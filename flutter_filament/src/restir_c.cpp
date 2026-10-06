/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "restir_c.h"

#include <filament/Engine.h>
#include <filament/LightManager.h>
#include <filament/Options.h>
#include <filament/View.h>
#include <utils/Entity.h>
#include <utils/Panic.h>

#include <cstdio>
#include <exception>

using namespace filament;
using namespace utils;

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

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline View* toView(void* p) { return reinterpret_cast<View*>(p); }
static inline Entity toEntity(uint32_t id) { return Entity::import(static_cast<int32_t>(id)); }

static_assert(sizeof(filament_restir_options) == sizeof(RestirOptions),
        "filament_restir_options must mirror filament::RestirOptions");

void filament_view_set_restir_options(void* view, const filament_restir_options* options) {
    FFI_TRY
    if (!view || !options) return;
    RestirOptions o;
    o.enabled = options->enabled;
    o.initialCandidates = options->initialCandidates;
    o.spatialSamples = options->spatialSamples;
    o.spatialRadiusPx = options->spatialRadiusPx;
    o.temporal = options->temporal;
    o.maxHistory = options->maxHistory;
    o.visibilityRays = options->visibilityRays;
    o.shadeEmissive = options->shadeEmissive;
    toView(view)->setRestirOptions(o);
    FFI_CATCH()
}

void filament_view_get_restir_options(void* view, filament_restir_options* out_options) {
    FFI_TRY
    if (!view || !out_options) return;
    RestirOptions const& o = toView(view)->getRestirOptions();
    out_options->enabled = o.enabled;
    out_options->initialCandidates = o.initialCandidates;
    out_options->spatialSamples = o.spatialSamples;
    out_options->spatialRadiusPx = o.spatialRadiusPx;
    out_options->temporal = o.temporal;
    out_options->maxHistory = o.maxHistory;
    out_options->visibilityRays = o.visibilityRays;
    out_options->shadeEmissive = o.shadeEmissive;
    FFI_CATCH()
}

bool filament_view_restir_supported(void* view) {
    FFI_TRY
    return view ? toView(view)->isRestirSupported() : false;
    FFI_CATCH(false)
}

void filament_view_get_restir_stats(void* view, filament_restir_stats_t* out_stats) {
    FFI_TRY
    if (!out_stats) return;
    *out_stats = {};
    if (!view) return;
    View::RestirStats const stats = toView(view)->getRestirStats();
    out_stats->lightCount = stats.lightCount;
    out_stats->emissiveTriangleCount = stats.emissiveTriangleCount;
    out_stats->raysPerFrame = stats.raysPerFrame;
    out_stats->gpuNanos = stats.gpuNanos;
    FFI_CATCH()
}

void filament_view_restir_reset_history(void* view) {
    FFI_TRY
    if (view) toView(view)->resetRestirHistory();
    FFI_CATCH()
}

void filament_light_set_restir_sampling_weight(void* engine, uint32_t entity, float weight) {
    FFI_TRY
    if (!engine) return;
    auto& lm = toEngine(engine)->getLightManager();
    auto instance = lm.getInstance(toEntity(entity));
    if (instance) lm.setRestirSamplingWeight(instance, weight);
    FFI_CATCH()
}
