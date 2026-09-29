/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_TOOLS_C_H
#define FLUTTER_FILAMENT_TOOLS_C_H

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

/// Inspects a `.filamat` material binary buffer and returns a JSON string containing material parameters and info.
/// Free returned char* with `filament_tools_free_string`.
FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_json(const void* data, uint32_t size);

/// Inspects a `.filamat` material binary buffer and returns a human-readable text summary.
/// Free returned char* with `filament_tools_free_string`.
FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_text(const void* data, uint32_t size);

/// Encodes binary buffer into a C++ header source string (`resgen` tool).
/// Free returned char* with `filament_tools_free_string`.
FFI_PLUGIN_EXPORT char* filament_tools_resgen_encode(const void* data, uint32_t size, const char* symbol_name);

/// Computes box-filtered RGBA8 mipmaps for a given 2D image down to `target_level` (`mipgen` tool).
/// Populates `out_pixels`, `out_width`, `out_height`.
/// Returns 1 on success, 0 on error.
FFI_PLUGIN_EXPORT uint8_t filament_tools_generate_mipmap_level_rgba8(
    const uint8_t* src_pixels, uint32_t width, uint32_t height,
    uint32_t target_level, uint8_t* out_pixels, uint32_t* out_width, uint32_t* out_height);

/// Minifies GLSL shader source code by removing comments, empty lines, and indentation (`glslminifier` tool).
/// Free returned char* with `filament_tools_free_string`.
FFI_PLUGIN_EXPORT char* filament_tools_minify_glsl(const char* glsl_code, uint32_t options);

/// Blends two RGBA8 normal maps using Reoriented Normal Mapping (RNM) (`normal-blending` tool).
/// Populates `out_pixels` with the blended normal map pixels.
/// Returns 1 on success, 0 on error.
FFI_PLUGIN_EXPORT uint8_t filament_tools_blend_normal_maps_rgba8(
    const uint8_t* base_pixels, const uint8_t* detail_pixels,
    uint32_t width, uint32_t height, uint8_t* out_pixels);

/// Computes dielectric specular reflectance F0 from Index of Refraction (IOR) (`specular-color` tool).
FFI_PLUGIN_EXPORT float filament_tools_compute_dielectric_f0(float ior);

/// Computes conductor specular reflectance F0 from complex IOR (n, k) (`specular-color` tool).
FFI_PLUGIN_EXPORT void filament_tools_compute_conductor_f0(
    float n_r, float n_g, float n_b,
    float k_r, float k_g, float k_b,
    float* out_f0_r, float* out_f0_g, float* out_f0_b);

/// Computes 9-coefficient (27 floats) Spherical Harmonics (SH3) RGB values for diffuse IBL from an RGBA8 equirectangular map (`cmgen` tool).
/// Writes 27 floats into `out_sh3_rgb_27floats`. Returns 1 on success, 0 on error.
FFI_PLUGIN_EXPORT uint8_t filament_tools_compute_spherical_harmonics_rgba8(
    const uint8_t* equirect_pixels, uint32_t width, uint32_t height, float* out_sh3_rgb_27floats);

/// Compares two RGBA8 image buffers of equal size and computes image difference metrics (`diffimg` tool).
/// Writes difference image to `out_diff_pixels` (optional, can be null).
/// Populates `out_mean_error` and `out_max_error`. Returns 1 on success, 0 on error.
FFI_PLUGIN_EXPORT uint8_t filament_tools_compare_images_rgba8(
    const uint8_t* pixels_a, const uint8_t* pixels_b, uint32_t width, uint32_t height,
    uint8_t* out_diff_pixels, float* out_mean_error, float* out_max_error);

/// Computes Specular Ambient Occlusion (SAO) LUT value for a given roughness, NdotV angle, and ambient occlusion (`cso-lut` tool).
FFI_PLUGIN_EXPORT float filament_tools_compute_specular_ao(float roughness, float ndotv, float ao);

/// Compresses a binary buffer using ZSTD algorithm (`uberz` archive tool).
/// Writes compressed data to allocated buffer, populating `out_compressed_size`.
/// Free output buffer with `filament_tools_free_buffer`. Returns pointer on success, null on error.
FFI_PLUGIN_EXPORT void* filament_tools_zstd_compress(const void* data, uint32_t size, uint32_t* out_compressed_size);

/// Decompresses a ZSTD compressed binary buffer (`uberz` archive tool).
/// Writes decompressed data to allocated buffer, populating `out_decompressed_size`.
/// Free output buffer with `filament_tools_free_buffer`. Returns pointer on success, null on error.
FFI_PLUGIN_EXPORT void* filament_tools_zstd_decompress(const void* compressed_data, uint32_t compressed_size, uint32_t* out_decompressed_size);

/// Generates a JSON debug dump of the rendering pipeline state (`frame_pipeline_visualizer` tool).
/// Free returned char* with `filament_tools_free_string`.
FFI_PLUGIN_EXPORT char* filament_tools_dump_frame_pipeline_json(void* view, void* scene, void* camera);

/// Frees a C string allocated by tools C functions.
FFI_PLUGIN_EXPORT void filament_tools_free_string(char* str);

/// Frees a memory buffer allocated by tools C functions.
FFI_PLUGIN_EXPORT void filament_tools_free_buffer(void* ptr);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_TOOLS_C_H
