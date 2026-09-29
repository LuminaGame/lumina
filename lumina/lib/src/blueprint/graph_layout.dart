import 'dart:math' as math;

import 'blueprint_model.dart';
import 'editor_nodes.dart';
import 'node_library.dart';

/// One titled chain of a generated graph: an event and the nodes it runs,
/// in reading order.
class LuminaBlueprintGraphSection {
  /// The comment box title (`Move`, `Look`, `Jump`).
  final String title;

  /// The chain's nodes, left to right.
  final List<LuminaBlueprintNode> nodes;

  const LuminaBlueprintGraphSection(this.title, this.nodes);
}

/// Lays out graphs that engine code generates (the templates' Blueprints)
/// for readability: one titled comment box
/// per event chain, boxes stacked top to bottom at one left x with an even
/// gap, each chain's nodes left to right with an even gap between them.
/// Pure (data-only) nodes sit [pureDrop] below the exec row. Each box is
/// sized to its nodes plus [padding].
///
/// Node sizes come from [estimateSize], which follows the Blueprint editor's
/// node layout (lumina_ui `BlueprintNodeLayout`): header, pin rows, the
/// Enhanced Input settings row, label widths and the inline literal editors
/// of unconnected inputs.
abstract final class LuminaBlueprintGraphLayout {
  /// Horizontal gap between two neighbouring nodes' edges.
  static const double nodeGap = 64;

  /// Vertical gap between two boxes.
  static const double sectionGap = 96;

  /// Inner padding of a box: left, right and below the tallest node.
  static const double padding = 32;

  /// From a box's top to its exec row: the comment's title bar plus a gap.
  static const double titleBand = 56;

  /// How far below the exec row pure nodes sit.
  static const double pureDrop = 48;

  /// Places [sections] and returns the graph's nodes: the comment boxes
  /// first (they draw behind), then every section's nodes, in order. The
  /// first box's top-left is ([left], [top]). [wires] tell which inputs are
  /// connected (a connected input shows no inline literal editor, so its
  /// node is narrower).
  static List<LuminaBlueprintNode> stack(
    List<LuminaBlueprintGraphSection> sections, {
    List<LuminaBlueprintWire> wires = const [],
    double left = 0,
    double top = 0,
  }) {
    final connected = <String, Set<String>>{};
    for (final w in wires) {
      (connected[w.toNodeId] ??= {}).add(w.toPinId);
    }
    final comments = <LuminaBlueprintNode>[];
    final nodes = <LuminaBlueprintNode>[];
    final usedIds = <String>{};
    var y = top;
    for (final section in sections) {
      final rowTop = y + titleBand;
      var x = left + padding;
      var bottom = rowTop;
      for (final node in section.nodes) {
        final size = estimateSize(node, connectedInputs: connected[node.id] ?? const {});
        node
          ..x = x
          ..y = rowTop + (isPure(node) ? pureDrop : 0);
        x += size.width + nodeGap;
        bottom = math.max(bottom, node.y + size.height);
        nodes.add(node);
      }
      final width = math.max(x - nodeGap + padding - left, LuminaBlueprintEditorNodes.defaultCommentWidth);
      final height = bottom + padding - y;
      comments.add(LuminaBlueprintEditorNodes.newComment(
        id: _commentId(section.title, usedIds),
        x: left,
        y: y,
        width: width,
        height: height,
        title: section.title,
      ));
      y += height + sectionGap;
    }
    return [...comments, ...nodes];
  }

  /// A node without exec pins: evaluated where its value is read.
  static bool isPure(LuminaBlueprintNode node) =>
      !node.inputs.any((p) => p.type == LuminaPinType.exec) && !node.outputs.any((p) => p.type == LuminaPinType.exec);

  // The editor's node metrics (lumina_ui BlueprintNodeLayout).
  static const double _headerHeight = 26;
  static const double _settingsHeight = 30;
  static const double _padTop = 6;
  static const double _padBottom = 8;
  static const double _rowHeight = 26;

  /// The size the Blueprint editor draws [node] at, with [connectedInputs]
  /// wired (they hide their inline literal editors).
  static ({double width, double height}) estimateSize(LuminaBlueprintNode node, {Set<String> connectedInputs = const {}}) {
    final hasSettings = node.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction;
    double text(String s, double perChar) => s.length * perChar;
    bool labelled(LuminaBlueprintPin p) => !(p.type == LuminaPinType.exec && (p.name == 'Exec In' || p.name == 'Exec Out'));
    var inputs = 0.0;
    for (final p in node.inputs) {
      final literal = connectedInputs.contains(p.id) ? 0.0 : _inlineLiteralWidth(p.type);
      inputs = math.max(inputs, 20 + text(labelled(p) ? p.name : '', 5.4) + (literal > 0 ? 6 + literal : 0));
    }
    var outputs = 0.0;
    for (final p in node.outputs) {
      outputs = math.max(outputs, 20 + text(labelled(p) ? p.name : '', 5.4));
    }
    final title = text(node.title, 6.6) + 44;
    final width = math.max(math.max(inputs + outputs + 24, title), hasSettings ? 210.0 : 160.0).clamp(160.0, 520.0).toDouble();
    final rows = math.max(node.inputs.length, node.outputs.length);
    final height = _headerHeight + (hasSettings ? _settingsHeight : 0) + _padTop + rows * _rowHeight + _padBottom;
    return (width: width, height: height);
  }

  /// Width of the inline literal editor the Blueprint editor shows on an
  /// unconnected input of [type] (lumina_ui `BlueprintPinLiteralEditor`).
  static double _inlineLiteralWidth(LuminaPinType? type) => switch (type) {
        LuminaPinType.boolean => 26,
        LuminaPinType.integer || LuminaPinType.float => 56,
        LuminaPinType.string || LuminaPinType.name => 96,
        LuminaPinType.vector2D => 104,
        LuminaPinType.vector || LuminaPinType.rotator => 170,
        LuminaPinType.color => 96,
        LuminaPinType.transform => 176,
        LuminaPinType.hitResult => 62,
        LuminaPinType.structEnum || LuminaPinType.enumeration => 108,
        _ => 0,
      };

  /// `comment_move`, `comment_camera_toggle`; unique within one [stack].
  static String _commentId(String title, Set<String> used) {
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    var id = 'comment_${slug.isEmpty ? 'section' : slug}';
    for (var i = 2; !used.add(id); i++) {
      id = 'comment_${slug}_$i';
    }
    return id;
  }
}
