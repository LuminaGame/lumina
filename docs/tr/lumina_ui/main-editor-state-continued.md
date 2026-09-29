[English](../../en/lumina_ui/main-editor-state-continued.md)

# Ana editör: view model ve servisler (devamı)

Ana editör: view model ve servisler sayfasının devamı: `lib/ui/features/main_editor/services/`, `lib/ui/features/main_editor/services/pie_controller/`, `lib/ui/features/main_editor/view_models/`, `lib/ui/features/main_editor/view_models/editor_view_model/` altındaki diğer public dosyalar. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/main_editor/services/asset_editor_category.dart`](#libuifeaturesmain_editorservicesasset_editor_categorydart)
- [`lib/ui/features/main_editor/services/blueprint_play_support.dart`](#libuifeaturesmain_editorservicesblueprint_play_supportdart)
- [`lib/ui/features/main_editor/services/editor_level_lights.dart`](#libuifeaturesmain_editorserviceseditor_level_lightsdart)
- [`lib/ui/features/main_editor/services/editor_level_post_process.dart`](#libuifeaturesmain_editorserviceseditor_level_post_processdart)
- [`lib/ui/features/main_editor/services/editor_preferences.dart`](#libuifeaturesmain_editorserviceseditor_preferencesdart)
- [`lib/ui/features/main_editor/services/editor_transform.dart`](#libuifeaturesmain_editorserviceseditor_transformdart)
- [`lib/ui/features/main_editor/services/environment_actor_properties.dart`](#libuifeaturesmain_editorservicesenvironment_actor_propertiesdart)
- [`lib/ui/features/main_editor/services/light_actor_properties.dart`](#libuifeaturesmain_editorserviceslight_actor_propertiesdart)
- [`lib/ui/features/main_editor/services/pie_controller/editor_pie_game.dart`](#libuifeaturesmain_editorservicespie_controllereditor_pie_gamedart)
- [`lib/ui/features/main_editor/services/pie_debug_projection.dart`](#libuifeaturesmain_editorservicespie_debug_projectiondart)
- [`lib/ui/features/main_editor/services/pie_mouse_capture.dart`](#libuifeaturesmain_editorservicespie_mouse_capturedart)
- [`lib/ui/features/main_editor/services/project_blueprint_functions.dart`](#libuifeaturesmain_editorservicesproject_blueprint_functionsdart)
- [`lib/ui/features/main_editor/services/project_trash.dart`](#libuifeaturesmain_editorservicesproject_trashdart)
- [`lib/ui/features/main_editor/services/standalone_game_runner.dart`](#libuifeaturesmain_editorservicesstandalone_game_runnerdart)
- [`lib/ui/features/main_editor/services/transform_gizmo.dart`](#libuifeaturesmain_editorservicestransform_gizmodart)
- [`lib/ui/features/main_editor/services/widget_blueprint_assets.dart`](#libuifeaturesmain_editorserviceswidget_blueprint_assetsdart)
- [`lib/ui/features/main_editor/view_models/editor_panels_controller.dart`](#libuifeaturesmain_editorview_modelseditor_panels_controllerdart)
- [`lib/ui/features/main_editor/view_models/editor_view_model/blueprints_and_level_blueprints.dart`](#libuifeaturesmain_editorview_modelseditor_view_modelblueprints_and_level_blueprintsdart)
- [`lib/ui/features/main_editor/view_models/editor_view_model/plugin_extensions.dart`](#libuifeaturesmain_editorview_modelseditor_view_modelplugin_extensionsdart)
- [`lib/ui/features/main_editor/view_models/editor_view_model/project_and_levels.dart`](#libuifeaturesmain_editorview_modelseditor_view_modelproject_and_levelsdart)
- [`lib/ui/features/main_editor/view_models/import_jobs_view_model.dart`](#libuifeaturesmain_editorview_modelsimport_jobs_view_modeldart)

## `lib/ui/features/main_editor/services/asset_editor_category.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `subEditorCategoryFor` | `String? subEditorCategoryFor(RealAssetInfo asset, {PluginExtensionRegistry? extensions})` | The sub-editor tab category [asset] opens in (`openSubEditorTab`'s first argument) — the one mapping the Content Browser's double-click, `EditorViewModel.openAssetEditorByPath` (File → New Asset, plugin level access) and the MCP `open_asset_editor` tool all use. |

## `lib/ui/features/main_editor/services/blueprint_play_support.dart`

### `class EditorBlueprintClassRegistry`

Play's Blueprint classes: lumina's [LuminaBlueprintClassRegistry], except that a Blueprint open in an editor plays its document as it is in the editor, compiled but not necessarily saved — Play runs the in-memory class. Every document, open or on disk, reaches the VM without its editor-only comment and reroute nodes, and the project's enum and interface assets are registered with lumina before any class compiles.

**Yapıcı Metotlar (Constructors):**

- `EditorBlueprintClassRegistry(super.projectDir, {super.inputActions, Map<String, LuminaBlueprintDocument> Function()? openDocuments,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `openDocuments` | `final Map<String, LuminaBlueprintDocument> Function() openDocuments` | Open Blueprint editors' documents by project-relative `.lmas` path. |
| `levelClassFor` | `LuminaBlueprintClass? levelClassFor(String levelPath, {List<Map<String, dynamic>>? actorMaps, LuminaLevelBluep...` | [levelPath]'s Level Blueprint: the one open in a Level Blueprint editor as it is there (compiled, not necessarily saved), else the level's stored one — either without its editor-only comment and reroute nodes. |
| `pawnClassPath` | `String? pawnClassPath(ProjectMapsAndModes mapsAndModes)` | The Pawn / Character Blueprint Play possesses for [mapsAndModes]: its Default Pawn Class, else its GameMode Blueprint's; null when neither names one. |

### `class PlayBlocker`

A reason Play did not start: a Blueprint with a compile error, and the node it is on when there is one (a row of Play's compile errors dialog).

**Yapıcı Metotlar (Constructors):**

- `const PlayBlocker({required this.blueprintPath, required this.message, this.nodeId, this.nodeTitle})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `blueprintPath` | `final String blueprintPath` |  |
| `message` | `final String message` |  |
| `nodeId` | `final String? nodeId` |  |
| `nodeTitle` | `final String? nodeTitle` |  |
| `blueprintName` | `String get blueprintName` |  |

### `abstract final class BlueprintPlayPreflight`

Play's compile step: open Blueprints whose badge is Dirty or Unknown compile first; then every class Play will use — the GameMode Blueprint, the pawn class and placed Blueprint actors — must load and validate. Warnings never block.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `needsCompile` | `static bool needsCompile(BlueprintEditorViewModel vm)` | Whether an open editor must compile before Play. |
| `relativePath` | `static String relativePath(String projectDir, String path)` |  |
| `compileEditors` | `static Future<List<PlayBlocker>> compileEditors(String projectDir, Iterable<BlueprintEditorViewModel> editors,...` | Compiles [editors] and returns the errors, by Blueprint and node; their warnings go to [warnings] when given. |
| `validate` | `static List<PlayBlocker> validate(EditorBlueprintClassRegistry registry, ProjectMapsAndModes mapsAndModes, Ite...` | Loads and validates the classes Play will use; their warnings go to [warnings] when given. |

### `class BlueprintActorPreview`

How the level viewport draws a placed Blueprint: its first mesh component (the GLB, and that component's transform relative to the actor, composed through its parents as lumina builds them) and, for a Character, its capsule.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintActorPreview({required this.meshAsset, required this.meshRelative, required this.isCharacter, required this.capsuleRadius, required this.capsuleH...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshAsset` | `final String? meshAsset` | The project-relative mesh asset the viewport loads. |
| `meshRelative` | `final Matrix4 meshRelative` | The mesh component's transform relative to the actor, runtime space. |
| `isCharacter` | `final bool isCharacter` |  |
| `capsuleRadius` | `final double capsuleRadius` |  |
| `capsuleHalfHeight` | `final double capsuleHalfHeight` |  |
| `parentClass` | `final String parentClass` |  |
| `read` | `static BlueprintActorPreview? read(String projectDir, String path)` | Reads the Blueprint at [path] (project-relative) in [projectDir]. |
| `of` | `static BlueprintActorPreview of(LuminaBlueprintDocument doc)` |  |

## `lib/ui/features/main_editor/services/editor_level_lights.dart`

### `class EditorLevelLights`

The level's own lights in the edit-mode viewport: every `DirectionalLight` / `PointLight` / `SpotLight` actor becomes the component PIE and the generated game build for it ([EditorPieGame.mapEditorActor] — one conversion, cm Z-up → runtime), in an editor world bound to the viewport's scene. Details edits, gizmo moves, visibility, deletion and undo are followed on every [sync]; a level without light actors is lit by nothing.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `lightTypes` | `static const Set<String> lightTypes` | Actor types realised here (the ones `mapEditorActor` turns into light components). |
| `isAttached` | `bool get isAttached` |  |
| `lightEntities` | `List<int> get lightEntities` | The Filament light entities in the scene now. |
| `components` | `List<LuminaLightComponent> get components` | The light components realised now, for the viewport's exposure metering. |
| `attach` | `void attach(FilamentEngine engine, FilamentScene scene)` | Binds to the viewport's engine and scene (an editor world: it runs no gameplay, only render prep). |
| `sync` | `void sync(Iterable<EditorActorNode> actors, {required bool enabled, bool Function(String id)? isVisible})` | Makes the scene's lights match [actors]: the visible light actors when [enabled] (Lit, Lighting shown, no Play session lighting the scene), none otherwise. |
| `detach` | `void detach()` | Removes every light from the scene and drops the world. |

## `lib/ui/features/main_editor/services/editor_level_post_process.dart`

### `class EditorLevelPostProcess`

The level's environment actors in the edit-mode viewport, the way [EditorLevelLights] runs the level's lights: every `ExponentialHeightFog`, `PostProcessVolume` and `LocalFogVolume` actor becomes the runtime component PIE and the generated game build for it ([EditorPieGame.mapEditorActor] — one conversion), in an editor world bound to the viewport's scene and, for post-processing only, to the viewport's [FilamentView] (`LuminaWorld.attachPostProcessView`: the world never takes the editor camera). lumina's `LuminaPostProcessBlender` then resolves the **baseline** (the editor quality's post-process, with the Environment editor's global Height Fog as the fallback when no fog actor exists), the fog actor and the volumes for the *editor camera*, and applies the result to the very view the level renders — so a fog scrub, a volume edit or flying the camera into a box changes the picture live, and leaving every volume returns the view to the baseline.

Filament's limits apply: one fog per view, one post-process state per view (volumes blend by camera position), no volumetric scattering (a Local Fog Volume is a fog-shell approximation).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` |  |
| `world` | `LuminaWorld? get world` | The editor world running the environment components (null when detached). |
| `blender` | `LuminaPostProcessBlender? get blender` | The blender the editor viewport blends through. |
| `baseline` | `LuminaPostProcessSettings get baseline` | The settings volumes blend from (the editor quality's post-process plus the fallback fog), as last synced. |
| `appliedForTest` | `LuminaPostProcessSettings? get appliedForTest` | Test seam: what the view was last given. |
| `realisedForTest` | `Map<String, LuminaActor> get realisedForTest` | Test seam: the realised runtime components by actor id. |
| `attach` | `void attach(FilamentEngine engine, FilamentScene scene, FilamentView view)` | Binds to the viewport's engine, scene and view. |
| `sync` | `void sync(Iterable<EditorActorNode> actors, {required LuminaPostProcessSettings quality, Map<String, dynamic>?...` | Makes the world match [actors] and applies the blend for the editor camera at [cameraAuthoring] (cm, Z-up). [quality] supplies the baseline (bloom/AO/SSR as the quality popover applies them); [environmentSection] is the level's `metadata.environment` whose `postProcess.fog*` values are the fallback fog when the level has no fog actor. With [enabled] false (a Play session owns the view) nothing is applied and every realised actor leaves the scene. |
| `withFallbackFog` | `static LuminaPostProcessSettings withFallbackFog(LuminaPostProcessSettings quality, Map<String, dynamic>? envi...` | [quality] with the Environment editor's Height Fog section (`environment.postProcess.fogEnabled/fogDensity/fogHeightFalloff/fogColorHex`, per metre → per cm) as its fog — the fallback for a level without a fog actor. Without a section the quality's fog stays. |
| `detach` | `void detach()` | Removes every realised actor and drops the world. |

## `lib/ui/features/main_editor/services/editor_preferences.dart`

### `enum FlightCameraControlType`

Editor Preferences → "Flight Camera Control Type": when W/A/S/D/Q/E fly the level viewport's camera.

**Değerler:**

- `rmbHeld`: W/A/S/D/Q/E fly while the right mouse button is held (the default).
- `always`: W/A/S/D/Q/E fly whenever the viewport has keyboard focus.
- `never`: W/A/S/D/Q/E never move the camera.

**Yapıcı Metotlar (Constructors):**

- `const FlightCameraControlType(this.label)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `label` | `final String label` | The label the preferences show for this choice. |
| `parse` | `static FlightCameraControlType parse(Object? value)` |  |

### `class EditorPreferences`

The editor's per-user preferences (as opposed to the project's Project Settings), in `editor_preferences.json` of the editor's config directory ([LuminaConfigDir]; a temp directory in every test). A change is saved at once.

**Yapıcı Metotlar (Constructors):**

- `factory EditorPreferences.load({Directory? configDir})`: The preferences stored in [configDir] (default: [LuminaConfigDir]); the defaults when the file is missing or unreadable.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` |  |
| `file` | `final File file` |  |
| `flightCameraControl` | `FlightCameraControlType get flightCameraControl` | When W/A/S/D/Q/E fly the level viewport's camera. |
| `importWorkers` | `int get importWorkers` | How many files a batch import converts at once, each in its own background isolate: 1–[maxImportWorkers]. |
| `defaultImportWorkers` | `static const int defaultImportWorkers` |  |
| `maxImportWorkers` | `static const int maxImportWorkers` |  |
| `setImportWorkers` | `void setImportWorkers(int value)` |  |
| `marketplaceUrl` | `String get marketplaceUrl` | The Lumina Marketplace server Window → Marketplace talks to; the local server by default. |
| `defaultMarketplaceUrl` | `static const String defaultMarketplaceUrl` |  |
| `isValidMarketplaceUrl` | `static bool isValidMarketplaceUrl(String value)` | An absolute http(s) URL with a host. |
| `setMarketplaceUrl` | `bool setMarketplaceUrl(String value)` | Returns false (and keeps the current URL) when [value] is not an http(s) URL. |
| `editorBuildMode` | `String get editorBuildMode` | The mode project editors are built in: `release` (default) or `debug` (for plugin authors: asserts, and a debugger can attach). |
| `defaultEditorBuildMode` | `static const String defaultEditorBuildMode` |  |
| `editorBuildModes` | `static const List<String> editorBuildModes` |  |
| `setEditorBuildMode` | `void setEditorBuildMode(String value)` |  |
| `editorBuildKeep` | `int get editorBuildKeep` | How many project editor builds `Clean unused builds` keeps. |
| `defaultEditorBuildKeep` | `static const int defaultEditorBuildKeep` |  |
| `maxEditorBuildKeep` | `static const int maxEditorBuildKeep` |  |
| `setEditorBuildKeep` | `void setEditorBuildKeep(int value)` |  |
| `editorBuildCacheDir` | `String? get editorBuildCacheDir` | The project editor build cache; null = the platform default (`EditorBuildCache.defaultRoot`). |
| `setEditorBuildCacheDir` | `void setEditorBuildCacheDir(String? value)` |  |
| `perProjectEditors` | `bool get perProjectEditors` | Every project opens in its own project editor, built on its first open, even without code plugins. Off, a plugin-less project opens in this editor. |
| `defaultPerProjectEditors` | `static const bool defaultPerProjectEditors` |  |
| `setPerProjectEditors` | `void setPerProjectEditors(bool value)` |  |
| `setFlightCameraControl` | `void setFlightCameraControl(FlightCameraControlType value)` |  |

## `lib/ui/features/main_editor/services/editor_transform.dart`

### `abstract final class EditorTransforms`

Where an editor actor is drawn. Stored transforms are centimetres, Z up; the viewport's Filament scene is the runtime's Y up. The conversion is lumina's [LuminaAxes] — the same rule the generated game and Play-In-Editor use, so the three agree.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `actorMatrix` | `static Matrix4 actorMatrix(EditorActorNode actor)` | [actor]'s transform in the viewport (runtime) space. |
| `matrixFor` | `static Matrix4 matrixFor(List<double> location, List<double> rotation, List<double> scale)` |  |
| `assetUnitScaleFor` | `static double assetUnitScaleFor(EditorActorNode actor)` | Asset units → world units for the mesh [actor] draws: an imported glTF is metres (×100); a primitive's GLB is generated in centimetres. |
| `meshMatrix` | `static Matrix4 meshMatrix(EditorActorNode actor)` | [actorMatrix] followed by the asset unit scale: what a mesh's root is drawn with. |
| `blueprintActorMatrix` | `static Matrix4 blueprintActorMatrix(EditorActorNode actor)` | A placed Blueprint's actor transform: location and rotation only (lumina constructs placed Blueprints without a scale). |

## `lib/ui/features/main_editor/services/environment_actor_properties.dart`

### `class EnvironmentActorProperties`

The placeable environment actors, resolved the one way every consumer agrees on, as `LightActorProperties` does for lights: the catalog seeds the component, the Details panel edits it, the edit-mode viewport (`EditorLevelPostProcess`), Play (`EditorPieGame.mapEditorActor`) and the code generator all read the same `properties` map through lumina's own parsers, so the editor and the game cannot disagree.

Filament's limits, stated once: one global exponential height fog per view (`ExponentialHeightFog` maps to it field for field); one post-process state per view, so a `PostProcessVolume` blends by camera position, never per pixel; no volumetric scattering, so a `LocalFogVolume` is a fog-shell approximation.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `heightFogType` | `static const String heightFogType` |  |
| `postProcessVolumeType` | `static const String postProcessVolumeType` |  |
| `localFogVolumeType` | `static const String localFogVolumeType` |  |
| `heightFogComponentType` | `static const String heightFogComponentType` |  |
| `postProcessVolumeComponentType` | `static const String postProcessVolumeComponentType` |  |
| `localFogVolumeComponentType` | `static const String localFogVolumeComponentType` |  |
| `actorTypes` | `static const Set<String> actorTypes` | Actor types the environment post-process service realises. |
| `isEnvironmentActor` | `static bool isEnvironmentActor(EditorActorNode a)` |  |
| `isVolume` | `static bool isVolume(EditorActorNode a)` |  |
| `componentTypeFor` | `static String? componentTypeFor(String actorType)` | The component type that carries an environment actor's settings. |
| `componentOf` | `static EditorComponentNode? componentOf(EditorActorNode actor)` | [actor]'s settings component, if it has one. |
| `propertiesOf` | `static Map<String, dynamic> propertiesOf(EditorActorNode actor)` | The `properties` map of [actor]'s settings component, or empty. |
| `seedHeightFog` | `static EditorComponentNode seedHeightFog(String actorId)` |  |
| `postProcessVolumeDefaults` | `static Map<String, dynamic> postProcessVolumeDefaults()` | Conventional defaults for the value rows; every override starts off. |
| `seedPostProcessVolume` | `static EditorComponentNode seedPostProcessVolume(String actorId)` |  |
| `localFogVolumeDefaults` | `static Map<String, dynamic> localFogVolumeDefaults()` |  |
| `seedLocalFogVolume` | `static EditorComponentNode seedLocalFogVolume(String actorId)` |  |
| `heightFogActorOf` | `static EditorActorNode? heightFogActorOf(Iterable<EditorActorNode> actors, {bool Function(String id)? isVisibl...` | The level's height fog actor (the first visible `ExponentialHeightFog`), or null when the level has none — then the Environment editor's global Height Fog section is the fallback. |
| `heightFogSettings` | `static LuminaHeightFogSettings heightFogSettings(EditorActorNode actor)` | The settings the height fog actor publishes: its properties with its authored Z as the runtime height. |
| `runtimeTransform` | `static Matrix4 runtimeTransform(EditorActorNode actor)` | The actor's world matrix in runtime axes (the one conversion the viewport, PIE and the generated level share). |
| `runtimeHalfExtent` | `static Vector3 runtimeHalfExtent(EditorActorNode actor)` | The half extent of a volume actor in runtime axes, before its scale (a `PostProcessVolume`'s `extentX/Y/Z`, a box `LocalFogVolume`'s, or a sphere's radius on every axis). |
| `isUnbound` | `static bool isUnbound(EditorActorNode actor)` | Whether a `PostProcessVolume` actor is unbound (draws no box, applies everywhere). |
| `isSphere` | `static bool isSphere(EditorActorNode actor)` | Whether a `LocalFogVolume` actor is a sphere. |
| `signature` | `static String signature(EditorActorNode a)` | Everything that changes what the runtime component does, for change detection. |

## `lib/ui/features/main_editor/services/light_actor_properties.dart`

### `class LightActorProperties`

A light actor's settings, resolved the one way every consumer agrees on: the Details panel's "Light" section, the edit-mode viewport (`EditorLevelLights`), Play (`EditorPieGame.mapEditorActor`) and the code generator all read the light's own component (`LuminaDirectionalLightComponent` / `LuminaPointLightComponent` / `LuminaSpotLightComponent`, the type `componentTypeFor` names), falling back to the actor-level `lightIntensity` / `lightColorHex` / `castShadows` that levels from before the section carry.

Units follow the runtime: lux for a directional light, lumens for point and spot lights, centimetres for the attenuation radius, degrees for angles.

**Yapıcı Metotlar (Constructors):**

- `const LightActorProperties({required this.intensity, required this.colorHex, required this.castShadows, required this.attenuationRadius, required this.innerCone...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `intensity` | `final double intensity` |  |
| `colorHex` | `final String colorHex` |  |
| `castShadows` | `final bool castShadows` |  |
| `attenuationRadius` | `final double attenuationRadius` | Point/spot sphere of influence, cm (Attenuation Radius). |
| `innerConeAngle` | `final double innerConeAngle` | Spot cone angles, degrees (`0 < inner <= outer <= 90`). |
| `outerConeAngle` | `final double outerConeAngle` |  |
| `sunAngularRadius` | `final double sunAngularRadius` | The sun disc's angular radius, degrees (directional). |
| `lightActorTypes` | `static const Set<String> lightActorTypes` | Actor types the section applies to. |
| `isLightActor` | `static bool isLightActor(EditorActorNode actor)` |  |
| `componentTypeFor` | `static String componentTypeFor(String actorType)` | The component type that carries a light actor's settings. |
| `defaultAttenuationRadius` | `static const double defaultAttenuationRadius` |  |
| `defaultInnerConeAngle` | `static const double defaultInnerConeAngle` |  |
| `defaultOuterConeAngle` | `static const double defaultOuterConeAngle` |  |
| `defaultSunAngularRadius` | `static const double defaultSunAngularRadius` |  |
| `componentOf` | `static EditorComponentNode? componentOf(EditorActorNode actor)` | The light component of [actor], if it has one. |
| `seedComponent` | `static EditorComponentNode seedComponent(String actorId, String actorType, {required double intensity})` | The component a freshly placed light of [actorType] starts with: the settings the Details panel edits, seeded from the catalog's intensity. |
| `ensureComponent` | `static EditorComponentNode? ensureComponent(EditorActorNode actor)` | Gives an older light actor (actor-level fields only) its component, carrying the values it had, so the Details panel can edit it. Returns the component, existing or new; null for other actors. |
| `read` | `static LightActorProperties read(EditorActorNode actor)` | [actor]'s settings as every consumer sees them. |
| `signature` | `String get signature` | Everything that changes what Filament draws, for change detection. |

## `lib/ui/features/main_editor/services/pie_controller/editor_pie_game.dart`

### `class EditorPieGame`

Declarative game built from the editor's level actors for Play-In-Editor.

Every editor actor is mapped to a real Lumina runtime object via [mapEditorActor]; the resulting tree is mounted into a [LuminaWorld] on the live Filament engine/scene so the simulated world contains the same meshes, lights and pawn the editor shows.

**Yapıcı Metotlar (Constructors):**

- `EditorPieGame(this.editorActors, {this.templateKind = GameTemplateKind.blank, this.input = const BoundProjectInput(contexts: [], actions: {}, unboundKeys: []),...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `editorActors` | `final List<EditorActorNode> editorActors` |  |
| `templateKind` | `final GameTemplateKind templateKind` | Which pawn the project's template scaffolds. `blank` plays the level with no player at all, which is what Simulate means for a level that has no game framework in it. |
| `input` | `final BoundProjectInput input` | The project's own input actions and mapping contexts, bound to the runtime. Rebinding a key in Project Settings changes what Play does. |
| `mannequinMeshPath` | `final String? mannequinMeshPath` | Absolute path of the Third Person character GLB (mesh + merged clips) the possessed character plays, or null for a project that has none. |
| `playerController` | `LuminaPlayerController? playerController` | The local player's controller once [startPlayerSession] has run. |
| `registry` | `final EditorBlueprintClassRegistry? registry` | The project's Blueprint classes: the GameMode Blueprint, the pawn class and placed Blueprint actors play through lumina's registry and VM. Null plays no Blueprints (tests of the template path). |
| `mapsAndModes` | `final ProjectMapsAndModes mapsAndModes` | The project's Maps & Modes: which game mode and pawn class Play uses. |
| `onBlueprintInstance` | `final void Function(LuminaBlueprintInstance instance)? onBlueprintInstance` | Called with every Blueprint instance Play creates (placed actors and the spawned pawn) before its BeginPlay runs. |
| `levelScript` | `final LuminaLevelScriptActor? levelScript` | The level's Blueprint script, attached as the world's level script so Level Loaded runs before any BeginPlay; null when the level has none. |
| `playerPawn` | `LuminaTemplateCharacter? get playerPawn` | The possessed character when it is the Dart template character (First Person and projects whose game mode names no Blueprint pawn), else null. |
| `possessedPawn` | `LuminaPawn? get possessedPawn` | Whatever pawn the local player possesses: a Blueprint pawn running in the VM, or the template character. |
| `playerCamera` | `LuminaCameraComponent? get playerCamera` | The camera Play looks through: the template character's, or the possessed Blueprint pawn's active camera component. |
| `pawnClassLabel` | `String? get pawnClassLabel` | What the status bar names as the running pawn: `BP_ThirdPersonCharacter (VM)` for a Blueprint pawn. |
| `playsBlueprintPawn` | `bool get playsBlueprintPawn` | Whether Play spawns a Blueprint pawn (a GameMode Blueprint, or a Maps & Modes Default Pawn Class). |
| `hasPlayerSession` | `bool get hasPlayerSession` | Whether this project carries a game mode that spawns a player. |
| `providesSunlight` | `bool get providesSunlight` | Whether the running level lights itself with a directional light, so the editor's own preview sun would only double it. |
| `installSubsystems` | `void installSubsystems(LuminaWorld world)` | Registers the subsystems a playing world needs but a mounted tree does not create for itself. |
| `installGameMode` | `void installGameMode(LuminaWorld world)` | Installs the game mode on [world] **before** `beginPlay`, because `LuminaWorld.beginPlay` is what calls `initGame` and creates the game state that `login` adds the player to. |
| `startPlayerSession` | `void startPlayerSession()` | Logs the local player in **after** `beginPlay`: `findPlayerStart` walks the world's levels, which are only populated once the tree has mounted. |
| `mountIntoWorldForTest` | `void mountIntoWorldForTest(LuminaWorld world)` | Mounts the actor tree into [world] and runs the whole play sequence. Used by tests, which have no Filament engine to mount into. |
| `step` | `void step(double deltaTime)` | Frame stepping (the MCP server's `pie_advance`) also in a world mounted for tests, which the base class refuses as "not mounted". |
| `bindsKey` | `bool bindsKey(LuminaKey key)` | Whether the project's mapping contexts bind [key] (PIE swallows only those; every key is still forwarded). |
| `injectedKeysForTest` | `int injectedKeysForTest` | Keys forwarded into the world, and keys that arrived with no input subsystem to take them. The smoke asserts the second stays zero. |
| `droppedKeysForTest` | `int droppedKeysForTest` |  |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | Forwards a key press from the editor viewport into the running world. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key)` | Forwards a key release from the editor viewport into the running world. |
| `injectAnalog` | `void injectAnalog(LuminaKey key, double value)` | Forwards an analog axis value into the running world. |
| `injectMouseDelta` | `void injectMouseDelta(double dx, double dy)` | Forwards a mouse movement, in pixels, into the running world. |
| `nonRuntimeTypes` | `static const Set<String> nonRuntimeTypes` | Editor actor types that carry no runtime representation. |
| `mapEditorActor` | `static LuminaObject? mapEditorActor(EditorActorNode actor, {EditorBlueprintClassRegistry? registry, void Funct...` | Maps an editor actor to its runtime counterpart, or null for organisational nodes such as folders. |
| `eulerDegreesToQuaternion` | `static vm64.Quaternion eulerDegreesToQuaternion(List<double> eulerDeg)` | Converts editor Euler angles in degrees (pitch X, yaw Y, roll Z) to a quaternion using the same XYZ order the viewport applies. |

## `lib/ui/features/main_editor/services/pie_debug_projection.dart`

### `abstract interface class PieDebugProjector`

What the debug-draw layer projects through: the game camera during Play, the editor camera once ejected.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `project` | `Offset? project(Vector3 p)` | The screen position of runtime point [p], or null when off camera. |
| `scaleAt` | `double scaleAt(Vector3 p)` | Pixels one runtime unit spans at [p]'s depth. |

### `class PieFunctionProjector`

A projector over two callbacks (the editor camera's overlay maths).

**Yapıcı Metotlar (Constructors):**

- `const PieFunctionProjector(this._project, this._scaleAt)`

### `class PieCameraProjection`

Projects **runtime** (Y-up, cm) points through the camera Play looks through: the possessed pawn's camera component — its eye, forward and up vectors and vertical field of view — onto the viewport, with the same pinhole model the Filament camera uses, so the debug shapes `LuminaWorld.debugShapes` records land where the renderer draws the world. Pure Dart; the level viewport builds one per frame.

**Yapıcı Metotlar (Constructors):**

- `PieCameraProjection({required this.eye, required Vector3 forward, required Vector3 up, required this.fovDegrees, required this.size,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `eye` | `final Vector3 eye` |  |
| `forward` | `final Vector3 forward` |  |
| `right` | `final Vector3 right` |  |
| `up` | `final Vector3 up` |  |
| `fovDegrees` | `final double fovDegrees` |  |
| `size` | `final Size size` |  |
| `project` | `Offset? project(Vector3 p)` | The screen position of runtime point [p], or null behind the camera. |
| `scaleAt` | `double scaleAt(Vector3 p)` | Pixels one runtime unit spans at [p]'s depth (for radii and sizes). |

## `lib/ui/features/main_editor/services/pie_mouse_capture.dart`

### `class PieMouseCapture`

Play-In-Editor's hold on the mouse: Play gives the game the mouse (hidden and captured), F4 gives the cursor back, a click on the game view takes it again.

Two things decide whether the pointer is captured: - the user's intent, [wantsCapture]: set by Play and by a click, cleared by F4 and by a [MouseCaptureLost] (focus went elsewhere); - whether the game takes input at all: a paused or ejected session gives the pointer back, and takes it again on resume or possess unless the user pressed F4.

Every change of the result is sent to [LuminaMouseCapture.backend], which is a recording backend under tests, smokes and `LUMINA_MOUSE_CAPTURE=off`.

**Yapıcı Metotlar (Constructors):**

- `PieMouseCapture({required this._gameAcceptsInput, required this._onMotion, bool Function()? gameWantsFreeCursor, MouseCaptureBackend Function()? backend,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `centreProvider` | `Offset? Function()? centreProvider` | The game view's centre in the Flutter view's coordinates, supplied by the viewport: where X11 parks the pointer, and where Wayland shows it again on release. |
| `isSessionActive` | `bool get isSessionActive` | Whether a Play session is running. |
| `wantsCapture` | `bool get wantsCapture` | The user's intent: the game should have the mouse. |
| `isCaptured` | `bool get isCaptured` | Whether the game has the mouse right now. |
| `isReleased` | `bool get isReleased` | F4 (or a lost capture) gave the cursor back while the game takes input: a click on the game view takes it again. |
| `hidesCursor` | `bool get hidesCursor` | The cursor is hidden: over the game view, and window-wide when the backend really holds the pointer ([holdsPointer]). |
| `holdsPointer` | `bool get holdsPointer` | The backend holds the pointer in place, so clicks land wherever it was held: the editor shields its whole window while this is true. |
| `acceptsPointerDeltas` | `bool get acceptsPointerDeltas` | Flutter's own pointer deltas turn the game's camera only while captured, and only when the backend does not report relative motion itself. |
| `isLocked` | `bool get isLocked` | The compositor confirmed the current capture. |
| `support` | `MouseCaptureSupport get support` | What the backend can do (unsupported until the first Play asked). |
| `hintEpoch` | `int get hintEpoch` | Bumped at every Play: the viewport shows the F4 hint once per epoch. |
| `begin` | `Future<void> begin() async` | Play started: the game takes the mouse. |
| `end` | `void end()` | Play stopped: the pointer is always given back. |
| `release` | `void release()` | F4: the cursor comes back and the editor can be used; the session keeps running. |
| `recapture` | `void recapture()` | A click on the game view: the game takes the mouse again. |
| `sync` | `void sync()` | Re-reads whether the game takes input (pause, resume, eject, possess). |

## `lib/ui/features/main_editor/services/project_blueprint_functions.dart`

### `class ProjectBlueprintFunctions`

The project's Dart functions exposed to Blueprints: lumina's [BlueprintFunctionScanner] over the project's `lib/`, run when the project opens and whenever a Dart file under `lib/` that mentions `@BlueprintCallable` / `@BlueprintPure` (or did at the last scan) changes on disk — the editor's saves and an IDE's alike, debounced by [debounce].

Each scan writes `lib/blueprint/blueprint_functions.g.dart` and `project.blueprint_functions.json`, declares the functions to this process ([BlueprintFunctionManifest.declareAll]) so the palette, the validator and the code generator know them, and reports the scanner's diagnostics in the Output Log with file and line. The editor never runs project code: in Play In Editor such a node is skipped with a "requires Play Standalone" notice.

**Yapıcı Metotlar (Constructors):**

- `ProjectBlueprintFunctions(this.projectDir, {this.debounce = const Duration(milliseconds: 500), // Warm between scans: a save rescans in well under a second, so...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `debounce` | `final Duration debounce` |  |
| `scanner` | `final BlueprintFunctionScanner scanner` |  |
| `functions` | `List<BlueprintExposedFunction> get functions` | The exposed functions of the last scan (or of the manifest on disk before the first one), sorted by node id. |
| `diagnostics` | `List<BlueprintFunctionDiagnostic> get diagnostics` | The scanner's findings on annotated functions it refused. |
| `isScanning` | `bool get isScanning` |  |
| `isWatching` | `bool get isWatching` |  |
| `scanCount` | `int scanCount` | Scans completed in this session. |
| `lastScanDuration` | `Duration? lastScanDuration` | How long the last scan took (the analyzer resolves `package:lumina` once per scan when any file is annotated). |
| `diagnosticFor` | `BlueprintFunctionDiagnostic? diagnosticFor(String name)` | The diagnostic of the function [name] (`applyDamage`, `Class.method`), if the last scan refused it. |
| `open` | `Future<void> open() async` | Opens the project: the manifest on disk first (the palette is right at once), then a watcher on `lib/` and a fresh scan. |
| `loadManifest` | `void loadManifest()` | Declares what `project.blueprint_functions.json` lists, without scanning. |
| `watch` | `void watch()` | Watches `lib/` for changes to annotated Dart files. |
| `scan` | `Future<void> scan()` | Rescans `lib/`. A scan requested while one runs runs after it; the returned future completes when the newest one has. |

## `lib/ui/features/main_editor/services/project_trash.dart`

### `class TrashedFile`

One file in a trash entry.

**Yapıcı Metotlar (Constructors):**

- `const TrashedFile({required this.original, required this.stored, required this.bytes, required this.sha256})`
- `factory TrashedFile.fromJson(Map<String, dynamic> j)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `original` | `final String original` | Project-relative, `/`-separated. |
| `stored` | `final String stored` | Relative to the entry's folder. |
| `bytes` | `final int bytes` |  |
| `sha256` | `final String sha256` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class TrashEntry`

One trashed deletion: its files and the level actors it removed, under `<project>/.lumina/trash/<id>/` with a `manifest.json`.

**Yapıcı Metotlar (Constructors):**

- `const TrashEntry({required this.id, required this.created, required this.reason, this.origin, required this.files, this.actors = const [],})`
- `factory TrashEntry.fromJson(Map<String, dynamic> j)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `created` | `final DateTime created` |  |
| `reason` | `final String reason` |  |
| `origin` | `final Map<String, Object?>? origin` |  |
| `files` | `final List<TrashedFile> files` |  |
| `actors` | `final List<Map<String, dynamic>> actors` |  |
| `bytes` | `int get bytes` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class TrashConflict`

A restore that would overwrite files that exist again.

**Yapıcı Metotlar (Constructors):**

- `const TrashConflict(this.paths)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `paths` | `final List<String> paths` |  |

### `class ProjectTrash`

The project's recycle bin: deleted assets are moved here, never erased, so undo and `restore_asset` bring them back byte-identical. It lives in the project (next to `editor_layout.json`), so a restore needs no global state; nothing purges it but the user's "Empty trash…".

**Yapıcı Metotlar (Constructors):**

- `ProjectTrash(this.projectDir, {Directory? root})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `root` | `final Directory root` |  |
| `forceCopy` | `bool forceCopy` | Copy + delete instead of rename (what happens across file systems); tests force it to exercise that path. |
| `moveToTrash` | `Future<TrashEntry> moveToTrash(List<String> relativePaths, {required String reason, TransactionOrigin? origin,...` | Moves [relativePaths] (project-relative; missing ones are skipped) into a new entry, with [actors] (the level actors the deletion removed, as maps) in its manifest. |
| `moveToTrashSync` | `TrashEntry moveToTrashSync(List<String> relativePaths, {required String reason, TransactionOrigin? origin, Lis...` | [moveToTrash] without awaiting (an undo / redo step runs synchronously); [id] reuses an entry id (redo puts files back under the id undo took them from). |
| `entry` | `TrashEntry? entry(String id)` |  |
| `restore` | `Future<TrashEntry> restore(String id) async` | Puts entry [id]'s files back and removes the entry; returns it (its actors are for the caller to re-insert). Throws [TrashConflict] naming the paths that exist again, changing nothing. |
| `restoreSync` | `TrashEntry restoreSync(String id)` | [restore] without awaiting. |
| `list` | `List<TrashEntry> list()` | Every entry, newest first. |
| `sizeBytes` | `int get sizeBytes` |  |
| `empty` | `Future<void> empty() async` | Erases everything in the trash. The panel's "Empty trash…" only — no MCP tool may call it (`McpExposure.neverExpose`). |

## `lib/ui/features/main_editor/services/standalone_game_runner.dart`

### `enum StandaloneState`

Where Play Standalone is.

**Değerler:**

- `idle`
- `building`
- `running`

### `class StandaloneGameRunner`

Play Standalone: builds the project with the real `flutter build linux|windows --debug` (the host's platform) and runs the built game as its own process, where everything runs — the project's Dart functions exposed to Blueprints included, which the editor process never executes. The build's and the game's output stream into the Output Log; [stop] kills the game (or the build).

The game is launched from its bundle rather than through `flutter run` so the process Stop kills is the game itself, not a tool that owns it.

**Yapıcı Metotlar (Constructors):**

- `StandaloneGameRunner(this.projectDir, {this.flutterExecutable = 'flutter'})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `flutterExecutable` | `final String flutterExecutable` |  |
| `state` | `StandaloneState get state` |  |
| `isActive` | `bool get isActive` |  |
| `pid` | `int? get pid` | The running game's process id, while it runs. |
| `lastPid` | `int? lastPid` | The id of the last game process started (kept after it ends, so a test can check it is gone). |
| `lastExitCode` | `int? lastExitCode` | How the last game process ended, once it has. |
| `output` | `final List<String> output` | Lines the build and the game printed (also in the Output Log). |
| `gameEnvironment` | `static Map<String, String> gameEnvironment([Map<String, String>? base])` | The environment the game runs in: the editor's, on the GPU the editor renders with (the one chosen in the launcher) unless the environment already picks one. |
| `hostPlatform` | `static String get hostPlatform` | The desktop platform the game is built for: the host's. |
| `bundleExecutable` | `File? bundleExecutable()` | The built game's executable: `build/linux/<arch>/debug/bundle/<name>` on Linux, `build/windows/<arch>/runner/Debug/<name>.exe` on Windows. |
| `start` | `Future<bool> start({Map<String, String>? environment}) async` | Builds and launches the game. Returns whether the game started. |
| `stop` | `Future<void> stop({Duration grace = const Duration(seconds: 3)}) async` | Stops the game (SIGTERM, then SIGKILL after [grace]) or the build, and completes when the process has ended. |

## `lib/ui/features/main_editor/services/transform_gizmo.dart`

### `class TransformGizmoModel`

The transform manipulator both viewports share: the handle layout of the translate / rotate / scale tools, hover hit-testing against the projected handles, and the drag solvers of [GizmoController] wrapped in a drag that remembers where it started.

The model is frame-agnostic: [pivot], [rotation] and every ray are in the caller's frame, and [project] maps that frame to viewport pixels. The level viewport uses its Z-up editor space with its own camera matrix; the Blueprint viewport converts its Y-up runtime camera to the authoring frame in one place (`SubEditor3DViewport`).

**Yapıcı Metotlar (Constructors):**

- `const TransformGizmoModel({required this.mode, required this.space, required this.pivot, required this.rotation, required this.axisLength, required this.planeOf...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `center` | `static const String center` | Handle ids. |
| `axisX` | `static const String axisX` |  |
| `axisY` | `static const String axisY` |  |
| `axisZ` | `static const String axisZ` |  |
| `planeXY` | `static const String planeXY` |  |
| `planeXZ` | `static const String planeXZ` |  |
| `planeYZ` | `static const String planeYZ` |  |
| `uniform` | `static const String uniform` |  |
| `axes` | `static const List<String> axes` |  |
| `planes` | `static const List<String> planes` |  |
| `mode` | `final GizmoMode mode` |  |
| `space` | `final GizmoSpace space` |  |
| `pivot` | `final Vector3 pivot` |  |
| `rotation` | `final Quaternion rotation` | The manipulated object's rotation, used for the local-space axes. |
| `axisLength` | `final double axisLength` | Arrow / stem / ring length in world units. |
| `planeOffset` | `final double planeOffset` | Where a plane quad sits along its two axes, in world units. |
| `orientHandles` | `final bool orientHandles` | Whether the handles are drawn (and hit-tested) along the local axes in local space. The level viewport's native manipulator is never rotated, so it hit-tests along the world axes whatever the space (false). |
| `project` | `final Offset? Function(Vector3 point) project` | Frame → viewport pixels; null when the point is behind the camera. |
| `axisDirection` | `Vector3 axisDirection(String axis)` | The direction of [axis] the drag solves along: the world axis, or the object's own in local space. |
| `planeNormal` | `Vector3 planeNormal(String plane)` | The normal of plane [plane] (`XY` → Z), world or local like [axisDirection]. |
| `handleAxis` | `Vector3 handleAxis(String axis)` | The direction handle [axis] is laid out along (see [orientHandles]). |
| `handleScreenPositions` | `Map<String, Offset>? handleScreenPositions()` | Where each handle is on screen, in viewport-local pixels, or null when the pivot is behind the camera. A handle behind the camera falls back to a fixed offset from the centre so hit-testing never sees a hole. |
| `ringPoints` | `List<Offset?> ringPoints(String axis, {int segments = 24, double? radius})` | The rotate tool's ring around [axis] as projected points (null where a point is behind the camera), [segments] + 1 of them. |
| `hitTest` | `String? hitTest(Offset localPos)` | The handle under [localPos], or null. The tolerances are the level viewport's: 12–16 px for the centre and plane quads, 20 px along an arrow, stem or ring. |
| `beginDrag` | `TransformGizmoDrag beginDrag(String handle, Ray ray, {Vector3? cameraPosition})` | Starts a drag of [handle] with the pointer's [ray]. [cameraPosition] is needed for the translate tool's centre handle (it drags in the plane facing the camera). |
| `distanceToSegment` | `static double distanceToSegment(Offset p, Offset a, Offset b)` | 2D distance from [p] to the segment [a]–[b]. |
| `minScale` | `static const double minScale` | The per-axis scale range. |
| `maxScale` | `static const double maxScale` |  |
| `clampScale` | `static Vector3 clampScale(Vector3 s)` |  |

### `class TransformGizmoDrag`

One drag of a handle: the solvers of [GizmoController] applied against the pivot and ray captured when the drag started, so every update is a delta from the grab point rather than from the previous pointer event.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `model` | `final TransformGizmoModel model` |  |
| `handle` | `final String handle` |  |
| `startPivot` | `final Vector3 startPivot` |  |
| `cameraPosition` | `final Vector3? cameraPosition` |  |
| `translation` | `Vector3 translation(Ray ray)` | Translate: the world-space offset of the pivot since the grab. |
| `rotationAxis` | `Vector3 get rotationAxis` | The axis the rotate tool turns about (world or local). |
| `rotationAngle` | `double rotationAngle(Ray ray)` | Rotate: the angle swept around [rotationAxis] since the grab, in degrees. |
| `scaleTravel` | `double scaleTravel(Ray ray)` | Scale: how far the pointer moved along the stem since the grab, in world units (the caller decides how much scale a unit is worth). |

### `class TransformGizmoSnap`

The toolbar's snap settings as the gizmo applies them: translate quantises the absolute result, rotate and scale the delta.

**Yapıcı Metotlar (Constructors):**

- `const TransformGizmoSnap({this.translateEnabled = false, this.rotateEnabled = false, this.scaleEnabled = false, this.translateStep = 10.0, this.rotateStep = 10....`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `translateEnabled` | `final bool translateEnabled` |  |
| `rotateEnabled` | `final bool rotateEnabled` |  |
| `scaleEnabled` | `final bool scaleEnabled` |  |
| `translateStep` | `final double translateStep` |  |
| `rotateStep` | `final double rotateStep` |  |
| `scaleStep` | `final double scaleStep` |  |
| `none` | `static const TransformGizmoSnap none` |  |
| `copyWith` | `TransformGizmoSnap copyWith({bool? translateEnabled, bool? rotateEnabled, bool? scaleEnabled, double? translat...` |  |
| `location` | `Vector3 location(Vector3 v)` |  |
| `angle` | `double angle(double degrees)` |  |
| `scale` | `double scale(double delta)` |  |

### `abstract final class AuthoringRotation`

Authoring-space (Z-up, degrees) rotation helpers for a gizmo that turns a stored `[x, y, z]` rotation (`LuminaAxes.rotation`) about a world axis.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `toRuntime` | `static Vector3 toRuntime(Vector3 authoring)` | Authoring `(x, y, z)` direction → runtime `(x, z, −y)`. |
| `toAuthoring` | `static Vector3 toAuthoring(Vector3 runtime)` | Runtime `(x, y, z)` direction → authoring `(x, −z, y)`. |
| `quaternionToAuthoring` | `static Quaternion quaternionToAuthoring(Quaternion runtime)` | A runtime-frame rotation expressed in the authoring frame (the same rotation, seen with Z up), so gizmo axes can be built from it. |
| `eulerFromRuntime` | `static List<double> eulerFromRuntime(Quaternion runtime, {List<double>? near})` | The inverse of [LuminaAxes.rotation]: authoring degrees `[x, y, z]` of a runtime-frame [runtime] rotation. A rotation has two Euler solutions; the one nearer [near] (the values the user sees) is returned, each angle unwrapped to within 180° of it, so a yaw-ring drag from `[0, 0, 0]` reads `[0, 0, θ]` rather than `[180, 180, θ − 180]`. |
| `rotatedAboutWorldAxis` | `static List<double> rotatedAboutWorldAxis(List<double> euler, Vector3 axis, double degrees)` | [euler] turned by [degrees] about the authoring-frame world [axis]: `R(axis, θ) · R(euler)`, back in authoring degrees (nearest solution). |

## `lib/ui/features/main_editor/services/widget_blueprint_assets.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kWidgetBlueprintParentClass` | `const String kWidgetBlueprintParentClass` | The parent class that makes a Blueprint a Widget Blueprint (a Blueprint Class whose parent is `UserWidget`). |
| `kWidgetBlueprintFolder` | `const String kWidgetBlueprintFolder` | Where new Widget Blueprints live: the widget designer's own default folder. |
| `createWidgetBlueprintAsset` | `String createWidgetBlueprintAsset({required String projectDirPath, required String name, String folder = kWidg...` | Writes a new Widget Blueprint named [name] (a default designer canvas) under [folder] (default [kWidgetBlueprintFolder]) of [projectDirPath] and returns its path relative to the project. An existing asset is never overwritten: a taken name gets the next free `_<n>` suffix. |
| `isWidgetBlueprintLmas` | `bool isWidgetBlueprintLmas(String? lmasPath)` | Whether the `.lmas` at [lmasPath] is a Widget Blueprint: a widget asset, or an actor Blueprint created with the [kWidgetBlueprintParentClass] parent before such Blueprints were written as widgets. The widget designer opens the latter on a fresh canvas and its first Save writes it as a widget asset. |
| `isWidgetBlueprintSummary` | `bool isWidgetBlueprintSummary(LuminaAssetSummary summary)` | [isWidgetBlueprintLmas] for an asset summary (an asset index entry). |

## `lib/ui/features/main_editor/view_models/editor_panels_controller.dart`

### `class EditorPanelsController`

The host's [EditorPanels]: plugin panel visibility over the editor layout.

A `PanelDefaultDock.right` panel lives in the right dock: open while `pluginPanelVisible[id]`, the dock's active tab `activeRightPanel`. Any other panel is a bottom-panel tab: open while the bottom panel shows its tab. Every change goes through [save] (the view model's `saveLayoutState`, which notifies); [refresh] brings each panel's [visibility] notifier up to date and runs on every such notification.

**Yapıcı Metotlar (Constructors):**

- `EditorPanelsController({required this.layout, required this.panels, required this.bottomTabIndex, required this.save, this.warn,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `layout` | `final EditorLayoutState Function() layout` | The current layout (the view model replaces it when it loads one). |
| `panels` | `final List<EditorPanelDescriptor> Function() panels` | Every registered plugin panel. |
| `bottomTabIndex` | `final int Function(String panelId) bottomTabIndex` | The bottom-panel tab index of a non-right panel, or -1. |
| `save` | `final void Function() save` |  |
| `warn` | `final void Function(String message)? warn` |  |
| `isRight` | `static bool isRight(EditorPanelDescriptor panel)` |  |
| `rightPanels` | `List<EditorPanelDescriptor> get rightPanels` | The right-dock panels, in registration order. |
| `openRightPanels` | `List<EditorPanelDescriptor> get openRightPanels` | The open right-dock panels, in registration order. |
| `activeRightPanel` | `EditorPanelDescriptor? get activeRightPanel` | The right dock's active panel: the saved one while open, else the first open one. |
| `activate` | `void activate(String panelId)` | Makes open right panel [panelId] the dock's active tab. |
| `refresh` | `void refresh()` | Brings every [visibility] notifier up to date. |
| `dispose` | `void dispose()` |  |

## `lib/ui/features/main_editor/view_models/editor_view_model/blueprints_and_level_blueprints.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `contentSubfolderOrNull` | `String? contentSubfolderOrNull(String? folder)` | [folder] as a project-relative `contents/…` subfolder (`blueprints/doors` → `contents/blueprints/doors`), or null for none, the `contents` root, a plugin content root or a path that climbs out. |

## `lib/ui/features/main_editor/view_models/editor_view_model/plugin_extensions.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kBuiltInBottomTabs` | `const int kBuiltInBottomTabs` | The bottom panel's own tabs (Content Browser, Output Log, Blueprint); plugin panels follow them, in registration order. |

## `lib/ui/features/main_editor/view_models/editor_view_model/project_and_levels.dart`

### `enum UnsavedLevelChoice`

What happens to the open level's unsaved changes when another level is opened: saved first, dropped, or the switch is called off.

**Değerler:**

- `save`
- `discard`
- `cancel`

## `lib/ui/features/main_editor/view_models/import_jobs_view_model.dart`

### `class ImportJobsViewModel`

What the import progress panel shows: the batch the editor's [ImportQueue] is running — every file's latest state, counts, elapsed and remaining time — and whether the panel is open, collapsed to its status-bar chip or dismissed.

Listens to the queue only; the Content Browser learns about new assets through [onAssetsLanded], once per written file, never by a rescan.

**Yapıcı Metotlar (Constructors):**

- `ImportJobsViewModel(this.queue, {this.onAssetsLanded, this.onBatchFinished})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `queue` | `final ImportQueue queue` |  |
| `onAssetsLanded` | `final void Function(List<RealAssetInfo> assets)? onAssetsLanded` | A file was written and indexed: its assets, for the Content Browser. |
| `onBatchFinished` | `final void Function(ImportBatchSummary summary)? onBatchFinished` | The batch ended. |
| `autoDismissAfter` | `static const Duration autoDismissAfter` | How long a batch that imported everything stays on screen. |
| `rows` | `List<ImportProgress> get rows` | Every file of the batch, in queue order (read from the queue, which is always current; the events only say when to redraw). |
| `isRunning` | `bool get isRunning` |  |
| `isCancelling` | `bool get isCancelling` |  |
| `total` | `int get total` |  |
| `finished` | `int get finished` |  |
| `imported` | `int get imported` |  |
| `failed` | `int get failed` |  |
| `cancelled` | `int get cancelled` |  |
| `overallFraction` | `double get overallFraction` |  |
| `current` | `ImportProgress? get current` | The file being worked on (the earliest one past `queued`), if any. |
| `failures` | `List<ImportProgress> get failures` | The failed files and why. |
| `summary` | `ImportBatchSummary? get summary` |  |
| `elapsed` | `Duration get elapsed` |  |
| `remaining` | `Duration? get remaining` | Remaining time from the pace so far — per finished file once one is finished, from the batch fraction before — null until there is a pace. |
| `headline` | `String get headline` | `Importing 12 / 51 · SM_AmmoBoxMetal.glb` while running, the outcome afterwards. |
| `chipLabel` | `String get chipLabel` | The status-bar chip: `Importing 12/51`. |
| `visible` | `bool get visible` |  |
| `collapsed` | `bool get collapsed` |  |
| `showDetails` | `bool get showDetails` |  |
| `collapse` | `void collapse()` |  |
| `expand` | `void expand()` |  |
| `toggleDetails` | `void toggleDetails()` |  |
| `dismiss` | `void dismiss()` | Hides the panel (the batch keeps running; the chip stays while it does). |
| `cancel` | `void cancel()` | Stops after the files in progress (they finish and are kept). |

---

[Önceki: Ana editör: view model ve servisler](main-editor-state.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Launcher ve details](launcher-and-details.md)
