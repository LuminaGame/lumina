/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_VULKAN_FEATURES_C_H
#define FLUTTER_FILAMENT_VULKAN_FEATURES_C_H

#include <stdbool.h>
#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Vulkan device extensions and feature structures for the engines created from now on
// (desktop Vulkan only; a device cannot gain them later). Requests are kept per requester
// ("post_pass", "dlss_fg", ...) and united at engine creation. Filament enables a requested
// feature member only when the device supports it; read the outcome back from the engine.

// Asks for a device extension (skipped with a log line when the device lacks it).
FFI_PLUGIN_EXPORT void filament_vulkan_request_device_extension(const char* requester, const char* name);

// Asks for one VkBool32 member of a feature structure: `sType` its VkStructureType,
// `structSize` sizeof the structure, `fieldOffset` the member's byte offset, `extension`
// the device extension the structure belongs to (NULL or empty for core structures). The
// structure is chained only when that extension is enabled.
FFI_PLUGIN_EXPORT void filament_vulkan_request_device_feature(const char* requester, uint32_t sType,
        uint32_t structSize, uint32_t fieldOffset, const char* extension);

// Forgets every extension and feature `requester` asked for (NULL forgets all requesters).
FFI_PLUGIN_EXPORT void filament_vulkan_clear_requests(const char* requester);

// Whether the engine's device was created with the requested feature member enabled.
// False on other backends and platforms.
FFI_PLUGIN_EXPORT bool filament_vulkan_device_feature_enabled(void* engine, uint32_t sType, uint32_t fieldOffset);

// Whether the engine's device was created with the device extension enabled.
FFI_PLUGIN_EXPORT bool filament_vulkan_device_extension_enabled(void* engine, const char* name);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_VULKAN_FEATURES_C_H
