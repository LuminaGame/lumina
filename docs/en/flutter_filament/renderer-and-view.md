[Türkçe](../../tr/flutter_filament/renderer-and-view.md)

# Renderer, views and frame pacing

Everything between a scene and the pixels on screen: the renderer and its frame loop, swap chains, views and picking, offscreen render targets, the frame pacer and the frame pipeline estimator, and `FilamentWidget`, which hosts a Filament view inside a Flutter widget tree. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
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

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/frame_pacer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_frame_pacer_create` | `FFI_PLUGIN_EXPORT void* filament_frame_pacer_create(void* engine, c...` | Allocates and initializes the native Filament `filament_frame_pacer_create` resource on the engine/GPU. |
| `filament_engine_destroy_frame_pacer` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_frame_pacer(void* en...` | Destroys the native Filament `filament_engine_destroy_frame_pacer` resource and releases GPU/host memory. |
| `filament_frame_pacer_configure` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_configure(void* pacer, ...` | Executes native Filament `filament_frame_pacer_configure` C binding. |
| `filament_frame_pacer_get_configuration` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_get_configuration(void*...` | Queries the `filament_frame_pacer_get_configuration` state, property, or counter from the native C layer. |
| `filament_frame_pacer_setup_frame` | `FFI_PLUGIN_EXPORT int8_t filament_frame_pacer_setup_frame(void* pac...` | Executes native Filament `filament_frame_pacer_setup_frame` C binding. |
| `filament_frame_pacer_setup_extra_frame` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_setup_extra_frame(void*...` | Executes native Filament `filament_frame_pacer_setup_extra_frame` C binding. |
| `filament_frame_pacer_has_gpu_fallen_behind` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_has_gpu_fallen_behind(v...` | Validates or queries the `filament_frame_pacer_has_gpu_fallen_behind` state/capability. |
| `filament_frame_pacer_apply_presentation_time` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_apply_presentation_time...` | Executes native Filament `filament_frame_pacer_apply_presentation_time` C binding. |
| `filament_frame_pacer_reset_pacing` | `FFI_PLUGIN_EXPORT void filament_frame_pacer_reset_pacing(void* pacer);` | Updates the `filament_frame_pacer_reset_pacing` parameter or state in the native C layer. |
| `filament_frame_pacer_get_expected_presentation_time` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_expected_present...` | Queries the `filament_frame_pacer_get_expected_presentation_time` state, property, or counter from the native C layer. |
| `filament_frame_pacer_get_rendering_deadline` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_rendering_deadli...` | Queries the `filament_frame_pacer_get_rendering_deadline` state, property, or counter from the native C layer. |
| `filament_frame_pacer_get_effective_latency` | `FFI_PLUGIN_EXPORT int64_t filament_frame_pacer_get_effective_latenc...` | Queries the `filament_frame_pacer_get_effective_latency` state, property, or counter from the native C layer. |
| `filament_frame_pacer_get_pacing_status` | `FFI_PLUGIN_EXPORT int8_t filament_frame_pacer_get_pacing_status(voi...` | Queries the `filament_frame_pacer_get_pacing_status` state, property, or counter from the native C layer. |
| `filament_frame_pacer_get_selected_frame_rate` | `FFI_PLUGIN_EXPORT float filament_frame_pacer_get_selected_frame_rat...` | Queries the `filament_frame_pacer_get_selected_frame_rate` state, property, or counter from the native C layer. |
| `filament_frame_pacer_is_exact_frame_rate_achieved` | `FFI_PLUGIN_EXPORT bool filament_frame_pacer_is_exact_frame_rate_ach...` | Validates or queries the `filament_frame_pacer_is_exact_frame_rate_achieved` state/capability. |

### `src/renderer_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_renderer_set_clear_options_ex` | `FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options_ex(void*...` | Updates the `filament_renderer_set_clear_options_ex` parameter or state in the native C layer. |
| `filament_renderer_get_clear_options` | `FFI_PLUGIN_EXPORT void filament_renderer_get_clear_options(void* re...` | Queries the `filament_renderer_get_clear_options` state, property, or counter from the native C layer. |
| `filament_renderer_set_clear_options` | `FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options( void* r...` | Updates the `filament_renderer_set_clear_options` parameter or state in the native C layer. |
| `filament_renderer_begin_frame` | `FFI_PLUGIN_EXPORT bool filament_renderer_begin_frame(void* renderer...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_render` | `FFI_PLUGIN_EXPORT void filament_renderer_render(void* renderer, voi...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_end_frame` | `FFI_PLUGIN_EXPORT void filament_renderer_end_frame(void* renderer);` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_set_frame_rate_options` | `FFI_PLUGIN_EXPORT void filament_renderer_set_frame_rate_options(voi...` | Updates the `filament_renderer_set_frame_rate_options` parameter or state in the native C layer. |
| `filament_renderer_get_frame_info_history` | `FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_frame_info_history...` | Queries the `filament_renderer_get_frame_info_history` state, property, or counter from the native C layer. |
| `filament_renderer_get_max_frame_history_size` | `FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_max_frame_history_...` | Queries the `filament_renderer_get_max_frame_history_size` state, property, or counter from the native C layer. |
| `filament_frame_info_invalid_sentinel` | `FFI_PLUGIN_EXPORT int64_t filament_frame_info_invalid_sentinel(void);` | Executes native Filament `filament_frame_info_invalid_sentinel` C binding. |
| `filament_frame_info_pending_sentinel` | `FFI_PLUGIN_EXPORT int64_t filament_frame_info_pending_sentinel(void);` | Executes native Filament `filament_frame_info_pending_sentinel` C binding. |
| `filament_renderer_render_standalone_view` | `FFI_PLUGIN_EXPORT void filament_renderer_render_standalone_view(voi...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_read_pixels` | `FFI_PLUGIN_EXPORT void filament_renderer_read_pixels( void *rendere...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_read_pixels_render_target` | `FFI_PLUGIN_EXPORT void filament_renderer_read_pixels_render_target(...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_set_presentation_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_presentation_time(void...` | Updates the `filament_renderer_set_presentation_time` parameter or state in the native C layer. |
| `filament_renderer_set_desired_presentation_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_desired_presentation_t...` | Updates the `filament_renderer_set_desired_presentation_time` parameter or state in the native C layer. |
| `filament_renderer_set_rendering_deadline` | `FFI_PLUGIN_EXPORT void filament_renderer_set_rendering_deadline(voi...` | Updates the `filament_renderer_set_rendering_deadline` parameter or state in the native C layer. |
| `filament_renderer_set_frame_schedule_time` | `FFI_PLUGIN_EXPORT void filament_renderer_set_frame_schedule_time(vo...` | Updates the `filament_renderer_set_frame_schedule_time` parameter or state in the native C layer. |
| `filament_renderer_skip_frame` | `FFI_PLUGIN_EXPORT void filament_renderer_skip_frame(void* renderer,...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_should_render_frame` | `FFI_PLUGIN_EXPORT bool filament_renderer_should_render_frame(void* ...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_has_gpu_fallen_behind` | `FFI_PLUGIN_EXPORT bool filament_renderer_has_gpu_fallen_behind(void...` | Validates or queries the `filament_renderer_has_gpu_fallen_behind` state/capability. |
| `filament_renderer_get_material_time` | `FFI_PLUGIN_EXPORT double filament_renderer_get_material_time(void* ...` | Queries the `filament_renderer_get_material_time` state, property, or counter from the native C layer. |
| `filament_renderer_set_material_time_epoch` | `FFI_PLUGIN_EXPORT void filament_renderer_set_material_time_epoch(vo...` | Updates the `filament_renderer_set_material_time_epoch` parameter or state in the native C layer. |
| `filament_renderer_skip_next_frames` | `FFI_PLUGIN_EXPORT void filament_renderer_skip_next_frames(void* ren...` | Dispatches drawing commands for the view and scene to the GPU. |
| `filament_renderer_get_frame_to_skip_count` | `FFI_PLUGIN_EXPORT size_t filament_renderer_get_frame_to_skip_count(...` | Queries the `filament_renderer_get_frame_to_skip_count` state, property, or counter from the native C layer. |
| `filament_renderer_pause_render_thread` | `FFI_PLUGIN_EXPORT void filament_renderer_pause_render_thread(void* ...` | Dispatches drawing commands for the view and scene to the GPU. |

### `src/swap_chain_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_swap_chain_is_msaa_supported` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_msaa_supported(void* ...` | Validates or queries the `filament_swap_chain_is_msaa_supported` state/capability. |
| `filament_swap_chain_is_protected_content_supported` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_protected_content_sup...` | Validates or queries the `filament_swap_chain_is_protected_content_supported` state/capability. |
| `filament_swap_chain_set_frame_rate` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_rate( void* sw...` | Updates the `filament_swap_chain_set_frame_rate` parameter or state in the native C layer. |
| `filament_swap_chain_is_frame_rate_change_supported` | `FFI_PLUGIN_EXPORT int filament_swap_chain_is_frame_rate_change_supp...` | Validates or queries the `filament_swap_chain_is_frame_rate_change_supported` state/capability. |
| `filament_swap_chain_get_native_window` | `FFI_PLUGIN_EXPORT void* filament_swap_chain_get_native_window(void*...` | Queries the `filament_swap_chain_get_native_window` state, property, or counter from the native C layer. |
| `filament_swap_chain_is_frame_scheduled_callback_set` | `FFI_PLUGIN_EXPORT bool filament_swap_chain_is_frame_scheduled_callb...` | Validates or queries the `filament_swap_chain_is_frame_scheduled_callback_set` state/capability. |
| `filament_swap_chain_set_frame_scheduled_callback` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_scheduled_call...` | Updates the `filament_swap_chain_set_frame_scheduled_callback` parameter or state in the native C layer. |
| `filament_swap_chain_set_frame_completed_callback` | `FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_completed_call...` | Updates the `filament_swap_chain_set_frame_completed_callback` parameter or state in the native C layer. |

### `src/view_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_options_sizeof` | `FFI_PLUGIN_EXPORT uint32_t filament_options_sizeof(int which);` | Executes native Filament `filament_options_sizeof` C binding. |
| `filament_engine_create_view` | `FFI_PLUGIN_EXPORT void* filament_engine_create_view(void* engine);` | Allocates and initializes the native Filament `filament_engine_create_view` resource on the engine/GPU. |
| `filament_engine_destroy_view` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_view(void* engine, v...` | Destroys the native Filament `filament_engine_destroy_view` resource and releases GPU/host memory. |
| `filament_view_set_scene` | `FFI_PLUGIN_EXPORT void filament_view_set_scene(void* view, void* sc...` | Updates the `filament_view_set_scene` parameter or state in the native C layer. |
| `filament_view_set_camera` | `FFI_PLUGIN_EXPORT void filament_view_set_camera(void* view, void* c...` | Updates the `filament_view_set_camera` parameter or state in the native C layer. |
| `filament_view_set_viewport` | `FFI_PLUGIN_EXPORT void filament_view_set_viewport(void* view, int32...` | Updates the `filament_view_set_viewport` parameter or state in the native C layer. |
| `filament_view_set_name` | `FFI_PLUGIN_EXPORT void filament_view_set_name(void* view, const cha...` | Updates the `filament_view_set_name` parameter or state in the native C layer. |
| `filament_view_set_shadowing_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_shadowing_enabled(void* vi...` | Updates the `filament_view_set_shadowing_enabled` parameter or state in the native C layer. |
| `filament_view_pick` | `FFI_PLUGIN_EXPORT void filament_view_pick(void* view, uint32_t x, u...` | Executes native Filament `filament_view_pick` C binding. |
| `filament_view_set_transparent_picking_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_transparent_picking_enable...` | Updates the `filament_view_set_transparent_picking_enabled` parameter or state in the native C layer. |
| `filament_view_is_transparent_picking_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_transparent_picking_enabled...` | Validates or queries the `filament_view_is_transparent_picking_enabled` state/capability. |
| `filament_view_get_name` | `FFI_PLUGIN_EXPORT const char* filament_view_get_name(void* view);` | Queries the `filament_view_get_name` state, property, or counter from the native C layer. |
| `filament_view_get_scene` | `FFI_PLUGIN_EXPORT void* filament_view_get_scene(void* view);` | Queries the `filament_view_get_scene` state, property, or counter from the native C layer. |
| `filament_view_get_camera` | `FFI_PLUGIN_EXPORT void* filament_view_get_camera(void* view);` | Queries the `filament_view_get_camera` state, property, or counter from the native C layer. |
| `filament_view_has_camera` | `FFI_PLUGIN_EXPORT bool filament_view_has_camera(void* view);` | Validates or queries the `filament_view_has_camera` state/capability. |
| `filament_view_get_viewport` | `FFI_PLUGIN_EXPORT void filament_view_get_viewport(void* view, int32...` | Queries the `filament_view_get_viewport` state, property, or counter from the native C layer. |
| `filament_view_get_render_target` | `FFI_PLUGIN_EXPORT void* filament_view_get_render_target(void* view);` | Queries the `filament_view_get_render_target` state, property, or counter from the native C layer. |
| `filament_view_get_visible_layers` | `FFI_PLUGIN_EXPORT uint8_t filament_view_get_visible_layers(void* vi...` | Queries the `filament_view_get_visible_layers` state, property, or counter from the native C layer. |
| `filament_view_is_shadowing_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_shadowing_enabled(void* view);` | Validates or queries the `filament_view_is_shadowing_enabled` state/capability. |
| `filament_view_is_screen_space_refraction_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_screen_space_refraction_ena...` | Validates or queries the `filament_view_is_screen_space_refraction_enabled` state/capability. |
| `filament_view_get_anti_aliasing` | `FFI_PLUGIN_EXPORT int filament_view_get_anti_aliasing(void* view);` | Queries the `filament_view_get_anti_aliasing` state, property, or counter from the native C layer. |
| `filament_view_set_post_processing_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_post_processing_enabled(vo...` | Updates the `filament_view_set_post_processing_enabled` parameter or state in the native C layer. |
| `filament_view_is_post_processing_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_post_processing_enabled(voi...` | Validates or queries the `filament_view_is_post_processing_enabled` state/capability. |
| `filament_view_set_blend_mode` | `FFI_PLUGIN_EXPORT void filament_view_set_blend_mode(void* view, int...` | Updates the `filament_view_set_blend_mode` parameter or state in the native C layer. |
| `filament_view_get_blend_mode` | `FFI_PLUGIN_EXPORT int filament_view_get_blend_mode(void* view);` | Queries the `filament_view_get_blend_mode` state, property, or counter from the native C layer. |
| `filament_view_set_stencil_buffer_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_stencil_buffer_enabled(voi...` | Updates the `filament_view_set_stencil_buffer_enabled` parameter or state in the native C layer. |
| `filament_view_is_stencil_buffer_enabled` | `FFI_PLUGIN_EXPORT bool filament_view_is_stencil_buffer_enabled(void...` | Validates or queries the `filament_view_is_stencil_buffer_enabled` state/capability. |
| `filament_view_set_front_face_winding_inverted` | `FFI_PLUGIN_EXPORT void filament_view_set_front_face_winding_inverte...` | Updates the `filament_view_set_front_face_winding_inverted` parameter or state in the native C layer. |
| `filament_view_is_front_face_winding_inverted` | `FFI_PLUGIN_EXPORT bool filament_view_is_front_face_winding_inverted...` | Validates or queries the `filament_view_is_front_face_winding_inverted` state/capability. |
| `filament_view_set_dynamic_lighting_options` | `FFI_PLUGIN_EXPORT void filament_view_set_dynamic_lighting_options(v...` | Updates the `filament_view_set_dynamic_lighting_options` parameter or state in the native C layer. |
| `filament_view_set_material_global` | `FFI_PLUGIN_EXPORT void filament_view_set_material_global(void* view...` | Updates the `filament_view_set_material_global` parameter or state in the native C layer. |
| `filament_view_get_material_global` | `FFI_PLUGIN_EXPORT void filament_view_get_material_global(void* view...` | Queries the `filament_view_get_material_global` state, property, or counter from the native C layer. |
| `filament_view_clear_frame_history` | `FFI_PLUGIN_EXPORT void filament_view_clear_frame_history(void* view...` | Executes native Filament `filament_view_clear_frame_history` C binding. |
| `filament_view_set_layer_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_layer_enabled(void* view, ...` | Updates the `filament_view_set_layer_enabled` parameter or state in the native C layer. |
| `filament_view_get_visible_renderable_count` | `FFI_PLUGIN_EXPORT uint32_t filament_view_get_visible_renderable_cou...` | Queries the `filament_view_get_visible_renderable_count` state, property, or counter from the native C layer. |
| `filament_view_set_anti_aliasing` | `FFI_PLUGIN_EXPORT void filament_view_set_anti_aliasing(void* view, ...` | Updates the `filament_view_set_anti_aliasing` parameter or state in the native C layer. |
| `filament_view_set_screen_space_refraction_enabled` | `FFI_PLUGIN_EXPORT void filament_view_set_screen_space_refraction_en...` | Updates the `filament_view_set_screen_space_refraction_enabled` parameter or state in the native C layer. |
| `filament_view_set_visible_layers` | `FFI_PLUGIN_EXPORT void filament_view_set_visible_layers(void* view,...` | Updates the `filament_view_set_visible_layers` parameter or state in the native C layer. |
| `filament_view_set_render_target` | `FFI_PLUGIN_EXPORT void filament_view_set_render_target(void* view, ...` | Updates the `filament_view_set_render_target` parameter or state in the native C layer. |
| `filament_view_set_bloom_options` | `FFI_PLUGIN_EXPORT void filament_view_set_bloom_options(void* view, ...` | Updates the `filament_view_set_bloom_options` parameter or state in the native C layer. |
| *... and 55 additional native C functions* | - | Library FFI bindings. |

## Dart API

### `lib/src/frame_history_stream.dart`

#### `class FrameHistoryStream`

Pure-Dart implementation of Filament's FrameHistoryStream.  Receives batches of [FrameInfo] records, deduplicates them by [FrameInfo.frameId], detects dropped or missing frame gaps, and emits unique completed frames in sequence.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `stream` | `Stream<FrameInfo> get stream` | Stream of individual, deduplicated [FrameInfo] instances in increasing order of frameId. |
| `lastFrameId` | `int get lastFrameId` | The highest frameId processed and emitted so far (0 if none). |
| `droppedFrameCount` | `int get droppedFrameCount` | Cumulative count of dropped/skipped frames detected via frameId discontinuities. |
| `push` | `void push(List<FrameInfo> history)` | Pushes a batch of [FrameInfo] records from [FilamentRenderer.getFrameInfoHistory]. |
| `close` | `void close()` | Closes the underlying stream controller. |

### `lib/src/frame_pacer.dart`

#### `enum FrameStatus`

Status code returned by [FilamentFramePacer.setupFrame] indicating whether the frame should render.

**Constructors:**
- `FrameStatus(this.value)`: Initializes `FrameStatus(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `accepted` | `accepted(0)` | The frame is approved for rendering. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static FrameStatus fromValue(int val)` | Executes `fromValue` operation. |
| `shouldRender` | `bool get shouldRender` | Whether this status approves rendering the frame. |

#### `enum PacingStatus`

Pipeline flow control status for [FilamentFramePacer].

**Constructors:**
- `PacingStatus(this.value)`: Initializes `PacingStatus(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `displayStuffed` | `displayStuffed(1)` | Latency has bloated; display queue is stuffed. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static PacingStatus fromValue(int val)` | Executes `fromValue` operation. |

#### `class HardwareTimeline`

Hardware presentation timeline telemetry.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `expectedPresentationTimeNs` | `int expectedPresentationTimeNs` | Anticipated physical presentation timestamp in nanoseconds on steady clock. |
| `deadlineNs` | `int deadlineNs` | Submission completion deadline in nanoseconds on steady clock. |

#### `class VsyncTick`

VSYNC timing telemetry passed to [FilamentFramePacer.setupFrame].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `baseTimeNs` | `int baseTimeNs` | Base hardware VSYNC tick timestamp in nanoseconds on steady clock. |
| `vsyncPeriodNs` | `int vsyncPeriodNs` | Physical hardware VSYNC period in nanoseconds (defaults to ~16.66ms for 60Hz). |
| `frameScheduleTimeNs` | `int frameScheduleTimeNs` | Time when frame scheduling callback was entered in nanoseconds on steady clock (0 = now). |
| `timelines` | `List<HardwareTimeline> timelines` | Candidate hardware presentation timelines. |

#### `class FramePacerConfiguration`

Dynamic target configuration for [FilamentFramePacer].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `targetFrameRate` | `double targetFrameRate` | Desired rendering frame rate in Hz. |
| `latency` | `Duration latency` | Target latency duration. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class FilamentFramePacer`

Coordinates frame scheduling and presentation timestamps to eliminate micro-stutter.  Typical game loop pattern: ```dart final status = pacer.setupFrame(tick); if (status.shouldRender) { // Advance simulation to pacer.expectedPresentationTime if (!pacer.hasGpuFallenBehind(renderer)) { pacer.applyPresentationTime(renderer); if (renderer.beginFrame(swapChain)) { renderer.render(view); renderer.endFrame(); } } } ```

**Constructors:**
- `FilamentFramePacer.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/frame_pipeline_estimator.dart`

#### `enum TargetPercentile`

Target statistical percentile for workload estimation.

#### `class Workload`

Computed ideal throughput recommendation from [FramePipelineEstimator.estimateWorkload].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `idealFrameDuration` | `Duration idealFrameDuration` | Ideal bottleneck frame duration (throughput). |
| `idealFrameRate` | `double idealFrameRate` | Ideal frame rate in Hz (1.0 / idealFrameDuration). |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class PacingSizing`

Structural latency and CPU safe delay sizing from [FramePipelineEstimator.estimatePacing].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `latencyFrames` | `int latencyFrames` | Recommended structural latency (pipeline depth in frames). |
| `safeDelayDuration` | `Duration safeDelayDuration` | Maximum safe delay before starting CPU work in the frame cycle. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class _TelemetryStats`

`_TelemetryStats`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `count` | `int count` | Holds the `count` property or configuration state. |
| `countGpu` | `int countGpu` | Holds the `countGpu` property or configuration state. |
| `countMargin` | `int countMargin` | Holds the `countMargin` property or configuration state. |
| `meanMain` | `double meanMain` | Holds the `meanMain` property or configuration state. |
| `meanBackend` | `double meanBackend` | Holds the `meanBackend` property or configuration state. |
| `meanGpu` | `double meanGpu` | Holds the `meanGpu` property or configuration state. |
| `meanMargin` | `double meanMargin` | Holds the `meanMargin` property or configuration state. |
| `stdDevMain` | `double stdDevMain` | Holds the `stdDevMain` property or configuration state. |
| `stdDevBackend` | `double stdDevBackend` | Holds the `stdDevBackend` property or configuration state. |
| `stdDevGpu` | `double stdDevGpu` | Holds the `stdDevGpu` property or configuration state. |
| `stdDevMargin` | `double stdDevMargin` | Holds the `stdDevMargin` property or configuration state. |
| `effectiveMain` | `double effectiveMain` | Holds the `effectiveMain` property or configuration state. |
| `effectiveBackend` | `double effectiveBackend` | Holds the `effectiveBackend` property or configuration state. |
| `effectiveGpu` | `double effectiveGpu` | Holds the `effectiveGpu` property or configuration state. |
| `totalTransitTimeNs` | `double totalTransitTimeNs` | Holds the `totalTransitTimeNs` property or configuration state. |
| `effectiveCompositionMarginNs` | `double effectiveCompositionMarginNs` | Holds the `effectiveCompositionMarginNs` property or configuration state. |

#### `class FramePipelineEstimator`

Pure Dart implementation of Filament's `FramePipelineEstimator`.  Calculates ideal refresh rate (throughput) and ideal structural latency (pipeline depth) based on historical [FrameInfo] telemetry using probabilistic Gaussian modeling.  C++ analog: `filament/include/filament/FramePipelineEstimator.h`

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `getZScore` | `static double getZScore(TargetPercentile targetPercentile)` | Converts a [TargetPercentile] to its standard normal distribution Z-score.  Reference: `FramePipelineEstimator::getZScore` |

### `lib/src/render_target.dart`

#### `enum AttachmentPoint`

`AttachmentPoint`: Enumeration listing system options and state constants.

**Constructors:**
- `AttachmentPoint(this.value)`: Initializes `AttachmentPoint(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `depth` | `depth(8)` | Executes `depth` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class RenderTargetAttachment`

`RenderTargetAttachment`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture texture` | Holds the `texture` property or configuration state. |
| `mipLevel` | `int mipLevel` | Holds the `mipLevel` property or configuration state. |
| `face` | `CubemapFace? face` | Holds the `face` property or configuration state. |
| `layer` | `int layer` | Holds the `layer` property or configuration state. |

#### `class FilamentRenderTarget`

An offscreen render target (Frame Buffer Object / FBO) that can be associated with a View.

**Constructors:**
- `FilamentRenderTarget._(this._ptr, this._engine)`: Initializes `FilamentRenderTarget._(this._ptr, this._engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `supportedColorAttachmentsCount` | `static int supportedColorAttachmentsCount(FilamentEngine engine)` | Returns the maximum number of color attachments supported by the engine. |
| `dispose` | `void dispose()` | Destroys this RenderTarget. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/motion_vectors.dart`

#### `class MotionVectorBuffer`

`MotionVectorBuffer`: the motion vectors of a `FilamentView` as a readable buffer: an RGBA16F texture the view exports into while `TemporalAntiAliasingOptions.motionVectors` is on, the render target that reads it back, and the readback itself. The structure pass of Filament (Lumina patch `0004`) renders them from each renderable's previous world transform, its previous bone palette and morph weights, and the previous frame's camera.

**Constructors:**
- `MotionVectorBuffer.attach({required FilamentEngine engine, required FilamentView view, required int width, required int height})`: creates the texture and render target (exactly the size of the view's render target) and makes `view` export into them; throws `StateError` when `view.motionVectorsSupported` is false.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture texture` | The RGBA16F export texture (`TextureUsage.colorAttachment | sampleable | blitSrc`). |
| `renderTarget` | `FilamentRenderTarget renderTarget` | The render target over `texture` the readback uses. |
| `read` | `Future<Float32List> read(FilamentRenderer renderer)` | The motion vectors of the last rendered frame: `width * height * 2` floats, two per texel (x, y), rows from the bottom of the image up. Reads the texture's own half floats and widens them. |
| `velocityAt` | `(double, double) velocityAt(Float32List velocity, int x, int y)` | The (x, y) motion at a top-down pixel coordinate of a buffer returned by `read`. |
| `halfToFloat` | `static double halfToFloat(int h)` | IEEE 754 binary16 to binary32. |
| `dispose` | `void dispose()` | Stops the export (when the view still points at this texture) and destroys the render target and the texture. |

### `lib/src/renderer.dart`

#### `class ClearOptions`

ClearOptions are used at the beginning of a frame to clear or retain SwapChain content.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `clearColor` | `Vector4 clearColor` | Color used to clear the RenderTarget (in linear RGBA space, each component typically 0.0 .. 1.0). |
| `clearStencil` | `int clearStencil` | Value to clear the stencil buffer (0..255). |
| `clear` | `bool clear` | Whether the SwapChain should be cleared using the [clearColor]. |
| `discard` | `bool discard` | Whether the SwapChain content should be discarded. |

#### `class DisplayInfo`

Display properties used by the engine for frame-pacing and dynamic resolution scaling.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `refreshRate` | `double refreshRate` | Refresh rate of the display in Hz (e.g. 60.0, 120.0). Must be > 0. |

#### `class FrameRateOptions`

Options controlling the desired frame rate and dynamic resolution responsiveness.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `headRoomRatio` | `double headRoomRatio` | Additional headroom for the GPU as a ratio of the target frame time (0.0 .. 1.0). |
| `scaleRate` | `double scaleRate` | Rate at which the GPU load is adjusted (e.g. 1/8 = 0.125). |
| `history` | `int history` | History size for smoothing (1 .. 31, default 15). |
| `interval` | `int interval` | Desired frame interval in units of 1 / refreshRate (1 = 60fps on 60Hz, 2 = 30fps on 60Hz). Must be >= 1. |

#### `class FrameInfo`

Timing and latency metrics for a rendered frame.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frameId` | `int frameId` | Holds the `frameId` property or configuration state. |
| `gpuFrameDuration` | `int gpuFrameDuration` | Holds the `gpuFrameDuration` property or configuration state. |
| `denoisedGpuFrameDuration` | `int denoisedGpuFrameDuration` | Holds the `denoisedGpuFrameDuration` property or configuration state. |
| `beginFrame` | `int beginFrame` | Holds the `beginFrame` property or configuration state. |
| `endFrame` | `int endFrame` | Holds the `endFrame` property or configuration state. |
| `backendBeginFrame` | `int backendBeginFrame` | Holds the `backendBeginFrame` property or configuration state. |
| `backendEndFrame` | `int backendEndFrame` | Holds the `backendEndFrame` property or configuration state. |
| `gpuFrameComplete` | `int gpuFrameComplete` | Holds the `gpuFrameComplete` property or configuration state. |
| `vsync` | `int vsync` | Holds the `vsync` property or configuration state. |
| `displayPresent` | `int displayPresent` | Holds the `displayPresent` property or configuration state. |
| `presentDeadline` | `int presentDeadline` | Holds the `presentDeadline` property or configuration state. |
| `displayPresentInterval` | `int displayPresentInterval` | Holds the `displayPresentInterval` property or configuration state. |
| `compositionToPresentLatency` | `int compositionToPresentLatency` | Holds the `compositionToPresentLatency` property or configuration state. |
| `expectedPresentLatency` | `int expectedPresentLatency` | Holds the `expectedPresentLatency` property or configuration state. |
| `frameScheduleTime` | `int frameScheduleTime` | Holds the `frameScheduleTime` property or configuration state. |
| `isGpuPending` | `bool get isGpuPending` | Checks current state or capability and returns a boolean value. |
| `isValidField` | `static bool isValidField(int value)` | Checks current state or capability and returns a boolean value. |

#### `class FilamentRenderer`

A Renderer generates drawing commands for the render thread and manages frame latency.  Typically one Renderer is created per window.

**Constructors:**
- `FilamentRenderer.internal(this._ptr, this._engine)`: Internal constructor for creating a [FilamentRenderer] from a native pointer.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/swap_chain.dart`

#### `class SwapChainConfig`

Configuration flags for swap chain creation.

**Constructors:**
- `SwapChainConfig(this.value)`: Initializes `SwapChainConfig(this.value)`.
- `SwapChainConfig._(this.value)`: Initializes `SwapChainConfig._(this.value)`.
- `SwapChainConfig._(value | other.value)`: Initializes `SwapChainConfig._(value | other.value)`.
- `SwapChainConfig._(value & other.value)`: Initializes `SwapChainConfig._(value & other.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `value` | `int value` | Raw bitfield value. |
| `contains` | `bool contains(SwapChainConfig flag)` | Checks if this configuration contains all flags in [flag]. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `enum FrameRateChangeSupport`

Three-state result for frame rate change support query.

#### `enum FrameRateCompatibility`

Frame rate compatibility mode for [FilamentSwapChain.setFrameRate].

**Constructors:**
- `FrameRateCompatibility(this.value)`: Initializes `FrameRateCompatibility(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fixedSource` | `fixedSource(1)` | Strongly prioritizes running at the exact requested rate (e.g. video playback). |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ChangeFrameRateStrategy`

Change strategy for non-seamless display frame rate transitions.

**Constructors:**
- `ChangeFrameRateStrategy(this.value)`: Initializes `ChangeFrameRateStrategy(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `always` | `always(1)` | Transition is applied immediately, even if a non-seamless display mode switch occurs. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class FilamentSwapChain`

A SwapChain represents the rendering target (typically a window surface).  Use [FilamentEngine.createSwapChain] for windowed rendering or [FilamentEngine.createHeadlessSwapChain] for offscreen rendering.

**Constructors:**
- `FilamentSwapChain.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/view.dart`

#### `class PickingResult`

`PickingResult`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PickingResult(this.renderable, this.depth, this.fragCoords)`: Initializes `PickingResult(this.renderable, this.depth, this.fragCoords)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `renderable` | `FilamentEntity? renderable` | Holds the `renderable` property or configuration state. |
| `depth` | `double depth` | Holds the `depth` property or configuration state. |

#### `class FilamentView`

A View encompasses all the state needed for rendering a Scene.  A View specifies the Scene, Camera, Viewport, and rendering parameters.

**Constructors:**
- `FilamentView.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `scene` | `scene(FilamentScene scene)` | Sets the Scene associated with this View. |
| `scene` | `FilamentScene? get scene` | Getter accessor returning the current value of `scene`. |
| `camera` | `camera(FilamentCamera camera)` | Sets the Camera associated with this View. |
| `camera` | `FilamentCamera? get camera` | Getter accessor returning the current value of `camera`. |
| `renderTarget` | `renderTarget(FilamentRenderTarget? renderTarget)` | Executes `renderTarget` operation. |
| `renderTarget` | `FilamentRenderTarget? get renderTarget` | Getter accessor returning the current value of `renderTarget`. |
| `setViewport` | `void setViewport(int left, int bottom, int width, int height)` | Sets the viewport for this View from explicit coordinates (in bottom-left origin). |
| `setViewportModel` | `void setViewportModel(Viewport vp)` | Sets the viewport for this View from a [Viewport] model. |
| `viewportModel` | `Viewport get viewportModel` | Gets the current viewport as a [Viewport] model. |
| `colorGrading` | `colorGrading(ColorGrading? cg)` | Sets or clears the ColorGrading on this View. Passing null restores the default color grading. |
| `setColorGradingModel` | `void setColorGradingModel(ColorGrading? cg)` | Sets the ColorGrading using a method call. |
| `colorGrading` | `ColorGrading? get colorGrading` | Gets the currently assigned [ColorGrading], if any. |
| `name` | `name(String name)` | Sets the View's name (for debugging). |
| `name` | `String? get name` | Getter accessor returning the current value of `name`. |
| `shadowingEnabled` | `shadowingEnabled(bool enabled)` | Enables or disables shadow mapping on this View. |
| `shadowingEnabled` | `bool get shadowingEnabled` | Getter accessor returning the current value of `shadowingEnabled`. |
| `postProcessingEnabled` | `postProcessingEnabled(bool enabled)` | Enables or disables post-processing on this View. |
| `postProcessingEnabled` | `bool get postProcessingEnabled` | Getter accessor returning the current value of `postProcessingEnabled`. |
| `shadowType` | `shadowType(ShadowType type)` | Executes `shadowType` operation. |
| `shadowType` | `ShadowType get shadowType` | Getter accessor returning the current value of `shadowType`. |
| `vsmShadowOptions` | `vsmShadowOptions(VsmShadowOptions options)` | Executes `vsmShadowOptions` operation. |
| `vsmShadowOptions` | `VsmShadowOptions get vsmShadowOptions` | Getter accessor returning the current value of `vsmShadowOptions`. |
| `softShadowOptions` | `softShadowOptions(SoftShadowOptions options)` | Executes `softShadowOptions` operation. |
| `softShadowOptions` | `SoftShadowOptions get softShadowOptions` | Getter accessor returning the current value of `softShadowOptions`. |
| `blendMode` | `blendMode(BlendMode mode)` | Executes `blendMode` operation. |
| `blendMode` | `BlendMode get blendMode` | Getter accessor returning the current value of `blendMode`. |
| `stencilBufferEnabled` | `stencilBufferEnabled(bool enabled)` | Executes `stencilBufferEnabled` operation. |
| `stencilBufferEnabled` | `bool get stencilBufferEnabled` | Getter accessor returning the current value of `stencilBufferEnabled`. |
| `frontFaceWindingInverted` | `frontFaceWindingInverted(bool inverted)` | Executes `frontFaceWindingInverted` operation. |
| `frontFaceWindingInverted` | `bool get frontFaceWindingInverted` | Getter accessor returning the current value of `frontFaceWindingInverted`. |
| `setDynamicLightingOptions` | `void setDynamicLightingOptions(double zLightNear, double zLightFar)` | Updates the `DynamicLightingOptions` parameter and applies changes to the system. |
| `setMaterialGlobal` | `void setMaterialGlobal(int index, double x, double y, double z, double w)` | Updates the `MaterialGlobal` parameter and applies changes to the system. |
| `clearFrameHistory` | `void clearFrameHistory(FilamentEngine engine)` | Clears all elements from the collection or buffer. |
| `setLayerEnabled` | `void setLayerEnabled(int layer, bool enabled)` | Updates the `LayerEnabled` parameter and applies changes to the system. |
| `visibleRenderableCount` | `int get visibleRenderableCount` | Getter accessor returning the current value of `visibleRenderableCount`. |
| `antiAliasing` | `antiAliasing(int type)` | Sets the anti-aliasing type (e.g., 0 for None, 1 for FXAA). |
| `antiAliasing` | `int get antiAliasing` | Gets the anti-aliasing type. |
| `screenSpaceRefractionEnabled` | `screenSpaceRefractionEnabled(bool enabled)` | Enables or disables screen space refraction. |
| `screenSpaceRefractionEnabled` | `bool get screenSpaceRefractionEnabled` | Gets whether screen space refraction is enabled. |
| `setVisibleLayers` | `void setVisibleLayers(int select, int values)` | Sets visible layers bitmask. |
| `visibleLayers` | `int get visibleLayers` | Getter accessor returning the current value of `visibleLayers`. |
| `bloomOptions` | `bloomOptions(BloomOptions options)` | Executes `bloomOptions` operation. |
| `bloomOptions` | `BloomOptions get bloomOptions` | Getter accessor returning the current value of `bloomOptions`. |
| `fogOptions` | `fogOptions(FogOptions options)` | Executes `fogOptions` operation. |
| `fogOptions` | `FogOptions get fogOptions` | Getter accessor returning the current value of `fogOptions`. |
| `depthOfFieldOptions` | `depthOfFieldOptions(DepthOfFieldOptions options)` | Executes `depthOfFieldOptions` operation. |
| `depthOfFieldOptions` | `DepthOfFieldOptions get depthOfFieldOptions` | Getter accessor returning the current value of `depthOfFieldOptions`. |
| `vignetteOptions` | `vignetteOptions(VignetteOptions options)` | Executes `vignetteOptions` operation. |
| `vignetteOptions` | `VignetteOptions get vignetteOptions` | Getter accessor returning the current value of `vignetteOptions`. |
| `ambientOcclusionOptions` | `ambientOcclusionOptions(AmbientOcclusionOptions options)` | Executes `ambientOcclusionOptions` operation. |
| `ambientOcclusionOptions` | `AmbientOcclusionOptions get ambientOcclusionOptions` | Getter accessor returning the current value of `ambientOcclusionOptions`. |
| `temporalAntiAliasingOptions` | `temporalAntiAliasingOptions(TemporalAntiAliasingOptions options)` | Executes `temporalAntiAliasingOptions` operation. |
| `temporalAntiAliasingOptions` | `TemporalAntiAliasingOptions get temporalAntiAliasingOptions` | Getter accessor returning the current value of `temporalAntiAliasingOptions`. |
| `multiSampleAntiAliasingOptions` | `multiSampleAntiAliasingOptions(MultiSampleAntiAliasingOptions options)` | Executes `multiSampleAntiAliasingOptions` operation. |
| `multiSampleAntiAliasingOptions` | `MultiSampleAntiAliasingOptions get multiSampleAntiAliasingOptions` | Getter accessor returning the current value of `multiSampleAntiAliasingOptions`. |
| `motionVectorsSupported` | `bool get motionVectorsSupported` | Whether the view's engine can render motion vectors (`TemporalAntiAliasingOptions.motionVectors`): a GPU backend at feature level 1 or higher with RG16F colour attachments. False on the noop backend. |
| `motionVectorTexture` | `FilamentTexture? get motionVectorTexture` / `set motionVectorTexture(FilamentTexture? texture)` | The texture the motion vectors are exported into while `motionVectors` is on: a two-or-more-channel float colour texture (colour attachment + sampleable) exactly the size of the view's render target; another size is ignored. Texels hold the screen-space offset of the surface since the previous frame, in texels, x right and y up; the background is zero. Null disables the export. |
| `screenSpaceReflectionsOptions` | `screenSpaceReflectionsOptions(ScreenSpaceReflectionsOptions options)` | Executes `screenSpaceReflectionsOptions` operation. |
| `screenSpaceReflectionsOptions` | `ScreenSpaceReflectionsOptions get screenSpaceReflectionsOptions` | Getter accessor returning the current value of `screenSpaceReflectionsOptions`. |
| `guardBandOptions` | `guardBandOptions(GuardBandOptions options)` | Executes `guardBandOptions` operation. |
| `guardBandOptions` | `GuardBandOptions get guardBandOptions` | Getter accessor returning the current value of `guardBandOptions`. |
| `dynamicResolutionOptions` | `dynamicResolutionOptions(DynamicResolutionOptions options)` | Executes `dynamicResolutionOptions` operation. |
| `dynamicResolutionOptions` | `DynamicResolutionOptions get dynamicResolutionOptions` | Getter accessor returning the current value of `dynamicResolutionOptions`. |
| `renderQuality` | `renderQuality(RenderQuality options)` | Executes `renderQuality` operation. |
| `renderQuality` | `RenderQuality get renderQuality` | Getter accessor returning the current value of `renderQuality`. |
| `dithering` | `dithering(Dithering d)` | Executes `dithering` operation. |
| `dithering` | `Dithering get dithering` | Getter accessor returning the current value of `dithering`. |
| `transparentPickingEnabled` | `transparentPickingEnabled(bool enabled)` | Executes `transparentPickingEnabled` operation. |
| `transparentPickingEnabled` | `bool get transparentPickingEnabled` | Getter accessor returning the current value of `transparentPickingEnabled`. |
| `pick` | `Future<PickingResult> pick(int x, int y)` | Picks a pixel on the screen and returns the rendered entity and depth at that pixel. Note: The coordinates (x, y) are based on a bottom-left origin. |
| `dispose` | `void dispose()` | Destroys this view and releases its resources. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/widget.dart`

**Top-level Functions:**

- **`with SingleTickerProviderStateMixin`**: Executes `SingleTickerProviderStateMixin` operation.

#### `class FilamentWidget`

A Flutter widget for rendering 3D Filament scenes natively.  Manages engine lifecycle, frame rendering loops, and viewport dimensions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `createState` | `State<FilamentWidget> createState() => _FilamentWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

#### `class _FilamentWidgetState`

`_FilamentWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(FilamentWidget oldWidget)` | Getter accessor returning the current value of `didUpdateWidget`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

---

[Previous: Engine, entities and core types](engine.md) | [Up: flutter_filament](index.md) | [Next: View options and color grading](view-options.md)
