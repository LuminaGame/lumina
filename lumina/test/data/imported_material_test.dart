import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The shared test-assets checkout (`LUMINA_TEST_ASSETS`, else next to the repo).
String testAssetsPath() =>
    Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';

void main() {
  test('a glTF import writes the material source the public builder produces', () async {
    final barrel = File('${testAssetsPath()}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) {
      markTestSkipped('test-assets missing');
      return;
    }
    final root = Directory.systemTemp.createTempSync('imported_material_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: barrel.path);
    final material = Directory('${root.path}/contents')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
        .firstWhere((a) => a.type == AssetType.filamat);
    List<double> numbers(String key) => material.metadata[key]!.split(',').map(double.parse).toList();
    final source = buildImportedMaterialSource(
      name: material.name,
      baseColor: numbers('baseColor'),
      metallic: double.parse(material.metadata['metallic']!),
      roughness: double.parse(material.metadata['roughness']!),
      emissive: numbers('emissive'),
      textureSlots: [for (final r in material.references) r.slotName],
    );
    expect(material.rawMatSource, source);
  });

  test('an imported material becomes a filamat asset in the glTF import format', () {
    const texture = AssetReference(slotName: 'baseColorMap', assetId: 'tex-1', assetPath: 'contents/T_Barrel.lmas');
    const normal = AssetReference(slotName: 'normalMap', assetId: 'tex-2', assetPath: 'contents/T_Barrel_N.lmas');
    final asset = const ImportedMaterial(
      name: 'M_Barrel',
      baseColor: [0.5, 0.25, 1, 1],
      metallic: 0.2,
      roughness: 0.7,
      emissive: [0, 0, 0],
      textures: [texture, normal],
      metadata: {'unreal_source': '/Game/M_Barrel'},
    ).toAsset(assetId: 'mat-1');
    expect(asset.type, AssetType.filamat);
    expect(asset.assetId, 'mat-1');
    expect(asset.metadata['baseColor'], '0.5,0.25,1.0,1.0');
    expect(asset.metadata['metallic'], '0.2');
    expect(asset.metadata['roughness'], '0.7');
    expect(asset.metadata['emissive'], '0.0,0.0,0.0');
    expect(asset.metadata['unreal_source'], '/Game/M_Barrel');
    expect(asset.references.map((r) => r.slotName), ['baseColorMap', 'normalMap']);
    expect(asset.rawMatSource, contains('materialParams_normalMap'));
    expect(asset.rawMatSource, contains('materialParams_baseColorMap'));
  });
}
