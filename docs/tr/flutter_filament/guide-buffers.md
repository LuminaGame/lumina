[English](../../en/flutter_filament/guide-buffers.md)

# Kılavuz tamponları (guide buffers)

Nöral denoiser ve upscaler'lar (DLSS Ray Reconstruction) için piksel başına kılavuzlar: gölgelenen yüzeyin dünya normali ve pürüzlülüğü, diffuse ve specular albedosu, ve bir ayna ışınının isabete kadar kat ettiği mesafe. Filament G-buffer'sız bir forward renderer'dır; Lumina'nın Filament yaması `0012` (bkz. `third_party/filament/README.md`) bunları lit shader'lardan yazar. Yalnızca Vulkan, yalnızca tek örnekli view'lar. Dosya yolları `flutter_filament/` paket klasörüne görelidir.

**Bu sayfada:**

- [Ne yazılır](#ne-yazılır)
- [Nasıl üretilir](#nasıl-üretilir)
- [Yerel C köprüsü (`src/guide_buffers_c.h`)](#yerel-c-köprüsü-srcguide_buffers_ch)
- [Dart API (`lib/src/guide_buffers.dart`)](#dart-api-libsrcguide_buffersdart)
- [Maliyet](#maliyet)
- [Sınırlar](#sınırlar)

## Ne yazılır

| `GuideBuffer` | biçim | içerik |
|---|---|---|
| `normalRoughness` | RGBA16F | dünya uzayı normali (xyz), algısal pürüzlülük (w) |
| `diffuseAlbedo` | RGBA8 | `baseColor · (1 − metallic)`, doğrusal |
| `specularAlbedo` | RGBA8 | pikselin bakış açısı için split-sum specular albedo `mix(dfg.x, dfg.y, F0)`, doğrusal |
| `specularHitDistance` | R16F | ayna yansıma ışınının isabete mesafesi (dünya birimi, metre); yüzey yoksa 0, ışın sahneden çıkarsa 65504 |

Hepsi render çözünürlüğündedir (renk geçişi boyutu). Unlit yüzeylerin (skybox) ve boş piksellerin kılavuzları sıfırdır.

## Nasıl üretilir

- `View::setGuideBufferOptions({ .enabled = true, .specularHitDistance = true })`.
- Bir temizleme geçişi üç renk kılavuzunu sıfırla oluşturur; renk geçişi onları renk eki 1–3 olarak bağlar. Lit fragment shader'lar (`surface_main.fs`, yalnızca `TARGET_VULKAN_ENVIRONMENT` için derlenir) malzemeyi değerlendirdikten sonra yazar. Specular-glossiness ve cloth malzemeler girdilerini aynı büyüklüklere eşler.
- Harmanlanan yüzeyler sıfır yazar (multiply harmanlananlar bir); böylece altlarındaki opak yüzeyin kılavuzları korunur.
- Sahnede ışın izleme açıkken (`Scene::setRayTracingEnabled`), yerleşik `rtSpecularHitDistance` ray query malzemesi derinlik ve normal kılavuzundan piksel başına bir ayna ışını izler.
- Frame graph, kimsenin okumadığı kılavuzları ayıklar: onları isteyen bir harici upscaler (`ExternalUpscaler::guideBuffers()`, harici geçişin 4–7 görüntüleri) ya da bir kullanıcı dokusuna kopya (`View::setGuideBufferTexture`) onları tutar.
- Yama `0012`'den önce derlenen malzemeler kılavuz yazmaz; onları yeniden derleyin (`flutter_filament` ve `lumina` içinde `tool/build_materials.sh`). glTF ubershader'ları ve çalışma zamanında derlenen malzemeler aynı Filament derlemesinden gelir ve yazar.

## Yerel C köprüsü (`src/guide_buffers_c.h`)

- `filament_view_set_guide_buffer_options(view, const filament_guide_buffer_options_t*)` / `filament_view_get_guide_buffer_options(view, out)`, `{ bool enabled; bool specularHitDistance; }` ile.
- `filament_view_set_guide_buffer_texture(view, which, texture)`: `which` kılavuzunu (`filament_guide_buffer`) her karede render çözünürlüğünde, kılavuzun biçiminde ve `BLIT_DST` kullanımlı bir dokuya kopyalar; NULL durdurur.

Web'de seçenekler gidiş-dönüş için saklanır, hiçbir şey çizilmez.

## Dart API (`lib/src/guide_buffers.dart`)

```dart
view.guideBufferOptions = const GuideBufferOptions(enabled: true);
scene.rayTracingEnabled = true; // specular isabet mesafesi için
final normals = GuideBufferReadback.attach(
    engine: engine, view: view, which: GuideBuffer.normalRoughness, width: w, height: h);
// bir kare çiz...
final data = await normals.read(renderer);           // w * h * 4 float, satırlar yukarıdan aşağı
final v = normals.at(data, x, y);                   // [nx, ny, nz, roughness]
normals.dispose();
```

- `GuideBuffer` (`format` ile), `GuideBufferOptions` (`enabled`, `specularHitDistance`), `FilamentView.guideBufferOptions` getter/setter ve `setGuideBufferTexture(GuideBuffer, FilamentTexture?)` (`GuideBuffers` uzantısı).
- `GuideBufferReadback`: bir kılavuzun dokusu, render target'ı ve geri okuması; testler ve hata ayıklama görünümleri için (`channels` 4, isabet mesafesinde 1; RGBA8 kılavuzlar 0..1'e normalize edilir).

## Maliyet

RTX PRO 2000'de 1920×1080'de ölçüldü (dört prop, tüm kılavuzlar dışa aktarılır, kareler çizilip beklenir): kılavuzsuz kareye göre 0,06 ms içinde, bu ölçümün koşudan koşuya gürültüsünün altında. Renk geçişi üç ek daha yazar (piksel başına 16 bayt); isabet mesafesi yüzey pikseli başına bir ışın izler.

## Sınırlar

- Yalnızca Vulkan; MSAA view'lar kılavuzsuz çizer.
- Özel vertex yer değiştirmesi, parçacıklar ve harmanlanan malzemelerin kendi kılavuzları yoktur.
- Specular isabet mesafesi ayna yönünü izler; pürüzlü yüzeyler örneklenmiş bir lob yönü ister.
