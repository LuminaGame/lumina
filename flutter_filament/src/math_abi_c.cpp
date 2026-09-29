/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "math_abi_c.h"

#include <math/vec2.h>
#include <math/vec3.h>
#include <math/vec4.h>
#include <math/quat.h>
#include <math/mat3.h>
#include <math/mat4.h>
#include <cstring>

using namespace filament::math;

size_t filament_sizeof_float2(void) { return sizeof(float2); }
size_t filament_sizeof_float3(void) { return sizeof(float3); }
size_t filament_sizeof_float4(void) { return sizeof(float4); }
size_t filament_sizeof_int2(void) { return sizeof(int2); }
size_t filament_sizeof_int3(void) { return sizeof(int3); }
size_t filament_sizeof_int4(void) { return sizeof(int4); }
size_t filament_sizeof_uint2(void) { return sizeof(uint2); }
size_t filament_sizeof_uint3(void) { return sizeof(uint3); }
size_t filament_sizeof_uint4(void) { return sizeof(uint4); }
size_t filament_sizeof_bool2(void) { return sizeof(bool2); }
size_t filament_sizeof_bool3(void) { return sizeof(bool3); }
size_t filament_sizeof_bool4(void) { return sizeof(bool4); }
size_t filament_sizeof_short4(void) { return sizeof(short4); }
size_t filament_sizeof_quatf(void) { return sizeof(quatf); }
size_t filament_sizeof_mat3f(void) { return sizeof(mat3f); }
size_t filament_sizeof_mat4f(void) { return sizeof(mat4f); }
size_t filament_sizeof_mat4(void) { return sizeof(mat4); }

void filament_test_quatf_read(const void* q, float out_xyzw[4]) {
    if (!q || !out_xyzw) return;
    const quatf* quat = reinterpret_cast<const quatf*>(q);
    out_xyzw[0] = quat->x;
    out_xyzw[1] = quat->y;
    out_xyzw[2] = quat->z;
    out_xyzw[3] = quat->w;
}

void filament_test_mat4f_col_major(void* out) {
    if (!out) return;
    mat4f t = mat4f::translation(float3{1.0f, 2.0f, 3.0f});
    std::memcpy(out, &t, sizeof(mat4f));
}

void filament_test_float3_array_sum(const void* arr, int32_t count, float out[3]) {
    if (!arr || count <= 0 || !out) return;
    const float3* items = reinterpret_cast<const float3*>(arr);
    float3 sum{0.0f, 0.0f, 0.0f};
    for (int32_t i = 0; i < count; i++) {
        sum += items[i];
    }
    out[0] = sum.x;
    out[1] = sum.y;
    out[2] = sum.z;
}

void filament_test_mat3f_read(const void* m, float out9[9]) {
    if (!m || !out9) return;
    std::memcpy(out9, m, sizeof(mat3f));
}

void filament_test_bool3_read(const void* b, uint8_t out3[3]) {
    if (!b || !out3) return;
    const bool3* b3 = reinterpret_cast<const bool3*>(b);
    out3[0] = b3->x ? 1 : 0;
    out3[1] = b3->y ? 1 : 0;
    out3[2] = b3->z ? 1 : 0;
}
