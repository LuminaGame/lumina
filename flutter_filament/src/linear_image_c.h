#ifndef FILAMENT_LINEAR_IMAGE_C_H
#define FILAMENT_LINEAR_IMAGE_C_H

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

typedef struct FilLinearImage FilLinearImage;

FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_create(uint32_t width, uint32_t height, uint32_t channels);
FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_share(const FilLinearImage* img);
FFI_PLUGIN_EXPORT void filament_linear_image_destroy(FilLinearImage* img);
FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_width(const FilLinearImage* img);
FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_height(const FilLinearImage* img);
FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_channels(const FilLinearImage* img);
FFI_PLUGIN_EXPORT float* filament_linear_image_get_pixel_data(FilLinearImage* img);
FFI_PLUGIN_EXPORT bool filament_linear_image_is_valid(const FilLinearImage* img);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_LINEAR_IMAGE_C_H
