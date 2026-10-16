import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_asset_upgrader.dart';
import 'package:path/path.dart' as p;

/// A package Filament 1.77 compiled (flutter_filament's UI overlay material,
/// material version 77), as a material saved before the upgrade carries.
final Uint8List oldPackage = File('test/fixtures/materials/ui_overlay_material_version_77.filamat').readAsBytesSync();

const oldSource = '''
material {
    name : "M_Old",
    shadingModel : unlit,
    variantFilter : [ skinning, directionalLighting ],
    specularAmbientOcclusion : true,
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = float4(getWorldOffset() * 0.0 + float3(0.2, 0.4, 0.6), 1.0);
    }
}
''';

Future<String> writeAsset(Directory dir, String name, {required String source, Uint8List? package, AssetType type = AssetType.filamat}) async {
  final path = p.join(dir.path, '$name.lmas');
  final asset = LuminaAsset(assetId: '$name.lmas', name: name, type: type, rawMatSource: source, rawPayload: package);
  await File(path).writeAsBytes(asset.toProtoBufferBytes());
  return path;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('lumina_material_upgrade_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the fixture is a package of the previous material version', () {
    expect(MaterialAssetUpgrader.packageVersion(oldPackage), 77);
    expect(filamentExpectedMaterialVersion, isNot(77));
  });

  test('a material compiled for an older Filament is migrated, compiled again and written back', () async {
    final path = await writeAsset(dir, 'M_Old', source: oldSource, package: oldPackage);
    final outcome = await MaterialAssetUpgrader().upgrade(path);
    expect(outcome, isNotNull);
    expect(outcome!.upgraded, isTrue, reason: outcome.describe());
    expect(outcome.staleVersion, 77);
    expect(outcome.changes, hasLength(3));
    final saved = LuminaAsset.fromBytes(await File(path).readAsBytes());
    expect(MaterialAssetUpgrader.packageVersion(saved.rawPayload), filamentExpectedMaterialVersion);
    expect(saved.rawMatSource, contains('variantFilter : [ skinning ]'));
    expect(saved.rawMatSource, contains('specularAmbientOcclusion : simple'));
    expect(saved.rawMatSource, isNot(contains('getWorldOffset')));
    expect(saved.metadata['compiled_size'], '${saved.rawPayload!.length}');
    // Upgraded once: a second pass has nothing to do.
    expect(await MaterialAssetUpgrader().upgrade(path), isNull);
  });

  test('a current material is left alone', () async {
    final compiled = FilamentMatc.compile(
      'material { name : "M_Current", shadingModel : unlit }\n'
      'fragment { void material(inout MaterialInputs material) { prepareMaterial(material); } }\n',
      fileName: 'M_Current.mat',
      defaultName: 'M_Current',
    );
    expect(compiled.ok, isTrue, reason: compiled.errorText);
    final path = await writeAsset(dir, 'M_Current', source: 'unused', package: compiled.package);
    final before = await File(path).readAsBytes();
    expect(await MaterialAssetUpgrader().upgrade(path), isNull);
    expect(await File(path).readAsBytes(), before);
  });

  test('a stale material whose source does not compile is reported and not rewritten', () async {
    final path = await writeAsset(dir, 'M_Broken', source: 'material { name : "M_Broken" }\nfragment { nope }\n', package: oldPackage);
    final before = await File(path).readAsBytes();
    final outcome = await MaterialAssetUpgrader().upgrade(path);
    expect(outcome!.upgraded, isFalse);
    expect(outcome.describe(), contains('compiled for material version 77'));
    expect(await File(path).readAsBytes(), before);
  });

  test('a stale material without source is reported, other assets are skipped', () async {
    final noSource = await writeAsset(dir, 'M_NoSource', source: '', package: oldPackage);
    final mesh = await writeAsset(dir, 'SM_Mesh', source: oldSource, type: AssetType.filamesh);
    final outcomes = await MaterialAssetUpgrader().upgradeAll([noSource, mesh]);
    expect(outcomes.single.path, noSource);
    expect(outcomes.single.error, contains('no .mat source'));
  });
}
