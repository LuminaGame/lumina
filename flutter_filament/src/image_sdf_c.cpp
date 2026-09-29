#include "image_sdf_c.h"
#include "linear_image_internal.h"
#include <image/ImageOps.h>

namespace {

struct PresenceConfig {
    float threshold;
    uint32_t channel;
};

bool presenceCallback(const image::LinearImage& img, uint32_t col, uint32_t row, void* user) {
    auto* cfg = reinterpret_cast<PresenceConfig*>(user);
    const float* p = img.getPixelRef(col, row);
    uint32_t ch = cfg->channel < img.getChannels() ? cfg->channel : 0;
    return p[ch] > cfg->threshold;
}

} // namespace

FilLinearImage* filament_image_compute_coord_field(
    const FilLinearImage* src,
    float presence_threshold,
    uint32_t presence_channel
) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        PresenceConfig cfg{presence_threshold, presence_channel};
        auto result = image::computeCoordField(src->image, presenceCallback, &cfg);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_edt_from_coord_field(
    const FilLinearImage* coord_field,
    bool sqrt_result
) {
    if (!coord_field || !coord_field->image.isValid()) return nullptr;
    try {
        auto result = image::edtFromCoordField(coord_field->image, sqrt_result);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_voronoi_from_coord_field(
    const FilLinearImage* coord_field,
    const FilLinearImage* src
) {
    if (!coord_field || !src || !coord_field->image.isValid() || !src->image.isValid()) return nullptr;
    try {
        auto result = image::voronoiFromCoordField(coord_field->image, src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}
