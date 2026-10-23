/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Filament's asynchronous resource path: textures, vertex buffers and index
// buffers created and filled off the calling thread, with completion reported
// through the callback bridge (kind FILAMENT_CALLBACK_KIND_ASYNC_RESOURCE,
// status FILAMENT_ASYNC_COMPLETED / FILAMENT_ASYNC_CANCELED).
//
// Every call takes a `request_id` the caller registered with the bridge. When
// the engine runs without an asynchronous mode (Engine::Config::asynchronousMode
// NONE, or a platform without threads), the same call runs synchronously and
// the callback fires COMPLETED before the function returns, so callers never
// have to branch on the mode.

#ifndef FLUTTER_FILAMENT_ASYNC_RESOURCE_C_H
#define FLUTTER_FILAMENT_ASYNC_RESOURCE_C_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "texture_c.h"
#include "vertex_buffer_c.h"

#ifndef FFI_PLUGIN_EXPORT
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* The callback bridge kind of every asynchronous resource completion. */
#define FILAMENT_CALLBACK_KIND_ASYNC_RESOURCE 2

/* Status delivered with the completion: backend::AsyncCallStatus. */
#define FILAMENT_ASYNC_COMPLETED 0
#define FILAMENT_ASYNC_CANCELED 1

/* The id of a call that ran synchronously (no asynchronous mode); never cancellable. */
#define FILAMENT_ASYNC_CALL_SYNC 0xFFFFFFFFu

FFI_PLUGIN_EXPORT bool filament_engine_is_asynchronous_mode_enabled(void* engine);
FFI_PLUGIN_EXPORT bool filament_engine_cancel_async_call(void* engine, uint32_t id);

/* Textures */
FFI_PLUGIN_EXPORT void* filament_texture_create_async(void* engine, const FilamentTextureDesc* desc, uint64_t request_id);
FFI_PLUGIN_EXPORT bool filament_texture_is_creation_complete(void* texture);
FFI_PLUGIN_EXPORT uint32_t filament_texture_set_image_async(
    void* engine, void* texture, uint8_t level,
    uint32_t xoffset, uint32_t yoffset, uint32_t zoffset,
    uint32_t width, uint32_t height, uint32_t depth,
    int32_t pixel_format, int32_t pixel_type, uint32_t stride, uint8_t alignment,
    void* data, size_t size, filament_buffer_free_fn cb, void* user,
    uint64_t request_id);

/* Vertex buffers */
FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_async(
    void* engine, uint8_t buffer_count, uint32_t vertex_count,
    int32_t attribute_count, const FilamentVertexAttributeDesc* attributes,
    bool enable_buffer_objects, bool advanced_skinning, uint64_t request_id);
FFI_PLUGIN_EXPORT bool filament_vertex_buffer_is_creation_complete(void* vb);
FFI_PLUGIN_EXPORT uint32_t filament_vertex_buffer_set_buffer_at_async(
    void* engine, void* vb, uint8_t buffer_index,
    void* data, size_t size, uint32_t byte_offset, filament_buffer_free_fn cb, void* user,
    uint64_t request_id);

/* Index buffers */
FFI_PLUGIN_EXPORT void* filament_index_buffer_create_async(
    void* engine, uint32_t index_count, int32_t buffer_type, uint64_t request_id);
FFI_PLUGIN_EXPORT bool filament_index_buffer_is_creation_complete(void* ib);
FFI_PLUGIN_EXPORT uint32_t filament_index_buffer_set_buffer_async(
    void* engine, void* ib, void* data, size_t size, uint32_t byte_offset,
    filament_buffer_free_fn cb, void* user, uint64_t request_id);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_ASYNC_RESOURCE_C_H
