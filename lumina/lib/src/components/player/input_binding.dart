import 'package:lumina/src/input/input_action.dart';

export 'package:lumina/src/input/input_action.dart' show TriggerState;

/// Typedef aligning legacy InputTriggerState to canonical TriggerState.
typedef InputTriggerState = TriggerState;

/// Representation of an action binding hook.
class InputActionBinding {
  final String actionName;
  final InputTriggerState state;
  final void Function() callback;

  const InputActionBinding({
    required this.actionName,
    required this.state,
    required this.callback,
  });
}

/// Representation of an axis binding hook.
class InputAxisBinding {
  final String axisName;
  final void Function(double value) callback;

  const InputAxisBinding({
    required this.axisName,
    required this.callback,
  });
}
