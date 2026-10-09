part of '../umg_widget_codegen.dart';

/// The widget's own Blueprint graph in its generated file —
/// the embedded script class (lumina's `generateWidgetScript`), the
/// element events it binds, and the call each handler makes into it.

/// The `Is Variable` elements of [doc] as lumina types them.
List<LuminaBlueprintWidgetElement> _variablesOf(UmgDocument doc) => [
      for (final n in doc.variableNodes)
        LuminaBlueprintWidgetElement(
          name: n.name,
          fieldName: n.fieldName,
          typeName: n.type.name,
          props: Map<String, dynamic>.fromEntries(n.props.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
        ),
    ];

/// The widget's graph as lumina compiles and runs it: comment boxes and
/// reroutes flattened, its variables attached; null without a graph.
LuminaWidgetBlueprintDocument? _widgetGraphOf(UmgDocument doc, String assetName) {
  final graph = doc.blueprint;
  if (graph == null) return null;
  final widget = LuminaWidgetBlueprintDocument(
    widgetClass: UmgWidgetCodegen.fileBaseName(assetName),
    variables: _variablesOf(doc),
    blueprint: BlueprintEditorNodes.forEngine(graph),
  );
  return widget.isEmpty ? null : widget;
}

/// The script class [assetName]'s graph compiles into (`WbpClickerGraph`).
String _graphClassNameFor(String assetName) => '${UmgNaming.toClassName(UmgWidgetCodegen.fileBaseName(assetName))}Graph';

/// The generated script of [doc]'s graph, or null when it has none — or
/// when it has errors (named in [warnings]): the widget then compiles
/// without its graph, exactly as before one existed.
BlueprintGenerationResult? _graphScriptFor(UmgDocument doc, String assetName, {List<String>? warnings}) {
  final widget = _widgetGraphOf(doc, assetName);
  if (widget == null) return null;
  final result = const BlueprintDartGenerator().generateWidgetScript(widget, className: _graphClassNameFor(assetName));
  if (!result.ok) {
    warnings?.add('The graph of ${widget.widgetClass} has errors and was left out: '
        '${result.errors.map((d) => d.message).join('; ')}');
    return null;
  }
  return result;
}

/// [doc] with every element event the graph binds recorded on its element
/// (`On Clicked (StartButton)` → `OnClicked` on StartButton), so the widget
/// wires a handler for it; a copy when anything was added.
UmgDocument _withGraphEvents(UmgDocument doc) {
  final graph = doc.blueprint;
  if (graph == null) return doc;
  final bound = <String, Set<String>>{};
  for (final n in graph.eventGraph.nodes) {
    if (n.registryId != LuminaBlueprintNodeLibrary.eventWidgetElement) continue;
    final element = n.literals['element'];
    final event = n.literals['event'];
    if (element is String && event is String) (bound[element] ??= {}).add(event);
  }
  if (bound.isEmpty) return doc;
  final copy = doc.deepCopy();
  copy.blueprint = graph;
  for (final node in copy.allNodes) {
    for (final event in bound[node.name] ?? const <String>{}) {
      if (!node.type.availableEvents.contains(event) || node.events.any((e) => e.name == event)) continue;
      node.events.add(UmgEvent(name: event, handler: _handlerNameFor(node, event)));
    }
  }
  return copy;
}

/// The handler method an element event gets (`OnClicked` on `startButton` →
/// `onClickedStartButton`), as the designer's `[+]` records it.
String _handlerNameFor(UmgNode node, String eventName) {
  final suffix = node.fieldName.isEmpty ? '' : node.fieldName[0].toUpperCase() + node.fieldName.substring(1);
  return '${eventName[0].toLowerCase()}${eventName.substring(1)}$suffix';
}

/// The line a handler starts with: the element event, fired into the
/// instance's graph script with the event's outputs.
String _fireCall(UmgNode node, UmgEvent event, String inst) {
  final args = switch (event.name) {
    'OnValueChanged' => ", {'value': value}",
    'OnTextCommitted' => ", {'text': value, 'commit_method': 'OnEnter'}",
    'OnSelectionChanged' => ', selection.eventArgs',
    _ => '',
  };
  return 'LuminaUserWidgets.fire($inst, ${_str(node.name)}, ${_str(event.name)}$args);';
}
