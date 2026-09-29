import 'dart:math' as math;

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A game world with collision and physics, a static floor whose top is at
/// runtime y = 0 (authoring Z = 0), ticked at 60 Hz.
class PhysicsWorld {
  PhysicsWorld({LuminaPhysicalMaterial? floorMaterial, double floorSize = 6000}) {
    world = LuminaWorld(worldType: LuminaWorldType.game);
    collision = world.registerSubsystem(LuminaCollisionSubsystem());
    physics = world.registerSubsystem(LuminaPhysicsSubsystem());
    floor = LuminaBoxComponent(location: Vector3(0, -10, 0), boxExtent: Vector3(floorSize / 2, 10, floorSize / 2))
      ..objectType = CollisionObjectType.worldStatic
      ..physicalMaterial = floorMaterial;
    world.persistentLevel.registerActor(LuminaActor(root: floor));
  }

  late final LuminaWorld world;
  late final LuminaCollisionSubsystem collision;
  late final LuminaPhysicsSubsystem physics;
  late final LuminaBoxComponent floor;

  /// A simulating box actor (its root), [halfExtents] cm, [massKg] kg.
  LuminaBoxComponent box(Vector3 location, Vector3 halfExtents,
      {double massKg = 10, Quaternion? rotation, LuminaPhysicalMaterial? material, bool spawn = false}) {
    final box = LuminaBoxComponent(location: location, rotation: rotation, boxExtent: halfExtents)
      ..simulatePhysics = true
      ..overrideMass = true
      ..massKg = massKg
      ..physicalMaterial = material;
    final actor = LuminaActor(root: box);
    if (spawn) {
      world.spawnActorImmediately(actor);
    } else {
      world.persistentLevel.registerActor(actor);
    }
    return box;
  }

  /// A simulating sphere actor.
  LuminaSphereComponent sphere(Vector3 location, double radius, {double massKg = 5, LuminaPhysicalMaterial? material}) {
    final sphere = LuminaSphereComponent(location: location, radius: radius)
      ..simulatePhysics = true
      ..overrideMass = true
      ..massKg = massKg
      ..physicalMaterial = material;
    world.persistentLevel.registerActor(LuminaActor(root: sphere));
    return sphere;
  }

  /// Where [slope] puts its surface: well above the floor.
  static final Vector3 slopeOrigin = Vector3(0, 3000, 0);

  /// A static slope: a large box tilted [degrees] about the runtime z axis
  /// (downhill is −x), its top surface through [slopeOrigin].
  LuminaBoxComponent slope(double degrees, {LuminaPhysicalMaterial? material}) {
    final rotation = Quaternion.axisAngle(Vector3(0, 0, 1), degrees * math.pi / 180);
    final up = Vector3(0, 1, 0)..applyQuaternion(rotation);
    final slope = LuminaBoxComponent(location: slopeOrigin + up * -10.0, rotation: rotation, boxExtent: Vector3(3000, 10, 1000))
      ..objectType = CollisionObjectType.worldStatic
      ..physicalMaterial = material;
    world.persistentLevel.registerActor(LuminaActor(root: slope));
    return slope;
  }

  void begin() => world.beginPlay();

  /// Ticks [seconds] at 60 Hz, calling [each] after every frame.
  void run(double seconds, [void Function(double t)? each]) {
    final frames = (seconds * 60).round();
    for (var i = 0; i < frames; i++) {
      world.tick(1 / 60);
      each?.call(i / 60 + 1 / 60);
    }
  }

  void dispose() => world.cleanup();
}

/// The angle (degrees) between [q]'s up axis and world up.
double tiltDegrees(Quaternion q) {
  final up = Vector3(0, 1, 0)..applyQuaternion(q);
  return math.acos(up.y.clamp(-1.0, 1.0)) * 180 / math.pi;
}
