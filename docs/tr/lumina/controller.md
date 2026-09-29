[English](../../en/lumina/controller.md)

# Controller'lar

Controller'lar pawn'ları possess eder ve yönetir: temel controller, oyuncu girdisini yönlendiren player controller ve oyuncuya ait verileri taşıyan player state. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/controller/controller.dart`](#libsrccontrollercontrollerdart)
- [`lib/src/controller/player_controller.dart`](#libsrccontrollerplayer_controllerdart)
- [`lib/src/controller/player_state.dart`](#libsrccontrollerplayer_statedart)

## `lib/src/controller/controller.dart`

### `class LuminaController`

Abstract controller base class that can possess and manage a [LuminaPawn].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pawn` | `LuminaPawn? get pawn` | `pawn` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `controlRotation` | `Vector3 get controlRotation` | `controlRotation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `controlRotation` | `controlRotation(Vector3 rot)` | `controlRotation` işlemini gerçekleştirir. |
| `possess` | `void possess(LuminaPawn pawnToPossess)` | Possesses the specified [pawnToPossess]. |
| `unpossess` | `void unpossess()` | Unpossesses the current pawn. |
| `onPossess` | `void onPossess(LuminaPawn pawn)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnpossess` | `void onUnpossess(LuminaPawn pawn)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/controller/player_controller.dart`

### `class LuminaPlayerController`

Player controller that handles human player input and state.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `playerState` | `LuminaPlayerState playerState` | `playerState` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraManager` | `final LuminaPlayerCameraManager cameraManager` | `cameraManager` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/controller/player_state.dart`

### `class LuminaPlayerState`

Represents player state data (score, team, name, health, etc.) with change notification.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `resetPlayerIdCounterForTesting` | `static void resetPlayerIdCounterForTesting()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `playerName` | `String get playerName` | The player's display name. |
| `playerName` | `playerName(String v)` | `playerName` işlemini gerçekleştirir. |
| `playerId` | `int get playerId` | Unique player ID (immutable). |
| `score` | `double get score` | Player's score. |
| `score` | `score(double v)` | `score` işlemini gerçekleştirir. |
| `addScore` | `void addScore(double delta)` | Adds [delta] to score and notifies listeners. |
| `teamId` | `int get teamId` | Player's team ID. |
| `teamId` | `teamId(int v)` | `teamId` işlemini gerçekleştirir. |
| `health` | `double get health` | Player's current health, clamped to >= 0. |
| `health` | `health(double v)` | `health` işlemini gerçekleştirir. |
| `isAlive` | `bool get isAlive` | Whether the player is currently alive (health > 0). |
| `addListener` | `void addListener(void Function() listener) => _listeners.add(listener)` | Adds a listener callback invoked when any property changes. |
| `removeListener` | `void removeListener(void Function() listener) => _listeners.remove(liste...` | Removes a listener callback. |
| `notifyChanged` | `void notifyChanged()` | Notifies all registered listeners of a state change. |
| `reset` | `void reset()` | Restores score to 0.0 and health to 100.0, firing a single notification if changed. |

---

[Önceki: Actor'ler, pawn'lar ve character'lar](object.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Bileşenler: temel, hareket, kamera, ışık, ses, çarpışma](components-core.md)
