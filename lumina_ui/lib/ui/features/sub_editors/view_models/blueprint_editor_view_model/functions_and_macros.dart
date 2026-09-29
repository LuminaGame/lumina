part of '../blueprint_editor_view_model.dart';

/// The My Blueprint selection and editing of functions (signatures, local
/// variables), macros, event dispatchers and implemented interfaces.
mixin _BlueprintEditorFunctionsAndMacros on _BlueprintEditorViewModelState {

  String? get selectedFunction => _selectedFunction;
  String? get selectedMacro => _selectedMacro;
  String? get selectedDispatcher => _selectedDispatcher;

  void _selectOnly({String? function, String? macro, String? dispatcher, String? variable}) {
    _selectedFunction = function;
    _selectedMacro = macro;
    _selectedDispatcher = dispatcher;
    _selectedVariable = variable;
    if (function != null || macro != null || dispatcher != null || variable != null) _selectedComponentId = null;
    notifyListeners();
  }

  void selectFunction(String? name) => _selectOnly(function: name);
  void selectMacro(String? name) => _selectOnly(macro: name);
  void selectDispatcher(String? name) => _selectOnly(dispatcher: name);

  @override
  bool _nameTaken(String name) =>
      _document.function(name) != null ||
      _document.macro(name) != null ||
      _document.dispatcher(name) != null ||
      _document.variable(name) != null;

  // ---------------------------------------------------------------------------
  // Functions
  // ---------------------------------------------------------------------------

  /// Every `Call <name>` node of the document (any graph).
  @override
  List<LuminaBlueprintNode> nodesCallingFunction(String name) => [
        for (final g in allGraphs)
          for (final n in g.nodes)
            if ((n.registryId == LuminaBlueprintNodeLibrary.callFunction || n.registryId == LuminaBlueprintNodeLibrary.callFunctionPure) &&
                n.literals['function'] == name)
              n,
      ];

  /// + New Function: an empty graph with its entry node, opened in
  /// a tab and selected in My Blueprint. Returns the (unique) name.
  String addFunction([String name = 'NewFunction']) {
    final unique = _uniqueName(name, _nameTaken);
    mutate('Add function $unique', () {
      final fn = LuminaBlueprintFunctionGraph(name: unique);
      fn.graph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.functionEntry,
          nodeId: BlueprintGraphEditor.newId('entry'), x: 60, y: 120, context: _contextFor(function: fn)));
      _document.functions.add(fn);
      return true;
    });
    _activeGraph = BlueprintGraphRef.function(unique);
    _selectOnly(function: unique);
    return unique;
  }

  bool renameFunction(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed == oldName || !_identifier.hasMatch(trimmed) || _nameTaken(trimmed)) return false;
    final fn = _document.function(oldName);
    if (fn == null) return false;
    final ok = mutate('Rename function $oldName', () {
      _document.function(oldName)!.name = trimmed;
      for (final call in nodesCallingFunction(oldName)) {
        call.literals['function'] = trimmed;
        call.title = LuminaBlueprintNodeLibrary.displayTitle(trimmed);
      }
      return true;
    });
    if (ok) {
      final editor = _graphEditors.remove(BlueprintGraphRef.function(oldName).key);
      if (editor != null) editor.dispose();
      if (_activeGraph == BlueprintGraphRef.function(oldName)) _activeGraph = BlueprintGraphRef.function(trimmed);
      if (_selectedFunction == oldName) _selectedFunction = trimmed;
      notifyListeners();
    }
    return ok;
  }

  /// Deletes a function, its graph and every call of it (the panel asks first).
  bool deleteFunction(String name) {
    if (_document.function(name) == null) return false;
    final ok = mutate('Delete function $name', () {
      _removeNodesEverywhere({for (final n in nodesCallingFunction(name)) n.id});
      _document.functions.removeWhere((f) => f.name == name);
      return true;
    });
    if (ok) {
      _pruneGraphState();
      notifyListeners();
    }
    return ok;
  }

  /// Re-resolves the pins of the function's entry / result nodes and of
  /// every call of it, dropping wires the new signature cannot carry.
  void _syncFunctionNodes(String name) {
    final fn = _document.function(name);
    if (fn == null) return;
    final editor = graphEditor(BlueprintGraphRef.function(name));
    for (final n in fn.graph.nodes) {
      if (n.registryId == LuminaBlueprintNodeLibrary.functionEntry || n.registryId == LuminaBlueprintNodeLibrary.functionResult) {
        editor.syncPins(n);
      }
    }
    editor.dropAllIncompatibleWires();
    _syncCallNodes(nodesCallingFunction(name));
  }

  void _syncCallNodes(List<LuminaBlueprintNode> calls) {
    if (calls.isEmpty) return;
    final ids = {for (final c in calls) c.id};
    for (final ref in graphs) {
      if (!ref.hasGraph) continue;
      final editor = graphEditor(ref);
      var touched = false;
      for (final n in editor.nodes) {
        if (ids.contains(n.id)) {
          editor.syncPins(n);
          touched = true;
        }
      }
      if (touched) editor.dropAllIncompatibleWires();
    }
  }

  bool _sameVariables(List<LuminaBlueprintVariable> a, List<LuminaBlueprintVariable> b) =>
      jsonEncode(a.map((v) => v.toJson()).toList()) == jsonEncode(b.map((v) => v.toJson()).toList());

  /// Sets the function's inputs: the entry node's outputs and every call's
  /// inputs follow, in one undo step.
  bool setFunctionInputs(String name, List<LuminaBlueprintVariable> inputs) {
    final fn = _document.function(name);
    if (fn == null || _sameVariables(fn.inputs, inputs)) return false;
    return mutate('Edit inputs of $name', () {
      _document.function(name)!.inputs
        ..clear()
        ..addAll(inputs);
      _syncFunctionNodes(name);
      return true;
    });
  }

  /// Sets the function's outputs: a Return Node is added when the function
  /// gains its first output; the result node and every call follow.
  bool setFunctionOutputs(String name, List<LuminaBlueprintVariable> outputs) {
    final fn = _document.function(name);
    if (fn == null || _sameVariables(fn.outputs, outputs)) return false;
    return mutate('Edit outputs of $name', () {
      final target = _document.function(name)!;
      target.outputs
        ..clear()
        ..addAll(outputs);
      if (outputs.isNotEmpty && !target.graph.nodes.any((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult)) {
        final entry = target.graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry).firstOrNull;
        final right = target.graph.nodes.fold<double>(0, (m, n) => math.max(m, n.x));
        target.graph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.functionResult,
            nodeId: BlueprintGraphEditor.newId('result'), x: right + 320, y: entry?.y ?? 120, context: _contextFor(function: target)));
      }
      _syncFunctionNodes(name);
      return true;
    });
  }

  /// Marks the function pure (callable from data chains, no exec pins):
  /// every call becomes the pure node, keeping its data wires.
  bool setFunctionPure(String name, bool pure) {
    final fn = _document.function(name);
    if (fn == null || fn.pure == pure) return false;
    return mutate(pure ? 'Make $name pure' : 'Make $name impure', () {
      _document.function(name)!.pure = pure;
      for (final g in allGraphs) {
        for (final n in g.nodes) {
          if ((n.registryId == LuminaBlueprintNodeLibrary.callFunction || n.registryId == LuminaBlueprintNodeLibrary.callFunctionPure) &&
              n.literals['function'] == name) {
            final replacement = LuminaBlueprintNodeLibrary.place(
              pure ? LuminaBlueprintNodeLibrary.callFunctionPure : LuminaBlueprintNodeLibrary.callFunction,
              nodeId: n.id,
              x: n.x,
              y: n.y,
              literals: n.literals,
              context: _contextFor(),
            );
            g.nodes[g.nodes.indexOf(n)] = replacement;
          }
        }
      }
      _syncFunctionNodes(name);
      return true;
    });
  }

  bool setFunctionCategory(String name, String category) {
    final fn = _document.function(name);
    if (fn == null || fn.category == category) return false;
    return mutate('Set category of $name', () {
      _document.function(name)!.category = category;
      return true;
    });
  }

  /// Adds a local variable to function [function]; returns its unique name.
  String addLocalVariable(String function, [String name = 'NewLocalVar', String type = 'Float']) {
    final fn = _document.function(function);
    if (fn == null) return name;
    final unique = _uniqueName(name, (n) => fn.localVariable(n) != null);
    mutate('Add local variable $unique', () {
      _document.function(function)!.localVariables.add(
          LuminaBlueprintVariable(name: unique, typeName: type, defaultValue: BlueprintPinStyle.defaultValueFor(type)));
      return true;
    });
    return unique;
  }

  /// Nodes of [function]'s graph naming local variable [name].
  List<LuminaBlueprintNode> nodesUsingLocalVariable(String function, String name) => [
        for (final n in _document.function(function)?.graph.nodes ?? const <LuminaBlueprintNode>[])
          if ((n.registryId == LuminaBlueprintNodeLibrary.localVariableGet || n.registryId == LuminaBlueprintNodeLibrary.localVariableSet) &&
              n.literals['variable'] == name)
            n,
      ];

  bool renameLocalVariable(String function, String oldName, String newName) {
    final fn = _document.function(function);
    final trimmed = newName.trim();
    if (fn == null || trimmed == oldName || !_identifier.hasMatch(trimmed) || fn.localVariable(trimmed) != null) return false;
    final index = fn.localVariables.indexWhere((v) => v.name == oldName);
    if (index < 0) return false;
    return mutate('Rename local variable $oldName', () {
      final target = _document.function(function)!;
      final v = target.localVariables[index];
      target.localVariables[index] = LuminaBlueprintVariable(name: trimmed, typeName: v.typeName, defaultValue: v.defaultValue);
      for (final n in nodesUsingLocalVariable(function, oldName)) {
        n.literals['variable'] = trimmed;
        n.title = '${LuminaBlueprintNodeLibrary.spec(n.registryId)?.title ?? ''} $trimmed'.trim();
      }
      return true;
    });
  }

  bool setLocalVariableType(String function, String name, String typeName) {
    final fn = _document.function(function);
    if (fn == null) return false;
    final index = fn.localVariables.indexWhere((v) => v.name == name);
    if (index < 0 || fn.localVariables[index].typeName == typeName) return false;
    return mutate('Change type of $name', () {
      final target = _document.function(function)!;
      target.localVariables[index] =
          LuminaBlueprintVariable(name: name, typeName: typeName, defaultValue: BlueprintPinStyle.defaultValueFor(typeName));
      final editor = graphEditor(BlueprintGraphRef.function(function));
      for (final n in nodesUsingLocalVariable(function, name)) {
        editor.syncPins(n);
      }
      editor.dropAllIncompatibleWires();
      return true;
    });
  }

  bool deleteLocalVariable(String function, String name) {
    final fn = _document.function(function);
    if (fn == null || fn.localVariable(name) == null) return false;
    return mutate('Delete local variable $name', () {
      final target = _document.function(function)!;
      final ids = {for (final n in nodesUsingLocalVariable(function, name)) n.id};
      target.graph.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
      target.graph.nodes.removeWhere((n) => ids.contains(n.id));
      target.localVariables.removeWhere((v) => v.name == name);
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Macros
  // ---------------------------------------------------------------------------

  @override
  List<LuminaBlueprintNode> nodesCallingMacro(String name) => [
        for (final g in allGraphs)
          for (final n in g.nodes)
            if (n.registryId == LuminaBlueprintNodeLibrary.callMacro && n.literals['macro'] == name) n,
      ];

  /// + New Macro: a body with Inputs / Outputs nodes carrying one exec pin
  /// each, opened in a tab.
  String addMacro([String name = 'NewMacro']) {
    final unique = _uniqueName(name, _nameTaken);
    mutate('Add macro $unique', () {
      final macro = LuminaBlueprintMacroGraph(
        name: unique,
        inputs: [const LuminaBlueprintVariable(name: 'Exec', typeName: 'Exec')],
        outputs: [const LuminaBlueprintVariable(name: 'Then', typeName: 'Exec')],
      );
      final context = _contextFor(macro: macro);
      macro.graph.nodes
        ..add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.macroInput,
            nodeId: BlueprintGraphEditor.newId('inputs'), x: 60, y: 120, context: context))
        ..add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.macroOutput,
            nodeId: BlueprintGraphEditor.newId('outputs'), x: 420, y: 120, context: context));
      _document.macros.add(macro);
      return true;
    });
    _activeGraph = BlueprintGraphRef.macro(unique);
    _selectOnly(macro: unique);
    return unique;
  }

  bool renameMacro(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed == oldName || !_identifier.hasMatch(trimmed) || _nameTaken(trimmed)) return false;
    if (_document.macro(oldName) == null) return false;
    final ok = mutate('Rename macro $oldName', () {
      _document.macro(oldName)!.name = trimmed;
      for (final call in nodesCallingMacro(oldName)) {
        call.literals['macro'] = trimmed;
        call.title = LuminaBlueprintNodeLibrary.displayTitle(trimmed);
      }
      return true;
    });
    if (ok) {
      _graphEditors.remove(BlueprintGraphRef.macro(oldName).key)?.dispose();
      if (_activeGraph == BlueprintGraphRef.macro(oldName)) _activeGraph = BlueprintGraphRef.macro(trimmed);
      if (_selectedMacro == oldName) _selectedMacro = trimmed;
      notifyListeners();
    }
    return ok;
  }

  bool deleteMacro(String name) {
    if (_document.macro(name) == null) return false;
    final ok = mutate('Delete macro $name', () {
      _removeNodesEverywhere({for (final n in nodesCallingMacro(name)) n.id});
      _document.macros.removeWhere((m) => m.name == name);
      return true;
    });
    if (ok) {
      _pruneGraphState();
      notifyListeners();
    }
    return ok;
  }

  void _syncMacroNodes(String name) {
    final macro = _document.macro(name);
    if (macro == null) return;
    final editor = graphEditor(BlueprintGraphRef.macro(name));
    for (final n in macro.graph.nodes) {
      if (n.registryId == LuminaBlueprintNodeLibrary.macroInput || n.registryId == LuminaBlueprintNodeLibrary.macroOutput) {
        editor.syncPins(n);
      }
    }
    editor.dropAllIncompatibleWires();
    _syncCallNodes(nodesCallingMacro(name));
  }

  /// Sets a macro's inputs (`Exec` typed pins are exec pins).
  bool setMacroInputs(String name, List<LuminaBlueprintVariable> inputs) {
    final macro = _document.macro(name);
    if (macro == null || _sameVariables(macro.inputs, inputs)) return false;
    return mutate('Edit inputs of $name', () {
      _document.macro(name)!.inputs
        ..clear()
        ..addAll(inputs);
      _syncMacroNodes(name);
      return true;
    });
  }

  bool setMacroOutputs(String name, List<LuminaBlueprintVariable> outputs) {
    final macro = _document.macro(name);
    if (macro == null || _sameVariables(macro.outputs, outputs)) return false;
    return mutate('Edit outputs of $name', () {
      _document.macro(name)!.outputs
        ..clear()
        ..addAll(outputs);
      _syncMacroNodes(name);
      return true;
    });
  }

  List<LuminaBlueprintNode> nodesUsingDispatcher(String name) => [
        for (final g in allGraphs)
          for (final n in g.nodes)
            if (_dispatcherNodes.contains(n.registryId) && n.literals['dispatcher'] == name) n,
      ];

  /// + New Event Dispatcher; returns its unique name.
  String addDispatcher([String name = 'NewEventDispatcher']) {
    final unique = _uniqueName(name, _nameTaken);
    mutate('Add dispatcher $unique', () {
      _document.dispatchers.add(LuminaBlueprintDispatcher(name: unique));
      return true;
    });
    _selectOnly(dispatcher: unique);
    return unique;
  }

  bool renameDispatcher(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed == oldName || !_identifier.hasMatch(trimmed) || _nameTaken(trimmed)) return false;
    if (_document.dispatcher(oldName) == null) return false;
    final ok = mutate('Rename dispatcher $oldName', () {
      _document.dispatcher(oldName)!.name = trimmed;
      for (final n in nodesUsingDispatcher(oldName)) {
        n.literals['dispatcher'] = trimmed;
        final probe = LuminaBlueprintNodeLibrary.place(n.registryId, nodeId: '_probe', literals: n.literals, context: _contextFor());
        n.title = probe.title;
      }
      return true;
    });
    if (ok && _selectedDispatcher == oldName) _selectedDispatcher = trimmed;
    return ok;
  }

  bool deleteDispatcher(String name) {
    if (_document.dispatcher(name) == null) return false;
    final ok = mutate('Delete dispatcher $name', () {
      _removeNodesEverywhere({for (final n in nodesUsingDispatcher(name)) n.id});
      _document.dispatchers.removeWhere((d) => d.name == name);
      return true;
    });
    if (ok && _selectedDispatcher == name) _selectedDispatcher = null;
    return ok;
  }

  /// Sets a dispatcher's parameters: every Call of it re-resolves.
  bool setDispatcherParameters(String name, List<LuminaBlueprintVariable> parameters) {
    final d = _document.dispatcher(name);
    if (d == null || _sameVariables(d.parameters, parameters)) return false;
    return mutate('Edit parameters of $name', () {
      _document.dispatcher(name)!.parameters
        ..clear()
        ..addAll(parameters);
      _syncCallNodes(nodesUsingDispatcher(name));
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Interfaces
  // ---------------------------------------------------------------------------

  /// Implements interface [name] (Class Defaults → Interfaces → Add): its
  /// functions become `Event <Function>` rows in the palette.
  bool addInterface(String name) {
    if (name.isEmpty || _document.interfaces.contains(name)) return false;
    return mutate('Implement $name', () {
      _document.interfaces.add(name);
      return true;
    });
  }

  /// Stops implementing [name]; its interface event nodes are removed.
  bool removeInterface(String name) {
    if (!_document.interfaces.contains(name)) return false;
    return mutate('Remove $name', () {
      _removeNodesEverywhere({
        for (final g in allGraphs)
          for (final n in g.nodes)
            if (n.registryId == LuminaBlueprintNodeLibrary.eventInterfaceFunction && n.literals['interface'] == name) n.id,
      });
      _document.interfaces.remove(name);
      return true;
    });
  }
}

String _uniqueName(String base, bool Function(String) taken) {
  var unique = base;
  for (var n = 2; taken(unique); n++) {
    unique = '$base$n';
  }
  return unique;
}

// ---------------------------------------------------------------------------
// Event dispatchers
// ---------------------------------------------------------------------------

const Set<String> _dispatcherNodes = {
  LuminaBlueprintNodeLibrary.callDispatcher,
  LuminaBlueprintNodeLibrary.bindEventToDispatcher,
  LuminaBlueprintNodeLibrary.unbindEventFromDispatcher,
  LuminaBlueprintNodeLibrary.unbindAllEvents,
};
