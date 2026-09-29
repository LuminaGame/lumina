#ifndef FILAMENT_COLOR_TRANSFORM_C_H
#define FILAMENT_COLOR_TRANSFORM_C_H

#include "linear_image_c.h"
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef FFI_PLUGIN_EXPORT
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_to_linear(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_srgb(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_color_to_grayscale(const FilLinearImage* src);

FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_bytes_to_linear(
    uint32_t width,
    uint32_t height,
    uint32_t bytes_per_row,
    uint32_t channels,
    const uint8_t* srgb_bytes
);

FFI_PLUGIN_EXPORT void filament_color_linear_to_srgb_bytes(
    const FilLinearImage* src,
    uint8_t* out_bytes,
    uint32_t bytes_per_row
);

FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_rgbm(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_color_rgbm_to_linear(const FilLinearImage* src);

FFI_PLUGIN_EXPORT void filament_color_linear_to_rgb_10_11_11_rev(
    const FilLinearImage* src,
    uint32_t* out_pixels
);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_COLOR_TRANSFORM_C_H
