import 'package:lumina/lumina.dart';

/// The MetaXR posing example's input and Blueprints, as project assets
/// (authoring space: cm, Z up; the player faces +Y).
///
/// - `BP_PosedCharacter`: the character mesh with a pose authoring
///   component holding the targets the controllers leave; it takes the
///   player's input (Enable Input) for reset, the pose slots and moving it.
/// - `BP_XRPlayer`: the pawn at the XR origin: the grab interaction both
///   controllers (or the mouse, on a desktop) grab with, Undo and the
///   passthrough toggle, a camera for desktop play, the tracked hands.
/// - `BP_RoomPassthrough`: the passthrough underlay of the room.
/// - `BP_PosingGameMode`: spawns `BP_XRPlayer`.
abstract final class MetaXrPosingContent {
  static const String characterName = 'BP_PosedCharacter';
  static const String playerName = 'BP_XRPlayer';
  static const String passthroughName = 'BP_RoomPassthrough';
  static const String gameModeName = 'BP_PosingGameMode';
  static const String characterPath = 'contents/blueprints/$characterName.lmas';
  static const String playerPath = 'contents/blueprints/$playerName.lmas';
  static const String passthroughPath = 'contents/blueprints/$passthroughName.lmas';
  static const String gameModePath = 'contents/blueprints/$gameModeName.lmas';

  /// The save slot the poses go to; the four poses are `Pose1` … `Pose4`.
  static const String poseSlot = 'MetaXrPosing';
  static const int slotCount = 4;

  /// Holding A this long saves into the current slot (a shorter press steps
  /// to the next slot and loads it).
  static const double saveHoldSeconds = 0.8;

  /// Holding Menu this long resets the character to its rest (A-) pose.
  static const double resetHoldSeconds = 1.0;

  /// Right stick: degrees per second the character turns; left stick: cm per
  /// second it slides.
  static const double turnSpeed = 90.0;
  static const double slideSpeed = 80.0;

  /// Desktop keys (Flutter logical key ids) beside the controllers.
  static const int keyIdZ = 0x0000007a;
  static const int keyIdR = 0x00000072;
  static const int keyIdE = 0x00000065;
  static const int keyIdQ = 0x00000071;
  static const int keyIdP = 0x00000070;

  static ProjectInputMapping _xr(String action, LuminaKey key, {double scale = 1.0, String axis = 'X'}) =>
      ProjectInputMapping(action: action, keyId: key.keyId!, keyLabel: key.id, scale: scale, axis: axis);

  /// The controllers' buttons (and desktop keys):
  /// - Undo: B / Y (Z);
  /// - Reset: hold Menu 1 s (R);
  /// - Slot: A steps to the next slot and loads it, held 0.8 s saves (E);
  /// - Slot back: X (Q);
  /// - Passthrough: left thumbstick click (P);
  /// - Turn: right thumbstick X; Slide: left thumbstick.
  static final ProjectInputSettings input = ProjectInputSettings(
    actions: const [
      ProjectInputAction(name: 'IA_Undo'),
      ProjectInputAction(name: 'IA_Reset'),
      ProjectInputAction(name: 'IA_Slot'),
      ProjectInputAction(name: 'IA_SlotBack'),
      ProjectInputAction(name: 'IA_TogglePassthrough'),
      ProjectInputAction(name: 'IA_Turn', valueType: ProjectInputValueType.axis1D),
      ProjectInputAction(name: 'IA_Slide', valueType: ProjectInputValueType.axis2D),
    ],
    mappingContexts: [
      ProjectMappingContext(name: 'Gameplay', mappings: [
        _xr('IA_Undo', LuminaKey.xrRightB),
        _xr('IA_Undo', LuminaKey.xrLeftY),
        const ProjectInputMapping(action: 'IA_Undo', keyId: keyIdZ, keyLabel: 'Z'),
        _xr('IA_Reset', LuminaKey.xrLeftMenu),
        const ProjectInputMapping(action: 'IA_Reset', keyId: keyIdR, keyLabel: 'R'),
        _xr('IA_Slot', LuminaKey.xrRightA),
        const ProjectInputMapping(action: 'IA_Slot', keyId: keyIdE, keyLabel: 'E'),
        _xr('IA_SlotBack', LuminaKey.xrLeftX),
        const ProjectInputMapping(action: 'IA_SlotBack', keyId: keyIdQ, keyLabel: 'Q'),
        _xr('IA_TogglePassthrough', LuminaKey.xrLeftThumbstickClick),
        const ProjectInputMapping(action: 'IA_TogglePassthrough', keyId: keyIdP, keyLabel: 'P'),
        _xr('IA_Turn', LuminaKey.xrRightThumbstickX),
        _xr('IA_Slide', LuminaKey.xrLeftThumbstickX),
        _xr('IA_Slide', LuminaKey.xrLeftThumbstickY, axis: 'Y'),
      ]),
    ],
  );

  /// The MetaXR passthrough node the player graph calls, declared with the
  /// plugin's own spec (id, pins, generated call), so the graph compiles in a
  /// tool that does not link the plugin; a game links it through the
  /// plugin's runtime module.
  static const String setPassthroughEnabled = 'metaxr_set_passthrough_enabled';

  static void declarePluginNodes() {
    if (LuminaBlueprintFunctionRegistry.entry(setPassthroughEnabled) != null) return;
    LuminaBlueprintFunctionRegistry.declare(
      const LuminaBlueprintNodeSpec(
        id: setPassthroughEnabled,
        title: 'Set Passthrough Enabled',
        category: 'XR|Passthrough',
        kind: LuminaBlueprintNodeKind.impure,
        headerColor: 0xFF5E35B1,
        keywords: ['xr', 'mixed reality', 'passthrough', 'room'],
        inputs: [
          LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
          LuminaBlueprintPinSpec('enabled', 'Enabled', LuminaPinType.boolean, defaultValue: true),
        ],
        outputs: [LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec)],
      ),
      call: const LuminaBlueprintCallShape('MetaPassthroughFunctions.setEnabled', ['enabled'],
          self: true, library: 'package:lumina_plugin_metaxr/runtime.dart'),
    );
  }

  static List<LuminaInputAction> get inputActions => ProjectInputBinder.bind(input).actions.values.toList();

  static (LuminaBlueprintNode Function(String id, String registryId, [Map<String, dynamic>? literals]),
      LuminaBlueprintWire Function(String from, String fromPin, String to, String toPin)) _builders(List<LuminaBlueprintVariable> variables) {
    final context = LuminaBlueprintTypeContext(variables: variables, inputActions: inputActions);
    var n = 0;
    return (
      (id, registryId, [literals]) => LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, literals: literals, context: context),
      (from, fromPin, to, toPin) => LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin),
    );
  }

  /// The posed character: [meshAssetPath] with a pose authoring component
  /// (weight 1, holding targets); Enable Input at BeginPlay; Reset (held),
  /// the slots (A short: next + load, A held: save; X: back + load), Turn
  /// and Slide.
  static LuminaBlueprintDocument characterBlueprint({required String meshAssetPath}) {
    final variables = [
      const LuminaBlueprintVariable(name: 'Slot', typeName: 'Int', defaultValue: 0),
      const LuminaBlueprintVariable(name: 'SlotPressedAt', typeName: 'Float', defaultValue: 0.0),
      const LuminaBlueprintVariable(name: 'ResetPressedAt', typeName: 'Float', defaultValue: 0.0),
    ];
    final (place, wire) = _builders(variables);
    LuminaBlueprintNode input(String id, String action) => place(id, LuminaBlueprintNodeLibrary.enhancedInputAction, {'action': action});
    LuminaBlueprintNode get(String id, String v) => place(id, LuminaBlueprintNodeLibrary.variableGet, {'variable': v});
    LuminaBlueprintNode set(String id, String v) => place(id, LuminaBlueprintNodeLibrary.variableSet, {'variable': v});
    LuminaBlueprintNode now(String id) => place(id, 'get_game_time_in_seconds');
    // The slot's pose name: "Pose" + (Slot + 1).
    List<LuminaBlueprintNode> poseName(String prefix) => [
          get('${prefix}_pose_slot', 'Slot'),
          place('${prefix}_plus1', 'int_add', {'b': 1}),
          place('${prefix}_digits', 'int_to_string'),
          place('${prefix}_name', 'append', {'a': 'Pose'}),
        ];
    List<LuminaBlueprintWire> poseNameWires(String prefix, String to) => [
          wire('${prefix}_pose_slot', 'value', '${prefix}_plus1', 'a'),
          wire('${prefix}_plus1', 'return_value', '${prefix}_digits', 'in_int'),
          wire('${prefix}_digits', 'return_value', '${prefix}_name', 'b'),
          wire('${prefix}_name', 'return_value', to, 'name'),
        ];

    final sections = [
      LuminaBlueprintGraphSection('Input', [
        place('begin', 'event_beginplay'),
        place('controller', 'get_player_controller', {'player_index': 0}),
        place('enable', 'enable_input'),
      ]),
      LuminaBlueprintGraphSection('Reset (hold Menu)', [
        input('reset', 'IA_Reset'),
        now('reset_now'),
        set('reset_mark', 'ResetPressedAt'),
        now('reset_end'),
        get('reset_at', 'ResetPressedAt'),
        place('reset_held', 'float_subtract'),
        place('reset_long', 'float_greater_equal', {'b': resetHoldSeconds}),
        place('reset_branch', 'branch'),
        place('reset_pose', 'reset_pose'),
      ]),
      LuminaBlueprintGraphSection('Slots (A: next and load, hold: save)', [
        input('slot', 'IA_Slot'),
        now('slot_now'),
        set('slot_mark', 'SlotPressedAt'),
        now('slot_end'),
        get('slot_at', 'SlotPressedAt'),
        place('slot_held', 'float_subtract'),
        place('slot_long', 'float_greater_equal', {'b': saveHoldSeconds}),
        place('slot_branch', 'branch'),
        place('save', 'save_pose', {'slot': poseSlot}),
        ...poseName('save'),
        get('next_slot', 'Slot'),
        place('next_add', 'int_add', {'b': 1}),
        place('next_mod', 'int_modulo', {'b': slotCount}),
        set('next_set', 'Slot'),
        place('load_next', 'load_pose', {'slot': poseSlot, 'blend_time': 0.3}),
        ...poseName('next'),
      ]),
      LuminaBlueprintGraphSection('Slot back (X)', [
        input('back', 'IA_SlotBack'),
        get('back_slot', 'Slot'),
        place('back_add', 'int_add', {'b': slotCount - 1}),
        place('back_mod', 'int_modulo', {'b': slotCount}),
        set('back_set', 'Slot'),
        place('load_back', 'load_pose', {'slot': poseSlot, 'blend_time': 0.3}),
        ...poseName('back'),
      ]),
      LuminaBlueprintGraphSection('Turn (right stick)', [
        input('turn', 'IA_Turn'),
        place('turn_dt', 'get_world_delta_seconds'),
        place('turn_rate', 'float_multiply', {'b': turnSpeed}),
        place('turn_step', 'float_multiply'),
        place('turn_rot', 'get_actor_rotation'),
        place('turn_parts', 'break_rotator'),
        place('turn_yaw', 'float_add'),
        place('turn_new', 'make_rotator'),
        place('turn_set', 'set_actor_rotation'),
      ]),
      LuminaBlueprintGraphSection('Slide (left stick)', [
        input('slide', 'IA_Slide'),
        place('slide_axis', 'break_vector2d'),
        place('slide_dt', 'get_world_delta_seconds'),
        place('slide_rate', 'float_multiply', {'b': slideSpeed}),
        place('slide_x', 'float_multiply'),
        place('slide_y', 'float_multiply'),
        place('slide_offset', 'make_vector', {'z': 0.0}),
        place('slide_at', 'get_actor_location'),
        place('slide_to', 'vector_add'),
        place('slide_set', 'set_actor_location', {'sweep': false}),
      ]),
    ];
    final wires = [
      wire('begin', 'exec_out', 'enable', 'exec_in'),
      wire('controller', 'return_value', 'enable', 'player_controller'),
      // Reset: the press time, then on release whether it was held long enough.
      wire('reset', 'started', 'reset_mark', 'exec_in'),
      wire('reset_now', 'return_value', 'reset_mark', 'value'),
      wire('reset', 'completed', 'reset_branch', 'exec_in'),
      wire('reset_end', 'return_value', 'reset_held', 'a'),
      wire('reset_at', 'value', 'reset_held', 'b'),
      wire('reset_held', 'return_value', 'reset_long', 'a'),
      wire('reset_long', 'return_value', 'reset_branch', 'condition'),
      wire('reset_branch', 'true_out', 'reset_pose', 'exec_in'),
      // Slot: held → save; short → next slot, load it.
      wire('slot', 'started', 'slot_mark', 'exec_in'),
      wire('slot_now', 'return_value', 'slot_mark', 'value'),
      wire('slot', 'completed', 'slot_branch', 'exec_in'),
      wire('slot_end', 'return_value', 'slot_held', 'a'),
      wire('slot_at', 'value', 'slot_held', 'b'),
      wire('slot_held', 'return_value', 'slot_long', 'a'),
      wire('slot_long', 'return_value', 'slot_branch', 'condition'),
      wire('slot_branch', 'true_out', 'save', 'exec_in'),
      ...poseNameWires('save', 'save'),
      wire('slot_branch', 'false_out', 'next_set', 'exec_in'),
      wire('next_slot', 'value', 'next_add', 'a'),
      wire('next_add', 'return_value', 'next_mod', 'a'),
      wire('next_mod', 'return_value', 'next_set', 'value'),
      wire('next_set', 'exec_out', 'load_next', 'exec_in'),
      ...poseNameWires('next', 'load_next'),
      // Back: previous slot, load it.
      wire('back', 'started', 'back_set', 'exec_in'),
      wire('back_slot', 'value', 'back_add', 'a'),
      wire('back_add', 'return_value', 'back_mod', 'a'),
      wire('back_mod', 'return_value', 'back_set', 'value'),
      wire('back_set', 'exec_out', 'load_back', 'exec_in'),
      ...poseNameWires('back', 'load_back'),
      // Turn: yaw += stick × speed × dt.
      wire('turn', 'triggered', 'turn_set', 'exec_in'),
      wire('turn', 'action_value', 'turn_rate', 'a'),
      wire('turn_rate', 'return_value', 'turn_step', 'a'),
      wire('turn_dt', 'return_value', 'turn_step', 'b'),
      wire('turn_rot', 'return_value', 'turn_parts', 'in_rot'),
      wire('turn_parts', 'z', 'turn_yaw', 'a'),
      wire('turn_step', 'return_value', 'turn_yaw', 'b'),
      wire('turn_parts', 'x', 'turn_new', 'x'),
      wire('turn_parts', 'y', 'turn_new', 'y'),
      wire('turn_yaw', 'return_value', 'turn_new', 'z'),
      wire('turn_new', 'return_value', 'turn_set', 'new_rotation'),
      // Slide: location += (stick x, stick y) × speed × dt on the floor.
      wire('slide', 'triggered', 'slide_set', 'exec_in'),
      wire('slide', 'action_value', 'slide_axis', 'in_vec'),
      wire('slide_dt', 'return_value', 'slide_rate', 'a'),
      wire('slide_axis', 'x', 'slide_x', 'a'),
      wire('slide_rate', 'return_value', 'slide_x', 'b'),
      wire('slide_axis', 'y', 'slide_y', 'a'),
      wire('slide_rate', 'return_value', 'slide_y', 'b'),
      wire('slide_x', 'return_value', 'slide_offset', 'x'),
      wire('slide_y', 'return_value', 'slide_offset', 'y'),
      wire('slide_at', 'return_value', 'slide_to', 'a'),
      wire('slide_offset', 'return_value', 'slide_to', 'b'),
      wire('slide_to', 'return_value', 'slide_set', 'new_location'),
    ];
    return LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      components: [
        LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
          id: 'mesh',
          name: 'Mesh',
          type: 'LuminaSkeletalMeshComponent',
          parentId: 'root',
          properties: {'skeletalMeshAsset': meshAssetPath},
        ),
        LuminaBlueprintComponent(
          id: 'pose',
          name: 'PoseAuthoring',
          type: 'LuminaPoseAuthoringComponent',
          isSceneComponent: false,
          properties: {'weight': 1.0, 'captureMode': 'holdTargets'},
        ),
      ],
      eventGraph: LuminaBlueprintGraph(nodes: LuminaBlueprintGraphLayout.stack(sections, wires: wires), wires: wires),
      variables: variables,
    );
  }

  /// Eye height of the desktop camera (cm).
  static const double eyeHeight = 160.0;

  /// The player at the XR origin: the grab interaction (the controllers
  /// register with it in the headset; the mouse grabs on a desktop), Undo,
  /// the passthrough toggle, a camera for desktop play and the two tracked
  /// hands.
  static LuminaBlueprintDocument playerBlueprint() {
    declarePluginNodes();
    final variables = [const LuminaBlueprintVariable(name: 'PassthroughOn', typeName: 'Bool', defaultValue: true)];
    final (place, wire) = _builders(variables);
    final sections = [
      LuminaBlueprintGraphSection('Undo (B / Y)', [
        place('undo', LuminaBlueprintNodeLibrary.enhancedInputAction, {'action': 'IA_Undo'}),
        place('undo_grab', 'undo_last_grab'),
      ]),
      LuminaBlueprintGraphSection('Passthrough (left stick click)', [
        place('toggle', LuminaBlueprintNodeLibrary.enhancedInputAction, {'action': 'IA_TogglePassthrough'}),
        place('pt_get', LuminaBlueprintNodeLibrary.variableGet, {'variable': 'PassthroughOn'}),
        place('pt_not', 'bool_not'),
        place('pt_set', LuminaBlueprintNodeLibrary.variableSet, {'variable': 'PassthroughOn'}),
        place('pt_now', LuminaBlueprintNodeLibrary.variableGet, {'variable': 'PassthroughOn'}),
        place('pt_apply', setPassthroughEnabled),
      ]),
      LuminaBlueprintGraphSection('Held handle (log)', [
        place('grabbed', 'event_pose_handle_grabbed'),
        place('grabbed_text', 'append', {'a': 'Holding '}),
        place('grabbed_print', 'print_string', {'print_to_screen': false, 'print_to_log': true}),
      ]),
    ];
    final wires = [
      wire('undo', 'started', 'undo_grab', 'exec_in'),
      wire('toggle', 'started', 'pt_set', 'exec_in'),
      wire('pt_get', 'value', 'pt_not', 'a'),
      wire('pt_not', 'return_value', 'pt_set', 'value'),
      wire('pt_set', 'exec_out', 'pt_apply', 'exec_in'),
      wire('pt_now', 'value', 'pt_apply', 'enabled'),
      wire('grabbed', 'exec_out', 'grabbed_print', 'exec_in'),
      wire('grabbed', 'handle', 'grabbed_text', 'b'),
      wire('grabbed_text', 'return_value', 'grabbed_print', 'in_string'),
    ];
    return LuminaBlueprintDocument(
      parentClass: 'LuminaPawn',
      components: [
        LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
          id: 'camera',
          name: 'DesktopCamera',
          type: 'LuminaCameraComponent',
          parentId: 'root',
          properties: {
            'location': [0.0, 0.0, eyeHeight],
            'rotation': [-15.0, 0.0, 0.0],
          },
        ),
        LuminaBlueprintComponent(
          id: 'grab',
          name: 'GrabInteraction',
          type: 'LuminaPoseGrabInteractor',
          isSceneComponent: false,
          properties: {'grabRadius': 10.0, 'useMouse': true, 'showHandles': true},
        ),
        for (final hand in const ['left', 'right'])
          LuminaBlueprintComponent(
            id: 'hand_$hand',
            name: 'Hand${hand[0].toUpperCase()}${hand.substring(1)}',
            type: 'LuminaMetaHandTrackingComponent',
            parentId: 'root',
            properties: {'hand': hand},
          ),
      ],
      eventGraph: LuminaBlueprintGraph(nodes: LuminaBlueprintGraphLayout.stack(sections, wires: wires), wires: wires),
      variables: variables,
      classDefaults: {'baseEyeHeight': eyeHeight},
    );
  }

  /// The room's passthrough: an underlay, on.
  static LuminaBlueprintDocument passthroughBlueprint() => LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(
            id: 'passthrough',
            name: 'Passthrough',
            type: 'LuminaMetaPassthroughComponent',
            parentId: 'root',
            properties: {'enabled': true, 'placement': 'underlay'},
          ),
        ],
      );

  /// The game mode: [playerPath] as the default pawn.
  static LuminaBlueprintDocument get gameModeBlueprint => LuminaBlueprintDocument(
        parentClass: 'LuminaGameMode',
        classDefaults: {'defaultPawnClass': playerPath, 'playerControllerClass': 'LuminaPlayerController'},
      );
}
