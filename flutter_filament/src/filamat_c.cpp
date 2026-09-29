/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Desktop only: filamat (the runtime material compiler) is not in Filament's WebAssembly build. Web builds get src/web_stubs_c.cpp (tool/web/gen_web_stubs.mjs).
#ifndef __EMSCRIPTEN__

#include "filamat_c.h"

#include <filamat/MaterialBuilder.h>
#include <filamat/Package.h>
#include <utils/JobSystem.h>
#include <utils/Panic.h>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <exception>

using namespace filamat;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Filamat C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Filamat C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Filamat C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline MaterialBuilder* toBuilder(void* p) { return reinterpret_cast<MaterialBuilder*>(p); }

void filament_filamat_init(void) {
    FFI_TRY
    MaterialBuilder::init();
    FFI_CATCH()
}

void filament_filamat_shutdown(void) {
    FFI_TRY
    MaterialBuilder::shutdown();
    FFI_CATCH()
}

void* filament_material_builder_create(void) {
    FFI_TRY
    auto builder = new MaterialBuilder();
    builder->targetApi(MaterialBuilder::TargetApi::ALL);
    builder->platform(MaterialBuilder::Platform::ALL);
    builder->culling(MaterialBuilder::CullingMode::NONE);
    return builder;
    FFI_CATCH(nullptr)
}

void filament_material_builder_destroy(void* builder) {
    FFI_TRY
    if (builder) {
        delete toBuilder(builder);
    }
    FFI_CATCH()
}

void filament_material_builder_set_name(void* builder, const char* name) {
    FFI_TRY
    toBuilder(builder)->name(name);
    FFI_CATCH()
}

void filament_material_builder_set_code(void* builder, const char* glsl_code) {
    FFI_TRY
    toBuilder(builder)->material(glsl_code);
    FFI_CATCH()
}

void filament_material_builder_set_shading(void* builder, int shading) {
    FFI_TRY
    toBuilder(builder)->shading(static_cast<filament::Shading>(shading));
    FFI_CATCH()
}

void filament_material_builder_set_double_sided(void* builder, bool double_sided) {
    FFI_TRY
    toBuilder(builder)->doubleSided(double_sided);
    FFI_CATCH()
}

void filament_material_builder_require_attribute(void* builder, int attribute) {
    FFI_TRY
    toBuilder(builder)->require(static_cast<filament::VertexAttribute>(attribute));
    FFI_CATCH()
}

void filament_material_builder_parameter_sampler(void* builder, const char* name, int sampler_type) {
    FFI_TRY
    toBuilder(builder)->parameter(name, static_cast<MaterialBuilder::SamplerType>(sampler_type));
    FFI_CATCH()
}

void filament_material_builder_parameter(void* builder, const char* name, int uniform_type, int precision) {
    FFI_TRY
    toBuilder(builder)->parameter(name, static_cast<MaterialBuilder::UniformType>(uniform_type), static_cast<MaterialBuilder::ParameterPrecision>(precision));
    FFI_CATCH()
}

void filament_material_builder_parameter_array(void* builder, const char* name, size_t size, int uniform_type, int precision) {
    FFI_TRY
    toBuilder(builder)->parameter(name, size, static_cast<MaterialBuilder::UniformType>(uniform_type), static_cast<MaterialBuilder::ParameterPrecision>(precision));
    FFI_CATCH()
}

void filament_material_builder_constant_bool(void* builder, const char* name, bool default_value) {
    FFI_TRY
    toBuilder(builder)->constant<bool>(name, MaterialBuilder::ConstantType::BOOL, default_value);
    FFI_CATCH()
}

void filament_material_builder_constant_int(void* builder, const char* name, int32_t default_value) {
    FFI_TRY
    toBuilder(builder)->constant<int32_t>(name, MaterialBuilder::ConstantType::INT, default_value);
    FFI_CATCH()
}

void filament_material_builder_constant_float(void* builder, const char* name, float default_value) {
    FFI_TRY
    toBuilder(builder)->constant<float>(name, MaterialBuilder::ConstantType::FLOAT, default_value);
    FFI_CATCH()
}

void filament_material_builder_material_vertex(void* builder, const char* code) {
    FFI_TRY
    toBuilder(builder)->materialVertex(code);
    FFI_CATCH()
}

void filament_material_builder_variable(void* builder, int variable, const char* name) {
    FFI_TRY
    toBuilder(builder)->variable(static_cast<MaterialBuilder::Variable>(variable), name);
    FFI_CATCH()
}

void filament_material_builder_variable_precision(void* builder, int variable, const char* name, int precision) {
    FFI_TRY
    toBuilder(builder)->variable(static_cast<MaterialBuilder::Variable>(variable), name, static_cast<MaterialBuilder::ParameterPrecision>(precision));
    FFI_CATCH()
}

void filament_material_builder_vertex_domain(void* builder, int domain) {
    FFI_TRY
    toBuilder(builder)->vertexDomain(static_cast<MaterialBuilder::VertexDomain>(domain));
    FFI_CATCH()
}

void filament_material_builder_vertex_domain_device_jittered(void* builder, bool jittered) {
    FFI_TRY
    toBuilder(builder)->vertexDomainDeviceJittered(jittered);
    FFI_CATCH()
}

void filament_material_builder_flip_uv(void* builder, bool flip) {
    FFI_TRY
    toBuilder(builder)->flipUV(flip);
    FFI_CATCH()
}

void filament_material_builder_blending(void* builder, int blending_mode) {
    FFI_TRY
    toBuilder(builder)->blending(static_cast<MaterialBuilder::BlendingMode>(blending_mode));
    FFI_CATCH()
}

void filament_material_builder_custom_blend_functions(void* builder, int src_rgb, int src_a, int dst_rgb, int dst_a) {
    FFI_TRY
    toBuilder(builder)->customBlendFunctions(
        static_cast<MaterialBuilder::BlendFunction>(src_rgb),
        static_cast<MaterialBuilder::BlendFunction>(src_a),
        static_cast<MaterialBuilder::BlendFunction>(dst_rgb),
        static_cast<MaterialBuilder::BlendFunction>(dst_a));
    FFI_CATCH()
}

void filament_material_builder_post_lighting_blending(void* builder, int blending_mode) {
    FFI_TRY
    toBuilder(builder)->postLightingBlending(static_cast<MaterialBuilder::BlendingMode>(blending_mode));
    FFI_CATCH()
}

void filament_material_builder_transparency_mode(void* builder, int mode) {
    FFI_TRY
    toBuilder(builder)->transparencyMode(static_cast<MaterialBuilder::TransparencyMode>(mode));
    FFI_CATCH()
}

void filament_material_builder_mask_threshold(void* builder, float threshold) {
    FFI_TRY
    toBuilder(builder)->maskThreshold(threshold);
    FFI_CATCH()
}

void filament_material_builder_alpha_to_coverage(void* builder, bool enable) {
    FFI_TRY
    toBuilder(builder)->alphaToCoverage(enable);
    FFI_CATCH()
}

void filament_material_builder_refraction_mode(void* builder, int mode) {
    FFI_TRY
    toBuilder(builder)->refractionMode(static_cast<MaterialBuilder::RefractionMode>(mode));
    FFI_CATCH()
}

void filament_material_builder_refraction_type(void* builder, int type) {
    FFI_TRY
    toBuilder(builder)->refractionType(static_cast<MaterialBuilder::RefractionType>(type));
    FFI_CATCH()
}

void filament_material_builder_culling(void* builder, int culling_mode) {
    FFI_TRY
    toBuilder(builder)->culling(static_cast<MaterialBuilder::CullingMode>(culling_mode));
    FFI_CATCH()
}

void filament_material_builder_color_write(void* builder, bool enable) {
    FFI_TRY
    toBuilder(builder)->colorWrite(enable);
    FFI_CATCH()
}

void filament_material_builder_depth_write(void* builder, bool enable) {
    FFI_TRY
    toBuilder(builder)->depthWrite(enable);
    FFI_CATCH()
}

void filament_material_builder_depth_culling(void* builder, bool enable) {
    FFI_TRY
    toBuilder(builder)->depthCulling(enable);
    FFI_CATCH()
}

void filament_material_builder_instanced(void* builder, bool enable) {
    FFI_TRY
    toBuilder(builder)->instanced(enable);
    FFI_CATCH()
}

void filament_material_builder_material_domain(void* builder, int domain) {
    FFI_TRY
    toBuilder(builder)->materialDomain(static_cast<MaterialBuilder::MaterialDomain>(domain));
    FFI_CATCH()
}

void filament_material_builder_group_size(void* builder, uint32_t x, uint32_t y, uint32_t z) {
    FFI_TRY
    toBuilder(builder)->groupSize(filament::math::uint3{x, y, z});
    FFI_CATCH()
}

void filament_material_builder_output(void* builder, int qualifier, int target, int precision, int type, const char* name, int location) {
    FFI_TRY
    toBuilder(builder)->output(
        static_cast<MaterialBuilder::VariableQualifier>(qualifier),
        static_cast<MaterialBuilder::OutputTarget>(target),
        static_cast<MaterialBuilder::Precision>(precision),
        static_cast<MaterialBuilder::OutputType>(type),
        name,
        location);
    FFI_CATCH()
}

void filament_material_builder_enable_framebuffer_fetch(void* builder) {
    FFI_TRY
    toBuilder(builder)->enableFramebufferFetch();
    FFI_CATCH()
}

void filament_material_builder_subpass(void* builder, int type, const char* name) {
    FFI_TRY
    toBuilder(builder)->subpass(static_cast<MaterialBuilder::SubpassType>(type), name);
    FFI_CATCH()
}

void filament_material_builder_platform(void* builder, int platform) {
    FFI_TRY
    toBuilder(builder)->platform(static_cast<MaterialBuilder::Platform>(platform));
    FFI_CATCH()
}

void filament_material_builder_target_api(void* builder, int api) {
    FFI_TRY
    toBuilder(builder)->targetApi(static_cast<MaterialBuilder::TargetApi>(api));
    FFI_CATCH()
}

void filament_material_builder_optimization(void* builder, int level) {
    FFI_TRY
    toBuilder(builder)->optimization(static_cast<MaterialBuilder::Optimization>(level));
    FFI_CATCH()
}

void filament_material_builder_variant_filter(void* builder, uint64_t mask) {
    FFI_TRY
    toBuilder(builder)->variantFilter(static_cast<filament::UserVariantFilterMask>(mask));
    FFI_CATCH()
}

void filament_material_builder_shader_define(void* builder, const char* name, const char* value) {
    FFI_TRY
    toBuilder(builder)->shaderDefine(name, value);
    FFI_CATCH()
}

void filament_material_builder_shadow_multiplier(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->shadowMultiplier(enabled);
    FFI_CATCH()
}

void filament_material_builder_transparent_shadow(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->transparentShadow(enabled);
    FFI_CATCH()
}

void filament_material_builder_colored_penumbra(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->coloredPenumbra(enabled);
    FFI_CATCH()
}

void filament_material_builder_shadow_far_attenuation(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->shadowFarAttenuation(enabled);
    FFI_CATCH()
}

void filament_material_builder_quality(void* builder, int quality) {
    FFI_TRY
    toBuilder(builder)->quality(static_cast<MaterialBuilder::ShaderQuality>(quality));
    FFI_CATCH()
}

void filament_material_builder_feature_level(void* builder, int level) {
    FFI_TRY
    toBuilder(builder)->featureLevel(static_cast<MaterialBuilder::FeatureLevel>(level));
    FFI_CATCH()
}

void filament_material_builder_include_essl1(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->includeEssl1(enabled);
    FFI_CATCH()
}

void filament_material_builder_interpolation(void* builder, int interpolation) {
    FFI_TRY
    toBuilder(builder)->interpolation(static_cast<MaterialBuilder::Interpolation>(interpolation));
    FFI_CATCH()
}

void filament_material_builder_specular_anti_aliasing(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->specularAntiAliasing(enabled);
    FFI_CATCH()
}

void filament_material_builder_specular_anti_aliasing_variance(void* builder, float variance) {
    FFI_TRY
    toBuilder(builder)->specularAntiAliasingVariance(variance);
    FFI_CATCH()
}

void filament_material_builder_specular_anti_aliasing_threshold(void* builder, float threshold) {
    FFI_TRY
    toBuilder(builder)->specularAntiAliasingThreshold(threshold);
    FFI_CATCH()
}

void filament_material_builder_clear_coat_ior_change(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->clearCoatIorChange(enabled);
    FFI_CATCH()
}

void filament_material_builder_linear_fog(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->linearFog(enabled);
    FFI_CATCH()
}

void filament_material_builder_custom_surface_shading(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->customSurfaceShading(enabled);
    FFI_CATCH()
}

void filament_material_builder_reflection_mode(void* builder, int mode) {
    FFI_TRY
    toBuilder(builder)->reflectionMode(static_cast<MaterialBuilder::ReflectionMode>(mode));
    FFI_CATCH()
}

void filament_material_builder_multi_bounce_ambient_occlusion(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->multiBounceAmbientOcclusion(enabled);
    FFI_CATCH()
}

void filament_material_builder_specular_ambient_occlusion(void* builder, int mode) {
    FFI_TRY
    toBuilder(builder)->specularAmbientOcclusion(static_cast<MaterialBuilder::SpecularAmbientOcclusion>(mode));
    FFI_CATCH()
}

void filament_material_builder_print_shaders(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->printShaders(enabled);
    FFI_CATCH()
}

void filament_material_builder_save_raw_variants(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->saveRawVariants(enabled);
    FFI_CATCH()
}

void filament_material_builder_generate_debug_info(void* builder, bool enabled) {
    FFI_TRY
    toBuilder(builder)->generateDebugInfo(enabled);
    FFI_CATCH()
}

void* filament_material_builder_build(void* builder, size_t* out_size) {
    FFI_TRY
    utils::JobSystem js(0);
    js.adopt();
    Package package = toBuilder(builder)->build(js);
    js.emancipate();
    if (!package.isValid()) {
        fprintf(stderr, "[Filamat C++ Error]: Material build failed! Package is invalid.\n");
        if (out_size) *out_size = 0;
        return nullptr;
    }
    size_t size = package.getSize();
    void* buffer = malloc(size);
    memcpy(buffer, package.getData(), size);
    if (out_size) *out_size = size;
    return buffer;
    FFI_CATCH(nullptr)
}

void filament_filamat_free_package(void* package_bytes) {
    FFI_TRY
    if (package_bytes) {
        free(package_bytes);
    }
    FFI_CATCH()
}

#endif  // __EMSCRIPTEN__
