[Türkçe](../../../tr/lumina/blueprint/model.md)

# Blueprint documents and assets

The data model of Blueprints: the class document with its components, variables, graphs, functions, macros and dispatchers; interface, enum, save-game and montage assets; the annotations that expose Dart functions as nodes; the validator's diagnostics; component mapping, per-instance collision overrides, graph layout, editor-only nodes, macro expansion and timelines. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/blueprint/blueprint_annotations.dart`](#libsrcblueprintblueprint_annotationsdart)
- [`lib/src/blueprint/blueprint_assets.dart`](#libsrcblueprintblueprint_assetsdart)
- [`lib/src/blueprint/blueprint_enums_interfaces.dart`](#libsrcblueprintblueprint_enums_interfacesdart)
- [`lib/src/blueprint/blueprint_model.dart`](#libsrcblueprintblueprint_modeldart)
- [`lib/src/blueprint/blueprint_validator.dart`](#libsrcblueprintblueprint_validatordart)
- [`lib/src/blueprint/collision_overrides.dart`](#libsrcblueprintcollision_overridesdart)
- [`lib/src/blueprint/component_mapping.dart`](#libsrcblueprintcomponent_mappingdart)
- [`lib/src/blueprint/editor_nodes.dart`](#libsrcblueprinteditor_nodesdart)
- [`lib/src/blueprint/graph_layout.dart`](#libsrcblueprintgraph_layoutdart)
- [`lib/src/blueprint/macro_expander.dart`](#libsrcblueprintmacro_expanderdart)
- [`lib/src/blueprint/timeline_curve.dart`](#libsrcblueprinttimeline_curvedart)

## `lib/src/blueprint/blueprint_annotations.dart`

### `class BlueprintCallable`

Marks a function as an impure Blueprint node, with exec pins: it runs when its exec input fires.

**Constructors:**

- `const BlueprintCallable({this.category, this.displayName, this.keywords = const [], this.tooltip})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `category` | `final String? category` | The palette category, `\|` separating levels (`Game\|Health`). Defaults to `Project`. |
| `displayName` | `final String? displayName` | The node title. Defaults to the function name split into words (`applyDamage` → "Apply Damage"). |
| `keywords` | `final List<String> keywords` | Extra words the palette search matches. |
| `tooltip` | `final String? tooltip` | The node tooltip. Defaults to the function's doc comment. |

### `class BlueprintPure`

Marks a function as a pure Blueprint node, without exec pins: it is evaluated when a node pulls one of its outputs. It must return a value.

**Constructors:**

- `const BlueprintPure({this.category, this.displayName, this.keywords = const [], this.tooltip})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `category` | `final String? category` | The palette category, `\|` separating levels. Defaults to `Project`. |
| `displayName` | `final String? displayName` | The node title. Defaults to the function name split into words. |
| `keywords` | `final List<String> keywords` | Extra words the palette search matches. |
| `tooltip` | `final String? tooltip` | The node tooltip. Defaults to the function's doc comment. |

## `lib/src/blueprint/blueprint_assets.dart`

### `class LuminaBlueprintSaveGameDocument`

A Blueprint save-game class asset: the `.lmas` payload `{"kind": "savegame", "name": …, "fields": […]}`. `Create Save Game Object` makes a [LuminaBlueprintSaveGame] of it; `Set / Get Save Field` type their pins from [fields].

**Constructors:**

- `const LuminaBlueprintSaveGameDocument({required this.name, this.fields = const []})`
- `factory LuminaBlueprintSaveGameDocument.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `static const String kind` |  |
| `name` | `final String name` |  |
| `fields` | `final List<LuminaBlueprintVariable> fields` |  |
| `field` | `LuminaBlueprintVariable? field(String? name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `toFormattedJson` | `String toFormattedJson()` |  |

### `abstract final class LuminaBlueprintSaveGameClasses`

The project's save-game classes; the editor and the generated `main()` fill it. Registering also registers the class with [LuminaSaveGame] so a loaded slot comes back as a [LuminaBlueprintSaveGame].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(LuminaBlueprintSaveGameDocument c)` |  |
| `registerAll` | `static void registerAll(Iterable<LuminaBlueprintSaveGameDocument> classes)` |  |
| `lookup` | `static LuminaBlueprintSaveGameDocument? lookup(String? name)` |  |
| `clear` | `static void clear()` |  |
| `all` | `static List<LuminaBlueprintSaveGameDocument> get all` |  |

### `class LuminaBlueprintSaveGame`

A save object of a Blueprint save-game class: the class name and its fields in [customSaveData] (JSON-plain, authoring-space values).

**Constructors:**

- `LuminaBlueprintSaveGame(this.className, {LuminaBlueprintSaveGameDocument? document, super.customSaveData, super.saveSlotName, super.userIndex, super.saveTimesta...`
- `factory LuminaBlueprintSaveGame.fromJson(String className, Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `className` | `final String className` |  |

### `class LuminaBlueprintMontageSection`

One section of a montage: where it starts and which section follows.

**Constructors:**

- `const LuminaBlueprintMontageSection({required this.name, required this.startTime, this.nextSection})`
- `factory LuminaBlueprintMontageSection.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `startTime` | `final double startTime` |  |
| `nextSection` | `final String? nextSection` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintMontageNotify`

A notify of a montage: a name fired at a time.

**Constructors:**

- `const LuminaBlueprintMontageNotify({required this.name, required this.time})`
- `factory LuminaBlueprintMontageNotify.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `time` | `final double time` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintMontageDocument`

A montage asset as `Play Anim Montage` plays it: the clip it plays on the skeletal mesh, its length (the clip's when the mesh knows it), sections and notifies. The `.lmas` payload carries `"kind": "montage"`.

**Constructors:**

- `const LuminaBlueprintMontageDocument({required this.name, required this.clip, this.length = 1.0, this.sections = const [], this.notifies = const [], this.blendI...`
- `factory LuminaBlueprintMontageDocument.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `static const String kind` |  |
| `name` | `final String name` |  |
| `clip` | `final String clip` |  |
| `length` | `final double length` |  |
| `sections` | `final List<LuminaBlueprintMontageSection> sections` |  |
| `notifies` | `final List<LuminaBlueprintMontageNotify> notifies` |  |
| `blendInTime` | `final double blendInTime` |  |
| `blendOutTime` | `final double blendOutTime` |  |
| `section` | `LuminaBlueprintMontageSection? section(String? name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `abstract final class LuminaBlueprintMontages`

The project's montage assets by name or path.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(LuminaBlueprintMontageDocument m, {String? path})` |  |
| `lookup` | `static LuminaBlueprintMontageDocument? lookup(String? nameOrPath)` |  |
| `clear` | `static void clear()` |  |

### `abstract final class LuminaBlueprintParticleTemplates`

The project's particle assets by path: what `Spawn Emitter at Location` builds a component from.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(String path, LuminaParticleEmitterConfig config)` |  |
| `lookup` | `static LuminaParticleEmitterConfig? lookup(String? path)` |  |
| `clear` | `static void clear()` |  |

### `class LuminaBlueprintMontagePlayback`

A montage being played by a Blueprint: the position on the montage's timeline, the section it is in, notifies fired, and the section jumps `Montage Jump To Section` / `Set Next Section` make.

**Constructors:**

- `LuminaBlueprintMontagePlayback(this.montage, {this.position = 0.0, this.playRate = 1.0})`: Sections follow one another in start order unless a section names its next one (or `Set Next Section` changes it).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `montage` | `final LuminaBlueprintMontageDocument montage` |  |
| `position` | `double position` |  |
| `playRate` | `double playRate` |  |
| `nextSections` | `final Map<String, String?> nextSections` |  |
| `finished` | `bool finished` |  |
| `currentSection` | `LuminaBlueprintMontageSection? get currentSection` | The section [position] lies in, if any. |
| `currentSectionEnd` | `double get currentSectionEnd` | The time the current section ends: the next section's start, else the montage length. |
| `jumpToSection` | `void jumpToSection(String name)` |  |
| `advance` | `List<String> advance(double dt)` | Advances [dt] seconds; returns the notifies passed, and sets [finished] when the last section ends without a next one. |

## `lib/src/blueprint/blueprint_enums_interfaces.dart`

### `abstract final class LuminaBlueprintEnums`

The project's enum assets a running game or the editor knows: `Switch on Enum`, `Int → Enum` and `Get Enum Value Count` read their values here. The editor's asset repository and the generated `main()` fill it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(LuminaBlueprintEnumDocument e)` |  |
| `registerAll` | `static void registerAll(Iterable<LuminaBlueprintEnumDocument> enums)` |  |
| `lookup` | `static LuminaBlueprintEnumDocument? lookup(String? name)` |  |
| `unregister` | `static void unregister(String name)` |  |
| `clear` | `static void clear()` |  |
| `isEmpty` | `static bool get isEmpty` |  |
| `all` | `static List<LuminaBlueprintEnumDocument> get all` | Every registered enum, in registration order. |
| `valuesOf` | `static List<String> valuesOf(String? name)` | The values of [name], or none for an unknown enum. |

### `abstract final class LuminaBlueprintInterfaces`

The project's interface assets: what `Interface Message` and `Event <Function>` type their pins from.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(LuminaBlueprintInterfaceDocument i)` |  |
| `registerAll` | `static void registerAll(Iterable<LuminaBlueprintInterfaceDocument> interfaces)` |  |
| `lookup` | `static LuminaBlueprintInterfaceDocument? lookup(String? name)` |  |
| `unregister` | `static void unregister(String name)` |  |
| `clear` | `static void clear()` |  |
| `isEmpty` | `static bool get isEmpty` |  |
| `all` | `static List<LuminaBlueprintInterfaceDocument> get all` |  |

### `class LuminaBlueprintCustomEvent`

A custom event as the type context sees it: its name and parameters, collected from the event graph's `custom_event` nodes so `Call Custom Event` and delegate pins can be typed.

**Constructors:**

- `const LuminaBlueprintCustomEvent({required this.name, this.parameters = const [], required this.nodeId})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `parameters` | `final List<LuminaBlueprintVariable> parameters` |  |
| `nodeId` | `final String nodeId` | The node that declares it. |

## `lib/src/blueprint/blueprint_model.dart`

### `enum LuminaPinType`

The type of a Blueprint pin.

Values are **authoring space**: a [vector] is centimetres, Z up, exactly what the Details panel shows; a [rotator] is [LuminaRotator]. Only the function library converts to the Y-up runtime.

**Values:**

- `exec`
- `boolean`
- `integer`
- `float`
- `string`
- `name`
- `vector`
- `vector2D`
- `rotator`
- `object`
- `transform`
- `structEnum`
- `color`: A linear colour `[r, g, b, a]` in 0–1.
- `array`: A list of one element type; the pin's `elementType` says which.
- `hitResult`: A trace hit as a JSON map (see Break Hit Result).
- `wildcard`: Any type: the element pins of the array nodes and loops until the node is given a `type` literal. Connects to every data pin.
- `enumeration`: A value of a project enum asset: the value's name as a string; the pin's `enumName` says which enum. Stored as `"type": "enum"`.
- `delegate`: A red delegate: a custom event bound to a timer or a dispatcher. Only a custom event's `delegate` output can feed one.
- `timerHandle`: A `LuminaTimerHandle` from Set Timer.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `jsonName` | `String get jsonName` | The name this type is stored under (`enum` for [enumeration]). |
| `parse` | `static LuminaPinType? parse(String? name)` | Reads a stored type name. The editor's older names map onto the new ones (`number` → [float], `vector3` → [vector], `objectRef` → [object]); an unknown name is null so the validator can report it. |
| `parseVariableType` | `static LuminaPinType? parseVariableType(String? typeName)` | The type of a Blueprint variable declared as [typeName] in the My Blueprint panel (`Float`, `Bool`, `Int`, `String`, `Vector`, …). |

### `abstract final class LuminaBlueprintObjectClass`

The class an object pin or variable carries, as a string: `Widget:<name>`, `WidgetElement:<UmgWidgetType name>`, `Component:<lumina component class>`, `Actor:<class>`, or `Object` (any). A kind alone (`Widget`, `Actor`, `Component`, `WidgetElement`) means any object of that kind.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `any` | `static const String any` |  |
| `widgetKind` | `static const String widgetKind` |  |
| `widgetElementKind` | `static const String widgetElementKind` |  |
| `componentKind` | `static const String componentKind` |  |
| `actorKind` | `static const String actorKind` |  |
| `saveGameKind` | `static const String saveGameKind` | A Blueprint save-game class: `SaveGame:SG_Player`. |
| `kinds` | `static const Set<String> kinds` |  |
| `isClassString` | `static bool isClassString(String s)` | Whether [s] is a class string this class understands. |
| `kind` | `static String kind(String cls)` | `Widget:WBP_HUD` → `Widget`; `Object` → `Object`. |
| `name` | `static String name(String cls)` | `Widget:WBP_HUD` → `WBP_HUD`; `Widget` → '' (any widget). |
| `widget` | `static String widget(String name)` |  |
| `widgetElement` | `static String widgetElement(String type)` |  |
| `component` | `static String component(String componentClass)` |  |
| `actor` | `static String actor(String actorClass)` |  |
| `saveGame` | `static String saveGame(String saveClass)` |  |
| `anyActor` | `static const String anyActor` | The base class every actor / component descends from. |
| `anyComponent` | `static const String anyComponent` |  |
| `engineParents` | `static const Map<String, String> engineParents` | The engine's own parent chains (the Blueprint class registry adds a project's Blueprint classes through [LuminaBlueprintTypeContext]). |
| `elementDisplayNames` | `static const Map<String, String> elementDisplayNames` | The display names of widget element types (UmgWidgetType names). |
| `elementParents` | `static const Map<String, String> elementParents` | Element types that take the nodes of a common type because their state means the same: a shadcn Progress is a Progress Bar to `Set Percent`, a Switch a Check Box to `Set Is Checked`, a Select a Combo Box to `Set Selected Option`, Tabs a Widget Switcher to `Set Active Widget Index`, the buttons Buttons to `Set Label`. |
| `displayName` | `static String displayName(String? cls)` | What the editor and diagnostics call [cls]: `Widget (WBP_HUD)`, `Text Block`, `Spring Arm`, `BP_Door`, `Object`. |
| `ancestors` | `static List<String> ancestors(String cls, {Map<String, String> parents = const {}})` | The parent chain of [cls] (excluding itself), through [parents] (a project's Blueprint classes, `BP_Door` → `LuminaActor`) and the engine's own hierarchy. Every actor ends at `LuminaActor`, every component at `LuminaActorComponent`. |
| `isAssignable` | `static bool isAssignable(String? from, String? to, {Map<String, String> parents = const {}})` | Whether a value of class [from] can be wired into a pin of class [to] (null on either side is `Object`): any → typed is refused (it needs a Cast), typed → any is allowed, a class is assignable to itself and to its ancestors, `Widget:X` → `Widget:X` only. |
| `assignError` | `static String? assignError(String? from, String? to, {Map<String, String> parents = const {}})` | Why [from] cannot be wired into [to], or null when it can. |

### `class LuminaRotator`

A rotation in the Details panel's convention: degrees about the authoring X, Y and Z axes. Authoring forward is +Y, so [x] is pitch, [y] roll and [z] yaw.

**Constructors:**

- `const LuminaRotator(this.x, this.y, this.z)`
- `const LuminaRotator.zero()`
- `factory LuminaRotator.fromList(List<num>? v)`: Reads `[x, y, z]`; missing entries are 0.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `x` | `final double x` |  |
| `y` | `final double y` |  |
| `z` | `final double z` |  |
| `pitch` | `double get pitch` |  |
| `roll` | `double get roll` |  |
| `yaw` | `double get yaw` |  |
| `toList` | `List<double> toList()` |  |

### `class LuminaBlueprintComponent`

One component of a Blueprint's component tree.

**Constructors:**

- `LuminaBlueprintComponent({required this.id, required this.name, required this.type, this.parentId, Map<String, dynamic>? properties, this.isSceneComponent = tru...`
- `factory LuminaBlueprintComponent.fromJson(Map<String, dynamic> map)`: Reads the editor's shape. Keys other than the known top-level fields are folded into [properties], as the editor does.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `String name` |  |
| `type` | `final String type` |  |
| `parentId` | `String? parentId` |  |
| `properties` | `final Map<String, dynamic> properties` |  |
| `isSceneComponent` | `final bool isSceneComponent` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintVariable`

A variable declared in the My Blueprint panel.

**Constructors:**

- `const LuminaBlueprintVariable({required this.name, required this.typeName, this.defaultValue})`
- `factory LuminaBlueprintVariable.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `typeName` | `final String typeName` | The type exactly as stored (`Float`, `Bool`, …), kept so a document round-trips unchanged. |
| `defaultValue` | `final dynamic defaultValue` |  |
| `type` | `LuminaPinType? get type` | Null when [typeName] is not a known type (a validator error). |
| `objectClass` | `String? get objectClass` | The class of an object variable (`Widget:WBP_HUD`, `Actor:BP_Door`); null for `Object` (any) and for non-object variables. |
| `elementType` | `LuminaPinType? get elementType` | The element type of an `Array:<type>` variable. |
| `enumName` | `String? get enumName` | The enum of an `Enum:<name>` variable, else null. |
| `toPin` | `LuminaBlueprintPin toPin({required bool isOutput})` | This variable as the pin it declares (a function parameter, a dispatcher parameter, a custom event parameter): id and name are the variable's name. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintPin`

A pin as stored on a placed node.

**Constructors:**

- `const LuminaBlueprintPin({required this.id, required this.name, required this.type, this.isOutput = false, this.defaultValue, this.objectClass, this.elementType...`
- `factory LuminaBlueprintPin.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `type` | `final LuminaPinType? type` | Null when the stored type name is unknown. |
| `isOutput` | `final bool isOutput` |  |
| `defaultValue` | `final dynamic defaultValue` |  |
| `objectClass` | `final String? objectClass` | The class of an object pin; null is any object. Stored as `"class"`. |
| `elementType` | `final LuminaPinType? elementType` | The element type of an array pin; stored as `"of"`. |
| `enumName` | `final String? enumName` | The enum of an [LuminaPinType.enumeration] pin; stored as `"enum"`. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintNode`

A node placed in a graph: which library node it is ([registryId]), its pins, its literal pin values and where the editor draws it.

**Constructors:**

- `LuminaBlueprintNode({required this.id, required this.registryId, required this.title, this.category = 'General', this.x = 0.0, this.y = 0.0, this.headerColor, L...`
- `factory LuminaBlueprintNode.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `registryId` | `final String registryId` |  |
| `title` | `String title` |  |
| `category` | `String category` |  |
| `x` | `double x` |  |
| `y` | `double y` |  |
| `headerColor` | `final int? headerColor` | ARGB header colour the editor stored; kept for round-tripping only. |
| `inputs` | `final List<LuminaBlueprintPin> inputs` |  |
| `outputs` | `final List<LuminaBlueprintPin> outputs` |  |
| `literals` | `final Map<String, dynamic> literals` | Pin id → literal value for pins without a wire, plus node settings such as an input action's `action` or a variable node's `variable`. |
| `pin` | `LuminaBlueprintPin? pin(String pinId)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintWire`

A wire from an output pin to an input pin.

**Constructors:**

- `const LuminaBlueprintWire({required this.id, required this.fromNodeId, required this.fromPinId, required this.toNodeId, required this.toPinId,})`
- `factory LuminaBlueprintWire.fromJson(Map<String, dynamic> json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `fromNodeId` | `final String fromNodeId` |  |
| `fromPinId` | `final String fromPinId` |  |
| `toNodeId` | `final String toNodeId` |  |
| `toPinId` | `final String toPinId` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintGraph`

One node graph (the event graph today).

**Constructors:**

- `LuminaBlueprintGraph({List<LuminaBlueprintNode>? nodes, List<LuminaBlueprintWire>? wires})`
- `factory LuminaBlueprintGraph.fromJson(Map<String, dynamic>? json)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `nodes` | `final List<LuminaBlueprintNode> nodes` |  |
| `wires` | `final List<LuminaBlueprintWire> wires` |  |
| `node` | `LuminaBlueprintNode? node(String id)` |  |
| `wiresFrom` | `Iterable<LuminaBlueprintWire> wiresFrom(String nodeId, String pinId)` | Wires leaving [nodeId]'s output [pinId]. |
| `wireInto` | `LuminaBlueprintWire? wireInto(String nodeId, String pinId)` | The wire into [nodeId]'s input [pinId], if any. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintFunctionGraph`

A user function of a Blueprint: its signature, its own graph (with a `function_entry` and, when it has outputs, a `function_result` node), local variables, and whether it is pure (no exec pins; callable from data chains).

**Constructors:**

- `LuminaBlueprintFunctionGraph({required this.name, List<LuminaBlueprintVariable>? inputs, List<LuminaBlueprintVariable>? outputs, List<LuminaBlueprintVariable>?...`
- `factory LuminaBlueprintFunctionGraph.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `String name` |  |
| `inputs` | `final List<LuminaBlueprintVariable> inputs` |  |
| `outputs` | `final List<LuminaBlueprintVariable> outputs` |  |
| `localVariables` | `final List<LuminaBlueprintVariable> localVariables` |  |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `pure` | `bool pure` |  |
| `category` | `String category` |  |
| `localVariable` | `LuminaBlueprintVariable? localVariable(String name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintMacroGraph`

A macro of a Blueprint: exec and data inputs / outputs (`typeName: 'Exec'` for exec pins) and a body graph with a `macro_input` and a `macro_output` node. A `call_macro` node is expanded into its caller by [LuminaBlueprintMacroExpander]; the document keeps it folded.

**Constructors:**

- `LuminaBlueprintMacroGraph({required this.name, List<LuminaBlueprintVariable>? inputs, List<LuminaBlueprintVariable>? outputs, LuminaBlueprintGraph? graph,})`
- `factory LuminaBlueprintMacroGraph.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `String name` |  |
| `inputs` | `final List<LuminaBlueprintVariable> inputs` |  |
| `outputs` | `final List<LuminaBlueprintVariable> outputs` |  |
| `graph` | `final LuminaBlueprintGraph graph` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintDispatcher`

An event dispatcher of a Blueprint: a name and the parameters every bound event receives.

**Constructors:**

- `LuminaBlueprintDispatcher({required this.name, List<LuminaBlueprintVariable>? parameters})`
- `factory LuminaBlueprintDispatcher.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `String name` |  |
| `parameters` | `final List<LuminaBlueprintVariable> parameters` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintFunctionSignature`

One function of a Blueprint interface. A function with outputs is implemented as a Blueprint function of that name; one without as an `event_interface_function` event.

**Constructors:**

- `const LuminaBlueprintFunctionSignature({required this.name, this.inputs = const [], this.outputs = const []})`
- `factory LuminaBlueprintFunctionSignature.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `inputs` | `final List<LuminaBlueprintVariable> inputs` |  |
| `outputs` | `final List<LuminaBlueprintVariable> outputs` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintInterfaceDocument`

A Blueprint interface asset: the `.lmas` payload `{"kind": "interface", "name": …, "functions": […]}`.

**Constructors:**

- `const LuminaBlueprintInterfaceDocument({required this.name, this.functions = const []})`
- `factory LuminaBlueprintInterfaceDocument.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `static const String kind` |  |
| `name` | `final String name` |  |
| `functions` | `final List<LuminaBlueprintFunctionSignature> functions` |  |
| `function` | `LuminaBlueprintFunctionSignature? function(String? name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `toFormattedJson` | `String toFormattedJson()` |  |

### `class LuminaBlueprintEnumDocument`

A Blueprint enum asset: the `.lmas` payload `{"kind": "enum", "name": …, "values": […]}`. Values are their names at run time.

**Constructors:**

- `const LuminaBlueprintEnumDocument({required this.name, this.values = const []})`
- `factory LuminaBlueprintEnumDocument.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `static const String kind` |  |
| `name` | `final String name` |  |
| `values` | `final List<String> values` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `toFormattedJson` | `String toFormattedJson()` |  |

### `class LuminaBlueprintDocument`

A Blueprint class document: what an ACTOR `.lmas` carries in its payload.

**Constructors:**

- `LuminaBlueprintDocument({this.parentClass = 'LuminaActor', List<LuminaBlueprintComponent>? components, LuminaBlueprintGraph? eventGraph, List<LuminaBlueprintVar...`
- `factory LuminaBlueprintDocument.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `parentClass` | `String parentClass` |  |
| `components` | `final List<LuminaBlueprintComponent> components` |  |
| `eventGraph` | `final LuminaBlueprintGraph eventGraph` |  |
| `variables` | `final List<LuminaBlueprintVariable> variables` |  |
| `classDefaults` | `final Map<String, dynamic> classDefaults` |  |
| `functions` | `final List<LuminaBlueprintFunctionGraph> functions` | User functions, macros and event dispatchers. |
| `macros` | `final List<LuminaBlueprintMacroGraph> macros` |  |
| `dispatchers` | `final List<LuminaBlueprintDispatcher> dispatchers` |  |
| `interfaces` | `final List<String> interfaces` | The names of the interface assets this Blueprint implements. |
| `functions` | `, functions` |  |
| `variable` | `LuminaBlueprintVariable? variable(String name)` |  |
| `function` | `LuminaBlueprintFunctionGraph? function(String? name)` |  |
| `macro` | `LuminaBlueprintMacroGraph? macro(String? name)` |  |
| `dispatcher` | `LuminaBlueprintDispatcher? dispatcher(String? name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `toFormattedJson` | `String toFormattedJson()` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaBlueprintObjectClassOf` | `String? luminaBlueprintObjectClassOf(String? typeName)` | The object class a stored variable type name carries: `Widget:WBP_HUD` stays as is, the legacy `Actor` is `Actor:LuminaActor`, `Object` / other types are null. An `Array:<object class>` gives its element class. |
| `luminaBlueprintEnumNameOf` | `String? luminaBlueprintEnumNameOf(String? typeName)` | The enum name a stored variable type carries: `Enum:E_DoorState` → `E_DoorState`; `Array:Enum:X` → `X`; anything else null. |
| `luminaBlueprintDocumentKind` | `String luminaBlueprintDocumentKind(Map<String, dynamic> payload)` | The kind of Blueprint document a `.lmas` payload holds: `class` (an actor Blueprint), `enum` or `interface`. |
| `luminaBlueprintLiteral` | `Object? luminaBlueprintLiteral(LuminaPinType type, Object? stored)` | Converts a stored literal to the Dart value a [type] pin carries: a `Vector3` for [LuminaPinType.vector], a `Vector2` for [LuminaPinType.vector2D], a [LuminaRotator], a `double`, …; null stays null. |
| `luminaBlueprintZero` | `Object? luminaBlueprintZero(LuminaPinType type)` | The zero value of a pin type: what an unset input reads as, in the VM and in generated code alike. |

## `lib/src/blueprint/blueprint_validator.dart`

### `enum LuminaBlueprintSeverity`

**Values:**

- `error`
- `warning`

### `class LuminaBlueprintDiagnostic`

One compiler-results row: what is wrong, and the node / pin it is on.

**Constructors:**

- `const LuminaBlueprintDiagnostic(this.severity, this.message, {this.nodeId, this.pinId})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `severity` | `final LuminaBlueprintSeverity severity` |  |
| `message` | `final String message` |  |
| `nodeId` | `final String? nodeId` |  |
| `pinId` | `final String? pinId` |  |
| `isError` | `bool get isError` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `validateBlueprint` | `List<LuminaBlueprintDiagnostic> validateBlueprint(LuminaBlueprintDocument doc, {List<LuminaInputAction> inputA...` | Checks a Blueprint against the node library: unknown nodes, wire types and multiplicity, pure cycles, unset required inputs, missing input actions and variables, duplicate events. An empty list means it can run in the VM and be generated to Dart. |

## `lib/src/blueprint/collision_overrides.dart`

### `abstract final class LuminaBlueprintCollisionOverrides`

A placed Blueprint actor's per-instance collision: the level Details' overrides of its class's collision components, stored in the level `.lmas` and applied by Play-In-Editor and the generated level alike.

Each override is a component node in the level actor's `components` whose `properties` name the Blueprint component ([componentIdKey]) and carry the collision JSON of `LuminaCollisionComponent.toCollisionJson`; keys an override lacks keep the class's values.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `componentIdKey` | `static const String componentIdKey` | The override node property naming the Blueprint component it overrides. |
| `collisionKeys` | `static const List<String> collisionKeys` | The collision JSON keys an override may carry. |
| `physicsKey` | `static const String physicsKey` | The key of an override's Physics section: the component `physics` JSON of `LuminaPrimitivePhysics.applyPhysicsJson`. |
| `fromActorMap` | `static Map<String, Map<String, dynamic>> fromActorMap(Map<String, dynamic> actor)` | The overrides of level actor map [actor] (`metadata.actors[]`), by Blueprint component id, reduced to [collisionKeys]; nodes without a component id or without any collision key are skipped. |
| `apply` | `static int apply(LuminaActor actor, Map<String, Map<String, dynamic>> overrides)` | Applies [overrides] to [actor]'s built Blueprint collision components (`applyCollisionJson`) and returns how many were applied. Ids that name no collision component, and actors that are not Blueprint instances, are ignored. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaWithCollisionOverrides` | `T luminaWithCollisionOverrides<T extends LuminaActor>(T actor, Map<String, Map<String, dynamic>> overrides)` | [actor] with its per-instance collision [overrides] applied ([LuminaBlueprintCollisionOverrides.apply]): the generated level wraps a placed Blueprint's factory call in it. |

## `lib/src/blueprint/component_mapping.dart`

### `typedef LuminaBlueprintAssetResolver`

Turns a stored mesh asset reference (a project `.lmas` path, a `.glb`) into what a mesh component loads; null to skip the mesh.

### `abstract final class LuminaBlueprintComponents`

Builds a Blueprint's component tree on an actor (its construction script). The VM and generated code both call it, so a Blueprint has the same components either way. Transforms are converted from authoring space with [LuminaAxes]. Light components read `intensity` (lumens), `colorHex` (the sRGB `#RRGGBB` the colour picker stores) or `color` (linear RGB), `attenuationRadius` (cm), `castShadows` and `visible`.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `editorOnly` | `static const Set<String> editorOnly` | Component types that exist only in the editor (drawn there, nothing at run time), or that the VM replaces (input is bound from the graph). |
| `construct` | `static Map<String, LuminaActorComponent> construct(LuminaActor actor, List<LuminaBlueprintComponent> component...` | Constructs [components] on [actor] and returns them by component id. A Character's capsule and movement are its own fields, configured rather than created twice. Unknown types are reported in [diagnostics] and skipped. |
| `meshPhysicsResolver` | `static LuminaMeshPhysics? Function(String storedMeshAsset)? meshPhysicsResolver` | Resolves a static mesh asset's `metadata.physics` (`{massKg, centerOfMassOffset}`) from its stored `.lmas` path: the editor / PIE sets it to lumina's mesh physics service; a generated game has none and uses the values the editor baked into each component's `physics.meshPhysics`. |
| `classNameOf` | `static String classNameOf(LuminaActorComponent c)` | The registry class name of a live component (the `Component:<class>` type): the document type it was built from, never `runtimeType` (minified on the web). A skeletal mesh reports `LuminaSkeletalMeshComponent`, its document type. |
| `isA` | `static bool isA(LuminaActorComponent c, String componentClass)` | Whether [c] is a [componentClass] or a subclass of it, by the engine's class chain. |
| `hullResolver` | `static List<Vector3>? Function(String hullAsset)? hullResolver` | Resolves a convex component's `hullAsset` (a mesh asset's `.lmas` path) to its hull points in the component's local frame (world units): the editor / PIE sets it to the mesh collision service; generated games carry the points in the component's `hullPoints` instead. A hull no resolver and no points provide degrades to the component's box. |
| `nextDynamicId` | `static String nextDynamicId()` | A fresh id for a component added at run time. |
| `addDynamic` | `static LuminaActorComponent? addDynamic(LuminaActor actor, String type, {String? name, Map<String, dynamic>? p...` | Adds a new component of document type [type] to [actor] at run time (Add Component): built by the same table as the construction script, attached to the actor root, registered. Null when the type has no runtime counterpart. |

### `extension on LuminaSceneComponent`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaBlueprintMeshPath` | `String luminaBlueprintMeshPath(String stored)` | What a mesh component loads for a stored mesh reference when no resolver maps it: a mesh asset's `.lmas` is loaded through the `.entity.glb` the import writes next to it; anything else as stored. |

## `lib/src/blueprint/editor_nodes.dart`

### `abstract final class LuminaBlueprintEditorNodes`

Graph nodes that only the editor draws: comment boxes and reroute dots. The node library has neither. They are stored in the graph like any other node, so they save into the `.lmas`, and [forEngine] strips them before a document reaches the validator, the VM or the Dart generator. A comment is dropped. A reroute is bypassed by wiring its source straight into what it fed.

They live in the engine package because engine code emits them too: generated template graphs carry comment boxes, and the VM ([LuminaBlueprintClass.fromDocument]) and the generator strip them from any document they receive.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `comment` | `static const String comment` | A comment box: literals `title`, `width`, `height`, `color` (ARGB int). Its position is the box's top-left; it has no pins. |
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
| `flattenGraph` | `static LuminaBlueprintGraph flattenGraph(LuminaBlueprintGraph graph)` | [graph] without editor-only nodes: comments dropped, every reroute chain replaced by direct wires from its source to each final target. The wire into the last reroute of a chain keeps the id of the first bypassed wire when there is exactly one target, so the debugger's exec glow still finds it. Returns [graph] itself when it has none. |
| `hasEditorNodes` | `static bool hasEditorNodes(LuminaBlueprintDocument document)` | Whether any graph of [document] holds an editor-only node. |
| `forEngine` | `static LuminaBlueprintDocument forEngine(LuminaBlueprintDocument document)` | A deep copy of [document] with every graph flattened: what the validator, the VM (Play) and the Dart generator receive. [document] itself when it has no editor-only node. |

## `lib/src/blueprint/graph_layout.dart`

### `class LuminaBlueprintGraphSection`

One titled chain of a generated graph: an event and the nodes it runs, in reading order.

**Constructors:**

- `const LuminaBlueprintGraphSection(this.title, this.nodes)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `title` | `final String title` | The comment box title (`Move`, `Look`, `Jump`). |
| `nodes` | `final List<LuminaBlueprintNode> nodes` | The chain's nodes, left to right. |

### `abstract final class LuminaBlueprintGraphLayout`

Lays out graphs that engine code generates (the templates' Blueprints) for readability: one titled comment box per event chain, boxes stacked top to bottom at one left x with an even gap, each chain's nodes left to right with an even gap between them. Pure (data-only) nodes sit [pureDrop] below the exec row. Each box is sized to its nodes plus [padding].

Node sizes come from [estimateSize], which follows the Blueprint editor's node layout (lumina_ui `BlueprintNodeLayout`): header, pin rows, the input settings row, label widths and the inline literal editors of unconnected inputs.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `nodeGap` | `static const double nodeGap` | Horizontal gap between two neighbouring nodes' edges. |
| `sectionGap` | `static const double sectionGap` | Vertical gap between two boxes. |
| `padding` | `static const double padding` | Inner padding of a box: left, right and below the tallest node. |
| `titleBand` | `static const double titleBand` | From a box's top to its exec row: the comment's title bar plus a gap. |
| `pureDrop` | `static const double pureDrop` | How far below the exec row pure nodes sit. |
| `stack` | `static List<LuminaBlueprintNode> stack(List<LuminaBlueprintGraphSection> sections, {List<LuminaBlueprintWire>...` | Places [sections] and returns the graph's nodes: the comment boxes first (they draw behind), then every section's nodes, in order. The first box's top-left is ([left], [top]). [wires] tell which inputs are connected (a connected input shows no inline literal editor, so its node is narrower). |
| `isPure` | `static bool isPure(LuminaBlueprintNode node)` | A node without exec pins: evaluated where its value is read. |
| `estimateSize` | `static ({double width, double height}) estimateSize(LuminaBlueprintNode node, {Set<String> connectedInputs = c...` | The size the Blueprint editor draws [node] at, with [connectedInputs] wired (they hide their inline literal editors). |

## `lib/src/blueprint/macro_expander.dart`

### `abstract final class LuminaBlueprintMacroExpander`

Expands every `call_macro` node of a graph into the macro's body (inlining each macro instance): body nodes are copied under `<callId>__<bodyId>` so a trace maps back to the instance, wires into the call's inputs continue into what the body's `Inputs` node fed, wires out of the call's outputs start from what fed the body's `Outputs` node, and a literal on the call node becomes the literal of every body pin that read that input. Nested macros expand too (depth 16).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `maxDepth` | `static const int maxDepth` |  |
| `expand` | `static LuminaBlueprintGraph expand(LuminaBlueprintGraph graph, List<LuminaBlueprintMacroGraph> macros, {int de...` | [graph] with every macro call inlined; [graph] itself is untouched (the document stays folded). A graph without macro calls is returned as is. |

## `lib/src/blueprint/timeline_curve.dart`

### `enum LuminaTimelineInterp`

How a timeline key reaches the next one.

**Values:**

- `linear`
- `cubic`
- `constant`

### `class LuminaTimelineKey`

One key of a timeline track: a time and a float, vector `[x, y, z]` or colour `[r, g, b, a]` value.

**Constructors:**

- `const LuminaTimelineKey(this.time, this.value, [this.interp = LuminaTimelineInterp.linear])`
- `factory LuminaTimelineKey.fromJson(Map<String, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `time` | `final double time` |  |
| `value` | `final List<double> value` |  |
| `interp` | `final LuminaTimelineInterp interp` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaTimelineTrack`

A named curve of a timeline: `float`, `vector` or `color` keys evaluated with linear, cubic (Catmull-Rom) or constant interpolation; held at the first / last key outside the range.

**Constructors:**

- `LuminaTimelineTrack({required this.name, this.type = 'float', List<LuminaTimelineKey> keys = const []})`
- `factory LuminaTimelineTrack.fromJson(Map<dynamic, dynamic> map)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `type` | `final String type` |  |
| `keys` | `final List<LuminaTimelineKey> keys` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `evaluate` | `Object evaluate(double t)` | The value at [t] as the pin carries it: a `double`, a `Vector3` or a colour `[r, g, b, a]`. |
| `evaluateComponents` | `List<double> evaluateComponents(double t)` | The raw components at [t]. |

### `class LuminaTimeline`

A running Timeline node: a position between 0 and [length] advanced forward or backward while playing, the tracks it evaluates, and the Update / Finished callbacks the owner re-enters its graph through. Shared by the VM and generated code.

**Constructors:**

- `LuminaTimeline({required this.name, this.length = 1.0, this.loop = false, List<LuminaTimelineTrack>? tracks, bool autoPlay = false})`
- `factory LuminaTimeline.fromLiterals(Map<String, dynamic> literals, {String? name})`: Builds one from a Timeline node's literals (`name`, `length`, `loop`, `auto_play`, `tracks`).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `length` | `double length` |  |
| `loop` | `bool loop` |  |
| `tracks` | `final List<LuminaTimelineTrack> tracks` |  |
| `onUpdate` | `void Function()? onUpdate` | Runs after every advance while playing, with the track values. |
| `onFinished` | `void Function()? onFinished` | Runs when the position reaches the end (or the start, in reverse). |
| `position` | `double get position` |  |
| `isPlaying` | `bool get isPlaying` |  |
| `isReversing` | `bool get isReversing` |  |
| `direction` | `String get direction` | `Forward` or `Backward`: the Direction output. |
| `play` | `void play()` |  |
| `playFromStart` | `void playFromStart()` |  |
| `stop` | `void stop()` |  |
| `reverse` | `void reverse()` |  |
| `reverseFromStart` | `void reverseFromStart()` |  |
| `setNewTime` | `void setNewTime(double t)` |  |
| `values` | `Map<String, Object?> values()` | The track values at the current position, by track name. |
| `advance` | `void advance(double dt)` | Advances [dt] seconds when playing; runs [onUpdate] once and [onFinished] when the end is reached (a looping timeline wraps and keeps playing). |

---

[Previous: Blueprints](index.md) | [Up: Blueprints](index.md) | [Next: Blueprint runtime, VM and node library](runtime.md)
