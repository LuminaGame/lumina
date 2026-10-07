import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintGraph, LuminaBlueprintNode, LuminaBlueprintWire;

import 'package:lumina_ui/ui/features/sub_editors/models/material_fragment_pins.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_source.dart';

part 'material_graph_parser/lexer_and_parser.dart';
part 'material_graph_parser/lowering.dart';
part 'material_graph_parser/layout.dart';

/// What [MaterialGraphParser.parse] made of a `.mat` source.
class MaterialGraphParseResult {
  final LuminaBlueprintGraph graph;

  /// Why the fragment became one Custom (Fragment) node, or null when the
  /// graph expresses it.
  final String? fallbackReason;

  /// Things a later graph edit will not keep (comments).
  final List<String> notes;

  const MaterialGraphParseResult(this.graph, {this.fallbackReason, this.notes = const []});

  bool get isFallback => fallbackReason != null;
}

/// Reads a `.mat` source into a material graph.
///
/// The fragment's `material()` body is parsed statement by statement into
/// expressions; the generator's own output parses back into the graph it came
/// from. A call the catalog has no node for becomes a Custom expression node
/// holding its GLSL; anything that cannot be expressed statement by statement
/// (control flow, unknown fields or declarations) makes the whole fragment one
/// Custom (Fragment) node, kept verbatim. Header parameters always become
/// parameter nodes, so a graph edit never drops a declaration.
class MaterialGraphParser {
  static MaterialGraphParseResult parse(String source) {
    final MatSource src;
    try {
      src = MatSource.parse(source);
    } on FormatException catch (e) {
      // Not even the blocks can be told apart: keep the text in one node.
      return _fallback(const MatSource([], []), source, 'the source does not parse (${e.message})');
    }
    final fragment = src.block('fragment');
    final body = fragment?.body ?? '';
    final vertex = src.block('vertex');
    try {
      final lowering = _Lowering(src);
      lowering.run(body, vertexBody: vertex?.body);
      final graph = lowering.graph;
      MaterialGraphLayout.arrange(graph);
      final vertexNodes = graph.node(MaterialNodes.outputNodeId)?.literals['vertexGraph'] == true;
      return MaterialGraphParseResult(graph, notes: [
        if (_hasComments(body)) 'Comments in the fragment are not kept once the graph rewrites the code.',
        if (vertexNodes && _hasComments(vertex!.body)) 'Comments in the vertex block are not kept once the graph rewrites the code.',
        ...lowering.notes,
      ]);
    } on _Unsupported catch (e) {
      return _fallback(src, body, e.reason);
    }
  }

  static bool _hasComments(String s) => s.contains('//') || s.contains('/*');

  static MaterialGraphParseResult _fallback(MatSource src, String fragmentBody, String reason) {
    final graph = LuminaBlueprintGraph();
    final output = MaterialNodes.ensureOutput(graph, materialName: src.materialName);
    final lowering = _Lowering(src, graph: graph);
    lowering.declareHeaderParameters(unusedOnly: false);
    // The vertex block stays as written next to the Custom (Fragment) node;
    // its variables are kept declared.
    output.literals['extraVariables'] = [for (final v in src.variables) v.raw.render()];
    final vertex = src.block('vertex');
    if (vertex != null && vertex.body.contains('material.')) {
      output.literals['vertexVerbatim'] = 'the fragment is a Custom (Fragment) node';
    }
    graph.nodes.add(MaterialNodes.create(
      MaterialNodes.customFragment,
      id: 'fragment',
      literals: {'code': _trimBlankLines(fragmentBody)},
    ));
    // Show the verbatim code's flow: parameters in, written fields out.
    MaterialFragmentPins.syncWires(graph);
    MaterialGraphLayout.arrange(graph);
    return MaterialGraphParseResult(graph, fallbackReason: reason);
  }

  static String _trimBlankLines(String s) {
    final lines = s.split('\n');
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }
}
