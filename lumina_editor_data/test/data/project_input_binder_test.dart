import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Play-In-Editor must honour the actions and keys the user edits in
/// Project Settings, not a second hardcoded list. The manifest's
/// [ProjectInputSettings] is the source of truth; this binder turns it into the
/// runtime's mapping contexts.
void main() {
  test('the first-person template binds W/A/S/D, the mouse and Space', () {
    final settings = GameTemplateCatalog.byId(kFirstPersonTemplateId).input;
    final bound = ProjectInputBinder.bind(settings);

    expect(bound.contexts.length, 1);
    final context = bound.contexts.first.context;
    expect(bound.contexts.first.priority, 0);

    final move = bound.actionByName('IA_Move');
    expect(move, isNotNull);
    expect(move!.valueType, InputValueType.axis2D);
    expect(bound.actionByName('IA_Jump')!.valueType, InputValueType.digitalBool);

    expect(context.mappingsForKey(LuminaKey.keyW).single.action, move);
    expect(context.mappingsForKey(LuminaKey.keyD).single.action, move);
    expect(context.mappingsForKey(LuminaKey.mouseX).single.action, bound.actionByName('IA_Look'));
    expect(context.mappingsForKey(LuminaKey.keySpace).single.action, bound.actionByName('IA_Jump'));
  });

  test('scale and axis reach the modifier, so W is +Y and A is -X', () {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.byId(kFirstPersonTemplateId).input);
    final context = bound.contexts.first.context;

    Vector2Like value(LuminaKey key) {
      final modifier = context.mappingsForKey(key).single.modifiers.single;
      final out = modifier.modify(const LuminaInputActionValue.axis1D(1.0), 1 / 60);
      return Vector2Like(out.asAxis2D.x, out.asAxis2D.y);
    }

    expect(value(LuminaKey.keyW).y, closeTo(1.0, 1e-9));
    expect(value(LuminaKey.keyS).y, closeTo(-1.0, 1e-9));
    expect(value(LuminaKey.keyA).x, closeTo(-1.0, 1e-9));
    expect(value(LuminaKey.keyD).x, closeTo(1.0, 1e-9));
    expect(value(LuminaKey.mouseY).y, closeTo(-1.0, 1e-9));
  });

  test('a digital action is Started on press, Triggered while held and Completed on release', () {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.byId(kThirdPersonTemplateId).input);
    final subsystem = LuminaInputSubsystem();
    for (final c in bound.contexts) {
      subsystem.addMappingContext(c.context, priority: c.priority);
    }
    final component = LuminaInputComponent(subsystem: subsystem);
    subsystem.registerComponent(component);
    final jump = bound.actionByName('IA_Jump')!;
    final events = <String>[];
    var frame = 0;
    for (final state in [TriggerState.started, TriggerState.triggered, TriggerState.completed]) {
      component.bindAction(jump, state, (_) => events.add('${state.name}@$frame'));
    }
    subsystem.injectKeyDown(LuminaKey.keySpace);
    for (frame = 0; frame < 5; frame++) {
      subsystem.tick(1 / 60);
    }
    subsystem.injectKeyUp(LuminaKey.keySpace);
    subsystem.tick(1 / 60);
    // The default for a mapping without triggers is Down: Triggered every
    // held frame, Completed on the release frame (frame 5), never before.
    expect(events.where((e) => e.startsWith('started')), ['started@0']);
    expect(events.where((e) => e.startsWith('triggered')).length, 5);
    expect(events.where((e) => e.startsWith('completed')), ['completed@5']);
  });

  test('neither digital nor axis mappings carry an explicit trigger (implicit Down)', () {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.byId(kFirstPersonTemplateId).input);
    final context = bound.contexts.first.context;
    expect(context.mappingsForKey(LuminaKey.keySpace).single.triggers, isEmpty);
    expect(context.mappingsForKey(LuminaKey.keyW).single.triggers, isEmpty);
  });

  test('a key the runtime has no equivalent for is reported, not silently dropped', () {
    const settings = ProjectInputSettings(
      actions: [ProjectInputAction(name: 'IA_Crouch')],
      mappingContexts: [
        ProjectMappingContext(
          name: 'Gameplay',
          mappings: [ProjectInputMapping(action: 'IA_Crouch', keyId: 0x12345678, keyLabel: 'Launch Mail')],
        ),
      ],
    );
    final bound = ProjectInputBinder.bind(settings);
    expect(bound.contexts.first.context.mappings, isEmpty);
    expect(bound.unboundKeys, contains('Launch Mail'));
  });

  test('any keyboard key binds — IA_ChangeCamera on V, IA_Screenshot on F5, a numpad key and Right Ctrl', () {
    const settings = ProjectInputSettings(
      actions: [
        ProjectInputAction(name: 'IA_ChangeCamera'),
        ProjectInputAction(name: 'IA_Screenshot'),
        ProjectInputAction(name: 'IA_Zoom', valueType: ProjectInputValueType.axis1D),
      ],
      mappingContexts: [
        ProjectMappingContext(
          name: 'Gameplay',
          mappings: [
            // The ids and labels the Project Settings key picker stores (LogicalKeyboardKey).
            ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x76, keyLabel: 'V'),
            ProjectInputMapping(action: 'IA_Screenshot', keyId: 0x100000805, keyLabel: 'F5'),
            ProjectInputMapping(action: 'IA_Zoom', keyId: 0x20000022b, keyLabel: 'Numpad Add', axis: 'X'),
            ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x200000101, keyLabel: 'Control Right'),
          ],
        ),
      ],
    );
    final bound = ProjectInputBinder.bind(settings);
    expect(bound.unboundKeys, isEmpty);
    final context = bound.contexts.single.context;
    expect(context.mappingsForKey(LuminaKey.keyV).single.action, bound.actionByName('IA_ChangeCamera'));
    expect(context.mappingsForKey(LuminaKey.keyF5).single.action, bound.actionByName('IA_Screenshot'));
    expect(context.mappingsForKey(LuminaKey.keyNumpadAdd).single.action, bound.actionByName('IA_Zoom'));
    expect(context.mappingsForKey(LuminaKey.keyRightControl).single.action, bound.actionByName('IA_ChangeCamera'));

    // Pressing V fires IA_ChangeCamera Started.
    final subsystem = LuminaInputSubsystem();
    subsystem.addMappingContext(context);
    final component = LuminaInputComponent(subsystem: subsystem);
    subsystem.registerComponent(component);
    var started = 0;
    component.bindAction(bound.actionByName('IA_ChangeCamera')!, TriggerState.started, (_) => started++);
    subsystem.injectKeyDown(LuminaKey.keyV);
    subsystem.tick(1 / 60);
    expect(started, 1);
  });

  test('the blank template binds nothing at all', () {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.byId(kBlank3dTemplateId).input);
    expect(bound.contexts, isEmpty);
    expect(bound.unboundKeys, isEmpty);
  });

  test('writeProjectInputDart writes lib/input/project_input.g.dart with custom actions and mappings', () {
    final tempDir = Directory.systemTemp.createTempSync('lumina_input_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    const settings = ProjectInputSettings(
      actions: [
        ProjectInputAction(name: 'IA_Move', valueType: ProjectInputValueType.axis2D),
        ProjectInputAction(name: 'IA_Collect'),
        ProjectInputAction(name: 'IA_ChangeCamera'),
        ProjectInputAction(name: 'IA_ESC'),
      ],
      mappingContexts: [
        ProjectMappingContext(
          name: 'Gameplay',
          mappings: [
            ProjectInputMapping(action: 'IA_Move', keyId: 119, keyLabel: 'W', axis: 'Y', scale: 1.0),
            ProjectInputMapping(action: 'IA_Collect', keyId: 101, keyLabel: 'E'),
            ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 118, keyLabel: 'V'),
            ProjectInputMapping(action: 'IA_ESC', keyId: 4294967323, keyLabel: 'Escape'),
          ],
        ),
      ],
    );

    final gen = DartCodeGeneratorService();
    expect(gen.writeProjectInputDart(tempDir.path, settings), isTrue);

    final file = File('${tempDir.path}/lib/input/project_input.g.dart');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();

    expect(content, contains("'IA_Collect': LuminaInputAction('IA_Collect', valueType: InputValueType.digitalBool)"));
    expect(content, contains("'IA_ChangeCamera': LuminaInputAction('IA_ChangeCamera', valueType: InputValueType.digitalBool)"));
    expect(content, contains("'IA_ESC': LuminaInputAction('IA_ESC', valueType: InputValueType.digitalBool)"));

    expect(content, contains("context0.mapKey(LuminaKey.keyE, luminaProjectInputActions['IA_Collect']!);"));
    expect(content, contains("context0.mapKey(LuminaKey.keyV, luminaProjectInputActions['IA_ChangeCamera']!);"));
    expect(content, contains("context0.mapKey(LuminaKey.keyEscape, luminaProjectInputActions['IA_ESC']!);"));

    // Also test reading from .lmproject manifest when settings parameter is null
    final manifestFile = File('${tempDir.path}/test_proj.lmproject');
    manifestFile.writeAsStringSync(jsonEncode({'input': settings.toMap()}));
    expect(gen.writeProjectInputDart(tempDir.path), isTrue);
  });
}

/// Tiny holder so the assertions read as x/y without importing vector_math.
class Vector2Like {
  final double x;
  final double y;
  const Vector2Like(this.x, this.y);
}
