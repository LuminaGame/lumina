import 'package:lumina/src/animation/locomotion_clip_set.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/graph_layout.dart';
import 'package:lumina/src/blueprint/node_library.dart';
import 'package:lumina/src/input/input_action.dart';
import 'package:lumina/src/game/template_character.dart';
import 'package:lumina/src/game/template_clips.dart';

export 'package:lumina/src/game/template_clips.dart';

/// The art the Third Person template ships: a CC0 character with its idle,
/// eight-direction walk / jog and movement clips merged into one GLB, so a
/// single gltfio asset (one animator) plays them all.
///
/// `tool/build_third_person_content.dart` builds [bundledMeshPath] from the
/// Quaternius packs listed in `assets/templates/third_person/LICENSE.txt`.
/// The file is **not** a Flutter
/// asset of this package — that would ship it inside every game that depends
/// on lumina. Project scaffolding reads it from the engine package on disk and
/// copies it into the new project's `contents/`.
class LuminaThirdPersonContent {
  const LuminaThirdPersonContent._();

  /// Name of the skeletal mesh asset, in the bundle and in a project.
  static const String meshAssetName = LuminaThirdPersonClips.meshAssetName;

  /// The merged GLB, relative to the lumina package root.
  static const String bundledMeshPath = LuminaThirdPersonClips.bundledMeshPath;

  /// Where a Third Person project keeps the mesh asset and its GLB companion.
  static const String projectMeshAssetPath = 'contents/meshes/skeletal/$meshAssetName.lmas';
  static const String projectMeshGlbPath = 'contents/meshes/skeletal/$meshAssetName.entity.glb';

  /// Folder of the per-clip animation assets that reference the mesh.
  static const String projectAnimationDir = 'contents/animations/$meshAssetName';

  static const String idleClip = LuminaThirdPersonClips.idle;

  /// The walk cycle per direction; see [LuminaThirdPersonClips.walks].
  static const Map<LuminaLocomotionDirection, String> walkClips = {
    LuminaLocomotionDirection.forward: 'Walk_Fwd_Loop',
    LuminaLocomotionDirection.forwardRight: 'Walk_Fwd_Right_Loop',
    LuminaLocomotionDirection.right: 'Walk_Right_Loop',
    LuminaLocomotionDirection.backwardRight: 'Walk_Bwd_Right_Loop',
    LuminaLocomotionDirection.backward: 'Walk_Bwd_Loop',
    LuminaLocomotionDirection.backwardLeft: 'Walk_Bwd_Left_Loop',
    LuminaLocomotionDirection.left: 'Walk_Left_Loop',
    LuminaLocomotionDirection.forwardLeft: 'Walk_Fwd_Left_Loop',
  };

  /// The jog cycle per direction: the sprint row of
  /// [locomotionBlendSpace].
  static const Map<LuminaLocomotionDirection, String> jogClips = {
    LuminaLocomotionDirection.forward: 'Jog_Fwd_Loop',
    LuminaLocomotionDirection.forwardRight: 'Jog_Fwd_Right_Loop',
    LuminaLocomotionDirection.right: 'Jog_Right_Loop',
    LuminaLocomotionDirection.backwardRight: 'Jog_Bwd_Right_Loop',
    LuminaLocomotionDirection.backward: 'Jog_Bwd_Loop',
    LuminaLocomotionDirection.backwardLeft: 'Jog_Bwd_Left_Loop',
    LuminaLocomotionDirection.left: 'Jog_Left_Loop',
    LuminaLocomotionDirection.forwardLeft: 'Jog_Fwd_Left_Loop',
  };

  /// Every clip in the bundle, in the order the tool merges them (which is the
  /// gltfio animation index order); see [LuminaThirdPersonClips.names].
  static const List<String> clipNames = LuminaThirdPersonClips.names;

  static const String jumpClip = LuminaThirdPersonClips.jump;
  static const String fallLoopClip = LuminaThirdPersonClips.fallLoop;
  static const String landClip = LuminaThirdPersonClips.land;
  static const String dashClip = LuminaThirdPersonClips.dash;
  static const String wallJumpClip = LuminaThirdPersonClips.wallJump;

  /// The idle breaks one of which plays after standing still a while.
  static const List<String> idleBreakClips = LuminaThirdPersonClips.idleBreaks;

  /// Turn-in-place clips by the yaw (degrees, right positive) each turns
  /// through; see [LuminaThirdPersonClips.turns].
  static const Map<String, double> turnClips = LuminaThirdPersonClips.turns;

  /// Ground speed at which the walk clips play at rate 1 without foot slide.
  ///
  /// Measured by forward kinematics on the bundled clips: the planted
  /// `ball_l` / `ball_r` moves back at 1.0 m/s relative to `root`, a stroll.
  static const double walkReferenceSpeed = 100.0; // cm/s

  /// Ground speed at which the jog clips play at rate 1 without foot slide.
  /// Measured the same way as [walkReferenceSpeed]: 6.0 m/s, a fast run, so
  /// the held sprint (480 cm/s) plays it at 0.8×.
  static const double jogReferenceSpeed = 600.0; // cm/s

  /// Idle + eight-way walk + eight-way jog for the character.
  static const LuminaLocomotionClipSet mannequinLocomotion = LuminaLocomotionClipSet(
    idle: idleClip,
    walk: walkClips,
    walkReferenceSpeed: walkReferenceSpeed,
    jog: jogClips,
    jogReferenceSpeed: jogReferenceSpeed,
    // The walk speed cap (300 cm/s) plays the walk cycle at 3×.
    maxWalkRate: maxWalkRate,
  );

  /// Play-rate ceiling of the walk cycle; see [mannequinLocomotion].
  static const double maxWalkRate = 3.0;

  /// The character's Animation Blueprint and walk blend space,
  /// as a Third Person project stores them.
  static const String animBlueprintName = 'ABP_Character';
  static const String walkBlendSpaceName = 'BS_Walk';
  static const String projectAnimBlueprintPath = '$projectAnimationDir/$animBlueprintName.lmas';
  static const String projectWalkBlendSpacePath = '$projectAnimationDir/$walkBlendSpaceName.lmas';

  /// The 2D Direction × Speed locomotion blend space ABP_Character's Walk state
  /// plays; `BS_Walk` stays for projects scaffolded earlier.
  static const String locomotionBlendSpaceName = 'BS_Locomotion';
  static const String projectLocomotionBlendSpacePath = '$projectAnimationDir/$locomotionBlendSpaceName.lmas';

  /// Every blend space a Third Person project ships, by asset path.
  static Map<String, LuminaBlendSpaceDocument> get blendSpaces => {
        projectWalkBlendSpacePath: walkBlendSpace,
        projectLocomotionBlendSpacePath: locomotionBlendSpace,
      };

  /// The template's character and game mode Blueprints.
  static const String characterBlueprintName = 'BP_ThirdPersonCharacter';
  static const String gameModeBlueprintName = 'BP_ThirdPersonGameMode';
  static const String characterBlueprintPath = 'contents/blueprints/$characterBlueprintName.lmas';
  static const String gameModeBlueprintPath = 'contents/blueprints/$gameModeBlueprintName.lmas';

  /// The wires of [characterBlueprint]'s Event Graph that cross comment boxes
  /// on purpose, as (from node, from pin, to node, to pin). The only one is
  /// the Dash launching along the Move box's pure `Get Forward Vector`, which
  /// is the free-look-aware move yaw's forward. It is a data read, not an exec
  /// link, so no event runs another's chain.
  static const List<(String, String, String, String)> characterBlueprintCrossBoxWires = [
    ('forward', 'return_value', 'dash_velocity', 'a'),
  ];

  /// `LuminaTemplateCharacter(thirdPerson: true)` as a Character Blueprint:
  /// its components and tuning, the character mesh animated by [animBlueprint]
  /// (unless [withMesh] is false), the Third Person Move / Look / Jump
  /// graph, a held IA_Sprint (the walk speed cap raised to
  /// [LuminaTemplateCharacterTuning.thirdPersonSprintSpeed]), an IA_Dash
  /// launch and a Tick wall trace for ABP_Character. Authoring space throughout (cm, Z up). [inputActions] type
  /// the Enhanced Input event nodes; [meshAsset] is the character mesh reference.
  static LuminaBlueprintDocument characterBlueprint({
    List<LuminaInputAction> inputActions = const [],
    bool withMesh = true,
    String meshAsset = projectMeshAssetPath,
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
        place('vector_scale', 'dash_velocity', {'b': dashSpeed}),
        place('launch_character', 'dash', {'xy_override': true, 'z_override': false}),
        place(LuminaBlueprintNodeLibrary.customEvent, 'dash_done', {'name': 'DashFinished'}),
        place('set_timer_by_event', 'dash_timer', {'time': dashSeconds, 'looping': false}),
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
        place('line_trace_forward', 'wall_trace', {'distance': wallTraceDistance}),
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
              'animClass': projectAnimBlueprintPath,
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

  /// The template's game mode: [characterBlueprint] as the Default Pawn Class.
  static LuminaBlueprintDocument get gameModeBlueprint => LuminaBlueprintDocument(
        parentClass: 'LuminaGameMode',
        classDefaults: {
          'defaultPawnClass': characterBlueprintPath,
          'playerControllerClass': 'LuminaPlayerController',
        },
      );

  /// The eight walk cycles on a Direction axis (degrees, right positive, as
  /// `calculate_direction` gives it); backward sits at both ends.
  static LuminaBlendSpaceDocument get walkBlendSpace => LuminaBlendSpaceDocument(
        axes: const [LuminaBlendSpaceAxis('Direction', -180.0, 180.0)],
        samples: [
          LuminaBlendSpaceSample(walkClips[LuminaLocomotionDirection.backward]!, -180.0),
          for (final (i, d) in LuminaLocomotionDirection.values.indexed)
            LuminaBlendSpaceSample(walkClips[d]!, i <= 4 ? i * 45.0 : (i - 8) * 45.0),
        ]..sort((a, b) => a.x.compareTo(b.x)),
      );

  /// The locomotion blend space: Direction (degrees,
  /// right positive) × Speed (cm/s). The walk clips sit on the
  /// [walkReferenceSpeed] row and the jog clips on the [jogReferenceSpeed]
  /// row, each row with backward at both ends of the direction ring.
  static LuminaBlendSpaceDocument get locomotionBlendSpace => LuminaBlendSpaceDocument(
        axes: const [LuminaBlendSpaceAxis('Direction', -180.0, 180.0), LuminaBlendSpaceAxis('Speed', 0.0, jogReferenceSpeed)],
        samples: [
          for (final (clips, speed) in [(walkClips, walkReferenceSpeed), (jogClips, jogReferenceSpeed)]) ...[
            LuminaBlendSpaceSample(clips[LuminaLocomotionDirection.backward]!, -180.0, speed),
            for (final (i, d) in LuminaLocomotionDirection.values.indexed)
              LuminaBlendSpaceSample(clips[d]!, i <= 4 ? i * 45.0 : (i - 8) * 45.0, speed),
          ],
        ]..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x)),
      );

  /// Seconds of standing still before an idle break may start (the
  /// break also waits for the idle clip to have played through once).
  static const double idleBreakAfterSeconds = 6.0;

  /// Root yaw offsets (degrees, absolute) beyond which a standing character
  /// turns in place with a 90° / 180° clip, when [turnClips] has them.
  static const double turn90Degrees = 60.0;
  static const double turn180Degrees = 135.0;

  /// Seconds into the jump clip after which still falling hands over to the fall loop.
  static const double jumpToFallAfterSeconds = 0.3;

  /// The dash: IA_Dash (Left Ctrl) launches the character at [dashSpeed]
  /// (cm/s, along the control yaw, replacing the horizontal velocity) and
  /// keeps `IsDashing` for [dashSeconds]; the roll gives way to the walk
  /// after [dashWalkAfterSeconds] (once the character is back on its feet)
  /// when still moving, or plays through into Idle.
  static const double dashSpeed = 600.0;
  static const double dashSeconds = 0.4;
  static const double dashWalkAfterSeconds = 1.2;

  /// How far ahead of the eyes the character's Tick looks for a wall
  /// (`WallAhead`, the wall jump's condition).
  static const double wallTraceDistance = 60.0;

  /// [mannequinLocomotion] and the rest of the movement set as an Animation
  /// Blueprint. The update graph stores the
  /// pawn's ground speed, walk direction, falling state, whether it is rising
  /// (falling with upward velocity: it just jumped) and how long it has stood
  /// still. The state machine idles below the idle threshold, walks the
  /// [locomotionBlendSpace] at a rate matched to the ground speed, plays the
  /// jump → fall loop → land clips through the air (the wall jump clip when
  /// rising into a wall the character's Tick trace reports as `WallAhead`),
  /// the dash clip while the character's IA_Dash graph holds `IsDashing`,
  /// and one of the idle breaks after [idleBreakAfterSeconds] of standing (the
  /// instance's reserved `StateTime` and `ClipFinished` variables). With
  /// [turnClips], a standing character keeps its feet planted and turns in
  /// place once the controller has turned it past [turn90Degrees] /
  /// [turn180Degrees] (`RootYawOffset`); without them it turns with its
  /// capsule. Every transition blends over the template's crossfade.
  static LuminaAnimBlueprintDocument get animBlueprint => animBlueprintWith();

  /// [animBlueprint] for a bundle with the turn-in-place clips [turns]
  /// (clip name → yaw in degrees, right positive; the 90° and 180° turns each
  /// way that have a clip get a state).
  static LuminaAnimBlueprintDocument animBlueprintWith({Map<String, double> turns = turnClips}) {
    const locomotion = mannequinLocomotion;
    final variables = [
      const LuminaBlueprintVariable(name: 'GroundSpeed', typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: 'Direction', typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: 'IsFalling', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'IsRising', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'IdleTime', typeName: 'Float', defaultValue: 0.0),
      // Written by BP_ThirdPersonCharacter (Set Anim Variable): the held
      // sprint (the walk cycle simply follows GroundSpeed), the dash impulse
      // for dashSeconds, and whether its wall trace hit.
      const LuminaBlueprintVariable(name: 'IsSprinting', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'IsDashing', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'WallAhead', typeName: 'Bool', defaultValue: false),
      // The aim offset's inputs: the controller's yaw / pitch
      // relative to the body, wrapped to ±180.
      const LuminaBlueprintVariable(name: 'AimYaw', typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: 'AimPitch', typeName: 'Float', defaultValue: 0.0),
      // Written by LuminaAnimBlueprintInstance before every update.
      const LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.stateTimeVariable, typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(
          name: LuminaAnimBlueprintInstance.clipFinishedVariable, typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(
          name: LuminaAnimBlueprintInstance.rootYawOffsetVariable, typeName: 'Float', defaultValue: 0.0),
    ];
    final context = LuminaBlueprintTypeContext(variables: variables);
    LuminaBlueprintNode place(String id, String nodeId, double x, double y, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, x: x, y: y, literals: literals, context: context);
    LuminaBlueprintWire wire(String id, String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    LuminaBlueprintNode get(String variable, String nodeId, double y) =>
        place(LuminaBlueprintNodeLibrary.variableGet, nodeId, 0, y, {'variable': variable});

    final update = LuminaBlueprintGraph(
      nodes: [
        place(LuminaBlueprintNodeLibrary.updateAnimation, 'update', 0, 0),
        place('get_velocity', 'velocity', 0, 160),
        place('get_actor_rotation', 'rotation', 0, 260),
        place('is_falling', 'falling', 0, 360),
        place('vector_length_xy', 'speed', 240, 160),
        place('calculate_direction', 'direction', 240, 260),
        place('break_vector', 'velocity_parts', 240, 460),
        place('float_greater', 'upward', 480, 460, {'b': 0.0}),
        place('bool_and', 'rising', 720, 460),
        place('float_less', 'still', 480, 160, {'b': locomotion.idleSpeedThreshold}),
        place(LuminaBlueprintNodeLibrary.variableGet, 'idle_time', 960, 560, {'variable': 'IdleTime'}),
        place('float_add', 'idle_time_plus', 1200, 560),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_speed', 480, 0, {'variable': 'GroundSpeed'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_direction', 720, 0, {'variable': 'Direction'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_falling', 960, 0, {'variable': 'IsFalling'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_rising', 1200, 0, {'variable': 'IsRising'}),
        // AimYaw / AimPitch = control rotation − actor rotation, wrapped.
        place('get_control_rotation', 'control', 0, 660),
        place('break_rotator', 'control_parts', 240, 660),
        place('break_rotator', 'body_parts', 240, 800),
        place('float_subtract', 'yaw_delta', 480, 660),
        place('float_subtract', 'pitch_delta', 480, 800),
        place('normalize_axis', 'aim_yaw', 720, 660),
        place('normalize_axis', 'aim_pitch', 720, 800),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_aim_yaw', 1440, 0, {'variable': 'AimYaw'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set_aim_pitch', 1680, 0, {'variable': 'AimPitch'}),
        place('branch', 'if_still', 1920, 0),
        place(LuminaBlueprintNodeLibrary.variableSet, 'add_idle_time', 2160, -80, {'variable': 'IdleTime'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'reset_idle_time', 2160, 120, {'variable': 'IdleTime', 'value': 0.0}),
      ],
      wires: [
        wire('w0', 'update', 'exec_out', 'set_speed', 'exec_in'),
        wire('w1', 'velocity', 'return_value', 'speed', 'in_vec'),
        wire('w2', 'speed', 'return_value', 'set_speed', 'value'),
        wire('w3', 'set_speed', 'exec_out', 'set_direction', 'exec_in'),
        wire('w4', 'velocity', 'return_value', 'direction', 'velocity'),
        wire('w5', 'rotation', 'return_value', 'direction', 'base_rotation'),
        wire('w6', 'direction', 'return_value', 'set_direction', 'value'),
        wire('w7', 'set_direction', 'exec_out', 'set_falling', 'exec_in'),
        wire('w8', 'falling', 'return_value', 'set_falling', 'value'),
        // IsRising = IsFalling && velocity.z > 0 (authoring space, Z up).
        wire('w9', 'set_falling', 'exec_out', 'set_rising', 'exec_in'),
        wire('w10', 'velocity', 'return_value', 'velocity_parts', 'in_vec'),
        wire('w11', 'velocity_parts', 'z', 'upward', 'a'),
        wire('w12', 'falling', 'return_value', 'rising', 'a'),
        wire('w13', 'upward', 'return_value', 'rising', 'b'),
        wire('w14', 'rising', 'return_value', 'set_rising', 'value'),
        // IdleTime accumulates while standing and resets on the first step.
        wire('w15', 'set_rising', 'exec_out', 'set_aim_yaw', 'exec_in'),
        wire('w23', 'control', 'return_value', 'control_parts', 'in_rot'),
        wire('w24', 'rotation', 'return_value', 'body_parts', 'in_rot'),
        wire('w25', 'control_parts', 'z', 'yaw_delta', 'a'),
        wire('w26', 'body_parts', 'z', 'yaw_delta', 'b'),
        wire('w27', 'yaw_delta', 'return_value', 'aim_yaw', 'angle'),
        wire('w28', 'aim_yaw', 'return_value', 'set_aim_yaw', 'value'),
        wire('w29', 'set_aim_yaw', 'exec_out', 'set_aim_pitch', 'exec_in'),
        wire('w30', 'control_parts', 'x', 'pitch_delta', 'a'),
        wire('w31', 'body_parts', 'x', 'pitch_delta', 'b'),
        wire('w32', 'pitch_delta', 'return_value', 'aim_pitch', 'angle'),
        wire('w33', 'aim_pitch', 'return_value', 'set_aim_pitch', 'value'),
        wire('w34', 'set_aim_pitch', 'exec_out', 'if_still', 'exec_in'),
        wire('w16', 'speed', 'return_value', 'still', 'a'),
        wire('w17', 'still', 'return_value', 'if_still', 'condition'),
        wire('w18', 'if_still', 'true_out', 'add_idle_time', 'exec_in'),
        wire('w19', 'idle_time', 'value', 'idle_time_plus', 'a'),
        wire('w20', 'update', 'delta_time_x', 'idle_time_plus', 'b'),
        wire('w21', 'idle_time_plus', 'return_value', 'add_idle_time', 'value'),
        wire('w22', 'if_still', 'false_out', 'reset_idle_time', 'exec_in'),
      ],
    );

    // Rules. Lower priority is checked first, so the air wins over speed.
    LuminaBlueprintNode result(double x) => place(LuminaBlueprintNodeLibrary.transitionResult, 'result', x, 0);

    /// A bool variable, optionally negated.
    LuminaBlueprintGraph flag(String variable, {bool not = false}) => LuminaBlueprintGraph(
          nodes: [get(variable, 'flag', 0), if (not) place('bool_not', 'not', 240, 0), result(480)],
          wires: [
            if (not) ...[wire('w0', 'flag', 'value', 'not', 'a'), wire('w1', 'not', 'return_value', 'result', 'can_enter')] else
              wire('w0', 'flag', 'value', 'result', 'can_enter'),
          ],
        );

    /// [a] && ![b].
    LuminaBlueprintGraph andNot(String a, String b) => LuminaBlueprintGraph(
          nodes: [
            get(a, 'flag', 0),
            get(b, 'other', 120),
            place('bool_not', 'not_other', 240, 120),
            place('bool_and', 'both', 480, 60),
            result(720),
          ],
          wires: [
            wire('w0', 'other', 'value', 'not_other', 'a'),
            wire('w1', 'flag', 'value', 'both', 'a'),
            wire('w2', 'not_other', 'return_value', 'both', 'b'),
            wire('w3', 'both', 'return_value', 'result', 'can_enter'),
          ],
        );

    /// [a] && [b].
    LuminaBlueprintGraph and(String a, String b) => LuminaBlueprintGraph(
          nodes: [get(a, 'flag', 0), get(b, 'other', 120), place('bool_and', 'both', 480, 60), result(720)],
          wires: [
            wire('w0', 'flag', 'value', 'both', 'a'),
            wire('w1', 'other', 'value', 'both', 'b'),
            wire('w2', 'both', 'return_value', 'result', 'can_enter'),
          ],
        );

    /// IsFalling but not IsRising: airborne without having just jumped.
    LuminaBlueprintGraph droppedOff() => andNot('IsFalling', 'IsRising');

    /// GroundSpeed below (or not below) the idle threshold, optionally only
    /// once IsFalling is false again.
    LuminaBlueprintGraph slow({required bool below, bool landed = false}) {
      final nodes = [
        get('GroundSpeed', 'speed', 0),
        place('float_less', 'below', 240, 0, {'b': locomotion.idleSpeedThreshold}),
        if (!below) place('bool_not', 'moving', 480, 0),
        if (landed) ...[get('IsFalling', 'falling', 120), place('bool_not', 'grounded', 240, 120), place('bool_and', 'both', 720, 60)],
        result(960),
      ];
      final speedOut = below ? ('below', 'return_value') : ('moving', 'return_value');
      return LuminaBlueprintGraph(nodes: nodes, wires: [
        wire('w0', 'speed', 'value', 'below', 'a'),
        if (!below) wire('w1', 'below', 'return_value', 'moving', 'a'),
        if (landed) ...[
          wire('w2', 'falling', 'value', 'grounded', 'a'),
          wire('w3', 'grounded', 'return_value', 'both', 'a'),
          wire('w4', speedOut.$1, speedOut.$2, 'both', 'b'),
          wire('w5', 'both', 'return_value', 'result', 'can_enter'),
        ] else
          wire('w5', speedOut.$1, speedOut.$2, 'result', 'can_enter'),
      ]);
    }

    /// ClipFinished, or StateTime past [after] while IsFalling (a long jump
    /// hands over to the fall loop before the jump clip ends).
    LuminaBlueprintGraph jumpDone() => LuminaBlueprintGraph(
          nodes: [
            get(LuminaAnimBlueprintInstance.clipFinishedVariable, 'finished', 0),
            get(LuminaAnimBlueprintInstance.stateTimeVariable, 'time', 120),
            place('float_greater', 'late', 240, 120, {'b': jumpToFallAfterSeconds}),
            get('IsFalling', 'falling', 240),
            place('bool_and', 'still_falling', 480, 180),
            place('bool_or', 'either', 720, 60),
            result(960),
          ],
          wires: [
            wire('w0', 'time', 'value', 'late', 'a'),
            wire('w1', 'late', 'return_value', 'still_falling', 'a'),
            wire('w2', 'falling', 'value', 'still_falling', 'b'),
            wire('w3', 'finished', 'value', 'either', 'a'),
            wire('w4', 'still_falling', 'return_value', 'either', 'b'),
            wire('w5', 'either', 'return_value', 'result', 'can_enter'),
          ],
        );

    /// The dash impulse is over and the character keeps walking on the
    /// ground: !IsDashing && !IsFalling && GroundSpeed above the threshold.
    LuminaBlueprintGraph dashIntoWalk() => LuminaBlueprintGraph(
          nodes: [
            get('IsDashing', 'dashing', 0),
            place('bool_not', 'not_dashing', 240, 0),
            get('IsFalling', 'falling', 120),
            place('bool_not', 'grounded', 240, 120),
            get('GroundSpeed', 'speed', 240),
            place('float_less', 'below', 240, 240, {'b': locomotion.idleSpeedThreshold}),
            place('bool_not', 'moving', 480, 240),
            place('bool_and', 'settled', 720, 60),
            place('bool_and', 'all', 960, 120),
            result(1200),
          ],
          wires: [
            wire('w0', 'dashing', 'value', 'not_dashing', 'a'),
            wire('w1', 'falling', 'value', 'grounded', 'a'),
            wire('w2', 'speed', 'value', 'below', 'a'),
            wire('w3', 'below', 'return_value', 'moving', 'a'),
            wire('w4', 'not_dashing', 'return_value', 'settled', 'a'),
            wire('w5', 'grounded', 'return_value', 'settled', 'b'),
            wire('w6', 'settled', 'return_value', 'all', 'a'),
            wire('w7', 'moving', 'return_value', 'all', 'b'),
            wire('w8', 'all', 'return_value', 'result', 'can_enter'),
          ],
        );

    /// ClipFinished while IdleTime is past the idle-break delay.
    LuminaBlueprintGraph idleBreakDue() => LuminaBlueprintGraph(
          nodes: [
            get('IdleTime', 'idle_time', 0),
            place('float_greater', 'waited', 240, 0, {'b': idleBreakAfterSeconds}),
            get(LuminaAnimBlueprintInstance.clipFinishedVariable, 'finished', 120),
            place('bool_and', 'both', 480, 60),
            result(720),
          ],
          wires: [
            wire('w0', 'idle_time', 'value', 'waited', 'a'),
            wire('w1', 'waited', 'return_value', 'both', 'a'),
            wire('w2', 'finished', 'value', 'both', 'b'),
            wire('w3', 'both', 'return_value', 'result', 'can_enter'),
          ],
        );

    /// RootYawOffset beyond [degrees] in the turn's direction: a right turn
    /// leaves the planted mesh at a negative offset. With [upTo], only up to
    /// that magnitude (the 90° band under the 180° band).
    LuminaBlueprintGraph turnDue({required bool right, required double degrees, double? upTo}) {
      final offset = LuminaAnimBlueprintInstance.rootYawOffsetVariable;
      final beyond = right ? 'float_less' : 'float_greater';
      final within = right ? 'float_greater' : 'float_less';
      final sign = right ? -1.0 : 1.0;
      return LuminaBlueprintGraph(
        nodes: [
          get(offset, 'offset', 0),
          place(beyond, 'beyond', 240, 0, {'b': sign * degrees}),
          if (upTo != null) ...[place(within, 'within', 240, 120, {'b': sign * upTo}), place('bool_and', 'band', 480, 60)],
          result(720),
        ],
        wires: [
          wire('w0', 'offset', 'value', 'beyond', 'a'),
          if (upTo != null) ...[
            wire('w1', 'offset', 'value', 'within', 'a'),
            wire('w2', 'beyond', 'return_value', 'band', 'a'),
            wire('w3', 'within', 'return_value', 'band', 'b'),
            wire('w4', 'band', 'return_value', 'result', 'can_enter'),
          ] else
            wire('w4', 'beyond', 'return_value', 'result', 'can_enter'),
        ],
      );
    }

    const blend = 0.2; // LuminaTemplateCharacterTuning.locomotionCrossFade
    const turnBlend = 0.3;
    LuminaAnimTransition go(String from, String to, LuminaBlueprintGraph rule,
            {int priority = 0, double blendDuration = blend, double minStateTime = 0.0}) =>
        LuminaAnimTransition(
            id: '${from.toLowerCase()}_to_${to.toLowerCase()}',
            from: from,
            to: to,
            blendDuration: blendDuration,
            priority: priority,
            minStateTime: minStateTime,
            rule: rule);

    /// Leaving a grounded state: the dash first (its launch puts the
    /// character into falling for a frame, so it must win over the drop),
    /// then a jump, then a drop.
    List<LuminaAnimTransition> airborne(String from) => [
          go(from, 'Dash', flag('IsDashing'), priority: 0),
          go(from, 'Jump', flag('IsRising'), priority: 1),
          go(from, 'FallLoop', droppedOff(), priority: 2),
        ];

    /// Rising into a wall: the wall jump (checked before landing).
    LuminaAnimTransition wallJump(String from) => go(from, 'WallJump', and('IsRising', 'WallAhead'), priority: 0);

    // 180° turns are checked before 90° ones; the 90° rules stop at the 180° band.
    // Only the turns the bundle has a clip for get a state.
    final turnStates = [
      for (final (name, yaw) in const [('TurnRight180', 180.0), ('TurnLeft180', -180.0), ('TurnRight90', 90.0), ('TurnLeft90', -90.0)])
        if (turns.containsValue(yaw)) (name, yaw),
    ];
    final plantsFeet = turnStates.isNotEmpty;

    return LuminaAnimBlueprintDocument(
      targetMesh: projectMeshAssetPath,
      variables: variables,
      eventGraph: update,
      // Free look: the head follows the camera through the
      // spine / neck / head chain.
      aimOffset: LuminaAnimAimOffset(bones: [
        for (final (bone, weight) in LuminaThirdPersonClips.aimOffsetBones) LuminaAnimAimOffsetBone(bone, weight),
      ]),
      stateMachines: [
        LuminaAnimStateMachine(
          name: 'Locomotion',
          entryState: 'Idle',
          sampleCrossFade: blend,
          states: [
            LuminaAnimState('Idle', LuminaAnimPose.clip(idleClip, plantsFeet: plantsFeet), x: 0, y: 0),
            LuminaAnimState('IdleBreak', LuminaAnimPose.randomClip(idleBreakClips, plantsFeet: plantsFeet), x: 0, y: 220),
            LuminaAnimState(
              'Walk',
              // Direction × GroundSpeed over the walk and jog
              // rows, each played at the ground speed over its own row.
              LuminaAnimPose.blendSpace(
                projectLocomotionBlendSpacePath,
                xVariable: 'Direction',
                yVariable: 'GroundSpeed',
                rateVariable: 'GroundSpeed',
                rateReference: locomotion.walkReferenceSpeed,
                minRate: locomotion.minWalkRate,
                maxRate: locomotion.maxWalkRate,
                rateRows: true,
              ),
              x: 320,
              y: 0,
            ),
            const LuminaAnimState('Jump', LuminaAnimPose.clip(jumpClip, loop: false), x: 160, y: -220),
            const LuminaAnimState('FallLoop', LuminaAnimPose.clip(fallLoopClip), x: 400, y: -220),
            const LuminaAnimState('Land', LuminaAnimPose.clip(landClip, loop: false), x: 640, y: -220),
            const LuminaAnimState('Dash', LuminaAnimPose.clip(dashClip, loop: false), x: 640, y: 0),
            const LuminaAnimState('WallJump', LuminaAnimPose.clip(wallJumpClip, loop: false), x: 400, y: -440),
            for (final (i, (name, yaw)) in turnStates.indexed)
              LuminaAnimState(
                name,
                LuminaAnimPose.clip(turns.entries.firstWhere((e) => e.value == yaw).key,
                    loop: false, rootYawDegrees: yaw, plantsFeet: true),
                x: -320,
                y: -220 + i * 150.0,
              ),
          ],
          transitions: [
            // Idle: the air first, then walking, then turning, then a break.
            ...airborne('Idle'),
            go('Idle', 'Walk', slow(below: false), priority: 3),
            for (final (i, (name, yaw)) in turnStates.indexed)
              go('Idle', name, turnDue(right: yaw > 0, degrees: yaw.abs() == 180.0 ? turn180Degrees : turn90Degrees, upTo: yaw.abs() == 180.0 ? null : turn180Degrees),
                  priority: 4 + i, blendDuration: turnBlend),
            go('Idle', 'IdleBreak', idleBreakDue(), priority: 8),
            // A break is interrupted by anything, and ends with its clip.
            ...airborne('IdleBreak'),
            go('IdleBreak', 'Walk', slow(below: false), priority: 3),
            go('IdleBreak', 'Idle', flag(LuminaAnimBlueprintInstance.clipFinishedVariable), priority: 4),
            // Walk.
            ...airborne('Walk'),
            go('Walk', 'Idle', slow(below: true), priority: 3),
            // Jump → wall jump when rising into a wall; fall loop when the clip
            // is done or the jump is long; land early on a short hop.
            wallJump('Jump'),
            go('Jump', 'Land', flag('IsFalling', not: true), priority: 1),
            go('Jump', 'FallLoop', jumpDone(), priority: 2),
            wallJump('FallLoop'),
            go('FallLoop', 'Land', flag('IsFalling', not: true), priority: 1),
            // The wall jump lands, or ends with its clip into the fall loop.
            go('WallJump', 'Land', flag('IsFalling', not: true), priority: 0),
            go('WallJump', 'FallLoop', flag(LuminaAnimBlueprintInstance.clipFinishedVariable), priority: 1),
            // Land: keep momentum into a walk, jump again, or settle into idle.
            ...airborne('Land'),
            go('Land', 'Walk', slow(below: false, landed: true), priority: 3),
            go('Land', 'Idle', flag(LuminaAnimBlueprintInstance.clipFinishedVariable), priority: 4),
            // Dash: a drop or a jump once the impulse is over, the walk after
            // dashWalkAfterSeconds while still moving, else the whole clip.
            go('Dash', 'FallLoop', andNot('IsFalling', 'IsDashing'), priority: 0),
            // (The launch frame can report a spurious rise while the capsule
            // settles back onto the floor: a jump counts once the impulse is over.)
            go('Dash', 'Jump', andNot('IsRising', 'IsDashing'), priority: 1),
            go('Dash', 'Walk', dashIntoWalk(), priority: 2, minStateTime: dashWalkAfterSeconds),
            go('Dash', 'Idle', flag(LuminaAnimBlueprintInstance.clipFinishedVariable), priority: 3),
            // Turns end with their clip, or give way to movement.
            for (final (name, _) in turnStates) ...[
              ...airborne(name),
              go(name, 'Walk', slow(below: false), priority: 3),
              go(name, 'Idle', flag(LuminaAnimBlueprintInstance.clipFinishedVariable), priority: 4, blendDuration: turnBlend),
            ],
          ],
        ),
      ],
    );
  }
}
