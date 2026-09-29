/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_FENCE_C_H
#define FLUTTER_FILAMENT_FENCE_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

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

FFI_PLUGIN_EXPORT void*    filament_engine_create_fence(void* engine);
FFI_PLUGIN_EXPORT int      filament_fence_wait(void* fence, int mode, uint64_t timeout_ns);
FFI_PLUGIN_EXPORT int      filament_fence_wait_and_destroy(void* fence, int mode);
FFI_PLUGIN_EXPORT uint64_t filament_fence_wait_for_ever(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_FENCE_C_H
