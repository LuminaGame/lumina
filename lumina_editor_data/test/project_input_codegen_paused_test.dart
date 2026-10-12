import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The generated game's `project_input.g.dart` keeps an action's Execute When
/// Paused flag, as Play-In-Editor's binder does.
void main() {
  test('only the flagged action is generated with executeWhenPaused', () {
    const settings = ProjectInputSettings(
      actions: [
        ProjectInputAction(name: 'IA_GraphicsMenu', executeWhenPaused: true),
        ProjectInputAction(name: 'IA_Jump'),
      ],
      mappingContexts: [
        ProjectMappingContext(name: 'Gameplay', mappings: [
          ProjectInputMapping(action: 'IA_GraphicsMenu', keyId: 0x10000001b, keyLabel: 'Escape'),
          ProjectInputMapping(action: 'IA_Jump', keyId: 0x20, keyLabel: 'Space'),
        ]),
      ],
    );
    final code = DartCodeGeneratorService().generateProjectInputDart(settings);
    expect(code,
        contains("'IA_GraphicsMenu': LuminaInputAction('IA_GraphicsMenu', valueType: InputValueType.digitalBool, executeWhenPaused: true),"));
    expect(code, contains("'IA_Jump': LuminaInputAction('IA_Jump', valueType: InputValueType.digitalBool),"));
    expect(code, contains('LuminaKey.keyEscape'));
  });
}
