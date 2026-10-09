[English](../../en/flutter_filament/restir.md)

# ReSTIR doğrudan aydınlatma

Çok sayıda noktasal ışıktan rezervuar yeniden örneklemesiyle doğrudan aydınlatma: her piksel küçük bir aday ışık rezervuarı tutar, önceki karenin ve komşularının rezervuarlarını yeniden kullanır, hayatta kalan ışığa tek bir görünürlük ışını izler ve yalnızca o ışığı gölgeler. Maliyet ışık sayısından neredeyse bağımsızdır ve her ışık sert, ışın izlemeli bir gölge düşürür. Yalnızca ray query destekli Vulkan'da (bkz. [Işın izleme](ray-tracing.md)); diğer her yerde froxel ışık döngüsü eskisi gibi çizer. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Filament'e nasıl oturur](#filamente-nasıl-oturur)
- [Froxel'lere göre ne değişir](#froxellere-göre-ne-değişir)
- [İşlem sırası](#i̇şlem-sırası)
- [Yerel C köprüsü (`src/restir_c.h`)](#yerel-c-köprüsü-srcrestir_ch)
- [Dart API (`lib/src/restir.dart`)](#dart-api-libsrcrestirdart)
- [İstatistikler](#i̇statistikler)
- [Sınırlar](#sınırlar)
- [Lisans notu](#lisans-notu)

## Filament'e nasıl oturur

Lumina'nın Filament yaması `0008` (bkz. `third_party/filament/README.md`) view'a `RestirOptions` ekler. Ray query'li bir motorda etkinleştirildiğinde ve sahne hızlandırma yapılarını tutuyorsa renderer her karede sahnenin tüm nokta ve spot ışıklarından bir ışık tamponu kurar (RGBA32F bir doku, ışık başına dört texel, 256 ışık sınırı yok) ve yapı derinliği üzerinde üç ray query post-process geçişi çalıştırır:

1. **Adaylar ve zamansal yeniden kullanım**: `initialCandidates` kadar ışık tekdüze çekilir, difüz bir yüzeye gölgesiz katkılarıyla ağırlıklandırılır (yeniden örneklemeli önem örneklemesi) ve yüzey aynıysa yeniden yansıtılan konumdaki önceki kare rezervuarıyla birleştirilir (`temporal`, geçmiş ağırlığı `maxHistory` ile sınırlı).
2. **Uzamsal yeniden kullanım**: `spatialRadiusPx` içindeki `spatialSamples` komşu rezervuar, ışıkları bu pikselde yeniden değerlendirilerek birleştirilir.
3. **Görünürlük**: yüzeyden seçilen ışığa tek bir ışın (`visibilityRays`).

Sonuç, (ışık indeksi, yeniden örnekleme ağırlığı W, görünürlük), renk geçişine bağlanır; lit malzeme shader'ları froxel'in ışıklarını döngüyle gezmek yerine o tek ışığın verisini okur ve tam BRDF'leriyle gölgeler. Yeniden kullanımdan sonraki rezervuarlar bir sonraki karenin geçmişi olur.

## Froxel'lere göre ne değişir

| | Froxel ışık döngüsü | ReSTIR doğrudan aydınlatma |
| :--- | :--- | :--- |
| Piksel başına ışık | froxel ile kesişen her ışık, Filament'in 256 ışık sınırına dek | istenen sayıda ışıktan yeniden örneklenmiş tek ışık |
| Maliyet | ışık sayısı ve örtüşmeyle büyür | piksel başına neredeyse sabit |
| Gölgeler | gölge haritası olan birkaç ışık için | her ışık için sert, ışın izlemeli gölge |
| Gürültü | yok | birkaç kare geçmişten sonra düşük; kamera kesmelerinde sıfırlanır |
| Saydam yüzeyler | gölgelenir | froxel döngüsünde kalır (arkalarında rezervuar yok) |
| Yönlü ışık, IBL | Filament'in yolları | değişmez |

## İşlem sırası

1. `FilamentEngine.create`'ten **önce** `RayTracing.requestExtensions()` (DLSS de her iki sırayla istenebilir).
2. Motoru Vulkan arka ucunda oluşturun; aygıt ışın izliyor ve ray query malzemeleri yüklüyse `view.restirSupported` true olur.
3. `scene.rayTracingEnabled = true`: görünürlük ışınları hızlandırma yapılarına ihtiyaç duyar.
4. `view.restirOptions = const RestirOptions(enabled: true)`; kalite/maliyet için sayıları ayarlayın.
5. Işık sayısı, kare başına ışın ve GPU süresi için `view.restirStats` okuyun; kamera kesmesinde `view.resetRestirHistory()` çağırın.
6. `lightManager.setRestirSamplingWeight(light, 0)` bir ışığı ReSTIR gölgelemesinden çıkarır; 1'den büyük değerler onu kayırır.

## Yerel C köprüsü (`src/restir_c.h`)

| C Fonksiyonu | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `filament_view_set_restir_options` | `void filament_view_set_restir_options(void* view, const filament_restir_options* options);` | View'ın ReSTIR seçeneklerini ayarlar. |
| `filament_view_get_restir_options` | `void filament_view_get_restir_options(void* view, filament_restir_options* out_options);` | Geri okur. |
| `filament_view_restir_supported` | `bool filament_view_restir_supported(void* view);` | Ray query var ve ReSTIR malzemeleri yüklü. |
| `filament_view_get_restir_stats` | `void filament_view_get_restir_stats(void* view, filament_restir_stats_t* out_stats);` | Son ReSTIR karesinin ışık sayısı, kare başına ışın ve GPU nanosaniyesi. |
| `filament_view_restir_reset_history` | `void filament_view_restir_reset_history(void* view);` | Zamansal geçmişi bırakır. |
| `filament_light_set_restir_sampling_weight` | `void filament_light_set_restir_sampling_weight(void* engine, uint32_t entity, float weight);` | Işık başına örnekleme ağırlığı (0 ışığı çıkarır, varsayılan 1). |

`filament_restir_options`, `filament::RestirOptions`'ı yansıtır (`filament_options_sizeof(14)`): `enabled`, `initialCandidates`, `spatialSamples`, `spatialRadiusPx`, `temporal`, `maxHistory`, `visibilityRays`, `shadeEmissive`.

## Dart API (`lib/src/restir.dart`)

#### `class RestirOptions`

| Özellik | Tür | Açıklama |
| :--- | :--- | :--- |
| `enabled` | `bool` | Noktasal ışıklar için ReSTIR kullan. Varsayılan false. |
| `initialCandidates` | `int` | Yeniden kullanımdan önce piksel ve kare başına örneklenen ışık. Varsayılan 8. |
| `spatialSamples` | `int` | Piksel başına birleştirilen komşu rezervuar; 0 uzamsal yeniden kullanımı kapatır. Varsayılan 2. |
| `spatialRadiusPx` | `double` | Komşuluk yarıçapı, piksel. Varsayılan 32. |
| `temporal` | `bool` | Önceki karenin rezervuarını yeniden kullan. Varsayılan true. |
| `maxHistory` | `int` | Bir rezervuarın tartabileceği geçmiş kare sayısı. Varsayılan 20. |
| `visibilityRays` | `bool` | Seçilen ışığa görünürlük ışını izle. Varsayılan true. |
| `shadeEmissive` | `bool` | Ayrılmış; emissive üçgenler ışık olarak uygulanmadı. |

#### `class RestirStats`

| Özellik | Tür | Açıklama |
| :--- | :--- | :--- |
| `lightCount` | `int` | Işık tamponundaki noktasal ışıklar. |
| `emissiveTriangleCount` | `int` | Her zaman 0. |
| `raysPerFrame` | `int` | Son karede izlenen görünürlük ışınları (piksel sayısı ya da ışınsız 0). |
| `gpuTime` | `Duration` | ReSTIR geçişlerinin son ölçülen GPU süresi. |

#### Başka yerlerdeki eklemeler

| Üye | Nerede | Açıklama |
| :--- | :--- | :--- |
| `restirOptions` (get/set), `restirSupported`, `restirStats`, `resetRestirHistory()` | `FilamentView` | View tarafı denetimler. |
| `setRestirSamplingWeight(entity, weight)` | `FilamentLightManager` | Işık başına örnekleme ağırlığı. |

```dart
RayTracing.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
// ... yüzlerce nokta ışıklı sahne, view, kamera
scene.rayTracingEnabled = true;
if (view.restirSupported) {
  view.restirOptions = const RestirOptions(enabled: true, initialCandidates: 8, spatialSamples: 2);
}
// birkaç kare sonra:
print(view.restirStats); // RestirStats(lights: 512, rays: 786432, gpu: 0:00:00.001900)
```

## İstatistikler

`lightCount`, ışık tamponunun tuttuğu noktasal ışık sayısıdır (yalnızca froxel'de görünenler değil, tüm sahne). `raysPerFrame`, `visibilityRays` açıkken çizim çözünürlüğündeki piksel sayısıdır. `gpuTime` üç geçişin çevresindeki bir zamanlayıcı sorgusundan gelir ve ölçtüğü kareden bir iki kare geride kalır.

## Sınırlar

- Yalnızca `VK_KHR_ray_query`'li Vulkan; başka yerlerde `restirSupported` false'tur ve `enabled` saklanır ama yok sayılır. ReSTIR ışık değerlendirmesini yalnızca Vulkan için derlenen shader'lar içerir ve iki texture'ını yalnızca onlar örnekler.
- Sahnede `rayTracingEnabled` açık olmalıdır; hızlandırma yapıları yoksa froxel yolu çizer.
- Yeniden örnekleme, derinlikten türetilen normale sahip difüz bir yüzeyi hedefler; parlak yansımalar daha yavaş yakınsar ve uzamsal yeniden kullanım derinlik kenarlarında temel, hafif yanlı birleştirmedir.
- Piksel ve kare başına tek ışık gölgelenir: kamera kesmesi ya da geçmiş sıfırlamasından sonra birkaç kare gürültü görünür; tek gürültü giderici zamansal birikimdir.
- Saydam yüzeyler froxel ışık döngüsünde kalır; yönlü ışık gölge haritalarını ya da [Işın izleme](ray-tracing.md) sayfasındaki ışın izlemeli gölgeyi korur.
- Noktasal ışıkların gölge haritaları ve temas gölgeleri ReSTIR altında uygulanmaz (görünürlük ışını onların yerini alır).
- Emissive üçgenler ışık olarak (`shadeEmissive`) uygulanmadı.

## Lisans notu

Bu, Lumina'nın kendi GLSL ReSTIR doğrudan aydınlatma uygulamasıdır (zamansal ve uzamsal yeniden kullanımlı yeniden örneklemeli önem örneklemesi, Bitterli ve ark., 2020'yi izler), Filament post-process malzemeleri olarak yazılmıştır. Güncel lisansı Lumina'nın GPL derlemesiyle uyumsuz olan NVIDIA RTXDI SDK'sından kod içermez; HLSL derleyicisi ya da compute shader gerektirmez.
