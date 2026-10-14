import 'dart:math' as math;

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/physics/jolt/jolt_physics_backend.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// The physics backend seam: which engine steps a subsystem, and that the
/// Jolt backend keeps Lumina's units, mass rules, filters and colliders.
void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  group('backend selection', () {
    test('a requested kind wins; auto picks Jolt where its library is built', () {
      expect(
        JoltPhysics.isAvailable,
        isTrue,
        reason: 'build tools/flutter_jolt with tool/build_jolt.bat or tool/build_jolt.sh: '
            '${LuminaPhysicsSubsystem.joltUnavailableReason}',
      );
      expect(LuminaPhysicsSubsystem.joltUnavailableReason, isNull);
      expect(LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.dart).backendKind, LuminaPhysicsBackendKind.dart);
      expect(LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.jolt).backendKind, LuminaPhysicsBackendKind.jolt);
      const forced = String.fromEnvironment('LUMINA_PHYSICS_BACKEND');
      final expected = LuminaPhysicsBackendKind.parse(forced) ?? LuminaPhysicsBackendKind.jolt;
      expect(LuminaPhysicsSubsystem().backendKind, expected == LuminaPhysicsBackendKind.auto ? LuminaPhysicsBackendKind.jolt : expected);
    });

    test('the default kind applies to subsystems created afterwards', () {
      LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.dart;
      final physics = LuminaPhysicsSubsystem();
      expect(physics.backendKind, LuminaPhysicsBackendKind.dart);
      expect(physics.backend, isA<LuminaDartPhysicsBackend>());
      LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt;
      expect(LuminaPhysicsSubsystem().backendKind, LuminaPhysicsBackendKind.jolt);
      expect(physics.backendKind, LuminaPhysicsBackendKind.dart);
    });

    test('parse reads dart, jolt and auto in any case', () {
      expect(LuminaPhysicsBackendKind.parse('JOLT'), LuminaPhysicsBackendKind.jolt);
      expect(LuminaPhysicsBackendKind.parse(' dart '), LuminaPhysicsBackendKind.dart);
      expect(LuminaPhysicsBackendKind.parse('auto'), LuminaPhysicsBackendKind.auto);
      expect(LuminaPhysicsBackendKind.parse('bullet'), isNull);
      expect(LuminaPhysicsBackendKind.parse(null), isNull);
    });
  });

  for (final kind in [LuminaPhysicsBackendKind.dart, LuminaPhysicsBackendKind.jolt]) {
    group('on ${kind.name}', () {
      setUp(() => LuminaPhysicsSubsystem.defaultBackend = kind);

      test('an impulse of 1000 kg·cm/s moves a 10 kg box at 100 cm/s; it travels 50 cm in 0.5 s', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        expect(w.physics.backendKind, kind);
        final box = w.box(Vector3(0, 500, 0), Vector3.all(25))..enableGravity = false;
        w.begin();
        box.addImpulse(Vector3(1000, 0, 0));
        final start = box.worldLocation.x;
        w.run(0.5);
        expect(box.physicsBody!.linearVelocity.x, closeTo(100, 1.0));
        expect(box.worldLocation.x - start, closeTo(50, 2.0));
      });

      test('the body keeps the Dart mass, centre of mass and inertia', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        final box = w.box(Vector3(0, 500, 0), Vector3(50, 10, 20), massKg: 12);
        box.centerOfMassOffset = Vector3(10, 0, 0);
        w.begin();
        final body = box.physicsBody!;
        expect(body.mass, 12);
        expect(body.localCenterOfMass.x, closeTo(10, 1e-9));
        final backend = w.physics.backend;
        if (backend is LuminaJoltPhysicsBackend) {
          expect(backend.joltWorld.bodyMass(backend.joltBodyId(body)!), closeTo(12, 1e-4));
        }
        // Falls straight: an off-centre centre of mass does not make a free
        // body spin.
        w.run(0.3);
        expect(body.angularVelocity.length, lessThan(1e-3));
      });

      test('a box whose collision ignores worldStatic falls through the floor', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        final ghost = w.box(Vector3(0, 30, 0), Vector3.all(25))..setResponse(CollisionObjectType.worldStatic, CollisionResponse.ignore);
        final solid = w.box(Vector3(200, 30, 0), Vector3.all(25));
        w.begin();
        w.run(1.5);
        expect(ghost.worldLocation.y, lessThan(-200));
        expect(solid.worldLocation.y, closeTo(25, 0.5));
      });

      test('an overlap-only trigger box never blocks a falling body', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        final trigger = LuminaBoxComponent(location: Vector3(0, 100, 0), boxExtent: Vector3(200, 20, 200))
          ..setResponseToAll(CollisionResponse.overlap);
        w.world.persistentLevel.registerActor(LuminaActor(root: trigger));
        final ball = w.sphere(Vector3(0, 300, 0), 20);
        w.begin();
        w.run(2);
        expect(ball.worldLocation.y, closeTo(20, 1.0), reason: 'fell through the trigger onto the floor');
      });

      test('every shape keeps its Dart mass; a mirrored convex hull rests on its face', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        final hull = LuminaConvexComponent(location: Vector3(600, 60, 0), scale: Vector3(-1.5, 1, 1), points: [
          for (var i = 0; i < 12; i++) Vector3(30 * math.cos(i * math.pi / 3), i < 6 ? -20 : 20, 30 * math.sin(i * math.pi / 3)),
        ]);
        final shapes = <LuminaCollisionComponent>[
          LuminaBoxComponent(location: Vector3(-400, 60, 0), boxExtent: Vector3(20, 10, 30)),
          LuminaSphereComponent(location: Vector3(-200, 60, 0), radius: 15),
          LuminaCapsuleComponent(location: Vector3(0, 80, 0), radius: 10, halfHeight: 40),
          LuminaCylinderComponent(location: Vector3(200, 80, 0), radius: 20, halfHeight: 30),
          LuminaConeComponent(location: Vector3(400, 80, 0), radius: 25, halfHeight: 30),
          hull,
        ];
        for (final c in shapes) {
          c.simulatePhysics = true;
          w.world.persistentLevel.registerActor(LuminaActor(root: c));
        }
        w.begin();
        w.run(3);
        final backend = w.physics.backend;
        for (final c in shapes) {
          final body = c.physicsBody!;
          expect(body.mass, greaterThan(0));
          if (backend is LuminaJoltPhysicsBackend) {
            expect(backend.joltWorld.bodyMass(backend.joltBodyId(body)!), closeTo(body.mass, body.mass * 1e-5),
                reason: '${c.runtimeType}');
          }
        }
        expect(hull.worldLocation.y, closeTo(20, 1.0), reason: 'the scaled, mirrored prism lies on a face');
      });

      test('a moved floor carries what lands on it afterwards', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        final ball = w.sphere(Vector3(0, 200, 0), 20);
        w.begin();
        w.floor.relativeLocation = Vector3(0, 90, 0); // floor top at y = 100
        w.run(2);
        expect(ball.worldLocation.y, closeTo(120, 1.0));
      });

      test('a landscape heightfield carries a sphere and a box at the sampled height', () {
        final w = PhysicsWorld();
        addTearDown(w.dispose);
        w.floor.relativeLocation = Vector3(0, -5000, 0);
        // 17 x 17 samples over 160 m, a slope of 1 m per 10 m along +X.
        final data = LandscapeData(gridResolution: 17, worldSize: 160, maxHeight: 50);
        for (var row = 0; row < 17; row++) {
          for (var col = 0; col < 17; col++) {
            data.setHeight(col, row, 10 + data.worldXOf(col) * 0.1);
          }
        }
        final land = LuminaCollisionComponent.heightfield(shape: HeightfieldShape(data, unitsPerMetre: 100))
          ..objectType = CollisionObjectType.worldStatic;
        w.world.persistentLevel.registerActor(LuminaActor(root: land));
        final ball = w.sphere(Vector3(0, 1500, 0), 20, massKg: 5);
        final box = w.box(Vector3(2000, 1500, 0), Vector3.all(25));
        ball.linearDamping = 5;
        w.begin();
        w.run(3);
        // At x = 0 the ground is 10 m high; at x = 20 m, 12 m.
        expect(ball.worldLocation.y - 20, closeTo(1000, 3), reason: 'rolls down the slope a little at most');
        final under = 1000 + box.worldLocation.x * 0.1;
        expect(box.worldLocation.y - 25, closeTo(under, 4));
        // Resting on one of its faces: a box axis along the slope's normal.
        final normal = Vector3(-0.1, 1, 0).normalized();
        final faceDown = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
            .map((a) => (a..applyQuaternion(box.worldRotation)).dot(normal).abs())
            .reduce(math.max);
        expect(faceDown, greaterThan(math.cos(0.05)));
      }, skip: kind == LuminaPhysicsBackendKind.dart ? 'the Dart solver keeps only spheres and capsules on a heightfield' : null);
    });
  }
}
