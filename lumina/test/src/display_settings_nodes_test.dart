import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../blueprint/display_settings_blueprint.dart';
import 'game/display_test_support.dart';

const _ids = [
  'get_screen_resolution',
  'get_desktop_resolution',
  'get_supported_resolutions',
  'get_supported_refresh_rates',
  'get_monitor_count',
  'get_current_monitor',
  'set_screen_resolution',
  'set_fullscreen_monitor',
];

void main() {
  setUp(resetDisplay);
  tearDown(resetDisplay);

  test('every display node has a spec in Settings|Display, a VM function and a call shape', () {
    for (final id in _ids) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.category, 'Settings|Display', reason: id);
      expect(spec.keywords, containsAll(['resolution', 'screen', 'display', 'monitor']), reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull, reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.builtIn('get_desktop_resolution')!.keywords, contains('refresh rate'));
    expect(LuminaBlueprintNodeLibrary.builtIn('set_screen_resolution')!.keywords, contains('fullscreen'));
  });

  test('the queries read the runner report of the monitor the game is on', () async {
    final window = FakeRunnerWindow();
    installRunner(window);
    await LuminaGameWindow.restore();
    final actor = LuminaActor();
    expect(LuminaBlueprintFunctionLibrary.getDesktopResolution(actor), (width: 3440, height: 1440, refreshRate: 60));
    final supported = LuminaBlueprintFunctionLibrary.getSupportedResolutions(actor).cast<Vector2>();
    expect([for (final v in supported) (v.x.toInt(), v.y.toInt())],
        [(800, 600), (1280, 720), (1280, 1024), (1920, 1080), (2560, 1080), (3440, 1440)]);
    expect(LuminaBlueprintFunctionLibrary.getSupportedRefreshRates(actor, 1920, 1080), [60, 100]);
    expect(LuminaBlueprintFunctionLibrary.getMonitorCount(actor), 2);
    expect(LuminaBlueprintFunctionLibrary.getCurrentMonitor(actor), (index: 0, name: 'DELL U3419W'));
    expect(LuminaBlueprintFunctionLibrary.getScreenResolution(actor), (width: 1280, height: 720));
  });

  test('Set Screen Resolution and Set Fullscreen Monitor round-trip through Apply Scalability Settings', () async {
    final window = FakeRunnerWindow();
    installRunner(window);
    await LuminaGameWindow.restore();
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);

    LuminaBlueprintFunctionLibrary.setScreenResolution(actor, 1920, 1080);
    LuminaBlueprintFunctionLibrary.setFullscreenMonitor(actor, 1);
    expect(window.resizes, isEmpty, reason: 'staged until applied');
    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(actor);
    await LuminaGameDisplay.pendingApply;
    expect(window.moves, [1]);
    expect(window.resizes, [(1920, 1080)]);
    expect(LuminaBlueprintFunctionLibrary.getCurrentMonitor(actor), (index: 1, name: 'Second Screen'));
    // The second monitor's work area is 1040 px high: the window is clamped.
    expect(LuminaBlueprintFunctionLibrary.getScreenResolution(actor), (width: 1904, height: 1001));

    LuminaBlueprintFunctionLibrary.setScreenResolution(actor, 1280, 720);
    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(actor);
    await LuminaGameDisplay.pendingApply;
    expect(LuminaBlueprintFunctionLibrary.getScreenResolution(actor), (width: 1280, height: 720));
  });

  test('a Blueprint display menu runs in the VM without a window', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(displaySettingsBlueprint(), name: 'bp_display_settings').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.tick(1 / 60);
    expect([for (final t in trace) if (t.printed != null) t.printed], ['1920', '1080', '1', '1', 'Display', '0', '0']);
    expect(LuminaGameDisplay.renderResolution.value, (1920, 1080));
  });
}
