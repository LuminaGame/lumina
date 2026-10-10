import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/frame_pacing_settings_blueprint.dart';

/// Set Target FPS / Set VSync Enabled and their Get nodes compile to the
/// library calls the VM makes, and the generated game hands the project's
/// settings to the game host as the defaults.
void main() {
  test('the frame rate nodes compile without issues to the library calls', () {
    final result = const BlueprintDartGenerator().generate(framePacingSettingsBlueprint(),
        className: 'BpFramePacingSettings', assetPath: 'contents/blueprints/bp_frame_pacing_settings.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    for (final call in [
      'LuminaBlueprintFunctionLibrary.setTargetFps(this, 30)',
      'LuminaBlueprintFunctionLibrary.setVsyncEnabled(this, false)',
      'LuminaBlueprintFunctionLibrary.applyScalabilitySettings(this)',
      'LuminaBlueprintFunctionLibrary.getTargetFps(this)',
      'LuminaBlueprintFunctionLibrary.getVsyncEnabled(this)',
    ]) {
      expect(code, contains(call), reason: call);
    }
    // Get after Apply reads again: the value in force, not a cached one.
    expect(RegExp(r'LuminaBlueprintFunctionLibrary\.getTargetFps\(this\)').allMatches(code).length, greaterThanOrEqualTo(2));
  });

  test('the generated main() passes the project Target FPS and VSync to the game host', () {
    final main = DartCodeGeneratorService().generateMainDart(projectName: 'Paced', targetFps: 60, vsyncEnabled: true);
    expect(main, contains('targetFps: 60,'));
    expect(main, contains('vsyncEnabled: true,'));
    // The player's saved choice is restored before runApp.
    expect(main.indexOf('LuminaGameWindow.restore('), lessThan(main.indexOf('runApp(')));
  });
}
