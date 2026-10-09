[Türkçe](../../tr/lumina_core/services-continued.md)

# Services (continued)

The pure services, part two: generated-code migration, GLB animation merging and retargeting, the glTF packer, import formats, level templates, the config and data folders, plugin packaging and host patching, the primitive GLB factory, project engine links, the TGA decoder and workspace paths. File paths are relative to the `lumina_core/` package directory.

**On this page:**

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
- [`lib/src/services/flutter_filament_web_prebuilt.dart`](#libsrcservicesflutter_filament_web_prebuiltdart)
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

**Top-level Functions:**

- **`Map<String, dynamic> luminaTemplateSunActor() => _sun()`**: The directional sun actor map shared by the game and level templates.
- **`Map<String, dynamic> luminaTemplateSkyActor() => _sky()`**: The sky/atmosphere actor map shared by the game and level templates.

### `enum GameTemplateKind`

Which runtime pawn shape a template scaffolds.

### `class GameTemplate`

One entry of the shared template catalog.  This is the single source of truth both the launcher UI and `ProjectRepository.createProjectStream` read: the chip label and blurb, the actors seeded into `contents/levels/L_DefaultLevel.lmas`, the input actions and mapping context written into the manifest, and whether user-owned character / game-mode source is generated.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `icon` | `String icon` | Short icon hint the launcher maps to a shadcn icon. |
| `kind` | `GameTemplateKind kind` | Holds the `kind` property or configuration state. |
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

**Constructors:**
- `GameTemplateCatalog._()`: Initializes `GameTemplateCatalog._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `byId` | `static GameTemplate byId(String? id)` | Resolves [id] to a template, tolerating the legacy `'Blank 3D'` label and unknown ids (both fall back to [blank3d]). |

## `lib/src/services/generated_code_migration.dart`

### `class LuminaGeneratedCodeMigration`

Brings a project's generated Dart written by earlier Lumina versions to the current naming rules ([dartTypeName], [dartFileName]).

Earlier generators named the files in `lib/levels/`, `lib/actors/`, `lib/anim/` and `lib/widgets/` after their assets (`L_Main.dart`, `BP_Door.dart`) and their classes `L_Main`, `BPDoor`, `WBPHud`. Today the files are snake_case (`l_main.dart`, `bp_door.dart`) and the classes UpperCamelCase (`LMain`, `BpDoor`, `WbpHud`). [migrate] renames the legacy files — keeping their contents, so `BEGIN USER CODE` regions survive — renames the classes they declare, and rewrites the imports and class references of every Dart file under `lib/`, so a project regenerates cleanly and still compiles in between. A legacy file whose snake_case file already exists is stale and is deleted.

Earlier generators also keyed placed actors and level scripts with Flutter's `ValueKey` (`key: const ValueKey('act_floor')`, a `{Key? key, ...}` Blueprint actor factory, `key is ValueKey<String>` in the data-layer assignment) and imported `package:flutter/foundation.dart` for it. Generated levels, Blueprints and registries now write `LuminaObjectKey('<id>')`; [migrateObjectKeys] rewrites the old files of `lib/levels/`, `lib/actors/` and `lib/anim/` in place (widgets keep Flutter's keys). [migrate] runs it first, and opening a project (`ProjectRepository.loadProject` → `prepareAssetIndex` → `migrateGeneratedCode`) runs both on a background isolate.

Generated code imported the engine's `lumina_runtime.dart`, which also carried the game widget, UMG, media and mouse capture. Those moved to `lumina_widgets`: [migrateGameImports] rewrites the files under `lib/` that use one of them (the launcher, UMG widget classes and their registry) to import `kLuminaGameLibrary` (`package:lumina_widgets/lumina_game.dart`; a `show` / `hide` clause is kept), and [migratePubspecGameDependency] adds `lumina_widgets` next to the `lumina` dependency in the same form (git: same url and ref, `path: lumina_widgets`; path: the folder beside `lumina`). [migrate] and opening a project run both.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `generatedFolders` | `static const List<String> generatedFolders` | The `lib/` folders whose files are named after assets. |
| `migrate` | `static Map<String, String> migrate(String projectDir)` | Migrates [projectDir]'s generated Dart; returns the renamed files, `lib/…` old path → new path (empty when there was nothing to migrate). |
| `objectKeyFolders` | `static const List<String> objectKeyFolders` | The generated folders whose code keys engine objects: `levels`, `actors`, `anim`. |
| `migrateObjectKeys` | `static List<String> migrateObjectKeys(String projectDir)` | Rewrites Flutter `Key` / `ValueKey` on engine objects to `LuminaObjectKey` in [objectKeyFolders]; returns the rewritten files (`lib/...`), empty when none needed it. |
| `rewriteObjectKeys` | `static String rewriteObjectKeys(String source)` | [source] with `ValueKey<String>` / `ValueKey(` / `Key? key` replaced by `LuminaObjectKey` and their `foundation.dart` import dropped (other shown names kept). Idempotent. |
| `migrateGameImports` | `static List<String> migrateGameImports(String projectDir)` | Rewrites the `lumina_runtime.dart` import of the files that use the game UI to the game library; returns them (`lib/...`). |
| `rewriteGameImports` | `static String rewriteGameImports(String source)` | [source] with `package:lumina/lumina_runtime.dart` imports replaced by the game library (a duplicate plain import dropped). |
| `migratePubspecGameDependency` | `static bool migratePubspecGameDependency(String projectDir)` | Adds `lumina_widgets` next to `lumina` in the project's pubspec; true when it changed. |
| `withGameDependency` | `static String withGameDependency(String pubspec)` | The pubspec text with that dependency added. |

## `lib/src/services/glb_animation_merger.dart`

### `class GlbClipSource`

One animation to merge into a base GLB: animation [animationIndex] of the GLB [bytes], stored in the result under [name].

**Constructors:**

- `const GlbClipSource({required this.name, required this.bytes, this.animationIndex = 0, this.stripRootMotion = false, this.rotationOnly, this.keepTranslationForB...`
- `factory GlbClipSource.fromGltf(File gltf, {String? name, int animationIndex = 0})`: A clip exported as a `.gltf` document with its keys in a sibling binary file (`buffers[].uri`, e.g. `Land.bin`), packed into a GLB in memory.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `bytes` | `final Uint8List bytes` |  |
| `animationIndex` | `final int animationIndex` |  |
| `stripRootMotion` | `final bool stripRootMotion` | Drop the clip's `root` translation channel: a root-motion export moves the whole mesh away from its capsule and snaps it back when the clip ends; the character's movement provides the travel instead. |
| `rotationOnly` | `final bool? rotationOnly` | Rotation-only retarget: drop the clip's translation and scale channels for every bone except [keepTranslationForBones], keeping all rotations, so a clip exported from a skeleton with different bone lengths (the same bone names on other proportions) does not push the base's bones to the other skeleton's offsets. The kept bones' translation keys are scaled by the ratio of the base's to the source's bind length of that bone. `null` (the default) turns it on automatically when the clip's skeleton differs from the base's — its skin joints and the base's are not the same set. |
| `keepTranslationForBones` | `final Set<String> keepTranslationForBones` |  |

### `class GlbClipMergeReport`

What merging one clip did to its channels: the bones whose channels were copied and the bones the base skeleton lacked (dropped only with `skipMissingBones`).

**Constructors:**

- `const GlbClipMergeReport({required this.clip, required this.keptBones, required this.droppedBones, required this.keptChannels, required this.droppedChannels, th...`

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const GlbMergeReport(this.clips)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `clips` | `final List<GlbClipMergeReport> clips` |  |
| `forClip` | `GlbClipMergeReport? forClip(String name)` |  |

### `class GlbDocument`

A GLB split into its JSON document and its binary chunk.

**Constructors:**

- `GlbDocument(this.json, this.bin)`
- `factory GlbDocument.parse(Uint8List bytes, {String label = 'input'})`: Parses [bytes] as a binary glTF 2.0 container. [label] names the input in the [FormatException] thrown for anything that is not one.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `json` | `final Map<String, dynamic> json` |  |
| `bin` | `final Uint8List bin` |  |
| `encode` | `Uint8List encode()` | Serializes the document back into a GLB, padding the JSON chunk with spaces and the binary chunk with zeros to 4-byte boundaries. |

### `class GlbAnimationMerger`

Merges animations from several GLBs into one skinned GLB, so a single gltfio asset — and therefore a single `FilamentAnimator` — can play them all.

gltfio's animator only plays animations stored in the same asset as the nodes they move. Clip sets exported one animation per file (Unreal's mannequin sequences, Mixamo downloads) are therefore merged ahead of time. Channels are retargeted by **node name**: two exports of the same skeleton do not have to list their bones in the same order, and the Unreal mannequin clips in `test-assets/` indeed permute the finger bones relative to `SKM_Manny_Simple`.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `animationNames` | `static List<String> animationNames(Uint8List glb)` | The names of the animations stored in [glb], in index order. |
| `hasUnitScales` | `static bool hasUnitScales(Uint8List glb, {int animationIndex = 0, double tolerance = 1e-4})` | Whether every scale channel of animation [animationIndex] keeps every bone at scale 1 (within [tolerance]); true when it has no scale channel. |
| `hasCollapsedScales` | `static bool hasCollapsedScales(Uint8List glb, {int animationIndex = 0})` |  |
| `merge` | `static Uint8List merge({required Uint8List base, required List<GlbClipSource> clips, bool skipMissingBones = f...` | Returns [base] with one animation appended per entry of [clips]. |
| `mergeWithReport` | `static ({Uint8List bytes, GlbMergeReport report}) mergeWithReport({required Uint8List base, required List<GlbC...` | [merge], also reporting per clip which bones' channels were kept and, with [skipMissingBones], which were dropped because the base skeleton has no node of that name (an export with extra bones — the Unreal mannequin's `breast_l/r` — animates the bones both skeletons share and leaves the rest at the bind pose). |

## `lib/src/services/glb_animation_retargeter.dart`

### `class GlbSkeletonMatch`

How well a clip's animated bones match a skeleton, by name.

**Constructors:**

- `const GlbSkeletonMatch({required this.matched, required this.animated, required this.missing})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `matched` | `final int matched` | Animated clip bones the skeleton has. |
| `animated` | `final int animated` | Bones the clip animates. |
| `missing` | `final List<String> missing` | Animated clip bones the skeleton lacks. |
| `score` | `double get score` | Share of the clip's animated bones found in the skeleton, 0–1. |

### `class GlbRetargetResult`

A clip retargeted into a skeletal mesh GLB.

**Constructors:**

- `const GlbRetargetResult({required this.glb, required this.clipName, required this.clipIndex, required this.duration, required this.mappedBones, required this.re...`

**Members:**

| Member | Signature | Description |
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

GEM-X SOMA clips use a separate semantic mapping: `LeftLeg`/`RightLeg` drive
thighs and `LeftShin`/`RightShin` drive calves. `Chest` drives the highest thoracic
bone (`spine_05` when present). Their GLB nodes must contain a neutral reference
pose, declared by `extras.somaReferencePose = "neutral"`. Retargeting transfers
model-space motion relative to that reference onto the target bind axes. Target
bone offsets stay intact, and root-relative displacement is added to the target
pelvis placement. Twist/corrective bones follow their parents. Upper-arm and
forearm reference directions align through the semantic elbow and wrist children;
T-pose source motion does not acquire the A-pose target's reference bend. Neutral
torso and leg placement remain unchanged; neutral arms follow the source reference
direction. Older GEM-X exports without that reference
are refused with a regeneration message.

The implementation is divided into `glb_animation_retargeter/models.dart`,
`operation.dart`, `pose_sampling.dart`, `rest_alignment.dart` and `soma_mapping.dart`; the public entry
point remains `GlbAnimationRetargeter.retargetInto`.

Unlike [GlbAnimationMerger], which copies channels verbatim onto an identical skeleton, this handles skeletons that differ in hierarchy and proportions (UE5's spine_04/05, neck_02 and metacarpals have no UE4 counterpart):

- **Rotation only.** Skeleton bones the clip lacks keep their rest rotation relative to their parent. Mapped bones depend on whether the two skeletons share their bone axis convention (pelvis, spine_01 and thighs within 45° at rest):
  - **Shared axes** (UE4 → UE5 mannequin): every mapped bone takes the clip bone's model-space rotation, arms included, so compatible skeletons keep the clip's orientations exactly.
  - **Other axes or rest poses** (the Blender-exported Superhero, Y along each bone and T-pose arms, onto Manny or a MetaHuman, X along each bone and A-pose arms): each mapped bone takes the clip bone's model-space motion away from its rest pose, applied to the target rest. Limb bones (from the upper arm and the thigh down, hands, fingers) first turn their target rest to lie like the clip's rest bone, measured by their nearest mapped descendants and the clip joints those map to (best fit over all of them: a hand over its fingers), so every limb segment points where the clip's segment points. The trunk (pelvis, spine, neck, head) and the clavicles keep the target's own rest, so the chest and head keep the character's build. A target with more numbered spine bones than the clip takes the clip's top spine bone (the chest) on its own top spine bone (`spine_05` against `spine_03`); the spine bones in between ride on the one below.
  - Twist bones the clip does not animate ride on their limb; forearm twist bones (`lowerarm_twist_NN_l/r`) also roll with the hand by their share of the forearm length.
- **Translations come from the target skeleton**, except the skeleton root (copied: root motion and placement) and the pelvis (copied, scaled by the target's leg length over the clip's). Clip bone translations are otherwise ignored: an Unreal FBX carries the authoring skeleton's proportions in them.

Body joints receive dynamic or constant rotation/translation channels. Unmapped facial and corrective joints are excluded so body clips preserve their local reference transforms.

**Batch retargeting.** `GlbRetargetBatch(target)` imports many clips into one mesh: the target GLB is parsed once, each `add(clip:, clipName:, animationIndex:)` retargets one clip exactly as `retargetInto` does (same poses, same clip indices; its result carries an empty `glb`), and `finish()` encodes the GLB once and returns `(glb:, clips:)`, every clip result carrying that GLB. Rest channels are compact: a bone gets a constant rest channel in a clip only when another animation of the asset moves it (so switching clips still resets it), and the constant values are shared between clips. A set of clips that animate the same bones then costs little more than their keyed motion; one `retargetInto` per clip parses and copies the whole growing GLB each time and writes both channels of every body joint per clip, which on a 926-joint MetaHuman with hundreds of clips is quadratic.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `jointNames` | `static Set<String> jointNames(Uint8List glb)` | Names of the joints of every skin in [glb]. |
| `animatedNodeNames` | `static Set<String> animatedNodeNames(Uint8List clip, {int animationIndex = 0})` | Names of the nodes animation [animationIndex] of [clip] animates. |
| `match` | `static GlbSkeletonMatch match({required Uint8List target, required Uint8List clip, int animationIndex = 0})` | How well [clip]'s animation matches [target]'s skeleton. |
| `matchNames` | `static GlbSkeletonMatch matchNames(Set<String> targetJoints, Set<String> animated)` |  |
| `retargetInto` | `static GlbRetargetResult retargetInto({required Uint8List target, required Uint8List clip, required String cli...` | Retargets animation [animationIndex] of [clip] onto [target]'s skeleton and returns [target] with it appended as [clipName] (replacing an animation of that name). |

### `class GlbRetargetBatch`

| Member | Signature | Description |
| :--- | :--- | :--- |
| constructor | `GlbRetargetBatch(Uint8List target)` | Parses [target] (throws like `retargetInto` for a GLB without a skin or with several buffers). |
| `add` | `GlbRetargetResult add({required Uint8List clip, required String clipName, int animationIndex = 0})` | Retargets one clip (replacing an animation of that name); the result's `glb` is empty. Throws `StateError` after `finish`. |
| `length` | `int get length` | Clips added so far. |
| `finish` | `({Uint8List glb, List<GlbRetargetResult> clips}) finish()` | The target with every clip, and the clip results carrying it. Once only. |

## `lib/src/services/gltf_packer.dart`

### `class GltfPacker`

Packs a text `.gltf` and the files it references (its `.bin` buffers and image files) into one self-contained GLB.

The import pipeline stores a mesh's payload as GLB, so a `.gltf` is staged through [packFile] — without it the payload kept a relative `uri` that no longer resolves once the file is in the project.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `externalUris` | `static List<String> externalUris(Map<String, dynamic> gltf)` | The relative file URIs (decoded, `/`-separated) [gltf] references: external buffers first, then images. `data:` URIs are left out. |
| `referencedFiles` | `static List<String> referencedFiles(String gltfPath)` | The files [gltfPath] references, resolved beside it (they need not exist). |
| `packFile` | `static Uint8List packFile(String gltfPath, {Uint8List? missingImage})` | [gltfPath] as GLB bytes: every buffer (external or `data:`) merged into the BIN chunk, every external or `data:` image moved into a buffer view. Throws a [FormatException] naming a referenced file that is missing, except an image file when [missingImage] is given: that image then gets these bytes instead (the file-manager thumbnailer draws the geometry of a model whose textures were not copied along; an import never passes it). |

## `lib/src/services/import_formats.dart`

### `enum ImportFormatKind`

What an importable file becomes.

**Values:**

- `mesh`: glTF / GLB, OBJ, FBX, Collada, 3DS, PLY, DirectX, STL → a static or skeletal mesh (or an animation).
- `texture`: PNG, JPEG, WebP, TGA → a texture.
- `audio`: WAV, OGG, MP3 → a sound.
- `asset`: A `.lmas` from another project, copied in as it is.

### `class ImportFormats`

The file types the import pipeline takes: the one table [AssetRepository.stageImport] classifies by, the Content Browser's file picker offers and the folder importer (`ImportFolderScanner`) walks.

**Members:**

| Member | Signature | Description |
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

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `material` | `static String material(String raw, String baseName)` | `M_Wood` stays, `MI_Wood` → `M_Wood`, a name holding the file's name gets `M_`, anything else becomes `M_<file>_<name>`. |
| `texture` | `static String texture(String raw, String baseName)` | `T_Wood_N` stays, `MI_…`/`M_…` swap the prefix for `T_`, a name holding the file's name gets `T_`, anything else becomes `T_<file>_<name>`. |

## `lib/src/services/level_template_service.dart`

**Top-level Functions:**

- **`Map<String, dynamic> defaultWorldPartitionSection()`**: A fresh `metadata.worldPartition` section carrying the runtime's own defaults and no data layers (a level authors those itself).

### `class LevelTemplate`

One entry in the New Level dialog.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | One line describing exactly what this template seeds — shown in the dialog, so it must stay truthful. |
| `levelActors` | `List<Map<String, dynamic>> get levelActors` | Fresh actor maps (`EditorActorNode.toMap()` shape) for a new level. |
| `worldPartition` | `Map<String, dynamic>? get worldPartition` | Fresh `metadata.worldPartition` section, or null when the template does not author one (`Empty`, `Default`). |

### `class LevelTemplateCatalog`

The templates `File → New Level…` offers, in dialog order.

**Constructors:**
- `LevelTemplateCatalog._()`: Initializes `LevelTemplateCatalog._()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `byId` | `static LevelTemplate byId(String? id)` | Resolves [id] to a template; unknown ids fall back to [standard]. |

## `lib/src/services/lumina_config_dir.dart`

### `abstract final class LuminaConfigDir`

The per-user directory Lumina Studio keeps its settings in: `recent_projects.json`, `launcher_settings.json`, `editor_quality.json`, `plugin_wizard.json`.

Every reader and writer of those files resolves the directory here, in this order: 1. a directory the caller passes explicitly (a repository's `configDir`); 2. [override], the in-process redirect test harnesses set; 3. the `LUMINA_CONFIG_DIR` environment variable; 4. `~/.config/lumina`.

Test suites set [override] to a fresh temp directory in their `flutter_test_config.dart`, so no test reads or writes the user's own files.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` | The environment variable that redirects the directory for a whole process (tooling exports it to the test runs it starts). |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. Dart cannot set an environment variable for its own process, so a test harness sets this. |
| `resolve` | `static Directory resolve({Directory? explicit, Map<String, String>? environment})` | The config directory. [explicit] wins over everything else; [environment] defaults to the process environment. |
| `file` | `static File file(String name, {Directory? explicit})` | The file [name] in the resolved directory. |

## `lib/src/services/lumina_data_dir.dart`

### `abstract final class LuminaDataDir`

The per-user directory Lumina keeps downloaded data in: the engine source a release build fetches for itself (`engine/<version>/`) the prebuilt Filament builds (`filament/<version>/`) and flutter_filament's downloaded web module (`flutter_filament_web/module/`).

- Windows: `%LOCALAPPDATA%\Lumina`; - Linux: `$XDG_DATA_HOME/lumina`, else `~/.local/share/lumina` (where the user plugins and the MiniAI models live too); - macOS: `~/Library/Application Support/Lumina`.

`LUMINA_DATA_DIR` redirects it for a whole process; [override] does the same in-process (test harnesses).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `environmentVariable` | `static const String environmentVariable` |  |
| `override` | `static Directory? override` | In-process redirect, ahead of [environmentVariable]. |
| `resolve` | `static Directory resolve({Map<String, String>? environment, String? operatingSystem})` | The data directory for [environment] (default: the process environment) on [operatingSystem] (default: this one). |
| `engineRoot` | `static Directory engineRoot({Map<String, String>? environment, String? operatingSystem})` | `<data>/engine`: one checkout per release tag. |
| `filamentRoot` | `static Directory filamentRoot({Map<String, String>? environment, String? operatingSystem})` | `<data>/filament`: one prebuilt Filament per Filament version. |
| `webModuleRoot` | `static Directory webModuleRoot({Map<String, String>? environment, String? operatingSystem})` | `<data>/flutter_filament_web`: flutter_filament's downloaded WebAssembly module (one copy, replaced when the editor version changes). |

## `lib/src/services/flutter_filament_web_prebuilt.dart`

### `abstract final class FlutterFilamentWebPrebuilt`

The flutter_filament web module every Lumina release attaches (`.github/workflows/release.yml`): `flutter-filament-web-<tag>.zip` plus a `.sha256` sidecar, holding one folder `flutter-filament-web-<tag>` with `flutter_filament.js`, `flutter_filament.wasm` and a `README.md`.

`ensure` downloads the archive of the editor's own release; when that release has none (HTTP 404) or the editor is a development build (no tag), it takes the newest non-draft release that carries the archive and its sidecar, found through the GitHub releases API. The archive is checked against its sidecar before anything is unpacked (`ReleaseAssets.fetch`), unpacked to `<root>/module`, and `lumina-web-module.json` there records the release it came from (`tag`), the editor version that asked for it (`requestedTag`), the verified `sha256` and `fetchedAt`. An install made for the same editor version is reused without the network; one made for another version is downloaded again. A failed or interrupted run keeps the previous install. The default root is `LuminaDataDir.webModuleRoot()`; `LUMINA_RELEASE_BASE_URL` and `LUMINA_RELEASE_API_URL` redirect the download and the listing (mirrors).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fileNames` | `static const List<String> fileNames` | `flutter_filament.js`, `flutter_filament.wasm`. |
| `markerFileName` | `static const String markerFileName` | `lumina-web-module.json`. |
| `defaultApiUrl` / `apiUrlVariable` | `static const String` | The GitHub releases listing and the variable that redirects it. |
| `baseName` / `archiveName` | `static String baseName(String tag)` / `archiveName(String tag)` | `flutter-filament-web-<tag>` and `flutter-filament-web-<tag>.zip`. |
| `moduleDir` | `static Directory moduleDir(Directory root)` | `<root>/module`. |
| `defaultRoot` | `static Directory defaultRoot()` | `LuminaDataDir.webModuleRoot()`. |
| `installed` | `static FlutterFilamentWebInstall? installed([Directory? root])` | The unpacked module with its marker, or null when missing or incomplete. |
| `ensure` | `static Future<FlutterFilamentWebInstall> ensure({required String requestedTag, Directory? root, void Function(double, String)? onProgress, String? baseUrl, String? apiUrl, bool force = false, HttpClient? httpClient, Map<String, String>? environment})` | Installs the module for the editor version `requestedTag` (empty in a development build) as described above. Throws `FlutterFilamentWebPrebuiltException` (offline, checksum mismatch, no release with the asset). |
| `newestTagWithModule` | `static Future<String?> newestTagWithModule(String apiUrl, {HttpClient? httpClient, Set<String> skip = const {}})` | The newest non-draft release in the listing whose assets hold the archive and its sidecar. |

### `class FlutterFilamentWebInstall`

A downloaded module: `directory` (both files), `tag` (the release it came from), `requestedTag` (the editor version that asked for it) and `sha256`.

## `lib/src/services/plugin_host_patcher_service.dart`

### `class PluginHostPatcherService`

`PluginHostPatcherService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `patchPubspec` | `Future<void> patchPubspec(Directory hostRoot, List<LuminaPluginDescripto...` | Executes `patchPubspec` operation. |
| `generateRegistrar` | `Future<void> generateRegistrar(Directory hostRoot, List<LuminaPluginDesc...` | Executes `generateRegistrar` operation. |
| `registrarSource` | `String registrarSource(List<LuminaPluginDescriptor> enabledCodePlugins)` | The registrar library: `kEnabledPlugins` (one instance per editor module), `kPluginProcesses` and `registerAllPlugins`; deterministic for a plugin list. `kPluginProcesses` maps every plugin whose manifest says `"isolation": "process"` to a factory of its `process_class`, whatever a project's `plugin_isolation` says (the editor applies the override when it starts), for example `'my_tools': () => my_tools_plugin.MyToolsProcess(),`; with none it is `{}`. |

## `lib/src/services/plugin_pack_script.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kPluginPackScriptFileName` | `const String kPluginPackScriptFileName` | Where the script lives in a plugin (under `tool/`). |
| `kPluginPackScriptPath` | `const String kPluginPackScriptPath` | The plugin-relative path of the script. |
| `kPluginPackScript` | `const String kPluginPackScript` | The script's source. |

## `lib/src/services/primitive_glb_factory.dart`

### `class PrimitiveGlbFactory`

Builds a real glTF 2.0 binary (`.glb`) for an engine primitive.  `Primitive` actors — the template test rooms, and "spawn a cube" — carry a shape and a size instead of an imported model. Rather than teaching every consumer a second geometry path, the shape is turned into an ordinary glTF binary here, so it flows through the same parser, the same renderer, the same picking and the same triangle counter as any imported mesh.  Geometry is centred on the origin and sized in world units (cm), so the actor's own transform places it. Output is deterministic for a given request.  Every shape carries `TEXCOORD_0` and `TANGENT`, so a textured (or normal-mapped) material assigned to it draws its texture: each box face and the plane map the whole 0..1 square upright, a sphere and a cylinder wall wrap it once around (u) from top (v = 0) to bottom (v = 1), and cylinder caps map it as a disc. UVs follow glTF (v runs down the image); tangents point along +u, with `w` making `cross(normal, tangent) * w` point up the image, as glTF defines it.

**Constructors:**
- `PrimitiveGlbFactory._()`: Initializes `PrimitiveGlbFactory._()`.

### `class _Geometry`

`_Geometry`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_Geometry(this.positions, this.normals, this.uvs, this.indices)`: Initializes `_Geometry(this.positions, this.normals, this.uvs, this.indices)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `normals` | `List<double> normals` | Holds the `normals` property or configuration state. |
| `uvs` | `List<double> uvs` | Holds the `uvs` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |

## `lib/src/services/project_engine_link.dart`

### `class ProjectEngineLink`

How a game project reaches the engine.

The project's `pubspec.yaml` depends on `lumina` and `lumina_widgets` ([enginePackages]; generated code imports `lumina_game.dart`) through git ([kLuminaGitUrl], `path: lumina` / `path: lumina_widgets`), so it is committable and builds on any machine once the LuminaGame repos are published. One of two things makes it build on the machine of the engine checkout the editor runs from:

- a gitignored `pubspec_overrides.yaml` pinning `lumina` and every package of its path/git closure (`flutter_filament`, the tools packages, …) to the local checkout (absolute `/`-separated paths: the project folder and the engine are on unrelated paths, often on different drives); each local package's hook then finds Filament through its own `../filament`; - or, building against git, `hooks: user_defines:` in `pubspec.yaml` telling the native-assets hooks of flutter_filament / flutter_assimp / flutter_riglogic where this machine's Filament build, libc++ and RigLogic library are. A package resolved from git (a pub-cache checkout) has no `../filament` beside it. The hooks runner reads user-defines from the root `pubspec.yaml` only (pub rejects a `hooks` key in `pubspec_overrides.yaml`), so this block holds machine paths; it is rewritten whenever the project is linked again.

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const ProjectEngineLinkResult({this.engineRoot, this.overrides = const {}, this.hookUserDefines = const {}})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineRoot` | `final String? engineRoot` | The local engine checkout the project was linked to; null: git only. |
| `overrides` | `final Map<String, String> overrides` | The packages pinned in `pubspec_overrides.yaml` (name → dir). |
| `hookUserDefines` | `final Map<String, Map<String, String>> hookUserDefines` | The hook settings written into `pubspec.yaml`. |
| `isLocal` | `bool get isLocal` |  |

## `lib/src/services/space_free_build_dir.dart`

### `abstract final class SpaceFreeBuildDir`

Where `flutter pub get` / `flutter build` run for a folder on Windows: a junction to it under a space-free root, so the native-assets hooks never see a path with a space. native_toolchain_c runs `cl.exe` through `cmd.exe`, and `cl.exe` lives under "C:\Program Files", so one more quoted argument (an output dir, include or library under "…\Lumina Projects\…") breaks cmd's quoting ("'C:\Program' is not recognized"). The alias also keeps every path short. The files stay where they are; only the path the build sees changes. Used by the project editor build ([EditorBuildService.buildDirOf]), Cook & Package and Play Standalone.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `of` | `static String of(String dir, {Directory? aliasRoot, String? platform})` | The build folder for [dir]: [dir] itself off Windows (or when [platform] is not `windows`), else a stable junction to it under [aliasRoot] (default [defaultAliasRoot]), one per folder. A path at the alias that is not a link is never touched: [dir] is used as it is. |
| `defaultAliasRoot` | `static String defaultAliasRoot()` | `%LOCALAPPDATA%\lumina\hosts`, or `<SystemDrive>\lumina-hosts` when `%LOCALAPPDATA%` itself has a space (a user name with a space). |

## `lib/src/services/tga_decoder_service.dart`

### `class TgaImage`

`TgaImage`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `rgbaBytes` | `Uint8List rgbaBytes` | Holds the `rgbaBytes` property or configuration state. |

### `class TgaDecoderService`

`TgaDecoderService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isTga` | `static bool isTga(Uint8List bytes)` | Checks if given bytes match a valid TGA image header |
| `decode` | `static TgaImage? decode(Uint8List bytes)` | Decodes TGA binary bytes into raw RGBA8888 pixels |
| `tgaToPng` | `static Uint8List? tgaToPng(Uint8List tgaBytes)` | Converts TGA bytes directly to standard PNG bytes |
| `encodePng` | `static Uint8List encodePng(Uint8List rgba, int width, int height)` | Pure Dart standard PNG encoder with zlib compression |

## `lib/src/services/umg_widget_library_service.dart`

### `abstract final class UmgWidgetLibraryService`

Keeps a game project's `pubspec.yaml` in line with its UMG widget library: a `shadcn` project depends on shadcn_flutter at the editor's version ([kGameShadcnFlutterVersion]), a `flutter` project does not. The dependency lives in a marked block so switching back and forth is exact and idempotent.

**Members:**

| Member | Signature | Description |
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

**Members:**

| Member | Signature | Description |
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
| `pluginPackageDirs` | `static List<String> pluginPackageDirs(String root)` | The root directories of the packages in `<root>/.dart_tool/package_config.json` that ship a `<name>.lmplugin` manifest (the engine's built-in plugins: a local checkout through `pubspec_overrides.yaml`, or the pub cache's git checkout), sorted by name; empty before `pub get`. |
| `gitSourceOf` | `static LuminaGitSource? gitSourceOf(String root, String name, {String? packageDir})` | The git dependency `<root>/pubspec.lock` resolved [name] from (url, path, resolved commit); null for a path override or a hosted package, and, with [packageDir], unless that folder is the checkout of that commit. |
| `testAssets` | `static String get testAssets` | The shared 3D test assets (`<root>/test-assets`). |
| `findRootFrom` | `static String? findRootFrom(String start)` | The first of [start] and its ancestors holding `lumina/pubspec.yaml`. |

## `lib/src/services/glb_reader.dart`

The pure-Dart GLB reader. `GlbReader.parse(bytes, decoders:)` reads a binary glTF (`.glb`), or a `.lmas` JSON container that carries one as `raw_payload`, into `GlbMeshData`: the node hierarchy, world-space positions and indices per primitive, UVs, vertex colours, skinning, morph targets and animation clips. What pure Dart cannot decode comes from the caller through `GlbDecoders`:

- `draco` (`GlbDracoDecoder`): decodes a `KHR_draco_mesh_compression` primitive to a `GlbDracoMesh` (positions, UVs, indices). Without it such a primitive keeps only its accessor bounds.
- `image` (`GlbImageDecoder`): decodes a base colour texture to `GlbDecodedPixels` (`width`, `height`, `rgba`), which the reader samples into vertex colours. Without it the material's base colour factor is used.
- `prepare` (`GlbBytesTransform`): rewrites the bytes before reading. The editor passes its import sanitizer.

The engine provides the first two (`LuminaGlbLoader` in `lumina`, see [Utilities](../lumina/utilities.md)); the editor adds the third (`GlbParserService.parseGlb` in [lumina_editor_data](../lumina_editor_data/services.md)).


### `enum GlbNodeType`

`GlbNodeType`: Enumeration listing system options and state constants.

### `class GlbNode`

`GlbNode`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `index` | `int index` | Holds the `index` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `meshIndex` | `int? meshIndex` | Holds the `meshIndex` property or configuration state. |
| `meshName` | `String? meshName` | Holds the `meshName` property or configuration state. |
| `primitiveCount` | `int primitiveCount` | Holds the `primitiveCount` property or configuration state. |
| `children` | `List<GlbNode> children` | Holds the `children` property or configuration state. |
| `translation` | `List<double>? translation` | Holds the `translation` property or configuration state. |
| `rotation` | `List<double>? rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double>? scale` | Holds the `scale` property or configuration state. |
| `type` | `GlbNodeType type` | Holds the `type` property or configuration state. |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `isVisible` | `bool isVisible` | Holds the `isVisible` property or configuration state. |
| `totalDescendantCount` | `int get totalDescendantCount` | Getter accessor returning the current value of `totalDescendantCount`. |
| `directChildCount` | `int get directChildCount` | Getter accessor returning the current value of `directChildCount`. |
| `getAllDescendantNodeIndices` | `List<int> getAllDescendantNodeIndices()` | Queries and returns the `AllDescendantNodeIndices` value or child object. |
| `getAllDescendantPositions` | `List<double> getAllDescendantPositions()` | Queries and returns the `AllDescendantPositions` value or child object. |
| `getAllDescendantIndices` | `List<int> getAllDescendantIndices()` | Queries and returns the `AllDescendantIndices` value or child object. |

### `class GlbSubPrimitive`

`GlbSubPrimitive`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `vertexColors` | `Uint8List? vertexColors` | Holds the `vertexColors` property or configuration state. |
| `baseColor` | `List<double> baseColor` | Holds the `baseColor` property or configuration state. |
| `materialName` | `String? materialName` | Name of the glTF material the primitive uses (its material slot), or null when it has none. Set for Draco-compressed primitives too. |
| `materialIndex` | `int? materialIndex` | Index of the glTF material the primitive uses (its material slot), or null when it has none. Set for Draco-compressed primitives too. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |

### `class GlbMorphTarget`

`GlbMorphTarget`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `positionDeltas` | `List<double> positionDeltas` | Holds the `positionDeltas` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |

### `class GlbAnimationChannel`

`GlbAnimationChannel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `nodeIndex` | `int nodeIndex` | Holds the `nodeIndex` property or configuration state. |
| `nodeName` | `String nodeName` | Holds the `nodeName` property or configuration state. |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `keyframeTimes` | `List<double> keyframeTimes` | Holds the `keyframeTimes` property or configuration state. |
| `values` | `List<double> values` | Holds the `values` property or configuration state. |
| `interpolation` | `String interpolation` | Holds the `interpolation` property or configuration state. |

### `class GlbAnimationClip`

`GlbAnimationClip`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `animatedNodeIndices` | `animatedNodeIndices` | Holds the `animatedNodeIndices` property or configuration state. |
| `channelTargetPaths` | `channelTargetPaths` | Holds the `channelTargetPaths` property or configuration state. |
| `channels` | `List<GlbAnimationChannel> channels` | Holds the `channels` property or configuration state. |
| `compositeKeyframeTimes` | `List<double> compositeKeyframeTimes` | Holds the `compositeKeyframeTimes` property or configuration state. |

### `class GlbMeshData`

`GlbMeshData`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `subPrimitives` | `List<GlbSubPrimitive> subPrimitives` | Holds the `subPrimitives` property or configuration state. |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |
| `uvs` | `List<double> uvs` | Holds the `uvs` property or configuration state. |
| `minBounds` | `List<double> minBounds` | Holds the `minBounds` property or configuration state. |
| `maxBounds` | `List<double> maxBounds` | Holds the `maxBounds` property or configuration state. |
| `baseColor` | `List<double> baseColor` | Holds the `baseColor` property or configuration state. |
| `vertexColors` | `vertexColors` | Holds the `vertexColors` property or configuration state. |
| `rawPayload` | `Uint8List? rawPayload` | Holds the `rawPayload` property or configuration state. |
| `rootNodes` | `List<GlbNode> rootNodes` | Holds the `rootNodes` property or configuration state. |
| `allNodes` | `List<GlbNode> allNodes` | Holds the `allNodes` property or configuration state. |
| `materialNames` | `List<String> materialNames` | Holds the `materialNames` property or configuration state. |
| `skeletonJointIndices` | `Set<int> skeletonJointIndices` | Holds the `skeletonJointIndices` property or configuration state. |
| `morphTargets` | `List<GlbMorphTarget> morphTargets` | Holds the `morphTargets` property or configuration state. |
| `jointsPerVertex` | `Uint16List? jointsPerVertex` | Holds the `jointsPerVertex` property or configuration state. |
| `weightsPerVertex` | `Float32List? weightsPerVertex` | Holds the `weightsPerVertex` property or configuration state. |
| `maxInfluences` | `int maxInfluences` | Holds the `maxInfluences` property or configuration state. |
| `animations` | `List<GlbAnimationClip> animations` | Holds the `animations` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |
| `boneCount` | `int get boneCount` | Getter accessor returning the current value of `boneCount`. |
| `animatedNodeIndices` | `Set<int> get animatedNodeIndices` | Getter accessor returning the current value of `animatedNodeIndices`. |

---

[Previous: Services](services.md) | [Up: lumina_core (pure-Dart foundation)](index.md)
