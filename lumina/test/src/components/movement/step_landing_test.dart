import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A world with a floor whose top is at y = 0 and a 20 cm step (top at
/// y = 20) spanning x = 100..500.
({LuminaWorld world, LuminaCharacter character}) _stepWorld(Vector3 start) {
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  final colSys = LuminaCollisionSubsystem();
  world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(colSys, world);
  void box(Vector3 centre, Vector3 extent) {
    final actor = LuminaActor(location: centre);
    final comp = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = extent;
    CollisionProfile.applyBlockAll(comp);
    actor.addComponent(comp);
    world.persistentLevel.registerActor(actor);
  }

  box(Vector3(0.0, -50.0, 0.0), Vector3(1000.0, 50.0, 1000.0));
  box(Vector3(300.0, 10.0, 0.0), Vector3(200.0, 10.0, 200.0));
  final character = LuminaCharacter(location: start);
  world.persistentLevel.registerActor(character);
  world.beginPlay();
  return (world: world, character: character);
}

void main() {
  const dt = 1 / 60;

  test('a character falling onto a step lands on it, not on a floor still 20 cm below its feet', () {
    // The feet start 60 cm above the step's top.
    final s = _stepWorld(Vector3(300.0, 20.0 + 80.0 + 60.0, 0.0));
    final movement = s.character.characterMovement;
    movement.setMovementMode(MovementMode.falling);
    var landedAt = -1;
    for (var f = 0; f < 120; f++) {
      movement.performMove(dt);
      if (movement.isWalking) {
        expect(movement.currentFloor.floorDistance, lessThan(1.0),
            reason: 'frame $f: walking with the floor ${movement.currentFloor.floorDistance.toStringAsFixed(1)} cm below');
        final feet = s.character.actorLocation.y - 80.0;
        expect(feet - 20.0, lessThan(1.0), reason: 'frame $f: feet ${feet.toStringAsFixed(1)} cm, step top 20 cm');
        if (landedAt < 0) landedAt = f;
      }
    }
    expect(landedAt, greaterThan(0), reason: 'the character lands');
    expect(s.character.actorLocation.y - 80.0, closeTo(20.0, 1.0));
  });

  test('a character walking off a 20 cm step follows it down smoothly, never dropping a step height in one frame', () {
    // On the step, walking towards its edge at x = 500 at 300 cm/s (5 cm a
    // frame): the capsule's rounded bottom rolls over the edge, about 35 cm
    // of travel for the 20 cm.
    final s = _stepWorld(Vector3(420.0, 20.0 + 80.0 + 0.05, 0.0));
    final movement = s.character.characterMovement;
    movement.performMove(dt);
    expect(movement.isWalking, isTrue);
    var maxDrop = 0.0;
    var maxDropAt = '';
    var fell = false;
    for (var f = 0; f < 90; f++) {
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      movement.velocity.setValues(300.0, movement.velocity.y, 0.0);
      final before = s.character.actorLocation.y;
      movement.performMove(dt);
      if (movement.isFalling) fell = true;
      final drop = before - s.character.actorLocation.y;
      if (drop > maxDrop) {
        maxDrop = drop;
        maxDropAt = 'frame $f at x ${s.character.actorLocation.x.toStringAsFixed(1)}';
      }
    }
    expect(fell, isFalse, reason: 'a 20 cm step is walked down, not fallen from');
    expect(maxDrop, lessThan(10.0), reason: 'dropped ${maxDrop.toStringAsFixed(1)} cm in one frame ($maxDropAt)');
    expect(s.character.actorLocation.x, greaterThan(600.0));
    expect(s.character.actorLocation.y - 80.0, closeTo(0.0, 1.0));
  });
}
