import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

LuminaPawn _createPawn({Vector3? location}) {
  return LuminaPawn(
    location: location,
    root: LuminaCollisionComponent(
      shapeType: CollisionShapeType.box,
    )..boxExtent.setFrom(Vector3(0.4, 0.4, 0.4)),
  );
}

void main() {
  group('Gameplay Volumes Tests', () {
    test('LuminaTriggerVolume fires begin and end overlap on entry and exit', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final trigger = LuminaTriggerVolume(extent: Vector3(1.0, 1.0, 1.0));
      final pawn = _createPawn(location: Vector3(0.5, 0.0, 0.0));

      int beginCount = 0;
      int endCount = 0;
      trigger.onActorBeginOverlap = (a) => beginCount++;
      trigger.onActorEndOverlap = (a) => endCount++;

      world.persistentLevel.registerActor(trigger);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();

      // Overlap detected on tick
      world.tick(0.016);
      expect(beginCount, equals(1));
      expect(trigger.overlappingActors, contains(pawn));

      // Staying inside doesn't repeat begin overlap
      for (int i = 0; i < 10; i++) {
        world.tick(0.016);
      }
      expect(beginCount, equals(1));
      expect(endCount, equals(0));

      // Pawn exits to (5, 0, 0)
      pawn.actorLocation = Vector3(5.0, 0.0, 0.0);
      world.tick(0.016);

      expect(endCount, equals(1));
      expect(trigger.overlappingActors.isEmpty, isTrue);
    });

    test('encompassesPoint tests oriented bounding box accurately', () {
      final volume = LuminaVolume(extent: Vector3(1.0, 1.0, 1.0));
      expect(volume.encompassesPoint(Vector3(0.9, 0.9, 0.9)), isTrue);
      expect(volume.encompassesPoint(Vector3(1.1, 0.0, 0.0)), isFalse);

      // Rotate volume 45 degrees around Y
      volume.actorRotation = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi / 4.0);
      // Along the rotated corner, a point at (1.2, 0, 0) is now inside
      expect(volume.encompassesPoint(Vector3(1.2, 0.0, 0.0)), isTrue);
    });

    test('triggerOnceOnly unsubscribes after first trigger', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final trigger = LuminaTriggerVolume(
        extent: Vector3(1.0, 1.0, 1.0),
        triggerOnceOnly: true,
      );
      final pawn = _createPawn(location: Vector3(0.0, 0.0, 0.0));

      int beginCount = 0;
      trigger.onActorBeginOverlap = (a) => beginCount++;

      world.persistentLevel.registerActor(trigger);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();

      world.tick(0.016);
      expect(beginCount, equals(1));

      // Exit
      pawn.actorLocation = Vector3(5.0, 0.0, 0.0);
      world.tick(0.016);

      // Re-enter
      pawn.actorLocation = Vector3(0.0, 0.0, 0.0);
      world.tick(0.016);

      expect(beginCount, equals(1));
    });

    test('actorFilter ignores non-matching actors', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final trigger = LuminaTriggerVolume(
        extent: Vector3(1.0, 1.0, 1.0),
        actorFilter: (a) => a is LuminaPawn,
      );
      final plainActor = LuminaActor(
        location: Vector3(0.0, 0.0, 0.0),
        root: LuminaCollisionComponent(
          shapeType: CollisionShapeType.box,
        )..boxExtent.setFrom(Vector3(0.4, 0.4, 0.4)),
      );

      int beginCount = 0;
      trigger.onActorBeginOverlap = (a) => beginCount++;

      world.persistentLevel.registerActor(trigger);
      world.persistentLevel.registerActor(plainActor);
      world.beginPlay();

      world.tick(0.016);
      expect(beginCount, equals(0));
      expect(trigger.overlappingActors.isEmpty, isTrue);

      final pawn = _createPawn(location: Vector3(0.0, 0.0, 0.0));
      world.persistentLevel.registerActor(pawn);
      pawn.onInitialize();
      pawn.onBeginPlay();

      world.tick(0.016);
      expect(beginCount, equals(1));
      expect(trigger.overlappingActors, contains(pawn));
    });

    test('LuminaKillZVolume damages and destroys entering pawn and ignores volumes', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final killVolume = LuminaKillZVolume(extent: Vector3(2.0, 2.0, 2.0));
      final triggerVolume = LuminaTriggerVolume(extent: Vector3(1.0, 1.0, 1.0));
      final pawn = _createPawn(location: Vector3(0.0, 0.0, 0.0));

      double damageReceived = 0.0;
      pawn.onTakeAnyDamage = (d, i, c) => damageReceived = d;

      bool killed = false;
      killVolume.onActorKilled = (v) => killed = true;

      world.persistentLevel.registerActor(killVolume);
      world.persistentLevel.registerActor(triggerVolume);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();

      world.tick(0.016);

      expect(damageReceived, greaterThanOrEqualTo(1e9));
      expect(killed, isTrue);

      // Overlapping trigger volume is not destroyed
      expect(world.actors.contains(triggerVolume), isTrue);

      // Pawn is destroyed after Phase 5
      world.tick(0.016);
      expect(world.actors.contains(pawn), isFalse);
    });

    test('world.killZ destroys actors falling below threshold', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.killZ = -100.0;

      LuminaActor? killedActor;
      world.onActorFellOutOfWorld = (v) => killedActor = v;

      final actor = LuminaActor(location: Vector3(0.0, -101.0, 0.0));
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      world.tick(0.016);
      expect(killedActor, same(actor));

      world.tick(0.016);
      expect(world.actors.contains(actor), isFalse);
    });

    test('Destroying trigger volume removes it from collisions and fires no callbacks', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final trigger = LuminaTriggerVolume(extent: Vector3(1.0, 1.0, 1.0));
      final pawn = _createPawn(location: Vector3(5.0, 0.0, 0.0));

      int beginCount = 0;
      trigger.onActorBeginOverlap = (a) => beginCount++;

      world.persistentLevel.registerActor(trigger);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();

      world.destroyActor(trigger);
      world.tick(0.016);

      // Pawn enters where the trigger used to be
      pawn.actorLocation = Vector3(0.0, 0.0, 0.0);
      world.tick(0.016);

      expect(beginCount, equals(0));
    });
  });
}
