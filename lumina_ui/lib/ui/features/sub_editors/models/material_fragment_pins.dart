import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaBlueprintGraph, LuminaBlueprintNode, LuminaBlueprintWire;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';

/// The pins and wires of a Custom (Fragment) node, read from its verbatim
/// code: the header parameters it reads (`materialParams.x` /
/// `materialParams_x`) become inputs wired from their parameter nodes, and
/// the `MaterialInputs` fields it assigns (`material.normal = …`) become
/// outputs wired into the Material node. The code stays the source of truth:
/// the wires show its flow and are rebuilt whenever the code changes.
abstract final class MaterialFragmentPins {
  static final RegExp _paramRef = RegExp(r'\bmaterialParams[._]([A-Za-z_][A-Za-z0-9_]*)');
  static final RegExp _fieldWrite = RegExp(r'\bmaterial\.([A-Za-z_][A-Za-z0-9_]*)(?:\.[xyzwrgba]+)?\s*(?:[-+*/]?=)(?!=)');

  /// The parameters [node]'s code reads, in first-use order.
  static List<String> parameters(LuminaBlueprintNode node) {
    final code = '${node.literals['code'] ?? ''}';
    final seen = <String>{};
    return [for (final m in _paramRef.allMatches(code)) if (seen.add(m.group(1)!)) m.group(1)!];
  }

  /// The Material node pins whose fields [node]'s code assigns, in the
  /// Material node's pin order.
  static List<String> outputs(LuminaBlueprintNode node) {
    final code = '${node.literals['code'] ?? ''}';
    final written = {for (final m in _fieldWrite.allMatches(code)) m.group(1)!};
    return [
      for (final e in MaterialNodes.outputFields.entries)
        if (written.contains(e.value)) e.key,
    ];
  }

  static List<MaterialPinDef> inputPins(LuminaBlueprintNode node) =>
      [for (final name in parameters(node)) MaterialPinDef(name, name)];

  static List<MaterialPinDef> outputPins(LuminaBlueprintNode node) {
    final labels = {for (final p in MaterialNodes.spec(MaterialNodes.output)!.inputs) p.id: p};
    return [
      for (final id in outputs(node))
        if (labels[id] case final p?) MaterialPinDef(id, p.name, type: p.type),
    ];
  }

  /// Replaces every wire touching a Custom (Fragment) node in [graph] with
  /// the ones its code implies.
  static void syncWires(LuminaBlueprintGraph graph) {
    final fragments = graph.nodes.where((n) => n.registryId == MaterialNodes.customFragment).toList();
    if (fragments.isEmpty) return;
    final ids = {for (final f in fragments) f.id};
    graph.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
    final output = graph.node(MaterialNodes.outputNodeId);
    for (final fragment in fragments) {
      for (final name in parameters(fragment)) {
        final param = graph.nodes
            .where((n) => MaterialNodes.isParameter(n.registryId) && n.literals['name'] == name)
            .firstOrNull;
        if (param == null) continue;
        final from = MaterialNodes.outputsOf(param).firstOrNull;
        if (from == null) continue;
        graph.wires.add(LuminaBlueprintWire(
          id: '${fragment.id}_in_$name',
          fromNodeId: param.id,
          fromPinId: from.id,
          toNodeId: fragment.id,
          toPinId: name,
        ));
      }
      if (output == null) continue;
      for (final pin in outputs(fragment)) {
        graph.wires.add(LuminaBlueprintWire(
          id: '${fragment.id}_out_$pin',
          fromNodeId: fragment.id,
          fromPinId: pin,
          toNodeId: output.id,
          toPinId: pin,
        ));
      }
    }
  }
}
