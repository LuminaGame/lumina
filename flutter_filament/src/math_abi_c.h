/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_MATH_ABI_C_H
#define FLUTTER_FILAMENT_MATH_ABI_C_H

#include <stdint.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Sizeof hooks
FFI_PLUGIN_EXPORT size_t filament_sizeof_float2(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_float3(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_float4(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_int2(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_int3(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_int4(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_uint2(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_uint3(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_uint4(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_bool2(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_bool3(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_bool4(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_short4(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_quatf(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_mat3f(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4f(void);
FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4(void);

// Layout & readback verification hooks
FFI_PLUGIN_EXPORT void filament_test_quatf_read(const void* q, float out_xyzw[4]);
FFI_PLUGIN_EXPORT void filament_test_mat4f_col_major(void* out);
FFI_PLUGIN_EXPORT void filament_test_float3_array_sum(const void* arr, int32_t count, float out[3]);
FFI_PLUGIN_EXPORT void filament_test_mat3f_read(const void* m, float out9[9]);
FFI_PLUGIN_EXPORT void filament_test_bool3_read(const void* b, uint8_t out3[3]);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_MATH_ABI_C_H
