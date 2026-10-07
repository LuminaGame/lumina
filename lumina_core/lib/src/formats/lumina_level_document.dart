import 'dart:convert';

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

  /// The `metadata` key a level stores its Level Blueprint under.
  static const String levelBlueprintKey = 'levelBlueprint';

  /// The stored Level Blueprint as JSON (`metadata.levelBlueprint`), or null
  /// when the level has none. The engine reads it into its
  /// `LuminaLevelBlueprintDocument` (`levelBlueprint`, from `package:lumina`).
  Map<String, dynamic>? get levelBlueprintJson {
    final stored = metadata[levelBlueprintKey];
    return stored is Map ? Map<String, dynamic>.from(stored) : null;
  }

  /// Stores [value] under `metadata.levelBlueprint`; null removes the key,
  /// so a level without a script stays as it was.
  set levelBlueprintJson(Map<String, dynamic>? value) {
    if (value == null) {
      metadata.remove(levelBlueprintKey);
    } else {
      metadata[levelBlueprintKey] = value;
    }
  }

  /// Whether the level carries a Blueprint.
  bool get hasLevelBlueprint => metadata[levelBlueprintKey] is Map;

  Map<String, dynamic> toJson() => container;

  String encode() => jsonEncode(container);
}
