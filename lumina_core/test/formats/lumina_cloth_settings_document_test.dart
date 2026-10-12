import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// Cloth settings assets: the document round-trips through a real `.lmas`
/// file, clamps what an editor or a hand-edited file gives it, and reads
/// defaults from an empty or broken payload.
void main() {
  test('a cloth settings asset round-trips through a .lmas file', () async {
    final dir = await Directory.systemTemp.createTemp('cloth_settings_');
    addTearDown(() => dir.delete(recursive: true));
    const doc = LuminaClothSettingsDocument(
      massKg: 0.4,
      stiffness: 0.8,
      bendStiffness: 0.05,
      iterations: 12,
      windDrag: 2.5,
      inertiaScale: 0.3,
      selfCollision: true,
      selfCollisionDistance: 3,
    );
    final file = File('${dir.path}/CS_Silk.lmas');
    await file.writeAsBytes(doc.toAsset(name: 'CS_Silk').toProtoBufferBytes());
    final asset = LuminaAsset.fromBytes(await file.readAsBytes());
    expect(asset.type, AssetType.clothSettings);
    expect(asset.name, 'CS_Silk');
    final back = LuminaClothSettingsDocument.fromAsset(asset);
    expect(back, doc);
    expect(back.iterations, 12);
    expect(back.selfCollision, isTrue);
  });

  test('values are clamped to their ranges and missing keys take the defaults', () {
    final doc = LuminaClothSettingsDocument.fromProperties({'stiffness': 4.0, 'iterations': 0, 'massKg': -1, 'selfCollision': true});
    expect(doc.stiffness, 1.0);
    expect(doc.iterations, 1);
    expect(doc.massKg, 0.01);
    expect(doc.damping, const LuminaClothSettingsDocument().damping);
    expect(doc.withValue('windTurbulence', 0.75).windTurbulence, 0.75);
    expect(doc.withValue('windTurbulence', 0.75).selfCollision, isTrue);
    for (final key in LuminaClothSettingsDocument.ranges.keys) {
      expect(doc.toProperties().containsKey(key), isTrue, reason: key);
    }
  });

  test('an asset without settings, or with a broken payload, reads the defaults', () {
    const empty = LuminaAsset(assetId: 'a', name: 'CS_Empty', type: AssetType.clothSettings);
    expect(LuminaClothSettingsDocument.fromAsset(empty), const LuminaClothSettingsDocument());
    final broken = LuminaAsset(assetId: 'b', name: 'CS_Broken', type: AssetType.clothSettings, rawPayload: Uint8List.fromList(utf8.encode('not json')));
    expect(LuminaClothSettingsDocument.fromAsset(broken), const LuminaClothSettingsDocument());
  });
}
