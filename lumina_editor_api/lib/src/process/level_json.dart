import '../editor_level.dart';

/// The JSON shapes of the level types on the plugin protocol (`host.level`):
/// the plugin process encodes specs and decodes snapshots with these, the
/// editor does the reverse. Transforms stay as the level stores them
/// (centimetres, Z up, degrees).
///
/// - actor snapshot: `{"id","name","type","parentId"?,"location":[x,y,z],
///   "rotation":[x,y,z],"scale":[x,y,z],"isVisible","meshAssetPath"?,
///   "components":[{"id","type","name","enabled","properties":{...}}]}`
/// - actor spec: `{"id"?,"name","type","parentId"?,"location","rotation",
///   "scale","meshAssetPath"?,"components":[{"type","name","properties":{...}}]}`
abstract final class EditorLevelJson {
  static Map<String, Object?> snapshotToJson(EditorActorSnapshot a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        if (a.parentId != null) 'parentId': a.parentId,
        'location': a.location,
        'rotation': a.rotation,
        'scale': a.scale,
        'isVisible': a.isVisible,
        if (a.meshAssetPath != null) 'meshAssetPath': a.meshAssetPath,
        'components': [
          for (final c in a.components)
            {'id': c.id, 'type': c.type, 'name': c.name, 'enabled': c.enabled, 'properties': c.properties},
        ],
      };

  static EditorActorSnapshot snapshotFromJson(Map<String, Object?> json) => EditorActorSnapshot(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        parentId: json['parentId'] as String?,
        location: _vec(json['location'], 0),
        rotation: _vec(json['rotation'], 0),
        scale: _vec(json['scale'], 1),
        isVisible: json['isVisible'] != false,
        meshAssetPath: json['meshAssetPath'] as String?,
        components: [
          for (final c in _maps(json['components']))
            EditorComponentSnapshot(
              id: c['id'] as String? ?? '',
              type: c['type'] as String? ?? '',
              name: c['name'] as String? ?? '',
              enabled: c['enabled'] != false,
              properties: _props(c['properties']),
            ),
        ],
      );

  static Map<String, Object?> specToJson(EditorActorSpec s) => {
        if (s.id != null) 'id': s.id,
        'name': s.name,
        'type': s.type,
        if (s.parentId != null) 'parentId': s.parentId,
        'location': s.location,
        'rotation': s.rotation,
        'scale': s.scale,
        if (s.meshAssetPath != null) 'meshAssetPath': s.meshAssetPath,
        'components': [
          for (final c in s.components) {'type': c.type, 'name': c.name, 'properties': c.properties},
        ],
      };

  static EditorActorSpec specFromJson(Map<String, Object?> json) => EditorActorSpec(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        parentId: json['parentId'] as String?,
        location: _vec(json['location'], 0),
        rotation: _vec(json['rotation'], 0),
        scale: _vec(json['scale'], 1),
        meshAssetPath: json['meshAssetPath'] as String?,
        components: [
          for (final c in _maps(json['components']))
            EditorComponentSpec(
              type: c['type'] as String? ?? '',
              name: c['name'] as String? ?? '',
              properties: _props(c['properties']),
            ),
        ],
      );

  static List<double> _vec(Object? v, double fill) {
    if (v is! List || v.length != 3) return [fill, fill, fill];
    return [for (final e in v) (e as num).toDouble()];
  }

  static Iterable<Map<String, Object?>> _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((m) => m.cast<String, Object?>()) : const [];

  static Map<String, dynamic> _props(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
}
