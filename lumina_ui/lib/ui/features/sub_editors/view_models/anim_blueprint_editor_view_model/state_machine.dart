part of '../anim_blueprint_editor_view_model.dart';

/// Graph navigation (breadcrumbs, rule editors, selection) and editing the
/// state machine's states and transitions.
mixin _AnimBlueprintEditorStateMachine on _AnimBlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  @override
  void open(AnimGraphLocation location) {
    _location = location;
    if (location.view == AnimGraphView.state) _selectedState = location.state;
    if (location.view == AnimGraphView.transition) _selectedTransition = location.transition;
    notifyListeners();
  }

  /// The breadcrumb trail of the open graph, each with where it leads.
  List<(String, AnimGraphLocation)> get breadcrumbs {
    switch (_location.view) {
      case AnimGraphView.eventGraph:
        return [('EventGraph', const AnimGraphLocation.eventGraph())];
      case AnimGraphView.animGraph:
        return [('AnimGraph', const AnimGraphLocation.animGraph())];
      case AnimGraphView.stateMachine:
      case AnimGraphView.state:
      case AnimGraphView.transition:
        final m = _location.machine ?? '';
        final crumbs = [
          ('AnimGraph', const AnimGraphLocation.animGraph()),
          (m, AnimGraphLocation.stateMachine(m)),
        ];
        if (_location.view == AnimGraphView.state) crumbs.add((_location.state!, _location));
        if (_location.view == AnimGraphView.transition) {
          final t = transition(_location.transition!);
          crumbs.add((t == null ? _location.transition! : '${t.from} → ${t.to}', _location));
        }
        return crumbs;
    }
  }

  @override
  LuminaAnimTransition? transition(String id) => machine?.transitions.where((t) => t.id == id).firstOrNull;

  /// The canvas editor of transition [id]'s rule graph.
  @override
  BlueprintGraphEditor ruleEditor(String id) => _ruleEditors.putIfAbsent(
        id,
        () => BlueprintGraphEditor(
          host: this,
          graphSource: () => transition(id)?.rule,
          nodeFilter: AnimBlueprintEditorViewModel.ruleAccepts,
          diagnosticsSource: () => [
            for (final r in _rows)
              if (r.location?.transition == id) r.diagnostic,
          ],
        ),
      );

  void selectState(String? name) {
    _selectedState = name;
    _selectedTransition = null;
    if (name != null) _selectedVariable = null;
    notifyListeners();
  }

  void selectTransition(String? id) {
    _selectedTransition = id;
    _selectedState = null;
    if (id != null) _selectedVariable = null;
    notifyListeners();
  }

  void selectVariable(String? name) {
    _selectedVariable = name;
    if (name != null) {
      _selectedState = null;
      _selectedTransition = null;
    }
    notifyListeners();
  }

  void _replaceMachine(LuminaAnimStateMachine Function(LuminaAnimStateMachine m) change) {
    final m = machine;
    if (m == null) return;
    _document.stateMachines[0] = change(m);
  }

  LuminaAnimStateMachine _copyMachine(LuminaAnimStateMachine m, {String? entryState}) => LuminaAnimStateMachine(
        name: m.name,
        entryState: entryState ?? m.entryState,
        states: m.states,
        transitions: m.transitions,
        sampleCrossFade: m.sampleCrossFade,
      );

  String _uniqueStateName(String base) {
    var name = base;
    var n = 1;
    while (machine?.state(name) != null) {
      name = '$base${++n}';
    }
    return name;
  }

  /// Adds a state at [position] (state machine canvas units) and returns its
  /// name. The first state becomes the entry state.
  String? addState(Offset position, {String base = 'NewState'}) {
    if (machine == null) {
      final name = base;
      mutate('Add state $name', () {
        _document.stateMachines.add(LuminaAnimStateMachine(
          name: 'Locomotion',
          entryState: name,
          states: [LuminaAnimState(name, const LuminaAnimPose.hold(), x: position.dx, y: position.dy)],
          transitions: [],
        ));
        return true;
      });
      return name;
    }
    final name = _uniqueStateName(base);
    final ok = mutate('Add state $name', () {
      final m = machine!;
      m.states.add(LuminaAnimState(name, const LuminaAnimPose.hold(), x: position.dx, y: position.dy));
      if (m.state(m.entryState) == null) _replaceMachine((m) => _copyMachine(m, entryState: name));
      return true;
    });
    if (ok) {
      _selectedState = name;
      _selectedTransition = null;
      notifyListeners();
    }
    return ok ? name : null;
  }

  int _stateIndex(String name) => machine?.states.indexWhere((s) => s.name == name) ?? -1;

  bool renameState(String oldName, String newName) {
    final trimmed = newName.trim();
    final m = machine;
    if (m == null || trimmed == oldName || trimmed.isEmpty || !AnimBlueprintEditorViewModel._identifier.hasMatch(trimmed) || m.state(trimmed) != null) {
      return false;
    }
    final index = _stateIndex(oldName);
    if (index < 0) return false;
    final ok = mutate('Rename state $oldName', () {
      final s = machine!.states[index];
      machine!.states[index] = LuminaAnimState(trimmed, s.pose, x: s.x, y: s.y);
      final ts = machine!.transitions;
      for (var i = 0; i < ts.length; i++) {
        final t = ts[i];
        if (t.from == oldName || t.to == oldName) {
          ts[i] = LuminaAnimTransition(
            id: t.id,
            from: t.from == oldName ? trimmed : t.from,
            to: t.to == oldName ? trimmed : t.to,
            blendDuration: t.blendDuration,
            priority: t.priority,
            rule: t.rule,
          );
        }
      }
      if (machine!.entryState == oldName) _replaceMachine((m) => _copyMachine(m, entryState: trimmed));
      return true;
    });
    if (ok) {
      if (_selectedState == oldName) _selectedState = trimmed;
      if (_location.state == oldName) _location = AnimGraphLocation.state(_location.machine!, trimmed);
      notifyListeners();
    }
    return ok;
  }

  bool deleteState(String name) {
    final index = _stateIndex(name);
    if (index < 0) return false;
    final ok = mutate('Delete state $name', () {
      final m = machine!;
      m.states.removeAt(index);
      final gone = m.transitions.where((t) => t.from == name || t.to == name).map((t) => t.id).toSet();
      m.transitions.removeWhere((t) => gone.contains(t.id));
      if (m.entryState == name) {
        _replaceMachine((m) => _copyMachine(m, entryState: m.states.isEmpty ? '' : m.states.first.name));
      }
      return true;
    });
    if (ok && _selectedState == name) _selectedState = null;
    return ok;
  }

  void moveState(String name, Offset delta) {
    final index = _stateIndex(name);
    if (index < 0) return;
    final s = machine!.states[index];
    machine!.states[index] = LuminaAnimState(s.name, s.pose, x: s.x + delta.dx, y: s.y + delta.dy);
    notifyListeners();
  }

  bool setEntryState(String name) {
    final m = machine;
    if (m == null || m.state(name) == null || m.entryState == name) return false;
    return mutate('Set entry state $name', () {
      _replaceMachine((m) => _copyMachine(m, entryState: name));
      return true;
    });
  }

  bool setStatePose(String name, LuminaAnimPose pose) {
    final index = _stateIndex(name);
    if (index < 0) return false;
    if (jsonEncode(machine!.states[index].pose.toJson()) == jsonEncode(pose.toJson())) return false;
    return mutate('Edit pose of $name', () {
      final s = machine!.states[index];
      machine!.states[index] = LuminaAnimState(s.name, pose, x: s.x, y: s.y);
      return true;
    });
  }

  /// Adds a transition [from] → [to] whose rule starts as an unconnected
  /// Result, and returns its id.
  String? addTransition(String from, String to) {
    final m = machine;
    if (m == null || from == to || m.state(from) == null || m.state(to) == null) return null;
    if (m.transitions.any((t) => t.from == from && t.to == to)) return null;
    final base = '${from}_to_$to'.toLowerCase().replaceAll(' ', '_');
    var id = base;
    var n = 1;
    while (transition(id) != null) {
      id = '${base}_${++n}';
    }
    final ok = mutate('Add transition $from → $to', () {
      machine!.transitions.add(LuminaAnimTransition(
        id: id,
        from: from,
        to: to,
        rule: LuminaBlueprintGraph(nodes: [
          LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult, nodeId: 'result', x: 420, y: 80),
        ]),
      ));
      return true;
    });
    if (!ok) return null;
    _selectedTransition = id;
    _selectedState = null;
    notifyListeners();
    return id;
  }

  bool deleteTransition(String id) {
    final t = transition(id);
    if (t == null) return false;
    final ok = mutate('Delete transition ${t.from} → ${t.to}', () {
      machine!.transitions.removeWhere((x) => x.id == id);
      return true;
    });
    if (ok) {
      _ruleEditors.remove(id);
      if (_selectedTransition == id) _selectedTransition = null;
    }
    return ok;
  }

  bool updateTransition(String id, {double? blendDuration, int? priority}) {
    final index = machine?.transitions.indexWhere((t) => t.id == id) ?? -1;
    if (index < 0) return false;
    final t = machine!.transitions[index];
    if ((blendDuration ?? t.blendDuration) == t.blendDuration && (priority ?? t.priority) == t.priority) return false;
    return mutate('Edit transition ${t.from} → ${t.to}', () {
      machine!.transitions[index] = LuminaAnimTransition(
        id: t.id,
        from: t.from,
        to: t.to,
        blendDuration: math.max(0.0, blendDuration ?? t.blendDuration),
        priority: priority ?? t.priority,
        rule: t.rule,
      );
      return true;
    });
  }
}
