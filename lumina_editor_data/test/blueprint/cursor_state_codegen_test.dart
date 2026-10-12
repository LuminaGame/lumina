import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/cursor_state_blueprint.dart';
import '../../../lumina/test/blueprint/generated/bp_cursor_state.g.dart';

/// Get GPU Memory Usage, Get Render Resolution, Get Show Mouse Cursor and Get
/// Input Mode compile to the library calls the VM makes, and both runs agree.
void main() {
  setUp(LuminaGameDisplay.resetForTesting);
  tearDown(LuminaGameDisplay.resetForTesting);

  test('the getters compile without issues to their library calls', () {
    final result = const BlueprintDartGenerator()
        .generate(cursorStateBlueprint(), className: 'BpCursorState', assetPath: 'contents/blueprints/bp_cursor_state.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    expect(result.code, contains('LuminaBlueprintFunctionLibrary.getShowMouseCursor(this, '));
    expect(result.code, contains('LuminaBlueprintFunctionLibrary.getInputMode(this, '));
    expect(result.code, contains('LuminaBlueprintFunctionLibrary.getGpuMemoryUsage(this)'));
    expect(result.code, contains('LuminaBlueprintFunctionLibrary.getRenderResolution(this)'));
  });

  test('VM and generated code print the same cursor states, GPU memory and render resolution', () {
    ({List<LuminaBlueprintTraceEvent> trace, String mode, bool cursor}) run(bool generated) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = generated
          ? BpCursorState()
          : LuminaBlueprintClass.fromDocument(cursorStateBlueprint(), name: 'bp_cursor_state').instantiate();
      final pc = LuminaPlayerController()..possess(actor as LuminaPawn);
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      return (trace: trace, mode: pc.inputMode, cursor: pc.bShowMouseCursor);
    }

    final vm = run(false);
    final gen = run(true);
    expect([for (final t in gen.trace) if (t.printed != null) t.printed],
        ['false', 'GameOnly', 'true', 'UIOnly', 'false', 'GameOnly', 'false', '1280', '720']);
    expect([for (final t in gen.trace) t.printed], [for (final t in vm.trace) t.printed]);
    expect([for (final t in vm.trace) t.registryId], [for (final t in gen.trace) t.registryId]);
    expect((gen.mode, gen.cursor), (vm.mode, vm.cursor));
  });
}
