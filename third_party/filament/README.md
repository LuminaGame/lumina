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
