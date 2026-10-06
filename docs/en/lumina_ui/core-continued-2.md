[Türkçe](../../tr/lumina_ui/core-continued-2.md)

# App shell and shared UI (continued, part 2)

Continuation of App shell and shared UI: the remaining public files under `lib/ui/core/window/` and `lib/ui/core/widgets/` (media players, declarative plugin panels). File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/core/window/lumina_window.dart`](#libuicorewindowlumina_windowdart)
- [`lib/ui/core/window/window_controls.dart`](#libuicorewindowwindow_controlsdart)
- [`lib/ui/core/window/window_state_store.dart`](#libuicorewindowwindow_state_storedart)
- [`lib/ui/core/widgets/media/editor_media_widgets.dart`](#libuicorewidgetsmediaeditor_media_widgetsdart)
- [`lib/ui/core/widgets/plugin_view/`](#libuicorewidgetsplugin_view)

## `lib/ui/core/window/lumina_window.dart`

### `typedef WindowCloseGuard`

Asked before the window closes; false keeps it open. The editor's guard shows the unsaved-changes prompt.

### `class LuminaWindow`

Lumina Studio's own window chrome: the native title bar is hidden, and the editor's menu row, [LuminaWindowControls] and the resize border drive the window through this controller.

It wraps `package:window_manager` and never assumes a state change: the maximize / fullscreen flags follow the plugin's events, so a window manager that ignores a request (a tiling WM refusing to maximize) or changes the window on its own is reflected as it really is.

Closing — from [LuminaWindowControls], or from the window manager (Alt+F4, the taskbar), which `setPreventClose(true)` turns into a `close` event — runs every registered [WindowCloseGuard] first, saves the window's placement through [store] and only then destroys the window.

**Constructors:**

- `LuminaWindow({WindowManager? manager, WindowStateStore? store})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `static final LuminaWindow instance` | The app's window. Widgets reach it through [LuminaWindowScope.of]. |
| `store` | `WindowStateStore get store` | Where the placement is saved; the editor preferences by default. |
| `isMaximized` | `bool get isMaximized` |  |
| `isFullScreen` | `bool get isFullScreen` |  |
| `normalBounds` | `Rect? get normalBounds` | The restored (un-maximized, windowed) bounds last seen. |
| `os` | `static String get os` | The desktop OS the chrome is drawn for (`linux`, `windows`, `macos`); a test can pretend to be another one. |
| `debugOsOverride` | `static String? debugOsOverride` |  |
| `drawsOwnControls` | `static bool get drawsOwnControls` | Whether this platform shows Lumina's own minimize / maximize / close buttons. macOS keeps its traffic lights (drawn by the system at the left of the hidden title bar, `windowButtonVisibility: true`). |
| `needsResizeBorder` | `static bool get needsResizeBorder` | Whether the app needs its own resize border: an undecorated GTK window has no WM handles. Windows keeps its native frame border and macOS its window edges with a hidden title bar. |
| `leadingInset` | `static double get leadingInset` | The room macOS's traffic lights take at the left of the menu row. |
| `startup` | `Future<void> startup(WindowOptions options) async` | Prepares the window before the first frame: restores the saved placement over [options] (whose `titleBarStyle` is the app's), turns the window manager's close into a request, and shows the window. |
| `minimize` | `Future<void> minimize()` |  |
| `toggleMaximize` | `Future<void> toggleMaximize()` | Maximizes or restores, from the window's real state. |
| `toggleFullScreen` | `Future<void> toggleFullScreen()` | Enters or leaves fullscreen, from the window's real state. |
| `startDragging` | `Future<void> startDragging()` |  |
| `startResizing` | `Future<void> startResizing(ResizeEdge edge)` |  |
| `addCloseGuard` | `void addCloseGuard(WindowCloseGuard guard)` |  |
| `removeCloseGuard` | `void removeCloseGuard(WindowCloseGuard guard)` |  |
| `requestClose` | `Future<bool> requestClose() async` | Asks every close guard (most recent first); when all agree, saves the placement and destroys the window. Returns whether the window closed. |

### `class LuminaWindowScope`

Puts a [LuminaWindow] in the tree (the app's [LuminaWindow.instance] when there is none), so window chrome rebuilds when the window changes state.

**Constructors:**

- `const LuminaWindowScope({super.key, required LuminaWindow window, required super.child})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `of` | `static LuminaWindow of(BuildContext context)` |  |
| `read` | `static LuminaWindow read(BuildContext context)` | The window without subscribing to its changes (for callbacks). |

## `lib/ui/core/window/window_controls.dart`

### `class LuminaWindowControls`

Lumina's own window buttons at the right end of the menu bar row (and of the launcher header): minimize, maximize ⇄ restore (the icon follows the window's real state), fullscreen and close (red on hover; it goes through [LuminaWindow.requestClose], so the editor's unsaved-changes prompt runs first).

macOS keeps its system traffic lights at the left, so there this draws nothing ([LuminaWindow.drawsOwnControls]).

**Constructors:**

- `const LuminaWindowControls({super.key, this.height = 30, this.showFullScreen = true})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `height` | `final double height` |  |
| `showFullScreen` | `final bool showFullScreen` |  |

### `class WindowDragArea`

The part of a title bar that moves the window: drag to move it, double-click to maximize / restore.

**Constructors:**

- `const WindowDragArea({super.key, this.child = const SizedBox.expand()})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `child` | `final Widget child` |  |

### `class LuminaWindowFrame`

The app's window frame, above every route: puts [window] in scope, gives F11 (fullscreen) to screens that have no shortcut layer of their own (the editor maps it to View ▸ Full Screen), and — where the native border is gone (Linux) — lays a thin resize border along every edge and corner, which drives `gtk_window_begin_resize_drag` through the plugin. The border steps aside while the window is maximized or fullscreen.

**Constructors:**

- `const LuminaWindowFrame({super.key, required this.window, required this.child})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `window` | `final LuminaWindow window` |  |
| `child` | `final Widget child` |  |
| `edge` | `static const double edge` | The border's thickness; corners take twice that along each side. |

## `lib/ui/core/window/window_state_store.dart`

### `class WindowStateData`

The editor window's placement as the user left it: the restored (un-maximized) bounds in logical pixels, plus whether it was maximized or fullscreen on top of them.

**Constructors:**

- `const WindowStateData({required this.bounds, this.maximized = false, this.fullScreen = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `bounds` | `final Rect bounds` |  |
| `maximized` | `final bool maximized` |  |
| `fullScreen` | `final bool fullScreen` |  |
| `minWidth` | `static const double minWidth` | Smaller than this is not a window anyone left on purpose (a corrupt or hand-edited file); it is ignored. |
| `minHeight` | `static const double minHeight` |  |
| `toJson` | `Map<String, Object> toJson()` |  |
| `fromJson` | `static WindowStateData? fromJson(Object? json)` | The state in [json], or null when it is missing, malformed or too small. |

### `class WindowStateStore`

Keeps [WindowStateData] in the editor preferences — the `window` block of `editor_preferences.json` in [LuminaConfigDir] (a temp directory in every test), beside the other Editor Preferences, which it never touches.

**Constructors:**

- `WindowStateStore({Directory? configDir})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` | The same file as `EditorPreferences.fileName`. |
| `key` | `static const String key` |  |
| `file` | `final File file` |  |
| `load` | `WindowStateData? load()` | The saved state, or null when there is none (first start) or it is unreadable. |
| `save` | `void save(WindowStateData state)` |  |

## `lib/ui/core/widgets/media/editor_media_widgets.dart`

### `class LuminaVideoPlayerWidget`

A full-featured desktop/editor video player widget built on `shadcn_flutter`. Integrates hardware-accelerated playback with:
- Play / Pause / Stop controls.
- Current position and total duration timecodes (`MM:SS` / `HH:MM:SS`).
- Interactive scrubbing slider for exact position seeking.
- Volume popover with mute toggle and slider.
- Loop playback toggle.
- Playback rate dropdown selector (`0.5x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`).

**Constructors:**

- `const LuminaVideoPlayerWidget({super.key, required this.controller, this.fit = BoxFit.contain, this.showControls = true, this.autoPlay = false})`

### `class LuminaAudioPlayerWidget`

A dedicated audio player widget for the editor with playback controls, progress scrubbing bar, timecode indicators, volume adjustments, and loop controls.

**Constructors:**

- `const LuminaAudioPlayerWidget({super.key, required this.controller, this.showControls = true, this.autoPlay = false})`

## `lib/ui/core/widgets/plugin_view/`

Declarative plugin panels. A plugin that runs in its own process cannot send widgets, so it describes a panel as a
`PluginViewSpec` (`package:lumina_plugin_protocol`, re-exported by `lumina_editor_api`): a tree of `PluginControl`s,
each with a `kind`, an `id` unique in the view, `props` and, for containers, `children`. The editor draws the spec with
its own shadcn widgets (the Details panel's property editors) and answers user actions with `PluginViewEvent`s; the
plugin answers with a new spec or a `PluginViewPatch`.

### `class PluginViewRenderer`

`const PluginViewRenderer({super.key, required PluginViewSpec spec, required void Function(PluginViewEvent) onEvent, String? projectDir})`

Draws [spec] top to bottom, one widget per control, each keyed `ValueKey('<viewId>/<controlId>')`. [projectDir]
resolves relative image paths and supplies the asset list of asset-ref fields outside the main editor. The panel does
not scroll by itself; the dock panel that hosts it does.

**Updating.** Pass a new spec, typically `spec.apply(patch)`. A control that renders the same as before (same kind, id,
props and children, compared deeply) keeps its widget instance, so Flutter skips it: a patch rebuilds only the
controls it changed, and an unchanged text field keeps its focus, caret and unsent typing. A full resend of an
identical spec changes nothing on screen. Inputs keep the user's latest choice until the plugin sends a different
`value`; a text field that has focus keeps what is being typed even then and shows the plugin's value once it is left.
A new view id or project directory starts over.

**Controls.** `label` (a 100 px muted label column, as in the Details panel) and `tooltip` work on every kind;
`enabled: false` greys an input or button out and it sends nothing.

| Kind | Props | Drawn with | Event |
|---|---|---|---|
| `section` | `title`, `collapsed` | the Details category header; clicking it collapses the children (local state; a new `collapsed` from the plugin wins) | none |
| `row` | `gap` (default 8) | children side by side: buttons keep their width, text shrinks, other controls share the rest | none |
| `text` | `value`, `style` (`body`, `muted`, `heading`, `code`, `error`) | a text line (`code` in JetBrains Mono) | none |
| `textField` | `value`, `placeholder`, `multiline` | shadcn `TextField` | `changed` with the text on Enter, or when the user leaves a field they changed (a multi-line field commits on leaving) |
| `numberField` | `value`, `min`, `max`, `step`, `unit` | `SliderField` when `min` and `max` are set, else `ScrubNumericField` | `changed` with the committed number, snapped to `step`, an `int` when `step` and `value` are whole; never per scrub tick |
| `boolField` | `value` | shadcn `Checkbox` | `changed` with the bool |
| `enumField` | `value`, `options` (`[{"value","label"}]`) | `EnumField` showing the labels | `changed` with the option's value |
| `assetRefField` | `value` (project-relative path), `assetTypes` (`AssetType` names) | `AssetPickerSelect` filtered by type, a clear button, and a drop target for Content Browser tiles | `changed` with the project-relative path, or null when cleared |
| `colorField` | `value` (`#RRGGBB` or `#AARRGGBB`) | `ColorField` (swatch, picker, hex text); an 8-digit value edits alpha | `changed` with the colour in the value's own form |
| `button` | `text`, `tone` (`EditorTone` name), `icon` (`PluginIconSpec` json) | shadcn `Button`: primary, destructive, outline (success and warning tint the text) | `pressed` |
| `progress` | `value` (0..1, null = indeterminate), `text` | shadcn `LinearProgressIndicator`, the text and the percentage | none |
| `log` | `lines` (newest last), `maxLines` (default 200), `height` (default 160) | a selectable monospace box keeping the newest `maxLines`; it follows new lines while scrolled to the bottom | none |
| `image` | `path` (absolute or project-relative) or `base64`, `height` (default 160) | `Image.memory`, fitted; the file is read asynchronously, base64 over 64 KB is decoded on a background isolate | none |
| `preview3d` | `scene` (`PluginSceneSpec` json), `height` (default 240) | `Plugin3DViewportContainer` with the node's mesh, `jointLocalPose` and the scene's `cameraDistance`, and the scene's nodes listed under it | `picked` with `{"node": <name>}` when a listed node is clicked |
| `divider` | none | a thin rule | none |

A kind the editor does not know draws one muted line, `unsupported control <kind>`, and never throws.

**Patches.** `PluginViewPatchOp.set(id, props)` merges props into one control; `PluginViewPatchOp.replace(id, control)`
replaces it whole. A long job reports progress by patching a `progress` and a `log` control:

```dart
spec = spec.apply(const PluginViewPatch([
  PluginViewPatchOp.set('job', {'value': 0.6, 'text': 'Placing instances'}),
  PluginViewPatchOp.set('log', {'lines': ['started', 'placed 72 / 120']}),
]));
```

**Limitations.** The 3D preview shows one scene node at a time (the first, or the one picked in the list under it);
node `location`/`rotation`/`scale` and the scene's `cameraTarget` are not applied, the viewport frames the shown mesh.
Picking is through the node list, not by clicking in the viewport. A button icon is drawn as its glyph from the named
font (no runtime `IconData`, so the release build can still tree-shake icon fonts); a glyph the editor never uses
itself may be missing from a tree-shaken release build.

### Files

One widget per kind, each in its own file: `plugin_section_control.dart` (also `PluginControlColumn`),
`plugin_row_control.dart`, `plugin_text_control.dart`, `plugin_text_field_control.dart`,
`plugin_number_field_control.dart`, `plugin_bool_field_control.dart`, `plugin_enum_field_control.dart`,
`plugin_asset_ref_field_control.dart` (also `PluginProjectAssets.scan`, the background-isolate project scan),
`plugin_color_field_control.dart`, `plugin_button_control.dart`, `plugin_progress_control.dart`,
`plugin_log_control.dart`, `plugin_image_control.dart`, `plugin_preview3d_control.dart`,
`plugin_divider_control.dart`, `plugin_unsupported_control.dart`. `plugin_control_cache.dart` (`PluginControlCache`)
maps kinds to widgets and reuses unchanged ones; `plugin_view_scope.dart` holds `PluginViewHost` (view id, project
directory, `emit`), `PluginViewScope`, the typed prop readers, `pluginControlEquals` and `PluginFieldRow`.

---

[Previous: App shell and shared UI (continued, part 1)](core-continued.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Main editor: views](main-editor-views.md)
