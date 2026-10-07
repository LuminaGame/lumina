[English](../../en/lumina_editor_data/services.md)

# Veri katmanı: use case'ler ve servisler

Editöre dönük veri katmanı, birinci bölüm: domain use case'leri (level kaydetme, asset içe aktarma, Dart kodu üretme) ve arkalarındaki servisler: asset referans grafiği, Dart kod üreteci, GLB servisi (engine'in GLB okuyucusu ve içe aktarma temizleyicisi) ve OBJ parser'ı, eklenti registry'si ve şablon üreteci ve thumbnail'lar. Proje input binder'ı engine runtime'ındadır ([Girdi](../lumina/input.md)). Saf servisler (otomatik kayıt zamanlayıcısı, engine logger, oyun ve level şablonları, TGA çözücü, host patcher, primitive GLB fabrikası, çalışma alanı ve veri yolları, build parmak izi ve önbelleği, glTF araçları ve diğerleri) `lumina_core`'dadır: bkz. [Servisler](../lumina_core/services.md). Dosya yolları `lumina_editor_data/` paket dizinine görelidir.

**Bu sayfada:**

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

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`String? validateProjectDir(String projectDir)`**: Shared input validation for the use-case layer. Returns an error message or null.
- **`String? validateLevelName(String levelName)`**: A level name must be a plain file stem: no separators, no parent references.

## `lib/src/domain/models/use_case_results.dart`

### `class SaveLevelResult`

Result of [SaveLevelUseCase]: where the `.lmas` level container landed on disk.

**Yapıcı Metotlar (Constructors):**
- `SaveLevelResult.failure(this.levelName, String this.error)`: `SaveLevelResult.failure(this.levelName, String this.error)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | `isSuccess` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelName` | `String levelName` | `levelName` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelFilePath` | `String? levelFilePath` | `levelFilePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorCount` | `int actorCount` | `actorCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `error` | `String? error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class GenerateDartCodeResult`

Result of [GenerateDartCodeUseCase]: the generated Dart files and the cleaned manifest.

**Yapıcı Metotlar (Constructors):**
- `GenerateDartCodeResult.failure(String this.error)`: `GenerateDartCodeResult.failure(String this.error)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | `isSuccess` alanını (field/property) ve ilişkili veriyi saklar. |
| `mainDartPath` | `String? mainDartPath` | `mainDartPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelDartPath` | `String? levelDartPath` | `levelDartPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `writtenFiles` | `List<String> writtenFiles` | `writtenFiles` alanını (field/property) ve ilişkili veriyi saklar. |
| `updatedProject` | `LuminaProject? updatedProject` | `updatedProject` alanını (field/property) ve ilişkili veriyi saklar. |
| `error` | `String? error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class ImportAssetResult`

Result of [ImportAssetUseCase]: the imported asset's `.lmas` description.

**Yapıcı Metotlar (Constructors):**
- `ImportAssetResult.failure(this.sourceFilePath, String this.error)`: `ImportAssetResult.failure(this.sourceFilePath, String this.error)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isSuccess` | `bool isSuccess` | `isSuccess` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceFilePath` | `String sourceFilePath` | `sourceFilePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `error` | `String? error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

## `lib/src/services/asset_reference_graph.dart`

### `class ResolvedReference`

`ResolvedReference`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `resolvedPath` | `String? resolvedPath` | `resolvedPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `broken` | `bool broken` | `broken` alanını (field/property) ve ilişkili veriyi saklar. |

### `class AssetReferenceGraph`

`AssetReferenceGraph`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `void build(List<RealAssetInfo> assets)` | Deklaratif alt nesne veya widget ağacını inşa eder. |
| `getAsset` | `RealAssetInfo? getAsset(String assetId)` | `Asset` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `dependenciesOf` | `List<RealAssetInfo> dependenciesOf(String assetId)` | `dependenciesOf` işlemini gerçekleştirir. |
| `referencersOf` | `List<RealAssetInfo> referencersOf(String assetId)` | `referencersOf` işlemini gerçekleştirir. |
| `dependencyClosure` | `Set<String> dependencyClosure(String assetId)` | `dependencyClosure` işlemini gerçekleştirir. |
| `resolve` | `ResolvedReference resolve(AssetReference ref)` | `resolve` işlemini gerçekleştirir. |

## `lib/src/services/assimp_import_service.dart`

### `class AssimpImportException`

Assimp'in dönüştüremediği bir model dosyası: `message` dosyayı ve Assimp'in gerekçesini adlandırır. Import bunu hata olarak loglar ve hiçbir şey yazmaz.

### `class AssimpImportResult`

Import hattı için dönüştürülmüş bir Collada, 3DS, PLY, DirectX veya STL dosyası: `glb` (bulunan her doku gömülü), `missingTextures` (`material`, `slot`, dosyanın yazdığı `path`, `file`) ve `embeddedTextures` (bulunan dosya adları).

### `abstract final class AssimpImportService`

FBX ve OBJ dışında (onların kendi servisleri var) Assimp'in okuduğu her 3D formatı → import hattı için GLB: Collada (`.dae`), 3DS, PLY, DirectX (`.x`) ve STL ([FlutterAssimp.importExtensions]). Asset deposu bunları bu servis üzerinden hazırlar (Content Browser import'u ve sürükle-bırak, klasör import'u, MCP `import_asset` aracı); dönüşüm kaynak dosyanın bulunduğu yerden yapılır, böylece dosyanın kendine göre gösterdiği her şey bulunur; hiçbir şey hazırlanmış bir kopyadan dönüştürülmez. Dokular sonra bir FBX'inkiler gibi bulunur ([FbxTextureLocator]: yazıldığı gibi, dosyaya göre klasörler ve dosya büyük/küçük harf fark etmeksizin, dosyanın klasöründe adıyla, Import penceresinin Textures Folder'ında ve alışılmış `Textures/` klasörlerinde) ve gömülür. Hiçbir yerde bulunamayan bir doku için Output Log'a onu adlandıran tek bir uyarı yazılır ve materyal onsuz içe aktarılır. Geometri, birimler ve eksenler Assimp'in okuduğu gibidir (Collada'nın `<unit>` ve `<up_axis>` değerlerini importer'ı uygular). Assimp'in okuyamadığı bir dosya import'u hatayla bitirir ve hiçbir asset yazmaz.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `handles` | `static bool handles(String path)` | [path] bu servis üzerinden mi içe aktarılır (FBX ve OBJ dışında bir Assimp formatı). |
| `convert` | `static Future<AssimpImportResult> convert(String path, {List<String> textureSearchDirs = const []})` | [convertSync]'i arka plan isolate'inde çalıştırır. |
| `convertSync` | `static AssimpImportResult convertSync(String path, {List<String> textureSearchDirs = const []})` | Assimp dosyayı okuyamazsa [AssimpImportException] fırlatır. |

## `lib/src/services/code_generator_service.dart`

### `class DartCodeGeneratorService`

`DartCodeGeneratorService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `generateActorRegistryDart` | `String generateActorRegistryDart(List<String> actorNames)` | Generates the actors.g.dart registry file. |
| `compileAndWriteActor` | `Future<bool> compileAndWriteActor(String projectPath, String assetName, ...` | Compiles a blueprint document into a project's lib/actors/ file. |
| `writeProjectInputDart` | `bool writeProjectInputDart(String projectPath, [ProjectInputSettings? settings])` | Proje ayarları veya manifestten lib/input/project_input.g.dart dosyasını üretip yazar. |

Üretilen seviyenin begin-play'i `LuminaWorldPartitionSubsystem`'i seviyenin `metadata.worldPartition` bölümüyle kaydeder (hücre boyutu, tick başına geçiş, başlangıç durumlarıyla data layer'lar), her aktörü partition'a ekler ve streaming kaynaklarını kaydeder. Bir seviye satırı `dataLayers: [<katman adı>, ...]` taşıyabilir (editör bunu henüz yazmaz; harita üreteci gibi araçlar yazar): üretilen kod o zaman aktörlerin `LuminaObjectKey` kimlikleriyle anahtarlanmış bir `dataLayersByActor` haritası tutar ve her ad için `partition.assignActorToLayer` çağırır; böylece yüklenmemiş ya da yalnızca yüklü katmanlar aktörlerinin tick almasını runtime'ın tanımladığı gibi engeller.

## `lib/src/services/obj_import_service.dart`

### `class MtlMaterial`

Bir Wavefront `.mtl` dosyasının tek bir `newmtl` bloğu: `name`, `diffuse` (`Kd`), `dissolve` (`d`), `opacity` (`d`, yoksa `1 - Tr`, yoksa 1), `diffuseMap` (`map_Kd`), `normalMap` (`norm`, `map_Bump` / `bump`), `alphaMap` (`map_d`), `specularMap` (`map_Ks`). Doku yolları yazıldığı gibidir, harita seçenekleri (`-bm 1`, `-o u v w`, `-clamp on`, …) çıkarılır; yol boşluk içerebilir.

### `class ObjImportResult`

Import hattı için dönüştürülmüş bir OBJ dosyası: `glb` (MTL değerleriyle materyaller, bulunan dokular gömülü), `materialLibraries` (`mtllib` adları), `missingMaterialLibraries`, `missingTextures` (MTL'nin yazdığı `path`, `file`, `uses`: onu isteyen materyal ve slot) ve `embeddedTextures`.

### `abstract final class ObjImportService`

Import hattı için OBJ → GLB. Asset deposu her `.obj`'yi bunun üzerinden hazırlar (Content Browser import'u ve sürükle-bırak, klasör import'u, MCP `import_asset` aracı, aynı dosyayı yeniden içe aktarmak); dönüşüm kaynak dosyanın kendi klasöründen yapılır, böylece `.mtl` dosyası ve dokuları bulunur. Geometriyi Assimp dönüştürür; MTL burada da okunur ve glTF materyallerine adlarıyla uygulanır:

- `Kd` → base colour; `d`, yalnızca `Tr` varsa `1 - Tr`, 1'in altındaysa → alfa ve `BLEND` (`blending : fade` olarak çizilir);
- `map_Kd` → base colour dokusu (renk faktörü beyaza döner), `map_Bump` / `bump` / `norm` → normal dokusu, `map_Ks` → specular dokusu (`specularMap`, reflectance olarak çizilir);
- `map_d` → base colour dokusunun alfası: `map_d` görüntüsü (alfa kanalı, yoksa parlaklığı) diffuse görüntüye işlenir, ikisi aynı dosyayı gösteriyorsa olduğu gibi kullanılır; bu alfa yalnızca tam saydam ve tam opak texel'lerden oluşuyorsa (kenar yumuşatmaya izin verilir) `MASK` (eşik 0.5), değilse `BLEND`.

`mtllib` adları önce OBJ'ye göre yazıldığı gibi (bu yazımla diskte yoksa klasörler ve dosya büyük/küçük harf fark etmeksizin), sonra OBJ'nin klasöründe büyük/küçük harf fark etmeksizin dosya adıyla (ardından Assimp gibi `<obj adı>.mtl`) çözülür; doku yolları FBX'teki gibi ([FbxTextureLocator]): yazıldığı gibi, OBJ'ye göre (aynı şekilde harf büyüklüğünden bağımsız), sonra OBJ'nin klasöründe, Import penceresinin Textures Folder'ında ve alışılmış `Textures/` klasörlerinde dosya adıyla. Hiçbir yerde bulunamayan bir materyal kütüphanesi veya doku için Output Log'a onu adlandıran tek bir uyarı yazılır; import onsuz devam eder. Hiçbir mesh'in kullanmadığı materyaller (Assimp'in `DefaultMaterial`'ı) atılır. Assimp dosyayı dönüştüremezse OBJ olduğu gibi hazırlanır.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isObj` | `static bool isObj(String path)` |  |
| `convert` | `static Future<ObjImportResult?> convert(String objPath, {List<String> textureSearchDirs = const []})` | [convertSync] arka plan isolate'inde. |
| `convertSync` | `static ObjImportResult? convertSync(String objPath, {List<String> textureSearchDirs = const []})` | Assimp dosyayı dönüştüremezse (köprü yüklü değil ya da OBJ okunamıyor) null. |
| `materialLibraries` | `static List<String> materialLibraries(String source)` | Bir OBJ [source]'unun `mtllib` adları, sırayla (ad boşluk içerebilir). |
| `locateMaterialLibrary` | `static File? locateMaterialLibrary(File objFile, String name)` | Bir `mtllib` [name]'inin gösterdiği dosya: OBJ'ye göre yazıldığı gibi (veya mutlak), klasörleri ve dosyası büyük/küçük harf fark etmeksizin ([FbxTextureLocator.findIgnoringCase]), sonra OBJ'nin klasöründe büyük/küçük harf fark etmeksizin dosya adıyla. |
| `parseMtl` | `static List<MtlMaterial> parseMtl(String source)` | Bir MTL [source]'unun materyalleri. |

## `lib/src/services/obj_parser_service.dart`

### `class ObjParserService`

Service for parsing Wavefront OBJ 3D model geometry.

## `lib/src/services/plugin_registry_service.dart`

### `enum PluginIssueType`

`PluginIssueType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class PluginIssue`

`PluginIssue`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PluginIssue(this.type, this.message)`: `PluginIssue(this.type, this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `type` | `PluginIssueType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |

### `class PluginEntry`

`PluginEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `descriptor` | `LuminaPluginDescriptor descriptor` | `descriptor` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `restartPending` | `bool restartPending` | `restartPending` alanını (field/property) ve ilişkili veriyi saklar. |
| `issues` | `List<PluginIssue> issues` | `issues` alanını (field/property) ve ilişkili veriyi saklar. |
| `overrides` | `List<PluginShadow> overrides` | Bu eklentinin geçersiz kıldığı, daha düşük öncelikli köklerdeki aynı adlı kopyalar (Plugin Manager kartında ve `list_plugins` içinde `overrides` olarak görünür). |

### `class PluginResolution`

`PluginResolution`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PluginResolution(this.resolvedPlugins, this.issues)`: `PluginResolution(this.resolvedPlugins, this.issues)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `resolvedPlugins` | `List<LuminaPluginDescriptor> resolvedPlugins` | `resolvedPlugins` alanını (field/property) ve ilişkili veriyi saklar. |
| `issues` | `List<PluginIssue> issues` | `issues` alanını (field/property) ve ilişkili veriyi saklar. |

### `class EnableResult`

`EnableResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `restartRequired` | `bool restartRequired` | `restartRequired` alanını (field/property) ve ilişkili veriyi saklar. |
| `issues` | `List<PluginIssue> issues` | `issues` alanını (field/property) ve ilişkili veriyi saklar. |

### `class PluginRegistryService`

`PluginRegistryService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `repo` | `PluginRepository repo` | `repo` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectRepo` | `ProjectRepository projectRepo` | `projectRepo` alanını (field/property) ve ilişkili veriyi saklar. |
| `entries` | `List<PluginEntry> get entries` | `entries` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `scanErrors` | `List<PluginScanError> get scanErrors` | `scanErrors` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `shadowed` | `List<PluginShadow> get shadowed` | Daha öncelikli bir kökteki aynı adlı eklentinin geçersiz kıldığı eklenti kopyaları; bilgi amaçlıdır, tarama hatası değildir. |
| `refresh` | `Future<void> refresh()` | `refresh` işlemini gerçekleştirir. |
| `initialize` | `Future<void> initialize(String projectDirPath)` | `initialize` işlemini gerçekleştirir. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | `resolve` işlemini gerçekleştirir. |
| `project` | `LuminaProject? get project` | Son yüklenen ya da kaydedilen haliyle açık proje. |
| `isolationOf` | `PluginIsolation isolationOf(String name)` | `name` eklentisinin açık projede nerede çalıştığı (`LuminaPluginDescriptor.effectiveIsolation`): `plugin_isolation` geçersiz kılması, yoksa manifest'i; process kısmı olmayan (ya da bilinmeyen) bir eklenti süreç içinde çalışır. |
| `isolationOverrideOf` | `PluginIsolation? isolationOverrideOf(String name)` | Açık projenin `name` için geçersiz kılması ya da null. |
| `setIsolationOverride` | `Future<bool> setIsolationOverride(String name, PluginIsolation? isolation)` | Projenin geçersiz kılmasını ayarlar (null kaldırır) ve `.lmproject`'i kaydeder; etkin eklentinin etkin yalıtımı değiştiyse true döner ve eklentiyi `restartPending` olarak işaretler. |

## `lib/src/services/plugin_template_generator_service.dart`

### `enum PluginTemplateType`

`PluginTemplateType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class PluginTemplateSpec`

`PluginTemplateSpec`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `templateType` | `PluginTemplateType templateType` | `templateType` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `friendlyName` | `String friendlyName` | `friendlyName` alanını (field/property) ve ilişkili veriyi saklar. |
| `author` | `String author` | `author` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `String category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `isolated` | `final bool isolated` | Yalıtılmış bir eklenti iskeleti üretir: `lib/src/<name>_process.dart` (`<Pascal>Process extends LuminaPluginProcess`: bir menü komutu, bir `ping` handler'ı, bildirimsel bir panel ve importer şablonunda importer'ı), panelinden `processChannel` üzerinden `ping` çağıran bir UI kabuğu, `test/<name>_process_test.dart` + `test/<name>_plugin_test.dart` ve manifest'te `"isolation": "process"` + `"process_class"`. Yalnızca içerik eklentisi yalıtılamaz (üretim başarısız olur). Kaynaklar `plugin_template/isolated_plugin_sources.dart`'tan gelir (süreç içi şablonlar: `plugin_template/code_plugin_sources.dart`). |

### `class PluginGenerationResult`

`PluginGenerationResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `success` | `bool success` | `success` alanını (field/property) ve ilişkili veriyi saklar. |
| `pluginDir` | `Directory? pluginDir` | `pluginDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `descriptor` | `LuminaPluginDescriptor? descriptor` | `descriptor` alanını (field/property) ve ilişkili veriyi saklar. |
| `log` | `List<String> log` | `log` alanını (field/property) ve ilişkili veriyi saklar. |
| `failureOutput` | `String? failureOutput` | `failureOutput` alanını (field/property) ve ilişkili veriyi saklar. |

### `class PluginTemplateGeneratorService`

`PluginTemplateGeneratorService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectRoot` | `Directory projectRoot` | `projectRoot` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorApiRoot` | `Directory editorApiRoot` | `editorApiRoot` alanını (field/property) ve ilişkili veriyi saklar. |
| `runner` | `ProcessRunner runner` | `runner` alanını (field/property) ve ilişkili veriyi saklar. |
| `nameToFriendly` | `static String nameToFriendly(String name)` | `nameToFriendly` işlemini gerçekleştirir. |
| `nameToPascal` | `static String nameToPascal(String name)` | `nameToPascal` işlemini gerçekleştirir. |
| `generate` | `Future<PluginGenerationResult> generate(PluginTemplateSpec spec)` | `generate` işlemini gerçekleştirir. |

## `lib/src/services/thumbnail_service.dart`

### `class ThumbnailService`

`ThumbnailService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `writeThumbnailCache` | `void writeThumbnailCache(String lmasPath, Uint8List png)` | `writeThumbnailCache` işlemini gerçekleştirir. |
| `readThumbnailCache` | `Uint8List? readThumbnailCache(String lmasPath)` | `readThumbnailCache` işlemini gerçekleştirir. |

## `lib/src/services/glb_parser_service.dart`

### `class GlbParserService`

`GlbParserService`: editörün GLB servisi. `parseGlb`, mesh verisini lumina_core'un `GlbReader`'ı (modeller [lumina_core servisleri](../lumina_core/services-continued.md) sayfasında), engine'in çözücüleri (`LuminaGlbLoader.decoders`: Filament'in Draco çözücüsü ve platform görüntü codec'i) ve `prepare` olarak bu servisin temizleyicisiyle okur. Temizleyici (`convertGlbTgaToPng`, `convertGlbTgaToPngAsync`, `inspectImageWork`) TGA dokuları PNG'ye çevirir, dış görüntüleri gömer, `defaultMaxTextureSize` üstündeki dokuları küçültür ve skin'leri dört normalize etkiye indirir; çıktı sürümü `sanitizerVersion`'dır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `parseGlb` | `static Future<GlbMeshData?> parseGlb(Uint8List bytes)` | Temizleyiciden sonra okunan GLB'nin ya da onu saran `.lmas`'ın mesh verisi. |
| `convertGlbTgaToPng` | `static Uint8List convertGlbTgaToPng(Uint8List glbBytes, {List<String>? searchDirs, int maxTextureSize})` | Temizlenmiş GLB byte'ları. |
| `convertGlbTgaToPngAsync` | `static Future<Uint8List> convertGlbTgaToPngAsync(Uint8List glbBytes, {List<String>? searchDirs, int maxTextureSize})` | Görüntü çözmek gerektiğinde aynısı, arka plan isolate'inde. |
| `inspectImageWork` | `static ({bool needsDecoding, bool selfContained}) inspectImageWork(Uint8List glbBytes, {int maxTextureSize})` | Temizlemenin maliyeti, yalnızca görüntü başlıklarından okunur. |

---

[Önceki: lumina_editor_data (editör veri katmanı)](index.md) | [Üst: lumina_editor_data (editör veri katmanı)](index.md) | [Sonraki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)](services-continued.md)
