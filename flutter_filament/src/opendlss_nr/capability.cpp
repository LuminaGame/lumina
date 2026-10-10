/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "opendlss_nr/opendlss_nr_config.h"
#include "opendlss_nr/capability.h"

#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

#include "vulkan_features_c.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
#include <bluevk/BlueVK.h>

#include "gpu_engine_internal.h"
#endif

namespace opendlss_nr {

namespace {

constexpr const char* kRequester = "opendlss_nr";

// A VkPhysicalDevice*Features structure by its numbers: Filament's bundled Vulkan headers predate some of them.
struct FeatureStruct {
  const char* label;
  uint32_t sType;
  uint32_t size;
  const char* extension;
  std::vector<uint32_t> fields;     // requested VkBool32 members (byte offsets)
  std::vector<uint32_t> required;   // the ones the kernels cannot run without
};

const std::vector<FeatureStruct>& features() {
  static const std::vector<FeatureStruct> list = {
      {"cooperative matrices", 1000506000u, 24, "VK_KHR_cooperative_matrix", {16}, {16}},
      // workgroup scope, flexible dimensions, reductions, conversions, per-element operations, tensor addressing,
      // block loads
      {"cooperative matrix 2", 1000593000u, 48, "VK_NV_cooperative_matrix2", {16, 20, 24, 28, 32, 36, 40}, {20, 28, 32, 36}},
      {"FP8 (shaderFloat8, shaderFloat8CooperativeMatrix)", 1000567000u, 24, "VK_EXT_shader_float8", {16, 20}, {16, 20}},
      {"16-bit floats and 8-bit integers", 1000082000u, 24, "VK_KHR_shader_float16_int8", {16, 20}, {16, 20}},
      {"8-bit storage", 1000177000u, 32, "VK_KHR_8bit_storage", {16, 20}, {16}},
      {"the Vulkan memory model", 1000211000u, 32, "VK_KHR_vulkan_memory_model", {16, 20}, {16}},
      {"subgroup size control", 1000225002u, 24, "VK_EXT_subgroup_size_control", {16, 20}, {16, 20}},
      {"maintenance4", 1000413000u, 24, "VK_KHR_maintenance4", {16}, {16}},
      // Core structures Filament chains itself (patch 0018 merges the members into its own):
      // VkPhysicalDeviceFeatures2::features.shaderInt16 (offset 16 + 41 * 4) and
      // VkPhysicalDevice16BitStorageFeatures::storageBuffer16BitAccess / uniformAndStorageBuffer16BitAccess.
      {"16-bit integers (shaderInt16)", 1000059000u, 240, "", {180}, {180}},
      {"16-bit storage", 1000083000u, 32, "", {16, 20}, {16}},
  };
  return list;
}

}  // namespace

void requestDeviceFeatures() {
  // The kernels are SPIR-V 1.6: Vulkan 1.3.
  filament_vulkan_request_api_version(kRequester, (1u << 22) | (3u << 12));
  for (const FeatureStruct& f : features()) {
    if (*f.extension) filament_vulkan_request_device_extension(kRequester, f.extension);
    for (uint32_t field : f.fields) filament_vulkan_request_device_feature(kRequester, f.sType, f.size, field, f.extension);
  }
}

Capability checkCapability(void* engine) {
  Capability c;
#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
  using namespace bluevk;
  void* instance = nullptr;
  void* physicalHandle = nullptr;
  void* device = nullptr;
  if (!engine || !flutter_filament_engine_vulkan_handles(engine, &instance, &physicalHandle, &device, nullptr)) {
    c.code = kNotVulkan;
    c.reason = "OpenDLSS-NR needs the desktop Vulkan backend";
    return c;
  }
  auto physical = static_cast<VkPhysicalDevice>(physicalHandle);
  VkPhysicalDeviceProperties properties{};
  vkGetPhysicalDeviceProperties(physical, &properties);
  c.deviceName = properties.deviceName;
  if (properties.vendorID != 0x10DE) {
    c.code = kNotNvidia;
    c.reason = "OpenDLSS-NR needs an NVIDIA GPU (Ada or newer); this device is " + c.deviceName;
    return c;
  }
  uint32_t count = 0;
  vkEnumerateDeviceExtensionProperties(physical, nullptr, &count, nullptr);
  std::vector<VkExtensionProperties> extensions(count);
  vkEnumerateDeviceExtensionProperties(physical, nullptr, &count, extensions.data());
  auto supported = [&](const char* name) {
    for (auto const& e : extensions) {
      if (std::strcmp(e.extensionName, name) == 0) return true;
    }
    return false;
  };
  static_assert(offsetof(VkPhysicalDeviceFeatures2, features) + offsetof(VkPhysicalDeviceFeatures, shaderInt16) == 180,
                "shaderInt16 offset");
  static_assert(sizeof(VkPhysicalDeviceFeatures2) <= 240, "VkPhysicalDeviceFeatures2 size");
  for (const FeatureStruct& f : features()) {
    if (*f.extension && !supported(f.extension)) {
      c.code = f.sType == 1000567000u || f.sType == 1000593000u ? kOlderGpu : kMissingExtension;
      c.reason = c.code == kOlderGpu
                     ? "OpenDLSS-NR needs an NVIDIA Ada or newer GPU (" + std::string(f.extension) + " is missing on " + c.deviceName + ")"
                     : "the driver lacks " + std::string(f.extension) + " (" + f.label + ")";
      return c;
    }
  }
  // The device's support, member by member.
  for (const FeatureStruct& f : features()) {
    std::vector<uint8_t> query(f.size, 0);
    std::memcpy(query.data(), &f.sType, sizeof(uint32_t));
    if (f.sType == uint32_t(VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2)) {
      // the core features: the query structure itself
      vkGetPhysicalDeviceFeatures2(physical, reinterpret_cast<VkPhysicalDeviceFeatures2*>(query.data()));
    } else {
      VkPhysicalDeviceFeatures2 features2{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2};
      features2.pNext = query.data();
      vkGetPhysicalDeviceFeatures2(physical, &features2);
    }
    for (uint32_t field : f.required) {
      VkBool32 value = VK_FALSE;
      std::memcpy(&value, query.data() + field, sizeof(value));
      if (!value) {
        c.code = f.sType == 1000567000u ? kOlderGpu : kMissingExtension;
        c.reason = c.code == kOlderGpu ? "OpenDLSS-NR needs an NVIDIA Ada or newer GPU (no FP8 tensor cores on " + c.deviceName + ")"
                                       : c.deviceName + " does not support " + f.label;
        return c;
      }
    }
  }
  // ... and what the engine's device was created with.
  for (const FeatureStruct& f : features()) {
    for (uint32_t field : f.required) {
      if (!filament_vulkan_device_feature_enabled(engine, f.sType, field)) {
        c.code = kNotEnabled;
        c.reason = std::string("the engine was created without ") + f.label +
                   "; restart after requesting the OpenDLSS-NR device features";
        return c;
      }
    }
  }
  // The kernels are SPIR-V 1.6, which needs a Vulkan 1.3 device.
  if (const uint32_t api = filament_vulkan_api_version(engine); api < ((1u << 22) | (3u << 12))) {
    c.code = kNotEnabled;
    c.reason = "the engine's Vulkan device runs API " + std::to_string(api >> 22) + "." +
               std::to_string((api >> 12) & 0x3ffu) + "; the OpenDLSS-NR kernels need 1.3 (restart after requesting the "
               "OpenDLSS-NR device features)";
    return c;
  }
  c.code = kCapable;
  c.reason = "supported on " + c.deviceName;
#else
  (void) engine;
  c.code = kNotVulkan;
  c.reason = "OpenDLSS-NR is not available on this platform (desktop Vulkan only)";
#endif
  return c;
}

}  // namespace opendlss_nr
