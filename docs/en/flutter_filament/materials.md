[Türkçe](../../tr/flutter_filament/materials.md)

# Materials

Loading compiled materials, creating material instances and setting their parameters and render state, and building new materials at run time with the filamat material builder. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/filamat_c.h`](#srcfilamat_ch)
  - [`src/material_c.h`](#srcmaterial_ch)
  - [`src/material_instance_c.h`](#srcmaterial_instance_ch)
- [Dart API](#dart-api)
  - [`lib/src/filamat_builder.dart`](#libsrcfilamat_builderdart)
  - [`lib/src/material.dart`](#libsrcmaterialdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/filamat_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_filamat_init` | `FFI_PLUGIN_EXPORT void filament_filamat_init(void);` | Executes native Filament `filament_filamat_init` C binding. |
| `filament_filamat_shutdown` | `FFI_PLUGIN_EXPORT void filament_filamat_shutdown(void);` | Executes native Filament `filament_filamat_shutdown` C binding. |
| `filament_material_builder_create` | `FFI_PLUGIN_EXPORT void* filament_material_builder_create(void);` | Allocates and initializes the native Filament `filament_material_builder_create` resource on the engine/GPU. |
| `filament_material_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_material_builder_destroy(void* buil...` | Destroys the native Filament `filament_material_builder_destroy` resource and releases GPU/host memory. |
| `filament_material_builder_set_name` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_name(void* bui...` | Updates the `filament_material_builder_set_name` parameter or state in the native C layer. |
| `filament_material_builder_set_code` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_code(void* bui...` | Updates the `filament_material_builder_set_code` parameter or state in the native C layer. |
| `filament_material_builder_set_double_sided` | `FFI_PLUGIN_EXPORT void filament_material_builder_set_double_sided(v...` | Updates the `filament_material_builder_set_double_sided` parameter or state in the native C layer. |
| `filament_material_builder_parameter` | `FFI_PLUGIN_EXPORT void filament_material_builder_parameter(void* bu...` | Executes native Filament `filament_material_builder_parameter` C binding. |
| `filament_material_builder_parameter_array` | `FFI_PLUGIN_EXPORT void filament_material_builder_parameter_array(vo...` | Executes native Filament `filament_material_builder_parameter_array` C binding. |
| `filament_material_builder_constant_bool` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_bool(void...` | Executes native Filament `filament_material_builder_constant_bool` C binding. |
| `filament_material_builder_constant_int` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_int(void*...` | Executes native Filament `filament_material_builder_constant_int` C binding. |
| `filament_material_builder_constant_float` | `FFI_PLUGIN_EXPORT void filament_material_builder_constant_float(voi...` | Executes native Filament `filament_material_builder_constant_float` C binding. |
| `filament_material_builder_material_vertex` | `FFI_PLUGIN_EXPORT void filament_material_builder_material_vertex(vo...` | Executes native Filament `filament_material_builder_material_vertex` C binding. |
| `filament_material_builder_variable` | `FFI_PLUGIN_EXPORT void filament_material_builder_variable(void* bui...` | Executes native Filament `filament_material_builder_variable` C binding. |
| `filament_material_builder_variable_precision` | `FFI_PLUGIN_EXPORT void filament_material_builder_variable_precision...` | Executes native Filament `filament_material_builder_variable_precision` C binding. |
| `filament_material_builder_vertex_domain` | `FFI_PLUGIN_EXPORT void filament_material_builder_vertex_domain(void...` | Executes native Filament `filament_material_builder_vertex_domain` C binding. |
| `filament_material_builder_vertex_domain_device_jittered` | `FFI_PLUGIN_EXPORT void filament_material_builder_vertex_domain_devi...` | Executes native Filament `filament_material_builder_vertex_domain_device_jittered` C binding. |
| `filament_material_builder_flip_uv` | `FFI_PLUGIN_EXPORT void filament_material_builder_flip_uv(void* buil...` | Executes native Filament `filament_material_builder_flip_uv` C binding. |
| `filament_material_builder_blending` | `FFI_PLUGIN_EXPORT void filament_material_builder_blending(void* bui...` | Executes native Filament `filament_material_builder_blending` C binding. |
| `filament_material_builder_custom_blend_functions` | `FFI_PLUGIN_EXPORT void filament_material_builder_custom_blend_funct...` | Executes native Filament `filament_material_builder_custom_blend_functions` C binding. |
| `filament_material_builder_post_lighting_blending` | `FFI_PLUGIN_EXPORT void filament_material_builder_post_lighting_blen...` | Executes native Filament `filament_material_builder_post_lighting_blending` C binding. |
| `filament_material_builder_transparency_mode` | `FFI_PLUGIN_EXPORT void filament_material_builder_transparency_mode(...` | Executes native Filament `filament_material_builder_transparency_mode` C binding. |
| `filament_material_builder_mask_threshold` | `FFI_PLUGIN_EXPORT void filament_material_builder_mask_threshold(voi...` | Executes native Filament `filament_material_builder_mask_threshold` C binding. |
| `filament_material_builder_alpha_to_coverage` | `FFI_PLUGIN_EXPORT void filament_material_builder_alpha_to_coverage(...` | Executes native Filament `filament_material_builder_alpha_to_coverage` C binding. |
| `filament_material_builder_refraction_mode` | `FFI_PLUGIN_EXPORT void filament_material_builder_refraction_mode(vo...` | Executes native Filament `filament_material_builder_refraction_mode` C binding. |
| `filament_material_builder_refraction_type` | `FFI_PLUGIN_EXPORT void filament_material_builder_refraction_type(vo...` | Executes native Filament `filament_material_builder_refraction_type` C binding. |
| `filament_material_builder_culling` | `FFI_PLUGIN_EXPORT void filament_material_builder_culling(void* buil...` | Executes native Filament `filament_material_builder_culling` C binding. |
| `filament_material_builder_color_write` | `FFI_PLUGIN_EXPORT void filament_material_builder_color_write(void* ...` | Executes native Filament `filament_material_builder_color_write` C binding. |
| `filament_material_builder_depth_write` | `FFI_PLUGIN_EXPORT void filament_material_builder_depth_write(void* ...` | Executes native Filament `filament_material_builder_depth_write` C binding. |
| `filament_material_builder_depth_culling` | `FFI_PLUGIN_EXPORT void filament_material_builder_depth_culling(void...` | Executes native Filament `filament_material_builder_depth_culling` C binding. |
| `filament_material_builder_instanced` | `FFI_PLUGIN_EXPORT void filament_material_builder_instanced(void* bu...` | Executes native Filament `filament_material_builder_instanced` C binding. |
| `filament_material_builder_material_domain` | `FFI_PLUGIN_EXPORT void filament_material_builder_material_domain(vo...` | Executes native Filament `filament_material_builder_material_domain` C binding. |
| `filament_material_builder_group_size` | `FFI_PLUGIN_EXPORT void filament_material_builder_group_size(void* b...` | Executes native Filament `filament_material_builder_group_size` C binding. |
| `filament_material_builder_output` | `FFI_PLUGIN_EXPORT void filament_material_builder_output(void* build...` | Executes native Filament `filament_material_builder_output` C binding. |
| `filament_material_builder_enable_framebuffer_fetch` | `FFI_PLUGIN_EXPORT void filament_material_builder_enable_framebuffer...` | Executes native Filament `filament_material_builder_enable_framebuffer_fetch` C binding. |
| `filament_material_builder_subpass` | `FFI_PLUGIN_EXPORT void filament_material_builder_subpass(void* buil...` | Executes native Filament `filament_material_builder_subpass` C binding. |
| `filament_material_builder_platform` | `FFI_PLUGIN_EXPORT void filament_material_builder_platform(void* bui...` | Executes native Filament `filament_material_builder_platform` C binding. |
| `filament_material_builder_target_api` | `FFI_PLUGIN_EXPORT void filament_material_builder_target_api(void* b...` | Queries the `filament_material_builder_target_api` state, property, or counter from the native C layer. |
| `filament_material_builder_optimization` | `FFI_PLUGIN_EXPORT void filament_material_builder_optimization(void*...` | Executes native Filament `filament_material_builder_optimization` C binding. |
| `filament_material_builder_variant_filter` | `FFI_PLUGIN_EXPORT void filament_material_builder_variant_filter(voi...` | Executes native Filament `filament_material_builder_variant_filter` C binding. |
| *... and 23 additional native C functions* | - | Library FFI bindings. |

### `src/material_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_material_create` | `FFI_PLUGIN_EXPORT void* filament_material_create(void* engine, cons...` | Allocates and initializes the native Filament `filament_material_create` resource on the engine/GPU. |
| `filament_material_create_ex` | `FFI_PLUGIN_EXPORT void* filament_material_create_ex( void* engine, ...` | Allocates and initializes the native Filament `filament_material_create_ex` resource on the engine/GPU. |
| `filament_material_create_instance` | `FFI_PLUGIN_EXPORT void* filament_material_create_instance(void* mat...` | Allocates and initializes the native Filament `filament_material_create_instance` resource on the engine/GPU. |
| `filament_material_create_instance_with_name` | `FFI_PLUGIN_EXPORT void* filament_material_create_instance_with_name...` | Allocates and initializes the native Filament `filament_material_create_instance_with_name` resource on the engine/GPU. |
| `filament_material_get_default_instance` | `FFI_PLUGIN_EXPORT void* filament_material_get_default_instance(void...` | Queries the `filament_material_get_default_instance` state, property, or counter from the native C layer. |
| `filament_engine_destroy_material` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_material(void* engin...` | Destroys the native Filament `filament_engine_destroy_material` resource and releases GPU/host memory. |
| `filament_material_compile` | `FFI_PLUGIN_EXPORT void filament_material_compile(void* material, in...` | Executes native Filament `filament_material_compile` C binding. |
| `filament_material_get_parameter_count` | `FFI_PLUGIN_EXPORT size_t filament_material_get_parameter_count(void...` | Queries the `filament_material_get_parameter_count` state, property, or counter from the native C layer. |
| `filament_material_get_parameters` | `FFI_PLUGIN_EXPORT size_t filament_material_get_parameters(void* mat...` | Queries the `filament_material_get_parameters` state, property, or counter from the native C layer. |
| `filament_material_has_parameter` | `FFI_PLUGIN_EXPORT bool filament_material_has_parameter(void* materi...` | Validates or queries the `filament_material_has_parameter` state/capability. |
| `filament_material_is_sampler` | `FFI_PLUGIN_EXPORT bool filament_material_is_sampler(void* material,...` | Validates or queries the `filament_material_is_sampler` state/capability. |
| `filament_material_get_parameter_transform_name` | `FFI_PLUGIN_EXPORT const char* filament_material_get_parameter_trans...` | Queries the `filament_material_get_parameter_transform_name` state, property, or counter from the native C layer. |
| `filament_material_set_default_parameter_bool` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_bool...` | Updates the `filament_material_set_default_parameter_bool` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_int` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_int(...` | Updates the `filament_material_set_default_parameter_int` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_float` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | Updates the `filament_material_set_default_parameter_float` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_float2` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | Updates the `filament_material_set_default_parameter_float2` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_float3` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | Updates the `filament_material_set_default_parameter_float3` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_float4` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_floa...` | Updates the `filament_material_set_default_parameter_float4` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_mat3` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat3...` | Updates the `filament_material_set_default_parameter_mat3` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_mat4` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_mat4...` | Updates the `filament_material_set_default_parameter_mat4` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_texture` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_text...` | Updates the `filament_material_set_default_parameter_texture` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_rgb` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgb(...` | Updates the `filament_material_set_default_parameter_rgb` parameter or state in the native C layer. |
| `filament_material_set_default_parameter_rgba` | `FFI_PLUGIN_EXPORT void filament_material_set_default_parameter_rgba...` | Updates the `filament_material_set_default_parameter_rgba` parameter or state in the native C layer. |
| `filament_material_get_shading` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_shading(void* mater...` | Queries the `filament_material_get_shading` state, property, or counter from the native C layer. |
| `filament_material_get_interpolation` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_interpolation(void*...` | Queries the `filament_material_get_interpolation` state, property, or counter from the native C layer. |
| `filament_material_get_blending_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_blending_mode(void*...` | Queries the `filament_material_get_blending_mode` state, property, or counter from the native C layer. |
| `filament_material_get_vertex_domain` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_vertex_domain(void*...` | Queries the `filament_material_get_vertex_domain` state, property, or counter from the native C layer. |
| `filament_material_get_material_domain` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_material_domain(voi...` | Queries the `filament_material_get_material_domain` state, property, or counter from the native C layer. |
| `filament_material_get_culling_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_culling_mode(void* ...` | Queries the `filament_material_get_culling_mode` state, property, or counter from the native C layer. |
| `filament_material_get_transparency_mode` | `FFI_PLUGIN_EXPORT int32_t filament_material_get_transparency_mode(v...` | Queries the `filament_material_get_transparency_mode` state, property, or counter from the native C layer. |
| `filament_material_is_color_write_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_color_write_enabled(voi...` | Validates or queries the `filament_material_is_color_write_enabled` state/capability. |
| `filament_material_is_depth_write_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_depth_write_enabled(voi...` | Validates or queries the `filament_material_is_depth_write_enabled` state/capability. |
| `filament_material_is_depth_culling_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_depth_culling_enabled(v...` | Validates or queries the `filament_material_is_depth_culling_enabled` state/capability. |
| `filament_material_is_double_sided` | `FFI_PLUGIN_EXPORT bool filament_material_is_double_sided(void* mate...` | Validates or queries the `filament_material_is_double_sided` state/capability. |
| `filament_material_is_alpha_to_coverage_enabled` | `FFI_PLUGIN_EXPORT bool filament_material_is_alpha_to_coverage_enabl...` | Validates or queries the `filament_material_is_alpha_to_coverage_enabled` state/capability. |
| `filament_material_get_mask_threshold` | `FFI_PLUGIN_EXPORT float filament_material_get_mask_threshold(void* ...` | Queries the `filament_material_get_mask_threshold` state, property, or counter from the native C layer. |
| `filament_material_has_shadow_multiplier` | `FFI_PLUGIN_EXPORT bool filament_material_has_shadow_multiplier(void...` | Validates or queries the `filament_material_has_shadow_multiplier` state/capability. |
| `filament_material_has_specular_anti_aliasing` | `FFI_PLUGIN_EXPORT bool filament_material_has_specular_anti_aliasing...` | Validates or queries the `filament_material_has_specular_anti_aliasing` state/capability. |
| `filament_material_get_specular_anti_aliasing_variance` | `FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasin...` | Queries the `filament_material_get_specular_anti_aliasing_variance` state, property, or counter from the native C layer. |
| `filament_material_get_specular_anti_aliasing_threshold` | `FFI_PLUGIN_EXPORT float filament_material_get_specular_anti_aliasin...` | Queries the `filament_material_get_specular_anti_aliasing_threshold` state, property, or counter from the native C layer. |
| *... and 6 additional native C functions* | - | Library FFI bindings. |

### `src/material_instance_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_material_instance_duplicate` | `FFI_PLUGIN_EXPORT void* filament_material_instance_duplicate(void* ...` | Executes native Filament `filament_material_instance_duplicate` C binding. |
| `filament_material_instance_set_bool` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool(void* mi...` | Updates the `filament_material_instance_set_bool` parameter or state in the native C layer. |
| `filament_material_instance_set_bool2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool2(void* m...` | Updates the `filament_material_instance_set_bool2` parameter or state in the native C layer. |
| `filament_material_instance_set_bool3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool3(void* m...` | Updates the `filament_material_instance_set_bool3` parameter or state in the native C layer. |
| `filament_material_instance_set_bool4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_bool4(void* m...` | Updates the `filament_material_instance_set_bool4` parameter or state in the native C layer. |
| `filament_material_instance_set_int` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int(void* mi,...` | Updates the `filament_material_instance_set_int` parameter or state in the native C layer. |
| `filament_material_instance_set_int2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int2(void* mi...` | Updates the `filament_material_instance_set_int2` parameter or state in the native C layer. |
| `filament_material_instance_set_int3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int3(void* mi...` | Updates the `filament_material_instance_set_int3` parameter or state in the native C layer. |
| `filament_material_instance_set_int4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int4(void* mi...` | Updates the `filament_material_instance_set_int4` parameter or state in the native C layer. |
| `filament_material_instance_set_uint` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint(void* mi...` | Updates the `filament_material_instance_set_uint` parameter or state in the native C layer. |
| `filament_material_instance_set_uint2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint2(void* m...` | Updates the `filament_material_instance_set_uint2` parameter or state in the native C layer. |
| `filament_material_instance_set_uint3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint3(void* m...` | Updates the `filament_material_instance_set_uint3` parameter or state in the native C layer. |
| `filament_material_instance_set_uint4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_uint4(void* m...` | Updates the `filament_material_instance_set_uint4` parameter or state in the native C layer. |
| `filament_material_instance_set_float` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float(void* m...` | Updates the `filament_material_instance_set_float` parameter or state in the native C layer. |
| `filament_material_instance_set_float2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float2(void* ...` | Updates the `filament_material_instance_set_float2` parameter or state in the native C layer. |
| `filament_material_instance_set_float3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float3(void* ...` | Updates the `filament_material_instance_set_float3` parameter or state in the native C layer. |
| `filament_material_instance_set_float4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float4(void* ...` | Updates the `filament_material_instance_set_float4` parameter or state in the native C layer. |
| `filament_material_instance_set_mat3` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3(void* mi...` | Updates the `filament_material_instance_set_mat3` parameter or state in the native C layer. |
| `filament_material_instance_set_mat4` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4(void* mi...` | Updates the `filament_material_instance_set_mat4` parameter or state in the native C layer. |
| `filament_material_instance_set_float_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float_array(v...` | Updates the `filament_material_instance_set_float_array` parameter or state in the native C layer. |
| `filament_material_instance_set_float2_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float2_array(...` | Updates the `filament_material_instance_set_float2_array` parameter or state in the native C layer. |
| `filament_material_instance_set_float3_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float3_array(...` | Updates the `filament_material_instance_set_float3_array` parameter or state in the native C layer. |
| `filament_material_instance_set_float4_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_float4_array(...` | Updates the `filament_material_instance_set_float4_array` parameter or state in the native C layer. |
| `filament_material_instance_set_int_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_int_array(voi...` | Updates the `filament_material_instance_set_int_array` parameter or state in the native C layer. |
| `filament_material_instance_set_mat3_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat3_array(vo...` | Updates the `filament_material_instance_set_mat3_array` parameter or state in the native C layer. |
| `filament_material_instance_set_mat4_array` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mat4_array(vo...` | Updates the `filament_material_instance_set_mat4_array` parameter or state in the native C layer. |
| `filament_material_instance_set_rgb` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_rgb(void* mi,...` | Updates the `filament_material_instance_set_rgb` parameter or state in the native C layer. |
| `filament_material_instance_set_rgba` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_rgba(void* mi...` | Updates the `filament_material_instance_set_rgba` parameter or state in the native C layer. |
| `filament_material_instance_set_texture` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_texture(void*...` | Updates the `filament_material_instance_set_texture` parameter or state in the native C layer. |
| `filament_material_instance_set_texture_ex` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_texture_ex(vo...` | Updates the `filament_material_instance_set_texture_ex` parameter or state in the native C layer. |
| `filament_material_instance_set_culling_mode` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode(...` | Updates the `filament_material_instance_set_culling_mode` parameter or state in the native C layer. |
| `filament_material_instance_set_culling_mode2` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_culling_mode2...` | Updates the `filament_material_instance_set_culling_mode2` parameter or state in the native C layer. |
| `filament_material_instance_set_double_sided` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_double_sided(...` | Updates the `filament_material_instance_set_double_sided` parameter or state in the native C layer. |
| `filament_material_instance_set_color_write` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_color_write(v...` | Updates the `filament_material_instance_set_color_write` parameter or state in the native C layer. |
| `filament_material_instance_set_depth_write` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_write(v...` | Updates the `filament_material_instance_set_depth_write` parameter or state in the native C layer. |
| `filament_material_instance_set_depth_culling` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_culling...` | Updates the `filament_material_instance_set_depth_culling` parameter or state in the native C layer. |
| `filament_material_instance_set_depth_func` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_depth_func(vo...` | Updates the `filament_material_instance_set_depth_func` parameter or state in the native C layer. |
| `filament_material_instance_set_transparency_mode` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_transparency_...` | Updates the `filament_material_instance_set_transparency_mode` parameter or state in the native C layer. |
| `filament_material_instance_set_mask_threshold` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_mask_threshol...` | Updates the `filament_material_instance_set_mask_threshold` parameter or state in the native C layer. |
| `filament_material_instance_set_polygon_offset` | `FFI_PLUGIN_EXPORT void filament_material_instance_set_polygon_offse...` | Updates the `filament_material_instance_set_polygon_offset` parameter or state in the native C layer. |
| *... and 39 additional native C functions* | - | Library FFI bindings. |

## Dart API

### `lib/src/filamat_builder.dart`

#### `enum FilamatShading`

Shading models for runtime GLSL materials.

**Constructors:**
- `FilamatShading(this.value)`: Initializes `FilamatShading(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `specularGlossiness` | `specularGlossiness(4)` | Executes `specularGlossiness` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum MaterialDomain`

Material domain for shaders.

**Constructors:**
- `MaterialDomain(this.value)`: Initializes `MaterialDomain(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `compute` | `compute(2)` | Executes `compute` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum BlendingMode`

Supported blending modes.

**Constructors:**
- `BlendingMode(this.value)`: Initializes `BlendingMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `custom` | `custom(7)` | Executes `custom` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum BlendFunction`

Blending functions for custom blend modes.

**Constructors:**
- `BlendFunction(this.value)`: Initializes `BlendFunction(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `srcAlphaSaturate` | `srcAlphaSaturate(10)` | Executes `srcAlphaSaturate` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum RefractionMode`

Refraction modes.

**Constructors:**
- `RefractionMode(this.value)`: Initializes `RefractionMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `screenSpace` | `screenSpace(2)` | Executes `screenSpace` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum RefractionType`

Refraction types.

**Constructors:**
- `RefractionType(this.value)`: Initializes `RefractionType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `thin` | `thin(1)` | Executes `thin` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ReflectionMode`

Reflection modes.

**Constructors:**
- `ReflectionMode(this.value)`: Initializes `ReflectionMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `screenSpace` | `screenSpace(1)` | Executes `screenSpace` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum SpecularAOMode`

Specular ambient occlusion modes.

**Constructors:**
- `SpecularAOMode(this.value)`: Initializes `SpecularAOMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bentNormals` | `bentNormals(2)` | Executes `bentNormals` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum MaterialVariable`

Custom interpolant variables for vertex-to-fragment communication.

**Constructors:**
- `MaterialVariable(this.value)`: Initializes `MaterialVariable(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `custom4` | `custom4(4)` | Executes `custom4` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum VertexDomain`

Types of vertex domains.

**Constructors:**
- `VertexDomain(this.value)`: Initializes `VertexDomain(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `device` | `device(3)` | Executes `device` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum MaterialPlatform`

Target platforms.

**Constructors:**
- `MaterialPlatform(this.value)`: Initializes `MaterialPlatform(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `all` | `all(2)` | Executes `all` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum TargetApi`

Target API / language representations.

**Constructors:**
- `TargetApi(this.value)`: Initializes `TargetApi(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `all` | `all(0x07)` | Executes `all` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum OptimizationLevel`

Shader optimization levels.

**Constructors:**
- `OptimizationLevel(this.value)`: Initializes `OptimizationLevel(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `performance` | `performance(3)` | Executes `performance` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum OutputTarget`

Target buffer for post-process outputs.

**Constructors:**
- `OutputTarget(this.value)`: Initializes `OutputTarget(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `depth` | `depth(1)` | Executes `depth` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum OutputType`

Data type for fragment shader outputs.

**Constructors:**
- `OutputType(this.value)`: Initializes `OutputType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `uint4` | `uint4(11)` | Executes `uint4` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum VariableQualifier`

Variable qualifiers for post-process outputs.

**Constructors:**
- `VariableQualifier(this.value)`: Initializes `VariableQualifier(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `out_` | `out_(0)` | Executes `out_` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ShaderQuality`

Shader quality levels.

**Constructors:**
- `ShaderQuality(this.value)`: Initializes `ShaderQuality(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `high` | `high(2)` | Executes `high` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum Interpolation`

Interpolation mode for attributes in fragment shader.

**Constructors:**
- `Interpolation(this.value)`: Initializes `Interpolation(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `flat` | `flat(1)` | Executes `flat` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class UserVariantFilterBit`

Bitmask constants for user variant filtering.

#### `class FilamentMaterialBuilder`

Dynamically builds and compiles GLSL material shaders into binary `.filamat` packages at runtime.

**Constructors:**
- `FilamentMaterialBuilder._(this._ptr)`: Initializes `FilamentMaterialBuilder._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/material.dart`

**Top-level Functions:**

- **`int filamentExpectedMaterialVersion`**: Represents a compiled Filament material. The material package version this engine build accepts.  A compiled `.filamat` carries its version in its header; if the two differ the engine refuses the material at load time. It logs and carries on, so the only visible symptom is that whatever used the material renders nothing — check this instead of trusting a successful load.
- **`int filamentMaterialPackageVersion(Uint8List package)`**: The version recorded in a compiled `.filamat` package's header.

#### `class MaterialConstant`

Specialization constant for material compilation.

**Constructors:**
- `MaterialConstant._(this.name)`: Initializes `MaterialConstant._(this.name)`.
- `MaterialConstant.int32(String name, int value)`: Initializes `MaterialConstant.int32(String name, int value)`.
- `MaterialConstant.float(String name, double value)`: Initializes `MaterialConstant.float(String name, double value)`.
- `MaterialConstant.bool_(String name, bool value)`: Initializes `MaterialConstant.bool_(String name, bool value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |

#### `class _Int32MaterialConstant`

`_Int32MaterialConstant`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_Int32MaterialConstant(super.name, this.value) : super._()`: Initializes `_Int32MaterialConstant(super.name, this.value) : super._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class _FloatMaterialConstant`

`_FloatMaterialConstant`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_FloatMaterialConstant(super.name, this.value) : super._()`: Initializes `_FloatMaterialConstant(super.name, this.value) : super._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `double value` | Holds the `value` property or configuration state. |

#### `class _BoolMaterialConstant`

`_BoolMaterialConstant`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_BoolMaterialConstant(super.name, this.value) : super._()`: Initializes `_BoolMaterialConstant(super.name, this.value) : super._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `bool value` | Holds the `value` property or configuration state. |

#### `enum ShadowSamplingQuality`

Quality of shadow sampling for material builders.

**Constructors:**
- `ShadowSamplingQuality(this.value)`: Initializes `ShadowSamplingQuality(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ultra` | `ultra(3)` | Executes `ultra` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class MaterialParameter`

Holds reflected information about a [FilamentMaterial] parameter.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `isSampler` | `bool isSampler` | Holds the `isSampler` property or configuration state. |
| `isSubpass` | `bool isSubpass` | Holds the `isSubpass` property or configuration state. |
| `uniformType` | `UniformType? uniformType` | Holds the `uniformType` property or configuration state. |
| `samplerType` | `TextureSamplerType? samplerType` | Holds the `samplerType` property or configuration state. |
| `count` | `int count` | Holds the `count` property or configuration state. |
| `precision` | `ParameterPrecision precision` | Holds the `precision` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class FilamentMaterial`

`FilamentMaterial`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FilamentMaterial.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentMaterialInstance`

An instance of a [FilamentMaterial] with its own parameter values.

**Constructors:**
- `FilamentMaterialInstance.internal(this._ptr, this._engine, [this._parentMaterial, this._borrowed = false])`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

---

[Previous: Lighting and image-based lighting](lighting-and-ibl.md) | [Up: flutter_filament](index.md) | [Next: Textures and images](textures-and-images.md)
