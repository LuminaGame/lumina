import 'package:lumina/lumina.dart';

/// A game's display menu as a Blueprint: BeginPlay chooses 1920×1080 on
/// monitor 0, applies the settings, then prints the screen resolution
/// (width, height), how many resolutions the monitor offers, the monitor
/// count, the current monitor's name, the desktop's refresh rate and how
/// many refresh rates 1920×1080 has.
LuminaBlueprintDocument displaySettingsBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_display_settings');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('set_screen_resolution', 'resolution', {'width': 1920, 'height': 1080}),
    place('set_fullscreen_monitor', 'monitor', {'index': 0}),
    place('apply_scalability_settings', 'apply'),
    place('get_screen_resolution', 'screen'),
    place('int_to_string', 'width_text'),
    place('print_string', 'say_width'),
    place('int_to_string', 'height_text'),
    place('print_string', 'say_height'),
    place('get_supported_resolutions', 'supported'),
    place('array_length', 'supported_count'),
    place('int_to_string', 'supported_text'),
    place('print_string', 'say_supported'),
    place('get_monitor_count', 'monitors'),
    place('int_to_string', 'monitors_text'),
    place('print_string', 'say_monitors'),
    place('get_current_monitor', 'current'),
    place('print_string', 'say_current'),
    place('get_desktop_resolution', 'desktop'),
    place('int_to_string', 'desktop_hz_text'),
    place('print_string', 'say_desktop_hz'),
    place('get_supported_refresh_rates', 'rates', {'width': 1920, 'height': 1080}),
    place('array_length', 'rates_count'),
    place('int_to_string', 'rates_text'),
    place('print_string', 'say_rates'),
  ]);
  const chain = ['begin', 'resolution', 'monitor', 'apply', 'say_width', 'say_height', 'say_supported', 'say_monitors',
    'say_current', 'say_desktop_hz', 'say_rates'];
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  doc.eventGraph.wires.addAll([
    wire('screen', 'width', 'width_text', 'in_int'),
    wire('width_text', 'return_value', 'say_width', 'in_string'),
    wire('screen', 'height', 'height_text', 'in_int'),
    wire('height_text', 'return_value', 'say_height', 'in_string'),
    wire('supported', 'return_value', 'supported_count', 'target_array'),
    wire('supported_count', 'return_value', 'supported_text', 'in_int'),
    wire('supported_text', 'return_value', 'say_supported', 'in_string'),
    wire('monitors', 'return_value', 'monitors_text', 'in_int'),
    wire('monitors_text', 'return_value', 'say_monitors', 'in_string'),
    wire('current', 'name', 'say_current', 'in_string'),
    wire('desktop', 'refresh_rate', 'desktop_hz_text', 'in_int'),
    wire('desktop_hz_text', 'return_value', 'say_desktop_hz', 'in_string'),
    wire('rates', 'return_value', 'rates_count', 'target_array'),
    wire('rates_count', 'return_value', 'rates_text', 'in_int'),
    wire('rates_text', 'return_value', 'say_rates', 'in_string'),
  ]);
  return doc;
}
