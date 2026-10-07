import 'dart:typed_data';
import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/material/lumina_material.dart';
import 'package:lumina/src/material/lumina_material_instance.dart';
import 'package:lumina/src/material/material_textures.dart';

/// A dynamic material instance.
///
/// Supports per-actor parameter mutations, texture bindings with custom samplers,
/// render-state overrides, and stencil configurations without modifying other instances.
class LuminaDynamicMaterialInstance extends LuminaMaterialInstance {
  final Map<String, FilamentTexture> _boundTextures = {};
  final List<FilamentTexture> _ownedTextures = [];

  /// Textures [setTextureAsset] bound, by sampler name.
  final Map<String, LuminaMaterialTextures> _assetTextures = {};

  /// The latest [setTextureAsset] call per sampler: an older load that
  /// finishes later is dropped.
  final Map<String, int> _textureRequests = {};

  /// The last value set per parameter name (a `double`, an `int`, a `bool`,
  /// a `[r, g, b, a]` list, a texture path), for tools and Blueprints to
  /// read back.
  final Map<String, Object?> parameterValues = {};

  LuminaDynamicMaterialInstance._(
    FilamentMaterialInstance nativeInstance,
    LuminaMaterial material,
    String name,
  ) : super.internal(
          nativeInstance,
          material,
          isDefaultInstance: false,
        ) {
    material.addRef();
  }

  /// Creates a dynamic duplicate of [source], inheriting its current parameters.
  factory LuminaDynamicMaterialInstance.from(
    LuminaMaterialInstance source, {
    String? name,
  }) {
    final nativeDuplicate = source.nativeInstance.duplicate(name: name);
    final instName = name ?? '${source.name}#dyn_${nativeDuplicate.hashCode}';
    return LuminaDynamicMaterialInstance._(
      nativeDuplicate,
      source.material,
      instName,
    );
  }

  void _validateParam(String name, UniformType expectedType) {
    if (!material.hasParameter(name)) {
      throw ArgumentError('Material "${material.name}" does not declare parameter "$name"');
    }
    final p = material.parameters.firstWhere((e) => e.name == name);
    if (p.isSampler || p.uniformType != expectedType) {
      throw ArgumentError(
        'Parameter "$name" has type ${p.uniformType}, cannot set with $expectedType',
      );
    }
  }

  void _validateArray(String name, UniformType expectedType, int totalLength, int stride) {
    _validateParam(name, expectedType);
    final p = material.parameters.firstWhere((e) => e.name == name);
    final elementCount = totalLength ~/ stride;
    if (elementCount != p.count) {
      throw ArgumentError(
        'Parameter array "$name" expects ${p.count} elements, but got $elementCount elements',
      );
    }
  }

  void _validateSampler(String name) {
    if (!material.hasParameter(name)) {
      throw ArgumentError('Material "${material.name}" does not declare sampler "$name"');
    }
    if (!material.isSampler(name)) {
      throw ArgumentError('Parameter "$name" is a uniform parameter, not a sampler');
    }
  }

  /// Sets a scalar float parameter value.
  void setScalar(String name, double value) {
    parameterValues[name] = value;
    _validateParam(name, UniformType.float_);
    nativeInstance.setFloat(name, value);
  }

  /// Sets an integer parameter value.
  @override
  void setInt(String name, int value) {
    _validateParam(name, UniformType.int_);
    nativeInstance.setInt(name, value);
  }

  /// Sets a boolean parameter value.
  @override
  void setBool(String name, bool value) {
    _validateParam(name, UniformType.bool_);
    nativeInstance.setBool(name, value);
  }

  /// Sets a 4-component vector parameter value.
  void setVector(String name, Vector4 value) {
    parameterValues[name] = <double>[value.x, value.y, value.z, value.w];
    _validateParam(name, UniformType.float4);
    nativeInstance.setFloat4(name, value.x, value.y, value.z, value.w);
  }

  /// Sets a 3-component vector parameter value.
  void setVector3(String name, Vector3 value) {
    _validateParam(name, UniformType.float3);
    nativeInstance.setFloat3(name, value.x, value.y, value.z);
  }

  /// Sets a color parameter value with color-space conversion.
  void setColor(String name, RgbType type, (double, double, double) rgb) {
    _validateParam(name, UniformType.float3);
    nativeInstance.setColor(name, type, rgb.$1, rgb.$2, rgb.$3);
  }

  /// Sets a 4-component color parameter value with color-space conversion.
  void setColorRgba(String name, RgbaType type, (double, double, double, double) rgba) {
    _validateParam(name, UniformType.float4);
    nativeInstance.setColorRgba(name, type, rgba.$1, rgba.$2, rgba.$3, rgba.$4);
  }

  /// Sets an array of float scalar values.
  void setScalarArray(String name, Float32List values) {
    _validateArray(name, UniformType.float_, values.length, 1);
    nativeInstance.setFloatArray(name, values);
  }

  /// Sets an array of float4 vector values (packed 4 floats per element).
  void setVectorArray(String name, Float32List packed16) {
    _validateArray(name, UniformType.float4, packed16.length, 4);
    nativeInstance.setFloat4Array(name, packed16);
  }

  /// Sets an array of 4x4 matrices (packed 16 floats per element).
  void setMatrixArray(String name, Float32List packed64) {
    _validateArray(name, UniformType.mat4, packed64.length, 16);
    nativeInstance.setMat4Array(name, packed64);
  }

  /// Binds a texture to [name] with an optional [sampler].
  void setTexture(
    String name,
    FilamentTexture texture, {
    TextureSampler sampler = const TextureSampler(),
  }) {
    _validateSampler(name);
    final old = _boundTextures[name];
    if (old != null && old != texture && _ownedTextures.contains(old)) {
      _ownedTextures.remove(old);
      old.dispose();
    }
    _boundTextures[name] = texture;
    nativeInstance.setTexture(name, texture, sampler: sampler);
    final loaded = _assetTextures[name];
    if (loaded != null && !identical(loaded.bound[name]?.texture, texture)) {
      _assetTextures.remove(name);
      loaded.release();
    }
  }

  /// Binds the texture at [path] to sampler [name]: a texture asset
  /// (`contents/…/T_x.lmas`, its payload the image) or an image file, read
  /// through [LuminaAssets] (the open project in the editor and Play, the
  /// asset bundle in a built game) and uploaded with the texture's settings
  /// (sRGB, mipmaps, filtering, wrap) as a material's own textures are
  /// ([LuminaMaterialTextures]); the upload is shared with every material
  /// that binds the same texture. Completes with false, the sampler left as
  /// it was, when the texture cannot be loaded (logged once) or a later call
  /// for [name] replaced this one.
  Future<bool> setTextureAsset(String name, String path, {LuminaAssetProvider? assetProvider}) async {
    _validateSampler(name);
    final request = _textureRequests[name] = (_textureRequests[name] ?? 0) + 1;
    final load = LuminaMaterialTextures.load(
      material.world.filamentEngine,
      material.nativeMaterial,
      [AssetReference(slotName: name, assetId: '', assetPath: path)],
      materialPath: material.assetPath,
      assetProvider: assetProvider,
    );
    _pendingTextures.add(load);
    final LuminaMaterialTextures textures;
    try {
      textures = await load;
    } finally {
      _pendingTextures.remove(load);
    }
    final bound = textures.bound[name];
    if (isDisposed || _textureRequests[name] != request || bound == null) {
      textures.release();
      return false;
    }
    final previous = _assetTextures.remove(name);
    setTexture(name, bound.texture, sampler: bound.sampler);
    _assetTextures[name] = textures;
    // After the rebind: the sampler no longer draws what it releases.
    previous?.release();
    return true;
  }

  final List<Future<LuminaMaterialTextures>> _pendingTextures = [];

  /// Completes once every [setTextureAsset] load started so far has settled.
  Future<void> get texturesLoaded => Future.wait(List.of(_pendingTextures)).then((_) {}, onError: (Object _) {});

  /// The texture [setTextureAsset] bound to sampler [name], or null.
  LuminaBoundTexture? textureParameter(String name) => _assetTextures[name]?.bound[name];

  /// Builds a 2D texture from raw RGBA8 pixels and binds it to [name].
  void setTextureFromPixels(
    String name, {
    required int width,
    required int height,
    required Uint8List rgbaBytes,
    TextureSampler sampler = const TextureSampler(),
  }) {
    _validateSampler(name);
    final engine = material.world.filamentEngine;
    final texture = FilamentTexture.create2D(
      engine: engine,
      width: width,
      height: height,
    );
    texture.setImage(
      pixelData: rgbaBytes,
      width: width,
      height: height,
    );
    _ownedTextures.add(texture);
    setTexture(name, texture, sampler: sampler);
  }

  // --- Render State Overrides ---

  /// Face culling mode override.
  CullingMode get cullingMode => nativeInstance.cullingMode;
  set cullingMode(CullingMode mode) => nativeInstance.setCullingMode(mode);

  /// Double-sided rendering override.
  bool get isDoubleSided => nativeInstance.isDoubleSided;
  set isDoubleSided(bool doubleSided) => nativeInstance.setDoubleSided(doubleSided);

  /// Color buffer write override.
  bool get isColorWriteEnabled => nativeInstance.isColorWriteEnabled;
  set isColorWriteEnabled(bool enable) => nativeInstance.setColorWrite(enable);

  /// Depth buffer write override.
  bool get isDepthWriteEnabled => nativeInstance.isDepthWriteEnabled;
  set isDepthWriteEnabled(bool enable) => nativeInstance.setDepthWrite(enable);

  /// Depth test (culling) override.
  bool get isDepthCullingEnabled => nativeInstance.isDepthCullingEnabled;
  set isDepthCullingEnabled(bool enable) => nativeInstance.setDepthCulling(enable);

  /// Depth comparison function override.
  DepthFunc get depthFunc => nativeInstance.depthFunc;
  set depthFunc(DepthFunc func) => nativeInstance.setDepthFunc(func);

  /// Transparency mode override.
  TransparencyMode get transparencyMode => nativeInstance.transparencyMode;
  set transparencyMode(TransparencyMode mode) => nativeInstance.setTransparencyMode(mode);

  /// Mask alpha cutoff threshold override.
  double get maskThreshold => nativeInstance.maskThreshold;
  set maskThreshold(double threshold) => nativeInstance.setMaskThreshold(threshold);

  /// Sets the polygon offset for this instance (e.g. for decals).
  void setPolygonOffset(double scale, double constant) {
    nativeInstance.setPolygonOffset(scale, constant);
  }

  /// Sets a custom viewport scissor rectangle (bottom-left origin).
  void setScissor({required int left, required int bottom, required int width, required int height}) {
    nativeInstance.setScissor(left: left, bottom: bottom, width: width, height: height);
  }

  /// Unsets custom scissor rectangle.
  void unsetScissor() {
    nativeInstance.unsetScissor();
  }

  // --- Stencil Overrides ---

  /// Enables or disables writing to the stencil buffer.
  void setStencilWrite(bool enabled) => nativeInstance.setStencilWrite(enabled);

  /// Checks if stencil buffer writing is enabled.
  bool get isStencilWriteEnabled => nativeInstance.isStencilWriteEnabled;

  /// Sets the stencil comparison function.
  void setStencilCompareFunction(DepthFunc func, {StencilFace face = StencilFace.frontAndBack}) {
    nativeInstance.setStencilCompareFunction(func, face: face);
  }

  /// Sets the stencil operation on pass.
  void setStencilOpDepthStencilPass(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    nativeInstance.setStencilOpDepthStencilPass(op, face: face);
  }

  /// Sets the stencil reference value.
  void setStencilReferenceValue(int value, {StencilFace face = StencilFace.frontAndBack}) {
    nativeInstance.setStencilReferenceValue(value, face: face);
  }

  /// Sets the stencil read mask.
  void setStencilReadMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    nativeInstance.setStencilReadMask(mask, face: face);
  }

  /// Sets the stencil write mask.
  void setStencilWriteMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    nativeInstance.setStencilWriteMask(mask, face: face);
  }

  @override
  void dispose() {
    if (isDisposed) {
      // Destroyed with its material: what it bound is still let go of.
      _releaseAssetTextures();
      return;
    }
    for (final tex in _ownedTextures) {
      tex.dispose();
    }
    _ownedTextures.clear();
    _boundTextures.clear();
    super.dispose();
    _releaseAssetTextures();
    material.release();
  }

  void _releaseAssetTextures() {
    for (final textures in _assetTextures.values) {
      textures.release();
    }
    _assetTextures.clear();
  }
}

/// A section's dynamic material instance that exists once the section's
/// material asset has loaded: what Create Dynamic Material Instance hands
/// out while a component's Material Override (or slot material) is still
/// loading, as it is at BeginPlay. Parameters set on it meanwhile
/// ([whenReady]) are applied to the instance, in order, when it is made.
class LuminaPendingDynamicMaterialInstance {
  LuminaPendingDynamicMaterialInstance(Future<LuminaDynamicMaterialInstance?> instance) {
    ready = instance.then((made) {
      _instance = made;
      _resolved = true;
      final queued = List.of(_queued);
      _queued.clear();
      if (made != null && !made.isDisposed) {
        for (final apply in queued) {
          apply(made);
        }
      }
      return made;
    }, onError: (Object _) {
      _resolved = true;
      _queued.clear();
      return null;
    });
  }

  /// The instance, or null when the section got no material to make one of.
  late final Future<LuminaDynamicMaterialInstance?> ready;

  LuminaDynamicMaterialInstance? _instance;
  bool _resolved = false;
  final List<void Function(LuminaDynamicMaterialInstance)> _queued = [];

  /// The instance once [ready] completed, else null.
  LuminaDynamicMaterialInstance? get instance => _instance;

  /// The values set so far per parameter name, for Blueprints to read back
  /// before the instance exists.
  final Map<String, Object?> parameterValues = {};

  /// Runs [apply] on the instance: now when it exists, else once it is made
  /// (dropped when none is).
  void whenReady(void Function(LuminaDynamicMaterialInstance instance) apply) {
    final made = _instance;
    if (made != null) {
      if (!made.isDisposed) apply(made);
      return;
    }
    if (!_resolved) _queued.add(apply);
  }
}
