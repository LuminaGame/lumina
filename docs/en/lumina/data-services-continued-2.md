[Türkçe](../../tr/lumina/data-services-continued-2.md)

# Data layer: use cases and services (continued, part 2)

Continuation of Data layer: use cases and services: the remaining public files under `lib/data/services/`. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/data/services/editor_build_service.dart`](#libdataserviceseditor_build_servicedart)
- [`lib/data/services/editor_host_generator_service.dart`](#libdataserviceseditor_host_generator_servicedart)
- [`lib/data/services/editor_source_vendor_service.dart`](#libdataserviceseditor_source_vendor_servicedart)
- [`lib/data/services/encoded_image_decoder.dart`](#libdataservicesencoded_image_decoderdart)
- [`lib/data/services/encoded_image_format.dart`](#libdataservicesencoded_image_formatdart)
- [`lib/data/services/engine_bootstrap.dart`](#libdataservicesengine_bootstrapdart)
- [`lib/data/services/engine_identity.dart`](#libdataservicesengine_identitydart)
- [`lib/data/services/fbx_import_service.dart`](#libdataservicesfbx_import_servicedart)
- [`lib/data/services/fbx_material_mapper.dart`](#libdataservicesfbx_material_mapperdart)
- [`lib/data/services/fbx_texture_locator.dart`](#libdataservicesfbx_texture_locatordart)
- [`lib/data/services/filament_thumbnail_renderer.dart`](#libdataservicesfilament_thumbnail_rendererdart)
- [`lib/data/services/generated_code_migration.dart`](#libdataservicesgenerated_code_migrationdart)

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
| `buildDirOf` | `String buildDirOf(String hostDir)` | Where `pub get` and `flutter build` run for [hostDir]: the host itself, or on Windows a junction to it under a space-free root. native_toolchain_c runs cl through cmd.exe, and `cl.exe` lives under "C:\Program Files", so one more quoted argument (an output dir under "…\Lumina Projects\…") breaks cmd's quoting ("'C:\Program' is not recognized"). The alias also keeps every path short. The files stay in the project. |
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
| `generate` | `Future<EditorHostResult> generate(String projectDir, List<LuminaPluginDescriptor> enabledCodePlugins, {String?...` |  |
| `isOldLayout` | `static bool isOldLayout(String hostDir)` | Whether the host at [hostDir] depends on `lumina_ui` anywhere but the project's copy beside it (a host from before per-project source copies). |

## `lib/data/services/editor_source_vendor_service.dart`

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

## `lib/data/services/encoded_image_format.dart`

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

## `lib/data/services/engine_bootstrap.dart`

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

## `lib/data/services/engine_identity.dart`

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

## `lib/data/services/fbx_material_mapper.dart`

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

## `lib/data/services/fbx_texture_locator.dart`

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
| `locateReference` | `File? locateReference(String uri)` | The file an FBX texture reference [uri] names: as written, relative to the FBX, then by file name (case-insensitive) in the [referenceDirs], then as an image in the [nearDirs] whose name ends in `_<file name>` (an exporter that prefixed the asset's name, e.g. Godot's `SM_Slot_Machine_T_Tread_Plate_Normal.png`). |
| `channelOf` | `static (FbxTextureChannel, int)? channelOf(String stem)` | The channel a file name (without extension) ends in, and how many of its tokens the suffix takes. |
| `coreName` | `static String coreName(String material)` | A material name without its asset-type prefix (`MI_`, `M_`, `Mat_`, `Material_`). |
| `matchByName` | `Map<int, Map<FbxTextureChannel, File>> matchByName(List<String> materials, {Set<String> exclude = const {}})` | The images of the [nearDirs] matched to [materials] by name: a file matches a material when its name holds the material's name (or its [coreName]) as whole tokens before a channel suffix — `T_Wood_BaseColor` for `M_Wood`, `SM_Slot_Machine_MI_Neon_Green_SM_Slot_Machine_Emissive` for `MI_Neon_Green`. A file goes to the material with the longest matching name (`MI_Plastic_Black_Matte_1_Normal` belongs to `MI_Plastic_Black_Matte_1`, not `MI_Plastic_Black`); files in [exclude] (already bound by reference) are skipped. Result: material index → channel → file (the first by path when several fit). |

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

## `lib/data/services/generated_code_migration.dart`

### `class LuminaGeneratedCodeMigration`

Brings a project's generated Dart written by earlier Lumina versions to the current naming rules ([dartTypeName], [dartFileName]).

Earlier generators named the files in `lib/levels/`, `lib/actors/`, `lib/anim/` and `lib/widgets/` after their assets (`L_Main.dart`, `BP_Door.dart`) and their classes `L_Main`, `BPDoor`, `WBPHud`. Today the files are snake_case (`l_main.dart`, `bp_door.dart`) and the classes UpperCamelCase (`LMain`, `BpDoor`, `WbpHud`). [migrate] renames the legacy files — keeping their contents, so `BEGIN USER CODE` regions survive — renames the classes they declare, and rewrites the imports and class references of every Dart file under `lib/`, so a project regenerates cleanly and still compiles in between. A legacy file whose snake_case file already exists is stale and is deleted.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `generatedFolders` | `static const List<String> generatedFolders` | The `lib/` folders whose files are named after assets. |
| `migrate` | `static Map<String, String> migrate(String projectDir)` | Migrates [projectDir]'s generated Dart; returns the renamed files, `lib/…` old path → new path (empty when there was nothing to migrate). |

---

[Previous: Data layer: use cases and services (continued, part 1)](data-services-continued.md) | [Up: lumina (engine core)](index.md) | [Next: Data layer: use cases and services (continued, part 3)](data-services-continued-3.md)
