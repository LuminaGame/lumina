// Authored box / sphere / capsule simple collision on a
// LuminaStaticMeshActor, next to its convex hulls.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void _expectVec(Vector3 actual, Vector3 expected, {double tol = 1e-9, String? reason}) {
  expect(actual.x, closeTo(expected.x, tol), reason: reason);
  expect(actual.y, closeTo(expected.y, tol), reason: reason);
  expect(actual.z, closeTo(expected.z, tol), reason: reason);
}

const _box = LuminaCollisionPrimitive.box(center: [10, 20, 30], halfExtents: [50, 40, 30]);
const _sphere = LuminaCollisionPrimitive.sphere(center: [0, 0, 25], radius: 25);
const _hull = LuminaCollisionHull('UCX_Post', [
  100, -10, 0, 120, -10, 0, 120, 10, 0, 100, 10, 0, //
  100, -10, 200, 120, -10, 200, 120, 10, 200, 100, 10, 200,
]);

LuminaStaticMeshActor _actor({List<LuminaCollisionPrimitive> primitives = const [], List<LuminaCollisionHull> hulls = const [], Vector3? scale}) =>
    LuminaStaticMeshActor(
      meshAssetPath: 'contents/meshes/static/SM_Prop.lmas',
      scale: scale,
      collisionHulls: hulls,
      collisionPrimitives: primitives,
    );

void main() {
  group('LuminaCollisionPrimitive (authored cm, Z up)', () {
    test('a box lands in runtime axes: centre (x, z, −y), half extents (x, z, y)', () {
      final c = _actor(primitives: const [_box]).collisionComponents.single;
      expect(c.shapeType, CollisionShapeType.box);
      _expectVec(c.relativeLocation, Vector3(10, 30, -20));
      _expectVec(c.boxExtent, Vector3(50, 30, 40));
      _expectVec(c.getAABB().min, Vector3(-40, 0, -60));
      _expectVec(c.getAABB().max, Vector3(60, 60, 20));
    });

    test('a sphere keeps its radius at its runtime centre', () {
      final c = _actor(primitives: const [_sphere]).collisionComponents.single;
      expect(c.shapeType, CollisionShapeType.sphere);
      expect(c.radius, 25);
      _expectVec(c.worldLocation, Vector3(0, 25, 0));
    });

    test('a capsule\'s half length is the cylinder\'s; its axis follows the authored axis', () {
      LuminaCollisionComponent capsule(String axis) => _actor(primitives: [
            LuminaCollisionPrimitive.capsule(center: const [0, 0, 70], radius: 20, halfLength: 30, axis: axis),
          ]).collisionComponents.single;
      final z = capsule('Z');
      expect(z.shapeType, CollisionShapeType.capsule);
      expect(z.radius, 20);
      expect(z.halfHeight, 50, reason: 'lumina half height includes the caps: 30 + 20');
      _expectVec(z.upVector, Vector3(0, 1, 0));
      _expectVec(z.getAABB().min, Vector3(-20, 20, -20));
      _expectVec(z.getAABB().max, Vector3(20, 120, 20));
      expect(capsule('X').upVector.x.abs(), closeTo(1, 1e-9), reason: 'authored X is runtime X');
      expect(capsule('Y').upVector.z.abs(), closeTo(1, 1e-9), reason: 'authored Y is runtime −Z');
      expect(capsule('Y').getAABB().max.z - capsule('Y').getAABB().min.z, closeTo(100, 1e-9));
    });
  });

  group('LuminaStaticMeshActor with authored shapes', () {
    test('hulls and primitives side by side, all world-static and blocking', () {
      final actor = _actor(hulls: const [_hull], primitives: const [_box, _sphere]);
      expect(actor.collisionComponents.map((c) => c.shapeType),
          [CollisionShapeType.convex, CollisionShapeType.box, CollisionShapeType.sphere]);
      final pawn = LuminaCapsuleComponent();
      CollisionProfile.applyPawn(pawn);
      for (final c in actor.collisionComponents) {
        expect(c.objectType, CollisionObjectType.worldStatic);
        expect(effectiveResponse(pawn, c), CollisionResponse.block);
        expect(actor.components, contains(c));
      }
    });

    test('the actor scale sizes and places the shapes, per axis, and follows actorScale', () {
      final actor = _actor(primitives: const [_box, _sphere], scale: Vector3.all(2));
      final box = actor.collisionComponents[0];
      final sphere = actor.collisionComponents[1];
      _expectVec(box.boxExtent, Vector3(100, 60, 80));
      _expectVec(box.relativeLocation, Vector3(20, 60, -40));
      expect(sphere.radius, 50);

      // Authored (1, 1, 3): three times taller.
      actor.actorScale = LuminaAxes.scale([1, 1, 3]);
      _expectVec(box.boxExtent, Vector3(50, 90, 40));
      _expectVec(box.relativeLocation, Vector3(10, 90, -20));
      expect(sphere.radius, 25, reason: 'a sphere takes the smallest scale');
      _expectVec(sphere.relativeLocation, Vector3(0, 75, 0));
    });

    test('a capsule scales its radius by the cross axes and its length by its own', () {
      final actor = _actor(primitives: const [
        LuminaCollisionPrimitive.capsule(center: [0, 0, 70], radius: 20, halfLength: 30),
      ], scale: LuminaAxes.scale([2, 3, 4]));
      final c = actor.collisionComponents.single;
      expect(c.radius, 40, reason: 'min(2, 3) × 20');
      expect(c.halfHeight, 4 * 30 + 40);
      _expectVec(c.relativeLocation, Vector3(0, 280, 0));
    });

    test('rotated with the actor', () {
      final actor = LuminaStaticMeshActor(
        meshAssetPath: 'contents/meshes/static/SM_Prop.lmas',
        location: LuminaAxes.location([500, 0, 0]),
        rotation: LuminaAxes.rotation([0, 0, 90]),
        collisionPrimitives: const [_box],
      );
      final box = actor.collisionComponents.single.getAABB();
      // Half extents (50, 40) in x/y turn to (40, 50) under a 90° yaw.
      expect(box.max.x - box.min.x, closeTo(80, 1e-6));
      expect(box.max.z - box.min.z, closeTo(100, 1e-6));
      expect(box.max.y, closeTo(60, 1e-6));
    });
  });

  group('a character walking into an authored box', () {
    for (final withBox in [true, false]) {
      test(withBox ? 'is stopped at its face and never enters it' : 'walks through when the prop has no simple collision', () {
        final world = LuminaWorld(worldType: LuminaWorldType.game);
        world.registerSubsystem(LuminaCollisionSubsystem());
        final floor = LuminaActor(location: Vector3(0, -50, 0));
        final floorBox = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = Vector3(3000, 50, 3000);
        CollisionProfile.applyBlockAll(floorBox);
        floor.addComponent(floorBox);
        world.persistentLevel.registerActor(floor);
        // A 2 m wide, 1 m deep, 1 m tall box, 3 m ahead (runtime −Z).
        const box = LuminaCollisionPrimitive.box(center: [0, 0, 50], halfExtents: [100, 50, 50]);
        final prop = LuminaStaticMeshActor(
          meshAssetPath: 'contents/meshes/static/SM_Counter_1.lmas',
          location: LuminaAxes.location([0, 300, 0]),
          collisionPrimitives: withBox ? const [box] : const [],
        );
        world.persistentLevel.registerActor(prop);
        final character = LuminaCharacter(location: Vector3(0, 80.2, 0));
        world.persistentLevel.registerActor(character);
        world.beginPlay();
        final r = character.capsuleComponent.radius;
        var deepest = 0.0;
        for (var frame = 0; frame < 300; frame++) {
          character.characterMovement.addInputVector(Vector3(0, 0, -1));
          world.tick(1 / 60);
          deepest = math.min(deepest, character.actorLocation.z);
        }
        if (withBox) {
          // The box's near face is at runtime z = −(300 − 50) = −250.
          expect(character.actorLocation.z, closeTo(-250 + r + character.characterMovement.skinWidth, 0.5));
          expect(deepest, greaterThanOrEqualTo(-250 + r - 0.5));
        } else {
          expect(character.actorLocation.z, lessThan(-1000));
        }
        world.cleanup();
      });
    }
  });
}
