import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import '../helpers/temp_project.dart';

/// A key the user binds in Project Settings outside the
/// template's set (IA_ChangeCamera on V) used to be dropped by PIE as "no
/// runtime equivalent". Play's keyboard handler now forwards every key
/// through `LuminaKey.fromKeyId`, the table the binder and the built game use.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the Project Settings key picker can capture: any key a keyboard
  /// sends (it stores `LogicalKeyboardKey.keyId` + label; Escape cancels the
  /// capture). A key added to a keyboard layout that maps to no LuminaKey
  /// fails here.
  final pickerKeys = <LogicalKeyboardKey>[
    for (var c = 0x61; c <= 0x7a; c++) LogicalKeyboardKey(c), // a–z
    for (var d = 0x30; d <= 0x39; d++) LogicalKeyboardKey(d), // 0–9
    LogicalKeyboardKey.f1, LogicalKeyboardKey.f2, LogicalKeyboardKey.f3, LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5, LogicalKeyboardKey.f6, LogicalKeyboardKey.f7, LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9, LogicalKeyboardKey.f10, LogicalKeyboardKey.f11, LogicalKeyboardKey.f12,
    LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space, LogicalKeyboardKey.tab, LogicalKeyboardKey.enter, LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.delete, LogicalKeyboardKey.insert, LogicalKeyboardKey.home, LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp, LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock, LogicalKeyboardKey.numLock, LogicalKeyboardKey.scrollLock,
    LogicalKeyboardKey.printScreen, LogicalKeyboardKey.pause, LogicalKeyboardKey.contextMenu,
    LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5, LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9, LogicalKeyboardKey.numpadAdd, LogicalKeyboardKey.numpadSubtract,
    LogicalKeyboardKey.numpadMultiply, LogicalKeyboardKey.numpadDivide, LogicalKeyboardKey.numpadDecimal,
    LogicalKeyboardKey.numpadEnter, LogicalKeyboardKey.numpadEqual, LogicalKeyboardKey.numpadComma,
    LogicalKeyboardKey.minus, LogicalKeyboardKey.equal, LogicalKeyboardKey.bracketLeft, LogicalKeyboardKey.bracketRight,
    LogicalKeyboardKey.backslash, LogicalKeyboardKey.semicolon, LogicalKeyboardKey.quote, LogicalKeyboardKey.backquote,
    LogicalKeyboardKey.comma, LogicalKeyboardKey.period, LogicalKeyboardKey.slash, LogicalKeyboardKey.intlBackslash,
  ];

  late Directory dir;
  late EditorViewModel vm;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lumina_pie_keys_');
    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    final gameplay = template.input.mappingContexts.single;
    // The user's Project Settings: IA_ChangeCamera on V, as the key picker stores it.
    final input = ProjectInputSettings(
      actions: [...template.input.actions, const ProjectInputAction(name: 'IA_ChangeCamera')],
      mappingContexts: [
        ProjectMappingContext(name: gameplay.name, priority: gameplay.priority, mappings: [
          ...gameplay.mappings,
          ProjectInputMapping(action: 'IA_ChangeCamera', keyId: LogicalKeyboardKey.keyV.keyId, keyLabel: 'V'),
        ]),
      ],
    );
    vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'KeysGame', template: kFirstPersonTemplateId, input: input),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
  });

  // Windows refuses to delete a folder a just-disposed editor still
  // holds; deleteTempProject retries on the real clock.
  tearDown(() async {
    if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
    vm.dispose();
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
    await deleteTempProject(dir);
  });

  KeyDownEvent down(LogicalKeyboardKey key) =>
      KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyV, logicalKey: key, timeStamp: Duration.zero);
  KeyUpEvent up(LogicalKeyboardKey key) =>
      KeyUpEvent(physicalKey: PhysicalKeyboardKey.keyV, logicalKey: key, timeStamp: Duration.zero);

  test('pressing V in Play fires IA_ChangeCamera Started; nothing is reported unbound', () async {
    final pie = vm.pieController;
    final game = pie.startHeadlessForTest(LuminaWorld());
    await pumpEventQueue();
    game.tickGame(1 / 60);
    expect(game.input.unboundKeys, isEmpty, reason: 'V has a runtime equivalent');

    final subsystem = game.gameInstance.world!.getSubsystem<LuminaInputSubsystem>()!;
    final component = LuminaInputComponent(subsystem: subsystem);
    subsystem.registerComponent(component);
    final events = <TriggerState>[];
    const changeCamera = LuminaInputAction('IA_ChangeCamera');
    for (final state in [TriggerState.started, TriggerState.completed]) {
      component.bindAction(changeCamera, state, (_) => events.add(state));
    }

    expect(pie.handleKeyEventForTest(down(LogicalKeyboardKey.keyV)), isTrue, reason: 'a bound key is swallowed while playing');
    game.tickGame(1 / 60);
    expect(events, [TriggerState.started]);
    expect(pie.handleKeyEventForTest(up(LogicalKeyboardKey.keyV)), isTrue);
    game.tickGame(1 / 60);
    expect(events, [TriggerState.started, TriggerState.completed]);

    // An unbound key still reaches the world (Is Input Key Down) but is not
    // swallowed, so editor shortcuts such as Alt+P keep working.
    expect(pie.handleKeyEventForTest(down(LogicalKeyboardKey.keyP)), isFalse);
    expect(subsystem.isKeyDown(LuminaKey.keyP), isTrue);
    pie.handleKeyEventForTest(up(LogicalKeyboardKey.keyP));
  });

  test('every key the Project Settings key picker can capture maps to a LuminaKey and reaches the game', () async {
    final pie = vm.pieController;
    final game = pie.startHeadlessForTest(LuminaWorld());
    await pumpEventQueue();
    game.tickGame(1 / 60);
    final subsystem = game.gameInstance.world!.getSubsystem<LuminaInputSubsystem>()!;
    for (final key in pickerKeys) {
      final luminaKey = LuminaKey.fromKeyId(key.keyId);
      expect(luminaKey, isNotNull, reason: '${key.debugName} (0x${key.keyId.toRadixString(16)})');
      // F4 gives the mouse back and Esc stops Play while captured.
      if (key == LogicalKeyboardKey.f4) continue;
      pie.mouseCapture.release();
      pie.handleKeyEventForTest(down(key));
      expect(subsystem.isKeyDown(luminaKey!), isTrue, reason: '${key.debugName} reaches the world');
      pie.handleKeyEventForTest(up(key));
      expect(subsystem.isKeyDown(luminaKey), isFalse, reason: '${key.debugName} is released');
    }
    expect(LuminaKey.fromKeyId(LogicalKeyboardKey.escape.keyId), LuminaKey.keyEscape);
  });
}
