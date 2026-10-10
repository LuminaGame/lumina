/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "opendlss_nr/neural_pass.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

#include <algorithm>
#include <cmath>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

#include "gpu_engine_internal.h"
#include "kernels.h"
#include "nr_graph.h"
#include "nr_model.h"
#include "numeric.h"

using namespace filament;
using namespace bluevk;

namespace opendlss_nr {

namespace {

// The largest frame the pass takes: the GLSL route materializes every intermediate (about 1 GB at 1080p).
constexpr uint64_t kMaxPixels = 2560ull * 1600ull;

struct FrameParams {
  uint32_t fullWidth, fullHeight, validWidth, validHeight;
  uint32_t historyValid, seed, nrEnabled, styleId;
  float autoMask, paperWhite, colorStrength, intensity;
  float localTone, localStructure, skinStructure, blendScale;
};
static_assert(sizeof(FrameParams) == 64, "push constants");

#ifdef _WIN32
// The vendored loader opens files with narrow paths (the ANSI code page on Windows): hand it the short
// (8.3, ASCII) form of a directory whose name has other characters.
std::string loaderPath(const std::string& utf8) {
  bool ascii = std::all_of(utf8.begin(), utf8.end(), [](char c) { return (unsigned char)c < 0x80; });
  if (ascii) return utf8;
  int wide = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring w((size_t)wide, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, w.data(), wide);
  DWORD n = GetShortPathNameW(w.c_str(), nullptr, 0);
  if (!n) return utf8;
  std::wstring s((size_t)n, L'\0');
  GetShortPathNameW(w.c_str(), s.data(), n);
  s.resize(wcslen(s.c_str()));
  std::string out;
  for (wchar_t c : s) {
    if (c >= 0x80) return utf8;
    out.push_back((char)c);
  }
  return out;
}
#else
std::string loaderPath(const std::string& utf8) { return utf8; }
#endif

}  // namespace

LoadedModel::~LoadedModel() {
  model.reset();
  if (context) context->releaseAll();
  context.reset();
}

LoadedModel* loadModel(Engine* engine, const std::string& directory, std::string& error) {
  void* instance = nullptr;
  void* physical = nullptr;
  void* device = nullptr;
  if (!engine || !flutter_filament_engine_vulkan_handles(engine, &instance, &physical, &device, nullptr)) {
    error = "OpenDLSS-NR needs an engine on the desktop Vulkan backend";
    return nullptr;
  }
  try {
    auto loaded = std::make_unique<LoadedModel>();
    loaded->engine = engine;
    loaded->context = std::make_unique<vk::Context>(static_cast<VkPhysicalDevice>(physical), static_cast<VkDevice>(device));
    // Hashes were checked (or skipped on purpose) by checkModel; the loader re-reads the stage files.
    loaded->model = std::make_unique<nr::Model>(*loaded->context, loaderPath(directory), false);
    if (loaded->model->blockCount() != nr::Graph::kBlockCount) {
      error = "the model is not the 71-block network";
      return nullptr;
    }
    const nr::Tensor& blend = loaded->model->tensor(70, 0, "blend_scale");
    loaded->blendScale = blend.byteLength >= 2 ? num::f16ToF32((uint16_t)(blend.bytes[0] | (blend.bytes[1] << 8))) : 0.0f;
    if (!std::isfinite(loaded->blendScale)) loaded->blendScale = 0.0f;
    return loaded.release();
  } catch (const std::exception& e) {
    error = std::string("loading the model failed: ") + e.what();
    return nullptr;
  }
}

NeuralPass::NeuralPass(Engine* engine, View* view, LoadedModel* model)
    : engine_(engine), view_(view), model_(model), vk_(*model->context), device_(model->context->device()) {
  model_->passes.fetch_add(1);
}

NeuralPass::~NeuralPass() { model_->passes.fetch_sub(1); }

void NeuralPass::fail(const std::string& reason) noexcept {
  try {
    std::lock_guard<std::mutex> lock(mutex_);
    if (failure_.empty()) failure_ = reason;
  } catch (...) {
  }
  failed_ = true;
}

bool NeuralPass::supports(uint32_t width, uint32_t height) noexcept {
  return !failed_.load() && width >= 33 && height >= 33 && (uint64_t)width * height <= kMaxPixels;
}

void NeuralPass::setControls(const Controls& controls) {
  std::lock_guard<std::mutex> lock(mutex_);
  controls_ = controls;
}

Status NeuralPass::status() const {
  Status s;
  s.frames = frames_.load();
  s.width = width_.load();
  s.height = height_.load();
  s.failed = failed_.load();
  s.dispatches = dispatches_.load();
  s.deviceBytes = vk_.allocatedBytes();
  std::lock_guard<std::mutex> lock(mutex_);
  s.gpuMs = gpuMs_;
  s.gpuMsAverage = gpuMsAverage_;
  return s;
}

std::string NeuralPass::failure() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return failure_;
}

void NeuralPass::ensureFrameObjects() {
  if (compositePipeline_.pipeline) return;
  VkSamplerCreateInfo samplerInfo{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
  samplerInfo.magFilter = VK_FILTER_LINEAR;
  samplerInfo.minFilter = VK_FILTER_LINEAR;
  samplerInfo.addressModeU = samplerInfo.addressModeV = samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  VK_CHECK(vkCreateSampler(device_, &samplerInfo, nullptr, &linear_));
  samplerInfo.magFilter = VK_FILTER_NEAREST;
  samplerInfo.minFilter = VK_FILTER_NEAREST;
  VK_CHECK(vkCreateSampler(device_, &samplerInfo, nullptr, &nearest_));

  VkDescriptorSetLayoutBinding bindings[6] = {};
  for (uint32_t i = 0; i < 6; ++i) {
    bindings[i].binding = i;
    bindings[i].descriptorCount = 1;
    bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
    bindings[i].descriptorType = i < 3 ? VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
                                 : i == 3 ? VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
                                          : VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  }
  VkDescriptorSetLayoutCreateInfo layoutInfo{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
  layoutInfo.bindingCount = 6;
  layoutInfo.pBindings = bindings;
  VK_CHECK(vkCreateDescriptorSetLayout(device_, &layoutInfo, nullptr, &frameSetLayout_));
  VkPushConstantRange range{VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(FrameParams)};
  VkPipelineLayoutCreateInfo pipelineLayoutInfo{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
  pipelineLayoutInfo.setLayoutCount = 1;
  pipelineLayoutInfo.pSetLayouts = &frameSetLayout_;
  pipelineLayoutInfo.pushConstantRangeCount = 1;
  pipelineLayoutInfo.pPushConstantRanges = &range;
  VK_CHECK(vkCreatePipelineLayout(device_, &pipelineLayoutInfo, nullptr, &frameLayout_));
  VkDescriptorPoolSize sizes[3] = {
      {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 2 * kRing * 3},
      {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 2 * kRing},
      {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 2 * kRing * 2},
  };
  VkDescriptorPoolCreateInfo poolInfo{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
  poolInfo.maxSets = 2 * kRing;
  poolInfo.poolSizeCount = 3;
  poolInfo.pPoolSizes = sizes;
  VK_CHECK(vkCreateDescriptorPool(device_, &poolInfo, nullptr, &framePool_));
  VkDescriptorSetLayout layouts[2 * kRing];
  for (auto& l : layouts) l = frameSetLayout_;
  VkDescriptorSet sets[2 * kRing];
  VkDescriptorSetAllocateInfo allocInfo{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
  allocInfo.descriptorPool = framePool_;
  allocInfo.descriptorSetCount = 2 * kRing;
  allocInfo.pSetLayouts = layouts;
  VK_CHECK(vkAllocateDescriptorSets(device_, &allocInfo, sets));
  for (uint32_t i = 0; i < kRing; ++i) {
    featureSets_[i] = sets[i];
    compositeSets_[i] = sets[kRing + i];
  }
  VkQueryPoolCreateInfo queryInfo{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
  queryInfo.queryType = VK_QUERY_TYPE_TIMESTAMP;
  queryInfo.queryCount = 2 * kRing;
  VK_CHECK(vkCreateQueryPool(device_, &queryInfo, nullptr, &queries_));
  featuresPipeline_ = vk_.createComputePipeline(vk_.shaderModule("nr_features"), {}, "nr_features", 0, frameLayout_);
  compositePipeline_ = vk_.createComputePipeline(vk_.shaderModule("nr_composite"), {}, "nr_composite", 0, frameLayout_);
}

void NeuralPass::releaseSized() {
  graph_.reset();   // its activations are retired, freed once the GPU passed this frame
  features_ = nullptr;
  for (auto& h : history_) vk_.destroyImage(h);
  vk_.resetSets();
  historyPrimed_ = false;
}

void NeuralPass::ensureGraph(uint32_t width, uint32_t height, VkCommandBuffer commands) {
  if (graph_ && graph_->geometry().validWidth == width && graph_->geometry().validHeight == height) return;
  releaseSized();
  if (!kernels_) kernels_ = std::make_unique<nr::Kernels>(vk_);
  const nr::Geometry geometry = nr::Geometry::fromValid(width, height);
  graph_ = std::make_unique<nr::Graph>(vk_, *model_->model, *kernels_, geometry, nr::Graph::Options{});
  fullWidth_ = geometry.fullWidth;
  fullHeight_ = geometry.fullHeight;
  features_ = graph_->allocate("input features", fullWidth_ * fullHeight_, 16, nr::Format::F32);
  for (auto& h : history_) {
    h = vk_.createImage(width, height, VK_FORMAT_R16G16B16A16_SFLOAT,
                        VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT);
  }
  // Both history images go to the general layout once, cleared.
  VkImageMemoryBarrier toGeneral[2] = {};
  for (int i = 0; i < 2; ++i) {
    toGeneral[i].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    toGeneral[i].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    toGeneral[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
    toGeneral[i].srcQueueFamilyIndex = toGeneral[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    toGeneral[i].image = history_[i].image;
    toGeneral[i].subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
    toGeneral[i].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  }
  vkCmdPipelineBarrier(commands, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 2, toGeneral);
  VkClearColorValue black{};
  VkImageSubresourceRange range{VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
  for (auto& h : history_) vkCmdClearColorImage(commands, h.image, VK_IMAGE_LAYOUT_GENERAL, &black, 1, &range);
  vk_.transferBarrier(commands);
}

void NeuralPass::readTimestamps() {
  if (frame_ < kRing) return;
  const uint32_t slot = (uint32_t)(frame_ % kRing);   // written kRing frames ago, about to be reused
  uint64_t stamps[2] = {};
  if (vkGetQueryPoolResults(device_, queries_, 2 * slot, 2, sizeof(stamps), stamps, sizeof(uint64_t),
                            VK_QUERY_RESULT_64_BIT) != VK_SUCCESS)
    return;
  const double ms = (double)(stamps[1] - stamps[0]) * vk_.timestampPeriodNs() * 1e-6;
  if (!(ms >= 0.0 && ms < 10000.0)) return;
  std::lock_guard<std::mutex> lock(mutex_);
  gpuMs_ = ms;
  gpuMsAverage_ = gpuMsAverage_ == 0.0 ? ms : gpuMsAverage_ * 0.9 + ms * 0.1;
}

void NeuralPass::recordComposite(VkCommandBuffer commands, backend::ExternalPassContext const& context, bool network) {
  auto const& color = context.images[ExternalPostPass::COLOR];
  auto const& motion = context.images[ExternalPostPass::MOTION];
  auto const& output = context.images[ExternalPostPass::OUTPUT];
  const uint32_t slot = (uint32_t)(frame_ % kRing);
  const uint32_t parity = (uint32_t)(frame_ & 1);
  Controls controls;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    controls = controls_;
  }
  const bool haveHistory = history_[0].image != VK_NULL_HANDLE;
  FrameParams params{};
  params.fullWidth = network ? fullWidth_ : color.width;
  params.fullHeight = network ? fullHeight_ : color.height;
  params.validWidth = color.width;
  params.validHeight = color.height;
  params.historyValid = (network && historyPrimed_ && !(context.frame.flags & backend::ExternalPassFrame::FLAG_HISTORY_RESET)) ? 1u : 0u;
  params.seed = context.frame.frameId;
  params.nrEnabled = network ? 1u : 0u;
  params.styleId = std::min<uint32_t>(controls.style, 2u);
  params.autoMask = controls.autoMask ? 1.0f : 0.0f;
  params.paperWhite = controls.paperWhite;
  params.colorStrength = std::clamp(controls.colorStrength, 0.0f, 1.0f);
  params.intensity = std::clamp(controls.intensity, 0.0f, 1.0f);
  params.localTone = controls.localTone;
  params.localStructure = controls.localStructure;
  params.skinStructure = controls.skinStructure;
  params.blendScale = model_->blendScale;

  VkImageView colorView = reinterpret_cast<VkImageView>(color.imageView);
  VkImageView motionView = reinterpret_cast<VkImageView>(motion.imageView);
  VkImageView prevView = haveHistory ? history_[1 - parity].view : colorView;
  VkImageView nextView = haveHistory ? history_[parity].view : VK_NULL_HANDLE;
  VkImageLayout const colorLayout = static_cast<VkImageLayout>(color.layout);
  VkImageLayout const motionLayout = static_cast<VkImageLayout>(motion.layout);

  auto writeSet = [&](VkDescriptorSet set, bool composite) {
    VkDescriptorImageInfo images[3] = {
        {nearest_, colorView, colorLayout},
        {linear_, prevView, haveHistory ? VK_IMAGE_LAYOUT_GENERAL : colorLayout},
        {nearest_, motionView, motionLayout},
    };
    // The head exists once the graph recorded; the bypass never reads binding 3.
    VkDescriptorBufferInfo buffer{composite && network ? graph_->head().buffer.buffer : features_->buffer.buffer, 0,
                                  VK_WHOLE_SIZE};
    VkDescriptorImageInfo storage[2] = {
        {VK_NULL_HANDLE, reinterpret_cast<VkImageView>(output.imageView), static_cast<VkImageLayout>(output.layout)},
        {VK_NULL_HANDLE, nextView, VK_IMAGE_LAYOUT_GENERAL},
    };
    VkWriteDescriptorSet writes[6] = {};
    uint32_t count = 0;
    for (uint32_t i = 0; i < 3; ++i) {
      writes[count] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
      writes[count].dstSet = set;
      writes[count].dstBinding = i;
      writes[count].descriptorCount = 1;
      writes[count].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
      writes[count].pImageInfo = &images[i];
      ++count;
    }
    writes[count] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    writes[count].dstSet = set;
    writes[count].dstBinding = 3;
    writes[count].descriptorCount = 1;
    writes[count].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    writes[count].pBufferInfo = &buffer;
    ++count;
    if (composite) {
      for (uint32_t i = 0; i < 2; ++i) {
        writes[count] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
        writes[count].dstSet = set;
        writes[count].dstBinding = 4 + i;
        writes[count].descriptorCount = 1;
        writes[count].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writes[count].pImageInfo = &storage[i];
        ++count;
      }
    }
    vkUpdateDescriptorSets(device_, count, writes, 0, nullptr);
  };

  if (network) {
    writeSet(featureSets_[slot], false);
    vkCmdBindPipeline(commands, VK_PIPELINE_BIND_POINT_COMPUTE, featuresPipeline_.pipeline);
    vkCmdBindDescriptorSets(commands, VK_PIPELINE_BIND_POINT_COMPUTE, frameLayout_, 0, 1, &featureSets_[slot], 0, nullptr);
    vkCmdPushConstants(commands, frameLayout_, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(params), &params);
    vkCmdDispatch(commands, (fullWidth_ + 7) / 8, (fullHeight_ + 7) / 8, 1);
    vk_.computeBarrier(commands);
    graph_->record(commands, *features_);
    vk_.computeBarrier(commands);
    dispatches_ = kernels_->dispatchCount() + 2;
  }
  if (!haveHistory) throw std::runtime_error("no history images");   // ensureGraph creates them first
  writeSet(compositeSets_[slot], true);
  vkCmdBindPipeline(commands, VK_PIPELINE_BIND_POINT_COMPUTE, compositePipeline_.pipeline);
  vkCmdBindDescriptorSets(commands, VK_PIPELINE_BIND_POINT_COMPUTE, frameLayout_, 0, 1, &compositeSets_[slot], 0, nullptr);
  vkCmdPushConstants(commands, frameLayout_, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(params), &params);
  vkCmdDispatch(commands, (color.width + 7) / 8, (color.height + 7) / 8, 1);
  historyPrimed_ = true;
}

void NeuralPass::record(backend::ExternalPassContext const& context, VkCommandBuffer commands) {
  auto const& color = context.images[ExternalPostPass::COLOR];
  ensureFrameObjects();
  readTimestamps();
  const uint32_t slot = (uint32_t)(frame_ % kRing);
  vkCmdResetQueryPool(commands, queries_, 2 * slot, 2);
  // The colour and the motion were just rendered; make them (and the previous frame's history) visible here.
  VkMemoryBarrier barrier{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
  barrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
  vkCmdPipelineBarrier(commands,
                       VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT |
                           VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &barrier, 0, nullptr, 0, nullptr);
  vkCmdWriteTimestamp(commands, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, queries_, 2 * slot);
  bool network = true;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    network = controls_.enabled;
  }
  try {
    ensureGraph(color.width, color.height, commands);
    recordComposite(commands, context, network);
  } catch (const std::exception& e) {
    fail(std::string("OpenDLSS-NR stopped: ") + e.what());
    // The commands recorded so far are valid; the frame still gets OUTPUT, unchanged from the colour.
    if (graph_ && history_[0].image) {
      try {
        recordComposite(commands, context, false);
      } catch (...) {
      }
    }
  }
  VkMemoryBarrier after{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
  after.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
  after.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT;
  vkCmdPipelineBarrier(commands, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT |
                           VK_PIPELINE_STAGE_TRANSFER_BIT,
                       0, 1, &after, 0, nullptr, 0, nullptr);
  vkCmdWriteTimestamp(commands, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, queries_, 2 * slot + 1);
  width_ = color.width;
  height_ = color.height;
  ++frame_;
  frames_.fetch_add(1);
}

void NeuralPass::evaluate(backend::ExternalPassContext const& context) noexcept {
  if (failed_.load()) return;
  if (context.backend != backend::Backend::VULKAN || context.imageCount < 4) {
    fail("OpenDLSS-NR runs on the Vulkan backend only");
    return;
  }
  auto commands = reinterpret_cast<VkCommandBuffer>(context.commandBuffer);
  bool begun = false;
  try {
    vk_.beginRecording(commands);
    begun = true;
    record(context, commands);
  } catch (const std::exception& e) {
    fail(std::string("OpenDLSS-NR stopped: ") + e.what());
  } catch (...) {
    fail("OpenDLSS-NR stopped: unknown error");
  }
  if (begun) {
    try {
      vk_.endRecording(commands);
    } catch (...) {
      fail("OpenDLSS-NR stopped: could not track the frame");
    }
  }
}

void NeuralPass::destroyObjects() {
  graph_.reset();
  kernels_.reset();
  for (auto& h : history_) vk_.destroyImage(h);
  vk_.resetSets();
  vk_.releaseAll();
  vk_.destroyPipeline(featuresPipeline_);
  vk_.destroyPipeline(compositePipeline_);
  if (queries_) vkDestroyQueryPool(device_, queries_, nullptr);
  if (framePool_) vkDestroyDescriptorPool(device_, framePool_, nullptr);
  if (frameLayout_) vkDestroyPipelineLayout(device_, frameLayout_, nullptr);
  if (frameSetLayout_) vkDestroyDescriptorSetLayout(device_, frameSetLayout_, nullptr);
  if (linear_) vkDestroySampler(device_, linear_, nullptr);
  if (nearest_) vkDestroySampler(device_, nearest_, nullptr);
  queries_ = VK_NULL_HANDLE;
  framePool_ = VK_NULL_HANDLE;
  frameLayout_ = VK_NULL_HANDLE;
  frameSetLayout_ = VK_NULL_HANDLE;
  linear_ = nearest_ = VK_NULL_HANDLE;
}

}  // namespace opendlss_nr

#endif  // FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
