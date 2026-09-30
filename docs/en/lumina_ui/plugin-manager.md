[Türkçe](../../tr/lumina_ui/plugin-manager.md)

# Plugin manager

The Plugin Manager window, which lists, enables and disables plugins, and the New Plugin wizard, which generates a plugin package from a template. File paths are relative to the `lumina_ui/` package directory.

## Built-in plugins

**BUILT-IN** lists the plugins that ship with the engine: the plugin packages the engine workspace resolved (`lumina_plugin_pcg` and `lumina_plugin_miniai` from the plugins repository, pinned by commit as `lumina_ui` dev dependencies), found through `.dart_tool/package_config.json` by `editorPluginScanRoots` (`lib/ui/core/services/user_plugin_dir.dart`). In a source workspace they are the sibling `plugins` checkout (`pubspec_overrides.yaml`); in a release checkout, the git checkouts `flutter pub get` put in the pub cache. A built-in is enabled and disabled per project with its switch, like any other plugin: the switch writes the project's `enabled_plugins` in its `.lmproject`, the card shows **Restart required** and the restart banner appears, and the project's editor host is regenerated to depend on it (by the same git dependency the engine pinned; see [Plugins](../plugins/index.md)), so **Restart Editor** rebuilds the project editor with it. The built-ins ship off: their manifests do not set `enabled_by_default`, since each is a code plugin that needs a project editor rebuild. A built-in cannot be removed or edited from the Plugin Manager (it belongs to the engine checkout; the details pane says so); a user plugin of the same name (for example a newer version imported from a zip) takes its place.

## Importing a plugin

**Import from Folder** and **Import from Zip**, next to **New Plugin** in the list header, install a plugin into the per-user plugin folder (`UserPluginDir.resolve()`, where the Marketplace installs plugins too) by copying it; a plugin is never linked from where it was picked. Both open the system picker and validate before anything is written:

- the `<name>.lmplugin` manifest, by the marketplace's package rules (`checkPluginPackage` from `lumina_marketplace_shared`) and by the editor's own loader (`PluginRepository.loadInternal`);
- **a zip** is read as the marketplace plugin package format that `tool/pack_plugin.dart` writes: every entry must be a safe relative path (`isSafeRelativePath`: no `..`, no absolute path or drive, no backslash), no symbolic links, only files on the marketplace's allow-list, no duplicates, at most 10,000 entries and 1 GB unpacked; a single top folder, when present, must be named after the plugin; license and changelog problems refuse the zip;
- **a folder** is copied without `.dart_tool/`, `.git/`, `.idea/`, `.vscode/`, `node_modules/`, a root `build/` or `coverage/`, and `pubspec_overrides.yaml`; symbolic links are left out with a warning; license and changelog findings are only warnings.

A plugin of the same name already in the user folder asks **Replace / Cancel** (Replace swaps the whole folder; the previous copy comes back if writing fails). A project plugin of the same name refuses the import, because it would hide the user copy. A built-in of the same name is replaced for every project by the user copy, with a warning. After an install the plugin roots are rescanned and the new plugin is selected; enabling it is still a separate step.

**On this page:**

- [`lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`](#libuifeaturesplugin_managerviewsnew_plugin_wizarddart)
- [`lib/ui/features/plugin_manager/views/plugin_manager_view.dart`](#libuifeaturesplugin_managerviewsplugin_manager_viewdart)
- [`lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`](#libuifeaturesplugin_managerview_modelsplugin_manager_view_modeldart)
- [`lib/ui/features/plugin_manager/views/plugin_import_dialogs.dart`](#libuifeaturesplugin_managerviewsplugin_import_dialogsdart)
- [`lib/ui/features/plugin_manager/services/plugin_importer.dart`](#libuifeaturesplugin_managerservicesplugin_importerdart)
- [`lib/ui/core/services/folder_install.dart`](#libuicoreservicesfolder_installdart)

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

---

[Previous: Launcher and details](launcher-and-details.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Source control](source-control.md)
