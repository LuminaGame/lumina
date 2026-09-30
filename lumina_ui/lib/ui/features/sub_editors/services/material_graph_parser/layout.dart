part of '../material_graph_parser.dart';

/// Lays a parsed graph out left to right: the Material node on the right,
/// each expression one column left of its left-most consumer.
abstract final class MaterialGraphLayout {
  static const double columnGap = 70;
  static const double rowGap = 24;

  /// The texture thumbnail picker a Texture Sample / TextureParameter node
  /// draws under its header (`MaterialGraphEditor.nodeBody`).
  static const double textureBodyHeight = 52;

  static double _height(LuminaBlueprintNode n) {
    final rows = math.max(MaterialNodes.inputsOf(n).length, MaterialNodes.outputsOf(n).length);
    final body = n.registryId == MaterialNodes.textureSample || n.registryId == MaterialNodes.textureParameter
        ? textureBodyHeight
        : 0.0;
    return 26 + 6 + body + rows * 26 + 8 + 10;
  }

  /// The width the graph canvas gives [n] (its title and pin labels), so a
  /// column is as wide as its widest node.
  static double width(LuminaBlueprintNode n) {
    double text(String s, double c) => s.length * c;
    var inputs = 0.0;
    for (final p in MaterialNodes.inputsOf(n)) {
      inputs = math.max(inputs, 20 + text(p.name, 5.4) + (p.defaultValue != null ? 62 : 0));
    }
    var outputs = 0.0;
    for (final p in MaterialNodes.outputsOf(n)) {
      outputs = math.max(outputs, 20 + text(p.name, 5.4));
    }
    final title = text(MaterialNodes.titleOf(n), 6.6) + 44;
    return math.max(math.max(inputs + outputs + 24, title), 160.0).clamp(160.0, 520.0).toDouble();
  }

  static void arrange(LuminaBlueprintGraph graph) {
    // The Material node and the Set Vertex Variable nodes are the roots, in
    // the right-most column.
    final depth = <String, int>{
      MaterialNodes.outputNodeId: 0,
      for (final n in graph.nodes)
        if (n.registryId == MaterialNodes.setVertexVariable) n.id: 0,
    };
    // Longest path from the output, so a node sits left of every consumer.
    var changed = true;
    var guard = 0;
    while (changed && guard++ < graph.nodes.length + 2) {
      changed = false;
      for (final w in graph.wires) {
        final d = depth[w.toNodeId];
        if (d == null) continue;
        if ((depth[w.fromNodeId] ?? -1) < d + 1) {
          depth[w.fromNodeId] = d + 1;
          changed = true;
        }
      }
    }
    final maxDepth = depth.values.fold<int>(0, math.max);
    final columns = <int, List<LuminaBlueprintNode>>{};
    for (final n in graph.nodes) {
      final d = depth[n.id] ?? (maxDepth + 1);
      (columns[d] ??= []).add(n);
    }
    // Within a column, order by the consumer's position so wires rarely cross.
    final y = <String, double>{};
    for (final d in columns.keys.toList()..sort()) {
      final list = columns[d]!;
      double key(LuminaBlueprintNode n) {
        final consumers = [for (final w in graph.wires) if (w.fromNodeId == n.id && y.containsKey(w.toNodeId)) w];
        if (consumers.isEmpty) return double.maxFinite;
        return consumers.map((w) {
          final pins = MaterialNodes.inputsOf(graph.node(w.toNodeId)!);
          final idx = pins.indexWhere((p) => p.id == w.toPinId);
          return y[w.toNodeId]! + math.max(0, idx) * 26;
        }).reduce(math.min);
      }

      // Stable: nodes with the same key keep graph order (the Material node
      // above the Set Vertex Variable nodes).
      final order = {for (final (i, n) in graph.nodes.indexed) n.id: i};
      list.sort((a, b) {
        final byKey = key(a).compareTo(key(b));
        if (byKey != 0) return byKey;
        if (a.id == MaterialNodes.outputNodeId) return -1;
        if (b.id == MaterialNodes.outputNodeId) return 1;
        return order[a.id]!.compareTo(order[b.id]!);
      });
      var cursor = 40.0;
      for (final n in list) {
        final wanted = key(n) == double.maxFinite ? cursor : math.max(cursor, key(n) - 40);
        y[n.id] = wanted;
        cursor = wanted + _height(n) + rowGap;
      }
    }
    // Columns right to left, each as wide as its widest node.
    final right = <int, double>{};
    var edge = 0.0;
    for (final d in columns.keys.toList()..sort()) {
      final widest = columns[d]!.map(width).fold<double>(0, math.max);
      right[d] = edge;
      edge -= widest + columnGap;
    }
    final minX = graph.nodes.map((n) => right[depth[n.id] ?? (maxDepth + 1)]! - width(n)).fold<double>(0, math.min);
    for (final n in graph.nodes) {
      final d = depth[n.id] ?? (maxDepth + 1);
      final columnWidth = columns[d]!.map(width).fold<double>(0, math.max);
      // Left-aligned in its column.
      n.x = 40 + right[d]! - columnWidth - minX;
      n.y = y[n.id] ?? 40;
    }
  }

  /// Gives nodes of [next] the places their counterparts had in [previous]
  /// (matched by kind and settings), so a re-parse keeps the author's layout.
  static void keepPositions(LuminaBlueprintGraph next, LuminaBlueprintGraph previous) {
    String signature(LuminaBlueprintNode n) {
      final l = n.literals;
      final key = switch (n.registryId) {
        MaterialNodes.constant || MaterialNodes.constant2 || MaterialNodes.constant3 || MaterialNodes.constant4 =>
          '${l['value']}|${l['varName'] ?? ''}',
        MaterialNodes.scalarParameter || MaterialNodes.vectorParameter || MaterialNodes.textureParameter => '${l['name']}',
        MaterialNodes.textureSample => '${l['parameter']}',
        MaterialNodes.textureCoordinate => '${l['index']}',
        MaterialNodes.custom || MaterialNodes.customFragment => '${l['code']}',
        MaterialNodes.setVertexVariable || MaterialNodes.vertexVariable => '${l['name']}',
        MaterialNodes.worldPosition => '${l['space']}',
        _ => '',
      };
      return '${n.registryId}|$key';
    }

    final pool = <String, List<LuminaBlueprintNode>>{};
    for (final n in previous.nodes) {
      (pool[signature(n)] ??= []).add(n);
    }
    for (final n in next.nodes) {
      final candidates = pool[signature(n)];
      if (candidates == null || candidates.isEmpty) continue;
      final match = candidates.removeAt(0);
      n.x = match.x;
      n.y = match.y;
    }
  }
}
