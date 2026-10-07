import 'package:lumina/src/input/input_action.dart';
import 'package:lumina/src/input/input_key.dart';
import 'package:lumina/src/input/input_modifier.dart';
import 'package:lumina/src/input/input_trigger.dart';

/// Represents a mapping between an input key and an input action with optional modifiers and triggers.
class LuminaActionKeyMapping {
  final LuminaKey key;
  final LuminaInputAction action;
  final List<LuminaInputModifier> modifiers;
  final List<LuminaInputTrigger> triggers;

  const LuminaActionKeyMapping({
    required this.key,
    required this.action,
    this.modifiers = const [],
    this.triggers = const [],
  });
}

/// Context containing a set of key-to-action mappings.
class LuminaInputMappingContext {
  final List<LuminaActionKeyMapping> _mappings = [];

  /// All mappings registered in this context.
  List<LuminaActionKeyMapping> get mappings => List.unmodifiable(_mappings);

  /// Maps a [key] to an [action] with optional [modifiers] and [triggers].
  LuminaActionKeyMapping mapKey(
    LuminaKey key,
    LuminaInputAction action, {
    List<LuminaInputModifier> modifiers = const [],
    List<LuminaInputTrigger> triggers = const [],
  }) {
    final mapping = LuminaActionKeyMapping(
      key: key,
      action: action,
      modifiers: modifiers,
      triggers: triggers,
    );
    _mappings.add(mapping);
    return mapping;
  }

  /// Unmaps all mappings between [key] and [action].
  void unmapKey(LuminaKey key, LuminaInputAction action) {
    _mappings.removeWhere((m) => m.key == key && m.action == action);
  }

  /// Returns all mappings registered for [key].
  List<LuminaActionKeyMapping> mappingsForKey(LuminaKey key) {
    return _mappings.where((m) => m.key == key).toList();
  }
}
