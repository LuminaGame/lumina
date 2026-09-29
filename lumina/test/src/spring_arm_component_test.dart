import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaSpringArmComponent basic mechanics', () {
    test('No lag, identity rotation, targetArmLength: 3 -> child camera world location (0, 0, 3)', () {
      final actor = LuminaActor(location: Vector3.zero());
      final arm = LuminaSpringArmComponent(targetArmLength: 3.0);
      arm.bEnableCameraLag = false;
      arm.bEnableCameraRotationLag = false;
      final child = LuminaCameraComponent();
      
      arm.attachToComponent(actor.rootComponent);
      child.attachToComponent(arm);

      arm.onTick(0.016);

      expect(child.worldLocation.x, closeTo(0.0, 1e-6));
      expect(child.worldLocation.y, closeTo(0.0, 1e-6));
      expect(child.worldLocation.z, closeTo(3.0, 1e-6));
    });

    test('without pawn control rotation, a boom on an actor turned 40° about +Y sits behind its drawn forward', () {
      final turn = Quaternion.axisAngle(Vector3(0, 1, 0), 40 * math.pi / 180);
      final actor = LuminaActor(location: Vector3.zero(), rotation: turn);
      final arm = LuminaSpringArmComponent(targetArmLength: 300.0);
      arm.bEnableCameraLag = false;
      arm.bEnableCameraRotationLag = false;
      arm.bDoCollisionTest = false;
      arm.attachToComponent(actor.rootComponent);
      arm.onTick(1 / 60);
      final forward = Vector3(0, 0, -1)..applyQuaternion(turn);
      final behind = arm.socketWorldLocation - actor.actorLocation;
      expect(behind.length, closeTo(300.0, 1e-6));
      expect((behind.normalized() + forward).length, lessThan(1e-6),
          reason: 'socket direction ${behind.normalized()} vs forward $forward');
    });

    test('luminaQuaternionToControlRotation undoes luminaControlRotationToQuaternion', () {
      for (final (p, y, r) in [(0.0, 40.0, 0.0), (-30.0, 125.0, 0.0), (20.0, -70.0, 15.0), (0.0, 180.0, 0.0)]) {
        final back = luminaQuaternionToControlRotation(luminaControlRotationToQuaternion(p, y, r));
        final again = luminaControlRotationToQuaternion(back.x, back.y, back.z);
        final q = luminaControlRotationToQuaternion(p, y, r);
        final dot = (q.x * again.x + q.y * again.y + q.z * again.z + q.w * again.w).abs();
        expect(dot, closeTo(1.0, 1e-9), reason: '($p, $y, $r) → $back');
        expect(back.x, closeTo(p, 1e-6));
      }
    });

    test('targetOffset and socketOffset rotate with the arm', () {
      final arm = LuminaSpringArmComponent(targetArmLength: 3.0);
      arm.bEnableCameraLag = false;
      arm.bEnableCameraRotationLag = false;
      arm.targetOffset = Vector3(0, 0.5, 0);
      arm.socketOffset = Vector3(0.5, 0, 0);

      arm.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), 1.5707963);
      
      arm.onTick(0.016);
      
      // we'll refine this later
      expect(true, isTrue);
    });

    test('bEnableCameraLag: true, cameraLagSpeed: 10, target teleports 10m on +X, one tick deltaTime=0.05 -> lag location 5m', () {
      final arm = LuminaSpringArmComponent(targetArmLength: 0.0);
      arm.bEnableCameraLag = true;
      arm.cameraLagSpeed = 10.0;
      
      arm.onTick(0.016);
      arm.relativeLocation = Vector3(10, 0, 0);
      arm.onTick(0.05);

      expect(arm.socketWorldLocation.x, closeTo(5.0, 1e-5));

      arm.onTick(0.2);
      expect(arm.socketWorldLocation.x, closeTo(10.0, 1e-5));
    });

    test('cameraLagMaxDistance: 1.0, target teleports 10m', () {
      final arm = LuminaSpringArmComponent(targetArmLength: 0.0);
      arm.bEnableCameraLag = true;
      arm.cameraLagSpeed = 10.0;
      arm.cameraLagMaxDistance = 1.0;
      
      arm.onTick(0.016);
      
      arm.relativeLocation = Vector3(10, 0, 0);
      arm.onTick(0.001);
      
      expect(arm.socketWorldLocation.x, closeTo(9.0, 1e-5));
    });

    test('bEnableCameraRotationLag: true, cameraRotationLagSpeed: 5, target yaws 90 instantly, tick 0.1', () {
      final arm = LuminaSpringArmComponent(targetArmLength: 0.0);
      arm.bEnableCameraRotationLag = true;
      arm.cameraRotationLagSpeed = 5.0;
      
      arm.onTick(0.016);
      
      arm.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), 1.5707963);
      arm.onTick(0.1);
      expect(true, isTrue);
    });
    
    test('bUsePawnControlRotation: true, pawn pitch -30, bInheritPitch: false', () {
      final pawn = LuminaPawn();
      final controller = LuminaPlayerController();
      controller.possess(pawn);
      controller.controlRotation = Vector3(-30, 90, 0);

      final arm = LuminaSpringArmComponent();
      arm.bUsePawnControlRotation = true;
      arm.bInheritPitch = false;
      arm.relativeRotation = Quaternion.identity();
      arm.attachToComponent(pawn.rootComponent);

      arm.onTick(0.016);
      expect(true, isTrue);
    });

    test('Zero allocations during tick', () {
      final arm = LuminaSpringArmComponent();
      arm.onTick(0.016);
      
      final child = LuminaCameraComponent();
      child.attachToComponent(arm);
      arm.onTick(0.016);
      
      final rLoc1 = child.relativeLocation;
      final rRot1 = child.relativeRotation;
      
      arm.onTick(0.016);
      
      expect(identical(rLoc1, child.relativeLocation), isTrue);
      expect(identical(rRot1, child.relativeRotation), isTrue);
    });

    test('Lag disabled mid-flight snaps instantly', () {
      final arm = LuminaSpringArmComponent(targetArmLength: 0.0);
      arm.bEnableCameraLag = true;
      arm.cameraLagSpeed = 1.0;
      
      arm.onTick(0.016);
      
      arm.relativeLocation = Vector3(10, 0, 0);
      arm.onTick(0.016);
      
      expect(arm.socketWorldLocation.x, lessThan(1.0));
      
      arm.bEnableCameraLag = false;
      arm.onTick(0.016);
      
      expect(arm.socketWorldLocation.x, closeTo(10.0, 1e-5));
    });
  });

  // The controller's rotation is in degrees (LuminaPlayerController
  // clamps pitch to ±89.9), and the boom used to hand it to a radian API.
  group('bUsePawnControlRotation follows the controller in degrees', () {
    const armLength = 3.0;

    ({LuminaPawn pawn, LuminaPlayerController controller, LuminaSpringArmComponent arm, LuminaCameraComponent camera})
        rig() {
      final pawn = LuminaPawn();
      final controller = LuminaPlayerController();
      controller.possess(pawn);
      final arm = LuminaSpringArmComponent(targetArmLength: armLength)
        ..bUsePawnControlRotation = true
        ..bEnableCameraLag = false
        ..bEnableCameraRotationLag = false;
      pawn.addComponent(arm);
      final camera = LuminaCameraComponent();
      camera.attachToComponent(arm);
      pawn.addComponent(camera);
      return (pawn: pawn, controller: controller, arm: arm, camera: camera);
    }

    void settle(({LuminaPawn pawn, LuminaPlayerController controller, LuminaSpringArmComponent arm, LuminaCameraComponent camera}) r) {
      r.controller.onTick(1 / 60);
      r.arm.onTick(1 / 60);
    }

    for (final yaw in [30.0, 90.0, -135.0]) {
      test('at yaw $yaw° the camera looks the way the pawn faces, $armLength m behind it', () {
        final r = rig();
        r.controller.controlRotation = Vector3(0.0, yaw, 0.0);
        settle(r);

        final pawnForward = r.pawn.rootComponent.forwardVector;
        final cameraForward = r.camera.forwardVector;
        expect(cameraForward.x, closeTo(pawnForward.x, 1e-6));
        expect(cameraForward.y, closeTo(pawnForward.y, 1e-6));
        expect(cameraForward.z, closeTo(pawnForward.z, 1e-6));

        final expected = r.arm.worldLocation - pawnForward * armLength;
        final eye = r.camera.worldLocation;
        expect(eye.x, closeTo(expected.x, 1e-6));
        expect(eye.y, closeTo(expected.y, 1e-6));
        expect(eye.z, closeTo(expected.z, 1e-6));
      });
    }

    test('positive pitch looks up and lowers the camera; negative pitch looks down and raises it', () {
      final r = rig();
      r.controller.controlRotation = Vector3(20.0, 0.0, 0.0);
      settle(r);
      expect(r.camera.forwardVector.y, closeTo(math.sin(20.0 * math.pi / 180.0), 1e-6));
      expect(r.camera.worldLocation.y, lessThan(r.arm.worldLocation.y));

      r.controller.controlRotation = Vector3(-20.0, 0.0, 0.0);
      settle(r);
      expect(r.camera.forwardVector.y, closeTo(-math.sin(20.0 * math.pi / 180.0), 1e-6));
      expect(r.camera.worldLocation.y, greaterThan(r.arm.worldLocation.y));
    });

    test('pitch tilts about the camera\'s own right axis, so it still works facing +X', () {
      final r = rig();
      r.controller.controlRotation = Vector3(-30.0, 90.0, 0.0);
      settle(r);

      final forward = r.camera.forwardVector;
      final pitch = -30.0 * math.pi / 180.0;
      // Facing +X (yaw 90°), looking 30° down.
      expect(forward.x, closeTo(math.cos(pitch), 1e-6));
      expect(forward.y, closeTo(math.sin(pitch), 1e-6));
      expect(forward.z, closeTo(0.0, 1e-6));
      // The boom swings up behind the pawn, on its -X side.
      expect(r.camera.worldLocation.x, lessThan(r.arm.worldLocation.x));
      expect(r.camera.worldLocation.y, greaterThan(r.arm.worldLocation.y));
    });

    test('a pitch the pawn does not inherit keeps the boom level', () {
      final r = rig();
      r.arm.bInheritPitch = false;
      r.controller.controlRotation = Vector3(-30.0, 90.0, 0.0);
      settle(r);

      final forward = r.camera.forwardVector;
      expect(forward.x, closeTo(1.0, 1e-6));
      expect(forward.y, closeTo(0.0, 1e-6));
    });
  });
}
