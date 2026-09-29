import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

class LevelSmokeActor extends LuminaActor {
  int tickCount = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('Level Module Smoke Tests', () {
    test('Scenario 01: Level lifecycle, actor ownership, streaming level spawn and reverse unload', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final level = LuminaLevel();
      level.state = LevelState.visible;
      world.streamingLevels.add(level);

      final actor1 = LevelSmokeActor();
      final actor2 = LevelSmokeActor();

      world.spawnActor(actor1, level: level);
      world.spawnActor(actor2, level: level);

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(level.actors.length, equals(2));
      expect(actor1.owningLevel, equals(level));
      expect(actor2.owningLevel, equals(level));
      expect(actor1.tickCount, equals(2));
      expect(actor2.tickCount, equals(2));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Level Module Smoke Tests Scenario 01: Level lifecycle, actor ownership, streaming level spawn and reverse unload';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      expect(level.actors.isEmpty, isTrue);
      expect(actor1.owningLevel, isNull);
      expect(actor2.owningLevel, isNull);
    });

    test('Scenario 02: LevelScriptActor lifecycle, onLevelLoaded hook, and reverse-order unload', () async {
      final log = <String>[];
      final script = _SmokeLevelScript(log);
      final level = LuminaLevel(scriptActor: script);
      final actor = LevelSmokeActor();
      level.registerActor(actor);

      final world = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(script.loadedCount, equals(1));
      expect(script.tickCount, equals(3));
      expect(actor.tickCount, equals(3));
      expect(identical(script.level, level), isTrue);

      final usedAssets = [
        'Props/Access_cards/access_card_red.glb',
        'Props/Banana Bunch/banana_bunch_short.glb',
      ];

      const testTitle = 'Level Module Smoke Tests Scenario 02: LevelScriptActor lifecycle, onLevelLoaded hook, and reverse-order unload';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      level.unloadActors();
      expect(script.unloadedCount, equals(1));
      expect(script.level, isNull);
      expect(level.actors.isEmpty, isTrue);
    });
  });
}

class _SmokeLevelScript extends LuminaLevelScriptActor {
  final List<String> log;
  int loadedCount = 0;
  int unloadedCount = 0;
  int tickCount = 0;

  _SmokeLevelScript(this.log);

  @override
  void onLevelLoaded() {
    super.onLevelLoaded();
    loadedCount++;
    log.add('loaded');
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }

  @override
  void onLevelUnloaded() {
    unloadedCount++;
    log.add('unloaded');
    super.onLevelUnloaded();
  }
}
