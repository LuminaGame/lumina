part of '../gltf_loader.dart';

/// A loaded glTF 2.0 3D model asset containing entities, transforms, materials, and animations.
class FilamentAsset {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentAssetLoader _loader;
  ffi.Pointer<ffi.Uint8>? _sourceDataPtr;
  bool _disposed = false;
  FilamentAssetInstance? _instance;
  final bool isInstanced;

  FilamentAsset._(this._ptr, this._loader, this._sourceDataPtr, {required this.isInstanced});

  /// Gets the primary instance of this asset.
  FilamentAssetInstance? get instance {
    _checkDisposed();
    if (_instance != null) return _instance;
    final ptr = c.filament_gltfio_asset_get_instance(_ptr);
    if (ptr == ffi.nullptr) return null;
    _instance = FilamentAssetInstance._(ptr, this);
    return _instance;
  }

  FilamentTrsTransformManager? _trsTransformManager;

  /// Gets the TrsTransformManager for procedural animation of nodes.
  FilamentTrsTransformManager get trsTransformManager {
    _checkDisposed();
    if (_trsTransformManager == null) {
      final ptr = c.filament_gltfio_trs_transform_manager_get(_ptr);
      if (ptr != ffi.nullptr) {
        _trsTransformManager = FilamentTrsTransformManager._(ptr);
      } else {
        throw StateError("TrsTransformManager is not available.");
      }
    }
    return _trsTransformManager!;
  }

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Gets the root entity of the asset hierarchy.
  int get rootEntity {
    _checkDisposed();
    return c.filament_gltfio_asset_get_root(_ptr);
  }

  /// Gets the total number of entities in the asset.
  int get entityCount {
    _checkDisposed();
    return c.filament_gltfio_asset_get_entity_count(_ptr);
  }

  /// Gets all entity IDs in the asset corresponding 1-to-1 with glTF nodes.
  List<int> get entities {
    _checkDisposed();
    final count = entityCount;
    if (count == 0) return [];
    final ptr = c.filament_gltfio_asset_get_entities(_ptr);
    if (ptr == ffi.nullptr) return [];
    return ptr.asTypedList(count).toList();
  }

  /// Adds all entities in this asset to [scene].
  void addToScene(FilamentScene scene) {
    _checkDisposed();
    c.filament_scene_add_asset_entities(scene.nativePointer, _ptr);
  }

  /// Adds specific entities from this asset to [scene].
  void addEntitiesToScene(FilamentScene scene, List<int> entities, {int sceneMask = 1}) {
    _checkDisposed();
    if (entities.isEmpty) return;
    final ptr = calloc<ffi.Uint32>(entities.length);
    for (int i = 0; i < entities.length; i++) {
      ptr[i] = entities[i];
    }
    c.filament_gltfio_asset_add_entities_to_scene(_ptr, scene.nativePointer, ptr, entities.length, sceneMask);
    calloc.free(ptr);
  }

  /// Removes all entities in this asset from [scene].
  void removeFromScene(FilamentScene scene) {
    _checkDisposed();
    c.filament_scene_remove_asset_entities(scene.nativePointer, _ptr);
  }

  /// Releases temporary source glTF JSON/buffer memory after loading resources.
  void releaseSourceData() {
    _checkDisposed();
    c.filament_gltfio_asset_release_source_data(_ptr);
    if (_sourceDataPtr != null) {
      calloc.free(_sourceDataPtr!);
      _sourceDataPtr = null;
    }
  }

  /// Gets the [FilamentAnimator] interface for playing glTF animations.
  FilamentAnimator get animator {
    _checkDisposed();
    final animPtr = c.filament_gltfio_asset_get_animator(_ptr);
    return FilamentAnimator._(animPtr);
  }

  /// Returns the wireframe entity for diagnostic lines rendering.
  int getWireframeEntity() {
    _checkDisposed();
    return c.filament_gltfio_asset_get_wireframe(_ptr);
  }

  /// Gets the glTF node name for [entity], or null if unnamed.
  String? getEntityName(int entity) {
    _checkDisposed();
    final ptr = c.filament_gltfio_asset_get_entity_name(_ptr, entity);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Gets the extras JSON string for [entity], or null if none.
  String? getExtras(int entity) {
    _checkDisposed();
    final ptr = c.filament_gltfio_asset_get_extras(_ptr, entity);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Gets the number of morph targets for [entity].
  int getMorphTargetCountAt(int entity) {
    _checkDisposed();
    return c.filament_gltfio_asset_get_morph_target_count_at(_ptr, entity);
  }

  /// Gets the morph target name for [entity] at [target] index, or null.
  String? getMorphTargetNameAt(int entity, int target) {
    _checkDisposed();
    final ptr = c.filament_gltfio_asset_get_morph_target_name_at(_ptr, entity, target);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Gets the first entity ID matching [name], or 0 if not found.
  int getFirstEntityByName(String name) {
    _checkDisposed();
    final namePtr = name.toNativeUtf8();
    final result = c.filament_gltfio_asset_get_first_entity_by_name(_ptr, namePtr.cast());
    calloc.free(namePtr);
    return result;
  }

  /// Gets all entity IDs matching [name].
  List<int> getEntitiesByName(String name) {
    _checkDisposed();
    final namePtr = name.toNativeUtf8();
    final count = c.filament_gltfio_asset_get_entities_by_name(_ptr, namePtr.cast(), ffi.nullptr, 0);
    if (count == 0) {
      calloc.free(namePtr);
      return [];
    }
    final outPtr = calloc<ffi.Uint32>(count);
    final written = c.filament_gltfio_asset_get_entities_by_name(_ptr, namePtr.cast(), outPtr, count);
    calloc.free(namePtr);
    final result = outPtr.asTypedList(written).toList();
    calloc.free(outPtr);
    return result;
  }

  /// Gets the axis-aligned bounding box of the asset.
  Aabb getBoundingBox() {
    _checkDisposed();
    final ptrMin = calloc<ffi.Float>(3);
    final ptrMax = calloc<ffi.Float>(3);
    c.filament_gltfio_asset_get_bounding_box(_ptr, ptrMin, ptrMax);
    final min = Vector3(ptrMin[0], ptrMin[1], ptrMin[2]);
    final max = Vector3(ptrMax[0], ptrMax[1], ptrMax[2]);
    calloc.free(ptrMin);
    calloc.free(ptrMax);
    return Aabb(min: min, max: max);
  }

  /// Gets the total number of scenes in this asset.
  int getSceneCount() {
    _checkDisposed();
    return c.filament_gltfio_asset_get_scene_count(_ptr);
  }

  /// Gets the name of the scene at [sceneIndex], or null if unnamed.
  String? getSceneName(int sceneIndex) {
    _checkDisposed();
    final ptr = c.filament_gltfio_asset_get_scene_name(_ptr, sceneIndex);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Pops renderables from this asset's ownership into a list, up to [max].
  List<int> _entityList(int Function(ffi.Pointer<ffi.Void>) count,
      ffi.Pointer<ffi.Uint32> Function(ffi.Pointer<ffi.Void>) getter) {
    _checkDisposed();
    final n = count(_ptr);
    if (n == 0) return const [];
    final ptr = getter(_ptr);
    if (ptr == ffi.nullptr) return const [];
    return ptr.asTypedList(n).toList();
  }

  /// Number of entities in this asset that have a renderable component.
  int get renderableEntityCount {
    _checkDisposed();
    return c.filament_gltfio_asset_get_renderable_entity_count(_ptr);
  }

  /// Entities in this asset that have a renderable component.
  List<int> get renderableEntities => _entityList(
      c.filament_gltfio_asset_get_renderable_entity_count,
      c.filament_gltfio_asset_get_renderable_entities);

  /// Number of entities in this asset that have a light component.
  int get lightEntityCount {
    _checkDisposed();
    return c.filament_gltfio_asset_get_light_entity_count(_ptr);
  }

  /// Entities in this asset that have a light component (KHR_lights_punctual).
  List<int> get lightEntities => _entityList(
      c.filament_gltfio_asset_get_light_entity_count,
      c.filament_gltfio_asset_get_light_entities);

  /// Number of entities in this asset that have a camera component.
  int get cameraEntityCount {
    _checkDisposed();
    return c.filament_gltfio_asset_get_camera_entity_count(_ptr);
  }

  /// Entities in this asset that have a camera component.
  List<int> get cameraEntities => _entityList(
      c.filament_gltfio_asset_get_camera_entity_count,
      c.filament_gltfio_asset_get_camera_entities);

  /// Number of external resource URIs referenced by this asset.
  int get resourceUriCount {
    _checkDisposed();
    return c.filament_gltfio_asset_get_resource_uri_count(_ptr);
  }

  /// External resource URIs (buffers/images) referenced by this asset.
  List<String> get resourceUris {
    _checkDisposed();
    final n = c.filament_gltfio_asset_get_resource_uri_count(_ptr);
    final out = <String>[];
    for (var i = 0; i < n; i++) {
      final p = c.filament_gltfio_asset_get_resource_uri_at(_ptr, i);
      if (p != ffi.nullptr) out.add(p.cast<Utf8>().toDartString());
    }
    return out;
  }

  /// Pops one not-yet-popped renderable entity, or returns 0 when none remain.
  ///
  /// Useful for progressive scene population while resources stream in.
  int popRenderable() {
    _checkDisposed();
    return c.filament_gltfio_asset_pop_renderable(_ptr);
  }

  List<int> popRenderables(int max) {
    _checkDisposed();
    if (max <= 0) return [];
    final outPtr = calloc<ffi.Uint32>(max);
    final count = c.filament_gltfio_asset_pop_renderables(_ptr, outPtr, max);
    final result = outPtr.asTypedList(count).toList();
    calloc.free(outPtr);
    return result;
  }

  /// Detaches Filament components from this asset's ownership.
  void detachFilamentComponents() {
    _checkDisposed();
    c.filament_gltfio_asset_detach_filament_components(_ptr);
  }


  /// Destroys this asset via its asset loader.
  void dispose() {
    if (_disposed) return;
    _loader.destroyAsset(this);
  }

  void _markDisposed() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentAsset has been disposed');
    }
  }
}
