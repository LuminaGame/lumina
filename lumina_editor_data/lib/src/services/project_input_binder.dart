import 'package:lumina/src/game/template_character.dart';
import 'package:lumina/src/input/input_component.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina_core/lumina_core.dart';

/// One mapping context from the manifest, with the priority it was authored at.
class BoundMappingContext {
  final String name;
  final int priority;
  final LuminaInputMappingContext context;

  const BoundMappingContext({required this.name, required this.priority, required this.context});
}

/// The result of binding a project's input settings to the runtime.
class BoundProjectInput {
  final List<BoundMappingContext> contexts;
  final Map<String, LuminaInputAction> actions;

  /// Labels of keys the manifest binds that the runtime has no equivalent for.
  /// Reported rather than silently dropped, so the editor can say so.
  final List<String> unboundKeys;

  const BoundProjectInput({
    required this.contexts,
    required this.actions,
    required this.unboundKeys,
  });

  LuminaInputAction? actionByName(String name) => actions[name];
}

/// Turns the `.lmproject` manifest's [ProjectInputSettings] — the same
/// structures the Project Settings input editor edits — into the runtime's
/// actions and mapping contexts.
///
/// Play-In-Editor binds through this, so rebinding a key in Project Settings
/// changes what Play does, instead of PIE keeping a second hardcoded list.
class ProjectInputBinder {
  const ProjectInputBinder._();

  /// `LogicalKeyboardKey.keyId` (and the mouse / gamepad sentinels) →
  /// runtime key: every keyboard key, through the one table
  /// PIE and the generated game read too.
  static LuminaKey? keyForId(int keyId) => LuminaKey.fromKeyId(keyId);

  static InputValueType _valueType(ProjectInputValueType type) {
    switch (type) {
      case ProjectInputValueType.axis1D:
        return InputValueType.axis1D;
      case ProjectInputValueType.axis2D:
        return InputValueType.axis2D;
      case ProjectInputValueType.digital:
        return InputValueType.digitalBool;
    }
  }

  static BoundProjectInput bind(ProjectInputSettings settings) {
    final actions = <String, LuminaInputAction>{
      for (final a in settings.actions)
        a.name: LuminaInputAction(a.name, valueType: _valueType(a.valueType)),
    };
    final unbound = <String>[];
    final contexts = <BoundMappingContext>[];

    for (final projectContext in settings.mappingContexts) {
      final context = LuminaInputMappingContext();
      for (final mapping in projectContext.mappings) {
        final key = keyForId(mapping.keyId);
        final action = actions[mapping.action];
        if (key == null || action == null) {
          unbound.add(mapping.keyLabel.isEmpty ? '#${mapping.keyId}' : mapping.keyLabel);
          continue;
        }
        final isAxis = action.valueType != InputValueType.digitalBool;
        context.mapKey(
          key,
          action,
          modifiers: isAxis
              ? <LuminaInputModifier>[
                  LuminaAxisPlacementModifier(
                    toX: mapping.axis.toUpperCase() == 'X' ? mapping.scale : 0.0,
                    toY: mapping.axis.toUpperCase() == 'Y' ? mapping.scale : 0.0,
                  ),
                ]
              : const <LuminaInputModifier>[],
          // No trigger — an implicit Down: Started on press, Triggered
          // every held frame, Completed on release.
          triggers: const <LuminaInputTrigger>[],
        );
      }
      contexts.add(BoundMappingContext(
        name: projectContext.name,
        priority: projectContext.priority,
        context: context,
      ));
    }

    return BoundProjectInput(contexts: contexts, actions: actions, unboundKeys: unbound);
  }
}

/// Registers [input]'s mapping contexts on [world]'s input subsystem and binds
/// the template character's move / look / jump / free-look handlers to them.
///
/// The action *names* come from the manifest, so a project that renames
/// `IA_Move` in Project Settings keeps working as long as the name is one of
/// the three the template character understands. Returns the input component
/// added to the character, or null when the project binds no gameplay input.
LuminaInputComponent? bindTemplateCharacterInput({
  required LuminaTemplateCharacter character,
  required LuminaWorld world,
  required BoundProjectInput input,
}) {
  if (input.contexts.isEmpty) return null;

  var subsystem = world.getSubsystem<LuminaInputSubsystem>();
  subsystem ??= world.registerSubsystem(LuminaInputSubsystem());
  for (final bound in input.contexts) {
    subsystem.addMappingContext(bound.context, priority: bound.priority);
  }

  final component = LuminaInputComponent();
  character.addComponent(component);

  final move = input.actionByName(luminaTemplateMoveAction.name);
  final look = input.actionByName(luminaTemplateLookAction.name);
  final jump = input.actionByName(luminaTemplateJumpAction.name);
  if (move != null) component.bindAction(move, TriggerState.triggered, character.onMove);
  if (look != null) component.bindAction(look, TriggerState.triggered, character.onLook);
  // Jump on Started, Stop Jumping on Completed.
  if (jump != null) {
    component.bindAction(jump, TriggerState.started, character.onJump);
    component.bindAction(jump, TriggerState.completed, character.onStopJumping);
  }
  // Free look: held — Started on, Completed / Canceled off.
  final freeLook = input.actionByName(luminaTemplateFreeLookAction.name);
  if (freeLook != null) {
    component.bindAction(freeLook, TriggerState.started, character.onFreeLook);
    component.bindAction(freeLook, TriggerState.completed, character.onStopFreeLook);
    component.bindAction(freeLook, TriggerState.canceled, character.onStopFreeLook);
  }

  return component;
}
