import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../lumina/test/blueprint/generated/bp_traversal_character.g.dart';
import '../../../lumina/test/blueprint/traversal_blueprint.dart';

/// A character Blueprint whose Jump tries a traversal action first: the VM
/// and the generated class hurdle the same wall the same way, node for node
/// and centimetre for centimetre.
void main() {
  final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
  final actions = bound.actions.values.toList();

  ({LuminaWorld world, LuminaCharacter pawn, LuminaPlayerController pc, LuminaInputSubsystem input, List<LuminaBlueprintTraceEvent> trace, LuminaTraversalComponent traversal})
      spawn(bool generated) {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
    final input = w.registerSubsystem(LuminaInputSubsystem());
    for (final c in ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    TraversalBlueprintFixture.level(w);
    final start = Vector3(0, 90.2, 0);
    final LuminaCharacter pawn = generated
        ? BpTraversalCharacter(location: start)
        : LuminaBlueprintClass.fromDocument(TraversalBlueprintFixture.characterBlueprint(inputActions: actions),
                inputActions: actions)
            .instantiate(location: start) as LuminaCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    (pawn as LuminaBlueprintRuntime).trace = trace.add;
    w.persistentLevel.registerActor(pawn);
    final pc = LuminaPlayerController()..possess(pawn);
    w.beginPlay();
    final traversal = (pawn as LuminaBlueprintRuntime).blueprintComponents['traversal'] as LuminaTraversalComponent..useRig(TraversalBlueprintFixture.rig());
    return (world: w, pawn: pawn, pc: pc, input: input, trace: trace, traversal: traversal);
  }

  test('Jump at a wall hurdles it in the VM and in generated Dart alike; in the open both jump', () {
    final vm = spawn(false);
    final gen = spawn(true);
    for (var frame = 0; frame < 200; frame++) {
      for (final s in [vm, gen]) {
        if (frame == 5) s.pawn.characterMovement.velocity.setValues(0, 0, -400);
        if (frame == 5) s.input.injectKeyDown(LuminaKey.keySpace);
        if (frame == 8) s.input.injectKeyUp(LuminaKey.keySpace);
        s.pc.onTick(1 / 60);
        s.world.tick(1 / 60);
      }
      expect(gen.traversal.isTraversing, vm.traversal.isTraversing, reason: 'frame $frame');
      for (var i = 0; i < 3; i++) {
        expect(gen.pawn.actorLocation[i], closeTo(vm.pawn.actorLocation[i], 1e-6), reason: 'frame $frame location[$i]');
      }
    }
    expect(vm.traversal.actionCount, 1);
    expect(vm.traversal.lastChoice!.animation.action, LuminaTraversalActionType.hurdle);
    expect(vm.pawn.actorLocation.z, lessThan(-265), reason: 'behind the wall');
    expect([for (final t in vm.trace) t.registryId], [for (final t in gen.trace) t.registryId]);
    expect(vm.trace.map((t) => t.registryId), containsAll(['try_traversal_action', 'branch', 'stop_jumping']));
    expect(vm.trace.map((t) => t.registryId), isNot(contains('jump')), reason: 'the traversal replaced the jump');

    // Turned around, nothing ahead: both jump.
    for (final s in [vm, gen]) {
      s.pawn.actorRotation = Quaternion.axisAngle(Vector3(0, 1, 0), 0);
      s.input.injectKeyDown(LuminaKey.keySpace);
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      expect(s.pawn.characterMovement.isFalling, isTrue);
      expect(s.trace.last.registryId, 'jump');
    }
  });
}
