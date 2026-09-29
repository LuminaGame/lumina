import 'blueprint_model.dart';
import 'node_library.dart';

/// Expands every `call_macro` node of a graph into the macro's body
/// (inlining each macro instance): body nodes are
/// copied under `<callId>__<bodyId>` so a trace maps back to the instance,
/// wires into the call's inputs continue into what the body's `Inputs` node
/// fed, wires out of the call's outputs start from what fed the body's
/// `Outputs` node, and a literal on the call node becomes the literal of
/// every body pin that read that input. Nested macros expand too (depth 16).
abstract final class LuminaBlueprintMacroExpander {
  static const int maxDepth = 16;

  /// [graph] with every macro call inlined; [graph] itself is untouched (the
  /// document stays folded). A graph without macro calls is returned as is.
  static LuminaBlueprintGraph expand(LuminaBlueprintGraph graph, List<LuminaBlueprintMacroGraph> macros, {int depth = 0}) {
    if (macros.isEmpty || !graph.nodes.any((n) => n.registryId == LuminaBlueprintNodeLibrary.callMacro)) return graph;
    if (depth >= maxDepth) return graph;
    final nodes = <LuminaBlueprintNode>[];
    final wires = <LuminaBlueprintWire>[];
    var wireSerial = 0;
    String wireId(String call) => '${call}__w${wireSerial++}';

    // Endpoint rewrites: (callId, pin) → the expanded endpoints.
    final inputTargets = <String, List<(String node, String pin)>>{}; // call.inputPin → body consumers
    final outputSources = <String, (String node, String pin)?>{}; // call.outputPin → body producer
    for (final node in graph.nodes) {
      if (node.registryId != LuminaBlueprintNodeLibrary.callMacro) {
        nodes.add(node);
        continue;
      }
      final macro = macros.where((m) => m.name == node.literals['macro']).firstOrNull;
      if (macro == null) {
        nodes.add(node);
        continue;
      }
      final body = expand(macro.graph, macros, depth: depth + 1);
      String prefixed(String id) => '${node.id}__$id';
      final inputNode = body.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.macroInput).firstOrNull;
      final outputNode = body.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.macroOutput).firstOrNull;
      for (final b in body.nodes) {
        if (identical(b, inputNode) || identical(b, outputNode)) continue;
        nodes.add(LuminaBlueprintNode(
          id: prefixed(b.id),
          registryId: b.registryId,
          title: b.title,
          category: b.category,
          x: b.x,
          y: b.y,
          headerColor: b.headerColor,
          inputs: [...b.inputs],
          outputs: [...b.outputs],
          literals: {...b.literals},
        ));
      }
      for (final w in body.wires) {
        final fromInput = inputNode != null && w.fromNodeId == inputNode.id;
        final toOutput = outputNode != null && w.toNodeId == outputNode.id;
        if (fromInput && toOutput) {
          // A pass-through: the call's input goes straight to its output.
          (inputTargets['${node.id}.${w.fromPinId}'] ??= []).add(('#passthrough', w.toPinId));
          continue;
        }
        if (fromInput) {
          (inputTargets['${node.id}.${w.fromPinId}'] ??= []).add((prefixed(w.toNodeId), w.toPinId));
          continue;
        }
        if (toOutput) {
          outputSources['${node.id}.${w.toPinId}'] = (prefixed(w.fromNodeId), w.fromPinId);
          continue;
        }
        wires.add(LuminaBlueprintWire(
            id: wireId(node.id), fromNodeId: prefixed(w.fromNodeId), fromPinId: w.fromPinId, toNodeId: prefixed(w.toNodeId), toPinId: w.toPinId));
      }
      // Literals on the call's data inputs feed the body pins that read them.
      for (final entry in node.literals.entries) {
        if (entry.key == 'macro') continue;
        for (final (target, pin) in inputTargets['${node.id}.${entry.key}'] ?? const <(String, String)>[]) {
          if (target == '#passthrough') continue;
          nodes.firstWhere((n) => n.id == target).literals[pin] = entry.value;
        }
      }
    }
    final callIds = {for (final n in graph.nodes) if (n.registryId == LuminaBlueprintNodeLibrary.callMacro) n.id};
    // Wires of the caller: redirect the ones touching a macro call.
    List<LuminaBlueprintWire> redirect(LuminaBlueprintWire w) {
      final fromCall = callIds.contains(w.fromNodeId);
      final toCall = callIds.contains(w.toNodeId);
      if (!fromCall && !toCall) return [w];
      var from = (w.fromNodeId, w.fromPinId);
      if (fromCall) {
        final src = outputSources['${w.fromNodeId}.${w.fromPinId}'];
        if (src == null) return const [];
        from = src;
      }
      if (!toCall) {
        return [LuminaBlueprintWire(id: wireId(w.toNodeId), fromNodeId: from.$1, fromPinId: from.$2, toNodeId: w.toNodeId, toPinId: w.toPinId)];
      }
      final targets = inputTargets['${w.toNodeId}.${w.toPinId}'] ?? const <(String, String)>[];
      final out = <LuminaBlueprintWire>[];
      for (final (target, pin) in targets) {
        if (target == '#passthrough') {
          // Input → output of the same call: connect our source to whatever reads the call's output.
          for (final reader in graph.wires.where((r) => r.fromNodeId == w.toNodeId && r.fromPinId == pin)) {
            out.add(LuminaBlueprintWire(
                id: wireId(reader.toNodeId), fromNodeId: from.$1, fromPinId: from.$2, toNodeId: reader.toNodeId, toPinId: reader.toPinId));
          }
          continue;
        }
        out.add(LuminaBlueprintWire(id: wireId(target), fromNodeId: from.$1, fromPinId: from.$2, toNodeId: target, toPinId: pin));
      }
      return out;
    }

    for (final w in graph.wires) {
      wires.addAll(redirect(w));
    }
    // A call whose output is read but was fed by a pass-through is handled above; drop dangling duplicates.
    final seen = <String>{};
    final unique = [for (final w in wires) if (seen.add('${w.fromNodeId}.${w.fromPinId}>${w.toNodeId}.${w.toPinId}')) w];
    return LuminaBlueprintGraph(nodes: nodes, wires: unique);
  }
}
