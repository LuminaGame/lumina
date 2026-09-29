/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "buffer_descriptor_c.h"

#include <filament/Engine.h>
#include <filament/VertexBuffer.h>
#include <filament/Texture.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace filament::backend;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[BufferDescriptor C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[BufferDescriptor C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[BufferDescriptor C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) {
    return reinterpret_cast<Engine*>(p);
}

BufferDescriptor makeBufferDescriptor(
    void* data, size_t size, filament_buffer_free_fn cb, void* user) {
    if (cb == nullptr) {
        return BufferDescriptor(data, size);
    }
    return BufferDescriptor(data, size, cb, user);
}

PixelBufferDescriptor makePixelBufferDescriptor(
    void* data, size_t size, int32_t pixel_format, int32_t pixel_type,
    uint32_t stride, uint8_t alignment, filament_buffer_free_fn cb, void* user) {
    auto format = static_cast<PixelDataFormat>(pixel_format);
    auto type = static_cast<PixelDataType>(pixel_type);
    if (cb == nullptr) {
        return PixelBufferDescriptor(data, size, format, type, alignment, 0, 0, stride);
    }
    return PixelBufferDescriptor(data, size, format, type, alignment, 0, 0, stride, cb, user);
}

const void* filament_test_buffer_descriptor_peek(void* data) {
    return data;
}

void filament_test_consume_buffer_descriptor(
    void* engine, void* data, size_t size, filament_buffer_free_fn cb, void* user) {
    FFI_TRY
    if (!engine || !data || size == 0) return;
    Engine* e = toEngine(engine);
    uint32_t vertexCount = static_cast<uint32_t>((size + 11) / 12);
    if (vertexCount == 0) vertexCount = 1;

    VertexBuffer* vb = VertexBuffer::Builder()
        .vertexCount(vertexCount)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3, 0, 12)
        .build(*e);
    if (vb) {
        vb->setBufferAt(*e, 0, makeBufferDescriptor(data, size, cb, user));
        e->destroy(vb);
    }
    FFI_CATCH()
}

void filament_test_consume_pixel_buffer_descriptor(
    void* engine, void* data, size_t size, int32_t pixel_format, int32_t pixel_type,
    uint32_t stride, uint8_t alignment, filament_buffer_free_fn cb, void* user) {
    FFI_TRY
    if (!engine || !data || size == 0) return;
    Engine* e = toEngine(engine);
    Texture* tex = Texture::Builder()
        .width(4)
        .height(4)
        .levels(1)
        .sampler(Texture::Sampler::SAMPLER_2D)
        .format(Texture::InternalFormat::RGBA8)
        .build(*e);
    if (tex) {
        tex->setImage(*e, 0, makePixelBufferDescriptor(data, size, pixel_format, pixel_type, stride, alignment, cb, user));
        e->destroy(tex);
    }
    FFI_CATCH()
}
