[Türkçe](../../../tr/lumina_ui/sub-editors/material.md)

# Material editor

The Material editor: editing material source, compiling it with filamat, editing parameters and rendering a material preview. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/material/glsl_editor_widget.dart`](#libuifeaturessub_editorsviewsmaterialglsl_editor_widgetdart)
- [`lib/ui/features/sub_editors/views/material/parameter_panel.dart`](#libuifeaturessub_editorsviewsmaterialparameter_paneldart)
- [`lib/ui/features/sub_editors/views/material/material_sub_editor.dart`](#libuifeaturessub_editorsviewsmaterialmaterial_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/material_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsmaterial_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/material_preview_renderer.dart`](#libuifeaturessub_editorsservicesmaterial_preview_rendererdart)
- [`lib/ui/features/sub_editors/models/material_graph.dart`](#libuifeaturessub_editorsmodelsmaterial_graphdart)
- [`lib/ui/features/sub_editors/models/material_slot_binding.dart`](#libuifeaturessub_editorsmodelsmaterial_slot_bindingdart)
- [`lib/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart`](#libuifeaturessub_editorsservicesbuild_pipeline_servicematerial_precompile_stepdart)
- [`lib/ui/features/sub_editors/services/mat_source.dart`](#libuifeaturessub_editorsservicesmat_sourcedart)
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

Monospace GLSL Source Editor with line number gutter and parameter autocomplete.

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
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/material/parameter_panel.dart`

### `class MaterialParameterPanel`

Reflection-driven inspector panel for Material settings, PBR parameters, and texture slots.

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

### `class FilamatCompilerRunner`

Abstract compiler runner to facilitate testing in environments without native Filament binaries.

### `class DefaultFilamatCompilerRunner`

`DefaultFilamatCompilerRunner`: `class` representing the data model or functionality of the module.

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
| `load` | `Future<void> load()` | Loads the asset from the given [assetPath]. |

## `lib/ui/features/sub_editors/services/material_preview_renderer.dart`

### `class MaterialPreviewRenderer`

Owns the Filament objects that show a compiled `.filamat` package on a procedural preview primitive inside a sub-editor viewport.  Lifecycle: [mount] once the engine/scene exist, [applyParameters] whenever the editor's parameter values change, [setShape] when the user picks another primitive, [dispose] on teardown. Every native call is guarded: a material that fails to load leaves [isMounted] false and the caller keeps its software fallback.

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
| `setShape` | `void setShape(PreviewShape shape)` | Rebuilds the geometry for [shape] keeping the same material instance. |
| `packVertices` | `static Uint8List packVertices(PreviewMeshData mesh)` | Packs [mesh] into the interleaved layout Filament expects. Exposed for tests (no engine required). |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/models/material_graph.dart`

### `enum MaterialValueType`

The value a material expression pin carries: a float vector of one to four components, or a texture object.

**Values:**

- `float1`
- `float2`
- `float3`
- `float4`
- `texture`

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
| `isParameter` | `static bool isParameter(String registryId)` | Kinds that declare a `.mat` parameter. |
| `inputsOf` | `static List<MaterialPinDef> inputsOf(LuminaBlueprintNode node, [MaterialSurface surface = const MaterialSurfac...` | The node's inputs, resolved for its settings and the [surface]: a Custom node's named inputs; the output node's pins, the unused ones marked. |
| `outputsOf` | `static List<MaterialPinDef> outputsOf(LuminaBlueprintNode node)` |  |
| `customInputs` | `static List<String> customInputs(LuminaBlueprintNode node)` |  |
| `maskChannels` | `static String maskChannels(LuminaBlueprintNode node)` | A ComponentMask's selected channels, in RGBA order (`'rg'`). |
| `parameterName` | `static String? parameterName(LuminaBlueprintNode node)` | The `.mat` parameter a TextureSample, parameter node or wired TextureParameter names, or null for other nodes. |
| `titleOf` | `static String titleOf(LuminaBlueprintNode node)` | The title the canvas shows: a constant's value and a parameter's name in the header. |
| `formatNumber` | `static String formatNumber(Object? value)` | A float as GLSL and the canvas write it: always with a decimal point. |
| `create` | `static LuminaBlueprintNode create(String registryId, {required String id, double x = 0, double y = 0, Map<Stri...` | A new node of [registryId] with its default settings. |
| `ensureOutput` | `static LuminaBlueprintNode ensureOutput(LuminaBlueprintGraph graph, {String? materialName})` | The Material output node of [graph], created at [x]/[y] if missing. |
| `wireInto` | `static LuminaBlueprintWire? wireInto(LuminaBlueprintGraph graph, String nodeId, String pinId)` | The wire into input [pinId] of [nodeId], if any. |

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
| `note` | `final String? note` | Extra detail for the log line (e.g. "compiled from GLSL source"). |

### `class MaterialCompileInput`

What the precompile seam receives for one FILAMAT asset.

**Constructors:**

- `const MaterialCompileInput({required this.name, required this.relativePath, required this.package, required this.source})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `relativePath` | `final String relativePath` |  |
| `package` | `final Uint8List package` |  |
| `source` | `final String source` |  |

### `typedef MaterialCompiler`

Compiles one FILAMAT asset; injectable so tests need no GPU.

### `class FilamentMaterialCompiler`

The real seam: builds the `Material` on a headless Filament engine from the asset's compiled package bytes (or, when the asset only carries GLSL source, from a package built by the in-process filamat compiler exactly the way the Material Editor does) and warms its variants via `compile()`.

**Constructors:**

- `FilamentMaterialCompiler({this.timeout = const Duration(seconds: 30)})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `timeout` | `final Duration timeout` |  |
| `isFilamatPackage` | `static bool isFilamatPackage(Uint8List? bytes)` | Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS` chunk of size 4). Filament aborts the process on arbitrary bytes, so this guard is mandatory before `fromBuffer`. |
| `extractFragmentBody` | `static String extractFragmentBody(String source)` | Mirrors the Material Editor: the `fragment { … }` body is what the filamat builder compiles; header keys pick shading/blending. |
| `shadingOf` | `static FilamatShading shadingOf(String source)` |  |
| `blendingOf` | `static BlendingMode blendingOf(String source)` |  |
| `headerParameters` | `static List<(String, String)> headerParameters(String source)` | Parameters declared in the `.mat` header (`parameters : [ { type : float4, name : baseColor } ]`) as (type, name) pairs, so `materialParams.<name>` resolves when compiling. |
| `requiredAttributes` | `static Set<int> requiredAttributes(String source)` | Vertex attributes the `.mat` header's `requires : [ uv0, … ]` block asks for, as `VertexAttribute` indices, the way the Material Editor reads them: `getUV0()` in the fragment only compiles when UV0 is required. |
| `uniformTypeFor` | `static UniformType? uniformTypeFor(String matType)` |  |
| `buildPackageFromSource` | `Uint8List? buildPackageFromSource(String name, String source)` | Builds a package from GLSL [source] with the in-process filamat compiler; null when the compiler rejects it. |
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
| `parse` | `static MatSource parse(String source)` | Splits [source] into blocks. Throws [FormatException] on unbalanced braces. |
| `matchingBrace` | `static int matchingBrace(String s, int open)` | The index of the brace closing the one at [open], skipping strings and comments. |
| `renderHeader` | `static String renderHeader(List<MatEntry> entries)` | Renders a `material` header block from [entries]. |

## `lib/ui/features/sub_editors/services/material_graph_codegen.dart`

### `class MaterialGraphCodegen`

Writes a material graph as `.mat` source.

The `material` header is the current source's, with `parameters` and `requires` rewritten from the graph (every other key kept as written); blocks other than `fragment` are kept as written. The fragment is the graph: expressions inline, a local for every value used more than once (or named in the source it was parsed from), what feeds Normal before `prepareMaterial(material)`, everything else after it. A Custom (Fragment) node replaces the generated fragment with its code, verbatim.

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

The fragment's `material()` body is parsed statement by statement into expressions; the generator's own output parses back into the graph it came from. A call the catalog has no node for becomes a Custom expression node holding its GLSL; anything that cannot be expressed statement by statement (control flow, unknown fields or declarations) makes the whole fragment one Custom (Fragment) node, kept verbatim. Header parameters always become parameter nodes, so a graph edit never drops a declaration.

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
| `reachable` | `final Set<String> reachable` | Nodes that feed the Material output node (or are it). |
| `empty` | `static const MaterialGraphAnalysis empty` |  |
| `outputType` | `MaterialValueType? outputType(String nodeId, String pinId)` |  |
| `inputType` | `MaterialValueType? inputType(String nodeId, String pinId)` |  |
| `hasErrors` | `bool get hasErrors` |  |
| `errorNodeIds` | `Set<String> get errorNodeIds` |  |
| `diagnosticsFor` | `List<MaterialGraphDiagnostic> diagnosticsFor(String nodeId)` |  |
| `inputHasError` | `bool inputHasError(String nodeId, String pinId)` | Whether the wire into [nodeId].[pinId] carries a type error. |

### `class MaterialGraphChecker`

Infers every pin's type (float1–float4 with implicit scalar broadcast, or a texture) and reports what cannot compile.

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

Edits a material graph through the shared Blueprint graph canvas: material expressions instead of lumina's Blueprint node library, float1–float4 and texture pins instead of Blueprint pin types, and the material wiring rule — a wire is refused only for a loop or a texture/number mix-up; any other mismatch is drawn red and reported by the type checker.

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
| `nodeBody` | `Widget? nodeBody(BuildContext context, LuminaBlueprintNode node)` | The Texture Sample node: the bound texture's thumbnail and name; a click opens the searchable picker. |
| `displayType` | `static LuminaPinType displayType(MaterialValueType? t)` | The Blueprint pin type the canvas uses to pick an inline editor. |
| `colorFor` | `static Color colorFor(MaterialValueType? t)` |  |
| `typeOf` | `MaterialValueType? typeOf(String nodeId, String pinId, {required bool output})` | The resolved type of a pin: its fixed type, else what flows through it. |
| `showsInlineLiteral` | `bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)` | Only inputs with a "Const" fallback (Multiply's B, Lerp's Alpha, Fresnel's exponent) edit a constant on the node. |
| `uniqueParameterName` | `String uniqueParameterName(String base)` | A parameter name no node uses yet: [base], `base_1`, `base_2`, … |
| `removeNodes` | `bool removeNodes(Set<String> ids)` | Every node but the Material output can be deleted. |
| `setProperty` | `bool setProperty(String nodeId, String key, Object? value)` | Sets node setting [key] (a constant's value, a parameter's name, a Custom node's code) as one undo step. Renaming a Custom input keeps its wire; removing one drops it. |

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

The Details panel of the material graph: the selected expression's settings — constant values, parameter names and defaults, the texture a TextureSample reads, TexCoord tiling, mask channels, and a Custom node's inputs and GLSL. Every committed edit is one undo step.

**Constructors:**

- `const MaterialNodeDetailsPanel({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final MaterialEditorViewModel viewModel` |  |

---

[Previous: Landscape and foliage](landscape.md) | [Up: Sub-editors](index.md) | [Next: Navigation editor](navigation.md)
