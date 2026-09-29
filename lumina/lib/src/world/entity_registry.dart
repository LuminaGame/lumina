import '../object/actor.dart';
import '../components/base/scene_component.dart';

/// Central world registry mapping native Filament renderable entity IDs to owning components and actors.
class LuminaEntityRegistry {
  final Map<int, LuminaSceneComponent> _registry = <int, LuminaSceneComponent>{};

  /// Registers [entities] as belonging to [owner].
  void registerEntities(Iterable<int> entities, LuminaSceneComponent owner) {
    for (final id in entities) {
      _registry[id] = owner;
    }
  }

  /// Unregisters [entities] from this registry.
  void unregisterEntities(Iterable<int> entities) {
    for (final id in entities) {
      _registry.remove(id);
    }
  }

  /// Returns the component mapped to [entity], or null if not registered.
  LuminaSceneComponent? componentForEntity(int entity) => _registry[entity];

  /// Returns the actor owning the component mapped to [entity], or null if not registered.
  LuminaActor? actorForEntity(int entity) => _registry[entity]?.owner;

  /// Number of registered entity mappings.
  int get count => _registry.length;

  /// Clears all entity mappings.
  void clear() => _registry.clear();
}
