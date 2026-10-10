import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Keys typed into a text field inside the graph belong to the field: Delete
/// and Backspace edit the text instead of deleting the selected node, and
/// Ctrl+Z does not undo the graph.
void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('bp_text_keys_');
    Directory('${project.path}/lib/actors').createSync(recursive: true);
    File('${project.path}/my_project.lmproject').writeAsStringSync('{}');
  });

  tearDown(() {
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  Future<({BlueprintEditorViewModel vm, String printId})> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final file = File('${project.path}/contents/blueprints/BP_Keys.lmas')..parent.createSync(recursive: true);
    final vm = BlueprintEditorViewModel(
      assetPath: file.path,
      initialAsset: LuminaAsset(assetId: 'BP_Keys', name: 'BP_Keys', type: AssetType.actor),
    );
    final print = vm.addGraphNode('print_string', const Offset(60, 60))!;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_Keys', assetPath: file.path, viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return (vm: vm, printId: print.id);
  }

  Finder field(String nodeId) =>
      find.descendant(of: find.byKey(ValueKey('literal_${nodeId}_in_string_0')), matching: find.byType(EditableText));

  Future<void> focusField(WidgetTester tester, BlueprintEditorViewModel vm, String nodeId) async {
    vm.eventGraph.select(nodeId);
    await tester.tap(field(nodeId));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.eventGraph.selectedNodeIds, contains(nodeId));
  }

  String text(WidgetTester tester, String nodeId) => tester.widget<EditableText>(field(nodeId)).controller.text;

  testWidgets('Backspace in a node\'s text field removes a character and keeps the node', (tester) async {
    final (:vm, :printId) = await open(tester);
    await focusField(tester, vm, printId);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(vm.eventGraph.node(printId), isNotNull, reason: 'Backspace in the field deleted the node');
    expect(text(tester, printId), 'Hello Lumin');
  });

  testWidgets('Delete in a node\'s text field removes the next character and keeps the node', (tester) async {
    final (:vm, :printId) = await open(tester);
    await focusField(tester, vm, printId);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(vm.eventGraph.node(printId), isNotNull, reason: 'Delete in the field deleted the node');
    expect(text(tester, printId), 'ello Lumina');
  });

  testWidgets('Ctrl+Z, Ctrl+D and Ctrl+V in a node\'s text field leave the graph alone', (tester) async {
    final (:vm, :printId) = await open(tester);
    final begin = vm.addGraphNode('event_beginplay', const Offset(60, 300))!;
    await tester.pump();
    await focusField(tester, vm, printId);
    final before = vm.eventGraph.nodes.map((n) => n.id).toList();

    for (final key in [LogicalKeyboardKey.keyZ, LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyV]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    expect(vm.eventGraph.nodes.map((n) => n.id).toList(), before);
    expect(vm.eventGraph.node(begin.id), isNotNull, reason: 'Ctrl+Z in the field undid the graph');
  });

  testWidgets('with the canvas focused Delete still deletes the selected node', (tester) async {
    final (:vm, :printId) = await open(tester);
    final canvas = find.byKey(const ValueKey('blueprint_event_graph_canvas'));
    final box = tester.getRect(canvas);
    await tester.tapAt(box.bottomRight - const Offset(60, 60));
    await tester.pump();
    vm.eventGraph.select(printId);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(vm.eventGraph.node(printId), isNull);
  });
}
