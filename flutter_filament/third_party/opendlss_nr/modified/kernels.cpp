// Modified by Lumina from OpenDLSS-NR 9d08f41 src/kernels.cpp (MIT, see ../LICENSE): GLSL route only. Removed: the
// PTX routes (gemm2 / gemmt / gemmv / reduce / block32 / mlp / ffn / qkv / global attention PTX), the
// VK_NV_cuda_kernel_launch launches, counter chaining and its watchdog, the split-K tile counters, the SiLU table
// and the profiler. Shader modules come from the embedded SPIR-V (vk::Context::shaderModule) instead of .spv files.
// Every GLSL dispatch, its specialization constants, push constants and bindings are unchanged.
#include "kernels.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>

namespace nr {

namespace {
constexpr uint32_t F_RESIDUAL = 1, F_SCALE_RESIDUAL = 2, F_SILU = 8, F_QUANTIZE = 16,
                   F_DUAL = 32, F_RESIDUAL_E4 = 64, F_BROADCAST_INPUT = 128, F_OUT_F32 = 256;

// Workgroup shape for the GLSL FP8 GEMM: BM = 16 * subgroups rows, BN = 16 * tiles columns. Take the widest
// column tile that still fills the GPU; below that, the shape that comes closest. Wider tiles beat more
// workgroups (they amortize the staged K64 steps), so "fills" is one and a half workgroups per SM, measured.
// The shape changes no arithmetic: every output element sums its K in the same order whatever the tiling.
void chooseGemmShape(uint32_t N, uint32_t rows, uint32_t batches, uint32_t smCount, uint32_t& subgroups, uint32_t& tiles) {
  if (N % 16) throw std::runtime_error("GEMM N must be a multiple of 16: " + std::to_string(N));
  constexpr uint32_t maxTiles = 8u, maxSubgroups = 4u;
  const uint32_t minGroups = smCount * 3 / 2;
  uint32_t bestGroups = 0;
  subgroups = 4; tiles = 1;
  for (uint32_t sg : {8u, 4u}) {
    if (sg > maxSubgroups) continue;
    uint32_t rowGroups = (rows + 16 * sg - 1) / (16 * sg);
    for (uint32_t t : {8u, 6u, 4u, 3u, 2u, 1u}) {
      if (t > maxTiles || N % (t * 16) != 0) continue;
      uint32_t workgroups = batches * (N / (t * 16)) * rowGroups;
      if (workgroups >= minGroups) { subgroups = sg; tiles = t; return; }
      if (workgroups > bestGroups) { bestGroups = workgroups; subgroups = sg; tiles = t; }
    }
  }
}

void check(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
}  // namespace

Kernels::Kernels(vk::Context& context) : context_(context) {}

Kernels::~Kernels() {
  for (auto& [key, pipeline] : pipelines_) context_.destroyPipeline(pipeline);
  context_.destroyBuffer(splitScratch_);
}

VkPipeline Kernels::pipeline(const char* shader, const vk::SpecConstants& constants, uint32_t requiredSubgroupSize) {
  std::string key = shader;
  for (uint32_t value : constants.data) key += ":" + std::to_string(value);
  auto it = pipelines_.find(key);
  if (it != pipelines_.end()) return it->second.pipeline;
  vk::Pipeline created = context_.createComputePipeline(context_.shaderModule(shader), constants, shader, requiredSubgroupSize);
  pipelines_[key] = created;
  return created.pipeline;
}

void Kernels::dispatch(VkCommandBuffer commands, VkPipeline pipeline,
                       const vk::Buffer* const bindings[vk::kGenericBindings], const void* push, uint32_t pushBytes,
                       uint32_t x, uint32_t y, uint32_t z) {
  VkDescriptorSet set = context_.allocateSet(bindings);
  vkCmdBindPipeline(commands, VK_PIPELINE_BIND_POINT_COMPUTE, pipeline);
  vkCmdBindDescriptorSets(commands, VK_PIPELINE_BIND_POINT_COMPUTE, context_.pipelineLayout(), 0, 1, &set, 0, nullptr);
  vkCmdPushConstants(commands, context_.pipelineLayout(), VK_SHADER_STAGE_COMPUTE_BIT, 0, pushBytes, push);
  vkCmdDispatch(commands, x, y, z);
  context_.computeBarrier(commands);
  ++dispatches_;
}

void Kernels::dispatchLinear(VkCommandBuffer commands, VkPipeline pipeline,
                             const vk::Buffer* const bindings[vk::kGenericBindings], const void* push,
                             uint32_t pushBytes, uint32_t count) {
  uint32_t groups = (count + 255) / 256;
  uint32_t y = (groups + 65534) / 65535;
  dispatch(commands, pipeline, bindings, push, pushBytes, std::min(groups, 65535u), y, 1);
}

void Kernels::gemmFp8(VkCommandBuffer commands, const GemmFp8Args& a) {
  check(a.input && a.input->format == Format::E4, "FP8 GEMM input must be E4M3");
  check(a.K % 32 == 0, "FP8 GEMM K must be a multiple of 32");
  check(a.output, "FP8 GEMM needs an output");
  check(a.output->format == (a.quantize ? Format::E4 : Format::F16), "FP8 GEMM output format mismatch");
  check(!a.dualOutput || (a.dualOutput->format == Format::E4 && !a.quantize), "dual output must be E4 beside f16");
  check(a.output->allocRows >= alignRows(a.rows), "GEMM output rows");
  check(a.input->allocRows >= alignRows(a.rows), "GEMM input rows");
  check(a.inputColumnBase + (a.broadcastInput ? a.K : a.batches * a.K) <= a.input->channels, "GEMM input columns");
  check(a.outputColumnOffset + a.batches * a.N <= a.output->channels, "GEMM output columns");
  check(a.weightColumnOffset + a.N <= a.Nmatrix, "GEMM weight columns");
  check(!a.residual || a.residual->channels == a.output->channels, "residual must share the output layout");
  check(a.partition == 0 || (a.partition % 32 == 0 && a.K % a.partition == 0), "GEMM partition");
  check(a.input->channels % 16 == 0 && a.inputColumnBase % 16 == 0, "GEMM input rows must be 16-byte aligned");
  check(!a.residual || a.residual->allocRows >= alignRows(a.rows), "GEMM residual rows");
  // Split-K: independent partition chains in separate workgroups plus a reduce pass, for the
  // small-M partitioned GEMMs (ViT) whose workgroup count would otherwise starve the GPU.
  uint32_t splits = 1;
  if (a.partition && a.K > a.partition && a.batches == 1 &&
      ((a.rows + 63) / 64) * std::max(1u, a.N / 64) < 2 * context_.smCount() &&
      (VkDeviceSize)(a.K / a.partition) * alignRows(a.rows) * a.N * 2 <= (16u << 20))
    splits = a.K / a.partition;
  uint32_t subgroups = 4, tiles = 1;
  chooseGemmShape(a.N, a.rows, a.batches * splits, context_.smCount(), subgroups, tiles);
  uint32_t tile = tiles * 16, blockRows = subgroups * 16;
  uint32_t flags = 0;
  if (a.residual) flags |= F_RESIDUAL;
  if (a.scaleResidual) flags |= F_SCALE_RESIDUAL;
  if (a.silu) flags |= F_SILU;
  if (a.quantize) flags |= F_QUANTIZE;
  if (a.dualOutput) flags |= F_DUAL;
  if (a.residual && a.residual->format == Format::E4) flags |= F_RESIDUAL_E4;
  if (a.broadcastInput) flags |= F_BROADCAST_INPUT;
  check(!a.scaleResidual || a.auxTensor, "scaled residual needs an aux tensor");
  check(a.output->channels % 16 == 0 && (a.outputColumnOffset % 16) == 0 && (a.auxByteOffset % 16) == 0 && a.N % 16 == 0,
        "GEMM epilogue needs 16-column aligned outputs");
  const uint32_t publishFlags = flags & (F_SILU | F_QUANTIZE | F_DUAL);
  if (splits > 1) flags &= ~publishFlags;   // publication moves to the reduce pass
  vk::SpecConstants constants;
  constants.add(0, a.K);
  constants.add(1, tiles);
  constants.add(2, flags);
  constants.add(3, splits > 1 ? 0u : a.partition);
  constexpr uint32_t depthEnv = 4u;   // k32 steps in flight
  constants.add(4, std::max(1u, std::min(depthEnv, std::max(1u, a.K / 32))));
  constants.add(5, 1u);               // padded shared rows
  constants.add(7, subgroups);
  constants.add(8, subgroups * 32);
  constants.add(9, splits);
  // K per staged step: 64 (one flexible 16xNx64 multiply per barrier) when the partition allows it.
  const uint32_t partitionK = a.partition ? a.partition : a.K;
  const uint32_t kstep = partitionK % 64 == 0 ? 64u : 32u;
  constants.add(10, kstep);
  {  // prefetch depth in KSTEP units: the same bytes in flight as DEPTH k32 steps
    const uint32_t stepsTotal = std::max(1u, a.K / kstep / std::max(1u, splits));
    constants.data[4] = std::max(1u, std::min(depthEnv * 32 / kstep, stepsTotal));
  }
  const uint32_t splitStride = alignRows(a.rows) * a.N;   // f16 elements per partition slice
  struct Push {
    uint32_t rows, N, Nmatrix, weightColumnOffset, inputStride, inputColumnBase, outputStride, outputColumnOffset,
        auxHalfOffset, batches, columnGroups, splitStride;
  } push{a.rows, a.N, a.Nmatrix, a.weightColumnOffset, a.input->channels, a.inputColumnBase, a.output->channels,
         a.outputColumnOffset, a.auxByteOffset / 2, a.batches, a.N / tile, splitStride};
  if (splits > 1) {
    // One fixed scratch: it may not be reallocated while recorded dispatches still reference it.
    if (splitScratch_.buffer == VK_NULL_HANDLE) {
      splitScratchBytes_ = 16u << 20;
      splitScratch_ = context_.createBuffer(splitScratchBytes_, false, "split-K partials");
    }
    check((VkDeviceSize)splits * splitStride * 2 <= splitScratchBytes_, "split-K partials exceed the scratch buffer");
  }
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &a.input->buffer;
  bindings[1] = a.weights;
  if (!a.quantize) bindings[2] = &a.output->buffer;
  if (splits > 1) bindings[2] = &splitScratch_;
  if (a.residual && a.residual->format == Format::F16) bindings[3] = &a.residual->buffer;
  if (a.auxTensor) bindings[4] = &a.auxTensor->raw;
  if (a.quantize) bindings[5] = &a.output->buffer;
  if (a.dualOutput) bindings[5] = &a.dualOutput->buffer;
  if (a.residual && a.residual->format == Format::E4) bindings[6] = &a.residual->buffer;
  uint32_t rowGroups = (a.rows + blockRows - 1) / blockRows;
  uint32_t z = (rowGroups + 65534) / 65535;
  dispatch(commands, pipeline("gemm_fp8", constants), bindings, &push, sizeof(push), a.batches * (a.N / tile) * splits,
           std::min(rowGroups, 65535u), z);
  if (splits > 1) {
    vk::SpecConstants reduceConstants;
    reduceConstants.add(0, splits);
    reduceConstants.add(1, publishFlags);
    struct ReducePush { uint32_t rows, N, splitStride, outputStride, outputColumnOffset; }
        reducePush{a.rows, a.N, splitStride, a.output->channels, a.outputColumnOffset};
    const vk::Buffer* reduceBindings[vk::kGenericBindings] = {};
    reduceBindings[0] = &splitScratch_;
    if (!a.quantize) reduceBindings[2] = &a.output->buffer;
    if (a.quantize) reduceBindings[5] = &a.output->buffer;
    if (a.dualOutput) reduceBindings[5] = &a.dualOutput->buffer;
    dispatchLinear(commands, pipeline("gemm_reduce", reduceConstants), reduceBindings, &reducePush, sizeof(reducePush),
                   a.rows * a.N / 8);
  }
}

void Kernels::gemmF16(VkCommandBuffer commands, const GemmF16Args& a) {
  check(a.input && a.input->format == Format::F16, "f16 GEMM input must be f16");
  check(a.K % 16 == 0 && a.paddedN % 16 == 0 && a.N <= a.paddedN, "f16 GEMM shape");
  check(a.input->allocRows >= alignRows(a.rows) && a.output->allocRows >= alignRows(a.rows), "f16 GEMM rows");
  uint32_t flags = 0;
  if (a.output->format == Format::F32) flags |= F_OUT_F32;
  else if (a.output->format == Format::E4) flags |= F_QUANTIZE;
  if (a.dualOutput) flags |= F_DUAL;
  vk::SpecConstants constants;
  constants.add(0, a.K);
  constants.add(1, a.paddedN);
  constants.add(2, flags);
  struct Push { uint32_t rows, N, inputStride, outputStride; } push{a.rows, a.N, a.input->channels, a.output->channels};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &a.input->buffer;
  bindings[1] = a.weights;
  if (a.output->format == Format::F16) bindings[2] = &a.output->buffer;
  if (a.output->format == Format::E4) bindings[5] = &a.output->buffer;
  if (a.dualOutput) bindings[5] = &a.dualOutput->buffer;
  if (a.output->format == Format::F32) bindings[7] = &a.output->buffer;
  uint32_t rowGroups = (a.rows + 63) / 64;
  dispatch(commands, pipeline("gemm_f16", constants), bindings, &push, sizeof(push), 1, std::min(rowGroups, 65535u),
           (rowGroups + 65534) / 65535);
}

namespace {
struct OpsPush {
  uint32_t count, channels, inWidth, inHeight, outWidth, outHeight, auxOffsetA, auxOffsetB, dual;
};
}  // namespace

void Kernels::convertF32ToF16(VkCommandBuffer commands, const Activation& input, Activation& output) {
  check(input.format == Format::F32 && output.format == Format::F16, "convert formats");
  uint32_t count = input.rows * input.channels;
  vk::SpecConstants constants;
  constants.add(0, 0);
  OpsPush push{count, input.channels, 0, 0, 0, 0, 0, 0, 0};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &input.buffer;
  bindings[6] = &output.buffer;
  check(count % 8 == 0, "ops: element count must be a multiple of 8");
  dispatchLinear(commands, pipeline("ops", constants), bindings, &push, sizeof(push), count / 8);
}

void Kernels::quantize(VkCommandBuffer commands, const Activation& input, Activation& output) {
  check(input.format == Format::F16 && output.format == Format::E4, "quantize formats");
  uint32_t count = input.rows * input.channels;
  vk::SpecConstants constants;
  constants.add(0, 1);
  OpsPush push{count, input.channels, 0, 0, 0, 0, 0, 0, 0};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[1] = &input.buffer;
  bindings[5] = &output.buffer;
  check(count % 8 == 0, "ops: element count must be a multiple of 8");
  dispatchLinear(commands, pipeline("ops", constants), bindings, &push, sizeof(push), count / 8);
}

void Kernels::downsample2x(VkCommandBuffer commands, const Activation& input, Activation& output, uint32_t inWidth,
                           uint32_t inHeight, uint32_t outWidth, uint32_t outHeight) {
  check(input.format == Format::F16 && output.format == Format::E4, "downsample formats");
  check(input.rows == inWidth * inHeight && output.rows == outWidth * outHeight, "downsample geometry");
  uint32_t count = output.rows * output.channels;
  vk::SpecConstants constants;
  constants.add(0, 2);
  OpsPush push{count, output.channels, inWidth, inHeight, outWidth, outHeight, 0, 0, 0};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[1] = &input.buffer;
  bindings[5] = &output.buffer;
  check(count % 8 == 0, "ops: element count must be a multiple of 8");
  dispatchLinear(commands, pipeline("ops", constants), bindings, &push, sizeof(push), count / 8);
}

void Kernels::postBlend(VkCommandBuffer commands, const Activation& upsampleSource, const Activation& adapter,
                        const Tensor& tensor, uint32_t inputScaleByteOffset, uint32_t skipScaleByteOffset,
                        Activation& rawOutput, Activation& quantizedOutput, uint32_t inWidth, uint32_t inHeight,
                        uint32_t outWidth, uint32_t outHeight) {
  check(upsampleSource.format == Format::E4 && adapter.format == Format::E4, "post blend inputs");
  check(rawOutput.format == Format::F16 && quantizedOutput.format == Format::E4, "post blend outputs");
  uint32_t count = quantizedOutput.rows * quantizedOutput.channels;
  vk::SpecConstants constants;
  constants.add(0, 3);
  OpsPush push{count, quantizedOutput.channels, inWidth, inHeight, outWidth, outHeight, inputScaleByteOffset / 2,
               skipScaleByteOffset / 2, 1};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[2] = &upsampleSource.buffer;
  bindings[3] = &adapter.buffer;
  bindings[4] = &tensor.raw;
  bindings[5] = &quantizedOutput.buffer;
  bindings[6] = &rawOutput.buffer;
  check(count % 8 == 0, "ops: element count must be a multiple of 8");
  dispatchLinear(commands, pipeline("ops", constants), bindings, &push, sizeof(push), count / 8);
}

void Kernels::upsampleResidual(VkCommandBuffer commands, const Activation& projection, const Activation& skip,
                               const Tensor& tensor, uint32_t scaleByteOffset, Activation& output,
                               Activation* rawOutput, uint32_t inWidth, uint32_t inHeight, uint32_t outWidth,
                               uint32_t outHeight) {
  check(projection.format == Format::F16 && skip.format == Format::E4 && output.format == Format::E4,
        "upsample residual formats");
  check(!rawOutput || rawOutput->format == Format::F16, "upsample residual raw output");
  check(projection.rows == inWidth * inHeight && output.rows == outWidth * outHeight, "upsample residual geometry");
  uint32_t count = output.rows * output.channels;
  vk::SpecConstants constants;
  constants.add(0, 4);
  OpsPush push{count, output.channels, inWidth, inHeight, outWidth, outHeight, scaleByteOffset / 2, 0,
               rawOutput ? 1u : 0u};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[1] = &projection.buffer;
  bindings[3] = &skip.buffer;
  bindings[4] = &tensor.raw;
  bindings[5] = &output.buffer;
  if (rawOutput) bindings[6] = &rawOutput->buffer;
  check(count % 8 == 0, "ops: element count must be a multiple of 8");
  dispatchLinear(commands, pipeline("ops", constants), bindings, &push, sizeof(push), count / 8);
}

void Kernels::fusedBlock32(VkCommandBuffer commands, const FusedBlock32Args& a) {
  check(a.features || (a.state && a.state->format == Format::E4 && a.state->channels == 32), "fused block state");
  check(!a.skip16 || (a.skip16->format == Format::F16 && a.skip16->channels == 32), "fused block skip");
  check(a.outE4 || a.outF16 || a.head || a.pooled, "fused block needs an output");
  check(!a.pooled || (a.pooled->format == Format::E4 && a.pooled->channels == 32 && !a.outF16 && !a.head && a.pooledWidth), "fused pool output");
  check(!a.outE4 || (a.outE4->format == Format::E4 && a.outE4->channels == 32), "fused block E4 output");
  check(!a.outF16 || (a.outF16->format == Format::F16 && a.outF16->channels == 32), "fused block f16 output");
  check(a.ffnScaleByteOffset % 16 == 0 && a.attnScaleByteOffset % 16 == 0, "fused block scale vectors must be 16-byte aligned");
  uint32_t flags = (a.skip16 ? 1u : 0u) | (a.outE4 ? 2u : 0u) | (a.outF16 ? 4u : 0u) | (a.features ? 8u : 0u) |
                   (a.lowRes ? 16u : 0u) | (a.head ? 32u : 0u) | (a.pooled ? 64u : 0u) | (a.lowProjection ? 128u : 0u);
  vk::SpecConstants constants;
  constants.add(0, flags);
  uint32_t windowsX = (a.width + a.shiftX + 7) / 8, windowsY = (a.height + a.shiftY + 7) / 8;
  uint32_t windows = windowsX * windowsY;
  struct Push {
    uint32_t width, height, shiftX, shiftY, windowsX, windowCount, groupCount, auxFfnHalfOffset, auxAttnHalfOffset, scaleWordOffset,
        auxInputScaleHalf, auxAdapterScaleHalf, lowWidth;
  } push{a.width, a.height, a.shiftX, a.shiftY, windowsX, windows, 0u, a.ffnScaleByteOffset / 2, a.attnScaleByteOffset / 2,
         a.attentionScaleByteOffset / 4, a.inputScaleByteOffset / 2, a.adapterScaleByteOffset / 2,
         a.pooled ? a.pooledWidth : a.lowWidth};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  if (a.state) bindings[0] = &a.state->buffer;
  if (a.skip16) bindings[1] = &a.skip16->buffer;
  bindings[2] = a.w1;
  bindings[3] = a.w2;
  bindings[4] = a.wqkv;
  bindings[5] = a.wproj;
  bindings[6] = &a.tensor->raw;
  bindings[7] = a.prior;
  if (a.outE4) bindings[8] = &a.outE4->buffer;
  if (a.outF16) bindings[9] = &a.outF16->buffer;
  if (a.features) { check(a.features->format == Format::F32 && a.features->channels == 16 && a.adapterWeights, "fused pre inputs"); bindings[0] = &a.features->buffer; bindings[11] = a.adapterWeights; }
  if (a.lowRes) { check(a.lowRes->format == Format::E4 && a.state && a.state->format == Format::E4, "fused post inputs"); bindings[1] = &a.lowRes->buffer; }
  if (a.lowProjection) { check(a.lowProjection->format == Format::F16 && a.lowProjection->channels == 32 && a.state && !a.lowRes && !a.skip16, "fused upres inputs"); bindings[1] = &a.lowProjection->buffer; }
  if (a.head) { check(a.head->format == Format::F32 && a.head->channels == 4 && a.headWeights, "fused head"); bindings[9] = &a.head->buffer; bindings[11] = a.headWeights; }
  if (a.pooled) bindings[9] = &a.pooled->buffer;
  // Persistent: two resident workgroups per SM, each walking window pairs.
  uint32_t groups = std::min((windows + 1) / 2, 2 * context_.smCount());
  push.groupCount = groups;
  dispatch(commands, pipeline("fused_block32", constants), bindings, &push, sizeof(push), groups, 1, 1);
}

void Kernels::gemmMlp(VkCommandBuffer commands, const MlpArgs& a) {
  check(a.input && a.input->format == Format::E4, "MLP input must be E4M3");
  check(a.output && a.output->format == Format::E4, "MLP output must be E4M3");
  check(a.K % 32 == 0 && a.hidden % 128 == 0 && a.nout % 16 == 0 && a.nout <= 64, "MLP shape");
  check(a.input->channels % 16 == 0 && a.inputColumnBase % 16 == 0, "MLP input alignment");
  check(a.inputColumnBase + (a.broadcastInput ? a.K : a.batches * a.K) <= a.input->channels, "MLP input columns");
  check(a.outputColumnOffset % 16 == 0 && a.output->channels % 16 == 0 && a.nout % 16 == 0, "MLP output alignment");
  check(a.outputColumnOffset + a.batches * a.nout <= a.output->channels, "MLP output columns");
  check(a.output->allocRows >= alignRows(a.rows) && a.input->allocRows >= alignRows(a.rows), "MLP rows");
  vk::SpecConstants constants;
  constants.add(0, a.K);
  constants.add(1, a.hidden);
  constants.add(2, a.nout);
  constants.add(3, a.broadcastInput ? 1u : 0u);
  constexpr uint32_t mlpDepth = 2u;   // k32 steps in flight
  constants.add(5, std::max(1u, std::min(mlpDepth, a.K / 32)));
  struct Push { uint32_t rows, inputStride, inputColumnBase, outputStride, outputColumnOffset, batches; }
      push{a.rows, a.input->channels, a.inputColumnBase, a.output->channels, a.outputColumnOffset, a.batches};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &a.input->buffer;
  bindings[1] = a.w1;
  bindings[2] = a.w2;
  bindings[5] = &a.output->buffer;
  uint32_t rowGroups = (a.rows + 63) / 64;
  dispatch(commands, pipeline("gemm_mlp", constants), bindings, &push, sizeof(push), a.batches,
           std::min(rowGroups, 65535u), (rowGroups + 65534) / 65535);
}

void Kernels::qkvAttention(VkCommandBuffer commands, const Activation& input, const vk::Buffer& weights, uint32_t Nmatrix,
                           const Tensor& tensor, uint32_t scaleByteOffset, const vk::Buffer& prior, Activation& attended,
                           uint32_t width, uint32_t height, uint32_t heads, uint32_t shiftX, uint32_t shiftY) {
  check(input.format == Format::E4 && input.channels == heads * 32, "qkv attention input");
  check(Nmatrix == heads * 96, "qkv attention weight columns");
  check(attended.format == Format::E4 && attended.channels == heads * 32, "qkv attention output");
  check(scaleByteOffset % 4 == 0, "qkv attention scale offset");
  uint32_t windowsX = (width + shiftX + 7) / 8, windowsY = (height + shiftY + 7) / 8;
  uint32_t windows = windowsX * windowsY;
  struct Push { uint32_t width, height, channels, heads, shiftX, shiftY, windowsX, windowCount, scaleWordOffset, Nmatrix; }
      push{width, height, heads * 32, heads, shiftX, shiftY, windowsX, windows, scaleByteOffset / 4, Nmatrix};
  vk::SpecConstants constants;
  constants.add(0, heads * 32);
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &input.buffer;
  bindings[1] = &weights;
  bindings[2] = &prior;
  bindings[4] = &tensor.raw;
  bindings[5] = &attended.buffer;
  dispatch(commands, pipeline("qkv_attention", constants), bindings, &push, sizeof(push), heads,
           std::min(windows, 65535u), (windows + 65534) / 65535);
}

void Kernels::windowNormalize(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor,
                              uint32_t scaleByteOffset, Activation& normalized, uint32_t tokens, uint32_t heads) {
  check(qkv.format == Format::F16 && normalized.format == Format::E4, "normalize formats");
  check(qkv.channels == heads * 96 && normalized.channels == heads * 96, "normalize channels");
  struct Push { uint32_t tokens, heads, channels, scaleWordOffset; } push{tokens, heads, heads * 32, scaleByteOffset / 4};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[1] = &qkv.buffer;
  bindings[4] = &tensor.raw;
  bindings[5] = &normalized.buffer;
  dispatchLinear(commands, pipeline("window_normalize", {}), bindings, &push, sizeof(push), tokens * heads);
}

void Kernels::windowAttend(VkCommandBuffer commands, const Activation& normalized, const vk::Buffer& prior,
                           Activation& attended, uint32_t width, uint32_t height, uint32_t heads, uint32_t shiftX,
                           uint32_t shiftY) {
  check(normalized.format == Format::E4 && attended.format == Format::E4, "attend formats");
  check(attended.channels == heads * 32, "attend channels");
  uint32_t windowsX = (width + shiftX + 7) / 8;
  uint32_t windowsY = (height + shiftY + 7) / 8;
  uint32_t windows = windowsX * windowsY;
  struct Push { uint32_t width, height, channels, heads, shiftX, shiftY, windowsX, windowCount; }
      push{width, height, heads * 32, heads, shiftX, shiftY, windowsX, windows};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &normalized.buffer;
  bindings[1] = &prior;
  bindings[5] = &attended.buffer;
  dispatch(commands, pipeline("window_attend", {}), bindings, &push, sizeof(push), heads, std::min(windows, 65535u),
           (windows + 65534) / 65535);
}

void Kernels::globalAttention(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor, uint32_t scaleByteOffset,
                              Activation& attended, uint32_t tokens, uint32_t paddedTokens, uint32_t heads,
                              const Activation* normalized) {
  check(qkv.format == Format::F16 && qkv.channels == heads * 96 && attended.format == Format::E4 &&
            attended.channels == heads * 32, "global attention formats");
  check(paddedTokens % 64 == 0 && paddedTokens >= tokens && qkv.allocRows >= tokens, "global attention tokens");
  check(scaleByteOffset % 4 == 0, "global attention scale offset");
  // Keys are staged in chunks of 256 tokens (16 KB); beyond one chunk the q/k/v are normalized once by
  // global_normalize (an E4 [padded][heads*96] buffer) instead of once per query block.
  const bool prenormalized = normalized != nullptr;
  const uint32_t chunk = std::min(paddedTokens, 256u);
  check(!prenormalized || (normalized->format == Format::E4 && normalized->allocRows >= paddedTokens), "global attention normalized buffer");
  vk::SpecConstants constants;
  constants.add(0, paddedTokens);
  constants.add(1, chunk);
  constants.add(2, prenormalized ? 1u : 0u);
  struct Push { uint32_t tokens, heads, channels, scaleWordOffset; } push{tokens, heads, heads * 32, scaleByteOffset / 4};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = prenormalized ? &normalized->buffer : &qkv.buffer;
  bindings[4] = &tensor.raw;
  bindings[5] = &attended.buffer;
  dispatch(commands, pipeline("global_attention", constants), bindings, &push, sizeof(push), heads, paddedTokens / 64, 1);
}

void Kernels::globalNormalize(VkCommandBuffer commands, const Activation& qkv, const Tensor& tensor,
                              uint32_t scaleByteOffset, Activation& normalized, uint32_t tokens, uint32_t heads) {
  check(qkv.format == Format::F16 && normalized.format == Format::E4, "global normalize formats");
  struct Push { uint32_t tokens, heads, channels, scaleWordOffset; } push{tokens, heads, heads * 32, scaleByteOffset / 4};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[1] = &qkv.buffer;
  bindings[4] = &tensor.raw;
  bindings[5] = &normalized.buffer;
  dispatchLinear(commands, pipeline("global_normalize", {}), bindings, &push, sizeof(push), tokens * heads);
}

void Kernels::globalAttend(VkCommandBuffer commands, const Activation& normalized, Activation& attended,
                           uint32_t tokens, uint32_t paddedTokens, uint32_t heads) {
  check(normalized.format == Format::E4 && attended.format == Format::E4, "global attend formats");
  check(paddedTokens % 64 == 0 && paddedTokens >= tokens && normalized.allocRows >= paddedTokens, "global attend tokens");
  vk::SpecConstants constants;
  constants.add(0, paddedTokens);
  struct Push { uint32_t tokens, heads, channels; } push{tokens, heads, heads * 32};
  const vk::Buffer* bindings[vk::kGenericBindings] = {};
  bindings[0] = &normalized.buffer;
  bindings[5] = &attended.buffer;
  dispatch(commands, pipeline("global_attend", constants), bindings, &push, sizeof(push), heads, paddedTokens / 16, 1);
}

}  // namespace nr
