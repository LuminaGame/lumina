import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/widget_class_test_project.dart';

/// Promote to Variable on a real project.
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

  test('promoted names follow the pin and the class', () {
    expect(BlueprintPalette.promotedName('Return Value', objectClass: 'Widget:WBP_HUD'), 'HudWidget');
    expect(BlueprintPalette.promotedName('Return Value', objectClass: 'Widget:WBP_MainMenu'), 'MainMenuWidget');
    expect(BlueprintPalette.promotedName('As Class', objectClass: 'Actor:BP_Door'), 'AsBpDoor');
    expect(BlueprintPalette.promotedName('Return Value', objectClass: 'Component:LuminaSpringArmComponent'), 'SpringArmComponent');
    expect(BlueprintPalette.promotedName('Delta Seconds'), 'DeltaSeconds');
    expect(BlueprintPalette.promotedName('Return Value', nodeRegistryId: 'get_actor_location'), 'GetActorLocation');
  });

  test('Promote on Create Widget Return Value declares HudWidget, wires Set into the exec chain, undoes as one step', () {
    final begin = vm.addGraphNode('event_beginplay', const Offset(0, 80))!;
    final create = vm.addGraphNode('create_widget', const Offset(300, 80), literals: {'class': 'WBP_HUD'})!;
    final add = vm.addGraphNode('add_to_viewport', const Offset(600, 80))!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: create.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: create.id, fromPinId: 'exec_out', toNodeId: add.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: create.id, fromPinId: 'return_value', toNodeId: add.id, toPinId: 'target');
    final variablesBefore = vm.document.variables.length;
    final nodesBefore = vm.graphNodes.length;

    final from = out(create, 'return_value');
    final promote = vm.eventGraph.paletteEntriesFor(from).first;
    expect(promote.action, BlueprintPaletteAction.promoteToVariable);
    final set = vm.eventGraph.placeEntry(promote, const Offset(450, 200), from: from)!;

    final variable = vm.document.variable('HudWidget')!;
    expect(variable.typeName, 'Widget:WBP_HUD');
    expect(variable.objectClass, 'Widget:WBP_HUD');
    expect(vm.selectedVariable, 'HudWidget', reason: 'My Blueprint selects the new variable');
    expect(set.registryId, LuminaBlueprintNodeLibrary.variableSet);
    expect(set.title, 'Set HudWidget');
    expect(vm.eventGraph.pin(set.id, 'value', output: false)!.objectClass, 'Widget:WBP_HUD');
    bool wired(String from, String fromPin, String to, String toPin) =>
        vm.graphWires.any((w) => w.fromNodeId == from && w.fromPinId == fromPin && w.toNodeId == to && w.toPinId == toPin);
    expect(wired(create.id, 'return_value', set.id, 'value'), isTrue, reason: 'the value comes from the promoted pin');
    expect(wired(create.id, 'exec_out', set.id, 'exec_in'), isTrue, reason: 'Set runs right after Create Widget');
    expect(wired(set.id, 'exec_out', add.id, 'exec_in'), isTrue, reason: 'and continues to Add to Viewport');
    expect(wired(create.id, 'exec_out', add.id, 'exec_in'), isFalse);
    expect(wired(create.id, 'return_value', add.id, 'target'), isTrue, reason: 'other readers of the pin keep their wire');
    expect(vm.transactions.undoLabel, 'Undo Promote HudWidget to variable', reason: 'one undo step');

    vm.undo();
    expect(vm.document.variables.length, variablesBefore);
    expect(vm.document.variable('HudWidget'), isNull);
    expect(vm.graphNodes.length, nodesBefore);
    expect(wired(create.id, 'exec_out', add.id, 'exec_in'), isTrue, reason: 'the chain is back');
    vm.redo();
    expect(vm.document.variable('HudWidget'), isNotNull);
    expect(vm.getGraphNode(set.id), isNotNull);

    // A second promotion of the same pin gets the next free name.
    final second = vm.eventGraph.promoteToVariable(from)!;
    expect(second.title, 'Set HudWidget2');
  });

  test('a pure pin promotes with only its data wire; an exec pin, Self and wildcards cannot be promoted', () {
    final tick = vm.addGraphNode('event_tick', const Offset(0, 300))!;
    final set = vm.eventGraph.promoteToVariable(out(tick, 'delta_seconds'))!;
    expect(vm.document.variable('DeltaSeconds')!.typeName, 'Float');
    expect(vm.graphWires.where((w) => w.toNodeId == set.id).map((w) => w.toPinId), unorderedEquals(['exec_in', 'value']),
        reason: 'an event has an exec chain the Set joins');

    final location = vm.addGraphNode('get_actor_location', const Offset(0, 0))!;
    final vec = vm.eventGraph.promoteToVariable(out(location, 'return_value'))!;
    expect(vm.document.variable(vec.literals['variable'] as String)!.typeName, 'Vector');
    expect(vm.graphWires.where((w) => w.toNodeId == vec.id).map((w) => w.toPinId), ['value'],
        reason: 'a pure node has no exec chain');

    expect(vm.eventGraph.promoteToVariable(out(tick, 'exec_tick_out')), isNull);
    expect(vm.eventGraph.promoteToVariable(BlueprintPinRef.self(vm.typeContext)), isNull);
    final arrayGet = vm.addGraphNode('array_get', const Offset(0, 0))!;
    expect(vm.eventGraph.promoteToVariable(out(arrayGet, 'return_value')), isNull, reason: 'an untyped wildcard has no type yet');
    expect(vm.eventGraph.variableTypeFor(BlueprintPinRef(nodeId: 'x', pinId: 'y', type: LuminaPinType.array, isOutput: true, elementType: LuminaPinType.object, objectClass: 'Actor:BP_Door')),
        'Array:Actor:BP_Door');
  });

  test('the promoted variable survives save and reload with its class', () async {
    final create = vm.addGraphNode('create_widget', const Offset(300, 80), literals: {'class': 'WBP_HUD'})!;
    vm.eventGraph.promoteToVariable(out(create, 'return_value'));
    expect(await vm.save(), isTrue);
    final doc = readBlueprint(project.characterPath);
    expect(doc.variable('HudWidget')!.typeName, 'Widget:WBP_HUD');
    final set = doc.eventGraph.nodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.variableSet);
    expect(set.inputs.firstWhere((p) => p.id == 'value').objectClass, 'Widget:WBP_HUD');
  });
}
