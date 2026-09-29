/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "index_buffer_c.h"
#include "buffer_descriptor_c.h"

#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
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

static inline IndexBuffer* toIndexBuffer(void* p) {
    return reinterpret_cast<IndexBuffer*>(p);
}

void* filament_index_buffer_create(
    void* engine,
    uint32_t index_count,
    int32_t buffer_type
) {
    FFI_TRY
    if (!engine || index_count == 0) return nullptr;

    IndexBuffer::IndexType type = (buffer_type == static_cast<int32_t>(backend::ElementType::UINT))
        ? IndexBuffer::IndexType::UINT
        : IndexBuffer::IndexType::USHORT;

    return IndexBuffer::Builder()
        .indexCount(index_count)
        .bufferType(type)
        .build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_index_buffer_set_buffer(
    void* engine,
    void* ib,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
) {
    FFI_TRY
    if (!engine || !ib || !data || size == 0) return;
    auto bd = makeBufferDescriptor(data, size, cb, user);
    toIndexBuffer(ib)->setBuffer(*toEngine(engine), std::move(bd), byte_offset);
    FFI_CATCH_VOID()
}

void filament_index_buffer_set_data(
    void* engine,
    void* ib,
    const void* data,
    uint32_t size_in_bytes
) {
    FFI_TRY
    if (!engine || !ib || !data || size_in_bytes == 0) return;
    void* copy = malloc(size_in_bytes);
    if (!copy) return;
    memcpy(copy, data, size_in_bytes);
    filament_index_buffer_set_buffer(
        engine,
        ib,
        copy,
        size_in_bytes,
        0,
        [](void* buffer, size_t, void*) { free(buffer); },
        nullptr
    );
    FFI_CATCH_VOID()
}

uint32_t filament_index_buffer_get_index_count(void* ib) {
    FFI_TRY
    if (!ib) return 0;
    return static_cast<uint32_t>(toIndexBuffer(ib)->getIndexCount());
    FFI_CATCH(0)
}

void filament_engine_destroy_index_buffer(void* engine, void* ib) {
    FFI_TRY
    if (!engine || !ib) return;
    toEngine(engine)->destroy(toIndexBuffer(ib));
    FFI_CATCH_VOID()
}
