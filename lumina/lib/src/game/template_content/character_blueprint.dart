part of '../template_content.dart';

/// The document [LuminaThirdPersonContent.characterBlueprint] returns.
LuminaBlueprintDocument _thirdPersonCharacterBlueprint({
  required List<LuminaInputAction> inputActions,
  required bool withMesh,
  required String meshAsset,
}) {
  final variables = [
    const LuminaBlueprintVariable(
      name: 'LookSensitivity',
      typeName: 'Float',
      defaultValue: LuminaTemplateCharacterTuning.lookSensitivity,
    ),
  ];
  final context = LuminaBlueprintTypeContext(variables: variables, inputActions: inputActions);
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);

  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  // One comment box per event chain, stacked top to bottom;
  // LuminaBlueprintGraphLayout places the nodes.
  final sections = [
    // Move: forward/right of the control yaw, scaled by the stick. Free look:
    // while Alt is held the body heading, not the orbiting
    // camera's yaw, drives the move.
    LuminaBlueprintGraphSection('Move', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'move', {'action': 'IA_Move'}),
      place('break_vector2d', 'move_axis'),
      place('get_control_rotation', 'control'),
      place('break_rotator', 'control_parts'),
      place('get_actor_rotation', 'body'),
      place('break_rotator', 'body_parts'),
      place('is_free_looking', 'free_looking'),
      place('select_float', 'move_yaw'),
      place('make_rotator', 'yaw_only'),
      place('get_forward_vector', 'forward'),
      place('get_right_vector', 'right'),
      place('add_movement_input', 'move_forward'),
      place('add_movement_input', 'move_right'),
    ]),
    // Look: mouse delta × LookSensitivity → controller yaw / pitch.
    LuminaBlueprintGraphSection('Look', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'look', {'action': 'IA_Look'}),
      place('break_vector2d', 'look_axis'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'sensitivity', {'variable': 'LookSensitivity'}),
      place('float_multiply', 'yaw_scaled'),
      place('float_multiply', 'pitch_scaled'),
      place('add_controller_yaw_input', 'yaw'),
      place('add_controller_pitch_input', 'pitch'),
    ]),
    // Jump: Started → Jump, Completed → Stop Jumping.
    LuminaBlueprintGraphSection('Jump', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'jump_input', {'action': 'IA_Jump'}),
      place('jump', 'jump'),
      place('stop_jumping', 'stop_jumping'),
    ]),
    // Sprint: held IA_Sprint raises the walk speed cap and
    // tells the anim instance; releasing (or cancelling) restores the walk.
    LuminaBlueprintGraphSection('Sprint', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'sprint_input', {'action': 'IA_Sprint'}),
      place('set_max_walk_speed', 'sprint_speed', {'max_walk_speed': LuminaTemplateCharacterTuning.thirdPersonSprintSpeed}),
      place('set_anim_variable', 'start_sprint', {'name': 'IsSprinting', 'type': 'boolean', 'value': true}),
      place('set_max_walk_speed', 'walk_speed', {'max_walk_speed': LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed}),
      place('set_anim_variable', 'end_sprint', {'name': 'IsSprinting', 'type': 'boolean', 'value': false}),
    ]),
    // Dash: Started → IsDashing, a launch along the move yaw
    // (XY override; Move's forward vector, see characterBlueprintCrossBoxWires),
    // and a timer whose custom event clears IsDashing.
    LuminaBlueprintGraphSection('Dash', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'dash_input', {'action': 'IA_Dash'}),
      place('set_anim_variable', 'start_dash', {'name': 'IsDashing', 'type': 'boolean', 'value': true}),
      place('vector_scale', 'dash_velocity', {'b': LuminaThirdPersonContent.dashSpeed}),
      place('launch_character', 'dash', {'xy_override': true, 'z_override': false}),
      place(LuminaBlueprintNodeLibrary.customEvent, 'dash_done', {'name': 'DashFinished'}),
      place('set_timer_by_event', 'dash_timer', {'time': LuminaThirdPersonContent.dashSeconds, 'looping': false}),
      place('set_anim_variable', 'end_dash', {'name': 'IsDashing', 'type': 'boolean', 'value': false}),
    ]),
    // Free look: held IA_FreeLook (Left Alt) orbits the
    // camera while the body keeps its heading and ABP_Character turns the head.
    LuminaBlueprintGraphSection('Free Look', [
      place(LuminaBlueprintNodeLibrary.enhancedInputAction, 'free_look_input', {'action': 'IA_FreeLook'}),
      place('set_free_look', 'start_free_look', {'enabled': true}),
      place('set_free_look', 'end_free_look', {'enabled': false}),
    ]),
    // Tick: WallAhead from a short trace along the look direction.
    LuminaBlueprintGraphSection('Wall Trace', [
      place('event_tick', 'tick'),
      place('line_trace_forward', 'wall_trace', {'distance': LuminaThirdPersonContent.wallTraceDistance}),
      place('set_anim_variable', 'set_wall_ahead', {'name': 'WallAhead', 'type': 'boolean'}),
    ]),
  ];
  final wires = [
    wire('move', 'action_value', 'move_axis', 'in_vec'),
    wire('control', 'return_value', 'control_parts', 'in_rot'),
    wire('body', 'return_value', 'body_parts', 'in_rot'),
    wire('body_parts', 'z', 'move_yaw', 'a'),
    wire('control_parts', 'z', 'move_yaw', 'b'),
    wire('free_looking', 'return_value', 'move_yaw', 'pick_a'),
    wire('move_yaw', 'return_value', 'yaw_only', 'z'),
    wire('yaw_only', 'return_value', 'forward', 'in_rot'),
    wire('yaw_only', 'return_value', 'right', 'in_rot'),
    wire('move', 'triggered', 'move_forward', 'exec_move_in'),
    wire('forward', 'return_value', 'move_forward', 'world_dir'),
    wire('move_axis', 'y', 'move_forward', 'scale_val'),
    wire('move_forward', 'exec_move_out', 'move_right', 'exec_move_in'),
    wire('right', 'return_value', 'move_right', 'world_dir'),
    wire('move_axis', 'x', 'move_right', 'scale_val'),
    wire('look', 'action_value', 'look_axis', 'in_vec'),
    wire('look_axis', 'x', 'yaw_scaled', 'a'),
    wire('sensitivity', 'value', 'yaw_scaled', 'b'),
    wire('look_axis', 'y', 'pitch_scaled', 'a'),
    wire('sensitivity', 'value', 'pitch_scaled', 'b'),
    wire('look', 'triggered', 'yaw', 'exec_in'),
    wire('yaw_scaled', 'return_value', 'yaw', 'val'),
    wire('yaw', 'exec_out', 'pitch', 'exec_in'),
    wire('pitch_scaled', 'return_value', 'pitch', 'val'),
    wire('jump_input', 'started', 'jump', 'exec_in'),
    wire('jump_input', 'completed', 'stop_jumping', 'exec_in'),
    wire('sprint_input', 'started', 'sprint_speed', 'exec_in'),
    wire('sprint_speed', 'exec_out', 'start_sprint', 'exec_in'),
    wire('sprint_input', 'completed', 'walk_speed', 'exec_in'),
    wire('sprint_input', 'canceled', 'walk_speed', 'exec_in'),
    wire('walk_speed', 'exec_out', 'end_sprint', 'exec_in'),
    wire('dash_input', 'started', 'start_dash', 'exec_in'),
    wire('start_dash', 'exec_out', 'dash', 'exec_in'),
    wire('forward', 'return_value', 'dash_velocity', 'a'),
    wire('dash_velocity', 'return_value', 'dash', 'launch_velocity'),
    wire('dash', 'exec_out', 'dash_timer', 'exec_in'),
    wire('dash_done', 'delegate', 'dash_timer', 'event'),
    wire('dash_done', 'exec_out', 'end_dash', 'exec_in'),
    wire('free_look_input', 'started', 'start_free_look', 'exec_in'),
    wire('free_look_input', 'completed', 'end_free_look', 'exec_in'),
    wire('free_look_input', 'canceled', 'end_free_look', 'exec_in'),
    wire('tick', 'exec_tick_out', 'wall_trace', 'exec_in'),
    wire('wall_trace', 'exec_out', 'set_wall_ahead', 'exec_in'),
    wire('wall_trace', 'return_value', 'set_wall_ahead', 'value'),
  ];

  return LuminaBlueprintDocument(
    parentClass: 'LuminaCharacter',
    components: [
      LuminaBlueprintComponent(
        id: 'capsule',
        name: 'CapsuleComponent',
        type: 'LuminaCapsuleComponent',
        properties: {
          'capsuleRadius': LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius,
          'capsuleHalfHeight': LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight,
        },
      ),
      LuminaBlueprintComponent(
        id: 'boom',
        name: 'CameraBoom',
        type: 'LuminaSpringArmComponent',
        parentId: 'capsule',
        properties: {
          'location': [0.0, 0.0, LuminaTemplateCharacterTuning.boomHeight],
          'targetArmLength': LuminaTemplateCharacterTuning.boomLength,
          'usePawnControlRotation': true,
          'enableCameraLag': true,
          'cameraLagSpeed': LuminaTemplateCharacterTuning.cameraLagSpeed,
          'enableCameraRotationLag': true,
          'cameraRotationLagSpeed': LuminaTemplateCharacterTuning.cameraRotationLagSpeed,
          'doCollisionTest': true,
          'probeSize': LuminaTemplateCharacterTuning.boomProbeSize,
        },
      ),
      LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
      LuminaBlueprintComponent(
        id: 'movement',
        name: 'CharacterMovement',
        type: 'LuminaCharacterMovementComponent',
        isSceneComponent: false,
        properties: {
          'maxWalkSpeed': LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed,
          'jumpZVelocity': LuminaTemplateCharacterTuning.jumpZVelocity,
          'airControl': LuminaTemplateCharacterTuning.airControl,
          'jumpCutMultiplier': LuminaTemplateCharacterTuning.jumpCutMultiplier,
        },
      ),
      if (withMesh)
        LuminaBlueprintComponent(
          id: 'mesh',
          name: 'Mesh',
          type: 'LuminaSkeletalMeshComponent',
          parentId: 'capsule',
          properties: {
            'skeletalMeshAsset': meshAsset,
            'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
            'animMode': 'Use Animation Blueprint',
            'animClass': LuminaThirdPersonContent.projectAnimBlueprintPath,
          },
        ),
    ],
    eventGraph: LuminaBlueprintGraph(nodes: LuminaBlueprintGraphLayout.stack(sections, wires: wires), wires: wires),
    variables: variables,
    classDefaults: {
      'bUseControllerRotationYaw': true,
      'baseEyeHeight': LuminaTemplateCharacterTuning.baseEyeHeight,
    },
  );
}
