#ifndef FILAMENT_IMAGE_SDF_C_H
#define FILAMENT_IMAGE_SDF_C_H

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

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_compute_coord_field(
    const FilLinearImage* src,
    float presence_threshold,
    uint32_t presence_channel
);

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_edt_from_coord_field(
    const FilLinearImage* coord_field,
    bool sqrt_result
);

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_voronoi_from_coord_field(
    const FilLinearImage* coord_field,
    const FilLinearImage* src
);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IMAGE_SDF_C_H
