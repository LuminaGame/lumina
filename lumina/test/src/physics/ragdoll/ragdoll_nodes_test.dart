import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../blueprint/ragdoll_blueprint.dart';
import '../physics_fixture.dart';
import 'ragdoll_fixture.dart';

void main() {
  test('the ragdoll nodes have specs, VM functions and call shapes', () {
    for (final id in ['start_ragdoll', 'stop_ragdoll', 'toggle_ragdoll', 'is_ragdoll', 'add_ragdoll_impulse']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    expect(LuminaBlueprintObjectClass.ancestors('Component:LuminaRagdollComponent'), ['Component:LuminaActorComponent']);
  });

  test('the component mapping builds a ragdoll from its properties', () {
    final c = LuminaRagdollComponent.fromProperties({
      'physicsAsset': 'contents/physics/PHYS_X.lmas',
      'getUpClips': ['A', 'B'],
      'flailClip': 'F',
      'hardLandingClip': 'L',
      'ragdollFallSpeed': 1500.0,
      'powered': true,
      'meshYawOffsetDegrees': 90.0,
    });
    expect(c.physicsAssetPath, 'contents/physics/PHYS_X.lmas');
    expect(c.getUpClips, ['A', 'B']);
    expect(c.fallMonitor.ragdollFallSpeed, 1500.0);
    expect(c.powered, isTrue);
    expect(c.meshYawOffsetDegrees, 90.0);
    expect(LuminaBlueprintComponents.classNameOf(c), 'LuminaRagdollComponent');
  });

  test('a Blueprint starts, pushes and toggles its ragdoll (VM)', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final actor = LuminaBlueprintClass.fromDocument(ragdollBlueprint(), name: 'bp_ragdoll').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    actor.actorLocation = Vector3(0, 90, 0);
    final ragdoll = actor.getComponent<LuminaRagdollComponent>()!;
    expect(ragdoll.getUpClips, ['GetUp_Front', 'GetUp_Back']);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: 'mannequin.glb')
      ..relativeLocation = Vector3(0, -90, 0)
      ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi);
    mesh.attachToComponent(actor.rootComponent);
    ragdoll
      ..mesh = mesh
      ..setUp(mannySampler, LuminaPhysicsAssetGenerator.fromSampler(mannySampler));
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    final printed = [for (final t in trace) if (t.printed != null) t.printed!];
    // Before, Started, during; Toggle without get-up clips in the mesh blends out.
    expect(printed, ['false', 'true', 'true', 'false']);
    expect(ragdoll.state, LuminaRagdollState.blendingOut);
  }, skip: mannySkip);
}
