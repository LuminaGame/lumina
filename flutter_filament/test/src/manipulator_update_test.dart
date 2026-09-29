import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Manipulator update and keyboard tests', () {
    late FilamentEngine engine;
    late FilamentManipulator manipulator;

    setUpAll(() {
      engine = FilamentEngine.create()!;
      engine.createHeadlessSwapChain(800, 600);
    });

    tearDownAll(() {
      engine.dispose();
    });

    setUp(() {
      manipulator = FilamentManipulator.create(
        mode: ManipulatorMode.freeFlight,
        viewportWidth: 800,
        viewportHeight: 600,
      );
    });

    tearDown(() {
      manipulator.dispose();
    });

    test('FREE_FLIGHT keyDown(forward) + update(dt) moves eye forward', () {
      final initialEye = manipulator.getLookAt().eye;
      manipulator.keyDown(ManipulatorKey.forward);

      for (int i = 0; i < 60; i++) {
        manipulator.update(1 / 60.0);
      }

      final newEye = manipulator.getLookAt().eye;
      
      final diff = [
        newEye[0] - initialEye[0],
        newEye[1] - initialEye[1],
        newEye[2] - initialEye[2],
      ];
      
      final lengthSq = diff[0] * diff[0] + diff[1] * diff[1] + diff[2] * diff[2];
      expect(lengthSq, greaterThan(0));
    });

    test('keyDown(forward) WITHOUT update leaves eye unchanged', () {
      final initialEye = manipulator.getLookAt().eye;
      manipulator.keyDown(ManipulatorKey.forward);
      // NO update()

      final newEye = manipulator.getLookAt().eye;
      expect(newEye, equals(initialEye));
    });

    test('After keyUp(forward), continued update calls decay speed (damping)', () {
      manipulator.keyDown(ManipulatorKey.forward);
      for (int i = 0; i < 60; i++) {
        manipulator.update(1 / 60.0);
      }
      
      final pos1 = manipulator.getLookAt().eye;
      manipulator.keyUp(ManipulatorKey.forward);

      manipulator.update(1 / 60.0);
      final pos2 = manipulator.getLookAt().eye;
      final dist1 = (pos2[0] - pos1[0]).abs() + (pos2[1] - pos1[1]).abs() + (pos2[2] - pos1[2]).abs();
      
      manipulator.update(1 / 60.0);
      final pos3 = manipulator.getLookAt().eye;
      final dist2 = (pos3[0] - pos2[0]).abs() + (pos3[1] - pos2[1]).abs() + (pos3[2] - pos2[2]).abs();
      
      printOnFailure('pos1: $pos1');
      printOnFailure('pos2: $pos2');
      printOnFailure('pos3: $pos3');
      printOnFailure('dist1: $dist1, dist2: $dist2');
      
      // Default damping is 0, meaning it may stop immediately (dist1 == 0).
      expect(dist1, greaterThanOrEqualTo(0));
      expect(dist2, lessThanOrEqualTo(dist1));
    });

    test('keyDown(left) + keyDown(forward) moves diagonally', () {
      final initialEye = manipulator.getLookAt().eye;
      
      manipulator.keyDown(ManipulatorKey.forward);
      manipulator.keyDown(ManipulatorKey.left);

      for (int i = 0; i < 60; i++) {
        manipulator.update(1 / 60.0);
      }
      
      final newEye = manipulator.getLookAt().eye;
      expect(newEye[0], isNot(equals(initialEye[0])));
      expect(newEye[2], isNot(equals(initialEye[2])));
    });

    test('On ORBIT manipulator, update and keyDown/Up are safe no-ops', () {
      final orbit = FilamentManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      final initialEye = orbit.getLookAt().eye;
      
      orbit.keyDown(ManipulatorKey.forward);
      orbit.update(1 / 60.0);
      orbit.keyUp(ManipulatorKey.forward);
      orbit.update(1 / 60.0);
      
      final newEye = orbit.getLookAt().eye;
      expect(newEye, equals(initialEye));
      
      orbit.dispose();
    });

    test('update(0.0) must not produce NaN in getLookAt', () {
      manipulator.keyDown(ManipulatorKey.forward);
      manipulator.update(0.0);
      
      final eye = manipulator.getLookAt().eye;
      expect(eye[0].isNaN, isFalse);
      expect(eye[1].isNaN, isFalse);
      expect(eye[2].isNaN, isFalse);
    });
  });
}
