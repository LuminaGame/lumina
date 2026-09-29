/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "vertex_buffer_c.h"
#include "buffer_descriptor_c.h"

#include <filament/Engine.h>
#include <filament/VertexBuffer.h>
#include <filament/BufferObject.h>
#include <filament/MaterialEnums.h>
#include <backend/DriverEnums.h>
#include <backend/BufferDescriptor.h>
#include <utils/Panic.h>

#include <cstring>
#include <cstdlib>
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

#define FFI_CATCH_VOID()                                                       \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
  }

static inline Engine* toEngine(void* p) {
    return reinterpret_cast<Engine*>(p);
}

static inline VertexBuffer* toVertexBuffer(void* p) {
    return reinterpret_cast<VertexBuffer*>(p);
}

void* filament_vertex_buffer_create(
    void* engine,
    uint8_t buffer_count,
    uint32_t vertex_count,
    int32_t attribute_count,
    const FilamentVertexAttributeDesc* attributes,
    bool enable_buffer_objects,
    bool advanced_skinning
) {
    FFI_TRY
    if (!engine || vertex_count == 0 || buffer_count == 0) return nullptr;

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
            if (desc.normalized) {
                builder.normalized(attr, true);
            }
        }
    }

    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_vertex_buffer_create_legacy(void* engine, uint32_t vertex_count, uint8_t buffer_count) {
    FilamentVertexAttributeDesc attrs[1] = {
        { static_cast<int32_t>(VertexAttribute::POSITION), 0, static_cast<int32_t>(backend::ElementType::FLOAT3), 0, 12, false }
    };
    return filament_vertex_buffer_create(engine, buffer_count, vertex_count, 1, attrs, false, false);
}

void* filament_vertex_buffer_create_with_color(void* engine, uint32_t vertex_count, uint8_t buffer_count) {
    FilamentVertexAttributeDesc attrs[2] = {
        { static_cast<int32_t>(VertexAttribute::POSITION), 0, static_cast<int32_t>(backend::ElementType::FLOAT3), 0, 12, false },
        { static_cast<int32_t>(VertexAttribute::COLOR), 0, static_cast<int32_t>(backend::ElementType::FLOAT4), 12, 16, false }
    };
    return filament_vertex_buffer_create(engine, buffer_count, vertex_count, 2, attrs, false, false);
}

void* filament_vertex_buffer_create_with_uv(void* engine, uint32_t vertex_count, uint8_t buffer_count) {
    FilamentVertexAttributeDesc attrs[2] = {
        { static_cast<int32_t>(VertexAttribute::POSITION), 0, static_cast<int32_t>(backend::ElementType::FLOAT3), 0, 12, false },
        { static_cast<int32_t>(VertexAttribute::UV0), 0, static_cast<int32_t>(backend::ElementType::FLOAT2), 12, 8, false }
    };
    return filament_vertex_buffer_create(engine, buffer_count, vertex_count, 2, attrs, false, false);
}

void filament_vertex_buffer_set_buffer_at(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
) {
    FFI_TRY
    if (!engine || !vb || !data || size == 0) return;
    auto bd = makeBufferDescriptor(data, size, cb, user);
    toVertexBuffer(vb)->setBufferAt(*toEngine(engine), buffer_index, std::move(bd), byte_offset);
    FFI_CATCH_VOID()
}

void filament_vertex_buffer_set_data(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    const void* data,
    uint32_t size_in_bytes
) {
    FFI_TRY
    if (!engine || !vb || !data || size_in_bytes == 0) return;
    void* copy = malloc(size_in_bytes);
    if (!copy) return;
    memcpy(copy, data, size_in_bytes);
    filament_vertex_buffer_set_buffer_at(
        engine,
        vb,
        buffer_index,
        copy,
        size_in_bytes,
        0,
        [](void* buffer, size_t, void*) { free(buffer); },
        nullptr
    );
    FFI_CATCH_VOID()
}

uint32_t filament_vertex_buffer_get_vertex_count(void* vb) {
    FFI_TRY
    if (!vb) return 0;
    return static_cast<uint32_t>(toVertexBuffer(vb)->getVertexCount());
    FFI_CATCH(0)
}

void filament_vertex_buffer_set_buffer_object_at(
    void* engine,
    void* vb,
    uint8_t buffer_index,
    void* bo
) {
    FFI_TRY
    if (!engine || !vb || !bo) return;
    toVertexBuffer(vb)->setBufferObjectAt(*toEngine(engine), buffer_index, reinterpret_cast<BufferObject*>(bo));
    FFI_CATCH_VOID()
}

void filament_engine_destroy_vertex_buffer(void* engine, void* vb) {
    FFI_TRY
    if (!engine || !vb) return;
    toEngine(engine)->destroy(toVertexBuffer(vb));
    FFI_CATCH_VOID()
}
