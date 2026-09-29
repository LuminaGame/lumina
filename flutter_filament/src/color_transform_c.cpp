#include "color_transform_c.h"
#include "linear_image_internal.h"
#include <image/ColorTransform.h>
#include <cmath>
#include <cstring>
#include <algorithm>

using namespace filament::math;

FilLinearImage* filament_color_srgb_to_linear(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        uint32_t c = in.getChannels();
        image::LinearImage out(w, h, c);

        for (uint32_t y = 0; y < h; ++y) {
            const float* pIn = in.getPixelRef(0, y);
            float* pOut = out.getPixelRef(0, y);
            for (uint32_t x = 0; x < w; ++x) {
                for (uint32_t ch = 0; ch < c; ++ch) {
                    if (ch < 3) {
                        float v = pIn[ch];
                        if (v <= 0.04045f) {
                            pOut[ch] = v * (1.0f / 12.92f);
                        } else {
                            pOut[ch] = std::pow((v + 0.055f) / 1.055f, 2.4f);
                        }
                    } else {
                        pOut[ch] = pIn[ch]; // alpha and other channels pass through untouched
                    }
                }
                pIn += c;
                pOut += c;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_color_linear_to_srgb(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        uint32_t c = in.getChannels();
        image::LinearImage out(w, h, c);

        for (uint32_t y = 0; y < h; ++y) {
            const float* pIn = in.getPixelRef(0, y);
            float* pOut = out.getPixelRef(0, y);
            for (uint32_t x = 0; x < w; ++x) {
                for (uint32_t ch = 0; ch < c; ++ch) {
                    if (ch < 3) {
                        pOut[ch] = image::linearTosRGB(pIn[ch]);
                    } else {
                        pOut[ch] = pIn[ch]; // alpha passes through
                    }
                }
                pIn += c;
                pOut += c;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_color_to_grayscale(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        uint32_t c = in.getChannels();
        image::LinearImage out(w, h, 1);

        for (uint32_t y = 0; y < h; ++y) {
            const float* pIn = in.getPixelRef(0, y);
            float* pOut = out.getPixelRef(0, y);
            for (uint32_t x = 0; x < w; ++x) {
                if (c == 1) {
                    pOut[x] = pIn[0];
                } else if (c >= 3) {
                    // Rec.709: 0.2126 R + 0.7152 G + 0.0722 B
                    pOut[x] = 0.2126f * pIn[0] + 0.7152f * pIn[1] + 0.0722f * pIn[2];
                } else {
                    pOut[x] = pIn[0];
                }
                pIn += c;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_color_srgb_bytes_to_linear(
    uint32_t width,
    uint32_t height,
    uint32_t bytes_per_row,
    uint32_t channels,
    const uint8_t* srgb_bytes
) {
    if (!srgb_bytes || width == 0 || height == 0 || channels == 0) return nullptr;
    try {
        uint32_t bpr = bytes_per_row > 0 ? bytes_per_row : width * channels;
        image::LinearImage out(width, height, channels);

        for (uint32_t y = 0; y < height; ++y) {
            const uint8_t* row = srgb_bytes + y * bpr;
            float* dst = out.getPixelRef(0, y);
            for (uint32_t x = 0; x < width; ++x) {
                for (uint32_t c = 0; c < channels; ++c) {
                    float val = row[c] / 255.0f;
                    if (c < 3) {
                        if (val <= 0.04045f) {
                            dst[c] = val * (1.0f / 12.92f);
                        } else {
                            dst[c] = std::pow((val + 0.055f) / 1.055f, 2.4f);
                        }
                    } else {
                        dst[c] = val; // alpha is linear
                    }
                }
                row += channels;
                dst += channels;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

void filament_color_linear_to_srgb_bytes(
    const FilLinearImage* src,
    uint8_t* out_bytes,
    uint32_t bytes_per_row
) {
    if (!src || !src->image.isValid() || !out_bytes) return;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        uint32_t c = in.getChannels();
        uint32_t bpr = bytes_per_row > 0 ? bytes_per_row : w * c;

        for (uint32_t y = 0; y < h; ++y) {
            const float* pIn = in.getPixelRef(0, y);
            uint8_t* row = out_bytes + y * bpr;
            for (uint32_t x = 0; x < w; ++x) {
                for (uint32_t ch = 0; ch < c; ++ch) {
                    float srgbVal = (ch < 3) ? image::linearTosRGB(pIn[ch]) : pIn[ch];
                    float clamped = std::clamp(srgbVal, 0.0f, 1.0f);
                    row[ch] = static_cast<uint8_t>(std::round(clamped * 255.0f));
                }
                pIn += c;
                row += c;
            }
        }
    } catch (...) {
    }
}

FilLinearImage* filament_color_linear_to_rgbm(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        image::LinearImage out(w, h, 4);

        for (uint32_t y = 0; y < h; ++y) {
            for (uint32_t x = 0; x < w; ++x) {
                float3 linearColor(0.0f);
                const float* p = in.getPixelRef(x, y);
                if (in.getChannels() >= 3) {
                    linearColor = float3(p[0], p[1], p[2]);
                } else if (in.getChannels() == 1) {
                    linearColor = float3(p[0]);
                }
                float4 rgbm = image::linearToRGBM(linearColor);
                float* dst = out.getPixelRef(x, y);
                dst[0] = rgbm.r;
                dst[1] = rgbm.g;
                dst[2] = rgbm.b;
                dst[3] = rgbm.a;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

FilLinearImage* filament_color_rgbm_to_linear(const FilLinearImage* src) {
    if (!src || !src->image.isValid()) return nullptr;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        image::LinearImage out(w, h, 3);

        for (uint32_t y = 0; y < h; ++y) {
            for (uint32_t x = 0; x < w; ++x) {
                const float* p = in.getPixelRef(x, y);
                float4 rgbm(p[0], p[1], p[2], in.getChannels() >= 4 ? p[3] : 1.0f);
                float3 linearColor = image::RGBMtoLinear(rgbm);
                float* dst = out.getPixelRef(x, y);
                dst[0] = linearColor.r;
                dst[1] = linearColor.g;
                dst[2] = linearColor.b;
            }
        }
        return wrapLinearImage(std::move(out));
    } catch (...) {
        return nullptr;
    }
}

void filament_color_linear_to_rgb_10_11_11_rev(
    const FilLinearImage* src,
    uint32_t* out_pixels
) {
    if (!src || !src->image.isValid() || !out_pixels) return;
    try {
        const auto& in = src->image;
        uint32_t w = in.getWidth();
        uint32_t h = in.getHeight();
        uint32_t c = in.getChannels();

        uint32_t idx = 0;
        for (uint32_t y = 0; y < h; ++y) {
            for (uint32_t x = 0; x < w; ++x) {
                const float* p = in.getPixelRef(x, y);
                float3 linearColor(0.0f);
                if (c >= 3) {
                    linearColor = float3(std::max(0.0f, p[0]), std::max(0.0f, p[1]), std::max(0.0f, p[2]));
                } else if (c == 1) {
                    linearColor = float3(std::max(0.0f, p[0]));
                }
                out_pixels[idx++] = image::linearToRGB_10_11_11_REV(linearColor);
            }
        }
    } catch (...) {
    }
}
