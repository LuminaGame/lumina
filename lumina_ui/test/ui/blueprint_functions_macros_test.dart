import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Size, ValueKey;
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Scaffold;

import '../helpers/blueprint_test_project.dart';

/// User functions, macros, local variables and
/// collapse / expand on a real project.
void main() {
  late BlueprintTestProject project;
  late BlueprintEditorViewModel vm;

  setUpAll(() => project = BlueprintTestProject.create());
  tearDownAll(() => project.dispose());

  setUp(() async {
    final path = project.createBlueprint('BP_Health', parentClass: 'LuminaActor');
    vm = BlueprintEditorViewModel(assetPath: path);
    await vm.load();
  });
  tearDown(() => vm.dispose());

  bool wired(BlueprintEditorViewModel vm, BlueprintGraphRef ref, String from, String fromPin, String to, String toPin) =>
      vm.graphEditor(ref).wires.any((w) => w.fromNodeId == from && w.fromPinId == fromPin && w.toNodeId == to && w.toPinId == toPin);

  test('+ New Function AddHealth opens a tab with an entry; inputs and outputs update entry, result and the call node', () async {
    final name = vm.addFunction('AddHealth');
    expect(name, 'AddHealth');
    expect(vm.activeGraph, const BlueprintGraphRef.function('AddHealth'), reason: 'the new function opens as a tab');
    expect(vm.selectedFunction, 'AddHealth');
    expect(vm.graphs, contains(const BlueprintGraphRef.function('AddHealth')));
    final fn = vm.document.function('AddHealth')!;
    final entry = fn.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry);
    expect(fn.graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult), isEmpty, reason: 'no outputs yet');

    expect(vm.setFunctionInputs('AddHealth', [const LuminaBlueprintVariable(name: 'Amount', typeName: 'Float', defaultValue: 0.0)]), isTrue);
    expect(vm.setFunctionOutputs('AddHealth', [const LuminaBlueprintVariable(name: 'NewHealth', typeName: 'Float', defaultValue: 0.0)]), isTrue);
    final editor = vm.graphEditor(const BlueprintGraphRef.function('AddHealth'));
    expect(editor.pin(entry.id, 'Amount', output: true)!.type, LuminaPinType.float, reason: 'the entry exposes the input');
    final result = vm.document.function('AddHealth')!.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult);
    expect(editor.pin(result.id, 'NewHealth', output: false)!.type, LuminaPinType.float, reason: 'a Return Node appeared with the output');

    // Call AddHealth in the palette, with those pins.
    final entryRow = vm.eventGraph.paletteEntries().where((e) => e.key == 'call_function_AddHealth').single;
    expect(entryRow.title, 'Call AddHealth');
    expect(entryRow.category, startsWith('Call Function'));
    final call = vm.eventGraph.placeEntry(entryRow, const Offset(400, 400))!;
    expect(call.registryId, LuminaBlueprintNodeLibrary.callFunction);
    expect(call.title, 'Add Health');
    expect(vm.eventGraph.pinsOf(call).inputs.map((p) => p.id), ['exec_in', 'Amount']);
    expect(vm.eventGraph.pinsOf(call).outputs.map((p) => p.id), ['exec_out', 'NewHealth']);

    // A second input reaches the call too; a wire into a removed input goes.
    final begin = vm.addGraphNode('event_beginplay', const Offset(0, 0))!;
    final tick = vm.addGraphNode('event_tick', const Offset(0, 300))!;
    expect(vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: call.id, toPinId: 'exec_in'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: call.id, toPinId: 'Amount'), isNotNull);
    vm.setFunctionInputs('AddHealth', [
      const LuminaBlueprintVariable(name: 'Amount', typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: 'Reason', typeName: 'String', defaultValue: ''),
    ]);
    expect(vm.eventGraph.pinsOf(call).inputs.map((p) => p.id), ['exec_in', 'Amount', 'Reason']);
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'delta_seconds', call.id, 'Amount'), isTrue);
    vm.setFunctionInputs('AddHealth', [const LuminaBlueprintVariable(name: 'Reason', typeName: 'String', defaultValue: '')]);
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'delta_seconds', call.id, 'Amount'), isFalse, reason: 'Amount is gone');
    vm.undo();
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'delta_seconds', call.id, 'Amount'), isTrue, reason: 'one undo step');

    // Rename propagates to the call; delete removes it.
    expect(vm.renameFunction('AddHealth', 'Heal'), isTrue);
    expect(vm.document.function('Heal'), isNotNull);
    expect(vm.getGraphNode(call.id)!.literals['function'], 'Heal');
    expect(vm.getGraphNode(call.id)!.title, 'Heal');
    expect(vm.activeGraph, const BlueprintGraphRef.function('Heal'));
    expect(vm.renameFunction('Heal', 'Heal'), isFalse);
    expect(vm.renameFunction('Heal', '9bad'), isFalse);
    expect(vm.deleteFunction('Heal'), isTrue);
    expect(vm.getGraphNode(call.id), isNull, reason: 'the call node is removed with the function');
    expect(vm.activeGraph, BlueprintGraphRef.eventGraph, reason: 'the tab closes');
    vm.undo();
    expect(vm.document.function('Heal'), isNotNull);
    expect(vm.getGraphNode(call.id), isNotNull);
  });

  test('a pure function is called by a pure node; local variables are scoped to the function graph', () {
    vm.addFunction('HealthPercent');
    vm.setFunctionOutputs('HealthPercent', [const LuminaBlueprintVariable(name: 'Percent', typeName: 'Float', defaultValue: 0.0)]);
    final call = vm.eventGraph.placeEntry(
        vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'call_function_HealthPercent'), const Offset(300, 300))!;
    expect(vm.setFunctionPure('HealthPercent', true), isTrue);
    final pure = vm.getGraphNode(call.id)!;
    expect(pure.registryId, LuminaBlueprintNodeLibrary.callFunctionPure);
    expect(vm.eventGraph.pinsOf(pure).inputs, isEmpty, reason: 'no exec pins on a pure call');
    expect(vm.eventGraph.pinsOf(pure).outputs.map((p) => p.id), ['Percent']);
    expect(vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'call_function_pure_HealthPercent').kind, LuminaBlueprintNodeKind.pure);
    final fnEditor = vm.graphEditor(const BlueprintGraphRef.function('HealthPercent'));
    final entry = vm.document.function('HealthPercent')!.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry);
    expect(fnEditor.pinsOf(entry).outputs, isEmpty, reason: 'a pure function has no exec entry');

    expect(vm.addLocalVariable('HealthPercent', 'Ratio', 'Float'), 'Ratio');
    expect(fnEditor.paletteEntries().where((e) => e.registryId == LuminaBlueprintNodeLibrary.localVariableGet).map((e) => e.title), ['Get Ratio']);
    expect(vm.eventGraph.paletteEntries().where((e) => e.registryId == LuminaBlueprintNodeLibrary.localVariableGet), isEmpty,
        reason: 'locals are not offered outside their function');
    final get = fnEditor.placeLocalVariable('Ratio', set: false, position: const Offset(200, 200))!;
    expect(fnEditor.pinsOf(get).outputs.single.type, LuminaPinType.float);
    expect(vm.setLocalVariableType('HealthPercent', 'Ratio', 'Int'), isTrue);
    expect(fnEditor.pinsOf(get).outputs.single.type, LuminaPinType.integer);
    expect(vm.renameLocalVariable('HealthPercent', 'Ratio', 'Fraction'), isTrue);
    expect(fnEditor.node(get.id)!.literals['variable'], 'Fraction');
    expect(vm.deleteLocalVariable('HealthPercent', 'Fraction'), isTrue);
    expect(fnEditor.node(get.id), isNull);
    expect(fnEditor.paletteEntries().where((e) => e.kind == LuminaBlueprintNodeKind.event), isEmpty, reason: 'no events inside a function');
  });

  test('+ New Macro gives Inputs / Outputs with exec pins; its call node has them, and renaming follows', () {
    expect(vm.addMacro('ClampAndPrint'), 'ClampAndPrint');
    final macro = vm.document.macro('ClampAndPrint')!;
    final editor = vm.graphEditor(const BlueprintGraphRef.macro('ClampAndPrint'));
    final inputs = macro.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.macroInput);
    final outputs = macro.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.macroOutput);
    expect(editor.pinsOf(inputs).outputs.map((p) => '${p.id}:${p.type.name}'), ['Exec:exec']);
    expect(editor.pinsOf(outputs).inputs.map((p) => '${p.id}:${p.type.name}'), ['Then:exec']);
    vm.setMacroInputs('ClampAndPrint', [
      const LuminaBlueprintVariable(name: 'Exec', typeName: 'Exec'),
      const LuminaBlueprintVariable(name: 'Value', typeName: 'Float', defaultValue: 0.0),
    ]);
    expect(editor.pinsOf(inputs).outputs.map((p) => p.id), ['Exec', 'Value']);
    final call = vm.eventGraph.placeEntry(vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'call_macro_ClampAndPrint'), Offset.zero)!;
    expect(call.title, 'Clamp And Print');
    expect(vm.eventGraph.pinsOf(call).inputs.map((p) => p.id), ['Exec', 'Value']);
    expect(vm.eventGraph.pinsOf(call).outputs.map((p) => p.id), ['Then']);
    expect(vm.renameMacro('ClampAndPrint', 'Clamp'), isTrue);
    expect(vm.getGraphNode(call.id)!.literals['macro'], 'Clamp');
    expect(vm.deleteMacro('Clamp'), isTrue);
    expect(vm.getGraphNode(call.id), isNull);
  });

  test('Collapse to Function DoStuff replaces three nodes with one call keeping the boundary wires; Expand and undo restore them', () async {
    final tick = vm.addGraphNode('event_tick', const Offset(0, 0))!;
    final divide = vm.addGraphNode('float_divide', const Offset(300, 0), literals: {'a': 1.0})!;
    final round = vm.addGraphNode('round', const Offset(600, 0))!;
    final toString = vm.addGraphNode('int_to_string', const Offset(900, 0))!;
    final print = vm.addGraphNode('print_string', const Offset(1200, 0))!;
    expect(vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: print.id, toPinId: 'exec_in'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: divide.id, toPinId: 'b'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: divide.id, fromPinId: 'return_value', toNodeId: round.id, toPinId: 'a'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: round.id, fromPinId: 'return_value', toNodeId: toString.id, toPinId: 'in_int'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: toString.id, fromPinId: 'return_value', toNodeId: print.id, toPinId: 'in_string'), isNotNull);
    final before = vm.document.toFormattedJson();

    vm.selectGraphNodes({divide.id, round.id, toString.id});
    final call = vm.collapseSelection(toMacro: false, name: 'DoStuff');
    expect(call, isNotNull, reason: vm.collapseRefusal);
    expect(vm.graphNodes.map((n) => n.id), unorderedEquals([tick.id, print.id, call!.id]));
    expect(call.registryId, LuminaBlueprintNodeLibrary.callFunction);
    expect(call.literals['function'], 'DoStuff');
    final fn = vm.document.function('DoStuff')!;
    expect(fn.inputs.map((v) => '${v.name}:${v.typeName}'), ['B:Float']);
    expect(fn.outputs.map((v) => '${v.name}:${v.typeName}'), ['ReturnValue:String']);
    expect(fn.graph.nodes.map((n) => n.registryId), containsAll(['float_divide', 'round', 'int_to_string', 'function_entry', 'function_result']));
    expect(fn.graph.nodes, hasLength(5));
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'delta_seconds', call.id, 'B'), isTrue, reason: 'the inbound wire moved to the call');
    expect(wired(vm, BlueprintGraphRef.eventGraph, call.id, 'ReturnValue', print.id, 'in_string'), isTrue, reason: 'the outbound wire too');
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'exec_tick_out', print.id, 'exec_in'), isTrue, reason: 'unrelated wires stay');
    final entry = fn.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry);
    final result = fn.graph.nodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult);
    expect(wired(vm, const BlueprintGraphRef.function('DoStuff'), entry.id, 'B', divide.id, 'b'), isTrue);
    expect(wired(vm, const BlueprintGraphRef.function('DoStuff'), toString.id, 'return_value', result.id, 'ReturnValue'), isTrue);
    expect(wired(vm, const BlueprintGraphRef.function('DoStuff'), divide.id, 'return_value', round.id, 'a'), isTrue, reason: 'inner wires kept');
    expect(vm.findNode(divide.id)!.node.literals['a'], 1.0, reason: 'literals travel with the nodes');
    expect(vm.transactions.undoLabel, 'Undo Collapse to function DoStuff');

    // The collapsed document compiles.
    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);

    // Expand puts the three nodes back, wired as before, and drops the function.
    final restored = vm.expandNode(call.id);
    expect(restored, unorderedEquals([divide.id, round.id, toString.id]));
    expect(vm.document.function('DoStuff'), isNull, reason: 'nothing else called it');
    expect(vm.getGraphNode(call.id), isNull);
    expect(wired(vm, BlueprintGraphRef.eventGraph, tick.id, 'delta_seconds', divide.id, 'b'), isTrue);
    expect(wired(vm, BlueprintGraphRef.eventGraph, divide.id, 'return_value', round.id, 'a'), isTrue);
    expect(wired(vm, BlueprintGraphRef.eventGraph, toString.id, 'return_value', print.id, 'in_string'), isTrue);

    // Undo the expand and the collapse: the original graph is back.
    vm.undo();
    expect(vm.document.function('DoStuff'), isNotNull);
    vm.undo();
    expect(vm.document.function('DoStuff'), isNull);
    expect(vm.document.toFormattedJson(), before, reason: 'undo restores the original document exactly');
  });

  test('Collapse to Macro carries exec pins; a selection with an event or nothing selected is refused', () {
    final begin = vm.addGraphNode('event_beginplay', const Offset(0, 0))!;
    final a = vm.addGraphNode('print_string', const Offset(300, 0), literals: {'in_string': 'a'})!;
    final b = vm.addGraphNode('print_string', const Offset(600, 0), literals: {'in_string': 'b'})!;
    final c = vm.addGraphNode('print_string', const Offset(900, 0), literals: {'in_string': 'c'})!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: a.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: a.id, fromPinId: 'exec_out', toNodeId: b.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: b.id, fromPinId: 'exec_out', toNodeId: c.id, toPinId: 'exec_in');

    vm.clearGraphSelection();
    expect(vm.collapseSelection(toMacro: true), isNull);
    expect(vm.collapseRefusal, isNotNull);
    vm.selectGraphNodes({begin.id, a.id});
    expect(vm.collapseSelection(toMacro: true), isNull, reason: 'events stay in the event graph');

    vm.selectGraphNodes({a.id, b.id});
    final call = vm.collapseSelection(toMacro: true, name: 'PrintTwice')!;
    expect(call.registryId, LuminaBlueprintNodeLibrary.callMacro);
    final macro = vm.document.macro('PrintTwice')!;
    expect(macro.inputs.map((v) => '${v.name}:${v.typeName}'), ['Exec:Exec']);
    expect(macro.outputs.map((v) => '${v.name}:${v.typeName}'), ['Then:Exec']);
    expect(wired(vm, BlueprintGraphRef.eventGraph, begin.id, 'exec_out', call.id, 'Exec'), isTrue);
    expect(wired(vm, BlueprintGraphRef.eventGraph, call.id, 'Then', c.id, 'exec_in'), isTrue);
    expect(vm.expandNode(call.id), unorderedEquals([a.id, b.id]));
    expect(wired(vm, BlueprintGraphRef.eventGraph, begin.id, 'exec_out', a.id, 'exec_in'), isTrue);
    expect(wired(vm, BlueprintGraphRef.eventGraph, b.id, 'exec_out', c.id, 'exec_in'), isTrue);
  });

  test('functions, macros and dispatchers save into the .lmas and load back', () async {
    vm.addFunction('AddHealth');
    vm.setFunctionInputs('AddHealth', [const LuminaBlueprintVariable(name: 'Amount', typeName: 'Float', defaultValue: 0.0)]);
    vm.addLocalVariable('AddHealth', 'Tmp');
    vm.addMacro('Twice');
    vm.addDispatcher('OnHealed');
    expect(await vm.save(), isTrue);
    final doc = readBlueprint(vm.assetPath);
    expect(doc.function('AddHealth')!.inputs.single.name, 'Amount');
    expect(doc.function('AddHealth')!.localVariables.single.name, 'Tmp');
    expect(doc.macro('Twice')!.graph.nodes.map((n) => n.registryId), containsAll(['macro_input', 'macro_output']));
    expect(doc.dispatcher('OnHealed'), isNotNull);
    final reloaded = BlueprintEditorViewModel(assetPath: vm.assetPath);
    await reloaded.load();
    expect(reloaded.graphs.map((g) => g.key), containsAll(['function:AddHealth', 'macro:Twice']));
    reloaded.dispose();
  });

  testWidgets('My Blueprint + New Function opens a graph tab and its Details add an input; Event Dispatchers + adds one', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_Health', assetPath: vm.assetPath, viewModel: vm, showPreviewViewport: false)),
    ));
    await tester.pump();
    await tester.tap(find.text('My Blueprint'));
    await tester.pump();
    expect(find.text('FUNCTIONS'), findsOneWidget);
    expect(find.text('MACROS'), findsOneWidget);
    expect(find.text('EVENT DISPATCHERS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fn_add')));
    await tester.pump();
    expect(vm.activeGraph, const BlueprintGraphRef.function('NewFunction'));
    expect(find.byKey(const ValueKey('graph_tab_function:NewFunction')), findsOneWidget);
    expect(find.byKey(const ValueKey('blueprint_graph_canvas_function:NewFunction')), findsOneWidget);
    expect(find.byKey(const ValueKey('bp_function_details')), findsOneWidget);
    expect(find.text('LOCAL VARIABLES (NEWFUNCTION)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fn_input_add')));
    await tester.pump();
    expect(vm.document.function('NewFunction')!.inputs.map((v) => v.name), ['NewParam']);
    await tester.tap(find.byKey(const ValueKey('fn_output_add')));
    await tester.pump();
    expect(vm.document.function('NewFunction')!.graph.nodes.map((n) => n.registryId), contains('function_result'));
    await tester.tap(find.byKey(const ValueKey('dispatcher_add')));
    await tester.pump();
    expect(vm.document.dispatchers.map((d) => d.name), ['NewEventDispatcher']);
    expect(find.byKey(const ValueKey('bp_dispatcher_details')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('graph_tab_eventGraph:')));
    await tester.pump();
    expect(find.byKey(const ValueKey('blueprint_event_graph_canvas')), findsOneWidget);
  });
}
