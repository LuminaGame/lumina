[Türkçe](../../tr/lumina/object.md)

# Actors, pawns and characters

The runtime object hierarchy: `LuminaActor`, the base of everything placed in a world, `LuminaPawn`, an actor that a controller can possess, and `LuminaCharacter`, a pawn with a capsule and character movement, plus the `LuminaSaveable` mixin. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/object/actor.dart`](#libsrcobjectactordart)
- [`lib/src/object/character.dart`](#libsrcobjectcharacterdart)
- [`lib/src/object/pawn.dart`](#libsrcobjectpawndart)

## `lib/src/object/actor.dart`

### `mixin LuminaSaveable`

Mixin defining serialization hooks for persistent actors and components.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `captureSaveData` | `Map<String, dynamic> captureSaveData()` | Captures custom save game variables into a JSON-encodable map. |
| `restoreSaveData` | `void restoreSaveData(Map<String, dynamic> data)` | Restores custom save game variables from the supplied map. |

### `class LuminaActor`

Base class for all entities/objects that can be spawned or placed in a [LuminaWorld].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rootComponent` | `final LuminaSceneComponent rootComponent` | Holds the `rootComponent` property or configuration state. |
| `owningLevel` | `LuminaLevel? owningLevel` | Holds the `owningLevel` property or configuration state. |
| `bSaveGame` | `bool bSaveGame` | Whether this actor should be persisted when saving the world state. |
| `saveId` | `String get saveId` | Stable unique identifier for this actor across save/load sessions. |
| `world` | `LuminaWorld? get world` | The world instance this actor is active in. |
| `isRegistered` | `bool get isRegistered` | Whether this actor has been explicitly registered with a world. |
| `isInitialized` | `bool get isInitialized` | Checks current state or capability and returns a boolean value. |
| `hasBegunPlay` | `bool get hasBegunPlay` | Checks current state or capability and returns a boolean value. |
| `components` | `List<LuminaActorComponent> get components` | Getter accessor returning the current value of `components`. |
| `actorLocation` | `Vector3 get actorLocation` | Getter accessor returning the current value of `actorLocation`. |
| `actorLocation` | `actorLocation(Vector3 v)` | Executes `actorLocation` operation. |
| `actorRotation` | `Quaternion get actorRotation` | Getter accessor returning the current value of `actorRotation`. |
| `actorRotation` | `actorRotation(Quaternion q)` | Executes `actorRotation` operation. |
| `actorScale` | `Vector3 get actorScale` | Getter accessor returning the current value of `actorScale`. |
| `actorScale` | `actorScale(Vector3 v)` | Executes `actorScale` operation. |
| `addComponent` | `void addComponent(LuminaActorComponent component)` | Adds a component to this actor. |
| `hiddenInGame` | `bool hiddenInGame` (also a constructor parameter) | Hides every scene component of the actor, the ones added later too; a level actor hidden in the editor's outliner (itself or through a folder) is spawned with it set by the generated level and by Play in Editor. |
| `removeComponent` | `void removeComponent(LuminaActorComponent component)` | Removes a component from this actor. |
| `onRegister` | `void onRegister(LuminaWorld world)` | Called when spawned or registered in a world. |
| `onInitialize` | `void onInitialize()` | Called after registration to initialize components. |
| `onBeginPlay` | `void onBeginPlay()` | Called when play begins. |
| `onTick` | `void onTick(double deltaTime)` | Called on every frame tick update. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Called during post-physics render prep phase. |
| `onUnregister` | `void onUnregister()` | Called when actor is destroyed or level unloads. |
| `isDestroyed` | `bool get isDestroyed` | True if this actor has been removed from the world or is pending kill. |
| `destroy` | `void destroy()` | Requests the world to destroy this actor. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/object/character.dart`

### `class LuminaCharacter`

Character pawn class equipped with capsule collision, movement component, and mesh.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `capsuleComponent` | `final LuminaCapsuleComponent capsuleComponent` | Holds the `capsuleComponent` property or configuration state. |
| `characterMovement` | `final LuminaCharacterMovementComponent characterMovement` | Holds the `characterMovement` property or configuration state. |
| `meshComponent` | `final LuminaSkinnedMeshComponent meshComponent` | Holds the `meshComponent` property or configuration state. |
| `jump` | `void jump()` | Executes `jump` operation. |

## `lib/src/object/pawn.dart`

### `class LuminaPawn`

Base class for actors that can be possessed by a [LuminaController] (Player or AI).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `controller` | `LuminaController? get controller` | Getter accessor returning the current value of `controller`. |
| `isPawnControlled` | `bool isPawnControlled()` | Returns whether this pawn is currently controlled by an active controller. |
| `isPlayerControlled` | `bool isPlayerControlled()` | Returns whether this pawn is controlled by a human player. |
| `isBotControlled` | `bool isBotControlled() => _controller != null && !isPlayerControlled()` | Returns whether this pawn is controlled by AI. |
| `addOnPossessed` | `void addOnPossessed(void Function(LuminaController) listener)` | Adds a listener callback invoked when this pawn is possessed by a controller. |
| `removeOnPossessed` | `void removeOnPossessed(void Function(LuminaController) listener)` | Removes a possession listener callback. |
| `addOnUnpossessed` | `void addOnUnpossessed(void Function(LuminaController) listener)` | Adds a listener callback invoked when this pawn is unpossessed. |
| `removeOnUnpossessed` | `void removeOnUnpossessed(void Function(LuminaController) listener)` | Removes an unpossession listener callback. |
| `restart` | `void restart()` | Resets transient movement and state on each new possession. |
| `possessedBy` | `void possessedBy(LuminaController newController)` | Called when possessed by a controller. |
| `unpossessed` | `void unpossessed()` | Called when unpossessed. |
| `setupPlayerInputComponent` | `void setupPlayerInputComponent(LuminaPlayerComponent playerInput)` | Hook for setting up input bindings on the player component. |
| `addMovementInput` | `void addMovementInput(Vector3 worldDirection, double scale)` | Adds movement input along a world direction vector without per-call normalization. |
| `getPendingMovementInputVector` | `Vector3 getPendingMovementInputVector() => _pendingMovementInput.clone()` | Returns a defensive copy of currently pending accumulated input. |
| `getLastMovementInputVector` | `Vector3 getLastMovementInputVector() => _lastMovementInput.clone()` | Returns a defensive copy of input consumed in the last frame. |
| `consumeMovementInputVector` | `Vector3 consumeMovementInputVector()` | Consumes and returns accumulated input vector, resetting pending input. |
| `addControllerPitchInput` | `void addControllerPitchInput(double v)` | Forwards pitch input in degrees to the controlling controller. |
| `addControllerYawInput` | `void addControllerYawInput(double v)` | Forwards yaw input in degrees to the controlling controller. |
| `addControllerRollInput` | `void addControllerRollInput(double v)` | Forwards roll input in degrees to the controlling controller. |
| `faceRotation` | `void faceRotation(Vector3 controlRotation, double deltaTime)` | Updates actor rotation towards control rotation per enabled axis flag. |
| `getPawnViewLocation` | `Vector3 getPawnViewLocation()` | Returns the eye location of this pawn for camera tracking. |
| `getViewRotation` | `Vector3 getViewRotation()` | Returns the view rotation in (pitch, yaw, roll) degrees. |

---

[Previous: World, levels and streaming](world.md) | [Up: lumina (engine core)](index.md) | [Next: Controllers](controller.md)
