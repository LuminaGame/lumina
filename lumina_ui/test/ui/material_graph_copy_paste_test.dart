import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_clipboard.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Copy / paste in the material node graph, which shares the Blueprint
/// graph canvas.
void main() {
  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  late Directory project;
  late File material;
  String? clipboard;

  setUp(() async {
    clipboard = null;
    if (!barrel.existsSync()) return;
    project = Directory.systemTemp.createTempSync('material_copy_paste_');
    Directory('${project.path}/contents').createSync();
    await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: barrel.path);
    material = Directory('${project.path}/contents/materials')
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));
  });

  tearDown(() {
    if (barrel.existsSync() && project.existsSync()) project.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await settle(tester);
  }

  testWidgets('a material node copies and pastes; a Blueprint clipboard pastes nothing into the material graph',
      (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    tester.view.physicalSize = const Size(1700, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return clipboard == null ? null : {'text': clipboard};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final vm = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: MaterialSubEditor(assetName: vm.asset!.name, viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Node Graph'));
    await settle(tester);

    final sample = vm.graph.graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.textureSample);
    final canvas = find.byType(BlueprintGraphCanvas);
    await tester.tapAt(tester.getRect(canvas).bottomRight - const Offset(40, 60));
    await settle(tester);
    vm.graph.editor.select(sample.id);
    await settle(tester);

    await ctrl(tester, LogicalKeyboardKey.keyC);
    expect(BlueprintGraphClipboard.decode(clipboard)?.graphKind, BlueprintGraphClipboard.materialKind);
    final before = vm.graph.graph.nodes.length;
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(vm.graph.graph.nodes.where((n) => n.registryId == MaterialNodes.textureSample), hasLength(2));
    expect(vm.graph.graph.nodes.length, before + 1);
    expect(vm.graph.editor.selectedNodeIds.single, isNot(sample.id));

    // Nodes copied from a Blueprint graph never land in a material graph.
    clipboard = BlueprintGraphClipboard(
      graphKind: BlueprintGraphClipboard.blueprintKind,
      nodes: [LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'p', x: 0, y: 0)],
      wires: const [],
    ).encode();
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(vm.graph.graph.nodes.length, before + 1);
    expect(find.textContaining('Blueprint nodes cannot be pasted into a material graph'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
