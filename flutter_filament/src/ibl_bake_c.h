#ifndef FILAMENT_IBL_BAKE_C_H
#define FILAMENT_IBL_BAKE_C_H

#include "ibl_cubemap_c.h"
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

typedef void (*FilIblProgress)(size_t index, float progress, void* userdata);

FFI_PLUGIN_EXPORT void filament_cubemap_ibl_roughness_filter(
    FilIblCubemap* dst,
    const FilIblCubemap* const* levels,
    size_t level_count,
    float linear_roughness,
    size_t max_num_samples,
    float mirror_x,
    float mirror_y,
    float mirror_z,
    bool prefilter,
    FilIblProgress progress,
    void* userdata
);

FFI_PLUGIN_EXPORT void filament_cubemap_ibl_diffuse_irradiance(
    FilIblCubemap* dst,
    const FilIblCubemap* const* levels,
    size_t level_count,
    size_t max_num_samples,
    FilIblProgress progress,
    void* userdata
);

FFI_PLUGIN_EXPORT void filament_cubemap_ibl_dfg(
    FilIblImage* dst,
    bool multiscatter,
    bool cloth
);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IBL_BAKE_C_H
