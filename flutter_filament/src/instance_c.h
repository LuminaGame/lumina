/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_INSTANCE_C_H
#define FLUTTER_FILAMENT_INSTANCE_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// TransformManager instance APIs
FFI_PLUGIN_EXPORT uint32_t filament_transform_manager_get_instance(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT bool filament_transform_manager_has_component(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_transform_manager_set_transform_i(
    void* engine, uint32_t instance, const float* mat4f);
FFI_PLUGIN_EXPORT void filament_transform_manager_get_world_transform_i(
    void* engine, uint32_t instance, float* out_mat4f);
FFI_PLUGIN_EXPORT void filament_transform_manager_get_transform_i(
    void* engine, uint32_t instance, float* out_mat4f);

// RenderableManager instance APIs
FFI_PLUGIN_EXPORT uint32_t filament_renderable_manager_get_instance(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT bool filament_renderable_manager_has_component(void* engine, uint32_t entity);

// LightManager instance APIs
FFI_PLUGIN_EXPORT uint32_t filament_light_manager_get_instance(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT bool filament_light_manager_has_component(void* engine, uint32_t entity);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_INSTANCE_C_H
