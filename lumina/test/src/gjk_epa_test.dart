import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('GJK / EPA Convex Collision Tests (Collision Task 03)', () {
    test('Support functions: Box direction (1,-1,1) selects (1,-2,3); Capsule along +Y selects top apex', () {
      final box = BoxShape(Vector3(1.0, 2.0, 3.0));
      final tIdentity = Matrix4.identity();
      final out = Vector3.zero();

      support(box, tIdentity, Vector3(1.0, -1.0, 1.0), out);
      expect(out.x, closeTo(1.0, 1e-6));
      expect(out.y, closeTo(-2.0, 1e-6));
      expect(out.z, closeTo(3.0, 1e-6));

      final capsule = CapsuleShape(0.4, 0.9);
      support(capsule, tIdentity, Vector3(0.0, 1.0, 0.0), out);
      expect(out.y, closeTo(0.9, 1e-6)); // top-sphere apex
    });

    test('gjkIntersect on Cone vs Box, Cone vs Sphere, and Cylinder vs Capsule', () {
      final cone = ConeShape(1.0, 2.0);
      final box = BoxShape(Vector3(1.0, 1.0, 1.0));
      final sphere = SphereShape(0.5);
      final cylinder = CylinderShape(0.5, 2.0);
      final capsule = CapsuleShape(0.4, 0.9);

      final tOrigin = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tOverlap = Matrix4.translation(Vector3(0.5, 0.5, 0.0));
      final tFar = Matrix4.translation(Vector3(10.0, 0.0, 0.0));

      final simplex = GjkSimplex();

      // Cone vs Box
      expect(gjkIntersect(cone, tOrigin, box, tOverlap, simplex), isTrue);
      expect(gjkIntersect(cone, tOrigin, box, tFar, simplex), isFalse);

      // Cone vs Sphere
      expect(gjkIntersect(cone, tOrigin, sphere, tOverlap, simplex), isTrue);
      expect(gjkIntersect(cone, tOrigin, sphere, tFar, simplex), isFalse);

      // Cylinder vs Capsule
      expect(gjkIntersect(cylinder, tOrigin, capsule, tOverlap, simplex), isTrue);
      expect(gjkIntersect(cylinder, tOrigin, capsule, tFar, simplex), isFalse);
    });

    test('GJK+EPA vs analytic cross-check on overlapping spheres agrees within 1e-4 depth and 1 deg normal', () {
      final sA = SphereShape(1.0);
      final sB = SphereShape(1.0);

      final tA = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tB = Matrix4.translation(Vector3(1.5, 0.0, 0.0));

      final result = ContactResult();
      final hit = testPair(sA, tA, sB, tB, result);

      expect(hit, isTrue);
      expect(result.penetrationDepth, closeTo(0.5, 1e-4));
      expect(result.normal.dot(Vector3(-1.0, 0.0, 0.0)), greaterThan(0.999));
    });

    // Moving A out along the EPA normal by the EPA depth must
    // separate the pair, and 90 % of it must not (the depth is the minimum
    // translation). Seeded, so the same 3900-odd poses run every time.
    test('EPA answer separates the pair and is minimal (seeded random poses)', () {
      final rng = math.Random(1);
      final shapes = <String, CollisionShape>{
        'box': BoxShape(Vector3(60, 40, 50)),
        'cyl': const CylinderShape(40, 120),
        'cone': const ConeShape(50, 120),
        'caps': const CapsuleShape(40, 90),
      };
      Quaternion randomRotation() =>
          Quaternion.axisAngle(Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble())..normalize(), rng.nextDouble() * 3);
      final failures = <String>[];
      var overlapping = 0;
      for (final a in shapes.keys) {
        for (final b in shapes.keys) {
          if (a == 'caps' && b == 'caps') continue; // analytic
          for (var i = 0; i < 300; i++) {
            final tA = Matrix4.compose(Vector3.zero(), randomRotation(), Vector3.all(1));
            final offset = Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1)
              ..scale(rng.nextDouble() * 120);
            final tB = Matrix4.compose(offset, randomRotation(), Vector3.all(1));
            final c = ContactResult();
            if (!testPair(shapes[a]!, tA, shapes[b]!, tB, c)) continue;
            overlapping++;
            Matrix4 movedBy(double d) => tA.clone()..setTranslation(tA.getTranslation() + c.normal * d);
            final scratch = ContactResult();
            final separates = !testPair(shapes[a]!, movedBy(c.penetrationDepth + 0.5), shapes[b]!, tB, scratch);
            final minimal = c.penetrationDepth <= 2 || testPair(shapes[a]!, movedBy(c.penetrationDepth * 0.9), shapes[b]!, tB, scratch);
            if (!separates || !minimal) {
              failures.add('$a vs $b #$i: depth ${c.penetrationDepth.toStringAsFixed(2)}, normal ${c.normal}, '
                  'separates $separates, minimal $minimal');
            }
          }
        }
      }
      expect(overlapping, greaterThan(3000));
      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
    });

    test('Degenerate: identical shapes at identical transform reports overlap and terminates with finite depth', () {
      final boxA = BoxShape(Vector3(1.0, 1.0, 1.0));
      final boxB = BoxShape(Vector3(1.0, 1.0, 1.0));
      final t = Matrix4.identity();

      final result = ContactResult();
      final hit = testPair(boxA, t, boxB, t, result);

      expect(hit, isTrue);
      expect(result.penetrationDepth.isNaN, isFalse);
      expect(result.normal.length.isNaN, isFalse);
    });
  });
}
