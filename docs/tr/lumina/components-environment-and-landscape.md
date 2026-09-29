[English](../../en/lumina/components-environment-and-landscape.md)

# Bileşenler: çevre ve landscape

Çevreyi oluşturan component'ler: sky ve procedural sky (Filament binding'leriyle), reflection capture'lar ve mesh builder, section map, GLB builder ve residency planlamasıyla landscape component'i. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/components/environment/procedural_sky_binding.dart`](#libsrccomponentsenvironmentprocedural_sky_bindingdart)
- [`lib/src/components/environment/procedural_sky_component.dart`](#libsrccomponentsenvironmentprocedural_sky_componentdart)
- [`lib/src/components/environment/reflection_capture_component.dart`](#libsrccomponentsenvironmentreflection_capture_componentdart)
- [`lib/src/components/environment/sky_binding.dart`](#libsrccomponentsenvironmentsky_bindingdart)
- [`lib/src/components/environment/sky_component.dart`](#libsrccomponentsenvironmentsky_componentdart)
- [`lib/src/components/landscape/landscape_component.dart`](#libsrccomponentslandscapelandscape_componentdart)
- [`lib/src/components/landscape/landscape_glb_builder.dart`](#libsrccomponentslandscapelandscape_glb_builderdart)
- [`lib/src/components/landscape/landscape_mesh_builder.dart`](#libsrccomponentslandscapelandscape_mesh_builderdart)
- [`lib/src/components/landscape/landscape_residency.dart`](#libsrccomponentslandscapelandscape_residencydart)
- [`lib/src/components/landscape/landscape_section_map.dart`](#libsrccomponentslandscapelandscape_section_mapdart)
- [`lib/src/components/environment/exponential_height_fog_component.dart`](#libsrccomponentsenvironmentexponential_height_fog_componentdart)
- [`lib/src/components/environment/local_fog_volume_component.dart`](#libsrccomponentsenvironmentlocal_fog_volume_componentdart)
- [`lib/src/components/environment/post_process_volume_component.dart`](#libsrccomponentsenvironmentpost_process_volume_componentdart)
- [`lib/src/components/landscape/landscape_brush_cursor.dart`](#libsrccomponentslandscapelandscape_brush_cursordart)

## `lib/src/components/environment/procedural_sky_binding.dart`

### `class LuminaProceduralSkyDescription`

Immutable description of a procedural sky and ocean.  This is the value type the editor's `ProceduralSky` actor speaks: it is parsed straight out of a `LuminaProceduralSkyComponent` property map — the map the Details panel writes onto the actor and the `.lmas` level file — so the editor viewport, the runtime component and the code generator all agree on what a level's procedural sky is.

**Yapıcı Metotlar (Constructors):**
- `LuminaProceduralSkyDescription.fromProperties(Map<String, dynamic>? props)`: Builds a description from a `LuminaProceduralSkyComponent` property map, falling back to [defaults] for every missing or malformed entry.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeOfDay` | `double timeOfDay` | Hour of the day, 0..24. 12.0 is noon, 0/24 is midnight. |
| `turbidity` | `double turbidity` | Atmospheric haze. 1 is a crystal-clear day, 10 is heavy smog. |
| `rayleigh` | `double rayleigh` | Rayleigh scattering strength — how blue the sky is. |
| `mieCoefficient` | `double mieCoefficient` | Mie scattering coefficient (forward scattering around the sun). |
| `mieG` | `double mieG` | Mie directionality, 0..1. Higher values tighten the sun's halo. |
| `cloudCoverage` | `double cloudCoverage` | Cloud cover, 0 (clear) .. 1 (overcast). |
| `cloudDensity` | `double cloudDensity` | Cloud opacity. |
| `waterStrength` | `double waterStrength` | Ocean wave strength. 0 disables the water reflection. |
| `waterSpeed` | `double waterSpeed` | Ocean wave speed. |
| `dayCycleSpeed` | `double dayCycleSpeed` | Simulated hours advanced per real second. 0 freezes the sky. |
| `visible` | `bool visible` | Whether the sky renders at all. |
| `toProperties` | `Map<String, dynamic> toProperties()` | The property map the editor stores on the actor's component and the code generator reads back. |
| `sunDirection` | `List<double> get sunDirection` | Unit sun direction for [timeOfDay] (+Y is up, noon is near the zenith). |
| `isNight` | `bool get isNight` | Whether the sun is below the horizon at [timeOfDay]. |
| `advancedTimeOfDay` | `double advancedTimeOfDay(double deltaSeconds)` | [timeOfDay] advanced by [deltaSeconds] of the day cycle, wrapped to 0..24. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaProceduralSkyBinding`

Binds a [LuminaProceduralSkyDescription] onto a live Filament engine + scene as a real, animating sky renderable.  [LuminaProceduralSkyComponent] wraps one of these for a full [LuminaWorld]; this binding exists for surfaces that render a Filament scene *without* a world — the Lumina Studio level viewport — so those viewports never have to build the geometry, compile the shader or compute the uniforms themselves. It mirrors [LuminaSkyBinding], which does the same for the `Environment` actor's skybox and image-based lighting.  The sky is a full-screen triangle renderable with `depthWrite: false`, not a Filament `Skybox`, which is what lets it animate per frame and what lets a level carry both it and an `Environment` actor. It lights nothing.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `scene` | `FilamentScene scene` | `scene` alanını (field/property) ve ilişkili veriyi saklar. |
| `loadNightSkyTextures` | `bool loadNightSkyTextures` | Whether to load the real moon and Milky Way textures. When false (or when a load fails) 1×1 neutral textures stay bound, which is enough for the atmosphere, clouds and ocean. |
| `isLoaded` | `bool get isLoaded` | Whether the shader is compiled and the sky renderable is in the scene. |
| `loaded` | `Future<void> get loaded` | Completes once the sky is in the scene, or completes with an error. |
| `skyEntity` | `int? get skyEntity` | The scene entity carrying the sky triangle, once loaded. |
| `description` | `LuminaProceduralSkyDescription get description` | The description currently bound to the scene. |
| `load` | `Future<void> load(LuminaProceduralSkyDescription description)` | Compiles the shader, builds the geometry and puts the sky in the scene.  Safe to call more than once; later calls are no-ops. |
| `apply` | `void apply(LuminaProceduralSkyDescription description)` | Pushes [description] onto the scene.  Cheap and idempotent: the uniforms are re-uploaded only when something changed, and nothing is ever rebuilt, so it is safe to call on every Details-panel keystroke and on every frame of a day cycle. |
| `advance` | `double advance(double deltaSeconds)` | Advances the day cycle by [deltaSeconds] and re-uploads. Returns the new time of day, so a host can write it back onto the actor it came from. |
| `dispose` | `void dispose()` | Removes the sky from the scene and destroys every resource it owns. |

## `lib/src/components/environment/procedural_sky_component.dart`

### `class LuminaProceduralSkyComponent`

A fully procedural sky and ocean: single-pass atmospheric scattering (Preetham & Hoffman), volumetric FBM clouds, a day/night cycle with stars and the Milky Way, and a real-time ocean water reflection.  This is the runtime form of flutter_filament's "Procedural Sky & Ocean" gallery sample (`example/lib/samples/simulated_skybox_sample.dart`, itself a port of Filament's `web/examples/sky/SimulatedSkybox.js`). The sample's shader is shipped with this package as `packages/lumina/assets/sky/simulated_skybox.filamat`.  The component is the declarative face of [LuminaProceduralSkyBinding]: it owns the parameters as mutable fields, and the binding owns the GPU resources and the uniform maths. The Lumina Studio level viewport drives the same binding directly, without a world, so the editor and the game cannot render different skies.  Unlike [LuminaSkyComponent] this does **not** create a Filament `Skybox`: the sky is a full-screen triangle renderable with `depthWrite: false`, which is what lets it animate per frame and what lets a level carry both. Pair it with a [LuminaSkyComponent] (or the editor's Environment actor) when the scene also needs image-based lighting — a procedural sky lights nothing.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeOfDay` | `double timeOfDay` | Hour of the day, 0..24. 12.0 is noon, 0/24 is midnight. |
| `turbidity` | `double turbidity` | Atmospheric haze. 1 is a crystal-clear day, 10 is heavy smog. |
| `rayleigh` | `double rayleigh` | Rayleigh scattering strength — how blue the sky is. |
| `mieCoefficient` | `double mieCoefficient` | Mie scattering coefficient (forward scattering around the sun). |
| `mieG` | `double mieG` | Mie directionality, 0..1. Higher values tighten the sun's halo. |
| `cloudCoverage` | `double cloudCoverage` | Cloud cover, 0 (clear) .. 1 (overcast). |
| `cloudDensity` | `double cloudDensity` | Cloud opacity. |
| `waterStrength` | `double waterStrength` | Ocean wave strength. 0 disables the water reflection. |
| `waterSpeed` | `double waterSpeed` | Ocean wave speed. |
| `dayCycleSpeed` | `double dayCycleSpeed` | Simulated hours advanced per real second. 0 freezes the sky at [timeOfDay]. A multiple of 24 is a no-op: the sky returns to the same hour every tick. |
| `loadNightSkyTextures` | `bool loadNightSkyTextures` | Whether to load the bundled moon and Milky Way textures. When false (or when a load fails) 1×1 neutral textures are used, which is enough for the atmosphere, clouds and ocean. |
| `description` | `LuminaProceduralSkyDescription get description` | The current parameters as a value. |
| `isLoaded` | `bool get isLoaded` | Whether the shader is compiled and the sky renderable is in the scene. |
| `loaded` | `Future<void> get loaded` | Completes once the sky is in the scene (or completes with an error). |
| `skyEntity` | `int? get skyEntity` | The scene entity carrying the sky triangle, once loaded. |
| `sunDirection` | `List<double> get sunDirection` | Unit sun direction for the current [timeOfDay] (+Y is up). |
| `isNight` | `bool get isNight` | Whether the sun is below the horizon at [timeOfDay]. |
| `visible` | `bool get visible` | `visible` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `visible` | `visible(bool value)` | `visible` işlemini gerçekleştirir. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `updateUniforms` | `void updateUniforms() => _binding?.apply(description)` | Uploads every sky uniform for the current parameters. A no-op before the component is registered on a world with a native context. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/environment/reflection_capture_component.dart`

### `class LuminaReflectionFilterCache`

Cache and factory for shared IBL prefiltering GPU objects per engine/world.

**Yapıcı Metotlar (Constructors):**
- `LuminaReflectionFilterCache(this.engine)`: `LuminaReflectionFilterCache(this.engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `getOrCreateContext` | `IblPrefilterContext getOrCreateContext()` | `OrCreateContext` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getOrCreateIrradianceFilter` | `IrradianceFilter getOrCreateIrradianceFilter()` | `OrCreateIrradianceFilter` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getOrCreateEquirectToCubemap` | `EquirectangularToCubemap getOrCreateEquirectToCubemap()` | `OrCreateEquirectToCubemap` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class LuminaReflectionCaptureComponent`

Reflection capture component generating GPU-filtered environment cubemap reflections.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `resolution` | `int resolution` | `resolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `specularLevels` | `int specularLevels` | `specularLevels` alanını (field/property) ve ilişkili veriyi saklar. |
| `captureOnRegister` | `bool captureOnRegister` | `captureOnRegister` alanını (field/property) ve ilişkili veriyi saklar. |
| `nearClip` | `double nearClip` | `nearClip` alanını (field/property) ve ilişkili veriyi saklar. |
| `farClip` | `double farClip` | `farClip` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasCapture` | `bool get hasCapture` | Whether reflection probe capture has completed. |
| `reflectionsTexture` | `FilamentTexture? get reflectionsTexture` | Non-owning view of the filtered reflections texture. |
| `validateEquirectTextureFormat` | `bool validateEquirectTextureFormat(TextureFormat format)` | Validates that an equirectangular texture has a floating-point HDR format. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `captureFromEquirect` | `Future<void> captureFromEquirect(FilamentTexture equirectHdr)` | Prefilters a supplied equirectangular HDR panorama texture into reflection cubemaps. |
| `invalidate` | `void invalidate()` | Invalidates the captured reflection texture and restores the original scene IndirectLight. |

## `lib/src/components/environment/sky_binding.dart`

### `class LuminaSkyDescription`

Immutable description of a scene's sky background and image-based lighting.  This is the value type the editor's `Environment` actor speaks: it is parsed straight out of a `LuminaSkyComponent` property map (the map the Environment Lighting sub-editor writes onto the actor and the `.lmas` level file), so the editor viewports, the runtime and the code generator all agree on what a level's sky is.

**Yapıcı Metotlar (Constructors):**
- `LuminaSkyDescription(color: defaultColor)`: `LuminaSkyDescription(color: defaultColor)` nesnesini ilklendirir.
- `LuminaSkyDescription.fromProperties(Map<String, dynamic>? props)`: Builds a description from a `LuminaSkyComponent` property map, falling back to [defaults] for every missing or malformed entry.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `useEnvironmentMap` | `bool useEnvironmentMap` | Whether the sky comes from an HDRI environment cubemap instead of a solid colour. |
| `environmentAssetPath` | `String? environmentAssetPath` | Project-relative path of the `.ktx` environment map, when [useEnvironmentMap] is set. |
| `color` | `Vector4 color` | Solid sky colour (linear RGBA) used when [useEnvironmentMap] is false. |
| `skyIntensity` | `double skyIntensity` | Skybox intensity in lux. |
| `iblIntensity` | `double iblIntensity` | Indirect (ambient / IBL) intensity in lux. |
| `rotationDegrees` | `double rotationDegrees` | Yaw rotation of the environment, in degrees. |
| `showSun` | `bool showSun` | Whether the skybox renders the sun disc of the brightest sun light. |
| `skyVisible` | `bool skyVisible` | Whether the skybox is drawn at all (the IBL still applies when false). |
| `defaultColor` | `static Vector4 get defaultColor` | The editor's default sky colour (`#5C7FB8`, a daylight zenith blue). |
| `defaults` | `static LuminaSkyDescription get defaults` | A neutral daylight default used when a level carries no Environment actor. |
| `colorFromHex` | `static Vector4 colorFromHex(String hex)` | Parses `#RRGGBB` / `#AARRGGBB` into a linear-ish RGBA vector.  The editor stores sky colours as sRGB hex, and Filament's `Skybox` takes linear colour, so the channels are converted with the sRGB EOTF. |
| `needsRebuildFrom` | `bool needsRebuildFrom(LuminaSkyDescription other)` | Whether [other] needs the native skybox / IBL objects rebuilt rather than just re-parameterised. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaSkyBinding`

Binds a [LuminaSkyDescription] onto a live Filament engine + scene as a real `Skybox` and a real `IndirectLight`.  [LuminaSkyComponent] does the same thing for a full [LuminaWorld]; this binding exists for surfaces that render a Filament scene *without* a world — the Lumina Studio level viewport and the sub-editor preview viewports — so those viewports never have to talk to `FilamentSkybox` / `FilamentIndirectLight` themselves.  ### Why a fallback cubemap and not just spherical harmonics  A solid-colour sky carries no reflection information, and an `IndirectLight` built from spherical harmonics alone gives diffuse ambient but **no specular ambient** — so a metallic or smooth PBR surface lit only by directional lights renders as a black silhouette. Callers therefore always hand this binding a neutral fallback IBL cubemap ([fallbackIblKtx]) which is used whenever the description has no HDRI of its own. This is the editor-preview environment: it lights and reflects, it never replaces the level's sky.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `scene` | `FilamentScene scene` | `scene` alanını (field/property) ve ilişkili veriyi saklar. |
| `fallbackIblKtx` | `Uint8List? fallbackIblKtx` | Neutral KTX1 IBL cubemap used when the description has no HDRI. |
| `applied` | `LuminaSkyDescription? get applied` | The description currently bound to the scene, if any. |
| `skybox` | `FilamentSkybox? get skybox` | The live skybox, or null when the description hides it. |
| `indirectLight` | `FilamentIndirectLight? get indirectLight` | The live indirect light. |
| `dispose` | `void dispose()` | Removes the skybox and indirect light from the scene and destroys them. |

## `lib/src/components/environment/sky_component.dart`

### `class LuminaSkyComponent`

Environment skybox and Image-Based Lighting (IBL) indirect light component for a world.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isColorMode` | `bool isColorMode` | `isColorMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `environmentAssetPath` | `String? environmentAssetPath` | `environmentAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyboxAssetPath` | `String? skyboxAssetPath` | `skyboxAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `showSun` | `bool showSun` | `showSun` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyIntensity` | `double skyIntensity` | `skyIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoaded` | `bool get isLoaded` | Whether asynchronous asset loading and native binding is complete. |
| `loaded` | `Future<void> get loaded` | Future completing when the environment finishes loading and binding. |
| `color` | `Vector4 get color` | Active solid color in color mode (throws [StateError] in environment mode). |
| `color` | `color(Vector4 value)` | `color` işlemini gerçekleştirir. |
| `iblIntensity` | `double get iblIntensity` | IBL ambient indirect light intensity in lux. |
| `iblIntensity` | `iblIntensity(double value)` | `iblIntensity` işlemini gerçekleştirir. |
| `visible` | `bool get visible` | Whether the skybox is visible in the background. |
| `visible` | `visible(bool value)` | `visible` işlemini gerçekleştirir. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/landscape/landscape_component.dart`

### `class LuminaLandscapeComponent`

Renders a sculpted terrain — heightmap tiles plus foliage layers — from a `LANDSCAPE` `.lmas` payload.  This is the single implementation of terrain drawing in the stack: the Landscape sub-editor's preview, the level viewport and generated game code all mount this component, so what a designer sculpts is exactly what ships. The terrain is one [LuminaProceduralMeshComponent] with one section per tile (see [LandscapeSectionMap]); each foliage layer becomes one or more [LuminaInstancedStaticMeshComponent]s built from the real geometry of that layer's mesh asset.  ## Known engine limits, stated rather than hidden  * **No lit terrain material yet.** `createMeshSection` cannot declare a `uv1` attribute, and the gltfio ubershader's *lit* variants require one. The terrain therefore uses the **unlit, vertex-coloured** ubershader variant, with the height ramp baked into the vertex colours, so a tile still reads as terrain. Once procedural mesh sections can declare `uv1`, [buildTerrainMaterial] is the one place to change. * **Foliage is chunked.** Filament caps one instanced renderable at `engine.maxAutomaticInstances` — **64** on the desktop Vulkan backend it was measured on — so a layer's instances are split across that many renderables each. Chunks hold contiguous slices, so batch order matches the payload order. * **Collision is not part of this component.** The terrain does **not** register with `LuminaCollisionSubsystem`: a character will fall through it. What *is* available today is an exact analytic ground query — [sampleHeightAtWorld] and [sampleNormalAtWorld] read the same bilinear heightmap the mesh is built from — so gameplay code can clamp a pawn to the terrain. A real swept collider against the heightmap does not exist yet; until it does, do not assume physics on terrain.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String? assetPath` | The `.lmas` this terrain was authored in, when it was loaded from disk. |
| `quadsPerSection` | `int quadsPerSection` | Quads per terrain tile along each axis (the section granularity). |
| `unitsPerMetre` | `double unitsPerMetre` | Preview/world units per terrain metre. |
| `foliageMeshScale` | `double foliageMeshScale` | Compensates a foliage mesh asset's own authoring unit.  The default is 1.0 — the mesh is placed at the scale it was authored in, with no hidden conversion. A project whose foliage GLBs are centimetre- authored passes 0.01; the Landscape sub-editor passes its own value. |
| `foliageChunkCapacity` | `int? foliageChunkCapacity` | Instances per foliage renderable. Defaults to the engine's real `maxAutomaticInstances`, which is the only honest value. |
| `residencyBudget` | `LandscapeResidencyBudget? residencyBudget` | What may be mounted at once.  Null means "decide from the terrain's size": a terrain of at most [autoStreamTileThreshold] tiles mounts whole, anything larger streams against [LandscapeResidencyBudget]'s defaults. At 8129² the terrain is 16 129 tiles and ~68 M vertices, so mounting it whole is not an option that exists. |
| `data` | `LandscapeData? get data` | The heightmap/foliage payload, once loaded. |
| `sectionMap` | `LandscapeSectionMap? get sectionMap` | The tile map the sections were built from. |
| `terrainMesh` | `LuminaProceduralMeshComponent? get terrainMesh` | The procedural mesh carrying the terrain tiles. |
| `sectionCount` | `int get sectionCount` | Number of terrain tiles currently mounted. |
| `loadError` | `String? get loadError` | Why the payload could not be read, when it could not. |
| `foliageError` | `String? get foliageError` | Why a foliage layer could not be mounted, when one could not. |
| `isTerrainBuilt` | `bool get isTerrainBuilt` | True once the terrain tiles have been created. |
| `foliageChunksOf` | `List<LuminaInstancedStaticMeshComponent> foliageChunksOf(int layerIndex)` | The instanced renderables carrying layer [layerIndex]'s foliage. |
| `foliageChunkCount` | `int get foliageChunkCount` | Total renderables drawing foliage across every layer. |
| `mountedFoliageLayers` | `Iterable<int> get mountedFoliageLayers` | Layer indices that currently have a mounted instance batch. |
| `foliageInstanceCount` | `int foliageInstanceCount(int layerIndex)` | Live instances mounted for layer [layerIndex]. |
| `foliageInstanceTransform` | `Matrix4 foliageInstanceTransform(int layerIndex, int instanceIndex)` | The transform of layer [layerIndex]'s [instanceIndex]-th instance, read back out of the GPU batch it actually lives in. |
| `sampleHeightAtWorld` | `double sampleHeightAtWorld(double worldX, double worldZ)` | Terrain height (world units) under a world-space XZ position.  This is the same bilinear sample the mesh vertices are built from, offset by the component's own world transform, so a pawn clamped to it stands exactly on the drawn surface. |
| `sampleNormalAtWorld` | `Vector3 sampleNormalAtWorld(double worldX, double worldZ)` | Unit surface normal under a world-space XZ position. |
| `containsWorld` | `bool containsWorld(double worldX, double worldZ)` | True when a world XZ position lies inside the terrain footprint. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `ensureBuilt` | `Future<void> ensureBuilt()` | Completes once the terrain tiles **and** every foliage layer are mounted.  Foliage geometry is parsed from real mesh assets, which is asynchronous; terrain is synchronous. Callers that only need the terrain can ignore this. |
| `mountPayload` | `Future<void> mountPayload(LandscapeData payload)` | Replaces the payload and rebuilds every tile and foliage layer from it.  This is what the sub-editor calls when a terrain is opened or resized, and what a level uses to hot-swap a landscape asset. |
| `ensureTerrainMesh` | `LuminaProceduralMeshComponent? ensureTerrainMesh()` | Ensures the empty procedural mesh exists so the editor can push tiles into it. Returns null when there is no live native context. |
| `clearTerrain` | `void clearTerrain()` | Drops every terrain tile (the foliage batches are left alone). |
| `supportsPartialUpdate` | `bool supportsPartialUpdate(int sectionIndex)` | True when tile [sectionIndex] can take a windowed vertex upload.  A tile that does not exist yet can never take one — a fresh component after registration has no sections at all, and answering "yes" there silently drops every upload. |
| `buildTerrainMaterial` | `FilamentMaterialInstance? buildTerrainMaterial()` | The material the terrain tiles are drawn with.  Unlit + vertex colours is the attribute set the ubershader provider can satisfy from a procedural section today (see the class doc's `uv1` note). |
| `effectiveResidencyBudget` | `LandscapeResidencyBudget get effectiveResidencyBudget` | The budget actually in force, after the size-based default. |
| `totalSectionCount` | `int get totalSectionCount` | Total tiles this terrain has, resident or not. |
| `residentSectionCount` | `int get residentSectionCount` | Tiles currently mounted. |
| `residentTriangleCount` | `int get residentTriangleCount` | Triangles currently mounted, summed from the geometry really uploaded. |
| `residentVertexCount` | `int get residentVertexCount` | Vertices currently mounted, read back from the mesh component (i.e. after any MIKKTSPACE split), not from what we asked for. |
| `residentGpuBytes` | `int get residentGpuBytes` | Bytes the resident tiles occupy in GPU vertex and index buffers, computed from each section's real stride and vertex count. |
| `tilesOutsideBudget` | `int get tilesOutsideBudget` | Tiles inside the load radius that the budget could not afford. |
| `residentLods` | `Map<int, int> get residentLods` | Tile index → mounted LOD step. |
| `isSectionResident` | `bool isSectionResident(int sectionIndex) => _residentLod.containsKey(sec...` | True when tile [sectionIndex] is currently mounted. |
| `lodStepOf` | `int lodStepOf(int sectionIndex)` | The LOD step tile [sectionIndex] is mounted at, or 0 when it is not. |
| `rebuildResidentSection` | `bool rebuildResidentSection(int sectionIndex)` | Rebuilds one resident tile from the payload at its current LOD and edge stitching — what a sculpt stroke needs when the tile cannot take a windowed upload (it is decimated, or the tangent builder split it).  Returns false when the tile is not resident, so a caller does not mount terrain the residency budget deliberately left out. |
| `residencyCamera` | `Vector3 get residencyCamera` | The camera position the current residency was solved for. |
| `updateResidency` | `void updateResidency(Vector3 cameraWorld)` | Re-solves residency for a camera at [cameraWorld] and mounts/unmounts tiles to match. |
| `effectiveFoliageChunkCapacity` | `int get effectiveFoliageChunkCapacity` | Instances per foliage renderable, as the engine really allows. |
| `terrainBounds` | `Aabb3 get terrainBounds` | The volume the terrain (and the foliage standing on it) occupies, in component-local units.  Filament bakes a renderable's bounds when it is built, so every foliage chunk is built with this box rather than with whatever instances happened to exist at that moment — otherwise a chunk painted far from the origin is culled against a placeholder box and silently disappears. |
| `addFoliageInstance` | `int addFoliageInstance(int layerIndex, Matrix4 transform)` | Appends one instance to layer [layerIndex]; returns its global index in the layer, or `-1` when the layer is not mounted.  Instances are laid down in contiguous chunks of [effectiveFoliageChunkCapacity], so the batch order always matches the payload order. |
| `removeFoliageInstance` | `void removeFoliageInstance(int layerIndex, int instanceIndex)` | Swap-removes an instance: the layer's last instance moves into the hole, exactly as `LuminaInstancedStaticMeshComponent.removeInstance` does, so a caller mirroring the batch in its own array stays in step. |
| `clearFoliage` | `void clearFoliage()` | Drops every mounted foliage layer (the batches and their renderables). |

### `class _FoliageBatch`

One foliage layer's GPU state: its geometry and material plus the chunked renderables holding its instances.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `meshAssetPath` | `String meshAssetPath` | `meshAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `vb` | `FilamentVertexBuffer vb` | `vb` alanını (field/property) ve ilişkili veriyi saklar. |
| `ib` | `FilamentIndexBuffer ib` | `ib` alanını (field/property) ve ilişkili veriyi saklar. |
| `material` | `FilamentMaterialInstance material` | `material` alanını (field/property) ve ilişkili veriyi saklar. |
| `indexCount` | `int indexCount` | `indexCount` alanını (field/property) ve ilişkili veriyi saklar. |

### `class _FoliageGeometry`

Interleaved foliage vertices in the layout the instanced batch's vertex buffer declares: position `float3`, packed tangent frame `short4`, `uv0` `float2`, colour `ubyte4` — 32 bytes per vertex.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `packed` | `Uint8List packed` | `packed` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int vertexCount` | `vertexCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromParsed` | `static _FoliageGeometry fromParsed(List<double> positions, List<int> ind...` | `fromParsed` işlemini gerçekleştirir. |

## `lib/src/components/landscape/landscape_glb_builder.dart`

### `class LandscapeGlbBuilder`

Turns a landscape payload into an ordinary glTF 2.0 binary.  The main level viewport draws actors through `FilamentAssetLoader`, i.e. from glTF payloads, not from lumina scene components. Rather than teach it a second terrain path, a placed `Landscape` actor carries a glTF proxy of its own heightmap built here — the same heights, the same height ramp in `COLOR_0` as [LandscapeMeshBuilder] bakes into the runtime tiles — so the terrain the designer sculpted is what they see in the level, and picking, bounds and the triangle counter all work unchanged.  This is a *viewport proxy*: at play time (and in generated game code) the terrain is drawn by `LuminaLandscapeComponent` from the same payload, with its tiles, foliage and partial updates. The proxy carries no foliage.

**Yapıcı Metotlar (Constructors):**
- `LandscapeGlbBuilder._()`: `LandscapeGlbBuilder._()` nesnesini ilklendirir.

## `lib/src/components/landscape/landscape_mesh_builder.dart`

### `class LandscapeSectionGeometry`

The vertex/index arrays of one terrain tile, in the exact layout `LuminaProceduralMeshComponent.createMeshSection` expects.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sectionIndex` | `int sectionIndex` | `sectionIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `verticesPerRow` | `int verticesPerRow` | Vertices per row / number of rows actually emitted (after [lodStep]). |
| `rowCount` | `int rowCount` | `rowCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `lodStep` | `int lodStep` | The decimation step this geometry was built with (1 = full detail). |
| `positions` | `Float32List positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `Float32List normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `uv0` | `Float32List uv0` | `uv0` alanını (field/property) ve ilişkili veriyi saklar. |
| `colors` | `Uint8List colors` | `colors` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class LandscapeEdgeSteps`

The LOD steps of a tile's four neighbours.  A tile whose neighbour is coarser must place its shared-edge vertices on the straight line the coarse neighbour draws, or a crack opens along the seam. Steps are powers of two, so the coarse tile's edge samples are a subset of the fine tile's and the fix is exact: every fine vertex between two coarse ones takes the linear interpolation of them.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `north` | `int north` | Step of the neighbour at lower row / higher row / lower column / higher column. 1 means "as fine as this tile", i.e. nothing to stitch. |
| `south` | `int south` | `south` alanını (field/property) ve ilişkili veriyi saklar. |
| `west` | `int west` | `west` alanını (field/property) ve ilişkili veriyi saklar. |
| `east` | `int east` | `east` alanını (field/property) ve ilişkili veriyi saklar. |
| `isFlat` | `bool get isFlat` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LandscapeMeshBuilder`

The one place terrain geometry is derived from a [LandscapeData].  Both the runtime `LuminaLandscapeComponent` and the Landscape sub-editor's preview build their tiles here, so a terrain looks identical in the editor, in the level viewport and in a packaged game.  Tiles duplicate their seam row/column with their neighbours (see [LandscapeSectionMap]), so a height edited on a seam is written into both copies and no crack appears.

**Yapıcı Metotlar (Constructors):**
- `LandscapeMeshBuilder._()`: `LandscapeMeshBuilder._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sampledCount` | `static int sampledCount(int full, int step) => _sampledCount(full, step)` | Number of vertices emitted along an axis of [full] samples at [step].  The last sample is always emitted so the tile keeps its seam vertex even when [step] does not divide `full - 1`. |
| `sampleOffset` | `static int sampleOffset(int i, int full, int step)` | The global grid offset of the [i]-th emitted sample along an axis of [full] samples at [step]. |

## `lib/src/components/landscape/landscape_residency.dart`

### `class LandscapeResidencyBudget`

What a landscape is allowed to keep mounted at once.  At 8129² the terrain is 127 × 127 = 16 129 tiles and ~68 M vertices; every tile mounted at once is not a thing this (or any) machine renders. The budget is the honest statement of that: tiles are mounted nearest-first until one of these limits is reached, and the rest stay unmounted.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `loadRadius` | `double loadRadius` | Radius around the camera inside which tiles may be mounted, in terrain metres. Tiles beyond it are never resident, whatever the budget allows. |
| `maxSections` | `int maxSections` | Hard cap on mounted tiles. |
| `maxTriangles` | `int maxTriangles` | Hard cap on mounted triangles. |
| `lodDistances` | `List<double> lodDistances` | Distance (metres) at which each LOD step takes over, ascending.  `[200, 500, 1200]` means: full detail inside 200 m, every 2nd sample out to 500 m, every 4th out to 1200 m, every 8th beyond. The steps are always powers of two so a tile keeps its seam samples and a coarser neighbour's vertices are a subset of a finer one's — which is what makes the crack-free stitching in [LandscapeMeshBuilder] exact. |
| `lodStepFor` | `int lodStepFor(double distance)` | The LOD step a tile at [distance] metres should use. |

### `class LandscapeResidencyPlan`

The tiles a landscape should have mounted right now, and at what detail.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tileLod` | `Map<int, int> tileLod` | Tile index → LOD step (1 = every sample). |
| `triangles` | `int triangles` | Triangles the plan costs, summed from the real per-tile geometry. |
| `droppedForBudget` | `int droppedForBudget` | Tiles that were inside [LandscapeResidencyBudget.loadRadius] but did not fit the budget — the honest count of what the viewer is not seeing. |
| `sectionCount` | `int get sectionCount` | `sectionCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class LandscapeResidency`

Decides which terrain tiles are resident around a camera.  This is the same model the world-partition subsystem applies to actors — a streaming source with a radius, cells sorted by distance, a residency set that grows and shrinks as the source moves — applied to terrain tiles, which additionally carry a LOD. `LuminaStreamingSourceComponent` is the component form of that source and can drive [solve] directly through its `location` and `loadingRadius`.

**Yapıcı Metotlar (Constructors):**
- `LandscapeResidency._()`: `LandscapeResidency._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `triangleCountOf` | `static int triangleCountOf(LandscapeSectionMap map, int sectionIndex, in...` | Triangles a tile costs at [lodStep]. |

## `lib/src/components/landscape/landscape_section_map.dart`

### `class HeightRect`

Inclusive rectangle of heightmap cells touched by a stroke.

**Yapıcı Metotlar (Constructors):**
- `HeightRect(this.minCol, this.minRow, this.maxCol, this.maxRow)`: `HeightRect(this.minCol, this.minRow, this.maxCol, this.maxRow)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minCol` | `int minCol` | `minCol` alanını (field/property) ve ilişkili veriyi saklar. |
| `minRow` | `int minRow` | `minRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxCol` | `int maxCol` | `maxCol` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxRow` | `int maxRow` | `maxRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `colCount` | `int get colCount` | `colCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rowCount` | `int get rowCount` | `rowCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cellCount` | `int get cellCount` | `cellCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `union` | `HeightRect union(HeightRect other)` | `union` işlemini gerçekleştirir. |
| `inflate` | `HeightRect inflate(int ring, int resolution)` | Grows the rect by [ring] cells, clamped to a [resolution]² grid — used to recompute normals one ring outside the edited cells. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class SectionUpdateWindow`

One contiguous vertex window of a terrain mesh section.  Windows are always **row-contiguous**: a circular brush touches a span of rows, and each section uploads that row span in a single `updateMeshSection(vertexOffset: …)` call — some untouched columns ride along, which is cheaper than one call per row at 64-quad tile width and matches the single-window contract of `updateMeshSection`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sectionIndex` | `int sectionIndex` | `sectionIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `sectionCol` | `int sectionCol` | `sectionCol` alanını (field/property) ve ilişkili veriyi saklar. |
| `sectionRow` | `int sectionRow` | `sectionRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `firstLocalRow` | `int firstLocalRow` | `firstLocalRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `rowCount` | `int rowCount` | `rowCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `verticesPerRow` | `int verticesPerRow` | `verticesPerRow` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexOffset` | `int get vertexOffset` | `vertexOffset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LandscapeSectionMap`

Maps the heightmap grid onto tiled mesh sections.  Sections share their seam rows/columns (each section's vertex grid duplicates its neighbour's edge), so a brush on a seam writes both copies and no crack appears.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gridResolution` | `int gridResolution` | `gridResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `quadsPerSection` | `int quadsPerSection` | `quadsPerSection` alanını (field/property) ve ilişkili veriyi saklar. |
| `sectionsPerSide` | `int get sectionsPerSide` | `sectionsPerSide` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sectionCount` | `int get sectionCount` | `sectionCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `verticesPerRow` | `int get verticesPerRow` | Vertices per row of a full-size section (seam row included). |
| `verticesPerSection` | `int get verticesPerSection` | `verticesPerSection` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sectionIndexAt` | `int sectionIndexAt(int sectionCol, int sectionRow)` | `sectionIndexAt` işlemini gerçekleştirir. |
| `sectionColOf` | `int sectionColOf(int sectionIndex)` | `sectionColOf` işlemini gerçekleştirir. |
| `sectionRowOf` | `int sectionRowOf(int sectionIndex)` | `sectionRowOf` işlemini gerçekleştirir. |
| `firstColumnOf` | `int firstColumnOf(int sectionIndex)` | First global heightmap column of a section. |
| `firstRowOf` | `int firstRowOf(int sectionIndex)` | `firstRowOf` işlemini gerçekleştirir. |
| `verticesPerRowOf` | `int verticesPerRowOf(int sectionIndex)` | Vertices per row of [sectionIndex] (the last section is clipped when the resolution is not a multiple of [quadsPerSection]). |
| `rowsOf` | `int rowsOf(int sectionIndex) => math.min(verticesPerRow, gridResolution ...` | `rowsOf` işlemini gerçekleştirir. |
| `windowsFor` | `List<SectionUpdateWindow> windowsFor(HeightRect rect)` | The upload windows covering [rect], one per affected section. |

## `lib/src/components/environment/exponential_height_fog_component.dart`

### `class LuminaHeightFogSettings`

Exponential Height Fog settings, mapped onto Filament's per-view `FogOptions`. Filament's fog is global and exponential in height, so this is a field-for-field mapping, not an approximation:

| Setting                 | Filament `FogOptions`                 | |-------------------------|---------------------------------------| | Fog Density (/m)        | `density` (/cm)                       | | Fog Height Falloff (/m) | `heightFalloff` (/cm)                 | | Start Distance (cm)     | `distance`                            | | Fog Cutoff Distance (cm)| `cutOffDistance` (0 → infinity)       | | Fog Max Opacity         | `maximumOpacity`                      | | Fog Inscattering Color  | `colorR/G/B`                          | | Use sky colour          | `fogColorFromIbl`                     | | the actor's Z           | `height` (the runtime Y, cm)          |

Density and falloff are per metre in content and divided by [LuminaUnits.unitsPerMetre] once, here.

**Yapıcı Metotlar (Constructors):**

- `const LuminaHeightFogSettings({this.enabled = true, this.fogDensity = 0.02, this.fogHeightFalloff = 0.2, this.startDistance = 0.0, this.fogCutoffDistance = 0.0,...`
- `factory LuminaHeightFogSettings.fromProperties(Map<String, dynamic>? p, {double height = 0.0})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaults` | `static const LuminaHeightFogSettings defaults` |  |
| `defaultInscatteringColor` | `static const Vector3Const defaultInscatteringColor` | The default inscattering colour (0.447, 0.638, 1.0). |
| `enabled` | `final bool enabled` |  |
| `fogDensity` | `final double fogDensity` | Per metre (default 0.02). |
| `fogHeightFalloff` | `final double fogHeightFalloff` | Per metre (default 0.2). |
| `startDistance` | `final double startDistance` | cm. |
| `fogCutoffDistance` | `final double fogCutoffDistance` | cm; 0 means no cutoff. |
| `fogMaxOpacity` | `final double fogMaxOpacity` | 0..1. |
| `inscatteringColor` | `final Vector3Const inscatteringColor` |  |
| `useSkyColor` | `final bool useSkyColor` |  |
| `height` | `final double height` | The fog's reference height in runtime axes (Y up), cm — the fog actor's authored Z. |
| `toProperties` | `Map<String, dynamic> toProperties()` | The editor component's `properties` map (no height: that is the actor's Z). |
| `inscatteringColorHex` | `String get inscatteringColorHex` |  |
| `toFogOptions` | `FogOptions toFogOptions(FogOptions base)` | Filament's options, keeping from [base] what these settings have no field for (sun in-scattering, the sky colour texture). |
| `copyWith` | `LuminaHeightFogSettings copyWith({bool? enabled, double? fogDensity, double? fogHeightFalloff, double? startDi...` |  |

### `class Vector3Const`

A const-able RGB triple (vector_math's `Vector3` has no const constructor).

**Yapıcı Metotlar (Constructors):**

- `const Vector3Const(this.x, this.y, this.z)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `x` | `final double x` |  |
| `y` | `final double y` |  |
| `z` | `final double z` |  |
| `toVector3` | `Vector3 toVector3()` |  |

### `class LuminaExponentialHeightFogComponent`

The runtime form of the Exponential Height Fog actor.

It writes nothing to the view itself: each render prep it publishes its [settings] — with its own world height — onto the world's [LuminaPostProcessBlender], which composes them with the level baseline and any Post Process / Local Fog volumes and applies the result. One per world: a second component replaces the first (Filament has one fog per view) and says so in the log.

**Yapıcı Metotlar (Constructors):**

- `LuminaExponentialHeightFogComponent({super.key, super.location, super.rotation, this.enabled = true, this.fogDensity = 0.02, this.fogHeightFalloff = 0.2, this.s...`
- `factory LuminaExponentialHeightFogComponent.fromProperties(Map<String, dynamic>? properties, {Vector3? location, Quaternion? rotation, bool visible = true,})`: From the editor component's `properties` map (see [LuminaHeightFogSettings.fromProperties]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` |  |
| `fogDensity` | `double fogDensity` |  |
| `fogHeightFalloff` | `double fogHeightFalloff` |  |
| `startDistance` | `double startDistance` |  |
| `fogCutoffDistance` | `double fogCutoffDistance` |  |
| `fogMaxOpacity` | `double fogMaxOpacity` |  |
| `inscatteringColor` | `Vector3 inscatteringColor` |  |
| `useSkyColor` | `bool useSkyColor` |  |
| `visible` | `bool get visible` |  |
| `visible` | `set visible(bool v)` |  |
| `isActive` | `bool get isActive` | Enabled and visible: what the blender sees. |
| `settings` | `LuminaHeightFogSettings get settings` | The settings as published: the fog height is this component's world Y. |

## `lib/src/components/environment/local_fog_volume_component.dart`

### `enum LuminaLocalFogShape`

Shapes a [LuminaLocalFogVolumeComponent] can take.

**Değerler:**

- `sphere`
- `box`

### `class LuminaLocalFogVolumeComponent`

A Local Fog Volume, as far as Filament allows: **an approximation — no volumetric scattering.**

Filament has no local participating media, no ray march and no fog other than the global exponential height fog. This component is therefore two honest pieces:

1. a **fog shell** — a sphere or box with inverted winding, drawn unlit, alpha-blended, depth-tested and shadowless, whose per-vertex alpha is baked from [fogDensity], [radialAttenuation] (alpha falls from the centre to the rim) and [heightFalloff] (alpha falls with height above the centre), tinted by [fogAlbedo]. From outside the camera sees the far interior wall through whatever stands inside; from inside the shell surrounds the camera. It is generated as a small glTF in memory ([LuminaFogShellGlbFactory]) and drawn through the same static mesh path primitives use — no runtime shader compile, so it works wherever primitives do; 2. a [LuminaPostProcessVolume] on the world's blender whose `fogDensityScale` / `fogColor` pull the **global** fog towards the volume's density and albedo while the camera is inside, restored on exit.

Fog phase G and emissive have no Filament counterpart and are not offered.

**Yapıcı Metotlar (Constructors):**

- `LuminaLocalFogVolumeComponent({super.key, super.location, super.rotation, super.scale, this.shape = LuminaLocalFogShape.sphere, this.radius = 500.0, Vector3? ex...`
- `factory LuminaLocalFogVolumeComponent.fromProperties(Map<String, dynamic>? properties, {Vector3? location, Quaternion? rotation, Vector3? scale, bool visible =...`: From the editor component's `properties`: `shape` (`sphere`/`box`), `radius` (cm), `extentX/Y/Z` (Z-up cm → runtime), `fogAlbedoHex`, `fogDensity`, `heightFalloff` (/m), `radialAttenuation`, `enabled`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `densityScalePerUnit` | `static const double densityScalePerUnit` | How much the global fog density is multiplied while the camera is inside: `1 + densityScalePerUnit · fogDensity`. |
| `blenderPriority` | `static const double blenderPriority` | Blender priority: above ordinary Post Process Volumes. |
| `shape` | `LuminaLocalFogShape shape` |  |
| `radius` | `double radius` | Sphere radius, cm. |
| `extent` | `Vector3 extent` | Box half size, cm, runtime axes. |
| `fogAlbedo` | `Vector3 fogAlbedo` |  |
| `fogDensity` | `double fogDensity` | 0..1: the shell's peak alpha, and the global fog scale while inside. |
| `heightFalloff` | `double heightFalloff` | Per metre; 0 = none. Alpha falls with height above the centre. |
| `radialAttenuation` | `double radialAttenuation` | 0 = uniform, 1 = transparent at the rim. |
| `enabled` | `bool enabled` |  |
| `visible` | `bool get visible` |  |
| `visible` | `set visible(bool v)` |  |
| `isActive` | `bool get isActive` |  |
| `fogDensityScale` | `double get fogDensityScale` | The global-fog scale published while the camera is inside. |
| `volume` | `final LuminaPostProcessVolume volume` | The shape the blender evaluates. |
| `shell` | `LuminaStaticMeshComponent? get shell` | The shell renderable, once built (in a registered actor). |
| `shellKey` | `String get shellKey` | The cache key naming the current shell geometry; changes whenever a shell-affecting field changes. |

### `class LuminaFogShellGlbFactory`

Builds the fog shell glTF in memory: an inward-wound sphere or box whose `COLOR_0` alpha carries the fog falloff, with an unlit, alpha-blended material (`KHR_materials_unlit`, `alphaMode: BLEND`, single sided).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `sphereRings` | `static const int sphereRings` |  |
| `sphereSegments` | `static const int sphereSegments` |  |
| `boxSubdivisions` | `static const int boxSubdivisions` | Subdivisions per box face edge, so the vertex alpha gradient reads. |
| `alphaAt` | `static double alphaAt(Vector3 local, {required double reach, required double density, required double heightFa...` | The per-vertex alpha, 0..1, of a shell vertex at [local] (cm, centred). |
| `build` | `static Uint8List build({required LuminaLocalFogShape shape, required double radius, required Vector3 extent, r...` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `luminaLocalFogShapeFrom` | `LuminaLocalFogShape luminaLocalFogShapeFrom(String? name)` |  |

## `lib/src/components/environment/post_process_volume_component.dart`

### `class LuminaPostProcessVolumeComponent`

The runtime form of a Post Process Volume: an oriented box (or unbound volume) with a priority, a blend radius and a blend weight, and a block of per-setting overrides. It registers a [LuminaPostProcessVolume] with the world's [LuminaPostProcessBlender] and keeps its transform and fields current every render prep; the blender decides what the camera sees.

Filament applies one post-process state to the whole view, so the volume blends by camera position — never per pixel.

**Yapıcı Metotlar (Constructors):**

- `LuminaPostProcessVolumeComponent({super.key, super.location, super.rotation, super.scale, Vector3? extent, this.unbound = false, this.enabled = true, this.prior...`
- `factory LuminaPostProcessVolumeComponent.fromProperties(Map<String, dynamic>? properties, {Vector3? location, Quaternion? rotation, Vector3? scale, bool visible...`: From the editor component's `properties`: `extentX/Y/Z` authored Z-up in cm (→ runtime axes), `unbound`, `enabled`, `priority`, `blendRadius`, `blendWeight`, and the override block ([LuminaPostProcessOverrides.fromProperties]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `extent` | `Vector3 extent` | Half size in cm, runtime axes, before the actor's scale. |
| `unbound` | `bool unbound` |  |
| `enabled` | `bool enabled` |  |
| `priority` | `double priority` |  |
| `blendRadius` | `double blendRadius` | cm, outside the box. |
| `blendWeight` | `double blendWeight` | 0..1. |
| `overrides` | `LuminaPostProcessOverrides overrides` |  |
| `visible` | `bool get visible` |  |
| `visible` | `set visible(bool v)` |  |
| `volume` | `final LuminaPostProcessVolume volume` | The shape the blender evaluates (a live object the component updates). |
| `containsPoint` | `bool containsPoint(Vector3 world)` | Whether [world] (runtime axes) is inside the box; unbound → true. |

## `lib/src/components/landscape/landscape_brush_cursor.dart`

### `class LandscapeBrushCursor`

Where and how a sculpt or foliage brush is drawn on a terrain.

Positions and the radius are **world units** — the space of `LuminaLandscapeComponent.sampleHeightAtWorld` — so an editor passes what its raycast returned without knowing the terrain's own scale.

**Yapıcı Metotlar (Constructors):**

- `LandscapeBrushCursor({required this.centerX, required this.centerZ, required this.radius, this.falloff = 0.5, Vector3? color,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `centerX` | `final double centerX` |  |
| `centerZ` | `final double centerZ` |  |
| `radius` | `final double radius` | Outer radius: where the brush's influence ends. |
| `falloff` | `final double falloff` | Fraction of [radius] that fades out; the full-strength core ends at `radius × (1 − falloff)`. |
| `color` | `final Vector3 color` | Linear RGB, 0–1. |

### `enum LandscapeCursorRing`

What a ring of cursor vertices draws.

**Değerler:**

- `fill`: The translucent disc: solid in the core, fading across the falloff band.
- `innerLine`: The crisp ring at the end of the full-strength core (both edges of it).
- `outerLine`: The inner edge of the crisp ring at the brush's radius.
- `outerEdge`: The outermost ring of vertices, exactly at the brush's radius.

### `class LandscapeBrushCursorGeometry`

The cursor mesh: pure maths over a heightmap, with a topology that never changes (so moving or resizing the cursor is one in-place upload).

Vertices are laid out ring by ring, [segments] per ring, and draped on the heightmap's bilinear surface plus a small lift. Colours are premultiplied by their alpha (Filament's translucent blending).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaultSegments` | `static const int defaultSegments` | Vertices per ring. |
| `coreRings` | `static const int coreRings` | Rings in the full-strength core (after the centre) and in the falloff band. |
| `bandRings` | `static const int bandRings` |  |
| `fillAlpha` | `static const int fillAlpha` | Fill opacity in the core, of 255. |
| `lineAlpha` | `static const int lineAlpha` | Opacity of the two crisp rings, of 255. |
| `positions` | `final Float32List positions` |  |
| `uv0` | `final Float32List uv0` |  |
| `colors` | `final Uint8List colors` |  |
| `indices` | `final Uint32List indices` |  |
| `segments` | `final int segments` |  |
| `lineWidth` | `final double lineWidth` | Width of the crisp rings, in the same units as [positions]. |
| `vertexCount` | `int get vertexCount` |  |
| `ringCount` | `int get ringCount` |  |
| `ringTOf` | `double ringTOf(int v)` | Normalised radius (0 centre → 1 rim) of vertex [v]'s ring. |
| `ringOf` | `LandscapeCursorRing ringOf(int v)` | What vertex [v]'s ring draws. |
| `verticesOf` | `List<int> verticesOf(LandscapeCursorRing kind)` | Every vertex of the rings of [kind]. |
| `fillWeight` | `static double fillWeight(double t, double falloff)` | The fill's opacity profile, 0–1: 1 in the core, a smooth fade to 0 across the falloff band. |
| `build` | `static LandscapeBrushCursorGeometry build(LandscapeData data, {required double centerX, required double center...` | Builds the cursor centred on ([centerX], [centerZ]) with [radius] — all in the terrain's own metres — and returns positions scaled by [unitsPerMetre]. |

---

[Önceki: Bileşenler: mesh'ler ve parçacıklar](components-mesh-and-particles.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Girdi (input)](input.md)
