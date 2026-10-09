[Türkçe](../../tr/lumina/materials-and-post-process.md)

# Materials and post-processing

The engine-level material API (materials, material instances, dynamic material instances and the material cache) and the post-processing stack: post-process settings and controller, scalability profiles and shadow settings. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/post_process/post_process_controller.dart`](#libsrcpost_processpost_process_controllerdart)
- [`lib/src/post_process/post_process_settings.dart`](#libsrcpost_processpost_process_settingsdart)
- [`lib/src/post_process/scalability_profile.dart`](#libsrcpost_processscalability_profiledart)
- [`lib/src/post_process/shadow_settings.dart`](#libsrcpost_processshadow_settingsdart)
- [`lib/src/material/dynamic_material_instance.dart`](#libsrcmaterialdynamic_material_instancedart)
- [`lib/src/material/lumina_material.dart`](#libsrcmateriallumina_materialdart)
- [`lib/src/material/lumina_material_instance.dart`](#libsrcmateriallumina_material_instancedart)
- [`lib/src/material/material_cache.dart`](#libsrcmaterialmaterial_cachedart)
- [`lib/src/post_process/post_process_blender.dart`](#libsrcpost_processpost_process_blenderdart)

## `lib/src/post_process/post_process_controller.dart`

### `class LuminaPostProcessController`

World-owned controller that diffs and applies [LuminaPostProcessSettings] and [LuminaShadowSettings] to a bound [FilamentView].  Diffs option families to minimize native FFI traffic and avoids rebuilding the expensive 3D LUT [ColorGrading] object unless color grading properties actually changed.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | Holds the `world` property or configuration state. |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `view` | `FilamentView view` | Holds the `view` property or configuration state. |
| `applied` | `LuminaPostProcessSettings get applied` | The currently applied post-process settings, or standard defaults if not yet explicitly applied. |
| `appliedShadows` | `LuminaShadowSettings get appliedShadows` | The currently applied shadow settings, or default shadow settings if not yet explicitly applied. |
| `apply` | `void apply(LuminaPostProcessSettings settings)` | Applies the given [settings] to the view, diffing each option family against the previous state. |
| `readBack` | `LuminaPostProcessSettings readBack()` | Reconstructs a [LuminaPostProcessSettings] object by querying the live [FilamentView] getters. |
| `notifyCameraCut` | `void notifyCameraCut()` | Clears temporal anti-aliasing and SSR frame history (e.g. upon camera teleportation). |
| `dispose` | `void dispose()` | Releases resources held by this controller. |

## `lib/src/post_process/post_process_settings.dart`

### `class LuminaColorGradeSettings`

Immutable configuration for the Filament color grading pipeline and tone mapping.

**Constructors:**
- `LuminaColorGradeSettings.defaults() : this._()`: Initializes `LuminaColorGradeSettings.defaults() : this._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toneMapper` | `ToneMapperType toneMapper` | Holds the `toneMapper` property or configuration state. |
| `agxLook` | `AgxLook agxLook` | Holds the `agxLook` property or configuration state. |
| `genericContrast` | `double genericContrast` | Holds the `genericContrast` property or configuration state. |
| `genericMidGrayIn` | `double genericMidGrayIn` | Holds the `genericMidGrayIn` property or configuration state. |
| `genericMidGrayOut` | `double genericMidGrayOut` | Holds the `genericMidGrayOut` property or configuration state. |
| `genericHdrMax` | `double genericHdrMax` | Holds the `genericHdrMax` property or configuration state. |
| `quality` | `ColorGradingQuality quality` | Holds the `quality` property or configuration state. |
| `format` | `LutFormat format` | Holds the `format` property or configuration state. |
| `lutDimensions` | `int lutDimensions` | Holds the `lutDimensions` property or configuration state. |
| `exposure` | `double exposure` | Holds the `exposure` property or configuration state. |
| `nightAdaptation` | `double nightAdaptation` | Holds the `nightAdaptation` property or configuration state. |
| `contrast` | `double contrast` | Holds the `contrast` property or configuration state. |
| `vibrance` | `double vibrance` | Holds the `vibrance` property or configuration state. |
| `saturation` | `double saturation` | Holds the `saturation` property or configuration state. |
| `luminanceScaling` | `bool luminanceScaling` | Holds the `luminanceScaling` property or configuration state. |
| `gamutMapping` | `bool gamutMapping` | Holds the `gamutMapping` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

### `class LuminaPostProcessSettings`

Immutable value object holding the entire per-view post-process pipeline configuration.

**Constructors:**
- `LuminaPostProcessSettings.standard()`: Factory for standard default settings matching Filament baseline with ACES Legacy.
- `LuminaPostProcessSettings.none()`: Factory for minimal settings with post processing disabled and linear tone mapper.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bloom` | `BloomOptions bloom` | Holds the `bloom` property or configuration state. |
| `depthOfField` | `DepthOfFieldOptions depthOfField` | Holds the `depthOfField` property or configuration state. |
| `vignette` | `VignetteOptions vignette` | Holds the `vignette` property or configuration state. |
| `fog` | `FogOptions fog` | Holds the `fog` property or configuration state. |
| `ambientOcclusion` | `AmbientOcclusionOptions ambientOcclusion` | Holds the `ambientOcclusion` property or configuration state. |
| `taa` | `TemporalAntiAliasingOptions taa` | Holds the `taa` property or configuration state. |
| `msaa` | `MultiSampleAntiAliasingOptions msaa` | Holds the `msaa` property or configuration state. |
| `screenSpaceReflections` | `ScreenSpaceReflectionsOptions screenSpaceReflections` | Holds the `screenSpaceReflections` property or configuration state. |
| `guardBand` | `GuardBandOptions guardBand` | Holds the `guardBand` property or configuration state. |
| `dynamicResolution` | `DynamicResolutionOptions dynamicResolution` | Holds the `dynamicResolution` property or configuration state. |
| `renderQuality` | `RenderQuality renderQuality` | Holds the `renderQuality` property or configuration state. |
| `dithering` | `Dithering dithering` | Holds the `dithering` property or configuration state. |
| `antiAliasing` | `AntiAliasing antiAliasing` | Holds the `antiAliasing` property or configuration state. |
| `postProcessingEnabled` | `bool postProcessingEnabled` | Holds the `postProcessingEnabled` property or configuration state. |
| `colorGrade` | `LuminaColorGradeSettings colorGrade` | Holds the `colorGrade` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

## `lib/src/post_process/scalability_profile.dart`

### `class LuminaScalabilityProfile`

Bundled engine scalability profile governing shadows, quality buffers, and anti-aliasing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shadows` | `LuminaShadowSettings shadows` | Holds the `shadows` property or configuration state. |
| `renderQuality` | `RenderQuality renderQuality` | Holds the `renderQuality` property or configuration state. |
| `dynamicResolution` | `DynamicResolutionOptions dynamicResolution` | Holds the `dynamicResolution` property or configuration state. |
| `taa` | `TemporalAntiAliasingOptions taa` | Holds the `taa` property or configuration state. |
| `msaa` | `MultiSampleAntiAliasingOptions msaa` | Holds the `msaa` property or configuration state. |
| `antiAliasing` | `AntiAliasing antiAliasing` | Holds the `antiAliasing` property or configuration state. |
| `forPreset` | `static LuminaScalabilityProfile forPreset(String preset)` | The profile behind a preset name as the editor and the project manifest spell it (`Low`, `Medium`, `High`, `Epic`, `Cinematic`); anything unrecognised falls back to [epic], which is the manifest default. |
| `withResolutionScale` | `LuminaScalabilityProfile withResolutionScale(double percent)` | This profile rendered at [percent] of the view's resolution.  100 % returns the profile unchanged. Anything else pins Filament's dynamic-resolution scaler to that fixed factor — it is the only knob that changes the internal render resolution without resizing the surface. The value is clamped to 25–200 %. |
| `applyToView` | `void applyToView(FilamentView view)` | Writes the view-level half of this profile into [view].  Shadows are deliberately not written here: they live on the scene's directional light, so they go through `LuminaWorld.applyScalability` / `LuminaPostProcessController.applyShadowSettings`, which have the light and the camera clip planes to work with. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

## `lib/src/post_process/shadow_settings.dart`

### `enum CsmSplitMode`

Calculation scheme for cascaded shadow map (CSM) split planes.

### `class LuminaShadowSettings`

Immutable configuration for directional sun shadows and cascaded shadow maps.

**Constructors:**
- `LuminaShadowSettings.defaults() : this._()`: Initializes `LuminaShadowSettings.defaults() : this._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shadowType` | `ShadowType shadowType` | Holds the `shadowType` property or configuration state. |
| `vsm` | `VsmShadowOptions vsm` | Holds the `vsm` property or configuration state. |
| `soft` | `SoftShadowOptions soft` | Holds the `soft` property or configuration state. |
| `mapSize` | `int mapSize` | Holds the `mapSize` property or configuration state. |
| `cascades` | `int cascades` | Holds the `cascades` property or configuration state. |
| `splitMode` | `CsmSplitMode splitMode` | Holds the `splitMode` property or configuration state. |
| `practicalLambda` | `double practicalLambda` | Holds the `practicalLambda` property or configuration state. |
| `shadowFar` | `double shadowFar` | Holds the `shadowFar` property or configuration state. |
| `stable` | `bool stable` | Holds the `stable` property or configuration state. |
| `screenSpaceContactShadows` | `bool screenSpaceContactShadows` | Holds the `screenSpaceContactShadows` property or configuration state. |
| `contactShadowsStepCount` | `int contactShadowsStepCount` | Holds the `contactShadowsStepCount` property or configuration state. |
| `constantBias` | `double constantBias` | Holds the `constantBias` property or configuration state. |
| `normalBias` | `double normalBias` | Holds the `normalBias` property or configuration state. |
| `rayTraced` | `bool rayTraced` | Trace the directional light's shadows against the scene's acceleration structures instead of rendering the cascades (ray query support and a scene with ray tracing enabled; falls back to the maps otherwise). Default false. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

## `lib/src/post_process/rtx_settings.dart`

### `class LuminaRayTracingSettings`

Hardware ray tracing for a view: the scene's acceleration structures, ray-traced sun shadows and ReSTIR direct lighting of the punctual lights. Needs a Vulkan engine created after `LuminaRtxController.requestExtensions` on a GPU with ray query support; otherwise the settings are kept and the shadow maps and the froxel light loop render.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | Keep the scene's acceleration structures (the switch for everything below). Default false. |
| `sunShadows` | `bool sunShadows` | Ray-traced hard shadows for the directional light instead of cascaded shadow maps. Default true. |
| `restir` | `bool restir` | Shade the punctual lights with ReSTIR direct lighting instead of the froxel loop. Default false. |
| `restirCandidates` | `int restirCandidates` | Lights sampled per pixel and frame (1 to 64). Default 8. |
| `restirSpatialSamples` | `int restirSpatialSamples` | Neighbouring reservoirs merged per pixel (0 to 8). Default 2. |
| `restirOptions` | `RestirOptions get restirOptions` | The Filament ReSTIR options these settings describe. |
| `copyWith`, `toMap`, `fromMap` | | Value semantics and the JSON form the editor stores. |

### `class LuminaDlssSettings`

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | DLSS Super Resolution on the view. Default false. |
| `quality` | `DlssQuality quality` | The NGX quality mode. Default `balanced`. |
| `rayReconstruction` | `bool rayReconstruction` | DLSS Ray Reconstruction (`DlssRayReconstruction`, the transformer model) instead of Super Resolution: also denoises the ray-traced lighting, fed by the view's guide buffers. Its output is the view's viewport (the chosen screen resolution in borderless fullscreen) and it renders at the quality scale of that; a resize recreates it on the next apply. Default false; JSON key `ray_reconstruction`. |
| `copyWith`, `toMap`, `fromMap` | | Value semantics and the JSON form the editor stores. |

### `enum LuminaFsr3Quality`

`nativeAA` (1.0), `quality` (1.5), `balanced` (1.7), `performance` (2.0), `ultraPerformance` (3.0): the FSR3 upscaling ratio per axis (`scale`); the view renders at `1 / scale` of the output.

### `class LuminaFsr3Settings`

FidelityFX Super Resolution 3 for a view through Filament's fragment-pass port (patch 0009): works on every backend with the structure pass motion vectors. DLSS on the same view takes precedence.

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | FSR3 on the view. Default false. |
| `quality` | `LuminaFsr3Quality quality` | The render-resolution preset. Default `quality`. |
| `sharpness` | `double sharpness` | RCAS sharpening after the upscale, 0 to 1. Default 0.5. |
| `frameGeneration` | `bool frameGeneration` | Present an interpolated frame before each rendered frame. Default false. |
| `taaOptions` | `TemporalAntiAliasingOptions taaOptions(TemporalAntiAliasingOptions base)` | `base` with TAA enabled, `TaaAlgorithm.fsr3`, the preset's `upscaling`, `sharpness` and `frameGeneration`. |
| `dynamicResolutionOptions` | `DynamicResolutionOptions get dynamicResolutionOptions` | Dynamic resolution pinned at `1 / scale` (disabled for `nativeAA`). |
| `copyWith`, `toMap`, `fromMap` | | Value semantics; JSON keys `enabled`, `quality`, `sharpness`, `frame_generation`. |

### `class LuminaRtxController`

Applies both settings to one view: the scene's acceleration structures, the directional lights' `ShadowOptions.rayTraced`, the view's `RestirOptions` and a `Dlss` instance that follows the viewport size.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `requestExtensions` | `static bool requestExtensions({String? dlssRuntimeDir})` | Asks the engines created from now on for the ray query extensions and, with the NGX runtime present, the DLSS and DLSS Frame Generation ones. Call it before the engine exists. |
| `activeNvidiaFeatures` | `static ObservableValue<Set<String>> activeNvidiaFeatures` | The NGX features running on any view right now (`DLSS Super Resolution`, `DLSS Ray Reconstruction`, `DLSS Frame Generation`), for an NVIDIA attribution while they are in use. |
| `rayReconstructionSupported`, `maxDlssGeneratedFrames` | `static bool rayReconstructionSupported(FilamentEngine engine)`, `static int maxDlssGeneratedFrames(FilamentEngine engine)` | Whether NGX runs Ray Reconstruction on the engine's GPU, and the most frames DLSS Frame Generation generates per rendered frame (0 without it); probed once per engine. |
| `dlssAvailable` | `static bool get dlssAvailable` | The NGX runtime was found and an NVIDIA Vulkan device exists. |
| `rayTracingSupported` | `bool get rayTracingSupported` | The engine traces rays. |
| `apply` | `void apply(LuminaRayTracingSettings rayTracing, LuminaDlssSettings dlss, {LuminaFsr3Settings fsr3 = const LuminaFsr3Settings(), LuminaDlssFrameGenerationSettings dlssFrameGeneration = const LuminaDlssFrameGenerationSettings(), required TemporalAntiAliasingOptions baseTaa, required DynamicResolutionOptions baseDynamicResolution})` | Applies both; cheap when nothing changed. The base options are restored when DLSS turns off (DLSS itself needs TAA with motion vectors). |
| `dlss`, `appliedRayTracing`, `appliedDlss` | | The live DLSS instance and the settings last applied. |
| `rayReconstruction`, `frameGenerator`, `appliedFrameGeneration` | | The live `DlssRayReconstruction` (with the view's guide buffers on) and `DlssFrameGenerator`, and the frame generation settings last applied. |
| `appliedFsr3`, `fsr3Active`, `fsr3Supported` | | The FSR3 settings last applied, whether FSR3 is on the view now (enabled, motion vectors available, no DLSS) and whether the engine renders the motion vectors it needs. |
| `invalidate` | `void invalidate()` | Forgets what it put on the view (DLSS is destroyed), so the next `apply` pushes everything again: call it after something else rewrote the view's TAA or dynamic resolution, such as a scalability profile. |
| `dispose` | `void dispose()` | Releases the DLSS, Ray Reconstruction and frame generator instances. |

### `class LuminaDlssFrameGenerationSettings`

`generatedFrames` (0–5): frames DLSS Frame Generation generates per rendered frame (0 is off, the default; 1 is 2x, 3 is 4x); `enabled`; JSON key `generated_frames`. The generated frames are presented between the rendered ones by the native swap chain path; a Flutter texture viewport receives only the rendered frames.

## `lib/src/post_process/rendering_features.dart`

The game-facing form of the settings above, used by the game user settings (`LuminaUserSettingsSubsystem`, see [World](world.md)) and their Blueprint nodes.

### `enum LuminaUpscaler`

`none` (`None`), `fsr3` (`FSR3`), `dlss` (`DLSS`), `dlssRayReconstruction` (`DLSS RR`); `displayName`, and `parse(String?)` (case-insensitive, `fsr` is FSR3, `dlss_rr` / `ray reconstruction` / `DLSS Ray Reconstruction` is DLSS RR, anything else `none`).

### `enum LuminaFrameGenerator`

`fsr3` (`FSR3`), `dlss` (`DLSS`): who generates the frames; `parse(String?)`, anything unknown is `fsr3`.

### `enum LuminaUpscalerQuality`

One quality scale for both upscalers, with `displayName`, the FSR3 preset (`fsr3`) and the DLSS mode (`dlss`): `nativeAA` (`Native AA`, FSR3 native AA, DLAA), `quality` (Max Quality), `balanced`, `performance` (Max Performance), `ultraPerformance`. `parse` ignores case, spaces and underscores; `DLAA` and `native` are `nativeAA`, anything unknown `quality`.

### `class LuminaRenderingFeatureSupport`

What a GPU can do, with a reason per "no": `rayTracing`, `dlss`, `fsr3`, `frameGeneration`, `rayReconstruction`, `dlssFrameGeneration` (+ `maxDlssGeneratedFrames`) and their `…Reason` strings. `probe({engine, view})` asks the engine (`supportsRayQuery`; Vulkan backend + `LuminaRtxController.dlssAvailable` for DLSS) and the view (`motionVectorsSupported` for FSR3 and frame generation); `none(reason)` on the web or without a renderer; `withoutDlss(reason)`, `withoutRayReconstruction(reason)`; `supportedUpscalers` (`none` first, `DLSS RR` when Ray Reconstruction runs).

### `class LuminaRenderingFeatureSettings`

The player's choice: `rayTracing`, `rayTracedShadows` (default true), `restir`, `restirCandidates` (1–64, 8), `restirSpatialSamples` (0–8, 2), `upscaler`, `upscalerQuality` (`quality`), `sharpness` (0–1, 0.5), `frameGeneration`, `frameGenerator` (`fsr3`), `dlssGeneratedFrames` (1–5, 1). `rayTracingSettings`, `fsr3Settings`, `dlssSettings`, `dlssFrameGenerationSettings` are the engine settings it describes; `resolve(support)` returns a `LuminaResolvedRenderingFeatures` (`settings` actually applied + `fallbacks` messages: ray tracing off without ray query, DLSS RR → DLSS without ray tracing or Ray Reconstruction support, DLSS → FSR3 → None, DLSS frame generation → FSR3 frame generation without support and clamped to the GPU's maximum, FSR3 frame generation only with FSR3); `copyWith` clamps; `toMap` / `fromMap` (keys `ray_tracing`, `ray_traced_shadows`, `restir`, `restir_candidates`, `restir_spatial_samples`, `upscaler`, `upscaler_quality`, `sharpness`, `frame_generation`, `frame_generator`, `dlss_generated_frames`; unknown or mistyped values keep the default).

**Games**: `LuminaGameWidget` asks for the ray query and DLSS extensions (`LuminaRtxController.requestExtensions`) before the shared engine is created, once per process and never on the web. DLSS also needs the NGX runtimes (`nvngx_dlss`; `nvngx_dlssd` for Ray Reconstruction, `nvngx_dlssg` for frame generation) next to the game executable, in `LUMINA_DLSS_DIR` or a fetched SDK; the packaged game does not ship it.

## `lib/src/material/dynamic_material_instance.dart`

### `class LuminaDynamicMaterialInstance`

A dynamic material instance.  Supports per-actor parameter mutations, texture bindings with custom samplers, render-state overrides, and stencil configurations without modifying other instances.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `setScalar` | `void setScalar(String name, double value)` | Sets a scalar float parameter value. |
| `setInt` | `void setInt(String name, int value)` | Updates the `Int` parameter and applies changes to the system. |
| `setBool` | `void setBool(String name, bool value)` | Updates the `Bool` parameter and applies changes to the system. |
| `setVector` | `void setVector(String name, Vector4 value)` | Sets a 4-component vector parameter value. |
| `setVector3` | `void setVector3(String name, Vector3 value)` | Sets a 3-component vector parameter value. |
| `setColor` | `void setColor(String name, RgbType type, (double, double, double) rgb)` | Sets a color parameter value with color-space conversion. |
| `setColorRgba` | `void setColorRgba(String name, RgbaType type, (double, double, double, d...` | Sets a 4-component color parameter value with color-space conversion. |
| `setScalarArray` | `void setScalarArray(String name, Float32List values)` | Sets an array of float scalar values. |
| `setVectorArray` | `void setVectorArray(String name, Float32List packed16)` | Sets an array of float4 vector values (packed 4 floats per element). |
| `setMatrixArray` | `void setMatrixArray(String name, Float32List packed64)` | Sets an array of 4x4 matrices (packed 16 floats per element). |
| `setTextureAsset` | `Future<bool> setTextureAsset(String name, String path, {LuminaAssetProvider? assetProvider})` | Binds the texture at [path] to sampler [name]: a texture asset (`contents/…/T_x.lmas`) or an image file, read through `LuminaAssets` and uploaded with the texture's settings (sRGB, mipmaps, filtering, wrap) exactly as a material's own textures (`LuminaMaterialTextures`), sharing the upload. False (sampler unchanged) when it cannot be loaded (logged once) or a later call for [name] replaced it. What Set Texture Parameter Value calls. |
| `texturesLoaded` | `Future<void> get texturesLoaded` | Completes once every `setTextureAsset` load started so far has settled. |
| `textureParameter` | `LuminaBoundTexture? textureParameter(String name)` | The texture `setTextureAsset` bound to sampler [name], or null; released when replaced or when the instance is disposed. |
| `cullingMode` | `CullingMode get cullingMode` | Face culling mode override. |
| `cullingMode` | `cullingMode(CullingMode mode) => nativeInstance.setCullingMode(mode)` | Executes `cullingMode` operation. |
| `isDoubleSided` | `bool get isDoubleSided` | Double-sided rendering override. |
| `isDoubleSided` | `isDoubleSided(bool doubleSided) => nativeInstance.setDoubleSided(doubleS...` | Checks current state or capability and returns a boolean value. |
| `isColorWriteEnabled` | `bool get isColorWriteEnabled` | Color buffer write override. |
| `isColorWriteEnabled` | `isColorWriteEnabled(bool enable) => nativeInstance.setColorWrite(enable)` | Checks current state or capability and returns a boolean value. |
| `isDepthWriteEnabled` | `bool get isDepthWriteEnabled` | Depth buffer write override. |
| `isDepthWriteEnabled` | `isDepthWriteEnabled(bool enable) => nativeInstance.setDepthWrite(enable)` | Checks current state or capability and returns a boolean value. |
| `isDepthCullingEnabled` | `bool get isDepthCullingEnabled` | Depth test (culling) override. |
| `isDepthCullingEnabled` | `isDepthCullingEnabled(bool enable) => nativeInstance.setDepthCulling(ena...` | Checks current state or capability and returns a boolean value. |
| `depthFunc` | `DepthFunc get depthFunc` | Depth comparison function override. |
| `depthFunc` | `depthFunc(DepthFunc func) => nativeInstance.setDepthFunc(func)` | Executes `depthFunc` operation. |
| `transparencyMode` | `TransparencyMode get transparencyMode` | Transparency mode override. |
| `transparencyMode` | `transparencyMode(TransparencyMode mode) => nativeInstance.setTransparenc...` | Executes `transparencyMode` operation. |
| `maskThreshold` | `double get maskThreshold` | Mask alpha cutoff threshold override. |
| `maskThreshold` | `maskThreshold(double threshold) => nativeInstance.setMaskThreshold(thres...` | Executes `maskThreshold` operation. |
| `setPolygonOffset` | `void setPolygonOffset(double scale, double constant)` | Sets the polygon offset for this instance (e.g. for decals). |
| `unsetScissor` | `void unsetScissor()` | Unsets custom scissor rectangle. |
| `setStencilWrite` | `void setStencilWrite(bool enabled) => nativeInstance.setStencilWrite(ena...` | Enables or disables writing to the stencil buffer. |
| `isStencilWriteEnabled` | `bool get isStencilWriteEnabled` | Checks if stencil buffer writing is enabled. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class LuminaPendingDynamicMaterialInstance`

`lib/src/material/dynamic_material_instance.dart`. A section's dynamic material instance that exists once the section's material asset has loaded: what Create Dynamic Material Instance hands out while a component's Material Override (or slot material) is still loading, as it is at BeginPlay. Parameters set on it meanwhile are applied to the instance, in order, when it is made.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ready` | `late final Future<LuminaDynamicMaterialInstance?> ready` | The instance, or null when the section got no material to make one of. |
| `instance` | `LuminaDynamicMaterialInstance? get instance` | The instance once `ready` completed, else null. |
| `parameterValues` | `final Map<String, Object?> parameterValues` | The values set so far per parameter name, for Blueprints to read back before the instance exists. |
| `whenReady` | `void whenReady(void Function(LuminaDynamicMaterialInstance instance) apply)` | Runs [apply] on the instance now when it exists, else once it is made (dropped when none is). |

## `lib/src/material/lumina_material.dart`

### `class LuminaMaterial`

Asset-level wrapper around a compiled Filament material (.filamat) package.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `constants` | `List<MaterialConstant> constants` | Holds the `constants` property or configuration state. |
| `nativeMaterial` | `FilamentMaterial get nativeMaterial` | The underlying native [FilamentMaterial]. |
| `world` | `LuminaWorld get world` | The owning [LuminaWorld]. |
| `textures` | `LuminaMaterialTextures get textures` | The textures bound to this material's samplers, which every instance starts with, and the ones that could not be loaded. |
| `isDisposed` | `bool get isDisposed` | Whether this material asset has been disposed. |
| `parameterCount` | `int get parameterCount` | Total number of parameters declared on this material. |
| `parameters` | `List<MaterialParameter> get parameters` | Cached list of reflected material parameters. |
| `hasParameter` | `bool hasParameter(String name)` | Checks whether this material declares parameter [name]. |
| `isSampler` | `bool isSampler(String name)` | Checks whether parameter [name] is a sampler texture parameter. |
| `name` | `String? get name` | Name embedded in the material package. |
| `shading` | `FilamatShading get shading` | Shading model of this material. |
| `blendingMode` | `BlendingMode get blendingMode` | Blending mode of this material. |
| `cullingMode` | `CullingMode get cullingMode` | Default culling mode of this material. |
| `isDoubleSided` | `bool get isDoubleSided` | Whether this material is double-sided. |
| `maskThreshold` | `double get maskThreshold` | Mask threshold alpha cutoff value. |
| `materialDomain` | `MaterialDomain get materialDomain` | Material domain of this material. |
| `defaultInstance` | `LuminaMaterialInstance get defaultInstance` | Returns the cached, non-destroyable default instance of this material. |
| `setDefaultParameterFloat` | `void setDefaultParameterFloat(String name, double value)` | Sets default float parameter value on this material. |
| `setDefaultParameterFloat4` | `void setDefaultParameterFloat4(String name, Vector4 value)` | Sets default 4-component float parameter value on this material. |
| `setDefaultColor` | `void setDefaultColor(String name, RgbType type, (double, double, double)...` | Sets default RGB color on this material. |
| `addRef` | `void addRef()` | Increments the reference count. |
| `onInstanceDisposed` | `void onInstanceDisposed(LuminaMaterialInstance instance)` | Internal callback when an instance is disposed. |
| `release` | `void release()` | Decrements reference count and frees material when all references and instances are released. |
| `forceDestroy` | `void forceDestroy()` | Force-destroys this material and all instances during cache teardown. |

## `lib/src/material/lumina_material_instance.dart`

### `class LuminaMaterialInstance`

Wrapped instance of a [LuminaMaterial] assigned to mesh renderables.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `material` | `LuminaMaterial material` | Holds the `material` property or configuration state. |
| `isDefaultInstance` | `bool isDefaultInstance` | Holds the `isDefaultInstance` property or configuration state. |
| `nativeInstance` | `FilamentMaterialInstance get nativeInstance` | The underlying native Filament material instance. |
| `name` | `String get name` | The name of this material instance. |
| `isDisposed` | `bool get isDisposed` | Whether this instance has been disposed. |
| `getFloat` | `double getFloat(String name)` | Reads a float parameter value with reflection type validation. |
| `getFloat4` | `Vector4 getFloat4(String name)` | Reads a 4-component vector parameter value with reflection type validation. |
| `getInt` | `int getInt(String name)` | Reads an integer parameter value with reflection type validation. |
| `getBool` | `bool getBool(String name)` | Reads a boolean parameter value with reflection type validation. |
| `getMat4` | `Float32List getMat4(String name)` | Reads a 4x4 matrix parameter value with reflection type validation. |
| `setFloat` | `void setFloat(String name, double value)` | Sets a float parameter value. |
| `setFloat4` | `void setFloat4(String name, Vector4 value)` | Sets a 4-component float parameter value. |
| `setInt` | `void setInt(String name, int value)` | Sets an integer parameter value. |
| `setBool` | `void setBool(String name, bool value)` | Sets a boolean parameter value. |
| `dispose` | `void dispose()` | Destroys this material instance and notifies parent material. |
| `internalDispose` | `void internalDispose()` | Internal destruction when parent material is destroyed. |

## `lib/src/material/material_cache.dart`

### `class _MaterialCacheKey`

`_MaterialCacheKey`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_MaterialCacheKey(this.assetPath, this.constants)`: Initializes `_MaterialCacheKey(this.assetPath, this.constants)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `constants` | `List<MaterialConstant> constants` | Holds the `constants` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

### `class LuminaMaterialCache`

Refcounted cache of compiled [LuminaMaterial] assets for a world.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | Holds the `world` property or configuration state. |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `createNative` | `static FilamentMaterial createNative(FilamentEngine engine, String assetPath, Uint8List bytes, {List<MaterialConstant> constants = const []})` | A native material from the bytes of [assetPath]: a material `.lmas` (its compiled package, with the parameter values the Material Editor saved as defaults) or a `.filamat`. Throws a `StateError` when they hold no compiled material. |
| `createNativeWithTextureReferences` | `static (FilamentMaterial, List<AssetReference>) createNativeWithTextureReferences(FilamentEngine engine, String assetPath, Uint8List bytes, {List<MaterialConstant> constants = const []})` | `createNative`, plus the material asset's references: which texture each sampler draws. Empty for a `.filamat`. |
| `isCompiledPackage` | `static bool isCompiledPackage(Uint8List bytes)` | Whether [bytes] is a compiled `.filamat` package (Filament aborts the process on anything else). |
| `onMaterialReleased` | `void onMaterialReleased(LuminaMaterial material)` | Internal callback when material refcount drops to zero. |
| `dispose` | `void dispose()` | Disposes all cached materials. |

A material the cache loads (`load`, used by `LuminaStaticMeshComponent.setMaterialAsset`, `materialOverrideAsset` and mesh slot materials) gets its sampler textures loaded and bound on its default instance before it is returned, so every instance (and a `LuminaDynamicMaterialInstance` made from one) draws them; see `LuminaMaterialTextures`.


### `class LuminaInstanceMaterialOverride`

One material asset drawn on every section of a gltfio instance that no world owns: the editor's level viewport, where a placed mesh shows its assigned material as Play and the built game draw it (`LuminaStaticMeshComponent.materialOverrideAsset`).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fromBytes` | `factory LuminaInstanceMaterialOverride.fromBytes(FilamentEngine engine, String assetPath, Uint8List bytes, {LuminaAssetProvider? assetProvider})` | Builds the material from a material `.lmas` or `.filamat`, with its saved parameter values, and binds the textures its samplers name once they are loaded through [assetProvider] (else `LuminaAssets`); a `StateError` when there is no compiled material. |
| `texturesLoaded` | `Future<void> texturesLoaded` | Completes once the textures are bound (or found missing, each logged once). |
| `texturePaths` | `final List<String> texturePaths` | The textures its samplers name (`contents/…` or absolute, as they are read). The level viewport draws the material anew when one of them is saved again (`LuminaLevelActorMaterial.revision`). |
| `textures` | `LuminaMaterialTextures get textures` | The bound textures; empty until `texturesLoaded`. Released with the material on `dispose`. |
| `applyTo` | `void applyTo(FilamentAssetInstance instance)` | Draws it on every primitive of every renderable of [instance], remembering what each drew. |
| `restore` | `void restore()` | Gives those sections their own materials back. |
| `dispose` | `void dispose()` | Restores the sections and destroys the material. |

### `class LuminaMaterialTextures`

`lib/src/material/material_textures.dart`. The textures a material asset's samplers name, loaded and uploaded. A material asset records which texture goes to which sampler in its references (`slot_name` = the sampler parameter, `asset_path` = a texture `.lmas`, whose payload is the image, or an image file): the glTF import writes them for `baseColorMap`, `normalMap`, `metallicRoughnessMap`, `occlusionMap` and `emissiveMap`, the Material Editor for every `sampler2d` a texture was assigned to. Textures are read through `LuminaAssets` (the project's files in the editor and Play, the asset bundle in a built game, the web included; an absolute project path is read as its `contents/…` key there) and uploaded with the texture asset's `texture_settings`: `srgb` (without settings, colour samplers — names containing `color`, `albedo`, `diffuse`, `emissive` — are sRGB, the rest linear), mipmaps (none for `NoMipmaps` or the `UI` group), `filter` (`Bilinear` → linear-mipmap-nearest, `Trilinear` → linear-mipmap-linear, `Anisotropic 16x` → trilinear with anisotropy 16) and `address_x` / `address_y` (`Wrap`, `Clamp`, `Mirror`). One upload is shared per texture content (the file's bytes: image and settings) and engine and destroyed when the last material binding it is released, so a texture saved again (Texture editor Save / Reimport, an import over it) is uploaded anew for the materials loaded after the save while the ones still drawing the old upload keep it. A texture that cannot be read or decoded logs one warning and its sampler is left unbound.

| Member | Signature | Description |
| :--- | :--- | :--- |
| `load` | `static Future<LuminaMaterialTextures> load(FilamentEngine engine, FilamentMaterial material, List<AssetReference> references, {required String materialPath, LuminaAssetProvider? assetProvider})` | Loads the textures [references] name for the samplers [material] declares. |
| `texturePaths` | `static Map<String, String> texturePaths(FilamentMaterial material, List<AssetReference> references, {LuminaAssetProvider? assetProvider})` | The texture each declared sampler draws, by sampler name, as `load` reads it. |
| `bound` | `Map<String, LuminaBoundTexture> bound` | The texture bound to each sampler (`path`, the shared `texture`, its `sampler`, `srgb`). |
| `missing` | `Map<String, String> missing` | Why a sampler's texture was not bound. |
| `bindTo` | `void bindTo(FilamentMaterialInstance instance)` | Binds every loaded texture on [instance]; on a material's default instance, every instance created from it starts with them. |
| `release` | `void release()` | Lets go of the textures, after the material is destroyed. |
| `isColorSampler` | `static bool isColorSampler(String name)` | Whether a sampler holds colour (sRGB) rather than data, by name. |

## `lib/src/post_process/post_process_blender.dart`

### `class LuminaPostProcessBlender`

Post-process volume blending on top of Filament's single per-`View` post-processing state.

Filament has no notion of volumes: one `View` carries one set of options. The blender is the missing layer, in Dart and pure: it starts from the **baseline** (whatever the game or the editor last applied directly), overlays the level's height fog ([LuminaHeightFogSettings]), then walks every registered [LuminaPostProcessVolume] that contains the camera — unbound volumes always — in **priority** order, lerping towards each volume's [LuminaPostProcessOverrides] by its **blend weight** times a **blend-radius** falloff (1 inside, 0 at `blendRadius` outside the shape). The honest limit is that Filament blends the whole view by camera position, never per pixel.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `baseline` | `LuminaPostProcessSettings baseline` | The settings volumes blend from. Set by every direct `LuminaPostProcessController.apply` (game code, scalability, the editor). |
| `heightFog` | `LuminaHeightFogSettings? heightFog` | The level's Exponential Height Fog, or null when the level has no fog actor: then the baseline's fog stays. |
| `heightFogOwner` | `Object? heightFogOwner` | Who published [heightFog] (for the "one per level" rule). |
| `volumes` | `List<LuminaPostProcessVolume> get volumes` | Registered volumes, in registration order. |
| `cameraPositionOverride` | `Vector3? cameraPositionOverride` | Where the camera is when the world has no active camera component (the editor viewport's eye; runtime axes). |
| `addVolume` | `void addVolume(LuminaPostProcessVolume volume)` |  |
| `removeVolume` | `void removeVolume(LuminaPostProcessVolume volume)` |  |
| `clearVolumes` | `void clearVolumes()` |  |
| `setHeightFog` | `void setHeightFog(LuminaHeightFogSettings? fog, {required Object owner})` | Publishes the height fog from [owner]; a different live owner is replaced (last one wins — Filament has one fog per view). |
| `clearHeightFogOf` | `void clearHeightFogOf(Object owner)` | Clears the height fog if [owner] published it. |
| `resolve` | `LuminaPostProcessResult resolve(Vector3? cameraWorld)` | The settings for a camera at [cameraWorld] (runtime axes). With no camera position only unbound volumes apply. |

### `class LuminaPostProcessResult`

What [LuminaPostProcessBlender.resolve] produces: the view settings and, when a volume overrides depth-of-field focus, the camera focus distance (a `FilamentCamera` property, not a view option).

**Constructors:**

- `const LuminaPostProcessResult(this.settings, this.focusDistance)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `settings` | `final LuminaPostProcessSettings settings` |  |
| `focusDistance` | `final double? focusDistance` |  |

### `class LuminaPostProcessOverrides`

A volume's overrides: every field `null` means "not overridden", so it leaves the blended state alone (the per-setting override checkbox).

**Constructors:**

- `const LuminaPostProcessOverrides({this.bloomIntensity, this.bloomThreshold, this.vignette, this.depthOfFieldEnabled, this.dofFocusDistance, this.dofAperture, th...`
- `factory LuminaPostProcessOverrides.fromProperties(Map<String, dynamic> p)`: Reads the editor properties: a value counts only when its `override<Name>` flag is true.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `bloomIntensity` | `final double? bloomIntensity` | 0–8, the Environment editor's scale (Filament strength × 8). |
| `bloomThreshold` | `final double? bloomThreshold` | Filament's bloom `highlight`, lux. |
| `vignette` | `final double? vignette` | 0..1; pulls Filament's vignette `midPoint` inward. |
| `depthOfFieldEnabled` | `final bool? depthOfFieldEnabled` |  |
| `dofFocusDistance` | `final double? dofFocusDistance` | Camera focus distance, cm. |
| `dofAperture` | `final double? dofAperture` | Filament's DoF `cocScale` (0..2). |
| `ambientOcclusionEnabled` | `final bool? ambientOcclusionEnabled` |  |
| `ambientOcclusionIntensity` | `final double? ambientOcclusionIntensity` | Filament's AO `intensity` (0..4). |
| `exposure` | `final double? exposure` | Exposure compensation, EV. |
| `contrast` | `final double? contrast` |  |
| `saturation` | `final double? saturation` |  |
| `temperature` | `final double? temperature` | White-balance temperature, −1 (cool) .. 1 (warm). |
| `taaEnabled` | `final bool? taaEnabled` |  |
| `fogDensityScale` | `final double? fogDensityScale` | Multiplies the fog density (a Local Fog Volume's way in). |
| `fogColor` | `final Vector3? fogColor` |  |
| `keys` | `static const List<String> keys` | The editor component's property keys, each guarded by an `override<Name>` boolean (the override checkbox). |
| `overrideKey` | `static String overrideKey(String key)` |  |
| `toProperties` | `Map<String, dynamic> toProperties()` | The editor properties: values plus their `override<Name>` flags. |
| `isEmpty` | `bool get isEmpty` |  |
| `lerpOnto` | `void lerpOnto(LuminaPostProcessResolved current, double weight)` | Lerps [current] towards these overrides by [weight]; booleans switch once the weight reaches one half. |

### `class LuminaPostProcessResolved`

The mutable numeric state the blender lerps, in the editor's units, built from a [LuminaPostProcessSettings] and written back with the exact mappings the Environment editor and the code generator already use.

**Constructors:**

- `LuminaPostProcessResolved({required this.bloomIntensity, required this.bloomThreshold, required this.vignette, required this.depthOfFieldEnabled, required this....`
- `factory LuminaPostProcessResolved.fromSettings(LuminaPostProcessSettings s)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `bloomIntensityMax` | `static const double bloomIntensityMax` | A 0–8 bloom scale over Filament's 0–1 `strength`. |
| `bloomIntensity` | `double bloomIntensity` |  |
| `bloomThreshold` | `double bloomThreshold` |  |
| `vignette` | `double vignette` |  |
| `depthOfFieldEnabled` | `bool depthOfFieldEnabled` |  |
| `dofAperture` | `double dofAperture` |  |
| `ambientOcclusionEnabled` | `bool ambientOcclusionEnabled` |  |
| `ambientOcclusionIntensity` | `double ambientOcclusionIntensity` |  |
| `exposure` | `double exposure` |  |
| `contrast` | `double contrast` |  |
| `saturation` | `double saturation` |  |
| `temperature` | `double temperature` |  |
| `taaEnabled` | `bool taaEnabled` |  |
| `fogDensityScale` | `double fogDensityScale` |  |
| `fogColor` | `Vector3 fogColor` |  |
| `applyTo` | `LuminaPostProcessSettings applyTo(LuminaPostProcessSettings base)` | Writes this state onto [base]. |

### `class LuminaPostProcessVolume`

The shape the blender evaluates: an oriented box (or sphere) in runtime axes, or unbound. [worldTransform] carries the actor's rotation and scale (the half extent is scaled by it).

**Constructors:**

- `LuminaPostProcessVolume({this.enabled = true, this.unbound = false, this.priority = 0.0, this.blendRadius = 100.0, this.blendWeight = 1.0, this.overrides = cons...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` |  |
| `unbound` | `bool unbound` |  |
| `priority` | `double priority` |  |
| `blendRadius` | `double blendRadius` | Falloff distance outside the shape, cm (Blend Radius). |
| `blendWeight` | `double blendWeight` | 0..1 (Blend Weight). |
| `overrides` | `LuminaPostProcessOverrides overrides` |  |
| `worldTransform` | `Matrix4 worldTransform` | The actor's world matrix (rotation, position, scale). |
| `halfExtent` | `Vector3 halfExtent` | Half size, cm, before [worldTransform]'s scale. |
| `sphereRadius` | `double? sphereRadius` | When set the shape is a sphere of this radius (cm, unscaled). |
| `owner` | `Object? owner` | Whatever registered this volume (a component, the editor). |
| `surfaceDistance` | `double? surfaceDistance(Vector3 world)` | Signed distance from the shape surface (negative inside), cm, in world units; `null` for an unbound volume. |
| `containsPoint` | `bool containsPoint(Vector3 world)` |  |
| `weightFor` | `double weightFor(Vector3? cameraWorld)` | 1 inside, falling linearly to 0 over [blendRadius] outside; unbound → 1; no camera → only unbound volumes count. |

---

[Previous: AI](ai.md) | [Up: lumina (engine core)](index.md) | [Next: Rendering devices](rendering.md)
