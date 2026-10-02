[Türkçe](../../tr/lumina_editor_api/api-reference.md)

# API reference

Every type of the plugin API except the MCP types: `LuminaEditorPlugin` and `LuminaEditorContext`, editor commands, menus and menu items, toolbar and slot buttons, panel descriptors and `EditorPanels`, asset type handlers, importers, details customizations, the open level as plugins see it, the editor theme, per-plugin storage and Project Settings sections. File paths are relative to the `lumina_editor_api/` package directory.

**On this page:**

- [`lib/src/api_types.dart`](#libsrcapi_typesdart)
- [`lib/src/editor_command.dart`](#libsrceditor_commanddart)
- [`lib/src/editor_level.dart`](#libsrceditor_leveldart)
- [`lib/src/editor_panels.dart`](#libsrceditor_panelsdart)
- [`lib/src/editor_slot_button.dart`](#libsrceditor_slot_buttondart)
- [`lib/src/editor_theme.dart`](#libsrceditor_themedart)
- [`lib/src/plugin_storage.dart`](#libsrcplugin_storagedart)
- [`lib/src/project_settings_section.dart`](#libsrcproject_settings_sectiondart)

## `lib/src/api_types.dart`

### `class EditorToolbarButton`

A static icon button. The host turns it into an [EditorSlotButton]: [group] names an [EditorSlot] (`'levelToolbarAfterBlueprints'`, …), any other group goes to [EditorSlot.levelToolbarEnd]. Prefer [EditorSlotButton] for a label, tone, badge or live state.

**Constructors:**

- `const EditorToolbarButton({required this.id, required this.tooltip, required this.icon, required this.command, required this.group,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `tooltip` | `final String tooltip` |  |
| `icon` | `final IconData icon` |  |
| `command` | `final EditorCommand command` |  |
| `group` | `final String group` |  |

### `enum PanelDefaultDock`

**Values:**

- `left`
- `right`
- `bottom`
- `floating`

### `class EditorPanelDescriptor`

**Constructors:**

- `const EditorPanelDescriptor({required this.id, required this.title, required this.icon, required this.builder, this.defaultDock = PanelDefaultDock.left, this.defaultAlwaysVisible = false,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `icon` | `final IconData icon` |  |
| `builder` | `final Widget Function(BuildContext) builder` |  |
| `defaultDock` | `final PanelDefaultDock defaultDock` |  |
| `defaultAlwaysVisible` | `final bool defaultAlwaysVisible` | Whether a `PanelDefaultDock.right` panel shows in every editor tab (the sub-editors included) rather than in the level editor only, until the user chooses with the dock's pin button or the Window menu. The user's choice is saved with the editor layout; Reset Layout returns to this. Optional, `false` by default. |

### `class EditorAssetTypeHandler`

**Constructors:**

- `const EditorAssetTypeHandler({this.assetType, this.customTypeId, required this.displayName, required this.icon, required this.thumbnailBuilder, this.editorFacto...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetType` | `final AssetType? assetType` |  |
| `customTypeId` | `final String? customTypeId` |  |
| `displayName` | `final String displayName` |  |
| `icon` | `final IconData icon` |  |
| `thumbnailBuilder` | `final Future<Uint8List?> Function(LuminaAsset) thumbnailBuilder` |  |
| `editorFactory` | `final Widget Function(BuildContext, LuminaAsset)? editorFactory` |  |

### `class ImportContext`

**Constructors:**

- `const ImportContext({required this.targetDirectory})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targetDirectory` | `final String targetDirectory` |  |

### `class ImportResult`

**Constructors:**

- `const ImportResult.success(this.assetPath)`
- `const ImportResult.failure(this.error)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `success` | `final bool success` |  |
| `assetPath` | `final String? assetPath` |  |
| `error` | `final String? error` |  |

### `class EditorImporter`

**Constructors:**

- `const EditorImporter({required this.extensions, required this.description, required this.import,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `extensions` | `final List<String> extensions` |  |
| `description` | `final String description` |  |
| `import` | `final Future<ImportResult> Function(File source, ImportContext ctx) import` |  |

### `class DetailsTarget`

**Constructors:**

- `const DetailsTarget({required this.target, required this.setProperty,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `target` | `final Object target` |  |
| `setProperty` | `final void Function(String name, dynamic value) setProperty` |  |

### `class DetailsCustomization`

**Constructors:**

- `const DetailsCustomization({required this.targetTypeId, required this.sectionTitle, required this.builder,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targetTypeId` | `final String targetTypeId` |  |
| `sectionTitle` | `final String sectionTitle` |  |
| `builder` | `final Widget Function(BuildContext, DetailsTarget) builder` |  |

### `class EditorMenuItemOptions`

How a plugin menu item sits in its (sub)menu.

**Constructors:**

- `const EditorMenuItemOptions({this.order = 0, this.section, this.checked})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `order` | `final int order` | Sorts items within one (sub)menu; lower first, ties keep registration order. |
| `section` | `final String? section` | Items of different sections are separated by a divider; sections appear in the order their first item sorts. |
| `checked` | `final ValueListenable<bool>? checked` | When set, the item shows a check mark that follows the notifier. |

### `enum EditorMenuPlacement`

Where a plugin-owned top-level menu goes in the menu bar.

**Values:**

- `beforeWindow`: After the Plugins menu, before Window.
- `beforeHelp`: After Window, before Help.

### `class EditorMenuDescriptor`

A top-level menu a plugin owns. Fill it with `registerMenuItem('<title>/…', command)`. Built-in titles (File … Help, Plugins) and another plugin's title are refused.

**Constructors:**

- `const EditorMenuDescriptor({required this.id, required this.title, this.placement = EditorMenuPlacement.beforeWindow, this.order = 0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `placement` | `final EditorMenuPlacement placement` |  |
| `order` | `final int order` | Sorts plugin menus sharing a placement. |

### `abstract class LuminaEditorContext`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `registerMenuItem` | `void registerMenuItem(String menuPath, EditorCommand command, {EditorMenuItemOptions options = const EditorMen...` | Adds [command] to the menu bar at [menuPath]. A plugin registers under `Plugins/<Group>/…` (the Plugins menu) or under the title of a menu it registered with [registerMenu]; built-in menus (File, Edit, View, Build, Debug, Window, Help) refuse plugin items. Legacy `Tools/…` paths are moved to `Plugins/…` with a deprecation warning. |
| `registerMenu` | `void registerMenu(EditorMenuDescriptor menu)` | Registers a top-level menu the plugin owns. |
| `registerToolbarButton` | `void registerToolbarButton(EditorToolbarButton button)` |  |
| `registerSlotButton` | `void registerSlotButton(EditorSlotButton button)` | Puts a button with live state in a named slot of the level toolbar or the status bar. |
| `panels` | `EditorPanels get panels` | Opens, closes and observes the plugin's panels. Safe to keep from `register`. |
| `mcp` | `EditorMcp get mcp` | The editor's MCP tools: register this plugin's tools, list and call any tool in process. Safe to keep from `register`. |
| `storage` | `PluginStorage get storage` | This plugin's JSON store, per user and per open project. |
| `registerProjectSettingsSection` | `void registerProjectSettingsSection(ProjectSettingsSection section)` | Adds a page to Project Settings ▸ Plugins. |
| `pluginSettings` | `ValueListenable<Map<String, Object?>> get pluginSettings` | This plugin's applied project settings (`.lmproject` `plugin_settings.<pluginName>`); updates when Project Settings applies. |
| `registerPanel` | `void registerPanel(EditorPanelDescriptor panel)` |  |
| `registerAssetType` | `void registerAssetType(EditorAssetTypeHandler handler)` |  |
| `registerImporter` | `void registerImporter(EditorImporter importer)` |  |
| `registerDetailsCustomization` | `void registerDetailsCustomization(DetailsCustomization c)` |  |
| `registerConsoleCommand` | `void registerConsoleCommand(String name, String help, void Function(List<String> args) handler)` |  |

### `abstract class LuminaEditorPlugin`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `pluginName` | `String get pluginName` |  |
| `register` | `void register(LuminaEditorContext context)` | Adds this plugin's contributions to [context]. The editor's layout is loaded first, so [LuminaEditorContext.panels] reports the saved visibility here. If it throws, the editor drops what it registered, logs the error under [pluginName] and shows it in the Plugin Manager; the other plugins and the editor go on. |
| `unregister` | `void unregister(LuminaEditorContext context)` | The last call a plugin gets, after [onEditorShutdown]. |
| `onProjectOpened` | `void onProjectOpened(EditorProjectInfo project)` | The editor has [project] open; called after [register]. |
| `onProjectClosing` | `Future<void> onProjectClosing() async` | The project is closing: finish pending writes. Bounded by a host timeout. |
| `onEditorShutdown` | `Future<void> onEditorShutdown() async` | The editor is exiting: stop child processes. Bounded by a host timeout; not called after a crash. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kCustomAssetTypeKey` | `const String kCustomAssetTypeKey` | `LuminaAsset.metadata` key a plugin asset type carries its [EditorAssetTypeHandler.customTypeId] under: an `.lmas` of `AssetType.unknown` with `metadata[kCustomAssetTypeKey] == customTypeId` is that plugin's asset, and the Content Browser opens it with the handler's `editorFactory`. |
| `kAssetPathMetadataKey` | `const String kAssetPathMetadataKey` | `LuminaAsset.metadata` key the host sets on the asset it passes to [EditorAssetTypeHandler.editorFactory]: the absolute path of the `.lmas`, so the editor can write the asset back. |

## `lib/src/editor_command.dart`

### `class EditorCommand`

**Constructors:**

- `const EditorCommand({required this.id, required this.label, this.icon, this.shortcutLabel = '', required this.canExecute, required this.execute,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `label` | `final String label` |  |
| `icon` | `final IconData? icon` |  |
| `shortcutLabel` | `final String shortcutLabel` |  |
| `canExecute` | `final bool Function() canExecute` |  |
| `execute` | `final FutureOr<void> Function(BuildContext?) execute` |  |

## `lib/src/editor_level.dart`

### `class EditorComponentSnapshot`

One component of a placed actor, as a plugin sees it.

**Constructors:**

- `const EditorComponentSnapshot({required this.id, required this.type, required this.name, this.enabled = true, this.properties = const {},})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `enabled` | `final bool enabled` |  |
| `properties` | `final Map<String, dynamic> properties` |  |

### `class EditorActorSnapshot`

A placed actor, as a plugin sees it.

The transform is the stored one, exactly as the Details panel shows it: centimetres, **Z up**. [meshAssetPath] is the absolute path of the mesh the actor renders (null for non-mesh actors). Snapshots are immutable copies: edit through [EditorLevelAccess].

**Constructors:**

- `const EditorActorSnapshot({required this.id, required this.name, required this.type, this.parentId, required this.location, required this.rotation, required thi...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `type` | `final String type` |  |
| `parentId` | `final String? parentId` |  |
| `location` | `final List<double> location` |  |
| `rotation` | `final List<double> rotation` |  |
| `scale` | `final List<double> scale` |  |
| `isVisible` | `final bool isVisible` |  |
| `meshAssetPath` | `final String? meshAssetPath` |  |
| `components` | `final List<EditorComponentSnapshot> components` |  |
| `componentOfType` | `EditorComponentSnapshot? componentOfType(String type)` | The first component of [type], or null. |

### `class EditorComponentSpec`

A component a plugin asks the host to attach to a new actor.

**Constructors:**

- `const EditorComponentSpec({required this.type, required this.name, this.properties = const {},})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `properties` | `final Map<String, dynamic> properties` |  |

### `class EditorActorSpec`

An actor a plugin asks the host to place: same units and axes as [EditorActorSnapshot]. [id] is optional; the host assigns one otherwise. A `StaticMesh` spec with a [meshAssetPath] (absolute path of a `.glb` / `.lmas` under the project) renders that mesh in the viewport, plays in PIE and is generated into the game like any hand-placed mesh actor.

**Constructors:**

- `const EditorActorSpec({this.id, required this.name, required this.type, this.parentId, required this.location, this.rotation = const [0.0, 0.0, 0.0], this.scale...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String? id` |  |
| `name` | `final String name` |  |
| `type` | `final String type` |  |
| `parentId` | `final String? parentId` |  |
| `location` | `final List<double> location` |  |
| `rotation` | `final List<double> rotation` |  |
| `scale` | `final List<double> scale` |  |
| `meshAssetPath` | `final String? meshAssetPath` |  |
| `components` | `final List<EditorComponentSpec> components` |  |

### `abstract class EditorLevelAccess`

The open level, as the host exposes it to plugins.

Every edit is an undoable editor transaction and marks the level dirty, exactly like the same edit made through the Outliner or the Details panel; nothing here bypasses the host's transaction, dirty-flag or auto-save path.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDirPath` | `String get projectDirPath` | Absolute path of the open project's directory. |
| `activeLevelPath` | `String get activeLevelPath` | The active level's `.lmas`, relative to [projectDirPath] (`contents/levels/L_Main.lmas`). |
| `changes` | `Listenable get changes` | Notifies after any change to the level (actors, selection, save). |
| `actors` | `List<EditorActorSnapshot> get actors` | Every actor in the level, in outliner order. |
| `selectedActorIds` | `List<String> get selectedActorIds` | The selected actors' ids, in selection order. |
| `addActors` | `Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label})` | Places [specs] as one undoable transaction and returns their ids, in order. Mesh actors have their geometry loaded before they are added. |
| `runTransaction` | `Future<T> runTransaction<T>(String label, Future<T> Function() body)` | Runs [body] so that every level edit it makes is one undo step labelled [label]: an assistant turn, a scatter, a batch rename. A call inside another joins it. |
| `undoTopLabel` | `String? get undoTopLabel` | The label of the step Edit ▸ Undo would revert now, or null when there is none (e.g. an assistant's "Undo this turn"). |
| `undoIfTop` | `bool undoIfTop(String label)` | Undoes the newest step only when its label is [label]; false (nothing changes) when another step is on top or nothing can be undone. |
| `removeActors` | `void removeActors(Iterable<String> ids, {String? label})` | Removes the actors with [ids] (and their children) as one undoable transaction. |
| `setComponentProperty` | `void setComponentProperty(String actorId, String componentType, String propertyId, Object? value, {String? lab...` | Sets [propertyId] on the first component of [componentType] on the actor with [actorId], as an undoable transaction. |
| `selectActors` | `void selectActors(Iterable<String> ids)` | Selects exactly [ids]. |
| `saveLevel` | `Future<void> saveLevel()` | Saves the level to disk and regenerates the game's level code, the same path as File → Save Level. |
| `openAssetEditor` | `void openAssetEditor(String assetPath)` | Opens the asset at [assetPath] (absolute, or relative to [projectDirPath]) in its editor: a plugin asset type opens through the handler registered with [LuminaEditorContext.registerAssetType]. |
| `openLevel` | `Future<bool> openLevel(String relativePath, {bool show = true})` | Opens the level at [relativePath] (project-relative, e.g. a level the plugin wrote under `contents/levels/`) in the viewport and the Outliner, like File → Open Level. The open level's unsaved changes are saved first. When [relativePath] is already the open level it is read again from disk, so a plugin that rewrote the file sees the new contents; call [saveLevel] before rewriting it to keep its unsaved changes. [show] brings the level viewport to the front. Returns false, changing nothing, when there is no such file or Play-In-Editor runs. |
| `log` | `void log(String message, {String level = 'info', String source = 'Plugin'})` | Writes a line to the editor's Output Log. |

### `abstract class LuminaEditorHostContext`

The context a running Lumina Studio hands to [LuminaEditorPlugin.register]: the seven extension points plus the open level.

A bare [LuminaEditorContext] (a plugin's own unit test, a registration smoke) has no level, so plugins that edit the level check `context is LuminaEditorHostContext` and keep the [level] for later.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `level` | `EditorLevelAccess get level` |  |

## `lib/src/editor_panels.dart`

### `abstract class EditorPanels`

Opens, closes and observes plugin panels, reached through `LuminaEditorContext.panels`. A panel id is the `EditorPanelDescriptor.id` it was registered with. A `PanelDefaultDock.right` panel lives in the editor's right dock (closed until shown); other panels are tabs of the bottom panel.

**Constructors:**

- `const EditorPanels()`
- `factory EditorPanels.detached()`: A working in-memory implementation for a context with no editor behind it (tests, a bare registration context).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isVisible` | `bool isVisible(String panelId)` |  |
| `show` | `void show(String panelId, {bool focus = true})` | Opens [panelId]; with [focus] it becomes the dock's active tab. |
| `hide` | `void hide(String panelId)` |  |
| `toggle` | `void toggle(String panelId)` |  |
| `visibility` | `ValueListenable<bool> visibility(String panelId)` | Whether [panelId] is open, notified on every change, however it was made (the Window menu, the dock's close button, Reset Layout, a plugin call). One notifier per id; unknown ids are `false`. |

## `lib/src/editor_slot_button.dart`

### `enum EditorSlot`

A named place in the editor chrome a plugin button goes.

**Values:**

- `levelToolbarAfterBlueprints`: The level toolbar, right of the Blueprints ▾ dropdown.
- `levelToolbarEnd`: The level toolbar's right block, left of the Quality button.
- `statusBarLeft`: The status bar, after the actor counts.
- `statusBarRight`: The status bar, before the "Shaders compiled · Quality · … · RHI" text.

### `enum EditorTone`

A button's colour as a theme role, never a hex value: the host maps it to the active editor theme (`foreground`, `primary`, `logSuccess`, `logWarning`, `destructive`).

**Values:**

- `neutral`
- `primary`
- `success`
- `warning`
- `destructive`

### `class EditorButtonState`

What a slot button shows right now. The plugin replaces it through the button's [EditorSlotButton.state] notifier; only that button repaints.

**Constructors:**

- `const EditorButtonState({required this.icon, required this.tooltip, this.label, this.tone = EditorTone.neutral, this.enabled = true, this.active = false, this.b...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `label` | `final String? label` | Text beside the icon; null shows the icon only. |
| `icon` | `final IconData icon` |  |
| `tooltip` | `final String tooltip` |  |
| `tone` | `final EditorTone tone` |  |
| `enabled` | `final bool enabled` | False disables the button (so does the command's `canExecute`). |
| `active` | `final bool active` | The pressed / toggled-on look, e.g. while the plugin's panel is open. |
| `badge` | `final String? badge` | A short pill at the top-right ("3", "●"); null shows none. |
| `busy` | `final bool busy` | A spinner in place of the icon, e.g. while a model loads. The button stays clickable. |
| `copyWith` | `EditorButtonState copyWith({String? label, IconData? icon, String? tooltip, EditorTone? tone, bool? enabled, b...` | A copy with the given fields replaced. [label] and [badge] cannot be cleared here; use [withoutLabel] / [withoutBadge]. |
| `withoutLabel` | `EditorButtonState get withoutLabel` |  |
| `withoutBadge` | `EditorButtonState get withoutBadge` |  |

### `class EditorSlotButton`

A plugin button in a named [slot], registered with `LuminaEditorContext.registerSlotButton`. The host namespaces [id] as `<pluginName>.<id>` and refuses a second button with the same one.

**Constructors:**

- `const EditorSlotButton({required this.id, required this.slot, required this.state, required this.command, this.order = 0, this.menu,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `slot` | `final EditorSlot slot` |  |
| `order` | `final int order` | Sorts buttons within the slot; lower first, ties keep registration order. |
| `state` | `final ValueListenable<EditorButtonState> state` | The live look; the plugin keeps the notifier and updates it. |
| `command` | `final EditorCommand command` | Runs on click, unless [menu] is given. |
| `menu` | `final List<EditorCommand>? menu` | When set, a click opens a dropdown of these commands instead. |

## `lib/src/editor_theme.dart`

### `abstract class EditorThemeAccess`

The editor's active colour theme, read-only, so a plugin's panels and asset editors paint in the same colours as the host.

Tokens are the keys of the theme JSON — `background`, `card`, `cardHeader`, `rail`, `foreground`, `mutedForeground`, `primary`, `accent`, `destructive`, `warning`, `border`, the `pin*` Blueprint pin colours, `chart1`…`chart5`, … ([tokens] lists them). Listen to it to repaint when the user switches or edits the theme in Editor Preferences → Appearance. A plugin cannot change the theme.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `String get name` | The active theme's name ("Lumina Dark", or a user theme). |
| `brightness` | `Brightness get brightness` |  |
| `tokens` | `Iterable<String> get tokens` | Every colour token the theme defines. |
| `color` | `Color color(String token)` | The active value of [token]; throws [ArgumentError] for an unknown one. |
| `radius` | `double get radius` |  |

### `abstract class EditorThemeHost`

Implemented by the context a running Lumina Studio hands to `LuminaEditorPlugin.register` (next to `LuminaEditorHostContext`): check `context is EditorThemeHost` and keep [theme] to paint plugin panels in the editor's colours. A bare test context has no theme.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `theme` | `EditorThemeAccess get theme` |  |

## `lib/src/plugin_storage.dart`

### `class PluginStorage`

A plugin's own data: JSON files in a per-user directory (settings, downloads) and, while a project is open, a per-project one (`<project>/.lumina/plugins/<pluginName>/`). Reached through `LuminaEditorContext.storage`.

**Constructors:**

- `PluginStorage({required this.userDir, this.projectDir})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `userDir` | `final Directory userDir` |  |
| `projectDir` | `final Directory? projectDir` | Null while no project is open. |
| `readJson` | `Future<Map<String, Object?>?> readJson(String name, {bool project = false}) async` | The JSON object stored as [name] (`<name>.json`), or null when there is none. A file that is not a JSON object is a [FormatException] naming it. |
| `writeJson` | `Future<void> writeJson(String name, Map<String, Object?> data, {bool project = false}) async` | Stores [data] as [name] (`<name>.json`): written to a temp file, then renamed over the old one, so a crash never leaves half a file. |

### `class EditorProjectInfo`

The open project, as a plugin's lifecycle hooks see it.

**Constructors:**

- `const EditorProjectInfo({required this.name, required this.dir})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `dir` | `final String dir` | The project folder (holding `<name>.lmproject`). |

## `lib/src/project_settings_section.dart`

### `class ProjectSettingsSection`

A page a plugin adds to Project Settings ▸ Plugins. Its values live in the project manifest under `plugin_settings.<pluginName>` and go through the settings screen's Apply / Revert.

**Constructors:**

- `const ProjectSettingsSection({required this.id, required this.title, required this.builder, this.icon, this.keywords = const [],})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` | Unique within the plugin (e.g. `miniai`). |
| `title` | `final String title` | The row in the category list (e.g. "AI Assistant"). |
| `icon` | `final IconData? icon` |  |
| `keywords` | `final List<String> keywords` | Extra words the settings search matches. |
| `builder` | `final Widget Function(BuildContext context, PluginSettingsHandle settings) builder` | The page; edits go through [PluginSettingsHandle.set]. |

### `abstract class PluginSettingsHandle`

The plugin's settings as the Project Settings screen edits them (the unsaved working copy).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `values` | `Map<String, Object?> get values` |  |
| `get` | `T? get<T>(String key)` |  |
| `set` | `void set(String key, Object? value)` | Sets [key] to a JSON value; null removes it. A key that looks like a secret is refused: `.lmproject` is shared with the team. |
| `changes` | `Listenable get changes` | Fires after every [set]. |
| `checkKey` | `static void checkKey(String key, Object? value)` | Throws when [key] cannot go into the project manifest. |

### `class MapPluginSettingsHandle`

A [PluginSettingsHandle] over a plain map (tests, detached contexts).

**Constructors:**

- `MapPluginSettingsHandle([Map<String, Object?>? initial])`

---

[Previous: lumina_editor_api](index.md) | [Up: lumina_editor_api](index.md) | [Next: MCP tools API](mcp.md)
