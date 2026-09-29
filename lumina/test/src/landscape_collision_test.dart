import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A placed landscape is a walkable, sweep-able heightfield
/// collider: the character's capsule stands on it, walks up its slopes, steps
/// onto its ledges and stops at its cliffs, PIE and generated game alike.

const double _u = LuminaUnits.unitsPerMetre;

/// A world with a collision subsystem (as PIE and a generated game build it).
(LuminaWorld, LuminaCollisionSubsystem) _world() {
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  final collision = world.registerSubsystem(LuminaCollisionSubsystem());
  return (world, collision);
}

/// A terrain whose height is [heightOf](x, z) in terrain metres.
LandscapeData _terrain(double Function(double x, double z) heightOf,
    {int resolution = 129, double worldSize = 256.0, double maxHeight = 100.0}) {
  final data = LandscapeData.flat(gridResolution: resolution, worldSize: worldSize, maxHeight: maxHeight);
  for (var r = 0; r < resolution; r++) {
    for (var c = 0; c < resolution; c++) {
      data.setHeight(c, r, heightOf(data.worldXOf(c), data.worldZOf(r)).clamp(0.0, maxHeight));
    }
  }
  return data;
}

LuminaLandscapeComponent _place(LuminaWorld world, LandscapeData data, {Vector3? location, Quaternion? rotation}) {
  final landscape = LuminaLandscapeComponent(data: data, location: location, rotation: rotation);
  world.persistentLevel.registerActor(LuminaActor(root: landscape));
  return landscape;
}

void main() {
  test('a placed landscape registers a heightfield collider that a capsule sweep lands on', () {
    final (world, collision) = _world();
    final landscape = _place(world, _terrain((x, z) => 0.0));
    final collider = landscape.collisionComponent;
    expect(collider, isNotNull, reason: 'the landscape must register with the collision subsystem');
    expect(collider!.shapeType, CollisionShapeType.heightfield);
    expect(collider.objectType, CollisionObjectType.worldStatic);

    // A character-sized capsule 5 m up, swept 10 m down: its bottom (centre
    // − half height) meets the surface at y = 0 after 420 cm.
    final hit = HitResult();
    final start = Matrix4.translation(Vector3(300.0, 500.0, -200.0));
    expect(collision.sweep(const CapsuleShape(40.0, 80.0), start, Vector3(0.0, -1000.0, 0.0), hit), isTrue);
    expect(hit.component, same(collider));
    expect(hit.time, closeTo(0.42, 0.01));
    expect(hit.impactNormal.y, closeTo(1.0, 1e-3));

    // Overlap: a sphere half in the ground overlaps, one above it does not.
    final overlaps = <LuminaCollisionComponent>[];
    collision.overlapTest(const SphereShape(50.0), Matrix4.translation(Vector3(0.0, 30.0, 0.0)), overlaps);
    expect(overlaps, [collider]);
    collision.overlapTest(const SphereShape(50.0), Matrix4.translation(Vector3(0.0, 100.0, 0.0)), overlaps);
    expect(overlaps, isEmpty);

    // A ray from above hits the surface; one outside the footprint misses.
    expect(collision.raycast(Vector3(0.0, 1000.0, 0.0), Vector3(0.0, -1.0, 0.0), 5000.0, hit), isTrue);
    expect(hit.impactPoint.y, closeTo(0.0, 0.5));
    expect(collision.raycast(Vector3(20000.0, 1000.0, 0.0), Vector3(0.0, -1.0, 0.0), 5000.0, hit), isFalse);
    world.cleanup();
  });

  test('the collider follows the placed actor\'s location and rotation', () {
    final (world, collision) = _world();
    // A 20 m bump 60 m along the terrain's local +X.
    final data = _terrain((x, z) => 20.0 * math.exp(-((x - 60) * (x - 60) + z * z) / (2 * 8.0 * 8.0)));
    final origin = Vector3(1000.0, 50.0, -300.0);
    final landscape = _place(world, data,
        location: origin, rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi / 2));

    double surfaceAt(double wx, double wz) {
      final hit = HitResult();
      expect(collision.raycast(Vector3(wx, 5000.0, wz), Vector3(0.0, -1.0, 0.0), 10000.0, hit), isTrue,
          reason: 'the ray at ($wx, $wz) must hit the terrain');
      return hit.impactPoint.y;
    }

    // Flat ground sits at the actor's height.
    expect(surfaceAt(origin.x + 500, origin.z + 500), closeTo(origin.y, 0.5));
    // Local +X, rotated 90° about Y, is world −Z: the bump is there, and not
    // along world +X.
    expect(surfaceAt(origin.x, origin.z - 60 * _u), closeTo(origin.y + 20 * _u, 1.0 * _u));
    expect(surfaceAt(origin.x + 60 * _u, origin.z), closeTo(origin.y, 1.0));
    expect(landscape.collisionComponent!.getAABB().min.y, closeTo(origin.y, 1e-6));
    world.cleanup();
  });

  test('a character walks up a 20° slope on the surface, never through it', () {
    final (world, _) = _world();
    final slope = math.tan(20 * math.pi / 180);
    final data = _terrain((x, z) => math.max(0.0, x * slope));
    _place(world, data);
    final character = LuminaCharacter(location: Vector3(-1000.0, 80.0 + 1.0, 0.0));
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    final movement = character.characterMovement;
    final halfHeight = character.capsuleComponent.halfHeight;

    var maxGap = 0.0;
    for (var tick = 0; tick < 300; tick++) {
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      world.tick(1 / 60);
      final at = character.actorLocation;
      final surface = data.sampleHeight(at.x / _u, at.z / _u) * _u;
      final gap = (at.y - halfHeight) - surface;
      expect(gap, greaterThan(-2.0), reason: 'tick $tick: the capsule is ${-gap} cm inside the terrain');
      maxGap = math.max(maxGap, gap);
    }
    expect(character.actorLocation.x, greaterThan(500.0), reason: 'it walked up the slope');
    expect(movement.isWalking, isTrue);
    expect(maxGap, lessThan(12.0), reason: 'it stayed on the surface (max gap $maxGap cm)');
    world.cleanup();
  });

  // Walking up a ridge whose slope steepens cell by cell, the
  // capsule's forward sweep touched the next, steeper cell at t = 0 and the
  // slide projected the move onto the crease of the two (almost parallel)
  // ground planes — a line along X — so a character heading −Z stopped dead
  // on walkable ground.
  test('a character walks over a gentle ridge that steepens under it and down the far side', () {
    final (world, _) = _world();
    // 8 m over σ 9 m: ≈ 28° at its steepest, walkable (44°); 1 m cells.
    final data = _terrain((x, z) => 3.0 + 8.0 * math.exp(-(z * z) / (2 * 9.0 * 9.0)), worldSize: 128.0, maxHeight: 60.0);
    _place(world, data);
    // The Third Person mannequin's capsule (35 cm radius), as landscape
    // smoke Scenario 04 walks it.
    const halfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
    double surfaceAt(double wx, double wz) => data.sampleHeight(wx / _u, wz / _u) * _u;
    final character = LuminaTemplateCharacter(thirdPerson: true, location: Vector3(0.0, surfaceAt(0.0, 3000.0) + halfHeight + 2.0, 3000.0));
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    final movement = character.characterMovement;

    var crestFeet = double.negativeInfinity;
    var maxGap = 0.0;
    for (var tick = 0; tick < 1200; tick++) {
      movement.addInputVector(Vector3(0.0, 0.0, -1.0));
      world.tick(1 / 60);
      final at = character.actorLocation;
      final gap = (at.y - halfHeight) - surfaceAt(at.x, at.z);
      // −3 cm: the bilinear sample sits up to ~2 cm above the triangulated
      // surface on this curved ridge.
      expect(gap, greaterThan(-3.0), reason: 'tick $tick: the capsule is ${-gap} cm inside the terrain');
      maxGap = math.max(maxGap, gap);
      crestFeet = math.max(crestFeet, at.y - halfHeight);
    }
    final end = character.actorLocation;
    expect(end.z, lessThan(-10.0 * _u), reason: 'it crossed the crest and walked down the far side (z ${end.z})');
    expect(crestFeet, greaterThan(10.0 * _u), reason: 'it climbed the 8 m ridge (feet peaked at $crestFeet cm)');
    expect(maxGap, lessThan(15.0), reason: 'it stayed on the surface (max gap $maxGap cm)');
    expect(movement.isWalking, isTrue);
    world.cleanup();
  });

  test('a 25 cm ledge is stepped onto; a 3 m cliff face stops the character', () {
    final (world, _) = _world();
    // 25 cm cells (129 samples over 32 m): a ledge rising 0.25 m in one cell
    // (45°, steeper than the walkable 44°) at x = 0, and a 3 m wall at x = 8.
    final data = _terrain((x, z) => x < 0 ? 0.0 : (x < 8 ? 0.25 : 3.25), worldSize: 32.0, maxHeight: 10.0);
    _place(world, data);
    final character = LuminaCharacter(location: Vector3(-300.0, 81.0, 0.0));
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    final movement = character.characterMovement;
    expect(movement.maxStepHeight, greaterThanOrEqualTo(25.0));

    final modes = <int, MovementMode>{};
    for (var tick = 0; tick < 360; tick++) {
      movement.addInputVector(Vector3(1.0, 0.0, 0.0));
      world.tick(1 / 60);
      modes[tick] = movement.movementMode;
    }
    // Pressed against the steep face, the floor sweep hit the face
    // and the character stood on the ledge in `falling` forever.
    final airborneAtTheFace = [for (var t = 240; t < 360; t++) if (modes[t] != MovementMode.walking) '$t: ${modes[t]}'];
    expect(airborneAtTheFace, isEmpty, reason: 'walking every tick while pushing into the cliff');
    final at = character.actorLocation;
    expect(at.x, greaterThan(100.0), reason: 'the 25 cm ledge was stepped onto (x ${at.x})');
    expect(at.y - character.capsuleComponent.halfHeight, closeTo(25.0, 6.0), reason: 'standing on the ledge');
    expect(at.x + character.capsuleComponent.radius, lessThan(8.0 * _u + 30.0),
        reason: 'the 3 m face stopped it (x ${at.x})');
    expect(movement.isWalking, isTrue);
    world.cleanup();
  });

  test('a landscape loaded from its .lmas — what PIE and the generated level mount — gets the collider too', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_landscape_collision_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final data = _terrain((x, z) => 5.0);
    final asset = LuminaAsset(
      assetId: 'landscape_T',
      name: 'T',
      type: AssetType.landscape,
      rawPayload: data.toBytes(),
    );
    final path = '${tempDir.path}/T.lmas';
    File(path).writeAsBytesSync(asset.toProtoBufferBytes());

    final (world, collision) = _world();
    final landscape = LuminaLandscapeComponent(assetPath: path, location: Vector3(0.0, 100.0, 0.0));
    final actor = LuminaActor(root: landscape);
    world.persistentLevel.registerActor(actor);
    await landscape.ensureBuilt();
    expect(landscape.collisionComponent, isNotNull);
    expect(landscape.collisionComponent!.owner, same(actor));

    final hit = HitResult();
    expect(collision.raycast(Vector3(0.0, 5000.0, 0.0), Vector3(0.0, -1.0, 0.0), 10000.0, hit), isTrue);
    expect(hit.impactPoint.y, closeTo(100.0 + 5.0 * _u, 0.5));

    // Unregistering the actor takes the collider with it.
    world.persistentLevel.unregisterActor(actor);
    expect(collision.raycast(Vector3(0.0, 5000.0, 0.0), Vector3(0.0, -1.0, 0.0), 10000.0, hit), isFalse);
    world.cleanup();
  });
}
