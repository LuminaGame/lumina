import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Copy, cut, paste and duplicate of graph nodes in the Blueprint editor,
/// through the system clipboard.
void main() {
  late Directory project;
  String? clipboard;

  setUp(() {
    project = Directory.systemTemp.createTempSync('bp_copy_paste_');
    Directory('${project.path}/lib/actors').createSync(recursive: true);
    File('${project.path}/my_project.lmproject').writeAsStringSync('{}');
    clipboard = null;
  });

  tearDown(() {
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  /// The test binding has no OS clipboard: keep its text here.
  void useClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return clipboard == null ? null : {'text': clipboard};
      if (call.method == 'Clipboard.hasStrings') return {'value': clipboard != null};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  BlueprintEditorViewModel blueprint(String name) {
    final file = File('${project.path}/contents/blueprints/$name.lmas')..parent.createSync(recursive: true);
    return BlueprintEditorViewModel(
      assetPath: file.path,
      initialAsset: LuminaAsset(assetId: name, name: name, type: AssetType.actor),
    );
  }

  Future<void> mount(WidgetTester tester, BlueprintEditorViewModel vm) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    useClipboard(tester);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          key: ValueKey(vm.assetPath),
          assetName: vm.assetPath.split('/').last.replaceAll('.lmas', ''),
          assetPath: vm.assetPath,
          viewModel: vm,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder canvas() => find.byKey(const ValueKey('blueprint_event_graph_canvas'));

  /// Focuses the canvas (a click on empty space) and selects [ids].
  Future<void> focusAndSelect(WidgetTester tester, BlueprintEditorViewModel vm, Set<String> ids) async {
    await tester.tapAt(tester.getRect(canvas()).bottomRight - const Offset(40, 60));
    await tester.pump();
    vm.eventGraph.selectMany(ids);
    await tester.pump();
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // The clipboard is async: let the platform call and the paste finish.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }

  Future<TestGesture> hover(WidgetTester tester, Offset at) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at - const Offset(1, 1));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(at);
    await tester.pump();
    return mouse;
  }

  Set<String> ids(BlueprintEditorViewModel vm) => {for (final n in vm.eventGraph.nodes) n.id};

  testWidgets('Ctrl+C / Ctrl+V of a multi-selection keeps its internal wire, drops the outside one and selects the copies',
      (tester) async {
    final vm = blueprint('BP_Copy');
    final begin = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final print = vm.addGraphNode('print_string', const Offset(300, 40), literals: {'in_string': 'Copied'})!;
    final delay = vm.addGraphNode('delay', const Offset(620, 40))!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: delay.id, toPinId: 'exec_in');
    await mount(tester, vm);
    await focusAndSelect(tester, vm, {print.id, delay.id});

    await ctrl(tester, LogicalKeyboardKey.keyC);
    expect(clipboard, contains('"format":"lumina.graph-nodes"'));

    final state = tester.state<BlueprintGraphCanvasState>(find.byType(BlueprintGraphCanvas));
    final target = tester.getTopLeft(canvas()) + const Offset(300, 420);
    await hover(tester, target);
    final before = ids(vm);
    final steps = vm.transactions.history().length;
    await ctrl(tester, LogicalKeyboardKey.keyV);

    final added = ids(vm).difference(before);
    expect(added, hasLength(2));
    expect(vm.eventGraph.selectedNodeIds, added);
    final pastedPrint = vm.eventGraph.nodes.firstWhere((n) => added.contains(n.id) && n.registryId == 'print_string');
    final pastedDelay = vm.eventGraph.nodes.firstWhere((n) => added.contains(n.id) && n.registryId == 'delay');
    expect(pastedPrint.literals['in_string'], 'Copied');
    // The copies' top-left node lands under the mouse.
    final local = state.toScreen(Offset(pastedPrint.x, pastedPrint.y));
    expect((local - (target - tester.getTopLeft(canvas()))).distance, lessThan(2));
    expect(pastedDelay.x - pastedPrint.x, delay.x - print.x);
    final into = vm.eventGraph.wires.where((w) => added.contains(w.toNodeId) || added.contains(w.fromNodeId)).toList();
    expect(into, hasLength(1), reason: 'only the wire between the copied nodes is pasted');
    expect(into.single.fromNodeId, pastedPrint.id);
    expect(into.single.toNodeId, pastedDelay.id);

    // One undo step removes the pasted nodes and their wire.
    expect(vm.transactions.history().length, steps + 1);
    vm.undo();
    await tester.pump();
    expect(ids(vm), before);
  });

  testWidgets('Ctrl+X removes the selection in one step and Ctrl+Z brings nodes and wires back', (tester) async {
    final vm = blueprint('BP_Cut');
    final begin = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final print = vm.addGraphNode('print_string', const Offset(300, 40))!;
    final delay = vm.addGraphNode('delay', const Offset(620, 40))!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: delay.id, toPinId: 'exec_in');
    await mount(tester, vm);
    await focusAndSelect(tester, vm, {print.id, delay.id});
    final steps = vm.transactions.history().length;

    await ctrl(tester, LogicalKeyboardKey.keyX);
    expect(ids(vm), {begin.id});
    expect(vm.eventGraph.wires, isEmpty);
    expect(clipboard, contains('print_string'));
    expect(vm.transactions.history().length, steps + 1);

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(ids(vm), {begin.id, print.id, delay.id});
    expect(vm.eventGraph.wires, hasLength(2));

    // The cut nodes paste back, wired to each other.
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(vm.eventGraph.nodes, hasLength(5));
    expect(vm.eventGraph.wires, hasLength(3));
  });

  testWidgets('a copy pastes into another Blueprint, which gains the missing variable in the same undo step',
      (tester) async {
    final a = blueprint('BP_Source');
    final health = a.addVariable('Health', 'Float', 75.0);
    final get = a.addGraphNode('variable_get', const Offset(80, 80), literals: {'variable': health})!;
    final print = a.addGraphNode('print_string', const Offset(320, 80))!;
    await mount(tester, a);
    await focusAndSelect(tester, a, {get.id, print.id});
    await ctrl(tester, LogicalKeyboardKey.keyC);

    final b = blueprint('BP_Target');
    await mount(tester, b);
    await focusAndSelect(tester, b, {});
    expect(b.document.variable('Health'), isNull);
    await ctrl(tester, LogicalKeyboardKey.keyV);

    expect(b.eventGraph.nodes.map((n) => n.registryId).toSet(), {'variable_get', 'print_string'});
    final declared = b.document.variable('Health')!;
    expect(declared.typeName, 'Float');
    expect(declared.defaultValue, 75.0);
    expect(b.eventGraph.problems(b.eventGraph.nodes.firstWhere((n) => n.registryId == 'variable_get')), isEmpty);

    b.undo();
    await tester.pump();
    expect(b.eventGraph.nodes, isEmpty);
    expect(b.document.variable('Health'), isNull);
  });

  testWidgets('a second Event BeginPlay is left out with a toast; the other nodes paste', (tester) async {
    final vm = blueprint('BP_Events');
    final begin = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final print = vm.addGraphNode('print_string', const Offset(300, 40))!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in');
    await mount(tester, vm);
    await focusAndSelect(tester, vm, {begin.id, print.id});
    await ctrl(tester, LogicalKeyboardKey.keyC);
    await ctrl(tester, LogicalKeyboardKey.keyV);

    expect(vm.eventGraph.nodes.where((n) => n.registryId == 'event_beginplay'), hasLength(1));
    expect(vm.eventGraph.nodes.where((n) => n.registryId == 'print_string'), hasLength(2));
    expect(vm.eventGraph.wires, hasLength(1));
    expect(find.byKey(const ValueKey('graph_paste_skipped_toast')), findsOneWidget);
    expect(find.textContaining('Event BeginPlay: this graph already has it'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('text on the clipboard that is not graph nodes pastes nothing and records no step', (tester) async {
    final vm = blueprint('BP_Garbage');
    vm.addGraphNode('print_string', const Offset(300, 40));
    await mount(tester, vm);
    await focusAndSelect(tester, vm, {});
    final before = ids(vm);
    final steps = vm.transactions.history().length;
    for (final text in ['not a graph', '{"format":"lumina.graph-nodes","version":1}', '{"nodes":[{"id":"x","registryId":"delay"}]}']) {
      clipboard = text;
      await ctrl(tester, LogicalKeyboardKey.keyV);
    }
    expect(ids(vm), before);
    expect(vm.transactions.history().length, steps);
  });

  testWidgets('Ctrl+D duplicates 30 units down-right without touching the clipboard; comments and reroutes duplicate',
      (tester) async {
    final vm = blueprint('BP_Duplicate');
    final print = vm.addGraphNode('print_string', const Offset(300, 60))!;
    final delay = vm.addGraphNode('delay', const Offset(700, 60))!;
    final wire = vm.addGraphWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: delay.id, toPinId: 'exec_in')!;
    final dot = vm.eventGraph.insertReroute(wire.id, const Offset(560, 200))!;
    final comment = vm.eventGraph.addComment(position: const Offset(60, 300))!;
    await mount(tester, vm);
    clipboard = 'kept';
    await focusAndSelect(tester, vm, {print.id, dot.id, comment.id});
    await ctrl(tester, LogicalKeyboardKey.keyD);

    expect(clipboard, 'kept');
    expect(vm.eventGraph.nodes, hasLength(7));
    final copies = vm.eventGraph.nodes.where((n) => vm.eventGraph.selectedNodeIds.contains(n.id)).toList();
    expect(copies.map((n) => n.registryId).toSet(), {'print_string', dot.registryId, comment.registryId});
    // Print String → reroute is kept between the copies; reroute → Delay is not.
    final copyIds = {for (final n in copies) n.id};
    expect(vm.eventGraph.wires.where((w) => copyIds.contains(w.fromNodeId) || copyIds.contains(w.toNodeId)), hasLength(1));
    final printCopy = copies.firstWhere((n) => n.registryId == 'print_string');
    expect(Offset(printCopy.x, printCopy.y), const Offset(330, 90));
  });

  testWidgets('the node menu copies and pastes; the canvas palette lists Paste', (tester) async {
    final vm = blueprint('BP_Menu');
    final print = vm.addGraphNode('print_string', const Offset(200, 60))!;
    await mount(tester, vm);
    await focusAndSelect(tester, vm, {print.id});

    final nodeAt = tester.getCenter(find.byKey(ValueKey('node_${print.id}'))) - const Offset(0, 20);
    await tester.tapAt(nodeAt, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('node_menu_copy')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(clipboard, contains('print_string'));

    await tester.tapAt(nodeAt, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('node_menu_duplicate')));
    await tester.pumpAndSettle();
    expect(vm.eventGraph.nodes, hasLength(2));

    final state = tester.state<BlueprintGraphCanvasState>(find.byType(BlueprintGraphCanvas));
    state.openNodePalette(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(find.text('Paste'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('palette_entry_action_paste_nodes')).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(vm.eventGraph.nodes, hasLength(3));
    final pasted = vm.eventGraph.nodes.last;
    expect(state.toScreen(Offset(pasted.x, pasted.y)), const Offset(500, 500));
  });
}
