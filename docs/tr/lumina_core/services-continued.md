[English](../../en/lumina_core/services-continued.md)

# Servisler (devamı)

Saf servisler, ikinci bölüm: üretilmiş kod göçü, GLB animasyon birleştirme ve retargeting, glTF paketleyici, içe aktarma formatları, level şablonları, config ve veri klasörleri, eklenti paketleme ve host yamalama, primitive GLB fabrikası, proje engine bağlantıları, TGA çözücü ve çalışma alanı yolları. Dosya yolları `lumina_core/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/services/game_template_service.dart`](#libsrcservicesgame_template_servicedart)
- [`lib/src/services/generated_code_migration.dart`](#libsrcservicesgenerated_code_migrationdart)
- [`lib/src/services/glb_animation_merger.dart`](#libsrcservicesglb_animation_mergerdart)
- [`lib/src/services/glb_animation_retargeter.dart`](#libsrcservicesglb_animation_retargeterdart)
- [`lib/src/services/gltf_packer.dart`](#libsrcservicesgltf_packerdart)
- [`lib/src/services/import_formats.dart`](#libsrcservicesimport_formatsdart)
- [`lib/src/services/imported_asset_names.dart`](#libsrcservicesimported_asset_namesdart)
- [`lib/src/services/level_template_service.dart`](#libsrcserviceslevel_template_servicedart)
- [`lib/src/services/lumina_config_dir.dart`](#libsrcserviceslumina_config_dirdart)
- [`lib/src/services/lumina_data_dir.dart`](#libsrcserviceslumina_data_dirdart)
- [`lib/src/services/plugin_host_patcher_service.dart`](#libsrcservicesplugin_host_patcher_servicedart)
- [`lib/src/services/plugin_pack_script.dart`](#libsrcservicesplugin_pack_scriptdart)
- [`lib/src/services/primitive_glb_factory.dart`](#libsrcservicesprimitive_glb_factorydart)
- [`lib/src/services/project_engine_link.dart`](#libsrcservicesproject_engine_linkdart)
- [`lib/src/services/space_free_build_dir.dart`](#libsrcservicesspace_free_build_dirdart)
- [`lib/src/services/tga_decoder_service.dart`](#libsrcservicestga_decoder_servicedart)
- [`lib/src/services/umg_widget_library_service.dart`](#libsrcservicesumg_widget_library_servicedart)
- [`lib/src/services/workspace_paths.dart`](#libsrcservicesworkspace_pathsdart)
- [`lib/src/services/glb_reader.dart`](#libsrcservicesglb_readerdart)

## `lib/src/services/game_template_service.dart`

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

## `lib/src/services/generated_code_migration.dart`

### `class LuminaGeneratedCodeMigration`

Brings a project's generated Dart written by earlier Lumina versions to the current naming rules ([dartTypeName], [dartFileName]).

Earlier generators named the files in `lib/levels/`, `lib/actors/`, `lib/anim/` and `lib/widgets/` after their assets (`L_Main.dart`, `BP_Door.dart`) and their classes `L_Main`, `BPDoor`, `WBPHud`. Today the files are snake_case (`l_main.dart`, `bp_door.dart`) and the classes UpperCamelCase (`LMain`, `BpDoor`, `WbpHud`). [migrate] renames the legacy files — keeping their contents, so `BEGIN USER CODE` regions survive — renames the classes they declare, and rewrites the imports and class references of every Dart file under `lib/`, so a project regenerates cleanly and still compiles in between. A legacy file whose snake_case file already exists is stale and is deleted.

Önceki üreteçler yerleştirilmiş actor'leri ve seviye script'lerini Flutter'ın `ValueKey`'iyle de anahtarlıyordu (`key: const ValueKey('act_floor')`, `{Key? key, ...}` imzalı bir Blueprint actor fabrikası, data layer atamasında `key is ValueKey<String>`) ve bunun için `package:flutter/foundation.dart`'ı import ediyordu. Üretilen seviyeler, Blueprint'ler ve kayıt dosyaları artık `LuminaObjectKey('<id>')` yazar; [migrateObjectKeys] `lib/levels/`, `lib/actors/` ve `lib/anim/` altındaki eski dosyaları yerinde yeniden yazar (widget'lar Flutter anahtarlarını korur). [migrate] önce bunu çalıştırır; bir proje açılırken (`ProjectRepository.loadProject` → `prepareAssetIndex` → `migrateGeneratedCode`) ikisi de arka plan isolate'inde çalışır.

Üretilen kod motorun `lumina_runtime.dart`'ını import ediyordu; bu kütüphane oyun widget'ını, UMG'yi, medyayı ve fare yakalamayı da taşıyordu. Bunlar `lumina_widgets`'a taşındı: [migrateGameImports] `lib/` altında bunlardan birini kullanan dosyaları (launcher, UMG widget sınıfları ve kayıtları) `kLuminaGameLibrary`'yi (`package:lumina_widgets/lumina_game.dart`; `show` / `hide` korunur) import edecek şekilde yeniden yazar, [migratePubspecGameDependency] `lumina_widgets`'ı `lumina` bağımlılığının yanına aynı biçimde ekler (git: aynı url ve ref, `path: lumina_widgets`; path: `lumina`'nın yanındaki klasör). [migrate] ve bir projeyi açmak ikisini de çalıştırır.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `generatedFolders` | `static const List<String> generatedFolders` | The `lib/` folders whose files are named after assets. |
| `migrate` | `static Map<String, String> migrate(String projectDir)` | Migrates [projectDir]'s generated Dart; returns the renamed files, `lib/…` old path → new path (empty when there was nothing to migrate). |
| `objectKeyFolders` | `static const List<String> objectKeyFolders` | Kodu engine nesnelerini anahtarlayan üretilmiş klasörler: `levels`, `actors`, `anim`. |
| `migrateObjectKeys` | `static List<String> migrateObjectKeys(String projectDir)` | [objectKeyFolders] içinde engine nesnelerindeki Flutter `Key` / `ValueKey`'i `LuminaObjectKey`'e çevirir; yeniden yazılan dosyaları (`lib/...`) döndürür, gerek yoksa boş. |
| `rewriteObjectKeys` | `static String rewriteObjectKeys(String source)` | `ValueKey<String>` / `ValueKey(` / `Key? key` yerine `LuminaObjectKey` yazılmış ve `foundation.dart` import'u kaldırılmış [source] (diğer gösterilen adlar kalır). İdempotent. |
| `migrateGameImports` | `static List<String> migrateGameImports(String projectDir)` | Oyun arayüzünü kullanan dosyaların `lumina_runtime.dart` import'unu oyun kütüphanesine çevirir; onları döndürür (`lib/...`). |
| `rewriteGameImports` | `static String rewriteGameImports(String source)` | `package:lumina/lumina_runtime.dart` import'ları oyun kütüphanesiyle değiştirilmiş [source] (yinelenen düz import atılır). |
| `migratePubspecGameDependency` | `static bool migratePubspecGameDependency(String projectDir)` | Projenin pubspec'inde `lumina`'nın yanına `lumina_widgets` ekler; değiştiyse true. |
| `withGameDependency` | `static String withGameDependency(String pubspec)` | O bağımlılık eklenmiş pubspec metni. |

## `lib/src/services/glb_animation_merger.dart`

### `class GlbClipSource`

One animation to merge into a base GLB: animation [animationIndex] of the GLB [bytes], stored in the result under [name].

**Yapıcı Metotlar (Constructors):**

- `const GlbClipSource({required this.name, required this.bytes, this.animationIndex = 0, this.stripRootMotion = false, this.rotationOnly, this.keepTranslationForB...`
- `factory GlbClipSource.fromGltf(File gltf, {String? name, int animationIndex = 0})`: A clip exported as a `.gltf` document with its keys in a sibling binary file (`buffers[].uri`, e.g. `Land.bin`), packed into a GLB in memory.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `bytes` | `final Uint8List bytes` |  |
| `animationIndex` | `final int animationIndex` |  |
| `stripRootMotion` | `final bool stripRootMotion` | Drop the clip's `root` translation channel: a root-motion export moves the whole mesh away from its capsule and snaps it back when the clip ends; the character's movement provides the travel instead. |
| `rotationOnly` | `final bool? rotationOnly` | Rotation-only retarget: drop the clip's translation and scale channels for every bone except [keepTranslationForBones], keeping all rotations, so a clip exported from a skeleton with different bone lengths (the same bone names on other proportions) does not push the base's bones to the other skeleton's offsets. The kept bones' translation keys are scaled by the ratio of the base's to the source's bind length of that bone. `null` (the default) turns it on automatically when the clip's skeleton differs from the base's — its skin joints and the base's are not the same set. |
| `keepTranslationForBones` | `final Set<String> keepTranslationForBones` |  |

### `class GlbClipMergeReport`

What merging one clip did to its channels: the bones whose channels were copied and the bones the base skeleton lacked (dropped only with `skipMissingBones`).

**Yapıcı Metotlar (Constructors):**

- `const GlbClipMergeReport({required this.clip, required this.keptBones, required this.droppedBones, required this.keptChannels, required this.droppedChannels, th...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `clip` | `final String clip` |  |
| `keptBones` | `final List<String> keptBones` |  |
| `droppedBones` | `final List<String> droppedBones` |  |
| `keptChannels` | `final int keptChannels` |  |
| `droppedChannels` | `final int droppedChannels` |  |
| `strippedRootMotionChannels` | `final int strippedRootMotionChannels` | Root translation channels left out for a `stripRootMotion` clip. |
| `rotationOnly` | `final bool rotationOnly` | Whether the clip was retargeted rotation-only, and what that left out: translation / scale channels of bones other than the kept ones, and the factor each kept bone's translation was scaled by. |
| `droppedTranslationChannels` | `final int droppedTranslationChannels` |  |
| `droppedScaleChannels` | `final int droppedScaleChannels` |  |
| `translationScale` | `final Map<String, double> translationScale` |  |
| `droppedAny` | `bool get droppedAny` |  |
| `keeps` | `bool keeps(Iterable<String> bones)` | Whether every bone of [bones] kept at least one channel. |

### `class GlbMergeReport`

One [GlbClipMergeReport] per merged clip, in merge order.

**Yapıcı Metotlar (Constructors):**

- `const GlbMergeReport(this.clips)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `clips` | `final List<GlbClipMergeReport> clips` |  |
| `forClip` | `GlbClipMergeReport? forClip(String name)` |  |

### `class GlbDocument`

A GLB split into its JSON document and its binary chunk.

**Yapıcı Metotlar (Constructors):**

- `GlbDocument(this.json, this.bin)`
- `factory GlbDocument.parse(Uint8List bytes, {String label = 'input'})`: Parses [bytes] as a binary glTF 2.0 container. [label] names the input in the [FormatException] thrown for anything that is not one.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `json` | `final Map<String, dynamic> json` |  |
| `bin` | `final Uint8List bin` |  |
| `encode` | `Uint8List encode()` | Serializes the document back into a GLB, padding the JSON chunk with spaces and the binary chunk with zeros to 4-byte boundaries. |

### `class GlbAnimationMerger`

Merges animations from several GLBs into one skinned GLB, so a single gltfio asset — and therefore a single `FilamentAnimator` — can play them all.

gltfio's animator only plays animations stored in the same asset as the nodes they move. Clip sets exported one animation per file (Unreal's mannequin sequences, Mixamo downloads) are therefore merged ahead of time. Channels are retargeted by **node name**: two exports of the same skeleton do not have to list their bones in the same order, and the Unreal mannequin clips in `test-assets/` indeed permute the finger bones relative to `SKM_Manny_Simple`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `animationNames` | `static List<String> animationNames(Uint8List glb)` | The names of the animations stored in [glb], in index order. |
| `hasUnitScales` | `static bool hasUnitScales(Uint8List glb, {int animationIndex = 0, double tolerance = 1e-4})` | Whether every scale channel of animation [animationIndex] keeps every bone at scale 1 (within [tolerance]); true when it has no scale channel. |
| `hasCollapsedScales` | `static bool hasCollapsedScales(Uint8List glb, {int animationIndex = 0})` |  |
| `merge` | `static Uint8List merge({required Uint8List base, required List<GlbClipSource> clips, bool skipMissingBones = f...` | Returns [base] with one animation appended per entry of [clips]. |
| `mergeWithReport` | `static ({Uint8List bytes, GlbMergeReport report}) mergeWithReport({required Uint8List base, required List<GlbC...` | [merge], also reporting per clip which bones' channels were kept and, with [skipMissingBones], which were dropped because the base skeleton has no node of that name (an export with extra bones — the Unreal mannequin's `breast_l/r` — animates the bones both skeletons share and leaves the rest at the bind pose). |

## `lib/src/services/glb_animation_retargeter.dart`

### `class GlbSkeletonMatch`

How well a clip's animated bones match a skeleton, by name.

**Yapıcı Metotlar (Constructors):**

- `const GlbSkeletonMatch({required this.matched, required this.animated, required this.missing})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `matched` | `final int matched` | Animated clip bones the skeleton has. |
| `animated` | `final int animated` | Bones the clip animates. |
| `missing` | `final List<String> missing` | Animated clip bones the skeleton lacks. |
| `score` | `double get score` | Share of the clip's animated bones found in the skeleton, 0–1. |

### `class GlbRetargetResult`

A clip retargeted into a skeletal mesh GLB.

**Yapıcı Metotlar (Constructors):**

- `const GlbRetargetResult({required this.glb, required this.clipName, required this.clipIndex, required this.duration, required this.mappedBones, required this.re...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `glb` | `final Uint8List glb` | The mesh GLB with the clip appended (or replaced, when one of the same name was there). |
| `clipName` | `final String clipName` |  |
| `clipIndex` | `final int clipIndex` | Index of the clip among the result's animations (the gltfio animator index). |
| `duration` | `final double duration` | Clip length in seconds. |
| `mappedBones` | `final List<String> mappedBones` | Skeleton bones that follow a clip bone of the same name. |
| `restBones` | `final List<String> restBones` | Skeleton bones the clip has no bone for; they hold their rest rotation relative to their parent. |
| `ignoredSourceBones` | `final List<String> ignoredSourceBones` | Clip bones the skeleton does not have (ignored). |
| `pelvisTranslationScale` | `final double pelvisTranslationScale` | Factor applied to the pelvis translation (target leg length over the clip's leg length). |

### `abstract final class GlbAnimationRetargeter`

Retargets a skeletal animation onto another skeleton that shares its bone names (the UE4 → UE5 mannequin case) and appends it to that skeleton's GLB, so one gltfio asset (one animator) plays it.

GEM-X SOMA klipleri ayrı bir semantik eşleştirme kullanır: `LeftLeg`/`RightLeg`
üst bacağı, `LeftShin`/`RightShin` alt bacağı sürer. `Chest`, en üst göğüs kemiğine
(`spine_05` varsa ona) aktarılır. GLB düğümleri nötr referans pozunu taşımalı ve
`extras.somaReferencePose = "neutral"` ile belirtmelidir. Model uzayındaki hareket,
bu referansa göre hedef bind eksenlerine aktarılır. Hedef kemik konumları korunur;
göreli kök hareketi hedef pelvis konumuna eklenir. Twist/düzeltici kemikler
ebeveynlerini izler. Üst kol ve ön kol referans yönleri semantik dirsek ve bilek
çocukları üzerinden hizalanır; kaynak T-poz hareketine hedef A-poz açısı eklenmez.
Nötr gövde ve bacak konumları korunur; nötr kollar kaynak referans yönünü izler. Bu referansı
taşımayan eski GEM-X çıktıları yeniden üretim mesajıyla reddedilir.

Uygulama `glb_animation_retargeter/models.dart`, `operation.dart`,
`pose_sampling.dart` ve `soma_mapping.dart` dosyalarına ayrılmıştır. Genel giriş
noktası `GlbAnimationRetargeter.retargetInto` olarak kalır.

Unlike [GlbAnimationMerger], which copies channels verbatim onto an identical skeleton, this handles skeletons that differ in hierarchy and proportions (UE5's spine_04/05, neck_02 and metacarpals have no UE4 counterpart):

- **Rotation only.** Her eşleşen kemik, model uzayında klip kemiğinin rotasyonunu alır (klibin ileri kinematiği); yerel rotasyonu hedef ebeveyninden türetilir. Klibin eksik olduğu iskelet kemikleri ebeveynlerine göre rest rotasyonlarını korur. Rest pozları farklı olduğunda (örneğin kolların aşağı eğimli olduğu MetaHuman iskeletlerinde kaynak T-pose ile hedef A-pose farkı), hedef kemik rest yönelimleri kaynak rest yönlerine hizalanır; böylece animasyon deltaları rest açılarını katlamadan ve kollar/bacaklar çaprazlanmadan aktarılır. - **Translations come from the target skeleton**, iskelet kökü (kopyalanır: root motion ve yerleşim) ve pelvis (kopyalanır, hedefin bacak uzunluğunun klibinkine oranıyla ölçeklenir) hariç hedeften gelir. Klip kemik ötelemeleri haricinde yok sayılır.

Gövde kemiklerine dinamik veya sabit dönüş/konum kanalları yazılır. Eşleşmeyen yüz ve düzeltici kemikler hariç tutulur; gövde klibi bu kemiklerin yerel referans dönüşlerini korur.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `jointNames` | `static Set<String> jointNames(Uint8List glb)` | Names of the joints of every skin in [glb]. |
| `animatedNodeNames` | `static Set<String> animatedNodeNames(Uint8List clip, {int animationIndex = 0})` | Names of the nodes animation [animationIndex] of [clip] animates. |
| `match` | `static GlbSkeletonMatch match({required Uint8List target, required Uint8List clip, int animationIndex = 0})` | How well [clip]'s animation matches [target]'s skeleton. |
| `matchNames` | `static GlbSkeletonMatch matchNames(Set<String> targetJoints, Set<String> animated)` |  |
| `retargetInto` | `static GlbRetargetResult retargetInto({required Uint8List target, required Uint8List clip, required String cli...` | Retargets animation [animationIndex] of [clip] onto [target]'s skeleton and returns [target] with it appended as [clipName] (replacing an animation of that name). |

## `lib/src/services/gltf_packer.dart`

### `class GltfPacker`

Packs a text `.gltf` and the files it references (its `.bin` buffers and image files) into one self-contained GLB.

The import pipeline stores a mesh's payload as GLB, so a `.gltf` is staged through [packFile] — without it the payload kept a relative `uri` that no longer resolves once the file is in the project.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `externalUris` | `static List<String> externalUris(Map<String, dynamic> gltf)` | The relative file URIs (decoded, `/`-separated) [gltf] references: external buffers first, then images. `data:` URIs are left out. |
| `referencedFiles` | `static List<String> referencedFiles(String gltfPath)` | The files [gltfPath] references, resolved beside it (they need not exist). |
| `packFile` | `static Uint8List packFile(String gltfPath)` | [gltfPath] as GLB bytes: every buffer (external or `data:`) merged into the BIN chunk, every external or `data:` image moved into a buffer view. Throws a [FormatException] naming a referenced file that is missing. |

## `lib/src/services/import_formats.dart`

### `enum ImportFormatKind`

What an importable file becomes.

**Değerler:**

- `mesh`: glTF / GLB, OBJ, FBX, Collada, 3DS, PLY, DirectX, STL → a static or skeletal mesh (or an animation).
- `texture`: PNG, JPEG, WebP, TGA → a texture.
- `audio`: WAV, OGG, MP3 → a sound.
- `asset`: A `.lmas` from another project, copied in as it is.

### `class ImportFormats`

The file types the import pipeline takes: the one table [AssetRepository.stageImport] classifies by, the Content Browser's file picker offers and the folder importer (`ImportFolderScanner`) walks.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `byExtension` | `static const Map<String, ImportFormatKind> byExtension` | Lower-case extension (no dot) → what it imports as. |
| `extensions` | `static List<String> get extensions` | Every importable extension, as a file picker's `allowedExtensions`. |
| `companionExtensions` | `static const Set<String> companionExtensions` | Files that only travel with a primary file (a `.gltf`'s buffers, an OBJ's material library) and never import on their own. |
| `knownUnsupported` | `static const Map<String, String> knownUnsupported` | Formats people try that the pipeline has no importer for, and why. |
| `extensionOf` | `static String extensionOf(String path)` | The lower-case extension of [path] without the dot, or '' when none. |
| `kindOf` | `static ImportFormatKind? kindOf(String path)` | What [path] imports as, or null when the pipeline does not take it. |
| `isImportable` | `static bool isImportable(String path)` |  |
| `unsupportedReason` | `static String? unsupportedReason(String path)` | Why [path] is not imported, or null when it is. |
| `stagedKindOf` | `static String stagedKindOf(String path)` | The detected-kind label [AssetRepository.stageImport] reports for a non-glTF [path] ('texture', 'audio', 'static mesh'). |

## `lib/src/services/imported_asset_names.dart`

### `abstract final class ImportedAssetNames`

The names an import gives the materials and textures it extracts from a mesh file named [baseName] (prefixes: `M_`, `T_`).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `material` | `static String material(String raw, String baseName)` | `M_Wood` stays, `MI_Wood` → `M_Wood`, a name holding the file's name gets `M_`, anything else becomes `M_<file>_<name>`. |
| `texture` | `static String texture(String raw, String baseName)` | `T_Wood_N` stays, `MI_…`/`M_…` swap the prefix for `T_`, a name holding the file's name gets `T_`, anything else becomes `T_<file>_<name>`. |

## `lib/src/services/level_template_service.dart`

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

## `lib/src/services/lumina_config_dir.dart`

### `abstract final class LuminaConfigDir`

The per-user directory Lumina Studio keeps its settings in: `recent_projects.json`, `launcher_settings.json`, `editor_quality.json`, `plugin_wizard.json`.

Every reader and writer of those files resolves the directory here, in this order: 1. a directory the caller passes explicitly (a repository's `configDir`); 2. [override], the in-process redirect test harnesses set; 3. the `LUMINA_CONFIG_DIR` environment variable; 4. `~/.config/lumina`.

Test suites set [override] to a fresh temp directory in their `flutter_test_config.dart`, so no test reads or writes the user's own files.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` | The environment variable that redirects the directory for a whole process (tooling exports it to the test runs it starts). |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. Dart cannot set an environment variable for its own process, so a test harness sets this. |
| `resolve` | `static Directory resolve({Directory? explicit, Map<String, String>? environment})` | The config directory. [explicit] wins over everything else; [environment] defaults to the process environment. |
| `file` | `static File file(String name, {Directory? explicit})` | The file [name] in the resolved directory. |

## `lib/src/services/lumina_data_dir.dart`

### `abstract final class LuminaDataDir`

The per-user directory Lumina keeps downloaded data in: the engine source a release build fetches for itself (`engine/<version>/`) and the prebuilt Filament builds (`filament/<version>/`).

- Windows: `%LOCALAPPDATA%\Lumina`; - Linux: `$XDG_DATA_HOME/lumina`, else `~/.local/share/lumina` (where the user plugins and the MiniAI models live too); - macOS: `~/Library/Application Support/Lumina`.

`LUMINA_DATA_DIR` redirects it for a whole process; [override] does the same in-process (test harnesses).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` |  |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. |
| `resolve` | `static Directory resolve({Map<String, String>? environment, String? operatingSystem})` | The data directory for [environment] (default: the process environment) on [operatingSystem] (default: this one). |
| `engineRoot` | `static Directory engineRoot({Map<String, String>? environment, String? operatingSystem})` | `<data>/engine`: one checkout per release tag. |
| `filamentRoot` | `static Directory filamentRoot({Map<String, String>? environment, String? operatingSystem})` | `<data>/filament`: one prebuilt Filament per Filament version. |

## `lib/src/services/plugin_host_patcher_service.dart`

### `class PluginHostPatcherService`

`PluginHostPatcherService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `patchPubspec` | `Future<void> patchPubspec(Directory hostRoot, List<LuminaPluginDescripto...` | `patchPubspec` işlemini gerçekleştirir. |
| `generateRegistrar` | `Future<void> generateRegistrar(Directory hostRoot, List<LuminaPluginDesc...` | `generateRegistrar` işlemini gerçekleştirir. |
| `registrarSource` | `String registrarSource(List<LuminaPluginDescriptor> enabledCodePlugins)` | Registrar kütüphanesi: `kEnabledPlugins` (editor modülü başına bir örnek), `kPluginProcesses` ve `registerAllPlugins`; bir eklenti listesi için deterministiktir. `kPluginProcesses`, manifest'i `"isolation": "process"` diyen her eklentiyi `process_class`'ının bir fabrikasına eşler, projenin `plugin_isolation`'ı ne derse desin (editör geçersiz kılmayı başlarken uygular); örneğin `'my_tools': () => my_tools_plugin.MyToolsProcess(),`; hiç yoksa `{}` olur. |

## `lib/src/services/plugin_pack_script.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kPluginPackScriptFileName` | `const String kPluginPackScriptFileName` | Where the script lives in a plugin (under `tool/`). |
| `kPluginPackScriptPath` | `const String kPluginPackScriptPath` | The plugin-relative path of the script. |
| `kPluginPackScript` | `const String kPluginPackScript` | The script's source. |

## `lib/src/services/primitive_glb_factory.dart`

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

## `lib/src/services/project_engine_link.dart`

### `class ProjectEngineLink`

How a game project reaches the engine.

The project's `pubspec.yaml` depends on `lumina` and `lumina_widgets` ([enginePackages]; generated code imports `lumina_game.dart`) through git ([kLuminaGitUrl], `path: lumina` / `path: lumina_widgets`), so it is committable and builds on any machine once the LuminaGame repos are published. One of two things makes it build on the machine of the engine checkout the editor runs from:

- a gitignored `pubspec_overrides.yaml` pinning `lumina` and every package of its path/git closure (`flutter_filament`, the tools packages, …) to the local checkout (absolute `/`-separated paths: the project folder and the engine are on unrelated paths, often on different drives); each local package's hook then finds Filament through its own `../filament`; - or, building against git, `hooks: user_defines:` in `pubspec.yaml` telling the native-assets hooks of flutter_filament / flutter_assimp / flutter_riglogic where this machine's Filament build, libc++ and RigLogic library are. A package resolved from git (a pub-cache checkout) has no `../filament` beside it. The hooks runner reads user-defines from the root `pubspec.yaml` only (pub rejects a `hooks` key in `pubspec_overrides.yaml`), so this block holds machine paths; it is rewritten whenever the project is linked again.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `overridesFileName` | `static const String overridesFileName` |  |
| `hookedPackages` | `static const List<String> hookedPackages` | The packages whose hooks take the settings [hookUserDefines] writes. |
| `hooksMarker` | `static const String hooksMarker` | The first line of the generated `hooks:` comment, found again on every relink. |
| `engineDependency` | `static String engineDependency({String indent = ' ', String? ref, String? url})` | The git form of the engine dependency (no trailing newline), from [url] at [ref]. Both default to the engine checkout the editor fetched for its release ([LuminaWorkspace.engineRepo], [LuminaWorkspace.engineCommit]), so a project generated by a release editor builds against that exact commit; from a source workspace the URL is [kLuminaGitUrl] and there is no `ref:` (the default branch). |
| `localEngineRoot` | `static String? localEngineRoot({String? luminaPackageDir})` | The engine workspace root holding [luminaPackageDir] (default [LuminaWorkspace.package]`('lumina')`), or null when it is not a local checkout (no `lumina/pubspec.yaml` there). |
| `localPackages` | `static Map<String, String> localPackages(String engineRoot, {void Function(String)? onLog})` | `lumina`, `lumina_widgets` and every package of their path/git closure as [engineRoot] resolved them (name → absolute dir). When the closure cannot be walked (the engine was never `pub get`-ed), only `lumina` and the `flutter_filament` beside it. |
| `overridesYaml` | `static String overridesYaml(Map<String, String> packages, String engineRoot)` | The `pubspec_overrides.yaml` pinning [packages] (name → dir). |
| `hookUserDefines` | `static Map<String, Map<String, String>> hookUserDefines(String engineRoot, {Map<String, String>? packages})` | The hook settings (package → key → the dir's `file:` URI) for this machine: the engine workspace's own `hooks: user_defines:` (relative to its root pubspec), `<engine>/filament` when it names no Filament, and the built RigLogic library of the flutter_riglogic [packages] resolves to. Only directories that exist are kept. |
| `withHookUserDefines` | `static String withHookUserDefines(String pubspec, Map<String, Map<String, String>> defines, {bool anyBlock = f...` | [pubspec] with the `hooks:` block this class wrote (under [hooksMarker]; with [anyBlock], any top-level `hooks:` block) replaced by [defines], or removed when [defines] is empty; the new block is appended at the end. A `hooks:` block of the user's own is kept, and then none is added (a second top-level key would be invalid YAML). |
| `withGitEngineDependency` | `static String withGitEngineDependency(String pubspec, {String? ref})` | [pubspec] with its `lumina:` and `lumina_widgets:` dependencies in the git form (each added under `dependencies:` when missing, a new `lumina_widgets` at `lumina`'s ref); a `path:` or other source is replaced. The git `ref:` is [ref], else the release commit [engineDependency] defaults to; with neither, a `ref:` the existing dependency already has is kept (a source-workspace editor does not unpin a project a release editor pinned). |
| `ensureOverridesIgnored` | `static bool ensureOverridesIgnored(String projectDir)` | Adds `pubspec_overrides.yaml` to [projectDir]'s `.gitignore`; false when it was listed already. |
| `apply` | `static ProjectEngineLinkResult apply(String projectDir, {String? luminaPackageDir, bool localOverrides = true,...` | Links the project at [projectDir] to the engine: the git `lumina` dependency in its pubspec, and — when the editor runs from a local checkout ([localEngineRoot]) — either the gitignored `pubspec_overrides.yaml` ([localOverrides], the default; a hook block written earlier is removed, since every local package's hook finds Filament through its own `../filament`), or, building against git (`localOverrides: false`), the hook settings, unless an overrides file is in effect. Without a local checkout an existing overrides file and hook block are left as they are. Idempotent. |

### `class ProjectEngineLinkResult`

What [ProjectEngineLink.apply] did.

**Yapıcı Metotlar (Constructors):**

- `const ProjectEngineLinkResult({this.engineRoot, this.overrides = const {}, this.hookUserDefines = const {}})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String? engineRoot` | The local engine checkout the project was linked to; null: git only. |
| `overrides` | `final Map<String, String> overrides` | The packages pinned in `pubspec_overrides.yaml` (name → dir). |
| `hookUserDefines` | `final Map<String, Map<String, String>> hookUserDefines` | The hook settings written into `pubspec.yaml`. |
| `isLocal` | `bool get isLocal` |  |

## `lib/src/services/space_free_build_dir.dart`

### `abstract final class SpaceFreeBuildDir`

Windows'ta bir klasör için `flutter pub get` / `flutter build` komutlarının çalıştığı yer: boşluksuz bir kök altında ona giden bir junction; böylece native-assets hook'ları hiçbir zaman boşluk içeren bir yol görmez. native_toolchain_c `cl.exe`'yi `cmd.exe` üzerinden çalıştırır ve `cl.exe` "C:\Program Files" altındadır; bu yüzden tırnaklı bir argüman daha ("…\Lumina Projects\…" altındaki bir çıktı klasörü, include ya da kütüphane) cmd'nin tırnak işlemesini bozar ("'C:\Program' is not recognized"). Takma ad ayrıca bütün yolları kısa tutar. Dosyalar yerinde kalır; yalnızca build'in gördüğü yol değişir. Proje editörü build'i ([EditorBuildService.buildDirOf]), Cook & Package ve Play Standalone tarafından kullanılır.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `of` | `static String of(String dir, {Directory? aliasRoot, String? platform})` | [dir] için build klasörü: Windows dışında (ya da [platform] `windows` değilse) [dir]'in kendisi, aksi halde [aliasRoot] (varsayılan [defaultAliasRoot]) altında ona giden, klasör başına bir tane olan kalıcı bir junction. Takma ad yolunda link olmayan bir şey varsa ona dokunulmaz: [dir] olduğu gibi kullanılır. |
| `defaultAliasRoot` | `static String defaultAliasRoot()` | `%LOCALAPPDATA%\lumina\hosts`; `%LOCALAPPDATA%`'nın kendisi boşluk içeriyorsa (boşluklu bir kullanıcı adı) `<SystemDrive>\lumina-hosts`. |

## `lib/src/services/tga_decoder_service.dart`

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

## `lib/src/services/umg_widget_library_service.dart`

### `abstract final class UmgWidgetLibraryService`

Keeps a game project's `pubspec.yaml` in line with its UMG widget library: a `shadcn` project depends on shadcn_flutter at the editor's version ([kGameShadcnFlutterVersion]), a `flutter` project does not. The dependency lives in a marked block so switching back and forth is exact and idempotent.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `beginMarker` | `static const String beginMarker` |  |
| `endMarker` | `static const String endMarker` |  |
| `apply` | `static bool apply(String projectDir, String library)` | Makes `<projectDir>/pubspec.yaml` match [library]. Returns whether the file changed; the caller then runs `flutter pub get`. |
| `dependsOnShadcn` | `static bool dependsOnShadcn(String projectDir)` | Whether the project's pubspec declares shadcn_flutter (in the block or by hand), i.e. whether shadcn code compiles in the game. |
| `effectiveLibrary` | `static String effectiveLibrary(String projectDir, LuminaProject? project)` | The library the generated launcher and widgets can actually target: shadcn only when the project chose it *and* depends on it, so a manifest predating the setting never gets code its pubspec cannot build. |

## `lib/src/services/workspace_paths.dart`

### `class LuminaWorkspace`

Locates the Lumina workspace (the lumina repo: the folder holding `lumina/`, `lumina_ui/`, `flutter_filament/`, `filament/`, …) without assuming where it was checked out, so the same build runs from any checkout folder on Linux and on Windows.

Packages from the other repos (flutter_assimp, flutter_riglogic, flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared package, the plugins) are not under the root: they are git dependencies, or local checkouts through the root's `pubspec_overrides.yaml`. [package] finds them through the workspace's resolved package config.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `home` | `static String get home` | The user's home directory (`HOME`, or `USERPROFILE` on Windows). |
| `root` | `static String get root` | The workspace root: the checkout set by [useCheckout], else `LUMINA_WORKSPACE` when set, else the first ancestor of the working directory, the running executable or the script that contains `lumina/pubspec.yaml`, else `<home>/lumina`. |
| `useCheckout` | `static void useCheckout(String checkout, {String? commit, String? repo})` | Points [root] at [checkout] for the rest of the process: the engine source a release build fetched for itself (see `EngineBootstrap`). [commit] and [repo] are the commit that checkout is at and the git URL it came from; generated projects pin their engine dependency to them ([engineCommit], [engineRepo]). Takes precedence over every other way of finding the workspace. |
| `clearCheckout` | `static void clearCheckout()` | Undoes [useCheckout] (tests; a re-download that failed). |
| `checkoutOverride` | `static String? get checkoutOverride` | The checkout [useCheckout] set; null when the workspace is found the usual way. |
| `engineCommit` | `static String? get engineCommit` | The engine commit of the checkout set by [useCheckout]; null in a source workspace, where generated projects follow the default branch. |
| `engineRepo` | `static String? get engineRepo` | The git URL the checkout set by [useCheckout] was cloned from. |
| `findSourceRoot` | `static String? findSourceRoot({Map<String, String>? environment})` | The source workspace this process runs from, without the `<home>/lumina` fallback: `LUMINA_WORKSPACE`, else an ancestor of the working directory, the executable or the script holding `lumina/pubspec.yaml`; null when there is none (an installed release build). [environment] defaults to the process environment. |
| `package` | `static String package(String name)` | The directory of package [name], e.g. `package('lumina_editor_api')`: `<root>/<name>` when it holds that package, else where the workspace resolved it (see [packageIn]). |
| `packageIn` | `static String packageIn(String root, String name)` | [name]'s directory as the workspace at [root] sees it: `<root>/<name>` when its pubspec is there, else the package's root in `<root>/.dart_tool/package_config.json` (a package from another repo: a git checkout in the pub cache or its local override), else `<root>/<name>`. |
| `resolvedPackageDir` | `static String? resolvedPackageDir(String root, String name)` | [name]'s root directory from `<root>/.dart_tool/package_config.json` (written by `pub get` at the workspace root); null when the config or the package is missing. |
| `pluginPackageDirs` | `static List<String> pluginPackageDirs(String root)` | `<root>/.dart_tool/package_config.json` içinde `<name>.lmplugin` manifesti taşıyan paketlerin kök klasörleri (engine'in yerleşik eklentileri: `pubspec_overrides.yaml` üzerinden yerel checkout ya da pub önbelleğindeki git checkout'u), ada göre sıralı; `pub get` öncesinde boş. |
| `gitSourceOf` | `static LuminaGitSource? gitSourceOf(String root, String name, {String? packageDir})` | `<root>/pubspec.lock` dosyasının [name] paketini çözdüğü git bağımlılığı (url, path, çözülmüş commit); path override veya hosted paket için null, [packageDir] verilirse o klasör o commit'in checkout'u değilse de null. |
| `testAssets` | `static String get testAssets` | The shared 3D test assets (`<root>/test-assets`). |
| `findRootFrom` | `static String? findRootFrom(String start)` | The first of [start] and its ancestors holding `lumina/pubspec.yaml`. |

## `lib/src/services/glb_reader.dart`

Saf Dart GLB okuyucusu. `GlbReader.parse(bytes, decoders:)` bir binary glTF'i (`.glb`) ya da onu `raw_payload` olarak taşıyan bir `.lmas` JSON kabını `GlbMeshData`'ya okur: node hiyerarşisi, primitive başına dünya uzayı pozisyonları ve indeksler, UV'ler, vertex renkleri, skinning, morph target'lar ve animasyon clip'leri. Saf Dart'ın çözemediği şeyler çağırandan `GlbDecoders` ile gelir:

- `draco` (`GlbDracoDecoder`): `KHR_draco_mesh_compression` kullanan bir primitive'i `GlbDracoMesh`'e (pozisyonlar, UV'ler, indeksler) çözer. Olmadığında böyle bir primitive yalnızca accessor sınırlarını tutar.
- `image` (`GlbImageDecoder`): bir base colour dokusunu `GlbDecodedPixels`'e (`width`, `height`, `rgba`) çözer; okuyucu bunu vertex renklerine örnekler. Olmadığında materyalin base colour çarpanı kullanılır.
- `prepare` (`GlbBytesTransform`): byte'ları okumadan önce yeniden yazar. Editör içe aktarma temizleyicisini verir.

İlk ikisini engine sağlar (`lumina`'daki `LuminaGlbLoader`, bkz. [Yardımcılar](../lumina/utilities.md)); üçüncüsünü editör ekler ([lumina_editor_data](../lumina_editor_data/services.md) içindeki `GlbParserService.parseGlb`).


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
| `materialName` | `String? materialName` | Primitifin kullandığı glTF materyalinin adı (materyal yuvası); yoksa null. Draco ile sıkıştırılmış primitiflerde de doldurulur. |
| `materialIndex` | `int? materialIndex` | Primitifin kullandığı glTF materyalinin indeksi (materyal yuvası); yoksa null. Draco ile sıkıştırılmış primitiflerde de doldurulur. |
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

---

[Önceki: Servisler](services.md) | [Üst: lumina_core (saf Dart temeli)](index.md)
