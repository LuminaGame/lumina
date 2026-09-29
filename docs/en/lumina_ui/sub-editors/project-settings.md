[Türkçe](../../../tr/lumina_ui/sub-editors/project-settings.md)

# Project settings

The Project Settings editor: a searchable, validated, category-based view over the project's `.lmproject` manifest. File paths are relative to the `lumina_ui/` package directory.

## `lib/ui/features/sub_editors/views/project_settings_sub_editor.dart`

### `class ProjectSettingsSubEditor`

Project Settings: split view over the real `.lmproject`.  Left: searchable category list with validation badges. Right: the category's editors. Footer: dirty indicator, Revert, Apply & Save. Every control edits the view model's working copy instantly; only Apply writes the manifest and pushes graphics settings to the editor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `projectDirPath` | `String? projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `initialProject` | `LuminaProject? initialProject` | Holds the `initialProject` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `viewModel` | `ProjectSettingsViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<ProjectSettingsSubEditor> createState() => _ProjectSettingsSubEdit...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ProjectSettingsSubEditorState`

`_ProjectSettingsSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `viewModelForTest` | `ProjectSettingsViewModel get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/project_settings_view_model.dart`

### `class LevelChoice`

A LEVEL asset available to the Maps & Modes pickers.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `relativePath` | `String relativePath` | Holds the `relativePath` property or configuration state. |
| `displayName` | `String displayName` | Holds the `displayName` property or configuration state. |
| `thumbnail` | `Uint8List? thumbnail` | Holds the `thumbnail` property or configuration state. |

### `class PackagingRunState`

Result of a packaging run (`flutter build <target>`).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isRunning` | `bool isRunning` | Holds the `isRunning` property or configuration state. |
| `progress` | `double progress` | Holds the `progress` property or configuration state. |
| `exitCode` | `int? exitCode` | Holds the `exitCode` property or configuration state. |
| `lastLine` | `String? lastLine` | Holds the `lastLine` property or configuration state. |

### `class ProjectSettingsCategory`

Settings categories in display order. Keys are stable ids used by search, validation badges and the navigation list.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `static String title(String id)` | Executes `title` operation. |

### `class ProjectSettingsViewModel`

Edits the real `.lmproject` manifest: loads it through [ProjectRepository], keeps a working copy with dirty tracking and per-category validation, and writes it back on [apply]. Graphics changes are pushed to the editor via [onApplied] so the toolbar scalability state is shared, not copied.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectDirPath` | `String projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `loadError` | `String? get loadError` | Loads data from disk or memory buffer into the engine. |
| `hasProject` | `bool get hasProject` | Checks current state or capability and returns a boolean value. |
| `project` | `LuminaProject get project` | Getter accessor returning the current value of `project`. |
| `onDiskProject` | `LuminaProject? get onDiskProject` | Callback invoked when the corresponding event is triggered. |
| `manifestPath` | `String? get manifestPath` | Getter accessor returning the current value of `manifestPath`. |
| `filterQuery` | `String get filterQuery` | Getter accessor returning the current value of `filterQuery`. |
| `levels` | `List<LevelChoice> get levels` | Getter accessor returning the current value of `levels`. |
| `gameModeClasses` | `List<String> get gameModeClasses` | Getter accessor returning the current value of `gameModeClasses`. |
| `packaging` | `PackagingRunState get packaging` | Getter accessor returning the current value of `packaging`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `load` | `Future<void> load()` | Locates `<projectDir>/<name>.lmproject` (any `.lmproject` if the name is unknown) and loads it. Never throws; [loadError] reports failures. |
| `revert` | `Future<void> revert()` | Reloads the on-disk manifest, discarding edits. |
| `apply` | `Future<bool> apply()` | Validates every category; refuses to save while errors exist. Warnings (e.g. a map whose file is gone) do not block saving. |
| `validationErrors` | `Map<String, List<String>> get validationErrors` | Blocking errors keyed by [ProjectSettingsCategory] id. |
| `validationWarnings` | `Map<String, List<String>> get validationWarnings` | Non-blocking warnings (a missing default map is allowed). |
| `errorCount` | `int errorCount(String category)` | Executes `errorCount` operation. |
| `setFilterQuery` | `void setFilterQuery(String q)` | Updates the `FilterQuery` parameter and applies changes to the system. |
| `visibleCategories` | `List<String> get visibleCategories` | Categories whose title or row keywords match the query (all when empty). |
| `rowMatches` | `bool rowMatches(String label) => _filterQuery.isEmpty \|\| label.toLower...` | Whether a settings row labelled [label] matches the current query. |
| `setProjectName` | `void setProjectName(String v) => _update((p) => p.copyWith(projectName: v))` | Updates the `ProjectName` parameter and applies changes to the system. |
| `setDescription` | `void setDescription(String v) => _update((p) => p.copyWith(description: v))` | Updates the `Description` parameter and applies changes to the system. |
| `setQualityPreset` | `void setQualityPreset(String preset) => _update((p)` | Selecting a preset instantly expands every per-category tier. |
| `setScalabilityField` | `void setScalabilityField(String field, String tier) => _update((p)` | Updates the `ScalabilityField` parameter and applies changes to the system. |
| `setTargetFps` | `void setTargetFps(int fps) => _update((p) => p.copyWith(settings: _copyS...` | Updates the `TargetFps` parameter and applies changes to the system. |
| `setVSync` | `void setVSync(bool on) => _update((p) => p.copyWith(settings: _copySetti...` | Updates the `VSync` parameter and applies changes to the system. |
| `addAction` | `void addAction([String? name]) => _update((p)` | Appends a new item to the collection or scene. |
| `removeAction` | `void removeAction(int index) => _update((p)` | Releases and safely disposes the specified `Action` resource. |
| `addMappingContext` | `void addMappingContext([String? name]) => _update((p)` | Appends a new item to the collection or scene. |
| `removeMappingContext` | `void removeMappingContext(int index) => _update((p)` | Releases and safely disposes the specified `MappingContext` resource. |
| `addMapping` | `void addMapping(int contextIndex, ProjectInputMapping mapping) => _updat...` | Appends a new item to the collection or scene. |
| `removeMapping` | `void removeMapping(int contextIndex, int mappingIndex) => _update((p)` | Releases and safely disposes the specified `Mapping` resource. |
| `setEditorStartupMap` | `void setEditorStartupMap(String relativePath)` | Updates the `EditorStartupMap` parameter and applies changes to the system. |
| `setGameDefaultMap` | `void setGameDefaultMap(String relativePath)` | Updates the `GameDefaultMap` parameter and applies changes to the system. |
| `setDefaultGameMode` | `void setDefaultGameMode(String className)` | Updates the `DefaultGameMode` parameter and applies changes to the system. |
| `setGravityZ` | `void setGravityZ(double g) => _update((p) => p.copyWith(physics: p.physi...` | Updates the `GravityZ` parameter and applies changes to the system. |
| `setFixedTimestep` | `void setFixedTimestep(double dt) => _update((p) => p.copyWith(physics: p...` | Updates the `FixedTimestep` parameter and applies changes to the system. |
| `setTargetOs` | `void setTargetOs(String os) => _update((p) => p.copyWith(packaging: p.pa...` | Updates the `TargetOs` parameter and applies changes to the system. |
| `setOutputDir` | `void setOutputDir(String dir) => _update((p) => p.copyWith(packaging: p....` | Updates the `OutputDir` parameter and applies changes to the system. |
| `packageProject` | `Future<int> packageProject()` | Runs the real `flutter build <target>` in the project directory, streaming output into the engine log. A non-zero exit code is surfaced as an error and the progress resets; there is no fake success. |
| `cancelPackaging` | `void cancelPackaging()` | Executes `cancelPackaging` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/view_models/project_settings_view_model/models.dart`

### `class LevelChoice`

A LEVEL asset available to the Maps & Modes pickers.

**Constructors:**

- `const LevelChoice({required this.relativePath, required this.displayName, this.thumbnail})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` |  |
| `displayName` | `final String displayName` |  |
| `thumbnail` | `final Uint8List? thumbnail` |  |

### `class PackagingLogLine`

One line of a packaging run's console, tagged with its source (`Cook & Package [linux]`).

**Constructors:**

- `const PackagingLogLine({required this.at, required this.level, required this.source, required this.message})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `at` | `final DateTime at` |  |
| `level` | `final String level` |  |
| `source` | `final String source` |  |
| `message` | `final String message` |  |
| `target` | `String? get target` | The platform id a line belongs to, or null for run-wide lines. |

### `class PackagingRunState`

The last Package Project run over every ticked target.

**Constructors:**

- `const PackagingRunState({this.isRunning = false, this.statuses = const {}, this.durations = const {}, this.packageDirs = const {}, this.messages = const {}, thi...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isRunning` | `final bool isRunning` |  |
| `statuses` | `final Map<String, PackageTargetStatus> statuses` | Per platform id: pending → running → ok / failed / unbuildable / cancelled. |
| `durations` | `final Map<String, Duration> durations` |  |
| `packageDirs` | `final Map<String, String> packageDirs` | Package folders of the targets that succeeded. |
| `messages` | `final Map<String, String> messages` | Why a target was not built or failed. |
| `result` | `final BuildStepStatus? result` | Result of the whole run (null while running or before the first run). |
| `stage` | `final String? stage` |  |

### `class ProjectSettingsCategory`

Settings categories in display order. Keys are stable ids used by search, validation badges and the navigation list.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `description` | `static const description` |  |
| `graphics` | `static const graphics` |  |
| `input` | `static const input` |  |
| `mapsAndModes` | `static const mapsAndModes` |  |
| `physics` | `static const physics` |  |
| `packaging` | `static const packaging` |  |
| `userInterface` | `static const userInterface` |  |
| `all` | `static const all` |  |
| `title` | `static String title(String id)` |  |
| `keywords` | `static const Map<String, List<String>> keywords` | Searchable keywords per category (row labels) for the settings search. |

## `lib/ui/features/sub_editors/views/project_editor_builds_preferences_page.dart`

### `class ProjectEditorBuildsPreferencesPage`

Editor Preferences → General › Project Editor Builds: how project editors (a project's code plugins compiled into its own editor) are built, and the shared cache they live in.

**Constructors:**

- `const ProjectEditorBuildsPreferencesPage({super.key, required this.preferences, this.projectDir, this.engineRoot})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `preferences` | `final EditorPreferences preferences` |  |
| `projectDir` | `final String? projectDir` | The open project, whose copy of the engine source the Editor Source section shows; null in the launcher. |
| `engineRoot` | `final String? engineRoot` | The engine checkout the copy syncs from; defaults to this editor's. |
| `category` | `static const String category` |  |
| `cacheFor` | `static EditorBuildCache cacheFor(EditorPreferences preferences)` | The cache the preferences point at. |

## `lib/ui/features/sub_editors/views/project_editor_source_section.dart`

### `class ProjectEditorSourceSection`

Editor Preferences › Project Editor Builds › Editor Source: the open project's copy of the engine source under `.lumina/editor/`, whether the engine moved on since it was made, and Sync, which replaces the copy (after a warning) so the next open rebuilds from the engine's current source.

**Constructors:**

- `const ProjectEditorSourceSection({super.key, required this.projectDir, required this.engineRoot, required this.formatBytes})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `engineRoot` | `final String engineRoot` |  |
| `formatBytes` | `final String Function(int bytes) formatBytes` |  |

## `lib/ui/features/sub_editors/views/project_settings/web_loading_style_section.dart`

### `typedef SettingsSectionBuilder`

Builds a titled settings section (the sub-editor's own look).

### `typedef SettingsRowBuilder`

Builds a labelled, search-aware settings row.

### `class WebLoadingStyleSection`

Project Settings → Packaging & Target → **Web Loading Style**: the look of a web build's plain HTML loading screen, shown while a web target is ticked. Every control edits the view model's working copy; Apply & Save writes `packaging.web_loading_style` and regenerates the project's `web/` loading screen. The preview draws the generated page's layout with the same values, and "Open in Browser" serves the generated page itself.

**Constructors:**

- `const WebLoadingStyleSection({super.key, required this.viewModel, required this.section, required this.row})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final ProjectSettingsViewModel viewModel` |  |
| `section` | `final SettingsSectionBuilder section` |  |
| `row` | `final SettingsRowBuilder row` |  |

### `class WebLoadingPreview`

The loading screen's layout, drawn in Flutter with the page's values (`web/index.html` + `loading.css`): background or gradient, logo, title, subtitle, the progress in its style and the phase label `loading.js` shows at [fraction].

**Constructors:**

- `const WebLoadingPreview({super.key, required this.style, required this.logo, required this.fraction})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `style` | `final ResolvedWebLoadingStyle style` |  |
| `logo` | `final Widget? logo` |  |
| `fraction` | `final double fraction` |  |
| `labelFor` | `static String labelFor(double fraction)` | The label `loading.js` shows around [fraction] (its phases). |

---

[Previous: Physics asset editor](physics-asset.md) | [Up: Sub-editors](index.md) | [Next: Sequencer](sequencer.md)
