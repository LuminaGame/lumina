#ifndef FILAMENT_IMAGE_SAMPLER_C_H
#define FILAMENT_IMAGE_SAMPLER_C_H

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

enum FilImageFilter {
    FIL_IMAGE_FILTER_DEFAULT = 0,
    FIL_IMAGE_FILTER_BOX = 1,
    FIL_IMAGE_FILTER_NEAREST = 2,
    FIL_IMAGE_FILTER_HERMITE = 3,
    FIL_IMAGE_FILTER_GAUSSIAN_SCALARS = 4,
    FIL_IMAGE_FILTER_GAUSSIAN_NORMALS = 5,
    FIL_IMAGE_FILTER_MITCHELL = 6,
    FIL_IMAGE_FILTER_LANCZOS = 7,
    FIL_IMAGE_FILTER_MINIMUM = 8,
};

enum FilImageBoundary {
    FIL_IMAGE_BOUNDARY_EXCLUDE = 0,
    FIL_IMAGE_BOUNDARY_REGION = 1,
    FIL_IMAGE_BOUNDARY_CLAMP = 2,
    FIL_IMAGE_BOUNDARY_REPEAT = 3,
    FIL_IMAGE_BOUNDARY_MIRROR = 4,
    FIL_IMAGE_BOUNDARY_COLOR = 5,
    FIL_IMAGE_BOUNDARY_NEIGHBOR = 6,
};

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample(
    const FilLinearImage* src,
    uint32_t dst_width,
    uint32_t dst_height,
    int filter
);

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample_region(
    const FilLinearImage* src,
    uint32_t dst_width,
    uint32_t dst_height,
    int filter,
    float left,
    float top,
    float right,
    float bottom,
    int horizontal_boundary,
    int vertical_boundary
);

FFI_PLUGIN_EXPORT uint32_t filament_image_get_mipmap_count(const FilLinearImage* img);

FFI_PLUGIN_EXPORT void filament_image_generate_mipmaps(
    const FilLinearImage* src,
    int filter,
    FilLinearImage** out_levels,
    uint32_t count
);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IMAGE_SAMPLER_C_H
