/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_CALLBACK_BRIDGE_C_H
#define FLUTTER_FILAMENT_CALLBACK_BRIDGE_C_H

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

typedef struct {
    uint64_t request_id;
    int32_t kind;
    int32_t status;
    const void* payload;
    uint32_t payload_size;
} FilamentCallbackEnvelope;

typedef void (*filament_callback_dispatch_fn)(const FilamentCallbackEnvelope* env);

FFI_PLUGIN_EXPORT int32_t filament_callback_bridge_init(filament_callback_dispatch_fn dispatch);
FFI_PLUGIN_EXPORT void filament_callback_bridge_shutdown(void);
FFI_PLUGIN_EXPORT void filament_callback_envelope_free(FilamentCallbackEnvelope* env);

FFI_PLUGIN_EXPORT void filament_engine_pump_message_queues(void* engine);

FFI_PLUGIN_EXPORT void filament_test_callback_fire(
    uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size);

FFI_PLUGIN_EXPORT void filament_test_callback_fire_async(
    uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size);

#ifdef __cplusplus
}

void fireCallback(uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size);

#endif

#endif // FLUTTER_FILAMENT_CALLBACK_BRIDGE_C_H
