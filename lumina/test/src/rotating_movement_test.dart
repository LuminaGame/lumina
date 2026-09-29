import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaRotatingMovementComponent Tests', () {
    test('Rotating 90 deg/s for 1.0s advances yaw by 90 degrees', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final rot = LuminaRotatingMovementComponent(
        rotationRate: Vector3(0.0, 90.0, 0.0),
      );
      actor.addComponent(rot);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      for (int i = 0; i < 100; i++) {
        world.tick(0.01);
      }

      // Expected yaw = 90 deg (pi/2 rad) -> rotated forward vector (0,0,1) becomes (-1,0,0)
      final fwd = actor.actorRotation.rotate(Vector3(0.0, 0.0, 1.0));
      expect(fwd.x, closeTo(-1.0, 1e-3));
      expect(fwd.y, closeTo(0.0, 1e-3));
      expect(fwd.z, closeTo(0.0, 1e-3));
    });

    test('Rotating 360 degrees completes full circle with minimal drift', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final rot = LuminaRotatingMovementComponent(
        rotationRate: Vector3(0.0, 90.0, 0.0),
      );
      actor.addComponent(rot);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // 4.0 seconds = 360 degrees
      for (int i = 0; i < 400; i++) {
        world.tick(0.01);
      }

      final fwd = actor.actorRotation.rotate(Vector3(0.0, 0.0, 1.0));
      expect(fwd.x, closeTo(0.0, 1e-3));
      expect(fwd.y, closeTo(0.0, 1e-3));
      expect(fwd.z, closeTo(1.0, 1e-3));
    });

    test('Rotating determinism: 100 ticks of 0.01 vs 1 tick of 1.0', () {
      final world1 = LuminaWorld(worldType: LuminaWorldType.game);
      final actor1 = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final rot1 = LuminaRotatingMovementComponent(rotationRate: Vector3(45.0, 90.0, 30.0));
      actor1.addComponent(rot1);
      world1.persistentLevel.registerActor(actor1);
      world1.beginPlay();
      for (int i = 0; i < 100; i++) {
        world1.tick(0.01);
      }

      final world2 = LuminaWorld(worldType: LuminaWorldType.game);
      final actor2 = LuminaActor(location: Vector3.zero(), rotation: Quaternion.identity());
      final rot2 = LuminaRotatingMovementComponent(rotationRate: Vector3(45.0, 90.0, 30.0));
      actor2.addComponent(rot2);
      world2.persistentLevel.registerActor(actor2);
      world2.beginPlay();
      world2.tick(1.0);

      final fwd1 = actor1.actorRotation.rotate(Vector3(0.0, 0.0, 1.0));
      final fwd2 = actor2.actorRotation.rotate(Vector3(0.0, 0.0, 1.0));

      expect(fwd1.x, closeTo(fwd2.x, 1e-3));
      expect(fwd1.y, closeTo(fwd2.y, 1e-3));
      expect(fwd1.z, closeTo(fwd2.z, 1e-3));
    });

    test('Pivot translation orbits around pivot point', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final rot = LuminaRotatingMovementComponent(
        rotationRate: Vector3(0.0, 180.0, 0.0),
        pivotTranslation: Vector3(1.0, 0.0, 0.0), // Pivot is at (1, 0, 0)
      );
      actor.addComponent(rot);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // 1.0 second at 180 deg/s = 180 degree rotation around pivot (1, 0, 0)
      for (int i = 0; i < 100; i++) {
        world.tick(0.01);
      }

      // Actor was at (0, 0, 0), pivot at (1, 0, 0). After 180 deg orbit, actor is at (2, 0, 0)
      expect(actor.actorLocation.x, closeTo(2.0, 1e-3));
      expect(actor.actorLocation.y, closeTo(0.0, 1e-3));
      expect(actor.actorLocation.z, closeTo(0.0, 1e-3));
    });
  });
}
