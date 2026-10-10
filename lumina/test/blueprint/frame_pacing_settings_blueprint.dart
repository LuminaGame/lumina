import 'package:lumina/lumina.dart';

/// A graphics menu's frame rate choice as a Blueprint: BeginPlay prints the
/// target frame rate and VSync in force, sets 30 FPS with VSync off, applies
/// them (Apply Scalability Settings) and prints both again.
LuminaBlueprintDocument framePacingSettingsBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_frame_pacing_settings');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('get_target_fps', 'fps_before'),
    place('int_to_string', 'fps_before_text'),
    place('print_string', 'say_fps_before'),
    place('get_vsync_enabled', 'vsync_before'),
    place('bool_to_string', 'vsync_before_text'),
    place('print_string', 'say_vsync_before'),
    place('set_target_fps', 'set_fps', {'fps': 30}),
    place('set_vsync_enabled', 'set_vsync', {'enabled': false}),
    place('apply_scalability_settings', 'apply'),
    place('get_target_fps', 'fps_after'),
    place('int_to_string', 'fps_after_text'),
    place('print_string', 'say_fps_after'),
    place('get_vsync_enabled', 'vsync_after'),
    place('bool_to_string', 'vsync_after_text'),
    place('print_string', 'say_vsync_after'),
  ]);
  const chain = ['begin', 'say_fps_before', 'say_vsync_before', 'set_fps', 'set_vsync', 'apply', 'say_fps_after', 'say_vsync_after'];
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  doc.eventGraph.wires.addAll([
    wire('fps_before', 'return_value', 'fps_before_text', 'in_int'),
    wire('fps_before_text', 'return_value', 'say_fps_before', 'in_string'),
    wire('vsync_before', 'return_value', 'vsync_before_text', 'in_bool'),
    wire('vsync_before_text', 'return_value', 'say_vsync_before', 'in_string'),
    wire('fps_after', 'return_value', 'fps_after_text', 'in_int'),
    wire('fps_after_text', 'return_value', 'say_fps_after', 'in_string'),
    wire('vsync_after', 'return_value', 'vsync_after_text', 'in_bool'),
    wire('vsync_after_text', 'return_value', 'say_vsync_after', 'in_string'),
  ]);
  return doc;
}
