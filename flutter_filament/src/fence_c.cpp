/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "fence_c.h"
#include <filament/Engine.h>
#include <filament/Fence.h>
#include "utils_c.h"

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_val) } catch (...) { return return_val; }

static inline Engine* toEngine(void* ptr) {
    return reinterpret_cast<Engine*>(ptr);
}

static inline Fence* toFence(void* ptr) {
    return reinterpret_cast<Fence*>(ptr);
}

void* filament_engine_create_fence(void* engine) {
    FFI_TRY
    if (!engine) return nullptr;
    return toEngine(engine)->createFence();
    FFI_CATCH(nullptr)
}

int filament_fence_wait(void* fence, int mode, uint64_t timeout_ns) {
    FFI_TRY
    if (!fence) return -1; // FenceStatus::ERROR
    auto m = static_cast<Fence::Mode>(mode);
    auto status = toFence(fence)->wait(m, timeout_ns);
    return static_cast<int>(status);
    FFI_CATCH(-1)
}

int filament_fence_wait_and_destroy(void* fence, int mode) {
    FFI_TRY
    if (!fence) return -1;
    auto m = static_cast<Fence::Mode>(mode);
    auto status = Fence::waitAndDestroy(toFence(fence), m);
    return static_cast<int>(status);
    FFI_CATCH(-1)
}

uint64_t filament_fence_wait_for_ever(void) {
    return Fence::FENCE_WAIT_FOR_EVER;
}
