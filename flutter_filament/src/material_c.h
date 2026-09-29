/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_MATERIAL_C_H
#define FLUTTER_FILAMENT_MATERIAL_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* name;
    bool is_sampler;
    bool is_subpass;
    int32_t uniform_type;
    int32_t sampler_type;
    int32_t subpass_type;
    uint32_t count;
    int32_t precision;
} FilamentParameterInfo;

typedef struct {
    const char* name;
    int32_t type; // 0=int32, 1=float, 2=bool
    union {
        int32_t i;
        float f;
        bool b;
    } value;
} FilamentMaterialConstant;

// Material lifecycle & instances
/// The material package version this engine build accepts (the `.filamat`
/// header's version byte). Lets callers check a compiled material before
/// loading it, instead of finding out from a log line that the render is empty.
FFI_PLUGIN_EXPORT uint32_t filament_expected_material_version(void);

FFI_PLUGIN_EXPORT void* filament_material_create(void* engine, const void* data, uint32_t size);
FFI_PLUGIN_EXPORT void* filament_material_create_ex(
    void* engine,
    const void* package,
    size_t size,
    const FilamentMaterialConstant* constants,
    size_t constant_count,
    uint8_t sh_band_count,
    int32_t shadow_sampling_quality);
FFI_PLUGIN_EXPORT void* filament_material_create_instance(void* material);
FFI_PLUGIN_EXPORT void* filament_material_create_instance_with_name(void* material, const char* name);
FFI_PLUGIN_EXPORT void* filament_material_get_default_instance(void* material);
FFI_PLUGIN_EXPORT void filament_engine_destroy_material(void* engine, void* material);
FFI_PLUGIN_EXPORT void filament_material_compile(void* material, int32_t priority, uint64_t variant_filter, uint64_t request_id);

// Parameter reflection
FFI_PLUGIN_EXPORT size_t filament_material_get_parameter_count(void* material);
FFI_PLUGIN_EXPORT size_t filament_material_get_parameters(void* material, FilamentParameterInfo* out, size_t capacity);
FFI_PLUGIN_EXPORT bool filament_material_has_parameter(void* material, const char* name);
FFI_PLUGIN_EXPORT bool filament_material_is_sampler(void* material, const char* name);
FFI_PLUGIN_EXPORT const char* filament_material_get_parameter_transform_name(void* material, const char* name);

// Default parameter family
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_bool(void* material, const char* name, bool value);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_int(void* material, const char* name, int32_t value);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_float(void* material, const char* name, float value);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_float2(void* material, const char* name, float x, float y);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_float3(void* material, const char* name, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_float4(void* material, const char* name, float x, float y, float z, float w);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat3(void* material, const char* name, const float* m);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat4(void* material, const char* name, const float* m);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_texture(void* material, const char* name, void* texture, uint32_t sampler_params_packed);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgb(void* material, const char* name, int32_t rgb_type, float r, float g, float b);
FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgba(void* material, const char* name, int32_t rgba_type, float r, float g, float b, float a);

// Introspection getters
FFI_PLUGIN_EXPORT int32_t filament_material_get_shading(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_interpolation(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_blending_mode(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_vertex_domain(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_material_domain(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_culling_mode(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_transparency_mode(void* material);
FFI_PLUGIN_EXPORT bool filament_material_is_color_write_enabled(void* material);
FFI_PLUGIN_EXPORT bool filament_material_is_depth_write_enabled(void* material);
FFI_PLUGIN_EXPORT bool filament_material_is_depth_culling_enabled(void* material);
FFI_PLUGIN_EXPORT bool filament_material_is_double_sided(void* material);
FFI_PLUGIN_EXPORT bool filament_material_is_alpha_to_coverage_enabled(void* material);
FFI_PLUGIN_EXPORT float filament_material_get_mask_threshold(void* material);
FFI_PLUGIN_EXPORT bool filament_material_has_shadow_multiplier(void* material);
FFI_PLUGIN_EXPORT bool filament_material_has_specular_anti_aliasing(void* material);
FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasing_variance(void* material);
FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasing_threshold(void* material);
FFI_PLUGIN_EXPORT uint32_t filament_material_get_required_attributes(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_refraction_mode(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_refraction_type(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_reflection_mode(void* material);
FFI_PLUGIN_EXPORT int32_t filament_material_get_feature_level(void* material);
FFI_PLUGIN_EXPORT const char* filament_material_get_name(void* material);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_MATERIAL_C_H
