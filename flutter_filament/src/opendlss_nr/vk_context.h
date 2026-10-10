/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The Vulkan host the vendored OpenDLSS-NR network code (third_party/opendlss_nr) runs on inside Filament: the
// same `vk::Context` interface the upstream files use, implemented over bluevk on Filament's own device. Nothing is
// submitted: uploads and buffer fills are recorded into the command buffer Filament hands the external post pass
// (or queued until the first one), descriptor sets are written once and reused for as long as their buffers live,
// and objects are destroyed only after a VkEvent recorded behind their last use has signalled.
#pragma once

#include <bluevk/BlueVK.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <map>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>

#define VK_CHECK(expr)                                                                 \
  do {                                                                                 \
    VkResult vk_check_result_ = (expr);                                                \
    if (vk_check_result_ != VK_SUCCESS)                                                \
      throw std::runtime_error(std::string(#expr) + " failed: " +                      \
                               std::to_string((int)vk_check_result_));                 \
  } while (0)

// The vendored sources call vk* as volk declares them: globally.
using namespace bluevk;

namespace vk {

struct Buffer {
  VkBuffer buffer = VK_NULL_HANDLE;
  VkDeviceMemory memory = VK_NULL_HANDLE;
  VkDeviceSize size = 0;
  bool hostVisible = false;
  void* mapped = nullptr;
  const char* label = "";
};

struct Image {
  VkImage image = VK_NULL_HANDLE;
  VkDeviceMemory memory = VK_NULL_HANDLE;
  VkImageView view = VK_NULL_HANDLE;
  uint32_t width = 0, height = 0;
};

constexpr uint32_t kGenericBindings = 12;
constexpr uint32_t kPushConstantBytes = 128;

struct SpecConstants {
  std::vector<VkSpecializationMapEntry> entries;
  std::vector<uint32_t> data;
  void add(uint32_t id, uint32_t value) {
    entries.push_back({id, (uint32_t)(data.size() * 4), 4});
    data.push_back(value);
  }
};

struct Pipeline {
  VkPipeline pipeline = VK_NULL_HANDLE;
  const char* label = "";
};

class Context {
 public:
  // Adopts Filament's device. The physical device decides the memory types, the SM count and the limits.
  Context(VkPhysicalDevice physical, VkDevice device);
  ~Context();

  VkDevice device() const { return device_; }
  VkPhysicalDevice physical() const { return physical_; }
  uint32_t smCount() const { return smCount_; }
  float timestampPeriodNs() const { return timestampPeriod_; }
  VkPipelineLayout pipelineLayout() const { return pipelineLayout_; }

  // Buffers -----------------------------------------------------------------
  Buffer createBuffer(VkDeviceSize size, bool hostVisible, const char* label, VkBufferUsageFlags extra = 0);
  // Deferred: released once the GPU is past every recording made so far.
  void destroyBuffer(Buffer& buffer);
  // Recorded into the current command buffer, or queued for the next one.
  void upload(const Buffer& target, const void* data, VkDeviceSize size, VkDeviceSize offset = 0);
  void fillZero(const Buffer& target);

  Image createImage(uint32_t width, uint32_t height, VkFormat format, VkImageUsageFlags usage);
  void destroyImage(Image& image);

  // Pipelines -----------------------------------------------------------------
  // The embedded SPIR-V module of one network kernel ("gemm_fp8", ...), created on first use.
  VkShaderModule shaderModule(const std::string& name);
  Pipeline createComputePipeline(VkShaderModule module, const SpecConstants& constants, const char* label,
                                 uint32_t requiredSubgroupSize = 32, VkPipelineLayout layout = VK_NULL_HANDLE);
  void destroyPipeline(Pipeline& pipeline);

  // Descriptors: one generic layout with kGenericBindings storage buffers; a set per distinct binding list, written
  // once and reused (the buffers of a graph never change). Forget them when the buffers go (resetSets).
  VkDescriptorSet allocateSet(const Buffer* const bindings[kGenericBindings],
                              const VkDeviceSize offsets[kGenericBindings] = nullptr,
                              const VkDeviceSize ranges[kGenericBindings] = nullptr);
  void resetSets();

  void computeBarrier(VkCommandBuffer commands);   // compute -> compute
  void transferBarrier(VkCommandBuffer commands);  // transfer -> compute / transfer

  // Recording ---------------------------------------------------------------
  // Begins using `commands`: frees what the GPU is done with, records the queued uploads.
  void beginRecording(VkCommandBuffer commands);
  // Ends it: a VkEvent set at this point guards everything retired so far.
  void endRecording(VkCommandBuffer commands);
  // The device is idle (the caller waited on the engine): free everything retired.
  void releaseAll();

  // Device memory this context holds, in bytes.
  uint64_t allocatedBytes() const { return allocatedBytes_; }

 private:
  struct PendingCopy { VkBuffer staging; VkDeviceSize stagingOffset; VkBuffer target; VkDeviceSize offset, size; };
  struct PendingFill { VkBuffer target; };
  struct Retired {
    std::vector<Buffer> buffers;
    std::vector<Image> images;
    std::vector<VkDescriptorPool> pools;
  };
  struct InFlight { VkEvent event; Retired retired; };

  uint32_t findMemoryType(uint32_t typeBits, VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred = 0);
  void stageCopy(const Buffer& target, const void* data, VkDeviceSize size, VkDeviceSize offset);
  void recordPending(VkCommandBuffer commands);
  void collect(bool all);
  void freeRetired(Retired& retired);
  void addPool();

  VkPhysicalDevice physical_ = VK_NULL_HANDLE;
  VkDevice device_ = VK_NULL_HANDLE;
  VkPhysicalDeviceMemoryProperties memoryProperties_{};
  float timestampPeriod_ = 1.0f;
  uint32_t smCount_ = 16;
  VkDescriptorSetLayout setLayout_ = VK_NULL_HANDLE;
  VkPipelineLayout pipelineLayout_ = VK_NULL_HANDLE;
  std::vector<VkDescriptorPool> pools_;
  uint32_t setsInPool_ = 0;
  std::map<std::string, VkDescriptorSet> sets_;
  std::map<std::string, VkShaderModule> modules_;
  Buffer dummy_;

  // Staging: host-visible chunks, sub-allocated linearly; a chunk is retired with the recording that copied it.
  Buffer staging_;
  VkDeviceSize stagingUsed_ = 0;
  std::vector<PendingCopy> pendingCopies_;
  std::vector<PendingFill> pendingFills_;

  VkCommandBuffer recording_ = VK_NULL_HANDLE;
  Retired retired_;
  std::vector<InFlight> inFlight_;
  std::vector<VkEvent> freeEvents_;
  uint64_t allocatedBytes_ = 0;
  std::mutex mutex_;
};

}  // namespace vk
