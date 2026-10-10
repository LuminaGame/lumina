// Shared machinery of the fused window-attention kernels (fused_block32.comp,
// window_attention_fused.comp). The includer declares, before including:
//   layout(...) readonly buffer Prior { float16_t prior[]; };   // [heads][64][64] f16
//   shared uvec4 kv4[...];        // per window: Kp [64][32] E4 at KP, Vp [64][32] E4 at VP (physical-tiled rows)
//   shared uvec4 priv4[...];      // PRIV words per subgroup, phase-aliased:
//     E4 rows  @0..31   [16][32] E4, stride 2: Q (S GEMM input) -> attended (output)
//     F64      @32..175 [16][64] f16, stride 9: raw q|k staging, S rows (P E4 aliases words 0..3 of each row,
//                        the PV epilogue stages its tiles in words 4..7)
//     F32      @32..111 [16][32] f16, stride 5
//     HID      @32..111 [16][64] E4, stride 5
// and requires GL_EXT_float_e4m3, the cooperative matrix, subgroup shuffle and
// control-flow-attribute extensions plus common.glsl with DLSS_E4M3_HW.

const uint PRIV = 176u, F64 = 32u, F32 = 32u, HID = 32u;

#define ACC coopmat<float16_t, gl_ScopeSubgroup, 16, 16, gl_MatrixUseAccumulator>
#define MAT_A coopmat<floate4m3_t, gl_ScopeSubgroup, 16, 32, gl_MatrixUseA>
#define MAT_B coopmat<floate4m3_t, gl_ScopeSubgroup, 32, 16, gl_MatrixUseB>

uint tiledToken(uint token) {  // natural -> physical
  uint x = token & 7u, y = token >> 3u;
  return (y >> 2u) * 32u + (x >> 2u) * 16u + (y & 3u) * 4u + (x & 3u);
}

void subgroupSync() { subgroupMemoryBarrierShared(); subgroupBarrier(); }

// the exponential approximation on a packed pair: f32 affine, half clamp, then per half
// (bits << 5) + 0x8000 masked to 16 bits, which is (bits << 5) ^ 0x8000.
uint expWeightPair(uint scoreBits) {
  precise vec2 affine32 = fma(vec2(unpackFloat2x16(scoreBits)), vec2(0.044921875), vec2(1.30078125));
  f16vec2 affine = clamp(f16vec2(affine32), f16vec2(1.03125), f16vec2(1.5693359375));
  return ((packFloat2x16(affine) << 5u) & 0xffe0ffe0u) ^ 0x80008000u;
}

// Four E4M3 codes from two half pairs, little-endian.
uint e4x4(f16vec2 a, f16vec2 b) { return uint(e4m3HwPair(a)) | (uint(e4m3HwPair(b)) << 16u); }
uint e4x4Bits(uint a, uint b) { return e4x4(unpackFloat2x16(a), unpackFloat2x16(b)); }

// 16 halves (two words) -> 16 E4M3 codes (one word).
uvec4 quantize16(uvec4 w0, uvec4 w1) {
  return uvec4(e4x4Bits(w0.x, w0.y), e4x4Bits(w0.z, w0.w), e4x4Bits(w1.x, w1.y), e4x4Bits(w1.z, w1.w));
}

// 16 halves -> SiLU -> 16 E4M3 codes.
uvec4 hidden16(uvec4 w0, uvec4 w1) {
  return uvec4(e4x4(siluPair(unpackFloat2x16(w0.x)), siluPair(unpackFloat2x16(w0.y))),
               e4x4(siluPair(unpackFloat2x16(w0.z)), siluPair(unpackFloat2x16(w0.w))),
               e4x4(siluPair(unpackFloat2x16(w1.x)), siluPair(unpackFloat2x16(w1.y))),
               e4x4(siluPair(unpackFloat2x16(w1.z)), siluPair(unpackFloat2x16(w1.w))));
}

// round_f16(residual * scale) for eight residual/scale pairs (exact products in f32, one rounding).
uvec4 scaledResidual8(uvec4 residual, uvec4 scale) {
  uvec4 r;
  [[unroll]] for (uint i = 0u; i < 4u; ++i) {
    vec2 product = vec2(unpackFloat2x16(residual[i])) * vec2(unpackFloat2x16(scale[i]));
    r[i] = packFloat2x16(f16vec2(product));
  }
  return r;
}

// Same for eight E4M3 residual codes packed in two words.
uvec4 scaledResidualE4x8(uvec2 codes, uvec4 scale) {
  uvec4 r;
  [[unroll]] for (uint i = 0u; i < 4u; ++i) {
    uint pair = (codes[i >> 1u] >> ((i & 1u) * 16u)) & 0xffffu;
    vec2 product = vec2(e4m3HwToF32(pair & 0xffu), e4m3HwToF32(pair >> 8u)) * vec2(unpackFloat2x16(scale[i]));
    r[i] = packFloat2x16(f16vec2(product));
  }
  return r;
}

// Cosine normalization of one 32-channel vector held as 16 packed pairs:
// r[c] = fma(v[c], v[c], f16(v[c+16]^2)) for c < 16, tree stride 8/4/2/1, each
// level published as half exactly like the reference reduction array.
float16_t inverseNorm(uvec4 w0, uvec4 w1, uvec4 w2, uvec4 w3) {
  f16vec2 p[16];
  [[unroll]] for (uint i = 0u; i < 4u; ++i) {
    p[i] = unpackFloat2x16(w0[i]); p[4u + i] = unpackFloat2x16(w1[i]);
    p[8u + i] = unpackFloat2x16(w2[i]); p[12u + i] = unpackFloat2x16(w3[i]);
  }
  f16vec2 r[8];
  [[unroll]] for (uint m = 0u; m < 8u; ++m) {
    precise f16vec2 highSquare = p[m + 8u] * p[m + 8u];
    precise f16vec2 rm = fma(p[m], p[m], highSquare);
    r[m] = rm;
  }
  f16vec2 s8[4];
  [[unroll]] for (uint m = 0u; m < 4u; ++m) { precise f16vec2 s = r[m] + r[m + 4u]; s8[m] = s; }
  precise f16vec2 s4a = s8[0] + s8[2];
  precise f16vec2 s4b = s8[1] + s8[3];
  precise f16vec2 s2 = s4a + s4b;
  precise float16_t s1 = s2.x + s2.y;
  return float16_t(inversesqrt(float(s1)));
}

// 32 halves (four words) times a half (and optionally a second half), E4M3 codes of the products (two words).
void scaleQuantize32(uvec4 w0, uvec4 w1, uvec4 w2, uvec4 w3, float16_t norm, float16_t extra, bool applyExtra,
                     out uvec4 e0, out uvec4 e1) {
  uvec4 words[4] = uvec4[4](w0, w1, w2, w3);
  uint codes[8];
  [[unroll]] for (uint i = 0u; i < 8u; ++i) {
    f16vec2 a = unpackFloat2x16(words[i >> 1u][(i & 1u) * 2u]), b = unpackFloat2x16(words[i >> 1u][(i & 1u) * 2u + 1u]);
    precise f16vec2 na = a * norm;
    precise f16vec2 nb = b * norm;
    if (applyExtra) {
      precise f16vec2 sa = na * extra;
      precise f16vec2 sb = nb * extra;
      na = sa; nb = sb;
    }
    codes[i] = e4x4(na, nb);
  }
  e0 = uvec4(codes[0], codes[1], codes[2], codes[3]);
  e1 = uvec4(codes[4], codes[5], codes[6], codes[7]);
}

// Attention for one subgroup's 16 query rows: Q (E4 rows at `base`) against the
// window's Kp/Vp, prior tile row block at `priorOffset` (halves). S = QK^T + prior
// -> the specified softmax (exponential on read, half reciprocal, E4 weights) -> O = PV
// -> attended E4 [16][32] written back into the E4 rows.
void windowAttend(uint base, uint rowBase, uint KP, uint VP, uint priorOffset) {
  const uint lane = gl_SubgroupInvocationID;
  const uint lr = lane >> 1u, lh = lane & 1u;
  const uint sBase = base + F64;   // S rows [16][64] f16, 9 words per row
  MAT_A mq; coopMatLoad(mq, priv4, base, 2u, gl_CooperativeMatrixLayoutRowMajor);
  ACC priors[4];
  [[unroll]] for (uint kTile = 0u; kTile < 4u; ++kTile)
    coopMatLoad(priors[kTile], prior, priorOffset + kTile * 16u, 64u, gl_CooperativeMatrixLayoutRowMajor);
  [[unroll]] for (uint kTile = 0u; kTile < 4u; ++kTile) {
    MAT_B mb; coopMatLoad(mb, kv4, KP + kTile * 32u, 2u, gl_CooperativeMatrixLayoutColumnMajor);
    ACC mc = coopMatMulAdd(mq, mb, priors[kTile]);
    coopMatStore(mc, priv4, sBase + kTile * 2u, 9u, gl_CooperativeMatrixLayoutRowMajor);
  }
  subgroupSync();
  // Softmax: one lane pair per S row (lane = row*2 + hh, hh selects keys 0..31 or 32..63).
  // the specified softmax reduction: b[g][j] = e[g+16j] + e[g+16j+8]; t[g] = ((b0+b1)+b2)+b3;
  // total = (((t0+t2)+t4)+t6) + (((t1+t3)+t5)+t7). The exponentials stay in registers for the weights.
  {
    uint row = lr, hh = lh;
    uint src = sBase + row * 9u + hh * 4u;
    uvec4 s0 = priv4[src], s1 = priv4[src + 1u], s2 = priv4[src + 2u], s3 = priv4[src + 3u];
    uint e[16];   // packed exp weights of keys hh*32 + 2i, 2i+1
    [[unroll]] for (uint i = 0u; i < 4u; ++i) {
      e[i] = expWeightPair(s0[i]); e[4u + i] = expWeightPair(s1[i]);
      e[8u + i] = expWeightPair(s2[i]); e[12u + i] = expWeightPair(s3[i]);
    }
    // Own b values: this half holds j = 2*hh, 2*hh+1 for every g (local key = g + 16*(j & 1));
    // b[g][j] for g = 2m, 2m+1 live in one packed word.
    uint bOwn[8];   // [jLocal * 4 + m]
    [[unroll]] for (uint jl = 0u; jl < 2u; ++jl) {
      [[unroll]] for (uint m = 0u; m < 4u; ++m) {
        precise f16vec2 b = unpackFloat2x16(e[8u * jl + m]) + unpackFloat2x16(e[8u * jl + 4u + m]);
        bOwn[jl * 4u + m] = packFloat2x16(b);
      }
    }
    uint bOther[8];
    [[unroll]] for (uint i = 0u; i < 8u; ++i) bOther[i] = subgroupShuffleXor(bOwn[i], 1u);
    f16vec2 t[4];
    [[unroll]] for (uint m = 0u; m < 4u; ++m) {
      f16vec2 b0 = unpackFloat2x16(hh == 0u ? bOwn[m] : bOther[m]);
      f16vec2 b1 = unpackFloat2x16(hh == 0u ? bOwn[4u + m] : bOther[4u + m]);
      f16vec2 b2 = unpackFloat2x16(hh == 0u ? bOther[m] : bOwn[m]);
      f16vec2 b3 = unpackFloat2x16(hh == 0u ? bOther[4u + m] : bOwn[4u + m]);
      precise f16vec2 t01 = b0 + b1;
      precise f16vec2 t012 = t01 + b2;
      precise f16vec2 tm = t012 + b3;
      t[m] = tm;   // (t[2m], t[2m+1])
    }
    precise float16_t e01 = t[0].x + t[1].x;
    precise float16_t e012 = e01 + t[2].x;
    precise float16_t even = e012 + t[3].x;
    precise float16_t o01 = t[0].y + t[1].y;
    precise float16_t o012 = o01 + t[2].y;
    precise float16_t odd = o012 + t[3].y;
    precise float16_t total = even + odd;
    float16_t reciprocal = float16_t(1.0 / float(total));
    uint codes[8];
    [[unroll]] for (uint i = 0u; i < 8u; ++i) {
      precise f16vec2 wa = unpackFloat2x16(e[2u * i]) * reciprocal;
      precise f16vec2 wb = unpackFloat2x16(e[2u * i + 1u]) * reciprocal;
      codes[i] = e4x4(wa, wb);
    }
    subgroupSync();   // every lane has read its S words before P overwrites words 0..3 of the rows
    priv4[sBase + row * 9u + hh * 2u] = uvec4(codes[0], codes[1], codes[2], codes[3]);
    priv4[sBase + row * 9u + hh * 2u + 1u] = uvec4(codes[4], codes[5], codes[6], codes[7]);
  }
  subgroupSync();
  // O = P V over the 64 physical keys as two k32 steps; both 16x16 tiles staged in words 4..7 of the S rows.
  ACC mo[2];
  [[unroll]] for (uint cTile = 0u; cTile < 2u; ++cTile) {
    mo[cTile] = ACC(0.0);
    [[unroll]] for (uint kb = 0u; kb < 64u; kb += 32u) {
      MAT_A mp; coopMatLoad(mp, priv4, sBase + (kb >> 4u), 9u, gl_CooperativeMatrixLayoutRowMajor);
      MAT_B mv; coopMatLoad(mv, kv4, VP + kb * 2u + cTile, 2u, gl_CooperativeMatrixLayoutRowMajor);
      mo[cTile] = coopMatMulAdd(mp, mv, mo[cTile]);
    }
  }
  [[unroll]] for (uint cTile = 0u; cTile < 2u; ++cTile)
    coopMatStore(mo[cTile], priv4, sBase + 4u + cTile * 2u, 9u, gl_CooperativeMatrixLayoutRowMajor);
  subgroupSync();
  {
    uint src = sBase + lr * 9u + 4u + lh * 2u;
    priv4[base + lr * 2u + lh] = quantize16(priv4[src], priv4[src + 1u]);   // attended E4 [16][32]
  }
  subgroupSync();
}
