import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../blueprint/cursor_state_blueprint.dart';
import 'game/display_test_support.dart';

void main() {
  setUp(resetDisplay);
  tearDown(resetDisplay);

  test('the four nodes have specs, VM functions and call shapes', () {
    final expected = {
      'get_gpu_memory_usage': ('Lumina|Engine', <String>[], ['used_mb', 'budget_mb', 'available']),
      'get_render_resolution': ('Settings|Display', <String>[], ['width', 'height']),
      'get_show_mouse_cursor': ('Input|Mouse Interaction', ['target'], ['return_value']),
      'get_input_mode': ('Input', ['target'], ['return_value']),
    };
    for (final MapEntry(key: id, value: (category, inputs, outputs)) in expected.entries) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.category, category, reason: id);
      expect(spec.kind, LuminaBlueprintNodeKind.pure, reason: id);
      expect([for (final p in spec.inputs) p.id], inputs, reason: id);
      expect([for (final p in spec.outputs) p.id], outputs, reason: id);
      expect(spec.tooltip, isNotEmpty, reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull, reason: id);
    }
    final gpu = LuminaBlueprintNodeLibrary.builtIn('get_gpu_memory_usage')!;
    expect([for (final p in gpu.outputs) p.type], [LuminaPinType.float, LuminaPinType.float, LuminaPinType.boolean]);
    expect(gpu.keywords, containsAll(['vram', 'gpu', 'memory']));
  });

  test('without a native engine GPU memory is unavailable and the render resolution is the screen resolution', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    expect(LuminaBlueprintFunctionLibrary.getGpuMemoryUsage(actor), (usedMb: 0.0, budgetMb: 0.0, available: false));
    expect(LuminaBlueprintFunctionLibrary.getRenderResolution(actor), (width: 1280, height: 720));
    expect(LuminaBlueprintFunctionLibrary.getRenderResolution(actor), LuminaBlueprintFunctionLibrary.getScreenResolution(actor));
  });

  test('the cursor and input mode getters read what the setters wrote', () {
    final character = LuminaTemplateCharacter(thirdPerson: true);
    final pc = LuminaPlayerController()..possess(character);
    final ctx = LuminaBlueprintCallContext(character);
    final fns = LuminaBlueprintFunctionLibrary.functions;
    Object? cursor() => fns['get_show_mouse_cursor']!(ctx, const {})['return_value'];
    Object? mode() => fns['get_input_mode']!(ctx, const {})['return_value'];

    expect((cursor(), mode()), (false, 'GameOnly'));
    fns['set_show_mouse_cursor']!(ctx, {'show_mouse_cursor': true});
    fns['set_input_mode_ui_only']!(ctx, const {});
    expect((cursor(), mode()), (true, 'UIOnly'));
    fns['set_input_mode_game_and_ui']!(ctx, const {});
    expect(mode(), 'GameAndUI');
    expect(pc.inputMode, 'GameAndUI');
    // A wired Target that is the possessed character reads its controller.
    expect(fns['get_input_mode']!(LuminaBlueprintCallContext(LuminaActor()), {'target': character})['return_value'],
        'GameAndUI');
  });

  test('without a player controller the getters answer false and GameOnly, silently', () {
    final logs = <String>[];
    final previous = LuminaBlueprintFunctionLibrary.onLog;
    LuminaBlueprintFunctionLibrary.onLog = (self, message, level) => logs.add(message);
    addTearDown(() => LuminaBlueprintFunctionLibrary.onLog = previous);
    final actor = LuminaActor();
    expect(LuminaBlueprintFunctionLibrary.getShowMouseCursor(actor), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getInputMode(actor), 'GameOnly');
    expect(logs, isEmpty);
  });

  test('a Blueprint saves, changes and restores the cursor state in the VM', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(cursorStateBlueprint(), name: 'bp_cursor_state').instantiate();
    final pc = LuminaPlayerController()..possess(actor as LuminaPawn);
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.tick(1 / 60);
    expect([for (final t in trace) if (t.printed != null) t.printed],
        ['false', 'GameOnly', 'true', 'UIOnly', 'false', 'GameOnly', 'false', '1280', '720']);
    expect((pc.bShowMouseCursor, pc.inputMode), (false, 'GameOnly'));
  });
}
