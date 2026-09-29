/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Primitive types for renderable objects matching Filament C++ backend values.
enum PrimitiveType {
  points(0),
  lines(1),
  lineStrip(3),
  triangles(4),
  triangleStrip(5);

  final int value;
  const PrimitiveType(this.value);

  /// Backward-compatible alias for [value].
  int get rawValue => value;
}

/// Index element type matching backend::ElementType::USHORT and UINT.
enum IndexType {
  ushort(12),
  uint(17);

  final int value;
  const IndexType(this.value);
}



/// Bitmask describing intended texture usage in Filament.
abstract final class TextureUsage {
  static const int none = 0x0000;
  static const int colorAttachment = 0x0001;
  static const int depthAttachment = 0x0002;
  static const int stencilAttachment = 0x0004;
  static const int uploadable = 0x0008;
  static const int sampleable = 0x0010;
  static const int subpassInput = 0x0020;
  static const int blitSrc = 0x0040;
  static const int blitDst = 0x0080;
  static const int protectedUsage = 0x0100;
  static const int genMipmappable = 0x0200;
  static const int defaultUsage = uploadable | sampleable;
  static const int allAttachments = colorAttachment | depthAttachment | stencilAttachment | subpassInput;
}

/// Result returned by builders (RenderableManager, LightManager).
enum BuilderResult {
  error(-1),
  success(0);

  final int value;
  const BuilderResult(this.value);
}

/// Bitmask describing morphing capabilities on renderables.
abstract final class MorphType {
  static const int none = 0;
  static const int positions = 1;
  static const int tangents = 2;
  static const int custom = 4;
}

/// Type of geometry for a Renderable.
enum GeometryType {
  dynamicGeometry(0),
  staticBounds(1),
  staticGeometry(2);

  final int value;
  const GeometryType(this.value);
}

/// Vertex attributes supported by Filament.
enum VertexAttribute {
  position(0),
  tangents(1),
  color(2),
  uv0(3),
  uv1(4),
  boneIndices(5),
  boneWeights(6),
  custom0(8),
  custom1(9),
  custom2(10),
  custom3(11),
  custom4(12),
  custom5(13),
  custom6(14),
  custom7(15);

  final int value;
  const VertexAttribute(this.value);
}

/// Element data types for vertex buffer attributes matching Filament's `backend::ElementType`.
enum AttributeType {
  byte(0),
  byte2(1),
  byte3(2),
  byte4(3),
  ubyte(4),
  ubyte2(5),
  ubyte3(6),
  ubyte4(7),
  shortType(8),
  short2(9),
  short3(10),
  short4(11),
  ushort(12),
  ushort2(13),
  ushort3(14),
  ushort4(15),
  intType(16),
  uint(17),
  floatType(18),
  float2(19),
  float3(20),
  float4(21),
  half(22),
  half2(23),
  half3(24),
  half4(25);

  final int value;
  const AttributeType(this.value);

  static const AttributeType byte_ = byte;
  static const AttributeType short_ = shortType;
  static const AttributeType int_ = intType;
  static const AttributeType float_ = floatType;

  int get byteSize {
    switch (this) {
      case AttributeType.byte:
      case AttributeType.ubyte:
        return 1;
      case AttributeType.byte2:
      case AttributeType.ubyte2:
      case AttributeType.shortType:
      case AttributeType.ushort:
      case AttributeType.half:
        return 2;
      case AttributeType.byte3:
      case AttributeType.ubyte3:
        return 3;
      case AttributeType.byte4:
      case AttributeType.ubyte4:
      case AttributeType.short2:
      case AttributeType.ushort2:
      case AttributeType.half2:
      case AttributeType.intType:
      case AttributeType.uint:
      case AttributeType.floatType:
        return 4;
      case AttributeType.short3:
      case AttributeType.ushort3:
      case AttributeType.half3:
        return 6;
      case AttributeType.short4:
      case AttributeType.ushort4:
      case AttributeType.half4:
      case AttributeType.float2:
        return 8;
      case AttributeType.float3:
        return 12;
      case AttributeType.float4:
        return 16;
    }
  }
}

/// Supported uniform types matching Filament's `backend::UniformType`.
enum UniformType {
  boolType(0),
  bool2(1),
  bool3(2),
  bool4(3),
  floatType(4),
  float2(5),
  float3(6),
  float4(7),
  intType(8),
  int2(9),
  int3Type(10),
  int4(11),
  uint(12),
  uint2(13),
  uint3(14),
  uint4(15),
  mat3(16),
  mat4(17),
  structType(18);

  final int value;
  const UniformType(this.value);

  static const UniformType bool_ = boolType;
  static const UniformType float_ = floatType;
  static const UniformType int_ = intType;
  static const UniformType int3 = int3Type;
  static const UniformType struct_ = structType;
}

/// Precision specification for material parameters matching Filament's `backend::Precision`.
enum ParameterPrecision {
  low(0),
  medium(1),
  high(2),
  defaultPrecision(3);

  final int value;
  const ParameterPrecision(this.value);

  static const ParameterPrecision default_ = defaultPrecision;
}

/// RGB Color Space type.
enum RgbType {
  sRgb(0),
  linear(1);

  final int value;
  const RgbType(this.value);
}

/// RGBA Color Space type.
enum RgbaType {
  sRgb(0),
  linear(1),
  premultipliedSRgb(2),
  premultipliedLinear(3);

  final int value;
  const RgbaType(this.value);
}

/// Face culling mode matching Filament's `backend::CullingMode`.
enum CullingMode {
  none(0),
  front(1),
  back(2),
  frontAndBack(3);

  final int value;
  const CullingMode(this.value);
}

/// Depth and stencil comparison function matching Filament's `backend::SamplerCompareFunc`.
enum DepthFunc {
  le(0),
  ge(1),
  l(2),
  g(3),
  e(4),
  ne(5),
  a(6),
  n(7);

  final int value;
  const DepthFunc(this.value);
}

/// Transparency mode for rendering matching Filament's `TransparencyMode`.
enum TransparencyMode {
  defaultMode(0),
  twoPassesOneSide(1),
  twoPassesTwoSides(2);

  final int value;
  const TransparencyMode(this.value);

  static const TransparencyMode default_ = defaultMode;
}

/// Face selection for stencil operations matching Filament's `backend::StencilFace`.
enum StencilFace {
  front(1),
  back(2),
  frontAndBack(3);

  final int value;
  const StencilFace(this.value);
}

/// Stencil buffer operations matching Filament's `backend::StencilOperation`.
enum StencilOperation {
  keep(0),
  zero(1),
  replace(2),
  incr(3),
  incrWrap(4),
  decr(5),
  decrWrap(6),
  invert(7);

  final int value;
  const StencilOperation(this.value);
}

