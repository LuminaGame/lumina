/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "instance_c.h"

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/RenderableManager.h>
#include <filament/LightManager.h>
#include <utils/Entity.h>
#include <utils/Panic.h>
#include <math/mat4.h>
#include <cstring>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace filament::math;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Instance C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Instance C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Instance C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline Entity toEntity(uint32_t e) { return Entity::import(static_cast<int>(e)); }

uint32_t filament_transform_manager_get_instance(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return 0;
    TransformManager& tm = toEngine(engine)->getTransformManager();
    auto ti = tm.getInstance(toEntity(entity));
    return ti.asValue();
    FFI_CATCH(0)
}

bool filament_transform_manager_has_component(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return false;
    TransformManager& tm = toEngine(engine)->getTransformManager();
    return tm.hasComponent(toEntity(entity));
    FFI_CATCH(false)
}

void filament_transform_manager_set_transform_i(
    void* engine, uint32_t instance, const float* mat4f_ptr) {
    FFI_TRY
    if (!engine || instance == 0 || !mat4f_ptr) return;
    TransformManager& tm = toEngine(engine)->getTransformManager();
    const mat4f* matrix = reinterpret_cast<const mat4f*>(mat4f_ptr);
    tm.setTransform(TransformManager::Instance(instance), *matrix);
    FFI_CATCH()
}

void filament_transform_manager_get_transform_i(
    void* engine, uint32_t instance, float* out_mat4f) {
    FFI_TRY
    if (!engine || instance == 0 || !out_mat4f) return;
    TransformManager& tm = toEngine(engine)->getTransformManager();
    mat4f local = tm.getTransform(TransformManager::Instance(instance));
    std::memcpy(out_mat4f, &local, sizeof(mat4f));
    FFI_CATCH()
}

void filament_transform_manager_get_world_transform_i(
    void* engine, uint32_t instance, float* out_mat4f) {
    FFI_TRY
    if (!engine || instance == 0 || !out_mat4f) return;
    TransformManager& tm = toEngine(engine)->getTransformManager();
    mat4f world = tm.getWorldTransform(TransformManager::Instance(instance));
    std::memcpy(out_mat4f, &world, sizeof(mat4f));
    FFI_CATCH()
}

uint32_t filament_renderable_manager_get_instance(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return 0;
    RenderableManager& rm = toEngine(engine)->getRenderableManager();
    auto ri = rm.getInstance(toEntity(entity));
    return ri.asValue();
    FFI_CATCH(0)
}

bool filament_renderable_manager_has_component(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return false;
    RenderableManager& rm = toEngine(engine)->getRenderableManager();
    return rm.hasComponent(toEntity(entity));
    FFI_CATCH(false)
}

uint32_t filament_light_manager_get_instance(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return 0;
    LightManager& lm = toEngine(engine)->getLightManager();
    auto li = lm.getInstance(toEntity(entity));
    return li.asValue();
    FFI_CATCH(0)
}

bool filament_light_manager_has_component(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine || entity == 0) return false;
    LightManager& lm = toEngine(engine)->getLightManager();
    return lm.hasComponent(toEntity(entity));
    FFI_CATCH(false)
}
