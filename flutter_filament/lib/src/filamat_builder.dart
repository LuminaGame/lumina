import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/enums.dart';

/// Shading models for runtime GLSL materials.
enum FilamatShading {
  unlit(0),
  lit(1),
  subsurface(2),
  cloth(3),
  specularGlossiness(4);

  final int value;
  const FilamatShading(this.value);
}

/// Material domain for shaders.
enum MaterialDomain {
  surface(0),
  postProcess(1),
  compute(2);

  final int value;
  const MaterialDomain(this.value);
}

/// Supported blending modes.
enum BlendingMode {
  opaque(0),
  transparent(1),
  add(2),
  masked(3),
  fade(4),
  multiply(5),
  screen(6),
  custom(7);

  final int value;
  const BlendingMode(this.value);
}

/// Blending functions for custom blend modes.
enum BlendFunction {
  zero(0),
  one(1),
  srcColor(2),
  oneMinusSrcColor(3),
  dstColor(4),
  oneMinusDstColor(5),
  srcAlpha(6),
  oneMinusSrcAlpha(7),
  dstAlpha(8),
  oneMinusDstAlpha(9),
  srcAlphaSaturate(10);

  final int value;
  const BlendFunction(this.value);
}

/// Refraction modes.
enum RefractionMode {
  none(0),
  cubemap(1),
  screenSpace(2);

  final int value;
  const RefractionMode(this.value);
}

/// Refraction types.
enum RefractionType {
  solid(0),
  thin(1);

  final int value;
  const RefractionType(this.value);
}

/// Reflection modes.
enum ReflectionMode {
  default_(0),
  screenSpace(1);

  final int value;
  const ReflectionMode(this.value);
}

/// Specular ambient occlusion modes.
enum SpecularAOMode {
  none(0),
  simple(1),
  bentNormals(2);

  final int value;
  const SpecularAOMode(this.value);
}

/// Custom interpolant variables for vertex-to-fragment communication.
enum MaterialVariable {
  custom0(0),
  custom1(1),
  custom2(2),
  custom3(3),
  custom4(4);

  final int value;
  const MaterialVariable(this.value);
}

/// Types of vertex domains.
enum VertexDomain {
  object(0),
  world(1),
  view(2),
  device(3);

  final int value;
  const VertexDomain(this.value);
}

/// Target platforms.
enum MaterialPlatform {
  desktop(0),
  mobile(1),
  all(2);

  final int value;
  const MaterialPlatform(this.value);
}

/// Target API / language representations.
enum TargetApi {
  opengl(0x01),
  vulkan(0x02),
  metal(0x04),
  webgpu(0x08),
  all(0x07);

  final int value;
  const TargetApi(this.value);
}

/// Shader optimization levels.
enum OptimizationLevel {
  none(0),
  preprocessor(1),
  size(2),
  performance(3);

  final int value;
  const OptimizationLevel(this.value);
}

/// Target buffer for post-process outputs.
enum OutputTarget {
  color(0),
  depth(1);

  final int value;
  const OutputTarget(this.value);
}

/// Data type for fragment shader outputs.
enum OutputType {
  float(0),
  float2(1),
  float3(2),
  float4(3),
  int_(4),
  int2(5),
  int3(6),
  int4(7),
  uint(8),
  uint2(9),
  uint3(10),
  uint4(11);

  final int value;
  const OutputType(this.value);
}

/// Variable qualifiers for post-process outputs.
enum VariableQualifier {
  out_(0);

  final int value;
  const VariableQualifier(this.value);
}

/// Shader quality levels.
enum ShaderQuality {
  default_(-1),
  low(0),
  normal(1),
  high(2);

  final int value;
  const ShaderQuality(this.value);
}

/// Interpolation mode for attributes in fragment shader.
enum Interpolation {
  smooth(0),
  flat(1);

  final int value;
  const Interpolation(this.value);
}

/// Bitmask constants for user variant filtering.
abstract final class UserVariantFilterBit {
  static const int directionalLighting = 0x01;
  static const int dynamicLighting = 0x02;
  static const int shadowReceiver = 0x04;
  static const int skinning = 0x08;
  static const int fog = 0x10;
  static const int vsm = 0x20;
  static const int ssr = 0x40;
  static const int ste = 0x80;
  static const int all = 0xFF;
}

/// Dynamically builds and compiles GLSL material shaders into binary `.filamat` packages at runtime.
class FilamentMaterialBuilder {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  FilamentMaterialBuilder._(this._ptr);

  /// Initializes the filamat compiler engine. Must be called once before building.
  static void initEngine() {
    c.filament_filamat_init();
  }

  /// Shuts down the filamat compiler engine.
  static void shutdownEngine() {
    c.filament_filamat_shutdown();
  }

  /// Creates a new [FilamentMaterialBuilder].
  static FilamentMaterialBuilder create() {
    final ptr = c.filament_material_builder_create();
    return FilamentMaterialBuilder._(ptr);
  }

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Sets the material name.
  void setName(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_set_name(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets the GLSL shader code block.
  void setCode(String glslCode) {
    _checkDisposed();
    final nativeCode = glslCode.toNativeUtf8();
    try {
      c.filament_material_builder_set_code(_ptr, nativeCode.cast());
    } finally {
      calloc.free(nativeCode);
    }
  }

  /// Sets the vertex shader code block.
  void materialVertex(String glslCode) {
    _checkDisposed();
    final nativeCode = glslCode.toNativeUtf8();
    try {
      c.filament_material_builder_material_vertex(_ptr, nativeCode.cast());
    } finally {
      calloc.free(nativeCode);
    }
  }

  /// Sets the shading model.
  void setShading(FilamatShading shading) {
    _checkDisposed();
    c.filament_material_builder_set_shading(_ptr, shading.index);
  }

  /// Sets whether the material is double-sided.
  void setDoubleSided(bool doubleSided) {
    _checkDisposed();
    c.filament_material_builder_set_double_sided(_ptr, doubleSided);
  }

  /// Requires a vertex attribute (e.g. 2 for COLOR).
  void requireAttribute(int attribute) {
    _checkDisposed();
    c.filament_material_builder_require_attribute(_ptr, attribute);
  }

  /// Adds a sampler parameter (e.g. 0 for SAMPLER_2D).
  void addSamplerParameter(String name, {int samplerType = 0}) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_parameter_sampler(_ptr, nativeName.cast(), samplerType);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Adds a uniform parameter.
  void addParameter(
    String name,
    UniformType type, {
    ParameterPrecision precision = ParameterPrecision.default_,
  }) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_parameter(
        _ptr,
        nativeName.cast(),
        type.value,
        precision.value,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Adds a uniform array parameter.
  void addParameterArray(
    String name,
    int size,
    UniformType type, {
    ParameterPrecision precision = ParameterPrecision.default_,
  }) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_parameter_array(
        _ptr,
        nativeName.cast(),
        size,
        type.value,
        precision.value,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Adds a specialization constant of boolean type.
  void constantBool(String name, bool defaultValue) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_constant_bool(_ptr, nativeName.cast(), defaultValue);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Adds a specialization constant of integer type.
  void constantInt(String name, int defaultValue) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_constant_int(_ptr, nativeName.cast(), defaultValue);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Adds a specialization constant of float type.
  void constantFloat(String name, double defaultValue) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_constant_float(_ptr, nativeName.cast(), defaultValue);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Declares a custom variable interpolant.
  void variable(
    MaterialVariable variable,
    String name, {
    ParameterPrecision? precision,
  }) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      if (precision != null) {
        c.filament_material_builder_variable_precision(
          _ptr,
          variable.value,
          nativeName.cast(),
          precision.value,
        );
      } else {
        c.filament_material_builder_variable(
          _ptr,
          variable.value,
          nativeName.cast(),
        );
      }
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets the vertex domain.
  void vertexDomain(VertexDomain domain) {
    _checkDisposed();
    c.filament_material_builder_vertex_domain(_ptr, domain.value);
  }

  /// Sets whether the vertex domain in DEVICE space is jittered.
  void vertexDomainDeviceJittered(bool jittered) {
    _checkDisposed();
    c.filament_material_builder_vertex_domain_device_jittered(_ptr, jittered);
  }

  /// Sets whether to flip the Y coordinate of UV attributes (default true in Filament).
  void flipUV(bool flip) {
    _checkDisposed();
    c.filament_material_builder_flip_uv(_ptr, flip);
  }

  /// Sets the blending mode for this material.
  void blending(BlendingMode mode) {
    _checkDisposed();
    c.filament_material_builder_blending(_ptr, mode.value);
  }

  /// Sets custom blend functions (requires [BlendingMode.custom]).
  void customBlendFunctions({
    required BlendFunction srcRgb,
    required BlendFunction srcA,
    required BlendFunction dstRgb,
    required BlendFunction dstA,
  }) {
    _checkDisposed();
    c.filament_material_builder_custom_blend_functions(
      _ptr,
      srcRgb.value,
      srcA.value,
      dstRgb.value,
      dstA.value,
    );
  }

  /// Sets post-lighting blending mode.
  void postLightingBlending(BlendingMode mode) {
    _checkDisposed();
    c.filament_material_builder_post_lighting_blending(_ptr, mode.value);
  }

  /// Sets transparency mode.
  void transparencyMode(TransparencyMode mode) {
    _checkDisposed();
    c.filament_material_builder_transparency_mode(_ptr, mode.value);
  }

  /// Sets the clipping threshold for MASKED blending mode.
  void maskThreshold(double threshold) {
    _checkDisposed();
    c.filament_material_builder_mask_threshold(_ptr, threshold);
  }

  /// Enables alpha-to-coverage for MSAA.
  void alphaToCoverage(bool enable) {
    _checkDisposed();
    c.filament_material_builder_alpha_to_coverage(_ptr, enable);
  }

  /// Sets refraction mode.
  void refractionMode(RefractionMode mode) {
    _checkDisposed();
    c.filament_material_builder_refraction_mode(_ptr, mode.value);
  }

  /// Sets refraction type.
  void refractionType(RefractionType type) {
    _checkDisposed();
    c.filament_material_builder_refraction_type(_ptr, type.value);
  }

  /// Sets triangle culling mode.
  void culling(CullingMode mode) {
    _checkDisposed();
    c.filament_material_builder_culling(_ptr, mode.value);
  }

  /// Enables or disables color buffer writing.
  void colorWrite(bool enable) {
    _checkDisposed();
    c.filament_material_builder_color_write(_ptr, enable);
  }

  /// Enables or disables depth buffer writing.
  void depthWrite(bool enable) {
    _checkDisposed();
    c.filament_material_builder_depth_write(_ptr, enable);
  }

  /// Enables or disables depth culling/testing.
  void depthCulling(bool enable) {
    _checkDisposed();
    c.filament_material_builder_depth_culling(_ptr, enable);
  }

  /// Enables instanced primitive support.
  void instanced(bool enable) {
    _checkDisposed();
    c.filament_material_builder_instanced(_ptr, enable);
  }

  /// Convenience preset configuring transparent material settings.
  void transparentPreset() {
    blending(BlendingMode.transparent);
    depthWrite(false);
  }

  /// Sets the material domain (surface, post-process, compute).
  void materialDomain(MaterialDomain domain) {
    _checkDisposed();
    c.filament_material_builder_material_domain(_ptr, domain.value);
  }

  /// Sets compute kernel group size.
  void groupSize({int x = 1, int y = 1, int z = 1}) {
    _checkDisposed();
    c.filament_material_builder_group_size(_ptr, x, y, z);
  }

  /// Adds a fragment shader output variable (for POST_PROCESS domain).
  void output({
    VariableQualifier qualifier = VariableQualifier.out_,
    required OutputTarget target,
    ParameterPrecision precision = ParameterPrecision.default_,
    required OutputType type,
    required String name,
    int location = -1,
  }) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_output(
        _ptr,
        qualifier.value,
        target.value,
        precision.value,
        type.value,
        nativeName.cast(),
        location,
      );
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Enables framebuffer fetch in shaders.
  void enableFramebufferFetch() {
    _checkDisposed();
    c.filament_material_builder_enable_framebuffer_fetch(_ptr);
  }

  /// Adds a subpass input parameter.
  void subpass({int type = 0, required String name}) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_builder_subpass(_ptr, type, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets target platform hint.
  void platform(MaterialPlatform platform) {
    _checkDisposed();
    c.filament_material_builder_platform(_ptr, platform.value);
  }

  /// Sets target rendering API.
  void targetApi(TargetApi api) {
    _checkDisposed();
    c.filament_material_builder_target_api(_ptr, api.value);
  }

  /// Sets shader optimization level.
  void optimization(OptimizationLevel level) {
    _checkDisposed();
    c.filament_material_builder_optimization(_ptr, level.value);
  }

  /// Specifies a bitmask of variants to filter out.
  void variantFilter(int mask) {
    _checkDisposed();
    c.filament_material_builder_variant_filter(_ptr, mask);
  }

  /// Adds a preprocessor macro define.
  void shaderDefine(String name, String value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final nativeValue = value.toNativeUtf8();
    try {
      c.filament_material_builder_shader_define(
        _ptr,
        nativeName.cast(),
        nativeValue.cast(),
      );
    } finally {
      calloc.free(nativeValue);
      calloc.free(nativeName);
    }
  }

  /// Multiplies material output by shadowing factor (UNLIT model only).
  void shadowMultiplier(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_shadow_multiplier(_ptr, enabled);
  }

  /// Enables casting transparent shadows.
  void transparentShadow(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_transparent_shadow(_ptr, enabled);
  }

  /// Enables colored penumbrae for cast shadows.
  void coloredPenumbra(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_colored_penumbra(_ptr, enabled);
  }

  /// Enables shadow far attenuation.
  void shadowFarAttenuation(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_shadow_far_attenuation(_ptr, enabled);
  }

  /// Sets shader compilation quality.
  void quality(ShaderQuality quality) {
    _checkDisposed();
    c.filament_material_builder_quality(_ptr, quality.value);
  }

  /// Sets target feature level.
  void featureLevel(int level) {
    _checkDisposed();
    c.filament_material_builder_feature_level(_ptr, level);
  }

  /// Enables generation of ESSL 1.0 code for FL0.
  void includeEssl1(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_include_essl1(_ptr, enabled);
  }

  /// Sets fragment attribute interpolation mode.
  void interpolation(Interpolation interpolation) {
    _checkDisposed();
    c.filament_material_builder_interpolation(_ptr, interpolation.value);
  }

  /// Enables specular anti-aliasing with optional variance and threshold.
  void specularAntiAliasing(
    bool enabled, {
    double? variance,
    double? threshold,
  }) {
    _checkDisposed();
    c.filament_material_builder_specular_anti_aliasing(_ptr, enabled);
    if (variance != null) {
      c.filament_material_builder_specular_anti_aliasing_variance(_ptr, variance);
    }
    if (threshold != null) {
      c.filament_material_builder_specular_anti_aliasing_threshold(_ptr, threshold);
    }
  }

  /// Enables or disables clear coat index of refraction darkening.
  void clearCoatIorChange(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_clear_coat_ior_change(_ptr, enabled);
  }

  /// Enables linear fog.
  void linearFog(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_linear_fog(_ptr, enabled);
  }

  /// Enables custom surface shading function in GLSL fragment.
  void customSurfaceShading(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_custom_surface_shading(_ptr, enabled);
  }

  /// Sets reflection rendering mode.
  void reflectionMode(ReflectionMode mode) {
    _checkDisposed();
    c.filament_material_builder_reflection_mode(_ptr, mode.value);
  }

  /// Enables multi-bounce ambient occlusion.
  void multiBounceAmbientOcclusion(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_multi_bounce_ambient_occlusion(_ptr, enabled);
  }

  /// Sets specular ambient occlusion mode.
  void specularAmbientOcclusion(SpecularAOMode mode) {
    _checkDisposed();
    c.filament_material_builder_specular_ambient_occlusion(_ptr, mode.value);
  }

  /// Debug: Outputs generated GLSL shader code to stdout.
  void printShaders(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_print_shaders(_ptr, enabled);
  }

  /// Debug: Writes raw generated GLSL variant files to the working directory.
  void saveRawVariants(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_save_raw_variants(_ptr, enabled);
  }

  /// Debug: Includes debugging symbols in generated SPIRV package.
  void generateDebugInfo(bool enabled) {
    _checkDisposed();
    c.filament_material_builder_generate_debug_info(_ptr, enabled);
  }

  /// Converts a string identifier to its matching [UniformType], or null.
  static UniformType? uniformTypeFromString(String name) {
    switch (name.toLowerCase()) {
      case 'bool':
      case 'booltype':
        return UniformType.boolType;
      case 'bool2':
        return UniformType.bool2;
      case 'bool3':
        return UniformType.bool3;
      case 'bool4':
        return UniformType.bool4;
      case 'float':
      case 'floattype':
        return UniformType.floatType;
      case 'float2':
        return UniformType.float2;
      case 'float3':
        return UniformType.float3;
      case 'float4':
        return UniformType.float4;
      case 'int':
      case 'inttype':
        return UniformType.intType;
      case 'int2':
        return UniformType.int2;
      case 'int3':
      case 'int3_type':
        return UniformType.int3Type;
      case 'int4':
        return UniformType.int4;
      case 'uint':
        return UniformType.uint;
      case 'uint2':
        return UniformType.uint2;
      case 'uint3':
        return UniformType.uint3;
      case 'uint4':
        return UniformType.uint4;
      case 'mat3':
        return UniformType.mat3;
      case 'mat4':
        return UniformType.mat4;
      case 'struct':
      case 'structtype':
        return UniformType.structType;
      default:
        return null;
    }
  }

  /// Converts a [UniformType] to its string representation.
  static String uniformTypeToString(UniformType type) {
    switch (type) {
      case UniformType.boolType:
        return 'bool';
      case UniformType.bool2:
        return 'bool2';
      case UniformType.bool3:
        return 'bool3';
      case UniformType.bool4:
        return 'bool4';
      case UniformType.floatType:
        return 'float';
      case UniformType.float2:
        return 'float2';
      case UniformType.float3:
        return 'float3';
      case UniformType.float4:
        return 'float4';
      case UniformType.intType:
        return 'int';
      case UniformType.int2:
        return 'int2';
      case UniformType.int3Type:
        return 'int3';
      case UniformType.int4:
        return 'int4';
      case UniformType.uint:
        return 'uint';
      case UniformType.uint2:
        return 'uint2';
      case UniformType.uint3:
        return 'uint3';
      case UniformType.uint4:
        return 'uint4';
      case UniformType.mat3:
        return 'mat3';
      case UniformType.mat4:
        return 'mat4';
      case UniformType.structType:
        return 'struct';
    }
  }

  /// Compiles the GLSL shader and builds a `.filamat` binary buffer.
  ///
  /// Returns `null` if compilation failed.
  Uint8List? build() {
    _checkDisposed();
    final outSizePtr = calloc<ffi.Size>();
    try {
      final bufferPtr = c.filament_material_builder_build(_ptr, outSizePtr);
      if (bufferPtr == ffi.nullptr) {
        return null;
      }
      final size = outSizePtr.value;
      final nativeBytes = bufferPtr.cast<ffi.Uint8>().asTypedList(size);
      final resultBytes = Uint8List.fromList(nativeBytes);
      c.filament_filamat_free_package(bufferPtr);
      return resultBytes;
    } finally {
      calloc.free(outSizePtr);
    }
  }

  /// Disposes this builder.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_material_builder_destroy(_ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentMaterialBuilder has been disposed');
    }
  }
}
