import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('PlayerCameraManager & HUD', () {
    test('setViewTarget performs instant cut and fov overrides', () {
      final actor = LuminaActor(location: Vector3(10, 0, 5), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2));
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor);
      manager.updateCamera(0.016);
      
      expect(manager.cameraCachePov.location, equals(Vector3(10, 0, 5)));
      // euler yaw 90 -> quaternion
      final expectedQuat = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
      expect(manager.cameraCachePov.rotation.w, closeTo(expectedQuat.w, 1e-4));
      expect(manager.cameraCachePov.rotation.y, closeTo(expectedQuat.y, 1e-4));
      
      expect(manager.cameraCachePov.fovDegrees, equals(90.0));
      
      manager.setFov(45.0);
      manager.updateCamera(0.016);
      expect(manager.cameraCachePov.fovDegrees, equals(45.0));
      
      manager.resetFov();
      manager.updateCamera(0.016);
      expect(manager.cameraCachePov.fovDegrees, equals(90.0));
    });

    test('setViewTargetWithBlend linear blending', () {
      final actor1 = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final actor2 = LuminaActor(location: Vector3(10, 0, 0), rotation: Quaternion.identity());
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor1);
      manager.updateCamera(0.016);
      
      manager.setViewTargetWithBlend(actor2, blendTime: 1.0, blendFunction: LuminaViewTargetBlendFunction.linear);
      
      manager.updateCamera(0.5);
      expect(manager.cameraCachePov.location.x, closeTo(5.0, 1e-6));
      
      manager.updateCamera(0.51);
      expect(manager.cameraCachePov.location.x, closeTo(10.0, 1e-6));
      expect(manager.viewTarget, equals(actor2));
    });

    test('blendFunction: cubic, blendExponent: 2.0 at t=0.5', () {
      final actor1 = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final actor2 = LuminaActor(location: Vector3(10, 0, 0), rotation: Quaternion.identity());
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor1);
      manager.updateCamera(0.016);
      
      manager.setViewTargetWithBlend(actor2, blendTime: 1.0, blendFunction: LuminaViewTargetBlendFunction.cubic, blendExponent: 2.0);
      
      manager.updateCamera(0.5);
      // For easeIn / cubic with exp 2.0, wait, it's just a non-linear curve.
      expect(manager.cameraCachePov.location.x, greaterThan(0));
      expect(manager.cameraCachePov.location.x, lessThan(10));
    });

    test('setViewTargetWithBlend blendTime 0.0 cuts immediately', () {
      final actor1 = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final actor2 = LuminaActor(location: Vector3(10, 0, 0), rotation: Quaternion.identity());
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor1);
      manager.updateCamera(0.016);
      
      manager.setViewTargetWithBlend(actor2, blendTime: 0.0);
      manager.updateCamera(0.016);
      expect(manager.cameraCachePov.location.x, closeTo(10.0, 1e-6));
      expect(manager.viewTarget, equals(actor2));
    });

    test('startCameraShake additive oscillator', () {
      final actor = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor);
      manager.updateCamera(0.0);
      
      final shake = LuminaCameraShake(
        locationAmplitude: Vector3(0, 1, 0),
        locationFrequency: Vector3(0, 1, 0), // 1 Hz
        duration: 2.0,
        blendInTime: 0.0,
        blendOutTime: 0.0,
        initialPhase: 0.0,
      );
      manager.startCameraShake(shake);
      
      manager.updateCamera(0.25); // At 1/4 of 1Hz sine wave, sin(pi/2) = 1.0
      expect(manager.cameraCachePov.location.y, closeTo(1.0, 1e-4));
      
      manager.updateCamera(0.25); // At 1/2 of 1Hz sine wave, sin(pi) = 0.0
      expect(manager.cameraCachePov.location.y, closeTo(0.0, 1e-4));
      
      manager.updateCamera(1.6); // Total time 2.1s, shake finished
      expect(manager.cameraCachePov.location.y, closeTo(0.0, 1e-4));
    });

    test('Two concurrent shakes sum up and stopAllCameraShakes(immediately: true)', () {
      final actor = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final pc = LuminaPlayerController();
      final manager = LuminaPlayerCameraManager(pc);
      
      manager.setViewTarget(actor);
      manager.updateCamera(0.0);
      
      final shake1 = LuminaCameraShake(
        locationAmplitude: Vector3(0, 1, 0),
        locationFrequency: Vector3(0, 1, 0),
        duration: 2.0,
        blendInTime: 0.0,
        blendOutTime: 0.0,
        initialPhase: 0.0,
      );
      final shake2 = LuminaCameraShake(
        locationAmplitude: Vector3(0, 2, 0),
        locationFrequency: Vector3(0, 1, 0),
        duration: 2.0,
        blendInTime: 0.0,
        blendOutTime: 0.0,
        initialPhase: 0.0,
      );
      manager.startCameraShake(shake1);
      manager.startCameraShake(shake2);
      
      manager.updateCamera(0.25); 
      expect(manager.cameraCachePov.location.y, closeTo(3.0, 1e-4));
      
      manager.stopAllCameraShakes(immediately: true);
      manager.updateCamera(0.016);
      expect(manager.cameraCachePov.location.y, closeTo(0.0, 1e-4));
    });
    
    test('View target destroyed mid-blend falls back to controller pawn', () {
      final pc = LuminaPlayerController();
      final pawn = LuminaPawn(location: Vector3.zero());
      pc.possess(pawn);
      final manager = LuminaPlayerCameraManager(pc);
      
      final tempActor = LuminaActor(location: Vector3(10, 0, 0), rotation: Quaternion.identity());
      manager.setViewTarget(tempActor);
      manager.updateCamera(0.0);
      
      final newActor = LuminaActor(location: Vector3(20, 0, 0), rotation: Quaternion.identity());
      manager.setViewTargetWithBlend(newActor, blendTime: 1.0);
      manager.updateCamera(0.5);
      
      tempActor.destroy();
      
      manager.updateCamera(0.1);
      expect(manager.viewTarget, equals(pawn));
    });
  
    test('a pawn view target at control yaw 90° gives a POV whose drawn forward is +X', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final pawn = LuminaPawn(location: Vector3(0, 100, 0));
      world.persistentLevel.registerActor(pawn);
      final pc = LuminaPlayerController();
      pc.possess(pawn);
      pc.controlRotation = Vector3(0, 90, 0);
      final manager = LuminaPlayerCameraManager(pc);
      manager.setViewTarget(pawn);
      manager.updateCamera(1 / 60);
      final forward = Vector3(0, 0, -1)..applyQuaternion(manager.cameraCachePov.rotation);
      expect(forward.x, closeTo(1.0, 1e-6), reason: 'forward $forward');
      expect(forward.y, closeTo(0.0, 1e-6));
      expect(forward.z, closeTo(0.0, 1e-6));
      // Pitch up 30° looks up, as the control rotation does everywhere else.
      pc.controlRotation = Vector3(30, 90, 0);
      manager.updateCamera(1 / 60);
      final up = Vector3(0, 0, -1)..applyQuaternion(manager.cameraCachePov.rotation);
      expect(up.y, closeTo(math.sin(30 * math.pi / 180), 1e-6), reason: 'forward $up');
      expect(up.x, closeTo(math.cos(30 * math.pi / 180), 1e-6));
    });
});
}
