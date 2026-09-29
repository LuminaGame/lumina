import 'ffi_platform.dart' as ffi;

import 'ffi_package_platform.dart';

import 'engine.dart';
import 'indirect_light.dart';
import 'skybox.dart';
import 'filament_bindings.dart' as c;
import 'view.dart';

/// A Scene is a flat container of Renderable and Light instances.
///
/// Renderables and Lights must be added to a Scene to be rendered.
class FilamentScene {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor.
  FilamentScene.internal(this._ptr, this._engine);

  /// The raw native pointer to the Filament Scene.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Populates this scene with the official Filament 3D Suzanne Monkey model,
  /// including all 5 PBR KTX2 textures (Albedo, AO, Metallic, Roughness, Normal Map).
  int createSuzanneSample(FilamentView view) {
    _checkDisposed();
    return c.filament_suzanne_sample_create(
      _engine.nativePointer,
      view.nativePointer,
      _ptr,
    );
  }

  /// Destroys all Suzanne 3D sample resources cleanly before engine disposal.
  void destroySuzanneSample() {
    if (_disposed) return;
    c.filament_suzanne_sample_destroy(_engine.nativePointer, _ptr);
  }

  /// Adds an entity to this scene.
  ///
  /// The entity is ignored for rendering purposes if it doesn't have
  /// a Renderable or Light component.
  void addEntity(int entity) {
    _checkDisposed();
    c.filament_scene_add_entity(_ptr, entity);
  }

  /// Adds a list of entities to the scene in a single batch FFI call.
  void addEntities(List<int> entities) {
    _checkDisposed();
    if (entities.isEmpty) return;
    final ptr = calloc<ffi.Uint32>(entities.length);
    try {
      ptr.asTypedList(entities.length).setAll(0, entities);
      c.filament_scene_add_entities(_ptr, ptr, entities.length);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Removes an entity from this scene.
  void removeEntity(int entity) {
    _checkDisposed();
    c.filament_scene_remove_entity(_ptr, entity);
  }

  /// Removes a list of entities from the scene in a single batch FFI call.
  void removeEntities(List<int> entities) {
    _checkDisposed();
    if (entities.isEmpty) return;
    final ptr = calloc<ffi.Uint32>(entities.length);
    try {
      ptr.asTypedList(entities.length).setAll(0, entities);
      c.filament_scene_remove_entities(_ptr, ptr, entities.length);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Removes all entities from the scene.
  void removeAllEntities() {
    _checkDisposed();
    c.filament_scene_remove_all_entities(_ptr);
  }

  /// Returns true if the given entity is present in the scene.
  bool hasEntity(int entity) {
    _checkDisposed();
    return c.filament_scene_has_entity(_ptr, entity);
  }

  /// Sets the Image-Based Lighting (IBL) IndirectLight for this scene.
  void setIndirectLight(FilamentIndirectLight? indirectLight) {
    _checkDisposed();
    c.filament_scene_set_indirect_light(
      _ptr,
      indirectLight?.nativePointer ?? ffi.nullptr,
    );
  }

  /// The currently attached [FilamentIndirectLight], or null if none is set.
  FilamentIndirectLight? get indirectLight {
    _checkDisposed();
    final ptr = c.filament_scene_get_indirect_light(_ptr);
    if (ptr == ffi.nullptr) return null;
    return FilamentIndirectLight.internal(ptr, _engine);
  }

  set indirectLight(FilamentIndirectLight? value) => setIndirectLight(value);

  /// Sets the background Skybox for this scene.
  void setSkybox(FilamentSkybox? skybox) {
    _checkDisposed();
    c.filament_scene_set_skybox(
      _ptr,
      skybox?.nativePointer ?? ffi.nullptr,
    );
  }

  /// The currently attached [FilamentSkybox], or null if none is set.
  FilamentSkybox? get skybox {
    _checkDisposed();
    final ptr = c.filament_scene_get_skybox(_ptr);
    if (ptr == ffi.nullptr) return null;
    return FilamentSkybox.internal(ptr, _engine);
  }

  set skybox(FilamentSkybox? value) => setSkybox(value);

  /// Returns the total number of entities in this scene.
  int get entityCount {
    _checkDisposed();
    return c.filament_scene_get_entity_count(_ptr);
  }

  /// Returns the number of active renderable objects in this scene.
  int get renderableCount {
    _checkDisposed();
    return c.filament_scene_get_renderable_count(_ptr);
  }

  /// Returns the number of active light objects in this scene.
  int get lightCount {
    _checkDisposed();
    return c.filament_scene_get_light_count(_ptr);
  }

  /// Destroys this scene and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_scene(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentScene has been disposed');
    }
  }
}
