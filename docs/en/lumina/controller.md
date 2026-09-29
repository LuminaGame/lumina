[Türkçe](../../tr/lumina/controller.md)

# Controllers

Controllers possess pawns and drive them: the base controller, the player controller that routes player input, and the player state that carries per-player data. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/controller/controller.dart`](#libsrccontrollercontrollerdart)
- [`lib/src/controller/player_controller.dart`](#libsrccontrollerplayer_controllerdart)
- [`lib/src/controller/player_state.dart`](#libsrccontrollerplayer_statedart)

## `lib/src/controller/controller.dart`

### `class LuminaController`

Abstract controller base class that can possess and manage a [LuminaPawn].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pawn` | `LuminaPawn? get pawn` | Getter accessor returning the current value of `pawn`. |
| `controlRotation` | `Vector3 get controlRotation` | Getter accessor returning the current value of `controlRotation`. |
| `controlRotation` | `controlRotation(Vector3 rot)` | Executes `controlRotation` operation. |
| `possess` | `void possess(LuminaPawn pawnToPossess)` | Possesses the specified [pawnToPossess]. |
| `unpossess` | `void unpossess()` | Unpossesses the current pawn. |
| `onPossess` | `void onPossess(LuminaPawn pawn)` | Callback invoked when the corresponding event is triggered. |
| `onUnpossess` | `void onUnpossess(LuminaPawn pawn)` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/controller/player_controller.dart`

### `class LuminaPlayerController`

Player controller that handles human player input and state.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `playerState` | `LuminaPlayerState playerState` | Holds the `playerState` property or configuration state. |
| `cameraManager` | `final LuminaPlayerCameraManager cameraManager` | Holds the `cameraManager` property or configuration state. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/controller/player_state.dart`

### `class LuminaPlayerState`

Represents player state data (score, team, name, health, etc.) with change notification.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `resetPlayerIdCounterForTesting` | `static void resetPlayerIdCounterForTesting()` | Resets values or state back to defaults. |
| `playerName` | `String get playerName` | The player's display name. |
| `playerName` | `playerName(String v)` | Executes `playerName` operation. |
| `playerId` | `int get playerId` | Unique player ID (immutable). |
| `score` | `double get score` | Player's score. |
| `score` | `score(double v)` | Executes `score` operation. |
| `addScore` | `void addScore(double delta)` | Adds [delta] to score and notifies listeners. |
| `teamId` | `int get teamId` | Player's team ID. |
| `teamId` | `teamId(int v)` | Executes `teamId` operation. |
| `health` | `double get health` | Player's current health, clamped to >= 0. |
| `health` | `health(double v)` | Executes `health` operation. |
| `isAlive` | `bool get isAlive` | Whether the player is currently alive (health > 0). |
| `addListener` | `void addListener(void Function() listener) => _listeners.add(listener)` | Adds a listener callback invoked when any property changes. |
| `removeListener` | `void removeListener(void Function() listener) => _listeners.remove(liste...` | Removes a listener callback. |
| `notifyChanged` | `void notifyChanged()` | Notifies all registered listeners of a state change. |
| `reset` | `void reset()` | Restores score to 0.0 and health to 100.0, firing a single notification if changed. |

---

[Previous: Actors, pawns and characters](object.md) | [Up: lumina (engine core)](index.md) | [Next: Components: base, movement, camera, light, audio, collision](components-core.md)
