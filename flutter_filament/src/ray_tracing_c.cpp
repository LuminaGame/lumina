/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "ray_tracing_c.h"
#include "gpu_engine_internal.h"

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/SwapChain.h>
#include <filament/View.h>
#include <filament/Viewport.h>
#include <math/vec3.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <utils/Panic.h>

#include <cstdio>
#include <exception>
#include <string>
#include <vector>

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
static inline Scene* toScene(void* p) { return reinterpret_cast<Scene*>(p); }
static inline View* toView(void* p) { return reinterpret_cast<View*>(p); }
static inline Entity toEntity(uint32_t id) { return Entity::import(static_cast<int32_t>(id)); }

namespace {

// The device extensions Vulkan ray queries need; unavailable ones are skipped by the
// platform with a log line, and the engine then reports no ray query support.
// Filament creates a Vulkan 1.1 device, so the extensions these depend on (core in 1.2)
// are listed too, dependencies first.
const std::vector<std::string> kRayQueryDeviceExtensions = {
    "VK_KHR_maintenance3",
    "VK_EXT_descriptor_indexing",
    "VK_KHR_shader_float_controls",
    "VK_KHR_spirv_1_4",
    "VK_KHR_device_group",
    "VK_KHR_buffer_device_address",
    "VK_KHR_deferred_host_operations",
    "VK_KHR_acceleration_structure",
    "VK_KHR_ray_query",
};

bool hasDesktopVulkanPlatform() {
#if defined(__EMSCRIPTEN__) || defined(__ANDROID__) || defined(__APPLE__)
    return false;
#else
    return true;
#endif
}

} // namespace

bool filament_ray_tracing_request_extensions(void) {
    if (!hasDesktopVulkanPlatform()) return false;
    flutter_filament_set_extra_vulkan_extensions("ray_tracing", {}, kRayQueryDeviceExtensions);
    return true;
}

void filament_ray_tracing_clear_extension_request(void) {
    flutter_filament_set_extra_vulkan_extensions("ray_tracing", {}, {});
}

bool filament_engine_supports_ray_query(void* engine) {
    FFI_TRY
    if (!engine) return false;
    return toEngine(engine)->isRayQuerySupported();
    FFI_CATCH(false)
}

void filament_scene_set_ray_tracing_enabled(void* scene, bool enabled) {
    FFI_TRY
    if (scene) toScene(scene)->setRayTracingEnabled(enabled);
    FFI_CATCH()
}

bool filament_scene_get_ray_tracing_enabled(void* scene) {
    FFI_TRY
    return scene ? toScene(scene)->isRayTracingEnabled() : false;
    FFI_CATCH(false)
}

uint32_t filament_scene_get_tlas_instance_count(void* scene) {
    FFI_TRY
    return scene ? toScene(scene)->getTlasInstanceCount() : 0u;
    FFI_CATCH(0u)
}

uint64_t filament_scene_get_tlas_build_nanos(void* scene) {
    FFI_TRY
    return scene ? toScene(scene)->getLastTlasBuildTimeNanos() : 0u;
    FFI_CATCH(0u)
}

void filament_renderable_set_ray_tracing_visible(void* engine, uint32_t entity, bool visible) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    if (instance) rm.setRayTracingVisible(instance, visible);
    FFI_CATCH()
}

bool filament_renderable_is_ray_tracing_visible(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    return instance ? rm.isRayTracingVisible(instance) : false;
    FFI_CATCH(false)
}

bool filament_scene_trace_visibility(void* engine, void* scene,
        const float* origin3, const float* direction3, float max_distance,
        float* out_distance, uint32_t* out_entity, uint32_t* out_primitive) {
    if (out_distance) *out_distance = 0.0f;
    if (out_entity) *out_entity = 0u;
    if (out_primitive) *out_primitive = 0u;
    FFI_TRY
    if (!engine || !scene || !origin3 || !direction3) return false;
    Engine* const e = toEngine(engine);
    Scene* const s = toScene(scene);
    if (!e->isRayQuerySupported() || !s->isRayTracingEnabled()) return false;

    // A throwaway 1x1 view over the scene: the renderer answers the query while it
    // renders the view, which also rebuilds the acceleration structures first.
    SwapChain* const swapChain = e->createSwapChain(1, 1, 0);
    Renderer* const renderer = e->createRenderer();
    View* const view = e->createView();
    Entity const cameraEntity = EntityManager::get().create();
    Camera* const camera = e->createCamera(cameraEntity);
    camera->setProjection(45.0, 1.0, 0.1, 100.0);
    view->setScene(s);
    view->setCamera(camera);
    view->setViewport({ 0, 0, 1, 1 });
    view->setPostProcessingEnabled(false);
    view->setShadowingEnabled(false);
    view->setScreenSpaceRefractionEnabled(false);

    struct Answer {
        bool done = false;
        View::RayQueryResult result{};
    } answer;
    view->traceRay(math::float3{ origin3[0], origin3[1], origin3[2] },
            math::float3{ direction3[0], direction3[1], direction3[2] }, max_distance,
            [&answer](View::RayQueryResult const& result) {
                answer.result = result;
                answer.done = true;
            });

    // The read-back lands a frame or two later; the callback runs on this thread
    // inside flushAndWait().
    for (int frame = 0; frame < 16 && !answer.done; frame++) {
        if (renderer->beginFrame(swapChain)) {
            renderer->render(view);
            renderer->endFrame();
        }
        e->flushAndWait();
    }

    view->setScene(nullptr);
    e->destroy(view);
    e->destroy(renderer);
    e->destroy(swapChain);
    e->destroyCameraComponent(cameraEntity);
    EntityManager::get().destroy(cameraEntity);
    e->flushAndWait();

    if (!answer.done || !answer.result.hit) return false;
    if (out_distance) *out_distance = answer.result.distance;
    if (out_entity) *out_entity = answer.result.renderable.isNull() ? 0u : static_cast<uint32_t>(answer.result.renderable.getId());
    if (out_primitive) *out_primitive = answer.result.primitive;
    return true;
    FFI_CATCH(false)
}

void filament_view_trace_ray(void* view, const float* origin3, const float* direction3,
        float max_distance, FilamentRayHitCallback callback, void* user_data) {
    FFI_TRY
    if (!callback) return;
    if (!view || !origin3 || !direction3) {
        callback(false, 0.0f, 0u, 0u, user_data);
        return;
    }
    toView(view)->traceRay(math::float3{ origin3[0], origin3[1], origin3[2] },
            math::float3{ direction3[0], direction3[1], direction3[2] }, max_distance,
            [callback, user_data](View::RayQueryResult const& result) {
                uint32_t const entity = result.renderable.isNull() ? 0u : static_cast<uint32_t>(result.renderable.getId());
                callback(result.hit, result.distance, entity, result.primitive, user_data);
            });
    FFI_CATCH()
}
