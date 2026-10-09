import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import 'display_test_support.dart';

void main() {
  late Directory temp;
  late String settingsPath;

  setUp(() {
    resetDisplay();
    temp = Directory.systemTemp.createTempSync('lumina_display_');
    settingsPath = LuminaGameWindow.settingsFileFor('${temp.path}/SaveGames');
  });

  tearDown(() {
    resetDisplay();
    temp.deleteSync(recursive: true);
  });

  group('display report', () {
    test('resolutions are unique and ascending; refresh rates per resolution ascending', () {
      final info = LuminaDisplayInfo.fromMap(twoMonitorReport())!;
      expect(info.monitors, hasLength(2));
      final main = info.current!;
      expect(main.name, 'DELL U3419W');
      expect(main.primary, isTrue);
      expect((main.width, main.height), (3440, 1440));
      expect(main.current, const LuminaDisplayMode(3440, 1440, 60));
      expect(main.resolutions, [(800, 600), (1280, 720), (1280, 1024), (1920, 1080), (2560, 1080), (3440, 1440)]);
      expect(main.refreshRatesFor(1920, 1080), [60, 100]);
      expect(main.refreshRatesFor(3440, 1440), [50, 60, 100]);
      expect(main.refreshRatesFor(1024, 768), isEmpty);
      expect(info.clientSize, (1280, 720));
    });

    test('a report round-trips through its map, and a report without monitors is null', () {
      final info = LuminaDisplayInfo.fromMap(twoMonitorReport(current: 1))!;
      final again = LuminaDisplayInfo.fromMap(info.toMap())!;
      expect(again.currentMonitor, 1);
      expect(again.current!.device, r'\\.\DISPLAY2');
      expect(again.current!.resolutions, info.current!.resolutions);
      expect(LuminaDisplayInfo.fromMap({'monitors': []}), isNull);
      expect(LuminaDisplayInfo.fromMap({'monitors': [{'name': 'broken'}]}), isNull);
    });

    test('without a display report the queries answer from the render size', () {
      expect(LuminaGameDisplay.supportedResolutions((1600, 900)), [(1600, 900)]);
      expect(LuminaGameDisplay.desktopMode((1600, 900)), const LuminaDisplayMode(1600, 900));
      expect(LuminaGameDisplay.monitorCount, 1);
      expect(LuminaGameDisplay.currentMonitor, (0, 'Display'));
      expect(LuminaGameDisplay.refreshRatesFor(1920, 1080), isEmpty);
    });
  });

  group('apply', () {
    test('windowed: the client area becomes the resolution, nothing is scaled', () async {
      final window = FakeRunnerWindow();
      installRunner(window);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(resolution: (1920, 1080));
      expect(window.resizes, [(1920, 1080)]);
      expect(window.client, (1920, 1080));
      expect(LuminaGameDisplay.renderResolution.value, isNull);
      expect(LuminaGameDisplay.currentResolution((1, 1), viewBound: false), (1920, 1080));
    });

    test('windowed: a resolution larger than the work area is clamped by the window', () async {
      final window = FakeRunnerWindow();
      installRunner(window);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(resolution: (3440, 1440));
      expect(window.client, (3424, 1353));
      expect(LuminaGameDisplay.currentResolution((1, 1), viewBound: false), (3424, 1353));
    });

    test('borderless fullscreen: the window stays, the game renders at the resolution', () async {
      final window = FakeRunnerWindow(current: LuminaWindowMode.borderlessFullscreen);
      installRunner(window);
      await LuminaGameWindow.restore(startMode: LuminaWindowMode.borderlessFullscreen, settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(resolution: (1920, 1080));
      expect(window.resizes, isEmpty);
      expect(LuminaGameDisplay.renderResolution.value, (1920, 1080));
      expect(LuminaGameDisplay.currentResolution((3440, 1440), viewBound: true), (1920, 1080));

      // The monitor's own size (or more) is native; 0 × 0 is native.
      await LuminaGameDisplay.apply(resolution: (3440, 1440));
      expect(LuminaGameDisplay.renderResolution.value, isNull);
      await LuminaGameDisplay.apply(resolution: (2560, 1080));
      expect(LuminaGameDisplay.renderResolution.value, (2560, 1080));
      await LuminaGameDisplay.apply(resolution: (0, 0));
      expect(LuminaGameDisplay.screenResolution, isNull);
      expect(LuminaGameDisplay.renderResolution.value, isNull);
    });

    test('a window that cannot be resized renders the resolution scaled', () async {
      installRunner(FakeRunnerWindow(canResize: false));
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(resolution: (1280, 720));
      expect(LuminaGameDisplay.renderResolution.value, (1280, 720));
    });

    test('switching the window mode re-applies the resolution', () async {
      final window = FakeRunnerWindow();
      installRunner(window);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(resolution: (1920, 1080));
      window.resizes.clear();

      await LuminaGameWindow.setMode(LuminaWindowMode.borderlessFullscreen);
      expect(LuminaGameDisplay.renderResolution.value, (1920, 1080));
      expect(window.resizes, isEmpty);

      // The player's Alt+Enter back to windowed: the client area again.
      window.playerToggles();
      await LuminaGameDisplay.pendingApply;
      expect(LuminaGameDisplay.renderResolution.value, isNull);
      expect(window.resizes, [(1920, 1080)]);
    });

    test('a monitor choice moves the window; the same monitor does not', () async {
      final window = FakeRunnerWindow(current: LuminaWindowMode.borderlessFullscreen);
      installRunner(window);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.apply(monitor: 1);
      expect(window.moves, [1]);
      expect(LuminaGameDisplay.currentMonitor, (1, 'Second Screen'));
      expect(LuminaGameDisplay.desktopMode((1, 1)), const LuminaDisplayMode(1920, 1080, 60));
      await LuminaGameDisplay.apply(monitor: 1);
      expect(window.moves, [1]);
    });
  });

  group('settings file', () {
    test('mode, resolution and monitor share GameUserSettings.json and come back after a restart', () async {
      final window = FakeRunnerWindow();
      installRunner(window);
      await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameWindow.setMode(LuminaWindowMode.borderlessFullscreen);
      await LuminaGameDisplay.apply(resolution: (1280, 720), monitor: 1);
      await LuminaGameUserSettingsFile.idle;
      final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
      expect(saved['window_mode'], 'borderless_fullscreen');
      expect(saved['screen_resolution'], {'width': 1280, 'height': 720});
      expect(saved['fullscreen_monitor'], {'index': 1, 'device': r'\\.\DISPLAY2', 'name': 'Second Screen'});

      // Next launch: the runner starts windowed on the main monitor.
      resetDisplay();
      final next = FakeRunnerWindow();
      installRunner(next);
      final mode = await LuminaGameWindow.restore(settingsFilePath: settingsPath);
      await LuminaGameDisplay.pendingApply;
      expect(mode, LuminaWindowMode.borderlessFullscreen);
      expect(next.moves, [1]);
      expect(LuminaGameDisplay.screenResolution, (1280, 720));
      expect(LuminaGameDisplay.renderResolution.value, (1280, 720));
      expect(LuminaGameDisplay.fullscreenMonitor, 1);
    });

    test('a restored monitor is found by its device id when the order changed', () {
      LuminaGameDisplay.info.value = LuminaDisplayInfo.fromMap(twoMonitorReport());
      expect(
          LuminaGameDisplay.monitorFrom({
            'fullscreen_monitor': {'index': 0, 'device': r'\\.\DISPLAY2'},
          }),
          1);
      expect(LuminaGameDisplay.monitorFrom({'fullscreen_monitor': {'index': 5}}), isNull);
      expect(LuminaGameDisplay.resolutionFrom({'screen_resolution': [1280, 720]}), (1280, 720));
      expect(LuminaGameDisplay.resolutionFrom({'screen_resolution': {'width': 0, 'height': 0}}), isNull);
    });
  });
}
