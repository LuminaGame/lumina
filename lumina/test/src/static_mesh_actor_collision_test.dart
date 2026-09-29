// LuminaStaticMeshActor turns authored hulls into
// blocking convex collision, and a character walking into it is stopped.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A 100 cm cube standing on the ground, authored Z-up in cm (its base at
/// z = 0), as the level stores hulls.
const _cube = LuminaCollisionHull('UCX_Cube', [
  -50, -50, 0, 50, -50, 0, 50, 50, 0, -50, 50, 0, //
  -50, -50, 100, 50, -50, 100, 50, 50, 100, -50, 50, 100,
]);

/// A second, smaller element (e.g. the other piece of a split UCX_ mesh).
const _post = LuminaCollisionHull('UCX_Cube_2', [
  100, -10, 0, 120, -10, 0, 120, 10, 0, 100, 10, 0, //
  100, -10, 200, 120, -10, 200, 120, 10, 200, 100, 10, 200,
]);

void main() {
  group('LuminaCollisionHull', () {
    test('converts its authored Z-up points to the runtime frame through LuminaAxes', () {
      final p = _cube.runtimePoints;
      expect(_cube.pointCount, 8);
      expect(p, hasLength(8));
      // Authoring (x, y, z) → runtime (x, z, −y).
      expect(p[6].x, 50);
      expect(p[6].y, 100, reason: 'authored z (height) is runtime y');
      expect(p[6].z, -50, reason: 'authored +y is runtime −z');
    });
  });

  group('LuminaStaticMeshActor', () {
    test('one blocking, world-static convex component per hull', () {
      final actor = LuminaStaticMeshActor(meshAssetPath: 'contents/meshes/static/SM_Cube.lmas', collisionHulls: const [_cube, _post]);
      expect(actor.rootComponent, same(actor.meshComponent));
      expect(actor.collisionComponents, hasLength(2));
      for (final c in actor.collisionComponents) {
        expect(c.shapeType, CollisionShapeType.convex);
        expect(c.objectType, CollisionObjectType.worldStatic);
        expect(c.parentComponent, same(actor.meshComponent));
        expect(actor.components, contains(c));
      }
      final pawn = LuminaCapsuleComponent();
      CollisionProfile.applyPawn(pawn);
      expect(effectiveResponse(pawn, actor.collisionComponents.first), CollisionResponse.block);
      expect(actor.collisionComponents.first.getAABB().max.y, closeTo(100, 1e-9));
    });

    test('a mesh without hulls has no collision', () {
      final actor = LuminaStaticMeshActor(meshAssetPath: 'contents/meshes/static/SM_Counter_1.lmas');
      expect(actor.collisionComponents, isEmpty);
      expect(actor.components.whereType<LuminaCollisionComponent>(), isEmpty);
    });

    test('hull components carry the actor scale and follow actorScale', () {
      final actor = LuminaStaticMeshActor(
        meshAssetPath: 'contents/meshes/static/SM_Cube.lmas',
        scale: Vector3.all(2),
        collisionHulls: const [_cube],
      );
      final hull = actor.collisionComponents.single;
      expect(hull.relativeScale, Vector3.all(2));
      expect(hull.getAABB().max.y, closeTo(200, 1e-9));
      actor.actorScale = Vector3.all(3);
      expect(hull.relativeScale, Vector3.all(3));
      expect(hull.getAABB().max.y, closeTo(300, 1e-9));
      expect(actor.meshComponent.relativeScale, Vector3.all(3));
    });

    test('the hulls sit where the actor is, rotated with it', () {
      // Authored yaw 90° about Z at authored (500, 0, 0): runtime x = 500.
      final actor = LuminaStaticMeshActor(
        meshAssetPath: 'contents/meshes/static/SM_Cube.lmas',
        location: LuminaAxes.location([500, 0, 0]),
        rotation: LuminaAxes.rotation([0, 0, 90]),
        collisionHulls: const [_post],
      );
      final box = actor.collisionComponents.single.getAABB();
      // The post (authored x 100..120, y −10..10) turns onto the authored y
      // axis: runtime x stays within 500 ± 10.
      expect(box.min.x, closeTo(490, 1e-6));
      expect(box.max.x, closeTo(510, 1e-6));
      expect(box.max.y, closeTo(200, 1e-6));
    });
  });

  group('a character walking into an imported prop', () {
    ({LuminaWorld world, LuminaCharacter character}) yard({required bool hulls}) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.registerSubsystem(LuminaCollisionSubsystem());
      final floor = LuminaActor(location: Vector3(0, -50, 0));
      final floorBox = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = Vector3(3000, 50, 3000);
      CollisionProfile.applyBlockAll(floorBox);
      floorBox.objectType = CollisionObjectType.worldStatic;
      floor.addComponent(floorBox);
      world.persistentLevel.registerActor(floor);
      // The prop 300 cm ahead (runtime −Z is forward): its hull spans
      // z −350 … −250.
      world.persistentLevel.registerActor(LuminaStaticMeshActor(
        meshAssetPath: 'contents/meshes/static/SM_Cube.lmas',
        location: Vector3(0, 0, -300),
        collisionHulls: hulls ? const [_cube] : const [],
      ));
      final character = LuminaCharacter(location: Vector3(0, 80.2, 0));
      world.persistentLevel.registerActor(character);
      world.beginPlay();
      return (world: world, character: character);
    }

    test('is stopped by the hull face and never enters it', () {
      final (:world, :character) = yard(hulls: true);
      final face = -250.0;
      final radius = character.capsuleComponent.radius;
      var deepest = 0.0;
      for (var frame = 0; frame < 300; frame++) {
        character.characterMovement.addInputVector(Vector3(0, 0, -1));
        world.tick(1 / 60);
        deepest = deepest < character.actorLocation.z ? deepest : character.actorLocation.z;
      }
      final skin = character.characterMovement.skinWidth;
      expect(character.actorLocation.z, closeTo(face + radius + skin, 0.5), reason: 'stands against the face');
      expect(deepest, greaterThanOrEqualTo(face + radius - 0.5), reason: 'the capsule never went into the hull');
      expect(character.actorLocation.y, closeTo(80, 1), reason: 'still on the floor, not on top of the prop');
      world.cleanup();
    });

    test('walks through the same spot when the mesh has no hulls', () {
      final (:world, :character) = yard(hulls: false);
      for (var frame = 0; frame < 300; frame++) {
        character.characterMovement.addInputVector(Vector3(0, 0, -1));
        world.tick(1 / 60);
      }
      expect(character.actorLocation.z, lessThan(-1000));
      world.cleanup();
    });
  });
}
