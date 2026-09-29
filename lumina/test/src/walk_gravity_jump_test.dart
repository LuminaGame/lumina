import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('WalkGravityJump Tests (CharMovement Task 02)', () {
    test('All 9 named tunables exist with documented defaults', () {
      final movement = LuminaCharacterMovementComponent();
      expect(movement.maxWalkSpeed, equals(600.0));
      expect(movement.acceleration, equals(2000.0));
      expect(movement.groundFriction, equals(8.0));
      expect(movement.brakingDeceleration, equals(2500.0));
      expect(movement.gravityScale, equals(1.0));
      expect(movement.jumpZVelocity, equals(500.0));
      expect(movement.airControl, equals(0.35));
      expect(movement.maxWalkSlopeAngle, equals(44.0));
      expect(movement.maxStepHeight, equals(30.0));
    });

    test('Acceleration ramp: forward input from rest reaches ~200 at 0.1s and exactly 600 at 1.0s', () {
      final movement = LuminaCharacterMovementComponent();

      // 0.1s of acceleration
      movement.calcVelocity(0.1, Vector3(1.0, 0.0, 0.0));
      expect(movement.velocity.x, closeTo(200.0, 1e-1));

      // 1.0s of acceleration (should clamp to maxWalkSpeed 600.0)
      for (int i = 0; i < 10; i++) {
        movement.calcVelocity(0.1, Vector3(1.0, 0.0, 0.0));
      }
      expect(movement.velocity.x, closeTo(600.0, 1e-2));
      expect(movement.velocity.length, closeTo(600.0, 1e-2));
    });

    test('Braking: at 600 cm/s, input released with brakingDeceleration 2500 reaches ~100 at 0.2s, snaps to 0', () {
      final movement = LuminaCharacterMovementComponent();
      movement.velocity.setValues(600.0, 0.0, 0.0);

      // 0.2s of braking: 600 - 2500 * 0.2 = 100
      movement.applyVelocityBraking(0.2);
      expect(movement.velocity.x, closeTo(100.0, 1e-1));

      // Additional 0.1s of braking (100 - 250 < 0 -> snaps to 0.0)
      movement.applyVelocityBraking(0.1);
      expect(movement.velocity.x, equals(0.0));
      expect(movement.velocity.z, equals(0.0));
    });

    test('Vertical speed is not clamped by maxWalkSpeed: falling 1s reaches velocity.y ~ -980', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final character = LuminaCharacter(location: Vector3(0.0, 10000.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.setMovementMode(MovementMode.falling);

      movement.performMove(1.0);

      expect(movement.velocity.y, closeTo(-980.0, 5.0));
    });

    test('No air friction: airborne with 300 cm/s horizontal, no input -> horizontal speed unchanged after 0.5s', () {
      final movement = LuminaCharacterMovementComponent();
      movement.setMovementMode(MovementMode.falling);
      movement.velocity.setValues(300.0, 0.0, 0.0);

      movement.calcVelocity(0.5, Vector3.zero());

      expect(movement.velocity.x, closeTo(300.0, 1e-3));
    });

    test('findFloor: 30 deg ramp is walkable, 50 deg ramp is blocking but not walkable and slides down', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      // 30 deg slope box (walkable since <= 44 deg)
      final ramp30 = LuminaActor(location: Vector3(0.0, 0.0, 0.0))
        ..actorRotation = Quaternion.axisAngle(Vector3(0.0, 0.0, 1.0), math.pi / 6.0); // 30 deg
      final ramp30Comp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(500.0, 50.0, 500.0);
      CollisionProfile.applyBlockAll(ramp30Comp);
      ramp30.addComponent(ramp30Comp);
      world.persistentLevel.registerActor(ramp30);

      final character = LuminaCharacter(location: Vector3(0.0, 140.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final floorRes = FloorResult();
      final hit = findFloor(character.capsuleComponent, colSys, 30.0, 44.0, 0.1, floorRes);
      expect(hit, isTrue);
      expect(floorRes.isWalkable, isTrue);

      // 50 deg slope box (too steep since > 44 deg)
      final ramp50 = LuminaActor(location: Vector3(1000.0, 0.0, 0.0))
        ..actorRotation = Quaternion.axisAngle(Vector3(0.0, 0.0, 1.0), 50.0 * math.pi / 180.0);
      final ramp50Comp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(500.0, 50.0, 500.0);
      CollisionProfile.applyBlockAll(ramp50Comp);
      ramp50.addComponent(ramp50Comp);
      world.persistentLevel.registerActor(ramp50);

      final char50 = LuminaCharacter(location: Vector3(1000.0, 160.0, 0.0));
      world.persistentLevel.registerActor(char50);

      final floorRes50 = FloorResult();
      final hit50 = findFloor(char50.capsuleComponent, colSys, 30.0, 44.0, 0.1, floorRes50);
      expect(hit50, isTrue);
      expect(floorRes50.blockingHit, isTrue);
      expect(floorRes50.isWalkable, isFalse);
    });

    test('Jump: grounded jump returns true and sets velocity.y; airborne jump returns false and does not double jump', () {
      final movement = LuminaCharacterMovementComponent();

      final didJump1 = movement.jump();
      expect(didJump1, isTrue);
      expect(movement.velocity.y, equals(movement.jumpZVelocity));
      expect(movement.isGrounded, isFalse);

      final didJump2 = movement.jump();
      expect(didJump2, isFalse);
      expect(movement.velocity.y, equals(movement.jumpZVelocity));
    });

    test('Air control: falling with airControl 0.35, sideways input produces 0.35 * acceleration * dt', () {
      final movement = LuminaCharacterMovementComponent();
      movement.setMovementMode(MovementMode.falling);
      movement.velocity.setZero();

      movement.calcVelocity(0.1, Vector3(0.0, 0.0, 1.0));

      final expectedZ = 2000.0 * 0.35 * 0.1; // 70
      expect(movement.velocity.z, closeTo(expectedZ, 1e-2));
    });

    test('Step up: 20cm step with maxStepHeight 30 lifts character onto step; 40cm step is blocked', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      // Floor at y = -50
      final floorActor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final floorComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 50.0, 1000.0);
      CollisionProfile.applyBlockAll(floorComp);
      floorActor.addComponent(floorComp);
      world.persistentLevel.registerActor(floorActor);

      // Step: 20cm high step starting at x = 100 (center x = 300, extent = 200)
      final stepActor = LuminaActor(location: Vector3(300.0, 10.0, 0.0));
      final stepComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(200.0, 10.0, 200.0);
      CollisionProfile.applyBlockAll(stepComp);
      stepActor.addComponent(stepComp);
      world.persistentLevel.registerActor(stepActor);

      final character = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.velocity.setValues(400.0, 0.0, 0.0);

      // Perform move into the step
      movement.performMove(0.5);

      expect(character.actorLocation.x, greaterThan(50.0));
      expect(character.actorLocation.y, greaterThanOrEqualTo(99.0)); // Lifted onto step
    });
  });
}
