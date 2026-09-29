part of '../anim_blueprint_editor_view_model.dart';

/// Anim Blueprint variables (add, rename, retype, default, delete) and
/// compiling with its diagnostic rows.
mixin _AnimBlueprintEditorVariablesAndCompile on _AnimBlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Variables
  // ---------------------------------------------------------------------------

  Iterable<LuminaBlueprintGraph> get _allGraphs sync* {
    yield _document.eventGraph;
    for (final m in _document.stateMachines) {
      for (final t in m.transitions) {
        yield t.rule;
      }
    }
  }

  List<LuminaBlueprintNode> nodesUsingVariable(String name) => [
        for (final g in _allGraphs)
          for (final n in g.nodes)
            if (n.literals['variable'] == name) n,
      ];

  String addVariable(String name, String typeName, [Object? defaultValue]) {
    var unique = name;
    var n = 1;
    while (_document.variables.any((v) => v.name == unique)) {
      unique = '$name${++n}';
    }
    mutate('Add variable $unique', () {
      _document.variables.add(LuminaBlueprintVariable(
          name: unique, typeName: typeName, defaultValue: defaultValue ?? BlueprintPinStyle.defaultValueFor(typeName)));
      return true;
    });
    _selectedVariable = unique;
    notifyListeners();
    return unique;
  }

  LuminaAnimPose _renamedPose(LuminaAnimPose p, String? Function(String? v) rename) {
    if (p.kind != LuminaAnimPoseKind.blendSpace) return p;
    return LuminaAnimPose.blendSpace(
      p.blendSpace!,
      xVariable: rename(p.xVariable) ?? '',
      yVariable: rename(p.yVariable),
      rate: p.rate,
      rateVariable: rename(p.rateVariable),
      rateReference: p.rateReference,
      minRate: p.minRate,
      maxRate: p.maxRate,
    );
  }

  void _renamePoses(String? Function(String? v) rename) {
    for (final m in _document.stateMachines) {
      for (var i = 0; i < m.states.length; i++) {
        final s = m.states[i];
        m.states[i] = LuminaAnimState(s.name, _renamedPose(s.pose, rename), x: s.x, y: s.y);
      }
    }
  }

  bool renameVariable(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed == oldName ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(trimmed) ||
        _document.variables.any((v) => v.name == trimmed)) {
      return false;
    }
    final index = _document.variables.indexWhere((v) => v.name == oldName);
    if (index < 0) return false;
    final ok = mutate('Rename variable $oldName', () {
      final v = _document.variables[index];
      _document.variables[index] = LuminaBlueprintVariable(name: trimmed, typeName: v.typeName, defaultValue: v.defaultValue);
      for (final node in nodesUsingVariable(oldName)) {
        node.literals['variable'] = trimmed;
        node.title = '${LuminaBlueprintNodeLibrary.spec(node.registryId)?.title ?? ''} $trimmed'.trim();
      }
      _renamePoses((v) => v == oldName ? trimmed : v);
      return true;
    });
    if (ok) {
      if (_overrides.containsKey(oldName)) _overrides[trimmed] = _overrides.remove(oldName);
      if (_selectedVariable == oldName) _selectedVariable = trimmed;
      notifyListeners();
    }
    return ok;
  }

  bool setVariableType(String name, String typeName) {
    final index = _document.variables.indexWhere((v) => v.name == name);
    if (index < 0 || _document.variables[index].typeName == typeName) return false;
    final ok = mutate('Change type of $name', () {
      _document.variables[index] =
          LuminaBlueprintVariable(name: name, typeName: typeName, defaultValue: BlueprintPinStyle.defaultValueFor(typeName));
      for (final g in _allGraphs) {
        for (final n in g.nodes) {
          if (n.literals['variable'] == name) {
            final pins = LuminaBlueprintNodeLibrary.pinsOf(n, typeContext);
            if (pins == null) continue;
            n.inputs
              ..clear()
              ..addAll(pins.inputs.map((p) => p.toPin(isOutput: false)));
            n.outputs
              ..clear()
              ..addAll(pins.outputs.map((p) => p.toPin(isOutput: true)));
          }
        }
      }
      return true;
    });
    if (ok) _overrides.remove(name);
    return ok;
  }

  bool setVariableDefault(String name, Object? value) {
    final index = _document.variables.indexWhere((v) => v.name == name);
    if (index < 0 || jsonEncode(_document.variables[index].defaultValue) == jsonEncode(value)) return false;
    return mutate('Set default of $name', () {
      final v = _document.variables[index];
      _document.variables[index] = LuminaBlueprintVariable(name: v.name, typeName: v.typeName, defaultValue: value);
      return true;
    });
  }

  bool deleteVariable(String name) {
    if (!_document.variables.any((v) => v.name == name)) return false;
    final ok = mutate('Delete variable $name', () {
      for (final g in _allGraphs) {
        final ids = {for (final n in g.nodes) if (n.literals['variable'] == name) n.id};
        g.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
        g.nodes.removeWhere((n) => ids.contains(n.id));
      }
      _renamePoses((v) => v == name ? null : v);
      _document.variables.removeWhere((v) => v.name == name);
      return true;
    });
    if (ok) {
      _overrides.remove(name);
      if (_selectedVariable == name) _selectedVariable = null;
    }
    return ok;
  }

  AnimGraphLocation? _locate(LuminaBlueprintDiagnostic d) {
    final m = machine;
    final match = RegExp(r"^Transition '([^']+)'").firstMatch(d.message);
    if (match != null && m != null) return AnimGraphLocation.transition(m.name, match.group(1)!);
    if (d.nodeId != null && _document.eventGraph.node(d.nodeId!) != null) return const AnimGraphLocation.eventGraph();
    final state = RegExp(r"^State '([^']+)'").firstMatch(d.message);
    if (state != null && m != null) return AnimGraphLocation.state(m.name, state.group(1)!);
    return m == null ? null : AnimGraphLocation.stateMachine(m.name);
  }

  String? _nodeTitle(LuminaBlueprintDiagnostic d, AnimGraphLocation? at) {
    if (d.nodeId == null) return null;
    if (at?.view == AnimGraphView.transition) return transition(at!.transition!)?.rule.node(d.nodeId!)?.title;
    return _document.eventGraph.node(d.nodeId!)?.title;
  }

  /// Compile: lumina's `validateAnimBlueprint` through
  /// `BlueprintDartGenerator.generateAnimBlueprint`, plus the editor's own
  /// check that every transition's Result is connected. A clean result is
  /// written to `lib/anim/<ABP>.dart`, where a project compile puts it.
  Future<bool> compile() async {
    _reloadBlendSpaces();
    final issues = <LuminaBlueprintDiagnostic>[];
    final m = machine;
    for (final t in m?.transitions ?? const <LuminaAnimTransition>[]) {
      final result = t.resultNode;
      if (result == null) continue;
      if (t.rule.wireInto(result.id, 'can_enter') == null && result.literals['can_enter'] != true) {
        issues.add(LuminaBlueprintDiagnostic(
          LuminaBlueprintSeverity.error,
          "Transition '${t.id}' (${t.from} → ${t.to}): the Result is not connected, so the transition is never taken.",
          nodeId: result.id,
          pinId: 'can_enter',
        ));
      }
    }
    final dir = projectDir;
    if (dir != null) LuminaGeneratedCodeMigration.migrate(dir);
    final file = dir == null ? null : File('$dir/lib/anim/${dartFileName(name)}');
    final existing = file != null && file.existsSync() ? file.readAsStringSync() : null;
    final result = const BlueprintDartGenerator().generateAnimBlueprint(
      _document,
      className: AnimBlueprintEditorViewModel.className(name),
      assetPath: relativePath,
      blendSpaces: stateBlendSpaces,
      existingContent: existing,
    );
    issues.addAll(result.issues);
    final ok = result.ok && !issues.any((d) => d.isError);
    _generatedCode = result.code ?? '';
    if (ok && file != null && existing != result.code) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(result.code!);
    }
    _rows = [
      for (final d in issues)
        () {
          final at = _locate(d);
          return AnimCompileRow(d, at, _nodeTitle(d, at));
        }(),
    ];
    _compileStatus = issues.any((d) => d.isError)
        ? BlueprintCompileStatus.error
        : issues.isNotEmpty
            ? BlueprintCompileStatus.warning
            : BlueprintCompileStatus.upToDate;
    EngineLoggerService().log('Compiled $name: ${_compileStatus.label}',
        level: _compileStatus == BlueprintCompileStatus.error ? 'error' : 'success');
    _previewRevision = -1;
    notifyListeners();
    eventGraph.documentChanged();
    for (final e in _ruleEditors.values) {
      e.documentChanged();
    }
    return ok;
  }

  /// Opens the graph a Compiler Results row points at and frames its node.
  void openRow(AnimCompileRow row) {
    final at = row.location;
    if (at == null) return;
    open(at);
    final nodeId = row.diagnostic.nodeId;
    if (nodeId == null) return;
    final editor = at.view == AnimGraphView.transition ? ruleEditor(at.transition!) : eventGraph;
    editor.select(nodeId);
    editor.focusNode(nodeId);
  }
}
