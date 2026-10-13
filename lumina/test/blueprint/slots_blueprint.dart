import 'package:lumina/lumina.dart';

/// A character Blueprint with three slots (Body leading, an empty Hair and
/// an empty Torso following it). BeginPlay prints how many slots there are,
/// fills Hair (printing whether the slot exists and its mesh), clears it
/// (printing again), tries a slot that does not exist, and fits a garment
/// into Torso.
LuminaBlueprintDocument slotsBlueprint() {
  LuminaBlueprintComponent slot(String id, String name, String mesh, {String? parent, String? from}) =>
      LuminaBlueprintComponent(
        id: id,
        name: name,
        type: 'LuminaSkeletalMeshComponent',
        parentId: parent,
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': mesh, 'slot': name, 'poseFrom': ?from},
      );
  final components = [
    LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent', isSceneComponent: true),
    slot('body', 'Body', 'contents/meshes/skeletal/SK_Hero_Body.lmas', parent: 'root'),
    slot('hair', 'Hair', '', parent: 'body', from: 'body'),
    slot('torso', 'Torso', '', parent: 'body', from: 'body'),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_slots');
  LuminaBlueprintNode place(String nodeId, String id, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(nodeId, nodeId: id, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('get_slots', 'slots'),
    place('array_length', 'count', {'type': 'string'}),
    place('int_to_string', 'count_text'),
    place('print_string', 'say_count'),
    place('set_slot_mesh', 'fill', {'slot': 'Hair', 'mesh': 'contents/meshes/skeletal/SK_Hero_Hair.lmas'}),
    place('bool_to_string', 'fill_text'),
    place('print_string', 'say_fill'),
    place('get_slot_mesh', 'hair_mesh', {'slot': 'Hair'}),
    place('print_string', 'say_hair'),
    place('clear_slot', 'empty', {'slot': 'Hair'}),
    place('bool_to_string', 'empty_text'),
    place('print_string', 'say_empty'),
    place('get_slot_mesh', 'hair_after', {'slot': 'Hair'}),
    place('print_string', 'say_after'),
    place('set_slot_mesh', 'missing', {'slot': 'Cape', 'mesh': 'contents/meshes/skeletal/SK_Cape.lmas'}),
    place('bool_to_string', 'missing_text'),
    place('print_string', 'say_missing'),
    place('fit_garment', 'fit', {'slot': 'Torso', 'garment': 'contents/characters/G_Shirt.lmas'}),
    place('bool_to_string', 'fit_text'),
    place('print_string', 'say_fit'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'say_count', 'exec_in'),
    wire('slots', 'return_value', 'count', 'target_array'),
    wire('count', 'return_value', 'count_text', 'in_int'),
    wire('count_text', 'return_value', 'say_count', 'in_string'),
    wire('say_count', 'exec_out', 'fill', 'exec_in'),
    wire('fill', 'exec_out', 'say_fill', 'exec_in'),
    wire('fill', 'return_value', 'fill_text', 'in_bool'),
    wire('fill_text', 'return_value', 'say_fill', 'in_string'),
    wire('say_fill', 'exec_out', 'say_hair', 'exec_in'),
    wire('hair_mesh', 'return_value', 'say_hair', 'in_string'),
    wire('say_hair', 'exec_out', 'empty', 'exec_in'),
    wire('empty', 'exec_out', 'say_empty', 'exec_in'),
    wire('empty', 'return_value', 'empty_text', 'in_bool'),
    wire('empty_text', 'return_value', 'say_empty', 'in_string'),
    wire('say_empty', 'exec_out', 'say_after', 'exec_in'),
    wire('hair_after', 'return_value', 'say_after', 'in_string'),
    wire('say_after', 'exec_out', 'missing', 'exec_in'),
    wire('missing', 'exec_out', 'say_missing', 'exec_in'),
    wire('missing', 'return_value', 'missing_text', 'in_bool'),
    wire('missing_text', 'return_value', 'say_missing', 'in_string'),
    wire('say_missing', 'exec_out', 'fit', 'exec_in'),
    wire('fit', 'exec_out', 'say_fit', 'exec_in'),
    wire('fit', 'return_value', 'fit_text', 'in_bool'),
    wire('fit_text', 'return_value', 'say_fit', 'in_string'),
  ]);
  return doc;
}
