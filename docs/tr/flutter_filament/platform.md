[English](../../en/flutter_filament/platform.md)

# Platform entegrasyonu ve GPU seçimi

Binding'lerin platform yapıştırıcısı: backend ve GPU başına tek bir Filament engine'ini lease'ler üzerinden paylaştıran engine host, Vulkan GPU listeleme ve tercihi, web'de ve native'de `FilamentWeb` başlatma ve Flutter widget'ının native ve web varyantları. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/engine_host.dart`](#libsrcengine_hostdart)
- [`lib/src/gpu.dart`](#libsrcgpudart)
- [`lib/src/platform_info.dart`](#libsrcplatform_infodart)
- [Android derlemeleri](#android-derlemeleri)
- [`lib/src/web_init_native.dart`](#libsrcweb_init_nativedart)
- [`lib/src/web_init_web.dart`](#libsrcweb_init_webdart)
- [`lib/src/widget_native.dart`](#libsrcwidget_nativedart)
- [`lib/src/widget_web.dart`](#libsrcwidget_webdart)

## `lib/src/engine_host.dart`

### `class FilamentEngineLease`

A claim on a shared [FilamentEngine].

Every holder — a viewport, a thumbnail renderer, a sub-editor that frees engine objects in its own `dispose` — takes one and releases it when it is done with the engine. The engine stays alive while any lease is held and is destroyed by [FilamentEngineHost] after the last [release], once its engine-scoped resources are gone.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `owner` | `final String owner` | Who holds this lease, for leak reports (`FilamentEngineHost.leaseOwners`). |
| `engine` | `FilamentEngine get engine` | The shared engine. Throws after [release]. |
| `isReleased` | `bool get isReleased` | Whether [release] was called. |
| `release` | `void release()` | Gives the engine back. The last release destroys it (engine-scoped resources first). Calling it again does nothing. |

### `abstract final class FilamentEngineHost`

One Filament engine per process and GPU, shared by every viewport.

Engines are keyed by backend and GPU preference (`gpu`, else [FilamentEngine.defaultGpuPreference] at the time of the call), so viewports asking for the same GPU share one engine, and changing the preference gives new viewports a new engine while existing ones keep theirs. Each viewport still owns its own swap chain, renderer, view, scene and camera on it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `acquire` | `static FilamentEngineLease? acquire({String owner = 'anonymous', FilamentBackend backend = FilamentBackend.def...` | A lease on the shared engine for [backend] and [gpu], creating the engine (with [config], only used then) when there is none. Null when no engine can be created on this host. |
| `retain` | `static FilamentEngineLease? retain(FilamentEngine engine, {String owner = 'anonymous'})` | Another lease on [engine] if the host owns it; null for an engine created directly with `FilamentEngine.create` (its creator owns it). |
| `owns` | `static bool owns(FilamentEngine engine)` | Whether the host owns [engine]. |
| `leaseCount` | `static int leaseCount(FilamentEngine engine)` | How many leases hold [engine] (0 when the host does not own it). |
| `leaseOwners` | `static List<String> leaseOwners(FilamentEngine engine)` | The owners of [engine]'s leases, in the order they were taken. |
| `liveEngines` | `static List<FilamentEngine> get liveEngines` | The engines the host currently owns. |
| `liveEngineCount` | `static int get liveEngineCount` | How many engines the host currently owns. |

## `lib/src/gpu.dart`

### `enum FilamentGpuType`

The kind of a Vulkan physical device (`VkPhysicalDeviceType`).

**Değerler:**

- `other`
- `integrated`
- `discrete`
- `virtualGpu`
- `cpu`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fromVulkan` | `static FilamentGpuType fromVulkan(int type)` |  |
| `label` | `String get label` | A short label for pickers: Discrete, Integrated, Virtual, CPU, Other. |

### `class FilamentGpuInfo`

One Vulkan device, as the system loader enumerates it.

**Yapıcı Metotlar (Constructors):**

- `const FilamentGpuInfo({required this.name, required this.type, required this.vendorId, required this.deviceId, required this.index,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `type` | `final FilamentGpuType type` |  |
| `vendorId` | `final int vendorId` |  |
| `deviceId` | `final int deviceId` |  |
| `index` | `final int index` | Position in the loader's enumeration: the index a [FilamentGpuPreference] or `VK_DEVICE_INDEX` refers to. |

### `class FilamentGpuPreference`

Which GPU a Vulkan engine should render on: a device-name substring, an enumeration index, or neither ([automatic], Filament's own choice unless the environment sets `FILAMENT_GPU` / `VK_DEVICE_INDEX`). Other backends ignore it.

**Yapıcı Metotlar (Constructors):**

- `const FilamentGpuPreference({this.deviceName, this.index})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `deviceName` | `final String? deviceName` |  |
| `index` | `final int? index` |  |
| `automatic` | `static const FilamentGpuPreference automatic` |  |
| `isAutomatic` | `bool get isAutomatic` |  |

### `abstract final class FilamentGpu`

Lists the GPUs a Vulkan engine can render on.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `listVulkanDevices` | `static List<FilamentGpuInfo> listVulkanDevices()` | Enumerates the Vulkan devices through the system loader, independently of any engine. Empty when Vulkan is unavailable (and on the web). |
| `livePlatformCount` | `static int get livePlatformCount` | Vulkan platforms alive in this process: one per Vulkan engine not yet disposed. For leak checks. |

## `lib/src/platform_info.dart`

### `abstract final class FilamentPlatformInfo`

Çalışan flutter_filament derlemesinin ne olduğu; platforma göre farklı bir yol seçen kod (material sağlayıcı, backend, özellik) için.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isWeb` | `static bool get isWeb` | Web (WebAssembly + WebGL2) derlemesi. |
| `isAndroid` | `static bool get isAndroid` | Android derlemesi (telefonlar ve Quest gibi bağımsız gözlükler): varsayılan Vulkan, OpenGL ES'e geri düşüş, mobil feature level, JIT glTF materyali yok, matdbg ve imageio kodlayıcıları yok; ray query, ReSTIR ve DLSS desteklenmiyor olarak raporlanır. |
| `hasJitMaterialProvider` | `static bool get hasJitMaterialProvider` | JIT glTF material sağlayıcısının bu derlemede olup olmadığı; false ise `FilamentMaterialProvider.ubershader` kullanın. |

## Android derlemeleri

Native-assets hook'u `libflutter_filament.so`'yu `arm64-v8a` ve `x86_64` için derler ve `filament/out/android-release/filament/lib/<abi>/` altındaki statik kütüphaneleri (`hook/native_inputs.dart` içindeki `androidFilamentLibs`) bağlar; üretilmiş başlıklar (`uberarchive.h`, IBL prefilter materyalleri) aynı kurulum ağacından gelir. Bu arşivler masaüstü prebuilt ile aynı upstream etiketinden ve yamalardan derlenir: `tool/filament/build_prebuilt.ps1 -Android` NDK 28 ile derler ve `filament-<VERSION>-android.tar.gz` paketler; `dart run tool/filament/fetch_prebuilt.dart --android` bunu prebuilt klasörünün `out/android-release` dizinine açar (lumina_core'da `FilamentPrebuiltAndroid`). 0020 yaması ray query materyallerini Android derlemesinin dışında bırakır.

- **Tek kaynak listesi.** Her sarmalayıcı kaynağı (`nativeSources`) her hedef için derlenir; Android'de olmayan şey dosyanın içinde derleme dışı kalır, böylece `src/filament_c.h`'deki tüm `filament_*` fonksiyonları dışa aktarılır ve web stub'ları gibi "desteklenmiyor" döndürür (`false`, `0`, `nullptr`, ıskalayan bir ışın). `test/hook/android_link_test.dart` derlenmiş bir kütüphaneyi başlıklarla karşılaştırır.
- **Backend.** `FilamentBackend.defaultBackend` Android'de de Vulkan demektir (Filament kendisi OpenGL ES seçerdi). Vulkan engine'i oluşturulamazsa engine OpenGL ES'e geri düşer ve `Vulkan is not available; falling back to OpenGL ES` yazar (logcat etiketi `flutter_filament`). Vulkan engine'i masaüstündeki aynı platform alt sınıfını alır (`VulkanPlatformAndroid`); böylece `FilamentEngine.gpuName`, GPU bellek bütçesi ve eklenti / özellik istekleri orada da çalışır.
- **Materyaller.** Mobil feature level, bir materyalin MOBILE gölgelendiricilerini yükler. Paketlerle gelen her materyal `-p all` ile derlenir (flutter_filament ve lumina'daki `tool/materials.txt`); `test/src/material_platform_test.dart` iki gölgelendirici modelini de denetler.
- **glTF.** Android'in gltfio'sunda JIT material sağlayıcısı yoktur; `FilamentMaterialProvider.ubershader` kullanın (bkz. `FilamentPlatformInfo.hasJitMaterialProvider`).
- **Eklenti modülü.** `android/` yalnızca Flutter'ın eklenti yükleyicisi için bir kütüphane modülüdür; kütüphane hook'tan gelir.
- **Cihaz denetimi.** Örnek uygulamanın First Light örneği (`--dart-define=FLUTTER_FILAMENT_SAMPLE=first_light`) `/sdcard/Android/data/com.lumina.flutter_filament_example/files/first_light/` dizinine itilen `.glb` dosyalarını yükler, bir güneş ve bir IBL altında döndürür ve backend'i, GPU'yu ve kare sürelerini loglar (`[first_light]` satırları). Quest 3S'te `Adreno (TM) 740` (Vulkan 1.3, feature level 1) üzerinde 2D panel olarak çalışır.

## `lib/src/web_init_native.dart`

### `abstract final class FilamentWeb`

Platform initialisation for flutter_filament.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ensureInitialized` | `static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async` | Native platforms link the library at build time: nothing to do. |
| `isWeb` | `static const bool isWeb` | Whether this is a web build. |

## `lib/src/web_init_web.dart`

### `abstract final class FilamentWeb`

Platform initialisation for flutter_filament.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ensureInitialized` | `static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async` | Loads the WebAssembly module (`flutter_filament.js` + `.wasm` from [moduleUrl]'s directory) and registers the generated struct layouts and callback types. Call once before using any flutter_filament API on the web. Idempotent. |
| `isWeb` | `static const bool isWeb` | Whether this is a web build. |

## `lib/src/widget_native.dart`

### `class NativeFilamentWidgetState`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `createFilamentWidgetState` | `State<FilamentWidget> createFilamentWidgetState()` | Native platformlar: headless bir swap chain'e çizer ve geri okunan kareyi bir [RawImage] ile gösterir; `nativeSurface` verilirse o penceredeki bir SwapChain'e çizer ve sunumu Filament yapar (bkz. renderer-and-view.md, *Doğrudan sunum*). |

## `lib/src/widget_web.dart`

### `class WebFilamentWidgetState`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `createFilamentWidgetState` | `State<FilamentWidget> createFilamentWidgetState()` | Web builds: Filament's WebGL2 backend presents straight into a `<canvas>` hosted by a platform view — no readback, no decode. |

---

[Önceki: Editör primitifleri, araçlar ve test](editor-tools-and-testing.md) | [Üst: flutter_filament](index.md) | [Sonraki: Harici Vulkan bağlamı ve swapchain görüntüleri](external-vulkan.md)
