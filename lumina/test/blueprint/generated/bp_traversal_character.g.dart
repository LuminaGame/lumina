// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_traversal_character.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpTraversalCharacter extends LuminaCharacter with LuminaBlueprintRuntime {
  BpTraversalCharacter({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_traversal_character';

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
      id: 'movement',
      name: 'CharacterMovement',
      type: 'LuminaCharacterMovementComponent',
      parentId: null,
      properties: <String, dynamic>{'maxWalkSpeed': 500.0},
      isSceneComponent: false,
    ),
    LuminaBlueprintComponent(
      id: 'traversal',
      name: 'Traversal',
      type: 'LuminaTraversalComponent',
      parentId: null,
      properties: <String, dynamic>{'animations': <dynamic>[<String, dynamic>{'action': 'hurdle', 'clip': 'Hurdle', 'maxHeight': 125.0, 'blendOutTime': 1.2, 'windows': <dynamic>[<String, dynamic>{'target': 'FrontLedge', 'start': 0.2, 'end': 0.55, 'rotation': true}, <String, dynamic>{'target': 'BackFloor', 'start': 0.8, 'end': 1.05}]}, <String, dynamic>{'action': 'vault', 'clip': 'Vault', 'maxHeight': 125.0, 'windows': <dynamic>[<String, dynamic>{'target': 'FrontLedge', 'start': 0.1, 'end': 0.5, 'rotation': true}]}, <String, dynamic>{'action': 'mantle', 'clip': 'Mantle', 'maxHeight': 275.0, 'windows': <dynamic>[<String, dynamic>{'target': 'FrontLedge', 'start': 0.05, 'end': 0.7, 'rotation': true}]}]},
      isSceneComponent: false,
    ),
  ];

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _bindInput();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
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
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Jump', valueType: InputValueType.digitalBool), TriggerState.started, (value) => _onJump_inputStarted(value.asBool)),
        LuminaBlueprintInputBinding(const LuminaInputAction('IA_Jump', valueType: InputValueType.digitalBool), TriggerState.completed, (value) => _onJump_inputCompleted(value.asBool)),
      ]);

  /// IA_Jump Started (node jump_input).
  void _onJump_inputStarted(bool actionValue) {
    bool? otraverse_return_value;
    final r0 = LuminaBlueprintFunctionLibrary.tryTraversalAction(this);
    otraverse_return_value = r0;
    if (trace != null) blueprintTrace('jump_input', 'traverse', 'try_traversal_action', {'return_value': r0});
    if (trace != null) blueprintTrace('jump_input', 'fits', 'branch', {'condition': (otraverse_return_value ?? false)});
    if (!(otraverse_return_value ?? false)) {
      LuminaBlueprintFunctionLibrary.jump(this);
      if (trace != null) blueprintTrace('jump_input', 'jump', 'jump', {});
    }
  }

  /// IA_Jump Completed (node jump_input).
  void _onJump_inputCompleted(bool actionValue) {
    LuminaBlueprintFunctionLibrary.stopJumping(this);
    if (trace != null) blueprintTrace('jump_input', 'stop_jumping', 'stop_jumping', {});
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
