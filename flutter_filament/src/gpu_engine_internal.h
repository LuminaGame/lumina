/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Internal (not exported) helpers shared between the GPU-selecting engine
// factory in gpu_engine_c.cpp and the Vulkan-only features built on it
// (dlss_c.cpp). Nothing here is part of the FFI surface.

#ifndef FLUTTER_FILAMENT_GPU_ENGINE_INTERNAL_H
#define FLUTTER_FILAMENT_GPU_ENGINE_INTERNAL_H

#include <string>
#include <vector>

/// Extra Vulkan instance / device extensions every engine created from now on
/// asks its platform for (unavailable ones are skipped by Filament with a log
/// line). Requests are kept per `requester` ("dlss", "ray_tracing", ...) and
/// united at engine creation, so the order of the requests does not matter;
/// empty lists clear that requester's entry.
void flutter_filament_set_extra_vulkan_extensions(const char* requester,
        const std::vector<std::string>& instanceExtensions,
        const std::vector<std::string>& deviceExtensions);

/// The Vulkan objects behind an engine created through
/// filament_engine_create_on_gpu (desktop Vulkan backend only). Returns false
/// for engines on other backends or platforms. `hadExtraExtensions` tells
/// whether the engine was created while extra extensions were requested.
bool flutter_filament_engine_vulkan_handles(void* engine, void** outInstance, void** outPhysicalDevice,
        void** outDevice, bool* hadExtraExtensions);

#endif // FLUTTER_FILAMENT_GPU_ENGINE_INTERNAL_H
