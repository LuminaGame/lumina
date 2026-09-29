import 'package:lumina/lumina.dart';

/// Engine nodes parity fixture: a Character Blueprint that reads the engine
/// stats, traces along its look direction, queries the world, drives the
/// view target, spawns / tags / scales / times out an actor, and answers
/// every actor event, so the VM and the generated Dart are compared trace
/// for trace.
LuminaBlueprintDocument engineNodesBlueprint() {
  var wires = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wires++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  const variables = [
    LuminaBlueprintVariable(name: 'Spawned', typeName: 'Actor:LuminaActor'),
  ];
  final components = [
    LuminaBlueprintComponent(id: 'capsule', name: 'CapsuleComponent', type: 'LuminaCapsuleComponent'),
    LuminaBlueprintComponent(
        id: 'boom', name: 'CameraBoom', type: 'LuminaSpringArmComponent', parentId: 'capsule', properties: {'targetArmLength': 400.0}),
    LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', variables: [...variables], components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_engine_nodes');
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);

  /// A pure node whose output feeds a conversion then a Print String.
  void printed(String node, String outPin, String convert, String inPin, String label, {Map<String, dynamic>? convertLiterals}) {
    doc.eventGraph.nodes.addAll([p(convert, '${node}_text', convertLiterals), p('print_string', 'say_$node')]);
    doc.eventGraph.wires.addAll([
      w(node, outPin, '${node}_text', inPin),
      w('${node}_text', 'return_value', 'say_$node', 'in_string'),
    ]);
  }

  doc.eventGraph.nodes.addAll([
    p('event_beginplay', 'begin'),
    p('sequence', 'seq')
      ..outputs.add(const LuminaBlueprintPin(id: 'then_2', name: 'Then 2', type: LuminaPinType.exec, isOutput: true)),
    // Engine.
    p('get_frame_number', 'frame'),
    p('get_platform_name', 'platform'),
    p('print_string', 'say_platform'),
    p('set_time_dilation', 'dilate', {'time_dilation': 1.0}),
    // Spawn, tag, scale, distance, bounds, life span.
    p('spawn_actor_from_class', 'spawn', {
      'class': 'Actor:LuminaActor',
      'spawn_transform': {'location': [100.0, 0.0, 0.0], 'rotation': [0.0, 0.0, 0.0], 'scale': [1.0, 1.0, 1.0]},
    }),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_spawned', {'variable': 'Spawned'}),
    p('add_tag', 'tag', {'tag': 'Marker'}),
    p('actor_has_tag', 'has_tag', {'tag': 'Marker'}),
    p('set_actor_scale_3d', 'scale', {'new_scale_3d': [2.0, 2.0, 2.0]}),
    p('get_actor_scale_3d', 'scale_of'),
    p('get_distance_to', 'dist'),
    p('get_horizontal_distance_to', 'hdist'),
    p('get_actor_forward_vector', 'fwd'),
    p('get_actor_bounds', 'bounds'),
    p('set_life_span', 'life', {'in_life_span': 0.25}),
    p('get_owner', 'owner_of'),
    p('get_display_name', 'owner_name'),
    p('print_string', 'say_owner'),
    // View target and camera.
    p('set_view_target_with_blend', 'view', {'blend_time': 0.0}),
    p('get_view_target', 'vt'),
    p('get_display_name', 'vt_name'),
    p('print_string', 'say_vt'),
    p('get_camera_location', 'cam_loc'),
    p('get_look_forward_direction', 'look'),
    p('get_actor_eyes_view_point', 'eyes'),
    // Damage to self: Event AnyDamage answers.
    p('apply_damage', 'hurt', {'base_damage': 10.0}),
    // Trace and queries.
    p('line_trace_forward', 'trace', {'distance': 500.0, 'draw_debug': true}),
    p('branch', 'if_hit'),
    p('break_hit_result', 'hit'),
    p('print_string', 'say_miss', {'in_string': 'miss'}),
    p('get_actors_in_view_cone', 'cone', {'class': 'Actor:LuminaActor', 'distance': 1000.0, 'cone_angle': 60.0}),
    p('array_length', 'cone_n'),
    p('get_all_actors_of_class', 'all', {'class': 'Actor:LuminaActor'}),
    p('array_length', 'all_n'),
    p('is_hidden', 'hidden'),
    // Tick: frame rate, delta, the spawned actor's fate.
    p('event_tick', 'tick'),
    p('sequence', 'tick_seq'),
    p('get_frame_rate', 'fps'),
    p('round', 'fps_round'),
    p('get_world_delta_seconds', 'delta'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'spawned', {'variable': 'Spawned'}),
    p('is_actor_being_destroyed', 'dying'),
    // Events.
    p('event_end_play', 'end'),
    p('append', 'end_text', {'a': 'end '}),
    p('print_string', 'say_end'),
    p('event_destroyed', 'destroyed'),
    p('print_string', 'say_destroyed', {'in_string': 'destroyed'}),
    p('event_any_damage', 'damaged'),
    p('float_to_string', 'damage_text', {'decimals': 1}),
    p('print_string', 'say_damage'),
    p('event_take_point_damage', 'point'),
    p('vector_to_string', 'point_text'),
    p('print_string', 'say_point'),
    p('event_actor_begin_overlap', 'enter'),
    p('get_display_name', 'enter_name'),
    p('print_string', 'say_enter'),
    p('event_actor_end_overlap', 'leave'),
    p('print_string', 'say_leave', {'in_string': 'left'}),
    p('event_begin_overlap', 'comp_enter'),
    p('get_class_name', 'comp_class'),
    p('print_string', 'say_comp'),
    p('event_hit', 'hit_event'),
    p('break_hit_result', 'hit_parts'),
    p('get_display_name', 'hit_name'),
    p('print_string', 'say_hit'),
  ]);
  printed('frame', 'return_value', 'int_to_string', 'in_int', 'frame');
  printed('has_tag', 'return_value', 'bool_to_string', 'in_bool', 'tag');
  printed('scale_of', 'return_value', 'vector_to_string', 'in_vec', 'scale');
  printed('dist', 'return_value', 'float_to_string', 'in_float', 'dist', convertLiterals: {'decimals': 1});
  printed('hdist', 'return_value', 'float_to_string', 'in_float', 'hdist', convertLiterals: {'decimals': 1});
  printed('fwd', 'return_value', 'vector_to_string', 'in_vec', 'fwd');
  printed('bounds', 'origin', 'vector_to_string', 'in_vec', 'bounds');
  printed('cam_loc', 'return_value', 'vector_to_string', 'in_vec', 'cam');
  printed('look', 'return_value', 'vector_to_string', 'in_vec', 'look');
  printed('eyes', 'location', 'vector_to_string', 'in_vec', 'eyes');
  printed('hit', 'distance', 'float_to_string', 'in_float', 'hit', convertLiterals: {'decimals': 0});
  printed('cone_n', 'return_value', 'int_to_string', 'in_int', 'cone');
  printed('all_n', 'return_value', 'int_to_string', 'in_int', 'all');
  printed('hidden', 'return_value', 'bool_to_string', 'in_bool', 'hidden');
  printed('fps_round', 'return_value', 'int_to_string', 'in_int', 'fps');
  printed('delta', 'return_value', 'float_to_string', 'in_float', 'delta', convertLiterals: {'decimals': 3});
  printed('dying', 'return_value', 'bool_to_string', 'in_bool', 'dying');
  doc.eventGraph.wires.addAll([
    w('begin', 'exec_out', 'seq', 'exec_in'),
    // then_0: engine and spawn chain.
    w('seq', 'then_0', 'say_frame', 'exec_in'),
    w('say_frame', 'exec_out', 'say_platform', 'exec_in'),
    w('platform', 'return_value', 'say_platform', 'in_string'),
    w('say_platform', 'exec_out', 'dilate', 'exec_in'),
    w('dilate', 'exec_out', 'spawn', 'exec_in'),
    w('spawn', 'exec_out', 'set_spawned', 'exec_in'),
    w('spawn', 'return_value', 'set_spawned', 'value'),
    w('set_spawned', 'exec_out', 'tag', 'exec_in'),
    w('set_spawned', 'value', 'tag', 'target'),
    w('tag', 'exec_out', 'say_has_tag', 'exec_in'),
    w('set_spawned', 'value', 'has_tag', 'target'),
    w('say_has_tag', 'exec_out', 'scale', 'exec_in'),
    w('set_spawned', 'value', 'scale', 'target'),
    w('scale', 'exec_out', 'say_scale_of', 'exec_in'),
    w('set_spawned', 'value', 'scale_of', 'target'),
    w('say_scale_of', 'exec_out', 'say_dist', 'exec_in'),
    w('set_spawned', 'value', 'dist', 'other_actor'),
    w('say_dist', 'exec_out', 'say_hdist', 'exec_in'),
    w('set_spawned', 'value', 'hdist', 'other_actor'),
    w('say_hdist', 'exec_out', 'say_fwd', 'exec_in'),
    w('say_fwd', 'exec_out', 'say_bounds', 'exec_in'),
    w('say_bounds', 'exec_out', 'life', 'exec_in'),
    w('set_spawned', 'value', 'life', 'target'),
    w('life', 'exec_out', 'say_owner', 'exec_in'),
    w('set_spawned', 'value', 'owner_of', 'target'),
    w('owner_of', 'return_value', 'owner_name', 'object'),
    w('owner_name', 'return_value', 'say_owner', 'in_string'),
    // then_1: view target, camera, damage.
    w('seq', 'then_1', 'view', 'exec_in'),
    w('view', 'exec_out', 'say_vt', 'exec_in'),
    w('vt', 'return_value', 'vt_name', 'object'),
    w('vt_name', 'return_value', 'say_vt', 'in_string'),
    w('say_vt', 'exec_out', 'say_cam_loc', 'exec_in'),
    w('say_cam_loc', 'exec_out', 'say_look', 'exec_in'),
    w('say_look', 'exec_out', 'say_eyes', 'exec_in'),
    w('say_eyes', 'exec_out', 'hurt', 'exec_in'),
    // then_2: trace and queries.
    w('seq', 'then_2', 'trace', 'exec_in'),
    w('trace', 'exec_out', 'if_hit', 'exec_in'),
    w('trace', 'return_value', 'if_hit', 'condition'),
    w('trace', 'out_hit', 'hit', 'hit'),
    w('if_hit', 'true_out', 'say_hit', 'exec_in'),
    w('if_hit', 'false_out', 'say_miss', 'exec_in'),
    w('say_hit', 'exec_out', 'say_cone_n', 'exec_in'),
    w('say_miss', 'exec_out', 'say_cone_n', 'exec_in'),
    w('cone', 'return_value', 'cone_n', 'target_array'),
    w('say_cone_n', 'exec_out', 'say_all_n', 'exec_in'),
    w('all', 'return_value', 'all_n', 'target_array'),
    w('say_all_n', 'exec_out', 'say_hidden', 'exec_in'),
    // Tick.
    w('tick', 'exec_tick_out', 'tick_seq', 'exec_in'),
    w('tick_seq', 'then_0', 'say_fps_round', 'exec_in'),
    w('fps', 'return_value', 'fps_round', 'a'),
    w('tick_seq', 'then_1', 'say_delta', 'exec_in'),
    w('say_delta', 'exec_out', 'say_dying', 'exec_in'),
    w('spawned', 'value', 'dying', 'target'),
    // Events.
    w('end', 'exec_out', 'say_end', 'exec_in'),
    w('end', 'end_play_reason', 'end_text', 'b'),
    w('end_text', 'return_value', 'say_end', 'in_string'),
    w('destroyed', 'exec_out', 'say_destroyed', 'exec_in'),
    w('damaged', 'exec_out', 'say_damage', 'exec_in'),
    w('damaged', 'damage', 'damage_text', 'in_float'),
    w('damage_text', 'return_value', 'say_damage', 'in_string'),
    w('point', 'exec_out', 'say_point', 'exec_in'),
    w('point', 'hit_location', 'point_text', 'in_vec'),
    w('point_text', 'return_value', 'say_point', 'in_string'),
    w('enter', 'exec_out', 'say_enter', 'exec_in'),
    w('enter', 'other_actor', 'enter_name', 'object'),
    w('enter_name', 'return_value', 'say_enter', 'in_string'),
    w('leave', 'exec_out', 'say_leave', 'exec_in'),
    w('comp_enter', 'exec_out', 'say_comp', 'exec_in'),
    w('comp_enter', 'other_comp', 'comp_class', 'object'),
    w('comp_class', 'return_value', 'say_comp', 'in_string'),
    w('hit_event', 'exec_out', 'say_hit_event', 'exec_in'),
    w('hit_event', 'hit', 'hit_parts', 'hit'),
    w('hit_parts', 'hit_actor', 'hit_name', 'object'),
    w('hit_name', 'return_value', 'say_hit_event', 'in_string'),
  ]);
  // The Event Hit print is named apart from the trace's `say_hit`.
  doc.eventGraph.nodes.add(p('print_string', 'say_hit_event'));
  doc.eventGraph.nodes.removeWhere((n) => n.id == 'say_hit');
  doc.eventGraph.nodes.add(p('print_string', 'say_hit'));
  return doc;
}
