import 'package:lumina/lumina.dart';

/// A character Blueprint with a ragdoll: capsule, movement and a ragdoll
/// component built by the component mapping; BeginPlay prints Is Ragdoll,
/// starts the ragdoll (printing Started and Is Ragdoll), pushes the head,
/// then Toggle Ragdoll gets up and Is Ragdoll is printed again; Stop
/// Ragdoll on an animated character does nothing.
LuminaBlueprintDocument ragdollBlueprint() {
  final components = [
    LuminaBlueprintComponent(id: 'root', name: 'Capsule', type: 'LuminaCapsuleComponent', properties: {
      'radius': 35.0,
      'halfHeight': 90.0,
    }),
    LuminaBlueprintComponent(id: 'move', name: 'CharacterMovement', type: 'LuminaCharacterMovementComponent'),
    LuminaBlueprintComponent(id: 'ragdoll', name: 'Ragdoll', type: 'LuminaRagdollComponent', properties: {
      'physicsAsset': '',
      'blendOutTime': 0.25,
      'settleSpeed': 6.0,
      'getUpClips': ['GetUp_Front', 'GetUp_Back'],
      'hardLandingSpeed': 800.0,
    }),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_ragdoll');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('is_ragdoll', 'before'),
    place('bool_to_string', 'before_text'),
    place('print_string', 'say_before'),
    place('stop_ragdoll', 'stop_idle', {'get_up': true}),
    place('start_ragdoll', 'start'),
    place('bool_to_string', 'started_text'),
    place('print_string', 'say_started'),
    place('is_ragdoll', 'during'),
    place('bool_to_string', 'during_text'),
    place('print_string', 'say_during'),
    place('add_ragdoll_impulse', 'push', {'impulse': [0.0, 3000.0, 0.0], 'bone_name': 'head'}),
    place('toggle_ragdoll', 'toggle'),
    place('is_ragdoll', 'after'),
    place('bool_to_string', 'after_text'),
    place('print_string', 'say_after'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'say_before', 'exec_in'),
    wire('before', 'return_value', 'before_text', 'in_bool'),
    wire('before_text', 'return_value', 'say_before', 'in_string'),
    wire('say_before', 'exec_out', 'stop_idle', 'exec_in'),
    wire('stop_idle', 'exec_out', 'start', 'exec_in'),
    wire('start', 'return_value', 'started_text', 'in_bool'),
    wire('started_text', 'return_value', 'say_started', 'in_string'),
    wire('start', 'exec_out', 'say_started', 'exec_in'),
    wire('say_started', 'exec_out', 'say_during', 'exec_in'),
    wire('during', 'return_value', 'during_text', 'in_bool'),
    wire('during_text', 'return_value', 'say_during', 'in_string'),
    wire('say_during', 'exec_out', 'push', 'exec_in'),
    wire('push', 'exec_out', 'toggle', 'exec_in'),
    wire('toggle', 'exec_out', 'say_after', 'exec_in'),
    wire('after', 'return_value', 'after_text', 'in_bool'),
    wire('after_text', 'return_value', 'say_after', 'in_string'),
  ]);
  return doc;
}
