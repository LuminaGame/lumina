import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('NarrowPhase Analytic Tests (Collision Task 03)', () {
    test('Sphere vs Sphere: colliding with depth 0.5 and normal (-1,0,0) from B to A; separated not colliding', () {
      final sA = SphereShape(1.0);
      final sB = SphereShape(1.0);

      final tA = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tB = Matrix4.translation(Vector3(1.5, 0.0, 0.0));

      final result = ContactResult();
      final hit = sphereVsSphere(sA, tA, sB, tB, result);

      expect(hit, isTrue);
      expect(result.isColliding, isTrue);
      expect(result.penetrationDepth, closeTo(0.5, 1e-6));
      expect(result.normal.x, closeTo(-1.0, 1e-6)); // B -> A
      expect(result.normal.y, closeTo(0.0, 1e-6));
      expect(result.normal.z, closeTo(0.0, 1e-6));

      final tFar = Matrix4.translation(Vector3(2.5, 0.0, 0.0));
      final hitFar = sphereVsSphere(sA, tA, sB, tFar, result);
      expect(hitFar, isFalse);
    });

    test('closestPointsBetweenSegments: skew segments produce distance 1.0; parallel and point segments produce finite values', () {
      final p1 = Vector3(0.0, 0.0, 0.0);
      final q1 = Vector3(1.0, 0.0, 0.0);
      final p2 = Vector3(0.5, 1.0, -1.0);
      final q2 = Vector3(0.5, 1.0, 1.0);

      final outA = Vector3.zero();
      final outB = Vector3.zero();

      final dist = closestPointsBetweenSegments(p1, q1, p2, q2, outA, outB);

      expect(dist, closeTo(1.0, 1e-6));
      expect(outA.x, closeTo(0.5, 1e-6));
      expect(outA.y, closeTo(0.0, 1e-6));
      expect(outA.z, closeTo(0.0, 1e-6));

      expect(outB.x, closeTo(0.5, 1e-6));
      expect(outB.y, closeTo(1.0, 1e-6));
      expect(outB.z, closeTo(0.0, 1e-6));

      // Parallel segments
      final distPar = closestPointsBetweenSegments(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 1.0, 0.0),
        Vector3(1.0, 0.0, 0.0),
        Vector3(1.0, 1.0, 0.0),
        outA,
        outB,
      );
      expect(distPar, closeTo(1.0, 1e-6));
      expect(outA.x.isNaN, isFalse);

      // Zero-length (point) segment
      final distPt = closestPointsBetweenSegments(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 0.0, 0.0),
        Vector3(2.0, 0.0, 0.0),
        Vector3(2.0, 1.0, 0.0),
        outA,
        outB,
      );
      expect(distPt, closeTo(2.0, 1e-6));
      expect(outA.x.isNaN, isFalse);
    });

    test('Two vertical capsules (r=0.4, halfHeight=0.9) with axes 0.6 apart -> capsuleVsCapsule colliding depth 0.2', () {
      final capA = CapsuleShape(0.4, 0.9);
      final capB = CapsuleShape(0.4, 0.9);

      final tA = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tB = Matrix4.translation(Vector3(0.6, 0.0, 0.0));

      final result = ContactResult();
      final hit = capsuleVsCapsule(capA, tA, capB, tB, result);

      expect(hit, isTrue);
      expect(result.penetrationDepth, closeTo(0.2, 1e-6));
      expect(result.normal.x, closeTo(-1.0, 1e-6)); // B -> A
      expect(result.normal.y, closeTo(0.0, 1e-6));
    });

    test('Upright capsule with bottom 0.1 below plane y=0 -> capsuleVsPlane depth 0.1, normal (0,1,0)', () {
      final cap = CapsuleShape(0.4, 0.9);
      // Capsule center at y = 0.8 -> bottom is at 0.8 - 0.9 = -0.1 (0.1 below y=0)
      final t = Matrix4.translation(Vector3(0.0, 0.8, 0.0));
      final plane = Plane.components(0.0, 1.0, 0.0, 0.0); // y = 0

      final result = ContactResult();
      final hit = capsuleVsPlane(cap, t, plane, result);

      expect(hit, isTrue);
      expect(result.penetrationDepth, closeTo(0.1, 1e-6));
      expect(result.normal.x, closeTo(0.0, 1e-6));
      expect(result.normal.y, closeTo(1.0, 1e-6));
      expect(result.normal.z, closeTo(0.0, 1e-6));
    });

    test('sphereVsCone: sphere centered 0.3 above apex of cone (r=1, h=2) collides with depth 0.2', () {
      final cone = ConeShape(1.0, 2.0);
      final sphere = SphereShape(0.5);

      final tCone = Matrix4.translation(Vector3(0.0, 0.0, 0.0)); // apex is at y = 1.0
      final tSphere = Matrix4.translation(Vector3(0.0, 1.3, 0.0)); // distance from apex is 0.3 -> depth = 0.5 - 0.3 = 0.2

      final result = ContactResult();
      final hit = sphereVsCone(sphere, tSphere, cone, tCone, result);

      expect(hit, isTrue);
      expect(result.penetrationDepth, closeTo(0.2, 1e-6));

      // Separated
      final tFar = Matrix4.translation(Vector3(5.0, 1.0, 0.0));
      expect(sphereVsCone(sphere, tFar, cone, tCone, result), isFalse);
    });

    test('rayVsCapsule: ray from (-5,0,0) along +X at upright capsule (r=0.4) at origin hits at t = 4.6', () {
      final origin = Vector3(-5.0, 0.0, 0.0);
      final dir = Vector3(1.0, 0.0, 0.0);
      final segStart = Vector3(0.0, -0.5, 0.0);
      final segEnd = Vector3(0.0, 0.5, 0.0);
      final radius = 0.4;

      final t = rayVsCapsule(origin, dir, segStart, segEnd, radius);
      expect(t, isNotNull);
      expect(t!, closeTo(4.6, 1e-6));

      // Ray missing capsule
      final tMiss = rayVsCapsule(Vector3(-5.0, 5.0, 0.0), dir, segStart, segEnd, radius);
      expect(tMiss, isNull);
    });
  });
}
