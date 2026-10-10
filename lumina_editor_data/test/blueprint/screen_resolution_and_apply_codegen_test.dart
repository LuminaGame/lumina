import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/generated/bp_screen_resolution_and_apply.g.dart';
import '../../../lumina/test/blueprint/screen_resolution_and_apply_blueprint.dart';

/// Set Screen Resolution And Apply compiles to the library call the VM makes,
/// and both apply and keep the resolution.
void main() {
  late Directory temp;

  setUp(() {
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
    LuminaGameUserSettingsFile.resetForTesting();
    temp = Directory.systemTemp.createTempSync('lumina_res_apply_');
  });
  tearDown(() {
    LuminaGameWindow.resetForTesting();
    LuminaGameDisplay.resetForTesting();
    LuminaGameUserSettingsFile.resetForTesting();
    temp.deleteSync(recursive: true);
  });

  test('the node compiles without issues to setScreenResolutionAndApply', () {
    final result = const BlueprintDartGenerator().generate(screenResolutionAndApplyBlueprint(),
        className: 'BpScreenResolutionAndApply', assetPath: 'contents/blueprints/bp_screen_resolution_and_apply.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    expect(result.code, contains('LuminaBlueprintFunctionLibrary.setScreenResolutionAndApply(this, 1600, 900)'));
    expect(result.code, isNot(contains('applyScalabilitySettings')));
  });

  test('VM and generated code apply and persist the same resolution', () async {
    Future<({List<LuminaBlueprintTraceEvent> trace, Map<String, dynamic> settings, (int, int)? render, Object? saved})> run(
        bool generated) async {
      LuminaGameWindow.resetForTesting();
      LuminaGameDisplay.resetForTesting();
      final path = LuminaGameWindow.settingsFileFor('${temp.path}/${generated ? 'gen' : 'vm'}/SaveGames');
      await LuminaGameWindow.restore(settingsFilePath: path);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = generated
          ? BpScreenResolutionAndApply()
          : LuminaBlueprintClass.fromDocument(screenResolutionAndApplyBlueprint(), name: 'bp_screen_resolution_and_apply')
              .instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      await LuminaGameDisplay.pendingApply;
      final saved = (jsonDecode(await File(path).readAsString()) as Map<String, dynamic>)[LuminaGameDisplay.resolutionKey];
      return (
        trace: trace,
        settings: world.userSettings.toMap(),
        render: LuminaGameDisplay.renderResolution.value,
        saved: saved,
      );
    }

    final vm = await run(false);
    final gen = await run(true);
    expect([for (final t in vm.trace) t.registryId], [for (final t in gen.trace) t.registryId]);
    expect([for (final t in gen.trace) if (t.printed != null) t.printed], ['1600', '900']);
    expect([for (final t in gen.trace) t.printed], [for (final t in vm.trace) t.printed]);
    expect(gen.settings, vm.settings);
    expect(gen.render, (1600, 900));
    expect(vm.render, (1600, 900));
    expect(gen.saved, {'width': 1600, 'height': 900});
    expect(vm.saved, {'width': 1600, 'height': 900});
  });
}
