import 'dart:convert';

import 'package:lumina/src/blueprint/level_blueprint.dart';

/// A level `.lmas` as Lumina Studio writes it (a JSON container): `assetId`,
/// `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and
/// `metadata` — the placed actors (`metadata.actors`), the level's sections
/// (environment, navigation, world partition) and, its
/// Level Blueprint (`metadata.levelBlueprint`). Unknown keys are kept.
class LuminaLevelDocument {
  /// Project-relative path (`contents/levels/L_Test.lmas`).
  final String relativePath;

  /// The whole container, as read (and as [toJson] writes it back).
  final Map<String, dynamic> container;

  LuminaLevelDocument({required this.relativePath, Map<String, dynamic>? container})
      : container = container ??
            <String, dynamic>{
              'assetId': 'level_${_baseName(relativePath)}',
              'name': _baseName(relativePath),
              'type': 'level',
              'relativePath': relativePath,
              'rawPayload': null,
              'metadata': <String, dynamic>{'actors': <Map<String, dynamic>>[]},
            };

  /// Reads a level container's JSON; null when it is not one.
  static LuminaLevelDocument? tryParse(String json, {required String relativePath}) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['metadata'] is! Map) return null;
      return LuminaLevelDocument(relativePath: relativePath, container: Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static String _baseName(String path) => path.split('/').last.replaceAll('.lmas', '');

  /// The level's name (`L_Test`).
  String get name => (container['name'] as String?) ?? _baseName(relativePath);

  /// `metadata`, created when missing.
  Map<String, dynamic> get metadata {
    final m = container['metadata'];
    if (m is Map<String, dynamic>) return m;
    final created = m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
    container['metadata'] = created;
    return created;
  }

  /// The placed actors (`metadata.actors`), as maps.
  List<Map<String, dynamic>> get actors => [
        for (final a in metadata['actors'] as List? ?? const []) if (a is Map) Map<String, dynamic>.from(a),
      ];
  set actors(List<Map<String, dynamic>> value) => metadata['actors'] = value;

  /// The level's Blueprint: an empty graph when none is stored.
  LuminaLevelBlueprintDocument get levelBlueprint =>
      LuminaLevelBlueprintDocument.fromLevelMetadata(metadata, levelPath: relativePath);

  /// Stores [value] under `metadata.levelBlueprint`; an empty Blueprint
  /// removes the key, so a level without a script stays as it was.
  set levelBlueprint(LuminaLevelBlueprintDocument? value) {
    if (value == null || value.isEmpty) {
      metadata.remove(LuminaLevelBlueprintDocument.metadataKey);
    } else {
      metadata[LuminaLevelBlueprintDocument.metadataKey] = value.toJson();
    }
  }

  /// Whether the level carries a Blueprint.
  bool get hasLevelBlueprint => metadata[LuminaLevelBlueprintDocument.metadataKey] is Map;

  /// The placed actors a Level Blueprint refers to by name.
  List<LuminaBlueprintLevelActorRef> get levelActorRefs => LuminaBlueprintLevelActorRef.fromActorMaps(actors);

  Map<String, dynamic> toJson() => container;

  String encode() => jsonEncode(container);
}
