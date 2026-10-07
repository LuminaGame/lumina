import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/services/engine_logger_service.dart';

/// One `.lmas` of a project as the asset index knows it: its project-relative
/// path, the size and modification time the summary was read at, and the
/// summary.
class AssetIndexEntry {
  /// Project-relative, `/`-separated (`contents/meshes/static/SM_Rock.lmas`).
  final String path;
  final int size;

  /// Modification time in ms since epoch.
  final int modifiedMs;
  final LuminaAssetSummary summary;

  /// The project the entry belongs to (absolute).
  final String projectDir;

  const AssetIndexEntry({
    required this.projectDir,
    required this.path,
    required this.size,
    required this.modifiedMs,
    required this.summary,
  });

  String get absolutePath => '$projectDir/$path';
  File get file => File(absolutePath);

  /// `SM_Rock.lmas`.
  String get fileName => path.substring(path.lastIndexOf('/') + 1);

  /// `SM_Rock`: the class / asset name callers key by.
  String get baseName => fileName.endsWith('.lmas') ? fileName.substring(0, fileName.length - 5) : fileName;

  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(modifiedMs);

  AssetType get type => summary.type;

  /// `metadata[key]`, read from the file when the index left a large value out.
  String? metadataValue(String key) {
    if (!summary.omittedMetadata.contains(key)) return summary.metadata[key];
    try {
      return LuminaAsset.readSummary(file).metadata[key];
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'size': size, 'mtime': modifiedMs, 'summary': summary.toJson()};
}

/// What one refresh changed (project-relative paths).
class AssetIndexChange {
  final List<String> added;
  final List<String> changed;
  final List<String> removed;
  const AssetIndexChange({this.added = const [], this.changed = const [], this.removed = const []});

  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty;

  @override
  String toString() => 'AssetIndexChange(+${added.length} ~${changed.length} -${removed.length})';
}

/// How the last refresh went — the seam tests use to prove an unchanged
/// project is only stat'ed.
class AssetIndexRefreshStats {
  final int files;
  final int decoded;
  final int removed;
  final Duration elapsed;
  final bool offThread;
  const AssetIndexRefreshStats({
    this.files = 0,
    this.decoded = 0,
    this.removed = 0,
    this.elapsed = Duration.zero,
    this.offThread = false,
  });

  @override
  String toString() => 'AssetIndexRefreshStats(files: $files, decoded: $decoded, removed: $removed, ${elapsed.inMilliseconds} ms${offThread ? ', off-thread' : ''})';
}

/// A project's asset index (asset registry):
/// every `.lmas` under `contents/` with its id, name, type, metadata,
/// references, thumbnail stamps and companion-file times, read without
/// decoding payloads and persisted to `<project>/.lumina/asset_index.json`.
///
/// The index is derived data: never the source of truth, always rebuildable.
/// Entries are keyed by project-relative path and validated by size and
/// modification time; [refresh] stats every file and decodes only new or
/// changed ones, in an isolate pool, then drops deleted ones and saves the
/// file atomically. A missing, corrupt or older-format index file rebuilds.
///
/// One instance per project directory ([open]); every scan of the editor
/// (content browser, class catalogs, Blueprint registries, PIE, code
/// generation) reads it instead of decoding every `.lmas`.
class LuminaAssetIndex {
  LuminaAssetIndex._(this.projectDir);

  /// Bumped whenever the stored summary changes shape.
  static const int formatVersion = 1;
  static const String directoryName = '.lumina';
  static const String fileName = 'asset_index.json';

  static final Map<String, LuminaAssetIndex> _instances = {};

  /// The index of [projectDir] (shared by every caller in this isolate).
  static LuminaAssetIndex open(String projectDir) {
    final key = _normalize(projectDir);
    return _instances.putIfAbsent(key, () => LuminaAssetIndex._(key));
  }

  /// Forgets the in-memory instance of [projectDir] (the file stays).
  static void close(String projectDir) => _instances.remove(_normalize(projectDir))?._dispose();

  static String _normalize(String dir) {
    var d = Directory(dir).absolute.path.replaceAll(r'\', '/');
    while (d.length > 1 && d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }

  final String projectDir;
  final EngineLoggerService _logger = EngineLoggerService();

  Map<String, AssetIndexEntry> _entries = {};
  bool _loaded = false;
  Future<AssetIndexChange>? _inFlight;
  AssetIndexRefreshStats _lastStats = const AssetIndexRefreshStats();
  final StreamController<AssetIndexChange> _changes = StreamController<AssetIndexChange>.broadcast();

  /// `<project>/.lumina/asset_index.json`.
  File get file => File('$projectDir/$directoryName/$fileName');

  /// Incremental updates: what each refresh added, changed and removed.
  Stream<AssetIndexChange> get changes => _changes.stream;

  AssetIndexRefreshStats get lastRefreshStats => _lastStats;

  /// Whether [refresh] / [refreshSync] ran at least once in this session.
  bool get isLoaded => _loaded;

  /// Every indexed asset, sorted by path.
  List<AssetIndexEntry> get entries => (_entries.values.toList()..sort((a, b) => a.path.compareTo(b.path)));

  List<LuminaAssetSummary> get summaries => [for (final e in entries) e.summary];

  List<AssetIndexEntry> byType(AssetType type) => [for (final e in entries) if (e.type == type) e];

  /// The entry of [path] (project-relative or absolute), or null.
  AssetIndexEntry? byPath(String path) => _entries[relativePathOf(path)];

  /// Actor assets whose Blueprint document is of [kind] (`class`, `enum`,
  /// `interface`, `save_game`, `montage`, …), sorted by path.
  List<AssetIndexEntry> blueprintDocuments(String kind) => [
        for (final e in entries)
          if (e.summary.blueprintKind == kind) e,
      ];

  /// [path] relative to the project, `/`-separated.
  String relativePathOf(String path) {
    var p = path.replaceAll(r'\', '/');
    if (p.startsWith('$projectDir/')) p = p.substring(projectDir.length + 1);
    if (p.startsWith('./')) p = p.substring(2);
    return p;
  }

  void _dispose() => _changes.close();

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  /// Brings the index up to date with `contents/`: stats every `.lmas` (and
  /// its companions), decodes the summaries of new or changed files in an
  /// isolate pool, drops deleted files and saves the index when anything
  /// changed. Concurrent calls share one refresh.
  ///
  /// The summaries go to an isolate pool when the files to read add up to
  /// [offThreadBytes] or more (a cold index of a real project); a handful of
  /// small files is cheaper to read here than an isolate is to start.
  /// [offThread] forces either way.
  Future<AssetIndexChange> refresh({int? workers, bool? offThread}) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _refreshAsync(workers: workers, offThread: offThread).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  /// Indexes just [paths] (`.lmas` files, project-relative or absolute) —
  /// what an import just wrote — without walking
  /// `contents/`: each is stat'ed and summarised, its companions read from
  /// one listing of its folder, and the change is saved and broadcast on
  /// [changes]. A listed path that no longer exists is dropped.
  AssetIndexChange refreshPaths(Iterable<String> paths) {
    _ensureLoaded();
    final rels = {
      for (final p in paths)
        if (p.endsWith('.lmas')) relativePathOf(p),
    }.toList()
      ..sort();
    final added = <String>[];
    final changed = <String>[];
    final removed = <String>[];
    final folders = <String, ({Set<String> bases, List<File> others})>{};
    for (final rel in rels) {
      final file = File('$projectDir/$rel');
      final stat = file.statSync();
      if (stat.type != FileSystemEntityType.file) {
        if (_entries.remove(rel) != null) removed.add(rel);
        continue;
      }
      final slash = rel.lastIndexOf('/');
      final dir = slash < 0 ? projectDir : '$projectDir/${rel.substring(0, slash)}';
      final folder = folders.putIfAbsent(dir, () {
        final bases = <String>{};
        final others = <File>[];
        for (final e in Directory(dir).listSync(followLinks: false)) {
          if (e is! File) continue;
          // A listed path joins its name with `\` on Windows.
          final name = e.uri.pathSegments.last;
          if (name.endsWith('.lmas')) {
            bases.add(name.substring(0, name.length - 5));
          } else if (!name.startsWith('.')) {
            others.add(e);
          }
        }
        return (bases: bases, others: others);
      });
      // A companion belongs to the first `<base>.` prefix naming an asset
      // of the folder, as in the full walk.
      final base = rel.substring(slash + 1, rel.length - 5);
      final companions = <String, int>{};
      for (final f in folder.others) {
        final name = f.uri.pathSegments.last;
        var dot = name.indexOf('.');
        while (dot > 0) {
          final prefix = name.substring(0, dot);
          if (folder.bases.contains(prefix)) {
            if (prefix == base) companions[name] = f.lastModifiedSync().millisecondsSinceEpoch;
            break;
          }
          dot = name.indexOf('.', dot + 1);
        }
      }
      final summary = _summarize(file.path);
      (_entries.containsKey(rel) ? changed : added).add(rel);
      _entries[rel] = AssetIndexEntry(
        projectDir: projectDir,
        path: rel,
        size: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        summary: summary == null
            ? LuminaAssetSummary(assetId: '', name: '', type: AssetType.unknown, companionModified: companions)
            : summary.copyWith(companionModified: companions),
      );
    }
    final change = AssetIndexChange(added: added, changed: changed, removed: removed);
    _finish(change);
    return change;
  }

  /// Bytes of `.lmas` to summarise from which [refresh] uses isolates.
  static const int offThreadBytes = 16 * 1024 * 1024;

  /// Whether summarising files totalling [bytes] belongs off the UI isolate.
  static bool shouldSummarizeOffThread(int bytes) => bytes >= offThreadBytes;

  /// [refresh] on the calling isolate, for synchronous callers: cheap when
  /// the index is warm (stats only), a full summary pass when it is cold.
  AssetIndexChange refreshSync() {
    final sw = Stopwatch()..start();
    _ensureLoaded();
    final walk = _walk();
    final todo = _diff(walk);
    final decoded = <String, LuminaAssetSummary?>{};
    for (final path in todo) {
      decoded[path] = _summarize('$projectDir/$path');
    }
    final change = _apply(walk, decoded);
    _lastStats = AssetIndexRefreshStats(
      files: walk.lmas.length,
      decoded: todo.length,
      removed: change.removed.length,
      elapsed: sw.elapsed,
    );
    _finish(change);
    return change;
  }

  Future<AssetIndexChange> _refreshAsync({int? workers, bool? offThread}) async {
    final sw = Stopwatch()..start();
    _ensureLoaded();
    var walk = _walk();
    final todo = _diff(walk);
    final decoded = <String, LuminaAssetSummary?>{};
    final todoBytes = todo.fold<int>(0, (sum, p) => sum + (walk.lmas[p]?.size ?? 0));
    final useIsolates = todo.isNotEmpty && (offThread ?? shouldSummarizeOffThread(todoBytes));
    if (todo.isNotEmpty && !useIsolates) {
      for (final path in todo) {
        decoded[path] = _summarize('$projectDir/$path');
      }
    }
    if (useIsolates) {
      final pool = math.max(1, math.min(workers ?? math.min(4, Platform.numberOfProcessors), todo.length));
      final chunks = List.generate(pool, (_) => <String>[]);
      for (var i = 0; i < todo.length; i++) {
        chunks[i % pool].add('$projectDir/${todo[i]}');
      }
      final results = await Future.wait([for (final chunk in chunks) _summarizeOffThread(chunk)]);
      for (var c = 0; c < chunks.length; c++) {
        for (var i = 0; i < chunks[c].length; i++) {
          final json = results[c][i];
          decoded[relativePathOf(chunks[c][i])] = json == null ? null : LuminaAssetSummary.fromJson(json);
        }
      }
      // Files written while the pool ran are summarised again, here.
      final fresh = _walk();
      for (final path in fresh.lmas.keys) {
        final before = walk.lmas[path];
        final now = fresh.lmas[path]!;
        final known = _entries[path];
        final stillCurrent = before != null && before.size == now.size && before.mtime == now.mtime;
        if (decoded.containsKey(path) ? !stillCurrent : (known == null || known.size != now.size || known.modifiedMs != now.mtime)) {
          decoded[path] = _summarize('$projectDir/$path');
        }
      }
      walk = fresh;
    }
    final change = _apply(walk, decoded);
    _lastStats = AssetIndexRefreshStats(
      files: walk.lmas.length,
      decoded: todo.length,
      removed: change.removed.length,
      elapsed: sw.elapsed,
      offThread: useIsolates,
    );
    if (useIsolates) {
      _logger.log(
        'Asset index: ${walk.lmas.length} assets, ${todo.length} summarised off the UI isolate in ${sw.elapsedMilliseconds} ms',
        level: 'info',
        source: 'AssetIndex',
      );
    }
    _finish(change);
    return change;
  }

  /// Summaries of [paths] as JSON, read in a background isolate (a static
  /// helper so the closure captures nothing but [paths]).
  static Future<List<Map<String, dynamic>?>> _summarizeOffThread(List<String> paths) =>
      Isolate.run(() => [for (final p in paths) _summarize(p)?.toJson()]);

  void _finish(AssetIndexChange change) {
    if (change.isEmpty) return;
    _save();
    _thumbnails.removeWhere((path, _) => change.changed.contains(path) || change.removed.contains(path));
    if (!_changes.isClosed) _changes.add(change);
  }

  static LuminaAssetSummary? _summarize(String path) {
    try {
      return LuminaAsset.readSummary(File(path));
    } catch (_) {
      return null;
    }
  }

  /// The `.lmas` paths whose size / mtime / companions differ from the index.
  List<String> _diff(_Walk walk) {
    final todo = <String>[];
    walk.lmas.forEach((path, stat) {
      final e = _entries[path];
      if (e == null || e.size != stat.size || e.modifiedMs != stat.mtime) todo.add(path);
    });
    todo.sort();
    return todo;
  }

  AssetIndexChange _apply(_Walk walk, Map<String, LuminaAssetSummary?> decoded) {
    final added = <String>[];
    final changed = <String>[];
    final removed = <String>[];
    final next = <String, AssetIndexEntry>{};
    walk.lmas.forEach((path, stat) {
      final old = _entries[path];
      final companions = walk.companions[path] ?? const <String, int>{};
      if (decoded.containsKey(path)) {
        final summary = decoded[path];
        if (summary == null) {
          // Unreadable: indexed as unknown so it is not decoded again until it changes.
          next[path] = AssetIndexEntry(
            projectDir: projectDir,
            path: path,
            size: stat.size,
            modifiedMs: stat.mtime,
            summary: LuminaAssetSummary(assetId: '', name: '', type: AssetType.unknown, companionModified: companions),
          );
        } else {
          next[path] = AssetIndexEntry(
            projectDir: projectDir,
            path: path,
            size: stat.size,
            modifiedMs: stat.mtime,
            summary: summary.copyWith(companionModified: companions),
          );
        }
        (old == null ? added : changed).add(path);
        return;
      }
      if (old == null) return;
      if (old.size != stat.size || old.modifiedMs != stat.mtime) {
        next[path] = old; // summarised again on the next refresh
        return;
      }
      if (!_sameCompanions(old.summary.companionModified, companions)) {
        next[path] = AssetIndexEntry(
          projectDir: projectDir,
          path: path,
          size: old.size,
          modifiedMs: old.modifiedMs,
          summary: old.summary.copyWith(companionModified: companions),
        );
        changed.add(path);
      } else {
        next[path] = old;
      }
    });
    for (final path in _entries.keys) {
      if (!walk.lmas.containsKey(path)) removed.add(path);
    }
    _entries = next;
    added.sort();
    changed.sort();
    removed.sort();
    return AssetIndexChange(added: added, changed: changed, removed: removed);
  }

  static bool _sameCompanions(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  /// Every `.lmas` under `contents/` (size, mtime) and each one's companion
  /// files (`<base>.<ext>` siblings: `.entity.glb`, a texture's image).
  _Walk _walk() {
    final lmas = <String, ({int size, int mtime})>{};
    final companions = <String, Map<String, int>>{};
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return _Walk(lmas, companions);
    final others = <File>[];
    final basesByDir = <String, Set<String>>{};
    for (final entity in contents.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final slash = path.lastIndexOf('/');
      final name = path.substring(slash + 1);
      if (name.endsWith('.lmas')) {
        final stat = entity.statSync();
        if (stat.type != FileSystemEntityType.file) continue;
        final rel = path.substring(projectDir.length + 1);
        lmas[rel] = (size: stat.size, mtime: stat.modified.millisecondsSinceEpoch);
        (basesByDir[path.substring(0, slash)] ??= <String>{}).add(name.substring(0, name.length - 5));
      } else if (!name.startsWith('.')) {
        others.add(entity);
      }
    }
    for (final f in others) {
      final path = f.path.replaceAll(r'\', '/');
      final slash = path.lastIndexOf('/');
      final bases = basesByDir[path.substring(0, slash)];
      if (bases == null) continue;
      final name = path.substring(slash + 1);
      var dot = name.indexOf('.');
      while (dot > 0) {
        final base = name.substring(0, dot);
        if (bases.contains(base)) {
          final owner = '${path.substring(projectDir.length + 1, slash)}/$base.lmas';
          (companions[owner] ??= <String, int>{})[name] = f.lastModifiedSync().millisecondsSinceEpoch;
          break;
        }
        dot = name.indexOf('.', dot + 1);
      }
    }
    return _Walk(lmas, companions);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    final f = file;
    if (!f.existsSync()) return;
    try {
      final json = jsonDecode(f.readAsStringSync());
      if (json is! Map || json['format'] != formatVersion || json['entries'] is! Map) {
        _logger.log('Asset index at ${f.path} is from another format; rebuilding', level: 'info', source: 'AssetIndex');
        return;
      }
      final entries = <String, AssetIndexEntry>{};
      (json['entries'] as Map).forEach((path, value) {
        if (path is! String || value is! Map) return;
        final size = value['size'];
        final mtime = value['mtime'];
        final summary = value['summary'];
        if (size is! int || mtime is! int || summary is! Map) return;
        entries[path] = AssetIndexEntry(
          projectDir: projectDir,
          path: path,
          size: size,
          modifiedMs: mtime,
          summary: LuminaAssetSummary.fromJson(Map<String, dynamic>.from(summary)),
        );
      });
      _entries = entries;
    } catch (e) {
      _logger.log('Asset index at ${f.path} is unreadable ($e); rebuilding', level: 'warning', source: 'AssetIndex');
      _entries = {};
    }
  }

  void _save() {
    try {
      final f = file;
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp');
      final sorted = entries;
      tmp.writeAsStringSync(jsonEncode({
        'format': formatVersion,
        'entries': {for (final e in sorted) e.path: e.toJson()},
      }), flush: true);
      tmp.renameSync(f.path);
    } catch (e) {
      _logger.log('Could not save the asset index: $e', level: 'warning', source: 'AssetIndex');
    }
  }

  // ---------------------------------------------------------------------------
  // Thumbnails
  // ---------------------------------------------------------------------------

  final Map<String, ({int size, int mtime, Uint8List? bytes})> _thumbnails = {};
  int _thumbnailBytes = 0;
  static const int _maxThumbnailBytes = 96 * 1024 * 1024;

  /// [entry]'s embedded thumbnail, read from its byte range (no payload
  /// decode) and kept in memory until the file changes. A texture without
  /// one shows its image. Null when the asset has none.
  Uint8List? thumbnailOf(AssetIndexEntry entry) {
    final cached = _thumbnails[entry.path];
    if (cached != null && cached.size == entry.size && cached.mtime == entry.modifiedMs) return cached.bytes;
    Uint8List? bytes;
    final s = entry.summary;
    if (s.thumbnailRange != null) {
      bytes = LuminaAssetSummary.readRange(entry.file, s.thumbnailRange!);
    } else if (s.type == AssetType.texture && s.payloadRange != null) {
      bytes = LuminaAssetSummary.readRange(entry.file, s.payloadRange!);
    } else if (s.hasThumbnail && s.thumbnailRange == null && s.payloadRange == null) {
      // A summary without byte ranges (read by full decode): decode once.
      try {
        final asset = LuminaAsset.fromBytes(entry.file.readAsBytesSync());
        bytes = asset.thumbnailPng;
        if ((bytes == null || bytes.isEmpty) && asset.type == AssetType.texture) bytes = asset.rawPayload;
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes != null && bytes.isEmpty) bytes = null;
    if (_thumbnailBytes > _maxThumbnailBytes) {
      _thumbnails.clear();
      _thumbnailBytes = 0;
    }
    _thumbnails[entry.path] = (size: entry.size, mtime: entry.modifiedMs, bytes: bytes);
    _thumbnailBytes += bytes?.length ?? 0;
    return bytes;
  }
}

class _Walk {
  final Map<String, ({int size, int mtime})> lmas;
  final Map<String, Map<String, int>> companions;
  const _Walk(this.lmas, this.companions);
}
