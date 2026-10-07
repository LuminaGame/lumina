[Türkçe](../../tr/lumina/data-services-continued.md)

# Data layer: use cases and services (continued, part 1)

Continuation of Data layer: use cases and services: the remaining public files under `lib/data/services/`, `lib/data/services/blueprint_codegen/`. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/data/services/app_icon_service.dart`](#libdataservicesapp_icon_servicedart)
- [`lib/data/services/base_eye_height_migration.dart`](#libdataservicesbase_eye_height_migrationdart)
- [`lib/data/services/blueprint_class_registry.dart`](#libdataservicesblueprint_class_registrydart)
- [`lib/data/services/blueprint_codegen/blueprint_dart_generator.dart`](#libdataservicesblueprint_codegenblueprint_dart_generatordart)
- [`lib/data/services/blueprint_function_manifest.dart`](#libdataservicesblueprint_function_manifestdart)
- [`lib/data/services/blueprint_function_scanner.dart`](#libdataservicesblueprint_function_scannerdart)
- [`lib/data/services/blueprint_project_assets.dart`](#libdataservicesblueprint_project_assetsdart)
- [`lib/data/services/derived_data_cache.dart`](#libdataservicesderived_data_cachedart)

## `lib/data/services/app_icon_service.dart`

### `class AppIconPlatformResult`

What [AppIconService.write] did for one platform.

**Constructors:**

- `const AppIconPlatformResult(this.platform, {this.files = const [], this.skippedReason, this.warnings = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `platform` | `final String platform` |  |
| `files` | `final List<String> files` | Project-relative paths of the files written. |
| `skippedReason` | `final String? skippedReason` | Why nothing was written (the project has no folder for the platform). |
| `warnings` | `final List<String> warnings` | Notes worth logging: a runner patch that could not find its anchor. |
| `written` | `bool get written` |  |

### `class AppIconReport`

**Constructors:**

- `const AppIconReport(this.platforms)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `platforms` | `final Map<String, AppIconPlatformResult> platforms` |  |
| `writtenFiles` | `List<String> get writtenFiles` |  |
| `summary` | `String summary()` |  |

### `class AppIconService`

Writes a game project's app-icon files for every platform from one high-resolution master PNG: Windows ICO, macOS and iOS icon sets, Android legacy and adaptive mipmaps, the web favicon, icons and manifest, and the Linux runner icon plus the runner/CMake patches that show it. The master is resampled with `package:image`; rasterizing an SVG into that master is the caller's job (the editor uses flutter_svg).

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const LinuxBundleReport({required this.ok, this.desktopFile, this.gioAvailable = false, this.gioIconSet = false, this.messages = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `desktopFile` | `final String? desktopFile` |  |
| `gioAvailable` | `final bool gioAvailable` |  |
| `gioIconSet` | `final bool gioIconSet` |  |
| `messages` | `final List<String> messages` |  |

### `class LinuxBundleBranding`

Finishes a built Linux bundle so it presents the project icon outside the running window too: a `.desktop` entry in the bundle, and the executable's file-manager icon on this host. An ELF file carries no icon of its own; the file manager reads GIO metadata (`metadata::custom-icon`), which is stored per user on this machine and does not travel with a copy.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `finish` | `static Future<LinuxBundleReport> finish({required String bundleDir, required String executableName, required S...` |  |

## `lib/data/services/base_eye_height_migration.dart`

### `class BaseEyeHeightMigrationReport`

What [BaseEyeHeightMigration.run] did to one project.

**Constructors:**

- `const BaseEyeHeightMigrationReport({this.migratedBlueprints = const [], this.patchedGeneratedFiles = const [], this.alreadyMigrated = false,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `migratedBlueprints` | `final List<String> migratedBlueprints` | Project-relative `.lmas` paths whose class default was rewritten. |
| `patchedGeneratedFiles` | `final List<String> patchedGeneratedFiles` | Project-relative generated `lib/actors/*.dart` files patched to match. |
| `alreadyMigrated` | `final bool alreadyMigrated` | True when the project had already been migrated (the marker exists). |
| `didAnything` | `bool get didAnything` |  |

### `class BaseEyeHeightMigration`

The one-time move of the Third Person template's Base Eye Height to the capsule-centre convention.

`baseEyeHeight` is measured from the actor location, which for a character is the capsule centre. Older projects store the template's feet-based 160 cm in BP_ThirdPersonCharacter's class defaults, which puts the eyes (and every trace) 250 cm above the ground. On project open, every Character Blueprint that still carries exactly that template value — parent `LuminaCharacter`, class default `baseEyeHeight == 160`, root capsule of the template's 90 cm half height — gets [LuminaTemplateCharacterTuning.baseEyeHeight] instead; its generated `lib/actors/<name>.dart` constructor line is patched to match. A value the user chose (anything but 160) or a different capsule is left alone.

Runs once per project: [markerPath] under `.lumina/` records it, so a value set back to 160 on purpose later is never touched again.

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `LuminaBlueprintClassRegistry(this.projectDir, {List<LuminaInputAction>? inputActions, LuminaBlueprintAssetResolver? resolveAsset,})`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const BlueprintGenerationResult(this.code, this.issues, {this.imports = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `code` | `final String? code` |  |
| `issues` | `final List<LuminaBlueprintDiagnostic> issues` |  |
| `imports` | `final List<String> imports` | The import directives [code] needs beyond `package:lumina/lumina_runtime.dart` and vector_math, for code embedded in another file (a level script); empty for a whole file. |
| `ok` | `bool get ok` |  |
| `errors` | `List<LuminaBlueprintDiagnostic> get errors` |  |

### `class BlueprintClassRef`

A generated class another generated class refers to by its `.lmas` path — a mesh's Anim Class, a GameMode's Default Pawn Class: the class, and the file generated code imports it from.

**Constructors:**

- `const BlueprintClassRef(this.className, [this.importUri])`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `className` | `final String className` |  |
| `importUri` | `final String? importUri` |  |

### `typedef BlueprintAnimClassRef`

### `class BlueprintDartGenerator`

Compiles a Blueprint document into a Dart class that behaves exactly like the VM running it: the same component table, the same shared runtime (latent Delay, input binding, tracing), and straight-line event methods that call [LuminaBlueprintFunctionLibrary] directly, evaluating pure nodes in the VM's order so both produce the same trace. Animation Blueprints compile the same way ([generateAnimBlueprint]).

A node of a Dart function exposed with `@BlueprintCallable` / `@BlueprintPure` (registered or declared in [LuminaBlueprintFunctionRegistry]) compiles to a direct call through its library's import prefix ([functionPrefix]); `functionImports` overrides the URI a library is imported by.

**Constructors:**

- `const BlueprintDartGenerator()`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const BlueprintFunctionDiagnostic({required this.path, required this.line, required this.function, this.parameter, required this.message,})`
- `factory BlueprintFunctionDiagnostic.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` | Project-relative (`lib/health.dart`). |
| `line` | `final int line` |  |
| `function` | `final String function` |  |
| `parameter` | `final String? parameter` |  |
| `message` | `final String message` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class BlueprintExposedFunction`

An annotated Dart function as a Blueprint node: its [spec], how generated code calls it ([call]), and where it is declared.

**Constructors:**

- `const BlueprintExposedFunction({required this.spec, required this.call, required this.path, required this.line})`
- `factory BlueprintExposedFunction.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `spec` | `final LuminaBlueprintNodeSpec spec` |  |
| `call` | `final LuminaBlueprintCallShape call` |  |
| `path` | `final String path` | Project-relative (`lib/health.dart`). |
| `line` | `final int line` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class BlueprintFunctionManifest`

`project.blueprint_functions.json`, next to the `.lmproject`: what the scanner found in the project's `lib/`, so the editor lists the project's functions in the palette, validates and compiles Blueprints that use them, and reports the scanner's errors, without compiling project code.

**Constructors:**

- `const BlueprintFunctionManifest({this.functions = const [], this.diagnostics = const []})`
- `factory BlueprintFunctionManifest.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const BlueprintFunctionScan.empty([this.diagnostics = const []])`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `functions` | `final List<BlueprintExposedFunction> functions` |  |
| `diagnostics` | `final List<BlueprintFunctionDiagnostic> diagnostics` |  |
| `packageName` | `final String? packageName` | The project's Dart package, as the scanned libraries' URIs name it. |
| `function` | `BlueprintExposedFunction? function(String id)` |  |
| `manifest` | `BlueprintFunctionManifest get manifest` | `project.blueprint_functions.json`'s content. |

### `class BlueprintFunctionScanner`

Lumina's function scanner: reads the `@BlueprintCallable` / `@BlueprintPure` functions of a project's `lib/` with `package:analyzer`, derives each one's node — pins from the parameters and the return type, category, title, keywords, and the doc comment as tooltip — and generates the registration the Blueprint VM calls, since Flutter has no run-time reflection.

Types are resolved, not matched by name: a project class called `Vector3` is not vector_math's, and any `LuminaActor` subclass is an object pin. The project needs its `.dart_tool/package_config.json` (`flutter pub get`); the Dart SDK is the one of the Flutter SDK that wrote it, unless [sdkPath] names one. Editor side only: games never import the analyzer.

**Constructors:**

- `const BlueprintFunctionScanner({this.sdkPath, this.keepWarm = false})`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const LuminaProjectBlueprintClass({required this.path, required this.name, required this.parentClass})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `name` | `final String name` |  |
| `parentClass` | `final String parentClass` |  |
| `isGameMode` | `bool get isGameMode` |  |

### `class LuminaProjectBlueprintAssets`

Every asset the Blueprint runtime resolves through a registry, read from a project's `contents/`: enum, interface, save-game and montage `.lmas` payloads (by their `kind`), particle systems (the first enabled emitter of `metadata['particle_system']`) and the actor Blueprint classes. The code generator writes `lib/blueprint_registry.g.dart` from it; Play-In-Editor registers it straight into lumina's registries.

**Constructors:**

- `const LuminaProjectBlueprintAssets({this.enums = const [], this.interfaces = const [], this.saveGameClasses = const [], this.montages = const [], this.particleT...`
- `factory LuminaProjectBlueprintAssets.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
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

## `lib/data/services/derived_data_cache.dart`

### `class DerivedDataEntryHeader`

Header stored in front of every derived-data entry's payload.

**Constructors:**

- `const DerivedDataEntryHeader({required this.key, required this.payloadBytes, required this.payloadSha256, this.sourceBytes = 0, this.buildMicros = 0, this.label...`
- `factory DerivedDataEntryHeader.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const DerivedDataCacheUsage(this.entries, this.bytes)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entries` | `final int entries` |  |
| `bytes` | `final int bytes` |  |

### `class DerivedDataCacheStats`

What the derived-data caches of this process did since it started.

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `DerivedDataCache(this.projectRoot, {this.maxBytes = defaultMaxBytes})`

**Members:**

| Member | Signature | Description |
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

---

[Previous: Data layer: use cases and services](data-services.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: use cases and services (continued, part 2)](data-services-continued-2.md)
