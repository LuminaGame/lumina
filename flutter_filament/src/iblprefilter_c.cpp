/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "iblprefilter_c.h"

#include <filament/Engine.h>
#include <filament/Texture.h>
#include <filament-iblprefilter/IBLPrefilterContext.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[IBLPrefilter C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[IBLPrefilter C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[IBLPrefilter C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline Texture* toTexture(void* p) { return reinterpret_cast<Texture*>(p); }

struct FilIblPrefilterContext {
    IBLPrefilterContext context;
    FilIblPrefilterContext(Engine& engine) : context(engine) {}
};

struct FilEquirectToCubemap {
    IBLPrefilterContext::EquirectangularToCubemap functor;
    FilEquirectToCubemap(IBLPrefilterContext& ctx, bool mirror)
        : functor(ctx, IBLPrefilterContext::EquirectangularToCubemap::Config{ mirror }) {}
};

struct FilSpecularFilter {
    IBLPrefilterContext::SpecularFilter filter;
    FilSpecularFilter(IBLPrefilterContext& ctx) : filter(ctx) {}
    FilSpecularFilter(IBLPrefilterContext& ctx, IBLPrefilterContext::SpecularFilter::Config config)
        : filter(ctx, config) {}
};

struct FilIrradianceFilter {
    IBLPrefilterContext::IrradianceFilter filter;
    FilIrradianceFilter(IBLPrefilterContext& ctx) : filter(ctx) {}
    FilIrradianceFilter(IBLPrefilterContext& ctx, IBLPrefilterContext::IrradianceFilter::Config config)
        : filter(ctx, config) {}
};

// Context
FilIblPrefilterContext* filament_iblprefilter_context_create(void* engine) {
    FFI_TRY
    if (!engine) return nullptr;
    return new FilIblPrefilterContext(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_iblprefilter_context_destroy(FilIblPrefilterContext* ctx) {
    FFI_TRY
    if (ctx) {
        delete ctx;
    }
    FFI_CATCH()
}

// EquirectangularToCubemap
FilEquirectToCubemap* filament_equirect_to_cubemap_create(FilIblPrefilterContext* ctx, bool mirror) {
    FFI_TRY
    if (!ctx) return nullptr;
    return new FilEquirectToCubemap(ctx->context, mirror);
    FFI_CATCH(nullptr)
}

void filament_equirect_to_cubemap_destroy(FilEquirectToCubemap* e) {
    FFI_TRY
    if (e) {
        delete e;
    }
    FFI_CATCH()
}

void* filament_equirect_to_cubemap_run(FilEquirectToCubemap* e, void* equirect, void* out_cube) {
    FFI_TRY
    if (!e || !equirect) return nullptr;
    Texture* out = e->functor(toTexture(equirect), toTexture(out_cube));
    return out;
    FFI_CATCH(nullptr)
}

// SpecularFilter
FilSpecularFilter* filament_specular_filter_create(FilIblPrefilterContext* ctx) {
    FFI_TRY
    if (!ctx) return nullptr;
    return new FilSpecularFilter(ctx->context);
    FFI_CATCH(nullptr)
}

FilSpecularFilter* filament_specular_filter_create_config(FilIblPrefilterContext* ctx, uint16_t sample_count, uint8_t level_count, int kernel) {
    FFI_TRY
    if (!ctx) return nullptr;
    IBLPrefilterContext::SpecularFilter::Config config;
    config.sampleCount = sample_count;
    config.levelCount = level_count;
    config.kernel = static_cast<IBLPrefilterContext::Kernel>(kernel);
    return new FilSpecularFilter(ctx->context, config);
    FFI_CATCH(nullptr)
}

void filament_specular_filter_destroy(FilSpecularFilter* f) {
    FFI_TRY
    if (f) {
        delete f;
    }
    FFI_CATCH()
}

void* filament_specular_filter_run(FilSpecularFilter* f, void* environment_cubemap, void* out_reflections, float hdr_linear, float hdr_max, float lod_offset, bool generate_mipmap) {
    FFI_TRY
    if (!f || !environment_cubemap) return nullptr;
    IBLPrefilterContext::SpecularFilter::Options options;
    options.hdrLinear = hdr_linear;
    options.hdrMax = hdr_max;
    options.lodOffset = lod_offset;
    options.generateMipmap = generate_mipmap;
    Texture* out = f->filter(options, toTexture(environment_cubemap), toTexture(out_reflections));
    return out;
    FFI_CATCH(nullptr)
}

// IrradianceFilter
FilIrradianceFilter* filament_irradiance_filter_create(FilIblPrefilterContext* ctx) {
    FFI_TRY
    if (!ctx) return nullptr;
    return new FilIrradianceFilter(ctx->context);
    FFI_CATCH(nullptr)
}

FilIrradianceFilter* filament_irradiance_filter_create_config(FilIblPrefilterContext* ctx, uint16_t sample_count, int kernel) {
    FFI_TRY
    if (!ctx) return nullptr;
    IBLPrefilterContext::IrradianceFilter::Config config;
    config.sampleCount = sample_count;
    config.kernel = static_cast<IBLPrefilterContext::Kernel>(kernel);
    return new FilIrradianceFilter(ctx->context, config);
    FFI_CATCH(nullptr)
}

void filament_irradiance_filter_destroy(FilIrradianceFilter* f) {
    FFI_TRY
    if (f) {
        delete f;
    }
    FFI_CATCH()
}

void* filament_irradiance_filter_run(FilIrradianceFilter* f, void* environment_cubemap, void* out_irradiance, float hdr_linear, float hdr_max, float lod_offset, bool generate_mipmap) {
    FFI_TRY
    if (!f || !environment_cubemap) return nullptr;
    IBLPrefilterContext::IrradianceFilter::Options options;
    options.hdrLinear = hdr_linear;
    options.hdrMax = hdr_max;
    options.lodOffset = lod_offset;
    options.generateMipmap = generate_mipmap;
    Texture* out = f->filter(options, toTexture(environment_cubemap), toTexture(out_irradiance));
    return out;
    FFI_CATCH(nullptr)
}
