[English](../../../en/lumina_ui/sub-editors/build-manager.md)

# Build yöneticisi

Build Manager: materyal ön derleme, navigasyon bake, thumbnail yenileme ve asset doğrulama adımları ile oyunun Dart kodunu yeniden üreten ve gerçek bir `flutter build` çalıştıran Cook & Package. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/build_manager_sub_editor.dart`](#libuifeaturessub_editorsviewsbuild_manager_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/build_manager_view_model.dart`](#libuifeaturessub_editorsview_modelsbuild_manager_view_modeldart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicedart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/cook_and_package_steps.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicecook_and_package_stepsdart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/host_build_targets.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicehost_build_targetsdart)

## `lib/ui/features/sub_editors/views/build_manager_sub_editor.dart`

### `class BuildManagerSubEditor`

Build Manager (honestly scoped): the four real build steps (material precompile, navigation bake, thumbnail regeneration, asset validation) plus Cook & Package through a real `flutter build`.  Left: step checklist with live status badges + durations. Center: the pipeline's log console and the validation issue table. Right: target / configuration / extra flags / artifact path. Bottom: global progress, stage, elapsed time, Cancel. Nothing here is fabricated — every number and line comes from a [BuildEvent].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPath` | `String? projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialProject` | `LuminaProject? initialProject` | `initialProject` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | `editorViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `BuildManagerViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<BuildManagerSubEditor> createState() => _BuildManagerSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _BuildManagerSubEditorState`

`_BuildManagerSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModelForTest` | `BuildManagerViewModel get viewModelForTest` | `viewModelForTest` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/build_manager_view_model.dart`

### `class BuildStepState`

Per-step UI state derived from real pipeline events.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | `status` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `Duration? duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `progressLabel` | `String? progressLabel` | `progressLabel` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String? message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildLogLine`

One console line; timestamps are the event's real wall-clock time.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `at` | `DateTime at` | `at` alanını (field/property) ve ilişkili veriyi saklar. |
| `level` | `String level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `source` | `String source` | `source` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `timestamp` | `String get timestamp` | `timestamp` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class BuildManagerViewModel`

Build Manager state: step selection, target/config, one pipeline at a time, per-step status + durations, the live log and validation issues. Every line shown originates from a [BuildEvent]; logs are also forwarded to [EngineLoggerService] so the main Output Log sees builds.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectDirPath` | `String projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `flutterExecutable` | `String flutterExecutable` | `flutterExecutable` alanını (field/property) ve ilişkili veriyi saklar. |
| `project` | `LuminaProject? get project` | `project` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isStepEnabled` | `bool isStepEnabled(BuildStepKind kind)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `stepState` | `BuildStepState stepState(BuildStepKind kind)` | `stepState` işlemini gerçekleştirir. |
| `logLines` | `List<BuildLogLine> get logLines` | `logLines` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `issues` | `List<ValidationIssue> get issues` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hostTargets` | `HostBuildTargets? get hostTargets` | `hostTargets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isProbing` | `bool get isProbing` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `flutterAvailable` | `bool get flutterAvailable` | `flutterAvailable` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `flutterVersion` | `String? get flutterVersion` | `flutterVersion` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `availableTargets` | `List<String> get availableTargets` | `availableTargets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `target` | `String? get target` | `target` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `configuration` | `BuildConfiguration get configuration` | `configuration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `extraFlags` | `String get extraFlags` | `extraFlags` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isRunning` | `bool get isRunning` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `currentStep` | `BuildStepKind? get currentStep` | `currentStep` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentStage` | `String get currentStage` | `currentStage` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `completedSteps` | `int get completedSteps` | `completedSteps` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `totalSteps` | `int get totalSteps` | `totalSteps` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `elapsed` | `Duration get elapsed` | `elapsed` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `artifactPath` | `String? get artifactPath` | `artifactPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastPipelineStatus` | `BuildStepStatus? get lastPipelineStatus` | `lastPipelineStatus` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `globalProgress` | `double? get globalProgress` | Global progress 0..1, or null while the cook (unmeasurable) runs. |
| `cookArguments` | `List<String> get cookArguments` | The literal argv Cook will spawn (`flutter` + these). |
| `expectedArtifactPath` | `String? get expectedArtifactPath` | `expectedArtifactPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cookDisabledReason` | `String? get cookDisabledReason` | `cookDisabledReason` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `cookEnabled` | `bool get cookEnabled` | `cookEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `init` | `Future<void> init()` | Probes the host toolchain once (skipped when targets were injected). |
| `setStepEnabled` | `void setStepEnabled(BuildStepKind kind, bool enabled)` | `StepEnabled` parametresini günceller ve sisteme uygular. |
| `setTarget` | `void setTarget(String? target)` | `Target` parametresini günceller ve sisteme uygular. |
| `setConfiguration` | `void setConfiguration(BuildConfiguration configuration)` | `Configuration` parametresini günceller ve sisteme uygular. |
| `setExtraFlags` | `void setExtraFlags(String flags)` | `ExtraFlags` parametresini günceller ve sisteme uygular. |
| `clearLog` | `void clearLog()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `logText` | `String get logText` | `logText` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `buildAll` | `Future<BuildStepStatus?> buildAll() => _run(BuildPlan(steps: _assetSteps...` | Runs the checked steps in the fixed order. |
| `cookAndPackage` | `Future<BuildStepStatus?> cookAndPackage()` | Runs the checked steps, then the real `flutter build <target>`. |
| `cancel` | `void cancel()` | `cancel` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/sub_editors/services/build_pipeline_service.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`MatcResult buildPackageFromSource(String name, String source, {String? includeDirectory})`**: Compiles the whole `.mat` [source] with the material compiler (every header key, `vertex` and `fragment` blocks, `#include`s from [includeDirectory]), as the Material Editor does.
- **`Future<MaterialCompileOutcome> call(MaterialCompileInput input)`**: `call` işlemini gerçekleştirir.
- **`void dispose()`**: Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır.
- **`BuildStepKind kind`**: `kind` işlemini gerçekleştirir.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: İlgili komutun veya eylemin mantığını çalıştırır.
- **`BuildStepStatus status`**: `status` işlemini gerçekleştirir.
- **`String message`**: `message` işlemini gerçekleştirir.
- **`NavBuildOutcome(this.status, this.message)`**: `NavBuildOutcome` işlemini gerçekleştirir.
- **`BuildStepKind kind`**: `kind` işlemini gerçekleştirir.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: İlgili komutun veya eylemin mantığını çalıştırır.
- **`Future<NavBuildOutcome> levelFileNavigationBuilder(BuildStepContext ctx)`**: Reads `NavMeshBoundsVolume` actors (and the level's `navigation` section) from the active level `.lmas`, then runs the engine's real grid bake ([LuminaNavigationSystem.buildFromWorld]) on a headless world.
- **`BuildStepKind kind`**: `kind` işlemini gerçekleştirir.
- **`bool isStale(File lmas, LuminaAsset asset)`**: Stale when the asset has no thumbnail, or the payload (`.lmas` mtime) is newer than the cached thumbnail timestamp (or there is no timestamp).
- **`Future<StepResult> execute(BuildStepContext ctx)`**: İlgili komutun veya eylemin mantığını çalıştırır.
- **`BuildStepKind kind`**: `kind` işlemini gerçekleştirir.
- **`Future<StepResult> execute(BuildStepContext ctx)`**: İlgili komutun veya eylemin mantığını çalıştırır.
- **`bool ok`**: Result of the pre-spawn code-generation pass.
- **`String message`**: `message` işlemini gerçekleştirir.
- **`List<String> writtenFiles`**: `writtenFiles` işlemini gerçekleştirir.
- **`String target`**: Regenerates the game's Dart code; the default reads the active level from disk, the editor injects its own save-and-generate path.
- **`BuildConfiguration configuration`**: `configuration` işlemini gerçekleştirir.
- **`String extraFlags`**: `extraFlags` işlemini gerçekleştirir.
- **`String flutterExecutable`**: `flutterExecutable` işlemini gerçekleştirir.
- **`BuildStepKind kind`**: `kind` işlemini gerçekleştirir.
- **`String artifactPathFor(String projectDir, String target, BuildConfiguration configuration)`**: Where `flutter build <target>` leaves its output for [configuration].
- **`List<String> buildArguments()`**: The argv the step spawns: `flutter build <target> <flag> [extra…]`.
- **`List<String> shellSplit(String input)`**: Splits a flags string the way a POSIX shell would (quotes and backslash escapes honoured, no expansion).
- **`Future<CookCodeGenOutcome> levelFileCodeGenerator(BuildStepContext ctx)`**: Default code-gen: reads the active level's actors + environment from its `.lmas` and runs [GenerateDartCodeUseCase] (fresh `lib/main.dart` + `lib/levels/<L>.dart`, dirty flag cleared, timestamp stamped).
- **`Future<StepResult> execute(BuildStepContext ctx)`**: İlgili komutun veya eylemin mantığını çalıştırır.
- **`String text`**: `text` işlemini gerçekleştirir.
- **`bool replaceLast`**: `replaceLast` işlemini gerçekleştirir.
- **`Stream<_SplitLine> bind(Stream<String> stream)`**: `bind` işlemini gerçekleştirir.
- **`bool flutterAvailable`**: Platforms the host can actually `flutter build`, learned from a real `flutter doctor -v` run — never a hardcoded platform list.
- **`String? flutterVersion`**: `flutterVersion` işlemini gerçekleştirir.
- **`List<String> targets`**: `targets` işlemini gerçekleştirir.
- **`String? error`**: `error` işlemini gerçekleştirir.
- **`String rawDoctor`**: `rawDoctor` işlemini gerçekleştirir.
- **`String labelFor(String target) => switch (target)`**: `labelFor` işlemini gerçekleştirir.

### `enum BuildStepKind`

Build Manager pipeline: real build steps over the open project — material precompile, navigation grid bake, thumbnail regeneration, asset validation — and Cook & Package, which regenerates the game's Dart code and drives a real `flutter build <target>` child process with streamed output. Every event in the stream originates from actual work; there are no fabricated counters.  The steps in their fixed documented execution order.

**Yapıcı Metotlar (Constructors):**
- `BuildStepKind(this.label)`: `BuildStepKind(this.label)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cookAndPackage` | `cookAndPackage('Cook & Package')` | `cookAndPackage` işlemini gerçekleştirir. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |

### `enum BuildStepStatus`

`BuildStepStatus`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum BuildConfiguration`

Build configuration names mapped to the literal `flutter build` flag.

**Yapıcı Metotlar (Constructors):**
- `BuildConfiguration(this.label, this.flag, this.modeDir)`: `BuildConfiguration(this.label, this.flag, this.modeDir)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shipping` | `shipping('Shipping', '--release', 'release')` | `shipping` işlemini gerçekleştirir. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `flag` | `String flag` | The flag passed verbatim to `flutter build`. |
| `modeDir` | `String modeDir` | Flutter's output-directory name for the mode. |

### `class BuildCancellationToken`

Cooperative cancellation shared by the pipeline and the running step.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isCancelled` | `bool get isCancelled` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `cancel` | `void cancel()` | `cancel` işlemini gerçekleştirir. |
| `onCancel` | `void onCancel(void Function() fn)` | Registers [fn] to run when the token fires (immediately if already fired). |
| `removeListener` | `void removeListener(void Function() fn) => _listeners.remove(fn)` | Belirtilen `Listener` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

### `class BuildEvent`

`BuildEvent`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

### `class BuildStepStarted`

`BuildStepStarted`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BuildStepStarted(this.kind)`: `BuildStepStarted(this.kind)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildStepProgress`

Measurable progress inside a step (materials compiled, thumbnails rendered…).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `completed` | `int completed` | `completed` alanını (field/property) ve ilişkili veriyi saklar. |
| `total` | `int total` | `total` alanını (field/property) ve ilişkili veriyi saklar. |
| `failed` | `int failed` | `failed` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildLogEvent`

`BuildLogEvent`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind? kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `level` | `String level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `source` | `String source` | `source` alanını (field/property) ve ilişkili veriyi saklar. |
| `replaceLast` | `bool replaceLast` | True when this line replaces the previous one (carriage-return progress spinners from `flutter build`). |

### `class BuildStepFinished`

`BuildStepFinished`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `status` | `BuildStepStatus status` | `status` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `Duration duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildValidationIssue`

`BuildValidationIssue`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BuildValidationIssue(this.issue)`: `BuildValidationIssue(this.issue)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `issue` | `ValidationIssue issue` | `issue` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildPipelineFinished`

`BuildPipelineFinished`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | `status` alanını (field/property) ve ilişkili veriyi saklar. |
| `artifactPath` | `String? artifactPath` | `artifactPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `Duration duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |

### `enum ValidationIssueKind`

`ValidationIssueKind`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum ValidationSeverity`

`ValidationSeverity`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class ValidationIssue`

`ValidationIssue`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Project-relative path of the `.lmas` holding the broken reference. |
| `slotName` | `String slotName` | `slotName` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetPath` | `String targetPath` | `targetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetId` | `String assetId` | `assetId` alanını (field/property) ve ilişkili veriyi saklar. |
| `kind` | `ValidationIssueKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `severity` | `ValidationSeverity severity` | `severity` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |

### `class StepResult`

`StepResult`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `StepResult.skipped(String message) : this(BuildStepStatus.skipped, message)`: `StepResult.skipped(String message) : this(BuildStepStatus.skipped, message)` nesnesini ilklendirir.
- `StepResult.cancelled(String message) : this(BuildStepStatus.cancelled, message)`: `StepResult.cancelled(String message) : this(BuildStepStatus.cancelled, message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `status` | `BuildStepStatus status` | `status` alanını (field/property) ve ilişkili veriyi saklar. |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `artifactPath` | `String? artifactPath` | `artifactPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `issues` | `List<ValidationIssue> issues` | `issues` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildStepContext`

What a step sees: the project on disk, the cancellation token and the event sinks. Named to avoid clashing with Flutter's `BuildContext`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectDir` | `String projectDir` | `projectDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `project` | `LuminaProject? project` | `project` alanını (field/property) ve ilişkili veriyi saklar. |
| `token` | `BuildCancellationToken token` | `token` alanını (field/property) ve ilişkili veriyi saklar. |
| `kind` | `BuildStepKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `issue` | `void issue(ValidationIssue issue) => _emit(BuildValidationIssue(issue))` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `activeLevelName` | `String? get activeLevelName` | Active level name (`L_Main`) from the manifest, or null. |
| `activeLevelFile` | `File? get activeLevelFile` | `activeLevelFile` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class BuildStep`

`BuildStep`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `kind` | `BuildStepKind get kind` | `kind` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `execute` | `Future<StepResult> execute(BuildStepContext ctx)` | İlgili komutun veya eylemin mantığını çalıştırır. |

### `class BuildPlan`

`BuildPlan`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `steps` | `List<BuildStep> steps` | `steps` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BuildPipelineService`

`BuildPipelineService`: Dosya işlemleri, veri dönüşümleri veya motor mantığını yürüten servis sınıfıdır.

### `class _ScannedAsset`

`_ScannedAsset`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_ScannedAsset(this.file, this.relativePath, this.asset)`: `_ScannedAsset(this.file, this.relativePath, this.asset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `file` | `File file` | `file` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativePath` | `String relativePath` | `relativePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `LuminaAsset asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MaterialCompileOutcome`

`MaterialCompileOutcome`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `MaterialCompileOutcome.failed(this.error)`: `MaterialCompileOutcome.failed(this.error)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ok` | `bool ok` | `ok` alanını (field/property) ve ilişkili veriyi saklar. |
| `error` | `String? error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `note` | `String? note` | Extra detail for the log line (e.g. "compiled from .mat source"). |

### `class MaterialCompileInput`

What the precompile seam receives for one FILAMAT asset.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativePath` | `String relativePath` | `relativePath` alanını (field/property) ve ilişkili veriyi saklar. |
| `package` | `Uint8List package` | `package` alanını (field/property) ve ilişkili veriyi saklar. |
| `source` | `String source` | `source` alanını (field/property) ve ilişkili veriyi saklar. |

### `class FilamentMaterialCompiler`

The real seam: builds the `Material` on a headless Filament engine from the asset's compiled package bytes (or, when the asset only carries `.mat` source, from a package the material compiler — Filament's own `.mat` parser, as the Material Editor uses it — builds from the whole source) and warms its variants via `compile()`. A rejected source fails as `matc: <matc's messages>`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeout` | `Duration timeout` | `timeout` alanını (field/property) ve ilişkili veriyi saklar. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS` chunk of size 4). Filament aborts the process on arbitrary bytes, so this guard is mandatory before `fromBuffer`. |
| `out` | `out` | `out` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/cook_and_package_steps.dart`

### `class CookCodeGenOutcome`

Result of the pre-spawn code-generation pass.

**Yapıcı Metotlar (Constructors):**

- `const CookCodeGenOutcome(this.ok, this.message, {this.writtenFiles = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `message` | `final String message` |  |
| `writtenFiles` | `final List<String> writtenFiles` |  |

### `typedef CookCodeGenerator`

Regenerates the game's Dart code; the default reads the active level from disk, the editor injects its own save-and-generate path.

### `class CookAndPackageStep`

**Yapıcı Metotlar (Constructors):**

- `CookAndPackageStep({required this.target, required this.configuration, this.extraFlags = '', this.flutterExecutable = 'flutter', BuildProcessStarter? processSta...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

### `class PackageTargetsStep`

Packages every ticked target in turn: a target the host, its toolchain or the engine cannot build is reported with its reasons and never spawned; the others run [CookAndPackageStep] and are copied into their own `<output dir>/package/<target>` folder. The game's code is generated once for the whole run.

**Yapıcı Metotlar (Constructors):**

- `PackageTargetsStep({required this.targets, required this.reasonsFor, required this.packageDirFor, this.configuration = BuildConfiguration.shipping, this.extraFl...`

**Üyeler:**

| Üye | İmza | Açıklama |
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
| `argumentsFor` | `List<String> argumentsFor(String target)` | The argv `flutter` gets for [target]. |
| `sourceFor` | `static String sourceFor(String target)` |  |
| `copyArtifact` | `static int copyArtifact(String from, String to)` | Replaces [to] with a copy of [from] (a folder's contents, or a single file such as an APK); returns the bytes copied. Refuses to copy a folder into itself. |

## `lib/ui/features/sub_editors/services/build_pipeline_service/host_build_targets.dart`

### `class ToolchainStatus`

One `flutter doctor` section, e.g. `[!] Android toolchain`.

**Yapıcı Metotlar (Constructors):**

- `const ToolchainStatus({required this.name, required this.ready, this.issues = const []})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `ready` | `final bool ready` |  |
| `issues` | `final List<String> issues` | The section's errors (or its warnings when it has none), each with its indented hint lines joined in. |

### `class HostBuildTargets`

What the host can `flutter build`, learned from a real `flutter doctor -v` run — never a hardcoded platform list — and, per packaging platform, why it cannot: the host, the doctor toolchain, or the engine's native build.

**Yapıcı Metotlar (Constructors):**

- `const HostBuildTargets({required this.flutterAvailable, this.flutterVersion, this.targets = const [], this.error, this.rawDoctor = '', this.toolchains = const {...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

[Önceki: Blueprint editörü (devamı, bölüm 2)](blueprint-continued-2.md) | [Üst: Alt editörler](index.md) | [Sonraki: Çevre ışıklandırması](environment-lighting.md)
