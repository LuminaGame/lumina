#ifndef FILAMENT_IMAGE_OPS_C_H
#define FILAMENT_IMAGE_OPS_C_H

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

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_extract_channel(const FilLinearImage* src, uint32_t channel);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_combine_channels(const FilLinearImage* const* imgs, uint32_t count);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_crop_region(const FilLinearImage* src, uint32_t left, uint32_t top, uint32_t right, uint32_t bottom);
FFI_PLUGIN_EXPORT void filament_image_blit(FilLinearImage* dst, const FilLinearImage* src, int32_t x, int32_t y);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_stack(const FilLinearImage* const* imgs, uint32_t count);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_stack(const FilLinearImage* const* imgs, uint32_t count);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_flip(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_flip(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_transpose(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vectors_to_colors(const FilLinearImage* src);
FFI_PLUGIN_EXPORT FilLinearImage* filament_image_colors_to_vectors(const FilLinearImage* src);
FFI_PLUGIN_EXPORT int filament_image_compare(const FilLinearImage* a, const FilLinearImage* b, float epsilon);
FFI_PLUGIN_EXPORT void filament_image_clear_to_value(FilLinearImage* img, float value);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IMAGE_OPS_C_H
