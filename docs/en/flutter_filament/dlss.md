[Türkçe](../../tr/flutter_filament/dlss.md)

# DLSS Super Resolution

NVIDIA DLSS Super Resolution behind Filament's dynamic resolution: the view renders at the resolution NGX picks for a quality mode and DLSS reconstructs the output size. Vulkan on NVIDIA RTX GPUs (Windows, Linux x86_64) only; every other backend, GPU and the web keep Filament's FSR1 path. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [How it fits Filament](#how-it-fits-filament)
- [The SDK and its licence](#the-sdk-and-its-licence)
- [Order of operations](#order-of-operations)
- [Native C bridge (`src/dlss_c.h`)](#native-c-bridge-srcdlss_ch)
- [Dart API (`lib/src/dlss.dart`)](#dart-api-libsrcdlssdart)
- [Quality modes](#quality-modes)
- [Ray Reconstruction](#ray-reconstruction)
- [Frame Generation](#frame-generation)
- [Limits](#limits)

## How it fits Filament

Lumina's Filament patch `0006` (see `third_party/filament/README.md`) adds an *external upscaler* to Filament: `DynamicResolutionOptions.upscaler` (`Upscaler.builtin` or `Upscaler.external`) and `View::setExternalUpscaler`. While it is active Filament still jitters the camera as for TAA and renders the motion vectors of patch `0004`, but skips its own TAA resolve and hands the low-resolution colour, depth and motion vectors plus a full-resolution output image to the registered upscaler inside the frame, on the backend thread, through a Vulkan `externalPass` command. `Dlss` is that upscaler: it records the NGX evaluation into Filament's command buffer. When the upscaler declines a frame (wrong size, NGX failure) Filament falls back to FSR1, so the view keeps rendering.

## The SDK and its licence

The NGX SDK (`nvsdk_ngx*.h`, the static entry-point library and the `nvngx_dlss` runtime) is covered by NVIDIA's DLSS SDK licence, which is not GPL-compatible. Nothing of it is committed, packaged into a Lumina release or installer, or loaded from anywhere but the user's machine:

```bash
dart run tool/dlss/fetch_sdk.dart            # downloads into build/dlss-sdk/ (gitignored)
dart run tool/dlss/fetch_sdk.dart --check    # verifies what is there
```

The release tag is pinned in `tool/dlss/VERSION`, every file's SHA-256 and size in `tool/dlss/manifest.txt`; the licence text lands in `build/dlss-sdk/LICENSE.txt`. The native build (`hook/build.dart`) compiles `src/dlss_c.cpp` with `FLUTTER_FILAMENT_DLSS=1` and links the NGX stub only when that folder exists; a checkout without it builds, tests and renders exactly as before, and `Dlss.available` is false. At run time the `nvngx_dlss` library is looked up in `LUMINA_DLSS_DIR` (the folder or an SDK root), next to the executable, then in the fetched SDK folder.

The hook declares the SDK's header and entry-point library as dependencies; while one is missing it declares the deepest existing folder on its path instead (creating an empty `build/dlss-sdk/` if needed), because the hooks runner treats a missing file as just modified and would re-run the hook on every build. Fetching (or deleting) the folder therefore makes the next `flutter run` / `flutter test` of any package re-run the hook exactly once and build the DLSS path in (or out), and later runs skip it again: no `flutter clean` is needed, only a relaunch of the app that was running before the fetch. Lumina Studio started from source (`flutter run` in `lumina_ui`) then shows the DLSS HUD button as available on an NVIDIA RTX GPU; an installed editor carries no NGX code and cannot gain it afterwards.

## Order of operations

1. `Dlss.available` is true: the runtime was found and an NVIDIA Vulkan device exists.
2. `Dlss.requestExtensions()` **before** `FilamentEngine.create`: NGX needs Vulkan instance and device extensions that cannot be added to an existing device. `Dlss.clearExtensionRequest()` undoes it for later engines.
3. Create the engine on the Vulkan backend, the view, scene and camera as usual.
4. `view.temporalAntiAliasingOptions = TemporalAntiAliasingOptions(enabled: true, motionVectors: true)`: the jittered camera and the velocity buffer feed DLSS; Filament's TAA resolve is skipped while DLSS is active.
5. `Dlss.create(engine:, view:, options: DlssOptions(quality:, outputWidth:, outputHeight:))`. The output size is the view's viewport. The call initialises NGX for the device, reads the optimal render resolution (`renderResolution`), registers the upscaler and sets `DynamicResolutionOptions(enabled: true, upscaler: Upscaler.external, minScale == maxScale == render / output)`.
6. Render frames. `quality` changes the mode (the feature is recreated on the next frame), `resetHistory()` clears the temporal history for a camera cut.
7. `destroy()` releases the feature and returns the view to `Upscaler.builtin` with dynamic resolution disabled. Destroy every `Dlss` before its engine.

A resized view needs a new `Dlss` with the new output size.

## Native C bridge (`src/dlss_c.h`)

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_dlss_available` | `bool filament_dlss_available(void);` | The NGX runtime was found and an NVIDIA Vulkan device is present. |
| `filament_dlss_request_extensions` | `bool filament_dlss_request_extensions(void);` | Asks the engines created from now on for the NGX Vulkan extensions; false when NGX is absent. |
| `filament_dlss_set_runtime_dir` | `void filament_dlss_set_runtime_dir(const char* dir);` | Where to look for the `nvngx_dlss` runtime first (an SDK root or the library's folder), ahead of `LUMINA_DLSS_DIR`, the executable folder and the working directory; NULL forgets the hint. |
| `filament_dlss_clear_extension_request` | `void filament_dlss_clear_extension_request(void);` | Forgets the request for later engines. |
| `filament_dlss_create` | `void* filament_dlss_create(void* engine, void* view, const filament_dlss_options_t* opts);` | Initialises NGX for the engine's device, queries the optimal render size, registers the upscaler and enables dynamic resolution; NULL with `filament_dlss_last_error` set on failure. |
| `filament_dlss_get_render_resolution` | `void filament_dlss_get_render_resolution(void* dlss, uint32_t* out_w, uint32_t* out_h);` | The render resolution NGX chose (0,0 after a failure). |
| `filament_dlss_set_quality` | `void filament_dlss_set_quality(void* dlss, uint8_t quality);` | Changes the quality mode; the feature is recreated on the next frame. |
| `filament_dlss_reset_history` | `void filament_dlss_reset_history(void* dlss);` | Resets the temporal history for the next evaluation. |
| `filament_dlss_destroy` | `void filament_dlss_destroy(void* dlss);` | Releases the feature and restores the builtin upscaler; NULL-safe. |
| `filament_dlss_last_error` | `const char* filament_dlss_last_error(void);` | The last error (process-wide), or NULL after a successful call. |

`filament_dlss_options_t` holds `quality` (`filament_dlss_quality`), `outputWidth`, `outputHeight`, `hdr`, `autoExposure` and `sharpness`. `filament_dynamic_resolution_options` gained `upscaler` (`filament_upscaler`).

## Dart API (`lib/src/dlss.dart`)

#### `enum DlssQuality`

`maxPerformance`, `balanced`, `maxQuality`, `ultraPerformance`, `dlaa` (native resolution, anti-aliasing only).

#### `class DlssOptions`

| Property | Type | Description |
| :--- | :--- | :--- |
| `quality` | `DlssQuality` | The quality mode; default `balanced`. |
| `outputWidth`, `outputHeight` | `int` | The view's viewport (output) size. |
| `hdr` | `bool` | The colour input is HDR; Filament hands DLSS the LDR frame after colour grading, so it stays false. |
| `autoExposure` | `bool` | Let DLSS measure exposure itself; default true. |
| `sharpness` | `double` | 0 (off) to 1; current DLSS releases ignore it. |

#### `class Dlss`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `available` | `static bool get available` | The NGX runtime was found and an NVIDIA Vulkan device is present. |
| `requestExtensions` | `static bool requestExtensions()` | Must run before the engine is created; false (and no change) when DLSS is unavailable. |
| `runtimeDirectory` | `static set runtimeDirectory(String? dir)` | Where the runtime is looked for first (an SDK root or the library's folder); set it before `available` is read. |
| `clearExtensionRequest` | `static void clearExtensionRequest()` | Later engines are created without the NGX extensions. |
| `lastErrorMessage` | `static String? get lastErrorMessage` | The last error NGX or the wrapper reported, or null. |
| `Dlss.create` | `factory Dlss.create({required FilamentEngine engine, required FilamentView view, required DlssOptions options})` | Creates the feature and switches the view to the external upscaler; throws `StateError` with the error message when DLSS is unavailable, the engine lacks the extensions or NGX declines. |
| `renderResolution` | `(int, int) get renderResolution` | The render resolution NGX chose for the current quality. |
| `quality` | `set quality(DlssQuality)` | Changes the mode; the view's dynamic resolution scale follows. |
| `resetHistory` | `void resetHistory()` | Clears the temporal history for the next frame. |
| `lastError` | `String? get lastError` | Same as `lastErrorMessage`, per instance. |
| `destroy` | `void destroy()` | Releases the feature; the view returns to `Upscaler.builtin`. Idempotent. |
| `isDestroyed` | `bool get isDestroyed` | Whether `destroy()` ran. |

```dart
Dlss.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
final view = engine.createView();
// ... scene, camera, viewport 1920x1080
view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
final dlss = Dlss.create(
  engine: engine,
  view: view,
  options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: 1920, outputHeight: 1080),
);
final (w, h) = dlss.renderResolution; // about 1114x626 for Balanced
// render...
dlss.destroy();
```

## Quality modes

| Mode | Render scale per axis (1080p output) |
| :--- | :--- |
| `ultraPerformance` | about 33% (640×360) |
| `maxPerformance` | about 50% (960×540) |
| `balanced` | about 58% (1114×626) |
| `maxQuality` | about 67% (1280×720) |
| `dlaa` | 100% (anti-aliasing only) |

The exact sizes come from NGX (`NGX_DLSS_GET_OPTIMAL_SETTINGS`) and may change between SDK releases.

## Ray Reconstruction

DLSS Ray Reconstruction (NGX feature `dlssd`, `nvngx_dlssd`) replaces the upscaler *and* the denoiser of a ray-traced frame with one network: it takes the noisy HDR colour at the render resolution, depth, motion vectors and the [guide buffers](guide-buffers.md), and writes a denoised, anti-aliased HDR frame at the output resolution. In Lumina it denoises ReSTIR lighting (one visibility ray per pixel) and ray-traced shadow edges.

- **Where it runs**: an external upscaler of the `HDR` stage (patch `0011`, see [External post pass and Vulkan device features](external-post-pass.md)): in place of Filament's TAA, before bloom and colour grading. It asks for all four guides (`ExternalUpscaler::guideBuffers()`), which arrive as images 4–7.
- **Runtime**: `tool/dlss/manifest.txt` pins `lib/Windows_x86_64/rel/nvngx_dlssd.dll` and `lib/Linux_x86_64/rel/libnvidia-ngx-dlssd.so.310.9.1`; `dart run tool/dlss/fetch_sdk.dart` fetches them next to `nvngx_dlss` (never committed, NVIDIA's licence). NGX is initialised once per engine and shared with Super Resolution (`src/ngx_c.cpp`).
- **Order**: `DlssRayReconstruction.available` → `Dlss.requestExtensions()` and `RayTracing.requestExtensions()` before the engine → a scene with ray tracing (ReSTIR, ray-traced shadows) → `DlssRayReconstruction.create(engine:, view:, options: DlssRayReconstructionOptions(quality:, outputWidth:, outputHeight:, preset:))`. Creating it turns on the view's guide buffers, TAA jitter and motion vectors, and dynamic resolution at the NGX render size; `destroy()` restores the previous options.
- **Settings sent to NGX**: packed roughness (normals.w), hardware (reversed-Z) depth, motion scale (−1, −1), jitter = −Filament's sample offset, `IsHDR | AutoExposure | MVLowRes | DepthInverted`, the camera's view and unjittered projection matrices, the specular hit distance. Presets: `DlssRayReconstructionPreset.f` (default, the SDK 310.9 transformer model), `e`, `d`, `defaultPreset`.
- **C bridge** (`src/dlss_rr_c.h`): `filament_dlss_rr_available`, `_supported(engine)`, `_create(engine, view, const filament_dlss_rr_options_t*)` with `{ quality, outputWidth, outputHeight, preset }`, `_get_render_resolution`, `_set_quality`, `_reset_history`, `_last_gpu_time_ns` (Vulkan timestamps around the evaluation), `_frame_count`, `_destroy`, `_last_error`.
- **Measured on the RTX PRO 2000** (SDK 310.9.1, preset F): Balanced at 1920×1080 renders 1114×626 and the evaluation takes 4.6 ms; Max Quality at 1024×768 (683×512) 1.8 ms. On raw one-ray ReSTIR (two candidates, no reuse) at 1280×720 the temporal noise (per-pixel luma standard deviation over 16 still frames) falls to 29 % of Filament's TAA (0.53 against 1.85 on a 0..255 scale); on Lumina's default ReSTIR, which already reuses samples, to 76 % (0.53 against 0.69). Against a 128-frame accumulation of the TAA image the PSNR is about 1 dB lower than TAA's (the reference is TAA's own mean; Ray Reconstruction also upscales from 67 %).

## Frame Generation

DLSS Frame Generation (NGX feature `dlssg`, `nvngx_dlssg`) generates frames between two rendered frames from the final image, the depth and the motion; Multi Frame Generation generates up to five per rendered frame (6x) on RTX 50 class GPUs. Lumina drives NGX directly on Vulkan (no Streamline):

- **Probe**: `DlssFrameGeneration.probe(engine)` reads `FrameGeneration.Available`, the driver requirement, `DLSSG.MultiFrameCountMax` and the device extensions NGX asks for. `DlssFrameGeneration.requestExtensions()` (with `Dlss.requestExtensions()`) before the engine adds what Frame Generation uses.
- **Presenting** (`DlssFrameGenerator.create(engine:, view:, generatedFrames:)`): an external frame generator (Filament patch `0013`, `View::setExternalFrameGenerator`) receives the view's final frame, its depth and the motion at its size, and writes `generatedFrames` frames. The first is presented in place of the frame's present; `Renderer::endFrame` presents the others and then the rendered frame. With `SwapChainConfig.disableVsync` the presents are spaced evenly (the wait is part of the render thread); `FilamentRenderer.getPresentTimes()` returns the most recent present times. Only views rendered straight into a SwapChain get extra presents; a view drawn into a texture (a Flutter widget, so Lumina Studio's viewport and Flutter-hosted games) is composited at Flutter's rate and shows the first generated frame of each rendered frame instead. FSR3 frame generation (patch `0009`) takes precedence when both are on.
- **Inspecting** (`DlssFrameInterpolator.create(engine:, view:)`): runs the network as an external post pass and shows the generated frame in place of the rendered one, so its quality can be measured.
- **C bridge** (`src/dlss_fg_c.h`): `filament_dlss_fg_available`, `_request_extensions`, `_clear_extension_request`, `_probe`, `_create`, `_set_generated_frames`, `_frame_count`, `_last_result`, `_last_gpu_time_ns`, `_destroy`, the `_interpolator_*` functions and `_last_error`; `filament_renderer_get_present_times` in `src/renderer_c.h`.
- **Measured on the RTX PRO 2000** (SDK 310.9.1, 1024×768): `MultiFrameCountMax` 5 (up to 6x); 2x, 4x and 6x present exactly 2, 4 and 6 frames per rendered frame; NGX takes 1.6 ms (2x), 3.6 ms (4x) and 5.4 ms (6x) of GPU time per rendered frame. A generated frame of a sliding prop is 36.9 dB from the rendered true midpoint (24.5 dB from either neighbour). Without vsync no two presents of a frame are submitted back to back (none of 119 intervals under 1 ms), but the presented rate does not rise: Filament paces on its single render thread, so the waits between the presents of one frame lengthen the frame itself (4x: about 60 presents/s against 80 plain frames/s in the test loop). A real gain needs presentation paced off the render thread (a present thread or `VK_KHR_present_wait`), which this integration does not do; with vsync the SwapChain's own blocking spaces the presents at the refresh rate.

## Limits

- Vulkan only, NVIDIA GPUs with DLSS support only; OpenGL, Metal, WebGPU and the web report `Dlss.available == false`.
- [Frame Generation](#frame-generation) adds presents only for views rendered into a SwapChain; Flutter-hosted views show one generated frame per rendered frame.
- The frame DLSS Super Resolution receives is LDR (after colour grading): it is an external upscaler of the `DISPLAY` stage. Patch `0011` adds the `HDR` stage (in place of the TAA resolve, before bloom and colour grading) for upscalers that need the linear frame; see [External post pass and Vulkan device features](external-post-pass.md).
- Lumina Studio drives DLSS from the viewport HUD; games choose it through the game user settings (`LuminaUserSettingsSubsystem`, Blueprint **Set Upscaler** / **Is DLSS Supported**, see `lumina/world.md`), which fall back to FSR3 or none where DLSS is unavailable. A game built without the fetched SDK has no NGX code, like an installed editor.
