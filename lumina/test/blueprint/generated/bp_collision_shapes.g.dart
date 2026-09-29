// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_collision_shapes.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpCollisionShapes extends LuminaActor with LuminaBlueprintRuntime {
  BpCollisionShapes({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_collision_shapes';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root',
      name: 'DefaultSceneRoot',
      type: 'LuminaSceneComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'box',
      name: 'TriggerBox',
      type: 'LuminaBoxComponent',
      parentId: 'root',
      properties: <String, dynamic>{'boxExtent': <dynamic>[100.0, 100.0, 100.0], 'preset': 'Trigger', 'location': <dynamic>[0.0, 0.0, 100.0]},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'sphere',
      name: 'PickupSphere',
      type: 'LuminaSphereComponent',
      parentId: 'root',
      properties: <String, dynamic>{'radius': 60.0, 'preset': 'OverlapAll', 'location': <dynamic>[200.0, 0.0, 60.0]},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'pillar',
      name: 'Pillar',
      type: 'LuminaCylinderComponent',
      parentId: 'root',
      properties: <String, dynamic>{'radius': 30.0, 'halfHeight': 150.0, 'preset': 'BlockAll', 'location': <dynamic>[-200.0, 0.0, 150.0]},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'cone',
      name: 'Cone',
      type: 'LuminaConeComponent',
      parentId: 'root',
      properties: <String, dynamic>{'radius': 40.0, 'halfHeight': 60.0, 'preset': 'custom', 'objectType': 'worldDynamic', 'responses': <String, dynamic>{'worldStatic': 'block', 'worldDynamic': 'ignore', 'pawn': 'overlap'}, 'generateOverlapEvents': true, 'collisionEnabled': true},
      isSceneComponent: true,
    ),
  ];

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    final p0 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.getCollisionPreset(p0);
    if (trace != null) blueprintTrace('begin', 'box_preset', 'get_collision_preset', {'target': p0, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_box_preset', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p2});
    LuminaBlueprintFunctionLibrary.setCollisionResponseToChannel(p2, 'Pawn', 'Block');
    if (trace != null) blueprintTrace('begin', 'block_pawns', 'set_collision_response_to_channel', {'target': p2, 'channel': 'Pawn', 'response': 'Block'});
    final p3 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.getCollisionResponseToChannel(p3, 'Pawn');
    if (trace != null) blueprintTrace('begin', 'pawn_response', 'get_collision_response_to_channel', {'target': p3, 'channel': 'Pawn', 'return_value': p4});
    LuminaBlueprintFunctionLibrary.printString(this, p4, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_pawn_response', 'print_string', {'in_string': p4, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p4);
    final p5 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p5});
    final p6 = LuminaBlueprintFunctionLibrary.getCollisionPreset(p5);
    if (trace != null) blueprintTrace('begin', 'box_preset_after', 'get_collision_preset', {'target': p5, 'return_value': p6});
    LuminaBlueprintFunctionLibrary.printString(this, p6, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_box_preset_after', 'print_string', {'in_string': p6, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p6);
    final p7 = LuminaBlueprintFunctionLibrary.getComponent(this, 'PickupSphere');
    if (trace != null) blueprintTrace('begin', 'sphere', 'get_component', {'component': 'PickupSphere', 'return_value': p7});
    LuminaBlueprintFunctionLibrary.setSphereRadius(p7, 80.0);
    if (trace != null) blueprintTrace('begin', 'grow_sphere', 'set_sphere_radius', {'target': p7, 'radius': 80.0});
    final p8 = LuminaBlueprintFunctionLibrary.getComponent(this, 'PickupSphere');
    if (trace != null) blueprintTrace('begin', 'sphere', 'get_component', {'component': 'PickupSphere', 'return_value': p8});
    final p9 = LuminaBlueprintFunctionLibrary.getSphereRadius(p8);
    if (trace != null) blueprintTrace('begin', 'sphere_radius', 'get_sphere_radius', {'target': p8, 'return_value': p9});
    final p10 = LuminaBlueprintFunctionLibrary.floatToString(p9, 0);
    if (trace != null) blueprintTrace('begin', 'radius_text', 'float_to_string', {'in_float': p9, 'decimals': 0, 'return_value': p10});
    LuminaBlueprintFunctionLibrary.printString(this, p10, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_radius', 'print_string', {'in_string': p10, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p10);
    final p11 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p11});
    LuminaBlueprintFunctionLibrary.setBoxExtent(p11, Vector3(120.0, 130.0, 140.0));
    if (trace != null) blueprintTrace('begin', 'grow_box', 'set_box_extent', {'target': p11, 'box_extent': Vector3(120.0, 130.0, 140.0)});
    final p12 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('begin', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p12});
    final p13 = LuminaBlueprintFunctionLibrary.getBoxExtent(p12);
    if (trace != null) blueprintTrace('begin', 'box_extent', 'get_box_extent', {'target': p12, 'return_value': p13});
    final p14 = LuminaBlueprintFunctionLibrary.vectorToString(p13);
    if (trace != null) blueprintTrace('begin', 'extent_text', 'vector_to_string', {'in_vec': p13, 'return_value': p14});
    LuminaBlueprintFunctionLibrary.printString(this, p14, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_extent', 'print_string', {'in_string': p14, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p14);
    final p15 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Pillar');
    if (trace != null) blueprintTrace('begin', 'pillar', 'get_component', {'component': 'Pillar', 'return_value': p15});
    LuminaBlueprintFunctionLibrary.setCollisionPreset(p15, 'OverlapAllDynamic');
    if (trace != null) blueprintTrace('begin', 'pillar_overlaps', 'set_collision_preset', {'target': p15, 'preset': 'OverlapAllDynamic'});
    final p16 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Pillar');
    if (trace != null) blueprintTrace('begin', 'pillar', 'get_component', {'component': 'Pillar', 'return_value': p16});
    final p17 = LuminaBlueprintFunctionLibrary.getCollisionObjectType(p16);
    if (trace != null) blueprintTrace('begin', 'pillar_type', 'get_collision_object_type', {'target': p16, 'return_value': p17});
    LuminaBlueprintFunctionLibrary.printString(this, p17, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_pillar_type', 'print_string', {'in_string': p17, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p17);
    final p18 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Pillar');
    if (trace != null) blueprintTrace('begin', 'pillar', 'get_component', {'component': 'Pillar', 'return_value': p18});
    LuminaBlueprintFunctionLibrary.setGenerateOverlapEvents(p18, false);
    if (trace != null) blueprintTrace('begin', 'pillar_quiet', 'set_generate_overlap_events', {'target': p18, 'generate': false});
    final p19 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Cone');
    if (trace != null) blueprintTrace('begin', 'cone', 'get_component', {'component': 'Cone', 'return_value': p19});
    LuminaBlueprintFunctionLibrary.setCollisionObjectType(p19, 'Pawn');
    if (trace != null) blueprintTrace('begin', 'cone_pawn', 'set_collision_object_type', {'target': p19, 'object_type': 'Pawn'});
    final p20 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Cone');
    if (trace != null) blueprintTrace('begin', 'cone', 'get_component', {'component': 'Cone', 'return_value': p20});
    LuminaBlueprintFunctionLibrary.setCollisionResponseToAllChannels(p20, 'Ignore');
    if (trace != null) blueprintTrace('begin', 'cone_ignores', 'set_collision_response_to_all_channels', {'target': p20, 'response': 'Ignore'});
    final p21 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Cone');
    if (trace != null) blueprintTrace('begin', 'cone', 'get_component', {'component': 'Cone', 'return_value': p21});
    LuminaBlueprintFunctionLibrary.setCollisionEnabled(p21, 'NoCollision');
    if (trace != null) blueprintTrace('begin', 'cone_off', 'set_collision_enabled', {'target': p21, 'new_type': 'NoCollision'});
    final p22 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Cone');
    if (trace != null) blueprintTrace('begin', 'cone', 'get_component', {'component': 'Cone', 'return_value': p22});
    final p23 = LuminaBlueprintFunctionLibrary.getCollisionPreset(p22);
    if (trace != null) blueprintTrace('begin', 'cone_preset', 'get_collision_preset', {'target': p22, 'return_value': p23});
    LuminaBlueprintFunctionLibrary.printString(this, p23, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_cone_preset', 'print_string', {'in_string': p23, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p23);
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    final p24 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('tick', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p24});
    final p25 = LuminaBlueprintFunctionLibrary.getOverlappingComponents(p24);
    if (trace != null) blueprintTrace('tick', 'overlaps', 'get_overlapping_components', {'target': p24, 'return_value': p25});
    final p26 = LuminaBlueprintFunctionLibrary.arrayLength(p25);
    if (trace != null) blueprintTrace('tick', 'overlap_count', 'array_length', {'target_array': p25, 'return_value': p26});
    final p27 = LuminaBlueprintFunctionLibrary.intToString(p26);
    if (trace != null) blueprintTrace('tick', 'count_text', 'int_to_string', {'in_int': p26, 'return_value': p27});
    LuminaBlueprintFunctionLibrary.printString(this, p27, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_count', 'print_string', {'in_string': p27, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p27);
    final p28 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('tick', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p28});
    final p29 = LuminaBlueprintFunctionLibrary.getPlayerCharacter(this, 0);
    if (trace != null) blueprintTrace('tick', 'player', 'get_player_character', {'player_index': 0, 'return_value': p29});
    final p30 = LuminaBlueprintFunctionLibrary.isOverlappingActor(p28, p29);
    if (trace != null) blueprintTrace('tick', 'touching_player', 'is_overlapping_actor', {'target': p28, 'other': p29, 'return_value': p30});
    final p31 = LuminaBlueprintFunctionLibrary.boolToString(p30);
    if (trace != null) blueprintTrace('tick', 'touching_text', 'bool_to_string', {'in_bool': p30, 'return_value': p31});
    LuminaBlueprintFunctionLibrary.printString(this, p31, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_touching', 'print_string', {'in_string': p31, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p31);
    final p32 = LuminaBlueprintFunctionLibrary.getComponent(this, 'TriggerBox');
    if (trace != null) blueprintTrace('tick', 'box', 'get_component', {'component': 'TriggerBox', 'return_value': p32});
    final p33 = LuminaBlueprintFunctionLibrary.getOverlappingActors(p32, 'Actor:LuminaPawn');
    if (trace != null) blueprintTrace('tick', 'overlap_actors', 'get_overlapping_actors', {'target': p32, 'class': 'Actor:LuminaPawn', 'return_value': p33});
    final p34 = LuminaBlueprintFunctionLibrary.arrayLength(p33);
    if (trace != null) blueprintTrace('tick', 'actor_count', 'array_length', {'target_array': p33, 'return_value': p34});
    final p35 = LuminaBlueprintFunctionLibrary.intToString(p34);
    if (trace != null) blueprintTrace('tick', 'actor_count_text', 'int_to_string', {'in_int': p34, 'return_value': p35});
    LuminaBlueprintFunctionLibrary.printString(this, p35, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_actor_count', 'print_string', {'in_string': p35, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p35);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
