import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A character placed with its origin (the capsule centre) on the ground, as
/// a Blueprint character dropped into a level at height 0 is: its capsule
/// starts half in the floor. Play stands it on the floor instead of letting
/// it fall through.
({LuminaWorld world, LuminaCharacter character}) _world(Vector3 start, {double halfHeight = 88.0}) {
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
  // The level's Ground: a primitive plane, whose collider is a 10 cm slab
  // centred on y = 0.
  final ground = LuminaPrimitiveActor(
    shape: LuminaPrimitiveShape.plane,
    size: Vector3(6000.0, 0.0, 6000.0),
    color: Vector3(0.37, 0.42, 0.36),
  );
  CollisionProfile.applyBlockAll(ground.collisionComponent);
  world.persistentLevel.registerActor(ground);
  final character = LuminaCharacter(location: start);
  character.capsuleComponent.capsuleHalfHeight = halfHeight;
  character.capsuleComponent.capsuleRadius = 40.0;
  world.persistentLevel.registerActor(character);
  world.beginPlay();
  return (world: world, character: character);
}

void main() {
  const dt = 1 / 60;
  const slabTop = LuminaPrimitiveActor.planeColliderThickness / 2;

  test('a character placed with its capsule centre on the ground stands on it and does not fall through', () {
    final s = _world(Vector3(839.0, 0.0, 87.0));
    final movement = s.character.characterMovement;
    for (var f = 0; f < 180; f++) {
      movement.performMove(dt);
    }
    final bottom = s.character.actorLocation.y - 88.0;
    expect(bottom, closeTo(slabTop, 2.0), reason: 'capsule bottom ${bottom.toStringAsFixed(1)} cm, ground top $slabTop cm');
    expect(movement.isWalking, isTrue);
  });

  test('a character placed above the ground still falls onto it', () {
    final s = _world(Vector3(0.0, 300.0, 0.0));
    final movement = s.character.characterMovement;
    movement.performMove(dt);
    expect(s.character.actorLocation.y, greaterThan(250.0), reason: 'not snapped down: it falls');
    for (var f = 0; f < 240; f++) {
      movement.performMove(dt);
    }
    expect(s.character.actorLocation.y - 88.0, closeTo(slabTop, 2.0));
  });

  test('a character fully below the ground is not pulled up through it', () {
    final s = _world(Vector3(0.0, -400.0, 0.0));
    s.character.characterMovement.performMove(dt);
    expect(s.character.actorLocation.y, lessThan(-300.0));
  });
}
