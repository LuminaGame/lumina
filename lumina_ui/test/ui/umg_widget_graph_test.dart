import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Widget Blueprint graph: its document in the widget
/// `.lmas`, Is Variable, the Details `+` binding, and the Graph tab as the
/// Blueprint editor in its widget configuration (real temp project, real
/// WIDGET `.lmas`).
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_graph_test_');
    projectDir = '${tempDir.path}/ClickProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/ClickProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'ClickProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Clicker.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Clicker.lmas';
  });

  tearDown(() {
    LuminaWidgetClassRegistry.clear();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A Button `StartButton` and a Text `Title` on the root canvas.
  ({UmgNode button, UmgNode title}) addClicker(UmgEditorViewModel vm) {
    final button = vm.addWidget(UmgWidgetType.button, parentId: vm.document.root.id, canvasPosition: const Offset(80, 80))!;
    vm.rename(button.id, 'StartButton');
    final title = vm.addWidget(UmgWidgetType.text, parentId: vm.document.root.id, canvasPosition: const Offset(80, 200))!;
    vm.rename(title.id, 'Title');
    return (button: vm.document.findNode(button.id)!, title: vm.document.findNode(title.id)!);
  }

  /// `Get Title → Set Text (Text) "Clicked!"` after [event]'s exec.
  void wireSetText(UmgEditorViewModel vm, LuminaBlueprintNode event) {
    final graph = vm.graphEditor.eventGraph;
    final get = graph.addNode(LuminaBlueprintNodeLibrary.getWidgetVariable, const Offset(80, 400), literals: {'element': 'Title'})!;
    final set = graph.addNode('set_element_text', const Offset(400, 300), literals: {'in_text': 'Clicked!'})!;
    expect(graph.addWire(fromNodeId: event.id, fromPinId: 'exec_out', toNodeId: set.id, toPinId: 'exec_in'), isNotNull);
    expect(graph.addWire(fromNodeId: get.id, fromPinId: 'return_value', toNodeId: set.id, toPinId: 'target'), isNotNull);
  }

  test('the graph and Is Variable round-trip through the widget .lmas; panels default off, Button / Text on', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final c = addClicker(vm);
    final box = vm.addWidget(UmgWidgetType.verticalBox, parentId: vm.document.root.id, canvasPosition: const Offset(400, 80))!;
    expect(c.button.isVariable, isTrue);
    expect(c.title.isVariable, isTrue);
    expect(vm.document.findNode(box.id)!.isVariable, isFalse);
    expect(vm.document.root.isVariable, isFalse, reason: 'the root is a panel');

    final clicked = vm.bindWidgetEvent(c.button.id, 'OnClicked')!;
    wireSetText(vm, clicked);
    expect(vm.isDirty, isTrue);
    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);

    final payload = jsonDecode(utf8.decode(LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync()).rawPayload!)) as Map;
    expect(payload['blueprint'], isA<Map>());
    expect(payload['blueprint']['parentClass'], LuminaWidgetBlueprintDocument.parentClass);

    final reopened = UmgEditorViewModel(assetPath: lmasPath);
    await reopened.load();
    expect(jsonEncode(reopened.graphEditor.document.toJson()), jsonEncode(vm.graphEditor.document.toJson()));
    expect(reopened.graphEditor.boundEventNode('StartButton', 'OnClicked')!.title, 'On Clicked (StartButton)');
    expect(reopened.graphEditor.typeContext.widgetVariables!.map((v) => v.name), ['StartButton', 'Title']);

    // Unticking Title takes it out of the graph's members; its Get is flagged on compile.
    expect(reopened.setIsVariable(reopened.document.variableNodes.last.id, false), isTrue);
    expect(reopened.graphEditor.typeContext.widgetVariables!.map((v) => v.name), ['StartButton']);
    final result = reopened.graphEditor.compileGraph();
    expect(result.ok, isFalse);
    expect(result.errors.map((d) => d.message), contains(contains("no variable 'Title'")));
    vm.dispose();
    reopened.dispose();
  });

  test('Details + creates the bound node once and focuses it; removing the binding removes the node', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final c = addClicker(vm);
    final first = vm.bindWidgetEvent(c.button.id, 'OnClicked')!;
    expect(vm.mode, UmgEditorMode.graph);
    expect(vm.showGeneratedCode, isFalse);
    expect(vm.document.findNode(c.button.id)!.events.map((e) => e.name), ['OnClicked']);
    expect(vm.graphEditor.eventGraph.selectedNodeIds, {first.id});
    expect(vm.isEventBound(c.button.id, 'OnClicked'), isTrue);

    vm.setMode(UmgEditorMode.designer);
    final again = vm.bindWidgetEvent(c.button.id, 'OnClicked')!;
    expect(again.id, first.id, reason: 'a second + (or Open) focuses the same node');
    expect(vm.graphEditor.document.eventGraph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement), hasLength(1));
    expect(vm.bindWidgetEvent(c.title.id, 'OnClicked'), isNull, reason: 'a Text has no OnClicked');

    // Undo in Graph mode undoes the graph, not the designer.
    vm.undo();
    expect(vm.graphEditor.boundEventNode('StartButton', 'OnClicked'), isNull);
    expect(vm.document.findNode(c.button.id)!.events, hasLength(1));
    vm.redo();
    expect(vm.graphEditor.boundEventNode('StartButton', 'OnClicked'), isNotNull);

    expect(vm.removeEvent(c.button.id, 'OnClicked'), isTrue);
    expect(vm.graphEditor.boundEventNode('StartButton', 'OnClicked'), isNull);
    expect(vm.isEventBound(c.button.id, 'OnClicked'), isFalse);

    // Renaming the element renames its graph references.
    vm.bindWidgetEvent(c.button.id, 'OnHovered');
    vm.rename(c.button.id, 'PlayButton');
    expect(vm.graphEditor.boundEventNode('PlayButton', 'OnHovered')!.title, 'On Hovered (PlayButton)');
    vm.dispose();
  });

  test('the palette of a widget graph offers its variables, their events and the lifecycle events, not BeginPlay', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    addClicker(vm);
    final entries = BlueprintPalette.entriesFor(vm.graphEditor.eventGraph.context, null);
    final titles = entries.map((e) => e.title).toSet();
    expect(titles, containsAll(['Event Construct', 'Event Pre Construct', 'Event Destruct', 'Event Tick', 'StartButton', 'Title',
        'On Clicked (StartButton)', 'On Hovered (StartButton)', 'On Unhovered (StartButton)', 'Self', 'Set Text (Text)', 'Remove from Parent']));
    expect(titles, isNot(contains('Event BeginPlay')));
    expect(titles, isNot(contains('On Clicked (Title)')));
    expect(entries.where((e) => e.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement && e.title == 'Get Widget'), isEmpty);
    vm.dispose();
  });

  testWidgets('Graph shows the Blueprint canvas in its widget configuration; View Generated Code shows the source', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    late ({UmgNode button, UmgNode title}) c;
    await tester.runAsync(() async => c = addClicker(vm));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Clicker', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    vm.select(c.button.id);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(ValueKey('umg_is_variable_${c.button.id}')), findsOneWidget);

    // The green + of OnClicked opens the Graph with the bound node.
    final plus = find.byKey(ValueKey('umg_event_add_OnClicked_${c.button.id}'));
    await tester.ensureVisible(plus);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(() async {
      await tester.tap(plus);
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(vm.mode, UmgEditorMode.graph);
    expect(find.byKey(const ValueKey('blueprint_event_graph_canvas')), findsOneWidget);
    expect(find.text('On Clicked (StartButton)'), findsWidgets);
    expect(find.byKey(const ValueKey('bp_my_blueprint')), findsOneWidget);
    expect(find.byKey(const ValueKey('widget_variable_row_StartButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('widget_variable_row_Title')), findsOneWidget);
    expect(find.text('Components'), findsNothing);
    expect(find.text('3D Viewport'), findsNothing);
    expect(find.byKey(const ValueKey('bp_compile')), findsNothing, reason: 'the UMG toolbar is the toolbar');

    // My Blueprint ▸ Widgets: Title dragged onto the canvas is `Get Title`.
    final row = find.byKey(const ValueKey('widget_variable_row_Title'));
    final myBlueprint = find.descendant(of: find.byKey(const ValueKey('bp_my_blueprint')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(row, 80, scrollable: myBlueprint);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final from = tester.getCenter(row);
    final to = tester.getCenter(find.byKey(const ValueKey('blueprint_event_graph_canvas'))) + const Offset(0, 120);
    final drag = await tester.startGesture(from);
    for (var i = 1; i <= 6; i++) {
      await drag.moveTo(from + Offset(12.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 1; i <= 12; i++) {
      await drag.moveTo(Offset.lerp(from + const Offset(72, 0), to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pump(const Duration(milliseconds: 150));
    final gets = vm.graphEditor.document.eventGraph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.getWidgetVariable);
    expect(gets.map((n) => n.title), ['Title']);

    await tester.tap(find.byKey(const ValueKey('umg_view_generated_code')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('umg_graph_source')), findsOneWidget);
    expect(find.textContaining("LuminaUserWidgets.fire(widget.instance, 'StartButton', 'OnClicked');"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('umg_view_generated_code')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('blueprint_event_graph_canvas')), findsOneWidget);
    vm.dispose();
  });

  test('Compile with a graph error shows it on the node and writes nothing; a clean compile writes the graph class', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final c = addClicker(vm);
    final clicked = vm.bindWidgetEvent(c.button.id, 'OnClicked')!;
    wireSetText(vm, clicked);
    final broken = vm.graphEditor.eventGraph.addNode(LuminaBlueprintNodeLibrary.getWidgetVariable, const Offset(80, 600), literals: {'element': 'Gone'})!;
    final output = File('$projectDir/lib/widgets/wbp_clicker.dart');

    await vm.compile();
    expect(vm.compileError, contains("no variable 'Gone'"));
    expect(output.existsSync(), isFalse);
    expect(vm.graphEditor.diagnostics.where((d) => d.isError).map((d) => d.nodeId), contains(broken.id));

    vm.graphEditor.eventGraph.removeNode(broken.id);
    await vm.compile();
    expect(vm.compileError, isNull);
    final src = output.readAsStringSync();
    expect(src, contains('class WbpClickerGraph extends LuminaUserWidget with LuminaBlueprintRuntime {'));
    expect(src, contains("LuminaUserWidgets.fire(widget.instance, 'StartButton', 'OnClicked');"));
    expect(src, contains("case ('StartButton', 'OnClicked'):"));
    final registry = File('$projectDir/lib/widgets/widget_registry.g.dart').readAsStringSync();
    expect(registry, contains("LuminaUserWidgets.register('WBP_Clicker', WbpClickerGraph.new);"));
    vm.dispose();
  });
}
