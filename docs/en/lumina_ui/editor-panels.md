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
| Viewport | the preview scene (`LuminaUmgViewport`, `viewport_*` nodes) | On Picked, Gizmo Preview / Commit / Cancel, Camera Changed, Scene Ready, Asset Load Failed |

Tree and list rows are the Outliner's (24 px, an indent per depth, chevrons, the selection bar, hover tint); Ctrl
toggles and Shift extends the selection. The Asset Picker element is the editor's `EditorAssetPicker`. Timeline,
table and canvas widgets come later as native editor widgets.

## The editor function library

`EditorPanelLibrary` registers `editorOnly` nodes (category `Editor|…`) in the Blueprint function registry. Calls run on
the UI isolate and return at once; disk or process work is a latent node (Completed / Failed) whose work runs async.
Writes need the panel's declared capability (the validator rejects a node whose capability is not declared):

- **Selection**: Get Selected Actors, Select Actors, Clear Selection; event On Editor Selection Changed.
- **Level** (writes need `level`): Get Level Actors (class / label filter), Get Level Actor Tree (Tree View items by
  type), Get Actor Label, Get / Set Actor Transform, Get / Set Component Property, Add Actor From Asset, Remove Actors,
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
  dismissed), Close This Panel (Result Json), Set / Get Element State, Get Project Name, Is Play Active, Get / Set
  Plugin Setting (`PluginStorage`), Get / Set Project Plugin Setting (`.lmproject` `plugin_settings`, which the plugin
  process receives as `pluginSettings`).
- **Plugin Process** (`process`, plugin panels only): Call Plugin Process (Method, Args Json) → Completed (Result) /
  Failed (Error Code, Error Message) with the 30 s call timeout, failing at once with `unavailable` while the process is
  down; Get Plugin Process State; events On Plugin Process Event (its Name setting filters) and On Plugin Process State
  Changed (running, stopped, crashed, restarting).
- **Json** (`lumina`): Make Json Object / Array, Json Get String / Number / Bool / Json / Array, Json Set Field, Json
  Has Field, Parse Json (Failed with the error), Json To String.

## The plugin process

The process sets element states directly with `PluginProcessContext.patchPanel(panel, ops)` (`host.panelState`):
`patchPanel('content/EPW_Tools.lmas', [PluginPanelStateOp('StatusText', {'text': 'Ready'})])` reaches every open
instance of that panel without running its graph. `EditorPanelLinks` applies patches at most 30 times a second per
panel, coalescing a burst; unknown elements are logged once. `context.emit(name, data)` is what On Plugin Process
Event receives.

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
