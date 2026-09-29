#include "ibl_bake_c.h"
#include "ibl_internal.h"
#include <ibl/CubemapIBL.h>
#include <vector>

void filament_cubemap_ibl_roughness_filter(
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
) {
    if (!dst || !levels || level_count == 0) return;
    try {
        std::vector<filament::ibl::Cubemap> levelsVec;
        levelsVec.reserve(level_count);
        for (size_t i = 0; i < level_count; i++) {
            if (levels[i]) {
                filament::ibl::Cubemap cm(levels[i]->dim);
                for (int f = 0; f < 6; f++) {
                    cm.setImageForFace(
                        static_cast<filament::ibl::Cubemap::Face>(f),
                        levels[i]->cubemap.getImageForFace(static_cast<filament::ibl::Cubemap::Face>(f))
                    );
                }
                levelsVec.emplace_back(std::move(cm));
            }
        }
        filament::math::float3 mirror(mirror_x, mirror_y, mirror_z);
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapIBL::roughnessFilter(
                js,
                dst->cubemap,
                levelsVec,
                linear_roughness,
                max_num_samples,
                mirror,
                prefilter,
                progress,
                userdata
            );
        });
    } catch (...) {
    }
}

void filament_cubemap_ibl_diffuse_irradiance(
    FilIblCubemap* dst,
    const FilIblCubemap* const* levels,
    size_t level_count,
    size_t max_num_samples,
    FilIblProgress progress,
    void* userdata
) {
    if (!dst || !levels || level_count == 0) return;
    try {
        std::vector<filament::ibl::Cubemap> levelsVec;
        levelsVec.reserve(level_count);
        for (size_t i = 0; i < level_count; i++) {
            if (levels[i]) {
                filament::ibl::Cubemap cm(levels[i]->dim);
                for (int f = 0; f < 6; f++) {
                    cm.setImageForFace(
                        static_cast<filament::ibl::Cubemap::Face>(f),
                        levels[i]->cubemap.getImageForFace(static_cast<filament::ibl::Cubemap::Face>(f))
                    );
                }
                levelsVec.emplace_back(std::move(cm));
            }
        }
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapIBL::diffuseIrradiance(
                js,
                dst->cubemap,
                levelsVec,
                max_num_samples,
                progress,
                userdata
            );
        });
    } catch (...) {
    }
}

void filament_cubemap_ibl_dfg(
    FilIblImage* dst,
    bool multiscatter,
    bool cloth
) {
    if (!dst || !dst->image.isValid()) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapIBL::DFG(
                js,
                dst->image,
                multiscatter,
                cloth
            );
        });
    } catch (...) {
    }
}
