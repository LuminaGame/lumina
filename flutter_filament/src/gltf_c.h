/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_GLTF_C_H
#define FLUTTER_FILAMENT_GLTF_C_H

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

typedef struct {
    uint8_t doubleSided;
    uint8_t unlit;
    uint8_t hasVertexColors;
    uint8_t hasBaseColorTexture;
    uint8_t hasNormalTexture;
    uint8_t hasOcclusionTexture;
    uint8_t hasEmissiveTexture;
    uint8_t useSpecularGlossiness;
    uint8_t alphaMode;
    uint8_t enableDiagnostics;
    uint8_t hasMetallicRoughnessTexture;
    uint8_t metallicRoughnessUV;
    uint8_t hasSpecularGlossinessTexture;
    uint8_t specularGlossinessUV;
    uint8_t baseColorUV;
    uint8_t hasClearCoatTexture;
    uint8_t clearCoatUV;
    uint8_t hasClearCoatRoughnessTexture;
    uint8_t clearCoatRoughnessUV;
    uint8_t hasClearCoatNormalTexture;
    uint8_t clearCoatNormalUV;
    uint8_t hasClearCoat;
    uint8_t hasTransmission;
    uint8_t hasTextureTransforms;
    uint8_t emissiveUV;
    uint8_t aoUV;
    uint8_t normalUV;
    uint8_t hasTransmissionTexture;
    uint8_t transmissionUV;
    uint8_t hasSheenColorTexture;
    uint8_t sheenColorUV;
    uint8_t hasSheenRoughnessTexture;
    uint8_t sheenRoughnessUV;
    uint8_t hasVolumeThicknessTexture;
    uint8_t volumeThicknessUV;
    uint8_t hasSheen;
    uint8_t hasIOR;
    uint8_t hasVolume;
    uint8_t hasDispersion;
    uint8_t hasSpecular;
    uint8_t hasSpecularTexture;
    uint8_t hasSpecularColorTexture;
    uint8_t specularTextureUV;
    uint8_t specularColorTextureUV;
} filament_gltfio_material_key_t;

FFI_PLUGIN_EXPORT void* filament_gltfio_create_ubershader_provider(void* engine, const void* archive, uint32_t archive_size);
FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provider(void* engine);
FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provider_ex(void* engine, bool optimize_shaders);

FFI_PLUGIN_EXPORT void filament_gltfio_destroy_material_provider(void* provider);
FFI_PLUGIN_EXPORT void* filament_gltfio_material_provider_create_material_instance(void* provider, filament_gltfio_material_key_t* config, uint8_t* out_uvmap8, const char* label, const char* extras);
FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_materials(void* provider, void** out, size_t max);
FFI_PLUGIN_EXPORT bool filament_gltfio_material_provider_needs_dummy_data(void* provider, int vertex_attribute);

FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_materials_count(void* provider);
FFI_PLUGIN_EXPORT void filament_gltfio_material_provider_destroy_materials(void* provider);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create(void* engine, void* material_provider);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_with_names(void* engine, void* material_provider, void* names);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy(void* loader);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_asset(void* loader, const uint8_t* bytes, uint32_t size);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instanced_asset(void* loader, const uint8_t* bytes, uint32_t size, void** out_instances, size_t num_instances);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instance(void* loader, void* asset);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy_asset(void* loader, void* asset);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_gc(void* loader);
FFI_PLUGIN_EXPORT void* filament_gltfio_resource_loader_create(void* engine, const char* default_path, bool normalize_skinning_weights);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_destroy(void* resource_loader);
FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_load_resources(void* resource_loader, void* asset);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_set_configuration(void* resource_loader, const char* default_path, bool normalize_skinning_weights);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_texture_provider(void* resource_loader, const char* mime, void* provider);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_resource_data(void* resource_loader, const char* uri, const uint8_t* data, size_t size);
FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_has_resource_data(void* resource_loader, const char* uri);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_evict_resource_data(void* resource_loader);
FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_async_begin_load(void* resource_loader, void* asset);
FFI_PLUGIN_EXPORT float filament_gltfio_resource_loader_async_get_load_progress(void* resource_loader);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_update_load(void* resource_loader);
FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_cancel_load(void* resource_loader);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_release_source_data(void* asset);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_root(void* asset);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_entity_count(void* asset);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_entities(void* asset);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_get_bounding_box(void* asset, float* out_min3, float* out_max3);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_light_entity_count(void* asset);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_light_entities(void* asset);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_renderable_entity_count(void* asset);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_renderable_entities(void* asset);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_camera_entity_count(void* asset);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_camera_entities(void* asset);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_resource_uri_count(void* asset);
FFI_PLUGIN_EXPORT const char* filament_gltfio_asset_get_resource_uri_at(void* asset, size_t i);
FFI_PLUGIN_EXPORT const char* filament_gltfio_asset_get_extras(void* asset, uint32_t entity);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_morph_target_count_at(void* asset, uint32_t entity);
FFI_PLUGIN_EXPORT const char* filament_gltfio_asset_get_morph_target_name_at(void* asset, uint32_t entity, size_t target);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_scene_count(void* asset);
FFI_PLUGIN_EXPORT const char* filament_gltfio_asset_get_scene_name(void* asset, size_t scene);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_add_entities_to_scene(void* asset, void* scene, const uint32_t* entities, size_t count, uint32_t scene_mask);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_pop_renderable(void* asset);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_pop_renderables(void* asset, uint32_t* out, size_t max);
FFI_PLUGIN_EXPORT void filament_gltfio_asset_detach_filament_components(void* asset);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_get_instance(void* asset);

FFI_PLUGIN_EXPORT void* filament_gltfio_instance_get_asset(void* instance);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_instance_get_entities(void* instance);
FFI_PLUGIN_EXPORT size_t filament_gltfio_instance_get_entity_count(void* instance);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_instance_get_root(void* instance);
FFI_PLUGIN_EXPORT void* filament_gltfio_instance_get_animator(void* instance);

FFI_PLUGIN_EXPORT size_t filament_gltfio_instance_get_skin_count(void* instance);
FFI_PLUGIN_EXPORT const char* filament_gltfio_instance_get_skin_name_at(void* instance, size_t skin);
FFI_PLUGIN_EXPORT size_t filament_gltfio_instance_get_joint_count_at(void* instance, size_t skin);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_instance_get_joints_at(void* instance, size_t skin);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_attach_skin(void* instance, size_t skin, uint32_t target_entity);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_detach_skin(void* instance, size_t skin, uint32_t target_entity);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_get_inverse_bind_matrices_at(void* instance, size_t skin, float* out_mat4_array);

FFI_PLUGIN_EXPORT size_t filament_gltfio_instance_get_material_instance_count(void* instance);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_get_material_instances(void* instance, void** out, size_t max);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_detach_material_instances(void* instance);

FFI_PLUGIN_EXPORT void filament_gltfio_instance_apply_material_variant(void* instance, size_t variant);
FFI_PLUGIN_EXPORT size_t filament_gltfio_instance_get_material_variant_count(void* instance);
FFI_PLUGIN_EXPORT const char* filament_gltfio_instance_get_material_variant_name(void* instance, size_t variant);

FFI_PLUGIN_EXPORT void filament_gltfio_instance_recompute_bounding_boxes(void* instance);
FFI_PLUGIN_EXPORT void filament_gltfio_instance_get_bounding_box(void* instance, float* out_min3, float* out_max3);
FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_entities(void* asset);
FFI_PLUGIN_EXPORT void filament_scene_add_asset_entities(void* scene, void* asset);
FFI_PLUGIN_EXPORT void filament_scene_remove_asset_entities(void* scene, void* asset);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_get_animator(void* asset);
FFI_PLUGIN_EXPORT void filament_gltfio_animator_apply_animation(void* animator, size_t animation_index, float time);
FFI_PLUGIN_EXPORT void filament_gltfio_animator_apply_cross_fade(void* animator, size_t previous_anim_index, float previous_anim_time, float alpha);
FFI_PLUGIN_EXPORT void filament_gltfio_animator_update_bone_matrices(void* animator);
FFI_PLUGIN_EXPORT void filament_gltfio_animator_reset_bone_matrices(void* animator);
FFI_PLUGIN_EXPORT size_t filament_gltfio_animator_get_animation_count(void* animator);
FFI_PLUGIN_EXPORT float filament_gltfio_animator_get_animation_duration(void* animator, size_t anim_index);
FFI_PLUGIN_EXPORT const char* filament_gltfio_animator_get_animation_name(void* animator, size_t anim_index);

// NodeManager
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_get_node_manager(void* loader);
FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_get_names(void* loader);
FFI_PLUGIN_EXPORT bool filament_gltfio_node_manager_has_component(void* nm, uint32_t entity);
FFI_PLUGIN_EXPORT const char* filament_gltfio_node_manager_get_extras(void* nm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_gltfio_node_manager_set_extras(void* nm, uint32_t entity, const char* json);
FFI_PLUGIN_EXPORT size_t filament_gltfio_node_manager_get_morph_target_name_count(void* nm, uint32_t entity);
FFI_PLUGIN_EXPORT const char* filament_gltfio_node_manager_get_morph_target_name_at(void* nm, uint32_t entity, size_t i);
FFI_PLUGIN_EXPORT void filament_gltfio_node_manager_set_morph_target_names(void* nm, uint32_t entity, const char* const* names, size_t count);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_node_manager_get_scene_membership(void* nm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_gltfio_node_manager_set_scene_membership(void* nm, uint32_t entity, uint32_t scene_mask);

// TrsTransformManager
FFI_PLUGIN_EXPORT void* filament_gltfio_trs_transform_manager_get(void* engine);
FFI_PLUGIN_EXPORT bool filament_gltfio_trs_transform_manager_has_component(void* tm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_trs_set_translation(void* tm, uint32_t entity, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_trs_get_translation(void* tm, uint32_t entity, float* out3);
FFI_PLUGIN_EXPORT void filament_trs_set_rotation(void* tm, uint32_t entity, float qx, float qy, float qz, float qw);
FFI_PLUGIN_EXPORT void filament_trs_get_rotation(void* tm, uint32_t entity, float* out_quat4);
FFI_PLUGIN_EXPORT void filament_trs_set_scale(void* tm, uint32_t entity, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_trs_get_scale(void* tm, uint32_t entity, float* out3);
FFI_PLUGIN_EXPORT void filament_trs_set_trs(void* tm, uint32_t entity, const float* t3, const float* quat4, const float* s3);
FFI_PLUGIN_EXPORT void filament_trs_get_transform(void* tm, uint32_t entity, float* out_mat4);

FFI_PLUGIN_EXPORT bool filament_gltf_decode_draco(const uint8_t* compressed_bytes, uint32_t compressed_size, float* out_positions, float* out_uvs, uint32_t* out_indices, uint32_t* out_vertex_count, uint32_t* out_index_count);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_wireframe(void* asset);
FFI_PLUGIN_EXPORT void* filament_gltf_create_mesh_wireframe(void* engine_ptr, const float* positions, uint32_t vertex_count, const uint32_t* indices, uint32_t index_count);
FFI_PLUGIN_EXPORT void* filament_create_line_segments_mesh(void* engine_ptr, const float* positions, uint32_t vertex_count, const uint32_t* line_indices, uint32_t line_index_count);
FFI_PLUGIN_EXPORT uint32_t filament_wireframe_handle_get_entity(void* handle_ptr);
FFI_PLUGIN_EXPORT void filament_wireframe_set_color(void* handle_ptr, float r, float g, float b, float a);

/// 1 when the wireframe mesh owns a compiled material instance, 0 when it does
/// not. A wireframe with no material instance is drawn by Filament's default
/// material, which ignores `filament_wireframe_set_color` entirely: the lines
/// come out white whatever colour is asked for.
FFI_PLUGIN_EXPORT int filament_wireframe_has_material(void* handle_ptr);
FFI_PLUGIN_EXPORT void filament_wireframe_handle_destroy(void* engine_ptr, void* handle_ptr);
FFI_PLUGIN_EXPORT void filament_cleanup_engine_materials(void* engine);
FFI_PLUGIN_EXPORT const char* filament_gltfio_asset_get_entity_name(void* asset, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_first_entity_by_name(void* asset, const char* name);
FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_entities_by_name(void* asset, const char* name, uint32_t* out_entities, size_t max_count);

FFI_PLUGIN_EXPORT void* filament_gltfio_create_stb_provider(void* engine);
FFI_PLUGIN_EXPORT void* filament_gltfio_create_ktx2_provider(void* engine);
FFI_PLUGIN_EXPORT void* filament_gltfio_create_webp_provider(void* engine);
FFI_PLUGIN_EXPORT bool filament_gltfio_is_webp_supported(void);
FFI_PLUGIN_EXPORT void filament_gltfio_texture_provider_destroy(void* provider);
FFI_PLUGIN_EXPORT void* filament_gltfio_texture_provider_push_texture(void* provider, const uint8_t* data, size_t size, const char* mime, uint64_t flags);
FFI_PLUGIN_EXPORT void* filament_gltfio_texture_provider_pop_texture(void* provider);
FFI_PLUGIN_EXPORT void filament_gltfio_texture_provider_update_queue(void* provider);
FFI_PLUGIN_EXPORT void filament_gltfio_texture_provider_wait_for_completion(void* provider);
FFI_PLUGIN_EXPORT void filament_gltfio_texture_provider_cancel_decoding(void* provider);
FFI_PLUGIN_EXPORT size_t filament_gltfio_texture_provider_get_pushed_count(void* provider);
FFI_PLUGIN_EXPORT size_t filament_gltfio_texture_provider_get_popped_count(void* provider);
FFI_PLUGIN_EXPORT size_t filament_gltfio_texture_provider_get_decoded_count(void* provider);
FFI_PLUGIN_EXPORT const char* filament_gltfio_texture_provider_get_push_message(void* provider);
FFI_PLUGIN_EXPORT const char* filament_gltfio_texture_provider_get_pop_message(void* provider);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_GLTF_C_H
