import 'dart:io';

import 'package:flutter/gestures.dart' show kPrimaryButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Node Graph tab over a real imported material.
void main() {
  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');

  late Directory project;
  late File material;

  setUp(() async {
    if (!barrel.existsSync()) return;
    project = Directory.systemTemp.createTempSync('material_graph_view_');
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

  Future<MaterialEditorViewModel> open(WidgetTester tester) async {
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
    await _settle(tester);
    return vm;
  }

  Future<void> wire(WidgetTester tester, String from, String to) async {
    final a = tester.getCenter(find.byKey(ValueKey(from)));
    final b = tester.getCenter(find.byKey(ValueKey(to)));
    final g = await tester.startGesture(a, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await g.moveBy(const Offset(12, 0));
    await tester.pump();
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(a, b, i / 8)!);
      await tester.pump();
    }
    await g.up();
    await _settle(tester);
  }

  Future<String> addFromPalette(WidgetTester tester, MaterialEditorViewModel vm, String registryId) async {
    final before = vm.graph.graph.nodes.map((n) => n.id).toSet();
    await tester.tap(find.byKey(const ValueKey('material_graph_add_node')));
    await _settle(tester);
    await tester.tap(find.byKey(ValueKey('palette_entry_$registryId')));
    await _settle(tester);
    return vm.graph.graph.nodes.map((n) => n.id).toSet().difference(before).single;
  }

  testWidgets('the imported material opens as nodes, and a graph edit rewrites the GLSL (undoably)', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    final graph = vm.graph.graph;
    final sample = graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.textureSample);
    expect(sample.literals['parameter'], 'baseColorMap');
    expect(find.byKey(const ValueKey('node_${MaterialNodes.outputNodeId}')), findsOneWidget);
    expect(find.byKey(ValueKey('node_${sample.id}')), findsOneWidget);
    expect(find.text('Texture Sample · baseColorMap'), findsOneWidget);
    expect(vm.isDirty, isFalse, reason: 'looking at the graph changes nothing');

    // Add a Constant3Vector from the palette and wire it into Emissive.
    final tint = await addFromPalette(tester, vm, MaterialNodes.constant3);
    await wire(tester, 'pin_${tint}_out_out', 'pin_${MaterialNodes.outputNodeId}_${MaterialNodes.emissive}_in');
    expect(graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.emissive)?.fromNodeId, tint);
    expect(vm.currentCode, contains('material.emissive = vec4(vec3(1.0, 1.0, 1.0), 1.0);'));
    expect(vm.isDirty, isTrue);

    // The GLSL tab shows the rewritten source.
    await tester.tap(find.text('GLSL Source (.mat)'));
    await _settle(tester);
    expect(find.textContaining('material.emissive = vec4(vec3(1.0, 1.0, 1.0), 1.0);'), findsWidgets);
    await tester.tap(find.text('Node Graph'));
    await _settle(tester);

    // One undo step removes the wire and its line, redo brings both back.
    await tester.tap(find.byKey(const ValueKey('material_graph_undo')));
    await _settle(tester);
    expect(vm.graph.graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.emissive), isNull);
    expect(vm.currentCode, isNot(contains('material.emissive')));
    await tester.tap(find.byKey(const ValueKey('material_graph_redo')));
    await _settle(tester);
    expect(vm.currentCode, contains('material.emissive'));

    // Save, reopen: the node sits where it was.
    final placed = vm.graph.graph.node(tint)!;
    final at = (placed.x, placed.y);
    expect(await tester.runAsync(vm.save), isTrue);
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(saved.metadata['material_graph'], isNotNull);
    final reopened = MaterialEditorViewModel(assetPath: material.path);
    await tester.runAsync(reopened.load);
    reopened.graph.ensureSynced();
    final again = reopened.graph.graph.node(tint);
    expect(again, isNotNull, reason: 'the stored graph is used, ids and all');
    expect((again!.x, again.y), at);
  });

  testWidgets('a type error is a compiler-log row that selects its node, and blocks compiling stale code', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    final c2 = await addFromPalette(tester, vm, MaterialNodes.constant2);
    final before = vm.currentCode;
    await wire(tester, 'pin_${c2}_out_out', 'pin_${MaterialNodes.outputNodeId}_${MaterialNodes.baseColor}_in');

    expect(vm.graph.analysis.errorNodeIds, {MaterialNodes.outputNodeId});
    expect(vm.currentCode, before, reason: 'a graph with errors does not rewrite the source');
    expect(vm.syntaxStatus, contains('Graph Error'));
    expect(await tester.runAsync(vm.compile), isFalse);

    vm.graph.editor.clearSelection();
    await tester.tap(find.text('Base Color expects float3, got float2').last);
    await _settle(tester);
    expect(vm.graph.editor.selectedNodeIds, {MaterialNodes.outputNodeId});

    // Deleting the offending node fixes the graph and the source follows.
    vm.graph.editor.select(c2);
    expect(vm.graph.editor.removeSelected(), isTrue);
    await _settle(tester);
    expect(vm.graph.analysis.hasErrors, isFalse);
  });

  testWidgets('a hand edit in the GLSL tab re-parses into the graph', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    await tester.tap(find.text('GLSL Source (.mat)'));
    await _settle(tester);
    vm.updateCodeFromEditor(vm.currentCode.replaceFirst('vec4(0.8, 0.8, 0.8, 1.0)', 'vec4(0.2, 0.4, 0.8, 1.0)'));
    await tester.tap(find.text('Node Graph'));
    await _settle(tester);
    expect(find.text('0.2, 0.4, 0.8, 1.0'), findsOneWidget);
  });
}

/// Pumps a few frames: the preview's ticker never lets pumpAndSettle settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
