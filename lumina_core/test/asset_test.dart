import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';

void main() {
  _thumbnailNeutrality();
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

/// The generated thumbnails were painted on a blue-tinted card while
/// every editor surface is a neutral grey. This package sits below the editor
/// and cannot import its palette, so the rule is asserted on the source.
void _thumbnailNeutrality() {
  test('generated thumbnail colours carry no hue', () {
    final source = File('lib/data/repositories/asset_repository.dart');
    expect(source.existsSync(), isTrue);
    // The library and its part files (split by domain).
    final lines = [
      ...source.readAsLinesSync(),
      for (final m in RegExp(r"^part '([^']+)';", multiLine: true).allMatches(source.readAsStringSync()))
        ...File('lib/data/repositories/${m.group(1)}').readAsLinesSync(),
    ];

    final tinted = <String>[];
    final literal = RegExp(r'ui\.Color\(0x([0-9A-Fa-f]{8})\)');
    for (final line in lines) {
      for (final match in literal.allMatches(line)) {
        final value = int.parse(match.group(1)!, radix: 16);
        final r = (value >> 16) & 0xFF, g = (value >> 8) & 0xFF, b = value & 0xFF;
        final spread = [r, g, b].reduce((a, c) => a > c ? a : c) -
            [r, g, b].reduce((a, c) => a < c ? a : c);
        // Only the greys matter: an icon may be any colour it likes, but a
        // surface that is meant to be grey must actually be grey.
        final isMeantToBeGrey = r < 0x60 && g < 0x60 && b < 0x60;
        if (isMeantToBeGrey && spread > 4) {
          tinted.add('${match.group(0)} (channel spread $spread) in: ${line.trim()}');
        }
      }
    }

    expect(tinted, isEmpty,
        reason: 'these dark surfaces have a hue; the editor\'s neutrals do '
            'not:\n${tinted.join('\n')}');
  });
}
