/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Internal (not exported): the NVIDIA NGX runtime shared by the DLSS features
// (Super Resolution in dlss_c.cpp, Ray Reconstruction in dlss_rr_c.cpp): the
// runtime folder lookup, NGX initialised once per engine (per VkDevice) and
// reference counted, and the NGX result names. Compiled only with the fetched
// SDK (FLUTTER_FILAMENT_DLSS=1); nothing here is part of the FFI surface.

#ifndef FLUTTER_FILAMENT_NGX_INTERNAL_H
#define FLUTTER_FILAMENT_NGX_INTERNAL_H

#if defined(FLUTTER_FILAMENT_DLSS) && FLUTTER_FILAMENT_DLSS && !defined(__EMSCRIPTEN__) && \
        (defined(_WIN32) || (defined(__linux__) && !defined(__ANDROID__)))
#define FLUTTER_FILAMENT_DLSS_ENABLED 1
#else
#define FLUTTER_FILAMENT_DLSS_ENABLED 0
#endif

#if FLUTTER_FILAMENT_DLSS_ENABLED

#include <bluevk/BlueVK.h>

#include <nvsdk_ngx.h>
#include <nvsdk_ngx_vk.h>

#include <cstdint>
#include <mutex>
#include <string>

namespace filament {
class Engine;
}

namespace flutter_filament::ngx {

// Lumina's NGX project id: stable across releases, identifies the integration to the driver
// (no account or registration is attached to it).
constexpr const char* kProjectId = "a1f0c3a0-4e7b-4d4a-9b2e-6c3f1d8e2b11";
constexpr const char* kEngineVersion = "lumina-filament-1.77.2";

const char* resultName(NVSDK_NGX_Result r);
std::string describe(const char* what, NVSDK_NGX_Result r);
NVSDK_NGX_PerfQuality_Value toPerfQuality(uint8_t quality);

// Guards everything below.
std::mutex& mutex();

// Where the runtime libraries are looked up first (an SDK root or the folder itself); empty
// forgets the hint. Takes effect at the next runtimeDir() call that finds nothing cached.
void setRuntimeDirHint(const char* dir);

// The folder holding the NGX DLSS runtime (`nvngx_dlss` on Windows,
// `libnvidia-ngx-dlss.so.*` on Linux): the hint, LUMINA_DLSS_DIR (the folder or an SDK
// root), the executable's folder, then build/dlss-sdk under the working directory. Cached;
// empty when none is found.
std::string const& runtimeDir();

// Whether the runtime folder holds the library of one feature: "nvngx_dlss",
// "nvngx_dlssd" (Ray Reconstruction), "nvngx_dlssg" (Frame Generation); on Linux the
// matching libnvidia-ngx-*.so.
bool hasFeatureLibrary(const char* windowsStem);

bool hasNvidiaVulkanDevice();

// NGX initialised for an engine's Vulkan device and its capability parameters.
struct Device {
    VkDevice device = VK_NULL_HANDLE;
    NVSDK_NGX_Parameter* capabilities = nullptr;
    int refs = 0;
};

// Initialises NGX for the engine (first call) or adds a reference. Returns null with
// `error` set when the engine is not desktop Vulkan, was created without the NGX
// extensions, the runtime is missing or NGX declines. Call with mutex() held.
Device* acquire(filament::Engine* engine, std::string& error);

// Drops a reference; the last one shuts NGX down for the device (the GPU must be idle).
// Call with mutex() held.
void release(filament::Engine* engine);

} // namespace flutter_filament::ngx

#endif // FLUTTER_FILAMENT_DLSS_ENABLED

#endif // FLUTTER_FILAMENT_NGX_INTERNAL_H
