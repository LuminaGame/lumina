[English](../../en/lumina_core/formats.md)

# Dosya formatları ve repository'ler

Lumina'nın dosya formatları Dart modelleri olarak (`.lmas` asset'leri ve özetleri, `.lmproject` manifest'i ve ayarları, level dokümanları, landscape ve sequencer verisi, `.lmplugin` tanımları, tema dokümanları, son projeler) ve level ile eklentileri okuyup yazan repository'ler. Dosya yolları `lumina_core/` paket dizinine görelidir.

**Bu sayfada:**

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

## `lib/src/formats/lumina_asset.dart`

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

## `lib/src/formats/lumina_asset_summary.dart`

### `class LmasByteRange`

Where a base64 string value (`thumbnail_png`, `raw_payload`) sits inside a `.lmas` file: the byte offset of its first character (after the opening quote) and its length in bytes. A null [length] means the string was not scanned to its end (the summary stopped once it had what it needed).

**Yapıcı Metotlar (Constructors):**

- `const LmasByteRange(this.offset, [this.length])`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `offset` | `final int offset` |  |
| `length` | `final int? length` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `fromJson` | `static LmasByteRange? fromJson(Object? json)` |  |

### `class LuminaAssetSummary`

What a `.lmas` is without its payload: id, name, type, metadata, references, whether it carries a thumbnail and where it and the payload sit in the file. [LuminaAsset.readSummary] reads it without base64-decoding `thumbnail_png` / `raw_payload`; the project's asset index ([LuminaAssetIndex]) stores one per file.

For an actor asset whose payload is a small Blueprint document, the summary also knows the document's [blueprintKind] (`class`, `enum`, `interface`, `save_game`, `montage`, …), its [parentClass] and whether it has an event graph — what the class catalogs need without the payload.

**Yapıcı Metotlar (Constructors):**

- `const LuminaAssetSummary({required this.assetId, required this.name, required this.type, this.hasThumbnail = false, this.metadata = const {}, this.references =...`
- `factory LuminaAssetSummary.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `LuminaLevelDocument({required this.relativePath, Map<String, dynamic>? container})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` | Project-relative path (`contents/levels/L_Test.lmas`). |
| `container` | `final Map<String, dynamic> container` | The whole container, as read (and as [toJson] writes it back). |
| `tryParse` | `static LuminaLevelDocument? tryParse(String json, {required String relativePath})` | Reads a level container's JSON; null when it is not one. |
| `name` | `String get name` | The level's name (`L_Test`). |
| `metadata` | `Map<String, dynamic> get metadata` | `metadata`, created when missing. |
| `actors` | `List<Map<String, dynamic>> get actors` | The placed actors (`metadata.actors`), as maps. |
| `actors` | `set actors(List<Map<String, dynamic>> value)` |  |
| `levelBlueprintKey` | `static const String levelBlueprintKey` | Bir level'ın Level Blueprint'ini sakladığı `metadata` anahtarı (`'levelBlueprint'`). |
| `levelBlueprintJson` | `Map<String, dynamic>? get levelBlueprintJson` | Saklanan Level Blueprint JSON olarak; level'da yoksa null. Engine onu `levelBlueprint` extension getter'ı ile kendi `LuminaLevelBlueprintDocument` tipine okur (`package:lumina`, `lib/src/blueprint/level_blueprint_storage.dart`); aynı extension `levelActorRefs`'i de ekler. |
| `levelBlueprintJson` | `set levelBlueprintJson(Map<String, dynamic>? value)` | [value]'yu `metadata.levelBlueprint` altına yazar; null anahtarı siler, böylece script'i olmayan bir level olduğu gibi kalır. |
| `hasLevelBlueprint` | `bool get hasLevelBlueprint` | Level'ın bir Blueprint taşıyıp taşımadığı. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `encode` | `String encode()` |  |

## `lib/src/formats/lumina_plugin_descriptor.dart`

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
| `processClass` | `final String? processClass` | `entryLibrary` içinde, eklentinin kendi sürecinde çalışan `LuminaPluginProcess` alt sınıfı (`.lmplugin` `"process_class"`). `"isolation": "process"` diyen bir eklentinin editor modülünde zorunludur. |
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
| `isolation` | `final PluginIsolation isolation` | Editor modülünün nerede çalıştığı (`.lmplugin` `"isolation"`, varsayılan `in_process`); `toJson` onu yalnızca `process` iken yazar. |
| `processModule` | `PluginModuleDescriptor? get processModule` | Bir `process_class` adı veren editor modülü ya da null. |
| `processClass` | `String? get processClass` | `processModule`'ün `process_class`'ı. |
| `effectiveIsolation` | `PluginIsolation effectiveIsolation([LuminaProject? project])` | Eklentinin `project` içinde nerede çalıştığı: yalıtılmış bir eklenti (`process_class` ile `process`) projenin `plugin_isolation`'ı onu `in_process`'e zorlamadıkça kendi sürecinde çalışır; diğer her eklenti süreç içinde çalışır. |
| `extras` | `Map<String, dynamic> extras` | `extras` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginDir` | `Directory pluginDir` | `pluginDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `origin` | `PluginOrigin origin` | `origin` alanını (field/property) ve ilişkili veriyi saklar. |
| `isContentOnly` | `bool get isContentOnly` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `iconFile` | `File? get iconFile` | `iconFile` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

## `lib/src/formats/lumina_project.dart`

Girdi ayarları ile haritalar ve modlar (`ProjectInputValueType`, `ProjectInputAction`, `ProjectInputMapping`, `ProjectMappingContext`, `ProjectInputSettings`, `ProjectMapsAndModes`) `project_input_settings.dart` içinde, paketleme ayarları (`kPackagingPlatforms`, `packagingPlatformLabel`, `ProjectPackagingSettings`, …) `project_packaging_settings.dart` içinde durur; `lumina_project.dart` ikisini de dışa aktarır, import edenler bir değişiklik görmez.

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
| `pluginIsolation` | `final Map<String, PluginIsolation> pluginIsolation` | Eklenti başına yalıtım geçersiz kılmaları, `.lmproject` `plugin_isolation: {"<plugin>": "in_process" \| "process"}` (ada göre sıralı, yalnızca boş değilken yazılır; okurken bilinmeyen bir değer atılır). Hata ayıklamak için yalıtılmış bir eklentiyi süreç içine zorlar; bkz. `LuminaPluginDescriptor.effectiveIsolation`. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `template` | `String template` | Id of the game template the project was scaffolded from (`blank_3d` | `first_person` | `third_person`, see `GameTemplateCatalog`). Manifests written before templates existed default to `blank_3d`. |
| `input` | `ProjectInputSettings input` | `input` alanını (field/property) ve ilişkili veriyi saklar. |
| `mapsAndModes` | `ProjectMapsAndModes mapsAndModes` | `mapsAndModes` alanını (field/property) ve ilişkili veriyi saklar. |
| `physics` | `ProjectPhysicsSettings physics` | `physics` alanını (field/property) ve ilişkili veriyi saklar. |
| `packaging` | `ProjectPackagingSettings packaging` | `packaging` alanını (field/property) ve ilişkili veriyi saklar. |
| `toMap` | `Map<String, dynamic> toMap()` | `toMap` işlemini gerçekleştirir. |

## `lib/src/formats/lumina_theme_document.dart`

### `class LuminaComponentStyle`

Bir widget türü (buton, kart, metin girişi, rozet, iletişim penceresi vb.) için bileşen düzeyinde stil geçersiz kılmaları: arka plan ve ön plan renkleri, kenarlık yuvarlaklığı, iç boşluk (padding) ve tipografi geçersiz kılmaları.

**Yapıcı Metotlar (Constructors):**

- `const LuminaComponentStyle({this.backgroundColor, this.foregroundColor, this.borderRadius, this.borderColor, this.borderWidth, this.paddingHorizontal, this.paddingVertical, this.fontSize, this.fontWeight})`

### `class LuminaCustomStyle`

Oyun widget'larına atanabilen, belirli bir hedef bileşeni özelleştiren adlandırılmış özel stil varyantı.

**Yapıcı Metotlar (Constructors):**

- `const LuminaCustomStyle({required this.name, required this.targetComponent, required this.style})`

### `class LuminaThemeDocument`

`AssetType.theme` türündeki `.lmas` varlıklarında serileştirilen kullanıcı arayüzü temaları için doküman modeli. Tasarım belirteçlerini (renk paleti, temel köşe yuvarlaklığı, tipografi), bileşene özel geçersiz kılmaları ve adlandırılmış özel stilleri saklar.

**Yapıcı Metotlar (Constructors):**

- `const LuminaThemeDocument({this.name, this.baseTheme, this.colors, this.radius, this.fontFamily, this.baseFontSize, this.headlineFontSize, this.componentStyles, this.customStyles})`
- `factory LuminaThemeDocument.defaultShadcnDark({String name = 'DefaultTheme'})`
- `factory LuminaThemeDocument.defaultGameTheme({String name = 'GameUITheme'})`
- `factory LuminaThemeDocument.fromAsset(LuminaAsset asset)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `colorInt` | `int colorInt(String token, {int fallback = 0xFF888888})` | Tema paletindeki bir belirtecin ARGB rengi (`0xAARRGGBB`) ya da [fallback]. Flutter kodu onu `colorOf` extension'ı ile `Color` olarak okur (`package:lumina`, `lib/src/umg/theme_document_colors.dart`); aynı dosya `LuminaComponentStyle`'a `bgColor` / `fgColor` / `bColor` ekler. |
| `hasComponentStyle` | `bool hasComponentStyle(String componentKey)` | Bileşen için özel bir stil geçersiz kılmasının bulunup bulunmadığını döner. |
| `toAsset` | `LuminaAsset toAsset({String name})` | Tema dokümanını `AssetType.theme` türünde bir `LuminaAsset` varlığına serileştirir. |
| `toJson` | `String toJson()` | Tema dokümanını JSON metnine serileştirir. |

## `lib/src/formats/plugin_isolation.dart`

### `enum PluginIsolation`

Bir code plugin'in editor modülünün nerede çalıştığı: `inProcess` (`in_process`, editörün içinde) ya da `process` (process kısmı kendi denetlenen sürecinde). `manifestValue`, `.lmplugin` / `.lmproject` dosyalarına yazılan dizgidir; `static PluginIsolation? tryParse(Object? value)` birini okur (başka her şey için null). `lumina_plugin_descriptor.dart` ve `lumina_project.dart` tarafından dışa aktarılır.

## `lib/src/formats/project_web_loading_style.dart`

### `class ProjectWebLoadingStyle`

`packaging.web_loading_style` in the `.lmproject`: how a web build's plain HTML loading screen looks while the engine, the renderer and the game's assets download.

Empty fields fall back to the project: the background to the Icon Background, the title to the project name, the logo ([logoFromIcon]) to the project icon. [resolve] applies those fallbacks and replaces invalid values, so nothing unchecked reaches the generated CSS or HTML.

**Yapıcı Metotlar (Constructors):**

- `const ProjectWebLoadingStyle({this.background = '', this.gradient = '', this.accent = defaultAccent, this.text = defaultText, this.logo = logoFromIcon, this.tit...`
- `factory ProjectWebLoadingStyle.fromMap(Map<String, dynamic> map)`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const ResolvedWebLoadingStyle({required this.background, required this.gradient, required this.accent, required this.text, required this.logo, required this.tit...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

## `lib/src/formats/sequencer_data.dart`

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

## `lib/src/repositories/level_repository.dart`

### `class LuminaLevelRepository`

Bir projenin level `.lmas` kapsayıcılarını okur ve yazar; level'ın her anahtarını diskteki gibi korur. Engine `loadLevelBlueprint` / `saveLevelBlueprint` ekler (`package:lumina`, `lib/src/blueprint/level_blueprint_storage.dart`).

**Yapıcı Metotlar (Constructors):**

- `const LuminaLevelRepository(this.projectDir)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` | The project directory the level paths are relative to. |
| `load` | `LuminaLevelDocument? load(String relativePath)` | The level at [relativePath] (`contents/levels/L_Test.lmas`), or null when there is no such level. |
| `save` | `void save(LuminaLevelDocument level)` | Writes [level] to its path. |

## `lib/src/repositories/plugin_repository.dart`

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
| `errors` | `List<PluginScanError> errors` | `errors` alanını (field/property) ve ilişkili veriyi saklar. Aynı kökün iki klasörünün aynı eklenti adını taşıması `duplicateName` hatasıdır. |
| `shadowed` | `List<PluginShadow> shadowed` | Daha öncelikli bir kökteki aynı adlı eklentinin geçersiz kıldığı kopyalar (proje > kullanıcı > engine). Bilinçli bir davranıştır, hiçbir zaman hata değildir: editör bunu info düzeyinde loglar, kazanan eklentinin Plugin Manager kartında "Overrides the engine copy" yazar. |

### `class PluginShadow`

Daha öncelikli bir kökte aynı adlı eklenti yüklendiği için yüklenmeyen eklenti kopyası.

| Alan | Tür | Anlamı |
| :--- | :--- | :--- |
| `name` | `String` | İki kopyanın taşıdığı eklenti adı. |
| `winner` | `LuminaPluginDescriptor` | Yüklenen kopya. |
| `shadowedManifestPath` | `String` | Yüklenmeyen kopyanın `.lmplugin` dosyası. |
| `shadowedOrigin` | `PluginOrigin` | Yüklenmeyen kopyanın kökü. |

### `class PluginRepository`

`PluginRepository`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `roots` | `List<PluginScanRoot> roots` | `roots` alanını (field/property) ve ilişkili veriyi saklar. |
| `scanAll` | `Future<PluginScanResult> scanAll()` | `scanAll` işlemini gerçekleştirir. |
| `load` | `Future<LuminaPluginDescriptor> load(File manifest)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `loadInternal` | `Future<LuminaPluginDescriptor> loadInternal(File manifest, PluginOrigin ...` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. `in_process` / `process` dışındaki bir `isolation`'ı, Dart sınıf adı olmayan bir `process_class`'ı ve `process_class` adı veren bir editor modülü olmadan `"isolation": "process"`'i (`schemaViolation` tarama hatası olarak) reddeder. |

---

[Önceki: Matematik: birimler, eksenler ve dönüşler](math.md) | [Üst: lumina_core (saf Dart temeli)](index.md) | [Sonraki: Servisler](services.md)
