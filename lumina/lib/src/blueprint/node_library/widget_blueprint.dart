part of '../node_library.dart';

// --- Widget Blueprint graphs ----------------------------------------

/// The widget's own events, its `Is Variable` elements and Self: the nodes
/// only a Widget Blueprint graph holds.
final List<LuminaBlueprintNodeSpec> _widgetBlueprintNodes = [
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.eventWidgetConstruct,
    title: 'Event Construct',
    category: 'User Interface|Widget Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['widget', 'construct', 'created', 'shown', 'added', 'viewport', 'init', 'start'],
    outputs: [_execOut],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.eventWidgetPreConstruct,
    title: 'Event Pre Construct',
    category: 'User Interface|Widget Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['widget', 'pre construct', 'design time', 'init'],
    outputs: [_execOut, LuminaBlueprintPinSpec('is_design_time', 'Is Design Time', LuminaPinType.boolean, defaultValue: false)],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.eventWidgetDestruct,
    title: 'Event Destruct',
    category: 'User Interface|Widget Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['widget', 'destruct', 'removed', 'hidden', 'close', 'end'],
    outputs: [_execOut],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.eventWidgetTick,
    title: 'Event Tick',
    category: 'User Interface|Widget Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['widget', 'tick', 'update', 'frame', 'every frame', 'delta'],
    outputs: [_execOut, LuminaBlueprintPinSpec('in_delta_time', 'In Delta Time', LuminaPinType.float, defaultValue: 0.0)],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.eventWidgetElement,
    title: 'On Widget Event',
    category: 'User Interface|Widget Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['widget', 'button', 'clicked', 'pressed', 'hovered', 'value changed', 'text committed', 'bind', 'event'],
    outputs: [_execOut],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.getWidgetVariable,
    title: 'Get Widget',
    category: 'Widget Variables',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _variable,
    keywords: ['widget', 'variable', 'element', 'get', 'is variable'],
    outputs: [LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.object, objectClass: LuminaBlueprintObjectClass.widgetElementKind)],
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaBlueprintNodeLibrary.getWidgetSelf,
    title: 'Self',
    category: 'User Interface',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _variable,
    keywords: ['self', 'this', 'widget', 'reference', 'get a reference to self'],
    outputs: [LuminaBlueprintPinSpec(_returnValue, 'Self', LuminaPinType.object, objectClass: LuminaBlueprintObjectClass.widgetKind)],
  ),
];

/// The extra outputs of a bound element [event] of an element typed
/// [typeName] (`On Value Changed (Volume)` → `Value` float).
List<LuminaBlueprintPinSpec> _widgetEventOutputs(String? event, String? typeName, LuminaBlueprintNode node) => switch (event) {
      LuminaWidgetEvents.onValueChanged => [
          LuminaBlueprintPinSpec('value', 'Value', LuminaPinType.parse(LuminaWidgetEvents.valueTypeOf(typeName ?? '')) ?? LuminaPinType.string),
        ],
      LuminaWidgetEvents.onTextCommitted => [
          _s('text', 'Text'),
          _enum('commit_method', 'Commit Method', LuminaBlueprintNodeLibrary.textCommitEnum),
        ],
      LuminaWidgetEvents.onSelectionChanged => _selectionChangedOutputs(node),
      _ => const [],
    };

/// The pins of a widget-graph node in [context].
({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs}) _widgetPinsOf(
    LuminaBlueprintNodeSpec s, LuminaBlueprintNode node, LuminaBlueprintTypeContext context) {
  String? lit(String key) => node.literals[key] is String && (node.literals[key] as String).isNotEmpty ? node.literals[key] as String : null;
  switch (s.id) {
    case LuminaBlueprintNodeLibrary.eventWidgetElement:
      final element = context.widgetVariable(lit('element'));
      return (inputs: s.inputs, outputs: [...s.outputs, ..._widgetEventOutputs(lit('event'), element?.typeName, node)]);
    case LuminaBlueprintNodeLibrary.getWidgetVariable:
      final element = context.widgetVariable(lit('element'));
      if (element == null) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: s.inputs, outputs: [for (final p in s.outputs) p.retyped(p.type, objectClass: element.objectClass)]);
    case LuminaBlueprintNodeLibrary.getWidgetSelf:
      if (!context.isWidgetScope) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: s.inputs, outputs: [for (final p in s.outputs) p.retyped(p.type, objectClass: context.selfClass)]);
  }
  return (inputs: s.inputs, outputs: s.outputs);
}

/// The title a widget-graph node takes from its settings, or null.
String? _widgetTitleOf(String id, Map<String, dynamic>? literals) {
  String? lit(String key) => literals?[key] is String && (literals![key] as String).isNotEmpty ? literals[key] as String : null;
  switch (id) {
    case LuminaBlueprintNodeLibrary.eventWidgetElement:
      final element = lit('element');
      final event = lit('event');
      if (element == null || event == null) return null;
      return '${LuminaWidgetEvents.displayName(event)} ($element)';
    case LuminaBlueprintNodeLibrary.getWidgetVariable:
      return lit('element');
  }
  return null;
}

/// Why [node] cannot stand in a graph of [context] (the Widget Blueprint
/// rules), or null.
String? _widgetScopeError(LuminaBlueprintNode node, LuminaBlueprintNodeSpec spec, LuminaBlueprintTypeContext context) {
  if (!context.isWidgetScope) {
    return LuminaBlueprintNodeLibrary.widgetOnlyNodes.contains(spec.id) ? '${spec.title} can only be placed in a Widget Blueprint.' : null;
  }
  if (!LuminaBlueprintNodeLibrary.availableIn(spec, context)) return '${node.title} cannot be placed in a Widget Blueprint.';
  final element = node.literals['element'];
  switch (spec.id) {
    case LuminaBlueprintNodeLibrary.getWidgetVariable:
    case LuminaBlueprintNodeLibrary.eventWidgetElement:
      if (element is! String || element.isEmpty) return '${node.title} names no widget.';
      final v = context.widgetVariable(element);
      if (v == null) {
        return "${node.title}: this widget has no variable '$element' (was it deleted, renamed or is Is Variable off?).";
      }
      if (spec.id == LuminaBlueprintNodeLibrary.eventWidgetElement) {
        final event = node.literals['event'];
        if (event is! String || !LuminaWidgetEvents.forType(v.typeName).contains(event)) {
          return "${node.title}: '$element' has no event '${event ?? ''}'.";
        }
      }
  }
  return null;
}
