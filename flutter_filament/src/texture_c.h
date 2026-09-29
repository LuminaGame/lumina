/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_TEXTURE_C_H
#define FLUTTER_FILAMENT_TEXTURE_C_H

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

typedef struct FilamentTextureDesc {
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint8_t levels;
    int32_t sampler_type;      /* SamplerType (0..5) */
    int32_t internal_format;   /* TextureFormat */
    uint32_t usage;            /* TextureUsage bitmask; 0 = DEFAULT */
    uint8_t samples;           /* 0 or 1 = 1 sample */
    bool has_swizzle;
    uint8_t swizzle[4];        /* TextureSwizzle {r, g, b, a} */
    intptr_t import_handle;    /* 0 = none */
} FilamentTextureDesc;

typedef void (*filament_buffer_free_fn)(void* buffer, size_t size, void* user);

FFI_PLUGIN_EXPORT void* filament_texture_create(void* engine, const FilamentTextureDesc* desc);
FFI_PLUGIN_EXPORT void* filament_texture_create_2d(void* engine, uint32_t width, uint32_t height, int format, uint8_t levels);
FFI_PLUGIN_EXPORT void filament_texture_set_image(void* engine, void* texture, uint32_t level, const void* data, uint32_t size_in_bytes, uint32_t width, uint32_t height, int pixel_format, int pixel_type);
FFI_PLUGIN_EXPORT void filament_texture_set_image_ex(
    void* engine,
    void* texture,
    uint8_t level,
    uint32_t xoffset,
    uint32_t yoffset,
    uint32_t zoffset,
    uint32_t width,
    uint32_t height,
    uint32_t depth,
    int32_t pixel_format,
    int32_t pixel_type,
    uint32_t stride,
    uint8_t alignment,
    void* data,
    size_t size,
    filament_buffer_free_fn cb,
    void* user
);
FFI_PLUGIN_EXPORT void filament_engine_destroy_texture(void* engine, void* texture);

// generateMipmaps & runtime getters
FFI_PLUGIN_EXPORT void filament_texture_generate_mipmaps(void* engine, void* texture);
FFI_PLUGIN_EXPORT uint32_t filament_texture_get_width(void* texture, uint8_t level);
FFI_PLUGIN_EXPORT uint32_t filament_texture_get_height(void* texture, uint8_t level);
FFI_PLUGIN_EXPORT uint32_t filament_texture_get_depth(void* texture, uint8_t level);
FFI_PLUGIN_EXPORT uint8_t filament_texture_get_levels(void* texture);
FFI_PLUGIN_EXPORT int32_t filament_texture_get_target(void* texture);
FFI_PLUGIN_EXPORT int32_t filament_texture_get_format(void* texture);

// Static format & capability queries
FFI_PLUGIN_EXPORT bool filament_texture_is_format_supported(void* engine, int32_t internal_format);
FFI_PLUGIN_EXPORT bool filament_texture_is_format_mipmappable(void* engine, int32_t internal_format);
FFI_PLUGIN_EXPORT bool filament_texture_is_format_compressed(int32_t internal_format);
FFI_PLUGIN_EXPORT size_t filament_texture_compute_data_size(int32_t pixel_format, int32_t pixel_type, uint32_t stride, uint32_t height, uint8_t alignment);
FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_size(void* engine, int32_t sampler_type);
FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_array_layers(void* engine);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_TEXTURE_C_H
