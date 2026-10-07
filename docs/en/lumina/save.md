[Türkçe](../../tr/lumina/save.md)

# Save games

Persisting game progress: the save game object and the save game subsystem that snapshots and restores world state. File paths are relative to the `lumina/` package directory.

## `lib/src/save/save_game.dart`

### `class LuminaSaveGame`

Base save game object containing player state, level name, and serialized data.

**Constructors:**
- `LuminaSaveGame.fromJson(Map<String, dynamic> json)`: Initializes `LuminaSaveGame.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `instantiateFromJson` | `static LuminaSaveGame instantiateFromJson(Map<String, dynamic> json)` | Instantiates a registered [LuminaSaveGame] subclass from [json] or falls back to base class. |
| `saveSlotName` | `String saveSlotName` | Holds the `saveSlotName` property or configuration state. |
| `userIndex` | `int userIndex` | Holds the `userIndex` property or configuration state. |
| `saveTimestamp` | `DateTime saveTimestamp` | Holds the `saveTimestamp` property or configuration state. |
| `currentLevelName` | `String currentLevelName` | Holds the `currentLevelName` property or configuration state. |
| `playerLocation` | `Vector3 playerLocation` | Holds the `playerLocation` property or configuration state. |
| `playerRotation` | `Quaternion playerRotation` | Holds the `playerRotation` property or configuration state. |
| `customSaveData` | `Map<String, dynamic> customSaveData` | Holds the `customSaveData` property or configuration state. |
| `saveGameVersion` | `int saveGameVersion` | Holds the `saveGameVersion` property or configuration state. |
| `saveGameClassName` | `String get saveGameClassName` | Serializes and writes the current state or asset to disk. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `serialize` | `String serialize() => jsonEncode(toJson())` | Executes `serialize` operation. |
| `deserialize` | `static LuminaSaveGame deserialize(String rawJson)` | Executes `deserialize` operation. |
| `serializeBinary` | `Uint8List serializeBinary()` | Executes `serializeBinary` operation. |
| `deserializeBinary` | `static LuminaSaveGame deserializeBinary(Uint8List bytes)` | Executes `deserializeBinary` operation. |

## `lib/src/save/save_game_subsystem.dart`

### `class LuminaSaveResult`

Represents the structured result of an asynchronous save operation.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `success` | `bool success` | Holds the `success` property or configuration state. |
| `error` | `Object? error` | Holds the `error` property or configuration state. |
| `filePath` | `String? filePath` | Holds the `filePath` property or configuration state. |

### `class LuminaSaveCorruptException`

Thrown when an existing save file on disk contains corrupted or unparseable data.

**Constructors:**
- `LuminaSaveCorruptException(this.message, [this.cause])`: Initializes `LuminaSaveCorruptException(this.message, [this.cause])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `cause` | `Object? cause` | Holds the `cause` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class LuminaActorRecord`

Serialized representation of a single actor and its persistent components.

**Constructors:**
- `LuminaActorRecord.fromJson(Map<String, dynamic> json)`: Initializes `LuminaActorRecord.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `saveId` | `String saveId` | Holds the `saveId` property or configuration state. |
| `actorClassName` | `String actorClassName` | Holds the `actorClassName` property or configuration state. |
| `location` | `List<double> location` | Holds the `location` property or configuration state. |
| `rotation` | `List<double> rotation` | Holds the `rotation` property or configuration state. |
| `customData` | `Map<String, dynamic> customData` | Holds the `customData` property or configuration state. |
| `componentData` | `Map<String, Map<String, dynamic>> componentData` | Holds the `componentData` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class LuminaWorldStateSnapshot`

Snapshot of entire world state including actors and data layers.

**Constructors:**
- `LuminaWorldStateSnapshot.fromJson(Map<String, dynamic> json)`: Initializes `LuminaWorldStateSnapshot.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `levelName` | `String levelName` | Holds the `levelName` property or configuration state. |
| `actors` | `List<LuminaActorRecord> actors` | Holds the `actors` property or configuration state. |
| `dataLayerStates` | `Map<String, String> dataLayerStates` | Holds the `dataLayerStates` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class LuminaRestoreReport`

Report summarizing the results of restoring a world state.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `restored` | `int restored` | Holds the `restored` property or configuration state. |
| `spawned` | `int spawned` | Holds the `spawned` property or configuration state. |
| `missingIds` | `List<String> missingIds` | Holds the `missingIds` property or configuration state. |

### `class LuminaSaveGameSubsystem`

Subsystem managing asynchronous Game Save & Load operations on disk with atomic write protection.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `saveDirectoryPath` | `String saveDirectoryPath` | Holds the `saveDirectoryPath` property or configuration state. |
| `onWorldInitialize` | `void onWorldInitialize(LuminaWorld world)` | Callback invoked when the corresponding event is triggered. |
| `captureWorldState` | `LuminaWorldStateSnapshot captureWorldState()` | Captures all actors and components marked with [bSaveGame = true] across active world levels. |
| `restoreWorldState` | `Future<LuminaRestoreReport> restoreWorldState(LuminaWorldStateSnapshot s...` | Restores a [LuminaWorldStateSnapshot] onto the live world. |
| `loadGameFromSlotAsync` | `Future<LuminaSaveGame?> loadGameFromSlotAsync(String slotName, int userI...` | Asynchronously loads a [LuminaSaveGame] object from a designated slot file. |
| `doesSaveGameExist` | `Future<bool> doesSaveGameExist(String slotName, int userIndex)` | Checks if a final save slot file exists on disk. |
| `deleteSaveSlot` | `Future<bool> deleteSaveSlot(String slotName, int userIndex)` | Deletes a save slot file and any orphaned temporary file. |

---

[Previous: User widgets](user-widgets.md) | [Up: lumina (engine core)](index.md) | [Next: Blueprints](blueprint/index.md)
