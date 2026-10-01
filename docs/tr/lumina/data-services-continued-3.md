[English](../../en/lumina/data-services-continued-3.md)

# Veri katmanı: use case'ler ve servisler (devamı, bölüm 3)

Veri katmanı: use case'ler ve servisler sayfasının devamı: `lib/data/services/` altındaki diğer public dosyalar. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/data/services/authored_animation_clip.dart`](#libdataservicesauthored_animation_clipdart)
- [`lib/data/services/authored_animation_writer.dart`](#libdataservicesauthored_animation_writerdart)
- [`lib/data/services/glb_animation_merger.dart`](#libdataservicesglb_animation_mergerdart)
- [`lib/data/services/glb_animation_retargeter.dart`](#libdataservicesglb_animation_retargeterdart)
- [`lib/data/services/gltf_packer.dart`](#libdataservicesgltf_packerdart)
- [`lib/data/services/import_folder_scanner.dart`](#libdataservicesimport_folder_scannerdart)
- [`lib/data/services/import_formats.dart`](#libdataservicesimport_formatsdart)
- [`lib/data/services/import_image_conversion.dart`](#libdataservicesimport_image_conversiondart)
- [`lib/data/services/import_queue.dart`](#libdataservicesimport_queuedart)
- [`lib/data/services/imported_asset_names.dart`](#libdataservicesimported_asset_namesdart)
- [`lib/data/services/level_asset_manifest.dart`](#libdataserviceslevel_asset_manifestdart)
- [`lib/data/services/lumina_config_dir.dart`](#libdataserviceslumina_config_dirdart)
- [`lib/data/services/lumina_data_dir.dart`](#libdataserviceslumina_data_dirdart)
- [`lib/data/services/mesh_collision_service.dart`](#libdataservicesmesh_collision_servicedart)
- [`lib/data/services/mesh_physics_service.dart`](#libdataservicesmesh_physics_servicedart)
- [`lib/data/services/plugin_pack_script.dart`](#libdataservicesplugin_pack_scriptdart)
- [`lib/data/services/project_engine_link.dart`](#libdataservicesproject_engine_linkdart)
- [`lib/data/services/thumbnail_sidecar_migration.dart`](#libdataservicesthumbnail_sidecar_migrationdart)
- [`lib/data/services/umg_widget_library_service.dart`](#libdataservicesumg_widget_library_servicedart)
- [`lib/data/services/web_loading_screen_service.dart`](#libdataservicesweb_loading_screen_servicedart)
- [`lib/data/services/workspace_paths.dart`](#libdataservicesworkspace_pathsdart)

## `lib/data/services/authored_animation_clip.dart`

Editörde oluşturulan bir Animation Sequence (Content Browser ▸ New ▸ Animation Sequence, ardından Animation editöründe kemik kemik pozlanır): kemiklerin translation / rotation / scale kanallarında tam karelerdeki anahtarlar. Animasyon `.lmas` dosyası onu JSON olarak (`authored_clip`), editörün birebir kaynağı olarak saklar; `GlbAuthoredClipWriter` onu her oynatıcının kullandığı glTF animasyonuna çevirir.

### `enum AuthoredInterpolation`

Bir kanalın anahtarları arasında nasıl ilerlediği: `linear` (`LINEAR`; dönüşler en kısa yoldan slerp), `step` (`STEP`, önceki anahtarı tutar) ve `cubic` (sıfır giriş / çıkış teğetleriyle yazılan `CUBICSPLINE`: her anahtarda yumuşak giriş ve çıkış). gltfio spline teğetlerini anahtar aralığıyla değil interpolantla ölçekler; bu yüzden düz teğetler, onun ve glTF belirtiminin aynı biçimde hesapladığı tek cubic biçimidir. glTF anahtar başına değil kanal başına interpolasyon yapar. `gltfName`, `label`, `fromGltf`, `fromLabel`.

### `class BoneTrs`

Bir kemiğin yerel dönüşümü (glTF düğüm TRS): `t`, `r` (quaternion), `s`; `toMatrix`, `toList` (`[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]`, `SubEditor3DViewport.jointLocalPose`'un aldığı biçim), `channel(path)`, `withChannel(path, values)`.

### `class AuthoredChannel`

Bir kemiğin animasyonlu bir özelliği: `path` (`translation` / `rotation` / `scale`), `interpolation`, `keys` (kare → 3 değer, dönüş için 4: `x y z w`). `setKey`, `removeKey`, `moveKey` (indiği yerdeki anahtarın yerini alır), `copy`, JSON. `sample(frame)` kanalı gltfio animatörünün yaptığı gibi hesaplar: anahtarlı aralığın dışında uç anahtarlar tutulur, `STEP` önceki anahtarı tutar, translation / scale doğrusal, rotation slerp, cubic yumuşak (bileşen bileşen, dönüş için normalize); dönüş anahtarları önce, yazıcının sakladığı gibi, tek yarıküreye getirilir.

### `class AuthoredAnimationClip`

`name` (glTF animasyon adı), `frameRate`, `lengthFrames`, `duration`, `tracks` (kemik → yol → kanal), `bones` (anahtarı olanlar). `setKey(bone, path, frame, values)` (0 ≤ kare ≤ `lengthFrames`), `hasKey`, `removeKey` / `moveKey` (tek kanal ya da kemiğin tüm kanalları), `keyFrames(bone)`, `sample(bone, path, t)`, `samplePose(skeleton, t)` (her düğümün yerel dönüşümü: dinlenme pozunun üzerinde anahtarlı kanallar), `copy`, `toJson` / `fromJson` / `encode` / `decode` (birebir gidiş-dönüş; eşitlik JSON'u karşılaştırır).

### `class GlbSkeleton`

Deri (skin) içeren bir GLB'nin düğüm hiyerarşisi: `names`, `parent`, `rest(node)`, `joints` (tüm skin'lerin eklemleri), `order` (ebeveynler çocuklardan önce), `root` (en üstteki skin eklemi), `rootChild` (onun altında en çok alt düğümü olan eklem: pelvis), `indexOf`, `isJoint`, `worldMatrices(pose)` (GLB'nin çerçevesi: metre, Y yukarı). `GlbSkeleton.fromGlb(bytes)` / `fromJson(gltfJson)`.

## `lib/data/services/authored_animation_writer.dart`

### `abstract final class GlbAuthoredClipWriter`

`write({meshGlb, clip}) → ({Uint8List glb, int clipIndex})`: `clip`'i `clip.name` adlı animasyon olarak içeren mesh GLB'si; aynı adlı bir animasyon varsa yerinde değiştirilir (dosyanın kullandığı her eklenti referanslarını yeniden eşleyebildiği türdense eski accessor'ları, buffer view'ları ve ikili verisi atılıp parça sıkıştırılır), yoksa sona eklenir. Her skin eklemi bir kanal alır: klibin anahtarı olan yerde anahtarlar, diğerlerinde dinlenme rotation + translation değeri (`[0, duration]` boyunca sabit); böylece klip, başka bir klipten sonra da tüm iskeleti tanımlar. Tek anahtarlı bir kanal iki anahtarla tutulur (gltfio ikiden az zamanı olan sampler'ları atlar). GLB olmayan girdi, birden fazla buffer, skin yokluğu, mesh'te olmayan bir kemik (adıyla) ya da klip dışındaki bir anahtar için `FormatException` fırlatır.

### `abstract final class AuthoredAnimationStore`

Bir projedeki oluşturulmuş sekanslar; Third Person şablonunun ve bağlanmış bir FBX içe aktarımının klipleri gibi saklanır: klip iskelet mesh'in GLB'sinde (`.entity.glb` eşi ve varsa mesh `.lmas` payload'ı), adı mesh'in `animation_clips` listesinde, ve ona işaret eden payload'sız bir animasyon `.lmas` dosyası (`source_mesh`, `clip_name`, `clip_index`, `anim_properties`, `duration_seconds`, `length_frames`, bir `skeletal_mesh` referansı) ile birlikte `authored: true` ve `authored_clip`. Anim Blueprint'ler, Blend Space'ler, montajlar, Play-In-Editor ve üretilen oyun onu gltfio üzerinden adıyla, değiştirmeden oynatır.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `create` | `static String create({required String projectDir, required String meshRelPath, required String name, required int lengthFrames, double frameRate = 30.0, String? folder})` | Mesh için yeni bir sekans ([folder] verilmezse `contents/animations/<Mesh>/<name>.lmas`); ad, mesh'in klipleri ve klasörün dosyaları arasında benzersiz yapılır; iskelet kökünün dinlenme translation ve rotation değeri 0. karede anahtarlanır. Proje göreli yolu döndürür. |
| `save` | `static LuminaAsset save({required String projectDir, required String animationRelPath, required AuthoredAnimationClip clip, Map<String, String>? metadata, List<AssetReference>? references})` | Klibi mesh GLB'sine (aynı indeks) ve `.lmas` dosyasına yazar (editörün diğer metadata'sı korunur). |
| `load` | `static AuthoredAnimationClip? load(String projectDir, String animationRelPath)` | Oluşturulmuş klip; içe aktarılmış bir klip için null. |
| `isAuthored` / `clipOf` | `static bool isAuthored(LuminaAsset? asset)` / `static AuthoredAnimationClip? clipOf(LuminaAsset? asset)` | Bir animasyon varlığının burada oluşturulup oluşturulmadığı ve klibi. |

## `lib/data/services/glb_animation_merger.dart`

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

## `lib/data/services/glb_animation_retargeter.dart`

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

Unlike [GlbAnimationMerger], which copies channels verbatim onto an identical skeleton, this handles skeletons that differ in hierarchy and proportions (UE5's spine_04/05, neck_02 and metacarpals have no UE4 counterpart):

- **Rotation only.** Every matched bone takes the clip bone's rotation in model space (the clip's forward kinematics); its local rotation follows from its target parent. Skeleton bones the clip lacks keep their rest rotation relative to their parent. Both skeletons must share the bone axis convention and model space — true for glTF exported by Unreal and for FBX normalized by `FbxImportService` (both Y up, facing +Z). - **Translations come from the target skeleton**, except the skeleton root (copied: root motion and placement) and the pelvis (copied, scaled by the target's leg length over the clip's). Clip bone translations are otherwise ignored: an Unreal FBX carries the authoring skeleton's proportions in them.

Every skeleton joint gets a rotation and a translation channel (constant ones where nothing moves), so switching from another clip of the asset cannot leave a bone where that clip put it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `jointNames` | `static Set<String> jointNames(Uint8List glb)` | Names of the joints of every skin in [glb]. |
| `animatedNodeNames` | `static Set<String> animatedNodeNames(Uint8List clip, {int animationIndex = 0})` | Names of the nodes animation [animationIndex] of [clip] animates. |
| `match` | `static GlbSkeletonMatch match({required Uint8List target, required Uint8List clip, int animationIndex = 0})` | How well [clip]'s animation matches [target]'s skeleton. |
| `matchNames` | `static GlbSkeletonMatch matchNames(Set<String> targetJoints, Set<String> animated)` |  |
| `retargetInto` | `static GlbRetargetResult retargetInto({required Uint8List target, required Uint8List clip, required String cli...` | Retargets animation [animationIndex] of [clip] onto [target]'s skeleton and returns [target] with it appended as [clipName] (replacing an animation of that name). |

## `lib/data/services/gltf_packer.dart`

### `class GltfPacker`

Packs a text `.gltf` and the files it references (its `.bin` buffers and image files) into one self-contained GLB.

The import pipeline stores a mesh's payload as GLB, so a `.gltf` is staged through [packFile] — without it the payload kept a relative `uri` that no longer resolves once the file is in the project.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `externalUris` | `static List<String> externalUris(Map<String, dynamic> gltf)` | The relative file URIs (decoded, `/`-separated) [gltf] references: external buffers first, then images. `data:` URIs are left out. |
| `referencedFiles` | `static List<String> referencedFiles(String gltfPath)` | The files [gltfPath] references, resolved beside it (they need not exist). |
| `packFile` | `static Uint8List packFile(String gltfPath)` | [gltfPath] as GLB bytes: every buffer (external or `data:`) merged into the BIN chunk, every external or `data:` image moved into a buffer view. Throws a [FormatException] naming a referenced file that is missing. |

## `lib/data/services/import_folder_scanner.dart`

### `class ImportFolderFile`

One primary file a folder import brings in, with the files that travel with it.

**Yapıcı Metotlar (Constructors):**

- `const ImportFolderFile({required this.path, required this.relativePath, required this.kind, required this.bytes, this.companions = const [],})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` | Absolute path. |
| `relativePath` | `final String relativePath` | Path under the scanned folder, `/`-separated (`Props/Barrels/x.glb`). |
| `kind` | `final ImportFormatKind kind` |  |
| `bytes` | `final int bytes` | Its size plus its companions'. |
| `companions` | `final List<String> companions` | A `.gltf`'s buffers and images, an OBJ's `.mtl` and its textures (absolute paths): grouped here, never imported on their own. |
| `relativeDir` | `String get relativeDir` | The folder under the scanned root, '' at the root (`Props/Barrels`). |
| `fileName` | `String get fileName` |  |
| `baseName` | `String get baseName` | The file name without its extension: the imported asset's name. |

### `class SkippedImportFile`

A file a folder import leaves out, and why.

**Yapıcı Metotlar (Constructors):**

- `const SkippedImportFile({required this.path, required this.relativePath, required this.reason})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `relativePath` | `final String relativePath` |  |
| `reason` | `final String reason` |  |

### `class ImportFolderScan`

What [ImportFolderScanner.scan] found under [root].

**Yapıcı Metotlar (Constructors):**

- `const ImportFolderScan({required this.root, required this.files, required this.skipped, required this.ignored, required this.totalBytes,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `root` | `final String root` |  |
| `files` | `final List<ImportFolderFile> files` | Primary files, sorted by [ImportFolderFile.relativePath]. |
| `skipped` | `final List<SkippedImportFile> skipped` | Files that are not imported (unsupported, orphaned companions, links, a glTF missing a buffer), sorted by path. |
| `ignored` | `final int ignored` | Hidden files and folders and OS junk (`.DS_Store`, `Thumbs.db`, …), left out silently. |
| `totalBytes` | `final int totalBytes` | Bytes of every file that imports, companions included (each once). |
| `companionCount` | `int get companionCount` |  |
| `countsByKind` | `Map<ImportFormatKind, int> get countsByKind` | How many primary files import as each kind. |
| `folders` | `Set<String> get folders` | The distinct folders (relative) the primary files sit in. |

### `class ImportFolderScanner`

Walks a folder for File → Import Asset Folder…: every file the import pipeline takes ([ImportFormats]), recursively.

Hidden folders and files and OS junk are ignored; symbolic links are not followed unless asked (and then each real folder is visited once); a `.gltf`'s `.bin` and images and an OBJ's `.mtl` and textures are grouped with it, so they import once, as part of it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `junkFileNames` | `static const Set<String> junkFileNames` | File names (lower case) the walk ignores. |
| `scanInBackground` | `static Future<ImportFolderScan> scanInBackground(String root, {bool followLinks = false})` | [scan] in a background isolate, for a big tree. |
| `scan` | `static ImportFolderScan scan(String root, {bool followLinks = false})` |  |

### `enum ImportConflictPolicy`

What to do when an imported asset's target already exists.

**Değerler:**

- `skip`: Leave the existing asset; the file is not imported.
- `overwrite`: Re-import over it (it keeps its asset id, so references hold).
- `rename`: Import beside it as `<name>_1` (`_2`, …).

### `class ImportFolderOptions`

The Import Asset Folder summary dialog's options.

**Yapıcı Metotlar (Constructors):**

- `const ImportFolderOptions({this.targetFolder = 'contents', this.mirrorFolderStructure = true, this.conflictPolicy = ImportConflictPolicy.skip, this.autoOrganize...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `targetFolder` | `final String targetFolder` | The Content Browser folder the tree lands in (`contents/Imported`). |
| `mirrorFolderStructure` | `final bool mirrorFolderStructure` | `Props/Barrels/x.glb` → `<target>/Props/Barrels/` instead of `<target>/`. |
| `conflictPolicy` | `final ImportConflictPolicy conflictPolicy` |  |
| `autoOrganize` | `final bool autoOrganize` | Sort by type into `contents/meshes/static/`, `contents/textures/`, … instead (target folder and mirroring then do not apply). |
| `generateLods` | `final bool generateLods` |  |
| `copyWith` | `ImportFolderOptions copyWith({String? targetFolder, bool? mirrorFolderStructure, ImportConflictPolicy? conflic...` |  |

### `class PlannedFolderImport`

One file of an [ImportFolderPlan].

**Yapıcı Metotlar (Constructors):**

- `const PlannedFolderImport({required this.file, required this.request, required this.targetPath, this.conflicted = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final ImportFolderFile file` |  |
| `request` | `final ImportRequest request` |  |
| `targetPath` | `final String targetPath` | Where its primary `.lmas` lands (project-relative); with Auto Organize the type decides, so this is the likeliest folder. |
| `conflicted` | `final bool conflicted` | Its target already existed (or another file of the batch takes it): it overwrites, or was renamed. |

### `class ImportFolderPlan`

A scan turned into import requests under [ImportFolderOptions]: target folders (mirrored or not) and the conflict policy applied.

**Yapıcı Metotlar (Constructors):**

- `const ImportFolderPlan({required this.imports, required this.skippedExisting})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `imports` | `final List<PlannedFolderImport> imports` |  |
| `skippedExisting` | `final List<ImportFolderFile> skippedExisting` | Files left out because their asset exists (policy skip). |
| `requests` | `List<ImportRequest> get requests` |  |
| `conflicts` | `int get conflicts` | Files whose target exists, whatever the policy did with them. |
| `folderFor` | `static String folderFor(ImportFolderFile file, ImportFolderOptions options)` | The folder [file] imports into. |
| `normalizeFolder` | `static String normalizeFolder(String folder)` | `contents/Imported/` → `contents/Imported` (and `\` → `/`). |
| `build` | `static ImportFolderPlan build(ImportFolderScan scan, {required String projectPath, required ImportFolderOption...` |  |

## `lib/data/services/import_formats.dart`

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

## `lib/data/services/import_image_conversion.dart`

### `abstract final class ImportImageConversion`

The conversion an image import runs on its source file: TGA and WebP are stored as PNG, every other format as it is. The Texture editor's Reimport runs the same one, so a reimported payload is what an import would store.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `convertsToPng` | `static bool convertsToPng(String fileName)` | Whether an image named [fileName] is stored as PNG rather than as it is. |
| `importBytes` | `static Future<Uint8List> importBytes(File source) async` | The bytes an import stores for the image [source]. |

## `lib/data/services/import_queue.dart`

### `enum ImportStage`

Where one file of an import batch is. A file moves queued → converting → writing → thumbnail → done, or ends failed / cancelled.

**Değerler:**

- `queued`: Waiting for a worker.
- `converting`: Staged, converted and routed in the worker isolate; its placeholder thumbnails drawn on the UI isolate.
- `writing`: The asset family being written under `contents/` by the worker.
- `thumbnail`: Written and indexed (it shows in the Content Browser); its rendered thumbnail is being made on the UI isolate.
- `done`
- `failed`
- `cancelled`: Never started: the batch was cancelled first.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isTerminal` | `bool get isTerminal` |  |

### `class ImportRequest`

One file to import and how.

**Yapıcı Metotlar (Constructors):**

- `const ImportRequest({required this.sourcePath, this.targetSubFolder, this.autoOrganize = true, this.generateLods = false, this.targetSkeletonPath, this.targetBa...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `sourcePath` | `final String sourcePath` | The external file (`.glb`, `.gltf`, `.obj`, `.fbx`, an image, …). |
| `targetSubFolder` | `final String? targetSubFolder` | The Content Browser folder it lands in when [autoOrganize] is off. |
| `autoOrganize` | `final bool autoOrganize` |  |
| `generateLods` | `final bool generateLods` |  |
| `targetSkeletonPath` | `final String? targetSkeletonPath` | For an animation: the skeletal mesh to retarget onto (see [AssetRepository.convertStagedAsset]). |
| `targetBaseName` | `final String? targetBaseName` | The asset's name when it is not the file's (the folder importer's "rename" conflict policy: `Barrel_01` → `Barrel_01_1`). |
| `textureSearchDirs` | `final List<String> textureSearchDirs` | For an FBX: folders searched first for its textures (the Import dialog's "Textures Folder"). |
| `fileName` | `String get fileName` |  |
| `needsUiIsolate` | `bool get needsUiIsolate` | Staging a `.webp` decodes it with `dart:ui`, which only the UI isolate may use, so such a file is converted there instead of in a worker. |

### `class ImportProgress`

One file's state, as [ImportQueue.progress] reports it.

**Yapıcı Metotlar (Constructors):**

- `const ImportProgress({required this.batch, required this.index, required this.total, required this.request, required this.stage, required this.fileFraction, req...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `batch` | `final int batch` | Which batch (1, 2, …): a batch lasts from the first file queued while the queue was idle until every file queued since is finished. |
| `index` | `final int index` | This file's position in its batch (0-based) and the batch's size when this event was sent (it grows when files are added mid-batch). |
| `total` | `final int total` |  |
| `request` | `final ImportRequest request` |  |
| `stage` | `final ImportStage stage` |  |
| `fileFraction` | `final double fileFraction` | How far this file is (0–1) and how far the batch is: the mean of every file's fraction, monotonic while no file is added. |
| `overallFraction` | `final double overallFraction` |  |
| `message` | `final String message` | What is happening, for the progress panel. |
| `elapsed` | `final Duration elapsed` | Since the batch started. |
| `result` | `final RealAssetInfo? result` | The primary asset, from [ImportStage.thumbnail] on. |
| `assets` | `final List<RealAssetInfo> assets` | Every asset the file produced (primary, materials, textures, clips), as the Content Browser lists them, from [ImportStage.thumbnail] on. |
| `error` | `final String? error` | Why it failed ([ImportStage.failed]). |
| `fileName` | `String get fileName` |  |

### `class ImportBatchSummary`

How a batch ended.

**Yapıcı Metotlar (Constructors):**

- `const ImportBatchSummary({required this.batch, required this.total, required this.imported, required this.failed, required this.cancelled, required this.errors,...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `batch` | `final int batch` |  |
| `total` | `final int total` |  |
| `imported` | `final int imported` |  |
| `failed` | `final int failed` |  |
| `cancelled` | `final int cancelled` |  |
| `errors` | `final Map<String, String> errors` | File name → error, for every failed file. |
| `elapsed` | `final Duration elapsed` |  |

### `typedef ImportThumbnailStep`

The UI isolate's last step for a written file (the editor renders its Filament thumbnails here). Gets the file's [ImportStage.thumbnail] event.

### `class ImportQueue`

Imports files in the background: each file is staged and converted — glTF / OBJ / FBX parsing, Assimp, texture decoding and downscaling, the thumbnail's mesh projection — in a long-lived worker isolate, and written there too; the UI isolate only paints the placeholder thumbnails, indexes the new files and runs [thumbnailStep], one short step at a time with the event loop yielded between steps, so the editor keeps drawing frames.

Files go through the same [AssetRepository] steps as [AssetRepository.importExternalFile], so what lands on disk is identical. A file that fails never stops the batch; [cancel] lets the files in flight finish and skips the rest. Each worker loads its own FFI libraries (Assimp); no native pointer or Filament object ever crosses an isolate.

**Yapıcı Metotlar (Constructors):**

- `ImportQueue({required this.projectPath, int workers = 1, this.thumbnailStep, Future<void> Function()? frameYield, AssetRepository? repository,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `maxWorkers` | `static const int maxWorkers` | The most worker isolates a queue runs ([workers]). |
| `projectPath` | `final String projectPath` |  |
| `thumbnailStep` | `ImportThumbnailStep? thumbnailStep` |  |
| `workers` | `int get workers` | How many files convert at once, each in its own worker isolate (1–4). A change applies to the files not yet started. |
| `workers` | `set workers(int value)` |  |
| `progress` | `Stream<ImportProgress> get progress` | Every file's every stage change, in order. |
| `summaries` | `Stream<ImportBatchSummary> get summaries` | One summary per finished batch. |
| `files` | `List<ImportProgress> get files` | The current (or last) batch, one entry per file, in queue order. |
| `isRunning` | `bool get isRunning` |  |
| `isCancelling` | `bool get isCancelling` | Whether [cancel] was called during the current batch. |
| `total` | `int get total` |  |
| `finished` | `int get finished` |  |
| `imported` | `int get imported` |  |
| `failed` | `int get failed` |  |
| `cancelled` | `int get cancelled` |  |
| `overallFraction` | `double get overallFraction` | The batch's progress, 0–1. |
| `elapsed` | `Duration get elapsed` | Since the current (or last) batch started. |
| `lastSummary` | `ImportBatchSummary? get lastSummary` |  |
| `idle` | `Future<void> get idle` | Completes when no file is in flight. |
| `longestMainIsolateStep` | `Duration get longestMainIsolateStep` | The longest stretch any UI-isolate step of the queue held the isolate without yielding ([timeSynchronousSlices]) — the frame-budget figure, kept under 100 ms — and how many steps ran. |
| `mainIsolateSteps` | `int get mainIsolateSteps` |  |
| `longestMainIsolateStepByKind` | `Map<String, Duration> get longestMainIsolateStepByKind` | The longest run of each kind of UI-isolate step in the current batch (`thumbnails`, `index`, `decode`, …), for the smoke report. |
| `enqueue` | `Future<List<ImportProgress>> enqueue(List<ImportRequest> requests)` | Queues [requests] and returns at once; the future completes with each file's final state, in order, once all of them are finished. |
| `cancel` | `void cancel()` | Stops the batch after the files already converting: those finish and keep what they wrote; every file not yet started is cancelled. |
| `dispose` | `Future<void> dispose() async` | Stops the worker isolates. Files in flight are abandoned (their futures complete as cancelled); the queue cannot be used afterwards. |

### `class RemoteImportError`

An error raised in an import worker, carried back as its text.

**Yapıcı Metotlar (Constructors):**

- `const RemoteImportError(this.message)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `timeSynchronousSlices` | `Future<T> timeSynchronousSlices<T>(FutureOr<T> Function() body, void Function(Duration longest) report) async` | Runs [body] and reports the longest stretch it held this isolate without yielding — each synchronous run of its code and of every callback it schedules (future continuations, microtasks), not the time it spent waiting on I/O, other isolates or the engine (a codec, a raster). That is the most a step can delay a frame. |
| `describeImportError` | `String describeImportError(Object error)` | [error] as one readable line (no `Exception:` / `FormatException:` prefix). |

## `lib/data/services/imported_asset_names.dart`

### `abstract final class ImportedAssetNames`

The names an import gives the materials and textures it extracts from a mesh file named [baseName] (prefixes: `M_`, `T_`).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `material` | `static String material(String raw, String baseName)` | `M_Wood` stays, `MI_Wood` → `M_Wood`, a name holding the file's name gets `M_`, anything else becomes `M_<file>_<name>`. |
| `texture` | `static String texture(String raw, String baseName)` | `T_Wood_N` stays, `MI_…`/`M_…` swap the prefix for `T_`, a name holding the file's name gets `T_`, anything else becomes `T_<file>_<name>`. |

## `lib/data/services/level_asset_manifest.dart`

### `abstract final class LuminaLevelAssetManifest`

What a level loads: the assets its placed actors name — meshes, landscapes, sky environments, textures, materials, sounds, animation assets and the Blueprint classes placed in it with the assets their components name. The level code generator emits it as the level class's `assetManifest`; Play-In-Editor builds it from the level `.lmas` found through the project's asset index. Either way a [LuminaLevelPreloader] preloads it. Yerleştirilmiş bir mesh'e atanmış materyal yalnızca çizilebiliyorsa listelenir ([LuminaLevelActorMaterial]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fromActorMaps` | `static List<LuminaAssetRef> fromActorMaps(List<Map<String, dynamic>> actorMaps, {String? projectDir})` | The assets [actorMaps] (`metadata.actors`) name, in first-seen order and without duplicates, as bundle paths (`contents/…`). A placed Blueprint adds its class `.lmas` and — with [projectDir] to read the class from — the assets its components name. |
| `kindOf` | `static LuminaAssetKind kindOf(String path, {String? key})` | The kind of [path], from the key that named it (`staticMeshAsset`, `soundAsset`…) or its extension. |
| `bundlePath` | `static String bundlePath(String path)` | [path] as the game bundle names it: `contents/…` (a path through the project's `contents/` is cut there); any other path as it is. |
| `levelPath` | `static String? levelPath(LuminaAssetIndex index, String levelName)` | The project-relative `.lmas` of level [levelName] (`L_Arena`, `L_Arena.lmas` or `contents/…/L_Arena.lmas`), found through [index] (up to date): `contents/levels/<name>.lmas`, else the level asset of that name anywhere under `contents/`. Null when there is none. |
| `levelNames` | `static List<String> levelNames(LuminaAssetIndex index)` | The names of the project's levels, from [index] (up to date). |
| `forProjectLevel` | `static Future<List<LuminaAssetRef>?> forProjectLevel(String projectDir, String levelName) async` | Level [levelName] of [projectDir]'s asset list for Play-In-Editor: found and read through the asset index (refreshed first), paths absolute (the editor reads the disk). Null when there is no such level. |
| `toDartLiteral` | `static String toDartLiteral(List<LuminaAssetRef> refs, {String indent = ' '})` | [refs] as the `const` list literal a generated level's `assetManifest` holds. |

### `abstract final class LuminaLevelActorMaterial`

Seviyeye yerleştirilmiş bir mesh'in ya da temel şeklin kendi materyali yerine her bölümde çizdiği materyal: aktörün `materialPath` alanı (Details panelinin Material alanı, `set_actor_property material`). Seviye görünümü, Play-In-Editor ve seviye kod üreticisi (`materialOverrideAsset`) bunu buradan okur.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `actorTypes` | `static const Set<String> actorTypes` | `Mesh`, `StaticMesh`, `SkeletalMesh`, `Primitive`. |
| `pathOf` | `static String? pathOf(Map<String, dynamic> actor)` | Atanmış materyal, paket yolu olarak (`contents/…`); atama yoksa, yerleştirilmiş bir Blueprint için ya da `.lmas` / `.filamat` adı taşımayan bir değer için (eski editörlerin yazdığı yer tutucu adlar) null. |
| `problem` | `static String? problem(String path, {String? projectDir})` | Materyalin neden çizilemediği (bulunamadı, derlenmiş materyal yok) ya da null. Üretici o zaman argüman yerine bir yorum yazar, Play ve görünüm bunu günlüğe yazar, mesh kendi materyalini korur. |
| `revision` | `static String revision(String path, {String? projectDir, Iterable<String> textures = const []})` | Seviye görünümünün materyal için çizdiği: materyal dosyasının ve [textures]'ın (sampler'larının dokuları) her birinin değiştirilme zamanı ve boyutu. Değişince görünüm aktörün materyalini yeniden kurar: yeniden derlenince ya da bir doku kaydedilince, yeniden içe aktarılınca veya ayarı değişince. |

## `lib/data/services/lumina_config_dir.dart`

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

## `lib/data/services/lumina_data_dir.dart`

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

## `lib/data/services/mesh_collision_service.dart`

### `class MeshSimpleCollision`

A mesh asset's simple collision: convex [hulls] (imported `UCX_` pieces, then authored convex shapes), authored box / sphere / capsule [primitives], and the authored [complexity].

**Yapıcı Metotlar (Constructors):**

- `const MeshSimpleCollision({this.hulls = const [], this.primitives = const [], this.complexity = complexityDefault,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hulls` | `final List<LuminaCollisionHull> hulls` |  |
| `primitives` | `final List<LuminaCollisionPrimitive> primitives` |  |
| `complexity` | `final String complexity` | The Static Mesh editor's Collision Complexity: [complexityDefault], [complexitySimpleAsComplex] or [complexityComplexAsSimple]. |
| `none` | `static const MeshSimpleCollision none` |  |
| `complexityDefault` | `static const String complexityDefault` | Simple shapes for queries and physics, the mesh triangles for complex traces. |
| `complexitySimpleAsComplex` | `static const String complexitySimpleAsComplex` | Simple shapes for complex traces too. |
| `complexityComplexAsSimple` | `static const String complexityComplexAsSimple` | Per-triangle collision for everything, which the runtime has no shape for; such a mesh plays with its simple shapes. |
| `isEmpty` | `bool get isEmpty` |  |

### `abstract final class MeshCollisionService`

A static mesh asset's simple collision, as the runtime builds it.

The FBX import keeps the `UCX_`/`UBX_`/`USP_`/`UCP_` meshes it strips from the drawn GLB as the asset's `collision_hulls` metadata, in the glTF frame (metres, +Y up, model space). This turns them into authored [LuminaCollisionHull]s (centimetres, Z up), splitting a hull whose triangles form several disconnected pieces into one convex element per piece. The Static Mesh editor's authored shapes (`metadata['collision']`) join them: boxes, spheres and capsules as primitives, convex shapes as hulls — read in cm, Z up, a legacy (glTF metre, Y-up) document converted by [authoredCollisionInCentimetres].

Editor-side only (it reads `.lmas` files): the level code generator bakes the result into the generated level, and Play-In-Editor builds its actors from it. A game never calls it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `metadataKey` | `static const String metadataKey` | The mesh asset metadata key the FBX import writes. |
| `authoredKey` | `static const String authoredKey` | The mesh asset metadata key the Static Mesh editor writes. |
| `minPoints` | `static const int minPoints` | Fewer points than this enclose no volume. |
| `hullsForMeshAsset` | `static List<LuminaCollisionHull> hullsForMeshAsset(String meshAssetPath, {String? projectDir})` | The convex hulls of the mesh asset at [meshAssetPath] (imported `UCX_` pieces and authored convex shapes); see [simpleCollisionForMeshAsset]. |
| `simpleCollisionForMeshAsset` | `static MeshSimpleCollision simpleCollisionForMeshAsset(String meshAssetPath, {String? projectDir})` | The simple collision of the mesh asset at [meshAssetPath]: an absolute path, or a project path (`contents/…`) resolved under [projectDir]. [MeshSimpleCollision.none] for a mesh without any, a file that is not a `.lmas`, or one that cannot be read. Cached per file until its size or modification time changes. |
| `simpleCollisionFromMetadata` | `static MeshSimpleCollision simpleCollisionFromMetadata(Map<String, String> metadata)` | A mesh asset's simple collision from its [metadata]: the imported `collision_hulls` ([hullsFromMetadata]) and the authored `collision` document. |
| `authoredCollisionInCentimetres` | `static Map<String, dynamic> authoredCollisionInCentimetres(Map<String, dynamic> json)` | A stored `collision` document in the authoring frame (cm, Z up). |
| `hullsFromMetadata` | `static List<LuminaCollisionHull> hullsFromMetadata(Map<String, String> metadata)` | Parses the `collision_hulls` entry of a mesh asset's [metadata]. |
| `toAuthoring` | `static List<double> toAuthoring(double x, double y, double z)` | A glTF point (metres, Y up) in the authoring frame (cm, Z up), with float noise from the unit conversion rounded away. |
| `connectedPieces` | `static List<List<int>> connectedPieces(List<double> points, List<int> triangles)` | Groups the vertices of a triangle mesh into its connected pieces. Vertices at the same position are one vertex (Assimp splits a hull's corners by face normal); vertices no triangle uses are left out. |

## `lib/data/services/mesh_physics_service.dart`

### `abstract final class MeshPhysicsService`

A static mesh asset's physics as the Static Mesh editor stores it (`metadata.physics = {massKg, centerOfMassOffset}`): what a simulating component inherits unless it overrides its mass.

Editor-side only (it reads `.lmas` files): Play-In-Editor sets `LuminaBlueprintComponents.meshPhysicsResolver` to [forMeshAsset]; a generated game uses the values the editor baked into the component.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `metadataKey` | `static const String metadataKey` | The mesh asset metadata key the Static Mesh editor writes. |
| `forMeshAsset` | `static LuminaMeshPhysics? forMeshAsset(String meshAssetPath, {String? projectDir})` | The physics of the mesh asset at [meshAssetPath] (absolute, or a project path resolved under [projectDir]); null for a file that is not a readable `.lmas` or has no `physics` metadata. Cached per file until its size or modification time changes. |
| `fromMetadata` | `static LuminaMeshPhysics? fromMetadata(Map<String, String> metadata)` | The physics in a mesh asset's [metadata]; null without any. |

## `lib/data/services/plugin_pack_script.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kPluginPackScriptFileName` | `const String kPluginPackScriptFileName` | Where the script lives in a plugin (under `tool/`). |
| `kPluginPackScriptPath` | `const String kPluginPackScriptPath` | The plugin-relative path of the script. |
| `kPluginPackScript` | `const String kPluginPackScript` | The script's source. |

## `lib/data/services/project_engine_link.dart`

### `class ProjectEngineLink`

How a game project reaches the engine.

The project's `pubspec.yaml` depends on `lumina` through git ([kLuminaGitUrl], `path: lumina`), so it is committable and builds on any machine once the LuminaGame repos are published. One of two things makes it build on the machine of the engine checkout the editor runs from:

- a gitignored `pubspec_overrides.yaml` pinning `lumina` and every package of its path/git closure (`flutter_filament`, the tools packages, …) to the local checkout (absolute `/`-separated paths: the project folder and the engine are on unrelated paths, often on different drives); each local package's hook then finds Filament through its own `../filament`; - or, building against git, `hooks: user_defines:` in `pubspec.yaml` telling the native-assets hooks of flutter_filament / flutter_assimp / flutter_riglogic where this machine's Filament build, libc++ and RigLogic library are. A package resolved from git (a pub-cache checkout) has no `../filament` beside it. The hooks runner reads user-defines from the root `pubspec.yaml` only (pub rejects a `hooks` key in `pubspec_overrides.yaml`), so this block holds machine paths; it is rewritten whenever the project is linked again.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `overridesFileName` | `static const String overridesFileName` |  |
| `hookedPackages` | `static const List<String> hookedPackages` | The packages whose hooks take the settings [hookUserDefines] writes. |
| `hooksMarker` | `static const String hooksMarker` | The first line of the generated `hooks:` comment, found again on every relink. |
| `engineDependency` | `static String engineDependency({String indent = ' ', String? ref, String? url})` | The git form of the engine dependency (no trailing newline), from [url] at [ref]. Both default to the engine checkout the editor fetched for its release ([LuminaWorkspace.engineRepo], [LuminaWorkspace.engineCommit]), so a project generated by a release editor builds against that exact commit; from a source workspace the URL is [kLuminaGitUrl] and there is no `ref:` (the default branch). |
| `localEngineRoot` | `static String? localEngineRoot({String? luminaPackageDir})` | The engine workspace root holding [luminaPackageDir] (default [LuminaWorkspace.package]`('lumina')`), or null when it is not a local checkout (no `lumina/pubspec.yaml` there). |
| `localPackages` | `static Map<String, String> localPackages(String engineRoot, {void Function(String)? onLog})` | `lumina` and every package of its path/git closure as [engineRoot] resolved them (name → absolute dir). When the closure cannot be walked (the engine was never `pub get`-ed), only `lumina` and the `flutter_filament` beside it. |
| `overridesYaml` | `static String overridesYaml(Map<String, String> packages, String engineRoot)` | The `pubspec_overrides.yaml` pinning [packages] (name → dir). |
| `hookUserDefines` | `static Map<String, Map<String, String>> hookUserDefines(String engineRoot, {Map<String, String>? packages})` | The hook settings (package → key → the dir's `file:` URI) for this machine: the engine workspace's own `hooks: user_defines:` (relative to its root pubspec), `<engine>/filament` when it names no Filament, and the built RigLogic library of the flutter_riglogic [packages] resolves to. Only directories that exist are kept. |
| `withHookUserDefines` | `static String withHookUserDefines(String pubspec, Map<String, Map<String, String>> defines, {bool anyBlock = f...` | [pubspec] with the `hooks:` block this class wrote (under [hooksMarker]; with [anyBlock], any top-level `hooks:` block) replaced by [defines], or removed when [defines] is empty; the new block is appended at the end. A `hooks:` block of the user's own is kept, and then none is added (a second top-level key would be invalid YAML). |
| `withGitEngineDependency` | `static String withGitEngineDependency(String pubspec, {String? ref})` | [pubspec] with its `lumina:` dependency in the git form (added under `dependencies:` when missing); a `path:` or other source is replaced. The git `ref:` is [ref], else the release commit [engineDependency] defaults to; with neither, a `ref:` the existing dependency already has is kept (a source-workspace editor does not unpin a project a release editor pinned). |
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

## `lib/data/services/thumbnail_sidecar_migration.dart`

### `class ThumbnailSidecarMigrationReport`

What [ThumbnailSidecarMigration.run] did to one project.

**Yapıcı Metotlar (Constructors):**

- `const ThumbnailSidecarMigrationReport({this.removedDirectories = 0, this.removedSidecars = 0, this.reembedded = 0, this.restamped = 0, this.coverMoved = false,...`
- `factory ThumbnailSidecarMigrationReport.fromJson(Map<String, dynamic> json)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `removedDirectories` | `final int removedDirectories` | `.thumbnails/` directories deleted. |
| `removedSidecars` | `final int removedSidecars` | Sidecar PNGs deleted. |
| `reembedded` | `final int reembedded` | `.lmas` files that had no embedded thumbnail and got the sidecar's. |
| `restamped` | `final int restamped` | `.lmas` whose current thumbnail was re-stamped for the new staleness rule (its modification time set back to the thumbnail stamp). |
| `coverMoved` | `final bool coverMoved` | Whether `contents/.thumbnails/cover.png` moved to `.lumina/cover.png`. |
| `gitignoreRules` | `final List<String> gitignoreRules` | Rules appended to the project's `.gitignore`. |
| `elapsed` | `final Duration elapsed` |  |
| `didAnything` | `bool get didAnything` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class ThumbnailSidecarMigration`

The one-time move away from `.thumbnails/` sidecar files.

Every `contents/**/.thumbnails/<name>.png` is checked against its `<name>.lmas`: an asset with no embedded thumbnail gets the sidecar's (re-embedded), an asset whose thumbnail was current under the old rule (sidecar not older than the `.lmas` nor its `.entity.glb`) is re-stamped so it stays current under the new one ([ThumbnailService.staleFor]), and then the sidecars and their folders are deleted. `contents/.thumbnails/cover.png` moves to `.lumina/cover.png`. An existing `.gitignore` gains `.lumina/` and `**/.thumbnails/` when it lacks them. Idempotent: a migrated project has nothing left to do.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `sidecarDirectoryName` | `static const String sidecarDirectoryName` |  |
| `legacyCoverPath` | `static const String legacyCoverPath` |  |
| `coverPath` | `static const String coverPath` |  |
| `gitignoreRules` | `static const List<String> gitignoreRules` |  |
| `sidecarDirectories` | `static List<Directory> sidecarDirectories(String projectDir)` | Every `.thumbnails/` folder under `<projectDir>/contents`. |
| `run` | `static ThumbnailSidecarMigrationReport run(String projectDir)` |  |
| `ensureGitignoreRules` | `static List<String> ensureGitignoreRules(String projectDir)` | Appends the [gitignoreRules] an existing `.gitignore` of [projectDir] lacks; returns what it appended. |

## `lib/data/services/umg_widget_library_service.dart`

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

## `lib/data/services/web_loading_screen_service.dart`

### `class WebLoadingScreenReport`

What [WebLoadingScreenService.write] did.

**Yapıcı Metotlar (Constructors):**

- `const WebLoadingScreenReport({this.files = const [], this.logoFile, this.warnings = const [], this.skippedReason})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `files` | `final List<String> files` | Written files, relative to the project (or to the preview folder). |
| `logoFile` | `final String? logoFile` | The logo's file name next to `index.html`, or null (no logo). |
| `warnings` | `final List<String> warnings` | Why the logo could not be used, and similar non-fatal notes. |
| `skippedReason` | `final String? skippedReason` | Set when nothing was written (the project has no `web/` platform folder). |
| `written` | `bool get written` |  |

### `abstract final class WebLoadingScreenService`

Generates a web build's loading screen from the project's [ProjectWebLoadingStyle]: `web/index.html`, `web/loading.css`, `web/loading.js`, `web/flutter_bootstrap.js` and the logo.

The page is plain HTML/CSS/JS with nothing from another origin (no fonts, no CDN): it shows from the first byte, before any Flutter code arrives. - `loading.js` wraps `window.fetch` to count the bytes of the engine's wasm and of flutter_filament's module as they stream in, and wraps `_flutter.loader.load` (called from the generated `flutter_bootstrap.js` template, which Flutter fills in at build time) to follow the engine's start; - it exposes `window.luminaLoading.progress(fraction, label)`, which the generated `main()` calls through [LuminaWebLoading] for the renderer and the asset preload; - it fades the screen out on Flutter's `flutter-first-frame` event.

Packaging (Package Project, Cook & Package) writes these files into the project's `web/` before `flutter build web`; `index.html` is regenerated every time, so edits go in Project Settings, not in the file.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `generatedNotice` | `static const String generatedNotice` |  |
| `logoBaseName` | `static const String logoBaseName` |  |
| `write` | `static WebLoadingScreenReport write({required String projectDir, required LuminaProject project, Uint8List? ic...` | Writes the loading screen into `<projectDir>/web` (or [outDir]). |
| `indexHtml` | `static String indexHtml(ResolvedWebLoadingStyle style, {required String? logoFile, bool preview = false, Strin...` | The page: the loading screen's markup over the Flutter app. |
| `loadingCss` | `static String loadingCss(ResolvedWebLoadingStyle style)` |  |
| `loadingJs` | `static String loadingJs(ResolvedWebLoadingStyle style, {bool preview = false})` | The loading screen's script. [LuminaWebLoading.rendererStart] and [LuminaWebLoading.rendererEnd] are the phase boundaries the generated `main()` reports against. |
| `flutterBootstrapJs` | `static String flutterBootstrapJs()` | The `web/flutter_bootstrap.js` template: Flutter substitutes its loader and build config at build time; the loading screen is attached to the loader before it starts. |

## `lib/data/services/workspace_paths.dart`

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

---

[Önceki: Veri katmanı: use case'ler ve servisler (devamı, bölüm 2)](data-services-continued-2.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Veri katmanı: modeller ve repository'ler](data-models.md)
