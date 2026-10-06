/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_DLSS_C_H
#define FLUTTER_FILAMENT_DLSS_C_H

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

// DLSS Super Resolution (NVIDIA NGX, Vulkan) behind Filament's dynamic resolution.
//
// The NGX SDK is optional: `tool/dlss/fetch_sdk.dart` places it under build/dlss-sdk/
// and the native build then compiles this file with FLUTTER_FILAMENT_DLSS=1. Without
// it every function reports "not available" (false / NULL) and the engine renders as
// before. The nvngx_dlss runtime is loaded from LUMINA_DLSS_DIR, the folder of the
// executable, or the SDK folder the fetch script filled.

typedef enum filament_dlss_quality {
    FILAMENT_DLSS_MAX_PERFORMANCE = 0,
    FILAMENT_DLSS_BALANCED = 1,
    FILAMENT_DLSS_MAX_QUALITY = 2,
    FILAMENT_DLSS_ULTRA_PERFORMANCE = 3,
    FILAMENT_DLSS_DLAA = 4
} filament_dlss_quality;

typedef struct filament_dlss_options_t {
    uint8_t quality;            // filament_dlss_quality
    uint32_t outputWidth;       // the view's viewport (output) size
    uint32_t outputHeight;
    bool hdr;                   // the colour input is HDR (Filament hands LDR after colour grading)
    bool autoExposure;          // let DLSS measure exposure itself
    float sharpness;            // 0 (off) .. 1; ignored by current DLSS releases
} filament_dlss_options_t;

// The NGX runtime was found and an NVIDIA GPU is present (Vulkan).
FFI_PLUGIN_EXPORT bool filament_dlss_available(void);

// Asks the next engine creations to enable the Vulkan instance and device extensions
// NGX needs; must run before filament_engine_create*. Returns false (and changes
// nothing) when NGX is absent.
FFI_PLUGIN_EXPORT bool filament_dlss_request_extensions(void);

// Forgets a previous filament_dlss_request_extensions(): the next engines are created
// without the NGX extensions (tests, or when the user turned DLSS off).
FFI_PLUGIN_EXPORT void filament_dlss_clear_extension_request(void);

// Initialises NGX for the engine's Vulkan device, queries the optimal render
// resolution for the requested quality and output size, registers an external
// upscaler on the view and enables dynamic resolution with that fixed scale.
// Returns NULL with filament_dlss_last_error() set when NGX or the device declines.
FFI_PLUGIN_EXPORT void* filament_dlss_create(void* engine, void* view, const filament_dlss_options_t* opts);

// The render resolution NGX chose for the current quality (0,0 after a failure).
FFI_PLUGIN_EXPORT void filament_dlss_get_render_resolution(void* dlss, uint32_t* out_w, uint32_t* out_h);

// Changes the quality: queries the optimal resolution again, recreates the feature on
// the next frame and updates the view's dynamic resolution scale.
FFI_PLUGIN_EXPORT void filament_dlss_set_quality(void* dlss, uint8_t quality);

// Resets the temporal history for the next evaluation (camera cuts).
FFI_PLUGIN_EXPORT void filament_dlss_reset_history(void* dlss);

// Releases the feature, unregisters the upscaler and restores the view's builtin
// upscaler with dynamic resolution disabled. Safe to call with NULL.
FFI_PLUGIN_EXPORT void filament_dlss_destroy(void* dlss);

// The last error NGX or the wrapper reported (process-wide), or NULL when the last
// operation succeeded. The string stays valid until the next DLSS call.
FFI_PLUGIN_EXPORT const char* filament_dlss_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_DLSS_C_H
