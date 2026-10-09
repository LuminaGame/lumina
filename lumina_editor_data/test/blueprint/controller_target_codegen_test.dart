import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Set Show Mouse Cursor / Set Input Mode with a Character wired into Target:
/// generated code passes the Character to the same library call the VM makes,
/// which resolves it to the Player Controller possessing it.
void main() {
  LuminaBlueprintDocument cursorToggle() {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Toggle');
    LuminaBlueprintNode p(String id, String node, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: node, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('get_player_character', 'character'),
      p('set_show_mouse_cursor', 'cursor', {'show_mouse_cursor': true}),
      p('set_input_mode_game_and_ui', 'mode'),
    ]);
    doc.eventGraph.wires.addAll(const [
      LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w2', fromNodeId: 'cursor', fromPinId: 'exec_out', toNodeId: 'mode', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w3', fromNodeId: 'character', fromPinId: 'return_value', toNodeId: 'cursor', toPinId: 'target'),
      LuminaBlueprintWire(id: 'w4', fromNodeId: 'character', fromPinId: 'return_value', toNodeId: 'mode', toPinId: 'target'),
    ]);
    return doc;
  }

  test('a Character Target compiles to the controller-resolving library calls, with a warning', () {
    final result = const BlueprintDartGenerator().generate(cursorToggle(),
        className: 'BpToggle', assetPath: 'contents/blueprints/bp_toggle.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    expect(result.issues.where((i) => i.pinId == 'target' && i.message.contains('possesses')), hasLength(2),
        reason: result.issues.join('\n'));
    final code = result.code!;
    expect(code, contains('LuminaBlueprintFunctionLibrary.setShowMouseCursor(this, '));
    expect(code, contains('LuminaBlueprintFunctionLibrary.getPlayerCharacter(this, 0)'));
    expect(code, contains('LuminaBlueprintFunctionLibrary.setInputModeGameAndUI(this, '));
  });

  test('VM and generated call resolve a Character Target to its Player Controller', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(cursorToggle(), name: 'bp_toggle').instantiate();
    final pc = LuminaPlayerController()..possess(actor as LuminaPawn);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    expect(pc.bShowMouseCursor, isTrue);
    expect(pc.inputMode, 'GameAndUI');

    // The generated body's calls, made directly.
    final pc2 = LuminaPlayerController()..possess(LuminaTemplateCharacter(thirdPerson: true));
    final character = pc2.pawn!;
    LuminaBlueprintFunctionLibrary.setShowMouseCursor(LuminaActor(), character, true);
    LuminaBlueprintFunctionLibrary.setInputModeGameAndUI(LuminaActor(), character);
    expect(pc2.bShowMouseCursor, isTrue);
    expect(pc2.inputMode, 'GameAndUI');
  });
}
