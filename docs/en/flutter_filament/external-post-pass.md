[Türkçe](../../tr/flutter_filament/external-post-pass.md)

# External post pass and Vulkan device features

Two hooks for GPU work that lives outside Filament (a denoiser, a learned post-process, an official neural rendering pass once NVIDIA publishes one for Vulkan): a pass that rewrites the HDR frame before colour grading, and feature structures for the Vulkan device. Vulkan only (Windows, Linux x86_64); the other backends and the web skip the pass and enable nothing. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Where the pass runs](#where-the-pass-runs)
- [What the pass receives](#what-the-pass-receives)
- [HDR-stage external upscalers](#hdr-stage-external-upscalers)
- [Vulkan device features](#vulkan-device-features)
- [Native C bridge](#native-c-bridge)
- [Dart API](#dart-api)
- [Limits](#limits)

## Where the pass runs

Lumina's Filament patch `0011` (see `third_party/filament/README.md`) adds `View::setExternalPostPass(ExternalPostPass*)`. Filament calls the registered pass every frame:

1. after its TAA or FSR3 resolve, or after an external upscaler of the `HDR` stage (below),
2. before depth of field, bloom and colour grading,
3. at that point's resolution: the output resolution when TAA upscaling, FSR3 or an HDR upscaler ran, the render resolution otherwise (FSR3 rounds its output up to its alignment, so the image can be a few texels larger than the viewport; the viewport is its lower-left corner).

The pass runs on the backend thread inside Filament's command buffer through the `externalPass` driver command of patch `0006`; it records only, never submits.

## What the pass receives

`ExternalPassContext::images` (all in the general layout):

| index | image |
|---|---|
| `COLOR` (0) | the pre-exposed linear HDR frame (read-only) |
| `DEPTH` (1) | the colour pass depth at the render resolution, reversed Z |
| `MOTION` (2) | RGBA16F at the colour's size: `rg` motion in texels of that size (`uv_curr - uv_prev`, x right, y up), `b` = 1 where the previous position was on screen (history usable), `a` = 1 for the sky |
| `OUTPUT` (3) | RGBA16F storage image at the colour's size; it replaces the colour |

`ExternalPassContext::frame` carries the render and output sizes, the TAA jitter, a frame id, `exposure` (`1 / (1.2 · 2^ev100)`), the `viewFromWorld` matrix, the unjittered `clipFromView` projection and the flags `FLAG_VELOCITY_BUFFER` (the motion came from the structure pass velocity buffer) and `FLAG_HISTORY_RESET` (first frame or a reset).

The motion image is built by Filament's `postPassMotion` material: where the velocity buffer (`TemporalAntiAliasingOptions.motionVectors`) has a value it is rescaled to the pass resolution; elsewhere (motion vectors off, the sky) the surface the jittered depth describes is projected by this and the previous frame's unjittered cameras, so a still camera reports zero motion and a turning one moves the sky. `View::resetExternalPostPassHistory()` makes the next frame report no usable history (camera cuts).

## HDR-stage external upscalers

`ExternalUpscaler::stage()` (default `DISPLAY`) chooses where an external upscaler (patch `0006`) runs: `DISPLAY` is the original slot after colour grading on the LDR frame (DLSS Super Resolution), `HDR` replaces the TAA resolve on the linear HDR frame and writes an RGBA16F image at the output resolution, after which bloom and colour grading run unscaled. Upscalers that also denoise ray-traced lighting need the HDR stage. External passes now take up to eight images (`ExternalPassContext::MAX_IMAGES`).

## Vulkan device features

A Vulkan device gets its extensions and feature structures when it is created, so requests are made before `FilamentEngine.create`. Patch `0011` adds `VulkanPlatform::Customization::extraDeviceFeatures`: for each requested structure (sType, size, the extension it belongs to, the byte offsets of the requested `VkBool32` members) Filament queries the device, enables the requested members it supports and chains the structure. Members the device lacks, structures whose extension is not enabled and structure types Filament already chains itself (multiview, protected memory, buffer device address, acceleration structure, ray query) are skipped with a log line. `VulkanPlatform::isExtraDeviceFeatureEnabled` and `isDeviceExtensionEnabled` report the outcome.

## Native C bridge

`src/vulkan_features_c.h` (implemented in `src/gpu_engine_c.cpp`, per requester, united at engine creation):

- `filament_vulkan_request_device_extension(requester, name)`
- `filament_vulkan_request_device_feature(requester, sType, structSize, fieldOffset, extension)`
- `filament_vulkan_clear_requests(requester)` (NULL clears all)
- `filament_vulkan_device_feature_enabled(engine, sType, fieldOffset)`, `filament_vulkan_device_extension_enabled(engine, name)`

`src/post_pass_c.h`: a debug pass, a compute shader (`src/shaders/post_pass_debug.comp`, compiled by `dart tool/build_post_pass_shaders.dart` into `src/post_pass_debug_spv.h`, needs `glslc`):

- `filament_post_pass_debug_create(engine, view, mode)` → handle or NULL (`filament_post_pass_last_error()`)
- `filament_post_pass_debug_set_mode`, `_frame_count`, `_last_size`, `_destroy`
- `filament_view_reset_external_post_pass_history(view)`

## Dart API

```dart
VulkanFeatures.requestFeature('my_library', VulkanFeature.shaderSubgroupClock); // before the engine
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
VulkanFeatures.isFeatureEnabled(engine, VulkanFeature.shaderSubgroupClock);     // true on GPUs that have it

final pass = DebugPostPass.create(engine: engine, view: view, mode: DebugPostPassMode.motion);
pass.mode = DebugPostPassMode.history;   // green: history usable, red: not
view.resetExternalPostPassHistory();      // camera cut
pass.destroy();
```

`VulkanFeature` has constants for the structures Lumina's NVIDIA work uses (`shaderSubgroupClock`, `shaderDeviceClock`, `cooperativeMatrix`, `opticalFlow`, `shaderFloat8`); any other member is a `VulkanFeature(sType:, structSize:, fieldOffset:, extension:)`. `DebugPostPassMode`: `passthrough`, `motion`, `history`, `invert`.

## Limits

- Vulkan only; `DebugPostPass.create` throws a `StateError` elsewhere, and feature requests enable nothing.
- One external post pass per view.
- Custom vertex displacement is not in the velocity buffer (as for TAA), so such surfaces get the camera's motion only.
