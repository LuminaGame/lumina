[English](../../en/getting-started/requirements.md)

# Gereksinimler

Lumina'yı build edip çalıştırmadan önce kurulu olması gerekenler: Flutter SDK, melos, native-assets hook'ları için bir C/C++ toolchain, önceden build edilmiş Filament ve birkaç isteğe bağlı araç.

## Her zaman

- **Flutter SDK**, Dart `^3.12.0` ile (workspace'teki her paketin SDK kısıtı).
- Workspace script'leri için **melos 7**. Kök pubspec'in bir dev dependency'sidir; bu yüzden `dart pub get` sonrasında `dart run melos` çalışır. `dart pub global activate melos` ise `melos`'u `PATH`'e ekler.
- Lumina'nın yerel yamalarıyla, static kütüphaneler halinde **önceden build edilmiş Google Filament v1.77.2**. Her Lumina release'i Windows ve Linux (x64) için hazır bir arşiv içerir; `tool/filament/fetch_prebuilt.dart` bunu indirir. `tool/filament/build_prebuilt.sh` / `build_prebuilt.ps1` aynı arşivi upstream Filament'ten build eder. Bkz. [Checkout ve kurulum](setup.md#filamenti-build-etmek).
- Editörü ve smoke testleri çalıştırmak için **Vulkan ya da OpenGL destekli bir GPU**. `flutter_filament`'in unit testleri Filament'in noop backend'inde çalışır ve GPU gerektirmez.

## C/C++ toolchain

Native-assets hook'ları, `flutter_filament`, `flutter_assimp` ve `flutter_riglogic`'in C wrapper'larını ilk `flutter test` ya da `flutter run` sırasında derler. Bunlar için elle bir build adımı yoktur, ancak bir toolchain kurulu olmalıdır:

- **Linux**: clang, CMake ve Ninja. Hook'lar `flutter_filament/third_party/libcxx` içinde gelen libc++'a karşı derler; bu yüzden sistemdeki clang'ın kendi libc++ header'larına ihtiyacı yoktur. Bu libc++ **glibc 2.38 ya da üstünü** ister (Ubuntu 24.04, Debian 13, Fedora 39 ve sonrası).
- **Windows**: C++ workload'u ile Visual Studio 2022 (MSVC, CMake, Ninja) ve Python 3.

## tools repository'sinden native kütüphaneler

- **OpenRigLogic**: `flutter_riglogic`, vendored kaynaklarından build edilen static bir OpenRigLogic kütüphanesine link eder (bkz. [tools dokümantasyonu](https://github.com/LuminaGame/tools/tree/main/docs)).
- **Assimp** ek bir şey gerektirmez: `flutter_assimp`, Filament build'indeki Assimp kütüphanesine link eder.

## İsteğe bağlı

- Base ve good plugin set'leriyle **GStreamer 1.x**: `flutter_gstreamer` smoke test videolarını in-process encode etmek için bunu kullanır. GStreamer yoksa `SmokeArtifacts`, `PATH`'te bulunuyorsa `ffmpeg`'e (ve `ffprobe`'a) geri döner.
- **test-assets repository'si** ([LuminaGame/test-assets](https://github.com/LuminaGame/test-assets), Git LFS): testlerin ve smoke testlerin kullandığı gerçek 3D modeller. Bunlara ihtiyaç duyan testler, dosyalar yoksa atlanır.
- **Linux pointer capture**: GTK 3 ve Wayland pointer lock için `wayland-client`, `wayland-scanner` ve `wayland-protocols` (`lumina_mouse_capture` kullanır).
- **Web build'leri**: `flutter_filament`'in WebAssembly modülünü build etmek için Filament v1.77.2'ın kullandığı sürüm olan emsdk 5.0.4 (`flutter_filament/tool/web/README.md`).

---

[Önceki: Veri akışı](../overview/data-flow.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Checkout ve kurulum](setup.md)
