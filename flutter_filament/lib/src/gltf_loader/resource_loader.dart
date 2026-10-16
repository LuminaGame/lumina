part of '../gltf_loader.dart';

/// Controls loading external buffer/texture resources for a [FilamentAsset].
class FilamentResourceLoader {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  FilamentResourceLoader._(this._ptr);

  /// Creates a ResourceLoader.
  ///
  /// External buffers and textures reach it through [addResourceData].
  /// [defaultPath] (the glTF file's path, for resolving their relative URIs
  /// on disk) is deprecated in Filament, which plans to remove it.
  static FilamentResourceLoader create({
    required FilamentEngine engine,
    @Deprecated('Feed external buffers and textures with addResourceData; Filament deprecated ResourceConfiguration::gltfPath.')
    String? defaultPath,
    bool normalizeSkinningWeights = true,
  }) {
    ffi.Pointer<Utf8> nativePath = ffi.nullptr.cast();
    if (defaultPath != null) {
      nativePath = defaultPath.toNativeUtf8();
    }
    final ptr = c.filament_gltfio_resource_loader_create(
      engine.nativePointer,
      nativePath.cast(),
      normalizeSkinningWeights,
    );
    if (defaultPath != null) {
      calloc.free(nativePath);
    }
    return FilamentResourceLoader._(ptr);
  }

  /// Loads resources (buffers, textures) for [asset].
  bool loadResources(FilamentAsset asset) {
    _checkDisposed();
    return c.filament_gltfio_resource_loader_load_resources(
      _ptr,
      asset.nativePointer,
    );
  }

  /// Destroys this ResourceLoader. A [loadAsync] still in flight fails with a
  /// [StateError] and its progress poll is cancelled at once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopAsyncLoads(StateError('ResourceLoader was disposed during loadAsync'));
    c.filament_gltfio_resource_loader_destroy(_ptr);
  }

  /// The [loadAsync] calls still polling, each with its pending poll timer.
  final Map<Completer<void>, Timer?> _asyncLoads = {};

  /// Cancels every pending [loadAsync] poll and fails its future with [error]:
  /// a `Future.delayed` poll could not be cancelled, so a loader (or a widget
  /// that owned it) torn down mid-load left a timer behind that only noticed
  /// on its next tick.
  void _stopAsyncLoads(Object error) {
    final loads = Map.of(_asyncLoads);
    _asyncLoads.clear();
    loads.forEach((completer, timer) {
      timer?.cancel();
      if (!completer.isCompleted) completer.completeError(error);
    });
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentResourceLoader has been disposed');
    }
  }
  /// Configures this ResourceLoader.
  void setConfiguration({
    @Deprecated('Feed external buffers and textures with addResourceData; Filament deprecated ResourceConfiguration::gltfPath.')
    String? gltfPath,
    bool normalizeSkinningWeights = true,
  }) {
    _checkDisposed();
    ffi.Pointer<Utf8> nativePath = ffi.nullptr.cast();
    if (gltfPath != null) {
      nativePath = gltfPath.toNativeUtf8();
    }
    c.filament_gltfio_resource_loader_set_configuration(
      _ptr,
      nativePath.cast(),
      normalizeSkinningWeights,
    );
    if (gltfPath != null) {
      calloc.free(nativePath);
    }
  }

  /// Registers a TextureProvider for a specific MIME type.
  void addTextureProvider(String mime, TextureProvider provider) {
    _checkDisposed();
    final nativeMime = mime.toNativeUtf8();
    c.filament_gltfio_resource_loader_add_texture_provider(
      _ptr,
      nativeMime.cast(),
      provider.nativePointer,
    );
    calloc.free(nativeMime);
  }

  /// Feeds binary data for a specific URI into the loader.
  void addResourceData(String uri, Uint8List data) {
    _checkDisposed();
    final nativeUri = uri.toNativeUtf8();
    final ptr = malloc<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    c.filament_gltfio_resource_loader_add_resource_data(
      _ptr,
      nativeUri.cast(),
      ptr.cast(),
      data.length,
    );
    
    calloc.free(nativeUri);
    // Note: the C side takes ownership and frees ptr, wait! The C side copies the data! 
    // Wait, in my C implementation, I do:
    // uint8_t* copied_data = (uint8_t*)malloc(size); memcpy(copied_data, data, size);
    // So the C side makes its own copy, and I MUST free `ptr` here!
    calloc.free(ptr);
  }

  /// Checks if resource data for [uri] is present.
  bool hasResourceData(String uri) {
    _checkDisposed();
    final nativeUri = uri.toNativeUtf8();
    final result = c.filament_gltfio_resource_loader_has_resource_data(
      _ptr,
      nativeUri.cast(),
    );
    calloc.free(nativeUri);
    return result;
  }

  /// Evicts all resource data from the cache.
  void evictResourceData() {
    _checkDisposed();
    c.filament_gltfio_resource_loader_evict_resource_data(_ptr);
  }

  /// Begins asynchronous loading for [asset].
  void asyncBeginLoad(FilamentAsset asset) {
    _checkDisposed();
    c.filament_gltfio_resource_loader_async_begin_load(_ptr, asset.nativePointer);
  }

  /// Updates the async loading process. Must be called repeatedly (e.g. per frame).
  void asyncUpdateLoad() {
    _checkDisposed();
    c.filament_gltfio_resource_loader_async_update_load(_ptr);
  }

  /// Gets the async loading progress [0, 1].
  double asyncGetLoadProgress() {
    _checkDisposed();
    return c.filament_gltfio_resource_loader_async_get_load_progress(_ptr);
  }

  /// Cancels an in-progress async load. A pending [loadAsync] fails with a
  /// [StateError] and stops polling.
  void asyncCancelLoad() {
    _checkDisposed();
    c.filament_gltfio_resource_loader_async_cancel_load(_ptr);
    _stopAsyncLoads(StateError('loadAsync was cancelled'));
  }

  /// Helper to asynchronously load all resources with a progress callback.
  ///
  /// Polls every 16 ms on a [Timer] this loader owns: [asyncCancelLoad] and
  /// [dispose] cancel it, so nothing is left pending once either returns.
  Future<void> loadAsync(FilamentAsset asset, {void Function(double progress)? onProgress}) {
    _checkDisposed();
    asyncBeginLoad(asset);

    final completer = Completer<void>();
    _asyncLoads[completer] = null;

    void fail(Object error) {
      _asyncLoads.remove(completer);
      if (!completer.isCompleted) completer.completeError(error);
    }

    void checkProgress() {
      if (!_asyncLoads.containsKey(completer)) return;
      if (_disposed) return fail(StateError('ResourceLoader was disposed during loadAsync'));
      if (asset.isDisposed) return fail(StateError('FilamentAsset was disposed during loadAsync'));

      final double progress;
      try {
        asyncUpdateLoad();
        progress = asyncGetLoadProgress();
        onProgress?.call(progress);
      } catch (e) {
        return fail(e);
      }

      if (!_asyncLoads.containsKey(completer)) return; // onProgress cancelled it
      if (progress >= 1.0) {
        _asyncLoads.remove(completer);
        completer.complete();
      } else {
        _asyncLoads[completer] = Timer(const Duration(milliseconds: 16), checkProgress);
      }
    }

    checkProgress();
    return completer.future;
  }

  /// Registers standard texture providers: stb (PNG/JPG), ktx2, and webp if available.
  void registerDefaultProviders(FilamentEngine engine) {
    _checkDisposed();
    addTextureProvider('image/jpeg', TextureProvider.stb(engine: engine));
    addTextureProvider('image/png', TextureProvider.stb(engine: engine));
    addTextureProvider('image/ktx2', TextureProvider.ktx2(engine: engine));
    // Note: glTF usually registers webp too, but it needs a WebP provider.
    try {
      addTextureProvider('image/webp', TextureProvider.webp(engine: engine));
    } catch (_) {
      // Ignore if webp is not supported
    }
  }
}

/// Represents a native Filament C++ Vulkan GPU Wireframe Mesh entity built from positions & indices.
class FilamentWireframeMesh {
  final ffi.Pointer<ffi.Void> _handle;
  final FilamentEngine _engine;
  bool _disposed = false;

  FilamentWireframeMesh._(this._handle, this._engine);

  /// Creates a native C++ Filament LINES wireframe mesh entity from 3D vertex positions and triangle indices.
  static FilamentWireframeMesh? create({
    required FilamentEngine engine,
    required List<double> positions,
    required List<int> indices,
  }) {
    if (positions.isEmpty || indices.isEmpty) return null;

    final posPtr = calloc<ffi.Float>(positions.length);
    posPtr.asTypedList(positions.length).setAll(0, positions);

    final indPtr = calloc<ffi.Uint32>(indices.length);
    indPtr.asTypedList(indices.length).setAll(0, indices);

    final handle = c.filament_gltf_create_mesh_wireframe(
      engine.nativePointer,
      posPtr,
      positions.length ~/ 3,
      indPtr,
      indices.length,
    );

    calloc.free(posPtr);
    calloc.free(indPtr);

    if (handle == ffi.nullptr) return null;
    return FilamentWireframeMesh._(handle, engine);
  }

  /// Creates a native C++ Filament LINES wireframe mesh entity from 3D vertex positions and direct line index pairs.
  static FilamentWireframeMesh? createLineSegments({
    required FilamentEngine engine,
    required List<double> positions,
    required List<int> lineIndices,
  }) {
    if (positions.isEmpty || lineIndices.isEmpty) return null;

    final posPtr = calloc<ffi.Float>(positions.length);
    posPtr.asTypedList(positions.length).setAll(0, positions);

    final indPtr = calloc<ffi.Uint32>(lineIndices.length);
    indPtr.asTypedList(lineIndices.length).setAll(0, lineIndices);

    final handle = c.filament_create_line_segments_mesh(
      engine.nativePointer,
      posPtr,
      positions.length ~/ 3,
      indPtr,
      lineIndices.length,
    );

    calloc.free(posPtr);
    calloc.free(indPtr);

    if (handle == ffi.nullptr) return null;
    return FilamentWireframeMesh._(handle, engine);
  }

  /// Gets the native Filament C++ entity ID for adding to [FilamentScene].
  /// Sets the base color of the wireframe mesh.
  void setColor(double r, double g, double b, double a) {
    _checkDisposed();
    c.filament_wireframe_set_color(_handle, r, g, b, a);
  }

  /// Whether this mesh owns a compiled material instance.
  ///
  /// False means the wireframe material failed to compile and Filament is
  /// drawing the lines with its default material, which ignores [setColor]:
  /// every wireframe comes out white. That is worth failing a test over,
  /// because nothing else about the render looks wrong.
  bool get hasMaterial {
    _checkDisposed();
    return c.filament_wireframe_has_material(_handle) != 0;
  }

  int get entityId {
    _checkDisposed();
    return c.filament_wireframe_handle_get_entity(_handle);
  }

  /// Destroys the native Filament wireframe mesh entity, vertex buffer, and index buffer.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_wireframe_handle_destroy(_engine.nativePointer, _handle);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentWireframeMesh has been disposed');
    }
  }
}
