/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_DEBUG_REGISTRY_C_H
#define FLUTTER_FILAMENT_DEBUG_REGISTRY_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef FFI_PLUGIN_EXPORT
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void* filament_engine_get_debug_registry(void* engine);

FFI_PLUGIN_EXPORT bool filament_debug_registry_has_property(void* reg, const char* name);

FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_bool  (void* reg, const char* name, bool v);
FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_int   (void* reg, const char* name, int32_t v);
FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float (void* reg, const char* name, float v);
FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float2(void* reg, const char* name, float x, float y);
FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float3(void* reg, const char* name, float x, float y, float z);
FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float4(void* reg, const char* name, float x, float y, float z, float w);

FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_bool  (void* reg, const char* name, bool* out);
FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_int   (void* reg, const char* name, int32_t* out);
FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float (void* reg, const char* name, float* out);
FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float2(void* reg, const char* name, float* out2);
FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float3(void* reg, const char* name, float* out3);
FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float4(void* reg, const char* name, float* out4);

FFI_PLUGIN_EXPORT bool filament_debug_registry_get_data_source(void* reg, const char* name, const void** out_data, uint32_t* out_count);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_DEBUG_REGISTRY_C_H
