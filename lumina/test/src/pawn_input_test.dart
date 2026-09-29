import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Pawn Input and Controller Rotation Tests (Pawn Task 02)', () {
    test('addMovementInput accumulates without per-call normalization', () {
      final pawn = LuminaPawn();

      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 1.0);
      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 1.0);

      expect(pawn.getPendingMovementInputVector(), equals(Vector3(2.0, 0.0, 0.0)));
    });

    test('addMovementInput with negative scale reverses direction and scale 0 is no-op', () {
      final pawn = LuminaPawn();

      pawn.addMovementInput(Vector3(0.0, 0.0, 1.0), -0.5);
      expect(pawn.getPendingMovementInputVector(), equals(Vector3(0.0, 0.0, -0.5)));

      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 0.0);
      expect(pawn.getPendingMovementInputVector(), equals(Vector3(0.0, 0.0, -0.5)));
    });

    test('consumeMovementInputVector transitions pending to last and second consume returns zero', () {
      final pawn = LuminaPawn();

      pawn.addMovementInput(Vector3(2.0, 0.0, 0.0), 1.0);

      final consumed1 = pawn.consumeMovementInputVector();
      expect(consumed1, equals(Vector3(2.0, 0.0, 0.0)));
      expect(pawn.getPendingMovementInputVector(), equals(Vector3.zero()));
      expect(pawn.getLastMovementInputVector(), equals(Vector3(2.0, 0.0, 0.0)));

      final consumed2 = pawn.consumeMovementInputVector();
      expect(consumed2, equals(Vector3.zero()));
      expect(pawn.getLastMovementInputVector(), equals(Vector3.zero()));
    });

    test('Mutating vector returned by consumeMovementInputVector does not corrupt internal state', () {
      final pawn = LuminaPawn();

      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 1.0);
      final vec = pawn.consumeMovementInputVector();
      vec.x = 999.0;

      expect(pawn.getLastMovementInputVector().x, equals(1.0));
    });

    test('Yaw-only default flag: faceRotation sets yaw while pitch and roll remain unchanged', () {
      final pawn = LuminaPawn();
      expect(pawn.bUseControllerRotationPitch, isFalse);
      expect(pawn.bUseControllerRotationYaw, isTrue);
      expect(pawn.bUseControllerRotationRoll, isFalse);

      pawn.faceRotation(Vector3(30.0, 90.0, 10.0), 1.0 / 60.0);

      // Verify rotation has 90 deg yaw
      final euler = _quaternionToDegrees(pawn.actorRotation);
      expect(euler.y, closeTo(90.0, 1e-4));
      expect(euler.x, closeTo(0.0, 1e-4));
      expect(euler.z, closeTo(0.0, 1e-4));
      // Positive yaw turns right: the pawn faces, and is drawn facing, +X.
      final forward = pawn.rootComponent.forwardVector;
      expect(forward.x, closeTo(1.0, 1e-9));
      expect(forward.z, closeTo(0.0, 1e-9));
    });

    test('All 3 flags true sets full control rotation', () {
      final pawn = LuminaPawn()
        ..bUseControllerRotationPitch = true
        ..bUseControllerRotationYaw = true
        ..bUseControllerRotationRoll = true;

      pawn.faceRotation(Vector3(30.0, 90.0, 10.0), 1.0 / 60.0);

      final euler = _quaternionToDegrees(pawn.actorRotation);
      expect(euler.x, closeTo(30.0, 1e-4));
      expect(euler.y, closeTo(90.0, 1e-4));
      expect(euler.z, closeTo(10.0, 1e-4));
    });

    test('All 3 flags false leaves actorRotation untouched', () {
      final pawn = LuminaPawn()
        ..bUseControllerRotationPitch = false
        ..bUseControllerRotationYaw = false
        ..bUseControllerRotationRoll = false;

      final initialRotation = pawn.actorRotation.clone();
      pawn.faceRotation(Vector3(30.0, 90.0, 10.0), 1.0 / 60.0);

      expect(pawn.actorRotation, equals(initialRotation));
    });

    test('addControllerYawInput adds to controller controlRotation when possessed and no-ops when unpossessed', () {
      final pawn = LuminaPawn();
      final pc = LuminaPlayerController();

      pawn.addControllerYawInput(45.0);
      expect(pc.controlRotation.y, equals(0.0));

      pc.possess(pawn);
      pawn.addControllerYawInput(45.0);
      pawn.addControllerYawInput(45.0);
      expect(pc.controlRotation.y, equals(90.0));
    });

    test('LuminaPlayerController ticks and clamps pitch to [-89.9, 89.9]', () {
      final pawn = LuminaPawn()..bUseControllerRotationPitch = true;
      final pc = LuminaPlayerController();
      pc.possess(pawn);

      pc.controlRotation = Vector3(120.0, 0.0, 0.0);
      pc.onTick(1.0 / 60.0);

      expect(pc.controlRotation.x, closeTo(89.9, 1e-5));
      final euler = _quaternionToDegrees(pawn.actorRotation);
      expect(euler.x, closeTo(89.9, 1e-4));
    });
  });
}

/// The pawn's Euler degrees for its actor rotation, as the engine decodes it
/// (the actor rotation is the drawn one, positive yaw turns right).
Vector3 _quaternionToDegrees(Quaternion q) => luminaPawnQuaternionToEuler(q);
