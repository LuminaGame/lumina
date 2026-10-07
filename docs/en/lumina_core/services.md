[Türkçe](../../tr/lumina_core/services.md)

# Services

The pure services, part one: animation authoring and GLB animation tools, the asset index, config files, Dart identifiers, the project editor build cache and fingerprint, engine source vendoring, engine bootstrap and identity, the engine logger, FBX helpers and game templates. File paths are relative to the `lumina_core/` package directory.

**On this page:**

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

**Constructors:**

- `const SkeletonCandidate(this.lmasPath, this.match)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `lmasPath` | `final String lmasPath` | `contents/...lmas`, relative to the project. |
| `match` | `final GlbSkeletonMatch match` |  |

### `class AnimationBinding`

Where an imported animation ended up on its skeletal mesh.

**Constructors:**

- `const AnimationBinding({required this.meshLmasPath, required this.meshAssetId, required this.clips})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `meshLmasPath` | `final String meshLmasPath` |  |
| `meshAssetId` | `final String meshAssetId` |  |
| `clips` | `final List<GlbRetargetResult> clips` | Retargeting details per clip, in clip order. |

### `abstract final class AnimationImportBinder`

Binds imported animation clips to a project skeletal mesh.

gltfio only plays animations stored in the asset whose nodes they move, so an animation-only import (an Unreal `AS_*.FBX`: skeleton + keys, no mesh) is retargeted onto a skeletal mesh and appended to that mesh's GLB — the `.entity.glb` companion and, when the mesh `.lmas` embeds one, its payload — the way the Third Person template bundles its clips (`tool/build_third_person_content.dart`).

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const AssetIndexEntry({required this.projectDir, required this.path, required this.size, required this.modifiedMs, required this.summary,})`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const AssetIndexChange({this.added = const [], this.changed = const [], this.removed = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `added` | `final List<String> added` |  |
| `changed` | `final List<String> changed` |  |
| `removed` | `final List<String> removed` |  |
| `isEmpty` | `bool get isEmpty` |  |

### `class AssetIndexRefreshStats`

How the last refresh went — the seam tests use to prove an unchanged project is only stat'ed.

**Constructors:**

- `const AssetIndexRefreshStats({this.files = 0, this.decoded = 0, this.removed = 0, this.elapsed = Duration.zero, this.offThread = false,})`

**Members:**

| Member | Signature | Description |
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

**Members:**

| Member | Signature | Description |
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

An Animation Sequence authored in the editor (Content Browser ▸ New ▸ Animation Sequence, then posed bone by bone in the Animation editor): keys at whole frames on bones' translation / rotation / scale channels. The animation `.lmas` keeps it as JSON (`authored_clip`), the editor's exact source; `GlbAuthoredClipWriter` turns it into the glTF animation every player uses.

### `enum AuthoredInterpolation`

How a channel moves between its keys: `linear` (`LINEAR`; rotations slerp on the shortest path), `step` (`STEP`, holds the earlier key) and `cubic` (`CUBICSPLINE` written with zero in / out tangents: an ease in and out at every key). gltfio scales spline tangents by the interpolant rather than the key spacing, so flat tangents are the one cubic form it and the glTF specification evaluate the same way. glTF interpolates per channel, not per key. `gltfName`, `label`, `fromGltf`, `fromLabel`.

### `class BoneTrs`

A bone's local transform (glTF node TRS): `t`, `r` (quaternion), `s`; `toMatrix`, `toList` (`[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]`, the form `SubEditor3DViewport.jointLocalPose` takes), `channel(path)`, `withChannel(path, values)`, `static BoneTrs blend(a, b, w)` (translation and scale lerp, rotation shortest-path slerp; the pose library's weight).

### `class AuthoredChannel`

One animated property of one bone: `path` (`translation` / `rotation` / `scale`), `interpolation`, `keys` (frame → 3 values, or 4 for a rotation `x y z w`). `setKey`, `removeKey`, `moveKey` (replaces a key where it lands), `copy`, JSON. `sample(frame)` evaluates the channel exactly as gltfio's animator does: the end keys hold outside the keyed range, the earlier key holds for `STEP`, translation / scale lerp, rotation slerps, cubic eases (component-wise, normalised for a rotation); rotation keys are brought into one hemisphere first, as the writer stores them.

### `class AuthoredAnimationClip`

`name` (the glTF animation name), `frameRate`, `lengthFrames`, `duration`, `tracks` (bone → path → channel), `bones` (the keyed ones). `setKey(bone, path, frame, values)` (0 ≤ frame ≤ `lengthFrames`), `hasKey`, `removeKey` / `moveKey` (one channel or all of a bone's), `keyFrames(bone)`, `sample(bone, path, t)`, `samplePose(skeleton, t)` (every node's local transform: the keyed channels over the rest pose), `copy`, `toJson` / `fromJson` / `encode` / `decode` (exact round trip; equality compares the JSON).

### `class GlbSkeleton`

A skinned GLB's node hierarchy: `names`, `parent`, `rest(node)`, `joints` (every skin's joints), `order` (parents before children), `root` (the topmost skin joint), `rootChild` (the joint below it with the most descendants: the pelvis), `indexOf`, `isJoint`, `worldMatrices(pose)` (the GLB's frame: metres, Y up). `GlbSkeleton.fromGlb(bytes)` / `fromJson(gltfJson)`.

## `lib/src/services/authored_animation_writer.dart`

### `abstract final class GlbAuthoredClipWriter`

`write({meshGlb, clip, int? index}) → ({Uint8List glb, int clipIndex})`: the mesh GLB with `clip` as the animation named `clip.name`, replacing one of that name in place (its accessors, buffer views and binary data dropped and the chunk compacted, when every extension the file uses is one whose references it can remap) or appended. Every skin joint gets a channel: the clip's keys where it has them, the rest rotation + translation (constant over `[0, duration]`) elsewhere, so the clip defines the whole skeleton after any other clip. A one-key channel is held over two keys (gltfio skips samplers with fewer than two times). Throws `FormatException` for a non-GLB, more than one buffer, no skin, a bone the mesh lacks (named) or a key outside the clip. A new animation goes at `index` when given (clamped; to put a removed clip back where it was), else at the end.

`remove({meshGlb, clipName}) → ({Uint8List glb, int clipIndex})?`: the mesh GLB without that animation and without the accessors, buffer views and binary data only it used (the same compaction as a replace; an `animations` list left empty is dropped), with the index it had; null when there is no animation of that name.

### `abstract final class AuthoredAnimationStore`

Authored sequences in a project, stored the way the Third Person template's and a bound FBX import's clips are: the clip in the skeletal mesh's GLB (the `.entity.glb` companion, and the mesh `.lmas` payload when it has one), its name in the mesh's `animation_clips`, and an animation `.lmas` with no payload that points at it (`source_mesh`, `clip_name`, `clip_index`, `anim_properties`, `duration_seconds`, `length_frames`, a `skeletal_mesh` reference) plus `authored: true` and `authored_clip`. Anim Blueprints, Blend Spaces, montages, Play-In-Editor and the generated game play it by name through gltfio, unchanged.

| Member | Signature | Description |
| :--- | :--- | :--- |
| `create` | `static String create({required String projectDir, required String meshRelPath, required String name, required int lengthFrames, double frameRate = 30.0, String? folder})` | A new sequence for the mesh (`contents/animations/<Mesh>/<name>.lmas` unless [folder]); the name is made unique among the mesh's clips and the folder's files; the skeleton root's rest translation and rotation keyed at frame 0. Returns the project relative path. |
| `save` | `static LuminaAsset save({required String projectDir, required String animationRelPath, required AuthoredAnimationClip clip, Map<String, String>? metadata, List<AssetReference>? references})` | Writes the clip into the mesh GLB (same index) and the `.lmas` (the editor's other metadata kept). |
| `load` | `static AuthoredAnimationClip? load(String projectDir, String animationRelPath)` | The authored clip, or null for an imported clip. |
| `detach` | `static bool detach(String projectDir, String animationRelPath)` | Takes the sequence's clip out of its mesh (GLB companion, payload, `animation_clips`) before its `.lmas` leaves the project; the `.lmas` is untouched. False for an imported clip or when the mesh or clip is gone. The editor's trash, create-undo and Delete call it. |
| `attach` | `static bool attach(String projectDir, String animationRelPath)` | Puts the clip of a restored sequence back into its mesh at its `clip_index` (the `.lmas` is rewritten only if it lands elsewhere). False for an imported clip, a missing mesh or a mesh that already has that clip. |
| `isAuthored` / `clipOf` | `static bool isAuthored(LuminaAsset? asset)` / `static AuthoredAnimationClip? clipOf(LuminaAsset? asset)` | Whether an animation asset was authored here, and its clip. |

## `lib/src/services/authored_pose_tools.dart`

Posing helpers for authored clips, used by the Animation editor's Pose tab. They work on whole poses (`Map<int, BoneTrs>`, node → local transform) in the GLB frame (glTF metres, +Y up) and produce ordinary local transforms, so the result is keyed and saved as the same FK glTF clip.

### `class SkeletonMirror`

Left / right bone pairs of a `GlbSkeleton` and the sagittal plane they mirror across, detected from the rest pose (the plane's normal is the mean right-to-left direction of the paired bones, its point their mean midpoint).

| Member | Signature | Description |
| :--- | :--- | :--- |
| `mirroredName` | `static String? mirroredName(String name)` | The other side's name by convention: `_l`/`_r`, `_L`/`_R`, `.l`/`.r`, `.L`/`.R` suffixes, `l_`/`r_` prefixes, `Left`/`Right` words; null for a name with no side. |
| `of` | `factory SkeletonMirror.of(GlbSkeleton skeleton, {Map<String, String> overrides = const {}})` | The table: pairs by name where both bones exist, the user's [overrides] (either direction) first. |
| `pairs` / `lateralAxis` / `planePoint` | fields | Bone → partner (both ways); the plane's unit normal; a point on it. |
| `partnerOf` | `String partnerOf(String bone)` | The partner, or the bone itself on the plane. |
| `mirrorVector` / `mirrorPoint` / `mirrorRotation` | `Vector3 mirrorVector(Vector3 v)` / `Vector3 mirrorPoint(Vector3 p)` / `Quaternion mirrorRotation(Quaternion q)` | Reflection of an offset, a position, and a world rotation (`S·R·S`: the mirrored axis, the other way). |
| `mirror` | `Map<int, BoneTrs> mirror({required Map<int, BoneTrs> source, required Map<int, BoneTrs> target, required Iterable<String> bones})` | The local transforms that put the mirror image of [bones] as posed in [source] onto their partners over [target]: each partner turns from its rest pose as its source turned (mirrored, world space); a translated source moves its partner by the mirrored offset; scale is copied; parents are solved before children. Returns the changed nodes. |

### `class TwoBoneIkChain`

`TwoBoneIkChain(name, upper, lower, end)`: a limb by node index. `static List<TwoBoneIkChain> detect(GlbSkeleton)` finds `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg` from an end effector named like a hand or foot with a side (`hand_l`, `LeftFoot`, `foot.R`, `l_hand`) whose parent and grandparent are joints.

### `abstract final class TwoBoneIkSolver`

`static Map<int, BoneTrs> solve({required GlbSkeleton skeleton, required Map<int, BoneTrs> pose, required TwoBoneIkChain chain, required Vector3 target, Vector3? pole, bool keepEndRotation = true})`: law of cosines in the plane of the target and the pole (the chain's current bend when [pole] is null); the target is clamped to the chain's reach. Returns new local transforms for the upper and lower bone (and the end effector, keeping its world orientation, with [keepEndRotation]); only rotations change.

### `abstract final class RootMotionAuthoring`

Up is glTF +Y.

| Member | Signature | Description |
| :--- | :--- | :--- |
| `extractFromPelvis` | `static bool extractFromPelvis(AuthoredAnimationClip clip, GlbSkeleton skeleton)` | At every frame with a root or pelvis translation key, keys the skeleton root at its position plus the pelvis's horizontal travel since the first of them, and the pelvis (`GlbSkeleton.rootChild`) at the same world position over it, so it keeps only its vertical motion; the root channel takes the pelvis channel's interpolation. False when the pelvis has no translation keys. |
| `zeroRoot` | `static bool zeroRoot(AuthoredAnimationClip clip, GlbSkeleton skeleton)` | The inverse: the root's translation returns to its rest value (one key at frame 0) and the pelvis is keyed where it was in the world. False when the root has no translation keys. |

### `class AuthoredPose`, `class AuthoredPoseLibrary`, `abstract final class AuthoredPoseLibraryStore`

`AuthoredPose(name, bones)`: local transforms by bone name (`renamed`, JSON). `AuthoredPoseLibrary({meshRelPath, poses, mirrorOverrides})`: one skeletal mesh's poses and hand-set mirror pairs (`pose(name)`, `copy`, JSON). `AuthoredPoseLibraryStore`: `pathFor(meshRelPath)` (`contents/animations/<Mesh>/PoseLibrary.lmas`), `load(projectDir, meshRelPath)` (empty when missing), `save(projectDir, library)` (an `AssetType.unknown` `.lmas` with the JSON payload and `pose_library: true`, `source_mesh`, `pose_count` metadata), `isLibrary(asset)`.

## `lib/src/services/auto_save_timer_service.dart`

### `class AutoSaveTimerService`

`AutoSaveTimerService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onPerformSave` | `SaveCallback onPerformSave` | Holds the `onPerformSave` property or configuration state. |
| `stop` | `void stop()` | Executes `stop` operation. |
| `checkAndExecuteAutoSave` | `Future<LuminaProject> checkAndExecuteAutoSave(LuminaProject project)` | Executes `checkAndExecuteAutoSave` operation. |

## `lib/src/services/config_json_file.dart`

### `class ConfigJsonFile`

A JSON file in the editor's config directory ([LuminaConfigDir]) that several writers share: the editor, a second editor window, a test run — each in its own process or isolate.

* [write] replaces the file atomically: the new content is written and flushed to a temp file in the same directory, which is then renamed over the file. A reader sees the old content or the new one, never a truncated file. * [update] is a read-modify-write under an exclusive lock (`<name>.lock`, created exclusively, so it holds across processes and isolates alike): two writers never overwrite each other's change. * Content that does not parse is never taken for an empty value. [read] tries again for a moment (a writer that still rewrites the file in place may be half-way through), then throws [ConfigFileUnreadableException]. [update] moves such a file aside as `<name>.unreadable-<timestamp>` before it writes, so the content is kept.

**Constructors:**

- `ConfigJsonFile(this.file)`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `ConfigFileUnreadableException(this.file, this.cause)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `cause` | `final Object cause` |  |

## `lib/src/services/dart_identifiers.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
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

**Constructors:**

- `const EditorBuildEntry(this.hash, this.dir, this.stamp)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `hash` | `final String hash` |  |
| `dir` | `final Directory dir` |  |
| `stamp` | `final Map<String, dynamic> stamp` | The stamp written at install: `{hash, inputs, engineRevision, flutterVersion, platform, mode, builtAt, executable}`. |
| `bundle` | `Directory get bundle` |  |
| `executable` | `String get executable` | The editor executable inside [bundle] (`stamp.executable` is relative). |

### `class EditorBuildCache`

The machine-wide, content-addressed cache of compiled project editors: `<root>/<hash>/{bundle/, stamp.json, complete}`. Projects with the same plugin set on the same engine share one entry.

Crash-safe: an install copies into `<hash>.tmp/` and renames, and only an entry with its `complete` marker is ever returned. Two launchers building the same hash serialize on `<hash>.lock` ([RandomAccessFile.lock]).

**Constructors:**

- `EditorBuildCache({Directory? root, Directory? nativeRoot})`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const EditorHostInputs({required this.hostDir, required this.engineRoot, required this.pluginDirs, required this.flutterVersion, required this.flutterRevision,...`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const FlutterToolInfo(this.version, this.revision)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `version` | `final String version` |  |
| `revision` | `final String revision` |  |
| `probe` | `static Future<FlutterToolInfo> probe({String flutter = 'flutter'}) async` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kEditorEngineRepos` | `const List<String> kEditorEngineRepos` | The engine packages a project editor is compiled from (the ones of other repos are found through the workspace's package config). |
| `fingerprintComponents` | `Future<Map<String, String>> fingerprintComponents(EditorHostInputs inputs) async` | Per-input hashes: `host.pubspec`, `host.lock`, `engine:<repo>`, `plugin:<name>`, and the plain values `flutter`, `platform`, `mode` (kept readable, so a reason can say "Flutter 3.41 → 3.44"). `plugin:<name>` hashes the plugin's `lib/`, `hook/`, `pubspec.yaml` and its `.lmplugin` (the manifest decides what the registrar compiles in: `registration_class`, `isolation`, `process_class`). |
| `fingerprint` | `Future<String> fingerprint(EditorHostInputs inputs) async` | SHA-256 (hex) over [components] (or over [fingerprintComponents] of [inputs]). |
| `fingerprintOf` | `String fingerprintOf(Map<String, String> components)` |  |
| `diffInputs` | `List<String> diffInputs(Map<String, String> older, Map<String, String> newer)` | Human-readable reasons [newer] differs from [older], one per change: "plugin a_plugin changed", "editor source changed (lumina_ui)", "Flutter 3.41.0 → 3.44.0", "build mode release → debug". |
| `engineRepoState` | `Future<String> engineRepoState(String dir) async` | A repo's source state: its git state when it is a checkout, else a content manifest (the project's copy of the engine) of `lib/`, `src/`, `hook/`, the platform runner folders `windows/`, `linux/`, `macos/` (without `flutter/ephemeral`, links not followed) and `pubspec.yaml`, so a runner change in the copy rebuilds the project editor. |

## `lib/src/services/editor_source_vendor_service.dart`

### `class EditorEngineUpdate`

A project's copy of the engine source comes from another engine than the running one (see [EditorSourceVendorService.engineUpdate]). The launcher asks "Update this project's editor?" with [fromLabel] and [toLabel].

**Constructors:**

- `const EditorEngineUpdate({required this.copied, required this.current, this.projectEngineVersion, this.changedRepos = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `copied` | `final EngineIdentity? copied` | The engine the copy was taken from, as its stamp records it; null for a copy made before stamps recorded it. |
| `projectEngineVersion` | `final String? projectEngineVersion` | The project's `.lmproject` `engine_version`, when it names a version. |
| `current` | `final EngineIdentity current` | The engine a sync would copy from. |
| `changedRepos` | `final List<String> changedRepos` | The copied repos whose engine source changed since the copy. |
| `fromLabel` | `String get fromLabel` | The copy's engine for the user: its label, else the project's `engine_version`, else "an older engine". |
| `toLabel` | `String get toLabel` | The running engine for the user; with a copy of the same version and commit (edits in a source checkout) the changed repos are named. |

### `class EditorSourceVendorService`

Copies the engine's Dart source, dependencies included, into a project's editor host: `<host>/lumina_ui/`, `<host>/lumina/`, `<host>/flutter_filament/`, … at the workspace's relative layout, so the copied pubspecs' `path: ../x` entries resolve among themselves. Packages from other repos (git dependencies: flutter_assimp, flutter_riglogic, flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared package) are copied from where the engine workspace resolved them (its package config: the pub cache, or a local checkout through `pubspec_overrides.yaml`) to `<host>/<name>/`; the host pubspec overrides every one of them to its copy. Filament's C++ tree is linked (`<host>/filament` → `<engine>/filament`), never copied.

The copy is made once and is the project's own afterwards: only [sync] replaces it.

**Constructors:**

- `EditorSourceVendorService({required this.engineRoot, this.rootPackage = 'lumina_ui', this.linkPackages = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` | The workspace root holding `lumina_ui/`, `lumina/`, `filament/`, …. |
| `rootPackage` | `final String rootPackage` | The package whose path-dependency closure is copied. |
| `linkPackages` | `final bool linkPackages` | Links each package to the engine instead of copying it: for engine development and tests, where a ~650 MB copy per build is pointless. Projects never use it. |
| `stampFileName` | `static const String stampFileName` |  |
| `engineLockFileName` | `static const String engineLockFileName` | `.lumina_engine_pubspec.lock`: the engine workspace's `pubspec.lock` as it was when the copy was made (the versions the copied source was built and tested with); [vendor] writes it and the host generator pins the host's hosted packages to it. |
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
| `vendor` | `Future<void> vendor(String hostDir, {void Function(double fraction, String file)? onProgress}) async` | Copies every [copyRoots] package into [hostDir] (replacing what is there), links Filament and writes the stamp, which records the engine the copy came from (`engine`: [EngineIdentity]). Each package is copied into `<host>/.source.tmp/` first and moved into place only when all of them copied, so an interrupted copy leaves the old state. |
| `copiedEngine` | `static EngineIdentity? copiedEngine(String hostDir)` | The engine [hostDir]'s copy was taken from, from its stamp; null when the stamp predates the record (or there is no copy). |
| `engineChangedSince` | `Future<List<String>> engineChangedSince(String hostDir) async` | The engine repos (top-level dirs) whose state changed since [hostDir]'s copy was made. |
| `engineUpdate` | `Future<EditorEngineUpdate?> engineUpdate(String hostDir, {required EngineIdentity current, String? projectEngineVersion}) async` | Whether [hostDir]'s copy comes from another engine than [current]: null when the host holds no copy or the copy is current. A stamp that records its engine differs when that engine is not [current] or the engine's source changed since ([engineChangedSince]: in a source checkout, edits count). An older stamp differs when the source changed or the project's [projectEngineVersion] names another version; the creators' placeholder `kLuminaEngineVersion` names none. |

## `lib/src/services/encoded_image_format.dart`

### `enum EncodedImageFormat`

The container an encoded image is stored in, told from its bytes.

Every format with a signature is recognised by it. TGA has none, so it is only reported when no signature matched and the header passes [TgaDecoderService.isTga]. A glTF `mimeType` or a file extension never decides: exporters label images wrongly and texture folders hold PNGs saved under `.tga` names, and a PNG read as a TGA header is an 18505x21060 image.

**Values:**

- `png`
- `jpeg`
- `webp`
- `gif`
- `bmp`
- `ktx2`
- `tga`
- `unknown`: No signature matched and the bytes are not a TGA header either.

**Constructors:**

- `const EncodedImageFormat(this.mimeType)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `mimeType` | `final String? mimeType` |  |
| `sniff` | `static EncodedImageFormat sniff(Uint8List bytes)` | The format of [bytes]; [unknown] when nothing matches. |

## `lib/src/services/engine_bootstrap.dart`

### `abstract final class LuminaRelease`

What the release workflow compiles into a Lumina Studio build (`--dart-define`): the release tag, its commit and the engine repo. All empty in a dev build.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `version` | `static const String version` | The release tag, e.g. `v0.1.0`; empty in dev builds. |
| `commit` | `static const String commit` | The full commit SHA the release was built from. |
| `repo` | `static String get repo` | The engine repo the release fetches its source from. |
| `isRelease` | `static bool get isRelease` | Whether this is a release build. |

### `typedef FilamentProvider`

Downloads (or finds) the prebuilt Filament build [version] and returns its directory, usable as the hooks' `filament_dir`: from the `filament-<version>` release, else from the [releaseTag] release (the editor's own, for releases that attached Filament themselves). The signature of `FilamentPrebuilt.ensure`.

### `enum EngineBootstrapStep`

The steps of [EngineBootstrap.ensure], in order.

**Values:**

- `prerequisites`
- `source`
- `filament`
- `packages`

**Constructors:**

- `const EngineBootstrapStep(this.label)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `label` | `final String label` |  |

### `sealed class EngineBootstrapEvent`

An event of [EngineBootstrap.run] / [EngineBootstrap.ensure].

**Constructors:**

- `const EngineBootstrapEvent()`

### `final class EngineBootstrapProgress`

[step] started or advanced; [fraction] is null while unknown.

**Constructors:**

- `const EngineBootstrapProgress(this.step, this.message, {this.fraction})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `fraction` | `final double? fraction` |  |
| `message` | `final String message` |  |

### `final class EngineBootstrapLog`

A line of tool output (git, flutter) during [step].

**Constructors:**

- `const EngineBootstrapLog(this.step, this.line)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `line` | `final String line` |  |

### `final class EngineBootstrapStepDone`

[step] finished; [skipped] when there was nothing to do.

**Constructors:**

- `const EngineBootstrapStepDone(this.step, {this.skipped = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `step` | `final EngineBootstrapStep step` |  |
| `skipped` | `final bool skipped` |  |

### `final class EngineBootstrapPrerequisites`

The prerequisite check's findings (sent whether or not any is missing).

**Constructors:**

- `const EngineBootstrapPrerequisites(this.prerequisites)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `prerequisites` | `final List<EnginePrerequisite> prerequisites` |  |

### `final class EngineBootstrapCompleted`

The checkout is ready and active.

**Constructors:**

- `const EngineBootstrapCompleted(this.checkout)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `checkout` | `final EngineCheckout checkout` |  |

### `final class EngineBootstrapFailed`

The bootstrap stopped; running it again resumes.

**Constructors:**

- `const EngineBootstrapFailed(this.error)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `error` | `final EngineBootstrapException error` |  |

### `class EnginePrerequisite`

A tool the engine source needs on this machine.

**Constructors:**

- `const EnginePrerequisite({required this.name, required this.location, required this.required, required this.hint})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` | Display name, e.g. `Git`. |
| `location` | `final String? location` | Where it was found (a path, a version), or null when missing. |
| `required` | `final bool required` | Missing required prerequisites stop the bootstrap; the others (the C++ toolchain, needed only to build games and project editors) are reported. |
| `hint` | `final String hint` | How to install it. |
| `found` | `bool get found` |  |

### `class EngineBootstrapException`

Why [EngineBootstrap.ensure] stopped.

**Constructors:**

- `const EngineBootstrapException(this.message, {required this.step, this.missing = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `step` | `final EngineBootstrapStep step` | The step that failed. |
| `missing` | `final List<EnginePrerequisite> missing` | The required prerequisites that are missing (step [EngineBootstrapStep.prerequisites]). |

### `class EngineCheckout`

A complete engine checkout, as recorded in its marker file.

**Constructors:**

- `const EngineCheckout({required this.dir, required this.version, required this.commit, required this.repo, required this.filamentVersion, required this.filamentD...`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `EngineBootstrap({required this.version, this.commit = '', this.repo = kLuminaGitUrl, Directory? engineRoot, Directory? filamentRoot, Map<String, String>? enviro...`
- `factory EngineBootstrap.release({FilamentProvider? filament})`: The bootstrap of this release build ([LuminaRelease]).

**Members:**

| Member | Signature | Description |
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

Which engine a Lumina Studio runs on, or which engine a project's copy of the engine source was taken from: a release tag and its commit, or for a source checkout the source version and its `HEAD`.

**Constructors:**

- `const EngineIdentity({required this.version, this.commit = '', this.release = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `version` | `final String version` | The version without the tag's `v`: `0.0.1-dev.7`, or `0.0.1-dev` in a source checkout. |
| `commit` | `final String commit` | The full commit SHA; empty when unknown (a source tree that is not a git checkout). |
| `release` | `final bool release` | Whether this is a fetched release checkout (named by its tag alone). |
| `of` | `static Future<EngineIdentity> of(String engineRoot) async` | The engine at [engineRoot]: a fetched release checkout names its tag and commit (its bootstrap marker), so a project editor, which carries no release defines, reads the same identity as the Studio that fetched it. Any other tree is a source checkout: [LuminaRelease.displayVersion] and `git rev-parse HEAD` there (only the tree's own checkout). |
| `stripTag` | `static String stripTag(String version)` | `v0.1.0` → `0.1.0`. |
| `label` | `String get label` | The name shown to the user: the release version, or the source version with its commit (`0.0.1-dev (08cb722)`). |
| `key` | `String get key` | `<version>@<commit>`: equal for the same engine. |
| `toJson / fromJson` | `Map<String, Object?> toJson() · static EngineIdentity? fromJson(Object? json)` | The `engine` record of the vendor stamp and of the Studio record; `fromJson` is null when no version is named. |

## `lib/src/services/engine_logger_service.dart`

### `class EngineLogEntry`

`EngineLogEntry`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EngineLogEntry.fromJson(Map<String, dynamic> json)`: Initializes `EngineLogEntry.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timestamp` | `String timestamp` | Holds the `timestamp` property or configuration state. |
| `level` | `String level` | Holds the `level` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class EngineLoggerService`

`EngineLoggerService`: Service class encapsulating business logic, file I/O, or engine processing.

**Constructors:**
- `EngineLoggerService()`: Initializes `EngineLoggerService()`.
- `EngineLoggerService._internal()`: Initializes `EngineLoggerService._internal()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `logStream` | `Stream<EngineLogEntry> get logStream` | Getter accessor returning the current value of `logStream`. |
| `logs` | `List<EngineLogEntry> get logs` | Getter accessor returning the current value of `logs`. |
| `clear` | `void clear()` | Clears all elements from the collection or buffer. |

## `lib/src/services/fbx_material_mapper.dart`

### `abstract final class FbxMaterialMapper`

FBX Phong/Lambert material values → glTF metallic/roughness:

- **base colour** = the FBX diffuse colour (Assimp: `DiffuseColor × DiffuseFactor`), raw — FBX colours are linear; alpha = the FBX `Opacity` (below 1 → alpha blend). A diffuse *texture* replaces the colour (the factor becomes white): the texture is wired straight into Base Color; - **emissive** = the FBX emissive colour (`EmissiveColor × EmissiveFactor`); above 1 it is normalized and the rest goes into `KHR_materials_emissive_strength`; an emissive texture with a black emissive colour emits at full strength; - **roughness** from the Phong exponent, see [roughnessFromPhong]; - **metallic** 0 — Phong has no metalness — unless the file carries a PBR value (Maya Stingray/Arnold `Maya|metallic`, 3ds Max Physical `metalness`). `ReflectionFactor` is *not* used: the FBX SDK template defaults it to 1, so every such export would come in as metal.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `roughnessFromPhong` | `static double roughnessFromPhong({required double shininess, required double specular})` | Perceptual roughness for a Phong material with exponent [shininess] and specular intensity [specular] (specular colour luminance × specular factor). |
| `valuesFor` | `static ({List<double>? baseColor, double alpha, double metallic, double roughness, List<double> emissive}) val...` | The glTF values for one flutter_assimp `material_details` entry. |
| `applyToGltf` | `static void applyToGltf(Map<String, dynamic> json, List<Map> details)` | Writes each FBX material's values ([details], flutter_assimp's `material_details`, matched by name, else by index) into the glTF [json]'s materials in place, replacing the glTF exporter's guess (`roughness = 1 − sqrt × specular`, which makes every such export fully rough). |
| `setEmissive` | `static void setEmissive(Map<String, dynamic> json, Map material, List<double> rgb)` | Sets [material]'s emissive colour [rgb] (linear, any intensity): a colour above 1 is normalized, the scale going into `KHR_materials_emissive_strength`; black removes the emission. |
| `emissiveOf` | `static List<double> emissiveOf(Map material)` | The emissive colour × strength a glTF [material] asks for. |

## `lib/src/services/fbx_texture_locator.dart`

### `enum FbxTextureChannel`

A texture channel an image beside an FBX can be matched to by its name, and the glTF slot it fills.

**Values:**

- `baseColor`
- `normal`
- `emissive`
- `orm`
- `occlusion`

**Constructors:**

- `const FbxTextureChannel(this.suffix, this.slot)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `suffix` | `final String suffix` | The suffix of the texture asset the importer names it by (`T_<core>_<suffix>`). |
| `slot` | `final String slot` | The `.lmas` material sampler / glTF slot it fills. |

### `class FbxTextureLocator`

Where the textures of an FBX are looked for, in order — the path as written, then relative to the FBX — plus the folders people keep textures in:

- **near folders** (searched first, and the only ones whose images are matched to materials by name): the folders chosen in the import options, the FBX's folder, and its `Textures/`, `textures/`, `<fbx name>/` and `<fbx name>.fbm/` subfolders (`.fbm` is where the FBX SDK extracts embedded media); - **reference folders** (a referenced file name only): the near folders, then the `Textures`/`textures`/`Texturen`/`Materials` folders of the FBX's folder and its three nearest ancestors, with their direct subfolders.

**Constructors:**

- `FbxTextureLocator({required this.fbxFile, List<String> extraDirs = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fbxFile` | `final File fbxFile` |  |
| `extraDirs` | `final List<String> extraDirs` |  |
| `sourceDir` | `Directory get sourceDir` |  |
| `nearDirs` | `late final List<Directory> nearDirs` |  |
| `referenceDirs` | `late final List<Directory> referenceDirs` |  |
| `nearImages` | `late final List<File> nearImages` | Every image file in the [nearDirs], each once. |
| `locateReference` | `File? locateReference(String uri)` | The file an FBX texture reference [uri] names: as written, relative to the FBX (each with its folders and file matched in any case when that spelling is not on disk, see [findIgnoringCase]), then by file name (case-insensitive) in the [referenceDirs], then as an image in the [nearDirs] whose name ends in `_<file name>` (an exporter that prefixed the asset's name, e.g. Godot's `SM_Slot_Machine_T_Tread_Plate_Normal.png`). |
| `findIgnoringCase` | `static File? findIgnoringCase(String path, {Directory? base})` | The file [path] (`/`- or `\`-separated; relative to [base], or absolute) names where its folders or file are spelled with other capitals than on a case-sensitive disk (Linux: `Maps/wood.png` finds `maps/wood.png`): each segment goes to the entry of that name in any case ([pickIgnoringCase]). `.` and `..` are followed as written. Null when a segment has no match. A case-insensitive file system (Windows, macOS) finds these by the exact lookup already. |
| `pickIgnoringCase` | `static T? pickIgnoringCase<T extends FileSystemEntity>(Iterable<T> entries, String name)` | The entry of [entries] named [name] in any case: the one spelled exactly so when there is one, else the first by name (code units), so the choice never depends on the order the directory was listed in. |
| `channelOf` | `static (FbxTextureChannel, int)? channelOf(String stem)` | The channel a file name (without extension) ends in, and how many of its tokens the suffix takes. |
| `coreName` | `static String coreName(String material)` | A material name without its asset-type prefix (`MI_`, `M_`, `Mat_`, `Material_`). |
| `matchByName` | `Map<int, Map<FbxTextureChannel, File>> matchByName(List<String> materials, {Set<String> exclude = const {}})` | The images of the [nearDirs] matched to [materials] by name: a file matches a material when its name holds the material's name (or its [coreName]) as whole tokens before a channel suffix — `T_Wood_BaseColor` for `M_Wood`, `SM_Slot_Machine_MI_Neon_Green_SM_Slot_Machine_Emissive` for `MI_Neon_Green`. A file goes to the material with the longest matching name (`MI_Plastic_Black_Matte_1_Normal` belongs to `MI_Plastic_Black_Matte_1`, not `MI_Plastic_Black`); files in [exclude] (already bound by reference) are skipped. Result: material index → channel → file (the first by path when several fit). |

---

[Previous: File formats and repositories](formats.md) | [Up: lumina_core (pure-Dart foundation)](index.md) | [Next: Services (continued)](services-continued.md)
