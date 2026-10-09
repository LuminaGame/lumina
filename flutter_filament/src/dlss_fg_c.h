/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_DLSS_FG_C_H
#define FLUTTER_FILAMENT_DLSS_FG_C_H

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

// DLSS Frame Generation (NVIDIA NGX feature `dlssg`, Vulkan) as far as NGX offers it directly:
// the availability and requirement probe, and an interpolator that runs NGX's frame
// generation inside Filament's frame (external post pass) and shows the generated frame
// between the previous and the current one instead of the current one. That makes the
// network's output inspectable and measurable; it does not present extra frames (see the
// DLSS documentation page for why presenting them is out of reach today). Needs the fetched
// SDK with nvngx_dlssg, an NVIDIA GPU of the RTX 40 series or newer and
// filament_dlss_fg_request_extensions() before the engine is created.

typedef struct filament_dlss_fg_probe_t {
    bool available;                 // FrameGeneration.Available
    bool needsUpdatedDriver;        // FrameGeneration.NeedsUpdatedDriver
    uint32_t minDriverMajor;
    uint32_t minDriverMinor;
    int32_t featureInitResult;      // FrameGeneration.FeatureInitResult (NVSDK_NGX_Result)
    uint32_t multiFrameCountMax;    // DLSSG.MultiFrameCountMax (1 = 2x only, 3 = up to 4x, ...)
    uint32_t supportFlags;          // NVSDK_NGX_Feature_Support_Result bits (0 = supported)
    uint32_t minHwArchitecture;     // NV_GPU_ARCHITECTURE_ID the feature needs
    char deviceExtensions[1024];    // the device extensions NGX asks for, space-separated
} filament_dlss_fg_probe_t;

// The NGX runtime with nvngx_dlssg was found and an NVIDIA Vulkan device is present.
FFI_PLUGIN_EXPORT bool filament_dlss_fg_available(void);

// Asks the engines created from now on for the Vulkan device extensions (and the optical
// flow feature) NGX reports for Frame Generation, on top of the DLSS ones. Returns false when
// unavailable.
FFI_PLUGIN_EXPORT bool filament_dlss_fg_request_extensions(void);

// Forgets filament_dlss_fg_request_extensions().
FFI_PLUGIN_EXPORT void filament_dlss_fg_clear_extension_request(void);

// Initialises NGX for the engine and fills `out` from its capability parameters and the
// feature requirements. False (with filament_dlss_fg_last_error()) when NGX cannot start.
FFI_PLUGIN_EXPORT bool filament_dlss_fg_probe(void* engine, filament_dlss_fg_probe_t* out);

// Registers the interpolator on the view (an external post pass, single-sampled view at its
// output resolution): from the second frame on, the view shows frame `index` of
// `multiFrameCount` generated between the previous and the current frame. NULL with
// filament_dlss_fg_last_error() set on failure.
FFI_PLUGIN_EXPORT void* filament_dlss_fg_interpolator_create(void* engine, void* view, uint32_t multiFrameCount,
        uint32_t index);

// Frames for which NGX generated an image.
FFI_PLUGIN_EXPORT uint64_t filament_dlss_fg_interpolator_frame_count(void* interpolator);

// The NGX result of the last creation or evaluation (1 = success).
FFI_PLUGIN_EXPORT int32_t filament_dlss_fg_interpolator_last_result(void* interpolator);

// GPU time of the last completed evaluation in nanoseconds (0 before the first).
FFI_PLUGIN_EXPORT uint64_t filament_dlss_fg_interpolator_last_gpu_time_ns(void* interpolator);

FFI_PLUGIN_EXPORT void filament_dlss_fg_interpolator_destroy(void* interpolator);

// DLSS Frame Generation presenting through Filament (an external frame generator on the view):
// every rendered frame of a view drawn into a SwapChain is preceded by `generatedFrames`
// generated ones (1 = 2x, 3 = 4x, up to 5 = 6x on RTX 50 class GPUs); Renderer::endFrame()
// presents them, evenly spaced without vsync. Views rendered into a texture (Flutter) do not
// get extra presents. NULL with filament_dlss_fg_last_error() set when unavailable or when the
// GPU allows fewer frames (DLSSG.MultiFrameCountMax).
FFI_PLUGIN_EXPORT void* filament_dlss_fg_create(void* engine, void* view, uint32_t generatedFrames);

// Changes the generated frames per rendered frame (1..5, within the GPU's limit).
FFI_PLUGIN_EXPORT void filament_dlss_fg_set_generated_frames(void* generator, uint32_t generatedFrames);

// Rendered frames for which NGX generated frames.
FFI_PLUGIN_EXPORT uint64_t filament_dlss_fg_frame_count(void* generator);

// The NGX result of the last creation or evaluation (1 = success).
FFI_PLUGIN_EXPORT int32_t filament_dlss_fg_last_result(void* generator);

// GPU time of the last completed set of evaluations (all generated frames of one rendered
// frame) in nanoseconds.
FFI_PLUGIN_EXPORT uint64_t filament_dlss_fg_last_gpu_time_ns(void* generator);

FFI_PLUGIN_EXPORT void filament_dlss_fg_destroy(void* generator);

FFI_PLUGIN_EXPORT const char* filament_dlss_fg_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_DLSS_FG_C_H
