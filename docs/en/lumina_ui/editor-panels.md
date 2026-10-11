[Türkçe](../../tr/lumina_ui/editor-panels.md)

# Editor panels (Widget Blueprints run by the editor)

An **editor panel** is a Widget Blueprint (`.lmas`, designer tree + graph) marked with an `editorPanel` block. Lumina
Studio finds it in an enabled plugin's `content/` or in the open project's `contents/`, compiles its graph into the
editor's Blueprint VM in memory and docks it as a side panel, a bottom tab, a workspace tab, a dialog or a Project
Settings section: no Dart compile, no project editor build, no restart. A plugin made only of content (editor
panels) plus, optionally, a process part is added, updated and removed while the editor runs. File paths are relative
to the `lumina_ui/` package unless they name another package.

## The `editorPanel` block

`LuminaEditorPanelInfo` (`lumina_core`, `formats/editor_panel_info.dart`) parses, validates and writes it:

```json
{"title": "Prop Tools", "icon": "box", "dock": "right", "defaultAlwaysVisible": false,
 "contentDroppable": true, "contentBrowserOpened": false, "menuPath": "Plugins/Prop Tools/Prop Tools",
 "minWidth": 300, "minHeight": 200, "capabilities": ["level", "assets", "process", "mcp"]}
```

- `dock`: `left` / `bottom` (bottom-panel tabs, like plugin panels), `right` (the right dock), `tab` (a workspace
  tab, restored with the layout), `dialog` (modal; opened only by `Open Editor Panel` from a panel of the same owner,
  never listed in a menu), `projectSettings` (the owning plugin's Project Settings ▸ Plugins section).
- An unknown dock or capability, or an empty title, is a `FormatException` naming the field. Only the fields an
  author wrote are written back, so a block round-trips byte for byte. `capabilityHash` keys trust decisions.
- `minWidth` / `minHeight` default to 200 px; `menuPath` defaults to `Plugins/<Plugin>/<Title>` for a plugin's panel
  and `Window/Editor Panels/<Title>` for a project's.

## Discovery and compiling

- `EditorPanelCatalog` (`lumina_editor_data`) scans the sources on a background isolate and watches them (live
  reload). Sources: every enabled plugin with `can_contain_content` (`<plugin>/content/**`), then the project's
  `contents/**`. A panel's id is `<plugin name>/<asset path>` or `project/<asset path>`; a plugin panel whose title a
  project panel also has is suffixed with the plugin's friendly name.
- `EditorPanelHost` (`lib/ui/core/editor_panels/editor_panel_host.dart`, reached as `EditorViewModel.editorPanels`)
  compiles each entry (`EditorPanelRuntime.compile` → `LuminaBlueprintClass.forEditorPanel`), opens and closes
  instances, raises the editor's events in them and live-reloads them. `EditorViewModel.startEditorPanels()` starts it
  once the plugins are scanned (the editor does this itself when it runs with timers).
- A panel whose graph has errors does not run: its slot lists the errors with **Open in Widget Editor**.

## Running

- Scripts live in the editor registry (`LuminaUserWidgets.editor`): starting Play (which clears
  `LuminaUserWidgets.game`) never touches a docked panel, and a panel never receives game Tick.
- They are hidden actors in a private headless world (`EditorPanelWorld`): no scene, never rendered or saved, ticked
  only while at least one panel is shown, so Delay, timers, timelines and Event Tick work. Level actors are never in
  it; panels reach them through the level library.
- Lifecycle: Pre Construct + Construct when a panel opens, Destruct when it closes (the right dock's close button,
  Close This Panel, the plugin disabled). A bottom tab another tab covers keeps running without Tick.
- **Step budget**: one event that runs more than 1,000,000 nodes or longer than 250 ms is stopped; the panel shows
  "Stopped: <event> ran too long · Reload" and the editor stays responsive.
- **Live reload**: saving the asset (or Compile in its designer) swaps the running instance within 500 ms: Destruct on
  the old script, element states kept where an element's name and type are unchanged (only what the panel changed at
  run time overrides the new designer values), graph variables kept where name and type match, Construct on the new
  one. A save with errors keeps the last good version running under an error banner. Enabling, disabling or updating a
  plugin adds, removes or reloads its panels the same way.

## Docking

`EditorPanelDocking` (`editor_panel_docking.dart`) registers each owner's panels through
`PluginExtensionRegistry.setEditorPanelContributions` (kept apart from the plugin's own shell and process
contributions):

- `left` / `right` / `bottom`: `EditorPanelDescriptor`s, so they dock exactly like plugin panels (right dock with the
  "Always" option, bottom tabs, visibility in the layout). **Window ▸ Editor Panels** lists every docked panel; a
  plugin's panel also gets its `Plugins/<Plugin>/<Title>` menu item.
- `tab`: an `EditorTabDescriptor`; `contentBrowserOpened` docks the Content Browser at its bottom, otherwise the
  Content Drawer toggle (the status bar's folder button) and its pin are offered. Open tabs are remembered in the
  layout and reopened.
- `dialog`: `showEditorPanelDialog` opens it modally (sized from `minWidth` / `minHeight`; Escape dismisses).
- `projectSettings`: a `ProjectSettingsSection` of the owning plugin.
- Panels render in the editor theme (`EditorColors.sidebar`, `card`, `cardHeader`, `border`, editor font sizes), never
  the project's game theme, through `UmgRuntimeView(editorTheme: true)`.
- **Content Browser drops**: in a `contentDroppable` panel, an element flagged "Accepts Asset Drops"
  (`acceptsAssetDrops`, type filter `assetDropTypes`) is a `DragTarget<RealAssetInfo>`; a drop fires its
  `On Asset Dropped (Asset Path, Asset Type)`.

## The editor widget set

The designer's **Editor** palette section, offered only for an editor panel (`EditorWidgetSet`,
`lib/ui/core/editor_panels/widgets/`):

| Element | State keys | Events |
|---|---|---|
| Editor Section | `title`, `expanded` | On Section Toggled |
| Property Row | `label`, `labelWidth` | — |
| Tree View | `items` (`[{id, label, icon, children}]`), `selected`, `expanded`, `multiSelect` | On Item Selected, Double Clicked, Context Menu, Expanded |
| List View | `items`, `selected`, `multiSelect` | On Item Selected, Double Clicked, Context Menu |
| Asset Picker | `value`, `typeFilter`, `placeholder`, `allowClear` | On Asset Picked |
| Resizable Split | `orientation`, `split`, `minFirst`, `minSecond` | — |
| Editor Toolbar | — | — |
| Status Line | `text`, `tone` | — |
| Viewport | the preview scene (`LuminaUmgViewport`, `viewport_*` nodes; project assets (`contents/…`) are read from the open project, a mesh the graph adds is framed once loaded while the camera is untouched, `Play Animation File` reads the files a plugin process writes) | On Picked, Gizmo Preview / Commit / Cancel, Camera Changed, Scene Ready, Asset Load Failed, Asset Dropped (when it accepts drops) |
| Timeline | `fps`, `length`, `playhead`, `playing`, `loop`, `zoom`, `scroll`, `tracks`, `clips`, `keys`, `range`, `snap`, `boundViewport` | On Playhead Changed, Play State Changed, Clip Preview / Commit / Cancel, Clip Text Committed, Key Preview / Commit / Cancel, Key Added, Keys Deleted, Selection Changed, Track Context Menu |
| Table | `columns`, `rows`, `sort`, `selection`, `selected`, `filter` | On Cell Committed, Row Selected, Row Double Clicked, Row Context Menu, Sort Changed |
| Canvas | `space`, `background`, `items`, `viewBox` | On Item Clicked, Item Drag Preview / Commit / Cancel, Item Hover, Background Clicked |

Tree and list rows are the Outliner's (24 px, an indent per depth, chevrons, the selection bar, hover tint); Ctrl
toggles and Shift extends the selection. The Asset Picker element is the editor's `EditorAssetPicker`.

## Timeline, Table and Canvas (native editor widgets)

Three kinds of editor UI interact per frame and cannot be built from elements and graphs: a timeline, a table with
inline editing and a 2D canvas. They are written once in `lib/ui/core/editor_panels/widgets/` (`timeline/`, `table/`,
`canvas/`) and used both as editor panel elements (`EditorNativeElements`, the Editor palette entries Timeline, Table,
Canvas) and as the JSON spec controls `timeline`, `table` and `canvas` of a plugin process's declarative panel (thin
adapters in `lib/ui/core/widgets/plugin_view/`). Their state is JSON-plain (`PluginTimelineState`,
`PluginTableState`, `PluginCanvasState` in `lumina_plugin_protocol`; frames are integers, seconds derive from `fps`).

**Interaction contract** (`widgets/interaction/editor_interaction.dart`): every drag, scrub, resize and hover is
applied in the widget at once; it reports throttled **preview** events (at most 30 a second, `EditorPreviewThrottle`),
one **commit** on release and **cancel** on Escape (the value snaps back). Playback advances the playhead locally at
the state's fps on its own painter layer; only play, pause, loop changes and the playhead on release or a step are
reported, never a playback frame. A slow graph or process never stalls a drag. In an editor panel the events are the
element's events and a commit is written back into the element state; in a JSON spec they are `PluginViewEvent`s with
`phase` and an edit waits for the process's patch (10 s, then it reverts with a toast).

- **Timeline**: track headers (Lucide icon + label) under group headers, a ruler in frames and seconds, clip blocks
  with their text, keyframe glyphs (`diamond`, `circle`, `square`), the selection in the editor's selection colour, a
  transport bar (step back, play / pause, step forward, loop, the frame / seconds readout, fps). Move and resize clips
  within `minLength` / `maxLength` (frames, snapped to `snap`), double-click a clip with `editableText` to edit its
  text, drag keys (Shift adds to the selection, a drag on empty space box-selects), double-click a keys track to add a
  key, Delete removes the selected keys, Space plays, ← / → step, Home / End jump, Ctrl + wheel zooms around the
  cursor, the wheel or a middle drag pans. Each painter is its own file (`timeline_ruler_painter.dart`,
  `timeline_tracks_painter.dart`, `timeline_playhead_painter.dart`).
- **Viewport binding**: `boundViewport: {element, node}` makes the playhead drive that Viewport element's node: the
  node's animation time is set on the Viewport's live preview every frame the playhead moves
  (`LuminaViewportSceneRuntime.setLocalAnimationTime`, `EditorPanelViewportDriver`), with no description diff, no
  graph run and no process message; when the playhead stops, the time is written into the scene description
  (`animation.time`, not playing), so it is kept.
- **Table**: a sticky header with sort chevrons and resizable columns, an optional filter row, group rows, 24 px rows
  virtualised (only the visible rows build; 2,000 rows sort in a few milliseconds), `tone` (`warning`, `error`) on the
  first cell and a left bar, a row `tooltip`. Cells by `kind`: `text`, `number`, `color` edit in place on a double
  click (Enter commits, Escape cancels), `bool` is a check box, `enum` a shadcn `Select`, `assetRef` the editor's
  `EditorAssetPicker` filtered by the column's `typeFilter`. Selection is `single` or `multi` (Ctrl toggles, Shift
  takes the range). On Cell Committed carries the value (`Value` Json) and its text (`Text`).
- **Canvas**: items `line`, `polyline`, `rect`, `circle`, `path` (SVG path data: M, L, H, V, C, Q, Z), `text` and
  `image` (a project path, a texture `.lmas` or a plugin's file) in `local` pixels or `normalized` 0–1 space, with
  `stroke`, `fill`, `width`, `hit`, `draggable` and `cursor`; an optional `viewBox` (`panZoom`: middle drag and wheel
  pan, Ctrl + wheel zooms). Each item paints on its own layer and the list is diffed by id, so a change to one item
  repaints only that item. Positions in events are in the item space (`X`, `Y`).

Graphs set the dynamic fields with Set Element State or the typed helpers **Timeline Set Clips**, **Timeline Set
Keys**, **Timeline Set Playhead**, **Table Set Rows** and **Canvas Set Items** (`Editor|Panels|Native Widgets`; a
malformed value is logged and not written); a plugin process pushes a whole clip list or row list with one
`host.panelState` op. The Details panel edits the static fields (tracks, fps, length, snap, boundViewport; columns,
selection, filter; space, background, items). A game Widget Blueprint that contains one of the editor widgets is a
validator error; the game code generator never emits them.

The sequencer's and the animation editor's own timelines (`sub_editors/views/sequencer/timeline_widget.dart`,
`widgets/animation_dope_sheet/`, `views/animation/toolbar_timeline.dart`) keep their view-model-bound widgets. What
the shared timeline lacks for them: curve editing (tangents, value curves), audio waveforms, sub-tracks per property
and section blending; moving them is a later refactor.

## The editor function library

`EditorPanelLibrary` registers `editorOnly` nodes (category `Editor|…`) in the Blueprint function registry. Calls run on
the UI isolate and return at once; disk or process work is a latent node (Completed / Failed) whose work runs async.
Writes need the panel's declared capability (the validator rejects a node whose capability is not declared):

- **Selection**: Get Selected Actors, Select Actors, Clear Selection; event On Editor Selection Changed.
- **Level** (writes need `level`): Get Level Actors (class / label filter), Get Level Actor Tree (Tree View items by
  type), Get / Set Actor Label, Get / Set Actor Transform, Get / Set Component Property, Add Actor From Asset, Remove Actors,
  Focus Viewport On Actors, Save Level; event On Level Changed.
- **Transactions**: Begin Transaction (Label) → transaction, End Transaction, Cancel Transaction. Every level or asset
  edit inside one is one Edit ▸ Undo step named by the label; a transaction left open when the event finishes is
  ended by the host with a warning in the Output Log.
- **Assets** (writes need `assets`): Get Selected Assets, List Assets (Folder, Type Filter, Recursive), Get Asset Info,
  Open Asset Editor, Rename / Move / Duplicate / Delete Asset (the reference-safe operations), Save Asset Json; event On
  Content Browser Selection Changed.
- **Content Browser**: Sync Content Browser To Asset, Get Content Browser Folder, Show Content Drawer.
- **Menus**: Add Panel Menu Item (Path, Label, Event Name), Show Context Menu (Items) → Chosen (Item Id) / Cancelled.
- **Notifications**: Show Toast, Show Progress / Finish Progress (bars at the bottom of the panel), Log To Output, Show
  Confirm Dialog → Confirmed / Cancelled.
- **Asset Picker**: Pick Asset (Type Filter) → Picked (Asset Path) / Cancelled, opening the editor's asset picker popup
  over the panel. A text field that looks like an asset path is a "use Asset Picker" warning.
- **Panels**: Open Editor Panel (Closed → Result Json; a dialog answers with its Close This Panel Json, null when
  dismissed), Close This Panel (Result Json), Set / Get Element State (a Button's `style`, `primary` / `destructive` / …, is
  element state too), Get Project Name, Is Play Active, Get / Set
  Plugin Setting (`PluginStorage`), Get / Set Project Plugin Setting (`.lmproject` `plugin_settings`, which the plugin
  process receives as `pluginSettings`).
- **Plugin Process** (`process`, plugin panels only): Call Plugin Process (Method, Args Json) → Completed (Result) /
  Failed (Error Code, Error Message) with the 30 s call timeout, failing at once with `unavailable` while the process is
  down; Restart Plugin Process (Completed once it runs again, a manual restart); Get Plugin Process State; events On Plugin Process Event (its Name setting filters) and On Plugin Process State
  Changed (running, stopped, crashed, restarting).
- **Native Widgets**: Timeline Set Clips / Set Keys / Set Playhead, Table Set Rows, Canvas Set Items (see above).
- **Json** (`lumina`): Make Json Object / Array, Json Get String / Number / Bool / Json / Array, Json Set Field, Json
  Has Field, Parse Json (Failed with the error), Json To String.

## The plugin process

The process sets element states directly with `PluginProcessContext.patchPanel(panel, ops)` (`host.panelState`):
`patchPanel('content/EPW_Tools.lmas', [PluginPanelStateOp('StatusText', {'text': 'Ready'})])` reaches every open
instance of that panel without running its graph. `EditorPanelLinks` applies patches at most 30 times a second per
panel, coalescing a burst; unknown elements are logged once. `context.emit(name, data)` is what On Plugin Process
Event receives. `context.openEditorPanel(panel)` opens one of the plugin's panels where it docks (Plugins menu
commands of a process often do). The OpenXR plugin's `EPW_OpenXR` is a complete example: its graph calls the
process's methods, the process patches its status texts and emits `openxr.status` for the rest. The Kimodo kernel
plugin is a whole editor made this way: a workspace tab with a Viewport and a Timeline bound to it, a mapping Table
tab, a weights dialog and a Project Settings section, all state in its process, which patches the timeline's clips and
keys, the Viewport's `scene` and the sidebar values after every change; when the process stops, the tab's graph
disables its inputs and offers Restart Plugin Process.

## Trust

- **Plugin panels** are trusted with their plugin: the confirmation that admits its code (the import confirmation,
  which lists its editor panels and their capabilities, a Marketplace install, enabling it) admits its panels too.
- **Project panels** do not run until the user trusts them: the first open shows a prompt listing each panel with its
  capabilities ("Trust and run" / "Not now"); the decision is stored per user in `<LuminaDataDir>/editor_panel_trust.json`,
  keyed by the project's absolute path and each panel's capability hash. A new panel or one whose capabilities grow
  asks again; moving the project asks again. Untrusted panels show "Not trusted · Review".
- There is no file, network or process node: a panel's writes go through the level proxy and the asset operations,
  both undoable; heavy or privileged work belongs to the plugin process.

## Authoring

- Content Browser ▸ New ▸ **Editor Panel Widget** writes `contents/editor/EPW_NewEditorPanel.lmas` (a section, a
  property row and a button wired to Show Toast). The new-plugin wizard's default template, **Editor panel (Widget
  Blueprint)**, makes a content-only plugin with `content/EPW_<Name>.lmas`.
- The UMG designer's root Details show **Class Settings ▸ Editor Panel** (the block and its capability checkboxes);
  its graph palette is the editor scope; **Run as Editor Panel** saves and opens or reloads it docked. An engine
  plugin's panel opens read-only.
- Editor panels never reach a game: the widget codegen skips them, `Create Widget` of one in a game graph is a
  validator error, and the cook step lists, for the build, the other files of any asset folder holding one
  (`EditorPanelPackaging`).

## MCP

`editor_panels_list`, `editor_panel_open`, `editor_panel_close`, `editor_panel_state`, `editor_panel_interact` and
`editor_panel_screenshot` (see the [MCP tool catalogue](mcp-tools.md)); a custom event marked "Expose to MCP"
(`exposeToMcp`) in a trusted panel with the `mcp` capability is the tool `panel_<owner>_<event>`, its inputs typed from
the event's parameters, answering the panel's state.

## Plugin API

`LuminaEditorContext.editorPanels` (`EditorPanelWidgets`): `all`, `byId`, `isOpen`, `open`, `close`, `changes`, for
in-process plugins that open one of their panels from a command. See the [API reference](../lumina_editor_api/api-reference.md).

---

[Up: lumina_ui](index.md)
