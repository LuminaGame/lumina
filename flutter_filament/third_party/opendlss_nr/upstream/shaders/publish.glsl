// Accumulator publication helpers (fragment level). The coopmat2 tensor stores and the plain
// coopMatStore of 8-bit accumulators to global memory compile to scattered narrow stores that
// cost ~8000 SM cycles per 16x32 tile (measured in gemm_mlp); these macros assemble the row tile in
// shared memory as 32-bit words and store whole 16-byte words.
//
// Accumulator layout (verified on Ada): lane (g = l>>2, t = l&3) holds rows g and
// g+8; element j of a row half is column 8*(j>>1) + 2t + (j&1). Requires GL_KHR_shader_subgroup_shuffle.
#ifndef DLSS_PUBLISH_GLSL
#define DLSS_PUBLISH_GLSL

// E4 codes of a NaN-free pair: the saturating hardware conversion (= common.glsl e4m3HwPair without the NaN
// guard, for accumulators whose NaNs the caller has already removed).
uint16_t e4m3PairFast(f16vec2 value) {
  fe4m3vec2 converted;
  saturatedConvertEXT(converted, value);
  u8vec2 codes = floate4m3BitsToUintEXT(converted);
  return uint16_t(uint(codes.x) | (uint(codes.y) << 8u));
}

// 16 x N f16 accumulator `acc` -> E4 row tile of N/4 32-bit words per row in `words32` at `base`
// (NaN -> 0). Lanes t, t^1 exchange one pair per column group so the even lane assembles the word of
// row g and the odd lane that of row g+8. Follow with subgroupBarrier() before reading the tile.
#define PUBLISH_E4_TILE(acc, N, words32, base, g, t)                                                   \
  {                                                                                                    \
    [[unroll]] for (uint j = 0u; j < (N) / 8u; ++j) {                                                  \
      f16vec2 v0 = f16vec2(acc[2u * j], acc[2u * j + 1u]);                                             \
      f16vec2 v1 = f16vec2(acc[(N) / 4u + 2u * j], acc[(N) / 4u + 2u * j + 1u]);                       \
      uint c0 = uint(e4m3PairFast(mix(v0, f16vec2(0.0), isnan(v0))));                                  \
      uint c1 = uint(e4m3PairFast(mix(v1, f16vec2(0.0), isnan(v1))));                                  \
      bool odd = ((t) & 1u) != 0u;                                                                     \
      uint recv = subgroupShuffleXor(odd ? c0 : c1, 1u);                                               \
      uint word = odd ? (recv | (c1 << 16u)) : (c0 | (recv << 16u));                                   \
      uint row = odd ? (g) + 8u : (g);                                                                 \
      words32[(base) + row * ((N) / 4u) + 2u * j + ((t) >> 1u)] = word;                                \
    }                                                                                                  \
  }

// 16 x N f16 accumulator -> f16 row tile of N/2 32-bit words per row (pairs are already words).
#define PUBLISH_F16_TILE(acc, N, words32, base, g, t)                                                  \
  {                                                                                                    \
    [[unroll]] for (uint h = 0u; h < 2u; ++h) {                                                        \
      [[unroll]] for (uint j = 0u; j < (N) / 8u; ++j) {                                                \
        words32[(base) + ((g) + 8u * h) * ((N) / 2u) + 4u * j + (t)] =                                 \
            packFloat2x16(f16vec2(acc[(N) / 4u * h + 2u * j], acc[(N) / 4u * h + 2u * j + 1u]));       \
      }                                                                                                \
    }                                                                                                  \
  }

#endif
