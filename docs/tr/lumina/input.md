[English](../../en/lumina/input.md)

# Girdi (input)

Action tabanlı input sistemi: input action'lar ve değerleri, tuşları action'lara bağlayan mapping context'ler, input subsystem ve component ile ham girdiyi şekillendiren modifier'lar (dead zone, negate, scalar, response curve) ve trigger'lar (pressed, released, hold, tap, pulse). Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/input/input_action.dart`](#libsrcinputinput_actiondart)
- [`lib/src/input/input_component.dart`](#libsrcinputinput_componentdart)
- [`lib/src/input/input_key.dart`](#libsrcinputinput_keydart)
- [`lib/src/input/input_mapping_context.dart`](#libsrcinputinput_mapping_contextdart)
- [`lib/src/input/input_modifier.dart`](#libsrcinputinput_modifierdart)
- [`lib/src/input/input_trigger.dart`](#libsrcinputinput_triggerdart)

## `lib/src/input/input_action.dart`

### `enum InputValueType`

Value type carried by an input action.

### `enum TriggerState`

Trigger state for input actions and bindings.

### `class LuminaInputActionValue`

Typed input action value supporting implicit type conversions.

**Yapıcı Metotlar (Constructors):**
- `LuminaInputActionValue.bool(bool v)`: `LuminaInputActionValue.bool(bool v)` nesnesini ilklendirir.
- `LuminaInputActionValue.axis1D(double v)`: `LuminaInputActionValue.axis1D(double v)` nesnesini ilklendirir.
- `LuminaInputActionValue.axis2D(Vector2 v)`: `LuminaInputActionValue.axis2D(Vector2 v)` nesnesini ilklendirir.
- `LuminaInputActionValue.axis3D(Vector3 v)`: `LuminaInputActionValue.axis3D(Vector3 v)` nesnesini ilklendirir.
- `LuminaInputActionValue.raw(this.type, this._x, this._y, this._z)`: `LuminaInputActionValue.raw(this.type, this._x, this._y, this._z)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `type` | `InputValueType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `asBool` | `bool get asBool` | `asBool` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `asAxis1D` | `double get asAxis1D` | `asAxis1D` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `asAxis2D` | `Vector2 get asAxis2D` | `asAxis2D` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `asAxis3D` | `Vector3 get asAxis3D` | `asAxis3D` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `magnitude` | `double get magnitude` | `magnitude` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class LuminaInputAction`

Represents an abstract Input Action.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `valueType` | `InputValueType valueType` | `valueType` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

## `lib/src/input/input_component.dart`

### `class _ContextStackEntry`

`_ContextStackEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_ContextStackEntry(this.context, this.priority)`: `_ContextStackEntry(this.context, this.priority)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `context` | `LuminaInputMappingContext context` | `context` alanını (field/property) ve ilişkili veriyi saklar. |
| `priority` | `int priority` | `priority` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaInputSubsystem`

Global world subsystem that manages mapping contexts, input injection, modifiers, triggers, and priority resolution.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `removeMappingContext` | `void removeMappingContext(LuminaInputMappingContext imc)` | Removes a mapping context from the priority stack and resets its triggers. |
| `registerComponent` | `void registerComponent(LuminaInputComponent component)` | Registers an input component to receive dispatched events. |
| `unregisterComponent` | `void unregisterComponent(LuminaInputComponent component)` | Unregisters an input component. |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | Injects a digital key press event. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key)` | Injects a digital key release event. |
| `injectAnalog` | `void injectAnalog(LuminaKey key, double value)` | Injects an analog axis delta or value. |
| `tick` | `void tick(double deltaTime)` | Resolves all actuated inputs through contexts, modifiers, and triggers, dispatching events to components. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onWorldShutdown` | `void onWorldShutdown()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

### `class LuminaInputComponent`

Component attached to actors for receiving and processing enhanced input signals.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispatch` | `void dispatch(LuminaInputAction action, TriggerState event, LuminaInputA...` | Dispatches an action event to registered callbacks. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/input/input_key.dart`

### `class LuminaKey`

Represents a physical or virtual input hardware key / axis.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `isAnalog` | `bool isAnalog` | `isAnalog` alanını (field/property) ve ilişkili veriyi saklar. |
| `identical` | `identical(this, other) \|\| (other is LuminaKey && other.id == id)` | `identical` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

## `lib/src/input/input_mapping_context.dart`

### `class LuminaActionKeyMapping`

Represents a mapping between an input key and an input action with optional modifiers and triggers.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `key` | `LuminaKey key` | `key` alanını (field/property) ve ilişkili veriyi saklar. |
| `action` | `LuminaInputAction action` | `action` alanını (field/property) ve ilişkili veriyi saklar. |
| `modifiers` | `List<LuminaInputModifier> modifiers` | `modifiers` alanını (field/property) ve ilişkili veriyi saklar. |
| `triggers` | `List<LuminaInputTrigger> triggers` | `triggers` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaInputMappingContext`

Context containing a set of key-to-action mappings.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mappings` | `List<LuminaActionKeyMapping> get mappings` | All mappings registered in this context. |
| `unmapKey` | `void unmapKey(LuminaKey key, LuminaInputAction action)` | Unmaps all mappings between [key] and [action]. |
| `mappingsForKey` | `List<LuminaActionKeyMapping> mappingsForKey(LuminaKey key)` | Returns all mappings registered for [key]. |

## `lib/src/input/input_modifier.dart`

### `class LuminaInputModifier`

Base class for input modifiers that transform raw action values.

**Yapıcı Metotlar (Constructors):**
- `LuminaInputModifier()`: `LuminaInputModifier()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Modifies [rawValue] and returns the transformed value. |

### `enum DeadZoneType`

Type of dead zone evaluation.

### `class LuminaDeadZoneModifier`

Modifies an input value by applying a dead zone threshold and rescaling.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `lowerThreshold` | `double lowerThreshold` | `lowerThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `upperThreshold` | `double upperThreshold` | `upperThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `DeadZoneType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | `modify` işlemini gerçekleştirir. |

### `class LuminaNegateModifier`

Inverts selected axes of an input value.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `bool x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `bool y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `bool z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | `modify` işlemini gerçekleştirir. |

### `class LuminaScalarModifier`

Multiplies axes of an input value by scalar factors.

**Yapıcı Metotlar (Constructors):**
- `LuminaScalarModifier.uniform(double s) : scalar = Vector3(s, s, s)`: `LuminaScalarModifier.uniform(double s) : scalar = Vector3(s, s, s)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `scalar` | `Vector3 scalar` | `scalar` alanını (field/property) ve ilişkili veriyi saklar. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | `modify` işlemini gerçekleştirir. |

### `class LuminaResponseCurveModifier`

Shapes input sensitivity using an exponential response curve.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `exponent` | `double exponent` | `exponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | `modify` işlemini gerçekleştirir. |

## `lib/src/input/input_trigger.dart`

### `enum TriggerEvaluation`

Per-trigger evaluation state for a single frame.

### `class LuminaInputTrigger`

Base class for input triggers that evaluate action activation conditions.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actuationThreshold` | `double actuationThreshold` | `actuationThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `isActuated` | `bool isActuated(LuminaInputActionValue v)` | Returns true if [v] magnitude exceeds [actuationThreshold]. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates and returns the trigger evaluation for this frame. |
| `reset` | `void reset()` | Resets internal state and timers. |

### `class LuminaPressedTrigger`

Triggers on the initial actuation frame (press).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Mevcut verileri veya durumu günceller. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

### `class LuminaReleasedTrigger`

Triggers when actuation ceases (release).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Mevcut verileri veya durumu günceller. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

### `class LuminaHoldTrigger`

Triggers after an actuation is held for [holdTimeThreshold] seconds.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `holdTimeThreshold` | `double holdTimeThreshold` | `holdTimeThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `isOneShot` | `bool isOneShot` | `isOneShot` alanını (field/property) ve ilişkili veriyi saklar. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Mevcut verileri veya durumu günceller. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

### `class LuminaTapTrigger`

Triggers only when quickly pressed and released before [tapReleaseTimeThreshold] seconds.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tapReleaseTimeThreshold` | `double tapReleaseTimeThreshold` | `tapReleaseTimeThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Mevcut verileri veya durumu günceller. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

### `class LuminaPulseTrigger`

Triggers repeatedly at [interval] seconds while held.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `interval` | `double interval` | `interval` alanını (field/property) ve ilişkili veriyi saklar. |
| `triggerOnStart` | `bool triggerOnStart` | `triggerOnStart` alanını (field/property) ve ilişkili veriyi saklar. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Mevcut verileri veya durumu günceller. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

---

[Önceki: Bileşenler: çevre ve landscape](components-environment-and-landscape.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Animasyon](animation.md)
