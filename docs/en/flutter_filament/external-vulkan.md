[Türkçe](../../tr/flutter_filament/external-vulkan.md)

# External Vulkan context and swapchain images

An engine can render on a Vulkan instance and device someone else created, into swapchain images someone else owns. That is the OpenXR path: `XR_KHR_vulkan_enable2` creates the device (`xrCreateVulkanDeviceKHR`), and only the compositor's swapchain images reach the eyes. flutter_filament never links OpenXR: a separate native library (the OpenXR bridge of `lumina_plugin_openxr`) fills two C structs, and Dart only hands their addresses over. File paths are relative to the `flutter_filament/` package directory. Desktop (Windows, Linux) and Android Vulkan; on the web every entry point returns null / false.

**On this page:**

- [How it fits together](#how-it-fits-together)
- [The queue rule](#the-queue-rule)
- [Multiview stereo](#multiview-stereo)
- [`src/external_vulkan_c.h`](#srcexternal_vulkan_ch)
- [`lib/src/external_vulkan.dart`](#libsrcexternal_vulkandart)
- [`lib/src/stereo.dart`](#libsrcstereodart)

## How it fits together

1. **The device.** `filament_external_vulkan_device_info_create(instance, physicalDevice, multiview, extraExtensions)` lists what Filament needs from a device it will adopt: the features it enables itself (depth clamp, anisotropy, ETC2/BC, clip distance, multiview when asked and supported, sampler YCbCr on Android), one or two queues of the graphics family, and a protected queue when the device supports protected memory (Filament fetches one then). Its `VkDeviceCreateInfo` goes to `vkCreateDevice` or `xrCreateVulkanDeviceKHR`. With a shared context Filament adds no extensions or features of its own, so whatever else the app needs (the runtime's own extensions are added by the runtime) must be in `extraExtensions`.
2. **The engine.** `FilamentEngine.createOnExternalVulkan(ExternalVulkanContext)` (`filament_engine_create_external_vulkan`) builds a Vulkan engine with `Engine::Builder::sharedContext` and a platform subclass (`VulkanPlatformWindows` / `Linux` / `Android`) that knows external swapchains. A GPU preference (`FILAMENT_GPU`, `VK_DEVICE_INDEX`) does not apply: it is logged and ignored, because Filament refuses a preference next to a shared context. `ExternalVulkanContext.of(engine)` reads back the instance, devices and queue of any Vulkan engine.
3. **The images.** `FilamentSwapChain.external(engine, provider)` (`filament_swap_chain_create_external`) takes a `filament_external_swapchain_provider`: image count, size, colour format, layer count, depth format, and C callbacks `get_images`, `acquire`, `present`, `destroy` with a `user_data` pointer. Filament calls them on its driver thread: `acquire` when a frame begins (`xrAcquireSwapchainImage` + `xrWaitSwapchainImage`), `present` after the frame's commands are submitted (`xrReleaseSwapchainImage`). Dart is never called per frame.
4. **Layouts and formats.** External swapchains are not transitioned to `PRESENT_SRC_KHR` (`Customization::transitionSwapChainImageLayoutForPresent = false`): the images go back as colour attachments, which is how OpenXR takes them. Pick the colour format from `xrEnumerateSwapchainFormats`; an sRGB format (`VK_FORMAT_R8G8B8A8_SRGB` on a Quest) lets the hardware encode Filament's linear output. The provider supplies a depth image (`get_images`' `depth`); Filament does not make one for an external swapchain.
5. **Bring-up without a runtime.** `ExternalVulkanOffscreen` is a reference provider with its own instance, device (made through the device info above) and images that can be read back, recording every acquire and present. Desktop tests and the smoke use it.

## The queue rule

Filament submits from its driver thread on `ExternalVulkanContext.queueIndex`. The device info asks for two queues of the graphics family when it has them (desktop GPUs and the Adreno 740 do): **index 0 is for the runtime** (the queue the OpenXR graphics binding names, used by `xrEndFrame` and the swapchain calls), **index 1 for Filament** (`filament_external_vulkan_device_info_filament_queue_index`). On a family with a single queue nothing else may submit while the engine renders, except inside the provider's callbacks, which run on the driver thread in order with Filament's submits. `present` itself first consumes Filament's "finished" semaphore with an empty submit on Filament's queue, then calls the provider. `test/src/external_vulkan_test.dart` checks that Filament gets index 1.

## Multiview stereo

An engine created with `EngineConfig(stereoscopicType: StereoscopicType.multiview, stereoscopicEyeCount: 2)` on a device with the multiview feature renders both eyes in one pass into a 2-layer image when the view's `stereoscopicOptions` are enabled. Each eye sits at `FilamentCamera.setEyeModelMatrix(eye, model)` relative to the head (the camera's model matrix) and can have its own projection (`setCustomEyeProjection`, an OpenXR view's asymmetric field of view). The materials need a multiview variant: the prebuilt Filament (from `1.77.2-lumina.20`) is built with `FILAMENT_ENABLE_MULTIVIEW=ON` and `FILAMENT_SAMPLES_STEREO_TYPE=multiview`, so the engine's default material, the skybox and the glTF ubershaders have one. The materials flutter_filament draws itself (the line material of `FilamentWireframeMesh` and the UI overlay) and lumina's procedural sky ship one package per stereoscopic type (`-PstereoscopicType=instanced|multiview` in `tool/materials.txt`), and the engine's `stereoscopicType` picks the package: a package of the other type still loads, but Filament logs `The stereoscopic type in the compiled material ... is not compatible with the engine's setting` and its stereo view draws nothing. `test/src/material_stereo_variants_test.dart` loads them on a multiview engine. A stereo view renders without post-processing (its output is linear, encoded by an sRGB image). When the engine cannot render stereo, `FilamentView.isStereoActive(engine)` is false and the view renders one eye: the explicit fallback (one swapchain per eye and two views) instead of a black frame.

## `src/external_vulkan_c.h`

| Function | Description |
| :--- | :--- |
| `filament_engine_create_external_vulkan(context, feature_level, config)` | A Vulkan engine on the given instance, physical device, device and queue. Null on failure. |
| `filament_engine_is_external_vulkan(engine)` | Whether the engine adopted an external device. |
| `filament_engine_get_vulkan_context(engine, out)` | The Vulkan objects and queue of any Vulkan engine; `multiview` tells whether the engine renders multiview stereo. |
| `filament_swap_chain_create_external(engine, provider)` | A SwapChain on the provider's images (the struct is copied). |
| `filament_external_vulkan_device_info_create(...)`, `_create_info`, `_queue_family`, `_filament_queue_index`, `_multiview`, `_destroy` | What a device Filament adopts must be created with. |
| `filament_external_vulkan_offscreen_create(width, height, image_count, layer_count, multiview, srgb)`, `_context`, `_provider`, `_read_pixels`, `_events`, `_destroy` | The reference provider. |

The C wrapper also gained the stereo calls the Dart extensions use: `filament_view_set_stereoscopic_options` / `get` / `filament_view_is_stereo_active` (`src/view_c.h`) and `filament_camera_set_eye_model_matrix` / `get`, `filament_camera_set_custom_eye_projection`, `filament_camera_get_eye_projection_matrix` (`src/camera_c.h`).

## `lib/src/external_vulkan.dart`

### `class ExternalVulkanContext`

`instance`, `physicalDevice`, `device` (addresses), `queueFamily`, `queueIndex`, `multiview`. `ExternalVulkanContext.of(engine)` reads one back; `copyToNative` fills the C struct.

### `class ExternalVulkanOffscreen`

| Member | Description |
| :--- | :--- |
| `create({width, height, imageCount = 3, layers = 1, multiview = false, srgb = false})` | Instance, device and RGBA8 images; null without Vulkan. |
| `context` | The objects for `FilamentEngine.createOnExternalVulkan`. |
| `provider` | The provider struct for `FilamentSwapChain.external` (owned by this object). |
| `readPixels(index, {layer})` | One layer of one image, RGBA8, top row first, while the engine is idle. |
| `events` | Every acquire and present so far (`ExternalSwapchainEvent`). |
| `dispose()` | Destroys images, device and instance (after the engine). |

`FilamentEngine.createOnExternalVulkan`, `FilamentEngine.isExternalVulkan` and `FilamentSwapChain.external` live with their classes (`lib/src/engine.dart`, `lib/src/swap_chain.dart`).

## `lib/src/stereo.dart`

| Extension member | Description |
| :--- | :--- |
| `FilamentView.stereoscopicOptions` (get / set) | Enables stereo on the view. |
| `FilamentView.isStereoActive(engine)` | Whether both eyes render (options on and the engine can do it). |
| `FilamentCamera.setEyeModelMatrix(eye, model)` / `getEyeModelMatrix(eye)` | An eye relative to the head. |
| `FilamentCamera.setCustomEyeProjection(projections, culling, near:, far:)` | One projection per eye and the culling projection that encloses them. |
| `FilamentCamera.getEyeProjectionMatrix(eye)` | An eye's projection. |

---

[Previous: Platform integration and GPU selection](platform.md) | [Up: flutter_filament](index.md) | [Next: lumina (engine core)](../lumina/index.md)
