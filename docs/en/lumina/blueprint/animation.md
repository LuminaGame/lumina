[Türkçe](../../../tr/lumina/blueprint/animation.md)

# Animation Blueprints

Animation Blueprints: the document with its variables, update graph and state machine (states, poses, transitions), blend spaces and aim offsets, the validator, and the instances that run it each tick, either in the VM or as generated code. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/blueprint/anim/anim_blueprint_instance.dart`](#libsrcblueprintanimanim_blueprint_instancedart)
- [`lib/src/blueprint/anim/anim_blueprint_model.dart`](#libsrcblueprintanimanim_blueprint_modeldart)
- [`lib/src/blueprint/anim/anim_blueprint_validator.dart`](#libsrcblueprintanimanim_blueprint_validatordart)
- [`lib/src/blueprint/vm/anim_blueprint_vm.dart`](#libsrcblueprintvmanim_blueprint_vmdart)

## `lib/src/blueprint/anim/anim_blueprint_instance.dart`

### `typedef LuminaAnimBlueprintFactory`

Makes the Animation Blueprint instance for a skeletal mesh component.

### `abstract class LuminaAnimBlueprintInstance`

A running Animation Blueprint: each tick it runs the update graph ([updateAnimation]), takes the first true transition out of the current state, and plays that state's pose on [mesh] — a clip, the nearest blend-space sample (crossfaded, phase-synced between samples of one blend space) at a rate from a speed variable, or the current pose held still.

Add it to the actor before [mesh], so a frame's pose is chosen before the mesh applies it (as the locomotion driver is). The VM ([LuminaVmAnimBlueprintInstance]) and generated classes override [updateAnimation] and [evaluateRule]; the rest is shared, so both animate the same way.

Before the update graph runs, three **reserved variables** are written for the graphs to read (declare them in the Animation Blueprint to use them): [stateTimeVariable] (seconds in the current state), [clipFinishedVariable] (the state's clip has played through once, see [clipFinished]) and [rootYawOffsetVariable] (degrees the planted mesh lags behind the pawn's yaw, see [rootYawOffsetDegrees]). Transitions may also gate on [LuminaAnimTransition.minStateTime] / [LuminaAnimTransition.automaticRule].

**Constructors:**

- `LuminaAnimBlueprintInstance({super.key, required this.mesh, required this.stateMachine, this.blendSpaces = const {}, this.meshYawOffsetDegrees = 0.0, this.aimOf...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `stateTimeVariable` | `static const String stateTimeVariable` |  |
| `clipFinishedVariable` | `static const String clipFinishedVariable` |  |
| `rootYawOffsetVariable` | `static const String rootYawOffsetVariable` |  |
| `rootYawBlendOutDegreesPerSecond` | `static const double rootYawBlendOutDegreesPerSecond` | How fast [rootYawOffsetDegrees] blends back to 0 while the current pose does not plant the feet (degrees per second). |
| `mesh` | `final LuminaAnimatedMeshComponent mesh` |  |
| `stateMachine` | `final LuminaAnimStateMachine stateMachine` |  |
| `blendSpaces` | `final Map<String, LuminaBlendSpaceDocument> blendSpaces` |  |
| `meshYawOffsetDegrees` | `final double meshYawOffsetDegrees` |  |
| `aimOffset` | `final LuminaAnimAimOffset? aimOffset` | The aim offset layered over the pose, if any. |
| `aimYaw` | `double get aimYaw` | The aim the bones show now (degrees), interpolating toward the clamped variables; 0 without an aim offset. |
| `aimPitch` | `double get aimPitch` |  |
| `blendWeights` | `Map<String, double> get blendWeights` | The current blend-space pose's sample weights by clip, summing to 1; the mesh plays the largest (gltfio crossfades two clips, it does not blend four). Empty outside a blend-space state. |
| `variables` | `final Map<String, Object?> variables` | Variable values by name, read by poses and written by the update graph. |
| `trace` | `void Function(LuminaBlueprintTraceEvent event)? trace` | Called for every executed node, as [LuminaBlueprintRuntime.trace]. |
| `random` | `math.Random random` | Picks the clip of a random pose on state entry; seed it for a deterministic run. |
| `clipDurationFallbacks` | `final Map<String, double> clipDurationFallbacks` | Clip lengths (seconds) for clips [mesh] cannot report yet — before its asset loads, or in a headless test where it never does. A clip whose length is known nowhere counts as finished at once. |
| `currentState` | `String? get currentState` | The state machine's current state. |
| `currentStateClip` | `String? get currentStateClip` | The clip the current state plays (the one picked for a random pose), if it plays a clip. |
| `stateTime` | `double get stateTime` | Seconds since the current state was entered. |
| `rootYawOffsetDegrees` | `double get rootYawOffsetDegrees` | Degrees the mesh is turned away from its owner's facing to keep its feet planted (negative after the pawn turned right); see [LuminaAnimPose.plantsFeet] and [LuminaAnimPose.rootYawDegrees]. |
| `clipDurationOf` | `double? clipDurationOf(String clip)` | Length of [clip] from the mesh, else [clipDurationFallbacks], else null. |
| `stateTimeRemaining` | `double? get stateTimeRemaining` | Seconds until the current state's clip has played through once at its rate; null when the state plays no clip or the length is unknown. |
| `clipFinished` | `bool get clipFinished` | Whether the current state's clip has played through once (a looping clip: its first cycle). True for a clip of unknown length, false for a blend space or a held pose. Frame times accumulate in floating point, so a microsecond short of the length counts as finished. |
| `updateAnimation` | `void updateAnimation(double deltaTimeX)` | Runs the update graph (Event Blueprint Update Animation). |
| `evaluateRule` | `bool evaluateRule(LuminaAnimTransition transition)` | Whether [transition]'s rule holds. |
| `blueprintTrace` | `void blueprintTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String...` |  |
| `montagePlaying` | `bool montagePlaying` | While a montage plays on the mesh the state machine keeps its state and time but leaves the mesh's clip alone. |
| `pawnOwner` | `LuminaActor get pawnOwner` | The pawn this instance animates: the function library's `self`. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaAnimVariableDefaults` | `Map<String, Object?> luminaAnimVariableDefaults(List<LuminaBlueprintVariable> variables)` | Initial variable values of [variables], as the pin types' values. |

## `lib/src/blueprint/anim/anim_blueprint_model.dart`

### `class LuminaBlendSpaceAxis`

One axis of a blend space.

**Constructors:**

- `const LuminaBlendSpaceAxis(this.name, this.min, this.max)`
- `factory LuminaBlendSpaceAxis.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `min` | `final double min` |  |
| `max` | `final double max` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlendSpaceSample`

A clip placed in a blend space at ([x], [y]).

**Constructors:**

- `const LuminaBlendSpaceSample(this.clip, this.x, [this.y = 0.0])`
- `factory LuminaBlendSpaceSample.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `clip` | `final String clip` |  |
| `x` | `final double x` |  |
| `y` | `final double y` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaBlendSpaceDocument`

A 1D or 2D blend space asset (`blend_space` `.lmas` payload).

**Constructors:**

- `const LuminaBlendSpaceDocument({required this.axes, required this.samples})`
- `factory LuminaBlendSpaceDocument.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `axes` | `final List<LuminaBlendSpaceAxis> axes` |  |
| `samples` | `final List<LuminaBlendSpaceSample> samples` |  |
| `nearest` | `LuminaBlendSpaceSample? nearest(double x, [double y = 0.0])` | The sample nearest to ([x], [y]) with each axis normalised to its range. gltfio blends exactly two clips, so the nearest sample plus a crossfade is what plays. An exact tie goes to the sample farther from the origin, which matches the locomotion driver's rounding of 45° sectors. |
| `containsClip` | `bool containsClip(String? clip)` |  |
| `rows` | `List<double> get rows` | The distinct Y values the samples sit on, ascending: a 2D space's rows (e.g. the walk row and the jog row on the Speed axis); one row for a 1D space. |
| `weightedSamples` | `List<(LuminaBlendSpaceSample, double)> weightedSamples(double x, [double y = 0.0])` | The samples ([x], [y]) blends and their weights, summing to 1: along X the two samples of a row around [x] share it linearly (clamped to the row's ends — `BS_Walk` / `BS_Locomotion` repeat backward at ±180 so the direction ring wraps), and in a 2D space the two rows around [y] share it linearly too (bilinear; clamped to the first and last row). Zero weights are left out. |
| `weights` | `Map<String, double> weights(double x, [double y = 0.0])` | [weightedSamples] summed per clip. |
| `dominant` | `LuminaBlendSpaceSample? dominant(double x, [double y = 0.0])` | The sample with the largest weight at ([x], [y]) — what plays, since gltfio blends exactly two clips (a crossfade) rather than four. A tie goes to the sample farther from the origin, as in [nearest]. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `enum LuminaAnimPoseKind`

**Values:**

- `clip`
- `blendSpace`
- `hold`

### `class LuminaAnimPose`

What a state plays: a clip (or one clip picked at random from a set when the state is entered), a blend space sampled by variables (with a play rate from a speed variable), or the current pose held still.

A clip pose may play once ([loop] false — the last frame holds until the state is left; the instance reports it in its `ClipFinished` variable), turn the mesh by [rootYawDegrees] over the clip's length (turn-in-place clips whose root motion was stripped), and [plantsFeet]: while such a state plays, the mesh keeps facing where it was when the pawn's yaw changes, and the instance's `RootYawOffset` variable accumulates the difference for the transition rules (the root yaw offset).

**Constructors:**

- `const LuminaAnimPose.clip(String this.clip, {this.rate = 1.0, this.loop = true, this.rootYawDegrees = 0.0, this.plantsFeet = false,})`
- `LuminaAnimPose.randomClip(List<String> clips, {this.rate = 1.0, this.loop = false, this.rootYawDegrees = 0.0, this.plantsFeet = false,})`: One of [clips], chosen when the state is entered (idle breaks). Plays once by default.
- `const LuminaAnimPose.blendSpace(String this.blendSpace, {required String this.xVariable, this.yVariable, this.rate = 1.0, this.rateVariable, this.rateReference...`
- `const LuminaAnimPose.hold()`
- `factory LuminaAnimPose.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `final LuminaAnimPoseKind kind` |  |
| `clip` | `final String? clip` |  |
| `clips` | `final List<String> clips` | The clips a random pose picks from on state entry; empty for a single clip. [clip] is then the first of them. |
| `blendSpace` | `final String? blendSpace` |  |
| `xVariable` | `final String? xVariable` |  |
| `yVariable` | `final String? yVariable` |  |
| `rate` | `final double rate` |  |
| `rateVariable` | `final String? rateVariable` |  |
| `rateReference` | `final double rateReference` |  |
| `minRate` | `final double minRate` |  |
| `maxRate` | `final double maxRate` |  |
| `rateRows` | `final bool rateRows` | A 2D blend space's play rate follows the speed row of the sample that plays: [rateVariable] over that sample's Y (the walk row 250, the jog row 480) instead of the single [rateReference], so both the walk and the jog keep their feet planted. |
| `loop` | `final bool loop` |  |
| `rootYawDegrees` | `final double rootYawDegrees` |  |
| `plantsFeet` | `final bool plantsFeet` |  |
| `isRandom` | `bool get isRandom` | Whether this is a clip pose that picks among several clips. |
| `candidates` | `List<String> get candidates` | The clips this pose can play: the random set, or the single clip. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimState`

A state of the state machine and where the editor draws it.

**Constructors:**

- `const LuminaAnimState(this.name, this.pose, {this.x = 0.0, this.y = 0.0})`
- `factory LuminaAnimState.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `pose` | `final LuminaAnimPose pose` |  |
| `x` | `final double x` |  |
| `y` | `final double y` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimTransition`

A transition arrow: taken when its rule graph's Result is true, the state has been active for at least [minStateTime] seconds and — with [automaticRule] (an automatic rule based on the state's sequence player) — the state's one-shot clip has finished. Lower [priority] is checked first.

**Constructors:**

- `LuminaAnimTransition({required this.id, required this.from, required this.to, this.blendDuration = 0.2, this.priority = 0, this.minStateTime = 0.0, this.automat...`
- `factory LuminaAnimTransition.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `from` | `final String from` |  |
| `to` | `final String to` |  |
| `blendDuration` | `final double blendDuration` |  |
| `priority` | `final int priority` |  |
| `minStateTime` | `final double minStateTime` |  |
| `automaticRule` | `final bool automaticRule` |  |
| `rule` | `final LuminaBlueprintGraph rule` | A pure graph over the Animation Blueprint's variables ending in one `transition_result` node. |
| `resultNode` | `LuminaBlueprintNode? get resultNode` | The rule's `transition_result` node. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimStateMachine`

The AnimGraph's state machine (e.g. "Locomotion").

**Constructors:**

- `LuminaAnimStateMachine({required this.name, required this.entryState, required this.states, required this.transitions, this.sampleCrossFade = 0.2,})`
- `factory LuminaAnimStateMachine.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `entryState` | `final String entryState` |  |
| `states` | `final List<LuminaAnimState> states` |  |
| `transitions` | `final List<LuminaAnimTransition> transitions` |  |
| `sampleCrossFade` | `final double sampleCrossFade` | Seconds a change of blend-space sample blends over. |
| `state` | `LuminaAnimState? state(String name)` |  |
| `transitionsFrom` | `List<LuminaAnimTransition> transitionsFrom(String state)` | Transitions leaving [state], in the order they are checked. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimAimOffsetBone`

One bone of an aim offset and its share of the aim.

**Constructors:**

- `const LuminaAnimAimOffsetBone(this.name, this.weight)`
- `factory LuminaAnimAimOffsetBone.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `weight` | `final double weight` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimAimOffset`

An Aim Offset on a bone chain: every update the instance clamps the [yawVariable] / [pitchVariable] values to ±[maxYaw] / ±[maxPitch], interpolates toward them at [interpSpeed] (exponential, per second) and turns each of [bones] by its [LuminaAnimAimOffsetBone.weight] share through a joint override, on top of the playing clip. The default chain is `spine_03` / `neck_01` / `head`.

**Constructors:**

- `const LuminaAnimAimOffset({this.bones = defaultBones, this.yawVariable = 'AimYaw', this.pitchVariable = 'AimPitch', this.maxYaw = 80.0, this.maxPitch = 45.0, th...`
- `factory LuminaAnimAimOffset.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaultBones` | `static const List<LuminaAnimAimOffsetBone> defaultBones` |  |
| `bones` | `final List<LuminaAnimAimOffsetBone> bones` |  |
| `yawVariable` | `final String yawVariable` |  |
| `pitchVariable` | `final String pitchVariable` |  |
| `maxYaw` | `final double maxYaw` |  |
| `maxPitch` | `final double maxPitch` |  |
| `interpSpeed` | `final double interpSpeed` |  |
| `toJson` | `Map<String, dynamic> toJson()` |  |

### `class LuminaAnimBlueprintDocument`

An Animation Blueprint (`anim_blueprint` `.lmas` payload): the mesh it animates, its variables, the update event graph and the AnimGraph's state machine.

**Constructors:**

- `LuminaAnimBlueprintDocument({this.targetMesh = '', List<LuminaBlueprintVariable>? variables, LuminaBlueprintGraph? eventGraph, List<LuminaAnimStateMachine>? sta...`
- `factory LuminaAnimBlueprintDocument.fromJson(Map<String, dynamic> j)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targetMesh` | `final String targetMesh` |  |
| `variables` | `final List<LuminaBlueprintVariable> variables` |  |
| `eventGraph` | `final LuminaBlueprintGraph eventGraph` |  |
| `stateMachines` | `final List<LuminaAnimStateMachine> stateMachines` |  |
| `meshYawOffsetDegrees` | `final double meshYawOffsetDegrees` | Yaw from the mesh's authored forward to +Z (glTF faces +Z: 0). |
| `aimOffset` | `final LuminaAnimAimOffset? aimOffset` | The aim offset layered over the state machine's pose, if any. |
| `copyWith` | `LuminaAnimBlueprintDocument copyWith({String? targetMesh, List<LuminaBlueprintVariable>? variables, LuminaBlue...` |  |
| `stateMachine` | `LuminaAnimStateMachine? get stateMachine` | The AnimGraph's output state machine. |
| `updateDocument` | `LuminaBlueprintDocument get updateDocument` | The update graph and variables as a plain Blueprint document, so the Blueprint validator and code generator treat it like any other graph. |
| `toJson` | `Map<String, dynamic> toJson()` |  |

## `lib/src/blueprint/anim/anim_blueprint_validator.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `validateAnimBlueprint` | `List<LuminaBlueprintDiagnostic> validateAnimBlueprint(LuminaAnimBlueprintDocument document, {Map<String, Lumin...` | Checks an Animation Blueprint the way the VM and the code generator both need it: the update graph as a Blueprint graph without latent nodes, one state machine whose entry state exists, every blend space a state plays in [blendSpaces], and every transition joining two states with a pure rule graph that ends in a Result node. |

## `lib/src/blueprint/vm/anim_blueprint_vm.dart`

### `class LuminaAnimBlueprintClass`

An Animation Blueprint ready to run in the VM: its update graph and every transition rule validated once.

**Constructors:**

- `factory LuminaAnimBlueprintClass.fromDocument(LuminaAnimBlueprintDocument document, {String name = 'AnimBlueprint', Map<String, LuminaBlendSpaceDocument> blendS...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `document` | `final LuminaAnimBlueprintDocument document` |  |
| `blendSpaces` | `final Map<String, LuminaBlendSpaceDocument> blendSpaces` |  |
| `diagnostics` | `final List<LuminaBlueprintDiagnostic> diagnostics` |  |
| `hasErrors` | `bool get hasErrors` |  |
| `instantiate` | `LuminaVmAnimBlueprintInstance instantiate(LuminaAnimatedMeshComponent mesh)` |  |
| `factory` | `LuminaAnimBlueprintFactory get factory` |  |

### `class LuminaVmAnimBlueprintInstance`

An Animation Blueprint run by the VM: the update graph and the transition rules go through [LuminaBlueprintInterpreter], with the owning pawn as the function library's `self`.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `animClass` | `final LuminaAnimBlueprintClass animClass` |  |
| `maxNodesPerEvent` | `int maxNodesPerEvent` | A single update stops after this many nodes. |
| `lastError` | `String? lastError` |  |
| `hostDelay` | `void hostDelay(String nodeId, double seconds, void Function() resume)` | Unreachable: the validator rejects latent nodes in an Animation Blueprint. |

---

[Previous: Blueprint function library](function-library.md) | [Up: Blueprints](index.md) | [Next: Utilities, math and testing](../utilities.md)
