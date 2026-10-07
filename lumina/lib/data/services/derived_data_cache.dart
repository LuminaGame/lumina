import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'package:lumina/data/services/engine_logger_service.dart';
import 'package:lumina/data/services/glb_parser_service.dart';

/// Header stored in front of every derived-data entry's payload.
class DerivedDataEntryHeader {
  /// The cache key the entry was written under; must match its file name.
  final String key;
  final int payloadBytes;

  /// SHA-256 of the payload, checked on every read.
  final String payloadSha256;

  /// Size of the source the payload was derived from (0 when unknown).
  final int sourceBytes;

  /// How long building the payload took, so a hit can say what it saved.
  final int buildMicros;
  final String label;
  final String createdAt;

  const DerivedDataEntryHeader({
    required this.key,
    required this.payloadBytes,
    required this.payloadSha256,
    this.sourceBytes = 0,
    this.buildMicros = 0,
    this.label = '',
    this.createdAt = '',
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'payloadBytes': payloadBytes,
        'payloadSha256': payloadSha256,
        'sourceBytes': sourceBytes,
        'buildMicros': buildMicros,
        'label': label,
        'createdAt': createdAt,
      };

  factory DerivedDataEntryHeader.fromJson(Map<String, dynamic> json) => DerivedDataEntryHeader(
        key: json['key'] as String,
        payloadBytes: json['payloadBytes'] as int,
        payloadSha256: json['payloadSha256'] as String,
        sourceBytes: json['sourceBytes'] as int? ?? 0,
        buildMicros: json['buildMicros'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

/// Entry count and bytes on disk of a cache (or of what a clear freed).
class DerivedDataCacheUsage {
  final int entries;
  final int bytes;
  const DerivedDataCacheUsage(this.entries, this.bytes);
}

/// What the derived-data caches of this process did since it started.
class DerivedDataCacheStats {
  int hits = 0;
  int misses = 0;
  int corrupt = 0;
  int evictions = 0;
  int bytesRead = 0;
  int bytesWritten = 0;
}

/// A project's local derived-data cache: `<project>/DerivedDataCache/`.
///
/// It stores data that is expensive to derive from project content and cheap
/// to rebuild — today the texture-budgeted GLB [GlbParserService] makes of an
/// asset that still carries oversized source art (~37 s for a mesh
/// with fourteen 8192x8192 PNGs). Entries are keyed by what they were derived
/// from, validated on every read (magic, format version, key, payload length,
/// payload SHA-256), written atomically (temp file + rename), bounded by
/// [maxBytes] with least-recently-used eviction, and never committed (the
/// folder carries its own `.gitignore`) or cooked (it is outside `contents/`;
/// see [packagedEntriesIncludingCache]). Hits, misses, corrupt entries,
/// evictions and clears are logged to the Output Log.
class DerivedDataCache {
  /// Project-root folder the cache lives in.
  static const String directoryName = 'DerivedDataCache';

  /// Bucket of texture-budgeted GLBs ([sanitizedGlb]).
  static const String sanitizedGlbBucket = 'SanitizedGlb';

  /// Default size bound per project: 2 GiB. A budgeted 8K-textured character
  /// is ~20 MB, so this only bites on projects with a lot of oversized art.
  static const int defaultMaxBytes = 2 * 1024 * 1024 * 1024;

  static const String entryExtension = '.ddc';
  static const int formatVersion = 1;
  static const String _logSource = 'DerivedDataCache';
  static const List<int> _magic = [0x4C, 0x44, 0x44, 0x43]; // "LDDC"
  static final RegExp _validKey = RegExp(r'^[A-Za-z0-9_.-]+$');

  static final DerivedDataCacheStats sessionStats = DerivedDataCacheStats();

  final String projectRoot;
  final int maxBytes;

  DerivedDataCache(this.projectRoot, {this.maxBytes = defaultMaxBytes});

  static final EngineLoggerService _logger = EngineLoggerService();

  Directory get directory => Directory('$projectRoot/$directoryName');

  File entryFile(String bucket, String key) {
    if (!_validKey.hasMatch(bucket) || !_validKey.hasMatch(key)) {
      throw ArgumentError('Derived-data bucket and key must be file-name safe: $bucket/$key');
    }
    return File('${directory.path}/$bucket/$key$entryExtension');
  }

  // ---------------------------------------------------------------------------
  // Project discovery

  /// The nearest ancestor directory of [path] (or [path] itself, when it is a
  /// directory) holding a `*.lmproject` manifest, or null outside any project.
  static String? findProjectRoot(String path) {
    var dir = FileSystemEntity.isDirectorySync(path) ? Directory(path).absolute : File(path).absolute.parent;
    while (true) {
      try {
        if (dir.listSync(followLinks: false).any((e) => e is File && e.path.endsWith('.lmproject'))) {
          return dir.path;
        }
      } on FileSystemException {
        // Unreadable ancestor: keep walking.
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// The cache of the project [path] belongs to, or null outside any project.
  static DerivedDataCache? forAssetPath(String path, {int maxBytes = defaultMaxBytes}) {
    final root = findProjectRoot(path);
    return root == null ? null : DerivedDataCache(root, maxBytes: maxBytes);
  }

  // ---------------------------------------------------------------------------
  // Texture-budgeted GLBs

  static String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Key of the texture-budgeted GLB derived from a source whose SHA-256 is
  /// [sourceSha256]: the content hash, the budget and the converter version,
  /// so a changed source, budget or [GlbParserService.sanitizerVersion] misses.
  static String sanitizedGlbKey(
    String sourceSha256,
    int maxTextureSize, {
    int converterVersion = GlbParserService.sanitizerVersion,
  }) =>
      '${sourceSha256}_b${maxTextureSize}_v$converterVersion';

  /// Whether [sanitizedGlb] would persist the result for [source]: only when
  /// the sanitizer has to decode images (the expensive path) and every image
  /// is embedded, so the output depends on [source] alone.
  static bool isCacheableGlb(Uint8List source, {int maxTextureSize = GlbParserService.defaultMaxTextureSize}) {
    final work = GlbParserService.inspectImageWork(source, maxTextureSize: maxTextureSize);
    return work.needsDecoding && work.selfContained;
  }

  /// [GlbParserService.convertGlbTgaToPngAsync] for the asset at [assetPath],
  /// through the derived-data cache of the project it belongs to. Outside a
  /// project, or for a source that is cheap or not self-contained, it simply
  /// converts.
  static Future<Uint8List> sanitizeGlbForAsset(
    String assetPath,
    Uint8List payload, {
    List<String>? searchDirs,
    int maxTextureSize = GlbParserService.defaultMaxTextureSize,
  }) {
    if (isCacheableGlb(payload, maxTextureSize: maxTextureSize)) {
      final cache = forAssetPath(assetPath);
      if (cache != null) {
        return cache.sanitizedGlb(
          payload,
          searchDirs: searchDirs,
          maxTextureSize: maxTextureSize,
          label: File(assetPath).uri.pathSegments.last,
        );
      }
    }
    return GlbParserService.convertGlbTgaToPngAsync(payload, searchDirs: searchDirs, maxTextureSize: maxTextureSize);
  }

  /// The texture-budgeted form of [source]: from this cache when an entry for
  /// its content hash, [maxTextureSize] and the converter version exists and
  /// validates, otherwise built by [GlbParserService.convertGlbTgaToPngAsync]
  /// and stored. Hashing, reading and writing all run off the calling isolate.
  Future<Uint8List> sanitizedGlb(
    Uint8List source, {
    List<String>? searchDirs,
    int maxTextureSize = GlbParserService.defaultMaxTextureSize,
    String? label,
  }) async {
    if (!isCacheableGlb(source, maxTextureSize: maxTextureSize)) {
      return GlbParserService.convertGlbTgaToPngAsync(source, searchDirs: searchDirs, maxTextureSize: maxTextureSize);
    }
    final name = label ?? 'GLB';
    final where = '$directoryName/$sanitizedGlbBucket';
    final _Probe probe;
    try {
      probe = await _probeOffThread(directory.path, sanitizedGlbBucket, source, maxTextureSize);
    } catch (e) {
      // The cache must never cost a load: convert as if it did not exist.
      _logger.log('DDC lookup for $name failed ($e); converting without the cache',
          level: 'warning', source: _logSource);
      return GlbParserService.convertGlbTgaToPngAsync(source, searchDirs: searchDirs, maxTextureSize: maxTextureSize);
    }

    final hit = probe.payload;
    if (hit != null) {
      sessionStats.hits++;
      sessionStats.bytesRead += hit.length;
      final saved = probe.header!.buildMicros > 0 ? ', skipping a ${_duration(probe.header!.buildMicros)} rebuild' : '';
      _logger.log(
        'DDC hit: $name — loaded ${_size(hit.length)} of derived data in ${_duration(probe.readMicros)} '
        '(hashing the ${_size(source.length)} source took ${_duration(probe.hashMicros)})$saved '
        '[key ${_shortKey(probe.key)}]',
        level: 'info',
        source: _logSource,
      );
      return hit;
    }
    if (probe.problem != null) {
      sessionStats.corrupt++;
      _logger.log(
        'DDC entry $where/${probe.key}$entryExtension for $name is corrupt (${probe.problem}); discarded, rebuilding',
        level: 'warning',
        source: _logSource,
      );
    }

    sessionStats.misses++;
    final watch = Stopwatch()..start();
    final built = await GlbParserService.convertGlbTgaToPngAsync(
      source,
      searchDirs: searchDirs,
      maxTextureSize: maxTextureSize,
    );
    watch.stop();
    var stored = 'stored ${_size(built.length)} in $where';
    try {
      await put(
        sanitizedGlbBucket,
        probe.key,
        built,
        label: name,
        sourceBytes: source.length,
        buildMicros: watch.elapsedMicroseconds,
      );
    } on FileSystemException catch (e) {
      // A full or read-only disk costs the next session the rebuild, nothing more.
      stored = 'not stored (${e.message}${e.osError == null ? '' : ': ${e.osError!.message}'})';
    } catch (e) {
      stored = 'not stored ($e)';
    }
    _logger.log(
      'DDC miss: $name — built in ${_duration(watch.elapsedMicroseconds)} from a ${_size(source.length)} source, '
      '$stored [key ${_shortKey(probe.key)}]',
      level: stored.startsWith('stored') ? 'info' : 'warning',
      source: _logSource,
    );
    return built;
  }

  // ---------------------------------------------------------------------------
  // Generic entries

  /// The payload stored under [bucket]/[key], or null when there is none. A
  /// corrupt or truncated entry is logged, deleted and reported as absent. A
  /// hit marks the entry as recently used.
  Future<Uint8List?> get(String bucket, String key, {String? label}) async {
    final file = entryFile(bucket, key);
    if (!file.existsSync()) return null;
    final read = await _readOffThread(file.path, key);
    if (read.problem != null) {
      sessionStats.corrupt++;
      _logger.log(
        'DDC entry $directoryName/$bucket/$key$entryExtension${label == null ? '' : ' for $label'} is corrupt '
        '(${read.problem}); discarded',
        level: 'warning',
        source: _logSource,
      );
      return null;
    }
    return read.payload;
  }

  /// Stores [payload] under [bucket]/[key] (atomically: a temp file renamed
  /// into place), then evicts least-recently-used entries until the cache is
  /// within [maxBytes]. Throws [FileSystemException] when the disk refuses.
  Future<File> put(
    String bucket,
    String key,
    Uint8List payload, {
    String? label,
    int sourceBytes = 0,
    int buildMicros = 0,
  }) async {
    final file = entryFile(bucket, key);
    final header = DerivedDataEntryHeader(
      key: key,
      payloadBytes: payload.length,
      payloadSha256: '', // Filled in off-thread.
      sourceBytes: sourceBytes,
      buildMicros: buildMicros,
      label: label ?? '',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ).toJson();
    final evicted = await _writeOffThread(directory.path, file.path, header, payload, maxBytes);
    sessionStats.bytesWritten += payload.length;
    if (evicted.entries > 0) {
      sessionStats.evictions += evicted.entries;
      _logger.log(
        'DDC evicted ${_count(evicted.entries)} (${_size(evicted.bytes)}) to stay under the '
        '${_size(maxBytes)} bound of $directoryName',
        level: 'info',
        source: _logSource,
      );
    }
    return file;
  }

  /// Every entry file in the cache, sorted by path.
  List<File> entries() {
    final dir = directory;
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith(entryExtension))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  DerivedDataCacheUsage usage() {
    var bytes = 0;
    final all = entries();
    for (final f in all) {
      try {
        bytes += f.lengthSync();
      } on FileSystemException {
        // Removed under us.
      }
    }
    return DerivedDataCacheUsage(all.length, bytes);
  }

  /// Deletes every entry (and any temp file a crashed write left behind) and
  /// logs what that freed. The cache rebuilds entries on demand.
  Future<DerivedDataCacheUsage> clear() async {
    final before = usage();
    final dir = directory;
    if (dir.existsSync()) {
      for (final e in dir.listSync(followLinks: false)) {
        // Listings join with the native separator (`\` on Windows).
        if (e.path.replaceAll(r'\', '/').endsWith('/.gitignore')) continue;
        e.deleteSync(recursive: true);
      }
    }
    _logger.log(
      'Cleared the Derived Data Cache at ${dir.path}: ${_count(before.entries)}, ${_size(before.bytes)} freed',
      level: 'success',
      source: _logSource,
    );
    return before;
  }

  /// The header of the entry [file], or null when it is not a readable entry.
  static DerivedDataEntryHeader? readEntryHeader(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final head = raf.readSync(12);
      if (head.length < 12 || !_hasMagic(head)) return null;
      final data = ByteData.sublistView(head);
      if (data.getUint32(4, Endian.little) != formatVersion) return null;
      final json = raf.readSync(data.getUint32(8, Endian.little));
      return DerivedDataEntryHeader.fromJson(jsonDecode(utf8.decode(json)) as Map<String, dynamic>);
    } catch (_) {
      return null;
    } finally {
      raf?.closeSync();
    }
  }

  // ---------------------------------------------------------------------------
  // Keeping the cache out of git and out of the packaged game

  /// Adds `DerivedDataCache/` to [projectRoot]'s `.gitignore` (creating it if
  /// needed). Returns false when the rule was already there.
  static bool ensureIgnoredBy(String projectRoot) {
    final file = File('$projectRoot/.gitignore');
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    const rules = {'DerivedDataCache/', '/DerivedDataCache/', 'DerivedDataCache', '/DerivedDataCache'};
    if (LineSplitter.split(existing).any((l) => rules.contains(l.trim()))) return false;
    final out = StringBuffer(existing);
    if (existing.isNotEmpty) {
      if (!existing.endsWith('\n')) out.writeln();
      out.writeln();
    }
    out
      ..writeln('# Lumina derived data: rebuilt on demand, never committed')
      ..writeln('$directoryName/');
    file.writeAsStringSync(out.toString());
    return true;
  }

  /// The `flutter: assets:` entries of a project pubspec that would bundle the
  /// cache into a cooked game. `flutter build` only packages the listed asset
  /// entries (directories are not recursive), so the cache stays out unless
  /// one of these names it — which Cook & Package refuses.
  static List<String> packagedEntriesIncludingCache(String pubspecYaml) {
    Object? doc;
    try {
      doc = loadYaml(pubspecYaml);
    } catch (_) {
      return const [];
    }
    if (doc is! Map) return const [];
    final flutter = doc['flutter'];
    if (flutter is! Map) return const [];
    final assets = flutter['assets'];
    if (assets is! List) return const [];
    final offending = <String>[];
    for (final entry in assets) {
      final path = entry is Map ? entry['path'] : entry;
      if (path is! String) continue;
      var normalized = path.trim();
      while (normalized.startsWith('./')) {
        normalized = normalized.substring(2);
      }
      if (normalized.startsWith('/')) normalized = normalized.substring(1);
      if (normalized == directoryName || normalized.startsWith('$directoryName/')) offending.add(path);
    }
    return offending;
  }

  // ---------------------------------------------------------------------------
  // Off-thread work. Each closure is built in a scope holding only sendable
  // values, so nothing else of the caller's context is copied to the worker.

  static Future<_Probe> _probeOffThread(String dir, String bucket, Uint8List source, int maxTextureSize) =>
      Isolate.run(() => _probe(dir, bucket, source, maxTextureSize));

  static Future<_Read> _readOffThread(String path, String key) => Isolate.run(() => _readEntry(path, key, deleteIfCorrupt: true));

  static Future<DerivedDataCacheUsage> _writeOffThread(
    String dir,
    String path,
    Map<String, dynamic> header,
    Uint8List payload,
    int maxBytes,
  ) =>
      Isolate.run(() => _writeEntry(dir, path, header, payload, maxBytes));

  static _Probe _probe(String dir, String bucket, Uint8List source, int maxTextureSize) {
    final watch = Stopwatch()..start();
    final key = sanitizedGlbKey(sha256Hex(source), maxTextureSize);
    final hashMicros = watch.elapsedMicroseconds;
    final path = '$dir/$bucket/$key$entryExtension';
    if (!File(path).existsSync()) {
      return _Probe(key: key, hashMicros: hashMicros, readMicros: 0);
    }
    watch.reset();
    final read = _readEntry(path, key, deleteIfCorrupt: true);
    return _Probe(
      key: key,
      hashMicros: hashMicros,
      readMicros: watch.elapsedMicroseconds,
      payload: read.payload,
      header: read.header,
      problem: read.problem,
    );
  }

  /// Reads and validates the entry at [path]; a valid one is marked as used
  /// now (its mtime drives LRU eviction), a corrupt one deleted. The payload
  /// is read into its own buffer (not a view into the whole file).
  static _Read _readEntry(String path, String key, {required bool deleteIfCorrupt}) {
    final file = File(path);
    String? problem;
    DerivedDataEntryHeader? header;
    Uint8List? payload;
    try {
      final raf = file.openSync();
      try {
        final length = raf.lengthSync();
        final head = raf.readSync(12);
        if (head.length < 12) {
          problem = 'truncated header: $length bytes';
        } else if (!_hasMagic(head)) {
          problem = 'not a derived-data entry (bad magic)';
        } else {
          final data = ByteData.sublistView(head);
          final version = data.getUint32(4, Endian.little);
          final headerLength = data.getUint32(8, Endian.little);
          if (version != formatVersion) {
            problem = 'entry format $version, expected $formatVersion';
          } else if (12 + headerLength > length) {
            problem = 'truncated header: $length of ${12 + headerLength} bytes';
          } else {
            try {
              header = DerivedDataEntryHeader.fromJson(
                jsonDecode(utf8.decode(raf.readSync(headerLength))) as Map<String, dynamic>,
              );
            } catch (_) {
              problem = 'unreadable header';
            }
            final h = header;
            if (h != null) {
              final bodyLength = length - 12 - headerLength;
              if (h.key != key) {
                problem = 'key mismatch: the entry was written for ${h.key}';
              } else if (bodyLength != h.payloadBytes) {
                problem = bodyLength < h.payloadBytes
                    ? 'truncated payload: $bodyLength of ${h.payloadBytes} bytes'
                    : 'payload is $bodyLength bytes, header says ${h.payloadBytes}';
              } else {
                final body = raf.readSync(bodyLength);
                if (body.length != bodyLength) {
                  problem = 'truncated payload: ${body.length} of ${h.payloadBytes} bytes';
                } else if (sha256Hex(body) != h.payloadSha256) {
                  problem = 'payload hash mismatch';
                } else {
                  payload = body;
                }
              }
            }
          }
        }
      } finally {
        raf.closeSync();
      }
    } on FileSystemException catch (e) {
      problem = 'unreadable: ${e.osError?.message ?? e.message}';
    }
    if (problem != null) {
      if (deleteIfCorrupt) {
        try {
          file.deleteSync();
        } on FileSystemException {
          // Already gone, or a read-only disk: the next write replaces it.
        }
      }
      return _Read(problem: problem);
    }
    try {
      file.setLastModifiedSync(DateTime.now());
    } on FileSystemException {
      // A read-only cache still serves hits; it just cannot track recency.
    }
    return _Read(payload: payload, header: header);
  }

  static DerivedDataCacheUsage _writeEntry(
    String dir,
    String path,
    Map<String, dynamic> header,
    Uint8List payload,
    int maxBytes,
  ) {
    final root = Directory(dir)..createSync(recursive: true);
    // The cache keeps itself out of git even in projects whose .gitignore
    // predates it.
    final ignore = File('${root.path}/.gitignore');
    if (!ignore.existsSync()) {
      ignore.writeAsStringSync('# Lumina derived data: rebuilt on demand, never committed\n*\n');
    }
    final target = File(path);
    target.parent.createSync(recursive: true);

    header['payloadSha256'] = sha256Hex(payload);
    final headerBytes = utf8.encode(jsonEncode(header));
    final prefix = ByteData(12)
      ..setUint8(0, _magic[0])
      ..setUint8(1, _magic[1])
      ..setUint8(2, _magic[2])
      ..setUint8(3, _magic[3])
      ..setUint32(4, formatVersion, Endian.little)
      ..setUint32(8, headerBytes.length, Endian.little);

    final temp = File('${target.parent.path}/.${target.uri.pathSegments.last}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      final raf = temp.openSync(mode: FileMode.writeOnly);
      try {
        raf
          ..writeFromSync(prefix.buffer.asUint8List())
          ..writeFromSync(headerBytes)
          ..writeFromSync(payload)
          ..flushSync();
      } finally {
        raf.closeSync();
      }
      temp.renameSync(target.path);
    } catch (_) {
      if (temp.existsSync()) temp.deleteSync();
      rethrow;
    }
    return _evict(root, keep: target.path, maxBytes: maxBytes);
  }

  /// Deletes least-recently-used entries (oldest mtime first) until the cache
  /// fits [maxBytes], never the entry just written; also sweeps temp files an
  /// interrupted write left behind more than an hour ago.
  static DerivedDataCacheUsage _evict(Directory root, {required String keep, required int maxBytes}) {
    final entries = <(File, int, DateTime)>[];
    var total = 0;
    final staleBefore = DateTime.now().subtract(const Duration(hours: 1));
    for (final f in root.listSync(recursive: true, followLinks: false).whereType<File>()) {
      try {
        final stat = f.statSync();
        if (f.path.endsWith('.tmp')) {
          if (stat.modified.isBefore(staleBefore)) f.deleteSync();
          continue;
        }
        if (!f.path.endsWith(entryExtension)) continue;
        entries.add((f, stat.size, stat.modified));
        total += stat.size;
      } on FileSystemException {
        continue;
      }
    }
    if (total <= maxBytes) return const DerivedDataCacheUsage(0, 0);
    entries.sort((a, b) {
      final byAge = a.$3.compareTo(b.$3);
      return byAge != 0 ? byAge : a.$1.path.compareTo(b.$1.path);
    });
    var count = 0;
    var freed = 0;
    for (final (file, size, _) in entries) {
      if (total <= maxBytes) break;
      if (file.path == keep) continue;
      try {
        file.deleteSync();
        total -= size;
        freed += size;
        count++;
      } on FileSystemException {
        continue;
      }
    }
    return DerivedDataCacheUsage(count, freed);
  }

  static bool _hasMagic(List<int> bytes) =>
      bytes[0] == _magic[0] && bytes[1] == _magic[1] && bytes[2] == _magic[2] && bytes[3] == _magic[3];

  static String _size(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
  }

  static String _duration(int micros) =>
      micros >= 1000000 ? '${(micros / 1000000).toStringAsFixed(2)} s' : '${(micros / 1000).round()} ms';

  static String _count(int entries) => entries == 1 ? '1 entry' : '$entries entries';

  static String _shortKey(String key) {
    final cut = key.indexOf('_');
    return cut > 12 ? '${key.substring(0, 12)}…${key.substring(cut)}' : key;
  }
}

class _Probe {
  final String key;
  final int hashMicros;
  final int readMicros;
  final Uint8List? payload;
  final DerivedDataEntryHeader? header;
  final String? problem;
  const _Probe({
    required this.key,
    required this.hashMicros,
    required this.readMicros,
    this.payload,
    this.header,
    this.problem,
  });
}

class _Read {
  final Uint8List? payload;
  final DerivedDataEntryHeader? header;
  final String? problem;
  const _Read({this.payload, this.header, this.problem});
}
