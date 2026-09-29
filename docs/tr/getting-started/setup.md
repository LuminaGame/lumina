[English](../../en/getting-started/setup.md)

# Checkout ve kurulum

Lumina repository'lerinin yan yana nasıl yerleştirileceği, pub workspace'in nasıl çözüleceği, native-assets hook'larının Filament'a nasıl yönlendirileceği ve Filament kütüphanelerinin nasıl build edileceği.

## Checkout düzeni

Lumina repository'leri yan yana checkout edilmek üzere tasarlanmıştır:

```
<dir>/
  lumina/        https://github.com/LuminaGame/lumina
  tools/         https://github.com/LuminaGame/tools
  plugins/       https://github.com/LuminaGame/plugins
  marketplace/   https://github.com/LuminaGame/marketplace
  filament/      prebuilt out/ klasörleriyle yamalı Filament v1.77.0
  test-assets/   https://github.com/LuminaGame/test-assets (isteğe bağlı, Git LFS)
```

`lumina` checkout'unun içinde `filament/` ve `test-assets/`, ortak klasörlere işaret eden ve gitignore edilmiş link'lerdir:

```bash
git clone https://github.com/LuminaGame/lumina.git
cd lumina
ln -s ../filament filament            # Windows: mklink /J filament ..\filament
ln -s ../test-assets test-assets      # isteğe bağlı; Windows: mklink /J test-assets ..\test-assets
```

## Workspace'i çözmek

Repository tek bir Dart pub workspace'idir; kökte çalıştırılan tek bir komut tüm paketleri çözer:

```bash
dart pub get
```

tools, plugins ve marketplace repository'lerindeki paketler git dependency'leridir. Bunların yerine yan yana duran checkout'larınızla çalışmak için kökte, gitignore edilmiş bir `pubspec_overrides.yaml` oluşturun; `dependency_overrides:` girdileri `../tools/...`, `../plugins/...` ve `../marketplace/shared` klasörlerini göstersin (tam liste [repository haritasında](../overview/repositories.md#repositoryler-birbirine-nasıl-bağlanır)), ardından `dart pub get`'i yeniden çalıştırın.

## Native-assets hook ayarları

Hook'lar yollarını workspace kökündeki `pubspec.yaml` dosyasının `hooks: user_defines:` bölümünden okur (yollar bu dosyaya görelidir). Bu repository şunları ayarlar:

```yaml
hooks:
  user_defines:
    flutter_filament:
      filament_dir: filament
    flutter_assimp:
      filament_dir: filament
      libcxx_dir: flutter_filament/third_party/libcxx
    flutter_riglogic:
      riglogic_lib_dir: openriglogic/lib
      libcxx_dir: flutter_filament/third_party/libcxx
```

| Ayar | Paket | Environment override | Varsayılan |
|---|---|---|---|
| `filament_dir` | `flutter_filament`, `flutter_assimp` | `LUMINA_FILAMENT_DIR` | `<package>/../filament` |
| `libcxx_dir` (Linux) | `flutter_assimp`, `flutter_riglogic` | `LUMINA_LIBCXX_DIR` | `<package>/../../lumina/flutter_filament/third_party/libcxx` |
| `riglogic_lib_dir` | `flutter_riglogic` | `LUMINA_RIGLOGIC_LIB_DIR` | `<package>/third_party/openriglogic/lib` (user-define'ın klasöründe kütüphane yoksa da) |

Git'ten çözülen bir paket pub cache'te durur ve yanında Filament yoktur; user-define'lar onun hook'una bu repository'nin `filament/` link'inin nerede olduğunu söyler. Environment override'ları yalnızca doğrudan çalıştırılan bir hook'a ulaşır: Flutter/Dart hooks runner'ı `LUMINA_*` değişkenlerini iletmez.

`flutter_filament/hook/build.dart`, include path'lerinin, derleyici flag'lerinin ve link edilen Filament kütüphanelerinin esas listesidir. Static kütüphaneleri hook dependency'si olarak bildirdiği için bunlardan birini yeniden build etmek, bir sonraki `flutter test` ya da `flutter run` sırasında onu kullanan her şeyi yeniden link eder.

## Filament'i build etmek

Hook'lar static kütüphaneleri `filament/out/cmake-release/` (Linux ve macOS) ya da `filament/out/cmake-release-windows/` (Windows) altında bekler. Lumina, upstream Filament v1.77.0'ı üç yerel yamayla kullanır; yamalar `third_party/filament/patches/` altındadır ve `third_party/filament/README.md` içinde açıklanır:

- gömülü `libassimp` içinde bir sınır (bounds) düzeltmesi;
- skinned ve morph'lu renderable'ları screen-space reflections pass'inin dışında tutan bir `RenderPass.cpp` değişikliği (bu olmadan Vulkan backend'i device'ı kaybeder);
- WebP texture'lı bir WebAssembly build'inin SDL2 olmadan configure edilebilmesi için bir `third_party/libwebp/tnt` değişikliği.

### Hazır arşiv

Filament'i edinmenin en hızlı yolu hazır arşivdir. `tool/filament/VERSION` onu adlandırır (örneğin `1.77.0-lumina.1`); her Lumina release'i `filament-<VERSION>-windows-x64.zip` ve `filament-<VERSION>-linux-x64.tar.gz` dosyalarını, her biri bir `.sha256` dosyasıyla birlikte içerir. Arşivde `filament_dir` olarak kullanılabilen tek bir klasör vardır: hook'ların okuduğu header'lar, kaynaklar ve static kütüphaneler (`tool/filament/prebuilt_manifest.txt` içinde listelenir), `matc`, yamalar ve build'i tarif eden bir `lumina-filament.json`.

İndirmek, doğrulamak ve açmak için:

```bash
dart run tool/filament/fetch_prebuilt.dart --tag <lumina release tag'i>
```

Komut açılan klasörü yazdırır (varsayılan olarak `build/filament-prebuilt/cache/<VERSION>`). Klasörü `filament` olarak link edin ya da `filament_dir`'i ona yönlendirin:

```bash
ln -s "$(dart run tool/filament/fetch_prebuilt.dart --tag v0.1.0)" filament   # Windows: mklink /J filament <klasör>
```

Arşivi upstream Filament ve yamalardan kendiniz build etmek için:

```bash
tool/filament/build_prebuilt.sh                                               # Linux: clang 19+, CMake, Ninja
powershell -ExecutionPolicy Bypass -File tool\filament\build_prebuilt.ps1   # Windows: Visual Studio 2022, Python 3
```

İkisi de Filament'i tag'inden `build/filament-src`'ye (ya da argüman olarak verilen klasöre) clone eder, yamaları uygular, yalnızca hook'ların link ettiği kütüphaneleri ve `matc`'yi build eder ve arşivi `build/filament-prebuilt/`'e yazar. İlk build yaklaşık bir saat sürer, sonraki çalıştırmalar artımlıdır. Build edilmiş `build/filament-src` aynı zamanda `filament_dir`'in gösterebileceği eksiksiz bir Filament checkout'udur. Bir hook'u değiştirdikten sonra manifest'i güncellemek için `dart tool/filament/prebuilt_manifest.dart` çalıştırın; bir yamayı ya da build flag'lerini değiştirdikten sonra `tool/filament/VERSION` içindeki son eki artırın.

### Bir Filament checkout'unda build etmek

**Linux / macOS**, Filament checkout'unda:

```bash
./build.sh -p desktop release
```

Linux'ta sistemdeki clang libc++ header'ları olmadan gelebilir. Bu durumda hem `out/cmake-release` hem de `out/prebuilt-tools-release`'i `flutter_filament/third_party/libcxx` içindeki libc++ ile configure edin: `CMAKE_CXX_FLAGS`'e `-nostdinc++ -isystem <libcxx>/usr/lib/llvm-21/include/c++/v1 -isystem <libcxx>/usr/lib/llvm-21/include`, linker flag'lerine `-L<libcxx>/usr/lib/x86_64-linux-gnu` ekleyin. Tek bir kütüphane `ninja -C out/cmake-release filament` ile yeniden build edilebilir.

**Windows**, `lumina` checkout'undan (C++ workload'lu Visual Studio 2022 ve Python 3 gerekir):

```bat
flutter_filament\tool\build_filament_windows.bat            :: configure (ilk çalıştırma) ve build
flutter_filament\tool\build_filament_windows.bat filament   :: tek bir target'ı yeniden build et
```

Bu script `filament/out/cmake-release-windows/`'u static CRT (`/MT`) ile, Linux build'iyle aynı özellik setinde build eder.

**Web**: `flutter_filament/tool/web/build_filament_web.sh` Filament'i WebAssembly için `filament/out/cmake-wasm-release`'e build eder, `flutter_filament/tool/web/build_module.sh` ise `flutter_filament/web/flutter_filament.{js,wasm}`'ı link eder. Bkz. `flutter_filament/tool/web/README.md`.

## OpenRigLogic'i build etmek

`flutter_riglogic`, tools checkout'unda build edilen static bir OpenRigLogic kütüphanesine link eder:

```bash
bash ../tools/flutter_riglogic/tool/build_openriglogic.sh      # Linux
..\tools\flutter_riglogic\tool\build_openriglogic.bat          # Windows
```

Yukarıdaki `pubspec_overrides.yaml` ile hook kütüphaneyi tools checkout'unda bulur: kök pubspec'teki `riglogic_lib_dir: openriglogic/lib` yalnızca kurulu bir Lumina Studio'nun engine checkout'unda bulunan bir klasörü adlandırır (release'in prebuilt kütüphanesi oraya bağlanır), klasöründe kütüphane olmayan bir user-define ise paketin kendi build'ine bırakır. Bir geliştirme checkout'unda `flutter_riglogic` git'ten çözülüyorsa `riglogic_lib_dir`'i bunun yerine `../tools/flutter_riglogic/third_party/openriglogic/lib`'e yönlendirin.

## Derlenmiş materyaller

`flutter_filament` ve `lumina`, derlenmiş Filament materyalleriyle (`.filamat`) gelir. Bir materyal kaynağını ya da Filament build'ini değiştirdikten sonra bunları her paketin `tool/build_materials.sh` script'iyle yeniden derleyin: engine ile artık uyuşmayan bir materyal yükleme sırasında reddedilir ve bu, başarısız bir test olarak değil, hiçbir şey çizmeyen bir render olarak ortaya çıkar.

## Release'ler ve kurulum

Lumina Studio'yu build etmeden kullanmak için [GitHub releases](https://github.com/LuminaGame/lumina/releases) üzerinden kurun. Installer'lar editörü içine gömmez. Lumina projelerini build etmek için gerekenleri kurar, ardından en son editör build'ini indirir:

| Platform | Installer | Kurdukları |
|---|---|---|
| Windows | `lumina-studio-setup-<tag>-windows-x64.exe` | Git, Visual Studio 2022 C++ Build Tools ve GStreamer (winget), PATH'te yoksa Flutter stable, ardından `%LOCALAPPDATA%\Programs\Lumina Studio` içine editör |
| Linux | `lumina-studio_<version>-1_amd64.deb` / `lumina-studio-<version>-1.x86_64.rpm` | Build bağımlılıkları (clang, CMake, Ninja, GTK 3, GStreamer), `/opt/lumina/flutter` içine Flutter, `/opt/lumina/studio` içine editör; `lumina-studio` ile başlatılır |

Windows setup'ı `/DRYRUN` kabul eder: hiçbir şeyi değiştirmeden neyi kuracağını ve indireceğini listeler. Her release editörün kendisini de (`lumina-studio-<tag>-windows-x64.zip`, `lumina-studio-<tag>-linux-x64.tar.gz` ve imzalıysa bir MSIX) ve editörün ilk açılışta indirdiği, yukarıda anlatılan prebuilt Filament arşivlerini de taşır. Her dosyanın bir `.sha256` sidecar'ı vardır.

`lumina_ui/pubspec.yaml` içindeki sürümle eşleşen bir `v*` tag'i push etmek `.github/workflows/release.yml`'ı çalıştırır. Workflow repository'ler arası pin'leri kontrol eder, Filament'ı build eder (cache'li), Windows ve Linux için Lumina Studio'yu ve installer'ları build eder ve release'i yayımlar. `installer/README.tr.md` her installer'ı, yerelde nasıl build edileceğini ve imzalama secret'larını anlatır.

---

[Önceki: Gereksinimler](requirements.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Editörü ve testleri çalıştırmak](running.md)
