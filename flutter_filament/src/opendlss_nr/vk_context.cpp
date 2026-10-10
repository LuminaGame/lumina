/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "opendlss_nr/opendlss_nr_config.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

#include "opendlss_nr/vk_context.h"

#include <algorithm>

#include "opendlss_nr/spirv.h"

namespace vk {

namespace {
constexpr VkDeviceSize kStagingChunk = 32ull << 20;
constexpr uint32_t kSetsPerPool = 512;
// VK_NV_shader_sm_builtins properties (the SM count sizes the persistent grids).
constexpr VkStructureType kSmBuiltinsProperties = VkStructureType(1000154001);
struct SmBuiltinsProperties {
  VkStructureType sType;
  void* pNext;
  uint32_t shaderSMCount;
  uint32_t shaderWarpsPerSM;
};
// VkPipelineShaderStageRequiredSubgroupSizeCreateInfo (VK_EXT_subgroup_size_control)
constexpr VkStructureType kRequiredSubgroupSize = VkStructureType(1000225001);
struct RequiredSubgroupSize {
  VkStructureType sType;
  void* pNext;
  uint32_t requiredSubgroupSize;
};
constexpr VkPipelineShaderStageCreateFlags kRequireFullSubgroups = 0x00000002;
}  // namespace

Context::Context(VkPhysicalDevice physical, VkDevice device) : physical_(physical), device_(device) {
  vkGetPhysicalDeviceMemoryProperties(physical_, &memoryProperties_);
  SmBuiltinsProperties sm{kSmBuiltinsProperties, nullptr, 0, 0};
  VkPhysicalDeviceProperties2 properties{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2};
  uint32_t extensionCount = 0;
  vkEnumerateDeviceExtensionProperties(physical_, nullptr, &extensionCount, nullptr);
  std::vector<VkExtensionProperties> extensions(extensionCount);
  vkEnumerateDeviceExtensionProperties(physical_, nullptr, &extensionCount, extensions.data());
  for (auto const& e : extensions) {
    if (std::strcmp(e.extensionName, "VK_NV_shader_sm_builtins") == 0) properties.pNext = &sm;
  }
  vkGetPhysicalDeviceProperties2(physical_, &properties);
  timestampPeriod_ = properties.properties.limits.timestampPeriod;
  if (sm.shaderSMCount) smCount_ = sm.shaderSMCount;

  VkDescriptorSetLayoutBinding bindings[kGenericBindings];
  for (uint32_t i = 0; i < kGenericBindings; ++i) {
    bindings[i] = {};
    bindings[i].binding = i;
    bindings[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[i].descriptorCount = 1;
    bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
  }
  VkDescriptorSetLayoutCreateInfo layoutInfo{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
  layoutInfo.bindingCount = kGenericBindings;
  layoutInfo.pBindings = bindings;
  VK_CHECK(vkCreateDescriptorSetLayout(device_, &layoutInfo, nullptr, &setLayout_));
  VkPushConstantRange range{VK_SHADER_STAGE_COMPUTE_BIT, 0, kPushConstantBytes};
  VkPipelineLayoutCreateInfo pipelineLayoutInfo{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
  pipelineLayoutInfo.setLayoutCount = 1;
  pipelineLayoutInfo.pSetLayouts = &setLayout_;
  pipelineLayoutInfo.pushConstantRangeCount = 1;
  pipelineLayoutInfo.pPushConstantRanges = &range;
  VK_CHECK(vkCreatePipelineLayout(device_, &pipelineLayoutInfo, nullptr, &pipelineLayout_));
  dummy_ = createBuffer(256, false, "dummy");
  fillZero(dummy_);
}

Context::~Context() {
  releaseAll();
  for (auto& [name, module] : modules_) vkDestroyShaderModule(device_, module, nullptr);
  for (VkDescriptorPool pool : pools_) vkDestroyDescriptorPool(device_, pool, nullptr);
  auto destroyNow = [&](Buffer& b) {
    if (b.buffer) vkDestroyBuffer(device_, b.buffer, nullptr);
    if (b.memory) vkFreeMemory(device_, b.memory, nullptr);
    b = Buffer{};
  };
  destroyNow(dummy_);
  destroyNow(staging_);
  if (pipelineLayout_) vkDestroyPipelineLayout(device_, pipelineLayout_, nullptr);
  if (setLayout_) vkDestroyDescriptorSetLayout(device_, setLayout_, nullptr);
  for (VkEvent event : freeEvents_) vkDestroyEvent(device_, event, nullptr);
}

uint32_t Context::findMemoryType(uint32_t typeBits, VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) {
  for (VkMemoryPropertyFlags want : {required | preferred, required}) {
    for (uint32_t i = 0; i < memoryProperties_.memoryTypeCount; ++i) {
      if ((typeBits & (1u << i)) && (memoryProperties_.memoryTypes[i].propertyFlags & want) == want) return i;
    }
  }
  throw std::runtime_error("no suitable Vulkan memory type");
}

Buffer Context::createBuffer(VkDeviceSize size, bool hostVisible, const char* label, VkBufferUsageFlags extra) {
  Buffer result;
  result.size = std::max<VkDeviceSize>(size, 16);
  result.hostVisible = hostVisible;
  result.label = label;
  VkBufferCreateInfo info{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  info.size = result.size;
  info.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT | extra;
  info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  VK_CHECK(vkCreateBuffer(device_, &info, nullptr, &result.buffer));
  VkMemoryRequirements requirements;
  vkGetBufferMemoryRequirements(device_, result.buffer, &requirements);
  VkMemoryAllocateInfo allocateInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocateInfo.allocationSize = requirements.size;
  try {
    allocateInfo.memoryTypeIndex = findMemoryType(
        requirements.memoryTypeBits,
        hostVisible ? (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
                    : VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    VK_CHECK(vkAllocateMemory(device_, &allocateInfo, nullptr, &result.memory));
  } catch (...) {
    vkDestroyBuffer(device_, result.buffer, nullptr);
    throw;
  }
  VK_CHECK(vkBindBufferMemory(device_, result.buffer, result.memory, 0));
  if (hostVisible) VK_CHECK(vkMapMemory(device_, result.memory, 0, VK_WHOLE_SIZE, 0, &result.mapped));
  allocatedBytes_ += requirements.size;
  return result;
}

void Context::destroyBuffer(Buffer& buffer) {
  if (!buffer.buffer) return;
  std::lock_guard<std::mutex> lock(mutex_);
  retired_.buffers.push_back(buffer);
  buffer = Buffer{};
}

Image Context::createImage(uint32_t width, uint32_t height, VkFormat format, VkImageUsageFlags usage) {
  Image image;
  image.width = width;
  image.height = height;
  VkImageCreateInfo info{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
  info.imageType = VK_IMAGE_TYPE_2D;
  info.format = format;
  info.extent = {width, height, 1};
  info.mipLevels = 1;
  info.arrayLayers = 1;
  info.samples = VK_SAMPLE_COUNT_1_BIT;
  info.tiling = VK_IMAGE_TILING_OPTIMAL;
  info.usage = usage;
  info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  VK_CHECK(vkCreateImage(device_, &info, nullptr, &image.image));
  VkMemoryRequirements requirements;
  vkGetImageMemoryRequirements(device_, image.image, &requirements);
  VkMemoryAllocateInfo allocateInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocateInfo.allocationSize = requirements.size;
  allocateInfo.memoryTypeIndex = findMemoryType(requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
  VK_CHECK(vkAllocateMemory(device_, &allocateInfo, nullptr, &image.memory));
  VK_CHECK(vkBindImageMemory(device_, image.image, image.memory, 0));
  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = image.image;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = format;
  viewInfo.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
  VK_CHECK(vkCreateImageView(device_, &viewInfo, nullptr, &image.view));
  allocatedBytes_ += requirements.size;
  return image;
}

void Context::destroyImage(Image& image) {
  if (!image.image) return;
  std::lock_guard<std::mutex> lock(mutex_);
  retired_.images.push_back(image);
  image = Image{};
}

void Context::stageCopy(const Buffer& target, const void* data, VkDeviceSize size, VkDeviceSize offset) {
  const VkDeviceSize aligned = (size + 15) & ~VkDeviceSize(15);
  if (!staging_.buffer || stagingUsed_ + aligned > staging_.size) {
    if (staging_.buffer) retired_.buffers.push_back(staging_);
    staging_ = createBuffer(std::max(kStagingChunk, aligned), true, "staging");
    stagingUsed_ = 0;
  }
  std::memcpy(static_cast<uint8_t*>(staging_.mapped) + stagingUsed_, data, size);
  pendingCopies_.push_back({staging_.buffer, stagingUsed_, target.buffer, offset, size});
  stagingUsed_ += aligned;
}

void Context::upload(const Buffer& target, const void* data, VkDeviceSize size, VkDeviceSize offset) {
  if (size == 0) return;
  std::lock_guard<std::mutex> lock(mutex_);
  stageCopy(target, data, size, offset);
  if (recording_) recordPending(recording_);
}

void Context::fillZero(const Buffer& target) {
  std::lock_guard<std::mutex> lock(mutex_);
  pendingFills_.push_back({target.buffer});
  if (recording_) recordPending(recording_);
}

void Context::recordPending(VkCommandBuffer commands) {
  if (pendingFills_.empty() && pendingCopies_.empty()) return;
  for (auto const& fill : pendingFills_) vkCmdFillBuffer(commands, fill.target, 0, VK_WHOLE_SIZE, 0);
  for (auto const& copy : pendingCopies_) {
    VkBufferCopy region{copy.stagingOffset, copy.offset, copy.size};
    vkCmdCopyBuffer(commands, copy.staging, copy.target, 1, &region);
  }
  pendingFills_.clear();
  pendingCopies_.clear();
  transferBarrier(commands);
}

VkShaderModule Context::shaderModule(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = modules_.find(name);
  if (it != modules_.end()) return it->second;
  const opendlss_nr::SpirvModule* spirv = opendlss_nr::findSpirv(name.c_str());
  if (!spirv) throw std::runtime_error("no embedded SPIR-V for " + name);
  VkShaderModuleCreateInfo info{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
  info.codeSize = spirv->words * 4;
  info.pCode = spirv->code;
  VkShaderModule module = VK_NULL_HANDLE;
  VK_CHECK(vkCreateShaderModule(device_, &info, nullptr, &module));
  modules_[name] = module;
  return module;
}

Pipeline Context::createComputePipeline(VkShaderModule module, const SpecConstants& constants, const char* label,
                                        uint32_t requiredSubgroupSize, VkPipelineLayout layout) {
  VkSpecializationInfo specialization{};
  specialization.mapEntryCount = (uint32_t)constants.entries.size();
  specialization.pMapEntries = constants.entries.data();
  specialization.dataSize = constants.data.size() * 4;
  specialization.pData = constants.data.data();
  RequiredSubgroupSize subgroupInfo{kRequiredSubgroupSize, nullptr, requiredSubgroupSize};
  VkPipelineShaderStageCreateInfo stage{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO};
  stage.pNext = requiredSubgroupSize ? &subgroupInfo : nullptr;
  stage.flags = requiredSubgroupSize ? kRequireFullSubgroups : 0;
  stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
  stage.module = module;
  stage.pName = "main";
  stage.pSpecializationInfo = constants.entries.empty() ? nullptr : &specialization;
  VkComputePipelineCreateInfo info{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
  info.stage = stage;
  info.layout = layout ? layout : pipelineLayout_;
  Pipeline result;
  result.label = label;
  VK_CHECK(vkCreateComputePipelines(device_, VK_NULL_HANDLE, 1, &info, nullptr, &result.pipeline));
  return result;
}

void Context::destroyPipeline(Pipeline& pipeline) {
  // Pipelines are destroyed with the pass, after the engine waited for the GPU.
  if (pipeline.pipeline) vkDestroyPipeline(device_, pipeline.pipeline, nullptr);
  pipeline.pipeline = VK_NULL_HANDLE;
}

void Context::addPool() {
  VkDescriptorPoolSize size{VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, kSetsPerPool * kGenericBindings};
  VkDescriptorPoolCreateInfo info{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
  info.maxSets = kSetsPerPool;
  info.poolSizeCount = 1;
  info.pPoolSizes = &size;
  VkDescriptorPool pool = VK_NULL_HANDLE;
  VK_CHECK(vkCreateDescriptorPool(device_, &info, nullptr, &pool));
  pools_.push_back(pool);
  setsInPool_ = 0;
}

VkDescriptorSet Context::allocateSet(const Buffer* const bindings[kGenericBindings],
                                     const VkDeviceSize offsets[kGenericBindings],
                                     const VkDeviceSize ranges[kGenericBindings]) {
  std::lock_guard<std::mutex> lock(mutex_);
  std::string key;
  key.reserve(kGenericBindings * 40);
  for (uint32_t i = 0; i < kGenericBindings; ++i) {
    const Buffer* buffer = bindings[i] ? bindings[i] : &dummy_;
    key += std::to_string((uint64_t)buffer->buffer) + ":" + std::to_string(offsets ? offsets[i] : 0) + ":" +
           std::to_string(ranges ? ranges[i] : 0) + ";";
  }
  auto it = sets_.find(key);
  if (it != sets_.end()) return it->second;
  if (pools_.empty() || setsInPool_ >= kSetsPerPool) addPool();
  VkDescriptorSetAllocateInfo allocateInfo{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
  allocateInfo.descriptorPool = pools_.back();
  allocateInfo.descriptorSetCount = 1;
  allocateInfo.pSetLayouts = &setLayout_;
  VkDescriptorSet set = VK_NULL_HANDLE;
  VK_CHECK(vkAllocateDescriptorSets(device_, &allocateInfo, &set));
  ++setsInPool_;
  VkDescriptorBufferInfo infos[kGenericBindings];
  VkWriteDescriptorSet writes[kGenericBindings];
  for (uint32_t index = 0; index < kGenericBindings; ++index) {
    const Buffer* buffer = bindings[index] ? bindings[index] : &dummy_;
    infos[index] = {buffer->buffer, offsets ? offsets[index] : 0,
                    ranges && ranges[index] ? ranges[index] : VK_WHOLE_SIZE};
    writes[index] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    writes[index].dstSet = set;
    writes[index].dstBinding = index;
    writes[index].descriptorCount = 1;
    writes[index].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    writes[index].pBufferInfo = &infos[index];
  }
  vkUpdateDescriptorSets(device_, kGenericBindings, writes, 0, nullptr);
  sets_[key] = set;
  return set;
}

void Context::resetSets() {
  std::lock_guard<std::mutex> lock(mutex_);
  sets_.clear();
  for (VkDescriptorPool pool : pools_) retired_.pools.push_back(pool);
  pools_.clear();
  setsInPool_ = 0;
}

void Context::computeBarrier(VkCommandBuffer commands) {
  // Compute -> compute only (transfer stages here make the driver flush caches between every dispatch).
  VkMemoryBarrier barrier{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
  barrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
  vkCmdPipelineBarrier(commands, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1,
                       &barrier, 0, nullptr, 0, nullptr);
}

void Context::transferBarrier(VkCommandBuffer commands) {
  VkMemoryBarrier barrier{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT | VK_ACCESS_SHADER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT |
                          VK_ACCESS_TRANSFER_WRITE_BIT;
  vkCmdPipelineBarrier(commands, VK_PIPELINE_STAGE_TRANSFER_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &barrier, 0,
                       nullptr, 0, nullptr);
}

void Context::beginRecording(VkCommandBuffer commands) {
  std::lock_guard<std::mutex> lock(mutex_);
  collect(false);
  recording_ = commands;
  recordPending(commands);
}

void Context::endRecording(VkCommandBuffer commands) {
  std::lock_guard<std::mutex> lock(mutex_);
  recording_ = VK_NULL_HANDLE;
  // The staging chunk was read by this recording's copies.
  if (staging_.buffer && stagingUsed_ > 0) {
    retired_.buffers.push_back(staging_);
    staging_ = Buffer{};
    stagingUsed_ = 0;
  }
  VkEvent event = VK_NULL_HANDLE;
  if (!freeEvents_.empty()) {
    event = freeEvents_.back();
    freeEvents_.pop_back();
  } else {
    VkEventCreateInfo info{VK_STRUCTURE_TYPE_EVENT_CREATE_INFO};
    VK_CHECK(vkCreateEvent(device_, &info, nullptr, &event));
  }
  vkCmdSetEvent(commands, event, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT);
  inFlight_.push_back({event, std::move(retired_)});
  retired_ = Retired{};
}

void Context::freeRetired(Retired& retired) {
  for (auto& b : retired.buffers) {
    if (b.buffer) vkDestroyBuffer(device_, b.buffer, nullptr);
    if (b.memory) vkFreeMemory(device_, b.memory, nullptr);
  }
  for (auto& image : retired.images) {
    if (image.view) vkDestroyImageView(device_, image.view, nullptr);
    if (image.image) vkDestroyImage(device_, image.image, nullptr);
    if (image.memory) vkFreeMemory(device_, image.memory, nullptr);
  }
  for (VkDescriptorPool pool : retired.pools) vkDestroyDescriptorPool(device_, pool, nullptr);
  retired = Retired{};
}

void Context::collect(bool all) {
  // A set event means the GPU passed that recording, and every earlier one of the same queue.
  size_t done = 0;
  for (size_t i = 0; i < inFlight_.size(); ++i) {
    if (all || vkGetEventStatus(device_, inFlight_[i].event) == VK_EVENT_SET) done = i + 1;
  }
  for (size_t i = 0; i < done; ++i) {
    freeRetired(inFlight_[i].retired);
    vkResetEvent(device_, inFlight_[i].event);
    freeEvents_.push_back(inFlight_[i].event);
  }
  inFlight_.erase(inFlight_.begin(), inFlight_.begin() + (ptrdiff_t)done);
}

void Context::releaseAll() {
  std::lock_guard<std::mutex> lock(mutex_);
  collect(true);
  freeRetired(retired_);
}

}  // namespace vk

#endif  // FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
