part of '../blueprint_editor_view_model.dart';

/// Collapsing a node selection into a function/macro/collapsed graph and
/// expanding it back.
mixin _BlueprintEditorCollapseExpand on _BlueprintEditorViewModelState {

  /// Collapse to Function / Collapse to Macro (and Collapse Nodes,
  /// which makes a macro): the selected nodes of the active graph move into
  /// a new graph named [name]; wires crossing the selection's boundary
  /// become the new graph's inputs and outputs, and one call node takes the
  /// selection's place with those wires re-attached. One undo step; null
  /// (with [collapseRefusal] set) when the selection cannot be collapsed.
  @override
  LuminaBlueprintNode? collapseSelection({required bool toMacro, String? name, BlueprintGraphRef? graph}) {
    collapseRefusal = null;
    final ref = graph ?? _activeGraph;
    if (!ref.hasGraph) return _refuse('Only a node graph can be collapsed');
    final editor = graphEditor(ref);
    final selected = {
      for (final id in editor.selectedNodeIds)
        if (editor.node(id) != null && !BlueprintEditorNodes.isComment(editor.node(id)!)) id,
    };
    if (selected.isEmpty) return _refuse('Select the nodes to collapse first');
    for (final id in selected) {
      final n = editor.node(id)!;
      final spec = LuminaBlueprintNodeLibrary.spec(n.registryId);
      if (spec?.kind == LuminaBlueprintNodeKind.event ||
          n.registryId == LuminaBlueprintNodeLibrary.functionResult ||
          n.registryId == LuminaBlueprintNodeLibrary.macroOutput) {
        return _refuse('${n.title} cannot be collapsed: events, entries and returns stay in their graph');
      }
      if (!toMacro && spec?.kind == LuminaBlueprintNodeKind.latent) {
        return _refuse('${n.title} is latent: collapse to a macro instead');
      }
    }
    final wires = editor.wires;
    final inbound = [for (final w in wires) if (selected.contains(w.toNodeId) && !selected.contains(w.fromNodeId)) w];
    final outbound = [for (final w in wires) if (selected.contains(w.fromNodeId) && !selected.contains(w.toNodeId)) w];
    // Resolved now: the selected nodes leave the graph before rewiring.
    final wireTypes = {
      for (final w in [...inbound, ...outbound]) w.id: editor.pin(w.fromNodeId, w.fromPinId, output: true)?.type,
    };
    LuminaPinType? typeOf(LuminaBlueprintWire w) => wireTypes[w.id];
    final execIn = {for (final w in inbound) if (typeOf(w) == LuminaPinType.exec) (w.toNodeId, w.toPinId)}.toList();
    final execOut = {for (final w in outbound) if (typeOf(w) == LuminaPinType.exec) (w.fromNodeId, w.fromPinId)}.toList();
    if (!toMacro && execIn.length > 1) return _refuse('A function has one entry: the selection is entered at ${execIn.length} pins');
    if (!toMacro && execOut.length > 1) return _refuse('A function has one exit: the selection leaves at ${execOut.length} pins');
    final dataIn = {for (final w in inbound) if (typeOf(w) != LuminaPinType.exec) (w.toNodeId, w.toPinId)}.toList();
    final dataOut = {for (final w in outbound) if (typeOf(w) != LuminaPinType.exec) (w.fromNodeId, w.fromPinId)}.toList();

    // Parameter names and types from the inner pins they stand for.
    final usedNames = <String>{};
    String param(String pinName) {
      var base = _pascal(pinName);
      if (base == 'ExecIn' || base == 'ExecOut') base = 'Exec';
      var unique = base;
      for (var n = 2; usedNames.contains(unique); n++) {
        unique = '$base$n';
      }
      usedNames.add(unique);
      return unique;
    }

    LuminaBlueprintVariable? variableFor((String, String) key, {required bool output}) {
      final spec = editor.pin(key.$1, key.$2, output: output);
      if (spec == null) return null;
      final type = editor.variableTypeFor(BlueprintPinRef.of(key.$1, spec, isOutput: output));
      if (type == null) return null;
      return LuminaBlueprintVariable(name: param(spec.name), typeName: type, defaultValue: BlueprintPinStyle.defaultValueFor(type));
    }

    final inputs = <(String, String), LuminaBlueprintVariable>{};
    final outputs = <(String, String), LuminaBlueprintVariable>{};
    for (final key in dataIn) {
      final v = variableFor(key, output: false);
      if (v == null) return _refuse('The pin ${key.$2} of ${editor.node(key.$1)?.title} has no type a parameter can carry');
      inputs[key] = v;
    }
    for (final key in dataOut) {
      final v = variableFor(key, output: true);
      if (v == null) return _refuse('The pin ${key.$2} of ${editor.node(key.$1)?.title} has no type a parameter can carry');
      outputs[key] = v;
    }
    final execInNames = {for (final key in execIn) key: param(toMacro && execIn.length > 1 ? 'Exec ${execIn.indexOf(key) + 1}' : 'Exec')};
    final execOutNames = {for (final key in execOut) key: param(toMacro && execOut.length > 1 ? 'Then ${execOut.indexOf(key) + 1}' : 'Then')};

    final graphName = _uniqueName(name?.trim().isNotEmpty == true ? name!.trim() : (toMacro ? 'CollapsedGraph' : 'CollapsedFunction'), _nameTaken);
    final nodes = [for (final id in selected) editor.node(id)!];
    final minX = nodes.fold<double>(double.infinity, (m, n) => math.min(m, n.x));
    final maxX = nodes.fold<double>(-double.infinity, (m, n) => math.max(m, n.x));
    final avgY = nodes.fold<double>(0, (m, n) => m + n.y) / nodes.length;
    final callAt = Offset(nodes.fold<double>(0, (m, n) => m + n.x) / nodes.length, avgY);
    final newRef = toMacro ? BlueprintGraphRef.macro(graphName) : BlueprintGraphRef.function(graphName);

    final result = mutate<LuminaBlueprintNode?>(toMacro ? 'Collapse to macro $graphName' : 'Collapse to function $graphName', () {
      final g = editor.graph;
      final inner = [for (final n in g.nodes) if (selected.contains(n.id)) n];
      final innerWires = [for (final w in g.wires) if (selected.contains(w.fromNodeId) && selected.contains(w.toNodeId)) w];
      g.nodes.removeWhere((n) => selected.contains(n.id));
      g.wires.removeWhere((w) => selected.contains(w.fromNodeId) || selected.contains(w.toNodeId));

      final entryId = BlueprintGraphEditor.newId(toMacro ? 'inputs' : 'entry');
      final resultId = BlueprintGraphEditor.newId(toMacro ? 'outputs' : 'result');
      final LuminaBlueprintGraph body;
      if (toMacro) {
        final macro = LuminaBlueprintMacroGraph(
          name: graphName,
          inputs: [
            for (final key in execIn) LuminaBlueprintVariable(name: execInNames[key]!, typeName: 'Exec'),
            ...inputs.values,
          ],
          outputs: [
            for (final key in execOut) LuminaBlueprintVariable(name: execOutNames[key]!, typeName: 'Exec'),
            ...outputs.values,
          ],
          graph: LuminaBlueprintGraph(nodes: inner, wires: innerWires),
        );
        _document.macros.add(macro);
        body = macro.graph;
        final context = _contextFor(macro: macro);
        body.nodes.insert(0, LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.macroInput, nodeId: entryId, x: minX - 320, y: avgY, context: context));
        body.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.macroOutput, nodeId: resultId, x: maxX + 320, y: avgY, context: context));
      } else {
        final fn = LuminaBlueprintFunctionGraph(
          name: graphName,
          inputs: inputs.values.toList(),
          outputs: outputs.values.toList(),
          graph: LuminaBlueprintGraph(nodes: inner, wires: innerWires),
        );
        _document.functions.add(fn);
        body = fn.graph;
        final context = _contextFor(function: fn);
        body.nodes.insert(0, LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.functionEntry, nodeId: entryId, x: minX - 320, y: avgY, context: context));
        if (outputs.isNotEmpty || execOut.isNotEmpty) {
          body.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.functionResult, nodeId: resultId, x: maxX + 320, y: avgY, context: context));
        }
      }
      LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
          LuminaBlueprintWire(id: BlueprintGraphEditor.newId('wire'), fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
      // Inside: entry → inner pins, inner pins → result.
      for (final key in execIn) {
        body.wires.add(wire(entryId, toMacro ? execInNames[key]! : 'exec_out', key.$1, key.$2));
      }
      for (final e in inputs.entries) {
        body.wires.add(wire(entryId, e.value.name, e.key.$1, e.key.$2));
      }
      for (final key in execOut) {
        body.wires.add(wire(key.$1, key.$2, resultId, toMacro ? execOutNames[key]! : 'exec_in'));
      }
      for (final e in outputs.entries) {
        body.wires.add(wire(e.key.$1, e.key.$2, resultId, e.value.name));
      }
      // Outside: the call node in the selection's place.
      final call = LuminaBlueprintNodeLibrary.place(
        toMacro ? LuminaBlueprintNodeLibrary.callMacro : LuminaBlueprintNodeLibrary.callFunction,
        nodeId: BlueprintGraphEditor.newId('call'),
        x: callAt.dx,
        y: callAt.dy,
        literals: {toMacro ? 'macro' : 'function': graphName},
        context: _contextFor(),
      );
      g.nodes.add(call);
      for (final w in inbound) {
        final key = (w.toNodeId, w.toPinId);
        final pin = typeOf(w) == LuminaPinType.exec ? (toMacro ? execInNames[key]! : 'exec_in') : inputs[key]!.name;
        if (!g.wires.any((x) => x.toNodeId == call.id && x.toPinId == pin && typeOf(w) != LuminaPinType.exec)) {
          g.wires.add(wire(w.fromNodeId, w.fromPinId, call.id, pin));
        }
      }
      for (final w in outbound) {
        final key = (w.fromNodeId, w.fromPinId);
        final pin = typeOf(w) == LuminaPinType.exec ? (toMacro ? execOutNames[key]! : 'exec_out') : outputs[key]!.name;
        g.wires.add(wire(call.id, pin, w.toNodeId, w.toPinId));
      }
      editor.selectMany({call.id});
      return call;
    });
    if (result != null) {
      graphEditor(newRef);
      notifyListeners();
    }
    return result;
  }

  LuminaBlueprintNode? _refuse(String why) {
    collapseRefusal = why;
    return null;
  }

  /// Expand Node on a Call Function / Macro node: the graph's body
  /// comes back into the caller's graph where the call was, wired the way
  /// the call was; the function or macro itself is deleted when nothing
  /// else called it. Returns the ids of the restored nodes.
  Set<String>? expandNode(String nodeId, {BlueprintGraphRef? graph}) {
    final ref = graph ?? _activeGraph;
    if (!ref.hasGraph) return null;
    final editor = graphEditor(ref);
    final call = editor.node(nodeId);
    if (call == null) return null;
    final isMacro = call.registryId == LuminaBlueprintNodeLibrary.callMacro;
    final isFunction = call.registryId == LuminaBlueprintNodeLibrary.callFunction || call.registryId == LuminaBlueprintNodeLibrary.callFunctionPure;
    if (!isMacro && !isFunction) return null;
    final name = call.literals[isMacro ? 'macro' : 'function'] as String?;
    final body = isMacro ? _document.macro(name)?.graph : _document.function(name)?.graph;
    if (name == null || body == null) return null;
    final otherCallers = (isMacro ? nodesCallingMacro(name) : nodesCallingFunction(name)).where((n) => n.id != nodeId).isNotEmpty;
    final restored = <String>{};
    final ok = mutate('Expand ${call.title}', () {
      final g = editor.graph;
      final entry = body.nodes.where((n) => n.registryId == (isMacro ? LuminaBlueprintNodeLibrary.macroInput : LuminaBlueprintNodeLibrary.functionEntry)).firstOrNull;
      final result = body.nodes.where((n) => n.registryId == (isMacro ? LuminaBlueprintNodeLibrary.macroOutput : LuminaBlueprintNodeLibrary.functionResult)).firstOrNull;
      final boundary = {?entry?.id, ?result?.id};
      // Fresh ids only when the body stays (another caller may expand too).
      final idMap = <String, String>{};
      for (final n in body.nodes) {
        if (boundary.contains(n.id)) continue;
        idMap[n.id] = otherCallers ? BlueprintGraphEditor.newId('node') : n.id;
      }
      final copy = LuminaBlueprintGraph.fromJson(body.toJson());
      final offset = Offset(call.x - (entry?.x ?? 0) - 320, call.y - (entry?.y ?? 0));
      for (final n in copy.nodes) {
        if (boundary.contains(n.id)) continue;
        final placed = LuminaBlueprintNode.fromJson({...n.toJson(), 'id': idMap[n.id]});
        placed.x += offset.dx;
        placed.y += offset.dy;
        g.nodes.add(placed);
        restored.add(placed.id);
      }
      LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
          LuminaBlueprintWire(id: BlueprintGraphEditor.newId('wire'), fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
      final callIn = [for (final w in g.wires) if (w.toNodeId == nodeId) w];
      final callOut = [for (final w in g.wires) if (w.fromNodeId == nodeId) w];
      for (final w in copy.wires) {
        final fromBoundary = boundary.contains(w.fromNodeId);
        final toBoundary = boundary.contains(w.toNodeId);
        if (!fromBoundary && !toBoundary) {
          g.wires.add(wire(idMap[w.fromNodeId]!, w.fromPinId, idMap[w.toNodeId]!, w.toPinId));
          continue;
        }
        if (fromBoundary && !toBoundary) {
          // entry.<param> → inner: whatever fed the call's <param> feeds inner.
          final callPin = w.fromPinId == 'exec_out' ? 'exec_in' : w.fromPinId;
          final feeding = callIn.where((x) => x.toPinId == callPin);
          for (final f in feeding) {
            g.wires.add(wire(f.fromNodeId, f.fromPinId, idMap[w.toNodeId]!, w.toPinId));
          }
          if (feeding.isEmpty && call.literals.containsKey(callPin)) {
            g.node(idMap[w.toNodeId]!)!.literals[w.toPinId] = call.literals[callPin];
          }
          continue;
        }
        if (!fromBoundary && toBoundary) {
          // inner → result.<param>: the call's <param> targets now read inner.
          final callPin = w.toPinId == 'exec_in' ? 'exec_out' : w.toPinId;
          for (final t in callOut.where((x) => x.fromPinId == callPin)) {
            g.wires.add(wire(idMap[w.fromNodeId]!, w.fromPinId, t.toNodeId, t.toPinId));
          }
        }
      }
      g.wires.removeWhere((w) => w.fromNodeId == nodeId || w.toNodeId == nodeId);
      g.nodes.removeWhere((n) => n.id == nodeId);
      if (!otherCallers) {
        if (isMacro) {
          _document.macros.removeWhere((m) => m.name == name);
        } else {
          _document.functions.removeWhere((f) => f.name == name);
        }
      }
      editor.selectMany(restored);
      return true;
    });
    if (!ok) return null;
    _pruneGraphState();
    notifyListeners();
    return restored;
  }
}

String _pascal(String s) {
  final words = s.split(RegExp(r'[^A-Za-z0-9]+')).where((w) => w.isNotEmpty);
  final out = words.map((w) => w[0].toUpperCase() + w.substring(1)).join();
  return out.isEmpty ? 'Value' : out;
}
