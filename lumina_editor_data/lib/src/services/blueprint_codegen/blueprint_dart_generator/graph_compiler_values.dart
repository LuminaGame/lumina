part of '../blueprint_dart_generator.dart';

/// The data side of [_GraphCompiler]: input and output expressions,
/// evaluating the pure nodes behind them in the VM's order.
extension _GraphCompilerValues on _GraphCompiler {
  /// The expression for [node]'s input [pin]: its wire's source, else its
  /// literal, else the library default — the VM's `_input`.
  String _input(_Frame frame, LuminaBlueprintNode node, String pin, Map<String, Map<String, String>> step,
      List<String> out, String pad) {
    final spec = pins[node.id]!.inputs.where((p) => p.id == pin).firstOrNull;
    // A shape argument that is a node setting, not a pin (`enum`, `interface`, `dispatcher`).
    if (spec == null) return _json(node.literals[pin]);
    final wire = graph.wireInto(node.id, pin);
    if (wire != null) {
      final expr = _output(frame, wire.fromNodeId, wire.fromPinId, step, out, pad);
      final fromNode = graph.node(wire.fromNodeId);
      final declared = fromNode == null
          ? null
          : LuminaBlueprintNodeLibrary.spec(fromNode.registryId)?.outputs.where((p) => p.id == wire.fromPinId).firstOrNull?.type;
      final from = pins[wire.fromNodeId]?.outputs.where((p) => p.id == wire.fromPinId).firstOrNull?.type;
      // A wildcard source (an array item, a loop element — Object? in Dart,
      // even when a `type` literal types the pin) feeding a typed pin is
      // checked at run time, as the VM's typed inputs are.
      final wildcardSource = from == LuminaPinType.wildcard || declared == LuminaPinType.wildcard;
      if (wildcardSource && spec.type != LuminaPinType.wildcard && spec.type != LuminaPinType.object) {
        // One typed local per use site: an inline `as` would promote the
        // source variable and make a second cast redundant.
        final typed = 't${_counter.next()}';
        out.add('${pad}final $typed = $expr as ${_dartType(spec.type)};');
        return typed;
      }
      return expr;
    }
    if (node.literals.containsKey(pin)) return _literal(spec.type, node.literals[pin]);
    return _literal(spec.type, spec.defaultValue);
  }

  /// The expression for [nodeId]'s output [pin] — the VM's `_output`.
  String _output(_Frame frame, String nodeId, String pin, Map<String, Map<String, String>> step, List<String> out,
      String pad) {
    final type = pins[nodeId]?.outputs.where((p) => p.id == pin).firstOrNull?.type;
    if (nodeId == frame.eventNodeId) return frame.eventOutputs[pin] ?? _literal(type!, null);
    final node = graph.node(nodeId)!;
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId)!;
    // A custom event's red delegate pin.
    if (node.registryId == LuminaBlueprintNodeLibrary.customEvent && pin == 'delegate') {
      return 'LuminaBlueprintDelegate($self, ${_str(node.literals['name'] as String? ?? '')})';
    }
    if (spec.kind != LuminaBlueprintNodeKind.pure) {
      final holder = frame.impureVars['$nodeId.$pin'];
      final zero = _literal(type!, null);
      return holder == null ? zero : (zero == 'null' ? holder : '($holder ?? $zero)');
    }
    final cached = step[nodeId];
    if (cached != null) return cached[pin]!;
    final values = <String, String>{};
    final Map<String, String> outputs;
    if (node.registryId == LuminaBlueprintNodeLibrary.variableGet) {
      final v = 'p${_counter.next()}';
      final hasTarget = pins[nodeId]!.inputs.any((p) => p.id == 'target');
      if (hasTarget) {
        final target = _input(frame, node, 'target', step, out, pad);
        out.add('${pad}final $v = ($target as dynamic)?.${_var(node.literals['variable'] as String)};');
      } else {
        out.add('${pad}final $v = ${readVariable(node.literals['variable'] as String)};');
      }
      outputs = {'value': v};
    } else if (node.registryId == LuminaBlueprintNodeLibrary.getComponent && pins[nodeId]!.inputs.any((p) => p.id == 'target')) {
      final target = _input(frame, node, 'target', step, out, pad);
      final compName = _str(node.literals['component'] as String? ?? '');
      final r = 'p${_counter.next()}';
      out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.getComponent($target, $compName);');
      outputs = {'return_value': r};
    } else if (node.registryId == LuminaBlueprintNodeLibrary.localVariableGet) {
      final v = 'p${_counter.next()}';
      if (readLocal == null) {
        error('Local variable ${node.literals['variable']} is used outside a function.', node: node.id);
        return 'null';
      }
      out.add('${pad}final $v = ${readLocal!(node.literals['variable'] as String)};');
      outputs = {'value': v};
    } else if (node.registryId == LuminaBlueprintNodeLibrary.callFunctionPure) {
      final args = _signatureArgs(frame, node, step, out, pad, const {'function'}, values);
      final r = 'p${_counter.next()}';
      out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.callFunction($self, ${_str(node.literals['function'] as String? ?? '')}, $args);');
      outputs = {};
      for (final o in pins[nodeId]!.outputs) {
        final v = 'p${_counter.next()}';
        out.add('${pad}final $v = ${_mapOutput(r, o)};');
        outputs[o.id] = v;
      }
      step[nodeId] = outputs;
      out.add('${pad}if (trace != null) blueprintTrace(${_str(frame.traceId)}, ${_str(nodeId)}, '
          '${_str(node.registryId)}, ${_map({...values, ...outputs})});');
      return outputs[pin]!;
    } else if (node.registryId == 'make_array') {
      // Variadic: one argument per item pin.
      final items = [for (final p in pins[nodeId]!.inputs) p.id];
      for (final a in items) {
        values[a] = _input(frame, node, a, step, out, pad);
      }
      final r = 'p${_counter.next()}';
      out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.makeArray([${items.map((a) => values[a]!).join(', ')}]);');
      outputs = {'return_value': r};
    } else {
      final shape = _GraphCompiler._shape(node.registryId)!;
      final args = <String, String>{};
      for (final a in shape.args) {
        args[a] = _input(frame, node, a, step, out, pad);
        if (pins[nodeId]!.inputs.any((p) => p.id == a)) values[a] = args[a]!;
      }
      final r = 'p${_counter.next()}';
      out.add('${pad}final $r = ${_call(shape, node, [for (final a in shape.args) args[a]!])};');
      outputs = {for (final o in shape.outputs) o: shape.returnsRecord ? '$r.${_recordField(o)}' : r};
    }
    step[nodeId] = outputs;
    out.add('${pad}if (trace != null) blueprintTrace(${_str(frame.traceId)}, ${_str(nodeId)}, '
        '${_str(node.registryId)}, ${_map({...values, ...outputs})});');
    return outputs[pin]!;
  }
}
