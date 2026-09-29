/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "callback_bridge_c.h"

#include <filament/Engine.h>
#include <utils/Panic.h>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <exception>
#include <thread>
#include <vector>

using namespace filament;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[CallbackBridge C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[CallbackBridge C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[CallbackBridge C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static std::atomic<filament_callback_dispatch_fn> g_dispatch{nullptr};

static inline Engine* toEngine(void* p) {
    return reinterpret_cast<Engine*>(p);
}

int32_t filament_callback_bridge_init(filament_callback_dispatch_fn dispatch) {
    if (dispatch == nullptr) return -1;
    filament_callback_dispatch_fn expected = nullptr;
    if (g_dispatch.compare_exchange_strong(expected, dispatch)) {
        return 0;
    }
    // If already set to the same dispatch function, succeed
    if (expected == dispatch) {
        return 0;
    }
    return -1;
}

void filament_callback_bridge_shutdown(void) {
    g_dispatch.store(nullptr);
}

void filament_callback_envelope_free(FilamentCallbackEnvelope* env) {
    if (env) {
        if (env->payload) {
            free(const_cast<void*>(env->payload));
        }
        delete env;
    }
}

void fireCallback(uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size) {
    filament_callback_dispatch_fn dispatch = g_dispatch.load();
    if (!dispatch) return;

    FilamentCallbackEnvelope* env = new FilamentCallbackEnvelope();
    env->request_id = request_id;
    env->kind = kind;
    env->status = status;
    env->payload_size = size;
    if (payload && size > 0) {
        void* copy = malloc(size);
        if (copy) {
            std::memcpy(copy, payload, size);
        }
        env->payload = copy;
    } else {
        env->payload = nullptr;
    }

    dispatch(env);
}

void filament_engine_pump_message_queues(void* engine) {
    FFI_TRY
    if (engine) {
        toEngine(engine)->pumpMessageQueues();
    }
    FFI_CATCH()
}

void filament_test_callback_fire(
    uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size) {
    fireCallback(request_id, kind, status, payload, size);
}

void filament_test_callback_fire_async(
    uint64_t request_id, int32_t kind, int32_t status, const void* payload, uint32_t size) {
    std::vector<uint8_t> payload_copy;
    if (payload && size > 0) {
        payload_copy.resize(size);
        std::memcpy(payload_copy.data(), payload, size);
    }

    std::thread([request_id, kind, status, payload_copy = std::move(payload_copy)]() {
        const void* ptr = payload_copy.empty() ? nullptr : payload_copy.data();
        uint32_t sz = static_cast<uint32_t>(payload_copy.size());
        fireCallback(request_id, kind, status, ptr, sz);
    }).detach();
}
