import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' hide Frustum;
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('Frustum Pure Dart Visibility Tests', () {
    late Matrix4 proj;
    late Matrix4 view;
    late Matrix4 projView;
    late Frustum frustum;

    setUp(() {
      // Perspective projection with 90° FOV, aspect 1.0, near 0.1, far 100.0
      // Camera looking down -Z (OpenGL convention)
      proj = makePerspectiveMatrix(math.pi / 2, 1.0, 0.1, 100.0);
      view = Matrix4.identity();
      projView = proj * view;
      frustum = Frustum(projView);
    });

    test('Enum order: left, right, bottom, top, far, near', () {
      expect(FrustumPlane.left.index, equals(0));
      expect(FrustumPlane.right.index, equals(1));
      expect(FrustumPlane.bottom.index, equals(2));
      expect(FrustumPlane.top.index, equals(3));
      expect(FrustumPlane.far.index, equals(4));
      expect(FrustumPlane.near.index, equals(5));
    });

    test('Plane sanity: unit normals and near plane on-point evaluation', () {
      final planes = frustum.getNormalizedPlanes();
      expect(planes.length, equals(6));

      for (int i = 0; i < 6; i++) {
        final p = planes[i];
        final normalLen = math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
        expect(normalLen, closeTo(1.0, 1e-6));
      }

      final nearPlane = frustum.getNormalizedPlane(FrustumPlane.near);
      // Evaluated at near plane point (0, 0, -0.1)
      final nearDist = nearPlane.x * 0 + nearPlane.y * 0 + nearPlane.z * (-0.1) + nearPlane.w;
      expect(nearDist, closeTo(0.0, 1e-5));
    });

    test('Point classification tests', () {
      // Inside frustum
      expect(frustum.contains(Vector3(0, 0, -1)), isTrue);
      expect(frustum.contains(Vector3(0.5, 0.5, -1)), isTrue);
      expect(frustum.contains(Vector3(0.99, 0, -1)), isTrue);
      expect(frustum.contains(Vector3(-0.99, 0, -1)), isTrue);

      // Outside frustum
      expect(frustum.contains(Vector3(0, 0, -0.05)), isFalse); // in front of near
      expect(frustum.contains(Vector3(0, 0, -200)), isFalse);  // beyond far
      expect(frustum.contains(Vector3(0, 0, 1)), isFalse);     // behind camera
      expect(frustum.contains(Vector3(1.5, 0, -1)), isFalse);  // outside 90° FOV cone
      expect(frustum.contains(Vector3(-1.5, 0, -1)), isFalse); // outside 90° FOV cone
    });

    test('Sphere intersection tests', () {
      // Sphere at (0, 0, -10) with r=1 is fully inside
      expect(frustum.intersectsSphere(Vector4(0, 0, -10, 1)), isTrue);

      // Sphere at (0, 0, -102) with r=1 is beyond far (far = 100)
      expect(frustum.intersectsSphere(Vector4(0, 0, -102, 1)), isFalse);

      // Sphere at (0, 0, -100.5) with r=1 straddles far plane
      expect(frustum.intersectsSphere(Vector4(0, 0, -100.5, 1)), isTrue);

      // Sphere centered outside but radius reaching in
      expect(frustum.intersectsSphere(Vector4(2.0, 0, -1, 1.5)), isTrue);
    });

    test('Box intersection tests', () {
      // Unit box at (0, 0, -5) intersects
      final boxInside = Box(center: Vector3(0, 0, -5), halfExtent: Vector3.all(1));
      expect(frustum.intersects(boxInside), isTrue);

      // Unit box at (50, 0, -5) does not intersect
      final boxOutside = Box(center: Vector3(50, 0, -5), halfExtent: Vector3.all(1));
      expect(frustum.intersects(boxOutside), isFalse);

      // Huge box enclosing the whole frustum intersects
      final hugeBox = Box(center: Vector3(0, 0, -50), halfExtent: Vector3.all(200));
      expect(frustum.intersects(hugeBox), isTrue);
    });

    test('Off-center matrix with view = lookAt(eye: (0,0,5), target: origin)', () {
      final lookAtView = makeViewMatrix(Vector3(0, 0, 5), Vector3.zero(), Vector3(0, 1, 0));
      final pv = proj * lookAtView;
      final offCenterFrustum = Frustum(pv);

      // Origin (0,0,0) is in front of camera (eye is at (0,0,5) looking towards origin, dist = 5)
      expect(offCenterFrustum.contains(Vector3.zero()), isTrue);

      // (0,0,6) is behind the eye
      expect(offCenterFrustum.contains(Vector3(0, 0, 6)), isFalse);
    });

    test('Differential golden: 100 random points test self-consistency', () {
      final rand = math.Random(42);
      final planes = frustum.getNormalizedPlanes();

      for (int i = 0; i < 100; i++) {
        final x = (rand.nextDouble() * 2 - 1) * 50;
        final y = (rand.nextDouble() * 2 - 1) * 50;
        final z = -rand.nextDouble() * 150;
        final pt = Vector3(x, y, z);

        bool manualInside = true;
        for (final p in planes) {
          final dist = p.x * pt.x + p.y * pt.y + p.z * pt.z + p.w;
          if (dist > 1e-6) {
            manualInside = false;
            break;
          }
        }

        expect(frustum.contains(pt), equals(manualInside));
      }
    });
  });
}
