/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "material_instance_c.h"

#include <filament/MaterialInstance.h>
#include <filament/Material.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/Color.h>
#include <math/mat4.h>
#include <math/mat3.h>
#include <utils/Panic.h>
#include <cstring>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace filament::math;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[MaterialInstance C++ Panic]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[MaterialInstance C++ Exception]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[MaterialInstance C++ Unknown Exception]\n"); \
    return return_value; \
}

static inline MaterialInstance* toMaterialInstance(void* p) { return reinterpret_cast<MaterialInstance*>(p); }
static inline Texture* toTexture(void* p) { return reinterpret_cast<Texture*>(p); }

void* filament_material_instance_duplicate(void* mi, const char* name) {
    FFI_TRY
    MaterialInstance* instance = toMaterialInstance(mi);
    if (!instance) return nullptr;
    return MaterialInstance::duplicate(instance, name);
    FFI_CATCH(nullptr)
}

void filament_material_instance_set_bool(void* mi, const char* name, bool value) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, value);
    FFI_CATCH()
}

void filament_material_instance_set_bool2(void* mi, const char* name, const bool* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, bool2{v[0], v[1]});
    FFI_CATCH()
}

void filament_material_instance_set_bool3(void* mi, const char* name, const bool* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, bool3{v[0], v[1], v[2]});
    FFI_CATCH()
}

void filament_material_instance_set_bool4(void* mi, const char* name, const bool* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, bool4{v[0], v[1], v[2], v[3]});
    FFI_CATCH()
}

void filament_material_instance_set_int(void* mi, const char* name, int32_t value) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, value);
    FFI_CATCH()
}

void filament_material_instance_set_int2(void* mi, const char* name, int32_t x, int32_t y) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, int2{x, y});
    FFI_CATCH()
}

void filament_material_instance_set_int3(void* mi, const char* name, int32_t x, int32_t y, int32_t z) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, int3{x, y, z});
    FFI_CATCH()
}

void filament_material_instance_set_int4(void* mi, const char* name, int32_t x, int32_t y, int32_t z, int32_t w) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, int4{x, y, z, w});
    FFI_CATCH()
}

void filament_material_instance_set_uint(void* mi, const char* name, uint32_t v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, v);
    FFI_CATCH()
}

void filament_material_instance_set_uint2(void* mi, const char* name, const uint32_t* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, uint2{v[0], v[1]});
    FFI_CATCH()
}

void filament_material_instance_set_uint3(void* mi, const char* name, const uint32_t* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, uint3{v[0], v[1], v[2]});
    FFI_CATCH()
}

void filament_material_instance_set_uint4(void* mi, const char* name, const uint32_t* v) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, uint4{v[0], v[1], v[2], v[3]});
    FFI_CATCH()
}

void filament_material_instance_set_float(void* mi, const char* name, float value) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, value);
    FFI_CATCH()
}

void filament_material_instance_set_float2(void* mi, const char* name, float x, float y) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, float2{x, y});
    FFI_CATCH()
}

void filament_material_instance_set_float3(void* mi, const char* name, float x, float y, float z) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, float3{x, y, z});
    FFI_CATCH()
}

void filament_material_instance_set_float4(void* mi, const char* name, float x, float y, float z, float w) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, float4{x, y, z, w});
    FFI_CATCH()
}

void filament_material_instance_set_mat3(void* mi, const char* name, const float* matrix9) {
    FFI_TRY
    mat3f m(
        float3{matrix9[0], matrix9[1], matrix9[2]},
        float3{matrix9[3], matrix9[4], matrix9[5]},
        float3{matrix9[6], matrix9[7], matrix9[8]}
    );
    toMaterialInstance(mi)->setParameter(name, m);
    FFI_CATCH()
}

void filament_material_instance_set_mat4(void* mi, const char* name, const float* matrix16) {
    FFI_TRY
    mat4f m(
        float4{matrix16[0], matrix16[1], matrix16[2], matrix16[3]},
        float4{matrix16[4], matrix16[5], matrix16[6], matrix16[7]},
        float4{matrix16[8], matrix16[9], matrix16[10], matrix16[11]},
        float4{matrix16[12], matrix16[13], matrix16[14], matrix16[15]}
    );
    toMaterialInstance(mi)->setParameter(name, m);
    FFI_CATCH()
}

void filament_material_instance_set_float_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, values, count);
    FFI_CATCH()
}

void filament_material_instance_set_float2_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, reinterpret_cast<const float2*>(values), count);
    FFI_CATCH()
}

void filament_material_instance_set_float3_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, reinterpret_cast<const float3*>(values), count);
    FFI_CATCH()
}

void filament_material_instance_set_float4_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, reinterpret_cast<const float4*>(values), count);
    FFI_CATCH()
}

void filament_material_instance_set_int_array(void* mi, const char* name, const int32_t* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, values, count);
    FFI_CATCH()
}

void filament_material_instance_set_mat3_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, reinterpret_cast<const mat3f*>(values), count);
    FFI_CATCH()
}

void filament_material_instance_set_mat4_array(void* mi, const char* name, const float* values, uint32_t count) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, reinterpret_cast<const mat4f*>(values), count);
    FFI_CATCH()
}

void filament_material_instance_set_rgb(void* mi, const char* name, int32_t rgb_type, float r, float g, float b) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, static_cast<RgbType>(rgb_type), float3{r, g, b});
    FFI_CATCH()
}

void filament_material_instance_set_rgba(void* mi, const char* name, int32_t rgba_type, float r, float g, float b, float a) {
    FFI_TRY
    toMaterialInstance(mi)->setParameter(name, static_cast<RgbaType>(rgba_type), float4{r, g, b, a});
    FFI_CATCH()
}

void filament_material_instance_set_texture(void* mi, const char* name, void* texture) {
    FFI_TRY
    TextureSampler sampler;
    toMaterialInstance(mi)->setParameter(name, toTexture(texture), sampler);
    FFI_CATCH()
}

void filament_material_instance_set_texture_ex(void* mi, const char* name, void* texture, uint32_t sampler_params_packed) {
    FFI_TRY
    if (!mi || !name || !texture) return;
    
    backend::SamplerParams params;
    static_assert(sizeof(backend::SamplerParams) == 4, "SamplerParams must be 4 bytes");
    std::memcpy(&params, &sampler_params_packed, 4);
    TextureSampler sampler(params);

    static_cast<MaterialInstance*>(mi)->setParameter(name, static_cast<Texture*>(texture), sampler);
    FFI_CATCH()
}

void filament_material_instance_set_culling_mode(void* mi, int32_t mode) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setCullingMode(static_cast<backend::CullingMode>(mode));
    FFI_CATCH()
}

void filament_material_instance_set_culling_mode2(void* mi, int32_t color_pass_mode, int32_t shadow_pass_mode) {
    FFI_TRY
    if (!mi) return;
#if FILAMENT_VERSION_MAJOR > 1 || (FILAMENT_VERSION_MAJOR == 1 && FILAMENT_VERSION_MINOR >= 43)
    // Guarding just in case, but Filament has this.
    static_cast<MaterialInstance*>(mi)->setCullingMode(static_cast<backend::CullingMode>(color_pass_mode), static_cast<backend::CullingMode>(shadow_pass_mode));
#else
    static_cast<MaterialInstance*>(mi)->setCullingMode(static_cast<backend::CullingMode>(color_pass_mode));
#endif
    FFI_CATCH()
}

void filament_material_instance_set_double_sided(void* mi, bool double_sided) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setDoubleSided(double_sided);
    FFI_CATCH()
}

void filament_material_instance_set_color_write(void* mi, bool enable) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setColorWrite(enable);
    FFI_CATCH()
}

void filament_material_instance_set_depth_write(void* mi, bool enable) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setDepthWrite(enable);
    FFI_CATCH()
}

void filament_material_instance_set_depth_culling(void* mi, bool enable) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setDepthCulling(enable);
    FFI_CATCH()
}

void filament_material_instance_set_depth_func(void* mi, int32_t func) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setDepthFunc(static_cast<backend::SamplerCompareFunc>(func));
    FFI_CATCH()
}

void filament_material_instance_set_transparency_mode(void* mi, int32_t mode) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setTransparencyMode(static_cast<TransparencyMode>(mode));
    FFI_CATCH()
}

void filament_material_instance_set_mask_threshold(void* mi, float threshold) {
    FFI_TRY
    if (!mi) return;
    auto* inst = static_cast<MaterialInstance*>(mi);
    if (!inst->getMaterial()->hasParameter("_maskThreshold")) return;
    inst->setMaskThreshold(threshold);
    FFI_CATCH()
}

void filament_material_instance_set_polygon_offset(void* mi, float scale, float constant) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setPolygonOffset(scale, constant);
    FFI_CATCH()
}

void filament_material_instance_set_scissor(void* mi, uint32_t left, uint32_t bottom, uint32_t width, uint32_t height) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->setScissor(left, bottom, width, height);
    FFI_CATCH()
}

void filament_material_instance_unset_scissor(void* mi) {
    FFI_TRY
    if (!mi) return;
    static_cast<MaterialInstance*>(mi)->unsetScissor();
    FFI_CATCH()
}

int32_t filament_material_instance_get_culling_mode(void* mi) {
    FFI_TRY
    if (!mi) return 0;
    return static_cast<int32_t>(static_cast<MaterialInstance*>(mi)->getCullingMode());
    FFI_CATCH(0)
}

bool filament_material_instance_is_double_sided(void* mi) {
    FFI_TRY
    if (!mi) return false;
    return static_cast<MaterialInstance*>(mi)->isDoubleSided();
    FFI_CATCH(false)
}

bool filament_material_instance_is_color_write_enabled(void* mi) {
    FFI_TRY
    if (!mi) return false;
    return static_cast<MaterialInstance*>(mi)->isColorWriteEnabled();
    FFI_CATCH(false)
}

bool filament_material_instance_is_depth_write_enabled(void* mi) {
    FFI_TRY
    if (!mi) return false;
    return static_cast<MaterialInstance*>(mi)->isDepthWriteEnabled();
    FFI_CATCH(false)
}

bool filament_material_instance_is_depth_culling_enabled(void* mi) {
    FFI_TRY
    if (!mi) return false;
    return static_cast<MaterialInstance*>(mi)->isDepthCullingEnabled();
    FFI_CATCH(false)
}

int32_t filament_material_instance_get_depth_func(void* mi) {
    FFI_TRY
    if (!mi) return 0;
    return static_cast<int32_t>(static_cast<MaterialInstance*>(mi)->getDepthFunc());
    FFI_CATCH(0)
}

int32_t filament_material_instance_get_transparency_mode(void* mi) {
    FFI_TRY
    if (!mi) return 0;
    return static_cast<int32_t>(static_cast<MaterialInstance*>(mi)->getTransparencyMode());
    FFI_CATCH(0)
}

float filament_material_instance_get_mask_threshold(void* mi) {
    FFI_TRY
    if (!mi) return 0.0f;
    auto* inst = static_cast<MaterialInstance*>(mi);
    if (!inst->getMaterial()->hasParameter("_maskThreshold")) return 0.0f;
    return inst->getMaskThreshold();
    FFI_CATCH(0.0f)
}

// Stencil
void filament_material_instance_set_stencil_write(void* mi, bool enabled) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilWrite(enabled);
    FFI_CATCH()
}

bool filament_material_instance_is_stencil_write_enabled(void* mi) {
    FFI_TRY
    if (!mi) return false;
    return toMaterialInstance(mi)->isStencilWriteEnabled();
    FFI_CATCH(false)
}

void filament_material_instance_set_stencil_compare_function(void* mi, int32_t func, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilCompareFunction(
        static_cast<MaterialInstance::StencilCompareFunc>(func),
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_op_stencil_fail(void* mi, int32_t op, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilOpStencilFail(
        static_cast<MaterialInstance::StencilOperation>(op),
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_op_depth_fail(void* mi, int32_t op, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilOpDepthFail(
        static_cast<MaterialInstance::StencilOperation>(op),
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_op_depth_stencil_pass(void* mi, int32_t op, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilOpDepthStencilPass(
        static_cast<MaterialInstance::StencilOperation>(op),
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_reference_value(void* mi, uint8_t value, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilReferenceValue(
        value,
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_read_mask(void* mi, uint8_t mask, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilReadMask(
        mask,
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

void filament_material_instance_set_stencil_write_mask(void* mi, uint8_t mask, int32_t face) {
    FFI_TRY
    if (!mi) return;
    toMaterialInstance(mi)->setStencilWriteMask(
        mask,
        static_cast<MaterialInstance::StencilFace>(face)
    );
    FFI_CATCH()
}

// Constants
void filament_material_instance_set_constant_int(void* mi, const char* name, int32_t v) {
    FFI_TRY
    if (!mi || !name) return;
    toMaterialInstance(mi)->setConstant<int32_t>(name, v);
    FFI_CATCH()
}

void filament_material_instance_set_constant_float(void* mi, const char* name, float v) {
    FFI_TRY
    if (!mi || !name) return;
    toMaterialInstance(mi)->setConstant<float>(name, v);
    FFI_CATCH()
}

void filament_material_instance_set_constant_bool(void* mi, const char* name, bool v) {
    FFI_TRY
    if (!mi || !name) return;
    toMaterialInstance(mi)->setConstant<bool>(name, v);
    FFI_CATCH()
}

// Parameter Read-back
float filament_material_instance_get_parameter_float(void* mi, const char* name) {
    FFI_TRY
    if (!mi || !name) return 0.0f;
    return toMaterialInstance(mi)->getParameter<float>(name);
    FFI_CATCH(0.0f)
}

void filament_material_instance_get_parameter_float2(void* mi, const char* name, float* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<float2>(name);
    out[0] = val.x; out[1] = val.y;
    FFI_CATCH()
}

void filament_material_instance_get_parameter_float3(void* mi, const char* name, float* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<float3>(name);
    out[0] = val.x; out[1] = val.y; out[2] = val.z;
    FFI_CATCH()
}

void filament_material_instance_get_parameter_float4(void* mi, const char* name, float* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<float4>(name);
    out[0] = val.x; out[1] = val.y; out[2] = val.z; out[3] = val.w;
    FFI_CATCH()
}

int32_t filament_material_instance_get_parameter_int(void* mi, const char* name) {
    FFI_TRY
    if (!mi || !name) return 0;
    return toMaterialInstance(mi)->getParameter<int32_t>(name);
    FFI_CATCH(0)
}

void filament_material_instance_get_parameter_int2(void* mi, const char* name, int32_t* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<int2>(name);
    out[0] = val.x; out[1] = val.y;
    FFI_CATCH()
}

void filament_material_instance_get_parameter_int3(void* mi, const char* name, int32_t* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<int3>(name);
    out[0] = val.x; out[1] = val.y; out[2] = val.z;
    FFI_CATCH()
}

void filament_material_instance_get_parameter_int4(void* mi, const char* name, int32_t* out) {
    FFI_TRY
    if (!mi || !name || !out) return;
    auto val = toMaterialInstance(mi)->getParameter<int4>(name);
    out[0] = val.x; out[1] = val.y; out[2] = val.z; out[3] = val.w;
    FFI_CATCH()
}

uint32_t filament_material_instance_get_parameter_uint(void* mi, const char* name) {
    FFI_TRY
    if (!mi || !name) return 0;
    return toMaterialInstance(mi)->getParameter<uint32_t>(name);
    FFI_CATCH(0)
}

bool filament_material_instance_get_parameter_bool(void* mi, const char* name) {
    FFI_TRY
    if (!mi || !name) return false;
    return toMaterialInstance(mi)->getParameter<int32_t>(name) != 0;
    FFI_CATCH(false)
}

void filament_material_instance_get_parameter_mat4(void* mi, const char* name, float* out16) {
    FFI_TRY
    if (!mi || !name || !out16) return;
    auto val = toMaterialInstance(mi)->getParameter<mat4f>(name);
    std::memcpy(out16, &val[0][0], sizeof(float) * 16);
    FFI_CATCH()
}

void* filament_material_instance_get_material(void* mi) {
    FFI_TRY
    if (!mi) return nullptr;
    return const_cast<Material*>(toMaterialInstance(mi)->getMaterial());
    FFI_CATCH(nullptr)
}

const char* filament_material_instance_get_name(void* mi) {
    FFI_TRY
    if (!mi) return "";
    const char* n = toMaterialInstance(mi)->getName();
    return n ? n : "";
    FFI_CATCH("")
}

void filament_material_instance_set_specular_antialiasing_variance(void* mi, float variance) {
    FFI_TRY
    if (!mi) return;
    auto* inst = toMaterialInstance(mi);
    if (!inst->getMaterial()->hasSpecularAntiAliasing()) return;
    inst->setSpecularAntiAliasingVariance(variance);
    FFI_CATCH()
}

float filament_material_instance_get_specular_antialiasing_variance(void* mi) {
    FFI_TRY
    if (!mi) return 0.0f;
    auto* inst = toMaterialInstance(mi);
    if (!inst->getMaterial()->hasSpecularAntiAliasing()) return 0.0f;
    return inst->getSpecularAntiAliasingVariance();
    FFI_CATCH(0.0f)
}

void filament_material_instance_set_specular_antialiasing_threshold(void* mi, float threshold) {
    FFI_TRY
    if (!mi) return;
    auto* inst = toMaterialInstance(mi);
    if (!inst->getMaterial()->hasSpecularAntiAliasing()) return;
    inst->setSpecularAntiAliasingThreshold(threshold);
    FFI_CATCH()
}

float filament_material_instance_get_specular_antialiasing_threshold(void* mi) {
    FFI_TRY
    if (!mi) return 0.0f;
    auto* inst = toMaterialInstance(mi);
    if (!inst->getMaterial()->hasSpecularAntiAliasing()) return 0.0f;
    return inst->getSpecularAntiAliasingThreshold();
    FFI_CATCH(0.0f)
}
