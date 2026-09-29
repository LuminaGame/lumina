/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "ktx2_reader_c.h"

#include <filament/Engine.h>
#include <filament/Texture.h>
#include <ktxreader/Ktx2Reader.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

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
