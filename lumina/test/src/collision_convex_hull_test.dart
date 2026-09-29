// ConvexHullShape — the hull itself, its support
// mapping through GJK/EPA, ray casts, sweeps and the convex collision
// component.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The 8 corners of a box with half extents [h] (centred on the origin).
List<Vector3> _corners(Vector3 h) => [
      for (var i = 0; i < 8; i++)
        Vector3(i & 1 == 0 ? -h.x : h.x, i & 2 == 0 ? -h.y : h.y, i & 4 == 0 ? -h.z : h.z),
    ];

void _expectVec(Vector3 actual, Vector3 expected, {double tol = 1e-6, String? reason}) {
  expect(actual.x, closeTo(expected.x, tol), reason: reason);
  expect(actual.y, closeTo(expected.y, tol), reason: reason);
  expect(actual.z, closeTo(expected.z, tol), reason: reason);
}

void main() {
  group('ConvexHullShape', () {
    test('keeps the 8 corners of a box and drops its centre and interior points', () {
      final rng = math.Random(7);
      final points = [
        ..._corners(Vector3(1, 2, 3)),
        Vector3.zero(),
        for (var i = 0; i < 20; i++)
          Vector3((rng.nextDouble() * 2 - 1) * 0.9, (rng.nextDouble() * 2 - 1) * 1.9, (rng.nextDouble() * 2 - 1) * 2.9),
      ]..shuffle(rng);
      final hull = ConvexHullShape(points);
      expect(hull.isDegenerate, isFalse);
      expect(hull.vertices, hasLength(8));
      expect(hull.triangles.length, 12 * 3);
      expect(hull.planes, hasLength(6), reason: 'coplanar triangles share one face plane');
      _expectVec(hull.localMin, Vector3(-1, -2, -3));
      _expectVec(hull.localMax, Vector3(1, 2, 3));
      // Every face plane faces outwards: all vertices are on or behind it.
      for (final plane in hull.planes) {
        for (final v in hull.vertices) {
          expect(plane.normal.dot(v) - plane.offset, lessThanOrEqualTo(1e-9));
        }
      }
    });

    test('welds points closer than 1e-4 (Assimp splits hull vertices by normal)', () {
      final points = [
        ..._corners(Vector3.all(1)),
        for (final c in _corners(Vector3.all(1))) c + Vector3(0.00001, 0, 0),
      ];
      expect(ConvexHullShape(points).vertices, hasLength(8));
    });

    // Timed against a linear pass over the same points in the same
    // process, not the wall clock, so a loaded machine (the full suite runs
    // files in parallel) slows both alike. The hull costs ~12 such passes (the
    // limit is 30); it used to cost 40–70 (3 s alone, 6–9 s in a full run).
    test('hulls a whole mesh\'s vertex buffer (100k points) in near-linear time', () {
      final rng = math.Random(5);
      final points = [
        for (var i = 0; i < 100000; i++)
          (Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1)..normalize())
            ..scale(40 + rng.nextDouble() * 10),
      ];
      // One linear pass: the support point in 256 directions (what a
      // collision query does per hull), over all 100k points.
      final directions = [
        for (var k = 0; k < 256; k++) Vector3(math.cos(k * 0.7), math.sin(k * 1.3), math.cos(k * 2.1))..normalize(),
      ];
      var sink = 0.0;
      int linearPassMicros() {
        final watch = Stopwatch()..start();
        for (final d in directions) {
          var best = -double.infinity;
          for (final p in points) {
            final v = p.dot(d);
            if (v > best) best = v;
          }
          sink += best;
        }
        return watch.elapsedMicroseconds;
      }

      // Warm up the JIT on both.
      ConvexHullShape(points.sublist(0, 2000));
      linearPassMicros();
      late ConvexHullShape hull;
      final ratios = <double>[];
      for (var round = 0; round < 2; round++) {
        final before = linearPassMicros();
        final watch = Stopwatch()..start();
        hull = ConvexHullShape(points);
        final hullMicros = watch.elapsedMicroseconds;
        final after = linearPassMicros();
        ratios.add(hullMicros / ((before + after) / 2));
      }
      expect(sink, isNot(0.0));
      final best = ratios.reduce(math.min);
      expect(best, lessThan(30.0),
          reason: 'the 100k-point hull cost ${ratios.map((r) => r.toStringAsFixed(1)).join(' / ')} linear passes');
      for (final p in points.take(2000)) {
        for (final plane in hull.planes) {
          expect(plane.normal.dot(p) - plane.offset, lessThan(1e-3));
        }
      }
    });

    test('coplanar points are degenerate and collide as their bounding box', () {
      final hull = ConvexHullShape([Vector3(-50, 0, -50), Vector3(50, 0, -50), Vector3(50, 0, 50), Vector3(-50, 0, 50)]);
      expect(hull.isDegenerate, isTrue);
      _expectVec(hull.localMin, Vector3(-50, 0, -50));
      _expectVec(hull.localMax, Vector3(50, 0, 50));
    });

    test('support is the farthest hull vertex, exact under rotation and non-uniform scale', () {
      final box = BoxShape(Vector3(1, 2, 3));
      final hull = ConvexHullShape(_corners(box.halfExtents));
      final t = Matrix4.compose(Vector3(10, 0, 0), Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2), Vector3(2, 1, 1));
      final rng = math.Random(3);
      for (var i = 0; i < 50; i++) {
        final dir = Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1);
        final a = support(hull, t, dir, Vector3.zero());
        final b = support(box, t, dir, Vector3.zero());
        expect(a.dot(dir), closeTo(b.dot(dir), 1e-9), reason: 'direction $dir');
      }
      final px = support(hull, t, Vector3(1, 0, 0), Vector3.zero());
      expect(px.x, closeTo(13.0, 1e-9), reason: 'local z (3) lands on world x after 90° about Y');
    });
  });

  group('narrow phase', () {
    final cube = ConvexHullShape(_corners(Vector3.all(1)));

    test('hull vs box through GJK/EPA: depth and normal', () {
      final contact = ContactResult();
      expect(testPair(cube, Matrix4.identity(), BoxShape(Vector3.all(1)), Matrix4.translation(Vector3(1.5, 0, 0)), contact), isTrue);
      expect(contact.penetrationDepth, closeTo(0.5, 1e-2));
      expect(contact.normal.x, lessThan(-0.99), reason: 'from the box (B) towards the hull (A)');
      expect(testPair(cube, Matrix4.identity(), BoxShape(Vector3.all(1)), Matrix4.translation(Vector3(2.5, 0, 0)), contact), isFalse);
    });

    test('hull pairs: moving out along the normal by the depth separates, 90 % of it does not (seeded poses)', () {
      final rng = math.Random(11);
      // An irregular 40-point hull, and a box-like one whose support has ties.
      final blob = ConvexHullShape([
        for (var i = 0; i < 40; i++)
          (Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1)..normalize())
            ..multiply(Vector3(60, 45, 35)),
      ]);
      final crate = ConvexHullShape(_corners(Vector3(50, 40, 30)));
      final others = <String, CollisionShape>{
        'blob': blob,
        'crate': crate,
        'caps': const CapsuleShape(35, 90),
        'box': BoxShape(Vector3(60, 40, 50)),
        'cyl': const CylinderShape(40, 120),
      };
      Quaternion randomRotation() =>
          Quaternion.axisAngle(Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble())..normalize(), rng.nextDouble() * 3);
      final failures = <String>[];
      var overlapping = 0;
      for (final a in const ['blob', 'crate']) {
        for (final b in others.keys) {
          for (var i = 0; i < 200; i++) {
            final axisAligned = i.isEven;
            final tA = Matrix4.compose(Vector3.zero(), axisAligned ? Quaternion.identity() : randomRotation(), Vector3.all(1));
            final offset = Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1)
              ..scale(rng.nextDouble() * 110);
            if (axisAligned) offset.setValues(offset.x.roundToDouble(), 0, 0); // face contacts with support ties
            final tB = Matrix4.compose(offset, axisAligned ? Quaternion.identity() : randomRotation(), Vector3.all(1));
            final c = ContactResult();
            if (!testPair(others[a]!, tA, others[b]!, tB, c)) continue;
            overlapping++;
            Matrix4 movedBy(double d) => tA.clone()..setTranslation(tA.getTranslation() + c.normal * d);
            final scratch = ContactResult();
            final separates = !testPair(others[a]!, movedBy(c.penetrationDepth + 0.5), others[b]!, tB, scratch);
            final minimal =
                c.penetrationDepth <= 2 || testPair(others[a]!, movedBy(c.penetrationDepth * 0.9), others[b]!, tB, scratch);
            if (!separates || !minimal) failures.add('$a vs $b #$i: depth ${c.penetrationDepth}, normal ${c.normal}');
          }
        }
      }
      expect(overlapping, greaterThan(1000));
      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
    });

    test('the template character capsule against a 100 cm hull cube', () {
      final hull = ConvexHullShape(_corners(Vector3.all(50)));
      const capsule = CapsuleShape(35, 90);
      final contact = ContactResult();
      // Capsule surface 10 cm inside the +X face.
      final tCap = Matrix4.translation(Vector3(50 + 35 - 10, 0, 0));
      expect(testPair(capsule, tCap, hull, Matrix4.identity(), contact), isTrue);
      expect(contact.penetrationDepth, closeTo(10, 0.1));
      expect(contact.normal.x, greaterThan(0.99), reason: 'from the hull towards the capsule');
      final apart = Matrix4.translation(Vector3(50 + 35 + 5, 0, 0));
      expect(testPair(capsule, apart, hull, Matrix4.identity(), contact), isFalse);
    });
  });

  group('rayVsConvexHull', () {
    final cube = ConvexHullShape(_corners(Vector3.all(1)));

    test('hits the entering face with its outward normal', () {
      final n = Vector3.zero();
      final t = rayVsConvexHull(Vector3(-10, 0, 0), Vector3(1, 0, 0), cube, Matrix4.identity(), n);
      expect(t, closeTo(9, 1e-9));
      _expectVec(n, Vector3(-1, 0, 0));
    });

    test('follows the hull transform (45° about Y)', () {
      final n = Vector3.zero();
      final rot = Matrix4.compose(Vector3.zero(), Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4), Vector3.all(1));
      final t = rayVsConvexHull(Vector3(-10, 0, 0.2), Vector3(1, 0, 0), cube, rot, n);
      // The rotated square is the diamond |x| + |z| = √2; at z = 0.2 its
      // left edge is at x = 0.2 − √2.
      expect(t, closeTo(10 + 0.2 - math.sqrt2, 1e-9));
      _expectVec(n, Vector3(-math.sqrt1_2, 0, math.sqrt1_2));
    });

    test('misses when pointing away, and is 0 from inside', () {
      final n = Vector3.zero();
      expect(rayVsConvexHull(Vector3(-10, 0, 0), Vector3(-1, 0, 0), cube, Matrix4.identity(), n), isNull);
      expect(rayVsConvexHull(Vector3(-10, 5, 0), Vector3(1, 0, 0), cube, Matrix4.identity(), n), isNull);
      expect(rayVsConvexHull(Vector3(0.2, 0, 0), Vector3(1, 0, 0), cube, Matrix4.identity(), n), 0.0);
    });

    test('a degenerate (flat) hull is hit from above', () {
      final flat = ConvexHullShape([Vector3(-50, 0, -50), Vector3(50, 0, -50), Vector3(50, 0, 50), Vector3(-50, 0, 50)]);
      final n = Vector3.zero();
      expect(rayVsConvexHull(Vector3(0, 100, 0), Vector3(0, -1, 0), flat, Matrix4.identity(), n), closeTo(100, 1e-9));
      _expectVec(n, Vector3(0, 1, 0));
    });
  });

  group('LuminaCollisionComponent.convexHull', () {
    LuminaCollisionComponent cubeComponent({Vector3? location, Vector3? scale}) => LuminaCollisionComponent.convexHull(
          points: _corners(Vector3.all(50)),
          location: location,
          scale: scale,
        );

    test('is a convex shape with a transform-correct AABB and one cached shape', () {
      final c = cubeComponent(location: Vector3(100, 0, 0), scale: Vector3.all(2));
      expect(c.shapeType, CollisionShapeType.convex);
      expect(c.worldShape, isA<ConvexHullShape>());
      expect(identical(c.worldShape, c.worldShape), isTrue, reason: 'never rebuilt per query');
      _expectVec(c.getAABB().min, Vector3(0, -100, -100));
      _expectVec(c.getAABB().max, Vector3(200, 100, 100));
      c.location = Vector3(0, 0, 0);
      _expectVec(c.getAABB().min, Vector3(-100, -100, -100), reason: 'the cached AABB follows the transform');
      final obb = c.getOBB();
      _expectVec(obb.halfExtents, Vector3.all(100));
    });

    test('the subsystem ray-casts, sweeps and overlaps it', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final sys = world.registerSubsystem(LuminaCollisionSubsystem());
      final hull = cubeComponent(location: Vector3(100, 0, 0), scale: Vector3.all(2));
      CollisionProfile.applyBlockAll(hull);
      hull.objectType = CollisionObjectType.worldStatic;
      world.persistentLevel.registerActor(LuminaActor()..addComponent(hull));
      world.beginPlay();

      final hit = HitResult();
      expect(sys.raycast(Vector3(-500, 0, 0), Vector3(1, 0, 0), 10000, hit), isTrue);
      expect(hit.component, hull);
      expect(hit.time, closeTo(500, 1e-6), reason: 'the raycast time is a distance');
      _expectVec(hit.impactNormal, Vector3(-1, 0, 0));

      final trace = HitResult();
      expect(sys.lineTraceSingle(start: Vector3(100, 500, 0), end: Vector3(100, -500, 0), out: trace), isTrue);
      expect(trace.time, closeTo(0.4, 1e-6));
      _expectVec(trace.impactNormal, Vector3(0, 1, 0));

      // The capsule's +X side reaches the hull's −X face (x = 0) after 260 cm.
      final sweep = HitResult();
      expect(
        sys.sweep(const CapsuleShape(40, 90), Matrix4.translation(Vector3(-300, 0, 0)), Vector3(400, 0, 0), sweep),
        isTrue,
      );
      expect(sweep.time, closeTo(260 / 400, 1e-2));
      expect(sweep.impactNormal.x, lessThan(-0.99));

      final found = <LuminaCollisionComponent>[];
      expect(sys.overlapTest(const SphereShape(10), Matrix4.translation(Vector3(150, 0, 0)), found), 1);
      expect(found.single, hull);
      world.cleanup();
    });

    test('a flat hull still blocks a capsule sweeping down onto it', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final sys = world.registerSubsystem(LuminaCollisionSubsystem());
      final flat = LuminaCollisionComponent.convexHull(
        points: [Vector3(-50, 0, -50), Vector3(50, 0, -50), Vector3(50, 0, 50), Vector3(-50, 0, 50)],
      );
      CollisionProfile.applyBlockAll(flat);
      world.persistentLevel.registerActor(LuminaActor()..addComponent(flat));
      world.beginPlay();
      final hit = HitResult();
      expect(sys.sweep(const CapsuleShape(40, 90), Matrix4.translation(Vector3(0, 200, 0)), Vector3(0, -300, 0), hit), isTrue);
      expect(hit.time, closeTo(110 / 300, 1e-2));
      world.cleanup();
    });
  });
}
