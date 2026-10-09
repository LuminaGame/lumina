part of '../editor_view_model.dart';

/// Actor components: add, remove, rename, enable and property edits (each one
/// undo step), and the Light/Camera/Sky components older actors are given.
mixin _EditorComponentEdits on _EditorViewModelState, _EditorActorsAndComponents {
  // Component Wrappers

  /// Adds a [type] component to [actorId] as one undo step; returns it (with a
  /// level-unique id), or null for an unknown actor.
  EditorComponentNode? addComponentWithTransaction(String actorId, String type) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == actorId,
      orElse: () => null,
    );
    if (actor == null) return null;

    final newComponent = EditorComponentNode(
      id: _uniqueComponentId(),
      type: type,
      name: type.replaceAll('Lumina', '').replaceAll('Component', ''),
    );

    actor.components.add(newComponent);
    transactions.record(
      EditorTransaction(
        label: 'Add Component',
        undo: () {
          actor.components.removeWhere((c) => c.id == newComponent.id);
          _markDirty();
          notifyListeners();
        },
        redo: () {
          actor.components.add(newComponent);
          _markDirty();
          notifyListeners();
        },
      ),
    );
    _logger.log(
      'Added component "$type" to actor "$actorId"',
      level: 'info',
      source: 'Details',
    );
    _markDirty();
    notifyListeners();
    return newComponent;
  }

  void setComponentEnabledWithTransaction(
    String actorId,
    String componentId,
    bool enabled,
  ) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == actorId,
      orElse: () => null,
    );
    if (actor == null) return;

    final comp = actor.components.firstWhere((c) => c.id == componentId);
    if (comp.enabled == enabled) return;

    comp.enabled = enabled;
    transactions.record(
      EditorTransaction(
        label: enabled ? 'Enable Component' : 'Disable Component',
        undo: () {
          comp.enabled = !enabled;
          _markDirty();
          notifyListeners();
        },
        redo: () {
          comp.enabled = enabled;
          _markDirty();
          notifyListeners();
        },
      ),
    );
    _markDirty();
    notifyListeners();
  }

  void renameComponentWithTransaction(
    String actorId,
    String componentId,
    String newName,
  ) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == actorId,
      orElse: () => null,
    );
    if (actor == null) return;

    final comp = actor.components.firstWhere((c) => c.id == componentId);
    final oldName = comp.name;
    if (oldName == newName) return;

    comp.name = newName;
    transactions.record(
      EditorTransaction(
        label: 'Rename Component',
        undo: () {
          comp.name = oldName;
          _markDirty();
          notifyListeners();
        },
        redo: () {
          comp.name = newName;
          _markDirty();
          notifyListeners();
        },
      ),
    );
    _markDirty();
    notifyListeners();
  }

  void updateComponentProperty(
    String actorId,
    String componentId,
    String propertyId,
    dynamic value,
  ) {
    final actor = _actors.firstWhere((a) => a.id == actorId);
    final comp = actor.components.firstWhere((c) => c.id == componentId);
    comp.properties[propertyId] = value;
    _refreshPrimitiveMesh(actor);
    notifyListeners();
  }

  /// Gives an older light actor (actor-level light fields
  /// only) its `Light` component, so the Details panel can edit it. Not an
  /// undoable edit: the values stay what they were.
  EditorComponentNode? ensureLightComponent(String actorId) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null || !LightActorProperties.isLightActor(actor)) return null;
    if (LightActorProperties.componentOf(actor) != null) return LightActorProperties.componentOf(actor);
    final component = LightActorProperties.ensureComponent(actor);
    _markDirty();
    notifyListeners();
    return component;
  }

  /// Gives a Camera from an older level (no camera component) its
  /// `LuminaCameraComponent` with the runtime defaults, so the Details panel
  /// can edit it. Not an undoable edit.
  EditorComponentNode? ensureCameraComponent(String actorId) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null || !CameraActorProperties.isCameraActor(actor)) return null;
    final existing = CameraActorProperties.componentOf(actor);
    if (existing != null) return existing;
    final component = CameraActorProperties.ensureComponent(actor);
    _markDirty();
    notifyListeners();
    return component;
  }

  /// Gives an environment actor its `LuminaSkyComponent`, so the Details panel
  /// can edit it and the code generator can emit it.
  EditorComponentNode? ensureSkyComponent(String actorId) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null || !EditorSceneEnvironment.isEnvironmentActor(actor.type)) return null;
    final existing = EditorSceneEnvironment.componentOf(actor);
    if (existing != null) return existing;
    final component = EditorSceneEnvironment.seedSkyComponent(actor.id);
    actor.components.add(component);
    _markDirty();
    notifyListeners();
    return component;
  }

  void updateComponentPropertyWithTransaction(
    String actorId,
    String componentId,
    String propertyId,
    dynamic value, {
    bool isCommit = true,
  }) {
    if (!isCommit) {
      if (actorId.isNotEmpty) {
        final actor =
            _actors.where((a) => a.id == actorId).firstOrNull;
        if (actor != null) {
          final c = actor.components.where((c) => c.id == componentId).firstOrNull;
          if (c != null) {
            c.properties[propertyId] = value;
            _refreshPrimitiveMesh(actor);
            notifyListeners();
          }
        }
      } else {
        bool changed = false;
        for (final actor in selectedActors) {
          final c = actor.components.where((c) => c.id == componentId).firstOrNull;
          if (c != null) {
            c.properties[propertyId] = value;
            _refreshPrimitiveMesh(actor);
            changed = true;
          }
        }
        if (changed) notifyListeners();
      }
      return;
    }
    final actorNode = _actors.cast<EditorActorNode>().firstWhere(
      (a) => a.id == actorId,
    );
    final compType = actorNode.components
        .firstWhere((c) => c.id == componentId)
        .type;
    applyPropertyToSelection(compType, propertyId, value);
  }

  void toggleComponentEnabledWithTransaction(
    String actorId,
    String compId,
    bool enabled,
  ) {
    if (selectedActors.isEmpty) return;
    final type = selectedActors
        .expand((a) => a.components)
        .firstWhere(
          (c) => c.id == compId,
          orElse: () => selectedActors.first.components.first,
        )
        .type;
    final targets = selectedActors
        .where((a) => a.components.any((c) => c.type == type))
        .toList();
    if (targets.isEmpty) return;

    final beforeStates = {
      for (var a in targets)
        a.id: a.components.firstWhere((c) => c.type == type).enabled,
    };

    void apply() {
      for (final a in targets) {
        a.components.firstWhere((c) => c.type == type).enabled = enabled;
      }
      _markDirty();
    }

    void undo() {
      for (final a in targets) {
        a.components.firstWhere((c) => c.type == type).enabled =
            beforeStates[a.id]!;
      }
      _markDirty();
    }

    apply();
    transactions.record(
      EditorTransaction(
        label: 'Multi-edit Enable Component',
        redo: apply,
        undo: undo,
      ),
    );
  }

  /// A component id no actor in the level uses yet. Two components added
  /// in the same millisecond used to share `comp_<ms>`, which made
  /// removing "this" component ambiguous.
  String _uniqueComponentId() {
    final taken = {for (final a in _actors) for (final c in a.components) c.id};
    final base = 'comp_${DateTime.now().millisecondsSinceEpoch}';
    var id = base;
    for (var n = 1; taken.contains(id); n++) {
      id = '${base}_$n';
    }
    return id;
  }

  /// Details → × on one component: removes exactly [compId] from
  /// [actorId], as one undo step that puts it back at its position.
  void removeComponentWithTransaction(String actorId, String compId) {
    final actor = _nodeById(actorId);
    if (actor == null) return;
    final index = actor.components.indexWhere((c) => c.id == compId);
    if (index < 0) return;
    final removed = actor.components[index];

    void apply() {
      actor.components.removeWhere((c) => identical(c, removed));
      _markDirty();
      notifyListeners();
    }

    void undo() {
      actor.components.insert(index.clamp(0, actor.components.length), removed);
      _markDirty();
      notifyListeners();
    }

    apply();
    transactions.record(
      EditorTransaction(label: 'Remove Component ${removed.name}', redo: apply, undo: undo),
    );
  }

  /// Multi-select Details → × on a shared component type: removes every
  /// component of [type] from every selected actor, as one undo step that
  /// restores each of them at its position.
  void removeComponentTypeFromSelectionWithTransaction(String type) {
    final removed = <(EditorActorNode, int, EditorComponentNode)>[
      for (final a in selectedActors)
        for (var i = 0; i < a.components.length; i++)
          if (a.components[i].type == type) (a, i, a.components[i]),
    ];
    if (removed.isEmpty) return;

    void apply() {
      for (final (actor, _, comp) in removed) {
        actor.components.removeWhere((c) => identical(c, comp));
      }
      _markDirty();
      notifyListeners();
    }

    void undo() {
      // Ascending indices per actor, so each insert lands where it was.
      for (final (actor, index, comp) in removed) {
        actor.components.insert(index.clamp(0, actor.components.length), comp);
      }
      _markDirty();
      notifyListeners();
    }

    apply();
    transactions.record(
      EditorTransaction(label: 'Multi-edit Remove Component', redo: apply, undo: undo),
    );
  }
}
