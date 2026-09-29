[Türkçe](../../tr/lumina_ui/plugin-manager.md)

# Plugin manager

The Plugin Manager window, which lists, enables and disables plugins, and the New Plugin wizard, which generates a plugin package from a template. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/plugin_manager/views/new_plugin_wizard.dart`](#libuifeaturesplugin_managerviewsnew_plugin_wizarddart)
- [`lib/ui/features/plugin_manager/views/plugin_manager_view.dart`](#libuifeaturesplugin_managerviewsplugin_manager_viewdart)
- [`lib/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart`](#libuifeaturesplugin_managerview_modelsplugin_manager_view_modeldart)

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

---

[Previous: Launcher and details](launcher-and-details.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Source control](source-control.md)
