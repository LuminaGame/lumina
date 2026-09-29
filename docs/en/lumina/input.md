[Türkçe](../../tr/lumina/input.md)

# Input

The action-based input system: input actions and their values, mapping contexts that bind keys to actions, the input subsystem and component, and the modifiers (dead zone, negate, scalar, response curve) and triggers (pressed, released, hold, tap, pulse) that shape raw input. File paths are relative to the `lumina/` package directory.

**On this page:**

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

**Constructors:**
- `LuminaInputActionValue.bool(bool v)`: Initializes `LuminaInputActionValue.bool(bool v)`.
- `LuminaInputActionValue.axis1D(double v)`: Initializes `LuminaInputActionValue.axis1D(double v)`.
- `LuminaInputActionValue.axis2D(Vector2 v)`: Initializes `LuminaInputActionValue.axis2D(Vector2 v)`.
- `LuminaInputActionValue.axis3D(Vector3 v)`: Initializes `LuminaInputActionValue.axis3D(Vector3 v)`.
- `LuminaInputActionValue.raw(this.type, this._x, this._y, this._z)`: Initializes `LuminaInputActionValue.raw(this.type, this._x, this._y, this._z)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `type` | `InputValueType type` | Holds the `type` property or configuration state. |
| `asBool` | `bool get asBool` | Getter accessor returning the current value of `asBool`. |
| `asAxis1D` | `double get asAxis1D` | Getter accessor returning the current value of `asAxis1D`. |
| `asAxis2D` | `Vector2 get asAxis2D` | Getter accessor returning the current value of `asAxis2D`. |
| `asAxis3D` | `Vector3 get asAxis3D` | Getter accessor returning the current value of `asAxis3D`. |
| `magnitude` | `double get magnitude` | Getter accessor returning the current value of `magnitude`. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class LuminaInputAction`

Represents an abstract Input Action.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `valueType` | `InputValueType valueType` | Holds the `valueType` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

## `lib/src/input/input_component.dart`

### `class _ContextStackEntry`

`_ContextStackEntry`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_ContextStackEntry(this.context, this.priority)`: Initializes `_ContextStackEntry(this.context, this.priority)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `context` | `LuminaInputMappingContext context` | Holds the `context` property or configuration state. |
| `priority` | `int priority` | Holds the `priority` property or configuration state. |

### `class LuminaInputSubsystem`

Global world subsystem that manages mapping contexts, input injection, modifiers, triggers, and priority resolution.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `removeMappingContext` | `void removeMappingContext(LuminaInputMappingContext imc)` | Removes a mapping context from the priority stack and resets its triggers. |
| `registerComponent` | `void registerComponent(LuminaInputComponent component)` | Registers an input component to receive dispatched events. |
| `unregisterComponent` | `void unregisterComponent(LuminaInputComponent component)` | Unregisters an input component. |
| `injectKeyDown` | `void injectKeyDown(LuminaKey key)` | Injects a digital key press event. |
| `injectKeyUp` | `void injectKeyUp(LuminaKey key)` | Injects a digital key release event. |
| `injectAnalog` | `void injectAnalog(LuminaKey key, double value)` | Injects an analog axis delta or value. |
| `tick` | `void tick(double deltaTime)` | Resolves all actuated inputs through contexts, modifiers, and triggers, dispatching events to components. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onWorldShutdown` | `void onWorldShutdown()` | Callback invoked when the corresponding event is triggered. |

### `class LuminaInputComponent`

Component attached to actors for receiving and processing enhanced input signals.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispatch` | `void dispatch(LuminaInputAction action, TriggerState event, LuminaInputA...` | Dispatches an action event to registered callbacks. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/input/input_key.dart`

### `class LuminaKey`

Represents a physical or virtual input hardware key / axis.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `isAnalog` | `bool isAnalog` | Holds the `isAnalog` property or configuration state. |
| `identical` | `identical(this, other) \|\| (other is LuminaKey && other.id == id)` | Executes `identical` operation. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

## `lib/src/input/input_mapping_context.dart`

### `class LuminaActionKeyMapping`

Represents a mapping between an input key and an input action with optional modifiers and triggers.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `key` | `LuminaKey key` | Holds the `key` property or configuration state. |
| `action` | `LuminaInputAction action` | Holds the `action` property or configuration state. |
| `modifiers` | `List<LuminaInputModifier> modifiers` | Holds the `modifiers` property or configuration state. |
| `triggers` | `List<LuminaInputTrigger> triggers` | Holds the `triggers` property or configuration state. |

### `class LuminaInputMappingContext`

Context containing a set of key-to-action mappings.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mappings` | `List<LuminaActionKeyMapping> get mappings` | All mappings registered in this context. |
| `unmapKey` | `void unmapKey(LuminaKey key, LuminaInputAction action)` | Unmaps all mappings between [key] and [action]. |
| `mappingsForKey` | `List<LuminaActionKeyMapping> mappingsForKey(LuminaKey key)` | Returns all mappings registered for [key]. |

## `lib/src/input/input_modifier.dart`

### `class LuminaInputModifier`

Base class for input modifiers that transform raw action values.

**Constructors:**
- `LuminaInputModifier()`: Initializes `LuminaInputModifier()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Modifies [rawValue] and returns the transformed value. |

### `enum DeadZoneType`

Type of dead zone evaluation.

### `class LuminaDeadZoneModifier`

Modifies an input value by applying a dead zone threshold and rescaling.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `lowerThreshold` | `double lowerThreshold` | Holds the `lowerThreshold` property or configuration state. |
| `upperThreshold` | `double upperThreshold` | Holds the `upperThreshold` property or configuration state. |
| `type` | `DeadZoneType type` | Holds the `type` property or configuration state. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Executes `modify` operation. |

### `class LuminaNegateModifier`

Inverts selected axes of an input value.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `bool x` | Holds the `x` property or configuration state. |
| `y` | `bool y` | Holds the `y` property or configuration state. |
| `z` | `bool z` | Holds the `z` property or configuration state. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Executes `modify` operation. |

### `class LuminaScalarModifier`

Multiplies axes of an input value by scalar factors.

**Constructors:**
- `LuminaScalarModifier.uniform(double s) : scalar = Vector3(s, s, s)`: Initializes `LuminaScalarModifier.uniform(double s) : scalar = Vector3(s, s, s)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `scalar` | `Vector3 scalar` | Holds the `scalar` property or configuration state. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Executes `modify` operation. |

### `class LuminaResponseCurveModifier`

Shapes input sensitivity using an exponential response curve.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `exponent` | `double exponent` | Holds the `exponent` property or configuration state. |
| `modify` | `LuminaInputActionValue modify(LuminaInputActionValue rawValue, double de...` | Executes `modify` operation. |

## `lib/src/input/input_trigger.dart`

### `enum TriggerEvaluation`

Per-trigger evaluation state for a single frame.

### `class LuminaInputTrigger`

Base class for input triggers that evaluate action activation conditions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actuationThreshold` | `double actuationThreshold` | Holds the `actuationThreshold` property or configuration state. |
| `isActuated` | `bool isActuated(LuminaInputActionValue v)` | Returns true if [v] magnitude exceeds [actuationThreshold]. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates and returns the trigger evaluation for this frame. |
| `reset` | `void reset()` | Resets internal state and timers. |

### `class LuminaPressedTrigger`

Triggers on the initial actuation frame (press).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates the current state or data values. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

### `class LuminaReleasedTrigger`

Triggers when actuation ceases (release).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates the current state or data values. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

### `class LuminaHoldTrigger`

Triggers after an actuation is held for [holdTimeThreshold] seconds.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `holdTimeThreshold` | `double holdTimeThreshold` | Holds the `holdTimeThreshold` property or configuration state. |
| `isOneShot` | `bool isOneShot` | Holds the `isOneShot` property or configuration state. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates the current state or data values. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

### `class LuminaTapTrigger`

Triggers only when quickly pressed and released before [tapReleaseTimeThreshold] seconds.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `tapReleaseTimeThreshold` | `double tapReleaseTimeThreshold` | Holds the `tapReleaseTimeThreshold` property or configuration state. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates the current state or data values. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

### `class LuminaPulseTrigger`

Triggers repeatedly at [interval] seconds while held.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `interval` | `double interval` | Holds the `interval` property or configuration state. |
| `triggerOnStart` | `bool triggerOnStart` | Holds the `triggerOnStart` property or configuration state. |
| `update` | `TriggerEvaluation update(LuminaInputActionValue value, double deltaTime)` | Updates the current state or data values. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

---

[Previous: Components: environment and landscape](components-environment-and-landscape.md) | [Up: lumina (engine core)](index.md) | [Next: Animation](animation.md)
