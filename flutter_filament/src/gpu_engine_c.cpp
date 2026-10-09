/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Engine creation with a GPU preference. Every native engine is
// created here: on desktop Linux and Windows the Vulkan backend gets a
// VulkanPlatformLinux/VulkanPlatformWindows whose only change is the `gpu`
// customization, so the
// preference (explicit, or FILAMENT_GPU / VK_DEVICE_INDEX from the
// environment) reaches Filament's device selection, and the chosen physical
// device can be read back.

#include "gpu_c.h"
#include "gpu_engine_internal.h"
#include "vulkan_features_c.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include <filament/Engine.h>
#include <utils/Panic.h>

#if !defined(__EMSCRIPTEN__) && defined(__linux__) && !defined(__ANDROID__)
#define FLUTTER_FILAMENT_GPU_PLATFORM 1
#include <backend/platforms/VulkanPlatformLinux.h>
using DesktopVulkanPlatform = filament::backend::VulkanPlatformLinux;
#elif defined(_WIN32)
#define FLUTTER_FILAMENT_GPU_PLATFORM 1
#include <backend/platforms/VulkanPlatformWindows.h>
using DesktopVulkanPlatform = filament::backend::VulkanPlatformWindows;
#endif

using namespace filament;

namespace {

struct GpuPreference {
    std::string name;
    int index = -1;
    bool empty() const { return name.empty() && index < 0; }
};

bool allDigits(const char* s) {
    if (!s || !*s) return false;
    for (const char* p = s; *p; ++p) {
        if (*p < '0' || *p > '9') return false;
    }
    return true;
}

/// FILAMENT_GPU (a name substring or an index), then VK_DEVICE_INDEX.
GpuPreference fromEnvironment() {
    GpuPreference pref;
    const char* gpu = std::getenv("FILAMENT_GPU");
    if (gpu && *gpu) {
        if (allDigits(gpu)) {
            pref.index = std::atoi(gpu);
        } else {
            pref.name = gpu;
        }
        return pref;
    }
    const char* index = std::getenv("VK_DEVICE_INDEX");
    if (allDigits(index)) pref.index = std::atoi(index);
    return pref;
}

#if FLUTTER_FILAMENT_GPU_PLATFORM
// Extra Vulkan extensions requested for the engines created from now on (DLSS
// and ray tracing need theirs before the device exists), one entry per
// requester; their union is copied into each platform at creation.
std::mutex gExtraExtensionsMutex;
std::map<std::string, std::pair<std::vector<std::string>, std::vector<std::string>>> gExtraExtensions;

static void appendUnique(std::vector<std::string>& into, const std::vector<std::string>& names) {
    for (const auto& n : names) {
        if (std::find(into.begin(), into.end(), n) == into.end()) into.push_back(n);
    }
}

// Device extensions and feature-structure members requested through
// filament_vulkan_request_device_* (one entry per requester), united at engine creation.
struct FeatureRequest {
    uint32_t sType = 0;
    uint32_t size = 0;
    std::string extension;
    std::vector<uint32_t> fields;
};

struct VulkanRequests {
    std::vector<std::string> extensions;
    std::vector<FeatureRequest> features;
};

std::map<std::string, VulkanRequests> gVulkanRequests;  // guarded by gExtraExtensionsMutex

static void mergeFeature(std::vector<FeatureRequest>& into, const FeatureRequest& request) {
    for (auto& existing : into) {
        if (existing.sType != request.sType) continue;
        existing.size = std::max(existing.size, request.size);
        if (existing.extension.empty()) existing.extension = request.extension;
        for (uint32_t f : request.fields) {
            if (std::find(existing.fields.begin(), existing.fields.end(), f) == existing.fields.end()) {
                existing.fields.push_back(f);
            }
        }
        return;
    }
    into.push_back(request);
}

class PreferredGpuPlatform final : public DesktopVulkanPlatform {
public:
    explicit PreferredGpuPlatform(GpuPreference pref) : mPref(std::move(pref)) {
        std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
        for (const auto& entry : gExtraExtensions) {
            appendUnique(mInstanceExtensions, entry.second.first);
            appendUnique(mDeviceExtensions, entry.second.second);
        }
        for (const auto& entry : gVulkanRequests) {
            appendUnique(mDeviceExtensions, entry.second.extensions);
            for (const auto& feature : entry.second.features) mergeFeature(mFeatures, feature);
        }
    }

    Customization getCustomization() const noexcept override {
        Customization c = DesktopVulkanPlatform::getCustomization();
        if (!mPref.name.empty()) c.gpu.deviceName = utils::CString(mPref.name.c_str());
        if (mPref.index >= 0) c.gpu.index = static_cast<int8_t>(mPref.index);
        c.extraInstanceExtensions = toCStrings(mInstanceExtensions);
        c.extraDeviceExtensions = toCStrings(mDeviceExtensions);
        auto features = utils::FixedCapacityVector<Customization::ExtraDeviceFeature>::with_capacity(mFeatures.size());
        for (const auto& f : mFeatures) {
            Customization::ExtraDeviceFeature feature;
            feature.sType = f.sType;
            feature.size = f.size;
            feature.extension = utils::CString(f.extension.c_str());
            feature.fields = utils::FixedCapacityVector<uint32_t>::with_capacity(f.fields.size());
            for (uint32_t field : f.fields) feature.fields.push_back(field);
            features.push_back(std::move(feature));
        }
        c.extraDeviceFeatures = std::move(features);
        return c;
    }

    bool hasExtraExtensions() const noexcept {
        return !mInstanceExtensions.empty() || !mDeviceExtensions.empty();
    }

private:
    static utils::FixedCapacityVector<utils::CString> toCStrings(const std::vector<std::string>& in) {
        auto out = utils::FixedCapacityVector<utils::CString>::with_capacity(in.size());
        for (const auto& s : in) out.push_back(utils::CString(s.c_str()));
        return out;
    }

    GpuPreference mPref;
    std::vector<std::string> mInstanceExtensions;
    std::vector<std::string> mDeviceExtensions;
    std::vector<FeatureRequest> mFeatures;
};

PreferredGpuPlatform* platformOf(void* engine);

std::mutex gPlatformsMutex;
std::unordered_map<Engine*, PreferredGpuPlatform*> gPlatforms;

PreferredGpuPlatform* platformOf(void* engine) {
    std::lock_guard<std::mutex> lock(gPlatformsMutex);
    auto it = gPlatforms.find(static_cast<Engine*>(engine));
    return it == gPlatforms.end() ? nullptr : it->second;
}
#endif

}  // namespace

void* filament_engine_create_on_gpu(int backend, int feature_level, bool paused,
        const filament_engine_config_t* config, const char* const* feature_names,
        const bool* feature_values, int feature_count, const char* gpu_name, int gpu_index) {
    try {
        Engine::Builder builder;
        auto resolved = static_cast<Engine::Backend>(backend);
        builder.backend(resolved);
        if (feature_level >= 0) {
            builder.featureLevel(static_cast<Engine::FeatureLevel>(feature_level));
        }
        builder.paused(paused);
        Engine::Config cfg;
        if (config) {
            cfg.commandBufferSizeMB = config->command_buffer_size_mb;
            cfg.perRenderPassArenaSizeMB = config->per_render_pass_arena_size_mb;
            cfg.minCommandBufferSizeMB = config->min_command_buffer_size_mb;
            cfg.jobSystemThreadCount = config->job_system_thread_count;
            cfg.preferredShaderLanguage = static_cast<Engine::Config::ShaderLanguage>(config->preferred_shader_language);
            cfg.forceGLES2Context = config->force_gles2_context;
            cfg.gpuContextPriority = static_cast<backend::Platform::GpuContextPriority>(config->gpu_context_priority);
            cfg.materialCacheCapacity = config->material_cache_capacity;
            cfg.stereoscopicEyeCount = static_cast<uint8_t>(config->stereoscopic_eye_count);
            cfg.stereoscopicType = static_cast<backend::StereoscopicType>(config->stereoscopic_type);
            builder.config(&cfg);
        }
        if (feature_names && feature_values && feature_count > 0) {
            for (int i = 0; i < feature_count; ++i) {
                if (feature_names[i]) builder.feature(feature_names[i], feature_values[i]);
            }
        }

#if FLUTTER_FILAMENT_GPU_PLATFORM
        // DEFAULT resolves to Vulkan on desktop Linux and Windows (PlatformFactory.cpp).
        const bool vulkan = resolved == Engine::Backend::VULKAN || resolved == Engine::Backend::DEFAULT;
        PreferredGpuPlatform* platform = nullptr;
        if (vulkan) {
            GpuPreference pref;
            if (gpu_name && *gpu_name) pref.name = gpu_name;
            if (gpu_index >= 0) pref.index = gpu_index;
            if (pref.empty()) pref = fromEnvironment();
            // Filament's own name matching is broken in v1.77.0: its
            // DeviceInfo::name is a string_view into a per-iteration
            // VkPhysicalDeviceProperties, so every name dangles
            // (VulkanPlatform.cpp selectPhysicalDevice). Resolve the name
            // against our enumeration (same loader order) and pass an index.
            if (!pref.name.empty()) {
                const int found = flutter_filament_find_vulkan_device(pref.name.c_str());
                if (found >= 0) {
                    pref.index = found;
                } else {
                    fprintf(stderr, "[flutter_filament] no Vulkan device matches \"%s\"; using the default device\n", pref.name.c_str());
                }
                pref.name.clear();
            }
            // Filament aborts on an index past its device list; drop it instead.
            if (pref.index >= 0 && pref.index >= flutter_filament_cached_vulkan_device_count()) {
                fprintf(stderr, "[flutter_filament] GPU index %d is out of range; using the default device\n", pref.index);
                pref.index = -1;
            }
            platform = new PreferredGpuPlatform(pref);
            builder.backend(Engine::Backend::VULKAN);
            builder.platform(platform);
        }
        Engine* engine = builder.build();
        if (platform) {
            if (engine) {
                std::lock_guard<std::mutex> lock(gPlatformsMutex);
                gPlatforms[engine] = platform;
            } else {
                delete platform;
            }
        }
        return engine;
#else
        (void) gpu_name;
        (void) gpu_index;
        return builder.build();
#endif
    } catch (const utils::Panic& e) {
        fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());
        return nullptr;
    } catch (const std::exception& e) {
        fprintf(stderr, "[flutter_filament] engine creation failed: %s\n", e.what());
        return nullptr;
    }
}

int filament_engine_get_gpu_name(void* engine, char* out, int capacity) {
    if (!out || capacity <= 0) return 0;
    out[0] = '\0';
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = nullptr;
    {
        std::lock_guard<std::mutex> lock(gPlatformsMutex);
        auto it = gPlatforms.find(static_cast<Engine*>(engine));
        if (it != gPlatforms.end()) platform = it->second;
    }
    if (!platform) return 0;
    VkPhysicalDevice device = platform->getPhysicalDevice();
    if (device == VK_NULL_HANDLE) return 0;
    // bluevk is bound to this engine's own instance by Filament.
    VkPhysicalDeviceProperties props{};
    bluevk::vkGetPhysicalDeviceProperties(device, &props);
    std::strncpy(out, props.deviceName, static_cast<size_t>(capacity) - 1);
    out[capacity - 1] = '\0';
    return static_cast<int>(std::strlen(out));
#else
    (void) engine;
    return 0;
#endif
}

bool filament_engine_get_gpu_memory(void* engine, filament_gpu_memory_t* out) {
    if (!out) return false;
    *out = filament_gpu_memory_t{};
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = nullptr;
    {
        std::lock_guard<std::mutex> lock(gPlatformsMutex);
        auto it = gPlatforms.find(static_cast<Engine*>(engine));
        if (it != gPlatforms.end()) platform = it->second;
    }
    if (!platform) return false;
    VkPhysicalDevice device = platform->getPhysicalDevice();
    if (device == VK_NULL_HANDLE) return false;
    // The budget struct may only be chained when the device supports the
    // extension (it need not be enabled for a physical-device query).
    uint32_t extensionCount = 0;
    if (bluevk::vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, nullptr) != VK_SUCCESS) {
        return false;
    }
    std::vector<VkExtensionProperties> extensions(extensionCount);
    bluevk::vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, extensions.data());
    bool supported = false;
    for (const auto& e : extensions) {
        if (std::strcmp(e.extensionName, VK_EXT_MEMORY_BUDGET_EXTENSION_NAME) == 0) supported = true;
    }
    // Filament's instance is Vulkan 1.1, so the core entry point is valid.
    if (!supported || !bluevk::vkGetPhysicalDeviceMemoryProperties2) return false;
    VkPhysicalDeviceMemoryBudgetPropertiesEXT budget{};
    budget.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT;
    VkPhysicalDeviceMemoryProperties2 props{};
    props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2;
    props.pNext = &budget;
    bluevk::vkGetPhysicalDeviceMemoryProperties2(device, &props);
    for (uint32_t i = 0; i < props.memoryProperties.memoryHeapCount; ++i) {
        const VkMemoryHeap& heap = props.memoryProperties.memoryHeaps[i];
        if ((heap.flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) == 0) continue;
        out->device_local_usage += budget.heapUsage[i];
        out->device_local_budget += budget.heapBudget[i];
        out->device_local_size += heap.size;
        out->heap_count++;
    }
    return out->heap_count > 0;
#else
    (void) engine;
    return false;
#endif
}

void flutter_filament_release_gpu_platform(Engine* engine) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = nullptr;
    {
        std::lock_guard<std::mutex> lock(gPlatformsMutex);
        auto it = gPlatforms.find(engine);
        if (it == gPlatforms.end()) return;
        platform = it->second;
        gPlatforms.erase(it);
    }
    delete platform;
#else
    (void) engine;
#endif
}

int filament_gpu_live_platform_count(void) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    std::lock_guard<std::mutex> lock(gPlatformsMutex);
    return static_cast<int>(gPlatforms.size());
#else
    return 0;
#endif
}

void flutter_filament_set_extra_vulkan_extensions(const char* requester,
        const std::vector<std::string>& instanceExtensions,
        const std::vector<std::string>& deviceExtensions) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
    const std::string key = requester ? requester : "";
    if (instanceExtensions.empty() && deviceExtensions.empty()) {
        gExtraExtensions.erase(key);
    } else {
        gExtraExtensions[key] = { instanceExtensions, deviceExtensions };
    }
#else
    (void) requester;
    (void) instanceExtensions;
    (void) deviceExtensions;
#endif
}

bool flutter_filament_engine_vulkan_handles(void* engine, void** outInstance, void** outPhysicalDevice,
        void** outDevice, bool* hadExtraExtensions) {
    if (outInstance) *outInstance = nullptr;
    if (outPhysicalDevice) *outPhysicalDevice = nullptr;
    if (outDevice) *outDevice = nullptr;
    if (hadExtraExtensions) *hadExtraExtensions = false;
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = nullptr;
    {
        std::lock_guard<std::mutex> lock(gPlatformsMutex);
        auto it = gPlatforms.find(static_cast<Engine*>(engine));
        if (it != gPlatforms.end()) platform = it->second;
    }
    if (!platform || platform->getDevice() == VK_NULL_HANDLE) return false;
    if (outInstance) *outInstance = platform->getInstance();
    if (outPhysicalDevice) *outPhysicalDevice = platform->getPhysicalDevice();
    if (outDevice) *outDevice = platform->getDevice();
    if (hadExtraExtensions) *hadExtraExtensions = platform->hasExtraExtensions();
    return true;
#else
    (void) engine;
    return false;
#endif
}

void filament_vulkan_request_device_extension(const char* requester, const char* name) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    if (!name || !*name) return;
    std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
    appendUnique(gVulkanRequests[requester ? requester : ""].extensions, { name });
#else
    (void) requester;
    (void) name;
#endif
}

void filament_vulkan_request_device_feature(const char* requester, uint32_t sType, uint32_t structSize,
        uint32_t fieldOffset, const char* extension) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    FeatureRequest request;
    request.sType = sType;
    request.size = structSize;
    request.extension = extension ? extension : "";
    request.fields.push_back(fieldOffset);
    std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
    mergeFeature(gVulkanRequests[requester ? requester : ""].features, request);
#else
    (void) requester;
    (void) sType;
    (void) structSize;
    (void) fieldOffset;
    (void) extension;
#endif
}

void filament_vulkan_clear_requests(const char* requester) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
    if (requester) {
        gVulkanRequests.erase(requester);
    } else {
        gVulkanRequests.clear();
    }
#else
    (void) requester;
#endif
}

bool filament_vulkan_device_feature_enabled(void* engine, uint32_t sType, uint32_t fieldOffset) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    return platform && platform->getDevice() != VK_NULL_HANDLE &&
            platform->isExtraDeviceFeatureEnabled(sType, fieldOffset);
#else
    (void) engine;
    (void) sType;
    (void) fieldOffset;
    return false;
#endif
}

bool filament_vulkan_device_extension_enabled(void* engine, const char* name) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    return platform && name && platform->getDevice() != VK_NULL_HANDLE &&
            platform->isDeviceExtensionEnabled(name);
#else
    (void) engine;
    (void) name;
    return false;
#endif
}
