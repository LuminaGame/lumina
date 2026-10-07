import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/blueprint/blueprint_runtime.dart';

/// A placed Blueprint actor's per-instance collision: the level
/// Details' overrides of its class's collision components, stored in the level `.lmas` and applied by
/// Play-In-Editor and the generated level alike.
///
/// Each override is a component node in the level actor's `components` whose
/// `properties` name the Blueprint component ([componentIdKey]) and carry the
/// collision JSON of `LuminaCollisionComponent.toCollisionJson`; keys an
/// override lacks keep the class's values.
abstract final class LuminaBlueprintCollisionOverrides {
  /// The override node property naming the Blueprint component it overrides.
  static const String componentIdKey = 'blueprintComponentId';

  /// The collision JSON keys an override may carry.
  static const List<String> collisionKeys = ['preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'];

  /// The key of an override's Physics section: the component
  /// `physics` JSON of `LuminaPrimitivePhysics.applyPhysicsJson`.
  static const String physicsKey = 'physics';

  /// The overrides of level actor map [actor] (`metadata.actors[]`), by
  /// Blueprint component id, reduced to [collisionKeys]; nodes without a
  /// component id or without any collision key are skipped.
  static Map<String, Map<String, dynamic>> fromActorMap(Map<String, dynamic> actor) {
    final components = actor['components'];
    if (components is! List) return const {};
    final overrides = <String, Map<String, dynamic>>{};
    for (final node in components) {
      final props = node is Map ? node['properties'] : null;
      if (props is! Map) continue;
      final id = props[componentIdKey];
      if (id is! String || id.isEmpty) continue;
      final json = <String, dynamic>{
        for (final k in collisionKeys)
          if (props.containsKey(k)) k: props[k],
        if (props[physicsKey] is Map) physicsKey: Map<String, dynamic>.from(props[physicsKey] as Map),
      };
      if (json.isNotEmpty) overrides[id] = json;
    }
    return overrides;
  }

  /// Applies [overrides] to [actor]'s built Blueprint collision components
  /// (`applyCollisionJson`) and returns how many were applied. Ids that name
  /// no collision component, and actors that are not Blueprint instances,
  /// are ignored.
  static int apply(LuminaActor actor, Map<String, Map<String, dynamic>> overrides) {
    if (actor is! LuminaBlueprintRuntime || overrides.isEmpty) return 0;
    final built = actor.blueprintComponents;
    var applied = 0;
    overrides.forEach((id, json) {
      final component = built[id];
      final physics = json[physicsKey];
      if (component is LuminaPrimitivePhysics && physics is Map) {
        component.applyPhysicsJson(Map<String, dynamic>.from(physics));
      }
      if (component is LuminaCollisionComponent && collisionKeys.any(json.containsKey)) {
        component.applyCollisionJson(json);
        applied++;
      } else if (component is LuminaPrimitivePhysics && physics is Map) {
        applied++;
      }
    });
    return applied;
  }
}

/// [actor] with its per-instance collision [overrides] applied
/// ([LuminaBlueprintCollisionOverrides.apply]): the generated level wraps a
/// placed Blueprint's factory call in it.
T luminaWithCollisionOverrides<T extends LuminaActor>(T actor, Map<String, Map<String, dynamic>> overrides) {
  LuminaBlueprintCollisionOverrides.apply(actor, overrides);
  return actor;
}
