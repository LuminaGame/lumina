import 'package:lumina/lumina.dart';

/// `WBP_SettingsMenu`, a settings menu whose Combo Box lists the monitor's
/// resolutions: each option's label is `W×H` and its value the Vector 2D
/// itself, so picking one hands Set Screen Resolution the resolution
/// without a parallel array.
const String settingsMenuClass = 'WBP_SettingsMenu';

/// The widget class: a Combo Box `Resolution` (one designer option, `Native`
/// standing for 0 × 0) and a Text `Status`, both `Is Variable`.
const LuminaBlueprintWidgetClass settingsMenuWidgetClass = LuminaBlueprintWidgetClass(name: settingsMenuClass, elements: [
  LuminaBlueprintWidgetElement(name: 'Resolution', fieldName: 'resolution', typeName: 'comboBox', props: {
    'options': [
      {'label': 'Native', 'value': [0.0, 0.0], 'type': 'vector2D'},
    ],
    'selected': 'Native',
  }),
  LuminaBlueprintWidgetElement(name: 'Status', fieldName: 'status', typeName: 'text', props: {'text': ''}),
]);

/// The graph:
/// - Event Construct → Clear Options (Resolution) → For Each (Get Supported
///   Resolutions) → Add Option (Label `{0}×{1}` of the rounded X / Y, Value =
///   the element); Completed → Set Selected Index 0 → Print Get Option Count;
/// - On Selection Changed (Resolution), Value typed Vector 2D → Set Screen
///   Resolution (rounded X, Y) → Set Text (Status, Selected Item) → Print
///   `ITEM #INDEX SELECT_TYPE @INDEX_BY_VALUE` followed by Get Selected
///   Option's label.
LuminaWidgetBlueprintDocument settingsMenuBlueprint() {
  final widget = LuminaWidgetBlueprintDocument(widgetClass: settingsMenuClass, variables: settingsMenuWidgetClass.elements);
  final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [settingsMenuWidgetClass]);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  const vector2D = {'type': 'vector2D'};
  final g = widget.blueprint.eventGraph;
  g.nodes.addAll([
    p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'res', {'element': 'Resolution'}),
    p('clear_element_options', 'clear'),
    p('get_supported_resolutions', 'supported'),
    p('for_each_loop', 'loop', vector2D),
    p('break_vector2d', 'size'),
    p('round', 'width'),
    p('round', 'height'),
    p('int_to_string', 'width_text'),
    p('int_to_string', 'height_text'),
    p('format_string', 'label', {'format': '{0}×{1}'}),
    p('add_element_option', 'add', vector2D),
    p('set_element_selected_index', 'pick', {'index': 0}),
    p('get_element_option_count', 'count'),
    p('int_to_string', 'count_text'),
    p('print_string', 'say_count', {'print_to_screen': false}),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'changed', {'element': 'Resolution', 'event': 'OnSelectionChanged', ...vector2D}),
    p('break_vector2d', 'chosen'),
    p('round', 'chosen_width'),
    p('round', 'chosen_height'),
    p('set_screen_resolution', 'apply'),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'status', {'element': 'Status'}),
    p('set_element_text', 'show'),
    p('int_to_string', 'index_text'),
    p('enum_to_string', 'how'),
    p('find_element_option_index_by_value', 'found', vector2D),
    p('int_to_string', 'found_text'),
    p('get_element_selected_option', 'current', vector2D),
    p('format_string', 'summary', {'format': '{0} #{1} {2} @{3}'}),
    p('append', 'summary_label'),
    p('print_string', 'say_change', {'print_to_screen': false}),
  ]);
  g.wires.addAll([
    w('construct', 'exec_out', 'clear', 'exec_in'),
    w('res', 'return_value', 'clear', 'target'),
    w('clear', 'exec_out', 'loop', 'exec_in'),
    w('supported', 'return_value', 'loop', 'array'),
    w('loop', 'loop_body', 'add', 'exec_in'),
    w('res', 'return_value', 'add', 'target'),
    w('loop', 'array_element', 'size', 'in_vec'),
    w('size', 'x', 'width', 'a'),
    w('size', 'y', 'height', 'a'),
    w('width', 'return_value', 'width_text', 'in_int'),
    w('height', 'return_value', 'height_text', 'in_int'),
    w('width_text', 'return_value', 'label', 'arg_0'),
    w('height_text', 'return_value', 'label', 'arg_1'),
    w('label', 'return_value', 'add', 'option'),
    w('loop', 'array_element', 'add', 'value'),
    w('loop', 'completed', 'pick', 'exec_in'),
    w('res', 'return_value', 'pick', 'target'),
    w('pick', 'exec_out', 'say_count', 'exec_in'),
    w('res', 'return_value', 'count', 'target'),
    w('count', 'return_value', 'count_text', 'in_int'),
    w('count_text', 'return_value', 'say_count', 'in_string'),
    w('changed', 'exec_out', 'apply', 'exec_in'),
    w('changed', 'value', 'chosen', 'in_vec'),
    w('chosen', 'x', 'chosen_width', 'a'),
    w('chosen', 'y', 'chosen_height', 'a'),
    w('chosen_width', 'return_value', 'apply', 'width'),
    w('chosen_height', 'return_value', 'apply', 'height'),
    w('apply', 'exec_out', 'show', 'exec_in'),
    w('status', 'return_value', 'show', 'target'),
    w('changed', 'selected_item', 'show', 'in_text'),
    w('show', 'exec_out', 'say_change', 'exec_in'),
    w('changed', 'index', 'index_text', 'in_int'),
    w('changed', 'select_type', 'how', 'value'),
    w('res', 'return_value', 'found', 'target'),
    w('changed', 'value', 'found', 'value'),
    w('found', 'return_value', 'found_text', 'in_int'),
    w('changed', 'selected_item', 'summary', 'arg_0'),
    w('index_text', 'return_value', 'summary', 'arg_1'),
    w('how', 'return_value', 'summary', 'arg_2'),
    w('found_text', 'return_value', 'summary', 'arg_3'),
    w('res', 'return_value', 'current', 'target'),
    w('summary', 'return_value', 'summary_label', 'a'),
    w('current', 'return_value', 'summary_label', 'b'),
    w('summary_label', 'return_value', 'say_change', 'in_string'),
  ]);
  return widget;
}
