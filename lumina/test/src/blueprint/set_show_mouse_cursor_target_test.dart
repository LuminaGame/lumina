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

  test('a Pawn or Character Target acts on the Player Controller possessing it', () {
    final character = LuminaTemplateCharacter(thirdPerson: true);
    final pc = LuminaPlayerController()..possess(character);
    final pawn = LuminaPawn();
    final pawnPc = LuminaPlayerController()..possess(pawn);
    // Self is an unrelated actor: only Target can name the controller.
    final ctx = LuminaBlueprintCallContext(LuminaActor());
    final fns = LuminaBlueprintFunctionLibrary.functions;

    fns['set_show_mouse_cursor']!(ctx, {'target': character, 'show_mouse_cursor': true});
    expect(pc.bShowMouseCursor, isTrue);
    fns['set_input_mode_ui_only']!(ctx, {'target': character});
    expect(pc.inputMode, 'UIOnly');
    fns['set_input_mode_game_and_ui']!(ctx, {'target': pawn});
    expect(pawnPc.inputMode, 'GameAndUI');
    fns['set_input_mode_game_only']!(ctx, {'target': character});
    expect(pc.inputMode, 'GameOnly');
    fns['set_show_mouse_cursor']!(ctx, {'target': pawn, 'show_mouse_cursor': true});
    expect(pawnPc.bShowMouseCursor, isTrue);
  });

  test('a Target with no Player Controller logs one warning instead of failing silently', () {
    final logs = <String>[];
    final previous = LuminaBlueprintFunctionLibrary.onLog;
    LuminaBlueprintFunctionLibrary.onLog = (self, message, level) {
      if (level >= 900) logs.add(message);
    };
    addTearDown(() => LuminaBlueprintFunctionLibrary.onLog = previous);
    final ctx = LuminaBlueprintCallContext(LuminaActor());
    final unpossessed = LuminaPawn();
    final fns = LuminaBlueprintFunctionLibrary.functions;

    fns['set_show_mouse_cursor']!(ctx, {'target': unpossessed, 'show_mouse_cursor': true});
    fns['set_show_mouse_cursor']!(ctx, {'target': unpossessed, 'show_mouse_cursor': false});
    fns['set_input_mode_ui_only']!(ctx, {'target': 'not a controller'});

    expect(logs.where((m) => m.contains('Set Show Mouse Cursor')), hasLength(1), reason: logs.join('\n'));
    expect(logs.where((m) => m.contains('Set Input Mode UI Only')), hasLength(1), reason: logs.join('\n'));
    expect(logs.first, contains('Player Controller'));
  });

  group('Target type diagnostics', () {
    List<LuminaBlueprintDiagnostic> validateTarget(String source, {String pin = 'return_value'}) {
      final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
      final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Probe');
      LuminaBlueprintNode p(String id, String node) =>
          LuminaBlueprintNodeLibrary.place(id, nodeId: node, context: context);
      final impureSource = source == 'create_widget';
      doc.eventGraph.nodes.addAll([p('event_beginplay', 'begin'), p(source, 'src'), p('set_show_mouse_cursor', 'cursor')]);
      doc.eventGraph.wires.addAll([
        if (impureSource) ...const [
          LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'src', toPinId: 'exec_in'),
          LuminaBlueprintWire(id: 'w1', fromNodeId: 'src', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
        ] else
          const LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
        LuminaBlueprintWire(id: 'w2', fromNodeId: 'src', fromPinId: pin, toNodeId: 'cursor', toPinId: 'target'),
      ]);
      return validateBlueprint(doc, className: 'BP_Probe').where((d) => d.nodeId == 'cursor' && d.pinId == 'target').toList();
    }

    test('Get Player Controller compiles clean', () {
      expect(validateTarget('get_player_controller'), isEmpty);
    });

    test('a Character or Pawn Target warns that its controller is used', () {
      for (final source in ['get_player_character', 'get_player_pawn']) {
        final d = validateTarget(source);
        expect(d, hasLength(1), reason: '$source: ${d.join('\n')}');
        expect(d.single.severity, LuminaBlueprintSeverity.warning, reason: source);
        expect(d.single.message, contains('Player Controller'), reason: source);
        expect(d.single.message, contains('possesses'), reason: source);
      }
    });

    test('a widget Target is an error', () {
      final d = validateTarget('create_widget');
      expect(d.where((x) => x.isError), hasLength(1), reason: d.join('\n'));
      expect(d.single.message, contains('Player Controller'));
    });

    test('a vector Target is an error', () {
      final d = validateTarget('make_vector');
      expect(d.where((x) => x.isError), isNotEmpty, reason: d.join('\n'));
    });
  });
}
