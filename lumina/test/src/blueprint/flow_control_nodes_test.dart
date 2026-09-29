import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The flow-control macros in the VM — DoOnce, FlipFlop, Gate,
/// DoN, ForLoop, ForEachLoop, WhileLoop (capped), the switches, MultiGate
/// and Retriggerable Delay.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals, LuminaBlueprintTypeContext? context]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context ?? const LuminaBlueprintTypeContext());

  ({LuminaBlueprintInstance actor, List<LuminaBlueprintTraceEvent> trace, LuminaWorld world}) run(LuminaBlueprintDocument doc) {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Flow');
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintInstance;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    return (actor: actor, trace: trace, world: w);
  }

  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  test('DoOnce fires once until Reset; FlipFlop alternates A, B, A', () {
    // Tick → DoOnce → Print "once"; Tick → FlipFlop → Print "A" / "B"; the 4th tick resets DoOnce.
    const variables = [LuminaBlueprintVariable(name: 'Ticks', typeName: 'Int', defaultValue: 0)];
    const context = LuminaBlueprintTypeContext(variables: variables);
    final r = run(LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_tick', 'tick'),
      place('sequence', 'seq'),
      place('do_once', 'once'),
      place('print_string', 'p_once', {'in_string': 'once'}),
      place('flip_flop', 'ff'),
      place('print_string', 'p_a', {'in_string': 'A'}),
      place('print_string', 'p_b', {'in_string': 'B'}),
      place(LuminaBlueprintNodeLibrary.variableGet, 'ticks', {'variable': 'Ticks'}, context),
      place('int_increment', 'inc'),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_ticks', {'variable': 'Ticks'}, context),
      place('int_equal', 'is_fourth', {'b': 4}),
      place('branch', 'if_fourth'),
    ], wires: [
      wire('tick', 'exec_tick_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'once', 'exec_in'),
      wire('once', 'completed', 'p_once', 'exec_in'),
      wire('seq', 'then_1', 'ff', 'exec_in'),
      wire('ff', 'a', 'p_a', 'exec_in'),
      wire('ff', 'b', 'p_b', 'exec_in'),
      wire('p_a', 'exec_out', 'set_ticks', 'exec_in'),
      wire('p_b', 'exec_out', 'set_ticks', 'exec_in'),
      wire('ticks', 'value', 'inc', 'a'),
      wire('inc', 'return_value', 'set_ticks', 'value'),
      wire('set_ticks', 'exec_out', 'if_fourth', 'exec_in'),
      wire('set_ticks', 'value', 'is_fourth', 'a'),
      wire('is_fourth', 'return_value', 'if_fourth', 'condition'),
      wire('if_fourth', 'true_out', 'once', 'reset'),
    ])));
    for (var i = 0; i < 5; i++) {
      r.world.tick(1 / 60);
    }
    expect(printed(r.trace), ['once', 'A', 'B', 'A', 'B', 'once', 'A']);
    expect(r.trace.where((t) => t.registryId == 'flip_flop').map((t) => t.values['is_a']), [true, false, true, false, true]);
    r.world.cleanup();
  });

  test('Gate blocks when closed and passes after Open; Toggle flips it', () {
    final r = run(LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('sequence', 'seq'),
      place('gate', 'gate', {'start_closed': true}),
      place('print_string', 'through', {'in_string': 'through'}),
      place('event_tick', 'tick'),
      place('sequence', 'tick_seq'),
    ], wires: [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'gate', 'exec_in'), // closed: blocked
      wire('seq', 'then_1', 'gate', 'open'),
      wire('gate', 'exit', 'through', 'exec_in'),
      wire('tick', 'exec_tick_out', 'tick_seq', 'exec_in'),
      wire('tick_seq', 'then_0', 'gate', 'exec_in'),
      wire('tick_seq', 'then_1', 'gate', 'toggle'),
    ])));
    expect(printed(r.trace), isEmpty, reason: 'closed at BeginPlay');
    r.world.tick(1 / 60); // open → through, then toggled closed
    r.world.tick(1 / 60); // closed → blocked, toggled open
    r.world.tick(1 / 60); // open → through
    expect(printed(r.trace), ['through', 'through']);
    r.world.cleanup();
  });

  test('DoN passes N times then blocks; ForLoop 0..4 runs the body five times then Completed', () {
    final r = run(LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('for_loop', 'loop', {'first_index': 0, 'last_index': 4}),
      place('int_to_string', 'idx_text'),
      place('print_string', 'body'),
      place('print_string', 'done', {'in_string': 'done'}),
      place('event_tick', 'tick'),
      place('do_n', 'do_n', {'n': 3}),
      place('int_to_string', 'count_text'),
      place('print_string', 'counted'),
    ], wires: [
      wire('begin', 'exec_out', 'loop', 'exec_in'),
      wire('loop', 'loop_body', 'body', 'exec_in'),
      wire('loop', 'index', 'idx_text', 'in_int'),
      wire('idx_text', 'return_value', 'body', 'in_string'),
      wire('loop', 'completed', 'done', 'exec_in'),
      wire('tick', 'exec_tick_out', 'do_n', 'exec_in'),
      wire('do_n', 'exit', 'counted', 'exec_in'),
      wire('do_n', 'counter', 'count_text', 'in_int'),
      wire('count_text', 'return_value', 'counted', 'in_string'),
    ])));
    expect(printed(r.trace), ['0', '1', '2', '3', '4', 'done']);
    for (var i = 0; i < 10; i++) {
      r.world.tick(1 / 60);
    }
    expect(printed(r.trace).skip(6), ['1', '2', '3'], reason: 'three of ten ticks pass DoN(3)');
    expect(r.actor.blueprintFlowState['do_n'], 3);
    r.world.cleanup();
  });

  test('ForLoopWithBreak stops at Break; ForEachLoop yields each element and index', () {
    const variables = [LuminaBlueprintVariable(name: 'Names', typeName: 'Array:String', defaultValue: ['a', 'b', 'c'])];
    const context = LuminaBlueprintTypeContext(variables: variables);
    final r = run(LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('sequence', 'seq'),
      place('for_loop_with_break', 'loop', {'first_index': 0, 'last_index': 9}),
      place('int_equal', 'is_two', {'b': 2}),
      place('branch', 'if_two'),
      place('int_to_string', 'idx_text'),
      place('print_string', 'body'),
      place('print_string', 'done', {'in_string': 'broke'}),
      place(LuminaBlueprintNodeLibrary.variableGet, 'names', {'variable': 'Names'}, context),
      place('for_each_loop', 'each', {'type': 'string'}),
      place('int_to_string', 'each_idx'),
      place('append_3', 'label'),
      place('print_string', 'each_body'),
      place('print_string', 'each_done', {'in_string': 'each done'}),
    ], wires: [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'loop', 'exec_in'),
      wire('loop', 'loop_body', 'if_two', 'exec_in'),
      wire('loop', 'index', 'is_two', 'a'),
      wire('is_two', 'return_value', 'if_two', 'condition'),
      wire('if_two', 'true_out', 'loop', 'break'),
      wire('if_two', 'false_out', 'body', 'exec_in'),
      wire('loop', 'index', 'idx_text', 'in_int'),
      wire('idx_text', 'return_value', 'body', 'in_string'),
      wire('loop', 'completed', 'done', 'exec_in'),
      wire('seq', 'then_1', 'each', 'exec_in'),
      wire('names', 'value', 'each', 'array'),
      wire('each', 'loop_body', 'each_body', 'exec_in'),
      wire('each', 'array_index', 'each_idx', 'in_int'),
      wire('each_idx', 'return_value', 'label', 'a'),
      wire('each', 'array_element', 'label', 'c'),
      wire('label', 'return_value', 'each_body', 'in_string'),
      wire('each', 'completed', 'each_done', 'exec_in'),
    ])));
    expect(printed(r.trace), ['0', '1', 'broke', '0a', '1b', '2c', 'each done']);
    expect(r.actor.hostPins['each']!.outputs.firstWhere((p) => p.id == 'array_element').type, LuminaPinType.string,
        reason: 'the type literal types the element pin');
    r.world.cleanup();
  });

  test('WhileLoop with an always-true condition stops at the cap with a logged warning; a counting loop ends', () {
    const variables = [LuminaBlueprintVariable(name: 'N', typeName: 'Int', defaultValue: 0)];
    const context = LuminaBlueprintTypeContext(variables: variables);
    final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('sequence', 'seq'),
      place('while_loop', 'forever', {'condition': true}),
      place('print_string', 'capped', {'in_string': 'capped'}),
      place('while_loop', 'count', {}),
      place(LuminaBlueprintNodeLibrary.variableGet, 'n', {'variable': 'N'}, context),
      place('int_less', 'lt', {'b': 3}),
      place('int_increment', 'inc'),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_n', {'variable': 'N'}, context),
      place('print_string', 'counted', {'in_string': 'counted'}),
    ], wires: [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'forever', 'exec_in'),
      wire('forever', 'completed', 'capped', 'exec_in'),
      wire('seq', 'then_1', 'count', 'exec_in'),
      wire('n', 'value', 'lt', 'a'),
      wire('lt', 'return_value', 'count', 'condition'),
      wire('count', 'loop_body', 'set_n', 'exec_in'),
      wire('n', 'value', 'inc', 'a'),
      wire('inc', 'return_value', 'set_n', 'value'),
      wire('count', 'completed', 'counted', 'exec_in'),
    ]));
    final warnings = validateBlueprint(doc).where((d) => !d.isError).toList();
    expect(warnings.single.nodeId, 'forever');
    expect(warnings.single.message, contains('always true'));
    final r = run(doc);
    final cap = r.trace.where((t) => t.nodeId == 'forever' && t.values['capped'] == true).single;
    expect(cap.values['iterations'], LuminaBlueprintNodeLibrary.whileLoopCap);
    expect(printed(r.trace), ['capped', 'counted']);
    expect(r.actor.variables['N'], 3);
    expect(r.actor.lastError, isNull, reason: 'the cap is a warning, not an aborted run');
    r.world.cleanup();
  });

  test('Switch on String / Int take their case or Default; Switch on Bool; MultiGate cycles and loops', () {
    const variables = [LuminaBlueprintVariable(name: 'Key', typeName: 'String', defaultValue: 'b')];
    const context = LuminaBlueprintTypeContext(variables: variables);
    final r = run(LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('sequence', 'seq'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'key', {'variable': 'Key'}, context),
      place('switch_on_string', 'sw', {'cases': ['a', 'b']}),
      place('print_string', 'sa', {'in_string': 'case a'}),
      place('print_string', 'sb', {'in_string': 'case b'}),
      place('print_string', 'sd', {'in_string': 'default'}),
      place('switch_on_string', 'sw2', {'cases': ['a', 'b'], 'selection': 'z'}),
      place('print_string', 'sd2', {'in_string': 'default z'}),
      place('switch_on_int', 'swi', {'cases': [1, 2, 3], 'selection': 2}),
      place('print_string', 'i2', {'in_string': 'two'}),
      place('print_string', 'id', {'in_string': 'int default'}),
      place('switch_on_bool', 'swb', {'selection': true}),
      place('print_string', 'bt', {'in_string': 'yes'}),
      place('event_tick', 'tick'),
      place('multi_gate', 'mg', {'count': 3, 'loop': true}),
      place('print_string', 'm0', {'in_string': 'out 0'}),
      place('print_string', 'm1', {'in_string': 'out 1'}),
      place('print_string', 'm2', {'in_string': 'out 2'}),
    ], wires: [
      wire('begin', 'exec_out', 'seq', 'exec_in'),
      wire('seq', 'then_0', 'sw', 'exec_in'),
      wire('key', 'value', 'sw', 'selection'),
      wire('sw', 'case_0', 'sa', 'exec_in'),
      wire('sw', 'case_1', 'sb', 'exec_in'),
      wire('sw', 'default', 'sd', 'exec_in'),
      wire('sb', 'exec_out', 'sw2', 'exec_in'),
      wire('sw2', 'default', 'sd2', 'exec_in'),
      wire('sd2', 'exec_out', 'swi', 'exec_in'),
      wire('swi', 'case_1', 'i2', 'exec_in'),
      wire('swi', 'default', 'id', 'exec_in'),
      wire('i2', 'exec_out', 'swb', 'exec_in'),
      wire('swb', 'true_out', 'bt', 'exec_in'),
      wire('tick', 'exec_tick_out', 'mg', 'exec_in'),
      wire('mg', 'out_0', 'm0', 'exec_in'),
      wire('mg', 'out_1', 'm1', 'exec_in'),
      wire('mg', 'out_2', 'm2', 'exec_in'),
    ])));
    expect(r.actor.hostPins['sw']!.outputs.map((p) => p.id), ['case_0', 'case_1', 'default']);
    expect(r.actor.hostPins['sw']!.outputs.first.name, 'a');
    expect(printed(r.trace), ['case b', 'default z', 'two', 'yes']);
    for (var i = 0; i < 4; i++) {
      r.world.tick(1 / 60);
    }
    expect(printed(r.trace).skip(4), ['out 0', 'out 1', 'out 2', 'out 0'], reason: 'Loop wraps round');
    r.world.cleanup();
  });

  test('Retriggerable Delay restarts its countdown on every trigger; flow state resets at BeginPlay', () {
    final r = run(LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_tick', 'tick'),
      place('do_n', 'twice', {'n': 2}),
      place('retriggerable_delay', 'wait', {'duration': 0.5}),
      place('print_string', 'late', {'in_string': 'late'}),
    ], wires: [
      wire('tick', 'exec_tick_out', 'twice', 'exec_in'),
      wire('twice', 'exit', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'late', 'exec_in'),
    ])));
    final firedAt = <int>[];
    for (var i = 1; i <= 90; i++) {
      final before = printed(r.trace).length;
      r.world.tick(1 / 60);
      if (printed(r.trace).length > before) firedAt.add(i);
    }
    // Triggered on ticks 1 and 2 (DoN 2): the second trigger restarts the
    // 0.5 s, so it fires 30 ticks after tick 2, once.
    expect(firedAt, [32]);
    expect(r.actor.blueprintFlowState['twice'], 2);
    r.actor.onBeginPlay();
    expect(r.actor.blueprintFlowState, isEmpty, reason: 'PIE restart starts over');
    r.world.cleanup();
  });
}
