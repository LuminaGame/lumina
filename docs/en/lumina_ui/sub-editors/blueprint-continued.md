[Türkçe](../../../tr/lumina_ui/sub-editors/blueprint-continued.md)

# Blueprint editor (continued, part 1)

Continuation of Blueprint editor: the remaining public files under `lib/ui/features/sub_editors/models/`, `lib/ui/features/sub_editors/services/`, `lib/ui/features/sub_editors/view_models/`, `lib/ui/features/sub_editors/views/blueprint/`. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/models/blueprint_compile_status.dart`](#libuifeaturessub_editorsmodelsblueprint_compile_statusdart)
- [`lib/ui/features/sub_editors/models/blueprint_editor_nodes.dart`](#libuifeaturessub_editorsmodelsblueprint_editor_nodesdart)
- [`lib/ui/features/sub_editors/models/blueprint_editor_type_context.dart`](#libuifeaturessub_editorsmodelsblueprint_editor_type_contextdart)
- [`lib/ui/features/sub_editors/models/blueprint_graph_ref.dart`](#libuifeaturessub_editorsmodelsblueprint_graph_refdart)
- [`lib/ui/features/sub_editors/models/blueprint_palette.dart`](#libuifeaturessub_editorsmodelsblueprint_palettedart)
- [`lib/ui/features/sub_editors/models/blueprint_pin_style.dart`](#libuifeaturessub_editorsmodelsblueprint_pin_styledart)
- [`lib/ui/features/sub_editors/services/blueprint_asset_catalog.dart`](#libuifeaturessub_editorsservicesblueprint_asset_catalogdart)
- [`lib/ui/features/sub_editors/services/blueprint_debugger.dart`](#libuifeaturessub_editorsservicesblueprint_debuggerdart)
- [`lib/ui/features/sub_editors/services/blueprint_preview_scene.dart`](#libuifeaturessub_editorsservicesblueprint_preview_scenedart)
- [`lib/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart`](#libuifeaturessub_editorsview_modelsblueprint_enum_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/blueprint_graph_editor.dart`](#libuifeaturessub_editorsview_modelsblueprint_graph_editordart)
- [`lib/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart`](#libuifeaturessub_editorsview_modelsblueprint_interface_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelslevel_blueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/widget_blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelswidget_blueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/views/blueprint/compile_results.dart`](#libuifeaturessub_editorsviewsblueprintcompile_resultsdart)

## `lib/ui/features/sub_editors/models/blueprint_compile_status.dart`

### `enum BlueprintCompileStatus`

The toolbar Compile badge (the compile status): nothing compiled yet this session, edited since the last compile, or the last compile's result.

**Values:**

- `unknown`
- `dirty`
- `error`
- `warning`
- `upToDate`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `label` | `String get label` |  |

## `lib/ui/features/sub_editors/models/blueprint_editor_nodes.dart`

### `abstract final class BlueprintEditorNodes`

Editor-only graph nodes: comment boxes and reroute dots. lumina's node library has neither (it runs graphs, it does not draw them), so they live in the graph as ordinary stored nodes — they save into the `.lmas` with the rest — and [forEngine] strips them before a document reaches the validator, the VM or the Dart generator: a comment is dropped, a reroute is bypassed by wiring its source straight into what it fed.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `comment` | `static const String comment` | A comment box: literals `title`, `width`, `height`, `color` (ARGB int). Its position is the box's top-left; it has no pins. lumina owns the editor-only node kinds ([LuminaBlueprintEditorNodes]): its template graphs carry comment boxes, and its VM and generator strip them. |
| `reroute` | `static const String reroute` | A reroute dot: one input `in` and one output `out`, both typed as the wire it was inserted into (stored on the node's pins). |
| `rerouteIn` | `static const String rerouteIn` |  |
| `rerouteOut` | `static const String rerouteOut` |  |
| `defaultCommentWidth` | `static const double defaultCommentWidth` |  |
| `defaultCommentHeight` | `static const double defaultCommentHeight` |  |
| `defaultCommentColor` | `static const int defaultCommentColor` |  |
| `isEditorOnly` | `static bool isEditorOnly(String registryId)` |  |
| `isComment` | `static bool isComment(LuminaBlueprintNode node)` |  |
| `isReroute` | `static bool isReroute(LuminaBlueprintNode node)` |  |
| `commentWidth` | `static double commentWidth(LuminaBlueprintNode node)` |  |
| `commentHeight` | `static double commentHeight(LuminaBlueprintNode node)` |  |
| `commentColor` | `static int commentColor(LuminaBlueprintNode node)` |  |
| `newComment` | `static LuminaBlueprintNode newComment({required String id, required double x, required double y, double width...` | A new comment box at ([x], [y]) of [width] × [height]. |
| `newReroute` | `static LuminaBlueprintNode newReroute({required String id, required double x, required double y, required Lumi...` | A new reroute at ([x], [y]) carrying [type] (with its class / element type / enum, so the wires through it keep type-checking). |
| `reroutePins` | `static ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs}) reroutePins(LuminaBluepri...` | The pins of a reroute as pin specs (the stored pins carry the type). |
| `nodesInside` | `static List<LuminaBlueprintNode> nodesInside(LuminaBlueprintNode comment, Iterable<LuminaBlueprintNode> nodes,...` | The nodes a comment box [comment] encloses (their top-left inside the box), given each node's rect through [rectOf]; comments never contain comments. |
| `flattenGraph` | `static LuminaBlueprintGraph flattenGraph(LuminaBlueprintGraph graph)` | [graph] without editor-only nodes: comments dropped, every reroute chain replaced by direct wires from its source to each final target ([LuminaBlueprintEditorNodes.flattenGraph]). |
| `forEngine` | `static LuminaBlueprintDocument forEngine(LuminaBlueprintDocument document)` | A deep copy of [document] with every graph flattened: what the validator, the VM (Play) and the Dart generator receive. |
| `forEngineJson` | `static Map<String, dynamic> forEngineJson(Map<String, dynamic> payload)` | [forEngine] on a document JSON payload (Play loading an `.lmas`). |
| `hasEditorNodes` | `static bool hasEditorNodes(LuminaBlueprintDocument document)` | Whether [payload] holds any editor-only node (a quick check before re-serialising a document Play reads from disk). |

## `lib/ui/features/sub_editors/models/blueprint_editor_type_context.dart`

### `class BlueprintEditorTypeContext`

lumina's type context plus what only the editor's palette needs: the interfaces the document implements, so `Event <Function>` rows are offered for those and nothing else. Built by [of] from the context lumina resolves for a document, function or macro.

**Constructors:**

- `const BlueprintEditorTypeContext({super.variables, super.inputActions, super.widgetClasses, super.components, super.selfClass, super.actorParents, super.functio...`
- `factory BlueprintEditorTypeContext.of(LuminaBlueprintTypeContext base, {List<String> implementedInterfaces = const []})`: [base] with [implementedInterfaces] attached.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `implementedInterfaces` | `final List<String> implementedInterfaces` |  |
| `implementedBy` | `static List<String> implementedBy(LuminaBlueprintTypeContext context)` | The interfaces [context] implements: none for a plain lumina context. |

## `lib/ui/features/sub_editors/models/blueprint_graph_ref.dart`

### `enum BlueprintGraphKind`

Which graph of a Blueprint document a tab or a graph editor is about: the event graph, the construction script, one of the user functions or macros (by name), or a Timeline node's curve tab.

**Values:**

- `eventGraph`
- `constructionScript`
- `function`
- `macro`
- `timeline`

### `class BlueprintGraphRef`

**Constructors:**

- `const BlueprintGraphRef.function(String name)`
- `const BlueprintGraphRef.macro(String name)`
- `const BlueprintGraphRef.timeline(String nodeId)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `final BlueprintGraphKind kind` |  |
| `name` | `final String? name` | The function or macro name, or the Timeline node id; null otherwise. |
| `eventGraph` | `static const BlueprintGraphRef eventGraph` |  |
| `constructionScript` | `static const BlueprintGraphRef constructionScript` |  |
| `isFunction` | `bool get isFunction` |  |
| `isMacro` | `bool get isMacro` |  |
| `isTimeline` | `bool get isTimeline` |  |
| `hasGraph` | `bool get hasGraph` | Whether this ref names a node graph the canvas edits. |
| `label` | `String get label` | The tab label. |
| `key` | `String get key` | A stable key for widgets and editor caches. |

## `lib/ui/features/sub_editors/models/blueprint_palette.dart`

### `enum BlueprintPaletteAction`

A palette row that is an editor action rather than a library node, such as the pinned "Promote to Variable".

**Values:**

- `promoteToVariable`
- `addCustomEvent`
- `addComment`
- `collapseNodes`
- `collapseToFunction`
- `collapseToMacro`

### `class BlueprintPaletteEntry`

One row of the graph editor's node palette: a library node, a variable node already bound to one of the document's variables (`Get Speed`), a generated typed-object node (`Get FPSCounter`, `Get CameraBoom`, `Cast To WBP_Menu`) or an editor action (`Promote to Variable`).

**Constructors:**

- `const BlueprintPaletteEntry({required this.registryId, required this.title, required this.category, required this.keywords, required this.headerColor, required...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `registryId` | `final String registryId` |  |
| `title` | `final String title` |  |
| `category` | `final String category` |  |
| `keywords` | `final List<String> keywords` |  |
| `headerColor` | `final int headerColor` |  |
| `kind` | `final LuminaBlueprintNodeKind kind` |  |
| `literals` | `final Map<String, dynamic> literals` | Node settings the entry places the node with (`{'variable': 'Speed'}`, `{'class': 'WBP_HUD', 'element': 'FPSCounter'}`). |
| `deprecation` | `final String? deprecation` | Non-null for a node kept only so old documents load. |
| `isProject` | `final bool isProject` | A Dart function of the project exposed with `@BlueprintCallable` / `@BlueprintPure`, shown with a "Project" badge. |
| `tooltip` | `final String? tooltip` | The function's doc comment (or the annotation's tooltip), on hover. |
| `objectClass` | `final String? objectClass` | The object class the entry is about (`Widget:WBP_HUD` for `Get FPSCounter`, `WidgetElement:text` for `Set Text (Text)`), for the palette's class headers; null for untyped nodes. |
| `action` | `final BlueprintPaletteAction? action` | Non-null for a row that runs an editor action instead of placing a library node. |
| `keyOverride` | `final String? keyOverride` | A key of its own, for a row that places the same node as another row of the same palette ("Create a Reference to Door_01" beside `Door_01`). |
| `pinned` | `final bool pinned` | Listed first, above the graph actions (the `Create a Reference to <Actor>` row at the top of the right-click menu). |
| `key` | `String get key` | A stable key for widgets and tests: the node id, plus the node setting that makes the row unique (variable, element, component, class). |
| `group` | `String get group` | The top-level category (`Math\|Vector` → `Math`). |
| `isAction` | `bool get isAction` |  |
| `haystack` | `String get haystack` | The lower-cased text a search matches against. |
| `matches` | `bool matches(String query)` |  |

### `class BlueprintPinRef`

A pin a new node could be wired from: the pin the user dragged off. An object pin carries its class and an array pin its element type, so the palette can be context sensitive.

**Constructors:**

- `const BlueprintPinRef({required this.nodeId, required this.pinId, required this.type, required this.isOutput, this.objectClass, this.elementType, this.enumName,...`
- `factory BlueprintPinRef.of(String nodeId, LuminaBlueprintPinSpec pin, {required bool isOutput})`: The ref of [pin] on node [nodeId].
- `factory BlueprintPinRef.self(LuminaBlueprintTypeContext context)`: A `Self` reference: what the Blueprint's own actor pins carry (`Actor:BP_ThirdPersonCharacter`); dragging it lists the component tree. The node id is empty: nothing is wired to it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `nodeId` | `final String nodeId` |  |
| `pinId` | `final String pinId` |  |
| `type` | `final LuminaPinType type` |  |
| `isOutput` | `final bool isOutput` |  |
| `objectClass` | `final String? objectClass` |  |
| `elementType` | `final LuminaPinType? elementType` |  |
| `enumName` | `final String? enumName` | The enum of an enumeration pin. |
| `isSelf` | `bool get isSelf` |  |
| `spec` | `LuminaBlueprintPinSpec get spec` | This pin as the library describes it, for [LuminaBlueprintNodeLibrary.canConnect]. |

### `abstract final class BlueprintPalette`

The node palette over lumina's [LuminaBlueprintNodeLibrary]: every library node grouped by category, variable nodes expanded per declared variable, searchable by title, category and keywords, and filtered to the nodes that can take a wire from a dragged pin. Pure Dart: the editor keeps no catalog of its own, and the typed-object rows (`Get <Element>`, `Get <Component>`, `Cast To <Class>`, Promote to Variable) are generated per drag from the [LuminaBlueprintTypeContext].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `promoteToVariableId` | `static const String promoteToVariableId` |  |
| `promoteToVariable` | `static const BlueprintPaletteEntry promoteToVariable` | The pinned first row of a pin drag: Promote to Variable. |
| `addCustomEvent` | `static const BlueprintPaletteEntry addCustomEvent` | The graph actions of the right-click menu, offered as pinned rows of the palette: Add Custom Event…, Add Comment, and — with a selection — Collapse Nodes / to Function / to Macro. |
| `addComment` | `static const BlueprintPaletteEntry addComment` |  |
| `collapseNodes` | `static const BlueprintPaletteEntry collapseNodes` |  |
| `collapseToFunction` | `static const BlueprintPaletteEntry collapseToFunction` |  |
| `collapseToMacro` | `static const BlueprintPaletteEntry collapseToMacro` |  |
| `engineActorClasses` | `static const List<String> engineActorClasses` | Engine actor classes a Cast To can target besides the project's own Blueprint classes. |
| `signatureNodes` | `static const Set<String> signatureNodes` | Every entry for a graph whose variables are [variables]. [filter] restricts the library (a transition rule allows pure nodes only). Library nodes that only make sense bound to a document signature: the palette lists them per function / macro / event / dispatcher / interface function / enum through [generated], never bare. |
| `levelActorReference` | `static BlueprintPaletteEntry levelActorReference(LuminaBlueprintLevelActorRef ref, {bool createReference = fal...` | The palette row of a reference to the level's placed actor [ref]: titled with the actor's name, under **Level Actors**; [createReference] words it as the right-click menu's pinned `Create a Reference to <Actor>`. |
| `widgetEntries` | `static List<BlueprintPaletteEntry> widgetEntries(LuminaBlueprintTypeContext context, {BlueprintPinRef? from, b...` | A widget graph's rows: `<Element>` (Get) per `Is Variable` element under **Widgets**, and `On <Event> (<Element>)` per event each offers under **Widget Events**; from a pin, only the Gets. |
| `scoped` | `static bool Function(LuminaBlueprintNodeSpec spec) scoped(LuminaBlueprintTypeContext context, bool Function(Lu...` | [filter] narrowed to the nodes lumina allows in [context]'s scope (level-only nodes in a Level Blueprint, component nodes everywhere else). |
| `entries` | `static List<BlueprintPaletteEntry> entries({List<LuminaBlueprintVariable> variables = const [], bool Function(...` |  |
| `generated` | `static List<BlueprintPaletteEntry> generated(LuminaBlueprintTypeContext context, {BlueprintPinRef? from, bool...` | The generated rows of [context]: one `Get <Element>` per element of every widget class, one `Get <Component>` per component, and one `Cast To <Class>` per widget and actor class. With [from], only the rows that concern the dragged pin: the elements of its widget class, the components when it is Self. |
| `signatureEntries` | `static List<BlueprintPaletteEntry> signatureEntries(LuminaBlueprintTypeContext context, {bool Function(LuminaB...` | The rows bound to the document's signatures: a `Call <Function>` per user function (pure ones as pure nodes), a call per macro and custom event, Call / Bind / Unbind / Unbind All per dispatcher, `<Function> (Message)` per project interface function, `Event <Function>` per function of an implemented interface, the enum nodes per project enum, and local variable Get / Set in a function. |
| `castTargets` | `static List<String> castTargets(LuminaBlueprintTypeContext context)` | The classes a Cast To can target in [context]: the widget classes, then the project's Blueprint actor classes and the engine's actor classes. |
| `entriesFor` | `static List<BlueprintPaletteEntry> entriesFor(LuminaBlueprintTypeContext context, BlueprintPinRef? from, {bool...` | The context-sensitive palette for a drag off [from] (or the full palette when null): library entries, variable nodes, the generated typed rows, each narrowed to nodes with a pin [from] can join, and — for a data output — Promote to Variable pinned first. Pure: the same inputs give the same rows. |
| `search` | `static List<BlueprintPaletteEntry> search(List<BlueprintPaletteEntry> entries, String query)` | [entries] matching [query]: every term must occur in the entry's haystack, built once per entry per search. |
| `rank` | `static int rank(BlueprintPaletteEntry entry, String query)` | How well [entry] answers [query], for ordering search results: 0 when every term is in the title (`movement` → Add Movement Input), 1 when only the category, id or keywords match. |
| `relevance` | `static int relevance(BlueprintPaletteEntry entry, BlueprintPinRef? from, LuminaBlueprintTypeContext context)` | How closely [entry] concerns the class of the dragged pin [from], for ordering a context-sensitive palette: 0 when the entry is about exactly that class (the widget's elements, the element type's setters, the component class's nodes), 1 when about a class the pin is assignable to (any widget, any element), 2 for nodes that take any object or another type. |
| `compatiblePin` | `static String? compatiblePin(BlueprintPaletteEntry entry, BlueprintPinRef from, LuminaBlueprintTypeContext con...` | The pin of [entry]'s node a wire from [from] would join: an input the library lets [from] connect to when [from] is an output, an output when it is an input. Null when the node has no such pin, or [entry] is an action. |
| `compatibleWith` | `static List<BlueprintPaletteEntry> compatibleWith(List<BlueprintPaletteEntry> entries, BlueprintPinRef from, L...` | [entries] narrowed to nodes with a pin [from] can connect to. Actions stay, and so do the `Get <Component>` rows and the nodes that act on an implicit Self (`Self\|…` and the `…_trace_forward` traces, no target pin) of a Self drag: Self is the node's implicit target, not a wire. |
| `takesImplicitSelf` | `static bool takesImplicitSelf(BlueprintPaletteEntry entry)` | Whether [entry] acts on the Blueprint's own actor without a target pin, so a Self drag offers it. |
| `promotedName` | `static String promotedName(String pinName, {String? objectClass, String? nodeRegistryId})` | The name for a promoted variable: the pin's name in PascalCase (`Return Value` of a `Create Widget` of `WBP_HUD` → `HudWidget`; `As Class` of a Cast To `BP_Door` → `AsBpDoor`; `Delta Seconds` → `DeltaSeconds`). |

## `lib/ui/features/sub_editors/models/blueprint_pin_style.dart`

### `abstract final class BlueprintPinStyle`

How the graph editor draws a pin of [LuminaPinType]: its colour and the label the My Blueprint panel's type chip shows. Presentation only; the types themselves come from lumina's node library.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `color` | `static Color color(LuminaPinType? type)` |  |
| `label` | `static String label(LuminaPinType? type)` |  |
| `variableTypeNames` | `static const List<String> variableTypeNames` | The basic variable types the My Blueprint panel offers, as stored in the document's `type` field (lumina's `LuminaPinType.parseVariableType`). |
| `pinLabel` | `static String pinLabel(LuminaBlueprintPinSpec pin)` | What a pin's tooltip and the palette's "From" line call [pin]: the class of an object pin (`Widget (WBP_HUD)`, `Text Block`, `Spring Arm`), `Array of Float` for a typed array, the type otherwise. |
| `variableLabel` | `static String variableLabel(String typeName)` | What the type chip shows for a variable declared as [typeName]: the class of an object variable (`Widget (WBP_HUD)`, `Text Block`, `Spring Arm`, `BP_Door`), `Array of Float` for arrays, the type otherwise. |
| `variableTypeGroups` | `static List<BlueprintVariableTypeGroup> variableTypeGroups(LuminaBlueprintTypeContext context)` | The My Blueprint type picker's groups: Basic, Object, the project's widget classes, every widget element type, the document's component classes and the actor classes, each as the type name the document stores. |
| `parameterTypeGroups` | `static List<BlueprintVariableTypeGroup> parameterTypeGroups(LuminaBlueprintTypeContext context, {bool allowExe...` | Types a function / macro / dispatcher parameter may take: the variable types plus `Exec` for macro pins when [allowExec]. |
| `defaultValueFor` | `static Object? defaultValueFor(String typeName)` | The literal a new variable (or a reset pin) of [typeName] starts at. |

### `class BlueprintVariableTypeGroup`

One group of the type picker: its heading and the type names it offers.

**Constructors:**

- `const BlueprintVariableTypeGroup(this.title, this.typeNames)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `title` | `final String title` |  |
| `typeNames` | `final List<String> typeNames` |  |

## `lib/ui/features/sub_editors/services/blueprint_asset_catalog.dart`

### `class BlueprintAssetCatalog`

The Blueprint-side assets of a project that are not actor Blueprints: enum (`contents/enums/E_*.lmas`) and interface (`contents/interfaces/BPI_*.lmas`) assets — `.lmas` files of [AssetType.actor] whose payload carries lumina's `kind` discriminator — plus the asset paths the literal editors pick from (sounds, montages, materials, particles, levels, save classes). Read from disk, refreshed on [AssetRepository.onAssetsChanged], and registered into lumina's [LuminaBlueprintEnums] / [LuminaBlueprintInterfaces] so the validator, the generator and Play resolve them.

**Constructors:**

- `BlueprintAssetCatalog(this.projectDir, {bool watch = true})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `enumsFolder` | `static const String enumsFolder` |  |
| `interfacesFolder` | `static const String interfacesFolder` |  |
| `enumAssets` | `List<BlueprintEnumAsset> get enumAssets` |  |
| `interfaceAssets` | `List<BlueprintInterfaceAsset> get interfaceAssets` |  |
| `enums` | `List<LuminaBlueprintEnumDocument> get enums` |  |
| `interfaces` | `List<LuminaBlueprintInterfaceDocument> get interfaces` |  |
| `enumeration` | `LuminaBlueprintEnumDocument? enumeration(String? name)` |  |
| `interface` | `LuminaBlueprintInterfaceDocument? interface(String? name)` |  |
| `assetPaths` | `List<String> assetPaths(BlueprintAssetKind kind)` | Project-relative `.lmas` paths of [kind], for an asset pin's picker. |
| `refresh` | `void refresh()` | Re-reads the project; listeners are told when anything changed. |
| `registerRuntimeAssets` | `void registerRuntimeAssets()` | Makes the project's enums and interfaces known to lumina's registries (the type context, the validator and Play read them there). |
| `documentKindOf` | `static String? documentKindOf(String? path)` | Reads the `kind` of the Blueprint document in the `.lmas` at [path]: `class`, `enum`, `interface`, … or null when the file is not a Blueprint asset. |
| `isEnumLmas` | `static bool isEnumLmas(String? path)` |  |
| `isInterfaceLmas` | `static bool isInterfaceLmas(String? path)` |  |
| `scanEnums` | `static List<BlueprintEnumAsset> scanEnums(String projectDir)` | Every enum asset under `contents/` of [projectDir], by name. |
| `scanInterfaces` | `static List<BlueprintInterfaceAsset> scanInterfaces(String projectDir)` | Every interface asset under `contents/` of [projectDir], by name. |
| `scanAssetPaths` | `static Map<BlueprintAssetKind, List<String>> scanAssetPaths(String projectDir)` | The project-relative paths of every asset a literal editor may pick, by kind: from the asset's indexed type, Blueprint document kind and the folder it lives in. |
| `uniqueName` | `static String uniqueName(String projectDir, String folder, String name)` | A name no `.lmas` in [folder] uses yet: [name], else `<name>_<n>`. |
| `writeEnum` | `static String writeEnum(String projectDir, LuminaBlueprintEnumDocument document, {String? path})` | Writes the enum asset `contents/enums/<name>.lmas` and returns its project-relative path. |
| `writeInterface` | `static String writeInterface(String projectDir, LuminaBlueprintInterfaceDocument document, {String? path})` | Writes the interface asset `contents/interfaces/<name>.lmas` and returns its project-relative path. |
| `readEnum` | `static LuminaBlueprintEnumDocument? readEnum(String path)` | The enum document stored at [path], or null. |
| `readInterface` | `static LuminaBlueprintInterfaceDocument? readInterface(String path)` | The interface document stored at [path], or null. |
| `remapSwitchWires` | `static int remapSwitchWires(LuminaBlueprintGraph graph, String enumName, List<String> oldValues, List<String>...` | Rewires every `Switch on <enum>` of [graph] after the enum's values went from [oldValues] to [newValues]: a case pin follows its value's name, not its index. Returns how many wires moved; wires of removed values are dropped. |
| `remapDocumentSwitchWires` | `static int remapDocumentSwitchWires(LuminaBlueprintDocument document, String enumName, List<String> oldValues,...` | [remapSwitchWires] on every graph of [document]. |
| `remapProjectSwitchWires` | `static List<String> remapProjectSwitchWires(String projectDir, String enumName, List<String> oldValues, List<S...` | Rewrites every actor Blueprint `.lmas` of [projectDir] whose switches name [enumName], after its values were reordered; returns the project-relative paths touched. |

### `class BlueprintEnumAsset`

An enum asset on disk.

**Constructors:**

- `const BlueprintEnumAsset({required this.path, required this.document})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `document` | `final LuminaBlueprintEnumDocument document` |  |

### `class BlueprintInterfaceAsset`

An interface asset on disk.

**Constructors:**

- `const BlueprintInterfaceAsset({required this.path, required this.document})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `document` | `final LuminaBlueprintInterfaceDocument document` |  |

### `enum BlueprintAssetKind`

What an asset pin's picker lists.

**Values:**

- `sound`
- `montage`
- `material`
- `particle`
- `level`
- `saveGame`

## `lib/ui/features/sub_editors/services/blueprint_debugger.dart`

### `class BlueprintTraceRecorder`

Live execution of one running Blueprint instance (the Blueprint debugger): the nodes it ran and the exec wires it took in the last [window], and the last value of every pin. Fed by the instance's `trace`; read by the graph canvas.

**Constructors:**

- `BlueprintTraceRecorder(this.graph)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `window` | `static const Duration window` |  |
| `eventCount` | `int eventCount` | Every trace event received, for tests and the status line. |
| `record` | `void record(LuminaBlueprintTraceEvent event)` | Records one executed or evaluated node. |
| `activeNodeIds` | `Set<String> get activeNodeIds` | Nodes run in the last [window]. |
| `activeWireIds` | `Set<String> get activeWireIds` | Exec wires taken in the last [window]. |
| `intensity` | `double intensity(String nodeId, {bool wire = false})` | 1 just after a node ran, fading to 0 over [window]. |
| `lastValue` | `Object? lastValue(String nodeId, String pinId)` | The last value [nodeId]'s pin [pinId] carried, or null. |
| `hasValue` | `bool hasValue(String nodeId, String pinId)` |  |

### `class BlueprintPieDebugger`

The Blueprint instances a Play session debugs: the possessed pawn's, and the selected placed Blueprint actor's, by the project-relative path of their class. Blueprint editors showing one of those classes light up its graph.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `static final BlueprintPieDebugger instance` |  |
| `isRunning` | `bool get isRunning` |  |
| `targets` | `Map<String, LuminaBlueprintInstance> get targets` |  |
| `recorderFor` | `BlueprintTraceRecorder? recorderFor(String path)` | The recorder for class [path], or null when no debugged instance plays it. |
| `setTargets` | `void setTargets(Map<String, LuminaBlueprintInstance> targets)` | Debugs [targets] (path → instance), replacing what was debugged. |
| `clear` | `void clear()` | Play stopped. |

### `class BlueprintBreakpointHit`

A `breakpoint` node reached during Play: Play pauses on it and the Blueprint editor frames the node. Cleared when Play resumes or stops.

**Constructors:**

- `const BlueprintBreakpointHit({required this.blueprintPath, required this.nodeId, required this.at})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `blueprintPath` | `final String blueprintPath` |  |
| `nodeId` | `final String nodeId` |  |
| `at` | `final DateTime at` |  |
| `blueprintName` | `String get blueprintName` |  |

### `class BlueprintBreakpoints`

The breakpoint Play is paused on, if any.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `static final BlueprintBreakpoints instance` |  |
| `hitCount` | `int hitCount` |  |
| `current` | `BlueprintBreakpointHit? get current` |  |
| `hit` | `bool hit(String blueprintPath, String nodeId)` | Records a hit; returns false when Play is already stopped on one. |
| `clear` | `void clear()` |  |

### `class BlueprintNavigation`

Requests to open a Blueprint at a node (Play's compile-errors dialog): a Blueprint editor showing [path] selects and frames [nodeId].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `instance` | `static final BlueprintNavigation instance` |  |
| `pending` | `({String path, String nodeId})? get pending` | The newest request, until an editor for its Blueprint takes it. |
| `request` | `void request(String path, String nodeId)` |  |
| `take` | `String? take(String path)` | The pending node for [path], consumed; null when none. |

## `lib/ui/features/sub_editors/services/blueprint_preview_scene.dart`

### `class BlueprintPreviewScene`

The Blueprint editor's 3D Viewport: the Blueprint's actor built the way Play builds it, in the viewport's preview world.

- The components come from lumina's `LuminaBlueprintComponents.construct` on a `LuminaCharacter` / `LuminaPawn` / `LuminaActor` (the Blueprint VM's own parents), with the project class registry's asset resolver (a mesh `.lmas` loads through its `.entity.glb`) and Anim Class factory, so transforms convert from authoring space (cm, Z up) through `LuminaAxes` exactly as in Play and the generated game. - A Skeletal Mesh with an Animation Blueprint runs it: editor worlds do not tick gameplay, so the scene ticks the Anim Blueprint instances, then the meshes, then the world's render prep. The pawn stands still, so the Third Person character plays its Idle state. - Collision shapes (capsule, box, sphere, cylinder, cone, convex hull), spring arms, cameras and arrows are drawn as line overlays ([overlays]); the selected component is highlighted (a mesh by its bounds). Nothing looks through the Blueprint's cameras: they stay inactive, and the viewport keeps its orbit camera.

Every world the viewport hands over gets a fresh actor (switching tabs remounts the viewport); a document edit that changes a component rebuilds it, and so does a texture its materials draw being saved again (checked about once a second). Without a world the actor is still built (unregistered) so the overlays and [framing] are known before the viewport opens.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `diagnostics` | `final List<LuminaBlueprintDiagnostic> diagnostics` | What went wrong building the actor (unknown component types, an Anim Class that does not compile), newest last. |
| `tickSeconds` | `static const double tickSeconds` |  |
| `shapeTypes` | `static const Set<String> shapeTypes` | The shape collision components drawn through lumina's `LuminaCollisionComponent.buildWireframe`; the capsule keeps its own `buildCapsuleWireframe`. |
| `capsuleColor` | `static const (double, double, double) capsuleColor = (0.95, 0.42, 0.55)` | Component-visualizer hues, saturated enough to read on the grey backdrop: a pink capsule, a red spring arm, a blue camera, and the orange selection. |
| `springArmColor` | `static const (double, double, double) springArmColor = (1.0, 0.18, 0.15)` |  |
| `cameraColor` | `static const (double, double, double) cameraColor = (0.3, 0.65, 1.0)` |  |
| `selectionColor` | `static const (double, double, double) selectionColor = (1.0, 0.6, 0.1)` |  |
| `world` | `LuminaWorld? get world` |  |
| `isAttached` | `bool get isAttached` |  |
| `hasNativeWorld` | `bool get hasNativeWorld` |  |
| `actor` | `LuminaActor? get actor` | The preview actor (registered in [world] while attached). |
| `revision` | `int get revision` | Bumped whenever the actor is rebuilt or a mesh of it finishes loading. |
| `componentFor` | `LuminaActorComponent? componentFor(String id)` | The component built for Blueprint component [id], or null. |
| `animInstanceFor` | `LuminaAnimBlueprintInstance? animInstanceFor(String id)` | The Animation Blueprint instance playing on mesh component [id]. |
| `selected` | `String? get selected` | The highlighted component. |
| `setDocument` | `void setDocument(LuminaBlueprintDocument document, {String? projectDir})` | Shows [document]'s components (a copy is built; the signature of its components decides whether anything changed). [projectDir] resolves mesh assets and Anim Classes. |
| `select` | `void select(String? id)` | Highlights component [id] (null: none). |
| `attach` | `void attach(LuminaWorld world, {bool startTicker = true})` | Builds the actor in the viewport's [world] and starts ticking it. |
| `attachHeadless` | `void attachHeadless()` | A world of its own with no native context (widget tests): the actor and its Anim Blueprint run, nothing draws. Ticked by [advance]. |
| `detach` | `void detach()` | Releases the world. The actor is built again, unregistered. |
| `advance` | `void advance(double dt)` | One preview frame of [dt] seconds: Anim Blueprints choose the pose, meshes apply it, the world syncs transforms to Filament. |
| `summary` | `String get summary` | One line for the viewport's stats strip: the mesh, and what it plays. |
| `sceneTransformFor` | `({Vector3 worldLocation, Quaternion worldRotation, Quaternion parentRotation})? sceneTransformFor(String id)` | The built scene component of [id] as the viewport's gizmo needs it: its world location and rotation, and its parent's world rotation (the frame its relative transform is written in), all runtime frame (Y up). |
| `setComponentTransform` | `void setComponentTransform(String id, {List<double>? location, List<double>? rotation, List<double>? scale})` | Moves the built component of [id] live, as a gizmo drag writes the relative [location] / [rotation] / [scale] (authoring values), without rebuilding the actor: spring arms re-place their children, the overlays follow, and the attached world's next tick syncs Filament. |
| `pick` | `String? pick(ViewportRay ray)` | The scene component under [ray] (runtime frame): the nearest hit among the components' bounding boxes — a capsule's, boom's, camera's or arrow's drawn lines, a mesh's bounds — or null. Boxes thinner than [pickPadding] (a boom is a line) are padded so they can be hit. |
| `pickPadding` | `static const double pickPadding` |  |
| `centerOfMassColor` | `static const (double, double, double) centerOfMassColor = (1.0, 0.25, 0.85)` | The centre-of-mass marker's colour. |
| `centerOfMassOf` | `static Vector3 centerOfMassOf(LuminaPrimitivePhysics component)` | Where [component]'s body turns about, world space (runtime, cm): its shapes' centroid moved by its (or its mesh's) centre-of-mass offset. |
| `overlays` | `List<SubEditorLineSet> get overlays` | The line overlays, in runtime space (Y up, cm). |
| `framing` | `({Vector3 target, double distance}) get framing` | Where the viewport's orbit camera starts (runtime space, cm): centred on the actor's body — its capsule and meshes, framing a Blueprint by its primitives — from twice the distance that fits them in the 45° view, which leaves the boom and the camera behind it in frame. |

## `lib/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart`

### `class BlueprintEnumViewModel`

The Enumeration sub-editor's state: lumina's [LuminaBlueprintEnumDocument] read from and written to the enum `.lmas` (`contents/enums/E_*.lmas`, payload `kind: enum`). Values are ordered, renamed and reordered here; every edit is one undo step, and saving a reordered enum moves the `Switch on <enum>` case wires of every Blueprint in the project so each case keeps following its value by name.

**Constructors:**

- `BlueprintEnumViewModel({required this.assetPath, String? name, List<String>? values})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetPath` | `final String assetPath` |  |
| `transactions` | `final TransactionManager transactions` |  |
| `name` | `String get name` |  |
| `values` | `List<String> get values` |  |
| `selectedIndex` | `int? get selectedIndex` |  |
| `isDirty` | `bool get isDirty` |  |
| `document` | `LuminaBlueprintEnumDocument get document` |  |
| `projectDir` | `String? get projectDir` | The project directory the asset lives in (its `contents/` ancestor), or null. |
| `load` | `Future<void> load() async` |  |
| `save` | `Future<bool> save() async` | Writes the `.lmas`; a reorder / rename also rewires the project's switches on this enum. Returns whether the file was written. |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `select` | `void select(int? index)` |  |
| `addValue` | `String addValue([String? name])` | Adds a value and selects it; returns its name. Without [name] the next free `NewEnumerator<n>`; a given name gets a numeric suffix if taken. |
| `renameValue` | `bool renameValue(int index, String newName)` |  |
| `removeValue` | `bool removeValue(int index)` |  |
| `moveValue` | `bool moveValue(int from, int to)` | Moves the value at [from] to [to] (reorder). |
| `moveUp` | `bool moveUp(int index)` |  |
| `moveDown` | `bool moveDown(int index)` |  |

## `lib/ui/features/sub_editors/view_models/blueprint_graph_editor.dart`

### `abstract interface class BlueprintGraphHost`

What a [BlueprintGraphEditor] edits against: the document's variables and input actions, and its undo history. The Blueprint editor, the Animation Blueprint editor's event graph and each transition rule share one canvas through this seam (one graph canvas).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `typeContext` | `LuminaBlueprintTypeContext get typeContext` |  |
| `availableWidgetClasses` | `List<String> get availableWidgetClasses` | Available widget classes in the project (UMG widgets). |
| `declareVariable` | `void declareVariable(LuminaBlueprintVariable variable)` | Adds [variable] to the document without recording an undo step: called inside [mutate] by Promote to Variable, so the variable and its Set node are one step. Hosts without variables ignore it. |
| `mutate` | `T mutate<T>(String label, T Function() mutation)` | Runs [mutation] as one undoable step labelled [label]. A mutation that returns null or false changes nothing and records nothing. |
| `beginInteraction` | `void beginInteraction(String label)` | Starts a coalesced interaction (a node drag): edits between this and [endInteraction] become one undo step. |
| `endInteraction` | `void endInteraction({bool layoutOnly = false})` | Ends the interaction. [layoutOnly] edits (moving nodes) do not make the compiled code stale. |

### `class BlueprintNodeProblem`

A live problem on a node, drawn as the node's banner.

**Constructors:**

- `const BlueprintNodeProblem(this.message, {this.isError = true})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `isError` | `final bool isError` |  |

### `typedef BlueprintResolvedPins`

### `class BlueprintGraphEditor`

Edits one [LuminaBlueprintGraph] through lumina's node library: placing nodes, wiring typed pins, literals, input actions and variables, with every change an undoable step on the [host]. Selection lives here; the document lives in the host.

**Constructors:**

- `BlueprintGraphEditor({required this.host, required this.graphSource, this.nodeFilter, this.diagnosticsSource, this.contextSource, this.pinOptionsProvider, this....`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `host` | `final BlueprintGraphHost host` |  |
| `graphSource` | `final LuminaBlueprintGraph? Function() graphSource` | The graph edited now; looked up on every access because an undo replaces the host's document. |
| `nodeFilter` | `final bool Function(LuminaBlueprintNodeSpec spec)? nodeFilter` | Library nodes this graph accepts (a transition rule: pure nodes only). |
| `diagnosticsSource` | `final Iterable<LuminaBlueprintDiagnostic> Function()? diagnosticsSource` | The last compile's diagnostics, for outlining failing nodes. |
| `contextSource` | `final LuminaBlueprintTypeContext Function()? contextSource` | The type context this graph resolves pins in when it is not the host's own (a function graph scopes its entry / result / local variables, a macro its inputs / outputs). |
| `pinOptionsProvider` | `final List<String>? Function(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)? pinOptionsProvider` | Dropdown choices for a pin the host knows better than the library: the project's asset paths of a kind (`sound`, `montage`, `material`, `particle`, `level`, `savegame`) for asset pins. |
| `pinnedEntriesSource` | `final List<BlueprintPaletteEntry> Function()? pinnedEntriesSource` | Rows the right-click palette pins first (e.g. `Create a Reference to <Actor>` for the outliner's selected actors). |
| `ValueNotifier` | `final ValueNotifier<({String nodeId, int serial})?> focusRequest = ValueNotifier(null)` | Asks the canvas to frame a node (Compiler Results navigation). |
| `graph` | `LuminaBlueprintGraph get graph` |  |
| `nodes` | `List<LuminaBlueprintNode> get nodes` |  |
| `wires` | `List<LuminaBlueprintWire> get wires` |  |
| `context` | `LuminaBlueprintTypeContext get context` |  |
| `documentChanged` | `void documentChanged()` | The host replaced or edited the document: repaint. |
| `debug` | `BlueprintTraceRecorder? get debug` | Live execution of the running instance this graph belongs to, during Play; null otherwise. |
| `debug` | `set debug(BlueprintTraceRecorder? value)` |  |
| `newId` | `static String newId(String prefix)` |  |
| `node` | `LuminaBlueprintNode? node(String id)` |  |
| `pinsOf` | `BlueprintResolvedPins pinsOf(LuminaBlueprintNode node)` | The node's pins as the library resolves them now (an input action's Action Value takes the action's type); stored pins for an unknown node. |
| `pin` | `LuminaBlueprintPinSpec? pin(String nodeId, String pinId, {required bool output})` |  |
| `isConnected` | `bool isConnected(String nodeId, String pinId, {required bool output})` |  |
| `paletteEntries` | `List<BlueprintPaletteEntry> paletteEntries()` | The palette for this graph: library nodes allowed here, variable nodes per declared variable. |
| `paletteActions` | `List<BlueprintPaletteEntry> paletteActions({bool canCollapse = false})` | The graph actions the right-click palette pins first: Add Custom Event… where events are allowed, Add Comment, and the collapse actions when [canCollapse]. |
| `paletteEntriesFor` | `List<BlueprintPaletteEntry> paletteEntriesFor(BlueprintPinRef from)` | The context-sensitive palette for a drag off [from]: only nodes with a pin [from] can join, the typed rows of its class (`Get <Element>` of its widget class, the component tree from Self, `Cast To`), with Promote to Variable pinned first for a data output. |
| `problems` | `List<BlueprintNodeProblem> problems(LuminaBlueprintNode node)` | Live problems of [node]: an unknown or deprecated node, a missing input action or variable. Shown as a banner before any compile. |
| `errorNodeIds` | `Set<String> get errorNodeIds` | Nodes the last compile reported an error on. |
| `whyNotConnect` | `String? whyNotConnect(String fromNodeId, String fromPinId, String toNodeId, String toPinId)` | Why a wire from [fromNodeId].[fromPinId] (an output) to [toNodeId].[toPinId] (an input) cannot be made, or null when it can. |
| `pinColor` | `Color pinColor(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output})` | The colour of [pin]'s anchor and of wires leaving it. |
| `pinTypeLabel` | `String pinTypeLabel(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output})` | [pin]'s type as the context-sensitive palette names it. |
| `showsInlineLiteral` | `bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)` | Whether an unconnected input edits its literal inline (when the type has an inline editor at all). |
| `compatibleEntries` | `List<BlueprintPaletteEntry> compatibleEntries(List<BlueprintPaletteEntry> entries, BlueprintPinRef from)` | [entries] narrowed to nodes that can take a wire from [from]. |
| `wireHasProblem` | `bool wireHasProblem(LuminaBlueprintWire wire)` | Whether [wire] is drawn as broken. |
| `nodeBodyHeight` | `double nodeBodyHeight(LuminaBlueprintNode node)` | Height of the widget [nodeBody] draws under a node's header (0: none). |
| `nodeBody` | `Widget? nodeBody(BuildContext context, LuminaBlueprintNode node)` | A widget drawn between a node's header and its pins (the Material Editor's texture thumbnail on a Texture Sample node); null for none. |
| `settingPins` | `static const Map<String, Set<String>> settingPins` | Node settings that are also pins (`class` of Cast To, `element` of Get Element, `component` of Get Component): editing them retitles and re-types the node, so [setLiteral] routes them to [setNodeSetting]. |
| `inputKeyNodes` | `static const Set<String> inputKeyNodes` | Nodes whose `Key` pin names an engine input key. |
| `pinOptions` | `List<String>? pinOptions(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)` | Dropdown options for a pin's literal value, or null if it uses a standard editor. |
| `wireColor` | `Color wireColor(LuminaBlueprintWire wire)` | The colour [wire] is drawn in: its source pin's. |
| `selectedNodeIds` | `Set<String> get selectedNodeIds` |  |
| `select` | `void select(String nodeId, {bool additive = false})` |  |
| `toggle` | `void toggle(String nodeId)` |  |
| `selectMany` | `void selectMany(Set<String> ids)` |  |
| `clearSelection` | `void clearSelection()` |  |
| `focusNode` | `void focusNode(String nodeId)` | Selects [nodeId] and asks the canvas to centre it. |
| `accepts` | `bool accepts(String registryId)` | Whether this graph takes library node [registryId]: the graph's own filter, and lumina's scope rule (level-only nodes only in a Level Blueprint, component nodes everywhere else). |
| `addNode` | `LuminaBlueprintNode? addNode(String registryId, Offset position, {Map<String, dynamic>? literals})` | Places library node [registryId] at [position] (canvas coordinates). |
| `placeEntry` | `LuminaBlueprintNode? placeEntry(BlueprintPaletteEntry entry, Offset position, {BlueprintPinRef? from})` | Places [entry] at [position] and, when the user dragged off [from], wires the new node's compatible pin to it, in one undo step. |
| `placeVariable` | `LuminaBlueprintNode? placeVariable(String name, {required bool set, required Offset position})` | A Get or Set node for variable [name] (My Blueprint drag). |
| `placeLevelActor` | `LuminaBlueprintNode? placeLevelActor(String name, {required Offset position})` | A reference to the level's placed actor [name] (`Get Door_01`): an outliner or Level Actors drag, or `Create a Reference to <Actor>`. Null outside a Level Blueprint or for an actor the level does not have. |
| `placeComponent` | `LuminaBlueprintNode? placeComponent(String name, {required Offset position})` | A `Get <Component>` node for the Blueprint's component [name] (My Blueprint's Components section drag). |
| `placeElementGet` | `LuminaBlueprintNode? placeElementGet(String variable, String element, {required Offset position})` | `Get <variable>` → `Get <element>` for widget variable [variable]'s element [element], wired, in one undo step (My Blueprint's element list). |
| `variableTypeFor` | `String? variableTypeFor(BlueprintPinRef ref)` | The variable type name a pin of [ref] promotes to (`Widget:WBP_HUD`, `Float`, `Array:Float`), or null when the pin cannot become a variable. |
| `promoteToVariable` | `LuminaBlueprintNode? promoteToVariable(BlueprintPinRef from, {Offset? position})` | Promote to Variable: declares a variable named after [from] (`HudWidget` for Create Widget WBP_HUD's Return Value), typed with the pin's class, places its Set node at [position] wired from the pin and spliced into the source node's exec chain, in one undo step. Returns the Set node; null for a pin that cannot be promoted. |
| `adoptWildcardTypesFromWires` | `void adoptWildcardTypesFromWires()` | Types every still-untyped wildcard node from its existing wires — for graphs saved before wildcard nodes adopted a type when wired. Not an undo step: it only makes pins show what the wires already carry. |
| `addWire` | `LuminaBlueprintWire? addWire({required String fromNodeId, required String fromPinId, required String toNodeId,...` | Wires output [fromPinId] to input [toPinId]; null (nothing recorded) when the pins are incompatible. |
| `connectPins` | `LuminaBlueprintWire? connectPins(BlueprintPinRef a, BlueprintPinRef b)` | Joins two pins in whichever direction they allow. |
| `removeWire` | `bool removeWire(String wireId)` |  |
| `breakLinks` | `bool breakLinks(String nodeId, String pinId, {required bool output})` | Break Link(s) on a pin. |
| `removeNode` | `bool removeNode(String nodeId)` |  |
| `removeNodes` | `bool removeNodes(Set<String> ids)` |  |
| `removeSelected` | `bool removeSelected()` |  |
| `setLiteral` | `bool setLiteral(String nodeId, String pinId, Object? value)` | Sets an unconnected input's literal; one undo step per committed edit. |
| `setNodeAction` | `bool setNodeAction(String nodeId, String action)` | Points an EnhancedInputAction node at project action [action]: the title follows, the Action Value re-types to the action's value type, and wires the new type cannot carry are removed, all in one undo step. |
| `setNodeSetting` | `bool setNodeSetting(String nodeId, String key, Object? value)` | Sets node setting [key] (`class`, `element`, `component`, `cases`, `count`, `type`) on [nodeId]: the title and category follow the library, the pins re-resolve, and wires the new pins cannot carry are removed, all in one undo step. |
| `addSequencePin` | `bool addSequencePin(String nodeId)` | "Add pin" on a Sequence: one more `Then n` output. |
| `addCountedPin` | `bool addCountedPin(String nodeId)` | "Add pin" on a Make Array (and any `count` node: Multi Gate): one more item pin. |
| `syncPins` | `void syncPins(LuminaBlueprintNode node)` | Rewrites [node]'s stored pins from the library's resolution. |
| `dropIncompatibleWires` | `int dropIncompatibleWires(String nodeId)` | Removes wires into or out of [nodeId] whose ends no longer match. |
| `dropAllIncompatibleWires` | `int dropAllIncompatibleWires()` | Removes every wire in the graph whose ends no longer match (a variable retype touches every Get / Set of it and what they feed). |
| `replaceLegacyInput` | `LuminaBlueprintNode? replaceLegacyInput(String nodeId)` | Swaps a legacy OnInputAxis / OnInputAction node for an EnhancedInputAction at the same place, keeping its exec wires (lumina's deprecation diagnostic names the replacement). |
| `addCustomEvent` | `LuminaBlueprintNode? addCustomEvent(String name, Offset position)` | "Add Custom Event…": a named event with no parameters yet; the name is made unique among the graph's custom events. |
| `setCustomEventParameters` | `bool setCustomEventParameters(String nodeId, List<LuminaBlueprintVariable> parameters)` | Sets a custom event's parameters (name, type, default): its output pins follow, every `Call <Event>` re-resolves, and wires the new signature cannot carry are dropped — one undo step. |
| `renameCustomEvent` | `bool renameCustomEvent(String nodeId, String newName)` | Renames a custom event and every `Call <Event>` naming it. |
| `addComment` | `LuminaBlueprintNode? addComment({Offset? position, Rect? around, String title = 'Comment'})` | A comment box (`C`): around [around] when given (the selected nodes' bounds, padded), else a default box at [position]. |
| `setComment` | `bool setComment(String nodeId, {String? title, double? width, double? height, int? color})` | Edits a comment's title, size or colour (one undo step each). |
| `insertReroute` | `LuminaBlueprintNode? insertReroute(String wireId, Offset position)` | Splits [wireId] with a reroute dot at [position] (double-clicking a wire): the source now feeds the dot and the dot feeds the old target. |
| `sourceThroughReroutes` | `({String nodeId, String pinId})? sourceThroughReroutes(String nodeId, String pinId)` | The far source of a wire chain through reroutes ending at output [pinId] of [nodeId]: the pin that really carries the value. |
| `placeDispatcher` | `LuminaBlueprintNode? placeDispatcher(String name, {required String registryId, required Offset position})` | A Call / Bind / Unbind / Unbind All node for dispatcher [name] (My Blueprint drag). |
| `assignDispatcher` | `LuminaBlueprintNode? assignDispatcher(String name, {required Offset position})` | "Assign": a Bind node plus a new custom event named after the dispatcher, its delegate wired into the bind, in one undo step. |
| `placeLocalVariable` | `LuminaBlueprintNode? placeLocalVariable(String name, {required bool set, required Offset position})` | A local variable Get / Set of the function graph being edited. |
| `setTimelineTracks` | `bool setTimelineTracks(String nodeId, List<LuminaTimelineTrack> tracks)` | Set Timeline tracks / Switch cases: `tracks` on a Timeline. |
| `timelineTracks` | `static List<LuminaTimelineTrack> timelineTracks(LuminaBlueprintNode node)` | The Timeline node's tracks as stored. |
| `beginMove` | `void beginMove()` |  |
| `moveNodes` | `void moveNodes(Iterable<String> ids, Offset delta)` |  |
| `endMove` | `void endMove()` |  |

## `lib/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart`

### `class BlueprintInterfaceViewModel`

The Blueprint Interface sub-editor's state: lumina's [LuminaBlueprintInterfaceDocument] read from and written to the interface `.lmas` (`contents/interfaces/BPI_*.lmas`, payload `kind: interface`): a list of function signatures (name, inputs, outputs). Every edit is one undo step.

**Constructors:**

- `BlueprintInterfaceViewModel({required this.assetPath, String? name, List<LuminaBlueprintFunctionSignature>? functions})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetPath` | `final String assetPath` |  |
| `transactions` | `final TransactionManager transactions` |  |
| `name` | `String get name` |  |
| `functions` | `List<LuminaBlueprintFunctionSignature> get functions` |  |
| `selectedFunction` | `String? get selectedFunction` |  |
| `function` | `LuminaBlueprintFunctionSignature? function(String? name)` |  |
| `document` | `LuminaBlueprintInterfaceDocument get document` |  |
| `isDirty` | `bool get isDirty` |  |
| `projectDir` | `String? get projectDir` | The project directory the asset lives in (its `contents/` ancestor), or null. |
| `load` | `Future<void> load() async` |  |
| `save` | `Future<bool> save() async` |  |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `select` | `void select(String? name)` |  |
| `addFunction` | `String addFunction([String name = 'NewFunction'])` | Adds a function named [name] (made unique) with no parameters; returns its name. |
| `renameFunction` | `bool renameFunction(String oldName, String newName)` |  |
| `removeFunction` | `bool removeFunction(String name)` |  |
| `setInputs` | `bool setInputs(String name, List<LuminaBlueprintVariable> inputs)` |  |
| `setOutputs` | `bool setOutputs(String name, List<LuminaBlueprintVariable> outputs)` |  |
| `addParameter` | `String addParameter(String name, {required bool output, String parameter = 'NewParam', String type = 'Float'})` | Adds a parameter to [name]'s inputs or outputs; returns the parameter name. |

## `lib/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart`

### `class LevelBlueprintEditorViewModel`

The Level Blueprint editor's state: the Blueprint editor configured for a level. Its document is the level's [LuminaLevelBlueprintDocument], read from and saved into the level `.lmas` (`metadata.levelBlueprint`) through [LuminaLevelRepository]; its graphs resolve in lumina's level context, so `Get <Actor>` is typed by the placed actor's class and the palette lists the level's actors under **Level Actors**; the actors selected in the outliner are offered as `Create a Reference to <Actor>`. It has no components, 3D viewport, construction script or class defaults.

**Constructors:**

- `LevelBlueprintEditorViewModel({required this.projectDirectory, required this.levelPath, this.levelActorsSource, this.selectedActorNames, this.onSaved, LuminaLev...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDirectory` | `final String projectDirectory` | The project the level belongs to. |
| `levelPath` | `final String levelPath` | The project-relative level (`contents/levels/L_DefaultLevel.lmas`). |
| `levelActorsSource` | `final List<LuminaBlueprintLevelActorRef> Function()? levelActorsSource` | The level's placed actors as the outliner has them now; the level's saved actors when null. |
| `selectedActorNames` | `final List<String> Function()? selectedActorNames` | The names of the actors selected in the outliner. |
| `onSaved` | `final void Function(LuminaLevelBlueprintDocument saved)? onSaved` | Called after [save] wrote the Blueprint into the level. |
| `levelName` | `String get levelName` | The level's name (`L_DefaultLevel`). |
| `scriptClassName` | `String get scriptClassName` | The generated level script class (`_LDefaultLevelScript`). |
| `graphs` | `List<BlueprintGraphRef> get graphs` | A Level Blueprint has no construction script. |
| `levelDocument` | `LuminaLevelBlueprintDocument get levelDocument` | The document as lumina stores it in the level. |
| `levelActors` | `List<LuminaBlueprintLevelActorRef> get levelActors` | The level's placed actors a reference can name, in level order. |
| `levelActorsChanged` | `void levelActorsChanged()` | The outliner's actors changed (added, renamed, deleted, reclassed): references re-type and banners follow, once per real change. |
| `renameLevelActor` | `int renameLevelActor(String oldName, String newName)` | Renames every reference to placed actor [oldName] (`Get Door_01` → `FrontDoor`), keeping its wires: the outliner renamed the actor. Not an undo step — the reference follows the actor — and a document that was saved stays saved (the level's copy is renamed too). |
| `renameActorReferences` | `static int renameActorReferences(LuminaBlueprintDocument doc, String oldName, String newName)` | Renames the `Get <Actor>` nodes of [doc] naming [oldName] to [newName]; returns how many changed. |
| `pinnedPaletteEntries` | `List<BlueprintPaletteEntry> pinnedPaletteEntries()` | `Create a Reference to <Actor>` for each actor selected in the outliner, pinned at the top of the right-click palette. |
| `prepare` | `void prepare()` | Readies a freshly opened editor: the project's input actions, functions and assets, and the placed actors' classes, without replacing the document it opened with. |
| `save` | `Future<bool> save() async` | Writes the Blueprint into the level `.lmas` (`metadata.levelBlueprint`), keeping everything else of the level as it is on disk. |
| `compile` | `Future<bool> compile() async` | lumina's validator and level script generator on the graph as it is now (components, unknown or duplicate actor names, level nodes); Save writes it into the level, Save Level writes the script into `lib/levels/`. |
| `generatedDartCode` | `String get generatedDartCode` | The level script class Save Level writes into `lib/levels/<Level>.dart`. |

## `lib/ui/features/sub_editors/view_models/widget_blueprint_editor_view_model.dart`

### `class WidgetBlueprintEditorViewModel`

The Widget Blueprint graph editor's state: the Blueprint editor configured for a widget. Its document is the widget's graph, stored inside the widget `.lmas` by the UMG designer that owns this view model ([onSave] / [onCompile] run the designer's Save and Compile, which write the tree and the graph together); its graphs resolve in lumina's widget context, so the `Is Variable` elements are typed members (`Get Title` → `WidgetElement:text`) and bound element events (`On Clicked (StartButton)`) are keyed by element name. It has no components, 3D viewport, construction script or class defaults.

**Constructors:**

- `WidgetBlueprintEditorViewModel({required super.assetPath, required this.widgetClass, required this.variablesSource, this.projectDirectory, this.onSave, this.onC...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `widgetClass` | `final String widgetClass` | The widget class (`WBP_Clicker`). |
| `projectDirectory` | `final String? projectDirectory` | The project the widget belongs to. |
| `variablesSource` | `final List<LuminaBlueprintWidgetElement> Function() variablesSource` | The widget's `Is Variable` elements as the designer has them now. |
| `onSave` | `final Future<bool> Function()? onSave` | The designer's Save (tree and graph); false when it failed. |
| `onCompile` | `final Future<bool> Function()? onCompile` | The designer's Compile (graph check, then the widget file). |
| `generatedSource` | `final String Function()? generatedSource` | The widget's generated source (the code preview). |
| `scriptClassName` | `String get scriptClassName` | The script class the graph compiles into (`WbpClickerGraph`). |
| `graphs` | `List<BlueprintGraphRef> get graphs` | A widget graph has no construction script. |
| `widgetDocument` | `LuminaWidgetBlueprintDocument get widgetDocument` | The graph as lumina runs and compiles it: comment boxes and reroutes flattened, the designer's variables attached. |
| `variablesChanged` | `void variablesChanged()` | The designer's elements changed (added, renamed, deleted, Is Variable toggled): pins re-type and banners follow. |
| `boundEventNode` | `LuminaBlueprintNode? boundEventNode(String element, String event)` | The bound `On <Event> (<element>)` node of the event graph, or null. |
| `focusBoundEvent` | `LuminaBlueprintNode? focusBoundEvent(String element, String event)` | The green `+`: the bound `On <Event> (<element>)` node, placed below the event graph's other nodes when there is none (one undo step of the graph), shown and selected. Returns the node, or null when the element is not a variable or has no such event. |
| `removeBoundEvent` | `int removeBoundEvent(String element, String event)` | Removes every bound `On <Event> (<element>)` node (the designer removed the binding), as one undo step of the graph. Returns how many. |
| `renameElementReferences` | `int renameElementReferences(String oldName, String newName)` | Renames every `Get <element>` and bound event naming [oldName] (the designer renamed the element), keeping wires. Not an undo step of the graph: the reference follows the element, as Level Blueprint actor references follow the outliner; a saved graph stays saved. |
| `renameIn` | `static int renameIn(LuminaBlueprintDocument doc, String oldName, String newName)` | Renames the widget references of [doc] from [oldName] to [newName]. |
| `adoptRecordedEvents` | `int adoptRecordedEvents(List<({String element, String event})> recorded)` | One bound event node per event the designer recorded on an element (a widget designed before its graph existed): each lands in a column at the left of the event graph. Not an undo step: the graph opens with them. Returns how many. |
| `documentSaved` | `void documentSaved()` | The designer wrote the graph into the widget `.lmas`. |
| `save` | `Future<bool> save() async` | The designer's Save: the widget tree and this graph, in one `.lmas`. |
| `compile` | `Future<bool> compile() async` | The designer's Compile (F7 in the graph): this graph's check, then the widget file. |
| `compileGraph` | `BlueprintGenerationResult compileGraph()` | lumina's validator and widget-script generator on the graph as it is now: errors land on their nodes and in Compiler Results. The designer embeds a clean result in `lib/widgets/WBP_<Name>.dart`. |
| `generatedDartCode` | `String get generatedDartCode` | The widget's whole generated file (the code preview under the graph). |
| `prepare` | `void prepare()` | Readies a freshly opened graph: the project's input actions, functions and assets, without replacing the document. |

## `lib/ui/features/sub_editors/views/blueprint/compile_results.dart`

### `class BlueprintCompileBadge`

The toolbar's compile status badge with its states: Unknown (not compiled this session), Dirty (edited since), Error, Warnings, Up to date.

**Constructors:**

- `const BlueprintCompileBadge({super.key, required this.status})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `status` | `final BlueprintCompileStatus status` |  |
| `look` | `static (IconData, Color) look(BlueprintCompileStatus status)` |  |

### `class BlueprintCompilerResults`

Compiler Results: one row per diagnostic of the last compile (severity, node, message). Clicking a row that names a node selects and frames it.

**Constructors:**

- `const BlueprintCompilerResults({super.key, required this.status, required this.diagnostics, required this.nodeTitle, required this.onSelect,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `status` | `final BlueprintCompileStatus status` |  |
| `diagnostics` | `final List<LuminaBlueprintDiagnostic> diagnostics` |  |
| `nodeTitle` | `final String? Function(LuminaBlueprintDiagnostic diagnostic) nodeTitle` |  |
| `onSelect` | `final ValueChanged<LuminaBlueprintDiagnostic> onSelect` |  |

---

[Previous: Blueprint editor](blueprint.md) | [Up: Sub-editors](index.md) | [Next: Blueprint editor (continued, part 2)](blueprint-continued-2.md)
