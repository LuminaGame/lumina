/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_IBLPREFILTER_C_H
#define FLUTTER_FILAMENT_IBLPREFILTER_C_H

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

typedef struct FilIblPrefilterContext FilIblPrefilterContext;
typedef struct FilEquirectToCubemap FilEquirectToCubemap;
typedef struct FilSpecularFilter FilSpecularFilter;
typedef struct FilIrradianceFilter FilIrradianceFilter;

// Context
FFI_PLUGIN_EXPORT FilIblPrefilterContext* filament_iblprefilter_context_create(void* engine);
FFI_PLUGIN_EXPORT void filament_iblprefilter_context_destroy(FilIblPrefilterContext* ctx);

// EquirectangularToCubemap
FFI_PLUGIN_EXPORT FilEquirectToCubemap* filament_equirect_to_cubemap_create(FilIblPrefilterContext* ctx, bool mirror);
FFI_PLUGIN_EXPORT void filament_equirect_to_cubemap_destroy(FilEquirectToCubemap* e);
FFI_PLUGIN_EXPORT void* filament_equirect_to_cubemap_run(FilEquirectToCubemap* e, void* equirect, void* out_cube);

// SpecularFilter
FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_create(FilIblPrefilterContext* ctx);
FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_create_config(FilIblPrefilterContext* ctx, uint16_t sample_count, uint8_t level_count, int kernel);
FFI_PLUGIN_EXPORT void filament_specular_filter_destroy(FilSpecularFilter* f);
FFI_PLUGIN_EXPORT void* filament_specular_filter_run(FilSpecularFilter* f, void* environment_cubemap, void* out_reflections, float hdr_linear, float hdr_max, float lod_offset, bool generate_mipmap);

// IrradianceFilter
FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_create(FilIblPrefilterContext* ctx);
FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_create_config(FilIblPrefilterContext* ctx, uint16_t sample_count, int kernel);
FFI_PLUGIN_EXPORT void filament_irradiance_filter_destroy(FilIrradianceFilter* f);
FFI_PLUGIN_EXPORT void* filament_irradiance_filter_run(FilIrradianceFilter* f, void* environment_cubemap, void* out_irradiance, float hdr_linear, float hdr_max, float lod_offset, bool generate_mipmap);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_IBLPREFILTER_C_H
