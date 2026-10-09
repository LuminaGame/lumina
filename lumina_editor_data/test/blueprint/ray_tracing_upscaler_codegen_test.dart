import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/generated/bp_graphics_settings.g.dart';
import '../../../lumina/test/blueprint/rendering_features_blueprint.dart';

/// The ray tracing and upscaler nodes compile to the same library calls the
/// VM makes.
void main() {
  test('the game settings Blueprint compiles without issues to the ray tracing and upscaler library calls', () {
    final result = const BlueprintDartGenerator().generate(renderingFeaturesBlueprint(),
        className: 'BpGraphicsSettings', assetPath: 'contents/blueprints/bp_graphics_settings.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    for (final call in [
      'LuminaBlueprintFunctionLibrary.setRayTracingEnabled(this, true)',
      'LuminaBlueprintFunctionLibrary.setRayTracedShadowsEnabled(this, false)',
      'LuminaBlueprintFunctionLibrary.setRestirEnabled(this, true)',
      'LuminaBlueprintFunctionLibrary.setRestirCandidates(this, 16)',
      'LuminaBlueprintFunctionLibrary.setRestirSpatialSamples(this, 4)',
      "LuminaBlueprintFunctionLibrary.setUpscaler(this, 'DLSS')",
      "LuminaBlueprintFunctionLibrary.setUpscalerQuality(this, 'Performance')",
      'LuminaBlueprintFunctionLibrary.setUpscalerSharpness(this, 0.7)',
      'LuminaBlueprintFunctionLibrary.setFrameGenerationEnabled(this, true)',
      'LuminaBlueprintFunctionLibrary.applyScalabilitySettings(this)',
      'LuminaBlueprintFunctionLibrary.getUpscaler(this)',
      'LuminaBlueprintFunctionLibrary.getActiveUpscaler(this)',
      'LuminaBlueprintFunctionLibrary.isDlssSupported(this)',
      'LuminaBlueprintFunctionLibrary.isRayTracingActive(this)',
    ]) {
      expect(code, contains(call), reason: call);
    }
  });

  test('VM and generated code set the same settings and print the same trace', () {
    ({List<LuminaBlueprintTraceEvent> trace, LuminaUserSettingsSubsystem settings}) run(bool generated) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = generated
          ? BpGraphicsSettings()
          : LuminaBlueprintClass.fromDocument(renderingFeaturesBlueprint(), name: 'bp_graphics_settings').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      return (trace: trace, settings: world.userSettings);
    }

    final vm = run(false);
    final gen = run(true);
    expect([for (final t in vm.trace) t.registryId], [for (final t in gen.trace) t.registryId]);
    expect([for (final t in gen.trace) if (t.printed != null) t.printed], ['DLSS', 'None', 'false', 'false']);
    expect([for (final t in gen.trace) t.printed], [for (final t in vm.trace) t.printed]);
    expect(gen.settings.toMap(), vm.settings.toMap());
    expect(gen.settings.renderingFallbacks, vm.settings.renderingFallbacks);
  });
}
