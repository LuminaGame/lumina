# flutter_filament for the web

The web build is one WebAssembly module, `web/flutter_filament.{js,wasm}`. It contains Filament's WebGL2 backend and our own C wrapper (`src/*_c.cpp`), so the web exports the same `filament_*` functions the Dart bindings call on desktop. The module is single-threaded (no `SharedArrayBuffer`, so no COOP/COEP headers are needed).

## Toolchain

- **emsdk 5.0.4**, the version Filament v1.77.2's CI uses (`filament/build/common/get-emscripten.sh`), installed in `~/emsdk`:
  ```bash
  git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
  cd ~/emsdk && git checkout 5.0.4 && ./emsdk install 5.0.4 && ./emsdk activate 5.0.4
  ```
  Override the location with `EMSDK=...`.
- **Host tools** (matc, resgen, cmgen, …) are a native build exported as prebuilt executables into `filament/out/prebuilt-tools-release`; `tool/web/build_host_tools.sh` builds them (clang against the bundled libc++ on Linux, like `tool/filament/build_prebuilt.sh`).
- **A Filament source tree.** The scripts default to the repository's `filament` link; `LUMINA_FILAMENT_SRC=<dir>` names another checkout, for example the patched one `tool/filament/build_prebuilt.sh --checkout-only <dir>` produces (the pruned prebuilt archive has no sources and cannot be built from).

## Build

```bash
tool/web/build_host_tools.sh     # matc, resgen, cmgen, … → filament/out/prebuilt-tools-release
tool/web/build_filament_web.sh   # Filament → filament/out/cmake-wasm-release (long; incremental after)
tool/web/build_module.sh         # our wrapper + Filament → web/flutter_filament.{js,wasm} (-O3)
OPT=-O1 tool/web/build_module.sh # faster iteration
```

- `build_filament_web.sh` mirrors `filament/build.sh -p wasm`. That script cannot be used as-is on this machine: it also relinks the host tools in `out/cmake-release`, which fails here.
- `JOBS=<n>` limits `ninja -j` in the two Filament builds.

## Continuous integration

`.github/actions/filament-web` runs the three scripts on a Linux runner: it checks out the patched Filament source at `tool/filament/VERSION` into `build/filament-web-src`, installs the emsdk version that checkout's CI uses (`build/common/get-emscripten.sh`), builds the host tools and Filament for WebAssembly (cached as one tree, keyed by the patches, the version and the scripts), and links the module. The `web` job of `ci.yml` then runs `test/web/` in headless Chrome and uploads `flutter-filament-web`; the `web` job of `release.yml` attaches `flutter-filament-web-<tag>.zip` (+ `.sha256`) to the Lumina release.
- `build_module.sh` reads the source and include lists from `hook/build.dart`, and the exported symbols from the ffigen output (`tool/web/exported_symbols.mjs`), so the web module and the desktop library cannot drift.

## The Dart side

The same wrapper code runs on both platforms:
- **Platform imports**: wrappers import `lib/src/ffi_platform.dart`, `lib/src/ffi_package_platform.dart` and `lib/src/filament_bindings.dart`. These re-export `dart:ffi`, `package:ffi` and the ffigen bindings natively, and `lib/src/web_ffi/` plus the generated web files on the web.
- **`lib/src/web_ffi/`**: a `dart:ffi` / `package:ffi`-compatible layer over the module's heap.
  - `Pointer` is a wasm32 address;
  - `Struct` / `Union` / `Array` are views over the heap;
  - `NativeCallable` goes through Emscripten's function table;
  - `NativeFinalizer` sits on dart:core `Finalizer`;
  - `calloc`, `malloc`, `Arena`, `Utf8` allocate through the module.
- **Generator**: `dart run tool/ffigen_web.dart` rewrites the ffigen output into `lib/src/third_party/filament_c.web.g.dart`: 1,113 functions calling the exports, 33 struct/union views laid out for wasm32, plus callback-type and `Native.addressOf` registrations. It also rewrites `lib/src/math_types.dart` into `math_types.web.g.dart`. Re-run it after `tool/ffigen.dart`; `test/web/bindings_lockstep_test.dart` fails if you forget.
- **App start-up**: `await FilamentWeb.ensureInitialized(moduleUrl: ...)` loads the module and registers the generated layouts (a no-op natively).
- **Heap growth** detaches `TypedData` views. Re-derive views after allocating. `LinearImage.data` and `IblImage.data` do this themselves.

Both `flutter build web` (dart2js) and `flutter build web --wasm` compile a flutter_filament consumer.

## FilamentWidget on the web

`FilamentWidget` is the same widget on every platform. On the web (`lib/src/widget_web.dart`) it:
- hosts its own `<canvas>` in a platform view, registered with Emscripten as `'!flutter-filament-N'` (`specialHTMLTargets`, so shadow roots do not matter);
- creates its engine with `FilamentEngine.createForCanvas`;
- presents every frame straight into the canvas (no readback);
- sizes the drawing buffer to the layout × `devicePixelRatio`.

A web app must serve `flutter_filament.js` and `flutter_filament.wasm` next to its `index.html` (copy them into the app's `web/`), or call `FilamentWeb.ensureInitialized(moduleUrl: …)` before the first widget. See `example/lib/web_smoke.dart`, which `test/web/widget_web_smoke_test.dart` builds and drives in headless Chrome.

## Tests

```bash
node --test test/web/module_test.mjs          # exports, heap, ABI parity (also run by flutter test)
flutter test test/web/                        # + the headless-Chrome canvas smoke and the browser suite
flutter test --platform chrome test/web_browser/   # the Dart layer in Chrome (memory layer, API smoke with a GLB)
UPDATE_ABI_GOLDEN=1 flutter test test/web/abi_golden_test.dart   # after an intentional ABI change
```

- `test/web/abi_golden.json` holds the desktop library's struct sizes and enum values; the module must reproduce them.
- `test/web/canvas_smoke_test.dart` draws in headless Chrome (SwiftShader WebGL2) through the C functions only, and saves its PNG to the smoke report.

## Not available on the web (by design, for now)

WebP textures (`EXT_texture_webp`) are on: `build_filament_web.sh` passes `FILAMENT_SUPPORTS_WEBP_TEXTURES=ON`, which needs the vendored `third_party/libwebp/tnt` patch.

These Filament libraries are desktop tools and are not part of Filament's WebAssembly build:
- **filamat**: runtime material compiler;
- **full imageio codecs**;
- **matdbg**: material inspector;
- **gltfio JIT shader provider**: it needs filamat;
- **Suzanne sample resources**.

Their `filament_*` functions still exist on the web, so the Dart bindings are identical. The bodies are generated by `tool/web/gen_web_stubs.mjs` (`src/web_stubs_c.cpp`, or hand-written in `tools_c.cpp` / `gltf_c.cpp` / `geometry_c.cpp`), log one line, and return zero or null.

What this means for games:
- materials must ship as compiled filamat packages for OpenGL ES (`matc -a opengl -p mobile`) instead of being compiled at runtime;
- glTF assets use the ubershader provider.
- fragment samplers: WebGL 2 gives a shader 16 (ANGLE's Direct3D 11 backend, Chrome's default on Windows, crashes its GPU process on some 16-sampler lit shaders). A lit shader spends up to 7 on the per-view set (structure, shadow map, the two IBL textures, SSAO, SSR, fog), so keep a material at 8 samplers or fewer; the ubershader uses 8. The Vulkan-only ray query textures (`sampler0_rtShadow`, the ReSTIR textures) are not sampled in OpenGL / WebGL shaders (Filament patch `0010`).

Regenerate the stubs after changing `filamat_c.h` or `imageio_c.h`:
```bash
node tool/web/gen_web_stubs.mjs
```
