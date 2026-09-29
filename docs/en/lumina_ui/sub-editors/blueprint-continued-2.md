[Türkçe](../../../tr/lumina_ui/sub-editors/blueprint-continued-2.md)

# Blueprint editor (continued, part 2)

Continuation of Blueprint editor: the remaining public files under `lib/ui/features/sub_editors/views/blueprint/`, `lib/ui/features/sub_editors/views/blueprint/graph_canvas/`, `lib/ui/features/sub_editors/views/blueprint/timeline/`, `lib/ui/features/sub_editors/views/blueprint_enum/`, `lib/ui/features/sub_editors/views/blueprint_interface/`. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/blueprint/graph_canvas.dart`](#libuifeaturessub_editorsviewsblueprintgraph_canvasdart)
- [`lib/ui/features/sub_editors/views/blueprint/graph_canvas/painters.dart`](#libuifeaturessub_editorsviewsblueprintgraph_canvaspaintersdart)
- [`lib/ui/features/sub_editors/views/blueprint/my_blueprint_panel.dart`](#libuifeaturessub_editorsviewsblueprintmy_blueprint_paneldart)
- [`lib/ui/features/sub_editors/views/blueprint/node_palette.dart`](#libuifeaturessub_editorsviewsblueprintnode_palettedart)
- [`lib/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart`](#libuifeaturessub_editorsviewsblueprintpin_literal_editordart)
- [`lib/ui/features/sub_editors/views/blueprint/signature_editor.dart`](#libuifeaturessub_editorsviewsblueprintsignature_editordart)
- [`lib/ui/features/sub_editors/views/blueprint/timeline/timeline_editor.dart`](#libuifeaturessub_editorsviewsblueprinttimelinetimeline_editordart)
- [`lib/ui/features/sub_editors/views/blueprint_enum/enum_sub_editor.dart`](#libuifeaturessub_editorsviewsblueprint_enumenum_sub_editordart)
- [`lib/ui/features/sub_editors/views/blueprint_interface/interface_sub_editor.dart`](#libuifeaturessub_editorsviewsblueprint_interfaceinterface_sub_editordart)

## `lib/ui/features/sub_editors/views/blueprint/graph_canvas.dart`

### `class BlueprintComponentDrag`

What a My Blueprint variable row carries when dragged onto a graph. A My Blueprint component dragged onto the graph: drops a `Get <name>`.

**Constructors:**

- `const BlueprintComponentDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintElementDrag`

A widget variable's element dragged onto the graph: drops `Get <variable>` → `Get <element>`, wired.

**Constructors:**

- `const BlueprintElementDrag(this.variable, this.element)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `variable` | `final String variable` |  |
| `element` | `final String element` |  |

### `class BlueprintVariableDrag`

**Constructors:**

- `const BlueprintVariableDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintDispatcherDrag`

A My Blueprint event dispatcher dragged onto the graph: offers Call / Bind / Unbind / Unbind All / Assign.

**Constructors:**

- `const BlueprintDispatcherDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintLocalVariableDrag`

A function's local variable dragged onto its graph: Get or Set.

**Constructors:**

- `const BlueprintLocalVariableDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintLevelActorDrag`

A placed actor of the level dragged onto a Level Blueprint's graph (the Level Actors list, the outliner's actors): drops a reference to it, `Get <Actor>`.

**Constructors:**

- `const BlueprintLevelActorDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintWidgetVariableDrag`

A widget's `Is Variable` element dragged onto its graph (My Blueprint's Widgets): drops `Get <Element>`.

**Constructors:**

- `const BlueprintWidgetVariableDrag(this.name)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |

### `class BlueprintGraphCallDrag`

A My Blueprint function or macro dragged onto a graph: drops its call.

**Constructors:**

- `const BlueprintGraphCallDrag(this.name, {this.isMacro = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `isMacro` | `final bool isMacro` |  |

### `class BlueprintGraphCanvasActions`

Graph actions a [BlueprintGraphCanvas] hands to its host editor: collapsing the selection, expanding a call node, opening a Timeline's curve tab, opening a called function's / macro's graph. Null callbacks hide the actions.

**Constructors:**

- `const BlueprintGraphCanvasActions({this.onCollapse, this.onExpand, this.onOpenTimeline, this.onOpenGraph})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `onCollapse` | `final void Function({required bool toMacro, required bool named})? onCollapse` |  |
| `onExpand` | `final void Function(String nodeId)? onExpand` |  |
| `onOpenTimeline` | `final void Function(String nodeId)? onOpenTimeline` |  |
| `onOpenGraph` | `final void Function(String name, {required bool isMacro})? onOpenGraph` |  |

### `class BlueprintNodeLayout`

Where a node's parts sit, in canvas units. One deterministic layout is shared by the node widgets, the wire painter and pin hit-testing, so a wire always starts exactly on its pin.

**Constructors:**

- `factory BlueprintNodeLayout.of(BlueprintGraphEditor editor, LuminaBlueprintNode node)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `headerHeight` | `static const double headerHeight` |  |
| `bannerHeight` | `static const double bannerHeight` |  |
| `settingsHeight` | `static const double settingsHeight` |  |
| `padTop` | `static const double padTop` |  |
| `padBottom` | `static const double padBottom` |  |
| `rowHeight` | `static const double rowHeight` |  |
| `anchorInset` | `static const double anchorInset` |  |
| `node` | `final LuminaBlueprintNode node` |  |
| `pins` | `final BlueprintResolvedPins pins` |  |
| `problems` | `final List<BlueprintNodeProblem> problems` |  |
| `hasSettings` | `final bool hasSettings` |  |
| `connectedInputs` | `final Set<String> connectedInputs` |  |
| `width` | `final double width` |  |
| `bodyHeight` | `final double bodyHeight` | Height of the editor's [BlueprintGraphEditor.nodeBody] widget. |
| `rerouteSize` | `static const double rerouteSize` |  |
| `commentTitleHeight` | `static const double commentTitleHeight` |  |
| `isComment` | `bool get isComment` |  |
| `isReroute` | `bool get isReroute` |  |
| `showsLabel` | `static bool showsLabel(LuminaBlueprintPinSpec p)` | Plain exec pins are unlabelled. |
| `hasBanner` | `bool get hasBanner` |  |
| `rows` | `int get rows` |  |
| `bodyTop` | `double get bodyTop` |  |
| `height` | `double get height` |  |
| `rect` | `Rect get rect` |  |
| `commentTitleRect` | `Rect get commentTitleRect` | The comment's draggable title bar, in canvas units. |
| `pinCenter` | `Offset? pinCenter(String pinId, {required bool output})` |  |

### `class BlueprintGraphCanvas`

The Blueprint graph canvas: nodes from lumina's library, colour-coded typed pins, Bezier wires, pan / zoom / marquee, drag-to-wire with a context-sensitive palette on empty space, inline literals, My Blueprint variable drops (Ctrl: Get, Alt: Set), node banners for missing actions and deprecated nodes, and Compiler Results navigation. The Blueprint editor's event graph and the Animation Blueprint editor's event and rule graphs all use this one widget.

**Constructors:**

- `const BlueprintGraphCanvas({super.key, required this.editor, this.graphLabel, this.actions = const BlueprintGraphCanvasActions()})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `editor` | `final BlueprintGraphEditor editor` |  |
| `graphLabel` | `final String? graphLabel` | Shown faintly in the corner (`EventGraph`, `Rule: Idle → Walk`). |
| `actions` | `final BlueprintGraphCanvasActions actions` | Collapse / expand / open-tab actions the host editor provides. |

### `class BlueprintGraphCanvasState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `panOffset` | `Offset get panOffset` |  |
| `zoom` | `double get zoom` |  |

## `lib/ui/features/sub_editors/views/blueprint/graph_canvas/painters.dart`

### `class BlueprintExecPinPainter`

The exec pin's arrow: a right-pointing pentagon drawn as an outline while the pin is unwired and filled once it is wired.

**Constructors:**

- `const BlueprintExecPinPainter({required this.filled, required this.color})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `filled` | `final bool filled` |  |
| `color` | `final Color color` |  |

## `lib/ui/features/sub_editors/views/blueprint/my_blueprint_panel.dart`

### `typedef BlueprintNamedRowActions`

One named row of a My Blueprint list (a function, macro or dispatcher).

### `class BlueprintMyBlueprintSections`

The Graphs / Functions / Macros / Event Dispatchers / Local Variables sections of My Blueprint, wired to the Blueprint editor; absent for hosts without them (the Animation Blueprint editor).

**Constructors:**

- `const BlueprintMyBlueprintSections({required this.graphs, required this.activeGraph, required this.onOpenGraph, required this.functions, required this.macros, r...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `graphs` | `final List<BlueprintGraphRef> graphs` |  |
| `activeGraph` | `final BlueprintGraphRef activeGraph` |  |
| `onOpenGraph` | `final ValueChanged<BlueprintGraphRef> onOpenGraph` |  |
| `functions` | `final List<String> functions` |  |
| `macros` | `final List<String> macros` |  |
| `dispatchers` | `final List<String> dispatchers` |  |
| `selectedFunction` | `final String? selectedFunction` |  |
| `selectedMacro` | `final String? selectedMacro` |  |
| `selectedDispatcher` | `final String? selectedDispatcher` |  |
| `functionActions` | `final BlueprintNamedRowActions functionActions` |  |
| `macroActions` | `final BlueprintNamedRowActions macroActions` |  |
| `dispatcherActions` | `final BlueprintNamedRowActions dispatcherActions` |  |
| `localsOf` | `final String? localsOf` | The local variables of the function whose graph is active, or null. |
| `localVariables` | `final List<LuminaBlueprintVariable> localVariables` |  |
| `onAddLocal` | `final VoidCallback? onAddLocal` |  |
| `onRenameLocal` | `final bool Function(String oldName, String newName)? onRenameLocal` |  |
| `onSetLocalType` | `final void Function(String name, String typeName)? onSetLocalType` |  |
| `onDeleteLocal` | `final ValueChanged<String>? onDeleteLocal` |  |

### `class BlueprintMyBlueprintPanel`

The My Blueprint panel: the graphs (optional [graphs] section), the variables, each with a type chip whose picker groups Basic / Object / Widgets / Widget Elements / Components / Actors from the [context], the Components section (draggable `Get <name>` nodes) and, for a selected widget variable, its searchable elements. A variable dragged onto a graph places a Get or Set node; renaming renames its nodes; deleting asks first and removes its nodes.

**Constructors:**

- `const BlueprintMyBlueprintPanel({super.key, required this.variables, this.context = const LuminaBlueprintTypeContext(), required this.selected, required this.on...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `variables` | `final List<LuminaBlueprintVariable> variables` |  |
| `context` | `final LuminaBlueprintTypeContext context` | The document's type context: widget classes, components and actor classes the type picker and the Components section list. |
| `selected` | `final String? selected` |  |
| `onSelect` | `final ValueChanged<String> onSelect` |  |
| `onAdd` | `final VoidCallback onAdd` |  |
| `onRename` | `final bool Function(String oldName, String newName) onRename` |  |
| `onSetType` | `final void Function(String name, String typeName) onSetType` |  |
| `onDelete` | `final ValueChanged<String> onDelete` |  |
| `usageCount` | `final int Function(String name) usageCount` |  |
| `graphs` | `final List<Widget> graphs` | Extra sections above the variables (the Animation Blueprint's graphs). |
| `sections` | `final BlueprintMyBlueprintSections? sections` | The Blueprint editor's graph / function / macro / dispatcher sections. |

### `class BlueprintMyBlueprintPanelState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `visibleElements` | `List<LuminaBlueprintWidgetElement>? get visibleElements` | The elements of the selected widget variable's class matching the search, or null when the selection is not a widget variable. |
| `beginRename` | `void beginRename(String name, {String kind = 'var'})` | Starts renaming [name] in place. |

## `lib/ui/features/sub_editors/views/blueprint/node_palette.dart`

### `class BlueprintNodePalette`

The node palette ("All Actions for this Blueprint"): lumina's node library grouped by category and searchable by title, category and keywords. Opened from a pin drag it is "context sensitive": only nodes that can take the wire are listed.

**Constructors:**

- `const BlueprintNodePalette({super.key, required this.entries, required this.onSelect, required this.onClose, this.context = const LuminaBlueprintTypeContext(),...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entries` | `final List<BlueprintPaletteEntry> entries` |  |
| `from` | `final BlueprintPinRef? from` |  |
| `fromLabel` | `final String? fromLabel` |  |
| `fromTypeLabel` | `final String? fromTypeLabel` | The dragged pin's type name and colour; the Blueprint style of [from]'s type when null. |
| `fromColor` | `final Color? fromColor` |  |
| `onSelect` | `final ValueChanged<BlueprintPaletteEntry> onSelect` |  |
| `onClose` | `final VoidCallback onClose` |  |
| `context` | `final LuminaBlueprintTypeContext context` | The graph's type context, for ordering a pin drag's rows by class. |

### `class BlueprintNodePaletteState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `visibleEntries` | `List<BlueprintPaletteEntry> get visibleEntries` |  |

## `lib/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart`

### `class BlueprintPinLiteralEditor`

The inline editor for an unconnected input pin's literal, by pin type: a switch for booleans, a number field for integers and floats, a text field for strings and names, X/Y for Vector2D, X/Y/Z (cm) for vectors, Roll/Pitch/Yaw (°) for rotators, a swatch plus hex field for colours (stored `[r, g, b, a]`), the location / rotation / scale triple for transforms, a read-only struct badge for hit results and a dropdown (or text) for enums. Each field commits on Enter or when it loses focus, so one typed value is one undo step.

**Constructors:**

- `const BlueprintPinLiteralEditor({super.key, required this.keyPrefix, required this.type, required this.value, required this.onCommit, this.options, this.expande...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `keyPrefix` | `final String keyPrefix` |  |
| `type` | `final LuminaPinType type` |  |
| `value` | `final Object? value` |  |
| `onCommit` | `final ValueChanged<Object?> onCommit` |  |
| `expanded` | `final bool expanded` | Wider fields for the Details panel. |
| `options` | `final List<String>? options` | Optional dropdown choices (e.g. Widget Blueprint classes for Create Widget). |
| `supports` | `static bool supports(LuminaPinType type)` |  |
| `inlineWidth` | `static double inlineWidth(LuminaPinType type, [List<String>? options])` | Width the inline editor takes on a node, for the node's layout. |
| `colorToHex` | `static String colorToHex(List<double> c)` | `[r, g, b, a]` (0–1) as `#RRGGBBAA`. |
| `hexToColor` | `static List<double>? hexToColor(String text)` | `#RRGGBB` or `#RRGGBBAA` (with or without `#`) as `[r, g, b, a]`; null when the text is not a colour. |

## `lib/ui/features/sub_editors/views/blueprint/signature_editor.dart`

### `class BlueprintSignatureEditor`

A parameter list of a signature: the inputs or outputs of a function, macro, dispatcher, custom event or interface function. Each row edits the parameter's name, type (the type pill's groups, plus `Exec` for macro pins) and default; `+` adds one, `×` removes one; every change hands the whole list back through [onChanged], which the owner commits as one undo step.

**Constructors:**

- `const BlueprintSignatureEditor({super.key, required this.title, required this.keyPrefix, required this.parameters, required this.onChanged, this.context = const...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `title` | `final String title` |  |
| `keyPrefix` | `final String keyPrefix` |  |
| `parameters` | `final List<LuminaBlueprintVariable> parameters` |  |
| `onChanged` | `final ValueChanged<List<LuminaBlueprintVariable>> onChanged` |  |
| `context` | `final LuminaBlueprintTypeContext context` |  |
| `allowExec` | `final bool allowExec` |  |
| `showDefaults` | `final bool showDefaults` |  |

## `lib/ui/features/sub_editors/views/blueprint/timeline/timeline_editor.dart`

### `class BlueprintTimelineEditor`

The Timeline tab: the node's length / loop / auto-play, its float / vector / colour tracks (add, rename, delete) and a curve canvas per track where keys are added (click), moved (drag), deleted and given an interpolation. Everything edits the Timeline node's literals through the view model, so the graph node's track outputs and the `.lmas` follow at once.

**Constructors:**

- `const BlueprintTimelineEditor({super.key, required this.viewModel, required this.nodeId})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final BlueprintEditorViewModel viewModel` |  |
| `nodeId` | `final String nodeId` |  |

### `class BlueprintTimelineEditorState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `vm` | `BlueprintEditorViewModel get vm` |  |
| `nodeId` | `String get nodeId` |  |
| `selectedKey` | `({String track, int index})? get selectedKey` |  |
| `trackColors` | `static const List<Color> trackColors` |  |
| `setKey` | `void setKey(String track, int index, LuminaTimelineKey key)` | Replaces one key of [track]; the view model sorts and clamps. |
| `addKey` | `void addKey(String track, double time, double value)` | Adds a key at ([time], [value]) to [track] and selects it. |
| `deleteKey` | `void deleteKey(String track, int index)` |  |

## `lib/ui/features/sub_editors/views/blueprint_enum/enum_sub_editor.dart`

### `class BlueprintEnumSubEditor`

The Enumeration sub-editor: the enum's ordered values with add, rename (double-click or the pencil), remove, move up / down; Save writes the `.lmas` and rewires the project's `Switch on <enum>` cases by value name.

**Constructors:**

- `const BlueprintEnumSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final BlueprintEnumViewModel? viewModel` |  |

### `class BlueprintEnumSubEditorState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEnumViewModel get viewModel` |  |

## `lib/ui/features/sub_editors/views/blueprint_interface/interface_sub_editor.dart`

### `class BlueprintInterfaceSubEditor`

The Blueprint Interface sub-editor: the interface's functions with their signatures. A function with outputs is implemented as a Blueprint function; one without as an event.

**Constructors:**

- `const BlueprintInterfaceSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final BlueprintInterfaceViewModel? viewModel` |  |

### `class BlueprintInterfaceSubEditorState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintInterfaceViewModel get viewModel` |  |

---

[Previous: Blueprint editor (continued, part 1)](blueprint-continued.md) | [Up: Sub-editors](index.md) | [Next: Build manager](build-manager.md)
