# Filament patches

Lumina renders with [Google Filament](https://github.com/google/filament) at the
upstream tag **v1.77.2**, plus the patches in `patches/`. Nothing else in the
Filament tree is changed: the prebuilt archives the engine and the editor link
are upstream v1.77.2 with exactly these files applied in order.

| Patch | Touches | Why |
|---|---|---|
| `0001-libassimp-gltf2-replacedata-joint-bounds.patch` | `third_party/libassimp/code/glTF2/glTF2Asset.inl` | Memory-safety fix in the bundled Assimp's glTF 2 exporter. |
| `0002-ssr-skip-skinned-morphed.patch` | `filament/src/RenderPass.cpp` | Keeps skinned and morphed renderables out of the screen-space reflections pass, which otherwise loses the Vulkan device. |
| `0003-libwebp-wasm-no-webp-js.patch` | `third_party/libwebp/tnt/CMakeLists.txt` | Lets a WebAssembly build with WebP textures configure without SDL2. |
| `0004-velocity-buffer-motion-vectors.patch` | `filament/include/filament/{Options,View}.h`, `filament/src/{PostProcessManager,FrameHistory,View}.*`, `filament/src/details/{Renderer,Scene,View}.*`, `filament/src/ds/StructureDescriptorSet.*`, `filament/src/materials/antiAliasing/taa/taa.mat`, `libs/filabridge/.../UibStructs.h`, `libs/filamat/src/shaders/UibGenerator.cpp`, `shaders/src/surface_*` | Per-pixel motion vectors from the structure pass (`TemporalAntiAliasingOptions::motionVectors`), consumed by TAA and exportable through `View::setMotionVectorTexture`. |
| `0005-shutdown-terminates-views-before-cameras.patch` | `filament/src/details/Engine.cpp` | `Engine::shutdown` terminates leaked views before it frees the cameras their shadow maps own and the resource allocator disposer their frame history returns to; the upstream order reads freed memory and crashes `Engine::destroy`. |
| `0006-external-upscaler-pass.patch` | `filament/backend/include/backend/ExternalPass.h` (new), `backend/{DriverEnums.h,platforms/VulkanPlatform.h}`, `backend/src/vulkan/{VulkanDriver,VulkanTexture,platform/VulkanPlatform}.cpp`, the other drivers' no-ops, `filament/include/filament/{Options,View}.h`, `filament/src/{PostProcessManager,View}.*`, `filament/src/details/{Renderer,View}.*` | An external upscaler (DLSS) behind dynamic resolution: `DynamicResolutionOptions::upscaler`, `View::setExternalUpscaler`, the `externalPass` driver command that hands Vulkan images and the recording command buffer to a client callback, and client-requested Vulkan extensions. |
| `0008-restir-direct-lighting.patch` | `filament/include/filament/{Options,View,LightManager}.h`, `filament/src/{PostProcessManager,RendererUtils,FrameHistory}.*`, `filament/src/details/{Renderer,View}.*`, `filament/src/components/LightManager.*`, `filament/src/ds/ColorPassDescriptorSet.*`, `filament/src/materials/rt/restir*.mat` (new), `libs/filabridge` (bindings 14/15, `restirMode` uniform), `libs/filamat/src/shaders/{Sib,Uib}Generator.cpp`, `shaders/src/surface_light_punctual.fs` | ReSTIR direct lighting: `RestirOptions` on the view, a per-frame light buffer texture of every punctual light, candidate / temporal / spatial resampling and visibility passes as ray query materials, and the lit shaders shading the one resampled light; also fixes the vertical flip of the ray query materials' depth reconstruction. |
| `0007-vulkan-ray-query.patch` | `filament/backend/include/backend/AccelerationStructure.h` (new), `backend/src/vulkan/VulkanAccelerationStructure.*` (new), `backend/{DriverEnums.h,Handle.h,private/backend/{Driver.h,DriverAPI.inc}}`, the Vulkan driver, context, platform, handles, buffer and descriptor-set caches, the other drivers' no-ops, `filament/include/filament/{Engine,LightManager,RenderableManager,Scene,View}.h`, `filament/src/{PostProcessManager,RenderPrimitive,RendererUtils,MaterialParser,MaterialDefinition}.*`, `filament/src/details/{Renderer,Scene,View,VertexBuffer,IndexBuffer,Engine}.*`, `filament/src/ds/*`, `filament/src/materials/rt/` (new), `libs/filabridge` (binding points, chunk type), `libs/filamat` (the `rayQuery` material flag, GLSL 460 + `GL_EXT_ray_query`, SPIR-V 1.4), `shaders/src/surface_light_directional.fs`, `third_party/smol-v/source/smolv.cpp` | Vulkan ray query: acceleration structures as backend objects, a per-scene BLAS/TLAS kept by `Scene::setRayTracingEnabled`, hard ray-traced sun shadows (`ShadowOptions::rayTraced`) and single-ray visibility queries (`View::traceRay`). |
| `0009-fsr3-upscaler-frame-generation.patch` | `filament/include/filament/{Options,SwapChain}.h`, `filament/src/{PostProcessManager,FrameHistory}.*`, `filament/src/details/{Renderer,View,SwapChain}.*`, `filament/src/materials/fsr3/*` (new), `filament/CMakeLists.txt`, `backend/DriverEnums.h`, `backend/src/vulkan/platform/VulkanPlatformSwapChainImpl.*`, `backend/{include/backend/platforms/PlatformWGL.h,src/opengl/platforms/PlatformWGL.cpp}` | The FidelityFX Super Resolution 3.1 upscaler and frame generation as fragment passes (`TemporalAntiAliasingOptions::algorithm`, `frameGeneration`), fed by the structure pass motion vectors of 0004, and the `SwapChain::CONFIG_DISABLE_VSYNC` flag (Vulkan, WGL). FidelityFX SDK shader code is MIT licensed (AMD). |
| `0010-ray-query-samplers-vulkan-only.patch` | `shaders/src/surface_light_{directional,punctual}.fs` | The ray-traced shadow fetch of 0007 and the ReSTIR light evaluation of 0008 are compiled for Vulkan only, so OpenGL and WebGL lit shaders spend no fragment sampler on them (Chrome's ANGLE/Direct3D 11 crashed on a 16th). |
| `0011-external-post-pass-and-device-features.patch` | `backend/include/backend/{ExternalPass.h,platforms/VulkanPlatform.h}`, `backend/src/vulkan/platform/VulkanPlatform.cpp`, `filament/include/filament/View.h`, `filament/src/{PostProcessManager,FrameHistory,View}.*`, `filament/src/details/{Renderer,View}.*`, `filament/src/materials/rt/{postPassMotion.mat (new),rt.*}`, `filament/CMakeLists.txt` | An external post pass on the HDR frame before colour grading (`View::setExternalPostPass`) with output-resolution motion and a history-valid flag, an `HDR` stage for external upscalers, eight external-pass images, and client-requested Vulkan device feature structures (`Customization::extraDeviceFeatures`). |
| `0012-guide-buffers.patch` | `filament/include/filament/{Options,View}.h`, `filament/src/{RendererUtils,PostProcessManager,View}.*`, `filament/src/details/{Renderer,View}.*`, `filament/src/materials/rt/{rtSpecularHitDistance.mat (new),rt.cpp}`, `filament/CMakeLists.txt`, `shaders/src/surface_main.fs` | Guide buffers for neural denoisers: normal + roughness, diffuse and specular albedo written by the lit shaders as colour attachments 1-3 (Vulkan), the ray-traced specular hit distance, `View::setGuideBufferOptions` / `setGuideBufferTexture`, and `ExternalUpscaler::guideBuffers()`. |

## 0001: libassimp glTF 2 `ReplaceData_joint` bounds

`glTF2::Buffer::ReplaceData_joint` is what the glTF 2 exporter uses to rewrite
the joint indices of skinned meshes. Upstream it allocates exactly the new
byte length and always copies the tail that follows the replaced range. When
the replacement reaches the end of the buffer, that tail length
(`new_size - (offset + count)`) is zero or wraps around, and the copy runs
past both buffers. It also shrinks the buffer's storage below the capacity it
records, which later appends rely on.

The patch allocates `max(capacity, new size)`, keeps that as the capacity, and
copies the tail only when there is one. `flutter_assimp` compiles the glTF 2
exporter against these sources and links the Assimp library of this build, so
the fix covers both.

## 0002: skinned and morphed renderables in the SSR pass

The screen-space reflections pass renders with Filament's special SSR variant
(`MNT|PCK|DEP`). That variant cannot carry the skinning bit, because the SSR
mask includes it: calling `setSkinning()` on the SSR variant of a skinned or
morphed renderable produces `MNT|PCK|DEP|SKN`, which Filament resolves as a
depth/picking variant. That program matches neither the SSR pass's render
target nor its per-view descriptor-set layout. OpenGL tolerates it; Vulkan
loses the device (`vkGetQueryPoolResults` returns `VK_ERROR_DEVICE_LOST`).

With the patch, skinned and morphed renderables emit sentinel commands in the
SSR pass only, the same path Filament already takes for a primitive without a
material instance. They are still drawn normally in every other pass; they just
do not appear in screen-space reflections until Filament gains SSR skinning
variants.

## 0003: libwebp for WebAssembly without `webp.js`

Filament's wrapper around libwebp forces `WEBP_BUILD_WEBP_JS` on for WASM
builds. `webp.js` is libwebp's demo viewer and requires SDL2
(`find_package(SDL2 REQUIRED)`), so configuring a WebAssembly build with
`FILAMENT_SUPPORTS_WEBP_TEXTURES=ON` fails. Filament only links the
`webpdecoder` library, so the patch turns the demo off. It matters for
`flutter_filament`'s web module, which loads glTF assets that use
`EXT_texture_webp`; desktop builds are unaffected.

## 0004: motion vectors from the structure pass

Filament's TAA reprojects its history with one camera matrix, which is only right for a
still scene under a moving camera. With `TemporalAntiAliasingOptions::motionVectors` the
structure pass (now at full resolution) also renders a velocity buffer: the picking
variant of every material gets a second colour output, `outVelocity` (RG16F, texels of
screen motion since the previous frame, x right and y up), computed from a new
`vertex_prevPosition` varying. That varying comes from the renderable's previous world
transform (`PerRenderableData::prevWorldFromModelMatrix`, kept per entity by `FScene`
and advanced once per renderer frame) and the previous frame's unjittered
`clipFromWorld` (`PerViewUib::prevClipFromWorldMatrix`, kept in the view's frame
history). Both fields live in space the UBOs reserved, so their layout and
`MATERIAL_VERSION` are unchanged; materials compiled before this patch still load and
simply write no velocity. Skinned and morphed renderables also keep the pose the previous
frame rendered with: `FRenderableManager` shadows each owned bone palette and weight set on
the CPU, and the first `setBones` / `setMorphWeights` of a frame (the renderer advances a
motion-frame counter in `endFrame`) uploads that copy into a second buffer bound as
`PrevBonesUniforms` / `PrevMorphingUniforms` (per-renderable bindings 6 and 7, emitted for
the skinning variants). A renderable not updated in a frame binds its current pose as the
previous one (no motion); a shared `SkinningBuffer` has no previous palette. Custom vertex
displacement is not captured. The TAA material
samples the velocity buffer (`useVelocity` constant) instead of reprojecting by matrix,
and `View::setMotionVectorTexture` renders the buffer into a user texture of the render
target's size for upscalers and tests.

## 0008: ReSTIR direct lighting

Filament evaluates every punctual light overlapping a pixel's froxel, capped at 256 lights. This patch
adds `RestirOptions` (`View::setRestirOptions`, `getRestirStats`, `isRestirSupported`,
`resetRestirHistory`; `LightManager::setRestirSamplingWeight`). When enabled on a device with ray queries
and a scene that keeps its acceleration structures, `FView::prepareRestirLights` packs every point and spot
light of the scene into an RGBA32F texture (four texels per light) before the froxel culling shrinks the
list, and `PostProcessManager::restir` runs three `rayQuery` post-process materials over the structure
depth: `restirCandidates` (uniform candidates weighted by the unshadowed diffuse contribution, merged with
the previous frame's reservoir at the reprojected position, history bounded by `maxHistory`),
`restirSpatial` (neighbour reservoirs re-evaluated at the pixel) and `restirShade` (one visibility ray into
the TLAS). The reservoirs after reuse are kept in the frame history. The colour pass binds the shading
result and the light texture at per-view bindings 14 and 15 and sets `restirMode` (the former
`reservedLight0` uniform); `surface_light_punctual.fs` then shades that single light with the material's
BRDF, weighted by W, instead of looping over the froxel. Transparent surfaces keep the froxel loop. The
patch also fixes the ray query materials' depth reconstruction, which mirrored Y on Vulkan (window y grows
downwards). The implementation is Lumina's own GLSL; it contains no RTXDI SDK code.

## 0009: FSR3 upscaler and frame generation

Filament's only temporal upscaler is its own TAA (`TemporalAntiAliasingOptions::upscaling`). This patch
adds `TemporalAntiAliasingOptions::algorithm` (`FILAMENT` or `FSR3`) and `frameGeneration`. With `FSR3`
the renderer forces the structure pass motion vectors of patch 0004 and `PostProcessManager::fsr3`
replaces the TAA pass with a port of the AMD FidelityFX Super Resolution 3.1 upscaler to Filament
post-process materials (`filament/src/materials/fsr3/`): `prepare_inputs` converts the texel-space
velocity into the FSR UV motion the SDK expects (camera reprojection where no motion vector was
written), then `prepare_reactivity`, `shading_change`, `luma_diff`, `luma_instability`, `reduce` and
`accumulate` run as fragment passes instead of compute shaders, so the upscaler works on every backend
and feature level 1 (no stereo). `upscaling`, `sharpness` (RCAS), `lodBias` and `jitterPattern` apply;
the dilated depth, motion, reactive mask, luma history and accumulation are kept in the frame history.
`frameGeneration` interpolates a frame between the previous and the current accumulated output
(`fsr3_frame_interpolation`) and presents it before the rendered frame (`Renderer::endFrame`), doubling
the presented rate at half a frame of latency; the view must render into the swap chain without guard
band. `SwapChain::CONFIG_DISABLE_VSYNC` (Vulkan: `VK_PRESENT_MODE_IMMEDIATE_KHR`, WGL:
`wglSwapIntervalEXT(0)`) presents without vertical sync; with frame generation the renderer paces the
two presents. An external upscaler (patch 0006, DLSS) takes precedence. The shader code is derived from
the FidelityFX SDK v1.1.4, MIT licensed, copyright Advanced Micro Devices; the licence header is kept
in `fsr3_common.fs`.
The patch also completes patch 0007 for clang's `-Werror` build on Linux and WebAssembly: the
`ACCELERATION_STRUCTURE` descriptor type in `to_string`, the matdbg writer and the Vulkan resource
manager's destroy switch, and a `struct` forward declaration of `VulkanContext`.
It also completes patch 0004 for feature level 0 (the WebAssembly / GLES 2.0 build): the vertex shaders
read the velocity uniforms only when `MATERIAL_FEATURE_LEVEL > 0`, since feature level 0 has no motion
vectors and its uniform block omits them.

## Working with the patches

The patches are `git format-patch` output against the v1.77.2 tag, and apply
with either `git apply` or `git am`:

```bash
git clone --depth 1 --branch v1.77.2 https://github.com/google/filament.git
cd filament
git apply ../lumina/third_party/filament/patches/*.patch
```

`tool/filament/build_prebuilt.sh` (Linux, macOS prepared) and
`tool/filament/build_prebuilt.ps1` (Windows) do this, build the static
libraries the native-assets hooks link, and pack them into the archives each
Lumina release carries. To change a patch or add one:

1. Apply the existing patches to a clean v1.77.2 checkout and commit them
   there (`git am patches/*.patch`).
2. Make the change as a new commit, or amend the commit it belongs to.
3. Regenerate the series with
   `git format-patch --zero-commit --no-signature --no-stat -o <this folder> v1.77.2`
   and give the new files short, descriptive names in the same `NNNN-` order.
4. Bump the suffix in `tool/filament/VERSION` (`1.77.2-lumina.N`), so that
   the release publishes a new archive and installed editors download it.

Moving to a newer Filament release means rebasing the series onto the new tag,
dropping patches that upstream has absorbed, and setting `tool/filament/VERSION`
to `<new version>-lumina.1`.

## 0005: `Engine::shutdown` terminates views before cameras and the disposer

`FEngine::shutdown` frees the camera components (`mCameraManager.terminate`) and resets the
resource allocator disposer before it cleans up the objects the application did not destroy,
among them the views. `FView::terminate` needs both: a view that rendered shadows owns a
`ShadowMapManager` whose `ShadowMap`s hold two `FCamera` pointers each and destroy them in
`ShadowMap::terminate`, and `clearFrameHistory` returns the TAA / SSR history textures
through `getResourceAllocatorDisposer()`. By then the cameras are freed and the disposer is
null, so the teardown reads freed memory and `Engine::destroy` crashes whenever the heap
reused it (reliably after a few dozen TAA frames). The patch moves `mCameraManager.terminate`
and the disposer's `terminate` / `reset` after `cleanupResourceList(mViews)`; nothing in
between uses either.

## 0006: an external upscaler pass (DLSS)

Filament upscales a dynamically scaled frame with its own bilinear, SGSR1 or FSR1 passes.
This patch lets a library outside Filament do it instead. `DynamicResolutionOptions::upscaler`
(`BUILTIN` or `EXTERNAL`, in padding so the struct keeps its size) selects the
`ExternalUpscaler` registered with `View::setExternalUpscaler()`. When it is active the
renderer still jitters the camera as for TAA (`TemporalAntiAliasingOptions` must be on, with
`motionVectors` for the velocity buffer of patch 0004) but skips the TAA resolve, and
`PostProcessManager::upscaleExternal()` adds a side-effect frame-graph pass that issues the
new `DriverApi::externalPass` command with the low-resolution colour, depth and motion vectors
and a full-resolution storage output (`TextureUsage::STORAGE` maps to
`VK_IMAGE_USAGE_STORAGE_BIT`). The Vulkan driver transitions the four images to the general
layout, fills an `ExternalPassContext` (instance, physical device, device, the recording
`VkCommandBuffer`, each image's `VkImage` / `VkImageView` / format / extent, the frame's jitter
and sizes) and calls the client's callback on the backend thread; a memory barrier follows the
callback. The other backends log once and skip the pass, so the renderer's `supports()` check
makes Filament fall back to FSR1 there. `VulkanPlatform::Customization` grows
`extraInstanceExtensions` / `extraDeviceExtensions` (skipped with a log line when unavailable),
and `VK_KHR_buffer_device_address` enables its feature when requested: NGX needs both before
the device exists. The DLSS code itself lives in `flutter_filament` (`src/dlss_c.cpp`).

## 0007: Vulkan ray query

Filament has no notion of ray tracing. This patch adds the smallest foundation that lets
fragment shaders trace rays against the scene on Vulkan (`VK_KHR_acceleration_structure`,
`VK_KHR_ray_query`, `VK_KHR_buffer_device_address`), while every other backend and every
device without the extensions behaves exactly as before.

- **Backend.** `HwAccelerationStructure` is a new handle type with the driver commands
  `createAccelerationStructureBlas` (one triangle geometry described by
  `AccelerationStructureGeometry`: a position attribute inside a buffer object and an optional
  index buffer), `createAccelerationStructureTlas(capacity)`, `updateTlasInstances` (an array
  of `AccelerationStructureInstance`: 3x4 transform, custom index, mask, BLAS handle),
  `buildAccelerationStructure(BUILD | REFIT)`, `destroyAccelerationStructure`,
  `updateDescriptorSetAccelerationStructure` for the new `DescriptorType::ACCELERATION_STRUCTURE`
  and the query `isRayQuerySupported()`. The Vulkan platform requests the three extensions and
  chains their feature structs when the device offers them; the allocator is created with
  buffer device addresses, and vertex / index buffers get the
  `SHADER_DEVICE_ADDRESS` and `ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY` usages.
  `VulkanAccelerationStructure` owns the structure, its storage and scratch buffers and records
  the build with the required memory barriers. The other drivers implement the commands as
  no-ops and report no support.
- **Materials.** A post-process material declares `rayQuery : true` (stored in the new
  `MAT_RAYQ` chunk) to be compiled as GLSL 460 with `GL_EXT_ray_query` for SPIR-V 1.4 on Vulkan
  only, with `layout(set = 0, binding = 13) uniform accelerationStructureEXT sceneTlas` from the
  per-view set (`PerViewBindingPoints::TLAS`). Such a material renders with the ray-query
  post-process descriptor-set layout (frame uniforms + TLAS), selected by
  `MaterialDefinition::hasRayQuery` (the `MAT_RAYQ` chunk is written for every material domain).
  The Vulkan 1.1 device Filament creates has no core 1.2 entry points, so buffer addresses come
  from `vkGetBufferDeviceAddressKHR`. Such shaders are SPIR-V 1.4, so the bundled smol-v
  compressor accepts module headers up to 1.6 (the ray query opcodes it does not know are
  stored as plain operand words). Lit surface shaders gain the `sampler0_rtShadow` sampler
  (`PerViewBindingPoints::RT_SHADOW`); `surface_light_directional.fs` multiplies the sun's
  visibility by it when bit 2 of `directionalShadows` is set.
- **Engine.** `Engine::isRayQuerySupported()`. `Scene::setRayTracingEnabled()` makes
  `FScene::updateAccelerationStructures` run at the start of every frame the scene renders
  (from `FRenderer::renderJob`): one BLAS per distinct primitive geometry (vertex buffer,
  index buffer, offset, count; built once, dropped after 120 unused frames) and a TLAS over
  every renderable of the scene with `RenderableManager::isRayTracingVisible()` (default true,
  `setRayTracingVisible(false)` removes one), rebuilt every frame from the current world
  transforms with the instance custom index pointing back at the entity. The TLAS capacity
  doubles when it runs out; a timer query measures the build
  (`Scene::getLastTlasBuildTimeNanos`, `Scene::getTlasInstanceCount`). Skinned and morphed
  renderables are traced in their bind pose, since the backend has no compute path to
  deform them yet.
- **Ray-traced sun shadows.** `LightManager::ShadowOptions::rayTraced` (after `lispsm`, no
  layout change) replaces the directional cascades: `FView::prepareShadowing` skips the
  shadow map when the device and scene support it, the structure pass runs at full
  resolution (a view whose only shadows are ray-traced has no shadow map manager, and its
  shadow uniforms stay the dummy buffer), and `PostProcessManager::rayTracedShadows` renders the built-in `rtShadow`
  material into an R8 visibility mask (one ray per pixel from the structure depth toward the
  light, with a distance-scaled bias) that the colour pass binds as `sampler0_rtShadow`. Point
  and spot shadows keep their shadow maps.
- **Ray queries.** `View::traceRay(origin, direction, maxDistance, callback)` queues a query
  like `View::pick`. The next frame renders the built-in `rayVisibility` material into a 1x1
  RGBA32F target and reads it back; the callback receives `RayQueryResult{hit, distance,
  renderable, primitive}`. Without support the queries are answered with no hit.

## 0010: ray query textures only in Vulkan shaders

0007 and 0008 made every lit shader sample `sampler0_rtShadow` (when bit 2 of
`directionalShadows` is set) and the ReSTIR reservoir and light textures (when
`restirMode` is on), for every target API. Ray query exists only on Vulkan, so on
OpenGL, OpenGL ES and WebGL those textures are always placeholders, yet each fetch
keeps its sampler active. On feature level 1 a lit material with eight samplers (the
glTF ubershader) plus fog then has 16 active fragment samplers instead of upstream's 15,
and Chrome's GPU process crashes on that program under ANGLE's Direct3D 11 backend (the
default on Windows): every WebGL context of the page is lost, the next program's link
status reads as failed with an empty log, and the page goes blank. Any 15 of the 16 draw.

The patch wraps the ray-traced shadow fetch in `surface_light_directional.fs` and the
ReSTIR evaluation (`evaluateRestirLight` and its call) in `surface_light_punctual.fs` in
`#if defined(TARGET_VULKAN_ENVIRONMENT)`. The per-view declarations stay, so the
descriptor-set layouts and `MATERIAL_VERSION` are unchanged; on the other APIs the unused
samplers are inactive. Materials compiled before the patch keep sampling the placeholder
until they are rebuilt.
## 0011: external post pass, HDR-stage upscalers and device feature structures

Patch 0006 lets a library outside Filament upscale the LDR frame after colour grading. Neural
passes (a denoiser, a learned post-process, a neural rendering network) need the frame earlier:
anti-aliased or upscaled but still linear HDR, with depth and motion at that resolution.
`View::setExternalPostPass(ExternalPostPass*)` registers such a pass; the renderer calls it after
the TAA or FSR3 resolve and before depth of field, bloom and colour grading, on Vulkan only.
`PostProcessManager::externalPostPass` first renders the `postPassMotion` material (Vulkan-only
resources next to the ray query materials) into an RGBA16F motion image at the colour's size: the
velocity buffer of patch 0004 rescaled, or, where it has nothing (motion vectors off, the sky),
the surface the jittered depth describes projected by this and the previous frame's unjittered
cameras (`FrameHistoryEntry::postPass`); `b` flags a previous position on screen, `a` the sky.
It then issues `externalPass` with colour, depth, motion and an RGBA16F storage output that
replaces the colour. `View::resetExternalPostPassHistory()` reports no usable history for one
frame. `ExternalPassFrame` gains the exposure, the view and unjittered projection matrices and
two flags; `ExternalPassContext::MAX_IMAGES` grows from 4 to 8 for guide images.
`ExternalUpscaler::stage()` (default `DISPLAY`, the 0006 behaviour) can return `HDR`: the
upscaler then replaces the TAA resolve on the linear frame, writes RGBA16F at the output
resolution, and bloom and colour grading run unscaled after it.
`VulkanPlatform::Customization::extraDeviceFeatures` lists feature structures (sType, size,
extension, byte offsets of requested `VkBool32` members). Filament queries each through
`vkGetPhysicalDeviceFeatures2`, enables the requested members the device supports and chains
the structure, skipping (with a log line) unsupported members, structures whose extension is not
enabled and structure types it already chains; `isExtraDeviceFeatureEnabled` and
`isDeviceExtensionEnabled` report the result. Colour grading as a subpass is disabled while an
external post pass is registered.

## 0012: guide buffers

Neural denoisers (DLSS Ray Reconstruction) need per-pixel guides a forward renderer does not keep.
`GuideBufferOptions` on the view (`View::setGuideBufferOptions`) turns them on for single-sampled
views on Vulkan: `PostProcessManager::clearGuideBuffers` creates three zero-cleared targets
(normal + roughness RGBA16F, diffuse albedo RGBA8, specular albedo RGBA8) and the colour pass binds
them as attachments 1-3 (`RendererUtils::ColorPassConfig::guideBuffers`, also across the split
opaque / transparent passes of screen-space refraction; the colour pass then always renders into an
intermediate target). `surface_main.fs` declares the three outputs for `TARGET_VULKAN_ENVIRONMENT` only
and writes them after `evaluateMaterial()`: `shading_normal` and the perceptual roughness,
`baseColor * (1 - metallic)`, and `mix(dfg.x, dfg.y, F0)` from `prefilteredDFG` (specular-glossiness and
cloth materials map their inputs); unlit surfaces and the screen-space reflection variant write zero,
blended surfaces zero (multiply-blended one) so the opaque guides survive their blend. With ray tracing
on the scene, `PostProcessManager::specularHitDistance` renders the built-in `rtSpecularHitDistance`
ray query material (one mirror ray per pixel from the depth and the normal guide) into R16F.
`ExternalUpscaler::guideBuffers()` asks for guides by `GuideBuffer` bit; they arrive as external-pass
images 4-7. `View::setGuideBufferTexture` blits a guide into a user texture of the same size and format.
OpenGL, Metal, WebGPU and WebGL compile no extra outputs, so their sampler and output budgets are
unchanged.
