import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Texture Sample node shows its texture's thumbnail
/// and name; clicking it opens a searchable picker with thumbnail rows, and
/// the pick is one undo step shared with the parameter panel.
void main() {
  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  final banana = File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_long.glb');
  final assetsPresent = barrel.existsSync() && banana.existsSync();

  late Directory project;
  late File material;

  setUp(() async {
    if (!assetsPresent) return;
    project = Directory.systemTemp.createTempSync('material_node_texture_');
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<MaterialEditorViewModel> openGraph(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1700, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final vm = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: MaterialSubEditor(assetName: vm.asset!.name, viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Node Graph'));
    await settle(tester);
    return vm;
  }

  const barrelTexture = 'T_fuel_barrel_red_loot_barrel_bc.jpg';
  const bananaTexture = 'T_banana_bunch_long_Banana_Bunch_bc.jpg';

  testWidgets('the Texture Sample node shows the bound texture thumbnail and name', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final vm = await openGraph(tester);
    final sample = vm.graph.graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.textureSample);
    final field = find.byKey(ValueKey('node_texture_${sample.id}'));
    expect(field, findsOneWidget);
    expect(find.descendant(of: field, matching: find.text(barrelTexture)), findsOneWidget);
    final thumb = tester.widget<AssetThumbnail>(find.descendant(of: field, matching: find.byType(AssetThumbnail)));
    expect(thumb.bytes, isNotNull, reason: 'the real .lmas thumbnail, not a badge');
    expect(thumb.bytes, isNotEmpty);
  });

  testWidgets('clicking the node thumbnail opens a searchable picker; picking rebinds, undo restores', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final vm = await openGraph(tester);
    final sample = vm.graph.graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.textureSample);
    await tester.tap(find.byKey(ValueKey('node_texture_${sample.id}')));
    await settle(tester);

    expect(find.byKey(const ValueKey('texture_picker_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('texture_picker_item_$barrelTexture.lmas')), findsOneWidget);
    expect(find.byKey(const ValueKey('texture_picker_item_$bananaTexture.lmas')), findsOneWidget);
    expect(find.byKey(const ValueKey('texture_picker_clear')), findsOneWidget);
    // Every row carries a thumbnail.
    expect(find.descendant(of: find.byType(AssetPickerPopup), matching: find.byType(AssetThumbnail)), findsNWidgets(2));

    await tester.enterText(find.byKey(const ValueKey('texture_picker_search')), 'banana');
    await settle(tester);
    expect(find.byKey(const ValueKey('texture_picker_item_$barrelTexture.lmas')), findsNothing);
    expect(find.byKey(const ValueKey('texture_picker_item_$bananaTexture.lmas')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('texture_picker_item_$bananaTexture.lmas')));
    await settle(tester);
    final param = vm.parameters.firstWhere((p) => p.name == 'baseColorMap');
    expect(param.textureRef!.assetPath, endsWith('$bananaTexture.lmas'));
    expect(find.byType(AssetPickerPopup), findsNothing);
    // Node and panel both show the new texture.
    expect(find.descendant(of: find.byKey(ValueKey('node_texture_${sample.id}')), matching: find.text(bananaTexture)), findsOneWidget);
    expect(vm.graph.transactions.undoLabel, 'Undo Set baseColorMap texture');

    vm.graph.undo();
    await settle(tester);
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef!.assetPath, endsWith('$barrelTexture.lmas'));
    expect(find.descendant(of: find.byKey(ValueKey('node_texture_${sample.id}')), matching: find.text(barrelTexture)), findsOneWidget);
    vm.graph.redo();
    await settle(tester);
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef!.assetPath, endsWith('$bananaTexture.lmas'));

    // Save writes the picked texture's real reference.
    expect(await tester.runAsync(vm.save), isTrue);
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(saved.references.single.assetPath, endsWith('$bananaTexture.lmas'));
  });

  testWidgets('the parameter panel uses the same picker, and clear unbinds', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final vm = await openGraph(tester);
    await tester.tap(find.byKey(const ValueKey('texture_picker_baseColorMap')));
    await settle(tester);
    expect(find.byKey(const ValueKey('texture_picker_search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('texture_picker_clear')));
    await settle(tester);
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef, isNull);
    expect(vm.graph.transactions.undoLabel, 'Undo Clear baseColorMap texture');
    final sample = vm.graph.graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.textureSample);
    expect(find.descendant(of: find.byKey(ValueKey('node_texture_${sample.id}')), matching: find.text('Unassigned')), findsOneWidget);
  });
}
