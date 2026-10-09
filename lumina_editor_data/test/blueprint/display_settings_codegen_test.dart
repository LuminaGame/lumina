import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/display_settings_blueprint.dart';
import '../../../lumina/test/blueprint/generated/bp_display_settings.g.dart';

/// The screen resolution and monitor nodes compile to the same library calls
/// the VM makes.
void main() {
  setUp(() {
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
  });
  tearDown(() {
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
  });

  test('the display menu Blueprint compiles without issues to the display library calls', () {
    final result = const BlueprintDartGenerator().generate(displaySettingsBlueprint(),
        className: 'BpDisplaySettings', assetPath: 'contents/blueprints/bp_display_settings.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    for (final call in [
      'LuminaBlueprintFunctionLibrary.setScreenResolution(this, 1920, 1080)',
      'LuminaBlueprintFunctionLibrary.setFullscreenMonitor(this, 0)',
      'LuminaBlueprintFunctionLibrary.applyScalabilitySettings(this)',
      'LuminaBlueprintFunctionLibrary.getScreenResolution(this)',
      'LuminaBlueprintFunctionLibrary.getDesktopResolution(this)',
      'LuminaBlueprintFunctionLibrary.getSupportedResolutions(this)',
      'LuminaBlueprintFunctionLibrary.getSupportedRefreshRates(this, 1920, 1080)',
      'LuminaBlueprintFunctionLibrary.getMonitorCount(this)',
      'LuminaBlueprintFunctionLibrary.getCurrentMonitor(this)',
    ]) {
      expect(code, contains(call), reason: call);
    }
  });

  test('VM and generated code apply the same resolution and print the same trace', () {
    ({List<LuminaBlueprintTraceEvent> trace, Map<String, dynamic> settings, (int, int)? render}) run(bool generated) {
      LuminaGameDisplay.resetForTesting();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = generated
          ? BpDisplaySettings()
          : LuminaBlueprintClass.fromDocument(displaySettingsBlueprint(), name: 'bp_display_settings').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      return (trace: trace, settings: world.userSettings.toMap(), render: LuminaGameDisplay.renderResolution.value);
    }

    final vm = run(false);
    final gen = run(true);
    expect([for (final t in vm.trace) t.registryId], [for (final t in gen.trace) t.registryId]);
    expect([for (final t in gen.trace) if (t.printed != null) t.printed], ['1920', '1080', '1', '1', 'Display', '0', '0']);
    expect([for (final t in gen.trace) t.printed], [for (final t in vm.trace) t.printed]);
    expect(gen.settings, vm.settings);
    expect(gen.render, (1920, 1080));
    expect(vm.render, (1920, 1080));
  });
}
