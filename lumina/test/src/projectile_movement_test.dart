import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaProjectileMovementComponent Tests', () {
    test('onBeginPlay initializes velocity along forward vector when local space enabled', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(
        location: Vector3(0.0, 0.0, 0.0),
        rotation: Quaternion.identity(), // facing +Z in Lumina forward convention
      );
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 1000.0,
        bInitialVelocityInLocalSpace: true,
      );
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      expect(proj.velocity.x, closeTo(0.0, 1e-3));
      expect(proj.velocity.y, closeTo(0.0, 1e-3));
      expect(proj.velocity.z, closeTo(1000.0, 1e-3));
      expect(proj.isSimulating, isTrue);
    });

    test('Free flight gravity parabolic motion', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 10000.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 0.0,
        projectileGravityScale: 1.0,
      );
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // 100 ticks of 0.01s = 1.0s
      for (int i = 0; i < 100; i++) {
        world.tick(0.01);
      }

      // v.y = -980 cm/s
      expect(proj.velocity.y, closeTo(-980.0, 5.0));
      // y = 10000 - 0.5 * 980 * 1^2 = ~9509.5
      expect(actor.actorLocation.y, closeTo(9505.0, 20.0));
    });

    test('projectileGravityScale 0 maintains straight horizontal flight', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 1000.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 1500.0,
        projectileGravityScale: 0.0,
        bInitialVelocityInLocalSpace: false,
      );
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();
      proj.setVelocity(Vector3(1500.0, 0.0, 0.0));

      for (int i = 0; i < 50; i++) {
        world.tick(0.02);
      }

      expect(proj.velocity.x, closeTo(1500.0, 1e-3));
      expect(proj.velocity.y, closeTo(0.0, 1e-3));
      expect(actor.actorLocation.y, closeTo(1000.0, 1e-3));
      expect(actor.actorLocation.x, closeTo(1500.0, 1e-3)); // 1500 cm/s * 1.0s = 1500 cm
    });

    test('maxSpeed caps accelerating velocity', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 100000.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 0.0,
        maxSpeed: 1200.0,
        projectileGravityScale: 1.0,
      );
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      for (int i = 0; i < 300; i++) {
        world.tick(0.016);
      }

      expect(proj.velocity.length, closeTo(1200.0, 1e-3));
    });

    test('Bounce restitution and tangential friction decomposition', () {
      final proj = LuminaProjectileMovementComponent(
        bShouldBounce: true,
        bounciness: 0.5,
        friction: 0.2,
      );

      final incomingV = Vector3(300.0, -400.0, 0.0);
      final normal = Vector3(0.0, 1.0, 0.0);

      // vn = -400, vt = 300
      // vn' = - (-400) * 0.5 = 200
      // vt' = 300 * (1 - 0.2) = 240
      final outgoing = proj.calculateBounceVelocity(incomingV, normal);

      expect(outgoing.x, closeTo(240.0, 1e-3));
      expect(outgoing.y, closeTo(200.0, 1e-3));
      expect(outgoing.z, closeTo(0.0, 1e-3));
    });

    test('Bounce stop threshold stops simulation when post-bounce speed is low', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final floor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final floorCol = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(5000.0, 50.0, 5000.0);
      CollisionProfile.applyBlockAll(floorCol);
      floor.addComponent(floorCol);
      world.persistentLevel.registerActor(floor);

      final actor = LuminaActor(location: Vector3(0.0, 55.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 0.0,
        bShouldBounce: true,
        bounciness: 0.05, // very small bounce -> speed < threshold
        bounceVelocityStopSimulatingThreshold: 100.0,
      );
      proj.setVelocity(Vector3(0.0, -80.0, 0.0));
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      bool stopped = false;
      proj.onProjectileStop = (hit) => stopped = true;

      world.beginPlay();
      world.tick(0.1);

      expect(stopped, isTrue);
      expect(proj.isSimulating, isFalse);
    });

    test('Homing acceleration curves trajectory toward target component', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final targetActor = LuminaActor(location: Vector3(1000.0, 0.0, 1000.0));
      world.persistentLevel.registerActor(targetActor);

      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 1000.0,
        projectileGravityScale: 0.0,
        homingTargetComponent: targetActor.rootComponent,
        homingAccelerationMagnitude: 2000.0,
        bInitialVelocityInLocalSpace: false,
      );
      proj.setVelocity(Vector3(0.0, 0.0, 1000.0)); // initially moving +Z
      actor.addComponent(proj);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      double dist1 = (targetActor.actorLocation - actor.actorLocation).length;
      world.tick(0.2);
      double dist2 = (targetActor.actorLocation - actor.actorLocation).length;
      world.tick(0.2);
      double dist3 = (targetActor.actorLocation - actor.actorLocation).length;

      expect(dist2, lessThan(dist1));
      expect(dist3, lessThan(dist2));
    });
  });
}
