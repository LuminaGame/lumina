[Türkçe](../../tr/lumina/data-services-continued-2.md)

# Data layer: use cases and services (continued, part 2)

Continuation of Data layer: use cases and services: the remaining public files under `lib/data/services/`. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/data/services/editor_build_service.dart`](#libdataserviceseditor_build_servicedart)
- [`lib/data/services/editor_host_generator_service.dart`](#libdataserviceseditor_host_generator_servicedart)
- [`lib/data/services/encoded_image_decoder.dart`](#libdataservicesencoded_image_decoderdart)
- [`lib/data/services/fbx_import_service.dart`](#libdataservicesfbx_import_servicedart)
- [`lib/data/services/filament_thumbnail_renderer.dart`](#libdataservicesfilament_thumbnail_rendererdart)

## `lib/data/services/editor_build_service.dart`

### `enum EditorBuildPhase`

The phases of a project editor build, with their share of the bar.

**Values:**

- `copyingSource`: The engine source into the project, once.
- `generatingHost`
- `resolvingPackages`
- `buildingNativeAssets`
- `compilingDart`
- `linking`
- `installing`

**Constructors:**

- `const EditorBuildPhase(this.weight, this.label)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `weight` | `final int weight` | Percent of the whole build (the weights sum to 100). |
| `label` | `final String label` |  |
| `overall` | `double overall(double inPhase)` | The overall fraction when this phase is [inPhase] done. |

### `class EditorBuildProgress`

**Constructors:**

- `const EditorBuildProgress(this.phase, this.fraction, this.message, {this.logLine})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `phase` | `final EditorBuildPhase phase` |  |
| `fraction` | `final double fraction` | Overall 0–1, monotonic non-decreasing over a build. |
| `message` | `final String message` |  |
| `logLine` | `final String? logLine` |  |

### `sealed class EditorBuildOutcome`

**Constructors:**

- `const EditorBuildOutcome()`

### `class EditorBuildSucceeded`

**Constructors:**

- `const EditorBuildSucceeded(this.entry, this.logPath, this.elapsed)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entry` | `final EditorBuildEntry entry` |  |
| `logPath` | `final String? logPath` |  |
| `elapsed` | `final Duration elapsed` | The whole build, from generation to install (zero on a cache hit). |

### `class EditorBuildFailed`

**Constructors:**

- `const EditorBuildFailed(this.message, this.lastLines, this.logPath)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `lastLines` | `final List<String> lastLines` | The last [EditorBuildService.failureTailLines] lines of the log. |
| `logPath` | `final String? logPath` |  |

### `class EditorBuildCancelled`

**Constructors:**

- `const EditorBuildCancelled(this.logPath)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `logPath` | `final String? logPath` |  |

### `typedef EditorBuildProcessStarter`

Starts a child process; the same shape as the cook step's starter, so a test replays recorded output through it.

### `class EditorBuildJob`

One running build. [progress] is a broadcast stream; [result] completes once, with the outcome.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `progress` | `final Stream<EditorBuildProgress> progress` |  |
| `result` | `final Future<EditorBuildOutcome> result` |  |
| `cancel` | `void cancel()` |  |
| `logPath` | `String? get logPath` | `<cache>/<hash>.log`, once the hash is known (after `pub get`). |

### `class EditorBuildProgressParser`

Maps `flutter build <platform> -v` output to phases and in-phase fractions. Only counts the output carries move the bar: - native assets: completed build hooks (`output.json contents:` after a hook's "Running (cd package…" line) against [hookPackages]; - compiling: the flutter_assemble targets the tool reports complete (kernel snapshot, AOT snapshot, bundle assets); - linking: MSBuild's finished projects against the [linkTargets] of the generated solution, or CMake/ninja's `[n/m]` steps. A line without a count leaves the bar where it is.

The tool runs the hooks and the kernel compile in parallel; the bar stays in the native-assets phase until the last hook is done (a compile milestone seen meanwhile is applied when the phase is entered).

**Constructors:**

- `EditorBuildProgressParser({required this.hookPackages, this.linkTargets})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `hookPackages` | `final int hookPackages` | How many packages in the host's package graph have a `hook/build.dart`. |
| `linkTargets` | `final int Function()? linkTargets` | How many projects MSBuild builds (the top-level `.sln`'s projects), read when linking starts; null or 0 when unknown (non-Windows). |
| `phase` | `EditorBuildPhase phase` |  |
| `inPhase` | `double inPhase` |  |
| `message` | `String message` |  |
| `feed` | `bool feed(String line)` | Feeds one line; returns true when the phase or fraction moved. |
| `overall` | `double get overall` |  |
| `msBuildProjects` | `static int msBuildProjects(String buildDir)` | Projects in the generated Visual Studio solution of [hostDir]'s build. |

### `class EditorBuildService`

Generates, resolves, builds and installs a project editor: **generate → pub get → flutter build → install**, as a stream of [EditorBuildProgress] and one [EditorBuildOutcome]. The full log goes to `<cache>/<hash>.log`.

**Constructors:**

- `EditorBuildService({required this.engineRoot, EditorBuildCache? cache, EditorHostGeneratorService? generator, EditorSourceVendorService? vendor, String? flutter...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` |  |
| `cache` | `final EditorBuildCache cache` |  |
| `generator` | `final EditorHostGeneratorService generator` |  |
| `vendor` | `final EditorSourceVendorService vendor` | Copies the engine source into the project before the first build. |
| `flutterExecutable` | `final String flutterExecutable` |  |
| `flutterInfo` | `final Future<FlutterToolInfo> Function() flutterInfo` |  |
| `mode` | `final String mode` | `release` (default) or `debug`. |
| `platform` | `final String platform` | `windows`, `linux` or `macos`. |
| `environment` | `final Map<String, String>? environment` | Extra environment for the child processes (the smoke run redirects the caches with it). |
| `cleanHostAfterInstall` | `final bool cleanHostAfterInstall` | Whether to delete the host's `.dart_tool/` and `build/` after install (only the bundle is cached). |
| `hostAliasRoot` | `final Directory? hostAliasRoot` | Windows: where the space-free build aliases of project hosts live Defaults to `%LOCALAPPDATA%\lumina\hosts`. |
| `failureTailLines` | `static const int failureTailLines` |  |
| `buildDirOf` | `String buildDirOf(String hostDir)` | Where `pub get` and `flutter build` run for [hostDir]: the host itself, or on Windows a junction to it under a space-free root (see [SpaceFreeBuildDir]). The files stay in the project. |
| `bundleDirOf` | `String bundleDirOf(String hostDir)` | `build/<platform>/…` holding the runnable bundle, relative to the host. |
| `executableIn` | `String executableIn(String packageName)` | The executable inside the bundle. |
| `countHookPackages` | `static int countHookPackages(String hostDir)` | Packages in the host's package graph that have a `hook/build.dart` (from `.dart_tool/package_config.json`). |
| `start` | `EditorBuildJob start(String projectDir, List<LuminaPluginDescriptor> plugins, {String? projectName, bool syncSource = false, FutureOr<void> Function()? onSourceSynced})` | Builds the project editor of [projectDir]. [syncSource] replaces the project's copy of the engine source first, even when one is there (the update to the running engine; the copy phase reads "Updating editor source"), and [onSourceSynced] runs once the new copy is in place. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaultEditorBuildProcessStarter` | `Future<Process> defaultEditorBuildProcessStarter(String executable, List<String> arguments, {String? workingDi...` |  |
| `killProcessTree` | `Future<void> killProcessTree(int pid) async` | Kills [pid] and its children (`flutter` is a script that runs the tool, which runs MSBuild/CMake/ninja and the hooks). |

## `lib/data/services/editor_host_generator_service.dart`

### `enum EditorHostStatus`

What [EditorHostGeneratorService.generate] did.

**Values:**

- `generated`: `<project>/.lumina/editor/` holds the project's editor host.

### `class EditorHostResult`

**Constructors:**

- `factory EditorHostResult.generated(Directory hostDir, String packageName, {required bool changed})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `status` | `final EditorHostStatus status` |  |
| `hostDir` | `final Directory? hostDir` | `<project>/.lumina/editor`, when [status] is [EditorHostStatus.generated]. |
| `packageName` | `final String? packageName` | The host package's name (`<project_snake>_editor`), also its binary name. |
| `changed` | `final bool changed` | Whether any generated file differed from what was on disk. |

### `class EditorHostGeneratorService`

Writes a project's editor host package: a thin Flutter app in `<project>/.lumina/editor/` that depends on `lumina_ui` as a library plus the project's code plugins, and holds its own registrar and platform runner. Every engine package it depends on is the project's own copy beside it (`lumina_ui/`, `lumina/`, …, made by `EditorSourceVendorService`), referenced by relative paths. The engine checkout is never modified.

Output is deterministic (the same inputs give byte-identical files) and written in place: a regeneration that changes nothing leaves the folder — the source copy, `.dart_tool`, `pubspec.lock` and build stamp — untouched.

The host's `pubspec.lock` is seeded with every hosted package of the engine lock ([engineLockOf]: the project copy's snapshot, else the engine workspace's `pubspec.lock`), so `pub get` keeps the versions the engine was built with instead of the newest ones pub.dev published since. Packages only the host has (a code plugin's own dependencies) keep their entries and new ones resolve normally; path and git packages are pinned by the pubspec itself. The lock is rewritten when the host has none, when its pubspec changed, or when it holds an engine package at another version.

**Constructors:**

- `EditorHostGeneratorService({required this.engineRoot, String? platform, String? workspaceRoot})` — `workspaceRoot` (default `engineRoot`) is the workspace whose `pubspec.lock` pinned the git-resolved plugins: such a plugin is written into the host pubspec as that git dependency, never as a path into the pub cache.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` | The workspace root holding `lumina_ui/`, `lumina/`, `flutter_filament/`, …. |
| `platform` | `final String platform` | The host OS whose runner folder is copied (`linux`, `windows`, `macos`). |
| `stampFileName` | `static const String stampFileName` | The stamp file the build service writes into the host after a build. |
| `hostDirOf` | `static String hostDirOf(String projectDir)` |  |
| `packageNameFor` | `static String packageNameFor(String projectName)` | `MyGame` → `my_game_editor`, always a valid Dart package name. |
| `editorCodePlugins` | `static List<LuminaPluginDescriptor> editorCodePlugins(List<LuminaPluginDescriptor> plugins)` | The plugins that contribute editor code (the ones a host must compile). |
| `projectNameIn` | `static String? projectNameIn(String projectDir)` | The project's name: the `.lmproject` file's base name. |
| `generate` | `Future<EditorHostResult> generate(String projectDir, List<LuminaPluginDescriptor> enabledCodePlugins, {String?...` || Writes `pubspec.yaml`, `lib/plugin_registrar.dart` (`PluginHostPatcherService.registrarSource`) and `lib/main.dart`, whose `main` calls `runLuminaEditor(args, plugins: kEnabledPlugins, processes: kPluginProcesses, host: EditorHostInfo(...))`, plus the renamed runner. |
| `engineLockOf` | `File engineLockOf(String hostDir)` | The lock the host's hosted packages are pinned to: the copy's `EditorSourceVendorService.engineLockFileName`, else `<workspaceRoot>/pubspec.lock`. |
| `movedFromEngineLock` | `List<String> movedFromEngineLock(String hostDir)` | Engine-locked hosted packages the host's lock holds at another version (a code plugin's constraint moved them), as `name <engine> → <host>`; the build log warns about each. |
| `isOldLayout` | `static bool isOldLayout(String hostDir)` | Whether the host at [hostDir] depends on `lumina_ui` anywhere but the project's copy beside it (a host from before per-project source copies). |

## `lib/data/services/encoded_image_decoder.dart`

### `class DecodedRgbaImage`

Decoded pixels: `width * height` RGBA8 texels, row-major, alpha premultiplied (what `dart:ui`'s `ImageByteFormat.rawRgba` hands back).

**Constructors:**

- `const DecodedRgbaImage(this.width, this.height, this.rgba)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `width` | `final int width` |  |
| `height` | `final int height` |  |
| `rgba` | `final Uint8List rgba` |  |

### `abstract final class EncodedImageDecoder`

Decodes an encoded image with the decoder for its [EncodedImageFormat], the same way on every isolate.

`dart:ui`'s image codec only exists on a root isolate (the editor's UI isolate, a test's main isolate, the web's only isolate). There it decodes PNG, JPEG, WebP, GIF and BMP; on any other isolate — an `Isolate.run` worker, a save or streaming worker — `package:image` decodes the same formats. TGA always goes through [TgaDecoderService]. KTX2 (Basis) and unrecognised bytes are not decoded to pixels here.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `platformCodecAvailable` | `static bool get platformCodecAvailable` | Whether this isolate can use `dart:ui`'s image codec. |
| `platformCodecProxy` | `static Future<DecodedRgbaImage> Function(Uint8List bytes)? platformCodecProxy` | Decodes with the UI isolate's platform codec on behalf of an isolate that has none: the import worker sets this to a round trip to the UI isolate, so what it decodes — the texels a mesh thumbnail samples — matches a UI-isolate decode bit for bit (JPEG decoders disagree in the last bits). Used only where [platformCodecAvailable] is false. |
| `decodeRgba` | `static Future<DecodedRgbaImage?> decodeRgba(Uint8List bytes) async` | [bytes] decoded to premultiplied RGBA8, or `null` when its format is not one this decoder turns into pixels (KTX2, unknown). Throws a [FormatException] for bytes that carry a recognised signature but do not decode. |

## `lib/data/services/fbx_import_service.dart`

### `class FbxImportException`

Thrown when an FBX file cannot be turned into a GLB.

**Constructors:**

- `const FbxImportException(this.message)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `message` | `final String message` |  |

### `class FbxImportResult`

An FBX file converted for the import pipeline.

**Constructors:**

- `const FbxImportResult({required this.glb, required this.report, required this.clipNames, required this.collisionHulls,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `glb` | `final Uint8List glb` | Standard glTF: metres, +Y up, one animation per FBX take (named), node transforms as TRS, `UCX_`-style collision hulls removed. |
| `report` | `final Map<String, dynamic> report` | The bridge report without the hull points and triangles (see `AssimpImportConversion.report`). |
| `clipNames` | `final List<String> clipNames` | One name per take, in animation order. |
| `collisionHulls` | `final List<Map<String, dynamic>> collisionHulls` | The removed collision hulls: name, shape (convex/box/sphere/ capsule), vertex_count, face_count, min/max, points (x, y, z flattened; metres, Y up, in the asset's space) and triangles (indices into the points, 3 per face). `MeshCollisionService` turns them into collision. |
| `missingTextureDetails` | `List<Map<String, dynamic>> get missingTextureDetails` | Each texture the FBX referenced but that was found nowhere (see [FbxImportService.missingTextureDetailsKey]): `material` (the FBX material name), `slot`, `path` (as the FBX wrote it), `file`. |
| `materialTextures` | `List<Map<String, dynamic>> get materialTextures` | Each texture bound to a material (see [FbxImportService.materialTexturesKey]). |
| `toAssetMetadata` | `Map<String, String> toAssetMetadata({String? assetBaseName})` | What the import records on the emitted asset: the source format, how it was normalized, the takes and (when the source had any) the hulls. [assetBaseName] (the mesh asset's name) turns the FBX material names of the texture lists into the material assets' names. |

### `abstract final class FbxImportService`

FBX → GLB for the import pipeline.

flutter_assimp's bridge does the heavy lifting natively: it bakes the FBX unit scale and axis system into the scene (Unreal exports are centimetres, Z up) and strips `UCX_`/`UBX_`/`USP_`/`UCP_` collision hulls. What remains is fixing what Assimp's glTF exporter writes:

- one unnamed animation **per channel** (per bone); they are merged back into one animation per FBX take, named after the file (single take) or `<file>_<take>`; - samplers carry their interpolation under `path`; rewritten as `interpolation`; - node transforms as `matrix`; rewritten as TRS, which animated nodes must use (glTF 2.0 ) and the CPU mesh parser reads.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isFbx` | `static bool isFbx(String path)` |  |
| `convert` | `static Future<FbxImportResult> convert(String fbxPath, {List<String> textureSearchDirs = const []})` | [convertSync] in a background isolate (Assimp takes seconds on a skeletal mesh; the editor's UI thread must not wait on it). |
| `convertSync` | `static FbxImportResult convertSync(String fbxPath, {List<String> textureSearchDirs = const []})` | [textureSearchDirs] are searched first for the FBX's textures (the Import dialog's "Textures Folder"). |
| `applyMaterialDetails` | `static Uint8List applyMaterialDetails(Uint8List glb, List<Map> details)` | [FbxMaterialMapper.applyToGltf] on a GLB. |
| `missingTextureDetailsKey` | `static const String missingTextureDetailsKey` | Each referenced texture that was found nowhere: `material` (FBX name), `slot` (`normalMap`, …), `path` (as the FBX wrote it), `file` (its file name). The import names each in the Output Log. |
| `materialTexturesKey` | `static const String materialTexturesKey` | Each texture bound to a material: `material` (FBX name), `slot`, `file` (the file found), `texture` (the image's name, which the texture asset is named after) and `source` (`referenced`, `embedded` or `matched by name`). |
| `textureSlots` | `static Iterable<(String, Map)> textureSlots(Map material) sync*` | glTF texture slots of a material, as the `.lmas` sampler names. |
| `attachMatchedTextures` | `static ({Uint8List glb, List<String> embedded, List<Map<String, dynamic>> bound}) attachMatchedTextures(Uint8L...` | Gives the materials of [glb] the images of the locator's near folders that match them by name ([FbxTextureLocator.matchByName]) in the channels no referenced texture fills: an FBX that names no texture (an Unreal export of a material with constants and textures carries only the constants) still gets the textures its author dropped next to it. Each becomes an embedded image named `T_<material core>_<channel>`. |
| `embeddedTexturesKey` | `static const String embeddedTexturesKey` | Textures the FBX referenced that were found and embedded (file names). |
| `missingTexturesKey` | `static const String missingTexturesKey` | Textures the FBX referenced that exist nowhere near it (the exporter's absolute paths, e.g. `W:/Cafe/.../T_Leather_Normal.png`). |
| `clipNamesFor` | `static List<String> clipNamesFor(String baseName, List<String> takeNames)` | Clip names for [takeNames]: a single take is named after the file (an Unreal export calls every take "Unreal Take"); several are `<file>_<take>`, made unique. |
| `postProcess` | `static Uint8List postProcess(Uint8List glb, {required List<({String name, int channels})> takes, String? gener...` | Rewrites the exporter's GLB (see the class doc). [takes] lists each take's clip name and channel count in export order; when their channel counts do not add up to the animations present, everything is merged into one clip named after the first take. |
| `resolveExternalImages` | `static ({Uint8List glb, List<String> embedded, List<String> missing, List<Map<String, dynamic>> missingDetails...` | Makes every image of [glb] self-contained. An FBX names its textures by the path they had on the author's machine; Assimp's exporter keeps that as the image `uri`. Each one is looked up by [locator] (default: one for [sourceDir]; see [FbxTextureLocator.locateReference]). Found images are embedded (TGA re-encoded as PNG) under the name the FBX gave the file; the rest are removed together with the textures and material slots that sampled them, so the import never writes a texture asset without an image, and are listed per material in `missingDetails`. |
| `decomposeMatrix` | `static ({List<double> translation, List<double> rotation, List<double> scale}) decomposeMatrix(List<double> m)` | Column-major 4×4 → translation, unit quaternion (x, y, z, w) and scale. A mirrored basis (negative determinant) is carried by a negative X scale. |

## `lib/data/services/filament_thumbnail_renderer.dart`

### `class ThumbnailMeshPart`

One glTF binary placed in a thumbnail scene.

[transform] is the placement in world space (Y up, centimetres). [unitScale] converts the glTF's own units into world units: imported glTF is metres and is drawn ×[LuminaUnits.unitsPerMetre], exactly as `LuminaStaticMeshComponent.assetUnitScale` draws it in a level; geometry generated in world units (primitives) uses 1.

**Constructors:**

- `ThumbnailMeshPart(this.glb, {Matrix4? transform, this.unitScale = LuminaUnits.unitsPerMetre, this.pose})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `glb` | `final Uint8List glb` |  |
| `transform` | `final Matrix4 transform` |  |
| `unitScale` | `final double unitScale` |  |
| `pose` | `final ThumbnailPose? pose` | The animation pose to draw a skinned mesh in; its rest pose when null. |

### `class ThumbnailPose`

A frame of an animation clip stored in a mesh's GLB: the clip named [clip] (else the one at [clipIndex]), at [fraction] of its length — an animation sequence's thumbnail is its mesh at the middle of the clip.

**Constructors:**

- `const ThumbnailPose({this.clip, this.clipIndex, this.fraction = 0.5})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `clip` | `final String? clip` |  |
| `clipIndex` | `final int? clipIndex` |  |
| `fraction` | `final double fraction` |  |
| `indexIn` | `int? indexIn(List<String> names)` | The gltfio animation index this pose names in [names], or null. |

### `class FilamentThumbnailRenderer`

Renders asset thumbnails offscreen with Filament.

It draws on the process's shared engine (flutter_filament `FilamentEngineHost`), leased on first use and released by [dispose], with its own headless swap chain, renderer, view and scene: the editor's viewports and the thumbnail queue are one Vulkan device, not one each. The engine is on the GPU every engine in the process uses (`FilamentEngine.defaultGpuPreference`, which the editor sets from its Graphics Device setting, then `FILAMENT_GPU`).

Every render is lit by the same studio rig (a sun, image-based lighting and a neutral backdrop) and framed from a three-quarter view onto the bounds of what was drawn, with the near and far planes taken from those bounds, so a 3 cm bolt and a 30 m level both fill the frame. The frame is rendered at [supersample]× and averaged down to [size]² before it is encoded.

Renders are serialized: callers may overlap, the engine never does.

**Constructors:**

- `FilamentThumbnailRenderer({super.size, super.supersample, super.sunIntensity, super.iblIntensity, super.backdrop, super.iblKtx,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shared` | `static FilamentThumbnailRenderer get shared` | The process-wide renderer the editor's thumbnail queue uses. |
| `isAvailable` | `bool get isAvailable` | False once the engine could not be created (no GPU, no driver); every render then returns null and callers keep their fallback. |
| `environmentIbl` | `set environmentIbl(Uint8List? ktx)` | Sets the image-based light (a KTX1 cubemap, e.g. Filament's `default_env_ibl.ktx`). Without one the rig uses a neutral spherical-harmonics ambient. |
| `environmentIbl` | `Uint8List? get environmentIbl` |  |
| `renderMesh` | `Future<Uint8List?> renderMesh(Uint8List glb)` | A static or skeletal mesh (GLB / glTF bytes, metres), drawn ×100 like a level draws it. Null when nothing could be loaded or rendered. |
| `renderMeshParts` | `Future<Uint8List?> renderMeshParts(List<ThumbnailMeshPart> parts, {double pitchDegrees = 22})` | Several meshes in one frame (a Blueprint's mesh components, a level). |
| `renderMaterial` | `Future<Uint8List?> renderMaterial(LuminaAsset material, {String? projectRoot})` | A material on a preview sphere: its compiled package when it has one, else compiled from its whole `.mat` source by Filament's own material compiler (`FilamentMatc`: every header key, `vertex` and `fragment` blocks); when neither yields a package the sphere gets a default lit material in the material's base colour (the Material Editor's fallback). Texture references resolve against [projectRoot]. |
| `renderLevel` | `Future<Uint8List?> renderLevel(List<Map<String, dynamic>> actors, {String? projectRoot}) async` | A level from its stored actors (`metadata.actors`: centimetres, Z up): its primitives and meshes, framed from above on the bounds of the level. Mesh paths resolve against [projectRoot]. |
| `levelParts` | `static Future<List<ThumbnailMeshPart>> levelParts(List<Map<String, dynamic>> actors, {String? projectRoot}) as...` | The drawable pieces of a level: primitives (built in world units) and mesh actors (glTF metres), each placed by its stored transform converted from Z up to the runtime's Y up. |
| `authoringTransform` | `static Matrix4 authoringTransform(dynamic location, dynamic rotation, dynamic scale)` | A stored (Z up, cm, degrees) transform as a runtime (Y up) matrix, the conversion the level code generator emits ([LuminaAxes]). |
| `resolveProjectPath` | `static String? resolveProjectPath(String path, String? projectRoot)` | [path] as an openable file: absolute and existing paths as they are, project-relative ones (`contents/…`) under [projectRoot]. |
| `loadMeshGlb` | `static Future<Uint8List?> loadMeshGlb(String path) async` | The GLB a mesh file draws: a `.glb`/`.gltf` as it is, a `.lmas`'s embedded payload or its `.entity.glb` companion. Run through the import sanitizer (TGA → PNG, texture budget, four skin influences) so gltfio can load it; already-sanitized files pass straight through. |
| `dispose` | `void dispose()` | Releases the engine and everything on it. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] is a compiled `.filamat` package: a `MAT_VERS` chunk of size 4. Filament aborts the process on anything else. |
| `materialParameterValues` | `static Map<String, Object?> materialParameterValues(LuminaAsset material)` | The values a material instance starts with: the `.mat` header's `default :` entries, overridden by what the Material Editor saved in `metadata.parameter_defaults`. |

---

[Previous: Data layer: use cases and services (continued, part 1)](data-services-continued.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: use cases and services (continued, part 3)](data-services-continued-3.md)
