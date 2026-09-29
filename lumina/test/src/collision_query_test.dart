import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Collision Query Tests (Collision Task 04)', () {
    test('raycast from (-1000,0,0) along +X returns first blocking hit on sphere; with layerMask excluding sphere returns box', () {
      final subsystem = LuminaCollisionSubsystem();

      final sphere = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 100.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      sphere.setLayer(1);
      CollisionProfile.applyBlockAll(sphere);

      final box = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 100.0, 100.0)
        ..location = Vector3(500.0, 0.0, 0.0);
      box.setLayer(2);
      CollisionProfile.applyBlockAll(box);

      subsystem.register(sphere);
      subsystem.register(box);

      final hit = HitResult();
      final hitFound = subsystem.raycast(
        Vector3(-1000.0, 0.0, 0.0),
        Vector3(1.0, 0.0, 0.0),
        2000.0,
        hit,
      );

      expect(hitFound, isTrue);
      expect(hit.component, equals(sphere));
      expect(hit.time, closeTo(900.0, 1e-4));
      expect(hit.impactPoint.x, closeTo(-100.0, 1e-4));
      expect(hit.impactNormal.x, closeTo(-1.0, 1e-6));

      // Query with layerMask excluding layer 1 (only layer 2)
      final hitLayer2 = HitResult();
      final hitBox = subsystem.raycast(
        Vector3(-1000.0, 0.0, 0.0),
        Vector3(1.0, 0.0, 0.0),
        2000.0,
        hitLayer2,
        layerMask: CollisionLayers.layer(2),
      );

      expect(hitBox, isTrue);
      expect(hitLayer2.component, equals(box));
      expect(hitLayer2.time, closeTo(1400.0, 1e-4)); // -1000 to 400 = 1400
    });

    test('raycast with ignore set to intervening component passes through it', () {
      final subsystem = LuminaCollisionSubsystem();

      final sphere = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 100.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyBlockAll(sphere);

      final box = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 100.0, 100.0)
        ..location = Vector3(500.0, 0.0, 0.0);
      CollisionProfile.applyBlockAll(box);

      subsystem.register(sphere);
      subsystem.register(box);

      final hit = HitResult();
      final hitFound = subsystem.raycast(
        Vector3(-1000.0, 0.0, 0.0),
        Vector3(1.0, 0.0, 0.0),
        2000.0,
        hit,
        ignore: sphere,
      );

      expect(hitFound, isTrue);
      expect(hit.component, equals(box));
    });

    test('sweep of a capsule centered at (0,200,0) by delta (0,-200,0) toward floor box at y=0 hits with time ~0.55', () {
      final subsystem = LuminaCollisionSubsystem();

      final floor = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 100.0, 1000.0) // Top of box is at y = 0 when center is at y = -100
        ..location = Vector3(0.0, -100.0, 0.0);
      CollisionProfile.applyBlockAll(floor);
      subsystem.register(floor);

      final capsule = CapsuleShape(40.0, 90.0);
      final start = Matrix4.translation(Vector3(0.0, 200.0, 0.0));
      final delta = Vector3(0.0, -200.0, 0.0);

      final hit = HitResult();
      final sweepHit = subsystem.sweep(capsule, start, delta, hit);

      expect(sweepHit, isTrue);
      expect(hit.blockingHit, isTrue);
      // Capsule bottom is at y = 200 - 90 = 110. Floor top is at y = 0.0.
      // Travel required is 110 out of delta magnitude 200 -> time = 110 / 200 = 0.55
      expect(hit.time, closeTo(0.55, 0.02));
      expect(hit.impactNormal.y, closeTo(1.0, 1e-6));
    });

    test('overlapTest with a sphere covering 2 of 3 placed components returns count 2', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..location = Vector3(50.0, 0.0, 0.0);
      a.setLayer(1);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..location = Vector3(-50.0, 0.0, 0.0);
      b.setLayer(1);

      final c = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..location = Vector3(1000.0, 0.0, 0.0);
      c.setLayer(1);

      subsystem.register(a);
      subsystem.register(b);
      subsystem.register(c);

      final results = <LuminaCollisionComponent>[];
      final count = subsystem.overlapTest(
        SphereShape(200.0),
        Matrix4.identity(),
        results,
      );

      expect(count, equals(2));
      expect(results, contains(a));
      expect(results, contains(b));
      expect(results, isNot(contains(c)));
    });
  });
}
