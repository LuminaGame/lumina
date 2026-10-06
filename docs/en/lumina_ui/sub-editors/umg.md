[Türkçe](../../../tr/lumina_ui/sub-editors/umg.md)

# Widget (UMG) designer

The widget designer for game UI: the UMG document model, the designer canvas, palette, hierarchy tree and slot inspector, the view model, and the code generator that turns a widget asset into a Flutter widget class. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/umg/designer_canvas.dart`](#libuifeaturessub_editorsviewsumgdesigner_canvasdart)
- [`lib/ui/features/sub_editors/views/umg/hierarchy_tree.dart`](#libuifeaturessub_editorsviewsumghierarchy_treedart)
- [`lib/ui/features/sub_editors/views/umg/palette.dart`](#libuifeaturessub_editorsviewsumgpalettedart)
- [`lib/ui/features/sub_editors/views/umg/slot_inspector.dart`](#libuifeaturessub_editorsviewsumgslot_inspectordart)
- [`lib/ui/features/sub_editors/views/umg/widget_sub_editor.dart`](#libuifeaturessub_editorsviewsumgwidget_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/umg_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsumg_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/umg_widget_codegen.dart`](#libuifeaturessub_editorsservicesumg_widget_codegendart)
- [`lib/ui/features/sub_editors/models/umg_document.dart`](#libuifeaturessub_editorsmodelsumg_documentdart)
- [`lib/ui/features/sub_editors/services/umg_widget_validator.dart`](#libuifeaturessub_editorsservicesumg_widget_validatordart)
- [`lib/ui/features/sub_editors/services/widget_class_catalog.dart`](#libuifeaturessub_editorsserviceswidget_class_catalogdart)
- [`lib/ui/features/sub_editors/views/umg/umg_components.dart`](#libuifeaturessub_editorsviewsumgumg_componentsdart)
- [`lib/ui/features/sub_editors/views/umg/umg_runtime_view.dart`](#libuifeaturessub_editorsviewsumgumg_runtime_viewdart)
- [`lib/ui/features/sub_editors/views/umg/umg_text_style.dart`](#libuifeaturessub_editorsviewsumgumg_text_styledart)
- [`lib/ui/features/sub_editors/views/umg/umg_theme_helper.dart`](#libuifeaturessub_editorsviewsumgumg_theme_helperdart)

## `lib/ui/features/sub_editors/views/umg/designer_canvas.dart`

### `class UmgDesignerCanvas`

Visual Designer Canvas: renders the document with the real shadcn_flutter widgets (wrapped in [IgnorePointer]) under a design-time overlay that does hit-testing, selection, drag-move, 8-handle resize, snap-to-grid, alignment guides and the resolution/DPI frame.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `createState` | `State<UmgDesignerCanvas> createState() => UmgDesignerCanvasState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class UmgDesignerCanvasState`

`UmgDesignerCanvasState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel get vm` | Getter accessor returning the current value of `vm`. |
| `rectFor` | `Rect? rectFor(String id)` | Last measured rect of [id] in canvas (logical design) coordinates. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(covariant UmgDesignerCanvas oldWidget)` | Executes `didUpdateWidget` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _Guide`

`_Guide`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vertical` | `bool vertical` | Holds the `vertical` property or configuration state. |
| `at` | `double at` | Holds the `at` property or configuration state. |
| `from` | `double from` | Holds the `from` property or configuration state. |
| `to` | `double to` | Holds the `to` property or configuration state. |

### `class _GridPainter`

`_GridPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `gridSize` | `double gridSize` | Holds the `gridSize` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `screenScale` | `double screenScale` | Holds the `screenScale` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(_GridPainter old)` | Executes `shouldRepaint` operation. |

### `class _OverlayPainter`

`_OverlayPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rects` | `Map<String, Rect> rects` | Holds the `rects` property or configuration state. |
| `document` | `UmgDocument document` | Holds the `document` property or configuration state. |
| `selectedId` | `String? selectedId` | Holds the `selectedId` property or configuration state. |
| `hoverId` | `String? hoverId` | Holds the `hoverId` property or configuration state. |
| `guides` | `List<_Guide> guides` | Holds the `guides` property or configuration state. |
| `screenScale` | `double screenScale` | Holds the `screenScale` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(_OverlayPainter old)` | Executes `shouldRepaint` operation. |

### `class _UmgRuntimeTree`

Maps document nodes to real shadcn_flutter widgets (same registry as [UmgWidgetCodegen], executed live).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `onInteraction` | `VoidCallback onInteraction` | Holds the `onInteraction` property or configuration state. |
| `build` | `Widget build(BuildContext context) => _build(vm.document.root)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/umg/hierarchy_tree.dart`

### `class UmgHierarchyTree`

Widget Hierarchy `Tree`: rows are drop targets for palette widgets and for reordering (`Draggable<String>` node ids); the `ContextMenu` offers Wrap With / Replace With / Add Child / Rename / Delete.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `createState` | `State<UmgHierarchyTree> createState() => _UmgHierarchyTreeState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _UmgHierarchyTreeState`

`_UmgHierarchyTreeState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel get vm` | Getter accessor returning the current value of `vm`. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _RenameDialog`

`_RenameDialog`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `node` | `UmgNode node` | Holds the `node` property or configuration state. |
| `createState` | `State<_RenameDialog> createState() => _RenameDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _RenameDialogState`

`_RenameDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/umg/palette.dart`

**Top-level Functions:**

- **`IconData umgIconFor(UmgWidgetType type)`**: Icon per palette type (LucideIcons, shadcn_flutter).

### `class UmgPalette`

Widget palette: `Accordion` categories whose entries are real `Draggable<UmgWidgetType>`s (pointer-anchored so the drop point is the pointer). Double-click places the widget into the selected panel.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/umg/slot_inspector.dart`

### `class UmgSlotInspector`

Right panel: Slot (anchors preset matrix, position/size/ alignment, size-to-content, Z-order — or the honest box/overlay slot fields), Appearance (color & tint, font size, image brush, per-type content) and Widget Events (`[+] OnClicked` …).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `UmgEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _AnchorGlyphPainter`

Draws the little anchor glyph (dot/bar) of a preset.

**Constructors:**
- `_AnchorGlyphPainter(this.preset)`: Initializes `_AnchorGlyphPainter(this.preset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `preset` | `UmgAnchorPreset preset` | Holds the `preset` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(_AnchorGlyphPainter old)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/views/umg/widget_sub_editor.dart`

### `class UMGWidgetSubEditor`

UMG designer: Palette | Hierarchy tabs on the left, the live designer canvas (or the generated-source Graph view) in the center and the slot/appearance/events inspector on the right — all bound to one [UmgEditorViewModel] over a real WIDGET `.lmas`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `LuminaAsset? asset` | Holds the `asset` property or configuration state. |
| `projectDirPath` | `String? projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `viewModel` | `UmgEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<UMGWidgetSubEditor> createState() => _UMGWidgetSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _UMGWidgetSubEditorState`

`_UMGWidgetSubEditorState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModelForTest` | `UmgEditorViewModel get viewModelForTest` | Getter accessor returning the current value of `viewModelForTest`. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/umg_editor_view_model.dart`

### `enum UmgEditorMode`

Designer mode of the center panel.

### `class UmgEditorViewModel`

View model of the UMG designer: one persisted [UmgDocument] inside a real WIDGET `.lmas`, every mutation recorded on its own [TransactionManager], `save()` through `LuminaAsset.toProtoBufferBytes()`, `compile()` through [UmgWidgetCodegen] into the project's `lib/widgets/`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `projectDirPathOverride` | `String? projectDirPathOverride` | Holds the `projectDirPathOverride` property or configuration state. |
| `document` | `UmgDocument get document` | Getter accessor returning the current value of `document`. |
| `isLoaded` | `bool get isLoaded` | Checks current state or capability and returns a boolean value. |
| `selectedId` | `String? get selectedId` | Selects the target actor or asset. |
| `selectedNode` | `UmgNode? get selectedNode` | Selects the target actor or asset. |
| `mode` | `UmgEditorMode get mode` | Getter accessor returning the current value of `mode`. |
| `resolution` | `UmgResolution get resolution` | Getter accessor returning the current value of `resolution`. |
| `dpiScale` | `double get dpiScale` | Getter accessor returning the current value of `dpiScale`. |
| `logicalSize` | `Size get logicalSize` | Getter accessor returning the current value of `logicalSize`. |
| `lastRejectionReason` | `String? get lastRejectionReason` | Getter accessor returning the current value of `lastRejectionReason`. |
| `lastCompile` | `UmgCompileResult? get lastCompile` | Getter accessor returning the current value of `lastCompile`. |
| `compileError` | `String? get compileError` | Getter accessor returning the current value of `compileError`. |
| `textureAssets` | `List<RealAssetInfo> get textureAssets` | Getter accessor returning the current value of `textureAssets`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `className` | `String get className` | Getter accessor returning the current value of `className`. |
| `projectDirPath` | `String? get projectDirPath` | Getter accessor returning the current value of `projectDirPath`. |
| `generatedSource` | `String get generatedSource` | Generated source for the current document (Graph tab / compile preview). |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `compile` | `Future<UmgCompileResult> compile()` | Saves, then writes `lib/widgets/wbp_<name>.dart` (class `Wbp<Name>`) into the project. |
| `discardChanges` | `void discardChanges()` | Executes `discardChanges` operation. |
| `select` | `void select(String? id)` | Selects the target actor or asset. |
| `setMode` | `void setMode(UmgEditorMode mode)` | Updates the `Mode` parameter and applies changes to the system. |
| `setResolution` | `void setResolution(UmgResolution resolution)` | Updates the `Resolution` parameter and applies changes to the system. |
| `setCustomResolution` | `void setCustomResolution(int width, int height)` | Updates the `CustomResolution` parameter and applies changes to the system. |
| `setDpiScale` | `void setDpiScale(double scale)` | Updates the `DpiScale` parameter and applies changes to the system. |
| `beginInteraction` | `void beginInteraction(String label)` | Starts a coalesced interaction (canvas drag, scrub): previews mutate the document live, [endInteraction] records a single transaction. |
| `endInteraction` | `void endInteraction()` | Executes `endInteraction` operation. |
| `undo` | `void undo() => transactions.undo()` | Reverts the last executed editor operation. |
| `redo` | `void redo() => transactions.redo()` | Re-applies the last undone editor operation. |
| `setCanvasPosition` | `void setCanvasPosition(String id, Offset position)` | Updates the `CanvasPosition` parameter and applies changes to the system. |
| `setCanvasSize` | `void setCanvasSize(String id, Size size)` | Updates the `CanvasSize` parameter and applies changes to the system. |
| `previewCanvasPosition` | `void previewCanvasPosition(String id, Offset position)` | Live (un-recorded) canvas position update used inside an interaction. |
| `previewCanvasRect` | `void previewCanvasRect(String id, Rect rect, Size parentSize)` | Live (un-recorded) rect update used by move/resize handles: rewrites position/size so the slot resolves to [rect] inside [parentSize]. |
| `previewSlot` | `void previewSlot(String id, void Function(UmgSlot slot) edit)` | Live (un-recorded) slot field edit used by inspector scrubbing. |
| `applyAnchorPreset` | `void applyAnchorPreset(String id, UmgAnchorPreset preset)` | Setter mutator assigning a new value to `applyAnchorPreset`. |
| `canvasSizeOf` | `Size canvasSizeOf(String id)` | Best-effort design-time size of a panel (its own canvas rect if it is a canvas child, otherwise the simulated screen). |
| `setZOrder` | `void setZOrder(String id, int zOrder)` | Updates the `ZOrder` parameter and applies changes to the system. |
| `setProp` | `void setProp(String id, String key, dynamic value)` | Updates the `Prop` parameter and applies changes to the system. |
| `previewProp` | `void previewProp(String id, String key, dynamic value)` | Live (un-recorded) prop edit used by inspector scrubbing. |
| `rename` | `bool rename(String id, String newName)` | Renames the element; the display name becomes the generated identifier via [UmgNaming.toFieldName]. Rejects empty/non-identifier/duplicate names. |
| `wrapWith` | `UmgNode? wrapWith(String id, UmgWidgetType type)` | Inserts a new [type] parent between [id] and its parent, handing the child's slot to the wrapper. |
| `replaceWith` | `UmgNode? replaceWith(String id, UmgWidgetType type)` | Swaps the node's type, keeping identity, name, slot and compatible children. |
| `deleteNode` | `bool deleteNode(String id)` | Releases and safely disposes the specified `Node` resource. |
| `addEvent` | `bool addEvent(String id, String eventName)` | `[+] OnClicked` etc.: records a named handler on the node. |
| `removeEvent` | `bool removeEvent(String id, String eventName)` | Releases and safely disposes the specified `Event` resource. |
| `bindTexture` | `void bindTexture(String id, RealAssetInfo? texture)` | Binds a real TEXTURE `.lmas` to an Image element. |
| `textureBytesFor` | `Uint8List? textureBytesFor(String id)` | Raw image bytes of the texture bound to [id] (read from disk, cached). |
| `refreshTextures` | `void refreshTextures()` | Executes `refreshTextures` operation. |
| `availableThemePaths` | `List<String> get availableThemePaths` | Relative paths of `.lmas` theme assets discovered in the active project. |
| `activeThemePath` | `String? get activeThemePath` | Relative path to the `.lmas` theme asset bound to this document (null = project default). |
| `activeTheme` | `LuminaThemeDocument get activeTheme` | Parsed [LuminaThemeDocument] currently active for this widget document. |
| `activeThemeData` | `ThemeData get activeThemeData` | Constructed shadcn [ThemeData] from [activeTheme]. |
| `loadedThemes` | `Map<String, LuminaThemeDocument> get loadedThemes` | Cache of loaded theme assets keyed by relative path. |
| `refreshAvailableThemes` | `Future<void> refreshAvailableThemes()` | Re-scans the project for theme assets and updates [availableThemePaths]. |
| `loadThemeForDocument` | `Future<void> loadThemeForDocument()` | Loads the document's assigned theme or falls back to project default. |
| `setDocumentTheme` | `Future<void> setDocumentTheme(String? path)` | Sets or clears the document-level base theme asset path and reloads. |
| `setNodeTheme` | `Future<void> setNodeTheme(String nodeId, String? themePath)` | Sets or clears a component-level theme override asset path on a specific node. |
| `themeForNode` | `LuminaThemeDocument themeForNode(UmgNode node)` | Resolves the effective [LuminaThemeDocument] for [node] (taking component override if present, else document theme). |
| `themeDataForNode` | `ThemeData themeDataForNode(UmgNode node)` | Resolves the effective shadcn [ThemeData] for [node]. |

## `lib/ui/features/sub_editors/services/umg_widget_codegen.dart`

### `class UmgCompileResult`

Outcome of one compile of a widget document.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filePath` | `String filePath` | Holds the `filePath` property or configuration state. |
| `written` | `bool written` | Holds the `written` property or configuration state. |
| `source` | `String source` | Holds the `source` property or configuration state. |
| `warnings` | `List<String> warnings` | Holds the `warnings` property or configuration state. |

### `class UmgWidgetCodegen`

Generates the real Flutter widget class for a [UmgDocument] (`<project>/lib/widgets/wbp_<name>.dart`, class `Wbp<Name>`). Same principles as the actor codegen: deterministic, idempotent, compare-before-write, `// BEGIN USER CODE: <tag>` … `// END USER CODE` regions survive regeneration, orphaned regions are kept commented at the end of the file. The game never parses the `.lmas`; this file is the truth.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fileBaseName` | `static String fileBaseName(String assetName)` | Widget class base name the document registers under (`WBP_` prefix enforced); the generated file and class derive from it (`WBP_PlayerHUD` → `wbp_player_hud.dart`, class `WbpPlayerHUD`). |
| `classNameFor` | `static String classNameFor(String assetName) => UmgNaming.toClassName(fi...` | Executes `classNameFor` operation. |
| `outputPath` | `static String outputPath(String projectPath, String assetName)` | Executes `outputPath` operation. |
| `parseUserRegions` | `static Map<String, String> parseUserRegions(String? existing)` | Parses guarded regions out of an existing generated file. |

## `lib/ui/features/sub_editors/models/umg_document.dart`

### `enum UmgWidgetCategory`

Palette categories of the UMG designer.

### `enum UmgWidgetType`

Every widget type the designer can place. The order here is the palette order; `displayName` is what the palette/hierarchy show and `dartWidget` the shadcn_flutter class the runtime renderer and the code generator map it to.

**Constructors:**
- `UmgWidgetType(this.displayName, this.category, this.capacity)`: Initializes `UmgWidgetType(this.displayName, this.category, this.capacity)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `comboBox` | `comboBox('Combo Box', UmgWidgetCategory.common, UmgChildCapacity.none)` | Executes `comboBox` operation. |
| `displayName` | `String displayName` | Holds the `displayName` property or configuration state. |
| `category` | `UmgWidgetCategory category` | Holds the `category` property or configuration state. |
| `capacity` | `UmgChildCapacity capacity` | Holds the `capacity` property or configuration state. |
| `isPanel` | `bool get isPanel` | Checks current state or capability and returns a boolean value. |
| `isCanvas` | `bool get isCanvas` | Checks current state or capability and returns a boolean value. |
| `isBox` | `bool get isBox` | Checks current state or capability and returns a boolean value. |
| `childSlotKind` | `UmgSlotKind get childSlotKind` | Which slot kind children of this type carry. |
| `availableEvents` | `List<String> get availableEvents` | Events the designer offers for this type (Widget Events section). |
| `isInteractive` | `bool get isInteractive` | Whether the runtime widget carries user-mutable state (needs a StatefulWidget in generated code even without events). |
| `defaultProps` | `Map<String, dynamic> defaultProps()` | Default props for a freshly placed widget of this type. |
| `defaultCanvasSize` | `Size get defaultCanvasSize` | Default size of a newly dropped canvas slot for this type. |
| `fromName` | `static UmgWidgetType fromName(String name)` | Executes `fromName` operation. |

### `enum UmgChildCapacity`

`UmgChildCapacity`: Enumeration listing system options and state constants.

### `enum UmgSlotKind`

Slot kinds: a child's slot is decided by its *parent* panel.

### `enum UmgAlign`

Horizontal/vertical alignment of box/overlay slots.

### `class UmgSlot`

Per-child slot data. One class carries every field so wrap/replace can migrate slots without loss; only the fields relevant to [kind] are serialized and shown in the inspector.

**Constructors:**
- `UmgSlot.fromJson(Map<String, dynamic> map)`: Initializes `UmgSlot.fromJson(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `kind` | `UmgSlotKind kind` | Holds the `kind` property or configuration state. |
| `anchorMin` | `Offset anchorMin` | Holds the `anchorMin` property or configuration state. |
| `anchorMax` | `Offset anchorMax` | Holds the `anchorMax` property or configuration state. |
| `position` | `Offset position` | Holds the `position` property or configuration state. |
| `size` | `Size size` | Holds the `size` property or configuration state. |
| `alignment` | `Offset alignment` | Holds the `alignment` property or configuration state. |
| `sizeToContent` | `bool sizeToContent` | Holds the `sizeToContent` property or configuration state. |
| `zOrder` | `int zOrder` | Holds the `zOrder` property or configuration state. |
| `paddingLeft` | `double paddingLeft` | Holds the `paddingLeft` property or configuration state. |
| `paddingTop` | `double paddingTop` | Holds the `paddingTop` property or configuration state. |
| `paddingRight` | `double paddingRight` | Holds the `paddingRight` property or configuration state. |
| `paddingBottom` | `double paddingBottom` | Holds the `paddingBottom` property or configuration state. |
| `fill` | `bool fill` | Holds the `fill` property or configuration state. |
| `flex` | `double flex` | Holds the `flex` property or configuration state. |
| `hAlign` | `UmgAlign hAlign` | Holds the `hAlign` property or configuration state. |
| `vAlign` | `UmgAlign vAlign` | Holds the `vAlign` property or configuration state. |
| `copy` | `UmgSlot copy() => UmgSlot.fromJson(toJson())` | Executes `copy` operation. |
| `isStretchX` | `bool get isStretchX` | Checks current state or capability and returns a boolean value. |
| `isStretchY` | `bool get isStretchY` | Checks current state or capability and returns a boolean value. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class UmgEvent`

A named event handler recorded on a node (`OnClicked` → `onClickedStartButton`).

**Constructors:**
- `UmgEvent.fromJson(Map<String, dynamic> map)`: Initializes `UmgEvent.fromJson(Map<String, dynamic> map)`.
- `UmgEvent(name: map['name']?.toString() ?? '', handler: map['handler']?.toString() ?? '')`: Initializes `UmgEvent(name: map['name']?.toString() ?? '', handler: map['handler']?.toString() ?? '')`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `handler` | `String handler` | Holds the `handler` property or configuration state. |
| `regionTag` | `String get regionTag` | Snake-case tag used for the guarded user region in generated code. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class UmgNode`

One element of the widget tree.

**Constructors:**
- `UmgNode.fromJson(Map<String, dynamic> map)`: Initializes `UmgNode.fromJson(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `type` | `UmgWidgetType type` | Holds the `type` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `fieldName` | `String fieldName` | Holds the `fieldName` property or configuration state. |
| `slot` | `UmgSlot slot` | Holds the `slot` property or configuration state. |
| `props` | `Map<String, dynamic> props` | Holds the `props` property or configuration state. |
| `events` | `List<UmgEvent> events` | Holds the `events` property or configuration state. |
| `children` | `List<UmgNode> children` | Holds the `children` property or configuration state. |
| `deepCopy` | `UmgNode deepCopy() => UmgNode.fromJson(toJson())` | Executes `deepCopy` operation. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `visit` | `void visit(void Function(UmgNode node, UmgNode? parent) fn, [UmgNode? pa...` | Depth-first walk, parents before children. |

### `class UmgNaming`

Dart-identifier naming helpers for element names.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toFieldName` | `static String toFieldName(String display)` | `HealthBar Progress` → `healthBarProgress`; returns '' when nothing usable remains. |
| `isIdentifier` | `static bool isIdentifier(String s) => _identifier.hasMatch(s) && !_reser...` | Checks current state or capability and returns a boolean value. |
| `toClassName` | `static String toClassName(String assetName)` | `WBP_PlayerHUD` → `WbpPlayerHUD` (the rule every code generator follows). |

### `enum UmgAnchorPreset`

Anchor presets of the 3×3 + stretch matrix.

**Constructors:**
- `UmgAnchorPreset(this.min, this.max)`: Initializes `UmgAnchorPreset(this.min, this.max)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fullStretch` | `fullStretch(Offset(0, 0), Offset(1, 1))` | Executes `fullStretch` operation. |
| `min` | `Offset min` | Holds the `min` property or configuration state. |
| `max` | `Offset max` | Holds the `max` property or configuration state. |
| `alignment` | `Offset get alignment` | Alignment that keeps the pivot on the anchored corner/edge. |
| `label` | `String get label` | Getter accessor returning the current value of `label`. |

### `class UmgResolution`

Screen Resolution Simulator entries.

**Constructors:**
- `UmgResolution('1920x1080 Full HD', 1920, 1080)`: Initializes `UmgResolution('1920x1080 Full HD', 1920, 1080)`.
- `UmgResolution('2560x1440 2K', 2560, 1440)`: Initializes `UmgResolution('2560x1440 2K', 2560, 1440)`.
- `UmgResolution('3840x2160 4K UHD', 3840, 2160)`: Initializes `UmgResolution('3840x2160 4K UHD', 3840, 2160)`.
- `UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852)`: Initializes `UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `isCustom` | `bool isCustom` | Holds the `isCustom` property or configuration state. |
| `key` | `String get key` | Getter accessor returning the current value of `key`. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

### `class UmgLayout`

Canvas-slot layout math shared by the designer canvas, the inspector and (as emitted source) the generated widget. Semantics: when an axis is not stretched, `position` is the pivot offset from the anchor point and `size` the extent; when stretched, `position` is the near margin and `size` the far margin.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `resolveCanvasRect` | `static Rect resolveCanvasRect(UmgSlot slot, Size parent)` | Executes `resolveCanvasRect` operation. |
| `fitSlotToRect` | `static void fitSlotToRect(UmgSlot slot, Rect rect, Size parent)` | Rewrites `position`/`size` of [slot] so that it resolves to [rect] at [parent] with its current anchors/alignment. |
| `applyPreset` | `static void applyPreset(UmgSlot slot, UmgAnchorPreset preset, Size parent)` | Applies [preset] to [slot] keeping its resolved rect at [parent] unchanged. |
| `snap` | `static double snap(double v, double grid)` | Executes `snap` operation. |

### `class UmgDocument`

The persisted designer document (`rawPayload` UTF-8 JSON of the WIDGET `.lmas`).

**Constructors:**
- `UmgDocument.createDefault()`: A new widget: one root Canvas Panel.
- `UmgDocument.fromJson(Map<String, dynamic> map)`: Initializes `UmgDocument.fromJson(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `root` | `UmgNode root` | Holds the `root` property or configuration state. |
| `designResolution` | `UmgResolution designResolution` | Holds the `designResolution` property or configuration state. |
| `dpiScale` | `double dpiScale` | Holds the `dpiScale` property or configuration state. |
| `themePath` | `String? themePath` | Optional relative path to a `.lmas` theme asset bound to this widget document. |
| `logicalSize` | `Size get logicalSize` | Getter accessor returning the current value of `logicalSize`. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `toFormattedJson` | `String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(t...` | Executes `toFormattedJson` operation. |
| `deepCopy` | `UmgDocument deepCopy() => UmgDocument.fromJson(toJson())` | Executes `deepCopy` operation. |
| `findNode` | `UmgNode? findNode(String id)` | Searches and retrieves matching items or actors. |
| `parentOf` | `UmgNode? parentOf(String id)` | Executes `parentOf` operation. |
| `allNodes` | `List<UmgNode> get allNodes` | Getter accessor returning the current value of `allNodes`. |
| `isDescendant` | `bool isDescendant(String ancestorId, String id)` | Checks current state or capability and returns a boolean value. |
| `lastRejectionReason` | `String? lastRejectionReason` | Attaches a detached [node] under [parentId]; returns the node, or null (with a reason in [lastRejectionReason]) when the parent cannot take it. |
| `removeNode` | `bool removeNode(String id)` | Releases and safely disposes the specified `Node` resource. |

## `lib/ui/features/sub_editors/services/umg_widget_validator.dart`

### `abstract final class UmgWidgetValidator`

Checks a widget document against the project's widget library: a plain-Flutter game cannot import shadcn_flutter, so a shadcn component in such a project is an error naming the element.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shadcnNodes` | `static List<UmgNode> shadcnNodes(UmgDocument doc)` | The shadcn components of [doc], parents before children. |
| `errors` | `static List<String> errors(UmgDocument doc, String library)` | One error per shadcn component when [library] is plain Flutter. |

## `lib/ui/features/sub_editors/services/widget_class_catalog.dart`

### `class WidgetClassCatalog`

The project's classes as the Blueprint type context needs them: every widget `.lmas` under `contents/` as a [LuminaBlueprintWidgetClass] (its designer elements become `Get <Element>` rows and `Widget:<name>` pin classes), and every actor Blueprint's parent class for assignability up the chain. Read from disk, refreshed on [AssetRepository.onAssetsChanged] (the UMG editor saved → the next palette open sees the new element), and registered into [LuminaWidgetClassRegistry] when Play starts.

**Constructors:**

- `WidgetClassCatalog(this.projectDir, {bool watch = true})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `widgetClasses` | `List<LuminaBlueprintWidgetClass> get widgetClasses` | The widget classes on disk, by name. |
| `actorParents` | `Map<String, String> get actorParents` | Project Blueprint class → its parent class (`BP_Door` → `LuminaActor`). |
| `widgetClass` | `LuminaBlueprintWidgetClass? widgetClass(String? name)` |  |
| `refresh` | `void refresh()` | Re-reads the project; listeners are told when anything changed. |
| `registerRuntimeClasses` | `void registerRuntimeClasses()` | Makes every widget class of this project known to the runtime (`Create Widget` seeds per-element state from it). |
| `scanWidgetClasses` | `static List<LuminaBlueprintWidgetClass> scanWidgetClasses(String projectDir)` | Every widget Blueprint under `contents/` of [projectDir], sorted by name: found through the project's asset index, so only the widget `.lmas` files are read. |
| `readWidgetClass` | `static LuminaBlueprintWidgetClass? readWidgetClass(File file)` | The widget class stored in the widget `.lmas` [file], or null when the file is not a widget Blueprint (or cannot be read). |
| `fromUmgDocument` | `static LuminaBlueprintWidgetClass fromUmgDocument(String name, UmgDocument doc)` | [doc] as the engine sees it: one element per designer widget below the root, typed by its `UmgWidgetType` name and seeded with its stored properties. |
| `scanActorParents` | `static Map<String, String> scanActorParents(String projectDir)` | Every actor Blueprint under `contents/blueprints/` → its parent class, from the asset index's summaries (the Blueprint document's `parentClass`, else `metadata.parent_class`). |

## `lib/ui/features/sub_editors/views/umg/umg_components.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `umgContainerStyle` | `LuminaUmgContainerStyle umgContainerStyle(Map<String, dynamic> props, Map<String, Object?>? element)` | How the designer canvas and [UmgRuntimeView] draw a Container and the shadcn components, from the designer props under the runtime element state, exactly as the generated widget does. The Container style of [props] (designer) under [element] (runtime). |
| `umgContainer` | `Widget umgContainer(UmgNode node, Map<String, Object?>? element, {ImageProvider? image, Widget? child})` | A Container element: Flutter's `Container` via [LuminaUmgContainer]. |
| `umgItems` | `List<String> umgItems(Object? v)` | The comma-separated options / items of a component. |
| `umgRequiresShadcn` | `Widget umgRequiresShadcn(UmgNode node)` | What a plain-Flutter project shows instead of a shadcn component: the game cannot import shadcn_flutter. |
| `umgShadcnValueKey` | `({String runtime, String designer})? umgShadcnValueKey(UmgWidgetType type)` | The runtime key a component's value is written under (the key the element nodes it shares read), and the designer key it was seeded from. |
| `umgShadcnComponent` | `Widget umgShadcnComponent(UmgNode node, Map<String, Object?>? element, {List<Widget> children = const [], void...` | A shadcn component of [node]: [element] is its runtime state (null in the designer), [children] its built children (a Card's / Tooltip's content, the pages of Tabs, the item contents of an Accordion). [onChanged] gets the new value of an interactive component, [onPressed] a button press. |

## `lib/ui/features/sub_editors/views/umg/umg_runtime_view.dart`

### `class UmgRuntimeView`

Renders a [UmgDocument] using real shadcn_flutter widgets and layout. Used by the Play-In-Editor (PIE) viewport overlay and widget previews.

[runtimeValues] is the widget instance map `Create Widget` built: every designer element is wrapped in a [LuminaUmgElement] and reads its live state (`elements[<name>]`) through [LuminaUmgElementBinding], exactly as the generated widget classes do, so a `Set Text (Text)` on one Text block rebuilds only that block. The instance's legacy top-level `text` / `percent` (the deprecated `Set Text (Widget)` / `Set Percent (Widget)`) still apply to elements without their own state.

**Constructors:**

- `const UmgRuntimeView({super.key, required this.document, this.runtimeValues, this.textureBytes, this.onAction, this.plainLibrary = false,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `document` | `final UmgDocument document` |  |
| `runtimeValues` | `final Map<String, Object?>? runtimeValues` |  |
| `textureBytes` | `final Map<String, Uint8List>? textureBytes` |  |
| `onAction` | `final void Function(String nodeId, String action)? onAction` |  |
| `plainLibrary` | `final bool plainLibrary` | The project uses plain Flutter widgets: shadcn components show the "requires the shadcn widget library" placeholder, as the built game cannot render them. |
| `theme` | `final LuminaThemeDocument? theme` | Optional theme to render the runtime view with (defaults to shadcn dark tokens). |
| `loadedThemes` | `final Map<String, LuminaThemeDocument>? loadedThemes` | Optional cache of loaded themes for component-level theme overrides. |

## `lib/ui/features/sub_editors/views/umg/umg_text_style.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `umgTextStyle` | `TextStyle umgTextStyle(Map<String, dynamic> props, Map<String, Object?>? element, {bool outlineRing = false})` | The text look of a designer element, shared by the designer canvas and [UmgRuntimeView] so both draw what the generated widget draws: font size, colour and drop shadow from the designer [props], each overridden by the runtime element state [element] (what the Blueprint element nodes wrote; null in the designer). |
| `umgTextShadow` | `LuminaUmgTextShadow umgTextShadow(Map<String, dynamic> props, Map<String, Object?>? element)` | The drop shadow of [props] under the runtime [element]'s overrides. |
| `umgTextOutline` | `LuminaUmgTextOutline umgTextOutline(Map<String, dynamic> props, Map<String, Object?>? element)` | The outline of [props] under the runtime [element]'s overrides. |
| `umgText` | `Widget umgText(String text, Map<String, dynamic> props, Map<String, Object?>? element)` | A text of a designer element: [umgTextStyle] plus its outline drawn as a stroked layer under the fill ([LuminaUmgText], the widget the generated code uses too). |

## `lib/ui/features/sub_editors/views/umg/umg_theme_helper.dart`

### `class UmgThemeHelper`

Helper utilities bridging [LuminaThemeDocument] with shadcn [ThemeData] and rendering themed components (e.g. Buttons with custom styles and component theme overrides) in the UMG designer canvas and runtime views.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `themeDataFromLuminaDoc` | `static ThemeData themeDataFromLuminaDoc(LuminaThemeDocument doc)` | Builds a full shadcn [ThemeData] and [ColorScheme] from [doc]'s tokens and metrics. |
| `resolveThemeForNode` | `static LuminaThemeDocument resolveThemeForNode({required UmgNode node, required LuminaThemeDocument documentTheme, required Map<String, LuminaThemeDocument> loadedThemes})` | Resolves the theme to use for [node], checking `node.props['theme']` against [loadedThemes] and falling back to [documentTheme]. |
| `buildThemedButton` | `static Widget buildThemedButton({required BuildContext context, required UmgNode node, required LuminaThemeDocument theme, required Widget child, VoidCallback? onPressed})` | Renders a themed Button applying the theme's colors, radius, padding, button variant, and custom style (`LuminaCustomStyle`). |
| `buildDocumentThemePicker` | `static Widget buildDocumentThemePicker({required BuildContext context, required UmgEditorViewModel vm, bool compact = false})` | Renders a dropdown dialog allowing the user to select the document-level base theme asset. |
| `buildNodeThemePicker` | `static Widget buildNodeThemePicker({required BuildContext context, required UmgEditorViewModel vm, required UmgNode node})` | Renders a picker for component-level theme override with an `(Inherit from Widget)` option. |
| `buildButtonStylePicker` | `static Widget buildButtonStylePicker({required BuildContext context, required UmgEditorViewModel vm, required UmgNode node})` | Renders a picker for button variants (`primary`, `secondary`, `outline`, etc.) and theme custom styles (`LuminaCustomStyle`). |

---

[Previous: Texture editor](texture.md) | [Up: Sub-editors](index.md)
