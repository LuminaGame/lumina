[Türkçe](../../tr/lumina/data-models.md)

# Data layer: models and repositories

The editor-facing data layer, part two: the persisted models (`.lmas` assets, the `.lmproject` manifest and its settings, plugin descriptors, landscape and sequencer data, recent projects) and the repositories that read and write them on disk. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/data/models/landscape_data.dart`](#libdatamodelslandscape_datadart)
- [`lib/data/models/lumina_asset.dart`](#libdatamodelslumina_assetdart)
- [`lib/data/models/lumina_plugin_descriptor.dart`](#libdatamodelslumina_plugin_descriptordart)
- [`lib/data/models/lumina_project.dart`](#libdatamodelslumina_projectdart)
- [`lib/data/models/recent_project_entry.dart`](#libdatamodelsrecent_project_entrydart)
- [`lib/data/models/sequencer_data.dart`](#libdatamodelssequencer_datadart)
- [`lib/data/repositories/asset_repository.dart`](#libdatarepositoriesasset_repositorydart)
- [`lib/data/repositories/collections_repository.dart`](#libdatarepositoriescollections_repositorydart)
- [`lib/data/repositories/plugin_repository.dart`](#libdatarepositoriesplugin_repositorydart)
- [`lib/data/repositories/project_repository.dart`](#libdatarepositoriesproject_repositorydart)

## `lib/data/models/landscape_data.dart`

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

## `lib/data/models/lumina_asset.dart`

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

## `lib/data/models/lumina_plugin_descriptor.dart`

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
| `extras` | `Map<String, dynamic> extras` | Holds the `extras` property or configuration state. |
| `pluginDir` | `Directory pluginDir` | Holds the `pluginDir` property or configuration state. |
| `origin` | `PluginOrigin origin` | Holds the `origin` property or configuration state. |
| `isContentOnly` | `bool get isContentOnly` | Checks current state or capability and returns a boolean value. |
| `iconFile` | `File? get iconFile` | Getter accessor returning the current value of `iconFile`. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

## `lib/data/models/lumina_project.dart`

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
| `template` | `String template` | Id of the game template the project was scaffolded from (`blank_3d` | `first_person` | `third_person`, see `data/services/game_template_service.dart`). Manifests written before templates existed default to `blank_3d`. |
| `input` | `ProjectInputSettings input` | Holds the `input` property or configuration state. |
| `mapsAndModes` | `ProjectMapsAndModes mapsAndModes` | Holds the `mapsAndModes` property or configuration state. |
| `physics` | `ProjectPhysicsSettings physics` | Holds the `physics` property or configuration state. |
| `packaging` | `ProjectPackagingSettings packaging` | Holds the `packaging` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

## `lib/data/models/recent_project_entry.dart`

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

## `lib/data/models/sequencer_data.dart`

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

## `lib/data/repositories/asset_repository.dart`

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

## `lib/data/repositories/collections_repository.dart`

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

## `lib/data/repositories/plugin_repository.dart`

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
| `errors` | `List<PluginScanError> errors` | Holds the `errors` property or configuration state. |

### `class PluginRepository`

`PluginRepository`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `roots` | `List<PluginScanRoot> roots` | Holds the `roots` property or configuration state. |
| `scanAll` | `Future<PluginScanResult> scanAll()` | Executes `scanAll` operation. |
| `load` | `Future<LuminaPluginDescriptor> load(File manifest)` | Loads data from disk or memory buffer into the engine. |
| `loadInternal` | `Future<LuminaPluginDescriptor> loadInternal(File manifest, PluginOrigin ...` | Loads data from disk or memory buffer into the engine. |

## `lib/data/repositories/project_repository.dart`

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
| `saveProject` | `Future<void> saveProject(LuminaProject project, String projectDirPath)` | Serializes and writes the current state or asset to disk. |

---

[Previous: Data layer: use cases and services (continued, part 3)](data-services-continued-3.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: models and repositories (continued)](data-models-continued.md)
