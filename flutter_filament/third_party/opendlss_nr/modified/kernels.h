// Compute kernel wrappers: pipeline specialization cache plus dispatch helpers with the exact operand contracts
// of the network (GLSL cooperative-matrix reference kernels).
//
// Modified by Lumina from OpenDLSS-NR 9d08f41 src/kernels.h (MIT, see ../LICENSE): the PTX kernels
// (VK_NV_cuda_kernel_launch), barrier-free counter chaining, split-K tile counters, the SiLU table upload and the
// per-dispatch profiler are removed; only the GLSL route remains. The operand contracts are unchanged.
#pragma once
#include <map>
#include <string>
#include <vector>

#include "nr_model.h"
#include "vk_context.h"

namespace nr {

enum class Format { E4, F16, F32 };

inline uint32_t formatBytes(Format format) { return format == Format::E4 ? 1 : format == Format::F16 ? 2 : 4; }
inline uint32_t alignRows(uint32_t rows) { return (rows + 63) & ~63u; }

// A [rows][channels] activation tensor. Rows are allocated padded to 64 so
// cooperative-matrix A loads never leave the buffer.
struct Activation {
  vk::Buffer buffer;
  Format format = Format::E4;
  uint32_t rows = 0;
  uint32_t channels = 0;
  uint32_t allocRows = 0;
  std::string label;
  VkDeviceSize validBytes() const { return (VkDeviceSize)rows * channels * formatBytes(format); }
};

struct GemmFp8Args {
  const Activation* input = nullptr;
  uint32_t inputColumnBase = 0;   // added for every batch
  const vk::Buffer* weights = nullptr;  // plain [batches*K][Nmatrix] E4M3
  uint32_t Nmatrix = 0;
  uint32_t weightColumnOffset = 0;
  Activation* output = nullptr;   // F16 unless quantize (E4)
  uint32_t outputColumnOffset = 0;
  Activation* dualOutput = nullptr;  // E4 copy of the published value
  const Activation* residual = nullptr;
  bool scaleResidual = false;
  const Tensor* auxTensor = nullptr;
  uint32_t auxByteOffset = 0;
  bool silu = false;
  bool quantize = true;
  uint32_t rows = 0, K = 0, N = 0;
  uint32_t batches = 1;
  bool broadcastInput = false;
  uint32_t partition = 0;  // 0 or 256/512/1024 (split-K modes)
};

struct GemmF16Args {
  const Activation* input = nullptr;  // F16
  const vk::Buffer* weights = nullptr;  // plain [K][paddedN] f16
  uint32_t paddedN = 0;
  Activation* output = nullptr;       // F16 / E4 / F32 by format
  Activation* dualOutput = nullptr;   // E4
  uint32_t rows = 0, K = 0, N = 0;
};

class Kernels {
 public:
  explicit Kernels(vk::Context& context);
  ~Kernels();

  void gemmFp8(VkCommandBuffer commands, const GemmFp8Args& args);
  void gemmF16(VkCommandBuffer commands, const GemmF16Args& args);

  void convertF32ToF16(VkCommandBuffer commands, const Activation& input, Activation& output);
  void quantize(VkCommandBuffer commands, const Activation& input, Activation& output);
  void downsample2x(VkCommandBuffer commands, const Activation& input, Activation& output, uint32_t inWidth,
                    uint32_t inHeight, uint32_t outWidth, uint32_t outHeight);
  // learned_post_blend: raw f16 and E4 copies of up*inputScale + adapter*skipScale.
  void postBlend(VkCommandBuffer commands, const Activation& upsampleSource, const Activation& adapter,
                 const Tensor& tensor, uint32_t inputScaleByteOffset, uint32_t skipScaleByteOffset,
                 Activation& rawOutput, Activation& quantizedOutput, uint32_t inWidth, uint32_t inHeight,
                 uint32_t outWidth, uint32_t outHeight);
  // Decoder transition: E4 (and optionally raw f16) of round_f16(projection[low] + skip * scale).
  void upsampleResidual(VkCommandBuffer commands, const Activation& projection, const Activation& skip,
                        const Tensor& tensor, uint32_t scaleByteOffset, Activation& output, Activation* rawOutput,
                        uint32_t inWidth, uint32_t inHeight, uint32_t outWidth, uint32_t outHeight);

  // Fused 32-channel Swin block: one dispatch per block (see fused_block32.comp).
  struct FusedBlock32Args {
    // Pre / post fusion (block 0 / block 70): the input adapter, the post blend and the RGBA head in the block.
    const Activation* features = nullptr;   // F_PRE: f32 [tokens][16] input features (replaces state / skip16)
    const vk::Buffer* adapterWeights = nullptr;   // F_PRE: f16 [16][32] (f16Matrix layout 1)
    const Activation* lowRes = nullptr;     // F_POST: half-resolution E4 block output (state = block-0 output)
    const Activation* lowProjection = nullptr;   // F_UPRES: half-resolution f16 projection (state = E4 skip, scaled by inputScale)
    uint32_t inputScaleByteOffset = 0, adapterScaleByteOffset = 0, lowWidth = 0;   // F_POST
    const vk::Buffer* headWeights = nullptr;   // F_HEAD: f16 [32][16] (f16Matrix layout 2, padded)
    Activation* head = nullptr;             // F_HEAD: f32 [tokens][4] output (replaces outF16)
    Activation* pooled = nullptr;           // F_POOL: E4 half-resolution 2x2 box pool of the raw output (replaces outF16)
    uint32_t pooledWidth = 0;
    const Activation* state = nullptr;      // E4 [tokens][32]
    const Activation* skip16 = nullptr;     // optional f16 FFN skip (else the state)
    const vk::Buffer* w1 = nullptr;         // [32][128]
    const vk::Buffer* w2 = nullptr;         // [128][32]
    const vk::Buffer* wqkv = nullptr;       // [32][96]
    const vk::Buffer* wproj = nullptr;      // [32][32]
    const vk::Buffer* prior = nullptr;      // [64][64] f16
    const Tensor* tensor = nullptr;
    uint32_t ffnScaleByteOffset = 0, attnScaleByteOffset = 0, attentionScaleByteOffset = 0;
    Activation* outE4 = nullptr;
    Activation* outF16 = nullptr;
    uint32_t width = 0, height = 0, shiftX = 0, shiftY = 0;
  };
  void fusedBlock32(VkCommandBuffer commands, const FusedBlock32Args& args);

  // Split-K partial sums (one fixed scratch: dispatches already recorded hold it).
  vk::Buffer splitScratch_{};
  VkDeviceSize splitScratchBytes_ = 0;

  // Fused two-layer MLP (gemm_mlp.comp): E4(E4(SiLU(A W1)) W2) per batch, hidden on chip.
  struct MlpArgs {
    const Activation* input = nullptr;
    uint32_t inputColumnBase = 0;
    bool broadcastInput = false;
    const vk::Buffer* w1 = nullptr;        // tile-major [batch][K/32][hidden][32]
    const vk::Buffer* w2 = nullptr;        // N-major [batch][nout][hidden] (fp8Matrix tileMajor = false)
    Activation* output = nullptr;          // E4, columns outputColumnOffset + batch * nout
    uint32_t outputColumnOffset = 0;
    uint32_t rows = 0, K = 0, hidden = 0, nout = 0, batches = 1;
  };
  void gemmMlp(VkCommandBuffer commands, const MlpArgs& args);

  // Fused QKV projection + normalize + attention (qkv_attention.comp): E4 input in, E4 attended out.
  void qkvAttention(VkCommandBuffer commands, const Activation& input, const vk::Buffer& weights, uint32_t Nmatrix,
                    const Tensor& tensor, uint32_t scaleByteOffset, const vk::Buffer& prior, Activation& attended,
                    uint32_t width, uint32_t height, uint32_t heads, uint32_t shiftX, uint32_t shiftY);
  void windowNormalize(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor,
                       uint32_t scaleByteOffset, Activation& normalized, uint32_t tokens, uint32_t heads);
  void windowAttend(VkCommandBuffer commands, const Activation& normalized, const vk::Buffer& prior,
                    Activation& attended, uint32_t width, uint32_t height, uint32_t heads, uint32_t shiftX,
                    uint32_t shiftY);
  // Fused ViT normalize + global attention (global_attention.comp): raw half QKV in, E4 attended out.
  void globalAttention(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor, uint32_t scaleByteOffset,
                       Activation& attended, uint32_t tokens, uint32_t paddedTokens, uint32_t heads,
                       const Activation* normalized = nullptr);   // normalized: E4 q/k/v from globalNormalize (large token counts)
  void globalNormalize(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor,
                       uint32_t scaleByteOffset, Activation& normalized, uint32_t tokens, uint32_t heads);
  void globalAttend(VkCommandBuffer commands, const Activation& normalized, Activation& attended, uint32_t tokens,
                    uint32_t paddedTokens, uint32_t heads);

  uint32_t dispatchCount() const { return dispatches_; }
  void resetDispatchCount() { dispatches_ = 0; }

 private:
  // requiredSubgroupSize 0: no subgroup requirement (kernels without subgroup operations and a workgroup that is not a
  // multiple of 32)
  VkPipeline pipeline(const char* shader, const vk::SpecConstants& constants, uint32_t requiredSubgroupSize = 32);
  void dispatch(VkCommandBuffer commands, VkPipeline pipeline, const vk::Buffer* const bindings[vk::kGenericBindings],
                const void* push, uint32_t pushBytes, uint32_t x, uint32_t y, uint32_t z);
  void dispatchLinear(VkCommandBuffer commands, VkPipeline pipeline,
                      const vk::Buffer* const bindings[vk::kGenericBindings], const void* push, uint32_t pushBytes,
                      uint32_t count);
  vk::Context& context_;
  std::map<std::string, vk::Pipeline> pipelines_;
  uint32_t dispatches_ = 0;
};

}  // namespace nr
