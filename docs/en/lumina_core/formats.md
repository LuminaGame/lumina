[Türkçe](../../tr/lumina_core/formats.md)

# File formats and repositories

Lumina's file formats as Dart models (`.lmas` assets and their summaries, the `.lmproject` manifest and its settings, level documents, landscape and sequencer data, `.lmplugin` descriptors, theme documents, recent projects) and the repositories that read and write levels and plugins. File paths are relative to the `lumina_core/` package directory.

**On this page:**

- [`lib/src/formats/landscape_data.dart`](#libsrcformatslandscape_datadart)
- [`lib/src/formats/lumina_asset.dart`](#libsrcformatslumina_assetdart)
- [`lib/src/formats/lumina_asset_summary.dart`](#libsrcformatslumina_asset_summarydart)
- [`lib/src/formats/lumina_level_document.dart`](#libsrcformatslumina_level_documentdart)
- [`lib/src/formats/lumina_plugin_descriptor.dart`](#libsrcformatslumina_plugin_descriptordart)
- [`lib/src/formats/lumina_project.dart`](#libsrcformatslumina_projectdart)
- [`lib/src/formats/lumina_theme_document.dart`](#libsrcformatslumina_theme_documentdart)
- [`lib/src/formats/plugin_isolation.dart`](#libsrcformatsplugin_isolationdart)
- [`lib/src/formats/project_web_loading_style.dart`](#libsrcformatsproject_web_loading_styledart)
- [`lib/src/formats/recent_project_entry.dart`](#libsrcformatsrecent_project_entrydart)
- [`lib/src/formats/sequencer_data.dart`](#libsrcformatssequencer_datadart)
- [`lib/src/repositories/level_repository.dart`](#libsrcrepositorieslevel_repositorydart)
- [`lib/src/repositories/plugin_repository.dart`](#libsrcrepositoriesplugin_repositorydart)

## `lib/src/formats/landscape_data.dart`

### `class FoliageRules`

Placement rules of one foliage layer.  [density] is instances per 100 m² of painted area, [minSpacing] the rejection radius (metres) between instances of the same layer, and the slope range is measured in degrees off the terrain's up vector — all of them are evaluated against the real heightmap when scattering.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `density` | `double density` | Holds the `density` property or configuration state. |
| `minSpacing` | `double minSpacing` | Holds the `minSpacing` property or configuration state. |
| `scaleMin` | `double scaleMin` | Holds the `scaleMin` property or configuration state. |
| `scaleMax` | `double scaleMax` | Holds the `scaleMax` property or configuration state. |
| `randomYaw` | `bool randomYaw` | Holds the `randomYaw` property or configuration state. |
| `alignToNormal` | `bool alignToNormal` | Holds the `alignToNormal` property or configuration state. |
| `slopeMinDegrees` | `double slopeMinDegrees` | Holds the `slopeMinDegrees` property or configuration state. |
| `slopeMaxDegrees` | `double slopeMaxDegrees` | Holds the `slopeMaxDegrees` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

### `class FoliageInstance`

One placed foliage instance: world position (metres, terrain space), a non-uniform scale, the yaw applied around the alignment axis and the surface normal it was aligned to.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `double x` | Holds the `x` property or configuration state. |
| `y` | `double y` | Holds the `y` property or configuration state. |
| `z` | `double z` | Holds the `z` property or configuration state. |
| `scaleX` | `double scaleX` | Holds the `scaleX` property or configuration state. |
| `scaleY` | `double scaleY` | Holds the `scaleY` property or configuration state. |
| `scaleZ` | `double scaleZ` | Holds the `scaleZ` property or configuration state. |
| `yaw` | `double yaw` | Holds the `yaw` property or configuration state. |
| `nx` | `double nx` | Holds the `nx` property or configuration state. |
| `ny` | `double ny` | Holds the `ny` property or configuration state. |
| `nz` | `double nz` | Holds the `nz` property or configuration state. |

### `class FoliageLayer`

A foliage layer: one mesh asset, its placement rules and the packed transforms of every instance painted with it.  The transforms are a flat `Float32List` of [floatsPerInstance] floats per instance (pos3, scale3, yaw, normal3) — the mirror of the GPU instance batch, kept consistent through the same swap-remove that `LuminaInstancedStaticMeshComponent.removeInstance` performs.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `meshAssetId` | `String meshAssetId` | Holds the `meshAssetId` property or configuration state. |
| `meshAssetPath` | `String meshAssetPath` | Holds the `meshAssetPath` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `rules` | `FoliageRules rules` | Holds the `rules` property or configuration state. |
| `instanceCount` | `int get instanceCount` | Getter accessor returning the current value of `instanceCount`. |
| `transforms` | `Float32List get transforms` | The live transform floats (a view, length `instanceCount * 10`). |
| `addInstance` | `void addInstance(FoliageInstance i)` | Appends a new item to the collection or scene. |
| `instanceAt` | `FoliageInstance instanceAt(int index)` | Executes `instanceAt` operation. |
| `removeAt` | `int removeAt(int index)` | Swap-removes [index]; returns the index the last instance moved from (`-1` when the removed instance was the last one) so callers can keep a parallel array in step with the GPU batch. |
| `clearInstances` | `void clearInstances()` | Clears all elements from the collection or buffer. |

### `class LandscapeData`

A square heightmap terrain plus its foliage layers — the single source of truth of the Landscape editor and of the runtime terrain component.  Heights are metres in `[0, maxHeight]` on a [gridResolution]² vertex grid covering a [worldSize]×[worldSize] metre square centred on the origin; the mesh sections and instance batches are derived from it and always regenerable.  ## Storage  Heights are held as **normalized `uint16`** scaled by [maxHeight] — two bytes per sample, with a quantisation step of `maxHeight / 65535` (exactly the precision a 16-bit PNG import carries anyway). That is what makes the 8129² ceiling reachable: 66 080 641 samples cost ~132 MB instead of the ~264 MB the old `Float32List` needed. Payload **v2** writes those samples directly; **v1** float payloads are still read and quantised on the way in.  There is no `heights` array to index: reads and writes go through [heightAt]/[setHeight] (or the linear [heightAtIndex]/[setHeightAtIndex]), and [heightsSnapshot] materialises a full `Float32List` only when a caller explicitly asks for one. Nothing in the sculpt or mesh path may do that at scale — at 8129² a single snapshot is 264 MB.

**Constructors:**
- `LandscapeData.fromBytes(Uint8List bytes)`: Initializes `LandscapeData.fromBytes(Uint8List bytes)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `version` | `int version` | Holds the `version` property or configuration state. |
| `gridResolution` | `int gridResolution` | Holds the `gridResolution` property or configuration state. |
| `worldSize` | `double worldSize` | Holds the `worldSize` property or configuration state. |
| `maxHeight` | `double maxHeight` | Holds the `maxHeight` property or configuration state. |
| `layers` | `List<FoliageLayer> layers` | Holds the `layers` property or configuration state. |
| `samples` | `Uint16List samples` | Normalized heights: `sample * maxHeight / 65535` metres. |
| `samplesAreExternal` | `bool samplesAreExternal` | True when this payload was decoded from a header whose samples live in a sidecar file that has not been attached yet. |
| `isValidResolution` | `static bool isValidResolution(int resolution)` | A resolution the section map tiles exactly: `n * 64 + 1`, from 65 to [maxGridResolution]. |
| `validResolutions` | `static List<int> get validResolutions` | Every resolution the importer accepts, ascending. |
| `describeInvalidResolution` | `static String? describeInvalidResolution(int resolution)` | Why [resolution] cannot be imported, or null when it can. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `heightBytes` | `int get heightBytes` | Bytes the heights occupy in memory. |
| `cellSize` | `double get cellSize` | Metres between two neighbouring height samples. |
| `heightStep` | `double get heightStep` | The smallest height difference this payload can represent. |
| `heightMin` | `double get heightMin` | Lowest height in the terrain, as of the last [recomputeHeightRange]. |
| `heightMax` | `double get heightMax` | Highest height in the terrain, as of the last [recomputeHeightRange]. |
| `recomputeHeightRange` | `void recomputeHeightRange()` | Rescans every sample to refresh [heightMin]/[heightMax].  O(vertexCount) — call it when a terrain is created, imported or opened, never per stroke and never per vertex. [setHeight] widens the cached range as it goes, so the range is only ever too generous, never wrong in a way that clips the colour ramp. |
| `heightAt` | `double heightAt(int col, int row)` | Executes `heightAt` operation. |
| `heightAtIndex` | `double heightAtIndex(int index)` | Height of the [index]-th sample in row-major order. |
| `setHeight` | `void setHeight(int col, int row, double value)` | Updates the `Height` parameter and applies changes to the system. |
| `setHeightAtIndex` | `void setHeightAtIndex(int index, double value)` | Updates the `HeightAtIndex` parameter and applies changes to the system. |
| `heightsSnapshot` | `Float32List heightsSnapshot()` | A full `Float32List` of every height, materialised on demand.  Two bytes per sample become four: at 8129² this is a 264 MB allocation. Nothing in the sculpt, mesh or save path calls it — it exists for tests and for exporting a v1 payload. |
| `worldXOf` | `double worldXOf(int col)` | World X (metres) of column [col]; the grid is centred on the origin. |
| `worldZOf` | `double worldZOf(int row)` | Executes `worldZOf` operation. |
| `columnOf` | `double columnOf(double worldX)` | Executes `columnOf` operation. |
| `rowOf` | `double rowOf(double worldZ)` | Executes `rowOf` operation. |
| `sampleHeight` | `double sampleHeight(double worldX, double worldZ)` | Bilinear height sample at a world position (metres). |
| `sampleNormal` | `Vector3 sampleNormal(double worldX, double worldZ)` | Unit surface normal (Y-up) from central differences of the heightmap. |
| `sampleSlopeDegrees` | `double sampleSlopeDegrees(double worldX, double worldZ)` | Slope in degrees off vertical at a world position. |
| `contains` | `bool contains(double worldX, double worldZ)` | True when [worldX]/[worldZ] lie inside the terrain footprint. |
| `copyWithHeights` | `LandscapeData copyWithHeights(Float32List newHeights)` | Executes `copyWithHeights` operation. |
| `sidecarPathFor` | `static String sidecarPathFor(String assetPath)` | The heights file that belongs to the `.lmas` at [assetPath]. |
| `writeSidecar` | `Future<void> writeSidecar(File file)` | Streams the samples into [file] in 4 Mi-sample chunks.  Nothing here materialises a second copy of the heightmap: at 8129² one monolithic byte list would be another 132 MB on top of the samples. |
| `readSidecar` | `void readSidecar(File file)` | Reads a sidecar written by [writeSidecar] into this payload's samples.  Throws when the sidecar does not describe this terrain, rather than filling the grid with whatever bytes were there. |

## `lib/src/formats/lumina_asset.dart`

### `enum AssetType`

`AssetType`: Enumeration listing system options and state constants.

### `class AssetReference`

`AssetReference`: `class` representing the data model or functionality of the module.

**Constructors:**
- `AssetReference.fromMap(Map<String, dynamic> map)`: Initializes `AssetReference.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `slotName` | `String slotName` | Holds the `slotName` property or configuration state. |
| `assetId` | `String assetId` | Holds the `assetId` property or configuration state. |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class LuminaAsset`

`LuminaAsset`: `class` representing the data model or functionality of the module.

**Constructors:**
- `LuminaAsset.fromMap(Map<String, dynamic> map)`: Initializes `LuminaAsset.fromMap(Map<String, dynamic> map)`.
- `LuminaAsset.fromBytes(Uint8List bytes)`: Deserializes asset from binary Protobuf bytes or JSON fallback payload.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetId` | `String assetId` | Holds the `assetId` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `type` | `AssetType type` | Holds the `type` property or configuration state. |
| `hasThumbnail` | `bool hasThumbnail` | Holds the `hasThumbnail` property or configuration state. |
| `thumbnailPng` | `Uint8List? thumbnailPng` | Holds the `thumbnailPng` property or configuration state. |
| `rawPayload` | `Uint8List? rawPayload` | Holds the `rawPayload` property or configuration state. |
| `rawMatSource` | `String rawMatSource` | Holds the `rawMatSource` property or configuration state. |
| `references` | `List<AssetReference> references` | Holds the `references` property or configuration state. |
| `metadata` | `Map<String, String> metadata` | Holds the `metadata` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |
| `toProtoBufferBytes` | `Uint8List toProtoBufferBytes()` | Serializes asset to binary Protobuf bytes format with LMAS magic header. |

## `lib/src/formats/lumina_asset_summary.dart`

### `class LmasByteRange`

Where a base64 string value (`thumbnail_png`, `raw_payload`) sits inside a `.lmas` file: the byte offset of its first character (after the opening quote) and its length in bytes. A null [length] means the string was not scanned to its end (the summary stopped once it had what it needed).

**Constructors:**

- `const LmasByteRange(this.offset, [this.length])`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `offset` | `final int offset` |  |
| `length` | `final int? length` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `fromJson` | `static LmasByteRange? fromJson(Object? json)` |  |

### `class LuminaAssetSummary`

What a `.lmas` is without its payload: id, name, type, metadata, references, whether it carries a thumbnail and where it and the payload sit in the file. [LuminaAsset.readSummary] reads it without base64-decoding `thumbnail_png` / `raw_payload`; the project's asset index ([LuminaAssetIndex]) stores one per file.

For an actor asset whose payload is a small Blueprint document, the summary also knows the document's [blueprintKind] (`class`, `enum`, `interface`, `save_game`, `montage`, …), its [parentClass] and whether it has an event graph — what the class catalogs need without the payload.

**Constructors:**

- `const LuminaAssetSummary({required this.assetId, required this.name, required this.type, this.hasThumbnail = false, this.metadata = const {}, this.references =...`
- `factory LuminaAssetSummary.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetId` | `final String assetId` |  |
| `name` | `final String name` |  |
| `type` | `final AssetType type` |  |
| `hasThumbnail` | `final bool hasThumbnail` |  |
| `metadata` | `final Map<String, String> metadata` |  |
| `references` | `final List<AssetReference> references` |  |
| `blueprintKind` | `final String? blueprintKind` | The Blueprint document kind of an actor payload (`class` when the document names none), else null. |
| `documentParentClass` | `final String? documentParentClass` | The Blueprint document's own `parentClass` (null when it names none). |
| `parentClass` | `String? get parentClass` | The Blueprint document's `parentClass`, else `metadata['parent_class']`. |
| `hasEventGraph` | `final bool hasEventGraph` | Whether the Blueprint document has an `eventGraph`. |
| `thumbnailRange` | `final LmasByteRange? thumbnailRange` | `thumbnail_png` in the file (null when absent or empty). |
| `payloadRange` | `final LmasByteRange? payloadRange` | `raw_payload` in the file (null when absent). |
| `companionModified` | `final Map<String, int> companionModified` | Companion file name (`SM_Rock.entity.glb`, `T_Rock.png`) → its modification time in ms since epoch. Filled by the asset index. |
| `omittedMetadata` | `final Set<String> omittedMetadata` | Metadata keys whose (large) values were left out of [metadata] when the summary was stored in the index; read the file for them. |
| `hasThumbnailBytes` | `bool get hasThumbnailBytes` | Whether the file embeds thumbnail bytes. |
| `thumbnailSource` | `String? get thumbnailSource` | `metadata.thumbnail_source` (`filament`, `image`, `badge`). |
| `newestCompanionModified` | `int? get newestCompanionModified` | The newest companion modification time (ms), or null without companions. |
| `copyWith` | `LuminaAssetSummary copyWith({Map<String, int>? companionModified, Map<String, String>? metadata, Set<String>?...` |  |
| `maxStoredMetadataValue` | `static const int maxStoredMetadataValue` | Metadata values longer than this are left out of the stored summary (a big level's `actors` list), listed in [omittedMetadata]. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `assetTypeNamed` | `static AssetType assetTypeNamed(String? name)` | The [AssetType] named [name] (`unknown` for anything else), as [LuminaAsset.fromMap] resolves it. |
| `maxInspectedPayload` | `static const int maxInspectedPayload` | Payloads at most this long (base64 bytes) are decoded to learn an actor Blueprint document's kind and parent class. |
| `read` | `static LuminaAssetSummary read(File file)` | Reads [file]'s summary: tokenises the JSON object, decoding the small fields and only locating the base64 strings. Legacy files with the base64 fields first are scanned past them (no decode); a file this reader cannot follow is decoded fully. |
| `fromBytes` | `static LuminaAssetSummary fromBytes(Uint8List bytes)` | Reads [bytes] (a whole `.lmas`) the same way, for in-memory callers. |
| `readRange` | `static Uint8List? readRange(File file, LmasByteRange range)` | Reads the base64 string at [range] of [file] and decodes it. Null when the range is empty or unreadable. |

## `lib/src/formats/lumina_level_document.dart`

### `class LuminaLevelDocument`

A level `.lmas` as Lumina Studio writes it (a JSON container): `assetId`, `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and `metadata` — the placed actors (`metadata.actors`), the level's sections (environment, navigation, world partition) and, its Level Blueprint (`metadata.levelBlueprint`). Unknown keys are kept.

**Constructors:**

- `LuminaLevelDocument({required this.relativePath, Map<String, dynamic>? container})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` | Project-relative path (`contents/levels/L_Test.lmas`). |
| `container` | `final Map<String, dynamic> container` | The whole container, as read (and as [toJson] writes it back). |
| `tryParse` | `static LuminaLevelDocument? tryParse(String json, {required String relativePath})` | Reads a level container's JSON; null when it is not one. |
| `name` | `String get name` | The level's name (`L_Test`). |
| `metadata` | `Map<String, dynamic> get metadata` | `metadata`, created when missing. |
| `actors` | `List<Map<String, dynamic>> get actors` | The placed actors (`metadata.actors`), as maps. |
| `actors` | `set actors(List<Map<String, dynamic>> value)` |  |
| `levelBlueprintKey` | `static const String levelBlueprintKey` | The `metadata` key a level stores its Level Blueprint under (`'levelBlueprint'`). |
| `levelBlueprintJson` | `Map<String, dynamic>? get levelBlueprintJson` | The stored Level Blueprint as JSON, or null when the level has none. The engine reads it into its `LuminaLevelBlueprintDocument` through the `levelBlueprint` extension getter (`package:lumina`, `lib/src/blueprint/level_blueprint_storage.dart`), which also adds `levelActorRefs`. |
| `levelBlueprintJson` | `set levelBlueprintJson(Map<String, dynamic>? value)` | Stores [value] under `metadata.levelBlueprint`; null removes the key, so a level without a script stays as it was. |
| `hasLevelBlueprint` | `bool get hasLevelBlueprint` | Whether the level carries a Blueprint. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `encode` | `String encode()` |  |

## `lib/src/formats/lumina_plugin_descriptor.dart`

### `enum PluginOrigin`

`PluginOrigin`: Enumeration listing system options and state constants.

### `enum PluginModuleType`

`PluginModuleType`: Enumeration listing system options and state constants.

### `class PluginModuleDescriptor`

`PluginModuleDescriptor`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PluginModuleDescriptor.fromJson(Map<String, dynamic> json)`: Initializes `PluginModuleDescriptor.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `type` | `PluginModuleType type` | Holds the `type` property or configuration state. |
| `entryLibrary` | `String entryLibrary` | Holds the `entryLibrary` property or configuration state. |
| `registrationClass` | `String registrationClass` | Holds the `registrationClass` property or configuration state. |
| `processClass` | `final String? processClass` | The `LuminaPluginProcess` subclass in `entryLibrary` that runs in the plugin's own process (`.lmplugin` `"process_class"`). Required on an editor module of a plugin with `"isolation": "process"`. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class PluginDependencyRef`

`PluginDependencyRef`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PluginDependencyRef.fromJson(Map<String, dynamic> json)`: Initializes `PluginDependencyRef.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `version` | `VersionConstraint version` | Holds the `version` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class LuminaPluginDescriptor`

`LuminaPluginDescriptor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `friendlyName` | `String? friendlyName` | Holds the `friendlyName` property or configuration state. |
| `version` | `Version version` | Holds the `version` property or configuration state. |
| `description` | `String? description` | Holds the `description` property or configuration state. |
| `category` | `String category` | Holds the `category` property or configuration state. |
| `authors` | `List<String> authors` | Holds the `authors` property or configuration state. |
| `engineVersion` | `VersionConstraint? engineVersion` | Holds the `engineVersion` property or configuration state. |
| `dependencies` | `List<PluginDependencyRef> dependencies` | Holds the `dependencies` property or configuration state. |
| `modules` | `List<PluginModuleDescriptor> modules` | Holds the `modules` property or configuration state. |
| `enabledByDefault` | `bool enabledByDefault` | Holds the `enabledByDefault` property or configuration state. |
| `canContainContent` | `bool canContainContent` | Holds the `canContainContent` property or configuration state. |
| `isolation` | `final PluginIsolation isolation` | Where the editor module runs (`.lmplugin` `"isolation"`, default `in_process`); written by `toJson` only when `process`. |
| `processModule` | `PluginModuleDescriptor? get processModule` | The editor module that names a `process_class`, or null. |
| `processClass` | `String? get processClass` | `processModule`'s `process_class`. |
| `effectiveIsolation` | `PluginIsolation effectiveIsolation([LuminaProject? project])` | Where the plugin runs in `project`: an isolated plugin (`process` with a `process_class`) runs in its own process unless the project's `plugin_isolation` forces it `in_process`; any other plugin runs in process. |
| `extras` | `Map<String, dynamic> extras` | Holds the `extras` property or configuration state. |
| `pluginDir` | `Directory pluginDir` | Holds the `pluginDir` property or configuration state. |
| `origin` | `PluginOrigin origin` | Holds the `origin` property or configuration state. |
| `isContentOnly` | `bool get isContentOnly` | Checks current state or capability and returns a boolean value. |
| `iconFile` | `File? get iconFile` | Getter accessor returning the current value of `iconFile`. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

## `lib/src/formats/lumina_project.dart`

The input settings and maps and modes (`ProjectInputValueType`, `ProjectInputAction`, `ProjectInputMapping`, `ProjectMappingContext`, `ProjectInputSettings`, `ProjectMapsAndModes`) live in `project_input_settings.dart`, the packaging settings (`kPackagingPlatforms`, `packagingPlatformLabel`, `ProjectPackagingSettings`, …) in `project_packaging_settings.dart`; `lumina_project.dart` exports both, so importers see no change.

### `class ScalabilityCategory`

`ScalabilityCategory`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ScalabilityCategory.fromMap(Map<String, dynamic> map)`: Initializes `ScalabilityCategory.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewDistance` | `String viewDistance` | Holds the `viewDistance` property or configuration state. |
| `shadowQuality` | `String shadowQuality` | Holds the `shadowQuality` property or configuration state. |
| `antiAliasing` | `String antiAliasing` | Holds the `antiAliasing` property or configuration state. |
| `postProcessing` | `String postProcessing` | Holds the `postProcessing` property or configuration state. |
| `textureQuality` | `String textureQuality` | Holds the `textureQuality` property or configuration state. |
| `shadingQuality` | `String shadingQuality` | Holds the `shadingQuality` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `extension ScalabilityPresets`

`ScalabilityPresets`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `forPreset` | `static ScalabilityCategory forPreset(String preset)` | Executes `forPreset` operation. |

### `enum ProjectInputValueType`

Value type of an input action, as defined by the runtime input system (actions and mapping contexts).

### `class ProjectInputAction`

`ProjectInputAction`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectInputAction.fromMap(Map<String, dynamic> map)`: Initializes `ProjectInputAction.fromMap(Map<String, dynamic> map)`.
- `ProjectInputAction(name: name ?? this.name, valueType: valueType ?? this.valueType)`: Initializes `ProjectInputAction(name: name ?? this.name, valueType: valueType ?? this.valueType)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `valueType` | `ProjectInputValueType valueType` | Holds the `valueType` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectInputMapping`

One key binding inside a mapping context. [keyId] is the stable `LogicalKeyboardKey.keyId` and [keyLabel] its debug/display name; the runtime input task maps `keyId` back to its own key abstraction.

**Constructors:**
- `ProjectInputMapping.fromMap(Map<String, dynamic> map)`: Initializes `ProjectInputMapping.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `action` | `String action` | Holds the `action` property or configuration state. |
| `keyId` | `int keyId` | Holds the `keyId` property or configuration state. |
| `keyLabel` | `String keyLabel` | Holds the `keyLabel` property or configuration state. |
| `scale` | `double scale` | Holds the `scale` property or configuration state. |
| `axis` | `String axis` | `X`, `Y` (axis component the key drives) or empty for digital actions. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectMappingContext`

`ProjectMappingContext`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectMappingContext.fromMap(Map<String, dynamic> map)`: Initializes `ProjectMappingContext.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `priority` | `int priority` | Holds the `priority` property or configuration state. |
| `mappings` | `List<ProjectInputMapping> mappings` | Holds the `mappings` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectInputSettings`

`ProjectInputSettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectInputSettings.fromMap(Map<String, dynamic> map)`: Initializes `ProjectInputSettings.fromMap(Map<String, dynamic> map)`.
- `ProjectInputSettings(actions: actions ?? this.actions, mappingContexts: mappingContexts ?? this.mappingContexts)`: Initializes `ProjectInputSettings(actions: actions ?? this.actions, mappingContexts: mappingContexts ?? this.mappingContexts)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actions` | `List<ProjectInputAction> actions` | Holds the `actions` property or configuration state. |
| `mappingContexts` | `List<ProjectMappingContext> mappingContexts` | Holds the `mappingContexts` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectMapsAndModes`

`ProjectMapsAndModes`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectMapsAndModes.fromMap(Map<String, dynamic> map)`: Initializes `ProjectMapsAndModes.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editorStartupMap` | `String editorStartupMap` | `contents/`-relative path of the level the editor opens on startup. |
| `gameDefaultMap` | `String gameDefaultMap` | `contents/`-relative path of the level the shipped game starts in. |
| `defaultGameMode` | `String defaultGameMode` | Dart class name of the game mode (built-in `LuminaGameMode` or a generated actor class). |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectPhysicsSettings`

`ProjectPhysicsSettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectPhysicsSettings.fromMap(Map<String, dynamic> map)`: Initializes `ProjectPhysicsSettings.fromMap(Map<String, dynamic> map)`.
- `ProjectPhysicsSettings(gravityZ: gravityZ ?? this.gravityZ, fixedTimestep: fixedTimestep ?? this.fixedTimestep)`: Initializes `ProjectPhysicsSettings(gravityZ: gravityZ ?? this.gravityZ, fixedTimestep: fixedTimestep ?? this.fixedTimestep)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `gravityZ` | `double gravityZ` | World gravity along Z in cm/s² (default -980). |
| `fixedTimestep` | `double fixedTimestep` | Holds the `fixedTimestep` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class ProjectPackagingSettings`

`ProjectPackagingSettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ProjectPackagingSettings.fromMap(Map<String, dynamic> map)`: Initializes `ProjectPackagingSettings.fromMap(Map<String, dynamic> map)`.
- `ProjectPackagingSettings(targetOs: targetOs ?? this.targetOs, outputDir: outputDir ?? this.outputDir)`: Initializes `ProjectPackagingSettings(targetOs: targetOs ?? this.targetOs, outputDir: outputDir ?? this.outputDir)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `targetOs` | `String targetOs` | Holds the `targetOs` property or configuration state. |
| `outputDir` | `String outputDir` | Holds the `outputDir` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class EditorSnapSettings`

`EditorSnapSettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EditorSnapSettings.fromMap(Map<String, dynamic> map)`: Initializes `EditorSnapSettings.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `translateSnapEnabled` | `bool translateSnapEnabled` | Holds the `translateSnapEnabled` property or configuration state. |
| `rotateSnapEnabled` | `bool rotateSnapEnabled` | Holds the `rotateSnapEnabled` property or configuration state. |
| `scaleSnapEnabled` | `bool scaleSnapEnabled` | Holds the `scaleSnapEnabled` property or configuration state. |
| `surfaceSnapEnabled` | `bool surfaceSnapEnabled` | Holds the `surfaceSnapEnabled` property or configuration state. |
| `gridVisible` | `bool gridVisible` | Holds the `gridVisible` property or configuration state. |
| `translateSnapStep` | `double translateSnapStep` | Holds the `translateSnapStep` property or configuration state. |
| `rotateSnapStep` | `double rotateSnapStep` | Holds the `rotateSnapStep` property or configuration state. |
| `scaleSnapStep` | `double scaleSnapStep` | Holds the `scaleSnapStep` property or configuration state. |
| `gridStep` | `double gridStep` | Holds the `gridStep` property or configuration state. |
| `gridExtent` | `double gridExtent` | Holds the `gridExtent` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class EngineScalabilitySettings`

`EngineScalabilitySettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EngineScalabilitySettings.fromMap(Map<String, dynamic> map)`: Initializes `EngineScalabilitySettings.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `targetFps` | `int targetFps` | Holds the `targetFps` property or configuration state. |
| `vsyncEnabled` | `bool vsyncEnabled` | Holds the `vsyncEnabled` property or configuration state. |
| `qualityPreset` | `String qualityPreset` | Holds the `qualityPreset` property or configuration state. |
| `scalability` | `ScalabilityCategory scalability` | Holds the `scalability` property or configuration state. |
| `autoOrganizeFiles` | `bool autoOrganizeFiles` | Holds the `autoOrganizeFiles` property or configuration state. |
| `autoSaveIntervalSeconds` | `int autoSaveIntervalSeconds` | Holds the `autoSaveIntervalSeconds` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class EditorViewportSettings`

`EditorViewportSettings`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Constructors:**
- `EditorViewportSettings.fromMap(Map<String, dynamic> map)`: Initializes `EditorViewportSettings.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cameraMode` | `String cameraMode` | Holds the `cameraMode` property or configuration state. |
| `viewMode` | `String viewMode` | Holds the `viewMode` property or configuration state. |
| `bufferVisualization` | `String bufferVisualization` | Holds the `bufferVisualization` property or configuration state. |
| `showFlags` | `Map<String, bool> showFlags` | Holds the `showFlags` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

### `class LuminaProject`

`LuminaProject`: `class` representing the data model or functionality of the module.

**Constructors:**
- `LuminaProject.fromMap(Map<String, dynamic> map)`: Initializes `LuminaProject.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectName` | `String projectName` | Holds the `projectName` property or configuration state. |
| `engineVersion` | `String engineVersion` | Holds the `engineVersion` property or configuration state. |
| `activeLevel` | `String activeLevel` | Holds the `activeLevel` property or configuration state. |
| `isDirty` | `bool isDirty` | Holds the `isDirty` property or configuration state. |
| `lastModifiedTimestamp` | `String lastModifiedTimestamp` | Holds the `lastModifiedTimestamp` property or configuration state. |
| `lastCodeGeneratedTimestamp` | `String lastCodeGeneratedTimestamp` | Holds the `lastCodeGeneratedTimestamp` property or configuration state. |
| `settings` | `EngineScalabilitySettings settings` | Holds the `settings` property or configuration state. |
| `editorSnap` | `EditorSnapSettings editorSnap` | Holds the `editorSnap` property or configuration state. |
| `editorViewport` | `EditorViewportSettings editorViewport` | Holds the `editorViewport` property or configuration state. |
| `enabledPlugins` | `List<String>? enabledPlugins` | Holds the `enabledPlugins` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `template` | `String template` | Id of the game template the project was scaffolded from (`blank_3d` | `first_person` | `third_person`, see `GameTemplateCatalog`). Manifests written before templates existed default to `blank_3d`. |
| `input` | `ProjectInputSettings input` | Holds the `input` property or configuration state. |
| `mapsAndModes` | `ProjectMapsAndModes mapsAndModes` | Holds the `mapsAndModes` property or configuration state. |
| `physics` | `ProjectPhysicsSettings physics` | Holds the `physics` property or configuration state. |
| `packaging` | `ProjectPackagingSettings packaging` | Holds the `packaging` property or configuration state. |
| `pluginIsolation` | `final Map<String, PluginIsolation> pluginIsolation` | Per-plugin isolation overrides, `.lmproject` `plugin_isolation: {"<plugin>": "in_process" \| "process"}` (written sorted by name, only when not empty; an unknown value is dropped on read). Forces an isolated plugin in process for debugging; see `LuminaPluginDescriptor.effectiveIsolation`. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

## `lib/src/formats/lumina_theme_document.dart`

### `class LuminaComponentStyle`

Component-level styling overrides for a widget type (button, card, input, badge, dialog, etc.): background and foreground colors, border radius, padding, and typography overrides.

**Constructors:**

- `const LuminaComponentStyle({this.backgroundColor, this.foregroundColor, this.borderRadius, this.borderColor, this.borderWidth, this.paddingHorizontal, this.paddingVertical, this.fontSize, this.fontWeight})`

### `class LuminaCustomStyle`

Named style variant targeting a specific component type that can be applied to game widgets.

**Constructors:**

- `const LuminaCustomStyle({required this.name, required this.targetComponent, required this.style})`

### `class LuminaThemeDocument`

Document model for UI themes serialized in `.lmas` assets with `AssetType.theme`. Stores design tokens (color palette, base border radius, typography), component-specific overrides, and custom named styles.

**Constructors:**

- `const LuminaThemeDocument({this.name, this.baseTheme, this.colors, this.radius, this.fontFamily, this.baseFontSize, this.headlineFontSize, this.componentStyles, this.customStyles})`
- `factory LuminaThemeDocument.defaultShadcnDark({String name = 'DefaultTheme'})`
- `factory LuminaThemeDocument.defaultGameTheme({String name = 'GameUITheme'})`
- `factory LuminaThemeDocument.fromAsset(LuminaAsset asset)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `colorInt` | `int colorInt(String token, {int fallback = 0xFF888888})` | The ARGB colour (`0xAARRGGBB`) of a token from the theme palette, or [fallback]. Flutter code reads it as a `Color` with the `colorOf` extension (`package:lumina`, `lib/src/umg/theme_document_colors.dart`), which also adds `bgColor` / `fgColor` / `bColor` to `LuminaComponentStyle`. |
| `hasComponentStyle` | `bool hasComponentStyle(String componentKey)` | Returns true if an explicit style override exists for the component. |
| `toAsset` | `LuminaAsset toAsset({String name})` | Serializes the theme document into a `LuminaAsset` of `AssetType.theme`. |
| `toJson` | `String toJson()` | Serializes the theme document to a JSON string. |

## `lib/src/formats/plugin_isolation.dart`

### `enum PluginIsolation`

Where a code plugin's editor module runs: `inProcess` (`in_process`, inside the editor) or `process` (its process part in its own supervised process). `manifestValue` is the string written in `.lmplugin` / `.lmproject` files; `static PluginIsolation? tryParse(Object? value)` reads one (null for anything else). Exported by `lumina_plugin_descriptor.dart` and `lumina_project.dart`.

## `lib/src/formats/project_web_loading_style.dart`

### `class ProjectWebLoadingStyle`

`packaging.web_loading_style` in the `.lmproject`: how a web build's plain HTML loading screen looks while the engine, the renderer and the game's assets download.

Empty fields fall back to the project: the background to the Icon Background, the title to the project name, the logo ([logoFromIcon]) to the project icon. [resolve] applies those fallbacks and replaces invalid values, so nothing unchecked reaches the generated CSS or HTML.

**Constructors:**

- `const ProjectWebLoadingStyle({this.background = '', this.gradient = '', this.accent = defaultAccent, this.text = defaultText, this.logo = logoFromIcon, this.tit...`
- `factory ProjectWebLoadingStyle.fromMap(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `background` | `final String background` | `#RRGGBB`; empty: the project's Icon Background. |
| `gradient` | `final String gradient` | `#RRGGBB` the background fades to (top to bottom); empty: a solid colour. |
| `accent` | `final String accent` | `#RRGGBB` of the progress bar / ring. |
| `text` | `final String text` | `#RRGGBB` of the title, subtitle and labels. |
| `logo` | `final String logo` | [logoFromIcon], a project-relative image (PNG, JPG, WebP, SVG, GIF), or [logoNone]. |
| `title` | `final String title` | Empty: the project name. |
| `subtitle` | `final String subtitle` |  |
| `progressStyle` | `final String progressStyle` | One of [progressStyles]. |
| `fadeMs` | `final int fadeMs` | How long the screen takes to fade out once the first frame is drawn. |
| `logoFromIcon` | `static const String logoFromIcon` |  |
| `logoNone` | `static const String logoNone` |  |
| `defaultAccent` | `static const String defaultAccent` |  |
| `defaultText` | `static const String defaultText` |  |
| `defaultFadeMs` | `static const int defaultFadeMs` |  |
| `maxFadeMs` | `static const int maxFadeMs` |  |
| `progressStyles` | `static const List<String> progressStyles` |  |
| `logoExtensions` | `static const List<String> logoExtensions` | Image extensions a browser shows as the logo. |
| `isHexColor` | `static bool isHexColor(String v)` |  |
| `problems` | `List<String> problems()` | Why this style cannot be generated as it is (Project Settings shows these as validation errors; [resolve] falls back instead). |
| `resolve` | `ResolvedWebLoadingStyle resolve(LuminaProject project)` | The values the generated page uses for [project]. |
| `toMap` | `Map<String, dynamic> toMap()` |  |
| `copyWith` | `ProjectWebLoadingStyle copyWith({String? background, String? gradient, String? accent, String? text, String? l...` |  |

### `class ResolvedWebLoadingStyle`

A [ProjectWebLoadingStyle] with the project fallbacks applied and every colour a valid upper-case `#RRGGBB`.

**Constructors:**

- `const ResolvedWebLoadingStyle({required this.background, required this.gradient, required this.accent, required this.text, required this.logo, required this.tit...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `background` | `final String background` |  |
| `gradient` | `final String? gradient` | Null: a solid [background]. |
| `accent` | `final String accent` |  |
| `text` | `final String text` |  |
| `logo` | `final String logo` |  |
| `title` | `final String title` |  |
| `subtitle` | `final String subtitle` |  |
| `progressStyle` | `final String progressStyle` |  |
| `fadeMs` | `final int fadeMs` |  |
| `argb` | `static int argb(String hex)` | `0xAARRGGBB` of a resolved `#RRGGBB` colour. |

## `lib/src/formats/recent_project_entry.dart`

### `class RecentProjectEntry`

Represents a tracked project entry in the launcher's recent projects list.

**Constructors:**
- `RecentProjectEntry.fromMap(Map<String, dynamic> map)`: Initializes `RecentProjectEntry.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `project` | `LuminaProject project` | Holds the `project` property or configuration state. |
| `projectDir` | `String projectDir` | Holds the `projectDir` property or configuration state. |
| `lastOpened` | `DateTime lastOpened` | Holds the `lastOpened` property or configuration state. |
| `coverImage` | `String? coverImage` | Holds the `coverImage` property or configuration state. |
| `isMissing` | `bool isMissing` | Holds the `isMissing` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

## `lib/src/formats/sequencer_data.dart`

### `enum KeyInterpolation`

`KeyInterpolation`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cubic` | `cubic` | Holds the `cubic` property or configuration state. |
| `toJson` | `String toJson()` | Serializes the object to a JSON map. |
| `fromJson` | `static KeyInterpolation fromJson(String name)` | Reconstructs the object from a serialized map/JSON. |

### `class SequencerKey`

`SequencerKey`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SequencerKey.fromJson(Map<String, dynamic> json)`: Initializes `SequencerKey.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `frame` | `int frame` | Holds the `frame` property or configuration state. |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `interpolation` | `KeyInterpolation interpolation` | Holds the `interpolation` property or configuration state. |
| `inTangent` | `double inTangent` | Holds the `inTangent` property or configuration state. |
| `outTangent` | `double outTangent` | Holds the `outTangent` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class SequencerChannel`

`SequencerChannel`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SequencerChannel.fromJson(Map<String, dynamic> json)`: Initializes `SequencerChannel.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `keys` | `List<SequencerKey> keys` | Holds the `keys` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `enum SequencerTrackKind`

`SequencerTrackKind`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `visibility` | `visibility` | Holds the `visibility` property or configuration state. |
| `toJson` | `String toJson()` | Serializes the object to a JSON map. |
| `fromJson` | `static SequencerTrackKind fromJson(String name)` | Reconstructs the object from a serialized map/JSON. |

### `class SequencerTrack`

`SequencerTrack`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SequencerTrack.fromJson(Map<String, dynamic> json)`: Initializes `SequencerTrack.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `actorId` | `String actorId` | Holds the `actorId` property or configuration state. |
| `actorName` | `String actorName` | Holds the `actorName` property or configuration state. |
| `kind` | `SequencerTrackKind kind` | Holds the `kind` property or configuration state. |
| `propertyName` | `String? propertyName` | Holds the `propertyName` property or configuration state. |
| `channels` | `List<SequencerChannel> channels` | Holds the `channels` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class SequencerData`

`SequencerData`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SequencerData.fromJson(Map<String, dynamic> json)`: Initializes `SequencerData.fromJson(Map<String, dynamic> json)`.
- `SequencerData.fromBytes(Uint8List bytes)`: Initializes `SequencerData.fromBytes(Uint8List bytes)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `version` | `int version` | Holds the `version` property or configuration state. |
| `fps` | `int fps` | Holds the `fps` property or configuration state. |
| `lengthFrames` | `int lengthFrames` | Holds the `lengthFrames` property or configuration state. |
| `tracks` | `List<SequencerTrack> tracks` | Holds the `tracks` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `toBytes` | `Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson(...` | Executes `toBytes` operation. |

## `lib/src/repositories/level_repository.dart`

### `class LuminaLevelRepository`

Reads and writes a project's level `.lmas` containers, keeping every key of the level as it is on disk. The engine adds `loadLevelBlueprint` / `saveLevelBlueprint` (`package:lumina`, `lib/src/blueprint/level_blueprint_storage.dart`).

**Constructors:**

- `const LuminaLevelRepository(this.projectDir)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` | The project directory the level paths are relative to. |
| `load` | `LuminaLevelDocument? load(String relativePath)` | The level at [relativePath] (`contents/levels/L_Test.lmas`), or null when there is no such level. |
| `save` | `void save(LuminaLevelDocument level)` | Writes [level] to its path. |

## `lib/src/repositories/plugin_repository.dart`

### `enum PluginErrorKind`

`PluginErrorKind`: Enumeration listing system options and state constants.

### `class PluginScanError`

`PluginScanError`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filePath` | `String filePath` | Holds the `filePath` property or configuration state. |
| `kind` | `PluginErrorKind kind` | Holds the `kind` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `jsonOffset` | `int? jsonOffset` | Holds the `jsonOffset` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class PluginManifestException`

`PluginManifestException`: `class` representing the data model or functionality of the module.

**Constructors:**
- `PluginManifestException(this.error)`: Initializes `PluginManifestException(this.error)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `error` | `PluginScanError error` | Holds the `error` property or configuration state. |
| `toString` | `String toString() => error.toString()` | Executes `toString` operation. |

### `class PluginScanRoot`

`PluginScanRoot`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dir` | `Directory dir` | Holds the `dir` property or configuration state. |
| `origin` | `PluginOrigin origin` | Holds the `origin` property or configuration state. |
| `packageDirs` | `List<Directory>? packageDirs` | The plugin folders themselves, for a root whose plugins do not share a parent (the packages a workspace resolved); null scans `dir`'s sub-folders. |
| `PluginScanRoot.packages` | `PluginScanRoot.packages({required Directory dir, required List<Directory> packageDirs, required PluginOrigin origin})` | A root made of the given plugin folders; `dir` is the workspace they were resolved for. The editor's built-ins are one. |
| `candidates` | `List<Directory> candidates()` | The folders scanned as plugins: the existing `packageDirs`, else `dir`'s sub-folders. |

### `class PluginScanResult`

`PluginScanResult`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `plugins` | `List<LuminaPluginDescriptor> plugins` | Holds the `plugins` property or configuration state. |
| `errors` | `List<PluginScanError> errors` | Holds the `errors` property or configuration state. Two folders of the same root naming one plugin are a `duplicateName` error. |
| `shadowed` | `List<PluginShadow> shadowed` | Copies a same-named plugin of a higher-priority root overrides (project > user > engine). Intended, so never an error: the editor logs it at info level and the winner's Plugin Manager card says "Overrides the engine copy". |

### `class PluginShadow`

A plugin copy that does not load because a plugin of the same name in a higher-priority root does.

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `name` | `String` | The plugin name both copies carry. |
| `winner` | `LuminaPluginDescriptor` | The copy that loads. |
| `shadowedManifestPath` | `String` | The `.lmplugin` of the copy that does not load. |
| `shadowedOrigin` | `PluginOrigin` | The root of the copy that does not load. |

### `class PluginRepository`

`PluginRepository`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `roots` | `List<PluginScanRoot> roots` | Holds the `roots` property or configuration state. |
| `scanAll` | `Future<PluginScanResult> scanAll()` | Executes `scanAll` operation. |
| `load` | `Future<LuminaPluginDescriptor> load(File manifest)` | Loads data from disk or memory buffer into the engine. |
| `loadInternal` | `Future<LuminaPluginDescriptor> loadInternal(File manifest, PluginOrigin ...` | Loads data from disk or memory buffer into the engine. Rejects (as a `schemaViolation` scan error) an `isolation` other than `in_process` / `process`, a `process_class` that is not a Dart class name, and `"isolation": "process"` without an editor module naming its `process_class`. |

---

[Previous: Math: units, axes and rotations](math.md) | [Up: lumina_core (pure-Dart foundation)](index.md) | [Next: Services](services.md)
