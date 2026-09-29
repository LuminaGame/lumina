import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class PhaseProbeSubsystem extends LuminaWorldSubsystem {
  final List<String> eventLog;
  PhaseProbeSubsystem(this.eventLog);

  @override
  void onWorldTick(double deltaTime) {
    eventLog.add('subsystem:onWorldTick');
  }

  @override
  void onWorldShutdown() {
    eventLog.add('subsystemShutdown');
    super.onWorldShutdown();
  }
}

class PipelineProbeActor extends LuminaActor {
  final String name;
  final List<String> eventLog;
  int tickCount = 0;
  int beginPlayCount = 0;
  void Function(LuminaWorld world)? onTickAction;

  PipelineProbeActor(this.name, this.eventLog, {super.location});

  @override
  void onRegister(LuminaWorld world) {
    super.onRegister(world);
    eventLog.add('onRegister:$name');
  }

  @override
  void onInitialize() {
    super.onInitialize();
    eventLog.add('onInitialize:$name');
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    beginPlayCount++;
    eventLog.add('onBeginPlay:$name');
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    eventLog.add('onTick:$name');
    if (world != null && onTickAction != null) {
      onTickAction!(world!);
    }
  }

  @override
  void onUnregister() {
    eventLog.add('onUnregister:$name');
    super.onUnregister();
  }
}

class SpawnOnBeginPlayActor extends LuminaActor {
  final PipelineProbeActor actorToSpawn;
  final List<String> eventLog;

  SpawnOnBeginPlayActor(this.actorToSpawn, this.eventLog);

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    eventLog.add('onBeginPlay:Spawner');
    world?.spawnActor(actorToSpawn);
  }
}

void main() {
  group('World Tick Pipeline Tests (Task 01)', () {
    test('5-stage phase order probe executes in exact deterministic order for 3 frames', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.onPhaseExecuted = (phase) => eventLog.add(phase);

      final subsystem = PhaseProbeSubsystem(eventLog);
      world.subsystems.registerSubsystem<PhaseProbeSubsystem>(subsystem, world);

      final actor = PipelineProbeActor('A1', eventLog);
      world.persistentLevel.registerActor(actor);

      world.onRenderPrepCallback = (a) => eventLog.add('renderPrep:${a.runtimeType}');

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        eventLog.clear();
        world.tick(1.0 / 60.0);

        expect(eventLog, equals([
          'prePhysics',
          'subsystemTick',
          'subsystem:onWorldTick',
          'onTick:A1',
          'renderPrep',
          'renderPrep:PipelineProbeActor',
          'deferredCommands',
        ]));
      }
    });

    test('spawnActor before frame N ticks receives onRegister->onInitialize->onBeginPlay in phase 5, first onTick at N+1', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.onPhaseExecuted = (phase) => eventLog.add(phase);
      world.beginPlay();

      final newActor = PipelineProbeActor('SpawnedActor', eventLog);
      world.spawnActor(newActor);

      // Frame 1
      world.tick(1.0 / 60.0);

      expect(newActor.tickCount, equals(0));
      expect(eventLog, contains('onRegister:SpawnedActor'));
      expect(eventLog, contains('onInitialize:SpawnedActor'));
      expect(eventLog, contains('onBeginPlay:SpawnedActor'));

      final regIdx = eventLog.indexOf('onRegister:SpawnedActor');
      final initIdx = eventLog.indexOf('onInitialize:SpawnedActor');
      final beginIdx = eventLog.indexOf('onBeginPlay:SpawnedActor');
      final defIdx = eventLog.indexOf('deferredCommands');

      expect(regIdx, greaterThanOrEqualTo(defIdx));
      expect(initIdx, greaterThan(regIdx));
      expect(beginIdx, greaterThan(initIdx));

      // Frame 2
      eventLog.clear();
      world.tick(1.0 / 60.0);
      expect(newActor.tickCount, equals(1));
      expect(eventLog, contains('onTick:SpawnedActor'));
    });

    // An actor registered into the persistent level after the world
    // began play (a scene built before its pawn, a declarative rebuild, a
    // save-game factory) begins play like a spawned one, instead of never.
    test('an actor registered after beginPlay initializes and begins play once on the next tick, before its first onTick', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final lateActor = PipelineProbeActor('Late', eventLog);
      world.persistentLevel.registerActor(lateActor);
      world.beginPlay(); // a second beginPlay is a no-op and must not be needed
      expect(lateActor.hasBegunPlay, isFalse, reason: 'registration alone does not begin play');

      world.tick(1.0 / 60.0);
      expect(lateActor.hasBegunPlay, isTrue);
      expect(lateActor.beginPlayCount, 1);
      expect(lateActor.tickCount, 1, reason: 'it ticks in the frame it began play');
      expect(eventLog.indexOf('onInitialize:Late'), lessThan(eventLog.indexOf('onBeginPlay:Late')));
      expect(eventLog.indexOf('onBeginPlay:Late'), lessThan(eventLog.indexOf('onTick:Late')));

      for (var i = 0; i < 5; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(lateActor.beginPlayCount, 1);
      expect(lateActor.tickCount, 6);
    });

    test('an actor registered after beginPlay in an editor world neither begins play nor ticks', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.editor);
      world.beginPlay();
      final lateActor = PipelineProbeActor('Late', eventLog);
      world.persistentLevel.registerActor(lateActor);
      world.tick(1.0 / 60.0);
      expect(lateActor.hasBegunPlay, isFalse);
      expect(lateActor.tickCount, 0);
    });

    test('destroyActor called during onTick lets victim complete frame N, fires onUnregister in phase 5, absent at N+1', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.onPhaseExecuted = (phase) => eventLog.add(phase);

      final victim = PipelineProbeActor('Victim', eventLog);
      final killer = PipelineProbeActor('Killer', eventLog);

      world.persistentLevel.registerActor(killer);
      world.persistentLevel.registerActor(victim);

      killer.onTickAction = (w) {
        w.destroyActor(victim);
      };

      world.beginPlay();

      // Frame 1
      world.tick(1.0 / 60.0);

      expect(killer.tickCount, equals(1));
      expect(victim.tickCount, equals(1)); // Victim completed frame N
      expect(eventLog, contains('onUnregister:Victim'));

      // Absent at frame N+1
      expect(world.persistentLevel.actors.contains(victim), isFalse);

      // Frame 2
      world.tick(1.0 / 60.0);
      expect(victim.tickCount, equals(1)); // Did not tick again
    });

    test('spawnActor from inside onBeginPlay is deferred to frame N+1 phase 5', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final child = PipelineProbeActor('Child', eventLog);
      final spawner = SpawnOnBeginPlayActor(child, eventLog);

      world.spawnActor(spawner);

      // Frame 1: spawner spawns in phase 5, calls spawnActor(child)
      world.tick(1.0 / 60.0);
      expect(eventLog, contains('onBeginPlay:Spawner'));
      expect(child.isInitialized, isFalse);
      expect(child.tickCount, equals(0));

      // Frame 2: child is spawned in phase 5
      world.tick(1.0 / 60.0);
      expect(child.isInitialized, isTrue);
      expect(child.hasBegunPlay, isTrue);
      expect(child.tickCount, equals(0));

      // Frame 3: child receives first tick
      world.tick(1.0 / 60.0);
      expect(child.tickCount, equals(1));
    });

    test('Streaming-level gating: loaded level actors do not tick; visible level actors do', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final streamingActor = PipelineProbeActor('StreamActor', eventLog);
      final streamingLevel = LuminaLevel(children: [streamingActor]);
      streamingLevel.state = LevelState.loaded;

      world.streamingLevels.add(streamingLevel);
      streamingLevel.registerActor(streamingActor);
      streamingActor.onRegister(world);
      streamingActor.onInitialize();
      streamingActor.onBeginPlay();

      world.beginPlay();

      world.tick(1.0 / 60.0);
      expect(streamingActor.tickCount, equals(0));

      // Make visible
      streamingLevel.state = LevelState.visible;
      world.tick(1.0 / 60.0);
      expect(streamingActor.tickCount, equals(1));
    });

    test('onBeginPlay fires exactly once per actor across 10 frames', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final actor = PipelineProbeActor('Actor', eventLog);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      for (int i = 0; i < 10; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.beginPlayCount, equals(1));
      expect(actor.tickCount, equals(10));
    });

    test('Double-buffering: 100 frames with spawn/destroy allocate zero new buffer instances', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();

      final bufSpawnInitial = world.debugActiveSpawnBuffer;
      final bufDestroyInitial = world.debugActiveDestroyBuffer;

      for (int i = 0; i < 100; i++) {
        final a = LuminaActor();
        world.spawnActor(a);
        world.destroyActor(a);
        world.tick(1.0 / 60.0);
      }

      // Buffers used are one of the two pre-allocated buffers
      expect(world.debugAllocatedBufferCount, equals(4)); // 2 for spawn, 2 for destroy
      expect(
        world.debugActiveSpawnBuffer == bufSpawnInitial ||
        world.debugActiveSpawnBuffer == world.debugSecondarySpawnBuffer,
        isTrue,
      );
      expect(
        world.debugActiveDestroyBuffer == bufDestroyInitial ||
        world.debugActiveDestroyBuffer == world.debugSecondaryDestroyBuffer,
        isTrue,
      );
    });

    test('Re-entrant tick call throws StateError', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final reentrantActor = PipelineProbeActor('Reentrant', eventLog);
      world.persistentLevel.registerActor(reentrantActor);

      Object? caughtError;
      reentrantActor.onTickAction = (w) {
        try {
          w.tick(1.0 / 60.0);
        } catch (e) {
          caughtError = e;
        }
      };

      world.beginPlay();
      world.tick(1.0 / 60.0);
      expect(caughtError, isA<StateError>());
    });

    test('cleanup() order: actors unregister before subsystem shutdown; native handles null; idempotent', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final subsystem = PhaseProbeSubsystem(eventLog);
      world.subsystems.registerSubsystem<PhaseProbeSubsystem>(subsystem, world);

      final actor = PipelineProbeActor('A1', eventLog);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();
      world.cleanup();

      expect(eventLog, contains('onUnregister:A1'));
      expect(eventLog, contains('subsystemShutdown'));

      final actorIdx = eventLog.indexOf('onUnregister:A1');
      final subIdx = eventLog.indexOf('subsystemShutdown');
      expect(actorIdx, lessThan(subIdx));

      expect(world.filamentEngineOrNull, isNull);
      expect(world.filamentSceneOrNull, isNull);

      // Second cleanup is no-op
      final countBefore = eventLog.length;
      world.cleanup();
      expect(eventLog.length, equals(countBefore));
    });
  });
}
