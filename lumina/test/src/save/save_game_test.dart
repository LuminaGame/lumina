import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class MyCustomSaveGame extends LuminaSaveGame {
  double health;
  List<String> inventory;

  MyCustomSaveGame({
    super.saveSlotName,
    super.userIndex,
    super.saveTimestamp,
    super.currentLevelName,
    super.playerLocation,
    super.playerRotation,
    super.customSaveData,
    super.saveGameVersion,
    this.health = 100.0,
    List<String>? inventory,
  }) : inventory = inventory ?? [];

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['health'] = health;
    json['inventory'] = inventory;
    return json;
  }

  factory MyCustomSaveGame.fromJson(Map<String, dynamic> json) {
    final base = LuminaSaveGame.fromJson(json);
    return MyCustomSaveGame(
      saveSlotName: base.saveSlotName,
      userIndex: base.userIndex,
      saveTimestamp: base.saveTimestamp,
      currentLevelName: base.currentLevelName,
      playerLocation: base.playerLocation,
      playerRotation: base.playerRotation,
      customSaveData: base.customSaveData,
      saveGameVersion: base.saveGameVersion,
      health: (json['health'] as num?)?.toDouble() ?? 100.0,
      inventory: (json['inventory'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

void main() {
  group('LuminaSaveGame Serialization Tests (Task 01)', () {
    setUp(() {
      LuminaSaveGame.registerSaveGameType<MyCustomSaveGame>(
        'MyCustomSaveGame',
        (json) => MyCustomSaveGame.fromJson(json),
      );
    });

    test('Default-constructed LuminaSaveGame serialize -> deserialize round-trip', () {
      final save = LuminaSaveGame(
        saveTimestamp: DateTime.utc(2026, 8, 22, 12, 0, 0),
      );
      final serialized = save.serialize();
      final restored = LuminaSaveGame.deserialize(serialized);

      expect(restored.saveSlotName, equals('SaveSlot_01'));
      expect(restored.userIndex, equals(0));
      expect(restored.currentLevelName, equals('DefaultLevel'));
      expect(restored.saveTimestamp.toIso8601String(), equals(DateTime.utc(2026, 8, 22, 12, 0, 0).toIso8601String()));
      expect(restored.playerLocation, equals(Vector3.zero()));
      expect(restored.playerRotation, equals(Quaternion.identity()));
      expect(restored.saveGameVersion, equals(1));
    });

    test('Round-trip with non-trivial transform and customSaveData', () {
      final save = LuminaSaveGame(
        playerLocation: Vector3(1.5, -2.0, 3.25),
        playerRotation: Quaternion(0, 0.7071, 0, 0.7071),
        customSaveData: {'gold': 250, 'name': 'Canus'},
      );

      final restored = LuminaSaveGame.deserialize(save.serialize());

      expect(restored.playerLocation.x, closeTo(1.5, 1e-6));
      expect(restored.playerLocation.y, closeTo(-2.0, 1e-6));
      expect(restored.playerLocation.z, closeTo(3.25, 1e-6));
      expect(restored.playerRotation.y, closeTo(0.7071, 1e-6));
      expect(restored.playerRotation.w, closeTo(0.7071, 1e-6));
      expect(restored.customSaveData['gold'], equals(250));
      expect(restored.customSaveData['name'], equals('Canus'));
    });

    test('JSON containing integer coordinates parses to double without crash', () {
      final rawJson = jsonEncode({
        'saveSlotName': 'SlotInt',
        'playerLocation': [1, 2, 3],
        'playerRotation': [0, 1, 0, 0],
      });

      final restored = LuminaSaveGame.deserialize(rawJson);
      expect(restored.playerLocation, equals(Vector3(1.0, 2.0, 3.0)));
      expect(restored.playerRotation, equals(Quaternion(0.0, 1.0, 0.0, 0.0)));
    });

    test('MyCustomSaveGame subclass round-trip via registry and instantiateFromJson', () {
      final custom = MyCustomSaveGame(
        health: 75.0,
        inventory: ['Sword', 'Shield'],
      );

      final jsonStr = custom.serialize();
      final restored = LuminaSaveGame.deserialize(jsonStr);

      expect(restored, isA<MyCustomSaveGame>());
      final typed = restored as MyCustomSaveGame;
      expect(typed.health, equals(75.0));
      expect(typed.inventory, equals(['Sword', 'Shield']));
    });

    test('Unregistered class name in JSON falls back to base LuminaSaveGame', () {
      final rawJson = jsonEncode({
        'saveGameClassName': 'UnregisteredAlienSaveGame',
        'saveSlotName': 'SlotFallback',
        'currentLevelName': 'SecretBase',
      });

      final restored = LuminaSaveGame.deserialize(rawJson);
      expect(restored, isA<LuminaSaveGame>());
      expect(restored.saveSlotName, equals('SlotFallback'));
      expect(restored.currentLevelName, equals('SecretBase'));
    });

    test('serializeBinary and deserializeBinary round-trip with LMSV magic and version', () {
      final save = LuminaSaveGame(
        saveSlotName: 'BinarySlot',
        playerLocation: Vector3(10, 20, 30),
      );

      final bytes = save.serializeBinary();
      expect(bytes.length, greaterThan(8));
      // Magic LMSV
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('LMSV'));

      final restored = LuminaSaveGame.deserializeBinary(bytes);
      expect(restored.saveSlotName, equals('BinarySlot'));
      expect(restored.playerLocation, equals(Vector3(10.0, 20.0, 30.0)));

      // Corrupt magic byte
      final corrupted = Uint8List.fromList(bytes);
      corrupted[0] = 0x58; // 'X'
      expect(() => LuminaSaveGame.deserializeBinary(corrupted), throwsFormatException);
    });

    test('toJson with non-encodable customSaveData throws ArgumentError naming offending key', () {
      final save = LuminaSaveGame(
        customSaveData: {
          'validKey': 123,
          'bad': Vector3.zero(),
        },
      );

      expect(
        () => save.toJson(),
        throwsA(isA<ArgumentError>().having((e) => e.message.toString(), 'message', contains('bad'))),
      );
    });

    test('deserialize invalid JSON throws FormatException and missing optional fields default cleanly', () {
      expect(() => LuminaSaveGame.deserialize('not json at all'), throwsFormatException);

      final partialJson = jsonEncode({'saveSlotName': 'Minimal'});
      final restored = LuminaSaveGame.deserialize(partialJson);
      expect(restored.saveSlotName, equals('Minimal'));
      expect(restored.customSaveData, isEmpty);
    });

    test('JSON with saveGameVersion: 0 preserves version for migration hooks', () {
      final rawJson = jsonEncode({
        'saveGameVersion': 0,
        'saveSlotName': 'OldSave',
      });

      final restored = LuminaSaveGame.deserialize(rawJson);
      expect(restored.saveGameVersion, equals(0));
    });
  });
}
