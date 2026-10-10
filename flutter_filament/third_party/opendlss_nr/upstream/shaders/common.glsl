// Shared numeric helpers: the half / E4M3 publication points of the network, implemented so that every kernel
// (and the CPU reference in src/reference.cpp) rounds identically.
#ifndef DLSS_COMMON_GLSL
#define DLSS_COMMON_GLSL

#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_shader_16bit_storage : require
#extension GL_EXT_shader_8bit_storage : require

// f32 -> RNE f16 -> f32, on the bit pattern.
// Don't write float(float16_t(x)): the NVIDIA compiler drops it as a no-op and the rounding
// goes with it. That was the first parity bug, inside the SiLU.
float roundF16(float value) {
  uint bits = floatBitsToUint(value);
  uint sign = bits & 0x80000000u;
  uint magnitude = bits & 0x7fffffffu;
  if (magnitude >= 0x7f800000u) return value;                                   // inf / nan
  if (magnitude >= 0x477ff000u) return uintBitsToFloat(sign | 0x7f800000u);     // >= 65520 overflows to inf
  if (magnitude < 0x38800000u) {                                                // below 2^-14: half subnormal grid 2^-24
    float scaled = roundEven(uintBitsToFloat(magnitude) * 16777216.0);
    return uintBitsToFloat(sign) + uintBitsToFloat(sign | floatBitsToUint(scaled * 0.000000059604644775390625));
  }
  uint lsb = (magnitude >> 13u) & 1u;
  uint rounded = (magnitude + 0xfffu + lsb) & ~0x1fffu;
  return uintBitsToFloat(sign | rounded);
}

uint f16Bits(float16_t value) { return uint(float16BitsToUint16(value)); }
float16_t f16FromBits(uint bits) { return uint16BitsToFloat16(uint16_t(bits & 0xffffu)); }

uint shiftRne(uint value, uint shift) {
  uint quotient = value >> shift;
  uint remainderMask = (1u << shift) - 1u;
  uint remainder = value & remainderMask;
  uint halfway = 1u << (shift - 1u);
  return quotient + ((remainder > halfway || (remainder == halfway && (quotient & 1u) != 0u)) ? 1u : 0u);
}

// An already half-rounded value to its E4M3FN code: RNE, finite saturation at 448, NaN -> +0.
// The sign of a zero survives (code 0x80), as the hardware conversion does. It makes no numeric
// difference; parity compares bytes.
uint e4m3CodeFromF16Bits(uint halfBits) {
  bool isNan = (halfBits & 0x7c00u) == 0x7c00u && (halfBits & 0x03ffu) != 0u;
  if (isNan) return 0u;
  if ((halfBits & 0x7fffu) == 0u) return (halfBits >> 8u) & 0x80u;
  uint negative = (halfBits & 0x8000u) != 0u ? 0x80u : 0u;
  uint exponent = (halfBits >> 10u) & 0x1fu;
  uint mantissa = halfBits & 0x03ffu;
  uint code;
  if (exponent == 31u) {
    code = 0x7eu;                     // inf saturates
  } else if (exponent <= 8u) {        // E4M3 subnormal
    uint significand = exponent == 0u ? mantissa : 1024u + mantissa;
    uint shift = exponent == 0u ? 15u : 16u - exponent;
    code = min(shiftRne(significand, shift), 8u);
  } else {
    uint e4Exponent = exponent - 8u;
    uint e4Mantissa = shiftRne(mantissa, 7u);
    if (e4Mantissa == 8u) { e4Mantissa = 0u; e4Exponent += 1u; }
    code = (e4Exponent > 15u || (e4Exponent == 15u && e4Mantissa > 6u)) ? 0x7eu : ((e4Exponent << 3u) | e4Mantissa);
  }
  return negative | code;
}

uint e4m3CodeFromF32(float value) { return e4m3CodeFromF16Bits(f16Bits(float16_t(value))); }

#ifdef DLSS_E4M3_HW
// Hardware cvt.rn.satfinite.e4m3, equal to e4m3CodeFromF16Bits for every non-NaN half.
// The guard is the whole difference: the instruction turns a NaN into the E4M3 NaN code, and a NaN gets
// here every time a zero row is cosine normalized (0 * inf). +0 keeps that code out of every tensor.
uint8_t e4m3Hw(float16_t value) {
  if (isnan(value)) return uint8_t(0u);
  floate4m3_t converted;
  saturatedConvertEXT(converted, value);
  return floate4m3BitsToUintEXT(converted);
}

// Two halves -> two E4M3 codes packed little-endian, same rules as e4m3Hw.
uint16_t e4m3HwPair(f16vec2 value) {
  f16vec2 clean = mix(value, f16vec2(0.0), isnan(value));
  fe4m3vec2 converted;
  saturatedConvertEXT(converted, clean);
  u8vec2 codes = floate4m3BitsToUintEXT(converted);
  return uint16_t(uint(codes.x) | (uint(codes.y) << 8u));
}

// Hardware decode. NaN codes read back as 0, as in the reference.
float e4m3HwToF32(uint code) {
  float value = float(uintBitsToFloate4m3EXT(uint8_t(code & 0xffu)));
  return isnan(value) ? 0.0 : value;
}
#endif

// The network's cubic SiLU in half FMAs: identical to the f32 formulation (mpCubicSilu below) for all
// 65536 half inputs.
float16_t siluHalf(float16_t value) {
  float16_t bounded = clamp(value, float16_t(-4.0), float16_t(4.0));
  precise float16_t inner = fma(float16_t(-0.055908203125), abs(bounded), float16_t(0.447265625));
  precise float16_t polynomial = fma(bounded, inner, float16_t(0.89453125));
  precise float16_t result = value * polynomial;
  return result;
}

f16vec2 siluPair(f16vec2 value) {
  f16vec2 bounded = clamp(value, f16vec2(-4.0), f16vec2(4.0));
  precise f16vec2 inner = fma(f16vec2(-0.055908203125), abs(bounded), f16vec2(0.447265625));
  precise f16vec2 polynomial = fma(bounded, inner, f16vec2(0.89453125));
  precise f16vec2 result = value * polynomial;
  return result;
}

float e4m3ToF32(uint bits) {
  bool negative = (bits & 0x80u) != 0u;
  uint exponent = (bits >> 3u) & 0x0fu;
  uint mantissa = bits & 0x07u;
  float value;
  if (exponent == 0u) value = float(mantissa) * 0.001953125;
  else if (exponent == 15u && mantissa == 7u) value = 0.0;
  else value = (1.0 + float(mantissa) * 0.125) * uintBitsToFloat((exponent + 120u) << 23u);
  return negative ? -value : value;
}

// The f32 spelling of siluHalf: each step is one f32 operation rounded once to half.
// The explicit fma is not decoration. Without it the compiler splits the multiply-add and
// double-rounds, which was the second thing to break parity.
float mpCubicSilu(float value) {
  precise float bounded = roundF16(clamp(value, -4.0, 4.0));
  precise float absolute = roundF16(abs(bounded));
  precise float inner = roundF16(fma(-0.055908203125, absolute, 0.447265625));
  precise float polynomial = roundF16(fma(bounded, inner, 0.89453125));
  return roundF16(value * polynomial);
}

#endif
