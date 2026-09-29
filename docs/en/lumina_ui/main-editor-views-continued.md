[Türkçe](../../tr/lumina_ui/main-editor-views-continued.md)

# Main editor: views (continued)

Continuation of Main editor: views: the remaining public files under `lib/ui/features/main_editor/views/`. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/main_editor/views/about_dialog.dart`](#libuifeaturesmain_editorviewsabout_dialogdart)
- [`lib/ui/features/main_editor/views/affected_actors_note.dart`](#libuifeaturesmain_editorviewsaffected_actors_notedart)
- [`lib/ui/features/main_editor/views/content_browser_folder_tile.dart`](#libuifeaturesmain_editorviewscontent_browser_folder_tiledart)
- [`lib/ui/features/main_editor/views/content_browser_folder_tree.dart`](#libuifeaturesmain_editorviewscontent_browser_folder_treedart)
- [`lib/ui/features/main_editor/views/editor_slot_bar.dart`](#libuifeaturesmain_editorviewseditor_slot_bardart)
- [`lib/ui/features/main_editor/views/import_asset_folder_dialog.dart`](#libuifeaturesmain_editorviewsimport_asset_folder_dialogdart)
- [`lib/ui/features/main_editor/views/import_asset_options_dialog.dart`](#libuifeaturesmain_editorviewsimport_asset_options_dialogdart)
- [`lib/ui/features/main_editor/views/import_progress_panel.dart`](#libuifeaturesmain_editorviewsimport_progress_paneldart)
- [`lib/ui/features/main_editor/views/import_target_skeleton_select.dart`](#libuifeaturesmain_editorviewsimport_target_skeleton_selectdart)
- [`lib/ui/features/main_editor/views/import_textures_folder_row.dart`](#libuifeaturesmain_editorviewsimport_textures_folder_rowdart)
- [`lib/ui/features/main_editor/views/legacy_units_banner.dart`](#libuifeaturesmain_editorviewslegacy_units_bannerdart)
- [`lib/ui/features/main_editor/views/menu_tree_builder.dart`](#libuifeaturesmain_editorviewsmenu_tree_builderdart)
- [`lib/ui/features/main_editor/views/pie_blueprint_debug_panel.dart`](#libuifeaturesmain_editorviewspie_blueprint_debug_paneldart)
- [`lib/ui/features/main_editor/views/pie_debug_draw_layer.dart`](#libuifeaturesmain_editorviewspie_debug_draw_layerdart)
- [`lib/ui/features/main_editor/views/pie_mouse_capture_layer.dart`](#libuifeaturesmain_editorviewspie_mouse_capture_layerdart)
- [`lib/ui/features/main_editor/views/pie_widget_layer.dart`](#libuifeaturesmain_editorviewspie_widget_layerdart)
- [`lib/ui/features/main_editor/views/play_blocked_dialog.dart`](#libuifeaturesmain_editorviewsplay_blocked_dialogdart)
- [`lib/ui/features/main_editor/views/right_dock_widget.dart`](#libuifeaturesmain_editorviewsright_dock_widgetdart)
- [`lib/ui/features/main_editor/views/status_bar_engine_segment.dart`](#libuifeaturesmain_editorviewsstatus_bar_engine_segmentdart)
- [`lib/ui/features/main_editor/views/toolbar_priority_row.dart`](#libuifeaturesmain_editorviewstoolbar_priority_rowdart)

## `lib/ui/features/main_editor/views/about_dialog.dart`

### `class FilamentLogo`

Filament's logo in the variant that reads on the current theme: the light-on-dark mark on the dark themes, the dark mark on the light one (`assets/third_party/filament/`, Apache-2.0, unmodified artwork).

**Constructors:**

- `const FilamentLogo({super.key, required this.height})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `onDarkAsset` | `static const String onDarkAsset` |  |
| `onLightAsset` | `static const String onLightAsset` |  |
| `height` | `final double height` |  |

### `class AboutLuminaDialog`

**Constructors:**

- `const AboutLuminaDialog({super.key, required this.engineVersion, required this.onClose})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineVersion` | `final String engineVersion` |  |
| `onClose` | `final VoidCallback onClose` |  |
| `versionInfo` | `String versionInfo()` | What Copy version info puts on the clipboard. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `rhiLabel` | `String rhiLabel(String? gpu)` | The renderer the status bar and About name: `RHI: Vulkan · <gpu>`, the GPU the editor renders on. |
| `showAboutLuminaDialog` | `void showAboutLuminaDialog(BuildContext context, {required String engineVersion})` | Help ▸ About: Lumina's version, then what renders it — Filament's logo, version, material version and licence, read from the linked library through package:lumina. |

## `lib/ui/features/main_editor/views/affected_actors_note.dart`

### `class AffectedActorsNote`

The placed actors a delete will remove with the assets they reference, listed in the delete confirmations so nothing leaves the level unannounced. Renders nothing when no actor is affected.

**Constructors:**

- `const AffectedActorsNote({super.key, required this.actors})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `actors` | `final List<EditorActorNode> actors` |  |

## `lib/ui/features/main_editor/views/content_browser_folder_tile.dart`

### `class ContentBrowserFolderTile`

A subfolder tile at the top of the content browser grid: a click selects it, a double-click enters it, an asset dropped on it moves there, and its context menu offers Open, New Folder, Rename, Delete and Favorites.

**Constructors:**

- `const ContentBrowserFolderTile({super.key, required this.viewModel, required this.path, required this.width, required this.height, required this.selected, requi...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `path` | `final String path` |  |
| `width` | `final double width` |  |
| `height` | `final double height` |  |
| `selected` | `final bool selected` |  |
| `onSelect` | `final VoidCallback onSelect` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `contentFolderMenuItems` | `List<MenuItem> contentFolderMenuItems(BuildContext context, EditorViewModel vm, String path, {VoidCallback? on...` | The folder context menu shared by the grid's folder tiles and the Sources tree: Open (when [onOpen] is given), New Folder, Import Folder Here, Rename, Delete and Favorites. The `contents` root offers New Folder, Import Folder Here and Favorites only. |
| `showNewContentFolderDialog` | `void showNewContentFolderDialog(BuildContext context, EditorViewModel vm, String parent)` | New Folder under [parent]; the browser then shows [parent] with the new tile. |
| `showRenameContentFolderDialog` | `void showRenameContentFolderDialog(BuildContext context, EditorViewModel vm, String folder)` | Rename [folder]; references to its assets follow the new path. |
| `showDeleteContentFolderDialog` | `void showDeleteContentFolderDialog(BuildContext context, EditorViewModel vm, String folder)` | Confirms, then deletes [folder] with every asset in it. |

## `lib/ui/features/main_editor/views/content_browser_folder_tree.dart`

### `class FolderTreeRow`

One visible row of the Sources tree.

**Constructors:**

- `const FolderTreeRow({required this.path, required this.depth, required this.hasChildren, required this.expanded})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `depth` | `final int depth` |  |
| `hasChildren` | `final bool hasChildren` |  |
| `expanded` | `final bool expanded` |  |

### `class ContentFolderRow`

A folder row of the Sources rail: chevron (tree rows only), folder icon, name, the aggregated source-control badge, the shared folder context menu, and a drop target that moves a dragged asset into the folder.

**Constructors:**

- `const ContentFolderRow({super.key, required this.path, required this.vm, required this.selected, required this.onTap, this.depth = 0, this.showChevronSlot = fal...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `vm` | `final EditorViewModel? vm` |  |
| `selected` | `final bool selected` |  |
| `onTap` | `final VoidCallback onTap` |  |
| `depth` | `final int depth` | Tree rows only: indent level and the chevron. [onToggle] is null for a folder without subfolders (a spacer keeps the names aligned); with [showChevronSlot] false (Favorites) there is no chevron column at all. |
| `showChevronSlot` | `final bool showChevronSlot` |  |
| `expanded` | `final bool expanded` |  |
| `onToggle` | `final VoidCallback? onToggle` |  |

### `class ContentBrowserSourcesRail`

The Content Browser's Sources rail: the [before] widgets (Favorites, the SOURCES heading), the collapsible folder tree — only its visible rows are built — and the [after] widgets (Collections, Smart Views), in one scroll view. A click on a tree row gives the tree the keyboard: Right expands the selected folder, Left collapses it, and Left on a collapsed folder selects its parent.

**Constructors:**

- `const ContentBrowserSourcesRail({super.key, required this.vm, this.before = const [], this.after = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `vm` | `final EditorViewModel? vm` |  |
| `before` | `final List<Widget> before` |  |
| `after` | `final List<Widget> after` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `flattenFolderTree` | `List<FolderTreeRow> flattenFolderTree(Iterable<String> folders, Set<String> expanded)` | Flattens [folders] into the rows the Sources tree shows: every root (a folder whose parent is not itself listed — `contents`, plugin content roots) in the given order, then, depth first, the children of each folder in [expanded], sorted by name. Collapsed subtrees are skipped entirely, so the cost follows the visible rows, not the project size. |

## `lib/ui/features/main_editor/views/editor_slot_bar.dart`

### `class EditorSlotBar`

The plugin buttons of one named [slot]. The row rebuilds when plugins register; each button rebuilds only on its own state.

**Constructors:**

- `const EditorSlotBar({super.key, required this.registry, required this.slot, this.compact = false, this.leadingGap = 0, this.trailingGap = 0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `registry` | `final PluginExtensionRegistry registry` |  |
| `slot` | `final EditorSlot slot` |  |
| `compact` | `final bool compact` | The status bar's size: 10 px icons, 9 px labels. |
| `leadingGap` | `final double leadingGap` | Space before and after the buttons, only when the slot has any. |
| `trailingGap` | `final double trailingGap` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `editorToneColor` | `Color editorToneColor(EditorTone tone)` | The theme colour of [tone]. |

## `lib/ui/features/main_editor/views/import_asset_folder_dialog.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `startImportAssetFolder` | `Future<void> startImportAssetFolder(BuildContext context, EditorViewModel vm, {String? targetFolder}) async` | File → Import Asset Folder…: picks a folder, walks it ([ImportFolderScanner], off the UI isolate) and shows the summary dialog. [targetFolder] is where the tree lands by default (the Content Browser's selected folder, or the folder right-clicked). |
| `showImportAssetFolderDialog` | `void showImportAssetFolderDialog(BuildContext context, EditorViewModel vm, ImportFolderScan scan, {String? tar...` | The Import Asset Folder summary for [scan]: what imports (counts per type, size, grouped companions), what is skipped and why, and the options — Mirror folder structure, target folder, what to do with assets that already exist, Auto Organize, Generate LODs. Import queues the files on the background import queue (its progress panel shows the batch). |
| `importFolderTargetError` | `String? importFolderTargetError(String folder)` | Why [folder] cannot be the target, or null: it must be `contents` or a folder under it. |
| `importFolderHeadline` | `String importFolderHeadline(ImportFolderScan scan)` | "14 files · 2.3 MB · 5 folders" for [scan]. |
| `importKindCount` | `String importKindCount(ImportFormatKind kind, int n)` |  |
| `importConflictLabel` | `String importConflictLabel(ImportConflictPolicy p)` |  |
| `importFolderPlanLine` | `String importFolderPlanLine(ImportFolderPlan plan, ImportConflictPolicy policy)` | "Imports 12 files · 3 already exist: skipped". |
| `formatImportBytes` | `String formatImportBytes(int bytes)` |  |

## `lib/ui/features/main_editor/views/import_asset_options_dialog.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `showImportAssetOptionsDialog` | `void showImportAssetOptionsDialog(BuildContext context, EditorViewModel? vm, List<String> filePaths,)` | The Content Browser's Import Asset Options dialog for [filePaths] (auto organize, LODs, an animation's target skeleton, an FBX's textures folder). Import Asset queues every file on the editor's background import queue and closes at once; progress shows in the import panel. |

## `lib/ui/features/main_editor/views/import_progress_panel.dart`

### `class ImportProgressPanel`

The background import's progress, as a bottom-right import notification: `Importing 12 / 51 · file`, the batch's bar, elapsed and remaining time, Cancel, an expandable per-file list and, once finished, the outcome with "Show errors". Collapses to [ImportProgressChip] in the status bar; a batch that imported everything dismisses itself after [ImportJobsViewModel.autoDismissAfter].

**Constructors:**

- `const ImportProgressPanel({super.key, required this.jobs, required this.onShowErrors})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `jobs` | `final ImportJobsViewModel jobs` |  |
| `onShowErrors` | `final VoidCallback onShowErrors` | Opens the Output Log filtered to errors. |
| `width` | `static const double width` |  |

### `class ImportProgressChip`

The status-bar chip a collapsed [ImportProgressPanel] leaves behind (`Importing 12/51`, with a small bar); clicking it opens the panel.

**Constructors:**

- `const ImportProgressChip({super.key, required this.jobs})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `jobs` | `final ImportJobsViewModel jobs` |  |

## `lib/ui/features/main_editor/views/import_target_skeleton_select.dart`

### `class ImportTargetSkeletonSelect`

The Import Asset Options dialog's **Target Skeleton** row: which project skeletal mesh an imported FBX animation is retargeted onto.

[value] follows `EditorViewModel.processImportPipeline(targetSkeletonPath:)`: null matches a skeleton by bone names, `''` keeps the animation unbound, anything else is a skeletal mesh `.lmas` path relative to the project.

**Constructors:**

- `const ImportTargetSkeletonSelect({super.key, required this.skeletalMeshes, required this.value, required this.onChanged,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `autoValue` | `static const String autoValue` | The Select's value for "match by bone names" (null in [value]). |
| `appliesTo` | `static bool appliesTo(List<String> filePaths)` | Whether the dialog shows the row for [filePaths]: only an FBX can hold an animation the importer retargets. |
| `skeletalMeshes` | `final List<RealAssetInfo> skeletalMeshes` | The project's skeletal meshes (the retarget targets on offer). |
| `value` | `final String? value` |  |
| `onChanged` | `final ValueChanged<String?> onChanged` |  |

## `lib/ui/features/main_editor/views/import_textures_folder_row.dart`

### `class ImportTexturesFolderRow`

The Import Asset Options dialog's **Textures Folder** row: a folder the FBX importer searches first for the FBX's textures. Without one it looks next to the FBX and in its `Textures/`, `textures/`, `<name>/` and `<name>.fbm/` folders. Textures the FBX names are found by file name; images named after a material and a channel (`T_Wood_BaseColor`, `…_MI_Neon_Green_…_Emissive`, `_Normal`, `_ORM`) are applied to that material even when the FBX names none (an Unreal FBX export carries only its materials' constants).

**Constructors:**

- `const ImportTexturesFolderRow({super.key, required this.value, required this.onChanged, this.picker})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `appliesTo` | `static bool appliesTo(List<String> filePaths)` | Only an FBX goes through the texture search. |
| `value` | `final String? value` | The chosen folder, or null for "next to the FBX". |
| `onChanged` | `final ValueChanged<String?> onChanged` |  |
| `picker` | `final Future<String?> Function()? picker` | The directory picker; null opens the OS dialog. |

## `lib/ui/features/main_editor/views/legacy_units_banner.dart`

### `class LegacyUnitsBanner`

Shown under the menu bar for a project created before Lumina switched to centimetres and Z-up authoring. Such a project is not migrated (the user's decision): its levels were authored in metres, Y up, and would play at the wrong scale.

**Constructors:**

- `const LegacyUnitsBanner({super.key})`

## `lib/ui/features/main_editor/views/menu_tree_builder.dart`

### `class MenuTreeEntry`

One menu item to place: [path] runs from the first submenu under the menu it belongs to down to the item's own slot (its last segment); the item shows [command]'s label.

**Constructors:**

- `const MenuTreeEntry({required this.path, required this.command, this.options = const EditorMenuItemOptions()})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final List<String> path` |  |
| `command` | `final EditorCommand command` |  |
| `options` | `final EditorMenuItemOptions options` |  |

### `sealed class MenuTreeNode`

The laid-out menu: items, submenus and the dividers between sections.

**Constructors:**

- `const MenuTreeNode()`

### `class MenuTreeLeaf`

**Constructors:**

- `const MenuTreeLeaf(this.entry)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entry` | `final MenuTreeEntry entry` |  |

### `class MenuTreeSubmenu`

**Constructors:**

- `const MenuTreeSubmenu(this.title, this.children)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `title` | `final String title` |  |
| `children` | `final List<MenuTreeNode> children` |  |

### `class MenuTreeDivider`

**Constructors:**

- `const MenuTreeDivider()`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `layoutMenuTree` | `List<MenuTreeNode> layoutMenuTree(Iterable<MenuTreeEntry> entries)` | Lays [entries] out as a tree of any depth. Within each (sub)menu the children sort by `order` (a submenu takes its lowest descendant's order and its first item's section), ties keep registration order; children of different sections are grouped in the order their sections first appear, with one divider between neighbouring groups. |
| `buildMenuTree` | `List<MenuItem> buildMenuTree(Iterable<MenuTreeEntry> entries, {BuildContext? commandContext, MenuItem Function...` | Builds shadcn menu items for [entries] ([layoutMenuTree]). Items run their command with [commandContext] when given (a context that outlives the closed menu) and are disabled while `canExecute` is false; a `checked` item shows a live check mark. [itemBuilder] replaces the default button for plain (unchecked) items. |
| `menuTreeButton` | `MenuButton menuTreeButton(EditorCommand command, {BuildContext? commandContext, String? label})` | The default menu button for [command]: icon, label, shortcut, disabled while `canExecute` is false. |
| `menuCheckboxItem` | `MenuItem menuCheckboxItem(EditorCommand command, ValueListenable<bool> checked, {BuildContext? commandContext}...` | A built-in menu's checkbox row: [command] with a check that follows [checked] while the menu is open, keyed `menu_check_<command id>` like the plugin rows. |

## `lib/ui/features/main_editor/views/pie_blueprint_debug_panel.dart`

### `class PieBlueprintDebugPanel`

The level editor's docked Blueprint tab: during Play it shows the event graph of the Blueprint the debugger follows (the possessed pawn, or the selected placed Blueprint) with its nodes and exec wires lighting up as they run; hovering a data pin shows its last value. Every debugged Blueprint — the level's own script too — is listed above the graph to switch to.

**Constructors:**

- `const PieBlueprintDebugPanel({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |

### `class PieBlueprintDebugPanelState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `pick` | `void pick(String path)` | Shows [path]'s graph (one of the debugged Blueprints). |
| `debuggedPath` | `String? get debuggedPath` | The class shown, for tests. |
| `graphViewModel` | `BlueprintEditorViewModel? get graphViewModel` |  |

## `lib/ui/features/main_editor/views/pie_debug_draw_layer.dart`

### `typedef PieDebugProject`

Projects a runtime point to the viewport, or null when off camera.

### `class PieDebugDrawLayer`

The level viewport's Play overlay for `LuminaWorld.debugShapes` and `LuminaWorld.screenMessages`: lines, spheres, boxes, points, arrows, capsules and strings the running Blueprints drew, projected through the game camera, and the Print String lines top-left in their colours. Repaints every frame while [world] plays; the world drops expired records itself.

**Constructors:**

- `const PieDebugDrawLayer({super.key, required this.world, required this.projection})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `world` | `final LuminaWorld? Function() world` |  |
| `projection` | `final PieDebugProjector? Function() projection` | The projection for the current frame (the game camera's, or the editor camera's once ejected); null draws only the screen messages. |

### `class PieDebugDrawLayerState`

### `class PieDebugShapePainter`

Draws [shapes] through [projection]: a polyline per shape, circles for spheres and points, a wire box, an arrow head, a capsule outline and a label for strings.

**Constructors:**

- `PieDebugShapePainter({required this.shapes, required this.projection})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shapes` | `final List<LuminaDebugShape> shapes` |  |
| `projection` | `final PieDebugProjector projection` |  |
| `colorOf` | `static Color colorOf(List<double> c)` |  |
| `drawn` | `int drawn` | How many shapes were drawn on the last paint (for tests). |

## `lib/ui/features/main_editor/views/pie_mouse_capture_layer.dart`

### `class PieMouseCaptureLayer`

Play's mouse capture on the game view, one child of the viewport's Stack: - the hint "Press F4 to show the mouse cursor", prominent when Play takes the mouse and faded out after [hintDuration]; - once F4 gave the cursor back, a hint and a click target over the view: a click takes the mouse again and is not passed to the editor (no selection); - while the backend holds the pointer, a window-wide shield in the root overlay: the cursor is hidden wherever the held pointer sits (Wayland holds it where it was, often on the toolbar's Play button), and clicks there never press editor buttons.

**Constructors:**

- `const PieMouseCaptureLayer({super.key, required this.pie, this.hintDuration = const Duration(seconds: 5)})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `pie` | `final PieController pie` |  |
| `hintDuration` | `final Duration hintDuration` |  |
| `captureHint` | `static const String captureHint` | The capture hint, as the user asked for it. |
| `releasedHint` | `static const String releasedHint` | The hint while the cursor is released. |

## `lib/ui/features/main_editor/views/pie_widget_layer.dart`

### `class PieWidgetLayer`

Renders the UMG widgets a Play-In-Editor session adds to the viewport through the engine's [LuminaWidgetLayer], so PIE and the built game share one rendering path. The editor has no compiled widget classes, so each class is built from its designer document ([UmgRuntimeView]) bound to the instance's per-element state; the project's widget documents are registered into [LuminaWidgetClassRegistry] so `Create Widget` seeds those elements.

**Constructors:**

- `const PieWidgetLayer({super.key, required this.pieController, required this.projectDirPath,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `pieController` | `final PieController pieController` |  |
| `projectDirPath` | `final String projectDirPath` |  |

## `lib/ui/features/main_editor/views/play_blocked_dialog.dart`

### `class PlayBlockedDialog`

**Constructors:**

- `const PlayBlockedDialog({super.key, required this.blockers, required this.onOpen, required this.onClose})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `blockers` | `final List<PlayBlocker> blockers` |  |
| `onOpen` | `final ValueChanged<PlayBlocker> onOpen` |  |
| `onClose` | `final VoidCallback onClose` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `openBlueprintAtNode` | `void openBlueprintAtNode(EditorViewModel vm, String path, String? nodeId)` | Opens Blueprint [path] (project-relative) in its editor tab and asks the editor to select and frame [nodeId]. |
| `showPlayBlockedDialog` | `void showPlayBlockedDialog(BuildContext context, EditorViewModel vm, List<PlayBlocker> blockers)` | The "compile errors" dialog on Play: Play did not start; each row is Blueprint → node → message, and clicking a row opens that Blueprint framed on the node. |

## `lib/ui/features/main_editor/views/right_dock_widget.dart`

### `class RightDockWidget`

The right dock: the open `PanelDefaultDock.right` plugin panels. A header names the active one; with several open, a tab strip switches between them. Each tab has a close button. Bodies stay mounted in an [IndexedStack], so a panel keeps its state across tab switches.

**Constructors:**

- `const RightDockWidget({super.key, required this.controller})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `controller` | `final EditorPanelsController controller` |  |

## `lib/ui/features/main_editor/views/status_bar_engine_segment.dart`

### `class FilamentStatusSegment`

The status bar's `Filament <version>` segment: Filament's logo tinted to the muted foreground (so it reads on every theme), the linked version, a tooltip with the material version, and [onPressed] (Help ▸ About).

**Constructors:**

- `const FilamentStatusSegment({super.key, required this.onPressed})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `logoAsset` | `static const String logoAsset` | The raster mark (transparent, 64 px high) — tinted, a flat shape reads better than the SVG's gloss at 12 px. |
| `onPressed` | `final VoidCallback? onPressed` |  |

## `lib/ui/features/main_editor/views/toolbar_priority_row.dart`

### `class ToolbarPriorityRow`

The level toolbar's layout: three children, [leading], [middle] and [trailing], in a row of fixed height.

- [trailing] (plugin end-slot buttons, Quality) always gets its full width. - [leading] (the tool groups) gets its natural width when it fits beside [trailing]; otherwise whatever is left (it scrolls). - [middle] (the frame stats) gets the rest and gives way first; it is laid out tight, so a text with an ellipsis truncates.

**Constructors:**

- `ToolbarPriorityRow({super.key, required Widget leading, required Widget middle, required Widget trailing, this.gap = 12})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `gap` | `final double gap` | The space after [leading] and after [middle]. |

---

[Previous: Main editor: views](main-editor-views.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Main editor: view model and services](main-editor-state.md)
