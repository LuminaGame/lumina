#ifndef FILAMENT_IBL_SH_C_H
#define FILAMENT_IBL_SH_C_H

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

FFI_PLUGIN_EXPORT bool filament_cubemap_sh_compute(
    const FilIblCubemap* cm,
    uint8_t num_bands,
    bool irradiance,
    float* out_sh
);

FFI_PLUGIN_EXPORT void filament_cubemap_sh_window(
    float* sh,
    uint8_t num_bands,
    float cutoff
);

FFI_PLUGIN_EXPORT void filament_cubemap_sh_preprocess_for_shader(
    float* sh
);

FFI_PLUGIN_EXPORT void filament_cubemap_sh_render(
    FilIblCubemap* out_cm,
    const float* sh,
    uint8_t num_bands
);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IBL_SH_C_H
