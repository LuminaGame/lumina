import 'dart:convert';

import 'package:lumina_editor_data/lumina_editor.dart';

/// Editor-only graph nodes: comment boxes and reroute
/// dots. lumina's node library has neither (it runs graphs, it does not draw
/// them), so they live in the graph as ordinary stored nodes — they save
/// into the `.lmas` with the rest — and [forEngine] strips them before a
/// document reaches the validator, the VM or the Dart generator: a comment
/// is dropped, a reroute is bypassed by wiring its source straight into
/// what it fed.
abstract final class BlueprintEditorNodes {
  /// A comment box: literals `title`, `width`, `height`, `color` (ARGB int).
  /// Its position is the box's top-left; it has no pins. lumina owns the
  /// editor-only node kinds ([LuminaBlueprintEditorNodes]): its template
  /// graphs carry comment boxes, and its VM and generator strip them.
  static const String comment = LuminaBlueprintEditorNodes.comment;

  /// A reroute dot: one input `in` and one output `out`, both typed as the
  /// wire it was inserted into (stored on the node's pins).
  static const String reroute = LuminaBlueprintEditorNodes.reroute;

  static const String rerouteIn = LuminaBlueprintEditorNodes.rerouteIn;
  static const String rerouteOut = LuminaBlueprintEditorNodes.rerouteOut;

  static const double defaultCommentWidth = LuminaBlueprintEditorNodes.defaultCommentWidth;
  static const double defaultCommentHeight = LuminaBlueprintEditorNodes.defaultCommentHeight;
  static const int defaultCommentColor = LuminaBlueprintEditorNodes.defaultCommentColor;

  static bool isEditorOnly(String registryId) => LuminaBlueprintEditorNodes.isEditorOnly(registryId);

  static bool isComment(LuminaBlueprintNode node) => LuminaBlueprintEditorNodes.isComment(node);
  static bool isReroute(LuminaBlueprintNode node) => LuminaBlueprintEditorNodes.isReroute(node);

  static double commentWidth(LuminaBlueprintNode node) => LuminaBlueprintEditorNodes.commentWidth(node);
  static double commentHeight(LuminaBlueprintNode node) => LuminaBlueprintEditorNodes.commentHeight(node);
  static int commentColor(LuminaBlueprintNode node) => LuminaBlueprintEditorNodes.commentColor(node);

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
      LuminaBlueprintEditorNodes.newComment(id: id, x: x, y: y, width: width, height: height, title: title, color: color);

  /// A new reroute at ([x], [y]) carrying [type] (with its class / element
  /// type / enum, so the wires through it keep type-checking).
  static LuminaBlueprintNode newReroute({
    required String id,
    required double x,
    required double y,
    required LuminaBlueprintPinSpec type,
  }) {
    LuminaBlueprintPin pin(String pinId, bool isOutput) => LuminaBlueprintPin(
          id: pinId,
          name: pinId,
          type: type.type,
          isOutput: isOutput,
          objectClass: type.objectClass,
          elementType: type.elementType,
          enumName: type.enumName,
        );
    return LuminaBlueprintNode(
      id: id,
      registryId: reroute,
      title: 'Reroute',
      category: 'Reroute',
      x: x,
      y: y,
      inputs: [pin(rerouteIn, false)],
      outputs: [pin(rerouteOut, true)],
    );
  }

  /// The pins of a reroute as pin specs (the stored pins carry the type).
  static ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs}) reroutePins(LuminaBlueprintNode node) {
    LuminaBlueprintPinSpec spec(LuminaBlueprintPin p) => LuminaBlueprintPinSpec(
          p.id,
          p.name,
          p.type ?? LuminaPinType.wildcard,
          objectClass: p.objectClass,
          elementType: p.elementType,
          enumName: p.enumName,
        );
    return (inputs: node.inputs.map(spec).toList(), outputs: node.outputs.map(spec).toList());
  }

  /// The nodes a comment box [comment] encloses (their top-left inside the
  /// box), given each node's rect through [rectOf]; comments never contain
  /// comments.
  static List<LuminaBlueprintNode> nodesInside(
    LuminaBlueprintNode comment,
    Iterable<LuminaBlueprintNode> nodes, {
    required ({double width, double height}) Function(LuminaBlueprintNode node) sizeOf,
  }) {
    final left = comment.x;
    final top = comment.y;
    final right = left + commentWidth(comment);
    final bottom = top + commentHeight(comment);
    return [
      for (final n in nodes)
        if (n.id != comment.id && !isComment(n))
          if (n.x >= left && n.y >= top && n.x + sizeOf(n).width <= right && n.y + sizeOf(n).height <= bottom) n,
    ];
  }

  /// [graph] without editor-only nodes: comments dropped, every reroute
  /// chain replaced by direct wires from its source to each final target
  /// ([LuminaBlueprintEditorNodes.flattenGraph]).
  static LuminaBlueprintGraph flattenGraph(LuminaBlueprintGraph graph) => LuminaBlueprintEditorNodes.flattenGraph(graph);

  /// A deep copy of [document] with every graph flattened: what the
  /// validator, the VM (Play) and the Dart generator receive.
  static LuminaBlueprintDocument forEngine(LuminaBlueprintDocument document) {
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

  /// [forEngine] on a document JSON payload (Play loading an `.lmas`).
  static Map<String, dynamic> forEngineJson(Map<String, dynamic> payload) =>
      forEngine(LuminaBlueprintDocument.fromJson(payload)).toJson();

  /// Whether [payload] holds any editor-only node (a quick check before
  /// re-serialising a document Play reads from disk).
  static bool hasEditorNodes(LuminaBlueprintDocument document) => LuminaBlueprintEditorNodes.hasEditorNodes(document);
}
