/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_GEOMETRY_C_H
#define FLUTTER_FILAMENT_GEOMETRY_C_H

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
    FILAMENT_ATTR_POSITION  = 0,
    FILAMENT_ATTR_TANGENTS  = 1,
    FILAMENT_ATTR_COLOR     = 2,
    FILAMENT_ATTR_UV0       = 3,
    FILAMENT_ATTR_UV1       = 4,
} FilamentVertexAttribute;

typedef enum {
    FILAMENT_ELEMENT_FLOAT2 = 4,
    FILAMENT_ELEMENT_FLOAT3 = 5,
    FILAMENT_ELEMENT_FLOAT4 = 6,
    FILAMENT_ELEMENT_UBYTE4 = 10,
} FilamentElementType;

typedef enum {
    FILAMENT_INDEX_TYPE_USHORT = 0,
    FILAMENT_INDEX_TYPE_UINT   = 1,
} FilamentIndexType;

typedef enum {
    FILAMENT_PRIMITIVE_POINTS         = 0,
    FILAMENT_PRIMITIVE_LINES          = 1,
    FILAMENT_PRIMITIVE_LINE_STRIP     = 3,
    FILAMENT_PRIMITIVE_TRIANGLES      = 4,
    FILAMENT_PRIMITIVE_TRIANGLE_STRIP = 5,
} FilamentPrimitiveType;

// IndexBuffer

FFI_PLUGIN_EXPORT uint32_t filament_mesh_reader_load_mesh_from_buffer(
    void* engine, const void* data, uint32_t size, void* material_instance);
FFI_PLUGIN_EXPORT uint32_t filament_geometry_create_suzanne_monkey_mesh(
    void* engine, void* material_instance);
FFI_PLUGIN_EXPORT uint32_t filament_suzanne_sample_create(
    void* engine, void* view, void* scene);
FFI_PLUGIN_EXPORT void filament_suzanne_sample_destroy(
    void* engine, void* scene);


// MaterialInstance (moved to material_instance_c.h)
FFI_PLUGIN_EXPORT void filament_engine_destroy_material_instance(void* engine, void* mi);

typedef struct FilamentBone {
    float unit_quat[4];
    float translation[3];
    float reserved;
} FilamentBone;

// RenderableManager
FFI_PLUGIN_EXPORT void* filament_renderable_builder_create(uint32_t primitive_count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry(void* builder, uint32_t index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_min_max(void* builder, uint32_t index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t min_index, uint32_t max_index, uint32_t count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_full(void* builder, uint32_t index, int primitive_type, void* vb, void* ib);
FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_no_index(void* builder, uint32_t index, int primitive_type, void* vb);
FFI_PLUGIN_EXPORT void filament_renderable_builder_material(void* builder, uint32_t index, void* material_instance);
FFI_PLUGIN_EXPORT void filament_renderable_builder_bounding_box(void* builder, float min_x, float min_y, float min_z, float max_x, float max_y, float max_z);
FFI_PLUGIN_EXPORT void filament_renderable_builder_culling(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_cast_shadows(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_receive_shadows(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_priority(void* builder, uint8_t priority);
FFI_PLUGIN_EXPORT void filament_renderable_builder_layer_mask(void* builder, uint8_t select, uint8_t values);
FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning(void* builder, uint32_t bone_count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_bones(void* builder, uint32_t bone_count, const FilamentBone* bones);
FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_matrices(void* builder, uint32_t bone_count, const float* transforms);
FFI_PLUGIN_EXPORT void filament_renderable_builder_enable_skinning_buffers(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_buffer(void* builder, void* skinning_buffer, uint32_t bone_count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_renderable_builder_bone_indices_and_weights(void* builder, uint32_t primitive_index, const float* indices_and_weights, uint32_t count, uint32_t bones_per_vertex);
FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_type(void* builder, int geometry_type);
FFI_PLUGIN_EXPORT void filament_renderable_builder_channel(void* builder, uint8_t channel);
FFI_PLUGIN_EXPORT void filament_renderable_builder_light_channel(void* builder, unsigned int channel, bool enable);
FFI_PLUGIN_EXPORT void filament_renderable_builder_blend_order(void* builder, uint32_t primitive_index, uint16_t order);
FFI_PLUGIN_EXPORT void filament_renderable_builder_global_blend_order_enabled(void* builder, uint32_t primitive_index, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_screen_space_contact_shadows(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_fog(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing(void* builder, uint32_t target_count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_buffer(void* builder, void* morph_target_buffer);
FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_offset_at(void* builder, uint8_t level, uint32_t primitive_index, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_renderable_builder_instances(void* builder, uint32_t instance_count);
FFI_PLUGIN_EXPORT void filament_renderable_builder_instances_buffer(void* builder, uint32_t instance_count, void* instance_buffer);
FFI_PLUGIN_EXPORT int32_t filament_renderable_builder_build(void* builder, void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_renderable_builder_destroy(void* builder);

FFI_PLUGIN_EXPORT void filament_renderable_create(void* engine, uint32_t entity, void* vb, void* ib, void* mi, uint32_t offset, uint32_t count, int primitive_type);
FFI_PLUGIN_EXPORT void filament_renderable_set_bounding_box(void* engine, uint32_t entity, float min_x, float min_y, float min_z, float max_x, float max_y, float max_z);
FFI_PLUGIN_EXPORT void filament_renderable_set_priority(void* engine, uint32_t entity, uint8_t priority);
FFI_PLUGIN_EXPORT void filament_renderable_set_culling(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_set_cast_shadows(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_set_receive_shadows(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT void filament_renderable_set_layer_mask(void* engine, uint32_t entity, uint8_t select, uint8_t values);
FFI_PLUGIN_EXPORT void filament_renderable_set_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index, void* material_instance);
FFI_PLUGIN_EXPORT void filament_renderable_set_geometry_at(void* engine, uint32_t entity, uint32_t primitive_index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t count);
FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_primitive_count(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void* filament_renderable_get_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index);
FFI_PLUGIN_EXPORT void filament_renderable_clear_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index);
FFI_PLUGIN_EXPORT void filament_renderable_set_bones(void* engine, uint32_t entity, const FilamentBone* bones, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_renderable_set_bones_matrices(void* engine, uint32_t entity, const float* transforms, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_renderable_set_skinning_buffer(void* engine, uint32_t entity, void* skinning_buffer, uint32_t count, uint32_t offset);

FFI_PLUGIN_EXPORT void filament_renderable_set_channel(void* engine, uint32_t entity, uint8_t channel);
FFI_PLUGIN_EXPORT uint8_t filament_renderable_get_channel(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_renderable_set_blend_order_at(void* engine, uint32_t entity, uint32_t primitive_index, uint16_t order);
FFI_PLUGIN_EXPORT uint16_t filament_renderable_get_blend_order_at(void* engine, uint32_t entity, uint32_t primitive_index);
FFI_PLUGIN_EXPORT void filament_renderable_set_global_blend_order_enabled_at(void* engine, uint32_t entity, uint32_t primitive_index, bool enabled);
FFI_PLUGIN_EXPORT bool filament_renderable_is_global_blend_order_enabled_at(void* engine, uint32_t entity, uint32_t primitive_index);
FFI_PLUGIN_EXPORT void filament_renderable_set_light_channel(void* engine, uint32_t entity, unsigned int channel, bool enable);
FFI_PLUGIN_EXPORT bool filament_renderable_get_light_channel(void* engine, uint32_t entity, unsigned int channel);
FFI_PLUGIN_EXPORT void filament_renderable_set_screen_space_contact_shadows(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT bool filament_renderable_is_screen_space_contact_shadows_enabled(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_renderable_set_fog_enabled(void* engine, uint32_t entity, bool enabled);
FFI_PLUGIN_EXPORT bool filament_renderable_get_fog_enabled(void* engine, uint32_t entity);

FFI_PLUGIN_EXPORT bool filament_renderable_has_component(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_instance(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_component_count(void* engine);
FFI_PLUGIN_EXPORT void filament_renderable_get_entities(void* engine, uint32_t* out_entities, uint32_t capacity);
FFI_PLUGIN_EXPORT void filament_renderable_get_axis_aligned_bounding_box(void* engine, uint32_t entity, float* out_center_halfextent);
FFI_PLUGIN_EXPORT bool filament_renderable_is_shadow_caster(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT bool filament_renderable_is_shadow_receiver(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_enabled_attributes_at(void* engine, uint32_t entity, uint32_t primitive_index);

FFI_PLUGIN_EXPORT void filament_renderable_set_morph_weights(void* engine, uint32_t entity, const float* weights, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_renderable_set_morph_target_buffer_offset_at(void* engine, uint32_t entity, uint8_t level, uint32_t primitive_index, uint32_t offset);
FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_morph_target_count(void* engine, uint32_t entity);

FFI_PLUGIN_EXPORT uint32_t filament_renderable_get_instance_count(void* engine, uint32_t entity);

FFI_PLUGIN_EXPORT void filament_renderable_destroy(void* engine, uint32_t entity);

// TransformManager
FFI_PLUGIN_EXPORT void filament_transform_create(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_transform_create_with_parent(void* engine, uint32_t entity, uint32_t parent_entity, const float* local_transform);
FFI_PLUGIN_EXPORT void filament_transform_open_local_transform_transaction(void* engine);
FFI_PLUGIN_EXPORT void filament_transform_commit_local_transform_transaction(void* engine);
FFI_PLUGIN_EXPORT void filament_transform_set_transform(void* engine, uint32_t entity, const float* matrix);
FFI_PLUGIN_EXPORT void filament_transform_get_transform(void* engine, uint32_t entity, float* out_matrix);
FFI_PLUGIN_EXPORT void filament_transform_get_world_transform(void* engine, uint32_t entity, float* out_matrix);
FFI_PLUGIN_EXPORT void filament_transform_destroy(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_transform_set_parent(void* engine, uint32_t entity, uint32_t parent_entity);
FFI_PLUGIN_EXPORT uint32_t filament_transform_get_parent(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT uint32_t filament_transform_get_child_count(void* engine, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_transform_get_children(void* engine, uint32_t entity, uint32_t* out_children, uint32_t capacity);

// Transcoder
FFI_PLUGIN_EXPORT size_t filament_transcode(
    float* target,
    const void* source,
    size_t vertex_count,
    int component_type,
    bool normalized,
    uint32_t component_count,
    size_t input_stride_bytes
);

FFI_PLUGIN_EXPORT size_t filament_transcode_output_size(
    size_t vertex_count,
    uint32_t component_count
);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_GEOMETRY_C_H
