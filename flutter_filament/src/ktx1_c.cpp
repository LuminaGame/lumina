/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "ktx1_c.h"

#include <filament/Engine.h>
#include <filament/Texture.h>
#include <image/Ktx1Bundle.h>
#include <ktxreader/Ktx1Reader.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace image;
using namespace ktxreader;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Ktx1 C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Ktx1 C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Ktx1 C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

struct FilKtx1Bundle {
    Ktx1Bundle* bundle = nullptr;
    FilKtx1Bundle(Ktx1Bundle* b) : bundle(b) {}
    ~FilKtx1Bundle() {
        if (bundle) {
            delete bundle;
            bundle = nullptr;
        }
    }
};

FilKtx1Bundle* filament_ktx1_bundle_create(const uint8_t* bytes, uint32_t nbytes) {
    FFI_TRY
    if (!bytes || nbytes == 0) return nullptr;
    auto* b = new Ktx1Bundle(bytes, nbytes);
    return new FilKtx1Bundle(b);
    FFI_CATCH(nullptr)
}

FilKtx1Bundle* filament_ktx1_bundle_create_empty(uint32_t num_mip_levels, uint32_t array_length, bool is_cubemap) {
    FFI_TRY
    auto* b = new Ktx1Bundle(num_mip_levels, array_length, is_cubemap);
    return new FilKtx1Bundle(b);
    FFI_CATCH(nullptr)
}

void filament_ktx1_bundle_destroy(FilKtx1Bundle* b) {
    FFI_TRY
    if (b) {
        delete b;
    }
    FFI_CATCH()
}

uint32_t filament_ktx1_bundle_get_num_mip_levels(const FilKtx1Bundle* b) {
    FFI_TRY
    if (!b || !b->bundle) return 0;
    return b->bundle->getNumMipLevels();
    FFI_CATCH(0)
}

uint32_t filament_ktx1_bundle_get_array_length(const FilKtx1Bundle* b) {
    FFI_TRY
    if (!b || !b->bundle) return 0;
    return b->bundle->getArrayLength();
    FFI_CATCH(0)
}

bool filament_ktx1_bundle_is_cubemap(const FilKtx1Bundle* b) {
    FFI_TRY
    if (!b || !b->bundle) return false;
    return b->bundle->isCubemap();
    FFI_CATCH(false)
}

bool filament_ktx1_bundle_get_spherical_harmonics(FilKtx1Bundle* b, float* out) {
    FFI_TRY
    if (!b || !b->bundle || !out) return false;
    return b->bundle->getSphericalHarmonics(reinterpret_cast<filament::math::float3*>(out));
    FFI_CATCH(false)
}

const char* filament_ktx1_bundle_get_metadata(const FilKtx1Bundle* b, const char* key) {
    FFI_TRY
    if (!b || !b->bundle || !key) return nullptr;
    return b->bundle->getMetadata(key);
    FFI_CATCH(nullptr)
}

void filament_ktx1_bundle_set_metadata(FilKtx1Bundle* b, const char* key, const char* value) {
    FFI_TRY
    if (!b || !b->bundle || !key || !value) return;
    b->bundle->setMetadata(key, value);
    FFI_CATCH()
}

bool filament_ktx1_bundle_get_blob(const FilKtx1Bundle* b, uint32_t mip, uint32_t face, uint8_t** out_data, uint32_t* out_size) {
    FFI_TRY
    if (!b || !b->bundle || !out_data || !out_size) return false;
    KtxBlobIndex idx = { mip, 0, face };
    return b->bundle->getBlob(idx, out_data, out_size);
    FFI_CATCH(false)
}

bool filament_ktx1_bundle_set_blob(FilKtx1Bundle* b, uint32_t mip, uint32_t face, const uint8_t* data, uint32_t size) {
    FFI_TRY
    if (!b || !b->bundle || !data || size == 0) return false;
    KtxBlobIndex idx = { mip, 0, face };
    return b->bundle->setBlob(idx, data, size);
    FFI_CATCH(false)
}

uint32_t filament_ktx1_bundle_get_serialized_length(const FilKtx1Bundle* b) {
    FFI_TRY
    if (!b || !b->bundle) return 0;
    return b->bundle->getSerializedLength();
    FFI_CATCH(0)
}

bool filament_ktx1_bundle_serialize(const FilKtx1Bundle* b, uint8_t* out, uint32_t nbytes) {
    FFI_TRY
    if (!b || !b->bundle || !out || nbytes == 0) return false;
    return b->bundle->serialize(out, nbytes);
    FFI_CATCH(false)
}

void* filament_ktx1_reader_create_texture(void* engine, FilKtx1Bundle* bundle, bool srgb) {
    FFI_TRY
    if (!engine || !bundle || !bundle->bundle) return nullptr;
    auto* e = reinterpret_cast<Engine*>(engine);
    Ktx1Bundle* inner = bundle->bundle;
    bundle->bundle = nullptr; // transfer ownership to Ktx1Reader
    Texture* tex = Ktx1Reader::createTexture(e, inner, srgb);
    return tex;
    FFI_CATCH(nullptr)
}
