import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The sight sense traced its line of sight from `viewer + 160 cm`
/// to `target + 160 cm`, both actor locations (capsule centres), so it ran
/// 240 cm above the floor for a standing character: over a 2 m wall. The
/// trace now starts at the viewer's eyes (`getActorEyesViewPoint`, i.e.
/// `baseEyeHeight` above the capsule centre) and ends at the
/// target's actor location.
void main() {
  /// A world with a blocking floor whose top is at y = 0, an AI character
  /// looking down +Z from the origin and a player character 6 m ahead, both
  /// standing on the floor. [wallHeight] (cm) puts a 6 m wide, 40 cm thick
  /// blocking wall half way between them.
  ({LuminaWorld world, LuminaAIPerceptionComponent sight, LuminaCharacter viewer, LuminaCharacter target}) scene({
    required double wallHeight,
  }) {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem());
    final percepSys = LuminaAIPerceptionSystem();
    world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

    final floor = LuminaActor(location: Vector3(0.0, -50.0, 0.0));
    final floorBox = LuminaBoxComponent(boxExtent: Vector3(2000.0, 50.0, 2000.0));
    CollisionProfile.applyBlockAll(floorBox);
    floor.addComponent(floorBox);
    world.persistentLevel.registerActor(floor);

    final wall = LuminaActor(location: Vector3(0.0, wallHeight / 2, 300.0));
    final wallBox = LuminaBoxComponent(boxExtent: Vector3(300.0, wallHeight / 2, 20.0));
    CollisionProfile.applyBlockAll(wallBox);
    wall.addComponent(wallBox);
    world.persistentLevel.registerActor(wall);

    final viewer = LuminaCharacter(location: Vector3(0.0, 80.0, 0.0));
    final sight = LuminaAIPerceptionComponent(
      sightConfig: AISenseConfigSight(sightRadius: 1500.0, peripheralVisionAngleDegrees: 70.0),
      updateInterval: 0.1,
    );
    viewer.addComponent(sight);
    final target = LuminaCharacter(location: Vector3(0.0, 80.0, 600.0));
    world.persistentLevel.registerActor(viewer);
    world.persistentLevel.registerActor(target);
    // Looking down +Z: yaw 180° (the control rotation's yaw 0 faces −Z).
    LuminaAIController()
      ..possess(viewer)
      ..controlRotation.y = 180.0;
    percepSys.registerSource(target);
    world.beginPlay();
    return (world: world, sight: sight, viewer: viewer, target: target);
  }

  void settle(LuminaWorld world) {
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
  }

  test('a 2 m wall between two standing characters blocks sight', () {
    final s = scene(wallHeight: 200.0);
    settle(s.world);
    expect(s.viewer.characterMovement.isGrounded, isTrue);
    final eyes = s.viewer.getActorEyesViewPoint().location.y;
    expect(eyes, lessThan(200.0), reason: 'the AI\'s eyes (${eyes.toStringAsFixed(1)} cm) are below the wall top');
    expect(s.sight.getCurrentlyPerceivedActors(sense: AISenseType.sight), isNot(contains(s.target)),
        reason: 'the line of sight runs from the eyes, under the 2 m wall top');
  });

  test('a 1 m crate between them does not block sight: the AI looks over it from its eyes', () {
    final s = scene(wallHeight: 100.0);
    settle(s.world);
    expect(s.sight.getCurrentlyPerceivedActors(sense: AISenseType.sight), contains(s.target));
  });

  test('the line of sight starts at the eyes: a crate that hides the capsule centre does not hide the target', () {
    // A 125 cm crate right in front of the viewer covers its capsule centre
    // (80 cm) but not its eyes (144 cm); a trace from the capsule centre
    // would be blocked, one from the eyes clears it.
    final s = scene(wallHeight: 0.0);
    final crate = LuminaActor(location: Vector3(0.0, 62.5, 60.0));
    final crateBox = LuminaBoxComponent(boxExtent: Vector3(100.0, 62.5, 10.0));
    CollisionProfile.applyBlockAll(crateBox);
    crate.addComponent(crateBox);
    s.world.persistentLevel.registerActor(crate);
    settle(s.world);
    expect(s.sight.getCurrentlyPerceivedActors(sense: AISenseType.sight), contains(s.target));
  });

  test('drawDebugSight records the trace from the eyes: green to the wall, red past it', () {
    final s = scene(wallHeight: 200.0);
    s.sight.drawDebugSight = true;
    settle(s.world);
    final lines = s.world.debugShapes.where((d) => d.kind == LuminaDebugShapeKind.line).toList();
    expect(lines, hasLength(2), reason: '$lines');
    final green = lines.firstWhere((d) => d.color[1] == 1.0);
    final red = lines.firstWhere((d) => d.color[0] == 1.0);
    final eyes = s.viewer.getActorEyesViewPoint().location;
    expect((green.points.first - eyes).length, lessThan(1e-6), reason: 'starts at the eyes');
    expect(green.points.last.z, closeTo(280.0, 1.0), reason: 'the hit on the near face of the wall');
    expect((red.points.last - s.target.actorLocation).length, lessThan(1e-6), reason: 'ends at the target');
  });
}
