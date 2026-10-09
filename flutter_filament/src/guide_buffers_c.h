/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_GUIDE_BUFFERS_C_H
#define FLUTTER_FILAMENT_GUIDE_BUFFERS_C_H

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

// Guide buffers (Filament's GuideBufferOptions, Vulkan only): world normal + roughness,
// diffuse albedo and specular albedo written by the lit shaders in the colour pass, and the
// specular hit distance traced with ray queries. On the web the options are accepted and
// ignored.

typedef enum filament_guide_buffer {
    FILAMENT_GUIDE_NORMAL_ROUGHNESS = 0,        // RGBA16F
    FILAMENT_GUIDE_DIFFUSE_ALBEDO = 1,          // RGBA8
    FILAMENT_GUIDE_SPECULAR_ALBEDO = 2,         // RGBA8
    FILAMENT_GUIDE_SPECULAR_HIT_DISTANCE = 3    // R16F
} filament_guide_buffer;

typedef struct filament_guide_buffer_options_t {
    bool enabled;
    bool specularHitDistance;
} filament_guide_buffer_options_t;

FFI_PLUGIN_EXPORT void filament_view_set_guide_buffer_options(void* view,
        const filament_guide_buffer_options_t* options);

FFI_PLUGIN_EXPORT void filament_view_get_guide_buffer_options(void* view,
        filament_guide_buffer_options_t* out);

// Copies guide `which` into `texture` every frame (render resolution, the guide's format,
// BLIT_DST usage); NULL stops the copy.
FFI_PLUGIN_EXPORT void filament_view_set_guide_buffer_texture(void* view, uint8_t which, void* texture);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_GUIDE_BUFFERS_C_H
