// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_gameplay_nodes.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import 'abp_character.g.dart';

class BpGameplayNodes extends LuminaCharacter with LuminaBlueprintRuntime {
  BpGameplayNodes({super.key, super.location, super.rotation}) {
    bUseControllerRotationYaw = true;
    baseEyeHeight = 70.0;
    blueprintComponentTree = _components;
    blueprintAnimClasses = _animBlueprints;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components, animBlueprints: _animBlueprints);
  }

  @override
  String get blueprintClassName => 'bp_gameplay_nodes';

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
    LuminaBlueprintComponent(
      id: 'lamp',
      name: 'Lamp',
      type: 'LuminaPointLightComponent',
      parentId: 'capsule',
      properties: <String, dynamic>{'intensity': 800.0, 'location': <dynamic>[0.0, 0.0, 200.0]},
      isSceneComponent: true,
    ),
  ];

  /// The Animation Blueprints this Blueprint's meshes name as their Anim Class.
  static LuminaAnimBlueprintFactory? _animBlueprints(String animClass) => switch (animClass) {
        'contents/animations/SKM_Superhero_Female/ABP_Character.lmas' => AbpCharacter.create,
        _ => null,
      };

  double lookSensitivity = 0.15;
  Object? save;
  Object? voice;

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
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  @override
  void onMontageEnded(String montage, bool interrupted) {
    super.onMontageEnded(montage, interrupted);
    _onEnded(montage, interrupted);
  }

  @override
  void onAnimNotify(String notifyName) {
    super.onAnimNotify(notifyName);
    _onNotify(notifyName);
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

  /// Event BeginPlay (node begin).
  void _onBegin() {
    Object? ocreate_return_value;
    Object? oset_save_value;
    bool? osave_return_value;
    Object? oload_return_value;
    bool? odelete_return_value;
    Object? omusic_return_value;
    Object? oset_voice_value;
    double? owave_return_value;
    Object? osparks_return_value;
    if (trace != null) blueprintTrace('begin', 'seq', 'sequence', {});
    final p35 = LuminaBlueprintFunctionLibrary.getGameMode(this);
    if (trace != null) blueprintTrace('begin', 'mode', 'get_game_mode', {'return_value': p35});
    final p36 = LuminaBlueprintFunctionLibrary.isValid(p35);
    if (trace != null) blueprintTrace('begin', 'mode_valid', 'is_valid', {'input_object': p35, 'return_value': p36});
    final p37 = LuminaBlueprintFunctionLibrary.boolToString(p36);
    if (trace != null) blueprintTrace('begin', 'mode_valid_text', 'bool_to_string', {'in_bool': p36, 'return_value': p37});
    LuminaBlueprintFunctionLibrary.printString(this, p37, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_mode_valid', 'print_string', {'in_string': p37, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p37);
    final p38 = LuminaBlueprintFunctionLibrary.getCurrentLevelName(this);
    if (trace != null) blueprintTrace('begin', 'level', 'get_current_level_name', {'return_value': p38});
    LuminaBlueprintFunctionLibrary.printString(this, p38, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_level', 'print_string', {'in_string': p38, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p38);
    final p39 = LuminaBlueprintFunctionLibrary.getGameInstance(this);
    if (trace != null) blueprintTrace('begin', 'gi', 'get_game_instance', {'return_value': p39});
    final p40 = LuminaBlueprintFunctionLibrary.isValid(p39);
    if (trace != null) blueprintTrace('begin', 'gi_valid', 'is_valid', {'input_object': p39, 'return_value': p40});
    final p41 = LuminaBlueprintFunctionLibrary.boolToString(p40);
    if (trace != null) blueprintTrace('begin', 'gi_valid_text', 'bool_to_string', {'in_bool': p40, 'return_value': p41});
    LuminaBlueprintFunctionLibrary.printString(this, p41, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_gi_valid', 'print_string', {'in_string': p41, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p41);
    LuminaBlueprintFunctionLibrary.executeConsoleCommand(this, 'slomo 1');
    if (trace != null) blueprintTrace('begin', 'slomo', 'execute_console_command', {'command': 'slomo 1'});
    final p42 = LuminaBlueprintFunctionLibrary.isGamePaused(this);
    if (trace != null) blueprintTrace('begin', 'paused', 'is_game_paused', {'return_value': p42});
    final p43 = LuminaBlueprintFunctionLibrary.boolToString(p42);
    if (trace != null) blueprintTrace('begin', 'paused_text', 'bool_to_string', {'in_bool': p42, 'return_value': p43});
    LuminaBlueprintFunctionLibrary.printString(this, p43, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_paused', 'print_string', {'in_string': p43, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p43);
    final p44 = LuminaBlueprintFunctionLibrary.getGameTimeSinceCreation(this);
    if (trace != null) blueprintTrace('begin', 'age', 'get_game_time_since_creation', {'return_value': p44});
    final p45 = LuminaBlueprintFunctionLibrary.floatToString(p44, 1);
    if (trace != null) blueprintTrace('begin', 'age_text', 'float_to_string', {'in_float': p44, 'decimals': 1, 'return_value': p45});
    LuminaBlueprintFunctionLibrary.printString(this, p45, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_age', 'print_string', {'in_string': p45, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p45);
    final r46 = LuminaBlueprintFunctionLibrary.createSaveGameObject(this, 'SG_Parity');
    ocreate_return_value = r46;
    if (trace != null) blueprintTrace('begin', 'create', 'create_save_game_object', {'class': 'SG_Parity', 'return_value': r46});
    save = ocreate_return_value;
    oset_save_value = ocreate_return_value;
    if (trace != null) blueprintTrace('begin', 'set_save', 'variable_set', {'value': ocreate_return_value});
    LuminaBlueprintFunctionLibrary.setSaveField(this, oset_save_value, 'SG_Parity', 'Score', 5);
    if (trace != null) blueprintTrace('begin', 'set_score', 'set_save_field', {'target': oset_save_value, 'value': 5});
    LuminaBlueprintFunctionLibrary.setSaveField(this, oset_save_value, 'SG_Parity', 'Where', Vector3(1.0, 2.0, 3.0));
    if (trace != null) blueprintTrace('begin', 'set_where', 'set_save_field', {'target': oset_save_value, 'value': Vector3(1.0, 2.0, 3.0)});
    final p47 = LuminaBlueprintFunctionLibrary.getSaveField(oset_save_value, 'Score', 'SG_Parity');
    if (trace != null) blueprintTrace('begin', 'get_score', 'get_save_field', {'target': oset_save_value, 'return_value': p47});
    final t48 = p47 as int;
    final p49 = LuminaBlueprintFunctionLibrary.intToString(t48);
    if (trace != null) blueprintTrace('begin', 'get_score_text', 'int_to_string', {'in_int': t48, 'return_value': p49});
    LuminaBlueprintFunctionLibrary.printString(this, p49, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_get_score', 'print_string', {'in_string': p49, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p49);
    final r50 = LuminaBlueprintFunctionLibrary.saveGameToSlot(this, oset_save_value, 'parity', 0);
    osave_return_value = r50;
    if (trace != null) blueprintTrace('begin', 'save', 'save_game_to_slot', {'save_game_object': oset_save_value, 'slot_name': 'parity', 'user_index': 0, 'return_value': r50});
    final p51 = LuminaBlueprintFunctionLibrary.boolToString((osave_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'save_text', 'bool_to_string', {'in_bool': (osave_return_value ?? false), 'return_value': p51});
    LuminaBlueprintFunctionLibrary.printString(this, p51, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_save', 'print_string', {'in_string': p51, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p51);
    final r52 = LuminaBlueprintFunctionLibrary.loadGameFromSlot(this, 'parity', 0);
    oload_return_value = r52;
    if (trace != null) blueprintTrace('begin', 'load', 'load_game_from_slot', {'slot_name': 'parity', 'user_index': 0, 'return_value': r52});
    final p53 = LuminaBlueprintFunctionLibrary.getSaveField(oload_return_value, 'Where', 'SG_Parity');
    if (trace != null) blueprintTrace('begin', 'loaded_where', 'get_save_field', {'target': oload_return_value, 'return_value': p53});
    final t54 = p53 as Vector3;
    final p55 = LuminaBlueprintFunctionLibrary.vectorToString(t54);
    if (trace != null) blueprintTrace('begin', 'loaded_where_text', 'vector_to_string', {'in_vec': t54, 'return_value': p55});
    LuminaBlueprintFunctionLibrary.printString(this, p55, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_loaded_where', 'print_string', {'in_string': p55, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p55);
    final p56 = LuminaBlueprintFunctionLibrary.doesSaveGameExist(this, 'parity', 0);
    if (trace != null) blueprintTrace('begin', 'exists', 'does_save_game_exist', {'slot_name': 'parity', 'user_index': 0, 'return_value': p56});
    final p57 = LuminaBlueprintFunctionLibrary.boolToString(p56);
    if (trace != null) blueprintTrace('begin', 'exists_text', 'bool_to_string', {'in_bool': p56, 'return_value': p57});
    LuminaBlueprintFunctionLibrary.printString(this, p57, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_exists', 'print_string', {'in_string': p57, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p57);
    final r58 = LuminaBlueprintFunctionLibrary.deleteGameInSlot(this, 'parity', 0);
    odelete_return_value = r58;
    if (trace != null) blueprintTrace('begin', 'delete', 'delete_game_in_slot', {'slot_name': 'parity', 'user_index': 0, 'return_value': r58});
    final p59 = LuminaBlueprintFunctionLibrary.boolToString((odelete_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'delete_text', 'bool_to_string', {'in_bool': (odelete_return_value ?? false), 'return_value': p59});
    LuminaBlueprintFunctionLibrary.printString(this, p59, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_delete', 'print_string', {'in_string': p59, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p59);
    if (trace != null) blueprintTrace('begin', 'stream', 'load_stream_level', {'level_name': 'L_Nowhere', 'make_visible_after_load': true, 'should_block_on_load': false});
    LuminaBlueprintFunctionLibrary.loadStreamLevel(this, 'L_Nowhere', true, false, () => _resumeStreamFromBegin());
    final p62 = LuminaBlueprintFunctionLibrary.isInputKeyDown(this, 'W');
    if (trace != null) blueprintTrace('begin', 'w_down', 'is_input_key_down', {'key': 'W', 'return_value': p62});
    final p63 = LuminaBlueprintFunctionLibrary.boolToString(p62);
    if (trace != null) blueprintTrace('begin', 'w_down_text', 'bool_to_string', {'in_bool': p62, 'return_value': p63});
    LuminaBlueprintFunctionLibrary.printString(this, p63, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_w_down', 'print_string', {'in_string': p63, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p63);
    final p64 = LuminaBlueprintFunctionLibrary.getViewportSize(this);
    if (trace != null) blueprintTrace('begin', 'viewport', 'get_viewport_size', {'return_value': p64});
    final p65 = LuminaBlueprintFunctionLibrary.breakVector2D(p64);
    if (trace != null) blueprintTrace('begin', 'viewport_parts', 'break_vector2d', {'in_vec': p64, 'x': p65.x, 'y': p65.y});
    final p66 = LuminaBlueprintFunctionLibrary.floatToString(p65.x, 0);
    if (trace != null) blueprintTrace('begin', 'viewport_parts_text', 'float_to_string', {'in_float': p65.x, 'decimals': 0, 'return_value': p66});
    LuminaBlueprintFunctionLibrary.printString(this, p66, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_viewport_parts', 'print_string', {'in_string': p66, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p66);
    final p67 = LuminaBlueprintFunctionLibrary.projectWorldToScreen(this, Vector3(0.0, 500.0, 100.0));
    if (trace != null) blueprintTrace('begin', 'project', 'project_world_to_screen', {'world_location': Vector3(0.0, 500.0, 100.0), 'screen_position': p67.screenPosition, 'return_value': p67.returnValue});
    final p68 = LuminaBlueprintFunctionLibrary.boolToString(p67.returnValue);
    if (trace != null) blueprintTrace('begin', 'project_text', 'bool_to_string', {'in_bool': p67.returnValue, 'return_value': p68});
    LuminaBlueprintFunctionLibrary.printString(this, p68, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_project', 'print_string', {'in_string': p68, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p68);
    final p69 = LuminaBlueprintFunctionLibrary.getLastInputDevice(this);
    if (trace != null) blueprintTrace('begin', 'device', 'get_last_input_device', {'return_value': p69});
    LuminaBlueprintFunctionLibrary.printString(this, p69, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_device', 'print_string', {'in_string': p69, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p69);
    LuminaBlueprintFunctionLibrary.playSound2D(this, 'contents/audio/click.wav', 0.5, 1.0, 0.0);
    if (trace != null) blueprintTrace('begin', 'click', 'play_sound_2d', {'sound': 'contents/audio/click.wav', 'volume': 0.5, 'pitch': 1.0, 'start_time': 0.0});
    final r70 = LuminaBlueprintFunctionLibrary.spawnSound2D(this, 'contents/audio/music.wav', 1.0, 1.0, 0.0, false);
    omusic_return_value = r70;
    if (trace != null) blueprintTrace('begin', 'music', 'spawn_sound_2d', {'sound': 'contents/audio/music.wav', 'volume': 1.0, 'pitch': 1.0, 'start_time': 0.0, 'auto_destroy': false, 'return_value': r70});
    voice = omusic_return_value;
    oset_voice_value = omusic_return_value;
    if (trace != null) blueprintTrace('begin', 'set_voice', 'variable_set', {'value': omusic_return_value});
    final p71 = LuminaBlueprintFunctionLibrary.isSoundPlaying(this, oset_voice_value);
    if (trace != null) blueprintTrace('begin', 'playing', 'is_sound_playing', {'target': oset_voice_value, 'return_value': p71});
    final p72 = LuminaBlueprintFunctionLibrary.boolToString(p71);
    if (trace != null) blueprintTrace('begin', 'playing_text', 'bool_to_string', {'in_bool': p71, 'return_value': p72});
    LuminaBlueprintFunctionLibrary.printString(this, p72, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_playing', 'print_string', {'in_string': p72, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p72);
    LuminaBlueprintFunctionLibrary.setSoundVolume(this, oset_voice_value, 0.2);
    if (trace != null) blueprintTrace('begin', 'quiet', 'set_sound_volume', {'target': oset_voice_value, 'volume': 0.2});
    LuminaBlueprintFunctionLibrary.setSoundClassVolume(this, 'Music', 0.5);
    if (trace != null) blueprintTrace('begin', 'mix', 'set_sound_class_volume', {'sound_class': 'Music', 'volume': 0.5});
    final r73 = LuminaBlueprintFunctionLibrary.playAnimMontage(this, 'AM_Parity', 1.0, '');
    owave_return_value = r73;
    if (trace != null) blueprintTrace('begin', 'wave', 'play_anim_montage', {'montage': 'AM_Parity', 'play_rate': 1.0, 'start_section': '', 'return_value': r73});
    final p74 = LuminaBlueprintFunctionLibrary.floatToString((owave_return_value ?? 0.0), 1);
    if (trace != null) blueprintTrace('begin', 'wave_text', 'float_to_string', {'in_float': (owave_return_value ?? 0.0), 'decimals': 1, 'return_value': p74});
    LuminaBlueprintFunctionLibrary.printString(this, p74, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_wave', 'print_string', {'in_string': p74, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p74);
    final p75 = LuminaBlueprintFunctionLibrary.isPlayingMontage(this);
    if (trace != null) blueprintTrace('begin', 'waving', 'is_playing_montage', {'return_value': p75});
    final p76 = LuminaBlueprintFunctionLibrary.boolToString(p75);
    if (trace != null) blueprintTrace('begin', 'waving_text', 'bool_to_string', {'in_bool': p75, 'return_value': p76});
    LuminaBlueprintFunctionLibrary.printString(this, p76, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_waving', 'print_string', {'in_string': p76, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p76);
    final p77 = LuminaBlueprintFunctionLibrary.getCurrentMontage(this);
    if (trace != null) blueprintTrace('begin', 'montage_name', 'get_current_montage', {'return_value': p77});
    LuminaBlueprintFunctionLibrary.printString(this, p77, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_montage', 'print_string', {'in_string': p77, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p77);
    LuminaBlueprintFunctionLibrary.setAnimVariable(this, 'IsFalling', true);
    if (trace != null) blueprintTrace('begin', 'set_falling', 'set_anim_variable', {'name': 'IsFalling', 'value': true});
    final p78 = LuminaBlueprintFunctionLibrary.getAnimVariable(this, 'IsFalling');
    if (trace != null) blueprintTrace('begin', 'get_falling', 'get_anim_variable', {'name': 'IsFalling', 'return_value': p78});
    final t79 = p78 as bool;
    final p80 = LuminaBlueprintFunctionLibrary.boolToString(t79);
    if (trace != null) blueprintTrace('begin', 'get_falling_text', 'bool_to_string', {'in_bool': t79, 'return_value': p80});
    LuminaBlueprintFunctionLibrary.printString(this, p80, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_get_falling', 'print_string', {'in_string': p80, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p80);
    final p81 = LuminaBlueprintFunctionLibrary.getAnimInstance(this);
    if (trace != null) blueprintTrace('begin', 'abp', 'get_anim_instance', {'return_value': p81});
    final p82 = LuminaBlueprintFunctionLibrary.isValid(p81);
    if (trace != null) blueprintTrace('begin', 'abp_valid', 'is_valid', {'input_object': p81, 'return_value': p82});
    final p83 = LuminaBlueprintFunctionLibrary.boolToString(p82);
    if (trace != null) blueprintTrace('begin', 'abp_valid_text', 'bool_to_string', {'in_bool': p82, 'return_value': p83});
    LuminaBlueprintFunctionLibrary.printString(this, p83, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_abp_valid', 'print_string', {'in_string': p83, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p83);
    final r84 = LuminaBlueprintFunctionLibrary.spawnEmitterAtLocation(this, 'contents/fx/P_Parity.lmas', Vector3(0.0, 100.0, 0.0), const LuminaRotator(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), true);
    osparks_return_value = r84;
    if (trace != null) blueprintTrace('begin', 'sparks', 'spawn_emitter_at_location', {'emitter_template': 'contents/fx/P_Parity.lmas', 'location': Vector3(0.0, 100.0, 0.0), 'rotation': const LuminaRotator(0.0, 0.0, 0.0), 'scale': Vector3(1.0, 1.0, 1.0), 'auto_destroy': true, 'return_value': r84});
    final p85 = LuminaBlueprintFunctionLibrary.isValid(osparks_return_value);
    if (trace != null) blueprintTrace('begin', 'sparks_valid', 'is_valid', {'input_object': osparks_return_value, 'return_value': p85});
    final p86 = LuminaBlueprintFunctionLibrary.boolToString(p85);
    if (trace != null) blueprintTrace('begin', 'sparks_valid_text', 'bool_to_string', {'in_bool': p85, 'return_value': p86});
    LuminaBlueprintFunctionLibrary.printString(this, p86, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_sparks_valid', 'print_string', {'in_string': p86, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p86);
    LuminaBlueprintFunctionLibrary.setParticleParameter(this, osparks_return_value, 'SpawnRate', 0.0);
    if (trace != null) blueprintTrace('begin', 'sparks_rate', 'set_particle_parameter', {'target': osparks_return_value, 'parameter_name': 'SpawnRate', 'value': 0.0});
    LuminaBlueprintFunctionLibrary.deactivateParticleSystem(this, osparks_return_value);
    if (trace != null) blueprintTrace('begin', 'sparks_off', 'deactivate_particle_system', {'target': osparks_return_value});
    LuminaBlueprintFunctionLibrary.setMaterialScalarParameterOnActor(this, null, 'metallic', 0.5);
    if (trace != null) blueprintTrace('begin', 'shine', 'set_material_scalar_parameter_on_actor', {'target': null, 'parameter_name': 'metallic', 'value': 0.5});
    final p87 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Lamp');
    if (trace != null) blueprintTrace('begin', 'lamp', 'get_component', {'component': 'Lamp', 'return_value': p87});
    LuminaBlueprintFunctionLibrary.setLightIntensity(this, p87, 5000.0);
    if (trace != null) blueprintTrace('begin', 'bright', 'set_light_intensity', {'target': p87, 'new_intensity': 5000.0});
    final p88 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Lamp');
    if (trace != null) blueprintTrace('begin', 'lamp', 'get_component', {'component': 'Lamp', 'return_value': p88});
    final p89 = LuminaBlueprintFunctionLibrary.getLightIntensity(this, p88);
    if (trace != null) blueprintTrace('begin', 'lumens', 'get_light_intensity', {'target': p88, 'return_value': p89});
    final p90 = LuminaBlueprintFunctionLibrary.floatToString(p89, 0);
    if (trace != null) blueprintTrace('begin', 'lumens_text', 'float_to_string', {'in_float': p89, 'decimals': 0, 'return_value': p90});
    LuminaBlueprintFunctionLibrary.printString(this, p90, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_lumens', 'print_string', {'in_string': p90, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p90);
    final p91 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Lamp');
    if (trace != null) blueprintTrace('begin', 'lamp', 'get_component', {'component': 'Lamp', 'return_value': p91});
    LuminaBlueprintFunctionLibrary.toggleLightVisibility(this, p91);
    if (trace != null) blueprintTrace('begin', 'flip', 'toggle_light_visibility', {'target': p91});
    final p92 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Lamp');
    if (trace != null) blueprintTrace('begin', 'lamp', 'get_component', {'component': 'Lamp', 'return_value': p92});
    LuminaBlueprintFunctionLibrary.setLightColor(this, p92, <double>[1.0, 0.5, 0.0, 1.0]);
    if (trace != null) blueprintTrace('begin', 'tint', 'set_light_color', {'target': p92, 'new_light_color': <double>[1.0, 0.5, 0.0, 1.0]});
    final p93 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Lamp');
    if (trace != null) blueprintTrace('begin', 'lamp', 'get_component', {'component': 'Lamp', 'return_value': p93});
    LuminaBlueprintFunctionLibrary.setLightRadius(this, p93, 1500.0);
    if (trace != null) blueprintTrace('begin', 'reach', 'set_light_radius', {'target': p93, 'new_radius': 1500.0});
    LuminaBlueprintFunctionLibrary.printString(this, 'on screen', true, true, <double>[0.0, 0.66, 1.0, 1.0], 5.0, 'parity');
    if (trace != null) blueprintTrace('begin', 'screen', 'print_string', {'in_string': 'on screen', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 5.0, 'key': 'parity'}, printed: 'on screen');
    LuminaBlueprintFunctionLibrary.printText(this, 'text too', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'text', 'print_text', {'in_text': 'text too', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'text too');
    LuminaBlueprintFunctionLibrary.drawDebugLine(this, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 100.0, 0.0), <double>[1.0, 1.0, 1.0, 1.0], 1.0, 0.0);
    if (trace != null) blueprintTrace('begin', 'line', 'draw_debug_line', {'line_start': Vector3(0.0, 0.0, 0.0), 'line_end': Vector3(0.0, 100.0, 0.0), 'line_color': <double>[1.0, 1.0, 1.0, 1.0], 'duration': 1.0, 'thickness': 0.0});
    LuminaBlueprintFunctionLibrary.drawDebugSphere(this, Vector3(0.0, 0.0, 100.0), 30.0, 12, <double>[1.0, 1.0, 1.0, 1.0], 0.0, 0.0);
    if (trace != null) blueprintTrace('begin', 'sphere', 'draw_debug_sphere', {'center': Vector3(0.0, 0.0, 100.0), 'radius': 30.0, 'segments': 12, 'line_color': <double>[1.0, 1.0, 1.0, 1.0], 'duration': 0.0, 'thickness': 0.0});
    LuminaBlueprintFunctionLibrary.drawDebugString(this, Vector3(0.0, 0.0, 200.0), 'hi', <double>[1.0, 1.0, 1.0, 1.0], 0.0);
    if (trace != null) blueprintTrace('begin', 'label', 'draw_debug_string', {'text_location': Vector3(0.0, 0.0, 200.0), 'text': 'hi', 'text_color': <double>[1.0, 1.0, 1.0, 1.0], 'duration': 0.0});
    LuminaBlueprintFunctionLibrary.logWarning(this, 'careful');
    if (trace != null) blueprintTrace('begin', 'warn', 'log_warning', {'in_string': 'careful'});
    LuminaBlueprintFunctionLibrary.breakpoint(this);
    if (trace != null) blueprintTrace('begin', 'bp', 'breakpoint', {});
    LuminaBlueprintFunctionLibrary.flushDebugShapes(this);
    if (trace != null) blueprintTrace('begin', 'flush', 'flush_debug_shapes', {});
  }

  /// Event Montage Ended (node ended).
  void _onEnded(String montage, bool interrupted) {
    final p94 = LuminaBlueprintFunctionLibrary.boolToString(interrupted);
    if (trace != null) blueprintTrace('ended', 'interrupted_text', 'bool_to_string', {'in_bool': interrupted, 'return_value': p94});
    final p95 = LuminaBlueprintFunctionLibrary.append3(montage, ' ended ', p94);
    if (trace != null) blueprintTrace('ended', 'ended_line', 'append_3', {'a': montage, 'b': ' ended ', 'c': p94, 'return_value': p95});
    LuminaBlueprintFunctionLibrary.printString(this, p95, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('ended', 'say_ended', 'print_string', {'in_string': p95, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p95);
  }

  /// Event Anim Notify (node notify).
  void _onNotify(String notifyName) {
    final p96 = LuminaBlueprintFunctionLibrary.append('notify ', notifyName);
    if (trace != null) blueprintTrace('notify', 'notify_line', 'append', {'a': 'notify ', 'b': notifyName, 'return_value': p96});
    LuminaBlueprintFunctionLibrary.printString(this, p96, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('notify', 'say_notify', 'print_string', {'in_string': p96, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p96);
  }

  /// After Load Stream Level (by Name) (node stream).
  void _resumeStreamFromBegin() {
    LuminaBlueprintFunctionLibrary.printString(this, 'stream completed', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('stream', 'say_streamed', 'print_string', {'in_string': 'stream completed', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'stream completed');
    final p60 = LuminaBlueprintFunctionLibrary.isStreamLevelLoaded(this, 'L_Nowhere');
    if (trace != null) blueprintTrace('stream', 'streamed', 'is_stream_level_loaded', {'level_name': 'L_Nowhere', 'return_value': p60});
    final p61 = LuminaBlueprintFunctionLibrary.boolToString(p60);
    if (trace != null) blueprintTrace('stream', 'streamed_text', 'bool_to_string', {'in_bool': p60, 'return_value': p61});
    LuminaBlueprintFunctionLibrary.printString(this, p61, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('stream', 'say_streamed_flag', 'print_string', {'in_string': p61, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p61);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
