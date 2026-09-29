#include "ibl_sh_c.h"
#include "ibl_internal.h"
#include <ibl/CubemapSH.h>
#include <cstring>

bool filament_cubemap_sh_compute(
    const FilIblCubemap* cm,
    uint8_t num_bands,
    bool irradiance,
    float* out_sh
) {
    if (!cm || !out_sh || num_bands == 0 || num_bands > 5) return false;
    try {
        std::unique_ptr<filament::math::float3[]> result = withJobSystem([&](utils::JobSystem& js) {
            return filament::ibl::CubemapSH::computeSH(
                js,
                cm->cubemap,
                num_bands,
                irradiance
            );
        });
        if (!result) return false;
        size_t count = num_bands * num_bands;
        std::memcpy(out_sh, result.get(), count * 3 * sizeof(float));
        return true;
    } catch (...) {
        return false;
    }
}

void filament_cubemap_sh_window(
    float* sh,
    uint8_t num_bands,
    float cutoff
) {
    if (!sh || num_bands == 0) return;
    try {
        size_t count = num_bands * num_bands;
        std::unique_ptr<filament::math::float3[]> shPtr(new filament::math::float3[count]);
        std::memcpy(shPtr.get(), sh, count * 3 * sizeof(float));
        filament::ibl::CubemapSH::windowSH(shPtr, num_bands, cutoff);
        std::memcpy(sh, shPtr.get(), count * 3 * sizeof(float));
    } catch (...) {
    }
}

void filament_cubemap_sh_preprocess_for_shader(
    float* sh
) {
    if (!sh) return;
    try {
        size_t count = 9; // 3 bands
        std::unique_ptr<filament::math::float3[]> shPtr(new filament::math::float3[count]);
        std::memcpy(shPtr.get(), sh, count * 3 * sizeof(float));
        filament::ibl::CubemapSH::preprocessSHForShader(shPtr);
        std::memcpy(sh, shPtr.get(), count * 3 * sizeof(float));
    } catch (...) {
    }
}

void filament_cubemap_sh_render(
    FilIblCubemap* out_cm,
    const float* sh,
    uint8_t num_bands
) {
    if (!out_cm || !sh || num_bands == 0) return;
    try {
        size_t count = num_bands * num_bands;
        std::unique_ptr<filament::math::float3[]> shPtr(new filament::math::float3[count]);
        std::memcpy(shPtr.get(), sh, count * 3 * sizeof(float));
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapSH::renderSH(js, out_cm->cubemap, shPtr, num_bands);
        });
    } catch (...) {
    }
}
