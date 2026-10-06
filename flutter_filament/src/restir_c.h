/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_RESTIR_C_H
#define FLUTTER_FILAMENT_RESTIR_C_H

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

// ReSTIR direct lighting (Vulkan ray query): per-pixel reservoirs resample the scene's
// punctual lights, reuse the previous frame and the neighbourhood, trace one visibility
// ray and shade the surviving light. Needs filament_engine_supports_ray_query() and
// filament_scene_set_ray_tracing_enabled(); otherwise the froxel light loop renders.

// Mirrors filament::RestirOptions (filament_options_sizeof(14)).
typedef struct filament_restir_options {
    bool enabled;
    uint8_t initialCandidates;  // lights sampled per pixel and frame (default 8)
    uint8_t spatialSamples;     // neighbour reservoirs merged per pixel (default 2, 0 disables)
    float spatialRadiusPx;      // neighbourhood radius in pixels (default 32)
    bool temporal;              // reuse the previous frame's reservoir (default true)
    uint8_t maxHistory;         // frames of history one reservoir may weigh (default 20)
    bool visibilityRays;        // trace a ray to the chosen light (default true)
    bool shadeEmissive;         // reserved, not implemented
} filament_restir_options;

typedef struct filament_restir_stats_t {
    uint32_t lightCount;            // punctual lights in the light buffer last frame
    uint32_t emissiveTriangleCount; // always 0
    uint32_t raysPerFrame;          // visibility rays traced last frame
    uint64_t gpuNanos;              // GPU time of the ReSTIR passes last measured
} filament_restir_stats_t;

FFI_PLUGIN_EXPORT void filament_view_set_restir_options(void* view, const filament_restir_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_restir_options(void* view, filament_restir_options* out_options);

// Ray queries are available and the ReSTIR materials are loaded for this engine.
FFI_PLUGIN_EXPORT bool filament_view_restir_supported(void* view);

// Counters of the last ReSTIR frame (zeros while off or unsupported).
FFI_PLUGIN_EXPORT void filament_view_get_restir_stats(void* view, filament_restir_stats_t* out_stats);

// Drops the temporal history: the next frame resamples from scratch (camera cuts).
FFI_PLUGIN_EXPORT void filament_view_restir_reset_history(void* view);

// Scales how much ReSTIR favours a light (0 removes it, default 1).
FFI_PLUGIN_EXPORT void filament_light_set_restir_sampling_weight(void* engine, uint32_t entity, float weight);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_RESTIR_C_H
