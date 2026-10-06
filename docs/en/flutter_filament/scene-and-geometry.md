[Türkçe](../../tr/flutter_filament/scene-and-geometry.md)

# Scene and geometry

How geometry reaches the GPU: the scene, the renderable and transform managers, vertex, index, buffer, instance, morph-target and skinning buffers, native buffer ownership, tangent-space mesh generation and the filamesh format. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/buffer_descriptor_c.h`](#srcbuffer_descriptor_ch)
  - [`src/buffer_object_c.h`](#srcbuffer_object_ch)
  - [`src/filamesh_c.h`](#srcfilamesh_ch)
  - [`src/geometry_c.h`](#srcgeometry_ch)
  - [`src/index_buffer_c.h`](#srcindex_buffer_ch)
  - [`src/instance_buffer_c.h`](#srcinstance_buffer_ch)
  - [`src/instance_c.h`](#srcinstance_ch)
  - [`src/morph_target_buffer_c.h`](#srcmorph_target_buffer_ch)
  - [`src/skinning_buffer_c.h`](#srcskinning_buffer_ch)
  - [`src/tangent_space_mesh_c.h`](#srctangent_space_mesh_ch)
  - [`src/vertex_buffer_c.h`](#srcvertex_buffer_ch)
- [Dart API](#dart-api)
  - [`lib/src/buffer_descriptor.dart`](#libsrcbuffer_descriptordart)
  - [`lib/src/buffer_object.dart`](#libsrcbuffer_objectdart)
  - [`lib/src/filamesh.dart`](#libsrcfilameshdart)
  - [`lib/src/index_buffer.dart`](#libsrcindex_bufferdart)
  - [`lib/src/instance.dart`](#libsrcinstancedart)
  - [`lib/src/instance_buffer.dart`](#libsrcinstance_bufferdart)
  - [`lib/src/morph_target_buffer.dart`](#libsrcmorph_target_bufferdart)
  - [`lib/src/renderable.dart`](#libsrcrenderabledart)
  - [`lib/src/scene.dart`](#libsrcscenedart)
  - [`lib/src/skinning_buffer.dart`](#libsrcskinning_bufferdart)
  - [`lib/src/tangent_space_mesh.dart`](#libsrctangent_space_meshdart)
  - [`lib/src/transform.dart`](#libsrctransformdart)
  - [`lib/src/vertex_buffer.dart`](#libsrcvertex_bufferdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/buffer_descriptor_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_test_consume_buffer_descriptor` | `FFI_PLUGIN_EXPORT void filament_test_consume_buffer_descriptor( voi...` | Executes native Filament `filament_test_consume_buffer_descriptor` C binding. |
| `filament_test_consume_pixel_buffer_descriptor` | `FFI_PLUGIN_EXPORT void filament_test_consume_pixel_buffer_descripto...` | Executes native Filament `filament_test_consume_pixel_buffer_descriptor` C binding. |
| `filament_test_buffer_descriptor_peek` | `FFI_PLUGIN_EXPORT const void* filament_test_buffer_descriptor_peek(...` | Executes native Filament `filament_test_buffer_descriptor_peek` C binding. |

### `src/buffer_object_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_buffer_object_create` | `FFI_PLUGIN_EXPORT void* filament_buffer_object_create( void* engine...` | Allocates and initializes the native Filament `filament_buffer_object_create` resource on the engine/GPU. |
| `filament_buffer_object_set_buffer` | `FFI_PLUGIN_EXPORT void filament_buffer_object_set_buffer( void* eng...` | Updates the `filament_buffer_object_set_buffer` parameter or state in the native C layer. |
| `filament_buffer_object_get_byte_count` | `FFI_PLUGIN_EXPORT uint32_t filament_buffer_object_get_byte_count(vo...` | Queries the `filament_buffer_object_get_byte_count` state, property, or counter from the native C layer. |
| `filament_engine_destroy_buffer_object` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_buffer_object(void* ...` | Destroys the native Filament `filament_engine_destroy_buffer_object` resource and releases GPU/host memory. |

### `src/filamesh_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_material_registry_create` | `FFI_PLUGIN_EXPORT FilMaterialRegistry* filament_material_registry_c...` | Allocates and initializes the native Filament `filament_material_registry_create` resource on the engine/GPU. |
| `filament_material_registry_destroy` | `FFI_PLUGIN_EXPORT void filament_material_registry_destroy(FilMateri...` | Destroys the native Filament `filament_material_registry_destroy` resource and releases GPU/host memory. |
| `filament_material_registry_register` | `FFI_PLUGIN_EXPORT void filament_material_registry_register(FilMater...` | Executes native Filament `filament_material_registry_register` C binding. |
| `filament_material_registry_get` | `FFI_PLUGIN_EXPORT void* filament_material_registry_get(const FilMat...` | Executes native Filament `filament_material_registry_get` C binding. |
| `filament_material_registry_unregister` | `FFI_PLUGIN_EXPORT void filament_material_registry_unregister(FilMat...` | Executes native Filament `filament_material_registry_unregister` C binding. |
| `filament_material_registry_num_registered` | `FFI_PLUGIN_EXPORT size_t filament_material_registry_num_registered(...` | Executes native Filament `filament_material_registry_num_registered` C binding. |
| `filament_material_registry_get_name_at` | `FFI_PLUGIN_EXPORT const char* filament_material_registry_get_name_a...` | Queries the `filament_material_registry_get_name_at` state, property, or counter from the native C layer. |
| `filament_filamesh_load_with_registry` | `FFI_PLUGIN_EXPORT bool filament_filamesh_load_with_registry( void* ...` | Executes native Filament `filament_filamesh_load_with_registry` C binding. |
| `filament_filamesh_destroy` | `FFI_PLUGIN_EXPORT void filament_filamesh_destroy(void* engine, FilF...` | Destroys the native Filament `filament_filamesh_destroy` resource and releases GPU/host memory. |

### `src/geometry_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_mesh_reader_load_mesh_from_buffer` | `FFI_PLUGIN_EXPORT uint32_t filament_mesh_reader_load_mesh_from_buff...` | Executes native Filament `filament_mesh_reader_load_mesh_from_buffer` C binding. |
| `filament_geometry_create_suzanne_monkey_mesh` | `FFI_PLUGIN_EXPORT uint32_t filament_geometry_create_suzanne_monkey_...` | Allocates and initializes the native Filament `filament_geometry_create_suzanne_monkey_mesh` resource on the engine/GPU. |
| `filament_suzanne_sample_create` | `FFI_PLUGIN_EXPORT uint32_t filament_suzanne_sample_create( void* en...` | Allocates and initializes the native Filament `filament_suzanne_sample_create` resource on the engine/GPU. |
| `filament_suzanne_sample_destroy` | `FFI_PLUGIN_EXPORT void filament_suzanne_sample_destroy( void* engin...` | Destroys the native Filament `filament_suzanne_sample_destroy` resource and releases GPU/host memory. |
| `filament_engine_destroy_material_instance` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_material_instance(vo...` | Destroys the native Filament `filament_engine_destroy_material_instance` resource and releases GPU/host memory. |
| `filament_renderable_builder_create` | `FFI_PLUGIN_EXPORT void* filament_renderable_builder_create(uint32_t...` | Allocates and initializes the native Filament `filament_renderable_builder_create` resource on the engine/GPU. |
| `filament_renderable_builder_geometry` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_geometry_min_max` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_min_max...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_geometry_full` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_full(vo...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_geometry_no_index` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_no_inde...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_material` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_material(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_bounding_box` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_bounding_box(voi...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_culling` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_culling(void* bu...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_cast_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_cast_shadows(voi...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_receive_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_receive_shadows(...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_priority` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_priority(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_layer_mask` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_layer_mask(void*...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_skinning` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_skinning_bones` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_bones(v...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_skinning_matrices` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_matrice...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_enable_skinning_buffers` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_enable_skinning_...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_skinning_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_buffer(...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_bone_indices_and_weights` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_bone_indices_and...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_geometry_type` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_type(vo...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_channel` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_channel(void* bu...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_light_channel` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_light_channel(vo...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_blend_order` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_blend_order(void...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_global_blend_order_enabled` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_global_blend_ord...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_screen_space_contact_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_screen_space_con...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_fog` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_fog(void* builde...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_morphing` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_morphing_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_buffer(...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_morphing_offset_at` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_offset_...` | Updates the `filament_renderable_builder_morphing_offset_at` parameter or state in the native C layer. |
| `filament_renderable_builder_instances` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_instances(void* ...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_instances_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_instances_buffer...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_build` | `FFI_PLUGIN_EXPORT int32_t filament_renderable_builder_build(void* b...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderable_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_destroy(void* bu...` | Destroys the native Filament `filament_renderable_builder_destroy` resource and releases GPU/host memory. |
| `filament_renderable_create` | `FFI_PLUGIN_EXPORT void filament_renderable_create(void* engine, uin...` | Allocates and initializes the native Filament `filament_renderable_create` resource on the engine/GPU. |
| `filament_renderable_set_bounding_box` | `FFI_PLUGIN_EXPORT void filament_renderable_set_bounding_box(void* e...` | Updates the `filament_renderable_set_bounding_box` parameter or state in the native C layer. |
| `filament_renderable_set_priority` | `FFI_PLUGIN_EXPORT void filament_renderable_set_priority(void* engin...` | Updates the `filament_renderable_set_priority` parameter or state in the native C layer. |
| *... and 51 additional native C functions* | - | Library FFI bindings. |

### `src/index_buffer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_index_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_index_buffer_create( void* engine,...` | Allocates and initializes the native Filament `filament_index_buffer_create` resource on the engine/GPU. |
| `filament_index_buffer_set_buffer` | `FFI_PLUGIN_EXPORT void filament_index_buffer_set_buffer( void* engi...` | Updates the `filament_index_buffer_set_buffer` parameter or state in the native C layer. |
| `filament_index_buffer_set_data` | `FFI_PLUGIN_EXPORT void filament_index_buffer_set_data( void* engine...` | Updates the `filament_index_buffer_set_data` parameter or state in the native C layer. |
| `filament_index_buffer_get_index_count` | `FFI_PLUGIN_EXPORT uint32_t filament_index_buffer_get_index_count(vo...` | Queries the `filament_index_buffer_get_index_count` state, property, or counter from the native C layer. |
| `filament_engine_destroy_index_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_index_buffer(void* e...` | Destroys the native Filament `filament_engine_destroy_index_buffer` resource and releases GPU/host memory. |

### `src/instance_buffer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_instance_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_instance_buffer_create(void* engin...` | Allocates and initializes the native Filament `filament_instance_buffer_create` resource on the engine/GPU. |
| `filament_instance_buffer_set_local_transforms` | `FFI_PLUGIN_EXPORT void filament_instance_buffer_set_local_transform...` | Updates the `filament_instance_buffer_set_local_transforms` parameter or state in the native C layer. |
| `filament_instance_buffer_get_local_transform` | `FFI_PLUGIN_EXPORT void filament_instance_buffer_get_local_transform...` | Queries the `filament_instance_buffer_get_local_transform` state, property, or counter from the native C layer. |
| `filament_instance_buffer_get_instance_count` | `FFI_PLUGIN_EXPORT uint32_t filament_instance_buffer_get_instance_co...` | Queries the `filament_instance_buffer_get_instance_count` state, property, or counter from the native C layer. |

### `src/instance_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_transform_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_transform_manager_get_instance(...` | Queries the `filament_transform_manager_get_instance` state, property, or counter from the native C layer. |
| `filament_transform_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_transform_manager_has_component(voi...` | Validates or queries the `filament_transform_manager_has_component` state/capability. |
| `filament_transform_manager_set_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_set_transform_i( ...` | Updates the `filament_transform_manager_set_transform_i` parameter or state in the native C layer. |
| `filament_transform_manager_get_world_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_get_world_transfo...` | Queries the `filament_transform_manager_get_world_transform_i` state, property, or counter from the native C layer. |
| `filament_transform_manager_get_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_get_transform_i( ...` | Queries the `filament_transform_manager_get_transform_i` state, property, or counter from the native C layer. |
| `filament_renderable_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_renderable_manager_get_instance...` | Queries the `filament_renderable_manager_get_instance` state, property, or counter from the native C layer. |
| `filament_renderable_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_renderable_manager_has_component(vo...` | Validates or queries the `filament_renderable_manager_has_component` state/capability. |
| `filament_light_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_light_manager_get_instance(void...` | Queries the `filament_light_manager_get_instance` state, property, or counter from the native C layer. |
| `filament_light_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_light_manager_has_component(void* e...` | Validates or queries the `filament_light_manager_has_component` state/capability. |

### `src/morph_target_buffer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_morph_target_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_morph_target_buffer_create(void* e...` | Allocates and initializes the native Filament `filament_morph_target_buffer_create` resource on the engine/GPU. |
| `filament_morph_target_buffer_set_positions_at_float3` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_a...` | Updates the `filament_morph_target_buffer_set_positions_at_float3` parameter or state in the native C layer. |
| `filament_morph_target_buffer_set_positions_at_float4` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_a...` | Updates the `filament_morph_target_buffer_set_positions_at_float4` parameter or state in the native C layer. |
| `filament_morph_target_buffer_set_tangents_at` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_tangents_at...` | Updates the `filament_morph_target_buffer_set_tangents_at` parameter or state in the native C layer. |
| `filament_morph_target_buffer_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_vertex_...` | Queries the `filament_morph_target_buffer_get_vertex_count` state, property, or counter from the native C layer. |
| `filament_morph_target_buffer_get_count` | `FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_count(v...` | Queries the `filament_morph_target_buffer_get_count` state, property, or counter from the native C layer. |
| `filament_morph_target_buffer_has_positions` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_positions(v...` | Queries the `filament_morph_target_buffer_has_positions` state, property, or counter from the native C layer. |
| `filament_morph_target_buffer_has_tangents` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_tangents(vo...` | Queries the `filament_morph_target_buffer_has_tangents` state, property, or counter from the native C layer. |
| `filament_morph_target_buffer_is_custom_morphing_enabled` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_is_custom_morph...` | Queries the `filament_morph_target_buffer_is_custom_morphing_enabled` state, property, or counter from the native C layer. |

### `src/skinning_buffer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_skinning_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_skinning_buffer_create(void* engin...` | Allocates and initializes the native Filament `filament_skinning_buffer_create` resource on the engine/GPU. |
| `filament_skinning_buffer_set_bones` | `FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones(void* eng...` | Updates the `filament_skinning_buffer_set_bones` parameter or state in the native C layer. |
| `filament_skinning_buffer_set_bones_matrices` | `FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones_matrices(...` | Updates the `filament_skinning_buffer_set_bones_matrices` parameter or state in the native C layer. |
| `filament_skinning_buffer_get_bone_count` | `FFI_PLUGIN_EXPORT uint32_t filament_skinning_buffer_get_bone_count(...` | Queries the `filament_skinning_buffer_get_bone_count` state, property, or counter from the native C layer. |
| `filament_engine_destroy_skinning_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_skinning_buffer(void...` | Destroys the native Filament `filament_engine_destroy_skinning_buffer` resource and releases GPU/host memory. |

### `src/tangent_space_mesh_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_tsm_builder_create` | `FFI_PLUGIN_EXPORT FilTsmBuilder* filament_tsm_builder_create(void);` | Allocates and initializes the native Filament `filament_tsm_builder_create` resource on the engine/GPU. |
| `filament_tsm_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_destroy(FilTsmBuilder* b);` | Destroys the native Filament `filament_tsm_builder_destroy` resource and releases GPU/host memory. |
| `filament_tsm_builder_vertex_count` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_vertex_count(FilTsmBuil...` | Executes native Filament `filament_tsm_builder_vertex_count` C binding. |
| `filament_tsm_builder_normals` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_normals(FilTsmBuilder* ...` | Executes native Filament `filament_tsm_builder_normals` C binding. |
| `filament_tsm_builder_tangents` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_tangents(FilTsmBuilder*...` | Executes native Filament `filament_tsm_builder_tangents` C binding. |
| `filament_tsm_builder_uvs` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_uvs(FilTsmBuilder* b, c...` | Executes native Filament `filament_tsm_builder_uvs` C binding. |
| `filament_tsm_builder_positions` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_positions(FilTsmBuilder...` | Executes native Filament `filament_tsm_builder_positions` C binding. |
| `filament_tsm_builder_triangle_count` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangle_count(FilTsmBu...` | Executes native Filament `filament_tsm_builder_triangle_count` C binding. |
| `filament_tsm_builder_triangles_uint3` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_uint3(FilTsmB...` | Executes native Filament `filament_tsm_builder_triangles_uint3` C binding. |
| `filament_tsm_builder_triangles_ushort3` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_ushort3(FilTs...` | Executes native Filament `filament_tsm_builder_triangles_ushort3` C binding. |
| `filament_tsm_builder_aux` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_aux(FilTsmBuilder* b, i...` | Executes native Filament `filament_tsm_builder_aux` C binding. |
| `filament_tsm_builder_algorithm` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_algorithm(FilTsmBuilder...` | Executes native Filament `filament_tsm_builder_algorithm` C binding. |
| `filament_tsm_builder_build` | `FFI_PLUGIN_EXPORT FilTangentSpaceMesh* filament_tsm_builder_build(F...` | Executes native Filament `filament_tsm_builder_build` C binding. |
| `filament_tsm_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_vertex_count(const FilT...` | Queries the `filament_tsm_get_vertex_count` state, property, or counter from the native C layer. |
| `filament_tsm_get_triangle_count` | `FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_triangle_count(const Fi...` | Queries the `filament_tsm_get_triangle_count` state, property, or counter from the native C layer. |
| `filament_tsm_remeshed` | `FFI_PLUGIN_EXPORT bool filament_tsm_remeshed(const FilTangentSpaceM...` | Executes native Filament `filament_tsm_remeshed` C binding. |
| `filament_tsm_get_positions` | `FFI_PLUGIN_EXPORT void filament_tsm_get_positions(const FilTangentS...` | Queries the `filament_tsm_get_positions` state, property, or counter from the native C layer. |
| `filament_tsm_get_uvs` | `FFI_PLUGIN_EXPORT void filament_tsm_get_uvs(const FilTangentSpaceMe...` | Queries the `filament_tsm_get_uvs` state, property, or counter from the native C layer. |
| `filament_tsm_get_quats_float4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_float4(const FilTange...` | Queries the `filament_tsm_get_quats_float4` state, property, or counter from the native C layer. |
| `filament_tsm_get_quats_short4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_short4(const FilTange...` | Queries the `filament_tsm_get_quats_short4` state, property, or counter from the native C layer. |
| `filament_tsm_get_quats_half4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_half4(const FilTangen...` | Queries the `filament_tsm_get_quats_half4` state, property, or counter from the native C layer. |
| `filament_tsm_get_triangles_uint3` | `FFI_PLUGIN_EXPORT void filament_tsm_get_triangles_uint3(const FilTa...` | Queries the `filament_tsm_get_triangles_uint3` state, property, or counter from the native C layer. |
| `filament_tsm_get_aux` | `FFI_PLUGIN_EXPORT void filament_tsm_get_aux(const FilTangentSpaceMe...` | Queries the `filament_tsm_get_aux` state, property, or counter from the native C layer. |
| `filament_tsm_destroy` | `FFI_PLUGIN_EXPORT void filament_tsm_destroy(FilTangentSpaceMesh* m);` | Destroys the native Filament `filament_tsm_destroy` resource and releases GPU/host memory. |

### `src/vertex_buffer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_vertex_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create( void* engine...` | Allocates and initializes the native Filament `filament_vertex_buffer_create` resource on the engine/GPU. |
| `filament_vertex_buffer_create_legacy` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_legacy(void* ...` | Allocates and initializes the native Filament `filament_vertex_buffer_create_legacy` resource on the engine/GPU. |
| `filament_vertex_buffer_create_with_color` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_color(vo...` | Allocates and initializes the native Filament `filament_vertex_buffer_create_with_color` resource on the engine/GPU. |
| `filament_vertex_buffer_create_with_uv` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_uv(void*...` | Allocates and initializes the native Filament `filament_vertex_buffer_create_with_uv` resource on the engine/GPU. |
| `filament_vertex_buffer_set_buffer_at` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_at( void* ...` | Updates the `filament_vertex_buffer_set_buffer_at` parameter or state in the native C layer. |
| `filament_vertex_buffer_set_data` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_data( void* engin...` | Updates the `filament_vertex_buffer_set_data` parameter or state in the native C layer. |
| `filament_vertex_buffer_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_vertex_buffer_get_vertex_count(...` | Queries the `filament_vertex_buffer_get_vertex_count` state, property, or counter from the native C layer. |
| `filament_vertex_buffer_set_buffer_object_at` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_object_at(...` | Updates the `filament_vertex_buffer_set_buffer_object_at` parameter or state in the native C layer. |
| `filament_engine_destroy_vertex_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_vertex_buffer(void* ...` | Destroys the native Filament `filament_engine_destroy_vertex_buffer` resource and releases GPU/host memory. |

## Dart API

### `lib/src/buffer_descriptor.dart`

#### `class NativeBuffer`

A contiguous native memory buffer allocated on the C heap for zero-copy transfers to Filament.

**Constructors:**
- `NativeBuffer._(this.pointer, this.sizeInBytes, this._view)`: Initializes `NativeBuffer._(this.pointer, this.sizeInBytes, this._view)`.
- `NativeBuffer.allocate(int byteCount)`: Allocates [byteCount] bytes of native memory using `calloc`.
- `NativeBuffer.copy(Uint8List source)`: Allocates native memory and copies [source] bytes into it.
- `NativeBuffer.fromTypedData(TypedData source)`: Allocates native memory and copies any [TypedData] into it.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sizeInBytes` | `int sizeInBytes` | Holds the `sizeInBytes` property or configuration state. |
| `asTypedList` | `Uint8List get asTypedList` | Returns a Dart [Uint8List] view pointing directly to the allocated native memory.  Throws a [StateError] if this buffer has already been released or freed. |
| `address` | `int get address` | The raw native address of this buffer. |
| `isReleased` | `bool get isReleased` | Whether this buffer has been released / freed. |
| `free` | `void free()` | Frees the allocated native memory. Safe to call multiple times (idempotent). |

#### `class _BufferEntry`

`_BufferEntry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `keepAlive` | `Object keepAlive` | Holds the `keepAlive` property or configuration state. |
| `completer` | `Completer<void> completer` | Holds the `completer` property or configuration state. |

#### `class BufferOwnershipRegistry`

Central registry managing buffer ownership and release callbacks from Filament's backend.

**Constructors:**
- `BufferOwnershipRegistry._()`: Initializes `BufferOwnershipRegistry._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `whenReleased` | `Future<void> whenReleased(int token)` | Returns a [Future] that completes when the GPU backend has finished processing the buffer associated with [token] and released it. |
| `pendingCount` | `int get pendingCount` | The number of buffers currently awaiting GPU release. |
| `dispose` | `void dispose()` | Disposes the native callback listener. |

### `lib/src/buffer_object.dart`

#### `enum BufferObjectBindingType`

Distinguishes between buffer object bindings (e.g., vertex, uniform, SSBO).

**Constructors:**
- `BufferObjectBindingType(this.value)`: Initializes `BufferObjectBindingType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shaderStorage` | `shaderStorage(2)` | Executes `shaderStorage` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class FilamentBufferObject`

A generic GPU buffer containing data for sharing between multiple VertexBuffer instances.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `byteCount` | `int get byteCount` | Maximum number of bytes this BufferObject can hold. |
| `bindingType` | `BufferObjectBindingType get bindingType` | The binding type of this BufferObject. |
| `dispose` | `void dispose()` | Destroys this BufferObject. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/filamesh.dart`

#### `class MaterialRegistry`

Registry of named [FilamentMaterialInstance]s used when loading .filamesh models.

**Constructors:**
- `MaterialRegistry() : _handle = c.filament_material_registry_create()`: Initializes `MaterialRegistry() : _handle = c.filament_material_registry_create()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `register` | `void register(String name, FilamentMaterialInstance materialInstance)` | Registers a [FilamentMaterialInstance] with a given submesh [name]. |
| `getMaterialInstance` | `FilamentMaterialInstance? getMaterialInstance(String name)` | Gets the registered [FilamentMaterialInstance] for [name], or null if not registered. |
| `unregister` | `void unregister(String name)` | Unregisters the material instance associated with [name]. |
| `numRegistered` | `int get numRegistered` | Number of registered materials in this registry. |
| `names` | `List<String> get names` | Returns the list of all registered material names. |
| `destroy` | `void destroy()` | Destroys the native registry handle.  Note: The registry does NOT own the underlying [FilamentMaterialInstance]s; destroying the registry leaves the material instances intact. |

#### `class FilameshMesh`

Represents a loaded .filamesh mesh containing a renderable entity, vertex buffer, and index buffer.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `renderable` | `int get renderable` | The renderable entity ID. |
| `vertexBuffer` | `int get vertexBuffer` | The native handle pointer value of the underlying [VertexBuffer]. |
| `indexBuffer` | `int get indexBuffer` | The native handle pointer value of the underlying [IndexBuffer]. |
| `destroy` | `void destroy()` | Destroys the renderable entity, vertex buffer, and index buffer in proper engine order. |

### `lib/src/index_buffer.dart`

#### `class FilamentIndexBuffer`

A buffer holding index data defining triangle or line primitives.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `indexCount` | `int get indexCount` | Number of indices this buffer can hold. |
| `type` | `IndexType get type` | The element type of the indices (ushort or uint). |
| `byteCapacity` | `int get byteCapacity` | Total capacity in bytes for this IndexBuffer. |
| `setUint16Data` | `void setUint16Data(Uint16List data)` | Sets 16-bit short index data (backward-compatible convenience). |
| `setUint32Data` | `void setUint32Data(Uint32List data)` | Sets 32-bit int index data (backward-compatible convenience). |
| `dispose` | `void dispose()` | Destroys this IndexBuffer. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/instance.dart`

#### `extension type const`

Zero-cost extension type representing a fast, cached `TransformManager::Instance` handle.  Instance handles avoid repeated entity-to-component hash map lookups inside high-frequency frame loops. An instance handle is valid within a frame but may be invalidated across component additions / deletions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid transform component (non-zero). |

#### `extension type const`

Zero-cost extension type representing a fast `RenderableManager::Instance` handle.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid renderable component (non-zero). |

#### `extension type const`

Zero-cost extension type representing a fast `LightManager::Instance` handle.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid light component (non-zero). |

### `lib/src/instance_buffer.dart`

**Top-level Functions:**

- **`Float32List packMatrices(List<Matrix4> matrices)`**: Helper to pack a list of [Matrix4] objects into a contiguous column-major [Float32List] of length 16 * N.

#### `class InstanceBuffer`

Holds GPU draw instance transforms for GPU instancing.

**Constructors:**
- `InstanceBuffer._(this._nativeBuffer, this.engine, this._instanceCount)`: Initializes `InstanceBuffer._(this._nativeBuffer, this.engine, this._instanceCount)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `getLocalTransform` | `Matrix4 getLocalTransform(int index)` | Returns the local transform for instance at [index]. |
| `instanceCount` | `int get instanceCount` | Returns the instance capacity of this buffer. |
| `isDisposed` | `bool get isDisposed` | Whether this buffer has been disposed. |
| `destroy` | `void destroy() => dispose()` | Destroys the InstanceBuffer. |
| `dispose` | `void dispose()` | Destroys the InstanceBuffer. |

### `lib/src/morph_target_buffer.dart`

**Top-level Functions:**

- **`Int16List packTangentFrame(dynamic q)`**: Packs a quaternion (or 4D tangent frame) into an [Int16List] of 4 snorm16 values.  Symmetric packaging matching Filament's `norm.h`.

#### `class MorphTargetBuffer`

A container for vertex morphing data that supports both automatic and manual morphing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Returns the vertex count of this buffer. |
| `count` | `int get count` | Returns the target count of this buffer. |
| `hasPositions` | `bool get hasPositions` | Whether position morphing is enabled on this buffer. |
| `hasTangents` | `bool get hasTangents` | Whether tangent morphing is enabled on this buffer. |
| `isCustomMorphingEnabled` | `bool get isCustomMorphingEnabled` | Whether custom morphing is enabled on this buffer. |
| `isDisposed` | `bool get isDisposed` | Whether this buffer has been disposed. |
| `destroy` | `void destroy() => dispose()` | Destroys the MorphTargetBuffer. |
| `dispose` | `void dispose()` | Destroys the MorphTargetBuffer. |

### `lib/src/renderable.dart`

#### `extension BoneExt`

Helper for constructing Bone instances.

#### `class RenderableBuilder`

Builder for creating multi-primitive renderables.

**Constructors:**
- `RenderableBuilder(int primitiveCount) : _builder = c.filament_renderable_builder_create(primitiveCount)`: Initializes `RenderableBuilder(int primitiveCount) : _builder = c.filament_renderable_builder_create(primitiveCount)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `geometryType` | `void geometryType(GeometryType type)` | Sets the optimization hint for this renderable's geometry. Note: With `GeometryType.static_`, Filament makes optimization assumptions. Binding a different buffer later is undefined. |
| `material` | `void material(int index, FilamentMaterialInstance mi)` | Assigns a [materialInstance] to the primitive at [index]. |
| `boundingBox` | `void boundingBox(double minX, double minY, double minZ, double maxX, dou...` | Sets the axis-aligned bounding box. Mandatory if culling is enabled! |
| `culling` | `void culling(bool enabled)` | Executes `culling` operation. |
| `castShadows` | `void castShadows(bool enabled)` | Executes `castShadows` operation. |
| `receiveShadows` | `void receiveShadows(bool enabled)` | Executes `receiveShadows` operation. |
| `priority` | `void priority(int priority)` | Executes `priority` operation. |
| `layerMask` | `void layerMask(int select, int mask)` | Executes `layerMask` operation. |
| `channel` | `void channel(int channel)` | Sets the render channel (0..7) this renderable is associated to. |
| `lightChannel` | `void lightChannel(int channel, bool enable)` | Enables or disables a light channel (0..7). |
| `blendOrder` | `void blendOrder(int primitiveIndex, int order)` | Sets drawing order for blended primitives (0..65535). |
| `globalBlendOrderEnabled` | `void globalBlendOrderEnabled(int primitiveIndex, bool enabled)` | Sets whether the blend order is global or local (default) to this renderable. |
| `screenSpaceContactShadows` | `void screenSpaceContactShadows(bool enabled)` | Enables or disables screen-space contact shadows. |
| `fog` | `void fog(bool enabled)` | Enables or disables large-scale fog application to this renderable. |
| `morphing` | `void morphing(int targetCount)` | Configures morphing for [targetCount] targets. |
| `morphingBuffer` | `void morphingBuffer(dynamic morphTargetBuffer)` | Associates a MorphTargetBuffer to this renderable. |
| `instances` | `void instances(int count, [dynamic instanceBuffer])` | Specifies draw instance count (1..32767) optionally with an [instanceBuffer]. |
| `skinning` | `void skinning(int boneCount)` | Configures skinning for [boneCount] bones. |
| `enableSkinningBuffers` | `void enableSkinningBuffers(bool enabled)` | Enables advanced skinning buffers. Must be called if boneIndicesAndWeights is used. |
| `build` | `void build(FilamentEngine engine, int entity)` | Builds the renderable component onto [entity].  Throws [FilamentException] if the build fails (e.g., missing geometry). |
| `destroy` | `void destroy()` | Cancels the build and frees the underlying handle. |

#### `class FilamentRenderableManager`

`FilamentRenderableManager`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FilamentRenderableManager(this.engine)`: Creates a renderable manager wrapper.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `getInstance` | `RenderableInstance getInstance(int entity)` | Resolves an entity ID to its cached [RenderableInstance] handle. |
| `hasComponent` | `bool hasComponent(int entity)` | Whether [entity] has a renderable component. |
| `componentCount` | `int get componentCount` | Number of renderable components managed by the engine. |
| `entities` | `List<int> get entities` | All entities with a renderable component. |
| `getPrimitiveCount` | `int getPrimitiveCount(int entity)` | Gets the primitive count for the given [entity]. |
| `getMaterialInstanceAt` | `FilamentMaterialInstance? getMaterialInstanceAt(int entity, int primitiv...` | Gets the [FilamentMaterialInstance] bound at [primitiveIndex] on [entity]. Note: Returns a borrowed instance. You should not rely on it outliving the entity. |
| `clearMaterialInstanceAt` | `void clearMaterialInstanceAt(int entity, int primitiveIndex)` | Clears the material instance bound at [primitiveIndex] on [entity], returning it to the default material. |
| `createSuzanneMonkeyMesh` | `int createSuzanneMonkeyMesh(FilamentMaterialInstance materialInstance)` | Creates the official 3D Suzanne Monkey Head mesh renderable. |
| `getAxisAlignedBoundingBox` | `Box getAxisAlignedBoundingBox(int entity)` | Gets the axis-aligned bounding box for [entity]. |
| `setPriority` | `void setPriority(int entity, int priority)` | Sets the rendering priority of [entity] (0..7, where 7 renders first / behind). |
| `setCulling` | `void setCulling(int entity, bool enabled)` | Enables or disables frustum culling for [entity]. |
| `setCastShadows` | `void setCastShadows(int entity, bool enabled)` | Enables or disables shadow casting for [entity]. |
| `setRayTracingVisible` | `void setRayTracingVisible(int entity, bool visible)` | Whether the geometry of [entity] is part of the ray tracing acceleration structures of its scene (default true). |
| `isRayTracingVisible` | `bool isRayTracingVisible(int entity)` | Checks if [entity] is part of the ray tracing acceleration structures. |
| `isShadowCaster` | `bool isShadowCaster(int entity) => c.filament_renderable_is_shadow_caste...` | Checks if [entity] casts shadows. |
| `setReceiveShadows` | `void setReceiveShadows(int entity, bool enabled)` | Enables or disables receiving shadows for [entity]. |
| `isShadowReceiver` | `bool isShadowReceiver(int entity) => c.filament_renderable_is_shadow_rec...` | Checks if [entity] receives shadows. |
| `setLayerMask` | `void setLayerMask(int entity, int select, int mask)` | Sets the 8-bit layer mask for [entity]. |
| `setChannel` | `void setChannel(int entity, int channel)` | Sets the render channel (0..7) of [entity]. |
| `getChannel` | `int getChannel(int entity)` | Gets the render channel of [entity]. |
| `setBlendOrderAt` | `void setBlendOrderAt(int entity, int primitiveIndex, int order)` | Sets the blend order for primitive at [primitiveIndex] on [entity]. |
| `getBlendOrderAt` | `int getBlendOrderAt(int entity, int primitiveIndex)` | Gets the blend order for primitive at [primitiveIndex] on [entity]. |
| `setGlobalBlendOrderEnabledAt` | `void setGlobalBlendOrderEnabledAt(int entity, int primitiveIndex, bool e...` | Sets whether the blend order is global or local for primitive at [primitiveIndex] on [entity]. |
| `isGlobalBlendOrderEnabledAt` | `bool isGlobalBlendOrderEnabledAt(int entity, int primitiveIndex)` | Gets whether the blend order is global for primitive at [primitiveIndex] on [entity]. |
| `setLightChannel` | `void setLightChannel(int entity, int channel, bool enable)` | Enables or disables light channel [channel] (0..7) on [entity]. |
| `getLightChannel` | `bool getLightChannel(int entity, int channel)` | Gets whether light channel [channel] is enabled on [entity]. |
| `setScreenSpaceContactShadows` | `void setScreenSpaceContactShadows(int entity, bool enabled)` | Enables or disables screen-space contact shadows on [entity]. |
| `isScreenSpaceContactShadowsEnabled` | `bool isScreenSpaceContactShadowsEnabled(int entity)` | Checks if screen-space contact shadows are enabled on [entity]. |
| `setFogEnabled` | `void setFogEnabled(int entity, bool enabled)` | Enables or disables large-scale fog on [entity]. |
| `getFogEnabled` | `bool getFogEnabled(int entity)` | Gets whether large-scale fog is enabled on [entity]. |
| `getEnabledAttributesAt` | `Set<VertexAttribute> getEnabledAttributesAt(int entity, int primitiveIndex)` | Gets the set of enabled VertexAttributes at [primitiveIndex] for [entity]. |
| `getMorphTargetCount` | `int getMorphTargetCount(int entity)` | Gets the number of morph targets for [entity]. |
| `getInstanceCount` | `int getInstanceCount(int entity)` | Gets the number of draw instances for [entity]. |
| `setMaterialInstanceAt` | `void setMaterialInstanceAt(int entity, int primitiveIndex, FilamentMater...` | Binds a [materialInstance] to the primitive index of [entity]. |
| `destroy` | `void destroy(int entity)` | Destroys the renderable component of [entity]. |

### `lib/src/scene.dart`

#### `class FilamentScene`

A Scene is a flat container of Renderable and Light instances.  Renderables and Lights must be added to a Scene to be rendered.

**Constructors:**
- `FilamentScene.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `createSuzanneSample` | `int createSuzanneSample(FilamentView view)` | Populates this scene with the official Filament 3D Suzanne Monkey model, including all 5 PBR KTX2 textures (Albedo, AO, Metallic, Roughness, Normal Map). |
| `destroySuzanneSample` | `void destroySuzanneSample()` | Destroys all Suzanne 3D sample resources cleanly before engine disposal. |
| `addEntity` | `void addEntity(int entity)` | Adds an entity to this scene.  The entity is ignored for rendering purposes if it doesn't have a Renderable or Light component. |
| `addEntities` | `void addEntities(List<int> entities)` | Adds a list of entities to the scene in a single batch FFI call. |
| `removeEntity` | `void removeEntity(int entity)` | Removes an entity from this scene. |
| `removeEntities` | `void removeEntities(List<int> entities)` | Removes a list of entities from the scene in a single batch FFI call. |
| `removeAllEntities` | `void removeAllEntities()` | Removes all entities from the scene. |
| `hasEntity` | `bool hasEntity(int entity)` | Returns true if the given entity is present in the scene. |
| `rayTracingEnabled` | `bool rayTracingEnabled` (get/set) | Keeps ray tracing acceleration structures for the scene, rebuilt every rendered frame; needs `FilamentEngine.supportsRayQuery` (see [Ray tracing](ray-tracing.md)). Default false. |
| `tlasInstanceCount` | `int get tlasInstanceCount` | Renderables in the top-level acceleration structure after the last frame (0 while off or unsupported). |
| `lastTlasBuildTime` | `Duration get lastTlasBuildTime` | GPU time of the last top-level structure build (`Duration.zero` until a timer query resolved). |
| `traceVisibility` | `Future<RayHit?> traceVisibility(double ox, double oy, double oz, double dx, double dy, double dz, {double maxDistance = 1.0e5})` | Test hook: traces one visibility ray through a temporary 1x1 view and waits for the answer; `null` on a miss or without ray tracing. Call it between frames. |
| `setIndirectLight` | `void setIndirectLight(FilamentIndirectLight? indirectLight)` | Sets the Image-Based Lighting (IBL) IndirectLight for this scene. |
| `indirectLight` | `FilamentIndirectLight? get indirectLight` | The currently attached [FilamentIndirectLight], or null if none is set. |
| `indirectLight` | `indirectLight(FilamentIndirectLight? value) => setIndirectLight(value)` | Executes `indirectLight` operation. |
| `setSkybox` | `void setSkybox(FilamentSkybox? skybox)` | Sets the background Skybox for this scene. |
| `skybox` | `FilamentSkybox? get skybox` | The currently attached [FilamentSkybox], or null if none is set. |
| `skybox` | `skybox(FilamentSkybox? value) => setSkybox(value)` | Executes `skybox` operation. |
| `entityCount` | `int get entityCount` | Returns the total number of entities in this scene. |
| `renderableCount` | `int get renderableCount` | Returns the number of active renderable objects in this scene. |
| `lightCount` | `int get lightCount` | Returns the number of active light objects in this scene. |
| `dispose` | `void dispose()` | Destroys this scene and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/skinning_buffer.dart`

#### `class SkinningBuffer`

`SkinningBuffer`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SkinningBuffer._(this._nativeBuffer, this.engine, this._boneCount)`: Initializes `SkinningBuffer._(this._nativeBuffer, this.engine, this._boneCount)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `boneCount` | `int get boneCount` | Returns the (rounded) capacity of the buffer. |
| `destroy` | `void destroy()` | Destroys the SkinningBuffer. |

### `lib/src/tangent_space_mesh.dart`

#### `enum TsmAlgorithm`

The algorithm used to generate the tangent space.

**Constructors:**
- `TsmAlgorithm(this.value)`: Initializes `TsmAlgorithm(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frisvad` | `frisvad(4)` | Frisvad's method (requires normals). |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum TsmAuxAttribute`

Auxiliary attributes that can be provided and will be properly mapped if remeshed.

**Constructors:**
- `TsmAuxAttribute(this.value)`: Initializes `TsmAuxAttribute(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `weights` | `weights(3)` | Executes `weights` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum _TsmAuxType`

Internal data types for auxiliary attributes.

**Constructors:**
- `_TsmAuxType(this.value)`: Initializes `_TsmAuxType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ushort4` | `ushort4(4)` | Executes `ushort4` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class TangentSpaceMeshBuilder`

Builds a [TangentSpaceMesh].

**Constructors:**
- `TangentSpaceMeshBuilder() : _builder = c.filament_tsm_builder_create()`: Initializes `TangentSpaceMeshBuilder() : _builder = c.filament_tsm_builder_create()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vertexCount` | `void vertexCount(int count)` | Executes `vertexCount` operation. |
| `triangleCount` | `void triangleCount(int count)` | Executes `triangleCount` operation. |
| `trianglesUint` | `void trianglesUint(Uint32List tris)` | Executes `trianglesUint` operation. |
| `trianglesUshort` | `void trianglesUshort(Uint16List tris)` | Executes `trianglesUshort` operation. |
| `algorithm` | `void algorithm(TsmAlgorithm algo)` | Executes `algorithm` operation. |
| `build` | `TangentSpaceMesh build()` | Constructs and returns the declarative element or widget hierarchy. |

#### `class TangentSpaceMesh`

The generated tangent space mesh.

**Constructors:**
- `TangentSpaceMesh._(this._ptr)`: Initializes `TangentSpaceMesh._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |
| `remeshed` | `bool get remeshed` | Getter accessor returning the current value of `remeshed`. |
| `getTrianglesUint32` | `Uint32List getTrianglesUint32()` | Queries and returns the `TrianglesUint32` value or child object. |
| `destroy` | `void destroy()` | Releases and safely disposes the specified `` resource. |

### `lib/src/transform.dart`

#### `class FilamentTransformManager`

Manages transform components for entities.  Transform components give entities a position and orientation in space.

**Constructors:**
- `FilamentTransformManager(this.engine)`: Creates a transform manager wrapper for [engine].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `transaction` | `void transaction(void Function() body)` | Executes [body] synchronously inside an open local-transform transaction.  During the transaction, local transform updates are batched without recomputing world transforms on every call, avoiding $O(\text{depth})$ cost per update. When [body] finishes (or throws), the transaction is automatically committed.  Nested calls to [transaction] are rejected with a [StateError]. |
| `getInstance` | `TransformInstance getInstance(int entity)` | Resolves an entity ID to its cached [TransformInstance] handle.  Returns an invalid instance ([TransformInstance.isValid] == false) if the entity has no transform component. |
| `hasComponent` | `bool hasComponent(int entity)` | Whether [entity] has a transform component. |
| `setTransform` | `void setTransform(int entity, List<double> matrix16)` | Sets the local transform matrix of [entity] using a 16-element column-major matrix array. |
| `setTransformAt` | `void setTransformAt(TransformInstance instance, List<double> matrix16)` | Sets the local transform matrix directly via a fast cached [TransformInstance] handle. |
| `getTransformAt` | `List<double> getTransformAt(TransformInstance instance)` | Gets the local transform matrix directly via a fast cached [TransformInstance] handle. |
| `getTransform` | `List<double> getTransform(int entity)` | Gets the local transform matrix of [entity] as a 16-element column-major matrix array. |
| `getWorldTransform` | `List<double> getWorldTransform(int entity)` | Gets the world transform matrix of [entity] as a 16-element column-major matrix array. |
| `worldTransformAt` | `List<double> worldTransformAt(TransformInstance instance)` | Gets the world transform matrix directly via a fast cached [TransformInstance] handle. |
| `destroy` | `void destroy(int entity)` | Destroys the transform component for [entity]. |
| `setParent` | `void setParent(int entity, int parentEntity)` | Sets the parent entity of [entity]'s transform component. Pass [parentEntity] as 0 to unparent (make a root). |
| `getParent` | `int getParent(int entity)` | Gets the parent entity ID of [entity]'s transform, or 0 if it has no parent. |
| `childCount` | `int childCount(int entity)` | Gets the number of children attached to [entity]'s transform. |
| `getChildren` | `List<int> getChildren(int entity, int capacity)` | Gets a list of children entities attached to [entity]'s transform. The list will be clamped to [capacity] elements. |

### `lib/src/vertex_buffer.dart`

#### `class VertexAttributeDesc`

Description of a vertex attribute within a [FilamentVertexBuffer].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `attribute` | `VertexAttribute attribute` | Holds the `attribute` property or configuration state. |
| `bufferIndex` | `int bufferIndex` | Holds the `bufferIndex` property or configuration state. |
| `type` | `AttributeType type` | Holds the `type` property or configuration state. |
| `byteOffset` | `int byteOffset` | Holds the `byteOffset` property or configuration state. |
| `byteStride` | `int byteStride` | Holds the `byteStride` property or configuration state. |
| `normalized` | `bool normalized` | Holds the `normalized` property or configuration state. |

#### `class FilamentVertexBuffer`

A buffer holding vertex data (positions, normals, UVs, colors, etc.).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vertexCount` | `int get vertexCount` | Number of vertices in each buffer slot. |
| `bufferCount` | `int get bufferCount` | Number of buffer slots. |
| `enableBufferObjects` | `bool get enableBufferObjects` | Whether buffer object mode is enabled. |
| `attributes` | `List<VertexAttributeDesc> get attributes` | The attribute descriptions for this vertex buffer. |
| `dispose` | `void dispose()` | Destroys this VertexBuffer. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

---

[Previous: View options and color grading](view-options.md) | [Up: flutter_filament](index.md) | [Next: Camera and manipulator](camera-and-manipulator.md)
