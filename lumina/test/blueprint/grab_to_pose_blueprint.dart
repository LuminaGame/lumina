import 'package:lumina/lumina.dart';

/// A pawn-like actor that grabs pose handles: BeginPlay adds a grab
/// interactor and sets its radius; On Pose Handle Grabbed prints the
/// handle's name, On Pose Handle Released the grabber's id; On Pose Handle
/// Hovered has nothing wired.
LuminaBlueprintDocument grabToPoseBlueprint() {
  final components = [LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent')];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_grab_to_pose');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('add_grab_interactor', 'add', {'use_mouse': false}),
    place('set_grab_radius', 'radius', {'radius': 8.0}),
    place('event_pose_handle_grabbed', 'grabbed'),
    place('print_string', 'say_grabbed'),
    place('event_pose_handle_released', 'released'),
    place('print_string', 'say_released'),
    place('event_pose_handle_hovered', 'hovered'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'add', 'exec_in'),
    wire('add', 'exec_out', 'radius', 'exec_in'),
    wire('grabbed', 'exec_out', 'say_grabbed', 'exec_in'),
    wire('grabbed', 'handle', 'say_grabbed', 'in_string'),
    wire('released', 'exec_out', 'say_released', 'exec_in'),
    wire('released', 'grabber', 'say_released', 'in_string'),
  ]);
  return doc;
}
