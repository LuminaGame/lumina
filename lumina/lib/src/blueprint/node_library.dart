import 'package:lumina/src/input/input_action.dart';
import 'package:lumina/src/blueprint/blueprint_assets.dart';
import 'package:lumina/src/blueprint/blueprint_enums_interfaces.dart';
import 'package:lumina/src/blueprint/blueprint_function_registry.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/editor/editor_widget_events.dart';
import 'package:lumina/src/blueprint/level_blueprint.dart';
import 'package:lumina/src/blueprint/widget_blueprint.dart';
import 'package:lumina/src/blueprint/widget_classes.dart';
import 'package:lumina/src/umg/combo_box_options.dart';
import 'package:lumina/src/umg/viewport/viewport_nodes.dart';
import 'package:lumina/src/umg/viewport/viewport_scene.dart';

part 'node_library/specs.dart';
part 'node_library/pin_builders.dart';
part 'node_library/pins_of.dart';
part 'node_library/events_pawn_ui_input.dart';
part 'node_library/math_objects_components.dart';
part 'node_library/math_string_array.dart';
part 'node_library/flow_control.dart';
part 'node_library/engine_and_actors.dart';
part 'node_library/graph_members.dart';
part 'node_library/game_framework.dart';
part 'node_library/rendering_features.dart';
part 'node_library/media_and_debug.dart';
part 'node_library/type_context.dart';
part 'node_library/widget_blueprint.dart';
part 'node_library/ragdoll.dart';
part 'node_library/traversal.dart';
part 'node_library/window_mode.dart';
part 'node_library/display_settings.dart';
part 'node_library/combo_box.dart';
part 'node_library/umg_viewport.dart';
part 'node_library/pose_authoring.dart';
part 'node_library/conversions.dart';
part 'node_library/staged_settings.dart';
part 'node_library/editor_scope.dart';
part 'node_library/editor_events.dart';

/// The one node catalog the editor palette, the VM and the code generator
/// read.
abstract final class LuminaBlueprintNodeLibrary {
  static const String enhancedInputAction = 'event_enhanced_input_action';
  static const String variableGet = 'variable_get';
  static const String variableSet = 'variable_set';

  /// Trigger exec outputs of [enhancedInputAction], in pin order.
  static const List<String> inputTriggerPins = ['triggered', 'started', 'ongoing', 'canceled', 'completed'];

  /// Nodes the VM executes itself because they steer execution rather than
  /// compute: they have no function-library entry.
  static const Set<String> intrinsics = {
    'branch',
    'sequence',
    'delay',
    variableGet,
    variableSet,
    transitionResult,
    isValidBranch,
    castTo,
    functionEntry,
    functionResult,
    macroInput,
    macroOutput,
    callMacro,
    localVariableGet,
    localVariableSet,
    switchOnEnum,
    timeline,
    loadStreamLevel,
    asyncSaveGameToSlot,
    ...levelLoadLatents,
    ...flowIntrinsics,
  };

  /// The flow-control macros, run by the VM and written as
  /// Dart control flow by the generator.
  static const Set<String> flowIntrinsics = {
    'do_once',
    'flip_flop',
    'gate',
    'do_n',
    'for_loop',
    'for_loop_with_break',
    'while_loop',
    'for_each_loop',
    'retriggerable_delay',
    'switch_on_int',
    'switch_on_string',
    'switch_on_name',
    'switch_on_bool',
    'multi_gate',
  };

  /// Nodes with per-instance state the runtime keeps by node id.
  static const Set<String> statefulFlow = {'do_once', 'flip_flop', 'gate', 'do_n', 'multi_gate'};

  /// Nodes whose wildcard pins take the type of their `type` literal
  /// (`float`, `object`, …) and `class` literal.
  static const Set<String> wildcardNodes = {
    'array_get',
    'array_contains',
    'array_find',
    'array_first',
    'array_last',
    'make_array',
    'array_add',
    'array_set',
    'for_each_loop',
    'set_anim_variable',
    'get_anim_variable',
    'set_particle_parameter',
    'add_element_option',
    'set_element_selected_value',
    'get_element_selected_option',
    'get_element_option_value',
    'find_element_option_index_by_value',
  };

  /// Whether [node]'s wildcard pins take a type from its `type` / `class`
  /// literals, which the editor sets when a wildcard pin is wired: the
  /// [wildcardNodes] and a Combo Box's On Selection Changed (its Value).
  static bool adoptsWildcardType(LuminaBlueprintNode node) =>
      wildcardNodes.contains(node.registryId) ||
      (node.registryId == eventWidgetElement && node.literals['event'] == LuminaWidgetEvents.onSelectionChanged);

  /// The while loop's iteration cap (an infinite-loop guard).
  static const int whileLoopCap = 100000;

  /// Nodes whose object / array outputs take the class of their `class`
  /// literal.
  static const Set<String> classTypedNodes = {
    castTo,
    'get_component_by_class',
    'add_component',
    'spawn_actor_from_class',
    'get_all_actors_of_class',
    'get_actors_in_view_cone',
    'get_closest_actor_of_class_in_direction',
    'get_actors_within_radius',
    'sphere_overlap_actors',
    'array_filter_by_class',
    'get_overlapping_actors',
  };

  /// The trace nodes whose `channel` literal names a trace channel.
  static const Set<String> traceNodes = {
    'line_trace_by_channel',
    'line_trace_forward',
    'multi_line_trace_by_channel',
    'multi_line_trace_forward',
    'sphere_trace_by_channel',
    'sphere_trace_forward',
  };

  /// The actor events and the actor hook each is dispatched
  /// from, for the VM and the generator.
  static const Map<String, String> actorEventHooks = {
    'event_end_play': 'onEndPlay',
    'event_destroyed': 'onDestroyed',
    'event_any_damage': 'onAnyDamage',
    'event_take_point_damage': 'onPointDamage',
    'event_actor_begin_overlap': 'notifyActorBeginOverlap',
    'event_begin_overlap': 'notifyActorBeginOverlap',
    'event_actor_end_overlap': 'notifyActorEndOverlap',
    'event_end_overlap': 'notifyActorEndOverlap',
    'event_hit': 'notifyActorHit',
    'event_montage_ended': 'onMontageEnded',
    'event_anim_notify': 'onAnimNotify',
    'event_pose_handle_changed': 'onPoseHandleChanged',
    'event_pose_handle_grabbed': 'onPoseHandleGrabbed',
    'event_pose_handle_released': 'onPoseHandleReleased',
    'event_pose_handle_hovered': 'onPoseHandleHovered',
  };

  /// Typed object nodes.
  static const String isValidBranch = 'is_valid_branch';
  static const String castTo = 'cast_to';
  static const String getWidgetElement = 'get_widget_element';
  static const String getComponent = 'get_component';

  static const String _scene = 'LuminaSceneComponent';
  static const String _arm = 'LuminaSpringArmComponent';
  static const String _cam = 'LuminaCameraComponent';
  static const String _skel = 'LuminaAnimatedMeshComponent';
  static const String _mesh = 'LuminaStaticMeshComponent';
  static const String _coll = 'LuminaCollisionComponent';
  static const String _box = 'LuminaBoxComponent';
  static const String _sphere = 'LuminaSphereComponent';
  static const String _capsule = 'LuminaCapsuleComponent';
  static const String _move = 'LuminaCharacterMovementComponent';
  static const LuminaBlueprintPinSpec _bone =
      LuminaBlueprintPinSpec('bone_name', 'Bone Name', LuminaPinType.name, defaultValue: '');

  /// Custom events, functions, macros, dispatchers, interfaces, enums and
  /// timelines.
  static const String customEvent = 'custom_event';
  static const String callCustomEvent = 'call_custom_event';
  static const String functionEntry = 'function_entry';
  static const String functionResult = 'function_result';
  static const String callFunction = 'call_function';
  static const String callFunctionPure = 'call_function_pure';
  static const String macroInput = 'macro_input';
  static const String macroOutput = 'macro_output';
  static const String callMacro = 'call_macro';
  static const String localVariableGet = 'local_variable_get';
  static const String localVariableSet = 'local_variable_set';
  static const String callDispatcher = 'call_dispatcher';
  static const String bindEventToDispatcher = 'bind_event_to_dispatcher';
  static const String unbindEventFromDispatcher = 'unbind_event_from_dispatcher';
  static const String unbindAllEvents = 'unbind_all_events';
  static const String interfaceMessage = 'interface_message';
  static const String implementsInterface = 'implements_interface';
  static const String eventInterfaceFunction = 'event_interface_function';
  static const String enumLiteral = 'enum_literal';
  static const String switchOnEnum = 'switch_on_enum';
  static const String timeline = 'timeline';

  /// Game framework, save game and latent nodes.
  static const String getGameMode = 'get_game_mode';
  static const String loadStreamLevel = 'load_stream_level';

  /// Level loading with progress: Load Level preloads a
  /// persistent level, Change Level switches to it, Load And Change Level
  /// does both.
  static const String loadLevel = 'load_level';
  static const String changeLevel = 'change_level';
  static const String loadAndChangeLevel = 'load_and_change_level';

  /// The level-loading latents: each result pin (On Progress, On Error, On
  /// Success) re-enters the chain with fresh output values, and calls the
  /// custom event bound to its delegate input.
  static const Set<String> levelLoadLatents = {loadLevel, changeLevel, loadAndChangeLevel};
  static const String asyncSaveGameToSlot = 'async_save_game_to_slot';
  static const String createSaveGameObject = 'create_save_game_object';
  static const String setSaveField = 'set_save_field';
  static const String getSaveField = 'get_save_field';

  /// Level Blueprints: a placed actor by name, the level's
  /// actors of a class, and the level's own events.
  static const String getLevelActor = 'get_level_actor';
  static const String getLevelActorsOfClass = 'get_level_actors_of_class';
  static const String eventLevelBeginPlay = 'event_level_begin_play';
  static const String eventLevelTick = 'event_level_tick';
  static const String eventLevelEndPlay = 'event_level_end_play';
  static const String eventLevelLoaded = 'event_level_loaded';
  static const String eventLevelUnloaded = 'event_level_unloaded';

  /// The level events, and the actor event each one is an alias of in a
  /// Level Blueprint (placing both is placing the event twice).
  static const Map<String, String?> levelEvents = {
    eventLevelBeginPlay: 'event_beginplay',
    eventLevelTick: 'event_tick',
    eventLevelEndPlay: 'event_end_play',
    eventLevelLoaded: null,
    eventLevelUnloaded: null,
  };

  /// Nodes only a Level Blueprint may hold.
  static const Set<String> levelOnlyNodes = {
    getLevelActor,
    getLevelActorsOfClass,
    eventLevelBeginPlay,
    eventLevelTick,
    eventLevelEndPlay,
    eventLevelLoaded,
    eventLevelUnloaded,
  };

  /// Nodes that reach the Blueprint's own components, which a Level
  /// Blueprint has none of.
  static const Set<String> selfComponentNodes = {getComponent, 'get_component_by_class', 'add_component'};

  /// Widget Blueprint graphs: the widget's lifecycle events, a
  /// bound element event (`On Clicked (StartButton)`, literals `element` +
  /// `event`), an `Is Variable` element (literal `element`) and Self.
  static const String eventWidgetConstruct = 'event_widget_construct';
  static const String eventWidgetPreConstruct = 'event_widget_pre_construct';
  static const String eventWidgetDestruct = 'event_widget_destruct';
  static const String eventWidgetTick = 'event_widget_tick';
  static const String eventWidgetElement = 'event_widget_element';
  static const String getWidgetVariable = 'get_widget_variable';
  static const String getWidgetSelf = 'get_widget_self';

  /// Nodes only a Widget Blueprint graph may hold.
  static const Set<String> widgetOnlyNodes = {
    eventWidgetConstruct,
    eventWidgetPreConstruct,
    eventWidgetDestruct,
    eventWidgetTick,
    eventWidgetElement,
    getWidgetVariable,
    getWidgetSelf,
  };

  /// The actor's own events, which a widget does not have.
  static const Set<String> actorEvents = {
    'event_beginplay',
    'event_tick',
    'event_input_axis',
    'event_input_action',
    enhancedInputAction,
  };

  /// `ESlateVisibility`: the values Set Visibility takes (strings at run time).
  static const String slateVisibilityEnum = 'ESlateVisibility';
  static const List<String> slateVisibilities = ['Visible', 'Collapsed', 'Hidden', 'HitTestInvisible', 'SelfHitTestInvisible'];

  /// `ETextCommit`: how On Text Committed was committed.
  static const String textCommitEnum = 'ETextCommit';

  /// The values of an engine enum ([slateVisibilityEnum], [textCommitEnum],
  /// [timelineDirectionEnum]), or null for a project enum.
  static List<String>? engineEnumValues(String? name) => switch (name) {
        slateVisibilityEnum => slateVisibilities,
        textCommitEnum => LuminaWidgetEvents.commitMethods,
        LuminaComboBoxOptions.selectInfoEnum => LuminaComboBoxOptions.selectInfos,
        timelineDirectionEnum => timelineDirections,
        _ => LuminaViewportNodes.enumValues(name),
      };

  /// Whether node [spec] belongs in a graph of [context]: level-only nodes
  /// in a Level Blueprint, component nodes everywhere else (the palette's
  /// filter); widget-only nodes in a Widget Blueprint, which
  /// takes no actor events, level nodes or components.
  static bool availableIn(LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeContext context) {
    // Editor panels: editor-only nodes there only, game-only nodes never.
    if (spec.editorOnly && !context.isEditorScope) return false;
    if (context.isEditorScope && _isGameOnly(spec)) return false;
    if (context.isWidgetScope) {
      return !levelOnlyNodes.contains(spec.id) &&
          !selfComponentNodes.contains(spec.id) &&
          !actorEvents.contains(spec.id) &&
          !actorEventHooks.containsKey(spec.id);
    }
    if (widgetOnlyNodes.contains(spec.id)) return false;
    return context.isLevelScope ? !selfComponentNodes.contains(spec.id) : !levelOnlyNodes.contains(spec.id);
  }

  /// Why [node] breaks the Widget Blueprint or editor panel rules of
  /// [context], or null.
  static String? widgetScopeError(LuminaBlueprintNode node, LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeContext context) =>
      _editorScopeError(node, spec, context) ?? _widgetScopeError(node, spec, context);

  /// Whether [spec] acts on the game (the player, input, level travel, save
  /// games, …) and so is never offered in an editor panel.
  static bool isGameOnly(LuminaBlueprintNodeSpec spec) => _isGameOnly(spec);

  /// Latent nodes whose Completed pin fires from a callback:
  /// the VM and the generator resume the chain there.
  static const Set<String> callbackLatents = {loadStreamLevel, asyncSaveGameToSlot};

  /// The enum a Timeline's Direction output carries.
  static const String timelineDirectionEnum = 'ETimelineDirection';
  static const List<String> timelineDirections = ['Forward', 'Backward'];

  /// Nodes whose data pins come from a signature the VM and generator pass
  /// as a name → value map: the call is variadic.
  static const Set<String> signatureCalls = {callCustomEvent, callFunction, callFunctionPure, callDispatcher, interfaceMessage};

  /// Nodes whose every pin comes from the document (a function's or
  /// macro's signature) — their spec declares none.
  static const Set<String> dynamicPinNodes = {callFunctionPure, macroInput, macroOutput, callMacro};

  /// The custom events [graph] declares, with their parameters.
  static List<LuminaBlueprintCustomEvent> customEventsOf(LuminaBlueprintGraph graph) => [
        for (final n in graph.nodes)
          if (n.registryId == customEvent && n.literals['name'] is String && (n.literals['name'] as String).isNotEmpty)
            LuminaBlueprintCustomEvent(name: n.literals['name'] as String, parameters: customEventParameters(n), nodeId: n.id),
      ];

  /// A custom event node's parameters: its `parameters` literal
  /// (`[{name, type, default}]`), else its stored data outputs.
  static List<LuminaBlueprintVariable> customEventParameters(LuminaBlueprintNode node) {
    final literal = node.literals['parameters'];
    if (literal is List) {
      return [for (final p in literal) if (p is Map) LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(p))];
    }
    return [
      for (final p in node.outputs)
        if (p.type != null && p.type != LuminaPinType.exec && p.type != LuminaPinType.delegate)
          LuminaBlueprintVariable(name: p.id, typeName: _typeNameOfPin(p), defaultValue: p.defaultValue),
    ];
  }

  /// The variable type name a stored pin declares (`Int`, `Enum:X`, `Actor:BP_Door`, `Array:Float`).
  static String _typeNameOfPin(LuminaBlueprintPin p) {
    final t = p.type ?? LuminaPinType.wildcard;
    if (t == LuminaPinType.object) return p.objectClass ?? LuminaBlueprintObjectClass.any;
    if (t == LuminaPinType.enumeration) return 'Enum:${p.enumName ?? ''}';
    if (t == LuminaPinType.array) {
      final of = p.elementType ?? LuminaPinType.wildcard;
      return 'Array:${of == LuminaPinType.object ? (p.objectClass ?? LuminaBlueprintObjectClass.any) : of.name}';
    }
    return t.name;
  }

  /// Animation Blueprint nodes.
  static const String updateAnimation = 'event_blueprint_update_animation';
  static const String transitionResult = 'transition_result';

  /// Every node: the built-ins, then the functions registered or declared in
  /// [LuminaBlueprintFunctionRegistry].
  static List<LuminaBlueprintNodeSpec> get all => LuminaBlueprintFunctionRegistry.isEmpty
      ? builtIns
      : List.unmodifiable([...builtIns, ...LuminaBlueprintFunctionRegistry.specs]);

  /// The nodes lumina ships.
  static final List<LuminaBlueprintNodeSpec> builtIns = List.unmodifiable(_markStagedSettings(<LuminaBlueprintNodeSpec>[
    ..._eventPawnUiInputNodes,
    ..._mathObjectComponentNodes,
    ..._mathStringArrayNodes,
    ..._flowControlNodes,
    ..._engineAndActorNodes,
    ..._graphMemberNodes,
    ..._gameFrameworkNodes,
    ..._renderingFeatureNodes,
    ..._mediaAndDebugNodes,
    ..._widgetBlueprintNodes,
    ..._ragdollNodes,
    ..._traversalNodes,
    ..._windowModeNodes,
    ..._displaySettingsNodes,
    ..._comboBoxNodes,
    ..._umgViewportNodes,
    ..._poseAuthoringNodes,
    ..._conversionNodes,
    ..._editorEventNodes,
  ]));

  static final Map<String, LuminaBlueprintNodeSpec> _byId = {for (final s in builtIns) s.id: s};

  /// The node [id]: a built-in, else a registered or declared function.
  static LuminaBlueprintNodeSpec? spec(String id) => _byId[id] ?? LuminaBlueprintFunctionRegistry.spec(id);

  /// The built-in node [id] only.
  static LuminaBlueprintNodeSpec? builtIn(String id) => _byId[id];

  /// The pin type an input action's value carries.
  static LuminaPinType actionValueType(InputValueType type) {
    switch (type) {
      case InputValueType.digitalBool:
        return LuminaPinType.boolean;
      case InputValueType.axis1D:
        return LuminaPinType.float;
      case InputValueType.axis2D:
        return LuminaPinType.vector2D;
      case InputValueType.axis3D:
        return LuminaPinType.vector;
    }
  }

  /// The node's pins as the library resolves them for [context]. Fixed nodes
  /// take the spec's pins (a stored node's pin list cannot change them);
  /// variable nodes type their value from the variable, an input action node
  /// its Action Value from the action, and a Sequence keeps its stored outputs.
  /// Null for an unknown node.
  static ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})? pinsOf(
    LuminaBlueprintNode node,
    LuminaBlueprintTypeContext context,
  ) =>
      _pinsOf(node, context);

  /// The pin type of a timeline track (`float`, `vector`, `color`).
  static LuminaPinType timelineTrackType(String type) => switch (type.toLowerCase()) {
        'vector' => LuminaPinType.vector,
        'color' || 'linearcolor' => LuminaPinType.color,
        _ => LuminaPinType.float,
      };

  /// `AddHealth` → `Add Health`, `OnDoorOpened` → `On Door Opened`.
  static String displayTitle(String name) =>
      name.replaceAll('_', ' ').replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (m) => ' ').trim();

  /// A new node of library node [id] at ([x], [y]), with pins resolved for
  /// [context]. [literals] carries node settings such as `action` or
  /// `variable`.
  static LuminaBlueprintNode place(
    String id, {
    required String nodeId,
    double x = 0.0,
    double y = 0.0,
    Map<String, dynamic>? literals,
    LuminaBlueprintTypeContext context = const LuminaBlueprintTypeContext(),
  }) {
    final s = spec(id);
    if (s == null) throw ArgumentError.value(id, 'id', 'not a Blueprint library node');
    final node = LuminaBlueprintNode(
      id: nodeId,
      registryId: id,
      title: s.title,
      category: s.category,
      x: x,
      y: y,
      headerColor: s.headerColor,
      literals: {...?literals},
    );
    final pins = pinsOf(node, context)!;
    node.inputs.addAll(pins.inputs.map((p) => p.toPin(isOutput: false)));
    node.outputs.addAll(pins.outputs.map((p) => p.toPin(isOutput: true)));
    if (id == enhancedInputAction && literals?['action'] is String) node.title = literals!['action'] as String;
    final variable = literals?['variable'];
    if ((id == variableGet || id == variableSet) && variable is String) {
      node.title = '${s.title} $variable';
      final cls = literals?['class'];
      if (cls is String && cls.isNotEmpty) {
        final clsName = LuminaBlueprintObjectClass.name(cls);
        if (clsName.isNotEmpty) node.category = 'Variables|$clsName';
      }
    }
    final element = literals?['element'];
    if (id == getWidgetElement && element is String && element.isNotEmpty) {
      node.title = 'Get $element';
      final owner = pins.inputs.firstWhere((p) => p.id == 'target').objectClass;
      final cls = owner == null ? '' : LuminaBlueprintObjectClass.name(owner);
      if (cls.isNotEmpty) node.category = 'Widget|$cls';
    }
    final component = literals?['component'];
    if (id == getComponent && component is String && component.isNotEmpty) {
      node.title = 'Get $component';
      final cls = literals?['class'];
      if (cls is String && cls.isNotEmpty) {
        final clsName = LuminaBlueprintObjectClass.name(cls);
        if (clsName.isNotEmpty) node.category = 'Components|$clsName';
      }
    }
    if (id == castTo && literals?['class'] is String && (literals!['class'] as String).isNotEmpty) {
      node.title = 'Cast To ${LuminaBlueprintObjectClass.displayName(literals['class'] as String)}';
    }
    if (id == 'spawn_actor_from_class' && literals?['class'] is String && (literals!['class'] as String).isNotEmpty) {
      node.title = 'SpawnActor ${LuminaBlueprintObjectClass.displayName(literals['class'] as String)}';
    }
    // Graph-member node titles.
    String? lit(String key) => literals?[key] is String && (literals![key] as String).isNotEmpty ? literals[key] as String : null;
    switch (id) {
      case customEvent:
        if (lit('name') != null) node.title = lit('name')!;
      case callCustomEvent:
        if (lit('event') != null) node.title = lit('event')!;
      case callFunction:
      case callFunctionPure:
        if (lit('function') != null) node.title = displayTitle(lit('function')!);
      case callMacro:
        if (lit('macro') != null) node.title = displayTitle(lit('macro')!);
      case localVariableGet:
      case localVariableSet:
        if (lit('variable') != null) node.title = '${s.title} ${lit('variable')}';
      case callDispatcher:
        if (lit('dispatcher') != null) node.title = 'Call ${displayTitle(lit('dispatcher')!)}';
      case bindEventToDispatcher:
        if (lit('dispatcher') != null) node.title = 'Bind Event to ${displayTitle(lit('dispatcher')!)}';
      case unbindEventFromDispatcher:
        if (lit('dispatcher') != null) node.title = 'Unbind Event from ${displayTitle(lit('dispatcher')!)}';
      case unbindAllEvents:
        if (lit('dispatcher') != null) node.title = 'Unbind all Events from ${displayTitle(lit('dispatcher')!)}';
      case interfaceMessage:
        if (lit('function') != null) node.title = '${displayTitle(lit('function')!)} (Message)';
      case eventInterfaceFunction:
        if (lit('function') != null) node.title = 'Event ${displayTitle(lit('function')!)}';
      case getLevelActor:
        if (lit('actor') != null) node.title = lit('actor')!;
      case eventWidgetElement:
      case getWidgetVariable:
        node.title = _widgetTitleOf(id, literals) ?? node.title;
      case enumLiteral:
        if (lit('enum') != null) node.title = lit('enum')!;
      case switchOnEnum:
        if (lit('enum') != null) node.title = 'Switch on ${lit('enum')}';
      case timeline:
        if (lit('name') != null) node.title = lit('name')!;
      case setSaveField:
        if (lit('field') != null) node.title = 'Set ${lit('field')}';
      case getSaveField:
        if (lit('field') != null) node.title = 'Get ${lit('field')}';
      case createSaveGameObject:
        if (lit('class') != null) node.title = 'Create Save Game Object (${LuminaBlueprintObjectClass.displayName(lit('class')!.contains(':') ? lit('class')! : LuminaBlueprintObjectClass.saveGame(lit('class')!))})';
    }
    return node;
  }

  /// Why output pin [from] cannot be wired into input pin [to], or null when
  /// it can: the types must match and, for object pins, the classes must be
  /// assignable; an array's element types must match too.
  static String? connectionError(
    LuminaBlueprintPinSpec from,
    LuminaBlueprintPinSpec to, {
    LuminaBlueprintTypeContext context = const LuminaBlueprintTypeContext(),
  }) {
    if (from.type == LuminaPinType.wildcard || to.type == LuminaPinType.wildcard) {
      if (from.type == LuminaPinType.exec || to.type == LuminaPinType.exec) return 'Cannot connect exec to a data pin.';
      return null;
    }
    if (from.type != to.type) return 'Cannot connect ${from.type.name} to ${to.type.name}.';
    if (from.type == LuminaPinType.object) return context.assignError(from.objectClass, to.objectClass);
    if (from.type == LuminaPinType.enumeration && from.enumName != null && to.enumName != null && from.enumName != to.enumName) {
      return 'Cannot connect ${from.enumName} to ${to.enumName}.';
    }
    if (from.type == LuminaPinType.array) {
      final a = from.elementType;
      final b = to.elementType;
      if (a != null && b != null && a != b) return 'Cannot connect array of ${a.name} to array of ${b.name}.';
      if (a == LuminaPinType.object || b == LuminaPinType.object) {
        return context.assignError(from.objectClass, to.objectClass);
      }
    }
    return null;
  }

  /// The node that converts a [from] value into a [to] input, for the editor
  /// to insert between two mismatched pins; null when there is none.
  static LuminaBlueprintConversion? conversionNodeFor(LuminaPinType from, LuminaPinType to) => _conversionNodeFor(from, to);

  /// Whether output pin [from] can be wired into input pin [to].
  static bool canConnect(
    LuminaBlueprintPinSpec from,
    LuminaBlueprintPinSpec to, {
    LuminaBlueprintTypeContext context = const LuminaBlueprintTypeContext(),
  }) =>
      connectionError(from, to, context: context) == null;
}
