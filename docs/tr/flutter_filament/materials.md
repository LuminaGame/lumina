[English](../../en/flutter_filament/materials.md)

# Materyaller

Derlenmiş materyallerin yüklenmesi, material instance oluşturma ve parametreleri ile render state'lerini ayarlama ve filamat material builder ile çalışma anında yeni materyal üretme. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/filamat_c.h`](#srcfilamat_ch)
  - [`src/material_c.h`](#srcmaterial_ch)
  - [`src/material_instance_c.h`](#srcmaterial_instance_ch)
- [Dart API](#dart-api)
  - [`lib/src/filamat_builder.dart`](#libsrcfilamat_builderdart)
  - [`lib/src/material.dart`](#libsrcmaterialdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/filamat_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_filamat_init` | `FFI_PLUGIN_EXPORT void filament_filamat_init(void);` | Filament yerel `filament_filamat_init` C fonksiyonunu çalıştırır. |
| `filament_filamat_shutdown` | `FFI_PLUGIN_EXPORT void filament_filamat_shutdown(void);` | Filament yerel `filament_filamat_shutdown` C fonksiyonunu çalıştırır. |
| `filament_material_builder_create` | `FFI_PLUGIN_EXPORT void* filament_material_builder_create(void);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_material_builder_destroy(void* buil...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_material_builder_set_name` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_name(void* bui...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_builder_set_code` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_code(void* bui...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_builder_set_double_sided` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_double_sided(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_builder_parameter` | `FFI_PLUGIN_EXPORT void filament_material_builder_parameter(void* bu...` | Filament yerel `filament_material_builder_parameter` C fonksiyonunu çalıştırır. |
| `filament_material_builder_parameter_array` | `FFI_PLUGIN_EXPORT void filament_material_builder_parameter_array(vo...` | Filament yerel `filament_material_builder_parameter_array` C fonksiyonunu çalıştırır. |
| `filament_material_builder_constant_bool` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_bool(void...` | Filament yerel `filament_material_builder_constant_bool` C fonksiyonunu çalıştırır. |
| `filament_material_builder_constant_int` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_int(void*...` | Filament yerel `filament_material_builder_constant_int` C fonksiyonunu çalıştırır. |
| `filament_material_builder_constant_float` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_float(voi...` | Filament yerel `filament_material_builder_constant_float` C fonksiyonunu çalıştırır. |
| `filament_material_builder_material_vertex` | `FFI_PLUGIN_EXPORT void filament_material_builder_material_vertex(vo...` | Filament yerel `filament_material_builder_material_vertex` C fonksiyonunu çalıştırır. |
| `filament_material_builder_variable` | `FFI_PLUGIN_EXPORT void filament_material_builder_variable(void* bui...` | Filament yerel `filament_material_builder_variable` C fonksiyonunu çalıştırır. |
| `filament_material_builder_variable_precision` | `FFI_PLUGIN_EXPORT void filament_material_builder_variable_precision...` | Filament yerel `filament_material_builder_variable_precision` C fonksiyonunu çalıştırır. |
| `filament_material_builder_vertex_domain` | `FFI_PLUGIN_EXPORT void filament_material_builder_vertex_domain(void...` | Filament yerel `filament_material_builder_vertex_domain` C fonksiyonunu çalıştırır. |
| `filament_material_builder_vertex_domain_device_jittered` | `FFI_PLUGIN_EXPORT void filament_material_builder_vertex_domain_devi...` | Filament yerel `filament_material_builder_vertex_domain_device_jittered` C fonksiyonunu çalıştırır. |
| `filament_material_builder_flip_uv` | `FFI_PLUGIN_EXPORT void filament_material_builder_flip_uv(void* buil...` | Filament yerel `filament_material_builder_flip_uv` C fonksiyonunu çalıştırır. |
| `filament_material_builder_blending` | `FFI_PLUGIN_EXPORT void filament_material_builder_blending(void* bui...` | Filament yerel `filament_material_builder_blending` C fonksiyonunu çalıştırır. |
| `filament_material_builder_custom_blend_functions` | `FFI_PLUGIN_EXPORT void filament_material_builder_custom_blend_funct...` | Filament yerel `filament_material_builder_custom_blend_functions` C fonksiyonunu çalıştırır. |
| `filament_material_builder_post_lighting_blending` | `FFI_PLUGIN_EXPORT void filament_material_builder_post_lighting_blen...` | Filament yerel `filament_material_builder_post_lighting_blending` C fonksiyonunu çalıştırır. |
| `filament_material_builder_transparency_mode` | `FFI_PLUGIN_EXPORT void filament_material_builder_transparency_mode(...` | Filament yerel `filament_material_builder_transparency_mode` C fonksiyonunu çalıştırır. |
| `filament_material_builder_mask_threshold` | `FFI_PLUGIN_EXPORT void filament_material_builder_mask_threshold(voi...` | Filament yerel `filament_material_builder_mask_threshold` C fonksiyonunu çalıştırır. |
| `filament_material_builder_alpha_to_coverage` | `FFI_PLUGIN_EXPORT void filament_material_builder_alpha_to_coverage(...` | Filament yerel `filament_material_builder_alpha_to_coverage` C fonksiyonunu çalıştırır. |
| `filament_material_builder_refraction_mode` | `FFI_PLUGIN_EXPORT void filament_material_builder_refraction_mode(vo...` | Filament yerel `filament_material_builder_refraction_mode` C fonksiyonunu çalıştırır. |
| `filament_material_builder_refraction_type` | `FFI_PLUGIN_EXPORT void filament_material_builder_refraction_type(vo...` | Filament yerel `filament_material_builder_refraction_type` C fonksiyonunu çalıştırır. |
| `filament_material_builder_culling` | `FFI_PLUGIN_EXPORT void filament_material_builder_culling(void* buil...` | Filament yerel `filament_material_builder_culling` C fonksiyonunu çalıştırır. |
| `filament_material_builder_color_write` | `FFI_PLUGIN_EXPORT void filament_material_builder_color_write(void* ...` | Filament yerel `filament_material_builder_color_write` C fonksiyonunu çalıştırır. |
| `filament_material_builder_depth_write` | `FFI_PLUGIN_EXPORT void filament_material_builder_depth_write(void* ...` | Filament yerel `filament_material_builder_depth_write` C fonksiyonunu çalıştırır. |
| `filament_material_builder_depth_culling` | `FFI_PLUGIN_EXPORT void filament_material_builder_depth_culling(void...` | Filament yerel `filament_material_builder_depth_culling` C fonksiyonunu çalıştırır. |
| `filament_material_builder_instanced` | `FFI_PLUGIN_EXPORT void filament_material_builder_instanced(void* bu...` | Filament yerel `filament_material_builder_instanced` C fonksiyonunu çalıştırır. |
| `filament_material_builder_material_domain` | `FFI_PLUGIN_EXPORT void filament_material_builder_material_domain(vo...` | Filament yerel `filament_material_builder_material_domain` C fonksiyonunu çalıştırır. |
| `filament_material_builder_group_size` | `FFI_PLUGIN_EXPORT void filament_material_builder_group_size(void* b...` | Filament yerel `filament_material_builder_group_size` C fonksiyonunu çalıştırır. |
| `filament_material_builder_output` | `FFI_PLUGIN_EXPORT void filament_material_builder_output(void* build...` | Filament yerel `filament_material_builder_output` C fonksiyonunu çalıştırır. |
| `filament_material_builder_enable_framebuffer_fetch` | `FFI_PLUGIN_EXPORT void filament_material_builder_enable_framebuffer...` | Filament yerel `filament_material_builder_enable_framebuffer_fetch` C fonksiyonunu çalıştırır. |
| `filament_material_builder_subpass` | `FFI_PLUGIN_EXPORT void filament_material_builder_subpass(void* buil...` | Filament yerel `filament_material_builder_subpass` C fonksiyonunu çalıştırır. |
| `filament_material_builder_platform` | `FFI_PLUGIN_EXPORT void filament_material_builder_platform(void* bui...` | Filament yerel `filament_material_builder_platform` C fonksiyonunu çalıştırır. |
| `filament_material_builder_target_api` | `FFI_PLUGIN_EXPORT void filament_material_builder_target_api(void* b...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_builder_optimization` | `FFI_PLUGIN_EXPORT void filament_material_builder_optimization(void*...` | Filament yerel `filament_material_builder_optimization` C fonksiyonunu çalıştırır. |
| `filament_material_builder_variant_filter` | `FFI_PLUGIN_EXPORT void filament_material_builder_variant_filter(voi...` | Filament yerel `filament_material_builder_variant_filter` C fonksiyonunu çalıştırır. |
| *... ve 23 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

### `src/material_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_material_create` | `FFI_PLUGIN_EXPORT void* filament_material_create(void* engine, cons...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_create_ex` | `FFI_PLUGIN_EXPORT void* filament_material_create_ex( void* engine, ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_create_instance` | `FFI_PLUGIN_EXPORT void* filament_material_create_instance(void* mat...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_create_instance_with_name` | `FFI_PLUGIN_EXPORT void* filament_material_create_instance_with_name...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_material_get_default_instance` | `FFI_PLUGIN_EXPORT void* filament_material_get_default_instance(void...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_destroy_material` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_material(void* engin...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_material_compile` | `FFI_PLUGIN_EXPORT void filament_material_compile(void* material, in...` | Filament yerel `filament_material_compile` C fonksiyonunu çalıştırır. |
| `filament_material_get_parameter_count` | `FFI_PLUGIN_EXPORT size_t filament_material_get_parameter_count(void...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_parameters` | `FFI_PLUGIN_EXPORT size_t filament_material_get_parameters(void* mat...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_has_parameter` | `FFI_PLUGIN_EXPORT bool filament_material_has_parameter(void* materi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_is_sampler` | `FFI_PLUGIN_EXPORT bool filament_material_is_sampler(void* material,...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_get_parameter_transform_name` | `FFI_PLUGIN_EXPORT const char* filament_material_get_parameter_trans...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_set_default_parameter_bool` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_bool...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_int` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_int(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_float` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_float2` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_float3` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_float4` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_mat3` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat3...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_mat4` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat4...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_texture` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_text...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_rgb` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgb(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_set_default_parameter_rgba` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgba...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_get_shading` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_shading(void* mater...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_interpolation` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_interpolation(void*...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_blending_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_blending_mode(void*...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_vertex_domain` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_vertex_domain(void*...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_material_domain` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_material_domain(voi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_culling_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_culling_mode(void* ...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_transparency_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_transparency_mode(v...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_is_color_write_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_color_write_enabled(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_is_depth_write_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_depth_write_enabled(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_is_depth_culling_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_depth_culling_enabled(v...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_is_double_sided` | `FFI_PLUGIN_EXPORT bool filament_material_is_double_sided(void* mate...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_is_alpha_to_coverage_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_alpha_to_coverage_enabl...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_get_mask_threshold` | `FFI_PLUGIN_EXPORT float filament_material_get_mask_threshold(void* ...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_has_shadow_multiplier` | `FFI_PLUGIN_EXPORT bool filament_material_has_shadow_multiplier(void...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_has_specular_anti_aliasing` | `FFI_PLUGIN_EXPORT bool filament_material_has_specular_anti_aliasing...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_material_get_specular_anti_aliasing_variance` | `FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasin...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_material_get_specular_anti_aliasing_threshold` | `FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasin...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| *... ve 6 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

### `src/material_instance_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_material_instance_duplicate` | `FFI_PLUGIN_EXPORT void* filament_material_instance_duplicate(void* ...` | Filament yerel `filament_material_instance_duplicate` C fonksiyonunu çalıştırır. |
| `filament_material_instance_set_bool` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_bool2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool2(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_bool3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool3(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_bool4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool4(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_int` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int(void* mi,...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_int2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int2(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_int3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int3(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_int4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int4(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_uint` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_uint2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint2(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_uint3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint3(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_uint4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint4(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float(void* m...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float2(void* ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float3(void* ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float4(void* ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_mat3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_mat4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float_array(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float2_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float2_array(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float3_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float3_array(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_float4_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float4_array(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_int_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int_array(voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_mat3_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3_array(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_mat4_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4_array(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_rgb` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_rgb(void* mi,...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_rgba` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_rgba(void* mi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_texture` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_texture(void*...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_texture_ex` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_texture_ex(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_culling_mode` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_culling_mode2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode2...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_double_sided` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_double_sided(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_color_write` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_color_write(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_depth_write` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_write(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_depth_culling` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_culling...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_depth_func` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_func(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_transparency_mode` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_transparency_...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_mask_threshold` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mask_threshol...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_material_instance_set_polygon_offset` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_polygon_offse...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| *... ve 39 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

## Dart API

### `lib/src/filamat_builder.dart`

#### `enum FilamatShading`

Shading models for runtime GLSL materials.

**Yapıcı Metotlar (Constructors):**
- `FilamatShading(this.value)`: `FilamatShading(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `specularGlossiness` | `specularGlossiness(4)` | `specularGlossiness` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum MaterialDomain`

Material domain for shaders.

**Yapıcı Metotlar (Constructors):**
- `MaterialDomain(this.value)`: `MaterialDomain(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `compute` | `compute(2)` | `compute` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum BlendingMode`

Supported blending modes.

**Yapıcı Metotlar (Constructors):**
- `BlendingMode(this.value)`: `BlendingMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `custom` | `custom(7)` | `custom` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum BlendFunction`

Blending functions for custom blend modes.

**Yapıcı Metotlar (Constructors):**
- `BlendFunction(this.value)`: `BlendFunction(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `srcAlphaSaturate` | `srcAlphaSaturate(10)` | `srcAlphaSaturate` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum RefractionMode`

Refraction modes.

**Yapıcı Metotlar (Constructors):**
- `RefractionMode(this.value)`: `RefractionMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `screenSpace` | `screenSpace(2)` | `screenSpace` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum RefractionType`

Refraction types.

**Yapıcı Metotlar (Constructors):**
- `RefractionType(this.value)`: `RefractionType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `thin` | `thin(1)` | `thin` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum ReflectionMode`

Reflection modes.

**Yapıcı Metotlar (Constructors):**
- `ReflectionMode(this.value)`: `ReflectionMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `screenSpace` | `screenSpace(1)` | `screenSpace` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum SpecularAOMode`

Specular ambient occlusion modes.

**Yapıcı Metotlar (Constructors):**
- `SpecularAOMode(this.value)`: `SpecularAOMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bentNormals` | `bentNormals(2)` | `bentNormals` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum MaterialVariable`

Custom interpolant variables for vertex-to-fragment communication.

**Yapıcı Metotlar (Constructors):**
- `MaterialVariable(this.value)`: `MaterialVariable(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `custom4` | `custom4(4)` | `custom4` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum VertexDomain`

Types of vertex domains.

**Yapıcı Metotlar (Constructors):**
- `VertexDomain(this.value)`: `VertexDomain(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `device` | `device(3)` | `device` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum MaterialPlatform`

Target platforms.

**Yapıcı Metotlar (Constructors):**
- `MaterialPlatform(this.value)`: `MaterialPlatform(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `all` | `all(2)` | `all` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum TargetApi`

Target API / language representations.

**Yapıcı Metotlar (Constructors):**
- `TargetApi(this.value)`: `TargetApi(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `all` | `all(0x07)` | `all` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum OptimizationLevel`

Shader optimization levels.

**Yapıcı Metotlar (Constructors):**
- `OptimizationLevel(this.value)`: `OptimizationLevel(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `performance` | `performance(3)` | `performance` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum OutputTarget`

Target buffer for post-process outputs.

**Yapıcı Metotlar (Constructors):**
- `OutputTarget(this.value)`: `OutputTarget(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `depth` | `depth(1)` | `depth` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum OutputType`

Data type for fragment shader outputs.

**Yapıcı Metotlar (Constructors):**
- `OutputType(this.value)`: `OutputType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `uint4` | `uint4(11)` | `uint4` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum VariableQualifier`

Variable qualifiers for post-process outputs.

**Yapıcı Metotlar (Constructors):**
- `VariableQualifier(this.value)`: `VariableQualifier(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `out_` | `out_(0)` | `out_` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum ShaderQuality`

Shader quality levels.

**Yapıcı Metotlar (Constructors):**
- `ShaderQuality(this.value)`: `ShaderQuality(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `high` | `high(2)` | `high` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum Interpolation`

Interpolation mode for attributes in fragment shader.

**Yapıcı Metotlar (Constructors):**
- `Interpolation(this.value)`: `Interpolation(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `flat` | `flat(1)` | `flat` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class UserVariantFilterBit`

Bitmask constants for user variant filtering.

#### `class FilamentMaterialBuilder`

Dynamically builds and compiles GLSL material shaders into binary `.filamat` packages at runtime.

**Yapıcı Metotlar (Constructors):**
- `FilamentMaterialBuilder._(this._ptr)`: `FilamentMaterialBuilder._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initEngine` | `static void initEngine()` | Initializes the filamat compiler engine. Must be called once before building. |
| `shutdownEngine` | `static void shutdownEngine()` | Shuts down the filamat compiler engine. |
| `create` | `static FilamentMaterialBuilder create()` | Creates a new [FilamentMaterialBuilder]. |
| `setName` | `void setName(String name)` | Sets the material name. |
| `setCode` | `void setCode(String glslCode)` | Sets the GLSL shader code block. |
| `materialVertex` | `void materialVertex(String glslCode)` | Sets the vertex shader code block. |
| `setShading` | `void setShading(FilamatShading shading)` | Sets the shading model. |
| `setDoubleSided` | `void setDoubleSided(bool doubleSided)` | Sets whether the material is double-sided. |
| `requireAttribute` | `void requireAttribute(int attribute)` | Requires a vertex attribute (e.g. 2 for COLOR). |
| `constantBool` | `void constantBool(String name, bool defaultValue)` | Adds a specialization constant of boolean type. |
| `constantInt` | `void constantInt(String name, int defaultValue)` | Adds a specialization constant of integer type. |
| `constantFloat` | `void constantFloat(String name, double defaultValue)` | Adds a specialization constant of float type. |
| `vertexDomain` | `void vertexDomain(VertexDomain domain)` | Sets the vertex domain. |
| `vertexDomainDeviceJittered` | `void vertexDomainDeviceJittered(bool jittered)` | Sets whether the vertex domain in DEVICE space is jittered. |
| `flipUV` | `void flipUV(bool flip)` | Sets whether to flip the Y coordinate of UV attributes (default true in Filament). |
| `blending` | `void blending(BlendingMode mode)` | Sets the blending mode for this material. |
| `postLightingBlending` | `void postLightingBlending(BlendingMode mode)` | Sets post-lighting blending mode. |
| `transparencyMode` | `void transparencyMode(TransparencyMode mode)` | Sets transparency mode. |
| `maskThreshold` | `void maskThreshold(double threshold)` | Sets the clipping threshold for MASKED blending mode. |
| `alphaToCoverage` | `void alphaToCoverage(bool enable)` | Enables alpha-to-coverage for MSAA. |
| `refractionMode` | `void refractionMode(RefractionMode mode)` | Sets refraction mode. |
| `refractionType` | `void refractionType(RefractionType type)` | Sets refraction type. |
| `culling` | `void culling(CullingMode mode)` | Sets triangle culling mode. |
| `colorWrite` | `void colorWrite(bool enable)` | Enables or disables color buffer writing. |
| `depthWrite` | `void depthWrite(bool enable)` | Enables or disables depth buffer writing. |
| `depthCulling` | `void depthCulling(bool enable)` | Enables or disables depth culling/testing. |
| `instanced` | `void instanced(bool enable)` | Enables instanced primitive support. |
| `transparentPreset` | `void transparentPreset()` | Convenience preset configuring transparent material settings. |
| `materialDomain` | `void materialDomain(MaterialDomain domain)` | Sets the material domain (surface, post-process, compute). |
| `enableFramebufferFetch` | `void enableFramebufferFetch()` | Enables framebuffer fetch in shaders. |
| `platform` | `void platform(MaterialPlatform platform)` | Sets target platform hint. |
| `targetApi` | `void targetApi(TargetApi api)` | Sets target rendering API. |
| `optimization` | `void optimization(OptimizationLevel level)` | Sets shader optimization level. |
| `variantFilter` | `void variantFilter(int mask)` | Specifies a bitmask of variants to filter out. |
| `shaderDefine` | `void shaderDefine(String name, String value)` | Adds a preprocessor macro define. |
| `shadowMultiplier` | `void shadowMultiplier(bool enabled)` | Multiplies material output by shadowing factor (UNLIT model only). |
| `transparentShadow` | `void transparentShadow(bool enabled)` | Enables casting transparent shadows. |
| `coloredPenumbra` | `void coloredPenumbra(bool enabled)` | Enables colored penumbrae for cast shadows. |
| `shadowFarAttenuation` | `void shadowFarAttenuation(bool enabled)` | Enables shadow far attenuation. |
| `quality` | `void quality(ShaderQuality quality)` | Sets shader compilation quality. |
| `featureLevel` | `void featureLevel(int level)` | Sets target feature level. |
| `includeEssl1` | `void includeEssl1(bool enabled)` | Enables generation of ESSL 1.0 code for FL0. |
| `interpolation` | `void interpolation(Interpolation interpolation)` | Sets fragment attribute interpolation mode. |
| `clearCoatIorChange` | `void clearCoatIorChange(bool enabled)` | Enables or disables clear coat index of refraction darkening. |
| `linearFog` | `void linearFog(bool enabled)` | Enables linear fog. |
| `customSurfaceShading` | `void customSurfaceShading(bool enabled)` | Enables custom surface shading function in GLSL fragment. |
| `reflectionMode` | `void reflectionMode(ReflectionMode mode)` | Sets reflection rendering mode. |
| `multiBounceAmbientOcclusion` | `void multiBounceAmbientOcclusion(bool enabled)` | Enables multi-bounce ambient occlusion. |
| `specularAmbientOcclusion` | `void specularAmbientOcclusion(SpecularAOMode mode)` | Sets specular ambient occlusion mode. |
| `printShaders` | `void printShaders(bool enabled)` | Debug: Outputs generated GLSL shader code to stdout. |
| `saveRawVariants` | `void saveRawVariants(bool enabled)` | Debug: Writes raw generated GLSL variant files to the working directory. |
| `generateDebugInfo` | `void generateDebugInfo(bool enabled)` | Debug: Includes debugging symbols in generated SPIRV package. |
| `uniformTypeFromString` | `static UniformType? uniformTypeFromString(String name)` | Converts a string identifier to its matching [UniformType], or null. |
| `uniformTypeToString` | `static String uniformTypeToString(UniformType type)` | Converts a [UniformType] to its string representation. |
| `build` | `Uint8List? build()` | Compiles the GLSL shader and builds a `.filamat` binary buffer.  Returns `null` if compilation failed. |
| `dispose` | `void dispose()` | Disposes this builder. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/material.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`int filamentExpectedMaterialVersion`**: Represents a compiled Filament material. The material package version this engine build accepts.  A compiled `.filamat` carries its version in its header; if the two differ the engine refuses the material at load time. It logs and carries on, so the only visible symptom is that whatever used the material renders nothing — check this instead of trusting a successful load.
- **`int filamentMaterialPackageVersion(Uint8List package)`**: The version recorded in a compiled `.filamat` package's header.

#### `class MaterialConstant`

Specialization constant for material compilation.

**Yapıcı Metotlar (Constructors):**
- `MaterialConstant._(this.name)`: `MaterialConstant._(this.name)` nesnesini ilklendirir.
- `MaterialConstant.int32(String name, int value)`: `MaterialConstant.int32(String name, int value)` nesnesini ilklendirir.
- `MaterialConstant.float(String name, double value)`: `MaterialConstant.float(String name, double value)` nesnesini ilklendirir.
- `MaterialConstant.bool_(String name, bool value)`: `MaterialConstant.bool_(String name, bool value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class _Int32MaterialConstant`

`_Int32MaterialConstant`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_Int32MaterialConstant(super.name, this.value) : super._()`: `_Int32MaterialConstant(super.name, this.value) : super._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class _FloatMaterialConstant`

`_FloatMaterialConstant`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_FloatMaterialConstant(super.name, this.value) : super._()`: `_FloatMaterialConstant(super.name, this.value) : super._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class _BoolMaterialConstant`

`_BoolMaterialConstant`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_BoolMaterialConstant(super.name, this.value) : super._()`: `_BoolMaterialConstant(super.name, this.value) : super._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `bool value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum ShadowSamplingQuality`

Quality of shadow sampling for material builders.

**Yapıcı Metotlar (Constructors):**
- `ShadowSamplingQuality(this.value)`: `ShadowSamplingQuality(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ultra` | `ultra(3)` | `ultra` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class MaterialParameter`

Holds reflected information about a [FilamentMaterial] parameter.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSampler` | `bool isSampler` | `isSampler` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSubpass` | `bool isSubpass` | `isSubpass` alanını (field/property) ve ilişkili veriyi saklar. |
| `uniformType` | `UniformType? uniformType` | `uniformType` alanını (field/property) ve ilişkili veriyi saklar. |
| `samplerType` | `TextureSamplerType? samplerType` | `samplerType` alanını (field/property) ve ilişkili veriyi saklar. |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |
| `precision` | `ParameterPrecision precision` | `precision` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class FilamentMaterial`

`FilamentMaterial`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FilamentMaterial.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `parameterCount` | `int get parameterCount` | Number of parameters declared on this material. |
| `parameters` | `List<MaterialParameter> get parameters` | Reflected parameters of this material. |
| `hasParameter` | `bool hasParameter(String name)` | Checks whether this material declares a parameter with [name]. |
| `isSampler` | `bool isSampler(String name)` | Checks whether parameter [name] is a sampler texture parameter. |
| `parameterTransformName` | `String? parameterTransformName(String name)` | Gets the transform parameter name associated with sampler [name], or `null` if none. |
| `setDefaultParameterBool` | `void setDefaultParameterBool(String name, bool value)` | Sets default boolean parameter value. |
| `setDefaultParameterInt` | `void setDefaultParameterInt(String name, int value)` | Sets default integer parameter value. |
| `setDefaultParameterFloat` | `void setDefaultParameterFloat(String name, double value)` | Sets default float parameter value. |
| `setDefaultParameterFloat2` | `void setDefaultParameterFloat2(String name, double x, double y)` | Sets default 2-component float parameter value. |
| `setDefaultParameterFloat3` | `void setDefaultParameterFloat3(String name, double x, double y, double z)` | Sets default 3-component float parameter value. |
| `setDefaultParameterFloat4` | `void setDefaultParameterFloat4(String name, double x, double y, double z...` | Sets default 4-component float parameter value. |
| `setDefaultParameterMat3` | `void setDefaultParameterMat3(String name, List<double> matrix)` | Sets default 3x3 matrix parameter value. |
| `setDefaultParameterMat4` | `void setDefaultParameterMat4(String name, List<double> matrix)` | Sets default 4x4 matrix parameter value. |
| `setDefaultColor` | `void setDefaultColor(String name, RgbType type, (double, double, double)...` | Sets default RGB color parameter value. |
| `setDefaultColorRgba` | `void setDefaultColorRgba(String name, RgbaType type, (double, double, do...` | Sets default RGBA color parameter value. |
| `createInstance` | `FilamentMaterialInstance createInstance([String? name])` | Creates a new instance of this material with an optional [name]. |
| `defaultInstance` | `FilamentMaterialInstance get defaultInstance` | Returns the default instance of this material. |
| `getDefaultInstance` | `FilamentMaterialInstance getDefaultInstance()` | Returns the default instance of this material (alias for [defaultInstance]). |
| `shading` | `FilamatShading get shading` | Shading model of this material. |
| `interpolation` | `Interpolation get interpolation` | Interpolation mode of this material. |
| `blendingMode` | `BlendingMode get blendingMode` | Blending mode of this material. |
| `vertexDomain` | `VertexDomain get vertexDomain` | Vertex domain of this material. |
| `materialDomain` | `MaterialDomain get materialDomain` | Material domain of this material. |
| `cullingMode` | `CullingMode get cullingMode` | Default culling mode of this material. |
| `transparencyMode` | `TransparencyMode get transparencyMode` | Transparency mode of this material. |
| `isColorWriteEnabled` | `bool get isColorWriteEnabled` | Indicates whether instances of this material write into the color buffer. |
| `isDepthWriteEnabled` | `bool get isDepthWriteEnabled` | Indicates whether instances of this material write into the depth buffer. |
| `isDepthCullingEnabled` | `bool get isDepthCullingEnabled` | Indicates whether depth testing is enabled. |
| `isDoubleSided` | `bool get isDoubleSided` | Indicates whether this material is double-sided. |
| `isAlphaToCoverageEnabled` | `bool get isAlphaToCoverageEnabled` | Indicates whether this material uses alpha-to-coverage. |
| `maskThreshold` | `double get maskThreshold` | Mask threshold alpha cutoff value. |
| `hasShadowMultiplier` | `bool get hasShadowMultiplier` | Indicates whether this material has a shadow multiplier. |
| `hasSpecularAntiAliasing` | `bool get hasSpecularAntiAliasing` | Indicates whether specular anti-aliasing is enabled. |
| `specularAntiAliasingVariance` | `double get specularAntiAliasingVariance` | Specular anti-aliasing screen-space variance. |
| `specularAntiAliasingThreshold` | `double get specularAntiAliasingThreshold` | Specular anti-aliasing clamping threshold. |
| `requiredAttributes` | `Set<VertexAttribute> get requiredAttributes` | Set of vertex attributes required by this material. |
| `refractionMode` | `RefractionMode get refractionMode` | Refraction mode used by this material. |
| `refractionType` | `RefractionType get refractionType` | Refraction type used by this material. |
| `reflectionMode` | `ReflectionMode get reflectionMode` | Reflection mode used by this material. |
| `featureLevel` | `int get featureLevel` | Minimum required feature level. |
| `name` | `String get name` | Material name. |
| `dispose` | `void dispose()` | Destroys this Material. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentMaterialInstance`

An instance of a [FilamentMaterial] with its own parameter values.

**Yapıcı Metotlar (Constructors):**
- `FilamentMaterialInstance.internal(this._ptr, this._engine, [this._parentMaterial, this._borrowed = false])`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `setBool` | `void setBool(String name, bool value)` | Sets a boolean parameter value. |
| `setBool2` | `void setBool2(String name, bool x, bool y)` | Sets a 2-component boolean vector parameter value. |
| `setBool3` | `void setBool3(String name, bool x, bool y, bool z)` | Sets a 3-component boolean vector parameter value. |
| `setBool4` | `void setBool4(String name, bool x, bool y, bool z, bool w)` | Sets a 4-component boolean vector parameter value. |
| `setInt` | `void setInt(String name, int value)` | Sets an integer parameter value. |
| `setInt2` | `void setInt2(String name, int x, int y)` | Sets a 2-component integer vector parameter value. |
| `setInt3` | `void setInt3(String name, int x, int y, int z)` | Sets a 3-component integer vector parameter value. |
| `setInt4` | `void setInt4(String name, int x, int y, int z, int w)` | Sets a 4-component integer vector parameter value. |
| `setUint` | `void setUint(String name, int value)` | Sets a unsigned integer parameter value. |
| `setUint2` | `void setUint2(String name, int x, int y)` | Sets a 2-component unsigned integer vector parameter value. |
| `setUint3` | `void setUint3(String name, int x, int y, int z)` | Sets a 3-component unsigned integer vector parameter value. |
| `setUint4` | `void setUint4(String name, int x, int y, int z, int w)` | Sets a 4-component unsigned integer vector parameter value. |
| `setFloat` | `void setFloat(String name, double value)` | Sets a scalar float parameter value. |
| `setFloat2` | `void setFloat2(String name, double x, double y)` | Sets a 2-component vector parameter value. |
| `setFloat3` | `void setFloat3(String name, double x, double y, double z)` | Sets a 3-component vector parameter value. |
| `setFloat4` | `void setFloat4(String name, double x, double y, double z, double w)` | Sets a 4-component vector / color parameter value. |
| `setFloatArray` | `void setFloatArray(String name, Float32List values)` | Sets an array of float parameters. |
| `setFloat2Array` | `void setFloat2Array(String name, Float32List values)` | Sets an array of float2 parameters. |
| `setFloat3Array` | `void setFloat3Array(String name, Float32List values)` | Sets an array of float3 parameters. Note: expected 3 floats (12 bytes) per element. |
| `setFloat4Array` | `void setFloat4Array(String name, Float32List values)` | Sets an array of float4 parameters. |
| `setIntArray` | `void setIntArray(String name, Int32List values)` | Sets an array of int parameters. |
| `setMat3` | `void setMat3(String name, List<double> matrix9)` | Sets a 3x3 matrix parameter value (9 floats column-major). |
| `setMat4` | `void setMat4(String name, List<double> matrix16)` | Sets a 4x4 matrix parameter value (16 floats column-major). |
| `setMat3Array` | `void setMat3Array(String name, Float32List values)` | Sets an array of mat3 parameters (9 floats per matrix). |
| `setMat4Array` | `void setMat4Array(String name, Float32List values)` | Sets an array of mat4 parameters (16 floats per matrix, e.g. for bone palettes). |
| `setColor` | `void setColor(String name, RgbType type, double r, double g, double b)` | Sets a color parameter using a specific RGB color space. |
| `setColorRgba` | `void setColorRgba(String name, RgbaType type, double r, double g, double...` | Sets a color parameter using a specific RGBA color space. |
| `cullingMode` | `CullingMode get cullingMode` | Gets the face culling mode. |
| `setCullingMode` | `void setCullingMode(CullingMode mode)` | Sets the face culling mode for all passes. |
| `setCullingModeSeparate` | `void setCullingModeSeparate(CullingMode colorPassMode, CullingMode shado...` | Sets the face culling mode separately for the color pass and shadow pass. |
| `isDoubleSided` | `bool get isDoubleSided` | Gets whether this instance is double sided. |
| `setDoubleSided` | `void setDoubleSided(bool doubleSided)` | Sets whether this instance is double sided.  Note: Setting this to true disables culling inside Filament. Calling `setCullingMode` afterwards re-overrides this behavior. |
| `isColorWriteEnabled` | `bool get isColorWriteEnabled` | Gets whether color write is enabled. |
| `setColorWrite` | `void setColorWrite(bool enable)` | Enables or disables writing into the color buffer. |
| `isDepthWriteEnabled` | `bool get isDepthWriteEnabled` | Gets whether depth write is enabled. |
| `setDepthWrite` | `void setDepthWrite(bool enable)` | Enables or disables writing into the depth buffer. |
| `isDepthCullingEnabled` | `bool get isDepthCullingEnabled` | Gets whether depth culling is enabled. |
| `setDepthCulling` | `void setDepthCulling(bool enable)` | Enables or disables depth testing (culling). |
| `depthFunc` | `DepthFunc get depthFunc` | Gets the depth comparison function. |
| `setDepthFunc` | `void setDepthFunc(DepthFunc func)` | Sets the depth comparison function. |
| `transparencyMode` | `TransparencyMode get transparencyMode` | Gets the transparency mode. |
| `setTransparencyMode` | `void setTransparencyMode(TransparencyMode mode)` | Sets the transparency mode. |
| `maskThreshold` | `double get maskThreshold` | Gets the mask threshold (alpha cutoff). |
| `setMaskThreshold` | `void setMaskThreshold(double threshold)` | Sets the mask threshold (alpha cutoff). Only affects materials built with `blending: masked`. |
| `setPolygonOffset` | `void setPolygonOffset(double scale, double constant)` | Sets the polygon offset for this instance (useful for decals). |
| `unsetScissor` | `void unsetScissor()` | Removes the custom scissor rectangle, reverting to the view's viewport. |
| `setStencilWrite` | `void setStencilWrite(bool enabled)` | Sets whether stencil buffer writing is enabled for this instance. |
| `isStencilWriteEnabled` | `bool get isStencilWriteEnabled` | Gets whether stencil buffer writing is enabled for this instance. |
| `setConstantInt` | `void setConstantInt(String name, int value)` | Sets a specialization constant of integer type. |
| `setConstantFloat` | `void setConstantFloat(String name, double value)` | Sets a specialization constant of float type. |
| `setConstantBool` | `void setConstantBool(String name, bool value)` | Sets a specialization constant of boolean type. |
| `getFloat` | `double getFloat(String name)` | Reads a float parameter value. |
| `getInt` | `int getInt(String name)` | Reads an integer parameter value. |
| `getUint` | `int getUint(String name)` | Reads an unsigned integer parameter value. |
| `getBool` | `bool getBool(String name)` | Reads a boolean parameter value. |
| `getMat4` | `Float32List getMat4(String name)` | Reads a 4x4 float matrix parameter value. |
| `material` | `FilamentMaterial get material` | The parent [FilamentMaterial] of this instance. |
| `name` | `String get name` | The name of this material instance. |
| `setSpecularAntiAliasingVariance` | `void setSpecularAntiAliasingVariance(double variance)` | Sets the specular anti-aliasing variance. |
| `specularAntiAliasingVariance` | `double get specularAntiAliasingVariance` | Gets the specular anti-aliasing variance. |
| `setSpecularAntiAliasingThreshold` | `void setSpecularAntiAliasingThreshold(double threshold)` | Sets the specular anti-aliasing threshold. |
| `specularAntiAliasingThreshold` | `double get specularAntiAliasingThreshold` | Gets the specular anti-aliasing threshold. |
| `dispose` | `void dispose()` | Destroys this MaterialInstance. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: Işıklandırma ve image-based lighting](lighting-and-ibl.md) | [Üst: flutter_filament](index.md) | [Sonraki: Texture'lar ve görseller](textures-and-images.md)
