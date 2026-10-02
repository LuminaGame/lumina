[Türkçe](../../tr/lumina_ui/main-editor-views.md)

# Main editor: views

The widgets of the main editor window: the main editor view and its layout state, the 3D viewport, the outliner, the details panel, the content browser, the toolbar, the menu bar, the output log, the new level dialog and the restart-required banner. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/main_editor/views/content_browser_widget.dart`](#libuifeaturesmain_editorviewscontent_browser_widgetdart)
- [`lib/ui/features/main_editor/views/details_widget.dart`](#libuifeaturesmain_editorviewsdetails_widgetdart)
- [`lib/ui/features/main_editor/views/main_editor_view.dart`](#libuifeaturesmain_editorviewsmain_editor_viewdart)
- [`lib/ui/features/main_editor/views/menu_bar_widget.dart`](#libuifeaturesmain_editorviewsmenu_bar_widgetdart)
- [`lib/ui/features/main_editor/views/new_level_dialog.dart`](#libuifeaturesmain_editorviewsnew_level_dialogdart)
- [`lib/ui/features/main_editor/views/outliner_widget.dart`](#libuifeaturesmain_editorviewsoutliner_widgetdart)
- [`lib/ui/features/main_editor/views/output_log_widget.dart`](#libuifeaturesmain_editorviewsoutput_log_widgetdart)
- [`lib/ui/features/main_editor/views/restart_required_banner.dart`](#libuifeaturesmain_editorviewsrestart_required_bannerdart)
- [`lib/ui/features/main_editor/views/toolbar_widget.dart`](#libuifeaturesmain_editorviewstoolbar_widgetdart)
- [`lib/ui/features/main_editor/views/viewport_widget.dart`](#libuifeaturesmain_editorviewsviewport_widgetdart)
- [`lib/ui/features/main_editor/view_models/editor_layout_state.dart`](#libuifeaturesmain_editorview_modelseditor_layout_statedart)

## `lib/ui/features/main_editor/views/content_browser_widget.dart`

### `class ContentBrowserWidget`

`ContentBrowserWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<ContentBrowserWidget> createState() => _ContentBrowserWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ContentBrowserWidgetState`

`_ContentBrowserWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _LuminaClassInfo`

`_LuminaClassInfo`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `className` | `String className` | Holds the `className` property or configuration state. |
| `category` | `String category` | Holds the `category` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |

## `lib/ui/features/main_editor/views/details_widget.dart`

### `class DetailsWidget`

`DetailsWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<DetailsWidget> createState() => _DetailsWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _DetailsWidgetState`

`_DetailsWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _CategoryHeader`

`_CategoryHeader`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _MobilityBtn`

`_MobilityBtn`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `active` | `bool active` | Holds the `active` property or configuration state. |
| `onTap` | `VoidCallback onTap` | Holds the `onTap` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/main_editor_view.dart`

### `class MainEditorView`

`MainEditorView`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `project` | `LuminaProject? project` | Holds the `project` property or configuration state. |
| `projectLocation` | `String? projectLocation` | Holds the `projectLocation` property or configuration state. |
| `viewModel` | `EditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<MainEditorView> createState() => _MainEditorViewState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _MainEditorViewState`

`_MainEditorViewState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/menu_bar_widget.dart`

### `class MenuBarWidget`

`MenuBarWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engineVersion` | `String engineVersion` | Holds the `engineVersion` property or configuration state. |
| `activeLevelName` | `String activeLevelName` | Holds the `activeLevelName` property or configuration state. |
| `onSave` | `VoidCallback onSave` | Holds the `onSave` property or configuration state. |
| `viewModel` | `EditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/new_level_dialog.dart`

### `class NewLevelDialog`

`File → New Level…` — a name plus the template the level starts from.  Every entry is honest about what it seeds (including `Empty`, which seeds nothing on purpose), and the chosen template's actors and world-partition section are written into the new `.lmas` before the editor switches to it, so the level opens populated.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<NewLevelDialog> createState() => _NewLevelDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _NewLevelDialogState`

`_NewLevelDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _TemplateTile`

One selectable template row. It is a real focusable button, so the list is keyboard-navigable with Tab / Enter without any custom key handling.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `template` | `LevelTemplate template` | Holds the `template` property or configuration state. |
| `selected` | `bool selected` | Holds the `selected` property or configuration state. |
| `onSelected` | `VoidCallback onSelected` | Holds the `onSelected` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/outliner_widget.dart`

### `class OutlinerWidget`

`OutlinerWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<OutlinerWidget> createState() => _OutlinerWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _OutlinerWidgetState`

`_OutlinerWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _FlattenedNode`

`_FlattenedNode`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_FlattenedNode(this.node, this.depth, this.hasChildren)`: Initializes `_FlattenedNode(this.node, this.depth, this.hasChildren)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `node` | `EditorActorNode node` | Holds the `node` property or configuration state. |
| `depth` | `int depth` | Holds the `depth` property or configuration state. |
| `hasChildren` | `bool hasChildren` | Holds the `hasChildren` property or configuration state. |

## `lib/ui/features/main_editor/views/output_log_widget.dart`

### `class OutputLogWidget`

`OutputLogWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<OutputLogWidget> createState() => _OutputLogWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _OutputLogWidgetState`

`_OutputLogWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/restart_required_banner.dart`

### `class RestartRequiredBanner`

`RestartRequiredBanner`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onDismiss` | `VoidCallback onDismiss` | Holds the `onDismiss` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/toolbar_widget.dart`

### `class ToolbarWidget`

`ToolbarWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<ToolbarWidget> createState() => _ToolbarWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ToolbarWidgetState`

`_ToolbarWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _ToolBtn`

`_ToolBtn`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |
| `active` | `bool active` | Holds the `active` property or configuration state. |
| `onTap` | `VoidCallback onTap` | Holds the `onTap` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _SnapCluster`

`_SnapCluster`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_SnapCluster(this.vm)`: Initializes `_SnapCluster(this.vm)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `EditorViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _SnapToggleWithMenu`

`_SnapToggleWithMenu`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |
| `active` | `bool active` | Holds the `active` property or configuration state. |
| `onToggle` | `VoidCallback onToggle` | Holds the `onToggle` property or configuration state. |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `options` | `List<double> options` | Holds the `options` property or configuration state. |
| `onChanged` | `ValueChanged<double> onChanged` | Holds the `onChanged` property or configuration state. |
| `createState` | `State<_SnapToggleWithMenu> createState() => _SnapToggleWithMenuState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SnapToggleWithMenuState`

`_SnapToggleWithMenuState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _GridPopover`

`_GridPopover`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `EditorViewModel vm` | Holds the `vm` property or configuration state. |
| `createState` | `State<_GridPopover> createState() => _GridPopoverState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _GridPopoverState`

`_GridPopoverState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/main_editor/views/viewport_widget.dart`

**Top-level Functions:**

- **`with TickerProviderStateMixin`**: Executes `TickerProviderStateMixin` operation.

### `class ViewportWidget`

`ViewportWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `EditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<ViewportWidget> createState() => _ViewportWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### Camera preview (`camera_preview_panel.dart`, `level_scene_view.dart`)

Selecting exactly one camera actor (a placed `Camera`; not during Play) opens a **Camera preview** panel at the bottom-left of the 3D area, above the stats strip: the camera's name, a close button (×) and a live view of the level through that camera — its location and rotation (following gizmo drags and Details edits), its projection (vertical field of view, or orthographic width), near / far clip planes and exposure (its own aperture / shutter speed / ISO, or the level viewport's metered exposure with Auto Exposure). The picture is 16:9 (a camera has no aspect setting yet; the vertical field of view is the camera's, so the vertical framing matches Play). Drag the top-right corner to resize it (16:9 kept, 192–960 px wide and never taller than the 3D area allows); the width is a per-user editor preference (`EditorPreferences.cameraPreviewWidth`). × hides it until another camera is selected (or the selection moves away and back); selecting a non-camera or several actors hides it. Clicks on the panel stay on it (no selection or navigation behind it). While hidden it has no Filament view.

The preview draws the level viewport's own scene (`EditorViewModel.levelScene`) without the editor's helpers, through Filament visibility layers (`EditorViewLayers`): content (default layer), helpers (grid, gizmo, selection boxes, light / capsule / volume wires, Wireframe edge lines) and actor solids. The level view shows all three in Lit / Unlit and hides the solids in Wireframe (they stay in the scene, so the preview still shows the lit level); the preview shows content and solids. Lights are part of the scene, so in Unlit the preview loses the direct lights too; the level viewport's fog and Post Process Volumes are not applied to the preview.

| Class | Purpose |
| :--- | :--- |
| `CameraPreviewOverlay` | Fills the 3D area, shows the panel for `previewCameraOf(vm)` (the single selected camera outside Play), handles × and the corner drag; `panelWidth`, `maxWidth`, `close()`. |
| `CameraPreviewPanel` | The panel: title bar, `LevelSceneView` through the camera (`CameraActorView.apply`), the top-right resize grip. `aspect` = 16:9. |
| `LevelSceneView` / `LevelSceneViewState` | A second view of the level's scene on the shared engine, aimed by its owner (`onAim`, called on creation, scene changes, resize and every frame), with its own visible layers. The Sequencer viewport is built on it too. `drawsLevelScene`, `view`, `camera`, `drawn`, `aspect`, `aim()`. |
| `CameraActorView` (`services/camera_actor_view.dart`) | A camera actor as a view: `settingsOf` (`LuminaCameraSettings`), `pose` (`LevelViewPose`), `apply` (projection, clip planes, pose, exposure). |
| `EditorViewLayers` (`services/editor_view_layers.dart`) | The layer bits (`content`, `helpers`, `solids`, and `gizmo`: the level viewport's native transform gizmo, which the Sequencer's view (`editorView`) leaves out because it draws its own), the masks of each view, `show(view, layers)`, `tag(engine, entities, layer)`. |

Test seams on the level viewport state: `viewLayersForTest` (the level view's visible layers), `editorActorsInSceneForTest` (solids the level view draws; 0 in Wireframe), `editorActorSolidsInSceneForTest` (solids in the scene).

### `class _ViewportWidgetState`

`_ViewportWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(covariant ViewportWidget oldWidget)` | Getter accessor returning the current value of `didUpdateWidget`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `pieCameraDrivesViewForTest` | `bool get pieCameraDrivesViewForTest` | Test seam: whether the game's camera owns the Filament view. |
| `pieCameraEyeForTest` | `List<double>? get pieCameraEyeForTest` | Test seam: the eye position the PIE camera is pointing from, or null when the editor camera owns the view. |
| `nativeGizmoForTest` | `FilamentTransformGizmo? get nativeGizmoForTest` | The live transform gizmo, so smoke tests can assert which mode is on screen and which handle is highlighted. |
| `hoveredGizmoAxisForTest` | `String? get hoveredGizmoAxisForTest` | The gizmo handle the pointer is currently over, or null. |
| `nativeViewForTest` | `FilamentView? get nativeViewForTest` | The live Filament view, so smoke tests can assert what the renderer was actually told rather than what the view model believes. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |
| `gizmoHandleScreenPositionsForTest` | `Map<String, Offset>? gizmoHandleScreenPositionsForTest(Size viewportSize)` | Executes `gizmoHandleScreenPositionsForTest` operation. |

### `class _CameraMatrix`

`_CameraMatrix`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewportSize` | `Size viewportSize` | Holds the `viewportSize` property or configuration state. |
| `yawDeg` | `double yawDeg` | Holds the `yawDeg` property or configuration state. |
| `pitchDeg` | `double pitchDeg` | Holds the `pitchDeg` property or configuration state. |
| `dist` | `double dist` | Holds the `dist` property or configuration state. |
| `panX` | `double panX` | Holds the `panX` property or configuration state. |
| `panY` | `double panY` | Holds the `panY` property or configuration state. |
| `panZ` | `double panZ` | Holds the `panZ` property or configuration state. |
| `cx` | `final double cx` | Holds the `cx` property or configuration state. |
| `cy` | `final double cy` | Holds the `cy` property or configuration state. |
| `yawRad` | `final double yawRad` | Holds the `yawRad` property or configuration state. |
| `pitchRad` | `final double pitchRad` | Holds the `pitchRad` property or configuration state. |
| `fovScale` | `final double fovScale` | Holds the `fovScale` property or configuration state. |
| `camX` | `final double camX` | Holds the `camX` property or configuration state. |
| `camY` | `final double camY` | Holds the `camY` property or configuration state. |
| `camZ` | `final double camZ` | Holds the `camZ` property or configuration state. |
| `fZ` | `final double fX, fY, fZ` | Holds the `fZ` property or configuration state. |
| `rZ` | `final double rX, rY, rZ` | Holds the `rZ` property or configuration state. |
| `uZ` | `final double uX, uY, uZ` | Holds the `uZ` property or configuration state. |
| `project` | `Offset? project(double wx, double wy, double wz)` | Executes `project` operation. |
| `getWorldRayDirection` | `List<double> getWorldRayDirection(Offset screenPos)` | Queries and returns the `WorldRayDirection` value or child object. |
| `unprojectToFloor` | `Offset unprojectToFloor(Offset screenPos)` | Setter mutator assigning a new value to `unprojectToFloor`. |

## `lib/ui/features/main_editor/view_models/editor_layout_state.dart`

### `class EditorLayoutState`

`EditorLayoutState`: `class` representing the data model or functionality of the module.

The left column (World Outliner over Details) is never narrower than `minOutlinerWidth` (320 px, also `defaultOutlinerWidth`): the splitter stops there and a narrower width from a layout file or a caller is widened to it (`clampOutlinerWidth`).

**Constructors:**
- `EditorLayoutState.fromJson(Map<String, dynamic> json)`: Initializes `EditorLayoutState.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `outlinerWidth` | `double outlinerWidth` | Holds the `outlinerWidth` property or configuration state. |
| `detailsWidth` | `double detailsWidth` | Holds the `detailsWidth` property or configuration state. |
| `bottomHeight` | `double bottomHeight` | Holds the `bottomHeight` property or configuration state. |
| `outlinerVisible` | `bool outlinerVisible` | Holds the `outlinerVisible` property or configuration state. |
| `detailsVisible` | `bool detailsVisible` | Holds the `detailsVisible` property or configuration state. |
| `bottomVisible` | `bool bottomVisible` | Holds the `bottomVisible` property or configuration state. |
| `activeBottomTab` | `int activeBottomTab` | Holds the `activeBottomTab` property or configuration state. |
| `rightWidth` | `double rightWidth` | The right dock's width (default 340, at least 260), shared by every editor tab. |
| `pluginPanelVisible` | `Map<String, bool> pluginPanelVisible` | Which right-dock plugin panels are open (closed until shown). |
| `activeRightPanel` | `String? activeRightPanel` | The right dock's active tab. |
| `pluginPanelAlways` | `Map<String, bool> pluginPanelAlways` | The user's "Always" choice per right-dock panel: shown in every editor tab rather than the level editor only. A panel missing here uses its plugin's `defaultAlwaysVisible`. Saved as `pluginPanelAlways` in `editor_layout.json`; Reset Layout clears it. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `resetToDefault` | `void resetToDefault()` | Resets values or state back to defaults. |

---

[Previous: App shell and shared UI (continued, part 2)](core-continued-2.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Main editor: views (continued)](main-editor-views-continued.md)
