import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_core/src/formats/lumina_asset_summary.dart';

export 'package:lumina_core/src/formats/lumina_asset_summary.dart';

enum AssetType {
  unknown,
  level,
  filamesh,
  filameshSk,
  filamat,
  texture,
  actor,
  animation,
  particle,
  audio,
  landscape,
  physicsAsset,
  sequencer,
  widget,

  /// An Animation Blueprint: `raw_payload` is a
  /// `LuminaAnimBlueprintDocument` as JSON.
  animBlueprint,

  /// A Blend Space: `raw_payload` is a
  /// `LuminaBlendSpaceDocument` as JSON.
  blendSpace,

  /// A UI Theme: `raw_payload` is a
  /// `LuminaThemeDocument` as JSON.
  theme,

  /// A Pose Search Database (motion matching): `raw_payload` is a
  /// `LuminaPoseSearchDatabaseDocument` as JSON; its feature cache is the
  /// `.posedb` file next to the `.lmas`.
  poseSearchDatabase,
}

class AssetReference {
  final String slotName;
  final String assetId;
  final String assetPath;

  const AssetReference({
    required this.slotName,
    required this.assetId,
    required this.assetPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'slot_name': slotName,
      'asset_id': assetId,
      'asset_path': assetPath,
    };
  }

  factory AssetReference.fromMap(Map<String, dynamic> map) {
    return AssetReference(
      slotName: map['slot_name'] as String? ?? '',
      assetId: map['asset_id'] as String? ?? '',
      assetPath: map['asset_path'] as String? ?? '',
    );
  }
}

class LuminaAsset {
  final String assetId;
  final String name;
  final AssetType type;
  final bool hasThumbnail;
  final Uint8List? thumbnailPng;
  final Uint8List? rawPayload;
  final String rawMatSource;
  final List<AssetReference> references;
  final Map<String, String> metadata;

  const LuminaAsset({
    required this.assetId,
    required this.name,
    required this.type,
    this.hasThumbnail = false,
    this.thumbnailPng,
    this.rawPayload,
    this.rawMatSource = '',
    this.references = const [],
    this.metadata = const {},
  });

  /// The document as JSON. The two large base64 fields come last,
  /// so [readSummary] learns everything else from a small
  /// prefix of the file.
  Map<String, dynamic> toMap() {
    return {
      'asset_id': assetId,
      'name': name,
      'type': type.name,
      'has_thumbnail': hasThumbnail,
      'raw_mat_source': rawMatSource,
      'references': references.map((r) => r.toMap()).toList(),
      'metadata': metadata,
      'thumbnail_png': thumbnailPng != null ? base64Encode(thumbnailPng!) : null,
      'raw_payload': rawPayload != null ? base64Encode(rawPayload!) : null,
    };
  }

  /// The keys [toMap] writes last, in order.
  static const List<String> trailingKeys = ['thumbnail_png', 'raw_payload'];

  /// [map] (a `.lmas` document patched as raw JSON) with [trailingKeys]
  /// moved to the end, as [toMap] orders them; other keys keep their order.
  static Map<String, dynamic> withTrailingPayload(Map<String, dynamic> map) {
    if (!trailingKeys.any(map.containsKey)) return map;
    return {
      for (final e in map.entries)
        if (!trailingKeys.contains(e.key)) e.key: e.value,
      for (final k in trailingKeys)
        if (map.containsKey(k)) k: map[k],
    };
  }

  /// The summary of the `.lmas` at [file] without decoding its payload or
  /// thumbnail (see [LuminaAssetSummary.read]).
  static LuminaAssetSummary readSummary(File file) => LuminaAssetSummary.read(file);

  factory LuminaAsset.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'unknown';
    final assetType = AssetType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => AssetType.unknown,
    );

    final refsList = map['references'] as List<dynamic>? ?? [];
    final references = refsList
        .map((e) => AssetReference.fromMap(e as Map<String, dynamic>))
        .toList();

    final metaMap = map['metadata'] as Map<String, dynamic>? ?? {};
    final metadata = metaMap.map((k, v) => MapEntry(k, v.toString()));

    return LuminaAsset(
      assetId: map['asset_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: assetType,
      hasThumbnail: map['has_thumbnail'] as bool? ?? false,
      thumbnailPng: map['thumbnail_png'] != null
          ? base64Decode(map['thumbnail_png'] as String)
          : null,
      rawPayload: map['raw_payload'] != null
          ? base64Decode(map['raw_payload'] as String)
          : null,
      rawMatSource: map['raw_mat_source'] as String? ?? '',
      references: references,
      metadata: metadata,
    );
  }

  /// Serializes asset to binary Protobuf bytes format with LMAS magic header.
  Uint8List toProtoBufferBytes() {
    final jsonStr = jsonEncode(toMap());
    final jsonBytes = utf8.encode(jsonStr);
    final builder = BytesBuilder()
      ..add([0x4C, 0x4D, 0x41, 0x53]) // LMAS Magic Header
      ..add(jsonBytes);
    return builder.toBytes();
  }

  /// Deserializes asset from binary Protobuf bytes or JSON fallback payload.
  factory LuminaAsset.fromBytes(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x4C &&
        bytes[1] == 0x4D &&
        bytes[2] == 0x41 &&
        bytes[3] == 0x53) {
      final jsonStr = utf8.decode(bytes.sublist(4));
      return LuminaAsset.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
    }
    final jsonStr = utf8.decode(bytes);
    return LuminaAsset.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}
