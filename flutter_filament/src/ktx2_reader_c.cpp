/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "ktx2_reader_c.h"

#include <filament/Engine.h>
#include <filament/Texture.h>
#include <ktxreader/Ktx2Reader.h>
#include <utils/Panic.h>
#include <basisu_transcoder.h>
#include <algorithm>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <mutex>

using namespace filament;
using namespace ktxreader;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Ktx2Reader C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Ktx2Reader C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Ktx2Reader C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }

struct FilKtx2Reader {
    Ktx2Reader reader;
    FilKtx2Reader(Engine& engine, bool quiet) : reader(engine, quiet) {}
};

FilKtx2Reader* filament_ktx2_reader_create(void* engine, bool quiet) {
    FFI_TRY
    if (!engine) return nullptr;
    return new FilKtx2Reader(*toEngine(engine), quiet);
    FFI_CATCH(nullptr)
}

void filament_ktx2_reader_destroy(FilKtx2Reader* r) {
    FFI_TRY
    if (r) {
        delete r;
    }
    FFI_CATCH()
}

int filament_ktx2_reader_request_format(FilKtx2Reader* r, int internal_format) {
    FFI_TRY
    if (!r) return static_cast<int>(Ktx2Reader::Result::FORMAT_UNSUPPORTED);
    auto res = r->reader.requestFormat(static_cast<Texture::InternalFormat>(internal_format));
    return static_cast<int>(res);
    FFI_CATCH(static_cast<int>(Ktx2Reader::Result::FORMAT_UNSUPPORTED))
}

void filament_ktx2_reader_unrequest_format(FilKtx2Reader* r, int internal_format) {
    FFI_TRY
    if (!r) return;
    r->reader.unrequestFormat(static_cast<Texture::InternalFormat>(internal_format));
    FFI_CATCH()
}

void* filament_ktx2_reader_load(FilKtx2Reader* r, const uint8_t* data, size_t size, int transfer_function) {
    FFI_TRY
    if (!r || !data || size == 0) return nullptr;
    Texture* tex = r->reader.load(data, size, static_cast<Ktx2Reader::TransferFunction>(transfer_function));
    return tex;
    FFI_CATCH(nullptr)
}

struct FilKtx2Async {
    Ktx2Reader::Async* asyncPtr = nullptr;
    FilKtx2Async(Ktx2Reader::Async* p) : asyncPtr(p) {}
};

FilKtx2Async* filament_ktx2_reader_async_create(FilKtx2Reader* r, const uint8_t* data, size_t size, int transfer_function) {
    FFI_TRY
    if (!r || !data || size == 0) return nullptr;
    auto* asyncObj = r->reader.asyncCreate(data, size, static_cast<Ktx2Reader::TransferFunction>(transfer_function));
    if (!asyncObj) return nullptr;
    return new FilKtx2Async(asyncObj);
    FFI_CATCH(nullptr)
}

void* filament_ktx2_async_get_texture(const FilKtx2Async* a) {
    FFI_TRY
    if (!a || !a->asyncPtr) return nullptr;
    return a->asyncPtr->getTexture();
    FFI_CATCH(nullptr)
}

int filament_ktx2_async_do_transcoding(FilKtx2Async* a) {
    FFI_TRY
    if (!a || !a->asyncPtr) return static_cast<int>(Ktx2Reader::Result::UNCOMPRESSED_TRANSCODE_FAILURE);
    auto res = a->asyncPtr->doTranscoding();
    return static_cast<int>(res);
    FFI_CATCH(static_cast<int>(Ktx2Reader::Result::UNCOMPRESSED_TRANSCODE_FAILURE))
}

void filament_ktx2_async_upload_images(FilKtx2Async* a) {
    FFI_TRY
    if (!a || !a->asyncPtr) return;
    a->asyncPtr->uploadImages();
    FFI_CATCH()
}

void filament_ktx2_reader_async_destroy(FilKtx2Reader* r, FilKtx2Async* a) {
    FFI_TRY
    if (r && a && a->asyncPtr) {
        r->reader.asyncDestroy(&a->asyncPtr);
    }
    if (a) {
        delete a;
    }
    FFI_CATCH()
}

uint8_t* filament_ktx2_decode_rgba8(const uint8_t* data, size_t size, uint32_t max_edge,
                                    uint32_t* out_width, uint32_t* out_height) {
    FFI_TRY
    if (!data || size == 0 || size > UINT32_MAX || !out_width || !out_height) return nullptr;
    static std::once_flag initOnce;
    std::call_once(initOnce, [] { basist::basisu_transcoder_init(); });

    basist::ktx2_transcoder transcoder;
    if (!transcoder.init(data, static_cast<uint32_t>(size))) return nullptr;
    if (transcoder.is_hdr() || transcoder.get_levels() == 0) return nullptr;
    if (!transcoder.start_transcoding()) return nullptr;

    uint32_t level = 0;
    if (max_edge > 0) {
        while (level + 1 < transcoder.get_levels()) {
            basist::ktx2_image_level_info info;
            if (!transcoder.get_image_level_info(info, level, 0, 0)) return nullptr;
            if (std::max(info.m_orig_width, info.m_orig_height) <= max_edge) break;
            level++;
        }
    }
    basist::ktx2_image_level_info info;
    if (!transcoder.get_image_level_info(info, level, 0, 0)) return nullptr;
    const uint32_t width = info.m_orig_width;
    const uint32_t height = info.m_orig_height;
    if (width == 0 || height == 0) return nullptr;

    auto* pixels = static_cast<uint8_t*>(std::malloc(size_t(width) * height * 4));
    if (!pixels) return nullptr;
    // A private transcoder state (the shared one is not thread safe); clear() initialises it, its
    // constructor leaves the cached level index undefined.
    basist::ktx2_transcoder_state state;
    state.clear();
    if (!transcoder.transcode_image_level(level, 0, 0, pixels, width * height,
            basist::transcoder_texture_format::cTFRGBA32, 0, width, height, -1, -1, &state)) {
        std::free(pixels);
        return nullptr;
    }
    *out_width = width;
    *out_height = height;
    return pixels;
    FFI_CATCH(nullptr)
}

void filament_ktx2_decode_free(uint8_t* pixels) {
    std::free(pixels);
}
