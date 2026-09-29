import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('MovementModes Tests (CharMovement Task 03)', () {
    test('setMovementMode(flying) from walking -> onMovementModeChanged(walking, flying) fired once; setting flying again is no-op', () {
      final movement = LuminaCharacterMovementComponent();
      expect(movement.movementMode, equals(MovementMode.walking));

      final transitions = <(MovementMode, MovementMode)>[];
      movement.onMovementModeChanged = (prev, curr) {
        transitions.add((prev, curr));
      };

      movement.setMovementMode(MovementMode.flying);
      expect(movement.movementMode, equals(MovementMode.flying));
      expect(movement.isFlying, isTrue);
      expect(transitions.length, equals(1));
      expect(transitions.first, equals((MovementMode.walking, MovementMode.flying)));

      // Setting flying again -> no-op
      movement.setMovementMode(MovementMode.flying);
      expect(transitions.length, equals(1));
    });

    test('Walk-off-ledge sequence: character walks off a platform edge -> mode is falling and callback recorded [walking -> falling]', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      // Platform ending at x = 100 (center at 0, halfExtent 100)
      final platform = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final platComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 50.0, 500.0);
      CollisionProfile.applyBlockAll(platComp);
      platform.addComponent(platComp);
      world.persistentLevel.registerActor(platform);

      final character = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      final transitions = <(MovementMode, MovementMode)>[];
      movement.onMovementModeChanged = (prev, curr) {
        transitions.add((prev, curr));
      };

      // Walk forward past the ledge (to x = 200)
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.velocity.setValues(400.0, 0.0, 0.0);
      movement.performMove(0.5);

      expect(movement.movementMode, equals(MovementMode.falling));
      expect(movement.isFalling, isTrue);
      expect(transitions, contains((MovementMode.walking, MovementMode.falling)));
    });

    test('Landing sequence: falling character reaches a flat floor -> mode returns to walking, velocity.y == 0, and transitions are [walking -> falling, falling -> walking]', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      // Floor at y = -50 (top at y = 0)
      final floor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final floorComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 50.0, 1000.0);
      CollisionProfile.applyBlockAll(floorComp);
      floor.addComponent(floorComp);
      world.persistentLevel.registerActor(floor);

      final character = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      final transitions = <(MovementMode, MovementMode)>[];
      movement.onMovementModeChanged = (prev, curr) {
        transitions.add((prev, curr));
      };

      // Jump
      final jumped = movement.jump();
      expect(jumped, isTrue);
      expect(transitions, equals([(MovementMode.walking, MovementMode.falling)]));

      // Fall back down over frames
      for (int i = 0; i < 60; i++) {
        world.tick(0.016);
      }

      expect(movement.movementMode, equals(MovementMode.walking));
      expect(movement.isWalking, isTrue);
      expect(movement.velocity.y, closeTo(0.0, 1e-2));
      expect(transitions, equals([
        (MovementMode.walking, MovementMode.falling),
        (MovementMode.falling, MovementMode.walking),
      ]));
    });

    test('Enter-walking guard: setMovementMode(walking) while 500cm above ground -> immediately re-routed to falling', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      // Floor at y = -50 (top at y = 0)
      final floor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
      final floorComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 50.0, 1000.0);
      CollisionProfile.applyBlockAll(floorComp);
      floor.addComponent(floorComp);
      world.persistentLevel.registerActor(floor);

      // Character 500cm above ground
      final character = LuminaCharacter(location: Vector3(0.0, 500.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.setMovementMode(MovementMode.flying);

      // Try setting walking while high in the air
      movement.setMovementMode(MovementMode.walking);

      expect(movement.movementMode, equals(MovementMode.falling));
      expect(movement.isFalling, isTrue);
    });

    test('physFlying: in flying mode, gravity is off -> hovering leaves velocity.y == 0; vertical input moves character up to maxFlySpeed', () {
      final movement = LuminaCharacterMovementComponent();
      movement.setMovementMode(MovementMode.flying);
      expect(movement.maxFlySpeed, equals(1200.0));

      // 1. Hovering without input
      movement.performMove(0.5);
      expect(movement.velocity.y, closeTo(0.0, 1e-6));

      // 2. Upward input
      movement.addInputVector(Vector3(0.0, 1.0, 0.0));
      movement.performMove(1.0);
      expect(movement.velocity.y, greaterThan(500.0));
      expect(movement.velocity.length, lessThanOrEqualTo(movement.maxFlySpeed + 1e-3));
    });

    test('physSwimming: with buoyancy 1.0, effective gravity is 0; with buoyancy 0.5, sinking occurs; speed clamps to maxSwimSpeed', () {
      final movement = LuminaCharacterMovementComponent();
      movement.setMovementMode(MovementMode.swimming);
      expect(movement.maxSwimSpeed, equals(300.0));
      expect(movement.buoyancy, equals(1.0));
      expect(movement.fluidFriction, equals(2.0));

      // Buoyancy 1.0 -> no sinking
      movement.performMove(0.1);
      expect(movement.velocity.y, closeTo(0.0, 1e-2));

      // Buoyancy 0.5 -> sinking with gravity * 0.5
      movement.buoyancy = 0.5;
      movement.fluidFriction = 0.0; // Isolate gravity test
      movement.performMove(1.0);
      expect(movement.velocity.y, closeTo(-980.0 * 0.5, 10.0));

      // Swimming horizontal input clamped to maxSwimSpeed
      movement.velocity.setZero();
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.performMove(1.0);
      expect(movement.velocity.length, lessThanOrEqualTo(movement.maxSwimSpeed + 1e-3));
    });

    test('physCustom: setMovementMode(custom, customModeIndex: 2) -> delegate called every tick; index change fires transition', () {
      final movement = LuminaCharacterMovementComponent();
      int callCount = 0;
      int lastIndex = -1;
      movement.physCustomDelegate = (dt, index) {
        callCount++;
        lastIndex = index;
      };

      final transitions = <(MovementMode, MovementMode)>[];
      movement.onMovementModeChanged = (prev, curr) {
        transitions.add((prev, curr));
      };

      movement.setMovementMode(MovementMode.custom, customModeIndex: 2);
      expect(movement.movementMode, equals(MovementMode.custom));
      expect(movement.customMovementModeIndex, equals(2));

      movement.performMove(0.016);
      expect(callCount, equals(1));
      expect(lastIndex, equals(2));

      // Switching sub-mode index
      movement.setMovementMode(MovementMode.custom, customModeIndex: 3);
      expect(movement.customMovementModeIndex, equals(3));
      expect(transitions.length, equals(2));
    });

    test('stopJumping cuts upward velocity for a short hop and clears the held flag', () {
      final movement = LuminaCharacterMovementComponent();
      movement.setMovementMode(MovementMode.walking);
      movement.jumpZVelocity = 800.0;
      movement.jumpCutMultiplier = 0.5;

      expect(movement.isJumpHeld, isFalse);
      movement.stopJumping(); // no-op when nothing is held
      expect(movement.jump(), isTrue);
      expect(movement.isJumpHeld, isTrue);
      expect(movement.velocity.y, 800.0);

      movement.stopJumping();
      expect(movement.isJumpHeld, isFalse);
      expect(movement.velocity.y, closeTo(400.0, 1e-7));

      // A second release does nothing more.
      movement.stopJumping();
      expect(movement.velocity.y, closeTo(400.0, 1e-7));

      // Landing clears any held state; a full hold keeps the full velocity.
      movement.setMovementMode(MovementMode.walking);
      movement.jumpCutMultiplier = 1.0;
      movement.jump();
      movement.stopJumping();
      expect(movement.velocity.y, 800.0);
    });

    test('Jump integration: jump() in walking mode -> history [walking -> falling]; jump() while flying returns false', () {
      final movement = LuminaCharacterMovementComponent();
      expect(movement.movementMode, equals(MovementMode.walking));

      final didJump = movement.jump();
      expect(didJump, isTrue);
      expect(movement.movementMode, equals(MovementMode.falling));
      expect(movement.velocity.y, equals(movement.jumpZVelocity));

      // Flying mode cannot jump
      movement.setMovementMode(MovementMode.flying);
      expect(movement.jump(), isFalse);
      expect(movement.movementMode, equals(MovementMode.flying));
    });

    test('Every mode still collides: flying into a wall is stopped by the sweep core without penetration', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);

      final wallActor = LuminaActor(location: Vector3(200.0, 0.0, 0.0));
      final wallComp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 500.0, 500.0);
      CollisionProfile.applyBlockAll(wallComp);
      wallActor.addComponent(wallComp);
      world.persistentLevel.registerActor(wallActor);

      final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final movement = character.characterMovement;
      movement.setMovementMode(MovementMode.flying);
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.velocity.setValues(1000.0, 0.0, 0.0);

      movement.performMove(0.5);

      expect(character.actorLocation.x, lessThan(100.0 - character.capsuleComponent.radius + 1e-1));
      expect(character.actorLocation.x, greaterThan(0.0));
    });
  });
}
