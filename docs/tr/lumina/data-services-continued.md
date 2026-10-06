[English](../../en/lumina/data-services-continued.md)

# Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)

Veri katmanı: use case'ler ve servisler sayfasının devamı: `lib/data/services/`, `lib/data/services/blueprint_codegen/` altındaki diğer public dosyalar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/data/services/animation_import_binder.dart`](#libdataservicesanimation_import_binderdart)
- [`lib/data/services/app_icon_service.dart`](#libdataservicesapp_icon_servicedart)
- [`lib/data/services/asset_index.dart`](#libdataservicesasset_indexdart)
- [`lib/data/services/base_eye_height_migration.dart`](#libdataservicesbase_eye_height_migrationdart)
- [`lib/data/services/blueprint_class_registry.dart`](#libdataservicesblueprint_class_registrydart)
- [`lib/data/services/blueprint_codegen/blueprint_dart_generator.dart`](#libdataservicesblueprint_codegenblueprint_dart_generatordart)
- [`lib/data/services/blueprint_function_manifest.dart`](#libdataservicesblueprint_function_manifestdart)
- [`lib/data/services/blueprint_function_scanner.dart`](#libdataservicesblueprint_function_scannerdart)
- [`lib/data/services/blueprint_project_assets.dart`](#libdataservicesblueprint_project_assetsdart)
- [`lib/data/services/config_json_file.dart`](#libdataservicesconfig_json_filedart)
- [`lib/data/services/dart_identifiers.dart`](#libdataservicesdart_identifiersdart)
- [`lib/data/services/derived_data_cache.dart`](#libdataservicesderived_data_cachedart)
- [`lib/data/services/editor_build_cache.dart`](#libdataserviceseditor_build_cachedart)
- [`lib/data/services/editor_build_fingerprint.dart`](#libdataserviceseditor_build_fingerprintdart)

## `lib/data/services/animation_import_binder.dart`

### `class SkeletonCandidate`

A project skeletal mesh an imported animation could play on.

**Yapıcı Metotlar (Constructors):**

- `const SkeletonCandidate(this.lmasPath, this.match)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `lmasPath` | `final String lmasPath` | `contents/...lmas`, relative to the project. |
| `match` | `final GlbSkeletonMatch match` |  |

### `class AnimationBinding`

Where an imported animation ended up on its skeletal mesh.

**Yapıcı Metotlar (Constructors):**

- `const AnimationBinding({required this.meshLmasPath, required this.meshAssetId, required this.clips})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshLmasPath` | `final String meshLmasPath` |  |
| `meshAssetId` | `final String meshAssetId` |  |
| `clips` | `final List<GlbRetargetResult> clips` | Retargeting details per clip, in clip order. |

### `abstract final class AnimationImportBinder`

Binds imported animation clips to a project skeletal mesh.

gltfio only plays animations stored in the asset whose nodes they move, so an animation-only import (an Unreal `AS_*.FBX`: skeleton + keys, no mesh) is retargeted onto a skeletal mesh and appended to that mesh's GLB — the `.entity.glb` companion and, when the mesh `.lmas` embeds one, its payload — the way the Third Person template bundles its clips (`tool/build_third_person_content.dart`).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `minimumAutoScore` | `static const double minimumAutoScore` | Least share of the clip's animated bones a skeleton must have to be picked automatically. |
| `meshGlb` | `static Uint8List? meshGlb(String lmasAbsolutePath)` | The GLB a skeletal mesh asset draws: its `.entity.glb` companion, else the `.lmas` payload. |
| `rankTargets` | `static List<SkeletonCandidate> rankTargets({required String projectPath, required List<String> skeletalMeshLma...` | Scores every skeletal mesh in [skeletalMeshLmasPaths] (project-relative) against [clipGlb]'s first animation, best first. Meshes whose GLB cannot be read are left out. |
| `pickTarget` | `static SkeletonCandidate? pickTarget({required String projectPath, required List<String> skeletalMeshLmasPaths...` | The best of [rankTargets] when it clears [minimumAutoScore] with at least three matched bones. |
| `bind` | `static AnimationBinding bind({required String projectPath, required String meshLmasPath, required Uint8List cl...` | Retargets every animation of [clipGlb] onto the skeletal mesh at [meshLmasPath] (project-relative) as [clipNames] (one per animation), writes the mesh's GLB back (companion and embedded payload) and lists the clips in the mesh's `animation_clips` metadata. |
| `clipMetadata` | `static Map<String, String> clipMetadata(String meshLmasPath, GlbRetargetResult result)` | Metadata of an animation asset bound to [meshLmasPath] as clip [result] — the same keys the Third Person template's clip assets carry, so the Animation editor and Animation Blueprints resolve it the same way. |

## `lib/data/services/app_icon_service.dart`

### `class AppIconPlatformResult`

What [AppIconService.write] did for one platform.

**Yapıcı Metotlar (Constructors):**

- `const AppIconPlatformResult(this.platform, {this.files = const [], this.skippedReason, this.warnings = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `platform` | `final String platform` |  |
| `files` | `final List<String> files` | Project-relative paths of the files written. |
| `skippedReason` | `final String? skippedReason` | Why nothing was written (the project has no folder for the platform). |
| `warnings` | `final List<String> warnings` | Notes worth logging: a runner patch that could not find its anchor. |
| `written` | `bool get written` |  |

### `class AppIconReport`

**Yapıcı Metotlar (Constructors):**

- `const AppIconReport(this.platforms)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `platforms` | `final Map<String, AppIconPlatformResult> platforms` |  |
| `writtenFiles` | `List<String> get writtenFiles` |  |
| `summary` | `String summary()` |  |

### `class AppIconService`

Writes a game project's app-icon files for every platform from one high-resolution master PNG: Windows ICO, macOS and iOS icon sets, Android legacy and adaptive mipmaps, the web favicon, icons and manifest, and the Linux runner icon plus the runner/CMake patches that show it. The master is resampled with `package:image`; rasterizing an SVG into that master is the caller's job (the editor uses flutter_svg).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `linuxIconBegin` | `static const String linuxIconBegin` |  |
| `linuxIconEnd` | `static const String linuxIconEnd` |  |
| `cmakeIconBegin` | `static const String cmakeIconBegin` |  |
| `cmakeIconEnd` | `static const String cmakeIconEnd` |  |
| `linuxBundleIconName` | `static const String linuxBundleIconName` | The Linux runner loads this from the bundle's `data/` at startup. |
| `windowsIcoSizes` | `static const List<int> windowsIcoSizes` |  |
| `macosSizes` | `static const List<int> macosSizes` |  |
| `iosSlots` | `static const List<(String, String, String, String, int)> iosSlots = [ ('Icon-App-20x20@2x.png', '20x20', 'ipho...` | Flutter's iOS `AppIcon.appiconset` slots: (filename, size, idiom, scale, pixels). |
| `androidDensities` | `static const Map<String, int> androidDensities` | Android densities and their legacy launcher size (48 dp). |
| `androidSafeZone` | `static const double androidSafeZone` | Adaptive icons are 108 dp and masked to about 66 dp: the foreground keeps the icon inside the middle 66/108. |
| `webMaskableSafeZone` | `static const double webMaskableSafeZone` | Maskable web icons keep their content inside the central 80 %. |
| `writeAsync` | `static Future<AppIconReport> writeAsync({required String projectDir, required Uint8List masterPng, required St...` | [write] on a background isolate, so the editor's UI keeps running while ~50 images are resampled. |
| `write` | `static AppIconReport write({required String projectDir, required Uint8List masterPng, required String appName,...` | Writes the icon files of every platform in [platforms] whose folder the project has; a missing folder is reported, never created. |
| `linuxApplicationId` | `static String? linuxApplicationId(String projectDir)` | `APPLICATION_ID` from the project's `linux/CMakeLists.txt`. |
| `linuxBinaryName` | `static String? linuxBinaryName(String projectDir)` | `BINARY_NAME` from the project's `linux/CMakeLists.txt`. |

### `class LinuxBundleReport`

What [LinuxBundleBranding.finish] did to a packaged Linux bundle.

**Yapıcı Metotlar (Constructors):**

- `const LinuxBundleReport({required this.ok, this.desktopFile, this.gioAvailable = false, this.gioIconSet = false, this.messages = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `desktopFile` | `final String? desktopFile` |  |
| `gioAvailable` | `final bool gioAvailable` |  |
| `gioIconSet` | `final bool gioIconSet` |  |
| `messages` | `final List<String> messages` |  |

### `class LinuxBundleBranding`

Finishes a built Linux bundle so it presents the project icon outside the running window too: a `.desktop` entry in the bundle, and the executable's file-manager icon on this host. An ELF file carries no icon of its own; the file manager reads GIO metadata (`metadata::custom-icon`), which is stored per user on this machine and does not travel with a copy.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `finish` | `static Future<LinuxBundleReport> finish({required String bundleDir, required String executableName, required S...` |  |

## `lib/data/services/asset_index.dart`

### `class AssetIndexEntry`

One `.lmas` of a project as the asset index knows it: its project-relative path, the size and modification time the summary was read at, and the summary.

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexEntry({required this.projectDir, required this.path, required this.size, required this.modifiedMs, required this.summary,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` | Project-relative, `/`-separated (`contents/meshes/static/SM_Rock.lmas`). |
| `size` | `final int size` |  |
| `modifiedMs` | `final int modifiedMs` | Modification time in ms since epoch. |
| `summary` | `final LuminaAssetSummary summary` |  |
| `projectDir` | `final String projectDir` | The project the entry belongs to (absolute). |
| `absolutePath` | `String get absolutePath` |  |
| `file` | `File get file` |  |
| `fileName` | `String get fileName` | `SM_Rock.lmas`. |
| `baseName` | `String get baseName` | `SM_Rock`: the class / asset name callers key by. |
| `modified` | `DateTime get modified` |  |
| `type` | `AssetType get type` |  |
| `metadataValue` | `String? metadataValue(String key)` | `metadata[key]`, read from the file when the index left a large value out. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class AssetIndexChange`

What one refresh changed (project-relative paths).

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexChange({this.added = const [], this.changed = const [], this.removed = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `added` | `final List<String> added` |  |
| `changed` | `final List<String> changed` |  |
| `removed` | `final List<String> removed` |  |
| `isEmpty` | `bool get isEmpty` |  |

### `class AssetIndexRefreshStats`

How the last refresh went — the seam tests use to prove an unchanged project is only stat'ed.

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexRefreshStats({this.files = 0, this.decoded = 0, this.removed = 0, this.elapsed = Duration.zero, this.offThread = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `files` | `final int files` |  |
| `decoded` | `final int decoded` |  |
| `removed` | `final int removed` |  |
| `elapsed` | `final Duration elapsed` |  |
| `offThread` | `final bool offThread` |  |

### `class LuminaAssetIndex`

A project's asset index (asset registry): every `.lmas` under `contents/` with its id, name, type, metadata, references, thumbnail stamps and companion-file times, read without decoding payloads and persisted to `<project>/.lumina/asset_index.json`.

The index is derived data: never the source of truth, always rebuildable. Entries are keyed by project-relative path and validated by size and modification time; [refresh] stats every file and decodes only new or changed ones, in an isolate pool, then drops deleted ones and saves the file atomically. A missing, corrupt or older-format index file rebuilds.

One instance per project directory ([open]); every scan of the editor (content browser, class catalogs, Blueprint registries, PIE, code generation) reads it instead of decoding every `.lmas`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `formatVersion` | `static const int formatVersion` | Bumped whenever the stored summary changes shape. |
| `directoryName` | `static const String directoryName` |  |
| `fileName` | `static const String fileName` |  |
| `open` | `static LuminaAssetIndex open(String projectDir)` | The index of [projectDir] (shared by every caller in this isolate). |
| `close` | `static void close(String projectDir)` | Forgets the in-memory instance of [projectDir] (the file stays). |
| `projectDir` | `final String projectDir` |  |
| `file` | `File get file` | `<project>/.lumina/asset_index.json`. |
| `changes` | `Stream<AssetIndexChange> get changes` | Incremental updates: what each refresh added, changed and removed. |
| `lastRefreshStats` | `AssetIndexRefreshStats get lastRefreshStats` |  |
| `isLoaded` | `bool get isLoaded` | Whether [refresh] / [refreshSync] ran at least once in this session. |
| `entries` | `List<AssetIndexEntry> get entries` | Every indexed asset, sorted by path. |
| `summaries` | `List<LuminaAssetSummary> get summaries` |  |
| `byType` | `List<AssetIndexEntry> byType(AssetType type)` |  |
| `byPath` | `AssetIndexEntry? byPath(String path)` | The entry of [path] (project-relative or absolute), or null. |
| `blueprintDocuments` | `List<AssetIndexEntry> blueprintDocuments(String kind)` | Actor assets whose Blueprint document is of [kind] (`class`, `enum`, `interface`, `save_game`, `montage`, …), sorted by path. |
| `relativePathOf` | `String relativePathOf(String path)` | [path] relative to the project, `/`-separated. |
| `refresh` | `Future<AssetIndexChange> refresh({int? workers, bool? offThread})` | Brings the index up to date with `contents/`: stats every `.lmas` (and its companions), decodes the summaries of new or changed files in an isolate pool, drops deleted files and saves the index when anything changed. Concurrent calls share one refresh. |
| `refreshPaths` | `AssetIndexChange refreshPaths(Iterable<String> paths)` | Indexes just [paths] (`.lmas` files, project-relative or absolute) — what an import just wrote — without walking `contents/`: each is stat'ed and summarised, its companions read from one listing of its folder, and the change is saved and broadcast on [changes]. A listed path that no longer exists is dropped. |
| `offThreadBytes` | `static const int offThreadBytes` | Bytes of `.lmas` to summarise from which [refresh] uses isolates. |
| `shouldSummarizeOffThread` | `static bool shouldSummarizeOffThread(int bytes)` | Whether summarising files totalling [bytes] belongs off the UI isolate. |
| `refreshSync` | `AssetIndexChange refreshSync()` | [refresh] on the calling isolate, for synchronous callers: cheap when the index is warm (stats only), a full summary pass when it is cold. |
| `thumbnailOf` | `Uint8List? thumbnailOf(AssetIndexEntry entry)` | [entry]'s embedded thumbnail, read from its byte range (no payload decode) and kept in memory until the file changes. A texture without one shows its image. Null when the asset has none. |

## `lib/data/services/base_eye_height_migration.dart`

### `class BaseEyeHeightMigrationReport`

What [BaseEyeHeightMigration.run] did to one project.

**Yapıcı Metotlar (Constructors):**

- `const BaseEyeHeightMigrationReport({this.migratedBlueprints = const [], this.patchedGeneratedFiles = const [], this.alreadyMigrated = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `migratedBlueprints` | `final List<String> migratedBlueprints` | Project-relative `.lmas` paths whose class default was rewritten. |
| `patchedGeneratedFiles` | `final List<String> patchedGeneratedFiles` | Project-relative generated `lib/actors/*.dart` files patched to match. |
| `alreadyMigrated` | `final bool alreadyMigrated` | True when the project had already been migrated (the marker exists). |
| `didAnything` | `bool get didAnything` |  |

### `class BaseEyeHeightMigration`

The one-time move of the Third Person template's Base Eye Height to the capsule-centre convention.

`baseEyeHeight` is measured from the actor location, which for a character is the capsule centre. Older projects store the template's feet-based 160 cm in BP_ThirdPersonCharacter's class defaults, which puts the eyes (and every trace) 250 cm above the ground. On project open, every Character Blueprint that still carries exactly that template value — parent `LuminaCharacter`, class default `baseEyeHeight == 160`, root capsule of the template's 90 cm half height — gets [LuminaTemplateCharacterTuning.baseEyeHeight] instead; its generated `lib/actors/<name>.dart` constructor line is patched to match. A value the user chose (anything but 160) or a different capsule is left alone.

Runs once per project: [markerPath] under `.lumina/` records it, so a value set back to 160 on purpose later is never touched again.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `markerPath` | `static const String markerPath` |  |
| `legacyValue` | `static const double legacyValue` | The feet-based template value older projects carry. |
| `newValue` | `static const double newValue` | What it becomes: the eyes above the capsule centre. |
| `isMigrated` | `static bool isMigrated(String projectDir)` |  |
| `run` | `static BaseEyeHeightMigrationReport run(String projectDir)` |  |

## `lib/data/services/blueprint_class_registry.dart`

### `class LuminaBlueprintClassRegistry`

A project's Blueprint classes for the VM: what the editor's Play resolves a class reference — a project-relative `.lmas` path — to, where a generated game uses `luminaBlueprintFactories`.

Classes are compiled once and cached by path. A path whose file changed on disk (its modification time) is compiled again on its next use, so a Blueprint saved or recompiled in the editor is what the next Play spawns. Animation Blueprints a mesh names as its Anim Class are served the same way, with the blend spaces their states play.

**Yapıcı Metotlar (Constructors):**

- `LuminaBlueprintClassRegistry(this.projectDir, {List<LuminaInputAction>? inputActions, LuminaBlueprintAssetResolver? resolveAsset,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `inputActions` | `final List<LuminaInputAction> inputActions` |  |
| `resolveAsset` | `final LuminaBlueprintAssetResolver resolveAsset` | Maps a stored mesh reference to the file a mesh component loads. |
| `diagnostics` | `final List<LuminaBlueprintDiagnostic> diagnostics` | What went wrong loading or compiling classes, newest last. Each message names the Blueprint it is about. |
| `classFor` | `LuminaBlueprintClass? classFor(String path)` | The Blueprint class at [path] (project-relative `.lmas`), or null when it cannot be read. A class with compile errors is returned too — check `hasErrors` — and its errors are added to [diagnostics]. |
| `registerActorClasses` | `List<String> registerActorClasses(Iterable<LuminaProjectBlueprintClass> classes)` | Makes every actor Blueprint of [classes] spawnable by name — `Spawn Actor from Class` in Play-In-Editor, as the generated `registerProjectBlueprints()` does in a built game. Each class compiles now; one without errors is registered (GameMode Blueprints never are) and every spawn is served the class as last compiled. Returns the registered class names. |
| `levelClassFor` | `LuminaBlueprintClass? levelClassFor(String levelPath, {List<Map<String, dynamic>>? actorMaps, LuminaLevelBluep...` | The Level Blueprint of the level at [levelPath], compiled for the VM: [document] when given (an editor's unsaved graph), else the level's `metadata.levelBlueprint`; its placed actors are [actorMaps] (the editor's current level) or the level's saved ones. The placed Blueprint actors' classes give `Get <Actor>` its types and targeted Call Custom Event its events. Null when the level has no Blueprint (or an empty one); a class with errors is returned too and its errors are added to [diagnostics]. Level scripts are never registered with `Spawn Actor from Class`. |
| `levelScriptFor` | `LuminaBlueprintLevelScript? levelScriptFor(String levelPath, {List<Map<String, dynamic>>? actorMaps, LuminaLev...` | A new script actor of [levelPath]'s Level Blueprint (see [levelClassFor]), keyed `<Level>_script` as the generated level's is; null when the level has no Blueprint or it has errors. Set it as the level's `scriptActor` before the world begins play. |
| `animClassFor` | `LuminaAnimBlueprintClass? animClassFor(String path)` | The Animation Blueprint at [path], compiled with the blend spaces its states play; null when it cannot be read or has errors. |
| `resolvePawnFactory` | `LuminaPawn Function()? resolvePawnFactory(ProjectMapsAndModes mapsAndModes)` | The pawn factory [mapsAndModes] selects: its Default Pawn Class, else the Default Pawn Class of its GameMode Blueprint; null when neither names a Blueprint (the caller's game mode keeps its own pawn). The class is resolved again at every spawn. |
| `createGameMode` | `LuminaGameMode? createGameMode(ProjectMapsAndModes mapsAndModes)` | The game mode of the GameMode Blueprint [mapsAndModes] selects, with its Default Pawn Class overridden by Maps & Modes when that is set; null when the project's game mode is a Dart class or the Blueprint has errors. |

## `lib/data/services/blueprint_codegen/blueprint_dart_generator.dart`

### `class BlueprintGenerationResult`

What [BlueprintDartGenerator.generate] produced: the Dart source, or null when an error stopped generation, and every issue found on the way.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintGenerationResult(this.code, this.issues, {this.imports = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `code` | `final String? code` |  |
| `issues` | `final List<LuminaBlueprintDiagnostic> issues` |  |
| `imports` | `final List<String> imports` | The import directives [code] needs beyond `package:lumina/lumina_runtime.dart` and vector_math, for code embedded in another file (a level script); empty for a whole file. |
| `ok` | `bool get ok` |  |
| `errors` | `List<LuminaBlueprintDiagnostic> get errors` |  |

### `class BlueprintClassRef`

A generated class another generated class refers to by its `.lmas` path — a mesh's Anim Class, a GameMode's Default Pawn Class: the class, and the file generated code imports it from.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintClassRef(this.className, [this.importUri])`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `className` | `final String className` |  |
| `importUri` | `final String? importUri` |  |

### `typedef BlueprintAnimClassRef`

### `class BlueprintDartGenerator`

Compiles a Blueprint document into a Dart class that behaves exactly like the VM running it: the same component table, the same shared runtime (latent Delay, input binding, tracing), and straight-line event methods that call [LuminaBlueprintFunctionLibrary] directly, evaluating pure nodes in the VM's order so both produce the same trace. Animation Blueprints compile the same way ([generateAnimBlueprint]).

A node of a Dart function exposed with `@BlueprintCallable` / `@BlueprintPure` (registered or declared in [LuminaBlueprintFunctionRegistry]) compiles to a direct call through its library's import prefix ([functionPrefix]); `functionImports` overrides the URI a library is imported by.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintDartGenerator()`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `functionPrefix` | `static String functionPrefix(String libraryUri)` | The import prefix generated code uses for the exposed-function library [libraryUri]: `package:my_game/combat/health.dart` → `fn_my_game_combat_health`. A prefix, because an unprefixed top-level function would lose to an inherited member of the same name inside a generated class (`jump`), or clash with vector_math's top-level functions. |
| `generate` | `BlueprintGenerationResult generate(LuminaBlueprintDocument doc, {required String className, String? assetPath,...` |  |
| `generateLevelScript` | `BlueprintGenerationResult generateLevelScript(LuminaLevelBlueprintDocument doc, {required String className, re...` | Compiles a Level Blueprint into the level's script class [className] (`_LTestScript`), a `LuminaLevelScriptActor` with the shared Blueprint runtime, keyed `<levelName>_script`: its events (BeginPlay, Tick, End Play, Level Loaded / Unloaded), custom events, functions, dispatchers and timelines as for a class Blueprint, and one field per placed actor of [levelActors] (`door01`), resolved by name once the level is loaded. [members], [beginPlay] and [tick] are the level's own script lines (the level generator's post-process, player login and controller tick), written ahead of the Blueprint's. The result is the class alone; [BlueprintGenerationResult.imports] lists what the level file must import for it. |
| `generateWidgetScript` | `BlueprintGenerationResult generateWidgetScript(LuminaWidgetBlueprintDocument doc, {required String className,...` | Compiles a widget's graph into its script class [className] (`WbpClickerGraph`), a `LuminaUserWidget` with the shared Blueprint runtime: Event Pre Construct / Construct / Destruct / Tick as the widget's lifecycle hooks, each bound element event as an `onWidgetEvent` case, and custom events, functions, dispatchers and timelines as for a class Blueprint. The result is the class alone, for the widget's generated file; [BlueprintGenerationResult.imports] lists what that file must import for it. |
| `generateAnimBlueprint` | `BlueprintGenerationResult generateAnimBlueprint(LuminaAnimBlueprintDocument doc, {required String className, S...` | Compiles an Animation Blueprint into a `LuminaAnimBlueprintInstance` subclass: the update graph as a method, the state machine and the [blendSpaces] its states play as static tables, and each transition rule as a method returning its Result. |
| `generateEnum` | `String generateEnum(LuminaBlueprintEnumDocument doc, {String? assetPath})` | A Blueprint enum asset as a Dart enum: `E_DoorState` → `enum EDoorState { closed, opening, open }` with the Blueprint value names, so generated game code can switch on it while pins keep the value name as a string (`EDoorState.opening.blueprintName`). |
| `generateInterface` | `String generateInterface(LuminaBlueprintInterfaceDocument doc, {String? assetPath})` | A Blueprint interface asset as an abstract Dart mixin over [LuminaBlueprintRuntime]: one method per function taking its argument map, plus the document for the registry. |
| `typeNameOf` | `static String typeNameOf(String name)` | The Dart type [generateEnum] / [generateInterface] emit for the asset [name] (`E_DoorState` → `EDoorState`); the project registry names it. |

## `lib/data/services/blueprint_function_manifest.dart`

### `class BlueprintFunctionDiagnostic`

A scanner finding on an annotated function: the file and line, the function (`name` or `Class.name`), the parameter when one is at fault, and what is wrong. The function gets no node.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintFunctionDiagnostic({required this.path, required this.line, required this.function, this.parameter, required this.message,})`
- `factory BlueprintFunctionDiagnostic.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` | Project-relative (`lib/health.dart`). |
| `line` | `final int line` |  |
| `function` | `final String function` |  |
| `parameter` | `final String? parameter` |  |
| `message` | `final String message` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class BlueprintExposedFunction`

An annotated Dart function as a Blueprint node: its [spec], how generated code calls it ([call]), and where it is declared.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintExposedFunction({required this.spec, required this.call, required this.path, required this.line})`
- `factory BlueprintExposedFunction.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `spec` | `final LuminaBlueprintNodeSpec spec` |  |
| `call` | `final LuminaBlueprintCallShape call` |  |
| `path` | `final String path` | Project-relative (`lib/health.dart`). |
| `line` | `final int line` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class BlueprintFunctionManifest`

`project.blueprint_functions.json`, next to the `.lmproject`: what the scanner found in the project's `lib/`, so the editor lists the project's functions in the palette, validates and compiles Blueprints that use them, and reports the scanner's errors, without compiling project code.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintFunctionManifest({this.functions = const [], this.diagnostics = const []})`
- `factory BlueprintFunctionManifest.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` |  |
| `format` | `static const int format` |  |
| `functions` | `final List<BlueprintExposedFunction> functions` |  |
| `diagnostics` | `final List<BlueprintFunctionDiagnostic> diagnostics` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `encode` | `String encode()` | The file's bytes: indented JSON, byte-stable for the same scan. |
| `read` | `static BlueprintFunctionManifest? read(Directory projectDir)` | Reads the manifest of the project at [projectDir]; null when there is none. |
| `write` | `void write(Directory projectDir)` |  |
| `declareAll` | `void declareAll()` | Makes these functions known to this process without running them ([LuminaBlueprintFunctionRegistry.declare]), replacing earlier declarations. Functions this process registered as callable keep their registration. |

## `lib/data/services/blueprint_function_scanner.dart`

### `class BlueprintFunctionScan`

What [BlueprintFunctionScanner.scan] found in a project's `lib/`: a node per valid annotated function, sorted by id, and a diagnostic per refused one.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintFunctionScan.empty([this.diagnostics = const []])`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `functions` | `final List<BlueprintExposedFunction> functions` |  |
| `diagnostics` | `final List<BlueprintFunctionDiagnostic> diagnostics` |  |
| `packageName` | `final String? packageName` | The project's Dart package, as the scanned libraries' URIs name it. |
| `function` | `BlueprintExposedFunction? function(String id)` |  |
| `manifest` | `BlueprintFunctionManifest get manifest` | `project.blueprint_functions.json`'s content. |

### `class BlueprintFunctionScanner`

Lumina's function scanner: reads the `@BlueprintCallable` / `@BlueprintPure` functions of a project's `lib/` with `package:analyzer`, derives each one's node — pins from the parameters and the return type, category, title, keywords, and the doc comment as tooltip — and generates the registration the Blueprint VM calls, since Flutter has no run-time reflection.

Types are resolved, not matched by name: a project class called `Vector3` is not vector_math's, and any `LuminaActor` subclass is an object pin. The project needs its `.dart_tool/package_config.json` (`flutter pub get`); the Dart SDK is the one of the Flutter SDK that wrote it, unless [sdkPath] names one. Editor side only: games never import the analyzer.

**Yapıcı Metotlar (Constructors):**

- `const BlueprintFunctionScanner({this.sdkPath, this.keepWarm = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `sdkPath` | `final String? sdkPath` | The Dart SDK to resolve against (`<flutter>/bin/cache/dart-sdk`); found from the project's package config, `FLUTTER_ROOT` or the running `dart` when null. |
| `keepWarm` | `final bool keepWarm` | Keep the analysis context of each scanned `lib/` alive between scans, telling it only which files changed (the editor rescans on every save; a cold scan takes seconds, a warm one a fraction of that). Release it with [release] when the project closes. |
| `release` | `static Future<void> release(Directory libDir) async` | Disposes the warm analysis context kept for [libDir] (see [keepWarm]). |
| `registrationPath` | `static const String registrationPath` | Where the generated registration goes, relative to the project. |
| `scan` | `Future<BlueprintFunctionScan> scan(Directory libDir) async` | Scans every `.dart` file under [libDir] (generated `*.g.dart` files excepted). Files that mention no annotation are not analyzed, so a project without exposed functions scans in milliseconds. |
| `generateRegistration` | `String generateRegistration(BlueprintFunctionScan scan, {String? libraryName})` | `lib/blueprint/blueprint_functions.g.dart`: `registerProjectBlueprintFunctions()` registers each function of [scan] with a closure that unpacks the pin values, calls the function and packs its outputs. Libraries of the project package [libraryName] (default: the scanned one) are imported relatively, others by URI. Byte-stable for the same scan. |
| `writeProjectOutputs` | `void writeProjectOutputs(Directory projectDir, BlueprintFunctionScan scan, {String? libraryName})` | Writes [registrationPath] and `project.blueprint_functions.json` (next to the `.lmproject`) for the project at [projectDir]. |

## `lib/data/services/blueprint_project_assets.dart`

### `class LuminaProjectBlueprintClass`

A Blueprint class asset of a project: its project-relative `.lmas` path, its class name (the file name, what `Actor:<name>` pins and `Spawn Actor from Class` use) and its parent class.

**Yapıcı Metotlar (Constructors):**

- `const LuminaProjectBlueprintClass({required this.path, required this.name, required this.parentClass})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `name` | `final String name` |  |
| `parentClass` | `final String parentClass` |  |
| `isGameMode` | `bool get isGameMode` |  |

### `class LuminaProjectBlueprintAssets`

Every asset the Blueprint runtime resolves through a registry, read from a project's `contents/`: enum, interface, save-game and montage `.lmas` payloads (by their `kind`), particle systems (the first enabled emitter of `metadata['particle_system']`) and the actor Blueprint classes. The code generator writes `lib/blueprint_registry.g.dart` from it; Play-In-Editor registers it straight into lumina's registries.

**Yapıcı Metotlar (Constructors):**

- `const LuminaProjectBlueprintAssets({this.enums = const [], this.interfaces = const [], this.saveGameClasses = const [], this.montages = const [], this.particleT...`
- `factory LuminaProjectBlueprintAssets.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `enums` | `final List<({String path, LuminaBlueprintEnumDocument document})> enums` |  |
| `interfaces` | `final List<({String path, LuminaBlueprintInterfaceDocument document})> interfaces` |  |
| `saveGameClasses` | `final List<({String path, LuminaBlueprintSaveGameDocument document})> saveGameClasses` |  |
| `montages` | `final List<({String path, LuminaBlueprintMontageDocument document})> montages` |  |
| `particleTemplates` | `final List<({String path, Map<String, dynamic> config})> particleTemplates` | Particle system path → its emitter config as the particle editor stores it ([LuminaParticleEmitterConfig.toJson] shape). |
| `classes` | `final List<LuminaProjectBlueprintClass> classes` |  |
| `particleSystemMetadataKey` | `static const String particleSystemMetadataKey` | The `LuminaAsset.metadata` key a particle system is stored under (the particle editor's `ParticleSystemDocument.metadataKey`). |
| `actorClasses` | `List<LuminaProjectBlueprintClass> get actorClasses` | The actor classes `Spawn Actor from Class` may make: no GameMode Blueprints. |
| `hasRegistryAssets` | `bool get hasRegistryAssets` | Whether nothing needs registering beyond what the actor factories give. |
| `scan` | `static LuminaProjectBlueprintAssets scan(String projectDir)` | Every registry asset of `<projectDir>/contents`, found through the project's asset index: only the Blueprint documents that are enums, interfaces, save games or montages are read in full; classes and particle systems come from their summaries. Unreadable files are skipped; every list is sorted by path so generated code is stable. |
| `scanAsync` | `static Future<LuminaProjectBlueprintAssets> scanAsync(String projectDir) async` | [scan] in a background isolate (its own index instance reads the persisted index file), for callers that must not block the UI. |
| `fromIndex` | `static LuminaProjectBlueprintAssets fromIndex(LuminaAssetIndex index)` | The registry assets of an up-to-date [index]. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `registerRuntime` | `void registerRuntime()` | Registers the enums, interfaces, save-game classes, montages (by name and path) and particle templates into lumina's registries — what the generated `registerProjectBlueprints()` does, for Play-In-Editor. Actor classes are the caller's: PIE compiles them through its class registry. |

## `lib/data/services/config_json_file.dart`

### `class ConfigJsonFile`

A JSON file in the editor's config directory ([LuminaConfigDir]) that several writers share: the editor, a second editor window, a test run — each in its own process or isolate.

* [write] replaces the file atomically: the new content is written and flushed to a temp file in the same directory, which is then renamed over the file. A reader sees the old content or the new one, never a truncated file. * [update] is a read-modify-write under an exclusive lock (`<name>.lock`, created exclusively, so it holds across processes and isolates alike): two writers never overwrite each other's change. * Content that does not parse is never taken for an empty value. [read] tries again for a moment (a writer that still rewrites the file in place may be half-way through), then throws [ConfigFileUnreadableException]. [update] moves such a file aside as `<name>.unreadable-<timestamp>` before it writes, so the content is kept.

**Yapıcı Metotlar (Constructors):**

- `ConfigJsonFile(this.file)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `readAttempts` | `static const int readAttempts` | How often a read that does not parse is tried, and how far apart. |
| `readRetryDelay` | `static const Duration readRetryDelay` |  |
| `staleLockAge` | `static const Duration staleLockAge` | A lock older than this was left behind by a writer that died. |
| `lockTimeout` | `static const Duration lockTimeout` | How long [update] waits for another writer's lock. |
| `lockFile` | `File get lockFile` | The lock [update] holds while it reads, changes and writes the file. |
| `read` | `Object? read()` | The decoded content; null when the file is missing or stays blank. |
| `write` | `void write(Object? value, {bool pretty = false})` | Replaces the file with [value], atomically. |
| `update` | `Object? update(Object? Function(Object? current) change, {bool Function(Object value)? isValid, bool pretty =...` | Reads the file, lets [change] turn its content (null when there is none) into the new content, and writes that — all under [lockFile]. |

### `class ConfigFileUnreadableException`

A config file whose content does not parse as the JSON it should hold, even after [ConfigJsonFile.read] tried again.

**Yapıcı Metotlar (Constructors):**

- `ConfigFileUnreadableException(this.file, this.cause)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `cause` | `final Object cause` |  |

## `lib/data/services/dart_identifiers.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dartKeywords` | `const Set<String> dartKeywords` | Dart's reserved words and built-in identifiers, plus `async` / `await` / `yield` (reserved inside asynchronous and generator bodies). |
| `isDartKeyword` | `bool isDartKeyword(String name)` | Whether [name] is in [dartKeywords]. |
| `dartTypeName` | `String dartTypeName(String name, {String fallback = 'Generated'})` | The UpperCamelCase Dart type name generated for the user name [name] (`L_Main` → `LMain`, `BP_Door` → `BpDoor`); [fallback] when [name] has no letters or digits. |
| `dartFileStem` | `String dartFileStem(String name, {String fallback = 'generated'})` | The snake_case file name (without `.dart`) generated for [name] (`BP_ThirdPersonCharacter` → `bp_third_person_character`); [fallback] when [name] has no letters or digits. |
| `dartFileName` | `String dartFileName(String name, {String fallback = 'generated'})` | [dartFileStem] with the `.dart` extension (`L_Main` → `l_main.dart`). |
| `dartLowerCamelCase` | `String dartLowerCamelCase(String name)` | [name] in lowerCamelCase without escaping keywords or leading digits (`HealthBar Progress` → `healthBarProgress`); '' when nothing is left. |
| `dartMemberName` | `String dartMemberName(String name, {Set<String> reserved = const {}, String fallback = 'value'})` | The lowerCamelCase Dart member name generated for the user name [name] (`Max Health` → `maxHealth`): a leading digit gets an `n` prefix, a Dart keyword or a name in [reserved] a trailing `_`, and a name with no letters or digits is [fallback]. |
| `legacyDartClassName` | `String legacyDartClassName(String name)` | The class name generators used before [dartTypeName] (`BP_Door` → `BPDoor`): what files generated by earlier versions declare, so they can be migrated. |

## `lib/data/services/derived_data_cache.dart`

### `class DerivedDataEntryHeader`

Header stored in front of every derived-data entry's payload.

**Yapıcı Metotlar (Constructors):**

- `const DerivedDataEntryHeader({required this.key, required this.payloadBytes, required this.payloadSha256, this.sourceBytes = 0, this.buildMicros = 0, this.label...`
- `factory DerivedDataEntryHeader.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `key` | `final String key` | The cache key the entry was written under; must match its file name. |
| `payloadBytes` | `final int payloadBytes` |  |
| `payloadSha256` | `final String payloadSha256` | SHA-256 of the payload, checked on every read. |
| `sourceBytes` | `final int sourceBytes` | Size of the source the payload was derived from (0 when unknown). |
| `buildMicros` | `final int buildMicros` | How long building the payload took, so a hit can say what it saved. |
| `label` | `final String label` |  |
| `createdAt` | `final String createdAt` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class DerivedDataCacheUsage`

Entry count and bytes on disk of a cache (or of what a clear freed).

**Yapıcı Metotlar (Constructors):**

- `const DerivedDataCacheUsage(this.entries, this.bytes)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `entries` | `final int entries` |  |
| `bytes` | `final int bytes` |  |

### `class DerivedDataCacheStats`

What the derived-data caches of this process did since it started.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hits` | `int hits` |  |
| `misses` | `int misses` |  |
| `corrupt` | `int corrupt` |  |
| `evictions` | `int evictions` |  |
| `bytesRead` | `int bytesRead` |  |
| `bytesWritten` | `int bytesWritten` |  |

### `class DerivedDataCache`

A project's local derived-data cache: `<project>/DerivedDataCache/`.

It stores data that is expensive to derive from project content and cheap to rebuild — today the texture-budgeted GLB [GlbParserService] makes of an asset that still carries oversized source art (~37 s for a mesh with fourteen 8192x8192 PNGs). Entries are keyed by what they were derived from, validated on every read (magic, format version, key, payload length, payload SHA-256), written atomically (temp file + rename), bounded by [maxBytes] with least-recently-used eviction, and never committed (the folder carries its own `.gitignore`) or cooked (it is outside `contents/`; see [packagedEntriesIncludingCache]). Hits, misses, corrupt entries, evictions and clears are logged to the Output Log.

**Yapıcı Metotlar (Constructors):**

- `DerivedDataCache(this.projectRoot, {this.maxBytes = defaultMaxBytes})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `directoryName` | `static const String directoryName` | Project-root folder the cache lives in. |
| `sanitizedGlbBucket` | `static const String sanitizedGlbBucket` | Bucket of texture-budgeted GLBs ([sanitizedGlb]). |
| `defaultMaxBytes` | `static const int defaultMaxBytes` | Default size bound per project: 2 GiB. A budgeted 8K-textured character is ~20 MB, so this only bites on projects with a lot of oversized art. |
| `entryExtension` | `static const String entryExtension` |  |
| `formatVersion` | `static const int formatVersion` |  |
| `sessionStats` | `static final DerivedDataCacheStats sessionStats` |  |
| `projectRoot` | `final String projectRoot` |  |
| `maxBytes` | `final int maxBytes` |  |
| `directory` | `Directory get directory` |  |
| `entryFile` | `File entryFile(String bucket, String key)` |  |
| `findProjectRoot` | `static String? findProjectRoot(String path)` | The nearest ancestor directory of [path] (or [path] itself, when it is a directory) holding a `*.lmproject` manifest, or null outside any project. |
| `forAssetPath` | `static DerivedDataCache? forAssetPath(String path, {int maxBytes = defaultMaxBytes})` | The cache of the project [path] belongs to, or null outside any project. |
| `sha256Hex` | `static String sha256Hex(Uint8List bytes)` |  |
| `sanitizedGlbKey` | `static String sanitizedGlbKey(String sourceSha256, int maxTextureSize, {int converterVersion = GlbParserServic...` | Key of the texture-budgeted GLB derived from a source whose SHA-256 is [sourceSha256]: the content hash, the budget and the converter version, so a changed source, budget or [GlbParserService.sanitizerVersion] misses. |
| `isCacheableGlb` | `static bool isCacheableGlb(Uint8List source, {int maxTextureSize = GlbParserService.defaultMaxTextureSize})` | Whether [sanitizedGlb] would persist the result for [source]: only when the sanitizer has to decode images (the expensive path) and every image is embedded, so the output depends on [source] alone. |
| `sanitizeGlbForAsset` | `static Future<Uint8List> sanitizeGlbForAsset(String assetPath, Uint8List payload, {List<String>? searchDirs, i...` | [GlbParserService.convertGlbTgaToPngAsync] for the asset at [assetPath], through the derived-data cache of the project it belongs to. Outside a project, or for a source that is cheap or not self-contained, it simply converts. |
| `sanitizedGlb` | `Future<Uint8List> sanitizedGlb(Uint8List source, {List<String>? searchDirs, int maxTextureSize = GlbParserServ...` | The texture-budgeted form of [source]: from this cache when an entry for its content hash, [maxTextureSize] and the converter version exists and validates, otherwise built by [GlbParserService.convertGlbTgaToPngAsync] and stored. Hashing, reading and writing all run off the calling isolate. |
| `get` | `Future<Uint8List?> get(String bucket, String key, {String? label}) async` | The payload stored under [bucket]/[key], or null when there is none. A corrupt or truncated entry is logged, deleted and reported as absent. A hit marks the entry as recently used. |
| `put` | `Future<File> put(String bucket, String key, Uint8List payload, {String? label, int sourceBytes = 0, int buildM...` | Stores [payload] under [bucket]/[key] (atomically: a temp file renamed into place), then evicts least-recently-used entries until the cache is within [maxBytes]. Throws [FileSystemException] when the disk refuses. |
| `entries` | `List<File> entries()` | Every entry file in the cache, sorted by path. |
| `usage` | `DerivedDataCacheUsage usage()` |  |
| `clear` | `Future<DerivedDataCacheUsage> clear() async` | Deletes every entry (and any temp file a crashed write left behind) and logs what that freed. The cache rebuilds entries on demand. |
| `readEntryHeader` | `static DerivedDataEntryHeader? readEntryHeader(File file)` | The header of the entry [file], or null when it is not a readable entry. |
| `ensureIgnoredBy` | `static bool ensureIgnoredBy(String projectRoot)` | Adds `DerivedDataCache/` to [projectRoot]'s `.gitignore` (creating it if needed). Returns false when the rule was already there. |
| `packagedEntriesIncludingCache` | `static List<String> packagedEntriesIncludingCache(String pubspecYaml)` | The `flutter: assets:` entries of a project pubspec that would bundle the cache into a cooked game. `flutter build` only packages the listed asset entries (directories are not recursive), so the cache stays out unless one of these names it — which Cook & Package refuses. |

## `lib/data/services/editor_build_cache.dart`

### `class EditorBuildEntry`

A complete cached project editor build.

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildEntry(this.hash, this.dir, this.stamp)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hash` | `final String hash` |  |
| `dir` | `final Directory dir` |  |
| `stamp` | `final Map<String, dynamic> stamp` | The stamp written at install: `{hash, inputs, engineRevision, flutterVersion, platform, mode, builtAt, executable}`. |
| `bundle` | `Directory get bundle` |  |
| `executable` | `String get executable` | The editor executable inside [bundle] (`stamp.executable` is relative). |

### `class EditorBuildCache`

The machine-wide, content-addressed cache of compiled project editors: `<root>/<hash>/{bundle/, stamp.json, complete}`. Projects with the same plugin set on the same engine share one entry.

Crash-safe: an install copies into `<hash>.tmp/` and renames, and only an entry with its `complete` marker is ever returned. Two launchers building the same hash serialize on `<hash>.lock` ([RandomAccessFile.lock]).

**Yapıcı Metotlar (Constructors):**

- `EditorBuildCache({Directory? root, Directory? nativeRoot})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `root` | `final Directory root` |  |
| `nativeRoot` | `final Directory nativeRoot` | flutter_filament's native library cache, swept alongside by [evict]. |
| `cacheBase` | `static String cacheBase({Map<String, String>? environment, String? operatingSystem})` | `%LOCALAPPDATA%\lumina` on Windows, `~/Library/Caches/lumina` on macOS, else `$XDG_CACHE_HOME/lumina` or `~/.cache/lumina`. |
| `defaultRoot` | `static Directory defaultRoot({Map<String, String>? environment, String? operatingSystem})` |  |
| `lockFile` | `File lockFile(String hash)` |  |
| `logFile` | `File logFile(String hash)` |  |
| `lookup` | `EditorBuildEntry? lookup(String hash)` |  |
| `hashes` | `List<String> hashes()` | Every complete entry's hash. |
| `install` | `Future<EditorBuildEntry> install(String hash, Directory builtBundle, {Map<String, dynamic> stamp = const {}})...` | Copies [builtBundle] into `<hash>.tmp/` with [stamp], marks it complete and renames it into place. A leftover `<hash>.tmp/` from a crashed install is removed first. The caller holds `<hash>.lock` ([obtain] does). |
| `touch` | `Future<void> touch(String hash) async` | Marks [hash] used now (eviction keeps recently used entries). |
| `withLock` | `Future<T> withLock<T>(String hash, Future<T> Function() body) async` | Locks `<hash>.lock` exclusively (waiting for another holder), runs [body], then releases it. |
| `obtain` | `Future<EditorBuildEntry> obtain(String hash, Future<({Directory bundle, Map<String, dynamic> stamp})> Function...` | The entry for [hash], building it with [build] only when it is not cached. Two callers for one hash serialize on its lock: the second finds the first one's entry and does not build. |
| `lastEvictedBytes` | `int lastEvictedBytes` | Bytes freed by the last [evict]. |
| `evict` | `Future<List<String>> evict({int keep = 5, Duration unusedFor = const Duration(days: 30)}) async` | Removes entries beyond the [keep] most recently used that were unused for [unusedFor], never one whose lock is held, plus any crashed `*.tmp` install. Also sweeps the native library cache the same way per package. Returns what was removed (`<hash>`, `native/<pkg>/<key>`). |
| `totalBytes` | `int totalBytes()` | Total size of every entry (for the preferences' cache line). |

## `lib/data/services/editor_build_fingerprint.dart`

### `class EditorHostInputs`

Everything a project editor build depends on.

**Yapıcı Metotlar (Constructors):**

- `const EditorHostInputs({required this.hostDir, required this.engineRoot, required this.pluginDirs, required this.flutterVersion, required this.flutterRevision,...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hostDir` | `final String hostDir` | `<project>/.lumina/editor`: its `pubspec.yaml` and `pubspec.lock`. |
| `engineRoot` | `final String engineRoot` | The workspace root holding the engine repos. |
| `pluginDirs` | `final Map<String, String> pluginDirs` | Each code plugin's package directory, by plugin name. |
| `flutterVersion` | `final String flutterVersion` | `flutter --version --machine`: `frameworkVersion` (shown in reasons) and `frameworkRevision` (hashed). |
| `flutterRevision` | `final String flutterRevision` |  |
| `platform` | `final String platform` | `windows-x64`, `linux-x64`, …. |
| `mode` | `final String mode` | `release` or `debug`. |
| `repos` | `final List<String> repos` | The repos (relative dirs under [engineRoot]) hashed as `engine:<repo>`: the engine repos, or the packages of a project's source copy. |
| `currentPlatform` | `static String currentPlatform()` | The running host: `<os>-<arch>`. |

### `class FlutterToolInfo`

`flutter --version --machine`, probed once per process.

**Yapıcı Metotlar (Constructors):**

- `const FlutterToolInfo(this.version, this.revision)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` |  |
| `revision` | `final String revision` |  |
| `probe` | `static Future<FlutterToolInfo> probe({String flutter = 'flutter'}) async` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kEditorEngineRepos` | `const List<String> kEditorEngineRepos` | The engine packages a project editor is compiled from (the ones of other repos are found through the workspace's package config). |
| `fingerprintComponents` | `Future<Map<String, String>> fingerprintComponents(EditorHostInputs inputs) async` | Per-input hashes: `host.pubspec`, `host.lock`, `engine:<repo>`, `plugin:<name>`, and the plain values `flutter`, `platform`, `mode` (kept readable, so a reason can say "Flutter 3.41 → 3.44"). `plugin:<name>`, eklentinin `lib/`, `hook/`, `pubspec.yaml` ve `.lmplugin` dosyalarını özetler (registrar'a neyin derleneceğine manifest karar verir: `registration_class`, `isolation`, `process_class`). |
| `fingerprint` | `Future<String> fingerprint(EditorHostInputs inputs) async` | SHA-256 (hex) over [components] (or over [fingerprintComponents] of [inputs]). |
| `fingerprintOf` | `String fingerprintOf(Map<String, String> components)` |  |
| `diffInputs` | `List<String> diffInputs(Map<String, String> older, Map<String, String> newer)` | Human-readable reasons [newer] differs from [older], one per change: "plugin a_plugin changed", "editor source changed (lumina_ui)", "Flutter 3.41.0 → 3.44.0", "build mode release → debug". |
| `engineRepoState` | `Future<String> engineRepoState(String dir) async` | Bir deponun kaynak durumu: checkout ise git durumu, değilse (projenin engine kopyası) `lib/`, `src/`, `hook/`, platform runner klasörleri `windows/`, `linux/`, `macos/` (`flutter/ephemeral` hariç, bağlantılar izlenmeden) ve `pubspec.yaml` içerik manifesti; böylece kopyadaki bir runner değişikliği proje editörünü yeniden derletir. |

---

[Önceki: Veri katmanı: use case'ler ve servisler](data-services.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 2)](data-services-continued-2.md)
