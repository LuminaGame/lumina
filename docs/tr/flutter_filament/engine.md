[English](../../en/flutter_filament/engine.md)

# Engine, entity'ler ve temel tipler

`FilamentWidget.frameViews`, `FilamentFrameViewsCallback(defaultView, width,
height)` callback'ini alır. Birden fazla view ayarlayıp döndürerek tek
`beginFrame` / `endFrame` çifti ve swap chain üzerinde render edin. Native
gösterim birleşik yüzeyi bir kez okur. Viewport koordinatları fiziksel piksel
cinsindedir; başlangıç sol alt köşedir. Callback `beginFrame` öncesinde çalışır.
Ek kaynakların sahibi çağırandır; engine hayattayken `onDispose` üzerinden
serbest bırakılmalıdır. Callback verilmezse tek view davranışı korunur. Web
renderer da bu callback'i destekler.

Engine yaşam döngüsü ve temel nesne modeli: `EngineConfig` ile `FilamentEngine` oluşturmak ve yok etmek, entity'ler ile entity ve name manager'ları, tüm builder'ların paylaştığı enum'lar, fence'ler, exception tipi, native callback'leri Dart'a taşıyan callback bridge, debug registry ve tanılama (diagnostics) log'u. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
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

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/callback_bridge_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_callback_bridge_init` | `FFI_PLUGIN_EXPORT int32_t filament_callback_bridge_init(filament_ca...` | Filament yerel `filament_callback_bridge_init` C fonksiyonunu çalıştırır. |
| `filament_callback_bridge_shutdown` | `FFI_PLUGIN_EXPORT void filament_callback_bridge_shutdown(void);` | Filament yerel `filament_callback_bridge_shutdown` C fonksiyonunu çalıştırır. |
| `filament_callback_envelope_free` | `FFI_PLUGIN_EXPORT void filament_callback_envelope_free(FilamentCall...` | Filament yerel `filament_callback_envelope_free` C fonksiyonunu çalıştırır. |
| `filament_engine_pump_message_queues` | `FFI_PLUGIN_EXPORT void filament_engine_pump_message_queues(void* en...` | Filament yerel `filament_engine_pump_message_queues` C fonksiyonunu çalıştırır. |
| `filament_test_callback_fire` | `FFI_PLUGIN_EXPORT void filament_test_callback_fire( uint64_t reques...` | Filament yerel `filament_test_callback_fire` C fonksiyonunu çalıştırır. |
| `filament_test_callback_fire_async` | `FFI_PLUGIN_EXPORT void filament_test_callback_fire_async( uint64_t ...` | Filament yerel `filament_test_callback_fire_async` C fonksiyonunu çalıştırır. |

### `src/debug_registry_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_engine_get_debug_registry` | `FFI_PLUGIN_EXPORT void* filament_engine_get_debug_registry(void* en...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_has_property` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_has_property(void* r...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_debug_registry_set_property_bool` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_bool (v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_set_property_int` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_int (vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_set_property_float` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float (...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_set_property_float2` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float2(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_set_property_float3` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float3(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_set_property_float4` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_set_property_float4(...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_debug_registry_get_property_bool` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_bool (v...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_property_int` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_int (vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_property_float` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float (...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_property_float2` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float2(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_property_float3` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float3(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_property_float4` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_property_float4(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_debug_registry_get_data_source` | `FFI_PLUGIN_EXPORT bool filament_debug_registry_get_data_source(void...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |

### `src/engine_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_engine_config_init_default` | `FFI_PLUGIN_EXPORT void filament_engine_config_init_default(filament...` | Filament yerel `filament_engine_config_init_default` C fonksiyonunu çalıştırır. |
| `filament_engine_create_ex` | `FFI_PLUGIN_EXPORT void* filament_engine_create_ex(int backend, int ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_engine_get_config` | `FFI_PLUGIN_EXPORT void filament_engine_get_config(void* engine, fil...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_create` | `FFI_PLUGIN_EXPORT void* filament_engine_create(int backend);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_engine_destroy` | `FFI_PLUGIN_EXPORT void filament_engine_destroy(void* engine);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_flush_and_wait` | `FFI_PLUGIN_EXPORT void filament_engine_flush_and_wait(void* engine);` | Filament komut kuyruğunu GPU'ya gönderir. |
| `filament_engine_get_material_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_material_count(void* e...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_get_vertex_buffer_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_vertex_buffer_count(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_get_index_buffer_count` | `FFI_PLUGIN_EXPORT size_t filament_engine_get_index_buffer_count(voi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_is_valid_renderer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_renderer(void* engi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_view` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_view(void* engine, ...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_scene` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_scene(void* engine,...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_swap_chain` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_swap_chain(void* en...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_camera` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_camera(void* engine...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_texture` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_texture(void* engin...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_material` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material(void* engi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_material_instance` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_material_instance(v...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_expensive_material_instance` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_expensive_material_...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_vertex_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_vertex_buffer(void*...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_index_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_index_buffer(void* ...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_buffer_object` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_buffer_object(void*...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_skinning_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skinning_buffer(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_morph_target_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_morph_target_buffer...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_is_valid_instance_buffer` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_instance_buffer(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_indirect_light` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_indirect_light(void...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_skybox` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_skybox(void* engine...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_render_target` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_render_target(void*...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_fence` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_fence(void* engine,...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_is_valid_color_grading` | `FFI_PLUGIN_EXPORT bool filament_engine_is_valid_color_grading(void*...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_destroy_entity_components` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_entity_components(vo...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_destroy_morph_target_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_morph_target_buffer(...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_destroy_fence` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_fence(void* engine, ...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_destroy_instance_buffer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_instance_buffer(void...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_engine_flush` | `FFI_PLUGIN_EXPORT void filament_engine_flush(void* engine);` | Filament komut kuyruğunu GPU'ya gönderir. |
| `filament_engine_flush_and_wait_timeout` | `FFI_PLUGIN_EXPORT bool filament_engine_flush_and_wait_timeout(void*...` | Filament komut kuyruğunu GPU'ya gönderir. |
| `filament_engine_execute` | `FFI_PLUGIN_EXPORT void filament_engine_execute(void* engine);` | Filament yerel `filament_engine_execute` C fonksiyonunu çalıştırır. |
| `filament_engine_set_paused` | `FFI_PLUGIN_EXPORT void filament_engine_set_paused(void* engine, boo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_engine_is_paused` | `FFI_PLUGIN_EXPORT bool filament_engine_is_paused(void* engine);` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_engine_get_steady_clock_time_nano` | `FFI_PLUGIN_EXPORT int64_t filament_engine_get_steady_clock_time_nan...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_engine_get_supported_feature_level` | `FFI_PLUGIN_EXPORT int filament_engine_get_supported_feature_level(v...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| *... ve 21 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

### `src/enum_check_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_enum_primitive_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_primitive_type(int32_t ordi...` | Filament yerel `filament_enum_primitive_type` C fonksiyonunu çalıştırır. |
| `filament_enum_index_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_index_type(int32_t ordinal);` | Filament yerel `filament_enum_index_type` C fonksiyonunu çalıştırır. |
| `filament_enum_texture_usage` | `FFI_PLUGIN_EXPORT uint32_t filament_enum_texture_usage(int32_t ordi...` | Filament yerel `filament_enum_texture_usage` C fonksiyonunu çalıştırır. |
| `filament_enum_builder_result` | `FFI_PLUGIN_EXPORT int32_t filament_enum_builder_result(int32_t ordi...` | Filament yerel `filament_enum_builder_result` C fonksiyonunu çalıştırır. |
| `filament_enum_morph_type` | `FFI_PLUGIN_EXPORT uint32_t filament_enum_morph_type(int32_t ordinal);` | Filament yerel `filament_enum_morph_type` C fonksiyonunu çalıştırır. |
| `filament_enum_backend` | `FFI_PLUGIN_EXPORT int32_t filament_enum_backend(int32_t ordinal);` | Filament yerel `filament_enum_backend` C fonksiyonunu çalıştırır. |
| `filament_enum_light_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_light_type(int32_t ordinal);` | Filament yerel `filament_enum_light_type` C fonksiyonunu çalıştırır. |
| `filament_enum_manipulator_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_manipulator_mode(int32_t or...` | Filament yerel `filament_enum_manipulator_mode` C fonksiyonunu çalıştırır. |
| `filament_enum_filamat_shading` | `FFI_PLUGIN_EXPORT int32_t filament_enum_filamat_shading(int32_t ord...` | Filament yerel `filament_enum_filamat_shading` C fonksiyonunu çalıştırır. |
| `filament_enum_texture_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_texture_format(int32_t ordi...` | Filament yerel `filament_enum_texture_format` C fonksiyonunu çalıştırır. |
| `filament_enum_internal_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_internal_format(int32_t ord...` | Filament yerel `filament_enum_internal_format` C fonksiyonunu çalıştırır. |
| `filament_enum_sampler_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_sampler_type(int32_t ordinal);` | Filament yerel `filament_enum_sampler_type` C fonksiyonunu çalıştırır. |
| `filament_enum_texture_swizzle` | `FFI_PLUGIN_EXPORT int32_t filament_enum_texture_swizzle(int32_t ord...` | Filament yerel `filament_enum_texture_swizzle` C fonksiyonunu çalıştırır. |
| `filament_enum_pixel_format` | `FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_format(int32_t ordinal);` | Filament yerel `filament_enum_pixel_format` C fonksiyonunu çalıştırır. |
| `filament_enum_pixel_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_pixel_type(int32_t ordinal);` | Filament yerel `filament_enum_pixel_type` C fonksiyonunu çalıştırır. |
| `filament_enum_attribute_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_attribute_type(int32_t ordi...` | Filament yerel `filament_enum_attribute_type` C fonksiyonunu çalıştırır. |
| `filament_enum_vertex_attribute` | `FFI_PLUGIN_EXPORT int32_t filament_enum_vertex_attribute(int32_t or...` | Filament yerel `filament_enum_vertex_attribute` C fonksiyonunu çalıştırır. |
| `filament_enum_uniform_type` | `FFI_PLUGIN_EXPORT int32_t filament_enum_uniform_type(int32_t ordinal);` | Filament yerel `filament_enum_uniform_type` C fonksiyonunu çalıştırır. |
| `filament_enum_precision` | `FFI_PLUGIN_EXPORT int32_t filament_enum_precision(int32_t ordinal);` | Filament yerel `filament_enum_precision` C fonksiyonunu çalıştırır. |
| `filament_enum_culling_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_culling_mode(int32_t ordinal);` | Filament yerel `filament_enum_culling_mode` C fonksiyonunu çalıştırır. |
| `filament_enum_depth_func` | `FFI_PLUGIN_EXPORT int32_t filament_enum_depth_func(int32_t ordinal);` | Filament yerel `filament_enum_depth_func` C fonksiyonunu çalıştırır. |
| `filament_enum_transparency_mode` | `FFI_PLUGIN_EXPORT int32_t filament_enum_transparency_mode(int32_t o...` | Filament yerel `filament_enum_transparency_mode` C fonksiyonunu çalıştırır. |

### `src/fence_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_engine_create_fence` | `FFI_PLUGIN_EXPORT void* filament_engine_create_fence(void* engine);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_fence_wait` | `FFI_PLUGIN_EXPORT int filament_fence_wait(void* fence, int mode, ui...` | Filament yerel `filament_fence_wait` C fonksiyonunu çalıştırır. |
| `filament_fence_wait_and_destroy` | `FFI_PLUGIN_EXPORT int filament_fence_wait_and_destroy(void* fence, ...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_fence_wait_for_ever` | `FFI_PLUGIN_EXPORT uint64_t filament_fence_wait_for_ever(void);` | Filament yerel `filament_fence_wait_for_ever` C fonksiyonunu çalıştırır. |

### `src/utils_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_set_panic_handler` | `FFI_PLUGIN_EXPORT void filament_set_panic_handler(FilamentPanicHand...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_clear_panic_handler` | `FFI_PLUGIN_EXPORT void filament_clear_panic_handler(void);` | Filament yerel `filament_clear_panic_handler` C fonksiyonunu çalıştırır. |
| `filament_get_last_panic` | `FFI_PLUGIN_EXPORT bool filament_get_last_panic(char* out_message, s...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_set_log_callback` | `FFI_PLUGIN_EXPORT void filament_set_log_callback(FilamentLogHandler...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_clear_log_callback` | `FFI_PLUGIN_EXPORT void filament_clear_log_callback(void);` | Filament yerel `filament_clear_log_callback` C fonksiyonunu çalıştırır. |
| `filament_test_trigger_panic` | `FFI_PLUGIN_EXPORT void filament_test_trigger_panic(void);` | Filament yerel `filament_test_trigger_panic` C fonksiyonunu çalıştırır. |
| `filament_test_log` | `FFI_PLUGIN_EXPORT void filament_test_log(const char* msg);` | Filament yerel `filament_test_log` C fonksiyonunu çalıştırır. |
| `filament_free_string` | `FFI_PLUGIN_EXPORT void filament_free_string(char* str);` | Filament yerel `filament_free_string` C fonksiyonunu çalıştırır. |
| `filament_name_component_manager_create` | `FFI_PLUGIN_EXPORT void* filament_name_component_manager_create(void);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_name_component_manager_destroy` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_destroy(void...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_name_component_manager_add_component` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_add_componen...` | Filament yerel `filament_name_component_manager_add_component` C fonksiyonunu çalıştırır. |
| `filament_name_component_manager_remove_component` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_remove_compo...` | Filament yerel `filament_name_component_manager_remove_component` C fonksiyonunu çalıştırır. |
| `filament_name_component_manager_get_instance` | `FFI_PLUGIN_EXPORT int32_t filament_name_component_manager_get_insta...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_name_component_manager_set_name` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_set_name(voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_name_component_manager_get_name` | `FFI_PLUGIN_EXPORT const char* filament_name_component_manager_get_n...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_name_component_manager_gc` | `FFI_PLUGIN_EXPORT void filament_name_component_manager_gc(void* ncm);` | Filament yerel `filament_name_component_manager_gc` C fonksiyonunu çalıştırır. |
| `filament_entity_manager_register_destruction_callback` | `FFI_PLUGIN_EXPORT void* filament_entity_manager_register_destructio...` | Filament yerel `filament_entity_manager_register_destruction_callback` C fonksiyonunu çalıştırır. |
| `filament_entity_manager_unregister_destruction_callback` | `FFI_PLUGIN_EXPORT void filament_entity_manager_unregister_destructi...` | Filament yerel `filament_entity_manager_unregister_destruction_callback` C fonksiyonunu çalıştırır. |

## Dart API

### `lib/src/callback_bridge.dart`

#### `class CallbackResult`

The result returned from an asynchronous Filament operation through the callback bridge.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `int kind` | The operation kind (e.g. pick, compile, async gltf, readback). |
| `status` | `int status` | The status code (0 for success, non-zero for error or custom status). |
| `payload` | `Uint8List payload` | The raw payload bytes delivered from C++. |

#### `class CallbackBridge`

Unified process-wide callback bridge for asynchronous C++ Filament events.

**Yapıcı Metotlar (Constructors):**
- `CallbackBridge._()`: `CallbackBridge._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `init` | `void init()` | Initializes the callback bridge with the native C dispatcher. |
| `pendingCount` | `int get pendingCount` | The number of pending requests currently registered. |
| `shutdown` | `void shutdown()` | Shuts down the bridge and fails any pending requests. |

### `lib/src/debug_registry.dart`

#### `class DebugDataSource`

Represents a read-only data source returned from [FilamentDebugRegistry.getDataSource].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `count` | `int count` | Number of elements in the buffer. |

#### `class FilamentFrameHistory`

Mirror of Filament's `DebugRegistry::FrameHistory` struct layout.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `target` | `double target` | `target` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetWithHeadroom` | `double targetWithHeadroom` | `targetWithHeadroom` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameTime` | `double frameTime` | `frameTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameTimeDenoised` | `double frameTimeDenoised` | `frameTimeDenoised` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `double scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `pidE` | `double pidE` | `pidE` alanını (field/property) ve ilişkili veriyi saklar. |
| `pidI` | `double pidI` | `pidI` alanını (field/property) ve ilişkili veriyi saklar. |
| `pidD` | `double pidD` | `pidD` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentDebugRegistry`

Exposes Filament engine-internal debug switches and telemetry streams as named properties.  Typical discovered properties include: - `d.shadowmap.focus_shadowcasters` (bool) - `d.shadowmap.far_uses_shadowcasters` (bool) - `d.renderer.doFrameCapture` (bool) - `d.view.camera_at_origin` (bool) - `d.view.pid.kp` (float) - `d.renderer.disable_subpasses` (bool)  Note: Property names are internal to Filament and subject to change across engine versions.

**Yapıcı Metotlar (Constructors):**
- `FilamentDebugRegistry.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentPanicException(this.message, this.function, this.file, this.line)`: `FilamentPanicException(this.message, this.function, this.file, this.line)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `function` | `String function` | `function` alanını (field/property) ve ilişkili veriyi saklar. |
| `file` | `String file` | `file` alanını (field/property) ve ilişkili veriyi saklar. |
| `line` | `int line` | `line` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class FilamentLogRecord`

A log record emitted by Filament's internal engine.

**Yapıcı Metotlar (Constructors):**
- `FilamentLogRecord(this.priority, this.tag, this.message)`: `FilamentLogRecord(this.priority, this.tag, this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `priority` | `int priority` | `priority` alanını (field/property) ve ilişkili veriyi saklar. |
| `tag` | `String tag` | `tag` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class FilamentDiagnostics`

Provides a bridge to intercept Filament engine panics and internal logs.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentBackend(this.value)`: `FilamentBackend(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `noop` | `noop(5)` | No-op backend (for testing). |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static FilamentBackend fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `enum ShaderLanguage`

Preferred shader language for Filament backends.

**Yapıcı Metotlar (Constructors):**
- `ShaderLanguage(this.value)`: `ShaderLanguage(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `metalLibrary` | `metalLibrary(2)` | `metalLibrary` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static ShaderLanguage fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `enum GpuContextPriority`

GPU context priority level for scheduling.

**Yapıcı Metotlar (Constructors):**
- `GpuContextPriority(this.value)`: `GpuContextPriority(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `realtime` | `realtime(4)` | `realtime` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static GpuContextPriority fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `enum FeatureLevel`

Backend feature levels.

**Yapıcı Metotlar (Constructors):**
- `FeatureLevel(this.value)`: `FeatureLevel(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fl3` | `fl3(3)` | `fl3` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static FeatureLevel fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `enum StereoscopicType`

Stereoscopic rendering technique type.

**Yapıcı Metotlar (Constructors):**
- `StereoscopicType(this.value)`: `StereoscopicType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `multiview` | `multiview(2)` | `multiview` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static StereoscopicType fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `enum CompilerPriorityQueue`

Compiler priority queue for shader precompilation.

**Yapıcı Metotlar (Constructors):**
- `CompilerPriorityQueue(this.value)`: `CompilerPriorityQueue(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `low` | `low(1)` | `low` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class EngineConfig`

Configuration options for initializing a [FilamentEngine].

**Yapıcı Metotlar (Constructors):**
- `EngineConfig.defaults()`: Populates configuration with Filament's default settings.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentEngine._(this._ptr)`: `FilamentEngine._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `paused` | `paused(bool val)` | `paused` işlemini gerçekleştirir. |
| `steadyClockTimeNano` | `int get steadyClockTimeNano` | Monotonically increasing clock time in nanoseconds, suitable for `beginFrame` vsync calculations. |
| `supportedFeatureLevel` | `FeatureLevel get supportedFeatureLevel` | The highest feature level supported by the active backend driver. |
| `setActiveFeatureLevel` | `FeatureLevel setActiveFeatureLevel(FeatureLevel level)` | Sets the active feature level within the supported range. |
| `activeFeatureLevel` | `FeatureLevel get activeFeatureLevel` | The currently active feature level. |
| `maxAutomaticInstances` | `int get maxAutomaticInstances` | Maximum number of automatic instances supported when automatic instancing is enabled. |
| `isStereoSupported` | `bool isStereoSupported([StereoscopicType type = StereoscopicType.instanc...` | Whether stereoscopic rendering is supported for the given [type]. |
| `supportsRayQuery` | `bool get supportsRayQuery` | Aygıtın ışın izleme hızlandırma yapıları kurup shader'lardan ışın izleyip izleyemediği (Vulkan ray query, bkz. [Işın izleme](ray-tracing.md)). |
| `hasUnrecoverableFailure` | `bool get hasUnrecoverableFailure` | Whether the engine has encountered an unrecoverable failure (e.g. GPU crash). |
| `backend` | `FilamentBackend get backend` | The backend driver used by this engine. |
| `automaticInstancingEnabled` | `bool get automaticInstancingEnabled` | Whether automatic draw-call batching/instancing is enabled. |
| `automaticInstancingEnabled` | `automaticInstancingEnabled(bool enable)` | `automaticInstancingEnabled` işlemini gerçekleştirir. |
| `materialCount` | `int get materialCount` | Returns the current number of allocated Material objects tracked by this engine. |
| `vertexBufferCount` | `int get vertexBufferCount` | Returns the current number of allocated VertexBuffer objects tracked by this engine. |
| `indexBufferCount` | `int get indexBufferCount` | Returns the current number of allocated IndexBuffer objects tracked by this engine. |
| `dispose` | `void dispose()` | Releases all resources and destroys this engine.  After calling [dispose], this engine instance must not be used. |
| `isDisposed` | `bool get isDisposed` | Whether this engine has been disposed. |

### `lib/src/entity.dart`

#### `class FilamentEntity`

A lightweight handle to an entity in Filament's Entity Component System (ECS).  Entities are 32-bit integer identifiers. Components (such as Camera, Light, Renderable, Transform) are attached to entities using their respective managers. Convention: `Entity.id == Entity::smuggle`; `Entity.none` (id 0) is never alive.

**Yapıcı Metotlar (Constructors):**
- `FilamentEntity(this.id, [this.engine])`: Creates a wrapper for an entity handle.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `int id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `engine` | `FilamentEngine? engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `destroy` | `void destroy()` | Destroys this entity and all attached Filament components. |
| `isAlive` | `bool get isAlive` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class EntityManager`

Global manager for entity lifecycles.

**Yapıcı Metotlar (Constructors):**
- `EntityManager._()`: `EntityManager._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `EntityDestructionSubscription._(this._nativeHandle, this._callable)`: `EntityDestructionSubscription._(this._nativeHandle, this._callable)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cancel` | `void cancel()` | Cancels this destruction subscription and frees native resources. |
| `isCancelled` | `bool get isCancelled` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/enums.dart`

#### `enum PrimitiveType`

Primitive types for renderable objects matching Filament C++ backend values.

**Yapıcı Metotlar (Constructors):**
- `PrimitiveType(this.value)`: `PrimitiveType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `triangleStrip` | `triangleStrip(5)` | `triangleStrip` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `rawValue` | `int get rawValue` | Backward-compatible alias for [value]. |

#### `enum IndexType`

Index element type matching backend::ElementType::USHORT and UINT.

**Yapıcı Metotlar (Constructors):**
- `IndexType(this.value)`: `IndexType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `uint` | `uint(17)` | `uint` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TextureUsage`

Bitmask describing intended texture usage in Filament.

#### `enum BuilderResult`

Result returned by builders (RenderableManager, LightManager).

**Yapıcı Metotlar (Constructors):**
- `BuilderResult(this.value)`: `BuilderResult(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `success` | `success(0)` | `success` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class MorphType`

Bitmask describing morphing capabilities on renderables.

#### `enum GeometryType`

Type of geometry for a Renderable.

**Yapıcı Metotlar (Constructors):**
- `GeometryType(this.value)`: `GeometryType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `staticGeometry` | `staticGeometry(2)` | `staticGeometry` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum VertexAttribute`

Vertex attributes supported by Filament.

**Yapıcı Metotlar (Constructors):**
- `VertexAttribute(this.value)`: `VertexAttribute(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `custom7` | `custom7(15)` | `custom7` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum AttributeType`

Element data types for vertex buffer attributes matching Filament's `backend::ElementType`.

**Yapıcı Metotlar (Constructors):**
- `AttributeType(this.value)`: `AttributeType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `half4` | `half4(25)` | `half4` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `byteSize` | `int get byteSize` | `byteSize` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `enum UniformType`

Supported uniform types matching Filament's `backend::UniformType`.

**Yapıcı Metotlar (Constructors):**
- `UniformType(this.value)`: `UniformType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `structType` | `structType(18)` | `structType` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum ParameterPrecision`

Precision specification for material parameters matching Filament's `backend::Precision`.

**Yapıcı Metotlar (Constructors):**
- `ParameterPrecision(this.value)`: `ParameterPrecision(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `defaultPrecision` | `defaultPrecision(3)` | `defaultPrecision` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum RgbType`

RGB Color Space type.

**Yapıcı Metotlar (Constructors):**
- `RgbType(this.value)`: `RgbType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `linear` | `linear(1)` | `linear` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum RgbaType`

RGBA Color Space type.

**Yapıcı Metotlar (Constructors):**
- `RgbaType(this.value)`: `RgbaType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `premultipliedLinear` | `premultipliedLinear(3)` | `premultipliedLinear` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum CullingMode`

Face culling mode matching Filament's `backend::CullingMode`.

**Yapıcı Metotlar (Constructors):**
- `CullingMode(this.value)`: `CullingMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frontAndBack` | `frontAndBack(3)` | `frontAndBack` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum DepthFunc`

Depth and stencil comparison function matching Filament's `backend::SamplerCompareFunc`.

**Yapıcı Metotlar (Constructors):**
- `DepthFunc(this.value)`: `DepthFunc(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `n` | `n(7)` | `n` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum TransparencyMode`

Transparency mode for rendering matching Filament's `TransparencyMode`.

**Yapıcı Metotlar (Constructors):**
- `TransparencyMode(this.value)`: `TransparencyMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `twoPassesTwoSides` | `twoPassesTwoSides(2)` | `twoPassesTwoSides` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum StencilFace`

Face selection for stencil operations matching Filament's `backend::StencilFace`.

**Yapıcı Metotlar (Constructors):**
- `StencilFace(this.value)`: `StencilFace(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frontAndBack` | `frontAndBack(3)` | `frontAndBack` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum StencilOperation`

Stencil buffer operations matching Filament's `backend::StencilOperation`.

**Yapıcı Metotlar (Constructors):**
- `StencilOperation(this.value)`: `StencilOperation(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `invert` | `invert(7)` | `invert` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

### `lib/src/exceptions.dart`

`lib/src/exceptions.dart` ve `lib/src/exception.dart` dosyalarının ikisi de aynı `FilamentException` sınıfını tanımlar.

#### `class FilamentException`

Exception thrown when a Filament engine operation fails.

**Yapıcı Metotlar (Constructors):**
- `FilamentException(this.message)`: `FilamentException(this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `lib/src/fence.dart`

#### `enum FenceStatus`

Status return codes for [FilamentFence] wait operations.

**Yapıcı Metotlar (Constructors):**
- `FenceStatus(this.value)`: `FenceStatus(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeoutExpired` | `timeoutExpired(1)` | The wait timeout expired before the GPU reached the fence marker. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static FenceStatus fromValue(int val)` | `fromValue` işlemini gerçekleştirir. |

#### `enum FenceMode`

Command stream flush behavior for [FilamentFence] wait operations.

**Yapıcı Metotlar (Constructors):**
- `FenceMode(this.value)`: `FenceMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dontFlush` | `dontFlush(1)` | Does not flush the command stream before waiting. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentFence`

A GPU-CPU synchronization fence primitive.  Fences allow tracking when the GPU has executed rendering commands up to a specific point in the command buffer.

**Yapıcı Metotlar (Constructors):**
- `FilamentFence.internal(this._ptr, this._engine)`: Internal constructor.
- `FilamentFence.create(FilamentEngine engine)`: Creates a new fence at the current point in the engine command stream.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fenceWaitForEver` | `static int get fenceWaitForEver` | Special timeout value representing infinite wait. |
| `dispose` | `void dispose()` | Destroys this fence and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/name_component_manager.dart`

#### `class NameComponentManager`

Component manager for associating string labels/names with entities.  In Filament, entities are raw integer IDs. [NameComponentManager] allows assigning human-readable names to entities (e.g. lights, procedural meshes, camera nodes) for scene hierarchy inspection and editor display.

**Yapıcı Metotlar (Constructors):**
- `NameComponentManager() : _ptr = c.filament_name_component_manager_create()`: Creates a new [NameComponentManager] attached to the global [EntityManager].
- `NameComponentManager.fromPointer(this._ptr)`: Creates a wrapper around an existing native pointer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `addComponent` | `void addComponent(dynamic entity)` | Adds a name component to [entity] if it doesn't already have one. |
| `removeComponent` | `void removeComponent(dynamic entity)` | Removes the name component from [entity]. |
| `hasComponent` | `bool hasComponent(dynamic entity)` | Checks if [entity] has an associated name component. |
| `setName` | `void setName(dynamic entity, String name)` | Sets or updates the name associated with [entity].  Automatically calls [addComponent] if [entity] does not yet have a name component. |
| `getName` | `String? getName(dynamic entity)` | Retrieves the name associated with [entity], or `null` if no name component exists. |
| `gc` | `void gc()` | Cleans up internal component storage by removing name components for dead/destroyed entities. |
| `destroy` | `void destroy()` | Destroys this [NameComponentManager] and frees its native memory. |
| `dispose` | `void dispose() => destroy()` | Alias for [destroy]. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: flutter_filament](index.md) | [Üst: flutter_filament](index.md) | [Sonraki: Renderer, view'ler ve frame pacing](renderer-and-view.md)
