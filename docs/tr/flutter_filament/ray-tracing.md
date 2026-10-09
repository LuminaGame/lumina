[English](../../en/flutter_filament/ray-tracing.md)

# Işın izleme

Vulkan arka ucunda `VK_KHR_ray_query` ile donanımsal ışın izleme: her sahne renderable'ları üzerinde hızlandırma yapıları tutabilir, yönlü ışık kademeli gölge haritaları yerine sert gölgeler izleyebilir ve bir view tekil görünürlük ışınlarını yanıtlar. Diğer arka uçlarda, uzantıları olmayan GPU'larda ve web'de her şey sessizce düşer: destek false okunur, sahne bayrağı hiçbir şey kurmaz, ışın izlemeli gölgeler gölge haritalarına döner ve ışınlar isabet bildirmez. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Filament'e nasıl oturur](#filamente-nasıl-oturur)
- [İşlem sırası](#i̇şlem-sırası)
- [Yerel C köprüsü (`src/ray_tracing_c.h`)](#yerel-c-köprüsü-srcray_tracing_ch)
- [Dart API (`lib/src/ray_tracing.dart` ve diğerleri)](#dart-api-libsrcray_tracingdart-ve-diğerleri)
- [Işın izlemeli güneş gölgeleri](#işın-izlemeli-güneş-gölgeleri)
- [Ray query malzemeleri](#ray-query-malzemeleri)
- [Sınırlar](#sınırlar)

## Filament'e nasıl oturur

Lumina'nın Filament yaması `0007` (bkz. `third_party/filament/README.md`) Vulkan arka ucuna hızlandırma yapılarını öğretir: her ayrı primitive geometrisi (vertex buffer, index buffer, offset ve count) için bir alt düzey yapı (BLAS) ve sahne başına, ışın izlemede görünür her renderable'ın dünya dönüşümleri üzerinde bir üst düzey yapı (TLAS). `Scene::setRayTracingEnabled`, renderer'ın sahnenin çizildiği her karenin başında, herhangi bir geçişten önce TLAS'ı yeniden kurmasını sağlar; BLAS'lar bir kez kurulur ve 120 kullanılmayan kareden sonra bırakılır. TLAS, *ray query malzemelerinin* (GLSL 460 ve `GL_EXT_ray_query` ile derlenen post-process malzemeler) view başına descriptor set'ine (binding 13) bağlanır; güneş ışın izlemeli gölge kullandığında lit malzemelerin renk geçişi bir ışın izlemeli gölge maskesi (binding 12) okur. Her TLAS kurulumunun GPU süresi bir zamanlayıcı sorgusuyla ölçülür.

Aygıt uzantılara sahipken vertex ve index buffer'lar hızlandırma yapısı kurulumlarının gerektirdiği kullanımlarla oluşturulur; ışın izleme açıldığında hiçbir buffer yeniden oluşturulmaz.

## İşlem sırası

1. `FilamentEngine.create`'ten **önce** `RayTracing.requestExtensions()`: `VK_KHR_acceleration_structure`, `VK_KHR_ray_query`, `VK_KHR_deferred_host_operations` ve `VK_KHR_buffer_device_address` var olan bir aygıta eklenemez. İstek DLSS isteğinin yanında saklanır; `Dlss.requestExtensions()` öncesinde ya da sonrasında gelebilir. `RayTracing.clearExtensionRequest()` sonraki motorlar için geri alır.
2. Motoru Vulkan arka ucunda oluşturun. GPU ve sürücü uzantıları sağlıyorsa `engine.supportsRayQuery` true olur; istek olmadan oluşturulan bir motorda false kalır.
3. `scene.rayTracingEnabled = true`. Bir sonraki çizilen kareden itibaren `scene.tlasInstanceCount` TLAS'taki renderable'ları sayar, `scene.lastTlasBuildTime` zamanlayıcısı çözüldüğünde (birkaç kare sonra) son kurulumu bildirir.
4. `FilamentRenderableManager.setRayTracingVisible(entity, false)` bir renderable'ı çizilmeye devam ederken yapılardan çıkarır (her renderable için varsayılan true).
5. Yönlü ışıkta `ShadowOptions(rayTraced: true)` gölgelerini ışın izlemeye çevirir; `view.traceRay(...)` ve test kancası `scene.traceVisibility(...)` görünürlük ışınlarını yanıtlar.

## Yerel C köprüsü (`src/ray_tracing_c.h`)

| C Fonksiyonu | İmza | Amaç ve Açıklama |
| :--- | :--- | :--- |
| `filament_ray_tracing_request_extensions` | `bool filament_ray_tracing_request_extensions(void);` | Bundan sonra oluşturulan motorlardan ray query aygıt uzantılarını ister; masaüstü Vulkan arka ucu yoksa false. |
| `filament_ray_tracing_clear_extension_request` | `void filament_ray_tracing_clear_extension_request(void);` | Sonraki motorlar için isteği unutur. |
| `filament_engine_supports_ray_query` | `bool filament_engine_supports_ray_query(void* engine);` | Aygıt hızlandırma yapıları kurar ve shader'lardan ışın izler. |
| `filament_scene_set_ray_tracing_enabled` | `void filament_scene_set_ray_tracing_enabled(void* scene, bool enabled);` | Sahnenin her karede yeniden kurulan hızlandırma yapılarını tutar. |
| `filament_scene_get_ray_tracing_enabled` | `bool filament_scene_get_ray_tracing_enabled(void* scene);` | Ayarlanan bayrak. |
| `filament_scene_get_tlas_instance_count` | `uint32_t filament_scene_get_tlas_instance_count(void* scene);` | Son kareden sonra TLAS'taki renderable sayısı. |
| `filament_scene_get_tlas_build_nanos` | `uint64_t filament_scene_get_tlas_build_nanos(void* scene);` | Son TLAS kurulumunun GPU süresi, nanosaniye. |
| `filament_renderable_set_ray_tracing_visible` | `void filament_renderable_set_ray_tracing_visible(void* engine, uint32_t entity, bool visible);` | Bir renderable'ın geometrisini dahil eder ya da çıkarır. |
| `filament_renderable_is_ray_tracing_visible` | `bool filament_renderable_is_ray_tracing_visible(void* engine, uint32_t entity);` | Ayarlanan bayrak (varsayılan true). |
| `filament_scene_trace_visibility` | `bool filament_scene_trace_visibility(void* engine, void* scene, const float* origin3, const float* direction3, float max_distance, float* out_distance, uint32_t* out_entity, uint32_t* out_primitive);` | Test kancası: sahne üzerinde geçici 1x1 bir view çizer ve ışının yanıtını bekler; isabette true. |
| `filament_view_trace_ray` | `void filament_view_trace_ray(void* view, const float* origin3, const float* direction3, float max_distance, FilamentRayHitCallback callback, void* user_data);` | View'ın bir sonraki karesinde yanıtlanan bir ışın kuyruğa alır; geri çağrı isabet, mesafe, entity ve üçgen indeksini alır. |

`FilamentShadowOptions` (`src/lighting_c.h`) `bool ray_traced` alanını kazandı.

## Dart API (`lib/src/ray_tracing.dart` ve diğerleri)

#### `class RayTracing`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `requestExtensions` | `static bool requestExtensions()` | Motor oluşturulmadan önce çalışmalıdır; masaüstü Vulkan arka ucu yoksa false (ve değişiklik yok). |
| `clearExtensionRequest` | `static void clearExtensionRequest()` | Sonraki motorlar ray query uzantıları olmadan oluşturulur. |

#### `class RayHit`

| Özellik | Tür | Açıklama |
| :--- | :--- | :--- |
| `t` | `double` | Işın başlangıcından isabete uzaklık, dünya birimi. |
| `entity` | `int` | İsabet alan renderable entity. |
| `primitive` | `int` | İsabet alan üçgenin geometrisi içindeki indeksi. |

#### Başka yerlerdeki eklemeler

| Üye | Nerede | Açıklama |
| :--- | :--- | :--- |
| `supportsRayQuery` | `FilamentEngine` | Aygıtın ışın izleyip izlemediği. |
| `rayTracingEnabled`, `tlasInstanceCount`, `lastTlasBuildTime`, `traceVisibility(...)` | `FilamentScene` | Sahne başına yapılar ve eşzamanlı test kancası (geçici 1x1 bir view üzerinden çizer; kareler arasında çağrılır). |
| `traceRay(ox, oy, oz, dx, dy, dz, {maxDistance})` | `FilamentView` | View'ın çizdiği bir sonraki karede yanıtlanan `Future<RayHit?>`, `pick` gibi. |
| `setRayTracingVisible`, `isRayTracingVisible` | `FilamentRenderableManager` | Renderable başına dahil etme. |
| `rayTraced` | `ShadowOptions` | Yönlü ışık için ışın izlemeli gölgeler. |

```dart
RayTracing.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
// ... sahne, view, kamera, renderable'lar
if (engine.supportsRayQuery) {
  scene.rayTracingEnabled = true;
  lightManager.setShadowOptions(sun, ShadowOptions(rayTraced: true));
}
// bir kare çizildikten sonra:
final hit = await view.traceRay(0, 2, 5, 0, 0, -1, maxDistance: 50);
if (hit != null) print('${hit.entity} entity, ${hit.t} birimde');
```

## Işın izlemeli güneş gölgeleri

Yönlü bir ışıkta `ShadowOptions.rayTraced` ile, yalnızca motor ray query destekliyor ve sahnede `rayTracingEnabled` açıksa, view o ışığın kademeli gölge haritalarını atlar. Yapı geçişi tam çözünürlükte çalışır ve yerleşik `rtShadow` malzemesi, yeniden kurulan yüzeyden ışığa doğru piksel başına bir ışın izler (kendi kendini gölgelemeye karşı mesafeyle ölçeklenen bir sapmayla) ve lit malzemelerin güneş görünürlüğüyle çarptığı R8 bir görünürlük maskesi üretir. Gölgeler sert kenarlıdır, ekran dışındakiler dahil sahnedeki her renderable'ı kapsar ve kademe ayarı gerektirmez; ışın izleme etkinken `mapSize`, `shadowCascades` ve yumuşaklık seçenekleri yok sayılır. Nokta ve spot ışıklar gölge haritalarını korur.

## Ray query malzemeleri

Bir post-process malzeme, malzeme bloğunda `rayQuery : true` bildirerek GLSL 460 ve `GL_EXT_ray_query` ile derlenir (yalnızca Vulkan, SPIR-V 1.4) ve view başına set'te `uniform accelerationStructureEXT sceneTlas` alır. Bugün iki tüketici Filament'in kendi `rtShadow` ve `rayVisibility` malzemeleridir; bir isabetin instance custom index'i sahne üzerinden renderable entity'ye geri eşlenir.

## Sınırlar

- Yalnızca Vulkan, `VK_KHR_ray_query` olan GPU'larda; OpenGL, Metal, WebGPU ve web `supportsRayQuery == false` bildirir. `sampler0_rtShadow`'u (ve ReSTIR texture'larını) yalnızca Vulkan için derlenen shader'lar örnekler: diğer API'lerin lit shader'ları onları dışarıda bırakır, böylece orada fragment sampler'ı harcamazlar (WebGL'de sekiz sampler'lı ve sisli bir lit materyal aksi halde 16'ya ulaşır; Chrome'un Direct3D 11 arka ucu bunu kaldıramaz).
- Skinned ve morph'lu renderable'lar bind pozunda izlenir: hızlandırma yapıları vertex buffer'ları okur ve skinning paletini ya da morph ağırlıklarını uygulayan bir compute ön geçişi henüz yoktur. Gölgeleri ve ışın isabetleri renderable'ın dönüşümünü izler, animasyonunu değil.
- Yapılara yalnızca pozisyon özniteliği olan `PrimitiveType.triangles` primitive'leri girer; çizgiler, noktalar ve şeritler yok sayılır.
- Işın izlemeli gölgeler serttir (penumbra yok) ve yalnızca yönlü ışığı kapsar.
- `FilamentScene.traceVisibility` kendi başına bir kare çizer; çalışan bir çizim döngüsünde `FilamentView.traceRay` kullanın.
- `lumina`'da `LuminaRtxController` bu denetimleri bir view'a uygular: Lumina Studio viewport HUD'undan, oyunlar oyun kullanıcı ayarlarından sürer (`LuminaUserSettingsSubsystem`, Blueprint **Set Ray Tracing Enabled** / **Is Ray Tracing Supported**, bkz. `lumina/world.md`).
