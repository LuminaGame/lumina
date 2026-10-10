import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_clipboard.dart';

/// The clipboard text of copied graph nodes: what a copy keeps, the
/// round trip, fresh ids on paste, and text that is not graph nodes.
void main() {
  LuminaBlueprintNode place(String registryId, String id, double x, double y, {Map<String, dynamic>? literals}) =>
      LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, x: x, y: y, literals: literals);

  LuminaBlueprintWire wire(String id, String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  late LuminaBlueprintGraph graph;

  setUp(() {
    final begin = place('event_beginplay', 'begin', 100, 80);
    final print = place('print_string', 'print', 360, 80, literals: {'in_string': 'Copied text', 'duration': 4.5});
    final delay = place('delay', 'delay', 640, 80);
    final comment = BlueprintEditorNodes.newComment(id: 'note', x: 60, y: 20, width: 520, height: 220, title: 'Start up');
    comment.literals['color'] = 0xFF884422;
    graph = LuminaBlueprintGraph(
      nodes: [comment, begin, print, delay],
      wires: [
        wire('w1', 'begin', 'exec_out', 'print', 'exec_in'),
        wire('w2', 'print', 'exec_out', 'delay', 'exec_in'),
      ],
    );
  });

  test('a copy keeps the wires between copied nodes and drops wires to the others', () {
    final copy = BlueprintGraphClipboard.copy(graph, {'begin', 'print'}, graphKind: BlueprintGraphClipboard.blueprintKind);
    expect(copy.nodes.map((n) => n.id), ['begin', 'print']);
    expect(copy.wires.map((w) => w.id), ['w1']);
    expect(copy.origin, const Offset(100, 80));
  });

  test('encode then decode keeps nodes, literals, pins, positions, comments and wires', () {
    final copy = BlueprintGraphClipboard.copy(graph, {'note', 'begin', 'print', 'delay'},
        graphKind: BlueprintGraphClipboard.blueprintKind,
        variableOf: (name) => const LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 100.0));
    final text = copy.encode();
    final header = jsonDecode(text) as Map<String, dynamic>;
    expect(header['format'], 'lumina.graph-nodes');
    expect(header['version'], 1);
    expect(header['graph'], 'blueprint');

    final back = BlueprintGraphClipboard.decode(text)!;
    expect(back.graphKind, 'blueprint');
    expect(back.nodes.map((n) => n.toJson()).toList(), copy.nodes.map((n) => n.toJson()).toList());
    expect(back.wires.map((w) => w.toJson()).toList(), copy.wires.map((w) => w.toJson()).toList());
    final print = back.nodes.firstWhere((n) => n.id == 'print');
    expect(print.literals['in_string'], 'Copied text');
    expect(print.literals['duration'], 4.5);
    final note = back.nodes.firstWhere((n) => n.id == 'note');
    expect(BlueprintEditorNodes.isComment(note), isTrue);
    expect(BlueprintEditorNodes.commentWidth(note), 520);
    expect(BlueprintEditorNodes.commentColor(note), 0xFF884422);
  });

  test('a copied variable node carries its variable declaration', () {
    final get = place('variable_get', 'get', 0, 0, literals: {'variable': 'Health'});
    final other = place('variable_get', 'other', 0, 60, literals: {'variable': 'Speed', 'class': 'Actor:BP_Door'});
    final g = LuminaBlueprintGraph(nodes: [get, other]);
    final copy = BlueprintGraphClipboard.copy(g, {'get', 'other'},
        graphKind: BlueprintGraphClipboard.blueprintKind,
        variableOf: (name) => name == 'Health' ? const LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 75.0) : null);
    final back = BlueprintGraphClipboard.decode(copy.encode())!;
    expect(back.variables.map((v) => v.toJson()), [
      {'name': 'Health', 'type': 'Float', 'default': 75.0},
    ]);
    expect(BlueprintGraphClipboard.memberVariableOf(other), isNull, reason: 'another class\'s variable is never declared');
  });

  test('instantiate gives fresh ids, moves the nodes to the point and re-points the wires', () {
    final copy = BlueprintGraphClipboard.decode(
        BlueprintGraphClipboard.copy(graph, {'begin', 'print'}, graphKind: BlueprintGraphClipboard.blueprintKind).encode())!;
    var n = 0;
    final made = copy.instantiate(at: const Offset(1000, 500), newId: (prefix) => '${prefix}_new${n++}');
    expect(made.nodes.map((x) => x.id), ['node_new0', 'node_new1']);
    expect(made.nodes.map((x) => Offset(x.x, x.y)), [const Offset(1000, 500), const Offset(1260, 500)]);
    expect(made.wires.single.fromNodeId, 'node_new0');
    expect(made.wires.single.toNodeId, 'node_new1');
    expect(made.wires.single.id, 'wire_new2');
    // The source copy is untouched: a second paste starts from the same text.
    expect(copy.nodes.map((x) => x.id), ['begin', 'print']);

    final onlyPrint = copy.instantiate(at: Offset.zero, newId: (p) => '${p}_x${n++}', keep: (x) => x.id == 'print');
    expect(onlyPrint.nodes.single.registryId, 'print_string');
    expect(onlyPrint.wires, isEmpty);
  });

  test('text that is not Lumina graph nodes decodes to null', () {
    for (final text in [
      null,
      '',
      'not a graph',
      '{}',
      '[1, 2, 3]',
      '{"format": "something.else", "version": 1, "graph": "blueprint", "nodes": [{"id": "a", "registryId": "delay"}]}',
      '{"format": "lumina.graph-nodes", "version": 99, "graph": "blueprint", "nodes": [{"id": "a", "registryId": "delay"}]}',
      '{"format": "lumina.graph-nodes", "version": 1, "graph": "blueprint", "nodes": []}',
      '{"format": "lumina.graph-nodes", "version": 1, "graph": "blueprint", "nodes": [{"id": "", "registryId": ""}]}',
      '{"format": "lumina.graph-nodes", "version": 1, "graph": "blueprint", "nodes": "x"}',
      '{"format": "lumina.graph-nodes", "version": 1, "graph": "blueprint", "nodes": [{"id": "a", "registryId": "delay", "position": 3}]}',
      '{"format": "lumina.graph-nodes", "ver',
    ]) {
      expect(BlueprintGraphClipboard.decode(text), isNull, reason: text);
    }
  });

  test('single-instance keys follow the one-node-per-event rule', () {
    expect(BlueprintGraphClipboard.singleInstanceKey(place('event_beginplay', 'a', 0, 0)), 'event_beginplay');
    expect(BlueprintGraphClipboard.singleInstanceKey(place('print_string', 'b', 0, 0)), isNull);
    expect(
        BlueprintGraphClipboard.singleInstanceKey(place('custom_event', 'c', 0, 0, literals: {'name': 'OnOpen'})), 'custom_event:OnOpen');
  });
}
