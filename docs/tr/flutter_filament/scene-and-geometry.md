[English](../../en/flutter_filament/scene-and-geometry.md)

# Sahne ve geometri

Geometrinin GPU'ya nasıl ulaştığı: sahne, renderable ve transform manager'ları, vertex, index, buffer, instance, morph-target ve skinning buffer'ları, native buffer sahipliği, tangent-space mesh üretimi ve filamesh formatı. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
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

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/buffer_descriptor_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_test_consume_buffer_descriptor` | `FFI_PLUGIN_EXPORT void filament_test_consume_buffer_descriptor( voi...` | Filament yerel `filament_test_consume_buffer_descriptor` C fonksiyonunu çalıştırır. |
| `filament_test_consume_pixel_buffer_descriptor` | `FFI_PLUGIN_EXPORT void filament_test_consume_pixel_buffer_descripto...` | Filament yerel `filament_test_consume_pixel_buffer_descriptor` C fonksiyonunu çalıştırır. |
| `filament_test_buffer_descriptor_peek` | `FFI_PLUGIN_EXPORT const void* filament_test_buffer_descriptor_peek(...` | Filament yerel `filament_test_buffer_descriptor_peek` C fonksiyonunu çalıştırır. |

### `src/buffer_object_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_buffer_object_create` | `FFI_PLUGIN_EXPORT void* filament_buffer_object_create( void* engine...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_buffer_object_set_buffer` | `FFI_PLUGIN_EXPORT void filament_buffer_object_set_buffer( void* eng...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_buffer_object_get_byte_count` | `FFI_PLUGIN_EXPORT uint32_t filament_buffer_object_get_byte_count(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_destroy_buffer_object` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_buffer_object(void* ...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/filamesh_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_material_registry_create` | `FFI_PLUGIN_EXPORT FilMaterialRegistry* filament_material_registry_c...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_registry_destroy` | `FFI_PLUGIN_EXPORT void filament_material_registry_destroy(FilMateri...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_material_registry_register` | `FFI_PLUGIN_EXPORT void filament_material_registry_register(FilMater...` | Filament yerel `filament_material_registry_register` C fonksiyonunu çalıştırır. |
| `filament_material_registry_get` | `FFI_PLUGIN_EXPORT void* filament_material_registry_get(const FilMat...` | Filament yerel `filament_material_registry_get` C fonksiyonunu çalıştırır. |
| `filament_material_registry_unregister` | `FFI_PLUGIN_EXPORT void filament_material_registry_unregister(FilMat...` | Filament yerel `filament_material_registry_unregister` C fonksiyonunu çalıştırır. |
| `filament_material_registry_num_registered` | `FFI_PLUGIN_EXPORT size_t filament_material_registry_num_registered(...` | Filament yerel `filament_material_registry_num_registered` C fonksiyonunu çalıştırır. |
| `filament_material_registry_get_name_at` | `FFI_PLUGIN_EXPORT const char* filament_material_registry_get_name_a...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_filamesh_load_with_registry` | `FFI_PLUGIN_EXPORT bool filament_filamesh_load_with_registry( void* ...` | Filament yerel `filament_filamesh_load_with_registry` C fonksiyonunu çalıştırır. |
| `filament_filamesh_destroy` | `FFI_PLUGIN_EXPORT void filament_filamesh_destroy(void* engine, FilF...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/geometry_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_mesh_reader_load_mesh_from_buffer` | `FFI_PLUGIN_EXPORT uint32_t filament_mesh_reader_load_mesh_from_buff...` | Filament yerel `filament_mesh_reader_load_mesh_from_buffer` C fonksiyonunu çalıştırır. |
| `filament_geometry_create_suzanne_monkey_mesh` | `FFI_PLUGIN_EXPORT uint32_t filament_geometry_create_suzanne_monkey_...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_suzanne_sample_create` | `FFI_PLUGIN_EXPORT uint32_t filament_suzanne_sample_create( void* en...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_suzanne_sample_destroy` | `FFI_PLUGIN_EXPORT void filament_suzanne_sample_destroy( void* engin...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_destroy_material_instance` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_material_instance(vo...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_renderable_builder_create` | `FFI_PLUGIN_EXPORT void* filament_renderable_builder_create(uint32_t...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_renderable_builder_geometry` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_geometry_min_max` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_min_max...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_geometry_full` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_full(vo...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_geometry_no_index` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_no_inde...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_material` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_material(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_bounding_box` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_bounding_box(voi...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_culling` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_culling(void* bu...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_cast_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_cast_shadows(voi...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_receive_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_receive_shadows(...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_priority` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_priority(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_layer_mask` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_layer_mask(void*...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_skinning` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_skinning_bones` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_bones(v...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_skinning_matrices` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_matrice...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_enable_skinning_buffers` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_enable_skinning_...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_skinning_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_skinning_buffer(...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_bone_indices_and_weights` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_bone_indices_and...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_geometry_type` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_geometry_type(vo...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_channel` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_channel(void* bu...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_light_channel` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_light_channel(vo...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_blend_order` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_blend_order(void...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_global_blend_order_enabled` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_global_blend_ord...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_screen_space_contact_shadows` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_screen_space_con...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_fog` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_fog(void* builde...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_morphing` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_morphing_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_buffer(...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_morphing_offset_at` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_morphing_offset_...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderable_builder_instances` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_instances(void* ...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_instances_buffer` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_instances_buffer...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_build` | `FFI_PLUGIN_EXPORT int32_t filament_renderable_builder_build(void* b...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderable_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_renderable_builder_destroy(void* bu...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_renderable_create` | `FFI_PLUGIN_EXPORT void filament_renderable_create(void* engine, uin...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_renderable_set_bounding_box` | `FFI_PLUGIN_EXPORT void filament_renderable_set_bounding_box(void* e...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderable_set_priority` | `FFI_PLUGIN_EXPORT void filament_renderable_set_priority(void* engin...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| *... ve 51 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

### `src/index_buffer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_index_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_index_buffer_create( void* engine,...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_index_buffer_set_buffer` | `FFI_PLUGIN_EXPORT void filament_index_buffer_set_buffer( void* engi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_index_buffer_set_data` | `FFI_PLUGIN_EXPORT void filament_index_buffer_set_data( void* engine...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_index_buffer_get_index_count` | `FFI_PLUGIN_EXPORT uint32_t filament_index_buffer_get_index_count(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_destroy_index_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_index_buffer(void* e...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/instance_buffer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_instance_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_instance_buffer_create(void* engin...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_instance_buffer_set_local_transforms` | `FFI_PLUGIN_EXPORT void filament_instance_buffer_set_local_transform...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_instance_buffer_get_local_transform` | `FFI_PLUGIN_EXPORT void filament_instance_buffer_get_local_transform...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_instance_buffer_get_instance_count` | `FFI_PLUGIN_EXPORT uint32_t filament_instance_buffer_get_instance_co...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |

### `src/instance_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_transform_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_transform_manager_get_instance(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_transform_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_transform_manager_has_component(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_transform_manager_set_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_set_transform_i( ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_transform_manager_get_world_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_get_world_transfo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_transform_manager_get_transform_i` | `FFI_PLUGIN_EXPORT void filament_transform_manager_get_transform_i( ...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderable_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_renderable_manager_get_instance...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderable_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_renderable_manager_has_component(vo...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_light_manager_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_light_manager_get_instance(void...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_manager_has_component` | `FFI_PLUGIN_EXPORT bool filament_light_manager_has_component(void* e...` | Filament C motor durum veya yetenek doğrulamasını yapar. |

### `src/morph_target_buffer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_morph_target_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_morph_target_buffer_create(void* e...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_morph_target_buffer_set_positions_at_float3` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_a...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_morph_target_buffer_set_positions_at_float4` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_a...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_morph_target_buffer_set_tangents_at` | `FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_tangents_at...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_morph_target_buffer_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_vertex_...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_morph_target_buffer_get_count` | `FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_count(v...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_morph_target_buffer_has_positions` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_positions(v...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_morph_target_buffer_has_tangents` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_tangents(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_morph_target_buffer_is_custom_morphing_enabled` | `FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_is_custom_morph...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |

### `src/skinning_buffer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_skinning_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_skinning_buffer_create(void* engin...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_skinning_buffer_set_bones` | `FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones(void* eng...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_skinning_buffer_set_bones_matrices` | `FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones_matrices(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_skinning_buffer_get_bone_count` | `FFI_PLUGIN_EXPORT uint32_t filament_skinning_buffer_get_bone_count(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_destroy_skinning_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_skinning_buffer(void...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/tangent_space_mesh_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_tsm_builder_create` | `FFI_PLUGIN_EXPORT FilTsmBuilder* filament_tsm_builder_create(void);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_tsm_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_destroy(FilTsmBuilder* b);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_tsm_builder_vertex_count` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_vertex_count(FilTsmBuil...` | Filament yerel `filament_tsm_builder_vertex_count` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_normals` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_normals(FilTsmBuilder* ...` | Filament yerel `filament_tsm_builder_normals` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_tangents` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_tangents(FilTsmBuilder*...` | Filament yerel `filament_tsm_builder_tangents` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_uvs` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_uvs(FilTsmBuilder* b, c...` | Filament yerel `filament_tsm_builder_uvs` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_positions` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_positions(FilTsmBuilder...` | Filament yerel `filament_tsm_builder_positions` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_triangle_count` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangle_count(FilTsmBu...` | Filament yerel `filament_tsm_builder_triangle_count` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_triangles_uint3` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_uint3(FilTsmB...` | Filament yerel `filament_tsm_builder_triangles_uint3` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_triangles_ushort3` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_ushort3(FilTs...` | Filament yerel `filament_tsm_builder_triangles_ushort3` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_aux` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_aux(FilTsmBuilder* b, i...` | Filament yerel `filament_tsm_builder_aux` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_algorithm` | `FFI_PLUGIN_EXPORT void filament_tsm_builder_algorithm(FilTsmBuilder...` | Filament yerel `filament_tsm_builder_algorithm` C fonksiyonunu çalıştırır. |
| `filament_tsm_builder_build` | `FFI_PLUGIN_EXPORT FilTangentSpaceMesh* filament_tsm_builder_build(F...` | Filament yerel `filament_tsm_builder_build` C fonksiyonunu çalıştırır. |
| `filament_tsm_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_vertex_count(const FilT...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_triangle_count` | `FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_triangle_count(const Fi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_remeshed` | `FFI_PLUGIN_EXPORT bool filament_tsm_remeshed(const FilTangentSpaceM...` | Filament yerel `filament_tsm_remeshed` C fonksiyonunu çalıştırır. |
| `filament_tsm_get_positions` | `FFI_PLUGIN_EXPORT void filament_tsm_get_positions(const FilTangentS...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_uvs` | `FFI_PLUGIN_EXPORT void filament_tsm_get_uvs(const FilTangentSpaceMe...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_quats_float4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_float4(const FilTange...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_quats_short4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_short4(const FilTange...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_quats_half4` | `FFI_PLUGIN_EXPORT void filament_tsm_get_quats_half4(const FilTangen...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_triangles_uint3` | `FFI_PLUGIN_EXPORT void filament_tsm_get_triangles_uint3(const FilTa...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_get_aux` | `FFI_PLUGIN_EXPORT void filament_tsm_get_aux(const FilTangentSpaceMe...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_tsm_destroy` | `FFI_PLUGIN_EXPORT void filament_tsm_destroy(FilTangentSpaceMesh* m);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/vertex_buffer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_vertex_buffer_create` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create( void* engine...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_vertex_buffer_create_legacy` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_legacy(void* ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_vertex_buffer_create_with_color` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_color(vo...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_vertex_buffer_create_with_uv` | `FFI_PLUGIN_EXPORT void* filament_vertex_buffer_create_with_uv(void*...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_vertex_buffer_set_buffer_at` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_at( void* ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_vertex_buffer_set_data` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_data( void* engin...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_vertex_buffer_get_vertex_count` | `FFI_PLUGIN_EXPORT uint32_t filament_vertex_buffer_get_vertex_count(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_vertex_buffer_set_buffer_object_at` | `FFI_PLUGIN_EXPORT void filament_vertex_buffer_set_buffer_object_at(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_engine_destroy_vertex_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_vertex_buffer(void* ...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

## Dart API

### `lib/src/buffer_descriptor.dart`

#### `class NativeBuffer`

A contiguous native memory buffer allocated on the C heap for zero-copy transfers to Filament.

**Yapıcı Metotlar (Constructors):**
- `NativeBuffer._(this.pointer, this.sizeInBytes, this._view)`: `NativeBuffer._(this.pointer, this.sizeInBytes, this._view)` nesnesini ilklendirir.
- `NativeBuffer.allocate(int byteCount)`: Allocates [byteCount] bytes of native memory using `calloc`.
- `NativeBuffer.copy(Uint8List source)`: Allocates native memory and copies [source] bytes into it.
- `NativeBuffer.fromTypedData(TypedData source)`: Allocates native memory and copies any [TypedData] into it.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sizeInBytes` | `int sizeInBytes` | `sizeInBytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `asTypedList` | `Uint8List get asTypedList` | Returns a Dart [Uint8List] view pointing directly to the allocated native memory.  Throws a [StateError] if this buffer has already been released or freed. |
| `address` | `int get address` | The raw native address of this buffer. |
| `isReleased` | `bool get isReleased` | Whether this buffer has been released / freed. |
| `free` | `void free()` | Frees the allocated native memory. Safe to call multiple times (idempotent). |

#### `class _BufferEntry`

`_BufferEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `keepAlive` | `Object keepAlive` | `keepAlive` alanını (field/property) ve ilişkili veriyi saklar. |
| `completer` | `Completer<void> completer` | `completer` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class BufferOwnershipRegistry`

Central registry managing buffer ownership and release callbacks from Filament's backend.

**Yapıcı Metotlar (Constructors):**
- `BufferOwnershipRegistry._()`: `BufferOwnershipRegistry._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `whenReleased` | `Future<void> whenReleased(int token)` | Returns a [Future] that completes when the GPU backend has finished processing the buffer associated with [token] and released it. |
| `pendingCount` | `int get pendingCount` | The number of buffers currently awaiting GPU release. |
| `dispose` | `void dispose()` | Disposes the native callback listener. |

### `lib/src/buffer_object.dart`

#### `enum BufferObjectBindingType`

Distinguishes between buffer object bindings (e.g., vertex, uniform, SSBO).

**Yapıcı Metotlar (Constructors):**
- `BufferObjectBindingType(this.value)`: `BufferObjectBindingType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shaderStorage` | `shaderStorage(2)` | `shaderStorage` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentBufferObject`

A generic GPU buffer containing data for sharing between multiple VertexBuffer instances.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `byteCount` | `int get byteCount` | Maximum number of bytes this BufferObject can hold. |
| `bindingType` | `BufferObjectBindingType get bindingType` | The binding type of this BufferObject. |
| `dispose` | `void dispose()` | Destroys this BufferObject. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/filamesh.dart`

#### `class MaterialRegistry`

Registry of named [FilamentMaterialInstance]s used when loading .filamesh models.

**Yapıcı Metotlar (Constructors):**
- `MaterialRegistry() : _handle = c.filament_material_registry_create()`: `MaterialRegistry() : _handle = c.filament_material_registry_create()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `register` | `void register(String name, FilamentMaterialInstance materialInstance)` | Registers a [FilamentMaterialInstance] with a given submesh [name]. |
| `getMaterialInstance` | `FilamentMaterialInstance? getMaterialInstance(String name)` | Gets the registered [FilamentMaterialInstance] for [name], or null if not registered. |
| `unregister` | `void unregister(String name)` | Unregisters the material instance associated with [name]. |
| `numRegistered` | `int get numRegistered` | Number of registered materials in this registry. |
| `names` | `List<String> get names` | Returns the list of all registered material names. |
| `destroy` | `void destroy()` | Destroys the native registry handle.  Note: The registry does NOT own the underlying [FilamentMaterialInstance]s; destroying the registry leaves the material instances intact. |

#### `class FilameshMesh`

Represents a loaded .filamesh mesh containing a renderable entity, vertex buffer, and index buffer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `renderable` | `int get renderable` | The renderable entity ID. |
| `vertexBuffer` | `int get vertexBuffer` | The native handle pointer value of the underlying [VertexBuffer]. |
| `indexBuffer` | `int get indexBuffer` | The native handle pointer value of the underlying [IndexBuffer]. |
| `destroy` | `void destroy()` | Destroys the renderable entity, vertex buffer, and index buffer in proper engine order. |

### `lib/src/index_buffer.dart`

#### `class FilamentIndexBuffer`

A buffer holding index data defining triangle or line primitives.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `indexCount` | `int get indexCount` | Number of indices this buffer can hold. |
| `type` | `IndexType get type` | The element type of the indices (ushort or uint). |
| `byteCapacity` | `int get byteCapacity` | Total capacity in bytes for this IndexBuffer. |
| `setUint16Data` | `void setUint16Data(Uint16List data)` | Sets 16-bit short index data (backward-compatible convenience). |
| `setUint32Data` | `void setUint32Data(Uint32List data)` | Sets 32-bit int index data (backward-compatible convenience). |
| `dispose` | `void dispose()` | Destroys this IndexBuffer. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/instance.dart`

#### `extension type const`

Zero-cost extension type representing a fast, cached `TransformManager::Instance` handle.  Instance handles avoid repeated entity-to-component hash map lookups inside high-frequency frame loops. An instance handle is valid within a frame but may be invalidated across component additions / deletions.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid transform component (non-zero). |

#### `extension type const`

Zero-cost extension type representing a fast `RenderableManager::Instance` handle.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid renderable component (non-zero). |

#### `extension type const`

Zero-cost extension type representing a fast `LightManager::Instance` handle.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isValid` | `bool get isValid` | Whether this handle references a valid light component (non-zero). |

### `lib/src/instance_buffer.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Float32List packMatrices(List<Matrix4> matrices)`**: Helper to pack a list of [Matrix4] objects into a contiguous column-major [Float32List] of length 16 * N.

#### `class InstanceBuffer`

Holds GPU draw instance transforms for GPU instancing.

**Yapıcı Metotlar (Constructors):**
- `InstanceBuffer._(this._nativeBuffer, this.engine, this._instanceCount)`: `InstanceBuffer._(this._nativeBuffer, this.engine, this._instanceCount)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `getLocalTransform` | `Matrix4 getLocalTransform(int index)` | Returns the local transform for instance at [index]. |
| `instanceCount` | `int get instanceCount` | Returns the instance capacity of this buffer. |
| `isDisposed` | `bool get isDisposed` | Whether this buffer has been disposed. |
| `destroy` | `void destroy() => dispose()` | Destroys the InstanceBuffer. |
| `dispose` | `void dispose()` | Destroys the InstanceBuffer. |

### `lib/src/morph_target_buffer.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Int16List packTangentFrame(dynamic q)`**: Packs a quaternion (or 4D tangent frame) into an [Int16List] of 4 snorm16 values.  Symmetric packaging matching Filament's `norm.h`.

#### `class MorphTargetBuffer`

A container for vertex morphing data that supports both automatic and manual morphing.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Yapıcı Metotlar (Constructors):**
- `RenderableBuilder(int primitiveCount) : _builder = c.filament_renderable_builder_create(primitiveCount)`: `RenderableBuilder(int primitiveCount) : _builder = c.filament_renderable_builder_create(primitiveCount)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `geometryType` | `void geometryType(GeometryType type)` | Sets the optimization hint for this renderable's geometry. Note: With `GeometryType.static_`, Filament makes optimization assumptions. Binding a different buffer later is undefined. |
| `material` | `void material(int index, FilamentMaterialInstance mi)` | Assigns a [materialInstance] to the primitive at [index]. |
| `boundingBox` | `void boundingBox(double minX, double minY, double minZ, double maxX, dou...` | Sets the axis-aligned bounding box. Mandatory if culling is enabled! |
| `culling` | `void culling(bool enabled)` | `culling` işlemini gerçekleştirir. |
| `castShadows` | `void castShadows(bool enabled)` | `castShadows` işlemini gerçekleştirir. |
| `receiveShadows` | `void receiveShadows(bool enabled)` | `receiveShadows` işlemini gerçekleştirir. |
| `priority` | `void priority(int priority)` | `priority` işlemini gerçekleştirir. |
| `layerMask` | `void layerMask(int select, int mask)` | `layerMask` işlemini gerçekleştirir. |
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

`FilamentRenderableManager`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FilamentRenderableManager(this.engine)`: Creates a renderable manager wrapper.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
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
| `setRayTracingVisible` | `void setRayTracingVisible(int entity, bool visible)` | [entity] geometrisinin sahnesinin ışın izleme hızlandırma yapılarında yer alıp almadığı (varsayılan true). |
| `isRayTracingVisible` | `bool isRayTracingVisible(int entity)` | [entity] ışın izleme hızlandırma yapılarında mı, sorgular. |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentScene.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `createSuzanneSample` | `int createSuzanneSample(FilamentView view)` | Populates this scene with the official Filament 3D Suzanne Monkey model, including all 5 PBR KTX2 textures (Albedo, AO, Metallic, Roughness, Normal Map). |
| `destroySuzanneSample` | `void destroySuzanneSample()` | Destroys all Suzanne 3D sample resources cleanly before engine disposal. |
| `addEntity` | `void addEntity(int entity)` | Adds an entity to this scene.  The entity is ignored for rendering purposes if it doesn't have a Renderable or Light component. |
| `addEntities` | `void addEntities(List<int> entities)` | Adds a list of entities to the scene in a single batch FFI call. |
| `removeEntity` | `void removeEntity(int entity)` | Removes an entity from this scene. |
| `removeEntities` | `void removeEntities(List<int> entities)` | Removes a list of entities from the scene in a single batch FFI call. |
| `removeAllEntities` | `void removeAllEntities()` | Removes all entities from the scene. |
| `hasEntity` | `bool hasEntity(int entity)` | Returns true if the given entity is present in the scene. |
| `rayTracingEnabled` | `bool rayTracingEnabled` (get/set) | Sahne için her karede yeniden kurulan ışın izleme hızlandırma yapılarını tutar; `FilamentEngine.supportsRayQuery` gerekir (bkz. [Işın izleme](ray-tracing.md)). Varsayılan false. |
| `tlasInstanceCount` | `int get tlasInstanceCount` | Son kareden sonra üst düzey hızlandırma yapısındaki renderable sayısı (kapalı ya da desteksizken 0). |
| `lastTlasBuildTime` | `Duration get lastTlasBuildTime` | Son üst düzey yapı kurulumunun GPU süresi (bir zamanlayıcı sorgusu çözülene dek `Duration.zero`). |
| `traceVisibility` | `Future<RayHit?> traceVisibility(double ox, double oy, double oz, double dx, double dy, double dz, {double maxDistance = 1.0e5})` | Test kancası: geçici 1x1 bir view üzerinden tek bir görünürlük ışını izler ve yanıtı bekler; ıskalamada ya da ışın izleme yokken `null`. Kareler arasında çağrılır. |
| `setIndirectLight` | `void setIndirectLight(FilamentIndirectLight? indirectLight)` | Sets the Image-Based Lighting (IBL) IndirectLight for this scene. |
| `indirectLight` | `FilamentIndirectLight? get indirectLight` | The currently attached [FilamentIndirectLight], or null if none is set. |
| `indirectLight` | `indirectLight(FilamentIndirectLight? value) => setIndirectLight(value)` | `indirectLight` işlemini gerçekleştirir. |
| `setSkybox` | `void setSkybox(FilamentSkybox? skybox)` | Sets the background Skybox for this scene. |
| `skybox` | `FilamentSkybox? get skybox` | The currently attached [FilamentSkybox], or null if none is set. |
| `skybox` | `skybox(FilamentSkybox? value) => setSkybox(value)` | `skybox` işlemini gerçekleştirir. |
| `entityCount` | `int get entityCount` | Returns the total number of entities in this scene. |
| `renderableCount` | `int get renderableCount` | Returns the number of active renderable objects in this scene. |
| `lightCount` | `int get lightCount` | Returns the number of active light objects in this scene. |
| `dispose` | `void dispose()` | Destroys this scene and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/skinning_buffer.dart`

#### `class SkinningBuffer`

`SkinningBuffer`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SkinningBuffer._(this._nativeBuffer, this.engine, this._boneCount)`: `SkinningBuffer._(this._nativeBuffer, this.engine, this._boneCount)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `boneCount` | `int get boneCount` | Returns the (rounded) capacity of the buffer. |
| `destroy` | `void destroy()` | Destroys the SkinningBuffer. |

### `lib/src/tangent_space_mesh.dart`

#### `enum TsmAlgorithm`

The algorithm used to generate the tangent space.

**Yapıcı Metotlar (Constructors):**
- `TsmAlgorithm(this.value)`: `TsmAlgorithm(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frisvad` | `frisvad(4)` | Frisvad's method (requires normals). |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum TsmAuxAttribute`

Auxiliary attributes that can be provided and will be properly mapped if remeshed.

**Yapıcı Metotlar (Constructors):**
- `TsmAuxAttribute(this.value)`: `TsmAuxAttribute(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `weights` | `weights(3)` | `weights` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum _TsmAuxType`

Internal data types for auxiliary attributes.

**Yapıcı Metotlar (Constructors):**
- `_TsmAuxType(this.value)`: `_TsmAuxType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ushort4` | `ushort4(4)` | `ushort4` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TangentSpaceMeshBuilder`

Builds a [TangentSpaceMesh].

**Yapıcı Metotlar (Constructors):**
- `TangentSpaceMeshBuilder() : _builder = c.filament_tsm_builder_create()`: `TangentSpaceMeshBuilder() : _builder = c.filament_tsm_builder_create()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vertexCount` | `void vertexCount(int count)` | `vertexCount` işlemini gerçekleştirir. |
| `triangleCount` | `void triangleCount(int count)` | `triangleCount` işlemini gerçekleştirir. |
| `trianglesUint` | `void trianglesUint(Uint32List tris)` | `trianglesUint` işlemini gerçekleştirir. |
| `trianglesUshort` | `void trianglesUshort(Uint16List tris)` | `trianglesUshort` işlemini gerçekleştirir. |
| `algorithm` | `void algorithm(TsmAlgorithm algo)` | `algorithm` işlemini gerçekleştirir. |
| `build` | `TangentSpaceMesh build()` | Deklaratif alt nesne veya widget ağacını inşa eder. |

#### `class TangentSpaceMesh`

The generated tangent space mesh.

**Yapıcı Metotlar (Constructors):**
- `TangentSpaceMesh._(this._ptr)`: `TangentSpaceMesh._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `remeshed` | `bool get remeshed` | `remeshed` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `getTrianglesUint32` | `Uint32List getTrianglesUint32()` | `TrianglesUint32` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `destroy` | `void destroy()` | Belirtilen `` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

### `lib/src/transform.dart`

#### `class FilamentTransformManager`

Manages transform components for entities.  Transform components give entities a position and orientation in space.

**Yapıcı Metotlar (Constructors):**
- `FilamentTransformManager(this.engine)`: Creates a transform manager wrapper for [engine].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `attribute` | `VertexAttribute attribute` | `attribute` alanını (field/property) ve ilişkili veriyi saklar. |
| `bufferIndex` | `int bufferIndex` | `bufferIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `AttributeType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `byteOffset` | `int byteOffset` | `byteOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `byteStride` | `int byteStride` | `byteStride` alanını (field/property) ve ilişkili veriyi saklar. |
| `normalized` | `bool normalized` | `normalized` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentVertexBuffer`

A buffer holding vertex data (positions, normals, UVs, colors, etc.).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vertexCount` | `int get vertexCount` | Number of vertices in each buffer slot. |
| `bufferCount` | `int get bufferCount` | Number of buffer slots. |
| `enableBufferObjects` | `bool get enableBufferObjects` | Whether buffer object mode is enabled. |
| `attributes` | `List<VertexAttributeDesc> get attributes` | The attribute descriptions for this vertex buffer. |
| `dispose` | `void dispose()` | Destroys this VertexBuffer. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: View seçenekleri ve color grading](view-options.md) | [Üst: flutter_filament](index.md) | [Sonraki: Kamera ve manipulator](camera-and-manipulator.md)
