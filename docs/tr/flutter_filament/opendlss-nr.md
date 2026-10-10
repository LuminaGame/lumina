[English](../../en/flutter_filament/opendlss-nr.md)

# OpenDLSS-NR (deneysel, üçüncü taraf)

[OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR), NVIDIA'nın DLSS 5 nöral render ağının üçüncü taraf, resmî olmayan bir yeniden uygulamasıdır (bitmiş kareyi yeniden üreten üretici bir geçiş). flutter_filament bunu HDR kare üzerinde bir [harici post pass](external-post-pass.md) olarak çalıştırabilir; **yalnızca kullanıcının kendi sağladığı model ağırlıklarıyla**. Lumina ağırlıkları sağlamaz, indirmez, çıkarmaz ya da dönüştürmez ve nasıl edinileceğini anlatmaz; NVIDIA'nın model ağırlıkları yeniden dağıtılamaz ve edinilmesi ya da kullanılması NVIDIA'nın lisans koşullarını ihlal edebilir. Gereksinimleri üst projenin sayfasında anlatılır. Ne OpenDLSS-NR ne de Lumina NVIDIA ile bağlantılıdır; "DLSS" NVIDIA'nın ticari markasıdır ve yalnızca üst projenin adında geçer. Dosya yolları `flutter_filament/` paket klasörüne görelidir.

**Bu sayfada:**

- [Ne çalışır](#ne-çalışır)
- [Gereksinimler ve yetenek denetimi](#gereksinimler-ve-yetenek-denetimi)
- [Model klasörü](#model-klasörü)
- [Dart API](#dart-api)
- [Yerel C köprüsü](#yerel-c-köprüsü)
- [Ölçümler](#ölçümler)
- [Sınırlar ve riskler](#sınırlar-ve-riskler)

## Ne çalışır

Her karede, Filament'ın komut tamponunun içinde (patch `0011`'in `View::setExternalPostPass`'i), TAA / FSR3'ten sonra, alan derinliği, bloom ve renk düzeltmesinden önce:

1. `src/opendlss_nr/shaders/nr_features.comp`: dolgulu alanın her pikseli için 16 giriş: Gauss gürültüsü, HDR rengin ekran vekili (kâğıt beyazına göre, yumuşak omuz, sRGB kod değerleri), kancanın hareketiyle geri izdüşürülen önceki çıktı (beş noktalı Catmull-Rom; yalnızca geçmiş bayrağı açık ve sıfırlama yoksa) ve koşullandırma skalerleri (stil kimliği, ton, yapı, cilt, otomatik maske).
2. Vendorlanan ağ (`third_party/opendlss_nr`, üst projenin GLSL cooperative-matrix yolu: FP8 E4M3 aktivasyonlar, 71 bloklu Swin / ViT U-net), `nr::Graph` tarafından kaydedilir.
3. `src/opendlss_nr/shaders/nr_composite.comp`: vekil üzerine RGB artığı, geçmişle zamansal karışım (ağın kendi karışım logiti ve modelin öğrenilmiş üst sınırı), bir sonraki geçmiş (half'e kesilerek), isteğe bağlı stil ön ayarı ve yoğunluk, ardından parlaklığı koruyan ton yükseltmesiyle HDR kareye geri yazılır (kancanın `OUTPUT`'u). Sonlu olmayan bir sonuç kareye geri döner.

Üst projenin PTX / CUDA yolu (`VK_NV_cuda_kernel_launch`) dahil değildir: GLSL yolu aynı işlevi NVIDIA'nın CUDA uzantısı olmadan, daha yavaş hesaplar. Neyin alındığı (sabitlenmiş commit `9d08f41`, MIT) ve Lumina'nın neyi değiştirdiği `third_party/opendlss_nr/README.md`'dedir.

## Gereksinimler ve yetenek denetimi

- Masaüstü Vulkan (Windows, Linux x86_64), FP8 cooperative matrix destekli bir NVIDIA GPU (Ada veya daha yeni) ve `VK_KHR_cooperative_matrix`, `VK_NV_cooperative_matrix2`, `VK_EXT_shader_float8`, `VK_KHR_shader_float16_int8`, `VK_KHR_8bit_storage`, `VK_KHR_vulkan_memory_model`, `VK_EXT_subgroup_size_control` ve `VK_KHR_maintenance4` sunan bir sürücü.
- `FilamentEngine.create`'ten önce `OpenDlssNr.requestDeviceFeatures()` bu uzantıları ve özellik üyelerini ister ([Harici post pass ve Vulkan aygıt özellikleri](external-post-pass.md) zincirleri üzerinden).
- `OpenDlssNr.capability(engine)` `capable` ya da nedeni döndürür: `notVulkan`, `notNvidia`, `missingExtension`, `olderGpu` (FP8 tensör çekirdeği yok), `notEnabled` (motor istekten önce oluşturulmuş).
- Çekirdeklerin kullandığı iki yetenek henüz Filament'ın özellik zinciriyle istenemiyor (`shaderInt16` ve `storageBuffer16BitAccess`, Filament'ın kendi zincirlediği yapılarda), ve çekirdekler SPIR-V 1.6 iken Filament Vulkan 1.1 instance'ı oluşturuyor; NVIDIA sürücüleri yine de çalıştırır, doğrulama katmanı bunu bildirir. İkisi için bir Filament patch değişikliği planlandı.

## Model klasörü

Üst projenin düzeni: `manifest.json` (`totals.blockCount` = 71; `id`, `file`, `packedByteLength`, `sha256` içeren `stages[]`; `name`, `block`, `layer`, `parameter`, `stage`, `stageOffset`, `byteLength` içeren `tensors[]`) ve `model/<stage dosyaları>`. `OpenDlssNr.validateModel(path, verifyHashes:)` GPU'ya bir şey gitmeden önce denetler:

| sonuç | ne zaman |
|---|---|
| `missing` | klasör yok ya da `manifest.json` yok |
| `invalidManifest` | JSON değil, 16 MB'tan büyük, fazla iç içe, anahtar eksik, blok sayısı 71 değil |
| `stageMismatch` | bir stage dosyası eksik, manifestteki boyuttan farklı ya da klasörün dışına çıkan bir adı var |
| `layoutMismatch` | ağın okuduğu 153 tensörden biri eksik, küçük (düzenin sabitlediği yerde tam boyut), ya da stage'inin dışında |
| `hashMismatch` | `verifyHashes` ile, SHA-256'sı tutmayan bir stage dosyası |

`OpenDlssNr.writeSyntheticModel(path, random:)` bu düzende sıfırlarla ya da küçük rastgele değerlerle dolu bir model yazar. Eğitilmiş ağırlık içermez; testler ve süre ölçümü içindir.

## Dart API

`lib/src/opendlss_nr.dart`, `package:flutter_filament/filament.dart` ile dışa aktarılır:

```dart
OpenDlssNr.requestDeviceFeatures();            // motor oluşmadan önce
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
if (OpenDlssNr.capability(engine).supported) {
  final check = OpenDlssNr.validateModel(dir);  // bloklar: bir isolate'ten çağırın
  if (check.ok) {
    final model = OpenDlssNr.loadModel(engine, dir); // ya da isolate'te loadModelAddress
    final pass = OpenDlssNrPass.create(engine: engine, view: view, model: model,
        controls: const OpenDlssNrControls(intensity: 0.8, style: OpenDlssNrStyle.natural));
    // ... pass.status: frames, gpuMs, failed / failure
    pass.destroy();
    model.destroy();
  }
}
```

`OpenDlssNrControls`: `enabled` (false kareyi olduğu gibi geçirir), `intensity`, `localTone`, `localStructure`, `skinStructure` (-1 yapıyı izler), `autoMask`, `style` (`none`, `natural`, `cinematic`), `paperWhite`, `colorStrength`. `OpenDlssNr.loadModelAddress(engineAddress, dir)` Filament çağrısı yapmaz, arka plan isolate'i içindir; sonucu `OpenDlssNrModel.fromAddress` geri alır. Herhangi bir noktada hata alan geçiş (pipeline oluşturma, bellek, 2560 × 1600'den büyük bir kare) kendini kapatır, `status.failed` ve `status.failure` nedenini söyler ve view onsuz render etmeye devam eder.

## Yerel C köprüsü

`src/opendlss_nr_c.h` (uygulaması `src/opendlss_nr_c.cpp` ve `src/opendlss_nr/`): `filament_opendlss_nr_request_device_features`, `_capability`, `_validate_model`, `_write_synthetic_model`, `_model_load`, `_model_destroy`, `_create`, `_set_controls`, `_get_status`, `_destroy`. Mesajlar çağıranın tamponuna yazılır, böylece doğrulama birden çok iş parçacığında çalışabilir. Çekirdeklerin SPIR-V'si `dart tool/build_opendlss_nr_shaders.dart` (glslang 16.6 veya yenisi) ile `src/opendlss_nr/spirv.h`'ye üretilir; web derlemesi ve diğer platformlar "kullanılamıyor" diyen taslaklar derler.

## Ölçümler

RTX PRO 2000 Blackwell (GPU 1, 70 W) üzerinde `test/src/opendlss_nr_test.dart`, sentetik rastgele ağırlıklar, geçişin tamamı (girişler, ağ, birleştirme), 40 kare üzerinden ortalama GPU zaman damgaları:

| renk boyutu | GPU süresi | dispatch | aygıt belleği |
|---|---|---|---|
| 1024 × 768 | yaklaşık 11 ms | 311 | yaklaşık 920 MiB |
| 1920 × 1088 (1920 × 1080 bir view) | yaklaşık 27,5 ms | 302 | yaklaşık 1,36 GiB |

Ağırlıklar aritmetiğin maliyetini değiştirmez; gerçek bir model de aynı süreyi tutar. 1080p'de yalnızca bu geçiş bu GPU'da 60 fps kare bütçesini aşar.

## Sınırlar ve riskler

- Deneysel: üst projenin "bit-exact" iddiası paylaşılmamış kayıtlara dayanır ve bir üst proje raporu RTX 4080 dizüstünde yanlış renkler gösterir; çıktının doğruluğu ağırlıklar olmadan denetlenemez.
- Yalnızca Ada veya daha yeni NVIDIA GPU'larda masaüstü Vulkan; web, Android, macOS, OpenGL ve diğer üreticiler kullanılamıyor bildirir.
- 2560 × 1600'den büyük kareler reddedilir (GLSL yolu her ara sonucu bellekte tutar).
- Editör viewport'u ve PIE kendi aktivasyonlarını ayrı tutar (1080p'de yaklaşık 1 GB).
