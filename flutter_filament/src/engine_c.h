/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_ENGINE_C_H
#define FLUTTER_FILAMENT_ENGINE_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FILAMENT_BACKEND_DEFAULT = 0,
    FILAMENT_BACKEND_OPENGL  = 1,
    FILAMENT_BACKEND_VULKAN  = 2,
    FILAMENT_BACKEND_METAL   = 3,
    FILAMENT_BACKEND_WEBGPU  = 4,
    FILAMENT_BACKEND_NOOP    = 5,
} FilamentBackend;

typedef struct filament_engine_config_t {
    uint32_t command_buffer_size_mb;        // Config::commandBufferSizeMB
    uint32_t per_render_pass_arena_size_mb; // Config::perRenderPassArenaSizeMB
    uint32_t min_command_buffer_size_mb;    // Config::minCommandBufferSizeMB
    uint32_t job_system_thread_count;       // Config::jobSystemThreadCount (0 = automatic)
    int32_t  preferred_shader_language;     // Config::ShaderLanguage
    bool     force_gles2_context;           // Config::forceGLES2Context
    int32_t  gpu_context_priority;          // Config::GpuContextPriority
    uint32_t material_cache_capacity;       // Config::materialCacheCapacity
    uint32_t stereoscopic_eye_count;        // Config::stereoscopicEyeCount
    int32_t  stereoscopic_type;             // Config::StereoscopicType
} filament_engine_config_t;

// Version: the Filament release the wrapper was built against
// (VERSION_NAME of filament/android/gradle.properties, stamped by the build),
// as a static string that must not be freed; and the material version the
// linked headers accept.
FFI_PLUGIN_EXPORT const char* filament_get_version(void);
FFI_PLUGIN_EXPORT uint32_t filament_get_material_version(void);

// Engine Creation & Config
FFI_PLUGIN_EXPORT void filament_engine_config_init_default(filament_engine_config_t* out);
FFI_PLUGIN_EXPORT void* filament_engine_create_ex(int backend, int feature_level, bool paused, const filament_engine_config_t* config, const char* const* feature_names, const bool* feature_values, int feature_count);
FFI_PLUGIN_EXPORT void filament_engine_get_config(void* engine, filament_engine_config_t* out);
FFI_PLUGIN_EXPORT void* filament_engine_create(int backend);
FFI_PLUGIN_EXPORT void filament_engine_destroy(void* engine);
FFI_PLUGIN_EXPORT void filament_engine_flush_and_wait(void* engine);
FFI_PLUGIN_EXPORT size_t filament_engine_get_material_count(void* engine);
FFI_PLUGIN_EXPORT size_t filament_engine_get_vertex_buffer_count(void* engine);
FFI_PLUGIN_EXPORT size_t filament_engine_get_index_buffer_count(void* engine);

/// Live object counts of one engine: Filament's `Engine::get*Count()`,
/// the renderable / light / transform component counts, and the process-wide
/// entity count (entities are not per engine). Lets tests prove that a
/// viewport sharing an engine left nothing behind, and that a second viewport
/// on the same asset uploaded no new texture.
typedef struct filament_engine_resource_counts_t {
    int64_t textures;
    int64_t materials;
    int64_t vertex_buffers;
    int64_t index_buffers;
    int64_t buffer_objects;
    int64_t skinning_buffers;
    int64_t morph_target_buffers;
    int64_t instance_buffers;
    int64_t views;
    int64_t scenes;
    int64_t swap_chains;
    int64_t indirect_lights;
    int64_t skyboxes;
    int64_t color_gradings;
    int64_t render_targets;
    int64_t renderables;
    int64_t lights;
    int64_t transforms;
    int64_t entities;
} filament_engine_resource_counts_t;

/// Fills [out] with [engine]'s live object counts; false for a null engine.
FFI_PLUGIN_EXPORT bool filament_engine_get_resource_counts(void* engine, filament_engine_resource_counts_t* out);

// isValid family
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_renderer(void* engine, void* renderer);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_view(void* engine, void* view);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_scene(void* engine, void* scene);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_swap_chain(void* engine, void* swap_chain);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_camera(void* engine, void* camera);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_texture(void* engine, void* texture);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material(void* engine, void* material);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material_instance(void* engine, void* material, void* mi);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_expensive_material_instance(void* engine, void* mi);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_vertex_buffer(void* engine, void* vb);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_index_buffer(void* engine, void* ib);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_buffer_object(void* engine, void* bo);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skinning_buffer(void* engine, void* sb);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_morph_target_buffer(void* engine, void* mtb);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_instance_buffer(void* engine, void* ibuf);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_indirect_light(void* engine, void* ibl);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skybox(void* engine, void* skybox);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_render_target(void* engine, void* rt);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_fence(void* engine, void* fence);
FFI_PLUGIN_EXPORT bool filament_engine_is_valid_color_grading(void* engine, void* cg);

// Destroys
FFI_PLUGIN_EXPORT void filament_engine_destroy_entity_components(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_engine_destroy_morph_target_buffer(void* engine, void* mtb);
FFI_PLUGIN_EXPORT void filament_engine_destroy_fence(void* engine, void* fence);
FFI_PLUGIN_EXPORT void filament_engine_destroy_instance_buffer(void* engine, void* ibuf);

// Frame & Thread Control
FFI_PLUGIN_EXPORT void    filament_engine_flush(void* engine);
FFI_PLUGIN_EXPORT bool    filament_engine_flush_and_wait_timeout(void* engine, uint64_t timeout_ns);
FFI_PLUGIN_EXPORT void    filament_engine_execute(void* engine);
FFI_PLUGIN_EXPORT void    filament_engine_set_paused(void* engine, bool paused);
FFI_PLUGIN_EXPORT bool    filament_engine_is_paused(void* engine);
FFI_PLUGIN_EXPORT int64_t filament_engine_get_steady_clock_time_nano(void* engine);

// Capabilities & Query
FFI_PLUGIN_EXPORT int      filament_engine_get_supported_feature_level(void* engine);
FFI_PLUGIN_EXPORT int      filament_engine_set_active_feature_level(void* engine, int level);
FFI_PLUGIN_EXPORT int      filament_engine_get_active_feature_level(void* engine);
FFI_PLUGIN_EXPORT uint32_t filament_engine_get_max_automatic_instances(void* engine);
FFI_PLUGIN_EXPORT bool     filament_engine_is_stereo_supported(void* engine, int stereoscopic_type);
FFI_PLUGIN_EXPORT bool     filament_engine_has_unrecoverable_failure(void* engine);
FFI_PLUGIN_EXPORT int      filament_engine_get_backend(void* engine);
FFI_PLUGIN_EXPORT const void* filament_engine_get_default_material(void* engine);
FFI_PLUGIN_EXPORT void     filament_engine_set_automatic_instancing_enabled(void* engine, bool enable);
FFI_PLUGIN_EXPORT bool     filament_engine_is_automatic_instancing_enabled(void* engine);

// Renderer
FFI_PLUGIN_EXPORT void* filament_engine_create_renderer(void* engine);
FFI_PLUGIN_EXPORT void filament_engine_destroy_renderer(void* engine, void* renderer);

// SwapChain
FFI_PLUGIN_EXPORT void* filament_engine_create_swap_chain(void* engine, void* native_window, uint64_t flags);
FFI_PLUGIN_EXPORT void* filament_engine_create_headless_swap_chain(void* engine, uint32_t width, uint32_t height, uint64_t flags);
FFI_PLUGIN_EXPORT void filament_engine_destroy_swap_chain(void* engine, void* swap_chain);

// Entity Manager
// Convention: the uint32 crossing FFI is exactly Entity::smuggle(e) and is reconstructed with Entity::import(id); 0 is the null entity.
FFI_PLUGIN_EXPORT uint32_t filament_entity_create(void* engine);
FFI_PLUGIN_EXPORT void filament_entity_destroy(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT bool filament_entity_manager_is_alive(uint32_t entity);
FFI_PLUGIN_EXPORT void filament_entity_manager_create_entities(size_t n, uint32_t* out_entities);
FFI_PLUGIN_EXPORT void filament_entity_manager_destroy_entities(size_t n, uint32_t* entities);
FFI_PLUGIN_EXPORT size_t filament_entity_manager_get_entity_count(void);
FFI_PLUGIN_EXPORT void filament_entity_manager_advance_epoch(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_ENGINE_C_H
