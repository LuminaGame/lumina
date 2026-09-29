import 'package:lumina/lumina.dart';

/// Reusable graphs parity fixtures: the enum and interface assets
/// BP_ReusableGraphs uses, and the Blueprint itself — a custom event with a
/// parameter, a function with a local variable and a pure function, a macro,
/// an event dispatcher bound to its own custom event, an interface it
/// implements and messages itself with, Switch on Enum and the enum
/// conversions, timers by event / function name / next tick, and a
/// Timeline — so the VM and the generated Dart are compared trace for trace.
const LuminaBlueprintEnumDocument reusableDoorState =
    LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']);

const LuminaBlueprintInterfaceDocument reusableInteractable = LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable', functions: [
  LuminaBlueprintFunctionSignature(name: 'Interact', inputs: [LuminaBlueprintVariable(name: 'Instigator', typeName: 'Actor')]),
  LuminaBlueprintFunctionSignature(name: 'GetPrompt', outputs: [LuminaBlueprintVariable(name: 'Prompt', typeName: 'String', defaultValue: '')]),
]);

int _wires = 0;
LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: 'w${_wires++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

LuminaBlueprintDocument reusableGraphsBlueprint() {
  _wires = 0;
  final doc = LuminaBlueprintDocument(
    variables: [
      const LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 100.0),
      const LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0),
      const LuminaBlueprintVariable(name: 'State', typeName: 'Enum:E_DoorState', defaultValue: 'Closed'),
      const LuminaBlueprintVariable(name: 'Pulse', typeName: 'TimerHandle'),
    ],
    dispatchers: [
      LuminaBlueprintDispatcher(name: 'OnScored', parameters: [const LuminaBlueprintVariable(name: 'Points', typeName: 'Int', defaultValue: 0)]),
    ],
    interfaces: ['BPI_Interactable'],
  );
  // Function AddHealth(Amount) → NewHealth, with local Sum.
  final addHealth = LuminaBlueprintFunctionGraph(
    name: 'AddHealth',
    inputs: [const LuminaBlueprintVariable(name: 'Amount', typeName: 'Float', defaultValue: 0.0)],
    outputs: [const LuminaBlueprintVariable(name: 'NewHealth', typeName: 'Float', defaultValue: 0.0)],
    localVariables: [const LuminaBlueprintVariable(name: 'Sum', typeName: 'Float', defaultValue: 0.0)],
  );
  // Pure HealthPercent → Percent.
  final percent = LuminaBlueprintFunctionGraph(
      name: 'HealthPercent', pure: true, outputs: [const LuminaBlueprintVariable(name: 'Percent', typeName: 'Float', defaultValue: 0.0)]);
  // GetPrompt → Prompt implements the interface function with an output.
  final prompt = LuminaBlueprintFunctionGraph(
      name: 'GetPrompt', outputs: [const LuminaBlueprintVariable(name: 'Prompt', typeName: 'String', defaultValue: '')]);
  doc.functions.addAll([addHealth, percent, prompt]);
  // Macro ClampAndPrint(In, Value) → (Out, Clamped).
  final macro = LuminaBlueprintMacroGraph(
    name: 'ClampAndPrint',
    inputs: [const LuminaBlueprintVariable(name: 'In', typeName: 'Exec'), const LuminaBlueprintVariable(name: 'Value', typeName: 'Float', defaultValue: 0.0)],
    outputs: [const LuminaBlueprintVariable(name: 'Out', typeName: 'Exec'), const LuminaBlueprintVariable(name: 'Clamped', typeName: 'Float', defaultValue: 0.0)],
  );
  doc.macros.add(macro);
  const enums = [reusableDoorState];
  const interfaces = [reusableInteractable];

  final fc = LuminaBlueprintTypeContext.forFunction(doc, addHealth, className: 'bp_reusable_graphs', enums: enums, interfaces: interfaces);
  LuminaBlueprintNode f(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: fc);
  addHealth.graph.nodes.addAll([
    f('function_entry', 'entry'),
    f('function_result', 'result'),
    f(LuminaBlueprintNodeLibrary.variableGet, 'health', {'variable': 'Health'}),
    f('float_add', 'plus'),
    f('local_variable_set', 'set_sum', {'variable': 'Sum'}),
    f('local_variable_get', 'sum', {'variable': 'Sum'}),
    f(LuminaBlueprintNodeLibrary.variableSet, 'set_health', {'variable': 'Health'}),
    f('call_macro', 'clamp', {'macro': 'ClampAndPrint'}),
  ]);
  addHealth.graph.wires.addAll([
    _w('entry', 'exec_out', 'set_sum', 'exec_in'),
    _w('health', 'value', 'plus', 'a'),
    _w('entry', 'Amount', 'plus', 'b'),
    _w('plus', 'return_value', 'set_sum', 'value'),
    _w('set_sum', 'exec_out', 'set_health', 'exec_in'),
    _w('sum', 'value', 'set_health', 'value'),
    _w('set_health', 'exec_out', 'clamp', 'In'),
    _w('sum', 'value', 'clamp', 'Value'),
    _w('clamp', 'Out', 'result', 'exec_in'),
    _w('sum', 'value', 'result', 'NewHealth'),
  ]);
  final pc = LuminaBlueprintTypeContext.forFunction(doc, percent, className: 'bp_reusable_graphs', enums: enums, interfaces: interfaces);
  percent.graph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('function_entry', nodeId: 'pentry', context: pc),
    LuminaBlueprintNodeLibrary.place('function_result', nodeId: 'presult', context: pc),
    LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet, nodeId: 'h', literals: {'variable': 'Health'}, context: pc),
    LuminaBlueprintNodeLibrary.place('float_divide', nodeId: 'div', literals: {'b': 200.0}, context: pc),
  ]);
  percent.graph.wires.addAll([_w('h', 'value', 'div', 'a'), _w('div', 'return_value', 'presult', 'Percent')]);
  final gc = LuminaBlueprintTypeContext.forFunction(doc, prompt, className: 'bp_reusable_graphs', enums: enums, interfaces: interfaces);
  prompt.graph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('function_entry', nodeId: 'gentry', context: gc),
    LuminaBlueprintNodeLibrary.place('function_result', nodeId: 'gresult', literals: {'Prompt': 'Open'}, context: gc),
  ]);
  prompt.graph.wires.add(_w('gentry', 'exec_out', 'gresult', 'exec_in'));
  final mc = LuminaBlueprintTypeContext.forMacro(doc, macro, className: 'bp_reusable_graphs');
  macro.graph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('macro_input', nodeId: 'in', context: mc),
    LuminaBlueprintNodeLibrary.place('macro_output', nodeId: 'out', context: mc),
    LuminaBlueprintNodeLibrary.place('float_clamp', nodeId: 'clamp', literals: {'min': 0.0, 'max': 150.0}, context: mc),
    LuminaBlueprintNodeLibrary.place('float_to_string', nodeId: 'text', literals: {'decimals': 1}, context: mc),
    LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'say', context: mc),
  ]);
  macro.graph.wires.addAll([
    _w('in', 'In', 'say', 'exec_in'),
    _w('in', 'Value', 'clamp', 'value'),
    _w('clamp', 'return_value', 'text', 'in_float'),
    _w('text', 'return_value', 'say', 'in_string'),
    _w('say', 'exec_out', 'out', 'Out'),
    _w('clamp', 'return_value', 'out', 'Clamped'),
  ]);

  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_reusable_graphs', enums: enums, interfaces: interfaces);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  // Custom events must exist before the call nodes are placed (their pins come from the graph).
  doc.eventGraph.nodes.addAll([
    p('custom_event', 'scored', {'name': 'Scored', 'parameters': [{'name': 'Points', 'type': 'Int'}]}),
    p('custom_event', 'pulse', {'name': 'OnPulse'}),
    p('custom_event', 'next', {'name': 'NextTick'}),
    p('custom_event', 'named', {'name': 'Named'}),
  ]);
  final context2 = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_reusable_graphs', enums: enums, interfaces: interfaces);
  LuminaBlueprintNode q(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context2);
  doc.eventGraph.nodes.addAll([
    p('event_beginplay', 'begin'),
    p('sequence', 'seq')
      ..outputs.addAll(const [
        LuminaBlueprintPin(id: 'then_2', name: 'Then 2', type: LuminaPinType.exec, isOutput: true),
        LuminaBlueprintPin(id: 'then_3', name: 'Then 3', type: LuminaPinType.exec, isOutput: true),
      ]),
    // then_0: functions and the macro.
    q('call_function', 'add1', {'function': 'AddHealth', 'Amount': 30.0}),
    p('float_to_string', 'add1_text', {'decimals': 1}),
    p('print_string', 'say_add1'),
    q('call_function', 'add2', {'function': 'AddHealth', 'Amount': 50.0}),
    q('call_function_pure', 'pct', {'function': 'HealthPercent'}),
    p('float_to_string', 'pct_text', {'decimals': 2}),
    p('print_string', 'say_pct'),
    q('call_macro', 'mac', {'macro': 'ClampAndPrint', 'Value': 999.0}),
    p('float_to_string', 'mac_text', {'decimals': 0}),
    p('print_string', 'say_mac'),
    // then_1: dispatcher bound to Scored, called twice; a custom event called directly.
    q('bind_event_to_dispatcher', 'bind', {'dispatcher': 'OnScored'}),
    q('call_dispatcher', 'fire', {'dispatcher': 'OnScored', 'Points': 7}),
    q('call_custom_event', 'direct', {'event': 'Scored', 'Points': 3}),
    q('unbind_all_events', 'unbind', {'dispatcher': 'OnScored'}),
    q('call_dispatcher', 'fire2', {'dispatcher': 'OnScored', 'Points': 100}),
    // Scored(Points): Score += Points → print.
    p(LuminaBlueprintNodeLibrary.variableGet, 'score', {'variable': 'Score'}),
    p('int_add', 'score_add'),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_score', {'variable': 'Score'}),
    p('int_to_string', 'score_text'),
    p('append', 'score_line', {'a': 'score '}),
    p('print_string', 'say_score'),
    // then_2: interface on self, enums.
    q('interface_message', 'interact', {'interface': 'BPI_Interactable', 'function': 'Interact'}),
    q('interface_message', 'ask', {'interface': 'BPI_Interactable', 'function': 'GetPrompt'}),
    p('print_string', 'say_prompt'),
    q('implements_interface', 'impl', {'interface': 'BPI_Interactable'}),
    p('bool_to_string', 'impl_text'),
    p('print_string', 'say_impl'),
    q('event_interface_function', 'on_interact', {'interface': 'BPI_Interactable', 'function': 'Interact'}),
    p('get_display_name', 'who'),
    p('append', 'who_line', {'a': 'interact by '}),
    p('print_string', 'say_who'),
    q('enum_literal', 'opening', {'enum': 'E_DoorState', 'value': 'Opening'}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_state', {'variable': 'State'}),
    q('switch_on_enum', 'sw', {'enum': 'E_DoorState'}),
    p('print_string', 'say_closed', {'in_string': 'closed'}),
    p('print_string', 'say_opening', {'in_string': 'opening'}),
    q('enum_to_int', 'idx', {'enum': 'E_DoorState'}),
    p('int_to_string', 'idx_text'),
    p('print_string', 'say_idx'),
    q('int_to_enum', 'last', {'enum': 'E_DoorState', 'value': 9}),
    p('enum_to_string', 'last_text'),
    p('print_string', 'say_last'),
    q('get_enum_value_count', 'count', {'enum': 'E_DoorState'}),
    p('int_to_string', 'count_text'),
    p('print_string', 'say_count'),
    p('enum_equal', 'same'),
    p('bool_to_string', 'same_text'),
    p('print_string', 'say_same'),
    // then_3: timers and the timeline.
    q('set_timer_by_event', 'timer', {'time': 0.25, 'looping': true}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_pulse', {'variable': 'Pulse'}),
    q('set_timer_for_next_tick', 'next_timer'),
    q('set_timer_by_function_name', 'named_timer', {'function_name': 'Named', 'time': 0.1}),
    p('print_string', 'say_pulse', {'in_string': 'pulse'}),
    p('print_string', 'say_next', {'in_string': 'next tick'}),
    p('print_string', 'say_named', {'in_string': 'named'}),
    q('timeline', 'swing', {
      'name': 'Swing',
      'length': 0.5,
      'loop': false,
      'auto_play': false,
      'tracks': [
        {
          'name': 'Angle',
          'type': 'float',
          'keys': [
            {'time': 0.0, 'value': 0.0, 'interp': 'linear'},
            {'time': 0.5, 'value': 90.0, 'interp': 'linear'},
          ],
        },
        {
          'name': 'Tint',
          'type': 'color',
          'keys': [
            {'time': 0.0, 'value': [1.0, 0.0, 0.0, 1.0], 'interp': 'constant'},
            {'time': 0.25, 'value': [0.0, 1.0, 0.0, 1.0], 'interp': 'constant'},
          ],
        },
      ],
    }),
    p('float_to_string', 'angle_text', {'decimals': 1}),
    p('append', 'angle_line', {'a': 'angle '}),
    p('print_string', 'say_angle'),
    p('enum_to_string', 'dir_text'),
    p('append', 'done_line', {'a': 'finished '}),
    p('print_string', 'say_done'),
    // Tick: after 1.6 s pause the pulse timer, print its state.
    p('event_tick', 'tick'),
    p('do_n', 'once', {'n': 1}),
    p('get_game_time_in_seconds', 'time'),
    p('float_greater', 'late', {'b': 1.6}),
    p('branch', 'if_late'),
    p('do_once', 'pause_once'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'pulse_var', {'variable': 'Pulse'}),
    q('pause_timer', 'pause'),
    q('is_timer_paused', 'paused'),
    p('bool_to_string', 'paused_text'),
    p('print_string', 'say_paused'),
    q('get_timer_remaining_time', 'left'),
    p('float_to_string', 'left_text', {'decimals': 2}),
    p('print_string', 'say_left'),
  ]);
  doc.eventGraph.wires.addAll([
    _w('begin', 'exec_out', 'seq', 'exec_in'),
    // then_0
    _w('seq', 'then_0', 'add1', 'exec_in'),
    _w('add1', 'exec_out', 'say_add1', 'exec_in'),
    _w('add1', 'NewHealth', 'add1_text', 'in_float'),
    _w('add1_text', 'return_value', 'say_add1', 'in_string'),
    _w('say_add1', 'exec_out', 'add2', 'exec_in'),
    _w('add2', 'exec_out', 'say_pct', 'exec_in'),
    _w('pct', 'Percent', 'pct_text', 'in_float'),
    _w('pct_text', 'return_value', 'say_pct', 'in_string'),
    _w('say_pct', 'exec_out', 'mac', 'In'),
    _w('mac', 'Out', 'say_mac', 'exec_in'),
    _w('mac', 'Clamped', 'mac_text', 'in_float'),
    _w('mac_text', 'return_value', 'say_mac', 'in_string'),
    // then_1
    _w('seq', 'then_1', 'bind', 'exec_in'),
    _w('scored', 'delegate', 'bind', 'event'),
    _w('bind', 'exec_out', 'fire', 'exec_in'),
    _w('fire', 'exec_out', 'direct', 'exec_in'),
    _w('direct', 'exec_out', 'unbind', 'exec_in'),
    _w('unbind', 'exec_out', 'fire2', 'exec_in'),
    _w('scored', 'exec_out', 'set_score', 'exec_in'),
    _w('score', 'value', 'score_add', 'a'),
    _w('scored', 'Points', 'score_add', 'b'),
    _w('score_add', 'return_value', 'set_score', 'value'),
    _w('set_score', 'exec_out', 'say_score', 'exec_in'),
    _w('set_score', 'value', 'score_text', 'in_int'),
    _w('score_text', 'return_value', 'score_line', 'b'),
    _w('score_line', 'return_value', 'say_score', 'in_string'),
    // then_2
    _w('seq', 'then_2', 'interact', 'exec_in'),
    _w('interact', 'exec_out', 'ask', 'exec_in'),
    _w('ask', 'exec_out', 'say_prompt', 'exec_in'),
    _w('ask', 'Prompt', 'say_prompt', 'in_string'),
    _w('say_prompt', 'exec_out', 'say_impl', 'exec_in'),
    _w('impl', 'return_value', 'impl_text', 'in_bool'),
    _w('impl_text', 'return_value', 'say_impl', 'in_string'),
    _w('on_interact', 'exec_out', 'say_who', 'exec_in'),
    _w('on_interact', 'Instigator', 'who', 'object'),
    _w('who', 'return_value', 'who_line', 'b'),
    _w('who_line', 'return_value', 'say_who', 'in_string'),
    _w('say_impl', 'exec_out', 'set_state', 'exec_in'),
    _w('opening', 'return_value', 'set_state', 'value'),
    _w('set_state', 'exec_out', 'sw', 'exec_in'),
    _w('set_state', 'value', 'sw', 'selection'),
    _w('sw', 'case_0', 'say_closed', 'exec_in'),
    _w('sw', 'case_1', 'say_opening', 'exec_in'),
    _w('say_opening', 'exec_out', 'say_idx', 'exec_in'),
    _w('set_state', 'value', 'idx', 'value'),
    _w('idx', 'return_value', 'idx_text', 'in_int'),
    _w('idx_text', 'return_value', 'say_idx', 'in_string'),
    _w('say_idx', 'exec_out', 'say_last', 'exec_in'),
    _w('last', 'return_value', 'last_text', 'value'),
    _w('last_text', 'return_value', 'say_last', 'in_string'),
    _w('say_last', 'exec_out', 'say_count', 'exec_in'),
    _w('count', 'return_value', 'count_text', 'in_int'),
    _w('count_text', 'return_value', 'say_count', 'in_string'),
    _w('say_count', 'exec_out', 'say_same', 'exec_in'),
    _w('set_state', 'value', 'same', 'a'),
    _w('opening', 'return_value', 'same', 'b'),
    _w('same', 'return_value', 'same_text', 'in_bool'),
    _w('same_text', 'return_value', 'say_same', 'in_string'),
    // then_3
    _w('seq', 'then_3', 'timer', 'exec_in'),
    _w('pulse', 'delegate', 'timer', 'event'),
    _w('timer', 'exec_out', 'set_pulse', 'exec_in'),
    _w('timer', 'return_value', 'set_pulse', 'value'),
    _w('set_pulse', 'exec_out', 'next_timer', 'exec_in'),
    _w('next', 'delegate', 'next_timer', 'event'),
    _w('next_timer', 'exec_out', 'named_timer', 'exec_in'),
    _w('named_timer', 'exec_out', 'swing', 'play'),
    _w('pulse', 'exec_out', 'say_pulse', 'exec_in'),
    _w('next', 'exec_out', 'say_next', 'exec_in'),
    _w('named', 'exec_out', 'say_named', 'exec_in'),
    _w('swing', 'update', 'say_angle', 'exec_in'),
    _w('swing', 'Angle', 'angle_text', 'in_float'),
    _w('angle_text', 'return_value', 'angle_line', 'b'),
    _w('angle_line', 'return_value', 'say_angle', 'in_string'),
    _w('swing', 'finished', 'say_done', 'exec_in'),
    _w('swing', 'direction', 'dir_text', 'value'),
    _w('dir_text', 'return_value', 'done_line', 'b'),
    _w('done_line', 'return_value', 'say_done', 'in_string'),
    // Tick
    _w('tick', 'exec_tick_out', 'if_late', 'exec_in'),
    _w('time', 'return_value', 'late', 'a'),
    _w('late', 'return_value', 'if_late', 'condition'),
    _w('if_late', 'true_out', 'pause_once', 'exec_in'),
    _w('pause_once', 'completed', 'pause', 'exec_in'),
    _w('pulse_var', 'value', 'pause', 'handle'),
    _w('pause', 'exec_out', 'say_paused', 'exec_in'),
    _w('pulse_var', 'value', 'paused', 'handle'),
    _w('paused', 'return_value', 'paused_text', 'in_bool'),
    _w('paused_text', 'return_value', 'say_paused', 'in_string'),
    _w('say_paused', 'exec_out', 'say_left', 'exec_in'),
    _w('pulse_var', 'value', 'left', 'handle'),
    _w('left', 'return_value', 'left_text', 'in_float'),
    _w('left_text', 'return_value', 'say_left', 'in_string'),
  ]);
  doc.eventGraph.nodes.removeWhere((n) => n.id == 'once');
  return doc;
}
