[Türkçe](../../tr/lumina/data-services-continued-3.md)

# Data layer: use cases and services (continued, part 3)

Continuation of Data layer: use cases and services: the remaining public files under `lib/data/services/`. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/data/services/import_folder_scanner.dart`](#libdataservicesimport_folder_scannerdart)
- [`lib/data/services/import_image_conversion.dart`](#libdataservicesimport_image_conversiondart)
- [`lib/data/services/import_queue.dart`](#libdataservicesimport_queuedart)
- [`lib/data/services/level_asset_manifest.dart`](#libdataserviceslevel_asset_manifestdart)
- [`lib/data/services/mesh_collision_service.dart`](#libdataservicesmesh_collision_servicedart)
- [`lib/data/services/mesh_physics_service.dart`](#libdataservicesmesh_physics_servicedart)
- [`lib/data/services/thumbnail_sidecar_migration.dart`](#libdataservicesthumbnail_sidecar_migrationdart)
- [`lib/data/services/web_loading_screen_service.dart`](#libdataservicesweb_loading_screen_servicedart)

## `lib/data/services/import_folder_scanner.dart`

### `class ImportFolderFile`

One primary file a folder import brings in, with the files that travel with it.

**Constructors:**

- `const ImportFolderFile({required this.path, required this.relativePath, required this.kind, required this.bytes, this.companions = const [],})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` | Absolute path. |
| `relativePath` | `final String relativePath` | Path under the scanned folder, `/`-separated (`Props/Barrels/x.glb`). |
| `kind` | `final ImportFormatKind kind` |  |
| `bytes` | `final int bytes` | Its size plus its companions'. |
| `companions` | `final List<String> companions` | A `.gltf`'s buffers and images, an OBJ's `.mtl` and its textures (absolute paths): grouped here, never imported on their own. |
| `relativeDir` | `String get relativeDir` | The folder under the scanned root, '' at the root (`Props/Barrels`). |
| `fileName` | `String get fileName` |  |
| `baseName` | `String get baseName` | The file name without its extension: the imported asset's name. |

### `class SkippedImportFile`

A file a folder import leaves out, and why.

**Constructors:**

- `const SkippedImportFile({required this.path, required this.relativePath, required this.reason})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `relativePath` | `final String relativePath` |  |
| `reason` | `final String reason` |  |

### `class ImportFolderScan`

What [ImportFolderScanner.scan] found under [root].

**Constructors:**

- `const ImportFolderScan({required this.root, required this.files, required this.skipped, required this.ignored, required this.totalBytes,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `root` | `final String root` |  |
| `files` | `final List<ImportFolderFile> files` | Primary files, sorted by [ImportFolderFile.relativePath]. |
| `skipped` | `final List<SkippedImportFile> skipped` | Files that are not imported (unsupported, orphaned companions, links, a glTF missing a buffer), sorted by path. |
| `ignored` | `final int ignored` | Hidden files and folders and OS junk (`.DS_Store`, `Thumbs.db`, …), left out silently. |
| `totalBytes` | `final int totalBytes` | Bytes of every file that imports, companions included (each once). |
| `companionCount` | `int get companionCount` |  |
| `countsByKind` | `Map<ImportFormatKind, int> get countsByKind` | How many primary files import as each kind. |
| `folders` | `Set<String> get folders` | The distinct folders (relative) the primary files sit in. |

### `class ImportFolderScanner`

Walks a folder for File → Import Asset Folder…: every file the import pipeline takes ([ImportFormats]), recursively.

Hidden folders and files and OS junk are ignored; symbolic links are not followed unless asked (and then each real folder is visited once); a `.gltf`'s `.bin` and images and an OBJ's `.mtl` and textures are grouped with it, so they import once, as part of it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `junkFileNames` | `static const Set<String> junkFileNames` | File names (lower case) the walk ignores. |
| `scanInBackground` | `static Future<ImportFolderScan> scanInBackground(String root, {bool followLinks = false})` | [scan] in a background isolate, for a big tree. |
| `scan` | `static ImportFolderScan scan(String root, {bool followLinks = false})` |  |

### `enum ImportConflictPolicy`

What to do when an imported asset's target already exists.

**Values:**

- `skip`: Leave the existing asset; the file is not imported.
- `overwrite`: Re-import over it (it keeps its asset id, so references hold).
- `rename`: Import beside it as `<name>_1` (`_2`, …).

### `class ImportFolderOptions`

The Import Asset Folder summary dialog's options.

**Constructors:**

- `const ImportFolderOptions({this.targetFolder = 'contents', this.mirrorFolderStructure = true, this.conflictPolicy = ImportConflictPolicy.skip, this.autoOrganize...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targetFolder` | `final String targetFolder` | The Content Browser folder the tree lands in (`contents/Imported`). |
| `mirrorFolderStructure` | `final bool mirrorFolderStructure` | `Props/Barrels/x.glb` → `<target>/Props/Barrels/` instead of `<target>/`. |
| `conflictPolicy` | `final ImportConflictPolicy conflictPolicy` |  |
| `autoOrganize` | `final bool autoOrganize` | Sort by type into `contents/meshes/static/`, `contents/textures/`, … instead (target folder and mirroring then do not apply). |
| `generateLods` | `final bool generateLods` |  |
| `copyWith` | `ImportFolderOptions copyWith({String? targetFolder, bool? mirrorFolderStructure, ImportConflictPolicy? conflic...` |  |

### `class PlannedFolderImport`

One file of an [ImportFolderPlan].

**Constructors:**

- `const PlannedFolderImport({required this.file, required this.request, required this.targetPath, this.conflicted = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `file` | `final ImportFolderFile file` |  |
| `request` | `final ImportRequest request` |  |
| `targetPath` | `final String targetPath` | Where its primary `.lmas` lands (project-relative); with Auto Organize the type decides, so this is the likeliest folder. |
| `conflicted` | `final bool conflicted` | Its target already existed (or another file of the batch takes it): it overwrites, or was renamed. |

### `class ImportFolderPlan`

A scan turned into import requests under [ImportFolderOptions]: target folders (mirrored or not) and the conflict policy applied.

**Constructors:**

- `const ImportFolderPlan({required this.imports, required this.skippedExisting})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `imports` | `final List<PlannedFolderImport> imports` |  |
| `skippedExisting` | `final List<ImportFolderFile> skippedExisting` | Files left out because their asset exists (policy skip). |
| `requests` | `List<ImportRequest> get requests` |  |
| `conflicts` | `int get conflicts` | Files whose target exists, whatever the policy did with them. |
| `folderFor` | `static String folderFor(ImportFolderFile file, ImportFolderOptions options)` | The folder [file] imports into. |
| `normalizeFolder` | `static String normalizeFolder(String folder)` | `contents/Imported/` → `contents/Imported` (and `\` → `/`). |
| `build` | `static ImportFolderPlan build(ImportFolderScan scan, {required String projectPath, required ImportFolderOption...` |  |

## `lib/data/services/import_image_conversion.dart`

### `abstract final class ImportImageConversion`

The conversion an image import runs on its source file: TGA and WebP are stored as PNG, every other format as it is. The Texture editor's Reimport runs the same one, so a reimported payload is what an import would store.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `convertsToPng` | `static bool convertsToPng(String fileName)` | Whether an image named [fileName] is stored as PNG rather than as it is. |
| `importBytes` | `static Future<Uint8List> importBytes(File source) async` | The bytes an import stores for the image [source]. |

## `lib/data/services/import_queue.dart`

### `enum ImportStage`

Where one file of an import batch is. A file moves queued → converting → writing → thumbnail → done, or ends failed / cancelled.

**Values:**

- `queued`: Waiting for a worker.
- `converting`: Staged, converted and routed in the worker isolate; its placeholder thumbnails drawn on the UI isolate.
- `writing`: The asset family being written under `contents/` by the worker.
- `thumbnail`: Written and indexed (it shows in the Content Browser); its rendered thumbnail is being made on the UI isolate.
- `done`
- `failed`
- `cancelled`: Never started: the batch was cancelled first.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isTerminal` | `bool get isTerminal` |  |

### `class ImportRequest`

One file to import and how.

**Constructors:**

- `const ImportRequest({required this.sourcePath, this.targetSubFolder, this.autoOrganize = true, this.generateLods = false, this.targetSkeletonPath, this.targetBa...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `sourcePath` | `final String sourcePath` | The external file (`.glb`, `.gltf`, `.obj`, `.fbx`, an image, …). |
| `targetSubFolder` | `final String? targetSubFolder` | The Content Browser folder it lands in when [autoOrganize] is off. |
| `autoOrganize` | `final bool autoOrganize` |  |
| `generateLods` | `final bool generateLods` |  |
| `targetSkeletonPath` | `final String? targetSkeletonPath` | For an animation: the skeletal mesh to retarget onto (see [AssetRepository.convertStagedAsset]). |
| `targetBaseName` | `final String? targetBaseName` | The asset's name when it is not the file's (the folder importer's "rename" conflict policy: `Barrel_01` → `Barrel_01_1`). |
| `textureSearchDirs` | `final List<String> textureSearchDirs` | For an FBX: folders searched first for its textures (the Import dialog's "Textures Folder"). |
| `fileName` | `String get fileName` |  |
| `needsUiIsolate` | `bool get needsUiIsolate` | Staging a `.webp` decodes it with `dart:ui`, which only the UI isolate may use, so such a file is converted there instead of in a worker. |

### `class ImportProgress`

One file's state, as [ImportQueue.progress] reports it.

**Constructors:**

- `const ImportProgress({required this.batch, required this.index, required this.total, required this.request, required this.stage, required this.fileFraction, req...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `batch` | `final int batch` | Which batch (1, 2, …): a batch lasts from the first file queued while the queue was idle until every file queued since is finished. |
| `index` | `final int index` | This file's position in its batch (0-based) and the batch's size when this event was sent (it grows when files are added mid-batch). |
| `total` | `final int total` |  |
| `request` | `final ImportRequest request` |  |
| `stage` | `final ImportStage stage` |  |
| `fileFraction` | `final double fileFraction` | How far this file is (0–1) and how far the batch is: the mean of every file's fraction, monotonic while no file is added. |
| `overallFraction` | `final double overallFraction` |  |
| `message` | `final String message` | What is happening, for the progress panel. |
| `elapsed` | `final Duration elapsed` | Since the batch started. |
| `result` | `final RealAssetInfo? result` | The primary asset, from [ImportStage.thumbnail] on. |
| `assets` | `final List<RealAssetInfo> assets` | Every asset the file produced (primary, materials, textures, clips), as the Content Browser lists them, from [ImportStage.thumbnail] on. |
| `error` | `final String? error` | Why it failed ([ImportStage.failed]). |
| `fileName` | `String get fileName` |  |

### `class ImportBatchSummary`

How a batch ended.

**Constructors:**

- `const ImportBatchSummary({required this.batch, required this.total, required this.imported, required this.failed, required this.cancelled, required this.errors,...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `batch` | `final int batch` |  |
| `total` | `final int total` |  |
| `imported` | `final int imported` |  |
| `failed` | `final int failed` |  |
| `cancelled` | `final int cancelled` |  |
| `errors` | `final Map<String, String> errors` | File name → error, for every failed file. |
| `elapsed` | `final Duration elapsed` |  |

### `typedef ImportThumbnailStep`

The UI isolate's last step for a written file (the editor renders its Filament thumbnails here). Gets the file's [ImportStage.thumbnail] event.

### `class ImportQueue`

Imports files in the background: each file is staged and converted — glTF / OBJ / FBX parsing, Assimp, texture decoding and downscaling, the thumbnail's mesh projection — in a long-lived worker isolate, and written there too; the UI isolate only paints the placeholder thumbnails, indexes the new files and runs [thumbnailStep], one short step at a time with the event loop yielded between steps, so the editor keeps drawing frames.

Files go through the same [AssetRepository] steps as [AssetRepository.importExternalFile], so what lands on disk is identical. A file that fails never stops the batch; [cancel] lets the files in flight finish and skips the rest. Each worker loads its own FFI libraries (Assimp); no native pointer or Filament object ever crosses an isolate.

**Constructors:**

- `ImportQueue({required this.projectPath, int workers = 1, this.thumbnailStep, Future<void> Function()? frameYield, AssetRepository? repository,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `maxWorkers` | `static const int maxWorkers` | The most worker isolates a queue runs ([workers]). |
| `projectPath` | `final String projectPath` |  |
| `thumbnailStep` | `ImportThumbnailStep? thumbnailStep` |  |
| `workers` | `int get workers` | How many files convert at once, each in its own worker isolate (1–4). A change applies to the files not yet started. |
| `workers` | `set workers(int value)` |  |
| `progress` | `Stream<ImportProgress> get progress` | Every file's every stage change, in order. |
| `summaries` | `Stream<ImportBatchSummary> get summaries` | One summary per finished batch. |
| `files` | `List<ImportProgress> get files` | The current (or last) batch, one entry per file, in queue order. |
| `isRunning` | `bool get isRunning` |  |
| `isCancelling` | `bool get isCancelling` | Whether [cancel] was called during the current batch. |
| `total` | `int get total` |  |
| `finished` | `int get finished` |  |
| `imported` | `int get imported` |  |
| `failed` | `int get failed` |  |
| `cancelled` | `int get cancelled` |  |
| `overallFraction` | `double get overallFraction` | The batch's progress, 0–1. |
| `elapsed` | `Duration get elapsed` | Since the current (or last) batch started. |
| `lastSummary` | `ImportBatchSummary? get lastSummary` |  |
| `idle` | `Future<void> get idle` | Completes when no file is in flight. |
| `longestMainIsolateStep` | `Duration get longestMainIsolateStep` | The longest stretch any UI-isolate step of the queue held the isolate without yielding ([timeSynchronousSlices]) — the frame-budget figure, kept under 100 ms — and how many steps ran. |
| `mainIsolateSteps` | `int get mainIsolateSteps` |  |
| `longestMainIsolateStepByKind` | `Map<String, Duration> get longestMainIsolateStepByKind` | The longest run of each kind of UI-isolate step in the current batch (`thumbnails`, `index`, `decode`, …), for the smoke report. |
| `enqueue` | `Future<List<ImportProgress>> enqueue(List<ImportRequest> requests)` | Queues [requests] and returns at once; the future completes with each file's final state, in order, once all of them are finished. |
| `cancel` | `void cancel()` | Stops the batch after the files already converting: those finish and keep what they wrote; every file not yet started is cancelled. |
| `dispose` | `Future<void> dispose() async` | Stops the worker isolates. Files in flight are abandoned (their futures complete as cancelled); the queue cannot be used afterwards. |

### `class RemoteImportError`

An error raised in an import worker, carried back as its text.

**Constructors:**

- `const RemoteImportError(this.message)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `message` | `final String message` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `timeSynchronousSlices` | `Future<T> timeSynchronousSlices<T>(FutureOr<T> Function() body, void Function(Duration longest) report) async` | Runs [body] and reports the longest stretch it held this isolate without yielding — each synchronous run of its code and of every callback it schedules (future continuations, microtasks), not the time it spent waiting on I/O, other isolates or the engine (a codec, a raster). That is the most a step can delay a frame. |
| `describeImportError` | `String describeImportError(Object error)` | [error] as one readable line (no `Exception:` / `FormatException:` prefix). |

## `lib/data/services/level_asset_manifest.dart`

### `abstract final class LuminaLevelAssetManifest`

What a level loads: the assets its placed actors name — meshes, landscapes, sky environments, textures, materials, sounds, animation assets and the Blueprint classes placed in it with the assets their components name. The level code generator emits it as the level class's `assetManifest`; Play-In-Editor builds it from the level `.lmas` found through the project's asset index. Either way a [LuminaLevelPreloader] preloads it. A placed mesh's assigned material is listed only when it can be drawn ([LuminaLevelActorMaterial]).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fromActorMaps` | `static List<LuminaAssetRef> fromActorMaps(List<Map<String, dynamic>> actorMaps, {String? projectDir})` | The assets [actorMaps] (`metadata.actors`) name, in first-seen order and without duplicates, as bundle paths (`contents/…`). A placed Blueprint adds its class `.lmas` and — with [projectDir] to read the class from — the assets its components name. |
| `kindOf` | `static LuminaAssetKind kindOf(String path, {String? key})` | The kind of [path], from the key that named it (`staticMeshAsset`, `soundAsset`…) or its extension. |
| `bundlePath` | `static String bundlePath(String path)` | [path] as the game bundle names it: `contents/…` (a path through the project's `contents/` is cut there); any other path as it is. |
| `levelPath` | `static String? levelPath(LuminaAssetIndex index, String levelName)` | The project-relative `.lmas` of level [levelName] (`L_Arena`, `L_Arena.lmas` or `contents/…/L_Arena.lmas`), found through [index] (up to date): `contents/levels/<name>.lmas`, else the level asset of that name anywhere under `contents/`. Null when there is none. |
| `levelNames` | `static List<String> levelNames(LuminaAssetIndex index)` | The names of the project's levels, from [index] (up to date). |
| `forProjectLevel` | `static Future<List<LuminaAssetRef>?> forProjectLevel(String projectDir, String levelName) async` | Level [levelName] of [projectDir]'s asset list for Play-In-Editor: found and read through the asset index (refreshed first), paths absolute (the editor reads the disk). Null when there is no such level. |
| `toDartLiteral` | `static String toDartLiteral(List<LuminaAssetRef> refs, {String indent = ' '})` | [refs] as the `const` list literal a generated level's `assetManifest` holds. |

### `abstract final class LuminaLevelActorMaterial`

The material a placed level mesh or basic shape draws on every section in place of its own: the actor's `materialPath` (the Details panel's Material field, `set_actor_property material`). The level viewport, Play-In-Editor and the level code generator (`materialOverrideAsset`) all read it here.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `actorTypes` | `static const Set<String> actorTypes` | `Mesh`, `StaticMesh`, `SkeletalMesh`, `Primitive`. |
| `pathOf` | `static String? pathOf(Map<String, dynamic> actor)` | The assigned material as a bundle path (`contents/…`); null when none, for a placed Blueprint, or for a value that names no `.lmas` / `.filamat` (the placeholder names older editors wrote). |
| `problem` | `static String? problem(String path, {String? projectDir})` | Why the material cannot be drawn (not found, no compiled material), or null. The generator then emits a comment instead of the argument, Play and the viewport log it, and the mesh keeps its own. |
| `revision` | `static String revision(String path, {String? projectDir, Iterable<String> textures = const []})` | What the level viewport draws for the material: the material file's and each of [textures]' (its samplers' textures) modified time and size. The viewport rebuilds an actor's material when it changes: recompiled, or a texture saved, reimported or its settings changed. |

## `lib/data/services/mesh_collision_service.dart`

### `class MeshSimpleCollision`

A mesh asset's simple collision: convex [hulls] (imported `UCX_` pieces, then authored convex shapes), authored box / sphere / capsule [primitives], and the authored [complexity].

**Constructors:**

- `const MeshSimpleCollision({this.hulls = const [], this.primitives = const [], this.complexity = complexityDefault,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `hulls` | `final List<LuminaCollisionHull> hulls` |  |
| `primitives` | `final List<LuminaCollisionPrimitive> primitives` |  |
| `complexity` | `final String complexity` | The Static Mesh editor's Collision Complexity: [complexityDefault], [complexitySimpleAsComplex] or [complexityComplexAsSimple]. |
| `none` | `static const MeshSimpleCollision none` |  |
| `complexityDefault` | `static const String complexityDefault` | Simple shapes for queries and physics, the mesh triangles for complex traces. |
| `complexitySimpleAsComplex` | `static const String complexitySimpleAsComplex` | Simple shapes for complex traces too. |
| `complexityComplexAsSimple` | `static const String complexityComplexAsSimple` | Per-triangle collision for everything, which the runtime has no shape for; such a mesh plays with its simple shapes. |
| `isEmpty` | `bool get isEmpty` |  |

### `abstract final class MeshCollisionService`

A static mesh asset's simple collision, as the runtime builds it.

The FBX import keeps the `UCX_`/`UBX_`/`USP_`/`UCP_` meshes it strips from the drawn GLB as the asset's `collision_hulls` metadata, in the glTF frame (metres, +Y up, model space). This turns them into authored [LuminaCollisionHull]s (centimetres, Z up), splitting a hull whose triangles form several disconnected pieces into one convex element per piece. The Static Mesh editor's authored shapes (`metadata['collision']`) join them: boxes, spheres and capsules as primitives, convex shapes as hulls — read in cm, Z up, a legacy (glTF metre, Y-up) document converted by [authoredCollisionInCentimetres].

Editor-side only (it reads `.lmas` files): the level code generator bakes the result into the generated level, and Play-In-Editor builds its actors from it. A game never calls it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `metadataKey` | `static const String metadataKey` | The mesh asset metadata key the FBX import writes. |
| `authoredKey` | `static const String authoredKey` | The mesh asset metadata key the Static Mesh editor writes. |
| `minPoints` | `static const int minPoints` | Fewer points than this enclose no volume. |
| `hullsForMeshAsset` | `static List<LuminaCollisionHull> hullsForMeshAsset(String meshAssetPath, {String? projectDir})` | The convex hulls of the mesh asset at [meshAssetPath] (imported `UCX_` pieces and authored convex shapes); see [simpleCollisionForMeshAsset]. |
| `simpleCollisionForMeshAsset` | `static MeshSimpleCollision simpleCollisionForMeshAsset(String meshAssetPath, {String? projectDir})` | The simple collision of the mesh asset at [meshAssetPath]: an absolute path, or a project path (`contents/…`) resolved under [projectDir]. [MeshSimpleCollision.none] for a mesh without any, a file that is not a `.lmas`, or one that cannot be read. Cached per file until its size or modification time changes. |
| `simpleCollisionFromMetadata` | `static MeshSimpleCollision simpleCollisionFromMetadata(Map<String, String> metadata)` | A mesh asset's simple collision from its [metadata]: the imported `collision_hulls` ([hullsFromMetadata]) and the authored `collision` document. |
| `authoredCollisionInCentimetres` | `static Map<String, dynamic> authoredCollisionInCentimetres(Map<String, dynamic> json)` | A stored `collision` document in the authoring frame (cm, Z up). |
| `hullsFromMetadata` | `static List<LuminaCollisionHull> hullsFromMetadata(Map<String, String> metadata)` | Parses the `collision_hulls` entry of a mesh asset's [metadata]. |
| `toAuthoring` | `static List<double> toAuthoring(double x, double y, double z)` | A glTF point (metres, Y up) in the authoring frame (cm, Z up), with float noise from the unit conversion rounded away. |
| `connectedPieces` | `static List<List<int>> connectedPieces(List<double> points, List<int> triangles)` | Groups the vertices of a triangle mesh into its connected pieces. Vertices at the same position are one vertex (Assimp splits a hull's corners by face normal); vertices no triangle uses are left out. |

## `lib/data/services/mesh_physics_service.dart`

### `abstract final class MeshPhysicsService`

A static mesh asset's physics as the Static Mesh editor stores it (`metadata.physics = {massKg, centerOfMassOffset}`): what a simulating component inherits unless it overrides its mass.

Editor-side only (it reads `.lmas` files): Play-In-Editor sets `LuminaBlueprintComponents.meshPhysicsResolver` to [forMeshAsset]; a generated game uses the values the editor baked into the component.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `metadataKey` | `static const String metadataKey` | The mesh asset metadata key the Static Mesh editor writes. |
| `forMeshAsset` | `static LuminaMeshPhysics? forMeshAsset(String meshAssetPath, {String? projectDir})` | The physics of the mesh asset at [meshAssetPath] (absolute, or a project path resolved under [projectDir]); null for a file that is not a readable `.lmas` or has no `physics` metadata. Cached per file until its size or modification time changes. |
| `fromMetadata` | `static LuminaMeshPhysics? fromMetadata(Map<String, String> metadata)` | The physics in a mesh asset's [metadata]; null without any. |

## `lib/data/services/thumbnail_sidecar_migration.dart`

### `class ThumbnailSidecarMigrationReport`

What [ThumbnailSidecarMigration.run] did to one project.

**Constructors:**

- `const ThumbnailSidecarMigrationReport({this.removedDirectories = 0, this.removedSidecars = 0, this.reembedded = 0, this.restamped = 0, this.coverMoved = false,...`
- `factory ThumbnailSidecarMigrationReport.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `removedDirectories` | `final int removedDirectories` | `.thumbnails/` directories deleted. |
| `removedSidecars` | `final int removedSidecars` | Sidecar PNGs deleted. |
| `reembedded` | `final int reembedded` | `.lmas` files that had no embedded thumbnail and got the sidecar's. |
| `restamped` | `final int restamped` | `.lmas` whose current thumbnail was re-stamped for the new staleness rule (its modification time set back to the thumbnail stamp). |
| `coverMoved` | `final bool coverMoved` | Whether `contents/.thumbnails/cover.png` moved to `.lumina/cover.png`. |
| `gitignoreRules` | `final List<String> gitignoreRules` | Rules appended to the project's `.gitignore`. |
| `elapsed` | `final Duration elapsed` |  |
| `didAnything` | `bool get didAnything` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class ThumbnailSidecarMigration`

The one-time move away from `.thumbnails/` sidecar files.

Every `contents/**/.thumbnails/<name>.png` is checked against its `<name>.lmas`: an asset with no embedded thumbnail gets the sidecar's (re-embedded), an asset whose thumbnail was current under the old rule (sidecar not older than the `.lmas` nor its `.entity.glb`) is re-stamped so it stays current under the new one ([ThumbnailService.staleFor]), and then the sidecars and their folders are deleted. `contents/.thumbnails/cover.png` moves to `.lumina/cover.png`. An existing `.gitignore` gains `.lumina/` and `**/.thumbnails/` when it lacks them. Idempotent: a migrated project has nothing left to do.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `sidecarDirectoryName` | `static const String sidecarDirectoryName` |  |
| `legacyCoverPath` | `static const String legacyCoverPath` |  |
| `coverPath` | `static const String coverPath` |  |
| `gitignoreRules` | `static const List<String> gitignoreRules` |  |
| `sidecarDirectories` | `static List<Directory> sidecarDirectories(String projectDir)` | Every `.thumbnails/` folder under `<projectDir>/contents`. |
| `run` | `static ThumbnailSidecarMigrationReport run(String projectDir)` |  |
| `ensureGitignoreRules` | `static List<String> ensureGitignoreRules(String projectDir)` | Appends the [gitignoreRules] an existing `.gitignore` of [projectDir] lacks; returns what it appended. |

## `lib/data/services/web_loading_screen_service.dart`

### `class WebLoadingScreenReport`

What [WebLoadingScreenService.write] did.

**Constructors:**

- `const WebLoadingScreenReport({this.files = const [], this.logoFile, this.warnings = const [], this.skippedReason})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `files` | `final List<String> files` | Written files, relative to the project (or to the preview folder). |
| `logoFile` | `final String? logoFile` | The logo's file name next to `index.html`, or null (no logo). |
| `warnings` | `final List<String> warnings` | Why the logo could not be used, and similar non-fatal notes. |
| `skippedReason` | `final String? skippedReason` | Set when nothing was written (the project has no `web/` platform folder). |
| `written` | `bool get written` |  |

### `abstract final class WebLoadingScreenService`

Generates a web build's loading screen from the project's [ProjectWebLoadingStyle]: `web/index.html`, `web/loading.css`, `web/loading.js`, `web/flutter_bootstrap.js` and the logo.

The page is plain HTML/CSS/JS with nothing from another origin (no fonts, no CDN): it shows from the first byte, before any Flutter code arrives. - `loading.js` wraps `window.fetch` to count the bytes of the engine's wasm and of flutter_filament's module as they stream in, and wraps `_flutter.loader.load` (called from the generated `flutter_bootstrap.js` template, which Flutter fills in at build time) to follow the engine's start; - it exposes `window.luminaLoading.progress(fraction, label)`, which the generated `main()` calls through [LuminaWebLoading] for the renderer and the asset preload; - it fades the screen out on Flutter's `flutter-first-frame` event.

Packaging (Package Project, Cook & Package) writes these files into the project's `web/` before `flutter build web`; `index.html` is regenerated every time, so edits go in Project Settings, not in the file.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `generatedNotice` | `static const String generatedNotice` |  |
| `logoBaseName` | `static const String logoBaseName` |  |
| `write` | `static WebLoadingScreenReport write({required String projectDir, required LuminaProject project, Uint8List? ic...` | Writes the loading screen into `<projectDir>/web` (or [outDir]). |
| `indexHtml` | `static String indexHtml(ResolvedWebLoadingStyle style, {required String? logoFile, bool preview = false, Strin...` | The page: the loading screen's markup over the Flutter app. |
| `loadingCss` | `static String loadingCss(ResolvedWebLoadingStyle style)` |  |
| `loadingJs` | `static String loadingJs(ResolvedWebLoadingStyle style, {bool preview = false})` | The loading screen's script. [LuminaWebLoading.rendererStart] and [LuminaWebLoading.rendererEnd] are the phase boundaries the generated `main()` reports against. |
| `flutterBootstrapJs` | `static String flutterBootstrapJs()` | The `web/flutter_bootstrap.js` template: Flutter substitutes its loader and build config at build time; the loading screen is attached to the loader before it starts. |

---

[Previous: Data layer: use cases and services (continued, part 2)](data-services-continued-2.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: models and repositories](data-models.md)
