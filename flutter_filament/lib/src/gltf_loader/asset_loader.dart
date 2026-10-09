part of '../gltf_loader.dart';

/// Parses glTF and GLB binary files to produce [FilamentAsset] instances.
class FilamentAssetLoader {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentMaterialProvider _materialProvider;
  final FilamentEngine engine;
  final NameComponentManager? names;
  bool _disposed = false;
  final Set<FilamentAsset> _assets = {};

  FilamentAssetLoader._(this._ptr, this._materialProvider, this.engine, [this.names]) {
    _materialProvider._loaders.add(this);
    _liveLoaders.add(this);
  }

  /// Every loader that has not been disposed, across engines.
  static final Set<FilamentAssetLoader> _liveLoaders = {};

  /// Runs [gc] on every live loader of [engine].
  ///
  /// Filament reclaims entity ids by epochs: each component manager keeps a
  /// watermark that only its own `gc()` advances. The engine advances the
  /// epoch and syncs *its* managers on every frame (`FEngine::gc`), but
  /// gltfio's NodeManager and TrsTransformManager belong to the AssetLoader
  /// and are synced only by `AssetLoader::gc()` — which Filament's own apps
  /// call once per frame. Without it, the first gltfio entity destroyed
  /// through the entity manager pins both watermarks and Filament logs
  /// "EBR Stall Warning: Component Manager 'NodeManager' is stalling
  /// reclamation!" every 64 epochs for the rest of the process.
  /// [FilamentRenderer.beginFrame] and [FilamentRenderer.endFrame] call this
  /// after the native call, so no consumer has to. Cheap when the epoch has
  /// not moved (an O(1) early exit in Filament).
  static void collectGarbage(FilamentEngine engine) {
    if (_liveLoaders.isEmpty || engine.isDisposed) return;
    for (final loader in _liveLoaders.toList(growable: false)) {
      if (loader._disposed || !identical(loader.engine, engine)) continue;
      try {
        c.filament_gltfio_asset_loader_gc(loader._ptr);
      } catch (_) {
        // A loader mid-teardown; the next frame retries.
      }
    }
  }

  /// How many live loaders [engine] has (a test seam).
  static int liveLoaderCount(FilamentEngine engine) =>
      _liveLoaders.where((l) => !l._disposed && identical(l.engine, engine)).length;

  /// Creates an AssetLoader.
  static FilamentAssetLoader create({
    required FilamentEngine engine,
    required FilamentMaterialProvider materialProvider,
    NameComponentManager? names,
  }) {
    final ptr = names != null
        ? c.filament_gltfio_asset_loader_create_with_names(
            engine.nativePointer,
            materialProvider.nativePointer,
            names.nativePointer,
          )
        : c.filament_gltfio_asset_loader_create(
            engine.nativePointer,
            materialProvider.nativePointer,
          );
    return FilamentAssetLoader._(ptr, materialProvider, engine, names);
  }

  /// Parses a GLB or glTF 2.0 byte buffer and creates a [FilamentAsset].
  FilamentAsset? createAsset(Uint8List bytes) {
    _checkDisposed();
    // Overwritten in full right away: malloc, not calloc (zeroing a 300 MB
    // GLB first doubles the copy on the calling isolate). Freed by calloc.free
    // like the rest: both allocators share one heap.
    final ptr = malloc<ffi.Uint8>(bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);

    final assetPtr = c.filament_gltfio_asset_loader_create_asset(
      _ptr,
      ptr.cast(),
      bytes.length,
    );

    if (assetPtr == ffi.nullptr) {
      calloc.free(ptr);
      return null;
    }
    final asset = FilamentAsset._(assetPtr, this, ptr, isInstanced: false);
    _assets.add(asset);
    return asset;
  }

  /// Parses a GLB or glTF 2.0 byte buffer and creates an instanced [FilamentAsset] with [instanceCount] instances.
  (FilamentAsset?, List<FilamentAssetInstance>) createInstancedAsset(Uint8List bytes, int instanceCount) {
    _checkDisposed();
    final ptr = malloc<ffi.Uint8>(bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);

    final outInstances = calloc<ffi.Pointer<ffi.Void>>(instanceCount);

    final assetPtr = c.filament_gltfio_asset_loader_create_instanced_asset(
      _ptr,
      ptr.cast(),
      bytes.length,
      outInstances.cast(),
      instanceCount,
    );

    if (assetPtr == ffi.nullptr) {
      calloc.free(outInstances);
      calloc.free(ptr);
      return (null, const []);
    }

    final asset = FilamentAsset._(assetPtr, this, ptr, isInstanced: true);
    _assets.add(asset);

    final instances = <FilamentAssetInstance>[];
    for (var i = 0; i < instanceCount; i++) {
      final instancePtr = outInstances[i];
      if (instancePtr != ffi.nullptr) {
        instances.add(FilamentAssetInstance._(instancePtr, asset));
      }
    }

    calloc.free(outInstances);
    return (asset, instances);
  }

  /// Creates a new instance of a previously loaded [FilamentAsset].
  ///
  /// Fails and returns null if the asset was not loaded as instanced or if `releaseSourceData` was already called.
  FilamentAssetInstance? createInstance(FilamentAsset asset) {
    _checkDisposed();
    if (!asset.isInstanced) return null;
    final instancePtr = c.filament_gltfio_asset_loader_create_instance(_ptr, asset.nativePointer);
    if (instancePtr == ffi.nullptr) return null;
    return FilamentAssetInstance._(instancePtr, asset);
  }

  /// Garbage collects unused internal resources in the asset loader.
  void gc() {
    _checkDisposed();
    c.filament_gltfio_asset_loader_gc(_ptr);
  }

  /// Destroys an asset.
  void destroyAsset(FilamentAsset asset) {
    _checkDisposed();
    c.filament_gltfio_asset_loader_destroy_asset(_ptr, asset.nativePointer);
    if (asset._sourceDataPtr != null) {
      calloc.free(asset._sourceDataPtr!);
      asset._sourceDataPtr = null;
    }
    asset._markDisposed();
    _assets.remove(asset);
  }

  /// Destroys this AssetLoader.
  void dispose() {
    if (_disposed) return;
    if (_assets.isNotEmpty) {
      throw StateError('Cannot dispose AssetLoader while FilamentAssets are still active.');
    }
    _disposed = true;
    _liveLoaders.remove(this);
    _materialProvider._loaders.remove(this);
    c.filament_gltfio_asset_loader_destroy(_ptr);
  }

  FilamentNodeManager? _nodeManager;

  /// Gets the NodeManager for accessing node attributes like extras and morph targets.
  FilamentNodeManager get nodeManager {
    _checkDisposed();
    if (_nodeManager == null) {
      final ptr = c.filament_gltfio_asset_loader_get_node_manager(_ptr);
      if (ptr != ffi.nullptr) {
        _nodeManager = FilamentNodeManager._(ptr);
      } else {
        throw StateError("NodeManager is not available.");
      }
    }
    return _nodeManager!;
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentAssetLoader has been disposed');
    }
  }
}
