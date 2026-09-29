import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'lumina_asset.dart';

/// Where a base64 string value (`thumbnail_png`, `raw_payload`) sits inside a
/// `.lmas` file: the byte offset of its first character (after the opening
/// quote) and its length in bytes. A null [length] means the string was not
/// scanned to its end (the summary stopped once it had what it needed).
class LmasByteRange {
  final int offset;
  final int? length;
  const LmasByteRange(this.offset, [this.length]);

  Map<String, dynamic> toJson() => {'o': offset, if (length != null) 'l': length};

  static LmasByteRange? fromJson(Object? json) {
    if (json is! Map) return null;
    final o = json['o'];
    if (o is! int) return null;
    final l = json['l'];
    return LmasByteRange(o, l is int ? l : null);
  }

  @override
  bool operator ==(Object other) => other is LmasByteRange && other.offset == offset && other.length == length;

  @override
  int get hashCode => Object.hash(offset, length);
}

/// What a `.lmas` is without its payload: id, name, type,
/// metadata, references, whether it carries a thumbnail and where it and the
/// payload sit in the file. [LuminaAsset.readSummary] reads it without
/// base64-decoding `thumbnail_png` / `raw_payload`; the project's asset index
/// ([LuminaAssetIndex]) stores one per file.
///
/// For an actor asset whose payload is a small Blueprint document, the
/// summary also knows the document's [blueprintKind] (`class`, `enum`,
/// `interface`, `save_game`, `montage`, …), its [parentClass] and whether it
/// has an event graph — what the class catalogs need without the payload.
class LuminaAssetSummary {
  final String assetId;
  final String name;
  final AssetType type;
  final bool hasThumbnail;
  final Map<String, String> metadata;
  final List<AssetReference> references;

  /// The Blueprint document kind of an actor payload (`class` when the
  /// document names none), else null.
  final String? blueprintKind;

  /// The Blueprint document's own `parentClass` (null when it names none).
  final String? documentParentClass;

  /// The Blueprint document's `parentClass`, else `metadata['parent_class']`.
  String? get parentClass => documentParentClass ?? metadata['parent_class'];

  /// Whether the Blueprint document has an `eventGraph`.
  final bool hasEventGraph;

  /// `thumbnail_png` in the file (null when absent or empty).
  final LmasByteRange? thumbnailRange;

  /// `raw_payload` in the file (null when absent).
  final LmasByteRange? payloadRange;

  /// Companion file name (`SM_Rock.entity.glb`, `T_Rock.png`) → its
  /// modification time in ms since epoch. Filled by the asset index.
  final Map<String, int> companionModified;

  /// Metadata keys whose (large) values were left out of [metadata] when the
  /// summary was stored in the index; read the file for them.
  final Set<String> omittedMetadata;

  const LuminaAssetSummary({
    required this.assetId,
    required this.name,
    required this.type,
    this.hasThumbnail = false,
    this.metadata = const {},
    this.references = const [],
    this.blueprintKind,
    this.documentParentClass,
    this.hasEventGraph = false,
    this.thumbnailRange,
    this.payloadRange,
    this.companionModified = const {},
    this.omittedMetadata = const {},
  });

  /// Whether the file embeds thumbnail bytes.
  bool get hasThumbnailBytes => thumbnailRange != null && (thumbnailRange!.length ?? 1) > 0;

  /// `metadata.thumbnail_source` (`filament`, `image`, `badge`).
  String? get thumbnailSource => metadata['thumbnail_source'];

  /// The newest companion modification time (ms), or null without companions.
  int? get newestCompanionModified =>
      companionModified.isEmpty ? null : companionModified.values.reduce(math.max);

  LuminaAssetSummary copyWith({Map<String, int>? companionModified, Map<String, String>? metadata, Set<String>? omittedMetadata}) =>
      LuminaAssetSummary(
        assetId: assetId,
        name: name,
        type: type,
        hasThumbnail: hasThumbnail,
        metadata: metadata ?? this.metadata,
        references: references,
        blueprintKind: blueprintKind,
        documentParentClass: documentParentClass,
        hasEventGraph: hasEventGraph,
        thumbnailRange: thumbnailRange,
        payloadRange: payloadRange,
        companionModified: companionModified ?? this.companionModified,
        omittedMetadata: omittedMetadata ?? this.omittedMetadata,
      );

  /// Metadata values longer than this are left out of the stored summary
  /// (a big level's `actors` list), listed in [omittedMetadata].
  static const int maxStoredMetadataValue = 64 * 1024;

  Map<String, dynamic> toJson() {
    final meta = <String, String>{};
    final omitted = <String>{...omittedMetadata};
    metadata.forEach((k, v) {
      if (v.length > maxStoredMetadataValue) {
        omitted.add(k);
      } else {
        meta[k] = v;
      }
    });
    return {
      'id': assetId,
      'name': name,
      'type': type.name,
      if (hasThumbnail) 'has_thumbnail': true,
      'metadata': meta,
      if (references.isNotEmpty) 'references': [for (final r in references) r.toMap()],
      if (blueprintKind != null) 'blueprint_kind': blueprintKind,
      if (documentParentClass != null) 'parent_class': documentParentClass,
      if (hasEventGraph) 'event_graph': true,
      if (thumbnailRange != null) 'thumbnail': thumbnailRange!.toJson(),
      if (payloadRange != null) 'payload': payloadRange!.toJson(),
      if (companionModified.isNotEmpty) 'companions': companionModified,
      if (omitted.isNotEmpty) 'omitted_metadata': omitted.toList()..sort(),
    };
  }

  factory LuminaAssetSummary.fromJson(Map<String, dynamic> json) => LuminaAssetSummary(
        assetId: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: assetTypeNamed(json['type'] as String?),
        hasThumbnail: json['has_thumbnail'] == true,
        metadata: {
          for (final e in (json['metadata'] as Map? ?? const {}).entries) e.key as String: e.value.toString(),
        },
        references: [
          for (final r in (json['references'] as List? ?? const []))
            if (r is Map) AssetReference.fromMap(Map<String, dynamic>.from(r)),
        ],
        blueprintKind: json['blueprint_kind'] as String?,
        documentParentClass: json['parent_class'] as String?,
        hasEventGraph: json['event_graph'] == true,
        thumbnailRange: LmasByteRange.fromJson(json['thumbnail']),
        payloadRange: LmasByteRange.fromJson(json['payload']),
        companionModified: {
          for (final e in (json['companions'] as Map? ?? const {}).entries)
            if (e.value is int) e.key as String: e.value as int,
        },
        omittedMetadata: {for (final k in (json['omitted_metadata'] as List? ?? const [])) k.toString()},
      );

  /// The [AssetType] named [name] (`unknown` for anything else), as
  /// [LuminaAsset.fromMap] resolves it.
  static AssetType assetTypeNamed(String? name) =>
      AssetType.values.firstWhere((e) => e.name == (name ?? 'unknown'), orElse: () => AssetType.unknown);

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  /// Payloads at most this long (base64 bytes) are decoded to learn an actor
  /// Blueprint document's kind and parent class.
  static const int maxInspectedPayload = 4 * 1024 * 1024;

  /// Reads [file]'s summary: tokenises the JSON object, decoding the small
  /// fields and only locating the base64 strings. Legacy files with the
  /// base64 fields first are scanned past them (no decode); a file this
  /// reader cannot follow is decoded fully.
  static LuminaAssetSummary read(File file) {
    final raf = file.openSync();
    try {
      final src = _LmasByteSource(raf);
      try {
        return _SummaryParser(src).parse();
      } on _NotStreamable {
        return _fullDecode(file.readAsBytesSync());
      }
    } finally {
      raf.closeSync();
    }
  }

  /// Reads [bytes] (a whole `.lmas`) the same way, for in-memory callers.
  static LuminaAssetSummary fromBytes(Uint8List bytes) {
    try {
      return _SummaryParser(_LmasByteSource.memory(bytes)).parse();
    } on _NotStreamable {
      return _fullDecode(bytes);
    }
  }

  static LuminaAssetSummary _fullDecode(Uint8List bytes) {
    final hasHeader = bytes.length >= 4 && bytes[0] == 0x4C && bytes[1] == 0x4D && bytes[2] == 0x41 && bytes[3] == 0x53;
    final map = jsonDecode(utf8.decode(hasHeader ? bytes.sublist(4) : bytes));
    if (map is! Map) throw const FormatException('A .lmas holds a JSON object');
    final asset = LuminaAsset.fromMap(Map<String, dynamic>.from(map));
    final doc = _inspectDocument(asset.type, asset.rawPayload);
    return LuminaAssetSummary(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      hasThumbnail: asset.hasThumbnail,
      metadata: asset.metadata,
      references: asset.references,
      blueprintKind: doc?.kind,
      documentParentClass: doc?.parentClass,
      hasEventGraph: doc?.hasEventGraph ?? false,
      // No byte ranges: readers fall back to decoding the file.
    );
  }

  static ({String kind, String? parentClass, bool hasEventGraph})? _inspectDocument(AssetType type, Uint8List? payload) {
    if (type != AssetType.actor || payload == null || payload.isEmpty || payload[0] != 0x7B) return null;
    try {
      final json = jsonDecode(utf8.decode(payload));
      if (json is! Map) return null;
      final kind = json['kind'];
      final parent = json['parentClass'];
      return (
        kind: kind is String ? kind : 'class',
        parentClass: parent is String ? parent : null,
        hasEventGraph: json['eventGraph'] != null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reads the base64 string at [range] of [file] and decodes it. Null when
  /// the range is empty or unreadable.
  static Uint8List? readRange(File file, LmasByteRange range) {
    try {
      final raf = file.openSync();
      try {
        var length = range.length;
        length ??= _LmasByteSource(raf).findStringEnd(range.offset) - range.offset;
        if (length <= 0) return null;
        raf.setPositionSync(range.offset);
        final bytes = raf.readSync(length);
        if (bytes.length != length) return null;
        return base64Decode(ascii.decode(bytes));
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }
}

class _NotStreamable implements Exception {
  const _NotStreamable();
}

/// Random access over a `.lmas` (file or memory) through a sliding buffer.
class _LmasByteSource {
  final RandomAccessFile? _raf;
  final int length;
  final Uint8List _buf;
  int _start = 0;
  int _len = 0;

  static const int _chunk = 1 << 20;

  _LmasByteSource(RandomAccessFile raf)
      : _raf = raf,
        length = raf.lengthSync(),
        _buf = Uint8List(_chunk);

  _LmasByteSource.memory(Uint8List bytes)
      : _raf = null,
        length = bytes.length,
        _buf = bytes,
        _len = bytes.length;

  void _load(int pos) {
    final raf = _raf;
    if (raf == null) return;
    raf.setPositionSync(pos);
    _start = pos;
    _len = raf.readIntoSync(_buf, 0, math.min(_buf.length, length - pos));
  }

  int byteAt(int pos) {
    if (pos < 0 || pos >= length) throw const _NotStreamable();
    if (pos < _start || pos >= _start + _len) _load(pos);
    return _buf[pos - _start];
  }

  Uint8List slice(int from, int to) {
    if (from < 0 || to > length || to < from) throw const _NotStreamable();
    if (from >= _start && to <= _start + _len) {
      return Uint8List.sublistView(_buf, from - _start, to - _start);
    }
    final raf = _raf!;
    raf.setPositionSync(from);
    return raf.readSync(to - from);
  }

  /// The index of the quote closing the JSON string whose first character is
  /// at [pos], honouring backslash escapes.
  int findStringEnd(int pos) {
    var p = pos;
    while (p < length) {
      if (p < _start || p >= _start + _len) _load(p);
      final buf = _buf;
      final end = _len;
      var i = p - _start;
      while (i < end) {
        final c = buf[i];
        if (c == 0x22) return _start + i;
        if (c == 0x5C) {
          i += 2;
          continue;
        }
        i++;
      }
      p = _start + i;
    }
    throw const _NotStreamable();
  }
}

/// Tokenises the top-level JSON object of a `.lmas`.
class _SummaryParser {
  final _LmasByteSource src;
  _SummaryParser(this.src);

  int pos = 0;

  static const Set<String> _base64Keys = {'thumbnail_png', 'raw_payload'};
  static const Set<String> _decodedKeys = {'asset_id', 'name', 'type', 'has_thumbnail', 'references', 'metadata'};

  int _ws(int p) {
    while (true) {
      final c = src.byteAt(p);
      if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09) {
        p++;
      } else {
        return p;
      }
    }
  }

  /// The end (exclusive) of the JSON value starting at [p].
  int _skipValue(int p) {
    final c = src.byteAt(p);
    if (c == 0x22) return src.findStringEnd(p + 1) + 1;
    if (c == 0x7B || c == 0x5B) {
      var depth = 0;
      var q = p;
      while (true) {
        final b = src.byteAt(q);
        if (b == 0x22) {
          q = src.findStringEnd(q + 1) + 1;
          continue;
        }
        if (b == 0x7B || b == 0x5B) depth++;
        if (b == 0x7D || b == 0x5D) {
          depth--;
          if (depth == 0) return q + 1;
        }
        q++;
      }
    }
    // Literal / number.
    var q = p;
    while (true) {
      final b = src.byteAt(q);
      if (b == 0x2C || b == 0x7D || b == 0x5D || b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09) return q;
      q++;
    }
  }

  Object? _decode(int from, int to) => jsonDecode(utf8.decode(src.slice(from, to)));

  LuminaAssetSummary parse() {
    if (src.length >= 4 && src.byteAt(0) == 0x4C && src.byteAt(1) == 0x4D && src.byteAt(2) == 0x41 && src.byteAt(3) == 0x53) {
      pos = 4;
    }
    pos = _ws(pos);
    if (src.byteAt(pos) != 0x7B) throw const _NotStreamable();
    pos++;
    final fields = <String, Object?>{};
    LmasByteRange? thumb;
    LmasByteRange? payload;
    var hasThumbnailKey = false;
    var hasPayloadKey = false;
    while (true) {
      pos = _ws(pos);
      final c = src.byteAt(pos);
      if (c == 0x7D) break;
      if (c == 0x2C) {
        pos++;
        continue;
      }
      if (c != 0x22) throw const _NotStreamable();
      final keyEnd = src.findStringEnd(pos + 1);
      final key = _decode(pos, keyEnd + 1) as String;
      pos = _ws(keyEnd + 1);
      if (src.byteAt(pos) != 0x3A) throw const _NotStreamable();
      pos = _ws(pos + 1);
      if (_base64Keys.contains(key)) {
        final isThumb = key == 'thumbnail_png';
        if (isThumb) {
          hasThumbnailKey = true;
        } else {
          hasPayloadKey = true;
        }
        if (src.byteAt(pos) == 0x22) {
          // Everything the summary needs sits before a payload that is the
          // last field (the key order toMap writes): stop without scanning it
          // unless it is an actor document worth inspecting.
          if (!isThumb && _allSmallFieldsSeen(fields, hasThumbnailKey)) {
            payload = LmasByteRange(pos + 1);
            break;
          }
          final end = src.findStringEnd(pos + 1);
          final range = LmasByteRange(pos + 1, end - pos - 1);
          if (isThumb) {
            thumb = range.length! > 0 ? range : null;
          } else {
            payload = range;
          }
          pos = end + 1;
        } else {
          pos = _skipValue(pos);
        }
        continue;
      }
      final end = _skipValue(pos);
      if (_decodedKeys.contains(key)) fields[key] = _decode(pos, end);
      pos = end;
    }
    if (!hasPayloadKey) payload = null;

    final typeStr = fields['type'];
    if (typeStr != null && typeStr is! String) throw const _NotStreamable();
    final type = LuminaAssetSummary.assetTypeNamed(typeStr as String?);
    final refs = fields['references'];
    final meta = fields['metadata'];
    final metadata = meta is Map ? meta.map((k, v) => MapEntry(k as String, v.toString())) : <String, String>{};

    ({String kind, String? parentClass, bool hasEventGraph})? doc;
    if (type == AssetType.actor && payload != null) {
      var range = payload;
      if (range.length == null) range = LmasByteRange(range.offset, src.findStringEnd(range.offset) - range.offset);
      payload = range;
      if (range.length! > 0 && range.length! <= LuminaAssetSummary.maxInspectedPayload) {
        try {
          final bytes = base64Decode(ascii.decode(src.slice(range.offset, range.offset + range.length!)));
          doc = LuminaAssetSummary._inspectDocument(type, bytes);
        } catch (_) {
          doc = null;
        }
      }
    }

    return LuminaAssetSummary(
      assetId: fields['asset_id'] as String? ?? '',
      name: fields['name'] as String? ?? '',
      type: type,
      hasThumbnail: fields['has_thumbnail'] as bool? ?? false,
      metadata: metadata,
      references: refs is List ? [for (final e in refs) AssetReference.fromMap(e as Map<String, dynamic>)] : const [],
      blueprintKind: doc?.kind,
      documentParentClass: doc?.parentClass,
      hasEventGraph: doc?.hasEventGraph ?? false,
      thumbnailRange: thumb,
      payloadRange: payload,
    );
  }

  static bool _allSmallFieldsSeen(Map<String, Object?> fields, bool thumbnailSeen) =>
      thumbnailSeen && _decodedKeys.every(fields.containsKey);
}
