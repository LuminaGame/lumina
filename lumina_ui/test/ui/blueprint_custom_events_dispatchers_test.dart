import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/blueprint_test_project.dart';

/// Custom events with parameters and event dispatchers
/// (Call / Bind / Unbind / Assign) on a real project.
void main() {
  late BlueprintTestProject project;
  late BlueprintEditorViewModel vm;

  setUpAll(() => project = BlueprintTestProject.create());
  tearDownAll(() => project.dispose());

  setUp(() async {
    vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Door', parentClass: 'LuminaActor'));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test('Add Custom Event OnScored with Points: int places the event; Call OnScored lists it with the parameter', () async {
    final event = vm.eventGraph.addCustomEvent('OnScored', const Offset(0, 500))!;
    expect(event.registryId, LuminaBlueprintNodeLibrary.customEvent);
    expect(event.title, 'OnScored');
    expect(vm.eventGraph.pinsOf(event).outputs.map((p) => p.id), ['exec_out', 'delegate']);
    expect(vm.eventGraph.setCustomEventParameters(event.id, [const LuminaBlueprintVariable(name: 'Points', typeName: 'Int', defaultValue: 0)]), isTrue);
    expect(vm.eventGraph.pinsOf(event).outputs.map((p) => '${p.id}:${p.type.name}'), ['exec_out:exec', 'delegate:delegate', 'Points:integer']);
    final row = vm.eventGraph.paletteEntries().singleWhere((e) => e.key == 'call_custom_event_OnScored');
    expect(row.title, 'Call OnScored');
    final call = vm.eventGraph.placeEntry(row, const Offset(300, 500))!;
    expect(vm.eventGraph.pinsOf(call).inputs.map((p) => '${p.id}:${p.type.name}'), ['exec_in:exec', 'Points:integer']);
    expect(vm.eventGraph.problems(call), isEmpty);
    // A second event of the same name is refused; renaming follows the calls.
    expect(vm.eventGraph.addCustomEvent('OnScored', Offset.zero)!.literals['name'], 'OnScored2');
    expect(vm.eventGraph.renameCustomEvent(event.id, 'OnPointsScored'), isTrue);
    expect(vm.getGraphNode(call.id)!.literals['event'], 'OnPointsScored');
    expect(vm.eventGraph.problems(call), isEmpty);
    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(await vm.save(), isTrue);
    final saved = readBlueprint(vm.assetPath).eventGraph.node(event.id)!;
    expect(saved.literals['parameters'], [
      {'name': 'Points', 'type': 'Int', 'default': 0}
    ]);
  });

  test('a dispatcher OnDoorOpened offers Call / Bind / Unbind / Unbind All and Assign; Bind takes only a custom event delegate', () {
    expect(vm.addDispatcher('OnDoorOpened'), 'OnDoorOpened');
    expect(vm.selectedDispatcher, 'OnDoorOpened');
    vm.setDispatcherParameters('OnDoorOpened', [const LuminaBlueprintVariable(name: 'Opener', typeName: 'String', defaultValue: '')]);
    final keys = vm.eventGraph.paletteEntries().where((e) => e.literals['dispatcher'] == 'OnDoorOpened').map((e) => e.registryId);
    expect(keys, unorderedEquals(['call_dispatcher', 'bind_event_to_dispatcher', 'unbind_event_from_dispatcher', 'unbind_all_events']));

    final call = vm.eventGraph.placeDispatcher('OnDoorOpened', registryId: LuminaBlueprintNodeLibrary.callDispatcher, position: Offset.zero)!;
    expect(call.title, 'Call On Door Opened');
    expect(vm.eventGraph.pinsOf(call).inputs.map((p) => p.id), ['exec_in', 'Opener']);
    final bind = vm.eventGraph.placeDispatcher('OnDoorOpened', registryId: LuminaBlueprintNodeLibrary.bindEventToDispatcher, position: Offset.zero)!;
    expect(vm.eventGraph.pinsOf(bind).inputs.map((p) => p.id), ['exec_in', 'target', 'event']);

    final event = vm.eventGraph.addCustomEvent('OnOpened', const Offset(0, 300))!;
    expect(vm.eventGraph.whyNotConnect(event.id, 'delegate', bind.id, 'event'), isNull);
    expect(vm.addGraphWire(fromNodeId: event.id, fromPinId: 'delegate', toNodeId: bind.id, toPinId: 'event'), isNotNull);
    final tick = vm.addGraphNode('event_tick', const Offset(0, 600))!;
    expect(vm.eventGraph.whyNotConnect(tick.id, 'delta_seconds', bind.id, 'event'), isNotNull, reason: 'a float is not a delegate');
    expect(vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: bind.id, toPinId: 'event'), isNull);

    // Assign: a Bind plus a fresh custom event wired into it.
    final assigned = vm.eventGraph.assignDispatcher('OnDoorOpened', position: const Offset(500, 500))!;
    expect(assigned.registryId, LuminaBlueprintNodeLibrary.bindEventToDispatcher);
    final wire = vm.graphWires.singleWhere((w) => w.toNodeId == assigned.id && w.toPinId == 'event');
    final made = vm.getGraphNode(wire.fromNodeId)!;
    expect(made.registryId, LuminaBlueprintNodeLibrary.customEvent);
    expect(made.literals['name'], 'OnDoorOpened_Event');
    expect(vm.eventGraph.pinsOf(made).outputs.map((p) => p.id), contains('Opener'), reason: 'the event takes the dispatcher parameters');

    // Rename follows the nodes; delete removes them.
    expect(vm.renameDispatcher('OnDoorOpened', 'OnOpened2'), isTrue);
    expect(vm.getGraphNode(call.id)!.literals['dispatcher'], 'OnOpened2');
    expect(vm.getGraphNode(call.id)!.title, 'Call On Opened2');
    expect(vm.deleteDispatcher('OnOpened2'), isTrue);
    expect(vm.getGraphNode(call.id), isNull);
    expect(vm.getGraphNode(bind.id), isNull);
    expect(vm.getGraphNode(event.id), isNotNull, reason: 'the event itself stays');
    vm.undo();
    expect(vm.document.dispatcher('OnOpened2'), isNotNull);
    expect(vm.getGraphNode(call.id), isNotNull);
  });
}
