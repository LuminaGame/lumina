import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class CustomEyesPawn extends LuminaPawn {
  @override
  ({Vector3 location, Vector3 rotation}) getActorEyesViewPoint() {
    return (
      location: Vector3(100.0, 200.0, 300.0),
      rotation: Vector3(10.0, 20.0, 30.0),
    );
  }
}

void main() {
  group('Pawn View Point Tests (Pawn Task 03)', () {
    test('Pawn at (1000, 0, 500) with default baseEyeHeight gives eye location (1000, 160, 500)', () {
      final pawn = LuminaPawn(location: Vector3(1000.0, 0.0, 500.0));
      expect(pawn.getPawnViewLocation(), equals(Vector3(1000.0, 160.0, 500.0)));
    });

    test('baseEyeHeight == 0.0 gives view location equal to actorLocation', () {
      final pawn = LuminaPawn(location: Vector3(1000.0, 200.0, 500.0))..baseEyeHeight = 0.0;
      expect(pawn.getPawnViewLocation(), equals(Vector3(1000.0, 200.0, 500.0)));
    });

    test('Possessed pawn with controller controlRotation returns controller controlRotation for getViewRotation', () {
      final pawn = LuminaPawn();
      final pc = LuminaPlayerController();
      pc.possess(pawn);

      pc.controlRotation = Vector3(15.0, 45.0, 0.0);
      expect(pawn.getViewRotation(), equals(Vector3(15.0, 45.0, 0.0)));
    });

    test('Unpossessed pawn rotated 90 deg yaw returns actor rotation in degrees for getViewRotation', () {
      // +90° about +Y draws the pawn turned left (its −Z towards −X), and
      // positive view yaw turns right, so it looks along yaw −90.
      final pawn = LuminaPawn(rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 90.0 * 3.1415926535897932 / 180.0));
      final rot = pawn.getViewRotation();

      expect(pawn.rootComponent.forwardVector.x, closeTo(-1.0, 1e-9));
      expect(rot.y, closeTo(-90.0, 1e-4));
      expect(rot.x, closeTo(0.0, 1e-4));
      expect(rot.z, closeTo(0.0, 1e-4));
    });

    test('getActorEyesViewPoint returns record with location and rotation', () {
      final pawn = LuminaPawn(location: Vector3(100.0, 200.0, 300.0))..baseEyeHeight = 150.0;
      final eyes = pawn.getActorEyesViewPoint();

      expect(eyes.location, equals(Vector3(100.0, 350.0, 300.0)));
      expect(eyes.rotation, equals(pawn.getViewRotation()));
    });

    test('controller.getPlayerViewPoint delegates to possessed pawn and falls back when unpossessed', () {
      final pawn = LuminaPawn(location: Vector3(500.0, 0.0, 500.0));
      final pc = LuminaPlayerController();
      pc.controlRotation = Vector3(10.0, 20.0, 0.0);

      pc.possess(pawn);
      final viewPossessed = pc.getPlayerViewPoint();
      expect(viewPossessed.location, equals(pawn.getPawnViewLocation()));
      expect(viewPossessed.rotation, equals(pawn.getViewRotation()));

      pc.unpossess();
      final viewUnpossessed = pc.getPlayerViewPoint();
      expect(viewUnpossessed.location, equals(Vector3.zero()));
      expect(viewUnpossessed.rotation, equals(Vector3(10.0, 20.0, 0.0)));
    });

    test('LuminaCharacter derives baseEyeHeight from capsule default and honors constructor override', () {
      final charDefault = LuminaCharacter();
      // Above the capsule centre — 0.8 × the 80 cm half height, eyes 144 cm above the feet.
      expect(charDefault.baseEyeHeight, closeTo(64.0, 1e-4));

      final charCustom = LuminaCharacter(baseEyeHeight: 170.0);
      expect(charCustom.baseEyeHeight, equals(170.0));
    });

    test('Subclass overriding getActorEyesViewPoint is honored polymorphically by getPlayerViewPoint', () {
      final customPawn = CustomEyesPawn();
      final pc = LuminaPlayerController();
      pc.possess(customPawn);

      final viewPoint = pc.getPlayerViewPoint();
      expect(viewPoint.location, equals(Vector3(100.0, 200.0, 300.0)));
      expect(viewPoint.rotation, equals(Vector3(10.0, 20.0, 30.0)));
    });
  });
}
