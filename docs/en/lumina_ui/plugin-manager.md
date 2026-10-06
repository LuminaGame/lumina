[Türkçe](../../tr/lumina_ui/plugin-manager.md)

# Plugin manager

The Plugin Manager window, which lists, enables, disables, imports and removes plugins, and the New Plugin wizard, which generates a plugin package from a template. File paths are relative to the `lumina_ui/` package directory.

## Built-in plugins

**BUILT-IN** lists the plugins that ship with the engine: the plugin packages the engine workspace resolved (`lumina_plugin_pcg` and `lumina_plugin_miniai` from the plugins repository, pinned by commit as `lumina_ui` dev dependencies), found through `.dart_tool/package_config.json` by `editorPluginScanRoots` (`lib/ui/core/services/user_plugin_dir.dart`). In a source workspace they are the sibling `plugins` checkout (`pubspec_overrides.yaml`); in a release checkout, the git checkouts `flutter pub get` put in the pub cache. A built-in is enabled and disabled per project with its switch, like any other plugin: the switch writes the project's `enabled_plugins` in its `.lmproject`, the card shows **Restart required** and the restart banner appears, and the project's editor host is regenerated to depend on it (by the same git dependency the engine pinned; see [Plugins](../plugins/index.md)), so **Restart Editor** rebuilds the project editor with it. The built-ins ship off: their manifests do not set `enabled_by_default`, since each is a code plugin that needs a project editor rebuild. A built-in cannot be removed or edited from the Plugin Manager (it belongs to the engine checkout; the details pane says so); a user plugin of the same name (for example a newer version imported from a zip) takes its place. Such an override is not a scan error: the Output Log notes it at info level (source `PluginDiscovery`) and the card of the copy that loads says **Overrides the engine copy** (or the user copy, for a project plugin over a user one).

## A plugin that fails to load

The code plugins compiled into a project editor register while the editor starts, after the project's saved layout is loaded (a plugin may read or change its panels' visibility in `register`). A plugin whose `register` throws is left out: what it registered before the error is removed, the error is logged to the Output Log under the plugin's name (source `Plugins`), and its card shows an **Issue** badge whose tooltip holds the error (`PluginIssueType.registrationFailed`). The editor and the other plugins load as usual.

## Isolated plugins: process status

A plugin running in its own process (see [Plugin processes](plugin-processes.md)) shows a **Status** badge on its card
(Running, Starting, Hung, Crashed, Stopped, In process; the tooltip gives the reason) and a **Process** section in the
details pane: the status with its reason, pid, last exit code and automatic restarts, a **Restart** button, the
**Run in editor process (debugging)** switch and the tail of the process's log. The switch writes the project's
`plugin_isolation` override (`.lmproject`, through `PluginRegistryService.setIsolationOverride` and the editor's own
project) and moves the plugin at once: same channel, restarted in the other mode. The New Plugin wizard's
**Run in its own process** switch (not offered for content-only plugins) scaffolds an isolated plugin, as the MCP tool
`create_plugin` does with `isolated: true`.

## Importing a plugin

**Import from Folder** and **Import from Zip**, next to **New Plugin** in the list header, install a plugin into the per-user plugin folder (`UserPluginDir.resolve()`, where the Marketplace installs plugins too) by copying it; a plugin is never linked from where it was picked. Both open the system picker and validate before anything is written:

- the `<name>.lmplugin` manifest, by the marketplace's package rules (`checkPluginPackage` from `lumina_marketplace_shared`) and by the editor's own loader (`PluginRepository.loadInternal`);
- **a zip** is read as the marketplace plugin package format that `tool/pack_plugin.dart` writes: every entry must be a safe relative path (`isSafeRelativePath`: no `..`, no absolute path or drive, no backslash), no symbolic links, only files on the marketplace's allow-list, no duplicates, at most 10,000 entries and 1 GB unpacked; a single top folder, when present, must be named after the plugin; license and changelog problems refuse the zip;
- **a folder** is copied without `.dart_tool/`, `.git/`, `.idea/`, `.vscode/`, `node_modules/`, a root `build/` or `coverage/`, and `pubspec_overrides.yaml`; symbolic links are left out with a warning; license and changelog findings are only warnings.

A plugin of the same name already in the user folder asks **Replace / Cancel** (Replace swaps the whole folder; the previous copy comes back if writing fails). A project plugin of the same name refuses the import, because it would hide the user copy. A built-in of the same name is replaced for every project by the user copy, with a warning. After an install the plugin roots are rescanned and the new plugin is selected; enabling it is still a separate step.

## Removing a plugin

A USER or PROJECT plugin has a **Remove** button in the details pane (a built-in has none; it belongs to the engine checkout). Remove first opens a confirmation (`plugin_remove_dialog`) that lists what will be deleted before anything is deleted:

- the plugin folder, its file count and size; for a folder that is a **symbolic link or a Windows junction** (a developer linking a source checkout with `mklink /J`): "Linked from <target>; only the link is removed" — the link is deleted, never followed, and the folder it points to keeps every file;
- a USER plugin is removed for every project on this machine; a PROJECT plugin from this project's `plugins/`;
- a plugin the Marketplace installed (a plugin record in the editor's `marketplace/licenses.json` whose `installedTo` is the folder) is removed through the Marketplace's uninstall (`MarketplaceInstaller.removeInstall`), so its license record goes too;
- enabled in the open project: it is disabled (`enabled_plugins` in the `.lmproject`) together with the enabled plugins that depend on it (named), the project's editor host is regenerated as the switch does, and removing a code plugin shows the restart banner; a plugin this editor session registered stays active until the editor restarts (`EditorViewModel.isPluginLoaded`);
- a plugin of the same name in a lower-priority root (the built-in a user copy replaced, or a user plugin under a project one) takes its place again, disabled, and is selected;
- **Also delete its saved data** (unchecked): the per-user `plugin_data/<name>/` (`PluginDataDir`) and the open project's `.lumina/plugins/<name>/`, each with its size; only the folders that exist are listed. Other projects' data is not touched.

The removal is transactional (`FolderInstall.remove`): the folder is renamed to `.<name>.removing` beside it and only then deleted, so a locked file (on Windows, an open file or a loaded DLL) stops it before anything is deleted; the dialog then stays open and lists what was and was not removed, and nothing in the project changes. Saved data is deleted only after the plugin itself is gone. A scan root skips dot folders, so a set-aside folder is never listed as a plugin. Afterwards the plugin roots are rescanned (`EditorViewModel.rescanPlugins`, which keeps a pending restart banner) and the selection moves to the neighbour in the list. The MCP tool `remove_plugin` does the same; `dry_run: true` returns the deletion list.

**On this page:**

- [`lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`](#libuifeaturesplugin_managerviewsnew_plugin_wizarddart)
- [`lib/ui/features/plugin_manager/views/plugin_manager_view.dart`](#libuifeaturesplugin_managerviewsplugin_manager_viewdart)
- [`lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`](#libuifeaturesplugin_managerview_modelsplugin_manager_view_modeldart)
- [`lib/ui/features/plugin_manager/views/plugin_import_dialogs.dart`](#libuifeaturesplugin_managerviewsplugin_import_dialogsdart)
- [`lib/ui/features/plugin_manager/services/plugin_importer.dart`](#libuifeaturesplugin_managerservicesplugin_importerdart)
- [`lib/ui/core/services/folder_install.dart`](#libuicoreservicesfolder_installdart)
- [`lib/ui/features/plugin_manager/views/plugin_remove_dialog.dart`](#libuifeaturesplugin_managerviewsplugin_remove_dialogdart)
- [`lib/ui/features/plugin_manager/services/plugin_remover.dart`](#libuifeaturesplugin_managerservicesplugin_removerdart)

## `lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`

### `class NewPluginWizardDialog`

`NewPluginWizardDialog`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rootContext` | `BuildContext rootContext` | Holds the `rootContext` property or configuration state. |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `generatorService` | `PluginTemplateGeneratorService? generatorService` | Holds the `generatorService` property or configuration state. |
| `configFilePath` | `String? configFilePath` | Holds the `configFilePath` property or configuration state. |
| `projectRoot` | `Directory? projectRoot` | Holds the `projectRoot` property or configuration state. |
| `editorApiRoot` | `Directory? editorApiRoot` | Holds the `editorApiRoot` property or configuration state. |
| `onClose` | `VoidCallback onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<NewPluginWizardDialog> createState() => _NewPluginWizardDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _NewPluginWizardDialogState`

`_NewPluginWizardDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _TemplateTile`

`_TemplateTile`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |
| `isSelected` | `bool isSelected` | Holds the `isSelected` property or configuration state. |
| `onTap` | `VoidCallback onTap` | Holds the `onTap` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/plugin_manager/views/plugin_manager_view.dart`

### `class PluginManagerView`

`PluginManagerView`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _CategorySidebar`

`_CategorySidebar`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _CategoryRow`

`_CategoryRow`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `count` | `int count` | Holds the `count` property or configuration state. |
| `isSelected` | `bool isSelected` | Holds the `isSelected` property or configuration state. |
| `onTap` | `VoidCallback onTap` | Holds the `onTap` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _PluginCardList`

`_PluginCardList`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _PluginCard`

`_PluginCard`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `entry` | `PluginEntry entry` | Holds the `entry` property or configuration state. |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _ScanErrorsSection`

`_ScanErrorsSection`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `errors` | `List<PluginScanError> errors` | Holds the `errors` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _PluginDetailsPane`

`_PluginDetailsPane`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `PluginManagerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _PluginIcon`

`_PluginIcon`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `iconFile` | `File? iconFile` | Holds the `iconFile` property or configuration state. |
| `size` | `double size` | Holds the `size` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`

### `class PluginManagerViewModel`

`PluginManagerViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `registryService` | `PluginRegistryService registryService` | Holds the `registryService` property or configuration state. |
| `searchQuery` | `String get searchQuery` | Getter accessor returning the current value of `searchQuery`. |
| `searchQuery` | `searchQuery(String value)` | Executes `searchQuery` operation. |
| `selectedCategory` | `String get selectedCategory` | Selects the target actor or asset. |
| `selectedGroup` | `String get selectedGroup` | Selects the target actor or asset. |
| `selectCategory` | `void selectCategory(String group, String category)` | Selects the target actor or asset. |
| `selectedEntry` | `PluginEntry? get selectedEntry` | Selects the target actor or asset. |
| `selectedEntry` | `selectedEntry(PluginEntry? entry)` | Selects the target actor or asset. |
| `entries` | `List<PluginEntry> get entries` | Getter accessor returning the current value of `entries`. |
| `installedCount` | `int get installedCount` | Getter accessor returning the current value of `installedCount`. |
| `builtInCount` | `int get builtInCount` | Getter accessor returning the current value of `builtInCount`. |
| `totalCount` | `int get totalCount` | Getter accessor returning the current value of `totalCount`. |
| `enabledCount` | `int get enabledCount` | Getter accessor returning the current value of `enabledCount`. |
| `scanErrors` | `List<PluginScanError> get scanErrors` | Getter accessor returning the current value of `scanErrors`. |
| `categoryCounts` | `Map<String, int> get categoryCounts` | Getter accessor returning the current value of `categoryCounts`. |
| `refresh` | `Future<void> refresh()` | Executes `refresh` operation. |
| `resolve` | `PluginResolution resolve(Set<String> wantedEnabled)` | Executes `resolve` operation. |
| `onPluginsChanged` | `Future<void> Function()? onPluginsChanged` | Runs after an import changed the plugin folders (the editor wires `EditorViewModel.rescanPlugins`); without it the registry is refreshed. |
| `folderPicker` / `zipPicker` | `Future<String?> Function()? folderPicker` | The Import from Folder / Import from Zip pickers; null opens the system dialog (tests and smokes point them at real files through `EditorViewModel.pluginFolderPicker` / `pluginZipPicker`). |
| `importing` | `bool get importing` | An import is being validated or copied (the import buttons are disabled meanwhile). |
| `importPlugin` | `Future<PluginImportResult> importPlugin(PluginImportSource source, String path)` | Validates the folder or zip at `path` and copies it into the user plugin folder; an `alreadyInstalled` result waits for `confirmReplace` or `cancelImport`; an installed plugin is listed and selected. |
| `confirmReplace` | `Future<PluginImportResult> confirmReplace(PluginImportResult pending)` | Replace: installs the pending plugin over the installed copy. |
| `cancelImport` | `void cancelImport(PluginImportResult pending)` | Cancel: drops what the pending import staged. |
| `processOf` / `processFor` | `PluginProcessSupervisor? Function(String name)? processOf` | A plugin's process supervisor (the editor wires `pluginProcesses.supervisorOf`); null for an in-process plugin. |
| `restartProcess` | `Future<void> restartProcess(String name)` | Restart in the Process section. |
| `runsInEditorProcess` / `runsInEditor` / `onSetRunInEditorProcess` / `setRunInEditorProcess` | `Future<void> setRunInEditorProcess(String name, bool inEditorProcess)` | The "Run in editor process (debugging)" switch (the editor wires `EditorViewModel.pluginRunsInEditorProcess` / `setPluginRunsInEditorProcess`); `switchingIsolation` while it applies. |
| `isPluginLoaded` | `bool Function(String name)? isPluginLoaded` | Whether this editor session registered a plugin (the editor wires `EditorViewModel.isPluginLoaded`); the removal dialog says it stays active until restart. |
| `removerFactory` | `PluginRemover Function()? removerFactory` | Builds the `PluginRemover` for one removal (tests point it at temp data and Marketplace folders). |
| `removing` | `bool get removing` | A removal is running (Remove is disabled meanwhile). |
| `planRemoval` | `PluginRemovalPlan planRemoval(PluginEntry entry)` | What removing a user or project plugin deletes and changes, before anything is deleted; `ArgumentError` for a built-in. |
| `removePlugin` | `Future<PluginRemovalResult> removePlugin(PluginRemovalPlan plan, {bool deleteData = false})` | Removes it (with its saved data when asked); once the folder is gone an enabled plugin is disabled with its dependents (cascade), the roots are rescanned and the selection moves to the plugin of the same name that comes back, else the neighbour. A removal that stopped changes nothing in the project. |

## `lib/ui/features/plugin_manager/views/plugin_import_dialogs.dart`

| Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `startPluginImport` | `Future<void> startPluginImport(BuildContext context, PluginManagerViewModel vm, PluginImportSource source)` | Import from Folder / Import from Zip: picks, imports, asks Replace / Cancel (`plugin_import_replace_dialog`) for a plugin already in the user folder, then shows the result (`plugin_import_done_dialog`, or `plugin_import_error` listing every problem). |

## `lib/ui/features/plugin_manager/services/plugin_importer.dart`

### `class PluginImporter`

Validates a plugin folder or plugin package zip and copies it into the user plugin folder (see [Importing a plugin](#importing-a-plugin)).

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `PluginImporter` | `PluginImporter({Directory? userPluginDir, Directory? stagingRoot, List<LuminaPluginDescriptor> existing = const []})` | The target folder (default `UserPluginDir.resolve()`), where a zip is extracted first (default the system temp), and the scanned plugins, for name conflicts. |
| `inspectFolder` / `inspectZip` | `Future<PluginImportResult> inspectFolder(String path)` | Validates without writing into the user folder: `ready` with a `PluginImportCandidate`, or `invalid` with every problem. A zip is extracted into a staging folder. |
| `install` | `Future<PluginImportResult> install(PluginImportCandidate candidate, {bool replace = false})` | Copies the candidate to `<user plugin dir>/<name>/` through `FolderInstall.replace`: `installed`, `alreadyInstalled` (unless `replace`), `conflict` (a project plugin of that name) or `failed` (the previous copy restored). |
| `importFolder` / `importZip` | `Future<PluginImportResult> importFolder(String path)` | Inspect, then install. |
| `discard` / `discardCandidate` | `void discard(PluginImportResult result)` | Removes what a zip import staged (Cancel). |

`PluginImportSource` is `folder` or `zip`; `PluginImportStatus` is `ready`, `installed`, `alreadyInstalled`, `conflict`, `invalid` or `failed`; `PluginImportResult` carries the status, the candidate, `installedDir`, `existingDir`, `messages` and `warnings`.

## `lib/ui/core/services/folder_install.dart`

### `class FolderInstall`

Transactional folder installs, shared by the Marketplace installer and the plugin import.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `replace` | `T replace<T>(Directory dest, T Function() write, {String tag = 'previous'})` | Sets an existing `dest` aside (`.<name>.<tag>`), runs `write`, then drops the old copy, or restores it if `write` throws. |
| `moveAside` / `dropAside` / `restore` | `Directory? moveAside(Directory dest, {String tag})` | The three steps of `replace`, for callers that do more inside the transaction. |
| `copyTree` / `copyFiles` | `void copyTree(Directory from, Directory to)` | Copies a folder, or a map of relative path → file. |
| `remove` | `FolderRemoval remove(Directory dir, {String tag = 'removing'})` | Removes a folder without leaving half of it: a symbolic link or junction is deleted as a link (never followed); a folder is renamed to `.<name>.<tag>` and then deleted, so a failed rename (a locked file) removes nothing. `FolderRemoval` has `removed`, `link`, `leftovers` (files the set-aside folder kept), `error` and `complete`. |
| `describe` | `String describe(FileSystemException e)` | A file-system error in one line (OS message and path). |

## `lib/ui/features/plugin_manager/views/plugin_remove_dialog.dart`

| Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `confirmPluginRemoval` | `void confirmPluginRemoval(BuildContext context, PluginManagerViewModel vm, PluginEntry entry)` | The details pane's Remove: the confirmation (`plugin_remove_dialog`) listing what will be deleted (see [Removing a plugin](#removing-a-plugin)), the data checkbox (`plugin_remove_data`), Cancel (`plugin_remove_cancel`) / Remove (`plugin_remove_confirm`); a removal that did not finish keeps it open with what was and was not removed (`plugin_remove_error`, Close `plugin_remove_close`). |
| `formatPluginBytes` | `String formatPluginBytes(int bytes)` | B / KB / MB / GB. |

## `lib/ui/features/plugin_manager/services/plugin_remover.dart`

### `class PluginRemover`

Removes a user or project plugin from disk; never a built-in.

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `PluginRemover` | `PluginRemover({Directory? pluginDataDir, MarketplaceInstallDirs? marketplaceDirs})` | The per-user plugin data folder (default `PluginDataDir.resolve()`) and the Marketplace's install folders (default `MarketplaceInstallDirs.resolve()`). |
| `plan` | `PluginRemovalPlan plan(PluginEntry entry, {required List<PluginEntry> entries, required List<PluginScanRoot> roots, String? projectDir, bool loaded = false})` | What removing it deletes: folder, link target, files, bytes, enabled state and enabled dependents, Marketplace record, the plugin of the same name that comes back, existing data folders. `ArgumentError` for a built-in. |
| `remove` | `PluginRemovalResult remove(PluginRemovalPlan plan, {bool deleteData = false})` | Deletes the folder (`FolderInstall.remove`, or `MarketplaceInstaller.removeInstall` for a Marketplace install), then the data folders when asked. Changes nothing in the project. |

`PluginRemovalPlan` (with `toJson`, the `remove_plugin` dry run) carries `name`, `displayName`, `origin`, `pluginDir`, `linkTarget`, `fileCount`, `bytes`, `enabled`, `contentOnly`, `dependents`, `loaded`, `marketplaceRecord`, `revealedOrigin` / `revealedDir`, `data` (`PluginDataFolder`: `kind` user / project, `dir`, `fileCount`, `bytes`) and `projectDir`. `PluginRemovalResult` has `removed`, `removedPaths`, `notRemoved` (`<path>: <reason>`), `disabled` and `restartRequired`.

---

[Previous: Launcher and details](launcher-and-details.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Source control](source-control.md)
