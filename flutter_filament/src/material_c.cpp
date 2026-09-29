/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "material_c.h"
#include "callback_bridge_c.h"

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialEnums.h>
#include <filament/MaterialInstance.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/Color.h>
#include <backend/DriverEnums.h>
#include <math/mat4.h>
#include <math/mat3.h>
#include <utils/Panic.h>

#include <cstring>
#include <vector>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace filament::math;

#define FFI_TRY try {
#define FFI_CATCH(return_value)                                                \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
    return return_value;                                                       \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
    return return_value;                                                       \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
    return return_value;                                                       \
  }

#define FFI_CATCH_VOID()                                                       \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
  }

static inline Engine* toEngine(void* p) {
    return reinterpret_cast<Engine*>(p);
}

static inline Material* toMaterial(void* p) {
    return reinterpret_cast<Material*>(p);
}

static inline Texture* toTexture(void* p) {
    return reinterpret_cast<Texture*>(p);
}

/// The material package version this engine build accepts. A compiled
/// `.filamat` whose header carries a different version is rejected at load
/// time, so anything that ships one needs a way to check it without guessing.
uint32_t filament_expected_material_version() {
    return static_cast<uint32_t>(filament::MATERIAL_VERSION);
}

void* filament_material_create(void* engine, const void* data, uint32_t size) {
    FFI_TRY
    if (!engine || !data || size == 0) return nullptr;
    return Material::Builder().package(data, static_cast<size_t>(size)).build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_material_create_ex(
    void* engine,
    const void* package,
    size_t size,
    const FilamentMaterialConstant* constants,
    size_t constant_count,
    uint8_t sh_band_count,
    int32_t shadow_sampling_quality) {
    FFI_TRY
    if (!engine || !package || size == 0) return nullptr;
    Material::Builder builder;
    builder.package(package, size);
    if (constants && constant_count > 0) {
        for (size_t i = 0; i < constant_count; ++i) {
            const auto& c = constants[i];
            if (!c.name) continue;
            if (c.type == 0) {
                builder.constant<int32_t>(c.name, c.value.i);
            } else if (c.type == 1) {
                builder.constant<float>(c.name, c.value.f);
            } else if (c.type == 2) {
                builder.constant<bool>(c.name, c.value.b);
            }
        }
    }
    if (sh_band_count >= 1 && sh_band_count <= 3) {
        builder.sphericalHarmonicsBandCount(sh_band_count);
    }
    if (shadow_sampling_quality >= 0) {
        builder.shadowSamplingQuality(static_cast<Material::Builder::ShadowSamplingQuality>(shadow_sampling_quality));
    }
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_material_create_instance(void* material) {
    FFI_TRY
    if (!material) return nullptr;
    return toMaterial(material)->createInstance();
    FFI_CATCH(nullptr)
}

void* filament_material_create_instance_with_name(void* material, const char* name) {
    FFI_TRY
    if (!material) return nullptr;
    return toMaterial(material)->createInstance(name);
    FFI_CATCH(nullptr)
}

void* filament_material_get_default_instance(void* material) {
    FFI_TRY
    if (!material) return nullptr;
    return toMaterial(material)->getDefaultInstance();
    FFI_CATCH(nullptr)
}

void filament_engine_destroy_material(void* engine, void* material) {
    FFI_TRY
    if (!engine || !material) return;
    toEngine(engine)->destroy(toMaterial(material));
    FFI_CATCH_VOID()
}

void filament_material_compile(void* material, int32_t priority, uint64_t variant_filter, uint64_t request_id) {
    FFI_TRY
    if (!material) {
        fireCallback(request_id, 1 /* KIND_MATERIAL_COMPILE */, -1, nullptr, 0);
        return;
    }
    toMaterial(material)->compile(
        static_cast<Material::CompilerPriorityQueue>(priority),
        static_cast<UserVariantFilterMask>(variant_filter),
        nullptr,
        [request_id](Material* m) {
            fireCallback(request_id, 1 /* KIND_MATERIAL_COMPILE */, 0, nullptr, 0);
        }
    );
    FFI_CATCH_VOID()
}

size_t filament_material_get_parameter_count(void* material) {
    FFI_TRY
    if (!material) return 0;
    return toMaterial(material)->getParameterCount();
    FFI_CATCH(0)
}

size_t filament_material_get_parameters(void* material, FilamentParameterInfo* out, size_t capacity) {
    FFI_TRY
    if (!material || !out || capacity == 0) return 0;
    auto* mat = toMaterial(material);
    size_t count = mat->getParameterCount();
    if (count > capacity) {
        count = capacity;
    }
    std::vector<Material::ParameterInfo> nativeParams(count);
    size_t retrieved = mat->getParameters(nativeParams.data(), count);
    for (size_t i = 0; i < retrieved; ++i) {
        const auto& np = nativeParams[i];
        out[i].name = np.name;
        out[i].is_sampler = np.isSampler;
        out[i].is_subpass = np.isSubpass;
        if (np.isSampler) {
            out[i].sampler_type = static_cast<int32_t>(np.samplerType);
            out[i].uniform_type = 0;
            out[i].subpass_type = 0;
        } else if (np.isSubpass) {
            out[i].subpass_type = static_cast<int32_t>(np.subpassType);
            out[i].uniform_type = 0;
            out[i].sampler_type = 0;
        } else {
            out[i].uniform_type = static_cast<int32_t>(np.type);
            out[i].sampler_type = 0;
            out[i].subpass_type = 0;
        }
        out[i].count = np.count;
        out[i].precision = static_cast<int32_t>(np.precision);
    }
    return retrieved;
    FFI_CATCH(0)
}

bool filament_material_has_parameter(void* material, const char* name) {
    FFI_TRY
    if (!material || !name) return false;
    return toMaterial(material)->hasParameter(name);
    FFI_CATCH(false)
}

bool filament_material_is_sampler(void* material, const char* name) {
    FFI_TRY
    if (!material || !name) return false;
    return toMaterial(material)->isSampler(name);
    FFI_CATCH(false)
}

const char* filament_material_get_parameter_transform_name(void* material, const char* name) {
    FFI_TRY
    if (!material || !name) return nullptr;
    return toMaterial(material)->getParameterTransformName(name);
    FFI_CATCH(nullptr)
}

// Default parameters
void filament_material_set_default_parameter_bool(void* material, const char* name, bool value) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, value);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_int(void* material, const char* name, int32_t value) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, value);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_float(void* material, const char* name, float value) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, value);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_float2(void* material, const char* name, float x, float y) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, float2{x, y});
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_float3(void* material, const char* name, float x, float y, float z) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, float3{x, y, z});
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_float4(void* material, const char* name, float x, float y, float z, float w) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, float4{x, y, z, w});
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_mat3(void* material, const char* name, const float* m) {
    FFI_TRY
    if (!material || !name || !m) return;
    mat3f matrix;
    std::memcpy(&matrix, m, sizeof(mat3f));
    toMaterial(material)->setDefaultParameter(name, matrix);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_mat4(void* material, const char* name, const float* m) {
    FFI_TRY
    if (!material || !name || !m) return;
    mat4f matrix;
    std::memcpy(&matrix, m, sizeof(mat4f));
    toMaterial(material)->setDefaultParameter(name, matrix);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_texture(void* material, const char* name, void* texture, uint32_t sampler_params_packed) {
    FFI_TRY
    if (!material || !name || !texture) return;
    backend::SamplerParams params;
    static_assert(sizeof(backend::SamplerParams) == 4, "SamplerParams must be 4 bytes");
    std::memcpy(&params, &sampler_params_packed, 4);
    TextureSampler sampler(params);
    toMaterial(material)->setDefaultParameter(name, toTexture(texture), sampler);
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_rgb(void* material, const char* name, int32_t rgb_type, float r, float g, float b) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, static_cast<RgbType>(rgb_type), float3{r, g, b});
    FFI_CATCH_VOID()
}

void filament_material_set_default_parameter_rgba(void* material, const char* name, int32_t rgba_type, float r, float g, float b, float a) {
    FFI_TRY
    if (!material || !name) return;
    toMaterial(material)->setDefaultParameter(name, static_cast<RgbaType>(rgba_type), float4{r, g, b, a});
    FFI_CATCH_VOID()
}

// Introspection getters
int32_t filament_material_get_shading(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getShading());
    FFI_CATCH(0)
}

int32_t filament_material_get_interpolation(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getInterpolation());
    FFI_CATCH(0)
}

int32_t filament_material_get_blending_mode(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getBlendingMode());
    FFI_CATCH(0)
}

int32_t filament_material_get_vertex_domain(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getVertexDomain());
    FFI_CATCH(0)
}

int32_t filament_material_get_material_domain(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getMaterialDomain());
    FFI_CATCH(0)
}

int32_t filament_material_get_culling_mode(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getCullingMode());
    FFI_CATCH(0)
}

int32_t filament_material_get_transparency_mode(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getTransparencyMode());
    FFI_CATCH(0)
}

bool filament_material_is_color_write_enabled(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->isColorWriteEnabled();
    FFI_CATCH(false)
}

bool filament_material_is_depth_write_enabled(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->isDepthWriteEnabled();
    FFI_CATCH(false)
}

bool filament_material_is_depth_culling_enabled(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->isDepthCullingEnabled();
    FFI_CATCH(false)
}

bool filament_material_is_double_sided(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->isDoubleSided();
    FFI_CATCH(false)
}

bool filament_material_is_alpha_to_coverage_enabled(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->isAlphaToCoverageEnabled();
    FFI_CATCH(false)
}

float filament_material_get_mask_threshold(void* material) {
    FFI_TRY
    if (!material) return 0.0f;
    return toMaterial(material)->getMaskThreshold();
    FFI_CATCH(0.0f)
}

bool filament_material_has_shadow_multiplier(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->hasShadowMultiplier();
    FFI_CATCH(false)
}

bool filament_material_has_specular_anti_aliasing(void* material) {
    FFI_TRY
    if (!material) return false;
    return toMaterial(material)->hasSpecularAntiAliasing();
    FFI_CATCH(false)
}

float filament_material_get_specular_anti_aliasing_variance(void* material) {
    FFI_TRY
    if (!material) return 0.0f;
    return toMaterial(material)->getSpecularAntiAliasingVariance();
    FFI_CATCH(0.0f)
}

float filament_material_get_specular_anti_aliasing_threshold(void* material) {
    FFI_TRY
    if (!material) return 0.0f;
    return toMaterial(material)->getSpecularAntiAliasingThreshold();
    FFI_CATCH(0.0f)
}

uint32_t filament_material_get_required_attributes(void* material) {
    FFI_TRY
    if (!material) return 0;
    return toMaterial(material)->getRequiredAttributes().getValue();
    FFI_CATCH(0)
}

int32_t filament_material_get_refraction_mode(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getRefractionMode());
    FFI_CATCH(0)
}

int32_t filament_material_get_refraction_type(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getRefractionType());
    FFI_CATCH(0)
}

int32_t filament_material_get_reflection_mode(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getReflectionMode());
    FFI_CATCH(0)
}

int32_t filament_material_get_feature_level(void* material) {
    FFI_TRY
    if (!material) return 0;
    return static_cast<int32_t>(toMaterial(material)->getFeatureLevel());
    FFI_CATCH(0)
}

const char* filament_material_get_name(void* material) {
    FFI_TRY
    if (!material) return "";
    return toMaterial(material)->getName();
    FFI_CATCH("")
}
