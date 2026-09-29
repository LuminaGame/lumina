[English](../../en/lumina/save.md)

# Kayıt (save game)

Oyun ilerlemesinin kalıcı hale getirilmesi: save game nesnesi ve dünya durumunun anlık görüntüsünü alıp geri yükleyen save game subsystem'i. Dosya yolları `lumina/` paket dizinine görelidir.

## `lib/src/save/save_game.dart`

### `class LuminaSaveGame`

Base save game object containing player state, level name, and serialized data.

**Yapıcı Metotlar (Constructors):**
- `LuminaSaveGame.fromJson(Map<String, dynamic> json)`: `LuminaSaveGame.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `instantiateFromJson` | `static LuminaSaveGame instantiateFromJson(Map<String, dynamic> json)` | Instantiates a registered [LuminaSaveGame] subclass from [json] or falls back to base class. |
| `saveSlotName` | `String saveSlotName` | `saveSlotName` alanını (field/property) ve ilişkili veriyi saklar. |
| `userIndex` | `int userIndex` | `userIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `saveTimestamp` | `DateTime saveTimestamp` | `saveTimestamp` alanını (field/property) ve ilişkili veriyi saklar. |
| `currentLevelName` | `String currentLevelName` | `currentLevelName` alanını (field/property) ve ilişkili veriyi saklar. |
| `playerLocation` | `Vector3 playerLocation` | `playerLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `playerRotation` | `Quaternion playerRotation` | `playerRotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `customSaveData` | `Map<String, dynamic> customSaveData` | `customSaveData` alanını (field/property) ve ilişkili veriyi saklar. |
| `saveGameVersion` | `int saveGameVersion` | `saveGameVersion` alanını (field/property) ve ilişkili veriyi saklar. |
| `saveGameClassName` | `String get saveGameClassName` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `serialize` | `String serialize() => jsonEncode(toJson())` | `serialize` işlemini gerçekleştirir. |
| `deserialize` | `static LuminaSaveGame deserialize(String rawJson)` | `deserialize` işlemini gerçekleştirir. |
| `serializeBinary` | `Uint8List serializeBinary()` | `serializeBinary` işlemini gerçekleştirir. |
| `deserializeBinary` | `static LuminaSaveGame deserializeBinary(Uint8List bytes)` | `deserializeBinary` işlemini gerçekleştirir. |

## `lib/src/save/save_game_subsystem.dart`

### `class LuminaSaveResult`

Represents the structured result of an asynchronous save operation.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `success` | `bool success` | `success` alanını (field/property) ve ilişkili veriyi saklar. |
| `error` | `Object? error` | `error` alanını (field/property) ve ilişkili veriyi saklar. |
| `filePath` | `String? filePath` | `filePath` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaSaveCorruptException`

Thrown when an existing save file on disk contains corrupted or unparseable data.

**Yapıcı Metotlar (Constructors):**
- `LuminaSaveCorruptException(this.message, [this.cause])`: `LuminaSaveCorruptException(this.message, [this.cause])` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `cause` | `Object? cause` | `cause` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaActorRecord`

Serialized representation of a single actor and its persistent components.

**Yapıcı Metotlar (Constructors):**
- `LuminaActorRecord.fromJson(Map<String, dynamic> json)`: `LuminaActorRecord.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `saveId` | `String saveId` | `saveId` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorClassName` | `String actorClassName` | `actorClassName` alanını (field/property) ve ilişkili veriyi saklar. |
| `location` | `List<double> location` | `location` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double> rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `customData` | `Map<String, dynamic> customData` | `customData` alanını (field/property) ve ilişkili veriyi saklar. |
| `componentData` | `Map<String, Map<String, dynamic>> componentData` | `componentData` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class LuminaWorldStateSnapshot`

Snapshot of entire world state including actors and data layers.

**Yapıcı Metotlar (Constructors):**
- `LuminaWorldStateSnapshot.fromJson(Map<String, dynamic> json)`: `LuminaWorldStateSnapshot.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `levelName` | `String levelName` | `levelName` alanını (field/property) ve ilişkili veriyi saklar. |
| `actors` | `List<LuminaActorRecord> actors` | `actors` alanını (field/property) ve ilişkili veriyi saklar. |
| `dataLayerStates` | `Map<String, String> dataLayerStates` | `dataLayerStates` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class LuminaRestoreReport`

Report summarizing the results of restoring a world state.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `restored` | `int restored` | `restored` alanını (field/property) ve ilişkili veriyi saklar. |
| `spawned` | `int spawned` | `spawned` alanını (field/property) ve ilişkili veriyi saklar. |
| `missingIds` | `List<String> missingIds` | `missingIds` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaSaveGameSubsystem`

Subsystem managing asynchronous Game Save & Load operations on disk with atomic write protection.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `saveDirectoryPath` | `String saveDirectoryPath` | `saveDirectoryPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `onWorldInitialize` | `void onWorldInitialize(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `captureWorldState` | `LuminaWorldStateSnapshot captureWorldState()` | Captures all actors and components marked with [bSaveGame = true] across active world levels. |
| `restoreWorldState` | `Future<LuminaRestoreReport> restoreWorldState(LuminaWorldStateSnapshot s...` | Restores a [LuminaWorldStateSnapshot] onto the live world. |
| `loadGameFromSlotAsync` | `Future<LuminaSaveGame?> loadGameFromSlotAsync(String slotName, int userI...` | Asynchronously loads a [LuminaSaveGame] object from a designated slot file. |
| `doesSaveGameExist` | `Future<bool> doesSaveGameExist(String slotName, int userIndex)` | Checks if a final save slot file exists on disk. |
| `deleteSaveSlot` | `Future<bool> deleteSaveSlot(String slotName, int userIndex)` | Deletes a save slot file and any orphaned temporary file. |

---

[Önceki: Oyun arayüzü widget'ları (UMG runtime)](umg.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Blueprint'ler](blueprint/index.md)
