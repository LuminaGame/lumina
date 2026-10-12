import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/physics/jolt/jolt_physics_backend.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';
import '../ragdoll/ragdoll_fixture.dart';

/// A skirt skinned to the mannequin's skeleton: built around the pelvis and
/// weighted to the hip and leg bones, its waist stays on the body while the
/// hem swings within its max distance, it follows the character when it
/// moves and turns, stays outside the leg capsules, and draws its rest pose
/// on the Dart backend.
void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  Vector3 at(Float32List p, int i) => Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]);

  Future<(PhysicsWorld, LuminaActor, LuminaAnimatedMeshComponent, LuminaSkinnedClothComponent)> dress() async {
    final w = PhysicsWorld();
    final root = LuminaSceneComponent(location: Vector3(0, 0, 0));
    final actor = LuminaActor(root: root);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: mannyFile.path)..attachToComponent(root);
    actor.addComponent(mesh);
    final skirt = LuminaSkinnedClothComponent(mesh: mesh, sampler: mannySampler, color: Vector3(0.6, 0.1, 0.4));
    actor.addComponent(skirt);
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    await skirt.ready;
    return (w, actor, mesh, skirt);
  }

  /// The mesh's rest pose under its current render transform.
  void pose(LuminaAnimatedMeshComponent mesh, LuminaSkinnedClothComponent skirt) =>
      skirt.modifyPose(Float64List.fromList(skirt.skeleton!.restPose), mesh.renderTransform, 1 / 60);

  List<Vector3> worldVertices(LuminaSkinnedClothComponent skirt) {
    final p = skirt.currentSimPositions();
    return [for (var i = 0; i < p.length ~/ 3; i++) skirt.worldTransform.transform3(at(p, i))];
  }

  test('the skirt is built around the pelvis: a hard-skinned waist ring, weights summing to 1, a 25 cm hem freedom', () async {
    LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.dart;
    final (w, _, _, skirt) = await dress();
    addTearDown(w.dispose);
    final g = skirt.geometry!;
    final skin = skirt.skin!;
    expect(g.simVertexCount, 32 * 13);
    final pelvis = skirt.skeleton!.slotNamed('pelvis');
    for (var i = 0; i < 32; i++) {
      expect(skin.joints[4 * i], pelvis);
      expect(skin.maxDistances[i], 0);
    }
    for (var i = 0; i < g.simVertexCount; i++) {
      final sum = skin.weights[4 * i] + skin.weights[4 * i + 1] + skin.weights[4 * i + 2] + skin.weights[4 * i + 3];
      expect(sum, closeTo(1, 1e-5));
    }
    expect(skin.maxDistances.reduce(math.max), closeTo(25, 1e-3));
    // The waist sits at the mannequin's hips (about 1 m up).
    expect(g.bounds.max.y, inInclusiveRange(85, 115));
    expect(skirt.isSimulating, isFalse, reason: 'cloth needs Jolt');
  }, skip: mannySkip);

  test('nodes the mesh cannot address (left as zeros) are posed at rest, not collapsed', () async {
    LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.dart;
    final (w, _, mesh, skirt) = await dress();
    addTearDown(w.dispose);
    final full = Float64List.fromList(skirt.skeleton!.restPose);
    skirt.modifyPose(full, mesh.renderTransform, 1 / 60);
    final expected = Float64List.fromList(skirt.worldAffines!);
    // The mesh fills the bones it drives; the rest stays zero.
    final partial = Float64List(full.length);
    for (final name in ['pelvis', 'thigh_l', 'thigh_r', 'calf_l', 'calf_r']) {
      final slot = skirt.skeleton!.slotNamed(name);
      partial.setRange(slot * 10, slot * 10 + 10, full, slot * 10);
    }
    skirt.modifyPose(partial, mesh.renderTransform, 1 / 60);
    expect(skirt.worldAffines, expected);
  }, skip: mannySkip);

  group('on Jolt', () {
    setUp(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt);

    test('the waist stays on the body, the hem hangs within its freedom and outside the leg capsules', () async {
      final (w, _, mesh, skirt) = await dress();
      addTearDown(w.dispose);
      pose(mesh, skirt);
      w.run(2, (_) => pose(mesh, skirt));
      expect(skirt.isSimulating, isTrue);
      final backend = w.physics.backend as LuminaJoltPhysicsBackend;
      expect(backend.clothColliderCount(skirt), greaterThan(10), reason: 'limb capsules from the generated physics asset');
      final g = skirt.geometry!;
      final now = worldVertices(skirt);
      final rest = [for (var i = 0; i < g.simVertexCount; i++) skirt.worldTransform.transform3(g.simVertex(i))];
      expect(now.every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite), isTrue);
      for (var i = 0; i < g.simVertexCount; i++) {
        final freedom = skirt.skin!.maxDistances[i];
        expect(now[i].distanceTo(rest[i]), lessThan(freedom + 2.0), reason: 'vertex $i within its $freedom cm (and its thickness)');
      }
      // Above the floor and hanging (the hem lower than the waist).
      expect(now.map((v) => v.y).reduce(math.min), greaterThan(30));
      // Outside the thigh and calf capsules (by the cloth's thickness).
      final skeleton = skirt.skeleton!;
      final world = Float64List(skeleton.nodes.length * 12);
      skeleton.world(skeleton.restPose, LuminaRagdollSkeleton.affineOf(mesh.renderTransform), world);
      var deepest = 0.0;
      for (final body in LuminaPhysicsAssetGenerator.fromSampler(mannySampler).bodies) {
        if (!body.bone.contains('thigh') && !body.bone.contains('calf')) continue;
        final bone = LuminaRagdollSkeleton.frameOf(world, skeleton.slotNamed(body.bone));
        final rotation = bone.rotation * body.offsetQuaternion;
        final centre = bone.position + (body.offsetVector..applyQuaternion(bone.rotation));
        final axis = Vector3(0, 1, 0)..applyQuaternion(rotation);
        final half = body.effectiveHalfHeight - body.radius;
        for (final v in now) {
          final t = (v - centre).dot(axis).clamp(-half, half);
          deepest = math.max(deepest, body.radius - v.distanceTo(centre + axis * t));
        }
      }
      expect(deepest, lessThan(1.5), reason: 'deepest inside a leg capsule: $deepest cm');
    }, skip: mannySkip);

    test('the skirt follows the character: moved 1 m and turned 90°, the waist is on the body again', () async {
      final (w, actor, mesh, skirt) = await dress();
      addTearDown(w.dispose);
      pose(mesh, skirt);
      w.run(0.5, (_) => pose(mesh, skirt));
      for (var i = 1; i <= 60; i++) {
        actor.rootComponent
          ..relativeLocation = Vector3(100.0 * i / 60, 0, 0)
          ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2 * i / 60);
        w.run(1 / 60, (_) => pose(mesh, skirt));
      }
      w.run(1, (_) => pose(mesh, skirt));
      final g = skirt.geometry!;
      final now = worldVertices(skirt);
      for (var i = 0; i < 32; i++) {
        final skinned = skirt.worldTransform.transform3(g.simVertex(i));
        expect(now[i].distanceTo(skinned), lessThan(2.0), reason: 'waist vertex $i on the body (pushed out by its thickness at most)');
      }
      final centre = now.fold(Vector3.zero(), (a, v) => a..add(v))..scale(1 / now.length);
      expect(centre.x, closeTo(100, 15));
    }, skip: mannySkip);
  });
}
