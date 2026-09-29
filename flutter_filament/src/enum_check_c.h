/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_ENUM_CHECK_C_H
#define FLUTTER_FILAMENT_ENUM_CHECK_C_H

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

FFI_PLUGIN_EXPORT int32_t filament_enum_primitive_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_index_type(int32_t ordinal);
FFI_PLUGIN_EXPORT uint32_t filament_enum_texture_usage(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_builder_result(int32_t ordinal);
FFI_PLUGIN_EXPORT uint32_t filament_enum_morph_type(int32_t ordinal);

// Audit hooks for existing enums
FFI_PLUGIN_EXPORT int32_t filament_enum_backend(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_light_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_manipulator_mode(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_filamat_shading(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_texture_format(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_internal_format(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_sampler_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_texture_swizzle(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_format(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_attribute_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_vertex_attribute(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_uniform_type(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_precision(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_culling_mode(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_depth_func(int32_t ordinal);
FFI_PLUGIN_EXPORT int32_t filament_enum_transparency_mode(int32_t ordinal);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_ENUM_CHECK_C_H
