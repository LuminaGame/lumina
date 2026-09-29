import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('KinematicSweepCore Tests (CharMovement Task 01)', () {
    test('Free move: no obstacles, velocity (200,0,0), dt 0.5 -> owner moves (100,0,0) and safeMove returns true', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final character = LuminaCharacter();
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.gravityScale = 0.0;
      movement.velocity.setValues(200.0, 0.0, 0.0);

      movement.performMove(0.5);

      expect(character.actorLocation.x, closeTo(100.0, 1e-4));
      expect(character.actorLocation.y, closeTo(0.0, 1e-4));
      expect(character.actorLocation.z, closeTo(0.0, 1e-4));
    });

    test('Blocked move: wall at x=100, capsule r=40 at origin, delta (200,0,0) -> final x == 100 - 40 - skinWidth', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final wallActor = LuminaActor(location: Vector3(200.0, 0.0, 0.0)); // Center at x=200, halfExtent.x=100 -> wall plane at x=100
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      collisionSubsystem.register(wallComp);
      world.persistentLevel.registerActor(wallActor);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.gravityScale = 0.0;
      movement.velocity.setValues(200.0, 0.0, 0.0);

      movement.performMove(1.0);

      final expectedX = 100.0 - character.capsuleComponent.radius - movement.skinWidth;
      expect(character.actorLocation.x, closeTo(expectedX, 1e-1));
    });

    test('computeSlideVector: head-on stops (0,0,0), oblique (1,0,1) with normal (-1,0,0) -> (0,0,1)', () {
      final out = Vector3.zero();

      computeSlideVector(Vector3(1.0, 0.0, 0.0), 0.0, Vector3(-1.0, 0.0, 0.0), out);
      expect(out.x, closeTo(0.0, 1e-6));
      expect(out.y, closeTo(0.0, 1e-6));
      expect(out.z, closeTo(0.0, 1e-6));

      computeSlideVector(Vector3(1.0, 0.0, 1.0), 0.0, Vector3(-1.0, 0.0, 0.0), out);
      expect(out.x, closeTo(0.0, 1e-6));
      expect(out.y, closeTo(0.0, 1e-6));
      expect(out.z, closeTo(1.0, 1e-6));
    });

    test('45 deg wall slide: delta (200,0,0) into angled wall slides along tangent without penetrating', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      // Angled wall rotated 45 deg around Y
      final wallActor = LuminaActor(location: Vector3(150.0, 0.0, 0.0))
        ..actorRotation = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi / 4.0);
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(50.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      collisionSubsystem.register(wallComp);
      world.persistentLevel.registerActor(wallActor);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.gravityScale = 0.0;
      movement.velocity.setValues(200.0, 0.0, 0.0);

      movement.performMove(1.0);

      expect(character.actorLocation.x, greaterThan(0.0));
      expect(character.actorLocation.z.abs(), greaterThan(0.0));

      final overlaps = <LuminaCollisionComponent>[];
      collisionSubsystem.overlapTest(
        character.capsuleComponent.worldShape,
        character.capsuleComponent.worldTransform,
        overlaps,
        ignore: character.capsuleComponent,
      );
      expect(overlaps, isEmpty);
    });

    test('Corner (two walls 90 deg apart): position stable across ticks without jitter', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      // Wall 1 at x = 100
      final wall1 = LuminaActor(location: Vector3(200.0, 0.0, 0.0));
      final comp1 = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(comp1);
      wall1.addComponent(comp1);
      collisionSubsystem.register(comp1);
      world.persistentLevel.registerActor(wall1);

      // Wall 2 at z = 100
      final wall2 = LuminaActor(location: Vector3(0.0, 0.0, 200.0));
      final comp2 = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(500.0, 500.0, 100.0);
      CollisionProfile.applyBlockAll(comp2);
      wall2.addComponent(comp2);
      collisionSubsystem.register(comp2);
      world.persistentLevel.registerActor(wall2);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.gravityScale = 0.0;
      movement.velocity.setValues(200.0, 0.0, 200.0);

      // Move into the corner
      movement.performMove(1.0);

      // Repeated moves into the corner remain stable without jitter
      Vector3 lastPos = character.actorLocation.clone();
      for (int i = 0; i < 10; i++) {
        movement.performMove(0.016);
        expect((character.actorLocation - lastPos).length, lessThan(1e-1));
        lastPos = character.actorLocation.clone();
      }
    });

    test('Velocity clamping: after hitting wall head-on, velocity.x is zeroed while velocity.z is preserved', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final wallActor = LuminaActor(location: Vector3(200.0, 0.0, 0.0));
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      collisionSubsystem.register(wallComp);
      world.persistentLevel.registerActor(wallActor);

      final character = LuminaCharacter(location: Vector3(50.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.velocity.setValues(400.0, 0.0, 300.0);

      movement.performMove(0.5);

      expect(movement.velocity.x, closeTo(0.0, 1e-2));
      expect(movement.velocity.z, closeTo(300.0, 1e-2));
    });

    test('Depenetration: capsule spawned overlapping box by 10cm pushes out along contact normal', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      // Box wall plane at x = 100 (center x=200, halfExtent=100)
      final wallActor = LuminaActor(location: Vector3(200.0, 0.0, 0.0));
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      collisionSubsystem.register(wallComp);
      world.persistentLevel.registerActor(wallActor);

      // Capsule (radius 40) placed at x = 70 (boundary is at 70 + 40 = 110 -> 10 deep into wall)
      final character = LuminaCharacter(location: Vector3(70.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.velocity.setZero();

      movement.performMove(0.016);

      // Pushed out to x <= 100 - 40 = 60
      expect(character.actorLocation.x, lessThanOrEqualTo(60.1));
    });

    test('Root motion: addRootMotionDelta swept, consumed once, and blocked by wall', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.velocity.setZero();
      movement.addRootMotionDelta(Vector3(50.0, 0.0, 0.0));

      movement.performMove(0.016);
      expect(character.actorLocation.x, closeTo(50.0, 1e-2));

      // Second move does not repeat root motion
      movement.performMove(0.016);
      expect(character.actorLocation.x, closeTo(50.0, 1e-2));
    });

    test('No rigid-body coupling: overlap-response trigger passes through without altering velocity', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final triggerActor = LuminaActor(location: Vector3(100.0, 0.0, 0.0));
      final triggerComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyOverlapAll(triggerComp);
      triggerActor.addComponent(triggerComp);
      collisionSubsystem.register(triggerComp);
      world.persistentLevel.registerActor(triggerActor);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.velocity.setValues(400.0, 0.0, 0.0);

      movement.performMove(0.5);

      expect(character.actorLocation.x, closeTo(200.0, 1e-2));
      expect(movement.velocity.x, closeTo(400.0, 1e-2));
    });
  });
}
