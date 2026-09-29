import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaGameplayStatics Tests', () {
    test('spawnActor sets transform and defers spawn to next tick', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final pawn = LuminaPawn();
      final spawned = LuminaGameplayStatics.spawnActor(
        world,
        pawn,
        location: Vector3(1.0, 2.0, 3.0),
        rotation: Quaternion.identity(),
      );

      expect(spawned, same(pawn));
      expect(pawn.actorLocation.x, equals(1.0));
      expect(pawn.actorLocation.y, equals(2.0));
      expect(pawn.actorLocation.z, equals(3.0));

      // Not yet in persistentLevel before tick
      expect(world.persistentLevel.actors.contains(pawn), isFalse);

      // Present after one tick
      world.tick(0.016);
      expect(world.persistentLevel.actors.contains(pawn), isTrue);
      expect(pawn.hasBegunPlay, isTrue);
    });

    test('getAllActorsOfClass filters by type across levels in spawn order', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final p1 = LuminaPawn();
      final a1 = LuminaActor();
      final p2 = LuminaPawn();
      final a2 = LuminaActor();

      LuminaGameplayStatics.spawnActor(world, p1);
      LuminaGameplayStatics.spawnActor(world, a1);
      LuminaGameplayStatics.spawnActor(world, p2);
      LuminaGameplayStatics.spawnActor(world, a2);

      world.tick(0.016);

      final pawns = LuminaGameplayStatics.getAllActorsOfClass<LuminaPawn>(world);
      expect(pawns.length, equals(2));
      expect(pawns[0], same(p1));
      expect(pawns[1], same(p2));

      final allActors = LuminaGameplayStatics.getAllActorsOfClass<LuminaActor>(world);
      expect(allActors.length, equals(4));

      final firstPawn = LuminaGameplayStatics.getActorOfClass<LuminaPawn>(world);
      expect(firstPawn, same(p1));

      final nonExistent = LuminaGameplayStatics.getActorOfClass<LuminaCharacter>(world);
      expect(nonExistent, isNull);
    });

    test('getAllActorsWithinRadius respects distance thresholds', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final aNear = LuminaActor(location: Vector3(3.0, 0.0, 0.0));
      final aExact = LuminaActor(location: Vector3(5.0, 0.0, 0.0));
      final aFar = LuminaActor(location: Vector3(7.0, 0.0, 0.0));

      LuminaGameplayStatics.spawnActor(world, aNear);
      LuminaGameplayStatics.spawnActor(world, aExact);
      LuminaGameplayStatics.spawnActor(world, aFar);

      world.tick(0.016);

      final found = LuminaGameplayStatics.getAllActorsWithinRadius<LuminaActor>(
        world,
        Vector3.zero(),
        5.0,
      );

      expect(found.length, equals(2));
      expect(found, contains(aNear));
      expect(found, contains(aExact));
      expect(found.contains(aFar), isFalse);
    });

    test('applyDamage invokes onTakeAnyDamage callback', () {
      final target = LuminaActor();
      double receivedDmg = 0.0;
      target.onTakeAnyDamage = (dmg, inst, causer) {
        receivedDmg = dmg;
      };

      final applied = LuminaGameplayStatics.applyDamage(target, 25.0);
      expect(applied, equals(25.0));
      expect(receivedDmg, equals(25.0));

      // When bCanBeDamaged = false
      target.bCanBeDamaged = false;
      receivedDmg = 0.0;
      final blocked = LuminaGameplayStatics.applyDamage(target, 25.0);
      expect(blocked, equals(0.0));
      expect(receivedDmg, equals(0.0));
    });

    test('applyRadialDamage calculates linear falloff correctly', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final aCenter = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final aMid = LuminaActor(location: Vector3(5.0, 0.0, 0.0));
      final aEdge = LuminaActor(location: Vector3(10.0, 0.0, 0.0));
      final aOutside = LuminaActor(location: Vector3(12.0, 0.0, 0.0));

      final damages = <LuminaActor, double>{};
      for (final a in [aCenter, aMid, aEdge, aOutside]) {
        a.onTakeAnyDamage = (dmg, inst, causer) {
          damages[a] = dmg;
        };
        LuminaGameplayStatics.spawnActor(world, a);
      }

      world.tick(0.016);

      LuminaGameplayStatics.applyRadialDamage(
        world,
        100.0,
        Vector3.zero(),
        10.0,
        minimumDamage: 10.0,
        damageFalloff: 1.0,
      );

      expect(damages[aCenter], closeTo(100.0, 1e-5));
      expect(damages[aMid], closeTo(55.0, 1e-5));
      expect(damages[aEdge], closeTo(10.0, 1e-5));
      expect(damages.containsKey(aOutside), isFalse);
    });

    test('applyRadialDamage calculates quadratic falloff correctly', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final aMid = LuminaActor(location: Vector3(5.0, 0.0, 0.0));
      double receivedDmg = 0.0;
      aMid.onTakeAnyDamage = (dmg, inst, causer) => receivedDmg = dmg;
      LuminaGameplayStatics.spawnActor(world, aMid);

      world.tick(0.016);

      LuminaGameplayStatics.applyRadialDamage(
        world,
        100.0,
        Vector3.zero(),
        10.0,
        minimumDamage: 10.0,
        damageFalloff: 2.0,
      );

      // (5/10)^2 = 0.25 -> 100 + (10 - 100)*0.25 = 77.5
      expect(receivedDmg, closeTo(77.5, 1e-5));
    });

    test('applyRadialDamage skips damageCauser', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final causer = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final victim = LuminaActor(location: Vector3(2.0, 0.0, 0.0));

      bool causerDamaged = false;
      bool victimDamaged = false;

      causer.onTakeAnyDamage = (dmg, inst, c) => causerDamaged = true;
      victim.onTakeAnyDamage = (dmg, inst, c) => victimDamaged = true;

      LuminaGameplayStatics.spawnActor(world, causer);
      LuminaGameplayStatics.spawnActor(world, victim);

      world.tick(0.016);

      LuminaGameplayStatics.applyRadialDamage(
        world,
        50.0,
        Vector3.zero(),
        5.0,
        damageCauser: causer,
      );

      expect(causerDamaged, isFalse);
      expect(victimDamaged, isTrue);
    });

    test('destroyActor defers destruction and actor is removed after tick', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final actor = LuminaActor();
      LuminaGameplayStatics.spawnActor(world, actor);
      world.tick(0.016);
      expect(world.actors.contains(actor), isTrue);

      LuminaGameplayStatics.destroyActor(world, actor);
      expect(world.actors.contains(actor), isTrue);

      world.tick(0.016);
      expect(world.actors.contains(actor), isFalse);
      expect(LuminaGameplayStatics.getAllActorsOfClass<LuminaActor>(world).contains(actor), isFalse);
    });
  });
}
