import 'package:lumina/lumina.dart';

/// Every Math|Conversions node in one Blueprint: BeginPlay prints, in order,
/// To Float (Integer) 7 (`7.0`), Round 2.5 (`3`), Truncate -2.7 (`-2`),
/// Floor -2.1 (`-3`), Ceil 2.1 (`3`), To Integer (Bool) true (`1`),
/// To Bool (Integer) 0 (`false`), To Float (Bool) true (`1.0`),
/// String to Int " 42 " (`42`, Success `true`), String to Float "abc"
/// (Success `false`, then the Branch on it prints `not a number`),
/// String to Int "12.7" (`12`), To Name / To String (Name) `Door_01`,
/// To Vector (Float) 2.5 and To Vector 2D (Float) -1 (its Y, `-1.00`).
LuminaBlueprintDocument conversionsBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_conversions');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    // int → float
    place('int_to_float', 'i2f', {'a': 7}),
    place('float_to_string', 'i2f_text', {'decimals': 1}),
    place('print_string', 'say_i2f'),
    // float → int
    place('round', 'round', {'a': 2.5}),
    place('int_to_string', 'round_text'),
    place('print_string', 'say_round'),
    place('truncate', 'truncate', {'a': -2.7}),
    place('int_to_string', 'truncate_text'),
    place('print_string', 'say_truncate'),
    place('floor', 'floor', {'a': -2.1}),
    place('int_to_string', 'floor_text'),
    place('print_string', 'say_floor'),
    place('ceil', 'ceil', {'a': 2.1}),
    place('int_to_string', 'ceil_text'),
    place('print_string', 'say_ceil'),
    // bool ↔ int / float
    place('bool_to_int', 'b2i', {'in_bool': true}),
    place('int_to_string', 'b2i_text'),
    place('print_string', 'say_b2i'),
    place('int_to_bool', 'i2b', {'in_int': 0}),
    place('bool_to_string', 'i2b_text'),
    place('print_string', 'say_i2b'),
    place('bool_to_float', 'b2f', {'in_bool': true}),
    place('float_to_string', 'b2f_text', {'decimals': 1}),
    place('print_string', 'say_b2f'),
    // string → number with Success
    place('string_to_int', 's2i', {'in_string': ' 42 '}),
    place('int_to_string', 's2i_text'),
    place('print_string', 'say_s2i'),
    place('bool_to_string', 's2i_ok_text'),
    place('print_string', 'say_s2i_ok'),
    place('string_to_float', 's2f', {'in_string': 'abc'}),
    place('bool_to_string', 's2f_ok_text'),
    place('print_string', 'say_s2f_ok'),
    place('branch', 'parsed'),
    place('print_string', 'say_parsed', {'in_string': 'parsed'}),
    place('print_string', 'say_not_parsed', {'in_string': 'not a number'}),
    place('string_to_int', 's2i_frac', {'in_string': '12.7'}),
    place('int_to_string', 's2i_frac_text'),
    place('print_string', 'say_s2i_frac'),
    // string ↔ name
    place('string_to_name', 's2n', {'in_string': 'Door_01'}),
    place('name_to_string', 'n2s'),
    place('print_string', 'say_name'),
    // float → vector / vector 2D
    place('float_to_vector', 'f2v', {'in_float': 2.5}),
    place('vector_to_string', 'f2v_text'),
    place('print_string', 'say_f2v'),
    place('float_to_vector2d', 'f2v2', {'in_float': -1.0}),
    place('break_vector2d', 'f2v2_break'),
    place('float_to_string', 'f2v2_text'),
    place('print_string', 'say_f2v2'),
  ]);
  const chain = ['begin', 'say_i2f', 'say_round', 'say_truncate', 'say_floor', 'say_ceil', 'say_b2i', 'say_i2b', 'say_b2f',
    'say_s2i', 'say_s2i_ok', 'say_s2f_ok', 'parsed'];
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  const tail = ['say_s2i_frac', 'say_name', 'say_f2v', 'say_f2v2'];
  for (var k = 0; k + 1 < tail.length; k++) {
    doc.eventGraph.wires.add(wire(tail[k], 'exec_out', tail[k + 1], 'exec_in'));
  }
  doc.eventGraph.wires.addAll([
    wire('parsed', 'true_out', 'say_parsed', 'exec_in'),
    wire('parsed', 'false_out', 'say_not_parsed', 'exec_in'),
    wire('say_parsed', 'exec_out', 'say_s2i_frac', 'exec_in'),
    wire('say_not_parsed', 'exec_out', 'say_s2i_frac', 'exec_in'),
    wire('i2f', 'return_value', 'i2f_text', 'in_float'),
    wire('i2f_text', 'return_value', 'say_i2f', 'in_string'),
    wire('round', 'return_value', 'round_text', 'in_int'),
    wire('round_text', 'return_value', 'say_round', 'in_string'),
    wire('truncate', 'return_value', 'truncate_text', 'in_int'),
    wire('truncate_text', 'return_value', 'say_truncate', 'in_string'),
    wire('floor', 'return_value', 'floor_text', 'in_int'),
    wire('floor_text', 'return_value', 'say_floor', 'in_string'),
    wire('ceil', 'return_value', 'ceil_text', 'in_int'),
    wire('ceil_text', 'return_value', 'say_ceil', 'in_string'),
    wire('b2i', 'return_value', 'b2i_text', 'in_int'),
    wire('b2i_text', 'return_value', 'say_b2i', 'in_string'),
    wire('i2b', 'return_value', 'i2b_text', 'in_bool'),
    wire('i2b_text', 'return_value', 'say_i2b', 'in_string'),
    wire('b2f', 'return_value', 'b2f_text', 'in_float'),
    wire('b2f_text', 'return_value', 'say_b2f', 'in_string'),
    wire('s2i', 'return_value', 's2i_text', 'in_int'),
    wire('s2i_text', 'return_value', 'say_s2i', 'in_string'),
    wire('s2i', 'success', 's2i_ok_text', 'in_bool'),
    wire('s2i_ok_text', 'return_value', 'say_s2i_ok', 'in_string'),
    wire('s2f', 'success', 's2f_ok_text', 'in_bool'),
    wire('s2f_ok_text', 'return_value', 'say_s2f_ok', 'in_string'),
    wire('s2f', 'success', 'parsed', 'condition'),
    wire('s2i_frac', 'return_value', 's2i_frac_text', 'in_int'),
    wire('s2i_frac_text', 'return_value', 'say_s2i_frac', 'in_string'),
    wire('s2n', 'return_value', 'n2s', 'in_name'),
    wire('n2s', 'return_value', 'say_name', 'in_string'),
    wire('f2v', 'return_value', 'f2v_text', 'in_vec'),
    wire('f2v_text', 'return_value', 'say_f2v', 'in_string'),
    wire('f2v2', 'return_value', 'f2v2_break', 'in_vec'),
    wire('f2v2_break', 'y', 'f2v2_text', 'in_float'),
    wire('f2v2_text', 'return_value', 'say_f2v2', 'in_string'),
  ]);
  return doc;
}

/// What [conversionsBlueprint] prints, in order.
const List<String> conversionsBlueprintPrints = [
  '7.0', '3', '-2', '-3', '3', '1', 'false', '1.0', '42', 'true', 'false', 'not a number', '12', 'Door_01',
  'X=2.500 Y=2.500 Z=2.500', '-1.00',
];
