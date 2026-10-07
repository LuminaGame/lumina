[Türkçe](../../tr/lumina_editor_data/repositories.md)

# Data layer: models and repositories

The editor-facing data layer, part two: the repositories that need the engine or native libraries (assets with thumbnails and imports, collections, projects). The persisted models themselves (`.lmas` assets, the `.lmproject` manifest and its settings, level documents, plugin descriptors, landscape and sequencer data, recent projects) and the level and plugin repositories are pure Dart and live in `lumina_core`: see [File formats and repositories](../lumina_core/formats.md). File paths are relative to the `lumina_editor_data/` package directory.

**On this page:**

- [`lib/src/repositories/asset_repository.dart`](#libsrcrepositoriesasset_repositorydart)
- [`lib/src/repositories/collections_repository.dart`](#libsrcrepositoriescollections_repositorydart)
- [`lib/src/repositories/project_repository.dart`](#libsrcrepositoriesproject_repositorydart)

## `lib/src/repositories/asset_repository.dart`

### `class RealAssetInfo`

`RealAssetInfo`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fileName` | `String fileName` | Holds the `fileName` property or configuration state. |
| `relativePath` | `String relativePath` | Holds the `relativePath` property or configuration state. |
| `type` | `AssetType type` | Holds the `type` property or configuration state. |
| `bytes` | `int bytes` | Holds the `bytes` property or configuration state. |
| `thumbnailBytes` | `Uint8List? thumbnailBytes` | Holds the `thumbnailBytes` property or configuration state. |
| `lmasPath` | `String? lmasPath` | Holds the `lmasPath` property or configuration state. |
| `assetId` | `String? assetId` | Holds the `assetId` property or configuration state. |
| `references` | `List<AssetReference> references` | Holds the `references` property or configuration state. |
| `lastModified` | `DateTime? lastModified` | Holds the `lastModified` property or configuration state. |
| `formattedSize` | `String get formattedSize` | Getter accessor returning the current value of `formattedSize`. |

### `class AssetRepository`

`AssetRepository`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `renameAsset` | `void renameAsset(String projectPath, String lmasPath, String newName, As...` | Executes `renameAsset` operation. |
| `moveAsset` | `void moveAsset(String projectPath, String lmasPath, String targetFolder,...` | Executes `moveAsset` operation. |
| `duplicateAsset` | `void duplicateAsset(String lmasPath)` | Executes `duplicateAsset` operation. |
| `sizeInfo` | `Map<String, int> sizeInfo(String projectPath, String lmasPath, AssetRefe...` | Executes `sizeInfo` operation. |
| `loadMeshFromDisk` | `static Future<GlbMeshData?> loadMeshFromDisk(String targetPath)` | Centralized Universal 3D Mesh Loader: Reads any .lmas asset container, companion .entity.glb file, direct .glb/.gltf, or .obj file and returns a fully parsed [GlbMeshData] with geometry, bounds, subPrimitives, and material slots. |
| `scanProjectContents` | `List<RealAssetInfo> scanProjectContents(String projectPath)` | Executes `scanProjectContents` operation. |
| `scanContentFolders` | `List<String> scanContentFolders(String projectPath)` | Executes `scanContentFolders` operation. |

### `class _ThumbTri`

`_ThumbTri`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_ThumbTri(this.p0, this.p1, this.p2, this.depth, this.shade, this.i0, this.i1, this.i2)`: Initializes `_ThumbTri(this.p0, this.p1, this.p2, this.depth, this.shade, this.i0, this.i1, this.i2)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `depth` | `double depth` | Holds the `depth` property or configuration state. |
| `shade` | `double shade` | Holds the `shade` property or configuration state. |
| `i0` | `int i0` | Holds the `i0` property or configuration state. |
| `i1` | `int i1` | Holds the `i1` property or configuration state. |
| `i2` | `int i2` | Holds the `i2` property or configuration state. |

## `lib/src/repositories/collections_repository.dart`

### `class CollectionAsset`

`CollectionAsset`: `class` representing the data model or functionality of the module.

**Constructors:**
- `CollectionAsset.fromJson(Map<String, dynamic> json)`: Initializes `CollectionAsset.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetId` | `String assetId` | Holds the `assetId` property or configuration state. |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class Collection`

`Collection`: `class` representing the data model or functionality of the module.

**Constructors:**
- `Collection.fromJson(Map<String, dynamic> json)`: Initializes `Collection.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `assets` | `List<CollectionAsset> assets` | Holds the `assets` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class CollectionsRepository`

`CollectionsRepository`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `loadCollections` | `List<Collection> loadCollections(String projectPath)` | Loads data from disk or memory buffer into the engine. |
| `saveCollections` | `void saveCollections(String projectPath, List<Collection> collections)` | Serializes and writes the current state or asset to disk. |
| `healPaths` | `void healPaths(String projectPath, List<RealAssetInfo> currentAssets)` | Executes `healPaths` operation. |

## `lib/src/repositories/project_repository.dart`

### `enum ProjectCreationStep`

`ProjectCreationStep`: Enumeration listing system options and state constants.

### `class ProjectCreationProgress`

`ProjectCreationProgress`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectCreationProgress(this.step, this.progress, this.message)`: Initializes `ProjectCreationProgress(this.step, this.progress, this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `step` | `ProjectCreationStep step` | Holds the `step` property or configuration state. |
| `progress` | `double progress` | Holds the `progress` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |

### `class ProjectCreationException`

`ProjectCreationException`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectCreationException(this.step, this.message)`: Initializes `ProjectCreationException(this.step, this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `step` | `ProjectCreationStep step` | Holds the `step` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class ProjectRepository`

`ProjectRepository`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `configDir` | `Directory? configDir` | Holds the `configDir` property or configuration state. |
| `processRunner` | `ProcessRunner processRunner` | Holds the `processRunner` property or configuration state. |
| `resolvedConfigDir` | `Directory get resolvedConfigDir` | Getter accessor returning the current value of `resolvedConfigDir`. |
| `getRecentProjects` | `Future<List<RecentProjectEntry>> getRecentProjects()` | Queries and returns the `RecentProjects` value or child object. |
| `getRecentProjectsFlat` | `Future<List<LuminaProject>> getRecentProjectsFlat()` | Queries and returns the `RecentProjectsFlat` value or child object. |
| `removeRecentProject` | `Future<void> removeRecentProject(String projectDir)` | Releases and safely disposes the specified `RecentProject` resource. |
| `validateProject` | `Future<bool> validateProject(String projectDir)` | Executes `validateProject` operation. |
| `deleteProjectFromDisk` | `Future<void> deleteProjectFromDisk(String projectDir)` | Releases and safely disposes the specified `ProjectFromDisk` resource. |
| `validateProjectName` | `static String? validateProjectName(String? name)` | Validates a candidate project name against Dart package naming rules. |
| `validateLocation` | `static String? validateLocation(String? location)` | Validates the target project parent directory. |
| `luminaPackagePath` | `static String get luminaPackagePath` | Resolves the engine package path for pubspec dependency injection. |
| `loadProject` | `Future<LuminaProject?> loadProject(String lmprojectPath)` | Loads data from disk or memory buffer into the engine. |
| `updateEngineVersion` | `Future<String?> updateEngineVersion(String projectDir, String version) async` | Sets the `engine_version` of the `.lmproject` in [projectDir] to [version], leaving every other field as it is. Returns the previous value when it changed; null when it already was [version] or the folder holds no readable manifest. |
| `saveProject` | `Future<void> saveProject(LuminaProject project, String projectDirPath)` | Serializes and writes the current state or asset to disk. |

---

[Previous: Data layer: use cases and services (continued, part 3)](services-continued-3.md) | [Up: lumina_editor_data (editor data layer)](index.md) | [Next: Data layer: models and repositories (continued)](repositories-continued.md)
