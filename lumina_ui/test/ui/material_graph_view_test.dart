import 'dart:io';

import 'package:flutter/gestures.dart' show kPrimaryButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
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

  Future<String> addFromPalette(WidgetTester tester, MaterialEditorViewModel vm, String registryId, {String? search}) async {
    final before = vm.graph.graph.nodes.map((n) => n.id).toSet();
    await tester.tap(find.byKey(const ValueKey('material_graph_add_node')));
    await _settle(tester);
    if (search != null) {
      await tester.enterText(find.byKey(const ValueKey('palette_search')), search);
      await _settle(tester);
    }
    await tester.tap(find.byKey(ValueKey('palette_entry_$registryId')).first);
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

  testWidgets('Set Vertex Variable and Vertex Variable from the palette write the vertex block; Details pick and rename',
      (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    final setter = await addFromPalette(tester, vm, MaterialNodes.setVertexVariable, search: 'vertex variable');
    expect(vm.graph.graph.node(setter)!.literals['name'], 'Var');
    expect(find.text('Set Vertex Variable · Var'), findsOneWidget);
    final uv = await addFromPalette(tester, vm, MaterialNodes.textureCoordinate, search: 'texcoord');
    await wire(tester, 'pin_${uv}_out_out', 'pin_${setter}_value_in');
    final reader = await addFromPalette(tester, vm, MaterialNodes.vertexVariable, search: 'vertex variable');
    expect(vm.graph.graph.node(reader)!.literals['name'], 'Var', reason: 'a new reader takes the variable the material has');
    await wire(tester, 'pin_${reader}_rgb_out', 'pin_${MaterialNodes.outputNodeId}_${MaterialNodes.emissive}_in');
    expect(vm.graph.analysis.hasErrors, isFalse, reason: '${vm.graph.analysis.diagnostics}');
    expect(vm.currentCode, contains('material.Var = vec4(material.uv0, 0.0, 1.0);'));
    expect(vm.currentCode, contains('material.emissive = vec4(variable_Var.rgb, 1.0);'));
    expect(vm.currentCode, contains('variables : [ Var ]'));

    // The GLSL tab shows the vertex block.
    await tester.tap(find.text('GLSL Source (.mat)'));
    await _settle(tester);
    expect(find.textContaining('void materialVertex(inout MaterialVertexInputs material)'), findsWidgets);
    await tester.tap(find.text('Node Graph'));
    await _settle(tester);

    // The reader's Details list the material's variables.
    vm.graph.editor.clearSelection();
    vm.graph.editor.select(reader);
    await _settle(tester);
    expect(find.byKey(ValueKey('material_details_${reader}_variable')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('material_details_${reader}_variable')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('material_details_variable_option_Var')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await _settle(tester);

    // Renaming the setter in its Details renames the variable everywhere.
    vm.graph.editor.clearSelection();
    vm.graph.editor.select(setter);
    await _settle(tester);
    expect(find.byKey(ValueKey('material_details_${setter}_variable_help')), findsOneWidget);
    final field = find.descendant(of: find.byKey(ValueKey('material_details_${setter}_name_0')), matching: find.byType(TextField));
    await tester.enterText(field.first, 'uvTint');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(vm.graph.graph.node(reader)!.literals['name'], 'uvTint');
    expect(vm.currentCode, contains('material.uvTint = vec4(material.uv0, 0.0, 1.0);'));
    expect(vm.currentCode, contains('variable_uvTint.rgb'));
    expect(vm.currentCode, isNot(contains('variable_Var')));
    expect(await tester.runAsync(vm.compile), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
  });

  testWidgets('the palette lists the Logic nodes, and changing Compare\'s operator on the node rewrites the code',
      (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await open(tester);
    await tester.tap(find.byKey(const ValueKey('material_graph_add_node')));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'condition');
    await _settle(tester);
    expect(find.text('LOGIC'), findsOneWidget);
    for (final id in [
      MaterialLogicNodes.compare,
      MaterialLogicNodes.and,
      MaterialLogicNodes.or,
      MaterialLogicNodes.not,
      MaterialLogicNodes.ifNode,
    ]) {
      expect(find.byKey(ValueKey('palette_entry_$id')), findsOneWidget, reason: id);
    }
    for (final title in ['Compare', 'And', 'Or', 'Not', 'If']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    final cmp = await addFromPalette(tester, vm, MaterialLogicNodes.compare, search: 'compare');
    final branch = await addFromPalette(tester, vm, MaterialLogicNodes.ifNode, search: 'ternary');
    vm.graph.graph.node(branch)!.x -= 260;
    final editor = vm.graph.editor;
    expect(editor.addWire(fromNodeId: cmp, fromPinId: 'out', toNodeId: branch, toPinId: 'condition'), isNotNull);
    expect(
        editor.addWire(fromNodeId: branch, fromPinId: 'out', toNodeId: MaterialNodes.outputNodeId, toPinId: MaterialNodes.roughness),
        isNotNull);
    expect(editor.setLiteral(cmp, 'a', 0.75), isTrue);
    await _settle(tester);
    expect(vm.graph.analysis.hasErrors, isFalse, reason: '${vm.graph.analysis.diagnostics}');
    expect(vm.currentCode, contains('material.roughness = ((0.75 >= 0.0) ? 1.0 : 0.0);'));
    expect(find.text('Compare (A >= B)'), findsOneWidget);

    // The operator select on the node.
    await tester.tap(find.byKey(ValueKey('node_compare_op_$cmp')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('node_compare_op_option_<')));
    await _settle(tester);
    expect(MaterialLogicNodes.operatorOf(vm.graph.graph.node(cmp)!), '<');
    expect(vm.currentCode, contains('material.roughness = ((0.75 < 0.0) ? 1.0 : 0.0);'));
    expect(find.text('Compare (A < B)'), findsOneWidget);

    // The same select in the Details panel.
    editor.clearSelection();
    editor.select(cmp);
    await _settle(tester);
    await tester.tap(find.byKey(ValueKey('material_details_compare_op_$cmp')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('material_details_compare_op_option_!=')));
    await _settle(tester);
    expect(vm.currentCode, contains('material.roughness = ((0.75 != 0.0) ? 1.0 : 0.0);'));
    expect(await tester.runAsync(vm.compile), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
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
