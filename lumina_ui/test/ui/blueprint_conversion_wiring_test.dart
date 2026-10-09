import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// Wiring two different pin types in the Blueprint graph inserts the
/// conversion node lumina names for them, as one undo step; other
/// mismatches keep the refusal. Real temp project, real Blueprint `.lmas`.
void main() {
  late BlueprintTestProject project;
  late String assetPath;

  setUp(() {
    project = BlueprintTestProject.create();
    assetPath = project.createBlueprint('BP_Converter');
  });
  tearDown(() => project.dispose());

  Future<BlueprintEditorViewModel> pumpEditor(WidgetTester tester) async {
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: vm.fileBasename, assetPath: vm.assetPath, viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    return vm;
  }

  Finder canvas() => find.byType(BlueprintGraphCanvas);
  BlueprintGraphCanvasState canvasState(WidgetTester tester) => tester.state<BlueprintGraphCanvasState>(canvas());
  Offset pinGlobal(WidgetTester tester, String nodeId, String pinId, {required bool output}) =>
      tester.getTopLeft(canvas()) + canvasState(tester).pinScreenPosition(nodeId, pinId, output: output)!;

  /// Drags from [from] to [to] with the mouse; [whileOver] runs with the
  /// pointer over the target, before the release.
  Future<void> dragWire(WidgetTester tester, Offset from, Offset to, {void Function()? whileOver}) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    whileOver?.call();
    await g.up();
    await tester.pumpAndSettle();
  }

  /// Two nodes side by side in view: [fromId]'s output, [toId]'s input.
  Future<(LuminaBlueprintNode, LuminaBlueprintNode)> pair(
      WidgetTester tester, BlueprintEditorViewModel vm, String fromId, String toId, double y) async {
    final from = vm.eventGraph.addNode(fromId, Offset(-400, y))!;
    final to = vm.eventGraph.addNode(toId, Offset(0, y))!;
    canvasState(tester).frameCanvasPoint(Offset(-100, y + 40));
    await tester.pumpAndSettle();
    return (from, to);
  }

  testWidgets('an integer output dropped on a float input inserts To Float (Integer) as one undo step', (tester) async {
    final vm = await pumpEditor(tester);
    final (rnd, abs) = await pair(tester, vm, 'random_integer_in_range', 'float_abs', 1200);
    final before = jsonEncode(vm.document.eventGraph.toJson());

    String? tooltip;
    await dragWire(tester, pinGlobal(tester, rnd.id, 'return_value', output: true), pinGlobal(tester, abs.id, 'a', output: false),
        whileOver: () => tooltip = tester.widgetList<Text>(find.byKey(const ValueKey('wire_drag_hint'))).firstOrNull?.data);
    expect(tooltip, contains('To Float (Integer)'), reason: 'the drag says what it will insert');
    expect(find.text('Cannot connect integer to float.'), findsNothing);

    final conv = vm.graphNodes.singleWhere((n) => n.registryId == 'int_to_float');
    final wires = vm.graphWires;
    expect(wires.any((w) => w.fromNodeId == rnd.id && w.toNodeId == conv.id && w.toPinId == 'a'), isTrue);
    expect(wires.any((w) => w.fromNodeId == conv.id && w.fromPinId == 'return_value' && w.toNodeId == abs.id && w.toPinId == 'a'),
        isTrue);
    expect(wires.any((w) => w.fromNodeId == rnd.id && w.toNodeId == abs.id), isFalse, reason: 'no direct wire');
    expect(conv.x, inExclusiveRange(rnd.x, abs.x), reason: 'placed between the two pins');
    expect(vm.transactions.undoLabel, 'Undo Insert To Float (Integer)');

    final after = jsonEncode(vm.document.eventGraph.toJson());
    vm.undo();
    await tester.pumpAndSettle();
    expect(jsonEncode(vm.document.eventGraph.toJson()), before, reason: 'one undo removes the node and both wires');
    vm.redo();
    await tester.pumpAndSettle();
    expect(jsonEncode(vm.document.eventGraph.toJson()), after);
    vm.dispose();
  });

  testWidgets('float → integer inserts Truncate and says the fraction is dropped', (tester) async {
    final vm = await pumpEditor(tester);
    final (fabs, iabs) = await pair(tester, vm, 'float_abs', 'int_abs', 1500);
    String? tooltip;
    await dragWire(tester, pinGlobal(tester, fabs.id, 'return_value', output: true), pinGlobal(tester, iabs.id, 'a', output: false),
        whileOver: () => tooltip = tester.widgetList<Text>(find.byKey(const ValueKey('wire_drag_hint'))).firstOrNull?.data);
    expect(tooltip, allOf(contains('Truncate'), contains('fraction')));
    final conv = vm.graphNodes.singleWhere((n) => n.registryId == 'truncate');
    expect(vm.graphWires.any((w) => w.fromNodeId == conv.id && w.toNodeId == iabs.id && w.toPinId == 'a'), isTrue);
    expect(find.byKey(const ValueKey('conversion_lossy_toast')), findsOneWidget);
    expect(find.textContaining('drops the fraction'), findsWidgets);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    vm.dispose();
  });

  testWidgets('bool → integer and integer → string insert their nodes; string → integer keeps the refusal', (tester) async {
    final vm = await pumpEditor(tester);
    final (b, i) = await pair(tester, vm, 'random_bool_with_weight', 'int_abs', 1800);
    await dragWire(tester, pinGlobal(tester, b.id, 'return_value', output: true), pinGlobal(tester, i.id, 'a', output: false));
    expect(vm.graphNodes.where((n) => n.registryId == 'bool_to_int'), hasLength(1));

    final (n, s) = await pair(tester, vm, 'random_integer_in_range', 'string_length', 2100);
    await dragWire(tester, pinGlobal(tester, n.id, 'return_value', output: true), pinGlobal(tester, s.id, 's', output: false));
    expect(vm.graphNodes.where((n) => n.registryId == 'int_to_string'), hasLength(1));

    final (str, iabs) = await pair(tester, vm, 'string_trim', 'int_abs', 2400);
    final before = jsonEncode(vm.document.eventGraph.toJson());
    String? refusal;
    await dragWire(tester, pinGlobal(tester, str.id, 'return_value', output: true), pinGlobal(tester, iabs.id, 'a', output: false),
        whileOver: () => refusal = tester.widgetList<Text>(find.byKey(const ValueKey('wire_drag_refusal'))).firstOrNull?.data);
    expect(refusal, 'Cannot connect string to integer.');
    expect(jsonEncode(vm.document.eventGraph.toJson()), before, reason: 'nothing inserted, nothing wired');
    vm.dispose();
  });

  testWidgets('addWire stays strict: scripts and MCP never insert a node', (tester) async {
    final vm = await pumpEditor(tester);
    final (rnd, abs) = await pair(tester, vm, 'random_integer_in_range', 'float_abs', 1200);
    expect(vm.eventGraph.addWire(fromNodeId: rnd.id, fromPinId: 'return_value', toNodeId: abs.id, toPinId: 'a'), isNull);
    expect(vm.graphNodes.where((n) => n.registryId == 'int_to_float'), isEmpty);
    // connectPins (a canvas drop) converts.
    expect(
        vm.eventGraph.connectPins(BlueprintPinRef.of(rnd.id, vm.eventGraph.pin(rnd.id, 'return_value', output: true)!, isOutput: true),
            BlueprintPinRef.of(abs.id, vm.eventGraph.pin(abs.id, 'a', output: false)!, isOutput: false)),
        isNotNull);
    expect(vm.graphNodes.where((n) => n.registryId == 'int_to_float'), hasLength(1));
    vm.dispose();
  });

  test('the Widget Blueprint graph converts through the same editor', () async {
    final dir = Directory.systemTemp.createTempSync('umg_conv_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final projectDir = '${dir.path}/ConvProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/ConvProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'ConvProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Counter.lmas', type: AssetType.widget);
    final vm = UmgEditorViewModel(assetPath: '$projectDir/contents/widgets/WBP_Counter.lmas');
    await vm.load();
    final graph = vm.graphEditor.eventGraph;
    final rnd = graph.addNode('random_integer_in_range', const Offset(0, 400))!;
    final abs = graph.addNode('float_abs', const Offset(400, 400))!;
    final before = jsonEncode(vm.graphEditor.document.toJson());
    final wire = graph.connectPins(BlueprintPinRef.of(rnd.id, graph.pin(rnd.id, 'return_value', output: true)!, isOutput: true),
        BlueprintPinRef.of(abs.id, graph.pin(abs.id, 'a', output: false)!, isOutput: false));
    expect(wire, isNotNull);
    final conv = graph.nodes.singleWhere((n) => n.registryId == 'int_to_float');
    expect(wire!.fromNodeId, conv.id);
    vm.graphEditor.undo();
    expect(jsonEncode(vm.graphEditor.document.toJson()), before);
  });
}
