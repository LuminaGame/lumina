import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Box / sphere / cylinder / cone / convex collision components
/// with collision presets and per-channel responses.
void main() {
  group('shape collision components', () {
    test('each component reports its shape type and its geometry answers overlaps and line traces', () {
      final subsystem = LuminaCollisionSubsystem();
      final sphere = LuminaSphereComponent(radius: 50);
      final box = LuminaBoxComponent(boxExtent: Vector3(50, 50, 50));
      final cylinder = LuminaCylinderComponent(radius: 50, halfHeight: 80);
      final cone = LuminaConeComponent(radius: 50, halfHeight: 80);
      final convex = LuminaConvexComponent(points: [
        for (var i = 0; i < 8; i++) Vector3(i & 1 == 0 ? -50 : 50, i & 2 == 0 ? -50 : 50, i & 4 == 0 ? -50 : 50),
      ]);
      expect(sphere.shapeType, CollisionShapeType.sphere);
      expect(box.shapeType, CollisionShapeType.box);
      expect(cylinder.shapeType, CollisionShapeType.cylinder);
      expect(cone.shapeType, CollisionShapeType.cone);
      expect(convex.shapeType, CollisionShapeType.convex);
      expect(cylinder.height, 160.0, reason: 'height stays twice the half height');
      expect(cone.apex.y, closeTo(80, 1e-9));

      // Each at its own spot, all block; a ray from 100 cm away along +X.
      final shapes = <LuminaCollisionComponent, double>{sphere: 0, box: 1000, cylinder: 2000, cone: 3000, convex: 4000};
      shapes.forEach((c, z) {
        c.location = Vector3(0, 0, z);
        subsystem.register(c);
      });
      final hit = HitResult();
      for (final entry in shapes.entries) {
        final c = entry.key;
        final start = Vector3(-100, 0, entry.value);
        expect(subsystem.lineTraceSingle(start: start, end: Vector3(100, 0, entry.value), out: hit), isTrue,
            reason: '${c.runtimeType} missed');
        expect(hit.component, same(c));
        expect(hit.distance, closeTo(50, 0.5), reason: '${c.runtimeType} surface is 50 cm from the ray start');
      }
      // The cone's apex: a ray straight down onto it hits at its tip.
      expect(subsystem.lineTraceSingle(start: Vector3(0, 200, 3000), end: Vector3(0, -200, 3000), out: hit), isTrue);
      expect(hit.component, same(cone));
      expect(hit.distance, closeTo(120, 0.5));
      // The cylinder's side: a ray missing the cap circle but inside the side.
      expect(subsystem.lineTraceSingle(start: Vector3(-100, 70, 2000), end: Vector3(100, 70, 2000), out: hit), isTrue);
      expect(hit.component, same(cylinder));

      // Overlap tests with a probe sphere: touching each shape, and not at 20 cm past it.
      final results = <LuminaCollisionComponent>[];
      for (final entry in shapes.entries) {
        // The cone is 50 wide only near its base (y −80); probe it at y −70.
        final y = entry.key == cone ? -70.0 : 0.0;
        subsystem.overlapTest(SphereShape(10), Matrix4.translation(Vector3(55, y, entry.value)), results);
        expect(results, [entry.key], reason: '${entry.key.runtimeType} touched at 55 cm');
        subsystem.overlapTest(SphereShape(10), Matrix4.translation(Vector3(75, y, entry.value)), results);
        expect(results, isEmpty, reason: '${entry.key.runtimeType} not touched at 75 cm');
      }
    });

    test('buildWireframe returns closed loops (every point is shared by at least two segments)', () {
      final components = <LuminaCollisionComponent>[
        LuminaBoxComponent(boxExtent: Vector3(30, 40, 50), rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.4)),
        LuminaSphereComponent(radius: 50),
        LuminaCylinderComponent(radius: 50, halfHeight: 80),
        LuminaConeComponent(radius: 50, halfHeight: 80),
        LuminaConvexComponent(points: [
          for (var i = 0; i < 8; i++) Vector3(i & 1 == 0 ? -50 : 50, i & 2 == 0 ? -50 : 50, i & 4 == 0 ? -50 : 50),
        ]),
        LuminaCapsuleComponent(radius: 40, halfHeight: 90),
      ];
      for (final c in components) {
        final pts = c is LuminaCapsuleComponent ? c.buildCapsuleWireframe() : c.buildWireframe();
        expect(pts.length, greaterThanOrEqualTo(24), reason: '${c.runtimeType}');
        expect(pts.length.isEven, isTrue, reason: '${c.runtimeType} segment pairs');
        String key(Vector3 v) => '${(v.x * 1000).round()},${(v.y * 1000).round()},${(v.z * 1000).round()}';
        final counts = <String, int>{};
        for (final p in pts) {
          counts[key(p)] = (counts[key(p)] ?? 0) + 1;
        }
        expect(counts.values.every((n) => n >= 2), isTrue, reason: '${c.runtimeType} has a dangling segment end');
        for (var i = 0; i < pts.length; i += 2) {
          expect((pts[i] - pts[i + 1]).length, greaterThan(1e-6), reason: '${c.runtimeType} zero-length segment');
        }
      }
      // The box's edges are the rotated component's own axes.
      final box = components.first as LuminaBoxComponent;
      final pts = box.buildWireframe();
      expect(pts.length, 24);
      final lengths = [for (var i = 0; i < 24; i += 2) (pts[i] - pts[i + 1]).length];
      expect(lengths.where((l) => (l - 60).abs() < 1e-6).length, 4);
      expect(lengths.where((l) => (l - 80).abs() < 1e-6).length, 4);
      expect(lengths.where((l) => (l - 100).abs() < 1e-6).length, 4);
    });
  });

  group('collision presets', () {
    test('applyPreset(trigger) sets the preset table; reads back; one edit makes it custom; noCollision disables', () {
      final box = LuminaBoxComponent();
      expect(box.preset, LuminaCollisionPreset.blockAllDynamic, reason: 'the default grid is Block All Dynamic');
      box.applyPreset(LuminaCollisionPreset.trigger);
      expect(box.objectType, CollisionObjectType.worldDynamic);
      expect(box.getResponse(CollisionObjectType.pawn), CollisionResponse.overlap);
      expect(box.getResponse(CollisionObjectType.worldDynamic), CollisionResponse.overlap);
      expect(box.getResponse(CollisionObjectType.worldStatic), CollisionResponse.ignore);
      expect(box.generateOverlapEvents, isTrue);
      expect(box.collisionEnabled, isTrue);
      expect(box.preset, LuminaCollisionPreset.trigger);

      box.setResponse(CollisionObjectType.pawn, CollisionResponse.block);
      expect(box.preset, LuminaCollisionPreset.custom);

      box.applyPreset(LuminaCollisionPreset.pawn);
      expect(box.objectType, CollisionObjectType.pawn);
      expect(box.responses.values.every((r) => r == CollisionResponse.block), isTrue);
      expect(box.preset, LuminaCollisionPreset.pawn);

      box.applyPreset(LuminaCollisionPreset.blockAll);
      expect(box.objectType, CollisionObjectType.worldStatic);
      expect(box.preset, LuminaCollisionPreset.blockAll);
      box.applyPreset(LuminaCollisionPreset.overlapAllDynamic);
      expect(box.objectType, CollisionObjectType.worldDynamic);
      expect(box.responses.values.every((r) => r == CollisionResponse.overlap), isTrue);
      box.applyPreset(LuminaCollisionPreset.overlapAll);
      expect(box.preset, LuminaCollisionPreset.overlapAll);

      box.applyPreset(LuminaCollisionPreset.noCollision);
      expect(box.collisionEnabled, isFalse);
      expect(box.preset, LuminaCollisionPreset.noCollision);
      final other = LuminaBoxComponent();
      expect(effectiveResponse(box, other), CollisionResponse.ignore);

      // Custom keeps whatever is there.
      box.applyPreset(LuminaCollisionPreset.blockAllDynamic);
      box.applyPreset(LuminaCollisionPreset.custom);
      expect(box.preset, LuminaCollisionPreset.blockAllDynamic);
      expect(LuminaCollisionPreset.parse('Block All Dynamic'), LuminaCollisionPreset.blockAllDynamic);
      expect(LuminaCollisionPreset.parse('trigger'), LuminaCollisionPreset.trigger);
      expect(LuminaCollisionPreset.parse('nope'), isNull);
      expect(LuminaCollisionPreset.overlapAllDynamic.displayName, 'OverlapAllDynamic');
    });

    test('collision JSON round-trips a preset and a custom grid', () {
      final sphere = LuminaSphereComponent()..applyPreset(LuminaCollisionPreset.trigger);
      final json = sphere.toCollisionJson();
      expect(json, {
        'preset': 'trigger',
        'objectType': 'worldDynamic',
        'responses': {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'overlap'},
        'generateOverlapEvents': true,
        'collisionEnabled': true,
      });
      final copy = LuminaSphereComponent()..applyCollisionJson(json);
      expect(copy.profile, sphere.profile);
      expect(copy.preset, LuminaCollisionPreset.trigger);

      // A preset alone fills the grid.
      final fromPreset = LuminaBoxComponent()..applyCollisionJson({'preset': 'OverlapAll'});
      expect(fromPreset.preset, LuminaCollisionPreset.overlapAll);
      expect(fromPreset.objectType, CollisionObjectType.worldStatic);

      // Custom: the explicit grid wins, and survives the round trip.
      sphere.setResponse(CollisionObjectType.worldStatic, CollisionResponse.block);
      sphere.generateOverlapEvents = false;
      final custom = sphere.toCollisionJson();
      expect(custom['preset'], 'custom');
      expect((custom['responses'] as Map)['worldStatic'], 'block');
      final copy2 = LuminaConeComponent()..applyCollisionJson(custom);
      expect(copy2.profile, sphere.profile);
      expect(copy2.generateOverlapEvents, isFalse);

      // Partial JSON keeps the rest.
      final partial = LuminaCylinderComponent()..applyCollisionJson({'collisionEnabled': false});
      expect(partial.collisionEnabled, isFalse);
      expect(partial.objectType, CollisionObjectType.worldDynamic);
      expect(LuminaCollisionProfile.hasCollisionKeys({'radius': 3.0}), isFalse);
      expect(LuminaCollisionProfile.hasCollisionKeys({'preset': 'Pawn'}), isTrue);
    });
  });

  group('a capsule pawn against shape colliders', () {
    /// A character (a Pawn) drifting along −Z at 300 cm/s with no gravity
    /// towards a box wall 300 cm ahead, for [seconds]; returns its final z.
    ({LuminaCharacter character, LuminaBoxComponent box, int begins, int ends, int pawnBegins, double z}) run(
        void Function(LuminaBoxComponent box) setUp,
        {double seconds = 2.0}) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
      final wall = LuminaActor(location: Vector3(0, 0, -300));
      final box = LuminaBoxComponent(boxExtent: Vector3(200, 100, 20));
      setUp(box);
      wall.addComponent(box);
      world.persistentLevel.registerActor(wall);
      final character = LuminaCharacter(location: Vector3(0, 0, 0));
      world.persistentLevel.registerActor(character);
      var begins = 0, ends = 0, pawnBegins = 0;
      box.onComponentBeginOverlap = (_, other) {
        if (identical(other, character.capsuleComponent)) begins++;
      };
      box.onComponentEndOverlap = (_, other) {
        if (identical(other, character.capsuleComponent)) ends++;
      };
      character.capsuleComponent.onComponentBeginOverlap = (_, other) {
        if (identical(other, box)) pawnBegins++;
      };
      world.beginPlay();
      expect(character.capsuleComponent.objectType, CollisionObjectType.pawn, reason: 'a character is a Pawn');
      final movement = character.characterMovement;
      movement.gravityScale = 0.0;
      movement.setMovementMode(MovementMode.falling);
      final ticks = (seconds * 60).round();
      for (var i = 0; i < ticks; i++) {
        movement.velocity.setValues(0, 0, -300);
        world.tick(1 / 60);
      }
      final z = character.actorLocation.z;
      world.cleanup();
      return (character: character, box: box, begins: begins, ends: ends, pawnBegins: pawnBegins, z: z);
    }

    test('a blockAll box stops the pawn', () {
      final r = run((box) => box.applyPreset(LuminaCollisionPreset.blockAll));
      expect(r.z, greaterThan(-300 + 20 + 40 - 2), reason: 'stopped at the wall face (z ${r.z})');
      expect(r.z, lessThan(-200), reason: 'walked up to the wall');
      expect(r.begins, 0);
    });

    test('an overlapAll box lets the pawn through and both components get begin / end overlap events', () {
      final r = run((box) => box.applyPreset(LuminaCollisionPreset.overlapAll));
      expect(r.z, lessThan(-400), reason: 'passed through (z ${r.z})');
      expect(r.begins, 1);
      expect(r.pawnBegins, 1);
      expect(r.ends, 1);
      expect(r.box.overlappingComponents, isEmpty);
    });

    test('a trigger box overlaps the pawn but ignores world static geometry', () {
      final r = run((box) => box.applyPreset(LuminaCollisionPreset.trigger));
      expect(r.z, lessThan(-400));
      expect(r.begins, 1);
      final floor = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..objectType = CollisionObjectType.worldStatic;
      expect(effectiveResponse(r.box, floor), CollisionResponse.ignore);
    });

    test('with generateOverlapEvents == false there are no events and still no block', () {
      final r = run((box) {
        box.applyPreset(LuminaCollisionPreset.overlapAll);
        box.generateOverlapEvents = false;
      });
      expect(r.z, lessThan(-400));
      expect(r.begins, 0);
      expect(r.pawnBegins, 0);
      expect(r.ends, 0);
    });

    test('Pawn → Overlap on a blockAll box lets the pawn through while a world dynamic sphere is still blocked', () {
      final r = run((box) {
        box.applyPreset(LuminaCollisionPreset.blockAll);
        box.setResponse(CollisionObjectType.pawn, CollisionResponse.overlap);
      });
      expect(r.z, lessThan(-400));
      final dynamic = LuminaSphereComponent();
      expect(effectiveResponse(r.box, dynamic), CollisionResponse.block);
      expect(effectiveResponse(r.box, r.character.capsuleComponent), CollisionResponse.overlap);
    });

    test('object-type filters on traces and overlap queries see the shape components', () {
      final subsystem = LuminaCollisionSubsystem();
      final trigger = LuminaSphereComponent(radius: 100)..applyPreset(LuminaCollisionPreset.trigger);
      final pillar = LuminaCylinderComponent(radius: 50, halfHeight: 100)..applyPreset(LuminaCollisionPreset.blockAll);
      trigger.location = Vector3(0, 0, -200);
      pillar.location = Vector3(0, 0, -600);
      subsystem.register(trigger);
      subsystem.register(pillar);
      final hit = HitResult();
      expect(
          subsystem.lineTraceSingle(
              start: Vector3.zero(), end: Vector3(0, 0, -1000), out: hit, objectTypes: {CollisionObjectType.worldStatic}),
          isTrue);
      expect(hit.component, same(pillar), reason: 'the trigger is world dynamic');
      expect(hit.distance, closeTo(550, 1));
      expect(
          subsystem.lineTraceSingle(
              start: Vector3.zero(), end: Vector3(0, 0, -1000), out: hit, objectTypes: {CollisionObjectType.worldDynamic}),
          isTrue);
      expect(hit.component, same(trigger));
      expect(math.max(hit.distance, 0), closeTo(100, 1));
    });
  });
}
