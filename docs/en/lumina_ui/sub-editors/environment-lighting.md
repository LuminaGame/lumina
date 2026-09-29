[Türkçe](../../../tr/lumina_ui/sub-editors/environment-lighting.md)

# Environment lighting

The Environment Lighting mixer: sun position and time of day (with solar math), sky and IBL, height fog and post-process controls, previewed in a live world. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/environment_lighting_sub_editor.dart`](#libuifeaturessub_editorsviewsenvironment_lighting_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/environment_lighting_view_model.dart`](#libuifeaturessub_editorsview_modelsenvironment_lighting_view_modeldart)
- [`lib/ui/features/sub_editors/services/environment_preview_scene.dart`](#libuifeaturessub_editorsservicesenvironment_preview_scenedart)
- [`lib/ui/features/sub_editors/models/solar_math.dart`](#libuifeaturessub_editorsmodelssolar_mathdart)

## `lib/ui/features/sub_editors/views/environment_lighting_sub_editor.dart`

### `class EnvironmentLightingSubEditor`

Environment Lighting mixer: sun + time of day, sky/IBL, height fog and post-process controls that drive a real lumina world in the viewport and persist into the level's environment actors.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | Holds the `editorViewModel` property or configuration state. |
| `viewModel` | `EnvironmentLightingViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<EnvironmentLightingSubEditor> createState() => _EnvironmentLightin...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _EnvironmentLightingSubEditorState`

`_EnvironmentLightingSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `viewModelForTest` | `EnvironmentLightingViewModel? get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _SunPanel`

`_SunPanel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `EnvironmentLightingViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _RightPanel`

`_RightPanel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `EnvironmentLightingViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class SunGizmo`

Compass-style sun gizmo drawn over the viewport: the ring is the horizon (N up, E right), the centre is the zenith. Dragging the disc sets azimuth (angle) and elevation (distance from the centre) directly; the time slider follows through the view model.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `elevationDeg` | `double elevationDeg` | Holds the `elevationDeg` property or configuration state. |
| `azimuthDeg` | `double azimuthDeg` | Holds the `azimuthDeg` property or configuration state. |
| `sunColor` | `Vector3 sunColor` | Holds the `sunColor` property or configuration state. |
| `onDragEnd` | `VoidCallback onDragEnd` | Holds the `onDragEnd` property or configuration state. |
| `size` | `double size` | Holds the `size` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _SunGizmoPainter`

`_SunGizmoPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `elevationDeg` | `double elevationDeg` | Holds the `elevationDeg` property or configuration state. |
| `azimuthDeg` | `double azimuthDeg` | Holds the `azimuthDeg` property or configuration state. |
| `ringRadius` | `double ringRadius` | Holds the `ringRadius` property or configuration state. |
| `sunColor` | `Color sunColor` | Holds the `sunColor` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _SunGizmoPainter old)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/view_models/environment_lighting_view_model.dart`

### `enum EnvironmentSkyMode`

Sky background mode of the level's `LuminaSkyComponent`.

### `class EnvironmentState`

`EnvironmentState`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EnvironmentState.defaults()`: Documented defaults: 100 000 lux, 6500 K, no fog, Filament's bloom.
- `EnvironmentState.fromSection(Map<String, dynamic> section)`: Initializes `EnvironmentState.fromSection(Map<String, dynamic> section)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timeOfDay` | `double timeOfDay` | Holds the `timeOfDay` property or configuration state. |
| `sunElevationDeg` | `double sunElevationDeg` | Holds the `sunElevationDeg` property or configuration state. |
| `sunAzimuthDeg` | `double sunAzimuthDeg` | Holds the `sunAzimuthDeg` property or configuration state. |
| `sunIntensityLux` | `double sunIntensityLux` | Holds the `sunIntensityLux` property or configuration state. |
| `sunKelvin` | `double sunKelvin` | Holds the `sunKelvin` property or configuration state. |
| `sunColorOverride` | `bool sunColorOverride` | Holds the `sunColorOverride` property or configuration state. |
| `sunColorHex` | `String sunColorHex` | Holds the `sunColorHex` property or configuration state. |
| `castShadows` | `bool castShadows` | Holds the `castShadows` property or configuration state. |
| `sunDiscVisible` | `bool sunDiscVisible` | Holds the `sunDiscVisible` property or configuration state. |
| `skyMode` | `EnvironmentSkyMode skyMode` | Holds the `skyMode` property or configuration state. |
| `skyColorHex` | `String skyColorHex` | Holds the `skyColorHex` property or configuration state. |
| `skyEnvironmentAssetPath` | `String? skyEnvironmentAssetPath` | Holds the `skyEnvironmentAssetPath` property or configuration state. |
| `skyIntensity` | `double skyIntensity` | Holds the `skyIntensity` property or configuration state. |
| `iblIntensity` | `double iblIntensity` | Holds the `iblIntensity` property or configuration state. |
| `skyRotationDeg` | `double skyRotationDeg` | Holds the `skyRotationDeg` property or configuration state. |
| `followTimeOfDay` | `bool followTimeOfDay` | Holds the `followTimeOfDay` property or configuration state. |
| `fogEnabled` | `bool fogEnabled` | Holds the `fogEnabled` property or configuration state. |
| `fogDensity` | `double fogDensity` | Holds the `fogDensity` property or configuration state. |
| `fogHeightFalloff` | `double fogHeightFalloff` | Holds the `fogHeightFalloff` property or configuration state. |
| `fogColorHex` | `String fogColorHex` | Holds the `fogColorHex` property or configuration state. |
| `exposure` | `double exposure` | Holds the `exposure` property or configuration state. |
| `bloomIntensity` | `double bloomIntensity` | Holds the `bloomIntensity` property or configuration state. |
| `bloomThreshold` | `double bloomThreshold` | Holds the `bloomThreshold` property or configuration state. |
| `vignette` | `double vignette` | Holds the `vignette` property or configuration state. |
| `saturation` | `double saturation` | Holds the `saturation` property or configuration state. |
| `contrast` | `double contrast` | Holds the `contrast` property or configuration state. |
| `gamma` | `double gamma` | Holds the `gamma` property or configuration state. |
| `effectiveSunColor` | `Vector3 get effectiveSunColor` | The light colour actually sent to the engine: the Kelvin ramp unless a manual override is active. |
| `effectiveSunColorHex` | `String get effectiveSunColorHex` | Getter accessor returning the current value of `effectiveSunColorHex`. |
| `sunDirection` | `Vector3 get sunDirection` | Unit light direction (Y-up), the final value the runtime consumes. |
| `sunEuler` | `List<double> get sunEuler` | Editor Euler rotation stored on the Sun actor. |
| `sunProperties` | `Map<String, dynamic> get sunProperties` | Getter accessor returning the current value of `sunProperties`. |
| `skyProperties` | `Map<String, dynamic> get skyProperties` | Getter accessor returning the current value of `skyProperties`. |
| `postProcessProperties` | `Map<String, dynamic> get postProcessProperties` | Getter accessor returning the current value of `postProcessProperties`. |
| `toSection` | `Map<String, dynamic> toSection()` | The level payload's `environment` section. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class EnvironmentLightingViewModel`

View model of the Environment Lighting mixer.  Owns the [EnvironmentState], finds-or-creates the level's environment actors on [open], writes every committed edit through to those actors and the level's `environment` section (marking the level dirty so auto-save picks it up), records one undo transaction per gesture on the editor's [TransactionManager], and pushes live values into the attached [EnvironmentPreviewScene] (a real lumina world on the sub-editor viewport).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editor` | `EditorViewModel editor` | Holds the `editor` property or configuration state. |
| `preview` | `EnvironmentPreviewScene preview` | Holds the `preview` property or configuration state. |
| `state` | `EnvironmentState get state` | Getter accessor returning the current value of `state`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `isOpened` | `bool get isOpened` | Checks current state or capability and returns a boolean value. |
| `sunActor` | `EditorActorNode? get sunActor` | Getter accessor returning the current value of `sunActor`. |
| `skyActor` | `EditorActorNode? get skyActor` | Getter accessor returning the current value of `skyActor`. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Checks current state or capability and returns a boolean value. |
| `effectiveSunColor` | `Vector3 get effectiveSunColor` | Getter accessor returning the current value of `effectiveSunColor`. |
| `sunDirection` | `Vector3 get sunDirection` | Getter accessor returning the current value of `sunDirection`. |
| `timeLabel` | `String get timeLabel` | Getter accessor returning the current value of `timeLabel`. |
| `hdriAssets` | `List<String> get hdriAssets` | `.ktx` / `.ktx2` environment maps under the project's `contents/` (relative paths), scanned live from disk. |
| `open` | `void open()` | Finds (or creates, as a real undoable level edit) the `Sun` and `SkyAmbience` actors and loads the persisted state. |
| `setSunColorOverride` | `void setSunColorOverride(bool enabled)` | Updates the `SunColorOverride` parameter and applies changes to the system. |
| `setCastShadows` | `void setCastShadows(bool value) => _update(_state.copyWith(castShadows: ...` | Updates the `CastShadows` parameter and applies changes to the system. |
| `setSunDiscVisible` | `void setSunDiscVisible(bool value) => _update(_state.copyWith(sunDiscVis...` | Updates the `SunDiscVisible` parameter and applies changes to the system. |
| `setSkyMode` | `void setSkyMode(EnvironmentSkyMode mode)` | Updates the `SkyMode` parameter and applies changes to the system. |
| `setSkyEnvironmentAsset` | `void setSkyEnvironmentAsset(String? relativePath)` | Updates the `SkyEnvironmentAsset` parameter and applies changes to the system. |
| `setFollowTimeOfDay` | `void setFollowTimeOfDay(bool value)` | Updates the `FollowTimeOfDay` parameter and applies changes to the system. |
| `setFogEnabled` | `void setFogEnabled(bool value) => _update(_state.copyWith(fogEnabled: va...` | Updates the `FogEnabled` parameter and applies changes to the system. |
| `resetToDefaults` | `void resetToDefaults()` | Restores the documented defaults as a single undo step. |
| `save` | `Future<bool> save()` | Saves the level (`.lmas` + generated Dart) through the editor. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | Called by the viewport once its lumina world exists on the live engine. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | Called by the viewport right before it cleans the world up. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/services/environment_preview_scene.dart`

### `class EnvironmentPreviewScene`

Drives the Environment Lighting mixer's live viewport through lumina.  The sub-editor viewport hands over a [LuminaWorld] bound to its Filament engine/scene/view; this scene spawns the open level's mesh actors plus a real `LuminaDirectionalLightComponent` (the sun) and `LuminaSkyComponent` into it and applies fog/post-process through `world.postProcess`. Every slider edit lands here via [apply] and is visible on the next frame. No raw flutter_filament calls are made from the editor side.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Checks current state or capability and returns a boolean value. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
| `sun` | `LuminaDirectionalLightComponent? get sun` | Getter accessor returning the current value of `sun`. |
| `sky` | `LuminaSkyComponent? get sky` | Getter accessor returning the current value of `sky`. |
| `applied` | `EnvironmentState? get applied` | Getter accessor returning the current value of `applied`. |
| `meshActorCount` | `int get meshActorCount` | Number of level mesh actors mounted into the preview world. |
| `detach` | `void detach()` | Releases every reference; the viewport owns the world's cleanup. |
| `apply` | `void apply(EnvironmentState state)` | Pushes [state] into the live components. Cheap fields update in place; a sky whose mode/asset/intensity changed is rebuilt (the lumina sky component owns its skybox + IBL immutably). |

### `class SolarMathColor`

Hex → RGBA helper shared with the sky component (opaque alpha).

**Constructors:**
- `SolarMathColor._()`: Initializes `SolarMathColor._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hexToVector4` | `static Vector4 hexToVector4(String hex)` | Executes `hexToVector4` operation. |

## `lib/ui/features/sub_editors/models/solar_math.dart`

### `class SolarMath`

Editor-side solar position and colour-temperature helpers for the Environment Lighting mixer.  These are deterministic editor conveniences, not a sky simulation: the time-of-day slider is mapped onto a simple day arc (sunrise 06:00, zenith at 12:00, sunset 18:00) and the Kelvin slider onto a Planckian-locus approximation. The level and the generated game only ever receive the *final* light values (direction + colour) computed here.

**Constructors:**
- `SolarMath._()`: Initializes `SolarMath._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timeForAzimuth` | `static double timeForAzimuth(double azimuthDeg)` | Inverse of the azimuth half of [anglesForTime]: the hour at which the sun sits at [azimuthDeg] (used when the viewport gizmo drives the slider). |
| `lightDirection` | `static Vector3 lightDirection(double elevationDeg, double azimuthDeg)` | Direction the sunlight travels (from the sun toward the scene), Y-up, unit length. +X is east, -Z is north. |
| `eulerForAngles` | `static List<double> eulerForAngles(double elevationDeg, double azimuthDeg)` | Editor Euler rotation `[pitch, yaw, roll]` in degrees whose forward vector (0, 0, -1) equals [lightDirection]; this is what the level actor stores so PIE and the runtime build the same directional light. |
| `eulerForDirection` | `static List<double> eulerForDirection(Vector3 direction)` | Editor Euler rotation `[pitch, yaw, roll]` (degrees) whose forward vector equals [direction], inverting the editor's `Rz·Ry·Rx` order (`EditorPieGame.eulerDegreesToQuaternion`): forward = `(sin yaw, -sin pitch·cos yaw, -cos pitch·cos yaw)`. |
| `kelvinToRgb` | `static Vector3 kelvinToRgb(double kelvin)` | Linear RGB (0..1) for a colour temperature in Kelvin (Tanner Helland's approximation of the Planckian locus), valid for 1000–40000 K. |
| `rgbToHex` | `static String rgbToHex(Vector3 rgb)` | `#RRGGBB` for a 0..1 RGB vector. |
| `hexToRgb` | `static Vector3 hexToRgb(String hex)` | Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; white on error. |
| `formatTime` | `static String formatTime(double timeOfDay)` | `HH:MM` for a time-of-day in hours. |
| `dayPhase` | `static String dayPhase(double timeOfDay)` | Human day-phase label for the HUD (`14:30 — Afternoon`). |

---

[Previous: Build manager](build-manager.md) | [Up: Sub-editors](index.md) | [Next: Landscape and foliage](landscape.md)
