[Türkçe](../../tr/flutter_filament/index.md)

# flutter_filament

`flutter_filament` is the Dart FFI binding to the Google Filament physically based renderer. It is the lowest Dart layer of Lumina: every pixel the engine and the editor draw goes through it.

## Place in the architecture

`flutter_filament` sits directly on top of Filament's C++ libraries and below everything else in Lumina: `lumina` renders through it, and `lumina_ui` also uses it directly for its viewports. See [Layered architecture](../overview/layers.md).

## How the package is built

- **C wrapper**: `src/*_c.h` / `src/*_c.cpp` expose Filament as plain C functions prefixed `filament_*`; `src/filament_c.h` is the umbrella header. Every exported declaration carries `FFI_PLUGIN_EXPORT`.
- **Native-assets hook**: `hook/build.dart` compiles the wrapper on the first `flutter test` or `flutter run` and links about 44 Filament static libraries from `filament/out/cmake-release/` (or `cmake-release-windows/`). It is the authoritative list of include paths, flags (C++20; the bundled libc++ in `third_party/libcxx/` on Linux) and linked libraries.
- **Generated bindings**: `tool/ffigen.dart` writes `lib/src/third_party/filament_c.g.dart`; `tool/ffigen_web.dart` writes the web variants (`filament_c.web.g.dart`, `math_types.web.g.dart`).
- **Dart wrappers**: `lib/src/*.dart` wrap the C functions in classes such as `FilamentEngine`, `FilamentScene`, `FilamentView` and `FilamentAssetLoader`. They import the package's platform shims (`src/ffi_platform.dart`, `src/ffi_package_platform.dart`, `src/filament_bindings.dart`) instead of `dart:ffi`, so the same code runs natively and on the web.
- **Web**: `tool/web/` builds one WebAssembly module (`web/flutter_filament.{js,wasm}`) from the same C wrapper and a WebGL2 Filament build; `lib/src/web_ffi/` provides a `dart:ffi`-compatible layer over the module's heap. Web apps call `await FilamentWeb.ensureInitialized()` before using the engine. Desktop-only libraries (filamat, the full imageio, matdbg, the gltfio JIT) are stubbed on the web so every `filament_*` symbol stays exported.

## Libraries

- `package:flutter_filament/filament.dart`: the Dart API without the view widget; it imports no Flutter library. The engine (`lumina`) imports this one.
- `package:flutter_filament/flutter_filament.dart`: the same plus `FilamentWidget`, which hosts a view in a Flutter app (`lumina_widgets`, `lumina_ui`).
- `package:flutter_filament/ffi.dart` / `ffi_package.dart`: the pointer types for code that passes buffers.

## Adding a native function

1. Write the failing Dart test.
2. Declare the `filament_*` function in `src/<area>_c.h` (included from `src/filament_c.h`) and implement it in `src/<area>_c.cpp`.
3. Run `dart run tool/ffigen.dart`, then `dart run tool/ffigen_web.dart`.
4. Implement the Dart wrapper in `lib/src/`, importing `ffi_platform.dart` rather than `dart:ffi`.

## Reference pages

Each page covers one subsystem: the C functions of its `src/*_c.h` headers first, then the Dart classes of its `lib/src/` files.

| Page | Covers |
|---|---|
| [Engine, entities and core types](engine.md) | Engine lifecycle, entities, shared enums, fences, exceptions, callbacks, diagnostics. |
| [Renderer, views and frame pacing](renderer-and-view.md) | Renderer, swap chains, views, render targets, frame pacing, the Flutter widget. |
| [View options and color grading](view-options.md) | Per-view post-processing and quality options, tone mapping and color grading. |
| [DLSS Super Resolution](dlss.md) | NVIDIA DLSS behind dynamic resolution: the fetched SDK, the extension request before engine creation, quality modes, Ray Reconstruction (the denoising upscaler), limits. |
| [Ray tracing](ray-tracing.md) | Vulkan ray query: the extension request, per-scene acceleration structures, ray-traced sun shadows, visibility rays, limits. |
| [ReSTIR direct lighting](restir.md) | Many punctual lights by reservoir resampling with ray-traced visibility: options, stats, what changes versus froxels, limits. |
| [Guide buffers](guide-buffers.md) | Normal + roughness, diffuse and specular albedo from the lit shaders and the ray-traced specular hit distance, for neural denoisers and upscalers; readback for tests and debug views. |
| [External post pass and Vulkan device features](external-post-pass.md) | The hook for passes on the HDR frame before colour grading (colour, depth, motion with history validity), HDR-stage external upscalers, feature structures requested for the Vulkan device, the debug pass. |
| [Scene and geometry](scene-and-geometry.md) | Scenes, renderables, transforms, vertex/index/instance/morph/skinning buffers, filamesh. |
| [Camera and manipulator](camera-and-manipulator.md) | Cameras, projections, exposure and the orbit/map/free-flight camera manipulator. |
| [Lighting and image-based lighting](lighting-and-ibl.md) | Lights, shadows, indirect light, skyboxes, IBL baking and prefiltering. |
| [Materials](materials.md) | Materials, material instances, parameters and the runtime material compiler. |
| [Textures and images](textures-and-images.md) | Textures, samplers, image I/O, image operations, KTX1/KTX2, Basis transcoding. |
| [glTF loading and animation](gltfio.md) | glTF/GLB assets, instances, material providers, animators, Draco decoding. |
| [Math types](math.md) | Vector, quaternion and matrix value types, boxes, frustums, colors, exposure. |
| [Editor primitives, tools and testing](editor-tools-and-testing.md) | Grid, selection box, transform gizmo, offline tools, smoke-test entry point. |
| [Platform integration and GPU selection](platform.md) | Shared engine host, Vulkan GPU listing and preference, web start-up and the platform widget variants. |

---

[Previous: Running the editor and tests](../getting-started/running.md) | [Up: Lumina documentation](../../README.md) | [Next: Engine, entities and core types](engine.md)
