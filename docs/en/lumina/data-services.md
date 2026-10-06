[Türkçe](../../tr/lumina/data-services.md)

# Data layer: use cases and services

The editor-facing data layer, part one: the domain use cases (save level, import asset, generate Dart code) and the services behind them: asset reference graph, auto-save, the Dart code generator, the engine logger, game and level templates, the GLB, OBJ and TGA parsers, plugin registry, template generator and host patcher, primitive GLB factory, project input binder and thumbnails. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/domain/use_cases/generate_dart_code_use_case.dart`](#libdomainuse_casesgenerate_dart_code_use_casedart)
- [`lib/domain/use_cases/import_asset_use_case.dart`](#libdomainuse_casesimport_asset_use_casedart)
- [`lib/domain/use_cases/save_level_use_case.dart`](#libdomainuse_casessave_level_use_casedart)
- [`lib/domain/use_cases/use_case_validation.dart`](#libdomainuse_casesuse_case_validationdart)
- [`lib/domain/models/use_case_results.dart`](#libdomainmodelsuse_case_resultsdart)
- [`lib/data/services/asset_reference_graph.dart`](#libdataservicesasset_reference_graphdart)
- [`lib/data/services/assimp_import_service.dart`](#libdataservicesassimp_import_servicedart)
- [`lib/data/services/auto_save_timer_service.dart`](#libdataservicesauto_save_timer_servicedart)
- [`lib/data/services/code_generator_service.dart`](#libdataservicescode_generator_servicedart)
- [`lib/data/services/engine_logger_service.dart`](#libdataservicesengine_logger_servicedart)
- [`lib/data/services/game_template_service.dart`](#libdataservicesgame_template_servicedart)
- [`lib/data/services/glb_parser_service.dart`](#libdataservicesglb_parser_servicedart)
- [`lib/data/services/level_template_service.dart`](#libdataserviceslevel_template_servicedart)
- [`lib/data/services/obj_import_service.dart`](#libdataservicesobj_import_servicedart)
- [`lib/data/services/obj_parser_service.dart`](#libdataservicesobj_parser_servicedart)
- [`lib/data/services/plugin_host_patcher_service.dart`](#libdataservicesplugin_host_patcher_servicedart)
- [`lib/data/services/plugin_registry_service.dart`](#libdataservicesplugin_registry_servicedart)
- [`lib/data/services/plugin_template_generator_service.dart`](#libdataservicesplugin_template_generator_servicedart)
- [`lib/data/services/primitive_glb_factory.dart`](#libdataservicesprimitive_glb_factorydart)
- [`lib/data/services/project_input_binder.dart`](#libdataservicesproject_input_binderdart)
- [`lib/data/services/tga_decoder_service.dart`](#libdataservicestga_decoder_servicedart)
- [`lib/data/services/thumbnail_service.dart`](#libdataservicesthumbnail_servicedart)

## `lib/domain/use_cases/generate_dart_code_use_case.dart`

### `class GenerateDartCodeUseCase`

Generates the live declarative Dart code for a level (`lib/main.dart` + `lib/levels/<levelName>.dart`) via [DartCodeGeneratorService] and, when a [LuminaProject] is supplied, clears its dirty flag and stamps `lastCodeGeneratedTimestamp` through [ProjectRepository.saveProject].

## `lib/domain/use_cases/import_asset_use_case.dart`

### `class ImportAssetUseCase`

Imports an external model/texture/audio file into a project's `contents/` tree through [AssetRepository.importExternalFile] (stage → convert → resolve paths → emit `.lmas` family). Unsupported formats and thrown pipeline errors become a failure result.

## `lib/domain/use_cases/save_level_use_case.dart`

### `class SaveLevelUseCase`

Writes the active level as a `contents/levels/<levelName>.lmas` JSON container.  The container is exactly what Lumina Studio writes on Save Level: `assetId` (`level_<name>`), `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and `metadata.actors` — the actor maps (`EditorActorNode.toMap()`) are passed through untouched. Validation and I/O failures are reported in the result, never thrown.

## `lib/domain/use_cases/use_case_validation.dart`

**Top-level Functions:**

- **`String? validateProjectDir(String projectDir)`**: Shared input validation for the use-case layer. Returns an error message or null.
- **`String? validateLevelName(String levelName)`**: A level name must be a plain file stem: no separators, no parent references.

## `lib/domain/models/use_case_results.dart`

### `class SaveLevelResult`

Result of [SaveLevelUseCase]: where the `.lmas` level container landed on disk.

**Constructors:**
- `SaveLevelResult.failure(this.levelName, String this.error)`: Initializes `SaveLevelResult.failure(this.levelName, String this.error)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | Holds the `isSuccess` property or configuration state. |
| `levelName` | `String levelName` | Holds the `levelName` property or configuration state. |
| `levelFilePath` | `String? levelFilePath` | Holds the `levelFilePath` property or configuration state. |
| `actorCount` | `int actorCount` | Holds the `actorCount` property or configuration state. |
| `error` | `String? error` | Holds the `error` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class GenerateDartCodeResult`

Result of [GenerateDartCodeUseCase]: the generated Dart files and the cleaned manifest.

**Constructors:**
- `GenerateDartCodeResult.failure(String this.error)`: Initializes `GenerateDartCodeResult.failure(String this.error)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | Holds the `isSuccess` property or configuration state. |
| `mainDartPath` | `String? mainDartPath` | Holds the `mainDartPath` property or configuration state. |
| `levelDartPath` | `String? levelDartPath` | Holds the `levelDartPath` property or configuration state. |
| `writtenFiles` | `List<String> writtenFiles` | Holds the `writtenFiles` property or configuration state. |
| `updatedProject` | `LuminaProject? updatedProject` | Holds the `updatedProject` property or configuration state. |
| `error` | `String? error` | Holds the `error` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class ImportAssetResult`

Result of [ImportAssetUseCase]: the imported asset's `.lmas` description.

**Constructors:**
- `ImportAssetResult.failure(this.sourceFilePath, String this.error)`: Initializes `ImportAssetResult.failure(this.sourceFilePath, String this.error)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | Holds the `isSuccess` property or configuration state. |
| `sourceFilePath` | `String sourceFilePath` | Holds the `sourceFilePath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `error` | `String? error` | Holds the `error` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

## `lib/data/services/asset_reference_graph.dart`

### `class ResolvedReference`

`ResolvedReference`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `resolvedPath` | `String? resolvedPath` | Holds the `resolvedPath` property or configuration state. |
| `broken` | `bool broken` | Holds the `broken` property or configuration state. |

### `class AssetReferenceGraph`

`AssetReferenceGraph`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `void build(List<RealAssetInfo> assets)` | Constructs and returns the declarative element or widget hierarchy. |
| `getAsset` | `RealAssetInfo? getAsset(String assetId)` | Queries and returns the `Asset` value or child object. |
| `dependenciesOf` | `List<RealAssetInfo> dependenciesOf(String assetId)` | Executes `dependenciesOf` operation. |
| `referencersOf` | `List<RealAssetInfo> referencersOf(String assetId)` | Executes `referencersOf` operation. |
| `dependencyClosure` | `Set<String> dependencyClosure(String assetId)` | Executes `dependencyClosure` operation. |
| `resolve` | `ResolvedReference resolve(AssetReference ref)` | Executes `resolve` operation. |

## `lib/data/services/assimp_import_service.dart`

### `class AssimpImportException`

A model file Assimp could not convert: `message` names the file and Assimp's reason. The import logs it as an error and writes nothing.

### `class AssimpImportResult`

A Collada, 3DS, PLY, DirectX or STL file converted for the import pipeline: `glb` (every texture that was found embedded), `missingTextures` (`material`, `slot`, `path` as the file wrote it, `file`) and `embeddedTextures` (the file names found).

### `abstract final class AssimpImportService`

Every 3D format Assimp reads besides FBX and OBJ (which have their own services) → GLB for the import pipeline: Collada (`.dae`), 3DS, PLY, DirectX (`.x`) and STL ([FlutterAssimp.importExtensions]). The asset repository stages these through it (Content Browser import and drag and drop, folder import, the MCP `import_asset` tool), converting from the source file where it is, so whatever it references relative to itself resolves; nothing is converted from a staged copy. Textures are then located like an FBX's ([FbxTextureLocator]: as written, relative to the file with folders and file in any case, by name in its folder, the Import dialog's Textures Folder and the usual `Textures/` folders) and embedded. A texture found nowhere gets one Output Log warning naming it and the material is imported without it. Geometry, units and axes are as Assimp reads them (Collada's `<unit>` and `<up_axis>` are applied by its importer). A file Assimp cannot read fails the import with an error and writes no asset.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `handles` | `static bool handles(String path)` | Whether [path] is imported through this service (an Assimp format other than FBX and OBJ). |
| `convert` | `static Future<AssimpImportResult> convert(String path, {List<String> textureSearchDirs = const []})` | [convertSync] in a background isolate. |
| `convertSync` | `static AssimpImportResult convertSync(String path, {List<String> textureSearchDirs = const []})` | Throws [AssimpImportException] when Assimp cannot read the file. |

## `lib/data/services/auto_save_timer_service.dart`

### `class AutoSaveTimerService`

`AutoSaveTimerService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onPerformSave` | `SaveCallback onPerformSave` | Holds the `onPerformSave` property or configuration state. |
| `stop` | `void stop()` | Executes `stop` operation. |
| `checkAndExecuteAutoSave` | `Future<LuminaProject> checkAndExecuteAutoSave(LuminaProject project)` | Executes `checkAndExecuteAutoSave` operation. |

## `lib/data/services/code_generator_service.dart`

### `class DartCodeGeneratorService`

`DartCodeGeneratorService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `generateActorRegistryDart` | `String generateActorRegistryDart(List<String> actorNames)` | Generates the actors.g.dart registry file. |
| `compileAndWriteActor` | `Future<bool> compileAndWriteActor(String projectPath, String assetName, ...` | Compiles a blueprint document into a project's lib/actors/ file. |
| `writeProjectInputDart` | `bool writeProjectInputDart(String projectPath, [ProjectInputSettings? settings])` | Writes `lib/input/project_input.g.dart` from settings or project manifest. |

The generated level's begin-play registers `LuminaWorldPartitionSubsystem` with the level's `metadata.worldPartition` section (cell size, transitions per tick, the data layers with their initial state), adds every actor to the partition and registers the streaming sources. A level row may carry `dataLayers: [<layer name>, ...]` (the editor does not author it yet; tools such as the map generator write it): the generated code then holds a `dataLayersByActor` map keyed by the actors' `ValueKey` ids and calls `partition.assignActorToLayer` for each name, so unloaded or merely loaded layers keep their actors from ticking exactly as the runtime defines it.

## `lib/data/services/engine_logger_service.dart`

### `class EngineLogEntry`

`EngineLogEntry`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EngineLogEntry.fromJson(Map<String, dynamic> json)`: Initializes `EngineLogEntry.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timestamp` | `String timestamp` | Holds the `timestamp` property or configuration state. |
| `level` | `String level` | Holds the `level` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class EngineLoggerService`

`EngineLoggerService`: Service class encapsulating business logic, file I/O, or engine processing.

**Constructors:**
- `EngineLoggerService()`: Initializes `EngineLoggerService()`.
- `EngineLoggerService._internal()`: Initializes `EngineLoggerService._internal()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `logStream` | `Stream<EngineLogEntry> get logStream` | Getter accessor returning the current value of `logStream`. |
| `logs` | `List<EngineLogEntry> get logs` | Getter accessor returning the current value of `logs`. |
| `clear` | `void clear()` | Clears all elements from the collection or buffer. |

## `lib/data/services/game_template_service.dart`

**Top-level Functions:**

- **`Map<String, dynamic> luminaTemplateSunActor() => _sun()`**: The directional sun actor map shared by the game and level templates.
- **`Map<String, dynamic> luminaTemplateSkyActor() => _sky()`**: The sky/atmosphere actor map shared by the game and level templates.

### `enum GameTemplateKind`

Which runtime pawn shape a template scaffolds.

### `class GameTemplate`

One entry of the shared template catalog.  This is the single source of truth both the launcher UI and `ProjectRepository.createProjectStream` read: the chip label and blurb, the actors seeded into `contents/levels/L_DefaultLevel.lmas`, the input actions and mapping context written into the manifest, and whether user-owned character / game-mode source is generated.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `icon` | `String icon` | Short icon hint the launcher maps to a shadcn icon. |
| `kind` | `GameTemplateKind kind` | Holds the `kind` property or configuration state. |
| `levelActors` | `List<Map<String, dynamic>> get levelActors` | A fresh, independently mutable copy of the seeded actor maps (`EditorActorNode.toMap()` shape). |
| `input` | `ProjectInputSettings get input` | A fresh copy of the input actions and mapping contexts for the manifest. |
| `generatesGameSource` | `bool get generatesGameSource` | Whether this template writes `lib/pawns/…` and `lib/game/…` source the user owns. |
| `classPrefix` | `static String classPrefix(String projectName)` | `my_first_game` → `MyFirstGame`. |
| `characterClass` | `String characterClass(String projectName)` | Dart class name of the generated character for [projectName]. |
| `gameModeClass` | `String gameModeClass(String projectName)` | Dart class name of the generated game mode, or the engine default for the blank template. This is what lands in [ProjectMapsAndModes.defaultGameMode]. |
| `characterPath` | `String characterPath(String projectName)` | `lib/`-relative path of the generated character file. |
| `gameModePath` | `String gameModePath(String projectName)` | `lib/`-relative path of the generated game mode file. |
| `manifestStepMessages` | `List<String> manifestStepMessages(String projectName)` | Human-readable step lines the creation progress log names for this template, so the user sees what is actually being written. |

### `class GameTemplateCatalog`

The three templates offered by the launcher.

**Constructors:**
- `GameTemplateCatalog._()`: Initializes `GameTemplateCatalog._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `byId` | `static GameTemplate byId(String? id)` | Resolves [id] to a template, tolerating the legacy `'Blank 3D'` label and unknown ids (both fall back to [blank3d]). |

## `lib/data/services/glb_parser_service.dart`

### `enum GlbNodeType`

`GlbNodeType`: Enumeration listing system options and state constants.

### `class GlbNode`

`GlbNode`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `index` | `int index` | Holds the `index` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `meshIndex` | `int? meshIndex` | Holds the `meshIndex` property or configuration state. |
| `meshName` | `String? meshName` | Holds the `meshName` property or configuration state. |
| `primitiveCount` | `int primitiveCount` | Holds the `primitiveCount` property or configuration state. |
| `children` | `List<GlbNode> children` | Holds the `children` property or configuration state. |
| `translation` | `List<double>? translation` | Holds the `translation` property or configuration state. |
| `rotation` | `List<double>? rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double>? scale` | Holds the `scale` property or configuration state. |
| `type` | `GlbNodeType type` | Holds the `type` property or configuration state. |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `isVisible` | `bool isVisible` | Holds the `isVisible` property or configuration state. |
| `totalDescendantCount` | `int get totalDescendantCount` | Getter accessor returning the current value of `totalDescendantCount`. |
| `directChildCount` | `int get directChildCount` | Getter accessor returning the current value of `directChildCount`. |
| `getAllDescendantNodeIndices` | `List<int> getAllDescendantNodeIndices()` | Queries and returns the `AllDescendantNodeIndices` value or child object. |
| `getAllDescendantPositions` | `List<double> getAllDescendantPositions()` | Queries and returns the `AllDescendantPositions` value or child object. |
| `getAllDescendantIndices` | `List<int> getAllDescendantIndices()` | Queries and returns the `AllDescendantIndices` value or child object. |

### `class GlbSubPrimitive`

`GlbSubPrimitive`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `vertexColors` | `Uint8List? vertexColors` | Holds the `vertexColors` property or configuration state. |
| `baseColor` | `List<double> baseColor` | Holds the `baseColor` property or configuration state. |
| `materialName` | `String? materialName` | Holds the `materialName` property or configuration state. |
| `materialIndex` | `int? materialIndex` | Holds the `materialIndex` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |

### `class GlbMorphTarget`

`GlbMorphTarget`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `positionDeltas` | `List<double> positionDeltas` | Holds the `positionDeltas` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |

### `class GlbAnimationChannel`

`GlbAnimationChannel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `nodeIndex` | `int nodeIndex` | Holds the `nodeIndex` property or configuration state. |
| `nodeName` | `String nodeName` | Holds the `nodeName` property or configuration state. |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `keyframeTimes` | `List<double> keyframeTimes` | Holds the `keyframeTimes` property or configuration state. |
| `values` | `List<double> values` | Holds the `values` property or configuration state. |
| `interpolation` | `String interpolation` | Holds the `interpolation` property or configuration state. |

### `class GlbAnimationClip`

`GlbAnimationClip`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `animatedNodeIndices` | `animatedNodeIndices` | Holds the `animatedNodeIndices` property or configuration state. |
| `channelTargetPaths` | `channelTargetPaths` | Holds the `channelTargetPaths` property or configuration state. |
| `channels` | `List<GlbAnimationChannel> channels` | Holds the `channels` property or configuration state. |
| `compositeKeyframeTimes` | `List<double> compositeKeyframeTimes` | Holds the `compositeKeyframeTimes` property or configuration state. |

### `class GlbMeshData`

`GlbMeshData`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `subPrimitives` | `List<GlbSubPrimitive> subPrimitives` | Holds the `subPrimitives` property or configuration state. |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `uvs` | `List<double> uvs` | Holds the `uvs` property or configuration state. |
| `minBounds` | `List<double> minBounds` | Holds the `minBounds` property or configuration state. |
| `maxBounds` | `List<double> maxBounds` | Holds the `maxBounds` property or configuration state. |
| `baseColor` | `List<double> baseColor` | Holds the `baseColor` property or configuration state. |
| `vertexColors` | `vertexColors` | Holds the `vertexColors` property or configuration state. |
| `rawPayload` | `Uint8List? rawPayload` | Holds the `rawPayload` property or configuration state. |
| `rootNodes` | `List<GlbNode> rootNodes` | Holds the `rootNodes` property or configuration state. |
| `allNodes` | `List<GlbNode> allNodes` | Holds the `allNodes` property or configuration state. |
| `materialNames` | `List<String> materialNames` | Holds the `materialNames` property or configuration state. |
| `skeletonJointIndices` | `Set<int> skeletonJointIndices` | Holds the `skeletonJointIndices` property or configuration state. |
| `morphTargets` | `List<GlbMorphTarget> morphTargets` | Holds the `morphTargets` property or configuration state. |
| `jointsPerVertex` | `Uint16List? jointsPerVertex` | Holds the `jointsPerVertex` property or configuration state. |
| `weightsPerVertex` | `Float32List? weightsPerVertex` | Holds the `weightsPerVertex` property or configuration state. |
| `maxInfluences` | `int maxInfluences` | Holds the `maxInfluences` property or configuration state. |
| `animations` | `List<GlbAnimationClip> animations` | Holds the `animations` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |
| `boneCount` | `int get boneCount` | Getter accessor returning the current value of `boneCount`. |
| `animatedNodeIndices` | `Set<int> get animatedNodeIndices` | Getter accessor returning the current value of `animatedNodeIndices`. |

### `class _GlbDecodedImage`

`_GlbDecodedImage`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_GlbDecodedImage(this.width, this.height, this.rawPixels)`: Initializes `_GlbDecodedImage(this.width, this.height, this.rawPixels)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `rawPixels` | `Uint8List rawPixels` | Holds the `rawPixels` property or configuration state. |
| `sample` | `List<int> sample(double u, double v)` | Executes `sample` operation. |

### `class _NodeTransform`

`_NodeTransform`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_NodeTransform(this.translation, this.rotation, this.scale)`: Initializes `_NodeTransform(this.translation, this.rotation, this.scale)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `translation` | `List<double> translation` | Holds the `translation` property or configuration state. |
| `rotation` | `List<double> rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double> scale` | Holds the `scale` property or configuration state. |

### `class GlbParserService`

`GlbParserService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `parseGlb` | `static Future<GlbMeshData?> parseGlb(Uint8List bytes)` | Executes `parseGlb` operation. |

## `lib/data/services/level_template_service.dart`

**Top-level Functions:**

- **`Map<String, dynamic> defaultWorldPartitionSection()`**: A fresh `metadata.worldPartition` section carrying the runtime's own defaults and no data layers (a level authors those itself).

### `class LevelTemplate`

One entry in the New Level dialog.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | One line describing exactly what this template seeds — shown in the dialog, so it must stay truthful. |
| `levelActors` | `List<Map<String, dynamic>> get levelActors` | Fresh actor maps (`EditorActorNode.toMap()` shape) for a new level. |
| `worldPartition` | `Map<String, dynamic>? get worldPartition` | Fresh `metadata.worldPartition` section, or null when the template does not author one (`Empty`, `Default`). |

### `class LevelTemplateCatalog`

The templates `File → New Level…` offers, in dialog order.

**Constructors:**
- `LevelTemplateCatalog._()`: Initializes `LevelTemplateCatalog._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `byId` | `static LevelTemplate byId(String? id)` | Resolves [id] to a template; unknown ids fall back to [standard]. |

## `lib/data/services/obj_import_service.dart`

### `class MtlMaterial`

One `newmtl` block of a Wavefront `.mtl` file: `name`, `diffuse` (`Kd`), `dissolve` (`d`), `opacity` (`d`, else `1 - Tr`, else 1), `diffuseMap` (`map_Kd`), `normalMap` (`norm`, `map_Bump` / `bump`), `alphaMap` (`map_d`), `specularMap` (`map_Ks`). Texture paths are as written, with map options (`-bm 1`, `-o u v w`, `-clamp on`, …) removed; a path may contain spaces.

### `class ObjImportResult`

An OBJ file converted for the import pipeline: `glb` (the materials with their MTL values, found textures embedded), `materialLibraries` (the `mtllib` names), `missingMaterialLibraries`, `missingTextures` (`path` as the MTL wrote it, `file`, `uses`: the material and slot that wanted it) and `embeddedTextures`.

### `abstract final class ObjImportService`

OBJ → GLB for the import pipeline. The asset repository stages every `.obj` through it (Content Browser import and drag and drop, folder import, the MCP `import_asset` tool, importing the same file again), converting from the source file's own folder so its `.mtl` and textures resolve. Assimp converts the geometry; the MTL is also read here and applied to the glTF materials by name:

- `Kd` → base colour; `d`, or `1 - Tr` when only `Tr` is given, below 1 → alpha and `BLEND` (drawn as `blending : fade`);
- `map_Kd` → base colour texture (the colour factor turns white), `map_Bump` / `bump` / `norm` → normal texture, `map_Ks` → specular texture (`specularMap`, drawn as reflectance);
- `map_d` → the base colour texture's alpha: the `map_d` image (its alpha channel, else its luminance) is baked into the diffuse image, or used as it is when both name the same file; `MASK` (cutoff 0.5) when that alpha only has clear and opaque texels (anti-aliased edges allowed), `BLEND` otherwise.

`mtllib` names resolve as written relative to the OBJ (folders and file in any case when that spelling is not on disk), then by file name in any case in its folder (then `<obj name>.mtl`, as Assimp does); texture paths like an FBX's ([FbxTextureLocator]): as written, relative to the OBJ (likewise in any case), then by file name in the OBJ's folder, the Import dialog's Textures Folder and the usual `Textures/` folders. A material library or texture found nowhere gets one Output Log warning naming it; the import goes on without it. Materials no mesh uses (Assimp's `DefaultMaterial`) are dropped. When Assimp cannot convert the file, the OBJ is staged as it is.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isObj` | `static bool isObj(String path)` |  |
| `convert` | `static Future<ObjImportResult?> convert(String objPath, {List<String> textureSearchDirs = const []})` | [convertSync] in a background isolate. |
| `convertSync` | `static ObjImportResult? convertSync(String objPath, {List<String> textureSearchDirs = const []})` | Null when Assimp cannot convert the file (the bridge is not loaded or the OBJ is unreadable). |
| `materialLibraries` | `static List<String> materialLibraries(String source)` | The `mtllib` names of an OBJ's [source], in order (a name may contain spaces). |
| `locateMaterialLibrary` | `static File? locateMaterialLibrary(File objFile, String name)` | The file an `mtllib` [name] refers to: as written relative to the OBJ (or absolute), with its folders and file in any case ([FbxTextureLocator.findIgnoringCase]), then by file name in any case in the OBJ's folder. |
| `parseMtl` | `static List<MtlMaterial> parseMtl(String source)` | The materials of an MTL [source]. |

## `lib/data/services/obj_parser_service.dart`

### `class ObjParserService`

Service for parsing Wavefront OBJ 3D model geometry.

## `lib/data/services/plugin_host_patcher_service.dart`

### `class PluginHostPatcherService`

`PluginHostPatcherService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `patchPubspec` | `Future<void> patchPubspec(Directory hostRoot, List<LuminaPluginDescripto...` | Executes `patchPubspec` operation. |
| `generateRegistrar` | `Future<void> generateRegistrar(Directory hostRoot, List<LuminaPluginDesc...` | Executes `generateRegistrar` operation. |

## `lib/data/services/plugin_registry_service.dart`

### `enum PluginIssueType`

`PluginIssueType`: Enumeration listing system options and state constants.

### `class PluginIssue`

`PluginIssue`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PluginIssue(this.type, this.message)`: Initializes `PluginIssue(this.type, this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `type` | `PluginIssueType type` | Holds the `type` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |

### `class PluginEntry`

`PluginEntry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `descriptor` | `LuminaPluginDescriptor descriptor` | Holds the `descriptor` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `restartPending` | `bool restartPending` | Holds the `restartPending` property or configuration state. |
| `issues` | `List<PluginIssue> issues` | Holds the `issues` property or configuration state. |

### `class PluginResolution`

`PluginResolution`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PluginResolution(this.resolvedPlugins, this.issues)`: Initializes `PluginResolution(this.resolvedPlugins, this.issues)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `resolvedPlugins` | `List<LuminaPluginDescriptor> resolvedPlugins` | Holds the `resolvedPlugins` property or configuration state. |
| `issues` | `List<PluginIssue> issues` | Holds the `issues` property or configuration state. |

### `class EnableResult`

`EnableResult`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `restartRequired` | `bool restartRequired` | Holds the `restartRequired` property or configuration state. |
| `issues` | `List<PluginIssue> issues` | Holds the `issues` property or configuration state. |

### `class PluginRegistryService`

`PluginRegistryService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `repo` | `PluginRepository repo` | Holds the `repo` property or configuration state. |
| `projectRepo` | `ProjectRepository projectRepo` | Holds the `projectRepo` property or configuration state. |
| `entries` | `List<PluginEntry> get entries` | Getter accessor returning the current value of `entries`. |
| `scanErrors` | `List<PluginScanError> get scanErrors` | Getter accessor returning the current value of `scanErrors`. |
| `refresh` | `Future<void> refresh()` | Executes `refresh` operation. |
| `initialize` | `Future<void> initialize(String projectDirPath)` | Executes `initialize` operation. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | Executes `resolve` operation. |

## `lib/data/services/plugin_template_generator_service.dart`

### `enum PluginTemplateType`

`PluginTemplateType`: Enumeration listing system options and state constants.

### `class PluginTemplateSpec`

`PluginTemplateSpec`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `templateType` | `PluginTemplateType templateType` | Holds the `templateType` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `friendlyName` | `String friendlyName` | Holds the `friendlyName` property or configuration state. |
| `author` | `String author` | Holds the `author` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `category` | `String category` | Holds the `category` property or configuration state. |

### `class PluginGenerationResult`

`PluginGenerationResult`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `success` | `bool success` | Holds the `success` property or configuration state. |
| `pluginDir` | `Directory? pluginDir` | Holds the `pluginDir` property or configuration state. |
| `descriptor` | `LuminaPluginDescriptor? descriptor` | Holds the `descriptor` property or configuration state. |
| `log` | `List<String> log` | Holds the `log` property or configuration state. |
| `failureOutput` | `String? failureOutput` | Holds the `failureOutput` property or configuration state. |

### `class PluginTemplateGeneratorService`

`PluginTemplateGeneratorService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectRoot` | `Directory projectRoot` | Holds the `projectRoot` property or configuration state. |
| `editorApiRoot` | `Directory editorApiRoot` | Holds the `editorApiRoot` property or configuration state. |
| `runner` | `ProcessRunner runner` | Holds the `runner` property or configuration state. |
| `nameToFriendly` | `static String nameToFriendly(String name)` | Executes `nameToFriendly` operation. |
| `nameToPascal` | `static String nameToPascal(String name)` | Executes `nameToPascal` operation. |
| `generate` | `Future<PluginGenerationResult> generate(PluginTemplateSpec spec)` | Executes `generate` operation. |

## `lib/data/services/primitive_glb_factory.dart`

### `class PrimitiveGlbFactory`

Builds a real glTF 2.0 binary (`.glb`) for an engine primitive.  `Primitive` actors — the template test rooms, and "spawn a cube" — carry a shape and a size instead of an imported model. Rather than teaching every consumer a second geometry path, the shape is turned into an ordinary glTF binary here, so it flows through the same parser, the same renderer, the same picking and the same triangle counter as any imported mesh.  Geometry is centred on the origin and sized in world units (cm), so the actor's own transform places it. Output is deterministic for a given request.  Every shape carries `TEXCOORD_0` and `TANGENT`, so a textured (or normal-mapped) material assigned to it draws its texture: each box face and the plane map the whole 0..1 square upright, a sphere and a cylinder wall wrap it once around (u) from top (v = 0) to bottom (v = 1), and cylinder caps map it as a disc. UVs follow glTF (v runs down the image); tangents point along +u, with `w` making `cross(normal, tangent) * w` point up the image, as glTF defines it.

**Constructors:**
- `PrimitiveGlbFactory._()`: Initializes `PrimitiveGlbFactory._()`.

### `class _Geometry`

`_Geometry`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_Geometry(this.positions, this.normals, this.uvs, this.indices)`: Initializes `_Geometry(this.positions, this.normals, this.uvs, this.indices)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `normals` | `List<double> normals` | Holds the `normals` property or configuration state. |
| `uvs` | `List<double> uvs` | Holds the `uvs` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |

## `lib/data/services/project_input_binder.dart`

### `class LuminaAxisPlacementModifier`

Places a key's raw 1D value onto one axis of a 2D action, scaled — a swizzle-axis and a scalar modifier in one.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toX` | `double toX` | Holds the `toX` property or configuration state. |
| `toY` | `double toY` | Holds the `toY` property or configuration state. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Executes `modify` operation. |

### `class BoundMappingContext`

One mapping context from the manifest, with the priority it was authored at.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `priority` | `int priority` | Holds the `priority` property or configuration state. |
| `context` | `LuminaInputMappingContext context` | Holds the `context` property or configuration state. |

### `class BoundProjectInput`

The result of binding a project's input settings to the runtime.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `contexts` | `List<BoundMappingContext> contexts` | Holds the `contexts` property or configuration state. |
| `actions` | `Map<String, LuminaInputAction> actions` | Holds the `actions` property or configuration state. |
| `unboundKeys` | `List<String> unboundKeys` | Labels of keys the manifest binds that the runtime has no equivalent for. Reported rather than silently dropped, so the editor can say so. |
| `actionByName` | `LuminaInputAction? actionByName(String name)` | Executes `actionByName` operation. |

### `class ProjectInputBinder`

Turns the `.lmproject` manifest's [ProjectInputSettings] — the same structures the Project Settings input editor edits — into the runtime's actions and mapping contexts.  Play-In-Editor binds through this, so rebinding a key in Project Settings changes what Play does, instead of PIE keeping a second hardcoded list.

**Constructors:**
- `ProjectInputBinder._()`: Initializes `ProjectInputBinder._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bind` | `static BoundProjectInput bind(ProjectInputSettings settings)` | Executes `bind` operation. |

## `lib/data/services/tga_decoder_service.dart`

### `class TgaImage`

`TgaImage`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `rgbaBytes` | `Uint8List rgbaBytes` | Holds the `rgbaBytes` property or configuration state. |

### `class TgaDecoderService`

`TgaDecoderService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isTga` | `static bool isTga(Uint8List bytes)` | Checks if given bytes match a valid TGA image header |
| `decode` | `static TgaImage? decode(Uint8List bytes)` | Decodes TGA binary bytes into raw RGBA8888 pixels |
| `tgaToPng` | `static Uint8List? tgaToPng(Uint8List tgaBytes)` | Converts TGA bytes directly to standard PNG bytes |
| `encodePng` | `static Uint8List encodePng(Uint8List rgba, int width, int height)` | Pure Dart standard PNG encoder with zlib compression |

## `lib/data/services/thumbnail_service.dart`

### `class ThumbnailService`

`ThumbnailService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `writeThumbnailCache` | `void writeThumbnailCache(String lmasPath, Uint8List png)` | Executes `writeThumbnailCache` operation. |
| `readThumbnailCache` | `Uint8List? readThumbnailCache(String lmasPath)` | Executes `readThumbnailCache` operation. |

---

[Previous: Utilities, math and testing](utilities.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: use cases and services (continued, part 1)](data-services-continued.md)
