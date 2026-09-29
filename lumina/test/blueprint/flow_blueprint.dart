import 'package:lumina/lumina.dart';

/// A Blueprint exercising every flow construct for VM ↔ codegen parity:
/// Sequence, Branch on a pure comparison, variables, Tick,
/// a latent Delay, and an impure node's output read by a later node.
LuminaBlueprintDocument flowBlueprint() {
  const variables = [
    LuminaBlueprintVariable(name: 'X', typeName: 'Float', defaultValue: 7.0),
    LuminaBlueprintVariable(name: 'Total', typeName: 'Float', defaultValue: '0.0'),
    LuminaBlueprintVariable(name: 'Label', typeName: 'String', defaultValue: 'it\'s \$ok'),
  ];
  const context = LuminaBlueprintTypeContext(variables: variables);
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  return LuminaBlueprintDocument(
    parentClass: 'LuminaActor',
    variables: [...variables],
    eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('sequence', 'seq'),
      place('print_string', 'first', {'in_string': 'first'}),
      place(LuminaBlueprintNodeLibrary.variableGet, 'x', {'variable': 'X'}),
      place('float_greater', 'gt', {'b': 5.0}),
      place('branch', 'if'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'label', {'variable': 'Label'}),
      place('print_string', 'yes'),
      place('print_string', 'no', {'in_string': 'no'}),
      place('event_tick', 'tick'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'total', {'variable': 'Total'}),
      place('float_add', 'add'),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_total', {'variable': 'Total'}),
      place('delay', 'wait', {'duration': 0.25}),
      place('make_vector', 'where'),
      place('float_multiply', 'scaled', {'b': 100.0}),
      place('set_actor_location', 'move'),
      place('break_vector', 'moved_parts'),
      place('get_actor_location', 'here'),
      place('branch', 'moved'),
      place('print_string', 'late', {'in_string': 'late'}),
    ], wires: [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'first', 'exec_in'),
      wire('seq', 'then_1', 'if', 'exec_in'),
      wire('x', 'value', 'gt', 'a'),
      wire('gt', 'return_value', 'if', 'condition'),
      wire('if', 'true_out', 'yes', 'exec_in'),
      wire('label', 'value', 'yes', 'in_string'),
      wire('if', 'false_out', 'no', 'exec_in'),
      wire('tick', 'exec_tick_out', 'set_total', 'exec_in'),
      wire('total', 'value', 'add', 'a'),
      wire('tick', 'delta_seconds', 'add', 'b'),
      wire('add', 'return_value', 'set_total', 'value'),
      wire('set_total', 'exec_out', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'move', 'exec_in'),
      wire('total', 'value', 'scaled', 'a'),
      wire('scaled', 'return_value', 'where', 'x'),
      wire('where', 'return_value', 'move', 'new_location'),
      wire('move', 'exec_out', 'moved', 'exec_in'),
      wire('move', 'return_value', 'moved', 'condition'),
      wire('moved', 'true_out', 'late', 'exec_in'),
      wire('here', 'return_value', 'moved_parts', 'in_vec'),
    ]),
  );
}
