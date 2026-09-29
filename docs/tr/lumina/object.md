[English](../../en/lumina/object.md)

# Actor'ler, pawn'lar ve character'lar

Runtime nesne hiyerarşisi: dünyaya yerleştirilen her şeyin temeli olan `LuminaActor`, bir controller'ın possess edebildiği actor olan `LuminaPawn` ve capsule ile character movement'a sahip bir pawn olan `LuminaCharacter`, ayrıca `LuminaSaveable` mixin'i. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/object/actor.dart`](#libsrcobjectactordart)
- [`lib/src/object/character.dart`](#libsrcobjectcharacterdart)
- [`lib/src/object/pawn.dart`](#libsrcobjectpawndart)

## `lib/src/object/actor.dart`

### `mixin LuminaSaveable`

Mixin defining serialization hooks for persistent actors and components.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `captureSaveData` | `Map<String, dynamic> captureSaveData()` | Captures custom save game variables into a JSON-encodable map. |
| `restoreSaveData` | `void restoreSaveData(Map<String, dynamic> data)` | Restores custom save game variables from the supplied map. |

### `class LuminaActor`

Base class for all entities/objects that can be spawned or placed in a [LuminaWorld].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rootComponent` | `final LuminaSceneComponent rootComponent` | `rootComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `owningLevel` | `LuminaLevel? owningLevel` | `owningLevel` alanını (field/property) ve ilişkili veriyi saklar. |
| `bSaveGame` | `bool bSaveGame` | Whether this actor should be persisted when saving the world state. |
| `saveId` | `String get saveId` | Stable unique identifier for this actor across save/load sessions. |
| `world` | `LuminaWorld? get world` | The world instance this actor is active in. |
| `isRegistered` | `bool get isRegistered` | Whether this actor has been explicitly registered with a world. |
| `isInitialized` | `bool get isInitialized` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasBegunPlay` | `bool get hasBegunPlay` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `components` | `List<LuminaActorComponent> get components` | `components` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `actorLocation` | `Vector3 get actorLocation` | `actorLocation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `actorLocation` | `actorLocation(Vector3 v)` | `actorLocation` işlemini gerçekleştirir. |
| `actorRotation` | `Quaternion get actorRotation` | `actorRotation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `actorRotation` | `actorRotation(Quaternion q)` | `actorRotation` işlemini gerçekleştirir. |
| `actorScale` | `Vector3 get actorScale` | `actorScale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `actorScale` | `actorScale(Vector3 v)` | `actorScale` işlemini gerçekleştirir. |
| `addComponent` | `void addComponent(LuminaActorComponent component)` | Adds a component to this actor. |
| `removeComponent` | `void removeComponent(LuminaActorComponent component)` | Removes a component from this actor. |
| `onRegister` | `void onRegister(LuminaWorld world)` | Called when spawned or registered in a world. |
| `onInitialize` | `void onInitialize()` | Called after registration to initialize components. |
| `onBeginPlay` | `void onBeginPlay()` | Called when play begins. |
| `onTick` | `void onTick(double deltaTime)` | Called on every frame tick update. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Called during post-physics render prep phase. |
| `onUnregister` | `void onUnregister()` | Called when actor is destroyed or level unloads. |
| `isDestroyed` | `bool get isDestroyed` | True if this actor has been removed from the world or is pending kill. |
| `destroy` | `void destroy()` | Requests the world to destroy this actor. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/object/character.dart`

### `class LuminaCharacter`

Character pawn class equipped with capsule collision, movement component, and mesh.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `capsuleComponent` | `final LuminaCapsuleComponent capsuleComponent` | `capsuleComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `characterMovement` | `final LuminaCharacterMovementComponent characterMovement` | `characterMovement` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshComponent` | `final LuminaSkinnedMeshComponent meshComponent` | `meshComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `jump` | `void jump()` | `jump` işlemini gerçekleştirir. |

## `lib/src/object/pawn.dart`

### `class LuminaPawn`

Base class for actors that can be possessed by a [LuminaController] (Player or AI).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `controller` | `LuminaController? get controller` | `controller` özelliğinin anlık değerini okuyan getter erişimcisi. |
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

[Önceki: Dünya, level'lar ve streaming](world.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Controller'lar](controller.md)
