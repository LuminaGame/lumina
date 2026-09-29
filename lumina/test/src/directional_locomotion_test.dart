import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Idle / 8-way walk selection from a character's velocity
/// relative to the way it faces.
void main() {
  const clips = LuminaLocomotionClipSet(
    idle: 'Idle',
    walk: {
      LuminaLocomotionDirection.forward: 'Fwd',
      LuminaLocomotionDirection.forwardRight: 'FwdRight',
      LuminaLocomotionDirection.right: 'Right',
      LuminaLocomotionDirection.backwardRight: 'BwdRight',
      LuminaLocomotionDirection.backward: 'Bwd',
      LuminaLocomotionDirection.backwardLeft: 'BwdLeft',
      LuminaLocomotionDirection.left: 'Left',
      LuminaLocomotionDirection.forwardLeft: 'FwdLeft',
    },
    walkReferenceSpeed: 250.0, // cm/s
    idleSpeedThreshold: 15.0, // cm/s
  );

  // Facing the engine's default forward, -Z. Its right is +X.
  final facing = Vector3(0.0, 0.0, -1.0);

  LuminaLocomotionPose select(Vector3 velocity, {Vector3? towards, bool falling = false}) =>
      selectLocomotionPose(clips: clips, velocity: velocity, facing: towards ?? facing, isFalling: falling);

  Vector3 heading(double degreesRightOfFacing, double speed) {
    final r = degreesRightOfFacing * math.pi / 180.0;
    // forward -Z, right +X
    return Vector3(math.sin(r) * speed, 0.0, -math.cos(r) * speed);
  }

  group('selectLocomotionPose', () {
    test('below the idle threshold the character idles at normal rate', () {
      final pose = select(Vector3(5.0, 0.0, 0.0));
      expect(pose.clip, 'Idle');
      expect(pose.playRate, 1.0);
      expect(pose.holdCurrent, isFalse);
    });

    test('vertical speed alone does not count as walking', () {
      expect(select(Vector3(0.0, -300.0, 0.0)).clip, 'Idle');
    });

    final sectors = <double, String>{
      0: 'Fwd',
      45: 'FwdRight',
      90: 'Right',
      135: 'BwdRight',
      180: 'Bwd',
      -135: 'BwdLeft',
      -90: 'Left',
      -45: 'FwdLeft',
    };
    sectors.forEach((angle, clip) {
      test('moving ${angle.toStringAsFixed(0)}° right of facing plays $clip', () {
        expect(select(heading(angle, 250.0)).clip, clip);
        // Anywhere inside the 45° sector picks the same clip.
        expect(select(heading(angle + 20.0, 250.0)).clip, clip);
        expect(select(heading(angle - 20.0, 250.0)).clip, clip);
      });
    });

    test('directions are relative to the facing, not to world axes', () {
      // Facing +X (yaw 90° in the engine), moving +X is forward and +Z is right.
      final towardsX = Vector3(1.0, 0.0, 0.0);
      expect(select(Vector3(200.0, 0.0, 0.0), towards: towardsX).clip, 'Fwd');
      expect(select(Vector3(0.0, 0.0, 200.0), towards: towardsX).clip, 'Right');
      expect(select(Vector3(0.0, 0.0, -200.0), towards: towardsX).clip, 'Left');
    });

    test('play rate follows speed over the clip reference speed, clamped', () {
      expect(select(heading(0, 250.0)).playRate, closeTo(1.0, 1e-9));
      expect(select(heading(0, 300.0)).playRate, closeTo(1.2, 1e-9));
      expect(select(heading(0, 500.0)).playRate, closeTo(2.0, 1e-9));
      expect(select(heading(0, 900.0)).playRate, closeTo(2.0, 1e-9));
      expect(select(heading(0, 50.0)).playRate, closeTo(0.5, 1e-9));
    });

    test('while falling the current clip is held at rate 0', () {
      final pose = select(heading(0, 250.0), falling: true);
      expect(pose.holdCurrent, isTrue);
      expect(pose.playRate, 0.0);
    });

    test('a clip set must name all eight directions', () {
      expect(
        () => LuminaLocomotionClipSet.validated(
          idle: 'Idle',
          walk: const {LuminaLocomotionDirection.forward: 'Fwd'},
          walkReferenceSpeed: 250.0,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('backward'))),
      );
    });
  });

  group('LuminaDirectionalLocomotionComponent', () {
    ({LuminaWorld world, LuminaCharacter character, LuminaAnimatedMeshComponent mesh, LuminaDirectionalLocomotionComponent locomotion})
        rig() {
      final world = LuminaWorld();
      world.registerSubsystem(LuminaCollisionSubsystem());
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box,
        size: Vector3(4000.0, 100.0, 4000.0),
        color: Vector3.all(0.5),
        location: Vector3(0.0, -50.0, 0.0),
      ));
      final character = LuminaCharacter(location: Vector3(0.0, 90.0, 0.0));
      character.characterMovement.maxWalkSpeed = 300.0;
      // No native context: the mesh never loads, so clip requests stay
      // pending and currentClip reports what the driver asked for.
      final mesh = LuminaAnimatedMeshComponent(
        meshAssetPath: 'never_loaded.glb',
        location: Vector3(0.0, -80.0, 0.0),
      );
      final locomotion = LuminaDirectionalLocomotionComponent(mesh: mesh, clips: clips);
      character.addComponent(locomotion);
      character.addComponent(mesh);
      world.persistentLevel.registerActor(character);
      world.beginPlay();
      for (var i = 0; i < 30; i++) {
        world.tick(1 / 60);
      }
      expect(character.characterMovement.isFalling, isFalse, reason: 'the rig must stand on the floor');
      return (world: world, character: character, mesh: mesh, locomotion: locomotion);
    }

    void walk(({LuminaWorld world, LuminaCharacter character, LuminaAnimatedMeshComponent mesh, LuminaDirectionalLocomotionComponent locomotion}) r,
        Vector3 direction) {
      for (var i = 0; i < 60; i++) {
        r.character.characterMovement.addInputVector(direction);
        r.world.tick(1 / 60);
      }
    }

    test('a standing character idles', () {
      final r = rig();
      expect(r.mesh.currentClip, 'Idle');
      expect(r.mesh.playRate, 1.0);
    });

    test('walking along the character\'s right vector plays the right walk at a speed-matched rate', () {
      final r = rig();
      walk(r, r.character.rootComponent.rightVector);
      expect(r.mesh.currentClip, 'Right');
      expect(r.mesh.playRate, closeTo(300.0 / 250.0, 0.02));
    });

    test('walking backward plays the backward walk, and stopping returns to idle', () {
      final r = rig();
      walk(r, -r.character.rootComponent.forwardVector);
      expect(r.mesh.currentClip, 'Bwd');

      for (var i = 0; i < 60; i++) {
        r.world.tick(1 / 60);
      }
      expect(r.mesh.currentClip, 'Idle');
    });

    test('a falling character holds its pose', () {
      final r = rig();
      walk(r, r.character.rootComponent.forwardVector);
      r.character.actorLocation = Vector3(0.0, 600.0, 0.0);
      r.character.characterMovement.setMovementMode(MovementMode.falling);
      r.world.tick(1 / 60);
      expect(r.mesh.currentClip, 'Fwd', reason: 'the clip is kept');
      expect(r.mesh.playRate, 0.0);
    });

    for (final yaw in [0.0, 30.0, 90.0, -120.0]) {
      test('the drawn mesh faces the character\'s forward vector at yaw $yaw°', () {
        final r = rig();
        r.character.actorRotation = Quaternion.euler(yaw * math.pi / 180.0, 0.0, 0.0);
        r.world.tick(1 / 60);

        // What the renderer draws: the mesh's world matrix applied to the
        // glTF forward axis, +Z.
        final drawn = r.mesh.worldTransform.getRotation().transformed(Vector3(0.0, 0.0, 1.0));
        final forward = r.character.rootComponent.forwardVector;
        expect(drawn.x, closeTo(forward.x, 1e-6));
        expect(drawn.y, closeTo(0.0, 1e-6));
        expect(drawn.z, closeTo(forward.z, 1e-6));
      });
    }
  });
}
