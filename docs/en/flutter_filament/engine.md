[Türkçe](../../tr/flutter_filament/engine.md)

# Engine, entities and core types

The engine lifecycle and the core object model: creating and destroying a `FilamentEngine` with its `EngineConfig`, entities and the entity and name managers, the enums shared by every builder, fences, the exception type, the callback bridge that carries native callbacks back into Dart, the debug registry and the diagnostics log. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/callback_bridge_c.h`](#srccallback_bridge_ch)
  - [`src/debug_registry_c.h`](#srcdebug_registry_ch)
  - [`src/engine_c.h`](#srcengine_ch)
  - [`src/enum_check_c.h`](#srcenum_check_ch)
  - [`src/fence_c.h`](#srcfence_ch)
  - [`src/utils_c.h`](#srcutils_ch)
- [Dart API](#dart-api)
  - [`lib/src/callback_bridge.dart`](#libsrccallback_bridgedart)
  - [`lib/src/debug_registry.dart`](#libsrcdebug_registrydart)
  - [`lib/src/diagnostics.dart`](#libsrcdiagnosticsdart)
  - [`lib/src/engine.dart`](#libsrcenginedart)
  - [`lib/src/entity.dart`](#libsrcentitydart)
  - [`lib/src/enums.dart`](#libsrcenumsdart)
  - [`lib/src/exceptions.dart`](#libsrcexceptionsdart)
  - [`lib/src/fence.dart`](#libsrcfencedart)
  - [`lib/src/name_component_manager.dart`](#libsrcname_component_managerdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/callback_bridge_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_callback_bridge_init` | `FFI_PLUGIN_EXPORT int32_t filament_callback_bridge_init(filament_ca...` | Executes native Filament `filament_callback_bridge_init` C binding. |
| `filament_callback_bridge_shutdown` | `FFI_PLUGIN_EXPORT void filament_callback_bridge_shutdown(void);` | Executes native Filament `filament_callback_bridge_shutdown` C binding. |
| `filament_callback_envelope_free` | `FFI_PLUGIN_EXPORT void filament_callback_envelope_free(FilamentCall...` | Executes native Filament `filament_callback_envelope_free` C binding. |
| `filament_engine_pump_message_queues` | `FFI_PLUGIN_EXPORT void filament_engine_pump_message_queues(void* en...` | Executes native Filament `filament_engine_pump_message_queues` C binding. |
| `filament_test_callback_fire` | `FFI_PLUGIN_EXPORT void filament_test_callback_fire( uint64_t reques...` | Executes native Filament `filament_test_callback_fire` C binding. |
| `filament_test_callback_fire_async` | `FFI_PLUGIN_EXPORT void filament_test_callback_fire_async( uint64_t ...` | Executes native Filament `filament_test_callback_fire_async` C binding. |

### `src/debug_registry_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_engine_get_debug_registry` | `FFI_PLUGIN_EXPORT void* filament_engine_get_debug_registry(void* en...` | Queries the `filament_engine_get_debug_registry` state, property, or counter from the native C layer. |
| `filament_debug_registry_has_property` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_has_property(void* r...` | Validates or queries the `filament_debug_registry_has_property` state/capability. |
| `filament_debug_registry_set_property_bool` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_bool (v...` | Updates the `filament_debug_registry_set_property_bool` parameter or state in the native C layer. |
| `filament_debug_registry_set_property_int` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_int (vo...` | Updates the `filament_debug_registry_set_property_int` parameter or state in the native C layer. |
| `filament_debug_registry_set_property_float` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float (...` | Updates the `filament_debug_registry_set_property_float` parameter or state in the native C layer. |
| `filament_debug_registry_set_property_float2` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float2(...` | Updates the `filament_debug_registry_set_property_float2` parameter or state in the native C layer. |
| `filament_debug_registry_set_property_float3` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float3(...` | Updates the `filament_debug_registry_set_property_float3` parameter or state in the native C layer. |
| `filament_debug_registry_set_property_float4` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float4(...` | Updates the `filament_debug_registry_set_property_float4` parameter or state in the native C layer. |
| `filament_debug_registry_get_property_bool` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_bool (v...` | Queries the `filament_debug_registry_get_property_bool` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_property_int` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_int (vo...` | Queries the `filament_debug_registry_get_property_int` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_property_float` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float (...` | Queries the `filament_debug_registry_get_property_float` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_property_float2` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float2(...` | Queries the `filament_debug_registry_get_property_float2` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_property_float3` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float3(...` | Queries the `filament_debug_registry_get_property_float3` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_property_float4` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float4(...` | Queries the `filament_debug_registry_get_property_float4` state, property, or counter from the native C layer. |
| `filament_debug_registry_get_data_source` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_data_source(void...` | Queries the `filament_debug_registry_get_data_source` state, property, or counter from the native C layer. |

### `src/engine_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_engine_config_init_default` | `FFI_PLUGIN_EXPORT void filament_engine_config_init_default(filament...` | Executes native Filament `filament_engine_config_init_default` C binding. |
| `filament_engine_create_ex` | `FFI_PLUGIN_EXPORT void* filament_engine_create_ex(int backend, int ...` | Allocates and initializes the native Filament `filament_engine_create_ex` resource on the engine/GPU. |
| `filament_engine_get_config` | `FFI_PLUGIN_EXPORT void filament_engine_get_config(void* engine, fil...` | Queries the `filament_engine_get_config` state, property, or counter from the native C layer. |
| `filament_engine_create` | `FFI_PLUGIN_EXPORT void* filament_engine_create(int backend);` | Allocates and initializes the native Filament `filament_engine_create` resource on the engine/GPU. |
| `filament_engine_destroy` | `FFI_PLUGIN_EXPORT void filament_engine_destroy(void* engine);` | Destroys the native Filament `filament_engine_destroy` resource and releases GPU/host memory. |
| `filament_engine_flush_and_wait` | `FFI_PLUGIN_EXPORT void filament_engine_flush_and_wait(void* engine);` | Pushes queued Filament drawing commands to the GPU command buffer. |
| `filament_engine_get_material_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_material_count(void* e...` | Queries the `filament_engine_get_material_count` state, property, or counter from the native C layer. |
| `filament_engine_get_vertex_buffer_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_vertex_buffer_count(vo...` | Queries the `filament_engine_get_vertex_buffer_count` state, property, or counter from the native C layer. |
| `filament_engine_get_index_buffer_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_index_buffer_count(voi...` | Queries the `filament_engine_get_index_buffer_count` state, property, or counter from the native C layer. |
| `filament_engine_is_valid_renderer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_renderer(void* engi...` | Validates or queries the `filament_engine_is_valid_renderer` state/capability. |
| `filament_engine_is_valid_view` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_view(void* engine, ...` | Validates or queries the `filament_engine_is_valid_view` state/capability. |
| `filament_engine_is_valid_scene` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_scene(void* engine,...` | Validates or queries the `filament_engine_is_valid_scene` state/capability. |
| `filament_engine_is_valid_swap_chain` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_swap_chain(void* en...` | Validates or queries the `filament_engine_is_valid_swap_chain` state/capability. |
| `filament_engine_is_valid_camera` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_camera(void* engine...` | Validates or queries the `filament_engine_is_valid_camera` state/capability. |
| `filament_engine_is_valid_texture` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_texture(void* engin...` | Validates or queries the `filament_engine_is_valid_texture` state/capability. |
| `filament_engine_is_valid_material` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material(void* engi...` | Validates or queries the `filament_engine_is_valid_material` state/capability. |
| `filament_engine_is_valid_material_instance` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material_instance(v...` | Validates or queries the `filament_engine_is_valid_material_instance` state/capability. |
| `filament_engine_is_valid_expensive_material_instance` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_expensive_material_...` | Validates or queries the `filament_engine_is_valid_expensive_material_instance` state/capability. |
| `filament_engine_is_valid_vertex_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_vertex_buffer(void*...` | Validates or queries the `filament_engine_is_valid_vertex_buffer` state/capability. |
| `filament_engine_is_valid_index_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_index_buffer(void* ...` | Validates or queries the `filament_engine_is_valid_index_buffer` state/capability. |
| `filament_engine_is_valid_buffer_object` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_buffer_object(void*...` | Validates or queries the `filament_engine_is_valid_buffer_object` state/capability. |
| `filament_engine_is_valid_skinning_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skinning_buffer(voi...` | Validates or queries the `filament_engine_is_valid_skinning_buffer` state/capability. |
| `filament_engine_is_valid_morph_target_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_morph_target_buffer...` | Queries the `filament_engine_is_valid_morph_target_buffer` state, property, or counter from the native C layer. |
| `filament_engine_is_valid_instance_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_instance_buffer(voi...` | Validates or queries the `filament_engine_is_valid_instance_buffer` state/capability. |
| `filament_engine_is_valid_indirect_light` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_indirect_light(void...` | Validates or queries the `filament_engine_is_valid_indirect_light` state/capability. |
| `filament_engine_is_valid_skybox` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skybox(void* engine...` | Validates or queries the `filament_engine_is_valid_skybox` state/capability. |
| `filament_engine_is_valid_render_target` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_render_target(void*...` | Validates or queries the `filament_engine_is_valid_render_target` state/capability. |
| `filament_engine_is_valid_fence` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_fence(void* engine,...` | Validates or queries the `filament_engine_is_valid_fence` state/capability. |
| `filament_engine_is_valid_color_grading` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_color_grading(void*...` | Validates or queries the `filament_engine_is_valid_color_grading` state/capability. |
| `filament_engine_destroy_entity_components` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_entity_components(vo...` | Destroys the native Filament `filament_engine_destroy_entity_components` resource and releases GPU/host memory. |
| `filament_engine_destroy_morph_target_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_morph_target_buffer(...` | Destroys the native Filament `filament_engine_destroy_morph_target_buffer` resource and releases GPU/host memory. |
| `filament_engine_destroy_fence` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_fence(void* engine, ...` | Destroys the native Filament `filament_engine_destroy_fence` resource and releases GPU/host memory. |
| `filament_engine_destroy_instance_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_instance_buffer(void...` | Destroys the native Filament `filament_engine_destroy_instance_buffer` resource and releases GPU/host memory. |
| `filament_engine_flush` | `FFI_PLUGIN_EXPORT void filament_engine_flush(void* engine);` | Pushes queued Filament drawing commands to the GPU command buffer. |
| `filament_engine_flush_and_wait_timeout` | `FFI_PLUGIN_EXPORT bool filament_engine_flush_and_wait_timeout(void*...` | Pushes queued Filament drawing commands to the GPU command buffer. |
| `filament_engine_execute` | `FFI_PLUGIN_EXPORT void filament_engine_execute(void* engine);` | Executes native Filament `filament_engine_execute` C binding. |
| `filament_engine_set_paused` | `FFI_PLUGIN_EXPORT void filament_engine_set_paused(void* engine, boo...` | Updates the `filament_engine_set_paused` parameter or state in the native C layer. |
| `filament_engine_is_paused` | `FFI_PLUGIN_EXPORT bool filament_engine_is_paused(void* engine);` | Validates or queries the `filament_engine_is_paused` state/capability. |
| `filament_engine_get_steady_clock_time_nano` | `FFI_PLUGIN_EXPORT int64_t filament_engine_get_steady_clock_time_nan...` | Queries the `filament_engine_get_steady_clock_time_nano` state, property, or counter from the native C layer. |
| `filament_engine_get_supported_feature_level` | `FFI_PLUGIN_EXPORT int filament_engine_get_supported_feature_level(v...` | Queries the `filament_engine_get_supported_feature_level` state, property, or counter from the native C layer. |
| *... and 21 additional native C functions* | - | Library FFI bindings. |

### `src/enum_check_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_enum_primitive_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_primitive_type(int32_t ordi...` | Executes native Filament `filament_enum_primitive_type` C binding. |
| `filament_enum_index_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_index_type(int32_t ordinal);` | Executes native Filament `filament_enum_index_type` C binding. |
| `filament_enum_texture_usage` | `FFI_PLUGIN_EXPORT uint32_t filament_enum_texture_usage(int32_t ordi...` | Executes native Filament `filament_enum_texture_usage` C binding. |
| `filament_enum_builder_result` | `FFI_PLUGIN_EXPORT int32_t filament_enum_builder_result(int32_t ordi...` | Executes native Filament `filament_enum_builder_result` C binding. |
| `filament_enum_morph_type` | `FFI_PLUGIN_EXPORT uint32_t filament_enum_morph_type(int32_t ordinal);` | Executes native Filament `filament_enum_morph_type` C binding. |
| `filament_enum_backend` | `FFI_PLUGIN_EXPORT int32_t filament_enum_backend(int32_t ordinal);` | Executes native Filament `filament_enum_backend` C binding. |
| `filament_enum_light_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_light_type(int32_t ordinal);` | Executes native Filament `filament_enum_light_type` C binding. |
| `filament_enum_manipulator_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_manipulator_mode(int32_t or...` | Executes native Filament `filament_enum_manipulator_mode` C binding. |
| `filament_enum_filamat_shading` | `FFI_PLUGIN_EXPORT int32_t filament_enum_filamat_shading(int32_t ord...` | Executes native Filament `filament_enum_filamat_shading` C binding. |
| `filament_enum_texture_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_texture_format(int32_t ordi...` | Executes native Filament `filament_enum_texture_format` C binding. |
| `filament_enum_internal_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_internal_format(int32_t ord...` | Executes native Filament `filament_enum_internal_format` C binding. |
| `filament_enum_sampler_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_sampler_type(int32_t ordinal);` | Executes native Filament `filament_enum_sampler_type` C binding. |
| `filament_enum_texture_swizzle` | `FFI_PLUGIN_EXPORT int32_t filament_enum_texture_swizzle(int32_t ord...` | Executes native Filament `filament_enum_texture_swizzle` C binding. |
| `filament_enum_pixel_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_format(int32_t ordinal);` | Executes native Filament `filament_enum_pixel_format` C binding. |
| `filament_enum_pixel_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_type(int32_t ordinal);` | Executes native Filament `filament_enum_pixel_type` C binding. |
| `filament_enum_attribute_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_attribute_type(int32_t ordi...` | Executes native Filament `filament_enum_attribute_type` C binding. |
| `filament_enum_vertex_attribute` | `FFI_PLUGIN_EXPORT int32_t filament_enum_vertex_attribute(int32_t or...` | Executes native Filament `filament_enum_vertex_attribute` C binding. |
| `filament_enum_uniform_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_uniform_type(int32_t ordinal);` | Executes native Filament `filament_enum_uniform_type` C binding. |
| `filament_enum_precision` | `FFI_PLUGIN_EXPORT int32_t filament_enum_precision(int32_t ordinal);` | Executes native Filament `filament_enum_precision` C binding. |
| `filament_enum_culling_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_culling_mode(int32_t ordinal);` | Executes native Filament `filament_enum_culling_mode` C binding. |
| `filament_enum_depth_func` | `FFI_PLUGIN_EXPORT int32_t filament_enum_depth_func(int32_t ordinal);` | Executes native Filament `filament_enum_depth_func` C binding. |
| `filament_enum_transparency_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_transparency_mode(int32_t o...` | Executes native Filament `filament_enum_transparency_mode` C binding. |

### `src/fence_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_engine_create_fence` | `FFI_PLUGIN_EXPORT void* filament_engine_create_fence(void* engine);` | Allocates and initializes the native Filament `filament_engine_create_fence` resource on the engine/GPU. |
| `filament_fence_wait` | `FFI_PLUGIN_EXPORT int filament_fence_wait(void* fence, int mode, ui...` | Executes native Filament `filament_fence_wait` C binding. |
| `filament_fence_wait_and_destroy` | `FFI_PLUGIN_EXPORT int filament_fence_wait_and_destroy(void* fence, ...` | Destroys the native Filament `filament_fence_wait_and_destroy` resource and releases GPU/host memory. |
| `filament_fence_wait_for_ever` | `FFI_PLUGIN_EXPORT uint64_t filament_fence_wait_for_ever(void);` | Executes native Filament `filament_fence_wait_for_ever` C binding. |

### `src/utils_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_set_panic_handler` | `FFI_PLUGIN_EXPORT void filament_set_panic_handler(FilamentPanicHand...` | Updates the `filament_set_panic_handler` parameter or state in the native C layer. |
| `filament_clear_panic_handler` | `FFI_PLUGIN_EXPORT void filament_clear_panic_handler(void);` | Executes native Filament `filament_clear_panic_handler` C binding. |
| `filament_get_last_panic` | `FFI_PLUGIN_EXPORT bool filament_get_last_panic(char* out_message, s...` | Queries the `filament_get_last_panic` state, property, or counter from the native C layer. |
| `filament_set_log_callback` | `FFI_PLUGIN_EXPORT void filament_set_log_callback(FilamentLogHandler...` | Updates the `filament_set_log_callback` parameter or state in the native C layer. |
| `filament_clear_log_callback` | `FFI_PLUGIN_EXPORT void filament_clear_log_callback(void);` | Executes native Filament `filament_clear_log_callback` C binding. |
| `filament_test_trigger_panic` | `FFI_PLUGIN_EXPORT void filament_test_trigger_panic(void);` | Executes native Filament `filament_test_trigger_panic` C binding. |
| `filament_test_log` | `FFI_PLUGIN_EXPORT void filament_test_log(const char* msg);` | Executes native Filament `filament_test_log` C binding. |
| `filament_free_string` | `FFI_PLUGIN_EXPORT void filament_free_string(char* str);` | Executes native Filament `filament_free_string` C binding. |
| `filament_name_component_manager_create` | `FFI_PLUGIN_EXPORT void* filament_name_component_manager_create(void);` | Allocates and initializes the native Filament `filament_name_component_manager_create` resource on the engine/GPU. |
| `filament_name_component_manager_destroy` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_destroy(void...` | Destroys the native Filament `filament_name_component_manager_destroy` resource and releases GPU/host memory. |
| `filament_name_component_manager_add_component` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_add_componen...` | Executes native Filament `filament_name_component_manager_add_component` C binding. |
| `filament_name_component_manager_remove_component` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_remove_compo...` | Executes native Filament `filament_name_component_manager_remove_component` C binding. |
| `filament_name_component_manager_get_instance` | `FFI_PLUGIN_EXPORT int32_t filament_name_component_manager_get_insta...` | Queries the `filament_name_component_manager_get_instance` state, property, or counter from the native C layer. |
| `filament_name_component_manager_set_name` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_set_name(voi...` | Updates the `filament_name_component_manager_set_name` parameter or state in the native C layer. |
| `filament_name_component_manager_get_name` | `FFI_PLUGIN_EXPORT const char* filament_name_component_manager_get_n...` | Queries the `filament_name_component_manager_get_name` state, property, or counter from the native C layer. |
| `filament_name_component_manager_gc` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_gc(void* ncm);` | Executes native Filament `filament_name_component_manager_gc` C binding. |
| `filament_entity_manager_register_destruction_callback` | `FFI_PLUGIN_EXPORT void* filament_entity_manager_register_destructio...` | Executes native Filament `filament_entity_manager_register_destruction_callback` C binding. |
| `filament_entity_manager_unregister_destruction_callback` | `FFI_PLUGIN_EXPORT void filament_entity_manager_unregister_destructi...` | Executes native Filament `filament_entity_manager_unregister_destruction_callback` C binding. |

## Dart API

### `lib/src/callback_bridge.dart`

#### `class CallbackResult`

The result returned from an asynchronous Filament operation through the callback bridge.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `int kind` | The operation kind (e.g. pick, compile, async gltf, readback). |
| `status` | `int status` | The status code (0 for success, non-zero for error or custom status). |
| `payload` | `Uint8List payload` | The raw payload bytes delivered from C++. |

#### `class CallbackBridge`

Unified process-wide callback bridge for asynchronous C++ Filament events.

**Constructors:**
- `CallbackBridge._()`: Initializes `CallbackBridge._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `init` | `void init()` | Initializes the callback bridge with the native C dispatcher. |
| `pendingCount` | `int get pendingCount` | The number of pending requests currently registered. |
| `shutdown` | `void shutdown()` | Shuts down the bridge and fails any pending requests. |

### `lib/src/debug_registry.dart`

#### `class DebugDataSource`

Represents a read-only data source returned from [FilamentDebugRegistry.getDataSource].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `count` | `int count` | Number of elements in the buffer. |

#### `class FilamentFrameHistory`

Mirror of Filament's `DebugRegistry::FrameHistory` struct layout.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `target` | `double target` | Holds the `target` property or configuration state. |
| `targetWithHeadroom` | `double targetWithHeadroom` | Holds the `targetWithHeadroom` property or configuration state. |
| `frameTime` | `double frameTime` | Holds the `frameTime` property or configuration state. |
| `frameTimeDenoised` | `double frameTimeDenoised` | Holds the `frameTimeDenoised` property or configuration state. |
| `scale` | `double scale` | Holds the `scale` property or configuration state. |
| `pidE` | `double pidE` | Holds the `pidE` property or configuration state. |
| `pidI` | `double pidI` | Holds the `pidI` property or configuration state. |
| `pidD` | `double pidD` | Holds the `pidD` property or configuration state. |

#### `class FilamentDebugRegistry`

Exposes Filament engine-internal debug switches and telemetry streams as named properties.  Typical discovered properties include: - `d.shadowmap.focus_shadowcasters` (bool) - `d.shadowmap.far_uses_shadowcasters` (bool) - `d.renderer.doFrameCapture` (bool) - `d.view.camera_at_origin` (bool) - `d.view.pid.kp` (float) - `d.renderer.disable_subpasses` (bool)  Note: Property names are internal to Filament and subject to change across engine versions.

**Constructors:**
- `FilamentDebugRegistry.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasProperty` | `bool hasProperty(String name)` | Checks if a debug property exists by [name]. |
| `setBool` | `bool setBool(String name, bool value)` | Sets a boolean property value. Returns false if the property does not exist. |
| `getBool` | `bool? getBool(String name)` | Gets a boolean property value. Returns null if the property does not exist. |
| `setInt` | `bool setInt(String name, int value)` | Sets an integer property value. Returns false if the property does not exist. |
| `getInt` | `int? getInt(String name)` | Gets an integer property value. Returns null if the property does not exist. |
| `setDouble` | `bool setDouble(String name, double value)` | Sets a float/double property value. Returns false if the property does not exist. |
| `getDouble` | `double? getDouble(String name)` | Gets a float/double property value. Returns null if the property does not exist. |
| `setVec2` | `bool setVec2(String name, double x, double y)` | Sets a 2D vector property value. Returns false if the property does not exist. |
| `setVec3` | `bool setVec3(String name, double x, double y, double z)` | Sets a 3D vector property value. Returns false if the property does not exist. |
| `setVec4` | `bool setVec4(String name, double x, double y, double z, double w)` | Sets a 4D vector property value. Returns false if the property does not exist. |
| `getDataSource` | `DebugDataSource? getDataSource(String name)` | Queries a continuous debug data source buffer. Returns null if not registered. |

### `lib/src/diagnostics.dart`

#### `class FilamentPanicException`

Represents an intercepted Filament `PANIC_PRECONDITION` or assertion.

**Constructors:**
- `FilamentPanicException(this.message, this.function, this.file, this.line)`: Initializes `FilamentPanicException(this.message, this.function, this.file, this.line)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `function` | `String function` | Holds the `function` property or configuration state. |
| `file` | `String file` | Holds the `file` property or configuration state. |
| `line` | `int line` | Holds the `line` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class FilamentLogRecord`

A log record emitted by Filament's internal engine.

**Constructors:**
- `FilamentLogRecord(this.priority, this.tag, this.message)`: Initializes `FilamentLogRecord(this.priority, this.tag, this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `priority` | `int priority` | Holds the `priority` property or configuration state. |
| `tag` | `String tag` | Holds the `tag` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class FilamentDiagnostics`

Provides a bridge to intercept Filament engine panics and internal logs.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onPanic` | `static Stream<FilamentPanicException> get onPanic` | Stream of Filament panics. |
| `lastPanic` | `static String? get lastPanic` | Gets the last recorded panic message if one occurred. Used primarily as a synchronous fallback since NativeCallable.listener delivers asynchronously. |
| `installPanicHandler` | `static void installPanicHandler()` | Installs the panic handler. Filament panics will be thrown asynchronously into the Dart isolate. |
| `clearPanicHandler` | `static void clearPanicHandler()` | Clears the panic handler, allowing panics to crash the process. |
| `onLog` | `static Stream<FilamentLogRecord> get onLog` | Stream of Filament internal logs (warnings, errors, etc.) |
| `installLogHandler` | `static void installLogHandler()` | Installs the log handler to route `slog` output to `onLog` stream. |
| `clearLogHandler` | `static void clearLogHandler()` | Clears the log handler. |
| `testTriggerPanic` | `static void testTriggerPanic()` | Triggers a test panic on the C++ side. |
| `testLog` | `static void testLog(String message)` | Sends a test log to `slog.w` on the C++ side. |

### `lib/src/engine.dart`

#### `enum FilamentBackend`

Filament rendering backend.

**Constructors:**
- `FilamentBackend(this.value)`: Initializes `FilamentBackend(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `noop` | `noop(5)` | No-op backend (for testing). |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static FilamentBackend fromValue(int v)` | Executes `fromValue` operation. |

#### `enum ShaderLanguage`

Preferred shader language for Filament backends.

**Constructors:**
- `ShaderLanguage(this.value)`: Initializes `ShaderLanguage(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `metalLibrary` | `metalLibrary(2)` | Executes `metalLibrary` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static ShaderLanguage fromValue(int v)` | Executes `fromValue` operation. |

#### `enum GpuContextPriority`

GPU context priority level for scheduling.

**Constructors:**
- `GpuContextPriority(this.value)`: Initializes `GpuContextPriority(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `realtime` | `realtime(4)` | Executes `realtime` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static GpuContextPriority fromValue(int v)` | Executes `fromValue` operation. |

#### `enum FeatureLevel`

Backend feature levels.

**Constructors:**
- `FeatureLevel(this.value)`: Initializes `FeatureLevel(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fl3` | `fl3(3)` | Executes `fl3` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static FeatureLevel fromValue(int v)` | Executes `fromValue` operation. |

#### `enum StereoscopicType`

Stereoscopic rendering technique type.

**Constructors:**
- `StereoscopicType(this.value)`: Initializes `StereoscopicType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `multiview` | `multiview(2)` | Executes `multiview` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static StereoscopicType fromValue(int v)` | Executes `fromValue` operation. |

#### `enum CompilerPriorityQueue`

Compiler priority queue for shader precompilation.

**Constructors:**
- `CompilerPriorityQueue(this.value)`: Initializes `CompilerPriorityQueue(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `low` | `low(1)` | Executes `low` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class EngineConfig`

Configuration options for initializing a [FilamentEngine].

**Constructors:**
- `EngineConfig.defaults()`: Populates configuration with Filament's default settings.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `commandBufferSizeMB` | `int commandBufferSizeMB` | Size in MiB of the low-level command buffer arena. |
| `perRenderPassArenaSizeMB` | `int perRenderPassArenaSizeMB` | Size in MiB of the per-frame data arena. |
| `minCommandBufferSizeMB` | `int minCommandBufferSizeMB` | Minimum size in MiB of a low-level command buffer. |
| `jobSystemThreadCount` | `int jobSystemThreadCount` | Number of threads in the Engine JobSystem (0 = heuristic default). |
| `preferredShaderLanguage` | `ShaderLanguage preferredShaderLanguage` | Preferred shader language. |
| `forceGLES2Context` | `bool forceGLES2Context` | Force GLES 2.0 context when using OpenGL backend. |
| `gpuContextPriority` | `GpuContextPriority gpuContextPriority` | GPU context priority level. |
| `materialCacheCapacity` | `int materialCacheCapacity` | Capacity of the LRU cache for material definitions. |
| `stereoscopicEyeCount` | `int stereoscopicEyeCount` | Number of eyes for stereoscopic rendering. |
| `stereoscopicType` | `StereoscopicType stereoscopicType` | Type of technique for stereoscopic rendering. |

#### `class FilamentEngine`

The main entry point for the Filament rendering engine.  An [FilamentEngine] instance manages the rendering thread, hardware context, and the lifetime of all created resources (renderers, views, scenes, etc.).  Use [FilamentEngine.create] to instantiate and [dispose] to clean up.

**Constructors:**
- `FilamentEngine._(this._ptr)`: Initializes `FilamentEngine._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `config` | `EngineConfig get config` | Returns the current configuration of this engine. |
| `createRenderer` | `FilamentRenderer createRenderer()` | Creates a new [FilamentRenderer] associated with this engine. |
| `createView` | `FilamentView createView()` | Creates a new [FilamentView]. |
| `createScene` | `FilamentScene createScene()` | Creates a new [FilamentScene]. |
| `createCamera` | `FilamentCamera createCamera(int entity)` | Creates a new [FilamentCamera] attached to the given entity. |
| `createEntity` | `int createEntity()` | Creates a new entity and returns its ID. |
| `createFence` | `FilamentFence createFence()` | Creates a new [FilamentFence] in the command stream. |
| `destroyFramePacer` | `void destroyFramePacer(FilamentFramePacer pacer)` | Destroys a [FilamentFramePacer]. |
| `debugRegistry` | `FilamentDebugRegistry get debugRegistry` | Returns the [FilamentDebugRegistry] for querying and setting engine debug switches. |
| `destroyView` | `void destroyView(FilamentView view)` | Destroys a [FilamentView]. |
| `destroyScene` | `void destroyScene(FilamentScene scene)` | Destroys a [FilamentScene]. |
| `destroyCamera` | `void destroyCamera(FilamentCamera camera)` | Destroys a [FilamentCamera]. |
| `destroyColorGrading` | `void destroyColorGrading(ColorGrading colorGrading)` | Destroys a [ColorGrading] object. |
| `destroyEntity` | `void destroyEntity(int entity)` | Destroys an entity and all its Filament components. |
| `destroyEntityComponents` | `void destroyEntityComponents(int entity)` | Destroys all Filament components attached to the given [entity]. |
| `destroyMorphTargetBuffer` | `void destroyMorphTargetBuffer(ffi.Pointer<ffi.Void> mtb)` | Destroys a morph target buffer given its native pointer. |
| `destroyFence` | `void destroyFence(ffi.Pointer<ffi.Void> fence)` | Destroys a fence given its native pointer. |
| `destroyInstanceBuffer` | `void destroyInstanceBuffer(ffi.Pointer<ffi.Void> ibuf)` | Destroys an instance buffer given its native pointer. |
| `isValidRenderer` | `bool isValidRenderer(FilamentRenderer renderer)` | Tells whether a [FilamentRenderer] is valid. |
| `isValidView` | `bool isValidView(FilamentView view)` | Tells whether a [FilamentView] is valid. |
| `isValidScene` | `bool isValidScene(FilamentScene scene)` | Tells whether a [FilamentScene] is valid. |
| `isValidSwapChain` | `bool isValidSwapChain(FilamentSwapChain swapChain)` | Tells whether a [FilamentSwapChain] is valid. |
| `isValidCamera` | `bool isValidCamera(FilamentCamera camera)` | Tells whether a [FilamentCamera] component is valid. |
| `isValidTexture` | `bool isValidTexture(ffi.Pointer<ffi.Void> texture)` | Tells whether a Texture native handle is valid. |
| `isValidMaterial` | `bool isValidMaterial(ffi.Pointer<ffi.Void> material)` | Tells whether a Material native handle is valid. |
| `isValidMaterialInstance` | `bool isValidMaterialInstance(ffi.Pointer<ffi.Void> material, ffi.Pointer...` | Tells whether a MaterialInstance is valid when its parent Material is known. |
| `isValidMaterialInstanceExpensive` | `bool isValidMaterialInstanceExpensive(ffi.Pointer<ffi.Void> mi)` | Tells whether a MaterialInstance is valid (expensive full scan). |
| `isValidVertexBuffer` | `bool isValidVertexBuffer(ffi.Pointer<ffi.Void> vb)` | Tells whether a VertexBuffer native handle is valid. |
| `isValidIndexBuffer` | `bool isValidIndexBuffer(ffi.Pointer<ffi.Void> ib)` | Tells whether an IndexBuffer native handle is valid. |
| `isValidBufferObject` | `bool isValidBufferObject(ffi.Pointer<ffi.Void> bo)` | Tells whether a BufferObject native handle is valid. |
| `isValidSkinningBuffer` | `bool isValidSkinningBuffer(ffi.Pointer<ffi.Void> sb)` | Tells whether a SkinningBuffer native handle is valid. |
| `isValidMorphTargetBuffer` | `bool isValidMorphTargetBuffer(ffi.Pointer<ffi.Void> mtb)` | Tells whether a MorphTargetBuffer native handle is valid. |
| `isValidInstanceBuffer` | `bool isValidInstanceBuffer(ffi.Pointer<ffi.Void> ibuf)` | Tells whether an InstanceBuffer native handle is valid. |
| `isValidIndirectLight` | `bool isValidIndirectLight(FilamentIndirectLight ibl)` | Tells whether an [IndirectLight] native handle or instance is valid. |
| `isValidSkybox` | `bool isValidSkybox(FilamentSkybox skybox)` | Tells whether a [Skybox] instance is valid. |
| `isValidRenderTarget` | `bool isValidRenderTarget(ffi.Pointer<ffi.Void> rt)` | Tells whether a RenderTarget native handle is valid. |
| `isValidFence` | `bool isValidFence(ffi.Pointer<ffi.Void> fence)` | Tells whether a Fence native handle is valid. |
| `isValidColorGrading` | `bool isValidColorGrading(ColorGrading cg)` | Tells whether a [ColorGrading] instance is valid. |
| `flush` | `void flush()` | Flushes the current command buffer to the hardware rendering thread without blocking. |
| `pumpMessageQueues` | `void pumpMessageQueues()` | Pumps the engine's internal message queues, processing pending callbacks and asynchronous events.  Recommended to call once per frame in the main game loop. |
| `execute` | `void execute()` | Executes work on the calling thread. Only supported in single-threaded/web builds. |
| `isPaused` | `bool get isPaused` | Whether the rendering thread is paused. |
| `paused` | `paused(bool val)` | Executes `paused` operation. |
| `steadyClockTimeNano` | `int get steadyClockTimeNano` | Monotonically increasing clock time in nanoseconds, suitable for `beginFrame` vsync calculations. |
| `supportedFeatureLevel` | `FeatureLevel get supportedFeatureLevel` | The highest feature level supported by the active backend driver. |
| `setActiveFeatureLevel` | `FeatureLevel setActiveFeatureLevel(FeatureLevel level)` | Sets the active feature level within the supported range. |
| `activeFeatureLevel` | `FeatureLevel get activeFeatureLevel` | The currently active feature level. |
| `maxAutomaticInstances` | `int get maxAutomaticInstances` | Maximum number of automatic instances supported when automatic instancing is enabled. |
| `isStereoSupported` | `bool isStereoSupported([StereoscopicType type = StereoscopicType.instanc...` | Whether stereoscopic rendering is supported for the given [type]. |
| `supportsRayQuery` | `bool get supportsRayQuery` | Whether the device builds ray tracing acceleration structures and traces rays from shaders (Vulkan ray query, see [Ray tracing](ray-tracing.md)). |
| `hasUnrecoverableFailure` | `bool get hasUnrecoverableFailure` | Whether the engine has encountered an unrecoverable failure (e.g. GPU crash). |
| `backend` | `FilamentBackend get backend` | The backend driver used by this engine. |
| `automaticInstancingEnabled` | `bool get automaticInstancingEnabled` | Whether automatic draw-call batching/instancing is enabled. |
| `automaticInstancingEnabled` | `automaticInstancingEnabled(bool enable)` | Executes `automaticInstancingEnabled` operation. |
| `materialCount` | `int get materialCount` | Returns the current number of allocated Material objects tracked by this engine. |
| `vertexBufferCount` | `int get vertexBufferCount` | Returns the current number of allocated VertexBuffer objects tracked by this engine. |
| `indexBufferCount` | `int get indexBufferCount` | Returns the current number of allocated IndexBuffer objects tracked by this engine. |
| `dispose` | `void dispose()` | Releases all resources and destroys this engine.  After calling [dispose], this engine instance must not be used. |
| `isDisposed` | `bool get isDisposed` | Whether this engine has been disposed. |

### `lib/src/entity.dart`

#### `class FilamentEntity`

A lightweight handle to an entity in Filament's Entity Component System (ECS).  Entities are 32-bit integer identifiers. Components (such as Camera, Light, Renderable, Transform) are attached to entities using their respective managers. Convention: `Entity.id == Entity::smuggle`; `Entity.none` (id 0) is never alive.

**Constructors:**
- `FilamentEntity(this.id, [this.engine])`: Creates a wrapper for an entity handle.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `int id` | Holds the `id` property or configuration state. |
| `engine` | `FilamentEngine? engine` | Holds the `engine` property or configuration state. |
| `destroy` | `void destroy()` | Destroys this entity and all attached Filament components. |
| `isAlive` | `bool get isAlive` | Checks current state or capability and returns a boolean value. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class EntityManager`

Global manager for entity lifecycles.

**Constructors:**
- `EntityManager._()`: Initializes `EntityManager._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `create` | `int create()` | Creates a single new entity. |
| `destroy` | `void destroy(int entity)` | Destroys a single entity handle. |
| `createEntitiesInstance` | `List<int> createEntitiesInstance(int n) => createEntities(n)` | Bulk creates `n` new entities. |
| `destroyEntitiesInstance` | `void destroyEntitiesInstance(List<int> entities) => destroyEntities(enti...` | Bulk destroys the given entities. |
| `isAlive` | `static bool isAlive(int entity)` | Checks whether an entity handle (id) is currently alive.  The id 0 (null entity) is never alive. Note that `isAlive` correctly distinguishes recycled-generation handles if a previously destroyed handle is queried. |
| `createEntities` | `static List<int> createEntities(int n)` | Bulk creates `n` new entities in a single FFI call. |
| `destroyEntities` | `static void destroyEntities(List<int> entities)` | Bulk destroys the given entities in a single FFI call.  Note: This only destroys the entity handle in the global `EntityManager`. To properly clean up components (like Renderables or Transforms), you MUST ALSO use `engine.destroyEntity(entity)` instead, which cleans up the engine side as well as the entity handle. |
| `entityCount` | `static int get entityCount` | Gets the total number of alive entities process-wide. |
| `advanceEpoch` | `static void advanceEpoch()` | Advances the entity lifecycle epoch, sealing dead entities for component manager GC. |
| `onEntitiesDestroyed` | `static Stream<Uint32List> get onEntitiesDestroyed` | Broadcast stream of destroyed entity batches. |

#### `class EntityDestructionSubscription`

Represents an active entity destruction subscription.

**Constructors:**
- `EntityDestructionSubscription._(this._nativeHandle, this._callable)`: Initializes `EntityDestructionSubscription._(this._nativeHandle, this._callable)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cancel` | `void cancel()` | Cancels this destruction subscription and frees native resources. |
| `isCancelled` | `bool get isCancelled` | Checks current state or capability and returns a boolean value. |

### `lib/src/enums.dart`

#### `enum PrimitiveType`

Primitive types for renderable objects matching Filament C++ backend values.

**Constructors:**
- `PrimitiveType(this.value)`: Initializes `PrimitiveType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `triangleStrip` | `triangleStrip(5)` | Executes `triangleStrip` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `rawValue` | `int get rawValue` | Backward-compatible alias for [value]. |

#### `enum IndexType`

Index element type matching backend::ElementType::USHORT and UINT.

**Constructors:**
- `IndexType(this.value)`: Initializes `IndexType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `uint` | `uint(17)` | Executes `uint` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class TextureUsage`

Bitmask describing intended texture usage in Filament.

#### `enum BuilderResult`

Result returned by builders (RenderableManager, LightManager).

**Constructors:**
- `BuilderResult(this.value)`: Initializes `BuilderResult(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `success` | `success(0)` | Executes `success` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class MorphType`

Bitmask describing morphing capabilities on renderables.

#### `enum GeometryType`

Type of geometry for a Renderable.

**Constructors:**
- `GeometryType(this.value)`: Initializes `GeometryType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `staticGeometry` | `staticGeometry(2)` | Executes `staticGeometry` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum VertexAttribute`

Vertex attributes supported by Filament.

**Constructors:**
- `VertexAttribute(this.value)`: Initializes `VertexAttribute(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `custom7` | `custom7(15)` | Executes `custom7` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum AttributeType`

Element data types for vertex buffer attributes matching Filament's `backend::ElementType`.

**Constructors:**
- `AttributeType(this.value)`: Initializes `AttributeType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `half4` | `half4(25)` | Executes `half4` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `byteSize` | `int get byteSize` | Getter accessor returning the current value of `byteSize`. |

#### `enum UniformType`

Supported uniform types matching Filament's `backend::UniformType`.

**Constructors:**
- `UniformType(this.value)`: Initializes `UniformType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `structType` | `structType(18)` | Executes `structType` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ParameterPrecision`

Precision specification for material parameters matching Filament's `backend::Precision`.

**Constructors:**
- `ParameterPrecision(this.value)`: Initializes `ParameterPrecision(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `defaultPrecision` | `defaultPrecision(3)` | Executes `defaultPrecision` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum RgbType`

RGB Color Space type.

**Constructors:**
- `RgbType(this.value)`: Initializes `RgbType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `linear` | `linear(1)` | Executes `linear` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum RgbaType`

RGBA Color Space type.

**Constructors:**
- `RgbaType(this.value)`: Initializes `RgbaType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `premultipliedLinear` | `premultipliedLinear(3)` | Executes `premultipliedLinear` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum CullingMode`

Face culling mode matching Filament's `backend::CullingMode`.

**Constructors:**
- `CullingMode(this.value)`: Initializes `CullingMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frontAndBack` | `frontAndBack(3)` | Executes `frontAndBack` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum DepthFunc`

Depth and stencil comparison function matching Filament's `backend::SamplerCompareFunc`.

**Constructors:**
- `DepthFunc(this.value)`: Initializes `DepthFunc(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `n` | `n(7)` | Executes `n` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum TransparencyMode`

Transparency mode for rendering matching Filament's `TransparencyMode`.

**Constructors:**
- `TransparencyMode(this.value)`: Initializes `TransparencyMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `twoPassesTwoSides` | `twoPassesTwoSides(2)` | Executes `twoPassesTwoSides` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum StencilFace`

Face selection for stencil operations matching Filament's `backend::StencilFace`.

**Constructors:**
- `StencilFace(this.value)`: Initializes `StencilFace(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frontAndBack` | `frontAndBack(3)` | Executes `frontAndBack` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum StencilOperation`

Stencil buffer operations matching Filament's `backend::StencilOperation`.

**Constructors:**
- `StencilOperation(this.value)`: Initializes `StencilOperation(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `invert` | `invert(7)` | Executes `invert` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

### `lib/src/exceptions.dart`

Both `lib/src/exceptions.dart` and `lib/src/exception.dart` declare this same `FilamentException` class.

#### `class FilamentException`

Exception thrown when a Filament engine operation fails.

**Constructors:**
- `FilamentException(this.message)`: Initializes `FilamentException(this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `lib/src/fence.dart`

#### `enum FenceStatus`

Status return codes for [FilamentFence] wait operations.

**Constructors:**
- `FenceStatus(this.value)`: Initializes `FenceStatus(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timeoutExpired` | `timeoutExpired(1)` | The wait timeout expired before the GPU reached the fence marker. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static FenceStatus fromValue(int val)` | Executes `fromValue` operation. |

#### `enum FenceMode`

Command stream flush behavior for [FilamentFence] wait operations.

**Constructors:**
- `FenceMode(this.value)`: Initializes `FenceMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dontFlush` | `dontFlush(1)` | Does not flush the command stream before waiting. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class FilamentFence`

A GPU-CPU synchronization fence primitive.  Fences allow tracking when the GPU has executed rendering commands up to a specific point in the command buffer.

**Constructors:**
- `FilamentFence.internal(this._ptr, this._engine)`: Internal constructor.
- `FilamentFence.create(FilamentEngine engine)`: Creates a new fence at the current point in the engine command stream.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fenceWaitForEver` | `static int get fenceWaitForEver` | Special timeout value representing infinite wait. |
| `dispose` | `void dispose()` | Destroys this fence and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/name_component_manager.dart`

#### `class NameComponentManager`

Component manager for associating string labels/names with entities.  In Filament, entities are raw integer IDs. [NameComponentManager] allows assigning human-readable names to entities (e.g. lights, procedural meshes, camera nodes) for scene hierarchy inspection and editor display.

**Constructors:**
- `NameComponentManager() : _ptr = c.filament_name_component_manager_create()`: Creates a new [NameComponentManager] attached to the global [EntityManager].
- `NameComponentManager.fromPointer(this._ptr)`: Creates a wrapper around an existing native pointer.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `addComponent` | `void addComponent(dynamic entity)` | Adds a name component to [entity] if it doesn't already have one. |
| `removeComponent` | `void removeComponent(dynamic entity)` | Removes the name component from [entity]. |
| `hasComponent` | `bool hasComponent(dynamic entity)` | Checks if [entity] has an associated name component. |
| `setName` | `void setName(dynamic entity, String name)` | Sets or updates the name associated with [entity].  Automatically calls [addComponent] if [entity] does not yet have a name component. |
| `getName` | `String? getName(dynamic entity)` | Retrieves the name associated with [entity], or `null` if no name component exists. |
| `gc` | `void gc()` | Cleans up internal component storage by removing name components for dead/destroyed entities. |
| `destroy` | `void destroy()` | Destroys this [NameComponentManager] and frees its native memory. |
| `dispose` | `void dispose() => destroy()` | Alias for [destroy]. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

---

[Previous: flutter_filament](index.md) | [Up: flutter_filament](index.md) | [Next: Renderer, views and frame pacing](renderer-and-view.md)
