[English](../../en/lumina_editor_api/api-reference.md)

# API referansı

MCP tipleri dışında eklenti API'sinin tüm tipleri: `LuminaEditorPlugin` ve `LuminaEditorContext`, editör komutları, menüler ve menü öğeleri, toolbar ve slot butonları, panel tanımları ve `EditorPanels`, asset type handler'ları, importer'lar, details özelleştirmeleri, eklentilerin gördüğü haliyle açık level, editör teması, eklentiye özel depolama ve Project Settings bölümleri. Dosya yolları `lumina_editor_api/` paket dizinine görelidir.

**Bu sayfada:**

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

**Yapıcı Metotlar (Constructors):**

- `const EditorToolbarButton({required this.id, required this.tooltip, required this.icon, required this.command, required this.group,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `tooltip` | `final String tooltip` |  |
| `icon` | `final IconData icon` |  |
| `command` | `final EditorCommand command` |  |
| `group` | `final String group` |  |

### `enum PanelDefaultDock`

**Değerler:**

- `left`
- `right`
- `bottom`
- `floating`

### `class EditorPanelDescriptor`

**Yapıcı Metotlar (Constructors):**

- `const EditorPanelDescriptor({required this.id, required this.title, required this.icon, required this.builder, this.defaultDock = PanelDefaultDock.left, this.defaultAlwaysVisible = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `icon` | `final IconData icon` |  |
| `builder` | `final Widget Function(BuildContext) builder` |  |
| `defaultDock` | `final PanelDefaultDock defaultDock` |  |
| `defaultAlwaysVisible` | `final bool defaultAlwaysVisible` | Bir `PanelDefaultDock.right` panelinin yalnızca level editöründe değil, her editör sekmesinde (sub-editor'ler dahil) görünüp görünmeyeceği; kullanıcı dock'un iğne butonuyla ya da Window menüsüyle seçene kadar geçerlidir. Kullanıcının seçimi editör yerleşimiyle kaydedilir; Reset Layout bu değere döner. İsteğe bağlı, varsayılanı `false`. |

### `class EditorTabDescriptor`

Bir eklentinin sağladığı tam sayfa çalışma alanı editör sekmesi.

**Yapıcı Metotlar (Constructors):**

- `const EditorTabDescriptor({required this.id, required this.title, this.icon = const IconData(0xe255, fontFamily: 'MaterialIcons'), required this.builder, this.contentDroppable = false, this.contentBrowserOpened = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` | Çalışma alanı sekmesi kimliği. |
| `title` | `final String title` | Sekme başlığında gösterilecek metin. |
| `icon` | `final IconData icon` | Sekme ikonu. |
| `builder` | `final Widget Function(BuildContext context) builder` | Sekme gövdesi için widget kurucusu. |
| `contentDroppable` | `final bool contentDroppable` | Bu sekmenin Content Browser'dan sürüklenen varlıkları kabul edip etmeyeceği. İsteğe bağlı, varsayılanı `false`. |
| `contentBrowserOpened` | `final bool contentBrowserOpened` | Content Browser'ın sekmenin alt kısmında varsayılan olarak açık gelip gelmeyeceği. `false` olduğunda sol altta çekmece açma butonu gösterilir. İsteğe bağlı, varsayılanı `false`. |

### `class EditorAssetTypeHandler`

**Yapıcı Metotlar (Constructors):**

- `const EditorAssetTypeHandler({this.assetType, this.customTypeId, required this.displayName, required this.icon, required this.thumbnailBuilder, this.editorFactory, this.contentDroppable = false, this.contentBrowserOpened = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assetType` | `final AssetType? assetType` |  |
| `customTypeId` | `final String? customTypeId` |  |
| `displayName` | `final String displayName` |  |
| `icon` | `final IconData icon` |  |
| `thumbnailBuilder` | `final Future<Uint8List?> Function(LuminaAsset) thumbnailBuilder` |  |
| `editorFactory` | `final Widget Function(BuildContext, LuminaAsset)? editorFactory` |  |
| `contentDroppable` | `final bool contentDroppable` | Bu varlık alt editörünün Content Browser'dan sürüklenen varlıkları kabul edip etmeyeceği. İsteğe bağlı, varsayılanı `false`. |
| `contentBrowserOpened` | `final bool contentBrowserOpened` | Content Browser'ın editörün altında varsayılan olarak açık gelip gelmeyeceği. `false` olduğunda sol altta çekmece açma butonu gösterilir. İsteğe bağlı, varsayılanı `false`. |

### `class ImportContext`

**Yapıcı Metotlar (Constructors):**

- `const ImportContext({required this.targetDirectory})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `targetDirectory` | `final String targetDirectory` |  |

### `class ImportResult`

**Yapıcı Metotlar (Constructors):**

- `const ImportResult.success(this.assetPath)`
- `const ImportResult.failure(this.error)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `success` | `final bool success` |  |
| `assetPath` | `final String? assetPath` |  |
| `error` | `final String? error` |  |

### `class EditorImporter`

**Yapıcı Metotlar (Constructors):**

- `const EditorImporter({required this.extensions, required this.description, required this.import,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `extensions` | `final List<String> extensions` |  |
| `description` | `final String description` |  |
| `import` | `final Future<ImportResult> Function(File source, ImportContext ctx) import` |  |

### `class DetailsTarget`

**Yapıcı Metotlar (Constructors):**

- `const DetailsTarget({required this.target, required this.setProperty,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `target` | `final Object target` |  |
| `setProperty` | `final void Function(String name, dynamic value) setProperty` |  |

### `class DetailsCustomization`

**Yapıcı Metotlar (Constructors):**

- `const DetailsCustomization({required this.targetTypeId, required this.sectionTitle, required this.builder,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `targetTypeId` | `final String targetTypeId` |  |
| `sectionTitle` | `final String sectionTitle` |  |
| `builder` | `final Widget Function(BuildContext, DetailsTarget) builder` |  |

### `class EditorMenuItemOptions`

How a plugin menu item sits in its (sub)menu.

**Yapıcı Metotlar (Constructors):**

- `const EditorMenuItemOptions({this.order = 0, this.section, this.checked})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `order` | `final int order` | Sorts items within one (sub)menu; lower first, ties keep registration order. |
| `section` | `final String? section` | Items of different sections are separated by a divider; sections appear in the order their first item sorts. |
| `checked` | `final ValueListenable<bool>? checked` | When set, the item shows a check mark that follows the notifier. |

### `enum EditorMenuPlacement`

Where a plugin-owned top-level menu goes in the menu bar.

**Değerler:**

- `beforeWindow`: After the Plugins menu, before Window.
- `beforeHelp`: After Window, before Help.

### `class EditorMenuDescriptor`

A top-level menu a plugin owns. Fill it with `registerMenuItem('<title>/…', command)`. Built-in titles (File … Help, Plugins) and another plugin's title are refused.

**Yapıcı Metotlar (Constructors):**

- `const EditorMenuDescriptor({required this.id, required this.title, this.placement = EditorMenuPlacement.beforeWindow, this.order = 0,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `placement` | `final EditorMenuPlacement placement` |  |
| `order` | `final int order` | Sorts plugin menus sharing a placement. |

### `abstract class LuminaEditorContext`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `pluginName` | `String get pluginName` |  |
| `register` | `void register(LuminaEditorContext context)` | Bu eklentinin katkılarını [context]'e ekler. Editörün layout'u önce yüklenir, bu yüzden [LuminaEditorContext.panels] burada kayıtlı görünürlüğü verir. Hata fırlatırsa editör eklentinin kaydettiklerini geri alır, hatayı [pluginName] adıyla Output Log'a yazar ve Plugin Manager'da gösterir; diğer eklentiler ve editör çalışmaya devam eder. |
| `unregister` | `void unregister(LuminaEditorContext context)` | The last call a plugin gets, after [onEditorShutdown]. |
| `onProjectOpened` | `void onProjectOpened(EditorProjectInfo project)` | The editor has [project] open; called after [register]. |
| `onProjectClosing` | `Future<void> onProjectClosing() async` | The project is closing: finish pending writes. Bounded by a host timeout. |
| `onEditorShutdown` | `Future<void> onEditorShutdown() async` | The editor is exiting: stop child processes. Bounded by a host timeout; not called after a crash. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kCustomAssetTypeKey` | `const String kCustomAssetTypeKey` | `LuminaAsset.metadata` key a plugin asset type carries its [EditorAssetTypeHandler.customTypeId] under: an `.lmas` of `AssetType.unknown` with `metadata[kCustomAssetTypeKey] == customTypeId` is that plugin's asset, and the Content Browser opens it with the handler's `editorFactory`. |
| `kAssetPathMetadataKey` | `const String kAssetPathMetadataKey` | `LuminaAsset.metadata` key the host sets on the asset it passes to [EditorAssetTypeHandler.editorFactory]: the absolute path of the `.lmas`, so the editor can write the asset back. |

## `lib/src/editor_command.dart`

### `class EditorCommand`

**Yapıcı Metotlar (Constructors):**

- `const EditorCommand({required this.id, required this.label, this.icon, this.shortcutLabel = '', required this.canExecute, required this.execute,})`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const EditorComponentSnapshot({required this.id, required this.type, required this.name, this.enabled = true, this.properties = const {},})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `enabled` | `final bool enabled` |  |
| `properties` | `final Map<String, dynamic> properties` |  |

### `class EditorActorSnapshot`

A placed actor, as a plugin sees it.

The transform is the stored one, exactly as the Details panel shows it: centimetres, **Z up**. [meshAssetPath] is the absolute path of the mesh the actor renders (null for non-mesh actors). Snapshots are immutable copies: edit through [EditorLevelAccess].

**Yapıcı Metotlar (Constructors):**

- `const EditorActorSnapshot({required this.id, required this.name, required this.type, this.parentId, required this.location, required this.rotation, required thi...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const EditorComponentSpec({required this.type, required this.name, this.properties = const {},})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `properties` | `final Map<String, dynamic> properties` |  |

### `class EditorActorSpec`

An actor a plugin asks the host to place: same units and axes as [EditorActorSnapshot]. [id] is optional; the host assigns one otherwise. A `StaticMesh` spec with a [meshAssetPath] (absolute path of a `.glb` / `.lmas` under the project) renders that mesh in the viewport, plays in PIE and is generated into the game like any hand-placed mesh actor.

**Yapıcı Metotlar (Constructors):**

- `const EditorActorSpec({this.id, required this.name, required this.type, this.parentId, required this.location, this.rotation = const [0.0, 0.0, 0.0], this.scale...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `level` | `EditorLevelAccess get level` |  |
| `build3DViewport` | `Widget build3DViewport(BuildContext context, Plugin3DViewportOptions options)` | Kemik görselleştirme, etkileşimli eklem seçimi ve dönüştürme gizmosu içeren tam Filament 3D önizleme görünümünü yerleştirir. |
| `buildAssetPicker` | `Widget buildAssetPicker(BuildContext context, {...})` | Ana proje varlıklarına bağlı standart varlık seçici widget'ı. |

### `class Plugin3DViewportOptions`

[LuminaEditorHostContext.build3DViewport] metoduna aktarılan yapılandırma seçenekleri.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `title` | `final String title` | Görünüm alanı başlığı. |
| `meshPath` | `final String? meshPath` | İskeletli veya statik mesh varlığının proje göreli yolu (`.lmas`). |
| `glbBytes` | `final Uint8List? glbBytes` | Proje varlığı yerine doğrudan önizlenecek ham glTF/GLB ikili verisi. |
| `jointLocalPose` | `final Map<String, List<double>>? jointLocalPose` | Canlı kemik yerel dönüşümleri (4x4 matris veya pos+quat) ile duruş önizleme. |
| `overlayHUD` | `final Widget? overlayHUD` | 3D görünüm üzerine bindirilen özel Flutter widget katmanı. |
| `ghostSkeletons` | `final List<PluginGhostSkeleton>? ghostSkeletons` | Görsel referans veya anahtar kare noktaları için yarı saydam hayalet iskelet katmanları. |
| `showBones` | `final bool showBones` | Doğru olduğunda eklemleri camgöbeği noktalar ve aralarındaki kemikleri çizer. |
| `selectedBoneName` | `final String? selectedBoneName` | Amber rengi seçim halkası ile vurgulanan etkin seçili kemik/eklem. |
| `onBoneSelected` | `final void Function(String boneName)? onBoneSelected` | Kullanıcı 3D görünümde bir iskelet eklemine tıkladığında tetiklenen geri çağırma. |
| `onBoneMoved` | `final void Function(String boneName, List<double> newWorldPos, List<double> delta)? onBoneMoved` | Kullanıcı seçili ekleme bağlı 3D dönüştürme gizmosunu sürüklediğinde tetiklenen geri çağırma. |
| `showGizmo` | `final bool showGizmo` | Seçili eklem üzerinde 3D dönüştürme gizmosunun (RGB eksenleri + düzlemsel kuadlar) etkin olup olmadığı. |
| `visibleBoneNames` | `final Set<String>? visibleBoneNames` | Yalnızca görüntülenecek ve seçilecek kemik adları listesi; belirtildiğinde diğer eklemler (ör. yüz mimik veya düzeltme kemikleri) atlanır. |

## `lib/src/editor_panels.dart`

### `abstract class EditorPanels`

Opens, closes and observes plugin panels, reached through `LuminaEditorContext.panels`. A panel id is the `EditorPanelDescriptor.id` it was registered with. A `PanelDefaultDock.right` panel lives in the editor's right dock (closed until shown); other panels are tabs of the bottom panel.

**Yapıcı Metotlar (Constructors):**

- `const EditorPanels()`
- `factory EditorPanels.detached()`: A working in-memory implementation for a context with no editor behind it (tests, a bare registration context).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isVisible` | `bool isVisible(String panelId)` |  |
| `show` | `void show(String panelId, {bool focus = true})` | Opens [panelId]; with [focus] it becomes the dock's active tab. |
| `hide` | `void hide(String panelId)` |  |
| `toggle` | `void toggle(String panelId)` |  |
| `visibility` | `ValueListenable<bool> visibility(String panelId)` | Whether [panelId] is open, notified on every change, however it was made (the Window menu, the dock's close button, Reset Layout, a plugin call). One notifier per id; unknown ids are `false`. |

## `lib/src/editor_slot_button.dart`

### `enum EditorSlot`

A named place in the editor chrome a plugin button goes.

**Değerler:**

- `levelToolbarAfterBlueprints`: The level toolbar, right of the Blueprints ▾ dropdown.
- `levelToolbarEnd`: The level toolbar's right block, left of the Quality button.
- `statusBarLeft`: The status bar, after the actor counts.
- `statusBarRight`: The status bar, before the "Shaders compiled · Quality · … · RHI" text.

### `enum EditorTone`

A button's colour as a theme role, never a hex value: the host maps it to the active editor theme (`foreground`, `primary`, `logSuccess`, `logWarning`, `destructive`).

**Değerler:**

- `neutral`
- `primary`
- `success`
- `warning`
- `destructive`

### `class EditorButtonState`

What a slot button shows right now. The plugin replaces it through the button's [EditorSlotButton.state] notifier; only that button repaints.

**Yapıcı Metotlar (Constructors):**

- `const EditorButtonState({required this.icon, required this.tooltip, this.label, this.tone = EditorTone.neutral, this.enabled = true, this.active = false, this.b...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const EditorSlotButton({required this.id, required this.slot, required this.state, required this.command, this.order = 0, this.menu,})`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `String get name` | The active theme's name ("Lumina Dark", or a user theme). |
| `brightness` | `Brightness get brightness` |  |
| `tokens` | `Iterable<String> get tokens` | Every colour token the theme defines. |
| `color` | `Color color(String token)` | The active value of [token]; throws [ArgumentError] for an unknown one. |
| `radius` | `double get radius` |  |

### `abstract class EditorThemeHost`

Implemented by the context a running Lumina Studio hands to `LuminaEditorPlugin.register` (next to `LuminaEditorHostContext`): check `context is EditorThemeHost` and keep [theme] to paint plugin panels in the editor's colours. A bare test context has no theme.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `theme` | `EditorThemeAccess get theme` |  |

## `lib/src/plugin_storage.dart`

### `class PluginStorage`

A plugin's own data: JSON files in a per-user directory (settings, downloads) and, while a project is open, a per-project one (`<project>/.lumina/plugins/<pluginName>/`). Reached through `LuminaEditorContext.storage`.

**Yapıcı Metotlar (Constructors):**

- `PluginStorage({required this.userDir, this.projectDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `userDir` | `final Directory userDir` |  |
| `projectDir` | `final Directory? projectDir` | Null while no project is open. |
| `readJson` | `Future<Map<String, Object?>?> readJson(String name, {bool project = false}) async` | The JSON object stored as [name] (`<name>.json`), or null when there is none. A file that is not a JSON object is a [FormatException] naming it. |
| `writeJson` | `Future<void> writeJson(String name, Map<String, Object?> data, {bool project = false}) async` | Stores [data] as [name] (`<name>.json`): written to a temp file, then renamed over the old one, so a crash never leaves half a file. |

### `class EditorProjectInfo`

The open project, as a plugin's lifecycle hooks see it.

**Yapıcı Metotlar (Constructors):**

- `const EditorProjectInfo({required this.name, required this.dir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `dir` | `final String dir` | The project folder (holding `<name>.lmproject`). |

## `lib/src/project_settings_section.dart`

### `class ProjectSettingsSection`

A page a plugin adds to Project Settings ▸ Plugins. Its values live in the project manifest under `plugin_settings.<pluginName>` and go through the settings screen's Apply / Revert.

**Yapıcı Metotlar (Constructors):**

- `const ProjectSettingsSection({required this.id, required this.title, required this.builder, this.icon, this.keywords = const [],})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` | Unique within the plugin (e.g. `miniai`). |
| `title` | `final String title` | The row in the category list (e.g. "AI Assistant"). |
| `icon` | `final IconData? icon` |  |
| `keywords` | `final List<String> keywords` | Extra words the settings search matches. |
| `builder` | `final Widget Function(BuildContext context, PluginSettingsHandle settings) builder` | The page; edits go through [PluginSettingsHandle.set]. |

### `abstract class PluginSettingsHandle`

The plugin's settings as the Project Settings screen edits them (the unsaved working copy).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `values` | `Map<String, Object?> get values` |  |
| `get` | `T? get<T>(String key)` |  |
| `set` | `void set(String key, Object? value)` | Sets [key] to a JSON value; null removes it. A key that looks like a secret is refused: `.lmproject` is shared with the team. |
| `changes` | `Listenable get changes` | Fires after every [set]. |
| `checkKey` | `static void checkKey(String key, Object? value)` | Throws when [key] cannot go into the project manifest. |

### `class MapPluginSettingsHandle`

A [PluginSettingsHandle] over a plain map (tests, detached contexts).

**Yapıcı Metotlar (Constructors):**

- `MapPluginSettingsHandle([Map<String, Object?>? initial])`

## Eklenti Diyalogları ve İndirici (Plugin Dialogs & Downloader)

Lumina Studio, eklentiler için standartlaştırılmış bir modal diyalog altyapısı sunar. Diyaloglar durum çubuğuna (status bar) küçültme (minimize), canlı ilerleme durumu gösterimi, küçültme/geri yükleme döngülerinde görev verisi koruma ve arka planda dosya indirme desteği sağlar.

### `Future<T?> showPluginDialog<T>(...)`

Editör üzerinde durum çubuğuna küçültme ve kapatma butonları içeren modal bir [PluginDialogFrame] katmanı görüntüler. Eklentinin diyaloğu zaten açık veya küçültülmüş durumdaysa, [showPluginDialog] mükerrer controller oluşturmak yerine mevcut diyaloğu ekrana geri yükler (restore).

### `class PluginDialogController extends ChangeNotifier`

Tek bir eklenti diyaloğunun yaşam döngüsünü, durum metnini, ilerleme çubuğunu ve kalıcı görev verisini yönetir.

**Üyeler:**

- `isMinimized`: Diyaloğun o anda durum çubuğuna küçültülmüş olup olmadığını belirtir.
- `isClosed`: Diyaloğun tamamen kapatılıp kapatılmadığını belirtir.
- `statusText`: Diyalog alt çubuğunda ve durum çubuğu çipinde gösterilen dinamik durum mesajı.
- `progress`: İsteğe bağlı ilerleme oranı (`0.0` ile `1.0` arası).
- `taskData`: Küçültme/geri yükleme döngüleri boyunca korunan genel görev nesnesi (ör. aktif indirme görevi).
- `minimize()`: Diyaloğu durum çubuğuna küçültür.
- `restore(context)`: Diyaloğu yeniden ekrana geri yükler.
- `close()`: Diyaloğu tamamen kapatır ve [onCancelled] üzerinden aktif görevleri iptal eder.
- `updateStatus({String? text, double? progress, bool notify = true})`: Durum metnini ve ilerlemeyi canlı olarak günceller.

### `class PluginDialogManager extends ChangeNotifier`

Aktif ve küçültülmüş eklenti diyalog controller'larını takip eden genel kayıt defteri.

**Üyeler:**

- `findByPluginId(String pluginId)`: Bir eklentiye ait aktif veya küçültülmüş controller'ı arar.
- `minimizedDialogs`: Durum çubuğunda küçültülmüş olan controller'ların değiştirilemez listesi.
- `activeDialogs`: Kapatılmamış olan tüm controller'ların değiştirilemez listesi.

### `class PluginDownloader`

SHA-256 doğrulaması, yetkilendirme başlıkları (ör. Hugging Face tokenları), boş disk alanı denetimi ve akışlı (streaming) ilerleme güncellemelerini destekleyen HTTP dosya indiricisi.

**Üyeler:**

- `download(...)`: Geçerli dosyayı ve genel indirme ilerlemesini bildiren bir [PluginDownloadProgress] nesneleri akışı yayar.
- `cancel()`: Aktif indirme isteğini iptal eder ve bağlantıları temiz biçimde kapatır.

---

[Önceki: lumina_editor_api](index.md) | [Üst: lumina_editor_api](index.md) | [Sonraki: MCP araçları API'si](mcp.md)
