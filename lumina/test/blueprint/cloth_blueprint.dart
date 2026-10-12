import 'package:lumina/lumina.dart';

/// A flag Blueprint: a grid cloth pinned on its top edge, built by the
/// component mapping. BeginPlay prints Is Cloth Simulating, sets the wind,
/// pins one more vertex, switches the simulation off (printing again), on,
/// and resets the cloth (printing a last time).
LuminaBlueprintDocument clothBlueprint() {
  final components = [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent', isSceneComponent: true),
    LuminaBlueprintComponent(
      id: 'flag',
      name: 'Flag',
      type: 'LuminaClothComponent',
      parentId: 'root',
      isSceneComponent: true,
      properties: {
        'gridWidth': 120.0,
        'gridHeight': 80.0,
        'gridColumns': 12,
        'gridRows': 8,
        'pinning': 'topEdge',
        'massKg': 0.5,
        'stiffness': 0.95,
        'bendStiffness': 0.2,
        'wind': [0.0, 0.0, 0.0],
        'color': [0.1, 0.3, 0.8],
        'location': [0.0, 0.0, 300.0],
      },
    ),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_cloth');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('is_cloth_simulating', 'before'),
    place('bool_to_string', 'before_text'),
    place('print_string', 'say_before'),
    place('set_cloth_wind', 'blow', {'wind': [600.0, 0.0, 0.0], 'drag': 2.0}),
    place('pin_cloth_vertex', 'pin', {'vertex': 100, 'pinned': true}),
    place('set_cloth_simulation_enabled', 'off', {'enabled': false}),
    place('is_cloth_simulating', 'during'),
    place('bool_to_string', 'during_text'),
    place('print_string', 'say_during'),
    place('set_cloth_simulation_enabled', 'on', {'enabled': true}),
    place('reset_cloth', 'reset'),
    place('is_cloth_simulating', 'after'),
    place('bool_to_string', 'after_text'),
    place('print_string', 'say_after'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'say_before', 'exec_in'),
    wire('before', 'return_value', 'before_text', 'in_bool'),
    wire('before_text', 'return_value', 'say_before', 'in_string'),
    wire('say_before', 'exec_out', 'blow', 'exec_in'),
    wire('blow', 'exec_out', 'pin', 'exec_in'),
    wire('pin', 'exec_out', 'off', 'exec_in'),
    wire('off', 'exec_out', 'say_during', 'exec_in'),
    wire('during', 'return_value', 'during_text', 'in_bool'),
    wire('during_text', 'return_value', 'say_during', 'in_string'),
    wire('say_during', 'exec_out', 'on', 'exec_in'),
    wire('on', 'exec_out', 'reset', 'exec_in'),
    wire('reset', 'exec_out', 'say_after', 'exec_in'),
    wire('after', 'return_value', 'after_text', 'in_bool'),
    wire('after_text', 'return_value', 'say_after', 'in_string'),
  ]);
  return doc;
}
