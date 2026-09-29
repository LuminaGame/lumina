#include "ibl_cubemap_c.h"
#include "ibl_internal.h"
#include "linear_image_internal.h"
#include <image/LinearImage.h>
#include <cstring>
#include <algorithm>

FilIblImage* filament_ibl_image_create(size_t w, size_t h) {
    try {
        return new FilIblImage(w, h);
    } catch (...) {
        return nullptr;
    }
}

void filament_ibl_image_destroy(FilIblImage* img) {
    delete img;
}

size_t filament_ibl_image_get_width(const FilIblImage* img) {
    if (!img) return 0;
    return img->image.getWidth();
}

size_t filament_ibl_image_get_height(const FilIblImage* img) {
    if (!img) return 0;
    return img->image.getHeight();
}

float* filament_ibl_image_get_data(FilIblImage* img) {
    if (!img) return nullptr;
    return static_cast<float*>(img->image.getData());
}

size_t filament_ibl_image_get_bytes_per_row(const FilIblImage* img) {
    if (!img || !img->image.isValid()) return 0;
    return img->image.getBytesPerRow();
}

FilIblImage* filament_ibl_image_from_linear_image(const FilLinearImage* img) {
    if (!img || !img->image.isValid()) return nullptr;
    try {
        uint32_t w = img->image.getWidth();
        uint32_t h = img->image.getHeight();
        uint32_t c = img->image.getChannels();
        auto* iblImg = new FilIblImage(w, h);
        float* dst = static_cast<float*>(iblImg->image.getData());

        for (uint32_t y = 0; y < h; ++y) {
            const float* src = img->image.getPixelRef(0, y);
            for (uint32_t x = 0; x < w; ++x) {
                dst[0] = src[0];
                dst[1] = c > 1 ? src[1] : src[0];
                dst[2] = c > 2 ? src[2] : (c > 1 ? src[1] : src[0]);
                src += c;
                dst += 3;
            }
        }
        return iblImg;
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_ibl_image_to_linear_image(const FilIblImage* img) {
    if (!img || !img->image.isValid()) return nullptr;
    try {
        size_t w = img->image.getWidth();
        size_t h = img->image.getHeight();
        image::LinearImage linearImg(static_cast<uint32_t>(w), static_cast<uint32_t>(h), 3);
        // A face image of a cubemap cross is a sub-image whose rows are
        // strided across the whole cross: copy row by row, never as one block.
        const size_t rowBytes = w * 3 * sizeof(float);
        for (size_t y = 0; y < h; ++y) {
            const float* src = static_cast<const float*>(img->image.getPixelRef(0, y));
            float* dst = linearImg.getPixelRef(0, static_cast<uint32_t>(y));
            std::memcpy(dst, src, rowBytes);
        }
        return wrapLinearImage(std::move(linearImg));
    } catch (...) {
        return nullptr;
    }
}

FilIblCubemap* filament_cubemap_create(size_t dim) {
    try {
        return new FilIblCubemap(dim);
    } catch (...) {
        return nullptr;
    }
}

void filament_cubemap_destroy(FilIblCubemap* cm) {
    delete cm;
}

size_t filament_cubemap_get_dimensions(const FilIblCubemap* cm) {
    if (!cm) return 0;
    return cm->dim;
}

FilIblImage* filament_cubemap_get_face_image(FilIblCubemap* cm, int face) {
    if (!cm || face < 0 || face > 5) return nullptr;
    try {
        auto* img = new FilIblImage();
        img->image.set(cm->cubemap.getImageForFace(static_cast<filament::ibl::Cubemap::Face>(face)));
        return img;
    } catch (...) {
        return nullptr;
    }
}

void filament_cubemap_utils_equirect_to_cubemap(FilIblCubemap* dst, const FilIblImage* src) {
    if (!dst || !src || !src->image.isValid()) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::equirectangularToCubemap(js, dst->cubemap, src->image);
        });
    } catch (...) {
    }
}

void filament_cubemap_utils_cubemap_to_equirect(FilIblImage* dst, const FilIblCubemap* src) {
    if (!dst || !src || !dst->image.isValid()) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::cubemapToEquirectangular(js, dst->image, src->cubemap);
        });
    } catch (...) {
    }
}

void filament_cubemap_utils_set_all_faces_from_cross(FilIblCubemap* c, const FilIblImage* cross) {
    if (!c || !cross || !cross->image.isValid()) return;
    try {
        filament::ibl::CubemapUtils::setAllFacesFromCross(c->cubemap, cross->image);
    } catch (...) {
    }
}

FilIblCubemap* filament_cubemap_utils_cross_to_cubemap(const FilIblImage* cross) {
    if (!cross || !cross->image.isValid()) return nullptr;
    try {
        size_t w = cross->image.getWidth();
        size_t h = cross->image.getHeight();
        size_t dim = 0;
        if (w / 4 == h / 3) {
            dim = w / 4;
        } else if (w / 3 == h / 4) {
            dim = w / 3;
        } else {
            dim = std::min(w, h) / 3;
        }
        auto* cm = new FilIblCubemap(dim);
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::crossToCubemap(js, cm->cubemap, cross->image);
        });
        return cm;
    } catch (...) {
        return nullptr;
    }
}

void filament_cubemap_utils_cubemap_to_octahedron(FilIblImage* dst, const FilIblCubemap* src) {
    if (!dst || !src || !dst->image.isValid()) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::cubemapToOctahedron(js, dst->image, src->cubemap);
        });
    } catch (...) {
    }
}

void filament_cubemap_utils_mirror_cubemap(FilIblCubemap* dst, const FilIblCubemap* src) {
    if (!dst || !src) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::mirrorCubemap(js, dst->cubemap, src->cubemap);
        });
    } catch (...) {
    }
}

void filament_cubemap_utils_downsample_boxfilter(FilIblCubemap* dst, const FilIblCubemap* src) {
    if (!dst || !src) return;
    try {
        withJobSystemVoid([&](utils::JobSystem& js) {
            filament::ibl::CubemapUtils::downsampleCubemapLevelBoxFilter(js, dst->cubemap, src->cubemap);
        });
    } catch (...) {
    }
}

void filament_cubemap_utils_make_seamless(FilIblCubemap* c) {
    if (!c) return;
    try {
        c->cubemap.makeSeamless();
    } catch (...) {
    }
}
