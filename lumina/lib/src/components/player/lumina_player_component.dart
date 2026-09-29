import '../base/actor_component.dart';
import '../../object/actor.dart';
import '../../object/pawn.dart';
import 'input_binding.dart';
export 'input_binding.dart';

/// Player component attached to player-controlled pawns or actors for handling input bindings.
class LuminaPlayerComponent extends LuminaActorComponent {
  final Map<String, List<InputActionBinding>> _actionBindings = {};
  final Map<String, List<InputAxisBinding>> _axisBindings = {};

  LuminaPlayerComponent({super.key});

  /// Binds a named action (e.g., "Jump") to a callback with optional trigger state.
  InputActionBinding bindAction(
    String actionName,
    void Function() callback, {
    InputTriggerState state = InputTriggerState.triggered,
  }) {
    // Non-const instantiation ensures unique object identity for unbind
    final binding = InputActionBinding(
      actionName: actionName,
      state: state,
      callback: callback,
    );
    _actionBindings.putIfAbsent(actionName, () => []).add(binding);
    return binding;
  }

  /// Binds a named axis (e.g., "MoveForward") to a callback.
  InputAxisBinding bindAxis(
    String axisName,
    void Function(double value) callback,
  ) {
    final binding = InputAxisBinding(
      axisName: axisName,
      callback: callback,
    );
    _axisBindings.putIfAbsent(axisName, () => []).add(binding);
    return binding;
  }

  /// Unbinds a specific action binding handle.
  bool unbindAction(InputActionBinding binding) {
    final list = _actionBindings[binding.actionName];
    if (list == null) return false;
    final removed = list.remove(binding);
    if (list.isEmpty) {
      _actionBindings.remove(binding.actionName);
    }
    return removed;
  }

  /// Unbinds a specific axis binding handle.
  bool unbindAxis(InputAxisBinding binding) {
    final list = _axisBindings[binding.axisName];
    if (list == null) return false;
    final removed = list.remove(binding);
    if (list.isEmpty) {
      _axisBindings.remove(binding.axisName);
    }
    return removed;
  }

  /// Clears all registered action and axis bindings.
  void clearBindings() {
    _actionBindings.clear();
    _axisBindings.clear();
  }

  /// Triggers actions bound to [actionName] matching the specified [state].
  void triggerAction(String actionName, [InputTriggerState state = InputTriggerState.triggered]) {
    final list = _actionBindings[actionName];
    if (list == null || list.isEmpty) return;

    for (final binding in List<InputActionBinding>.from(list)) {
      if (binding.state == state) {
        binding.callback();
      }
    }
  }

  /// Triggers axes bound to [axisName] with [value].
  void triggerAxis(String axisName, double value) {
    final list = _axisBindings[axisName];
    if (list == null || list.isEmpty) return;

    for (final binding in List<InputAxisBinding>.from(list)) {
      binding.callback(value);
    }
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    if (ownerActor is! LuminaPawn) {
      throw StateError('LuminaPlayerComponent can only be attached to LuminaPawn or subclasses.');
    }
    super.onRegister(ownerActor);
  }

  @override
  void onUnregister() {
    clearBindings();
    super.onUnregister();
  }
}
