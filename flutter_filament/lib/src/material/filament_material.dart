part of '../material.dart';

class FilamentMaterial {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final Set<FilamentMaterialInstance> _instances = {};
  FilamentMaterialInstance? _defaultInstance;
  bool _disposed = false;

  /// Internal constructor.
  FilamentMaterial.internal(this._ptr, this._engine);

  /// Creates a Material from a compiled `.filamat` binary buffer.
  static FilamentMaterial fromBuffer({
    required FilamentEngine engine,
    required Uint8List filamatBuffer,
    List<MaterialConstant> constants = const [],
    int? sphericalHarmonicsBandCount,
    ShadowSamplingQuality? shadowSamplingQuality,
  }) {
    final ptr = calloc<ffi.Uint8>(filamatBuffer.length);
    final byteList = ptr.asTypedList(filamatBuffer.length);
    byteList.setAll(0, filamatBuffer);

    ffi.Pointer<ffi.Void> matPtr;
    if (constants.isNotEmpty || sphericalHarmonicsBandCount != null || shadowSamplingQuality != null) {
      final constantsPtr = calloc<c.FilamentMaterialConstant>(constants.length);
      final allocatedStrings = <ffi.Pointer<Utf8>>[];
      try {
        for (int i = 0; i < constants.length; i++) {
          final cConst = constants[i];
          final strPtr = cConst.name.toNativeUtf8();
          allocatedStrings.add(strPtr);
          constantsPtr[i].name = strPtr.cast();
          switch (cConst) {
            case _Int32MaterialConstant(:final value):
              constantsPtr[i].type = 0;
              constantsPtr[i].value.i = value;
            case _FloatMaterialConstant(:final value):
              constantsPtr[i].type = 1;
              constantsPtr[i].value.f = value;
            case _BoolMaterialConstant(:final value):
              constantsPtr[i].type = 2;
              constantsPtr[i].value.b = value;
          }
        }
        matPtr = c.filament_material_create_ex(
          engine.nativePointer,
          ptr.cast(),
          filamatBuffer.length,
          constantsPtr,
          constants.length,
          sphericalHarmonicsBandCount ?? 0,
          shadowSamplingQuality?.value ?? -1,
        );
      } finally {
        for (final s in allocatedStrings) {
          calloc.free(s);
        }
        calloc.free(constantsPtr);
      }
    } else {
      matPtr = c.filament_material_create(
        engine.nativePointer,
        ptr.cast(),
        filamatBuffer.length,
      );
    }
    calloc.free(ptr);

    if (matPtr == ffi.nullptr) {
      throw StateError('Failed to create FilamentMaterial from buffer');
    }

    return FilamentMaterial.internal(matPtr, engine);
  }

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Number of parameters declared on this material.
  int get parameterCount {
    _checkDisposed();
    return c.filament_material_get_parameter_count(_ptr);
  }

  /// Reflected parameters of this material.
  List<MaterialParameter> get parameters {
    _checkDisposed();
    final count = parameterCount;
    if (count == 0) return const [];

    final outArray = calloc<c.FilamentParameterInfo>(count);
    try {
      final retrieved = c.filament_material_get_parameters(_ptr, outArray, count);
      final result = <MaterialParameter>[];
      for (int i = 0; i < retrieved; i++) {
        final info = outArray[i];
        final nameStr = info.name.cast<Utf8>().toDartString();
        final isSampler = info.is_sampler;
        final isSubpass = info.is_subpass;
        final uniformType = (!isSampler &&
                !isSubpass &&
                info.uniform_type >= 0 &&
                info.uniform_type < UniformType.values.length)
            ? UniformType.values[info.uniform_type]
            : null;
        final samplerType = (isSampler &&
                info.sampler_type >= 0 &&
                info.sampler_type < TextureSamplerType.values.length)
            ? TextureSamplerType.values[info.sampler_type]
            : null;
        final precision = (info.precision >= 0 &&
                info.precision < ParameterPrecision.values.length)
            ? ParameterPrecision.values[info.precision]
            : ParameterPrecision.defaultPrecision;

        result.add(MaterialParameter(
          name: nameStr,
          isSampler: isSampler,
          isSubpass: isSubpass,
          uniformType: uniformType,
          samplerType: samplerType,
          count: info.count,
          precision: precision,
        ));
      }
      return result;
    } finally {
      calloc.free(outArray);
    }
  }

  /// Checks whether this material declares a parameter with [name].
  bool hasParameter(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_has_parameter(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Checks whether parameter [name] is a sampler texture parameter.
  bool isSampler(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_is_sampler(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Gets the transform parameter name associated with sampler [name], or `null` if none.
  String? parameterTransformName(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      final ptr = c.filament_material_get_parameter_transform_name(_ptr, nativeName.cast());
      if (ptr == ffi.nullptr) return null;
      return ptr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(nativeName);
    }
  }

  void _validateParameter(String name) {
    if (!hasParameter(name)) {
      throw ArgumentError('Material does not declare parameter "$name"');
    }
  }

  /// Sets default boolean parameter value.
  void setDefaultParameterBool(String name, bool value) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_bool(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default integer parameter value.
  void setDefaultParameterInt(String name, int value) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_int(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default float parameter value.
  void setDefaultParameterFloat(String name, double value) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_float(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default 2-component float parameter value.
  void setDefaultParameterFloat2(String name, double x, double y) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_float2(_ptr, nativeName.cast(), x, y);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default 3-component float parameter value.
  void setDefaultParameterFloat3(String name, double x, double y, double z) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_float3(_ptr, nativeName.cast(), x, y, z);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default 4-component float parameter value.
  void setDefaultParameterFloat4(String name, double x, double y, double z, double w) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_float4(_ptr, nativeName.cast(), x, y, z, w);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default 3x3 matrix parameter value.
  void setDefaultParameterMat3(String name, List<double> matrix) {
    _checkDisposed();
    _validateParameter(name);
    if (matrix.length != 9) {
      throw ArgumentError('Mat3 requires 9 elements, got ${matrix.length}');
    }
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(9);
    for (int i = 0; i < 9; i++) {
      ptr[i] = matrix[i];
    }
    try {
      c.filament_material_set_default_parameter_mat3(_ptr, nativeName.cast(), ptr);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Sets default 4x4 matrix parameter value.
  void setDefaultParameterMat4(String name, List<double> matrix) {
    _checkDisposed();
    _validateParameter(name);
    if (matrix.length != 16) {
      throw ArgumentError('Mat4 requires 16 elements, got ${matrix.length}');
    }
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr[i] = matrix[i];
    }
    try {
      c.filament_material_set_default_parameter_mat4(_ptr, nativeName.cast(), ptr);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Sets default texture and optional sampler parameter value.
  void setDefaultTexture(String name, FilamentTexture texture, {TextureSampler? sampler}) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    final packed = sampler?.packed ?? const TextureSampler().packed;
    try {
      c.filament_material_set_default_parameter_texture(
        _ptr,
        nativeName.cast(),
        texture.nativePointer,
        packed,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default RGB color parameter value.
  void setDefaultColor(String name, RgbType type, (double, double, double) color) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_rgb(
        _ptr,
        nativeName.cast(),
        type.value,
        color.$1,
        color.$2,
        color.$3,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets default RGBA color parameter value.
  void setDefaultColorRgba(String name, RgbaType type, (double, double, double, double) color) {
    _checkDisposed();
    _validateParameter(name);
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_set_default_parameter_rgba(
        _ptr,
        nativeName.cast(),
        type.value,
        color.$1,
        color.$2,
        color.$3,
        color.$4,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Asynchronously compiles the material variants.
  Future<void> compile({
    CompilerPriorityQueue priority = CompilerPriorityQueue.high,
    int variantFilter = UserVariantFilterBit.all,
  }) async {
    _checkDisposed();
    final (reqId, future) = CallbackBridge.instance.register(kind: 1);
    c.filament_material_compile(
      _ptr,
      priority.value,
      variantFilter,
      reqId,
    );
    await future;
  }

  /// Creates a new instance of this material with an optional [name].
  FilamentMaterialInstance createInstance([String? name]) {
    _checkDisposed();
    final ffi.Pointer<ffi.Void> miPtr;
    if (name != null) {
      final nativeName = name.toNativeUtf8();
      try {
        miPtr = c.filament_material_create_instance_with_name(_ptr, nativeName.cast());
      } finally {
        calloc.free(nativeName);
      }
    } else {
      miPtr = c.filament_material_create_instance(_ptr);
    }
    final instance = FilamentMaterialInstance.internal(miPtr, _engine, this);
    _instances.add(instance);
    return instance;
  }

  /// Returns the default instance of this material.
  FilamentMaterialInstance get defaultInstance {
    _checkDisposed();
    return _defaultInstance ??= () {
      final miPtr = c.filament_material_get_default_instance(_ptr);
      return FilamentMaterialInstance.internal(miPtr, _engine, this, true);
    }();
  }

  /// Returns the default instance of this material (alias for [defaultInstance]).
  FilamentMaterialInstance getDefaultInstance() => defaultInstance;

  /// Shading model of this material.
  FilamatShading get shading {
    _checkDisposed();
    final val = c.filament_material_get_shading(_ptr);
    return FilamatShading.values.firstWhere((e) => e.value == val, orElse: () => FilamatShading.lit);
  }

  /// Interpolation mode of this material.
  Interpolation get interpolation {
    _checkDisposed();
    final val = c.filament_material_get_interpolation(_ptr);
    return Interpolation.values.firstWhere((e) => e.value == val, orElse: () => Interpolation.smooth);
  }

  /// Blending mode of this material.
  BlendingMode get blendingMode {
    _checkDisposed();
    final val = c.filament_material_get_blending_mode(_ptr);
    return BlendingMode.values.firstWhere((e) => e.value == val, orElse: () => BlendingMode.opaque);
  }

  /// Vertex domain of this material.
  VertexDomain get vertexDomain {
    _checkDisposed();
    final val = c.filament_material_get_vertex_domain(_ptr);
    return VertexDomain.values.firstWhere((e) => e.value == val, orElse: () => VertexDomain.object);
  }

  /// Material domain of this material.
  MaterialDomain get materialDomain {
    _checkDisposed();
    final val = c.filament_material_get_material_domain(_ptr);
    return MaterialDomain.values.firstWhere((e) => e.value == val, orElse: () => MaterialDomain.surface);
  }

  /// Default culling mode of this material.
  CullingMode get cullingMode {
    _checkDisposed();
    final val = c.filament_material_get_culling_mode(_ptr);
    return CullingMode.values.firstWhere((e) => e.value == val, orElse: () => CullingMode.none);
  }

  /// Transparency mode of this material.
  TransparencyMode get transparencyMode {
    _checkDisposed();
    final val = c.filament_material_get_transparency_mode(_ptr);
    return TransparencyMode.values.firstWhere((e) => e.value == val, orElse: () => TransparencyMode.defaultMode);
  }

  /// Indicates whether instances of this material write into the color buffer.
  bool get isColorWriteEnabled {
    _checkDisposed();
    return c.filament_material_is_color_write_enabled(_ptr);
  }

  /// Indicates whether instances of this material write into the depth buffer.
  bool get isDepthWriteEnabled {
    _checkDisposed();
    return c.filament_material_is_depth_write_enabled(_ptr);
  }

  /// Indicates whether depth testing is enabled.
  bool get isDepthCullingEnabled {
    _checkDisposed();
    return c.filament_material_is_depth_culling_enabled(_ptr);
  }

  /// Indicates whether this material is double-sided.
  bool get isDoubleSided {
    _checkDisposed();
    return c.filament_material_is_double_sided(_ptr);
  }

  /// Indicates whether this material uses alpha-to-coverage.
  bool get isAlphaToCoverageEnabled {
    _checkDisposed();
    return c.filament_material_is_alpha_to_coverage_enabled(_ptr);
  }

  /// Mask threshold alpha cutoff value.
  double get maskThreshold {
    _checkDisposed();
    return c.filament_material_get_mask_threshold(_ptr);
  }

  /// Indicates whether this material has a shadow multiplier.
  bool get hasShadowMultiplier {
    _checkDisposed();
    return c.filament_material_has_shadow_multiplier(_ptr);
  }

  /// Indicates whether specular anti-aliasing is enabled.
  bool get hasSpecularAntiAliasing {
    _checkDisposed();
    return c.filament_material_has_specular_anti_aliasing(_ptr);
  }

  /// Specular anti-aliasing screen-space variance.
  double get specularAntiAliasingVariance {
    _checkDisposed();
    return c.filament_material_get_specular_anti_aliasing_variance(_ptr);
  }

  /// Specular anti-aliasing clamping threshold.
  double get specularAntiAliasingThreshold {
    _checkDisposed();
    return c.filament_material_get_specular_anti_aliasing_threshold(_ptr);
  }

  /// Set of vertex attributes required by this material.
  Set<VertexAttribute> get requiredAttributes {
    _checkDisposed();
    final mask = c.filament_material_get_required_attributes(_ptr);
    final result = <VertexAttribute>{};
    for (final attr in VertexAttribute.values) {
      if ((mask & (1 << attr.value)) != 0) {
        result.add(attr);
      }
    }
    return result;
  }

  /// Refraction mode used by this material.
  RefractionMode get refractionMode {
    _checkDisposed();
    final val = c.filament_material_get_refraction_mode(_ptr);
    return RefractionMode.values.firstWhere((e) => e.value == val, orElse: () => RefractionMode.none);
  }

  /// Refraction type used by this material.
  RefractionType get refractionType {
    _checkDisposed();
    final val = c.filament_material_get_refraction_type(_ptr);
    return RefractionType.values.firstWhere((e) => e.value == val, orElse: () => RefractionType.solid);
  }

  /// Reflection mode used by this material.
  ReflectionMode get reflectionMode {
    _checkDisposed();
    final val = c.filament_material_get_reflection_mode(_ptr);
    return ReflectionMode.values.firstWhere((e) => e.value == val, orElse: () => ReflectionMode.default_);
  }

  /// Minimum required feature level.
  int get featureLevel {
    _checkDisposed();
    return c.filament_material_get_feature_level(_ptr);
  }

  /// Material name.
  String get name {
    _checkDisposed();
    final ptr = c.filament_material_get_name(_ptr);
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  /// Destroys this Material.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final activeInstances = List<FilamentMaterialInstance>.from(_instances);
    for (final instance in activeInstances) {
      instance.dispose();
    }
    _instances.clear();
    c.filament_engine_destroy_material(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentMaterial has been disposed');
    }
  }
}
