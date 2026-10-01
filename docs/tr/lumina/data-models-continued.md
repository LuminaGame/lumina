[English](../../en/lumina/data-models-continued.md)

# Veri katmanı: modeller ve repository'ler (devamı)

Veri katmanı: modeller ve repository'ler sayfasının devamı: `lib/data/models/`, `lib/data/repositories/`, `lib/data/repositories/asset_repository/` altındaki diğer public dosyalar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/data/models/lumina_asset_summary.dart`](#libdatamodelslumina_asset_summarydart)
- [`lib/data/models/lumina_level_document.dart`](#libdatamodelslumina_level_documentdart)
- [`lib/data/models/project_web_loading_style.dart`](#libdatamodelsproject_web_loading_styledart)
- [`lib/data/repositories/asset_repository/file_operations.dart`](#libdatarepositoriesasset_repositoryfile_operationsdart)
- [`lib/data/repositories/asset_repository/mesh_thumbnail_geometry.dart`](#libdatarepositoriesasset_repositorymesh_thumbnail_geometrydart)
- [`lib/data/repositories/level_repository.dart`](#libdatarepositorieslevel_repositorydart)

## `lib/data/models/lumina_asset_summary.dart`

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

## `lib/data/models/lumina_level_document.dart`

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
| `levelBlueprint` | `LuminaLevelBlueprintDocument get levelBlueprint` | The level's Blueprint: an empty graph when none is stored. |
| `levelBlueprint` | `set levelBlueprint(LuminaLevelBlueprintDocument? value)` | Stores [value] under `metadata.levelBlueprint`; an empty Blueprint removes the key, so a level without a script stays as it was. |
| `hasLevelBlueprint` | `bool get hasLevelBlueprint` | Whether the level carries a Blueprint. |
| `levelActorRefs` | `List<LuminaBlueprintLevelActorRef> get levelActorRefs` | The placed actors a Level Blueprint refers to by name. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `encode` | `String encode()` |  |

## `lib/data/models/project_web_loading_style.dart`

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

## `lib/data/repositories/asset_repository/file_operations.dart`

### `class AssetMigrateEntry`

One file of a Migrate: its `contents/`-relative path, size, whether the target already has it, and whether this run copied it.

**Yapıcı Metotlar (Constructors):**

- `const AssetMigrateEntry({required this.relativePath, required this.bytes, required this.conflict, this.copied = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` |  |
| `bytes` | `final int bytes` |  |
| `conflict` | `final bool conflict` |  |
| `copied` | `final bool copied` |  |

## `lib/data/repositories/asset_repository/mesh_thumbnail_geometry.dart`

### `class MeshThumbnailGeometry`

A mesh's thumbnail drawing, worked out without `dart:ui` rendering so it can be computed in a background isolate: the triangles of the isometric projection [AssetRepository] draws, already sorted back to front, each as three screen points in a 128 px canvas and one shaded ARGB colour.

**Yapıcı Metotlar (Constructors):**

- `const MeshThumbnailGeometry(this.points, this.colors)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `points` | `final Float64List points` | `x0, y0, x1, y1, x2, y2` per triangle. |
| `colors` | `final Uint32List colors` | One opaque ARGB colour per triangle. |
| `triangleCount` | `int get triangleCount` |  |
| `forPayload` | `static Future<MeshThumbnailGeometry?> forPayload(AssetType type, Uint8List? payload) async` | The geometry of [type]'s thumbnail drawn from [payload] (a GLB, or OBJ text): null when the type does not draw its mesh or the payload holds none, as the thumbnail then falls back to the type's badge. |
| `fromMesh` | `static MeshThumbnailGeometry fromMesh(GlbMeshData glb)` | Projects [glb] isometrically into the thumbnail (at most ~5000 triangles), shades each triangle by a fixed light and colours it from its vertex colours or the mesh's base colour. |

## `lib/data/repositories/asset_repository/imported_material.dart`

### `String buildImportedMaterialSource({name, baseColor, textureSlots, metallic, roughness, emissive, doubleSided, alphaMode, alphaCutoff})`

İçe aktarılmış bir PBR materyalin Filament `.mat` kaynağı: glTF faktörleri sabit olarak gömülür, her doku slotu
(`baseColorMap`, `normalMap`, `metallicRoughnessMap` (roughness G, metallic B), `occlusionMap`, `emissiveMap`,
`specularMap`) için bir `sampler2d`, normal `prepareMaterial`'dan önce yazılır. glTF'in `doubleSided`, `alphaMode` ve
`alphaCutoff` alanları başlık anahtarları olur ve gltfio'nun aynı dosyayı çizdiği gibi çizilir: `doubleSided : true` (iki
yüz, culling kapalı); `MASK` → `blending : masked`, `maskThreshold` = `alphaCutoff` (varsayılan 0.5); `BLEND` →
`blending : fade`, glTF'in düz alfası (`baseColorFactor.a` × base color dokusunun alfası) fragment'ta renge
premultiply edilir, çift yüzlü bir `BLEND` materyal iki geçişte çizilir (`transparency : twoPassesTwoSides`). `OPAQUE`
tek yüzlü materyaller matc varsayılanlarında kalır (opak, arka yüzler cull edilir). Dokulu bir materyal `flipUV : false`
bildirir: mesh'in glTF doku koordinatları (v = 0 görüntünün üstünde) gltfio'nun kendi materyallerindeki gibi olduğu gibi
örneklenir; matc'nin varsayılanı `flipUV : true` dokuyu ters çizerdi. lumina'nın glTF / FBX / OBJ
import'u (Assimp formatları önce glTF'e çevrilir) ve importer eklentileri aynı üreticiyi kullanır; böylece içe aktarılan
bir materyal kimin ürettiğinden bağımsız aynıdır. Bu anahtarlar yazılmadan önce içe aktarılmış materyal asset'leri eski
kaynaklarını korur; modeli yeniden içe aktarmak yenisini yazar. `flipUV` da buna dahildir: onsuz içe aktarılmış bir
materyal derlendiğinde dokularını ters çizer; Assimp'in V çevirmesi düzeltilmeden önce içe aktarılmış bir FBX / OBJ /
Collada / 3DS / PLY / X mesh'i V-yukarı koordinatlar taşır (kendi dokuları ters); modeli yeniden içe aktarın.

### `class ImportedMaterial`

Bir importer'ın ürettiği materyal: `name`, `baseColor` (RGBA), `metallic`, `roughness`, `emissive` (RGB), `textures`
(her slot için mevcut bir doku asset'ine bir `AssetReference`), `doubleSided`, `alphaMode` (`OPAQUE` / `MASK` /
`BLEND`), `alphaCutoff` ve ek `metadata`. `materialSource()` `.mat` kaynağını,
`toAsset({assetId})` glTF import'unun yazdığı metadata anahtarlarıyla (`baseColor` "r,g,b,a", `metallic`,
`roughness`, `emissive` "r,g,b", `doubleSided`, `alphaMode`, `MASK` için `alphaCutoff`), doku referanslarıyla ve verilmezse yeni bir id ile `filamat` `LuminaAsset`'ini
döndürür. Unreal Engine importer eklentisi bağımsız materyal import'larını bununla yazar.

## `lib/data/repositories/level_repository.dart`

### `class LuminaLevelRepository`

Reads and writes a project's level `.lmas` containers: the whole document, or only its Level Blueprint, keeping every other key of the level as it is on disk.

**Yapıcı Metotlar (Constructors):**

- `const LuminaLevelRepository(this.projectDir)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` | The project directory the level paths are relative to. |
| `load` | `LuminaLevelDocument? load(String relativePath)` | The level at [relativePath] (`contents/levels/L_Test.lmas`), or null when there is no such level. |
| `save` | `void save(LuminaLevelDocument level)` | Writes [level] to its path. |
| `loadLevelBlueprint` | `LuminaLevelBlueprintDocument loadLevelBlueprint(String relativePath)` | The Level Blueprint of [relativePath]; an empty graph when the level has none (or does not exist yet). |
| `saveLevelBlueprint` | `LuminaLevelDocument saveLevelBlueprint(LuminaLevelBlueprintDocument blueprint)` | Stores [blueprint] in its level (`metadata.levelBlueprint`), creating a level container when none exists. Returns the saved level. |

---

[Önceki: Veri katmanı: modeller ve repository'ler](data-models.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: lumina_editor_api](../lumina_editor_api/index.md)
