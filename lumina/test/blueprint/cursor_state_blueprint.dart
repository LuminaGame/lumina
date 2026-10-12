import 'package:lumina/lumina.dart';

/// A menu's cursor handling as a Pawn Blueprint: BeginPlay prints the cursor
/// and input mode it finds, frees the cursor for the UI (Show Mouse Cursor,
/// Input Mode UI Only) and prints them again, restores Game Only without a
/// cursor and prints them a third time. Then it prints whether GPU memory is
/// available and the render resolution's width and height. Every cursor and
/// input-mode node names Get Player Controller as its Target.
LuminaBlueprintDocument cursorStateBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaPawn');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_cursor_state');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  final chain = <String>['begin'];
  doc.eventGraph.nodes.addAll([place('event_beginplay', 'begin'), place('get_player_controller', 'pc')]);
  void target(String nodeId) => doc.eventGraph.wires.add(wire('pc', 'return_value', nodeId, 'target'));
  void sayState(String suffix) {
    doc.eventGraph.nodes.addAll([
      place('get_show_mouse_cursor', 'cursor_$suffix'),
      place('bool_to_string', 'cursor_text_$suffix'),
      place('print_string', 'say_cursor_$suffix'),
      place('get_input_mode', 'mode_$suffix'),
      place('print_string', 'say_mode_$suffix'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('cursor_$suffix', 'return_value', 'cursor_text_$suffix', 'in_bool'),
      wire('cursor_text_$suffix', 'return_value', 'say_cursor_$suffix', 'in_string'),
      wire('mode_$suffix', 'return_value', 'say_mode_$suffix', 'in_string'),
    ]);
    target('cursor_$suffix');
    target('mode_$suffix');
    chain.addAll(['say_cursor_$suffix', 'say_mode_$suffix']);
  }

  sayState('found');
  doc.eventGraph.nodes.addAll([
    place('set_show_mouse_cursor', 'show_cursor', {'show_mouse_cursor': true}),
    place('set_input_mode_ui_only', 'ui_only'),
  ]);
  chain.addAll(['show_cursor', 'ui_only']);
  ['show_cursor', 'ui_only'].forEach(target);
  sayState('menu');
  doc.eventGraph.nodes.addAll([
    place('set_show_mouse_cursor', 'hide_cursor', {'show_mouse_cursor': false}),
    place('set_input_mode_game_only', 'game_only'),
  ]);
  chain.addAll(['hide_cursor', 'game_only']);
  ['hide_cursor', 'game_only'].forEach(target);
  sayState('restored');

  doc.eventGraph.nodes.addAll([
    place('get_gpu_memory_usage', 'gpu'),
    place('bool_to_string', 'gpu_text'),
    place('print_string', 'say_gpu'),
    place('get_render_resolution', 'render'),
    place('int_to_string', 'render_width_text'),
    place('print_string', 'say_render_width'),
    place('int_to_string', 'render_height_text'),
    place('print_string', 'say_render_height'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('gpu', 'available', 'gpu_text', 'in_bool'),
    wire('gpu_text', 'return_value', 'say_gpu', 'in_string'),
    wire('render', 'width', 'render_width_text', 'in_int'),
    wire('render_width_text', 'return_value', 'say_render_width', 'in_string'),
    wire('render', 'height', 'render_height_text', 'in_int'),
    wire('render_height_text', 'return_value', 'say_render_height', 'in_string'),
  ]);
  chain.addAll(['say_gpu', 'say_render_width', 'say_render_height']);

  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  return doc;
}
