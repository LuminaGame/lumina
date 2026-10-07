import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/texture_sampler.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

import 'package:flutter_filament/src/enums.dart';

import 'package:flutter_filament/src/callback_bridge.dart';
import 'package:flutter_filament/src/filamat_builder.dart';

/// Specialization constant for material compilation.
sealed class MaterialConstant {
  final String name;
  const MaterialConstant._(this.name);

  const factory MaterialConstant.int32(String name, int value) = _Int32MaterialConstant;
  const factory MaterialConstant.float(String name, double value) = _FloatMaterialConstant;
  const factory MaterialConstant.bool_(String name, bool value) = _BoolMaterialConstant;
}

class _Int32MaterialConstant extends MaterialConstant {
  final int value;
  const _Int32MaterialConstant(super.name, this.value) : super._();
}

class _FloatMaterialConstant extends MaterialConstant {
  final double value;
  const _FloatMaterialConstant(super.name, this.value) : super._();
}

class _BoolMaterialConstant extends MaterialConstant {
  final bool value;
  const _BoolMaterialConstant(super.name, this.value) : super._();
}

/// Quality of shadow sampling for material builders.
enum ShadowSamplingQuality {
  low(0),
  medium(1),
  high(2),
  ultra(3);

  final int value;
  const ShadowSamplingQuality(this.value);
}

/// Holds reflected information about a [FilamentMaterial] parameter.
class MaterialParameter {
  final String name;
  final bool isSampler;
  final bool isSubpass;
  final UniformType? uniformType;
  final TextureSamplerType? samplerType;
  final int count;
  final ParameterPrecision precision;

  const MaterialParameter({
    required this.name,
    required this.isSampler,
    required this.isSubpass,
    this.uniformType,
    this.samplerType,
    required this.count,
    required this.precision,
  });

  @override
  String toString() {
    return 'MaterialParameter(name: $name, isSampler: $isSampler, isSubpass: $isSubpass, '
        'uniformType: $uniformType, samplerType: $samplerType, count: $count, precision: $precision)';
  }
}

/// Represents a compiled Filament material.
/// The material package version this engine build accepts.
///
/// A compiled `.filamat` carries its version in its header; if the two differ
/// the engine refuses the material at load time. It logs and carries on, so
/// the only visible symptom is that whatever used the material renders
/// nothing — check this instead of trusting a successful load.
int get filamentExpectedMaterialVersion => c.filament_expected_material_version();

/// The version recorded in a compiled `.filamat` package's header.
int filamentMaterialPackageVersion(Uint8List package) {
  if (package.length < 13) {
    throw ArgumentError('not a .filamat package: ${package.length} bytes');
  }
  return package[12];
}

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

/// An instance of a [FilamentMaterial] with its own parameter values.
class FilamentMaterialInstance {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final FilamentMaterial? _parentMaterial;
  final bool _borrowed;
  bool _disposed = false;

  /// Internal constructor.
  FilamentMaterialInstance.internal(this._ptr, this._engine, [this._parentMaterial, this._borrowed = false]);

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Duplicates this instance, creating an independent instance sharing the same parent Material.
  FilamentMaterialInstance duplicate({String? name}) {
    _checkDisposed();
    final ffi.Pointer<ffi.Void> newPtr;
    if (name != null) {
      final nativeName = name.toNativeUtf8();
      newPtr = c.filament_material_instance_duplicate(_ptr, nativeName.cast());
      calloc.free(nativeName);
    } else {
      newPtr = c.filament_material_instance_duplicate(_ptr, ffi.nullptr);
    }
    if (newPtr == ffi.nullptr) {
      throw StateError('Failed to duplicate MaterialInstance');
    }
    final instance = FilamentMaterialInstance.internal(newPtr, _engine, _parentMaterial);
    _parentMaterial?._instances.add(instance);
    return instance;
  }


  /// Sets a boolean parameter value.
  void setBool(String name, bool value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_bool(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component boolean vector parameter value.
  void setBool2(String name, bool x, bool y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(2);
    ptr[0] = x; ptr[1] = y;
    c.filament_material_instance_set_bool2(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3-component boolean vector parameter value.
  void setBool3(String name, bool x, bool y, bool z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(3);
    ptr[0] = x; ptr[1] = y; ptr[2] = z;
    c.filament_material_instance_set_bool3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4-component boolean vector parameter value.
  void setBool4(String name, bool x, bool y, bool z, bool w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(4);
    ptr[0] = x; ptr[1] = y; ptr[2] = z; ptr[3] = w;
    c.filament_material_instance_set_bool4(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an integer parameter value.
  void setInt(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component integer vector parameter value.
  void setInt2(String name, int x, int y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int2(_ptr, nativeName.cast(), x, y);
    calloc.free(nativeName);
  }

  /// Sets a 3-component integer vector parameter value.
  void setInt3(String name, int x, int y, int z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int3(_ptr, nativeName.cast(), x, y, z);
    calloc.free(nativeName);
  }

  /// Sets a 4-component integer vector parameter value.
  void setInt4(String name, int x, int y, int z, int w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int4(_ptr, nativeName.cast(), x, y, z, w);
    calloc.free(nativeName);
  }

  /// Sets a unsigned integer parameter value.
  void setUint(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_uint(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component unsigned integer vector parameter value.
  void setUint2(String name, int x, int y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(2);
    ptr[0] = x; ptr[1] = y;
    c.filament_material_instance_set_uint2(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3-component unsigned integer vector parameter value.
  void setUint3(String name, int x, int y, int z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(3);
    ptr[0] = x; ptr[1] = y; ptr[2] = z;
    c.filament_material_instance_set_uint3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4-component unsigned integer vector parameter value.
  void setUint4(String name, int x, int y, int z, int w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(4);
    ptr[0] = x; ptr[1] = y; ptr[2] = z; ptr[3] = w;
    c.filament_material_instance_set_uint4(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a scalar float parameter value.
  void setFloat(String name, double value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component vector parameter value.
  void setFloat2(String name, double x, double y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float2(_ptr, nativeName.cast(), x, y);
    calloc.free(nativeName);
  }

  /// Sets a 3-component vector parameter value.
  void setFloat3(String name, double x, double y, double z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float3(_ptr, nativeName.cast(), x, y, z);
    calloc.free(nativeName);
  }

  /// Sets a 4-component vector / color parameter value.
  void setFloat4(String name, double x, double y, double z, double w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float4(
      _ptr,
      nativeName.cast(),
      x,
      y,
      z,
      w,
    );
    calloc.free(nativeName);
  }

  /// Sets an array of float parameters.
  void setFloatArray(String name, Float32List values) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float_array(_ptr, nativeName.cast(), ptr, values.length);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float2 parameters.
  void setFloat2Array(String name, Float32List values) {
    if (values.length % 2 != 0) throw ArgumentError('values length must be a multiple of 2');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float2_array(_ptr, nativeName.cast(), ptr, values.length ~/ 2);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float3 parameters. Note: expected 3 floats (12 bytes) per element.
  void setFloat3Array(String name, Float32List values) {
    if (values.length % 3 != 0) throw ArgumentError('values length must be a multiple of 3');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float3_array(_ptr, nativeName.cast(), ptr, values.length ~/ 3);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float4 parameters.
  void setFloat4Array(String name, Float32List values) {
    if (values.length % 4 != 0) throw ArgumentError('values length must be a multiple of 4');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float4_array(_ptr, nativeName.cast(), ptr, values.length ~/ 4);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of int parameters.
  void setIntArray(String name, Int32List values) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_int_array(_ptr, nativeName.cast(), ptr, values.length);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3x3 matrix parameter value (9 floats column-major).
  void setMat3(String name, List<double> matrix9) {
    if (matrix9.length != 9) {
      throw ArgumentError('matrix9 must contain exactly 9 elements');
    }
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(9);
    for (var i = 0; i < 9; i++) {
      ptr[i] = matrix9[i];
    }
    c.filament_material_instance_set_mat3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4x4 matrix parameter value (16 floats column-major).
  void setMat4(String name, List<double> matrix16) {
    if (matrix16.length != 16) {
      throw ArgumentError('Matrix must contain 16 elements');
    }
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(16);
    for (var i = 0; i < 16; i++) {
      ptr[i] = matrix16[i];
    }
    c.filament_material_instance_set_mat4(
      _ptr,
      nativeName.cast(),
      ptr,
    );
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of mat3 parameters (9 floats per matrix).
  void setMat3Array(String name, Float32List values) {
    if (values.length % 9 != 0) throw ArgumentError('values length must be a multiple of 9');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_mat3_array(_ptr, nativeName.cast(), ptr, values.length ~/ 9);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of mat4 parameters (16 floats per matrix, e.g. for bone palettes).
  void setMat4Array(String name, Float32List values) {
    if (values.length % 16 != 0) throw ArgumentError('values length must be a multiple of 16');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_mat4_array(_ptr, nativeName.cast(), ptr, values.length ~/ 16);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a color parameter using a specific RGB color space.
  void setColor(String name, RgbType type, double r, double g, double b) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_rgb(_ptr, nativeName.cast(), type.index, r, g, b);
    calloc.free(nativeName);
  }

  /// Sets a color parameter using a specific RGBA color space.
  void setColorRgba(String name, RgbaType type, double r, double g, double b, double a) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_rgba(_ptr, nativeName.cast(), type.index, r, g, b, a);
    calloc.free(nativeName);
  }

  /// Sets a Texture sampler parameter with optional [sampler] filter and wrap settings.
  void setTexture(
    String name,
    dynamic texture, {
    TextureSampler sampler = const TextureSampler(),
  }) {
    _checkDisposed();
    final ffi.Pointer<ffi.Void> texPtr;
    if (texture is FilamentTexture) {
      texPtr = texture.nativePointer;
    } else if (texture is ffi.Pointer<ffi.Void>) {
      texPtr = texture;
    } else {
      throw ArgumentError.value(
        texture,
        'texture',
        'Expected FilamentTexture or Pointer<Void>',
      );
    }

    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_texture_ex(
      _ptr,
      nativeName.cast(),
      texPtr,
      sampler.packed,
    );
    calloc.free(nativeName);
  }

  // --- Render State Overrides ---

  /// Gets the face culling mode.
  CullingMode get cullingMode {
    _checkDisposed();
    final mode = c.filament_material_instance_get_culling_mode(_ptr);
    return CullingMode.values.firstWhere((e) => e.value == mode, orElse: () => CullingMode.back);
  }

  /// Sets the face culling mode for all passes.
  void setCullingMode(CullingMode mode) {
    _checkDisposed();
    c.filament_material_instance_set_culling_mode(_ptr, mode.value);
  }

  /// Sets the face culling mode separately for the color pass and shadow pass.
  void setCullingModeSeparate(CullingMode colorPassMode, CullingMode shadowPassMode) {
    _checkDisposed();
    c.filament_material_instance_set_culling_mode2(_ptr, colorPassMode.value, shadowPassMode.value);
  }

  /// Gets whether this instance is double sided.
  bool get isDoubleSided {
    _checkDisposed();
    return c.filament_material_instance_is_double_sided(_ptr);
  }

  /// Sets whether this instance is double sided.
  /// 
  /// Note: Setting this to true disables culling inside Filament. 
  /// Calling `setCullingMode` afterwards re-overrides this behavior.
  void setDoubleSided(bool doubleSided) {
    _checkDisposed();
    c.filament_material_instance_set_double_sided(_ptr, doubleSided);
  }

  /// Gets whether color write is enabled.
  bool get isColorWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_color_write_enabled(_ptr);
  }

  /// Enables or disables writing into the color buffer.
  void setColorWrite(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_color_write(_ptr, enable);
  }

  /// Gets whether depth write is enabled.
  bool get isDepthWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_depth_write_enabled(_ptr);
  }

  /// Enables or disables writing into the depth buffer.
  void setDepthWrite(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_depth_write(_ptr, enable);
  }

  /// Gets whether depth culling is enabled.
  bool get isDepthCullingEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_depth_culling_enabled(_ptr);
  }

  /// Enables or disables depth testing (culling).
  void setDepthCulling(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_depth_culling(_ptr, enable);
  }

  /// Gets the depth comparison function.
  DepthFunc get depthFunc {
    _checkDisposed();
    final func = c.filament_material_instance_get_depth_func(_ptr);
    return DepthFunc.values.firstWhere((e) => e.value == func, orElse: () => DepthFunc.le);
  }

  /// Sets the depth comparison function.
  void setDepthFunc(DepthFunc func) {
    _checkDisposed();
    c.filament_material_instance_set_depth_func(_ptr, func.value);
  }

  /// Gets the transparency mode.
  TransparencyMode get transparencyMode {
    _checkDisposed();
    final mode = c.filament_material_instance_get_transparency_mode(_ptr);
    return TransparencyMode.values.firstWhere((e) => e.value == mode, orElse: () => TransparencyMode.defaultMode);
  }

  /// Sets the transparency mode.
  void setTransparencyMode(TransparencyMode mode) {
    _checkDisposed();
    c.filament_material_instance_set_transparency_mode(_ptr, mode.value);
  }

  /// Gets the mask threshold (alpha cutoff).
  double get maskThreshold {
    _checkDisposed();
    return c.filament_material_instance_get_mask_threshold(_ptr);
  }

  /// Sets the mask threshold (alpha cutoff). 
  /// Only affects materials built with `blending: masked`.
  void setMaskThreshold(double threshold) {
    _checkDisposed();
    c.filament_material_instance_set_mask_threshold(_ptr, threshold);
  }

  /// Sets the polygon offset for this instance (useful for decals).
  void setPolygonOffset(double scale, double constant) {
    _checkDisposed();
    c.filament_material_instance_set_polygon_offset(_ptr, scale, constant);
  }

  /// Sets a custom scissor rectangle for this instance.
  /// WARNING: Scissor coordinates use a BOTTOM-LEFT origin (Filament convention), 
  /// unlike Flutter's top-left origin.
  void setScissor({required int left, required int bottom, required int width, required int height}) {
    _checkDisposed();
    c.filament_material_instance_set_scissor(_ptr, left, bottom, width, height);
  }

  /// Removes the custom scissor rectangle, reverting to the view's viewport.
  void unsetScissor() {
    _checkDisposed();
    c.filament_material_instance_unset_scissor(_ptr);
  }

  /// Sets whether stencil buffer writing is enabled for this instance.
  void setStencilWrite(bool enabled) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_write(_ptr, enabled);
  }

  /// Gets whether stencil buffer writing is enabled for this instance.
  bool get isStencilWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_stencil_write_enabled(_ptr);
  }

  /// Sets the stencil comparison function.
  void setStencilCompareFunction(DepthFunc func, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_compare_function(_ptr, func.value, face.value);
  }

  /// Sets the stencil fail operation.
  void setStencilOpStencilFail(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_stencil_fail(_ptr, op.value, face.value);
  }

  /// Sets the depth fail operation.
  void setStencilOpDepthFail(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_depth_fail(_ptr, op.value, face.value);
  }

  /// Sets the depth-stencil pass operation.
  void setStencilOpDepthStencilPass(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_depth_stencil_pass(_ptr, op.value, face.value);
  }

  /// Sets the stencil reference value.
  void setStencilReferenceValue(int value, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (value < 0 || value > 255) {
      throw RangeError.range(value, 0, 255, 'value');
    }
    c.filament_material_instance_set_stencil_reference_value(_ptr, value, face.value);
  }

  /// Sets the stencil read mask.
  void setStencilReadMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (mask < 0 || mask > 255) {
      throw RangeError.range(mask, 0, 255, 'mask');
    }
    c.filament_material_instance_set_stencil_read_mask(_ptr, mask, face.value);
  }

  /// Sets the stencil write mask.
  void setStencilWriteMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (mask < 0 || mask > 255) {
      throw RangeError.range(mask, 0, 255, 'mask');
    }
    c.filament_material_instance_set_stencil_write_mask(_ptr, mask, face.value);
  }

  /// Sets a specialization constant of integer type.
  void setConstantInt(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_int(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets a specialization constant of float type.
  void setConstantFloat(String name, double value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_float(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets a specialization constant of boolean type.
  void setConstantBool(String name, bool value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_bool(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a float parameter value.
  double getFloat(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_float(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 2-component float parameter value.
  (double, double) getFloat2(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(2);
    try {
      c.filament_material_instance_get_parameter_float2(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 3-component float parameter value.
  (double, double, double) getFloat3(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(3);
    try {
      c.filament_material_instance_get_parameter_float3(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 4-component float parameter value.
  (double, double, double, double) getFloat4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(4);
    try {
      c.filament_material_instance_get_parameter_float4(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2], ptr[3]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads an integer parameter value.
  int getInt(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_int(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 2-component integer parameter value.
  (int, int) getInt2(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(2);
    try {
      c.filament_material_instance_get_parameter_int2(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 3-component integer parameter value.
  (int, int, int) getInt3(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(3);
    try {
      c.filament_material_instance_get_parameter_int3(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 4-component integer parameter value.
  (int, int, int, int) getInt4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(4);
    try {
      c.filament_material_instance_get_parameter_int4(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2], ptr[3]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads an unsigned integer parameter value.
  int getUint(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_uint(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a boolean parameter value.
  bool getBool(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_bool(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 4x4 float matrix parameter value.
  Float32List getMat4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(16);
    try {
      c.filament_material_instance_get_parameter_mat4(_ptr, nativeName.cast(), ptr);
      final list = Float32List(16);
      for (int i = 0; i < 16; i++) {
        list[i] = ptr[i];
      }
      return list;
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// The parent [FilamentMaterial] of this instance.
  FilamentMaterial get material {
    _checkDisposed();
    if (_parentMaterial != null) return _parentMaterial;
    final matPtr = c.filament_material_instance_get_material(_ptr);
    return FilamentMaterial.internal(matPtr, _engine);
  }

  /// The name of this material instance.
  String get name {
    _checkDisposed();
    final ptr = c.filament_material_instance_get_name(_ptr);
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  /// Sets the specular anti-aliasing variance.
  void setSpecularAntiAliasingVariance(double variance) {
    _checkDisposed();
    c.filament_material_instance_set_specular_antialiasing_variance(_ptr, variance);
  }

  /// Gets the specular anti-aliasing variance.
  double get specularAntiAliasingVariance {
    _checkDisposed();
    return c.filament_material_instance_get_specular_antialiasing_variance(_ptr);
  }

  /// Sets the specular anti-aliasing threshold.
  void setSpecularAntiAliasingThreshold(double threshold) {
    _checkDisposed();
    c.filament_material_instance_set_specular_antialiasing_threshold(_ptr, threshold);
  }

  /// Gets the specular anti-aliasing threshold.
  double get specularAntiAliasingThreshold {
    _checkDisposed();
    return c.filament_material_instance_get_specular_antialiasing_threshold(_ptr);
  }

  /// Destroys this MaterialInstance.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _parentMaterial?._instances.remove(this);
    if (!_borrowed) {
      c.filament_engine_destroy_material_instance(_engine.nativePointer, _ptr);
    }
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentMaterialInstance has been disposed');
    }
  }
}
