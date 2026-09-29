// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_engine_nodes.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpEngineNodes extends LuminaCharacter with LuminaBlueprintRuntime {
  BpEngineNodes({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_engine_nodes';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'capsule',
      name: 'CapsuleComponent',
      type: 'LuminaCapsuleComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'boom',
      name: 'CameraBoom',
      type: 'LuminaSpringArmComponent',
      parentId: 'capsule',
      properties: <String, dynamic>{'targetArmLength': 400.0},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'camera',
      name: 'FollowCamera',
      type: 'LuminaCameraComponent',
      parentId: 'boom',
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
  ];

  Object? spawned;

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

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    _onEnd(reason.displayName);
  }

  @override
  void onDestroyed() {
    super.onDestroyed();
    _onDestroyed();
  }

  @override
  void onAnyDamage(double damage, String damageType, LuminaController? instigator, LuminaActor? damageCauser) {
    super.onAnyDamage(damage, damageType, instigator, damageCauser);
    _onDamaged(damage, damageType, instigator, damageCauser);
  }

  @override
  void onPointDamage(double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType, LuminaController? instigator, LuminaActor? damageCauser) {
    super.onPointDamage(damage, hitLocation, hitFromDirection, damageType, instigator, damageCauser);
    final hitLocationA = LuminaBlueprintFunctionLibrary.toAuthoring(hitLocation);
    final hitFromDirectionA = LuminaBlueprintFunctionLibrary.toAuthoring(hitFromDirection);
    _onPoint(damage, hitLocationA, hitFromDirectionA, damageType, instigator, damageCauser);
  }

  @override
  void notifyActorBeginOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {
    super.notifyActorBeginOverlap(other, selfComponent, otherComponent);
    _onEnter(other);
    _onComp_enter(other, otherComponent);
  }

  @override
  void notifyActorEndOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {
    super.notifyActorEndOverlap(other, selfComponent, otherComponent);
    _onLeave(other);
  }

  @override
  void notifyActorHit(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent, HitResult hit) {
    super.notifyActorHit(other, selfComponent, otherComponent, hit);
    final hitOutputs = LuminaBlueprintFunctionLibrary.hitEventOutputs(this, other, hit);
    _onHit_event(hitOutputs);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    Object? ospawn_return_value;
    Object? oset_spawned_value;
    double? ohurt_return_value;
    Map<String, Object?>? otrace_out_hit;
    bool? otrace_return_value;
    if (trace != null) blueprintTrace('begin', 'seq', 'sequence', {});
    final p0 = LuminaBlueprintFunctionLibrary.getFrameNumber(this);
    if (trace != null) blueprintTrace('begin', 'frame', 'get_frame_number', {'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.intToString(p0);
    if (trace != null) blueprintTrace('begin', 'frame_text', 'int_to_string', {'in_int': p0, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_frame', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.getPlatformName();
    if (trace != null) blueprintTrace('begin', 'platform', 'get_platform_name', {'return_value': p2});
    LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_platform', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    LuminaBlueprintFunctionLibrary.setTimeDilation(this, 1.0);
    if (trace != null) blueprintTrace('begin', 'dilate', 'set_time_dilation', {'time_dilation': 1.0});
    final r3 = LuminaBlueprintFunctionLibrary.spawnActorFromClass(this, 'Actor:LuminaActor', <String, dynamic>{'location': <dynamic>[100.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0]}, 'Default');
    ospawn_return_value = r3;
    if (trace != null) blueprintTrace('begin', 'spawn', 'spawn_actor_from_class', {'class': 'Actor:LuminaActor', 'spawn_transform': <String, dynamic>{'location': <dynamic>[100.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0]}, 'collision_handling': 'Default', 'return_value': r3});
    spawned = ospawn_return_value;
    oset_spawned_value = ospawn_return_value;
    if (trace != null) blueprintTrace('begin', 'set_spawned', 'variable_set', {'value': ospawn_return_value});
    LuminaBlueprintFunctionLibrary.addTag(this, oset_spawned_value, 'Marker');
    if (trace != null) blueprintTrace('begin', 'tag', 'add_tag', {'target': oset_spawned_value, 'tag': 'Marker'});
    final p4 = LuminaBlueprintFunctionLibrary.actorHasTag(this, oset_spawned_value, 'Marker');
    if (trace != null) blueprintTrace('begin', 'has_tag', 'actor_has_tag', {'target': oset_spawned_value, 'tag': 'Marker', 'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.boolToString(p4);
    if (trace != null) blueprintTrace('begin', 'has_tag_text', 'bool_to_string', {'in_bool': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_has_tag', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    LuminaBlueprintFunctionLibrary.setActorScale3D(this, oset_spawned_value, Vector3(2.0, 2.0, 2.0));
    if (trace != null) blueprintTrace('begin', 'scale', 'set_actor_scale_3d', {'target': oset_spawned_value, 'new_scale_3d': Vector3(2.0, 2.0, 2.0)});
    final p6 = LuminaBlueprintFunctionLibrary.getActorScale3D(this, oset_spawned_value);
    if (trace != null) blueprintTrace('begin', 'scale_of', 'get_actor_scale_3d', {'target': oset_spawned_value, 'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.vectorToString(p6);
    if (trace != null) blueprintTrace('begin', 'scale_of_text', 'vector_to_string', {'in_vec': p6, 'return_value': p7});
    LuminaBlueprintFunctionLibrary.printString(this, p7, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_scale_of', 'print_string', {'in_string': p7, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p7);
    final p8 = LuminaBlueprintFunctionLibrary.getDistanceTo(this, null, oset_spawned_value);
    if (trace != null) blueprintTrace('begin', 'dist', 'get_distance_to', {'target': null, 'other_actor': oset_spawned_value, 'return_value': p8});
    final p9 = LuminaBlueprintFunctionLibrary.floatToString(p8, 1);
    if (trace != null) blueprintTrace('begin', 'dist_text', 'float_to_string', {'in_float': p8, 'decimals': 1, 'return_value': p9});
    LuminaBlueprintFunctionLibrary.printString(this, p9, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_dist', 'print_string', {'in_string': p9, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9);
    final p10 = LuminaBlueprintFunctionLibrary.getHorizontalDistanceTo(this, null, oset_spawned_value);
    if (trace != null) blueprintTrace('begin', 'hdist', 'get_horizontal_distance_to', {'target': null, 'other_actor': oset_spawned_value, 'return_value': p10});
    final p11 = LuminaBlueprintFunctionLibrary.floatToString(p10, 1);
    if (trace != null) blueprintTrace('begin', 'hdist_text', 'float_to_string', {'in_float': p10, 'decimals': 1, 'return_value': p11});
    LuminaBlueprintFunctionLibrary.printString(this, p11, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_hdist', 'print_string', {'in_string': p11, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p11);
    final p12 = LuminaBlueprintFunctionLibrary.getActorForwardVector(this, null);
    if (trace != null) blueprintTrace('begin', 'fwd', 'get_actor_forward_vector', {'target': null, 'return_value': p12});
    final p13 = LuminaBlueprintFunctionLibrary.vectorToString(p12);
    if (trace != null) blueprintTrace('begin', 'fwd_text', 'vector_to_string', {'in_vec': p12, 'return_value': p13});
    LuminaBlueprintFunctionLibrary.printString(this, p13, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_fwd', 'print_string', {'in_string': p13, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p13);
    final p14 = LuminaBlueprintFunctionLibrary.getActorBounds(this, null);
    if (trace != null) blueprintTrace('begin', 'bounds', 'get_actor_bounds', {'target': null, 'origin': p14.origin, 'box_extent': p14.boxExtent});
    final p15 = LuminaBlueprintFunctionLibrary.vectorToString(p14.origin);
    if (trace != null) blueprintTrace('begin', 'bounds_text', 'vector_to_string', {'in_vec': p14.origin, 'return_value': p15});
    LuminaBlueprintFunctionLibrary.printString(this, p15, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_bounds', 'print_string', {'in_string': p15, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p15);
    LuminaBlueprintFunctionLibrary.setLifeSpan(this, oset_spawned_value, 0.25);
    if (trace != null) blueprintTrace('begin', 'life', 'set_life_span', {'target': oset_spawned_value, 'in_life_span': 0.25});
    final p16 = LuminaBlueprintFunctionLibrary.getOwner(this, oset_spawned_value);
    if (trace != null) blueprintTrace('begin', 'owner_of', 'get_owner', {'target': oset_spawned_value, 'return_value': p16});
    final p17 = LuminaBlueprintFunctionLibrary.getDisplayName(p16);
    if (trace != null) blueprintTrace('begin', 'owner_name', 'get_display_name', {'object': p16, 'return_value': p17});
    LuminaBlueprintFunctionLibrary.printString(this, p17, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_owner', 'print_string', {'in_string': p17, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p17);
    LuminaBlueprintFunctionLibrary.setViewTargetWithBlend(this, null, 0.0, 'Linear', 2.0);
    if (trace != null) blueprintTrace('begin', 'view', 'set_view_target_with_blend', {'target': null, 'blend_time': 0.0, 'blend_func': 'Linear', 'blend_exp': 2.0});
    final p18 = LuminaBlueprintFunctionLibrary.getViewTarget(this);
    if (trace != null) blueprintTrace('begin', 'vt', 'get_view_target', {'return_value': p18});
    final p19 = LuminaBlueprintFunctionLibrary.getDisplayName(p18);
    if (trace != null) blueprintTrace('begin', 'vt_name', 'get_display_name', {'object': p18, 'return_value': p19});
    LuminaBlueprintFunctionLibrary.printString(this, p19, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_vt', 'print_string', {'in_string': p19, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p19);
    final p20 = LuminaBlueprintFunctionLibrary.getCameraLocation(this);
    if (trace != null) blueprintTrace('begin', 'cam_loc', 'get_camera_location', {'return_value': p20});
    final p21 = LuminaBlueprintFunctionLibrary.vectorToString(p20);
    if (trace != null) blueprintTrace('begin', 'cam_loc_text', 'vector_to_string', {'in_vec': p20, 'return_value': p21});
    LuminaBlueprintFunctionLibrary.printString(this, p21, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_cam_loc', 'print_string', {'in_string': p21, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p21);
    final p22 = LuminaBlueprintFunctionLibrary.getLookForwardDirection(this);
    if (trace != null) blueprintTrace('begin', 'look', 'get_look_forward_direction', {'return_value': p22});
    final p23 = LuminaBlueprintFunctionLibrary.vectorToString(p22);
    if (trace != null) blueprintTrace('begin', 'look_text', 'vector_to_string', {'in_vec': p22, 'return_value': p23});
    LuminaBlueprintFunctionLibrary.printString(this, p23, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_look', 'print_string', {'in_string': p23, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p23);
    final p24 = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(this);
    if (trace != null) blueprintTrace('begin', 'eyes', 'get_actor_eyes_view_point', {'location': p24.location, 'rotation': p24.rotation});
    final p25 = LuminaBlueprintFunctionLibrary.vectorToString(p24.location);
    if (trace != null) blueprintTrace('begin', 'eyes_text', 'vector_to_string', {'in_vec': p24.location, 'return_value': p25});
    LuminaBlueprintFunctionLibrary.printString(this, p25, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_eyes', 'print_string', {'in_string': p25, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p25);
    final r26 = LuminaBlueprintFunctionLibrary.applyDamage(this, null, 10.0, null, null, '');
    ohurt_return_value = r26;
    if (trace != null) blueprintTrace('begin', 'hurt', 'apply_damage', {'damaged_actor': null, 'base_damage': 10.0, 'event_instigator': null, 'damage_causer': null, 'damage_type_class': '', 'return_value': r26});
    final r27 = LuminaBlueprintFunctionLibrary.lineTraceForward(this, 500.0, 'Visibility', true);
    otrace_out_hit = r27.outHit;
    otrace_return_value = r27.returnValue;
    if (trace != null) blueprintTrace('begin', 'trace', 'line_trace_forward', {'distance': 500.0, 'channel': 'Visibility', 'draw_debug': true, 'out_hit': r27.outHit, 'return_value': r27.returnValue});
    if (trace != null) blueprintTrace('begin', 'if_hit', 'branch', {'condition': (otrace_return_value ?? false)});
    if ((otrace_return_value ?? false)) {
      final p28 = LuminaBlueprintFunctionLibrary.breakHitResult(otrace_out_hit);
      if (trace != null) blueprintTrace('begin', 'hit', 'break_hit_result', {'hit': otrace_out_hit, 'blocking_hit': p28.blockingHit, 'location': p28.location, 'impact_point': p28.impactPoint, 'impact_normal': p28.impactNormal, 'distance': p28.distance, 'hit_actor': p28.hitActor, 'hit_component': p28.hitComponent});
      final p29 = LuminaBlueprintFunctionLibrary.floatToString(p28.distance, 0);
      if (trace != null) blueprintTrace('begin', 'hit_text', 'float_to_string', {'in_float': p28.distance, 'decimals': 0, 'return_value': p29});
      LuminaBlueprintFunctionLibrary.printString(this, p29, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_hit', 'print_string', {'in_string': p29, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p29);
      final p30 = LuminaBlueprintFunctionLibrary.getActorsInViewCone(this, 'Actor:LuminaActor', 1000.0, 60.0);
      if (trace != null) blueprintTrace('begin', 'cone', 'get_actors_in_view_cone', {'class': 'Actor:LuminaActor', 'distance': 1000.0, 'cone_angle': 60.0, 'return_value': p30});
      final p31 = LuminaBlueprintFunctionLibrary.arrayLength(p30);
      if (trace != null) blueprintTrace('begin', 'cone_n', 'array_length', {'target_array': p30, 'return_value': p31});
      final p32 = LuminaBlueprintFunctionLibrary.intToString(p31);
      if (trace != null) blueprintTrace('begin', 'cone_n_text', 'int_to_string', {'in_int': p31, 'return_value': p32});
      LuminaBlueprintFunctionLibrary.printString(this, p32, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_cone_n', 'print_string', {'in_string': p32, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p32);
      final p33 = LuminaBlueprintFunctionLibrary.getAllActorsOfClass(this, 'Actor:LuminaActor');
      if (trace != null) blueprintTrace('begin', 'all', 'get_all_actors_of_class', {'class': 'Actor:LuminaActor', 'return_value': p33});
      final p34 = LuminaBlueprintFunctionLibrary.arrayLength(p33);
      if (trace != null) blueprintTrace('begin', 'all_n', 'array_length', {'target_array': p33, 'return_value': p34});
      final p35 = LuminaBlueprintFunctionLibrary.intToString(p34);
      if (trace != null) blueprintTrace('begin', 'all_n_text', 'int_to_string', {'in_int': p34, 'return_value': p35});
      LuminaBlueprintFunctionLibrary.printString(this, p35, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_all_n', 'print_string', {'in_string': p35, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p35);
      final p36 = LuminaBlueprintFunctionLibrary.isHidden(this, null);
      if (trace != null) blueprintTrace('begin', 'hidden', 'is_hidden', {'target': null, 'return_value': p36});
      final p37 = LuminaBlueprintFunctionLibrary.boolToString(p36);
      if (trace != null) blueprintTrace('begin', 'hidden_text', 'bool_to_string', {'in_bool': p36, 'return_value': p37});
      LuminaBlueprintFunctionLibrary.printString(this, p37, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_hidden', 'print_string', {'in_string': p37, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p37);
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'miss', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_miss', 'print_string', {'in_string': 'miss', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'miss');
      final p38 = LuminaBlueprintFunctionLibrary.getActorsInViewCone(this, 'Actor:LuminaActor', 1000.0, 60.0);
      if (trace != null) blueprintTrace('begin', 'cone', 'get_actors_in_view_cone', {'class': 'Actor:LuminaActor', 'distance': 1000.0, 'cone_angle': 60.0, 'return_value': p38});
      final p39 = LuminaBlueprintFunctionLibrary.arrayLength(p38);
      if (trace != null) blueprintTrace('begin', 'cone_n', 'array_length', {'target_array': p38, 'return_value': p39});
      final p40 = LuminaBlueprintFunctionLibrary.intToString(p39);
      if (trace != null) blueprintTrace('begin', 'cone_n_text', 'int_to_string', {'in_int': p39, 'return_value': p40});
      LuminaBlueprintFunctionLibrary.printString(this, p40, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_cone_n', 'print_string', {'in_string': p40, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p40);
      final p41 = LuminaBlueprintFunctionLibrary.getAllActorsOfClass(this, 'Actor:LuminaActor');
      if (trace != null) blueprintTrace('begin', 'all', 'get_all_actors_of_class', {'class': 'Actor:LuminaActor', 'return_value': p41});
      final p42 = LuminaBlueprintFunctionLibrary.arrayLength(p41);
      if (trace != null) blueprintTrace('begin', 'all_n', 'array_length', {'target_array': p41, 'return_value': p42});
      final p43 = LuminaBlueprintFunctionLibrary.intToString(p42);
      if (trace != null) blueprintTrace('begin', 'all_n_text', 'int_to_string', {'in_int': p42, 'return_value': p43});
      LuminaBlueprintFunctionLibrary.printString(this, p43, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_all_n', 'print_string', {'in_string': p43, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p43);
      final p44 = LuminaBlueprintFunctionLibrary.isHidden(this, null);
      if (trace != null) blueprintTrace('begin', 'hidden', 'is_hidden', {'target': null, 'return_value': p44});
      final p45 = LuminaBlueprintFunctionLibrary.boolToString(p44);
      if (trace != null) blueprintTrace('begin', 'hidden_text', 'bool_to_string', {'in_bool': p44, 'return_value': p45});
      LuminaBlueprintFunctionLibrary.printString(this, p45, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_hidden', 'print_string', {'in_string': p45, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p45);
    }
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    if (trace != null) blueprintTrace('tick', 'tick_seq', 'sequence', {});
    final p46 = LuminaBlueprintFunctionLibrary.getFrameRate(this);
    if (trace != null) blueprintTrace('tick', 'fps', 'get_frame_rate', {'return_value': p46});
    final p47 = LuminaBlueprintFunctionLibrary.round(p46);
    if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p46, 'return_value': p47});
    final p48 = LuminaBlueprintFunctionLibrary.intToString(p47);
    if (trace != null) blueprintTrace('tick', 'fps_round_text', 'int_to_string', {'in_int': p47, 'return_value': p48});
    LuminaBlueprintFunctionLibrary.printString(this, p48, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_fps_round', 'print_string', {'in_string': p48, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p48);
    final p49 = LuminaBlueprintFunctionLibrary.getWorldDeltaSeconds(this);
    if (trace != null) blueprintTrace('tick', 'delta', 'get_world_delta_seconds', {'return_value': p49});
    final p50 = LuminaBlueprintFunctionLibrary.floatToString(p49, 3);
    if (trace != null) blueprintTrace('tick', 'delta_text', 'float_to_string', {'in_float': p49, 'decimals': 3, 'return_value': p50});
    LuminaBlueprintFunctionLibrary.printString(this, p50, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_delta', 'print_string', {'in_string': p50, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p50);
    final p51 = spawned;
    if (trace != null) blueprintTrace('tick', 'spawned', 'variable_get', {'value': p51});
    final p52 = LuminaBlueprintFunctionLibrary.isActorBeingDestroyed(this, p51);
    if (trace != null) blueprintTrace('tick', 'dying', 'is_actor_being_destroyed', {'target': p51, 'return_value': p52});
    final p53 = LuminaBlueprintFunctionLibrary.boolToString(p52);
    if (trace != null) blueprintTrace('tick', 'dying_text', 'bool_to_string', {'in_bool': p52, 'return_value': p53});
    LuminaBlueprintFunctionLibrary.printString(this, p53, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_dying', 'print_string', {'in_string': p53, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p53);
  }

  /// Event EndPlay (node end).
  void _onEnd(String endPlayReason) {
    final p54 = LuminaBlueprintFunctionLibrary.append('end ', endPlayReason);
    if (trace != null) blueprintTrace('end', 'end_text', 'append', {'a': 'end ', 'b': endPlayReason, 'return_value': p54});
    LuminaBlueprintFunctionLibrary.printString(this, p54, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('end', 'say_end', 'print_string', {'in_string': p54, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p54);
  }

  /// Event Destroyed (node destroyed).
  void _onDestroyed() {
    LuminaBlueprintFunctionLibrary.printString(this, 'destroyed', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('destroyed', 'say_destroyed', 'print_string', {'in_string': 'destroyed', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'destroyed');
  }

  /// Event AnyDamage (node damaged).
  void _onDamaged(double damage, String damageType, Object? instigator, Object? damageCauser) {
    final p55 = LuminaBlueprintFunctionLibrary.floatToString(damage, 1);
    if (trace != null) blueprintTrace('damaged', 'damage_text', 'float_to_string', {'in_float': damage, 'decimals': 1, 'return_value': p55});
    LuminaBlueprintFunctionLibrary.printString(this, p55, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('damaged', 'say_damage', 'print_string', {'in_string': p55, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p55);
  }

  /// Event PointDamage (node point).
  void _onPoint(double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType, Object? instigator, Object? damageCauser) {
    final p56 = LuminaBlueprintFunctionLibrary.vectorToString(hitLocation);
    if (trace != null) blueprintTrace('point', 'point_text', 'vector_to_string', {'in_vec': hitLocation, 'return_value': p56});
    LuminaBlueprintFunctionLibrary.printString(this, p56, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('point', 'say_point', 'print_string', {'in_string': p56, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p56);
  }

  /// Event ActorBeginOverlap (node enter).
  void _onEnter(Object? other) {
    final p57 = LuminaBlueprintFunctionLibrary.getDisplayName(other);
    if (trace != null) blueprintTrace('enter', 'enter_name', 'get_display_name', {'object': other, 'return_value': p57});
    LuminaBlueprintFunctionLibrary.printString(this, p57, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('enter', 'say_enter', 'print_string', {'in_string': p57, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p57);
  }

  /// Event ActorEndOverlap (node leave).
  void _onLeave(Object? other) {
    LuminaBlueprintFunctionLibrary.printString(this, 'left', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('leave', 'say_leave', 'print_string', {'in_string': 'left', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'left');
  }

  /// OnComponentBeginOverlap (node comp_enter).
  void _onComp_enter(Object? other, Object? otherComponent) {
    final p58 = LuminaBlueprintFunctionLibrary.getClassName(otherComponent);
    if (trace != null) blueprintTrace('comp_enter', 'comp_class', 'get_class_name', {'object': otherComponent, 'return_value': p58});
    LuminaBlueprintFunctionLibrary.printString(this, p58, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('comp_enter', 'say_comp', 'print_string', {'in_string': p58, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p58);
  }

  /// Event Hit (node hit_event).
  void _onHit_event(Map<String, Object?> hitOutputs) {
    final p59 = LuminaBlueprintFunctionLibrary.breakHitResult(hitOutputs['hit']);
    if (trace != null) blueprintTrace('hit_event', 'hit_parts', 'break_hit_result', {'hit': hitOutputs['hit'], 'blocking_hit': p59.blockingHit, 'location': p59.location, 'impact_point': p59.impactPoint, 'impact_normal': p59.impactNormal, 'distance': p59.distance, 'hit_actor': p59.hitActor, 'hit_component': p59.hitComponent});
    final p60 = LuminaBlueprintFunctionLibrary.getDisplayName(p59.hitActor);
    if (trace != null) blueprintTrace('hit_event', 'hit_name', 'get_display_name', {'object': p59.hitActor, 'return_value': p60});
    LuminaBlueprintFunctionLibrary.printString(this, p60, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('hit_event', 'say_hit_event', 'print_string', {'in_string': p60, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p60);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
