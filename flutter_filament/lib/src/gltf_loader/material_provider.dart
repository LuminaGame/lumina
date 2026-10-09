part of '../gltf_loader.dart';

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
    final ptr = malloc<ffi.Uint8>(archiveData.length);
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
