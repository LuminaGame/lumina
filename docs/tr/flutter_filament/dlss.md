[English](../../en/flutter_filament/dlss.md)

# DLSS Super Resolution

Filament'in dinamik çözünürlüğünün arkasında NVIDIA DLSS Super Resolution: view, NGX'in kalite modu için seçtiği çözünürlükte render edilir ve DLSS çıktı boyutunu yeniden oluşturur. Yalnızca NVIDIA RTX GPU'larda Vulkan (Windows, Linux x86_64); diğer tüm backend'ler, GPU'lar ve web Filament'in FSR1 yolunda kalır. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Filament'e nasıl oturur](#filamente-nasıl-oturur)
- [SDK ve lisansı](#sdk-ve-lisansı)
- [İşlem sırası](#işlem-sırası)
- [Native C köprüsü (`src/dlss_c.h`)](#native-c-köprüsü-srcdlss_ch)
- [Dart API (`lib/src/dlss.dart`)](#dart-api-libsrcdlssdart)
- [Kalite modları](#kalite-modları)
- [Sınırlar](#sınırlar)

## Filament'e nasıl oturur

Lumina'nın Filament yaması `0006` (bkz. `third_party/filament/README.md`) Filament'e bir *harici upscaler* ekler: `DynamicResolutionOptions.upscaler` (`Upscaler.builtin` ya da `Upscaler.external`) ve `View::setExternalUpscaler`. Etkinken Filament kamerayı TAA'daki gibi jitter'lamaya ve yama `0004`'ün hareket vektörlerini render etmeye devam eder, ama kendi TAA resolve'unu atlar; düşük çözünürlüklü renk, derinlik ve hareket vektörlerini tam çözünürlüklü bir çıktı görüntüsüyle birlikte, kare içinde ve backend thread'inde, Vulkan `externalPass` komutuyla kayıtlı upscaler'a verir. `Dlss` o upscaler'dır: NGX değerlendirmesini Filament'in command buffer'ına kaydeder. Upscaler bir kareyi reddederse (yanlış boyut, NGX hatası) Filament FSR1'e döner, view render etmeyi sürdürür.

## SDK ve lisansı

NGX SDK (`nvsdk_ngx*.h`, statik giriş noktası kütüphanesi ve `nvngx_dlss` runtime'ı) GPL ile uyumlu olmayan NVIDIA DLSS SDK lisansına tabidir. Hiçbir parçası commit edilmez, bir Lumina release arşivine ya da kurucusuna konmaz, kullanıcının makinesi dışında bir yerden yüklenmez:

```bash
dart run tool/dlss/fetch_sdk.dart            # build/dlss-sdk/ içine indirir (gitignore'lu)
dart run tool/dlss/fetch_sdk.dart --check    # mevcut dosyaları doğrular
```

Release etiketi `tool/dlss/VERSION` içinde, her dosyanın SHA-256'sı ve boyutu `tool/dlss/manifest.txt` içinde sabitlenmiştir; lisans metni `build/dlss-sdk/LICENSE.txt` olarak iner. Native build (`hook/build.dart`) `src/dlss_c.cpp` dosyasını `FLUTTER_FILAMENT_DLSS=1` ile derler ve NGX stub'ını yalnızca o klasör varsa bağlar; klasörsüz bir checkout eskisi gibi derlenir, test edilir ve render eder, `Dlss.available` false olur. Çalışma zamanında `nvngx_dlss` kütüphanesi `LUMINA_DLSS_DIR` (klasörün kendisi ya da bir SDK kökü), çalıştırılabilir dosyanın yanı ve indirilen SDK klasöründe aranır.

## İşlem sırası

1. `Dlss.available` true: runtime bulundu ve bir NVIDIA Vulkan cihazı var.
2. `FilamentEngine.create` **öncesinde** `Dlss.requestExtensions()`: NGX'in istediği Vulkan instance ve device uzantıları var olan bir cihaza sonradan eklenemez. `Dlss.clearExtensionRequest()` sonraki motorlar için geri alır.
3. Motoru Vulkan backend'inde, view'ı, sahneyi ve kamerayı her zamanki gibi oluşturun.
4. `view.temporalAntiAliasingOptions = TemporalAntiAliasingOptions(enabled: true, motionVectors: true)`: jitter'lı kamera ve velocity buffer DLSS'i besler; DLSS etkinken Filament'in TAA resolve'u atlanır.
5. `Dlss.create(engine:, view:, options: DlssOptions(quality:, outputWidth:, outputHeight:))`. Çıktı boyutu view'ın viewport'udur. Çağrı NGX'i cihaz için başlatır, optimum render çözünürlüğünü okur (`renderResolution`), upscaler'ı kaydeder ve `DynamicResolutionOptions(enabled: true, upscaler: Upscaler.external, minScale == maxScale == render / output)` ayarlar.
6. Kareleri render edin. `quality` modu değiştirir (feature bir sonraki karede yeniden oluşturulur), `resetHistory()` kamera kesmeleri için zamansal geçmişi temizler.
7. `destroy()` feature'ı serbest bırakır ve view'ı dinamik çözünürlük kapalı olarak `Upscaler.builtin`'e döndürür. Her `Dlss`'i motorundan önce yok edin.

Yeniden boyutlanan bir view yeni çıktı boyutuyla yeni bir `Dlss` ister.

## Native C köprüsü (`src/dlss_c.h`)

| C Fonksiyonu | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `filament_dlss_available` | `bool filament_dlss_available(void);` | NGX runtime bulundu ve bir NVIDIA Vulkan cihazı var. |
| `filament_dlss_request_extensions` | `bool filament_dlss_request_extensions(void);` | Bundan sonra oluşturulan motorlardan NGX Vulkan uzantılarını ister; NGX yoksa false. |
| `filament_dlss_clear_extension_request` | `void filament_dlss_clear_extension_request(void);` | Sonraki motorlar için isteği unutur. |
| `filament_dlss_create` | `void* filament_dlss_create(void* engine, void* view, const filament_dlss_options_t* opts);` | NGX'i motorun cihazı için başlatır, optimum render boyutunu sorgular, upscaler'ı kaydeder ve dinamik çözünürlüğü açar; hata durumunda `filament_dlss_last_error` dolu olarak NULL. |
| `filament_dlss_get_render_resolution` | `void filament_dlss_get_render_resolution(void* dlss, uint32_t* out_w, uint32_t* out_h);` | NGX'in seçtiği render çözünürlüğü (hata sonrası 0,0). |
| `filament_dlss_set_quality` | `void filament_dlss_set_quality(void* dlss, uint8_t quality);` | Kalite modunu değiştirir; feature bir sonraki karede yeniden oluşturulur. |
| `filament_dlss_reset_history` | `void filament_dlss_reset_history(void* dlss);` | Bir sonraki değerlendirme için zamansal geçmişi sıfırlar. |
| `filament_dlss_destroy` | `void filament_dlss_destroy(void* dlss);` | Feature'ı serbest bırakır ve yerleşik upscaler'ı geri getirir; NULL güvenli. |
| `filament_dlss_last_error` | `const char* filament_dlss_last_error(void);` | Son hata (süreç genelinde) ya da başarılı çağrıdan sonra NULL. |

`filament_dlss_options_t` şunları taşır: `quality` (`filament_dlss_quality`), `outputWidth`, `outputHeight`, `hdr`, `autoExposure`, `sharpness`. `filament_dynamic_resolution_options` yapısına `upscaler` (`filament_upscaler`) eklendi.

## Dart API (`lib/src/dlss.dart`)

#### `enum DlssQuality`

`maxPerformance`, `balanced`, `maxQuality`, `ultraPerformance`, `dlaa` (doğal çözünürlük, yalnızca anti-aliasing).

#### `class DlssOptions`

| Özellik | Tip | Açıklama |
| :--- | :--- | :--- |
| `quality` | `DlssQuality` | Kalite modu; varsayılan `balanced`. |
| `outputWidth`, `outputHeight` | `int` | View'ın viewport (çıktı) boyutu. |
| `hdr` | `bool` | Renk girdisi HDR; Filament DLSS'e color grading sonrası LDR kareyi verdiğinden false kalır. |
| `autoExposure` | `bool` | Pozlamayı DLSS ölçsün; varsayılan true. |
| `sharpness` | `double` | 0 (kapalı) .. 1; güncel DLSS sürümleri yok sayar. |

#### `class Dlss`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `available` | `static bool get available` | NGX runtime bulundu ve bir NVIDIA Vulkan cihazı var. |
| `requestExtensions` | `static bool requestExtensions()` | Motor oluşturulmadan önce çağrılmalı; DLSS yoksa false (ve değişiklik yok). |
| `clearExtensionRequest` | `static void clearExtensionRequest()` | Sonraki motorlar NGX uzantıları olmadan oluşturulur. |
| `lastErrorMessage` | `static String? get lastErrorMessage` | NGX ya da sarmalayıcının bildirdiği son hata, yoksa null. |
| `Dlss.create` | `factory Dlss.create({required FilamentEngine engine, required FilamentView view, required DlssOptions options})` | Feature'ı oluşturur ve view'ı harici upscaler'a geçirir; DLSS yoksa, motor uzantısızsa ya da NGX reddederse hata mesajıyla `StateError` fırlatır. |
| `renderResolution` | `(int, int) get renderResolution` | Güncel kalite için NGX'in seçtiği render çözünürlüğü. |
| `quality` | `set quality(DlssQuality)` | Modu değiştirir; view'ın dinamik çözünürlük ölçeği izler. |
| `resetHistory` | `void resetHistory()` | Bir sonraki kare için zamansal geçmişi temizler. |
| `lastError` | `String? get lastError` | `lastErrorMessage` ile aynı, örnek üzerinden. |
| `destroy` | `void destroy()` | Feature'ı serbest bırakır; view `Upscaler.builtin`'e döner. Tekrarlanabilir. |
| `isDestroyed` | `bool get isDestroyed` | `destroy()` çalıştı mı. |

```dart
Dlss.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
final view = engine.createView();
// ... sahne, kamera, 1920x1080 viewport
view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
final dlss = Dlss.create(
  engine: engine,
  view: view,
  options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: 1920, outputHeight: 1080),
);
final (w, h) = dlss.renderResolution; // Balanced için yaklaşık 1114x626
// render...
dlss.destroy();
```

## Kalite modları

| Mod | Eksen başına render ölçeği (1080p çıktı) |
| :--- | :--- |
| `ultraPerformance` | yaklaşık %33 (640×360) |
| `maxPerformance` | yaklaşık %50 (960×540) |
| `balanced` | yaklaşık %58 (1114×626) |
| `maxQuality` | yaklaşık %67 (1280×720) |
| `dlaa` | %100 (yalnızca anti-aliasing) |

Kesin boyutlar NGX'ten gelir (`NGX_DLSS_GET_OPTIMAL_SETTINGS`) ve SDK sürümleri arasında değişebilir.

## Sınırlar

- Yalnızca Vulkan, yalnızca DLSS destekli NVIDIA GPU'lar; OpenGL, Metal, WebGPU ve web `Dlss.available == false` döndürür.
- DLSS Frame Generation ve Ray Reconstruction entegre değildir.
- DLSS'in aldığı kare LDR'dir (color grading sonrası); DLSS üzerinden HDR çıktı, upscaler'ın color grading'den önce çalışmasını gerektirir.
- Lumina Studio render ayarlarında DLSS'i henüz göstermez; oyunlar `Dlss`'i doğrudan çağırır.
