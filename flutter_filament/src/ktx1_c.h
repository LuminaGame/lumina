/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_KTX1_C_H
#define FLUTTER_FILAMENT_KTX1_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FilKtx1Bundle FilKtx1Bundle;

FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create(const uint8_t* bytes, uint32_t nbytes);
FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create_empty(uint32_t num_mip_levels, uint32_t array_length, bool is_cubemap);
FFI_PLUGIN_EXPORT void filament_ktx1_bundle_destroy(FilKtx1Bundle* b);
FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_num_mip_levels(const FilKtx1Bundle* b);
FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_array_length(const FilKtx1Bundle* b);
FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_is_cubemap(const FilKtx1Bundle* b);
FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_spherical_harmonics(FilKtx1Bundle* b, float* out);
FFI_PLUGIN_EXPORT const char* filament_ktx1_bundle_get_metadata(const FilKtx1Bundle* b, const char* key);
FFI_PLUGIN_EXPORT void filament_ktx1_bundle_set_metadata(FilKtx1Bundle* b, const char* key, const char* value);
FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_blob(const FilKtx1Bundle* b, uint32_t mip, uint32_t face, uint8_t** out_data, uint32_t* out_size);
FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_set_blob(FilKtx1Bundle* b, uint32_t mip, uint32_t face, const uint8_t* data, uint32_t size);
FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_serialized_length(const FilKtx1Bundle* b);
FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_serialize(const FilKtx1Bundle* b, uint8_t* out, uint32_t nbytes);

FFI_PLUGIN_EXPORT void* filament_ktx1_reader_create_texture(void* engine, FilKtx1Bundle* bundle, bool srgb);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_KTX1_C_H
