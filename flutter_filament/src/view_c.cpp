/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "view_c.h"

#include <filament/Engine.h>
#include <filament/View.h>
#include <filament/Viewport.h>
#include <filament/Scene.h>
#include <filament/Camera.h>
#include <filament/RenderTarget.h>
#include <filament/Skybox.h>
#include <filament/IndirectLight.h>
#include <filament/Texture.h>
#include <utils/Entity.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[View C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[View C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[View C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline View* toView(void* p) { return reinterpret_cast<View*>(p); }
static inline Scene* toScene(void* p) { return reinterpret_cast<Scene*>(p); }
static inline Camera* toCamera(void* p) { return reinterpret_cast<Camera*>(p); }
static inline RenderTarget* toRenderTarget(void* p) { return reinterpret_cast<RenderTarget*>(p); }
static inline Skybox* toSkybox(void* p) { return reinterpret_cast<Skybox*>(p); }
static inline IndirectLight* toIndirectLight(void* p) { return reinterpret_cast<IndirectLight*>(p); }
static inline Texture* toTexture(void* p) { return reinterpret_cast<Texture*>(p); }
static inline Entity toEntity(uint32_t e) { return Entity::import(static_cast<int>(e)); }

uint32_t filament_options_sizeof(int which) {
    switch (which) {
        case 0: return static_cast<uint32_t>(sizeof(DynamicResolutionOptions));
        case 1: return static_cast<uint32_t>(sizeof(BloomOptions));
        case 2: return static_cast<uint32_t>(sizeof(FogOptions));
        case 3: return static_cast<uint32_t>(sizeof(DepthOfFieldOptions));
        case 4: return static_cast<uint32_t>(sizeof(VignetteOptions));
        case 5: return static_cast<uint32_t>(sizeof(RenderQuality));
        case 6: return static_cast<uint32_t>(sizeof(AmbientOcclusionOptions));
        case 7: return static_cast<uint32_t>(sizeof(MultiSampleAntiAliasingOptions));
        case 8: return static_cast<uint32_t>(sizeof(TemporalAntiAliasingOptions));
        case 9: return static_cast<uint32_t>(sizeof(ScreenSpaceReflectionsOptions));
        case 10: return static_cast<uint32_t>(sizeof(GuardBandOptions));
        case 11: return static_cast<uint32_t>(sizeof(VsmShadowOptions));
        case 12: return static_cast<uint32_t>(sizeof(SoftShadowOptions));
        case 13: return static_cast<uint32_t>(sizeof(StereoscopicOptions));
        case 14: return static_cast<uint32_t>(sizeof(RestirOptions));
        default: return 0;
    }
}

void* filament_engine_create_view(void* engine) {
    FFI_TRY return toEngine(engine)->createView(); FFI_CATCH(nullptr)
}
void filament_engine_destroy_view(void* engine, void* view) {
    FFI_TRY toEngine(engine)->destroy(toView(view)); FFI_CATCH()
}
void filament_view_set_scene(void* view, void* scene) {
    FFI_TRY toView(view)->setScene(toScene(scene)); FFI_CATCH()
}
#include "callback_bridge_c.h"

// Wait, I might need to make sure I include `<string.h>` or `<stdlib.h>` if needed.
#include <string.h>

void filament_view_set_camera(void* view, void* camera) {
    FFI_TRY toView(view)->setCamera(toCamera(camera)); FFI_CATCH()
}
void filament_view_set_viewport(void* view, int32_t left, int32_t bottom, uint32_t width, uint32_t height) {
    FFI_TRY toView(view)->setViewport({left, bottom, width, height}); FFI_CATCH()
}
void filament_view_set_name(void* view, const char* name) {
    FFI_TRY toView(view)->setName(name); FFI_CATCH()
}
void filament_view_set_shadowing_enabled(void* view, bool enabled) {
    FFI_TRY toView(view)->setShadowingEnabled(enabled); FFI_CATCH()
}
void filament_view_set_post_processing_enabled(void* view, bool enabled) {
    FFI_TRY toView(view)->setPostProcessingEnabled(enabled); FFI_CATCH()
}

bool filament_view_is_post_processing_enabled(void* view) {
    FFI_TRY return toView(view)->isPostProcessingEnabled(); FFI_CATCH(false)
}

void filament_view_set_blend_mode(void* view, int blend_mode) {
    FFI_TRY toView(view)->setBlendMode(static_cast<BlendMode>(blend_mode)); FFI_CATCH()
}

int filament_view_get_blend_mode(void* view) {
    FFI_TRY return static_cast<int>(toView(view)->getBlendMode()); FFI_CATCH(0)
}

void filament_view_set_stencil_buffer_enabled(void* view, bool enabled) {
    FFI_TRY toView(view)->setStencilBufferEnabled(enabled); FFI_CATCH()
}

bool filament_view_is_stencil_buffer_enabled(void* view) {
    FFI_TRY return toView(view)->isStencilBufferEnabled(); FFI_CATCH(false)
}

void filament_view_set_front_face_winding_inverted(void* view, bool inverted) {
    FFI_TRY toView(view)->setFrontFaceWindingInverted(inverted); FFI_CATCH()
}

bool filament_view_is_front_face_winding_inverted(void* view) {
    FFI_TRY return toView(view)->isFrontFaceWindingInverted(); FFI_CATCH(false)
}

void filament_view_set_dynamic_lighting_options(void* view, float z_light_near, float z_light_far) {
    FFI_TRY toView(view)->setDynamicLightingOptions(z_light_near, z_light_far); FFI_CATCH()
}

void filament_view_set_material_global(void* view, uint32_t index, float x, float y, float z, float w) {
    FFI_TRY toView(view)->setMaterialGlobal(index, {x, y, z, w}); FFI_CATCH()
}

void filament_view_get_material_global(void* view, uint32_t index, float* out_xyzw) {
    FFI_TRY 
    auto val = toView(view)->getMaterialGlobal(index);
    out_xyzw[0] = val.x;
    out_xyzw[1] = val.y;
    out_xyzw[2] = val.z;
    out_xyzw[3] = val.w;
    FFI_CATCH()
}

void filament_view_clear_frame_history(void* view, void* engine) {
    FFI_TRY toView(view)->clearFrameHistory(*toEngine(engine)); FFI_CATCH()
}

void filament_view_set_layer_enabled(void* view, uint32_t layer, bool enabled) {
    FFI_TRY toView(view)->setLayerEnabled(layer, enabled); FFI_CATCH()
}

uint32_t filament_view_get_visible_renderable_count(void* view) {
    FFI_TRY return static_cast<uint32_t>(toView(view)->getVisibleRenderableCount()); FFI_CATCH(0)
}

void filament_view_set_anti_aliasing(void* view, int type) {
    FFI_TRY toView(view)->setAntiAliasing(static_cast<View::AntiAliasing>(type)); FFI_CATCH()
}
void filament_view_set_screen_space_refraction_enabled(void* view, bool enabled) {
    FFI_TRY toView(view)->setScreenSpaceRefractionEnabled(enabled); FFI_CATCH()
}
void filament_view_set_visible_layers(void* view, uint8_t select, uint8_t values) {
    FFI_TRY toView(view)->setVisibleLayers(select, values); FFI_CATCH()
}

void filament_view_pick(void* view, uint32_t x, uint32_t y, FilamentPickCallback callback, void* user_data) {
    FFI_TRY
    toView(view)->pick(x, y, [callback, user_data](filament::View::PickingQueryResult const& result) {
        uint32_t renderable = result.renderable.isNull() ? 0 : result.renderable.getId();
        callback(renderable, result.depth, result.fragCoords.x, result.fragCoords.y, user_data);
    });
    FFI_CATCH()
}

void filament_view_set_transparent_picking_enabled(void* view, bool enabled) {
    FFI_TRY toView(view)->setTransparentPickingEnabled(enabled); FFI_CATCH()
}

bool filament_view_is_transparent_picking_enabled(void* view) {
    FFI_TRY return toView(view)->isTransparentPickingEnabled(); FFI_CATCH(false)
}

const char* filament_view_get_name(void* view) {
    FFI_TRY return toView(view)->getName(); FFI_CATCH(nullptr)
}

void* filament_view_get_scene(void* view) {
    FFI_TRY return toView(view)->getScene(); FFI_CATCH(nullptr)
}

void* filament_view_get_camera(void* view) {
    FFI_TRY 
    if (toView(view)->hasCamera()) {
        return &toView(view)->getCamera(); 
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

bool filament_view_has_camera(void* view) {
    FFI_TRY return toView(view)->hasCamera(); FFI_CATCH(false)
}

void filament_view_get_viewport(void* view, int32_t* out_left_bottom, uint32_t* out_width_height) {
    FFI_TRY 
    auto vp = toView(view)->getViewport();
    out_left_bottom[0] = vp.left;
    out_left_bottom[1] = vp.bottom;
    out_width_height[0] = vp.width;
    out_width_height[1] = vp.height;
    FFI_CATCH()
}

void* filament_view_get_render_target(void* view) {
    FFI_TRY return toView(view)->getRenderTarget(); FFI_CATCH(nullptr)
}

uint8_t filament_view_get_visible_layers(void* view) {
    FFI_TRY return toView(view)->getVisibleLayers(); FFI_CATCH(0)
}

bool filament_view_is_shadowing_enabled(void* view) {
    FFI_TRY return toView(view)->isShadowingEnabled(); FFI_CATCH(false)
}

bool filament_view_is_screen_space_refraction_enabled(void* view) {
    FFI_TRY return toView(view)->isScreenSpaceRefractionEnabled(); FFI_CATCH(false)
}

int filament_view_get_anti_aliasing(void* view) {
    FFI_TRY return static_cast<int>(toView(view)->getAntiAliasing()); FFI_CATCH(0)
}
void filament_view_set_render_target(void* view, void* render_target) {
    FFI_TRY toView(view)->setRenderTarget(render_target ? toRenderTarget(render_target) : nullptr); FFI_CATCH()
}

void filament_view_set_bloom_options(void* view, const filament_bloom_options* options) {
    FFI_TRY toView(view)->setBloomOptions(*reinterpret_cast<const BloomOptions*>(options)); FFI_CATCH()
}
void filament_view_get_bloom_options(void* view, filament_bloom_options* out_options) {
    FFI_TRY *reinterpret_cast<BloomOptions*>(out_options) = toView(view)->getBloomOptions(); FFI_CATCH()
}

void filament_view_set_fog_options(void* view, const filament_fog_options* options) {
    FFI_TRY toView(view)->setFogOptions(*reinterpret_cast<const FogOptions*>(options)); FFI_CATCH()
}
void filament_view_get_fog_options(void* view, filament_fog_options* out_options) {
    FFI_TRY *reinterpret_cast<FogOptions*>(out_options) = toView(view)->getFogOptions(); FFI_CATCH()
}

void filament_view_set_depth_of_field_options(void* view, const filament_depth_of_field_options* options) {
    FFI_TRY toView(view)->setDepthOfFieldOptions(*reinterpret_cast<const DepthOfFieldOptions*>(options)); FFI_CATCH()
}
void filament_view_get_depth_of_field_options(void* view, filament_depth_of_field_options* out_options) {
    FFI_TRY *reinterpret_cast<DepthOfFieldOptions*>(out_options) = toView(view)->getDepthOfFieldOptions(); FFI_CATCH()
}

void filament_view_set_vignette_options(void* view, const filament_vignette_options* options) {
    FFI_TRY toView(view)->setVignetteOptions(*reinterpret_cast<const VignetteOptions*>(options)); FFI_CATCH()
}
void filament_view_get_vignette_options(void* view, filament_vignette_options* out_options) {
    FFI_TRY *reinterpret_cast<VignetteOptions*>(out_options) = toView(view)->getVignetteOptions(); FFI_CATCH()
}

void filament_view_set_ambient_occlusion_options(void* view, const filament_ambient_occlusion_options* options) {
    FFI_TRY toView(view)->setAmbientOcclusionOptions(*reinterpret_cast<const AmbientOcclusionOptions*>(options)); FFI_CATCH()
}
void filament_view_get_ambient_occlusion_options(void* view, filament_ambient_occlusion_options* out_options) {
    FFI_TRY *reinterpret_cast<AmbientOcclusionOptions*>(out_options) = toView(view)->getAmbientOcclusionOptions(); FFI_CATCH()
}

void filament_view_set_temporal_anti_aliasing_options(void* view, const filament_temporal_anti_aliasing_options* options) {
    FFI_TRY toView(view)->setTemporalAntiAliasingOptions(*reinterpret_cast<const TemporalAntiAliasingOptions*>(options)); FFI_CATCH()
}
void filament_view_get_temporal_anti_aliasing_options(void* view, filament_temporal_anti_aliasing_options* out_options) {
    FFI_TRY *reinterpret_cast<TemporalAntiAliasingOptions*>(out_options) = toView(view)->getTemporalAntiAliasingOptions(); FFI_CATCH()
}

bool filament_view_motion_vectors_supported(void* engine) {
    FFI_TRY
        Engine* const e = toEngine(engine);
        if (e == nullptr || e->getBackend() == Engine::Backend::NOOP) return false;
        if (e->getActiveFeatureLevel() == Engine::FeatureLevel::FEATURE_LEVEL_0) return false;
        return Texture::isTextureFormatSupported(*e, Texture::InternalFormat::RG16F);
    FFI_CATCH(false)
}

void filament_view_set_motion_vector_texture(void* view, void* texture) {
    FFI_TRY toView(view)->setMotionVectorTexture(reinterpret_cast<Texture const*>(texture)); FFI_CATCH()
}

void* filament_view_get_motion_vector_texture(void* view) {
    FFI_TRY return const_cast<Texture*>(toView(view)->getMotionVectorTexture()); FFI_CATCH(nullptr)
}

void filament_view_set_multi_sample_anti_aliasing_options(void* view, const filament_multi_sample_anti_aliasing_options* options) {
    FFI_TRY toView(view)->setMultiSampleAntiAliasingOptions(*reinterpret_cast<const MultiSampleAntiAliasingOptions*>(options)); FFI_CATCH()
}
void filament_view_get_multi_sample_anti_aliasing_options(void* view, filament_multi_sample_anti_aliasing_options* out_options) {
    FFI_TRY *reinterpret_cast<MultiSampleAntiAliasingOptions*>(out_options) = toView(view)->getMultiSampleAntiAliasingOptions(); FFI_CATCH()
}

void filament_view_set_screen_space_reflections_options(void* view, const filament_screen_space_reflections_options* options) {
    FFI_TRY toView(view)->setScreenSpaceReflectionsOptions(*reinterpret_cast<const ScreenSpaceReflectionsOptions*>(options)); FFI_CATCH()
}
void filament_view_get_screen_space_reflections_options(void* view, filament_screen_space_reflections_options* out_options) {
    FFI_TRY *reinterpret_cast<ScreenSpaceReflectionsOptions*>(out_options) = toView(view)->getScreenSpaceReflectionsOptions(); FFI_CATCH()
}

void filament_view_set_guard_band_options(void* view, const filament_guard_band_options* options) {
    FFI_TRY toView(view)->setGuardBandOptions(*reinterpret_cast<const GuardBandOptions*>(options)); FFI_CATCH()
}
void filament_view_get_guard_band_options(void* view, filament_guard_band_options* out_options) {
    FFI_TRY *reinterpret_cast<GuardBandOptions*>(out_options) = toView(view)->getGuardBandOptions(); FFI_CATCH()
}

void filament_view_set_dynamic_resolution_options(void* view, const filament_dynamic_resolution_options* options) {
    FFI_TRY 
    View::DynamicResolutionOptions opts;
    opts.minScale = {options->minScale[0], options->minScale[1]};
    opts.maxScale = {options->maxScale[0], options->maxScale[1]};
    opts.sharpness = options->sharpness;
    opts.enabled = options->enabled;
    opts.homogeneousScaling = options->homogeneousScaling;
    opts.quality = static_cast<QualityLevel>(options->quality);
    opts.upscaler = static_cast<Upscaler>(options->upscaler);
    toView(view)->setDynamicResolutionOptions(opts);
    FFI_CATCH()
}
void filament_view_get_dynamic_resolution_options(void* view, filament_dynamic_resolution_options* out_options) {
    FFI_TRY 
    auto opts = toView(view)->getDynamicResolutionOptions();
    out_options->minScale[0] = opts.minScale.x;
    out_options->minScale[1] = opts.minScale.y;
    out_options->maxScale[0] = opts.maxScale.x;
    out_options->maxScale[1] = opts.maxScale.y;
    out_options->sharpness = opts.sharpness;
    out_options->enabled = opts.enabled;
    out_options->homogeneousScaling = opts.homogeneousScaling;
    out_options->quality = static_cast<uint8_t>(opts.quality);
    out_options->upscaler = static_cast<uint8_t>(opts.upscaler);
    FFI_CATCH()
}
void filament_view_get_last_dynamic_resolution_scale(void* view, float* out_xy) {
    FFI_TRY
    auto scale = toView(view)->getLastDynamicResolutionScale();
    out_xy[0] = scale.x;
    out_xy[1] = scale.y;
    FFI_CATCH()
}

void filament_view_set_shadow_type(void* view, int shadow_type) {
    FFI_TRY
    toView(view)->setShadowType(static_cast<ShadowType>(shadow_type));
    FFI_CATCH()
}

int filament_view_get_shadow_type(void* view) {
    FFI_TRY
    return static_cast<int>(toView(view)->getShadowType());
    FFI_CATCH(0)
}

void filament_view_set_vsm_shadow_options(void* view, const filament_vsm_shadow_options* options) {
    FFI_TRY
    View::VsmShadowOptions opts;
    opts.anisotropy = options->anisotropy;
    opts.mipmapping = options->mipmapping;
    opts.msaaSamples = options->msaaSamples;
    opts.highPrecision = options->highPrecision;
    opts.minVarianceScale = options->minVarianceScale;
    opts.lightBleedReduction = options->lightBleedReduction;
    toView(view)->setVsmShadowOptions(opts);
    FFI_CATCH()
}

void filament_view_get_vsm_shadow_options(void* view, filament_vsm_shadow_options* out_options) {
    FFI_TRY
    auto opts = toView(view)->getVsmShadowOptions();
    out_options->anisotropy = opts.anisotropy;
    out_options->mipmapping = opts.mipmapping;
    out_options->msaaSamples = opts.msaaSamples;
    out_options->highPrecision = opts.highPrecision;
    out_options->minVarianceScale = opts.minVarianceScale;
    out_options->lightBleedReduction = opts.lightBleedReduction;
    FFI_CATCH()
}

void filament_view_set_soft_shadow_options(void* view, const filament_soft_shadow_options* options) {
    FFI_TRY
    View::SoftShadowOptions opts;
    opts.penumbraScale = options->penumbraScale;
    opts.penumbraRatioScale = options->penumbraRatioScale;
    opts.maxPenumbraRatio = options->maxPenumbraRatio;
    opts.maxSearchRadius = options->maxSearchRadius;
    toView(view)->setSoftShadowOptions(opts);
    FFI_CATCH()
}

void filament_view_get_soft_shadow_options(void* view, filament_soft_shadow_options* out_options) {
    FFI_TRY
    auto opts = toView(view)->getSoftShadowOptions();
    out_options->penumbraScale = opts.penumbraScale;
    out_options->penumbraRatioScale = opts.penumbraRatioScale;
    out_options->maxPenumbraRatio = opts.maxPenumbraRatio;
    out_options->maxSearchRadius = opts.maxSearchRadius;
    FFI_CATCH()
}

void filament_view_set_render_quality(void* view, const filament_render_quality* options) {
    FFI_TRY toView(view)->setRenderQuality(*reinterpret_cast<const RenderQuality*>(options)); FFI_CATCH()
}
void filament_view_get_render_quality(void* view, filament_render_quality* out_options) {
    FFI_TRY *reinterpret_cast<RenderQuality*>(out_options) = toView(view)->getRenderQuality(); FFI_CATCH()
}

void filament_view_set_dithering(void* view, int dithering) {
    FFI_TRY toView(view)->setDithering(static_cast<View::Dithering>(dithering)); FFI_CATCH()
}
int filament_view_get_dithering(void* view) {
    FFI_TRY return static_cast<int>(toView(view)->getDithering()); FFI_CATCH(0)
}

void* filament_engine_create_scene(void* engine) {
    FFI_TRY return toEngine(engine)->createScene(); FFI_CATCH(nullptr)
}
void filament_engine_destroy_scene(void* engine, void* scene) {
    FFI_TRY toEngine(engine)->destroy(toScene(scene)); FFI_CATCH()
}
void filament_scene_add_entity(void* scene, uint32_t entity) {
    FFI_TRY toScene(scene)->addEntity(toEntity(entity)); FFI_CATCH()
}
void filament_scene_add_entities(void* scene, const uint32_t* entities, uint32_t count) {
    FFI_TRY
    if (!scene || !entities || count == 0) return;
    std::vector<Entity> vec(count);
    for (uint32_t i = 0; i < count; ++i) {
        vec[i] = toEntity(entities[i]);
    }
    toScene(scene)->addEntities(vec.data(), count);
    FFI_CATCH()
}
void filament_scene_remove_entity(void* scene, uint32_t entity) {
    FFI_TRY toScene(scene)->remove(toEntity(entity)); FFI_CATCH()
}
void filament_scene_remove_entities(void* scene, const uint32_t* entities, uint32_t count) {
    FFI_TRY
    if (!scene || !entities || count == 0) return;
    std::vector<Entity> vec(count);
    for (uint32_t i = 0; i < count; ++i) {
        vec[i] = toEntity(entities[i]);
    }
    toScene(scene)->removeEntities(vec.data(), count);
    FFI_CATCH()
}
void filament_scene_remove_all_entities(void* scene) {
    FFI_TRY
    if (!scene) return;
    toScene(scene)->removeAllEntities();
    FFI_CATCH()
}
bool filament_scene_has_entity(void* scene, uint32_t entity) {
    FFI_TRY
    if (!scene) return false;
    return toScene(scene)->hasEntity(toEntity(entity));
    FFI_CATCH(false)
}
uint32_t filament_scene_get_entity_count(void* scene) {
    FFI_TRY return static_cast<uint32_t>(toScene(scene)->getEntityCount()); FFI_CATCH(0)
}
uint32_t filament_scene_get_renderable_count(void* scene) {
    FFI_TRY return static_cast<uint32_t>(toScene(scene)->getRenderableCount()); FFI_CATCH(0)
}
uint32_t filament_scene_get_light_count(void* scene) {
    FFI_TRY return static_cast<uint32_t>(toScene(scene)->getLightCount()); FFI_CATCH(0)
}
void filament_scene_set_skybox(void* scene, void* skybox) {
    FFI_TRY toScene(scene)->setSkybox(skybox ? toSkybox(skybox) : nullptr); FFI_CATCH()
}
void* filament_scene_get_skybox(void* scene) {
    FFI_TRY
    if (!scene) return nullptr;
    return toScene(scene)->getSkybox();
    FFI_CATCH(nullptr)
}
void filament_scene_set_indirect_light(void* scene, void* ibl) {
    FFI_TRY toScene(scene)->setIndirectLight(ibl ? toIndirectLight(ibl) : nullptr); FFI_CATCH()
}
void* filament_scene_get_indirect_light(void* scene) {
    FFI_TRY
    if (!scene) return nullptr;
    return toScene(scene)->getIndirectLight();
    FFI_CATCH(nullptr)
}

void* filament_engine_create_camera(void* engine, uint32_t entity) {
    FFI_TRY return toEngine(engine)->createCamera(toEntity(entity)); FFI_CATCH(nullptr)
}
void filament_engine_destroy_camera_component(void* engine, uint32_t entity) {
    FFI_TRY toEngine(engine)->destroyCameraComponent(toEntity(entity)); FFI_CATCH()
}
void filament_camera_set_projection_fov(void* camera, double fov_degrees, double aspect, double near_plane, double far_plane) {
    FFI_TRY toCamera(camera)->setProjection(fov_degrees, aspect, near_plane, far_plane, Camera::Fov::VERTICAL); FFI_CATCH()
}
void filament_camera_set_projection_ortho(void* camera, double left, double right, double bottom, double top, double near_plane, double far_plane) {
    FFI_TRY toCamera(camera)->setProjection(Camera::Projection::ORTHO, left, right, bottom, top, near_plane, far_plane); FFI_CATCH()
}
void filament_camera_look_at(void* camera, double eye_x, double eye_y, double eye_z, double center_x, double center_y, double center_z, double up_x, double up_y, double up_z) {
    FFI_TRY toCamera(camera)->lookAt({eye_x, eye_y, eye_z}, {center_x, center_y, center_z}, {up_x, up_y, up_z}); FFI_CATCH()
}
void filament_camera_set_exposure(void* camera, float aperture, float shutter_speed, float sensitivity) {
    FFI_TRY toCamera(camera)->setExposure(aperture, shutter_speed, sensitivity); FFI_CATCH()
}

uint8_t filament_render_target_get_supported_color_attachments_count(void* engine) {
    FFI_TRY
    Engine* eng = toEngine(engine);
    Texture* tex = Texture::Builder()
        .width(1).height(1).levels(1)
        .usage(Texture::Usage::COLOR_ATTACHMENT)
        .format(Texture::InternalFormat::RGBA8)
        .build(*eng);
    RenderTarget* rt = RenderTarget::Builder()
        .texture(RenderTarget::AttachmentPoint::COLOR0, tex)
        .build(*eng);
    uint8_t count = rt->getSupportedColorAttachmentsCount();
    eng->destroy(rt);
    eng->destroy(tex);
    return count;
    FFI_CATCH(RenderTarget::MIN_SUPPORTED_COLOR_ATTACHMENTS_COUNT)
}

void* filament_render_target_create_ex(void* engine,
        const filament_rt_attachment_t* color_attachments, uint32_t color_count,
        const filament_rt_attachment_t* depth_attachment,
        uint8_t samples) {
    FFI_TRY
    RenderTarget::Builder builder;
    
    for (uint32_t i = 0; i < color_count; ++i) {
        if (color_attachments[i].texture) {
            builder.texture(static_cast<RenderTarget::AttachmentPoint>(
                                static_cast<int>(RenderTarget::AttachmentPoint::COLOR0) + i),
                            toTexture(color_attachments[i].texture));
            builder.mipLevel(static_cast<RenderTarget::AttachmentPoint>(
                                static_cast<int>(RenderTarget::AttachmentPoint::COLOR0) + i),
                             color_attachments[i].mip_level);
            builder.face(static_cast<RenderTarget::AttachmentPoint>(
                                static_cast<int>(RenderTarget::AttachmentPoint::COLOR0) + i),
                         static_cast<Texture::CubemapFace>(color_attachments[i].face));
            builder.layer(static_cast<RenderTarget::AttachmentPoint>(
                                static_cast<int>(RenderTarget::AttachmentPoint::COLOR0) + i),
                          color_attachments[i].layer);
        }
    }
    
    if (depth_attachment && depth_attachment->texture) {
        builder.texture(RenderTarget::AttachmentPoint::DEPTH, toTexture(depth_attachment->texture));
        builder.mipLevel(RenderTarget::AttachmentPoint::DEPTH, depth_attachment->mip_level);
        builder.face(RenderTarget::AttachmentPoint::DEPTH, static_cast<Texture::CubemapFace>(depth_attachment->face));
        builder.layer(RenderTarget::AttachmentPoint::DEPTH, depth_attachment->layer);
    }
    
    if (samples > 1) {
        builder.samples(samples);
    }
    
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_render_target_create(void* engine, void* color_texture, void* depth_texture) {
    FFI_TRY
    filament_rt_attachment_t color = {color_texture, 0, 0, 0};
    filament_rt_attachment_t depth = {depth_texture, 0, 0, 0};
    return filament_render_target_create_ex(engine, color_texture ? &color : nullptr, color_texture ? 1 : 0, depth_texture ? &depth : nullptr, 1);
    FFI_CATCH(nullptr)
}
void filament_engine_destroy_render_target(void* engine, void* render_target) {
    FFI_TRY toEngine(engine)->destroy(toRenderTarget(render_target)); FFI_CATCH()
}
