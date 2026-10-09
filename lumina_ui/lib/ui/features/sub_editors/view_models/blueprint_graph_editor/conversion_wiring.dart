part of '../blueprint_graph_editor.dart';

/// Wiring two pins of different types through the conversion node lumina
/// names for them ([LuminaBlueprintNodeLibrary.conversionNodeFor]): an
/// integer output dropped on a float input gets To Float (Integer) between
/// them. The model stays strict; only a canvas drop ([BlueprintGraphEditor.connectPins])
/// converts, [BlueprintGraphEditor.addWire] never does.
extension BlueprintGraphConversions on BlueprintGraphEditor {
  /// The conversion a wire from output [fromNodeId].[fromPinId] into input
  /// [toNodeId].[toPinId] goes through; null when the pins connect directly,
  /// or when they cannot be joined at all (exec, delegate, object, a type
  /// pair without a conversion, a node this graph does not accept).
  LuminaBlueprintConversion? conversionFor(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    if (fromNodeId == toNodeId) return null;
    final from = pin(fromNodeId, fromPinId, output: true);
    final to = pin(toNodeId, toPinId, output: false);
    if (from == null || to == null || from.type == to.type) return null;
    if (whyNotConnect(fromNodeId, fromPinId, toNodeId, toPinId) == null) return null;
    final conversion = LuminaBlueprintNodeLibrary.conversionNodeFor(from.type, to.type);
    if (conversion == null || !accepts(conversion.nodeId)) return null;
    return conversion;
  }

  /// What the drag tooltip says over a pin [conversion] joins:
  /// `Converts integer → float. To Float (Integer): …`.
  String conversionHint(LuminaBlueprintConversion conversion, LuminaPinType from, LuminaPinType to) =>
      'Converts ${from.name} → ${to.name}. ${conversion.hint}';

  /// Places the conversion node half-way between the two nodes and wires
  /// output → node → input, as one undo step (`Insert <title>`). Null when
  /// [conversionFor] has none.
  LuminaBlueprintNode? insertConversion(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    final conversion = conversionFor(fromNodeId, fromPinId, toNodeId, toPinId);
    final a = node(fromNodeId);
    final b = node(toNodeId);
    if (conversion == null || a == null || b == null) return null;
    final title = LuminaBlueprintNodeLibrary.spec(conversion.nodeId)!.title;
    return host.mutate('Insert $title', () {
      final n = _place(conversion.nodeId, Offset((a.x + b.x) / 2, (a.y + b.y) / 2), null);
      graph.nodes.add(n);
      _connect(fromNodeId, fromPinId, n.id, conversion.inputPin);
      _connect(n.id, conversion.outputPin, toNodeId, toPinId);
      return n;
    });
  }

  /// [BlueprintGraphEditor.connectPins]' fallback: the wire from the inserted
  /// conversion node into [inp], or null.
  LuminaBlueprintWire? _connectThroughConversion(BlueprintPinRef out, BlueprintPinRef inp) {
    final inserted = insertConversion(out.nodeId, out.pinId, inp.nodeId, inp.pinId);
    if (inserted == null) return null;
    return graph.wires.lastWhere((w) => w.fromNodeId == inserted.id && w.toNodeId == inp.nodeId && w.toPinId == inp.pinId);
  }
}
