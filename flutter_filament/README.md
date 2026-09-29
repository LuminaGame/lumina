# flutter_filament

Dart FFI bindings to [Google Filament](https://github.com/google/filament) for the
Lumina engine and Lumina Studio. The package exposes Filament's engine, renderer,
scene/entity managers, materials, gltfio, image/ktx utilities, IBL prefiltering
and editor primitives (gizmos, wireframes) through a thin C wrapper.

## Layout

| Path | Purpose |
|---|---|
| `src/*_c.h` / `src/*_c.cpp` | C wrappers (`filament_*` functions). `src/filament_c.h` is the umbrella header. |
| `lib/src/third_party/filament_c.g.dart` | Generated FFI bindings (do not edit by hand). |
| `lib/src/*.dart` | Dart wrappers (`FilamentEngine`, `FilamentScene`, `FilamentAssetLoader`, …). |
| `hook/build.dart` | Native-assets build hook: include paths, flags and the list of Filament static libs. |
| `test/` | Unit tests (noop backend, no GPU). `test/smoke/` renders on the real GPU. |
| `tool/ffigen.dart` | Regenerates the bindings from the C headers. |
| `tool/smoke_report.dart` | Runs the smoke suite on GPU 1 and emits `build/smoke_report.html`. |

## Prerequisites

Prebuilt Filament static libraries are expected under `../filament/out/cmake-release/`
(built from the vendored `../filament` checkout with `./build.sh -p desktop release`).
The C code is compiled by the native-assets hook on the first `flutter test` / `flutter run`;
there is no manual build step.

## Commands

```bash
flutter test                                    # unit tests, noop backend
flutter test test/src/engine_test.dart          # single file
dart run tool/ffigen.dart                       # after editing src/*_c.h
dart run tool/smoke_report.dart                 # GPU smoke suite + HTML report (starts clean)
dart run tool/smoke_report.dart test/smoke/camera_smoke_test.dart   # one file, merged into the report
FILAMENT_SMOKE_BACKEND=vulkan flutter test .claude/skills/run-flutter-filament/render_smoke.dart
```

## Adding a native function

1. Write the failing Dart test.
2. Declare the `filament_*` function in `src/<area>_c.h` and implement it in `src/<area>_c.cpp`
   (every exported function must be declared in a header included from `src/filament_c.h`,
   otherwise `tool/ffigen.dart` drops it).
3. `dart run tool/ffigen.dart`.
4. Implement the Dart wrapper in `lib/src/`.
