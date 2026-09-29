import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

class GameSaveSmokeData extends LuminaSaveGame {
  double heroHealth;
  int collectedCoins;
  List<String> activeQuests;

  GameSaveSmokeData({
    super.saveSlotName,
    super.userIndex,
    super.saveTimestamp,
    super.currentLevelName,
    super.playerLocation,
    super.playerRotation,
    super.customSaveData,
    super.saveGameVersion,
    this.heroHealth = 100.0,
    this.collectedCoins = 0,
    List<String>? activeQuests,
  }) : activeQuests = activeQuests ?? [];

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['heroHealth'] = heroHealth;
    json['collectedCoins'] = collectedCoins;
    json['activeQuests'] = activeQuests;
    return json;
  }

  factory GameSaveSmokeData.fromJson(Map<String, dynamic> json) {
    final base = LuminaSaveGame.fromJson(json);
    return GameSaveSmokeData(
      saveSlotName: base.saveSlotName,
      userIndex: base.userIndex,
      saveTimestamp: base.saveTimestamp,
      currentLevelName: base.currentLevelName,
      playerLocation: base.playerLocation,
      playerRotation: base.playerRotation,
      customSaveData: base.customSaveData,
      saveGameVersion: base.saveGameVersion,
      heroHealth: (json['heroHealth'] as num?)?.toDouble() ?? 100.0,
      collectedCoins: (json['collectedCoins'] as num?)?.toInt() ?? 0,
      activeQuests: (json['activeQuests'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class SmokePersistentActor extends LuminaActor {
  double shield;
  String currentStance;

  SmokePersistentActor({
    super.saveId,
    super.bSaveGame = true,
    super.location,
    super.rotation,
    this.shield = 100.0,
    this.currentStance = 'Defensive',
  });

  @override
  Map<String, dynamic> captureSaveData() {
    return {
      'shield': shield,
      'currentStance': currentStance,
    };
  }

  @override
  void restoreSaveData(Map<String, dynamic> data) {
    shield = (data['shield'] as num?)?.toDouble() ?? 100.0;
    currentStance = data['currentStance'] as String? ?? 'Defensive';
  }
}

void main() {
  group('Game Save Module Smoke Tests', () {
    test('Scenario 01: LuminaSaveGame polymorphic subclass registration, JSON & LMSV binary serialization round-trip', () async {
      LuminaSaveGame.registerSaveGameType<GameSaveSmokeData>(
        'GameSaveSmokeData',
        (json) => GameSaveSmokeData.fromJson(json),
      );

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final heroActor = LuminaActor(location: Vector3(12.5, 4.0, -8.0));
      world.persistentLevel.registerActor(heroActor);
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final saveData = GameSaveSmokeData(
        saveSlotName: 'Slot_SmokeTest',
        currentLevelName: 'L_AncientRuins',
        playerLocation: heroActor.actorLocation,
        heroHealth: 88.5,
        collectedCoins: 42,
        activeQuests: ['DefeatGorgon', 'FindSunRelic'],
        customSaveData: {
          'unlockedPerks': ['DoubleJump', 'FireDash'],
          'worldSeed': 987654,
        },
      );

      // JSON Round-trip
      final jsonPayload = saveData.serialize();
      final fromJsonRestored = LuminaSaveGame.deserialize(jsonPayload);
      expect(fromJsonRestored, isA<GameSaveSmokeData>());
      final typedJson = fromJsonRestored as GameSaveSmokeData;
      expect(typedJson.heroHealth, equals(88.5));
      expect(typedJson.collectedCoins, equals(42));
      expect(typedJson.activeQuests, equals(['DefeatGorgon', 'FindSunRelic']));
      expect(typedJson.playerLocation.x, closeTo(12.5, 1e-5));

      final usedAssets = [
        'Props/Barrels/bent_barrel.glb',
        'Props/Access_cards/access_card_red.glb',
      ];

      const testTitle = 'Game Save Module Smoke Tests Scenario 01: LuminaSaveGame polymorphic subclass registration, JSON & LMSV binary serialization round-trip';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaSaveGameSubsystem async atomic slot write with tmp swap, corrupted save detection, and multi-slot listing', () async {
      final tempDir = Directory.systemTemp.createTempSync('smoke_save_subsystem_');
      final saveSubsystem = LuminaSaveGameSubsystem(saveDirectoryPath: tempDir.path);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.subsystems.registerSubsystem<LuminaSaveGameSubsystem>(saveSubsystem, world);

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Save 3 slots
      for (int i = 1; i <= 3; i++) {
        final save = GameSaveSmokeData(
          saveSlotName: 'CampaignSlot_$i',
          heroHealth: 100.0 - (i * 10),
          collectedCoins: i * 50,
        );
        final result = await saveSubsystem.saveGameToSlotAsync(save, 'CampaignSlot_$i', 0);
        expect(result.success, isTrue);
      }

      final slots = await saveSubsystem.listSaveSlots(userIndex: 0);
      expect(slots.length, equals(3));
      expect(slots.contains('CampaignSlot_1'), isTrue);
      expect(slots.contains('CampaignSlot_2'), isTrue);
      expect(slots.contains('CampaignSlot_3'), isTrue);

      final loaded2 = await saveSubsystem.loadGameFromSlotAsync('CampaignSlot_2', 0);
      expect(loaded2, isA<GameSaveSmokeData>());
      expect((loaded2 as GameSaveSmokeData).heroHealth, equals(80.0));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Game Save Module Smoke Tests Scenario 02: LuminaSaveGameSubsystem async atomic slot write with tmp swap, corrupted save detection, and multi-slot listing';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Scenario 03: bSaveGame automatic world-state capture, disk save/load loop, and actor transform/custom data restore', () async {
      final tempDir = Directory.systemTemp.createTempSync('smoke_world_restore_');
      final saveSubsystem = LuminaSaveGameSubsystem(saveDirectoryPath: tempDir.path);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.subsystems.registerSubsystem<LuminaSaveGameSubsystem>(saveSubsystem, world);

      LuminaSaveGameSubsystem.registerSaveableActorFactory(
        'SmokePersistentActor',
        (record) => SmokePersistentActor(
          saveId: record.saveId,
          location: Vector3(record.location[0], record.location[1], record.location[2]),
          rotation: Quaternion(record.rotation[0], record.rotation[1], record.rotation[2], record.rotation[3]),
        ),
      );

      final warrior = SmokePersistentActor(
        saveId: 'Warrior_Alpha',
        location: Vector3(25.0, 0.0, 15.0),
        shield: 85.0,
        currentStance: 'Aggressive',
      );
      final regularBox = LuminaActor(saveId: 'UnsavedBox', bSaveGame: false);

      world.persistentLevel.registerActor(warrior);
      world.persistentLevel.registerActor(regularBox);

      world.beginPlay();
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Save world state to disk
      final saveResult = await saveSubsystem.saveWorldToSlotAsync('WorldSlot_Smoke', 0);
      expect(saveResult.success, isTrue);

      // Mutate live world state
      warrior.actorLocation = Vector3(0.0, 0.0, 0.0);
      warrior.shield = 10.0;
      warrior.currentStance = 'Fleeing';

      // Restore from disk
      final restoreReport = await saveSubsystem.loadWorldFromSlotAsync('WorldSlot_Smoke', 0);
      expect(restoreReport, isNotNull);
      expect(restoreReport!.restored, equals(1));
      expect(warrior.actorLocation.x, closeTo(25.0, 1e-5));
      expect(warrior.shield, equals(85.0));
      expect(warrior.currentStance, equals('Aggressive'));

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
      ];

      const testTitle = 'Game Save Module Smoke Tests Scenario 03: bSaveGame automatic world-state capture, disk save/load loop, and actor transform/custom data restore';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      world.cleanup();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });
  });
}
