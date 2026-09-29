// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_editor_character.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpEditorCharacter extends LuminaCharacter with LuminaBlueprintRuntime {
  BpEditorCharacter({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_editor_character';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root_capsule',
      name: 'CapsuleComponent',
      type: 'LuminaCapsuleComponent',
      parentId: null,
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0], 'capsuleRadius': 35.0, 'capsuleHalfHeight': 90.0},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'arrow_comp',
      name: 'ArrowComponent',
      type: 'LuminaArrowComponent',
      parentId: 'root_capsule',
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0], 'arrowSize': 1.0, 'arrowColor': '#0088ffff'},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'spring_arm',
      name: 'CameraBoom',
      type: 'LuminaSpringArmComponent',
      parentId: 'root_capsule',
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0], 'targetArmLength': 400.0, 'usePawnControlRotation': true, 'inheritPitch': true, 'inheritYaw': true, 'inheritRoll': false},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'follow_cam',
      name: 'FollowCamera',
      type: 'LuminaCameraComponent',
      parentId: 'spring_arm',
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, 0.0], 'rotation': <dynamic>[0.0, 0.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0], 'fieldOfView': 90.0, 'usePawnControlRotation': false},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'skm_mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'root_capsule',
      properties: <String, dynamic>{'location': <dynamic>[0.0, 0.0, -90.0], 'rotation': <dynamic>[0.0, -90.0, 0.0], 'scale': <dynamic>[1.0, 1.0, 1.0], 'skeletalMeshAsset': '', 'animMode': 'Use Animation Asset', 'castShadows': true, 'receiveShadows': true},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'char_move',
      name: 'CharacterMovement',
      type: 'LuminaCharacterMovementComponent',
      parentId: null,
      properties: <String, dynamic>{'maxWalkSpeed': 600.0, 'jumpZVelocity': 700.0, 'gravityScale': 1.75, 'airControl': 0.35},
      isSceneComponent: false,
    ),
  ];

  double health = 100.0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onN_begin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onN_tick(deltaSeconds);
  }

  /// Event BeginPlay (node n_begin).
  void _onN_begin() {
    LuminaBlueprintFunctionLibrary.printString(this, 'hi', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('n_begin', 'n_print', 'print_string', {'in_string': 'hi', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'hi');
  }

  /// Event Tick (node n_tick).
  void _onN_tick(double deltaSeconds) {
    LuminaBlueprintFunctionLibrary.addMovementInput(this, Vector3(0.0, 1.0, 0.0), 0.5, false);
    if (trace != null) blueprintTrace('n_tick', 'n_move', 'add_movement_input', {'world_dir': Vector3(0.0, 1.0, 0.0), 'scale_val': 0.5, 'force': false});
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
