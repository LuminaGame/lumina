import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The traversal check on boxes: a character at the origin (feet at y 0,
/// capsule radius 40, half height 80) facing −Z, obstacles whose front face
/// is 80 cm ahead.
void main() {
  late LuminaWorld world;
  late LuminaCollisionSubsystem collision;
  late LuminaCharacter character;

  void box(Vector3 min, Vector3 max) {
    final actor = LuminaActor(location: (min + max) * 0.5);
    final c = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = (max - min) * 0.5;
    CollisionProfile.applyBlockAll(c);
    actor.addComponent(c);
    world.persistentLevel.registerActor(actor);
  }

  /// An obstacle [height] tall and [depth] deep starting 80 cm ahead.
  void obstacle(double height, double depth) => box(Vector3(-150, 0, -80 - depth), Vector3(150, height, -80));

  void floor({double behindDrop = 0.0, double obstacleDepth = 30}) {
    if (behindDrop == 0.0) {
      box(Vector3(-2000, -100, -2000), Vector3(2000, 0, 2000));
    } else {
      final back = -80 - obstacleDepth;
      box(Vector3(-2000, -100, back), Vector3(2000, 0, 2000));
      box(Vector3(-2000, -behindDrop - 100, -2000), Vector3(2000, -behindDrop, back));
    }
  }

  void reset() {
    world = LuminaWorld(worldType: LuminaWorldType.game);
    collision = LuminaCollisionSubsystem();
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collision, world);
    character = LuminaCharacter(location: Vector3(0, 80.2, 0));
    world.persistentLevel.registerActor(character);
  }

  setUp(reset);

  LuminaTraversalCheckResult check({double speed = 0.0}) {
    world.beginPlay();
    final c = character.capsuleComponent;
    return LuminaTraversalCheck(capsuleRadius: c.radius, capsuleHalfHeight: c.halfHeight).run(
      collision,
      location: c.worldLocation.clone(),
      forward: Vector3(0, 0, -1),
      speed: speed,
      ignore: c,
    );
  }

  test('a 100 cm wall 30 cm thick with floor behind is a hurdle', () {
    floor();
    obstacle(100, 30);
    final r = check();
    expect(r.actionType, LuminaTraversalActionType.hurdle, reason: '$r');
    expect(r.obstacleHeight, closeTo(100, 0.5));
    expect(r.obstacleDepth, closeTo(30, 2));
    expect(r.backLedgeHeight, closeTo(100, 1));
    expect(r.frontLedge.z, closeTo(-80, 0.5));
    expect(r.frontLedge.y, closeTo(100, 0.5));
    expect(r.frontLedgeNormal.z, closeTo(1, 1e-6));
    expect(r.backLedge.z, closeTo(-110, 2));
    expect(r.backFloor.y, closeTo(0, 1));
    expect(r.backFloor.z, lessThan(-110 - 40));
    expect(r.facingYaw.abs(), closeTo(3.14159, 1e-3), reason: 'facing −Z');
  });

  test('the same wall over a 150 cm drop is a vault', () {
    floor(behindDrop: 150);
    obstacle(100, 30);
    final r = check();
    expect(r.actionType, LuminaTraversalActionType.vault, reason: '$r');
    expect(r.hasBackLedge, isTrue);
    expect(r.hasBackFloor, isFalse);
  });

  test('a deep 120 cm box is a low mantle, a deep 200 cm one a high mantle', () {
    floor();
    obstacle(120, 200);
    final low = check();
    expect(low.actionType, LuminaTraversalActionType.mantle, reason: '$low');
    expect(low.obstacleHeight, closeTo(120, 0.5));
    expect(low.obstacleDepth, greaterThanOrEqualTo(59));
    expect(low.hasRoomOnTop, isTrue);

    reset();
    floor();
    obstacle(200, 200);
    final high = check();
    expect(high.actionType, LuminaTraversalActionType.mantle, reason: '$high');
    expect(high.obstacleHeight, closeTo(200, 0.5));
  });

  test('a narrow platform with floor level with its top behind is mantled', () {
    floor();
    obstacle(100, 40);
    box(Vector3(-150, 0, -600), Vector3(150, 95, -120));
    final r = check();
    expect(r.actionType, LuminaTraversalActionType.mantle, reason: '$r');
  });

  test('too high, too low, no room on top and nothing ahead are no action', () {
    floor();
    obstacle(300, 30);
    expect(check().actionType, LuminaTraversalActionType.none);

    reset();
    floor();
    obstacle(40, 30);
    final low = check();
    expect(low.actionType, LuminaTraversalActionType.none);
    expect(low.reason, contains('lower'));

    reset();
    floor();
    obstacle(100, 200);
    box(Vector3(-150, 140, -400), Vector3(150, 200, -125));
    final roomless = check();
    expect(roomless.actionType, LuminaTraversalActionType.none, reason: '$roomless');
    expect(roomless.hasRoomOnTop, isFalse);

    reset();
    floor();
    final empty = check();
    expect(empty.actionType, LuminaTraversalActionType.none);
    expect(empty.reason, 'nothing ahead');
  });

  test('the trace reaches farther the faster the character moves', () {
    floor();
    box(Vector3(-150, 0, -330), Vector3(150, 100, -300));
    expect(check().actionType, LuminaTraversalActionType.none);
    expect(check(speed: 500).actionType, LuminaTraversalActionType.hurdle);
  });
}
