import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';

void main() {
  group('LuminaAsset Model & Serialization Tests', () {
    test('Should construct LuminaAsset with correct properties', () {
      final ref = AssetReference(
        slotName: 'material_slot_0',
        assetId: 'mat-1234',
        assetPath: 'contents/materials/M_Test.lmas',
      );

      final asset = LuminaAsset(
        assetId: 'mesh-5678',
        name: 'SM_Chair',
        type: AssetType.filamesh,
        hasThumbnail: true,
        thumbnailPng: Uint8List.fromList([1, 2, 3, 4]),
        rawPayload: Uint8List.fromList([10, 20, 30]),
        rawMatSource: '',
        references: [ref],
        metadata: {'polyCount': '1250'},
      );

      expect(asset.assetId, equals('mesh-5678'));
      expect(asset.name, equals('SM_Chair'));
      expect(asset.type, equals(AssetType.filamesh));
      expect(asset.hasThumbnail, isTrue);
      expect(asset.references.length, equals(1));
      expect(asset.references.first.slotName, equals('material_slot_0'));
      expect(asset.metadata['polyCount'], equals('1250'));
    });

    test('Should serialize to Map/JSON and deserialize back accurately', () {
      final originalAsset = LuminaAsset(
        assetId: 'mat-9988',
        name: 'M_Wood',
        type: AssetType.filamat,
        hasThumbnail: false,
        rawMatSource: 'material { name : M_Wood }',
        references: [],
        metadata: {'shader': 'lit'},
      );

      final map = originalAsset.toMap();
      final jsonStr = jsonEncode(map);
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restoredAsset = LuminaAsset.fromMap(decodedMap);

      expect(restoredAsset.assetId, equals(originalAsset.assetId));
      expect(restoredAsset.name, equals(originalAsset.name));
      expect(restoredAsset.type, equals(AssetType.filamat));
      expect(restoredAsset.rawMatSource, equals('material { name : M_Wood }'));
      expect(restoredAsset.metadata['shader'], equals('lit'));
    });
  });
}
