import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/widget_class_test_project.dart';

/// Typed variables in My Blueprint, node settings and
/// the new literal editors, on a real project.
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

  Future<void> pumpEditor(WidgetTester tester) async {
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
  }

  test('the type picker groups offer Object, every widget class, element type, component and actor class', () {
    final groups = BlueprintPinStyle.variableTypeGroups(vm.typeContext);
    expect(groups.map((g) => g.title), ['Basic', 'Object', 'Widgets', 'Widget Elements', 'Components', 'Actors', 'Enums']);
    final byTitle = {for (final g in groups) g.title: g.typeNames};
    expect(byTitle['Basic'], containsAll(['Bool', 'Float', 'Vector', 'Color', 'Transform']));
    expect(byTitle['Object'], ['Object']);
    expect(byTitle['Widgets'], ['Widget:WBP_HUD', 'Widget:WBP_Menu']);
    expect(byTitle['Widget Elements'], containsAll(['WidgetElement:text', 'WidgetElement:progressBar', 'WidgetElement:button']));
    expect(byTitle['Components'], containsAll(['Component:LuminaSpringArmComponent', 'Component:LuminaCameraComponent',
        'Component:LuminaSkeletalMeshComponent', 'Component:LuminaCharacterMovementComponent']));
    expect(byTitle['Actors'], containsAll(['Actor:BP_Door', 'Actor:BP_ThirdPersonCharacter', 'Actor:LuminaActor', 'Actor:LuminaCharacter']));
    expect(BlueprintPinStyle.variableLabel('Widget:WBP_HUD'), 'Widget (WBP_HUD)');
    expect(BlueprintPinStyle.variableLabel('WidgetElement:text'), 'Text Block');
    expect(BlueprintPinStyle.variableLabel('Component:LuminaSpringArmComponent'), 'Spring Arm');
    expect(BlueprintPinStyle.variableLabel('Array:Float'), 'Array of Float');
    expect(BlueprintPinStyle.variableLabel('Object'), 'Object');
  });

  test('retyping HudWidget to Object retypes its nodes and drops the now-refused wire, one undo entry', () {
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    final get = vm.eventGraph.placeVariable('HudWidget', set: false, position: const Offset(0, 0))!;
    final element = vm.addGraphNode(LuminaBlueprintNodeLibrary.getWidgetElement, const Offset(200, 0),
        literals: {'class': 'WBP_HUD', 'element': 'FPSCounter'})!;
    final valid = vm.addGraphNode('is_valid', const Offset(200, 100))!;
    expect(vm.addGraphWire(fromNodeId: get.id, fromPinId: 'value', toNodeId: element.id, toPinId: 'target'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: get.id, fromPinId: 'value', toNodeId: valid.id, toPinId: 'input_object'), isNotNull);

    expect(vm.setVariableType('HudWidget', 'Object'), isTrue);
    expect(vm.document.variable('HudWidget')!.typeName, 'Object');
    expect(vm.eventGraph.pin(get.id, 'value', output: true)!.objectClass, isNull, reason: 'the Get retyped');
    expect(vm.graphWires.any((w) => w.toNodeId == element.id), isFalse, reason: 'Object cannot feed Get FPSCounter');
    expect(vm.graphWires.any((w) => w.toNodeId == valid.id), isTrue, reason: 'Is Valid takes any object');
    expect(vm.transactions.undoLabel, 'Undo Change type of HudWidget');
    vm.undo();
    expect(vm.document.variable('HudWidget')!.typeName, 'Widget:WBP_HUD');
    expect(vm.graphWires.any((w) => w.toNodeId == element.id), isTrue);
  });

  test('Format Text grows a pin per placeholder; Make Array adds pins; node settings retitle Cast To and Get Element', () {
    final fmt = vm.addGraphNode('format_string', const Offset(0, 0))!;
    List<String> args() => [for (final p in vm.eventGraph.pinsOf(fmt).inputs) if (p.id.startsWith('arg_')) p.name];
    expect(args(), ['{0}'], reason: 'the default format names {0}');
    vm.setPinLiteral(fmt.id, 'format', 'FPS: {0} ({1} ms)');
    expect(args(), ['{0}', '{1}']);
    vm.setPinLiteral(fmt.id, 'format', 'no placeholders');
    expect(args(), isEmpty);

    final arr = vm.addGraphNode('make_array', const Offset(0, 0))!;
    int items() => vm.eventGraph.pinsOf(arr).inputs.where((p) => p.id.startsWith('item_')).length;
    expect(items(), 2);
    expect(vm.eventGraph.addCountedPin(arr.id), isTrue);
    expect(items(), 3);
    expect(vm.eventGraph.setNodeSetting(arr.id, 'type', 'float'), isTrue);
    expect(vm.eventGraph.pinsOf(arr).inputs.first.type, LuminaPinType.float);
    expect(vm.eventGraph.pinsOf(arr).outputs.single.elementType, LuminaPinType.float);

    final seq = vm.addGraphNode('sequence', const Offset(0, 0))!;
    expect(vm.eventGraph.addSequencePin(seq.id), isTrue);
    expect(vm.eventGraph.pinsOf(seq).outputs.map((p) => p.id), ['then_0', 'then_1', 'then_2']);

    final cast = vm.addGraphNode(LuminaBlueprintNodeLibrary.castTo, const Offset(0, 0))!;
    expect(vm.eventGraph.pinOptions(cast, vm.eventGraph.pin(cast.id, 'class', output: false)!),
        containsAll(['Widget:WBP_HUD', 'Actor:BP_Door', 'Actor:LuminaCharacter']));
    vm.setPinLiteral(cast.id, 'class', 'Actor:BP_Door');
    expect(cast.title, 'Cast To BP_Door');
    expect(vm.eventGraph.pin(cast.id, 'as_class', output: true)!.objectClass, 'Actor:BP_Door');

    final element = vm.addGraphNode(LuminaBlueprintNodeLibrary.getWidgetElement, const Offset(0, 0))!;
    expect(vm.eventGraph.pinOptions(element, vm.eventGraph.pin(element.id, 'element', output: false)!),
        ['FPSCounter', 'Health', 'PlayButton']);
    vm.eventGraph.setNodeSetting(element.id, 'class', 'WBP_HUD');
    expect(vm.eventGraph.pinOptions(element, vm.eventGraph.pin(element.id, 'element', output: false)!), ['FPSCounter', 'Health']);
    vm.setPinLiteral(element.id, 'element', 'Health');
    expect(element.title, 'Get Health');
    expect(element.category, 'Widget|WBP_HUD');
    expect(vm.eventGraph.pin(element.id, 'return_value', output: true)!.objectClass, 'WidgetElement:progressBar');

    final sw = vm.addGraphNode('switch_on_int', const Offset(0, 0))!;
    vm.eventGraph.setNodeSetting(sw.id, 'cases', [1, 2]);
    expect(vm.eventGraph.pinsOf(sw).outputs.map((p) => p.name).take(2), ['1', '2']);
  });

  test('a colour literal persists as [r, g, b, a] in the .lmas', () async {
    final setColor = vm.addGraphNode('set_element_color', const Offset(0, 0))!;
    expect(BlueprintPinLiteralEditor.hexToColor('#FF8000'), [1.0, closeTo(0.502, 0.001), 0.0, 1.0]);
    expect(BlueprintPinLiteralEditor.colorToHex([1.0, 0.0, 0.0, 1.0]), '#FF0000FF');
    vm.setPinLiteral(setColor.id, 'in_color', BlueprintPinLiteralEditor.hexToColor('#FF000080'));
    expect(await vm.save(), isTrue);
    final saved = readBlueprint(project.characterPath).eventGraph.node(setColor.id)!;
    expect(saved.literals['in_color'], [1.0, 0.0, 0.0, closeTo(0.502, 0.001)]);
    final raw = jsonDecode(utf8.decode(LuminaAsset.fromBytes(File(project.characterPath).readAsBytesSync()).rawPayload!));
    expect(jsonEncode(raw).contains('"in_color"'), isTrue);
  });

  testWidgets('the Details panel edits a colour through the swatch field and Make Array through Add pin', (tester) async {
    final setColor = vm.addGraphNode('set_element_color', const Offset(40, 40))!;
    final arr = vm.addGraphNode('make_array', const Offset(40, 300))!;
    await pumpEditor(tester);
    vm.selectGraphNode(setColor.id);
    await tester.pump();
    expect(find.byKey(const ValueKey('bp_node_details')), findsOneWidget);
    expect(find.byKey(ValueKey('details_literal_${setColor.id}_in_color_swatch')), findsOneWidget);
    await tester.enterText(find.byKey(ValueKey('details_literal_${setColor.id}_in_color_0')), '#00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(setColor.literals['in_color'], [0.0, 1.0, 0.0, 1.0]);

    vm.selectGraphNode(arr.id);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('details_add_pin_${arr.id}')));
    await tester.pump();
    expect(vm.eventGraph.pinsOf(arr).inputs.where((p) => p.id.startsWith('item_')).length, 3);
  });

  testWidgets('My Blueprint shows the class chip, the Widgets group in the picker, Components and searchable elements',
      (tester) async {
    vm.addVariable('HudWidget', 'Widget:WBP_HUD');
    await pumpEditor(tester);
    await tester.tap(find.text('My Blueprint').first);
    await tester.pump();
    expect(find.descendant(of: find.byKey(const ValueKey('var_type_HudWidget')), matching: find.text('Widget (WBP_HUD)')), findsOneWidget,
        reason: 'the chip shows the class');
    expect(find.text('COMPONENTS'), findsOneWidget);
    expect(find.byKey(const ValueKey('component_row_CameraBoom')), findsOneWidget);
    expect(find.text('Spring Arm'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('var_type_HudWidget')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('var_type_group_Widgets')), findsOneWidget);
    expect(find.byKey(const ValueKey('var_type_group_Components')), findsOneWidget);
    expect(find.byKey(const ValueKey('var_type_item_Widget:WBP_HUD')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('var_type_item_Widget:WBP_Menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_type_item_Widget:WBP_Menu')).last);
    await tester.pumpAndSettle();
    expect(vm.document.variable('HudWidget')!.typeName, 'Widget:WBP_Menu');

    // Selecting the widget variable lists its elements, searchable.
    vm.setVariableType('HudWidget', 'Widget:WBP_HUD');
    vm.selectVariable('HudWidget');
    await tester.pump();
    expect(find.byKey(const ValueKey('element_row_FPSCounter')), findsOneWidget);
    expect(find.byKey(const ValueKey('element_row_Health')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('element_search')), 'heal');
    await tester.pump();
    expect(find.byKey(const ValueKey('element_row_FPSCounter')), findsNothing);
    expect(find.byKey(const ValueKey('element_row_Health')), findsOneWidget);

    // Dragging Health onto the graph places Get HudWidget → Get Health.
    final placed = vm.eventGraph.placeElementGet('HudWidget', 'Health', position: const Offset(300, 300))!;
    expect(placed.title, 'Get Health');
    expect(vm.graphWires.any((w) => w.toNodeId == placed.id && w.toPinId == 'target'), isTrue);
  });
}
