import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Timers by event / function name driven by the world's timer
/// manager, and Timelines with float / vector / colour curves.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  ({LuminaWorld world, LuminaBlueprintActor actor, List<LuminaBlueprintTraceEvent> trace}) play(LuminaBlueprintDocument doc, String name) {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: name);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    return (world: w, actor: actor, trace: trace);
  }

  test('Set Timer by Event 0.5 s looping runs OnPulse three times in 1.6 s; pause freezes it; clear stops it; next tick runs once', () {
    final doc = LuminaBlueprintDocument(variables: [
      const LuminaBlueprintVariable(name: 'Handle', typeName: 'TimerHandle'),
      const LuminaBlueprintVariable(name: 'Pulses', typeName: 'Int', defaultValue: 0),
    ]);
    expect(doc.variables.first.type, LuminaPinType.timerHandle);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Timer');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final setTimer = p('set_timer_by_event', 'timer', {'time': 0.5, 'looping': true});
    expect(setTimer.pin('event')!.type, LuminaPinType.delegate);
    expect(setTimer.pin('return_value')!.type, LuminaPinType.timerHandle);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('custom_event', 'pulse', {'name': 'OnPulse'}),
      setTimer,
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_handle', {'variable': 'Handle'}),
      p(LuminaBlueprintNodeLibrary.variableGet, 'pulses', {'variable': 'Pulses'}),
      p('int_increment', 'inc'),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_pulses', {'variable': 'Pulses'}),
      p('print_string', 'say', {'in_string': 'pulse'}),
      p('set_timer_for_next_tick', 'next'),
      p('custom_event', 'once', {'name': 'NextTick'}),
      p('print_string', 'say_once', {'in_string': 'next tick'}),
      p('set_timer_by_function_name', 'by_name', {'function_name': 'Named', 'time': 0.2}),
      p('custom_event', 'named', {'name': 'Named'}),
      p('print_string', 'say_named', {'in_string': 'named'}),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'timer', 'exec_in'),
      wire('pulse', 'delegate', 'timer', 'event'),
      wire('timer', 'exec_out', 'set_handle', 'exec_in'),
      wire('timer', 'return_value', 'set_handle', 'value'),
      wire('set_handle', 'exec_out', 'next', 'exec_in'),
      wire('once', 'delegate', 'next', 'event'),
      wire('next', 'exec_out', 'by_name', 'exec_in'),
      wire('pulse', 'exec_out', 'set_pulses', 'exec_in'),
      wire('pulses', 'value', 'inc', 'a'),
      wire('inc', 'return_value', 'set_pulses', 'value'),
      wire('set_pulses', 'exec_out', 'say', 'exec_in'),
      wire('once', 'exec_out', 'say_once', 'exec_in'),
      wire('named', 'exec_out', 'say_named', 'exec_in'),
    ]);
    final back = LuminaBlueprintDocument.fromJson(jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>);
    final run = play(back, 'BP_Timer');
    final handle = run.actor.variables['Handle'];
    expect(handle, isA<LuminaTimerHandle>());
    run.world.tick(0.1);
    expect(printed(run.trace), ['next tick']);
    for (var i = 0; i < 15; i++) {
      run.world.tick(0.1);
    }
    expect(run.actor.variables['Pulses'], 3, reason: 'at 0.5, 1.0 and 1.5 s of 1.6 s');
    expect(printed(run.trace).where((s) => s == 'named').length, 1, reason: 'a one-shot timer by function name');
    final ctx = LuminaBlueprintCallContext(run.actor);
    Object? call(String id, Map<String, Object?> inputs) => LuminaBlueprintFunctionLibrary.functions[id]!(ctx, inputs)['return_value'];
    expect(call('is_timer_active', {'handle': handle}), isTrue);
    final remaining = call('get_timer_remaining_time', {'handle': handle}) as double;
    expect(remaining, closeTo(0.4, 1e-6));
    expect(call('get_timer_elapsed_time', {'handle': handle}), closeTo(0.1, 1e-6));
    LuminaBlueprintFunctionLibrary.functions['pause_timer']!(ctx, {'handle': handle});
    run.world.tick(0.3);
    expect(call('is_timer_paused', {'handle': handle}), isTrue);
    expect(call('get_timer_remaining_time', {'handle': handle}), closeTo(remaining, 1e-6), reason: 'frozen while paused');
    LuminaBlueprintFunctionLibrary.functions['unpause_timer']!(ctx, {'handle': handle});
    run.world.tick(0.5);
    expect(run.actor.variables['Pulses'], 4);
    LuminaBlueprintFunctionLibrary.functions['clear_timer_by_handle']!(ctx, {'handle': handle});
    run.world.tick(1.0);
    expect(run.actor.variables['Pulses'], 4, reason: 'cleared');
    expect(call('is_timer_active', {'handle': handle}), isFalse);
    // Handles die with the actor.
    final again = LuminaBlueprintFunctionLibrary.setTimerByEvent(run.actor, LuminaBlueprintDelegate(run.actor, 'OnPulse'), 0.2, true);
    expect(run.actor.blueprintTimerHandles, contains(again));
    run.actor.destroy();
    run.world.tick(0.1);
    run.world.tick(1.0);
    expect(run.actor.variables['Pulses'], 4, reason: 'End Play cleared the actor\'s timers');
    // A Set Timer on an event with parameters is refused.
    doc.eventGraph.nodes.addAll([
      p('custom_event', 'with_arg', {'name': 'WithArg', 'parameters': [{'name': 'X', 'type': 'Int'}]}),
      p('set_timer_by_event', 'bad_timer', {'time': 1.0}),
    ]);
    doc.eventGraph.wires.add(wire('with_arg', 'delegate', 'bad_timer', 'event'));
    expect(validateBlueprint(doc, className: 'BP_Timer').where((d) => d.isError).map((d) => d.message),
        contains(contains("'WithArg' has parameters")));
  });

  test('Timeline DoorSwing: Update every tick with a rising track, Finished at 1 s with 90, Reverse back to 0, Set New Time, Loop', () {
    const tracks = [
      {
        'name': 'Angle',
        'type': 'float',
        'keys': [
          {'time': 0.0, 'value': 0.0, 'interp': 'cubic'},
          {'time': 1.0, 'value': 90.0, 'interp': 'cubic'},
        ],
      },
      {
        'name': 'Offset',
        'type': 'vector',
        'keys': [
          {'time': 0.0, 'value': [0.0, 0.0, 0.0], 'interp': 'linear'},
          {'time': 1.0, 'value': [0.0, 100.0, 0.0], 'interp': 'linear'},
        ],
      },
      {
        'name': 'Tint',
        'type': 'color',
        'keys': [
          {'time': 0.0, 'value': [1.0, 0.0, 0.0, 1.0], 'interp': 'constant'},
          {'time': 0.5, 'value': [0.0, 1.0, 0.0, 1.0], 'interp': 'constant'},
        ],
      },
    ];
    final curve = LuminaTimelineTrack.fromJson(tracks[0]);
    expect(curve.evaluate(0.5), closeTo(45.0, 2.0), reason: 'cubic within ±2');
    expect(curve.evaluate(1.0), 90.0);
    expect(curve.evaluate(2.0), 90.0, reason: 'held after the last key');
    expect(LuminaTimelineTrack.fromJson(tracks[2]).evaluate(0.49), [1.0, 0.0, 0.0, 1.0]);
    expect(LuminaTimelineTrack.fromJson(tracks[2]).evaluate(0.5), [0.0, 1.0, 0.0, 1.0]);

    final doc = LuminaBlueprintDocument();
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Swing');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final timeline = p('timeline', 'swing', {'name': 'DoorSwing', 'length': 1.0, 'loop': false, 'auto_play': false, 'tracks': tracks});
    expect(timeline.title, 'DoorSwing');
    expect(timeline.pin('Angle')!.type, LuminaPinType.float);
    expect(timeline.pin('Offset')!.type, LuminaPinType.vector);
    expect(timeline.pin('Tint')!.type, LuminaPinType.color);
    expect(timeline.pin('direction')!.type, LuminaPinType.enumeration);
    expect(timeline.inputs.where((i) => i.type == LuminaPinType.exec).map((i) => i.id),
        ['play', 'play_from_start', 'stop', 'reverse', 'reverse_from_start', 'set_new_time']);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      timeline,
      p('float_to_string', 'angle_text', {'decimals': 1}),
      p('print_string', 'say_update'),
      p('float_to_string', 'done_text', {'decimals': 1}),
      p('append', 'done_line', {'a': 'finished at '}),
      p('print_string', 'say_done'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'swing', 'play'),
      wire('swing', 'update', 'say_update', 'exec_in'),
      wire('swing', 'Angle', 'angle_text', 'in_float'),
      wire('angle_text', 'return_value', 'say_update', 'in_string'),
      wire('swing', 'finished', 'say_done', 'exec_in'),
      wire('swing', 'Angle', 'done_text', 'in_float'),
      wire('done_text', 'return_value', 'done_line', 'b'),
      wire('done_line', 'return_value', 'say_done', 'in_string'),
    ]);
    final back = LuminaBlueprintDocument.fromJson(jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>);
    expect((back.eventGraph.node('swing')!.literals['tracks'] as List).length, 3);
    final run = play(back, 'BP_Swing');
    final tl = run.actor.blueprintTimelines['swing']!;
    expect(tl.isPlaying, isTrue);
    for (var i = 0; i < 10; i++) {
      run.world.tick(0.1);
    }
    final updates = [for (final s in printed(run.trace)) if (!s.startsWith('finished')) double.parse(s)];
    expect(updates.length, 10);
    for (var i = 1; i < updates.length; i++) {
      expect(updates[i], greaterThan(updates[i - 1]));
    }
    expect(updates.last, 90.0);
    expect(printed(run.trace).last, 'finished at 90.0');
    expect(tl.isPlaying, isFalse);
    expect(tl.position, 1.0);
    final ctx = LuminaBlueprintCallContext(run.actor);
    // Reverse from 90 back to 0: Update runs each tick, Finished fires at 0.
    run.actor.blueprintTimeline('swing').reverse();
    for (var i = 0; i < 10; i++) {
      run.world.tick(0.1);
    }
    expect(tl.position, closeTo(0.0, 1e-9));
    expect(printed(run.trace).last, 'finished at 0.0');
    expect(tl.direction, 'Backward');
    // Set New Time 0.5 → ≈45 (cubic within ±2).
    tl.setNewTime(0.5);
    expect(tl.values()['Angle'], closeTo(45.0, 2.0));
    expect((tl.values()['Offset'] as dynamic).y, closeTo(50.0, 1e-9));
    expect(tl.values()['Tint'], [0.0, 1.0, 0.0, 1.0]);
    // Loop keeps running past 1 s.
    tl.loop = true;
    tl.playFromStart();
    for (var i = 0; i < 25; i++) {
      run.world.tick(0.1);
    }
    expect(tl.isPlaying, isTrue);
    expect(tl.position, closeTo(0.5, 1e-6));
    expect(run.trace.where((t) => t.nodeId == 'say_done').length, 4, reason: 'Finished fires at every loop end');
    expect(LuminaBlueprintFunctionLibrary.functions.containsKey('timeline'), isFalse, reason: 'a VM intrinsic');
    expect(ctx.self, run.actor);
  });
}
