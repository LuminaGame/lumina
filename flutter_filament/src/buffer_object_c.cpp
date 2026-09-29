/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "buffer_object_c.h"
#include "buffer_descriptor_c.h"

#include <filament/Engine.h>
#include <filament/BufferObject.h>
#include <backend/DriverEnums.h>
#include <backend/BufferDescriptor.h>
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

static inline BufferObject* toBufferObject(void* p) {
    return reinterpret_cast<BufferObject*>(p);
}

void* filament_buffer_object_create(
    void* engine,
    uint32_t byte_count,
    int32_t binding_type
) {
    FFI_TRY
    if (!engine || byte_count == 0) return nullptr;
    return BufferObject::Builder()
        .size(byte_count)
        .bindingType(static_cast<BufferObject::BindingType>(binding_type))
        .build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_buffer_object_set_buffer(
    void* engine,
    void* bo,
    void* data,
    size_t size,
    uint32_t byte_offset,
    filament_buffer_free_fn cb,
    void* user
) {
    FFI_TRY
    if (!engine || !bo || !data || size == 0) return;
    auto bd = makeBufferDescriptor(data, size, cb, user);
    toBufferObject(bo)->setBuffer(*toEngine(engine), std::move(bd), byte_offset);
    FFI_CATCH_VOID()
}

uint32_t filament_buffer_object_get_byte_count(void* bo) {
    FFI_TRY
    if (!bo) return 0;
    return static_cast<uint32_t>(toBufferObject(bo)->getByteCount());
    FFI_CATCH(0)
}

void filament_engine_destroy_buffer_object(void* engine, void* bo) {
    FFI_TRY
    if (!engine || !bo) return;
    toEngine(engine)->destroy(toBufferObject(bo));
    FFI_CATCH_VOID()
}
