import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('CollisionShapes and CapsuleComponent Tests (Collision Task 01)', () {
    test('Capsule radius 0.4, halfHeight 0.9 at origin produces segment points [(0, -0.5, 0), (0, 0.5, 0)]', () {
      final capsule = LuminaCapsuleComponent(
        radius: 0.4,
        halfHeight: 0.9,
      );

      final pts = capsule.getSegmentPoints();
      expect(pts.length, equals(2));
      expect(pts[0].x, closeTo(0.0, 1e-9));
      expect(pts[0].y, closeTo(-0.5, 1e-9));
      expect(pts[0].z, closeTo(0.0, 1e-9));

      expect(pts[1].x, closeTo(0.0, 1e-9));
      expect(pts[1].y, closeTo(0.5, 1e-9));
      expect(pts[1].z, closeTo(0.0, 1e-9));
    });

    test('Same capsule rotated 90 deg around Z places segment on X axis [(0.5, 0, 0), (-0.5, 0, 0)]', () {
      final capsule = LuminaCapsuleComponent(
        radius: 0.4,
        halfHeight: 0.9,
        rotation: Quaternion.axisAngle(Vector3(0.0, 0.0, 1.0), 90.0 * 3.141592653589793 / 180.0),
      );

      // +90° about +Z turns the capsule's drawn +Y (its top) to −X.
      final pts = capsule.getSegmentPoints();
      expect(pts[0].x, closeTo(0.5, 1e-9));
      expect(pts[0].y, closeTo(0.0, 1e-9));
      expect(pts[0].z, closeTo(0.0, 1e-9));

      expect(pts[1].x, closeTo(-0.5, 1e-9));
      expect(pts[1].y, closeTo(0.0, 1e-9));
      expect(pts[1].z, closeTo(0.0, 1e-9));
    });

    test('Capsule attached to parent updates segmentStart/segmentEnd on parent move', () {
      final parent = LuminaSceneComponent(location: Vector3(10.0, 0.0, 0.0));
      final capsule = LuminaCapsuleComponent(
        radius: 0.4,
        halfHeight: 0.9,
      );
      capsule.attachToComponent(parent);

      expect(capsule.segmentStart.x, closeTo(10.0, 1e-9));
      expect(capsule.segmentStart.y, closeTo(-0.5, 1e-9));

      parent.relativeLocation = Vector3(20.0, 5.0, 0.0);

      expect(capsule.segmentStart.x, closeTo(20.0, 1e-9));
      expect(capsule.segmentStart.y, closeTo(4.5, 1e-9));
      expect(capsule.segmentEnd.x, closeTo(20.0, 1e-9));
      expect(capsule.segmentEnd.y, closeTo(5.5, 1e-9));
    });

    test('getAABB for upright capsule at (1, 2, 3) produces correct min/max bounds', () {
      final capsule = LuminaCapsuleComponent(
        location: Vector3(1.0, 2.0, 3.0),
        radius: 0.4,
        halfHeight: 0.9,
      );

      final aabb = capsule.getAABB();
      expect(aabb.min.x, closeTo(0.6, 1e-6));
      expect(aabb.min.y, closeTo(1.1, 1e-6));
      expect(aabb.min.z, closeTo(2.6, 1e-6));

      expect(aabb.max.x, closeTo(1.4, 1e-6));
      expect(aabb.max.y, closeTo(2.9, 1e-6));
      expect(aabb.max.z, closeTo(3.4, 1e-6));
    });

    test('getAABB for cylinder (radius 0.5, height 2) rotated 90 deg around X has correct extents', () {
      final cylinder = LuminaCollisionComponent(
        shapeType: CollisionShapeType.cylinder,
        radius: 0.5,
        rotation: Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), 90.0 * 3.141592653589793 / 180.0),
      );
      cylinder.height = 2.0;

      final aabb = cylinder.getAABB();
      // Y extent shrinks to +-0.5, Z extent grows to +-1.0
      expect(aabb.min.x, closeTo(-0.5, 1e-6));
      expect(aabb.max.x, closeTo(0.5, 1e-6));

      expect(aabb.min.y, closeTo(-0.5, 1e-6));
      expect(aabb.max.y, closeTo(0.5, 1e-6));

      expect(aabb.min.z, closeTo(-1.0, 1e-6));
      expect(aabb.max.z, closeTo(1.0, 1e-6));
    });

    test('getAABB for cone (radius 1, height 2) upright and apex/axis getters match rotation', () {
      final cone = LuminaCollisionComponent(
        shapeType: CollisionShapeType.cone,
        radius: 1.0,
      );
      cone.height = 2.0;

      expect(cone.axis.x, closeTo(0.0, 1e-6));
      expect(cone.axis.y, closeTo(1.0, 1e-6));
      expect(cone.axis.z, closeTo(0.0, 1e-6));

      expect(cone.apex.x, closeTo(0.0, 1e-6));
      expect(cone.apex.y, closeTo(1.0, 1e-6));
      expect(cone.apex.z, closeTo(0.0, 1e-6));

      final aabb = cone.getAABB();
      expect(aabb.min.x, closeTo(-1.0, 1e-6));
      expect(aabb.max.x, closeTo(1.0, 1e-6));
      expect(aabb.min.y, closeTo(-1.0, 1e-6));
      expect(aabb.max.y, closeTo(1.0, 1e-6));
      expect(aabb.min.z, closeTo(-1.0, 1e-6));
      expect(aabb.max.z, closeTo(1.0, 1e-6));
    });

    test('Box extent (1, 2, 3) rotated 90 deg around Y has AABB half-sizes (3, 2, 1)', () {
      final box = LuminaCollisionComponent(
        shapeType: CollisionShapeType.box,
        rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 90.0 * 3.141592653589793 / 180.0),
      );
      box.boxExtent = Vector3(1.0, 2.0, 3.0);

      final aabb = box.getAABB();
      expect(aabb.min.x, closeTo(-3.0, 1e-6));
      expect(aabb.max.x, closeTo(3.0, 1e-6));

      expect(aabb.min.y, closeTo(-2.0, 1e-6));
      expect(aabb.max.y, closeTo(2.0, 1e-6));

      expect(aabb.min.z, closeTo(-1.0, 1e-6));
      expect(aabb.max.z, closeTo(1.0, 1e-6));
    });

    test('getOBB for identity rotation returns OBB matching AABB bounds', () {
      final box = LuminaCollisionComponent(
        shapeType: CollisionShapeType.box,
        location: Vector3(2.0, 3.0, 4.0),
      );
      box.boxExtent = Vector3(1.0, 1.0, 1.0);

      final obb = box.getOBB();
      final aabb = box.getAABB();

      expect(obb.center, equals(aabb.center));
      expect(obb.halfExtents, equals(box.boxExtent));
    });

    test('buildCapsuleWireframe produces non-empty line list with vertices within radius of segment', () {
      final capsule = LuminaCapsuleComponent(
        radius: 0.4,
        halfHeight: 0.9,
      );

      final wireframe = capsule.buildCapsuleWireframe(segments: 16);
      expect(wireframe.isNotEmpty, isTrue);
      expect(wireframe.length % 2, equals(0)); // Even number of vertices for line list

      final seg = capsule.getSegmentPoints();
      final a = seg[0];
      final b = seg[1];

      for (final v in wireframe) {
        // Distance from point v to segment [a, b]
        final ab = b - a;
        final av = v - a;
        final t = (av.dot(ab) / ab.length2).clamp(0.0, 1.0);
        final proj = a + (ab * t);
        final dist = (v - proj).length;
        expect(dist, lessThanOrEqualTo(0.4 + 1e-6));
      }
    });

    test('Setting capsuleHalfHeight = 0.1 with radius = 0.4 yields zero-length segment without negative distance', () {
      final capsule = LuminaCapsuleComponent(
        radius: 0.4,
        halfHeight: 0.1,
      );

      final pts = capsule.getSegmentPoints();
      expect(pts[0], equals(pts[1]));
      expect(pts[0], equals(capsule.worldLocation));
    });
  });
}
