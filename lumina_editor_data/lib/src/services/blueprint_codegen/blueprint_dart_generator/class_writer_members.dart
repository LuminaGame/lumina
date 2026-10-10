part of '../blueprint_dart_generator.dart';

/// The members [_ClassWriter] writes per user function and per Timeline
/// node.
extension _ClassWriterMembers on _ClassWriter {
  /// A user function as a method taking its argument map and returning its
  /// outputs: inputs are the entry's outputs, locals are Dart
  /// locals, the Return node returns.
  String? _functionMethod(LuminaBlueprintFunctionGraph f, String method) {
    final fc = level != null || widget != null
        ? context.scoped(doc, function: f)
        : LuminaBlueprintTypeContext.forDocument(doc, inputActions: inputActions, className: blueprintName, functionScope: f);
    final graph = LuminaBlueprintMacroExpander.expand(f.graph, doc.macros);
    final entry = graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry).firstOrNull;
    if (entry == null) {
      _error("Function '${f.name}' has no Function Entry node.");
      return null;
    }
    String localName(String name) => 'l${_cap(_var(name))}';
    final zeros = {for (final o in f.outputs) o.name: _literal(o.type ?? LuminaPinType.float, o.defaultValue)};
    final c = _GraphCompiler(
      graph,
      fc,
      _counter,
      self: 'this',
      readVariable: _var,
      writeVariable: (name, value) => '${_var(name)} = $value;',
      readLocal: localName,
      writeLocal: (name, value) => '${localName(name)} = $value;',
      returnStatement: (outputs) => 'return ${_map({...zeros, ...outputs})};',
      timelineOf: _timelineGetter,
      error: _error,
      libraries: compiler.libraries,
    );
    final frame = _Frame(entry.id, _id(entry.id), {for (final i in f.inputs) i.name: _var(i.name)}, '', '');
    final body = <String>[];
    final result = graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult).firstOrNull;
    if (f.pure) {
      if (result != null) {
        final outputs = <String, String>{};
        for (final o in f.outputs) {
          outputs[o.name] = c._input(frame, result, o.name, <String, Map<String, String>>{}, body, '    ');
        }
        body.add('    return ${_map({...zeros, ...outputs})};');
      } else {
        body.add('    return ${_map(zeros)};');
      }
    } else {
      c._chain(frame, entry.id, 'exec_out', body, 2, {});
      body.add('    return ${_map(zeros)};');
    }
    final b = StringBuffer();
    b.writeln('  /// Function ${f.name}${f.pure ? ' (pure)' : ''}.');
    b.writeln('  Map<String, Object?> $method(Map<String, Object?> args) {');
    for (final i in f.inputs) {
      b.writeln('    final ${_var(i.name)} = ${_ClassWriter._argOf(LuminaBlueprintPinSpec.ofVariable(i))};');
    }
    for (final l in f.localVariables) {
      b.writeln('    ${_dartType(l.type ?? LuminaPinType.float)} ${localName(l.name)} = ${_literal(l.type ?? LuminaPinType.float, l.defaultValue)};');
    }
    for (final d in frame.declarations) {
      b.writeln('    $d');
    }
    for (final line in body) {
      b.writeln(line);
    }
    b.writeln('  }');
    // The compiler's resume methods (after a Delay inside the function) ride along.
    compiler.methods.addAll(c.methods);
    compiler.stateFields.addAll(c.stateFields);
    compiler.stateResets.addAll(c.stateResets);
    return b.toString();
  }

  /// Each Timeline node's runtime getter and its Update / Finished methods:
  /// the track values are the node's outputs for that run,
  /// traced under the node's id as the VM does.
  List<String> _timelineMembers() {
    final out = <String>[];
    for (final node in _timelines.values) {
      final getter = '_tl${_cap(_id(node.id))}';
      final outputs = [for (final p in pins[node.id]!.outputs) if (p.type != LuminaPinType.exec) p];
      final b = StringBuffer();
      b.writeln('  /// Timeline ${node.title} (node ${node.id}).');
      b.writeln('  LuminaTimeline get $getter => blueprintTimelines[${_str(node.id)}] ??= (LuminaTimeline.fromLiterals(${_json(node.literals)})');
      b.writeln('    ..onUpdate = ${getter}Update');
      b.writeln('    ..onFinished = ${getter}Finished);');
      out.add(b.toString());
      for (final pin in const ['update', 'finished']) {
        final method = '$getter${_cap(pin)}';
        final frame = _Frame(node.id, '${_id(node.id)}${_cap(pin)}', {
          for (final o in outputs)
            o.id: o.id == 'direction' ? '$getter.direction' : '(values[${_str(o.id)}] as ${_dartType(o.type)})',
        }, '', '');
        final body = <String>[];
        compiler._chain(frame, node.id, pin, body, 1, {});
        final m = StringBuffer();
        m.writeln('  void $method() {');
        m.writeln('    final values = $getter.values();');
        for (final d in frame.declarations) {
          m.writeln('    $d');
        }
        for (final line in body) {
          m.writeln('  $line');
        }
        m.writeln('  }');
        out.add(m.toString());
      }
    }
    return out;
  }
}
