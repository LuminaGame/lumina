import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget, filamentExpectedMaterialVersion;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_asset_upgrader.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const scenario = 'Material Filament upgrade Smoke: a material saved before the upgrade opens, is rewritten and previews';

/// A material a project saved before the Filament upgrade: its compiled
/// package is one Filament 1.77 built (material version 77, which the linked
/// engine refuses) and its header uses variant filters and a value spelling
/// 1.78 no longer takes. Opening it in the Material Editor rewrites the
/// source, compiles it again and the preview draws it; Save writes the
/// current package. The material comes from a real import of a barrel.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('needs ${barrel.path}');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_mat_upgrade_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    Directory('${root.path}/contents').createSync();
    await tester.runAsync(() => AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: barrel.path));
    final material = Directory('${root.path}/contents/materials/fuel_barrel_red')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));

    // The state a pre-upgrade save left on disk.
    final imported = LuminaAsset.fromBytes(material.readAsBytesSync());
    final old = File('test/fixtures/materials/ui_overlay_material_version_77.filamat').readAsBytesSync();
    final oldSource = imported.rawMatSource.replaceFirst(
      RegExp(r'material\s*\{\n'),
      'material {\n    variantFilter : [ directionalLighting, dynamicLighting, skinning ],\n'
          '    specularAmbientOcclusion : true,\n',
    );
    expect(oldSource, contains('directionalLighting'));
    material.writeAsBytesSync(LuminaAsset(
      assetId: imported.assetId,
      name: imported.name,
      type: imported.type,
      rawPayload: old,
      rawMatSource: oldSource,
      references: imported.references,
      metadata: imported.metadata,
    ).toProtoBufferBytes());
    expect(MaterialAssetUpgrader.packageVersion(old), 77);

    final vm = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(vm.load);
    expect(vm.currentCode, isNot(contains('directionalLighting')));
    expect(vm.currentCode, isNot(contains('dynamicLighting')));
    expect(vm.currentCode, contains('variantFilter : [ skinning ]'));
    expect(vm.currentCode, contains('specularAmbientOcclusion : simple'));
    expect('\n'.allMatches(vm.currentCode).length, '\n'.allMatches(oldSource).length);
    expect(MaterialAssetUpgrader.packageVersion(vm.compiledBytes), filamentExpectedMaterialVersion);
    expect(vm.isDirty, isTrue);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(width: 1400, height: 820, child: MaterialSubEditor(assetName: imported.name, viewModel: vm)),
        ),
      ),
    ));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    for (var i = 0; i < 300 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(find.byType(FilamentWidget), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 2500));

    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_filament_upgrade_preview', png, usedAssets: [barrel.path]);
    final stats = _previewStats(tester, png);
    // The barrel's base colour map is mostly grey-white with a red band: the
    // textured, lit sphere varies, it is not the flat fill of a refused material.
    expect(stats.variance, greaterThan(40.0), reason: 'the recompiled material shades the sphere');
    expect(stats.warm, greaterThan(0), reason: 'the red band of the barrel texture shows on the sphere');

    final c = tester.getCenter(find.byType(FilamentWidget));
    await rec.drag(c - const Offset(100, 0), c + const Offset(100, 0), steps: 60);
    for (final shape in ['Cube', 'Cylinder', 'Sphere']) {
      await tester.tap(find.widgetWithText(SecondaryButton, shape));
      await rec.hold(const Duration(milliseconds: 1500));
    }
    await rec.drag(c + const Offset(100, 0), c - const Offset(100, 0), steps: 60);
    while (rec.recorded < const Duration(milliseconds: 10500)) {
      await rec.hold(const Duration(milliseconds: 250));
    }

    expect(await tester.runAsync(vm.save), isTrue);
    expect(vm.isDirty, isFalse);
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(MaterialAssetUpgrader.packageVersion(saved.rawPayload), filamentExpectedMaterialVersion);
    expect(saved.rawMatSource, isNot(contains('directionalLighting')));
    final after = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_filament_upgrade_saved', after, usedAssets: [barrel.path]);
    rec.save(scenario, usedAssets: [barrel.path]);
  });
}

/// Luminance variance and warm (red-leaning) pixel count inside the preview's
/// `FilamentWidget`, read from a boundary PNG captured at pixel ratio 1.
({double variance, int warm, int samples}) _previewStats(WidgetTester tester, Uint8List png) {
  final decoded = img.decodePng(png)!;
  final rect = tester.getRect(find.byType(FilamentWidget)).deflate(12);
  var n = 0, warm = 0;
  var sum = 0.0, sumSq = 0.0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
    for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
      final p = decoded.getPixel(x.clamp(0, decoded.width - 1), y.clamp(0, decoded.height - 1));
      final lum = (p.r + p.g + p.b) / 3.0;
      sum += lum;
      sumSq += lum * lum;
      n++;
      if (p.r > p.b + 25 && p.r > 60) warm++;
    }
  }
  final mean = sum / n;
  return (variance: sumSq / n - mean * mean, warm: warm, samples: n);
}
