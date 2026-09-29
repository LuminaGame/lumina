import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Camera Manipulator Raycast API Tests', () {
    late FilamentEngine engine;
    late FilamentCameraManipulator manipulator;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      manipulator = FilamentCameraManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 800,
        viewportHeight: 600,
      );
    });

    tearDown(() {
      if (!manipulator.isDisposed) manipulator.dispose();
      if (!engine.isDisposed) engine.dispose();
    });

    double length(List<double> v) {
      return math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    }

    double distance(List<double> a, List<double> b) {
      final dx = a[0] - b[0];
      final dy = a[1] - b[1];
      final dz = a[2] - b[2];
      return math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    test('getRay at center aligns with getLookAt (center - eye)', () {
      final lookAt = manipulator.getLookAt();
      final (origin, direction) = manipulator.getRay(400, 300);

      expect(distance(origin, lookAt.eye), lessThan(1e-4));

      final dEye = [
        lookAt.center[0] - lookAt.eye[0],
        lookAt.center[1] - lookAt.eye[1],
        lookAt.center[2] - lookAt.eye[2],
      ];
      final len = length(dEye);
      final expectedDir = [dEye[0] / len, dEye[1] / len, dEye[2] / len];

      expect(distance(direction, expectedDir), lessThan(1e-3));
    });

    test('getRay direction must be unit length for center and corners', () {
      final points = [
        [400, 300],
        [0, 0],
        [799, 0],
        [0, 599],
        [799, 599],
      ];

      for (final p in points) {
        final (_, direction) = manipulator.getRay(p[0], p[1]);
        expect(length(direction), closeTo(1.0, 1e-4), reason: 'At point \$p');
      }
    });

    test('raycast at center returns a hit point on the ray', () {
      final hit = manipulator.raycast(400, 300);
      expect(hit, isNotNull);

      final (origin, direction) = manipulator.getRay(400, 300);
      final dHit = [
        hit![0] - origin[0],
        hit[1] - origin[1],
        hit[2] - origin[2],
      ];
      
      final len = length(dHit);
      expect(len, greaterThan(0)); 
      
      final hitDir = [dHit[0] / len, dHit[1] / len, dHit[2] / len];
      expect(distance(hitDir, direction), lessThan(1e-3));
    });

    test('Bottom-left origin check', () {
      final (_, dirBottom) = manipulator.getRay(400, 0);
      final (_, dirTop) = manipulator.getRay(400, 599);
      expect(dirBottom[1], lessThan(dirTop[1]));
    });

    test('raycastFlutter mirrors raycast by flipping y axis', () {
      final hitNative = manipulator.raycast(400, 600 - 100);
      final hitFlutter = manipulator.raycastFlutter(400.0, 100.0, 600.0);
      
      expect(hitNative, isNotNull);
      expect(hitFlutter, isNotNull);
      expect(distance(hitNative!, hitFlutter!), lessThan(1e-5));
    });
  });
}
