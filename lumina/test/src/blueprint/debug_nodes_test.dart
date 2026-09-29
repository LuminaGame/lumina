import 'dart:developer' as developer;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Print String's screen messages, the Draw Debug shapes the
/// editor renders, and the log nodes.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  test('Print String with a key replaces the previous screen message; durations expire; log levels', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final doc = LuminaBlueprintDocument();
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Debug');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final ps = p('print_string', 'fps', {'in_string': 'FPS: 60', 'print_to_screen': true, 'print_to_log': false, 'key': 'fps', 'duration': 0.0});
    expect(ps.pin('text_color')!.type, LuminaPinType.color);
    expect(ps.pin('key')!.type, LuminaPinType.name);
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('get_frame_number', 'frame'),
      p('int_to_string', 'frame_text'),
      p('append', 'line', {'a': 'FPS: '}),
      ps,
      p('print_text', 'hello', {'in_text': 'hello', 'duration': 5.0, 'text_color': [1.0, 0.0, 0.0, 1.0]}),
      p('log_warning', 'warn', {'in_string': 'careful'}),
      p('log_error', 'err', {'in_string': 'broken'}),
      p('breakpoint', 'bp'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('tick', 'exec_tick_out', 'fps', 'exec_in'),
      wire('frame', 'return_value', 'frame_text', 'in_int'),
      wire('frame_text', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'fps', 'in_string'),
      wire('fps', 'exec_out', 'hello', 'exec_in'),
      wire('hello', 'exec_out', 'warn', 'exec_in'),
      wire('warn', 'exec_out', 'err', 'exec_in'),
      wire('err', 'exec_out', 'bp', 'exec_in'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Debug');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    final logged = <({String message, int level})>[];
    LuminaBlueprintFunctionLibrary.onLog = (self, message, level) => logged.add((message: message, level: level));
    addTearDown(() => LuminaBlueprintFunctionLibrary.onLog = null);
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    w.tick(1 / 60);
    expect(w.screenMessages['fps']!.text, 'FPS: 1');
    expect(w.screenMessages.length, 2, reason: 'the keyed line and the unkeyed hello');
    w.tick(1 / 60);
    expect(w.screenMessages['fps']!.text, 'FPS: 2', reason: 'the same key replaces the line');
    expect(w.screenMessages.values.where((m) => m.text == 'hello').length, 2, reason: 'unkeyed lines stack');
    expect(w.screenMessages.values.firstWhere((m) => m.text == 'hello').color, [1.0, 0.0, 0.0, 1.0]);
    expect(trace.where((t) => t.printed == 'hello').length, 2, reason: 'Print Text traces like Print String');
    expect(logged.where((l) => l.level == 900).map((l) => l.message), ['careful', 'careful']);
    expect(logged.where((l) => l.level == 1000).map((l) => l.message), ['broken', 'broken']);
    expect(logged.where((l) => l.message == 'FPS: 1'), isEmpty, reason: 'Print to Log was off');
    expect(trace.where((t) => t.registryId == 'breakpoint').length, 2, reason: 'a breakpoint traces and continues');
    // Durations: the 0 s line is gone next frame when nothing rewrites it; 5 s hello lives on.
    actor.destroy();
    w.tick(1 / 60);
    w.tick(1 / 60);
    expect(w.screenMessages.containsKey('fps'), isFalse);
    expect(w.screenMessages.values.where((m) => m.text == 'hello').length, 3, reason: 'one more tick ran before the deferred destroy');
    for (var i = 0; i < 6 * 60; i++) {
      w.tick(1 / 60);
    }
    expect(w.screenMessages, isEmpty);
    developer.log('debug nodes ok', name: 'Blueprint');
  });

  test('Draw Debug Line adds a shape with its expiry; every shape kind records; Flush clears', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final actor = LuminaActor();
    w.persistentLevel.registerActor(actor);
    LuminaBlueprintFunctionLibrary.drawDebugLine(actor, Vector3(0, 0, 0), Vector3(0, 100, 0), [0.0, 1.0, 0.0, 1.0], 0.5, 2.0);
    expect(w.debugShapes.length, 1);
    final line = w.debugShapes.single;
    expect(line.kind, LuminaDebugShapeKind.line);
    expect(line.points, [Vector3(0, 0, 0), Vector3(0, 0, -100)], reason: 'stored in runtime axes');
    expect(line.expiresAt, closeTo(w.realTimeSeconds + 0.5, 1e-9));
    expect(line.thickness, 2.0);
    LuminaBlueprintFunctionLibrary.drawDebugSphere(actor, Vector3(1, 2, 3), 50.0, 12, [1.0, 0.0, 0.0, 1.0], 1.0);
    LuminaBlueprintFunctionLibrary.drawDebugBox(actor, Vector3.zero(), Vector3(10, 20, 30), const LuminaRotator(0, 0, 90), [1.0, 1.0, 0.0, 1.0], 1.0);
    LuminaBlueprintFunctionLibrary.drawDebugPoint(actor, Vector3(5, 5, 5), 4.0, [1.0, 1.0, 1.0, 1.0], 1.0);
    LuminaBlueprintFunctionLibrary.drawDebugArrow(actor, Vector3.zero(), Vector3(100, 0, 0), 10.0, [0.0, 0.0, 1.0, 1.0], 1.0);
    LuminaBlueprintFunctionLibrary.drawDebugString(actor, Vector3(0, 0, 200), 'hi', [1.0, 1.0, 1.0, 1.0], 1.0);
    LuminaBlueprintFunctionLibrary.drawDebugCapsule(actor, Vector3.zero(), 80.0, 40.0, const LuminaRotator.zero(), [0.0, 1.0, 1.0, 1.0], 1.0);
    expect(w.debugShapes.map((s) => s.kind).toSet(), LuminaDebugShapeKind.values.toSet());
    expect(w.debugShapes.firstWhere((s) => s.kind == LuminaDebugShapeKind.string).text, 'hi');
    expect(w.debugShapes.firstWhere((s) => s.kind == LuminaDebugShapeKind.box).extent, Vector3(10, 30, 20));
    // Expiry: the 0.5 s line goes at 0.5 s, the rest at 1 s.
    w.tick(0.6);
    expect(w.debugShapes.where((s) => s.kind == LuminaDebugShapeKind.line), isEmpty);
    expect(w.debugShapes.length, 6);
    w.tick(0.5);
    expect(w.debugShapes, isEmpty);
    LuminaBlueprintFunctionLibrary.drawDebugPoint(actor, Vector3.zero(), 1.0, [1.0, 1.0, 1.0, 1.0], 10.0);
    LuminaBlueprintFunctionLibrary.flushDebugShapes(actor);
    expect(w.debugShapes, isEmpty);
    for (final id in const ['draw_debug_line', 'draw_debug_sphere', 'draw_debug_box', 'draw_debug_point', 'draw_debug_arrow', 'draw_debug_string', 'draw_debug_capsule', 'flush_debug_shapes', 'breakpoint', 'log_warning', 'log_error', 'print_text']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintNodeLibrary.spec(id)!.category, 'Debug', reason: id);
    }
  });
}
