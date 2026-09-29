#include "image_sampler_c.h"
#include "linear_image_internal.h"
#include <image/ImageSampler.h>
#include <vector>

FilLinearImage* filament_image_resample(
    const FilLinearImage* src,
    uint32_t dst_width,
    uint32_t dst_height,
    int filter
) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto f = static_cast<image::Filter>(filter);
        auto result = image::resampleImage(src->image, dst_width, dst_height, f);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_resample_region(
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
) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        image::ImageSampler sampler;
        auto f = static_cast<image::Filter>(filter);
        sampler.horizontalFilter = f;
        sampler.verticalFilter = f;
        sampler.sourceRegion = {left, top, right, bottom};

        sampler.west.mode = static_cast<decltype(sampler.west.mode)>(horizontal_boundary);
        sampler.east.mode = static_cast<decltype(sampler.east.mode)>(horizontal_boundary);
        sampler.north.mode = static_cast<decltype(sampler.north.mode)>(vertical_boundary);
        sampler.south.mode = static_cast<decltype(sampler.south.mode)>(vertical_boundary);

        auto result = image::resampleImage(src->image, dst_width, dst_height, sampler);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

uint32_t filament_image_get_mipmap_count(const FilLinearImage* img) {
    if (!img || !img->image.isValid()) return 0;
    try {
        return image::getMipmapCount(img->image);
    } catch (...) {
        return 0;
    }
}

void filament_image_generate_mipmaps(
    const FilLinearImage* src,
    int filter,
    FilLinearImage** out_levels,
    uint32_t count
) {
    if (!src || !src->image.isValid() || !out_levels || count == 0) return;
    try {
        std::vector<image::LinearImage> levels(count);
        auto f = static_cast<image::Filter>(filter);
        image::generateMipmaps(src->image, f, levels.data(), count);
        for (uint32_t i = 0; i < count; i++) {
            out_levels[i] = wrapLinearImage(std::move(levels[i]));
        }
    } catch (...) {
        // error handling
    }
}
