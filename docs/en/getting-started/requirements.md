[Türkçe](../../tr/getting-started/requirements.md)

# Requirements

What you need installed before you can build and run Lumina: the Flutter SDK, melos, a C/C++ toolchain for the native-assets hooks, a prebuilt Filament and a few optional tools.

## Always

- **Flutter SDK** with Dart `^3.12.0` (the SDK constraint of every package in the workspace).
- **melos 7** for the workspace scripts. It is a dev dependency of the root pubspec, so `dart run melos` works after `dart pub get`; `dart pub global activate melos` puts `melos` on the `PATH`.
- **A prebuilt Google Filament v1.77.2** with Lumina's local patches, as static libraries. Each Lumina release attaches a ready archive for Windows and Linux (x64), which `tool/filament/fetch_prebuilt.dart` downloads; `tool/filament/build_prebuilt.sh` / `build_prebuilt.ps1` build the same archive from upstream Filament. See [Checkout and setup](setup.md#build-filament).
- **A GPU with Vulkan or OpenGL** to run the editor and the smoke tests. Unit tests of `flutter_filament` run on Filament's noop backend and need no GPU.

## C/C++ toolchain

The native-assets hooks compile the C wrappers of `flutter_filament`, `flutter_assimp` and `flutter_riglogic` on the first `flutter test` or `flutter run`. There is no manual build step for them, but a toolchain must be installed:

- **Linux**: clang, CMake and Ninja. The hooks compile against the libc++ bundled in `flutter_filament/third_party/libcxx`, so the system clang does not need its own libc++ headers. That libc++ needs **glibc 2.38 or newer** (Ubuntu 24.04, Debian 13, Fedora 39 or later).
- **Windows**: Visual Studio 2022 with the C++ workload (MSVC, CMake, Ninja) and Python 3.

## Native libraries from the tools repository

- **OpenRigLogic**: `flutter_riglogic` links a static OpenRigLogic library that is built from its vendored sources (see the [tools documentation](https://github.com/LuminaGame/tools/tree/main/docs)).
- **Assimp** needs nothing extra: `flutter_assimp` links the Assimp library of the Filament build.

## Optional

- **GStreamer 1.x** with the base and good plugin sets: `flutter_gstreamer` uses it to encode smoke-test videos in-process. Without it, `SmokeArtifacts` falls back to `ffmpeg` (with `ffprobe`) when that is on the `PATH`.
- **The test-assets repository** ([LuminaGame/test-assets](https://github.com/LuminaGame/test-assets), Git LFS): real 3D models used by tests and smoke tests. Tests that need them are skipped when they are missing.
- **Linux pointer capture**: GTK 3 and, for Wayland pointer lock, `wayland-client`, `wayland-scanner` and `wayland-protocols` (used by `lumina_mouse_capture`).
- **Web builds**: emsdk 5.0.4, the version Filament v1.77.2 uses, to build `flutter_filament`'s WebAssembly module (`flutter_filament/tool/web/README.md`).

---

[Previous: Data flow](../overview/data-flow.md) | [Up: Lumina documentation](../../README.md) | [Next: Checkout and setup](setup.md)
