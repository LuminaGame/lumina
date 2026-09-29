import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class SaveableHeroActor extends LuminaActor {
  double health;
  int restoreOrderTimestamp = 0;
  Vector3? locationAtRestoreTime;

  SaveableHeroActor({
    super.saveId,
    super.bSaveGame = true,
    super.location,
    super.rotation,
    this.health = 100.0,
  });

  @override
  Map<String, dynamic> captureSaveData() {
    return {'health': health};
  }

  @override
  void restoreSaveData(Map<String, dynamic> data) {
    health = (data['health'] as num?)?.toDouble() ?? 100.0;
    locationAtRestoreTime = Vector3.copy(actorLocation);
    restoreOrderTimestamp = DateTime.now().microsecondsSinceEpoch;
  }
}

class SaveableInventoryComponent extends LuminaActorComponent {
  List<String> items;

  SaveableInventoryComponent({
    super.componentName = 'Inventory',
    super.bSaveGame = true,
    List<String>? items,
  }) : items = items ?? [];

  @override
  Map<String, dynamic> captureSaveData() {
    return {'items': items};
  }

  @override
  void restoreSaveData(Map<String, dynamic> data) {
    items = (data['items'] as List?)?.map((e) => e.toString()).toList() ?? [];
  }
}

class NonSaveableComponent extends LuminaActorComponent {
  int tempCounter = 99;

  @override
  Map<String, dynamic> captureSaveData() => {'tempCounter': tempCounter};
}

void main() {
  group('Lumina World State Capture & Restore Tests (Task 03)', () {
    late Directory tempDir;
    late LuminaSaveGameSubsystem subsystem;
    late LuminaWorld world;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('world_restore_test_');
      subsystem = LuminaSaveGameSubsystem(saveDirectoryPath: tempDir.path);
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.subsystems.registerSubsystem<LuminaSaveGameSubsystem>(subsystem, world);

      LuminaSaveGameSubsystem.registerSaveableActorFactory(
        'SaveableHeroActor',
        (record) => SaveableHeroActor(
          saveId: record.saveId,
          location: Vector3(record.location[0], record.location[1], record.location[2]),
          rotation: Quaternion(record.rotation[0], record.rotation[1], record.rotation[2], record.rotation[3]),
        ),
      );
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('World with 3 actors, exactly 1 with bSaveGame=true yields exactly 1 LuminaActorRecord', () {
      final actor1 = LuminaActor(saveId: 'Actor_Unsaved1', bSaveGame: false);
      final actor2 = SaveableHeroActor(saveId: 'Hero_Saved', bSaveGame: true);
      final actor3 = LuminaActor(saveId: 'Actor_Unsaved2', bSaveGame: false);

      world.persistentLevel.registerActor(actor1);
      world.persistentLevel.registerActor(actor2);
      world.persistentLevel.registerActor(actor3);

      final snapshot = subsystem.captureWorldState();
      expect(snapshot.actors.length, equals(1));
      expect(snapshot.actors.first.saveId, equals('Hero_Saved'));
    });

    test('Actor transform restores correctly with quaternion accuracy', () async {
      final hero = SaveableHeroActor(
        saveId: 'Hero_Transform',
        location: Vector3(5.0, 0.0, 2.0),
        rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 1.57079632679), // 90 deg yaw
      );
      world.persistentLevel.registerActor(hero);

      final snapshot = subsystem.captureWorldState();

      // Mutate live actor
      hero.actorLocation = Vector3(50.0, 0.0, 0.0);
      hero.actorRotation = Quaternion.identity();

      final report = await subsystem.restoreWorldState(snapshot);
      expect(report.restored, equals(1));
      expect(hero.actorLocation.x, closeTo(5.0, 1e-6));
      expect(hero.actorLocation.z, closeTo(2.0, 1e-6));
      expect(hero.actorRotation.y, closeTo(0.70710678, 1e-4));
    });

    test('captureSaveData and restoreSaveData execute and restore data after transform is applied', () async {
      final hero = SaveableHeroActor(
        saveId: 'Hero_CustomData',
        location: Vector3(10.0, 0.0, 5.0),
        health: 40.0,
      );
      world.persistentLevel.registerActor(hero);

      final snapshot = subsystem.captureWorldState();
      expect(snapshot.actors.first.customData['health'], equals(40.0));

      hero.health = 100.0;
      hero.actorLocation = Vector3.zero();

      await subsystem.restoreWorldState(snapshot);
      expect(hero.health, equals(40.0));
      expect(hero.locationAtRestoreTime, isNotNull);
      expect(hero.locationAtRestoreTime!.x, closeTo(10.0, 1e-6));
    });

    test('Component with bSaveGame=true contributes to componentData and restores; unflagged contributes nothing', () async {
      final hero = SaveableHeroActor(saveId: 'Hero_WithComponents');
      final invComp = SaveableInventoryComponent(componentName: 'Inventory', items: ['Axe', 'Shield']);
      final nonSaveComp = NonSaveableComponent();

      hero.addComponent(invComp);
      hero.addComponent(nonSaveComp);
      world.persistentLevel.registerActor(hero);

      final snapshot = subsystem.captureWorldState();
      final record = snapshot.actors.first;

      expect(record.componentData.containsKey('Inventory'), isTrue);
      expect(record.componentData['Inventory']!['items'], equals(['Axe', 'Shield']));
      expect(record.componentData.containsKey('NonSaveableComponent'), isFalse);

      invComp.items = [];
      await subsystem.restoreWorldState(snapshot);
      expect(invComp.items, equals(['Axe', 'Shield']));
    });

    test('Missing live actor spawns via factory or reports in missingIds if unhandled', () async {
      final snapshot = LuminaWorldStateSnapshot(
        levelName: 'DefaultLevel',
        actors: [
          LuminaActorRecord(
            saveId: 'Spawnable_Hero',
            actorClassName: 'SaveableHeroActor',
            location: [100.0, 0.0, 200.0],
            rotation: [0.0, 0.0, 0.0, 1.0],
            customData: {'health': 55.0},
            componentData: {},
          ),
          LuminaActorRecord(
            saveId: 'Unknown_Alien',
            actorClassName: 'AlienClassNoFactory',
            location: [0.0, 0.0, 0.0],
            rotation: [0.0, 0.0, 0.0, 1.0],
            customData: {},
            componentData: {},
          ),
        ],
      );

      final report = await subsystem.restoreWorldState(snapshot);
      expect(report.spawned, equals(1));
      expect(report.missingIds, equals(['Unknown_Alien']));

      final spawnedHero = world.persistentLevel.actors.firstWhere((a) => a.saveId == 'Spawnable_Hero') as SaveableHeroActor;
      expect(spawnedHero.actorLocation.x, equals(100.0));
      expect(spawnedHero.health, equals(55.0));
    });

    test('Duplicate explicit saveId in world throws StateError on capture', () {
      final a1 = SaveableHeroActor(saveId: 'DUPLICATE_ID');
      final a2 = SaveableHeroActor(saveId: 'DUPLICATE_ID');

      world.persistentLevel.registerActor(a1);
      world.persistentLevel.registerActor(a2);

      expect(() => subsystem.captureWorldState(), throwsStateError);
    });

    test('Full loop through disk: saveWorldToSlotAsync and loadWorldFromSlotAsync', () async {
      final hero = SaveableHeroActor(
        saveId: 'Player1',
        location: Vector3(15.0, 3.0, 7.0),
        health: 65.0,
      );
      world.persistentLevel.registerActor(hero);

      final saveResult = await subsystem.saveWorldToSlotAsync('WorldSlot1', 0);
      expect(saveResult.success, isTrue);

      // Mutate live world
      hero.actorLocation = Vector3.zero();
      hero.health = 100.0;

      final restoreReport = await subsystem.loadWorldFromSlotAsync('WorldSlot1', 0);
      expect(restoreReport, isNotNull);
      expect(restoreReport!.restored, equals(1));
      expect(hero.actorLocation.x, closeTo(15.0, 1e-6));
      expect(hero.health, equals(65.0));
    });

    test('Data layer states round-trip through world state snapshot', () async {
      final partition = LuminaWorldPartitionSubsystem();
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final questLayer = partition.dataLayerManager.registerLayer(
        'DataLayer_Quests',
        initialState: DataLayerState.activated,
      );

      final snapshot = subsystem.captureWorldState();
      expect(snapshot.dataLayerStates['DataLayer_Quests'], equals('activated'));

      // Mutate layer
      partition.dataLayerManager.setDataLayerState('DataLayer_Quests', DataLayerState.unloaded);
      expect(questLayer.state, equals(DataLayerState.unloaded));

      await subsystem.restoreWorldState(snapshot);
      expect(questLayer.state, equals(DataLayerState.activated));
    });
  });
}
