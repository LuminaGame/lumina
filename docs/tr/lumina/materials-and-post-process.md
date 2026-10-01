[English](../../en/lumina/materials-and-post-process.md)

# Materyaller ve post-processing

Engine düzeyindeki materyal API'si (materyaller, material instance'lar, dynamic material instance'lar ve materyal cache'i) ve post-processing katmanı: post-process ayarları ve controller, scalability profilleri ve gölge ayarları. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | `world` alanını (field/property) ve ilişkili veriyi saklar. |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `view` | `FilamentView view` | `view` alanını (field/property) ve ilişkili veriyi saklar. |
| `applied` | `LuminaPostProcessSettings get applied` | The currently applied post-process settings, or standard defaults if not yet explicitly applied. |
| `appliedShadows` | `LuminaShadowSettings get appliedShadows` | The currently applied shadow settings, or default shadow settings if not yet explicitly applied. |
| `apply` | `void apply(LuminaPostProcessSettings settings)` | Applies the given [settings] to the view, diffing each option family against the previous state. |
| `readBack` | `LuminaPostProcessSettings readBack()` | Reconstructs a [LuminaPostProcessSettings] object by querying the live [FilamentView] getters. |
| `notifyCameraCut` | `void notifyCameraCut()` | Clears temporal anti-aliasing and SSR frame history (e.g. upon camera teleportation). |
| `dispose` | `void dispose()` | Releases resources held by this controller. |

## `lib/src/post_process/post_process_settings.dart`

### `class LuminaColorGradeSettings`

Immutable configuration for the Filament color grading pipeline and tone mapping.

**Yapıcı Metotlar (Constructors):**
- `LuminaColorGradeSettings.defaults() : this._()`: `LuminaColorGradeSettings.defaults() : this._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toneMapper` | `ToneMapperType toneMapper` | `toneMapper` alanını (field/property) ve ilişkili veriyi saklar. |
| `agxLook` | `AgxLook agxLook` | `agxLook` alanını (field/property) ve ilişkili veriyi saklar. |
| `genericContrast` | `double genericContrast` | `genericContrast` alanını (field/property) ve ilişkili veriyi saklar. |
| `genericMidGrayIn` | `double genericMidGrayIn` | `genericMidGrayIn` alanını (field/property) ve ilişkili veriyi saklar. |
| `genericMidGrayOut` | `double genericMidGrayOut` | `genericMidGrayOut` alanını (field/property) ve ilişkili veriyi saklar. |
| `genericHdrMax` | `double genericHdrMax` | `genericHdrMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `quality` | `ColorGradingQuality quality` | `quality` alanını (field/property) ve ilişkili veriyi saklar. |
| `format` | `LutFormat format` | `format` alanını (field/property) ve ilişkili veriyi saklar. |
| `lutDimensions` | `int lutDimensions` | `lutDimensions` alanını (field/property) ve ilişkili veriyi saklar. |
| `exposure` | `double exposure` | `exposure` alanını (field/property) ve ilişkili veriyi saklar. |
| `nightAdaptation` | `double nightAdaptation` | `nightAdaptation` alanını (field/property) ve ilişkili veriyi saklar. |
| `contrast` | `double contrast` | `contrast` alanını (field/property) ve ilişkili veriyi saklar. |
| `vibrance` | `double vibrance` | `vibrance` alanını (field/property) ve ilişkili veriyi saklar. |
| `saturation` | `double saturation` | `saturation` alanını (field/property) ve ilişkili veriyi saklar. |
| `luminanceScaling` | `bool luminanceScaling` | `luminanceScaling` alanını (field/property) ve ilişkili veriyi saklar. |
| `gamutMapping` | `bool gamutMapping` | `gamutMapping` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class LuminaPostProcessSettings`

Immutable value object holding the entire per-view post-process pipeline configuration.

**Yapıcı Metotlar (Constructors):**
- `LuminaPostProcessSettings.standard()`: Factory for standard default settings matching Filament baseline with ACES Legacy.
- `LuminaPostProcessSettings.none()`: Factory for minimal settings with post processing disabled and linear tone mapper.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bloom` | `BloomOptions bloom` | `bloom` alanını (field/property) ve ilişkili veriyi saklar. |
| `depthOfField` | `DepthOfFieldOptions depthOfField` | `depthOfField` alanını (field/property) ve ilişkili veriyi saklar. |
| `vignette` | `VignetteOptions vignette` | `vignette` alanını (field/property) ve ilişkili veriyi saklar. |
| `fog` | `FogOptions fog` | `fog` alanını (field/property) ve ilişkili veriyi saklar. |
| `ambientOcclusion` | `AmbientOcclusionOptions ambientOcclusion` | `ambientOcclusion` alanını (field/property) ve ilişkili veriyi saklar. |
| `taa` | `TemporalAntiAliasingOptions taa` | `taa` alanını (field/property) ve ilişkili veriyi saklar. |
| `msaa` | `MultiSampleAntiAliasingOptions msaa` | `msaa` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenSpaceReflections` | `ScreenSpaceReflectionsOptions screenSpaceReflections` | `screenSpaceReflections` alanını (field/property) ve ilişkili veriyi saklar. |
| `guardBand` | `GuardBandOptions guardBand` | `guardBand` alanını (field/property) ve ilişkili veriyi saklar. |
| `dynamicResolution` | `DynamicResolutionOptions dynamicResolution` | `dynamicResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `renderQuality` | `RenderQuality renderQuality` | `renderQuality` alanını (field/property) ve ilişkili veriyi saklar. |
| `dithering` | `Dithering dithering` | `dithering` alanını (field/property) ve ilişkili veriyi saklar. |
| `antiAliasing` | `AntiAliasing antiAliasing` | `antiAliasing` alanını (field/property) ve ilişkili veriyi saklar. |
| `postProcessingEnabled` | `bool postProcessingEnabled` | `postProcessingEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorGrade` | `LuminaColorGradeSettings colorGrade` | `colorGrade` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

## `lib/src/post_process/scalability_profile.dart`

### `class LuminaScalabilityProfile`

Bundled engine scalability profile governing shadows, quality buffers, and anti-aliasing.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shadows` | `LuminaShadowSettings shadows` | `shadows` alanını (field/property) ve ilişkili veriyi saklar. |
| `renderQuality` | `RenderQuality renderQuality` | `renderQuality` alanını (field/property) ve ilişkili veriyi saklar. |
| `dynamicResolution` | `DynamicResolutionOptions dynamicResolution` | `dynamicResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `taa` | `TemporalAntiAliasingOptions taa` | `taa` alanını (field/property) ve ilişkili veriyi saklar. |
| `msaa` | `MultiSampleAntiAliasingOptions msaa` | `msaa` alanını (field/property) ve ilişkili veriyi saklar. |
| `antiAliasing` | `AntiAliasing antiAliasing` | `antiAliasing` alanını (field/property) ve ilişkili veriyi saklar. |
| `forPreset` | `static LuminaScalabilityProfile forPreset(String preset)` | The profile behind a preset name as the editor and the project manifest spell it (`Low`, `Medium`, `High`, `Epic`, `Cinematic`); anything unrecognised falls back to [epic], which is the manifest default. |
| `withResolutionScale` | `LuminaScalabilityProfile withResolutionScale(double percent)` | This profile rendered at [percent] of the view's resolution.  100 % returns the profile unchanged. Anything else pins Filament's dynamic-resolution scaler to that fixed factor — it is the only knob that changes the internal render resolution without resizing the surface. The value is clamped to 25–200 %. |
| `applyToView` | `void applyToView(FilamentView view)` | Writes the view-level half of this profile into [view].  Shadows are deliberately not written here: they live on the scene's directional light, so they go through `LuminaWorld.applyScalability` / `LuminaPostProcessController.applyShadowSettings`, which have the light and the camera clip planes to work with. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

## `lib/src/post_process/shadow_settings.dart`

### `enum CsmSplitMode`

Calculation scheme for cascaded shadow map (CSM) split planes.

### `class LuminaShadowSettings`

Immutable configuration for directional sun shadows and cascaded shadow maps.

**Yapıcı Metotlar (Constructors):**
- `LuminaShadowSettings.defaults() : this._()`: `LuminaShadowSettings.defaults() : this._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shadowType` | `ShadowType shadowType` | `shadowType` alanını (field/property) ve ilişkili veriyi saklar. |
| `vsm` | `VsmShadowOptions vsm` | `vsm` alanını (field/property) ve ilişkili veriyi saklar. |
| `soft` | `SoftShadowOptions soft` | `soft` alanını (field/property) ve ilişkili veriyi saklar. |
| `mapSize` | `int mapSize` | `mapSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `cascades` | `int cascades` | `cascades` alanını (field/property) ve ilişkili veriyi saklar. |
| `splitMode` | `CsmSplitMode splitMode` | `splitMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `practicalLambda` | `double practicalLambda` | `practicalLambda` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowFar` | `double shadowFar` | `shadowFar` alanını (field/property) ve ilişkili veriyi saklar. |
| `stable` | `bool stable` | `stable` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenSpaceContactShadows` | `bool screenSpaceContactShadows` | `screenSpaceContactShadows` alanını (field/property) ve ilişkili veriyi saklar. |
| `contactShadowsStepCount` | `int contactShadowsStepCount` | `contactShadowsStepCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `constantBias` | `double constantBias` | `constantBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `normalBias` | `double normalBias` | `normalBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

## `lib/src/material/dynamic_material_instance.dart`

### `class LuminaDynamicMaterialInstance`

A dynamic material instance.  Supports per-actor parameter mutations, texture bindings with custom samplers, render-state overrides, and stencil configurations without modifying other instances.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `setScalar` | `void setScalar(String name, double value)` | Sets a scalar float parameter value. |
| `setInt` | `void setInt(String name, int value)` | `Int` parametresini günceller ve sisteme uygular. |
| `setBool` | `void setBool(String name, bool value)` | `Bool` parametresini günceller ve sisteme uygular. |
| `setVector` | `void setVector(String name, Vector4 value)` | Sets a 4-component vector parameter value. |
| `setVector3` | `void setVector3(String name, Vector3 value)` | Sets a 3-component vector parameter value. |
| `setColor` | `void setColor(String name, RgbType type, (double, double, double) rgb)` | Sets a color parameter value with color-space conversion. |
| `setColorRgba` | `void setColorRgba(String name, RgbaType type, (double, double, double, d...` | Sets a 4-component color parameter value with color-space conversion. |
| `setScalarArray` | `void setScalarArray(String name, Float32List values)` | Sets an array of float scalar values. |
| `setVectorArray` | `void setVectorArray(String name, Float32List packed16)` | Sets an array of float4 vector values (packed 4 floats per element). |
| `setMatrixArray` | `void setMatrixArray(String name, Float32List packed64)` | Sets an array of 4x4 matrices (packed 16 floats per element). |
| `setTextureAsset` | `Future<bool> setTextureAsset(String name, String path, {LuminaAssetProvider? assetProvider})` | [path]'deki dokuyu [name] sampler'ına bağlar: bir doku asset'i (`contents/…/T_x.lmas`) ya da bir görüntü dosyası; `LuminaAssets` üzerinden okunur ve bir materyalin kendi dokuları gibi (`LuminaMaterialTextures`) dokunun ayarlarıyla (sRGB, mipmap, filtreleme, sarma) yüklenir, yükleme paylaşılır. Yüklenemezse (bir kez loglanır) ya da aynı [name] için sonraki bir çağrı onu geçtiyse false döner, sampler değişmez. Set Texture Parameter Value bunu çağırır. |
| `texturesLoaded` | `Future<void> get texturesLoaded` | O ana kadar başlayan her `setTextureAsset` yüklemesi bittiğinde tamamlanır. |
| `textureParameter` | `LuminaBoundTexture? textureParameter(String name)` | `setTextureAsset`'in [name] sampler'ına bağladığı doku ya da null; yerine başkası konunca veya instance dispose edilince bırakılır. |
| `cullingMode` | `CullingMode get cullingMode` | Face culling mode override. |
| `cullingMode` | `cullingMode(CullingMode mode) => nativeInstance.setCullingMode(mode)` | `cullingMode` işlemini gerçekleştirir. |
| `isDoubleSided` | `bool get isDoubleSided` | Double-sided rendering override. |
| `isDoubleSided` | `isDoubleSided(bool doubleSided) => nativeInstance.setDoubleSided(doubleS...` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isColorWriteEnabled` | `bool get isColorWriteEnabled` | Color buffer write override. |
| `isColorWriteEnabled` | `isColorWriteEnabled(bool enable) => nativeInstance.setColorWrite(enable)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDepthWriteEnabled` | `bool get isDepthWriteEnabled` | Depth buffer write override. |
| `isDepthWriteEnabled` | `isDepthWriteEnabled(bool enable) => nativeInstance.setDepthWrite(enable)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDepthCullingEnabled` | `bool get isDepthCullingEnabled` | Depth test (culling) override. |
| `isDepthCullingEnabled` | `isDepthCullingEnabled(bool enable) => nativeInstance.setDepthCulling(ena...` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `depthFunc` | `DepthFunc get depthFunc` | Depth comparison function override. |
| `depthFunc` | `depthFunc(DepthFunc func) => nativeInstance.setDepthFunc(func)` | `depthFunc` işlemini gerçekleştirir. |
| `transparencyMode` | `TransparencyMode get transparencyMode` | Transparency mode override. |
| `transparencyMode` | `transparencyMode(TransparencyMode mode) => nativeInstance.setTransparenc...` | `transparencyMode` işlemini gerçekleştirir. |
| `maskThreshold` | `double get maskThreshold` | Mask alpha cutoff threshold override. |
| `maskThreshold` | `maskThreshold(double threshold) => nativeInstance.setMaskThreshold(thres...` | `maskThreshold` işlemini gerçekleştirir. |
| `setPolygonOffset` | `void setPolygonOffset(double scale, double constant)` | Sets the polygon offset for this instance (e.g. for decals). |
| `unsetScissor` | `void unsetScissor()` | Unsets custom scissor rectangle. |
| `setStencilWrite` | `void setStencilWrite(bool enabled) => nativeInstance.setStencilWrite(ena...` | Enables or disables writing to the stencil buffer. |
| `isStencilWriteEnabled` | `bool get isStencilWriteEnabled` | Checks if stencil buffer writing is enabled. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class LuminaPendingDynamicMaterialInstance`

`lib/src/material/dynamic_material_instance.dart`. Bölümün materyal asset'i yüklendiğinde var olan dynamic material instance: bileşenin Material Override'ı (ya da slot materyali) hâlâ yüklenirken (BeginPlay'deki gibi) Create Dynamic Material Instance'ın verdiği değer. Bu arada verilen parametreler, instance yapıldığında sırayla ona uygulanır.

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ready` | `late final Future<LuminaDynamicMaterialInstance?> ready` | Instance; bölüm instance yapılacak bir materyal almadıysa null. |
| `instance` | `LuminaDynamicMaterialInstance? get instance` | `ready` tamamlandıktan sonra instance, öncesinde null. |
| `parameterValues` | `final Map<String, Object?> parameterValues` | Parametre adına göre şimdiye kadar verilen değerler; Blueprint'ler instance yokken de okuyabilsin diye. |
| `whenReady` | `void whenReady(void Function(LuminaDynamicMaterialInstance instance) apply)` | [apply]'ı instance varsa hemen, yoksa yapıldığında çalıştırır (hiç yapılmazsa atılır). |

## `lib/src/material/lumina_material.dart`

### `class LuminaMaterial`

Asset-level wrapper around a compiled Filament material (.filamat) package.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `constants` | `List<MaterialConstant> constants` | `constants` alanını (field/property) ve ilişkili veriyi saklar. |
| `nativeMaterial` | `FilamentMaterial get nativeMaterial` | The underlying native [FilamentMaterial]. |
| `world` | `LuminaWorld get world` | The owning [LuminaWorld]. |
| `textures` | `LuminaMaterialTextures get textures` | Bu materyalin sampler'larına bağlı, her örneğin onlarla başladığı dokular ve yüklenemeyenler. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `material` | `LuminaMaterial material` | `material` alanını (field/property) ve ilişkili veriyi saklar. |
| `isDefaultInstance` | `bool isDefaultInstance` | `isDefaultInstance` alanını (field/property) ve ilişkili veriyi saklar. |
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

`_MaterialCacheKey`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_MaterialCacheKey(this.assetPath, this.constants)`: `_MaterialCacheKey(this.assetPath, this.constants)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `constants` | `List<MaterialConstant> constants` | `constants` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class LuminaMaterialCache`

Refcounted cache of compiled [LuminaMaterial] assets for a world.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld world` | `world` alanını (field/property) ve ilişkili veriyi saklar. |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `createNative` | `static FilamentMaterial createNative(FilamentEngine engine, String assetPath, Uint8List bytes, {List<MaterialConstant> constants = const []})` | [assetPath] baytlarından yerel bir materyal: bir materyal `.lmas` (derlenmiş paketi; Materyal Editörü'nün kaydettiği parametre değerleri varsayılan olur) ya da bir `.filamat`. Derlenmiş materyal yoksa `StateError` fırlatır. |
| `isCompiledPackage` | `static bool isCompiledPackage(Uint8List bytes)` | [bytes] derlenmiş bir `.filamat` paketi mi (Filament başka her şeyde süreci durdurur). |
| `createNativeWithTextureReferences` | `static (FilamentMaterial, List<AssetReference>) createNativeWithTextureReferences(FilamentEngine engine, String assetPath, Uint8List bytes, {List<MaterialConstant> constants = const []})` | `createNative` ve materyal varlığının referansları: her sampler'ın hangi dokuyu çizdiği. `.filamat` için boş. |
| `onMaterialReleased` | `void onMaterialReleased(LuminaMaterial material)` | Internal callback when material refcount drops to zero. |
| `dispose` | `void dispose()` | Disposes all cached materials. |

Önbelleğin yüklediği bir materyalin (`load`; `LuminaStaticMeshComponent.setMaterialAsset`, `materialOverrideAsset` ve mesh slot materyalleri bunu kullanır) sampler dokuları, materyal döndürülmeden önce yüklenip varsayılan örneğine bağlanır; böylece her örnek (ve ondan yapılan bir `LuminaDynamicMaterialInstance`) onları çizer; bkz. `LuminaMaterialTextures`.

### `class LuminaInstanceMaterialOverride`

Hiçbir dünyanın sahip olmadığı bir gltfio örneğinin her bölümüne çizilen tek bir materyal varlığı: editörün seviye görünümü, yerleştirilmiş bir mesh'in atanmış materyalini Play ve derlenmiş oyunun çizdiği gibi gösterir (`LuminaStaticMeshComponent.materialOverrideAsset`).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fromBytes` | `factory LuminaInstanceMaterialOverride.fromBytes(FilamentEngine engine, String assetPath, Uint8List bytes, {LuminaAssetProvider? assetProvider})` | Materyali bir materyal `.lmas` ya da `.filamat` dosyasından, kayıtlı parametre değerleriyle kurar ve sampler'larının adlandırdığı dokuları [assetProvider] (yoksa `LuminaAssets`) üzerinden yüklendiklerinde bağlar; derlenmiş materyal yoksa `StateError`. |
| `texturesLoaded` | `Future<void> texturesLoaded` | Dokular bağlandığında (ya da eksik bulunup her biri bir kez yazıldığında) tamamlanır. |
| `textures` | `LuminaMaterialTextures get textures` | Bağlı dokular; `texturesLoaded`'a kadar boş. `dispose` ile materyalle birlikte bırakılır. |
| `applyTo` | `void applyTo(FilamentAssetInstance instance)` | [instance] içindeki her çizilebilirin her primitifine çizer, her birinin önceki materyalini hatırlar. |
| `restore` | `void restore()` | O bölümlere kendi materyallerini geri verir. |
| `dispose` | `void dispose()` | Bölümleri geri yükler ve materyali yok eder. |

### `class LuminaMaterialTextures`

`lib/src/material/material_textures.dart`. Bir materyal varlığının sampler'larının adlandırdığı dokular, yüklenmiş ve GPU'ya aktarılmış halde. Materyal varlığı hangi dokunun hangi sampler'a gittiğini referanslarında tutar (`slot_name` = sampler parametresi, `asset_path` = yükü görüntü olan bir doku `.lmas`'ı ya da bir görüntü dosyası): glTF içe aktarımı bunları `baseColorMap`, `normalMap`, `metallicRoughnessMap`, `occlusionMap` ve `emissiveMap` için, Materyal Editörü de doku atanan her `sampler2d` için yazar. Dokular `LuminaAssets` üzerinden okunur (editörde ve Play'de projenin dosyaları, derlenmiş oyunda — web dahil — asset paketi; mutlak bir proje yolu orada `contents/…` anahtarı olarak okunur) ve doku varlığının `texture_settings` ayarlarıyla yüklenir: `srgb` (ayar yoksa renk sampler'ları — adında `color`, `albedo`, `diffuse`, `emissive` geçenler — sRGB, diğerleri doğrusal), mipmap'ler (`NoMipmaps` ya da `UI` grubu için yok), `filter` (`Bilinear` → linear-mipmap-nearest, `Trilinear` → linear-mipmap-linear, `Anisotropic 16x` → anizotropi 16 ile trilinear) ve `address_x` / `address_y` (`Wrap`, `Clamp`, `Mirror`). Her doku motor başına bir kez yüklenip paylaşılır, onu bağlayan son materyal bırakıldığında yok edilir. Okunamayan ya da çözülemeyen bir doku bir kez uyarı yazar ve sampler'ı bağlanmadan kalır.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `load` | `static Future<LuminaMaterialTextures> load(FilamentEngine engine, FilamentMaterial material, List<AssetReference> references, {required String materialPath, LuminaAssetProvider? assetProvider})` | [material]'ın bildirdiği sampler'lar için [references]'ın adlandırdığı dokuları yükler. |
| `bound` | `Map<String, LuminaBoundTexture> bound` | Her sampler'a bağlanan doku (`path`, paylaşılan `texture`, `sampler`, `srgb`). |
| `missing` | `Map<String, String> missing` | Bir sampler'ın dokusunun neden bağlanamadığı. |
| `bindTo` | `void bindTo(FilamentMaterialInstance instance)` | Yüklenen her dokuyu [instance] üzerine bağlar; materyalin varsayılan örneğine bağlanınca ondan sonra oluşturulan her örnek onlarla başlar. |
| `release` | `void release()` | Materyal yok edildikten sonra dokuları bırakır. |
| `isColorSampler` | `static bool isColorSampler(String name)` | Bir sampler'ın veri değil renk (sRGB) tuttuğunu adından belirler. |

## `lib/src/post_process/post_process_blender.dart`

### `class LuminaPostProcessBlender`

Post-process volume blending on top of Filament's single per-`View` post-processing state.

Filament has no notion of volumes: one `View` carries one set of options. The blender is the missing layer, in Dart and pure: it starts from the **baseline** (whatever the game or the editor last applied directly), overlays the level's height fog ([LuminaHeightFogSettings]), then walks every registered [LuminaPostProcessVolume] that contains the camera — unbound volumes always — in **priority** order, lerping towards each volume's [LuminaPostProcessOverrides] by its **blend weight** times a **blend-radius** falloff (1 inside, 0 at `blendRadius` outside the shape). The honest limit is that Filament blends the whole view by camera position, never per pixel.

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const LuminaPostProcessResult(this.settings, this.focusDistance)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `settings` | `final LuminaPostProcessSettings settings` |  |
| `focusDistance` | `final double? focusDistance` |  |

### `class LuminaPostProcessOverrides`

A volume's overrides: every field `null` means "not overridden", so it leaves the blended state alone (the per-setting override checkbox).

**Yapıcı Metotlar (Constructors):**

- `const LuminaPostProcessOverrides({this.bloomIntensity, this.bloomThreshold, this.vignette, this.depthOfFieldEnabled, this.dofFocusDistance, this.dofAperture, th...`
- `factory LuminaPostProcessOverrides.fromProperties(Map<String, dynamic> p)`: Reads the editor properties: a value counts only when its `override<Name>` flag is true.

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `LuminaPostProcessResolved({required this.bloomIntensity, required this.bloomThreshold, required this.vignette, required this.depthOfFieldEnabled, required this....`
- `factory LuminaPostProcessResolved.fromSettings(LuminaPostProcessSettings s)`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `LuminaPostProcessVolume({this.enabled = true, this.unbound = false, this.priority = 0.0, this.blendRadius = 100.0, this.blendWeight = 1.0, this.overrides = cons...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

[Önceki: Yapay zeka (AI)](ai.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Render cihazları](rendering.md)
