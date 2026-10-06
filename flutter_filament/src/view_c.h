/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_VIEW_C_H
#define FLUTTER_FILAMENT_VIEW_C_H

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

// View Options Enums and Structs

typedef enum filament_quality_level {
    FILAMENT_QUALITY_LOW = 0,
    FILAMENT_QUALITY_MEDIUM,
    FILAMENT_QUALITY_HIGH,
    FILAMENT_QUALITY_ULTRA
} filament_quality_level;

typedef enum filament_blend_mode {
    FILAMENT_BLEND_OPAQUE = 0,
    FILAMENT_BLEND_TRANSLUCENT
} filament_blend_mode;

typedef struct filament_dynamic_resolution_options {
    float minScale[2];
    float maxScale[2];
    float sharpness;
    bool enabled;
    bool homogeneousScaling;
    uint8_t quality; // filament_quality_level
    uint8_t upscaler; // filament_upscaler
} filament_dynamic_resolution_options;

typedef enum filament_upscaler {
    FILAMENT_UPSCALER_BUILTIN = 0,
    FILAMENT_UPSCALER_EXTERNAL = 1
} filament_upscaler;

typedef enum filament_bloom_blend_mode {
    FILAMENT_BLOOM_BLEND_ADD = 0,
    FILAMENT_BLOOM_BLEND_INTERPOLATE
} filament_bloom_blend_mode;

typedef struct filament_bloom_options {
    void* dirt;
    float dirtStrength;
    float strength;
    uint32_t resolution;
    uint8_t levels;
    uint8_t blendMode; // filament_bloom_blend_mode
    bool threshold;
    bool enabled;
    float highlight;
    uint8_t quality; // filament_quality_level
    bool lensFlare;
    bool starburst;
    float chromaticAberration;
    uint8_t ghostCount;
    float ghostSpacing;
    float ghostThreshold;
    float haloThickness;
    float haloRadius;
    float haloThreshold;
} filament_bloom_options;

typedef struct filament_fog_options {
    float distance;
    float cutOffDistance;
    float maximumOpacity;
    float height;
    float heightFalloff;
    float color[3];
    float density;
    float inScatteringStart;
    float inScatteringSize;
    bool fogColorFromIbl;
    void* skyColor;
    bool enabled;
} filament_fog_options;

typedef enum filament_dof_filter {
    FILAMENT_DOF_FILTER_NONE = 0,
    FILAMENT_DOF_FILTER_UNUSED,
    FILAMENT_DOF_FILTER_MEDIAN
} filament_dof_filter;

typedef struct filament_depth_of_field_options {
    float cocScale;
    float cocAspectRatio;
    float maxApertureDiameter;
    bool enabled;
    uint8_t filter; // filament_dof_filter
    bool nativeResolution;
    uint8_t foregroundRingCount;
    uint8_t backgroundRingCount;
    uint8_t fastGatherRingCount;
    uint16_t maxForegroundCOC;
    uint16_t maxBackgroundCOC;
} filament_depth_of_field_options;

typedef struct filament_vignette_options {
    float midPoint;
    float roundness;
    float feather;
    float color[4];
    bool enabled;
} filament_vignette_options;

typedef struct filament_render_quality {
    uint8_t hdrColorBuffer; // filament_quality_level
} filament_render_quality;

typedef enum filament_ao_type {
    FILAMENT_AO_SAO = 0,
    FILAMENT_AO_GTAO
} filament_ao_type;

typedef struct filament_ambient_occlusion_options_ssct {
    float lightConeRad;
    float shadowDistance;
    float contactDistanceMax;
    float intensity;
    float lightDirection[3];
    float depthBias;
    float depthSlopeBias;
    uint8_t sampleCount;
    uint8_t rayCount;
    bool enabled;
} filament_ambient_occlusion_options_ssct;

typedef struct filament_ambient_occlusion_options_gtao {
    uint8_t sampleSliceCount;
    uint8_t sampleStepsPerSlice;
    float thicknessHeuristic;
    bool useVisibilityBitmasks;
    float constThickness;
    bool linearThickness;
} filament_ambient_occlusion_options_gtao;

typedef struct filament_ambient_occlusion_options {
    uint8_t aoType; // filament_ao_type
    float radius;
    float power;
    float bias;
    float resolution;
    float intensity;
    float bilateralThreshold;
    uint8_t quality; // filament_quality_level
    uint8_t lowPassFilter; // filament_quality_level
    uint8_t upsampling; // filament_quality_level
    bool enabled;
    bool bentNormals;
    float minHorizonAngleRad;
    filament_ambient_occlusion_options_ssct ssct;
    filament_ambient_occlusion_options_gtao gtao;
} filament_ambient_occlusion_options;

typedef struct filament_multi_sample_anti_aliasing_options {
    bool enabled;
    uint8_t sampleCount;
    bool customResolve;
} filament_multi_sample_anti_aliasing_options;

typedef enum filament_taa_box_type {
    FILAMENT_TAA_BOX_AABB = 0,
    FILAMENT_TAA_BOX_AABB_VARIANCE
} filament_taa_box_type;

typedef enum filament_taa_box_clipping {
    FILAMENT_TAA_BOX_ACCURATE = 0,
    FILAMENT_TAA_BOX_CLAMP,
    FILAMENT_TAA_BOX_NONE
} filament_taa_box_clipping;

typedef enum filament_taa_jitter_pattern {
    FILAMENT_TAA_JITTER_RGSS_X4 = 0,
    FILAMENT_TAA_JITTER_UNIFORM_HELIX_X4,
    FILAMENT_TAA_JITTER_HALTON_23_X8,
    FILAMENT_TAA_JITTER_HALTON_23_X16,
    FILAMENT_TAA_JITTER_HALTON_23_X32
} filament_taa_jitter_pattern;

typedef struct filament_temporal_anti_aliasing_options {
    float filterWidth;
    float feedback;
    float lodBias;
    float sharpness;
    bool enabled;
    float upscaling;
    bool filterHistory;
    bool filterInput;
    bool useYCoCg;
    bool hdr;
    uint8_t boxType; // filament_taa_box_type
    uint8_t boxClipping; // filament_taa_box_clipping
    uint8_t jitterPattern; // filament_taa_jitter_pattern
    float varianceGamma;
    bool preventFlickering;
    bool historyReprojection;
    // Render per-pixel motion vectors in the structure pass (full resolution) and reproject
    // the TAA history with them. See filament_view_set_motion_vector_texture.
    bool motionVectors;
} filament_temporal_anti_aliasing_options;

typedef struct filament_screen_space_reflections_options {
    float thickness;
    float bias;
    float maxDistance;
    float stride;
    bool enabled;
} filament_screen_space_reflections_options;

typedef struct filament_guard_band_options {
    bool enabled;
} filament_guard_band_options;

typedef enum filament_anti_aliasing {
    FILAMENT_ANTI_ALIASING_NONE = 0,
    FILAMENT_ANTI_ALIASING_FXAA
} filament_anti_aliasing;

typedef enum filament_dithering {
    FILAMENT_DITHERING_NONE = 0,
    FILAMENT_DITHERING_TEMPORAL
} filament_dithering;

typedef enum filament_shadow_type {
    FILAMENT_SHADOW_TYPE_PCF = 0,
    FILAMENT_SHADOW_TYPE_VSM,
    FILAMENT_SHADOW_TYPE_DPCF,
    FILAMENT_SHADOW_TYPE_PCSS,
    FILAMENT_SHADOW_TYPE_PCFD
} filament_shadow_type;

typedef struct filament_vsm_shadow_options {
    uint8_t anisotropy;
    bool mipmapping;
    uint8_t msaaSamples;
    bool highPrecision;
    float minVarianceScale;
    float lightBleedReduction;
} filament_vsm_shadow_options;

typedef struct filament_soft_shadow_options {
    float penumbraScale;
    float penumbraRatioScale;
    float maxPenumbraRatio;
    float maxSearchRadius;
} filament_soft_shadow_options;

typedef struct filament_stereoscopic_options {
    bool enabled;
} filament_stereoscopic_options;

FFI_PLUGIN_EXPORT uint32_t filament_options_sizeof(int which);

// View
FFI_PLUGIN_EXPORT void* filament_engine_create_view(void* engine);
FFI_PLUGIN_EXPORT void filament_engine_destroy_view(void* engine, void* view);
FFI_PLUGIN_EXPORT void filament_view_set_scene(void* view, void* scene);
FFI_PLUGIN_EXPORT void filament_view_set_camera(void* view, void* camera);
FFI_PLUGIN_EXPORT void filament_view_set_viewport(void* view, int32_t left, int32_t bottom, uint32_t width, uint32_t height);
FFI_PLUGIN_EXPORT void filament_view_set_name(void* view, const char* name);
FFI_PLUGIN_EXPORT void filament_view_set_shadowing_enabled(void* view, bool enabled);
typedef void (*FilamentPickCallback)(uint32_t renderable, float depth, float frag_x, float frag_y, void* user_data);

FFI_PLUGIN_EXPORT void filament_view_pick(void* view, uint32_t x, uint32_t y, FilamentPickCallback callback, void* user_data);
FFI_PLUGIN_EXPORT void filament_view_set_transparent_picking_enabled(void* view, bool enabled);
FFI_PLUGIN_EXPORT bool filament_view_is_transparent_picking_enabled(void* view);

FFI_PLUGIN_EXPORT const char* filament_view_get_name(void* view);
FFI_PLUGIN_EXPORT void* filament_view_get_scene(void* view);
FFI_PLUGIN_EXPORT void* filament_view_get_camera(void* view);
FFI_PLUGIN_EXPORT bool filament_view_has_camera(void* view);
FFI_PLUGIN_EXPORT void filament_view_get_viewport(void* view, int32_t* out_left_bottom, uint32_t* out_width_height);
FFI_PLUGIN_EXPORT void* filament_view_get_render_target(void* view);
FFI_PLUGIN_EXPORT uint8_t filament_view_get_visible_layers(void* view);
FFI_PLUGIN_EXPORT bool filament_view_is_shadowing_enabled(void* view);
FFI_PLUGIN_EXPORT bool filament_view_is_screen_space_refraction_enabled(void* view);
FFI_PLUGIN_EXPORT int filament_view_get_anti_aliasing(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_post_processing_enabled(void* view, bool enabled);
FFI_PLUGIN_EXPORT bool filament_view_is_post_processing_enabled(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_blend_mode(void* view, int blend_mode);
FFI_PLUGIN_EXPORT int filament_view_get_blend_mode(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_stencil_buffer_enabled(void* view, bool enabled);
FFI_PLUGIN_EXPORT bool filament_view_is_stencil_buffer_enabled(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_front_face_winding_inverted(void* view, bool inverted);
FFI_PLUGIN_EXPORT bool filament_view_is_front_face_winding_inverted(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_dynamic_lighting_options(void* view, float z_light_near, float z_light_far);

FFI_PLUGIN_EXPORT void filament_view_set_material_global(void* view, uint32_t index, float x, float y, float z, float w);
FFI_PLUGIN_EXPORT void filament_view_get_material_global(void* view, uint32_t index, float* out_xyzw);

FFI_PLUGIN_EXPORT void filament_view_clear_frame_history(void* view, void* engine);
FFI_PLUGIN_EXPORT void filament_view_set_layer_enabled(void* view, uint32_t layer, bool enabled);
FFI_PLUGIN_EXPORT uint32_t filament_view_get_visible_renderable_count(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_anti_aliasing(void* view, int type);
FFI_PLUGIN_EXPORT void filament_view_set_screen_space_refraction_enabled(void* view, bool enabled);
FFI_PLUGIN_EXPORT void filament_view_set_visible_layers(void* view, uint8_t select, uint8_t values);
FFI_PLUGIN_EXPORT void filament_view_set_render_target(void* view, void* render_target);

FFI_PLUGIN_EXPORT void filament_view_set_bloom_options(void* view, const filament_bloom_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_bloom_options(void* view, filament_bloom_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_fog_options(void* view, const filament_fog_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_fog_options(void* view, filament_fog_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_depth_of_field_options(void* view, const filament_depth_of_field_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_depth_of_field_options(void* view, filament_depth_of_field_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_vignette_options(void* view, const filament_vignette_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_vignette_options(void* view, filament_vignette_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_ambient_occlusion_options(void* view, const filament_ambient_occlusion_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_ambient_occlusion_options(void* view, filament_ambient_occlusion_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_temporal_anti_aliasing_options(void* view, const filament_temporal_anti_aliasing_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_temporal_anti_aliasing_options(void* view, filament_temporal_anti_aliasing_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_multi_sample_anti_aliasing_options(void* view, const filament_multi_sample_anti_aliasing_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_multi_sample_anti_aliasing_options(void* view, filament_multi_sample_anti_aliasing_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_screen_space_reflections_options(void* view, const filament_screen_space_reflections_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_screen_space_reflections_options(void* view, filament_screen_space_reflections_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_guard_band_options(void* view, const filament_guard_band_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_guard_band_options(void* view, filament_guard_band_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_dynamic_resolution_options(void* view, const filament_dynamic_resolution_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_dynamic_resolution_options(void* view, filament_dynamic_resolution_options* out_options);
FFI_PLUGIN_EXPORT void filament_view_get_last_dynamic_resolution_scale(void* view, float* out_xy);

FFI_PLUGIN_EXPORT void filament_view_set_shadow_type(void* view, int shadow_type);
FFI_PLUGIN_EXPORT int filament_view_get_shadow_type(void* view);

FFI_PLUGIN_EXPORT void filament_view_set_vsm_shadow_options(void* view, const filament_vsm_shadow_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_vsm_shadow_options(void* view, filament_vsm_shadow_options* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_soft_shadow_options(void* view, const filament_soft_shadow_options* options);
FFI_PLUGIN_EXPORT void filament_view_get_soft_shadow_options(void* view, filament_soft_shadow_options* out_options);


FFI_PLUGIN_EXPORT void filament_view_set_render_quality(void* view, const filament_render_quality* options);
FFI_PLUGIN_EXPORT void filament_view_get_render_quality(void* view, filament_render_quality* out_options);

FFI_PLUGIN_EXPORT void filament_view_set_dithering(void* view, int dithering);
FFI_PLUGIN_EXPORT int filament_view_get_dithering(void* view);

// Scene
FFI_PLUGIN_EXPORT void* filament_engine_create_scene(void* engine);
FFI_PLUGIN_EXPORT void filament_engine_destroy_scene(void* engine, void* scene);
FFI_PLUGIN_EXPORT void filament_scene_add_entity(void* scene, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_scene_add_entities(void* scene, const uint32_t* entities, uint32_t count);
FFI_PLUGIN_EXPORT void filament_scene_remove_entity(void* scene, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_scene_remove_entities(void* scene, const uint32_t* entities, uint32_t count);
FFI_PLUGIN_EXPORT void filament_scene_remove_all_entities(void* scene);
FFI_PLUGIN_EXPORT bool filament_scene_has_entity(void* scene, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_scene_get_entity_count(void* scene);
FFI_PLUGIN_EXPORT uint32_t filament_scene_get_renderable_count(void* scene);
FFI_PLUGIN_EXPORT uint32_t filament_scene_get_light_count(void* scene);
FFI_PLUGIN_EXPORT void filament_scene_set_skybox(void* scene, void* skybox);
FFI_PLUGIN_EXPORT void* filament_scene_get_skybox(void* scene);
FFI_PLUGIN_EXPORT void filament_scene_set_indirect_light(void* scene, void* ibl);
FFI_PLUGIN_EXPORT void* filament_scene_get_indirect_light(void* scene);

// Camera
FFI_PLUGIN_EXPORT void* filament_engine_create_camera(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_engine_destroy_camera_component(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_camera_set_projection_fov(void* camera, double fov_degrees, double aspect, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_set_projection_ortho(void* camera, double left, double right, double bottom, double top, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_look_at(void* camera, double eye_x, double eye_y, double eye_z, double center_x, double center_y, double center_z, double up_x, double up_y, double up_z);
FFI_PLUGIN_EXPORT void filament_camera_set_exposure(void* camera, float aperture, float shutter_speed, float sensitivity);

// RenderTarget
typedef struct filament_rt_attachment_t {
    void*    texture;
    uint8_t  mip_level;
    int32_t  face;
    uint32_t layer;
} filament_rt_attachment_t;

// ==========================================
// Motion vectors
// ==========================================
// Whether this engine can render motion vectors: a real GPU backend at feature level 1 or
// higher with RG16F colour attachments. False on the noop backend.
FFI_PLUGIN_EXPORT bool filament_view_motion_vectors_supported(void* engine);
// Exports the motion vectors of a view whose TAA options have motionVectors on into
// `texture` (a two-or-more-channel float colour texture, colour attachment + sampleable,
// exactly the size of the view's render target; texels of screen motion since the previous
// frame, x right, y up). NULL stops the export. The texture must outlive its use.
FFI_PLUGIN_EXPORT void filament_view_set_motion_vector_texture(void* view, void* texture);
// The texture set with filament_view_set_motion_vector_texture, or NULL.
FFI_PLUGIN_EXPORT void* filament_view_get_motion_vector_texture(void* view);

FFI_PLUGIN_EXPORT void* filament_render_target_create_ex(void* engine,
        const filament_rt_attachment_t* color_attachments, uint32_t color_count,
        const filament_rt_attachment_t* depth_attachment,
        uint8_t samples);

FFI_PLUGIN_EXPORT uint8_t filament_render_target_get_supported_color_attachments_count(void* engine);

FFI_PLUGIN_EXPORT void* filament_render_target_create(void* engine, void* color_texture, void* depth_texture);
FFI_PLUGIN_EXPORT void filament_engine_destroy_render_target(void* engine, void* render_target);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_VIEW_C_H
