// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Animation Blueprint contents/animations/ABP_MotionMatching.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'dart:convert';
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class AbpMotionMatching extends LuminaAnimBlueprintInstance {
  AbpMotionMatching({super.key, required super.mesh})
      : super(
          stateMachine: _stateMachine,
          blendSpaces: _blendSpaces,
          poseDatabases: _poseDatabases,
          meshYawOffsetDegrees: 0.0,
          initialVariables: {
            'Freeze': false,
            'MatchedClip': '',
          },
        );

  /// Makes the instance for a skeletal mesh whose Anim Class this is.
  static LuminaAnimBlueprintInstance create(LuminaAnimatedMeshComponent mesh) => AbpMotionMatching(mesh: mesh);

  /// The AnimGraph's state machine (Locomotion).
  static final LuminaAnimStateMachine _stateMachine = LuminaAnimStateMachine(
    name: 'Locomotion',
    entryState: 'Locomotion',
    sampleCrossFade: 0.2,
    states: [
      LuminaAnimState('Locomotion', LuminaAnimPose.motionMatching('contents/animations/PSD_Rig.lmas', blendTime: 0.25, poseWeight: 1.0, trajectoryWeight: 1.0, requiredTags: [], orientToMovement: false, debugDraw: false), x: 120.0, y: 60.0),
      LuminaAnimState('Frozen', LuminaAnimPose.hold(), x: 360.0, y: 60.0),
    ],
    transitions: [
      LuminaAnimTransition(id: 'locomotion_to_frozen', from: 'Locomotion', to: 'Frozen', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
      LuminaAnimTransition(id: 'frozen_to_locomotion', from: 'Frozen', to: 'Locomotion', blendDuration: 0.2, priority: 0, minStateTime: 0.0, automaticRule: false),
    ],
  );

  /// The blend spaces its states play, by asset path.
  static final Map<String, LuminaBlendSpaceDocument> _blendSpaces = {
  };

  /// The pose search databases its Motion Matching states play, by asset path.
  static final Map<String, LuminaPoseSearchDatabaseDocument> _poseDatabases = {
    'contents/animations/PSD_Rig.lmas': LuminaPoseSearchDatabaseDocument.fromJson(jsonDecode(r'''{"targetMesh":"contents/meshes/Rig.glb","clips":[{"clip":"Idle","loop":true,"mirror":false,"tags":[],"enabled":true,"costBias":0.0,"samplingStart":0.0,"samplingEnd":0.0},{"clip":"Start","loop":false,"mirror":false,"tags":[],"enabled":true,"costBias":0.0,"samplingStart":0.0,"samplingEnd":0.0},{"clip":"WalkF","loop":true,"mirror":false,"tags":[],"enabled":true,"costBias":0.0,"samplingStart":0.0,"samplingEnd":0.0},{"clip":"Stop","loop":false,"mirror":false,"tags":[],"enabled":true,"costBias":0.0,"samplingStart":0.0,"samplingEnd":0.0}],"schema":{"sampleRate":30.0,"trajectoryTimes":[-0.33,0.33,0.67,1.0],"trajectoryPositionWeight":1.0,"trajectoryFacingWeight":1.0,"bones":[{"name":"foot_l","position":1.0,"velocity":1.0},{"name":"foot_r","position":1.0,"velocity":1.0},{"name":"pelvis","position":0.0,"velocity":1.0}],"rootBone":"","meshYawOffsetDegrees":0.0},"searchInterval":0.1,"continuingPoseBias":0.05,"blendTime":0.2,"excludeEndSeconds":0.3,"loopingCostBias":-0.05}''') as Map<String, dynamic>),
  };

  @override
  void updateAnimation(double deltaTimeX) {
    _onUpdate(deltaTimeX);
  }

  @override
  bool evaluateRule(LuminaAnimTransition transition) => switch (transition.id) {
        'locomotion_to_frozen' => _ruleLocomotionToFrozen(),
        'frozen_to_locomotion' => _ruleFrozenToLocomotion(),
        _ => false,
      };

  /// Event Blueprint Update Animation (node update).
  void _onUpdate(double deltaTimeX) {
  }

  /// Can Locomotion → Frozen (transition locomotion_to_frozen) be taken?
  bool _ruleLocomotionToFrozen() {
    final p0 = variables['Freeze'] as bool;
    if (trace != null) blueprintTrace('locomotion_to_frozen', 'flag', 'variable_get', {'value': p0});
    return p0;
  }

  /// Can Frozen → Locomotion (transition frozen_to_locomotion) be taken?
  bool _ruleFrozenToLocomotion() {
    final p1 = variables['Freeze'] as bool;
    if (trace != null) blueprintTrace('frozen_to_locomotion', 'flag', 'variable_get', {'value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.boolNot(p1);
    if (trace != null) blueprintTrace('frozen_to_locomotion', 'not', 'bool_not', {'a': p1, 'return_value': p2});
    return p2;
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
