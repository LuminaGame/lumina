[Türkçe](../../tr/lumina_editor_data/services.md)

# Data layer: use cases and services

The editor-facing data layer, part one: the domain use cases (save level, import asset, generate Dart code) and the services behind them: asset reference graph, the Dart code generator, the GLB service (the engine's GLB reader plus the import sanitizer) and the OBJ parser, the plugin registry and template generator, and thumbnails. The project input binder is engine runtime ([Input](../lumina/input.md)). The pure services (auto-save timer, engine logger, game and level templates, TGA decoder, host patcher, primitive GLB factory, workspace and data paths, build fingerprint and cache, glTF tools and others) live in `lumina_core`: see [Services](../lumina_core/services.md). File paths are relative to the `lumina_editor_data/` package directory.

**On this page:**

- [`lib/src/domain/use_cases/generate_dart_code_use_case.dart`](#libsrcdomainuse_casesgenerate_dart_code_use_casedart)
- [`lib/src/domain/use_cases/import_asset_use_case.dart`](#libsrcdomainuse_casesimport_asset_use_casedart)
- [`lib/src/domain/use_cases/save_level_use_case.dart`](#libsrcdomainuse_casessave_level_use_casedart)
- [`lib/src/domain/use_cases/use_case_validation.dart`](#libsrcdomainuse_casesuse_case_validationdart)
- [`lib/src/domain/models/use_case_results.dart`](#libsrcdomainmodelsuse_case_resultsdart)
- [`lib/src/services/asset_reference_graph.dart`](#libsrcservicesasset_reference_graphdart)
- [`lib/src/services/assimp_import_service.dart`](#libsrcservicesassimp_import_servicedart)
- [`lib/src/services/code_generator_service.dart`](#libsrcservicescode_generator_servicedart)
- [`lib/src/services/obj_import_service.dart`](#libsrcservicesobj_import_servicedart)
- [`lib/src/services/obj_parser_service.dart`](#libsrcservicesobj_parser_servicedart)
- [`lib/src/services/plugin_registry_service.dart`](#libsrcservicesplugin_registry_servicedart)
- [`lib/src/services/plugin_template_generator_service.dart`](#libsrcservicesplugin_template_generator_servicedart)
- [`lib/src/services/thumbnail_service.dart`](#libsrcservicesthumbnail_servicedart)
- [`lib/src/services/glb_parser_service.dart`](#libsrcservicesglb_parser_servicedart)

## `lib/src/domain/use_cases/generate_dart_code_use_case.dart`

### `class GenerateDartCodeUseCase`

Generates the live declarative Dart code for a level (`lib/main.dart` + `lib/levels/<levelName>.dart`) via [DartCodeGeneratorService] and, when a [LuminaProject] is supplied, clears its dirty flag and stamps `lastCodeGeneratedTimestamp` through [ProjectRepository.saveProject].

## `lib/src/domain/use_cases/import_asset_use_case.dart`

### `class ImportAssetUseCase`

Imports an external model/texture/audio file into a project's `contents/` tree through [AssetRepository.importExternalFile] (stage → convert → resolve paths → emit `.lmas` family). Unsupported formats and thrown pipeline errors become a failure result.

## `lib/src/domain/use_cases/save_level_use_case.dart`

### `class SaveLevelUseCase`

Writes the active level as a `contents/levels/<levelName>.lmas` JSON container.  The container is exactly what Lumina Studio writes on Save Level: `assetId` (`level_<name>`), `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and `metadata.actors` — the actor maps (`EditorActorNode.toMap()`) are passed through untouched. Validation and I/O failures are reported in the result, never thrown.

## `lib/src/domain/use_cases/use_case_validation.dart`

**Top-level Functions:**

- **`String? validateProjectDir(String projectDir)`**: Shared input validation for the use-case layer. Returns an error message or null.
- **`String? validateLevelName(String levelName)`**: A level name must be a plain file stem: no separators, no parent references.

## `lib/src/domain/models/use_case_results.dart`

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

## `lib/src/services/asset_reference_graph.dart`

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

## `lib/src/services/assimp_import_service.dart`

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

## `lib/src/services/code_generator_service.dart`

### `class DartCodeGeneratorService`

`DartCodeGeneratorService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `generateActorRegistryDart` | `String generateActorRegistryDart(List<String> actorNames)` | Generates the actors.g.dart registry file. |
| `compileAndWriteActor` | `Future<bool> compileAndWriteActor(String projectPath, String assetName, ...` | Compiles a blueprint document into a project's lib/actors/ file. |
| `writeProjectInputDart` | `bool writeProjectInputDart(String projectPath, [ProjectInputSettings? settings])` | Writes `lib/input/project_input.g.dart` from settings or project manifest. |

The generated level's begin-play registers `LuminaWorldPartitionSubsystem` with the level's `metadata.worldPartition` section (cell size, transitions per tick, the data layers with their initial state), adds every actor to the partition and registers the streaming sources. A level row may carry `dataLayers: [<layer name>, ...]` (the editor does not author it yet; tools such as the map generator write it): the generated code then holds a `dataLayersByActor` map keyed by the actors' `LuminaObjectKey` ids and calls `partition.assignActorToLayer` for each name, so unloaded or merely loaded layers keep their actors from ticking exactly as the runtime defines it.

## `lib/src/services/obj_import_service.dart`

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

## `lib/src/services/obj_parser_service.dart`

### `class ObjParserService`

Service for parsing Wavefront OBJ 3D model geometry.

## `lib/src/services/plugin_registry_service.dart`

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
| `overrides` | `List<PluginShadow> overrides` | The same-named copies of lower-priority roots this plugin overrides (shown on its Plugin Manager card, `overrides` in `list_plugins`). |

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
| `shadowed` | `List<PluginShadow> get shadowed` | Plugin copies overridden by a same-named plugin of a higher-priority root; informational, never a scan error. |
| `refresh` | `Future<void> refresh()` | Executes `refresh` operation. |
| `initialize` | `Future<void> initialize(String projectDirPath)` | Executes `initialize` operation. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | Executes `resolve` operation. |
| `project` | `LuminaProject? get project` | The open project as last loaded or saved. |
| `isolationOf` | `PluginIsolation isolationOf(String name)` | Where plugin `name` runs in the open project (`LuminaPluginDescriptor.effectiveIsolation`): its `plugin_isolation` override, else its manifest; a plugin without a process part (or an unknown one) runs in process. |
| `isolationOverrideOf` | `PluginIsolation? isolationOverrideOf(String name)` | The open project's override for `name`, or null. |
| `setIsolationOverride` | `Future<bool> setIsolationOverride(String name, PluginIsolation? isolation)` | Sets (null removes) the project's override and saves the `.lmproject`; true when the enabled plugin's effective isolation changed, which marks it `restartPending`. |

## `lib/src/services/plugin_template_generator_service.dart`

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
| `isolated` | `final bool isolated` | Scaffolds an isolated plugin: `lib/src/<name>_process.dart` (`<Pascal>Process extends LuminaPluginProcess`: a menu command, a `ping` handler, a declarative panel, and with the importer template its importer), a UI shell whose panel calls `ping` through `processChannel`, `test/<name>_process_test.dart` + `test/<name>_plugin_test.dart`, and `"isolation": "process"` + `"process_class"` in the manifest. A content-only plugin cannot be isolated (generation fails). The sources come from `plugin_template/isolated_plugin_sources.dart` (in-process templates: `plugin_template/code_plugin_sources.dart`). |

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

## `lib/src/services/thumbnail_service.dart`

### `class ThumbnailService`

`ThumbnailService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `writeThumbnailCache` | `void writeThumbnailCache(String lmasPath, Uint8List png)` | Executes `writeThumbnailCache` operation. |
| `readThumbnailCache` | `Uint8List? readThumbnailCache(String lmasPath)` | Executes `readThumbnailCache` operation. |

## `lib/src/services/glb_parser_service.dart`

### `class GlbParserService`

`GlbParserService`: the editor's GLB service. `parseGlb` reads mesh data with lumina_core's `GlbReader` (the models are documented in [lumina_core services](../lumina_core/services-continued.md)), the engine's decoders (`LuminaGlbLoader.decoders`: Filament's Draco decoder and the platform image codec) and this service's sanitizer as `prepare`. The sanitizer (`convertGlbTgaToPng`, `convertGlbTgaToPngAsync`, `inspectImageWork`) converts TGA textures to PNG, embeds external images, downscales textures over `defaultMaxTextureSize` and reduces skins to four normalised influences; its output version is `sanitizerVersion`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `parseGlb` | `static Future<GlbMeshData?> parseGlb(Uint8List bytes)` | Mesh data of a GLB or a `.lmas` wrapping one, read after the sanitizer. |
| `convertGlbTgaToPng` | `static Uint8List convertGlbTgaToPng(Uint8List glbBytes, {List<String>? searchDirs, int maxTextureSize})` | The sanitized GLB bytes. |
| `convertGlbTgaToPngAsync` | `static Future<Uint8List> convertGlbTgaToPngAsync(Uint8List glbBytes, {List<String>? searchDirs, int maxTextureSize})` | The same on a background isolate when images must be decoded. |
| `inspectImageWork` | `static ({bool needsDecoding, bool selfContained}) inspectImageWork(Uint8List glbBytes, {int maxTextureSize})` | What sanitizing costs, read from image headers only. |

---

[Previous: lumina_editor_data (editor data layer)](index.md) | [Up: lumina_editor_data (editor data layer)](index.md) | [Next: Data layer: use cases and services (continued, part 1)](services-continued.md)
