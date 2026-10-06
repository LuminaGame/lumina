[English](../../en/flutter_filament/renderer-and-view.md)

# Renderer, view'ler ve frame pacing

Bir sahne ile ekrandaki pikseller arasındaki her şey: renderer ve frame döngüsü, swap chain'ler, view'ler ve picking, offscreen render target'lar, frame pacer ve frame pipeline estimator ve bir Filament view'ini Flutter widget ağacının içinde barındıran `FilamentWidget`. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/frame_pacer_c.h`](#srcframe_pacer_ch)
  - [`src/renderer_c.h`](#srcrenderer_ch)
  - [`src/swap_chain_c.h`](#srcswap_chain_ch)
  - [`src/view_c.h`](#srcview_ch)
- [Dart API](#dart-api)
  - [`lib/src/frame_history_stream.dart`](#libsrcframe_history_streamdart)
  - [`lib/src/frame_pacer.dart`](#libsrcframe_pacerdart)
  - [`lib/src/frame_pipeline_estimator.dart`](#libsrcframe_pipeline_estimatordart)
  - [`lib/src/render_target.dart`](#libsrcrender_targetdart)
  - [`lib/src/renderer.dart`](#libsrcrendererdart)
  - [`lib/src/swap_chain.dart`](#libsrcswap_chaindart)
  - [`lib/src/view.dart`](#libsrcviewdart)
  - [`lib/src/widget.dart`](#libsrcwidgetdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/frame_pacer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_frame_pacer_create` | `FFI_PLUGIN_EXPORT void* filament_frame_pacer_create(void* engine, c...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_engine_destroy_frame_pacer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_frame_pacer(void* en...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_frame_pacer_configure` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_configure(void* pacer, ...` | Filament yerel `filament_frame_pacer_configure` C fonksiyonunu çalıştırır. |
| `filament_frame_pacer_get_configuration` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_get_configuration(void*...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_setup_frame` | `FFI_PLUGIN_EXPORT int8_t filament_frame_pacer_setup_frame(void* pac...` | Filament yerel `filament_frame_pacer_setup_frame` C fonksiyonunu çalıştırır. |
| `filament_frame_pacer_setup_extra_frame` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_setup_extra_frame(void*...` | Filament yerel `filament_frame_pacer_setup_extra_frame` C fonksiyonunu çalıştırır. |
| `filament_frame_pacer_has_gpu_fallen_behind` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_has_gpu_fallen_behind(v...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_frame_pacer_apply_presentation_time` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_apply_presentation_time...` | Filament yerel `filament_frame_pacer_apply_presentation_time` C fonksiyonunu çalıştırır. |
| `filament_frame_pacer_reset_pacing` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_reset_pacing(void* pacer);` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_frame_pacer_get_expected_presentation_time` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_expected_present...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_get_rendering_deadline` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_rendering_deadli...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_get_effective_latency` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_effective_latenc...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_get_pacing_status` | `FFI_PLUGIN_EXPORT int8_t filament_frame_pacer_get_pacing_status(voi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_get_selected_frame_rate` | `FFI_PLUGIN_EXPORT float filament_frame_pacer_get_selected_frame_rat...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_pacer_is_exact_frame_rate_achieved` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_is_exact_frame_rate_ach...` | Filament C motor durum veya yetenek doğrulamasını yapar. |

### `src/renderer_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_renderer_set_clear_options_ex` | `FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options_ex(void*...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_get_clear_options` | `FFI_PLUGIN_EXPORT void filament_renderer_get_clear_options(void* re...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderer_set_clear_options` | `FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options( void* r...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_begin_frame` | `FFI_PLUGIN_EXPORT bool filament_renderer_begin_frame(void* renderer...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_render` | `FFI_PLUGIN_EXPORT void filament_renderer_render(void* renderer, voi...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_end_frame` | `FFI_PLUGIN_EXPORT void filament_renderer_end_frame(void* renderer);` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_set_frame_rate_options` | `FFI_PLUGIN_EXPORT void filament_renderer_set_frame_rate_options(voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_get_frame_info_history` | `FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_frame_info_history...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderer_get_max_frame_history_size` | `FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_max_frame_history_...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_frame_info_invalid_sentinel` | `FFI_PLUGIN_EXPORT int64_t filament_frame_info_invalid_sentinel(void);` | Filament yerel `filament_frame_info_invalid_sentinel` C fonksiyonunu çalıştırır. |
| `filament_frame_info_pending_sentinel` | `FFI_PLUGIN_EXPORT int64_t filament_frame_info_pending_sentinel(void);` | Filament yerel `filament_frame_info_pending_sentinel` C fonksiyonunu çalıştırır. |
| `filament_renderer_render_standalone_view` | `FFI_PLUGIN_EXPORT void filament_renderer_render_standalone_view(voi...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_read_pixels` | `FFI_PLUGIN_EXPORT void filament_renderer_read_pixels( void *rendere...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_read_pixels_render_target` | `FFI_PLUGIN_EXPORT void filament_renderer_read_pixels_render_target(...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_set_presentation_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_presentation_time(void...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_set_desired_presentation_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_desired_presentation_t...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_set_rendering_deadline` | `FFI_PLUGIN_EXPORT void filament_renderer_set_rendering_deadline(voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_set_frame_schedule_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_frame_schedule_time(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_skip_frame` | `FFI_PLUGIN_EXPORT void filament_renderer_skip_frame(void* renderer,...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_should_render_frame` | `FFI_PLUGIN_EXPORT bool filament_renderer_should_render_frame(void* ...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_has_gpu_fallen_behind` | `FFI_PLUGIN_EXPORT bool filament_renderer_has_gpu_fallen_behind(void...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_renderer_get_material_time` | `FFI_PLUGIN_EXPORT double filament_renderer_get_material_time(void* ...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderer_set_material_time_epoch` | `FFI_PLUGIN_EXPORT void filament_renderer_set_material_time_epoch(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_renderer_skip_next_frames` | `FFI_PLUGIN_EXPORT void filament_renderer_skip_next_frames(void* ren...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |
| `filament_renderer_get_frame_to_skip_count` | `FFI_PLUGIN_EXPORT size_t filament_renderer_get_frame_to_skip_count(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_renderer_pause_render_thread` | `FFI_PLUGIN_EXPORT void filament_renderer_pause_render_thread(void* ...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |

### `src/swap_chain_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_swap_chain_is_msaa_supported` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_msaa_supported(void* ...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_swap_chain_is_protected_content_supported` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_protected_content_sup...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_swap_chain_set_frame_rate` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_rate( void* sw...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_swap_chain_is_frame_rate_change_supported` | `FFI_PLUGIN_EXPORT int filament_swap_chain_is_frame_rate_change_supp...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_swap_chain_get_native_window` | `FFI_PLUGIN_EXPORT void* filament_swap_chain_get_native_window(void*...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_swap_chain_is_frame_scheduled_callback_set` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_frame_scheduled_callb...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_swap_chain_set_frame_scheduled_callback` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_scheduled_call...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_swap_chain_set_frame_completed_callback` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_completed_call...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |

### `src/view_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_options_sizeof` | `FFI_PLUGIN_EXPORT uint32_t filament_options_sizeof(int which);` | Filament yerel `filament_options_sizeof` C fonksiyonunu çalıştırır. |
| `filament_engine_create_view` | `FFI_PLUGIN_EXPORT void* filament_engine_create_view(void* engine);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_engine_destroy_view` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_view(void* engine, v...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_view_set_scene` | `FFI_PLUGIN_EXPORT void filament_view_set_scene(void* view, void* sc...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_camera` | `FFI_PLUGIN_EXPORT void filament_view_set_camera(void* view, void* c...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_viewport` | `FFI_PLUGIN_EXPORT void filament_view_set_viewport(void* view, int32...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_name` | `FFI_PLUGIN_EXPORT void filament_view_set_name(void* view, const cha...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_shadowing_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_shadowing_enabled(void* vi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_pick` | `FFI_PLUGIN_EXPORT void filament_view_pick(void* view, uint32_t x, u...` | Filament yerel `filament_view_pick` C fonksiyonunu çalıştırır. |
| `filament_view_set_transparent_picking_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_transparent_picking_enable...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_is_transparent_picking_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_transparent_picking_enabled...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_get_name` | `FFI_PLUGIN_EXPORT const char* filament_view_get_name(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_get_scene` | `FFI_PLUGIN_EXPORT void* filament_view_get_scene(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_get_camera` | `FFI_PLUGIN_EXPORT void* filament_view_get_camera(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_has_camera` | `FFI_PLUGIN_EXPORT bool filament_view_has_camera(void* view);` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_get_viewport` | `FFI_PLUGIN_EXPORT void filament_view_get_viewport(void* view, int32...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_get_render_target` | `FFI_PLUGIN_EXPORT void* filament_view_get_render_target(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_get_visible_layers` | `FFI_PLUGIN_EXPORT uint8_t filament_view_get_visible_layers(void* vi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_is_shadowing_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_shadowing_enabled(void* view);` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_is_screen_space_refraction_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_screen_space_refraction_ena...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_get_anti_aliasing` | `FFI_PLUGIN_EXPORT int filament_view_get_anti_aliasing(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_set_post_processing_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_post_processing_enabled(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_is_post_processing_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_post_processing_enabled(voi...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_set_blend_mode` | `FFI_PLUGIN_EXPORT void filament_view_set_blend_mode(void* view, int...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_get_blend_mode` | `FFI_PLUGIN_EXPORT int filament_view_get_blend_mode(void* view);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_set_stencil_buffer_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_stencil_buffer_enabled(voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_is_stencil_buffer_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_stencil_buffer_enabled(void...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_set_front_face_winding_inverted` | `FFI_PLUGIN_EXPORT void filament_view_set_front_face_winding_inverte...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_is_front_face_winding_inverted` | `FFI_PLUGIN_EXPORT bool filament_view_is_front_face_winding_inverted...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_view_set_dynamic_lighting_options` | `FFI_PLUGIN_EXPORT void filament_view_set_dynamic_lighting_options(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_material_global` | `FFI_PLUGIN_EXPORT void filament_view_set_material_global(void* view...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_get_material_global` | `FFI_PLUGIN_EXPORT void filament_view_get_material_global(void* view...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_clear_frame_history` | `FFI_PLUGIN_EXPORT void filament_view_clear_frame_history(void* view...` | Filament yerel `filament_view_clear_frame_history` C fonksiyonunu çalıştırır. |
| `filament_view_set_layer_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_layer_enabled(void* view, ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_get_visible_renderable_count` | `FFI_PLUGIN_EXPORT uint32_t filament_view_get_visible_renderable_cou...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_view_set_anti_aliasing` | `FFI_PLUGIN_EXPORT void filament_view_set_anti_aliasing(void* view, ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_screen_space_refraction_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_screen_space_refraction_en...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_visible_layers` | `FFI_PLUGIN_EXPORT void filament_view_set_visible_layers(void* view,...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_render_target` | `FFI_PLUGIN_EXPORT void filament_view_set_render_target(void* view, ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_view_set_bloom_options` | `FFI_PLUGIN_EXPORT void filament_view_set_bloom_options(void* view, ...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| *... ve 55 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

## Dart API

### `lib/src/frame_history_stream.dart`

#### `class FrameHistoryStream`

Pure-Dart implementation of Filament's FrameHistoryStream.  Receives batches of [FrameInfo] records, deduplicates them by [FrameInfo.frameId], detects dropped or missing frame gaps, and emits unique completed frames in sequence.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `stream` | `Stream<FrameInfo> get stream` | Stream of individual, deduplicated [FrameInfo] instances in increasing order of frameId. |
| `lastFrameId` | `int get lastFrameId` | The highest frameId processed and emitted so far (0 if none). |
| `droppedFrameCount` | `int get droppedFrameCount` | Cumulative count of dropped/skipped frames detected via frameId discontinuities. |
| `push` | `void push(List<FrameInfo> history)` | Pushes a batch of [FrameInfo] records from [FilamentRenderer.getFrameInfoHistory]. |
| `close` | `void close()` | Closes the underlying stream controller. |

### `lib/src/frame_pacer.dart`

#### `enum FrameStatus`

Status code returned by [FilamentFramePacer.setupFrame] indicating whether the frame should render.

**Yapıcı Metotlar (Constructors):**
- `FrameStatus(this.value)`: `FrameStatus(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `accepted` | `accepted(0)` | The frame is approved for rendering. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static FrameStatus fromValue(int val)` | `fromValue` işlemini gerçekleştirir. |
| `shouldRender` | `bool get shouldRender` | Whether this status approves rendering the frame. |

#### `enum PacingStatus`

Pipeline flow control status for [FilamentFramePacer].

**Yapıcı Metotlar (Constructors):**
- `PacingStatus(this.value)`: `PacingStatus(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `displayStuffed` | `displayStuffed(1)` | Latency has bloated; display queue is stuffed. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static PacingStatus fromValue(int val)` | `fromValue` işlemini gerçekleştirir. |

#### `class HardwareTimeline`

Hardware presentation timeline telemetry.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `expectedPresentationTimeNs` | `int expectedPresentationTimeNs` | Anticipated physical presentation timestamp in nanoseconds on steady clock. |
| `deadlineNs` | `int deadlineNs` | Submission completion deadline in nanoseconds on steady clock. |

#### `class VsyncTick`

VSYNC timing telemetry passed to [FilamentFramePacer.setupFrame].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `baseTimeNs` | `int baseTimeNs` | Base hardware VSYNC tick timestamp in nanoseconds on steady clock. |
| `vsyncPeriodNs` | `int vsyncPeriodNs` | Physical hardware VSYNC period in nanoseconds (defaults to ~16.66ms for 60Hz). |
| `frameScheduleTimeNs` | `int frameScheduleTimeNs` | Time when frame scheduling callback was entered in nanoseconds on steady clock (0 = now). |
| `timelines` | `List<HardwareTimeline> timelines` | Candidate hardware presentation timelines. |

#### `class FramePacerConfiguration`

Dynamic target configuration for [FilamentFramePacer].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `targetFrameRate` | `double targetFrameRate` | Desired rendering frame rate in Hz. |
| `latency` | `Duration latency` | Target latency duration. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class FilamentFramePacer`

Coordinates frame scheduling and presentation timestamps to eliminate micro-stutter.  Typical game loop pattern: ```dart final status = pacer.setupFrame(tick); if (status.shouldRender) { // Advance simulation to pacer.expectedPresentationTime if (!pacer.hasGpuFallenBehind(renderer)) { pacer.applyPresentationTime(renderer); if (renderer.beginFrame(swapChain)) { renderer.render(view); renderer.endFrame(); } } } ```

**Yapıcı Metotlar (Constructors):**
- `FilamentFramePacer.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `configure` | `void configure(FramePacerConfiguration config)` | Updates the active pacing targets mid-flight. |
| `configuration` | `FramePacerConfiguration get configuration` | Retrieves the current configuration used by the FramePacer. |
| `setupFrame` | `FrameStatus setupFrame(VsyncTick tick)` | Prepares and evaluates the frame pacing state for an upcoming frame cycle. |
| `setupExtraFrame` | `bool setupExtraFrame()` | Advances the pacing pipeline to target an extra presentation frame for latency recovery. |
| `hasGpuFallenBehind` | `bool hasGpuFallenBehind(FilamentRenderer renderer)` | Checks if the GPU rendering pipeline has fallen behind CPU submissions. |
| `applyPresentationTime` | `void applyPresentationTime(FilamentRenderer renderer)` | Applies the computed Latency Offset presentation time directly onto the renderer. |
| `resetPacing` | `void resetPacing()` | Forces FramePacer to abandon relative pacing state and re-anchor on next frame. |
| `expectedPresentationTime` | `int get expectedPresentationTime` | Expected presentation timestamp in nanoseconds on steady clock. |
| `renderingDeadline` | `int get renderingDeadline` | Rendering deadline timestamp in nanoseconds on steady clock. |
| `effectiveLatency` | `Duration get effectiveLatency` | Effective target latency. |
| `pacingStatus` | `PacingStatus get pacingStatus` | Current flow control status of the pacing pipeline. |
| `selectedFrameRate` | `double get selectedFrameRate` | Actual frame rate selected during active pacing cycle. |
| `isExactFrameRateAchieved` | `bool get isExactFrameRateAchieved` | Whether selected pacing frame rate is achieved exactly by display hardware. |
| `dispose` | `void dispose()` | Destroys this frame pacer and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/frame_pipeline_estimator.dart`

#### `enum TargetPercentile`

Target statistical percentile for workload estimation.

#### `class Workload`

Computed ideal throughput recommendation from [FramePipelineEstimator.estimateWorkload].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `idealFrameDuration` | `Duration idealFrameDuration` | Ideal bottleneck frame duration (throughput). |
| `idealFrameRate` | `double idealFrameRate` | Ideal frame rate in Hz (1.0 / idealFrameDuration). |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class PacingSizing`

Structural latency and CPU safe delay sizing from [FramePipelineEstimator.estimatePacing].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `latencyFrames` | `int latencyFrames` | Recommended structural latency (pipeline depth in frames). |
| `safeDelayDuration` | `Duration safeDelayDuration` | Maximum safe delay before starting CPU work in the frame cycle. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class _TelemetryStats`

`_TelemetryStats`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |
| `countGpu` | `int countGpu` | `countGpu` alanını (field/property) ve ilişkili veriyi saklar. |
| `countMargin` | `int countMargin` | `countMargin` alanını (field/property) ve ilişkili veriyi saklar. |
| `meanMain` | `double meanMain` | `meanMain` alanını (field/property) ve ilişkili veriyi saklar. |
| `meanBackend` | `double meanBackend` | `meanBackend` alanını (field/property) ve ilişkili veriyi saklar. |
| `meanGpu` | `double meanGpu` | `meanGpu` alanını (field/property) ve ilişkili veriyi saklar. |
| `meanMargin` | `double meanMargin` | `meanMargin` alanını (field/property) ve ilişkili veriyi saklar. |
| `stdDevMain` | `double stdDevMain` | `stdDevMain` alanını (field/property) ve ilişkili veriyi saklar. |
| `stdDevBackend` | `double stdDevBackend` | `stdDevBackend` alanını (field/property) ve ilişkili veriyi saklar. |
| `stdDevGpu` | `double stdDevGpu` | `stdDevGpu` alanını (field/property) ve ilişkili veriyi saklar. |
| `stdDevMargin` | `double stdDevMargin` | `stdDevMargin` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveMain` | `double effectiveMain` | `effectiveMain` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveBackend` | `double effectiveBackend` | `effectiveBackend` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveGpu` | `double effectiveGpu` | `effectiveGpu` alanını (field/property) ve ilişkili veriyi saklar. |
| `totalTransitTimeNs` | `double totalTransitTimeNs` | `totalTransitTimeNs` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveCompositionMarginNs` | `double effectiveCompositionMarginNs` | `effectiveCompositionMarginNs` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FramePipelineEstimator`

Pure Dart implementation of Filament's `FramePipelineEstimator`.  Calculates ideal refresh rate (throughput) and ideal structural latency (pipeline depth) based on historical [FrameInfo] telemetry using probabilistic Gaussian modeling.  C++ analog: `filament/include/filament/FramePipelineEstimator.h`

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `getZScore` | `static double getZScore(TargetPercentile targetPercentile)` | Converts a [TargetPercentile] to its standard normal distribution Z-score.  Reference: `FramePipelineEstimator::getZScore` |

### `lib/src/render_target.dart`

#### `enum AttachmentPoint`

`AttachmentPoint`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Yapıcı Metotlar (Constructors):**
- `AttachmentPoint(this.value)`: `AttachmentPoint(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `depth` | `depth(8)` | `depth` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class RenderTargetAttachment`

`RenderTargetAttachment`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture texture` | `texture` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipLevel` | `int mipLevel` | `mipLevel` alanını (field/property) ve ilişkili veriyi saklar. |
| `face` | `CubemapFace? face` | `face` alanını (field/property) ve ilişkili veriyi saklar. |
| `layer` | `int layer` | `layer` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentRenderTarget`

An offscreen render target (Frame Buffer Object / FBO) that can be associated with a View.

**Yapıcı Metotlar (Constructors):**
- `FilamentRenderTarget._(this._ptr, this._engine)`: `FilamentRenderTarget._(this._ptr, this._engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `supportedColorAttachmentsCount` | `static int supportedColorAttachmentsCount(FilamentEngine engine)` | Returns the maximum number of color attachments supported by the engine. |
| `dispose` | `void dispose()` | Destroys this RenderTarget. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/motion_vectors.dart`

#### `class MotionVectorBuffer`

`MotionVectorBuffer`: bir `FilamentView`'ın hareket vektörleri okunabilir bir tampon olarak: `TemporalAntiAliasingOptions.motionVectors` açıkken view'ın içine dışa aktardığı RGBA16F doku, onu geri okuyan render hedefi ve geri okumanın kendisi. Filament'in structure pass'i (Lumina yaması `0004`) vektörleri her renderable'ın önceki dünya dönüşümünden, önceki kemik paleti ve morph ağırlıklarından ve önceki karenin kamerasından üretir.

**Kurucular:**
- `MotionVectorBuffer.attach({required FilamentEngine engine, required FilamentView view, required int width, required int height})`: dokuyu ve render hedefini (view'ın render hedefiyle tam aynı boyutta) oluşturur ve `view`'ın onlara dışa aktarmasını sağlar; `view.motionVectorsSupported` false ise `StateError` fırlatır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture texture` | RGBA16F dışa aktarma dokusu (`TextureUsage.colorAttachment | sampleable | blitSrc`). |
| `renderTarget` | `FilamentRenderTarget renderTarget` | Geri okumanın kullandığı, `texture` üzerindeki render hedefi. |
| `read` | `Future<Float32List> read(FilamentRenderer renderer)` | Son render edilen karenin hareket vektörleri: `width * height * 2` float, texel başına iki (x, y), satırlar görüntünün altından yukarı. Dokunun kendi half float'larını okur ve genişletir. |
| `velocityAt` | `(double, double) velocityAt(Float32List velocity, int x, int y)` | `read`'in döndürdüğü tamponda, yukarıdan aşağı piksel koordinatındaki (x, y) hareket. |
| `halfToFloat` | `static double halfToFloat(int h)` | IEEE 754 binary16'dan binary32'ye. |
| `dispose` | `void dispose()` | Dışa aktarımı durdurur (view hâlâ bu dokuya bakıyorsa) ve render hedefiyle dokuyu yok eder. |

### `lib/src/renderer.dart`

#### `class ClearOptions`

ClearOptions are used at the beginning of a frame to clear or retain SwapChain content.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `clearColor` | `Vector4 clearColor` | Color used to clear the RenderTarget (in linear RGBA space, each component typically 0.0 .. 1.0). |
| `clearStencil` | `int clearStencil` | Value to clear the stencil buffer (0..255). |
| `clear` | `bool clear` | Whether the SwapChain should be cleared using the [clearColor]. |
| `discard` | `bool discard` | Whether the SwapChain content should be discarded. |

#### `class DisplayInfo`

Display properties used by the engine for frame-pacing and dynamic resolution scaling.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `refreshRate` | `double refreshRate` | Refresh rate of the display in Hz (e.g. 60.0, 120.0). Must be > 0. |

#### `class FrameRateOptions`

Options controlling the desired frame rate and dynamic resolution responsiveness.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `headRoomRatio` | `double headRoomRatio` | Additional headroom for the GPU as a ratio of the target frame time (0.0 .. 1.0). |
| `scaleRate` | `double scaleRate` | Rate at which the GPU load is adjusted (e.g. 1/8 = 0.125). |
| `history` | `int history` | History size for smoothing (1 .. 31, default 15). |
| `interval` | `int interval` | Desired frame interval in units of 1 / refreshRate (1 = 60fps on 60Hz, 2 = 30fps on 60Hz). Must be >= 1. |

#### `class FrameInfo`

Timing and latency metrics for a rendered frame.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frameId` | `int frameId` | `frameId` alanını (field/property) ve ilişkili veriyi saklar. |
| `gpuFrameDuration` | `int gpuFrameDuration` | `gpuFrameDuration` alanını (field/property) ve ilişkili veriyi saklar. |
| `denoisedGpuFrameDuration` | `int denoisedGpuFrameDuration` | `denoisedGpuFrameDuration` alanını (field/property) ve ilişkili veriyi saklar. |
| `beginFrame` | `int beginFrame` | `beginFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `endFrame` | `int endFrame` | `endFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `backendBeginFrame` | `int backendBeginFrame` | `backendBeginFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `backendEndFrame` | `int backendEndFrame` | `backendEndFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `gpuFrameComplete` | `int gpuFrameComplete` | `gpuFrameComplete` alanını (field/property) ve ilişkili veriyi saklar. |
| `vsync` | `int vsync` | `vsync` alanını (field/property) ve ilişkili veriyi saklar. |
| `displayPresent` | `int displayPresent` | `displayPresent` alanını (field/property) ve ilişkili veriyi saklar. |
| `presentDeadline` | `int presentDeadline` | `presentDeadline` alanını (field/property) ve ilişkili veriyi saklar. |
| `displayPresentInterval` | `int displayPresentInterval` | `displayPresentInterval` alanını (field/property) ve ilişkili veriyi saklar. |
| `compositionToPresentLatency` | `int compositionToPresentLatency` | `compositionToPresentLatency` alanını (field/property) ve ilişkili veriyi saklar. |
| `expectedPresentLatency` | `int expectedPresentLatency` | `expectedPresentLatency` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameScheduleTime` | `int frameScheduleTime` | `frameScheduleTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `isGpuPending` | `bool get isGpuPending` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isValidField` | `static bool isValidField(int value)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentRenderer`

A Renderer generates drawing commands for the render thread and manages frame latency.  Typically one Renderer is created per window.

**Yapıcı Metotlar (Constructors):**
- `FilamentRenderer.internal(this._ptr, this._engine)`: Internal constructor for creating a [FilamentRenderer] from a native pointer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `clearOptions` | `clearOptions(ClearOptions options)` | Sets ClearOptions which are used at the beginning of a frame to clear or retain SwapChain content. |
| `clearOptions` | `ClearOptions get clearOptions` | Returns the ClearOptions currently set. |
| `render` | `void render(FilamentView view)` | Render a [view] into this renderer's window.  Must be called after [beginFrame] and before [endFrame]. |
| `endFrame` | `void endFrame()` | Finishes the current frame and schedules it for display. |
| `displayInfo` | `displayInfo(DisplayInfo info)` | Sets display properties (such as refresh rate) needed for frame pacing and dynamic resolution. |
| `frameRateOptions` | `frameRateOptions(FrameRateOptions options)` | Sets frame rate options controlling target frame interval and dynamic resolution responsiveness. |
| `getFrameInfoHistory` | `List<FrameInfo> getFrameInfoHistory([int count = 1])` | Retrieves past frame timing information. |
| `maxFrameHistorySize` | `int get maxFrameHistorySize` | Maximum frame timing history capacity supported by this renderer. |
| `renderStandaloneView` | `void renderStandaloneView(FilamentView view)` | Renders a standalone view into its associated RenderTarget.  Must be called outside of [beginFrame] / [endFrame]. The [view] must have a [FilamentRenderTarget] assigned. |
| `vsyncTime` | `vsyncTime(int steadyClockNs)` | Sets VSYNC time in nanoseconds since epoch of steady_clock. |
| `presentationTime` | `presentationTime(int monotonicClockNs)` | Sets hardware presentation timestamp in nanoseconds on the steady clock. |
| `desiredPresentationTime` | `desiredPresentationTime(int ns)` | Sets targeted presentation timestamp in nanoseconds on the steady clock. |
| `renderingDeadline` | `renderingDeadline(int deadlineNs)` | Sets deadline time point in nanoseconds by which rendering must complete. |
| `frameScheduleTime` | `frameScheduleTime(int ns)` | Sets physical clock time when the frame scheduling callback was entered. |
| `shouldRenderFrame` | `bool get shouldRenderFrame` | Returns `true` if the current frame should be rendered. |
| `hasGpuFallenBehind` | `bool get hasGpuFallenBehind` | Returns `true` if GPU execution has fallen behind CPU rendering execution. |
| `materialTime` | `double get materialTime` | Returns the current material time in seconds. |
| `skipNextFrames` | `void skipNextFrames(int count)` | Requests the next [count] frames to be skipped. |
| `frameToSkipCount` | `int get frameToSkipCount` | Remainder count of frames to be skipped. |
| `pauseRenderThread` | `void pauseRenderThread(Duration duration)` | Stalls the render thread for the given duration (useful for pacing testing). |
| `dispose` | `void dispose()` | Destroys this renderer and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/swap_chain.dart`

#### `class SwapChainConfig`

Configuration flags for swap chain creation.

**Yapıcı Metotlar (Constructors):**
- `SwapChainConfig(this.value)`: `SwapChainConfig(this.value)` nesnesini ilklendirir.
- `SwapChainConfig._(this.value)`: `SwapChainConfig._(this.value)` nesnesini ilklendirir.
- `SwapChainConfig._(value | other.value)`: `SwapChainConfig._(value | other.value)` nesnesini ilklendirir.
- `SwapChainConfig._(value & other.value)`: `SwapChainConfig._(value & other.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `value` | `int value` | Raw bitfield value. |
| `contains` | `bool contains(SwapChainConfig flag)` | Checks if this configuration contains all flags in [flag]. |
| `disableVsync` | `static const SwapChainConfig disableVsync` | Ekranın dikey yenilemesini beklemeden sunar (Vulkan, Windows'ta OpenGL); kareler yırtılabilir. FSR3 kare üretimiyle iki sunumu renderer zamanlar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `enum FrameRateChangeSupport`

Three-state result for frame rate change support query.

#### `enum FrameRateCompatibility`

Frame rate compatibility mode for [FilamentSwapChain.setFrameRate].

**Yapıcı Metotlar (Constructors):**
- `FrameRateCompatibility(this.value)`: `FrameRateCompatibility(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fixedSource` | `fixedSource(1)` | Strongly prioritizes running at the exact requested rate (e.g. video playback). |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum ChangeFrameRateStrategy`

Change strategy for non-seamless display frame rate transitions.

**Yapıcı Metotlar (Constructors):**
- `ChangeFrameRateStrategy(this.value)`: `ChangeFrameRateStrategy(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `always` | `always(1)` | Transition is applied immediately, even if a non-seamless display mode switch occurs. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentSwapChain`

A SwapChain represents the rendering target (typically a window surface).  Use [FilamentEngine.createSwapChain] for windowed rendering or [FilamentEngine.createHeadlessSwapChain] for offscreen rendering.

**Yapıcı Metotlar (Constructors):**
- `FilamentSwapChain.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isSRGBSupported` | `static bool isSRGBSupported(FilamentEngine engine)` | Returns whether the engine supports the [SwapChainConfig.srgbColorspace] flag. |
| `isMSAASupported` | `static bool isMSAASupported(FilamentEngine engine, [int samples = 4])` | Returns whether the engine supports MSAA swap chains with [samples] count. |
| `isProtectedContentSupported` | `static bool isProtectedContentSupported(FilamentEngine engine)` | Returns whether the engine supports protected content swap chains. |
| `isFrameRateChangeSupported` | `FrameRateChangeSupport get isFrameRateChangeSupported` | Returns whether this SwapChain supports dynamic frame rate changes. |
| `nativeWindowAddress` | `int get nativeWindowAddress` | The raw native window address (0 for headless swap chains). |
| `isFrameScheduledCallbackSet` | `bool get isFrameScheduledCallbackSet` | Whether a frame scheduled callback is currently configured. |
| `onFrameScheduled` | `onFrameScheduled(void Function()? callback)` | Sets or clears the callback invoked when a frame has finished CPU processing. |
| `onFrameCompleted` | `onFrameCompleted(void Function()? callback)` | Sets or clears the callback invoked when a frame has finished GPU rendering. |
| `dispose` | `void dispose()` | Destroys this swap chain and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/view.dart`

#### `class PickingResult`

`PickingResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PickingResult(this.renderable, this.depth, this.fragCoords)`: `PickingResult(this.renderable, this.depth, this.fragCoords)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `renderable` | `FilamentEntity? renderable` | `renderable` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `double depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentView`

A View encompasses all the state needed for rendering a Scene.  A View specifies the Scene, Camera, Viewport, and rendering parameters.

**Yapıcı Metotlar (Constructors):**
- `FilamentView.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `scene` | `scene(FilamentScene scene)` | Sets the Scene associated with this View. |
| `scene` | `FilamentScene? get scene` | `scene` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `camera` | `camera(FilamentCamera camera)` | Sets the Camera associated with this View. |
| `camera` | `FilamentCamera? get camera` | `camera` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `renderTarget` | `renderTarget(FilamentRenderTarget? renderTarget)` | `renderTarget` işlemini gerçekleştirir. |
| `renderTarget` | `FilamentRenderTarget? get renderTarget` | `renderTarget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setViewport` | `void setViewport(int left, int bottom, int width, int height)` | Sets the viewport for this View from explicit coordinates (in bottom-left origin). |
| `setViewportModel` | `void setViewportModel(Viewport vp)` | Sets the viewport for this View from a [Viewport] model. |
| `viewportModel` | `Viewport get viewportModel` | Gets the current viewport as a [Viewport] model. |
| `colorGrading` | `colorGrading(ColorGrading? cg)` | Sets or clears the ColorGrading on this View. Passing null restores the default color grading. |
| `setColorGradingModel` | `void setColorGradingModel(ColorGrading? cg)` | Sets the ColorGrading using a method call. |
| `colorGrading` | `ColorGrading? get colorGrading` | Gets the currently assigned [ColorGrading], if any. |
| `name` | `name(String name)` | Sets the View's name (for debugging). |
| `name` | `String? get name` | `name` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `shadowingEnabled` | `shadowingEnabled(bool enabled)` | Enables or disables shadow mapping on this View. |
| `shadowingEnabled` | `bool get shadowingEnabled` | `shadowingEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `postProcessingEnabled` | `postProcessingEnabled(bool enabled)` | Enables or disables post-processing on this View. |
| `postProcessingEnabled` | `bool get postProcessingEnabled` | `postProcessingEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `shadowType` | `shadowType(ShadowType type)` | `shadowType` işlemini gerçekleştirir. |
| `shadowType` | `ShadowType get shadowType` | `shadowType` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vsmShadowOptions` | `vsmShadowOptions(VsmShadowOptions options)` | `vsmShadowOptions` işlemini gerçekleştirir. |
| `vsmShadowOptions` | `VsmShadowOptions get vsmShadowOptions` | `vsmShadowOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `softShadowOptions` | `softShadowOptions(SoftShadowOptions options)` | `softShadowOptions` işlemini gerçekleştirir. |
| `softShadowOptions` | `SoftShadowOptions get softShadowOptions` | `softShadowOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blendMode` | `blendMode(BlendMode mode)` | `blendMode` işlemini gerçekleştirir. |
| `blendMode` | `BlendMode get blendMode` | `blendMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `stencilBufferEnabled` | `stencilBufferEnabled(bool enabled)` | `stencilBufferEnabled` işlemini gerçekleştirir. |
| `stencilBufferEnabled` | `bool get stencilBufferEnabled` | `stencilBufferEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `frontFaceWindingInverted` | `frontFaceWindingInverted(bool inverted)` | `frontFaceWindingInverted` işlemini gerçekleştirir. |
| `frontFaceWindingInverted` | `bool get frontFaceWindingInverted` | `frontFaceWindingInverted` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setDynamicLightingOptions` | `void setDynamicLightingOptions(double zLightNear, double zLightFar)` | `DynamicLightingOptions` parametresini günceller ve sisteme uygular. |
| `setMaterialGlobal` | `void setMaterialGlobal(int index, double x, double y, double z, double w)` | `MaterialGlobal` parametresini günceller ve sisteme uygular. |
| `clearFrameHistory` | `void clearFrameHistory(FilamentEngine engine)` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `setLayerEnabled` | `void setLayerEnabled(int layer, bool enabled)` | `LayerEnabled` parametresini günceller ve sisteme uygular. |
| `visibleRenderableCount` | `int get visibleRenderableCount` | `visibleRenderableCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `antiAliasing` | `antiAliasing(int type)` | Sets the anti-aliasing type (e.g., 0 for None, 1 for FXAA). |
| `antiAliasing` | `int get antiAliasing` | Gets the anti-aliasing type. |
| `screenSpaceRefractionEnabled` | `screenSpaceRefractionEnabled(bool enabled)` | Enables or disables screen space refraction. |
| `screenSpaceRefractionEnabled` | `bool get screenSpaceRefractionEnabled` | Gets whether screen space refraction is enabled. |
| `setVisibleLayers` | `void setVisibleLayers(int select, int values)` | Sets visible layers bitmask. |
| `visibleLayers` | `int get visibleLayers` | `visibleLayers` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `bloomOptions` | `bloomOptions(BloomOptions options)` | `bloomOptions` işlemini gerçekleştirir. |
| `bloomOptions` | `BloomOptions get bloomOptions` | `bloomOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fogOptions` | `fogOptions(FogOptions options)` | `fogOptions` işlemini gerçekleştirir. |
| `fogOptions` | `FogOptions get fogOptions` | `fogOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `depthOfFieldOptions` | `depthOfFieldOptions(DepthOfFieldOptions options)` | `depthOfFieldOptions` işlemini gerçekleştirir. |
| `depthOfFieldOptions` | `DepthOfFieldOptions get depthOfFieldOptions` | `depthOfFieldOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vignetteOptions` | `vignetteOptions(VignetteOptions options)` | `vignetteOptions` işlemini gerçekleştirir. |
| `vignetteOptions` | `VignetteOptions get vignetteOptions` | `vignetteOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `ambientOcclusionOptions` | `ambientOcclusionOptions(AmbientOcclusionOptions options)` | `ambientOcclusionOptions` işlemini gerçekleştirir. |
| `ambientOcclusionOptions` | `AmbientOcclusionOptions get ambientOcclusionOptions` | `ambientOcclusionOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `temporalAntiAliasingOptions` | `temporalAntiAliasingOptions(TemporalAntiAliasingOptions options)` | `temporalAntiAliasingOptions` işlemini gerçekleştirir. |
| `temporalAntiAliasingOptions` | `TemporalAntiAliasingOptions get temporalAntiAliasingOptions` | `temporalAntiAliasingOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `multiSampleAntiAliasingOptions` | `multiSampleAntiAliasingOptions(MultiSampleAntiAliasingOptions options)` | `multiSampleAntiAliasingOptions` işlemini gerçekleştirir. |
| `multiSampleAntiAliasingOptions` | `MultiSampleAntiAliasingOptions get multiSampleAntiAliasingOptions` | `multiSampleAntiAliasingOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `motionVectorsSupported` | `bool get motionVectorsSupported` | View'ın motorunun hareket vektörü üretip üretemeyeceği (`TemporalAntiAliasingOptions.motionVectors`): feature level 1 ve üstü bir GPU backend'i ve RG16F renk eki. Noop backend'de false. |
| `motionVectorTexture` | `FilamentTexture? get motionVectorTexture` / `set motionVectorTexture(FilamentTexture? texture)` | `motionVectors` açıkken hareket vektörlerinin dışa aktarıldığı doku: en az iki kanallı float bir renk dokusu (renk eki + örneklenebilir), view'ın render hedefiyle tam aynı boyutta; başka boyut yok sayılır. Texel'ler yüzeyin önceki kareden bu yana ekrandaki kaymasını texel cinsinden tutar, x sağa ve y yukarı; arka plan sıfırdır. Null dışa aktarımı kapatır. |
| `screenSpaceReflectionsOptions` | `screenSpaceReflectionsOptions(ScreenSpaceReflectionsOptions options)` | `screenSpaceReflectionsOptions` işlemini gerçekleştirir. |
| `screenSpaceReflectionsOptions` | `ScreenSpaceReflectionsOptions get screenSpaceReflectionsOptions` | `screenSpaceReflectionsOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `guardBandOptions` | `guardBandOptions(GuardBandOptions options)` | `guardBandOptions` işlemini gerçekleştirir. |
| `guardBandOptions` | `GuardBandOptions get guardBandOptions` | `guardBandOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dynamicResolutionOptions` | `dynamicResolutionOptions(DynamicResolutionOptions options)` | `dynamicResolutionOptions` işlemini gerçekleştirir. |
| `dynamicResolutionOptions` | `DynamicResolutionOptions get dynamicResolutionOptions` | `dynamicResolutionOptions` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `renderQuality` | `renderQuality(RenderQuality options)` | `renderQuality` işlemini gerçekleştirir. |
| `renderQuality` | `RenderQuality get renderQuality` | `renderQuality` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dithering` | `dithering(Dithering d)` | `dithering` işlemini gerçekleştirir. |
| `dithering` | `Dithering get dithering` | `dithering` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `transparentPickingEnabled` | `transparentPickingEnabled(bool enabled)` | `transparentPickingEnabled` işlemini gerçekleştirir. |
| `transparentPickingEnabled` | `bool get transparentPickingEnabled` | `transparentPickingEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `pick` | `Future<PickingResult> pick(int x, int y)` | Picks a pixel on the screen and returns the rendered entity and depth at that pixel. Note: The coordinates (x, y) are based on a bottom-left origin. |
| `restirOptions` | `RestirOptions restirOptions` (get/set) | Noktasal ışıklar için ReSTIR doğrudan aydınlatma; bkz. [ReSTIR doğrudan aydınlatma](restir.md). |
| `restirSupported` | `bool get restirSupported` | Ray query var ve ReSTIR malzemeleri yüklü. |
| `restirStats` | `RestirStats get restirStats` | Son ReSTIR karesinin ışık sayısı, kare başına ışın ve GPU süresi. |
| `resetRestirHistory` | `void resetRestirHistory()` | ReSTIR zamansal geçmişini bırakır (kamera kesmeleri). |
| `traceRay` | `Future<RayHit?> traceRay(double ox, double oy, double oz, double dx, double dy, double dz, {double maxDistance = 1.0e5})` | Bu view'ın bir sonraki karesinde sahnenin hızlandırma yapılarına karşı tek bir görünürlük ışını izler, `pick` gibi; ıskalamada ya da ışın izleme yokken `null` (bkz. [Işın izleme](ray-tracing.md)). |
| `dispose` | `void dispose()` | Destroys this view and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/widget.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`with SingleTickerProviderStateMixin`**: `SingleTickerProviderStateMixin` işlemini gerçekleştirir.

#### `class FilamentWidget`

A Flutter widget for rendering 3D Filament scenes natively.  Manages engine lifecycle, frame rendering loops, and viewport dimensions.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onSceneCreated` | `FilamentSceneCreatedCallback? onSceneCreated` | Callback fired when the Filament 3D engine, scene, and camera are initialized. |
| `backend` | `FilamentBackend backend` | Backend engine to use (defaults to Metal on macOS, Vulkan/OpenGL on Linux/Android). |
| `width` | `double width` | Width of the 3D viewport canvas. |
| `height` | `double height` | Height of the 3D viewport canvas. |
| `onDispose` | `VoidCallback? onDispose` | Optional callback executed when the 3D widget is being disposed (for resource cleanup). |
| `cameraManipulator` | `FilamentCameraManipulator? cameraManipulator` | Optional camera manipulator for interactive orbit, pan, and zoom gestures. |
| `showFpsBadge` | `bool showFpsBadge` | Optional flag to render FPS badge overlay (defaults to false). Optional flag to render FPS badge overlay (defaults to false). |
| `isPaused` | `bool isPaused` | Whether 3D GPU frame rendering is paused (e.g. when viewport tab is inactive). |
| `pauseRendering` | `bool pauseRendering` | Whether to temporarily pause just the pixel readback & rendering loop while heavy operations (like mesh loading) are happening to prevent GPU fence timeouts. |
| `skipReadPixels` | `bool skipReadPixels` | Whether to skip readPixels for the current frame. Useful when the first frame of a new complex asset is rendered, which causes shader compilation and might timeout the readPixels fence. |
| `createState` | `State<FilamentWidget> createState() => _FilamentWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

#### `class _FilamentWidgetState`

`_FilamentWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(FilamentWidget oldWidget)` | `didUpdateWidget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

---

[Önceki: Engine, entity'ler ve temel tipler](engine.md) | [Üst: flutter_filament](index.md) | [Sonraki: View seçenekleri ve color grading](view-options.md)
