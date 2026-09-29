/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_KTX2_READER_C_H
#define FLUTTER_FILAMENT_KTX2_READER_C_H

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

typedef struct FilKtx2Reader FilKtx2Reader;
typedef struct FilKtx2Async FilKtx2Async;

FFI_PLUGIN_EXPORT FilKtx2Reader* filament_ktx2_reader_create(void* engine, bool quiet);
FFI_PLUGIN_EXPORT void filament_ktx2_reader_destroy(FilKtx2Reader* r);
FFI_PLUGIN_EXPORT int filament_ktx2_reader_request_format(FilKtx2Reader* r, int internal_format);
FFI_PLUGIN_EXPORT void filament_ktx2_reader_unrequest_format(FilKtx2Reader* r, int internal_format);
FFI_PLUGIN_EXPORT void* filament_ktx2_reader_load(FilKtx2Reader* r, const uint8_t* data, size_t size, int transfer_function);

// Async Interface
FFI_PLUGIN_EXPORT FilKtx2Async* filament_ktx2_reader_async_create(FilKtx2Reader* r, const uint8_t* data, size_t size, int transfer_function);
FFI_PLUGIN_EXPORT void* filament_ktx2_async_get_texture(const FilKtx2Async* a);
FFI_PLUGIN_EXPORT int filament_ktx2_async_do_transcoding(FilKtx2Async* a);
FFI_PLUGIN_EXPORT void filament_ktx2_async_upload_images(FilKtx2Async* a);
FFI_PLUGIN_EXPORT void filament_ktx2_reader_async_destroy(FilKtx2Reader* r, FilKtx2Async* a);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_KTX2_READER_C_H
