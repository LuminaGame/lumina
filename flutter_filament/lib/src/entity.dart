import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as ffi_gen;
import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

/// A lightweight handle to an entity in Filament's Entity Component System (ECS).
///
/// Entities are 32-bit integer identifiers. Components (such as Camera, Light,
/// Renderable, Transform) are attached to entities using their respective managers.
/// Convention: `Entity.id == Entity::smuggle`; `Entity.none` (id 0) is never alive.
class FilamentEntity {
  final int id;
  final FilamentEngine? engine;

  /// Creates a wrapper for an entity handle.
  const FilamentEntity(this.id, [this.engine]);

  /// Destroys this entity and all attached Filament components.
  void destroy() {
    if (engine == null) {
      throw StateError('Cannot destroy entity without bound engine');
    }
    engine!.destroyEntity(id);
  }

  bool get isAlive => EntityManager.isAlive(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilamentEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FilamentEntity($id)';
}

/// Alias for raw entity integer ID.
typedef Entity = int;

/// Global manager for entity lifecycles.
class EntityManager {
  static const EntityManager _instance = EntityManager._();
  const EntityManager._();

  /// Gets the singleton [EntityManager] instance.
  static EntityManager get() => _instance;

  /// Creates a single new entity.
  int create() {
    final list = createEntities(1);
    return list.first;
  }

  /// Destroys a single entity handle.
  void destroy(int entity) {
    destroyEntities([entity]);
  }

  /// Bulk creates `n` new entities.
  List<int> createEntitiesInstance(int n) => createEntities(n);

  /// Bulk destroys the given entities.
  void destroyEntitiesInstance(List<int> entities) => destroyEntities(entities);

  /// Checks whether an entity handle (id) is currently alive.
  /// 
  /// The id 0 (null entity) is never alive. Note that `isAlive` correctly
  /// distinguishes recycled-generation handles if a previously destroyed handle
  /// is queried.
  static bool isAlive(int entity) {
    return ffi_gen.filament_entity_manager_is_alive(entity);
  }

  /// Bulk creates `n` new entities in a single FFI call.
  static List<int> createEntities(int n) {
    if (n <= 0) return [];
    final ptr = calloc<ffi.Uint32>(n);
    ffi_gen.filament_entity_manager_create_entities(n, ptr);
    final result = ptr.asTypedList(n).toList();
    calloc.free(ptr);
    return result;
  }

  /// Bulk destroys the given entities in a single FFI call.
  ///
  /// Note: This only destroys the entity handle in the global `EntityManager`.
  /// To properly clean up components (like Renderables or Transforms), you
  /// MUST ALSO use `engine.destroyEntity(entity)` instead, which cleans up
  /// the engine side as well as the entity handle. 
  static void destroyEntities(List<int> entities) {
    if (entities.isEmpty) return;
    final ptr = calloc<ffi.Uint32>(entities.length);
    ptr.asTypedList(entities.length).setAll(0, entities);
    ffi_gen.filament_entity_manager_destroy_entities(entities.length, ptr);
    calloc.free(ptr);
  }

  /// Gets the total number of alive entities process-wide.
  static int get entityCount {
    return ffi_gen.filament_entity_manager_get_entity_count();
  }

  /// Advances the entity lifecycle epoch, sealing dead entities for component manager GC.
  static void advanceEpoch() {
    ffi_gen.filament_entity_manager_advance_epoch();
  }

  /// Listens to entity destruction events via callback.
  static EntityDestructionSubscription addDestructionListener(
    void Function(Uint32List entities) onEntitiesDestroyed,
  ) {
    late ffi.NativeCallable<ffi_gen.FilamentEntityDestructionCallbackFunction> callable;
    callable = ffi.NativeCallable<ffi_gen.FilamentEntityDestructionCallbackFunction>.listener(
      (ffi.Pointer<ffi.Uint32> entitiesPtr, int count, ffi.Pointer<ffi.Void> userData) {
        if (count <= 0 || entitiesPtr == ffi.nullptr) return;
        try {
          final list = Uint32List.fromList(entitiesPtr.asTypedList(count));
          onEntitiesDestroyed(list);
        } finally {
          calloc.free(entitiesPtr);
        }
      },
    );

    final handle = ffi_gen.filament_entity_manager_register_destruction_callback(
      callable.nativeFunction,
      ffi.nullptr,
    );

    return EntityDestructionSubscription._(handle, callable);
  }

  /// Broadcast stream of destroyed entity batches.
  static Stream<Uint32List> get onEntitiesDestroyed {
    late StreamController<Uint32List> controller;
    EntityDestructionSubscription? subscription;

    controller = StreamController<Uint32List>.broadcast(
      onListen: () {
        subscription = addDestructionListener((entities) {
          if (!controller.isClosed) {
            controller.add(entities);
          }
        });
      },
      onCancel: () {
        subscription?.cancel();
        subscription = null;
      },
    );

    return controller.stream;
  }
}

/// Represents an active entity destruction subscription.
class EntityDestructionSubscription {
  final ffi.Pointer<ffi.Void> _nativeHandle;
  final ffi.NativeCallable<ffi_gen.FilamentEntityDestructionCallbackFunction> _callable;
  bool _cancelled = false;

  EntityDestructionSubscription._(this._nativeHandle, this._callable);

  /// Cancels this destruction subscription and frees native resources.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    ffi_gen.filament_entity_manager_unregister_destruction_callback(_nativeHandle);
    _callable.close();
  }

  bool get isCancelled => _cancelled;
}
