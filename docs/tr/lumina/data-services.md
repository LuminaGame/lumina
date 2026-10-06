[English](../../en/lumina/data-services.md)

# Veri katmanı: use case'ler ve servisler

Editöre dönük veri katmanı, birinci bölüm: domain use case'leri (level kaydetme, asset içe aktarma, Dart kodu üretme) ve arkalarındaki servisler: asset referans grafiği, otomatik kayıt, Dart kod üreteci, engine logger, oyun ve level şablonları, GLB, OBJ ve TGA parser'ları, eklenti registry'si, şablon üreteci ve host patcher, primitive GLB fabrikası, proje input binder'ı ve thumbnail'lar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/domain/use_cases/generate_dart_code_use_case.dart`](#libdomainuse_casesgenerate_dart_code_use_casedart)
- [`lib/domain/use_cases/import_asset_use_case.dart`](#libdomainuse_casesimport_asset_use_casedart)
- [`lib/domain/use_cases/save_level_use_case.dart`](#libdomainuse_casessave_level_use_casedart)
- [`lib/domain/use_cases/use_case_validation.dart`](#libdomainuse_casesuse_case_validationdart)
- [`lib/domain/models/use_case_results.dart`](#libdomainmodelsuse_case_resultsdart)
- [`lib/data/services/asset_reference_graph.dart`](#libdataservicesasset_reference_graphdart)
- [`lib/data/services/assimp_import_service.dart`](#libdataservicesassimp_import_servicedart)
- [`lib/data/services/auto_save_timer_service.dart`](#libdataservicesauto_save_timer_servicedart)
- [`lib/data/services/code_generator_service.dart`](#libdataservicescode_generator_servicedart)
- [`lib/data/services/engine_logger_service.dart`](#libdataservicesengine_logger_servicedart)
- [`lib/data/services/game_template_service.dart`](#libdataservicesgame_template_servicedart)
- [`lib/data/services/glb_parser_service.dart`](#libdataservicesglb_parser_servicedart)
- [`lib/data/services/level_template_service.dart`](#libdataserviceslevel_template_servicedart)
- [`lib/data/services/obj_import_service.dart`](#libdataservicesobj_import_servicedart)
- [`lib/data/services/obj_parser_service.dart`](#libdataservicesobj_parser_servicedart)
- [`lib/data/services/plugin_host_patcher_service.dart`](#libdataservicesplugin_host_patcher_servicedart)
- [`lib/data/services/plugin_registry_service.dart`](#libdataservicesplugin_registry_servicedart)
- [`lib/data/services/plugin_template_generator_service.dart`](#libdataservicesplugin_template_generator_servicedart)
- [`lib/data/services/primitive_glb_factory.dart`](#libdataservicesprimitive_glb_factorydart)
- [`lib/data/services/project_input_binder.dart`](#libdataservicesproject_input_binderdart)
- [`lib/data/services/tga_decoder_service.dart`](#libdataservicestga_decoder_servicedart)
- [`lib/data/services/thumbnail_service.dart`](#libdataservicesthumbnail_servicedart)

## `lib/domain/use_cases/generate_dart_code_use_case.dart`

### `class GenerateDartCodeUseCase`

Generates the live declarative Dart code for a level (`lib/main.dart` + `lib/levels/<levelName>.dart`) via [DartCodeGeneratorService] and, when a [LuminaProject] is supplied, clears its dirty flag and stamps `lastCodeGeneratedTimestamp` through [ProjectRepository.saveProject].

## `lib/domain/use_cases/import_asset_use_case.dart`

### `class ImportAssetUseCase`

Imports an external model/texture/audio file into a project's `contents/` tree through [AssetRepository.importExternalFile] (stage → convert → resolve paths → emit `.lmas` family). Unsupported formats and thrown pipeline errors become a failure result.

## `lib/domain/use_cases/save_level_use_case.dart`

### `class SaveLevelUseCase`

Writes the active level as a `contents/levels/<levelName>.lmas` JSON container.  The container is exactly what Lumina Studio writes on Save Level: `assetId` (`level_<name>`), `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and `metadata.actors` — the actor maps (`EditorActorNode.toMap()`) are passed through untouched. Validation and I/O failures are reported in the result, never thrown.

## `lib/domain/use_cases/use_case_validation.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`String? validateProjectDir(String projectDir)`**: Shared input validation for the use-case layer. Returns an error message or null.
- **`String? validateLevelName(String levelName)`**: A level name must be a plain file stem: no separators, no parent references.

## `lib/domain/models/use_case_results.dart`

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

## `lib/data/services/asset_reference_graph.dart`

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

## `lib/data/services/assimp_import_service.dart`

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

## `lib/data/services/auto_save_timer_service.dart`

### `class AutoSaveTimerService`

`AutoSaveTimerService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onPerformSave` | `SaveCallback onPerformSave` | `onPerformSave` alanını (field/property) ve ilişkili veriyi saklar. |
| `stop` | `void stop()` | `stop` işlemini gerçekleştirir. |
| `checkAndExecuteAutoSave` | `Future<LuminaProject> checkAndExecuteAutoSave(LuminaProject project)` | `checkAndExecuteAutoSave` işlemini gerçekleştirir. |

## `lib/data/services/code_generator_service.dart`

### `class DartCodeGeneratorService`

`DartCodeGeneratorService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `generateActorRegistryDart` | `String generateActorRegistryDart(List<String> actorNames)` | Generates the actors.g.dart registry file. |
| `compileAndWriteActor` | `Future<bool> compileAndWriteActor(String projectPath, String assetName, ...` | Compiles a blueprint document into a project's lib/actors/ file. |
| `writeProjectInputDart` | `bool writeProjectInputDart(String projectPath, [ProjectInputSettings? settings])` | Proje ayarları veya manifestten lib/input/project_input.g.dart dosyasını üretip yazar. |

Üretilen seviyenin begin-play'i `LuminaWorldPartitionSubsystem`'i seviyenin `metadata.worldPartition` bölümüyle kaydeder (hücre boyutu, tick başına geçiş, başlangıç durumlarıyla data layer'lar), her aktörü partition'a ekler ve streaming kaynaklarını kaydeder. Bir seviye satırı `dataLayers: [<katman adı>, ...]` taşıyabilir (editör bunu henüz yazmaz; harita üreteci gibi araçlar yazar): üretilen kod o zaman aktörlerin `ValueKey` kimlikleriyle anahtarlanmış bir `dataLayersByActor` haritası tutar ve her ad için `partition.assignActorToLayer` çağırır; böylece yüklenmemiş ya da yalnızca yüklü katmanlar aktörlerinin tick almasını runtime'ın tanımladığı gibi engeller.

## `lib/data/services/engine_logger_service.dart`

### `class EngineLogEntry`

`EngineLogEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EngineLogEntry.fromJson(Map<String, dynamic> json)`: `EngineLogEntry.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timestamp` | `String timestamp` | `timestamp` alanını (field/property) ve ilişkili veriyi saklar. |
| `level` | `String level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `source` | `String source` | `source` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class EngineLoggerService`

`EngineLoggerService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Yapıcı Metotlar (Constructors):**
- `EngineLoggerService()`: `EngineLoggerService()` nesnesini ilklendirir.
- `EngineLoggerService._internal()`: `EngineLoggerService._internal()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `logStream` | `Stream<EngineLogEntry> get logStream` | `logStream` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `logs` | `List<EngineLogEntry> get logs` | `logs` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `clear` | `void clear()` | Koleksiyon veya tampon içeriğini tamamen temizler. |

## `lib/data/services/game_template_service.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Map<String, dynamic> luminaTemplateSunActor() => _sun()`**: The directional sun actor map shared by the game and level templates.
- **`Map<String, dynamic> luminaTemplateSkyActor() => _sky()`**: The sky/atmosphere actor map shared by the game and level templates.

### `enum GameTemplateKind`

Which runtime pawn shape a template scaffolds.

### `class GameTemplate`

One entry of the shared template catalog.  This is the single source of truth both the launcher UI and `ProjectRepository.createProjectStream` read: the chip label and blurb, the actors seeded into `contents/levels/L_DefaultLevel.lmas`, the input actions and mapping context written into the manifest, and whether user-owned character / game-mode source is generated.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | `description` alanını (field/property) ve ilişkili veriyi saklar. |
| `icon` | `String icon` | Short icon hint the launcher maps to a shadcn icon. |
| `kind` | `GameTemplateKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelActors` | `List<Map<String, dynamic>> get levelActors` | A fresh, independently mutable copy of the seeded actor maps (`EditorActorNode.toMap()` shape). |
| `input` | `ProjectInputSettings get input` | A fresh copy of the input actions and mapping contexts for the manifest. |
| `generatesGameSource` | `bool get generatesGameSource` | Whether this template writes `lib/pawns/…` and `lib/game/…` source the user owns. |
| `classPrefix` | `static String classPrefix(String projectName)` | `my_first_game` → `MyFirstGame`. |
| `characterClass` | `String characterClass(String projectName)` | Dart class name of the generated character for [projectName]. |
| `gameModeClass` | `String gameModeClass(String projectName)` | Dart class name of the generated game mode, or the engine default for the blank template. This is what lands in [ProjectMapsAndModes.defaultGameMode]. |
| `characterPath` | `String characterPath(String projectName)` | `lib/`-relative path of the generated character file. |
| `gameModePath` | `String gameModePath(String projectName)` | `lib/`-relative path of the generated game mode file. |
| `manifestStepMessages` | `List<String> manifestStepMessages(String projectName)` | Human-readable step lines the creation progress log names for this template, so the user sees what is actually being written. |

### `class GameTemplateCatalog`

The three templates offered by the launcher.

**Yapıcı Metotlar (Constructors):**
- `GameTemplateCatalog._()`: `GameTemplateCatalog._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `byId` | `static GameTemplate byId(String? id)` | Resolves [id] to a template, tolerating the legacy `'Blank 3D'` label and unknown ids (both fall back to [blank3d]). |

## `lib/data/services/glb_parser_service.dart`

### `enum GlbNodeType`

`GlbNodeType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class GlbNode`

`GlbNode`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `index` | `int index` | `index` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshIndex` | `int? meshIndex` | `meshIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshName` | `String? meshName` | `meshName` alanını (field/property) ve ilişkili veriyi saklar. |
| `primitiveCount` | `int primitiveCount` | `primitiveCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `children` | `List<GlbNode> children` | `children` alanını (field/property) ve ilişkili veriyi saklar. |
| `translation` | `List<double>? translation` | `translation` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double>? rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double>? scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `GlbNodeType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `positions` | `List<double> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `List<int> indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `isVisible` | `bool isVisible` | `isVisible` alanını (field/property) ve ilişkili veriyi saklar. |
| `totalDescendantCount` | `int get totalDescendantCount` | `totalDescendantCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `directChildCount` | `int get directChildCount` | `directChildCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `getAllDescendantNodeIndices` | `List<int> getAllDescendantNodeIndices()` | `AllDescendantNodeIndices` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getAllDescendantPositions` | `List<double> getAllDescendantPositions()` | `AllDescendantPositions` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getAllDescendantIndices` | `List<int> getAllDescendantIndices()` | `AllDescendantIndices` bilgisini veya alt nesnesini sorgulayıp döndürür. |

### `class GlbSubPrimitive`

`GlbSubPrimitive`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `List<int> indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexColors` | `Uint8List? vertexColors` | `vertexColors` alanını (field/property) ve ilişkili veriyi saklar. |
| `baseColor` | `List<double> baseColor` | `baseColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialName` | `String? materialName` | `materialName` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialIndex` | `int? materialIndex` | `materialIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class GlbMorphTarget`

`GlbMorphTarget`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `positionDeltas` | `List<double> positionDeltas` | `positionDeltas` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class GlbAnimationChannel`

`GlbAnimationChannel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `nodeIndex` | `int nodeIndex` | `nodeIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `nodeName` | `String nodeName` | `nodeName` alanını (field/property) ve ilişkili veriyi saklar. |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyframeTimes` | `List<double> keyframeTimes` | `keyframeTimes` alanını (field/property) ve ilişkili veriyi saklar. |
| `values` | `List<double> values` | `values` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolation` | `String interpolation` | `interpolation` alanını (field/property) ve ilişkili veriyi saklar. |

### `class GlbAnimationClip`

`GlbAnimationClip`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `animatedNodeIndices` | `animatedNodeIndices` | `animatedNodeIndices` alanını (field/property) ve ilişkili veriyi saklar. |
| `channelTargetPaths` | `channelTargetPaths` | `channelTargetPaths` alanını (field/property) ve ilişkili veriyi saklar. |
| `channels` | `List<GlbAnimationChannel> channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `compositeKeyframeTimes` | `List<double> compositeKeyframeTimes` | `compositeKeyframeTimes` alanını (field/property) ve ilişkili veriyi saklar. |

### `class GlbMeshData`

`GlbMeshData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `subPrimitives` | `List<GlbSubPrimitive> subPrimitives` | `subPrimitives` alanını (field/property) ve ilişkili veriyi saklar. |
| `positions` | `List<double> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `List<int> indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `uvs` | `List<double> uvs` | `uvs` alanını (field/property) ve ilişkili veriyi saklar. |
| `minBounds` | `List<double> minBounds` | `minBounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxBounds` | `List<double> maxBounds` | `maxBounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `baseColor` | `List<double> baseColor` | `baseColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexColors` | `vertexColors` | `vertexColors` alanını (field/property) ve ilişkili veriyi saklar. |
| `rawPayload` | `Uint8List? rawPayload` | `rawPayload` alanını (field/property) ve ilişkili veriyi saklar. |
| `rootNodes` | `List<GlbNode> rootNodes` | `rootNodes` alanını (field/property) ve ilişkili veriyi saklar. |
| `allNodes` | `List<GlbNode> allNodes` | `allNodes` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialNames` | `List<String> materialNames` | `materialNames` alanını (field/property) ve ilişkili veriyi saklar. |
| `skeletonJointIndices` | `Set<int> skeletonJointIndices` | `skeletonJointIndices` alanını (field/property) ve ilişkili veriyi saklar. |
| `morphTargets` | `List<GlbMorphTarget> morphTargets` | `morphTargets` alanını (field/property) ve ilişkili veriyi saklar. |
| `jointsPerVertex` | `Uint16List? jointsPerVertex` | `jointsPerVertex` alanını (field/property) ve ilişkili veriyi saklar. |
| `weightsPerVertex` | `Float32List? weightsPerVertex` | `weightsPerVertex` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxInfluences` | `int maxInfluences` | `maxInfluences` alanını (field/property) ve ilişkili veriyi saklar. |
| `animations` | `List<GlbAnimationClip> animations` | `animations` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneCount` | `int get boneCount` | `boneCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `animatedNodeIndices` | `Set<int> get animatedNodeIndices` | `animatedNodeIndices` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class _GlbDecodedImage`

`_GlbDecodedImage`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_GlbDecodedImage(this.width, this.height, this.rawPixels)`: `_GlbDecodedImage(this.width, this.height, this.rawPixels)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `rawPixels` | `Uint8List rawPixels` | `rawPixels` alanını (field/property) ve ilişkili veriyi saklar. |
| `sample` | `List<int> sample(double u, double v)` | `sample` işlemini gerçekleştirir. |

### `class _NodeTransform`

`_NodeTransform`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_NodeTransform(this.translation, this.rotation, this.scale)`: `_NodeTransform(this.translation, this.rotation, this.scale)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `translation` | `List<double> translation` | `translation` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double> rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double> scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |

### `class GlbParserService`

`GlbParserService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `parseGlb` | `static Future<GlbMeshData?> parseGlb(Uint8List bytes)` | `parseGlb` işlemini gerçekleştirir. |

## `lib/data/services/level_template_service.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Map<String, dynamic> defaultWorldPartitionSection()`**: A fresh `metadata.worldPartition` section carrying the runtime's own defaults and no data layers (a level authors those itself).

### `class LevelTemplate`

One entry in the New Level dialog.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `description` | `String description` | One line describing exactly what this template seeds — shown in the dialog, so it must stay truthful. |
| `levelActors` | `List<Map<String, dynamic>> get levelActors` | Fresh actor maps (`EditorActorNode.toMap()` shape) for a new level. |
| `worldPartition` | `Map<String, dynamic>? get worldPartition` | Fresh `metadata.worldPartition` section, or null when the template does not author one (`Empty`, `Default`). |

### `class LevelTemplateCatalog`

The templates `File → New Level…` offers, in dialog order.

**Yapıcı Metotlar (Constructors):**
- `LevelTemplateCatalog._()`: `LevelTemplateCatalog._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `byId` | `static LevelTemplate byId(String? id)` | Resolves [id] to a template; unknown ids fall back to [standard]. |

## `lib/data/services/obj_import_service.dart`

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

## `lib/data/services/obj_parser_service.dart`

### `class ObjParserService`

Service for parsing Wavefront OBJ 3D model geometry.

## `lib/data/services/plugin_host_patcher_service.dart`

### `class PluginHostPatcherService`

`PluginHostPatcherService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `patchPubspec` | `Future<void> patchPubspec(Directory hostRoot, List<LuminaPluginDescripto...` | `patchPubspec` işlemini gerçekleştirir. |
| `generateRegistrar` | `Future<void> generateRegistrar(Directory hostRoot, List<LuminaPluginDesc...` | `generateRegistrar` işlemini gerçekleştirir. |
| `registrarSource` | `String registrarSource(List<LuminaPluginDescriptor> enabledCodePlugins)` | Registrar kütüphanesi: `kEnabledPlugins` (editor modülü başına bir örnek), `kPluginProcesses` ve `registerAllPlugins`; bir eklenti listesi için deterministiktir. `kPluginProcesses`, manifest'i `"isolation": "process"` diyen her eklentiyi `process_class`'ının bir fabrikasına eşler, projenin `plugin_isolation`'ı ne derse desin (editör geçersiz kılmayı başlarken uygular); örneğin `'my_tools': () => my_tools_plugin.MyToolsProcess(),`; hiç yoksa `{}` olur. |

## `lib/data/services/plugin_registry_service.dart`

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
| `refresh` | `Future<void> refresh()` | `refresh` işlemini gerçekleştirir. |
| `initialize` | `Future<void> initialize(String projectDirPath)` | `initialize` işlemini gerçekleştirir. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | `resolve` işlemini gerçekleştirir. |
| `project` | `LuminaProject? get project` | Son yüklenen ya da kaydedilen haliyle açık proje. |
| `isolationOf` | `PluginIsolation isolationOf(String name)` | `name` eklentisinin açık projede nerede çalıştığı (`LuminaPluginDescriptor.effectiveIsolation`): `plugin_isolation` geçersiz kılması, yoksa manifest'i; process kısmı olmayan (ya da bilinmeyen) bir eklenti süreç içinde çalışır. |
| `isolationOverrideOf` | `PluginIsolation? isolationOverrideOf(String name)` | Açık projenin `name` için geçersiz kılması ya da null. |
| `setIsolationOverride` | `Future<bool> setIsolationOverride(String name, PluginIsolation? isolation)` | Projenin geçersiz kılmasını ayarlar (null kaldırır) ve `.lmproject`'i kaydeder; etkin eklentinin etkin yalıtımı değiştiyse true döner ve eklentiyi `restartPending` olarak işaretler. |

## `lib/data/services/plugin_template_generator_service.dart`

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

## `lib/data/services/primitive_glb_factory.dart`

### `class PrimitiveGlbFactory`

Builds a real glTF 2.0 binary (`.glb`) for an engine primitive.  `Primitive` actors — the template test rooms, and "spawn a cube" — carry a shape and a size instead of an imported model. Rather than teaching every consumer a second geometry path, the shape is turned into an ordinary glTF binary here, so it flows through the same parser, the same renderer, the same picking and the same triangle counter as any imported mesh.  Geometri orijinde ortalanır ve dünya birimiyle (cm) boyutlanır; aktörün kendi dönüşümü onu yerleştirir. Aynı istek her zaman aynı çıktıyı verir.  Her şekil `TEXCOORD_0` ve `TANGENT` taşır; böylece atanan dokulu (ya da normal haritalı) bir materyal dokusunu çizer: kutunun her yüzü ve düzlem 0..1 karesinin tamamını dik olarak eşler, küre ve silindir yüzeyi dokuyu bir kez çevresine sarar (u), üstten (v = 0) alta (v = 1); silindir kapakları dokuyu disk olarak eşler. UV'ler glTF'i izler (v görüntüde aşağı doğru artar); teğetler +u yönündedir ve `w`, glTF'in tanımladığı gibi `cross(normal, tangent) * w` vektörünü görüntüde yukarı çevirir.

**Yapıcı Metotlar (Constructors):**
- `PrimitiveGlbFactory._()`: `PrimitiveGlbFactory._()` nesnesini ilklendirir.

### `class _Geometry`

`_Geometry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_Geometry(this.positions, this.normals, this.uvs, this.indices)`: `_Geometry(this.positions, this.normals, this.uvs, this.indices)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `List<double> normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `uvs` | `List<double> uvs` | `uvs` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `List<int> indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/data/services/project_input_binder.dart`

### `class LuminaAxisPlacementModifier`

Places a key's raw 1D value onto one axis of a 2D action, scaled — a swizzle-axis and a scalar modifier in one.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toX` | `double toX` | `toX` alanını (field/property) ve ilişkili veriyi saklar. |
| `toY` | `double toY` | `toY` alanını (field/property) ve ilişkili veriyi saklar. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | `modify` işlemini gerçekleştirir. |

### `class BoundMappingContext`

One mapping context from the manifest, with the priority it was authored at.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `priority` | `int priority` | `priority` alanını (field/property) ve ilişkili veriyi saklar. |
| `context` | `LuminaInputMappingContext context` | `context` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BoundProjectInput`

The result of binding a project's input settings to the runtime.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `contexts` | `List<BoundMappingContext> contexts` | `contexts` alanını (field/property) ve ilişkili veriyi saklar. |
| `actions` | `Map<String, LuminaInputAction> actions` | `actions` alanını (field/property) ve ilişkili veriyi saklar. |
| `unboundKeys` | `List<String> unboundKeys` | Labels of keys the manifest binds that the runtime has no equivalent for. Reported rather than silently dropped, so the editor can say so. |
| `actionByName` | `LuminaInputAction? actionByName(String name)` | `actionByName` işlemini gerçekleştirir. |

### `class ProjectInputBinder`

Turns the `.lmproject` manifest's [ProjectInputSettings] — the same structures the Project Settings input editor edits — into the runtime's actions and mapping contexts.  Play-In-Editor binds through this, so rebinding a key in Project Settings changes what Play does, instead of PIE keeping a second hardcoded list.

**Yapıcı Metotlar (Constructors):**
- `ProjectInputBinder._()`: `ProjectInputBinder._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bind` | `static BoundProjectInput bind(ProjectInputSettings settings)` | `bind` işlemini gerçekleştirir. |

## `lib/data/services/tga_decoder_service.dart`

### `class TgaImage`

`TgaImage`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `rgbaBytes` | `Uint8List rgbaBytes` | `rgbaBytes` alanını (field/property) ve ilişkili veriyi saklar. |

### `class TgaDecoderService`

`TgaDecoderService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isTga` | `static bool isTga(Uint8List bytes)` | Checks if given bytes match a valid TGA image header |
| `decode` | `static TgaImage? decode(Uint8List bytes)` | Decodes TGA binary bytes into raw RGBA8888 pixels |
| `tgaToPng` | `static Uint8List? tgaToPng(Uint8List tgaBytes)` | Converts TGA bytes directly to standard PNG bytes |
| `encodePng` | `static Uint8List encodePng(Uint8List rgba, int width, int height)` | Pure Dart standard PNG encoder with zlib compression |

## `lib/data/services/thumbnail_service.dart`

### `class ThumbnailService`

`ThumbnailService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `writeThumbnailCache` | `void writeThumbnailCache(String lmasPath, Uint8List png)` | `writeThumbnailCache` işlemini gerçekleştirir. |
| `readThumbnailCache` | `Uint8List? readThumbnailCache(String lmasPath)` | `readThumbnailCache` işlemini gerçekleştirir. |

---

[Önceki: Yardımcılar, matematik ve test](utilities.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 1)](data-services-continued.md)
