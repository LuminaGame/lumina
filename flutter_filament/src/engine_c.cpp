/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "engine_c.h"
#include "gpu_c.h"
#include "lighting_c.h"

#include <backend/PixelBufferDescriptor.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <exception>
#include <stdexcept>
#include <filament/Engine.h>
#include <filament/LightManager.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/TransformManager.h>
#include <filament/SwapChain.h>
#include <filament/View.h>
#include <mutex>
#include <thread>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <utils/Panic.h>

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

static inline Engine *toEngine(void *p) {
  return reinterpret_cast<Engine *>(p);
}
static inline Renderer *toRenderer(void *p) {
  return reinterpret_cast<Renderer *>(p);
}
static inline SwapChain *toSwapChain(void *p) {
  return reinterpret_cast<SwapChain *>(p);
}
static inline View *toView(void *p) { return reinterpret_cast<View *>(p); }
static inline Entity toEntity(uint32_t e) {
  return Entity::import(static_cast<int>(e));
}

#include "gltf_c.h"

#include <filament/Camera.h>
#include <filament/Texture.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/BufferObject.h>
#include <filament/SkinningBuffer.h>
#include <filament/MorphTargetBuffer.h>
#include <filament/InstanceBuffer.h>
#include <filament/IndirectLight.h>
#include <filament/Skybox.h>
#include <filament/RenderTarget.h>
#include <filament/Fence.h>
#include <filament/ColorGrading.h>
#include <filament/MaterialEnums.h>

// The hook (and tool/web/build_module.sh) define this from
// filament/android/gradle.properties; a build that forgot it must not report
// an empty version.
#ifndef FLUTTER_FILAMENT_FILAMENT_VERSION
#error "FLUTTER_FILAMENT_FILAMENT_VERSION is not defined: the build must stamp the Filament version"
#endif

// The define is the bare version (1.77.0): quoting it on the command line
// breaks cl under cmd on Windows, so the string is made here.
#define FLUTTER_FILAMENT_STR2(x) #x
#define FLUTTER_FILAMENT_STR(x) FLUTTER_FILAMENT_STR2(x)

const char* filament_get_version(void) {
    return FLUTTER_FILAMENT_STR(FLUTTER_FILAMENT_FILAMENT_VERSION);
}

uint32_t filament_get_material_version(void) {
    return static_cast<uint32_t>(filament::MATERIAL_VERSION);
}

void filament_engine_config_init_default(filament_engine_config_t* out) {
  if (!out) return;
  Engine::Config defaultCfg;
  out->command_buffer_size_mb = defaultCfg.commandBufferSizeMB;
  out->per_render_pass_arena_size_mb = defaultCfg.perRenderPassArenaSizeMB;
  out->min_command_buffer_size_mb = defaultCfg.minCommandBufferSizeMB;
  out->job_system_thread_count = defaultCfg.jobSystemThreadCount;
  out->preferred_shader_language = static_cast<int32_t>(defaultCfg.preferredShaderLanguage);
  out->force_gles2_context = defaultCfg.forceGLES2Context;
  out->gpu_context_priority = static_cast<int32_t>(defaultCfg.gpuContextPriority);
  out->material_cache_capacity = defaultCfg.materialCacheCapacity;
  out->stereoscopic_eye_count = defaultCfg.stereoscopicEyeCount;
  out->stereoscopic_type = static_cast<int32_t>(defaultCfg.stereoscopicType);
}

void* filament_engine_create_ex(int backend, int feature_level, bool paused, const filament_engine_config_t* config, const char* const* feature_names, const bool* feature_values, int feature_count) {
  // One creation path (gpu_engine_c.cpp), so the environment's GPU choice
  // applies to every Vulkan engine.
  return filament_engine_create_on_gpu(backend, feature_level, paused, config, feature_names, feature_values, feature_count, nullptr, -1);
}

void filament_engine_get_config(void* engine, filament_engine_config_t* out) {
  FFI_TRY
  if (!engine || !out) return;
  const Engine::Config& cfg = toEngine(engine)->getConfig();
  out->command_buffer_size_mb = cfg.commandBufferSizeMB;
  out->per_render_pass_arena_size_mb = cfg.perRenderPassArenaSizeMB;
  out->min_command_buffer_size_mb = cfg.minCommandBufferSizeMB;
  out->job_system_thread_count = cfg.jobSystemThreadCount;
  out->preferred_shader_language = static_cast<int32_t>(cfg.preferredShaderLanguage);
  out->force_gles2_context = cfg.forceGLES2Context;
  out->gpu_context_priority = static_cast<int32_t>(cfg.gpuContextPriority);
  out->material_cache_capacity = cfg.materialCacheCapacity;
  out->stereoscopic_eye_count = cfg.stereoscopicEyeCount;
  out->stereoscopic_type = static_cast<int32_t>(cfg.stereoscopicType);
  FFI_CATCH()
}

void *filament_engine_create(int backend) {
  return filament_engine_create_on_gpu(backend, -1, false, nullptr, nullptr, nullptr, 0, nullptr, -1);
}

void filament_engine_destroy(void *engine) {
  FFI_TRY
  if (engine) {
    filament_cleanup_engine_materials(engine);
    Engine* e = toEngine(engine);
    Engine::destroy(e);
    flutter_filament_release_gpu_platform(e);
    flutter_filament_forget_owned_textures(e);
  }
  FFI_CATCH()
}

void filament_engine_flush_and_wait(void *engine) {
  FFI_TRY
  if (engine) {
    toEngine(engine)->flushAndWait();
  }
  FFI_CATCH()
}

// isValid family
bool filament_engine_is_valid_renderer(void* engine, void* renderer) {
  FFI_TRY
  return engine && renderer && toEngine(engine)->isValid(reinterpret_cast<const Renderer*>(renderer));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_view(void* engine, void* view) {
  FFI_TRY
  return engine && view && toEngine(engine)->isValid(reinterpret_cast<const View*>(view));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_scene(void* engine, void* scene) {
  FFI_TRY
  return engine && scene && toEngine(engine)->isValid(reinterpret_cast<const Scene*>(scene));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_swap_chain(void* engine, void* swap_chain) {
  FFI_TRY
  return engine && swap_chain && toEngine(engine)->isValid(reinterpret_cast<const SwapChain*>(swap_chain));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_camera(void* engine, void* camera) {
  FFI_TRY
  if (!engine || !camera) return false;
  auto* c = reinterpret_cast<Camera*>(camera);
  return toEngine(engine)->getCameraComponent(c->getEntity()) != nullptr;
  FFI_CATCH(false)
}

bool filament_engine_is_valid_texture(void* engine, void* texture) {
  FFI_TRY
  return engine && texture && toEngine(engine)->isValid(reinterpret_cast<const Texture*>(texture));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_material(void* engine, void* material) {
  FFI_TRY
  return engine && material && toEngine(engine)->isValid(reinterpret_cast<const Material*>(material));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_material_instance(void* engine, void* material, void* mi) {
  FFI_TRY
  return engine && material && mi && toEngine(engine)->isValid(reinterpret_cast<const Material*>(material), reinterpret_cast<const MaterialInstance*>(mi));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_expensive_material_instance(void* engine, void* mi) {
  FFI_TRY
  return engine && mi && toEngine(engine)->isValidExpensive(reinterpret_cast<const MaterialInstance*>(mi));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_vertex_buffer(void* engine, void* vb) {
  FFI_TRY
  return engine && vb && toEngine(engine)->isValid(reinterpret_cast<const VertexBuffer*>(vb));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_index_buffer(void* engine, void* ib) {
  FFI_TRY
  return engine && ib && toEngine(engine)->isValid(reinterpret_cast<const IndexBuffer*>(ib));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_buffer_object(void* engine, void* bo) {
  FFI_TRY
  return engine && bo && toEngine(engine)->isValid(reinterpret_cast<const BufferObject*>(bo));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_skinning_buffer(void* engine, void* sb) {
  FFI_TRY
  return engine && sb && toEngine(engine)->isValid(reinterpret_cast<const SkinningBuffer*>(sb));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_morph_target_buffer(void* engine, void* mtb) {
  FFI_TRY
  return engine && mtb && toEngine(engine)->isValid(reinterpret_cast<const MorphTargetBuffer*>(mtb));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_instance_buffer(void* engine, void* ibuf) {
  FFI_TRY
  return engine && ibuf && toEngine(engine)->isValid(reinterpret_cast<const InstanceBuffer*>(ibuf));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_indirect_light(void* engine, void* ibl) {
  FFI_TRY
  return engine && ibl && toEngine(engine)->isValid(reinterpret_cast<const IndirectLight*>(ibl));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_skybox(void* engine, void* skybox) {
  FFI_TRY
  return engine && skybox && toEngine(engine)->isValid(reinterpret_cast<const Skybox*>(skybox));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_render_target(void* engine, void* rt) {
  FFI_TRY
  return engine && rt && toEngine(engine)->isValid(reinterpret_cast<const RenderTarget*>(rt));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_fence(void* engine, void* fence) {
  FFI_TRY
  return engine && fence && toEngine(engine)->isValid(reinterpret_cast<const Fence*>(fence));
  FFI_CATCH(false)
}

bool filament_engine_is_valid_color_grading(void* engine, void* cg) {
  FFI_TRY
  return engine && cg && toEngine(engine)->isValid(reinterpret_cast<const ColorGrading*>(cg));
  FFI_CATCH(false)
}

// Destroys
void filament_engine_destroy_entity_components(void* engine, uint32_t entity) {
  FFI_TRY
  if (engine && entity != 0) {
    toEngine(engine)->destroy(toEntity(entity));
  }
  FFI_CATCH()
}

void filament_engine_destroy_morph_target_buffer(void* engine, void* mtb) {
  FFI_TRY
  if (engine && mtb) {
    toEngine(engine)->destroy(reinterpret_cast<const MorphTargetBuffer*>(mtb));
  }
  FFI_CATCH()
}

void filament_engine_destroy_fence(void* engine, void* fence) {
  FFI_TRY
  if (engine && fence) {
    toEngine(engine)->destroy(reinterpret_cast<const Fence*>(fence));
  }
  FFI_CATCH()
}

void filament_engine_destroy_instance_buffer(void* engine, void* ibuf) {
  FFI_TRY
  if (engine && ibuf) {
    toEngine(engine)->destroy(reinterpret_cast<const InstanceBuffer*>(ibuf));
  }
  FFI_CATCH()
}

// Frame & Thread Control
void filament_engine_flush(void* engine) {
  FFI_TRY
  if (engine) toEngine(engine)->flush();
  FFI_CATCH()
}

bool filament_engine_flush_and_wait_timeout(void* engine, uint64_t timeout_ns) {
  FFI_TRY
  if (engine) return toEngine(engine)->flushAndWait(timeout_ns);
  return false;
  FFI_CATCH(false)
}

void filament_engine_execute(void* engine) {
  FFI_TRY
  if (engine) toEngine(engine)->execute();
  FFI_CATCH()
}

void filament_engine_set_paused(void* engine, bool paused) {
  FFI_TRY
  if (engine) toEngine(engine)->setPaused(paused);
  FFI_CATCH()
}

bool filament_engine_is_paused(void* engine) {
  FFI_TRY
  if (engine) return toEngine(engine)->isPaused();
  return false;
  FFI_CATCH(false)
}

int64_t filament_engine_get_steady_clock_time_nano(void* engine) {
  FFI_TRY
  if (engine) return toEngine(engine)->getSteadyClockTimeNano();
  return 0;
  FFI_CATCH(0)
}

// Capabilities & Query
int filament_engine_get_supported_feature_level(void* engine) {
  FFI_TRY
  if (engine) return static_cast<int>(toEngine(engine)->getSupportedFeatureLevel());
  return 0;
  FFI_CATCH(0)
}

int filament_engine_set_active_feature_level(void* engine, int level) {
  FFI_TRY
  if (engine) return static_cast<int>(toEngine(engine)->setActiveFeatureLevel(static_cast<Engine::FeatureLevel>(level)));
  return 0;
  FFI_CATCH(0)
}

int filament_engine_get_active_feature_level(void* engine) {
  FFI_TRY
  if (engine) return static_cast<int>(toEngine(engine)->getActiveFeatureLevel());
  return 0;
  FFI_CATCH(0)
}

uint32_t filament_engine_get_max_automatic_instances(void* engine) {
  FFI_TRY
  if (engine) return static_cast<uint32_t>(toEngine(engine)->getMaxAutomaticInstances());
  return 0;
  FFI_CATCH(0)
}

bool filament_engine_is_stereo_supported(void* engine, int stereoscopic_type) {
  FFI_TRY
  if (engine) return toEngine(engine)->isStereoSupported(static_cast<backend::StereoscopicType>(stereoscopic_type));
  return false;
  FFI_CATCH(false)
}

bool filament_engine_has_unrecoverable_failure(void* engine) {
  FFI_TRY
  if (engine) return toEngine(engine)->hasUnrecoverableFailure();
  return false;
  FFI_CATCH(false)
}

int filament_engine_get_backend(void* engine) {
  FFI_TRY
  if (engine) return static_cast<int>(toEngine(engine)->getBackend());
  return 0;
  FFI_CATCH(0)
}

const void* filament_engine_get_default_material(void* engine) {
  FFI_TRY
  if (engine) return toEngine(engine)->getDefaultMaterial();
  return nullptr;
  FFI_CATCH(nullptr)
}

void filament_engine_set_automatic_instancing_enabled(void* engine, bool enable) {
  FFI_TRY
  if (engine) toEngine(engine)->setAutomaticInstancingEnabled(enable);
  FFI_CATCH()
}

bool filament_engine_is_automatic_instancing_enabled(void* engine) {
  FFI_TRY
  if (engine) return toEngine(engine)->isAutomaticInstancingEnabled();
  return false;
  FFI_CATCH(false)
}

size_t filament_engine_get_material_count(void *engine) {
  FFI_TRY
  if (engine) {
    return toEngine(engine)->getMaterialCount();
  }
  return 0;
  FFI_CATCH(0)
}

size_t filament_engine_get_vertex_buffer_count(void *engine) {
  FFI_TRY
  if (engine) {
    return toEngine(engine)->getVertexBufferCount();
  }
  return 0;
  FFI_CATCH(0)
}

size_t filament_engine_get_index_buffer_count(void *engine) {
  FFI_TRY
  if (engine) {
    return toEngine(engine)->getIndexBufferCount();
  }
  return 0;
  FFI_CATCH(0)
}

bool filament_engine_get_resource_counts(void *engine, filament_engine_resource_counts_t *out) {
  FFI_TRY
  if (!engine || !out) return false;
  Engine* e = toEngine(engine);
  out->textures = static_cast<int64_t>(e->getTextureCount());
  out->materials = static_cast<int64_t>(e->getMaterialCount());
  out->vertex_buffers = static_cast<int64_t>(e->getVertexBufferCount());
  out->index_buffers = static_cast<int64_t>(e->getIndexBufferCount());
  out->buffer_objects = static_cast<int64_t>(e->getBufferObjectCount());
  out->skinning_buffers = static_cast<int64_t>(e->getSkinningBufferCount());
  out->morph_target_buffers = static_cast<int64_t>(e->getMorphTargetBufferCount());
  out->instance_buffers = static_cast<int64_t>(e->getInstanceBufferCount());
  out->views = static_cast<int64_t>(e->getViewCount());
  out->scenes = static_cast<int64_t>(e->getSceneCount());
  out->swap_chains = static_cast<int64_t>(e->getSwapChainCount());
  out->indirect_lights = static_cast<int64_t>(e->getIndirectLightCount());
  out->skyboxes = static_cast<int64_t>(e->getSkyboxeCount());
  out->color_gradings = static_cast<int64_t>(e->getColorGradingCount());
  out->render_targets = static_cast<int64_t>(e->getRenderTargetCount());
  out->renderables = static_cast<int64_t>(e->getRenderableManager().getComponentCount());
  out->lights = static_cast<int64_t>(e->getLightManager().getComponentCount());
  out->transforms = static_cast<int64_t>(e->getTransformManager().getComponentCount());
  out->entities = static_cast<int64_t>(EntityManager::get().getEntityCount());
  return true;
  FFI_CATCH(false)
}

void *filament_engine_create_renderer(void *engine) {
  FFI_TRY
  return toEngine(engine)->createRenderer();
  FFI_CATCH(nullptr)
}

void filament_engine_destroy_renderer(void *engine, void *renderer) {
  FFI_TRY
  toEngine(engine)->destroy(toRenderer(renderer));
  FFI_CATCH()
}


void *filament_engine_create_swap_chain(void *engine, void *native_window,
                                        uint64_t flags) {
  FFI_TRY
  return toEngine(engine)->createSwapChain(native_window, flags);
  FFI_CATCH(nullptr)
}

void *filament_engine_create_headless_swap_chain(void *engine, uint32_t width,
                                                 uint32_t height,
                                                 uint64_t flags) {
  FFI_TRY
  if (flags == 0) {
    flags = backend::SWAP_CHAIN_CONFIG_READABLE |
            backend::SWAP_CHAIN_CONFIG_TRANSPARENT;
  }
  return toEngine(engine)->createSwapChain(width, height, flags);
  FFI_CATCH(nullptr)
}

void filament_engine_destroy_swap_chain(void *engine, void *swap_chain) {
  FFI_TRY
  toEngine(engine)->destroy(toSwapChain(swap_chain));
  FFI_CATCH()
}

uint32_t filament_entity_create(void *engine) {
  FFI_TRY
  Entity e = EntityManager::get().create();
  return static_cast<uint32_t>(e.getId());
  FFI_CATCH(0)
}

void filament_entity_destroy(void *engine, uint32_t entity) {
  FFI_TRY
  toEngine(engine)->destroy(toEntity(entity));
  EntityManager::get().destroy(toEntity(entity));
  FFI_CATCH()
}

bool filament_entity_manager_is_alive(uint32_t entity) {
  FFI_TRY
  return EntityManager::get().isAlive(toEntity(entity));
  FFI_CATCH(false)
}

void filament_entity_manager_create_entities(size_t n, uint32_t* out_entities) {
  FFI_TRY
  if (!out_entities || n == 0) return;
  // Filament EntityManager::create(n, Entity*)
  auto* entities = reinterpret_cast<Entity*>(out_entities);
  EntityManager::get().create(n, entities);
  FFI_CATCH()
}

void filament_entity_manager_destroy_entities(size_t n, uint32_t* entities) {
  FFI_TRY
  if (!entities || n == 0) return;
  auto* filEntities = reinterpret_cast<Entity*>(entities);
  EntityManager::get().destroy(n, filEntities);
  FFI_CATCH()
}

size_t filament_entity_manager_get_entity_count(void) {
  FFI_TRY
  return EntityManager::get().getEntityCount();
  FFI_CATCH(0)
}

void filament_entity_manager_advance_epoch(void) {
  FFI_TRY
  EntityManager::get().advanceEpoch();
  FFI_CATCH()
}
