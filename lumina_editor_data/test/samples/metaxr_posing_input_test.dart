import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The posing example's controller buttons, as the project's input binds them.
void main() {
  final input = MetaXrPosingContent.input;
  List<String> keysOf(String action) => [
        for (final c in input.mappingContexts)
          for (final m in c.mappings)
            if (m.action == action) m.keyLabel,
      ];

  test('Undo is B and Y, the passthrough toggle the left stick click, Reset the menu button', () {
    expect(keysOf('IA_Undo'), containsAll([LuminaKey.xrRightB.id, LuminaKey.xrLeftY.id]));
    expect(keysOf('IA_TogglePassthrough'), contains(LuminaKey.xrLeftThumbstickClick.id));
    expect(keysOf('IA_Reset'), contains(LuminaKey.xrLeftMenu.id));
  });

  test('A steps through the slots and, held, saves; X steps back', () {
    expect(keysOf('IA_Slot'), contains(LuminaKey.xrRightA.id));
    expect(keysOf('IA_SlotBack'), contains(LuminaKey.xrLeftX.id));
    expect(MetaXrPosingContent.saveHoldSeconds, greaterThan(0.5), reason: 'a long press, not a tap');
    expect(MetaXrPosingContent.resetHoldSeconds, 1.0);
  });

  test('the sticks turn and slide the character; every mapping binds a key the engine knows', () {
    expect(keysOf('IA_Turn'), [LuminaKey.xrRightThumbstickX.id]);
    expect(keysOf('IA_Slide'), [LuminaKey.xrLeftThumbstickX.id, LuminaKey.xrLeftThumbstickY.id]);
    final bound = ProjectInputBinder.bind(input);
    expect(bound.unboundKeys, isEmpty);
    expect(bound.actions.keys, containsAll(['IA_Undo', 'IA_Reset', 'IA_Slot', 'IA_SlotBack', 'IA_TogglePassthrough', 'IA_Turn', 'IA_Slide']));
  });
}
