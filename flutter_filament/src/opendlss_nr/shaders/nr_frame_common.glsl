// Shared pieces of the OpenDLSS-NR frame passes (input features and composite) on Filament's external post pass.
// Derived from OpenDLSS-NR 9d08f41 demo/shaders/nr_common.glsl (MIT, Copyright (c) 2026 maan; see
// third_party/opendlss_nr/LICENSE). Lumina's changes: the motion comes from the hook's MOTION image (texels of
// uv_curr - uv_prev, x right, y up; b = history usable) instead of the demo's unpacked velocity buffer, and the
// parameters are push constants.
// Float -> half round trips are spelled out at the bit level: the NVIDIA GLSL compiler elides float(float16_t(x)).

layout(push_constant) uniform Params {
  uint fullWidth, fullHeight, validWidth, validHeight;
  uint historyValid, seed, nrEnabled, styleId;
  float autoMask, paperWhite, colorStrength, intensity;
  float localTone, localStructure, skinStructure, blendScale;
} params;

float roundF16(float value) {
  uint bits = floatBitsToUint(value);
  uint sign = bits & 0x80000000u;
  uint magnitude = bits & 0x7fffffffu;
  if (magnitude >= 0x7f800000u) return value;
  if (magnitude >= 0x477ff000u) return uintBitsToFloat(sign | 0x7f800000u);
  if (magnitude < 0x38800000u) {
    float scaled = roundEven(uintBitsToFloat(magnitude) * 16777216.0);
    return uintBitsToFloat(sign) + uintBitsToFloat(sign | floatBitsToUint(scaled * 0.000000059604644775390625));
  }
  uint lsb = (magnitude >> 13u) & 1u;
  uint rounded = (magnitude + 0xfffu + lsb) & ~0x1fffu;
  return uintBitsToFloat(sign | rounded);
}

// Truncation (round toward zero) to the half grid: the stored history is truncated, not rounded.
float truncateHalf(float value) {
  uint bits = floatBitsToUint(value);
  uint signBit = (bits >> 16u) & 0x8000u;
  uint exponent = (bits >> 23u) & 0xffu;
  uint mantissa = bits & 0x7fffffu;
  uint halfBits;
  if (exponent == 0xffu) {
    halfBits = signBit | (mantissa != 0u ? 0x7e00u : 0x7c00u);
  } else {
    int halfExponent = int(exponent) - 112;
    if (halfExponent >= 31) halfBits = signBit | 0x7c00u;
    else if (halfExponent <= 0) {
      if (halfExponent < -10) halfBits = signBit;
      else halfBits = signBit | ((mantissa | 0x800000u) >> uint(14 - halfExponent));
    } else halfBits = signBit | (uint(halfExponent) << 10u) | (mantissa >> 13u);
  }
  return unpackHalf2x16(halfBits).x;
}

float finiteNonnegative(float value) {
  return (value == value && abs(value) <= 65504.0) ? max(value, 0.0) : 0.0;
}

float srgbEncode(float value) {
  float bounded = clamp(value, 0.0, 1.0);
  return bounded <= 0.0031308 ? 12.92 * bounded : 1.055 * pow(bounded, 1.0 / 2.4) - 0.055;
}

float srgbDecode(float value) {
  float bounded = clamp(value, 0.0, 1.0);
  return bounded <= 0.04045 ? bounded / 12.92 : pow((bounded + 0.055) / 1.055, 2.4);
}

// The display proxy: paper-white relative scene value with a soft shoulder, sRGB encoded, on the half grid.
float proxyComponent(float scene, float paperWhite) {
  float value = scene / max(paperWhite, 0.05);
  if (value > 0.75) value = 0.75 + 0.25 * (1.0 - exp(-5.770780 * (value - 0.75)));
  return roundF16(srgbEncode(value));
}

// Where `pixel` was in the previous frame, in uv with y down: the hook's motion is uv_curr - uv_prev in texels
// with y up, and its rows run top-down like the colour's.
vec2 historyUv(sampler2D motionTex, vec2 pixel, vec2 valid) {
  vec2 uv = (pixel + 0.5) / valid;
  vec2 m = texelFetch(motionTex, ivec2(pixel), 0).xy;
  return uv + vec2(-m.x, m.y) / valid;
}

// Whether the previous frame shows this surface (the hook's history flag). Without one, the history sample
// below is another surface's colour and must not be used.
bool hasHistory(sampler2D motionTex, vec2 pixel) {
  return texelFetch(motionTex, ivec2(pixel), 0).z > 0.5;
}

// Five-tap Catmull-Rom reconstruction of the history (the four axis taps plus the centre, with the
// bilinear-weight trick). A box or bilinear filter here softens the image frame over frame, because the
// history is fed back into the network's input.
vec3 historySample(sampler2D previousTex, sampler2D motionTex, vec2 pixel, vec2 valid) {
  vec2 position = historyUv(motionTex, pixel, valid) * valid;
  vec2 base = floor(position - 0.5) + 0.5;
  vec2 f = clamp(position - base, vec2(0.0), vec2(1.0));
  vec2 square = f * f; vec2 cube = f * square;
  vec2 w0 = fma(f + cube, vec2(-0.5), square);
  vec2 w1 = (cube * 1.5 - square * 2.5) + 1.0;
  vec2 w3 = (cube - square) * 0.5;
  vec2 w2 = ((1.0 - w0) - w1) - w3;
  vec2 middle = w1 + w2;
  vec2 low = clamp(base - 1.0, vec2(0.5), valid - 0.5) / valid;
  vec2 center = clamp(base + w2 / middle, vec2(0.5), valid - 0.5) / valid;
  vec2 high = clamp(base + 2.0, vec2(0.5), valid - 0.5) / valid;
  vec3 left = textureLod(previousTex, vec2(low.x, center.y), 0.0).rgb;
  vec3 top = textureLod(previousTex, vec2(center.x, low.y), 0.0).rgb;
  vec3 mid = textureLod(previousTex, center, 0.0).rgb;
  vec3 bottom = textureLod(previousTex, vec2(center.x, high.y), 0.0).rgb;
  vec3 right = textureLod(previousTex, vec2(high.x, center.y), 0.0).rgb;
  float a = w0.x * middle.y; float b = w0.y * middle.x;
  float c = middle.x * middle.y; float d = w3.y * middle.x; float e = w3.x * middle.y;
  vec3 value = fma(left, vec3(a), top * b);
  value = fma(mid, vec3(c), value);
  value = fma(bottom, vec3(d), value);
  value = fma(right, vec3(e), value);
  return value * (1.0 / (e + (d + (c + (a + b)))));
}
