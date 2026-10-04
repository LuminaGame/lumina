part of '../blueprint_editor_view_model.dart';

/// The component tree: transform drags, add/remove/rename/reparent,
/// properties, collision, physics and class defaults.
mixin _BlueprintEditorComponents on _BlueprintEditorViewModelState {

  /// Bumped on every live transform write of a gizmo drag (and when the
  /// drag ends or is cancelled), so the Details fields rebuild with the
  /// live value: a text field keeps what was typed otherwise.
  int get componentTransformRevision => _componentTransformRevision;

  /// The component a gizmo drag is moving, or null.
  String? get transformDragComponentId => _transformDragId;

  /// Whether the gizmo may move [id]: a scene component that is not the root
  /// (the root's gizmo is shown but the root does not move).
  bool canTransformComponent(String id) {
    final c = getComponent(id);
    return c != null && c.isSceneComponent && rootComponent?.id != id;
  }

  /// Snapshots [id]'s relative transform; the drag's writes go through
  /// [updateComponentTransform] and [endComponentTransformDrag] commits them
  /// as one undo step. A root or non-scene component starts no drag.
  void beginComponentTransformDrag(String id) {
    if (!canTransformComponent(id)) return;
    if (_transformDragId != null) endComponentTransformDrag();
    _transformDragId = id;
    beginInteraction('Transform ${getComponent(id)!.name}');
  }

  /// Ensures that component [id] is present in `_document.components`.
  /// If it is currently only inherited from a parent Blueprint, it is cloned
  /// into `_document.components` so its property overrides can be recorded,
  /// undo/redo tracked, and persisted to disk.
  LuminaBlueprintComponent _ensureComponentInDocument(String id) {
    final existing = _document.components.where((c) => c.id == id).firstOrNull;
    if (existing != null) return existing;
    final inherited = inheritedComponents.where((c) => c.id == id).firstOrNull;
    if (inherited != null) {
      final clone = LuminaBlueprintComponent(
        id: inherited.id,
        name: inherited.name,
        type: inherited.type,
        parentId: inherited.parentId,
        properties: Map<String, dynamic>.from(jsonDecode(jsonEncode(inherited.properties)) as Map),
        isSceneComponent: inherited.isSceneComponent,
      );
      _document.components.add(clone);
      return clone;
    }
    throw StateError('Component $id not found');
  }

  /// Writes the relative [location] / [rotation] / [scale] (authoring
  /// values, as the Details panel shows them) through live. During a drag
  /// the preview's built component moves with it and the document is not yet
  /// an undo step; outside a drag this is one undo step of its own.
  void updateComponentTransform(String id, {List<double>? location, List<double>? rotation, List<double>? scale}) {
    if (!canTransformComponent(id)) return;
    void apply() {
      final c = _ensureComponentInDocument(id);
      if (location != null) c.properties['location'] = List<double>.from(location);
      if (rotation != null) c.properties['rotation'] = List<double>.from(rotation);
      if (scale != null) c.properties['scale'] = List<double>.from(scale);
    }

    if (_transformDragId != id) {
      mutate('Transform ${getComponent(id)!.name}', () {
        apply();
        return true;
      });
      return;
    }
    apply();
    _componentTransformRevision++;
    preview.setComponentTransform(id, location: location, rotation: rotation, scale: scale);
    notifyListeners();
  }

  /// Commits the drag: one transaction with the transform before and after
  /// (none when nothing changed); the document is dirty from here.
  void endComponentTransformDrag() {
    if (_transformDragId == null) return;
    _transformDragId = null;
    _componentTransformRevision++;
    endInteraction();
    notifyListeners();
  }

  /// Esc mid-drag: the transform snapshot comes back, no undo entry.
  void cancelComponentTransformDrag() {
    if (_transformDragId == null) return;
    _transformDragId = null;
    _componentTransformRevision++;
    final before = _interactionBefore;
    _interactionBefore = null;
    if (before != null) {
      _restore(before);
    } else {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Components
  // ---------------------------------------------------------------------------

  LuminaBlueprintComponent? get rootComponent =>
      allComponents.where((c) => c.isSceneComponent && c.parentId == null).firstOrNull ??
      _document.components.where((c) => c.isSceneComponent && c.parentId == null).firstOrNull;

  LuminaBlueprintComponent? getComponent(String id) =>
      allComponents.where((c) => c.id == id).firstOrNull ??
      _document.components.where((c) => c.id == id).firstOrNull;

  bool isSceneComponent(String id) => getComponent(id)?.isSceneComponent ?? false;

  void selectComponent(String? id) {
    if (_selectedComponentId != id) {
      _selectedComponentId = id;
      if (id != null) _selectedVariable = null;
      notifyListeners();
    }
  }

  LuminaBlueprintComponent? addComponent(String type, {String? parentId}) {
    final desc = BlueprintComponentRegistry.getDescriptor(type);
    final isScene = desc?.isSceneComponent ?? true;

    final baseName = type.replaceAll('Lumina', '');
    var candidateName = baseName;
    var suffix = 1;
    while (_document.components.any((c) => c.name == candidateName)) {
      suffix++;
      candidateName = '$baseName$suffix';
    }

    String? resolvedParent = parentId;
    if (isScene) {
      resolvedParent = rootComponent == null ? null : (resolvedParent ?? rootComponent!.id);
    } else {
      resolvedParent = null;
    }

    final initialProps = <String, dynamic>{};
    for (final prop in desc?.properties ?? const <ComponentPropertySchema>[]) {
      if (prop.defaultValue != null) initialProps[prop.dartField] = prop.defaultValue;
    }

    final id = BlueprintGraphEditor.newId('comp');
    final added = mutate('Add $candidateName', () {
      _document.components.add(LuminaBlueprintComponent(
        id: id,
        name: candidateName,
        type: type,
        parentId: resolvedParent,
        properties: initialProps,
        isSceneComponent: isScene,
      ));
      return true;
    });
    if (!added) return null;
    _selectedComponentId = id;
    notifyListeners();
    return getComponent(id);
  }

  bool removeComponent(String id) {
    if (isInheritedComponent(id)) return false;
    final node = getComponent(id);
    if (node == null) return false;
    mutate('Delete ${node.name}', () {
      for (final child in _document.components.where((c) => c.parentId == id)) {
        child.parentId = node.parentId;
      }
      _document.components.removeWhere((c) => c.id == id);
      return true;
    });
    if (_selectedComponentId == id) {
      _selectedComponentId = _document.components.isNotEmpty ? _document.components.first.id : null;
    }
    notifyListeners();
    return true;
  }

  bool renameComponent(String id, String newName) {
    if (isInheritedComponent(id)) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || !_identifier.hasMatch(trimmed)) return false;
    if (_document.components.any((c) => c.id != id && c.name.toLowerCase() == trimmed.toLowerCase())) return false;
    if (getComponent(id) == null) return false;
    return mutate('Rename component', () {
      getComponent(id)!.name = trimmed;
      return true;
    });
  }

  bool canReparent(String childId, String? targetParentId) {
    if (isInheritedComponent(childId)) return false;
    if (childId == targetParentId) return false;
    if (targetParentId == null) return true;
    if (!isSceneComponent(targetParentId)) return false;
    String? current = targetParentId;
    while (current != null) {
      if (current == childId) return false;
      current = getComponent(current)?.parentId;
    }
    return true;
  }

  bool reparent(String childId, String? newParentId) {
    if (!canReparent(childId, newParentId)) return false;
    final node = getComponent(childId);
    if (node == null || !node.isSceneComponent) return false;
    return mutate('Attach ${node.name}', () {
      getComponent(childId)!.parentId = newParentId;
      return true;
    });
  }

  LuminaBlueprintComponent? duplicateComponent(String id) {
    final original = getComponent(id);
    if (original == null) return null;

    var candidateName = '${original.name}_Copy';
    var suffix = 1;
    while (_document.components.any((c) => c.name == candidateName)) {
      suffix++;
      candidateName = '${original.name}_Copy$suffix';
    }
    final newId = BlueprintGraphEditor.newId('comp');
    mutate('Duplicate ${original.name}', () {
      _document.components.add(LuminaBlueprintComponent(
        id: newId,
        name: candidateName,
        type: original.type,
        parentId: original.parentId,
        properties: Map<String, dynamic>.from(jsonDecode(jsonEncode(original.properties)) as Map),
        isSceneComponent: original.isSceneComponent,
      ));
      return true;
    });
    _selectedComponentId = newId;
    notifyListeners();
    return getComponent(newId);
  }

  @override
  void setProperty(String componentId, String propName, dynamic value) {
    final node = getComponent(componentId);
    if (node == null) return;
    final schema = BlueprintComponentRegistry.getSchema(node.type).where((p) => p.dartField == propName).firstOrNull;
    final resolvedValue = _resolvePropertyValue(schema, value);
    if (_propertyEditId != null) {
      // A slider drag on this property is open: this is its release.
      commitProperty(componentId, propName, resolvedValue);
      return;
    }
    if (jsonEncode(node.properties[propName]) == jsonEncode(resolvedValue)) return;
    mutate('Edit ${schema?.name ?? propName}', () {
      final target = _ensureComponentInDocument(componentId);
      target.properties[propName] = resolvedValue;
      return true;
    });
  }

  /// A number within its schema's hard limits (not the slider's range: a
  /// typed value may go past it).
  dynamic _resolvePropertyValue(ComponentPropertySchema? schema, dynamic value) {
    if (schema != null && schema.type == ComponentPropertyType.number && value is num) {
      return schema.clampToLimits(value.toDouble());
    }
    return value;
  }

  /// A live value while a Details slider or scrub moves (no undo step yet):
  /// the document and the 3D Viewport follow it; [commitProperty] on release
  /// records the whole drag as one undo step.
  void previewProperty(String componentId, String propName, dynamic value) {
    final node = _ensureComponentInDocument(componentId);
    final schema = BlueprintComponentRegistry.getSchema(node.type).where((p) => p.dartField == propName).firstOrNull;
    final key = '$componentId.$propName';
    if (_propertyEditId != key) {
      if (_propertyEditId != null) endInteraction();
      _propertyEditId = key;
      beginInteraction('Edit ${schema?.name ?? propName}');
    }
    node.properties[propName] = _resolvePropertyValue(schema, value);
    _syncPreview();
    notifyListeners();
  }

  /// Commits [value] (a slider's release, or a typed value): one undo step —
  /// the whole drag when [previewProperty] opened one.
  void commitProperty(String componentId, String propName, dynamic value) {
    final node = getComponent(componentId);
    if (node == null) return;
    final schema = BlueprintComponentRegistry.getSchema(node.type).where((p) => p.dartField == propName).firstOrNull;
    final key = '$componentId.$propName';
    if (_propertyEditId == null) {
      setProperty(componentId, propName, value);
      return;
    }
    if (_propertyEditId != key) {
      _propertyEditId = null;
      endInteraction();
      setProperty(componentId, propName, value);
      return;
    }
    final target = _ensureComponentInDocument(componentId);
    target.properties[propName] = _resolvePropertyValue(schema, value);
    _propertyEditId = null;
    endInteraction();
    notifyListeners();
  }

  /// Points a Skeletal Mesh component at Animation Blueprint [path] (its Anim
  /// Class) and switches it to Use Animation Blueprint, in one undo step;
  /// an empty path clears it.
  bool setAnimClass(String componentId, String path) {
    final node = getComponent(componentId);
    if (node == null || node.properties['animClass'] == path) return false;
    return mutate(path.isEmpty ? 'Clear Anim Class' : 'Set Anim Class', () {
      final c = _ensureComponentInDocument(componentId);
      c.properties['animClass'] = path;
      if (path.isNotEmpty) c.properties['animMode'] = 'Use Animation Blueprint';
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Collision
  // ---------------------------------------------------------------------------

  /// Writes collision JSON [json] (lumina's `preset`,
  /// `objectType`, `responses`, `generateOverlapEvents`, `collisionEnabled`)
  /// into collision component [id]'s properties as one undo step. Keys
  /// [json] lacks are left as they are. False for anything that is not a
  /// collision component, or when nothing changed.
  bool setComponentCollision(String id, Map<String, dynamic> json) {
    final node = getComponent(id);
    if (node == null || !BlueprintComponentRegistry.isCollisionCapable(node.type)) return false;
    final collision = {
      for (final k in const ['preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'])
        if (json.containsKey(k)) k: jsonDecode(jsonEncode(json[k])),
    };
    if (collision.isEmpty) return false;
    return mutate('Edit Collision of ${node.name}', () {
      final c = _ensureComponentInDocument(id);
      final before = jsonEncode(c.properties);
      c.properties.addAll(collision);
      return jsonEncode(c.properties) != before;
    });
  }

  /// The static mesh component [id] inherits its mass from, as lumina
  /// resolves it: itself when it is one, else the nearest static mesh in the
  /// tree (a parent, then a child, then any).
  LuminaBlueprintComponent? physicsMeshOf(String id) {
    final node = getComponent(id);
    if (node == null) return null;
    bool isMesh(LuminaBlueprintComponent c) =>
        c.type == 'LuminaStaticMeshComponent' && (c.properties['staticMeshAsset'] as String? ?? '').isNotEmpty;
    if (isMesh(node)) return node;
    final byId = {for (final c in _document.components) c.id: c};
    for (var p = node.parentId == null ? null : byId[node.parentId]; p != null; p = p.parentId == null ? null : byId[p.parentId]) {
      if (isMesh(p)) return p;
    }
    LuminaBlueprintComponent? child(String parent) {
      for (final c in _document.components.where((c) => c.parentId == parent)) {
        final found = isMesh(c) ? c : child(c.id);
        if (found != null) return found;
      }
      return null;
    }

    return child(node.id) ?? _document.components.where(isMesh).firstOrNull;
  }

  /// What component [id] inherits from its static mesh asset (the Static
  /// Mesh editor's `metadata.physics`) and the mesh's name; null without a
  /// mesh or physics metadata.
  ({LuminaMeshPhysics physics, String meshName})? inheritedPhysics(String id) {
    final mesh = physicsMeshOf(id);
    final dir = projectDir;
    if (mesh == null || dir == null) return null;
    final stored = mesh.properties['staticMeshAsset'] as String;
    final physics = MeshPhysicsService.forMeshAsset(stored, projectDir: dir);
    if (physics == null) return null;
    return (physics: physics, meshName: p.basenameWithoutExtension(stored));
  }

  /// Component [id]'s mass from its volume × density (what it simulates with
  /// when neither an override nor its mesh gives one), kg.
  double computedMassKg(String id) {
    final built = preview.componentFor(id);
    final node = getComponent(id);
    if (built is! LuminaPrimitivePhysics || node == null) return 0.0;
    final props = LuminaPhysicsSubsystem.resolveMassProperties(built);
    final physics = node.properties['physics'];
    final density = physics is Map && physics['density'] is num ? (physics['density'] as num).toDouble() : 1.0;
    return props.volume * density / 1000.0;
  }

  /// Writes physics JSON [json] (lumina's `physics` map) into
  /// component [id] as one undo step, with the inherited mesh values baked
  /// into `meshPhysics` for the generated game. False for a component
  /// without a Physics section, or when nothing changed.
  bool setComponentPhysics(String id, Map<String, dynamic> json) {
    final node = getComponent(id);
    if (node == null || !BlueprintEditorViewModel.isPhysicsCapable(node.type)) return false;
    final physics = Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map);
    final inherited = inheritedPhysics(id)?.physics;
    if (inherited != null) {
      physics['meshPhysics'] = inherited.toJson();
    } else {
      physics.remove('meshPhysics');
    }
    return mutate('Edit Physics of ${node.name}', () {
      final c = _ensureComponentInDocument(id);
      final before = jsonEncode(c.properties);
      c.properties['physics'] = physics;
      return jsonEncode(c.properties) != before;
    });
  }

  /// Re-bakes every Physics section's inherited mesh values (the mesh's
  /// mass may have changed in the Static Mesh editor since).
  @override
  void _refreshBakedMeshPhysics() {
    for (final c in _document.components) {
      final physics = c.properties['physics'];
      if (physics is! Map) continue;
      final inherited = inheritedPhysics(c.id)?.physics;
      if (inherited != null) {
        physics['meshPhysics'] = inherited.toJson();
      } else {
        physics.remove('meshPhysics');
      }
    }
  }

  /// Collision component [id]'s built-in setup, which its collision JSON is
  /// read on top of: a Character's root capsule is Pawn, anything
  /// else lumina's default (Block All Dynamic).
  LuminaCollisionProfile collisionBase(String id) {
    final node = getComponent(id);
    final characterCapsule = node != null &&
        node.type == 'LuminaCapsuleComponent' &&
        _document.parentClass == 'LuminaCharacter' &&
        rootComponent?.id == id;
    return characterCapsule ? LuminaCollisionProfile.forPreset(LuminaCollisionPreset.pawn) : LuminaCollisionProfile();
  }

  /// The project's static meshes that carry simple collision hulls (imported
  /// `UCX_` pieces or authored convex shapes): what a Convex Collision
  /// component can wrap. Project-relative `.lmas` paths.
  List<String> get convexHullMeshes {
    final dir = projectDir;
    if (dir == null) return const [];
    return [
      for (final a in _availableStaticMeshes)
        if (a.relativePath.endsWith('.lmas') && MeshCollisionService.hullsForMeshAsset(a.relativePath, projectDir: dir).isNotEmpty)
          a.relativePath,
    ];
  }

  /// Points Convex Collision component [id] at mesh [meshPath]'s simple
  /// collision (empty: none), in one undo step: `hullAsset` names the mesh
  /// and `hullPoints` carries its hull points in the component's frame
  /// (runtime axes, cm) — what lumina's component mapping builds the convex
  /// from in the generated game, which cannot read `.lmas` files. Several
  /// hulls collide as the one convex hull around all their points.
  bool setConvexHullAsset(String id, String meshPath) {
    final node = getComponent(id);
    if (node == null || node.type != 'LuminaConvexComponent') return false;
    final dir = projectDir;
    final hulls = meshPath.isEmpty || dir == null ? const <LuminaCollisionHull>[] : MeshCollisionService.hullsForMeshAsset(meshPath, projectDir: dir);
    final points = [
      for (final h in hulls)
        for (final v in h.runtimePoints) [v.x, v.y, v.z],
    ];
    return mutate(meshPath.isEmpty ? 'Clear Convex Hull' : 'Set Convex Hull', () {
      final c = _ensureComponentInDocument(id);
      final before = jsonEncode(c.properties);
      c.properties['hullAsset'] = meshPath;
      if (points.length >= 4) {
        c.properties['hullPoints'] = points;
      } else {
        c.properties.remove('hullPoints');
      }
      return jsonEncode(c.properties) != before;
    });
  }

  /// Convex Collision components without a hull (no mesh, or a mesh with no
  /// simple collision): they collide as their box.
  @override
  List<LuminaBlueprintComponent> get convexComponentsWithoutHull => [
        for (final c in _document.components)
          if (c.type == 'LuminaConvexComponent' && ((c.properties['hullPoints'] as List?)?.length ?? 0) < 4) c,
      ];

  void setClassDefault(String key, dynamic value) {
    mutate('Edit class default $key', () {
      _document.classDefaults[key] = value;
      return true;
    });
  }

  void setParentClass(String parentClass) {
    if (_document.parentClass == parentClass) return;
    mutate('Reparent Blueprint', () {
      _document.parentClass = parentClass;
      if (_document.components.isEmpty) {
        _document.components.addAll(BlueprintEditorViewModel.createDefaultDocument(fileBasename, parentClass: parentClass).components);
      }
      return true;
    });
  }

  void resetToDefaultComponents() {
    mutate('Reset components', () {
      final defaultDoc = BlueprintEditorViewModel.createDefaultDocument(fileBasename,
          parentClass: _document.parentClass.isNotEmpty ? _document.parentClass : 'LuminaCharacter');
      _document.components
        ..clear()
        ..addAll(defaultDoc.components);
      _document.parentClass = defaultDoc.parentClass;
      return true;
    });
  }
}
