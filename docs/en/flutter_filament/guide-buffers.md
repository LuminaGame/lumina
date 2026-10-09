[Türkçe](../../tr/flutter_filament/guide-buffers.md)

# Guide buffers

Per-pixel guides for neural denoisers and upscalers (DLSS Ray Reconstruction): the world normal and roughness, the diffuse and specular albedo of the shaded surface, and the distance a mirror ray travels to its hit. Filament is a forward renderer without a G-buffer; Lumina's Filament patch `0012` (see `third_party/filament/README.md`) writes these from the lit shaders. Vulkan only, single-sampled views only. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [What is written](#what-is-written)
- [How it is produced](#how-it-is-produced)
- [Native C bridge (`src/guide_buffers_c.h`)](#native-c-bridge-srcguide_buffers_ch)
- [Dart API (`lib/src/guide_buffers.dart`)](#dart-api-libsrcguide_buffersdart)
- [Cost](#cost)
- [Limits](#limits)

## What is written

| `GuideBuffer` | format | content |
|---|---|---|
| `normalRoughness` | RGBA16F | world-space normal (xyz), perceptual roughness (w) |
| `diffuseAlbedo` | RGBA8 | `baseColor · (1 − metallic)`, linear |
| `specularAlbedo` | RGBA8 | the split-sum specular albedo `mix(dfg.x, dfg.y, F0)` for the pixel's view angle, linear |
| `specularHitDistance` | R16F | distance (world units, metres) of a mirror-reflection ray to its hit; 0 where there is no surface, 65504 when the ray leaves the scene |

All are at the render resolution (the colour pass size). Unlit surfaces (the skybox) and empty pixels have zero guides.

## How it is produced

- `View::setGuideBufferOptions({ .enabled = true, .specularHitDistance = true })`.
- A clear pass creates the three colour guides at zero; the colour pass binds them as colour attachments 1–3. The lit fragment shaders (`surface_main.fs`, compiled for `TARGET_VULKAN_ENVIRONMENT` only) write them after evaluating the material. Specular-glossiness and cloth materials map their inputs to the same quantities.
- Blended surfaces write zero (multiply-blended ones one) so the opaque surface's guides stay in place under them.
- With ray tracing on the scene (`Scene::setRayTracingEnabled`), the built-in `rtSpecularHitDistance` ray query material traces one mirror ray per pixel from the depth and the normal guide.
- The frame graph culls guides nobody reads: an external upscaler that asks for them (`ExternalUpscaler::guideBuffers()`, images 4–7 of the external pass) or a copy into a user texture (`View::setGuideBufferTexture`) keeps them.
- Materials compiled before patch `0012` write no guides; recompile them (`tool/build_materials.sh` in `flutter_filament` and `lumina`). The glTF ubershaders and runtime-compiled materials come from the same Filament build and write them.

## Native C bridge (`src/guide_buffers_c.h`)

- `filament_view_set_guide_buffer_options(view, const filament_guide_buffer_options_t*)` / `filament_view_get_guide_buffer_options(view, out)` with `{ bool enabled; bool specularHitDistance; }`.
- `filament_view_set_guide_buffer_texture(view, which, texture)`: copies guide `which` (`filament_guide_buffer`) into a texture of the render resolution, the guide's format and `BLIT_DST` usage every frame; NULL stops it.

On the web the options are kept for round trips and nothing is rendered.

## Dart API (`lib/src/guide_buffers.dart`)

```dart
view.guideBufferOptions = const GuideBufferOptions(enabled: true);
scene.rayTracingEnabled = true; // for the specular hit distance
final normals = GuideBufferReadback.attach(
    engine: engine, view: view, which: GuideBuffer.normalRoughness, width: w, height: h);
// render a frame...
final data = await normals.read(renderer);           // w * h * 4 floats, rows top-down
final v = normals.at(data, x, y);                   // [nx, ny, nz, roughness]
normals.dispose();
```

- `GuideBuffer` (with its `format`), `GuideBufferOptions` (`enabled`, `specularHitDistance`), the `FilamentView.guideBufferOptions` getter/setter and `setGuideBufferTexture(GuideBuffer, FilamentTexture?)` (extension `GuideBuffers`).
- `GuideBufferReadback`: the texture, render target and readback of one guide, for tests and debug views (`channels` is 4, or 1 for the hit distance; RGBA8 guides are normalised to 0..1).

## Cost

Measured on the RTX PRO 2000 at 1920×1080 (four props, every guide exported, frames rendered and waited for): within 0.06 ms of the frame without guides, below the run-to-run noise of that measurement. The colour pass writes three more attachments (16 bytes per pixel); the hit distance traces one ray per surface pixel.

## Limits

- Vulkan only; MSAA views render without guides.
- Custom vertex displacement, particles and blended materials have no guides of their own.
- The specular hit distance follows the mirror direction; rough surfaces would need a sampled lobe direction.
