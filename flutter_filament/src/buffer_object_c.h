/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_BUFFER_OBJECT_C_H
#define FLUTTER_FILAMENT_BUFFER_OBJECT_C_H

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

FFI_PLUGIN_EXPORT void* filament_buffer_object_create(
    void* engine,
    uint32_t byte_count,
    int32_t binding_type
);

FFI_PLUGIN_EXPORT void filament_buffer_object_set_buffer(
    void* engine,
    void* bo,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
);

FFI_PLUGIN_EXPORT uint32_t filament_buffer_object_get_byte_count(void* bo);

FFI_PLUGIN_EXPORT void filament_engine_destroy_buffer_object(void* engine, void* bo);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_BUFFER_OBJECT_C_H
