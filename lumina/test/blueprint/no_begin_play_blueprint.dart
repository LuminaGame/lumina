import 'package:lumina/lumina.dart';

/// A Blueprint with no Event BeginPlay — a custom event `Ping` runs
/// a latent Delay, then prints `pong` — whose generated class must still
/// analyze clean (no empty `onBeginPlay` override).
LuminaBlueprintDocument noBeginPlayBlueprint() {
  const context = LuminaBlueprintTypeContext(variables: []);
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'nb${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  return LuminaBlueprintDocument(
    parentClass: 'LuminaActor',
    eventGraph: LuminaBlueprintGraph(nodes: [
      place('custom_event', 'ping', {'name': 'Ping'}),
      place('delay', 'wait', {'duration': 0.25}),
      place('print_string', 'pong', {'in_string': 'pong', 'print_to_screen': false}),
    ], wires: [
      wire('ping', 'exec_out', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'pong', 'exec_in'),
    ]),
  );
}
