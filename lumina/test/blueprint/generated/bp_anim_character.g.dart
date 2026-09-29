// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_anim_character.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import 'abp_character.g.dart';

class BpAnimCharacter extends LuminaCharacter with LuminaBlueprintRuntime {
  BpAnimCharacter({super.key, super.location, super.rotation}) {
    bUseControllerRotationYaw = true;
    baseEyeHeight = 70.0;
    blueprintComponentTree = _components;
    blueprintAnimClasses = _animBlueprints;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components, animBlueprints: _animBlueprints);
  }

  @override
  String get blueprintClassName => 'bp_anim_character';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'capsule',
      name: 'CapsuleComponent',
      type: 'LuminaCapsuleComponent',
      parentId: null,
      properties: <String, dynamic>{'capsuleRadius': 35.0, 'capsuleHalfHeight': 90.0},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'boom',
      name: 'CameraBoom',
      type: 'LuminaSpringArmComponent',
      parentId: 'capsule',
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, 60.0], 'targetArmLength': 350.0, 'usePawnControlRotation': true, 'enableCameraLag': true, 'cameraLagSpeed': 12.0, 'enableCameraRotationLag': true, 'cameraRotationLagSpeed': 14.0, 'doCollisionTest': true, 'probeSize': 25.0},
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
    LuminaBlueprintComponent(
      id: 'movement',
      name: 'CharacterMovement',
      type: 'LuminaCharacterMovementComponent',
      parentId: null,
      properties: <String, dynamic>{'maxWalkSpeed': 300.0, 'jumpZVelocity': 500.0, 'airControl': 0.35, 'jumpCutMultiplier': 1.0},
      isSceneComponent: false,
    ),
    LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: <String, dynamic>{'skeletalMeshAsset': 'assets/templates/third_person/SKM_Superhero_Female.glb', 'location': <dynamic>[0.0, 0.0, -90.0], 'animMode': 'Use Animation Blueprint', 'animClass': 'contents/animations/SKM_Superhero_Female/ABP_Character.lmas'},
      isSceneComponent: true,
    ),
  ];

  /// The Animation Blueprints this Blueprint's meshes name as their Anim Class.
  static LuminaAnimBlueprintFactory? _animBlueprints(String animClass) => switch (animClass) {
        'contents/animations/SKM_Superhero_Female/ABP_Character.lmas' => AbpCharacter.create,
        _ => null,
      };

  double lookSensitivity = 0.15;

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'DashFinished':
        _onDash_done(); return const {};
      default:
        return super.callBlueprint(name, args);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _bindInput();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  @override
  void possessedBy(LuminaController newController) {
    super.possessedBy(newController);
    _bindInput();
  }

  @override
  void unpossessed() {
    unbindBlueprintInput();
    super.unpossessed();
  }

  void _bindInput() => bindBlueprintInput([
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Move', valueType: InputValueType.axis2D), TriggerState.triggered, (value) => _onMoveTriggered(value.asAxis2D)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Look', valueType: InputValueType.axis2D), TriggerState.triggered, (value) => _onLookTriggered(value.asAxis2D)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Jump', valueType: InputValueType.digitalBool), TriggerState.started, (value) => _onJump_inputStarted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Jump', valueType: InputValueType.digitalBool), TriggerState.completed, (value) => _onJump_inputCompleted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Sprint', valueType: InputValueType.digitalBool), TriggerState.started, (value) => _onSprint_inputStarted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Sprint', valueType: InputValueType.digitalBool), TriggerState.canceled, (value) => _onSprint_inputCanceled(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Sprint', valueType: InputValueType.digitalBool), TriggerState.completed, (value) => _onSprint_inputCompleted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Dash', valueType: InputValueType.digitalBool), TriggerState.started, (value) => _onDash_inputStarted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_FreeLook', valueType: InputValueType.digitalBool), TriggerState.started, (value) => _onFree_look_inputStarted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_FreeLook', valueType: InputValueType.digitalBool), TriggerState.canceled, (value) => _onFree_look_inputCanceled(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_FreeLook', valueType: InputValueType.digitalBool), TriggerState.completed, (value) => _onFree_look_inputCompleted(value.asBool)),
      ]);

  /// IA_Move Triggered (node move).
  void _onMoveTriggered(Vector2 actionValue) {
    final p0 = LuminaBlueprintFunctionLibrary.getActorRotation(this);
    if (trace != null) blueprintTrace('move', 'body', 'get_actor_rotation', {'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.breakRotator(p0);
    if (trace != null) blueprintTrace('move', 'body_parts', 'break_rotator', {'in_rot': p0, 'x': p1.x, 'y': p1.y, 'z': p1.z});
    final p2 = LuminaBlueprintFunctionLibrary.getControlRotation(this);
    if (trace != null) blueprintTrace('move', 'control', 'get_control_rotation', {'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.breakRotator(p2);
    if (trace != null) blueprintTrace('move', 'control_parts', 'break_rotator', {'in_rot': p2, 'x': p3.x, 'y': p3.y, 'z': p3.z});
    final p4 = LuminaBlueprintFunctionLibrary.isFreeLooking(this);
    if (trace != null) blueprintTrace('move', 'free_looking', 'is_free_looking', {'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.selectFloat(p1.z, p3.z, p4);
    if (trace != null) blueprintTrace('move', 'move_yaw', 'select_float', {'a': p1.z, 'b': p3.z, 'pick_a': p4, 'return_value': p5});
    final p6 = LuminaBlueprintFunctionLibrary.makeRotator(0.0, 0.0, p5);
    if (trace != null) blueprintTrace('move', 'yaw_only', 'make_rotator', {'x': 0.0, 'y': 0.0, 'z': p5, 'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.getForwardVector(p6);
    if (trace != null) blueprintTrace('move', 'forward', 'get_forward_vector', {'in_rot': p6, 'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.breakVector2D(actionValue);
    if (trace != null) blueprintTrace('move', 'move_axis', 'break_vector2d', {'in_vec': actionValue, 'x': p8.x, 'y': p8.y});
    LuminaBlueprintFunctionLibrary.addMovementInput(this, p7, p8.y, false);
    if (trace != null) blueprintTrace('move', 'move_forward', 'add_movement_input', {'world_dir': p7, 'scale_val': p8.y, 'force': false});
    final p9 = LuminaBlueprintFunctionLibrary.getActorRotation(this);
    if (trace != null) blueprintTrace('move', 'body', 'get_actor_rotation', {'return_value': p9});
    final p10 = LuminaBlueprintFunctionLibrary.breakRotator(p9);
    if (trace != null) blueprintTrace('move', 'body_parts', 'break_rotator', {'in_rot': p9, 'x': p10.x, 'y': p10.y, 'z': p10.z});
    final p11 = LuminaBlueprintFunctionLibrary.getControlRotation(this);
    if (trace != null) blueprintTrace('move', 'control', 'get_control_rotation', {'return_value': p11});
    final p12 = LuminaBlueprintFunctionLibrary.breakRotator(p11);
    if (trace != null) blueprintTrace('move', 'control_parts', 'break_rotator', {'in_rot': p11, 'x': p12.x, 'y': p12.y, 'z': p12.z});
    final p13 = LuminaBlueprintFunctionLibrary.isFreeLooking(this);
    if (trace != null) blueprintTrace('move', 'free_looking', 'is_free_looking', {'return_value': p13});
    final p14 = LuminaBlueprintFunctionLibrary.selectFloat(p10.z, p12.z, p13);
    if (trace != null) blueprintTrace('move', 'move_yaw', 'select_float', {'a': p10.z, 'b': p12.z, 'pick_a': p13, 'return_value': p14});
    final p15 = LuminaBlueprintFunctionLibrary.makeRotator(0.0, 0.0, p14);
    if (trace != null) blueprintTrace('move', 'yaw_only', 'make_rotator', {'x': 0.0, 'y': 0.0, 'z': p14, 'return_value': p15});
    final p16 = LuminaBlueprintFunctionLibrary.getRightVector(p15);
    if (trace != null) blueprintTrace('move', 'right', 'get_right_vector', {'in_rot': p15, 'return_value': p16});
    final p17 = LuminaBlueprintFunctionLibrary.breakVector2D(actionValue);
    if (trace != null) blueprintTrace('move', 'move_axis', 'break_vector2d', {'in_vec': actionValue, 'x': p17.x, 'y': p17.y});
    LuminaBlueprintFunctionLibrary.addMovementInput(this, p16, p17.x, false);
    if (trace != null) blueprintTrace('move', 'move_right', 'add_movement_input', {'world_dir': p16, 'scale_val': p17.x, 'force': false});
  }

  /// IA_Look Triggered (node look).
  void _onLookTriggered(Vector2 actionValue) {
    final p18 = LuminaBlueprintFunctionLibrary.breakVector2D(actionValue);
    if (trace != null) blueprintTrace('look', 'look_axis', 'break_vector2d', {'in_vec': actionValue, 'x': p18.x, 'y': p18.y});
    final p19 = lookSensitivity;
    if (trace != null) blueprintTrace('look', 'sensitivity', 'variable_get', {'value': p19});
    final p20 = LuminaBlueprintFunctionLibrary.floatMultiply(p18.x, p19);
    if (trace != null) blueprintTrace('look', 'yaw_scaled', 'float_multiply', {'a': p18.x, 'b': p19, 'return_value': p20});
    LuminaBlueprintFunctionLibrary.addControllerYawInput(this, p20);
    if (trace != null) blueprintTrace('look', 'yaw', 'add_controller_yaw_input', {'val': p20});
    final p21 = LuminaBlueprintFunctionLibrary.breakVector2D(actionValue);
    if (trace != null) blueprintTrace('look', 'look_axis', 'break_vector2d', {'in_vec': actionValue, 'x': p21.x, 'y': p21.y});
    final p22 = lookSensitivity;
    if (trace != null) blueprintTrace('look', 'sensitivity', 'variable_get', {'value': p22});
    final p23 = LuminaBlueprintFunctionLibrary.floatMultiply(p21.y, p22);
    if (trace != null) blueprintTrace('look', 'pitch_scaled', 'float_multiply', {'a': p21.y, 'b': p22, 'return_value': p23});
    LuminaBlueprintFunctionLibrary.addControllerPitchInput(this, p23);
    if (trace != null) blueprintTrace('look', 'pitch', 'add_controller_pitch_input', {'val': p23});
  }

  /// IA_Jump Started (node jump_input).
  void _onJump_inputStarted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.jump(this);
    if (trace != null) blueprintTrace('jump_input', 'jump', 'jump', {});
  }

  /// IA_Jump Completed (node jump_input).
  void _onJump_inputCompleted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.stopJumping(this);
    if (trace != null) blueprintTrace('jump_input', 'stop_jumping', 'stop_jumping', {});
  }

  /// IA_Sprint Started (node sprint_input).
  void _onSprint_inputStarted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setMaxWalkSpeed(this, null, 480.0);
    if (trace != null) blueprintTrace('sprint_input', 'sprint_speed', 'set_max_walk_speed', {'target': null, 'max_walk_speed': 480.0});
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsSprinting', true);
    if (trace != null) blueprintTrace('sprint_input', 'start_sprint', 'set_anim_variable', {'name': 'IsSprinting', 'value': true});
  }

  /// IA_Sprint Canceled (node sprint_input).
  void _onSprint_inputCanceled(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setMaxWalkSpeed(this, null, 300.0);
    if (trace != null) blueprintTrace('sprint_input', 'walk_speed', 'set_max_walk_speed', {'target': null, 'max_walk_speed': 300.0});
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsSprinting', false);
    if (trace != null) blueprintTrace('sprint_input', 'end_sprint', 'set_anim_variable', {'name': 'IsSprinting', 'value': false});
  }

  /// IA_Sprint Completed (node sprint_input).
  void _onSprint_inputCompleted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setMaxWalkSpeed(this, null, 300.0);
    if (trace != null) blueprintTrace('sprint_input', 'walk_speed', 'set_max_walk_speed', {'target': null, 'max_walk_speed': 300.0});
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsSprinting', false);
    if (trace != null) blueprintTrace('sprint_input', 'end_sprint', 'set_anim_variable', {'name': 'IsSprinting', 'value': false});
  }

  /// IA_Dash Started (node dash_input).
  void _onDash_inputStarted(bool actionValue) {
    LuminaTimerHandle? odash_timer_return_value;
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsDashing', true);
    if (trace != null) blueprintTrace('dash_input', 'start_dash', 'set_anim_variable', {'name': 'IsDashing', 'value': true});
    final p24 = LuminaBlueprintFunctionLibrary.getActorRotation(this);
    if (trace != null) blueprintTrace('dash_input', 'body', 'get_actor_rotation', {'return_value': p24});
    final p25 = LuminaBlueprintFunctionLibrary.breakRotator(p24);
    if (trace != null) blueprintTrace('dash_input', 'body_parts', 'break_rotator', {'in_rot': p24, 'x': p25.x, 'y': p25.y, 'z': p25.z});
    final p26 = LuminaBlueprintFunctionLibrary.getControlRotation(this);
    if (trace != null) blueprintTrace('dash_input', 'control', 'get_control_rotation', {'return_value': p26});
    final p27 = LuminaBlueprintFunctionLibrary.breakRotator(p26);
    if (trace != null) blueprintTrace('dash_input', 'control_parts', 'break_rotator', {'in_rot': p26, 'x': p27.x, 'y': p27.y, 'z': p27.z});
    final p28 = LuminaBlueprintFunctionLibrary.isFreeLooking(this);
    if (trace != null) blueprintTrace('dash_input', 'free_looking', 'is_free_looking', {'return_value': p28});
    final p29 = LuminaBlueprintFunctionLibrary.selectFloat(p25.z, p27.z, p28);
    if (trace != null) blueprintTrace('dash_input', 'move_yaw', 'select_float', {'a': p25.z, 'b': p27.z, 'pick_a': p28, 'return_value': p29});
    final p30 = LuminaBlueprintFunctionLibrary.makeRotator(0.0, 0.0, p29);
    if (trace != null) blueprintTrace('dash_input', 'yaw_only', 'make_rotator', {'x': 0.0, 'y': 0.0, 'z': p29, 'return_value': p30});
    final p31 = LuminaBlueprintFunctionLibrary.getForwardVector(p30);
    if (trace != null) blueprintTrace('dash_input', 'forward', 'get_forward_vector', {'in_rot': p30, 'return_value': p31});
    final p32 = LuminaBlueprintFunctionLibrary.vectorScale(p31, 600.0);
    if (trace != null) blueprintTrace('dash_input', 'dash_velocity', 'vector_scale', {'a': p31, 'b': 600.0, 'return_value': p32});
    LuminaBlueprintFunctionLibrary.launchCharacter(this, null, p32, true, false);
    if (trace != null) blueprintTrace('dash_input', 'dash', 'launch_character', {'target': null, 'launch_velocity': p32, 'xy_override': true, 'z_override': false});
    final r33 = LuminaBlueprintFunctionLibrary.setTimerByEvent(this, LuminaBlueprintDelegate(this, 'DashFinished'), 0.4, false, -1.0);
    odash_timer_return_value = r33;
    if (trace != null) blueprintTrace('dash_input', 'dash_timer', 'set_timer_by_event', {'event': LuminaBlueprintDelegate(this, 'DashFinished'), 'time': 0.4, 'looping': false, 'initial_start_delay': -1.0, 'return_value': r33});
  }

  /// DashFinished (node dash_done).
  void _onDash_done() {
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsDashing', false);
    if (trace != null) blueprintTrace('dash_done', 'end_dash', 'set_anim_variable', {'name': 'IsDashing', 'value': false});
  }

  /// IA_FreeLook Started (node free_look_input).
  void _onFree_look_inputStarted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setFreeLook(this, true);
    if (trace != null) blueprintTrace('free_look_input', 'start_free_look', 'set_free_look', {'enabled': true});
  }

  /// IA_FreeLook Canceled (node free_look_input).
  void _onFree_look_inputCanceled(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setFreeLook(this, false);
    if (trace != null) blueprintTrace('free_look_input', 'end_free_look', 'set_free_look', {'enabled': false});
  }

  /// IA_FreeLook Completed (node free_look_input).
  void _onFree_look_inputCompleted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.setFreeLook(this, false);
    if (trace != null) blueprintTrace('free_look_input', 'end_free_look', 'set_free_look', {'enabled': false});
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    Map<String, Object?>? owall_trace_out_hit;
    bool? owall_trace_return_value;
    final r34 = LuminaBlueprintFunctionLibrary.lineTraceForward(this, 60.0, 'Visibility', false);
    owall_trace_out_hit = r34.outHit;
    owall_trace_return_value = r34.returnValue;
    if (trace != null) blueprintTrace('tick', 'wall_trace', 'line_trace_forward', {'distance': 60.0, 'channel': 'Visibility', 'draw_debug': false, 'out_hit': r34.outHit, 'return_value': r34.returnValue});
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'WallAhead', (owall_trace_return_value ?? false));
    if (trace != null) blueprintTrace('tick', 'set_wall_ahead', 'set_anim_variable', {'name': 'WallAhead', 'value': (owall_trace_return_value ?? false)});
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
