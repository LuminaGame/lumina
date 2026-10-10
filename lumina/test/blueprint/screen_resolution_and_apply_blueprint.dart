import 'package:lumina/lumina.dart';

/// A one-click resolution button as a Blueprint: BeginPlay runs Set Screen
/// Resolution And Apply with 1600×900, which applies it at once without Apply
/// Scalability Settings, then prints the screen resolution (width, height).
LuminaBlueprintDocument screenResolutionAndApplyBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_screen_resolution_and_apply');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('set_screen_resolution_and_apply', 'resolution', {'width': 1600, 'height': 900}),
    place('get_screen_resolution', 'screen'),
    place('int_to_string', 'width_text'),
    place('print_string', 'say_width'),
    place('int_to_string', 'height_text'),
    place('print_string', 'say_height'),
  ]);
  const chain = ['begin', 'resolution', 'say_width', 'say_height'];
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  doc.eventGraph.wires.addAll([
    wire('screen', 'width', 'width_text', 'in_int'),
    wire('width_text', 'return_value', 'say_width', 'in_string'),
    wire('screen', 'height', 'height_text', 'in_int'),
    wire('height_text', 'return_value', 'say_height', 'in_string'),
  ]);
  return doc;
}
