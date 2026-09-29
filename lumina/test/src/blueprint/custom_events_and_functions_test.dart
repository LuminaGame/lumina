import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Custom events with parameters, user functions with inputs,
/// outputs and local variables (pure ones too), macros expanded into the
/// caller, and the `.lmas` round trip of all of them.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  LuminaWorld world() => LuminaWorld(worldType: LuminaWorldType.game);

  ({LuminaBlueprintActor actor, List<LuminaBlueprintTraceEvent> trace}) play(LuminaWorld w, LuminaBlueprintDocument doc, String name) {
    final cls = LuminaBlueprintClass.fromDocument(doc, name: name);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    return (actor: actor, trace: trace);
  }

  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  test('a custom event OnScored(Points) round-trips and Call Custom Event runs its chain with Points 10', () {
    final doc = LuminaBlueprintDocument(variables: [const LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0)]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Scorer');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final scored = p('custom_event', 'scored', {
      'name': 'OnScored',
      'parameters': [{'name': 'Points', 'type': 'Int'}],
    });
    expect(scored.title, 'OnScored');
    expect(scored.pin('Points')!.type, LuminaPinType.integer);
    expect(scored.pin('delegate')!.type, LuminaPinType.delegate);
    doc.eventGraph.nodes.add(scored);
    // The call node's pins come from the event, once the graph knows it.
    final callContext = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Scorer');
    expect(callContext.customEvent('OnScored')!.parameters.single.name, 'Points');
    final call = LuminaBlueprintNodeLibrary.place('call_custom_event', nodeId: 'call', literals: {'event': 'OnScored', 'Points': 10}, context: callContext);
    expect(call.title, 'OnScored');
    expect(call.pin('Points')!.type, LuminaPinType.integer);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      call,
      p(LuminaBlueprintNodeLibrary.variableGet, 'score', {'variable': 'Score'}),
      p('int_add', 'add'),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_score', {'variable': 'Score'}),
      p('int_to_string', 'text'),
      p('print_string', 'say'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'call', 'exec_in'),
      wire('scored', 'exec_out', 'set_score', 'exec_in'),
      wire('score', 'value', 'add', 'a'),
      wire('scored', 'Points', 'add', 'b'),
      wire('add', 'return_value', 'set_score', 'value'),
      wire('set_score', 'exec_out', 'say', 'exec_in'),
      wire('set_score', 'value', 'text', 'in_int'),
      wire('text', 'return_value', 'say', 'in_string'),
    ]);
    // Round trip through JSON keeps the event, its parameters and the delegate pin.
    final json = jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>;
    final back = LuminaBlueprintDocument.fromJson(json);
    final event = back.eventGraph.node('scored')!;
    expect(event.literals['name'], 'OnScored');
    expect(event.pin('Points')!.type, LuminaPinType.integer);
    expect(event.pin('delegate')!.toJson()['type'], 'delegate');
    final run = play(world(), back, 'BP_Scorer');
    expect(printed(run.trace), ['10']);
    expect(run.actor.variables['Score'], 10);
    expect(run.trace.firstWhere((t) => t.registryId == 'call_custom_event').values['Points'], 10);
    // The event chain traces under the custom event's own node.
    expect(run.trace.firstWhere((t) => t.nodeId == 'set_score').eventNodeId, 'scored');
    // A second call through the runtime's callable surface.
    run.actor.callBlueprint('OnScored', {'Points': 5});
    expect(run.actor.variables['Score'], 15);
  });

  test('a function with a local variable mutates Health and returns 110 then 120; a pure function feeds a data chain', () {
    final doc = LuminaBlueprintDocument(variables: [
      const LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 100.0),
      const LuminaBlueprintVariable(name: 'MaxHealth', typeName: 'Float', defaultValue: 200.0),
    ]);
    final addHealth = LuminaBlueprintFunctionGraph(
      name: 'AddHealth',
      inputs: [const LuminaBlueprintVariable(name: 'Amount', typeName: 'Float', defaultValue: 0.0)],
      outputs: [const LuminaBlueprintVariable(name: 'NewHealth', typeName: 'Float', defaultValue: 0.0)],
      localVariables: [const LuminaBlueprintVariable(name: 'Sum', typeName: 'Float', defaultValue: 0.0)],
    );
    final percent = LuminaBlueprintFunctionGraph(
      name: 'HealthPercent',
      pure: true,
      outputs: [const LuminaBlueprintVariable(name: 'Percent', typeName: 'Float', defaultValue: 0.0)],
    );
    doc.functions.addAll([addHealth, percent]);
    // AddHealth: Entry → Sum = Health + Amount → Health = Sum → Result(NewHealth = Sum).
    final fc = LuminaBlueprintTypeContext.forFunction(doc, addHealth, className: 'BP_Health');
    LuminaBlueprintNode f(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: fc);
    final entry = f('function_entry', 'entry');
    expect(entry.pin('Amount')!.type, LuminaPinType.float);
    final result = f('function_result', 'result');
    expect(result.pin('NewHealth')!.type, LuminaPinType.float);
    addHealth.graph.nodes.addAll([
      entry,
      result,
      f(LuminaBlueprintNodeLibrary.variableGet, 'health', {'variable': 'Health'}),
      f('float_add', 'plus'),
      f('local_variable_set', 'set_sum', {'variable': 'Sum'}),
      f('local_variable_get', 'sum', {'variable': 'Sum'}),
      f(LuminaBlueprintNodeLibrary.variableSet, 'set_health', {'variable': 'Health'}),
    ]);
    expect(addHealth.graph.node('set_sum')!.pin('value')!.type, LuminaPinType.float);
    addHealth.graph.wires.addAll([
      wire('entry', 'exec_out', 'set_sum', 'exec_in'),
      wire('health', 'value', 'plus', 'a'),
      wire('entry', 'Amount', 'plus', 'b'),
      wire('plus', 'return_value', 'set_sum', 'value'),
      wire('set_sum', 'exec_out', 'set_health', 'exec_in'),
      wire('sum', 'value', 'set_health', 'value'),
      wire('set_health', 'exec_out', 'result', 'exec_in'),
      wire('sum', 'value', 'result', 'NewHealth'),
    ]);
    // HealthPercent (pure): Result(Percent = Health / MaxHealth); no exec pins.
    final pc = LuminaBlueprintTypeContext.forFunction(doc, percent, className: 'BP_Health');
    LuminaBlueprintNode g(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: pc);
    final pureResult = g('function_result', 'presult');
    expect(pureResult.inputs.where((p) => p.type == LuminaPinType.exec), isEmpty, reason: 'a pure function has no exec pins');
    percent.graph.nodes.addAll([
      g('function_entry', 'pentry'),
      pureResult,
      g(LuminaBlueprintNodeLibrary.variableGet, 'h', {'variable': 'Health'}),
      g(LuminaBlueprintNodeLibrary.variableGet, 'm', {'variable': 'MaxHealth'}),
      g('float_divide', 'div'),
    ]);
    percent.graph.wires.addAll([
      wire('h', 'value', 'div', 'a'),
      wire('m', 'value', 'div', 'b'),
      wire('div', 'return_value', 'presult', 'Percent'),
    ]);
    // Event graph: BeginPlay → AddHealth(10) → print → AddHealth(10) → print; then print HealthPercent.
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Health');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final call1 = p('call_function', 'call1', {'function': 'AddHealth', 'Amount': 10.0});
    expect(call1.title, 'Add Health');
    expect(call1.pin('NewHealth')!.type, LuminaPinType.float);
    final pure = p('call_function_pure', 'pct', {'function': 'HealthPercent'});
    expect(pure.inputs.where((p) => p.type == LuminaPinType.exec), isEmpty);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      call1,
      p('float_to_string', 't1', {'decimals': 0}),
      p('print_string', 'say1'),
      p('call_function', 'call2', {'function': 'AddHealth', 'Amount': 10.0}),
      p('float_to_string', 't2', {'decimals': 0}),
      p('print_string', 'say2'),
      pure,
      p('float_to_string', 't3', {'decimals': 2}),
      p('print_string', 'say3'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'call1', 'exec_in'),
      wire('call1', 'exec_out', 'say1', 'exec_in'),
      wire('call1', 'NewHealth', 't1', 'in_float'),
      wire('t1', 'return_value', 'say1', 'in_string'),
      wire('say1', 'exec_out', 'call2', 'exec_in'),
      wire('call2', 'exec_out', 'say2', 'exec_in'),
      wire('call2', 'NewHealth', 't2', 'in_float'),
      wire('t2', 'return_value', 'say2', 'in_string'),
      wire('say2', 'exec_out', 'say3', 'exec_in'),
      wire('pct', 'Percent', 't3', 'in_float'),
      wire('t3', 'return_value', 'say3', 'in_string'),
    ]);
    final back = LuminaBlueprintDocument.fromJson(jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>);
    expect(back.functions.map((f) => f.name), ['AddHealth', 'HealthPercent']);
    expect(back.functions.first.localVariables.single.name, 'Sum');
    expect(back.functions.last.pure, isTrue);
    final run = play(world(), back, 'BP_Health');
    expect(printed(run.trace), ['110', '120', '0.60']);
    expect(run.actor.variables['Health'], 120.0);
    expect(run.trace.firstWhere((t) => t.nodeId == 'set_sum').eventNodeId, 'entry', reason: 'function nodes trace under the entry');
    expect(run.actor.callBlueprint('AddHealth', {'Amount': 5.0}), {'NewHealth': 125.0});
  });

  test('recursion past 256 frames is a runtime error the editor can show, not a stack overflow', () {
    final doc = LuminaBlueprintDocument();
    final forever = LuminaBlueprintFunctionGraph(name: 'Forever', inputs: [const LuminaBlueprintVariable(name: 'N', typeName: 'Int', defaultValue: 0)]);
    doc.functions.add(forever);
    final fc = LuminaBlueprintTypeContext.forFunction(doc, forever, className: 'BP_Loop');
    forever.graph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('function_entry', nodeId: 'entry', context: fc),
      LuminaBlueprintNodeLibrary.place('call_function', nodeId: 'again', literals: {'function': 'Forever'}, context: fc),
      LuminaBlueprintNodeLibrary.place('function_result', nodeId: 'result', context: fc),
    ]);
    forever.graph.wires.addAll([wire('entry', 'exec_out', 'again', 'exec_in'), wire('again', 'exec_out', 'result', 'exec_in')]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Loop');
    doc.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context),
      LuminaBlueprintNodeLibrary.place('call_function', nodeId: 'start', literals: {'function': 'Forever'}, context: context),
    ]);
    doc.eventGraph.wires.add(wire('begin', 'exec_out', 'start', 'exec_in'));
    final run = play(world(), doc, 'BP_Loop');
    expect(run.actor.lastError, contains('256'));
    expect(run.actor.lastError, contains('Forever'));
  });

  test('a macro ClampAndPrint is expanded into the caller with unique ids while the document keeps it folded', () {
    final doc = LuminaBlueprintDocument();
    final macro = LuminaBlueprintMacroGraph(
      name: 'ClampAndPrint',
      inputs: [
        const LuminaBlueprintVariable(name: 'In', typeName: 'Exec'),
        const LuminaBlueprintVariable(name: 'Value', typeName: 'Float', defaultValue: 0.0),
      ],
      outputs: [
        const LuminaBlueprintVariable(name: 'Out', typeName: 'Exec'),
        const LuminaBlueprintVariable(name: 'Clamped', typeName: 'Float', defaultValue: 0.0),
      ],
    );
    doc.macros.add(macro);
    final mc = LuminaBlueprintTypeContext.forMacro(doc, macro, className: 'BP_Macro');
    LuminaBlueprintNode m(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: mc);
    final input = m('macro_input', 'in');
    expect(input.pin('In')!.type, LuminaPinType.exec);
    expect(input.pin('Value')!.type, LuminaPinType.float);
    macro.graph.nodes.addAll([
      input,
      m('macro_output', 'out'),
      m('float_clamp', 'clamp', {'min': 0.0, 'max': 1.0}),
      m('float_to_string', 'text', {'decimals': 2}),
      m('print_string', 'say'),
    ]);
    macro.graph.wires.addAll([
      wire('in', 'In', 'say', 'exec_in'),
      wire('in', 'Value', 'clamp', 'value'),
      wire('clamp', 'return_value', 'text', 'in_float'),
      wire('text', 'return_value', 'say', 'in_string'),
      wire('say', 'exec_out', 'out', 'Out'),
      wire('clamp', 'return_value', 'out', 'Clamped'),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Macro');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final call = p('call_macro', 'cp', {'macro': 'ClampAndPrint', 'Value': 3.5});
    expect(call.title, 'Clamp And Print');
    expect(call.pin('In')!.type, LuminaPinType.exec);
    expect(call.pin('Clamped')!.type, LuminaPinType.float);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      call,
      p('float_to_string', 'after_text', {'decimals': 1}),
      p('print_string', 'after'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'cp', 'In'),
      wire('cp', 'Out', 'after', 'exec_in'),
      wire('cp', 'Clamped', 'after_text', 'in_float'),
      wire('after_text', 'return_value', 'after', 'in_string'),
    ]);
    final expanded = LuminaBlueprintMacroExpander.expand(doc.eventGraph, doc.macros);
    expect(expanded.nodes.length, doc.eventGraph.nodes.length - 1 + 3, reason: 'the call is replaced by the body (minus its input / output nodes)');
    expect(expanded.node('cp__say'), isNotNull);
    expect(expanded.node('cp'), isNull);
    expect(expanded.wireInto('cp__say', 'exec_in')!.fromNodeId, 'begin');
    expect(expanded.wireInto('after', 'exec_in')!.fromNodeId, 'cp__say');
    expect(expanded.wireInto('after_text', 'in_float')!.fromNodeId, 'cp__clamp');
    expect(expanded.node('cp__clamp')!.literals['value'], 3.5, reason: 'the call literal feeds the body');
    expect(doc.eventGraph.node('cp'), isNotNull, reason: 'the document stays folded');
    final back = LuminaBlueprintDocument.fromJson(jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>);
    expect(back.macros.single.name, 'ClampAndPrint');
    expect(back.eventGraph.node('cp')!.registryId, 'call_macro');
    final run = play(world(), back, 'BP_Macro');
    expect(printed(run.trace), ['1.00', '1.0']);
    expect(run.trace.map((t) => t.nodeId), contains('cp__say'));
  });

  test('the validator names unknown functions, events and macros, duplicate custom events and a missing Result', () {
    final doc = LuminaBlueprintDocument();
    final f = LuminaBlueprintFunctionGraph(name: 'Answer', outputs: [const LuminaBlueprintVariable(name: 'Value', typeName: 'Int', defaultValue: 0)]);
    doc.functions.add(f);
    f.graph.nodes.add(LuminaBlueprintNodeLibrary.place('function_entry', nodeId: 'entry', context: LuminaBlueprintTypeContext.forFunction(doc, f)));
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Bad');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      p('custom_event', 'a', {'name': 'Ping'}),
      p('custom_event', 'b', {'name': 'Ping'}),
      p('call_function', 'nofn', {'function': 'Nope'}),
      p('call_custom_event', 'noev', {'event': 'Missing'}),
      p('call_macro', 'nomacro', {'macro': 'Gone'}),
    ]);
    final errors = validateBlueprint(doc, className: 'BP_Bad').where((d) => d.isError).map((d) => d.message).toList();
    expect(errors, contains(contains("Custom event 'Ping' is declared twice")));
    expect(errors, contains(contains("unknown function 'Nope'")));
    expect(errors, contains(contains("unknown custom event 'Missing'")));
    expect(errors, contains(contains("unknown macro 'Gone'")));
    expect(errors, contains(contains("Function 'Answer' has outputs but no Return node")));
  });
}
