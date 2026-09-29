/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_MATERIAL_INSTANCE_C_H
#define FLUTTER_FILAMENT_MATERIAL_INSTANCE_C_H

#include <stdint.h>
#include <stdbool.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void* filament_material_instance_duplicate(void* mi, const char* name);

// Scalar & Vector Setters
FFI_PLUGIN_EXPORT void filament_material_instance_set_bool(void* mi, const char* name, bool value);
FFI_PLUGIN_EXPORT void filament_material_instance_set_bool2(void* mi, const char* name, const bool* v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_bool3(void* mi, const char* name, const bool* v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_bool4(void* mi, const char* name, const bool* v);

FFI_PLUGIN_EXPORT void filament_material_instance_set_int(void* mi, const char* name, int32_t value);
FFI_PLUGIN_EXPORT void filament_material_instance_set_int2(void* mi, const char* name, int32_t x, int32_t y);
FFI_PLUGIN_EXPORT void filament_material_instance_set_int3(void* mi, const char* name, int32_t x, int32_t y, int32_t z);
FFI_PLUGIN_EXPORT void filament_material_instance_set_int4(void* mi, const char* name, int32_t x, int32_t y, int32_t z, int32_t w);

FFI_PLUGIN_EXPORT void filament_material_instance_set_uint(void* mi, const char* name, uint32_t v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_uint2(void* mi, const char* name, const uint32_t* v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_uint3(void* mi, const char* name, const uint32_t* v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_uint4(void* mi, const char* name, const uint32_t* v);

FFI_PLUGIN_EXPORT void filament_material_instance_set_float(void* mi, const char* name, float value);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float2(void* mi, const char* name, float x, float y);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float3(void* mi, const char* name, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float4(void* mi, const char* name, float x, float y, float z, float w);

FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3(void* mi, const char* name, const float* matrix9);
FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4(void* mi, const char* name, const float* matrix16);

// Array Setters
FFI_PLUGIN_EXPORT void filament_material_instance_set_float_array(void* mi, const char* name, const float* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float2_array(void* mi, const char* name, const float* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float3_array(void* mi, const char* name, const float* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_float4_array(void* mi, const char* name, const float* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_int_array(void* mi, const char* name, const int32_t* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3_array(void* mi, const char* name, const float* values, uint32_t count);
FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4_array(void* mi, const char* name, const float* values, uint32_t count);

// Color-space aware Setters
FFI_PLUGIN_EXPORT void filament_material_instance_set_rgb(void* mi, const char* name, int32_t rgb_type, float r, float g, float b);
FFI_PLUGIN_EXPORT void filament_material_instance_set_rgba(void* mi, const char* name, int32_t rgba_type, float r, float g, float b, float a);

// Texture Setters
FFI_PLUGIN_EXPORT void filament_material_instance_set_texture(void* mi, const char* name, void* texture);
FFI_PLUGIN_EXPORT void filament_material_instance_set_texture_ex(void* mi, const char* name, void* texture, uint32_t sampler_params_packed);

// Render State Overrides
FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode(void* mi, int32_t mode);
FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode2(void* mi, int32_t color_pass_mode, int32_t shadow_pass_mode);
FFI_PLUGIN_EXPORT void filament_material_instance_set_double_sided(void* mi, bool double_sided);
FFI_PLUGIN_EXPORT void filament_material_instance_set_color_write(void* mi, bool enable);
FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_write(void* mi, bool enable);
FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_culling(void* mi, bool enable);
FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_func(void* mi, int32_t func);
FFI_PLUGIN_EXPORT void filament_material_instance_set_transparency_mode(void* mi, int32_t mode);
FFI_PLUGIN_EXPORT void filament_material_instance_set_mask_threshold(void* mi, float threshold);
FFI_PLUGIN_EXPORT void filament_material_instance_set_polygon_offset(void* mi, float scale, float constant);
FFI_PLUGIN_EXPORT void filament_material_instance_set_scissor(void* mi, uint32_t left, uint32_t bottom, uint32_t width, uint32_t height);
FFI_PLUGIN_EXPORT void filament_material_instance_unset_scissor(void* mi);

// Stencil
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_write(void* mi, bool enabled);
FFI_PLUGIN_EXPORT bool filament_material_instance_is_stencil_write_enabled(void* mi);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_compare_function(void* mi, int32_t func, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_op_stencil_fail(void* mi, int32_t op, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_op_depth_fail(void* mi, int32_t op, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_op_depth_stencil_pass(void* mi, int32_t op, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_reference_value(void* mi, uint8_t value, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_read_mask(void* mi, uint8_t mask, int32_t face);
FFI_PLUGIN_EXPORT void filament_material_instance_set_stencil_write_mask(void* mi, uint8_t mask, int32_t face);

// Constants
FFI_PLUGIN_EXPORT void filament_material_instance_set_constant_int(void* mi, const char* name, int32_t v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_constant_float(void* mi, const char* name, float v);
FFI_PLUGIN_EXPORT void filament_material_instance_set_constant_bool(void* mi, const char* name, bool v);

// Parameter Read-back
FFI_PLUGIN_EXPORT float filament_material_instance_get_parameter_float(void* mi, const char* name);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_float2(void* mi, const char* name, float* out);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_float3(void* mi, const char* name, float* out);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_float4(void* mi, const char* name, float* out);
FFI_PLUGIN_EXPORT int32_t filament_material_instance_get_parameter_int(void* mi, const char* name);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_int2(void* mi, const char* name, int32_t* out);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_int3(void* mi, const char* name, int32_t* out);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_int4(void* mi, const char* name, int32_t* out);
FFI_PLUGIN_EXPORT uint32_t filament_material_instance_get_parameter_uint(void* mi, const char* name);
FFI_PLUGIN_EXPORT bool filament_material_instance_get_parameter_bool(void* mi, const char* name);
FFI_PLUGIN_EXPORT void filament_material_instance_get_parameter_mat4(void* mi, const char* name, float* out16);

// Render State Getters
FFI_PLUGIN_EXPORT int32_t filament_material_instance_get_culling_mode(void* mi);
FFI_PLUGIN_EXPORT bool filament_material_instance_is_double_sided(void* mi);
FFI_PLUGIN_EXPORT bool filament_material_instance_is_color_write_enabled(void* mi);
FFI_PLUGIN_EXPORT bool filament_material_instance_is_depth_write_enabled(void* mi);
FFI_PLUGIN_EXPORT bool filament_material_instance_is_depth_culling_enabled(void* mi);
FFI_PLUGIN_EXPORT int32_t filament_material_instance_get_depth_func(void* mi);
FFI_PLUGIN_EXPORT int32_t filament_material_instance_get_transparency_mode(void* mi);
FFI_PLUGIN_EXPORT float filament_material_instance_get_mask_threshold(void* mi);

// Identity & Material
FFI_PLUGIN_EXPORT void* filament_material_instance_get_material(void* mi);
FFI_PLUGIN_EXPORT const char* filament_material_instance_get_name(void* mi);

// Specular Anti-Aliasing
FFI_PLUGIN_EXPORT void filament_material_instance_set_specular_antialiasing_variance(void* mi, float variance);
FFI_PLUGIN_EXPORT float filament_material_instance_get_specular_antialiasing_variance(void* mi);
FFI_PLUGIN_EXPORT void filament_material_instance_set_specular_antialiasing_threshold(void* mi, float threshold);
FFI_PLUGIN_EXPORT float filament_material_instance_get_specular_antialiasing_threshold(void* mi);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_MATERIAL_INSTANCE_C_H
