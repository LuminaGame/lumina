[English](../../en/lumina/data-models.md)

# Veri katmanı: modeller ve repository'ler

Editöre dönük veri katmanı, ikinci bölüm: engine'e ya da native kütüphanelere ihtiyaç duyan repository'ler (küçük resimli ve içe aktarmalı asset'ler, koleksiyonlar, projeler). Kalıcı modellerin kendileri (`.lmas` asset'leri, `.lmproject` manifest'i ve ayarları, level dokümanları, eklenti tanımları, landscape ve sequencer verisi, son projeler) ile level ve eklenti repository'leri saf Dart'tır ve `lumina_core`'dadır: bkz. [Dosya formatları ve repository'ler](../lumina_core/formats.md). Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/data/repositories/asset_repository.dart`](#libdatarepositoriesasset_repositorydart)
- [`lib/data/repositories/collections_repository.dart`](#libdatarepositoriescollections_repositorydart)
- [`lib/data/repositories/project_repository.dart`](#libdatarepositoriesproject_repositorydart)

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
| `updateEngineVersion` | `Future<String?> updateEngineVersion(String projectDir, String version) async` | [projectDir] içindeki `.lmproject` dosyasının `engine_version` alanını [version] yapar, diğer alanlara dokunmaz. Değiştiyse önceki değeri döner; zaten [version] ise ya da okunur bir manifest yoksa null. |
| `saveProject` | `Future<void> saveProject(LuminaProject project, String projectDirPath)` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

---

[Önceki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)](data-services-continued-3.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: modeller ve repository'ler (devamı)](data-models-continued.md)
