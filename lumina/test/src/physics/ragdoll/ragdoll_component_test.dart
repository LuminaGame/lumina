import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';
import 'ragdoll_fixture.dart';

/// A character (capsule 35 × 90, movement, the mannequin mesh under the
/// capsule, a ragdoll component) standing on [PhysicsWorld]'s floor or
/// dropped from [height]. The mesh is not drawn: every frame the test hands
/// the ragdoll the rest pose as the "animation", as the mesh would.
class _Character {
  _Character({double height = 0.0, List<String> getUpClips = const [], bool clips = true}) {
    w = PhysicsWorld();
    capsule = LuminaCapsuleComponent(location: Vector3(0, 90.0 + height, 0), radius: 35, halfHeight: 90)
      ..objectType = CollisionObjectType.pawn;
    actor = LuminaActor(root: capsule);
    movement = LuminaCharacterMovementComponent();
    actor.addComponent(movement);
    mesh = LuminaAnimatedMeshComponent(meshAssetPath: 'mannequin.glb')
      ..relativeLocation = Vector3(0, -90, 0)
      ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi);
    mesh.attachToComponent(capsule);
    final sampler = clips ? LuminaGlbAnimationSampler.fromGlb(mannyWithGetUps()) : mannySampler;
    ragdoll = LuminaRagdollComponent(mesh: mesh, getUpClips: getUpClips, flailClip: clips ? 'Flail' : '')
      ..setUp(sampler, LuminaPhysicsAssetGenerator.fromSampler(sampler));
    actor.addComponent(ragdoll);
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    if (height > 0) movement.setMovementMode(MovementMode.falling);
  }

  late final PhysicsWorld w;
  late final LuminaCapsuleComponent capsule;
  late final LuminaActor actor;
  late final LuminaCharacterMovementComponent movement;
  late final LuminaAnimatedMeshComponent mesh;
  late final LuminaRagdollComponent ragdoll;

  /// What the mesh would do this frame, then the world tick.
  Float64List frame([double dt = 1 / 60, bool tick = true]) {
    final nodes = ragdoll.poseModifierNodes;
    final rest = ragdoll.getUpPlan != null || ragdoll.overlayClip != null
        ? LuminaRagdollSkeleton(ragdoll.sampler!, allNodes: true).restPose
        : LuminaRagdollSkeleton(ragdoll.sampler!, bones: [for (final b in ragdoll.physicsAsset!.bodies) ragdoll.sampler!.indexOfNode(b.bone)]).restPose;
    expect(rest.length, nodes.length * 10);
    final pose = Float64List.fromList(rest);
    ragdoll.modifyPose(pose, mesh.renderTransform, dt);
    if (tick) w.world.tick(dt);
    return pose;
  }

  void dispose() => w.dispose();
}

void main() {
  group('ragdoll component', () {
    test('R toggles: limp at the animated pose, then blends back to the animation', () {
      final c = _Character();
      for (var i = 0; i < 10; i++) {
        c.frame();
      }
      expect(c.ragdoll.state, LuminaRagdollState.animated);
      c.ragdoll.toggleRagdoll();
      expect(c.ragdoll.state, LuminaRagdollState.ragdoll);
      expect(c.movement.movementMode, MovementMode.custom);
      expect(c.ragdoll.ragdoll!.bodies.length, c.ragdoll.physicsAsset!.bodies.length);
      // The bodies start on the animated bones: the pelvis body where the
      // pelvis was.
      final pelvis = c.ragdoll.ragdoll!.root.boneFrame();
      expect(pelvis.position.y, closeTo(96, 3));
      for (var i = 0; i < 120; i++) {
        c.frame();
      }
      // It collapsed; the capsule followed the pelvis on the floor.
      expect(c.ragdoll.ragdoll!.root.boneFrame().position.y, lessThan(40));
      final p = c.ragdoll.ragdoll!.root.boneFrame().position;
      expect(c.capsule.worldLocation.x, closeTo(p.x, 0.5));
      expect(c.capsule.worldLocation.z, closeTo(p.z, 0.5));
      c.ragdoll.toggleRagdoll();
      expect(c.ragdoll.state, LuminaRagdollState.blendingOut);
      expect(c.movement.movementMode, MovementMode.walking);
      for (var i = 0; i < 40; i++) {
        c.frame();
      }
      expect(c.ragdoll.state, LuminaRagdollState.animated);
      expect(c.w.physics.bodies.where((b) => identical(b.owner, c.actor)), isEmpty);
      c.dispose();
    });

    test('an impulse starts the ragdoll and pushes the hit bone', () {
      final c = _Character();
      c.frame();
      c.ragdoll.addImpulse(Vector3(0, 0, 3000), bone: 'head');
      expect(c.ragdoll.isRagdoll, isTrue);
      final head = c.ragdoll.ragdoll!.bodyOf('head')!.body.linearVelocity;
      expect(head.z, greaterThan(100));
      c.dispose();
    });

    test('a long fall goes limp in the air, lands, settles and gets up the way it lies', () {
      final c = _Character(height: 1500, getUpClips: const ['GetUp_Front', 'GetUp_Back']);
      var startedAt = -1.0, startedSpeed = 0.0, startedHeight = 0.0;
      String? clip;
      var gotUpAt = -1.0;
      LuminaBoneFrame? snapshotPelvis;
      var lastSpeed = 0.0;
      c.ragdoll.onRagdollStarted = () {
        startedSpeed = lastSpeed;
        startedHeight = c.capsule.worldLocation.y;
      };
      c.ragdoll.onGetUpStarted = (name) => clip = name;
      var t = 0.0;
      while (t < 20 && gotUpAt < 0) {
        final before = c.ragdoll.state;
        if (before == LuminaRagdollState.ragdoll) snapshotPelvis = c.ragdoll.ragdoll!.root.boneFrame();
        lastSpeed = -c.movement.velocity.y;
        c.frame();
        t += 1 / 60;
        if (startedAt < 0 && c.ragdoll.state == LuminaRagdollState.ragdoll) startedAt = t;
        if (before == LuminaRagdollState.ragdoll && c.ragdoll.state == LuminaRagdollState.gettingUp) {
          // The first get-up frame shows the ragdoll's last pose.
          final pose = c.frame(0.0, false);
          final getUp = LuminaRagdollGetUp(c.ragdoll.sampler!);
          final world = Float64List(getUp.skeleton.length * 12);
          getUp.skeleton.world(pose, LuminaRagdollSkeleton.affineOf(c.mesh.renderTransform), world);
          final pelvis = LuminaRagdollSkeleton.frameOf(world, getUp.skeleton.slotNamed('pelvis'));
          expect((pelvis.position - snapshotPelvis!.position).length, lessThan(1.0));
          expect(c.ragdoll.getUpPlan!.faceDown, getUp.isFaceDown(snapshotPelvis));
        }
        if (gotUpAt < 0 && startedAt > 0 && c.ragdoll.state == LuminaRagdollState.animated) gotUpAt = t;
      }
      // ignore: avoid_print
      print('fall: limp at ${startedAt.toStringAsFixed(2)} s (${startedSpeed.toStringAsFixed(0)} cm/s, '
          'capsule ${startedHeight.toStringAsFixed(0)} cm), got up with $clip at ${gotUpAt.toStringAsFixed(2)} s');
      expect(startedAt, greaterThan(0));
      expect(startedHeight, greaterThan(150), reason: 'went limp in the air');
      expect(startedSpeed, greaterThan(1250));
      expect(clip, isNotNull);
      expect(gotUpAt, greaterThan(startedAt));
      expect(c.movement.movementMode, MovementMode.walking);
      // Standing on the floor again: the capsule's bottom within a few cm.
      expect(c.capsule.worldLocation.y - 90, closeTo(0, 5));
      c.dispose();
    });

    test('a medium fall plays the heavy landing over the animation', () {
      final c = _Character(height: 400);
      c.ragdoll.hardLandingClip = 'Flail';
      double? impact;
      c.ragdoll.onHardLanding = (s) => impact = s;
      var played = false;
      for (var i = 0; i < 120; i++) {
        c.frame();
        played |= c.ragdoll.overlayClip == 'Flail';
      }
      expect(impact, isNotNull);
      expect(impact!, greaterThan(750));
      expect(played, isTrue);
      expect(c.ragdoll.state, LuminaRagdollState.animated);
      c.dispose();
    });
  }, skip: mannySkip);
}
