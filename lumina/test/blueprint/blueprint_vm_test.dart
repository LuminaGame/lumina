import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'third_person_blueprint.dart';

/// The VM runs a Blueprint class as a real actor.
void main() {
  LuminaBlueprintDocument editorCharacter() => LuminaBlueprintDocument.fromJson(
      jsonDecode(File('test/blueprint/fixtures/editor_character.json').readAsStringSync()) as Map<String, dynamic>);

  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  LuminaBlueprintDocument graph(
    List<LuminaBlueprintNode Function(LuminaBlueprintTypeContext)> nodes,
    List<LuminaBlueprintWire> wires, {
    List<LuminaBlueprintVariable> variables = const [],
    String parentClass = 'LuminaActor',
  }) {
    final context = LuminaBlueprintTypeContext(variables: variables);
    return LuminaBlueprintDocument(
      parentClass: parentClass,
      eventGraph: LuminaBlueprintGraph(nodes: [for (final n in nodes) n(context)], wires: wires),
      variables: [...variables],
    );
  }

  LuminaBlueprintNode Function(LuminaBlueprintTypeContext) node(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      (context) => LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);

  LuminaWorld world() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
    w.persistentLevel.registerActor(
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: Vector3.all(0.5)));
    return w;
  }

  ({LuminaBlueprintInstance actor, List<LuminaBlueprintTraceEvent> trace, LuminaWorld world}) run(LuminaBlueprintDocument doc,
      {int? maxNodes}) {
    final w = world();
    final actor = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Test').instantiate() as LuminaBlueprintInstance;
    if (maxNodes != null) actor.maxNodesPerEvent = maxNodes;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    return (actor: actor, trace: trace, world: w);
  }

  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  test("the editor's default Character Blueprint instantiates with its components and tuning", () {
    final doc = editorCharacter();
    doc.components.firstWhere((c) => c.id == 'skm_mesh').properties['skeletalMeshAsset'] = 'mannequin.glb';
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Character');
    expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
    expect(cls.diagnostics.map((d) => d.message), contains(contains("'initialHealth'")),
        reason: 'an unknown class default is reported, not silently dropped');
    final character = cls.instantiate() as LuminaBlueprintCharacter;
    expect(character.capsuleComponent.capsuleRadius, 35);
    expect(character.capsuleComponent.capsuleHalfHeight, 90);
    final arm = character.blueprintComponents['spring_arm'] as LuminaSpringArmComponent;
    expect(arm.targetArmLength, 400);
    expect(arm.bUsePawnControlRotation, isTrue);
    final camera = character.blueprintComponents['follow_cam'] as LuminaCameraComponent;
    expect(camera.parentComponent, same(arm));
    expect(camera.isActive, isTrue);
    expect(character.characterMovement.maxWalkSpeed, 600);
    expect(character.characterMovement.jumpZVelocity, 700);
    final mesh = character.blueprintComponents['skm_mesh'] as LuminaAnimatedMeshComponent;
    expect(mesh.relativeLocation, Vector3(0, -90, 0), reason: 'authoring [0, 0, -90] is 90 cm below, runtime −Y');
    expect(mesh.parentComponent, same(character.rootComponent), reason: "the capsule's children attach to the actor root");
    expect(character.components.whereType<LuminaCapsuleComponent>().length, 1, reason: 'no second capsule');
  });

  test('BeginPlay prints once; Tick accumulates Delta Seconds into a variable', () {
    const total = LuminaBlueprintVariable(name: 'Total', typeName: 'Float', defaultValue: '0.0');
    final r = run(graph([
      node('event_beginplay', 'begin'),
      node('print_string', 'hi', {'in_string': 'hi'}),
      node('event_tick', 'tick'),
      node(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'Total'}),
      node('float_add', 'add'),
      node(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'Total'}),
    ], [
      wire('begin', 'exec_out', 'hi', 'exec_in'),
      wire('tick', 'exec_tick_out', 'set', 'exec_in'),
      wire('get', 'value', 'add', 'a'),
      wire('tick', 'delta_seconds', 'add', 'b'),
      wire('add', 'return_value', 'set', 'value'),
    ], variables: [total]));
    expect(printed(r.trace), ['hi']);
    for (var i = 0; i < 60; i++) {
      r.world.tick(1 / 60);
    }
    expect(r.actor.variables['Total'] as double, closeTo(1.0, 1e-9));
    expect(printed(r.trace), ['hi'], reason: 'BeginPlay runs once');
  });

  test('Branch reads a pure condition; a pure node runs once per exec step', () {
    const x = LuminaBlueprintVariable(name: 'X', typeName: 'Float', defaultValue: 7.0);
    final r = run(graph([
      node('event_beginplay', 'begin'),
      node(LuminaBlueprintNodeLibrary.variableGet, 'x', {'variable': 'X'}),
      node('float_greater', 'gt', {'b': 5.0}),
      node('branch', 'if'),
      node('print_string', 'yes', {'in_string': 'yes'}),
      node('print_string', 'no', {'in_string': 'no'}),
      // Two impure steps; the first pulls `vec` twice (directly and through
      // Break Vector), the second once.
      node('make_vector', 'vec', {'x': 3.0}),
      node('break_vector', 'parts'),
      node('add_movement_input', 'step1'),
      node('add_movement_input', 'step2'),
    ], [
      wire('begin', 'exec_out', 'if', 'exec_in'),
      wire('x', 'value', 'gt', 'a'),
      wire('gt', 'return_value', 'if', 'condition'),
      wire('if', 'true_out', 'yes', 'exec_in'),
      wire('if', 'false_out', 'no', 'exec_in'),
      wire('yes', 'exec_out', 'step1', 'exec_move_in'),
      wire('vec', 'return_value', 'step1', 'world_dir'),
      wire('vec', 'return_value', 'parts', 'in_vec'),
      wire('parts', 'x', 'step1', 'scale_val'),
      wire('step1', 'exec_move_out', 'step2', 'exec_move_in'),
      wire('vec', 'return_value', 'step2', 'world_dir'),
    ], variables: [x]));
    expect(printed(r.trace), ['yes']);
    expect(r.trace.where((t) => t.nodeId == 'vec').length, 2, reason: 'once in each of the two steps');
    final step1 = r.trace.firstWhere((t) => t.nodeId == 'step1');
    expect(step1.values['scale_val'], 3.0);
  });

  test('Sequence runs Then 0 before Then 1; Delay resumes 0.5 s later and ignores retriggers', () {
    final r = run(graph([
      node('event_beginplay', 'begin'),
      node('sequence', 'seq'),
      node('print_string', 'a', {'in_string': 'a'}),
      node('print_string', 'b', {'in_string': 'b'}),
      node('event_tick', 'tick'),
      node('delay', 'wait', {'duration': 0.5}),
      node('print_string', 'late', {'in_string': 'late'}),
    ], [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'a', 'exec_in'),
      wire('seq', 'then_1', 'b', 'exec_in'),
      wire('tick', 'exec_tick_out', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'late', 'exec_in'),
    ]));
    expect(printed(r.trace), ['a', 'b']);
    final firedAt = <int>[];
    for (var i = 1; i <= 62; i++) {
      final before = printed(r.trace).length;
      r.world.tick(1 / 60);
      if (printed(r.trace).length > before) firedAt.add(i);
    }
    // Scheduled on tick 1; every retrigger while pending is ignored; fires
    // 30 ticks (0.5 s) later, then Tick schedules the next one.
    expect(firedAt, [31, 61]);
  });

  test('input parity: the Blueprint character moves and looks exactly like LuminaTemplateCharacter', () {
    final start = Vector3(0, 100, 0);

    ({LuminaWorld world, LuminaPawn pawn, LuminaPlayerController pc, LuminaInputSubsystem input}) setUp(bool blueprint) {
      final w = world();
      final subsystem = w.registerSubsystem(LuminaInputSubsystem());
      // Each world binds its own contexts: triggers hold state.
      final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final pc = LuminaPlayerController();
      final LuminaPawn pawn;
      if (blueprint) {
        for (final c in input.contexts) {
          subsystem.addMappingContext(c.context, priority: c.priority);
        }
        pawn = LuminaBlueprintClass.fromDocument(
          thirdPersonCharacterBlueprint(inputActions: input.actions.values.toList()),
          name: 'BP_ThirdPersonCharacter',
          inputActions: input.actions.values.toList(),
        ).instantiate(location: start.clone()) as LuminaPawn;
        w.persistentLevel.registerActor(pawn);
        pc.possess(pawn);
      } else {
        final character = LuminaTemplateCharacter(thirdPerson: true, location: start.clone());
        w.persistentLevel.registerActor(character);
        pc.possess(character);
        bindTemplateCharacterInput(character: character, world: w, input: input);
        pawn = character;
      }
      w.beginPlay();
      return (world: w, pawn: pawn, pc: pc, input: subsystem);
    }

    final dart = setUp(false);
    final bp = setUp(true);
    for (var frame = 0; frame < 60; frame++) {
      for (final s in [dart, bp]) {
        if (frame == 0) s.input.injectKeyDown(LuminaKey.keyW);
        if (frame >= 10 && frame < 40) s.input.injectAnalog(LuminaKey.mouseX, 4.0);
        if (frame >= 20 && frame < 30) s.input.injectAnalog(LuminaKey.mouseY, -2.0);
        s.pc.onTick(1 / 60);
        s.world.tick(1 / 60);
      }
    }
    expect((dart.pawn.actorLocation - start).length, greaterThan(50), reason: 'the reference walked');
    for (var i = 0; i < 3; i++) {
      expect(bp.pawn.actorLocation[i], closeTo(dart.pawn.actorLocation[i], 1e-3), reason: 'location[$i]');
      expect(bp.pc.controlRotation[i], closeTo(dart.pc.controlRotation[i], 1e-6), reason: 'control rotation[$i]');
    }
    final bpCamera = (bp.pawn as LuminaBlueprintInstance).blueprintComponents['camera'] as LuminaCameraComponent;
    final dartCamera = (dart.pawn as LuminaTemplateCharacter).cameraComponent;
    for (var i = 0; i < 3; i++) {
      expect(bpCamera.worldLocation[i], closeTo(dartCamera.worldLocation[i], 1e-3), reason: 'camera[$i]');
    }
  });

  test('an exec loop is stopped as an infinite loop; the world and other events keep running', () {
    final r = run(graph([
      node('event_beginplay', 'begin'),
      node('sequence', 'loop'),
      node('event_tick', 'tick'),
      node('print_string', 'alive', {'in_string': 'alive'}),
    ], [
      wire('begin', 'exec_out', 'loop', 'exec_in'),
      wire('loop', 'then_0', 'loop', 'exec_in'),
      wire('tick', 'exec_tick_out', 'alive', 'exec_in'),
    ]), maxNodes: 5000);
    // BeginPlay already ran (and was stopped) inside run().
    expect(r.actor.lastError, startsWith('Infinite loop detected in BP_Test.Event BeginPlay'));
    r.world.tick(1 / 60);
    expect(printed(r.trace), ['alive']);
  });

  test('a Blueprint with an error refuses to instantiate and names the node', () {
    final doc = graph([
      node('event_tick', 'tick'),
      node('add_movement_input', 'move'),
    ], [
      wire('tick', 'exec_tick_out', 'move', 'exec_move_in'),
      wire('tick', 'delta_seconds', 'move', 'world_dir'),
    ]);
    expect(
      () => LuminaBlueprintClass.fromDocument(doc, name: 'BP_Broken').instantiate(),
      throwsA(isA<LuminaBlueprintCompileError>().having((e) => e.errors.single.nodeId, 'node', 'move')),
    );
  });
}
