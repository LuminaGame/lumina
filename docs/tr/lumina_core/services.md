[English](../../en/lumina_core/services.md)

# Servisler

Saf servisler, birinci bölüm: animasyon yazımı ve GLB animasyon araçları, asset indeksi, config dosyaları, Dart tanımlayıcıları, proje editörü build önbelleği ve parmak izi, engine kaynak kopyalama, engine kurulumu ve kimliği, engine logger, FBX yardımcıları ve oyun şablonları. Dosya yolları `lumina_core/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/services/animation_import_binder.dart`](#libsrcservicesanimation_import_binderdart)
- [`lib/src/services/asset_index.dart`](#libsrcservicesasset_indexdart)
- [`lib/src/services/authored_animation_clip.dart`](#libsrcservicesauthored_animation_clipdart)
- [`lib/src/services/authored_animation_writer.dart`](#libsrcservicesauthored_animation_writerdart)
- [`lib/src/services/authored_pose_tools.dart`](#libsrcservicesauthored_pose_toolsdart)
- [`lib/src/services/auto_save_timer_service.dart`](#libsrcservicesauto_save_timer_servicedart)
- [`lib/src/services/config_json_file.dart`](#libsrcservicesconfig_json_filedart)
- [`lib/src/services/dart_identifiers.dart`](#libsrcservicesdart_identifiersdart)
- [`lib/src/services/editor_build_cache.dart`](#libsrcserviceseditor_build_cachedart)
- [`lib/src/services/editor_build_fingerprint.dart`](#libsrcserviceseditor_build_fingerprintdart)
- [`lib/src/services/editor_source_vendor_service.dart`](#libsrcserviceseditor_source_vendor_servicedart)
- [`lib/src/services/encoded_image_format.dart`](#libsrcservicesencoded_image_formatdart)
- [`lib/src/services/engine_bootstrap.dart`](#libsrcservicesengine_bootstrapdart)
- [`lib/src/services/engine_identity.dart`](#libsrcservicesengine_identitydart)
- [`lib/src/services/engine_logger_service.dart`](#libsrcservicesengine_logger_servicedart)
- [`lib/src/services/fbx_material_mapper.dart`](#libsrcservicesfbx_material_mapperdart)
- [`lib/src/services/fbx_texture_locator.dart`](#libsrcservicesfbx_texture_locatordart)

## `lib/src/services/animation_import_binder.dart`

### `class SkeletonCandidate`

A project skeletal mesh an imported animation could play on.

**Yapıcı Metotlar (Constructors):**

- `const SkeletonCandidate(this.lmasPath, this.match)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `lmasPath` | `final String lmasPath` | `contents/...lmas`, relative to the project. |
| `match` | `final GlbSkeletonMatch match` |  |

### `class AnimationBinding`

Where an imported animation ended up on its skeletal mesh.

**Yapıcı Metotlar (Constructors):**

- `const AnimationBinding({required this.meshLmasPath, required this.meshAssetId, required this.clips})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshLmasPath` | `final String meshLmasPath` |  |
| `meshAssetId` | `final String meshAssetId` |  |
| `clips` | `final List<GlbRetargetResult> clips` | Retargeting details per clip, in clip order. |

### `abstract final class AnimationImportBinder`

Binds imported animation clips to a project skeletal mesh.

gltfio only plays animations stored in the asset whose nodes they move, so an animation-only import (an Unreal `AS_*.FBX`: skeleton + keys, no mesh) is retargeted onto a skeletal mesh and appended to that mesh's GLB — the `.entity.glb` companion and, when the mesh `.lmas` embeds one, its payload — the way the Third Person template bundles its clips (`tool/build_third_person_content.dart`).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `minimumAutoScore` | `static const double minimumAutoScore` | Least share of the clip's animated bones a skeleton must have to be picked automatically. |
| `meshGlb` | `static Uint8List? meshGlb(String lmasAbsolutePath)` | The GLB a skeletal mesh asset draws: its `.entity.glb` companion, else the `.lmas` payload. |
| `rankTargets` | `static List<SkeletonCandidate> rankTargets({required String projectPath, required List<String> skeletalMeshLma...` | Scores every skeletal mesh in [skeletalMeshLmasPaths] (project-relative) against [clipGlb]'s first animation, best first. Meshes whose GLB cannot be read are left out. |
| `pickTarget` | `static SkeletonCandidate? pickTarget({required String projectPath, required List<String> skeletalMeshLmasPaths...` | The best of [rankTargets] when it clears [minimumAutoScore] with at least three matched bones. |
| `bind` | `static AnimationBinding bind({required String projectPath, required String meshLmasPath, required Uint8List cl...` | Retargets every animation of [clipGlb] onto the skeletal mesh at [meshLmasPath] (project-relative) as [clipNames] (one per animation), writes the mesh's GLB back (companion and embedded payload) and lists the clips in the mesh's `animation_clips` metadata. |
| `clipMetadata` | `static Map<String, String> clipMetadata(String meshLmasPath, GlbRetargetResult result)` | Metadata of an animation asset bound to [meshLmasPath] as clip [result] — the same keys the Third Person template's clip assets carry, so the Animation editor and Animation Blueprints resolve it the same way. |

## `lib/src/services/asset_index.dart`

### `class AssetIndexEntry`

One `.lmas` of a project as the asset index knows it: its project-relative path, the size and modification time the summary was read at, and the summary.

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexEntry({required this.projectDir, required this.path, required this.size, required this.modifiedMs, required this.summary,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `path` | `final String path` | Project-relative, `/`-separated (`contents/meshes/static/SM_Rock.lmas`). |
| `size` | `final int size` |  |
| `modifiedMs` | `final int modifiedMs` | Modification time in ms since epoch. |
| `summary` | `final LuminaAssetSummary summary` |  |
| `projectDir` | `final String projectDir` | The project the entry belongs to (absolute). |
| `absolutePath` | `String get absolutePath` |  |
| `file` | `File get file` |  |
| `fileName` | `String get fileName` | `SM_Rock.lmas`. |
| `baseName` | `String get baseName` | `SM_Rock`: the class / asset name callers key by. |
| `modified` | `DateTime get modified` |  |
| `type` | `AssetType get type` |  |
| `metadataValue` | `String? metadataValue(String key)` | `metadata[key]`, read from the file when the index left a large value out. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class AssetIndexChange`

What one refresh changed (project-relative paths).

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexChange({this.added = const [], this.changed = const [], this.removed = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `added` | `final List<String> added` |  |
| `changed` | `final List<String> changed` |  |
| `removed` | `final List<String> removed` |  |
| `isEmpty` | `bool get isEmpty` |  |

### `class AssetIndexRefreshStats`

How the last refresh went — the seam tests use to prove an unchanged project is only stat'ed.

**Yapıcı Metotlar (Constructors):**

- `const AssetIndexRefreshStats({this.files = 0, this.decoded = 0, this.removed = 0, this.elapsed = Duration.zero, this.offThread = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `files` | `final int files` |  |
| `decoded` | `final int decoded` |  |
| `removed` | `final int removed` |  |
| `elapsed` | `final Duration elapsed` |  |
| `offThread` | `final bool offThread` |  |

### `class LuminaAssetIndex`

A project's asset index (asset registry): every `.lmas` under `contents/` with its id, name, type, metadata, references, thumbnail stamps and companion-file times, read without decoding payloads and persisted to `<project>/.lumina/asset_index.json`.

The index is derived data: never the source of truth, always rebuildable. Entries are keyed by project-relative path and validated by size and modification time; [refresh] stats every file and decodes only new or changed ones, in an isolate pool, then drops deleted ones and saves the file atomically. A missing, corrupt or older-format index file rebuilds.

One instance per project directory ([open]); every scan of the editor (content browser, class catalogs, Blueprint registries, PIE, code generation) reads it instead of decoding every `.lmas`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `formatVersion` | `static const int formatVersion` | Bumped whenever the stored summary changes shape. |
| `directoryName` | `static const String directoryName` |  |
| `fileName` | `static const String fileName` |  |
| `open` | `static LuminaAssetIndex open(String projectDir)` | The index of [projectDir] (shared by every caller in this isolate). |
| `close` | `static void close(String projectDir)` | Forgets the in-memory instance of [projectDir] (the file stays). |
| `projectDir` | `final String projectDir` |  |
| `file` | `File get file` | `<project>/.lumina/asset_index.json`. |
| `changes` | `Stream<AssetIndexChange> get changes` | Incremental updates: what each refresh added, changed and removed. |
| `lastRefreshStats` | `AssetIndexRefreshStats get lastRefreshStats` |  |
| `isLoaded` | `bool get isLoaded` | Whether [refresh] / [refreshSync] ran at least once in this session. |
| `entries` | `List<AssetIndexEntry> get entries` | Every indexed asset, sorted by path. |
| `summaries` | `List<LuminaAssetSummary> get summaries` |  |
| `byType` | `List<AssetIndexEntry> byType(AssetType type)` |  |
| `byPath` | `AssetIndexEntry? byPath(String path)` | The entry of [path] (project-relative or absolute), or null. |
| `blueprintDocuments` | `List<AssetIndexEntry> blueprintDocuments(String kind)` | Actor assets whose Blueprint document is of [kind] (`class`, `enum`, `interface`, `save_game`, `montage`, …), sorted by path. |
| `relativePathOf` | `String relativePathOf(String path)` | [path] relative to the project, `/`-separated. |
| `refresh` | `Future<AssetIndexChange> refresh({int? workers, bool? offThread})` | Brings the index up to date with `contents/`: stats every `.lmas` (and its companions), decodes the summaries of new or changed files in an isolate pool, drops deleted files and saves the index when anything changed. Concurrent calls share one refresh. |
| `refreshPaths` | `AssetIndexChange refreshPaths(Iterable<String> paths)` | Indexes just [paths] (`.lmas` files, project-relative or absolute) — what an import just wrote — without walking `contents/`: each is stat'ed and summarised, its companions read from one listing of its folder, and the change is saved and broadcast on [changes]. A listed path that no longer exists is dropped. |
| `offThreadBytes` | `static const int offThreadBytes` | Bytes of `.lmas` to summarise from which [refresh] uses isolates. |
| `shouldSummarizeOffThread` | `static bool shouldSummarizeOffThread(int bytes)` | Whether summarising files totalling [bytes] belongs off the UI isolate. |
| `refreshSync` | `AssetIndexChange refreshSync()` | [refresh] on the calling isolate, for synchronous callers: cheap when the index is warm (stats only), a full summary pass when it is cold. |
| `thumbnailOf` | `Uint8List? thumbnailOf(AssetIndexEntry entry)` | [entry]'s embedded thumbnail, read from its byte range (no payload decode) and kept in memory until the file changes. A texture without one shows its image. Null when the asset has none. |

## `lib/src/services/authored_animation_clip.dart`

Editörde oluşturulan bir Animation Sequence (Content Browser ▸ New ▸ Animation Sequence, ardından Animation editöründe kemik kemik pozlanır): kemiklerin translation / rotation / scale kanallarında tam karelerdeki anahtarlar. Animasyon `.lmas` dosyası onu JSON olarak (`authored_clip`), editörün birebir kaynağı olarak saklar; `GlbAuthoredClipWriter` onu her oynatıcının kullandığı glTF animasyonuna çevirir.

### `enum AuthoredInterpolation`

Bir kanalın anahtarları arasında nasıl ilerlediği: `linear` (`LINEAR`; dönüşler en kısa yoldan slerp), `step` (`STEP`, önceki anahtarı tutar) ve `cubic` (sıfır giriş / çıkış teğetleriyle yazılan `CUBICSPLINE`: her anahtarda yumuşak giriş ve çıkış). gltfio spline teğetlerini anahtar aralığıyla değil interpolantla ölçekler; bu yüzden düz teğetler, onun ve glTF belirtiminin aynı biçimde hesapladığı tek cubic biçimidir. glTF anahtar başına değil kanal başına interpolasyon yapar. `gltfName`, `label`, `fromGltf`, `fromLabel`.

### `class BoneTrs`

Bir kemiğin yerel dönüşümü (glTF düğüm TRS): `t`, `r` (quaternion), `s`; `toMatrix`, `toList` (`[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]`, `SubEditor3DViewport.jointLocalPose`'un aldığı biçim), `channel(path)`, `withChannel(path, values)`, `static BoneTrs blend(a, b, w)` (öteleme ve ölçek doğrusal, dönüş en kısa yoldan slerp; poz kütüphanesinin ağırlığı).

### `class AuthoredChannel`

Bir kemiğin animasyonlu bir özelliği: `path` (`translation` / `rotation` / `scale`), `interpolation`, `keys` (kare → 3 değer, dönüş için 4: `x y z w`). `setKey`, `removeKey`, `moveKey` (indiği yerdeki anahtarın yerini alır), `copy`, JSON. `sample(frame)` kanalı gltfio animatörünün yaptığı gibi hesaplar: anahtarlı aralığın dışında uç anahtarlar tutulur, `STEP` önceki anahtarı tutar, translation / scale doğrusal, rotation slerp, cubic yumuşak (bileşen bileşen, dönüş için normalize); dönüş anahtarları önce, yazıcının sakladığı gibi, tek yarıküreye getirilir.

### `class AuthoredAnimationClip`

`name` (glTF animasyon adı), `frameRate`, `lengthFrames`, `duration`, `tracks` (kemik → yol → kanal), `bones` (anahtarı olanlar). `setKey(bone, path, frame, values)` (0 ≤ kare ≤ `lengthFrames`), `hasKey`, `removeKey` / `moveKey` (tek kanal ya da kemiğin tüm kanalları), `keyFrames(bone)`, `sample(bone, path, t)`, `samplePose(skeleton, t)` (her düğümün yerel dönüşümü: dinlenme pozunun üzerinde anahtarlı kanallar), `copy`, `toJson` / `fromJson` / `encode` / `decode` (birebir gidiş-dönüş; eşitlik JSON'u karşılaştırır).

### `class GlbSkeleton`

Deri (skin) içeren bir GLB'nin düğüm hiyerarşisi: `names`, `parent`, `rest(node)`, `joints` (tüm skin'lerin eklemleri), `order` (ebeveynler çocuklardan önce), `root` (en üstteki skin eklemi), `rootChild` (onun altında en çok alt düğümü olan eklem: pelvis), `indexOf`, `isJoint`, `worldMatrices(pose)` (GLB'nin çerçevesi: metre, Y yukarı). `GlbSkeleton.fromGlb(bytes)` / `fromJson(gltfJson)`.

## `lib/src/services/authored_animation_writer.dart`

### `abstract final class GlbAuthoredClipWriter`

`write({meshGlb, clip, int? index}) → ({Uint8List glb, int clipIndex})`: `clip`'i `clip.name` adlı animasyon olarak içeren mesh GLB'si; aynı adlı bir animasyon varsa yerinde değiştirilir (dosyanın kullandığı her eklenti referanslarını yeniden eşleyebildiği türdense eski accessor'ları, buffer view'ları ve ikili verisi atılıp parça sıkıştırılır), yoksa sona eklenir. Her skin eklemi bir kanal alır: klibin anahtarı olan yerde anahtarlar, diğerlerinde dinlenme rotation + translation değeri (`[0, duration]` boyunca sabit); böylece klip, başka bir klipten sonra da tüm iskeleti tanımlar. Tek anahtarlı bir kanal iki anahtarla tutulur (gltfio ikiden az zamanı olan sampler'ları atlar). GLB olmayan girdi, birden fazla buffer, skin yokluğu, mesh'te olmayan bir kemik (adıyla) ya da klip dışındaki bir anahtar için `FormatException` fırlatır. Yeni bir animasyon, `index` verilmişse oraya (sınırlanarak; kaldırılmış bir klibi eski yerine koymak için), yoksa sona eklenir.

`remove({meshGlb, clipName}) → ({Uint8List glb, int clipIndex})?`: o animasyon ile yalnızca onun kullandığı accessor'lar, buffer view'lar ve ikili veri olmadan mesh GLB'si (değiştirmedeki sıkıştırmanın aynısı; boş kalan `animations` listesi atılır) ve animasyonun eski indeksi; o adda animasyon yoksa null.

### `abstract final class AuthoredAnimationStore`

Bir projedeki oluşturulmuş sekanslar; Third Person şablonunun ve bağlanmış bir FBX içe aktarımının klipleri gibi saklanır: klip iskelet mesh'in GLB'sinde (`.entity.glb` eşi ve varsa mesh `.lmas` payload'ı), adı mesh'in `animation_clips` listesinde, ve ona işaret eden payload'sız bir animasyon `.lmas` dosyası (`source_mesh`, `clip_name`, `clip_index`, `anim_properties`, `duration_seconds`, `length_frames`, bir `skeletal_mesh` referansı) ile birlikte `authored: true` ve `authored_clip`. Anim Blueprint'ler, Blend Space'ler, montajlar, Play-In-Editor ve üretilen oyun onu gltfio üzerinden adıyla, değiştirmeden oynatır.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `create` | `static String create({required String projectDir, required String meshRelPath, required String name, required int lengthFrames, double frameRate = 30.0, String? folder})` | Mesh için yeni bir sekans ([folder] verilmezse `contents/animations/<Mesh>/<name>.lmas`); ad, mesh'in klipleri ve klasörün dosyaları arasında benzersiz yapılır; iskelet kökünün dinlenme translation ve rotation değeri 0. karede anahtarlanır. Proje göreli yolu döndürür. |
| `save` | `static LuminaAsset save({required String projectDir, required String animationRelPath, required AuthoredAnimationClip clip, Map<String, String>? metadata, List<AssetReference>? references})` | Klibi mesh GLB'sine (aynı indeks) ve `.lmas` dosyasına yazar (editörün diğer metadata'sı korunur). |
| `load` | `static AuthoredAnimationClip? load(String projectDir, String animationRelPath)` | Oluşturulmuş klip; içe aktarılmış bir klip için null. |
| `detach` | `static bool detach(String projectDir, String animationRelPath)` | Sekansın `.lmas` dosyası projeden çıkmadan önce klibini mesh'inden (GLB eşi, payload, `animation_clips`) çıkarır; `.lmas` dosyasına dokunmaz. İçe aktarılmış klip için ya da mesh veya klip yoksa false. Editörün çöp kutusu, oluşturmayı geri alma ve Delete işlemleri bunu çağırır. |
| `attach` | `static bool attach(String projectDir, String animationRelPath)` | Geri getirilen bir sekansın klibini mesh'ine `clip_index` konumunda geri koyar (`.lmas` yalnızca klip başka bir yere düşerse yeniden yazılır). İçe aktarılmış klip, olmayan mesh ya da o klibe zaten sahip mesh için false. |
| `isAuthored` / `clipOf` | `static bool isAuthored(LuminaAsset? asset)` / `static AuthoredAnimationClip? clipOf(LuminaAsset? asset)` | Bir animasyon varlığının burada oluşturulup oluşturulmadığı ve klibi. |

## `lib/src/services/authored_pose_tools.dart`

Oluşturulmuş klipler için pozlama yardımcıları; Animation editörünün Pose sekmesi kullanır. Tüm pozlar üzerinde (`Map<int, BoneTrs>`, düğüm → yerel dönüşüm) GLB çerçevesinde (glTF metre, +Y yukarı) çalışırlar ve sıradan yerel dönüşümler üretirler; sonuç aynı FK glTF klibi olarak anahtarlanır ve kaydedilir.

### `class SkeletonMirror`

Bir `GlbSkeleton`'ın sol / sağ kemik çiftleri ve yansıtıldıkları sagital düzlem; dinlenme pozundan bulunur (düzlemin normali eşleşen kemiklerin ortalama sağdan sola yönü, noktası ortalama orta noktalarıdır).

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mirroredName` | `static String? mirroredName(String name)` | Diğer tarafın adı, geleneklere göre: `_l`/`_r`, `_L`/`_R`, `.l`/`.r`, `.L`/`.R` sonekleri, `l_`/`r_` önekleri, `Left`/`Right` sözcükleri; tarafı olmayan ad için null. |
| `of` | `factory SkeletonMirror.of(GlbSkeleton skeleton, {Map<String, String> overrides = const {}})` | Tablo: iki kemiğin de bulunduğu yerde ada göre çiftler; kullanıcının [overrides] çiftleri (her iki yönde) önce gelir. |
| `pairs` / `lateralAxis` / `planePoint` | alanlar | Kemik → eşi (iki yönde); düzlemin birim normali; düzlem üzerinde bir nokta. |
| `partnerOf` | `String partnerOf(String bone)` | Eşi; düzlem üzerindeki kemik için kendisi. |
| `mirrorVector` / `mirrorPoint` / `mirrorRotation` | `Vector3 mirrorVector(Vector3 v)` / `Vector3 mirrorPoint(Vector3 p)` / `Quaternion mirrorRotation(Quaternion q)` | Bir ofsetin, bir konumun ve bir dünya dönüşünün yansıması (`S·R·S`: yansıyan eksen, ters yönde). |
| `mirror` | `Map<int, BoneTrs> mirror({required Map<int, BoneTrs> source, required Map<int, BoneTrs> target, required Iterable<String> bones})` | [source] içinde pozlanmış [bones] kemiklerinin ayna görüntüsünü [target] üzerinde eşlerine koyan yerel dönüşümler: her eş, kaynağı dinlenme pozundan nasıl döndüyse öyle döner (yansıtılmış, dünya uzayında); öteleme almış bir kaynak eşini yansıtılmış ofset kadar taşır; ölçek kopyalanır; ebeveynler çocuklardan önce çözülür. Değişen düğümleri döndürür. |

### `class TwoBoneIkChain`

`TwoBoneIkChain(name, upper, lower, end)`: düğüm indeksiyle bir uzuv. `static List<TwoBoneIkChain> detect(GlbSkeleton)`, ebeveyni ve büyük ebeveyni eklem olan, el ya da ayak gibi adlandırılmış ve tarafı olan bir uç efektörden (`hand_l`, `LeftFoot`, `foot.R`, `l_hand`) `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg` zincirlerini bulur.

### `abstract final class TwoBoneIkSolver`

`static Map<int, BoneTrs> solve({required GlbSkeleton skeleton, required Map<int, BoneTrs> pose, required TwoBoneIkChain chain, required Vector3 target, Vector3? pole, bool keepEndRotation = true})`: hedef ile pole'un düzleminde kosinüs teoremi ([pole] null ise zincirin mevcut bükülmesi); hedef zincirin erişimine sınırlanır. Üst ve alt kemik için (ve [keepEndRotation] ile dünya yönelimini koruyarak uç efektör için) yeni yerel dönüşümler döndürür; yalnızca dönüşler değişir.

### `abstract final class RootMotionAuthoring`

Yukarı yön glTF +Y'dir.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `extractFromPelvis` | `static bool extractFromPelvis(AuthoredAnimationClip clip, GlbSkeleton skeleton)` | Kök ya da pelvis öteleme anahtarı olan her karede iskelet kökünü konumuna, pelvisin ilk kareden bu yana yatay yolunu ekleyerek anahtarlar; pelvisi (`GlbSkeleton.rootChild`) onun üzerinde aynı dünya konumunda anahtarlar, böylece pelvis yalnızca dikey hareketini korur; kök kanalı pelvis kanalının interpolasyonunu alır. Pelvisin öteleme anahtarı yoksa false. |
| `zeroRoot` | `static bool zeroRoot(AuthoredAnimationClip clip, GlbSkeleton skeleton)` | Tersi: kökün ötelemesi dinlenme değerine döner (0. karede tek anahtar) ve pelvis dünyada bulunduğu yerde anahtarlanır. Kökün öteleme anahtarı yoksa false. |

### `class AuthoredPose`, `class AuthoredPoseLibrary`, `abstract final class AuthoredPoseLibraryStore`

`AuthoredPose(name, bones)`: kemik adına göre yerel dönüşümler (`renamed`, JSON). `AuthoredPoseLibrary({meshRelPath, poses, mirrorOverrides})`: bir iskelet mesh'in pozları ve elle ayarlanmış ayna çiftleri (`pose(name)`, `copy`, JSON). `AuthoredPoseLibraryStore`: `pathFor(meshRelPath)` (`contents/animations/<Mesh>/PoseLibrary.lmas`), `load(projectDir, meshRelPath)` (yoksa boş), `save(projectDir, library)` (JSON payload'lı ve `pose_library: true`, `source_mesh`, `pose_count` metadata'lı bir `AssetType.unknown` `.lmas`), `isLibrary(asset)`.

## `lib/src/services/auto_save_timer_service.dart`

### `class AutoSaveTimerService`

`AutoSaveTimerService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onPerformSave` | `SaveCallback onPerformSave` | `onPerformSave` alanını (field/property) ve ilişkili veriyi saklar. |
| `stop` | `void stop()` | `stop` işlemini gerçekleştirir. |
| `checkAndExecuteAutoSave` | `Future<LuminaProject> checkAndExecuteAutoSave(LuminaProject project)` | `checkAndExecuteAutoSave` işlemini gerçekleştirir. |

## `lib/src/services/config_json_file.dart`

### `class ConfigJsonFile`

A JSON file in the editor's config directory ([LuminaConfigDir]) that several writers share: the editor, a second editor window, a test run — each in its own process or isolate.

* [write] replaces the file atomically: the new content is written and flushed to a temp file in the same directory, which is then renamed over the file. A reader sees the old content or the new one, never a truncated file. * [update] is a read-modify-write under an exclusive lock (`<name>.lock`, created exclusively, so it holds across processes and isolates alike): two writers never overwrite each other's change. * Content that does not parse is never taken for an empty value. [read] tries again for a moment (a writer that still rewrites the file in place may be half-way through), then throws [ConfigFileUnreadableException]. [update] moves such a file aside as `<name>.unreadable-<timestamp>` before it writes, so the content is kept.

**Yapıcı Metotlar (Constructors):**

- `ConfigJsonFile(this.file)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `readAttempts` | `static const int readAttempts` | How often a read that does not parse is tried, and how far apart. |
| `readRetryDelay` | `static const Duration readRetryDelay` |  |
| `staleLockAge` | `static const Duration staleLockAge` | A lock older than this was left behind by a writer that died. |
| `lockTimeout` | `static const Duration lockTimeout` | How long [update] waits for another writer's lock. |
| `lockFile` | `File get lockFile` | The lock [update] holds while it reads, changes and writes the file. |
| `read` | `Object? read()` | The decoded content; null when the file is missing or stays blank. |
| `write` | `void write(Object? value, {bool pretty = false})` | Replaces the file with [value], atomically. |
| `update` | `Object? update(Object? Function(Object? current) change, {bool Function(Object value)? isValid, bool pretty =...` | Reads the file, lets [change] turn its content (null when there is none) into the new content, and writes that — all under [lockFile]. |

### `class ConfigFileUnreadableException`

A config file whose content does not parse as the JSON it should hold, even after [ConfigJsonFile.read] tried again.

**Yapıcı Metotlar (Constructors):**

- `ConfigFileUnreadableException(this.file, this.cause)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `cause` | `final Object cause` |  |

## `lib/src/services/dart_identifiers.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dartKeywords` | `const Set<String> dartKeywords` | Dart's reserved words and built-in identifiers, plus `async` / `await` / `yield` (reserved inside asynchronous and generator bodies). |
| `isDartKeyword` | `bool isDartKeyword(String name)` | Whether [name] is in [dartKeywords]. |
| `dartTypeName` | `String dartTypeName(String name, {String fallback = 'Generated'})` | The UpperCamelCase Dart type name generated for the user name [name] (`L_Main` → `LMain`, `BP_Door` → `BpDoor`); [fallback] when [name] has no letters or digits. |
| `dartFileStem` | `String dartFileStem(String name, {String fallback = 'generated'})` | The snake_case file name (without `.dart`) generated for [name] (`BP_ThirdPersonCharacter` → `bp_third_person_character`); [fallback] when [name] has no letters or digits. |
| `dartFileName` | `String dartFileName(String name, {String fallback = 'generated'})` | [dartFileStem] with the `.dart` extension (`L_Main` → `l_main.dart`). |
| `dartLowerCamelCase` | `String dartLowerCamelCase(String name)` | [name] in lowerCamelCase without escaping keywords or leading digits (`HealthBar Progress` → `healthBarProgress`); '' when nothing is left. |
| `dartMemberName` | `String dartMemberName(String name, {Set<String> reserved = const {}, String fallback = 'value'})` | The lowerCamelCase Dart member name generated for the user name [name] (`Max Health` → `maxHealth`): a leading digit gets an `n` prefix, a Dart keyword or a name in [reserved] a trailing `_`, and a name with no letters or digits is [fallback]. |
| `legacyDartClassName` | `String legacyDartClassName(String name)` | The class name generators used before [dartTypeName] (`BP_Door` → `BPDoor`): what files generated by earlier versions declare, so they can be migrated. |

## `lib/src/services/editor_build_cache.dart`

### `class EditorBuildEntry`

A complete cached project editor build.

**Yapıcı Metotlar (Constructors):**

- `const EditorBuildEntry(this.hash, this.dir, this.stamp)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hash` | `final String hash` |  |
| `dir` | `final Directory dir` |  |
| `stamp` | `final Map<String, dynamic> stamp` | The stamp written at install: `{hash, inputs, engineRevision, flutterVersion, platform, mode, builtAt, executable}`. |
| `bundle` | `Directory get bundle` |  |
| `executable` | `String get executable` | The editor executable inside [bundle] (`stamp.executable` is relative). |

### `class EditorBuildCache`

The machine-wide, content-addressed cache of compiled project editors: `<root>/<hash>/{bundle/, stamp.json, complete}`. Projects with the same plugin set on the same engine share one entry.

Crash-safe: an install copies into `<hash>.tmp/` and renames, and only an entry with its `complete` marker is ever returned. Two launchers building the same hash serialize on `<hash>.lock` ([RandomAccessFile.lock]).

**Yapıcı Metotlar (Constructors):**

- `EditorBuildCache({Directory? root, Directory? nativeRoot})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `root` | `final Directory root` |  |
| `nativeRoot` | `final Directory nativeRoot` | flutter_filament's native library cache, swept alongside by [evict]. |
| `cacheBase` | `static String cacheBase({Map<String, String>? environment, String? operatingSystem})` | `%LOCALAPPDATA%\lumina` on Windows, `~/Library/Caches/lumina` on macOS, else `$XDG_CACHE_HOME/lumina` or `~/.cache/lumina`. |
| `defaultRoot` | `static Directory defaultRoot({Map<String, String>? environment, String? operatingSystem})` |  |
| `lockFile` | `File lockFile(String hash)` |  |
| `logFile` | `File logFile(String hash)` |  |
| `lookup` | `EditorBuildEntry? lookup(String hash)` |  |
| `hashes` | `List<String> hashes()` | Every complete entry's hash. |
| `install` | `Future<EditorBuildEntry> install(String hash, Directory builtBundle, {Map<String, dynamic> stamp = const {}})...` | Copies [builtBundle] into `<hash>.tmp/` with [stamp], marks it complete and renames it into place. A leftover `<hash>.tmp/` from a crashed install is removed first. The caller holds `<hash>.lock` ([obtain] does). |
| `touch` | `Future<void> touch(String hash) async` | Marks [hash] used now (eviction keeps recently used entries). |
| `withLock` | `Future<T> withLock<T>(String hash, Future<T> Function() body) async` | Locks `<hash>.lock` exclusively (waiting for another holder), runs [body], then releases it. |
| `obtain` | `Future<EditorBuildEntry> obtain(String hash, Future<({Directory bundle, Map<String, dynamic> stamp})> Function...` | The entry for [hash], building it with [build] only when it is not cached. Two callers for one hash serialize on its lock: the second finds the first one's entry and does not build. |
| `lastEvictedBytes` | `int lastEvictedBytes` | Bytes freed by the last [evict]. |
| `evict` | `Future<List<String>> evict({int keep = 5, Duration unusedFor = const Duration(days: 30)}) async` | Removes entries beyond the [keep] most recently used that were unused for [unusedFor], never one whose lock is held, plus any crashed `*.tmp` install. Also sweeps the native library cache the same way per package. Returns what was removed (`<hash>`, `native/<pkg>/<key>`). |
| `totalBytes` | `int totalBytes()` | Total size of every entry (for the preferences' cache line). |

## `lib/src/services/editor_build_fingerprint.dart`

### `class EditorHostInputs`

Everything a project editor build depends on.

**Yapıcı Metotlar (Constructors):**

- `const EditorHostInputs({required this.hostDir, required this.engineRoot, required this.pluginDirs, required this.flutterVersion, required this.flutterRevision,...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hostDir` | `final String hostDir` | `<project>/.lumina/editor`: its `pubspec.yaml` and `pubspec.lock`. |
| `engineRoot` | `final String engineRoot` | The workspace root holding the engine repos. |
| `pluginDirs` | `final Map<String, String> pluginDirs` | Each code plugin's package directory, by plugin name. |
| `flutterVersion` | `final String flutterVersion` | `flutter --version --machine`: `frameworkVersion` (shown in reasons) and `frameworkRevision` (hashed). |
| `flutterRevision` | `final String flutterRevision` |  |
| `platform` | `final String platform` | `windows-x64`, `linux-x64`, …. |
| `mode` | `final String mode` | `release` or `debug`. |
| `repos` | `final List<String> repos` | The repos (relative dirs under [engineRoot]) hashed as `engine:<repo>`: the engine repos, or the packages of a project's source copy. |
| `currentPlatform` | `static String currentPlatform()` | The running host: `<os>-<arch>`. |

### `class FlutterToolInfo`

`flutter --version --machine`, probed once per process.

**Yapıcı Metotlar (Constructors):**

- `const FlutterToolInfo(this.version, this.revision)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` |  |
| `revision` | `final String revision` |  |
| `probe` | `static Future<FlutterToolInfo> probe({String flutter = 'flutter'}) async` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kEditorEngineRepos` | `const List<String> kEditorEngineRepos` | The engine packages a project editor is compiled from (the ones of other repos are found through the workspace's package config). |
| `fingerprintComponents` | `Future<Map<String, String>> fingerprintComponents(EditorHostInputs inputs) async` | Per-input hashes: `host.pubspec`, `host.lock`, `engine:<repo>`, `plugin:<name>`, and the plain values `flutter`, `platform`, `mode` (kept readable, so a reason can say "Flutter 3.41 → 3.44"). `plugin:<name>`, eklentinin `lib/`, `hook/`, `pubspec.yaml` ve `.lmplugin` dosyalarını özetler (registrar'a neyin derleneceğine manifest karar verir: `registration_class`, `isolation`, `process_class`). |
| `fingerprint` | `Future<String> fingerprint(EditorHostInputs inputs) async` | SHA-256 (hex) over [components] (or over [fingerprintComponents] of [inputs]). |
| `fingerprintOf` | `String fingerprintOf(Map<String, String> components)` |  |
| `diffInputs` | `List<String> diffInputs(Map<String, String> older, Map<String, String> newer)` | Human-readable reasons [newer] differs from [older], one per change: "plugin a_plugin changed", "editor source changed (lumina_ui)", "Flutter 3.41.0 → 3.44.0", "build mode release → debug". |
| `engineRepoState` | `Future<String> engineRepoState(String dir) async` | Bir deponun kaynak durumu: checkout ise git durumu, değilse (projenin engine kopyası) `lib/`, `src/`, `hook/`, platform runner klasörleri `windows/`, `linux/`, `macos/` (`flutter/ephemeral` hariç, bağlantılar izlenmeden) ve `pubspec.yaml` içerik manifesti; böylece kopyadaki bir runner değişikliği proje editörünü yeniden derletir. |

## `lib/src/services/editor_source_vendor_service.dart`

### `class EditorEngineUpdate`

Projenin motor kaynağı kopyası çalışan motordan başka bir motordan geliyor (bkz. [EditorSourceVendorService.engineUpdate]). Launcher [fromLabel] ve [toLabel] ile "Update this project's editor?" diye sorar.

**Yapıcı Metotlar (Constructors):**

- `const EditorEngineUpdate({required this.copied, required this.current, this.projectEngineVersion, this.changedRepos = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `copied` | `final EngineIdentity? copied` | Kopyanın alındığı motor, damganın kaydettiği şekliyle; damgalar bunu kaydetmeden önce yapılmış kopyada null. |
| `projectEngineVersion` | `final String? projectEngineVersion` | Projenin `.lmproject` `engine_version` değeri, bir sürüm adlandırıyorsa. |
| `current` | `final EngineIdentity current` | Senkronizasyonun kopyalayacağı motor. |
| `changedRepos` | `final List<String> changedRepos` | Kopyadan beri motor kaynağı değişen kopyalanmış depolar. |
| `fromLabel` | `String get fromLabel` | Kopyanın motoru kullanıcı için: etiketi, yoksa projenin `engine_version` değeri, yoksa "an older engine". |
| `toLabel` | `String get toLabel` | Çalışan motor kullanıcı için; aynı sürüm ve commit'ten alınmış kopyada (kaynak checkout'unda düzenleme) değişen depolar da yazılır. |

### `class EditorSourceVendorService`

Copies the engine's Dart source, dependencies included, into a project's editor host: `<host>/lumina_ui/`, `<host>/lumina/`, `<host>/flutter_filament/`, … at the workspace's relative layout, so the copied pubspecs' `path: ../x` entries resolve among themselves. Packages from other repos (git dependencies: flutter_assimp, flutter_riglogic, flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared package) are copied from where the engine workspace resolved them (its package config: the pub cache, or a local checkout through `pubspec_overrides.yaml`) to `<host>/<name>/`; the host pubspec overrides every one of them to its copy. Filament's C++ tree is linked (`<host>/filament` → `<engine>/filament`), never copied.

The copy is made once and is the project's own afterwards: only [sync] replaces it.

**Yapıcı Metotlar (Constructors):**

- `EditorSourceVendorService({required this.engineRoot, this.rootPackage = 'lumina_ui', this.linkPackages = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` | The workspace root holding `lumina_ui/`, `lumina/`, `filament/`, …. |
| `rootPackage` | `final String rootPackage` | The package whose path-dependency closure is copied. |
| `linkPackages` | `final bool linkPackages` | Links each package to the engine instead of copying it: for engine development and tests, where a ~650 MB copy per build is pointless. Projects never use it. |
| `stampFileName` | `static const String stampFileName` |  |
| `engineLockFileName` | `static const String engineLockFileName` | `.lumina_engine_pubspec.lock`: kopya alındığı andaki engine workspace `pubspec.lock` dosyası (kopyalanan kaynağın derlenip test edildiği sürümler); [vendor] yazar, host generator host'un hosted paketlerini buna sabitler. |
| `filamentDir` | `static const String filamentDir` | Filament's C++ tree, linked beside the copied packages because the native-assets hooks resolve `../filament/…` from their package root. |
| `packageExcludes` | `static const Set<String> packageExcludes` | Skipped directly under each package root: build outputs, tests and backlog docs, none of which the editor build reads. |
| `anywhereExcludes` | `static const Set<String> anywhereExcludes` | Skipped at any depth. |
| `readStamp` | `static Map<String, dynamic>? readStamp(String hostDir)` |  |
| `copiedRepos` | `static List<String> copiedRepos(String hostDir)` | The packages copied into [hostDir] (relative, `/`), from its stamp; empty when it holds no copy. |
| `packageClosure` | `List<String> packageClosure()` | The package dirs (relative to the host, `/`-separated) reachable from [rootPackage] through `path:` and `git:` dependencies and overrides, in discovery order: see [packageSources]. |
| `packageSources` | `Map<String, String> packageSources()` | Each [packageClosure] entry and the directory it is copied from. A `path:` dependency inside [engineRoot] keeps its relative place; one leaving it is a [StateError]. A `git:` dependency (a package of another repo) is copied from where the engine workspace resolved it (see [LuminaWorkspace.resolvedPackageDir]) to `<name>`; one the engine has not resolved is a [StateError]. Path dependencies of such a package are copied by name too. |
| `copyRoots` | `List<String> copyRoots()` | [packageClosure] without packages nested in another one (they travel inside their parent). |
| `isVendored` | `bool isVendored(String hostDir)` | Whether [hostDir] holds a complete copy: the stamp, every package in it and the Filament link. |
| `vendorIfMissing` | `Future<bool> vendorIfMissing(String hostDir, {void Function(double fraction, String file)? onProgress}) async` | Copies the source unless [hostDir] already holds it; true when it copied. |
| `sync` | `Future<void> sync(String hostDir, {void Function(double fraction, String file)? onProgress})` | Replaces the copy with the engine's current source; edits made in the project's copy are lost. |
| `vendor` | `Future<void> vendor(String hostDir, {void Function(double fraction, String file)? onProgress}) async` | Her [copyRoots] paketini [hostDir] içine kopyalar (oradakinin yerine), Filament'i bağlar ve damgayı yazar; damga kopyanın alındığı motoru kaydeder (`engine`: [EngineIdentity]). Paketler önce `<host>/.source.tmp/` içine kopyalanır, hepsi bitince yerine taşınır; yarıda kalan kopya eski durumu bırakır. |
| `copiedEngine` | `static EngineIdentity? copiedEngine(String hostDir)` | [hostDir] kopyasının alındığı motor, damgasından; damga bu kayıttan eskiyse (ya da kopya yoksa) null. |
| `engineChangedSince` | `Future<List<String>> engineChangedSince(String hostDir) async` | The engine repos (top-level dirs) whose state changed since [hostDir]'s copy was made. |
| `engineUpdate` | `Future<EditorEngineUpdate?> engineUpdate(String hostDir, {required EngineIdentity current, String? projectEngineVersion}) async` | [hostDir] kopyası [current] dışında bir motordan mı geliyor: kopya yoksa ya da günselse null. Motorunu kaydeden damga, o motor [current] değilse ya da motor kaynağı o zamandan beri değiştiyse ([engineChangedSince]; kaynak checkout'unda düzenlemeler de sayılır) farklıdır. Eski damga, kaynak değiştiyse ya da projenin [projectEngineVersion] değeri başka bir sürüm adlandırıyorsa farklıdır; oluşturucuların yer tutucusu `kLuminaEngineVersion` sürüm sayılmaz. |

## `lib/src/services/encoded_image_format.dart`

### `enum EncodedImageFormat`

The container an encoded image is stored in, told from its bytes.

Every format with a signature is recognised by it. TGA has none, so it is only reported when no signature matched and the header passes [TgaDecoderService.isTga]. A glTF `mimeType` or a file extension never decides: exporters label images wrongly and texture folders hold PNGs saved under `.tga` names, and a PNG read as a TGA header is an 18505x21060 image.

**Değerler:**

- `png`
- `jpeg`
- `webp`
- `gif`
- `bmp`
- `ktx2`
- `tga`
- `unknown`: No signature matched and the bytes are not a TGA header either.

**Yapıcı Metotlar (Constructors):**

- `const EncodedImageFormat(this.mimeType)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mimeType` | `final String? mimeType` |  |
| `sniff` | `static EncodedImageFormat sniff(Uint8List bytes)` | The format of [bytes]; [unknown] when nothing matches. |

## `lib/src/services/engine_bootstrap.dart`

### `abstract final class LuminaRelease`

What the release workflow compiles into a Lumina Studio build (`--dart-define`): the release tag, its commit and the engine repo. All empty in a dev build.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `static const String version` | The release tag, e.g. `v0.1.0`; empty in dev builds. |
| `commit` | `static const String commit` | The full commit SHA the release was built from. |
| `repo` | `static String get repo` | The engine repo the release fetches its source from. |
| `isRelease` | `static bool get isRelease` | Whether this is a release build. |

### `typedef FilamentProvider`

Downloads (or finds) the prebuilt Filament build [version] and returns its directory, usable as the hooks' `filament_dir`: from the `filament-<version>` release, else from the [releaseTag] release (the editor's own, for releases that attached Filament themselves). The signature of `FilamentPrebuilt.ensure`.

### `enum EngineBootstrapStep`

The steps of [EngineBootstrap.ensure], in order.

**Değerler:**

- `prerequisites`
- `source`
- `filament`
- `packages`

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapStep(this.label)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `label` | `final String label` |  |

### `sealed class EngineBootstrapEvent`

An event of [EngineBootstrap.run] / [EngineBootstrap.ensure].

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapEvent()`

### `final class EngineBootstrapProgress`

[step] started or advanced; [fraction] is null while unknown.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapProgress(this.step, this.message, {this.fraction})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `fraction` | `final double? fraction` |  |
| `message` | `final String message` |  |

### `final class EngineBootstrapLog`

A line of tool output (git, flutter) during [step].

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapLog(this.step, this.line)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `line` | `final String line` |  |

### `final class EngineBootstrapStepDone`

[step] finished; [skipped] when there was nothing to do.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapStepDone(this.step, {this.skipped = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `skipped` | `final bool skipped` |  |

### `final class EngineBootstrapPrerequisites`

The prerequisite check's findings (sent whether or not any is missing).

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapPrerequisites(this.prerequisites)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `prerequisites` | `final List<EnginePrerequisite> prerequisites` |  |

### `final class EngineBootstrapCompleted`

The checkout is ready and active.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapCompleted(this.checkout)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `checkout` | `final EngineCheckout checkout` |  |

### `final class EngineBootstrapFailed`

The bootstrap stopped; running it again resumes.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapFailed(this.error)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `error` | `final EngineBootstrapException error` |  |

### `class EnginePrerequisite`

A tool the engine source needs on this machine.

**Yapıcı Metotlar (Constructors):**

- `const EnginePrerequisite({required this.name, required this.location, required this.required, required this.hint})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` | Display name, e.g. `Git`. |
| `location` | `final String? location` | Where it was found (a path, a version), or null when missing. |
| `required` | `final bool required` | Missing required prerequisites stop the bootstrap; the others (the C++ toolchain, needed only to build games and project editors) are reported. |
| `hint` | `final String hint` | How to install it. |
| `found` | `bool get found` |  |

### `class EngineBootstrapException`

Why [EngineBootstrap.ensure] stopped.

**Yapıcı Metotlar (Constructors):**

- `const EngineBootstrapException(this.message, {required this.step, this.missing = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `step` | `final EngineBootstrapStep step` | The step that failed. |
| `missing` | `final List<EnginePrerequisite> missing` | The required prerequisites that are missing (step [EngineBootstrapStep.prerequisites]). |

### `class EngineCheckout`

A complete engine checkout, as recorded in its marker file.

**Yapıcı Metotlar (Constructors):**

- `const EngineCheckout({required this.dir, required this.version, required this.commit, required this.repo, required this.filamentVersion, required this.filamentD...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dir` | `final String dir` | The checkout directory (`<data>/engine/<version>`). |
| `version` | `final String version` | The release tag it belongs to. |
| `commit` | `final String commit` | The commit it is checked out at (detached). |
| `repo` | `final String repo` | The git URL it was cloned from. |
| `filamentVersion` | `final String filamentVersion` | The prebuilt Filament version (`tool/filament/VERSION`) and directory its `filament` link points at. |
| `filamentDir` | `final String filamentDir` |  |
| `completedAt` | `final DateTime completedAt` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |
| `fromJson` | `static EngineCheckout? fromJson(String dir, Object? json)` |  |

### `class EngineBootstrap`

Fetches the engine source of a release build: the installed Lumina Studio is a prebuilt binary, but generating games, project editors and plugins needs the engine's source, at exactly the commit the binary was built from.

[ensure] makes `<engineRoot>/<version>` a partial git clone of [repo] checked out (detached) at [commit], links the prebuilt Filament for the checkout's `tool/filament/VERSION` as its `filament` folder (the root pubspec's hook settings name `filament`), runs `flutter pub get` there (the pinned `ref:`s and the committed lock resolve the other repos), writes a marker file and points [LuminaWorkspace.root] at the checkout.

Every step is idempotent: a complete checkout starts without the network, an interrupted one resumes (a clone whose objects arrived is checked out, a broken one is cloned again). Checkouts of older versions are kept.

**Yapıcı Metotlar (Constructors):**

- `EngineBootstrap({required this.version, this.commit = '', this.repo = kLuminaGitUrl, Directory? engineRoot, Directory? filamentRoot, Map<String, String>? enviro...`
- `factory EngineBootstrap.release({FilamentProvider? filament})`: The bootstrap of this release build ([LuminaRelease]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` | The release tag, e.g. `v0.1.0`: the checkout's folder name, and the commit to check out when [commit] is empty. |
| `commit` | `final String commit` | The commit to check out; empty: the tag [version]. |
| `repo` | `final String repo` | The engine repo (any git URL, `file://` included). |
| `engineRoot` | `final Directory engineRoot` | Where checkouts live (`<data>/engine`). |
| `filamentRoot` | `final Directory filamentRoot` | Where prebuilt Filament builds live (`<data>/filament`). |
| `environment` | `final Map<String, String> environment` | The environment tools are looked up in and run with. |
| `filament` | `final FilamentProvider? filament` | Supplies the prebuilt Filament; defaults to [defaultFilamentProvider]. |
| `checkToolchain` | `final bool checkToolchain` | Whether to look for the C++ toolchain (reported, never blocking). |
| `defaultFilamentProvider` | `static FilamentProvider? defaultFilamentProvider` | The Filament provider bootstraps use unless given one. |
| `markerName` | `static const String markerName` | The marker a complete checkout carries, inside its `.git` folder (so it never shows as a change and goes when the checkout goes). |
| `needed` | `static bool get needed` | Whether this process needs a bootstrap: a release build that does not run from a source workspace (`LUMINA_WORKSPACE`, or an ancestor checkout). |
| `checkoutDir` | `Directory get checkoutDir` | `<engineRoot>/<version>`. |
| `markerFile` | `File get markerFile` |  |
| `readyCheckout` | `EngineCheckout? readyCheckout()` | The checkout when it is complete — marker present and matching, `.git/HEAD` at the commit, Filament linked, packages resolved — else null. Reads files only (no git, no network). |
| `activate` | `static void activate(EngineCheckout checkout)` | Makes [LuminaWorkspace.root] resolve to [checkout] for this process. |
| `run` | `Stream<EngineBootstrapEvent> run({bool force = false, bool activate = true})` | [ensure] as a stream: its events, ending with [EngineBootstrapCompleted] or [EngineBootstrapFailed]. |
| `ensure` | `Future<EngineCheckout> ensure({void Function(EngineBootstrapEvent)? onEvent, bool force = false, bool activate...` | Makes the checkout complete (see the class comment) and returns it; with [activate], points [LuminaWorkspace.root] at it. [force] deletes the checkout first and downloads it again. Throws [EngineBootstrapException]. |
| `checkPrerequisites` | `Future<List<EnginePrerequisite>> checkPrerequisites() async` | Git and the Flutter SDK (required), and the C++ toolchain the engine's native code builds with (reported only), found through [environment]. |
| `findExecutable` | `String? findExecutable(String name)` | [name]'s full path on [environment]'s `PATH` (with `PATHEXT` on Windows), or null. |

## `lib/src/services/engine_identity.dart`

### `class EngineIdentity`

Bir Lumina Studio'nun hangi motorla çalıştığı ya da projenin motor kaynağı kopyasının hangi motordan alındığı: bir sürüm etiketi ve commit'i, ya da kaynak checkout'u için kaynak sürümü ve `HEAD`.

**Yapıcı Metotlar (Constructors):**

- `const EngineIdentity({required this.version, this.commit = '', this.release = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `version` | `final String version` | Etiketin `v` harfi olmadan sürüm: `0.0.1-dev.7`, kaynak checkout'unda `0.0.1-dev`. |
| `commit` | `final String commit` | Tam commit SHA'sı; bilinmiyorsa (git checkout'u olmayan kaynak ağacı) boş. |
| `release` | `final bool release` | İndirilmiş bir sürüm checkout'u mu (yalnızca etiketiyle adlandırılır). |
| `of` | `static Future<EngineIdentity> of(String engineRoot) async` | [engineRoot] konumundaki motor: indirilmiş sürüm checkout'u etiketini ve commit'ini (bootstrap işaretçisi) verir; sürüm tanımları taşımayan proje editörü de onu indiren Studio ile aynı kimliği okur. Başka her ağaç kaynak checkout'udur: [LuminaRelease.displayVersion] ve oradaki `git rev-parse HEAD` (yalnızca ağacın kendi checkout'u). |
| `stripTag` | `static String stripTag(String version)` | `v0.1.0` → `0.1.0`. |
| `label` | `String get label` | Kullanıcıya gösterilen ad: sürüm, ya da kaynak sürümü ve commit'i (`0.0.1-dev (08cb722)`). |
| `key` | `String get key` | `<version>@<commit>`: aynı motor için eşittir. |
| `toJson / fromJson` | `Map<String, Object?> toJson() · static EngineIdentity? fromJson(Object? json)` | Vendor damgasının ve Studio kaydının `engine` kaydı; sürüm yoksa `fromJson` null döner. |

## `lib/src/services/engine_logger_service.dart`

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

## `lib/src/services/fbx_material_mapper.dart`

### `abstract final class FbxMaterialMapper`

FBX Phong/Lambert material values → glTF metallic/roughness:

- **base colour** = the FBX diffuse colour (Assimp: `DiffuseColor × DiffuseFactor`), raw — FBX colours are linear; alpha = the FBX `Opacity` (below 1 → alpha blend). A diffuse *texture* replaces the colour (the factor becomes white): the texture is wired straight into Base Color; - **emissive** = the FBX emissive colour (`EmissiveColor × EmissiveFactor`); above 1 it is normalized and the rest goes into `KHR_materials_emissive_strength`; an emissive texture with a black emissive colour emits at full strength; - **roughness** from the Phong exponent, see [roughnessFromPhong]; - **metallic** 0 — Phong has no metalness — unless the file carries a PBR value (Maya Stingray/Arnold `Maya|metallic`, 3ds Max Physical `metalness`). `ReflectionFactor` is *not* used: the FBX SDK template defaults it to 1, so every such export would come in as metal.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `roughnessFromPhong` | `static double roughnessFromPhong({required double shininess, required double specular})` | Perceptual roughness for a Phong material with exponent [shininess] and specular intensity [specular] (specular colour luminance × specular factor). |
| `valuesFor` | `static ({List<double>? baseColor, double alpha, double metallic, double roughness, List<double> emissive}) val...` | The glTF values for one flutter_assimp `material_details` entry. |
| `applyToGltf` | `static void applyToGltf(Map<String, dynamic> json, List<Map> details)` | Writes each FBX material's values ([details], flutter_assimp's `material_details`, matched by name, else by index) into the glTF [json]'s materials in place, replacing the glTF exporter's guess (`roughness = 1 − sqrt × specular`, which makes every such export fully rough). |
| `setEmissive` | `static void setEmissive(Map<String, dynamic> json, Map material, List<double> rgb)` | Sets [material]'s emissive colour [rgb] (linear, any intensity): a colour above 1 is normalized, the scale going into `KHR_materials_emissive_strength`; black removes the emission. |
| `emissiveOf` | `static List<double> emissiveOf(Map material)` | The emissive colour × strength a glTF [material] asks for. |

## `lib/src/services/fbx_texture_locator.dart`

### `enum FbxTextureChannel`

A texture channel an image beside an FBX can be matched to by its name, and the glTF slot it fills.

**Değerler:**

- `baseColor`
- `normal`
- `emissive`
- `orm`
- `occlusion`

**Yapıcı Metotlar (Constructors):**

- `const FbxTextureChannel(this.suffix, this.slot)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `suffix` | `final String suffix` | The suffix of the texture asset the importer names it by (`T_<core>_<suffix>`). |
| `slot` | `final String slot` | The `.lmas` material sampler / glTF slot it fills. |

### `class FbxTextureLocator`

Where the textures of an FBX are looked for, in order — the path as written, then relative to the FBX — plus the folders people keep textures in:

- **near folders** (searched first, and the only ones whose images are matched to materials by name): the folders chosen in the import options, the FBX's folder, and its `Textures/`, `textures/`, `<fbx name>/` and `<fbx name>.fbm/` subfolders (`.fbm` is where the FBX SDK extracts embedded media); - **reference folders** (a referenced file name only): the near folders, then the `Textures`/`textures`/`Texturen`/`Materials` folders of the FBX's folder and its three nearest ancestors, with their direct subfolders.

**Yapıcı Metotlar (Constructors):**

- `FbxTextureLocator({required this.fbxFile, List<String> extraDirs = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fbxFile` | `final File fbxFile` |  |
| `extraDirs` | `final List<String> extraDirs` |  |
| `sourceDir` | `Directory get sourceDir` |  |
| `nearDirs` | `late final List<Directory> nearDirs` |  |
| `referenceDirs` | `late final List<Directory> referenceDirs` |  |
| `nearImages` | `late final List<File> nearImages` | Every image file in the [nearDirs], each once. |
| `locateReference` | `File? locateReference(String uri)` | Bir FBX doku referansı [uri]'nin gösterdiği dosya: yazıldığı gibi, FBX'e göre (bu yazımla diskte yoksa klasörleri ve dosyası büyük/küçük harf fark etmeksizin eşleşerek, bkz. [findIgnoringCase]), sonra [referenceDirs] içinde dosya adıyla (büyük/küçük harf duyarsız), sonra [nearDirs] içinde adı `_<dosya adı>` ile biten bir görsel olarak (asset'in adını öne ekleyen bir exporter, ör. Godot'nun `SM_Slot_Machine_T_Tread_Plate_Normal.png`'si). |
| `findIgnoringCase` | `static File? findIgnoringCase(String path, {Directory? base})` | [path]'in (`/` veya `\` ayraçlı; [base]'e göre ya da mutlak) gösterdiği dosya, klasörleri veya dosyası büyük/küçük harf duyarlı bir diskte başka harflerle yazılmışken (Linux: `Maps/wood.png`, `maps/wood.png`'yi bulur): her parça o adın herhangi bir harf büyüklüğündeki girdisine gider ([pickIgnoringCase]). `.` ve `..` yazıldığı gibi izlenir. Bir parçanın eşi yoksa null. Büyük/küçük harf duyarsız bir dosya sistemi (Windows, macOS) bunları zaten tam yolla bulur. |
| `pickIgnoringCase` | `static T? pickIgnoringCase<T extends FileSystemEntity>(Iterable<T> entries, String name)` | [entries] içinde herhangi bir harf büyüklüğünde [name] adlı girdi: tam bu yazımla olan varsa o, yoksa ada göre (kod birimi) ilki; böylece seçim klasörün listelenme sırasına hiç bağlı değildir. |
| `channelOf` | `static (FbxTextureChannel, int)? channelOf(String stem)` | The channel a file name (without extension) ends in, and how many of its tokens the suffix takes. |
| `coreName` | `static String coreName(String material)` | A material name without its asset-type prefix (`MI_`, `M_`, `Mat_`, `Material_`). |
| `matchByName` | `Map<int, Map<FbxTextureChannel, File>> matchByName(List<String> materials, {Set<String> exclude = const {}})` | The images of the [nearDirs] matched to [materials] by name: a file matches a material when its name holds the material's name (or its [coreName]) as whole tokens before a channel suffix — `T_Wood_BaseColor` for `M_Wood`, `SM_Slot_Machine_MI_Neon_Green_SM_Slot_Machine_Emissive` for `MI_Neon_Green`. A file goes to the material with the longest matching name (`MI_Plastic_Black_Matte_1_Normal` belongs to `MI_Plastic_Black_Matte_1`, not `MI_Plastic_Black`); files in [exclude] (already bound by reference) are skipped. Result: material index → channel → file (the first by path when several fit). |

---

[Önceki: Dosya formatları ve repository'ler](formats.md) | [Üst: lumina_core (saf Dart temeli)](index.md) | [Sonraki: Servisler (devamı)](services-continued.md)
