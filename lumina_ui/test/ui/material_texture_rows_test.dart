import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/parameter_panel.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression coverage: a sampler row names its texture with a
/// thumbnail (never the reference's UUID) and assigns only real textures.
void main() {
  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  final banana = File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_long.glb');
  final assetsPresent = barrel.existsSync() && banana.existsSync();

  late Directory project;
  late File material;

  setUp(() async {
    if (!assetsPresent) return;
    project = Directory.systemTemp.createTempSync('material_texture_rows_');
    Directory('${project.path}/contents').createSync();
    for (final source in [barrel, banana]) {
      await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: source.path);
    }
    material = Directory('${project.path}/contents/materials/fuel_barrel_red')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));
  });

  tearDown(() {
    if (assetsPresent && project.existsSync()) project.deleteSync(recursive: true);
  });

  Future<MaterialEditorViewModel> open(WidgetTester tester) async {
    final vm = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Align(
            alignment: Alignment.topLeft,
            // The panel's default width in the Material Editor.
            child: SizedBox(width: 260, height: 900, child: MaterialParameterPanel(viewModel: vm)),
          ),
        ),
      ),
    );
    await tester.pump();
    return vm;
  }

  testWidgets('a texture row names the bound texture with its thumbnail, not its UUID', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    final ref = vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef!;
    expect(ref.assetId, matches(RegExp(r'^[0-9a-f]{8}-')), reason: 'imports reference textures by UUID');

    expect(find.textContaining(ref.assetId), findsNothing, reason: 'the UUID is not a name');
    expect(find.text('T_fuel_barrel_red_loot_barrel_bc.jpg'), findsWidgets);
    expect(find.byKey(const ValueKey('texture_thumbnail_baseColorMap')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the row fits the 260 px panel');
  });

  testWidgets('the texture picker lists the project textures and binds the one picked', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    expect(find.text('Assign'), findsNothing, reason: 'no button that binds a made-up texture path');
    final textures = vm.availableTextures;
    expect(textures.map((t) => t.fileName).toList()..sort(), [
      'T_banana_bunch_long_Banana_Bunch_bc.jpg.lmas',
      'T_fuel_barrel_red_loot_barrel_bc.jpg.lmas',
    ]);

    await tester.tap(find.byKey(const ValueKey('texture_picker_baseColorMap')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T_banana_bunch_long_Banana_Bunch_bc.jpg').last);
    await tester.pumpAndSettle();

    final banana = textures.firstWhere((t) => t.fileName.startsWith('T_banana'));
    final param = vm.parameters.firstWhere((p) => p.name == 'baseColorMap');
    expect(param.textureRef!.assetId, banana.assetId);
    expect(param.textureRef!.assetPath, banana.relativePath, reason: 'stored project-relative');
    expect(File(param.resolvedTexturePath!).existsSync(), isTrue, reason: 'the preview can open it');
    expect(find.text('T_banana_bunch_long_Banana_Bunch_bc.jpg'), findsWidgets);

    expect(await tester.runAsync(vm.save), isTrue);
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(saved.references.single.assetPath, banana.relativePath);
    expect(saved.references.single.assetId, banana.assetId);
  });
}
