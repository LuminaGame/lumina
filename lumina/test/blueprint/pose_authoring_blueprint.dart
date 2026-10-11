import 'package:lumina/lumina.dart';

/// The test-assets mannequin, relative to the lumina package (the
/// directory tests run in).
const String poseAuthoringMeshPath = '../test-assets/mannequin/SKM_Manny_Simple.glb';

/// Where the graph puts the right hand, in authoring axes (cm).
const List<double> poseAuthoringHandTarget = [-35.0, -25.0, 130.0];

/// An actor with the mannequin as its skeletal mesh. BeginPlay adds a pose
/// authoring component to it, sets the right hand's target and prints
/// whether the handle took it, then prints the nearest handle to that spot
/// (none yet: the rig is still loading). Event On Pose Handle Changed prints
/// the handle's name.
LuminaBlueprintDocument poseAuthoringBlueprint() {
  final components = [
    LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
    LuminaBlueprintComponent(
        id: 'mesh', name: 'Mesh', type: 'LuminaSkeletalMeshComponent', parentId: 'root', properties: {
      'skeletalMeshAsset': poseAuthoringMeshPath,
    }),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_pose_authoring');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('add_pose_authoring', 'add'),
    place('set_pose_handle_target', 'set', {'handle': 'hand_r', 'location': poseAuthoringHandTarget}),
    place('bool_to_string', 'set_text'),
    place('print_string', 'say_set'),
    place('find_nearest_pose_handle', 'nearest', {'location': poseAuthoringHandTarget, 'max_distance': 8.0}),
    place('print_string', 'say_nearest'),
    place('event_pose_handle_changed', 'changed'),
    place('print_string', 'say_changed'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'add', 'exec_in'),
    wire('add', 'exec_out', 'set', 'exec_in'),
    wire('set', 'exec_out', 'say_set', 'exec_in'),
    wire('set', 'return_value', 'set_text', 'in_bool'),
    wire('set_text', 'return_value', 'say_set', 'in_string'),
    wire('say_set', 'exec_out', 'say_nearest', 'exec_in'),
    wire('nearest', 'handle', 'say_nearest', 'in_string'),
    wire('changed', 'exec_out', 'say_changed', 'exec_in'),
    wire('changed', 'handle', 'say_changed', 'in_string'),
  ]);
  return doc;
}
