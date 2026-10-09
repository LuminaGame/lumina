import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A window backend that keeps the mode the way a runner would: what the
/// game asked for, plus the toggles the player makes with Alt+Enter / F11.
class _RunnerWindow implements LuminaWindowModeBackend {
  _RunnerWindow(this.current);

  LuminaWindowMode current;
  final List<LuminaWindowMode> applied = [];
  void Function(LuminaWindowMode mode)? _listener;

  @override
  Future<LuminaWindowMode?> getMode() async => current;

  @override
  Future<bool> setMode(LuminaWindowMode mode) async {
    applied.add(mode);
    current = mode;
    return true;
  }

  @override
  set onModeChanged(void Function(LuminaWindowMode mode)? listener) => _listener = listener;

  /// The player pressed Alt+Enter: the runner toggled and tells the game.
  void playerToggles() {
    current = current == LuminaWindowMode.windowed ? LuminaWindowMode.borderlessFullscreen : LuminaWindowMode.windowed;
    _listener?.call(current);
  }
}

void main() {
  late Directory temp;
  late String settingsPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_window_');
    settingsPath = LuminaGameWindow.settingsFileFor('${temp.path}/SaveGames');
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
  });

  tearDown(() {
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
    temp.deleteSync(recursive: true);
  });

  test('labels parse back, case and spacing insensitive', () {
    for (final m in LuminaWindowMode.values) {
      expect(LuminaWindowMode.parse(m.label), m);
      expect(LuminaWindowMode.parse(m.id), m);
    }
    expect(LuminaWindowMode.parse('borderless fullscreen'), LuminaWindowMode.borderlessFullscreen);
    expect(LuminaWindowMode.parse('Fullscreen'), LuminaWindowMode.borderlessFullscreen);
    expect(LuminaWindowMode.parse('windowed'), LuminaWindowMode.windowed);
    expect(LuminaWindowMode.parse('Exclusive'), isNull);
  });

  test('restore applies the project start mode when the player chose nothing', () async {
    final window = _RunnerWindow(LuminaWindowMode.windowed);
    LuminaGameWindow.backend = window;
    final mode = await LuminaGameWindow.restore(
      startMode: LuminaWindowMode.borderlessFullscreen,
      settingsFilePath: settingsPath,
    );
    expect(mode, LuminaWindowMode.borderlessFullscreen);
    expect(window.applied, [LuminaWindowMode.borderlessFullscreen]);
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.borderlessFullscreen);
    // Nothing persisted: the project default stays in charge.
    expect(File(settingsPath).existsSync(), isFalse);
  });

  test('restore does not touch a window the runner already started in the mode', () async {
    final window = _RunnerWindow(LuminaWindowMode.borderlessFullscreen);
    LuminaGameWindow.backend = window;
    await LuminaGameWindow.restore(startMode: LuminaWindowMode.borderlessFullscreen, settingsFilePath: settingsPath);
    expect(window.applied, isEmpty);
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.borderlessFullscreen);
  });

  test('the player choice is persisted and wins over the project start mode', () async {
    final window = _RunnerWindow(LuminaWindowMode.borderlessFullscreen);
    LuminaGameWindow.backend = window;
    await LuminaGameWindow.restore(startMode: LuminaWindowMode.borderlessFullscreen, settingsFilePath: settingsPath);
    expect(await LuminaGameWindow.setMode(LuminaWindowMode.windowed), isTrue);
    final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect(saved['window_mode'], 'windowed');

    // Next launch: the runner starts fullscreen (project setting), the player's
    // windowed choice is restored before the first frame.
    LuminaGameWindow.resetForTesting();
    final next = _RunnerWindow(LuminaWindowMode.borderlessFullscreen);
    LuminaGameWindow.backend = next;
    final mode = await LuminaGameWindow.restore(startMode: LuminaWindowMode.borderlessFullscreen, settingsFilePath: settingsPath);
    expect(mode, LuminaWindowMode.windowed);
    expect(next.applied, [LuminaWindowMode.windowed]);
  });

  test('a toggle in the runner (Alt+Enter / F11) updates the mode and is persisted', () async {
    final window = _RunnerWindow(LuminaWindowMode.borderlessFullscreen);
    LuminaGameWindow.backend = window;
    await LuminaGameWindow.restore(startMode: LuminaWindowMode.borderlessFullscreen, settingsFilePath: settingsPath);
    window.playerToggles();
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.windowed);
    await LuminaGameWindow.pendingWrite;
    final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect(saved['window_mode'], 'windowed');
  });

  test('other keys of the user settings file are kept', () async {
    File(settingsPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'ray_tracing': true}));
    LuminaGameWindow.backend = _RunnerWindow(LuminaWindowMode.windowed);
    await LuminaGameWindow.restore(settingsFilePath: settingsPath);
    await LuminaGameWindow.setMode(LuminaWindowMode.borderlessFullscreen);
    final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect(saved, {'ray_tracing': true, 'window_mode': 'borderless_fullscreen'});
  });

  test('toggle flips between windowed and borderless fullscreen', () async {
    final window = _RunnerWindow(LuminaWindowMode.windowed);
    LuminaGameWindow.backend = window;
    await LuminaGameWindow.restore(settingsFilePath: settingsPath);
    await LuminaGameWindow.toggle();
    expect(window.current, LuminaWindowMode.borderlessFullscreen);
    await LuminaGameWindow.toggle();
    expect(window.current, LuminaWindowMode.windowed);
  });

  test('without a window backend (editor, web) the mode is only recorded', () async {
    expect(await LuminaGameWindow.setMode(LuminaWindowMode.borderlessFullscreen), isFalse);
    expect(LuminaGameWindow.mode.value, LuminaWindowMode.borderlessFullscreen);
  });

  test('settings file is GameUserSettings.json in the save games folder', () {
    expect(
      LuminaGameWindow.settingsFileFor('/home/p/.local/share/My Game/SaveGames/').replaceAll('\\', '/'),
      '/home/p/.local/share/My Game/SaveGames/GameUserSettings.json',
    );
  });

  group('Blueprint nodes', () {
    test('Set / Get / Toggle Fullscreen Mode are registered with call shapes', () {
      for (final id in ['set_fullscreen_mode', 'get_fullscreen_mode', 'toggle_fullscreen']) {
        expect(LuminaBlueprintNodeLibrary.builtIn(id), isNotNull, reason: id);
        expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull, reason: id);
        expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull, reason: id);
      }
    });

    test('Set Fullscreen Mode drives the window and Get reads it back', () async {
      final window = _RunnerWindow(LuminaWindowMode.windowed);
      LuminaGameWindow.backend = window;
      final actor = LuminaActor();
      LuminaBlueprintFunctionLibrary.setFullscreenMode(actor, 'Borderless Fullscreen');
      expect(LuminaBlueprintFunctionLibrary.getFullscreenMode(actor), 'Borderless Fullscreen');
      await LuminaGameWindow.pendingWrite;
      expect(window.current, LuminaWindowMode.borderlessFullscreen);
      LuminaBlueprintFunctionLibrary.toggleFullscreen(actor);
      expect(LuminaBlueprintFunctionLibrary.getFullscreenMode(actor), 'Windowed');
      await LuminaGameWindow.pendingWrite;
      expect(window.current, LuminaWindowMode.windowed);
    });
  });
}
