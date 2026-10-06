import 'ffi_platform.dart' as ffi;

import 'ffi_package_platform.dart';

import 'engine.dart';
import 'indirect_light.dart';
import 'ray_tracing.dart';
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

  /// Whether the scene keeps ray tracing acceleration structures: one
  /// bottom-level structure per primitive geometry and a top-level one over the
  /// world transforms of its renderables, rebuilt every frame the scene renders.
  ///
  /// Needs [FilamentEngine.supportsRayQuery]; otherwise the flag is kept but
  /// nothing is built. Default false. See [RayTracing].
  bool get rayTracingEnabled {
    _checkDisposed();
    return c.filament_scene_get_ray_tracing_enabled(_ptr);
  }

  set rayTracingEnabled(bool enabled) {
    _checkDisposed();
    c.filament_scene_set_ray_tracing_enabled(_ptr, enabled);
  }

  /// How many renderables the top-level acceleration structure held after the
  /// last rendered frame (0 while ray tracing is off or unsupported).
  int get tlasInstanceCount {
    _checkDisposed();
    return c.filament_scene_get_tlas_instance_count(_ptr);
  }

  /// GPU time of the last top-level structure build ([Duration.zero] until a
  /// timer query resolved).
  Duration get lastTlasBuildTime {
    _checkDisposed();
    final nanos = c.filament_scene_get_tlas_build_nanos(_ptr);
    return Duration(microseconds: nanos ~/ 1000);
  }

  /// Traces one visibility ray from ([ox], [oy], [oz]) along ([dx], [dy],
  /// [dz]) against the acceleration structures and waits for the answer.
  ///
  /// A test and tooling hook: it renders the scene through a temporary 1x1 view
  /// (which also rebuilds the structures from the current transforms), so call
  /// it between frames, never while a frame of your renderer is open. Returns
  /// `null` on a miss, when the hit is farther than [maxDistance], or when ray
  /// tracing is off or unsupported. Use [FilamentView.traceRay] for queries
  /// answered by the frames you render anyway.
  Future<RayHit?> traceVisibility(double ox, double oy, double oz, double dx, double dy, double dz,
      {double maxDistance = 1.0e5}) async {
    _checkDisposed();
    final origin = calloc<ffi.Float>(3);
    final direction = calloc<ffi.Float>(3);
    final distance = calloc<ffi.Float>();
    final entity = calloc<ffi.Uint32>();
    final primitive = calloc<ffi.Uint32>();
    try {
      origin[0] = ox;
      origin[1] = oy;
      origin[2] = oz;
      direction[0] = dx;
      direction[1] = dy;
      direction[2] = dz;
      final hit = c.filament_scene_trace_visibility(
          _engine.nativePointer, _ptr, origin, direction, maxDistance, distance, entity, primitive);
      if (!hit) return null;
      return RayHit(t: distance.value, entity: entity.value, primitive: primitive.value);
    } finally {
      calloc.free(origin);
      calloc.free(direction);
      calloc.free(distance);
      calloc.free(entity);
      calloc.free(primitive);
    }
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
