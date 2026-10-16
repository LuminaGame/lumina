import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const scenario = 'Material Post Lighting Smoke: an unlit barrel material blends its post lighting colour by the mix';

/// The Post Lighting Color and Mix the Material node and the `.mat` language
/// offer for unlit materials: a real imported barrel material made unlit, a
/// blue post lighting colour blended over its texture by a `postMix`
/// parameter. Driving the mix from 0 to 1 turns the preview blue; the
/// Post Lighting setting rewrites `postLightingBlending` and recompiles.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('needs ${barrel.path}');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_post_lighting_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    Directory('${root.path}/contents').createSync();
    await tester.runAsync(() => AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: barrel.path));
    final material = Directory('${root.path}/contents/materials/fuel_barrel_red')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));
    final imported = LuminaAsset.fromBytes(material.readAsBytesSync());

    // Unlit, with a post lighting colour mixed in by a parameter.
    final source = imported.rawMatSource
        .replaceFirst(RegExp(r'shadingModel\s*:\s*lit'), 'shadingModel : unlit')
        .replaceFirst(RegExp(r'parameters\s*:\s*\['),
            'parameters : [\n    { type : float, name : postMix },\n    { type : float3, name : postTint },')
        .replaceFirst(RegExp(r'\n\s*material\.metallic = [^;]*;'), '')
        .replaceFirst(RegExp(r'\n\s*material\.roughness = [^;]*;'), '')
        .replaceFirstMapped(
          RegExp(r'material\.baseColor \*= [^;]*;'),
          (m) => '${m[0]}'
              '\n    material.postLightingColor = vec4(materialParams.postTint, 1.0);'
              '\n    material.postLightingMixFactor = materialParams.postMix;',
        );
    expect(source, contains('postLightingMixFactor'));
    material.writeAsBytesSync(LuminaAsset(
      assetId: imported.assetId,
      name: imported.name,
      type: imported.type,
      rawMatSource: source,
      references: imported.references,
      metadata: imported.metadata,
    ).toProtoBufferBytes());

    final vm = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(vm.load);
    expect(vm.syntaxStatus, startsWith('Compile OK'), reason: vm.issues.map((i) => i.message).join('\n'));
    vm.setParam('postTint', [0.05, 0.25, 1.0]);
    vm.setParam('postMix', 0.0);

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
    expect(find.text('Post Lighting'), findsOneWidget, reason: 'the settings show the post lighting blend mode');
    await rec.hold(const Duration(milliseconds: 2000));

    final plain = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_post_lighting_mix_0', plain, usedAssets: [barrel.path]);

    // Mix 0 -> 1 over two seconds: the blue post lighting colour takes over.
    for (var i = 1; i <= 40; i++) {
      vm.setParam('postMix', i / 40);
      await rec.hold(const Duration(milliseconds: 50));
    }
    await rec.hold(const Duration(milliseconds: 800));
    final blue = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_post_lighting_mix_1', blue, usedAssets: [barrel.path]);
    final before = _blueShare(tester, plain), after = _blueShare(tester, blue);
    // The sphere covers about a quarter of the preview (grid and sky around it).
    expect(after, greaterThan(before + 0.15), reason: 'blue share $before -> $after');

    // Half way, then switch the blend mode in the settings: the header is
    // rewritten and the material compiles again.
    vm.setParam('postMix', 0.5);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.runAsync(() => vm.updateHeaderSettings(postLightingBlending: 'add'));
    expect(vm.currentCode, contains('postLightingBlending : add'));
    expect(vm.syntaxStatus, startsWith('Compile OK'));
    final c = tester.getCenter(find.byType(FilamentWidget));
    await rec.drag(c - const Offset(100, 0), c + const Offset(100, 0), steps: 60);
    while (rec.recorded < const Duration(milliseconds: 10500)) {
      await rec.hold(const Duration(milliseconds: 250));
    }
    final added = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_post_lighting_add', added, usedAssets: [barrel.path]);
    rec.save(scenario, usedAssets: [barrel.path]);
  });
}

/// The share of preview pixels whose blue clearly leads red and green.
double _blueShare(WidgetTester tester, Uint8List png) {
  final d = img.decodePng(png)!;
  final rect = tester.getRect(find.byType(FilamentWidget)).deflate(12);
  var n = 0, blue = 0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += 3) {
    for (var x = rect.left.round(); x < rect.right.round(); x += 3) {
      final p = d.getPixel(x.clamp(0, d.width - 1), y.clamp(0, d.height - 1));
      n++;
      if (p.b > p.r + 40 && p.b > p.g + 20) blue++;
    }
  }
  return blue / n;
}
