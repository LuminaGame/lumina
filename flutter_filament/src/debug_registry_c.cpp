/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "debug_registry_c.h"
#include <filament/Engine.h>
#include <filament/DebugRegistry.h>
#include <math/vec2.h>
#include <math/vec3.h>
#include <math/vec4.h>
#include "utils_c.h"

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_val) } catch (...) { return return_val; }

static inline Engine* toEngine(void* ptr) {
    return reinterpret_cast<Engine*>(ptr);
}

static inline DebugRegistry* toDebugRegistry(void* ptr) {
    return reinterpret_cast<DebugRegistry*>(ptr);
}

void* filament_engine_get_debug_registry(void* engine) {
    FFI_TRY
    if (!engine) return nullptr;
    return &toEngine(engine)->getDebugRegistry();
    FFI_CATCH(nullptr)
}

bool filament_debug_registry_has_property(void* reg, const char* name) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->hasProperty(name);
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_bool(void* reg, const char* name, bool v) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, v);
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_int(void* reg, const char* name, int32_t v) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, v);
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_float(void* reg, const char* name, float v) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, v);
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_float2(void* reg, const char* name, float x, float y) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, math::float2{x, y});
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_float3(void* reg, const char* name, float x, float y, float z) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, math::float3{x, y, z});
    FFI_CATCH(false)
}

bool filament_debug_registry_set_property_float4(void* reg, const char* name, float x, float y, float z, float w) {
    FFI_TRY
    if (!reg || !name) return false;
    return toDebugRegistry(reg)->setProperty(name, math::float4{x, y, z, w});
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_bool(void* reg, const char* name, bool* out) {
    FFI_TRY
    if (!reg || !name || !out) return false;
    return toDebugRegistry(reg)->getProperty(name, out);
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_int(void* reg, const char* name, int32_t* out) {
    FFI_TRY
    if (!reg || !name || !out) return false;
    return toDebugRegistry(reg)->getProperty(name, out);
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_float(void* reg, const char* name, float* out) {
    FFI_TRY
    if (!reg || !name || !out) return false;
    return toDebugRegistry(reg)->getProperty(name, out);
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_float2(void* reg, const char* name, float* out2) {
    FFI_TRY
    if (!reg || !name || !out2) return false;
    math::float2 v;
    if (toDebugRegistry(reg)->getProperty(name, &v)) {
        out2[0] = v.x;
        out2[1] = v.y;
        return true;
    }
    return false;
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_float3(void* reg, const char* name, float* out3) {
    FFI_TRY
    if (!reg || !name || !out3) return false;
    math::float3 v;
    if (toDebugRegistry(reg)->getProperty(name, &v)) {
        out3[0] = v.x;
        out3[1] = v.y;
        out3[2] = v.z;
        return true;
    }
    return false;
    FFI_CATCH(false)
}

bool filament_debug_registry_get_property_float4(void* reg, const char* name, float* out4) {
    FFI_TRY
    if (!reg || !name || !out4) return false;
    math::float4 v;
    if (toDebugRegistry(reg)->getProperty(name, &v)) {
        out4[0] = v.x;
        out4[1] = v.y;
        return true;
    }
    return false;
    FFI_CATCH(false)
}

bool filament_debug_registry_get_data_source(void* reg, const char* name, const void** out_data, uint32_t* out_count) {
    FFI_TRY
    if (!reg || !name || !out_data || !out_count) return false;
    auto ds = toDebugRegistry(reg)->getDataSource(name);
    if (ds.data == nullptr) {
        *out_data = nullptr;
        *out_count = 0;
        return false;
    }
    *out_data = ds.data;
    *out_count = static_cast<uint32_t>(ds.count);
    return true;
    FFI_CATCH(false)
}
