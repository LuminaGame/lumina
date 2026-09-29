import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Variant A — Set Show Mouse Cursor / Set Input Mode * with
/// an unwired Target silently did nothing. Lumina warns at compile time and acts on player 0's controller.
void main() {
  test('an unwired Target acts on the player-0 controller', () {
    final character = LuminaTemplateCharacter(thirdPerson: true);
    final pc = LuminaPlayerController()..possess(character);
    final ctx = LuminaBlueprintCallContext(character);
    final fns = LuminaBlueprintFunctionLibrary.functions;

    fns['set_show_mouse_cursor']!(ctx, {'show_mouse_cursor': true});
    expect(pc.bShowMouseCursor, isTrue);
    fns['set_input_mode_ui_only']!(ctx, const {});
    expect(pc.inputMode, 'UIOnly');
    fns['set_input_mode_game_and_ui']!(ctx, const {});
    expect(pc.inputMode, 'GameAndUI');
    fns['set_input_mode_game_only']!(ctx, const {});
    expect(pc.inputMode, 'GameOnly');
  });

  test('an unwired Target compiles with a warning on that node; a wired one does not', () {
    LuminaBlueprintDocument graph({required bool wired}) {
      final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
      final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Probe');
      LuminaBlueprintNode p(String id, String node, [Map<String, dynamic>? literals]) =>
          LuminaBlueprintNodeLibrary.place(id, nodeId: node, literals: literals, context: context);
      doc.eventGraph.nodes.addAll([
        p('event_beginplay', 'begin'),
        p('set_show_mouse_cursor', 'cursor'),
        p('set_input_mode_ui_only', 'mode'),
        if (wired) p('get_player_controller', 'pc'),
      ]);
      doc.eventGraph.wires.addAll([
        const LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
        const LuminaBlueprintWire(id: 'w2', fromNodeId: 'cursor', fromPinId: 'exec_out', toNodeId: 'mode', toPinId: 'exec_in'),
        if (wired) ...const [
          LuminaBlueprintWire(id: 'w3', fromNodeId: 'pc', fromPinId: 'return_value', toNodeId: 'cursor', toPinId: 'target'),
          LuminaBlueprintWire(id: 'w4', fromNodeId: 'pc', fromPinId: 'return_value', toNodeId: 'mode', toPinId: 'target'),
        ],
      ]);
      return doc;
    }

    final unwired = validateBlueprint(graph(wired: false), className: 'BP_Probe');
    expect(unwired.where((d) => d.isError), isEmpty, reason: unwired.join('\n'));
    final warnings = unwired.where((d) => d.severity == LuminaBlueprintSeverity.warning && d.pinId == 'target').toList();
    expect(warnings.map((d) => d.nodeId), containsAll(['cursor', 'mode']));
    expect(warnings.first.message, contains('Player Controller 0'));

    final wired = validateBlueprint(graph(wired: true), className: 'BP_Probe');
    expect(wired.where((d) => d.pinId == 'target'), isEmpty, reason: wired.join('\n'));
  });
}
