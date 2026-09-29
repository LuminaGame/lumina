/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Vulkan device enumeration for the GPU picker. It talks to the
// system loader directly instead of through bluevk: bluevk's function
// pointers are process-wide and bound to the running engine's instance, and
// rebinding them to a throwaway instance while an engine renders is unsafe.

#include "gpu_c.h"

#include <cstring>
#include <mutex>
#include <vector>

#if !defined(__EMSCRIPTEN__) && (defined(__linux__) || defined(_WIN32))
#define FLUTTER_FILAMENT_VULKAN_ENUMERATION 1
#endif

#if FLUTTER_FILAMENT_VULKAN_ENUMERATION
#define VK_NO_PROTOTYPES 1
#include <vulkan/vulkan.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif
#endif

namespace {

std::mutex gMutex;
std::vector<filament_gpu_info_t> gDevices;

#if FLUTTER_FILAMENT_VULKAN_ENUMERATION
PFN_vkGetInstanceProcAddr loadLoader() {
    static PFN_vkGetInstanceProcAddr getProc = [] {
#if defined(_WIN32)
        HMODULE lib = LoadLibraryA("vulkan-1.dll");
        return lib ? reinterpret_cast<PFN_vkGetInstanceProcAddr>(GetProcAddress(lib, "vkGetInstanceProcAddr")) : nullptr;
#else
        void* lib = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL);
        if (!lib) lib = dlopen("libvulkan.so", RTLD_NOW | RTLD_LOCAL);
        return lib ? reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(lib, "vkGetInstanceProcAddr")) : nullptr;
#endif
    }();
    return getProc;
}

std::vector<filament_gpu_info_t> enumerate() {
    std::vector<filament_gpu_info_t> out;
    auto getProc = loadLoader();
    if (!getProc) return out;
    auto createInstance = reinterpret_cast<PFN_vkCreateInstance>(getProc(nullptr, "vkCreateInstance"));
    if (!createInstance) return out;

    VkApplicationInfo app{};
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "flutter_filament device list";
    app.apiVersion = VK_API_VERSION_1_1;
    VkInstanceCreateInfo info{};
    info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    info.pApplicationInfo = &app;
    VkInstance instance = VK_NULL_HANDLE;
    if (createInstance(&info, nullptr, &instance) != VK_SUCCESS || instance == VK_NULL_HANDLE) return out;

    auto destroyInstance = reinterpret_cast<PFN_vkDestroyInstance>(getProc(instance, "vkDestroyInstance"));
    auto enumerateDevices = reinterpret_cast<PFN_vkEnumeratePhysicalDevices>(getProc(instance, "vkEnumeratePhysicalDevices"));
    auto getProperties = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties>(getProc(instance, "vkGetPhysicalDeviceProperties"));
    if (enumerateDevices && getProperties) {
        uint32_t count = 0;
        enumerateDevices(instance, &count, nullptr);
        std::vector<VkPhysicalDevice> devices(count);
        if (count > 0 && enumerateDevices(instance, &count, devices.data()) == VK_SUCCESS) {
            for (uint32_t i = 0; i < count; ++i) {
                VkPhysicalDeviceProperties props{};
                getProperties(devices[i], &props);
                filament_gpu_info_t g{};
                std::strncpy(g.name, props.deviceName, sizeof(g.name) - 1);
                g.type = static_cast<int32_t>(props.deviceType);
                g.vendor_id = props.vendorID;
                g.device_id = props.deviceID;
                g.api_version = props.apiVersion;
                g.index = static_cast<int32_t>(i);
                out.push_back(g);
            }
        }
    }
    if (destroyInstance) destroyInstance(instance, nullptr);
    return out;
}
#endif

}  // namespace

int filament_vulkan_device_count(void) {
#if FLUTTER_FILAMENT_VULKAN_ENUMERATION
    auto devices = enumerate();
    std::lock_guard<std::mutex> lock(gMutex);
    gDevices = std::move(devices);
    return static_cast<int>(gDevices.size());
#else
    return 0;
#endif
}

bool filament_vulkan_device_info(int index, filament_gpu_info_t* out) {
    std::lock_guard<std::mutex> lock(gMutex);
    if (!out || index < 0 || index >= static_cast<int>(gDevices.size())) return false;
    *out = gDevices[static_cast<size_t>(index)];
    return true;
}

/// The cached device list, enumerated on first use: engine creation must not
/// create a throwaway VkInstance each time (each one makes the NVIDIA driver
/// keep ~10 MB).
static void ensureEnumerated() {
    {
        std::lock_guard<std::mutex> lock(gMutex);
        if (!gDevices.empty()) return;
    }
    filament_vulkan_device_count();
}

int flutter_filament_find_vulkan_device(const char* name) {
    if (!name || !*name) return -1;
    ensureEnumerated();
    std::lock_guard<std::mutex> lock(gMutex);
    for (auto const& d : gDevices) {
        if (std::strstr(d.name, name)) return d.index;
    }
    return -1;
}

int flutter_filament_cached_vulkan_device_count() {
    ensureEnumerated();
    std::lock_guard<std::mutex> lock(gMutex);
    return static_cast<int>(gDevices.size());
}
