// Desktop only: imageio's full encoders and decoders are not in Filament's WebAssembly and
// Android builds (Android has imageio-lite). Web builds get src/web_stubs_c.cpp
// (tool/web/gen_web_stubs.mjs); Android builds the stubs at the end of this file.
#if !defined(__EMSCRIPTEN__) && !defined(__ANDROID__)

#include "imageio_c.h"
#include "linear_image_internal.h"
#include <imageio/ImageDecoder.h>
#include <imageio/ImageEncoder.h>
#include <imageio/BasisEncoder.h>
#include <sstream>
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <string>

struct FilBasisEncoderBuilder {
    image::BasisEncoder::Builder builder;
    FilBasisEncoderBuilder(uint32_t mips) : builder(mips, 1) {}
};

struct FilBasisEncoder {
    image::BasisEncoder* encoder;
    FilBasisEncoder(image::BasisEncoder* enc) : encoder(enc) {}
    ~FilBasisEncoder() { delete encoder; }
};

FilLinearImage* filament_image_decode(
    const uint8_t* data,
    size_t size,
    const char* source_name,
    int color_space
) {
    if (!data || size == 0) return nullptr;
    try {
        std::string s(reinterpret_cast<const char*>(data), size);
        std::istringstream stream(s);
        std::string srcName = source_name ? source_name : "";
        auto cs = static_cast<image::ImageDecoder::ColorSpace>(color_space);
        auto img = image::ImageDecoder::decode(stream, srcName, cs);
        if (!img.isValid()) return nullptr;
        return wrapLinearImage(std::move(img));
    } catch (...) {
        return nullptr;
    }
}

bool filament_image_encode(
    int format,
    const FilLinearImage* img,
    const char* compression,
    uint8_t** out_data,
    size_t* out_size
) {
    if (!img || !img->image.isValid() || !out_data || !out_size) return false;
    try {
        std::ostringstream ss(std::ios::binary | std::ios::out);
        auto fmt = static_cast<image::ImageEncoder::Format>(format);
        std::string comp = compression ? compression : "";
        bool ok = image::ImageEncoder::encode(ss, fmt, img->image, comp, "");
        if (!ok) return false;
        std::string str = ss.str();
        if (str.empty()) return false;
        uint8_t* buf = static_cast<uint8_t*>(std::malloc(str.size()));
        if (!buf) return false;
        std::memcpy(buf, str.data(), str.size());
        *out_data = buf;
        *out_size = str.size();
        return true;
    } catch (...) {
        return false;
    }
}

void filament_image_encode_free(uint8_t* data) {
    if (data) {
        std::free(data);
    }
}

FilBasisEncoderBuilder* filament_basis_encoder_builder_create(
    uint32_t mip_count,
    bool grayscale,
    bool normals,
    bool linear
) {
    if (mip_count == 0) mip_count = 1;
    try {
        auto* b = new FilBasisEncoderBuilder(mip_count);
        b->builder.grayscale(grayscale);
        b->builder.normals(normals);
        b->builder.linear(linear);
        return b;
    } catch (...) {
        return nullptr;
    }
}

void filament_basis_encoder_builder_miplevel(
    FilBasisEncoderBuilder* b,
    uint32_t mip,
    const FilLinearImage* img
) {
    if (!b || !img || !img->image.isValid()) return;
    try {
        b->builder.miplevel(mip, 0, img->image);
    } catch (...) {
    }
}

void filament_basis_encoder_builder_intermediate_format(
    FilBasisEncoderBuilder* b,
    bool uastc
) {
    if (!b) return;
    try {
        b->builder.intermediateFormat(
            uastc ? image::BasisEncoder::IntermediateFormat::UASTC
                  : image::BasisEncoder::IntermediateFormat::ETC1S
        );
    } catch (...) {
    }
}

FilBasisEncoder* filament_basis_encoder_builder_build(
    FilBasisEncoderBuilder* b
) {
    if (!b) return nullptr;
    try {
        auto* enc = b->builder.build();
        delete b;
        if (!enc) return nullptr;
        return new FilBasisEncoder(enc);
    } catch (...) {
        delete b;
        return nullptr;
    }
}

void filament_basis_encoder_builder_destroy(
    FilBasisEncoderBuilder* b
) {
    delete b;
}

bool filament_basis_encoder_encode(
    FilBasisEncoder* enc
) {
    if (!enc || !enc->encoder) return false;
    try {
        return enc->encoder->encode();
    } catch (...) {
        return false;
    }
}

const uint8_t* filament_basis_encoder_get_ktx2_data(
    const FilBasisEncoder* enc
) {
    if (!enc || !enc->encoder) return nullptr;
    return enc->encoder->getKtx2Data();
}

size_t filament_basis_encoder_get_ktx2_byte_count(
    const FilBasisEncoder* enc
) {
    if (!enc || !enc->encoder) return 0;
    return enc->encoder->getKtx2ByteCount();
}

void filament_basis_encoder_destroy(
    FilBasisEncoder* enc
) {
    delete enc;
}

#endif  // !__EMSCRIPTEN__ && !__ANDROID__

#if defined(__ANDROID__)
// Every entry point stays exported; each reports "unsupported" the way the web stubs do:
// no image, no encoded bytes, no encoder.
#include "imageio_c.h"

#include <cstdlib>

extern "C" {

FilLinearImage* filament_image_decode(const uint8_t*, size_t, const char*, int) { return nullptr; }
bool filament_image_encode(int, const FilLinearImage*, const char*, uint8_t** out_data, size_t* out_size) {
    if (out_data) *out_data = nullptr;
    if (out_size) *out_size = 0;
    return false;
}
void filament_image_encode_free(uint8_t* data) { free(data); }
FilBasisEncoderBuilder* filament_basis_encoder_builder_create(uint32_t, bool, bool, bool) { return nullptr; }
void filament_basis_encoder_builder_miplevel(FilBasisEncoderBuilder*, uint32_t, const FilLinearImage*) {}
void filament_basis_encoder_builder_intermediate_format(FilBasisEncoderBuilder*, bool) {}
FilBasisEncoder* filament_basis_encoder_builder_build(FilBasisEncoderBuilder*) { return nullptr; }
void filament_basis_encoder_builder_destroy(FilBasisEncoderBuilder*) {}
bool filament_basis_encoder_encode(FilBasisEncoder*) { return false; }
size_t filament_basis_encoder_get_ktx2_byte_count(const FilBasisEncoder*) { return 0; }
const uint8_t* filament_basis_encoder_get_ktx2_data(const FilBasisEncoder*) { return nullptr; }
void filament_basis_encoder_destroy(FilBasisEncoder*) {}

}  // extern "C"
#endif  // __ANDROID__
