import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintGraph, LuminaBlueprintNode;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';

/// The vertex-variable helpers of the material graph: which variable a Set /
/// Vertex Variable node names, the names `variables` header entries declare,
/// and the entries kept on the Material node.
abstract final class MaterialVertexVariables {
  /// The variable a Set Vertex Variable writes or a Vertex Variable reads.
  static String? variableName(LuminaBlueprintNode node) =>
      node.registryId == MaterialNodes.setVertexVariable || node.registryId == MaterialNodes.vertexVariable ? node.literals['name'] as String? : null;

  /// The name a `variables` header entry declares (`tint`, `"tint"` or
  /// `{ name : tint, precision : medium }` as rendered).
  static String? declaredVariableName(String entry) {
    final t = entry.trim();
    if (t.startsWith('{')) return RegExp(r'\bname\s*:\s*"?([A-Za-z_][A-Za-z0-9_]*)').firstMatch(t)?.group(1);
    final m = RegExp(r'^"?([A-Za-z_][A-Za-z0-9_]*)"?$').firstMatch(t);
    return m?.group(1);
  }

  /// Header `variables` entries no Set Vertex Variable node stands for, kept on
  /// the Material node (`extraVariables`) so they survive a graph edit.
  static List<String> extraVariables(LuminaBlueprintGraph graph) {
    final raw = graph.node(MaterialNodes.outputNodeId)?.literals['extraVariables'];
    if (raw is! List) return const [];
    return [for (final e in raw) if (e is String && e.trim().isNotEmpty) e];
  }
}
