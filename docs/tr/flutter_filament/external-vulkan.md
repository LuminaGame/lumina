[English](../../en/flutter_filament/external-vulkan.md)

# Harici Vulkan bağlamı ve swapchain görüntüleri

Bir engine, başkasının oluşturduğu bir Vulkan instance'ı ve device'ı üzerinde, başkasının sahip olduğu swapchain görüntülerine render edebilir. OpenXR yolu budur: `XR_KHR_vulkan_enable2` device'ı oluşturur (`xrCreateVulkanDeviceKHR`) ve gözlere yalnızca compositor'ün swapchain görüntüleri ulaşır. flutter_filament OpenXR'e hiç link etmez: ayrı bir native kütüphane (`lumina_plugin_openxr`'in OpenXR köprüsü) iki C struct'ını doldurur, Dart yalnızca adreslerini iletir. Dosya yolları `flutter_filament/` paket dizinine görelidir. Masaüstü (Windows, Linux) ve Android Vulkan; web'de her giriş noktası null / false döndürür.

**Bu sayfada:**

- [Parçalar nasıl birleşir](#parçalar-nasıl-birleşir)
- [Kuyruk kuralı](#kuyruk-kuralı)
- [Multiview stereo](#multiview-stereo)
- [`src/external_vulkan_c.h`](#srcexternal_vulkan_ch)
- [`lib/src/external_vulkan.dart`](#libsrcexternal_vulkandart)
- [`lib/src/stereo.dart`](#libsrcstereodart)

## Parçalar nasıl birleşir

1. **Device.** `filament_external_vulkan_device_info_create(instance, physicalDevice, multiview, extraExtensions)`, Filament'in sahipleneceği bir device'tan ne beklediğini listeler: kendisinin açtığı özellikler (depth clamp, anisotropy, ETC2/BC, clip distance, istenip destekleniyorsa multiview, Android'de sampler YCbCr), grafik ailesinden bir ya da iki kuyruk ve device protected memory destekliyorsa bir protected kuyruk (Filament o zaman bir tane alır). Bunun `VkDeviceCreateInfo`'su `vkCreateDevice`'a ya da `xrCreateVulkanDeviceKHR`'a verilir. Paylaşılan bağlamda Filament kendi eklentisini ya da özelliğini eklemez; uygulamanın başka neye ihtiyacı varsa (runtime kendi eklentilerini kendisi ekler) `extraExtensions` içinde olmalıdır.
2. **Engine.** `FilamentEngine.createOnExternalVulkan(ExternalVulkanContext)` (`filament_engine_create_external_vulkan`), `Engine::Builder::sharedContext` ile ve harici swapchain'leri tanıyan bir platform alt sınıfıyla (`VulkanPlatformWindows` / `Linux` / `Android`) bir Vulkan engine'i kurar. GPU tercihi (`FILAMENT_GPU`, `VK_DEVICE_INDEX`) uygulanmaz: loglanır ve yok sayılır, çünkü Filament paylaşılan bağlamın yanında tercih kabul etmez. `ExternalVulkanContext.of(engine)` herhangi bir Vulkan engine'inin instance, device ve kuyruğunu geri okur.
3. **Görüntüler.** `FilamentSwapChain.external(engine, provider)` (`filament_swap_chain_create_external`) bir `filament_external_swapchain_provider` alır: görüntü sayısı, boyut, renk formatı, katman sayısı, derinlik formatı ve bir `user_data` işaretçisiyle `get_images`, `acquire`, `present`, `destroy` C geri çağrıları. Filament bunları driver thread'inde çağırır: bir kare başlarken `acquire` (`xrAcquireSwapchainImage` + `xrWaitSwapchainImage`), karenin komutları gönderildikten sonra `present` (`xrReleaseSwapchainImage`). Dart her karede çağrılmaz.
4. **Layout ve formatlar.** Harici swapchain'ler `PRESENT_SRC_KHR`'a geçirilmez (`Customization::transitionSwapChainImageLayoutForPresent = false`): görüntüler colour attachment olarak geri döner, OpenXR onları böyle alır. Renk formatını `xrEnumerateSwapchainFormats`'tan seçin; sRGB bir format (Quest'te `VK_FORMAT_R8G8B8A8_SRGB`) Filament'in lineer çıktısını donanımın kodlamasına bırakır. Derinlik görüntüsünü provider verir (`get_images`'in `depth`'i); Filament harici swapchain için kendisi oluşturmaz.
5. **Runtime olmadan ayağa kaldırma.** `ExternalVulkanOffscreen`, kendi instance'ı, (yukarıdaki device bilgisiyle oluşturulmuş) device'ı ve geri okunabilen görüntüleri olan, her acquire ve present'i kaydeden bir referans provider'dır. Masaüstü testleri ve smoke onu kullanır.

## Kuyruk kuralı

Filament driver thread'inden `ExternalVulkanContext.queueIndex` kuyruğuna gönderir. Device bilgisi, aile bunlara sahipse grafik ailesinden iki kuyruk ister (masaüstü GPU'lar ve Adreno 740'ta var): **0. indeks runtime'ındır** (OpenXR grafik bağlamasının adlandırdığı, `xrEndFrame` ve swapchain çağrılarının kullandığı kuyruk), **1. indeks Filament'in** (`filament_external_vulkan_device_info_filament_queue_index`). Tek kuyruklu bir ailede engine render ederken başka hiçbir şey gönderim yapamaz; tek istisna provider'ın geri çağrılarıdır, onlar driver thread'inde Filament'in gönderimleriyle sırayla çalışır. `present` önce Filament'in "bitti" semaforunu Filament'in kuyruğunda boş bir gönderimle tüketir, sonra provider'ı çağırır. `test/src/external_vulkan_test.dart` Filament'in 1. indeksi aldığını denetler.

## Multiview stereo

Multiview özelliği olan bir device üzerinde `EngineConfig(stereoscopicType: StereoscopicType.multiview, stereoscopicEyeCount: 2)` ile oluşturulan bir engine, view'ın `stereoscopicOptions`'ı açıkken iki gözü tek geçişte 2 katmanlı bir görüntüye render eder. Her göz kafaya (kameranın model matrisi) göre `FilamentCamera.setEyeModelMatrix(eye, model)` konumundadır ve kendi projeksiyonu olabilir (`setCustomEyeProjection`, bir OpenXR view'ının asimetrik görüş alanı). Materyallerin multiview varyantı gerekir: hazır Filament (`1.77.2-lumina.20`'den itibaren) `FILAMENT_ENABLE_MULTIVIEW=ON` ve `FILAMENT_SAMPLES_STEREO_TYPE=multiview` ile derlenir, bu yüzden engine'in varsayılan materyali, skybox ve glTF ubershader'ları birer tane taşır. Stereo bir view post-processing olmadan render eder (çıktısı lineerdir, sRGB görüntü kodlar). Engine stereo render edemiyorsa `FilamentView.isStereoActive(engine)` false olur ve view tek göz render eder: siyah bir kare yerine açık bir geri düşüş (göz başına bir swapchain ve iki view).

## `src/external_vulkan_c.h`

| Fonksiyon | Açıklama |
| :--- | :--- |
| `filament_engine_create_external_vulkan(context, feature_level, config)` | Verilen instance, physical device, device ve kuyruk üzerinde bir Vulkan engine'i. Başarısızlıkta null. |
| `filament_engine_is_external_vulkan(engine)` | Engine'in harici bir device'ı sahiplenip sahiplenmediği. |
| `filament_engine_get_vulkan_context(engine, out)` | Herhangi bir Vulkan engine'inin Vulkan nesneleri ve kuyruğu; `multiview` engine'in multiview stereo render edip etmediğini söyler. |
| `filament_swap_chain_create_external(engine, provider)` | Provider'ın görüntüleri üzerinde bir SwapChain (struct kopyalanır). |
| `filament_external_vulkan_device_info_create(...)`, `_create_info`, `_queue_family`, `_filament_queue_index`, `_multiview`, `_destroy` | Filament'in sahipleneceği bir device'ın neyle oluşturulması gerektiği. |
| `filament_external_vulkan_offscreen_create(width, height, image_count, layer_count, multiview, srgb)`, `_context`, `_provider`, `_read_pixels`, `_events`, `_destroy` | Referans provider. |

C sarmalayıcısı Dart eklentilerinin kullandığı stereo çağrılarını da kazandı: `filament_view_set_stereoscopic_options` / `get` / `filament_view_is_stereo_active` (`src/view_c.h`) ve `filament_camera_set_eye_model_matrix` / `get`, `filament_camera_set_custom_eye_projection`, `filament_camera_get_eye_projection_matrix` (`src/camera_c.h`).

## `lib/src/external_vulkan.dart`

### `class ExternalVulkanContext`

`instance`, `physicalDevice`, `device` (adresler), `queueFamily`, `queueIndex`, `multiview`. `ExternalVulkanContext.of(engine)` bir tanesini geri okur; `copyToNative` C struct'ını doldurur.

### `class ExternalVulkanOffscreen`

| Üye | Açıklama |
| :--- | :--- |
| `create({width, height, imageCount = 3, layers = 1, multiview = false, srgb = false})` | Instance, device ve RGBA8 görüntüler; Vulkan yoksa null. |
| `context` | `FilamentEngine.createOnExternalVulkan` için nesneler. |
| `provider` | `FilamentSwapChain.external` için provider struct'ı (bu nesneye aittir). |
| `readPixels(index, {layer})` | Bir görüntünün bir katmanı, RGBA8, üst satır önce, engine boştayken. |
| `events` | Şimdiye kadarki her acquire ve present (`ExternalSwapchainEvent`). |
| `dispose()` | Görüntüleri, device'ı ve instance'ı yok eder (engine'den sonra). |

`FilamentEngine.createOnExternalVulkan`, `FilamentEngine.isExternalVulkan` ve `FilamentSwapChain.external` kendi sınıflarıyla birlikte durur (`lib/src/engine.dart`, `lib/src/swap_chain.dart`).

## `lib/src/stereo.dart`

| Eklenti üyesi | Açıklama |
| :--- | :--- |
| `FilamentView.stereoscopicOptions` (get / set) | View'da stereoyu açar. |
| `FilamentView.isStereoActive(engine)` | İki gözün render edilip edilmediği (seçenek açık ve engine yapabiliyor). |
| `FilamentCamera.setEyeModelMatrix(eye, model)` / `getEyeModelMatrix(eye)` | Kafaya göre bir göz. |
| `FilamentCamera.setCustomEyeProjection(projections, culling, near:, far:)` | Göz başına bir projeksiyon ve hepsini kapsayan culling projeksiyonu. |
| `FilamentCamera.getEyeProjectionMatrix(eye)` | Bir gözün projeksiyonu. |

---

[Önceki: Platform entegrasyonu ve GPU seçimi](platform.md) | [Üst: flutter_filament](index.md) | [Sonraki: lumina (engine çekirdeği)](../lumina/index.md)
