import 'package:lumina/lumina.dart';

/// `WBP_Clicker`, a widget whose own graph scripts it, as Lumina
/// Studio writes it — a Text `Title`, a Button `StartButton`, a Progress Bar
/// `Charge`, a Slider `Volume` and an Editable Text `NameField`, all `Is
/// Variable` except the Border `Frame`.
const String clickerClass = 'WBP_Clicker';

/// The widget class as the registry knows it (every named element).
const LuminaBlueprintWidgetClass clickerWidgetClass = LuminaBlueprintWidgetClass(name: clickerClass, elements: [
  LuminaBlueprintWidgetElement(name: 'Frame', fieldName: 'frame', typeName: 'border', props: {'color': '#1B1B22'}),
  LuminaBlueprintWidgetElement(name: 'Title', fieldName: 'title', typeName: 'text', props: {'text': 'Text Block', 'color': '#FFFFFF'}),
  LuminaBlueprintWidgetElement(name: 'StartButton', fieldName: 'startButton', typeName: 'button', props: {'label': 'Start'}),
  LuminaBlueprintWidgetElement(name: 'Charge', fieldName: 'charge', typeName: 'progressBar', props: {'percent': 0.0}),
  LuminaBlueprintWidgetElement(name: 'Volume', fieldName: 'volume', typeName: 'slider', props: {'value': 0.5}),
  LuminaBlueprintWidgetElement(name: 'NameField', fieldName: 'nameField', typeName: 'editableText', props: {'text': ''}),
]);

/// The `Is Variable` elements (everything but `Frame`).
List<LuminaBlueprintWidgetElement> clickerVariables() => [for (final e in clickerWidgetClass.elements) if (e.name != 'Frame') e];

/// The graph:
/// - Event Pre Construct → Set Text (Title) "Pre";
/// - Event Construct → Set Visibility (Title, Visible) → Set Text (Title) "Ready";
/// - On Clicked (StartButton) → Clicks = Clicks + 1 → Set Text (Title) "Clicked!" → Print "clicked";
/// - Event Tick → Set Percent (Charge, In Delta Time × 6);
/// - On Value Changed (Volume) → Set Percent (Charge, Value);
/// - On Text Committed (NameField) → Set Text (Title, Text) → Remove from Parent (no Target: Self);
/// - Event Destruct → Print "bye".
LuminaWidgetBlueprintDocument clickerBlueprint() {
  final widget = LuminaWidgetBlueprintDocument(
    widgetClass: clickerClass,
    variables: clickerVariables(),
    blueprint: LuminaBlueprintDocument(variables: [const LuminaBlueprintVariable(name: 'Clicks', typeName: 'Int', defaultValue: 0)]),
  );
  final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [clickerWidgetClass]);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  LuminaBlueprintWire w(String id, String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  final g = widget.blueprint.eventGraph;
  g.nodes.addAll([
    p(LuminaBlueprintNodeLibrary.eventWidgetPreConstruct, 'pre'),
    p('set_element_text', 'pre_text', {'in_text': 'Pre'}),
    p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
    p('set_element_visibility', 'show_title', {'in_visibility': 'Visible'}),
    p('set_element_text', 'ready_text', {'in_text': 'Ready'}),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'title', {'element': 'Title'}),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'clicked', {'element': 'StartButton', 'event': 'OnClicked'}),
    p('variable_get', 'clicks_get', {'variable': 'Clicks'}),
    p('int_add', 'clicks_add', {'b': 1}),
    p('variable_set', 'clicks_set', {'variable': 'Clicks'}),
    p('set_element_text', 'clicked_text', {'in_text': 'Clicked!'}),
    p('print_string', 'clicked_print', {'in_string': 'clicked', 'print_to_screen': false}),
    p(LuminaBlueprintNodeLibrary.eventWidgetTick, 'tick'),
    p('float_multiply', 'charge_rate', {'b': 6.0}),
    p('set_element_percent', 'charge_tick'),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'charge', {'element': 'Charge'}),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'volume_changed', {'element': 'Volume', 'event': 'OnValueChanged'}),
    p('set_element_percent', 'charge_volume'),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'name_committed', {'element': 'NameField', 'event': 'OnTextCommitted'}),
    p('set_element_text', 'name_text'),
    p('remove_from_parent', 'close'),
    p(LuminaBlueprintNodeLibrary.eventWidgetDestruct, 'destruct'),
    p('print_string', 'bye', {'in_string': 'bye', 'print_to_screen': false}),
  ]);
  g.wires.addAll([
    w('w0', 'pre', 'exec_out', 'pre_text', 'exec_in'),
    w('w1', 'title', 'return_value', 'pre_text', 'target'),
    w('w2', 'construct', 'exec_out', 'show_title', 'exec_in'),
    w('w3', 'show_title', 'exec_out', 'ready_text', 'exec_in'),
    w('w4', 'title', 'return_value', 'show_title', 'target'),
    w('w5', 'title', 'return_value', 'ready_text', 'target'),
    w('w6', 'clicked', 'exec_out', 'clicks_set', 'exec_in'),
    w('w7', 'clicks_get', 'value', 'clicks_add', 'a'),
    w('w8', 'clicks_add', 'return_value', 'clicks_set', 'value'),
    w('w9', 'clicks_set', 'exec_out', 'clicked_text', 'exec_in'),
    w('w10', 'title', 'return_value', 'clicked_text', 'target'),
    w('w11', 'clicked_text', 'exec_out', 'clicked_print', 'exec_in'),
    w('w12', 'tick', 'exec_out', 'charge_tick', 'exec_in'),
    w('w13', 'tick', 'in_delta_time', 'charge_rate', 'a'),
    w('w14', 'charge_rate', 'return_value', 'charge_tick', 'in_percent'),
    w('w15', 'charge', 'return_value', 'charge_tick', 'target'),
    w('w16', 'volume_changed', 'exec_out', 'charge_volume', 'exec_in'),
    w('w17', 'volume_changed', 'value', 'charge_volume', 'in_percent'),
    w('w18', 'charge', 'return_value', 'charge_volume', 'target'),
    w('w19', 'name_committed', 'exec_out', 'name_text', 'exec_in'),
    w('w20', 'name_committed', 'text', 'name_text', 'in_text'),
    w('w21', 'title', 'return_value', 'name_text', 'target'),
    w('w22', 'name_text', 'exec_out', 'close', 'exec_in'),
    w('w23', 'destruct', 'exec_out', 'bye', 'exec_in'),
  ]);
  return widget;
}
