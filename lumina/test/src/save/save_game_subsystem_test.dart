import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class SubsystemTestCustomSave extends LuminaSaveGame {
  double heroHealth;
  List<String> items;

  SubsystemTestCustomSave({
    super.saveSlotName,
    super.userIndex,
    super.saveTimestamp,
    super.currentLevelName,
    super.playerLocation,
    super.playerRotation,
    super.customSaveData,
    super.saveGameVersion,
    this.heroHealth = 100.0,
    List<String>? items,
  }) : items = items ?? [];

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['heroHealth'] = heroHealth;
    json['items'] = items;
    return json;
  }

  factory SubsystemTestCustomSave.fromJson(Map<String, dynamic> json) {
    final base = LuminaSaveGame.fromJson(json);
    return SubsystemTestCustomSave(
      saveSlotName: base.saveSlotName,
      userIndex: base.userIndex,
      saveTimestamp: base.saveTimestamp,
      currentLevelName: base.currentLevelName,
      playerLocation: base.playerLocation,
      playerRotation: base.playerRotation,
      customSaveData: base.customSaveData,
      saveGameVersion: base.saveGameVersion,
      heroHealth: (json['heroHealth'] as num?)?.toDouble() ?? 100.0,
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class FaultySaveGame extends LuminaSaveGame {
  @override
  Map<String, dynamic> toJson() {
    throw Exception('Simulated serialization failure');
  }
}

void main() {
  group('LuminaSaveGameSubsystem Tests (Task 02)', () {
    late Directory tempDir;
    late LuminaSaveGameSubsystem subsystem;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lumina_save_subsystem_test_');
      subsystem = LuminaSaveGameSubsystem(saveDirectoryPath: tempDir.path);
      LuminaSaveGame.registerSaveGameType<SubsystemTestCustomSave>(
        'SubsystemTestCustomSave',
        (json) => SubsystemTestCustomSave.fromJson(json),
      );
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('saveGameToSlotAsync writes Slot1_user_0.sav and leaves no .tmp behind', () async {
      final save = LuminaSaveGame(
        saveSlotName: 'Slot1',
        playerLocation: Vector3(10, 20, 30),
      );

      final result = await subsystem.saveGameToSlotAsync(save, 'Slot1', 0);
      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);

      final targetFile = File('${tempDir.path}/Slot1_user_0.sav');
      final tmpFile = File('${tempDir.path}/Slot1_user_0.sav.tmp');

      expect(targetFile.existsSync(), isTrue);
      expect(tmpFile.existsSync(), isFalse);
    });

    test('Save and load round-trip restores registered subclass instance', () async {
      final customSave = SubsystemTestCustomSave(
        saveSlotName: 'SlotTyped',
        heroHealth: 77.5,
        items: ['Potion', 'Key'],
      );

      final saveResult = await subsystem.saveGameToSlotAsync(customSave, 'SlotTyped', 0);
      expect(saveResult.success, isTrue);

      final loaded = await subsystem.loadGameFromSlotAsync('SlotTyped', 0);
      expect(loaded, isNotNull);
      expect(loaded, isA<SubsystemTestCustomSave>());
      final typed = loaded as SubsystemTestCustomSave;
      expect(typed.heroHealth, equals(77.5));
      expect(typed.items, equals(['Potion', 'Key']));
    });

    test('doesSaveGameExist returns false for nonexistent slots or different userIndex', () async {
      expect(await subsystem.doesSaveGameExist('Nope', 0), isFalse);

      final save = LuminaSaveGame();
      await subsystem.saveGameToSlotAsync(save, 'SlotA', 0);

      expect(await subsystem.doesSaveGameExist('SlotA', 0), isTrue);
      expect(await subsystem.doesSaveGameExist('SlotA', 1), isFalse);
    });

    test('Lone .tmp file (simulated crash) returns false for exists, and onWorldInitialize sweeps it', () async {
      final tmpFile = File('${tempDir.path}/SlotCrash_user_0.sav.tmp');
      tmpFile.writeAsStringSync('{"incomplete": true}');

      expect(await subsystem.doesSaveGameExist('SlotCrash', 0), isFalse);

      final world = LuminaWorld();
      subsystem.onWorldInitialize(world);

      expect(tmpFile.existsSync(), isFalse);
    });

    test('Failed save does not corrupt existing save file (atomic guarantee)', () async {
      final initialSave = LuminaSaveGame(
        saveSlotName: 'AtomicSlot',
        playerLocation: Vector3(1, 2, 3),
      );
      await subsystem.saveGameToSlotAsync(initialSave, 'AtomicSlot', 0);

      final faultySave = FaultySaveGame();
      final failResult = await subsystem.saveGameToSlotAsync(faultySave, 'AtomicSlot', 0);
      expect(failResult.success, isFalse);

      final loaded = await subsystem.loadGameFromSlotAsync('AtomicSlot', 0);
      expect(loaded, isNotNull);
      expect(loaded!.playerLocation, equals(Vector3(1, 2, 3)));
    });

    test('Corrupt save data throws LuminaSaveCorruptException and missing file returns null', () async {
      final missing = await subsystem.loadGameFromSlotAsync('MissingSlot', 0);
      expect(missing, isNull);

      final corruptFile = File('${tempDir.path}/CorruptSlot_user_0.sav');
      corruptFile.writeAsStringSync('garbage###not_valid_json');

      expect(
        () => subsystem.loadGameFromSlotAsync('CorruptSlot', 0),
        throwsA(isA<LuminaSaveCorruptException>()),
      );
    });

    test('Concurrent saves to same slot do not interleave and saves to distinct slots run in parallel', () async {
      // 10 concurrent saves to one slot
      final futures = <Future<LuminaSaveResult>>[];
      for (int i = 0; i < 10; i++) {
        final save = LuminaSaveGame(
          saveSlotName: 'ConcurrentSlot',
          userIndex: 0,
          customSaveData: {'iteration': i},
        );
        futures.add(subsystem.saveGameToSlotAsync(save, 'ConcurrentSlot', 0));
      }

      final results = await Future.wait(futures);
      for (final r in results) {
        expect(r.success, isTrue);
      }

      final loaded = await subsystem.loadGameFromSlotAsync('ConcurrentSlot', 0);
      expect(loaded, isNotNull);
      expect(loaded!.customSaveData['iteration'], isA<int>());

      // Distinct slots in parallel
      final multiSlotFutures = <Future<LuminaSaveResult>>[];
      for (int i = 0; i < 10; i++) {
        final save = LuminaSaveGame(saveSlotName: 'Slot_$i', userIndex: 0);
        multiSlotFutures.add(subsystem.saveGameToSlotAsync(save, 'Slot_$i', 0));
      }
      final multiResults = await Future.wait(multiSlotFutures);
      for (final r in multiResults) {
        expect(r.success, isTrue);
      }

      final allSlots = await subsystem.listSaveSlots(userIndex: 0);
      expect(allSlots.length, greaterThanOrEqualTo(10));
    });

    test('deleteSaveSlot removes file and any orphaned tmp sibling', () async {
      final save = LuminaSaveGame();
      await subsystem.saveGameToSlotAsync(save, 'DeleteMe', 0);
      final tmpFile = File('${tempDir.path}/DeleteMe_user_0.sav.tmp');
      tmpFile.writeAsStringSync('orphan');

      expect(await subsystem.doesSaveGameExist('DeleteMe', 0), isTrue);

      final deleted = await subsystem.deleteSaveSlot('DeleteMe', 0);
      expect(deleted, isTrue);
      expect(await subsystem.doesSaveGameExist('DeleteMe', 0), isFalse);
      expect(tmpFile.existsSync(), isFalse);

      final deletedAgain = await subsystem.deleteSaveSlot('DeleteMe', 0);
      expect(deletedAgain, isFalse);
    });

    test('Invalid slot names throw ArgumentError', () async {
      final save = LuminaSaveGame();
      expect(() => subsystem.saveGameToSlotAsync(save, '../evil', 0), throwsArgumentError);
      expect(() => subsystem.saveGameToSlotAsync(save, 'a/b', 0), throwsArgumentError);
      expect(() => subsystem.saveGameToSlotAsync(save, 'a\\b', 0), throwsArgumentError);
      expect(() => subsystem.saveGameToSlotAsync(save, '', 0), throwsArgumentError);
    });
  });
}
