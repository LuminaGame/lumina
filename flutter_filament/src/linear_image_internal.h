#pragma once
#include "linear_image_c.h"
#include <image/LinearImage.h>
#include <utility>

struct FilLinearImage {
    image::LinearImage image;
};

inline image::LinearImage* toLinearImage(FilLinearImage* img) {
    return img ? &img->image : nullptr;
}

inline const image::LinearImage* toLinearImage(const FilLinearImage* img) {
    return img ? &img->image : nullptr;
}

inline FilLinearImage* wrapLinearImage(image::LinearImage&& img) {
    auto* wrapper = new FilLinearImage();
    wrapper->image = std::move(img);
    return wrapper;
}

inline FilLinearImage* wrapLinearImage(const image::LinearImage& img) {
    auto* wrapper = new FilLinearImage();
    wrapper->image = img;
    return wrapper;
}
