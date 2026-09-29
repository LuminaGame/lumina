/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_BUFFER_DESCRIPTOR_C_H
#define FLUTTER_FILAMENT_BUFFER_DESCRIPTOR_C_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*filament_buffer_free_fn)(void* buffer, size_t size, void* user);

FFI_PLUGIN_EXPORT void filament_test_consume_buffer_descriptor(
    void* engine, void* data, size_t size, filament_buffer_free_fn cb, void* user);

FFI_PLUGIN_EXPORT void filament_test_consume_pixel_buffer_descriptor(
    void* engine, void* data, size_t size, int32_t pixel_format, int32_t pixel_type,
    uint32_t stride, uint8_t alignment, filament_buffer_free_fn cb, void* user);

FFI_PLUGIN_EXPORT const void* filament_test_buffer_descriptor_peek(void* data);

#ifdef __cplusplus
}

#include <backend/BufferDescriptor.h>
#include <backend/PixelBufferDescriptor.h>
#include <backend/DriverEnums.h>

filament::backend::BufferDescriptor makeBufferDescriptor(
    void* data, size_t size, filament_buffer_free_fn cb = nullptr, void* user = nullptr);

filament::backend::PixelBufferDescriptor makePixelBufferDescriptor(
    void* data, size_t size, int32_t pixel_format, int32_t pixel_type,
    uint32_t stride = 0, uint8_t alignment = 1, filament_buffer_free_fn cb = nullptr, void* user = nullptr);

#endif

#endif // FLUTTER_FILAMENT_BUFFER_DESCRIPTOR_C_H
