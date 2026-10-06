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

## Limits

- Vulkan only, NVIDIA GPUs with DLSS support only; OpenGL, Metal, WebGPU and the web report `Dlss.available == false`.
- DLSS Frame Generation and Ray Reconstruction are not integrated.
- The frame DLSS receives is LDR (after colour grading); HDR output through DLSS would need the upscaler before colour grading.
- Lumina Studio does not expose DLSS in its rendering settings yet; games call `Dlss` directly.
