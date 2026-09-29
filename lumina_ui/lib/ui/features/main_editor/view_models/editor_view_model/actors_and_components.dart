part of '../editor_view_model.dart';

/// Level actor nodes and their components: add/remove, component properties,
/// collision/physics placement overrides, light and mobility edits.
mixin _EditorActorsAndComponents on _EditorViewModelState {
  void addActorNodeForTest(EditorActorNode node) {
    _actors.add(node);
  }

  /// Adds a fully-formed actor node to the level as an undoable edit (used
  /// by sub-editors that create well-known actors, e.g. the Environment
  /// mixer's `Sun` / `SkyAmbience`).
  void addActorNode(EditorActorNode node, {String? label}) {
    void apply() {
      if (!_actors.any((a) => a.id == node.id)) _actors.add(node);
      _logger.log(
        'Added actor "${node.name}" (${node.type}) to the level',
        level: 'success',
        source: 'WorldTree',
      );
      _markDirty();
    }

    apply();

    transactions.record(
      EditorTransaction(
        label: label ?? 'Add ${node.name}',
        undo: () {
          _actors.removeWhere((a) => a.id == node.id);
          if (_selectedActor?.id == node.id) _selectedActor = null;
          _selectedActorIds.remove(node.id);
          _markDirty();
        },
        redo: apply,
      ),
    );
  }

  /// Adds [nodes] to the level as ONE undoable transaction (a
  /// PCG Generate places hundreds of instances and undoes as one step).
  /// Nodes whose id is already in the level are skipped.
  void addActorNodes(List<EditorActorNode> nodes, {String? label}) {
    if (nodes.isEmpty) return;
    final ids = nodes.map((n) => n.id).toList();
    void apply() {
      for (final node in nodes) {
        if (!_actors.any((a) => a.id == node.id)) _actors.add(node);
      }
      _logger.log(
        'Added ${nodes.length} actors to the level (${label ?? nodes.first.name})',
        level: 'success',
        source: 'WorldTree',
      );
      _markDirty();
    }

    apply();
    transactions.record(
      EditorTransaction(
        label: label ?? 'Add ${nodes.length} actors',
        undo: () {
          _actors.removeWhere((a) => ids.contains(a.id));
          if (_selectedActor != null && ids.contains(_selectedActor!.id)) _selectedActor = null;
          _selectedActorIds.removeAll(ids);
          _markDirty();
        },
        redo: apply,
      ),
    );
  }

  /// Removes the actors with [ids] and their subtrees as ONE undoable
  /// transaction (a PCG Cleanup).
  void removeActorNodes(Iterable<String> ids, {String? label}) {
    final targets = ids.where((id) => _actors.any((a) => a.id == id)).toList();
    if (targets.isEmpty) return;
    final snapshot = _cloneActors(_actors.cast<EditorActorNode>());
    final selectedBefore = _selectedActor?.id;
    final selectedSetBefore = List<String>.from(_selectedActorIds);
    void apply() {
      for (final id in targets) {
        deleteActorSubtree(id);
      }
      _markDirty();
      notifyListeners();
    }

    apply();
    _logger.log('Removed ${targets.length} actors (${label ?? 'plugin'})', level: 'info', source: 'WorldTree');
    transactions.record(
      EditorTransaction(
        label: label ?? 'Remove ${targets.length} actors',
        undo: () {
          _actors
            ..clear()
            ..addAll(_cloneActors(snapshot));
          _selectedActorIds
            ..clear()
            ..addAll(selectedSetBefore);
          _selectedActor = selectedBefore == null ? null : _actors.where((a) => a.id == selectedBefore).firstOrNull;
          _markDirty();
          notifyListeners();
        },
        redo: apply,
      ),
    );
  }

  /// Sets [propertyId] on the actor's first component of [componentType] as
  /// an undoable transaction, whether or not the actor is selected
  /// (a plugin's Details section edits through `DetailsTarget`).
  void setComponentPropertyWithTransaction(
    String actorId,
    String componentType,
    String propertyId,
    dynamic value, {
    String? label,
  }) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null) return;
    final comp = actor.components.where((c) => c.type == componentType).firstOrNull;
    if (comp == null) return;
    final before = comp.properties[propertyId];
    final hadBefore = comp.properties.containsKey(propertyId);
    void set(dynamic v, bool present) {
      if (present) {
        comp.properties[propertyId] = v;
      } else {
        comp.properties.remove(propertyId);
      }
      _markDirty();
      notifyListeners();
    }

    set(value, true);
    transactions.record(
      EditorTransaction(
        label: label ?? 'Set $propertyId',
        undo: () => set(before, hadBefore),
        redo: () => set(value, true),
      ),
    );
  }

  /// Stores collision JSON [json] (lumina's collision keys) on [actorId]'s
  /// collision component [componentId] as one undo step.
  /// With [blueprintComponent] — a collision component of a placed
  /// Blueprint's class — the JSON goes into the actor's instance override of
  /// it (created on the first edit, saved in the level `.lmas`); otherwise
  /// into the actor's own component [componentId].
  bool setActorComponentCollision(String actorId, String componentId, Map<String, dynamic> json,
      {LuminaBlueprintComponent? blueprintComponent}) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null) return false;
    final collision = {
      for (final k in const ['preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'])
        if (json.containsKey(k)) k: jsonDecode(jsonEncode(json[k])),
    };
    if (collision.isEmpty) return false;
    final overrideId = blueprintComponent == null ? null : '$actorId.collision.${blueprintComponent.id}';
    final existing = actor.components.where((c) => c.id == (overrideId ?? componentId)).firstOrNull;
    if (existing == null && blueprintComponent == null) return false;
    final before = existing == null ? null : jsonEncode(existing.properties);
    final after = <String, dynamic>{
      ...?existing?.properties,
      if (blueprintComponent != null) 'blueprintComponentId': blueprintComponent.id,
      ...collision,
    };
    if (before != null && before == jsonEncode(after)) return false;
    final afterJson = jsonEncode(after);

    void apply(String? props) {
      final target = actor.components.where((c) => c.id == (overrideId ?? componentId)).firstOrNull;
      if (props == null) {
        if (target != null) actor.components.remove(target);
      } else if (target == null) {
        actor.components.add(EditorComponentNode(
          id: overrideId!,
          type: blueprintComponent!.type,
          name: blueprintComponent.name,
          properties: Map<String, dynamic>.from(jsonDecode(props) as Map),
        ));
      } else {
        target.properties
          ..clear()
          ..addAll(Map<String, dynamic>.from(jsonDecode(props) as Map));
      }
      _markDirty();
      notifyListeners();
    }

    apply(afterJson);
    final name = blueprintComponent?.name ?? existing?.name ?? componentId;
    transactions.record(EditorTransaction(
      label: 'Edit Collision of ${actor.name}.$name',
      undo: () => apply(before),
      redo: () => apply(afterJson),
    ));
    return true;
  }

  /// Stores physics JSON [json] (lumina's `physics` map) as
  /// placed Blueprint actor [actorId]'s override of its class's component
  /// [blueprintComponent], in the same override node
  /// as its collision (the level `.lmas` `metadata.actors[].components`),
  /// as one undo step. Play-In-Editor and the generated level apply it.
  bool setActorComponentPhysics(String actorId, LuminaBlueprintComponent blueprintComponent, Map<String, dynamic> json) {
    final actor = _actors.where((a) => a.id == actorId).firstOrNull;
    if (actor == null) return false;
    final overrideId = '$actorId.collision.${blueprintComponent.id}';
    final existing = actor.components.where((c) => c.id == overrideId).firstOrNull;
    final before = existing == null ? null : jsonEncode(existing.properties);
    final after = <String, dynamic>{
      ...?existing?.properties,
      'blueprintComponentId': blueprintComponent.id,
      'physics': jsonDecode(jsonEncode(json)),
    };
    if (before != null && before == jsonEncode(after)) return false;
    final afterJson = jsonEncode(after);

    void apply(String? props) {
      final target = actor.components.where((c) => c.id == overrideId).firstOrNull;
      if (props == null) {
        if (target != null) actor.components.remove(target);
      } else if (target == null) {
        actor.components.add(EditorComponentNode(
          id: overrideId,
          type: blueprintComponent.type,
          name: blueprintComponent.name,
          properties: Map<String, dynamic>.from(jsonDecode(props) as Map),
        ));
      } else {
        target.properties
          ..clear()
          ..addAll(Map<String, dynamic>.from(jsonDecode(props) as Map));
      }
      _markDirty();
      notifyListeners();
    }

    apply(afterJson);
    transactions.record(EditorTransaction(
      label: 'Edit Physics of ${actor.name}.${blueprintComponent.name}',
      undo: () => apply(before),
      redo: () => apply(afterJson),
    ));
    return true;
  }

  void updateActorMaterial(String materialPath) {
    if (_selectedActor != null) {
      _selectedActor!.materialPath = materialPath;
      _logger.log(
        'Assigned material "$materialPath" to actor "${_selectedActor!.name}"',
        level: 'success',
        source: 'Inspector',
      );
      _markDirty();
    }
  }

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
    notifyListeners();
  }

  void updateActorMobility(String val) {
    if (_selectedActor != null) {
      final node = _selectedActor!;
      final oldVal = node.mobility;

      void apply() {
        node.mobility = val;
        _markDirty();
      }

      apply();

      transactions.record(
        EditorTransaction(
          label: 'Change Mobility ${node.name}',
          coalesceKey: 'updateActorMobility_${node.id}',
          undo: () {
            node.mobility = oldVal;
            _markDirty();
          },
          redo: apply,
        ),
      );
    }
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

  void updateActorLightIntensity(double val) {
    if (_selectedActor != null) {
      final node = _selectedActor!;
      final oldVal = node.lightIntensity;

      void apply() {
        node.lightIntensity = val;
        _markDirty();
      }

      apply();

      transactions.record(
        EditorTransaction(
          label: 'Change Light Intensity ${node.name}',
          coalesceKey: 'updateActorLightIntensity_${node.id}',
          undo: () {
            node.lightIntensity = oldVal;
            _markDirty();
          },
          redo: apply,
        ),
      );
    }
  }

  void updateActorCastShadows(bool val) {
    if (_selectedActor != null) {
      final node = _selectedActor!;
      final oldVal = node.castShadows;

      void apply() {
        node.castShadows = val;
        _markDirty();
      }

      apply();

      transactions.record(
        EditorTransaction(
          label: 'Change Cast Shadows ${node.name}',
          coalesceKey: 'updateActorCastShadows_${node.id}',
          undo: () {
            node.castShadows = oldVal;
            _markDirty();
          },
          redo: apply,
        ),
      );
    }
  }

  void updateActorLightColor(String val) {
    if (_selectedActor != null) {
      final node = _selectedActor!;
      final oldVal = node.lightColorHex;

      void apply() {
        node.lightColorHex = val;
        _markDirty();
      }

      apply();

      transactions.record(
        EditorTransaction(
          label: 'Change Light Color ${node.name}',
          coalesceKey: 'updateActorLightColor_${node.id}',
          undo: () {
            node.lightColorHex = oldVal;
            _markDirty();
          },
          redo: apply,
        ),
      );
    }
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
            notifyListeners();
          }
        }
      } else {
        bool changed = false;
        for (final actor in selectedActors) {
          final c = actor.components.where((c) => c.id == componentId).firstOrNull;
          if (c != null) {
            c.properties[propertyId] = value;
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
