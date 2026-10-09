/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_DLSS_RR_C_H
#define FLUTTER_FILAMENT_DLSS_RR_C_H

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

// DLSS Ray Reconstruction (NVIDIA NGX feature `dlssd`, Vulkan): one network that denoises
// the ray-traced lighting of the HDR frame and upscales it, in place of Filament's TAA. It
// runs as an external upscaler of the HDR stage and reads the view's guide buffers (normal +
// roughness, diffuse and specular albedo, specular hit distance). Needs the fetched SDK
// (tool/dlss/fetch_sdk.dart, never committed) with the nvngx_dlssd runtime, an NVIDIA RTX
// GPU and filament_dlss_request_extensions() before the engine is created. Without them
// every function reports "not available".

typedef enum filament_dlss_rr_preset {
    FILAMENT_DLSS_RR_PRESET_DEFAULT = 0,    // NGX's default for the installed runtime
    FILAMENT_DLSS_RR_PRESET_D = 4,          // transformer model
    FILAMENT_DLSS_RR_PRESET_E = 5,          // latest transformer model
    FILAMENT_DLSS_RR_PRESET_F = 6           // transformer model of SDK 310.9 (RR2)
} filament_dlss_rr_preset;

typedef struct filament_dlss_rr_options_t {
    uint8_t quality;            // filament_dlss_quality (MAX_PERFORMANCE .. DLAA)
    uint32_t outputWidth;       // the view's viewport (output) size
    uint32_t outputHeight;
    uint8_t preset;             // filament_dlss_rr_preset
} filament_dlss_rr_options_t;

// The NGX runtime with the Ray Reconstruction library (nvngx_dlssd) was found and an NVIDIA
// Vulkan device is present.
FFI_PLUGIN_EXPORT bool filament_dlss_rr_available(void);

// Whether the engine's GPU and driver offer Ray Reconstruction (initialises NGX for the
// engine and reads SuperSamplingDenoising.Available). False on other backends.
FFI_PLUGIN_EXPORT bool filament_dlss_rr_supported(void* engine);

// Turns on the view's guide buffers and TAA jitter + motion vectors, queries the render
// resolution for the quality and output size, registers the HDR-stage upscaler and sets
// the view's dynamic resolution to that scale. NULL with filament_dlss_rr_last_error() set
// when unavailable.
FFI_PLUGIN_EXPORT void* filament_dlss_rr_create(void* engine, void* view, const filament_dlss_rr_options_t* opts);

FFI_PLUGIN_EXPORT void filament_dlss_rr_get_render_resolution(void* rr, uint32_t* out_w, uint32_t* out_h);

// Changes the quality: the feature is recreated on the next frame.
FFI_PLUGIN_EXPORT void filament_dlss_rr_set_quality(void* rr, uint8_t quality);

// Resets the temporal history for the next evaluation (camera cuts).
FFI_PLUGIN_EXPORT void filament_dlss_rr_reset_history(void* rr);

// GPU time of the last completed evaluation in nanoseconds (0 before the first).
FFI_PLUGIN_EXPORT uint64_t filament_dlss_rr_last_gpu_time_ns(void* rr);

// Frames evaluated so far.
FFI_PLUGIN_EXPORT uint64_t filament_dlss_rr_frame_count(void* rr);

// Releases the feature and restores the view's guide buffers, TAA and dynamic resolution
// options. Safe with NULL.
FFI_PLUGIN_EXPORT void filament_dlss_rr_destroy(void* rr);

// The last error (process-wide), or NULL after a successful call.
FFI_PLUGIN_EXPORT const char* filament_dlss_rr_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_DLSS_RR_C_H
