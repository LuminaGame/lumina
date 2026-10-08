import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_databases.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_traversal.dart';

/// The example's playable character as project assets: its input, the
/// character Blueprint (gaits, crouch, jump, a spring-arm camera), its
/// Animation Blueprint (one Motion Matching state per stance) and the game
/// mode that spawns it. Authoring space throughout (cm, Z up).
abstract final class GaspCharacterContent {
  static const String characterName = 'BP_SandboxCharacter';
  static const String gameModeName = 'BP_SandboxGameMode';
  static const String animBlueprintName = 'ABP_SandboxCharacter';
  static const String characterPath = 'contents/blueprints/$characterName.lmas';
  static const String gameModePath = 'contents/blueprints/$gameModeName.lmas';

  /// Ground speed caps (cm/s): the sample's walk, run, sprint and crouch
  /// loops move at these speeds, so the capsule and the matched clips agree.
  static const double walkSpeed = 200.0;
  static const double runSpeed = 500.0;
  static const double sprintSpeed = 700.0;
  static const double crouchSpeed = 225.0;

  /// How fast the speed cap follows a gait change (`FInterp To` speed, 1/s):
  /// releasing Shift eases from run to walk over about a second instead of
  /// cutting the speed in one frame.
  static const double gaitInterpSpeed = 4.0;

  static const double capsuleRadius = 35.0;
  static const double capsuleHalfHeight = 90.0;
  static const double jumpZVelocity = 500.0;
  static const double lookSensitivity = 0.15;

  /// The C key (`LogicalKeyboardKey.keyC.keyId`).
  static const int keyIdC = 0x00000063;

  /// WASD move, mouse look, Space jump, C crouch toggle. Walking is the
  /// default gait; held Left Shift runs, held Left Shift + Left Ctrl sprints.
  static const ProjectInputSettings input = ProjectInputSettings(
    actions: [
      ProjectInputAction(name: 'IA_Move', valueType: ProjectInputValueType.axis2D),
      ProjectInputAction(name: 'IA_Look', valueType: ProjectInputValueType.axis2D),
      ProjectInputAction(name: 'IA_Jump'),
      ProjectInputAction(name: 'IA_Run'),
      ProjectInputAction(name: 'IA_Sprint'),
      ProjectInputAction(name: 'IA_Crouch'),
    ],
    mappingContexts: [
      ProjectMappingContext(name: 'Gameplay', mappings: [
        ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdW, keyLabel: 'W', axis: 'Y'),
        ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdS, keyLabel: 'S', scale: -1.0, axis: 'Y'),
        ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdA, keyLabel: 'A', scale: -1.0, axis: 'X'),
        ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdD, keyLabel: 'D', axis: 'X'),
        ProjectInputMapping(action: 'IA_Look', keyId: kMouseXAxisKeyId, keyLabel: 'Mouse X', axis: 'X'),
        ProjectInputMapping(action: 'IA_Look', keyId: kMouseYAxisKeyId, keyLabel: 'Mouse Y', scale: -1.0, axis: 'Y'),
        ProjectInputMapping(action: 'IA_Jump', keyId: kKeyIdSpace, keyLabel: 'Space'),
        ProjectInputMapping(action: 'IA_Run', keyId: kKeyIdShiftLeft, keyLabel: 'Left Shift'),
        ProjectInputMapping(action: 'IA_Sprint', keyId: kKeyIdControlLeft, keyLabel: 'Left Ctrl'),
        ProjectInputMapping(action: 'IA_Crouch', keyId: keyIdC, keyLabel: 'C'),
      ]),
    ],
  );

  /// The Animation Blueprint's path for [meshAssetPath]: next to the mesh's
  /// clips, as the editor creates one.
  static String animBlueprintPath(String meshAssetPath) =>
      'contents/animations/${_meshName(meshAssetPath)}/$animBlueprintName.lmas';

  /// A pose search database's path for [meshAssetPath].
  static String databasePath(String meshAssetPath, String name) =>
      'contents/animations/${_meshName(meshAssetPath)}/$name.lmas';

  static String _meshName(String path) => path.split('/').last.replaceAll('.lmas', '');

  /// The character: capsule, spring arm + camera, character movement, the
  /// mesh animated by [animBlueprintPath]; Move / Look / Jump, held run and
  /// sprint keys, the crouch toggle, and a Tick that eases the speed cap
  /// toward the gait's speed.
  ///
  /// With [traversal] rows the character also gets a traversal component
  /// and Jump first tries a traversal action (hurdle, vault, mantle),
  /// jumping only when none fits the obstacle ahead.
  static LuminaBlueprintDocument characterBlueprint({
    required String meshAssetPath,
    List<LuminaInputAction> inputActions = const [],
    List<LuminaTraversalAnimation> traversal = const [],
  }) {
    final variables = [
      const LuminaBlueprintVariable(name: 'LookSensitivity', typeName: 'Float', defaultValue: lookSensitivity),
      const LuminaBlueprintVariable(name: 'WantsRun', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'WantsSprint', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'IsCrouching', typeName: 'Bool', defaultValue: false),
    ];
    final context = LuminaBlueprintTypeContext(variables: variables, inputActions: inputActions);
    LuminaBlueprintNode place(String id, String registryId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, literals: literals, context: context);
    LuminaBlueprintNode input(String id, String action) =>
        place(id, LuminaBlueprintNodeLibrary.enhancedInputAction, {'action': action});
    LuminaBlueprintNode get(String id, String variable) =>
        place(id, LuminaBlueprintNodeLibrary.variableGet, {'variable': variable});
    LuminaBlueprintNode set(String id, String variable, [Object? value]) =>
        place(id, LuminaBlueprintNodeLibrary.variableSet, {'variable': variable, 'value': ?value});
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

    final sections = [
      LuminaBlueprintGraphSection('Move', [
        input('move', 'IA_Move'),
        place('move_axis', 'break_vector2d'),
        place('control', 'get_control_rotation'),
        place('control_parts', 'break_rotator'),
        place('yaw_only', 'make_rotator'),
        place('forward', 'get_forward_vector'),
        place('right', 'get_right_vector'),
        place('move_forward', 'add_movement_input'),
        place('move_right', 'add_movement_input'),
      ]),
      LuminaBlueprintGraphSection('Look', [
        input('look', 'IA_Look'),
        place('look_axis', 'break_vector2d'),
        get('sensitivity', 'LookSensitivity'),
        place('yaw_scaled', 'float_multiply'),
        place('pitch_scaled', 'float_multiply'),
        place('yaw', 'add_controller_yaw_input'),
        place('pitch', 'add_controller_pitch_input'),
      ]),
      LuminaBlueprintGraphSection('Jump', [
        input('jump_input', 'IA_Jump'),
        if (traversal.isNotEmpty) ...[
          place('traverse', 'try_traversal_action'),
          place('traversal_fits', 'branch'),
        ],
        place('jump', 'jump'),
        place('stop_jumping', 'stop_jumping'),
      ]),
      // Run while Left Shift is held.
      LuminaBlueprintGraphSection('Run', [
        input('run_input', 'IA_Run'),
        set('start_run', 'WantsRun', true),
        set('end_run', 'WantsRun', false),
      ]),
      // Left Ctrl held while running sprints.
      LuminaBlueprintGraphSection('Sprint', [
        input('sprint_input', 'IA_Sprint'),
        set('start_sprint', 'WantsSprint', true),
        set('end_sprint', 'WantsSprint', false),
      ]),
      // C toggles crouching and tells the Animation Blueprint.
      LuminaBlueprintGraphSection('Crouch', [
        input('crouch_input', 'IA_Crouch'),
        get('crouching', 'IsCrouching'),
        place('toggle_crouch', 'bool_not'),
        set('set_crouch', 'IsCrouching'),
        // Read again after the set: a pure node is evaluated per read, so
        // the NOT above would give the old value back.
        get('crouched', 'IsCrouching'),
        place('tell_crouch', 'set_anim_variable', {'name': 'IsCrouching', 'type': 'boolean'}),
      ]),
      // Tick: ease the speed cap toward the gait's speed (crouch > Shift +
      // Ctrl sprint > Shift run > walk) and tell the Animation Blueprint the
      // gait keys, so it searches the gait's clips.
      LuminaBlueprintGraphSection('Gait', [
        place('tick', 'event_tick'),
        get('gait_run', 'WantsRun'),
        get('gait_sprint', 'WantsSprint'),
        get('gait_crouch', 'IsCrouching'),
        place('run_and_sprint', 'bool_and'),
        place('run_or_walk', 'select_float', {'a': runSpeed, 'b': walkSpeed}),
        place('or_sprint', 'select_float', {'a': sprintSpeed}),
        place('or_crouch', 'select_float', {'a': crouchSpeed}),
        place('current_speed', 'get_max_walk_speed'),
        place('ease_speed', 'float_interp_to', {'interp_speed': gaitInterpSpeed}),
        place('gait_speed', 'set_max_walk_speed'),
        get('anim_run', 'WantsRun'),
        place('tell_run', 'set_anim_variable', {'name': 'WantsRun', 'type': 'boolean'}),
        get('anim_sprint', 'WantsSprint'),
        place('tell_sprint', 'set_anim_variable', {'name': 'WantsSprint', 'type': 'boolean'}),
      ]),
    ];
    final wires = [
      wire('move', 'action_value', 'move_axis', 'in_vec'),
      wire('control', 'return_value', 'control_parts', 'in_rot'),
      wire('control_parts', 'z', 'yaw_only', 'z'),
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
      if (traversal.isEmpty)
        wire('jump_input', 'started', 'jump', 'exec_in')
      else ...[
        wire('jump_input', 'started', 'traverse', 'exec_in'),
        wire('traverse', 'exec_out', 'traversal_fits', 'exec_in'),
        wire('traverse', 'return_value', 'traversal_fits', 'condition'),
        wire('traversal_fits', 'false_out', 'jump', 'exec_in'),
      ],
      wire('jump_input', 'completed', 'stop_jumping', 'exec_in'),
      wire('run_input', 'started', 'start_run', 'exec_in'),
      wire('run_input', 'completed', 'end_run', 'exec_in'),
      wire('run_input', 'canceled', 'end_run', 'exec_in'),
      wire('sprint_input', 'started', 'start_sprint', 'exec_in'),
      wire('sprint_input', 'completed', 'end_sprint', 'exec_in'),
      wire('sprint_input', 'canceled', 'end_sprint', 'exec_in'),
      wire('crouch_input', 'started', 'set_crouch', 'exec_in'),
      wire('crouching', 'value', 'toggle_crouch', 'a'),
      wire('toggle_crouch', 'return_value', 'set_crouch', 'value'),
      wire('set_crouch', 'exec_out', 'tell_crouch', 'exec_in'),
      wire('crouched', 'value', 'tell_crouch', 'value'),
      wire('tick', 'exec_tick_out', 'gait_speed', 'exec_in'),
      wire('gait_run', 'value', 'run_or_walk', 'pick_a'),
      wire('gait_run', 'value', 'run_and_sprint', 'a'),
      wire('gait_sprint', 'value', 'run_and_sprint', 'b'),
      wire('run_or_walk', 'return_value', 'or_sprint', 'b'),
      wire('run_and_sprint', 'return_value', 'or_sprint', 'pick_a'),
      wire('or_sprint', 'return_value', 'or_crouch', 'b'),
      wire('gait_crouch', 'value', 'or_crouch', 'pick_a'),
      wire('current_speed', 'return_value', 'ease_speed', 'current'),
      wire('or_crouch', 'return_value', 'ease_speed', 'target'),
      wire('tick', 'delta_seconds', 'ease_speed', 'delta_time'),
      wire('ease_speed', 'return_value', 'gait_speed', 'max_walk_speed'),
      wire('gait_speed', 'exec_out', 'tell_run', 'exec_in'),
      wire('anim_run', 'value', 'tell_run', 'value'),
      wire('tell_run', 'exec_out', 'tell_sprint', 'exec_in'),
      wire('anim_sprint', 'value', 'tell_sprint', 'value'),
    ];

    return LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      components: [
        LuminaBlueprintComponent(
          id: 'capsule',
          name: 'CapsuleComponent',
          type: 'LuminaCapsuleComponent',
          properties: {'capsuleRadius': capsuleRadius, 'capsuleHalfHeight': capsuleHalfHeight},
        ),
        LuminaBlueprintComponent(
          id: 'boom',
          name: 'CameraBoom',
          type: 'LuminaSpringArmComponent',
          parentId: 'capsule',
          properties: {
            'location': [0.0, 0.0, 55.0],
            'targetArmLength': 320.0,
            'usePawnControlRotation': true,
            'enableCameraLag': true,
            'cameraLagSpeed': 10.0,
            'enableCameraRotationLag': true,
            'cameraRotationLagSpeed': 14.0,
            'doCollisionTest': true,
            'probeSize': 25.0,
          },
        ),
        LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
        LuminaBlueprintComponent(
          id: 'movement',
          name: 'CharacterMovement',
          type: 'LuminaCharacterMovementComponent',
          isSceneComponent: false,
          properties: {'maxWalkSpeed': walkSpeed, 'jumpZVelocity': jumpZVelocity, 'airControl': 0.35, 'jumpCutMultiplier': 1.0},
        ),
        if (traversal.isNotEmpty)
          LuminaBlueprintComponent(
            id: 'traversal',
            name: 'Traversal',
            type: 'LuminaTraversalComponent',
            isSceneComponent: false,
            properties: {
              'animations': [for (final a in traversal) a.toJson()],
              'rootBone': GaspTraversal.rootBone,
            },
          ),
        LuminaBlueprintComponent(
          id: 'mesh',
          name: 'Mesh',
          type: 'LuminaSkeletalMeshComponent',
          parentId: 'capsule',
          properties: {
            'skeletalMeshAsset': meshAssetPath,
            'location': [0.0, 0.0, -capsuleHalfHeight],
            'animMode': 'Use Animation Blueprint',
            'animClass': animBlueprintPath(meshAssetPath),
          },
        ),
      ],
      eventGraph: LuminaBlueprintGraph(nodes: LuminaBlueprintGraphLayout.stack(sections, wires: wires), wires: wires),
      variables: variables,
      // The Motion Matching states turn the body toward its movement; the
      // camera orbits on its own.
      classDefaults: {'bUseControllerRotationYaw': false, 'baseEyeHeight': 70.0},
    );
  }

  /// The game mode: [characterPath] as the default pawn.
  static LuminaBlueprintDocument get gameModeBlueprint => LuminaBlueprintDocument(
        parentClass: 'LuminaGameMode',
        classDefaults: {'defaultPawnClass': characterPath, 'playerControllerClass': 'LuminaPlayerController'},
      );

  /// Seconds the landing database plays before the stand database takes
  /// over.
  static const double landSeconds = 0.45;

  /// The Animation Blueprint: the update graph stores whether the pawn
  /// falls (`IsCrouching`, `WantsRun` and `WantsSprint` come from the
  /// character); Stand, Run, Sprint, Crouch, Air and Land are Motion
  /// Matching states on [GaspDatabases]' databases, so every pose comes from
  /// a matched clip with its root motion removed. Stand (the walk), Run and
  /// Sprint share the stand database and search only their gait's clips
  /// (idle clips carry every gait), as the sample picks a database per gait.
  static LuminaAnimBlueprintDocument animBlueprint({required String meshAssetPath}) {
    final variables = [
      const LuminaBlueprintVariable(name: 'IsFalling', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'IsCrouching', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'WantsRun', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: 'WantsSprint', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.stateTimeVariable, typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.matchedClipVariable, typeName: 'String', defaultValue: ''),
    ];
    final context = LuminaBlueprintTypeContext(variables: variables);
    LuminaBlueprintNode place(String id, String registryId, double x, double y, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, x: x, y: y, literals: literals, context: context);
    LuminaBlueprintWire wire(String id, String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

    final update = LuminaBlueprintGraph(
      nodes: [
        place('update', LuminaBlueprintNodeLibrary.updateAnimation, 0, 0),
        place('falling', 'is_falling', 0, 160),
        place('set_falling', LuminaBlueprintNodeLibrary.variableSet, 280, 0, {'variable': 'IsFalling'}),
      ],
      wires: [
        wire('w0', 'update', 'exec_out', 'set_falling', 'exec_in'),
        wire('w1', 'falling', 'return_value', 'set_falling', 'value'),
      ],
    );

    /// A rule: every listed variable has its wanted value.
    LuminaBlueprintGraph rule(Map<String, bool> wanted) {
      final nodes = <LuminaBlueprintNode>[];
      final wires = <LuminaBlueprintWire>[];
      final terms = <(String, String)>[];
      var y = 0.0;
      for (final MapEntry(key: name, value: value) in wanted.entries) {
        final id = 'get_$name';
        nodes.add(place(id, LuminaBlueprintNodeLibrary.variableGet, 0, y, {'variable': name}));
        if (value) {
          terms.add((id, 'value'));
        } else {
          nodes.add(place('not_$name', 'bool_not', 240, y));
          wires.add(wire('w_not_$name', id, 'value', 'not_$name', 'a'));
          terms.add(('not_$name', 'return_value'));
        }
        y += 120;
      }
      var (from, pin) = terms.first;
      for (var i = 1; i < terms.length; i++) {
        nodes.add(place('and_$i', 'bool_and', 480.0 + 160 * i, 60));
        wires
          ..add(wire('w_and_a$i', from, pin, 'and_$i', 'a'))
          ..add(wire('w_and_b$i', terms[i].$1, terms[i].$2, 'and_$i', 'b'));
        (from, pin) = ('and_$i', 'return_value');
      }
      nodes.add(place('result', LuminaBlueprintNodeLibrary.transitionResult, 960, 0));
      wires.add(wire('w_result', from, pin, 'result', 'can_enter'));
      return LuminaBlueprintGraph(nodes: nodes, wires: wires);
    }

    String db(String name) => databasePath(meshAssetPath, name);
    LuminaAnimPose mm(String name, [List<String> requiredTags = const []]) =>
        LuminaAnimPose.motionMatching(db(name), blendTime: 0.2, orientToMovement: true, requiredTags: requiredTags);
    var t = 0;
    LuminaAnimTransition go(String from, String to, Map<String, bool> wanted,
            {int priority = 1, double blend = 0.2, double minStateTime = 0.0}) =>
        LuminaAnimTransition(
          id: 't${t++}',
          from: from,
          to: to,
          priority: priority,
          blendDuration: blend,
          minStateTime: minStateTime,
          rule: rule(wanted),
        );

    return LuminaAnimBlueprintDocument(
      targetMesh: meshAssetPath,
      variables: variables,
      eventGraph: update,
      stateMachines: [
        LuminaAnimStateMachine(
          name: 'Locomotion',
          entryState: 'Stand',
          states: [
            LuminaAnimState('Stand', mm(GaspDatabases.stand, const ['Walk']), x: 0, y: 0),
            LuminaAnimState('Run', mm(GaspDatabases.stand, const ['Run']), x: -320, y: -160),
            LuminaAnimState('Sprint', mm(GaspDatabases.stand, const ['Sprint']), x: -640, y: -160),
            LuminaAnimState('Crouch', mm(GaspDatabases.crouch), x: 0, y: 240),
            LuminaAnimState('Air', mm(GaspDatabases.jump), x: 320, y: 120),
            LuminaAnimState('Land', mm(GaspDatabases.land), x: 640, y: 0),
          ],
          transitions: [
            go('Stand', 'Air', {'IsFalling': true}, priority: 0),
            go('Run', 'Air', {'IsFalling': true}, priority: 0),
            go('Sprint', 'Air', {'IsFalling': true}, priority: 0),
            go('Crouch', 'Air', {'IsFalling': true}, priority: 0),
            go('Land', 'Air', {'IsFalling': true}, priority: 0),
            go('Stand', 'Crouch', {'IsCrouching': true}),
            go('Run', 'Crouch', {'IsCrouching': true}),
            go('Sprint', 'Crouch', {'IsCrouching': true}),
            // Gaits: Shift runs, Shift + Ctrl sprints, neither walks.
            go('Stand', 'Run', {'WantsRun': true, 'WantsSprint': false}, priority: 2),
            go('Stand', 'Sprint', {'WantsRun': true, 'WantsSprint': true}, priority: 2),
            go('Run', 'Sprint', {'WantsRun': true, 'WantsSprint': true}, priority: 2),
            go('Run', 'Stand', {'WantsRun': false}, priority: 2),
            go('Sprint', 'Run', {'WantsRun': true, 'WantsSprint': false}, priority: 2),
            go('Sprint', 'Stand', {'WantsRun': false}, priority: 2),
            go('Crouch', 'Stand', {'IsCrouching': false}),
            go('Air', 'Crouch', {'IsFalling': false, 'IsCrouching': true}),
            go('Air', 'Land', {'IsFalling': false, 'IsCrouching': false}),
            go('Land', 'Crouch', {'IsCrouching': true}),
            go('Land', 'Stand', {'IsFalling': false}, priority: 2, minStateTime: landSeconds),
          ],
        ),
      ],
    );
  }
}
