[Türkçe](../../../tr/lumina_ui/sub-editors/build-manager.md)

# Build manager

The Build Manager: material precompile, navigation bake, thumbnail regeneration and asset validation steps, and Cook & Package, which regenerates the game's Dart code and runs a real `flutter build`. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/build_manager_sub_editor.dart`](#libuifeaturessub_editorsviewsbuild_manager_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/build_manager_view_model.dart`](#libuifeaturessub_editorsview_modelsbuild_manager_view_modeldart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicedart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/cook_and_package_steps.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicecook_and_package_stepsdart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/host_build_targets.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicehost_build_targetsdart)

## `lib/ui/features/sub_editors/views/build_manager_sub_editor.dart`

### `class BuildManagerSubEditor`

Build Manager (honestly scoped): the four real build steps (material precompile, navigation bake, thumbnail regeneration, asset validation) plus Cook & Package through a real `flutter build`.  Left: step checklist with live status badges + durations. Center: the pipeline's log console and the validation issue table. Right: target / configuration / extra flags / artifact path. Bottom: global progress, stage, elapsed time, Cancel. Nothing here is fabricated — every number and line comes from a [BuildEvent].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `projectDirPath` | `String? projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `initialProject` | `LuminaProject? initialProject` | Holds the `initialProject` property or configuration state. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | Holds the `editorViewModel` property or configuration state. |
| `viewModel` | `BuildManagerViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<BuildManagerSubEditor> createState() => _BuildManagerSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _BuildManagerSubEditorState`

`_BuildManagerSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModelForTest` | `BuildManagerViewModel get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/build_manager_view_model.dart`

### `class BuildStepState`

Per-step UI state derived from real pipeline events.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | Holds the `status` property or configuration state. |
| `duration` | `Duration? duration` | Holds the `duration` property or configuration state. |
| `progressLabel` | `String? progressLabel` | Holds the `progressLabel` property or configuration state. |
| `message` | `String? message` | Holds the `message` property or configuration state. |

### `class BuildLogLine`

One console line; timestamps are the event's real wall-clock time.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `at` | `DateTime at` | Holds the `at` property or configuration state. |
| `level` | `String level` | Holds the `level` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `timestamp` | `String get timestamp` | Getter accessor returning the current value of `timestamp`. |

### `class BuildManagerViewModel`

Build Manager state: step selection, target/config, one pipeline at a time, per-step status + durations, the live log and validation issues. Every line shown originates from a [BuildEvent]; logs are also forwarded to [EngineLoggerService] so the main Output Log sees builds.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectDirPath` | `String projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `flutterExecutable` | `String flutterExecutable` | Holds the `flutterExecutable` property or configuration state. |
| `project` | `LuminaProject? get project` | Getter accessor returning the current value of `project`. |
| `isStepEnabled` | `bool isStepEnabled(BuildStepKind kind)` | Checks current state or capability and returns a boolean value. |
| `stepState` | `BuildStepState stepState(BuildStepKind kind)` | Executes `stepState` operation. |
| `logLines` | `List<BuildLogLine> get logLines` | Getter accessor returning the current value of `logLines`. |
| `issues` | `List<ValidationIssue> get issues` | Checks current state or capability and returns a boolean value. |
| `hostTargets` | `HostBuildTargets? get hostTargets` | Getter accessor returning the current value of `hostTargets`. |
| `isProbing` | `bool get isProbing` | Checks current state or capability and returns a boolean value. |
| `flutterAvailable` | `bool get flutterAvailable` | Getter accessor returning the current value of `flutterAvailable`. |
| `flutterVersion` | `String? get flutterVersion` | Getter accessor returning the current value of `flutterVersion`. |
| `availableTargets` | `List<String> get availableTargets` | Getter accessor returning the current value of `availableTargets`. |
| `target` | `String? get target` | Getter accessor returning the current value of `target`. |
| `configuration` | `BuildConfiguration get configuration` | Getter accessor returning the current value of `configuration`. |
| `extraFlags` | `String get extraFlags` | Getter accessor returning the current value of `extraFlags`. |
| `isRunning` | `bool get isRunning` | Checks current state or capability and returns a boolean value. |
| `currentStep` | `BuildStepKind? get currentStep` | Getter accessor returning the current value of `currentStep`. |
| `currentStage` | `String get currentStage` | Getter accessor returning the current value of `currentStage`. |
| `completedSteps` | `int get completedSteps` | Getter accessor returning the current value of `completedSteps`. |
| `totalSteps` | `int get totalSteps` | Getter accessor returning the current value of `totalSteps`. |
| `elapsed` | `Duration get elapsed` | Getter accessor returning the current value of `elapsed`. |
| `artifactPath` | `String? get artifactPath` | Getter accessor returning the current value of `artifactPath`. |
| `lastPipelineStatus` | `BuildStepStatus? get lastPipelineStatus` | Getter accessor returning the current value of `lastPipelineStatus`. |
| `globalProgress` | `double? get globalProgress` | Global progress 0..1, or null while the cook (unmeasurable) runs. |
| `cookArguments` | `List<String> get cookArguments` | The literal argv Cook will spawn (`flutter` + these). |
| `expectedArtifactPath` | `String? get expectedArtifactPath` | Getter accessor returning the current value of `expectedArtifactPath`. |
| `cookDisabledReason` | `String? get cookDisabledReason` | Getter accessor returning the current value of `cookDisabledReason`. |
| `cookEnabled` | `bool get cookEnabled` | Getter accessor returning the current value of `cookEnabled`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `init` | `Future<void> init()` | Probes the host toolchain once (skipped when targets were injected). |
| `setStepEnabled` | `void setStepEnabled(BuildStepKind kind, bool enabled)` | Updates the `StepEnabled` parameter and applies changes to the system. |
| `setTarget` | `void setTarget(String? target)` | Updates the `Target` parameter and applies changes to the system. |
| `setConfiguration` | `void setConfiguration(BuildConfiguration configuration)` | Updates the `Configuration` parameter and applies changes to the system. |
| `setExtraFlags` | `void setExtraFlags(String flags)` | Updates the `ExtraFlags` parameter and applies changes to the system. |
| `clearLog` | `void clearLog()` | Clears all elements from the collection or buffer. |
| `logText` | `String get logText` | Getter accessor returning the current value of `logText`. |
| `buildAll` | `Future<BuildStepStatus?> buildAll() => _run(BuildPlan(steps: _assetSteps...` | Runs the checked steps in the fixed order. |
| `cookAndPackage` | `Future<BuildStepStatus?> cookAndPackage()` | Runs the checked steps, then the real `flutter build <target>`. |
| `cancel` | `void cancel()` | Executes `cancel` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/services/build_pipeline_service.dart`

**Top-level Functions:**

- **`MatcResult buildPackageFromSource(String name, String source, {String? includeDirectory})`**: Compiles the whole `.mat` [source] with the material compiler (every header key, `vertex` and `fragment` blocks, `#include`s from [includeDirectory]), as the Material Editor does.
- **`Future<MaterialCompileOutcome> call(MaterialCompileInput input)`**: Executes `call` operation.
- **`void dispose()`**: Releases native FFI pointers, event subscriptions, and allocated memory.
- **`BuildStepKind kind`**: Executes `kind` operation.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: Executes the command or action logic.
- **`BuildStepStatus status`**: Executes `status` operation.
- **`String message`**: Executes `message` operation.
- **`NavBuildOutcome(this.status, this.message)`**: Executes `NavBuildOutcome` operation.
- **`BuildStepKind kind`**: Executes `kind` operation.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: Executes the command or action logic.
- **`Future<NavBuildOutcome> levelFileNavigationBuilder(BuildStepContext ctx)`**: Reads `NavMeshBoundsVolume` actors (and the level's `navigation` section) from the active level `.lmas`, then runs the engine's real grid bake ([LuminaNavigationSystem.buildFromWorld]) on a headless world.
- **`BuildStepKind kind`**: Executes `kind` operation.
- **`bool isStale(File lmas, LuminaAsset asset)`**: Stale when the asset has no thumbnail, or the payload (`.lmas` mtime) is newer than the cached thumbnail timestamp (or there is no timestamp).
- **`Future<StepResult> execute(BuildStepContext ctx)`**: Executes the command or action logic.
- **`BuildStepKind kind`**: Executes `kind` operation.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: Executes the command or action logic.
- **`bool ok`**: Result of the pre-spawn code-generation pass.
- **`String message`**: Executes `message` operation.
- **`List<String> writtenFiles`**: Executes `writtenFiles` operation.
- **`String target`**: Regenerates the game's Dart code; the default reads the active level from disk, the editor injects its own save-and-generate path.
- **`BuildConfiguration configuration`**: Executes `configuration` operation.
- **`String extraFlags`**: Executes `extraFlags` operation.
- **`String flutterExecutable`**: Executes `flutterExecutable` operation.
- **`BuildStepKind kind`**: Executes `kind` operation.
- **`String artifactPathFor(String projectDir, String target, BuildConfiguration configuration)`**: Where `flutter build <target>` leaves its output for [configuration].
- **`List<String> buildArguments()`**: The argv the step spawns: `flutter build <target> <flag> [extra…]`.
- **`List<String> shellSplit(String input)`**: Splits a flags string the way a POSIX shell would (quotes and backslash escapes honoured, no expansion).
- **`Future<CookCodeGenOutcome> levelFileCodeGenerator(BuildStepContext ctx)`**: Default code-gen: reads the active level's actors + environment from its `.lmas` and runs [GenerateDartCodeUseCase] (fresh `lib/main.dart` + `lib/levels/<L>.dart`, dirty flag cleared, timestamp stamped).
- **`Future<StepResult> execute(BuildStepContext ctx)`**: Executes the command or action logic.
- **`String text`**: Executes `text` operation.
- **`bool replaceLast`**: Executes `replaceLast` operation.
- **`Stream<_SplitLine> bind(Stream<String> stream)`**: Executes `bind` operation.
- **`bool flutterAvailable`**: Platforms the host can actually `flutter build`, learned from a real `flutter doctor -v` run — never a hardcoded platform list.
- **`String? flutterVersion`**: Executes `flutterVersion` operation.
- **`List<String> targets`**: Executes `targets` operation.
- **`String? error`**: Executes `error` operation.
- **`String rawDoctor`**: Executes `rawDoctor` operation.
- **`String labelFor(String target) => switch (target)`**: Executes `labelFor` operation.

### `enum BuildStepKind`

Build Manager pipeline: real build steps over the open project — material precompile, navigation grid bake, thumbnail regeneration, asset validation — and Cook & Package, which regenerates the game's Dart code and drives a real `flutter build <target>` child process with streamed output. Every event in the stream originates from actual work; there are no fabricated counters.  The steps in their fixed documented execution order.

**Constructors:**
- `BuildStepKind(this.label)`: Initializes `BuildStepKind(this.label)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cookAndPackage` | `cookAndPackage('Cook & Package')` | Executes `cookAndPackage` operation. |
| `label` | `String label` | Holds the `label` property or configuration state. |

### `enum BuildStepStatus`

`BuildStepStatus`: Enumeration listing system options and state constants.

### `enum BuildConfiguration`

Build configuration names mapped to the literal `flutter build` flag.

**Constructors:**
- `BuildConfiguration(this.label, this.flag, this.modeDir)`: Initializes `BuildConfiguration(this.label, this.flag, this.modeDir)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shipping` | `shipping('Shipping', '--release', 'release')` | Executes `shipping` operation. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `flag` | `String flag` | The flag passed verbatim to `flutter build`. |
| `modeDir` | `String modeDir` | Flutter's output-directory name for the mode. |

### `class BuildCancellationToken`

Cooperative cancellation shared by the pipeline and the running step.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isCancelled` | `bool get isCancelled` | Checks current state or capability and returns a boolean value. |
| `cancel` | `void cancel()` | Executes `cancel` operation. |
| `onCancel` | `void onCancel(void Function() fn)` | Registers [fn] to run when the token fires (immediately if already fired). |
| `removeListener` | `void removeListener(void Function() fn) => _listeners.remove(fn)` | Releases and safely disposes the specified `Listener` resource. |

### `class BuildEvent`

`BuildEvent`: `class` representing the data model or functionality of the module.

### `class BuildStepStarted`

`BuildStepStarted`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BuildStepStarted(this.kind)`: Initializes `BuildStepStarted(this.kind)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | Holds the `kind` property or configuration state. |

### `class BuildStepProgress`

Measurable progress inside a step (materials compiled, thumbnails rendered…).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | Holds the `kind` property or configuration state. |
| `completed` | `int completed` | Holds the `completed` property or configuration state. |
| `total` | `int total` | Holds the `total` property or configuration state. |
| `failed` | `int failed` | Holds the `failed` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |

### `class BuildLogEvent`

`BuildLogEvent`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind? kind` | Holds the `kind` property or configuration state. |
| `level` | `String level` | Holds the `level` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |
| `replaceLast` | `bool replaceLast` | True when this line replaces the previous one (carriage-return progress spinners from `flutter build`). |

### `class BuildStepFinished`

`BuildStepFinished`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | Holds the `kind` property or configuration state. |
| `status` | `BuildStepStatus status` | Holds the `status` property or configuration state. |
| `duration` | `Duration duration` | Holds the `duration` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |

### `class BuildValidationIssue`

`BuildValidationIssue`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BuildValidationIssue(this.issue)`: Initializes `BuildValidationIssue(this.issue)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `issue` | `ValidationIssue issue` | Holds the `issue` property or configuration state. |

### `class BuildPipelineFinished`

`BuildPipelineFinished`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | Holds the `status` property or configuration state. |
| `artifactPath` | `String? artifactPath` | Holds the `artifactPath` property or configuration state. |
| `duration` | `Duration duration` | Holds the `duration` property or configuration state. |

### `enum ValidationIssueKind`

`ValidationIssueKind`: Enumeration listing system options and state constants.

### `enum ValidationSeverity`

`ValidationSeverity`: Enumeration listing system options and state constants.

### `class ValidationIssue`

`ValidationIssue`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Project-relative path of the `.lmas` holding the broken reference. |
| `slotName` | `String slotName` | Holds the `slotName` property or configuration state. |
| `targetPath` | `String targetPath` | Holds the `targetPath` property or configuration state. |
| `assetId` | `String assetId` | Holds the `assetId` property or configuration state. |
| `kind` | `ValidationIssueKind kind` | Holds the `kind` property or configuration state. |
| `severity` | `ValidationSeverity severity` | Holds the `severity` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |

### `class StepResult`

`StepResult`: `class` representing the data model or functionality of the module.

**Constructors:**
- `StepResult.skipped(String message) : this(BuildStepStatus.skipped, message)`: Initializes `StepResult.skipped(String message) : this(BuildStepStatus.skipped, message)`.
- `StepResult.cancelled(String message) : this(BuildStepStatus.cancelled, message)`: Initializes `StepResult.cancelled(String message) : this(BuildStepStatus.cancelled, message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | Holds the `status` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `artifactPath` | `String? artifactPath` | Holds the `artifactPath` property or configuration state. |
| `issues` | `List<ValidationIssue> issues` | Holds the `issues` property or configuration state. |

### `class BuildStepContext`

What a step sees: the project on disk, the cancellation token and the event sinks. Named to avoid clashing with Flutter's `BuildContext`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectDir` | `String projectDir` | Holds the `projectDir` property or configuration state. |
| `project` | `LuminaProject? project` | Holds the `project` property or configuration state. |
| `token` | `BuildCancellationToken token` | Holds the `token` property or configuration state. |
| `kind` | `BuildStepKind kind` | Holds the `kind` property or configuration state. |
| `issue` | `void issue(ValidationIssue issue) => _emit(BuildValidationIssue(issue))` | Checks current state or capability and returns a boolean value. |
| `activeLevelName` | `String? get activeLevelName` | Active level name (`L_Main`) from the manifest, or null. |
| `activeLevelFile` | `File? get activeLevelFile` | Getter accessor returning the current value of `activeLevelFile`. |

### `class BuildStep`

`BuildStep`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind get kind` | Getter accessor returning the current value of `kind`. |
| `execute` | `Future<StepResult> execute(BuildStepContext ctx)` | Executes the command or action logic. |

### `class BuildPlan`

`BuildPlan`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `steps` | `List<BuildStep> steps` | Holds the `steps` property or configuration state. |

### `class BuildPipelineService`

`BuildPipelineService`: Service class encapsulating business logic, file I/O, or engine processing.

### `class _ScannedAsset`

`_ScannedAsset`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_ScannedAsset(this.file, this.relativePath, this.asset)`: Initializes `_ScannedAsset(this.file, this.relativePath, this.asset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `file` | `File file` | Holds the `file` property or configuration state. |
| `relativePath` | `String relativePath` | Holds the `relativePath` property or configuration state. |
| `asset` | `LuminaAsset asset` | Holds the `asset` property or configuration state. |

### `class MaterialCompileOutcome`

`MaterialCompileOutcome`: `class` representing the data model or functionality of the module.

**Constructors:**
- `MaterialCompileOutcome.failed(this.error)`: Initializes `MaterialCompileOutcome.failed(this.error)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ok` | `bool ok` | Holds the `ok` property or configuration state. |
| `error` | `String? error` | Holds the `error` property or configuration state. |
| `note` | `String? note` | Extra detail for the log line (e.g. "compiled from .mat source"). |

### `class MaterialCompileInput`

What the precompile seam receives for one FILAMAT asset.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `relativePath` | `String relativePath` | Holds the `relativePath` property or configuration state. |
| `package` | `Uint8List package` | Holds the `package` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |

### `class FilamentMaterialCompiler`

The real seam: builds the `Material` on a headless Filament engine from the asset's compiled package bytes (or, when the asset only carries `.mat` source, from a package the material compiler — Filament's own `.mat` parser, as the Material Editor uses it — builds from the whole source) and warms its variants via `compile()`. A rejected source fails as `matc: <matc's messages>`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timeout` | `Duration timeout` | Holds the `timeout` property or configuration state. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS` chunk of size 4). Filament aborts the process on arbitrary bytes, so this guard is mandatory before `fromBuffer`. |
| `out` | `out` | Holds the `out` property or configuration state. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/cook_and_package_steps.dart`

### `class CookCodeGenOutcome`

Result of the pre-spawn code-generation pass.

**Constructors:**

- `const CookCodeGenOutcome(this.ok, this.message, {this.writtenFiles = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `message` | `final String message` |  |
| `writtenFiles` | `final List<String> writtenFiles` |  |

### `typedef CookCodeGenerator`

Regenerates the game's Dart code; the default reads the active level from disk, the editor injects its own save-and-generate path.

### `class CookAndPackageStep`

**Constructors:**

- `CookAndPackageStep({required this.target, required this.configuration, this.extraFlags = '', this.flutterExecutable = 'flutter', BuildProcessStarter? processSta...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `target` | `final String target` |  |
| `configuration` | `final BuildConfiguration configuration` |  |
| `extraFlags` | `final String extraFlags` |  |
| `flutterExecutable` | `final String flutterExecutable` |  |
| `webModule` | `final FlutterFilamentWebModule? webModule` | flutter_filament's WebAssembly module, served next to a web build's `index.html`. Required for `web`. |
| `bundleWebResources` | `final bool bundleWebResources` | For `web`: ship CanvasKit and the other engine web resources inside the build (`--no-web-resources-cdn`) instead of loading them from Google's CDN, so the game also runs offline. |
| `bundleWebResourcesFlag` | `static const String bundleWebResourcesFlag` |  |
| `artifactPathFor` | `static String artifactPathFor(String projectDir, String target, BuildConfiguration configuration)` | Where `flutter build <target>` leaves its output for [configuration]. |
| `buildArguments` | `List<String> buildArguments()` | The argv the step spawns: `flutter build <target> <flag> [extra…]`. |
| `shellSplit` | `static List<String> shellSplit(String input)` | Splits a flags string the way a POSIX shell would (quotes and backslash escapes honoured, no expansion). |
| `levelFileCodeGenerator` | `static Future<CookCodeGenOutcome> levelFileCodeGenerator(BuildStepContext ctx) async` | Default code-gen: reads the active level's actors + environment from its `.lmas` and runs [GenerateDartCodeUseCase] (fresh `lib/main.dart` + `lib/levels/<level>.dart`, dirty flag cleared, timestamp stamped). |
| `formatBytes` | `static String formatBytes(int bytes)` | `12.3 MB`-style sizes for the log and the Output section. |
| `derivedDataCacheLeak` | `static String? derivedDataCacheLeak(String projectDir)` | Why cooking [projectDir] would ship its editor-only `DerivedDataCache/`, or null. `flutter build` bundles only the pubspec's asset entries, so the cache stays out unless one of them names it. |
| `buildAliasRoot` | `final Directory? buildAliasRoot` | Windows: where the space-free alias the build runs through lives ([SpaceFreeBuildDir]; default [SpaceFreeBuildDir.defaultAliasRoot]). On Windows `flutter build` runs through that alias of the project, because the native-assets hooks cannot compile under a path with a space (every project under `Lumina Projects`). |

### `class PackageTargetsStep`

Packages every ticked target in turn: a target the host, its toolchain or the engine cannot build is reported with its reasons and never spawned; the others run [CookAndPackageStep] and are copied into their own `<output dir>/package/<target>` folder. The game's code is generated once for the whole run.

**Constructors:**

- `PackageTargetsStep({required this.targets, required this.reasonsFor, required this.packageDirFor, this.configuration = BuildConfiguration.shipping, this.extraFl...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targets` | `final List<String> targets` | Platform ids ([kPackagingPlatforms]). |
| `configuration` | `final BuildConfiguration configuration` |  |
| `extraFlags` | `final String extraFlags` |  |
| `flutterExecutable` | `final String flutterExecutable` |  |
| `processStarter` | `final BuildProcessStarter? processStarter` |  |
| `codeGenerator` | `final CookCodeGenerator? codeGenerator` |  |
| `reasonsFor` | `final List<String> Function(String target) reasonsFor` | Why a target cannot be built (empty: buildable). |
| `packageDirFor` | `final String Function(String target) packageDirFor` | The folder a target's package is copied into. |
| `webModule` | `final FlutterFilamentWebModule? webModule` |  |
| `bundleWebResources` | `final bool bundleWebResources` |  |
| `beforeBuild` | `final Future<String?> Function(BuildStepContext ctx, String target)? beforeBuild` | Runs before a buildable target's `flutter build`; a non-null result fails the target with that message (e.g. the project icon becomes the platform's app icon). |
| `afterPackage` | `final Future<void> Function(BuildStepContext ctx, String target, String artifactPath, String packageDir)? afte...` | Runs once a target is copied into its package folder (e.g. a Linux bundle's `.desktop` entry and file-manager icon). |
| `buildAliasRoot` | `final Directory? buildAliasRoot` | Windows: where the space-free alias each build runs through lives ([CookAndPackageStep.buildAliasRoot]). |
| `argumentsFor` | `List<String> argumentsFor(String target)` | The argv `flutter` gets for [target]. |
| `sourceFor` | `static String sourceFor(String target)` |  |
| `copyArtifact` | `static int copyArtifact(String from, String to)` | Replaces [to] with a copy of [from] (a folder's contents, or a single file such as an APK); returns the bytes copied. Refuses to copy a folder into itself. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/host_build_targets.dart`

### `class ToolchainStatus`

One `flutter doctor` section, e.g. `[!] Android toolchain`.

**Constructors:**

- `const ToolchainStatus({required this.name, required this.ready, this.issues = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `ready` | `final bool ready` |  |
| `issues` | `final List<String> issues` | The section's errors (or its warnings when it has none), each with its indented hint lines joined in. |

### `class HostBuildTargets`

What the host can `flutter build`, learned from a real `flutter doctor -v` run — never a hardcoded platform list — and, per packaging platform, why it cannot: the host, the doctor toolchain, or the engine's native build.

**Constructors:**

- `const HostBuildTargets({required this.flutterAvailable, this.flutterVersion, this.targets = const [], this.error, this.rawDoctor = '', this.toolchains = const {...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `flutterAvailable` | `final bool flutterAvailable` |  |
| `flutterVersion` | `final String? flutterVersion` |  |
| `targets` | `final List<String> targets` | Platform ids ([kPackagingPlatforms]) whose toolchain is ready here. |
| `error` | `final String? error` |  |
| `rawDoctor` | `final String rawDoctor` |  |
| `toolchains` | `final Map<String, ToolchainStatus> toolchains` | Doctor sections by platform id (`android` → Android toolchain; `macos` and `ios` share Xcode). Empty when constructed without a doctor run. |
| `featureFlags` | `final List<String>? featureFlags` | `Feature flags:` from the doctor, or null when it printed none. |
| `operatingSystem` | `final String? operatingSystem` | The host OS (`Platform.operatingSystem` when null). |
| `hostOs` | `String get hostOs` |  |
| `toolchainNames` | `static const Map<String, String> toolchainNames` | The doctor section a platform's builds need; web needs none (Chrome is only for running). |
| `labelFor` | `static String labelFor(String target)` |  |
| `hostReason` | `static String? hostReason(String platform, String os)` | Why this host cannot build [platform] at all, or null. |
| `toolchainReason` | `String? toolchainReason(String platform)` | Why the Flutter toolchain for [platform] is not ready, or null. |
| `engineUnsupportedReason` | `static String? engineUnsupportedReason(String target, {List<String>? packageRoots})` | Why a Lumina game cannot be built for [target] yet, or null when it can. A ready Flutter toolchain is not enough: every game renders through flutter_filament, whose native-assets hook (`hook/build.dart`) links the Filament libraries only on Linux, macOS and Windows, and whose web build needs its WebAssembly module, looked up through the dependencies of [packageRoots] ([FlutterFilamentWebModule.locate]). |
| `reasonsFor` | `List<String> reasonsFor(String platform, {String? Function(String platform)? engineReason})` | Every reason [platform] cannot be packaged here: host, toolchain and engine, in that order. Empty means buildable. [engineReason] replaces [engineUnsupportedReason] (the editor looks the web module up once). |
| `shared` | `static Future<HostBuildTargets> shared()` | One `flutter doctor -v` per editor process, shared by Project Settings and the Build Manager. |
| `probe` | `static Future<HostBuildTargets> probe({BuildProcessStarter? processStarter, String? operatingSystem, Duration...` |  |
| `parseDoctor` | `static HostBuildTargets parseDoctor(String text, {required String operatingSystem})` | Parses `flutter doctor -v` text: every toolchain section with its status and problems; only passing ones the host OS can build for count as ready (never iOS/macOS from Linux). |

---

[Previous: Blueprint editor (continued, part 2)](blueprint-continued-2.md) | [Up: Sub-editors](index.md) | [Next: Environment lighting](environment-lighting.md)
