/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_LIGHTING_C_H
#define FLUTTER_FILAMENT_LIGHTING_C_H

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

typedef enum {
    FILAMENT_LIGHT_SUN          = 0,
    FILAMENT_LIGHT_DIRECTIONAL  = 1,
    FILAMENT_LIGHT_POINT        = 2,
    FILAMENT_LIGHT_FOCUSED_SPOT = 3,
    FILAMENT_LIGHT_SPOT         = 4,
} FilamentLightType;

typedef enum {
    FILAMENT_TEXTURE_FORMAT_R8     = 1,
    FILAMENT_TEXTURE_FORMAT_RGB8   = 13,
    FILAMENT_TEXTURE_FORMAT_RGBA8  = 17,
    FILAMENT_TEXTURE_FORMAT_SRGB8_A8 = 43,
} FilamentTextureFormat;

typedef enum {
    FILAMENT_PIXEL_FORMAT_R    = 0,
    FILAMENT_PIXEL_FORMAT_RGB  = 3,
    FILAMENT_PIXEL_FORMAT_RGBA = 4,
} FilamentPixelFormat;

typedef enum {
    FILAMENT_PIXEL_TYPE_UBYTE = 0,
    FILAMENT_PIXEL_TYPE_FLOAT = 5,
} FilamentPixelType;

// LightManager
FFI_PLUGIN_EXPORT void filament_light_create(void* engine, uint32_t entity, int type, float color_r, float color_g, float color_b, float intensity, float dir_x, float dir_y, float dir_z, bool cast_shadows);
FFI_PLUGIN_EXPORT void filament_light_destroy(void* engine, uint32_t entity);

// LightManager::Builder
FFI_PLUGIN_EXPORT void* filament_light_builder_create(int type);
FFI_PLUGIN_EXPORT void filament_light_builder_position(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_light_builder_direction(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_light_builder_color(void* builder, float r, float g, float b);
FFI_PLUGIN_EXPORT void filament_light_builder_intensity(void* builder, float intensity);
FFI_PLUGIN_EXPORT void filament_light_builder_intensity_candela(void* builder, float intensity);
FFI_PLUGIN_EXPORT void filament_light_builder_intensity_watts(void* builder, float watts, float efficiency);
FFI_PLUGIN_EXPORT void filament_light_builder_falloff(void* builder, float radius);
FFI_PLUGIN_EXPORT void filament_light_builder_spot_light_cone(void* builder, float inner, float outer);
FFI_PLUGIN_EXPORT void filament_light_builder_sun_angular_radius(void* builder, float radius);
FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_size(void* builder, float size);
FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_falloff(void* builder, float falloff);
FFI_PLUGIN_EXPORT void filament_light_builder_cast_shadows(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_light_builder_cast_light(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_light_builder_light_channel(void* builder, unsigned int channel, bool enable);
FFI_PLUGIN_EXPORT int32_t filament_light_builder_build(void* builder, void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_light_builder_destroy(void* builder);

// LightManager runtime setters / getters
FFI_PLUGIN_EXPORT void filament_light_set_color(void* engine, uint32_t entity, float r, float g, float b);
FFI_PLUGIN_EXPORT void filament_light_get_color(void* engine, uint32_t entity, float* out_rgb);
FFI_PLUGIN_EXPORT void filament_light_set_intensity(void* engine, uint32_t entity, float intensity);
FFI_PLUGIN_EXPORT void filament_light_set_intensity_candela(void* engine, uint32_t entity, float intensity);
FFI_PLUGIN_EXPORT void filament_light_set_intensity_watts(void* engine, uint32_t entity, float watts, float efficiency);
FFI_PLUGIN_EXPORT float filament_light_get_intensity(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_light_set_direction(void* engine, uint32_t entity, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_light_get_direction(void* engine, uint32_t entity, float* out_xyz);
FFI_PLUGIN_EXPORT void filament_light_set_position(void* engine, uint32_t entity, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_light_get_position(void* engine, uint32_t entity, float* out_xyz);
FFI_PLUGIN_EXPORT void filament_light_set_falloff(void* engine, uint32_t entity, float radius);
FFI_PLUGIN_EXPORT float filament_light_get_falloff(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_light_set_spot_light_cone(void* engine, uint32_t entity, float inner, float outer);
FFI_PLUGIN_EXPORT float filament_light_get_spot_light_inner_cone(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT float filament_light_get_spot_light_outer_cone(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_light_set_shadow_caster(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT bool filament_light_is_shadow_caster(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_light_set_light_channel(void* engine, uint32_t entity, unsigned int channel, bool enable);
FFI_PLUGIN_EXPORT bool filament_light_get_light_channel(void* engine, uint32_t entity, unsigned int channel);

// LightManager component queries
FFI_PLUGIN_EXPORT bool filament_light_has_component(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_light_get_instance(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT int filament_light_get_type(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_light_get_component_count(void* engine);
FFI_PLUGIN_EXPORT void filament_light_get_entities(void* engine, uint32_t* out_entities, uint32_t capacity);

// ShadowOptions & Cascaded Shadow Maps (CSM)
typedef struct FilamentShadowOptions {
    uint32_t map_size;
    uint8_t shadow_cascades;
    float cascade_split_positions[3];
    float constant_bias;
    float normal_bias;
    float shadow_far;
    float shadow_near_hint;
    float shadow_far_hint;
    bool stable;
    bool lispsm;
    float polygon_offset_constant;
    float polygon_offset_slope;
    bool screen_space_contact_shadows;
    uint8_t step_count;
    float max_shadow_distance;
    bool elvsm;
    float blur_width;
    float shadow_bulb_radius;
    float transform[4];
    float penumbra_scale;
    float penumbra_ratio_scale;
    float max_penumbra_ratio;
    // Trace hard shadows against the scene's ray tracing acceleration structures instead
    // of the cascaded shadow maps (directional lights; needs ray query support and
    // filament_scene_set_ray_tracing_enabled, falls back to the maps otherwise).
    bool ray_traced;
} FilamentShadowOptions;

FFI_PLUGIN_EXPORT size_t filament_sizeof_shadow_options(void);
FFI_PLUGIN_EXPORT void filament_light_builder_shadow_options(void* builder, const FilamentShadowOptions* options);
FFI_PLUGIN_EXPORT void filament_light_set_shadow_options(void* engine, uint32_t entity, const FilamentShadowOptions* options);
FFI_PLUGIN_EXPORT void filament_light_get_shadow_options(void* engine, uint32_t entity, FilamentShadowOptions* out_options);
FFI_PLUGIN_EXPORT void filament_shadow_cascades_compute_uniform_splits(float* out_splits, uint8_t cascades);
FFI_PLUGIN_EXPORT void filament_shadow_cascades_compute_log_splits(float* out_splits, uint8_t cascades, float near_plane, float far_plane);
FFI_PLUGIN_EXPORT void filament_shadow_cascades_compute_practical_splits(float* out_splits, uint8_t cascades, float near_plane, float far_plane, float lambda);

// Skybox
FFI_PLUGIN_EXPORT void* filament_skybox_create_color(void* engine, float r, float g, float b, float a);
FFI_PLUGIN_EXPORT void* filament_skybox_create_from_ktx(void* engine, const void* ktx_data, uint32_t size, bool show_sun);
FFI_PLUGIN_EXPORT void* filament_skybox_create_ex(void* engine, void* environment_cubemap, float color_r, float color_g, float color_b, float color_a, bool show_sun, float intensity, uint8_t priority);
FFI_PLUGIN_EXPORT void  filament_skybox_set_color(void* skybox, float r, float g, float b, float a);
FFI_PLUGIN_EXPORT void  filament_skybox_set_layer_mask(void* skybox, uint8_t select, uint8_t values);
FFI_PLUGIN_EXPORT uint8_t filament_skybox_get_layer_mask(void* skybox);
FFI_PLUGIN_EXPORT float filament_skybox_get_intensity(void* skybox);
FFI_PLUGIN_EXPORT void* filament_skybox_get_texture(void* skybox);
FFI_PLUGIN_EXPORT void filament_engine_destroy_skybox(void* engine, void* skybox);

// IndirectLight
FFI_PLUGIN_EXPORT void* filament_indirect_light_create(void* engine, void* cubemap_texture, float intensity);
FFI_PLUGIN_EXPORT void* filament_indirect_light_create_from_ktx(void* engine, const void* ktx_data, uint32_t size, float intensity);
FFI_PLUGIN_EXPORT void* filament_indirect_light_create_ex(void* engine, void* reflections_cubemap, uint8_t irradiance_bands, const float* irradiance_sh, uint8_t radiance_bands, const float* radiance_sh, float intensity, const float* rotation);
FFI_PLUGIN_EXPORT void filament_indirect_light_set_intensity(void* indirect_light, float intensity);
FFI_PLUGIN_EXPORT float filament_indirect_light_get_intensity(void* indirect_light);
FFI_PLUGIN_EXPORT void filament_indirect_light_set_rotation(void* ibl, const float* rotation9);
FFI_PLUGIN_EXPORT void filament_indirect_light_get_rotation(void* ibl, float* out9);
FFI_PLUGIN_EXPORT void* filament_indirect_light_get_reflections_texture(void* ibl);
FFI_PLUGIN_EXPORT void* filament_indirect_light_get_irradiance_texture(void* ibl);
FFI_PLUGIN_EXPORT void filament_indirect_light_get_direction_estimate(void* ibl, float* out_dir3);
FFI_PLUGIN_EXPORT void filament_indirect_light_get_color_estimate(void* ibl, float dir_x, float dir_y, float dir_z, float* out_rgba4);
FFI_PLUGIN_EXPORT void filament_indirect_light_direction_estimate_static(const float* sh27, float* out_dir3);
FFI_PLUGIN_EXPORT void filament_indirect_light_color_estimate_static(const float* sh27, float dir_x, float dir_y, float dir_z, float* out_rgba4);
FFI_PLUGIN_EXPORT void filament_engine_destroy_indirect_light(void* engine, void* ibl);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
/// Drops the owned-texture records of [engine] (its textures die with
/// it); called by `filament_engine_destroy`.
void flutter_filament_forget_owned_textures(void* engine);
#endif

#endif // FLUTTER_FILAMENT_LIGHTING_C_H
