import 'package:lumina/lumina.dart';

/// Flow and pure node parity fixtures: [flowNodesBlueprint] runs every
/// flow-control macro plus the FPS string chain and a variable array;
/// [pureNodesBlueprint] prints the result of every pure math / string / array
/// / struct node with its default literals (a table over the node ids), so the VM
/// and the generated Dart are compared node for node.

int _wires = 0;
LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: 'w${_wires++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

LuminaBlueprintDocument flowNodesBlueprint() {
  _wires = 0;
  const variables = [
    LuminaBlueprintVariable(name: 'Ticks', typeName: 'Int', defaultValue: 0),
    LuminaBlueprintVariable(name: 'N', typeName: 'Int', defaultValue: 0),
    LuminaBlueprintVariable(name: 'Log', typeName: 'Array:String', defaultValue: []),
    LuminaBlueprintVariable(name: 'Key', typeName: 'String', defaultValue: 'b'),
  ];
  const context = LuminaBlueprintTypeContext(variables: variables);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  return LuminaBlueprintDocument(variables: [...variables], eventGraph: LuminaBlueprintGraph(nodes: [
    // BeginPlay: ForLoop 0..2 → body prints index; Completed → ForLoopWithBreak
    // (breaks at 1) → WhileLoop counting N to 3 → ForEachLoop over a Make
    // Array → switches → DoOnce twice (second blocked).
    p('event_beginplay', 'begin'),
    p('for_loop', 'loop', {'first_index': 0, 'last_index': 2}),
    p('int_to_string', 'idx_text'),
    p('print_string', 'body'),
    p('for_loop_with_break', 'brk_loop', {'first_index': 0, 'last_index': 9}),
    p('int_equal', 'is_one', {'b': 1}),
    p('branch', 'if_one'),
    p('int_to_string', 'bidx_text'),
    p('print_string', 'bbody'),
    p('while_loop', 'count'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'n', {'variable': 'N'}),
    p('int_less', 'lt', {'b': 3}),
    p('int_increment', 'inc'),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_n', {'variable': 'N'}),
    p('make_array', 'names', {'count': 3, 'type': 'string', 'item_0': 'a', 'item_1': 'b', 'item_2': 'c'}),
    p('for_each_loop', 'each', {'type': 'string'}),
    p('int_to_string', 'each_idx'),
    p('append_3', 'label', {'b': ':'}),
    p('print_string', 'each_body'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'key', {'variable': 'Key'}),
    p('switch_on_string', 'sw', {'cases': ['a', 'b']}),
    p('print_string', 'sa', {'in_string': 'case a'}),
    p('print_string', 'sb', {'in_string': 'case b'}),
    p('print_string', 'sd', {'in_string': 'default'}),
    p('switch_on_int', 'swi', {'cases': [1, 2], 'selection': 5}),
    p('print_string', 'i1', {'in_string': 'one'}),
    p('print_string', 'idef', {'in_string': 'int default'}),
    p('switch_on_bool', 'swb', {'selection': false}),
    p('print_string', 'bf', {'in_string': 'no'}),
    p('sequence', 'twice'),
    p('do_once', 'once'),
    p('print_string', 'p_once', {'in_string': 'once'}),
    // Tick: FlipFlop A/B → DoN(3) → Gate (toggled every tick) → MultiGate(loop)
    // → the FPS chain → Add to the Log array → Retriggerable Delay.
    p('event_tick', 'tick'),
    p('flip_flop', 'ff'),
    p('print_string', 'p_a', {'in_string': 'A'}),
    p('print_string', 'p_b', {'in_string': 'B'}),
    p('do_n', 'do_n', {'n': 3}),
    p('int_to_string', 'count_text'),
    p('print_string', 'counted'),
    p('sequence', 'gate_seq'),
    p('gate', 'gate', {'start_closed': false}),
    p('print_string', 'through', {'in_string': 'through'}),
    p('multi_gate', 'mg', {'count': 2, 'loop': true}),
    p('print_string', 'm0', {'in_string': 'out 0'}),
    p('print_string', 'm1', {'in_string': 'out 1'}),
    p('float_divide', 'fps', {'a': 1.0}),
    p('round', 'fps_round'),
    p('int_to_string', 'fps_text'),
    p('format_string', 'fps_label', {'format': 'FPS: {0}'}),
    p('print_string', 'say_fps'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'log', {'variable': 'Log'}),
    p('array_add', 'add', {'type': 'string'}),
    p('array_length', 'len'),
    p('int_to_string', 'len_text'),
    p('print_string', 'say_len'),
    p('retriggerable_delay', 'wait', {'duration': 0.05}),
    p('print_string', 'late', {'in_string': 'late'}),
  ], wires: [
    _w('begin', 'exec_out', 'loop', 'exec_in'),
    _w('loop', 'loop_body', 'body', 'exec_in'),
    _w('loop', 'index', 'idx_text', 'in_int'),
    _w('idx_text', 'return_value', 'body', 'in_string'),
    _w('loop', 'completed', 'brk_loop', 'exec_in'),
    _w('brk_loop', 'loop_body', 'if_one', 'exec_in'),
    _w('brk_loop', 'index', 'is_one', 'a'),
    _w('is_one', 'return_value', 'if_one', 'condition'),
    _w('if_one', 'true_out', 'brk_loop', 'break'),
    _w('if_one', 'false_out', 'bbody', 'exec_in'),
    _w('brk_loop', 'index', 'bidx_text', 'in_int'),
    _w('bidx_text', 'return_value', 'bbody', 'in_string'),
    _w('brk_loop', 'completed', 'count', 'exec_in'),
    _w('n', 'value', 'lt', 'a'),
    _w('lt', 'return_value', 'count', 'condition'),
    _w('count', 'loop_body', 'set_n', 'exec_in'),
    _w('n', 'value', 'inc', 'a'),
    _w('inc', 'return_value', 'set_n', 'value'),
    _w('count', 'completed', 'each', 'exec_in'),
    _w('names', 'return_value', 'each', 'array'),
    _w('each', 'loop_body', 'each_body', 'exec_in'),
    _w('each', 'array_index', 'each_idx', 'in_int'),
    _w('each_idx', 'return_value', 'label', 'a'),
    _w('each', 'array_element', 'label', 'c'),
    _w('label', 'return_value', 'each_body', 'in_string'),
    _w('each', 'completed', 'sw', 'exec_in'),
    _w('key', 'value', 'sw', 'selection'),
    _w('sw', 'case_0', 'sa', 'exec_in'),
    _w('sw', 'case_1', 'sb', 'exec_in'),
    _w('sw', 'default', 'sd', 'exec_in'),
    _w('sb', 'exec_out', 'swi', 'exec_in'),
    _w('swi', 'case_0', 'i1', 'exec_in'),
    _w('swi', 'default', 'idef', 'exec_in'),
    _w('idef', 'exec_out', 'swb', 'exec_in'),
    _w('swb', 'false_out', 'bf', 'exec_in'),
    _w('bf', 'exec_out', 'twice', 'exec_in'),
    _w('twice', 'then_0', 'once', 'exec_in'),
    _w('twice', 'then_1', 'once', 'exec_in'),
    _w('once', 'completed', 'p_once', 'exec_in'),
    _w('tick', 'exec_tick_out', 'ff', 'exec_in'),
    _w('ff', 'a', 'p_a', 'exec_in'),
    _w('ff', 'b', 'p_b', 'exec_in'),
    _w('p_a', 'exec_out', 'do_n', 'exec_in'),
    _w('p_b', 'exec_out', 'do_n', 'exec_in'),
    _w('do_n', 'exit', 'counted', 'exec_in'),
    _w('do_n', 'counter', 'count_text', 'in_int'),
    _w('count_text', 'return_value', 'counted', 'in_string'),
    _w('counted', 'exec_out', 'gate_seq', 'exec_in'),
    _w('gate_seq', 'then_0', 'gate', 'exec_in'),
    _w('gate_seq', 'then_1', 'gate', 'toggle'),
    _w('gate', 'exit', 'through', 'exec_in'),
    _w('through', 'exec_out', 'mg', 'exec_in'),
    _w('mg', 'out_0', 'm0', 'exec_in'),
    _w('mg', 'out_1', 'm1', 'exec_in'),
    _w('m0', 'exec_out', 'say_fps', 'exec_in'),
    _w('m1', 'exec_out', 'say_fps', 'exec_in'),
    _w('tick', 'delta_seconds', 'fps', 'b'),
    _w('fps', 'return_value', 'fps_round', 'a'),
    _w('fps_round', 'return_value', 'fps_text', 'in_int'),
    _w('fps_text', 'return_value', 'fps_label', 'arg_0'),
    _w('fps_label', 'return_value', 'say_fps', 'in_string'),
    _w('say_fps', 'exec_out', 'add', 'exec_in'),
    _w('log', 'value', 'add', 'target_array'),
    _w('fps_label', 'return_value', 'add', 'new_item'),
    _w('add', 'exec_out', 'say_len', 'exec_in'),
    _w('log', 'value', 'len', 'target_array'),
    _w('len', 'return_value', 'len_text', 'in_int'),
    _w('len_text', 'return_value', 'say_len', 'in_string'),
    _w('say_len', 'exec_out', 'wait', 'exec_in'),
    _w('wait', 'exec_out', 'late', 'exec_in'),
  ]));
}

/// The pure math / string / array / struct nodes (plus the make/break pairs) and a literal
/// or two that makes each result non-trivial.
const Map<String, Map<String, dynamic>> pureNodeLiterals = {
  'float_abs': {'a': -2.5}, 'float_min': {'a': 1.0, 'b': 2.0}, 'float_max': {'a': 1.0, 'b': 2.0},
  'float_lerp': {'a': 0.0, 'b': 10.0, 'alpha': 0.25},
  'float_interp_to': {'current': 0.0, 'target': 100.0, 'delta_time': 0.1, 'interp_speed': 5.0},
  'float_sqrt': {'a': 16.0}, 'float_power': {'a': 2.0, 'b': 3.0}, 'float_modulo': {'a': 7.5, 'b': 2.0}, 'float_sign': {'a': -3.0},
  'float_map_range_clamped': {'value': 5.0, 'in_range_a': 0.0, 'in_range_b': 10.0, 'out_range_a': 0.0, 'out_range_b': 1.0},
  'float_nearly_equal': {'a': 1.0, 'b': 1.0}, 'float_sin': {'a': 30.0}, 'float_cos': {'a': 60.0}, 'float_tan': {'a': 45.0},
  'float_asin': {'a': 0.5}, 'float_acos': {'a': 0.5}, 'float_atan': {'a': 1.0}, 'float_atan2': {'y': 1.0, 'x': 1.0},
  'degrees_to_radians': {'a': 180.0}, 'radians_to_degrees': {'a': 3.0}, 'float_greater_equal': {'a': 2.0, 'b': 2.0},
  'float_less_equal': {'a': 2.0, 'b': 1.0}, 'float_not_equal': {'a': 2.0, 'b': 1.0}, 'select_float': {'a': 1.0, 'b': 2.0, 'pick_a': false},
  'round': {'a': 2.5}, 'truncate': {'a': -2.7}, 'ceil': {'a': 2.1}, 'floor': {'a': -2.1}, 'int_to_float': {'a': 3},
  'int_add': {'a': 4, 'b': 2}, 'int_subtract': {'a': 4, 'b': 2}, 'int_multiply': {'a': 4, 'b': 2}, 'int_divide': {'a': 7, 'b': 0},
  'int_modulo': {'a': 7, 'b': 3}, 'int_clamp': {'value': 15, 'min': 0, 'max': 10}, 'int_abs': {'a': -4}, 'int_min': {'a': 4, 'b': 2},
  'int_max': {'a': 4, 'b': 2}, 'int_greater': {'a': 4, 'b': 2}, 'int_less': {'a': 4, 'b': 2}, 'int_equal': {'a': 2, 'b': 2},
  'int_not_equal': {'a': 2, 'b': 2}, 'int_greater_equal': {'a': 2, 'b': 2}, 'int_less_equal': {'a': 1, 'b': 2},
  'int_increment': {'a': 4}, 'select_int': {'a': 1, 'b': 2, 'pick_a': true},
  'vector_normalize': {'a': [0.0, 3.0, 4.0]}, 'vector_dot': {'a': [1.0, 2.0, 3.0], 'b': [4.0, 5.0, 6.0]},
  'vector_cross': {'a': [1.0, 0.0, 0.0], 'b': [0.0, 1.0, 0.0]}, 'vector_distance': {'a': [0.0, 0.0, 0.0], 'b': [3.0, 4.0, 0.0]},
  'vector_distance_2d': {'a': [0.0, 0.0, 9.0], 'b': [3.0, 4.0, 0.0]}, 'vector_lerp': {'a': [0.0, 0.0, 0.0], 'b': [10.0, 0.0, 0.0], 'alpha': 0.5},
  'vector_interp_to': {'current': [0.0, 0.0, 0.0], 'target': [100.0, 0.0, 0.0], 'delta_time': 0.1, 'interp_speed': 5.0},
  'vector_subtract': {'a': [3.0, 3.0, 3.0], 'b': [1.0, 2.0, 3.0]}, 'vector_divide_float': {'a': [2.0, 4.0, 6.0], 'b': 2.0},
  'vector_negate': {'a': [1.0, -2.0, 3.0]}, 'vector_equal': {'a': [1.0, 1.0, 1.0], 'b': [1.0, 1.0, 1.0]},
  'vector_project_on_to': {'a': [2.0, 3.0, 0.0], 'b': [1.0, 0.0, 0.0]},
  'rotate_vector_around_axis': {'in_vect': [1.0, 0.0, 0.0], 'angle_deg': 90.0, 'axis': [0.0, 0.0, 1.0]},
  'get_up_vector': {'in_rot': [30.0, 0.0, 0.0]}, 'vector_is_zero': {'a': [0.0, 0.0, 0.0]},
  'select_vector': {'a': [1.0, 0.0, 0.0], 'b': [0.0, 1.0, 0.0], 'pick_a': false},
  'combine_rotators': {'a': [0.0, 0.0, 30.0], 'b': [0.0, 0.0, 40.0]}, 'delta_rotator': {'a': [0.0, 0.0, 170.0], 'b': [0.0, 0.0, -170.0]},
  'rotator_lerp': {'a': [0.0, 0.0, 0.0], 'b': [0.0, 0.0, 90.0], 'alpha': 0.5},
  'rotator_interp_to': {'current': [0.0, 0.0, 0.0], 'target': [0.0, 0.0, 90.0], 'delta_time': 0.1, 'interp_speed': 5.0},
  'find_look_at_rotation': {'start': [0.0, 0.0, 0.0], 'target': [100.0, 100.0, 50.0]},
  'rotator_equal': {'a': [0.0, 0.0, 180.0], 'b': [0.0, 0.0, -180.0]},
  'clamp_angle': {'angle_degrees': 370.0, 'min_angle': -180.0, 'max_angle': 180.0}, 'normalize_axis': {'angle': -190.0},
  'rotator_to_vector': {'in_rot': [0.0, 0.0, 90.0]}, 'make_rot_from_x': {'x': [1.0, 1.0, 0.0]},
  'make_transform': {'location': [1.0, 2.0, 3.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 2.0, 3.0]},
  'compose_transforms': {'a': {'location': [1.0, 0.0, 0.0], 'rotation': [0.0, 0.0, 0.0], 'scale': [1.0, 1.0, 1.0]}, 'b': {'location': [0.0, 0.0, 5.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [2.0, 2.0, 2.0]}},
  'transform_location': {'t': {'location': [0.0, 0.0, 5.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 1.0, 1.0]}, 'location': [1.0, 0.0, 0.0]},
  'inverse_transform_location': {'t': {'location': [0.0, 0.0, 5.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 1.0, 1.0]}, 'location': [1.0, 0.0, 5.0]},
  'transform_direction': {'t': {'location': [9.0, 9.0, 9.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 1.0, 1.0]}, 'direction': [0.0, 1.0, 0.0]},
  'make_color': {'r': 1.0, 'g': 0.5, 'b': 0.0, 'a': 1.0}, 'color_lerp': {'a': [0.0, 0.0, 0.0, 1.0], 'b': [1.0, 1.0, 1.0, 1.0], 'alpha': 0.5},
  'hex_to_color': {'hex': '#FF8000FF'}, 'color_to_hex': {'in_color': [1.0, 0.0, 0.0, 1.0]},
  'float_to_string': {'in_float': 3.14159, 'decimals': 2}, 'int_to_string': {'in_int': 42}, 'bool_to_string': {'in_bool': true},
  'vector_to_string': {'in_vec': [1.0, 2.0, 3.0]}, 'rotator_to_string': {'in_rot': [10.0, 20.0, 30.0]},
  'string_to_float': {'in_string': '2.5'}, 'string_to_int': {'in_string': '7'}, 'append': {'a': 'FPS: ', 'b': '60'},
  'append_3': {'a': 'a', 'b': 'b', 'c': 'c'}, 'format_string': {'format': '{0} of {1} ({2})', 'arg_0': '1', 'arg_1': '3'},
  'string_length': {'s': 'lumina'}, 'string_equal': {'a': 'Lumina', 'b': 'lumina', 'case_sensitive': false},
  'string_contains': {'search_in': 'Hello World', 'substring': 'world', 'use_case': false},
  'string_replace': {'source_string': 'a-b-c', 'from': '-', 'to': '+'}, 'string_to_upper': {'s': 'abc'}, 'string_to_lower': {'s': 'ABC'},
  'string_substring': {'s': 'lumina', 'start_index': 2, 'length': 3}, 'string_split': {'s': 'a b c', 'separator': ' '},
  'string_is_empty': {'s': ''}, 'string_trim': {'s': '  x '}, 'select_string': {'a': 'A', 'b': 'B', 'pick_a': false},
  'select_bool': {'a': true, 'b': false, 'pick_a': false}, 'select_object': {'pick_a': true},
  'array_length': {'target_array': [1, 2, 3]}, 'array_get': {'target_array': ['x', 'y'], 'index': 1, 'type': 'string'},
  'array_last_index': {'target_array': [1, 2, 3]}, 'array_is_empty': {'target_array': []},
  'array_contains': {'target_array': ['x', 'y'], 'item_to_find': 'y', 'type': 'string'},
  'array_find': {'target_array': ['x', 'y'], 'item_to_find': 'y', 'type': 'string'},
  'array_first': {'target_array': ['x', 'y'], 'type': 'string'}, 'array_last': {'target_array': ['x', 'y'], 'type': 'string'},
  'make_array': {'count': 2, 'type': 'integer', 'item_0': 7, 'item_1': 9},
  'array_filter_by_class': {'target_array': [], 'class': 'Actor:LuminaActor'},
  'break_transform': {'in_transform': {'location': [1.0, 2.0, 3.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 2.0, 3.0]}},
  'break_color': {'in_color': [0.1, 0.2, 0.3, 0.4]},
  'make_hit_result': {'blocking_hit': true, 'location': [1.0, 2.0, 3.0], 'distance': 42.0},
  'break_hit_result': {'hit': {'blockingHit': true, 'location': [1.0, 2.0, 3.0], 'impactPoint': [1.0, 2.0, 2.5], 'impactNormal': [0.0, 0.0, 1.0], 'distance': 42.0}},
};

LuminaBlueprintDocument pureNodesBlueprint() {
  _wires = 0;
  final nodes = <LuminaBlueprintNode>[LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin')];
  final wires = <LuminaBlueprintWire>[];
  var from = ('begin', 'exec_out');
  for (final entry in pureNodeLiterals.entries) {
    final id = entry.key;
    final spec = LuminaBlueprintNodeLibrary.spec(id)!;
    final node = LuminaBlueprintNodeLibrary.place(id, nodeId: 'n_$id', literals: entry.value);
    final out = node.outputs.first;
    nodes.add(node);
    // The first output, converted to a string, printed.
    final (converter, inPin) = switch (out.type) {
      LuminaPinType.float => ('float_to_string', 'in_float'),
      LuminaPinType.integer => ('int_to_string', 'in_int'),
      LuminaPinType.boolean => ('bool_to_string', 'in_bool'),
      LuminaPinType.vector => ('vector_to_string', 'in_vec'),
      LuminaPinType.rotator => ('rotator_to_string', 'in_rot'),
      LuminaPinType.color => ('color_to_hex', 'in_color'),
      LuminaPinType.array => ('array_length', 'target_array'),
      LuminaPinType.transform => ('break_transform', 'in_transform'),
      LuminaPinType.hitResult => ('break_hit_result', 'hit'),
      LuminaPinType.string => (null, null),
      _ => ('is_valid', 'input_object'),
    };
    var source = ('n_$id', out.id);
    if (converter != null) {
      nodes.add(LuminaBlueprintNodeLibrary.place(converter, nodeId: 'c_$id'));
      wires.add(_w(source.$1, source.$2, 'c_$id', inPin!));
      final converted = LuminaBlueprintNodeLibrary.spec(converter)!.outputs.first;
      source = ('c_$id', converted.id);
      // Two-step conversions: a length or a struct field, then to string.
      final (second, secondPin) = switch (converted.type) {
        LuminaPinType.integer => ('int_to_string', 'in_int'),
        LuminaPinType.boolean => ('bool_to_string', 'in_bool'),
        LuminaPinType.vector => ('vector_to_string', 'in_vec'),
        _ => (null, null),
      };
      if (second != null) {
        nodes.add(LuminaBlueprintNodeLibrary.place(second, nodeId: 's_$id'));
        wires.add(_w(source.$1, source.$2, 's_$id', secondPin!));
        source = ('s_$id', 'return_value');
      }
    }
    nodes.add(LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'p_$id'));
    wires.add(_w(source.$1, source.$2, 'p_$id', 'in_string'));
    wires.add(_w(from.$1, from.$2, 'p_$id', 'exec_in'));
    from = ('p_$id', 'exec_out');
    assert(spec.kind == LuminaBlueprintNodeKind.pure, id);
  }
  return LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: nodes, wires: wires));
}
