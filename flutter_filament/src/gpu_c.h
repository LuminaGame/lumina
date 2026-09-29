/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_GPU_C_H
#define FLUTTER_FILAMENT_GPU_C_H

#include <stdint.h>
#include <stdbool.h>

#include "engine_c.h"

#ifdef __cplusplus
extern "C" {
#endif

/// One Vulkan physical device, in the loader's enumeration order (the index
/// space Filament's GPU preference uses). `type` is VkPhysicalDeviceType:
/// 0 other, 1 integrated, 2 discrete, 3 virtual, 4 cpu.
typedef struct {
    char name[256];
    int32_t type;
    uint32_t vendor_id;
    uint32_t device_id;
    uint32_t api_version;
    int32_t index;
} filament_gpu_info_t;

/// Enumerates the Vulkan devices (through the system loader, independently of
/// any engine) and returns how many there are; 0 when Vulkan is unavailable.
FFI_PLUGIN_EXPORT int filament_vulkan_device_count(void);

/// Fills [out] with device [index] of the last enumeration. False when out of
/// range.
FFI_PLUGIN_EXPORT bool filament_vulkan_device_info(int index, filament_gpu_info_t* out);

/// `filament_engine_create_ex` with a GPU preference for the Vulkan backend:
/// [gpu_name] is a device-name substring (NULL or "" for none), [gpu_index] a
/// device index (-1 for none). With neither, the environment decides
/// (`FILAMENT_GPU`, a name or an index, then `VK_DEVICE_INDEX`), and with
/// nothing there Filament's own choice. Ignored by non-Vulkan backends.
FFI_PLUGIN_EXPORT void* filament_engine_create_on_gpu(int backend, int feature_level, bool paused,
        const filament_engine_config_t* config, const char* const* feature_names,
        const bool* feature_values, int feature_count, const char* gpu_name, int gpu_index);

/// Writes the name of the physical device [engine] renders on into [out]
/// (NUL-terminated, at most [capacity] bytes) and returns its length; 0 for a
/// non-Vulkan engine.
FFI_PLUGIN_EXPORT int filament_engine_get_gpu_name(void* engine, char* out, int capacity);

/// Device-local memory of the GPU an engine renders on, as `VK_EXT_memory_budget`
/// reports it. `device_local_usage` is this *process's* usage of
/// the device-local heaps, `device_local_budget` what the driver says the
/// process can use, `device_local_size` the heaps' size; all bytes, summed
/// over every `VK_MEMORY_HEAP_DEVICE_LOCAL_BIT` heap.
typedef struct {
    uint64_t device_local_usage;
    uint64_t device_local_budget;
    uint64_t device_local_size;
    int32_t heap_count;
} filament_gpu_memory_t;

/// Fills [out] for a Vulkan [engine] whose device supports
/// `VK_EXT_memory_budget`; false otherwise (OpenGL, noop, the web, no
/// extension).
FFI_PLUGIN_EXPORT bool filament_engine_get_gpu_memory(void* engine, filament_gpu_memory_t* out);

/// How many GPU-preference platforms are alive (one per Vulkan engine not yet
/// destroyed); lets tests prove none outlives its engine.
FFI_PLUGIN_EXPORT int filament_gpu_live_platform_count(void);

#ifdef __cplusplus
}

namespace filament { class Engine; }

/// The loader index of the first Vulkan device whose name contains [name],
/// or -1. Enumerates once and caches, so engine creation stays cheap.
int flutter_filament_find_vulkan_device(const char* name);

/// How many Vulkan devices the cached enumeration found.
int flutter_filament_cached_vulkan_device_count();

/// Releases the Vulkan platform [filament_engine_create_on_gpu] made for
/// [engine]; called by `filament_engine_destroy` after `Engine::destroy`.
void flutter_filament_release_gpu_platform(filament::Engine* engine);
#endif

#endif  // FLUTTER_FILAMENT_GPU_C_H
