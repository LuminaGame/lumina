import 'dart:ui' show Offset;

import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The node, pin and wire JSON and the node / wire / literal edits of a
/// Blueprint node graph, over any [BlueprintGraphEditor] (extracted from
/// the Blueprint tools so the Animation Blueprint's update graph and
/// transition rules share them).
/// Every edit is the graph editor's own call, so it is one undo step on the
/// stack of the editor that owns the graph.

Map<String, Object?> mcpPinSpec(LuminaBlueprintPinSpec p) => {
      'id': p.id,
      'name': p.name,
      'type': p.type.name,
      'default': p.defaultValue,
      'required': p.required,
    };

Map<String, Object?> mcpNodeJson(BlueprintGraphEditor graph, LuminaBlueprintNode n) {
  final pins = graph.pinsOf(n);
  return {
    'id': n.id,
    'node': n.registryId,
    'title': n.title,
    'category': n.category,
    'x': n.x,
    'y': n.y,
    'inputs': [
      for (final p in pins.inputs)
        {...mcpPinSpec(p), 'literal': n.literals[p.id], 'connected': graph.isConnected(n.id, p.id, output: false)},
    ],
    'outputs': [
      for (final p in pins.outputs) {...mcpPinSpec(p), 'connected': graph.isConnected(n.id, p.id, output: true)},
    ],
    'literals': n.literals,
  };
}

Map<String, Object?> mcpWireJson(LuminaBlueprintWire w) => {
      'id': w.id,
      'from_node': w.fromNodeId,
      'from_pin': w.fromPinId,
      'to_node': w.toNodeId,
      'to_pin': w.toPinId,
    };

/// A graph's nodes and wires as `get_*` tools return them.
Map<String, Object?> mcpGraphJson(BlueprintGraphEditor graph) => {
      'nodes': [for (final n in graph.graph.nodes) mcpNodeJson(graph, n)],
      'wires': graph.graph.wires.map(mcpWireJson).toList(),
    };

/// Places library node `node` at (`x`, `y`) with optional `literals`.
/// [rejected] explains why the graph refuses a node its filter does not take.
McpToolResult mcpGraphAddNode(
  BlueprintGraphEditor graph,
  String graphName,
  McpArgs args, {
  required String rejected,
  Map<String, Object?> Function()? extra,
}) {
  final registryId = args.string('node');
  if (LuminaBlueprintNodeLibrary.spec(registryId) == null) {
    return McpToolResult.error(
      'No library node "$registryId". Library ids look like "print_string" or "branch"; call list_blueprint_nodes '
      '(optionally with query) to find the id.',
    );
  }
  if (!graph.accepts(registryId)) return McpToolResult.error('The $graphName graph does not accept "$registryId": $rejected');
  final node = graph.addNode(
    registryId,
    Offset(args.number('x', fallback: 400), args.number('y', fallback: 200)),
    literals: args.optionalObject('literals')?.cast<String, dynamic>(),
  );
  if (node == null) return McpToolResult.error('The $graphName graph does not accept "$registryId": $rejected');
  return McpToolResult.json({'graph': graphName, 'node': mcpNodeJson(graph, node), ...?extra?.call()});
}

/// Wires `from_node.from_pin` → `to_node.to_pin`.
McpToolResult mcpGraphConnect(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra}) {
  final fromNode = args.string('from_node'), fromPin = args.string('from_pin');
  final toNode = args.string('to_node'), toPin = args.string('to_pin');
  for (final id in [fromNode, toNode]) {
    if (graph.node(id) == null) return McpToolResult.error('No node "$id" in the $graphName graph; ids come from the graph listing.');
  }
  final why = graph.whyNotConnect(fromNode, fromPin, toNode, toPin);
  if (why != null) {
    final from = graph.pin(fromNode, fromPin, output: true);
    final to = graph.pin(toNode, toPin, output: false);
    return McpToolResult.error(
      'Cannot connect $fromNode.$fromPin (${from?.type.name ?? 'no such output pin'}) → $toNode.$toPin '
      '(${to?.type.name ?? 'no such input pin'}): $why.',
    );
  }
  final wire = graph.addWire(fromNodeId: fromNode, fromPinId: fromPin, toNodeId: toNode, toPinId: toPin);
  if (wire == null) return McpToolResult.error('The wire was not created.');
  return McpToolResult.json({'graph': graphName, 'wire': mcpWireJson(wire), ...?extra?.call()});
}

/// Sets the literal of input pin `pin` on node `node` to `value`.
McpToolResult mcpGraphSetLiteral(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra}) {
  final nodeId = args.string('node'), pinId = args.string('pin');
  final node = graph.node(nodeId);
  if (node == null) return McpToolResult.error('No node "$nodeId" in the $graphName graph; ids come from the graph listing.');
  if (graph.pin(nodeId, pinId, output: false) == null) {
    final pins = graph.pinsOf(node).inputs.map((p) => p.id).join(', ');
    return McpToolResult.error('Node "${node.title}" has no input pin "$pinId". Inputs: $pins.');
  }
  final changed = graph.setLiteral(nodeId, pinId, args['value']);
  return McpToolResult.json({'changed': changed, 'node': mcpNodeJson(graph, node), ...?extra?.call()});
}

/// Deletes node `node` and its wires.
McpToolResult mcpGraphRemoveNode(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra}) {
  final nodeId = args.string('node');
  if (!graph.removeNode(nodeId)) return McpToolResult.error('No node "$nodeId" in the $graphName graph (or it cannot be removed).');
  return McpToolResult.json({'removed': nodeId, ...?extra?.call()});
}

/// Deletes wire `wire`.
McpToolResult mcpGraphRemoveWire(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra}) {
  final wireId = args.string('wire');
  if (!graph.removeWire(wireId)) return McpToolResult.error('No wire "$wireId" in the $graphName graph.');
  return McpToolResult.json({'removed': wireId, ...?extra?.call()});
}
