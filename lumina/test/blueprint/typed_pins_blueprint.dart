import 'package:lumina/lumina.dart';

/// The widget class BP_TypedPins creates.
const LuminaBlueprintWidgetClass typedPinsHud = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
  LuminaBlueprintWidgetElement(name: 'FPSCounter', typeName: 'text', props: {'text': 'FPS: 0'}),
  LuminaBlueprintWidgetElement(name: 'Health', typeName: 'progressBar', props: {'percent': 1.0}),
  LuminaBlueprintWidgetElement(name: 'Panel', typeName: 'container', props: {'backgroundColor': '#1E1E2A'}),
]);

/// A Character Blueprint exercising typed pins for VM ↔ codegen parity:
/// a typed widget variable, Create Widget → Get FPSCounter → Set Text, Is
/// Valid?, Cast To on Get Player Character, and Get CameraBoom → Set / Get
/// Target Arm Length, the shadow / outline setters on
/// FPSCounter and the Container setters on Panel.
LuminaBlueprintDocument typedPinsBlueprint() {
  const variables = [
    LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD'),
    LuminaBlueprintVariable(name: 'ArmLength', typeName: 'Float', defaultValue: 0.0),
    LuminaBlueprintVariable(name: 'Ticks', typeName: 'Int', defaultValue: 0),
  ];
  final components = [
    LuminaBlueprintComponent(id: 'capsule', name: 'CapsuleComponent', type: 'LuminaCapsuleComponent'),
    LuminaBlueprintComponent(
        id: 'boom',
        name: 'CameraBoom',
        type: 'LuminaSpringArmComponent',
        parentId: 'capsule',
        properties: {'targetArmLength': 400.0}),
    LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', variables: [...variables], components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, widgetClasses: const [typedPinsHud], className: 'bp_typed_pins');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('create_widget', 'create', {'class': 'WBP_HUD'}),
    place(LuminaBlueprintNodeLibrary.variableSet, 'set_hud', {'variable': 'HudWidget'}),
    place('add_to_viewport', 'show'),
    place('get_player_character', 'me'),
    place(LuminaBlueprintNodeLibrary.castTo, 'cast', {'class': 'Actor:LuminaCharacter'}),
    place('get_class_name', 'class_name'),
    place('print_string', 'is_character'),
    place('print_string', 'not_character', {'in_string': 'not a character'}),
    place(LuminaBlueprintNodeLibrary.castTo, 'cast_door', {'class': 'Actor:BP_Door'}),
    place('print_string', 'is_door', {'in_string': 'a door'}),
    place('print_string', 'not_door', {'in_string': 'not a door'}),
    place(LuminaBlueprintNodeLibrary.getComponent, 'boom', {'component': 'CameraBoom'}),
    place('set_target_arm_length', 'arm', {'target_arm_length': 500.0}),
    place('get_target_arm_length', 'arm_len'),
    place(LuminaBlueprintNodeLibrary.variableSet, 'set_len', {'variable': 'ArmLength'}),
    place('event_tick', 'tick'),
    place(LuminaBlueprintNodeLibrary.variableGet, 'hud', {'variable': 'HudWidget'}),
    place(LuminaBlueprintNodeLibrary.isValidBranch, 'valid'),
    place(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
    place('set_element_text', 'set_text', {'in_text': 'FPS: 60'}),
    place('set_element_shadow_enabled', 'shadow_on'),
    place('set_element_shadow_color', 'shadow_color', {'in_color': [1.0, 0.0, 0.0, 0.5]}),
    place('set_element_shadow_offset', 'shadow_offset', {'in_offset': [3.0, 4.0]}),
    place('set_element_outline', 'outline', {'in_size': 2.0, 'in_color': [0.0, 0.0, 0.0, 1.0]}),
    place(LuminaBlueprintNodeLibrary.getWidgetElement, 'panel', {'element': 'Panel'}),
    place('set_element_background_color', 'panel_bg', {'in_color': [0.2, 0.4, 0.6, 1.0]}),
    place('set_element_border_color', 'panel_border', {'in_color': [1.0, 0.5, 0.0, 1.0]}),
    place('set_element_corner_radius', 'panel_radius', {'in_radius': 12.0}),
    place('set_element_padding', 'panel_padding', {'left': 4.0, 'top': 8.0, 'right': 4.0, 'bottom': 8.0}),
    place('get_element_text', 'read_text'),
    place('print_string', 'echo'),
    place('print_string', 'no_hud', {'in_string': 'no hud'}),
    place('is_valid', 'is_valid'),
    place('get_display_name', 'boom_name'),
    place('print_string', 'say_boom'),
  ]);
  doc.eventGraph.wires.addAll([
    wire('begin', 'exec_out', 'create', 'exec_in'),
    wire('create', 'exec_out', 'set_hud', 'exec_in'),
    wire('create', 'return_value', 'set_hud', 'value'),
    wire('set_hud', 'exec_out', 'show', 'exec_in'),
    wire('set_hud', 'value', 'show', 'target'),
    wire('show', 'exec_out', 'cast', 'exec_in'),
    wire('me', 'return_value', 'cast', 'object'),
    wire('cast', 'cast_succeeded', 'is_character', 'exec_in'),
    wire('cast', 'as_class', 'class_name', 'object'),
    wire('class_name', 'return_value', 'is_character', 'in_string'),
    wire('cast', 'cast_failed', 'not_character', 'exec_in'),
    wire('is_character', 'exec_out', 'cast_door', 'exec_in'),
    wire('not_character', 'exec_out', 'cast_door', 'exec_in'),
    wire('me', 'return_value', 'cast_door', 'object'),
    wire('cast_door', 'cast_succeeded', 'is_door', 'exec_in'),
    wire('cast_door', 'cast_failed', 'not_door', 'exec_in'),
    wire('not_door', 'exec_out', 'arm', 'exec_in'),
    wire('boom', 'return_value', 'arm', 'target'),
    wire('arm', 'exec_out', 'set_len', 'exec_in'),
    wire('boom', 'return_value', 'arm_len', 'target'),
    wire('arm_len', 'return_value', 'set_len', 'value'),
    wire('set_len', 'exec_out', 'say_boom', 'exec_in'),
    wire('boom', 'return_value', 'boom_name', 'object'),
    wire('boom_name', 'return_value', 'say_boom', 'in_string'),
    wire('tick', 'exec_tick_out', 'valid', 'exec_in'),
    wire('hud', 'value', 'valid', 'input_object'),
    wire('valid', 'is_valid', 'set_text', 'exec_in'),
    wire('hud', 'value', 'fps', 'target'),
    wire('fps', 'return_value', 'set_text', 'target'),
    wire('set_text', 'exec_out', 'shadow_on', 'exec_in'),
    wire('fps', 'return_value', 'shadow_on', 'target'),
    wire('shadow_on', 'exec_out', 'shadow_color', 'exec_in'),
    wire('fps', 'return_value', 'shadow_color', 'target'),
    wire('shadow_color', 'exec_out', 'shadow_offset', 'exec_in'),
    wire('fps', 'return_value', 'shadow_offset', 'target'),
    wire('shadow_offset', 'exec_out', 'outline', 'exec_in'),
    wire('fps', 'return_value', 'outline', 'target'),
    wire('outline', 'exec_out', 'panel_bg', 'exec_in'),
    wire('hud', 'value', 'panel', 'target'),
    wire('panel', 'return_value', 'panel_bg', 'target'),
    wire('panel_bg', 'exec_out', 'panel_border', 'exec_in'),
    wire('panel', 'return_value', 'panel_border', 'target'),
    wire('panel_border', 'exec_out', 'panel_radius', 'exec_in'),
    wire('panel', 'return_value', 'panel_radius', 'target'),
    wire('panel_radius', 'exec_out', 'panel_padding', 'exec_in'),
    wire('panel', 'return_value', 'panel_padding', 'target'),
    wire('panel_padding', 'exec_out', 'echo', 'exec_in'),
    wire('fps', 'return_value', 'read_text', 'target'),
    wire('read_text', 'return_value', 'echo', 'in_string'),
    wire('valid', 'is_not_valid', 'no_hud', 'exec_in'),
    wire('hud', 'value', 'is_valid', 'input_object'),
  ]);
  return doc;
}
