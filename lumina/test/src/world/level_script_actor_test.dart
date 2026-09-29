import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class ScriptScenarioActor extends LuminaLevelScriptActor {
  final String name;
  final List<String> eventLog;
  int levelLoadedCount = 0;
  int levelUnloadedCount = 0;
  int tickCount = 0;
  int beginPlayCount = 0;
  void Function(LuminaLevelScriptActor script)? onLevelLoadedCallback;

  ScriptScenarioActor(this.name, this.eventLog);

  @override
  void onRegister(LuminaWorld world) {
    super.onRegister(world);
    eventLog.add('script.onRegister:$name');
  }

  @override
  void onInitialize() {
    super.onInitialize();
    eventLog.add('script.onInitialize:$name');
  }

  @override
  void onLevelLoaded() {
    super.onLevelLoaded();
    levelLoadedCount++;
    eventLog.add('script.onLevelLoaded:$name');
    onLevelLoadedCallback?.call(this);
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    beginPlayCount++;
    eventLog.add('script.onBeginPlay:$name');
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    eventLog.add('script.onTick:$name');
  }

  @override
  void onLevelUnloaded() {
    levelUnloadedCount++;
    eventLog.add('script.onLevelUnloaded:$name');
    super.onLevelUnloaded();
  }

  @override
  void onUnregister() {
    eventLog.add('script.onUnregister:$name');
    super.onUnregister();
  }
}

class ScriptScenarioEntityActor extends LuminaActor {
  final String name;
  final List<String> eventLog;
  int tickCount = 0;

  ScriptScenarioEntityActor(this.name, this.eventLog);

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    eventLog.add('actor.onBeginPlay:$name');
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    eventLog.add('actor.onTick:$name');
  }

  @override
  void onUnregister() {
    eventLog.add('actor.onUnregister:$name');
    super.onUnregister();
  }
}

void main() {
  group('Level Script Actor Tests (Level Task 02)', () {
    test('Script actor lifecycle ordering: onRegister->onInitialize->onLevelLoaded->onBeginPlay precedes other actors', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('MainScript', eventLog);
      final level = LuminaLevel(scriptActor: script);
      final actorA = ScriptScenarioEntityActor('A', eventLog);
      final actorB = ScriptScenarioEntityActor('B', eventLog);

      level.registerActor(actorA);
      level.registerActor(actorB);

      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);
      world.beginPlay();

      expect(eventLog, containsAllInOrder([
        'script.onRegister:MainScript',
        'script.onInitialize:MainScript',
        'script.onLevelLoaded:MainScript',
        'script.onBeginPlay:MainScript',
        'actor.onBeginPlay:A',
        'actor.onBeginPlay:B',
      ]));
    });

    test('onLevelLoaded fires exactly once across 10 subsequent ticks and visibility toggle', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('MainScript', eventLog);
      final level = LuminaLevel(scriptActor: script);
      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);

      world.beginPlay();
      expect(script.levelLoadedCount, equals(1));

      for (int i = 0; i < 10; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(script.levelLoadedCount, equals(1));

      level.state = LevelState.makingInvisible;
      level.state = LevelState.visible;
      world.tick(1.0 / 60.0);
      expect(script.levelLoadedCount, equals(1));
    });

    test('unloadActors ordering: actors reverse-order -> script.onLevelUnloaded -> script.onUnregister', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('MainScript', eventLog);
      final level = LuminaLevel(scriptActor: script);
      final actorA = ScriptScenarioEntityActor('A', eventLog);
      final actorB = ScriptScenarioEntityActor('B', eventLog);

      level.registerActor(actorA);
      level.registerActor(actorB);

      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);
      world.beginPlay();

      eventLog.clear();
      level.unloadActors();

      expect(eventLog, equals([
        'actor.onUnregister:B',
        'actor.onUnregister:A',
        'script.onLevelUnloaded:MainScript',
        'script.onUnregister:MainScript',
      ]));
      expect(script.levelUnloadedCount, equals(1));
    });

    test('script.level is identical to owning level while loaded and null after unload', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('MainScript', eventLog);
      final level = LuminaLevel(scriptActor: script);
      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);

      world.beginPlay();
      expect(identical(script.level, level), isTrue);

      world.cleanup();
      expect(script.level, isNull);
    });

    test('Script actor appears in level.actors at index 0 and ticks first while visible; 0 ticks while loaded', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('StreamScript', eventLog);
      final actorA = ScriptScenarioEntityActor('A', eventLog);
      final streamLevel = LuminaLevel(scriptActor: script, children: [actorA]);
      streamLevel.state = LevelState.loaded;

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.streamingLevels.add(streamLevel);
      streamLevel.registerActor(actorA);

      world.beginPlay();
      expect(streamLevel.actors.first, equals(script));
      expect(streamLevel.actors[0], equals(script));

      world.tick(1.0 / 60.0);
      expect(script.tickCount, equals(0));
      expect(actorA.tickCount, equals(0));

      streamLevel.state = LevelState.visible;
      eventLog.clear();
      world.tick(1.0 / 60.0);

      expect(script.tickCount, equals(1));
      expect(actorA.tickCount, equals(1));
      expect(eventLog, containsAllInOrder(['script.onTick:StreamScript', 'actor.onTick:A']));
    });

    test('world.spawnActor from inside onLevelLoaded registers into script level at phase-5 drain', () {
      final eventLog = <String>[];
      final script = ScriptScenarioActor('SpawnerScript', eventLog);
      final spawned = ScriptScenarioEntityActor('SpawnedByScript', eventLog);

      final level = LuminaLevel(scriptActor: script);
      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);

      script.onLevelLoadedCallback = (s) {
        world.spawnActor(spawned, level: s.level);
      };

      world.beginPlay();

      // Before tick, spawned is in deferred queue
      expect(level.actors.contains(spawned), isFalse);

      world.tick(1.0 / 60.0);
      expect(level.actors.contains(spawned), isTrue);
      expect(identical(spawned.owningLevel, level), isTrue);
    });

    test('Level without scriptActor loads, ticks 3 frames, and unloads with no errors', () {
      final eventLog = <String>[];
      final actor = ScriptScenarioEntityActor('NormalActor', eventLog);
      final level = LuminaLevel();
      level.registerActor(actor);

      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.tickCount, equals(3));
      world.cleanup();
      expect(level.actors.isEmpty, isTrue);
    });

    test('Two levels with two distinct script actors in one world deliver callbacks independently', () {
      final eventLog1 = <String>[];
      final eventLog2 = <String>[];

      final script1 = ScriptScenarioActor('Script1', eventLog1);
      final script2 = ScriptScenarioActor('Script2', eventLog2);

      final level1 = LuminaLevel(scriptActor: script1);
      final level2 = LuminaLevel(scriptActor: script2);
      level2.state = LevelState.visible;

      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level1);
      world.streamingLevels.add(level2);

      world.beginPlay();

      expect(script1.levelLoadedCount, equals(1));
      expect(script2.levelLoadedCount, equals(1));

      world.tick(1.0 / 60.0);
      expect(script1.tickCount, equals(1));
      expect(script2.tickCount, equals(1));

      level2.unloadActors();
      expect(script2.levelUnloadedCount, equals(1));
      expect(script1.levelUnloadedCount, equals(0));
    });
  });
}
