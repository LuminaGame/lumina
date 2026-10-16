import 'dart:io';

import 'package:flutter_filament/filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_asset_upgrader.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('lumina_material_editor_upgrade_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('opening a material saved before the Filament upgrade rewrites its source and compiles it again', () async {
    const source = '''
material {
    name : "M_Old",
    shadingModel : unlit,
    variantFilter : [ dynamicLighting, skinning ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = float4(0.2, 0.4, 0.6, 1.0);
    }
}
''';
    final path = p.join(dir.path, 'M_Old.lmas');
    final old = File('test/fixtures/materials/ui_overlay_material_version_77.filamat').readAsBytesSync();
    await File(path).writeAsBytes(
      LuminaAsset(assetId: 'M_Old.lmas', name: 'M_Old', type: AssetType.filamat, rawMatSource: source, rawPayload: old)
          .toProtoBufferBytes(),
    );

    final vm = MaterialEditorViewModel(assetPath: path);
    await vm.load();

    expect(vm.currentCode, contains('variantFilter : [ skinning ]'));
    expect('\n'.allMatches(vm.currentCode).length, '\n'.allMatches(source).length);
    expect(MaterialAssetUpgrader.packageVersion(vm.compiledBytes), filamentExpectedMaterialVersion);
    expect(vm.isDirty, isTrue, reason: 'the rewritten source and the new package are not saved yet');

    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);
    final saved = LuminaAsset.fromBytes(await File(path).readAsBytes());
    expect(MaterialAssetUpgrader.packageVersion(saved.rawPayload), filamentExpectedMaterialVersion);
    expect(saved.rawMatSource, isNot(contains('dynamicLighting')));
    vm.dispose();
  });

  test('a compiled package of another material version alone is compiled again and marks the editor dirty', () async {
    const source = 'material { name : "M_Same", shadingModel : unlit }\n'
        'fragment { void material(inout MaterialInputs material) { prepareMaterial(material); } }\n';
    final path = p.join(dir.path, 'M_Same.lmas');
    final old = File('test/fixtures/materials/ui_overlay_material_version_77.filamat').readAsBytesSync();
    await File(path).writeAsBytes(
      LuminaAsset(assetId: 'M_Same.lmas', name: 'M_Same', type: AssetType.filamat, rawMatSource: source, rawPayload: old)
          .toProtoBufferBytes(),
    );
    final vm = MaterialEditorViewModel(assetPath: path);
    await vm.load();
    expect(vm.currentCode, source);
    expect(MaterialAssetUpgrader.packageVersion(vm.compiledBytes), filamentExpectedMaterialVersion);
    expect(vm.isDirty, isTrue);
    vm.dispose();
  });
}
