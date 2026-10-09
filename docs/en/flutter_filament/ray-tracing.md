[Türkçe](../../tr/flutter_filament/ray-tracing.md)

# Ray tracing

Hardware ray tracing on the Vulkan backend through `VK_KHR_ray_query`: every scene can keep acceleration structures over its renderables, the directional light can trace hard shadows instead of rendering cascaded shadow maps, and a view answers single visibility rays. Everything degrades silently on other backends, on GPUs without the extensions and on the web: support reads false, the scene flag builds nothing, ray-traced shadows fall back to the shadow maps and rays report no hit. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [How it fits Filament](#how-it-fits-filament)
- [Order of operations](#order-of-operations)
- [Native C bridge (`src/ray_tracing_c.h`)](#native-c-bridge-srcray_tracing_ch)
- [Dart API (`lib/src/ray_tracing.dart` and friends)](#dart-api-libsrcray_tracingdart-and-friends)
- [Ray-traced sun shadows](#ray-traced-sun-shadows)
- [Ray query materials](#ray-query-materials)
- [Limits](#limits)

## How it fits Filament

Lumina's Filament patch `0007` (see `third_party/filament/README.md`) teaches the Vulkan backend acceleration structures: a bottom-level structure (BLAS) per distinct primitive geometry (vertex buffer, index buffer, offset and count) and a top-level structure (TLAS) per scene over the world transforms of every renderable that is ray-tracing visible. `Scene::setRayTracingEnabled` makes the renderer rebuild the TLAS at the start of every frame the scene renders, before any pass; BLASes are built once and dropped after 120 unused frames. The TLAS is bound to the per-view descriptor set (binding 13) of *ray query materials*, post-process materials compiled with GLSL 460 and `GL_EXT_ray_query`, and the colour pass of lit materials reads a ray-traced shadow mask (binding 12) when the sun uses ray-traced shadows. The GPU time of each TLAS build is measured with a timer query.

Vertex and index buffers are created with the usages acceleration-structure builds need whenever the device has the extensions, so no buffer has to be recreated when ray tracing is turned on.

## Order of operations

1. `RayTracing.requestExtensions()` **before** `FilamentEngine.create`: `VK_KHR_acceleration_structure`, `VK_KHR_ray_query`, `VK_KHR_deferred_host_operations` and `VK_KHR_buffer_device_address` cannot be added to an existing device. The request is stored next to the DLSS one, so `Dlss.requestExtensions()` may come before or after it. `RayTracing.clearExtensionRequest()` undoes it for later engines.
2. Create the engine on the Vulkan backend. `engine.supportsRayQuery` is true when the GPU and driver provide the extensions; it stays false for an engine created without the request.
3. `scene.rayTracingEnabled = true`. From the next rendered frame on, `scene.tlasInstanceCount` counts the renderables in the TLAS and `scene.lastTlasBuildTime` reports the last build once its timer resolved (a few frames later).
4. `FilamentRenderableManager.setRayTracingVisible(entity, false)` removes a renderable from the structures while it keeps rendering (default true for every renderable).
5. `ShadowOptions(rayTraced: true)` on the directional light switches its shadows to ray tracing; `view.traceRay(...)` and the test hook `scene.traceVisibility(...)` answer visibility rays.

## Native C bridge (`src/ray_tracing_c.h`)

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_ray_tracing_request_extensions` | `bool filament_ray_tracing_request_extensions(void);` | Asks the engines created from now on for the ray query device extensions; false where there is no desktop Vulkan backend. |
| `filament_ray_tracing_clear_extension_request` | `void filament_ray_tracing_clear_extension_request(void);` | Forgets the request for later engines. |
| `filament_engine_supports_ray_query` | `bool filament_engine_supports_ray_query(void* engine);` | The device builds acceleration structures and traces rays from shaders. |
| `filament_scene_set_ray_tracing_enabled` | `void filament_scene_set_ray_tracing_enabled(void* scene, bool enabled);` | Keeps the scene's acceleration structures, rebuilt every rendered frame. |
| `filament_scene_get_ray_tracing_enabled` | `bool filament_scene_get_ray_tracing_enabled(void* scene);` | The flag as set. |
| `filament_scene_get_tlas_instance_count` | `uint32_t filament_scene_get_tlas_instance_count(void* scene);` | Renderables in the TLAS after the last frame. |
| `filament_scene_get_tlas_build_nanos` | `uint64_t filament_scene_get_tlas_build_nanos(void* scene);` | GPU time of the last TLAS build in nanoseconds. |
| `filament_renderable_set_ray_tracing_visible` | `void filament_renderable_set_ray_tracing_visible(void* engine, uint32_t entity, bool visible);` | Includes or excludes a renderable's geometry. |
| `filament_renderable_is_ray_tracing_visible` | `bool filament_renderable_is_ray_tracing_visible(void* engine, uint32_t entity);` | The flag as set (default true). |
| `filament_scene_trace_visibility` | `bool filament_scene_trace_visibility(void* engine, void* scene, const float* origin3, const float* direction3, float max_distance, float* out_distance, uint32_t* out_entity, uint32_t* out_primitive);` | Test hook: renders a temporary 1x1 view over the scene and waits for the ray's answer; true on a hit. |
| `filament_view_trace_ray` | `void filament_view_trace_ray(void* view, const float* origin3, const float* direction3, float max_distance, FilamentRayHitCallback callback, void* user_data);` | Queues a ray answered by the view's next frame; the callback receives hit, distance, entity and triangle index. |

`FilamentShadowOptions` (`src/lighting_c.h`) gained `bool ray_traced`.

## Dart API (`lib/src/ray_tracing.dart` and friends)

#### `class RayTracing`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `requestExtensions` | `static bool requestExtensions()` | Must run before the engine is created; false (and no change) without a desktop Vulkan backend. |
| `clearExtensionRequest` | `static void clearExtensionRequest()` | Later engines are created without the ray query extensions. |

#### `class RayHit`

| Property | Type | Description |
| :--- | :--- | :--- |
| `t` | `double` | Distance from the ray origin to the hit, in world units. |
| `entity` | `int` | The renderable entity hit. |
| `primitive` | `int` | Index of the triangle hit within its geometry. |

#### Additions elsewhere

| Member | Where | Description |
| :--- | :--- | :--- |
| `supportsRayQuery` | `FilamentEngine` | Whether the device traces rays. |
| `rayTracingEnabled`, `tlasInstanceCount`, `lastTlasBuildTime`, `traceVisibility(...)` | `FilamentScene` | The per-scene structures and the synchronous test hook (renders through a temporary 1x1 view, so call it between frames). |
| `traceRay(ox, oy, oz, dx, dy, dz, {maxDistance})` | `FilamentView` | `Future<RayHit?>` answered by the next frame the view renders, like `pick`. |
| `setRayTracingVisible`, `isRayTracingVisible` | `FilamentRenderableManager` | Per-renderable inclusion. |
| `rayTraced` | `ShadowOptions` | Ray-traced shadows for the directional light. |

```dart
RayTracing.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
// ... scene, view, camera, renderables
if (engine.supportsRayQuery) {
  scene.rayTracingEnabled = true;
  lightManager.setShadowOptions(sun, ShadowOptions(rayTraced: true));
}
// after a frame rendered:
final hit = await view.traceRay(0, 2, 5, 0, 0, -1, maxDistance: 50);
if (hit != null) print('hit entity ${hit.entity} at ${hit.t} units');
```

## Ray-traced sun shadows

With `ShadowOptions.rayTraced` on a directional light, and only when the engine supports ray queries and the scene has `rayTracingEnabled`, the view skips the cascaded shadow maps of that light. The structure pass runs at full resolution and the built-in `rtShadow` material traces one ray per pixel from the reconstructed surface toward the light (with a distance-scaled bias against self-shadowing) into an R8 visibility mask that the lit materials multiply into the sun's visibility. The shadows are hard-edged, cover every renderable in the scene including the ones off-screen, and need no cascade tuning; `mapSize`, `shadowCascades` and the softness options are ignored while ray tracing is active. Point and spot lights keep their shadow maps.

## Ray query materials

A post-process material declares `rayQuery : true` in its material block to be compiled as GLSL 460 with `GL_EXT_ray_query` (Vulkan only, SPIR-V 1.4) and receives `uniform accelerationStructureEXT sceneTlas` in the per-view set. Filament's own `rtShadow` and `rayVisibility` materials are the two consumers today; the instance custom index of a hit maps back to the renderable entity through the scene.

## Limits

- Vulkan only, on GPUs with `VK_KHR_ray_query`; OpenGL, Metal, WebGPU and the web report `supportsRayQuery == false`. Only shaders compiled for Vulkan sample `sampler0_rtShadow` (and the ReSTIR textures): the other APIs' lit shaders leave them out, so they cost no fragment sampler there (on WebGL a lit material with eight samplers and fog would otherwise reach 16, which Chrome's Direct3D 11 backend does not survive).
- Skinned and morphed renderables are traced in their bind pose: the acceleration structures read the vertex buffers, and there is no compute pre-pass applying the skinning palette or morph weights yet. Their shadows and ray hits follow the renderable's transform, not its animation.
- Only `PrimitiveType.triangles` primitives with a position attribute enter the structures; lines, points and strips are ignored.
- Ray-traced shadows are hard (no penumbra) and cover the directional light only.
- `FilamentScene.traceVisibility` renders a frame on its own; use `FilamentView.traceRay` in a running render loop.
- In `lumina`, `LuminaRtxController` applies these controls to a view: Lumina Studio drives it from the viewport HUD and games through the game user settings (`LuminaUserSettingsSubsystem`, Blueprint **Set Ray Tracing Enabled** / **Is Ray Tracing Supported**, see `lumina/world.md`).
