import 'package:flutter/widgets.dart' show Offset;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';

/// WBP_Clicker: a Button `StartButton` and a Text `Title` (both Is
/// Variable); its graph: Event Construct → Set Visibility (Title, Visible),
/// On Clicked (StartButton) → Set Text (Title) "Clicked!".
UmgDocument clickerDocument() {
  final doc = UmgDocument.createDefault();
  final button = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.button, name: 'StartButton', id: 'n_button'), canvasPosition: const Offset(40, 40))!;
  button.props['label'] = 'Start';
  final title = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'Title', id: 'n_title'), canvasPosition: const Offset(40, 120))!;
  title.props['text'] = 'Waiting';
  button.events.add(const UmgEvent(name: 'OnClicked', handler: 'onClickedStartButton'));
  final graph = LuminaWidgetBlueprintDocument.emptyGraph();
  final context = LuminaBlueprintTypeContext.forWidget(
      LuminaWidgetBlueprintDocument(widgetClass: 'WBP_Clicker', variables: UmgWidgetCodegen.variablesOf(doc), blueprint: graph));
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  LuminaBlueprintWire w(String id, String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  graph.eventGraph.nodes.addAll([
    p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
    p('set_element_visibility', 'show', {'in_visibility': 'Visible'}),
    p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'title', {'element': 'Title'}),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'clicked', {'element': 'StartButton', 'event': 'OnClicked'}),
    p('set_element_text', 'set_text', {'in_text': 'Clicked!'}),
  ]);
  graph.eventGraph.wires.addAll([
    w('w0', 'construct', 'exec_out', 'show', 'exec_in'),
    w('w1', 'title', 'return_value', 'show', 'target'),
    w('w2', 'clicked', 'exec_out', 'set_text', 'exec_in'),
    w('w3', 'title', 'return_value', 'set_text', 'target'),
  ]);
  doc.blueprint = graph;
  return doc;
}

/// WBP_AgentForm — WBP_Clicker plus an Editable Text
/// `NameField`. On Clicked (StartButton) also prints "StartButton clicked"
/// (Print String, to the log); On Text Committed (NameField) sets Title to
/// "Committed!".
UmgDocument agentFormDocument() {
  final doc = clickerDocument();
  final field = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.editableText, name: 'NameField', id: 'n_field'),
      canvasPosition: const Offset(40, 200))!;
  field.props['hint'] = 'Your name';
  field.events.add(const UmgEvent(name: 'OnTextCommitted', handler: 'onTextCommittedNameField'));
  final graph = doc.blueprint!;
  final context = LuminaBlueprintTypeContext.forWidget(
      LuminaWidgetBlueprintDocument(widgetClass: 'WBP_AgentForm', variables: UmgWidgetCodegen.variablesOf(doc), blueprint: graph));
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  LuminaBlueprintWire w(String id, String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  graph.eventGraph.nodes.addAll([
    p('print_string', 'print_click', {'in_string': 'StartButton clicked', 'print_to_screen': false}),
    p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'committed', {'element': 'NameField', 'event': 'OnTextCommitted'}),
    p('set_element_text', 'set_committed', {'in_text': 'Committed!'}),
  ]);
  graph.eventGraph.wires.addAll([
    w('w4', 'set_text', 'exec_out', 'print_click', 'exec_in'),
    w('w5', 'committed', 'exec_out', 'set_committed', 'exec_in'),
    w('w6', 'title', 'return_value', 'set_committed', 'target'),
  ]);
  return doc;
}
