[Türkçe](../../tr/lumina/ai.md)

# AI

Game AI: the AI controller and path following, behavior trees with composites, decorators and tasks, the blackboard, the grid-based navigation system with A* path finding, and sight and hearing perception. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/ai/ai_controller.dart`](#libsrcaiai_controllerdart)
- [`lib/src/ai/behavior_tree.dart`](#libsrcaibehavior_treedart)
- [`lib/src/ai/blackboard.dart`](#libsrcaiblackboarddart)
- [`lib/src/ai/navigation_system.dart`](#libsrcainavigation_systemdart)
- [`lib/src/ai/perception.dart`](#libsrcaiperceptiondart)

## `lib/src/ai/ai_controller.dart`

### `enum PathFollowingRequestResult`

Result of issuing a path following or moveTo request.

### `enum PathFollowingStatus`

Current state of the AI path following execution.

### `enum PathFollowingResult`

Final completion status of a path following move request.

### `enum FocusPriority`

Focus priority level for AI gaze and orientation targeting.

### `class LuminaAIController`

Non-player counterpart of [LuminaPlayerController] that possesses a [LuminaPawn], executes path-following move requests, and manages a prioritized focus orientation stack.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `moveStatus` | `PathFollowingStatus get moveStatus` | Getter accessor returning the current value of `moveStatus`. |
| `currentPath` | `List<Vector3> get currentPath` | Getter accessor returning the current value of `currentPath`. |
| `stopMovement` | `void stopMovement()` | Aborts active movement and transitions status back to idle. |
| `pauseMove` | `void pauseMove()` | Pauses the active path following. |
| `resumeMove` | `void resumeMove()` | Resumes paused path following. |
| `clearFocus` | `void clearFocus(FocusPriority priority)` | Clears the focus setting at [priority]. |
| `focalPoint` | `Vector3? get focalPoint` | Evaluates the highest priority focus and returns the 3D world focal coordinate. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onUnpossess` | `void onUnpossess(LuminaPawn oldPawn)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/ai/behavior_tree.dart`

### `enum BTNodeResult`

Execution status result returned by behavior tree nodes.

### `enum BTFlowAbortMode`

Flow abort mode defining how decorator conditions interrupt active branches.

### `class BTContext`

Runtime context passed through behavior tree node ticks.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `blackboard` | `LuminaBlackboard blackboard` | Holds the `blackboard` property or configuration state. |
| `controller` | `LuminaAIController? controller` | Holds the `controller` property or configuration state. |
| `ownerActor` | `LuminaActor? ownerActor` | Holds the `ownerActor` property or configuration state. |
| `dt` | `double dt` | Holds the `dt` property or configuration state. |

### `class BTNode`

Abstract base class for all Behavior Tree nodes (composites, decorators, and tasks).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTSelector`

Composite node that executes children in sequence until one succeeds or remains in progress.

**Constructors:**
- `BTSelector(this.children)`: Initializes `BTSelector(this.children)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `children` | `List<BTNode> children` | Holds the `children` property or configuration state. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTSequence`

Composite node that executes children in sequence until one fails or remains in progress.

**Constructors:**
- `BTSequence(this.children)`: Initializes `BTSequence(this.children)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `children` | `List<BTNode> children` | Holds the `children` property or configuration state. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTSimpleParallel`

Composite node executing a primary task alongside a background subtree.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `primary` | `BTNode primary` | Holds the `primary` property or configuration state. |
| `background` | `BTNode background` | Holds the `background` property or configuration state. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTDecorator`

Base class for decorator nodes that wrap and conditionally control child execution.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `child` | `BTNode child` | Holds the `child` property or configuration state. |
| `observeAborts` | `BTFlowAbortMode observeAborts` | Holds the `observeAborts` property or configuration state. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | Executes `evaluateCondition` operation. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTBlackboardDecorator`

Decorator evaluating a blackboard condition before executing its child.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `key` | `String key` | Holds the `key` property or configuration state. |
| `isSet` | `bool? isSet` | Holds the `isSet` property or configuration state. |
| `equals` | `dynamic equals` | Holds the `equals` property or configuration state. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | Executes `evaluateCondition` operation. |

### `class BTCooldownDecorator`

Decorator enforcing a cooldown duration after successful child completion.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cooldownSeconds` | `double cooldownSeconds` | Holds the `cooldownSeconds` property or configuration state. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | Executes `evaluateCondition` operation. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |

### `class BTLoopDecorator`

Decorator looping child execution [count] times.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `count` | `int count` | Holds the `count` property or configuration state. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | Executes `evaluateCondition` operation. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTInverterDecorator`

Decorator inverting success into failure and vice versa.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | Executes `evaluateCondition` operation. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |

### `class BTWaitTask`

Leaf task waiting for a fixed duration of simulation time.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `seconds` | `double seconds` | Holds the `seconds` property or configuration state. |
| `randomDeviation` | `double randomDeviation` | Holds the `randomDeviation` property or configuration state. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTMoveToTask`

Leaf task commanding an AIController to move to a destination location or actor from blackboard.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `blackboardKey` | `String blackboardKey` | Holds the `blackboardKey` property or configuration state. |
| `acceptanceRadius` | `double acceptanceRadius` | Holds the `acceptanceRadius` property or configuration state. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx)` | Executes `abort` operation. |

### `class BTCallbackTask`

Custom leaf task delegating execution to closure callbacks.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt) => onTickCallback(ctx)` | Called every frame; updates physics, movement, and game logic by delta time (`dt`). |
| `abort` | `void abort(BTContext ctx) => onAbortCallback?.call(ctx)` | Executes `abort` operation. |

### `class LuminaBehaviorTreeComponent`

Actor component managing and ticking an active Behavior Tree.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `root` | `BTNode root` | Holds the `root` property or configuration state. |
| `blackboard` | `LuminaBlackboard blackboard` | Holds the `blackboard` property or configuration state. |
| `controller` | `LuminaAIController? controller` | Holds the `controller` property or configuration state. |
| `tickInterval` | `double tickInterval` | Holds the `tickInterval` property or configuration state. |
| `isRunning` | `bool get isRunning` | Checks current state or capability and returns a boolean value. |
| `start` | `void start()` | Executes `start` operation. |
| `stop` | `void stop()` | Executes `stop` operation. |
| `restart` | `void restart()` | Executes `restart` operation. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/ai/blackboard.dart`

### `class LuminaBlackboard`

Typed key/value memory storage used by Behavior Trees, Perception, and AI Controllers.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasValue` | `bool hasValue(String key) => _data.containsKey(key)` | Returns true if [key] is present in the blackboard. |
| `clearValue` | `void clearValue(String key)` | Clears the value for [key] and notifies registered observers. |
| `Function` | `void Function() addObserver(String key, void Function(String key) onChan...` | Adds a change listener for [key]. Returns an unsubscribe closure. |

## `lib/src/ai/navigation_system.dart`

### `class NavGridConfig`

Configuration properties for rasterizing a navigation grid and sizing agent clearances.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | Holds the `cellSize` property or configuration state. |
| `agentRadius` | `double agentRadius` | Holds the `agentRadius` property or configuration state. |
| `agentHeight` | `double agentHeight` | Holds the `agentHeight` property or configuration state. |
| `maxStepHeight` | `double maxStepHeight` | Holds the `maxStepHeight` property or configuration state. |
| `walkableLayerMask` | `int walkableLayerMask` | Holds the `walkableLayerMask` property or configuration state. |

### `class NavPath`

A computed path across the navigation grid consisting of world-space waypoint coordinates.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `points` | `List<Vector3> points` | Holds the `points` property or configuration state. |
| `isPartial` | `bool isPartial` | Holds the `isPartial` property or configuration state. |
| `length` | `double get length` | Getter accessor returning the current value of `length`. |

### `class LuminaNavigationSystem`

World subsystem that turns collision geometry into an inflated walkable grid and performs fast A* pathfinding.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isBuilt` | `bool get isBuilt` | Checks current state or capability and returns a boolean value. |
| `walkableCellCount` | `int get walkableCellCount` | Getter accessor returning the current value of `walkableCellCount`. |
| `config` | `NavGridConfig get config` | Getter accessor returning the current value of `config`. |
| `isWalkable` | `bool isWalkable(Vector3 worldPoint)` | Returns true if [worldPoint] lies within the grid bounds and is marked walkable. |
| `hasDirectWalkableLine` | `bool hasDirectWalkableLine(Vector3 a, Vector3 b)` | Tests if a direct unobstructed line of walkability exists between [a] and [b] using supercover rasterization. |
| `markDirty` | `void markDirty(Aabb3 region)` | Marks a bounding region as dirty for incremental re-rasterization. |
| `rebuildDirty` | `void rebuildDirty()` | Rebuilds all marked dirty regions immediately. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/ai/perception.dart`

### `class AISenseConfigSight`

Configuration parameters for the visual perception sense.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sightRadius` | `double sightRadius` | Holds the `sightRadius` property or configuration state. |
| `loseSightRadius` | `double loseSightRadius` | Holds the `loseSightRadius` property or configuration state. |
| `peripheralVisionAngleDegrees` | `double peripheralVisionAngleDegrees` | Holds the `peripheralVisionAngleDegrees` property or configuration state. |
| `maxAge` | `double maxAge` | Holds the `maxAge` property or configuration state. |
| `detectEnemies` | `bool detectEnemies` | Holds the `detectEnemies` property or configuration state. |
| `detectNeutrals` | `bool detectNeutrals` | Holds the `detectNeutrals` property or configuration state. |
| `detectFriendlies` | `bool detectFriendlies` | Holds the `detectFriendlies` property or configuration state. |

### `class AISenseConfigHearing`

Configuration parameters for the auditory perception sense.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hearingRange` | `double hearingRange` | Holds the `hearingRange` property or configuration state. |
| `maxAge` | `double maxAge` | Holds the `maxAge` property or configuration state. |

### `enum AISenseType`

Category of AI sensory perception.

### `class AIStimulus`

Record of a sensory stimulus received by an AI perception component.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `type` | `AISenseType type` | Holds the `type` property or configuration state. |
| `wasSuccessfullySensed` | `bool wasSuccessfullySensed` | Holds the `wasSuccessfullySensed` property or configuration state. |
| `stimulusLocation` | `Vector3 stimulusLocation` | Holds the `stimulusLocation` property or configuration state. |
| `receiverLocation` | `Vector3 receiverLocation` | Holds the `receiverLocation` property or configuration state. |
| `strength` | `double strength` | Holds the `strength` property or configuration state. |
| `age` | `double age` | Holds the `age` property or configuration state. |
| `maxAge` | `double maxAge` | Holds the `maxAge` property or configuration state. |
| `isExpired` | `bool get isExpired` | Checks current state or capability and returns a boolean value. |

### `class LuminaAIPerceptionComponent`

Actor component providing sight cones, LOS raycasting, and noise hearing perception.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sightConfig` | `AISenseConfigSight? sightConfig` | Holds the `sightConfig` property or configuration state. |
| `hearingConfig` | `AISenseConfigHearing? hearingConfig` | Holds the `hearingConfig` property or configuration state. |
| `updateInterval` | `double updateInterval` | Holds the `updateInterval` property or configuration state. |
| `dominantSense` | `AISenseType dominantSense` | Holds the `dominantSense` property or configuration state. |
| `getStimulusFor` | `AIStimulus? getStimulusFor(LuminaActor target, AISenseType sense)` | Retrieves the current stimulus for [target] and [sense]. |
| `receiveNoiseStimulus` | `void receiveNoiseStimulus(Vector3 location, double strength, LuminaActor...` | Executes `receiveNoiseStimulus` operation. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

### `class LuminaAIPerceptionSystem`

Central world subsystem maintaining registries of perception sources and listeners and routing stimuli.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `unregisterSource` | `void unregisterSource(LuminaActor actor)` | Executes `unregisterSource` operation. |
| `registerListener` | `void registerListener(LuminaAIPerceptionComponent listener)` | Executes `registerListener` operation. |
| `unregisterListener` | `void unregisterListener(LuminaAIPerceptionComponent listener)` | Executes `unregisterListener` operation. |
| `getSourcesFor` | `List<LuminaActor> getSourcesFor(AISenseType sense)` | Queries and returns the `SourcesFor` value or child object. |

---

[Previous: Physics](physics.md) | [Up: lumina (engine core)](index.md) | [Next: Materials and post-processing](materials-and-post-process.md)
