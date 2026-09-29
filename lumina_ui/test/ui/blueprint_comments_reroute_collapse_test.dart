import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/blueprint_test_project.dart';

/// Comment boxes and reroute dots are editor nodes
/// that persist in the `.lmas` and vanish from what the engine compiles.
void main() {
  late BlueprintTestProject project;
  late BlueprintEditorViewModel vm;

  setUpAll(() => project = BlueprintTestProject.create());
  tearDownAll(() => project.dispose());
  setUp(() async {
    vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Move', parentClass: 'LuminaActor'));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test('a comment "Movement" around two nodes moves them with it and persists in the .lmas', () async {
    final tick = vm.addGraphNode('event_tick', const Offset(100, 100))!;
    final move = vm.addGraphNode('add_movement_input', const Offset(400, 100))!;
    final far = vm.addGraphNode('print_string', const Offset(1200, 900))!;
    final comment = vm.eventGraph.addComment(around: const Rect.fromLTWH(100, 100, 600, 200), title: 'Movement')!;
    expect(BlueprintEditorNodes.isComment(comment), isTrue);
    expect(comment.title, 'Movement');
    expect(comment.x, 80);
    expect(vm.eventGraph.problems(comment), isEmpty, reason: 'an editor node is not "unknown"');
    final inside = BlueprintEditorNodes.nodesInside(comment, vm.graphNodes, sizeOf: (n) => (width: 160, height: 80)).map((n) => n.id);
    expect(inside, unorderedEquals([tick.id, move.id]));

    vm.moveNodes([comment.id, ...inside], const Offset(50, 30));
    expect(vm.getGraphNode(tick.id)!.x, 150);
    expect(vm.getGraphNode(move.id)!.y, 130);
    expect(vm.getGraphNode(far.id)!.x, 1200, reason: 'a node outside the box stays');
    expect(vm.eventGraph.setComment(comment.id, title: 'Locomotion', color: 0xFF224466), isTrue);

    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(vm.engineDocument.eventGraph.nodes.map((n) => n.registryId), isNot(contains(BlueprintEditorNodes.comment)));
    expect(await vm.save(), isTrue);
    final saved = readBlueprint(vm.assetPath).eventGraph.node(comment.id)!;
    expect(saved.title, 'Locomotion');
    expect(saved.literals['color'], 0xFF224466);
    expect(saved.literals['width'], 640.0);
  });

  test('double-clicking a wire inserts a reroute keeping the connection; the engine sees the direct wire', () async {
    final tick = vm.addGraphNode('event_tick', const Offset(0, 0))!;
    final move = vm.addGraphNode('add_movement_input', const Offset(600, 0))!;
    final wire = vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: move.id, toPinId: 'scale_val')!;
    final dot = vm.eventGraph.insertReroute(wire.id, const Offset(300, 40))!;
    expect(BlueprintEditorNodes.isReroute(dot), isTrue);
    expect(vm.eventGraph.pinsOf(dot).inputs.single.type, LuminaPinType.float, reason: 'typed as the wire');
    expect(vm.eventGraph.pinsOf(dot).outputs.single.type, LuminaPinType.float);
    expect(vm.graphWires.any((w) => w.fromNodeId == tick.id && w.toNodeId == dot.id && w.toPinId == 'in'), isTrue);
    expect(vm.graphWires.any((w) => w.fromNodeId == dot.id && w.fromPinId == 'out' && w.toNodeId == move.id && w.toPinId == 'scale_val'), isTrue);
    expect(vm.eventGraph.sourceThroughReroutes(dot.id, 'out'), (nodeId: tick.id, pinId: 'delta_seconds'));
    final exec = vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: move.id, toPinId: 'exec_move_in')!;
    final execDot = vm.eventGraph.insertReroute(exec.id, const Offset(300, -40))!;
    expect(vm.eventGraph.pinsOf(execDot).inputs.single.type, LuminaPinType.exec);
    final flat = vm.engineDocument.eventGraph;
    expect(flat.nodes.map((n) => n.registryId), isNot(contains(BlueprintEditorNodes.reroute)));
    expect(flat.wires.any((w) => w.fromNodeId == tick.id && w.fromPinId == 'delta_seconds' && w.toNodeId == move.id && w.toPinId == 'scale_val'), isTrue);
    expect(flat.wires.any((w) => w.fromNodeId == tick.id && w.fromPinId == 'exec_tick_out' && w.toNodeId == move.id && w.toPinId == 'exec_move_in'), isTrue);
    expect(await vm.compile(), isTrue, reason: '${vm.diagnostics}');
    expect(await vm.save(), isTrue);
    expect(readBlueprint(vm.assetPath).eventGraph.node(dot.id)!.registryId, BlueprintEditorNodes.reroute);
    vm.undo();
    vm.undo();
    vm.undo();
    expect(vm.getGraphNode(dot.id), isNull);
    expect(vm.graphWires.any((w) => w.fromNodeId == tick.id && w.toNodeId == move.id && w.toPinId == 'scale_val'), isTrue, reason: 'undo restores the direct wire');
  });
}
