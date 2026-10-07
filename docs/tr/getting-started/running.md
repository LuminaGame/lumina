[English](../../en/getting-started/running.md)

# Editörü ve testleri çalıştırmak

Lumina Studio'nun nasıl başlatılacağı, bir paketin unit testlerinin nasıl çalıştırılacağı, GPU smoke raporunun nasıl üretileceği ve melos workspace script'lerinin nasıl kullanılacağı.

## Lumina Studio'yu başlatmak

Editör, `lumina_ui` Flutter uygulamasıdır. Repository kökünden:

```bash
cd lumina_ui
flutter run -d linux        # ya da: -d windows, -d macos
```

İlk çalıştırma native wrapper'ları native-assets hook'larıyla derlediği için biraz zaman alır. Standart editör proje launcher'ıyla açılır; code plugin kullanan projeler kendi editor host binary'lerini alır.

Birden fazla GPU olan bir makinede `FILAMENT_GPU`, Vulkan device'ını bir isim parçasıyla ya da index'le seçer (örneğin `FILAMENT_GPU=RTX` ya da `FILAMENT_GPU=1`); `FILAMENT_GPU` ayarlı değilse `VK_DEVICE_INDEX` dikkate alınır.

## Testleri çalıştırmak

Her paket testlerini `test/` altında tutar. Değiştirdiğiniz kodu kapsayan dosyaları paket dizininden çalıştırın:

```bash
cd flutter_filament
flutter test test/src/engine_test.dart
```

- `flutter_filament` unit testleri Filament'in noop backend'inde çalışır ve GPU gerektirmez.
- Testler gerçek dosyalar ve gerçek native kütüphaneler kullanır. `test-assets/` içindeki modellere ihtiyaç duyan testler, dosyalar yoksa atlanır; `LUMINA_TEST_ASSETS` onları başka bir klasöre yönlendirir.
- `lumina_ui`'ın ayrıca `integration_test/` altında integration akışları vardır (`flutter test integration_test/<dosya>`).
- `lumina_core` saf Dart'tır: testleri `flutter test` ile değil, `dart test` ile çalışır (örneğin `dart test test/architecture/pure_dart_test.dart`).

## Smoke testler ve HTML raporu

Smoke testler gerçek GPU'da render eder ve kanıt olarak PNG ekran görüntüleri ve videolar yayınlar. Smoke test sistemi tools repository'sindeki [`lumina_smoke`](https://github.com/LuminaGame/tools/blob/main/docs/tr/lumina_smoke.md) paketidir:

- `package:lumina_smoke/lumina_smoke.dart`: `SmokeArtifacts` (sidecar JSON'lu PNG ve VP8/WebM artifact'ler), `SmokeVideo` (smoke video kuralları ve probe), `SmokeVideoRecorder`, `SmokeWebm` ve diğer encoder'lar ile araçlar;
- `package:lumina_smoke/flutter.dart`: çalışan bir uygulamayı kaydeden `SmokeRecorder` ve widget ile integration test PNG'lerini yakalayan `SmokeCapture`;
- `package:lumina_smoke/report.dart`: rapor çalıştırıcısı (`smokeReportMain`, `SmokeReportConfig`, generator ve canlı dashboard).

Her paket bunu testleri için yeniden export eder (`package:flutter_filament/testing.dart`, `package:lumina/testing.dart`, `package:lumina_ui/testing.dart`; lumina ve lumina_ui bunun üzerine kendi `SmokeArtifacts` sınıflarını ekler). `flutter_filament`, `lumina` ve `lumina_ui` paketlerinin her biri ince bir `tool/smoke_report.dart` tutar: kendi `SmokeReportConfig`'i (başlık, test kategorileri) ve `smokeReportMain`'i çağıran bir `main`. Bu script testleri yapılandırılmış GPU'da çalıştırır ve `build/smoke_artifacts/` içindeki dosyalara link veren `build/smoke_report.html`'i (ve `build/smoke_report/` altında kategori başına bir sayfa) yazar (birlikte paylaşın):

```bash
dart run tool/smoke_report.dart                                  # temiz bir build/ ile tüm smoke suite
dart run tool/smoke_report.dart test/smoke/<dosya>_test.dart    # tek dosya, mevcut rapora eklenir
dart run tool/smoke_report.dart <dosya> --plain-name <senaryo>  # tek senaryo
dart run tool/smoke_report.dart <hedef> --fresh                 # temiz başlayan hedefli çalıştırma
dart run tool/smoke_report.dart --all                           # unit, smoke ve integration testleri
dart run tool/smoke_report.dart --report-only                   # events dosyasından yeniden render
```

Artifact'ler testleriyle değiştirilme zamanına göre değil, her zaman bir sidecar JSON dosyasındaki bildirilen test adıyla eşleştirilir. Her smoke video en az 10 s uzunluğunda, en az 1024x768 boyutunda ve en az 30 fps gerçek frame içermeli, hiçbir frame 2 s'den uzun ekranda kalmamalıdır; bir kuralı çiğneyen video kaydedilirken reddedilir. `LUMINA_SMOKE_OUT` artifact dizinini, `LUMINA_SMOKE_REPORT_OUT` ise rapor sayfasını başka bir yere yönlendirir.

## Workspace script'leri

Repository kökünden (global melos olmadan `dart run melos run <script>` de çalışır):

```bash
melos run analyze        # her pakette flutter analyze
melos run format         # dart format
melos run format:check   # format'lanmamış kaynaklarda hata ver
melos run test           # test/ klasörü olan her pakette flutter test, paketler tek tek
melos run smoke          # tüm smoke suite'ler, her paketin build/smoke_report.html dosyasına eklenir
```

`tool/ci.sh` (bir POSIX shell script'i; Windows'ta Git Bash) derlenmiş materyalleri yeniden üretir, ardından dört paketin unit suite'lerini ve smoke raporlarını çalıştırır:

```bash
tool/ci.sh               # her paket için unit + smoke
tool/ci.sh --unit        # yalnızca unit suite'ler (GPU gerekmez)
tool/ci.sh --smoke       # yalnızca smoke raporları
tool/ci.sh lumina        # tek paket: flutter_filament | lumina | lumina_editor_api | lumina_ui
```

## Filament binding'lerini yeniden üretmek

`flutter_filament/src/` içinde bir C header'ını düzenledikten sonra hem native hem de web binding'lerini bu sırayla yeniden üretin:

```bash
cd flutter_filament
dart run tool/ffigen.dart
dart run tool/ffigen_web.dart
```

Web binding'leri yeniden üretilmediğinde `test/web/bindings_lockstep_test.dart` başarısız olur. Export edilen her `filament_*` fonksiyonu, `src/filament_c.h`'tan include edilen bir header'da tanımlanmalı ve `FFI_PLUGIN_EXPORT` makrosunu taşımalıdır; aksi halde üretilen binding'lerde ya da Windows'ta DLL export'larında yer almaz.

---

[Önceki: Checkout ve kurulum](setup.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: flutter_filament](../flutter_filament/index.md)
