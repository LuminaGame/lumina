/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_VERTEX_BUFFER_C_H
#define FLUTTER_FILAMENT_VERTEX_BUFFER_C_H

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

typedef struct {
    int32_t attribute;    /* VertexAttribute */
    uint8_t buffer_index;
    int32_t type;         /* AttributeType (backend::ElementType, 26 values) */
    uint32_t byte_offset;
    uint8_t byte_stride;
    bool normalized;
} FilamentVertexAttributeDesc;

FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create(
    void* engine,
    uint8_t buffer_count,
    uint32_t vertex_count,
    int32_t attribute_count,
    const FilamentVertexAttributeDesc* attributes,
    bool enable_buffer_objects,
    bool advanced_skinning
);

// Backward compatibility preset creators
FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_legacy(void* engine, uint32_t vertex_count, uint8_t buffer_count);
FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_color(void* engine, uint32_t vertex_count, uint8_t buffer_count);
FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_uv(void* engine, uint32_t vertex_count, uint8_t buffer_count);

FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_at(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
);

FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_data(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    const void* data,
    uint32_t size_in_bytes
);

FFI_PLUGIN_EXPORT uint32_t filament_vertex_buffer_get_vertex_count(void* vb);

FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_object_at(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    void* bo
);

FFI_PLUGIN_EXPORT void filament_engine_destroy_vertex_buffer(void* engine, void* vb);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_VERTEX_BUFFER_C_H
