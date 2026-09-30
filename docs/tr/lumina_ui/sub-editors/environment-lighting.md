[English](../../../en/lumina_ui/sub-editors/environment-lighting.md)

# Çevre ışıklandırması

Environment Lighting mikseri: canlı bir dünyada önizlenen güneş konumu ve günün saati (güneş matematiğiyle), sky ve IBL, height fog ve post-process kontrolleri. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/environment_lighting_sub_editor.dart`](#libuifeaturessub_editorsviewsenvironment_lighting_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/environment_lighting_view_model.dart`](#libuifeaturessub_editorsview_modelsenvironment_lighting_view_modeldart)
- [`lib/ui/features/sub_editors/services/environment_preview_scene.dart`](#libuifeaturessub_editorsservicesenvironment_preview_scenedart)
- [`lib/ui/features/sub_editors/models/solar_math.dart`](#libuifeaturessub_editorsmodelssolar_mathdart)

## `lib/ui/features/sub_editors/views/environment_lighting_sub_editor.dart`

### `class EnvironmentLightingSubEditor`

Environment Lighting mixer: sun + time of day, sky/IBL, height fog and post-process controls that drive a real lumina world in the viewport and persist into the level's environment actors.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | `editorViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `EnvironmentLightingViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<EnvironmentLightingSubEditor> createState() => _EnvironmentLightin...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _EnvironmentLightingSubEditorState`

`_EnvironmentLightingSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `viewModelForTest` | `EnvironmentLightingViewModel? get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _SunPanel`

`_SunPanel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `EnvironmentLightingViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _RightPanel`

`_RightPanel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `EnvironmentLightingViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class SunGizmo`

Compass-style sun gizmo drawn over the viewport: the ring is the horizon (N up, E right), the centre is the zenith. Dragging the disc sets azimuth (angle) and elevation (distance from the centre) directly; the time slider follows through the view model.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `elevationDeg` | `double elevationDeg` | `elevationDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `azimuthDeg` | `double azimuthDeg` | `azimuthDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunColor` | `Vector3 sunColor` | `sunColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `onDragEnd` | `VoidCallback onDragEnd` | `onDragEnd` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `double size` | `size` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _SunGizmoPainter`

`_SunGizmoPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `elevationDeg` | `double elevationDeg` | `elevationDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `azimuthDeg` | `double azimuthDeg` | `azimuthDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `ringRadius` | `double ringRadius` | `ringRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunColor` | `Color sunColor` | `sunColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _SunGizmoPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/view_models/environment_lighting_view_model.dart`

### `enum EnvironmentSkyMode`

Sky background mode of the level's `LuminaSkyComponent`.

### `class EnvironmentState`

`EnvironmentState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EnvironmentState.defaults()`: Documented defaults: 100 000 lux, 6500 K, no fog, Filament's bloom.
- `EnvironmentState.fromSection(Map<String, dynamic> section)`: `EnvironmentState.fromSection(Map<String, dynamic> section)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeOfDay` | `double timeOfDay` | `timeOfDay` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunElevationDeg` | `double sunElevationDeg` | `sunElevationDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunAzimuthDeg` | `double sunAzimuthDeg` | `sunAzimuthDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunIntensityLux` | `double sunIntensityLux` | `sunIntensityLux` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunKelvin` | `double sunKelvin` | `sunKelvin` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunColorOverride` | `bool sunColorOverride` | `sunColorOverride` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunColorHex` | `String sunColorHex` | `sunColorHex` alanını (field/property) ve ilişkili veriyi saklar. |
| `castShadows` | `bool castShadows` | `castShadows` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunDiscVisible` | `bool sunDiscVisible` | `sunDiscVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyMode` | `EnvironmentSkyMode skyMode` | `skyMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyColorHex` | `String skyColorHex` | `skyColorHex` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyEnvironmentAssetPath` | `String? skyEnvironmentAssetPath` | `skyEnvironmentAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyIntensity` | `double skyIntensity` | `skyIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `iblIntensity` | `double iblIntensity` | `iblIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `skyRotationDeg` | `double skyRotationDeg` | `skyRotationDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `followTimeOfDay` | `bool followTimeOfDay` | `followTimeOfDay` alanını (field/property) ve ilişkili veriyi saklar. |
| `fogEnabled` | `bool fogEnabled` | `fogEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `fogDensity` | `double fogDensity` | `fogDensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `fogHeightFalloff` | `double fogHeightFalloff` | `fogHeightFalloff` alanını (field/property) ve ilişkili veriyi saklar. |
| `fogColorHex` | `String fogColorHex` | `fogColorHex` alanını (field/property) ve ilişkili veriyi saklar. |
| `exposure` | `double exposure` | `exposure` alanını (field/property) ve ilişkili veriyi saklar. |
| `bloomIntensity` | `double bloomIntensity` | `bloomIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `bloomThreshold` | `double bloomThreshold` | `bloomThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `vignette` | `double vignette` | `vignette` alanını (field/property) ve ilişkili veriyi saklar. |
| `saturation` | `double saturation` | `saturation` alanını (field/property) ve ilişkili veriyi saklar. |
| `contrast` | `double contrast` | `contrast` alanını (field/property) ve ilişkili veriyi saklar. |
| `gamma` | `double gamma` | `gamma` alanını (field/property) ve ilişkili veriyi saklar. |
| `effectiveSunColor` | `Vector3 get effectiveSunColor` | The light colour actually sent to the engine: the Kelvin ramp unless a manual override is active. |
| `effectiveSunColorHex` | `String get effectiveSunColorHex` | `effectiveSunColorHex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sunDirection` | `Vector3 get sunDirection` | Unit light direction (Y-up), the final value the runtime consumes. |
| `sunEuler` | `List<double> get sunEuler` | Editor Euler rotation stored on the Sun actor. |
| `sunProperties` | `Map<String, dynamic> get sunProperties` | `sunProperties` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skyProperties` | `Map<String, dynamic> get skyProperties` | `skyProperties` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `postProcessProperties` | `Map<String, dynamic> get postProcessProperties` | `postProcessProperties` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toSection` | `Map<String, dynamic> toSection()` | The level payload's `environment` section. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class EnvironmentLightingViewModel`

View model of the Environment Lighting mixer.  Owns the [EnvironmentState], finds-or-creates the level's environment actors on [open], writes every committed edit through to those actors and the level's `environment` section (marking the level dirty so auto-save picks it up), records one undo transaction per gesture on the editor's [TransactionManager], and pushes live values into the attached [EnvironmentPreviewScene] (a real lumina world on the sub-editor viewport).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel editor` | `editor` alanını (field/property) ve ilişkili veriyi saklar. |
| `preview` | `EnvironmentPreviewScene preview` | `preview` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `EnvironmentState get state` | `state` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isOpened` | `bool get isOpened` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `sunActor` | `EditorActorNode? get sunActor` | `sunActor` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skyActor` | `EditorActorNode? get skyActor` | `skyActor` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `effectiveSunColor` | `Vector3 get effectiveSunColor` | `effectiveSunColor` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sunDirection` | `Vector3 get sunDirection` | `sunDirection` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `timeLabel` | `String get timeLabel` | `timeLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hdriAssets` | `List<String> get hdriAssets` | `.ktx` / `.ktx2` environment maps under the project's `contents/` (relative paths), scanned live from disk. |
| `open` | `void open()` | Finds (or creates, as a real undoable level edit) the `Sun` and `SkyAmbience` actors and loads the persisted state. |
| `setSunColorOverride` | `void setSunColorOverride(bool enabled)` | `SunColorOverride` parametresini günceller ve sisteme uygular. |
| `setCastShadows` | `void setCastShadows(bool value) => _update(_state.copyWith(castShadows: ...` | `CastShadows` parametresini günceller ve sisteme uygular. |
| `setSunDiscVisible` | `void setSunDiscVisible(bool value) => _update(_state.copyWith(sunDiscVis...` | `SunDiscVisible` parametresini günceller ve sisteme uygular. |
| `setSkyMode` | `void setSkyMode(EnvironmentSkyMode mode)` | `SkyMode` parametresini günceller ve sisteme uygular. |
| `setSkyEnvironmentAsset` | `void setSkyEnvironmentAsset(String? relativePath)` | `SkyEnvironmentAsset` parametresini günceller ve sisteme uygular. |
| `setFollowTimeOfDay` | `void setFollowTimeOfDay(bool value)` | `FollowTimeOfDay` parametresini günceller ve sisteme uygular. |
| `setFogEnabled` | `void setFogEnabled(bool value) => _update(_state.copyWith(fogEnabled: va...` | `FogEnabled` parametresini günceller ve sisteme uygular. |
| `resetToDefaults` | `void resetToDefaults()` | Restores the documented defaults as a single undo step. |
| `save` | `Future<bool> save()` | Saves the level (`.lmas` + generated Dart) through the editor. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | Called by the viewport once its lumina world exists on the live engine. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | Called by the viewport right before it cleans the world up. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/sub_editors/services/environment_preview_scene.dart`

### `class EnvironmentPreviewScene`

Drives the Environment Lighting mixer's live viewport through lumina.  The sub-editor viewport hands over a [LuminaWorld] bound to its Filament engine/scene/view; this scene spawns the open level's mesh actors plus a real `LuminaDirectionalLightComponent` (the sun) and `LuminaSkyComponent` into it and applies fog/post-process through `world.postProcess`. Every slider edit lands here via [apply] and is visible on the next frame. No raw flutter_filament calls are made from the editor side.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sun` | `LuminaDirectionalLightComponent? get sun` | `sun` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sky` | `LuminaSkyComponent? get sky` | `sky` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `applied` | `EnvironmentState? get applied` | `applied` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `meshActorCount` | `int get meshActorCount` | Number of level mesh actors mounted into the preview world. |
| `detach` | `void detach()` | Releases every reference; the viewport owns the world's cleanup. |
| `apply` | `void apply(EnvironmentState state)` | Pushes [state] into the live components. Cheap fields update in place; a sky whose mode/asset/intensity changed is rebuilt (the lumina sky component owns its skybox + IBL immutably). |

### `class SolarMathColor`

Hex → RGBA helper shared with the sky component (opaque alpha).

**Yapıcı Metotlar (Constructors):**
- `SolarMathColor._()`: `SolarMathColor._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hexToVector4` | `static Vector4 hexToVector4(String hex)` | `hexToVector4` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/models/solar_math.dart`

### `class SolarMath`

Editor-side solar position and colour-temperature helpers for the Environment Lighting mixer.  These are deterministic editor conveniences, not a sky simulation: the time-of-day slider is mapped onto a simple day arc (sunrise 06:00, zenith at 12:00, sunset 18:00) and the Kelvin slider onto a Planckian-locus approximation. The level and the generated game only ever receive the *final* light values (direction + colour) computed here.

**Yapıcı Metotlar (Constructors):**
- `SolarMath._()`: `SolarMath._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeForAzimuth` | `static double timeForAzimuth(double azimuthDeg)` | Inverse of the azimuth half of [anglesForTime]: the hour at which the sun sits at [azimuthDeg] (used when the viewport gizmo drives the slider). |
| `lightDirection` | `static Vector3 lightDirection(double elevationDeg, double azimuthDeg)` | Direction the sunlight travels (from the sun toward the scene), Y-up, unit length. +X is east, -Z is north. |
| `eulerForAngles` | `static List<double> eulerForAngles(double elevationDeg, double azimuthDeg)` | The stored rotation `[pitch, 0, yaw]` (the level's `[pitch, roll, yaw]`, degrees) whose forward vector (0, 0, -1) equals [lightDirection]; this is what the level actor stores so PIE and the runtime build the same directional light. |
| `eulerForDirection` | `static List<double> eulerForDirection(Vector3 direction)` | The stored rotation `[pitch, 0, yaw]` (the level's `[pitch, roll, yaw]`, degrees) whose drawn −Z equals [direction] (runtime, Y-up), inverting `LuminaAxes.rotation([x, 0, z])` = `Ry(−z)·Rx(x)`: forward = `(sin yaw·cos pitch, sin pitch, −cos yaw·cos pitch)`. |
| `kelvinToRgb` | `static Vector3 kelvinToRgb(double kelvin)` | Linear RGB (0..1) for a colour temperature in Kelvin (Tanner Helland's approximation of the Planckian locus), valid for 1000–40000 K. |
| `rgbToHex` | `static String rgbToHex(Vector3 rgb)` | `#RRGGBB` for a 0..1 RGB vector. |
| `hexToRgb` | `static Vector3 hexToRgb(String hex)` | Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; white on error. |
| `formatTime` | `static String formatTime(double timeOfDay)` | `HH:MM` for a time-of-day in hours. |
| `dayPhase` | `static String dayPhase(double timeOfDay)` | Human day-phase label for the HUD (`14:30 — Afternoon`). |

---

[Önceki: Build yöneticisi](build-manager.md) | [Üst: Alt editörler](index.md) | [Sonraki: Landscape ve foliage](landscape.md)
