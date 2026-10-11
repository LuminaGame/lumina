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

#include "external_vulkan_c.h"
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
#include <unordered_set>
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
#elif defined(__ANDROID__)
// Android gets the same platform subclass, so the device name, memory budget and the
// extension / feature requests (OpenXR, for one) work there too.
#define FLUTTER_FILAMENT_GPU_PLATFORM 1
#include <android/log.h>
#include <backend/platforms/VulkanPlatformAndroid.h>
using DesktopVulkanPlatform = filament::backend::VulkanPlatformAndroid;
#endif

// Engine creation messages: logcat on Android (stderr goes nowhere there), stderr elsewhere.
#if defined(__ANDROID__)
#define FF_ENGINE_LOG(...) __android_log_print(ANDROID_LOG_WARN, "flutter_filament", __VA_ARGS__)
#else
#define FF_ENGINE_LOG(...) fprintf(stderr, __VA_ARGS__)
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
    uint32_t apiVersion = 0;
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

/// A swapchain whose images belong to a filament_external_swapchain_provider.
struct ExternalSwapChain : filament::backend::Platform::SwapChain {
    filament_external_swapchain_provider provider{};
};

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
            mApiVersion = std::max(mApiVersion, entry.second.apiVersion);
        }
    }

    /// An engine on someone else's instance and device
    /// (filament_engine_create_external_vulkan): no GPU preference, and its
    /// external swapchains hand their images back in the layout they came in.
    explicit PreferredGpuPlatform(const filament_external_vulkan_context& context) : mExternal(true) {
        mShared.instance = static_cast<VkInstance>(context.instance);
        mShared.physicalDevice = static_cast<VkPhysicalDevice>(context.physical_device);
        mShared.logicalDevice = static_cast<VkDevice>(context.device);
        mShared.graphicsQueueFamilyIndex = context.queue_family;
        mShared.graphicsQueueIndex = context.queue_index;
        mShared.multiviewSupported = context.multiview;
    }

    bool isExternal() const noexcept { return mExternal; }
    VulkanSharedContext* sharedContext() noexcept { return &mShared; }

    /// Registers a provider copy that the next createSwapChain(nativeWindow)
    /// call recognises as an external swapchain.
    void expectExternalSwapChain(ExternalSwapChain* swapChain) {
        std::lock_guard<std::mutex> lock(mSwapChainsMutex);
        mExternalSwapChains.insert(swapChain);
    }

    SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags, VkExtent2D extent) override {
        if (ExternalSwapChain* external = findExternal(nativeWindow)) return external;
        return DesktopVulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    }

    SwapChainBundle getSwapChainBundle(SwapChainPtr handle) override {
        ExternalSwapChain* external = findExternal(handle);
        if (!external) return DesktopVulkanPlatform::getSwapChainBundle(handle);
        const filament_external_swapchain_provider& p = external->provider;
        std::vector<uint64_t> colors(p.image_count, 0);
        uint64_t depth = 0;
        if (p.get_images) p.get_images(p.user_data, colors.data(), &depth);
        SwapChainBundle bundle;
        bundle.colors = utils::FixedCapacityVector<VkImage>::with_capacity(colors.size());
        for (uint64_t image : colors) bundle.colors.push_back(toVkImage(image));
        bundle.depth = toVkImage(depth);
        bundle.colorFormat = static_cast<VkFormat>(p.color_format);
        bundle.depthFormat = static_cast<VkFormat>(p.depth_format);
        bundle.extent = {p.width, p.height};
        bundle.layerCount = p.layer_count == 0 ? 1 : p.layer_count;
        return bundle;
    }

    VkResult acquire(SwapChainPtr handle, ImageSyncData* out) override {
        ExternalSwapChain* external = findExternal(handle);
        if (!external) return DesktopVulkanPlatform::acquire(handle, out);
        uint32_t index = 0;
        const VkResult result = static_cast<VkResult>(
                external->provider.acquire ? external->provider.acquire(external->provider.user_data, &index)
                                           : VK_ERROR_INITIALIZATION_FAILED);
        out->imageIndex = index;
        // The provider waited for the image on the CPU (xrWaitSwapchainImage).
        out->imageReadySemaphore = VK_NULL_HANDLE;
        return result;
    }

    VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override {
        ExternalSwapChain* external = findExternal(handle);
        if (!external) return DesktopVulkanPlatform::present(handle, index, finishedDrawing);
        // Nothing presents through Vulkan here: consume the semaphore with an empty submit on
        // Filament's queue (this runs on the driver thread, ordered after the frame's
        // commands), then hand the image back to its owner.
        if (finishedDrawing != VK_NULL_HANDLE) {
            const VkPipelineStageFlags stage = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT;
            VkSubmitInfo submit{};
            submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submit.waitSemaphoreCount = 1;
            submit.pWaitSemaphores = &finishedDrawing;
            submit.pWaitDstStageMask = &stage;
            bluevk::vkQueueSubmit(getGraphicsQueue(), 1, &submit, VK_NULL_HANDLE);
        }
        return static_cast<VkResult>(external->provider.present
                ? external->provider.present(external->provider.user_data, index) : VK_SUCCESS);
    }

    bool hasResized(SwapChainPtr handle) override {
        return findExternal(handle) ? false : DesktopVulkanPlatform::hasResized(handle);
    }

    bool isProtected(SwapChainPtr handle) override {
        return findExternal(handle) ? false : DesktopVulkanPlatform::isProtected(handle);
    }

    VkResult recreate(SwapChainPtr handle) override {
        return findExternal(handle) ? VK_SUCCESS : DesktopVulkanPlatform::recreate(handle);
    }

    void destroy(SwapChainPtr handle) override {
        ExternalSwapChain* external = findExternal(handle);
        if (!external) {
            DesktopVulkanPlatform::destroy(handle);
            return;
        }
        {
            std::lock_guard<std::mutex> lock(mSwapChainsMutex);
            mExternalSwapChains.erase(external);
        }
        if (external->provider.destroy) external->provider.destroy(external->provider.user_data);
        delete external;
    }

    Customization getCustomization() const noexcept override {
        Customization c = DesktopVulkanPlatform::getCustomization();
        if (mExternal) {
            // OpenXR hands its images in COLOR_ATTACHMENT_OPTIMAL and takes them back so.
            c.transitionSwapChainImageLayoutForPresent = false;
            return c;
        }
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
        c.apiVersion = mApiVersion;
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

    static VkImage toVkImage(uint64_t handle) {
#if defined(__LP64__) || defined(_WIN64)
        return reinterpret_cast<VkImage>(static_cast<uintptr_t>(handle));
#else
        return static_cast<VkImage>(handle);
#endif
    }

    ExternalSwapChain* findExternal(void* pointer) {
        if (!mExternal || !pointer) return nullptr;
        std::lock_guard<std::mutex> lock(mSwapChainsMutex);
        auto it = mExternalSwapChains.find(static_cast<ExternalSwapChain*>(pointer));
        return it == mExternalSwapChains.end() ? nullptr : *it;
    }

    bool mExternal = false;
    VulkanSharedContext mShared{};
    std::mutex mSwapChainsMutex;
    std::unordered_set<ExternalSwapChain*> mExternalSwapChains;

    GpuPreference mPref;
    std::vector<std::string> mInstanceExtensions;
    std::vector<std::string> mDeviceExtensions;
    std::vector<FeatureRequest> mFeatures;
    uint32_t mApiVersion = 0;
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

void fillEngineConfig(Engine::Config& cfg, const filament_engine_config_t& config) {
    cfg.commandBufferSizeMB = config.command_buffer_size_mb;
    cfg.perRenderPassArenaSizeMB = config.per_render_pass_arena_size_mb;
    cfg.minCommandBufferSizeMB = config.min_command_buffer_size_mb;
    cfg.jobSystemThreadCount = config.job_system_thread_count;
    cfg.preferredShaderLanguage = static_cast<Engine::Config::ShaderLanguage>(config.preferred_shader_language);
    cfg.forceGLES2Context = config.force_gles2_context;
    cfg.gpuContextPriority = static_cast<backend::Platform::GpuContextPriority>(config.gpu_context_priority);
    cfg.materialCacheCapacity = config.material_cache_capacity;
    cfg.stereoscopicEyeCount = static_cast<uint8_t>(config.stereoscopic_eye_count);
    cfg.stereoscopicType = static_cast<backend::StereoscopicType>(config.stereoscopic_type);
}

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
            fillEngineConfig(cfg, *config);
            builder.config(&cfg);
        }
        if (feature_names && feature_values && feature_count > 0) {
            for (int i = 0; i < feature_count; ++i) {
                if (feature_names[i]) builder.feature(feature_names[i], feature_values[i]);
            }
        }

#if FLUTTER_FILAMENT_GPU_PLATFORM
        // DEFAULT resolves to Vulkan on desktop Linux and Windows (PlatformFactory.cpp), and
        // flutter_filament picks Vulkan for it on Android as well (Filament would pick GLES).
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
                    FF_ENGINE_LOG("[flutter_filament] no Vulkan device matches \"%s\"; using the default device\n", pref.name.c_str());
                }
                pref.name.clear();
            }
            // Filament aborts on an index past its device list; drop it instead.
            if (pref.index >= 0 && pref.index >= flutter_filament_cached_vulkan_device_count()) {
                FF_ENGINE_LOG("[flutter_filament] GPU index %d is out of range; using the default device\n", pref.index);
                pref.index = -1;
            }
            platform = new PreferredGpuPlatform(pref);
            builder.backend(Engine::Backend::VULKAN);
            builder.platform(platform);
        }
        Engine* engine = nullptr;
        try {
            engine = builder.build();
        } catch (const utils::Panic& e) {
            if (!platform) throw;
            FF_ENGINE_LOG("[flutter_filament] Vulkan engine creation failed: %s\n", e.what());
        }
        if (platform) {
            if (engine) {
                std::lock_guard<std::mutex> lock(gPlatformsMutex);
                gPlatforms[engine] = platform;
            } else {
                delete platform;
            }
        }
#if defined(__ANDROID__)
        // DEFAULT means Vulkan on Android too; a device without a usable Vulkan driver
        // falls back to OpenGL ES, and says so.
        if (!engine && resolved == Engine::Backend::DEFAULT) {
            FF_ENGINE_LOG("[flutter_filament] Vulkan is not available; falling back to OpenGL ES\n");
            builder.platform(nullptr);
            builder.backend(Engine::Backend::OPENGL);
            engine = builder.build();
        }
#endif
        return engine;
#else
        (void) gpu_name;
        (void) gpu_index;
        return builder.build();
#endif
    } catch (const utils::Panic& e) {
        FF_ENGINE_LOG("[Filament C++ Panic (Handled Safely)]: %s\n", e.what());
        return nullptr;
    } catch (const std::exception& e) {
        FF_ENGINE_LOG("[flutter_filament] engine creation failed: %s\n", e.what());
        return nullptr;
    }
}

void* filament_engine_create_external_vulkan(const filament_external_vulkan_context* context,
        int feature_level, const filament_engine_config_t* config) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    if (!context || !context->instance || !context->physical_device || !context->device) return nullptr;
    PreferredGpuPlatform* platform = nullptr;
    try {
        // Filament refuses a GPU preference next to a shared context: the device is chosen.
        const GpuPreference ignored = fromEnvironment();
        if (!ignored.empty()) {
            FF_ENGINE_LOG("[flutter_filament] FILAMENT_GPU / VK_DEVICE_INDEX ignored: the engine adopts an external Vulkan device\n");
        }
        platform = new PreferredGpuPlatform(*context);
        Engine::Builder builder;
        builder.backend(Engine::Backend::VULKAN);
        builder.platform(platform);
        builder.sharedContext(platform->sharedContext());
        if (feature_level >= 0) builder.featureLevel(static_cast<Engine::FeatureLevel>(feature_level));
        Engine::Config cfg;
        if (config) {
            fillEngineConfig(cfg, *config);
            builder.config(&cfg);
        }
        Engine* engine = builder.build();
        if (!engine) {
            delete platform;
            return nullptr;
        }
        std::lock_guard<std::mutex> lock(gPlatformsMutex);
        gPlatforms[engine] = platform;
        return engine;
    } catch (const utils::Panic& e) {
        FF_ENGINE_LOG("[flutter_filament] external Vulkan engine creation failed: %s\n", e.what());
    } catch (const std::exception& e) {
        FF_ENGINE_LOG("[flutter_filament] external Vulkan engine creation failed: %s\n", e.what());
    }
    delete platform;
    return nullptr;
#else
    (void) context;
    (void) feature_level;
    (void) config;
    return nullptr;
#endif
}

bool filament_engine_get_vulkan_context(void* engine, filament_external_vulkan_context* out) {
    if (!out) return false;
    *out = filament_external_vulkan_context{};
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    if (!platform || platform->getDevice() == VK_NULL_HANDLE) return false;
    out->instance = platform->getInstance();
    out->physical_device = platform->getPhysicalDevice();
    out->device = platform->getDevice();
    out->queue_family = platform->getGraphicsQueueFamilyIndex();
    out->queue_index = platform->getGraphicsQueueIndex();
    out->multiview = static_cast<Engine*>(engine)->isStereoSupported(backend::StereoscopicType::MULTIVIEW);
    return true;
#else
    (void) engine;
    return false;
#endif
}

bool filament_engine_is_external_vulkan(void* engine) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    return platform && platform->isExternal();
#else
    (void) engine;
    return false;
#endif
}

void* filament_swap_chain_create_external(void* engine, const filament_external_swapchain_provider* provider) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    if (!platform || !platform->isExternal() || !provider || provider->image_count == 0) return nullptr;
    try {
        auto* swapChain = new ExternalSwapChain();
        swapChain->provider = *provider;
        platform->expectExternalSwapChain(swapChain);
        // The provider copy is the "native window": the platform recognises it in createSwapChain.
        return static_cast<Engine*>(engine)->createSwapChain(swapChain, 0);
    } catch (const utils::Panic& e) {
        FF_ENGINE_LOG("[flutter_filament] external swapchain creation failed: %s\n", e.what());
        return nullptr;
    }
#else
    (void) engine;
    (void) provider;
    return nullptr;
#endif
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

void filament_vulkan_request_api_version(const char* requester, uint32_t version) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    std::lock_guard<std::mutex> lock(gExtraExtensionsMutex);
    gVulkanRequests[requester ? requester : ""].apiVersion = version;
#else
    (void) requester;
    (void) version;
#endif
}

uint32_t filament_vulkan_api_version(void* engine) {
#if FLUTTER_FILAMENT_GPU_PLATFORM
    PreferredGpuPlatform* platform = platformOf(engine);
    return platform && platform->getDevice() != VK_NULL_HANDLE ? platform->getApiVersion() : 0;
#else
    (void) engine;
    return 0;
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
