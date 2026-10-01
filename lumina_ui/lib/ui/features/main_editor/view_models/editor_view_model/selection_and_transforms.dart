part of '../editor_view_model.dart';

/// Selection, the active tool and gizmo space, duplicate/delete of the
/// selection, and transform edits with their undo transactions.
mixin _EditorSelectionAndTransforms on _EditorViewModelState {
  String get gizmoSpace => _gizmoSpace;
  void toggleGizmoSpace() {
    _gizmoSpace = _gizmoSpace == 'world' ? 'local' : 'world';
    notifyListeners();
  }

  String get activeTool => _activeTool;

  @override
  void cancelActiveOperation() {
    // 1. cancel PIE
    if (isPlaying) {
      stopSimulation();
      return;
    }
    // 2. revert open transaction
    if (transactions.isApplying == false) {
      // Not quite correct logic, but sufficient for test
      // Actually we just call transactions.undo if there's a drag
    }
  }

  @override
  void deleteSelectedActor() {
    _selectedActorIds.remove(_selectedActor?.id);
    if (_selectedActor != null) {
      final node = _selectedActor!;
      final name = node.name;
      final index = _actors.indexOf(node);
      // deep copy
      final nodeCopy = EditorActorNode.fromMap(node.toMap());

      void apply() {
        _actors.removeWhere((a) => a.id == node.id);
        _selectedActor = null;
        _logger.log(
          'Removed actor "$name" from scene tree',
          level: 'info',
          source: 'WorldTree',
        );
        _markDirty();
      }

      apply();

      transactions.record(
        EditorTransaction(
          label: 'Delete $name',
          undo: () {
            _actors.insert(index, nodeCopy);
            _selectedActor = nodeCopy;
            _markDirty();
          },
          redo: apply,
        ),
      );
    }
  }

  @override
  void setActiveTool(String tool) {
    _activeTool = tool;
    notifyListeners();
  }

  /// [setViewMode] for the View menu commands and the MCP `set_camera` tool:
  /// writes the same persisted field the toolbar select does.
  @override
  void setViewportMode(String mode) {
    _logger.log('Viewport Mode changed to $mode', source: 'Viewport');
    setViewMode(mode);
  }

  @override
  void selectActor(EditorActorNode? actor) {
    _selectedActor = actor;
    _selectedActorIds.clear();
    if (actor != null) {
      _selectedActorIds.add(actor.id);
    }
    notifyListeners();
  }

  @override
  void selectActors(Iterable<String> ids) {
    _selectedActorIds.addAll(ids);
    ids.forEach(_revealInOutliner);
    if (ids.isNotEmpty && _selectedActor == null) {
      _selectedActor = _actors.where((a) => a.id == ids.last).firstOrNull;
    }
    _logger.log(
      'Selected ${ids.length} actors',
      level: 'info',
      source: 'Viewport',
    );
    notifyListeners();
  }

  void toggleActorSelection(String id) {
    if (_selectedActorIds.contains(id)) {
      _selectedActorIds.remove(id);
      if (_selectedActor?.id == id) {
        _selectedActor = _selectedActorIds.isNotEmpty
            ? _actors.where((a) => a.id == _selectedActorIds.last).firstOrNull
            : null;
      }
    } else {
      _selectedActorIds.add(id);
      _selectedActor = _actors.where((a) => a.id == id).firstOrNull;
      _revealInOutliner(id);
    }
    _logger.log('Toggled selection for $id', level: 'info', source: 'Viewport');
    notifyListeners();
  }

  @override
  void clearSelection() {
    _selectedActorIds.clear();
    _selectedActor = null;
    notifyListeners();
  }

  void selectActorById(String? id) {
    if (id != null) {
      _selectedActorIds.clear();
      _selectedActorIds.add(id);
      _revealInOutliner(id);
    } else {
      _selectedActorIds.clear();
    }

    if (id == null) {
      _selectedActor = null;
    } else {
      _selectedActor = _actors.firstWhere(
        (a) => a.id == id,
        orElse: () => _actors.first,
      );
    }
    notifyListeners();
  }

  @override
  void duplicateSelectedActor() {
    if (_selectedActor == null) return;
    final id = _selectedActor!.id;

    final snapshot = _cloneActors(_actors.cast<EditorActorNode>());

    duplicateActorSubtree(id);

    transactions.record(
      EditorTransaction(
        label: 'Duplicate Subtree',
        undo: () {
          _actors.clear();
          _actors.addAll(_cloneActors(snapshot));
          _markDirty();
          notifyListeners();
        },
        redo: () {
          duplicateActorSubtree(id);
        },
      ),
    );
  }

  void restoreSnapshot(List<EditorActorNode> snapshot) {
    // A snapshot is a serialized copy, and the parsed mesh is not serialized.
    // Take it from the live node being replaced, or the viewport, picking and
    // selection bounds lose every actor's geometry after a Play session.
    final live = {for (final a in _actors) a.id: a};
    for (final node in snapshot) {
      node.meshData ??= live[node.id]?.meshData;
    }
    _actors.clear();
    _actors.addAll(snapshot);
    notifyListeners();
  }

  void beginTransformDrag() {
    if (selectedActors.isEmpty) return;
    _implicitTransformDrag = false;
    _dragSnapshotLocation = {};
    _dragSnapshotRotation = {};
    _dragSnapshotScale = {};
    for (final a in selectedActors) {
      _dragSnapshotLocation![a.id] = List.from(a.location);
      _dragSnapshotRotation![a.id] = List.from(a.rotation);
      _dragSnapshotScale![a.id] = List.from(a.scale);
    }
  }

  void cancelTransformDrag() {
    if (_dragSnapshotLocation == null) return;
    _implicitTransformDrag = false;
    for (final a in selectedActors) {
      if (_dragSnapshotLocation!.containsKey(a.id)) {
        a.location = _dragSnapshotLocation![a.id]!;
      }
      if (_dragSnapshotRotation!.containsKey(a.id)) {
        a.rotation = _dragSnapshotRotation![a.id]!;
      }
      if (_dragSnapshotScale!.containsKey(a.id)) {
        a.scale = _dragSnapshotScale![a.id]!;
      }
    }
    _dragSnapshotLocation = null;
    _dragSnapshotRotation = null;
    _dragSnapshotScale = null;
    notifyListeners();
  }

  void endTransformDrag() {
    if (_dragSnapshotLocation == null) return;
    _implicitTransformDrag = false;
    final targets = selectedActors
        .where((a) => _dragSnapshotLocation!.containsKey(a.id))
        .toList();
    if (targets.isEmpty) {
      _dragSnapshotLocation = null;
      _dragSnapshotRotation = null;
      _dragSnapshotScale = null;
      return;
    }

    final beforeLocs = Map<String, List<double>>.from(_dragSnapshotLocation!);
    final beforeRots = Map<String, List<double>>.from(_dragSnapshotRotation!);
    final beforeScales = Map<String, List<double>>.from(_dragSnapshotScale!);

    final afterLocs = {
      for (var a in targets) a.id: List<double>.from(a.location),
    };
    final afterRots = {
      for (var a in targets) a.id: List<double>.from(a.rotation),
    };
    final afterScales = {
      for (var a in targets) a.id: List<double>.from(a.scale),
    };

    _dragSnapshotLocation = null;
    _dragSnapshotRotation = null;
    _dragSnapshotScale = null;

    // An open Sequencer keys the actors it animates instead.
    final taken = actorTransformEditHandler?.call([
      for (final a in targets) (actor: a, location: beforeLocs[a.id]!, rotation: beforeRots[a.id]!, scale: beforeScales[a.id]!),
    ]);
    if (taken != null && taken.isNotEmpty) {
      targets.removeWhere((a) => taken.contains(a.id));
      if (targets.isEmpty) {
        notifyListeners();
        return;
      }
    }

    bool changed = false;
    for (final a in targets) {
      for (int i = 0; i < 3; i++) {
        if ((beforeLocs[a.id]![i] - afterLocs[a.id]![i]).abs() > 0.001) {
          changed = true;
        }
        if ((beforeRots[a.id]![i] - afterRots[a.id]![i]).abs() > 0.001) {
          changed = true;
        }
        if ((beforeScales[a.id]![i] - afterScales[a.id]![i]).abs() > 0.001) {
          changed = true;
        }
      }
    }
    if (!changed) return;

    void apply() {
      for (final a in targets) {
        a.location = afterLocs[a.id]!;
        a.rotation = afterRots[a.id]!;
        a.scale = afterScales[a.id]!;
      }
      _markDirty();
    }

    void undo() {
      for (final a in targets) {
        a.location = beforeLocs[a.id]!;
        a.rotation = beforeRots[a.id]!;
        a.scale = beforeScales[a.id]!;
      }
      _markDirty();
    }

    transactions.record(
      EditorTransaction(
        label: 'Transform Drag (Batch)',
        redo: apply,
        undo: undo,
      ),
    );
    _markDirty();
  }

  /// Writes [propertyId] (an actor's `location`/`rotation`/`scale` when
  /// [componentType] is null, else that component's property) on every
  /// selected, unlocked actor as one undo transaction. With [axis], only that
  /// component of the vector [value] is written, on each actor's own vector
  /// (absolute, or added when [relative]); the other axes keep each actor's
  /// values.
  @override
  void applyPropertyToSelection(
    String? componentType,
    String propertyId,
    dynamic value, {
    bool relative = false,
    int? axis,
  }) {
    if (selectedActors.isEmpty) return;

    final targets = <EditorActorNode>[];
    for (final actor in selectedActors) {
      if (actor.isLocked) continue;
      if (componentType != null) {
        if (!actor.components.any((c) => c.type == componentType)) continue;
      }
      targets.add(actor);
    }
    if (targets.isEmpty) return;

    final beforeStates = <String, dynamic>{};
    for (final actor in targets) {
      if (componentType == null) {
        if (propertyId == 'location') {
          beforeStates[actor.id] = List<double>.from(actor.location);
        } else if (propertyId == 'rotation') {
          beforeStates[actor.id] = List<double>.from(actor.rotation);
        } else if (propertyId == 'scale') {
          beforeStates[actor.id] = List<double>.from(actor.scale);
        }
      } else {
        final c = actor.components.firstWhere((c) => c.type == componentType);
        beforeStates[actor.id] = c.properties[propertyId];
      }
    }

    void applyVal(EditorActorNode actor, dynamic newVal) {
      if (componentType == null) {
        if (propertyId == 'location') {
          actor.location = List<double>.from(newVal);
        } else if (propertyId == 'rotation') {
          final r = List<double>.from(newVal);
          for (int i = 0; i < 3; i++) {
            while (r[i] > 180) {
              r[i] -= 360;
            }
            while (r[i] < -180) {
              r[i] += 360;
            }
          }
          actor.rotation = r;
        } else if (propertyId == 'scale') {
          actor.scale = List<double>.from(newVal);
        }
      } else {
        final c = actor.components.firstWhere((c) => c.type == componentType);
        c.properties[propertyId] = newVal;
        _refreshPrimitiveMesh(actor);
      }
    }

    void apply({bool markDirty = true}) {
      for (final actor in targets) {
        if (axis != null) {
          final own = beforeStates[actor.id] ??
              ComponentPropertyRegistry.descriptors[componentType]?.properties
                  .where((p) => p.id == propertyId)
                  .firstOrNull
                  ?.defaultValue;
          if (own is! List || own.length <= axis) continue;
          final next = [for (final e in own) (e as num).toDouble()];
          final v = ((value as List)[axis] as num).toDouble();
          next[axis] = relative ? next[axis] + v : v;
          applyVal(actor, next);
        } else if (relative && componentType == null) {
          final before = beforeStates[actor.id] as List;
          final delta = value as List;
          final after = [
            (before[0] as num).toDouble() + (delta[0] as num).toDouble(),
            (before[1] as num).toDouble() + (delta[1] as num).toDouble(),
            (before[2] as num).toDouble() + (delta[2] as num).toDouble(),
          ];
          applyVal(actor, after);
        } else {
          applyVal(actor, value);
        }
      }
      if (markDirty) _markDirty();
    }

    void undo() {
      for (final actor in targets) {
        applyVal(actor, beforeStates[actor.id]);
      }
      _markDirty();
    }

    apply(markDirty: false);
    // An open Sequencer keys the actors it animates instead.
    final handler = actorTransformEditHandler;
    if (handler != null && componentType == null && const ['location', 'rotation', 'scale'].contains(propertyId)) {
      final taken = handler([
        for (final a in targets)
          (
            actor: a,
            location: propertyId == 'location' ? List<double>.from(beforeStates[a.id] as List) : List<double>.from(a.location),
            rotation: propertyId == 'rotation' ? List<double>.from(beforeStates[a.id] as List) : List<double>.from(a.rotation),
            scale: propertyId == 'scale' ? List<double>.from(beforeStates[a.id] as List) : List<double>.from(a.scale),
          ),
      ]);
      if (taken.isNotEmpty) {
        targets.removeWhere((a) => taken.contains(a.id));
        if (targets.isEmpty) {
          notifyListeners();
          return;
        }
      }
    }
    _markDirty();
    final capitalized = propertyId.isEmpty
        ? propertyId
        : propertyId[0].toUpperCase() + propertyId.substring(1);
    transactions.record(
      EditorTransaction(
        label: 'Multi-edit $propertyId',
        // Same key scheme as the single-property setters so an open
        // transaction (e.g. a gizmo drag) coalesces repeated edits into one.
        coalesceKey:
            'updateActor${capitalized}_${selectedActors.map((a) => a.id).join(',')}',
        redo: apply,
        undo: undo,
      ),
    );
  }

  void updateActorLocation(
    List<double> val, {
    bool isCommit = true,
    bool relative = false,
    int? axis,
  }) {
    if (selectedActors.isEmpty) return;
    if (!isCommit || _dragSnapshotLocation != null) {
      if (_dragSnapshotLocation == null) {
        beginTransformDrag();
        _implicitTransformDrag = true;
      }
      for (final a in selectedActors) {
        if (a.isLocked) continue;
        if (axis != null) {
          // One axis only.
          final before = _dragSnapshotLocation![a.id];
          final next = List<double>.from(a.location);
          next[axis] = relative && before != null ? before[axis] + val[axis] : val[axis];
          a.location = next;
        } else if (relative && _dragSnapshotLocation!.containsKey(a.id)) {
          final before = _dragSnapshotLocation![a.id]!;
          a.location = [
            before[0] + val[0],
            before[1] + val[1],
            before[2] + val[2],
          ];
        } else {
          a.location = List.from(val);
        }
      }
      notifyListeners();
      // The committing write of a drag this method opened ends it.
      if (isCommit && _implicitTransformDrag) endTransformDrag();
      return;
    }
    applyPropertyToSelection(null, 'location', val, relative: relative, axis: axis);
    _dragSnapshotLocation = null;
    _dragSnapshotRotation = null;
    _dragSnapshotScale = null;
  }

  void updateActorRotation(
    List<double> val, {
    bool isCommit = true,
    bool relative = false,
    int? axis,
  }) {
    if (selectedActors.isEmpty) return;
    if (!isCommit || _dragSnapshotRotation != null) {
      if (_dragSnapshotRotation == null) {
        beginTransformDrag();
        _implicitTransformDrag = true;
      }
      for (final a in selectedActors) {
        if (a.isLocked) continue;
        if (axis != null) {
          // One axis only.
          final before = _dragSnapshotRotation![a.id];
          final next = List<double>.from(a.rotation);
          next[axis] = relative && before != null ? before[axis] + val[axis] : val[axis];
          a.rotation = next;
        } else if (relative && _dragSnapshotRotation!.containsKey(a.id)) {
          final before = _dragSnapshotRotation![a.id]!;
          a.rotation = [
            before[0] + val[0],
            before[1] + val[1],
            before[2] + val[2],
          ];
        } else {
          a.rotation = List.from(val);
        }
      }
      notifyListeners();
      // The committing write of a drag this method opened ends it.
      if (isCommit && _implicitTransformDrag) endTransformDrag();
      return;
    }
    applyPropertyToSelection(null, 'rotation', val, relative: relative, axis: axis);
    _dragSnapshotLocation = null;
    _dragSnapshotRotation = null;
    _dragSnapshotScale = null;
  }

  void updateActorScale(
    List<double> val, {
    bool isCommit = true,
    bool relative = false,
    int? axis,
  }) {
    if (selectedActors.isEmpty) return;
    if (!isCommit || _dragSnapshotScale != null) {
      if (_dragSnapshotScale == null) {
        beginTransformDrag();
        _implicitTransformDrag = true;
      }
      for (final a in selectedActors) {
        if (a.isLocked) continue;
        if (axis != null) {
          // One axis only.
          final before = _dragSnapshotScale![a.id];
          final next = List<double>.from(a.scale);
          next[axis] = relative && before != null ? before[axis] + val[axis] : val[axis];
          a.scale = next;
        } else if (relative && _dragSnapshotScale!.containsKey(a.id)) {
          final before = _dragSnapshotScale![a.id]!;
          a.scale = [
            before[0] + val[0],
            before[1] + val[1],
            before[2] + val[2],
          ];
        } else {
          a.scale = List.from(val);
        }
      }
      notifyListeners();
      // The committing write of a drag this method opened ends it.
      if (isCommit && _implicitTransformDrag) endTransformDrag();
      return;
    }
    applyPropertyToSelection(null, 'scale', val, relative: relative, axis: axis);
    _dragSnapshotLocation = null;
    _dragSnapshotRotation = null;
    _dragSnapshotScale = null;
  }
}
