#ifndef FILAMENT_IMAGEIO_C_H
#define FILAMENT_IMAGEIO_C_H

#include "linear_image_c.h"
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

typedef struct FilBasisEncoderBuilder FilBasisEncoderBuilder;
typedef struct FilBasisEncoder FilBasisEncoder;

enum FilImageDecoderColorSpace {
    FIL_IMAGE_DECODER_COLOR_SPACE_LINEAR = 0,
    FIL_IMAGE_DECODER_COLOR_SPACE_SRGB = 1,
};

enum FilImageEncoderFormat {
    FIL_IMAGE_ENCODER_FORMAT_PNG = 0,
    FIL_IMAGE_ENCODER_FORMAT_PNG_LINEAR = 1,
    FIL_IMAGE_ENCODER_FORMAT_HDR = 2,
    FIL_IMAGE_ENCODER_FORMAT_RGBM = 3,
    FIL_IMAGE_ENCODER_FORMAT_PSD = 4,
    FIL_IMAGE_ENCODER_FORMAT_EXR = 5,
    FIL_IMAGE_ENCODER_FORMAT_DDS = 6,
    FIL_IMAGE_ENCODER_FORMAT_DDS_LINEAR = 7,
    FIL_IMAGE_ENCODER_FORMAT_RGB_10_11_11_REV = 8,
};

FFI_PLUGIN_EXPORT FilLinearImage* filament_image_decode(
    const uint8_t* data,
    size_t size,
    const char* source_name,
    int color_space
);

FFI_PLUGIN_EXPORT bool filament_image_encode(
    int format,
    const FilLinearImage* img,
    const char* compression,
    uint8_t** out_data,
    size_t* out_size
);

FFI_PLUGIN_EXPORT void filament_image_encode_free(uint8_t* data);

FFI_PLUGIN_EXPORT FilBasisEncoderBuilder* filament_basis_encoder_builder_create(
    uint32_t mip_count,
    bool grayscale,
    bool normals,
    bool linear
);

FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_miplevel(
    FilBasisEncoderBuilder* b,
    uint32_t mip,
    const FilLinearImage* img
);

FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_intermediate_format(
    FilBasisEncoderBuilder* b,
    bool uastc
);

FFI_PLUGIN_EXPORT FilBasisEncoder* filament_basis_encoder_builder_build(
    FilBasisEncoderBuilder* b
);

FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_destroy(
    FilBasisEncoderBuilder* b
);

FFI_PLUGIN_EXPORT bool filament_basis_encoder_encode(FilBasisEncoder* e);

FFI_PLUGIN_EXPORT size_t filament_basis_encoder_get_ktx2_byte_count(
    const FilBasisEncoder* e
);

FFI_PLUGIN_EXPORT const uint8_t* filament_basis_encoder_get_ktx2_data(
    const FilBasisEncoder* e
);

FFI_PLUGIN_EXPORT void filament_basis_encoder_destroy(FilBasisEncoder* e);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IMAGEIO_C_H
