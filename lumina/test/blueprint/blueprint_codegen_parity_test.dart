import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'anim_blueprints.dart';
import 'collision_shapes_blueprint.dart';
import 'physics_blueprint.dart';
import 'anim_rig.dart';
import 'engine_nodes_blueprint.dart';
import 'reusable_graphs_blueprint.dart';
import 'flow_blueprint.dart';
import 'flow_nodes_blueprint.dart';
import 'gameplay_nodes_blueprint.dart';
import 'level_load_blueprint.dart';
import 'level_load_fixture.dart';
import 'generated/abp_character.g.dart';
import 'generated/bp_collision_shapes.g.dart';
import 'generated/bp_physics.g.dart';
import 'generated/bp_engine_nodes.g.dart';
import 'generated/bp_reusable_graphs.g.dart';
import 'generated/bp_flow_nodes.g.dart';
import 'generated/bp_gameplay_nodes.g.dart';
import 'generated/bp_level_load.g.dart';
import 'generated/bp_pure_nodes.g.dart';
import 'generated/bp_editor_character.g.dart';
import 'generated/bp_anim_character.g.dart';
import 'generated/bp_flow.g.dart';
import 'generated/bp_third_person_character.g.dart';
import 'generated/bp_typed_pins.g.dart';
import 'third_person_blueprint.dart';
import 'typed_pins_blueprint.dart';

/// Generated Blueprint Dart behaves exactly like the VM, proven
/// trace for trace on the committed goldens.
void main() {
  final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
  final actions = input.actions.values.toList();

  LuminaWorld world() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
    w.persistentLevel.registerActor(
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: Vector3.all(0.5)));
    return w;
  }

  /// Two pin values are the same: object pins by class (the two runs hold
  /// different instances), maps and lists element by element,
  /// other objects by type, everything else by value.
  void expectSameValue(Object? va, Object? vb, String where) {
    if (va is LuminaActor || va is LuminaActorComponent) {
      expect(LuminaBlueprintFunctionLibrary.classOf(vb), LuminaBlueprintFunctionLibrary.classOf(va), reason: where);
    } else if (va is Map) {
      expect(vb, isA<Map>(), reason: where);
      expect((vb as Map).keys.toList(), va.keys.toList(), reason: where);
      for (final key in va.keys) {
        expectSameValue(va[key], vb[key], '$where.$key');
      }
    } else if (va is List && va.isNotEmpty && va.any((e) => e is LuminaActor || e is Map || e is List)) {
      expect(vb, isA<List>(), reason: where);
      expect((vb as List).length, va.length, reason: where);
      for (var i = 0; i < va.length; i++) {
        expectSameValue(va[i], vb[i], '$where[$i]');
      }
    } else if (va != null && va is! num && va is! String && va is! bool && va is! List && va is! Vector3 && va is! Vector2 && va is! LuminaRotator) {
      expect(vb.runtimeType, va.runtimeType, reason: where);
    } else {
      expect(vb, va, reason: where);
    }
  }

  /// Two traces are equal node for node: event, node, kind, values, print.
  void expectSameTrace(List<LuminaBlueprintTraceEvent> vm, List<LuminaBlueprintTraceEvent> generated) {
    for (var i = 0; i < vm.length && i < generated.length; i++) {
      if (vm[i].nodeId != generated[i].nodeId || vm[i].registryId != generated[i].registryId) {
        final around = [for (var j = (i - 3).clamp(0, i); j <= i; j++) 'VM ${vm[j]} | generated ${generated[j]}'].join('\n');
        fail('traces diverge at step $i:\n$around');
      }
    }
    expect(generated.length, vm.length,
        reason: 'trace lengths differ; last VM ${vm.lastOrNull}, last generated ${generated.lastOrNull}');
    for (var i = 0; i < vm.length; i++) {
      final a = vm[i], b = generated[i];
      final where = 'step $i: VM $a vs generated $b';
      expect(b.eventNodeId, a.eventNodeId, reason: where);
      expect(b.nodeId, a.nodeId, reason: where);
      expect(b.registryId, a.registryId, reason: where);
      expect(b.printed, a.printed, reason: where);
      expect(b.values.keys.toList(), a.values.keys.toList(), reason: where);
      for (final k in a.values.keys) {
        expectSameValue(a.values[k], b.values[k], '$where, pin $k');
      }
    }
  }

  test("the editor's default Character: VM and generated build the same components", () {
    final doc = LuminaBlueprintDocument.fromJson(
        jsonDecode(File('test/blueprint/fixtures/editor_character.json').readAsStringSync()) as Map<String, dynamic>);
    final vm = LuminaBlueprintClass.fromDocument(doc).instantiate() as LuminaBlueprintCharacter;
    final generated = BpEditorCharacter();
    expect(generated.blueprintComponents.keys, vm.blueprintComponents.keys);
    for (final id in vm.blueprintComponents.keys) {
      final a = vm.blueprintComponents[id]!, b = generated.blueprintComponents[id]!;
      expect(b.runtimeType, a.runtimeType, reason: id);
      if (a is LuminaSceneComponent) {
        final s = b as LuminaSceneComponent;
        expect(s.relativeLocation, a.relativeLocation, reason: '$id location');
        expect(s.relativeRotation.storage, a.relativeRotation.storage, reason: '$id rotation');
        expect(identical(s.parentComponent, generated.rootComponent), identical(a.parentComponent, vm.rootComponent), reason: '$id parent');
      }
    }
    expect(generated.capsuleComponent.capsuleRadius, vm.capsuleComponent.capsuleRadius);
    expect(generated.characterMovement.maxWalkSpeed, vm.characterMovement.maxWalkSpeed);
    expect(generated.characterMovement.jumpZVelocity, vm.characterMovement.jumpZVelocity);
    expect((generated.blueprintComponents['spring_arm'] as LuminaSpringArmComponent).targetArmLength, 400);
  });

  test('input graph: 2 s of W, mouse and Space give the same trace and the same place', () {
    final start = Vector3(0, 100, 0);
    ({LuminaWorld world, LuminaPawn pawn, LuminaPlayerController pc, LuminaInputSubsystem input, List<LuminaBlueprintTraceEvent> trace})
        setUp(bool generated) {
      final w = world();
      final subsystem = w.registerSubsystem(LuminaInputSubsystem());
      // Each world binds its own contexts: triggers hold state (a Pressed
      // edge), so sharing them would let the first world consume it.
      final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      for (final c in input.contexts) {
        subsystem.addMappingContext(c.context, priority: c.priority);
      }
      final LuminaPawn pawn = generated
          ? BpThirdPersonCharacter(location: start.clone())
          : LuminaBlueprintClass.fromDocument(thirdPersonCharacterBlueprint(inputActions: actions), inputActions: actions)
              .instantiate(location: start.clone()) as LuminaPawn;
      final trace = <LuminaBlueprintTraceEvent>[];
      (pawn as LuminaBlueprintRuntime).trace = trace.add;
      final pc = LuminaPlayerController();
      w.persistentLevel.registerActor(pawn);
      pc.possess(pawn);
      w.beginPlay();
      return (world: w, pawn: pawn, pc: pc, input: subsystem, trace: trace);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    for (var frame = 0; frame < 120; frame++) {
      for (final s in [vm, gen]) {
        if (frame == 0) s.input.injectKeyDown(LuminaKey.keyW);
        if (frame >= 10 && frame < 50) s.input.injectAnalog(LuminaKey.mouseX, 3.0);
        if (frame >= 20 && frame < 30) s.input.injectAnalog(LuminaKey.mouseY, -2.0);
        if (frame == 60) s.input.injectKeyDown(LuminaKey.keySpace);
        if (frame == 66) s.input.injectKeyUp(LuminaKey.keySpace);
        s.pc.onTick(1 / 60);
        s.world.tick(1 / 60);
      }
    }
    expect(vm.trace.length, greaterThan(200), reason: 'the graph really ran');
    expect(vm.trace.any((t) => t.registryId == 'jump'), isTrue);
    expect(vm.trace.any((t) => t.registryId == 'stop_jumping'), isTrue);
    expectSameTrace(vm.trace, gen.trace);
    for (var i = 0; i < 3; i++) {
      expect(gen.pawn.actorLocation[i], closeTo(vm.pawn.actorLocation[i], 1e-6), reason: 'location[$i]');
      expect(gen.pc.controlRotation[i], closeTo(vm.pc.controlRotation[i], 1e-9), reason: 'control rotation[$i]');
    }
  });

  test('flow graph: Sequence, Branch, variables, Tick and Delay trace the same over 90 ticks', () {
    ({LuminaWorld world, List<LuminaBlueprintTraceEvent> trace, LuminaActor actor}) setUp(bool generated) {
      final w = world();
      final actor = generated ? BpFlow() : LuminaBlueprintClass.fromDocument(flowBlueprint()).instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      for (var i = 0; i < 90; i++) {
        w.tick(1 / 60);
      }
      return (world: w, trace: trace, actor: actor);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    expect(vm.trace.where((t) => t.printed == 'late').length, greaterThanOrEqualTo(4), reason: 'the Delay resumed repeatedly');
    expect(vm.trace.firstWhere((t) => t.nodeId == 'yes').printed, "it's \$ok", reason: 'the string variable reached Print');
    expectSameTrace(vm.trace, gen.trace);
    expect(gen.actor.actorLocation, vm.actor.actorLocation);
  });

  test('typed pins graph: widget elements, Is Valid?, Cast To and components trace the same', () {
    LuminaWidgetClassRegistry.register(typedPinsHud);
    addTearDown(LuminaWidgetClassRegistry.clear);
    ({LuminaWorld world, List<LuminaBlueprintTraceEvent> trace, LuminaBlueprintRuntime actor}) setUp(bool generated) {
      final w = world();
      final LuminaActor actor = generated
          ? BpTypedPins()
          : LuminaBlueprintClass.fromDocument(typedPinsBlueprint(), name: 'bp_typed_pins').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      for (var i = 0; i < 3; i++) {
        w.tick(1 / 60);
      }
      return (world: w, trace: trace, actor: actor);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed, ['bp_typed_pins', 'not a door', 'CameraBoom', 'FPS: 60', 'FPS: 60', 'FPS: 60']);
    expect(vm.trace.where((t) => t.registryId == 'cast_to').map((t) => t.values['as_class'] != null), [true, false]);
    expectSameTrace(vm.trace, gen.trace);
    for (final r in [vm, gen]) {
      final arm = r.actor.blueprintComponents['boom'] as LuminaSpringArmComponent;
      expect(arm.targetArmLength, 500.0);
      final widget = r.world.getSubsystem<LuminaWidgetSubsystem>()!.widgets.single;
      expect(((widget['elements'] as Map)['FPSCounter'] as Map)['text'], 'FPS: 60');
      expect(((widget['elements'] as Map)['Health'] as Map)['percent'], 1.0);
      // The shadow and outline setters write the same state.
      final fps = (widget['elements'] as Map)['FPSCounter'] as Map<String, Object?>;
      expect(fps['shadowEnabled'], isTrue);
      expect(fps['shadowColor'], [1.0, 0.0, 0.0, 0.5]);
      expect([fps['shadowOffsetX'], fps['shadowOffsetY']], [3.0, 4.0]);
      expect([fps['outlineSize'], fps['outlineColor']], [2.0, [0.0, 0.0, 0.0, 1.0]]);
      // The Container setters.
      final panel = (widget['elements'] as Map)['Panel'] as Map<String, Object?>;
      expect(panel['backgroundColor'], [0.2, 0.4, 0.6, 1.0]);
      expect(panel['borderColor'], [1.0, 0.5, 0.0, 1.0]);
      expect(panel['cornerRadius'], 12.0);
      expect(panel['padding'], [4.0, 8.0, 4.0, 8.0]);
    }
    expect((gen.actor as BpTypedPins).armLength, 500.0);
    expect((vm.actor as LuminaBlueprintInstance).variables['ArmLength'], 500.0);
    expect(gen.actor.blueprintClassName, 'bp_typed_pins');
  });

  test('physics graph: simulating components, every Physics node and Event Hit trace the same', () {
    ({LuminaWorld world, List<LuminaBlueprintTraceEvent> trace, LuminaBlueprintRuntime actor}) setUp(bool generated) {
      final w = world();
      final LuminaActor actor =
          generated ? BpPhysics() : LuminaBlueprintClass.fromDocument(physicsBlueprint(), name: 'bp_physics').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      for (var i = 0; i < 90; i++) {
        w.tick(1 / 60);
      }
      return (world: w, trace: trace, actor: actor);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed.take(6), ['10.0', 'true', '3.0', 'X=300.000 Y=0.000 Z=0.000', 'X=0.000 Y=90.000 Z=0.000', 'false']);
    expect(vm.trace.where((t) => t.nodeId == 'say_hit' && t.printed != null), isNotEmpty, reason: 'Event Hit fired');
    expectSameTrace(vm.trace, gen.trace);
    for (final id in ['crate', 'ball']) {
      final a = vm.actor.blueprintComponents[id] as LuminaCollisionComponent;
      final b = gen.actor.blueprintComponents[id] as LuminaCollisionComponent;
      expect(b.isSimulatingPhysics, isTrue);
      expect(b.worldLocation.storage, a.worldLocation.storage, reason: '$id moved identically');
      expect(b.worldRotation.storage, a.worldRotation.storage, reason: '$id turned identically');
    }
    vm.world.cleanup();
    gen.world.cleanup();
    expect(gen.actor.blueprintClassName, 'bp_physics');
  });

  test('collision shapes graph: presets, responses, sizes and overlaps trace the same', () {
    ({LuminaWorld world, List<LuminaBlueprintTraceEvent> trace, LuminaBlueprintRuntime actor, LuminaCharacter pawn}) setUp(
        bool generated) {
      final w = world();
      final LuminaActor actor = generated
          ? BpCollisionShapes()
          : LuminaBlueprintClass.fromDocument(collisionShapesBlueprint(), name: 'bp_collision_shapes').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      // A pawn standing inside the trigger box (authoring (0, 0, 100) is runtime (0, 100, 0)).
      final pawn = LuminaCharacter(location: Vector3(0, 100, 0));
      w.persistentLevel.registerActor(pawn);
      w.beginPlay();
      for (var i = 0; i < 3; i++) {
        w.tick(1 / 60);
      }
      return (world: w, trace: trace, actor: actor, pawn: pawn);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed.take(7), ['Trigger', 'Block', 'Custom', '80', 'X=120.000 Y=130.000 Z=140.000', 'WorldDynamic', 'NoCollision']);
    // Each tick: the pawn's capsule overlaps the box (it blocks pawns now, but the
    // pawn's capsule blocks too → a hit, not an overlap), so the counts read 0.
    expect(printed.skip(7).take(3), ['0', 'false', '0']);
    expectSameTrace(vm.trace, gen.trace);
    for (final r in [vm, gen]) {
      final box = r.actor.blueprintComponents['box'] as LuminaBoxComponent;
      expect(box.boxExtent, Vector3(120, 140, 130));
      expect(box.getResponse(CollisionObjectType.pawn), CollisionResponse.block);
      final sphere = r.actor.blueprintComponents['sphere'] as LuminaSphereComponent;
      expect(sphere.radius, 80.0);
      expect(sphere.preset, LuminaCollisionPreset.overlapAll);
      final pillar = r.actor.blueprintComponents['pillar'] as LuminaCylinderComponent;
      expect(pillar.preset, LuminaCollisionPreset.overlapAllDynamic);
      expect(pillar.generateOverlapEvents, isFalse);
      final cone = r.actor.blueprintComponents['cone'] as LuminaConeComponent;
      expect(cone.collisionEnabled, isFalse);
      expect(cone.objectType, CollisionObjectType.pawn);
      r.world.cleanup();
    }
    expect(gen.actor.blueprintClassName, 'bp_collision_shapes');
  });

  test('flow-control graph: loops, switches, gates, arrays and the FPS chain trace the same', () {
    ({LuminaWorld world, List<LuminaBlueprintTraceEvent> trace, LuminaBlueprintRuntime actor}) setUp(bool generated) {
      final w = world();
      final LuminaActor actor = generated
          ? BpFlowNodes()
          : LuminaBlueprintClass.fromDocument(flowNodesBlueprint(), name: 'bp_flow_nodes').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      for (var i = 0; i < 8; i++) {
        w.tick(1 / 60);
      }
      return (world: w, trace: trace, actor: actor);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed.take(13), ['0', '1', '2', '0', '0:a', '1:b', '2:c', 'case b', 'int default', 'no', 'once', 'A', '1']);
    expect(printed, contains('FPS: 60'));
    expect(printed, contains('through'));
    expect(printed, containsAll(['out 0', 'out 1']));
    expect(printed, contains('late'));
    expect(vm.trace.where((t) => t.registryId == 'while_loop').last.values['iterations'], 3);
    expectSameTrace(vm.trace, gen.trace);
    expect((vm.actor as LuminaBlueprintInstance).variables['Log'], (gen.actor as BpFlowNodes).log);
    expect((gen.actor as BpFlowNodes).n, 3);
  });

  test('every pure math / string / array / struct node gives the VM and the generated Dart the same value (table over the node ids)', () {
    ({List<LuminaBlueprintTraceEvent> trace, LuminaWorld world}) setUp(bool generated) {
      final w = world();
      final LuminaActor actor = generated
          ? BpPureNodes()
          : LuminaBlueprintClass.fromDocument(pureNodesBlueprint(), name: 'bp_pure_nodes').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      return (trace: trace, world: w);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    final covered = vm.trace.map((t) => t.registryId).toSet();
    for (final id in pureNodeLiterals.keys) {
      expect(covered, contains(id));
    }
    expect(vm.trace.firstWhere((t) => t.nodeId == 'p_append').printed, 'FPS: 60');
    expect(vm.trace.firstWhere((t) => t.nodeId == 'p_color_to_hex').printed, '#FF0000FF');
    expect(vm.trace.firstWhere((t) => t.nodeId == 'p_float_to_string').printed, '3.14');
    expect(vm.trace.firstWhere((t) => t.nodeId == 'p_int_divide').printed, '0');
    expectSameTrace(vm.trace, gen.trace);
  });

  test('engine graph: stats, traces, view target, spawn, tags, life span and the actor events trace the same', () {
    ({LuminaWorld world, LuminaCharacter actor, LuminaPlayerController pc, LuminaActor visitor, List<LuminaBlueprintTraceEvent> trace})
        setUp(bool generated) {
      final w = world();
      // Something to trace: a capsule 3 m ahead, at eye height.
      final ahead = LuminaActor(root: LuminaCapsuleComponent(radius: 50, halfHeight: 200), location: Vector3(0, 100, -300));
      w.persistentLevel.registerActor(ahead);
      // Something to overlap with later.
      final visitor = LuminaActor(root: LuminaCapsuleComponent(radius: 50, halfHeight: 100), location: Vector3(0, 0, 900));
      CollisionProfile.applyOverlapAll(visitor.rootComponent as LuminaCollisionComponent);
      w.persistentLevel.registerActor(visitor);
      final LuminaCharacter actor = generated
          ? BpEngineNodes()
          : LuminaBlueprintClass.fromDocument(engineNodesBlueprint(), name: 'bp_engine_nodes').instantiate() as LuminaCharacter;
      CollisionProfile.applyOverlapAll(actor.capsuleComponent);
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      final pc = LuminaPlayerController();
      w.persistentLevel.registerActor(actor);
      pc.possess(actor);
      w.beginPlay();
      return (world: w, actor: actor, pc: pc, visitor: visitor, trace: trace);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    for (var frame = 0; frame < 30; frame++) {
      for (final s in [vm, gen]) {
        if (frame == 10) s.visitor.actorLocation = Vector3(0, 0, 0);
        if (frame == 20) s.visitor.actorLocation = Vector3(0, 0, 900);
        if (frame == 25) {
          s.actor.takePointDamage(3.0, hitLocation: Vector3(1, 2, 3), hitFromDirection: Vector3(0, 0, 1));
        }
        if (frame == 28) s.actor.destroy();
        s.pc.onTick(1 / 60);
        s.world.tick(1 / 60);
      }
    }
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed, containsAll(['0', 'true', 'X=2.000 Y=2.000 Z=2.000', '100.0', 'end Destroyed', 'destroyed', '10.0']),
        reason: 'the spawned actor stands at (100, 0, 0)');
    expect(printed, contains('250'), reason: 'the trace hit the capsule 3 m ahead');
    expect(printed.where((p) => p == 'LuminaActor').length, greaterThanOrEqualTo(2), reason: 'the owner, the overlap visitor');
    expect(printed, contains('LuminaCapsuleComponent'));
    expect(printed, contains('left'));
    expect(printed.last, 'end Destroyed');
    expect(vm.trace.any((t) => t.registryId == 'spawn_actor_from_class'), isTrue);
    expect(vm.world.actors.length, gen.world.actors.length);
    expectSameTrace(vm.trace, gen.trace);
  });

  test('reusable graphs: custom events, functions, macros, dispatchers, interfaces, enums, timers and a timeline trace the same', () {
    LuminaBlueprintEnums.register(reusableDoorState);
    LuminaBlueprintInterfaces.register(reusableInteractable);
    addTearDown(() {
      LuminaBlueprintEnums.clear();
      LuminaBlueprintInterfaces.clear();
    });
    ({LuminaWorld world, LuminaActor actor, List<LuminaBlueprintTraceEvent> trace}) setUp(bool generated) {
      final w = world();
      final actor = generated
          ? BpReusableGraphs()
          : LuminaBlueprintClass.fromDocument(reusableGraphsBlueprint(), name: 'bp_reusable_graphs').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      return (world: w, actor: actor, trace: trace);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    for (var frame = 0; frame < 20; frame++) {
      for (final s in [vm, gen]) {
        s.world.tick(0.1);
      }
    }
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed.take(4), ['130.0', '130.0', '150.0', '0.90'], reason: 'AddHealth twice (the macro prints inside), then HealthPercent');
    expect(printed, containsAll(['150', 'score 7', 'score 10', 'interact by None', 'Open', 'true', 'opening', '1', 'Open', '3']));
    expect(printed, isNot(contains('score 110')), reason: 'unbound before the second Call');
    expect(printed.where((p) => p == 'pulse').length, 6, reason: '0.25 s looping until paused after 1.6 s');
    expect(printed.where((p) => p == 'next tick').length, 1);
    expect(printed.where((p) => p == 'named').length, 1);
    expect(printed.where((p) => p.startsWith('angle ')).length, 5, reason: 'a 0.5 s timeline at 0.1 s ticks');
    expect(printed, contains('finished Forward'));
    expect(printed, contains('true'));
    expect((vm.actor as LuminaBlueprintInstance).variables['Health'], 180.0, reason: 'the macro clamps only what it prints');
    expect((gen.actor as BpReusableGraphs).health, 180.0);
    expect((gen.actor as BpReusableGraphs).score, 10);
    expect((gen.actor as BpReusableGraphs).state, 'Opening');
    expect(vm.trace.map((t) => t.nodeId), contains('mac__say'), reason: 'the macro instance keeps its prefixed ids');
    expectSameTrace(vm.trace, gen.trace);
  });

  test('gameplay graph: game framework, save, input, audio, montage, fx, material, light and debug nodes trace the same', () {
    registerGameplayAssets();
    addTearDown(clearGameplayAssets);
    final saves = Directory.systemTemp.createTempSync('lumina_bp12_parity_');
    addTearDown(() => saves.deleteSync(recursive: true));
    final anim = templateAnimClass();
    ({LuminaWorld world, LuminaCharacter actor, LuminaPlayerController pc, List<LuminaBlueprintTraceEvent> trace}) setUp(bool generated) {
      final w = world();
      w.registerSubsystem(LuminaSaveGameSubsystem(saveDirectoryPath: saves.path));
      w.registerSubsystem(LuminaAudioSubsystem(backend: NullAudioBackend()));
      w.registerSubsystem(LuminaInputSubsystem());
      w.persistentLevel.levelName = 'L_Parity';
      final LuminaCharacter actor = generated
          ? BpGameplayNodes()
          : LuminaBlueprintClass.fromDocument(gameplayNodesBlueprint(inputActions: actions),
                  name: 'bp_gameplay_nodes',
                  inputActions: actions,
                  animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null)
              .instantiate() as LuminaCharacter;
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      final pc = LuminaPlayerController();
      w.persistentLevel.registerActor(actor);
      pc.possess(actor);
      w.beginPlay();
      return (world: w, actor: actor, pc: pc, trace: trace);
    }

    final vm = setUp(false);
    final gen = setUp(true);
    for (var frame = 0; frame < 10; frame++) {
      for (final s in [vm, gen]) {
        s.pc.onTick(0.1);
        s.world.tick(0.1);
      }
    }
    final printed = [for (final t in vm.trace) if (t.printed != null) t.printed!];
    expect(printed, containsAll(['false', 'L_Parity', '5', 'X=1.000 Y=2.000 Z=3.000', '1280', 'AM_Parity', '0.4', 'true', '5000', 'text too', 'on screen']));
    expect(printed, contains('stream completed'));
    expect(printed, contains('notify Beat'));
    expect(printed, contains('AM_Parity ended false'));
    expect(printed.where((p) => p == 'stream completed').length, 1);
    expect(File('${saves.path}/parity_user_0.sav').existsSync(), isFalse, reason: 'deleted on the chain');
    final lamp = (gen.actor as LuminaBlueprintRuntime).blueprintComponents['lamp'] as LuminaPointLightComponent;
    expect(lamp.intensity, 5000.0);
    expect(lamp.visible, isFalse);
    expect(lamp.falloffRadius, 1500.0);
    expect(vm.world.screenMessages['parity']!.text, 'on screen');
    expect(vm.world.debugShapes, isEmpty, reason: 'flushed');
    expectSameTrace(vm.trace, gen.trace);
  });

  test('level load graph: Load Level progress and its bound custom event, Change Level, its error and '
      'Load And Change Level trace the same', () async {
    final project = Directory.systemTemp.createTempSync('lvl_parity_');
    final dir = project.resolveSymbolicLinksSync();
    writeLevelLoadProject(dir);
    final saved = LuminaLevelPreloader.instance;
    addTearDown(() {
      LuminaLevelPreloader.instance = saved;
      LuminaGame.onChangeLevelRequested = null;
      LuminaAssetIndex.close(dir);
      project.deleteSync(recursive: true);
    });
    Future<({List<LuminaBlueprintTraceEvent> trace, List<String> printed, LuminaActor actor})> run(bool generated) async {
      // One asset at a time, so both runs see the same order.
      LuminaLevelPreloader.instance = LuminaLevelPreloader(
          manifestResolver: (name) => LuminaLevelAssetManifest.forProjectLevel(dir, name), maxConcurrent: 1);
      final w = world()..persistentLevel.levelName = 'L_First';
      final LuminaActor actor = generated
          ? BpLevelLoad()
          : LuminaBlueprintClass.fromDocument(levelLoadBlueprint(), name: 'bp_level_load').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      final host = LevelLoadTestHost(w)..install();
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      List<String> printed() => [for (final t in trace) if (t.printed != null) t.printed!];
      Future<void> until(bool Function(List<String> printed) done) async {
        for (var i = 0; i < 400 && !done(printed()); i++) {
          host.world.tick(1 / 30);
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(done(printed()), isTrue, reason: '${generated ? 'generated' : 'VM'}: ${printed()}');
      }

      final callable = actor as LuminaBlueprintCallable;
      callable.callBlueprint('StartLoading', const {});
      await until((p) => p.contains('changed'));
      callable.callBlueprint('TryBadLevel', const {});
      await until((p) => p.any((s) => s.startsWith('bad: ')));
      callable.callBlueprint('LoadAndGo', const {});
      await until((p) => p.contains('went'));
      host.uninstall();
      return (trace: trace, printed: printed(), actor: actor);
    }

    final vm = await run(false);
    final gen = await run(true);
    expect(vm.printed, containsAllInOrder(['loader ready', 'ac_unit_b_600x600', 'event ac_unit_b_600x600', 'sky', 'event sky', 'loaded true', 'changed', 'went']));
    expect(vm.printed.where((p) => p.startsWith('event ')), hasLength(6));
    expect((vm.actor as LuminaBlueprintInstance).variables['Updates'], 6);
    expect((gen.actor as BpLevelLoad).updates, 6);
    expect((gen.actor as BpLevelLoad).eventPercent, 100.0);
    expectSameTrace(vm.trace, gen.trace);
  });

  test('an exec loop is a generation error naming the node, and no code is produced', () {
    final doc = LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin'),
      LuminaBlueprintNodeLibrary.place('sequence', nodeId: 'loop'),
    ], wires: const [
      LuminaBlueprintWire(id: 'a', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'loop', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'b', fromNodeId: 'loop', fromPinId: 'then_0', toNodeId: 'loop', toPinId: 'exec_in'),
    ]));
    final result = const BlueprintDartGenerator().generate(doc, className: 'BpLoop');
    expect(result.ok, isFalse);
    expect(result.errors.single.nodeId, 'loop');
    expect(result.errors.single.message, contains('exec loop'));
  });

  test('compileAndWriteActor writes lib/actors, keeps the user region, and skips unchanged or broken documents', () async {
    final project = Directory.systemTemp.createTempSync('lumina_bp_codegen_');
    addTearDown(() => project.deleteSync(recursive: true));
    final service = DartCodeGeneratorService();
    final doc = flowBlueprint().toJson();
    expect(await service.compileAndWriteActor(project.path, 'BP_Flow', doc), isTrue);
    final file = File('${project.path}/lib/actors/bp_flow.dart');
    expect(file.readAsStringSync(), contains('class BpFlow extends LuminaActor with LuminaBlueprintRuntime'));
    expect(File('${project.path}/lib/actors/actors.g.dart').readAsStringSync(), contains("'BpFlow': () => BpFlow(),"));

    // A hand edit inside the user region survives regeneration.
    file.writeAsStringSync(file.readAsStringSync().replaceFirst(
        '  // BEGIN USER CODE: class_body\n', '  // BEGIN USER CODE: class_body\n  int handWritten() => 42;\n'));
    final stamp = file.lastModifiedSync();
    expect(await service.compileAndWriteActor(project.path, 'BP_Flow', doc), isTrue);
    expect(file.readAsStringSync(), contains('int handWritten() => 42;'));
    expect(file.lastModifiedSync(), stamp, reason: 'unchanged output is not rewritten');

    // A document with an error writes nothing and reports false.
    final broken = LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place('event_tick', nodeId: 'tick'),
      LuminaBlueprintNodeLibrary.place('add_movement_input', nodeId: 'move'),
    ], wires: const [
      LuminaBlueprintWire(id: 'a', fromNodeId: 'tick', fromPinId: 'exec_tick_out', toNodeId: 'move', toPinId: 'exec_move_in'),
      LuminaBlueprintWire(id: 'b', fromNodeId: 'tick', fromPinId: 'delta_seconds', toNodeId: 'move', toPinId: 'world_dir'),
    ]));
    expect(await service.compileAndWriteActor(project.path, 'BP_Broken', broken.toJson()), isFalse);
    expect(File('${project.path}/lib/actors/bp_broken.dart').existsSync(), isFalse);
  });

  group('Animation Blueprints', () {
    test('compileAndWriteActor compiles the Anim Class a mesh names into lib/anim and imports it', () async {
      final project = Directory.systemTemp.createTempSync('lumina_abp_codegen_');
      addTearDown(() => project.deleteSync(recursive: true));
      void writeAsset(String path, String name, AssetType type, Map<String, dynamic> payload) {
        final file = File('${project.path}/$path')..parent.createSync(recursive: true);
        file.writeAsBytesSync(LuminaAsset(assetId: name, name: name, type: type, rawPayload: utf8.encode(jsonEncode(payload)))
            .toProtoBufferBytes());
      }

      // A Third Person project: its input actions type the character's graph.
      File('${project.path}/manny.lmproject').writeAsStringSync(jsonEncode(
          LuminaProject(projectName: 'manny', template: 'third_person', input: GameTemplateCatalog.thirdPerson.input).toMap()));
      writeAsset(LuminaThirdPersonContent.projectAnimBlueprintPath, 'ABP_Character', AssetType.animBlueprint,
          LuminaThirdPersonContent.animBlueprint.toJson());
      final service = DartCodeGeneratorService();
      final doc = templateCharacterBlueprint(inputActions: actions).toJson();

      // The blend space is missing: ABP_Character cannot compile, so neither can the character.
      expect(await service.compileAndWriteActor(project.path, 'BP_AnimCharacter', doc), isFalse);
      expect(File('${project.path}/lib/actors/bp_anim_character.dart').existsSync(), isFalse);

      writeAsset(LuminaThirdPersonContent.projectWalkBlendSpacePath, 'BS_Walk', AssetType.blendSpace,
          LuminaThirdPersonContent.walkBlendSpace.toJson());
      // The Walk state plays BS_Locomotion; still missing, still no compile.
      expect(await service.compileAndWriteActor(project.path, 'BP_AnimCharacter', doc), isFalse);
      writeAsset(LuminaThirdPersonContent.projectLocomotionBlendSpacePath, 'BS_Locomotion', AssetType.blendSpace,
          LuminaThirdPersonContent.locomotionBlendSpace.toJson());
      expect(await service.compileAndWriteActor(project.path, 'BP_AnimCharacter', doc), isTrue);
      final anim = File('${project.path}/lib/anim/abp_character.dart').readAsStringSync();
      expect(anim, contains('class AbpCharacter extends LuminaAnimBlueprintInstance'));
      expect(anim, contains("LuminaBlendSpaceSample('Walk_Fwd_Right_Loop', 45.0, 100.0)"));
      expect(anim, contains("LuminaBlendSpaceSample('Jog_Fwd_Right_Loop', 45.0, 600.0)"));
      expect(anim, contains('rateRows: true'));
      final actor = File('${project.path}/lib/actors/bp_anim_character.dart').readAsStringSync();
      expect(actor, contains("import '../anim/abp_character.dart';"));
      expect(actor, contains("'${LuminaThirdPersonContent.projectAnimBlueprintPath}' => AbpCharacter.create,"));
      expect(File('${project.path}/lib/actors/actors.g.dart').readAsStringSync(), isNot(contains('AbpCharacter')),
          reason: 'an Animation Blueprint is not a placeable actor');

      // The generated pair matches the committed goldens, which the suite compiles.
      expect(anim, File('test/blueprint/generated/abp_character.g.dart').readAsStringSync());
    });

    test('VM and generated ABP_Character give the same trace, states, clips and crossfades over the script', () {
      ({AnimRig rig, List<LuminaBlueprintTraceEvent> trace, List<AnimSample> samples, List<String?> states}) run(
          LuminaAnimBlueprintFactory factory) {
        final rig = AnimRig.abp(factory);
        // Random clips (idle breaks) pick the same in both runs.
        rig.anim!.random = math.Random(3);
        final trace = <LuminaBlueprintTraceEvent>[];
        rig.anim!.trace = trace.add;
        final states = <String?>[];
        final samples = <AnimSample>[];
        for (final s in rig.script()) {
          samples.add(s);
        }
        states.add(rig.anim!.currentState);
        return (rig: rig, trace: trace, samples: samples, states: states);
      }

      final vm = run(templateAnimClass().factory);
      final gen = run(AbpCharacter.create);
      expect(gen.rig.anim, isA<AbpCharacter>());
      expect(vm.trace.length, greaterThan(5000), reason: 'the update graph and the rules really ran');
      expect(vm.trace.map((t) => t.eventNodeId).toSet(), containsAll(['update', 'idle_to_walk', 'walk_to_jump', 'fallloop_to_land', 'land_to_walk']));
      expectSameTrace(vm.trace, gen.trace);
      expect(gen.samples, vm.samples);
      expect(gen.rig.mesh.fades, vm.rig.mesh.fades);
      expect(gen.states, vm.states);
      // Every pose and transition field survives generation.
      final vmMachine = vm.rig.anim!.stateMachine, genMachine = gen.rig.anim!.stateMachine;
      expect(genMachine.states.map((s) => s.name), vmMachine.states.map((s) => s.name));
      for (var i = 0; i < vmMachine.states.length; i++) {
        final a = vmMachine.states[i].pose, b = genMachine.states[i].pose;
        final where = vmMachine.states[i].name;
        expect(b.kind, a.kind, reason: where);
        expect(b.clip, a.clip, reason: where);
        expect(b.clips, a.clips, reason: where);
        expect(b.loop, a.loop, reason: where);
        expect(b.rootYawDegrees, a.rootYawDegrees, reason: where);
        expect(b.plantsFeet, a.plantsFeet, reason: where);
        expect(b.rate, a.rate, reason: where);
      }
      expect(vmMachine.states.any((s) => s.pose.clips.length > 1), isTrue, reason: 'IdleBreak is a random clip set');
      expect(vmMachine.states.any((s) => !s.pose.loop), isTrue);
      expect(vmMachine.states.any((s) => s.pose.rootYawDegrees != 0.0), isFalse, reason: 'the bundle has no turn-in-place clips');
      for (var i = 0; i < vmMachine.transitions.length; i++) {
        final a = vmMachine.transitions[i], b = genMachine.transitions[i];
        expect(b.id, a.id);
        expect(b.minStateTime, a.minStateTime, reason: a.id);
        expect(b.automaticRule, a.automaticRule, reason: a.id);
      }
    });

    test('a generated character whose mesh names ABP_Character animates like the VM one', () {
      ({LuminaWorld world, LuminaCharacter character, List<String?> clips, List<LuminaBlueprintTraceEvent> trace}) spawn(
          bool generated) {
        final w = AnimRig.floorWorld();
        final anim = templateAnimClass();
        final LuminaCharacter character = generated
            ? BpAnimCharacter()
            : LuminaBlueprintClass.fromDocument(templateCharacterBlueprint(inputActions: actions),
                    name: 'BP_AnimCharacter',
                    inputActions: actions,
                    animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null)
                .instantiate() as LuminaCharacter;
        character.actorLocation = Vector3(0, 100, 0);
        final instance = (character as LuminaBlueprintRuntime).blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
        final trace = <LuminaBlueprintTraceEvent>[];
        instance.trace = trace.add;
        w.persistentLevel.registerActor(character);
        w.beginPlay();
        return (world: w, character: character, clips: <String?>[], trace: trace);
      }

      final vm = spawn(false);
      final gen = spawn(true);
      final mesh = <LuminaCharacter, LuminaAnimatedMeshComponent>{
        for (final c in [vm.character, gen.character])
          c: (c as LuminaBlueprintRuntime).blueprintComponents['mesh'] as LuminaAnimatedMeshComponent,
      };
      for (final (frames, direction) in [(30, Vector3.zero()), (60, Vector3(1, 0, 0)), (60, Vector3(0, 0, 1)), (40, Vector3.zero())]) {
        for (var i = 0; i < frames; i++) {
          for (final r in [vm, gen]) {
            if (direction.length2 > 0) r.character.characterMovement.addInputVector(direction);
            r.world.tick(1 / 60);
            r.clips.add(mesh[r.character]!.currentClip);
          }
        }
      }
      expect(vm.clips.toSet(), containsAll(['Idle_Loop', 'Walk_Right_Loop', 'Walk_Bwd_Loop']));
      expect(gen.clips, vm.clips);
      expectSameTrace(vm.trace, gen.trace);
    });
  });
}
