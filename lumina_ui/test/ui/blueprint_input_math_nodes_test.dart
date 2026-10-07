import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/node_palette.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// Enhanced Input, character, math and variable nodes
/// from lumina's node library, and an honest compile status. Every test runs
/// on a real temp project whose `.lmproject` holds the Third Person input
/// actions, against a real Blueprint `.lmas`.
void main() {
  late BlueprintTestProject project;
  late String assetPath;

  setUp(() {
    project = BlueprintTestProject.create();
    assetPath = project.createBlueprint('BP_Hero');
  });
  tearDown(() => project.dispose());

  Future<BlueprintEditorViewModel> loaded(WidgetTester tester, [String? path]) async {
    final vm = BlueprintEditorViewModel(assetPath: path ?? assetPath);
    await tester.runAsync(vm.load);
    return vm;
  }

  Future<void> pumpEditor(WidgetTester tester, BlueprintEditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: vm.fileBasename, assetPath: vm.assetPath, viewModel: vm)),
    ));
    await tester.pumpAndSettle();
  }

  Finder canvas() => find.byType(BlueprintGraphCanvas);
  BlueprintGraphCanvasState canvasState(WidgetTester tester) => tester.state<BlueprintGraphCanvasState>(canvas());

  Offset pinGlobal(WidgetTester tester, String nodeId, String pinId, {required bool output}) =>
      tester.getTopLeft(canvas()) + canvasState(tester).pinScreenPosition(nodeId, pinId, output: output)!;

  Future<void> dragMouse(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  Future<void> openPaletteAt(WidgetTester tester, Offset global) async {
    await tester.tapAt(global, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  Future<LuminaBlueprintNode> placeFromPalette(WidgetTester tester, BlueprintEditorViewModel vm, String query, String key,
      {required Offset at}) async {
    await openPaletteAt(tester, at);
    await tester.enterText(find.byKey(const ValueKey('palette_search')), query);
    await tester.pumpAndSettle();
    final before = vm.graphNodes.map((n) => n.id).toSet();
    await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
    await tester.pumpAndSettle();
    return vm.graphNodes.firstWhere((n) => !before.contains(n.id));
  }

  Future<void> pickAction(WidgetTester tester, String nodeId, String action) async {
    await tester.tap(find.byKey(ValueKey('node_action_select_$nodeId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('action_item_$action')).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the palette lists every library node; "movement" and "yaw" find the pawn input nodes', (tester) async {
    final vm = await loaded(tester);
    vm.addVariable('LookSensitivity', 'Float', 0.4);
    await pumpEditor(tester, vm);

    await openPaletteAt(tester, tester.getCenter(canvas()));
    final palette = tester.state<BlueprintNodePaletteState>(find.byType(BlueprintNodePalette));
    final listed = palette.widget.entries.map((e) => e.registryId).toSet();
    for (final spec in LuminaBlueprintNodeLibrary.all) {
      // Signature-bound nodes (Call Function, Switch on Enum, …) are listed
      // per function / enum / … instead of bare.
      if (BlueprintPalette.signatureNodes.contains(spec.id)) continue;
      // Level Blueprint nodes belong to a level's graph.
      if (!LuminaBlueprintNodeLibrary.availableIn(spec, vm.typeContext)) continue;
      expect(listed, contains(spec.id), reason: '${spec.id} (${spec.title}) must be in the palette');
    }
    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'looksens');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('palette_entry_variable_get_LookSensitivity')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_entry_variable_set_LookSensitivity')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'movement');
    await tester.pumpAndSettle();
    expect(find.text('Add Movement Input'), findsOneWidget);
    expect(find.text('Add Controller Yaw Input'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'yaw');
    await tester.pumpAndSettle();
    expect(find.text('Add Controller Yaw Input'), findsOneWidget);
  });

  testWidgets('IA_Move gives a Vector2D Action Value; IA_Jump re-types it to boolean and drops the wire, undoably',
      (tester) async {
    final vm = await loaded(tester);
    await pumpEditor(tester, vm);
    final origin = tester.getTopLeft(canvas());

    final input = await placeFromPalette(tester, vm, 'enhanced', 'event_enhanced_input_action', at: origin + const Offset(120, 120));
    expect(find.byKey(ValueKey('node_banner_${input.id}')), findsOneWidget, reason: 'no action picked yet');
    await pickAction(tester, input.id, 'IA_Move');
    expect(vm.getGraphNode(input.id)!.title, 'IA_Move');
    expect(find.text('IA_Move'), findsWidgets);
    expect(vm.eventGraph.pin(input.id, 'action_value', output: true)!.type, LuminaPinType.vector2D);
    expect(find.byKey(ValueKey('node_banner_${input.id}')), findsNothing);

    final breakNode = await placeFromPalette(tester, vm, 'break vector2d', 'break_vector2d', at: origin + const Offset(520, 140));
    await dragMouse(tester, pinGlobal(tester, input.id, 'action_value', output: true),
        pinGlobal(tester, breakNode.id, 'in_vec', output: false));
    expect(vm.graphWires.where((w) => w.fromNodeId == input.id && w.toNodeId == breakNode.id), hasLength(1));

    await pickAction(tester, input.id, 'IA_Jump');
    expect(vm.eventGraph.pin(input.id, 'action_value', output: true)!.type, LuminaPinType.boolean);
    expect(vm.getGraphNode(input.id)!.outputs.firstWhere((p) => p.id == 'action_value').type, LuminaPinType.boolean,
        reason: 'the stored pin re-types too');
    expect(vm.graphWires.where((w) => w.fromNodeId == input.id), isEmpty, reason: 'boolean cannot feed a Vector2D input');
    expect(vm.transactions.undoLabel, 'Undo Set input action IA_Jump');

    vm.undo();
    await tester.pumpAndSettle();
    expect(vm.getGraphNode(input.id)!.literals['action'], 'IA_Move');
    expect(vm.eventGraph.pin(input.id, 'action_value', output: true)!.type, LuminaPinType.vector2D);
    expect(vm.graphWires.where((w) => w.fromNodeId == input.id && w.toNodeId == breakNode.id), hasLength(1));
  });

  testWidgets('dragging off Action Value onto empty canvas and choosing Break Vector2D wires it', (tester) async {
    final vm = await loaded(tester);
    await pumpEditor(tester, vm);
    final origin = tester.getTopLeft(canvas());
    final input = await placeFromPalette(tester, vm, 'enhanced', 'event_enhanced_input_action', at: origin + const Offset(100, 100));
    await pickAction(tester, input.id, 'IA_Move');

    final from = pinGlobal(tester, input.id, 'action_value', output: true);
    await dragMouse(tester, from, from + const Offset(260, 60));
    expect(find.text('Node Palette — Context Sensitive'), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_entry_break_vector2d')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_entry_print_string')), findsNothing,
        reason: 'only nodes with a Vector2D input are offered');
    await tester.tap(find.byKey(const ValueKey('palette_entry_break_vector2d')));
    await tester.pumpAndSettle();

    final placed = vm.graphNodes.firstWhere((n) => n.registryId == 'break_vector2d');
    expect(vm.graphWires.single.fromPinId, 'action_value');
    expect(vm.graphWires.single.toNodeId, placed.id);
    expect(vm.graphWires.single.toPinId, 'in_vec');
    final outs = vm.eventGraph.pinsOf(placed).outputs;
    expect(outs.map((p) => (p.id, p.type)), [('x', LuminaPinType.float), ('y', LuminaPinType.float)]);
  });

  testWidgets('dragging LookSensitivity onto the graph places Set; renaming updates the node; undo restores both',
      (tester) async {
    final vm = await loaded(tester);
    vm.addVariable('LookSensitivity', 'Float', 0.4);
    await pumpEditor(tester, vm);
    await tester.tap(find.text('My Blueprint'));
    await tester.pumpAndSettle();
    expect(find.text('LookSensitivity'), findsOneWidget);

    final row = find.byKey(const ValueKey('var_row_LookSensitivity'));
    final drop = tester.getTopLeft(canvas()) + const Offset(300, 200);
    await dragMouse(tester, tester.getCenter(row), drop);
    expect(find.byKey(const ValueKey('variable_drop_set')), findsOneWidget, reason: 'a plain drop asks Get or Set');
    await tester.tap(find.byKey(const ValueKey('variable_drop_set')));
    await tester.pumpAndSettle();
    final set = vm.graphNodes.single;
    expect(set.registryId, LuminaBlueprintNodeLibrary.variableSet);
    expect(set.title, 'Set LookSensitivity');
    expect(vm.eventGraph.pin(set.id, 'value', output: false)!.type, LuminaPinType.float);

    // Ctrl-drag places a Get without asking.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await dragMouse(tester, tester.getCenter(row), drop + const Offset(0, 160));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(vm.graphNodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.variableGet), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('var_menu_LookSensitivity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_menu_rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('var_rename_field')), 'MouseSensitivity');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(vm.getGraphNode(set.id)!.title, 'Set MouseSensitivity');
    expect(find.text('Set MouseSensitivity'), findsOneWidget);
    expect(vm.document.variable('MouseSensitivity'), isNotNull);

    vm.undo();
    await tester.pumpAndSettle();
    expect(vm.getGraphNode(set.id)!.title, 'Set LookSensitivity');
    expect(vm.document.variable('LookSensitivity'), isNotNull);
    expect(vm.document.variable('MouseSensitivity'), isNull);

    // Deleting asks, then removes the variable's nodes.
    await tester.tap(find.byKey(const ValueKey('var_menu_LookSensitivity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_menu_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete variable LookSensitivity?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('var_delete_confirm')));
    await tester.pumpAndSettle();
    expect(vm.document.variables, isEmpty);
    expect(vm.graphNodes, isEmpty);
  });

  testWidgets('a rotator literal typed as yaw 90 persists in the .lmas and reads back as 90', (tester) async {
    final vm = await loaded(tester);
    await pumpEditor(tester, vm);
    final node = await placeFromPalette(tester, vm, 'forward vector', 'get_forward_vector',
        at: tester.getTopLeft(canvas()) + const Offset(200, 200));
    final yaw = find.byKey(ValueKey('literal_${node.id}_in_rot_2'));
    expect(yaw, findsOneWidget);
    await tester.enterText(find.descendant(of: yaw, matching: find.byType(EditableText)), '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(vm.getGraphNode(node.id)!.literals['in_rot'], [0.0, 0.0, 90.0]);
    expect(vm.transactions.undoLabel, 'Undo Edit In Rot');

    await tester.runAsync(vm.save);
    expect(readBlueprint(assetPath).eventGraph.node(node.id)!.literals['in_rot'], [0.0, 0.0, 90.0]);

    final reloaded = await loaded(tester);
    await pumpEditor(tester, reloaded);
    final field = find.descendant(of: find.byKey(ValueKey('literal_${node.id}_in_rot_2')), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(field).controller.text, '90.0');
  });

  testWidgets('the badge is Dirty after an edit, Error on a float → vector wire with node navigation, then Up to date',
      (tester) async {
    final vm = await loaded(tester);
    await pumpEditor(tester, vm);
    expect(vm.compileStatus, BlueprintCompileStatus.unknown);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_compile_badge')), matching: find.text('Unknown')), findsOneWidget);

    vm.addVariable('Offset', 'Vector');
    await tester.pumpAndSettle();
    expect(vm.compileStatus, BlueprintCompileStatus.dirty);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_compile_badge')), matching: find.text('Dirty')), findsOneWidget);

    final origin = tester.getTopLeft(canvas());
    final teleport = await placeFromPalette(tester, vm, 'setactorlocation', 'set_actor_location', at: origin + const Offset(520, 260));
    final get = await placeFromPalette(tester, vm, 'offset', 'variable_get_Offset', at: origin + const Offset(140, 300));
    await dragMouse(tester, pinGlobal(tester, get.id, 'value', output: true),
        pinGlobal(tester, teleport.id, 'new_location', output: false));
    expect(vm.graphWires, hasLength(1));

    // The variable becomes a float: the retype drops the wire it can no
    // longer carry; a document that still carries one
    // (edited by hand) fails the compile on that node.
    vm.setVariableType('Offset', 'Float');
    await tester.pumpAndSettle();
    expect(vm.graphWires, isEmpty, reason: 'float cannot feed a vector input');
    vm.document.eventGraph.wires.add(LuminaBlueprintWire(
        id: 'stale', fromNodeId: get.id, fromPinId: 'value', toNodeId: teleport.id, toPinId: 'new_location'));
    vm.eventGraph.documentChanged();
    await tester.pumpAndSettle();
    expect(vm.graphWires, hasLength(1));

    expect(find.byKey(const ValueKey('bp_compile')), findsOneWidget);
    await tester.runAsync(vm.compile);
    await tester.pumpAndSettle();
    expect(vm.compileStatus, BlueprintCompileStatus.error);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_compile_badge')), matching: find.text('Error')), findsOneWidget);
    final row = vm.diagnostics.indexWhere((d) => d.isError && d.nodeId == teleport.id);
    expect(row, isNonNegative, reason: '${vm.diagnostics}');
    expect(vm.diagnostics[row].message, contains('float'));
    expect(find.descendant(of: find.byKey(ValueKey('compiler_row_$row')), matching: find.text('[SetActorLocation]')),
        findsOneWidget);

    vm.eventGraph.clearSelection();
    await tester.tap(find.byKey(ValueKey('compiler_row_$row')));
    await tester.pumpAndSettle();
    expect(vm.selectedNodeIds, {teleport.id});

    vm.setVariableType('Offset', 'Vector');
    expect(find.byKey(const ValueKey('bp_compile')), findsOneWidget);
    await tester.runAsync(vm.compile);
    await tester.pumpAndSettle();
    expect(vm.diagnostics, isEmpty);
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_compile_badge')), matching: find.text('Up to date')), findsOneWidget);
    expect(File('${project.dir}/lib/actors/bp_hero.dart').existsSync(), isTrue);
  });

  testWidgets('a legacy OnInputAxis node loads with its deprecation banner and can be replaced', (tester) async {
    final doc = BlueprintEditorViewModel.createDefaultDocument('BP_Legacy');
    final context = const LuminaBlueprintTypeContext();
    doc.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_input_axis', nodeId: 'axis', context: context),
      LuminaBlueprintNodeLibrary.place('add_movement_input', nodeId: 'move', x: 300, context: context),
    ]);
    doc.eventGraph.wires.add(
        const LuminaBlueprintWire(id: 'w', fromNodeId: 'axis', fromPinId: 'exec_out', toNodeId: 'move', toPinId: 'exec_move_in'));
    final path = writeBlueprint(project.dir, 'BP_Legacy', doc);
    final vm = await loaded(tester, path);
    await pumpEditor(tester, vm);

    expect(find.byKey(const ValueKey('node_banner_axis')), findsOneWidget);
    expect(find.textContaining('Replace it with EnhancedInputAction'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('node_axis'))), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('node_menu_replace_legacy')));
    await tester.pumpAndSettle();
    final replacement = vm.graphNodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction);
    expect(vm.getGraphNode('axis'), isNull);
    expect(vm.graphWires.single.fromNodeId, replacement.id);
    expect(vm.graphWires.single.fromPinId, 'triggered');
  });

  test('rebuilding the Third Person Move/Look/Jump graph compiles clean and the generated class analyzes', () async {
    final root = Directory.systemTemp.createTempSync('lumina_bp04_game_');
    addTearDown(() => root.deleteSync(recursive: true));
    final dir = await scaffoldGameProject(root, name: 'bp_input', widgetLibrary: 'flutter');
    final path = writeBlueprint(dir, 'BP_MyCharacter',
        BlueprintEditorViewModel.createDefaultDocument('BP_MyCharacter', parentClass: 'LuminaCharacter'));
    final vm = BlueprintEditorViewModel(assetPath: path);
    await vm.load();
    expect(vm.inputActions.map((a) => a.name), containsAll(['IA_Move', 'IA_Look', 'IA_Jump']));

    // The same view-model calls the canvas, palette and My Blueprint make.
    final g = vm.eventGraph;
    final sensitivity = vm.addVariable('LookSensitivity', 'Float');
    vm.setVariableDefault(sensitivity, 0.4);
    var x = 0.0;
    LuminaBlueprintNode place(String key, {double y = 0}) {
      x += 240;
      final entry = g.paletteEntries().firstWhere((e) => e.key == key);
      return g.placeEntry(entry, Offset(x, y))!;
    }

    void wire(LuminaBlueprintNode a, String out, LuminaBlueprintNode b, String inp) =>
        expect(g.addWire(fromNodeId: a.id, fromPinId: out, toNodeId: b.id, toPinId: inp), isNotNull, reason: '$out → $inp');

    final move = place('event_enhanced_input_action');
    g.setNodeAction(move.id, 'IA_Move');
    final moveAxis = place('break_vector2d');
    final control = place('get_control_rotation');
    final parts = place('break_rotator');
    final yawOnly = place('make_rotator');
    final forward = place('get_forward_vector');
    final right = place('get_right_vector');
    final moveForward = place('add_movement_input');
    final moveRight = place('add_movement_input');
    x = 0;
    final look = place('event_enhanced_input_action', y: 400);
    g.setNodeAction(look.id, 'IA_Look');
    final lookAxis = place('break_vector2d', y: 400);
    final getSensitivity = place('variable_get_LookSensitivity', y: 400);
    final yawScaled = place('float_multiply', y: 400);
    final pitchScaled = place('float_multiply', y: 400);
    final yaw = place('add_controller_yaw_input', y: 400);
    final pitch = place('add_controller_pitch_input', y: 400);
    x = 0;
    final jumpInput = place('event_enhanced_input_action', y: 800);
    g.setNodeAction(jumpInput.id, 'IA_Jump');
    final jump = place('jump', y: 800);
    final stop = place('stop_jumping', y: 800);

    wire(move, 'action_value', moveAxis, 'in_vec');
    wire(control, 'return_value', parts, 'in_rot');
    wire(parts, 'z', yawOnly, 'z');
    wire(yawOnly, 'return_value', forward, 'in_rot');
    wire(yawOnly, 'return_value', right, 'in_rot');
    wire(move, 'triggered', moveForward, 'exec_move_in');
    wire(forward, 'return_value', moveForward, 'world_dir');
    wire(moveAxis, 'y', moveForward, 'scale_val');
    wire(moveForward, 'exec_move_out', moveRight, 'exec_move_in');
    wire(right, 'return_value', moveRight, 'world_dir');
    wire(moveAxis, 'x', moveRight, 'scale_val');
    wire(look, 'action_value', lookAxis, 'in_vec');
    wire(lookAxis, 'x', yawScaled, 'a');
    wire(getSensitivity, 'value', yawScaled, 'b');
    wire(lookAxis, 'y', pitchScaled, 'a');
    wire(getSensitivity, 'value', pitchScaled, 'b');
    wire(look, 'triggered', yaw, 'exec_in');
    wire(yawScaled, 'return_value', yaw, 'val');
    wire(yaw, 'exec_out', pitch, 'exec_in');
    wire(pitchScaled, 'return_value', pitch, 'val');
    wire(jumpInput, 'started', jump, 'exec_in');
    wire(jumpInput, 'completed', stop, 'exec_in');

    expect(await vm.compile(), isTrue);
    expect(vm.diagnostics, isEmpty, reason: '${vm.diagnostics}');
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);
    final generated = File('$dir/lib/actors/bp_my_character.dart');
    expect(generated.readAsStringSync(), contains('class BpMyCharacter extends LuminaCharacter'));
    final analysis = await analyzeGameProject(dir);
    expect(analysis.exitCode, 0, reason: '${analysis.stdout}${analysis.stderr}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('two exec outputs can both run into one exec input; a second data wire still replaces the first', () async {
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await vm.load();
    final g = vm.eventGraph;
    var x = 0.0;
    LuminaBlueprintNode place(String key) {
      x += 240;
      final entry = g.paletteEntries().firstWhere((e) => e.key == key);
      return g.placeEntry(entry, Offset(x, 0))!;
    }

    final branch = place('branch');
    final jump = place('jump');
    final stop = place('stop_jumping');
    final join = place('print_string');
    expect(g.addWire(fromNodeId: branch.id, fromPinId: 'true_out', toNodeId: jump.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: branch.id, fromPinId: 'false_out', toNodeId: stop.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: jump.id, fromPinId: 'exec_out', toNodeId: join.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: stop.id, fromPinId: 'exec_out', toNodeId: join.id, toPinId: 'exec_in'), isNotNull);

    final intoJoin = g.graph.wires.where((w) => w.toNodeId == join.id && w.toPinId == 'exec_in').toList();
    expect(intoJoin.map((w) => w.fromNodeId), unorderedEquals([jump.id, stop.id]),
        reason: 'the second exec wire must not break the first');

    // An exec output still drives one chain: rewiring jump's output moves it.
    expect(g.addWire(fromNodeId: jump.id, fromPinId: 'exec_out', toNodeId: stop.id, toPinId: 'exec_in'), isNotNull);
    expect(g.graph.wires.where((w) => w.fromNodeId == jump.id && w.fromPinId == 'exec_out').length, 1);

    // A data input still reads one value.
    final a = place('make_vector2d');
    final b = place('make_vector2d');
    final breaker = place('break_vector2d');
    expect(g.addWire(fromNodeId: a.id, fromPinId: 'return_value', toNodeId: breaker.id, toPinId: 'in_vec'), isNotNull);
    expect(g.addWire(fromNodeId: b.id, fromPinId: 'return_value', toNodeId: breaker.id, toPinId: 'in_vec'), isNotNull);
    final intoBreaker = g.graph.wires.where((w) => w.toNodeId == breaker.id && w.toPinId == 'in_vec').toList();
    expect(intoBreaker.single.fromNodeId, b.id);

    // The validator accepts the join.
    await vm.compile();
    expect(vm.diagnostics.where((d) => d.message.toLowerCase().contains('exec')), isEmpty);
  });

  testWidgets('an exec pin draws filled once wired and hollow while unwired', (tester) async {
    final vm = await loaded(tester);
    final g = vm.eventGraph;
    final jump = g.placeEntry(g.paletteEntries().firstWhere((e) => e.key == 'jump'), const Offset(200, 0))!;
    final stop = g.placeEntry(g.paletteEntries().firstWhere((e) => e.key == 'stop_jumping'), const Offset(500, 0))!;
    await pumpEditor(tester, vm);
    expect(find.byKey(ValueKey('pin_exec_${jump.id}_exec_out_out_hollow')), findsOneWidget);
    expect(find.byKey(ValueKey('pin_exec_${stop.id}_exec_in_in_hollow')), findsOneWidget);

    g.addWire(fromNodeId: jump.id, fromPinId: 'exec_out', toNodeId: stop.id, toPinId: 'exec_in');
    await tester.pump();
    expect(find.byKey(ValueKey('pin_exec_${jump.id}_exec_out_out_filled')), findsOneWidget);
    expect(find.byKey(ValueKey('pin_exec_${stop.id}_exec_in_in_filled')), findsOneWidget);
    final painter = tester.widget<CustomPaint>(find.byKey(ValueKey('pin_exec_${stop.id}_exec_in_in_filled'))).painter
        as BlueprintExecPinPainter;
    expect(painter.filled, isTrue);
  });

  testWidgets('right-clicking a node opens its menu at the pointer, not at the canvas bottom', (tester) async {
    final vm = await loaded(tester);
    final g = vm.eventGraph;
    final jump = g.placeEntry(g.paletteEntries().firstWhere((e) => e.key == 'jump'), const Offset(200, 120))!;
    await pumpEditor(tester, vm);
    final header = find.text(jump.title).first;
    final click = tester.getCenter(header);
    await tester.tapAt(click, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    final menu = find.byType(DropdownMenu);
    expect(menu, findsOneWidget);
    final topLeft = tester.getTopLeft(menu);
    // The menu opens at the click (a few pixels of popover offset aside),
    // and stays there on later frames.
    expect((topLeft - click).distance, lessThan(80), reason: 'menu at $topLeft, click at $click');
    await tester.pump(const Duration(milliseconds: 300));
    expect((tester.getTopLeft(menu) - topLeft).distance, lessThan(1));
    // shadcn shows menus as bottom sheets on mobile platforms (the test
    // default); the editor is a desktop app.
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  test('For Each Loop over an array of hit results yields a Hit Result element that Break Hit Result accepts', () async {
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await vm.load();
    final g = vm.eventGraph;
    var x = 0.0;
    LuminaBlueprintNode place(String key) {
      x += 260;
      final entry = g.paletteEntries().firstWhere((e) => e.key == key);
      return g.placeEntry(entry, Offset(x, 0))!;
    }

    final trace = place('multi_line_trace_forward');
    final loop = place('for_each_loop');
    LuminaBlueprintPinSpec? element() =>
        g.pinsOf(g.node(loop.id)!).outputs.where((p) => p.id == 'array_element').firstOrNull;
    expect(element()!.type, LuminaPinType.wildcard, reason: 'untyped until wired');

    expect(g.addWire(fromNodeId: trace.id, fromPinId: 'out_hits', toNodeId: loop.id, toPinId: 'array'), isNotNull);
    expect(element()!.type, LuminaPinType.hitResult, reason: 'the element takes the array element type');
    expect(g.node(loop.id)!.literals['type'], 'hitResult');

    // The palette dragged from the element now offers Break Hit Result, and it wires.
    final ref = BlueprintPinRef.of(loop.id, element()!, isOutput: true);
    expect(g.compatibleEntries(g.paletteEntries(), ref).map((e) => e.registryId), contains('break_hit_result'));
    final breaker = place('break_hit_result');
    expect(g.addWire(fromNodeId: loop.id, fromPinId: 'array_element', toNodeId: breaker.id, toPinId: 'hit'), isNotNull);

    // An actor array types Array Get's item as an actor.
    final actors = place('get_all_actors_of_class');
    final get = place('array_get');
    expect(g.addWire(fromNodeId: actors.id, fromPinId: 'return_value', toNodeId: get.id, toPinId: 'target_array'), isNotNull,
        reason: 'pins: ${g.pinsOf(get).inputs.map((p) => p.id)}');
    expect(g.pinsOf(g.node(get.id)!).outputs.firstWhere((p) => p.type != LuminaPinType.exec).type, LuminaPinType.object);
  });

  test('a For Each wired to hit results before wildcard typing existed is typed when the Blueprint loads', () async {
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await vm.load();
    final g = vm.eventGraph;
    final trace = g.placeEntry(g.paletteEntries().firstWhere((e) => e.key == 'multi_line_trace_forward'), const Offset(0, 0))!;
    final loop = g.placeEntry(g.paletteEntries().firstWhere((e) => e.key == 'for_each_loop'), const Offset(300, 0))!;
    g.addWire(fromNodeId: trace.id, fromPinId: 'out_hits', toNodeId: loop.id, toPinId: 'array');
    // Simulate an old save: the node has no type setting and wildcard pins.
    g.node(loop.id)!.literals.remove('type');
    g.syncPins(g.node(loop.id)!);
    await vm.save();

    final reopened = BlueprintEditorViewModel(assetPath: assetPath);
    await reopened.load();
    final element = reopened.eventGraph.pinsOf(reopened.eventGraph.node(loop.id)!).outputs.firstWhere((p) => p.id == 'array_element');
    expect(element.type, LuminaPinType.hitResult);
    expect(reopened.isDirty, isFalse, reason: 'normalising pins on load does not dirty the Blueprint');
  });
}
