[Türkçe](../../../tr/lumina_ui/sub-editors/material.md)

# Material editor

The Material editor: editing material source, compiling the whole `.mat` definition with Filament's own material compiler (the `.mat` parser `matc` uses, through `FilamentMatc`), editing parameters and rendering a material preview. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/material/glsl_editor_widget.dart`](#libuifeaturessub_editorsviewsmaterialglsl_editor_widgetdart)
- [`lib/ui/features/sub_editors/views/material/mat_completion_popup.dart`](#libuifeaturessub_editorsviewsmaterialmat_completion_popupdart)
- [`lib/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart`](#libuifeaturessub_editorsviewsmaterialglsl_syntax_highlighterdart)
- [`lib/ui/features/sub_editors/views/material/parameter_panel.dart`](#libuifeaturessub_editorsviewsmaterialparameter_paneldart)
- [`lib/ui/features/sub_editors/views/material/material_settings_section.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_settings_sectiondart)
- [`lib/ui/features/sub_editors/views/material/material_preview_pane.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_preview_panedart)
- [`lib/ui/features/sub_editors/views/material/material_sub_editor.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/material_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsmaterial_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/material_preview_renderer.dart`](#libuifeaturessub_editorsservicesmaterial_preview_rendererdart)
- [`lib/ui/features/sub_editors/models/material_graph.dart`](#libuifeaturessub_editorsmodelsmaterial_graphdart)
- [`lib/ui/features/sub_editors/models/material_logic_nodes.dart`](#libuifeaturessub_editorsmodelsmaterial_logic_nodesdart)
- [`lib/ui/features/sub_editors/models/material_fragment_pins.dart`](#libuifeaturessub_editorsmodelsmaterial_fragment_pinsdart)
- [`lib/ui/features/sub_editors/models/material_vertex_variables.dart`](#libuifeaturessub_editorsmodelsmaterial_vertex_variablesdart)
- [`lib/ui/features/sub_editors/models/material_slot_binding.dart`](#libuifeaturessub_editorsmodelsmaterial_slot_bindingdart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicematerial_precompile_stepdart)
- [`lib/ui/features/sub_editors/services/mat_source.dart`](#libuifeaturessub_editorsservicesmat_sourcedart)
- [`.mat` code completion (`lib/ui/features/sub_editors/services/mat_language/`)](#mat-code-completion-libuifeaturessub_editorsservicesmat_language)
- [`tool/generate_filament_material_api.dart`](#toolgenerate_filament_material_apidart)
- [`lib/ui/features/sub_editors/services/material_graph_codegen.dart`](#libuifeaturessub_editorsservicesmaterial_graph_codegendart)
- [`lib/ui/features/sub_editors/services/material_graph_parser.dart`](#libuifeaturessub_editorsservicesmaterial_graph_parserdart)
- [`lib/ui/features/sub_editors/services/material_graph_parser/layout.dart`](#libuifeaturessub_editorsservicesmaterial_graph_parserlayoutdart)
- [`lib/ui/features/sub_editors/services/material_graph_types.dart`](#libuifeaturessub_editorsservicesmaterial_graph_typesdart)
- [`lib/ui/features/sub_editors/services/material_sampler_parser.dart`](#libuifeaturessub_editorsservicesmaterial_sampler_parserdart)
- [`lib/ui/features/sub_editors/view_models/material_graph_controller.dart`](#libuifeaturessub_editorsview_modelsmaterial_graph_controllerdart)
- [`lib/ui/features/sub_editors/view_models/material_graph_editor.dart`](#libuifeaturessub_editorsview_modelsmaterial_graph_editordart)
- [`lib/ui/features/sub_editors/views/material/graph_view.dart`](#libuifeaturessub_editorsviewsmaterialgraph_viewdart)
- [`lib/ui/features/sub_editors/views/material/node_details_panel.dart`](#libuifeaturessub_editorsviewsmaterialnode_details_paneldart)

## `lib/ui/features/sub_editors/views/material/glsl_editor_widget.dart`

### `class MaterialGlslEditorWidget`

Monospace `.mat` source editor: syntax colours (when the controller is a [GlslCodeController]), a line-number gutter aligned row for row with the code (every line is fixed to 20 px through a forced strut, so a gutter row and its code line never drift apart), and VS Code-style code completion. The code area is a borderless field on a dark editor surface (`#1E1E1E`) shared with the gutter.

Code completion asks [`MatCompletion`](#mat-code-completion-libuifeaturessub_editorsservicesmat_language) at the caret and shows the result in a [`MatCompletionPopup`](#libuifeaturessub_editorsviewsmaterialmat_completion_popupdart) anchored just below the caret (flipped above it near the bottom edge). The caret position comes from the line and column: the line times the 20 px line height plus the 8 px code padding, minus the field's scroll offset; the column times the monospace character width measured once with a `TextPainter`. The popup's left edge lines its labels up with the start of the word being replaced.

| Input | Effect |
| :--- | :--- |
| Typing an identifier character (from the first one), `_` or `.` | Opens the popup when there are suggestions; while it is open every edit filters it again |
| Ctrl+Space | Opens it explicitly, also with nothing typed |
| ↑ / ↓ | Moves the selection (wraps around) |
| PageUp / PageDown | Moves the selection by a page (9 rows) |
| Enter, Tab or a click on a row | Replaces the word around the caret with the item and places the caret (inside `()` for a function that takes arguments) |
| Esc, a caret move without an edit, losing focus | Closes it |

The keys are handled through the field's `FocusNode.onKeyEvent` (chained to any handler it had before) and only while the popup is open, so editing keys behave normally otherwise.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `MaterialEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `controller` | `TextEditingController controller` | Holds the `controller` property or configuration state. |
| `focusNode` | `FocusNode focusNode` | Holds the `focusNode` property or configuration state. |
| `scrollController` | `ScrollController? scrollController` | Holds the `scrollController` property or configuration state. |
| `createState` | `State<MaterialGlslEditorWidget> createState() => MaterialGlslEditorWidge...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class MaterialGlslEditorWidgetState`

`MaterialGlslEditorWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `jumpToLine` | `void jumpToLine(int line1Indexed)` | Jumps the editor cursor to a specific 1-indexed line number. |
| `completionItems` | `List<MatCompletionItem> get completionItems` | The open popup's suggestions, best first; empty when it is closed. |
| `selectedCompletionIndex` | `int get selectedCompletionIndex` | The selected row of the open popup. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/material/mat_completion_popup.dart`

### `class MatCompletionPopup`

The suggestion list of the `.mat` source pane: one 22 px row per item with the kind's Lucide icon in the kind's colour, the label with the matched characters bold (in `EditorColors.accent`) and the detail (signature or type) right-aligned and muted. At most 10 rows are visible, the rest scroll; the selected row uses `EditorColors.selectionBg`. Beside the list a details pane shows the selected item's signature and documentation (description, default, availability), on the right, or on the left when the right side has no room, or not at all. Surfaces are `EditorColors.sidebar` with an `EditorColors.borderSolid` border.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `items` | `final List<MatCompletionItem> items` | The suggestions, best first. |
| `selectedIndex` | `final int selectedIndex` | The highlighted row, whose details the pane shows. |
| `scrollController` | `final ScrollController scrollController` | The list's scroll position; the editor keeps the selection visible with `offsetRevealing`. |
| `onAccept` | `final ValueChanged<int> onAccept` | Called with a row's index when it is clicked. |
| `detailsSide` | `final MatDetailsSide detailsSide` | `right`, `left` or `none`. |
| `rowHeight` / `maxVisibleRows` / `listWidth` / `detailsWidth` | `static const double 22` / `int 10` / `double 380` / `double 300` | The popup's metrics. |
| `listHeight` | `static double listHeight(int count)` | The list's height for `count` items, borders included. |
| `offsetRevealing` | `static double offsetRevealing(int index, double offset)` | The scroll offset that keeps row `index` visible. |

| Function | Signature | Description |
| :--- | :--- | :--- |
| `matCompletionKindIcon` | `IconData matCompletionKindIcon(MatCompletionKind kind)` | keyword `key`, type `type`, function `box`, field `tag`, property `wrench`, value `listOrdered`, variable `variable`, parameter `atSign`, constant `pi`, snippet `squareCode`. |
| `matCompletionKindColor` | `Color matCompletionKindColor(MatCompletionKind kind)` | The kind's `EditorColors` token: functions `chart4`, fields and properties `accent`, types `primary`, values `warning`, variables and parameters `chart3`, constants `materialPinFloat2`, keywords `mutedForeground`. |

## `lib/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart`

### `enum GlslTokenKind`

What a stretch of `.mat` source is, for colouring.

**Values:**

- `plain`
- `comment`
- `string`
- `number`
- `keyword`
- `type`
- `function`
- `builtin`: Filament's material API (`material`, `materialParams_x`, `getUV0`, ...).
- `headerKey`: a key of the `material { }` header (`name`, `shadingModel`, ...) and the block names (`material`, `vertex`, `fragment`).
- `preprocessor`
- `punctuation`

### `class GlslToken`

One coloured run of the source.

**Constructors:**

- `const GlslToken(this.kind, this.start, this.end)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `final GlslTokenKind kind` |  |
| `start` | `final int start` | Offset of the run's first character. |
| `end` | `final int end` | Offset one past the run's last character. |

### `abstract final class GlslSyntaxHighlighter`

Splits Filament `.mat` source (the JSON-like header plus GLSL blocks) into coloured runs. Purely lexical, so it is cheap enough to run on every keystroke and never needs the compiler.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `keywords` | `static const Set<String> keywords` | GLSL control-flow and qualifier keywords. |
| `types` | `static const Set<String> types` | GLSL types (`float`, `vec3`, `mat4`, `sampler2d`, ...). |
| `builtins` | `static const Set<String> builtins` | Filament material API names; any `materialParams_*` identifier counts too. |
| `headerKeys` | `static const Set<String> headerKeys` | `material` header keys and block names; coloured only when followed by `:` or `{`. |
| `tokenize` | `static List<GlslToken> tokenize(String source)` | The coloured runs of [source], in order; uncovered gaps are plain. An identifier followed by `(` is a `function`. |
| `palette` | `static const Map<GlslTokenKind, Color> palette` | The editor palette (dark theme): one colour per kind. |
| `highlight` | `static TextSpan highlight(String source, TextStyle base)` | [source] as coloured spans over [base] (comments in italics). |

### `class GlslCodeController`

A `TextEditingController` that draws `.mat` source with [GlslSyntaxHighlighter] colours; while an IME composes, it falls back to the plain underlined span. The Material editor's code controller.

**Constructors:**

- `GlslCodeController({super.text})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `buildTextSpan` | `TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing})` | The highlighted span of the current text. |

## `lib/ui/features/sub_editors/views/material/parameter_panel.dart`

### `class MaterialParameterPanel`

Reflection-driven inspector panel for the material's PBR parameters and texture slots. The header settings (domain, blend mode, shading, two sided) live in [MaterialSettingsSection], under the 3D preview.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `MaterialEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<MaterialParameterPanel> createState() => _MaterialParameterPanelSt...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _MaterialParameterPanelState`

`_MaterialParameterPanelState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/material/material_settings_section.dart`

### `class MaterialSettingsSection`

The material header's settings, shown under the Material editor's 3D preview: Domain (shown as Surface), Blend Mode, Shading and Two Sided. Blend Mode, Shading and Two Sided rewrite the matching key of the source's `material { }` header through `MaterialEditorViewModel.updateHeaderSettings`.

**Constructors:**

- `const MaterialSettingsSection({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |
| `build` | `Widget build(BuildContext context)` |  |

## `lib/ui/features/sub_editors/views/material/material_preview_pane.dart`

### `class MaterialPreviewPane`

The Material editor's left column: the 3D preview above [MaterialSettingsSection], split by a draggable divider (`ResizablePanel.vertical`; the settings pane starts at 190 px, minimum 120). The preview shows the compiled material on a Sphere, Cube, Cylinder or Plane, or on a project mesh (Custom), with a Grid toggle; it hides the viewport's own toolbar and shape selector.

Custom scans the project's mesh assets (static and skeletal) on a background isolate and offers them in an asset picker. The picked mesh is loaded from disk (a newer pick wins over an older load still running); when it has more than one material slot, a **Material slot** select chooses which slot wears the edited material, and the other sections keep the mesh's own materials.

**Constructors:**

- `const MaterialPreviewPane({super.key, required this.viewModel, required this.parameterRevision})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |
| `parameterRevision` | `final int parameterRevision` | Bumped by the editor on every view-model change so the preview re-applies the parameter values. |
| `meshTypes` | `static const Set<AssetType> meshTypes` | The mesh asset types the Custom preview offers: `filamesh` and `filameshSk`. |
| `sectionsOfSlot` | `static Set<int> sectionsOfSlot(GlbMeshData mesh, int slot)` | The geometry sections of [mesh] that belong to material slot [slot] (by `materialIndex`, or by `materialName` for a section without an index); every section when the mesh has at most one slot. |
| `scanMeshes` | `static Future<List<RealAssetInfo>> scanMeshes(String projectRoot)` | The project's mesh assets under [projectRoot], scanned on a background isolate (`Isolate.run`). |
| `createState` | `State<MaterialPreviewPane> createState()` |  |

## `lib/ui/features/sub_editors/views/material/material_sub_editor.dart`

### `class MaterialSubEditor`

`MaterialSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `LuminaAsset? asset` | Holds the `asset` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `viewModel` | `MaterialEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<MaterialSubEditor> createState() => _MaterialSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _MaterialSubEditorState`

`_MaterialSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/material_editor_view_model.dart`

### `enum MaterialCompileSeverity`

`MaterialCompileSeverity`: Enumeration listing system options and state constants.

### `class MaterialCompileIssue`

`MaterialCompileIssue`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `line` | `int line` | Holds the `line` property or configuration state. |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `severity` | `MaterialCompileSeverity severity` | Holds the `severity` property or configuration state. |

### `class MaterialCompileResult`

What one compile of a `.mat` source produced: `bytes` (the `.filamat` package, null when rejected), `issues` (the compiler's messages), `ok`.

### `class FilamatCompilerRunner`

Compiles a whole `.mat` material definition; injectable so a test can observe what the editor hands the compiler. `Future<MaterialCompileResult> compile({required String name, required String source, String? includeDirectory})`: [source] is the complete definition as written (header, `vertex` and `fragment` blocks), [name] names a material whose header has none, `#include` resolves against [includeDirectory].

### `class DefaultFilamatCompilerRunner`

The editor's compiler: Filament's own `.mat` parser (the one `matc` uses) through `FilamentMatc`, so every header key, the `vertex` and `fragment` blocks in any order and `#include`s mean what they mean to matc, and a failure lists matc's messages (verbatim) with their `.mat` line numbers as issues. `MaterialCompileIssue.fromMatc` maps one message; `MaterialCompileIssue.fromCompiler` marks it (the issue list labels a line-less one `matc:`). The header bar's shading and blending are read from the source for display only (every Filament value, e.g. `fade`, `multiply`, `specularGlossiness`); compiling never depends on them.

### `enum MaterialParamType`

`MaterialParamType`: Enumeration listing system options and state constants.

### `class MaterialParamModel`

`MaterialParamModel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `type` | `MaterialParamType type` | Holds the `type` property or configuration state. |
| `value` | `dynamic value` | Holds the `value` property or configuration state. |
| `min` | `double min` | Holds the `min` property or configuration state. |
| `max` | `double max` | Holds the `max` property or configuration state. |
| `isSampler` | `bool isSampler` | Holds the `isSampler` property or configuration state. |
| `textureRef` | `AssetReference? textureRef` | Holds the `textureRef` property or configuration state. |

### `class MaterialEditorViewModel`

`MaterialEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `compilerRunner` | `FilamatCompilerRunner compilerRunner` | Holds the `compilerRunner` property or configuration state. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `currentCode` | `String get currentCode` | Getter accessor returning the current value of `currentCode`. |
| `compiledBytes` | `Uint8List? get compiledBytes` | Getter accessor returning the current value of `compiledBytes`. |
| `elapsedMs` | `int get elapsedMs` | Getter accessor returning the current value of `elapsedMs`. |
| `isCompiling` | `bool get isCompiling` | Checks current state or capability and returns a boolean value. |
| `syntaxStatus` | `String get syntaxStatus` | Getter accessor returning the current value of `syntaxStatus`. |
| `issues` | `List<MaterialCompileIssue> get issues` | Checks current state or capability and returns a boolean value. |
| `bodyLineOffset` | `int get bodyLineOffset` | Getter accessor returning the current value of `bodyLineOffset`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `shading` | `FilamatShading get shading` | Getter accessor returning the current value of `shading`. |
| `blending` | `BlendingMode get blending` | Getter accessor returning the current value of `blending`. |
| `doubleSided` | `bool get doubleSided` | Getter accessor returning the current value of `doubleSided`. |
| `parameters` | `List<MaterialParamModel> get parameters` | Getter accessor returning the current value of `parameters`. |
| `currentCode` | `currentCode(String value)` | Executes `currentCode` operation. |
| `updateCodeFromEditor` | `void updateCodeFromEditor(String value)` | Updates code directly from the text editor without triggering continuous rebuild loops. |
| `load` | `Future<void> load()` | Loads the asset from the given [assetPath]. A missing file starts from the new-material template, which declares `flipUV : false`: meshes carry glTF texture coordinates (v = 0 at the image top), so a texture sampled with `getUV0()` draws upright (matc's default `true` turns it upside down). |

## `lib/ui/features/sub_editors/services/material_preview_renderer.dart`

### `class MaterialPreviewRenderer`

Owns the Filament objects that show a compiled `.filamat` package on a procedural preview primitive inside a sub-editor viewport.  Lifecycle: [mount] once the engine/scene exist (or [mountMaterialOnly] when the material goes onto another renderable, a mesh's material slot), [applyParameters] whenever the editor's parameter values change, [setShape] when the user picks another primitive, [dispose] on teardown. Every native call is guarded: a material that fails to load leaves [isMounted] false and the caller keeps its software fallback.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMounted` | `bool get isMounted` | Checks current state or capability and returns a boolean value. |
| `entity` | `int get entity` | Getter accessor returning the current value of `entity`. |
| `shape` | `PreviewShape get shape` | Getter accessor returning the current value of `shape`. |
| `lastError` | `String? get lastError` | Getter accessor returning the current value of `lastError`. |
| `materialInstance` | `FilamentMaterialInstance? get materialInstance` | Getter accessor returning the current value of `materialInstance`. |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package. Filament aborts the process (uncatchable panic) when handed arbitrary bytes, so callers must check this before [mount]. |
| `packageMaterialVersion` | `static int? packageMaterialVersion(Uint8List? bytes)` | The MATERIAL_VERSION a package was compiled with, or null if not a package. |
| `applyParameters` | `void applyParameters(List<MaterialParamModel> parameters)` | Pushes the editor's parameter values into the material instance. Unknown or sampler parameters are skipped; each setter is guarded so one bad value never blocks the rest. |
| `setShape` | `void setShape(PreviewShape shape)` | Rebuilds the geometry for [shape] keeping the same material instance. Needs a scene: after [mountMaterialOnly] it does nothing. |
| `mountMaterialOnly` | `bool mountMaterialOnly({required FilamentEngine engine, required Uint8List filamatBytes, List<MaterialParamModel> parameters = const []})` | Creates the material and its instance from [filamatBytes] with [parameters] applied, without a primitive of its own: the caller puts [materialInstance] on another renderable (the sections of a mesh's material slot). Returns true on success; a non-package or failing load sets [lastError]. |
| `hasMaterial` | `bool get hasMaterial` | Whether a material instance exists (with or without its own primitive). |
| `packVertices` | `static Uint8List packVertices(PreviewMeshData mesh)` | Packs [mesh] into the interleaved layout Filament expects. Exposed for tests (no engine required). |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/models/material_graph.dart`

### `enum MaterialValueType`

The value a material expression pin carries: a float vector of one to four components, a texture object, or a `bool` (`boolean`: a comparison's result, which only logic nodes and an If's Condition take; width 0, never broadcast or mixed with floats).

**Values:**

- `float1`
- `float2`
- `float3`
- `float4`
- `texture`
- `boolean`

**Constructors:**

- `const MaterialValueType(this.width)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `width` | `final int width` |  |
| `isNumeric` | `bool get isNumeric` |  |
| `label` | `String get label` | The type's name, as compiler messages use it. |
| `glsl` | `String get glsl` | The GLSL type a local of this type is declared with. |
| `ofWidth` | `static MaterialValueType ofWidth(int width)` |  |
| `parse` | `static MaterialValueType? parse(String? name)` | Reads a stored type name (`float3`, `vec3`, `float`). |

### `class MaterialPinDef`

One pin of a material expression. A null [type] is a dynamic numeric pin (Multiply's A and B): its type comes from what is wired into it.

**Constructors:**

- `const MaterialPinDef(this.id, this.name, {this.type, this.defaultValue, this.optional = false, this.unused = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `type` | `final MaterialValueType? type` |  |
| `defaultValue` | `final Object? defaultValue` | The constant an unconnected input uses (e.g. "Const A"); edited inline on the node. Null when the input must be wired (or is [optional]). |
| `optional` | `final bool optional` | An unconnected optional input falls back to built-in behaviour (TextureSample's UVs read UV0). |
| `unused` | `final bool unused` | Set on Material output pins the current shading model or blend mode ignores (the canvas greys them out). |
| `asUnused` | `MaterialPinDef asUnused()` |  |

### `class MaterialNodeSpec`

A material expression kind: its palette entry and pins.

**Constructors:**

- `const MaterialNodeSpec({required this.id, required this.title, required this.category, required this.headerColor, this.keywords = const [], this.inputs = const...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `category` | `final String category` |  |
| `keywords` | `final List<String> keywords` |  |
| `headerColor` | `final int headerColor` |  |
| `inputs` | `final List<MaterialPinDef> inputs` |  |
| `outputs` | `final List<MaterialPinDef> outputs` |  |
| `defaults` | `final Map<String, dynamic> defaults` | Node settings a new node starts with. |
| `tooltip` | `final String tooltip` |  |

### `class MaterialSurface`

The surface the Material output node shades: which of its pins are used.

**Constructors:**

- `const MaterialSurface({this.shading = FilamatShading.lit, this.blending = BlendingMode.opaque})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shading` | `final FilamatShading shading` |  |
| `blending` | `final BlendingMode blending` |  |
| `usesOpacity` | `bool get usesOpacity` |  |
| `uses` | `bool uses(String pinId)` | Whether the output pin [pinId] feeds anything for this shading model and blend mode (Filament's `MaterialInputs` has no field for the rest). |

### `abstract final class MaterialNodes`

The material expression catalog and the helpers that read a node's settings. A material graph is lumina's [LuminaBlueprintGraph]: a node's `registryId` is one of these ids, its settings and inline input constants live in `literals`, its place in `x`/`y`.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `output` | `static const String output` |  |
| `constant` | `static const String constant` |  |
| `constant2` | `static const String constant2` |  |
| `constant3` | `static const String constant3` |  |
| `constant4` | `static const String constant4` |  |
| `scalarParameter` | `static const String scalarParameter` |  |
| `vectorParameter` | `static const String vectorParameter` |  |
| `textureParameter` | `static const String textureParameter` |  |
| `textureSample` | `static const String textureSample` |  |
| `textureCoordinate` | `static const String textureCoordinate` |  |
| `add` | `static const String add` |  |
| `subtract` | `static const String subtract` |  |
| `multiply` | `static const String multiply` |  |
| `divide` | `static const String divide` |  |
| `lerp` | `static const String lerp` |  |
| `oneMinus` | `static const String oneMinus` |  |
| `clamp` | `static const String clamp` |  |
| `power` | `static const String power` |  |
| `dot` | `static const String dot` |  |
| `normalize` | `static const String normalize` |  |
| `componentMask` | `static const String componentMask` |  |
| `appendVector` | `static const String appendVector` |  |
| `time` | `static const String time` |  |
| `vertexColor` | `static const String vertexColor` |  |
| `fresnel` | `static const String fresnel` |  |
| `custom` | `static const String custom` |  |
| `customFragment` | `static const String customFragment` |  |
| `worldPosition` | `static const String worldPosition` | WorldPosition: the vertex's (vertex stage) or pixel's world position; setting `space` `absolute` (API-level world) or `camera_relative` (Filament's shading world). |
| `setVertexVariable` | `static const String setVertexVariable` | Set Vertex Variable: a sink whose `value` input is evaluated once per vertex (the `.mat` `vertex` block) and written to the float4 interpolant `name` (a `variables` entry). |
| `vertexVariable` | `static const String vertexVariable` | Vertex Variable: reads interpolant `name` in the fragment (`variable_<name>`), RGBA outputs. |
| `maxVariables` | `static const int maxVariables` | Filament's limit on `variables` (matc's `MATERIAL_VARIABLES_COUNT`, 5). |
| `maxVariablesWithColor` | `static const int maxVariablesWithColor` | The limit when the colour attribute is required (4). |
| `absoluteSpace` | `static const String absoluteSpace` | WorldPosition space: the API-level world. |
| `cameraRelativeSpace` | `static const String cameraRelativeSpace` | WorldPosition space: Filament's shading world, shifted by the camera position. |
| `outputNodeId` | `static const String outputNodeId` | The Material output node's fixed id: every graph has exactly one. |
| `baseColor` | `static const String baseColor` |  |
| `metallic` | `static const String metallic` |  |
| `roughness` | `static const String roughness` |  |
| `specular` | `static const String specular` |  |
| `normal` | `static const String normal` |  |
| `emissive` | `static const String emissive` |  |
| `opacity` | `static const String opacity` |  |
| `ambientOcclusion` | `static const String ambientOcclusion` |  |
| `outputFields` | `static const Map<String, String> outputFields` | Output pin → the Filament `MaterialInputs` field it writes. |
| `rgbaSwizzles` | `static const Map<String, String> rgbaSwizzles` | The swizzle each RGBA output reads from its vec4. |
| `all` | `static const List<MaterialNodeSpec> all` |  |
| `spec` | `static MaterialNodeSpec? spec(String? id)` |  |
| `isVertexAvailable` | `static bool isVertexAvailable(String registryId)` | Kinds the vertex stage can evaluate (everything that feeds a Set Vertex Variable): no textures, no shading values, no interpolants. |
| `isParameter` | `static bool isParameter(String registryId)` | Kinds that declare a `.mat` parameter. |
| `inputsOf` | `static List<MaterialPinDef> inputsOf(LuminaBlueprintNode node, [MaterialSurface surface = const MaterialSurfac...` | The node's inputs, resolved for its settings and the [surface]: a Custom node's named inputs; a Custom (Fragment) node's parameters read by its code ([MaterialFragmentPins.inputPins]); the output node's pins, the unused ones marked. |
| `outputsOf` | `static List<MaterialPinDef> outputsOf(LuminaBlueprintNode node)` | The node's outputs: a Custom (Fragment) node's are the `MaterialInputs` fields its code assigns ([MaterialFragmentPins.outputPins]); every other kind's come from its spec. |
| `customInputs` | `static List<String> customInputs(LuminaBlueprintNode node)` |  |
| `maskChannels` | `static String maskChannels(LuminaBlueprintNode node)` | A ComponentMask's selected channels, in RGBA order (`'rg'`). |
| `parameterName` | `static String? parameterName(LuminaBlueprintNode node)` | The `.mat` parameter a TextureSample, parameter node or wired TextureParameter names, or null for other nodes. |
| `titleOf` | `static String titleOf(LuminaBlueprintNode node)` | The title the canvas shows: a constant's value and a parameter's name in the header. |
| `formatNumber` | `static String formatNumber(Object? value)` | A float as GLSL and the canvas write it: always with a decimal point. |
| `create` | `static LuminaBlueprintNode create(String registryId, {required String id, double x = 0, double y = 0, Map<Stri...` | A new node of [registryId] with its default settings. |
| `ensureOutput` | `static LuminaBlueprintNode ensureOutput(LuminaBlueprintGraph graph, {String? materialName})` | The Material output node of [graph], created at [x]/[y] if missing. |
| `wireInto` | `static LuminaBlueprintWire? wireInto(LuminaBlueprintGraph graph, String nodeId, String pinId)` | The wire into input [pinId] of [nodeId], if any. |

## `lib/ui/features/sub_editors/models/material_logic_nodes.dart`

### `abstract final class MaterialLogicNodes`

The material graph's logic expressions (palette category **Logic**): Compare, And, Or, Not and If. A comparison yields a `bool` ([MaterialValueType.boolean]); bools feed only And / Or / Not and an If's Condition, never float math (a node that needs 0/1 takes `If(c, 1.0, 0.0)`). If is written as the GLSL conditional `(c ? t : f)`, so both values are evaluated: fine for pure expressions and texture samples. All five are vertex-available.

| Node | Id | Inputs | Output | Settings / code |
| :--- | :--- | :--- | :--- | :--- |
| Compare | `mat_compare` | A, B (float, inline constants) | bool | `op`: `>`, `>=` (default), `<`, `<=`, `==`, `!=`; a select on the node and in the Details. `(a >= b)` |
| And / Or | `mat_and` / `mat_or` | A, B (bool) | bool | `(a && b)` / `(a \|\| b)` |
| Not | `mat_not` | A (bool) | bool | `(!a)` |
| If | `mat_if` | Condition (bool), Then, Else (ids `condition`, `then`, `else`; the same numeric type; a float broadcasts; inline constants 1.0 / 0.0) | Result (`out`), that type | Picks Then where Condition holds, else Else; both are evaluated. `(c ? t : f)` |

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `compare` | `static const String compare` | `mat_compare`. |
| `and` | `static const String and` | `mat_and`. |
| `or` | `static const String or` | `mat_or`. |
| `not` | `static const String not` | `mat_not`. |
| `ifNode` | `static const String ifNode` | `mat_if`. |
| `category` | `static const String category` | `Logic`. |
| `operators` | `static const List<String> operators` | Compare's operators, in the order the editor lists them. |
| `defaultOperator` | `static const String defaultOperator` | `>=`. |
| `compareBodyHeight` | `static const double compareBodyHeight` | Height of the operator select a Compare node draws under its header. |
| `specs` | `static const List<MaterialNodeSpec> specs` | The five node specs, spread into [MaterialNodes.all]. |
| `isLogic` | `static bool isLogic(String registryId)` |  |
| `operatorOf` | `static String operatorOf(LuminaBlueprintNode node)` | A Compare node's operator (`>=` when unset or unknown). |
| `titleOf` | `static String? titleOf(LuminaBlueprintNode node)` | The canvas title of a logic node: a Compare shows its operator (`Compare (A >= B)`). |

## `lib/ui/features/sub_editors/models/material_fragment_pins.dart`

### `abstract final class MaterialFragmentPins`

The pins and wires of a Custom (Fragment) node, read from its verbatim code: the header parameters it reads (`materialParams.x` / `materialParams_x`) become inputs wired from their parameter nodes, and the `MaterialInputs` fields it assigns (`material.normal = …`, also `+=`-style and swizzled writes) become outputs wired into the Material node. The code stays the source of truth: the wires only show its flow and are rebuilt whenever the code changes (the parser's Custom (Fragment) fallback and `MaterialGraphEditor.setProperty` on `code` call [syncWires]).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `parameters` | `static List<String> parameters(LuminaBlueprintNode node)` | The parameters [node]'s code reads, in first-use order. |
| `outputs` | `static List<String> outputs(LuminaBlueprintNode node)` | The Material node pins whose fields [node]'s code assigns, in the Material node's pin order. |
| `inputPins` | `static List<MaterialPinDef> inputPins(LuminaBlueprintNode node)` | One dynamic input pin per parameter the code reads. |
| `outputPins` | `static List<MaterialPinDef> outputPins(LuminaBlueprintNode node)` | One output pin per assigned field, named and typed like the matching Material node pin. |
| `syncWires` | `static void syncWires(LuminaBlueprintGraph graph)` | Replaces every wire touching a Custom (Fragment) node in [graph] with the ones its code implies: parameter node → fragment input, fragment output → Material node pin. A parameter with no node in the graph gets no wire. |

## `lib/ui/features/sub_editors/models/material_vertex_variables.dart`

### `abstract final class MaterialVertexVariables`

The vertex-variable helpers of the material graph: which variable a Set / Vertex Variable node names, the names `variables` header entries declare, and the entries kept on the Material node.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `variableName` | `static String? variableName(LuminaBlueprintNode node)` | The variable a Set Vertex Variable writes or a Vertex Variable reads. |
| `declaredVariableName` | `static String? declaredVariableName(String entry)` | The name a `variables` header entry declares (`tint`, `"tint"` or `{ name : tint, precision : medium }`). |
| `extraVariables` | `static List<String> extraVariables(LuminaBlueprintGraph graph)` | Header `variables` entries no Set Vertex Variable node stands for, kept on the Material node (`extraVariables`) so they survive a graph edit. |

## `lib/ui/features/sub_editors/models/material_slot_binding.dart`

### `class MaterialSlotBinding`

One geometry section's material assignment in a mesh sub-editor.

Slots are keyed by section index (`element_0`, `element_1`, …), never by the source GLB's material *name* — two sections may legitimately share a name. Shared by the Static Mesh and Skeletal Mesh editors.

**Constructors:**

- `MaterialSlotBinding({required this.index, required this.slotName, this.assignedMaterialPath, this.assignedMaterialId, this.isHighlighted = false, this.isIsolate...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `index` | `final int index` |  |
| `slotName` | `final String slotName` |  |
| `assignedMaterialPath` | `String? assignedMaterialPath` |  |
| `assignedMaterialId` | `String? assignedMaterialId` |  |
| `isHighlighted` | `bool isHighlighted` |  |
| `isIsolated` | `bool isIsolated` |  |
| `textureBindings` | `final Map<String, MaterialTextureBinding> textureBindings` | Per-sampler texture overrides, keyed by the parameter name the bound material declares (e.g. `baseColorMap`). Empty when the slot uses the material's own defaults. |
| `sourceMaterialName` | `final String? sourceMaterialName` | The material name the source mesh itself declares for this section, when it has one. An unbound slot is not "nothing applied" — the mesh ships its own material, and the editor has to say which one. |
| `samplerNames` | `List<String> samplerNames` | Sampler parameter names the currently bound material declares. Empty for an unbound slot, and refreshed when the binding changes — never a guessed PBR list. |
| `samplerNames` | `, samplerNames` |  |
| `isBound` | `bool get isBound` |  |
| `effectiveMaterialLabel` | `String get effectiveMaterialLabel` | What this section actually renders with right now: the bound asset's file name when a material was picked, otherwise the mesh's own material name. |

### `class MaterialTextureBinding`

A texture `.lmas` bound to one sampler parameter of a slot's material.

**Constructors:**

- `const MaterialTextureBinding({required this.assetId, required this.assetPath})`
- `factory MaterialTextureBinding.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetId` | `final String assetId` |  |
| `assetPath` | `final String assetPath` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

## `lib/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart`

### `class MaterialCompileOutcome`

**Constructors:**

- `const MaterialCompileOutcome.ok({this.note})`
- `const MaterialCompileOutcome.failed(this.error)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ok` | `final bool ok` |  |
| `error` | `final String? error` |  |
| `note` | `final String? note` | Extra detail for the log line (e.g. "compiled from .mat source"). |

### `class MaterialCompileInput`

What the precompile seam receives for one FILAMAT asset.

**Constructors:**

- `const MaterialCompileInput({required this.name, required this.relativePath, required this.package, required this.source, this.includeDirectory})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `relativePath` | `final String relativePath` |  |
| `package` | `final Uint8List package` |  |
| `source` | `final String source` |  |
| `includeDirectory` | `final String? includeDirectory` | The folder `#include "…"` in [source] resolves against (the asset's own). |

### `typedef MaterialCompiler`

Compiles one FILAMAT asset; injectable so tests need no GPU.

### `class FilamentMaterialCompiler`

The real seam: builds the `Material` on a headless Filament engine from the asset's compiled package bytes (or, when the asset only carries `.mat` source, from a package the material compiler — Filament's own `.mat` parser, as the Material Editor uses it — builds from the whole source) and warms its variants via `compile()`. A rejected source fails as `matc: <matc's messages>`.

**Constructors:**

- `FilamentMaterialCompiler({this.timeout = const Duration(seconds: 30)})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `timeout` | `final Duration timeout` |  |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS` chunk of size 4). Filament aborts the process on arbitrary bytes, so this guard is mandatory before `fromBuffer`. |
| `buildPackageFromSource` | `MatcResult buildPackageFromSource(String name, String source, {String? includeDirectory})` | Compiles the whole `.mat` [source] with the material compiler (every header key, `vertex` and `fragment` blocks, `#include`s from [includeDirectory]), as the Material Editor does. |
| `call` | `Future<MaterialCompileOutcome> call(MaterialCompileInput input) async` |  |
| `dispose` | `void dispose()` |  |

### `class MaterialPrecompileStep`

**Constructors:**

- `MaterialPrecompileStep({MaterialCompiler? compiler})`

## `lib/ui/features/sub_editors/services/mat_source.dart`

### `sealed class MatValue`

A header value: a bare word or number, a quoted string, a list or an object.

**Constructors:**

- `const MatValue()`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `render` | `String render({int indent = 0})` |  |

### `class MatAtom`

**Constructors:**

- `const MatAtom(this.text)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `text` | `final String text` |  |

### `class MatString`

**Constructors:**

- `const MatString(this.text)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `text` | `final String text` |  |

### `class MatList`

**Constructors:**

- `const MatList(this.items)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `items` | `final List<MatValue> items` |  |

### `class MatObject`

**Constructors:**

- `const MatObject(this.entries)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entries` | `final List<MatEntry> entries` |  |
| `operator` | `MatValue? operator [](String key)` |  |

### `class MatEntry`

**Constructors:**

- `const MatEntry(this.key, this.value)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `key` | `final String key` |  |
| `value` | `final MatValue value` |  |

### `class MatBlock`

One top-level block: `name { body }`.

**Constructors:**

- `const MatBlock(this.name, this.body)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `body` | `final String body` |  |

### `class MatParameterDecl`

A parameter the header declares.

**Constructors:**

- `const MatParameterDecl(this.type, this.name, this.defaultValue, this.raw)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `type` | `final String type` |  |
| `name` | `final String name` |  |
| `defaultValue` | `final MatValue? defaultValue` |  |
| `raw` | `final MatObject raw` | The declaration as written, for re-emitting a parameter the graph does not model. |
| `isSampler` | `bool get isSampler` |  |

### `class MatVariableDecl`

A custom interpolant the header's `variables` declares: `tint`, or `{ name : tint, precision : medium }`.

**Constructors:**

- `const MatVariableDecl(this.name, this.precision, this.raw)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `precision` | `final String? precision` |  |
| `raw` | `final MatValue raw` | The entry as written. |

### `class MatSource`

**Constructors:**

- `const MatSource(this.blocks, this.header)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `blocks` | `final List<MatBlock> blocks` |  |
| `header` | `final List<MatEntry> header` | The `material` block's entries, in order; empty when there is none. |
| `block` | `MatBlock? block(String name)` |  |
| `headerValue` | `MatValue? headerValue(String key)` |  |
| `materialName` | `String? get materialName` |  |
| `requires` | `List<String> get requires` |  |
| `parameters` | `List<MatParameterDecl> get parameters` |  |
| `variables` | `List<MatVariableDecl> get variables` | The custom interpolants the header's `variables` declares, in order. |
| `tryParse` | `static MatSource? tryParse(String source)` | [parse], or null when the blocks cannot be told apart. |
| `parse` | `static MatSource parse(String source)` | Splits [source] into blocks. Throws [FormatException] on unbalanced braces. |
| `matchingBrace` | `static int matchingBrace(String s, int open)` | The index of the brace closing the one at [open], skipping strings and comments. |
| `renderHeader` | `static String renderHeader(List<MatEntry> entries)` | Renders a `material` header block from [entries]. |

## `.mat` code completion (`lib/ui/features/sub_editors/services/mat_language/`)

Pure Dart (no Flutter imports), so the same engine can serve other front ends. The API tables come from Filament's own material documentation through [`tool/generate_filament_material_api.dart`](#toolgenerate_filament_material_apidart).

| File | Contents |
| :--- | :--- |
| `mat_api_types.dart` | The table value types: `MatHeaderKeyInfo` (name, group, type, allowed `values`, `defaultValue`, description), `MatEntryKeyInfo` (a key of a `parameters` / `constants` / `variables` entry or of `blendFunction`), `MatParamTypeInfo`, `MatStructFieldInfo` (name, GLSL type, default, `shadingModels` it is available with — empty means all —, availability note, description, API level; `availableWith(model)`), `MatFunctionInfo` (name, full signature, return type, `MatStage` `any` / `vertex` / `fragment`, description, API level, category; `hasArguments`, `availableIn(stage)`), `MatTypeInfo`, `MatConstantInfo`. |
| `filament_material_api.g.dart` | Generated, checked in, not edited by hand. `filamentMaterialApiVersion` (`1.77.2`), `filamentHeaderKeys` (42: the 41 `### <Group>: <key>` sections plus `apiLevel`), `filamentParameterTypes` (22) and `filamentConstantTypes` (3), `filamentPrecisions`, `filamentParameterEntryKeys` / `filamentConstantEntryKeys` / `filamentVariableEntryKeys` / `filamentBlendFunctionKeys`, `filamentMaterialInputs` (28 `MaterialInputs` fields; the property tables of the material models give the descriptions, ranges and API levels, the struct's comments the defaults and the shading models), `filamentMaterialVertexInputs` (10 fields; `variable0`… stand for the header's `variables`), `filamentFunctions` (64 entries, 62 names, from the Math, Matrices, Frame constants, Material globals, Vertex only and Fragment only tables, `getCustom0()` to `getCustom7()` expanded, plus `prepareMaterial`), `filamentTypeAliases` (14) and `filamentConstants` (`PI`, `HALF_PI`). |
| `glsl_builtins.dart` | Hand-written: `glslBuiltinFunctions` (the common GLSL ES 3.0 built-ins — `texture`, `textureLod`, `textureSize`, `texelFetch`, `mix`, `clamp`, `step`, `smoothstep`, `min`, `max`, `abs`, `sign`, `floor`, `ceil`, `fract`, `mod`, `pow`, `exp`, `exp2`, `log`, `log2`, `sqrt`, `inversesqrt`, `length`, `distance`, `dot`, `cross`, `normalize`, `reflect`, `refract`, the trigonometry, `dFdx` / `dFdy` / `fwidth` (fragment only), `any`, `all`, `not`, `transpose`, `inverse`, `determinant` and the vector / matrix constructors — with signatures and one-line docs), `glslTypes`, `glslKeywords`, `glslFragmentKeywords` (`discard`). |
| `mat_document.dart` | `MatDocumentIndex.of(source)`: one pass over the source that never throws on a half-typed one. Top-level blocks (`MatBlockRange`), comment and string spans (`isInCommentOrString`, binary search), the header's `shadingModel` (`effectiveShadingModel` falls back to the documented default `lit`), `parameters` and `constants` (`MatDeclaredParam`), `variables`, `requires`, and the declarations of the `vertex` / `fragment` blocks (`MatLocal`: variables, function parameters, functions, structs; `localsBefore(block, offset)`). The last index is cached by text, so queries on the same text version scan it once. |
| `mat_header_context.dart` | `MatHeaderContext.at(doc, block, offset)`: walks the header to the caret and reports whether it is at a key or at a value, the key, the object or list it is in (`owner`: the header, a `parameters` / `constants` / `variables` entry, `blendFunction`, `requires`, …) and the keys already written there. |
| `mat_fuzzy_match.dart` | VS Code-style matching: `matchLabel(label, query)` returns a `MatMatch` with the tier (0 exact-case prefix, 1 case-insensitive prefix, 2 camelCase / word starts such as `gwp` → `getWorldPosition`, 3 substring), the matched positions and a score that orders matches of a tier (words skipped, substring start). |
| `mat_completion_item.dart` | `MatCompletionKind` (`keyword`, `type`, `function`, `field`, `property`, `value`, `variable`, `parameter`, `constant`, `snippet`, each with a relevance rank) and `MatCompletionItem` (`label`, `kind`, `detail`, `documentation`, `insertText`, `cursorOffsetInInsert`, `highlights`; `caretOffset`). |
| `mat_completion_sources.dart` | The candidates of each context (below); the static per-stage lists are built once. |
| `mat_completion.dart` | `MatCompletion.suggest(String source, int offset, {bool explicit = false}) → MatCompletionResult {replaceStart, replaceEnd, items}` and `MatCompletion.rank(candidates, prefix)`. |

**Contexts.** The replaced range is the identifier around the caret. With an empty prefix only an explicit request (Ctrl+Space) or a member access (`material.`) suggests anything; inside comments and strings nothing is suggested.

| Where | Suggestions |
| :--- | :--- |
| Outside every block | The `material`, `fragment` and `vertex` block snippets the source does not have yet (`fragment` with `material()` and `prepareMaterial(material);`, the caret on the empty line). |
| `material { }` at a key | The header keys not written yet, inserted as `key : `; inside a `parameters` entry `type`, `name`, `precision`, `format`, `multisample`, `filterable`, `transformName`; inside a `constants` entry `name`, `type`, `default`; inside a `variables` entry `name`, `precision`; inside `blendFunction` `srcRGB`, `srcA`, `dstRGB`, `dstA`. |
| `material { }` after `<key> :` or in its list | The key's documented values: `shadingModel` → `lit`, `subsurface`, `cloth`, `unlit`, `specularGlossiness`; `blending` → `opaque`, `transparent`, `fade`, `add`, `masked`, `multiply`, `screen`, `custom`; `requires : [ ]` → `uv0`, `uv1`, `color`, `position`, `tangents`, `custom0`…`custom7`; booleans → `true`, `false`; a parameter's `type :` → the parameter types (`float`…`float4`, `int`…, `uint`…, `bool`…, `float3x3`, `float4x4`, `sampler2d`, `sampler2dArray`, `samplerExternal`, `samplerCubemap`); `precision :` → `default`, `low`, `medium`, `high`. |
| `fragment { }` after `material.` | The `MaterialInputs` fields available with the header's shading model (`unlit` keeps `baseColor`, `emissive`, `postLightingColor`; `cloth` drops `metallic`, `clearCoat`, … and adds `subsurfaceColor`). |
| `vertex { }` after `material.` | The `MaterialVertexInputs` fields, with the header's `variables` in place of `variable0`…. |
| after `materialParams.` | The header's non-sampler parameters. |
| An identifier in `fragment` / `vertex` | Locals declared earlier in the block, `materialParams`, `materialParams_<sampler>`, `materialConstants_<constant>`, `variable_<name>` (fragment only), the Filament functions of the block's stage, the GLSL built-ins, types (a constructor such as `vec3` appears once, as the type), constants and keywords. |

**Ranking.** The exact label first, then the match tier and its score, then the kind (locals and parameters, fields / properties / values, functions, constants, types, keywords, snippets), then alphabetically. A function inserts `name()` with the caret inside the parentheses when any overload takes arguments, after them otherwise; overloads appear once (`(+1 overload)` in the detail). A query on a 200-line source takes well under a millisecond (`test/view_models/mat_completion_test.dart` checks a 5 ms bound per new text version).

## `tool/generate_filament_material_api.dart`

Generates `lib/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart` from Filament's material documentation, `docs_src/src_markdeep/Materials.md.html` (the page published as <https://google.github.io/filament/Materials.md.html>).

```bash
dart run tool/generate_filament_material_api.dart [<Materials.md.html>] [--version <x.y.z>]
```

| Input | Default |
| :--- | :--- |
| The document | `docs_src/src_markdeep/Materials.md.html` in the Filament checkout `tool/filament/build_prebuilt.*` builds from: `LUMINA_FILAMENT_WORK`, else `<workspace>/build/filament-src` (`LuminaWorkspace.root`) |
| `--version` | The checkout's `android/gradle.properties` `VERSION_NAME`, written into the generated header comment and `filamentMaterialApiVersion` |

The parser (`tool/src/filament_material_doc.dart`, `FilamentMaterialDoc.parse`) reads the `### <Group>: <key>` sections' `Type` / `Value` / `Description` definitions (allowed values from the backticked words before "Defaults to", `custom0` through `custom7` expanded, the default after "Defaults to"), the `[materialParamsTypes]` and `[materialConstantsTypes]` tables, the sampler fields, the `struct MaterialInputs` / `struct MaterialVertexInputs` blocks with their comments, the material model property tables and the Shader public APIs tables. `tool/src/filament_material_api_writer.dart` renders the tables one entry per line (`// dart format off`). `test/view_models/filament_material_api_test.dart` re-parses the document when it exists (skipping with the reason otherwise) and checks that every function name of the API tables is in the generated table and that the generated tables match a fresh parse.

## `lib/ui/features/sub_editors/services/material_graph_codegen.dart`

### `class MaterialGraphCodegen`

Writes a material graph as `.mat` source.

The `material` header is the current source's, with `parameters`, `requires` and `variables` rewritten from the graph (every other key kept as written; a source without a header gets one declaring `flipUV : false`, as the new-material template does); blocks other than `vertex` and `fragment` are kept as written. The fragment is the graph: expressions inline, a local for every value used more than once (or named in the source it was parsed from), what feeds Normal before `prepareMaterial(material)`, everything else after it. Logic nodes are expressions too: Compare `(a >= b)`, And / Or / Not `(a && b)`, `(a || b)`, `(!a)`, If the conditional `(c ? t : f)` (a float input of a wider If is cast, `vec3(x)`); the generator never writes an `if` statement or a declaration without a value. A Custom (Fragment) node replaces the generated fragment with its code, verbatim.

The `vertex` block is the Set Vertex Variable nodes: each writes its interpolant (`material.<name> = …`, widened to `vec4`: `vec4(x)`, `vec4(xy, 0.0, 1.0)`, `vec4(xyz, 1.0)`) from the expressions upstream of it, evaluated per vertex with the vertex stage's reads (`material.uv0`, `material.color`, `material.worldPosition`). With no such node a hand-written vertex block stays as written; one the graph wrote goes away with its last setter.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `generate` | `static String generate(LuminaBlueprintGraph graph, {required String currentSource, required MaterialSurface su...` |  |

## `lib/ui/features/sub_editors/services/material_graph_parser.dart`

### `class MaterialGraphParseResult`

What [MaterialGraphParser.parse] made of a `.mat` source.

**Constructors:**

- `const MaterialGraphParseResult(this.graph, {this.fallbackReason, this.notes = const []})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `fallbackReason` | `final String? fallbackReason` | Why the fragment became one Custom (Fragment) node, or null when the graph expresses it. |
| `notes` | `final List<String> notes` | Things a later graph edit will not keep (comments). |
| `isFallback` | `bool get isFallback` |  |

### `class MaterialGraphParser`

Reads a `.mat` source into a material graph.

The fragment's `material()` body is parsed statement by statement into expressions; the generator's own output parses back into the graph it came from. A call the catalog has no node for becomes a Custom expression node holding its GLSL (`abs(…)`, `getWorldGeometricNormalVector()` and the other Filament getters included). Comparisons (`>`, `>=`, `<`, `<=`, `==`, `!=`), `&&`, `||`, `!` and `?:` (lowest precedence, right associative) become logic nodes. An `if (c) { … } else if (c2) { … } else { … }` chain (braces or single statements, nested ifs inside a branch too) whose branches only assign (`=`, `+=`, `-=`, `*=`, `/=`) locals declared before it becomes, per assigned local, `If(c, v1, If(c2, v2, … v_else))`; a branch that does not assign it keeps the value from before the `if`. A declaration without a value (`vec2 finalUV;`) is accepted; reading it before every path assigned it falls back ("finalUV may be read unassigned"). A branch that writes `material.*`, calls `prepareMaterial` or declares a local read after it, a loop, and anything else that cannot be expressed statement by statement (unknown fields or declarations) makes the whole fragment one Custom (Fragment) node, kept verbatim, with a reason naming what, whose pins and wires show its code's flow (the parameters it reads wired in, the fields it writes wired into the Material node; see [MaterialFragmentPins]). Header parameters always become parameter nodes, so a graph edit never drops a declaration.

The header's `variables` and the `vertex` block are read too: `material.<variable> = …` in `materialVertex()` becomes a Set Vertex Variable node (the codegen's `vec4` widening reads back as the unwidened value), `variable_<name>` in the fragment one Vertex Variable node per name, `getUserWorldPosition()` / `getWorldPosition()` (and their vertex-block forms) a WorldPosition. A Time, VertexColor, TexCoord, WorldPosition or parameter used by both stages is one node. A vertex block that writes anything else (moves vertices, writes `material.color`) or uses a loop is kept as written (`notes` says why) and its declared variables stay readable.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `parse` | `static MaterialGraphParseResult parse(String source)` |  |

## `lib/ui/features/sub_editors/services/material_graph_parser/layout.dart`

### `abstract final class MaterialGraphLayout`

Lays a parsed graph out left to right: the Material node on the right, each expression one column left of its left-most consumer.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `columnGap` | `static const double columnGap` |  |
| `rowGap` | `static const double rowGap` |  |
| `textureBodyHeight` | `static const double textureBodyHeight` | The texture thumbnail picker a Texture Sample / TextureParameter node draws under its header (`MaterialGraphEditor.nodeBody`). |
| `width` | `static double width(LuminaBlueprintNode n)` | The width the graph canvas gives [n] (its title and pin labels), so a column is as wide as its widest node. |
| `arrange` | `static void arrange(LuminaBlueprintGraph graph)` |  |
| `keepPositions` | `static void keepPositions(LuminaBlueprintGraph next, LuminaBlueprintGraph previous)` | Gives nodes of [next] the places their counterparts had in [previous] (matched by kind and settings), so a re-parse keeps the author's layout. |

## `lib/ui/features/sub_editors/services/material_graph_types.dart`

### `class MaterialGraphDiagnostic`

A problem the type checker found on a node (or one of its inputs), worded as a material compiler message.

**Constructors:**

- `const MaterialGraphDiagnostic(this.message, {this.nodeId, this.pinId, this.isError = true})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `nodeId` | `final String? nodeId` |  |
| `pinId` | `final String? pinId` |  |
| `message` | `final String message` |  |
| `isError` | `final bool isError` |  |

### `class MaterialGraphAnalysis`

The resolved types and diagnostics of one material graph.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `diagnostics` | `final List<MaterialGraphDiagnostic> diagnostics` |  |
| `reachable` | `final Set<String> reachable` | Nodes that feed the Material output node (or are it): the fragment. |
| `vertexReachable` | `final Set<String> vertexReachable` | Nodes that feed a Set Vertex Variable (or are one): the vertex block. A node can be in both sets. |
| `empty` | `static const MaterialGraphAnalysis empty` |  |
| `outputType` | `MaterialValueType? outputType(String nodeId, String pinId)` |  |
| `inputType` | `MaterialValueType? inputType(String nodeId, String pinId)` |  |
| `hasErrors` | `bool get hasErrors` |  |
| `errorNodeIds` | `Set<String> get errorNodeIds` |  |
| `diagnosticsFor` | `List<MaterialGraphDiagnostic> diagnosticsFor(String nodeId)` |  |
| `inputHasError` | `bool inputHasError(String nodeId, String pinId)` | Whether the wire into [nodeId].[pinId] carries a type error. |

### `class MaterialGraphChecker`

Infers every pin's type (float1–float4 with implicit scalar broadcast, a texture, or a comparison's bool) and reports what cannot compile, including the logic rules (an If's Condition and And / Or / Not's inputs take a bool, an If's Then and Else the same numeric type or a float, Compare's inputs a float, and a bool reaches no other pin: each an error on that pin), the vertex stage's rules: a fragment-only node (TextureSample, TextureParameter, Fresnel, Vertex Variable) feeding a Set Vertex Variable, an invalid or duplicate variable name, more variables than matc allows (5; 4 with the vertex colour), a Vertex Variable whose name nothing writes or declares, a setter while the source's vertex block is hand-written code the graph would overwrite, and a wire into the Material node next to a Custom (Fragment) node (that node writes the whole fragment, so such a wire would be ignored; the node's own wires, which only show its code's flow, are not reported).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `surface` | `final MaterialSurface surface` |  |
| `check` | `static MaterialGraphAnalysis check(LuminaBlueprintGraph graph, MaterialSurface surface)` |  |

## `lib/ui/features/sub_editors/services/material_sampler_parser.dart`

### `class MaterialSamplerParser`

Extracts the sampler parameter names a Filament `.mat` source declares.

Used by the mesh sub-editors to show one texture row per sampler the bound material actually has. A material that declares no samplers yields an empty list — the parser never falls back to a guessed PBR set, because a row the material cannot consume would be a dead control.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `declaredSamplers` | `static List<String> declaredSamplers(String matSource)` | Sampler names in declaration order, de-duplicated. |

## `lib/ui/features/sub_editors/view_models/material_graph_controller.dart`

### `class MaterialGraphController`

The Material Editor's node graph and its link to the `.mat` source.

Graph and source are two views of one material. A graph edit is one undo step on [transactions] that regenerates the source (unless the graph has type errors, which the compiler log shows instead); a hand edit of the source re-parses it into the graph the next time the graph is looked at ([ensureSynced]), keeping the nodes where the author put them. The graph is stored in the `.lmas` metadata `material_graph` with a hash of the source it matches, so its layout survives a save and reload.

**Constructors:**

- `MaterialGraphController(this._vm)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `transactions` | `final TransactionManager transactions` |  |
| `editor` | `late final MaterialGraphEditor editor` |  |
| `bindTexture` | `bool bindTexture(String parameter, RealAssetInfo? asset)` | Binds sampler [parameter] to [asset] (null clears it) as one undo step: the panel, the node Details and the Texture Sample node all go through here. The binding lives in the view model's parameters, not in the graph, so the step restores it directly. |
| `graph` | `LuminaBlueprintGraph get graph` |  |
| `analysis` | `MaterialGraphAnalysis get analysis` |  |
| `surface` | `MaterialSurface get surface` |  |
| `isInitialized` | `bool get isInitialized` |  |
| `isAhead` | `bool get isAhead` | The graph holds edits the source lacks (its type errors kept it from being written). A hand edit of the source since makes the source the newer of the two again. |
| `isLayoutDirty` | `bool get isLayoutDirty` |  |
| `fallbackReason` | `String? get fallbackReason` | Why the fragment is one Custom (Fragment) node, when it is. |
| `notes` | `List<String> get notes` |  |
| `sourceHash` | `static String sourceHash(String code)` |  |
| `restore` | `void restore(String? storedJson)` | Forgets the graph; the next [ensureSynced] reads it from [storedJson] (the `.lmas` metadata) or parses the source. |
| `storedJson` | `String storedJson()` | The metadata value [restore] reads back. |
| `markSaved` | `void markSaved()` |  |
| `ensureSynced` | `void ensureSynced()` | Brings the graph in line with the source: the stored graph when it was saved with this very source, else a parse of the source laid out like the graph before it. A re-parse after a hand edit clears graph undo. |
| `headerChanged` | `void headerChanged(String previousCode)` | The source's header changed (shading model, blend mode) without its fragment: keep the graph, re-check it against the new surface, and regenerate the fragment so the pins the new surface does not use are left out, and come back when it uses them again (e.g. Unlit rejects `material.metallic`). A graph not opened yet is read first; a hand-written fragment kept as Custom (Fragment) stays as it is. |
| `issues` | `List<MaterialCompileIssue> get issues` | The graph's diagnostics as compiler-log rows. |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `arrange` | `void arrange()` | Lays the graph out again (one undo step). |

## `lib/ui/features/sub_editors/view_models/material_graph_editor.dart`

### `class MaterialGraphEditor`

Edits a material graph through the shared Blueprint graph canvas: material expressions instead of lumina's Blueprint node library, float1–float4, texture and bool pins (bool pins in the Blueprint boolean colour) instead of Blueprint pin types, and the material wiring rule — a wire is refused only for a loop or a texture/number mix-up; any other mismatch is drawn red and reported by the type checker.

**Constructors:**

- `MaterialGraphEditor({required super.host, required super.graphSource, required this.analysis, required this.surface, required this.textures, required this.textu...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `analysis` | `final MaterialGraphAnalysis Function() analysis` |  |
| `surface` | `final MaterialSurface Function() surface` |  |
| `textures` | `final List<RealAssetInfo> Function() textures` | The project's textures, the one bound to a sampler parameter, and the undoable rebind, for the Texture Sample node's thumbnail picker. |
| `textureFor` | `final RealAssetInfo? Function(String parameter) textureFor` |  |
| `bindTexture` | `final bool Function(String parameter, RealAssetInfo? asset) bindTexture` |  |
| `samplerOf` | `String? samplerOf(LuminaBlueprintNode node)` | The `.mat` sampler a Texture Sample / TextureParameter node reads: its own parameter, or the TextureParameter wired into Tex. |
| `textureBodyHeight` | `static const double textureBodyHeight` |  |
| `nodeBody` | `Widget? nodeBody(BuildContext context, LuminaBlueprintNode node)` | The Texture Sample node: the bound texture's thumbnail and name; a click opens the searchable picker. The Compare node: its operator select. |
| `compareOperatorSelect` | `static Widget compareOperatorSelect(LuminaBlueprintNode node, {required String keyPrefix, required void Function(String op) onChanged})` | A select over Compare's operators (`A >= B` …), shared by the node and the Details panel. |
| `displayType` | `static LuminaPinType displayType(MaterialValueType? t)` | The Blueprint pin type the canvas uses to pick an inline editor. |
| `colorFor` | `static Color colorFor(MaterialValueType? t)` |  |
| `typeOf` | `MaterialValueType? typeOf(String nodeId, String pinId, {required bool output})` | The resolved type of a pin: its fixed type, else what flows through it. |
| `showsInlineLiteral` | `bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)` | Only inputs with a "Const" fallback (Multiply's B, Lerp's Alpha, Fresnel's exponent) edit a constant on the node. |
| `uniqueParameterName` | `String uniqueParameterName(String base)` | A parameter name no node uses yet: [base], `base_1`, `base_2`, … |
| `declaredVariables` | `List<String> get declaredVariables` | The vertex variables the material has: the names Set Vertex Variable nodes write (graph order), then those the header declares without one. |
| `uniqueVariableName` | `String uniqueVariableName(String base)` | A variable name no Set Vertex Variable writes yet: [base], `base_1`, … (a new setter's default; a new Vertex Variable reads the first declared name). |
| `removeNodes` | `bool removeNodes(Set<String> ids)` | Every node but the Material output can be deleted. |
| `setProperty` | `bool setProperty(String nodeId, String key, Object? value)` | Sets node setting [key] (a constant's value, a parameter's name, a Custom node's code) as one undo step. Renaming a Custom input keeps its wire; removing one drops it. Renaming the only Set Vertex Variable of a variable renames the Vertex Variable nodes that read it. Changing a Custom (Fragment) node's `code` rebuilds its pins and wires ([MaterialFragmentPins.syncWires]). |

## `lib/ui/features/sub_editors/views/material/graph_view.dart`

### `class MaterialGraphView`

The Material Editor's Node Graph tab: the material as material expressions on the Blueprint editor's graph canvas, with a Details panel for the selected node. Graph and GLSL tab are two views of one material: an edit here rewrites the source, an edit there re-parses into this graph.

**Constructors:**

- `const MaterialGraphView({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |

### `class MaterialGraphViewState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `canvas` | `BlueprintGraphCanvasState? get canvas` |  |

## `lib/ui/features/sub_editors/views/material/node_details_panel.dart`

### `class MaterialNodeDetailsPanel`

The Details panel of the material graph: the selected expression's settings — constant values, parameter names and defaults, the texture a TextureSample reads, TexCoord tiling, mask channels, a Compare's operator, and a Custom node's inputs and GLSL. Every committed edit is one undo step.

**Constructors:**

- `const MaterialNodeDetailsPanel({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |

---

[Previous: Landscape and foliage](landscape.md) | [Up: Sub-editors](index.md) | [Next: Navigation editor](navigation.md)
