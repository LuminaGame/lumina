import 'package:lumina/lumina.dart';

/// `WBP_Customizer`, a character customisation screen: a Viewport `Preview`
/// shows the mannequin playing its idle with a hat at its head; Next Hat
/// swaps the hat, Colour tints the mannequin, picking a part prints it and
/// releasing an orbit shows the camera in the `Status` text.
const String customizerClass = 'WBP_Customizer';

/// The project assets the graph names (project-relative, as the editor
/// stores them).
const String customizerMannequin = 'contents/meshes/skeletal/SKM_UEFN_Mannequin.lmas';
const String customizerIdle = 'contents/animations/M_Neutral_Stand_Idle_Loop/M_Neutral_Stand_Idle_Loop.lmas';
const String customizerHatA = 'contents/meshes/static/SM_Hat_A.lmas';
const String customizerHatB = 'contents/meshes/static/SM_Hat_B.lmas';

/// The widget class: the Viewport `Preview`, the buttons `NextHat` and
/// `Colour`, and the Text `Status`, all `Is Variable`.
const LuminaBlueprintWidgetClass customizerWidgetClass = LuminaBlueprintWidgetClass(name: customizerClass, elements: [
  LuminaBlueprintWidgetElement(name: 'Preview', fieldName: 'preview', typeName: 'viewport', props: {
    'background': 'sky',
    'grid': true,
    'renderScale': 1.0,
    'maxFps': 60,
  }),
  LuminaBlueprintWidgetElement(name: 'NextHat', fieldName: 'nextHat', typeName: 'button', props: {'label': 'Next Hat'}),
  LuminaBlueprintWidgetElement(name: 'Colour', fieldName: 'colour', typeName: 'button', props: {'label': 'Colour'}),
  LuminaBlueprintWidgetElement(name: 'Status', fieldName: 'status', typeName: 'text', props: {'text': ''}),
]);

/// The graph:
/// - Event Construct → Viewport Add Skeletal Mesh (the mannequin) → set Hero
///   → Viewport Play Animation (Hero, idle, loop) → Viewport Add Static Mesh
///   (hat A) → set Hat → Viewport Attach To Socket (Hat, Hero, `head`) →
///   Viewport Show Skeleton (Hero) → Print `ready <Hero> <Hat>`;
/// - On Clicked (NextHat) → set HatIndex = (HatIndex + 1) % 2 → Viewport Set
///   Node Mesh (Hat, HatIndex == 1 ? hat B : hat A) → Print the index;
/// - On Clicked (Colour) → Viewport Set Material Parameter (Hero, slot 0,
///   `baseColorFactor`, Make Color 0.9 / 0.2 / 0.1) → Print `tinted`;
/// - On Picked (Preview) → Print `picked <node> <bone>`;
/// - On Camera Changed (Preview) → Set Text (Status, the yaw as text) →
///   Print `camera <yaw>`.
LuminaWidgetBlueprintDocument customizerBlueprint() {
  final widget = LuminaWidgetBlueprintDocument(widgetClass: customizerClass, variables: customizerWidgetClass.elements);
  widget.blueprint.variables.addAll(const [
    LuminaBlueprintVariable(name: 'Hero', typeName: 'String', defaultValue: ''),
    LuminaBlueprintVariable(name: 'Hat', typeName: 'String', defaultValue: ''),
    LuminaBlueprintVariable(name: 'HatIndex', typeName: 'Integer', defaultValue: 0),
  ]);
  final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [customizerWidgetClass]);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  final g = widget.blueprint.eventGraph;
  g.nodes.addAll([
    p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'preview', {'element': 'Preview'}),
    p('viewport_add_skeletal_mesh', 'add_hero', {'skeletal_mesh': customizerMannequin}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_hero', {'variable': 'Hero'}),
    p('viewport_play_animation', 'idle', {'animation': customizerIdle, 'loop': true, 'play_rate': 1.0}),
    p('viewport_add_static_mesh', 'add_hat', {'mesh': customizerHatA}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_hat', {'variable': 'Hat'}),
    p('viewport_attach_to_socket', 'attach', {'socket': 'head'}),
    p('viewport_show_skeleton', 'bones', {'joints': true}),
    p(LuminaBlueprintNodeLibrary.variableGet, 'hero', {'variable': 'Hero'}),
    p(LuminaBlueprintNodeLibrary.variableGet, 'hat', {'variable': 'Hat'}),
    p('append', 'ready_a', {'a': 'ready '}),
    p('append', 'ready_b', {'b': ' '}),
    p('append', 'ready_c'),
    p('print_string', 'say_ready', {'print_to_screen': false}),
    // Next Hat.
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'next', {'element': 'NextHat', 'event': 'OnClicked'}),
    p(LuminaBlueprintNodeLibrary.variableGet, 'index', {'variable': 'HatIndex'}),
    p('int_increment', 'inc'),
    p('int_modulo', 'wrap', {'b': 2}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_index', {'variable': 'HatIndex'}),
    p('int_equal', 'is_b', {'b': 1}),
    p('select_string', 'which', {'a': customizerHatB, 'b': customizerHatA}),
    p('viewport_set_node_mesh', 'swap'),
    p('int_to_string', 'index_text'),
    p('print_string', 'say_hat', {'print_to_screen': false}),
    // Colour.
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'colour', {'element': 'Colour', 'event': 'OnClicked'}),
    p('make_color', 'tint', {'r': 0.9, 'g': 0.2, 'b': 0.1, 'a': 1.0}),
    p('viewport_set_material_parameter', 'paint', {'slot': '0', 'parameter': 'baseColorFactor'}),
    p('print_string', 'say_tint', {'in_string': 'tinted', 'print_to_screen': false}),
    // On Picked.
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'picked', {'element': 'Preview', 'event': 'OnPicked'}),
    p('append', 'picked_a', {'a': 'picked '}),
    p('append', 'picked_b', {'b': ' '}),
    p('append', 'picked_c'),
    p('print_string', 'say_picked', {'print_to_screen': false}),
    // On Camera Changed.
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'camera', {'element': 'Preview', 'event': 'OnCameraChanged'}),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'status', {'element': 'Status'}),
    p('float_to_string', 'yaw_text'),
    p('set_element_text', 'show_yaw'),
    p('append', 'camera_text', {'a': 'camera '}),
    p('print_string', 'say_camera', {'print_to_screen': false}),
  ]);
  g.wires.addAll([
    w('construct', 'exec_out', 'add_hero', 'exec_in'),
    w('preview', 'return_value', 'add_hero', 'target'),
    w('add_hero', 'exec_out', 'set_hero', 'exec_in'),
    w('add_hero', 'return_value', 'set_hero', 'value'),
    w('set_hero', 'exec_out', 'idle', 'exec_in'),
    w('preview', 'return_value', 'idle', 'target'),
    w('hero', 'value', 'idle', 'node_id'),
    w('idle', 'exec_out', 'add_hat', 'exec_in'),
    w('preview', 'return_value', 'add_hat', 'target'),
    w('add_hat', 'exec_out', 'set_hat', 'exec_in'),
    w('add_hat', 'return_value', 'set_hat', 'value'),
    w('set_hat', 'exec_out', 'attach', 'exec_in'),
    w('preview', 'return_value', 'attach', 'target'),
    w('hat', 'value', 'attach', 'node_id'),
    w('hero', 'value', 'attach', 'parent'),
    w('attach', 'exec_out', 'bones', 'exec_in'),
    w('preview', 'return_value', 'bones', 'target'),
    w('hero', 'value', 'bones', 'node_id'),
    w('bones', 'exec_out', 'say_ready', 'exec_in'),
    w('hero', 'value', 'ready_a', 'b'),
    w('ready_a', 'return_value', 'ready_b', 'a'),
    w('ready_b', 'return_value', 'ready_c', 'a'),
    w('hat', 'value', 'ready_c', 'b'),
    w('ready_c', 'return_value', 'say_ready', 'in_string'),
    w('next', 'exec_out', 'set_index', 'exec_in'),
    w('index', 'value', 'inc', 'a'),
    w('inc', 'return_value', 'wrap', 'a'),
    w('wrap', 'return_value', 'set_index', 'value'),
    w('set_index', 'exec_out', 'swap', 'exec_in'),
    w('preview', 'return_value', 'swap', 'target'),
    w('hat', 'value', 'swap', 'node_id'),
    w('index', 'value', 'is_b', 'a'),
    w('is_b', 'return_value', 'which', 'pick_a'),
    w('which', 'return_value', 'swap', 'mesh'),
    w('swap', 'exec_out', 'say_hat', 'exec_in'),
    w('index', 'value', 'index_text', 'in_int'),
    w('index_text', 'return_value', 'say_hat', 'in_string'),
    w('colour', 'exec_out', 'paint', 'exec_in'),
    w('preview', 'return_value', 'paint', 'target'),
    w('hero', 'value', 'paint', 'node_id'),
    w('tint', 'return_value', 'paint', 'value'),
    w('paint', 'exec_out', 'say_tint', 'exec_in'),
    w('picked', 'exec_out', 'say_picked', 'exec_in'),
    w('picked', 'node_id', 'picked_a', 'b'),
    w('picked_a', 'return_value', 'picked_b', 'a'),
    w('picked_b', 'return_value', 'picked_c', 'a'),
    w('picked', 'bone', 'picked_c', 'b'),
    w('picked_c', 'return_value', 'say_picked', 'in_string'),
    w('camera', 'exec_out', 'show_yaw', 'exec_in'),
    w('status', 'return_value', 'show_yaw', 'target'),
    w('camera', 'yaw', 'yaw_text', 'in_float'),
    w('yaw_text', 'return_value', 'show_yaw', 'in_text'),
    w('show_yaw', 'exec_out', 'say_camera', 'exec_in'),
    w('yaw_text', 'return_value', 'camera_text', 'b'),
    w('camera_text', 'return_value', 'say_camera', 'in_string'),
  ]);
  return widget;
}
