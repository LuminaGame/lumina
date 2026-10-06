/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "lighting_c.h"

#include <filament/Engine.h>
#include <filament/LightManager.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/IndirectLight.h>
#include <utils/Entity.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>
#include <mutex>
#include <unordered_map>

using namespace filament;
using namespace utils;

namespace {
// The cubemap texture a KTX-built IndirectLight or Skybox was given
// here belongs to that object (the caller never sees it), keyed by engine and
// object so a destroyed engine's entries cannot match a later object at the
// same address.
struct OwnedKey {
    const void* engine;
    const void* object;
    bool operator==(const OwnedKey& o) const { return engine == o.engine && object == o.object; }
};
struct OwnedKeyHash {
    size_t operator()(const OwnedKey& k) const {
        return std::hash<const void*>()(k.engine) * 31u ^ std::hash<const void*>()(k.object);
    }
};
std::mutex gOwnedTexturesMutex;
std::unordered_map<OwnedKey, Texture*, OwnedKeyHash> gOwnedTextures;

void rememberOwnedTexture(Engine* engine, const void* object, Texture* texture) {
    std::lock_guard<std::mutex> lock(gOwnedTexturesMutex);
    gOwnedTextures[OwnedKey{engine, object}] = texture;
}

Texture* takeOwnedTexture(Engine* engine, const void* object) {
    std::lock_guard<std::mutex> lock(gOwnedTexturesMutex);
    auto it = gOwnedTextures.find(OwnedKey{engine, object});
    if (it == gOwnedTextures.end()) return nullptr;
    Texture* texture = it->second;
    gOwnedTextures.erase(it);
    return texture;
}
}  // namespace

void flutter_filament_forget_owned_textures(void* engine) {
    std::lock_guard<std::mutex> lock(gOwnedTexturesMutex);
    for (auto it = gOwnedTextures.begin(); it != gOwnedTextures.end();) {
        it = it->first.engine == engine ? gOwnedTextures.erase(it) : std::next(it);
    }
}

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Lighting C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Lighting C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Lighting C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline Skybox* toSkybox(void* p) { return reinterpret_cast<Skybox*>(p); }
static inline Texture* toTexture(void* p) { return reinterpret_cast<Texture*>(p); }
static inline IndirectLight* toIndirectLight(void* p) { return reinterpret_cast<IndirectLight*>(p); }
static inline Entity toEntity(uint32_t e) { return Entity::import(static_cast<int>(e)); }
static inline LightManager::Builder* toLightBuilder(void* p) { return reinterpret_cast<LightManager::Builder*>(p); }

void filament_light_create(
    void* engine, uint32_t entity, int type,
    float color_r, float color_g, float color_b, float intensity,
    float dir_x, float dir_y, float dir_z, bool cast_shadows) {
    FFI_TRY
    LightManager::Builder(static_cast<LightManager::Type>(type))
        .color({color_r, color_g, color_b})
        .intensity(intensity)
        .direction({dir_x, dir_y, dir_z})
        .castShadows(cast_shadows)
        .build(*toEngine(engine), toEntity(entity));
    FFI_CATCH()
}

void filament_light_destroy(void* engine, uint32_t entity) {
    FFI_TRY
    toEngine(engine)->getLightManager().destroy(toEntity(entity));
    FFI_CATCH()
}

void* filament_light_builder_create(int type) {
    FFI_TRY
    return new LightManager::Builder(static_cast<LightManager::Type>(type));
    FFI_CATCH(nullptr)
}

void filament_light_builder_position(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->position({x, y, z});
    FFI_CATCH()
}

void filament_light_builder_direction(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->direction({x, y, z});
    FFI_CATCH()
}

void filament_light_builder_color(void* builder, float r, float g, float b) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->color({r, g, b});
    FFI_CATCH()
}

void filament_light_builder_intensity(void* builder, float intensity) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->intensity(intensity);
    FFI_CATCH()
}

void filament_light_builder_intensity_candela(void* builder, float intensity) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->intensityCandela(intensity);
    FFI_CATCH()
}

void filament_light_builder_intensity_watts(void* builder, float watts, float efficiency) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->intensity(watts, efficiency);
    FFI_CATCH()
}

void filament_light_builder_falloff(void* builder, float radius) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->falloff(radius);
    FFI_CATCH()
}

void filament_light_builder_spot_light_cone(void* builder, float inner, float outer) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->spotLightCone(inner, outer);
    FFI_CATCH()
}

void filament_light_builder_sun_angular_radius(void* builder, float radius) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->sunAngularRadius(radius);
    FFI_CATCH()
}

void filament_light_builder_sun_halo_size(void* builder, float size) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->sunHaloSize(size);
    FFI_CATCH()
}

void filament_light_builder_sun_halo_falloff(void* builder, float falloff) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->sunHaloFalloff(falloff);
    FFI_CATCH()
}

void filament_light_builder_cast_shadows(void* builder, bool enabled) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->castShadows(enabled);
    FFI_CATCH()
}

void filament_light_builder_cast_light(void* builder, bool enabled) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->castLight(enabled);
    FFI_CATCH()
}

void filament_light_builder_light_channel(void* builder, unsigned int channel, bool enable) {
    FFI_TRY
    if (builder) toLightBuilder(builder)->lightChannel(channel, enable);
    FFI_CATCH()
}

int32_t filament_light_builder_build(void* builder, void* engine, uint32_t entity) {
    FFI_TRY
    if (!builder || !engine) return -1;
    auto* b = toLightBuilder(builder);
    auto res = b->build(*toEngine(engine), toEntity(entity));
    delete b;
    return static_cast<int32_t>(res);
    FFI_CATCH(-1)
}

void filament_light_builder_destroy(void* builder) {
    FFI_TRY
    if (builder) delete toLightBuilder(builder);
    FFI_CATCH()
}

void filament_light_set_color(void* engine, uint32_t entity, float r, float g, float b) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setColor(inst, {r, g, b});
    FFI_CATCH()
}

void filament_light_get_color(void* engine, uint32_t entity, float* out_rgb) {
    FFI_TRY
    if (!engine || !out_rgb) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) {
        auto color = lm.getColor(inst);
        out_rgb[0] = color.r;
        out_rgb[1] = color.g;
        out_rgb[2] = color.b;
    }
    FFI_CATCH()
}

void filament_light_set_intensity(void* engine, uint32_t entity, float intensity) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setIntensity(inst, intensity);
    FFI_CATCH()
}

void filament_light_set_intensity_candela(void* engine, uint32_t entity, float intensity) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setIntensityCandela(inst, intensity);
    FFI_CATCH()
}

void filament_light_set_intensity_watts(void* engine, uint32_t entity, float watts, float efficiency) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setIntensity(inst, watts, efficiency);
    FFI_CATCH()
}

float filament_light_get_intensity(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0.0f;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.getIntensity(inst);
    return 0.0f;
    FFI_CATCH(0.0f)
}

void filament_light_set_direction(void* engine, uint32_t entity, float x, float y, float z) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setDirection(inst, {x, y, z});
    FFI_CATCH()
}

void filament_light_get_direction(void* engine, uint32_t entity, float* out_xyz) {
    FFI_TRY
    if (!engine || !out_xyz) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) {
        auto dir = lm.getDirection(inst);
        out_xyz[0] = dir.x;
        out_xyz[1] = dir.y;
        out_xyz[2] = dir.z;
    }
    FFI_CATCH()
}

void filament_light_set_position(void* engine, uint32_t entity, float x, float y, float z) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setPosition(inst, {x, y, z});
    FFI_CATCH()
}

void filament_light_get_position(void* engine, uint32_t entity, float* out_xyz) {
    FFI_TRY
    if (!engine || !out_xyz) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) {
        auto pos = lm.getPosition(inst);
        out_xyz[0] = pos.x;
        out_xyz[1] = pos.y;
        out_xyz[2] = pos.z;
    }
    FFI_CATCH()
}

void filament_light_set_falloff(void* engine, uint32_t entity, float radius) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setFalloff(inst, radius);
    FFI_CATCH()
}

float filament_light_get_falloff(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0.0f;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.getFalloff(inst);
    return 0.0f;
    FFI_CATCH(0.0f)
}

void filament_light_set_spot_light_cone(void* engine, uint32_t entity, float inner, float outer) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setSpotLightCone(inst, inner, outer);
    FFI_CATCH()
}

float filament_light_get_spot_light_inner_cone(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0.0f;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.getSpotLightInnerCone(inst);
    return 0.0f;
    FFI_CATCH(0.0f)
}

float filament_light_get_spot_light_outer_cone(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0.0f;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.getSpotLightOuterCone(inst);
    return 0.0f;
    FFI_CATCH(0.0f)
}

void filament_light_set_shadow_caster(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setShadowCaster(inst, enabled);
    FFI_CATCH()
}

bool filament_light_is_shadow_caster(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.isShadowCaster(inst);
    return false;
    FFI_CATCH(false)
}

void filament_light_set_light_channel(void* engine, uint32_t entity, unsigned int channel, bool enable) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) lm.setLightChannel(inst, channel, enable);
    FFI_CATCH()
}

bool filament_light_get_light_channel(void* engine, uint32_t entity, unsigned int channel) {
    FFI_TRY
    if (!engine) return false;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) return lm.getLightChannel(inst, channel);
    return false;
    FFI_CATCH(false)
}

bool filament_light_has_component(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    return toEngine(engine)->getLightManager().hasComponent(toEntity(entity));
    FFI_CATCH(false)
}

uint32_t filament_light_get_instance(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0;
    return toEngine(engine)->getLightManager().getInstance(toEntity(entity)).asValue();
    FFI_CATCH(0)
}

int filament_light_get_type(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return -1;
    auto& lm = toEngine(engine)->getLightManager();
    auto e = toEntity(entity);
    if (!lm.hasComponent(e)) return -1;
    auto inst = lm.getInstance(e);
    if (!inst) return -1;
    return static_cast<int>(lm.getType(inst));
    FFI_CATCH(-1)
}

uint32_t filament_light_get_component_count(void* engine) {
    FFI_TRY
    if (!engine) return 0;
    return static_cast<uint32_t>(toEngine(engine)->getLightManager().getComponentCount());
    FFI_CATCH(0)
}

void filament_light_get_entities(void* engine, uint32_t* out_entities, uint32_t capacity) {
    FFI_TRY
    if (!engine || !out_entities || capacity == 0) return;
    auto& lm = toEngine(engine)->getLightManager();
    size_t count = lm.getComponentCount();
    size_t to_copy = std::min(count, static_cast<size_t>(capacity));
    auto* entities = lm.getEntities();
    for (size_t i = 0; i < to_copy; i++) {
        out_entities[i] = static_cast<uint32_t>(entities[i].getId());
    }
    FFI_CATCH()
}

static inline void toFilamentShadowOptions(const LightManager::ShadowOptions& src, FilamentShadowOptions* dst) {
    dst->map_size = src.mapSize;
    dst->shadow_cascades = src.shadowCascades;
    dst->cascade_split_positions[0] = src.cascadeSplitPositions[0];
    dst->cascade_split_positions[1] = src.cascadeSplitPositions[1];
    dst->cascade_split_positions[2] = src.cascadeSplitPositions[2];
    dst->constant_bias = src.constantBias;
    dst->normal_bias = src.normalBias;
    dst->shadow_far = src.shadowFar;
    dst->shadow_near_hint = src.shadowNearHint;
    dst->shadow_far_hint = src.shadowFarHint;
    dst->stable = src.stable;
    dst->lispsm = src.lispsm;
    dst->polygon_offset_constant = src.polygonOffsetConstant;
    dst->polygon_offset_slope = src.polygonOffsetSlope;
    dst->screen_space_contact_shadows = src.screenSpaceContactShadows;
    dst->step_count = src.stepCount;
    dst->max_shadow_distance = src.maxShadowDistance;
    dst->elvsm = src.vsm.elvsm;
    dst->blur_width = src.vsm.blurWidth;
    dst->shadow_bulb_radius = src.shadowBulbRadius;
    dst->transform[0] = src.transform.x;
    dst->transform[1] = src.transform.y;
    dst->transform[2] = src.transform.z;
    dst->transform[3] = src.transform.w;
    dst->penumbra_scale = src.penumbraScale;
    dst->penumbra_ratio_scale = src.penumbraRatioScale;
    dst->max_penumbra_ratio = src.maxPenumbraRatio;
    dst->ray_traced = src.rayTraced;
}

static inline void fromFilamentShadowOptions(const FilamentShadowOptions* src, LightManager::ShadowOptions& dst) {
    dst.mapSize = src->map_size;
    dst.shadowCascades = src->shadow_cascades;
    dst.cascadeSplitPositions[0] = src->cascade_split_positions[0];
    dst.cascadeSplitPositions[1] = src->cascade_split_positions[1];
    dst.cascadeSplitPositions[2] = src->cascade_split_positions[2];
    dst.constantBias = src->constant_bias;
    dst.normalBias = src->normal_bias;
    dst.shadowFar = src->shadow_far;
    dst.shadowNearHint = src->shadow_near_hint;
    dst.shadowFarHint = src->shadow_far_hint;
    dst.stable = src->stable;
    dst.lispsm = src->lispsm;
    dst.polygonOffsetConstant = src->polygon_offset_constant;
    dst.polygonOffsetSlope = src->polygon_offset_slope;
    dst.screenSpaceContactShadows = src->screen_space_contact_shadows;
    dst.stepCount = src->step_count;
    dst.maxShadowDistance = src->max_shadow_distance;
    dst.vsm.elvsm = src->elvsm;
    dst.vsm.blurWidth = src->blur_width;
    dst.shadowBulbRadius = src->shadow_bulb_radius;
    dst.transform.x = src->transform[0];
    dst.transform.y = src->transform[1];
    dst.transform.z = src->transform[2];
    dst.transform.w = src->transform[3];
    dst.penumbraScale = src->penumbra_scale;
    dst.penumbraRatioScale = src->penumbra_ratio_scale;
    dst.maxPenumbraRatio = src->max_penumbra_ratio;
    dst.rayTraced = src->ray_traced;
}

size_t filament_sizeof_shadow_options(void) {
    return sizeof(FilamentShadowOptions);
}

void filament_light_builder_shadow_options(void* builder, const FilamentShadowOptions* options) {
    FFI_TRY
    if (!builder || !options) return;
    LightManager::ShadowOptions opt;
    fromFilamentShadowOptions(options, opt);
    toLightBuilder(builder)->shadowOptions(opt);
    FFI_CATCH()
}

void filament_light_set_shadow_options(void* engine, uint32_t entity, const FilamentShadowOptions* options) {
    FFI_TRY
    if (!engine || !options) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) {
        LightManager::ShadowOptions opt;
        fromFilamentShadowOptions(options, opt);
        lm.setShadowOptions(inst, opt);
    }
    FFI_CATCH()
}

void filament_light_get_shadow_options(void* engine, uint32_t entity, FilamentShadowOptions* out_options) {
    FFI_TRY
    if (!engine || !out_options) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto inst = lm.getInstance(toEntity(entity));
    if (inst) {
        const auto& opt = lm.getShadowOptions(inst);
        toFilamentShadowOptions(opt, out_options);
    }
    FFI_CATCH()
}

void filament_shadow_cascades_compute_uniform_splits(float* out_splits, uint8_t cascades) {
    FFI_TRY
    if (!out_splits || cascades <= 1) return;
    LightManager::ShadowCascades::computeUniformSplits(out_splits, cascades);
    FFI_CATCH()
}

void filament_shadow_cascades_compute_log_splits(float* out_splits, uint8_t cascades, float near_plane, float far_plane) {
    FFI_TRY
    if (!out_splits || cascades <= 1) return;
    LightManager::ShadowCascades::computeLogSplits(out_splits, cascades, near_plane, far_plane);
    FFI_CATCH()
}

void filament_shadow_cascades_compute_practical_splits(float* out_splits, uint8_t cascades, float near_plane, float far_plane, float lambda) {
    FFI_TRY
    if (!out_splits || cascades <= 1) return;
    LightManager::ShadowCascades::computePracticalSplits(out_splits, cascades, near_plane, far_plane, lambda);
    FFI_CATCH()
}

void* filament_skybox_create_color(void* engine, float r, float g, float b, float a) {
    FFI_TRY
    return Skybox::Builder().color({r, g, b, a}).build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_skybox_create_ex(void* engine, void* environment_cubemap, float color_r, float color_g, float color_b, float color_a, bool show_sun, float intensity, uint8_t priority) {
    FFI_TRY
    if (!engine) return nullptr;
    Skybox::Builder builder;
    if (environment_cubemap) {
        builder.environment(toTexture(environment_cubemap));
    } else {
        builder.color({color_r, color_g, color_b, color_a});
    }
    builder.showSun(show_sun);
    builder.intensity(intensity);
    builder.priority(priority);
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_skybox_set_color(void* skybox, float r, float g, float b, float a) {
    FFI_TRY
    if (skybox) {
        toSkybox(skybox)->setColor({r, g, b, a});
    }
    FFI_CATCH()
}

void filament_skybox_set_layer_mask(void* skybox, uint8_t select, uint8_t values) {
    FFI_TRY
    if (skybox) {
        toSkybox(skybox)->setLayerMask(select, values);
    }
    FFI_CATCH()
}

uint8_t filament_skybox_get_layer_mask(void* skybox) {
    FFI_TRY
    if (skybox) {
        return toSkybox(skybox)->getLayerMask();
    }
    return 0;
    FFI_CATCH(0)
}

float filament_skybox_get_intensity(void* skybox) {
    FFI_TRY
    if (skybox) {
        return toSkybox(skybox)->getIntensity();
    }
    return 0.0f;
    FFI_CATCH(0.0f)
}

void* filament_skybox_get_texture(void* skybox) {
    FFI_TRY
    if (skybox) {
        return const_cast<Texture*>(toSkybox(skybox)->getTexture());
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

void filament_engine_destroy_skybox(void* engine, void* skybox) {
    FFI_TRY
    Engine* e = toEngine(engine);
    e->destroy(toSkybox(skybox));
    if (Texture* owned = takeOwnedTexture(e, skybox)) e->destroy(owned);
    FFI_CATCH()
}

#include <ktxreader/Ktx1Reader.h>
#include <filament/Scene.h>
#include <math/mat3.h>
#include <math/vec3.h>

void* filament_skybox_create_from_ktx(void* engine_ptr, const void* ktx_data, uint32_t size, bool show_sun) {
    FFI_TRY
    Engine* engine = toEngine(engine_ptr);
    image::Ktx1Bundle* bundle = new image::Ktx1Bundle(reinterpret_cast<const uint8_t*>(ktx_data), size);
    Texture* skyTex = ktxreader::Ktx1Reader::createTexture(engine, bundle, false);
    if (!skyTex) return nullptr;

    Skybox* skybox = Skybox::Builder()
        .environment(skyTex)
        .showSun(show_sun)
        .build(*engine);
    if (skybox) {
        rememberOwnedTexture(engine, skybox, skyTex);
    } else {
        engine->destroy(skyTex);
    }
    return skybox;
    FFI_CATCH(nullptr)
}

void* filament_indirect_light_create(void* engine, void* cubemap_texture, float intensity) {
    FFI_TRY
    return IndirectLight::Builder().reflections(toTexture(cubemap_texture)).intensity(intensity).build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_indirect_light_create_from_ktx(void* engine_ptr, const void* ktx_data, uint32_t size, float intensity) {
    FFI_TRY
    Engine* engine = toEngine(engine_ptr);
    image::Ktx1Bundle* bundle = new image::Ktx1Bundle(reinterpret_cast<const uint8_t*>(ktx_data), size);
    Texture* iblTex = ktxreader::Ktx1Reader::createTexture(engine, bundle, false);
    if (!iblTex) return nullptr;

    math::float3 bands[9];
    IndirectLight* ibl = nullptr;
    if (bundle->getSphericalHarmonics(bands)) {
        ibl = IndirectLight::Builder()
            .reflections(iblTex)
            .irradiance(3, bands)
            .intensity(intensity)
            .rotation(math::mat3f::rotation(0.5f, math::float3{ 0, 1, 0 }))
            .build(*engine);
    } else {
        ibl = IndirectLight::Builder()
            .reflections(iblTex)
            .intensity(intensity)
            .rotation(math::mat3f::rotation(0.5f, math::float3{ 0, 1, 0 }))
            .build(*engine);
    }
    if (ibl) {
        rememberOwnedTexture(engine, ibl, iblTex);
    } else {
        engine->destroy(iblTex);
    }
    return ibl;
    FFI_CATCH(nullptr)
}

void* filament_indirect_light_create_ex(void* engine, void* reflections_cubemap, uint8_t irradiance_bands, const float* irradiance_sh, uint8_t radiance_bands, const float* radiance_sh, float intensity, const float* rotation) {
    FFI_TRY
    if (!engine) return nullptr;
    IndirectLight::Builder builder;
    if (reflections_cubemap) {
        builder.reflections(toTexture(reflections_cubemap));
    }
    if (irradiance_sh && irradiance_bands >= 1 && irradiance_bands <= 3) {
        builder.irradiance(irradiance_bands, reinterpret_cast<const math::float3*>(irradiance_sh));
    }
    if (radiance_sh && radiance_bands >= 1 && radiance_bands <= 3) {
        builder.radiance(radiance_bands, reinterpret_cast<const math::float3*>(radiance_sh));
    }
    builder.intensity(intensity);
    if (rotation) {
        builder.rotation(*reinterpret_cast<const math::mat3f*>(rotation));
    }
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_indirect_light_set_intensity(void* indirect_light, float intensity) {
    FFI_TRY
    if (indirect_light) {
        toIndirectLight(indirect_light)->setIntensity(intensity);
    }
    FFI_CATCH()
}

float filament_indirect_light_get_intensity(void* indirect_light) {
    FFI_TRY
    if (indirect_light) {
        return toIndirectLight(indirect_light)->getIntensity();
    }
    return 0.0f;
    FFI_CATCH(0.0f)
}

void filament_indirect_light_set_rotation(void* ibl, const float* rotation9) {
    FFI_TRY
    if (ibl && rotation9) {
        toIndirectLight(ibl)->setRotation(*reinterpret_cast<const math::mat3f*>(rotation9));
    }
    FFI_CATCH()
}

void filament_indirect_light_get_rotation(void* ibl, float* out9) {
    FFI_TRY
    if (ibl && out9) {
        const math::mat3f& rot = toIndirectLight(ibl)->getRotation();
        memcpy(out9, &rot, sizeof(float) * 9);
    }
    FFI_CATCH()
}

void* filament_indirect_light_get_reflections_texture(void* ibl) {
    FFI_TRY
    if (ibl) {
        return const_cast<Texture*>(toIndirectLight(ibl)->getReflectionsTexture());
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

void* filament_indirect_light_get_irradiance_texture(void* ibl) {
    FFI_TRY
    if (ibl) {
        return const_cast<Texture*>(toIndirectLight(ibl)->getIrradianceTexture());
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

void filament_indirect_light_get_direction_estimate(void* ibl, float* out_dir3) {
    FFI_TRY
    if (ibl && out_dir3) {
        math::float3 dir = toIndirectLight(ibl)->getDirectionEstimate();
        out_dir3[0] = dir.x;
        out_dir3[1] = dir.y;
        out_dir3[2] = dir.z;
    }
    FFI_CATCH()
}

void filament_indirect_light_get_color_estimate(void* ibl, float dir_x, float dir_y, float dir_z, float* out_rgba4) {
    FFI_TRY
    if (ibl && out_rgba4) {
        math::float4 col = toIndirectLight(ibl)->getColorEstimate(math::float3{dir_x, dir_y, dir_z});
        out_rgba4[0] = col.r;
        out_rgba4[1] = col.g;
        out_rgba4[2] = col.b;
        out_rgba4[3] = col.a;
    }
    FFI_CATCH()
}

void filament_indirect_light_direction_estimate_static(const float* sh27, float* out_dir3) {
    FFI_TRY
    if (sh27 && out_dir3) {
        math::float3 dir = IndirectLight::getDirectionEstimate(reinterpret_cast<const math::float3*>(sh27));
        out_dir3[0] = dir.x;
        out_dir3[1] = dir.y;
        out_dir3[2] = dir.z;
    }
    FFI_CATCH()
}

void filament_indirect_light_color_estimate_static(const float* sh27, float dir_x, float dir_y, float dir_z, float* out_rgba4) {
    FFI_TRY
    if (sh27 && out_rgba4) {
        math::float4 col = IndirectLight::getColorEstimate(reinterpret_cast<const math::float3*>(sh27), math::float3{dir_x, dir_y, dir_z});
        out_rgba4[0] = col.r;
        out_rgba4[1] = col.g;
        out_rgba4[2] = col.b;
        out_rgba4[3] = col.a;
    }
    FFI_CATCH()
}

void filament_engine_destroy_indirect_light(void* engine, void* ibl) {
    FFI_TRY
    Engine* e = toEngine(engine);
    e->destroy(toIndirectLight(ibl));
    if (Texture* owned = takeOwnedTexture(e, ibl)) e->destroy(owned);
    FFI_CATCH()
}
