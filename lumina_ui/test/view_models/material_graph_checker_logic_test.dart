import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintGraph, LuminaBlueprintWire;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';

/// The type checker's rules for the logic nodes: a Condition takes a bool,
/// an If's Then and Else agree, Compare takes floats, and a bool never
/// reaches float math.
const _surface = MaterialSurface();

LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: '$from$fromPin$to$toPin', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

/// A graph whose Roughness is an If; [extra] adds what feeds it.
LuminaBlueprintGraph _graph(void Function(LuminaBlueprintGraph g) extra) {
  final g = LuminaBlueprintGraph();
  MaterialNodes.ensureOutput(g);
  g.nodes.add(MaterialNodes.create(MaterialLogicNodes.ifNode, id: 'if'));
  extra(g);
  return g;
}

List<String> _errorsOn(MaterialGraphAnalysis a, String nodeId, String pinId) => [
      for (final d in a.diagnostics)
        if (d.isError && d.nodeId == nodeId && d.pinId == pinId) d.message,
    ];

void main() {
  test('a float wired into Condition is an error on that pin', () {
    final g = _graph((g) {
      g.nodes.add(MaterialNodes.create(MaterialNodes.constant, id: 'k', literals: {'value': 0.5}));
      g.wires.addAll([_w('k', 'out', 'if', 'condition'), _w('if', 'out', MaterialNodes.outputNodeId, MaterialNodes.roughness)]);
    });
    final a = MaterialGraphChecker.check(g, _surface);
    expect(_errorsOn(a, 'if', 'condition'), [contains('Condition expects bool, got float')]);
    expect(a.inputHasError('if', 'condition'), isTrue, reason: 'the wire is drawn red');
  });

  test('an If with a float3 Then and a float2 Else is an error', () {
    final g = _graph((g) {
      g.nodes.addAll([
        MaterialNodes.create(MaterialLogicNodes.compare, id: 'cmp', literals: {'a': 1.0}),
        MaterialNodes.create(MaterialNodes.constant3, id: 'v3'),
        MaterialNodes.create(MaterialNodes.constant2, id: 'v2'),
      ]);
      g.wires.addAll([
        _w('cmp', 'out', 'if', 'condition'),
        _w('v3', 'out', 'if', 'then'),
        _w('v2', 'out', 'if', 'else'),
        _w('if', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
      ]);
    });
    final a = MaterialGraphChecker.check(g, _surface);
    expect(_errorsOn(a, 'if', 'else'), [contains('Then and Else must be the same type (float3 vs float2)')]);
  });

  test('an If with a float Then and a float3 Else broadcasts and generates a typed conditional', () {
    final g = _graph((g) {
      g.nodes.addAll([
        MaterialNodes.create(MaterialLogicNodes.compare, id: 'cmp', literals: {'a': 1.0, 'op': '<'}),
        MaterialNodes.create(MaterialNodes.constant3, id: 'v3', literals: {'value': [0.2, 0.4, 0.6]}),
      ]);
      g.wires.addAll([
        _w('cmp', 'out', 'if', 'condition'),
        _w('v3', 'out', 'if', 'else'),
        _w('if', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
      ]);
    });
    final a = MaterialGraphChecker.check(g, _surface);
    expect(a.hasErrors, isFalse, reason: '${a.diagnostics}');
    expect(a.outputType('if', 'out'), MaterialValueType.float3);
    expect(a.outputType('cmp', 'out'), MaterialValueType.boolean);
    final code = MaterialGraphCodegen.generate(g, currentSource: '', surface: _surface);
    expect(code, contains('((1.0 < 0.0) ? vec3(1.0) : vec3(0.2, 0.4, 0.6))'));
  });

  test('a Compare on a float2 is an error on that input', () {
    final g = _graph((g) {
      g.nodes.addAll([
        MaterialNodes.create(MaterialLogicNodes.compare, id: 'cmp'),
        MaterialNodes.create(MaterialNodes.constant2, id: 'v2'),
      ]);
      g.wires.addAll([
        _w('v2', 'out', 'cmp', 'a'),
        _w('cmp', 'out', 'if', 'condition'),
        _w('if', 'out', MaterialNodes.outputNodeId, MaterialNodes.roughness),
      ]);
    });
    final a = MaterialGraphChecker.check(g, _surface);
    expect(_errorsOn(a, 'cmp', 'a'), [contains('A expects float, got float2')]);
  });

  test('a bool into float math, into And from a float, and a missing Condition are errors', () {
    final g = _graph((g) {
      g.nodes.addAll([
        MaterialNodes.create(MaterialLogicNodes.compare, id: 'cmp'),
        MaterialNodes.create(MaterialNodes.multiply, id: 'mul'),
        MaterialNodes.create(MaterialLogicNodes.and, id: 'and'),
        MaterialNodes.create(MaterialNodes.constant, id: 'k'),
      ]);
      g.wires.addAll([
        _w('cmp', 'out', 'mul', 'a'),
        _w('mul', 'out', MaterialNodes.outputNodeId, MaterialNodes.metallic),
        _w('k', 'out', 'and', 'a'),
        _w('cmp', 'out', 'and', 'b'),
        _w('and', 'out', MaterialNodes.outputNodeId, MaterialNodes.specular),
        _w('if', 'out', MaterialNodes.outputNodeId, MaterialNodes.roughness),
      ]);
    });
    final a = MaterialGraphChecker.check(g, _surface);
    expect(_errorsOn(a, 'mul', 'a'), [contains('cannot take a bool')]);
    expect(_errorsOn(a, 'and', 'a'), [contains('A expects bool, got float')]);
    expect(_errorsOn(a, 'if', 'condition'), [contains("missing input 'Condition'")]);
    expect(_errorsOn(a, MaterialNodes.outputNodeId, MaterialNodes.specular), [contains('expects float, got bool')]);
  });

  test('logic nodes are available in the vertex stage', () {
    for (final id in [
      MaterialLogicNodes.compare,
      MaterialLogicNodes.and,
      MaterialLogicNodes.or,
      MaterialLogicNodes.not,
      MaterialLogicNodes.ifNode,
    ]) {
      expect(MaterialNodes.isVertexAvailable(id), isTrue, reason: id);
      expect(MaterialNodes.spec(id)!.category, 'Logic');
    }
    final ifSpec = MaterialNodes.spec(MaterialLogicNodes.ifNode)!;
    expect([for (final p in ifSpec.inputs) '${p.id}:${p.name}'], ['condition:Condition', 'then:Then', 'else:Else']);
    expect(ifSpec.outputs.single.name, 'Result');
    expect(ifSpec.tooltip, contains('Picks Then where Condition holds, else Else; both are evaluated'));
  });
}
