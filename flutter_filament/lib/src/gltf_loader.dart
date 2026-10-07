import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'dart:async';

import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/math/box.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/texture_provider.dart';
import 'package:flutter_filament/src/material.dart';
import 'package:flutter_filament/src/name_component_manager.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Configuration for glTF materials
class MaterialKey {
  bool doubleSided;
  bool unlit;
  bool hasVertexColors;
  bool hasBaseColorTexture;
  bool hasNormalTexture;
  bool hasOcclusionTexture;
  bool hasEmissiveTexture;
  bool useSpecularGlossiness;
  int alphaMode;
  bool enableDiagnostics;
  bool hasMetallicRoughnessTexture;
  int metallicRoughnessUV;
  bool hasSpecularGlossinessTexture;
  int specularGlossinessUV;
  int baseColorUV;
  bool hasClearCoatTexture;
  int clearCoatUV;
  bool hasClearCoatRoughnessTexture;
  int clearCoatRoughnessUV;
  bool hasClearCoatNormalTexture;
  int clearCoatNormalUV;
  bool hasClearCoat;
  bool hasTransmission;
  bool hasTextureTransforms;
  int emissiveUV;
  int aoUV;
  int normalUV;
  bool hasTransmissionTexture;
  int transmissionUV;
  bool hasSheenColorTexture;
  int sheenColorUV;
  bool hasSheenRoughnessTexture;
  int sheenRoughnessUV;
  bool hasVolumeThicknessTexture;
  int volumeThicknessUV;
  bool hasSheen;
  bool hasIOR;
  bool hasVolume;
  bool hasDispersion;
  bool hasSpecular;
  bool hasSpecularTexture;
  bool hasSpecularColorTexture;
  int specularTextureUV;
  int specularColorTextureUV;

  MaterialKey({
    this.doubleSided = false,
    this.unlit = false,
    this.hasVertexColors = false,
    this.hasBaseColorTexture = false,
    this.hasNormalTexture = false,
    this.hasOcclusionTexture = false,
    this.hasEmissiveTexture = false,
    this.useSpecularGlossiness = false,
    this.alphaMode = 0,
    this.enableDiagnostics = false,
    this.hasMetallicRoughnessTexture = false,
    this.metallicRoughnessUV = 0,
    this.hasSpecularGlossinessTexture = false,
    this.specularGlossinessUV = 0,
    this.baseColorUV = 0,
    this.hasClearCoatTexture = false,
    this.clearCoatUV = 0,
    this.hasClearCoatRoughnessTexture = false,
    this.clearCoatRoughnessUV = 0,
    this.hasClearCoatNormalTexture = false,
    this.clearCoatNormalUV = 0,
    this.hasClearCoat = false,
    this.hasTransmission = false,
    this.hasTextureTransforms = false,
    this.emissiveUV = 0,
    this.aoUV = 0,
    this.normalUV = 0,
    this.hasTransmissionTexture = false,
    this.transmissionUV = 0,
    this.hasSheenColorTexture = false,
    this.sheenColorUV = 0,
    this.hasSheenRoughnessTexture = false,
    this.sheenRoughnessUV = 0,
    this.hasVolumeThicknessTexture = false,
    this.volumeThicknessUV = 0,
    this.hasSheen = false,
    this.hasIOR = false,
    this.hasVolume = false,
    this.hasDispersion = false,
    this.hasSpecular = false,
    this.hasSpecularTexture = false,
    this.hasSpecularColorTexture = false,
    this.specularTextureUV = 0,
    this.specularColorTextureUV = 0,
  });
}

/// Result of creating a material instance via MaterialProvider.
class MaterialProviderResult {
  final FilamentMaterialInstance? instance;
  final MaterialKey key;
  final List<int> uvMap; // Array of 8 integers representing UvMap

  MaterialProviderResult({
    required this.instance,
    required this.key,
    required this.uvMap,
  });
}

/// Material provider using ubershader materials for glTF rendering.
class FilamentMaterialProvider {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine engine;
  bool _disposed = false;
  final Set<FilamentAssetLoader> _loaders = {};

  FilamentMaterialProvider._(this._ptr, this.engine);

  /// Creates a MaterialProvider using JIT filamat material compilation.
  static FilamentMaterialProvider jit(
    FilamentEngine engine, {
    bool optimizeShaders = false,
  }) {
    final providerPtr = c.filament_gltfio_create_jit_material_provider_ex(
      engine.nativePointer,
      optimizeShaders,
    );
    return FilamentMaterialProvider._(providerPtr, engine);
  }

  /// Creates a MaterialProvider using JIT filamat material compilation (legacy).
  static FilamentMaterialProvider createJitShader({
    required FilamentEngine engine,
  }) {
    return jit(engine);
  }

  /// Creates a MaterialProvider using ubershader materials.
  static FilamentMaterialProvider ubershader(FilamentEngine engine, {Uint8List? archiveData}) {
    return createUbershader(engine: engine, archiveData: archiveData);
  }

  /// Creates a MaterialProvider using ubershader materials.
  static FilamentMaterialProvider createUbershader({
    required FilamentEngine engine,
    Uint8List? archiveData,
  }) {
    if (archiveData == null || archiveData.isEmpty) {
      final providerPtr = c.filament_gltfio_create_ubershader_provider(
        engine.nativePointer,
        ffi.nullptr,
        0,
      );
      return FilamentMaterialProvider._(providerPtr, engine);
    }
    final ptr = calloc<ffi.Uint8>(archiveData.length);
    ptr.asTypedList(archiveData.length).setAll(0, archiveData);

    final providerPtr = c.filament_gltfio_create_ubershader_provider(
      engine.nativePointer,
      ptr.cast(),
      archiveData.length,
    );
    calloc.free(ptr);

    return FilamentMaterialProvider._(providerPtr, engine);
  }

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  bool _materialsDestroyed = false;

  /// Returns the number of cached Material instances owned by this provider.
  int get materialsCount {
    _checkDisposed();
    return c.filament_gltfio_material_provider_get_materials_count(_ptr);
  }

  /// Returns the cached Material instances owned by this provider.
  List<FilamentMaterial?> get materials {
    _checkDisposed();
    final count = materialsCount;
    if (count == 0) return [];

    final outPtr = calloc<ffi.Pointer<ffi.Void>>(count);
    final written = c.filament_gltfio_material_provider_get_materials(_ptr, outPtr.cast(), count);
    
    final result = <FilamentMaterial?>[];
    for (var i = 0; i < written; i++) {
      if (outPtr[i] != ffi.nullptr) {
        result.add(FilamentMaterial.internal(outPtr[i], engine));
      } else {
        result.add(null);
      }
    }
    
    calloc.free(outPtr);
    return result;
  }

  /// Check if the material provider needs dummy data for a vertex attribute (e.g. UV0).
  bool needsDummyData(int vertexAttribute) {
    _checkDisposed();
    return c.filament_gltfio_material_provider_needs_dummy_data(_ptr, vertexAttribute);
  }

  /// Creates a MaterialInstance given a MaterialKey configuration.
  /// The returned key may be constrained by the provider.
  MaterialProviderResult createMaterialInstance(MaterialKey key, {String? label, String? extras}) {
    _checkDisposed();
    
    final configPtr = calloc<c.filament_gltfio_material_key_t>();
    configPtr.ref.doubleSided = key.doubleSided ? 1 : 0;
    configPtr.ref.unlit = key.unlit ? 1 : 0;
    configPtr.ref.hasVertexColors = key.hasVertexColors ? 1 : 0;
    configPtr.ref.hasBaseColorTexture = key.hasBaseColorTexture ? 1 : 0;
    configPtr.ref.hasNormalTexture = key.hasNormalTexture ? 1 : 0;
    configPtr.ref.hasOcclusionTexture = key.hasOcclusionTexture ? 1 : 0;
    configPtr.ref.hasEmissiveTexture = key.hasEmissiveTexture ? 1 : 0;
    configPtr.ref.useSpecularGlossiness = key.useSpecularGlossiness ? 1 : 0;
    configPtr.ref.alphaMode = key.alphaMode;
    configPtr.ref.enableDiagnostics = key.enableDiagnostics ? 1 : 0;
    configPtr.ref.hasMetallicRoughnessTexture = key.hasMetallicRoughnessTexture ? 1 : 0;
    configPtr.ref.metallicRoughnessUV = key.metallicRoughnessUV;
    configPtr.ref.hasSpecularGlossinessTexture = key.hasSpecularGlossinessTexture ? 1 : 0;
    configPtr.ref.specularGlossinessUV = key.specularGlossinessUV;
    configPtr.ref.baseColorUV = key.baseColorUV;
    configPtr.ref.hasClearCoatTexture = key.hasClearCoatTexture ? 1 : 0;
    configPtr.ref.clearCoatUV = key.clearCoatUV;
    configPtr.ref.hasClearCoatRoughnessTexture = key.hasClearCoatRoughnessTexture ? 1 : 0;
    configPtr.ref.clearCoatRoughnessUV = key.clearCoatRoughnessUV;
    configPtr.ref.hasClearCoatNormalTexture = key.hasClearCoatNormalTexture ? 1 : 0;
    configPtr.ref.clearCoatNormalUV = key.clearCoatNormalUV;
    configPtr.ref.hasClearCoat = key.hasClearCoat ? 1 : 0;
    configPtr.ref.hasTransmission = key.hasTransmission ? 1 : 0;
    configPtr.ref.hasTextureTransforms = key.hasTextureTransforms ? 1 : 0;
    configPtr.ref.emissiveUV = key.emissiveUV;
    configPtr.ref.aoUV = key.aoUV;
    configPtr.ref.normalUV = key.normalUV;
    configPtr.ref.hasTransmissionTexture = key.hasTransmissionTexture ? 1 : 0;
    configPtr.ref.transmissionUV = key.transmissionUV;
    configPtr.ref.hasSheenColorTexture = key.hasSheenColorTexture ? 1 : 0;
    configPtr.ref.sheenColorUV = key.sheenColorUV;
    configPtr.ref.hasSheenRoughnessTexture = key.hasSheenRoughnessTexture ? 1 : 0;
    configPtr.ref.sheenRoughnessUV = key.sheenRoughnessUV;
    configPtr.ref.hasVolumeThicknessTexture = key.hasVolumeThicknessTexture ? 1 : 0;
    configPtr.ref.volumeThicknessUV = key.volumeThicknessUV;
    configPtr.ref.hasSheen = key.hasSheen ? 1 : 0;
    configPtr.ref.hasIOR = key.hasIOR ? 1 : 0;
    configPtr.ref.hasVolume = key.hasVolume ? 1 : 0;
    configPtr.ref.hasDispersion = key.hasDispersion ? 1 : 0;
    configPtr.ref.hasSpecular = key.hasSpecular ? 1 : 0;
    configPtr.ref.hasSpecularTexture = key.hasSpecularTexture ? 1 : 0;
    configPtr.ref.hasSpecularColorTexture = key.hasSpecularColorTexture ? 1 : 0;
    configPtr.ref.specularTextureUV = key.specularTextureUV;
    configPtr.ref.specularColorTextureUV = key.specularColorTextureUV;
    
    final outUvMapPtr = calloc<ffi.Uint8>(8);
    
    ffi.Pointer<Utf8> labelPtr = ffi.nullptr;
    if (label != null) labelPtr = label.toNativeUtf8();
    ffi.Pointer<Utf8> extrasPtr = ffi.nullptr;
    if (extras != null) extrasPtr = extras.toNativeUtf8();

    final instancePtr = c.filament_gltfio_material_provider_create_material_instance(
      _ptr,
      configPtr,
      outUvMapPtr,
      labelPtr != ffi.nullptr ? labelPtr.cast() : ffi.nullptr,
      extrasPtr != ffi.nullptr ? extrasPtr.cast() : ffi.nullptr,
    );
    
    if (labelPtr != ffi.nullptr) calloc.free(labelPtr);
    if (extrasPtr != ffi.nullptr) calloc.free(extrasPtr);
    
    final constrainedKey = MaterialKey(
      doubleSided: configPtr.ref.doubleSided != 0,
      unlit: configPtr.ref.unlit != 0,
      hasVertexColors: configPtr.ref.hasVertexColors != 0,
      hasBaseColorTexture: configPtr.ref.hasBaseColorTexture != 0,
      hasNormalTexture: configPtr.ref.hasNormalTexture != 0,
      hasOcclusionTexture: configPtr.ref.hasOcclusionTexture != 0,
      hasEmissiveTexture: configPtr.ref.hasEmissiveTexture != 0,
      useSpecularGlossiness: configPtr.ref.useSpecularGlossiness != 0,
      alphaMode: configPtr.ref.alphaMode,
      enableDiagnostics: configPtr.ref.enableDiagnostics != 0,
      hasMetallicRoughnessTexture: configPtr.ref.hasMetallicRoughnessTexture != 0,
      metallicRoughnessUV: configPtr.ref.metallicRoughnessUV,
      hasSpecularGlossinessTexture: configPtr.ref.hasSpecularGlossinessTexture != 0,
      specularGlossinessUV: configPtr.ref.specularGlossinessUV,
      baseColorUV: configPtr.ref.baseColorUV,
      hasClearCoatTexture: configPtr.ref.hasClearCoatTexture != 0,
      clearCoatUV: configPtr.ref.clearCoatUV,
      hasClearCoatRoughnessTexture: configPtr.ref.hasClearCoatRoughnessTexture != 0,
      clearCoatRoughnessUV: configPtr.ref.clearCoatRoughnessUV,
      hasClearCoatNormalTexture: configPtr.ref.hasClearCoatNormalTexture != 0,
      clearCoatNormalUV: configPtr.ref.clearCoatNormalUV,
      hasClearCoat: configPtr.ref.hasClearCoat != 0,
      hasTransmission: configPtr.ref.hasTransmission != 0,
      hasTextureTransforms: configPtr.ref.hasTextureTransforms != 0,
      emissiveUV: configPtr.ref.emissiveUV,
      aoUV: configPtr.ref.aoUV,
      normalUV: configPtr.ref.normalUV,
      hasTransmissionTexture: configPtr.ref.hasTransmissionTexture != 0,
      transmissionUV: configPtr.ref.transmissionUV,
      hasSheenColorTexture: configPtr.ref.hasSheenColorTexture != 0,
      sheenColorUV: configPtr.ref.sheenColorUV,
      hasSheenRoughnessTexture: configPtr.ref.hasSheenRoughnessTexture != 0,
      sheenRoughnessUV: configPtr.ref.sheenRoughnessUV,
      hasVolumeThicknessTexture: configPtr.ref.hasVolumeThicknessTexture != 0,
      volumeThicknessUV: configPtr.ref.volumeThicknessUV,
      hasSheen: configPtr.ref.hasSheen != 0,
      hasIOR: configPtr.ref.hasIOR != 0,
      hasVolume: configPtr.ref.hasVolume != 0,
      hasDispersion: configPtr.ref.hasDispersion != 0,
      hasSpecular: configPtr.ref.hasSpecular != 0,
      hasSpecularTexture: configPtr.ref.hasSpecularTexture != 0,
      hasSpecularColorTexture: configPtr.ref.hasSpecularColorTexture != 0,
      specularTextureUV: configPtr.ref.specularTextureUV,
      specularColorTextureUV: configPtr.ref.specularColorTextureUV,
    );
    
    final uvMapList = List.generate(8, (i) => outUvMapPtr[i]);
    
    calloc.free(configPtr);
    calloc.free(outUvMapPtr);

    return MaterialProviderResult(
      instance: instancePtr != ffi.nullptr ? FilamentMaterialInstance.internal(instancePtr, engine, null, false) : null,
      key: constrainedKey,
      uvMap: uvMapList,
    );
  }

  /// Destroys all cached materials held by this provider.
  void destroyMaterials() {
    _checkDisposed();
    if (_materialsDestroyed) return;
    _materialsDestroyed = true;
    c.filament_gltfio_material_provider_destroy_materials(_ptr);
  }

  /// Destroys this material provider and frees its cached materials.
  void dispose() {
    if (_disposed) return;
    if (_loaders.isNotEmpty) {
      throw StateError('Cannot dispose MaterialProvider while AssetLoaders are still active.');
    }
    _disposed = true;
    c.filament_gltfio_destroy_material_provider(_ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentMaterialProvider has been disposed');
    }
  }
}

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
    final ptr = calloc<ffi.Uint8>(bytes.length);
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
    final ptr = calloc<ffi.Uint8>(bytes.length);
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

/// Controls loading external buffer/texture resources for a [FilamentAsset].
class FilamentResourceLoader {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  FilamentResourceLoader._(this._ptr);

  /// Creates a ResourceLoader.
  static FilamentResourceLoader create({
    required FilamentEngine engine,
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
    final ptr = calloc<ffi.Uint8>(data.length);
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


/// Controls glTF animation playbacks and skeletal bone matrices.
class FilamentAnimator {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentAnimator._(this._ptr);

  /// Applies rotation, translation, and scale to entities for animation [animationIndex] at [timeSeconds].
  void applyAnimation(int animationIndex, double timeSeconds) {
    c.filament_gltfio_animator_apply_animation(
      _ptr,
      animationIndex,
      timeSeconds,
    );
  }

  /// Applies a cross-fade transition from a previous animation to the current animation.
  /// 
  /// You must call [applyAnimation] with the *next* clip first, and then call [applyCrossFade].
  /// The [alpha] controls the blend between the previous clip (0.0) and the new clip (1.0).
  void applyCrossFade(int previousAnimIndex, double previousAnimTime, double alpha) {
    if (previousAnimIndex < 0 || previousAnimIndex >= animationCount) {
      throw RangeError.range(previousAnimIndex, 0, animationCount - 1, 'previousAnimIndex');
    }
    c.filament_gltfio_animator_apply_cross_fade(
      _ptr,
      previousAnimIndex,
      previousAnimTime,
      alpha,
    );
  }

  /// Updates bone matrices for skinned models.
  void updateBoneMatrices() {
    c.filament_gltfio_animator_update_bone_matrices(_ptr);
  }

  /// Resets the bone matrices to their rest pose.
  void resetBoneMatrices() {
    c.filament_gltfio_animator_reset_bone_matrices(_ptr);
  }

  /// Returns the number of animations in the asset.
  int get animationCount =>
      c.filament_gltfio_animator_get_animation_count(_ptr);

  /// Returns the duration of animation at [animationIndex] in seconds.
  double getAnimationDuration(int animationIndex) =>
      c.filament_gltfio_animator_get_animation_duration(_ptr, animationIndex);

  /// Returns the string name of animation at [animationIndex].
  String getAnimationName(int animationIndex) {
    final ptr = c.filament_gltfio_animator_get_animation_name(
      _ptr,
      animationIndex,
    );
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }
}



/// A specific instance of a [FilamentAsset].
class FilamentAssetInstance {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentAsset _asset;

  FilamentAssetInstance._(this._ptr, this._asset);

  FilamentAsset getAsset() => _asset;

  int get root => c.filament_gltfio_instance_get_root(_ptr);

  int get entityCount => c.filament_gltfio_instance_get_entity_count(_ptr);

  List<int> get entities {
    final count = entityCount;
    if (count == 0) return [];
    final ptr = c.filament_gltfio_instance_get_entities(_ptr);
    return ptr.asTypedList(count).toList();
  }

  FilamentAnimator get animator {
    final animPtr = c.filament_gltfio_instance_get_animator(_ptr);
    return FilamentAnimator._(animPtr);
  }

  int get skinCount => c.filament_gltfio_instance_get_skin_count(_ptr);

  String? skinNameAt(int skinIndex) {
    final ptr = c.filament_gltfio_instance_get_skin_name_at(_ptr, skinIndex);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  int jointCountAt(int skinIndex) => c.filament_gltfio_instance_get_joint_count_at(_ptr, skinIndex);

  List<int> jointsAt(int skinIndex) {
    final count = jointCountAt(skinIndex);
    if (count == 0) return [];
    final ptr = c.filament_gltfio_instance_get_joints_at(_ptr, skinIndex);
    return ptr.asTypedList(count).toList();
  }

  void attachSkin(int skinIndex, int targetEntity) {
    if (skinIndex < 0 || skinIndex >= skinCount) {
      throw RangeError.index(skinIndex, this, 'skinIndex', 'Skin index out of bounds', skinCount);
    }
    c.filament_gltfio_instance_attach_skin(_ptr, skinIndex, targetEntity);
  }

  void detachSkin(int skinIndex, int targetEntity) {
    if (skinIndex < 0 || skinIndex >= skinCount) {
      throw RangeError.index(skinIndex, this, 'skinIndex', 'Skin index out of bounds', skinCount);
    }
    c.filament_gltfio_instance_detach_skin(_ptr, skinIndex, targetEntity);
  }

  Float32List inverseBindMatricesAt(int skinIndex) {
    final count = jointCountAt(skinIndex);
    if (count == 0) return Float32List(0);
    final outPtr = calloc<ffi.Float>(count * 16);
    c.filament_gltfio_instance_get_inverse_bind_matrices_at(_ptr, skinIndex, outPtr);
    final result = Float32List.fromList(outPtr.asTypedList(count * 16));
    calloc.free(outPtr);
    return result;
  }

  int get materialInstanceCount => c.filament_gltfio_instance_get_material_instance_count(_ptr);

  List<FilamentMaterialInstance> get materialInstances {
    final count = materialInstanceCount;
    if (count == 0) return [];
    final outPtr = calloc<ffi.Pointer<ffi.Void>>(count);
    c.filament_gltfio_instance_get_material_instances(_ptr, outPtr, count);
    
    final result = <FilamentMaterialInstance>[];
    for (var i = 0; i < count; i++) {
      result.add(FilamentMaterialInstance.internal(outPtr[i], _asset._loader.engine));
    }
    calloc.free(outPtr);
    return result;
  }

  void detachMaterialInstances() {
    c.filament_gltfio_instance_detach_material_instances(_ptr);
  }

  int get materialVariantCount => c.filament_gltfio_instance_get_material_variant_count(_ptr);

  String? materialVariantName(int variantIndex) {
    final ptr = c.filament_gltfio_instance_get_material_variant_name(_ptr, variantIndex);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void applyMaterialVariant(int variantIndex) {
    if (materialVariantCount == 0) return;
    c.filament_gltfio_instance_apply_material_variant(_ptr, variantIndex);
  }

  void recomputeBoundingBoxes() {
    c.filament_gltfio_instance_recompute_bounding_boxes(_ptr);
  }

  Aabb get boundingBox {
    final minPtr = calloc<ffi.Float>(3);
    final maxPtr = calloc<ffi.Float>(3);
    c.filament_gltfio_instance_get_bounding_box(_ptr, minPtr, maxPtr);
    final min = Vector3(minPtr[0], minPtr[1], minPtr[2]);
    final max = Vector3(maxPtr[0], maxPtr[1], maxPtr[2]);
    calloc.free(minPtr);
    calloc.free(maxPtr);
    return Aabb(min: min, max: max);
  }
}

class FilamentNodeManager {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentNodeManager._(this._ptr);

  bool hasComponent(int entity) {
    return c.filament_gltfio_node_manager_has_component(_ptr, entity);
  }

  String? getExtras(int entity) {
    final ptr = c.filament_gltfio_node_manager_get_extras(_ptr, entity);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void setExtras(int entity, String json) {
    final jsonPtr = json.toNativeUtf8();
    c.filament_gltfio_node_manager_set_extras(_ptr, entity, jsonPtr.cast());
    calloc.free(jsonPtr);
  }

  int getMorphTargetNameCount(int entity) {
    return c.filament_gltfio_node_manager_get_morph_target_name_count(_ptr, entity);
  }

  String? getMorphTargetNameAt(int entity, int index) {
    final ptr = c.filament_gltfio_node_manager_get_morph_target_name_at(_ptr, entity, index);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void setMorphTargetNames(int entity, List<String> names) {
    final count = names.length;
    final namesPtr = calloc<ffi.Pointer<ffi.Char>>(count);
    for (int i = 0; i < count; i++) {
      namesPtr[i] = names[i].toNativeUtf8().cast<ffi.Char>();
    }
    c.filament_gltfio_node_manager_set_morph_target_names(_ptr, entity, namesPtr.cast(), count);
    for (int i = 0; i < count; i++) {
      calloc.free(namesPtr[i]);
    }
    calloc.free(namesPtr);
  }

  int getSceneMembership(int entity) {
    return c.filament_gltfio_node_manager_get_scene_membership(_ptr, entity);
  }

  void setSceneMembership(int entity, int mask) {
    c.filament_gltfio_node_manager_set_scene_membership(_ptr, entity, mask);
  }
}

class FilamentTrsTransformManager {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentTrsTransformManager._(this._ptr);

  bool hasComponent(int entity) {
    return c.filament_gltfio_trs_transform_manager_has_component(_ptr, entity);
  }

  void setTranslation(int entity, double x, double y, double z) {
    c.filament_trs_set_translation(_ptr, entity, x, y, z);
  }

  Float32List getTranslation(int entity) {
    final out = calloc<ffi.Float>(3);
    c.filament_trs_get_translation(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(3));
    calloc.free(out);
    return result;
  }

  void setRotation(int entity, double qx, double qy, double qz, double qw) {
    c.filament_trs_set_rotation(_ptr, entity, qx, qy, qz, qw);
  }

  Float32List getRotation(int entity) {
    final out = calloc<ffi.Float>(4);
    c.filament_trs_get_rotation(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(4));
    calloc.free(out);
    return result;
  }

  void setScale(int entity, double x, double y, double z) {
    c.filament_trs_set_scale(_ptr, entity, x, y, z);
  }

  Float32List getScale(int entity) {
    final out = calloc<ffi.Float>(3);
    c.filament_trs_get_scale(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(3));
    calloc.free(out);
    return result;
  }

  void setTrs(int entity, Float32List translation, Float32List rotation, Float32List scale) {
    assert(translation.length >= 3 && rotation.length >= 4 && scale.length >= 3);
    final tPtr = calloc<ffi.Float>(3)..asTypedList(3).setAll(0, translation.take(3));
    final rPtr = calloc<ffi.Float>(4)..asTypedList(4).setAll(0, rotation.take(4));
    final sPtr = calloc<ffi.Float>(3)..asTypedList(3).setAll(0, scale.take(3));
    c.filament_trs_set_trs(_ptr, entity, tPtr, rPtr, sPtr);
    calloc.free(tPtr);
    calloc.free(rPtr);
    calloc.free(sPtr);
  }

  Float32List getTransform(int entity) {
    final out = calloc<ffi.Float>(16);
    c.filament_trs_get_transform(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(16));
    calloc.free(out);
    return result;
  }
}

/// Helper wrapper / alias for loading glTF and GLB assets.
class GltfLoader {
  final FilamentAssetLoader _loader;

  GltfLoader({
    required FilamentEngine engine,
    required FilamentMaterialProvider materialProvider,
    NameComponentManager? names,
  }) : _loader = FilamentAssetLoader.create(
          engine: engine,
          materialProvider: materialProvider,
          names: names,
        );

  FilamentAssetLoader get assetLoader => _loader;

  FilamentAsset? loadGltf(Uint8List bytes) => _loader.createAsset(bytes);

  void dispose() => _loader.dispose();
}
