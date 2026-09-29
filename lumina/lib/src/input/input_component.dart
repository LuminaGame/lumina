import 'package:vector_math/vector_math_64.dart';
import '../components/base/actor_component.dart';
import '../object/actor.dart';
import '../world/subsystem/world_subsystem.dart';
import 'input_action.dart';
import 'input_key.dart';
import 'input_mapping_context.dart';
import 'input_trigger.dart';

export 'input_action.dart';
export 'input_key.dart';
export 'input_modifier.dart';
export 'input_trigger.dart';
export 'input_mapping_context.dart';

class _ContextStackEntry {
  final LuminaInputMappingContext context;
  int priority;

  _ContextStackEntry(this.context, this.priority);
}

/// Global world subsystem that manages mapping contexts, input injection, modifiers, triggers, and priority resolution.
class LuminaInputSubsystem extends LuminaWorldSubsystem {
  final List<_ContextStackEntry> _contextStack = [];
  final Set<LuminaKey> _heldDigitalKeys = {};
  final Map<LuminaKey, double> _pendingAnalogValues = {};
  final List<LuminaInputComponent> _registeredComponents = [];
  final Map<LuminaInputAction, TriggerEvaluation> _lastActionEvaluations = {};
  final Map<LuminaInputAction, LuminaInputActionValue> _lastActionValues = {};

  /// Adds or updates a mapping context in the priority stack.
  void addMappingContext(LuminaInputMappingContext imc, {int priority = 0}) {
    final existingIndex = _contextStack.indexWhere((e) => e.context == imc);
    if (existingIndex != -1) {
      _contextStack[existingIndex].priority = priority;
    } else {
      _contextStack.add(_ContextStackEntry(imc, priority));
    }
    _contextStack.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Removes a mapping context from the priority stack and resets its triggers.
  void removeMappingContext(LuminaInputMappingContext imc) {
    for (final mapping in imc.mappings) {
      for (final trigger in mapping.triggers) {
        trigger.reset();
      }
    }
    _contextStack.removeWhere((e) => e.context == imc);
  }

  /// Registers an input component to receive dispatched events.
  void registerComponent(LuminaInputComponent component) {
    if (!_registeredComponents.contains(component)) {
      _registeredComponents.add(component);
    }
  }

  /// Unregisters an input component.
  void unregisterComponent(LuminaInputComponent component) {
    _registeredComponents.remove(component);
  }

  /// Injects a digital key press event.
  void injectKeyDown(LuminaKey key) {
    if (_heldDigitalKeys.add(key)) {
      _keyDownTimes[key] = 0.0;
      _justPressed.add(key);
    }
    _lastInputDevice = _deviceOf(key);
  }

  /// Injects a digital key release event.
  void injectKeyUp(LuminaKey key) {
    _heldDigitalKeys.remove(key);
    _keyDownTimes.remove(key);
  }

  /// Injects an analog axis delta or value.
  void injectAnalog(LuminaKey key, double value) {
    _pendingAnalogValues[key] = (_pendingAnalogValues[key] ?? 0.0) + value;
    _lastInputDevice = _deviceOf(key);
  }

  // --- Key state queries --------------------------------------

  final Map<LuminaKey, double> _keyDownTimes = {};
  final Set<LuminaKey> _justPressed = {};
  final Set<LuminaKey> _justPressedThisTick = {};
  final Map<LuminaKey, double> _lastAxisValues = {};
  final Vector2 _mousePosition = Vector2.zero();
  String _lastInputDevice = 'Keyboard';

  /// Whether [key] is held.
  bool isKeyDown(LuminaKey key) => _heldDigitalKeys.contains(key);

  /// Seconds [key] has been held across ticks; 0 when it is up.
  double keyDownTime(LuminaKey key) => _keyDownTimes[key] ?? 0.0;

  /// Whether [key] went down since the previous tick (true for exactly one tick).
  bool wasKeyJustPressed(LuminaKey key) => _justPressedThisTick.contains(key);

  /// The analog value [key] carried in the last tick (0 when quiet).
  double axisValue(LuminaKey key) => _lastAxisValues[key] ?? 0.0;

  /// The pointer position in viewport pixels the host last injected.
  Vector2 get mousePosition => _mousePosition.clone();

  void injectMousePosition(Vector2 position) {
    _mousePosition.setFrom(position);
    _lastInputDevice = 'Mouse';
  }

  /// `Keyboard`, `Mouse`, `Gamepad` or `Touch`: the device of the last input.
  String get lastInputDevice => _lastInputDevice;

  static String _deviceOf(LuminaKey key) {
    final id = key.id.toLowerCase();
    if (id.startsWith('mouse')) return 'Mouse';
    if (id.startsWith('gamepad')) return 'Gamepad';
    if (id.startsWith('touch')) return 'Touch';
    return 'Keyboard';
  }

  /// Resolves all actuated inputs through contexts, modifiers, and triggers, dispatching events to components.
  void tick(double deltaTime) {
    // Key state bookkeeping: hold times, this tick's presses, last axis values.
    for (final key in _heldDigitalKeys) {
      _keyDownTimes[key] = (_keyDownTimes[key] ?? 0.0) + deltaTime;
    }
    _justPressedThisTick
      ..clear()
      ..addAll(_justPressed);
    _justPressed.clear();
    _lastAxisValues
      ..clear()
      ..addAll(_pendingAnalogValues);
    // 1. Collect active mappings obeying priority shadowing
    final Set<LuminaKey> shadowedKeys = {};
    final List<LuminaActionKeyMapping> activeMappings = [];

    for (final entry in _contextStack) {
      for (final mapping in entry.context.mappings) {
        if (!shadowedKeys.contains(mapping.key)) {
          activeMappings.add(mapping);
        }
      }
      for (final mapping in entry.context.mappings) {
        shadowedKeys.add(mapping.key);
      }
    }

    // 2. Gather all distinct actions defined in active mappings plus actions previously active
    final Set<LuminaInputAction> allActions = {};
    for (final mapping in activeMappings) {
      allActions.add(mapping.action);
    }
    allActions.addAll(_lastActionEvaluations.keys);

    for (final action in allActions) {
      TriggerEvaluation currentEval = TriggerEvaluation.none;
      final Vector3 actionAccumulator = Vector3.zero();

      final mappingsForAction = activeMappings.where((m) => m.action == action).toList();
      for (final mapping in mappingsForAction) {
        final key = mapping.key;
        double rawInput = 0.0;
        if (_heldDigitalKeys.contains(key)) {
          rawInput = 1.0;
        } else if (_pendingAnalogValues.containsKey(key)) {
          rawInput = _pendingAnalogValues[key]!;
        }

        var modifiedVal = LuminaInputActionValue.raw(action.valueType, rawInput, 0.0, 0.0);
        for (final mod in mapping.modifiers) {
          modifiedVal = mod.modify(modifiedVal, deltaTime);
        }

        if (rawInput != 0.0) {
          actionAccumulator.add(modifiedVal.asAxis3D);
        }

        // Trigger evaluation
        TriggerEvaluation mappingEval;
        if (mapping.triggers.isEmpty) {
          // Implicit trigger
          mappingEval = (modifiedVal.magnitude > 0.0)
              ? TriggerEvaluation.triggered
              : TriggerEvaluation.none;
        } else {
          TriggerEvaluation bestTrigger = TriggerEvaluation.none;
          for (final trigger in mapping.triggers) {
            final eval = trigger.update(modifiedVal, deltaTime);
            if (eval == TriggerEvaluation.triggered) {
              bestTrigger = TriggerEvaluation.triggered;
              break;
            } else if (eval == TriggerEvaluation.ongoing && bestTrigger == TriggerEvaluation.none) {
              bestTrigger = TriggerEvaluation.ongoing;
            }
          }
          mappingEval = bestTrigger;
        }

        if (mappingEval == TriggerEvaluation.triggered) {
          currentEval = TriggerEvaluation.triggered;
        } else if (mappingEval == TriggerEvaluation.ongoing && currentEval == TriggerEvaluation.none) {
          currentEval = TriggerEvaluation.ongoing;
        }
      }

      final prevEval = _lastActionEvaluations[action] ?? TriggerEvaluation.none;
      final eventsToFire = <TriggerState>[];

      if (prevEval == TriggerEvaluation.none && currentEval == TriggerEvaluation.ongoing) {
        eventsToFire.add(TriggerState.started);
      } else if (prevEval == TriggerEvaluation.ongoing && currentEval == TriggerEvaluation.ongoing) {
        eventsToFire.add(TriggerState.ongoing);
      } else if (prevEval == TriggerEvaluation.ongoing && currentEval == TriggerEvaluation.none) {
        eventsToFire.add(TriggerState.canceled);
      } else if (prevEval == TriggerEvaluation.none && currentEval == TriggerEvaluation.triggered) {
        eventsToFire.add(TriggerState.started);
        eventsToFire.add(TriggerState.triggered);
      } else if ((prevEval == TriggerEvaluation.ongoing || prevEval == TriggerEvaluation.triggered) &&
          currentEval == TriggerEvaluation.triggered) {
        eventsToFire.add(TriggerState.triggered);
      } else if (prevEval == TriggerEvaluation.triggered && currentEval == TriggerEvaluation.none) {
        eventsToFire.add(TriggerState.completed);
      } else if (prevEval == TriggerEvaluation.triggered && currentEval == TriggerEvaluation.ongoing) {
        eventsToFire.add(TriggerState.ongoing);
      }

      final actionVal = LuminaInputActionValue.raw(
        action.valueType,
        actionAccumulator.x,
        actionAccumulator.y,
        actionAccumulator.z,
      );

      final dispatchVal = (currentEval == TriggerEvaluation.none && _lastActionValues.containsKey(action))
          ? _lastActionValues[action]!
          : actionVal;

      for (final event in eventsToFire) {
        for (final comp in List<LuminaInputComponent>.from(_registeredComponents)) {
          comp.dispatch(action, event, dispatchVal);
        }
      }

      if (currentEval == TriggerEvaluation.none) {
        _lastActionEvaluations.remove(action);
        _lastActionValues.remove(action);
      } else {
        _lastActionEvaluations[action] = currentEval;
        _lastActionValues[action] = actionVal;
      }
    }

    _pendingAnalogValues.clear();
  }

  @override
  void onWorldTick(double deltaTime) {
    tick(deltaTime);
  }

  @override
  void onWorldShutdown() {
    _contextStack.clear();
    _heldDigitalKeys.clear();
    _pendingAnalogValues.clear();
    _registeredComponents.clear();
    _lastActionEvaluations.clear();
    _lastActionValues.clear();
    super.onWorldShutdown();
  }
}

/// Component attached to actors for receiving and processing enhanced input signals.
class LuminaInputComponent extends LuminaActorComponent {
  final Map<LuminaInputAction, Map<TriggerState, List<void Function(LuminaInputActionValue value)>>> _actionListeners = {};
  LuminaInputSubsystem? _subsystem;

  // ignore: prefer_initializing_formals
  LuminaInputComponent({super.key, LuminaInputSubsystem? subsystem}) : _subsystem = subsystem;

  /// Binds a callback to an action for a specific [event] state.
  void bindAction(
    LuminaInputAction action,
    TriggerState event,
    void Function(LuminaInputActionValue value) callback,
  ) {
    final eventMap = _actionListeners.putIfAbsent(action, () => {});
    final list = eventMap.putIfAbsent(event, () => []);
    list.add(callback);
  }

  /// Dispatches an action event to registered callbacks.
  void dispatch(LuminaInputAction action, TriggerState event, LuminaInputActionValue value) {
    final eventMap = _actionListeners[action];
    if (eventMap == null) return;
    final callbacks = eventMap[event];
    if (callbacks == null) return;

    for (final cb in List<void Function(LuminaInputActionValue)>.from(callbacks)) {
      cb(value);
    }
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    final world = ownerActor.world;
    if (_subsystem == null && world != null) {
      _subsystem = world.subsystems.getSubsystem<LuminaInputSubsystem>();
    }
    _subsystem?.registerComponent(this);
  }

  @override
  void onUnregister() {
    _subsystem?.unregisterComponent(this);
    _actionListeners.clear();
    super.onUnregister();
  }
}
