// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Animation Blueprint contents/animations/SKM_Superhero_Female/ABP_Character.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class AbpCharacter extends LuminaAnimBlueprintInstance {
  AbpCharacter({super.key, required super.mesh})
      : super(
          stateMachine: _stateMachine,
          blendSpaces: _blendSpaces,
          meshYawOffsetDegrees: 0.0,
          aimOffset: const LuminaAnimAimOffset(
            bones: [
              LuminaAnimAimOffsetBone('spine_03', 0.15),
              LuminaAnimAimOffsetBone('neck_01', 0.25),
              LuminaAnimAimOffsetBone('Head', 0.6),
            ],
            yawVariable: 'AimYaw',
            pitchVariable: 'AimPitch',
            maxYaw: 80.0,
            maxPitch: 45.0,
            interpSpeed: 10.0,
          ),
          initialVariables: {
            'GroundSpeed': 0.0,
            'Direction': 0.0,
            'IsFalling': false,
            'IsRising': false,
            'IdleTime': 0.0,
            'IsSprinting': false,
            'IsDashing': false,
            'WallAhead': false,
            'AimYaw': 0.0,
            'AimPitch': 0.0,
            'StateTime': 0.0,
            'ClipFinished': false,
            'RootYawOffset': 0.0,
          },
        );

  /// Makes the instance for a skeletal mesh whose Anim Class this is.
  static LuminaAnimBlueprintInstance create(LuminaAnimatedMeshComponent mesh) => AbpCharacter(mesh: mesh);

  /// The AnimGraph's state machine (Locomotion).
  static final LuminaAnimStateMachine _stateMachine = LuminaAnimStateMachine(
    name: 'Locomotion',
    entryState: 'Idle',
    sampleCrossFade: 0.2,
    states: [
      LuminaAnimState('Idle', LuminaAnimPose.clip('Idle_Loop', rate: 1.0, loop: true, rootYawDegrees: 0.0, plantsFeet: false), x: 0.0, y: 0.0),
      LuminaAnimState('IdleBreak', LuminaAnimPose.randomClip(['Idle_Talking_Loop', 'Idle_FoldArms_Loop', 'Yes'], rate: 1.0, loop: false, rootYawDegrees: 0.0, plantsFeet: false), x: 0.0, y: 220.0),
      LuminaAnimState('Walk', LuminaAnimPose.blendSpace('contents/animations/SKM_Superhero_Female/BS_Locomotion.lmas', xVariable: 'Direction', yVariable: 'GroundSpeed', rate: 1.0, rateVariable: 'GroundSpeed', rateReference: 100.0, minRate: 0.5, maxRate: 3.0, rateRows: true), x: 320.0, y: 0.0),
      LuminaAnimState('Jump', LuminaAnimPose.clip('Jump_Start', rate: 1.0, loop: false, rootYawDegrees: 0.0, plantsFeet: false), x: 160.0, y: -220.0),
      LuminaAnimState('FallLoop', LuminaAnimPose.clip('Jump_Loop', rate: 1.0, loop: true, rootYawDegrees: 0.0, plantsFeet: false), x: 400.0, y: -220.0),
      LuminaAnimState('Land', LuminaAnimPose.clip('Jump_Land', rate: 1.0, loop: false, rootYawDegrees: 0.0, plantsFeet: false), x: 640.0, y: -220.0),
      LuminaAnimState('Dash', LuminaAnimPose.clip('Roll', rate: 1.0, loop: false, rootYawDegrees: 0.0, plantsFeet: false), x: 640.0, y: 0.0),
      LuminaAnimState('WallJump', LuminaAnimPose.clip('NinjaJump_Start', rate: 1.0, loop: false, rootYawDegrees: 0.0, plantsFeet: false), x: 400.0, y: -440.0),
    ],
    transitions: [
      LuminaAnimTransition(id: 'idle_to_dash', from: 'Idle', to: 'Dash', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idle_to_jump', from: 'Idle', to: 'Jump', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idle_to_fallloop', from: 'Idle', to: 'FallLoop', blendDuration: 0.2, priority: 2, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idle_to_walk', from: 'Idle', to: 'Walk', blendDuration: 0.2, priority: 3, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idle_to_idlebreak', from: 'Idle', to: 'IdleBreak', blendDuration: 0.2, priority: 8, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idlebreak_to_dash', from: 'IdleBreak', to: 'Dash', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idlebreak_to_jump', from: 'IdleBreak', to: 'Jump', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idlebreak_to_fallloop', from: 'IdleBreak', to: 'FallLoop', blendDuration: 0.2, priority: 2, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idlebreak_to_walk', from: 'IdleBreak', to: 'Walk', blendDuration: 0.2, priority: 3, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'idlebreak_to_idle', from: 'IdleBreak', to: 'Idle', blendDuration: 0.2, priority: 4, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walk_to_dash', from: 'Walk', to: 'Dash', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walk_to_jump', from: 'Walk', to: 'Jump', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walk_to_fallloop', from: 'Walk', to: 'FallLoop', blendDuration: 0.2, priority: 2, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walk_to_idle', from: 'Walk', to: 'Idle', blendDuration: 0.2, priority: 3, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'jump_to_walljump', from: 'Jump', to: 'WallJump', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'jump_to_land', from: 'Jump', to: 'Land', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'jump_to_fallloop', from: 'Jump', to: 'FallLoop', blendDuration: 0.2, priority: 2, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'fallloop_to_walljump', from: 'FallLoop', to: 'WallJump', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'fallloop_to_land', from: 'FallLoop', to: 'Land', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walljump_to_land', from: 'WallJump', to: 'Land', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'walljump_to_fallloop', from: 'WallJump', to: 'FallLoop', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'land_to_dash', from: 'Land', to: 'Dash', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'land_to_jump', from: 'Land', to: 'Jump', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'land_to_fallloop', from: 'Land', to: 'FallLoop', blendDuration: 0.2, priority: 2, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'land_to_walk', from: 'Land', to: 'Walk', blendDuration: 0.2, priority: 3, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'land_to_idle', from: 'Land', to: 'Idle', blendDuration: 0.2, priority: 4, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'dash_to_fallloop', from: 'Dash', to: 'FallLoop', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'dash_to_jump', from: 'Dash', to: 'Jump', blendDuration: 0.2, priority: 1, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'dash_to_walk', from: 'Dash', to: 'Walk', blendDuration: 0.2, priority: 2, minStateTime: 1.2, automaticRule: false),
      LuminaAnimTransition(id: 'dash_to_idle', from: 'Dash', to: 'Idle', blendDuration: 0.2, priority: 3, minStateTime: 0.0, automaticRule: false),
    ],
  );

  /// The blend spaces its states play, by asset path.
  static final Map<String, LuminaBlendSpaceDocument> _blendSpaces = {
    'contents/animations/SKM_Superhero_Female/BS_Locomotion.lmas': LuminaBlendSpaceDocument(
      axes: [LuminaBlendSpaceAxis('Direction', -180.0, 180.0), LuminaBlendSpaceAxis('Speed', 0.0, 600.0)],
      samples: [
        LuminaBlendSpaceSample('Walk_Bwd_Loop', -180.0, 100.0),
        LuminaBlendSpaceSample('Walk_Bwd_Left_Loop', -135.0, 100.0),
        LuminaBlendSpaceSample('Walk_Left_Loop', -90.0, 100.0),
        LuminaBlendSpaceSample('Walk_Fwd_Left_Loop', -45.0, 100.0),
        LuminaBlendSpaceSample('Walk_Fwd_Loop', 0.0, 100.0),
        LuminaBlendSpaceSample('Walk_Fwd_Right_Loop', 45.0, 100.0),
        LuminaBlendSpaceSample('Walk_Right_Loop', 90.0, 100.0),
        LuminaBlendSpaceSample('Walk_Bwd_Right_Loop', 135.0, 100.0),
        LuminaBlendSpaceSample('Walk_Bwd_Loop', 180.0, 100.0),
        LuminaBlendSpaceSample('Jog_Bwd_Loop', -180.0, 600.0),
        LuminaBlendSpaceSample('Jog_Bwd_Left_Loop', -135.0, 600.0),
        LuminaBlendSpaceSample('Jog_Left_Loop', -90.0, 600.0),
        LuminaBlendSpaceSample('Jog_Fwd_Left_Loop', -45.0, 600.0),
        LuminaBlendSpaceSample('Jog_Fwd_Loop', 0.0, 600.0),
        LuminaBlendSpaceSample('Jog_Fwd_Right_Loop', 45.0, 600.0),
        LuminaBlendSpaceSample('Jog_Right_Loop', 90.0, 600.0),
        LuminaBlendSpaceSample('Jog_Bwd_Right_Loop', 135.0, 600.0),
        LuminaBlendSpaceSample('Jog_Bwd_Loop', 180.0, 600.0),
      ],
    ),
  };

  @override
  void updateAnimation(double deltaTimeX) {
    _onUpdate(deltaTimeX);
  }

  @override
  bool evaluateRule(LuminaAnimTransition transition) => switch (transition.id) {
        'idle_to_dash' => _ruleIdleToDash(),
        'idle_to_jump' => _ruleIdleToJump(),
        'idle_to_fallloop' => _ruleIdleToFallloop(),
        'idle_to_walk' => _ruleIdleToWalk(),
        'idle_to_idlebreak' => _ruleIdleToIdlebreak(),
        'idlebreak_to_dash' => _ruleIdlebreakToDash(),
        'idlebreak_to_jump' => _ruleIdlebreakToJump(),
        'idlebreak_to_fallloop' => _ruleIdlebreakToFallloop(),
        'idlebreak_to_walk' => _ruleIdlebreakToWalk(),
        'idlebreak_to_idle' => _ruleIdlebreakToIdle(),
        'walk_to_dash' => _ruleWalkToDash(),
        'walk_to_jump' => _ruleWalkToJump(),
        'walk_to_fallloop' => _ruleWalkToFallloop(),
        'walk_to_idle' => _ruleWalkToIdle(),
        'jump_to_walljump' => _ruleJumpToWalljump(),
        'jump_to_land' => _ruleJumpToLand(),
        'jump_to_fallloop' => _ruleJumpToFallloop(),
        'fallloop_to_walljump' => _ruleFallloopToWalljump(),
        'fallloop_to_land' => _ruleFallloopToLand(),
        'walljump_to_land' => _ruleWalljumpToLand(),
        'walljump_to_fallloop' => _ruleWalljumpToFallloop(),
        'land_to_dash' => _ruleLandToDash(),
        'land_to_jump' => _ruleLandToJump(),
        'land_to_fallloop' => _ruleLandToFallloop(),
        'land_to_walk' => _ruleLandToWalk(),
        'land_to_idle' => _ruleLandToIdle(),
        'dash_to_fallloop' => _ruleDashToFallloop(),
        'dash_to_jump' => _ruleDashToJump(),
        'dash_to_walk' => _ruleDashToWalk(),
        'dash_to_idle' => _ruleDashToIdle(),
        _ => false,
      };

  /// Event Blueprint Update Animation (node update).
  void _onUpdate(double deltaTimeX) {
    double? oset_speed_value;
    double? oset_direction_value;
    bool? oset_falling_value;
    bool? oset_rising_value;
    double? oset_aim_yaw_value;
    double? oset_aim_pitch_value;
    double? oadd_idle_time_value;
    double? oreset_idle_time_value;
    final p0 = LuminaBlueprintFunctionLibrary.getVelocity(pawnOwner);
    if (trace != null) blueprintTrace('update', 'velocity', 'get_velocity', {'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.vectorLengthXY(p0);
    if (trace != null) blueprintTrace('update', 'speed', 'vector_length_xy', {'in_vec': p0, 'return_value': p1});
    variables['GroundSpeed'] = p1;
    oset_speed_value = p1;
    if (trace != null) blueprintTrace('update', 'set_speed', 'variable_set', {'value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.getVelocity(pawnOwner);
    if (trace != null) blueprintTrace('update', 'velocity', 'get_velocity', {'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.getActorRotation(pawnOwner);
    if (trace != null) blueprintTrace('update', 'rotation', 'get_actor_rotation', {'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.calculateDirection(p2, p3);
    if (trace != null) blueprintTrace('update', 'direction', 'calculate_direction', {'velocity': p2, 'base_rotation': p3, 'return_value': p4});
    variables['Direction'] = p4;
    oset_direction_value = p4;
    if (trace != null) blueprintTrace('update', 'set_direction', 'variable_set', {'value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.isFalling(pawnOwner);
    if (trace != null) blueprintTrace('update', 'falling', 'is_falling', {'return_value': p5});
    variables['IsFalling'] = p5;
    oset_falling_value = p5;
    if (trace != null) blueprintTrace('update', 'set_falling', 'variable_set', {'value': p5});
    final p6 = LuminaBlueprintFunctionLibrary.isFalling(pawnOwner);
    if (trace != null) blueprintTrace('update', 'falling', 'is_falling', {'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.getVelocity(pawnOwner);
    if (trace != null) blueprintTrace('update', 'velocity', 'get_velocity', {'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.breakVector(p7);
    if (trace != null) blueprintTrace('update', 'velocity_parts', 'break_vector', {'in_vec': p7, 'x': p8.x, 'y': p8.y, 'z': p8.z});
    final p9 = LuminaBlueprintFunctionLibrary.floatGreater(p8.z, 0.0);
    if (trace != null) blueprintTrace('update', 'upward', 'float_greater', {'a': p8.z, 'b': 0.0, 'return_value': p9});
    final p10 = LuminaBlueprintFunctionLibrary.boolAnd(p6, p9);
    if (trace != null) blueprintTrace('update', 'rising', 'bool_and', {'a': p6, 'b': p9, 'return_value': p10});
    variables['IsRising'] = p10;
    oset_rising_value = p10;
    if (trace != null) blueprintTrace('update', 'set_rising', 'variable_set', {'value': p10});
    final p11 = LuminaBlueprintFunctionLibrary.getControlRotation(pawnOwner);
    if (trace != null) blueprintTrace('update', 'control', 'get_control_rotation', {'return_value': p11});
    final p12 = LuminaBlueprintFunctionLibrary.breakRotator(p11);
    if (trace != null) blueprintTrace('update', 'control_parts', 'break_rotator', {'in_rot': p11, 'x': p12.x, 'y': p12.y, 'z': p12.z});
    final p13 = LuminaBlueprintFunctionLibrary.getActorRotation(pawnOwner);
    if (trace != null) blueprintTrace('update', 'rotation', 'get_actor_rotation', {'return_value': p13});
    final p14 = LuminaBlueprintFunctionLibrary.breakRotator(p13);
    if (trace != null) blueprintTrace('update', 'body_parts', 'break_rotator', {'in_rot': p13, 'x': p14.x, 'y': p14.y, 'z': p14.z});
    final p15 = LuminaBlueprintFunctionLibrary.floatSubtract(p12.z, p14.z);
    if (trace != null) blueprintTrace('update', 'yaw_delta', 'float_subtract', {'a': p12.z, 'b': p14.z, 'return_value': p15});
    final p16 = LuminaBlueprintFunctionLibrary.normalizeAxis(p15);
    if (trace != null) blueprintTrace('update', 'aim_yaw', 'normalize_axis', {'angle': p15, 'return_value': p16});
    variables['AimYaw'] = p16;
    oset_aim_yaw_value = p16;
    if (trace != null) blueprintTrace('update', 'set_aim_yaw', 'variable_set', {'value': p16});
    final p17 = LuminaBlueprintFunctionLibrary.getControlRotation(pawnOwner);
    if (trace != null) blueprintTrace('update', 'control', 'get_control_rotation', {'return_value': p17});
    final p18 = LuminaBlueprintFunctionLibrary.breakRotator(p17);
    if (trace != null) blueprintTrace('update', 'control_parts', 'break_rotator', {'in_rot': p17, 'x': p18.x, 'y': p18.y, 'z': p18.z});
    final p19 = LuminaBlueprintFunctionLibrary.getActorRotation(pawnOwner);
    if (trace != null) blueprintTrace('update', 'rotation', 'get_actor_rotation', {'return_value': p19});
    final p20 = LuminaBlueprintFunctionLibrary.breakRotator(p19);
    if (trace != null) blueprintTrace('update', 'body_parts', 'break_rotator', {'in_rot': p19, 'x': p20.x, 'y': p20.y, 'z': p20.z});
    final p21 = LuminaBlueprintFunctionLibrary.floatSubtract(p18.x, p20.x);
    if (trace != null) blueprintTrace('update', 'pitch_delta', 'float_subtract', {'a': p18.x, 'b': p20.x, 'return_value': p21});
    final p22 = LuminaBlueprintFunctionLibrary.normalizeAxis(p21);
    if (trace != null) blueprintTrace('update', 'aim_pitch', 'normalize_axis', {'angle': p21, 'return_value': p22});
    variables['AimPitch'] = p22;
    oset_aim_pitch_value = p22;
    if (trace != null) blueprintTrace('update', 'set_aim_pitch', 'variable_set', {'value': p22});
    final p23 = LuminaBlueprintFunctionLibrary.getVelocity(pawnOwner);
    if (trace != null) blueprintTrace('update', 'velocity', 'get_velocity', {'return_value': p23});
    final p24 = LuminaBlueprintFunctionLibrary.vectorLengthXY(p23);
    if (trace != null) blueprintTrace('update', 'speed', 'vector_length_xy', {'in_vec': p23, 'return_value': p24});
    final p25 = LuminaBlueprintFunctionLibrary.floatLess(p24, 15.0);
    if (trace != null) blueprintTrace('update', 'still', 'float_less', {'a': p24, 'b': 15.0, 'return_value': p25});
    if (trace != null) blueprintTrace('update', 'if_still', 'branch', {'condition': p25});
    if (p25) {
      final p26 = variables['IdleTime'] as double;
      if (trace != null) blueprintTrace('update', 'idle_time', 'variable_get', {'value': p26});
      final p27 = LuminaBlueprintFunctionLibrary.floatAdd(p26, deltaTimeX);
      if (trace != null) blueprintTrace('update', 'idle_time_plus', 'float_add', {'a': p26, 'b': deltaTimeX, 'return_value': p27});
      variables['IdleTime'] = p27;
      oadd_idle_time_value = p27;
      if (trace != null) blueprintTrace('update', 'add_idle_time', 'variable_set', {'value': p27});
    } else {
      variables['IdleTime'] = 0.0;
      oreset_idle_time_value = 0.0;
      if (trace != null) blueprintTrace('update', 'reset_idle_time', 'variable_set', {'value': 0.0});
    }
  }

  /// Can Idle → Dash (transition idle_to_dash) be taken?
  bool _ruleIdleToDash() {
    final p28 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('idle_to_dash', 'flag', 'variable_get', {'value': p28});
    return p28;
  }

  /// Can Idle → Jump (transition idle_to_jump) be taken?
  bool _ruleIdleToJump() {
    final p29 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('idle_to_jump', 'flag', 'variable_get', {'value': p29});
    return p29;
  }

  /// Can Idle → FallLoop (transition idle_to_fallloop) be taken?
  bool _ruleIdleToFallloop() {
    final p30 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('idle_to_fallloop', 'flag', 'variable_get', {'value': p30});
    final p31 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('idle_to_fallloop', 'other', 'variable_get', {'value': p31});
    final p32 = LuminaBlueprintFunctionLibrary.boolNot(p31);
    if (trace != null) blueprintTrace('idle_to_fallloop', 'not_other', 'bool_not', {'a': p31, 'return_value': p32});
    final p33 = LuminaBlueprintFunctionLibrary.boolAnd(p30, p32);
    if (trace != null) blueprintTrace('idle_to_fallloop', 'both', 'bool_and', {'a': p30, 'b': p32, 'return_value': p33});
    return p33;
  }

  /// Can Idle → Walk (transition idle_to_walk) be taken?
  bool _ruleIdleToWalk() {
    final p34 = variables['GroundSpeed'] as double;
    if (trace != null) blueprintTrace('idle_to_walk', 'speed', 'variable_get', {'value': p34});
    final p35 = LuminaBlueprintFunctionLibrary.floatLess(p34, 15.0);
    if (trace != null) blueprintTrace('idle_to_walk', 'below', 'float_less', {'a': p34, 'b': 15.0, 'return_value': p35});
    final p36 = LuminaBlueprintFunctionLibrary.boolNot(p35);
    if (trace != null) blueprintTrace('idle_to_walk', 'moving', 'bool_not', {'a': p35, 'return_value': p36});
    return p36;
  }

  /// Can Idle → IdleBreak (transition idle_to_idlebreak) be taken?
  bool _ruleIdleToIdlebreak() {
    final p37 = variables['IdleTime'] as double;
    if (trace != null) blueprintTrace('idle_to_idlebreak', 'idle_time', 'variable_get', {'value': p37});
    final p38 = LuminaBlueprintFunctionLibrary.floatGreater(p37, 6.0);
    if (trace != null) blueprintTrace('idle_to_idlebreak', 'waited', 'float_greater', {'a': p37, 'b': 6.0, 'return_value': p38});
    final p39 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('idle_to_idlebreak', 'finished', 'variable_get', {'value': p39});
    final p40 = LuminaBlueprintFunctionLibrary.boolAnd(p38, p39);
    if (trace != null) blueprintTrace('idle_to_idlebreak', 'both', 'bool_and', {'a': p38, 'b': p39, 'return_value': p40});
    return p40;
  }

  /// Can IdleBreak → Dash (transition idlebreak_to_dash) be taken?
  bool _ruleIdlebreakToDash() {
    final p41 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('idlebreak_to_dash', 'flag', 'variable_get', {'value': p41});
    return p41;
  }

  /// Can IdleBreak → Jump (transition idlebreak_to_jump) be taken?
  bool _ruleIdlebreakToJump() {
    final p42 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('idlebreak_to_jump', 'flag', 'variable_get', {'value': p42});
    return p42;
  }

  /// Can IdleBreak → FallLoop (transition idlebreak_to_fallloop) be taken?
  bool _ruleIdlebreakToFallloop() {
    final p43 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('idlebreak_to_fallloop', 'flag', 'variable_get', {'value': p43});
    final p44 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('idlebreak_to_fallloop', 'other', 'variable_get', {'value': p44});
    final p45 = LuminaBlueprintFunctionLibrary.boolNot(p44);
    if (trace != null) blueprintTrace('idlebreak_to_fallloop', 'not_other', 'bool_not', {'a': p44, 'return_value': p45});
    final p46 = LuminaBlueprintFunctionLibrary.boolAnd(p43, p45);
    if (trace != null) blueprintTrace('idlebreak_to_fallloop', 'both', 'bool_and', {'a': p43, 'b': p45, 'return_value': p46});
    return p46;
  }

  /// Can IdleBreak → Walk (transition idlebreak_to_walk) be taken?
  bool _ruleIdlebreakToWalk() {
    final p47 = variables['GroundSpeed'] as double;
    if (trace != null) blueprintTrace('idlebreak_to_walk', 'speed', 'variable_get', {'value': p47});
    final p48 = LuminaBlueprintFunctionLibrary.floatLess(p47, 15.0);
    if (trace != null) blueprintTrace('idlebreak_to_walk', 'below', 'float_less', {'a': p47, 'b': 15.0, 'return_value': p48});
    final p49 = LuminaBlueprintFunctionLibrary.boolNot(p48);
    if (trace != null) blueprintTrace('idlebreak_to_walk', 'moving', 'bool_not', {'a': p48, 'return_value': p49});
    return p49;
  }

  /// Can IdleBreak → Idle (transition idlebreak_to_idle) be taken?
  bool _ruleIdlebreakToIdle() {
    final p50 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('idlebreak_to_idle', 'flag', 'variable_get', {'value': p50});
    return p50;
  }

  /// Can Walk → Dash (transition walk_to_dash) be taken?
  bool _ruleWalkToDash() {
    final p51 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('walk_to_dash', 'flag', 'variable_get', {'value': p51});
    return p51;
  }

  /// Can Walk → Jump (transition walk_to_jump) be taken?
  bool _ruleWalkToJump() {
    final p52 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('walk_to_jump', 'flag', 'variable_get', {'value': p52});
    return p52;
  }

  /// Can Walk → FallLoop (transition walk_to_fallloop) be taken?
  bool _ruleWalkToFallloop() {
    final p53 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('walk_to_fallloop', 'flag', 'variable_get', {'value': p53});
    final p54 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('walk_to_fallloop', 'other', 'variable_get', {'value': p54});
    final p55 = LuminaBlueprintFunctionLibrary.boolNot(p54);
    if (trace != null) blueprintTrace('walk_to_fallloop', 'not_other', 'bool_not', {'a': p54, 'return_value': p55});
    final p56 = LuminaBlueprintFunctionLibrary.boolAnd(p53, p55);
    if (trace != null) blueprintTrace('walk_to_fallloop', 'both', 'bool_and', {'a': p53, 'b': p55, 'return_value': p56});
    return p56;
  }

  /// Can Walk → Idle (transition walk_to_idle) be taken?
  bool _ruleWalkToIdle() {
    final p57 = variables['GroundSpeed'] as double;
    if (trace != null) blueprintTrace('walk_to_idle', 'speed', 'variable_get', {'value': p57});
    final p58 = LuminaBlueprintFunctionLibrary.floatLess(p57, 15.0);
    if (trace != null) blueprintTrace('walk_to_idle', 'below', 'float_less', {'a': p57, 'b': 15.0, 'return_value': p58});
    return p58;
  }

  /// Can Jump → WallJump (transition jump_to_walljump) be taken?
  bool _ruleJumpToWalljump() {
    final p59 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('jump_to_walljump', 'flag', 'variable_get', {'value': p59});
    final p60 = variables['WallAhead'] as bool;
    if (trace != null) blueprintTrace('jump_to_walljump', 'other', 'variable_get', {'value': p60});
    final p61 = LuminaBlueprintFunctionLibrary.boolAnd(p59, p60);
    if (trace != null) blueprintTrace('jump_to_walljump', 'both', 'bool_and', {'a': p59, 'b': p60, 'return_value': p61});
    return p61;
  }

  /// Can Jump → Land (transition jump_to_land) be taken?
  bool _ruleJumpToLand() {
    final p62 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('jump_to_land', 'flag', 'variable_get', {'value': p62});
    final p63 = LuminaBlueprintFunctionLibrary.boolNot(p62);
    if (trace != null) blueprintTrace('jump_to_land', 'not', 'bool_not', {'a': p62, 'return_value': p63});
    return p63;
  }

  /// Can Jump → FallLoop (transition jump_to_fallloop) be taken?
  bool _ruleJumpToFallloop() {
    final p64 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('jump_to_fallloop', 'finished', 'variable_get', {'value': p64});
    final p65 = variables['StateTime'] as double;
    if (trace != null) blueprintTrace('jump_to_fallloop', 'time', 'variable_get', {'value': p65});
    final p66 = LuminaBlueprintFunctionLibrary.floatGreater(p65, 0.3);
    if (trace != null) blueprintTrace('jump_to_fallloop', 'late', 'float_greater', {'a': p65, 'b': 0.3, 'return_value': p66});
    final p67 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('jump_to_fallloop', 'falling', 'variable_get', {'value': p67});
    final p68 = LuminaBlueprintFunctionLibrary.boolAnd(p66, p67);
    if (trace != null) blueprintTrace('jump_to_fallloop', 'still_falling', 'bool_and', {'a': p66, 'b': p67, 'return_value': p68});
    final p69 = LuminaBlueprintFunctionLibrary.boolOr(p64, p68);
    if (trace != null) blueprintTrace('jump_to_fallloop', 'either', 'bool_or', {'a': p64, 'b': p68, 'return_value': p69});
    return p69;
  }

  /// Can FallLoop → WallJump (transition fallloop_to_walljump) be taken?
  bool _ruleFallloopToWalljump() {
    final p70 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('fallloop_to_walljump', 'flag', 'variable_get', {'value': p70});
    final p71 = variables['WallAhead'] as bool;
    if (trace != null) blueprintTrace('fallloop_to_walljump', 'other', 'variable_get', {'value': p71});
    final p72 = LuminaBlueprintFunctionLibrary.boolAnd(p70, p71);
    if (trace != null) blueprintTrace('fallloop_to_walljump', 'both', 'bool_and', {'a': p70, 'b': p71, 'return_value': p72});
    return p72;
  }

  /// Can FallLoop → Land (transition fallloop_to_land) be taken?
  bool _ruleFallloopToLand() {
    final p73 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('fallloop_to_land', 'flag', 'variable_get', {'value': p73});
    final p74 = LuminaBlueprintFunctionLibrary.boolNot(p73);
    if (trace != null) blueprintTrace('fallloop_to_land', 'not', 'bool_not', {'a': p73, 'return_value': p74});
    return p74;
  }

  /// Can WallJump → Land (transition walljump_to_land) be taken?
  bool _ruleWalljumpToLand() {
    final p75 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('walljump_to_land', 'flag', 'variable_get', {'value': p75});
    final p76 = LuminaBlueprintFunctionLibrary.boolNot(p75);
    if (trace != null) blueprintTrace('walljump_to_land', 'not', 'bool_not', {'a': p75, 'return_value': p76});
    return p76;
  }

  /// Can WallJump → FallLoop (transition walljump_to_fallloop) be taken?
  bool _ruleWalljumpToFallloop() {
    final p77 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('walljump_to_fallloop', 'flag', 'variable_get', {'value': p77});
    return p77;
  }

  /// Can Land → Dash (transition land_to_dash) be taken?
  bool _ruleLandToDash() {
    final p78 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('land_to_dash', 'flag', 'variable_get', {'value': p78});
    return p78;
  }

  /// Can Land → Jump (transition land_to_jump) be taken?
  bool _ruleLandToJump() {
    final p79 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('land_to_jump', 'flag', 'variable_get', {'value': p79});
    return p79;
  }

  /// Can Land → FallLoop (transition land_to_fallloop) be taken?
  bool _ruleLandToFallloop() {
    final p80 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('land_to_fallloop', 'flag', 'variable_get', {'value': p80});
    final p81 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('land_to_fallloop', 'other', 'variable_get', {'value': p81});
    final p82 = LuminaBlueprintFunctionLibrary.boolNot(p81);
    if (trace != null) blueprintTrace('land_to_fallloop', 'not_other', 'bool_not', {'a': p81, 'return_value': p82});
    final p83 = LuminaBlueprintFunctionLibrary.boolAnd(p80, p82);
    if (trace != null) blueprintTrace('land_to_fallloop', 'both', 'bool_and', {'a': p80, 'b': p82, 'return_value': p83});
    return p83;
  }

  /// Can Land → Walk (transition land_to_walk) be taken?
  bool _ruleLandToWalk() {
    final p84 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('land_to_walk', 'falling', 'variable_get', {'value': p84});
    final p85 = LuminaBlueprintFunctionLibrary.boolNot(p84);
    if (trace != null) blueprintTrace('land_to_walk', 'grounded', 'bool_not', {'a': p84, 'return_value': p85});
    final p86 = variables['GroundSpeed'] as double;
    if (trace != null) blueprintTrace('land_to_walk', 'speed', 'variable_get', {'value': p86});
    final p87 = LuminaBlueprintFunctionLibrary.floatLess(p86, 15.0);
    if (trace != null) blueprintTrace('land_to_walk', 'below', 'float_less', {'a': p86, 'b': 15.0, 'return_value': p87});
    final p88 = LuminaBlueprintFunctionLibrary.boolNot(p87);
    if (trace != null) blueprintTrace('land_to_walk', 'moving', 'bool_not', {'a': p87, 'return_value': p88});
    final p89 = LuminaBlueprintFunctionLibrary.boolAnd(p85, p88);
    if (trace != null) blueprintTrace('land_to_walk', 'both', 'bool_and', {'a': p85, 'b': p88, 'return_value': p89});
    return p89;
  }

  /// Can Land → Idle (transition land_to_idle) be taken?
  bool _ruleLandToIdle() {
    final p90 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('land_to_idle', 'flag', 'variable_get', {'value': p90});
    return p90;
  }

  /// Can Dash → FallLoop (transition dash_to_fallloop) be taken?
  bool _ruleDashToFallloop() {
    final p91 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('dash_to_fallloop', 'flag', 'variable_get', {'value': p91});
    final p92 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('dash_to_fallloop', 'other', 'variable_get', {'value': p92});
    final p93 = LuminaBlueprintFunctionLibrary.boolNot(p92);
    if (trace != null) blueprintTrace('dash_to_fallloop', 'not_other', 'bool_not', {'a': p92, 'return_value': p93});
    final p94 = LuminaBlueprintFunctionLibrary.boolAnd(p91, p93);
    if (trace != null) blueprintTrace('dash_to_fallloop', 'both', 'bool_and', {'a': p91, 'b': p93, 'return_value': p94});
    return p94;
  }

  /// Can Dash → Jump (transition dash_to_jump) be taken?
  bool _ruleDashToJump() {
    final p95 = variables['IsRising'] as bool;
    if (trace != null) blueprintTrace('dash_to_jump', 'flag', 'variable_get', {'value': p95});
    final p96 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('dash_to_jump', 'other', 'variable_get', {'value': p96});
    final p97 = LuminaBlueprintFunctionLibrary.boolNot(p96);
    if (trace != null) blueprintTrace('dash_to_jump', 'not_other', 'bool_not', {'a': p96, 'return_value': p97});
    final p98 = LuminaBlueprintFunctionLibrary.boolAnd(p95, p97);
    if (trace != null) blueprintTrace('dash_to_jump', 'both', 'bool_and', {'a': p95, 'b': p97, 'return_value': p98});
    return p98;
  }

  /// Can Dash → Walk (transition dash_to_walk) be taken?
  bool _ruleDashToWalk() {
    final p99 = variables['IsDashing'] as bool;
    if (trace != null) blueprintTrace('dash_to_walk', 'dashing', 'variable_get', {'value': p99});
    final p100 = LuminaBlueprintFunctionLibrary.boolNot(p99);
    if (trace != null) blueprintTrace('dash_to_walk', 'not_dashing', 'bool_not', {'a': p99, 'return_value': p100});
    final p101 = variables['IsFalling'] as bool;
    if (trace != null) blueprintTrace('dash_to_walk', 'falling', 'variable_get', {'value': p101});
    final p102 = LuminaBlueprintFunctionLibrary.boolNot(p101);
    if (trace != null) blueprintTrace('dash_to_walk', 'grounded', 'bool_not', {'a': p101, 'return_value': p102});
    final p103 = LuminaBlueprintFunctionLibrary.boolAnd(p100, p102);
    if (trace != null) blueprintTrace('dash_to_walk', 'settled', 'bool_and', {'a': p100, 'b': p102, 'return_value': p103});
    final p104 = variables['GroundSpeed'] as double;
    if (trace != null) blueprintTrace('dash_to_walk', 'speed', 'variable_get', {'value': p104});
    final p105 = LuminaBlueprintFunctionLibrary.floatLess(p104, 15.0);
    if (trace != null) blueprintTrace('dash_to_walk', 'below', 'float_less', {'a': p104, 'b': 15.0, 'return_value': p105});
    final p106 = LuminaBlueprintFunctionLibrary.boolNot(p105);
    if (trace != null) blueprintTrace('dash_to_walk', 'moving', 'bool_not', {'a': p105, 'return_value': p106});
    final p107 = LuminaBlueprintFunctionLibrary.boolAnd(p103, p106);
    if (trace != null) blueprintTrace('dash_to_walk', 'all', 'bool_and', {'a': p103, 'b': p106, 'return_value': p107});
    return p107;
  }

  /// Can Dash → Idle (transition dash_to_idle) be taken?
  bool _ruleDashToIdle() {
    final p108 = variables['ClipFinished'] as bool;
    if (trace != null) blueprintTrace('dash_to_idle', 'flag', 'variable_get', {'value': p108});
    return p108;
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
