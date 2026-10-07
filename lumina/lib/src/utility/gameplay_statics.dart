import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/pawn.dart';
import 'package:lumina/src/controller/controller.dart';
import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/utility/timer_manager.dart';

/// Stateless static facade providing one-line accessors for actor spawning, player lookup, queries, and damage.
abstract final class LuminaGameplayStatics {
  /// Spawns an actor into [world], setting its transform before enqueueing deferred creation in Phase 1 of next tick.
  static T spawnActor<T extends LuminaActor>(
    LuminaWorld world,
    T actor, {
    Vector3? location,
    Quaternion? rotation,
  }) {
    if (location != null) {
      actor.actorLocation = location;
    }
    if (rotation != null) {
      actor.actorRotation = rotation;
    }
    return world.spawnActor<T>(actor);
  }

  /// Schedules an actor for destruction in Phase 5 of the next tick.
  static void destroyActor(LuminaWorld world, LuminaActor actor) {
    world.destroyActor(actor);
  }

  /// Returns the player controller at [playerIndex] or null if absent.
  static LuminaPlayerController? getPlayerController(LuminaWorld world, {int playerIndex = 0}) {
    final fromPawns = world.actors
        .whereType<LuminaPawn>()
        .map((p) => p.controller)
        .whereType<LuminaPlayerController>()
        .toList();
    // Logged-in players whose pawn's spawn has not registered yet (the frame
    // they log in — a Level Blueprint's BeginPlay).
    for (final c in world.playerControllers) {
      if (!fromPawns.contains(c)) fromPawns.add(c);
    }
    if (playerIndex < fromPawns.length) {
      return fromPawns[playerIndex];
    }
    return world.actors.whereType<LuminaPlayerController>().elementAtOrNull(playerIndex);
  }

  /// Returns the pawn possessed by the player controller at [playerIndex] or null if absent.
  static LuminaPawn? getPlayerPawn(LuminaWorld world, {int playerIndex = 0}) {
    return getPlayerController(world, playerIndex: playerIndex)?.pawn;
  }

  /// Returns the viewpoint location of the player controller at [playerIndex] or null if absent.
  static Vector3? getPlayerViewLocation(LuminaWorld world, {int playerIndex = 0}) {
    return getPlayerController(world, playerIndex: playerIndex)?.getPlayerViewPoint().location;
  }

  /// Returns all active actors of type [T] across persistent and visible streaming levels in spawn order.
  static List<T> getAllActorsOfClass<T extends LuminaActor>(LuminaWorld world) {
    return world.actors.whereType<T>().toList();
  }

  /// Returns the first active actor of type [T] or null if none are present.
  static T? getActorOfClass<T extends LuminaActor>(LuminaWorld world) {
    return world.actors.whereType<T>().firstOrNull;
  }

  /// Returns all active actors of type [T] situated within [radius] distance from [origin].
  static List<T> getAllActorsWithinRadius<T extends LuminaActor>(
    LuminaWorld world,
    Vector3 origin,
    double radius,
  ) {
    if (radius < 0.0) return [];
    final rSq = radius * radius;
    return world.actors
        .whereType<T>()
        .where((a) => (a.actorLocation - origin).length2 <= rSq + 1e-9)
        .toList();
  }

  /// Applies standard damage to [target] and fires its [LuminaActor.onTakeAnyDamage] callback.
  static double applyDamage(
    LuminaActor target,
    double baseDamage, {
    LuminaController? instigator,
    LuminaActor? damageCauser,
    String damageType = '',
  }) {
    return target.takeDamage(baseDamage, instigator: instigator, damageCauser: damageCauser, damageType: damageType);
  }

  /// Applies radial damage with exponential or linear falloff to all damageable actors within [damageRadius].
  static void applyRadialDamage(
    LuminaWorld world,
    double baseDamage,
    Vector3 origin,
    double damageRadius, {
    double damageFalloff = 1.0,
    LuminaController? instigator,
    LuminaActor? damageCauser,
    double minimumDamage = 0.0,
    List<LuminaActor> ignoreActors = const [],
    String damageType = '',
  }) {
    if (damageRadius <= 0.0) return;

    // Snapshot target list to guarantee safe reentrancy if damage destroys actors
    final targets = getAllActorsWithinRadius<LuminaActor>(world, origin, damageRadius);

    for (final target in targets) {
      if (target == damageCauser || !target.bCanBeDamaged || ignoreActors.contains(target)) continue;

      final dist = (target.actorLocation - origin).length;
      final normDist = (dist / damageRadius).clamp(0.0, 1.0);
      final falloffFactor = math.pow(normDist, damageFalloff).toDouble();
      final actualDamage = baseDamage + (minimumDamage - baseDamage) * falloffFactor;

      applyDamage(target, actualDamage, instigator: instigator, damageCauser: damageCauser, damageType: damageType);
    }
  }

  /// Returns total accumulated game-time in seconds elapsed on [world].
  static double getTimeSeconds(LuminaWorld world) => world.timeSeconds;

  /// Retrieves the [LuminaTimerManager] world subsystem on [world] if registered.
  static LuminaTimerManager? getTimerManager(LuminaWorld world) =>
      world.getSubsystem<LuminaTimerManager>();
}
