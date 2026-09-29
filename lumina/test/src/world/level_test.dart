import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class LevelProbeActor extends LuminaActor {
  final String name;
  final List<String>? eventLog;
  int unregisterCount = 0;
  void Function()? onUnregisterCallback;

  LevelProbeActor(this.name, [this.eventLog]);

  @override
  void onUnregister() {
    unregisterCount++;
    eventLog?.add('onUnregister:$name');
    onUnregisterCallback?.call();
    super.onUnregister();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    eventLog?.add('onTick:$name');
  }
}

class ScriptProbeActor extends LuminaLevelScriptActor {
  final List<String> eventLog;
  ScriptProbeActor(this.eventLog);

  @override
  void onLevelUnloaded() {
    eventLog.add('onLevelUnloaded:scriptActor');
    super.onLevelUnloaded();
  }

  @override
  void onUnregister() {
    eventLog.add('onUnregister:scriptActor');
    super.onUnregister();
  }
}

void main() {
  group('Level Lifecycle and Actor Ownership Tests (Level Task 01)', () {
    test('registerActor is idempotent and sets actor.owningLevel', () {
      final level = LuminaLevel();
      final actor = LevelProbeActor('A1');

      level.registerActor(actor);
      expect(level.actors.length, equals(1));
      expect(identical(actor.owningLevel, level), isTrue);

      // Duplicate registration is no-op
      level.registerActor(actor);
      expect(level.actors.length, equals(1));
      expect(identical(actor.owningLevel, level), isTrue);
    });

    test('Registration order is preserved in iteration and tick dispatch', () {
      final eventLog = <String>[];
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final a = LevelProbeActor('A', eventLog);
      final b = LevelProbeActor('B', eventLog);
      final c = LevelProbeActor('C', eventLog);

      world.persistentLevel.registerActor(a);
      world.persistentLevel.registerActor(b);
      world.persistentLevel.registerActor(c);

      expect(world.persistentLevel.actors.map((x) => (x as LevelProbeActor).name).toList(), equals(['A', 'B', 'C']));

      world.beginPlay();
      world.tick(1.0 / 60.0);

      expect(eventLog, containsAllInOrder(['onTick:A', 'onTick:B', 'onTick:C']));
    });

    test('unregisterActor fires onUnregister once, nulls owningLevel/world, removes from actors', () {
      final level = LuminaLevel();
      final actor = LevelProbeActor('A1');

      level.registerActor(actor);
      expect(level.actors.contains(actor), isTrue);

      level.unregisterActor(actor);
      expect(actor.unregisterCount, equals(1));
      expect(actor.owningLevel, isNull);
      expect(actor.world, isNull);
      expect(level.actors.contains(actor), isFalse);

      // Second unregister is no-op
      level.unregisterActor(actor);
      expect(actor.unregisterCount, equals(1));
    });

    test('unloadActors on [A, B, C] + scriptActor unregisters in reverse order [C, B, A, scriptActor]', () {
      final eventLog = <String>[];
      final scriptActor = ScriptProbeActor(eventLog);
      final level = LuminaLevel(scriptActor: scriptActor);

      final a = LevelProbeActor('A', eventLog);
      final b = LevelProbeActor('B', eventLog);
      final c = LevelProbeActor('C', eventLog);

      level.registerActor(a);
      level.registerActor(b);
      level.registerActor(c);

      level.unloadActors();

      expect(eventLog, equals([
        'onUnregister:C',
        'onUnregister:B',
        'onUnregister:A',
        'onLevelUnloaded:scriptActor',
        'onUnregister:scriptActor',
      ]));
      expect(level.actors.isEmpty, isTrue);
      expect(level.owningWorld, isNull);
    });

    test('Circular reference cleanup: level callback listeners cleaned by onUnregister', () {
      final level = LuminaLevel();
      final levelListeners = <void Function()>[];

      final actor = LevelProbeActor('Listener');
      void listenerCallback() {}

      // Simulate subscribing to level
      levelListeners.add(listenerCallback);
      actor.onUnregisterCallback = () {
        levelListeners.remove(listenerCallback);
      };

      level.registerActor(actor);
      expect(levelListeners.length, equals(1));

      level.unloadActors();
      expect(levelListeners.isEmpty, isTrue);
    });

    test('spawnActor with target streamingLevel registers into streamingLevel after phase 5', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final streamingLevel = LuminaLevel();
      streamingLevel.state = LevelState.visible;
      world.streamingLevels.add(streamingLevel);

      final dynamicActor = LevelProbeActor('DynamicStreamActor');
      world.spawnActor(dynamicActor, level: streamingLevel);

      world.beginPlay();
      world.tick(1.0 / 60.0);

      expect(streamingLevel.actors.contains(dynamicActor), isTrue);
      expect(world.persistentLevel.actors.contains(dynamicActor), isFalse);
      expect(identical(dynamicActor.owningLevel, streamingLevel), isTrue);
    });

    test('Fresh LuminaWorld persistentLevel.state == visible; standalone LuminaLevel == unloaded', () {
      final world = LuminaWorld();
      expect(world.persistentLevel.state, equals(LevelState.visible));
      expect(world.persistentLevel.isVisible, isTrue);

      final standaloneLevel = LuminaLevel();
      expect(standaloneLevel.state, equals(LevelState.unloaded));
      expect(standaloneLevel.isVisible, isFalse);
    });

    test('LevelState.values order is preserved for 7 states', () {
      expect(LevelState.values, equals([
        LevelState.unloaded,
        LevelState.loading,
        LevelState.loaded,
        LevelState.makingVisible,
        LevelState.visible,
        LevelState.makingInvisible,
        LevelState.unloading,
      ]));
    });

    test('Debug assert: direct registerActor call during world tick maintains structural integrity', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final violator = LevelProbeActor('Violator');
      world.persistentLevel.registerActor(violator);

      final nested = LevelProbeActor('Nested');
      world.persistentLevel.registerActor(nested);

      world.beginPlay();
      world.tick(1.0 / 60.0);
      expect(world.persistentLevel.actors.contains(nested), isTrue);
    });
  });
}
