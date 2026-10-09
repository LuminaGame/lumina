[English](../../en/flutter_filament/index.md)

# flutter_filament

`flutter_filament`, fiziksel tabanlı (PBR) Google Filament renderer'ının Dart FFI binding'idir. Lumina'nın en alttaki Dart katmanıdır: engine'in ve editörün çizdiği her piksel bu paketten geçer.

## Mimarideki yeri

`flutter_filament`, doğrudan Filament'in C++ kütüphanelerinin üzerinde ve Lumina'daki diğer her şeyin altında durur: `lumina` render işlemini bunun üzerinden yapar, `lumina_ui` da viewport'ları için onu doğrudan kullanır. Bkz. [Katmanlı mimari](../overview/layers.md).

## Paket nasıl build edilir

- **C wrapper**: `src/*_c.h` / `src/*_c.cpp`, Filament'i `filament_*` önekli düz C fonksiyonları olarak sunar; `src/filament_c.h` şemsiye header'dır. Export edilen her bildirim `FFI_PLUGIN_EXPORT` taşır.
- **Native-assets hook**: `hook/build.dart`, wrapper'ı ilk `flutter test` ya da `flutter run` sırasında derler ve `filament/out/cmake-release/` (ya da `cmake-release-windows/`) içindeki yaklaşık 44 Filament static kütüphanesine link eder. Include path'lerinin, flag'lerin (C++20; Linux'ta `third_party/libcxx/` içindeki gömülü libc++) ve link edilen kütüphanelerin esas listesidir.
- **Üretilen binding'ler**: `tool/ffigen.dart`, `lib/src/third_party/filament_c.g.dart`'ı yazar; `tool/ffigen_web.dart` web sürümlerini (`filament_c.web.g.dart`, `math_types.web.g.dart`) yazar.
- **Dart wrapper'ları**: `lib/src/*.dart`, C fonksiyonlarını `FilamentEngine`, `FilamentScene`, `FilamentView` ve `FilamentAssetLoader` gibi sınıflarla sarar. `dart:ffi` yerine paketin platform shim'lerini (`src/ffi_platform.dart`, `src/ffi_package_platform.dart`, `src/filament_bindings.dart`) import ederler; böylece aynı kod hem native hem de web'de çalışır.
- **Web**: `tool/web/`, aynı C wrapper'ından ve WebGL2'li bir Filament build'inden tek bir WebAssembly modülü (`web/flutter_filament.{js,wasm}`) üretir; `lib/src/web_ffi/`, modülün heap'i üzerinde `dart:ffi` uyumlu bir katman sağlar. Web uygulamaları engine'i kullanmadan önce `await FilamentWeb.ensureInitialized()` çağırır. Yalnızca masaüstünde olan kütüphaneler (filamat, tam imageio, matdbg, gltfio JIT) web'de stub'lanır; böylece her `filament_*` sembolü export edilmeye devam eder.

## Kütüphaneler

- `package:flutter_filament/filament.dart`: görüntü widget'ı olmadan Dart API'si; hiçbir Flutter kütüphanesi import etmez. Motor (`lumina`) bunu import eder.
- `package:flutter_filament/flutter_filament.dart`: aynısı ve bir Flutter uygulamasında bir view'ı barındıran `FilamentWidget` (`lumina_widgets`, `lumina_ui`).
- `package:flutter_filament/ffi.dart` / `ffi_package.dart`: buffer geçiren kod için pointer türleri.

## Native fonksiyon eklemek

1. Başarısız olan Dart testini yazın.
2. `filament_*` fonksiyonunu `src/<alan>_c.h` içinde (`src/filament_c.h`'tan include edilen) bildirin ve `src/<alan>_c.cpp` içinde gerçekleyin.
3. `dart run tool/ffigen.dart`, ardından `dart run tool/ffigen_web.dart` çalıştırın.
4. Dart wrapper'ını `lib/src/` içinde, `dart:ffi` yerine `ffi_platform.dart` import ederek yazın.

## Referans sayfaları

Her sayfa bir subsystem'i kapsar: önce `src/*_c.h` header'larındaki C fonksiyonları, ardından `lib/src/` dosyalarındaki Dart sınıfları.

| Sayfa | Kapsam |
|---|---|
| [Engine, entity'ler ve temel tipler](engine.md) | Engine yaşam döngüsü, entity'ler, ortak enum'lar, fence'ler, exception'lar, callback'ler, tanılama. |
| [Renderer, view'ler ve frame pacing](renderer-and-view.md) | Renderer, swap chain'ler, view'ler, render target'lar, frame pacing, Flutter widget'ı. |
| [View seçenekleri ve color grading](view-options.md) | View başına post-processing ve kalite seçenekleri, tone mapping ve color grading. |
| [DLSS Super Resolution](dlss.md) | Dinamik çözünürlüğün arkasında NVIDIA DLSS: indirilen SDK, motor öncesi uzantı isteği, kalite modları, Ray Reconstruction (gürültü temizleyen upscaler), Frame Generation ve Multi Frame Generation, sınırlar. |
| [Işın izleme](ray-tracing.md) | Vulkan ray query: uzantı isteği, sahne başına hızlandırma yapıları, ışın izlemeli güneş gölgeleri, görünürlük ışınları, sınırlar. |
| [ReSTIR doğrudan aydınlatma](restir.md) | Işın izlemeli görünürlükle rezervuar yeniden örneklemesinden çok sayıda noktasal ışık: seçenekler, istatistikler, froxel'lere göre değişenler, sınırlar. |
| [Kılavuz tamponları](guide-buffers.md) | Lit shader'lardan normal + pürüzlülük, diffuse ve specular albedo ile ışın izlemeli specular isabet mesafesi; nöral denoiser ve upscaler'lar için; testler ve hata ayıklama görünümleri için geri okuma. |
| [Harici post pass ve Vulkan aygıt özellikleri](external-post-pass.md) | Renk düzenlemeden önce HDR karedeki geçişler için kanca (renk, derinlik, geçmiş geçerliliğiyle hareket), HDR aşamasındaki harici upscaler'lar, Vulkan aygıtı için istenen özellik yapıları, hata ayıklama geçişi. |
| [Sahne ve geometri](scene-and-geometry.md) | Sahneler, renderable'lar, transform'lar, vertex/index/instance/morph/skinning buffer'ları, filamesh. |
| [Kamera ve manipulator](camera-and-manipulator.md) | Kameralar, projeksiyonlar, exposure ve orbit/map/free-flight kamera manipulator'ı. |
| [Işıklandırma ve image-based lighting](lighting-and-ibl.md) | Işıklar, gölgeler, indirect light, skybox'lar, IBL bake ve prefilter. |
| [Materyaller](materials.md) | Materyaller, material instance'lar, parametreler ve runtime materyal derleyicisi. |
| [Texture'lar ve görseller](textures-and-images.md) | Texture'lar, sampler'lar, görsel I/O, görsel işlemleri, KTX1/KTX2, Basis transcoding. |
| [glTF yükleme ve animasyon](gltfio.md) | glTF/GLB asset'leri, instance'lar, material provider'lar, animator'lar, Draco decode. |
| [Matematik tipleri](math.md) | Vektör, quaternion ve matris değer tipleri, box'lar, frustum'lar, renkler, exposure. |
| [Editör primitifleri, araçlar ve test](editor-tools-and-testing.md) | Grid, seçim kutusu, transform gizmo, offline araçlar, smoke test giriş noktası. |
| [Platform entegrasyonu ve GPU seçimi](platform.md) | Paylaşılan engine host, Vulkan GPU listeleme ve tercihi, web başlatma ve platforma özel widget varyantları. |

---

[Önceki: Editörü ve testleri çalıştırmak](../getting-started/running.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Engine, entity'ler ve temel tipler](engine.md)
