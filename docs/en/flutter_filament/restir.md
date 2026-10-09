[Türkçe](../../tr/flutter_filament/restir.md)

# ReSTIR direct lighting

Direct lighting from many punctual lights by reservoir resampling: every pixel keeps a small reservoir of candidate lights, reuses the previous frame's and its neighbours' reservoirs, traces one visibility ray to the light that survives and shades that light alone. The cost is nearly independent of the light count and every light casts a hard ray-traced shadow. Vulkan with ray query support only (see [Ray tracing](ray-tracing.md)); everywhere else the froxel light loop renders as before. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [How it fits Filament](#how-it-fits-filament)
- [What changes versus froxels](#what-changes-versus-froxels)
- [Order of operations](#order-of-operations)
- [Native C bridge (`src/restir_c.h`)](#native-c-bridge-srcrestir_ch)
- [Dart API (`lib/src/restir.dart`)](#dart-api-libsrcrestirdart)
- [Stats](#stats)
- [Limits](#limits)
- [Licence note](#licence-note)

## How it fits Filament

Lumina's Filament patch `0008` (see `third_party/filament/README.md`) adds `RestirOptions` to the view. When it is enabled on an engine with ray queries and the scene keeps its acceleration structures, the renderer builds a light buffer every frame from all of the scene's point and spot lights (an RGBA32F texture, four texels per light, no 256-light cap), then runs three ray query post-process passes over the structure depth:

1. **Candidates and temporal reuse**: `initialCandidates` lights are drawn uniformly, weighted by their unshadowed contribution to a diffuse surface (resampled importance sampling), and merged with the previous frame's reservoir at the reprojected position when the surface is the same (`temporal`, history weight bounded by `maxHistory`).
2. **Spatial reuse**: `spatialSamples` neighbouring reservoirs within `spatialRadiusPx` are merged, re-evaluating their light at this pixel.
3. **Visibility**: one ray from the surface to the chosen light (`visibilityRays`).

The result, (light index, resampling weight W, visibility), is bound to the colour pass, where the lit material shaders fetch the light's data and shade that one light with their full BRDF instead of looping over the froxel's lights. The reservoirs after reuse become the next frame's history.

## What changes versus froxels

| | Froxel light loop | ReSTIR direct lighting |
| :--- | :--- | :--- |
| Lights per pixel | every light overlapping the froxel, up to Filament's 256-light limit | one resampled light, from any number of lights |
| Cost | grows with light count and overlap | nearly constant per pixel |
| Shadows | shadow maps for the few lights that have them | a hard ray-traced shadow for every light |
| Noise | none | low after a few frames of history; resets on camera cuts |
| Transparent surfaces | shaded | keep the froxel loop (no reservoir behind them) |
| Directional light, IBL | Filament's paths | unchanged |

## Order of operations

1. `RayTracing.requestExtensions()` **before** `FilamentEngine.create` (DLSS may be requested too, in either order).
2. Create the engine on the Vulkan backend; `view.restirSupported` is true when the device traces rays and the ray query materials are loaded.
3. `scene.rayTracingEnabled = true`: the visibility rays need the acceleration structures.
4. `view.restirOptions = const RestirOptions(enabled: true)`; tune the counts for quality against cost.
5. Read `view.restirStats` for the light count, the rays per frame and the GPU time; call `view.resetRestirHistory()` on a camera cut.
6. `lightManager.setRestirSamplingWeight(light, 0)` removes a light from ReSTIR shading; values above 1 favour it.

## Native C bridge (`src/restir_c.h`)

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_view_set_restir_options` | `void filament_view_set_restir_options(void* view, const filament_restir_options* options);` | Sets the ReSTIR options of the view. |
| `filament_view_get_restir_options` | `void filament_view_get_restir_options(void* view, filament_restir_options* out_options);` | Reads them back. |
| `filament_view_restir_supported` | `bool filament_view_restir_supported(void* view);` | Ray queries available and the ReSTIR materials loaded. |
| `filament_view_get_restir_stats` | `void filament_view_get_restir_stats(void* view, filament_restir_stats_t* out_stats);` | Light count, rays per frame and GPU nanoseconds of the last ReSTIR frame. |
| `filament_view_restir_reset_history` | `void filament_view_restir_reset_history(void* view);` | Drops the temporal history. |
| `filament_light_set_restir_sampling_weight` | `void filament_light_set_restir_sampling_weight(void* engine, uint32_t entity, float weight);` | Per-light sampling weight (0 removes the light, default 1). |

`filament_restir_options` mirrors `filament::RestirOptions` (`filament_options_sizeof(14)`): `enabled`, `initialCandidates`, `spatialSamples`, `spatialRadiusPx`, `temporal`, `maxHistory`, `visibilityRays`, `shadeEmissive`.

## Dart API (`lib/src/restir.dart`)

#### `class RestirOptions`

| Property | Type | Description |
| :--- | :--- | :--- |
| `enabled` | `bool` | Use ReSTIR for the punctual lights. Default false. |
| `initialCandidates` | `int` | Lights sampled per pixel and frame before reuse. Default 8. |
| `spatialSamples` | `int` | Neighbouring reservoirs merged per pixel; 0 disables spatial reuse. Default 2. |
| `spatialRadiusPx` | `double` | Neighbourhood radius in pixels. Default 32. |
| `temporal` | `bool` | Reuse the previous frame's reservoir. Default true. |
| `maxHistory` | `int` | Frames of history one reservoir may weigh. Default 20. |
| `visibilityRays` | `bool` | Trace a visibility ray to the chosen light. Default true. |
| `shadeEmissive` | `bool` | Reserved; emissive triangles as lights are not implemented. |

#### `class RestirStats`

| Property | Type | Description |
| :--- | :--- | :--- |
| `lightCount` | `int` | Punctual lights in the light buffer. |
| `emissiveTriangleCount` | `int` | Always 0. |
| `raysPerFrame` | `int` | Visibility rays traced last frame (the pixel count, or 0 without rays). |
| `gpuTime` | `Duration` | GPU time of the ReSTIR passes last measured. |

#### Additions elsewhere

| Member | Where | Description |
| :--- | :--- | :--- |
| `restirOptions` (get/set), `restirSupported`, `restirStats`, `resetRestirHistory()` | `FilamentView` | The view-side controls. |
| `setRestirSamplingWeight(entity, weight)` | `FilamentLightManager` | Per-light sampling weight. |

```dart
RayTracing.requestExtensions();
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
// ... scene with hundreds of point lights, view, camera
scene.rayTracingEnabled = true;
if (view.restirSupported) {
  view.restirOptions = const RestirOptions(enabled: true, initialCandidates: 8, spatialSamples: 2);
}
// after some frames:
print(view.restirStats); // RestirStats(lights: 512, rays: 786432, gpu: 0:00:00.001900)
```

## Stats

`lightCount` is the number of punctual lights the light buffer held (the whole scene, not only the froxel-visible ones). `raysPerFrame` is the render-resolution pixel count while `visibilityRays` is on. `gpuTime` comes from a timer query around the three passes and lags the frame it measures by a frame or two.

## Limits

- Vulkan with `VK_KHR_ray_query` only; `restirSupported` is false elsewhere and `enabled` is kept but ignored. Only shaders compiled for Vulkan contain the ReSTIR light evaluation and sample its two textures.
- The scene must have `rayTracingEnabled`; without acceleration structures the froxel path renders.
- Resampling targets a diffuse surface with a normal reconstructed from depth; glossy highlights converge more slowly and the spatial reuse is the basic, slightly biased combination at depth edges.
- Only one light is shaded per pixel and frame: noise is visible for a few frames after a camera cut or a history reset, and temporal accumulation is the only denoiser.
- Transparent surfaces keep the froxel light loop; the directional light keeps its shadow maps or the ray-traced shadow of [Ray tracing](ray-tracing.md).
- Light shadow maps and contact shadows of punctual lights are not applied under ReSTIR (the visibility ray replaces them).
- Emissive triangles as lights (`shadeEmissive`) are not implemented.

## Licence note

This is Lumina's own GLSL implementation of ReSTIR direct lighting (resampled importance sampling with temporal and spatial reuse, after Bitterli et al., 2020), written as Filament post-process materials. It contains no code from NVIDIA's RTXDI SDK, whose current licence is not compatible with Lumina's GPL build, and it needs no HLSL compiler or compute shaders.
