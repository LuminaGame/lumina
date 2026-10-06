/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_RAY_TRACING_C_H
#define FLUTTER_FILAMENT_RAY_TRACING_C_H

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

// Ray tracing foundation (Vulkan ray query): per-scene acceleration structures,
// ray-traced directional shadows (FilamentShadowOptions.ray_traced) and visibility
// rays. Every function is safe on backends without ray tracing: support reads false,
// the scene flag is kept but nothing is built, and rays report no hit.

// Asks the engines created from now on for the Vulkan ray query extensions
// (acceleration structure, ray query, deferred host operations, buffer device
// address). Must run before filament_engine_create*; the request is kept next to
// the DLSS one, so the order of the two does not matter. Returns false on platforms
// without a desktop Vulkan backend (web, Android, macOS), where nothing changes.
FFI_PLUGIN_EXPORT bool filament_ray_tracing_request_extensions(void);

// Forgets filament_ray_tracing_request_extensions(): later engines are created
// without the ray query extensions (tests, or when the user turned ray tracing off).
FFI_PLUGIN_EXPORT void filament_ray_tracing_clear_extension_request(void);

// The engine's device builds acceleration structures and traces rays from shaders.
FFI_PLUGIN_EXPORT bool filament_engine_supports_ray_query(void* engine);

// Keeps the scene's acceleration structures (one per primitive geometry, a top-level
// one over the renderables' transforms, rebuilt every frame the scene renders).
FFI_PLUGIN_EXPORT void filament_scene_set_ray_tracing_enabled(void* scene, bool enabled);
FFI_PLUGIN_EXPORT bool filament_scene_get_ray_tracing_enabled(void* scene);

// Renderables in the top-level structure after the last frame (0 when off or unsupported).
FFI_PLUGIN_EXPORT uint32_t filament_scene_get_tlas_instance_count(void* scene);

// GPU time of the last top-level structure build in nanoseconds (0 until a timer resolved).
FFI_PLUGIN_EXPORT uint64_t filament_scene_get_tlas_build_nanos(void* scene);

// Whether the renderable's geometry is part of the acceleration structures (default true).
FFI_PLUGIN_EXPORT void filament_renderable_set_ray_tracing_visible(void* engine, uint32_t entity, bool visible);
FFI_PLUGIN_EXPORT bool filament_renderable_is_ray_tracing_visible(void* engine, uint32_t entity);

// Test hook: traces one visibility ray against the scene's acceleration structures
// and waits for the answer. Renders the scene through a temporary 1x1 view (which
// also rebuilds the structures from the current transforms), so it must not run
// while a frame of the caller's renderer is open. Returns true on a hit and fills
// the distance, the entity hit and the triangle index; false (zeros) on a miss, when
// ray tracing is off or unsupported.
FFI_PLUGIN_EXPORT bool filament_scene_trace_visibility(void* engine, void* scene,
        const float* origin3, const float* direction3, float max_distance,
        float* out_distance, uint32_t* out_entity, uint32_t* out_primitive);

// Asynchronous ray query on a view: the callback fires with the result once the
// view's next frame rendered (hit = false when ray tracing is off or unsupported).
typedef void (*FilamentRayHitCallback)(bool hit, float distance, uint32_t entity, uint32_t primitive, void* user_data);
FFI_PLUGIN_EXPORT void filament_view_trace_ray(void* view, const float* origin3, const float* direction3,
        float max_distance, FilamentRayHitCallback callback, void* user_data);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_RAY_TRACING_C_H
