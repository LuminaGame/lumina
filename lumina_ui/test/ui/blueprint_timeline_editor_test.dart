import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/blueprint_test_project.dart';

/// The Timeline node's curve tab writes lumina's
/// Timeline literals.
void main() {
  late BlueprintTestProject project;
  late BlueprintEditorViewModel vm;

  setUpAll(() => project = BlueprintTestProject.create());
  tearDownAll(() => project.dispose());
  setUp(() async {
    vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Swing', parentClass: 'LuminaActor'));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test('a Timeline with a float track Alpha (0,0) (1,90) cubic, length 1 s, saves into the literals and shows an Alpha output', () async {
    final timeline = vm.addGraphNode('timeline', const Offset(300, 0))!;
    vm.openTimeline(timeline.id);
    expect(vm.activeGraph, BlueprintGraphRef.timeline(timeline.id));
    expect(vm.setTimelineLength(timeline.id, 1.0), isTrue);
    expect(vm.setTimelineLoop(timeline.id, false), isTrue);
    expect(vm.setTimelineLoop(timeline.id, false), isFalse, reason: 'already off');
    expect(vm.setTimelineAutoPlay(timeline.id, true), isTrue);
    expect(vm.addTimelineTrack(timeline.id, 'Alpha'), 'Alpha');
    expect(vm.setTimelineKeys(timeline.id, 'Alpha', [
      const LuminaTimelineKey(0.0, [0.0], LuminaTimelineInterp.cubic),
      const LuminaTimelineKey(1.0, [90.0], LuminaTimelineInterp.cubic),
    ]), isTrue);
    final node = vm.getGraphNode(timeline.id)!;
    expect(node.literals['length'], 1.0);
    expect(node.literals['autoPlay'], true);
    expect(node.literals['tracks'], [
      {
        'name': 'Alpha',
        'type': 'float',
        'keys': [
          {'time': 0.0, 'value': 0.0, 'interp': 'cubic'},
          {'time': 1.0, 'value': 90.0, 'interp': 'cubic'},
        ],
      }
    ]);
    expect(vm.eventGraph.pinsOf(node).outputs.map((p) => '${p.id}:${p.type.name}'), ['update:exec', 'finished:exec', 'direction:enumeration', 'Alpha:float']);
    final track = vm.timelineTracks(timeline.id).single;
    expect(track.evaluate(0.5), closeTo(45.0, 2.0), reason: 'the curve evaluates as lumina will play it');
    expect(vm.eventGraph.pinOptions(node, vm.eventGraph.pinsOf(node).outputs[2]), ['Forward', 'Backward']);

    // A vector track, rename follows wires, keys clamp to the length.
    expect(vm.addTimelineTrack(timeline.id, 'Offset', type: 'vector'), 'Offset');
    final set = vm.addGraphNode('set_actor_location', const Offset(700, 0))!;
    expect(vm.addGraphWire(fromNodeId: timeline.id, fromPinId: 'Offset', toNodeId: set.id, toPinId: 'new_location'), isNotNull);
    expect(vm.renameTimelineTrack(timeline.id, 'Offset', 'Position'), isTrue);
    expect(vm.graphWires.any((w) => w.fromNodeId == timeline.id && w.fromPinId == 'Position' && w.toNodeId == set.id), isTrue);
    expect(vm.setTimelineKeys(timeline.id, 'Alpha', [const LuminaTimelineKey(5.0, [1.0])]), isTrue);
    expect(vm.timelineTracks(timeline.id).first.keys.single.time, 1.0);
    expect(vm.removeTimelineTrack(timeline.id, 'Position'), isTrue);
    expect(vm.graphWires.any((w) => w.fromNodeId == timeline.id && w.fromPinId == 'Position'), isFalse, reason: 'its wire went with the pin');

    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(await vm.save(), isTrue);
    final saved = readBlueprint(vm.assetPath).eventGraph.node(timeline.id)!;
    expect((saved.literals['tracks'] as List).single['name'], 'Alpha');
    vm.undo();
    expect(vm.timelineTracks(timeline.id), hasLength(2), reason: 'one undo step per edit');
  });
}
