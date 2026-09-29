[English](../../en/lumina/ai.md)

# Yapay zeka (AI)

Oyun yapay zekası: AI controller ve path following, composite, decorator ve task'lı behavior tree'ler, blackboard, A* yol bulmalı grid tabanlı navigasyon sistemi ve görme ile duyma algısı. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `moveStatus` | `PathFollowingStatus get moveStatus` | `moveStatus` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentPath` | `List<Vector3> get currentPath` | `currentPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `stopMovement` | `void stopMovement()` | Aborts active movement and transitions status back to idle. |
| `pauseMove` | `void pauseMove()` | Pauses the active path following. |
| `resumeMove` | `void resumeMove()` | Resumes paused path following. |
| `clearFocus` | `void clearFocus(FocusPriority priority)` | Clears the focus setting at [priority]. |
| `focalPoint` | `Vector3? get focalPoint` | Evaluates the highest priority focus and returns the 3D world focal coordinate. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnpossess` | `void onUnpossess(LuminaPawn oldPawn)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/ai/behavior_tree.dart`

### `enum BTNodeResult`

Execution status result returned by behavior tree nodes.

### `enum BTFlowAbortMode`

Flow abort mode defining how decorator conditions interrupt active branches.

### `class BTContext`

Runtime context passed through behavior tree node ticks.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `blackboard` | `LuminaBlackboard blackboard` | `blackboard` alanını (field/property) ve ilişkili veriyi saklar. |
| `controller` | `LuminaAIController? controller` | `controller` alanını (field/property) ve ilişkili veriyi saklar. |
| `ownerActor` | `LuminaActor? ownerActor` | `ownerActor` alanını (field/property) ve ilişkili veriyi saklar. |
| `dt` | `double dt` | `dt` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BTNode`

Abstract base class for all Behavior Tree nodes (composites, decorators, and tasks).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTSelector`

Composite node that executes children in sequence until one succeeds or remains in progress.

**Yapıcı Metotlar (Constructors):**
- `BTSelector(this.children)`: `BTSelector(this.children)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `children` | `List<BTNode> children` | `children` alanını (field/property) ve ilişkili veriyi saklar. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTSequence`

Composite node that executes children in sequence until one fails or remains in progress.

**Yapıcı Metotlar (Constructors):**
- `BTSequence(this.children)`: `BTSequence(this.children)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `children` | `List<BTNode> children` | `children` alanını (field/property) ve ilişkili veriyi saklar. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTSimpleParallel`

Composite node executing a primary task alongside a background subtree.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `primary` | `BTNode primary` | `primary` alanını (field/property) ve ilişkili veriyi saklar. |
| `background` | `BTNode background` | `background` alanını (field/property) ve ilişkili veriyi saklar. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTDecorator`

Base class for decorator nodes that wrap and conditionally control child execution.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `child` | `BTNode child` | `child` alanını (field/property) ve ilişkili veriyi saklar. |
| `observeAborts` | `BTFlowAbortMode observeAborts` | `observeAborts` alanını (field/property) ve ilişkili veriyi saklar. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | `evaluateCondition` işlemini gerçekleştirir. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTBlackboardDecorator`

Decorator evaluating a blackboard condition before executing its child.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `key` | `String key` | `key` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSet` | `bool? isSet` | `isSet` alanını (field/property) ve ilişkili veriyi saklar. |
| `equals` | `dynamic equals` | `equals` alanını (field/property) ve ilişkili veriyi saklar. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | `evaluateCondition` işlemini gerçekleştirir. |

### `class BTCooldownDecorator`

Decorator enforcing a cooldown duration after successful child completion.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cooldownSeconds` | `double cooldownSeconds` | `cooldownSeconds` alanını (field/property) ve ilişkili veriyi saklar. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | `evaluateCondition` işlemini gerçekleştirir. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |

### `class BTLoopDecorator`

Decorator looping child execution [count] times.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | `evaluateCondition` işlemini gerçekleştirir. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTInverterDecorator`

Decorator inverting success into failure and vice versa.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `evaluateCondition` | `bool evaluateCondition(BTContext ctx)` | `evaluateCondition` işlemini gerçekleştirir. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |

### `class BTWaitTask`

Leaf task waiting for a fixed duration of simulation time.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `seconds` | `double seconds` | `seconds` alanını (field/property) ve ilişkili veriyi saklar. |
| `randomDeviation` | `double randomDeviation` | `randomDeviation` alanını (field/property) ve ilişkili veriyi saklar. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTMoveToTask`

Leaf task commanding an AIController to move to a destination location or actor from blackboard.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `blackboardKey` | `String blackboardKey` | `blackboardKey` alanını (field/property) ve ilişkili veriyi saklar. |
| `acceptanceRadius` | `double acceptanceRadius` | `acceptanceRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx)` | `abort` işlemini gerçekleştirir. |

### `class BTCallbackTask`

Custom leaf task delegating execution to closure callbacks.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tick` | `BTNodeResult tick(BTContext ctx, double dt) => onTickCallback(ctx)` | Her render karesinde delta zamanı (`dt`) ile fizik, hareket ve oyun mantığını günceller. |
| `abort` | `void abort(BTContext ctx) => onAbortCallback?.call(ctx)` | `abort` işlemini gerçekleştirir. |

### `class LuminaBehaviorTreeComponent`

Actor component managing and ticking an active Behavior Tree.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `root` | `BTNode root` | `root` alanını (field/property) ve ilişkili veriyi saklar. |
| `blackboard` | `LuminaBlackboard blackboard` | `blackboard` alanını (field/property) ve ilişkili veriyi saklar. |
| `controller` | `LuminaAIController? controller` | `controller` alanını (field/property) ve ilişkili veriyi saklar. |
| `tickInterval` | `double tickInterval` | `tickInterval` alanını (field/property) ve ilişkili veriyi saklar. |
| `isRunning` | `bool get isRunning` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `start` | `void start()` | `start` işlemini gerçekleştirir. |
| `stop` | `void stop()` | `stop` işlemini gerçekleştirir. |
| `restart` | `void restart()` | `restart` işlemini gerçekleştirir. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/ai/blackboard.dart`

### `class LuminaBlackboard`

Typed key/value memory storage used by Behavior Trees, Perception, and AI Controllers.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasValue` | `bool hasValue(String key) => _data.containsKey(key)` | Returns true if [key] is present in the blackboard. |
| `clearValue` | `void clearValue(String key)` | Clears the value for [key] and notifies registered observers. |
| `Function` | `void Function() addObserver(String key, void Function(String key) onChan...` | Adds a change listener for [key]. Returns an unsubscribe closure. |

## `lib/src/ai/navigation_system.dart`

### `class NavGridConfig`

Configuration properties for rasterizing a navigation grid and sizing agent clearances.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cellSize` | `double cellSize` | `cellSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `agentRadius` | `double agentRadius` | `agentRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `agentHeight` | `double agentHeight` | `agentHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxStepHeight` | `double maxStepHeight` | `maxStepHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `walkableLayerMask` | `int walkableLayerMask` | `walkableLayerMask` alanını (field/property) ve ilişkili veriyi saklar. |

### `class NavPath`

A computed path across the navigation grid consisting of world-space waypoint coordinates.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `points` | `List<Vector3> points` | `points` alanını (field/property) ve ilişkili veriyi saklar. |
| `isPartial` | `bool isPartial` | `isPartial` alanını (field/property) ve ilişkili veriyi saklar. |
| `length` | `double get length` | `length` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class LuminaNavigationSystem`

World subsystem that turns collision geometry into an inflated walkable grid and performs fast A* pathfinding.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isBuilt` | `bool get isBuilt` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `walkableCellCount` | `int get walkableCellCount` | `walkableCellCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `config` | `NavGridConfig get config` | `config` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isWalkable` | `bool isWalkable(Vector3 worldPoint)` | Returns true if [worldPoint] lies within the grid bounds and is marked walkable. |
| `hasDirectWalkableLine` | `bool hasDirectWalkableLine(Vector3 a, Vector3 b)` | Tests if a direct unobstructed line of walkability exists between [a] and [b] using supercover rasterization. |
| `markDirty` | `void markDirty(Aabb3 region)` | Marks a bounding region as dirty for incremental re-rasterization. |
| `rebuildDirty` | `void rebuildDirty()` | Rebuilds all marked dirty regions immediately. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/ai/perception.dart`

### `class AISenseConfigSight`

Configuration parameters for the visual perception sense.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sightRadius` | `double sightRadius` | `sightRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `loseSightRadius` | `double loseSightRadius` | `loseSightRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `peripheralVisionAngleDegrees` | `double peripheralVisionAngleDegrees` | `peripheralVisionAngleDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxAge` | `double maxAge` | `maxAge` alanını (field/property) ve ilişkili veriyi saklar. |
| `detectEnemies` | `bool detectEnemies` | `detectEnemies` alanını (field/property) ve ilişkili veriyi saklar. |
| `detectNeutrals` | `bool detectNeutrals` | `detectNeutrals` alanını (field/property) ve ilişkili veriyi saklar. |
| `detectFriendlies` | `bool detectFriendlies` | `detectFriendlies` alanını (field/property) ve ilişkili veriyi saklar. |

### `class AISenseConfigHearing`

Configuration parameters for the auditory perception sense.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hearingRange` | `double hearingRange` | `hearingRange` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxAge` | `double maxAge` | `maxAge` alanını (field/property) ve ilişkili veriyi saklar. |

### `enum AISenseType`

Category of AI sensory perception.

### `class AIStimulus`

Record of a sensory stimulus received by an AI perception component.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `type` | `AISenseType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `wasSuccessfullySensed` | `bool wasSuccessfullySensed` | `wasSuccessfullySensed` alanını (field/property) ve ilişkili veriyi saklar. |
| `stimulusLocation` | `Vector3 stimulusLocation` | `stimulusLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `receiverLocation` | `Vector3 receiverLocation` | `receiverLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `strength` | `double strength` | `strength` alanını (field/property) ve ilişkili veriyi saklar. |
| `age` | `double age` | `age` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxAge` | `double maxAge` | `maxAge` alanını (field/property) ve ilişkili veriyi saklar. |
| `isExpired` | `bool get isExpired` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class LuminaAIPerceptionComponent`

Actor component providing sight cones, LOS raycasting, and noise hearing perception.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sightConfig` | `AISenseConfigSight? sightConfig` | `sightConfig` alanını (field/property) ve ilişkili veriyi saklar. |
| `hearingConfig` | `AISenseConfigHearing? hearingConfig` | `hearingConfig` alanını (field/property) ve ilişkili veriyi saklar. |
| `updateInterval` | `double updateInterval` | `updateInterval` alanını (field/property) ve ilişkili veriyi saklar. |
| `dominantSense` | `AISenseType dominantSense` | `dominantSense` alanını (field/property) ve ilişkili veriyi saklar. |
| `getStimulusFor` | `AIStimulus? getStimulusFor(LuminaActor target, AISenseType sense)` | Retrieves the current stimulus for [target] and [sense]. |
| `receiveNoiseStimulus` | `void receiveNoiseStimulus(Vector3 location, double strength, LuminaActor...` | `receiveNoiseStimulus` işlemini gerçekleştirir. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

### `class LuminaAIPerceptionSystem`

Central world subsystem maintaining registries of perception sources and listeners and routing stimuli.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `unregisterSource` | `void unregisterSource(LuminaActor actor)` | `unregisterSource` işlemini gerçekleştirir. |
| `registerListener` | `void registerListener(LuminaAIPerceptionComponent listener)` | `registerListener` işlemini gerçekleştirir. |
| `unregisterListener` | `void unregisterListener(LuminaAIPerceptionComponent listener)` | `unregisterListener` işlemini gerçekleştirir. |
| `getSourcesFor` | `List<LuminaActor> getSourcesFor(AISenseType sense)` | `SourcesFor` bilgisini veya alt nesnesini sorgulayıp döndürür. |

---

[Önceki: Fizik](physics.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Materyaller ve post-processing](materials-and-post-process.md)
