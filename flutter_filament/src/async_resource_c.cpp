/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "async_resource_c.h"
#include "buffer_descriptor_c.h"
#include "callback_bridge_c.h"

#include <backend/DriverEnums.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/Texture.h>
#include <filament/VertexBuffer.h>
#include <utils/Panic.h>

#include <cstdio>
#include <exception>

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_value)                                                \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
    return return_value;                                                       \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
    return return_value;                                                       \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
    return return_value;                                                       \
  }

namespace {

Engine* toEngine(void* e) { return static_cast<Engine*>(e); }
Texture* toTexture(void* t) { return static_cast<Texture*>(t); }
VertexBuffer* toVertexBuffer(void* v) { return static_cast<VertexBuffer*>(v); }
IndexBuffer* toIndexBuffer(void* i) { return static_cast<IndexBuffer*>(i); }

int32_t statusOf(backend::AsyncCallStatus s) {
    return s == backend::AsyncCallStatus::COMPLETED ? FILAMENT_ASYNC_COMPLETED : FILAMENT_ASYNC_CANCELED;
}

void complete(uint64_t request_id, backend::AsyncCallStatus s) {
    fireCallback(request_id, FILAMENT_CALLBACK_KIND_ASYNC_RESOURCE, statusOf(s), nullptr, 0);
}

void completeNow(uint64_t request_id) {
    fireCallback(request_id, FILAMENT_CALLBACK_KIND_ASYNC_RESOURCE, FILAMENT_ASYNC_COMPLETED, nullptr, 0);
}

bool asyncOn(void* engine) { return toEngine(engine)->isAsynchronousModeEnabled(); }

// The texture builder the synchronous path uses (texture_c.cpp), kept in step.
Texture::Builder textureBuilder(const FilamentTextureDesc* desc) {
    Texture::Builder builder;
    builder.width(desc->width > 0 ? desc->width : 1)
           .height(desc->height > 0 ? desc->height : 1)
           .depth(desc->depth > 0 ? desc->depth : 1)
           .levels(desc->levels > 0 ? desc->levels : 1)
           .sampler(static_cast<backend::SamplerType>(desc->sampler_type))
           .format(static_cast<backend::TextureFormat>(desc->internal_format));
    if (desc->samples > 1) builder.samples(desc->samples);
    if (desc->usage != 0) builder.usage(static_cast<backend::TextureUsage>(desc->usage));
    if (desc->has_swizzle) {
        builder.swizzle(
            static_cast<backend::TextureSwizzle>(desc->swizzle[0]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[1]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[2]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[3]));
    }
    if (desc->import_handle != 0) builder.import(desc->import_handle);
    return builder;
}

VertexBuffer::Builder vertexBufferBuilder(uint8_t buffer_count, uint32_t vertex_count,
        int32_t attribute_count, const FilamentVertexAttributeDesc* attributes,
        bool enable_buffer_objects, bool advanced_skinning) {
    VertexBuffer::Builder builder;
    builder.bufferCount(buffer_count)
           .vertexCount(vertex_count)
           .enableBufferObjects(enable_buffer_objects)
           .advancedSkinning(advanced_skinning);
    if (attributes && attribute_count > 0) {
        for (int32_t i = 0; i < attribute_count; ++i) {
            const auto& desc = attributes[i];
            auto attr = static_cast<VertexAttribute>(desc.attribute);
            auto elemType = static_cast<VertexBuffer::AttributeType>(desc.type);
            builder.attribute(attr, desc.buffer_index, elemType, desc.byte_offset, desc.byte_stride);
            if (desc.normalized) builder.normalized(attr, true);
        }
    }
    return builder;
}

} // namespace

bool filament_engine_is_asynchronous_mode_enabled(void* engine) {
    FFI_TRY
    if (!engine) return false;
    return asyncOn(engine);
    FFI_CATCH(false)
}

bool filament_engine_cancel_async_call(void* engine, uint32_t id) {
    FFI_TRY
    if (!engine || id == FILAMENT_ASYNC_CALL_SYNC) return false;
    return toEngine(engine)->cancelAsyncCall(static_cast<backend::AsyncCallId>(id));
    FFI_CATCH(false)
}

// --- textures ---------------------------------------------------------------

void* filament_texture_create_async(void* engine, const FilamentTextureDesc* desc, uint64_t request_id) {
    FFI_TRY
    if (!engine || !desc) return nullptr;
    Texture::Builder builder = textureBuilder(desc);
    if (!asyncOn(engine) || desc->import_handle != 0) {
        Texture* t = builder.build(*toEngine(engine));
        if (t) completeNow(request_id);
        return t;
    }
    builder.async(nullptr, [request_id](Texture*, void*, backend::AsyncCallStatus s) { complete(request_id, s); });
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

bool filament_texture_is_creation_complete(void* texture) {
    FFI_TRY
    if (!texture) return false;
    return toTexture(texture)->isCreationComplete();
    FFI_CATCH(false)
}

uint32_t filament_texture_set_image_async(
    void* engine, void* texture, uint8_t level,
    uint32_t xoffset, uint32_t yoffset, uint32_t zoffset,
    uint32_t width, uint32_t height, uint32_t depth,
    int32_t pixel_format, int32_t pixel_type, uint32_t stride, uint8_t alignment,
    void* data, size_t size, filament_buffer_free_fn cb, void* user,
    uint64_t request_id) {
    FFI_TRY
    if (!engine || !texture || !data || size == 0) return FILAMENT_ASYNC_CALL_SYNC;
    auto pb = makePixelBufferDescriptor(data, size, pixel_format, pixel_type, stride, alignment, cb, user);
    Texture* t = toTexture(texture);
    Engine* e = toEngine(engine);
    if (!asyncOn(engine)) {
        t->setImage(*e, level, xoffset, yoffset, zoffset, width, height, depth, std::move(pb));
        completeNow(request_id);
        return FILAMENT_ASYNC_CALL_SYNC;
    }
    return static_cast<uint32_t>(t->setImageAsync(*e, level, xoffset, yoffset, zoffset, width, height, depth,
            std::move(pb), nullptr,
            [request_id](Texture*, void*, backend::AsyncCallStatus s) { complete(request_id, s); }));
    FFI_CATCH(FILAMENT_ASYNC_CALL_SYNC)
}

// --- vertex buffers ---------------------------------------------------------

void* filament_vertex_buffer_create_async(
    void* engine, uint8_t buffer_count, uint32_t vertex_count,
    int32_t attribute_count, const FilamentVertexAttributeDesc* attributes,
    bool enable_buffer_objects, bool advanced_skinning, uint64_t request_id) {
    FFI_TRY
    if (!engine || vertex_count == 0 || buffer_count == 0) return nullptr;
    VertexBuffer::Builder builder = vertexBufferBuilder(buffer_count, vertex_count, attribute_count, attributes,
            enable_buffer_objects, advanced_skinning);
    if (!asyncOn(engine)) {
        VertexBuffer* vb = builder.build(*toEngine(engine));
        if (vb) completeNow(request_id);
        return vb;
    }
    builder.async(nullptr, [request_id](VertexBuffer*, void*, backend::AsyncCallStatus s) { complete(request_id, s); });
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

bool filament_vertex_buffer_is_creation_complete(void* vb) {
    FFI_TRY
    if (!vb) return false;
    return toVertexBuffer(vb)->isCreationComplete();
    FFI_CATCH(false)
}

uint32_t filament_vertex_buffer_set_buffer_at_async(
    void* engine, void* vb, uint8_t buffer_index,
    void* data, size_t size, uint32_t byte_offset, filament_buffer_free_fn cb, void* user,
    uint64_t request_id) {
    FFI_TRY
    if (!engine || !vb || !data || size == 0) return FILAMENT_ASYNC_CALL_SYNC;
    auto bd = makeBufferDescriptor(data, size, cb, user);
    VertexBuffer* v = toVertexBuffer(vb);
    Engine* e = toEngine(engine);
    if (!asyncOn(engine)) {
        v->setBufferAt(*e, buffer_index, std::move(bd), byte_offset);
        completeNow(request_id);
        return FILAMENT_ASYNC_CALL_SYNC;
    }
    return static_cast<uint32_t>(v->setBufferAtAsync(*e, buffer_index, std::move(bd), byte_offset, nullptr,
            [request_id](VertexBuffer*, void*, backend::AsyncCallStatus s) { complete(request_id, s); }));
    FFI_CATCH(FILAMENT_ASYNC_CALL_SYNC)
}

// --- index buffers ----------------------------------------------------------

void* filament_index_buffer_create_async(void* engine, uint32_t index_count, int32_t buffer_type, uint64_t request_id) {
    FFI_TRY
    if (!engine || index_count == 0) return nullptr;
    IndexBuffer::IndexType type = (buffer_type == static_cast<int32_t>(backend::ElementType::UINT))
        ? IndexBuffer::IndexType::UINT
        : IndexBuffer::IndexType::USHORT;
    IndexBuffer::Builder builder;
    builder.indexCount(index_count).bufferType(type);
    if (!asyncOn(engine)) {
        IndexBuffer* ib = builder.build(*toEngine(engine));
        if (ib) completeNow(request_id);
        return ib;
    }
    builder.async(nullptr, [request_id](IndexBuffer*, void*, backend::AsyncCallStatus s) { complete(request_id, s); });
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

bool filament_index_buffer_is_creation_complete(void* ib) {
    FFI_TRY
    if (!ib) return false;
    return toIndexBuffer(ib)->isCreationComplete();
    FFI_CATCH(false)
}

uint32_t filament_index_buffer_set_buffer_async(
    void* engine, void* ib, void* data, size_t size, uint32_t byte_offset,
    filament_buffer_free_fn cb, void* user, uint64_t request_id) {
    FFI_TRY
    if (!engine || !ib || !data || size == 0) return FILAMENT_ASYNC_CALL_SYNC;
    auto bd = makeBufferDescriptor(data, size, cb, user);
    IndexBuffer* i = toIndexBuffer(ib);
    Engine* e = toEngine(engine);
    if (!asyncOn(engine)) {
        i->setBuffer(*e, std::move(bd), byte_offset);
        completeNow(request_id);
        return FILAMENT_ASYNC_CALL_SYNC;
    }
    return static_cast<uint32_t>(i->setBufferAsync(*e, std::move(bd), byte_offset, nullptr,
            [request_id](IndexBuffer*, void*, backend::AsyncCallStatus s) { complete(request_id, s); }));
    FFI_CATCH(FILAMENT_ASYNC_CALL_SYNC)
}
