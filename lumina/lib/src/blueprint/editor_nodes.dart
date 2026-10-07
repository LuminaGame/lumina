import 'dart:convert';

import 'package:lumina/src/blueprint/blueprint_model.dart';

/// Graph nodes that only the editor draws:
/// comment boxes and reroute dots. The node library has neither. They are
/// stored in the graph like any other node, so they save into the `.lmas`,
/// and [forEngine] strips them before a document reaches the validator, the
/// VM or the Dart generator. A comment is dropped. A reroute is bypassed by
/// wiring its source straight into what it fed.
///
/// They live in the engine package because engine code emits them too:
/// generated template graphs carry comment boxes, and the
/// VM ([LuminaBlueprintClass.fromDocument]) and the generator strip them from
/// any document they receive.
abstract final class LuminaBlueprintEditorNodes {
  /// A comment box: literals `title`, `width`, `height`, `color` (ARGB int).
  /// Its position is the box's top-left; it has no pins.
  static const String comment = 'comment';

  /// A reroute dot: one input `in` and one output `out`, both typed as the
  /// wire it was inserted into (stored on the node's pins).
  static const String reroute = 'reroute';

  static const String rerouteIn = 'in';
  static const String rerouteOut = 'out';

  static const double defaultCommentWidth = 320;
  static const double defaultCommentHeight = 200;
  static const int defaultCommentColor = 0xFF3D4A5C;

  static bool isEditorOnly(String registryId) => registryId == comment || registryId == reroute;

  static bool isComment(LuminaBlueprintNode node) => node.registryId == comment;
  static bool isReroute(LuminaBlueprintNode node) => node.registryId == reroute;

  static double commentWidth(LuminaBlueprintNode node) => (node.literals['width'] as num?)?.toDouble() ?? defaultCommentWidth;
  static double commentHeight(LuminaBlueprintNode node) => (node.literals['height'] as num?)?.toDouble() ?? defaultCommentHeight;
  static int commentColor(LuminaBlueprintNode node) => (node.literals['color'] as num?)?.toInt() ?? defaultCommentColor;

  /// A new comment box at ([x], [y]) of [width] × [height].
  static LuminaBlueprintNode newComment({
    required String id,
    required double x,
    required double y,
    double width = defaultCommentWidth,
    double height = defaultCommentHeight,
    String title = 'Comment',
    int color = defaultCommentColor,
  }) =>
      LuminaBlueprintNode(
        id: id,
        registryId: comment,
        title: title,
        category: 'Comments',
        x: x,
        y: y,
        headerColor: color,
        literals: {'title': title, 'width': width, 'height': height, 'color': color},
      );

  /// [graph] without editor-only nodes: comments dropped, every reroute
  /// chain replaced by direct wires from its source to each final target.
  /// The wire into the last reroute of a chain keeps the id of the first
  /// bypassed wire when there is exactly one target, so the debugger's exec
  /// glow still finds it. Returns [graph] itself when it has none.
  static LuminaBlueprintGraph flattenGraph(LuminaBlueprintGraph graph) {
    if (!graph.nodes.any((n) => isEditorOnly(n.registryId))) return graph;
    final reroutes = {for (final n in graph.nodes) if (isReroute(n)) n.id};
    final comments = {for (final n in graph.nodes) if (isComment(n)) n.id};
    final wires = <LuminaBlueprintWire>[];
    // The source feeding a reroute: walked back through chained reroutes.
    ({String nodeId, String pinId, String wireId})? sourceOf(String rerouteId, Set<String> seen) {
      if (!seen.add(rerouteId)) return null;
      final into = graph.wireInto(rerouteId, rerouteIn);
      if (into == null) return null;
      if (reroutes.contains(into.fromNodeId)) return sourceOf(into.fromNodeId, seen);
      return (nodeId: into.fromNodeId, pinId: into.fromPinId, wireId: into.id);
    }

    for (final w in graph.wires) {
      if (comments.contains(w.fromNodeId) || comments.contains(w.toNodeId)) continue;
      if (reroutes.contains(w.toNodeId)) continue; // resolved from the far end
      if (!reroutes.contains(w.fromNodeId)) {
        wires.add(w);
        continue;
      }
      final source = sourceOf(w.fromNodeId, {});
      if (source == null) continue; // a dangling reroute feeds nothing
      final id = wires.any((x) => x.id == source.wireId) ? w.id : source.wireId;
      wires.add(LuminaBlueprintWire(
        id: id,
        fromNodeId: source.nodeId,
        fromPinId: source.pinId,
        toNodeId: w.toNodeId,
        toPinId: w.toPinId,
      ));
    }
    return LuminaBlueprintGraph(
      nodes: [for (final n in graph.nodes) if (!isEditorOnly(n.registryId)) n],
      wires: wires,
    );
  }

  /// Whether any graph of [document] holds an editor-only node.
  static bool hasEditorNodes(LuminaBlueprintDocument document) {
    bool any(LuminaBlueprintGraph g) => g.nodes.any((n) => isEditorOnly(n.registryId));
    return any(document.eventGraph) || document.functions.any((f) => any(f.graph)) || document.macros.any((m) => any(m.graph));
  }

  /// A deep copy of [document] with every graph flattened: what the
  /// validator, the VM (Play) and the Dart generator receive. [document]
  /// itself when it has no editor-only node.
  static LuminaBlueprintDocument forEngine(LuminaBlueprintDocument document) {
    if (!hasEditorNodes(document)) return document;
    final copy = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(document.toJson())) as Map));
    void replace(LuminaBlueprintGraph target) {
      final flat = flattenGraph(target);
      if (identical(flat, target)) return;
      target.nodes
        ..clear()
        ..addAll(flat.nodes);
      target.wires
        ..clear()
        ..addAll(flat.wires);
    }

    replace(copy.eventGraph);
    for (final f in copy.functions) {
      replace(f.graph);
    }
    for (final m in copy.macros) {
      replace(m.graph);
    }
    return copy;
  }
}
