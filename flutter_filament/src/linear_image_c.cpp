#include "linear_image_c.h"
#include "linear_image_internal.h"
#include <new>

FilLinearImage* filament_linear_image_create(uint32_t width, uint32_t height, uint32_t channels) {
    try {
        auto* wrapper = new FilLinearImage();
        wrapper->image = image::LinearImage(width, height, channels);
        return wrapper;
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_linear_image_share(const FilLinearImage* img) {
    if (!img) return nullptr;
    try {
        auto* wrapper = new FilLinearImage();
        wrapper->image = img->image; // invokes copy constructor -> shared pixel data
        return wrapper;
    } catch (...) {
        return nullptr;
    }
}

void filament_linear_image_destroy(FilLinearImage* img) {
    if (!img) return;
    delete img;
}

uint32_t filament_linear_image_get_width(const FilLinearImage* img) {
    if (!img) return 0;
    return img->image.getWidth();
}

uint32_t filament_linear_image_get_height(const FilLinearImage* img) {
    if (!img) return 0;
    return img->image.getHeight();
}

uint32_t filament_linear_image_get_channels(const FilLinearImage* img) {
    if (!img) return 0;
    return img->image.getChannels();
}

float* filament_linear_image_get_pixel_data(FilLinearImage* img) {
    if (!img) return nullptr;
    return img->image.getPixelRef();
}

bool filament_linear_image_is_valid(const FilLinearImage* img) {
    if (!img) return false;
    return img->image.isValid();
}
