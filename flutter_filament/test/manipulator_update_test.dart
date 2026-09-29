import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Manipulator update(dt) & WASD Key Flight Control', () {
    test('ManipulatorKey enum values match C++ Manipulator::Key constants', () {
      expect(ManipulatorKey.forward.value, equals(0));
      expect(ManipulatorKey.left.value, equals(1));
      expect(ManipulatorKey.backward.value, equals(2));
      expect(ManipulatorKey.right.value, equals(3));
      expect(ManipulatorKey.up.value, equals(4));
      expect(ManipulatorKey.down.value, equals(5));
    });

    test('FREE_FLIGHT moves with keyDown(forward) + update(dt) loop', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      final initialLookAt = manip.getLookAt();
      final initialEye = initialLookAt.eye;

      // Press forward key and advance frames
      manip.keyDown(ManipulatorKey.forward);

      for (int i = 0; i < 60; i++) {
        manip.update(1.0 / 60.0);
      }

      final afterLookAt = manip.getLookAt();
      final afterEye = afterLookAt.eye;

      // Eye position must have moved forward (displacement along Z < 0 / distance > 0)
      final dx = afterEye[0] - initialEye[0];
      final dy = afterEye[1] - initialEye[1];
      final dz = afterEye[2] - initialEye[2];
      final distSq = dx * dx + dy * dy + dz * dz;

      expect(distSq, greaterThan(0.001));

      manip.dispose();
    });

    test('Regression test: keyDown WITHOUT update does not move the camera', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      final initialLookAt = manip.getLookAt();
      final initialEye = initialLookAt.eye;

      // Press forward key but do NOT call update
      manip.keyDown(ManipulatorKey.forward);

      final immediateLookAt = manip.getLookAt();
      final immediateEye = immediateLookAt.eye;

      expect(immediateEye[0], equals(initialEye[0]));
      expect(immediateEye[1], equals(initialEye[1]));
      expect(immediateEye[2], equals(initialEye[2]));

      manip.dispose();
    });

    test('keyUp causes coasting deceleration and damping convergence', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      // Accelerate forward
      manip.keyDown(ManipulatorKey.forward);
      for (int i = 0; i < 30; i++) {
        manip.update(1.0 / 60.0);
      }

      // Release key
      manip.keyUp(ManipulatorKey.forward);

      double prevDelta = 1e9;
      var lastEye = manip.getLookAt().eye;

      // Simulate coasting
      for (int i = 0; i < 100; i++) {
        manip.update(1.0 / 60.0);
        final currentEye = manip.getLookAt().eye;
        final stepDist = (currentEye[2] - lastEye[2]).abs();

        // Speed step must be non-increasing / decaying
        expect(stepDist, lessThanOrEqualTo(prevDelta + 1e-4));
        prevDelta = stepDist;
        lastEye = currentEye;
      }

      manip.dispose();
    });

    test('Diagonal movement: forward + left key combination', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      final initialEye = manip.getLookAt().eye;

      manip.keyDown(ManipulatorKey.forward);
      manip.keyDown(ManipulatorKey.left);

      for (int i = 0; i < 30; i++) {
        manip.update(1.0 / 60.0);
      }

      final movedEye = manip.getLookAt().eye;
      final dx = (movedEye[0] - initialEye[0]).abs();
      final dz = (movedEye[2] - initialEye[2]).abs();

      // Both X (strafe) and Z (forward) must have moved
      expect(dx, greaterThan(0.001));
      expect(dz, greaterThan(0.001));

      manip.dispose();
    });

    test('ORBIT mode is safe with update(dt) and keys (no crash)', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      final initialEye = manip.getLookAt().eye;

      manip.keyDown(ManipulatorKey.forward);
      manip.update(1.0 / 60.0);
      manip.keyUp(ManipulatorKey.forward);

      final afterEye = manip.getLookAt().eye;
      expect(afterEye[0], equals(initialEye[0]));
      expect(afterEye[1], equals(initialEye[1]));
      expect(afterEye[2], equals(initialEye[2]));

      manip.dispose();
    });

    test('update(0.0) produces valid finite numbers without NaN', () {
      final manip = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 1000,
        viewportHeight: 1000,
      );

      manip.update(0.0);

      final lookAt = manip.getLookAt();
      for (final v in lookAt.eye) {
        expect(v.isNaN, isFalse);
      }
      for (final v in lookAt.target) {
        expect(v.isNaN, isFalse);
      }
      for (final v in lookAt.up) {
        expect(v.isNaN, isFalse);
      }

      manip.dispose();
    });
  });
}
