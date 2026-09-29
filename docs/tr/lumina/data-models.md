[English](../../en/lumina/data-models.md)

# Veri katmanı: modeller ve repository'ler

Editöre dönük veri katmanı, ikinci bölüm: kalıcı modeller (`.lmas` asset'leri, `.lmproject` manifest'i ve ayarları, eklenti tanımları, landscape ve sequencer verisi, son projeler) ve bunları diskte okuyup yazan repository'ler. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `density` | `double density` | `density` alanını (field/property) ve ilişkili veriyi saklar. |
| `minSpacing` | `double minSpacing` | `minSpacing` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleMin` | `double scaleMin` | `scaleMin` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleMax` | `double scaleMax` | `scaleMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `randomYaw` | `bool randomYaw` | `randomYaw` alanını (field/property) ve ilişkili veriyi saklar. |
| `alignToNormal` | `bool alignToNormal` | `alignToNormal` alanını (field/property) ve ilişkili veriyi saklar. |
| `slopeMinDegrees` | `double slopeMinDegrees` | `slopeMinDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `slopeMaxDegrees` | `double slopeMaxDegrees` | `slopeMaxDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class FoliageInstance`

One placed foliage instance: world position (metres, terrain space), a non-uniform scale, the yaw applied around the alignment axis and the surface normal it was aligned to.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `double z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleX` | `double scaleX` | `scaleX` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleY` | `double scaleY` | `scaleY` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleZ` | `double scaleZ` | `scaleZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `yaw` | `double yaw` | `yaw` alanını (field/property) ve ilişkili veriyi saklar. |
| `nx` | `double nx` | `nx` alanını (field/property) ve ilişkili veriyi saklar. |
| `ny` | `double ny` | `ny` alanını (field/property) ve ilişkili veriyi saklar. |
| `nz` | `double nz` | `nz` alanını (field/property) ve ilişkili veriyi saklar. |

### `class FoliageLayer`

A foliage layer: one mesh asset, its placement rules and the packed transforms of every instance painted with it.  The transforms are a flat `Float32List` of [floatsPerInstance] floats per instance (pos3, scale3, yaw, normal3) — the mirror of the GPU instance batch, kept consistent through the same swap-remove that `LuminaInstancedStaticMeshComponent.removeInstance` performs.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `meshAssetId` | `String meshAssetId` | `meshAssetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshAssetPath` | `String meshAssetPath` | `meshAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `rules` | `FoliageRules rules` | `rules` alanını (field/property) ve ilişkili veriyi saklar. |
| `instanceCount` | `int get instanceCount` | `instanceCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `transforms` | `Float32List get transforms` | The live transform floats (a view, length `instanceCount * 10`). |
| `addInstance` | `void addInstance(FoliageInstance i)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `instanceAt` | `FoliageInstance instanceAt(int index)` | `instanceAt` işlemini gerçekleştirir. |
| `removeAt` | `int removeAt(int index)` | Swap-removes [index]; returns the index the last instance moved from (`-1` when the removed instance was the last one) so callers can keep a parallel array in step with the GPU batch. |
| `clearInstances` | `void clearInstances()` | Koleksiyon veya tampon içeriğini tamamen temizler. |

### `class LandscapeData`

A square heightmap terrain plus its foliage layers — the single source of truth of the Landscape editor and of the runtime terrain component.  Heights are metres in `[0, maxHeight]` on a [gridResolution]² vertex grid covering a [worldSize]×[worldSize] metre square centred on the origin; the mesh sections and instance batches are derived from it and always regenerable.  ## Storage  Heights are held as **normalized `uint16`** scaled by [maxHeight] — two bytes per sample, with a quantisation step of `maxHeight / 65535` (exactly the precision a 16-bit PNG import carries anyway). That is what makes the 8129² ceiling reachable: 66 080 641 samples cost ~132 MB instead of the ~264 MB the old `Float32List` needed. Payload **v2** writes those samples directly; **v1** float payloads are still read and quantised on the way in.  There is no `heights` array to index: reads and writes go through [heightAt]/[setHeight] (or the linear [heightAtIndex]/[setHeightAtIndex]), and [heightsSnapshot] materialises a full `Float32List` only when a caller explicitly asks for one. Nothing in the sculpt or mesh path may do that at scale — at 8129² a single snapshot is 264 MB.

**Yapıcı Metotlar (Constructors):**
- `LandscapeData.fromBytes(Uint8List bytes)`: `LandscapeData.fromBytes(Uint8List bytes)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `version` | `int version` | `version` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridResolution` | `int gridResolution` | `gridResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `worldSize` | `double worldSize` | `worldSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxHeight` | `double maxHeight` | `maxHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `layers` | `List<FoliageLayer> layers` | `layers` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `Uint16List samples` | Normalized heights: `sample * maxHeight / 65535` metres. |
| `samplesAreExternal` | `bool samplesAreExternal` | True when this payload was decoded from a header whose samples live in a sidecar file that has not been attached yet. |
| `isValidResolution` | `static bool isValidResolution(int resolution)` | A resolution the section map tiles exactly: `n * 64 + 1`, from 65 to [maxGridResolution]. |
| `validResolutions` | `static List<int> get validResolutions` | Every resolution the importer accepts, ascending. |
| `describeInvalidResolution` | `static String? describeInvalidResolution(int resolution)` | Why [resolution] cannot be imported, or null when it can. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `heightBytes` | `int get heightBytes` | Bytes the heights occupy in memory. |
| `cellSize` | `double get cellSize` | Metres between two neighbouring height samples. |
| `heightStep` | `double get heightStep` | The smallest height difference this payload can represent. |
| `heightMin` | `double get heightMin` | Lowest height in the terrain, as of the last [recomputeHeightRange]. |
| `heightMax` | `double get heightMax` | Highest height in the terrain, as of the last [recomputeHeightRange]. |
| `recomputeHeightRange` | `void recomputeHeightRange()` | Rescans every sample to refresh [heightMin]/[heightMax].  O(vertexCount) — call it when a terrain is created, imported or opened, never per stroke and never per vertex. [setHeight] widens the cached range as it goes, so the range is only ever too generous, never wrong in a way that clips the colour ramp. |
| `heightAt` | `double heightAt(int col, int row)` | `heightAt` işlemini gerçekleştirir. |
| `heightAtIndex` | `double heightAtIndex(int index)` | Height of the [index]-th sample in row-major order. |
| `setHeight` | `void setHeight(int col, int row, double value)` | `Height` parametresini günceller ve sisteme uygular. |
| `setHeightAtIndex` | `void setHeightAtIndex(int index, double value)` | `HeightAtIndex` parametresini günceller ve sisteme uygular. |
| `heightsSnapshot` | `Float32List heightsSnapshot()` | A full `Float32List` of every height, materialised on demand.  Two bytes per sample become four: at 8129² this is a 264 MB allocation. Nothing in the sculpt, mesh or save path calls it — it exists for tests and for exporting a v1 payload. |
| `worldXOf` | `double worldXOf(int col)` | World X (metres) of column [col]; the grid is centred on the origin. |
| `worldZOf` | `double worldZOf(int row)` | `worldZOf` işlemini gerçekleştirir. |
| `columnOf` | `double columnOf(double worldX)` | `columnOf` işlemini gerçekleştirir. |
| `rowOf` | `double rowOf(double worldZ)` | `rowOf` işlemini gerçekleştirir. |
| `sampleHeight` | `double sampleHeight(double worldX, double worldZ)` | Bilinear height sample at a world position (metres). |
| `sampleNormal` | `Vector3 sampleNormal(double worldX, double worldZ)` | Unit surface normal (Y-up) from central differences of the heightmap. |
| `sampleSlopeDegrees` | `double sampleSlopeDegrees(double worldX, double worldZ)` | Slope in degrees off vertical at a world position. |
| `contains` | `bool contains(double worldX, double worldZ)` | True when [worldX]/[worldZ] lie inside the terrain footprint. |
| `copyWithHeights` | `LandscapeData copyWithHeights(Float32List newHeights)` | `copyWithHeights` işlemini gerçekleştirir. |
| `sidecarPathFor` | `static String sidecarPathFor(String assetPath)` | The heights file that belongs to the `.lmas` at [assetPath]. |
| `writeSidecar` | `Future<void> writeSidecar(File file)` | Streams the samples into [file] in 4 Mi-sample chunks.  Nothing here materialises a second copy of the heightmap: at 8129² one monolithic byte list would be another 132 MB on top of the samples. |
| `readSidecar` | `void readSidecar(File file)` | Reads a sidecar written by [writeSidecar] into this payload's samples.  Throws when the sidecar does not describe this terrain, rather than filling the grid with whatever bytes were there. |

## `lib/data/models/lumina_asset.dart`

### `enum AssetType`

`AssetType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class AssetReference`

`AssetReference`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `AssetReference.fromMap(Map<String, dynamic> map)`: `AssetReference.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `slotName` | `String slotName` | `slotName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetId` | `String assetId` | `assetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class LuminaAsset`

`LuminaAsset`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `LuminaAsset.fromMap(Map<String, dynamic> map)`: `LuminaAsset.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.
- `LuminaAsset.fromBytes(Uint8List bytes)`: Deserializes asset from binary Protobuf bytes or JSON fallback payload.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetId` | `String assetId` | `assetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `AssetType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasThumbnail` | `bool hasThumbnail` | `hasThumbnail` alanını (field/property) ve ilişkili veriyi saklar. |
| `thumbnailPng` | `Uint8List? thumbnailPng` | `thumbnailPng` alanını (field/property) ve ilişkili veriyi saklar. |
| `rawPayload` | `Uint8List? rawPayload` | `rawPayload` alanını (field/property) ve ilişkili veriyi saklar. |
| `rawMatSource` | `String rawMatSource` | `rawMatSource` alanını (field/property) ve ilişkili veriyi saklar. |
| `references` | `List<AssetReference> references` | `references` alanını (field/property) ve ilişkili veriyi saklar. |
| `metadata` | `Map<String, String> metadata` | `metadata` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |
| `toProtoBufferBytes` | `Uint8List toProtoBufferBytes()` | Serializes asset to binary Protobuf bytes format with LMAS magic header. |

## `lib/data/models/lumina_plugin_descriptor.dart`

### `enum PluginOrigin`

`PluginOrigin`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum PluginModuleType`

`PluginModuleType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class PluginModuleDescriptor`

`PluginModuleDescriptor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PluginModuleDescriptor.fromJson(Map<String, dynamic> json)`: `PluginModuleDescriptor.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `PluginModuleType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `entryLibrary` | `String entryLibrary` | `entryLibrary` alanını (field/property) ve ilişkili veriyi saklar. |
| `registrationClass` | `String registrationClass` | `registrationClass` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class PluginDependencyRef`

`PluginDependencyRef`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PluginDependencyRef.fromJson(Map<String, dynamic> json)`: `PluginDependencyRef.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `version` | `VersionConstraint version` | `version` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class LuminaPluginDescriptor`

`LuminaPluginDescriptor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `friendlyName` | `String? friendlyName` | `friendlyName` alanını (field/property) ve ilişkili veriyi saklar. |
| `version` | `Version version` | `version` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String? description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `String category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `authors` | `List<String> authors` | `authors` alanını (field/property) ve ilişkili veriyi saklar. |
| `engineVersion` | `VersionConstraint? engineVersion` | `engineVersion` alanını (field/property) ve ilişkili veriyi saklar. |
| `dependencies` | `List<PluginDependencyRef> dependencies` | `dependencies` alanını (field/property) ve ilişkili veriyi saklar. |
| `modules` | `List<PluginModuleDescriptor> modules` | `modules` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabledByDefault` | `bool enabledByDefault` | `enabledByDefault` alanını (field/property) ve ilişkili veriyi saklar. |
| `canContainContent` | `bool canContainContent` | `canContainContent` alanını (field/property) ve ilişkili veriyi saklar. |
| `extras` | `Map<String, dynamic> extras` | `extras` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginDir` | `Directory pluginDir` | `pluginDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `origin` | `PluginOrigin origin` | `origin` alanını (field/property) ve ilişkili veriyi saklar. |
| `isContentOnly` | `bool get isContentOnly` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `iconFile` | `File? get iconFile` | `iconFile` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

## `lib/data/models/lumina_project.dart`

### `class ScalabilityCategory`

`ScalabilityCategory`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ScalabilityCategory.fromMap(Map<String, dynamic> map)`: `ScalabilityCategory.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewDistance` | `String viewDistance` | `viewDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowQuality` | `String shadowQuality` | `shadowQuality` alanını (field/property) ve ilişkili veriyi saklar. |
| `antiAliasing` | `String antiAliasing` | `antiAliasing` alanını (field/property) ve ilişkili veriyi saklar. |
| `postProcessing` | `String postProcessing` | `postProcessing` alanını (field/property) ve ilişkili veriyi saklar. |
| `textureQuality` | `String textureQuality` | `textureQuality` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadingQuality` | `String shadingQuality` | `shadingQuality` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `extension ScalabilityPresets`

`ScalabilityPresets`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `forPreset` | `static ScalabilityCategory forPreset(String preset)` | `forPreset` işlemini gerçekleştirir. |

### `enum ProjectInputValueType`

Value type of an input action, as defined by the runtime input system (actions and mapping contexts).

### `class ProjectInputAction`

`ProjectInputAction`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectInputAction.fromMap(Map<String, dynamic> map)`: `ProjectInputAction.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.
- `ProjectInputAction(name: name ?? this.name, valueType: valueType ?? this.valueType)`: `ProjectInputAction(name: name ?? this.name, valueType: valueType ?? this.valueType)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `valueType` | `ProjectInputValueType valueType` | `valueType` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectInputMapping`

One key binding inside a mapping context. [keyId] is the stable `LogicalKeyboardKey.keyId` and [keyLabel] its debug/display name; the runtime input task maps `keyId` back to its own key abstraction.

**Yapıcı Metotlar (Constructors):**
- `ProjectInputMapping.fromMap(Map<String, dynamic> map)`: `ProjectInputMapping.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `action` | `String action` | `action` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyId` | `int keyId` | `keyId` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyLabel` | `String keyLabel` | `keyLabel` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `double scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `axis` | `String axis` | `X`, `Y` (axis component the key drives) or empty for digital actions. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectMappingContext`

`ProjectMappingContext`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectMappingContext.fromMap(Map<String, dynamic> map)`: `ProjectMappingContext.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `priority` | `int priority` | `priority` alanını (field/property) ve ilişkili veriyi saklar. |
| `mappings` | `List<ProjectInputMapping> mappings` | `mappings` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectInputSettings`

`ProjectInputSettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectInputSettings.fromMap(Map<String, dynamic> map)`: `ProjectInputSettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.
- `ProjectInputSettings(actions: actions ?? this.actions, mappingContexts: mappingContexts ?? this.mappingContexts)`: `ProjectInputSettings(actions: actions ?? this.actions, mappingContexts: mappingContexts ?? this.mappingContexts)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actions` | `List<ProjectInputAction> actions` | `actions` alanını (field/property) ve ilişkili veriyi saklar. |
| `mappingContexts` | `List<ProjectMappingContext> mappingContexts` | `mappingContexts` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectMapsAndModes`

`ProjectMapsAndModes`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectMapsAndModes.fromMap(Map<String, dynamic> map)`: `ProjectMapsAndModes.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editorStartupMap` | `String editorStartupMap` | `contents/`-relative path of the level the editor opens on startup. |
| `gameDefaultMap` | `String gameDefaultMap` | `contents/`-relative path of the level the shipped game starts in. |
| `defaultGameMode` | `String defaultGameMode` | Dart class name of the game mode (built-in `LuminaGameMode` or a generated actor class). |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectPhysicsSettings`

`ProjectPhysicsSettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectPhysicsSettings.fromMap(Map<String, dynamic> map)`: `ProjectPhysicsSettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.
- `ProjectPhysicsSettings(gravityZ: gravityZ ?? this.gravityZ, fixedTimestep: fixedTimestep ?? this.fixedTimestep)`: `ProjectPhysicsSettings(gravityZ: gravityZ ?? this.gravityZ, fixedTimestep: fixedTimestep ?? this.fixedTimestep)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gravityZ` | `double gravityZ` | World gravity along Z in cm/s² (default -980). |
| `fixedTimestep` | `double fixedTimestep` | `fixedTimestep` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class ProjectPackagingSettings`

`ProjectPackagingSettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectPackagingSettings.fromMap(Map<String, dynamic> map)`: `ProjectPackagingSettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.
- `ProjectPackagingSettings(targetOs: targetOs ?? this.targetOs, outputDir: outputDir ?? this.outputDir)`: `ProjectPackagingSettings(targetOs: targetOs ?? this.targetOs, outputDir: outputDir ?? this.outputDir)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `targetOs` | `String targetOs` | `targetOs` alanını (field/property) ve ilişkili veriyi saklar. |
| `outputDir` | `String outputDir` | `outputDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class EditorSnapSettings`

`EditorSnapSettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EditorSnapSettings.fromMap(Map<String, dynamic> map)`: `EditorSnapSettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `translateSnapEnabled` | `bool translateSnapEnabled` | `translateSnapEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotateSnapEnabled` | `bool rotateSnapEnabled` | `rotateSnapEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleSnapEnabled` | `bool scaleSnapEnabled` | `scaleSnapEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `surfaceSnapEnabled` | `bool surfaceSnapEnabled` | `surfaceSnapEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridVisible` | `bool gridVisible` | `gridVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `translateSnapStep` | `double translateSnapStep` | `translateSnapStep` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotateSnapStep` | `double rotateSnapStep` | `rotateSnapStep` alanını (field/property) ve ilişkili veriyi saklar. |
| `scaleSnapStep` | `double scaleSnapStep` | `scaleSnapStep` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridStep` | `double gridStep` | `gridStep` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridExtent` | `double gridExtent` | `gridExtent` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class EngineScalabilitySettings`

`EngineScalabilitySettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EngineScalabilitySettings.fromMap(Map<String, dynamic> map)`: `EngineScalabilitySettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `targetFps` | `int targetFps` | `targetFps` alanını (field/property) ve ilişkili veriyi saklar. |
| `vsyncEnabled` | `bool vsyncEnabled` | `vsyncEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `qualityPreset` | `String qualityPreset` | `qualityPreset` alanını (field/property) ve ilişkili veriyi saklar. |
| `scalability` | `ScalabilityCategory scalability` | `scalability` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoOrganizeFiles` | `bool autoOrganizeFiles` | `autoOrganizeFiles` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoSaveIntervalSeconds` | `int autoSaveIntervalSeconds` | `autoSaveIntervalSeconds` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class EditorViewportSettings`

`EditorViewportSettings`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Yapıcı Metotlar (Constructors):**
- `EditorViewportSettings.fromMap(Map<String, dynamic> map)`: `EditorViewportSettings.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cameraMode` | `String cameraMode` | `cameraMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewMode` | `String viewMode` | `viewMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `bufferVisualization` | `String bufferVisualization` | `bufferVisualization` alanını (field/property) ve ilişkili veriyi saklar. |
| `showFlags` | `Map<String, bool> showFlags` | `showFlags` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

### `class LuminaProject`

`LuminaProject`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `LuminaProject.fromMap(Map<String, dynamic> map)`: `LuminaProject.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectName` | `String projectName` | `projectName` alanını (field/property) ve ilişkili veriyi saklar. |
| `engineVersion` | `String engineVersion` | `engineVersion` alanını (field/property) ve ilişkili veriyi saklar. |
| `activeLevel` | `String activeLevel` | `activeLevel` alanını (field/property) ve ilişkili veriyi saklar. |
| `isDirty` | `bool isDirty` | `isDirty` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastModifiedTimestamp` | `String lastModifiedTimestamp` | `lastModifiedTimestamp` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastCodeGeneratedTimestamp` | `String lastCodeGeneratedTimestamp` | `lastCodeGeneratedTimestamp` alanını (field/property) ve ilişkili veriyi saklar. |
| `settings` | `EngineScalabilitySettings settings` | `settings` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorSnap` | `EditorSnapSettings editorSnap` | `editorSnap` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewport` | `EditorViewportSettings editorViewport` | `editorViewport` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabledPlugins` | `List<String>? enabledPlugins` | `enabledPlugins` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `template` | `String template` | Id of the game template the project was scaffolded from (`blank_3d` | `first_person` | `third_person`, see `data/services/game_template_service.dart`). Manifests written before templates existed default to `blank_3d`. |
| `input` | `ProjectInputSettings input` | `input` alanını (field/property) ve ilişkili veriyi saklar. |
| `mapsAndModes` | `ProjectMapsAndModes mapsAndModes` | `mapsAndModes` alanını (field/property) ve ilişkili veriyi saklar. |
| `physics` | `ProjectPhysicsSettings physics` | `physics` alanını (field/property) ve ilişkili veriyi saklar. |
| `packaging` | `ProjectPackagingSettings packaging` | `packaging` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

## `lib/data/models/recent_project_entry.dart`

### `class RecentProjectEntry`

Represents a tracked project entry in the launcher's recent projects list.

**Yapıcı Metotlar (Constructors):**
- `RecentProjectEntry.fromMap(Map<String, dynamic> map)`: `RecentProjectEntry.fromMap(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `project` | `LuminaProject project` | `project` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDir` | `String projectDir` | `projectDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastOpened` | `DateTime lastOpened` | `lastOpened` alanını (field/property) ve ilişkili veriyi saklar. |
| `coverImage` | `String? coverImage` | `coverImage` alanını (field/property) ve ilişkili veriyi saklar. |
| `isMissing` | `bool isMissing` | `isMissing` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

## `lib/data/models/sequencer_data.dart`

### `enum KeyInterpolation`

`KeyInterpolation`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cubic` | `cubic` | `cubic` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `String toJson()` | Nesneyi JSON haritasına serileştirir. |
| `fromJson` | `static KeyInterpolation fromJson(String name)` | Veri haritasından nesneyi yeniden oluşturur. |

### `class SequencerKey`

`SequencerKey`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SequencerKey.fromJson(Map<String, dynamic> json)`: `SequencerKey.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `frame` | `int frame` | `frame` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolation` | `KeyInterpolation interpolation` | `interpolation` alanını (field/property) ve ilişkili veriyi saklar. |
| `inTangent` | `double inTangent` | `inTangent` alanını (field/property) ve ilişkili veriyi saklar. |
| `outTangent` | `double outTangent` | `outTangent` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class SequencerChannel`

`SequencerChannel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SequencerChannel.fromJson(Map<String, dynamic> json)`: `SequencerChannel.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `keys` | `List<SequencerKey> keys` | `keys` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `enum SequencerTrackKind`

`SequencerTrackKind`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `visibility` | `visibility` | `visibility` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `String toJson()` | Nesneyi JSON haritasına serileştirir. |
| `fromJson` | `static SequencerTrackKind fromJson(String name)` | Veri haritasından nesneyi yeniden oluşturur. |

### `class SequencerTrack`

`SequencerTrack`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SequencerTrack.fromJson(Map<String, dynamic> json)`: `SequencerTrack.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorId` | `String actorId` | `actorId` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorName` | `String actorName` | `actorName` alanını (field/property) ve ilişkili veriyi saklar. |
| `kind` | `SequencerTrackKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `propertyName` | `String? propertyName` | `propertyName` alanını (field/property) ve ilişkili veriyi saklar. |
| `channels` | `List<SequencerChannel> channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class SequencerData`

`SequencerData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SequencerData.fromJson(Map<String, dynamic> json)`: `SequencerData.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.
- `SequencerData.fromBytes(Uint8List bytes)`: `SequencerData.fromBytes(Uint8List bytes)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `version` | `int version` | `version` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `int fps` | `fps` alanını (field/property) ve ilişkili veriyi saklar. |
| `lengthFrames` | `int lengthFrames` | `lengthFrames` alanını (field/property) ve ilişkili veriyi saklar. |
| `tracks` | `List<SequencerTrack> tracks` | `tracks` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `toBytes` | `Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson(...` | `toBytes` işlemini gerçekleştirir. |

## `lib/data/repositories/asset_repository.dart`

### `class RealAssetInfo`

`RealAssetInfo`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fileName` | `String fileName` | `fileName` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativePath` | `String relativePath` | `relativePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `AssetType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `bytes` | `int bytes` | `bytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `thumbnailBytes` | `Uint8List? thumbnailBytes` | `thumbnailBytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `lmasPath` | `String? lmasPath` | `lmasPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetId` | `String? assetId` | `assetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `references` | `List<AssetReference> references` | `references` alanını (field/property) ve ilişkili veriyi saklar. |
| `lastModified` | `DateTime? lastModified` | `lastModified` alanını (field/property) ve ilişkili veriyi saklar. |
| `formattedSize` | `String get formattedSize` | `formattedSize` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class AssetRepository`

`AssetRepository`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `renameAsset` | `void renameAsset(String projectPath, String lmasPath, String newName, As...` | `renameAsset` işlemini gerçekleştirir. |
| `moveAsset` | `void moveAsset(String projectPath, String lmasPath, String targetFolder,...` | `moveAsset` işlemini gerçekleştirir. |
| `duplicateAsset` | `void duplicateAsset(String lmasPath)` | `duplicateAsset` işlemini gerçekleştirir. |
| `sizeInfo` | `Map<String, int> sizeInfo(String projectPath, String lmasPath, AssetRefe...` | `sizeInfo` işlemini gerçekleştirir. |
| `loadMeshFromDisk` | `static Future<GlbMeshData?> loadMeshFromDisk(String targetPath)` | Centralized Universal 3D Mesh Loader: Reads any .lmas asset container, companion .entity.glb file, direct .glb/.gltf, or .obj file and returns a fully parsed [GlbMeshData] with geometry, bounds, subPrimitives, and material slots. |
| `scanProjectContents` | `List<RealAssetInfo> scanProjectContents(String projectPath)` | `scanProjectContents` işlemini gerçekleştirir. |
| `scanContentFolders` | `List<String> scanContentFolders(String projectPath)` | `scanContentFolders` işlemini gerçekleştirir. |

### `class _ThumbTri`

`_ThumbTri`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_ThumbTri(this.p0, this.p1, this.p2, this.depth, this.shade, this.i0, this.i1, this.i2)`: `_ThumbTri(this.p0, this.p1, this.p2, this.depth, this.shade, this.i0, this.i1, this.i2)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `depth` | `double depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `shade` | `double shade` | `shade` alanını (field/property) ve ilişkili veriyi saklar. |
| `i0` | `int i0` | `i0` alanını (field/property) ve ilişkili veriyi saklar. |
| `i1` | `int i1` | `i1` alanını (field/property) ve ilişkili veriyi saklar. |
| `i2` | `int i2` | `i2` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/data/repositories/collections_repository.dart`

### `class CollectionAsset`

`CollectionAsset`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `CollectionAsset.fromJson(Map<String, dynamic> json)`: `CollectionAsset.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetId` | `String assetId` | `assetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class Collection`

`Collection`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `Collection.fromJson(Map<String, dynamic> json)`: `Collection.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `assets` | `List<CollectionAsset> assets` | `assets` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class CollectionsRepository`

`CollectionsRepository`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `loadCollections` | `List<Collection> loadCollections(String projectPath)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `saveCollections` | `void saveCollections(String projectPath, List<Collection> collections)` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `healPaths` | `void healPaths(String projectPath, List<RealAssetInfo> currentAssets)` | `healPaths` işlemini gerçekleştirir. |

## `lib/data/repositories/plugin_repository.dart`

### `enum PluginErrorKind`

`PluginErrorKind`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class PluginScanError`

`PluginScanError`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `filePath` | `String filePath` | `filePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `kind` | `PluginErrorKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `jsonOffset` | `int? jsonOffset` | `jsonOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class PluginManifestException`

`PluginManifestException`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PluginManifestException(this.error)`: `PluginManifestException(this.error)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `error` | `PluginScanError error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString() => error.toString()` | `toString` işlemini gerçekleştirir. |

### `class PluginScanRoot`

`PluginScanRoot`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dir` | `Directory dir` | `dir` alanını (field/property) ve ilişkili veriyi saklar. |
| `origin` | `PluginOrigin origin` | `origin` alanını (field/property) ve ilişkili veriyi saklar. |
| `packageDirs` | `List<Directory>? packageDirs` | Eklentileri ortak bir üst klasörde olmayan bir kök için eklenti klasörlerinin kendisi (bir çalışma alanının çözümlediği paketler); null ise `dir`'in alt klasörleri taranır. |
| `PluginScanRoot.packages` | `PluginScanRoot.packages({required Directory dir, required List<Directory> packageDirs, required PluginOrigin origin})` | Verilen eklenti klasörlerinden oluşan kök; `dir`, onların çözümlendiği çalışma alanıdır. Editörün yerleşik eklentileri böyle bir köktür. |
| `candidates` | `List<Directory> candidates()` | Eklenti olarak taranan klasörler: var olan `packageDirs`, yoksa `dir`'in alt klasörleri. |

### `class PluginScanResult`

`PluginScanResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `plugins` | `List<LuminaPluginDescriptor> plugins` | `plugins` alanını (field/property) ve ilişkili veriyi saklar. |
| `errors` | `List<PluginScanError> errors` | `errors` alanını (field/property) ve ilişkili veriyi saklar. |

### `class PluginRepository`

`PluginRepository`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `roots` | `List<PluginScanRoot> roots` | `roots` alanını (field/property) ve ilişkili veriyi saklar. |
| `scanAll` | `Future<PluginScanResult> scanAll()` | `scanAll` işlemini gerçekleştirir. |
| `load` | `Future<LuminaPluginDescriptor> load(File manifest)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `loadInternal` | `Future<LuminaPluginDescriptor> loadInternal(File manifest, PluginOrigin ...` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |

## `lib/data/repositories/project_repository.dart`

### `enum ProjectCreationStep`

`ProjectCreationStep`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class ProjectCreationProgress`

`ProjectCreationProgress`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectCreationProgress(this.step, this.progress, this.message)`: `ProjectCreationProgress(this.step, this.progress, this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `step` | `ProjectCreationStep step` | `step` alanını (field/property) ve ilişkili veriyi saklar. |
| `progress` | `double progress` | `progress` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ProjectCreationException`

`ProjectCreationException`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ProjectCreationException(this.step, this.message)`: `ProjectCreationException(this.step, this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `step` | `ProjectCreationStep step` | `step` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class ProjectRepository`

`ProjectRepository`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `configDir` | `Directory? configDir` | `configDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `processRunner` | `ProcessRunner processRunner` | `processRunner` alanını (field/property) ve ilişkili veriyi saklar. |
| `resolvedConfigDir` | `Directory get resolvedConfigDir` | `resolvedConfigDir` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `getRecentProjects` | `Future<List<RecentProjectEntry>> getRecentProjects()` | `RecentProjects` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getRecentProjectsFlat` | `Future<List<LuminaProject>> getRecentProjectsFlat()` | `RecentProjectsFlat` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `removeRecentProject` | `Future<void> removeRecentProject(String projectDir)` | Belirtilen `RecentProject` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `validateProject` | `Future<bool> validateProject(String projectDir)` | `validateProject` işlemini gerçekleştirir. |
| `deleteProjectFromDisk` | `Future<void> deleteProjectFromDisk(String projectDir)` | Belirtilen `ProjectFromDisk` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `validateProjectName` | `static String? validateProjectName(String? name)` | Validates a candidate project name against Dart package naming rules. |
| `validateLocation` | `static String? validateLocation(String? location)` | Validates the target project parent directory. |
| `luminaPackagePath` | `static String get luminaPackagePath` | Resolves the engine package path for pubspec dependency injection. |
| `loadProject` | `Future<LuminaProject?> loadProject(String lmprojectPath)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `saveProject` | `Future<void> saveProject(LuminaProject project, String projectDirPath)` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

---

[Önceki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)](data-services-continued-3.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: modeller ve repository'ler (devamı)](data-models-continued.md)
