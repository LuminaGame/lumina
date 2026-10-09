part of '../world.dart';

/// The phases [LuminaWorld.step] runs every frame, in order, and the
/// deferred spawn / destroy commands that close it.
extension _LuminaWorldTickPhases on LuminaWorld {
  void _expireDebugRecords() {
    final now = _realTimeSeconds;
    debugShapes.removeWhere((s) => s.expiresAt <= now);
    screenMessages.removeWhere((_, m) => m.expiresAt <= now);
  }

  void _prePhysicsTick(double deltaTime) {
    onPhaseExecuted?.call('prePhysics');
    buildOwner?.flushBuild();
  }

  void _physicsAndSubsystemUpdate(double deltaTime) {
    onPhaseExecuted?.call('subsystemTick');
    
    if (worldType.runsGameplay) {
      gameState?.tick(deltaTime);
    }

    if (worldType.ticksSubsystems) {
      subsystems.notifyTick(deltaTime);
    }
  }

  void _actorTick(double deltaTime) {
    if (!worldType.runsGameplay) return;

    // An actor registered into the persistent level after the world began
    // play (a pawn added to a running scene, a declarative rebuild,
    // a save-game factory) begins play here, before any actor ticks, as a
    // streaming level's actors do below; spawnActor / spawnActorImmediately
    // begin theirs on spawn.
    final persistentActors = persistentLevel.actors;
    for (final actor in persistentActors) {
      if (actor.hasBegunPlay || actor.isPendingDestroy) continue;
      if (!actor.isInitialized) actor.onInitialize();
      actor.onBeginPlay();
    }
    for (final actor in persistentActors) {
      if (actor.isInitialized && actor.hasBegunPlay) {
        actor.onTick(deltaTime);
      }
    }
    for (final level in streamingLevels) {
      if (level.state == LevelState.visible) {
        level.notifyLevelLoaded();
        for (final actor in level.actors) {
          if (!actor.isInitialized) actor.onInitialize();
          if (!actor.hasBegunPlay) actor.onBeginPlay();
          if (actor.isInitialized && actor.hasBegunPlay) {
            actor.onTick(deltaTime);
          }
        }
      }
    }

    if (killZ != null) {
      final kz = killZ!;
      final toKill = <LuminaActor>[];
      for (final actor in persistentLevel.actors) {
        if (actor.actorLocation.y < kz) {
          toKill.add(actor);
        }
      }
      for (final level in streamingLevels) {
        if (level.state == LevelState.visible) {
          for (final actor in level.actors) {
            if (actor.actorLocation.y < kz) {
              toKill.add(actor);
            }
          }
        }
      }
      for (final actor in toKill) {
        if (actor.bCanBeDamaged) {
          actor.takeDamage(1e9);
        }
        destroyActor(actor);
        onActorFellOutOfWorld?.call(actor);
      }
    }
  }

  void _postPhysicsRenderPrep(double deltaTime) {
    onPhaseExecuted?.call('renderPrep');
    if (worldType.runsRenderPrep) {
      for (final actor in persistentLevel.actors) {
        actor.onRenderPrep(this);
        onRenderPrepCallback?.call(actor);
      }
      for (final level in streamingLevels) {
        if (level.state == LevelState.visible) {
          for (final actor in level.actors) {
            actor.onRenderPrep(this);
            onRenderPrepCallback?.call(actor);
          }
        }
      }
      _syncViewCamera();
      _applyPostProcessBlend();
    }
  }

  void _executeDeferredCommands() {
    onPhaseExecuted?.call('deferredCommands');

    // 1. Swap and drain spawn buffer
    final toSpawn = _activeSpawnBuffer;
    _activeSpawnBuffer = (_activeSpawnBuffer == _pendingSpawnA) ? _pendingSpawnB : _pendingSpawnA;

    // Drain a snapshot so a throwing actor can never replay the buffer on the
    // next swap; the level owns registration (LuminaLevel.registerActor calls
    // onRegister when it is attached to a world), the world only fills in
    // for detached levels.
    final spawnBatch = List.of(toSpawn);
    toSpawn.clear();
    Object? firstError;
    StackTrace? firstStack;
    for (final item in spawnBatch) {
      final actor = item.actor;
      final targetLevel = item.targetLevel;
      try {
        targetLevel.registerActor(actor);
        if (!actor.isRegistered) {
          actor.onRegister(this);
        }
        actor.onInitialize();
        if (worldType.runsGameplay) {
          actor.onBeginPlay();
        }
      } catch (e, st) {
        // Keep spawning the rest of the batch; surface the first failure once.
        firstError ??= StateError('spawnActor failed for ${actor.runtimeType}: $e');
        firstStack ??= st;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }

    // 2. Swap and drain destroy buffer
    final toDestroy = _activeDestroyBuffer;
    _activeDestroyBuffer = (_activeDestroyBuffer == _pendingDestroyA) ? _pendingDestroyB : _pendingDestroyA;

    for (final actor in toDestroy) {
      if (actor.owningLevel != null) {
        actor.owningLevel!.unregisterActor(actor);
      } else {
        persistentLevel.unregisterActor(actor);
      }
    }
    toDestroy.clear();
  }
}

class _PendingSpawnItem {
  final LuminaActor actor;
  final LuminaLevel targetLevel;
  _PendingSpawnItem(this.actor, this.targetLevel);
}
