#include "image_ops_c.h"
#include "linear_image_internal.h"
#include <image/ImageOps.h>
#include <vector>
#include <algorithm>
#include <cstring>

FilLinearImage* filament_image_extract_channel(const FilLinearImage* src, uint32_t channel) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::extractChannel(src->image, channel);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_combine_channels(const FilLinearImage* const* imgs, uint32_t count) {
    if (!imgs || count == 0) return nullptr;
    try {
        std::vector<image::LinearImage> vec;
        vec.reserve(count);
        for (uint32_t i = 0; i < count; i++) {
            if (!imgs[i] || !imgs[i]->image.isValid()) return nullptr;
            vec.push_back(imgs[i]->image);
        }
        auto result = image::combineChannels(vec.data(), count);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_crop_region(const FilLinearImage* src, uint32_t left, uint32_t top, uint32_t right, uint32_t bottom) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::cropRegion(src->image, left, top, right, bottom);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

void filament_image_blit(FilLinearImage* dst, const FilLinearImage* src, int32_t dst_x, int32_t dst_y) {
    if (!dst || !src || !dst->image.isValid() || !src->image.isValid()) return;
    auto& d = dst->image;
    const auto& s = src->image;
    if (d.getChannels() != s.getChannels()) return;
    uint32_t channels = d.getChannels();
    uint32_t dw = d.getWidth();
    uint32_t dh = d.getHeight();
    uint32_t sw = s.getWidth();
    uint32_t sh = s.getHeight();

    int32_t start_x = std::max(0, dst_x);
    int32_t start_y = std::max(0, dst_y);
    int32_t end_x = std::min((int32_t)dw, dst_x + (int32_t)sw);
    int32_t end_y = std::min((int32_t)dh, dst_y + (int32_t)sh);

    for (int32_t y = start_y; y < end_y; ++y) {
        int32_t sy = y - dst_y;
        int32_t sx = start_x - dst_x;
        int32_t copy_w = end_x - start_x;
        if (copy_w <= 0) continue;
        float* dptr = d.getPixelRef(start_x, y);
        const float* sptr = s.getPixelRef(sx, sy);
        std::memcpy(dptr, sptr, copy_w * channels * sizeof(float));
    }
}

FilLinearImage* filament_image_horizontal_stack(const FilLinearImage* const* imgs, uint32_t count) {
    if (!imgs || count == 0) return nullptr;
    try {
        std::vector<image::LinearImage> vec;
        vec.reserve(count);
        for (uint32_t i = 0; i < count; i++) {
            if (!imgs[i] || !imgs[i]->image.isValid()) return nullptr;
            vec.push_back(imgs[i]->image);
        }
        auto result = image::horizontalStack(vec.data(), count);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_vertical_stack(const FilLinearImage* const* imgs, uint32_t count) {
    if (!imgs || count == 0) return nullptr;
    try {
        std::vector<image::LinearImage> vec;
        vec.reserve(count);
        for (uint32_t i = 0; i < count; i++) {
            if (!imgs[i] || !imgs[i]->image.isValid()) return nullptr;
            vec.push_back(imgs[i]->image);
        }
        auto result = image::verticalStack(vec.data(), count);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_horizontal_flip(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::horizontalFlip(src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_vertical_flip(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::verticalFlip(src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_transpose(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::transpose(src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_vectors_to_colors(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::vectorsToColors(src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_image_colors_to_vectors(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        auto result = image::colorsToVectors(src->image);
        return wrapLinearImage(std::move(result));
    } catch (...) {
        return nullptr;
    }
}

int filament_image_compare(const FilLinearImage* a, const FilLinearImage* b, float epsilon) {
    if (!a || !b || !a->image.isValid() || !b->image.isValid()) return -1;
    try {
        return image::compare(a->image, b->image, epsilon);
    } catch (...) {
        return -1;
    }
}

void filament_image_clear_to_value(FilLinearImage* img, float value) {
    if (!img || !img->image.isValid()) return;
    try {
        image::clearToValue(img->image, value);
    } catch (...) {
    }
}
