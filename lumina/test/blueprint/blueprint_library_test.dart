import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// One model, one node library, one function library.
void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/blueprint/fixtures/editor_character.json').readAsStringSync()) as Map<String, dynamic>;

  group('model', () {
    test('an editor-written Character Blueprint round-trips; only pin type names are normalised', () {
      final raw = fixture();
      final doc = LuminaBlueprintDocument.fromJson(raw);
      expect(doc.parentClass, 'LuminaCharacter');
      expect(doc.components.map((c) => c.id), ['root_capsule', 'arrow_comp', 'spring_arm', 'follow_cam', 'skm_mesh', 'char_move']);
      expect(doc.components.firstWhere((c) => c.id == 'skm_mesh').properties['location'], [0.0, 0.0, -90.0]);
      expect(doc.variables.single.type, LuminaPinType.float);
      final tick = doc.eventGraph.node('n_tick')!;
      expect(tick.pin('delta_seconds')!.type, LuminaPinType.float, reason: 'number → float');
      expect(doc.eventGraph.node('n_move')!.pin('world_dir')!.type, LuminaPinType.vector, reason: 'vector3 → vector');
      expect(doc.eventGraph.node('n_print')!.literals['in_string'], 'hi');

      // Everything but the type names is unchanged.
      final once = doc.toJson();
      String normalise(String json) => json.replaceAll('"number"', '"float"').replaceAll('"vector3"', '"vector"');
      expect(jsonEncode(once), normalise(jsonEncode(raw)));
      // A second round trip is byte-identical.
      expect(jsonEncode(LuminaBlueprintDocument.fromJson(jsonDecode(jsonEncode(once)) as Map<String, dynamic>).toJson()),
          jsonEncode(once));
    });
  });

  group('node library', () {
    test('every spec has a unique id, pins, and an exec input exactly when it executes', () {
      final ids = <String>{};
      for (final s in LuminaBlueprintNodeLibrary.all) {
        expect(ids.add(s.id), isTrue, reason: 'duplicate ${s.id}');
        // A signature-driven node declares its pins from the document.
        if (LuminaBlueprintNodeLibrary.dynamicPinNodes.contains(s.id)) continue;
        expect(s.inputs.length + s.outputs.length, greaterThan(0), reason: s.id);
        final executes = s.kind == LuminaBlueprintNodeKind.impure ||
            s.kind == LuminaBlueprintNodeKind.flow ||
            s.kind == LuminaBlueprintNodeKind.latent;
        expect(s.hasExecIn, executes, reason: s.id);
      }
    });

    test('every non-event node is exactly one of: a function-table entry or an intrinsic', () {
      for (final s in LuminaBlueprintNodeLibrary.all.where((s) => s.kind != LuminaBlueprintNodeKind.event)) {
        final inTable = LuminaBlueprintFunctionLibrary.functions.containsKey(s.id);
        final intrinsic = LuminaBlueprintNodeLibrary.intrinsics.contains(s.id);
        expect(inTable != intrinsic, isTrue, reason: '${s.id}: table $inTable, intrinsic $intrinsic');
      }
      for (final id in LuminaBlueprintFunctionLibrary.functions.keys) {
        expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: 'table entry $id has no spec');
      }
    });

    test('dynamic pins: an input action types its value, a variable node its value', () {
      final context = LuminaBlueprintTypeContext(
        variables: const [LuminaBlueprintVariable(name: 'LookSensitivity', typeName: 'Float', defaultValue: 0.5)],
        inputActions: const [luminaTemplateMoveAction, luminaTemplateJumpAction],
      );
      final move = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.enhancedInputAction,
          nodeId: 'm', literals: {'action': 'IA_Move'}, context: context);
      expect(move.title, 'IA_Move');
      expect(move.pin('action_value')!.type, LuminaPinType.vector2D);
      final jump = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.enhancedInputAction,
          nodeId: 'j', literals: {'action': 'IA_Jump'}, context: context);
      expect(jump.pin('action_value')!.type, LuminaPinType.boolean);
      final get = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet,
          nodeId: 'g', literals: {'variable': 'LookSensitivity'}, context: context);
      expect(get.pin('value')!.type, LuminaPinType.float);
      expect(get.title, 'Get LookSensitivity');
    });
  });

  group('function library', () {
    ({LuminaTemplateCharacter character, LuminaPlayerController pc}) possessed() {
      final character = LuminaTemplateCharacter(thirdPerson: true);
      final pc = LuminaPlayerController()..possess(character);
      return (character: character, pc: pc);
    }

    test('forward/right vectors are the ones LuminaTemplateCharacter.onMove uses', () {
      for (final yaw in [0.0, 30.0, 90.0, -45.0, 170.0]) {
        final r = yaw * math.pi / 180;
        final forward = LuminaBlueprintFunctionLibrary.toRuntime(
            LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator(0, 0, yaw)));
        final right = LuminaBlueprintFunctionLibrary.toRuntime(
            LuminaBlueprintFunctionLibrary.getRightVector(LuminaRotator(0, 0, yaw)));
        expect(forward.x, closeTo(math.sin(r), 1e-9));
        expect(forward.y, closeTo(0, 1e-9));
        expect(forward.z, closeTo(-math.cos(r), 1e-9));
        expect(right.x, closeTo(math.cos(r), 1e-9));
        expect(right.z, closeTo(math.sin(r), 1e-9));
      }
    });

    test('control rotation round-trips between the controller and a rotator', () {
      final p = possessed();
      p.pc.controlRotation = Vector3(-20, 75, 5);
      final rot = LuminaBlueprintFunctionLibrary.getControlRotation(p.character);
      expect([rot.pitch, rot.yaw, rot.roll], [-20, 75, -5]);
      expect(LuminaBlueprintFunctionLibrary.toControlRotation(rot), Vector3(-20, 75, 5));
    });

    test('Add Movement Input feeds the movement exactly as onMove does', () {
      final bp = possessed();
      final dart = possessed();
      final yawRot = LuminaBlueprintFunctionLibrary.getControlRotation(bp.character);
      LuminaBlueprintFunctionLibrary.addMovementInput(
          bp.character, LuminaBlueprintFunctionLibrary.getForwardVector(yawRot), 1.0);
      dart.character.onMove(LuminaInputActionValue.axis2D(Vector2(0, 1)));
      expect(bp.character.characterMovement.inputVector, dart.character.characterMovement.inputVector);
      expect(bp.character.characterMovement.inputVector.length, closeTo(1, 1e-9));
    });

    test('controller yaw and pitch input move the control rotation like onLook', () {
      final p = possessed();
      LuminaBlueprintFunctionLibrary.addControllerYawInput(p.character, 2.5);
      LuminaBlueprintFunctionLibrary.addControllerPitchInput(p.character, -1.5);
      expect(p.pc.controlRotation.y, 2.5);
      expect(p.pc.controlRotation.x, -1.5);
    });

    test('Stop Jumping cuts a jump short', () {
      double apex({double? stopAt}) {
        final world = LuminaWorld(worldType: LuminaWorldType.game);
        world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
        world.persistentLevel.registerActor(
            LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(4000, 0, 4000), color: Vector3.all(0.5)));
        final character = LuminaCharacter(location: Vector3(0, 100, 0));
        world.persistentLevel.registerActor(character);
        world.beginPlay();
        for (var i = 0; i < 60; i++) {
          world.tick(1 / 60);
        }
        final ground = character.actorLocation.y;
        LuminaBlueprintFunctionLibrary.jump(character);
        var top = ground;
        for (var i = 1; i <= 90; i++) {
          world.tick(1 / 60);
          if (stopAt != null && (i / 60 - stopAt).abs() < 1e-9) LuminaBlueprintFunctionLibrary.stopJumping(character);
          top = math.max(top, character.actorLocation.y);
        }
        world.cleanup();
        return top - ground;
      }

      final held = apex();
      final tapped = apex(stopAt: 0.1);
      expect(held, greaterThan(50));
      expect(tapped, lessThan(held * 0.9), reason: 'held $held cm vs tapped $tapped cm');
    });

    test('struct and math nodes', () {
      final b = LuminaBlueprintFunctionLibrary.breakVector2D(Vector2(0.3, -1));
      expect([b.x, b.y], [0.3, -1]);
      expect(LuminaBlueprintFunctionLibrary.vectorLengthXY(Vector3(300, 400, 900)), 500);
      expect(LuminaBlueprintFunctionLibrary.floatDivide(3, 0), 0);
      expect(LuminaBlueprintFunctionLibrary.floatClamp(5, 0, 1), 1);
      final out = LuminaBlueprintFunctionLibrary.functions['break_rotator']!(
          LuminaBlueprintCallContext(LuminaActor()), {'in_rot': const LuminaRotator(1, 2, 3)});
      expect(out, {'x': 1.0, 'y': 2.0, 'z': 3.0});
    });

    test('user interface and player nodes create, show, and update widgets', () {
      final p = possessed();
      final ctx = LuminaBlueprintCallContext(p.character);

      // Create Widget
      final widgetOut = LuminaBlueprintFunctionLibrary.functions['create_widget']!(
        ctx,
        {'class': 'WBP_PlayerHUD', 'owning_player': p.pc},
      );
      final widget = widgetOut['return_value'] as Map<String, Object?>;
      expect(widget['class'], 'WBP_PlayerHUD');
      expect(widget['owner'], p.pc);
      expect(widget['inViewport'], false);

      // Add to Viewport
      LuminaBlueprintFunctionLibrary.functions['add_to_viewport']!(
        ctx,
        {'target': widget, 'z_order': 1},
      );
      expect(widget['inViewport'], true);
      expect(widget['zOrder'], 1);

      // Is in Viewport
      final inViewportOut = LuminaBlueprintFunctionLibrary.functions['is_in_viewport']!(
        ctx,
        {'target': widget},
      );
      expect(inViewportOut['return_value'], true);

      // Set Text & Percent & Visibility
      LuminaBlueprintFunctionLibrary.functions['set_widget_text']!(
        ctx,
        {'target': widget, 'in_text': 'Health: 100'},
      );
      expect(widget['text'], 'Health: 100');

      LuminaBlueprintFunctionLibrary.functions['set_widget_percent']!(
        ctx,
        {'target': widget, 'in_percent': 0.85},
      );
      expect(widget['percent'], 0.85);

      LuminaBlueprintFunctionLibrary.functions['set_widget_visibility']!(
        ctx,
        {'target': widget, 'in_visibility': 'Hidden'},
      );
      expect(widget['visibility'], 'Hidden');

      // Remove from Parent
      LuminaBlueprintFunctionLibrary.functions['remove_from_parent']!(
        ctx,
        {'target': widget},
      );
      expect(widget['inViewport'], false);

      // Player Controller and Input Mode
      final pcOut = LuminaBlueprintFunctionLibrary.functions['get_player_controller']!(
        ctx,
        {'player_index': 0},
      );
      expect(pcOut['return_value'], same(p.pc));

      LuminaBlueprintFunctionLibrary.functions['set_show_mouse_cursor']!(
        ctx,
        {'target': p.pc, 'show_mouse_cursor': true},
      );
      expect(p.pc.bShowMouseCursor, isTrue);

      LuminaBlueprintFunctionLibrary.functions['set_input_mode_game_and_ui']!(
        ctx,
        {'target': p.pc, 'in_widget_to_focus': widget, 'lock_mouse_to_viewport': true},
      );
      expect(p.pc.inputMode, 'GameAndUI');

      LuminaBlueprintFunctionLibrary.functions['set_input_mode_ui_only']!(
        ctx,
        {'target': p.pc, 'in_widget_to_focus': widget},
      );
      expect(p.pc.inputMode, 'UIOnly');

      LuminaBlueprintFunctionLibrary.functions['set_input_mode_game_only']!(
        ctx,
        {'target': p.pc},
      );
      expect(p.pc.inputMode, 'GameOnly');
    });

    test('LuminaWidgetSubsystem tracks active widgets added to viewport', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final character = LuminaCharacter();
      world.persistentLevel.registerActor(character);

      final w1 = LuminaBlueprintFunctionLibrary.createWidget(character, 'WBP_HUD') as Map<String, Object?>;
      final w2 = LuminaBlueprintFunctionLibrary.createWidget(character, 'WBP_Menu') as Map<String, Object?>;

      final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
      expect(subsystem.widgets, isEmpty);

      LuminaBlueprintFunctionLibrary.addToViewport(character, w1, 2);
      expect(subsystem.widgets.length, 1);
      expect(subsystem.widgets.first['class'], 'WBP_HUD');

      LuminaBlueprintFunctionLibrary.addToViewport(character, w2, 0);
      expect(subsystem.widgets.length, 2);
      // Sorted by zOrder ascending
      expect(subsystem.widgets.first['class'], 'WBP_Menu');
      expect(subsystem.widgets.last['class'], 'WBP_HUD');

      LuminaBlueprintFunctionLibrary.setWidgetText(character, w1, 'Ammo: 30');
      expect(w1['text'], 'Ammo: 30');

      LuminaBlueprintFunctionLibrary.removeFromParent(character, w1);
      expect(subsystem.widgets.length, 1);
      expect(subsystem.widgets.first['class'], 'WBP_Menu');

      world.cleanup();
      expect(subsystem.widgets, isEmpty);
    });
  });

  group('validator', () {
    LuminaBlueprintDocument docWith(List<LuminaBlueprintNode> nodes, List<LuminaBlueprintWire> wires,
            {List<LuminaBlueprintVariable> variables = const []}) =>
        LuminaBlueprintDocument(
          parentClass: 'LuminaCharacter',
          eventGraph: LuminaBlueprintGraph(nodes: nodes, wires: wires),
          variables: [...variables],
        );
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals);
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: '$from.$fromPin>$to.$toPin', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    List<String> errors(List<LuminaBlueprintDiagnostic> d) => [for (final x in d.where((x) => x.isError)) '${x.nodeId}.${x.pinId}: ${x.message}'];

    test('the editor fixture validates clean', () {
      final d = validateBlueprint(LuminaBlueprintDocument.fromJson(fixture()));
      expect(d.where((x) => x.isError), isEmpty, reason: '$d');
    });

    test('a float wired into a vector pin is an error on that pin', () {
      final d = validateBlueprint(docWith([
        place('event_tick', 'tick'),
        place('add_movement_input', 'move'),
      ], [
        wire('tick', 'exec_tick_out', 'move', 'exec_move_in'),
        wire('tick', 'delta_seconds', 'move', 'world_dir'),
      ]));
      expect(errors(d), ['move.world_dir: Cannot connect float to vector.']);
    });

    test('two wires from one exec output', () {
      final d = validateBlueprint(docWith([
        place('event_beginplay', 'b'),
        place('jump', 'j1'),
        place('jump', 'j2'),
      ], [
        wire('b', 'exec_out', 'j1', 'exec_in'),
        wire('b', 'exec_out', 'j2', 'exec_in'),
      ]));
      expect(errors(d), ['b.exec_out: An exec output can have one wire; use a Sequence to run several.']);
    });

    test('a cycle through pure nodes', () {
      final d = validateBlueprint(docWith([
        place('float_add', 'a'),
        place('float_add', 'b'),
      ], [
        wire('a', 'return_value', 'b', 'a'),
        wire('b', 'return_value', 'a', 'a'),
      ]));
      expect(errors(d), isNotEmpty);
      expect(errors(d).every((e) => e.contains('cycle')), isTrue, reason: '${errors(d)}');
    });

    test('an input action missing from the project, and an undeclared variable', () {
      final d = validateBlueprint(
        docWith([
          place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'ia', {'action': 'IA_Missing'}),
          place(LuminaBlueprintNodeLibrary.variableGet, 'v', {'variable': 'Nope'}),
        ], const []),
        inputActions: const [luminaTemplateMoveAction],
      );
      expect(errors(d), [
        "ia.null: Input action 'IA_Missing' does not exist in the project.",
        "v.null: Get names an unknown variable 'Nope'.",
      ]);
    });

    test('a legacy axis input loads with a deprecation warning and is kept', () {
      final doc = docWith([place('event_input_axis', 'legacy')], const []);
      final d = validateBlueprint(doc);
      expect(d.single.severity, LuminaBlueprintSeverity.warning);
      expect(d.single.message, contains('EnhancedInputAction'));
      expect(LuminaBlueprintDocument.fromJson(doc.toJson()).eventGraph.node('legacy'), isNotNull);
    });

    test('a required struct input left unconnected', () {
      final d = validateBlueprint(docWith([place('break_vector2d', 'bv')], const []));
      expect(errors(d), ["bv.in_vec: 'In Vec' must be connected."]);
    });
  });
}
