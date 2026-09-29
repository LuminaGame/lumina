/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_INDEX_BUFFER_C_H
#define FLUTTER_FILAMENT_INDEX_BUFFER_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "buffer_descriptor_c.h"

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void* filament_index_buffer_create(
    void* engine,
    uint32_t index_count,
    int32_t buffer_type
);

FFI_PLUGIN_EXPORT void filament_index_buffer_set_buffer(
    void* engine,
    void* ib,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
);

FFI_PLUGIN_EXPORT void filament_index_buffer_set_data(
    void* engine,
    void* ib,
    const void* data,
    uint32_t size_in_bytes
);

FFI_PLUGIN_EXPORT uint32_t filament_index_buffer_get_index_count(void* ib);

FFI_PLUGIN_EXPORT void filament_engine_destroy_index_buffer(void* engine, void* ib);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_INDEX_BUFFER_C_H
