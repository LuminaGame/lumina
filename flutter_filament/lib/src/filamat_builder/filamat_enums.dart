part of '../filamat_builder.dart';

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
