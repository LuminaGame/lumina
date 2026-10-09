[English](../../en/flutter_filament/external-post-pass.md)

# Harici post pass ve Vulkan aygıt özellikleri

Filament dışında yaşayan GPU işleri (bir denoiser, öğrenilmiş bir post-process, NVIDIA Vulkan için yayımladığında resmi bir nöral render geçişi) için iki kanca: renk düzenlemeden önce HDR kareyi yeniden yazan bir geçiş ve Vulkan aygıtı için özellik yapıları. Yalnızca Vulkan (Windows, Linux x86_64); diğer backend'ler ve web geçişi atlar, hiçbir şeyi etkinleştirmez. Dosya yolları `flutter_filament/` paket klasörüne görelidir.

**Bu sayfada:**

- [Geçiş nerede çalışır](#geçiş-nerede-çalışır)
- [Geçişe ne verilir](#geçişe-ne-verilir)
- [HDR aşamasındaki harici upscaler'lar](#hdr-aşamasındaki-harici-upscalerlar)
- [Vulkan aygıt özellikleri](#vulkan-aygıt-özellikleri)
- [Yerel C köprüsü](#yerel-c-köprüsü)
- [Dart API](#dart-api)
- [Sınırlar](#sınırlar)

## Geçiş nerede çalışır

Lumina'nın Filament yaması `0011` (bkz. `third_party/filament/README.md`) `View::setExternalPostPass(ExternalPostPass*)` ekler. Filament kayıtlı geçişi her karede çağırır:

1. TAA ya da FSR3 çözümlemesinden, ya da `HDR` aşamasındaki bir harici upscaler'dan (aşağıda) sonra,
2. alan derinliği, bloom ve renk düzenlemeden önce,
3. o noktanın çözünürlüğünde: TAA upscaling, FSR3 ya da bir HDR upscaler çalıştıysa çıktı çözünürlüğü, aksi halde render çözünürlüğü (FSR3 çıktısını kendi hizalamasına yuvarlar; görüntü viewport'tan birkaç texel büyük olabilir, viewport sol alt köşesidir).

Geçiş, yama `0006`'nın `externalPass` sürücü komutuyla Filament'in komut tamponu içinde, backend thread'inde çalışır; yalnızca kaydeder, asla submit etmez.

## Geçişe ne verilir

`ExternalPassContext::images` (hepsi general layout'ta):

| indeks | görüntü |
|---|---|
| `COLOR` (0) | önceden pozlanmış doğrusal HDR kare (salt okunur) |
| `DEPTH` (1) | render çözünürlüğünde renk geçişi derinliği, ters Z |
| `MOTION` (2) | rengin boyutunda RGBA16F: `rg` o boyutun texel'leriyle hareket (`uv_curr - uv_prev`, x sağa, y yukarı), `b` = önceki konum ekrandaysa 1 (geçmiş kullanılabilir), `a` = gökyüzü için 1 |
| `OUTPUT` (3) | rengin boyutunda RGBA16F storage görüntü; rengin yerini alır |

`ExternalPassContext::frame` render ve çıktı boyutlarını, TAA jitter'ını, kare kimliğini, `exposure` değerini (`1 / (1.2 · 2^ev100)`), `viewFromWorld` matrisini, jitter'sız `clipFromView` projeksiyonunu ve `FLAG_VELOCITY_BUFFER` (hareket structure pass hız tamponundan geldi) ile `FLAG_HISTORY_RESET` (ilk kare ya da sıfırlama) bayraklarını taşır.

Hareket görüntüsünü Filament'in `postPassMotion` malzemesi üretir: hız tamponunun (`TemporalAntiAliasingOptions.motionVectors`) değer yazdığı yerde değer geçişin çözünürlüğüne ölçeklenir; başka yerde (hareket vektörleri kapalı, gökyüzü) jitter'lı derinliğin tarif ettiği yüzey bu ve önceki karenin jitter'sız kameralarıyla izdüşürülür; böylece duran kamera sıfır hareket, dönen kamera hareket eden gökyüzü verir. `View::resetExternalPostPassHistory()` sonraki karede hiçbir geçmişin kullanılamadığını bildirir (kamera kesmeleri).

## HDR aşamasındaki harici upscaler'lar

`ExternalUpscaler::stage()` (varsayılan `DISPLAY`) bir harici upscaler'ın (yama `0006`) nerede çalışacağını seçer: `DISPLAY` LDR karede renk düzenlemeden sonraki özgün yerdir (DLSS Super Resolution), `HDR` doğrusal HDR karede TAA çözümlemesinin yerini alır ve çıktı çözünürlüğünde RGBA16F bir görüntü yazar; ardından bloom ve renk düzenleme ölçeksiz çalışır. Işın izlemeli aydınlatmayı da temizleyen upscaler'lar HDR aşamasına ihtiyaç duyar. Harici geçişler artık sekiz görüntüye kadar alır (`ExternalPassContext::MAX_IMAGES`): `ExternalUpscaler::guideBuffers()`'tan bir maske döndüren upscaler, istediği [kılavuz tamponlarını](guide-buffers.md) 4–7 görüntüleri olarak alır (yama `0012`).

## Vulkan aygıt özellikleri

Bir Vulkan aygıtı eklentilerini ve özellik yapılarını oluşturulurken alır; istekler bu yüzden `FilamentEngine.create`'ten önce yapılır. Yama `0011` `VulkanPlatform::Customization::extraDeviceFeatures` ekler: istenen her yapı için (sType, boyut, ait olduğu eklenti, istenen `VkBool32` üyelerin bayt konumları) Filament aygıtı sorgular, aygıtın desteklediği istenen üyeleri etkinleştirir ve yapıyı zincire ekler. Aygıtta olmayan üyeler, eklentisi etkin olmayan yapılar ve Filament'in kendisinin zincirlediği yapı türleri (multiview, protected memory, buffer device address, acceleration structure, ray query) bir log satırıyla atlanır. `VulkanPlatform::isExtraDeviceFeatureEnabled` ve `isDeviceExtensionEnabled` sonucu bildirir.

## Yerel C köprüsü

`src/vulkan_features_c.h` (`src/gpu_engine_c.cpp` içinde, istekte bulunan başına tutulur, motor oluşturulurken birleştirilir):

- `filament_vulkan_request_device_extension(requester, name)`
- `filament_vulkan_request_device_feature(requester, sType, structSize, fieldOffset, extension)`
- `filament_vulkan_clear_requests(requester)` (NULL hepsini temizler)
- `filament_vulkan_device_feature_enabled(engine, sType, fieldOffset)`, `filament_vulkan_device_extension_enabled(engine, name)`

`src/post_pass_c.h`: bir hata ayıklama geçişi, bir compute shader (`src/shaders/post_pass_debug.comp`, `dart tool/build_post_pass_shaders.dart` ile `src/post_pass_debug_spv.h`'ye derlenir, `glslc` gerekir):

- `filament_post_pass_debug_create(engine, view, mode)` → tutamaç ya da NULL (`filament_post_pass_last_error()`)
- `filament_post_pass_debug_set_mode`, `_frame_count`, `_last_size`, `_destroy`
- `filament_view_reset_external_post_pass_history(view)`

## Dart API

```dart
VulkanFeatures.requestFeature('my_library', VulkanFeature.shaderSubgroupClock); // motordan önce
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
VulkanFeatures.isFeatureEnabled(engine, VulkanFeature.shaderSubgroupClock);     // destekleyen GPU'larda true

final pass = DebugPostPass.create(engine: engine, view: view, mode: DebugPostPassMode.motion);
pass.mode = DebugPostPassMode.history;   // yeşil: geçmiş kullanılabilir, kırmızı: değil
view.resetExternalPostPassHistory();      // kamera kesmesi
pass.destroy();
```

`VulkanFeature`, Lumina'nın NVIDIA çalışmasının kullandığı yapılar için sabitler içerir (`shaderSubgroupClock`, `shaderDeviceClock`, `cooperativeMatrix`, `opticalFlow`, `shaderFloat8`); başka her üye `VulkanFeature(sType:, structSize:, fieldOffset:, extension:)` olarak yazılır. `DebugPostPassMode`: `passthrough`, `motion`, `history`, `invert`.

## Sınırlar

- Yalnızca Vulkan; `DebugPostPass.create` başka yerlerde `StateError` fırlatır, özellik istekleri hiçbir şeyi etkinleştirmez.
- View başına bir harici post pass.
- Özel vertex yer değiştirmesi hız tamponunda yoktur (TAA'daki gibi); böyle yüzeyler yalnızca kameranın hareketini alır.
