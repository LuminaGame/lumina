[English](../../../en/lumina/blueprint/runtime.md)

# Blueprint runtime'ı, VM ve node kütüphanesi

Blueprint'lerin nasıl çalıştığı: paletin, VM'in ve kod üretecinin paylaştığı node kütüphanesi, VM ile üretilen kodun paylaştığı runtime mixin'i, yorumlayıcı ile Blueprint actor, pawn, character, level script ve user widget sınıfları, delegate'ler ve dispatcher'lar, proje node'ları için fonksiyon registry'si ve Level ile Widget Blueprint belgeleri. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/blueprint/blueprint_function_registry.dart`](#libsrcblueprintblueprint_function_registrydart)
- [`lib/src/blueprint/blueprint_runtime.dart`](#libsrcblueprintblueprint_runtimedart)
- [`lib/src/blueprint/level_blueprint.dart`](#libsrcblueprintlevel_blueprintdart)
- [`lib/src/blueprint/level_blueprint_storage.dart`](#libsrcblueprintlevel_blueprint_storagedart)
- [`lib/src/blueprint/node_library.dart`](#libsrcblueprintnode_librarydart)
- [`lib/src/blueprint/node_library/type_context.dart`](#libsrcblueprintnode_librarytype_contextdart)
- [`lib/src/blueprint/vm/blueprint_vm.dart`](#libsrcblueprintvmblueprint_vmdart)
- [`lib/src/blueprint/vm/blueprint_vm/instance.dart`](#libsrcblueprintvmblueprint_vminstancedart)
- [`lib/src/blueprint/widget_blueprint.dart`](#libsrcblueprintwidget_blueprintdart)
- [`lib/src/blueprint/widget_classes.dart`](#libsrcblueprintwidget_classesdart)

## `lib/src/blueprint/blueprint_function_registry.dart`

### `class LuminaBlueprintRegisteredFunction`

A node added to the library at run time: its spec, how generated code calls it, and its VM callable — null for a function that is only declared (project code the editor process cannot run).

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintRegisteredFunction(this.spec, this.call, this.function)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `spec` | `final LuminaBlueprintNodeSpec spec` |  |
| `call` | `final LuminaBlueprintCallShape? call` |  |
| `function` | `final LuminaBlueprintFunction? function` |  |
| `callable` | `bool get callable` | Whether the VM of this process can run it. |

### `abstract final class LuminaBlueprintFunctionRegistry`

Nodes beyond the built-in library: Dart functions registered as Blueprint-callable.

A project's generated `registerProjectBlueprintFunctions()` (`lib/blueprint/blueprint_functions.g.dart`) [register]s each annotated function with a closure the VM calls; editor plugins can register theirs the same way. The editor, which cannot run project code, [declare]s the project's functions from `project.blueprint_functions.json` so the palette, the validator and the code generator know them, and the VM reports them as requiring Play Standalone.

[LuminaBlueprintNodeLibrary.spec] / `all` and [LuminaBlueprintFunctionLibrary.functions] consult the registry after the built-ins.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `unavailableMessage` | `static const String unavailableMessage` | What the VM and the validator say about a declared-only function. |
| `idPrefix` | `static const String idPrefix` | The prefix of a node id generated for an annotated Dart function: `fn:<library uri>#<function name>`. |
| `idFor` | `static String idFor(String libraryUri, String function)` | The node id of the annotated function [function] (`name` or `Class.name`) in the library [libraryUri]. |
| `register` | `static void register(LuminaBlueprintNodeSpec spec, LuminaBlueprintFunction function, {LuminaBlueprintCallShape...` | Adds node [spec], run by [function] in the VM. [call] tells generated Blueprint code how to call it directly. Throws [StateError] when the id is a built-in node or already registered or declared. |
| `declare` | `static void declare(LuminaBlueprintNodeSpec spec, {LuminaBlueprintCallShape? call})` | Makes node [spec] known without a callable: the palette lists it, the validator accepts it (with a warning), the code generator calls it through [call], and the VM skips it with a "requires Play Standalone" log. A new declaration replaces an earlier one; a built-in id or a registered function throws [StateError]. |
| `entry` | `static LuminaBlueprintRegisteredFunction? entry(String id)` |  |
| `spec` | `static LuminaBlueprintNodeSpec? spec(String id)` |  |
| `function` | `static LuminaBlueprintFunction? function(String id)` |  |
| `callShape` | `static LuminaBlueprintCallShape? callShape(String id)` |  |
| `isDeclaredOnly` | `static bool isDeclaredOnly(String id)` | Whether [id] is declared but not callable in this process. |
| `isEmpty` | `static bool get isEmpty` |  |
| `specs` | `static List<LuminaBlueprintNodeSpec> get specs` | Every registered and declared node, in registration order. |
| `callableIds` | `static Iterable<String> get callableIds` | Ids of the nodes the VM can call, in registration order. |
| `unregister` | `static void unregister(String id)` |  |
| `clearDeclared` | `static void clearDeclared()` | Removes every declared-only function (before re-reading a project's manifest); registered ones stay. |
| `clear` | `static void clear()` | Removes everything. |

## `lib/src/blueprint/blueprint_runtime.dart`

### `class LuminaBlueprintTraceEvent`

One step of a Blueprint run, for tests, the editor's live highlighting and VM ↔ generated-code parity.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintTraceEvent({required this.eventNodeId, required this.nodeId, required this.registryId, this.values = const {}, this.printed,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `eventNodeId` | `final String eventNodeId` | The event node the run started from. |
| `nodeId` | `final String nodeId` |  |
| `registryId` | `final String registryId` |  |
| `values` | `final Map<String, Object?> values` | Input and output pin values of the node, by pin id. |
| `printed` | `final String? printed` | Print String's text, when the node printed. |

### `class LuminaBlueprintInputBinding`

An input binding a Blueprint makes: when [action] reaches [state], [handler] runs the graph from that trigger pin.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintInputBinding(this.action, this.state, this.handler)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `action` | `final LuminaInputAction action` |  |
| `state` | `final TriggerState state` |  |
| `handler` | `final void Function(LuminaInputActionValue value) handler` |  |

### `abstract interface class LuminaBlueprintCallable`

What a Blueprint answers by name: its custom events, its functions and the interface events it implements. The VM runs the graph; generated classes switch to their methods. Unknown names return an empty map.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `callBlueprint` | `Map<String, Object?> callBlueprint(String name, Map<String, Object?> args)` |  |

### `class LuminaBlueprintDelegate`

A bound custom event: the red delegate pin's value, what a timer or a dispatcher calls.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintDelegate(this.owner, this.eventName)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `owner` | `final LuminaBlueprintCallable owner` |  |
| `eventName` | `final String eventName` |  |
| `call` | `Map<String, Object?> call([Map<String, Object?> args = const {}])` |  |

### `class LuminaMulticastDelegate`

An event dispatcher's bound delegates: `Bind Event` adds, `Unbind` removes, `Call` broadcasts the parameters to each in binding order.

**Yapıcı Metotlar (Constructors):**

- `LuminaMulticastDelegate(this.name)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `bound` | `List<LuminaBlueprintDelegate> get bound` |  |
| `isBound` | `bool get isBound` |  |
| `add` | `void add(LuminaBlueprintDelegate delegate)` |  |
| `remove` | `void remove(LuminaBlueprintDelegate delegate)` |  |
| `removeAll` | `void removeAll([Object? owner])` | Removes every delegate of [owner] (Unbind All Events). |
| `broadcast` | `void broadcast([Map<String, Object?> args = const {}])` |  |

### `abstract final class LuminaBlueprintActorClasses`

The actor classes `Spawn Actor from Class` can make: the project's Blueprint classes by name (`BP_Door`), registered by the editor's class registry for Play-In-Editor and by the generated `main()` from `actors.g.dart`'s `luminaBlueprintFactories`, plus the engine's own `LuminaActor`, `LuminaPawn` and `LuminaCharacter`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `register` | `static void register(String className, LuminaActor Function() factory)` |  |
| `registerAll` | `static void registerAll(Map<String, LuminaActor Function()> factories)` |  |
| `unregister` | `static void unregister(String className)` |  |
| `clear` | `static void clear()` |  |
| `classNames` | `static Iterable<String> get classNames` | The registered class names. |
| `has` | `static bool has(String cls)` | Whether [cls] (`Actor:BP_Door` or `BP_Door`) can be spawned. |
| `create` | `static LuminaActor? create(String cls)` | A new actor of [cls], or null for an unknown class. |

### `mixin LuminaBlueprintRuntime`

What a running Blueprint needs besides its graph, shared by the VM and generated Dart so both behave the same: the component map, tracing, latent Delay, and input binding.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isEditor` | `static bool isEditor` | Whether Blueprints run under the editor's Play-In-Editor (PIE sets it while playing; a built game leaves it false): `Is Editor` reads it, and `Quit Game` only logs then unless PIE hooks `LuminaGame.onQuitRequested`. |
| `blueprintComponents` | `Map<String, LuminaActorComponent> blueprintComponents` | Components built from the Blueprint, by component id. |
| `debugShapes` | `final List<LuminaDebugShape> debugShapes` | The debug shapes this actor's nodes drew this tick (a trace's Draw Debug segment, Draw Debug Line…), cleared at the start of every tick; the world keeps them with their durations in `LuminaWorld.debugShapes`. |
| `blueprintComponentTree` | `List<LuminaBlueprintComponent> blueprintComponentTree` | The Blueprint's component tree as authored, so `Get <Component>` can find a component by its name. |
| `blueprintClassName` | `String get blueprintClassName` | The Blueprint's class name (`BP_ThirdPersonCharacter`), what `Actor:<class>` pins, Cast To and Get Class Name see. |
| `blueprintParentClasses` | `List<String> get blueprintParentClasses` | Bu aktörün kalıtım sırasındaki üst Blueprint sınıf adları (önce doğrudan üst sınıf, sonra ata Blueprint'ler). |
| `blueprintAnimClasses` | `LuminaAnimBlueprintFactory? Function(String animClass)? blueprintAnimClasses` | Resolves a Skeletal Mesh's Anim Class to its Animation Blueprint, for Set Anim Instance Class. |
| `blueprintFlowState` | `final Map<String, Object?> blueprintFlowState` | Per-node state of the flow-control macros (DoOnce, FlipFlop, Gate, DoN, MultiGate), by node id. Cleared at BeginPlay so a PIE restart starts over. |
| `callBlueprint` | `Map<String, Object?> callBlueprint(String name, Map<String, Object?> args)` | Answers a custom event, function or implemented interface function by name; the VM and generated classes override it. |
| `blueprintDispatchers` | `final Map<String, LuminaMulticastDelegate> blueprintDispatchers` | The event dispatchers of this instance, by name; created on first use. |
| `blueprintDispatcher` | `LuminaMulticastDelegate blueprintDispatcher(String name)` |  |
| `blueprintInterfaces` | `List<String> blueprintInterfaces` | The interface assets this Blueprint implements (the document's list; generated classes set it in their constructor). |
| `implementsInterface` | `bool implementsInterface(String name)` |  |
| `blueprintTimerHandles` | `final List<LuminaTimerHandle> blueprintTimerHandles` | Timer handles this actor set (cleared at End Play so a PIE restart leaks no callback). |
| `blueprintTimelines` | `final Map<String, LuminaTimeline> blueprintTimelines` | The Timelines of this actor's graph, by node id. |
| `blueprintTimeline` | `LuminaTimeline blueprintTimeline(String nodeId, [Map<String, dynamic> literals = const {}])` | The timeline of node [nodeId], built from [literals] on first use. |
| `blueprintLatentCompletions` | `final List<void Function()> blueprintLatentCompletions` | Callbacks of latent nodes (Load Stream Level, Async Save Game) that resolved off the tick, run at the next latent advance. |
| `blueprintBeginPlayTime` | `double blueprintBeginPlayTime` | The world time this actor's BeginPlay ran, for `Get Game Time Since Creation`. |
| `blueprintInputEnabled` | `bool blueprintInputEnabled` | Enable / Disable Input: while false the bound input handlers do not run. |
| `blueprintMontage` | `LuminaBlueprintMontagePlayback? blueprintMontage` | The montage this Blueprint is playing on its skeletal mesh. |
| `blueprintMontageMesh` | `LuminaAnimatedMeshComponent? blueprintMontageMesh` | The mesh the montage plays on. |
| `onMontageEnded` | `void onMontageEnded(String montage, bool interrupted)` | Called when the playing montage ends: [interrupted] when stopped or replaced (the Blueprint Montage Ended event). |
| `onAnimNotify` | `void onAnimNotify(String notifyName)` | Called when the playing montage passes a notify (the Anim Notify event). |
| `endBlueprintMontage` | `void endBlueprintMontage({required bool interrupted})` | Ends the running montage, [interrupted] or not, restoring the Anim Blueprint. |
| `blueprintTimerManager` | `LuminaTimerManager? get blueprintTimerManager` | The world's timer manager, registered when the world has none yet. |
| `blueprintRetriggerableDelay` | `void blueprintRetriggerableDelay(String nodeId, double seconds, void Function() resume)` | Retriggerable Delay: like [blueprintDelay], but a trigger while pending restarts the countdown. |
| `blueprintComponentNamed` | `LuminaActorComponent? blueprintComponentNamed(String name)` | The component named [name] in the Blueprint (by name or id), or null. |
| `trace` | `void Function(LuminaBlueprintTraceEvent event)? trace` | Called for every executed node and every evaluated pure node. |
| `lastError` | `String? lastError` | The last runtime error (an aborted run), for the editor to show. |
| `blueprintTrace` | `void blueprintTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String...` |  |
| `blueprintDelay` | `void blueprintDelay(String nodeId, double seconds, void Function() resume)` | Delay: [resume] runs [seconds] later. A Delay node already pending ignores the new trigger. |
| `advanceBlueprintLatent` | `void advanceBlueprintLatent(double deltaTime)` | Advances pending Delays and the Timelines; the owner calls it each tick before Event Tick. |
| `blueprintInputBound` | `bool get blueprintInputBound` | Whether input is bound (the pawn is player-controlled and in a world). |
| `bindBlueprintInput` | `void bindBlueprintInput(List<LuminaBlueprintInputBinding> bindings)` | Binds [bindings] once the pawn is controlled by a player controller and in a world; a no-op before that or when already bound. The world's input subsystem is created if needed. |
| `unbindBlueprintInput` | `void unbindBlueprintInput()` |  |

## `lib/src/blueprint/level_blueprint.dart`

### `class LuminaBlueprintLevelActorRef`

A placed actor a Level Blueprint refers to by name: its outliner name (`Door_01`), its class as an object pin types it (`Actor:BP_Door`, `Actor:LuminaPlayerStart`) and the id the level mounts it with (`LuminaObjectKey(id)`, in Play-In-Editor and in the generated level).

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintLevelActorRef({required this.name, required this.actorClass, required this.id})`
- `factory LuminaBlueprintLevelActorRef.fromJson(Map<String, dynamic> map)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `actorClass` | `final String actorClass` |  |
| `id` | `final String id` |  |
| `engineClassOfType` | `static const Map<String, String> engineClassOfType` | The engine class of each editor actor type a level can hold. |
| `classOfActorMap` | `static String classOfActorMap(Map<String, dynamic> actor)` | The class string of a placed actor map (`metadata.actors[]`): its Blueprint class (`contents/blueprints/BP_Door.lmas` → `Actor:BP_Door`), else its type's engine class, else `Actor:LuminaActor`. |
| `fromActorMap` | `static LuminaBlueprintLevelActorRef? fromActorMap(Map<String, dynamic> actor)` | The reference of a placed actor map; null for a folder or a nameless actor. |
| `fromActorMaps` | `static List<LuminaBlueprintLevelActorRef> fromActorMaps(Iterable<Object?> actors)` | Every referable actor of a level's `metadata.actors`, in level order. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaLevelBlueprintDocument`

A level's own Blueprint (the Level Blueprint): the graph that scripts the level itself — events, variables, functions, macros, dispatchers, timelines — stored inside the level `.lmas` under `metadata.levelBlueprint`, so a level and its script travel together.

**Yapıcı Metotlar (Constructors):**

- `LuminaLevelBlueprintDocument({required this.levelPath, LuminaBlueprintDocument? blueprint})`
- `factory LuminaLevelBlueprintDocument.fromJson(Map<String, dynamic> map, {String? levelPath})`
- `factory LuminaLevelBlueprintDocument.fromLevelMetadata(Object? metadata, {required String levelPath})`: The document a level's `metadata` stores; an empty graph when the level has none (or it cannot be read).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kind` | `static const String kind` | The `kind` discriminator of the stored payload. |
| `metadataKey` | `static const String metadataKey` | The level `.lmas` metadata key the document is stored under. |
| `parentClass` | `static const String parentClass` | The class every level script is (`Self` in a Level Blueprint). |
| `levelPath` | `final String levelPath` | The project-relative level this Blueprint scripts (`contents/levels/L_Test.lmas`). |
| `blueprint` | `final LuminaBlueprintDocument blueprint` | The graph, variables, functions… (`parentClass` is always [parentClass]; a level Blueprint has no components). |
| `levelName` | `String get levelName` | The level's base name (`L_Test`). |
| `isEmpty` | `bool get isEmpty` | Whether the Blueprint does nothing: no nodes, variables or functions. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `mixin LuminaBlueprintLevelActors`

What a level script needs to find the level's placed actors by name: the VM's `LuminaBlueprintLevelScript` and every generated `_<Level>Script` mix it in. The level mounts each placed actor with `LuminaObjectKey(id)`; [levelActor] finds it among the owning level's actors, then the world's, and answers null once it was destroyed or removed.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `levelActorIds` | `Map<String, String> get levelActorIds` | Placed actor name → the id the level mounts it with. |
| `levelActor` | `LuminaActor? levelActor(String name)` | The live placed actor named [name], or null (unknown, destroyed or removed from the level). |
| `liveLevelActor` | `LuminaActor? liveLevelActor(LuminaActor? actor)` | [actor] while it is still in play; null once destroyed or removed. |
| `levelActorsOfClass` | `List<Object?> levelActorsOfClass(String cls)` | The live placed actors of class string [cls], in level order. |

## `lib/src/blueprint/level_blueprint_storage.dart`

Bir level `.lmas` dosyası Level Blueprint'ini JSON olarak saklar (`lumina_core`'da `LuminaLevelDocument.levelBlueprintJson`). Bu extension'lar onu engine'in [`LuminaLevelBlueprintDocument`](#libsrcblueprintlevel_blueprintdart) tipine okur ve geri yazar.

### `extension LuminaLevelDocumentBlueprint on LuminaLevelDocument`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `levelBlueprint` | `LuminaLevelBlueprintDocument get levelBlueprint` | Level'ın Blueprint'i: saklanan yoksa boş bir graf. |
| `levelBlueprint` | `set levelBlueprint(LuminaLevelBlueprintDocument? value)` | [value]'yu `metadata.levelBlueprint` altına yazar; boş bir Blueprint anahtarı siler, böylece script'i olmayan bir level olduğu gibi kalır. |
| `levelActorRefs` | `List<LuminaBlueprintLevelActorRef> get levelActorRefs` | Bir Level Blueprint'in adıyla başvurduğu yerleştirilmiş actor'ler. |

### `extension LuminaLevelRepositoryBlueprint on LuminaLevelRepository`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `loadLevelBlueprint` | `LuminaLevelBlueprintDocument loadLevelBlueprint(String relativePath)` | [relativePath] level'ının Level Blueprint'i; level'da yoksa (ya da level henüz yoksa) boş bir graf. |
| `saveLevelBlueprint` | `LuminaLevelDocument saveLevelBlueprint(LuminaLevelBlueprintDocument blueprint)` | [blueprint]'i kendi level'ına (`metadata.levelBlueprint`) yazar; level kapsayıcısı yoksa oluşturur. Kaydedilen level'ı döndürür. |

## `lib/src/blueprint/node_library.dart`

### `enum LuminaBlueprintNodeKind`

How a node takes part in execution.

**Değerler:**

- `event`: An entry point: BeginPlay, Tick, an input action.
- `impure`: Runs when its exec input fires, then continues from its exec output.
- `pure`: No exec pins; evaluated when an impure node pulls one of its outputs.
- `flow`: Chooses where execution continues (Branch, Sequence).
- `latent`: Continues later (Delay).

### `class LuminaBlueprintPinSpec`

A pin as the library declares it.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintPinSpec(this.id, this.name, this.type, {this.defaultValue, this.required = false, this.objectClass, this.elementType, this.enumName})`
- `factory LuminaBlueprintPinSpec.ofVariable(LuminaBlueprintVariable v)`: The pin a declared parameter / variable makes: id and name are its name.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `type` | `final LuminaPinType type` |  |
| `defaultValue` | `final Object? defaultValue` |  |
| `required` | `final bool required` | A required input must be wired or given a literal. |
| `objectClass` | `final String? objectClass` | The class of an object pin: `Widget:WBP_HUD`, `WidgetElement:text`, `Component:LuminaSpringArmComponent`, `Actor:BP_Door`; null is any object. |
| `elementType` | `final LuminaPinType? elementType` | The element type of an array pin. |
| `enumName` | `final String? enumName` | The enum of an enum pin. |
| `toPin` | `LuminaBlueprintPin toPin({required bool isOutput})` |  |
| `retyped` | `LuminaBlueprintPinSpec retyped(LuminaPinType type, {String? objectClass, LuminaPinType? elementType, String? e...` | This pin with another type and class. |
| `renamed` | `LuminaBlueprintPinSpec renamed(String name)` | This pin with another name. |

### `class LuminaBlueprintNodeSpec`

One node of the library: its pins and kind. Behaviour lives in `LuminaBlueprintFunctionLibrary` (pure and impure nodes) or in the VM ([LuminaBlueprintNodeLibrary.intrinsics]).

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintNodeSpec({required this.id, required this.title, required this.category, required this.kind, this.inputs = const [], this.outputs = const [...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `title` | `final String title` |  |
| `category` | `final String category` |  |
| `kind` | `final LuminaBlueprintNodeKind kind` |  |
| `inputs` | `final List<LuminaBlueprintPinSpec> inputs` |  |
| `outputs` | `final List<LuminaBlueprintPinSpec> outputs` |  |
| `keywords` | `final List<String> keywords` |  |
| `headerColor` | `final int headerColor` | ARGB header colour, one per node family. |
| `deprecation` | `final String? deprecation` | Non-null for a node kept only so old documents load; the message says what replaces it. |
| `unsupported` | `final String? unsupported` | Non-null when the node loads but is not executed yet; the message says why. Reported as a warning. |
| `tooltip` | `final String? tooltip` | What the palette shows on hover: an exposed Dart function's doc comment. |
| `hasExecIn` | `bool get hasExecIn` |  |

### `abstract final class LuminaBlueprintNodeLibrary`

The one node catalog the editor palette, the VM and the code generator read.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `enhancedInputAction` | `static const String enhancedInputAction` |  |
| `variableGet` | `static const String variableGet` |  |
| `variableSet` | `static const String variableSet` |  |
| `inputTriggerPins` | `static const List<String> inputTriggerPins` | Trigger exec outputs of [enhancedInputAction], in pin order. |
| `intrinsics` | `static const Set<String> intrinsics` | Nodes the VM executes itself because they steer execution rather than compute: they have no function-library entry. |
| `flowIntrinsics` | `static const Set<String> flowIntrinsics` | The flow-control macros, run by the VM and written as Dart control flow by the generator. |
| `statefulFlow` | `static const Set<String> statefulFlow` | Nodes with per-instance state the runtime keeps by node id. |
| `wildcardNodes` | `static const Set<String> wildcardNodes` | Nodes whose wildcard pins take the type of their `type` literal (`float`, `object`, …) and `class` literal. |
| `whileLoopCap` | `static const int whileLoopCap` | The while loop's iteration cap (an infinite-loop guard). |
| `classTypedNodes` | `static const Set<String> classTypedNodes` | Nodes whose object / array outputs take the class of their `class` literal. |
| `traceNodes` | `static const Set<String> traceNodes` | The trace nodes whose `channel` literal names a trace channel. |
| `actorEventHooks` | `static const Map<String, String> actorEventHooks` | The actor events and the actor hook each is dispatched from, for the VM and the generator. |
| `isValidBranch` | `static const String isValidBranch` | Typed object nodes. |
| `castTo` | `static const String castTo` |  |
| `getWidgetElement` | `static const String getWidgetElement` |  |
| `getComponent` | `static const String getComponent` |  |
| `customEvent` | `static const String customEvent` | Custom events, functions, macros, dispatchers, interfaces, enums and timelines. |
| `callCustomEvent` | `static const String callCustomEvent` |  |
| `functionEntry` | `static const String functionEntry` |  |
| `functionResult` | `static const String functionResult` |  |
| `callFunction` | `static const String callFunction` |  |
| `callFunctionPure` | `static const String callFunctionPure` |  |
| `macroInput` | `static const String macroInput` |  |
| `macroOutput` | `static const String macroOutput` |  |
| `callMacro` | `static const String callMacro` |  |
| `localVariableGet` | `static const String localVariableGet` |  |
| `localVariableSet` | `static const String localVariableSet` |  |
| `callDispatcher` | `static const String callDispatcher` |  |
| `bindEventToDispatcher` | `static const String bindEventToDispatcher` |  |
| `unbindEventFromDispatcher` | `static const String unbindEventFromDispatcher` |  |
| `unbindAllEvents` | `static const String unbindAllEvents` |  |
| `interfaceMessage` | `static const String interfaceMessage` |  |
| `implementsInterface` | `static const String implementsInterface` |  |
| `eventInterfaceFunction` | `static const String eventInterfaceFunction` |  |
| `enumLiteral` | `static const String enumLiteral` |  |
| `switchOnEnum` | `static const String switchOnEnum` |  |
| `timeline` | `static const String timeline` |  |
| `getGameMode` | `static const String getGameMode` | Game framework, save game and latent nodes. |
| `loadStreamLevel` | `static const String loadStreamLevel` |  |
| `loadLevel` | `static const String loadLevel` | Level loading with progress: Load Level preloads a persistent level, Change Level switches to it, Load And Change Level does both. |
| `changeLevel` | `static const String changeLevel` |  |
| `loadAndChangeLevel` | `static const String loadAndChangeLevel` |  |
| `levelLoadLatents` | `static const Set<String> levelLoadLatents` | The level-loading latents: each result pin (On Progress, On Error, On Success) re-enters the chain with fresh output values, and calls the custom event bound to its delegate input. |
| `asyncSaveGameToSlot` | `static const String asyncSaveGameToSlot` |  |
| `createSaveGameObject` | `static const String createSaveGameObject` |  |
| `setSaveField` | `static const String setSaveField` |  |
| `getSaveField` | `static const String getSaveField` |  |
| `getLevelActor` | `static const String getLevelActor` | Level Blueprints: a placed actor by name, the level's actors of a class, and the level's own events. |
| `getLevelActorsOfClass` | `static const String getLevelActorsOfClass` |  |
| `eventLevelBeginPlay` | `static const String eventLevelBeginPlay` |  |
| `eventLevelTick` | `static const String eventLevelTick` |  |
| `eventLevelEndPlay` | `static const String eventLevelEndPlay` |  |
| `eventLevelLoaded` | `static const String eventLevelLoaded` |  |
| `eventLevelUnloaded` | `static const String eventLevelUnloaded` |  |
| `levelEvents` | `static const Map<String, String?> levelEvents` | The level events, and the actor event each one is an alias of in a Level Blueprint (placing both is placing the event twice). |
| `levelOnlyNodes` | `static const Set<String> levelOnlyNodes` | Nodes only a Level Blueprint may hold. |
| `selfComponentNodes` | `static const Set<String> selfComponentNodes` | Nodes that reach the Blueprint's own components, which a Level Blueprint has none of. |
| `eventWidgetConstruct` | `static const String eventWidgetConstruct` | Widget Blueprint graphs: the widget's lifecycle events, a bound element event (`On Clicked (StartButton)`, literals `element` + `event`), an `Is Variable` element (literal `element`) and Self. |
| `eventWidgetPreConstruct` | `static const String eventWidgetPreConstruct` |  |
| `eventWidgetDestruct` | `static const String eventWidgetDestruct` |  |
| `eventWidgetTick` | `static const String eventWidgetTick` |  |
| `eventWidgetElement` | `static const String eventWidgetElement` |  |
| `getWidgetVariable` | `static const String getWidgetVariable` |  |
| `getWidgetSelf` | `static const String getWidgetSelf` |  |
| `widgetOnlyNodes` | `static const Set<String> widgetOnlyNodes` | Nodes only a Widget Blueprint graph may hold. |
| `actorEvents` | `static const Set<String> actorEvents` | The actor's own events, which a widget does not have. |
| `slateVisibilityEnum` | `static const String slateVisibilityEnum` | `ESlateVisibility`: the values Set Visibility takes (strings at run time). |
| `slateVisibilities` | `static const List<String> slateVisibilities` |  |
| `textCommitEnum` | `static const String textCommitEnum` | `ETextCommit`: how On Text Committed was committed. |
| `engineEnumValues` | `static List<String>? engineEnumValues(String? name)` | The values of an engine enum ([slateVisibilityEnum], [textCommitEnum], [timelineDirectionEnum]), or null for a project enum. |
| `availableIn` | `static bool availableIn(LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeContext context)` | Whether node [spec] belongs in a graph of [context]: level-only nodes in a Level Blueprint, component nodes everywhere else (the palette's filter); widget-only nodes in a Widget Blueprint, which takes no actor events, level nodes or components. |
| `widgetScopeError` | `static String? widgetScopeError(LuminaBlueprintNode node, LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeCon...` | Why [node] breaks the Widget Blueprint rules of [context], or null. |
| `callbackLatents` | `static const Set<String> callbackLatents` | Latent nodes whose Completed pin fires from a callback: the VM and the generator resume the chain there. |
| `timelineDirectionEnum` | `static const String timelineDirectionEnum` | The enum a Timeline's Direction output carries. |
| `timelineDirections` | `static const List<String> timelineDirections` |  |
| `signatureCalls` | `static const Set<String> signatureCalls` | Nodes whose data pins come from a signature the VM and generator pass as a name → value map: the call is variadic. |
| `dynamicPinNodes` | `static const Set<String> dynamicPinNodes` | Nodes whose every pin comes from the document (a function's or macro's signature) — their spec declares none. |
| `customEventsOf` | `static List<LuminaBlueprintCustomEvent> customEventsOf(LuminaBlueprintGraph graph)` | The custom events [graph] declares, with their parameters. |
| `customEventParameters` | `static List<LuminaBlueprintVariable> customEventParameters(LuminaBlueprintNode node)` | A custom event node's parameters: its `parameters` literal (`[{name, type, default}]`), else its stored data outputs. |
| `updateAnimation` | `static const String updateAnimation` | Animation Blueprint nodes. |
| `transitionResult` | `static const String transitionResult` |  |
| `all` | `static List<LuminaBlueprintNodeSpec> get all` | Every node: the built-ins, then the functions registered or declared in [LuminaBlueprintFunctionRegistry]. |
| `builtIns` | `static final List<LuminaBlueprintNodeSpec> builtIns` | The nodes lumina ships. |
| `spec` | `static LuminaBlueprintNodeSpec? spec(String id)` | The node [id]: a built-in, else a registered or declared function. |
| `builtIn` | `static LuminaBlueprintNodeSpec? builtIn(String id)` | The built-in node [id] only. |
| `actionValueType` | `static LuminaPinType actionValueType(InputValueType type)` | The pin type an input action's value carries. |
| `pinsOf` | `static ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})? pinsOf(LuminaBlueprintNo...` | The node's pins as the library resolves them for [context]. Fixed nodes take the spec's pins (a stored node's pin list cannot change them); variable nodes type their value from the variable, an input action node its Action Value from the action, and a Sequence keeps its stored outputs. Null for an unknown node. |
| `timelineTrackType` | `static LuminaPinType timelineTrackType(String type)` | The pin type of a timeline track (`float`, `vector`, `color`). |
| `displayTitle` | `static String displayTitle(String name)` | `AddHealth` → `Add Health`, `OnDoorOpened` → `On Door Opened`. |
| `place` | `static LuminaBlueprintNode place(String id, {required String nodeId, double x = 0.0, double y = 0.0, Map<Strin...` | A new node of library node [id] at ([x], [y]), with pins resolved for [context]. [literals] carries node settings such as `action` or `variable`. |
| `connectionError` | `static String? connectionError(LuminaBlueprintPinSpec from, LuminaBlueprintPinSpec to, {LuminaBlueprintTypeCon...` | Why output pin [from] cannot be wired into input pin [to], or null when it can: the types must match and, for object pins, the classes must be assignable; an array's element types must match too. |
| `canConnect` | `static bool canConnect(LuminaBlueprintPinSpec from, LuminaBlueprintPinSpec to, {LuminaBlueprintTypeContext con...` | Whether output pin [from] can be wired into input pin [to]. |

## `lib/src/blueprint/node_library/type_context.dart`

### `class LuminaBlueprintTypeContext`

What a node's dynamic pins depend on: the document's variables, the project's input actions and, for typed object pins, the project's widget classes, the document's component tree, the class of `Self` and the parent chain of the project's Blueprint classes.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintTypeContext({this.variables = const [], this.inputActions = const [], this.widgetClasses = const [], this.components = const [], this.selfC...`
- `factory LuminaBlueprintTypeContext.forDocument(LuminaBlueprintDocument doc, {List<LuminaInputAction> inputActions = const [], List<LuminaBlueprintWidgetClass>?...`: The context of [doc]: its variables and components, `Self` typed as its parent class (or [className] when given, the Blueprint's own class), plus the widget classes of [widgetClasses] (default: the [LuminaWidgetClassRegistry]), its functions, macros, dispatchers and custom events, and the project's enums / interfaces (default: the registries).
- `factory LuminaBlueprintTypeContext.forWidget(LuminaWidgetBlueprintDocument widgetDoc, {List<LuminaInputAction> inputActions = const [], List<LuminaBlueprintWidg...`: A Widget Blueprint's context: [widgetDoc]'s graph, `Self` typed `Widget:<class>`, and its `Is Variable` elements, which `Get <Element>` reads with no target and bound events are keyed by.
- `factory LuminaBlueprintTypeContext.forLevel(LuminaLevelBlueprintDocument levelDoc, {List<LuminaBlueprintLevelActorRef> levelActors = const [], List<LuminaInputA...`: A Level Blueprint's context: [levelDoc]'s variables, functions…, `Self` typed `Actor:LuminaLevelScriptActor`, and the level's placed actors ([levelActors]) that `Get <Actor>` refers to by name, with their project Blueprint classes' parents ([actorParents]) and custom events ([customEventOwners]).
- `factory LuminaBlueprintTypeContext.forFunction(LuminaBlueprintDocument doc, LuminaBlueprintFunctionGraph function, {List<LuminaInputAction> inputActions = const...`: The context of [function]'s own graph inside [doc].
- `factory LuminaBlueprintTypeContext.forMacro(LuminaBlueprintDocument doc, LuminaBlueprintMacroGraph macro, {List<LuminaInputAction> inputActions = const [], Stri...`: The context of [macro]'s body inside [doc].

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `variables` | `final List<LuminaBlueprintVariable> variables` |  |
| `inputActions` | `final List<LuminaInputAction> inputActions` |  |
| `widgetClasses` | `final List<LuminaBlueprintWidgetClass> widgetClasses` | The widget classes `Create Widget` can make and `Get <Element>` reads. |
| `components` | `final List<LuminaBlueprintComponentRef> components` | The components of the Blueprint (`Get CameraBoom` → Spring Arm). |
| `selfClass` | `final String selfClass` | The class of `Self` (`Actor:LuminaCharacter`, `Actor:BP_Door`). |
| `actorParents` | `final Map<String, String> actorParents` | Project Blueprint class → its parent (`BP_Door` → `LuminaActor`), for assignability up the chain. |
| `functions` | `final List<LuminaBlueprintFunctionGraph> functions` | The document's user functions, macros and dispatchers. |
| `macros` | `final List<LuminaBlueprintMacroGraph> macros` |  |
| `dispatchers` | `final List<LuminaBlueprintDispatcher> dispatchers` |  |
| `dispatcherOwners` | `final Map<String, List<LuminaBlueprintDispatcher>> dispatcherOwners` | Dispatchers of other Blueprint classes by class name, for `Bind Event to <Dispatcher>` on a typed target. |
| `customEvents` | `final List<LuminaBlueprintCustomEvent> customEvents` | The custom events the event graph declares. |
| `inheritedCustomEvents` | `final List<LuminaBlueprintCustomEvent> inheritedCustomEvents` | Ata Blueprint sınıflarından miras alınan ve bu Blueprint'te geçersiz kılınabilen (@override) özel olaylar. |
| `enums` | `final List<LuminaBlueprintEnumDocument> enums` | The project's enum and interface assets (default: the registries). |
| `interfaces` | `final List<LuminaBlueprintInterfaceDocument> interfaces` |  |
| `gameModeClass` | `final String? gameModeClass` | The project's GameMode Blueprint class (`BP_ThirdPersonGameMode`), what `Get Game Mode` is typed as. |
| `saveGameClasses` | `final List<LuminaBlueprintSaveGameDocument> saveGameClasses` | The project's save-game classes (default: the registry). |
| `functionScope` | `final LuminaBlueprintFunctionGraph? functionScope` | The function or macro whose graph is being resolved, when one is (`function_entry` / `function_result` / local variables / `macro_input` / `macro_output` type from it). |
| `macroScope` | `final LuminaBlueprintMacroGraph? macroScope` |  |
| `levelActors` | `final List<LuminaBlueprintLevelActorRef>? levelActors` | The placed actors a Level Blueprint refers to by name; null outside a Level Blueprint. |
| `customEventOwners` | `final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners` | Custom events of other Blueprint classes by class name, for a Call Custom Event on a typed target (e.g. a Level Blueprint calls `Open` on `Door_01`). |
| `widgetVariables` | `final List<LuminaBlueprintWidgetElement>? widgetVariables` | The `Is Variable` elements of the widget a Widget Blueprint graph scripts; null outside a Widget Blueprint. |
| `isLevelScope` | `bool get isLevelScope` | Whether this is a Level Blueprint's graph. |
| `isWidgetScope` | `bool get isWidgetScope` | Whether this is a Widget Blueprint's graph. |
| `widgetVariable` | `LuminaBlueprintWidgetElement? widgetVariable(String? name)` | The widget variable (an `Is Variable` element) named [name], or null. |
| `levelActor` | `LuminaBlueprintLevelActorRef? levelActor(String? name)` | The placed actor [name] of the level, or null. |
| `saveGameClass` | `LuminaBlueprintSaveGameDocument? saveGameClass(String? cls)` |  |
| `scoped` | `LuminaBlueprintTypeContext scoped(LuminaBlueprintDocument doc, {LuminaBlueprintFunctionGraph? function, Lumina...` | This context for [function]'s or [macro]'s graph of [doc]: everything the event graph knows (level actors, owners…) in that scope. |
| `function` | `LuminaBlueprintFunctionGraph? function(String? name)` |  |
| `macro` | `LuminaBlueprintMacroGraph? macro(String? name)` |  |
| `dispatcher` | `LuminaBlueprintDispatcher? dispatcher(String? name, {String? ownerClass})` | The dispatcher [name] of this Blueprint, or of the class [ownerClass] (`Actor:BP_Door` / `BP_Door`) when given and known. |
| `customEvent` | `LuminaBlueprintCustomEvent? customEvent(String? name)` |  |
| `customEventOf` | `LuminaBlueprintCustomEvent? customEventOf(String cls, String? name)` | The custom event [name] of class string [cls] (`Actor:BP_Door`): its own when [cls] is Self's class, else [customEventOwners]'. |
| `enumeration` | `LuminaBlueprintEnumDocument? enumeration(String? name)` |  |
| `interface` | `LuminaBlueprintInterfaceDocument? interface(String? name)` |  |
| `localVariable` | `LuminaBlueprintVariable? localVariable(String? name)` | A local variable of the function being resolved. |
| `variable` | `LuminaBlueprintVariable? variable(String? name)` |  |
| `inputAction` | `LuminaInputAction? inputAction(String? name)` |  |
| `widgetClass` | `LuminaBlueprintWidgetClass? widgetClass(String? name)` |  |
| `widgetElement` | `({LuminaBlueprintWidgetClass cls, LuminaBlueprintWidgetElement element})? widgetElement(String? className, Str...` | The element [elementName] of widget class [className], or of the first class that has one by that name when [className] is null. |
| `component` | `LuminaBlueprintComponentRef? component(String? name)` |  |
| `assignError` | `String? assignError(String? from, String? to)` | Why a value of object class [from] cannot feed a pin of class [to] (see [LuminaBlueprintObjectClass.assignError]). |

## `lib/src/blueprint/vm/blueprint_vm.dart`

### `class LuminaBlueprintCompileError`

Thrown by [LuminaBlueprintClass.instantiate] for a Blueprint with errors.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintCompileError(this.blueprint, this.errors)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `blueprint` | `final String blueprint` |  |
| `errors` | `final List<LuminaBlueprintDiagnostic> errors` |  |

### `class LuminaBlueprintClass`

A Blueprint document ready to run in the VM: validated once, then instantiated any number of times.

**Yapıcı Metotlar (Constructors):**

- `factory LuminaBlueprintClass.forLevel(LuminaLevelBlueprintDocument levelDoc, {List<LuminaBlueprintLevelActorRef> levelActors = const [], String? name, List<Lumi...`: A Level Blueprint ready to run: [levelDoc]'s graph with [levelActors] as the placed actors `Get <Actor>` finds, named after the level. Instantiate it with [instantiateLevelScript].
- `factory LuminaBlueprintClass.forWidget(LuminaWidgetBlueprintDocument widgetDoc, {List<LuminaInputAction> inputActions = const [], LuminaBlueprintAssetResolver?...`: A Widget Blueprint's graph ready to run: [widgetDoc]'s graph with its `Is Variable` elements, named after the widget class. Instantiate it with [instantiateUserWidget].
- `factory LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument document, {String name = 'Blueprint', List<LuminaInputAction> inputActions = const [], LuminaB...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` | The asset name, used in messages (`BP_ThirdPersonCharacter`). |
| `document` | `final LuminaBlueprintDocument document` |  |
| `inputActions` | `final List<LuminaInputAction> inputActions` |  |
| `resolveAsset` | `final LuminaBlueprintAssetResolver? resolveAsset` |  |
| `assetProvider` | `final Future<Uint8List> Function(String path)? assetProvider` |  |
| `animBlueprints` | `final LuminaAnimBlueprintFactory? Function(String animClass)? animBlueprints` | Resolves a Skeletal Mesh's `animClass` to its Animation Blueprint. |
| `resolveClass` | `final LuminaBlueprintClass? Function(String path)? resolveClass` | Resolves another Blueprint class by its project-relative `.lmas` path — a GameMode Blueprint's Default Pawn Class. Called again at every spawn, so a registry that reloads recompiled classes serves the newest one. |
| `diagnostics` | `final List<LuminaBlueprintDiagnostic> diagnostics` |  |
| `levelActors` | `final List<LuminaBlueprintLevelActorRef>? levelActors` | A Level Blueprint's placed actors; null for a class Blueprint. |
| `actorParents` | `final Map<String, String> actorParents` | Project Blueprint class → parent, and other classes' custom events, for typing object pins and targeted Call Custom Event. |
| `customEventOwners` | `final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners` |  |
| `widgetVariables` | `final List<LuminaBlueprintWidgetElement>? widgetVariables` | A Widget Blueprint's `Is Variable` elements; null for any other Blueprint. |
| `inheritedCustomEvents` | `List<LuminaBlueprintCustomEvent> get inheritedCustomEvents` | Ata Blueprint sınıflarından miras alınan tüm özel olaylar. |
| `allCustomEvents` | `List<LuminaBlueprintCustomEvent> get allCustomEvents` | Bu sınıfın tüm özel olayları (ata sınıfların olayları ve çocuk sınıfın @override geçersiz kılmaları). |
| `isUserWidget` | `bool get isUserWidget` | Whether this is a Widget Blueprint's graph (use [instantiateUserWidget]). |
| `isLevelScript` | `bool get isLevelScript` | Whether this is a Level Blueprint (use [instantiateLevelScript]). |
| `typeContext` | `LuminaBlueprintTypeContext typeContext({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? mac...` | The type context the class's graphs resolve in — [function]'s or [macro]'s graph when given. |
| `instantiateUserWidget` | `LuminaBlueprintUserWidget instantiateUserWidget()` | A new script of this Widget Blueprint, for [LuminaUserWidgets.register]. |
| `instantiateLevelScript` | `LuminaBlueprintLevelScript instantiateLevelScript({LuminaObjectKey? key})` | A new level script of this Level Blueprint, to set as the level's `scriptActor` before the world begins play. |
| `gameModeParent` | `static const String gameModeParent` | The parent class of a GameMode Blueprint. |
| `isGameMode` | `bool get isGameMode` | Whether this is a GameMode Blueprint (use [createGameMode]). |
| `isPawn` | `bool get isPawn` | Whether instances are pawns (a Pawn or Character Blueprint). |
| `defaultPawnClass` | `String get defaultPawnClass` | A GameMode Blueprint's Default Pawn Class (its `.lmas` path), or ''. |
| `hasErrors` | `bool get hasErrors` |  |
| `instantiate` | `LuminaActor instantiate({LuminaObjectKey? key, Vector3? location, Quaternion? rotation})` | A new actor of this class: a [LuminaBlueprintCharacter], [LuminaBlueprintPawn] or [LuminaBlueprintActor] by `parentClass`, with its components built and class defaults applied. |
| `createGameMode` | `LuminaGameMode createGameMode({LuminaPawn Function()? pawnOverride})` | The game mode of a GameMode Blueprint: its Default Pawn Class (resolved through [resolveClass] at every spawn) at the player start, possessed by a [LuminaPlayerController]. [pawnOverride] is the project's Maps & Modes Default Pawn Class, which wins when given. |

### `abstract interface class LuminaBlueprintGraphHost`

What the interpreter runs a graph against: the graph and its resolved pins, the variables, the actor the function library acts on (`self`), tracing, latent Delay and the loop guard. A Blueprint actor is one; an Animation Blueprint instance, whose `self` is its pawn, is another.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hostGraph` | `LuminaBlueprintGraph get hostGraph` |  |
| `hostPins` | `Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins` |  |
| `hostVariables` | `Map<String, Object?> get hostVariables` |  |
| `hostSelf` | `LuminaActor get hostSelf` |  |
| `hostMaxNodes` | `int get hostMaxNodes` |  |
| `hostName` | `String get hostName` |  |
| `hostTrace` | `void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? pri...` |  |
| `hostDelay` | `void hostDelay(String nodeId, double seconds, void Function() resume)` |  |
| `hostRetriggerableDelay` | `void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume)` |  |
| `hostError` | `void hostError(String message)` |  |
| `hostFlowState` | `Map<String, Object?> get hostFlowState` | Per-node flow-control state by node id. |
| `hostLocals` | `Map<String, Object?> get hostLocals` | Local variables of the function frame being run; empty outside a function. |
| `hostInstance` | `LuminaBlueprintInstance? get hostInstance` | The Blueprint the graph belongs to, for delegates, function calls and timelines; null for an Animation Blueprint. |

### `abstract final class LuminaBlueprintInterpreter`

Runs Blueprint graphs node by node.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `run` | `static void run(LuminaBlueprintGraphHost host, String nodeId, String execPin, Map<String, Object?> eventOutput...` | Runs the chain leaving [nodeId]'s exec output [execPin]. [eventOutputs] are the starting event's data outputs (Delta Seconds, Action Value). |
| `evaluateInput` | `static Object? evaluateInput(LuminaBlueprintGraphHost host, String nodeId, String pinId, {Map<String, Object?>...` | The value of [nodeId]'s input [pinId], evaluating pure nodes: a transition rule's result. |

### `class LuminaBlueprintActor`

A Blueprint with parent `LuminaActor`.

### `class LuminaBlueprintPawn`

A Blueprint with parent `LuminaPawn`.

### `class LuminaBlueprintCharacter`

A Blueprint with parent `LuminaCharacter`.

### `class LuminaBlueprintLevelScript`

A Level Blueprint's script actor: the level's [LuminaLevelScriptActor] running its graph in the VM. Event BeginPlay / Event Level BeginPlay, Tick, End Play, Level Loaded (before any other actor's BeginPlay) and Level Unloaded; `Get <Actor>` finds the level's placed actors by name. Never spawnable from a class.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `onBeginPlay` | `void onBeginPlay()` | Event (Level) BeginPlay waits for the local player: while the world has a game mode that has logged no one in yet — Play-In-Editor logs in right after `beginPlay` — it runs on [onPostLogin], or on the first tick if no one logs in. A built game logs in inside its script's BeginPlay, ahead of the graph, so both see the player's pawn. |

### `class LuminaBlueprintUserWidget`

A Widget Blueprint's script: the widget's [LuminaUserWidget] running its graph in the VM. Event Pre Construct / Construct when the widget is added to the viewport, Destruct when it is removed, Tick while it is on screen, and each bound element event (`On Clicked (StartButton)`) when [LuminaUserWidgets.fire] reports it.

## `lib/src/blueprint/vm/blueprint_vm/instance.dart`

### `mixin LuminaBlueprintInstance`

What every Blueprint actor carries: its class, variables, component map, the trace hook, and the interpreter.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `blueprintClass` | `late final LuminaBlueprintClass blueprintClass` |  |
| `variables` | `final Map<String, Object?> variables` | Current variable values by name. |
| `maxNodesPerEvent` | `int maxNodesPerEvent` | A single event run stops after this many nodes (an infinite-loop guard). |
| `maxCallDepth` | `static const int maxCallDepth` | A function call nests at most this deep (a stack limit). |
| `callBlueprint` | `Map<String, Object?> callBlueprint(String name, Map<String, Object?> args)` | A custom event, a user function, or an implemented interface function, by [name]: the event's chain runs (no outputs), the function's graph runs on its own frame and returns its outputs. Unknown names do nothing. |
| `timelineFor` | `LuminaTimeline timelineFor(LuminaBlueprintGraphHost host, LuminaBlueprintNode node)` | A Timeline node's runtime, wired to re-enter the graph at its Update / Finished pins with the track values as the node's outputs. |

## `lib/src/blueprint/widget_blueprint.dart`

### `class LuminaWidgetBlueprintDocument`

A widget asset's own Blueprint graph (the Widget Blueprint Graph): the widget class it scripts, its `Is Variable` elements (typed members `Get <Element>` reads with no target) and the graph document itself — event graph, variables, functions, macros, dispatchers — whose parent class is always [parentClass]. The editor stores [blueprint]'s JSON inside the widget `.lmas` payload, beside the designer tree.

**Yapıcı Metotlar (Constructors):**

- `LuminaWidgetBlueprintDocument({required this.widgetClass, this.variables = const [], LuminaBlueprintDocument? blueprint,})`
- `factory LuminaWidgetBlueprintDocument.fromJson(Map<String, dynamic> map, {String? widgetClass})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `kind` | `static const String kind` | The `kind` discriminator of the stored payload. |
| `payloadKey` | `static const String payloadKey` | The payload key the designer document stores the graph under. |
| `parentClass` | `static const String parentClass` | The class every widget script is (`Self` is the widget instance). |
| `widgetClass` | `final String widgetClass` | The widget class (`WBP_Clicker`). |
| `variables` | `final List<LuminaBlueprintWidgetElement> variables` | The elements marked `Is Variable`, by designer name. |
| `blueprint` | `final LuminaBlueprintDocument blueprint` | The graph (`parentClass` is always [parentClass]; no components). |
| `selfClass` | `String get selfClass` | The pin class of the widget itself (`Widget:WBP_Clicker`), what Self is. |
| `variable` | `LuminaBlueprintWidgetElement? variable(String? name)` | The variable element [name], or null. |
| `isEmpty` | `bool get isEmpty` | Whether the graph does nothing: no nodes, variables or functions. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `emptyGraph` | `static LuminaBlueprintDocument emptyGraph()` | A fresh widget graph: parent [parentClass], nothing placed. |

### `abstract final class LuminaWidgetEvents`

The events each widget element type can bind in a Widget Blueprint graph (the green `+` buttons in the Details panel), by the designer's element type name (`button`, `slider`, `shadcnTextField`, …).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `onClicked` | `static const String onClicked` |  |
| `onHovered` | `static const String onHovered` |  |
| `onUnhovered` | `static const String onUnhovered` |  |
| `onValueChanged` | `static const String onValueChanged` |  |
| `onTextCommitted` | `static const String onTextCommitted` |  |
| `forType` | `static List<String> forType(String typeName)` | The events an element of [typeName] offers, in the Details panel's order. |
| `displayName` | `static String displayName(String event)` | `OnClicked` → `On Clicked` (the bound event node's title prefix). |
| `valueTypeOf` | `static String valueTypeOf(String typeName)` | The pin type name of `On Value Changed`'s `Value` for [typeName]: `float` (sliders), `boolean` (check boxes, switches, toggles), `integer` (tabs), `string` (texts, combo boxes, selects). |
| `commitMethods` | `static const List<String> commitMethods` | `ETextCommit` (On Text Committed's Commit Method). |

## `lib/src/blueprint/widget_classes.dart`

### `class LuminaBlueprintWidgetElement`

One named element of a widget class: what `Get <Name>` returns on a `Widget:<class>` pin. [typeName] is the UmgWidgetType name (`text`, `progressBar`, `button`, …); [props] are the designer's stored properties, which seed the element's runtime state.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintWidgetElement({required this.name, String? fieldName, required this.typeName, this.props = const {},})`
- `factory LuminaBlueprintWidgetElement.fromJson(Map<String, dynamic> map)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `fieldName` | `final String fieldName` | The Dart field the generated widget class exposes it as. |
| `typeName` | `final String typeName` |  |
| `props` | `final Map<String, dynamic> props` |  |
| `objectClass` | `String get objectClass` | The pin class of this element: `WidgetElement:text`. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlueprintWidgetClass`

The engine's plain description of a widget class (a UMG `.lmas` document as the Blueprint side sees it): its name and its named elements. The editor converts its `UmgDocument`; the generated game fills [LuminaWidgetClassRegistry] from its compiled widget classes.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintWidgetClass({required this.name, this.elements = const []})`
- `factory LuminaBlueprintWidgetClass.fromJson(Map<String, dynamic> map)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `elements` | `final List<LuminaBlueprintWidgetElement> elements` |  |
| `objectClass` | `String get objectClass` | The pin class of this widget: `Widget:WBP_HUD`. |
| `element` | `LuminaBlueprintWidgetElement? element(String? name)` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `abstract final class LuminaWidgetClassRegistry`

The widget classes a running game or the editor knows: `Create Widget` builds a widget instance's per-element state from the class found here. Unknown classes still create a widget with no elements.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `register` | `static void register(LuminaBlueprintWidgetClass cls)` | Adds or replaces [cls] under its name. |
| `registerAll` | `static void registerAll(Iterable<LuminaBlueprintWidgetClass> classes)` |  |
| `lookup` | `static LuminaBlueprintWidgetClass? lookup(String? name)` |  |
| `unregister` | `static void unregister(String name)` |  |
| `clear` | `static void clear()` |  |
| `isEmpty` | `static bool get isEmpty` |  |
| `classes` | `static List<LuminaBlueprintWidgetClass> get classes` | Every registered class, in registration order. |
| `elementsFor` | `static Map<String, Object?> elementsFor(String className)` | A fresh widget instance's `elements` map for [className]: one JSON-plain map per element, seeded from the designer's properties. |
| `newElementState` | `static Map<String, Object?> newElementState(LuminaBlueprintWidgetElement e)` | The runtime state of one element: its type, the common properties every element has, then the designer's stored properties. |

### `class LuminaBlueprintComponentRef`

One component of a Blueprint's component tree as the type context sees it: `Get <name>` yields a `Component:<componentClass>`.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintComponentRef({required this.name, required this.componentClass, this.id})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `componentClass` | `final String componentClass` |  |
| `id` | `final String? id` | The component's id in the document, where the runtime finds it. |
| `objectClass` | `String get objectClass` | The pin class: `Component:LuminaSpringArmComponent`. |
| `fromComponents` | `static List<LuminaBlueprintComponentRef> fromComponents(List<LuminaBlueprintComponent> components)` | The refs of a document's components (editor-only components too: they are typed, and null at run time). |

---

[Önceki: Blueprint belgeleri ve asset'leri](model.md) | [Üst: Blueprint'ler](index.md) | [Sonraki: Blueprint fonksiyon kütüphanesi](function-library.md)
