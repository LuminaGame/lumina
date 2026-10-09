# Changelog

## Unreleased

- DLSS Frame Generation and Multi Frame Generation (prebuilt `1.77.2-lumina.11`, Filament patch `0013`): NGX `dlssg`
  driven directly on Vulkan. `DlssFrameGenerator` registers an external frame generator
  (`View::setExternalFrameGenerator`); `Renderer::endFrame` presents up to five generated frames before each rendered
  one, evenly spaced without vsync, for views rendered into a SwapChain. `DlssFrameGeneration.probe` reports
  availability and the multi-frame limit, `DlssFrameInterpolator` shows the generated frame for inspection,
  `FilamentRenderer.getPresentTimes` the present pacing. The `nvngx_dlssg` runtimes are pinned in
  `tool/dlss/manifest.txt`.
- DLSS Ray Reconstruction (`DlssRayReconstruction`, `src/dlss_rr_c.cpp`): NGX `dlssd` as an HDR-stage external upscaler
  fed by the guide buffers, denoising ReSTIR and ray-traced shadows while it upscales. `tool/dlss/manifest.txt` pins the
  `nvngx_dlssd` runtimes (fetched, never committed); NGX is shared with Super Resolution (`src/ngx_c.cpp`).
- Guide buffers (prebuilt `1.77.2-lumina.10`, Filament patch `0012`): `view.guideBufferOptions =
  GuideBufferOptions(enabled: true)` makes the lit shaders write world normal + roughness, diffuse and specular
  albedo as extra colour-pass outputs (Vulkan), and the specular hit distance is traced with ray queries.
  `ExternalUpscaler::guideBuffers()` hands them to an external upscaler (images 4-7); `GuideBufferReadback`
  copies one into a texture and reads it back. Recompile materials built before (the sky materials are).
- External post pass and Vulkan device features (prebuilt `1.77.2-lumina.9`, Filament patch `0011`): a hook
  for passes on the HDR frame after TAA / FSR3 and before bloom and colour grading (`View::setExternalPostPass`,
  colour, depth and an output-resolution motion image with a history-valid flag), an `HDR` stage for external
  upscalers, eight external-pass images, and Vulkan feature structures requested before engine creation
  (`VulkanFeatures.requestFeature`, `VulkanFeatures.isFeatureEnabled`). `DebugPostPass` is a compute-shader pass
  on the hook (passthrough, motion, history, invert).
- Web: lit shaders no longer sample the Vulkan-only ray query textures (prebuilt `1.77.2-lumina.8`, Filament
  patch `0010`). On OpenGL and WebGL a lit material with eight samplers and fog (the glTF ubershader) had 16
  active fragment samplers, and Chrome's GPU process crashed on it under ANGLE/Direct3D 11: the page went
  blank after `Link error in "…"`, `CONTEXT_LOST_WEBGL` and `RenderPass arena is full`. The ray-traced shadow
  fetch and the ReSTIR evaluation are now compiled for Vulkan only. Rebuild the web module and recompile
  materials compiled before.
- Linux arm64: the native hook links the bundled libc++ of the target architecture
  (`third_party/libcxx/usr/lib/aarch64-linux-gnu`), `tool/filament/build_prebuilt.sh` builds
  `filament-<VERSION>-linux-arm64.tar.gz` on an aarch64 host, and CI and the release workflow build
  Filament, Lumina Studio and the Linux packages on `ubuntu-24.04-arm` next to x64. DLSS stays x64 only.
- FSR3 upscaler and frame generation (prebuilt `1.77.2-lumina.7`, Filament patch `0009`):
  `TemporalAntiAliasingOptions.algorithm = TaaAlgorithm.fsr3` replaces Filament's TAA with a fragment-shader
  port of the FidelityFX Super Resolution 3.1 upscaler fed by the structure pass motion vectors (`upscaling`,
  `sharpness`, `lodBias`, `jitterPattern` apply), and `frameGeneration` presents an interpolated frame before
  each rendered one. `SwapChainConfig.disableVsync` presents without vertical sync (Vulkan, WGL). Every backend;
  an external upscaler (DLSS) takes precedence.
- ReSTIR direct lighting (prebuilt `1.77.2-lumina.6`, Filament patch `0008`): `RestirOptions` on the view
  replaces the froxel light loop with per-pixel reservoir resampling of all the scene's punctual lights
  (initial candidates, temporal and spatial reuse) and one ray-traced visibility ray per pixel; the cost is
  nearly independent of the light count and every light casts a hard shadow. `FilamentView.restirOptions`,
  `restirSupported`, `restirStats`, `resetRestirHistory()` and `FilamentLightManager.setRestirSamplingWeight`.
  Lumina's own GLSL implementation, Vulkan ray query only. The patch also fixes the vertical flip of the
  ray-traced shadow rays on Vulkan.
- `Dlss.runtimeDirectory` names the fetched NGX SDK (or its runtime folder) to look in first, ahead of
  `LUMINA_DLSS_DIR`, the executable folder and the working directory; Lumina Studio points it at the engine
  checkout's SDK folder at startup.
- Ray tracing foundation (prebuilt `1.77.2-lumina.5`, Filament patch `0007`): the Vulkan backend builds
  acceleration structures (`VK_KHR_ray_query`). `RayTracing.requestExtensions()` before the engine is created,
  `FilamentEngine.supportsRayQuery`, `FilamentScene.rayTracingEnabled` (a BLAS per primitive geometry and a TLAS
  over the scene rebuilt every frame, `tlasInstanceCount`, `lastTlasBuildTime`),
  `FilamentRenderableManager.setRayTracingVisible`, `ShadowOptions.rayTraced` (hard ray-traced sun shadows that
  replace the cascaded shadow maps when supported), `FilamentView.traceRay` and the test hook
  `FilamentScene.traceVisibility`. Post-process materials may declare `rayQuery : true` to trace rays
  themselves. Skinned and morphed renderables are traced in their bind pose for now. Other backends, GPUs
  without the extensions and the web report no support and render as before.
- DLSS Super Resolution (prebuilt `1.77.2-lumina.4`, Filament patch `0006`): `Dlss` renders a view at the
  resolution NVIDIA NGX picks for a `DlssQuality` and reconstructs the output through Filament's new external
  upscaler pass (`DynamicResolutionOptions.upscaler`). The NGX SDK is fetched by `tool/dlss/fetch_sdk.dart`
  (NVIDIA's licence, never committed); `Dlss.requestExtensions()` must run before the engine is created, and
  the view needs TAA with motion vectors on. Vulkan on NVIDIA GPUs only; everything else keeps FSR1.
- Motion vectors (prebuilt `1.77.2-lumina.3`, Filament patch `0004`): `TemporalAntiAliasingOptions.motionVectors`
  makes the structure pass render per-pixel screen motion (texels, x right, y up) from each renderable's previous
  world transform and the previous frame's camera; TAA reprojects its history with it. `FilamentView.motionVectorsSupported`,
  `FilamentView.motionVectorTexture` and `MotionVectorBuffer` export and read the buffer. Skinned and morphed renderables
  carry the pose of the previous frame too (bones and weights set through `RenderableManager`; a shared `SkinningBuffer`
  does not).
- Fixed: disposing an engine that still owned a view which had rendered shadows could crash the process
  (Filament patch `0005`: `Engine::shutdown` now terminates leaked views before it frees the cameras their shadow
  maps own and the disposer their TAA history returns to). It surfaced as a crash in `FilamentEngine.dispose()`
  after frames rendered with TAA.
- Filament upgraded to v1.77.2 (prebuilt `1.77.2-lumina.1`): Metal external image handles, correct
  Vulkan depth/stencil render-target format reporting. The material version stays 77. The prebuilt
  scripts re-apply the patches after a tag change (a forced checkout used to drop them silently).
- The WebAssembly module is built in CI (`.github/actions/filament-web`): `tool/web/build_host_tools.sh`
  exports Filament's host tools, the web scripts take `LUMINA_FILAMENT_SRC` (a patched source checkout,
  `tool/filament/build_prebuilt.sh --checkout-only`), `build_module.sh` reads the hook's current source and
  include lists again, and every release attaches `flutter-filament-web-<tag>.zip`.
- Filament upgraded to v1.77.0 (from a 1.75.0 release-candidate cut).
- `FilamentTransformManager.getTransformAt` implemented (new C function
  `filament_transform_manager_get_transform_i`); previously threw `UnimplementedError`.
- `FilamentAsset`: `renderableEntities`, `lightEntities`, `cameraEntities`, `resourceUris`
  (+ `*Count` getters) and `popRenderable()`.
- `Ktx1Bundle.getBlob`, `LinearImage.isValid`.
- `FilamentWidget.onFrame` callback reporting per-frame CPU and frame time.
- `filament_wireframe_set_color` is now declared in `src/gltf_c.h` so binding regeneration keeps it.
- Test fixtures (`blackjack_blender2.glb`, `attackhelicopter.entity.glb`, `YVO3D_44368.glb`) now live in `../test-assets/fixtures/`.
- Removed stray root binaries/scratch sources and the dead `flutter_filament_bindings_generated.dart` stub;
  README rewritten for the real package.

## 0.0.1 (2026-08-22)

- Initial import: engine, renderer, view, scene, entity/transform/renderable/light managers,
  materials and material instances, gltfio (asset loader, resource loader, animator, instances),
  image/ktx1/ktx2/imageio, IBL prefilter, camutils manipulators, editor primitives (gizmo, wireframe),
  smoke-report tooling with GPU 1 environment injection.
