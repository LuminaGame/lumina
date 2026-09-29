import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class TestAudioSubsystem extends LuminaWorldSubsystem {}

void main() {
  group('SubsystemCollection and Binary Serialization Tests', () {
    test('Should register and retrieve world subsystem via SubsystemCollection', () {
      final world = LuminaWorld();
      final collection = LuminaSubsystemCollection();
      final audioSys = TestAudioSubsystem();

      collection.registerSubsystem<TestAudioSubsystem>(audioSys, world);
      expect(audioSys.isInitialized, isTrue);

      final retrieved = collection.getSubsystem<TestAudioSubsystem>();
      expect(retrieved, equals(audioSys));
    });

    test('Should serialize and deserialize LuminaAsset to binary Protobuf bytes with LMAS magic header', () {
      final asset = LuminaAsset(
        assetId: 'test_uuid_123',
        name: 'BinaryMesh',
        type: AssetType.filamesh,
        rawPayload: Uint8List.fromList([1, 2, 3, 4, 5]),
        metadata: const {'test_key': 'test_val'},
      );

      final bytes = asset.toProtoBufferBytes();
      expect(bytes.length, greaterThan(4));
      expect(bytes[0], equals(0x4C)); // 'L'
      expect(bytes[1], equals(0x4D)); // 'M'
      expect(bytes[2], equals(0x41)); // 'A'
      expect(bytes[3], equals(0x53)); // 'S'

      final restored = LuminaAsset.fromBytes(bytes);
      expect(restored.assetId, equals('test_uuid_123'));
      expect(restored.name, equals('BinaryMesh'));
      expect(restored.type, equals(AssetType.filamesh));
      expect(restored.metadata['test_key'], equals('test_val'));
    });
  });
}
