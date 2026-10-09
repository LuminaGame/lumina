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

  /// Assigns the material asset [materialPath] (project-relative
  /// `contents/…`) to the selected mesh actor, drawn on every section of its
  /// mesh in the viewport, in Play and in the built game; null gives the mesh
  /// its own materials back. One undo step.
  void updateActorMaterial(String? materialPath) {
    if (_selectedActor == null) return;
    final node = _selectedActor!;
    final oldVal = node.materialPath;
    final newVal = (materialPath == null || materialPath.isEmpty) ? null : materialPath;
    if (oldVal == newVal) return;

    void set(String? value) {
      node.materialPath = value;
      _markDirty();
    }

    set(newVal);
    _logger.log(
      newVal == null ? 'Cleared the material of actor "${node.name}"' : 'Assigned material "$newVal" to actor "${node.name}"',
      level: 'success',
      source: 'Inspector',
    );
    transactions.record(
      EditorTransaction(
        label: 'Change Material ${node.name}',
        undo: () => set(oldVal),
        redo: () => set(newVal),
      ),
    );
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
}
