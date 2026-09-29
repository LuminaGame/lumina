import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('Box and Aabb Tests', () {
    test('Box.set and min/max getters round-trip', () {
      final box = Box();
      box.set(Vector3(-1, -2, -3), Vector3(3, 2, 1));

      expect(box.center.x, closeTo(1.0, 1e-6));
      expect(box.center.y, closeTo(0.0, 1e-6));
      expect(box.center.z, closeTo(-1.0, 1e-6));

      expect(box.halfExtent.x, closeTo(2.0, 1e-6));
      expect(box.halfExtent.y, closeTo(2.0, 1e-6));
      expect(box.halfExtent.z, closeTo(2.0, 1e-6));

      final min = box.min;
      final max = box.max;
      expect(min.x, closeTo(-1.0, 1e-6));
      expect(min.y, closeTo(-2.0, 1e-6));
      expect(min.z, closeTo(-3.0, 1e-6));
      expect(max.x, closeTo(3.0, 1e-6));
      expect(max.y, closeTo(2.0, 1e-6));
      expect(max.z, closeTo(1.0, 1e-6));
    });

    test('unionSelf combines bounding boxes correctly', () {
      // Unit box at origin: center=(0,0,0), halfExtent=(1,1,1) -> min=(-1,-1,-1), max=(1,1,1)
      final box1 = Box(center: Vector3.zero(), halfExtent: Vector3.all(1));
      // Unit box at (10,0,0): center=(10,0,0), halfExtent=(1,1,1) -> min=(9,-1,-1), max=(11,1,1)
      final box2 = Box(center: Vector3(10, 0, 0), halfExtent: Vector3.all(1));

      box1.unionSelf(box2);
      expect(box1.min.x, closeTo(-1.0, 1e-6));
      expect(box1.min.y, closeTo(-1.0, 1e-6));
      expect(box1.min.z, closeTo(-1.0, 1e-6));
      expect(box1.max.x, closeTo(11.0, 1e-6));
      expect(box1.max.y, closeTo(1.0, 1e-6));
      expect(box1.max.z, closeTo(1.0, 1e-6));
    });

    test('getBoundingSphere returns center and radius', () {
      final box = Box(center: Vector3(5, 6, 7), halfExtent: Vector3(1, 1, 1));
      final sphere = box.getBoundingSphere();

      expect(sphere.x, equals(5.0));
      expect(sphere.y, equals(6.0));
      expect(sphere.z, equals(7.0));
      expect(sphere.w, closeTo(math.sqrt(3.0), 1e-6));
    });

    test('Aabb.getCorners returns 8 corners in exact Filament order', () {
      final aabb = Aabb(min: Vector3(-1, -2, -3), max: Vector3(4, 5, 6));
      final corners = aabb.getCorners();

      expect(corners.length, equals(8));
      expect(corners[0], equals(Vector3(-1, -2, -3))); // min.x, min.y, min.z
      expect(corners[1], equals(Vector3(4, -2, -3)));  // max.x, min.y, min.z
      expect(corners[2], equals(Vector3(-1, 5, -3)));  // min.x, max.y, min.z
      expect(corners[3], equals(Vector3(4, 5, -3)));   // max.x, max.y, min.z
      expect(corners[4], equals(Vector3(-1, -2, 6)));  // min.x, min.y, max.z
      expect(corners[5], equals(Vector3(4, -2, 6)));   // max.x, min.y, max.z
      expect(corners[6], equals(Vector3(-1, 5, 6)));   // min.x, max.y, max.z
      expect(corners[7], equals(Vector3(4, 5, 6)));    // max.x, max.y, max.z
    });

    test('Aabb.contains signed distance semantics per Box.h', () {
      // Unit AABB: [-1, 1]^3
      final aabb = Aabb(min: Vector3(-1, -1, -1), max: Vector3(1, 1, 1));

      // Center is inside: distance to nearest face is -1.0
      expect(aabb.contains(Vector3.zero()), closeTo(-1.0, 1e-6));

      // Point 0.5 outside +X: (1.5, 0, 0) -> distance = +0.5
      expect(aabb.contains(Vector3(1.5, 0, 0)), closeTo(0.5, 1e-6));

      // Point on face: (1.0, 0.5, 0.5) -> distance = 0.0
      expect(aabb.contains(Vector3(1.0, 0.5, 0.5)), closeTo(0.0, 1e-6));
    });

    test('Arvo transform: 45 degree rotation around Z and translation', () {
      // Unit cube [-1, 1]^3
      final aabb = Aabb(min: Vector3(-1, -1, -1), max: Vector3(1, 1, 1));

      // 45 degrees rotation around Z
      final rotZ = Matrix3.rotationZ(math.pi / 4);
      final t = Vector3(10, 20, 30);

      final transformed = aabb.transform(rotZ, t);

      final sqrt2 = math.sqrt(2.0);
      expect(transformed.min.x, closeTo(10.0 - sqrt2, 1e-6));
      expect(transformed.max.x, closeTo(10.0 + sqrt2, 1e-6));
      expect(transformed.min.y, closeTo(20.0 - sqrt2, 1e-6));
      expect(transformed.max.y, closeTo(20.0 + sqrt2, 1e-6));
      expect(transformed.min.z, closeTo(29.0, 1e-6));
      expect(transformed.max.z, closeTo(31.0, 1e-6));
    });

    test('Cross-check: transformMat4 equals transform(upperLeft, translation)', () {
      final aabb = Aabb(min: Vector3(-2, -3, -4), max: Vector3(5, 6, 7));

      final m = Matrix4.compose(
        Vector3(10, -5, 8),
        Quaternion.axisAngle(Vector3(1, 2, 3).normalized(), 0.75),
        Vector3(2, 3, 4),
      );

      final t1 = aabb.transformMat4(m);
      final upperLeft = Matrix3.zero();
      for (int c = 0; c < 3; c++) {
        for (int r = 0; r < 3; r++) {
          upperLeft.setEntry(r, c, m.entry(r, c));
        }
      }
      final translation = Vector3(m.entry(0, 3), m.entry(1, 3), m.entry(2, 3));
      final t2 = aabb.transform(upperLeft, translation);

      expect(t1.min.x, closeTo(t2.min.x, 1e-6));
      expect(t1.min.y, closeTo(t2.min.y, 1e-6));
      expect(t1.min.z, closeTo(t2.min.z, 1e-6));
      expect(t1.max.x, closeTo(t2.max.x, 1e-6));
      expect(t1.max.y, closeTo(t2.max.y, 1e-6));
      expect(t1.max.z, closeTo(t2.max.z, 1e-6));
    });

    test('Degenerate: empty Aabb stays empty, point Box has zero halfExtent', () {
      final emptyAabb = Aabb();
      expect(emptyAabb.isEmpty, isTrue);

      final transformedEmpty = emptyAabb.transformMat4(Matrix4.identity());
      expect(transformedEmpty.isEmpty, isTrue);

      final pointBox = Box(center: Vector3(1, 2, 3), halfExtent: Vector3.zero());
      expect(pointBox.isEmpty, isTrue);
      final pointSphere = pointBox.getBoundingSphere();
      expect(pointSphere.w, equals(0.0));
      expect(pointSphere.xyz, equals(Vector3(1, 2, 3)));
    });
  });
}
