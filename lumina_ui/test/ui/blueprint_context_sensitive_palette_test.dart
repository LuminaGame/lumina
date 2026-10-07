import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/widget_class_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/node_palette.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/widget_class_test_project.dart';

/// The context-sensitive palette on a real Third Person
/// project with a real `WBP_HUD.lmas` (Text FPSCounter, Progress Bar Health).
void main() {
  late WidgetClassTestProject project;
  late BlueprintEditorViewModel vm;

  setUpAll(() => project = WidgetClassTestProject.create());
  tearDownAll(() => project.dispose());

  setUp(() async {
    vm = BlueprintEditorViewModel(assetPath: project.characterPath);
    await vm.load();
  });
  tearDown(() => vm.dispose());

  BlueprintPinRef out(LuminaBlueprintNode node, String pinId) =>
      BlueprintPinRef.of(node.id, vm.eventGraph.pin(node.id, pinId, output: true)!, isOutput: true);

  Iterable<String> titles(List<BlueprintPaletteEntry> entries) => entries.map((e) => e.title);

  test('the catalog reads WBP_HUD and BP_Door from the project on disk', () {
    final catalog = vm.widgetClassCatalog!;
    final hud = catalog.widgetClass('WBP_HUD')!;
    expect(hud.elements.map((e) => (e.name, e.typeName)), [('FPSCounter', 'text'), ('Health', 'progressBar')]);
    expect(hud.element('FPSCounter')!.props['text'], 'FPS: --');
    expect(catalog.widgetClass('WBP_Menu')!.elements.single.name, 'PlayButton');
    expect(catalog.actorParents['BP_Door'], 'LuminaActor');
    expect(catalog.actorParents['BP_ThirdPersonCharacter'], 'LuminaCharacter');
    final context = vm.typeContext;
    expect(context.selfClass, 'Actor:BP_ThirdPersonCharacter');
    expect(context.components.map((c) => c.name), containsAll(['CameraBoom', 'FollowCamera', 'Mesh', 'CharacterMovement']));
    expect(WidgetClassCatalog.scanWidgetClasses(project.dir).map((w) => w.name), ['WBP_HUD', 'WBP_Menu']);
  });

  test('Create Widget (WBP_HUD) Return Value lists the widget rows, Promote first, and not the element setters', () {
    // A Create Widget placed from the palette names a project class at once.
    final create = vm.addGraphNode('create_widget', const Offset(300, 300))!;
    expect(create.literals['class'], 'WBP_HUD', reason: 'seeded from the project\'s widget classes');
    final from = out(create, 'return_value');
    expect(from.objectClass, 'Widget:WBP_HUD');

    final entries = vm.eventGraph.paletteEntriesFor(from);
    expect(entries.first.title, 'Promote to Variable');
    expect(entries.first.action, BlueprintPaletteAction.promoteToVariable);
    final names = titles(entries).toList();
    expect(names, containsAll(['Get FPSCounter', 'Get Health', 'Is Valid', 'Add to Viewport', 'Set Visibility (Widget)',
        'Remove from Parent', 'Cast To WBP_Menu', 'Cast To BP_Door']));
    expect(entries.where((e) => e.title == 'Is Valid').map((e) => e.registryId), containsAll(['is_valid', 'is_valid_branch']),
        reason: 'Is Valid (pure) and Is Valid? (flow) both take any object');
    expect(names, isNot(contains('Set Text (Text)')));
    expect(names, isNot(contains('Set Percent')));
    expect(names, isNot(contains('Get PlayButton')), reason: 'elements of another widget class are not listed');
    expect(names, isNot(contains('Get CameraBoom')), reason: 'a widget is not Self');

    final fps = entries.firstWhere((e) => e.title == 'Get FPSCounter');
    expect(fps.registryId, LuminaBlueprintNodeLibrary.getWidgetElement);
    expect(fps.category, 'Widget|WBP_HUD');
    expect(fps.literals, {'class': 'WBP_HUD', 'element': 'FPSCounter'});
    expect(fps.objectClass, 'Widget:WBP_HUD');
    expect(titles(BlueprintPalette.search(entries, 'fps')), contains('Get FPSCounter'));
    expect(BlueprintPalette.compatiblePin(fps, from, vm.typeContext), 'target');

    // Set <Var> only for variables of an assignable class.
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    vm.addVariable('MenuWidget', 'Widget:WBP_Menu');
    vm.addVariable('AnyObject', 'Object');
    vm.addVariable('Speed', 'Float');
    final again = titles(vm.eventGraph.paletteEntriesFor(from)).toList();
    expect(again, containsAll(['Set HudWidget', 'Set AnyObject']));
    expect(again, isNot(contains('Set MenuWidget')));
    expect(again, isNot(contains('Set Speed')));
  });

  test('Get FPSCounter yields a Text Block whose pin lists the text and common element nodes only', () {
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    final get = vm.eventGraph.placeVariable('HudWidget', set: false, position: const Offset(100, 100))!;
    final from = out(get, 'value');
    expect(from.objectClass, 'Widget:WBP_HUD');
    final entry = vm.eventGraph.paletteEntriesFor(from).firstWhere((e) => e.title == 'Get FPSCounter');
    final element = vm.eventGraph.placeEntry(entry, const Offset(400, 100), from: from)!;
    expect(element.title, 'Get FPSCounter');
    expect(vm.graphWires.any((w) => w.fromNodeId == get.id && w.toNodeId == element.id && w.toPinId == 'target'), isTrue);
    final ret = vm.eventGraph.pin(element.id, 'return_value', output: true)!;
    expect(ret.objectClass, 'WidgetElement:text');
    expect(vm.eventGraph.pinTypeLabel(element, ret, output: true), 'Text Block');

    final names = titles(vm.eventGraph.paletteEntriesFor(out(element, 'return_value'))).toList();
    expect(names, containsAll(['Set Text (Text)', 'Get Text (Text)', 'Set Color and Opacity', 'Set Font Size',
        'Set Visibility', 'Set Is Enabled', 'Set Render Opacity']));
    expect(names, isNot(contains('Set Percent')));
    expect(names, isNot(contains('Add to Viewport')));
  });

  test('Self lists the component tree; Get CameraBoom then lists the Spring Arm nodes', () {
    final self = BlueprintPinRef.self(vm.typeContext);
    final entries = vm.eventGraph.paletteEntriesFor(self);
    final names = titles(entries).toList();
    expect(names, containsAll(['Get CameraBoom', 'Get FollowCamera', 'Get Mesh', 'Get CharacterMovement', 'Get CapsuleComponent']));
    expect(names, isNot(contains('Promote to Variable')), reason: 'Self is not a wire');
    // Engine nodes that take Self appear here as they land in the library.
    for (final id in ['get_look_forward_direction', 'line_trace_forward']) {
      if (LuminaBlueprintNodeLibrary.spec(id) != null) {
        expect(entries.map((e) => e.registryId), contains(id), reason: '$id takes Self');
      }
    }
    final boom = entries.firstWhere((e) => e.title == 'Get CameraBoom');
    expect(boom.category, 'Components|BP_ThirdPersonCharacter');
    final placed = vm.eventGraph.placeEntry(boom, const Offset(200, 200), from: self)!;
    expect(vm.eventGraph.pin(placed.id, 'return_value', output: true)!.objectClass, 'Component:LuminaSpringArmComponent');
    final armNames = titles(vm.eventGraph.paletteEntriesFor(out(placed, 'return_value'))).toList();
    expect(armNames, containsAll(['Set Target Arm Length', 'Get Target Arm Length', 'Set Relative Location', 'Set Enable Camera Lag']));
    expect(armNames, isNot(contains('Set Field of View')), reason: 'a camera node refuses a Spring Arm');
    expect(armNames, isNot(contains('Set Max Walk Speed')));

    // My Blueprint's Components section places the same node.
    final dropped = vm.eventGraph.placeComponent('FollowCamera', position: const Offset(1, 1))!;
    expect(dropped.title, 'Get FollowCamera');
    expect(vm.eventGraph.pin(dropped.id, 'return_value', output: true)!.objectClass, 'Component:LuminaCameraComponent');
  });

  test('a float pin lists math, conversion and string nodes; an array pin the array and For Each nodes', () {
    final tick = vm.addGraphNode('event_tick', const Offset(0, 300))!;
    final floatEntries = vm.eventGraph.paletteEntriesFor(out(tick, 'delta_seconds'));
    final names = titles(floatEntries).toList();
    expect(names, contains('Promote to Variable'));
    expect(floatEntries.map((e) => e.registryId), containsAll(['float_multiply', 'float_clamp', 'float_to_string', 'float_lerp']));
    expect(names, isNot(contains('Get FPSCounter')));
    expect(names, isNot(contains('Add to Viewport')));

    vm.addVariable('Scores', 'Array:Float');
    final get = vm.eventGraph.placeVariable('Scores', set: false, position: const Offset(0, 0))!;
    final arrayRef = out(get, 'value');
    expect(arrayRef.type, LuminaPinType.array);
    expect(arrayRef.elementType, LuminaPinType.float);
    final arrayEntries = vm.eventGraph.paletteEntriesFor(arrayRef);
    expect(arrayEntries.map((e) => e.registryId), containsAll(['array_length', 'array_get', 'for_each_loop', 'array_add', 'array_contains']));
    expect(arrayEntries.map((e) => e.registryId), isNot(contains('float_multiply')));
  });

  test('dragging from an input pin lists sources: Create Widget and Gets of an assignable class', () {
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    vm.addVariable('MenuWidget', 'Widget:WBP_Menu');
    final add = vm.addGraphNode('add_to_viewport', const Offset(0, 0))!;
    final target = vm.eventGraph.pin(add.id, 'target', output: false)!;
    final from = BlueprintPinRef.of(add.id, target, isOutput: false);
    final names = titles(vm.eventGraph.paletteEntriesFor(from)).toList();
    expect(names, containsAll(['Create Widget', 'Get HudWidget', 'Get MenuWidget']));
    expect(names, isNot(contains('Promote to Variable')));
    expect(names, isNot(contains('Get FPSCounter')), reason: 'an element is not a widget');

    final setText = vm.addGraphNode('set_element_text', const Offset(0, 0))!;
    final textTarget = vm.eventGraph.pin(setText.id, 'target', output: false)!;
    final textNames = titles(vm.eventGraph.paletteEntriesFor(BlueprintPinRef.of(setText.id, textTarget, isOutput: false))).toList();
    expect(textNames, contains('Get FPSCounter'));
    expect(textNames, isNot(contains('Get Health')), reason: 'a Progress Bar is not a Text Block');
    expect(textNames, isNot(contains('Get HudWidget')));
  });

  test('wiring a Widget (WBP_HUD) into Set Percent is refused naming both classes, and Compiler Results reports a forced wire', () async {
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    final get = vm.eventGraph.placeVariable('HudWidget', set: false, position: const Offset(0, 0))!;
    final setPercent = vm.addGraphNode('set_element_percent', const Offset(300, 0))!;
    final why = vm.eventGraph.whyNotConnect(get.id, 'value', setPercent.id, 'target')!;
    expect(why, contains('Widget (WBP_HUD)'));
    expect(why, contains('Progress Bar'));
    expect(vm.addGraphWire(fromNodeId: get.id, fromPinId: 'value', toNodeId: setPercent.id, toPinId: 'target'), isNull);
    expect(vm.graphWires.where((w) => w.toNodeId == setPercent.id), isEmpty);

    // A wire that exists anyway (a document edited by hand, or retyped) is a
    // Compiler Results error on that node and pin, and drawn broken.
    vm.document.eventGraph.wires.add(LuminaBlueprintWire(
        id: 'forced', fromNodeId: get.id, fromPinId: 'value', toNodeId: setPercent.id, toPinId: 'target'));
    expect(vm.eventGraph.wireHasProblem(vm.document.eventGraph.wires.last), isTrue);
    await vm.compile();
    final row = vm.diagnostics.firstWhere((d) => d.isError && d.message.contains('Widget (WBP_HUD)'));
    expect(row.message, contains('Progress Bar'));
    expect(row.nodeId, setPercent.id);
    expect(row.pinId, 'target');
  });

  testWidgets('the palette dialog pins Promote to Variable, shows WIDGET › WBP_HUD and the class on the From line', (tester) async {
    final create = vm.addGraphNode('create_widget', const Offset(300, 300), literals: {'class': 'WBP_HUD'})!;
    final from = out(create, 'return_value');
    BlueprintPaletteEntry? chosen;
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: BlueprintNodePalette(
        entries: vm.eventGraph.paletteEntriesFor(from),
        context: vm.typeContext,
        from: from,
        fromLabel: 'Return Value',
        fromTypeLabel: vm.eventGraph.pinTypeLabel(create, vm.eventGraph.pin(create.id, 'return_value', output: true)!, output: true),
        onSelect: (e) => chosen = e,
        onClose: () {},
      ),
    ));
    await tester.pump();
    expect(find.text('From Return Value (Widget (WBP_HUD))'), findsOneWidget);
    // The rows about WBP_HUD lead: its elements before the any-object nodes.
    expect(tester.getTopLeft(find.text('WIDGET › WBP_HUD')).dy, lessThan(tester.getTopLeft(find.text('USER INTERFACE')).dy));
    final promote = find.byKey(const ValueKey('palette_entry_${BlueprintPalette.promoteToVariableId}'));
    expect(promote, findsOneWidget);
    expect(find.text('WIDGET › WBP_HUD'), findsOneWidget, reason: 'the category header names the class');
    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'fps');
    await tester.pump();
    expect(find.byKey(const ValueKey('palette_best_matches')), findsOneWidget);
    expect(find.text('Widget › WBP_HUD'), findsOneWidget, reason: 'a best match shows its class category');
    expect(find.text('Get FPSCounter'), findsOneWidget);
    expect(find.text('Get Health'), findsNothing);
    await tester.tap(find.text('Get FPSCounter'));
    await tester.pump();
    expect(chosen!.literals['element'], 'FPSCounter');
  });

  testWidgets('the graph canvas opens the context palette from a typed pin drag and places the wired element node',
      (tester) async {
    final create = vm.addGraphNode('create_widget', const Offset(60, 60), literals: {'class': 'WBP_HUD'})!;
    vm.startHeadlessPreview();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: 'BP_ThirdPersonCharacter',
          assetPath: project.characterPath,
          viewModel: vm,
          showPreviewViewport: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final canvasFinder = find.byType(BlueprintGraphCanvas);
    expect(canvasFinder, findsOneWidget);
    final canvas = tester.state<BlueprintGraphCanvasState>(canvasFinder);
    final start = tester.getTopLeft(canvasFinder) + canvas.pinScreenPosition(create.id, 'return_value', output: true)!;
    final end = start + const Offset(260, 200);
    // Drag off the Return Value onto empty canvas, as a mouse does.
    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Node Palette — Context Sensitive'), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_entry_${BlueprintPalette.promoteToVariableId}')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'get fpscounter');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('palette_entry_get_widget_element_FPSCounter')));
    await tester.pump();
    final element = vm.graphNodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.getWidgetElement);
    expect(element.title, 'Get FPSCounter');
    expect(vm.graphWires.any((w) => w.fromNodeId == create.id && w.toNodeId == element.id), isTrue);
    expect(find.byKey(ValueKey('pin_tooltip_${element.id}_return_value_out')), findsOneWidget);
  });
}
