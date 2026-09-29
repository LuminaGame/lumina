[Türkçe](../../tr/getting-started/running.md)

# Running the editor and tests

How to start Lumina Studio, run a package's unit tests, produce the GPU smoke report and use the melos workspace scripts.

## Start Lumina Studio

The editor is the `lumina_ui` Flutter app. From the repository root:

```bash
cd lumina_ui
flutter run -d linux        # or: -d windows, -d macos
```

The first run compiles the native wrappers through the native-assets hooks, which takes a while. The stock editor starts with the project launcher; projects that use code plugins get their own editor host binary.

On a machine with several GPUs, `FILAMENT_GPU` selects the Vulkan device by a name substring or an index (for example `FILAMENT_GPU=RTX` or `FILAMENT_GPU=1`); `VK_DEVICE_INDEX` is honoured when `FILAMENT_GPU` is not set.

## Run tests

Each package keeps its tests under `test/`. Run the files that cover what you changed, from the package directory:

```bash
cd flutter_filament
flutter test test/src/engine_test.dart
```

- `flutter_filament` unit tests run on Filament's noop backend and need no GPU.
- Tests use real files and real native libraries. Tests that need models from `test-assets/` are skipped when the assets are missing; `LUMINA_TEST_ASSETS` points them at another folder.
- `lumina_ui` also has integration flows under `integration_test/` (`flutter test integration_test/<file>`).

## Smoke tests and the HTML report

Smoke tests render on the real GPU and publish PNG screenshots and videos as evidence. The smoke-test system is the [`lumina_smoke`](https://github.com/LuminaGame/tools/blob/main/docs/en/lumina_smoke.md) package of the tools repository:

- `package:lumina_smoke/lumina_smoke.dart`: `SmokeArtifacts` (PNG and VP8/WebM artifacts with a sidecar JSON), `SmokeVideo` (the smoke-video rules and probe), `SmokeVideoRecorder`, `SmokeWebm` and the other encoders and tools;
- `package:lumina_smoke/flutter.dart`: `SmokeRecorder`, which records a running app, and `SmokeCapture`, which captures widget and integration-test PNGs;
- `package:lumina_smoke/report.dart`: the report runner (`smokeReportMain`, `SmokeReportConfig`, the generator and the live dashboard).

Each package re-exports it for its tests (`package:flutter_filament/testing.dart`, `package:lumina/testing.dart`, `package:lumina_ui/testing.dart`; lumina and lumina_ui add their own `SmokeArtifacts` on top). Each of `flutter_filament`, `lumina` and `lumina_ui` keeps a thin `tool/smoke_report.dart`: its `SmokeReportConfig` (title, test categories) and a `main` that calls `smokeReportMain`. It runs the tests on the configured GPU and writes `build/smoke_report.html` (plus one page per category under `build/smoke_report/`), which links the files in `build/smoke_artifacts/` (share them together):

```bash
dart run tool/smoke_report.dart                                  # the whole smoke suite, from a clean build/
dart run tool/smoke_report.dart test/smoke/<file>_test.dart     # one file, merged into the existing report
dart run tool/smoke_report.dart <file> --plain-name <scenario>  # one scenario
dart run tool/smoke_report.dart <target> --fresh                # a targeted run that starts clean
dart run tool/smoke_report.dart --all                           # unit, smoke and integration tests
dart run tool/smoke_report.dart --report-only                   # re-render from the events file
```

Artifacts are matched to their tests by the declared test name through a sidecar JSON file, never by modification time. Every smoke video must be at least 10 s long, at least 1024x768 and at least 30 fps of real frames, with no frame held longer than 2 s; a video that breaks a rule is refused when it is saved. `LUMINA_SMOKE_OUT` redirects the artifact directory and `LUMINA_SMOKE_REPORT_OUT` the report page.

## Workspace scripts

From the repository root (`dart run melos run <script>` works without a global melos):

```bash
melos run analyze        # flutter analyze in every package
melos run format         # dart format
melos run format:check   # fail on unformatted sources
melos run test           # flutter test in every package with a test/ folder, one package at a time
melos run smoke          # every smoke suite, merged into each package's build/smoke_report.html
```

`tool/ci.sh` (a POSIX shell script; Git Bash on Windows) rebuilds the compiled materials, then runs the unit suites and the smoke reports of all four packages:

```bash
tool/ci.sh               # unit + smoke for every package
tool/ci.sh --unit        # unit suites only (no GPU needed)
tool/ci.sh --smoke       # smoke reports only
tool/ci.sh lumina        # one package: flutter_filament | lumina | lumina_editor_api | lumina_ui
```

## Regenerating the Filament bindings

After editing a C header in `flutter_filament/src/`, regenerate both the native and the web bindings, in this order:

```bash
cd flutter_filament
dart run tool/ffigen.dart
dart run tool/ffigen_web.dart
```

`test/web/bindings_lockstep_test.dart` fails when the web bindings were not regenerated. Every exported `filament_*` function must be declared in a header included from `src/filament_c.h` and carry the `FFI_PLUGIN_EXPORT` macro, otherwise it is missing from the generated bindings or, on Windows, from the DLL exports.

---

[Previous: Checkout and setup](setup.md) | [Up: Lumina documentation](../../README.md) | [Next: flutter_filament](../flutter_filament/index.md)
