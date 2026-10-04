part of '../blueprint_editor_view_model.dart';

/// The event-graph delegates kept for the component-level API and the
/// My Blueprint variables (add, rename, retype, default, delete).
mixin _BlueprintEditorGraphAndVariables on _BlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Graph (delegates kept for the component-level API and older callers)
  // ---------------------------------------------------------------------------

  List<LuminaBlueprintNode> get graphNodes => List.unmodifiable(_document.eventGraph.nodes);
  List<LuminaBlueprintWire> get graphWires => List.unmodifiable(_document.eventGraph.wires);
  @override
  Set<String> get selectedNodeIds => eventGraph.selectedNodeIds;
  LuminaBlueprintNode? getGraphNode(String id) => _document.eventGraph.node(id);

  LuminaBlueprintNode? addGraphNode(String registryId, Offset position, {Map<String, dynamic>? literals}) =>
      eventGraph.addNode(registryId, position, literals: literals);

  bool removeGraphNode(String nodeId) => eventGraph.removeNode(nodeId);
  void removeSelectedGraphNodes() => eventGraph.removeSelected();

  LuminaBlueprintWire? addGraphWire({
    required String fromNodeId,
    required String fromPinId,
    required String toNodeId,
    required String toPinId,
  }) =>
      eventGraph.addWire(fromNodeId: fromNodeId, fromPinId: fromPinId, toNodeId: toNodeId, toPinId: toPinId);

  bool removeGraphWire(String wireId) => eventGraph.removeWire(wireId);
  void setPinLiteral(String nodeId, String pinId, dynamic value) => eventGraph.setLiteral(nodeId, pinId, value);
  void selectGraphNode(String nodeId, {bool multiSelect = false}) => eventGraph.select(nodeId, additive: multiSelect);
  void toggleSelectGraphNode(String nodeId) => eventGraph.toggle(nodeId);
  void selectGraphNodes(Set<String> nodeIds) => eventGraph.selectMany(nodeIds);
  void clearGraphSelection() => eventGraph.clearSelection();

  void moveNodes(Iterable<String> nodeIds, Offset delta) {
    eventGraph.beginMove();
    eventGraph.moveNodes(nodeIds, delta);
    eventGraph.endMove();
  }

  @override
  void _seedDefaultGraph() {
    LuminaBlueprintNode place(String id, String nodeId, double x, double y) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, x: x, y: y, context: typeContext);
    LuminaBlueprintWire wire(String id, String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    _document.eventGraph.nodes.addAll([
      place('event_beginplay', 'node_begin_play', 60, 80),
      place('print_string', 'node_print', 320, 80),
      place('event_tick', 'node_tick', 60, 260),
      place('add_movement_input', 'node_move', 320, 260),
    ]);
    _document.eventGraph.wires.addAll([
      wire('wire_begin_print', 'node_begin_play', 'exec_out', 'node_print', 'exec_in'),
      wire('wire_tick_move', 'node_tick', 'exec_tick_out', 'node_move', 'exec_move_in'),
      wire('wire_delta_scale', 'node_tick', 'delta_seconds', 'node_move', 'scale_val'),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Variables (My Blueprint)
  // ---------------------------------------------------------------------------

  String? get selectedVariable => _selectedVariable;

  void selectVariable(String? name) {
    _selectedVariable = name;
    if (name != null) _selectedComponentId = null;
    notifyListeners();
  }

  /// Adds a variable named [name] (made unique) of [type] and returns its name.
  String addVariable(String name, String type, [Object? defaultValue]) {
    var unique = name;
    var n = 1;
    while (_document.variable(unique) != null) {
      unique = '$name${++n}';
    }
    mutate('Add variable $unique', () {
      _document.variables.add(LuminaBlueprintVariable(
        name: unique,
        typeName: type,
        defaultValue: defaultValue ?? BlueprintPinStyle.defaultValueFor(type),
      ));
      return true;
    });
    _selectedVariable = unique;
    notifyListeners();
    return unique;
  }

  /// Every node graph of the document: the event graph, each function's and
  /// each macro's.
  @override
  Iterable<LuminaBlueprintGraph> get allGraphs sync* {
    yield _document.eventGraph;
    for (final f in _document.functions) {
      yield f.graph;
    }
    for (final m in _document.macros) {
      yield m.graph;
    }
  }

  /// Nodes naming variable [name] (Get / Set of the member) in any graph.
  List<LuminaBlueprintNode> nodesUsingVariable(String name) => [
        for (final g in allGraphs)
          for (final n in g.nodes)
            if ((n.registryId == LuminaBlueprintNodeLibrary.variableGet || n.registryId == LuminaBlueprintNodeLibrary.variableSet) &&
                n.literals['variable'] == name &&
                (n.literals['class'] == null ||
                    n.literals['class'] == '' ||
                    n.literals['class'] == fileBasename ||
                    n.literals['class'] == 'Actor:$fileBasename'))
              n,
      ];

  /// Removes [ids] and their wires from every graph.
  @override
  void _removeNodesEverywhere(Set<String> ids) {
    for (final g in allGraphs) {
      g.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
      g.nodes.removeWhere((n) => ids.contains(n.id));
    }
  }

  /// Renames a variable and every Get / Set node naming it, in one undo step.
  bool renameVariable(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed == oldName || !_identifier.hasMatch(trimmed) || _document.variable(trimmed) != null) return false;
    final index = _document.variables.indexWhere((v) => v.name == oldName);
    if (index < 0) return false;
    final ok = mutate('Rename variable $oldName', () {
      final v = _document.variables[index];
      _document.variables[index] = LuminaBlueprintVariable(name: trimmed, typeName: v.typeName, defaultValue: v.defaultValue);
      for (final node in nodesUsingVariable(oldName)) {
        node.literals['variable'] = trimmed;
        final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
        node.title = '${spec?.title ?? ''} $trimmed'.trim();
      }
      return true;
    });
    if (ok && _selectedVariable == oldName) _selectedVariable = trimmed;
    return ok;
  }

  /// Changes a variable's type. Its nodes re-type and the wires the new type
  /// cannot carry (a `Widget (WBP_HUD)` retyped to `Object` feeding `Get
  /// FPSCounter`) are dropped, all in one undo step.
  bool setVariableType(String name, String typeName) {
    final index = _document.variables.indexWhere((v) => v.name == name);
    if (index < 0 || _document.variables[index].typeName == typeName) return false;
    return mutate('Change type of $name', () {
      _document.variables[index] =
          LuminaBlueprintVariable(name: name, typeName: typeName, defaultValue: BlueprintPinStyle.defaultValueFor(typeName));
      for (final node in nodesUsingVariable(name)) {
        eventGraph.syncPins(node);
      }
      eventGraph.dropAllIncompatibleWires();
      for (final e in _graphEditors.values) {
        e.dropAllIncompatibleWires();
      }
      return true;
    });
  }

  bool setVariableDefault(String name, Object? value) {
    final index = _document.variables.indexWhere((v) => v.name == name);
    if (index >= 0) {
      if (jsonEncode(_document.variables[index].defaultValue) == jsonEncode(value)) return false;
      return mutate('Set default of $name', () {
        final v = _document.variables[index];
        _document.variables[index] = LuminaBlueprintVariable(name: v.name, typeName: v.typeName, defaultValue: value);
        return true;
      });
    }
    if (isInheritedVariable(name)) {
      return mutate('Override default of $name', () {
        _document.classDefaults[name] = value;
        return true;
      });
    }
    return false;
  }

  /// Deletes a variable and the nodes that use it (the panel asks first).
  bool deleteVariable(String name) {
    if (_document.variable(name) == null) return false;
    final ok = mutate('Delete variable $name', () {
      _removeNodesEverywhere({for (final n in nodesUsingVariable(name)) n.id});
      _document.variables.removeWhere((v) => v.name == name);
      return true;
    });
    if (ok && _selectedVariable == name) _selectedVariable = null;
    return ok;
  }
}

final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
