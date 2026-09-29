part of '../editor_view_model.dart';

/// The World Outliner: hierarchy, folders, attach/reparent, rename,
/// duplicate/delete subtrees, visibility/lock/solo, search and filters.
mixin _EditorOutliner on _EditorViewModelState {
  List<EditorActorNode> childrenOf(String parentId) {
    return _actors.where((a) => a.parentId == parentId).toList();
  }

  List<EditorActorNode> get rootActors {
    return _actors.where((a) => a.parentId == null).toList();
  }

  // --- Outliner folders -------------------------------------

  @override
  EditorActorNode? _nodeById(String? id) =>
      id == null ? null : _actors.where((a) => a.id == id).firstOrNull;

  bool _isFolder(String? id) => _nodeById(id)?.type == 'Folder';

  /// Whether a node is drawn and pickable in the viewport. Folders are
  /// editor-only grouping and never are.
  bool isViewportRepresented(String id) => _nodeById(id)?.type != 'Folder';

  /// The outliner's children of [parentId] (null: the roots) in display order:
  /// folders first, alphabetically, then the other nodes in level order.
  List<EditorActorNode> outlinerChildrenOf(String? parentId) {
    final children = _actors.where((a) => a.parentId == parentId).toList();
    final folders = children.where((a) => a.type == 'Folder').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [...folders, ...children.where((a) => a.type != 'Folder')];
  }

  /// Every folder with its display path (`Props / Crates`), for the
  /// outliner's `Move to Folder` menu.
  List<({EditorActorNode folder, String path})> get folderPaths {
    final result = <({EditorActorNode folder, String path})>[];
    void visit(String? parentId, String prefix) {
      for (final f in outlinerChildrenOf(parentId).where((a) => a.type == 'Folder')) {
        final path = prefix.isEmpty ? f.name : '$prefix / ${f.name}';
        result.add((folder: f, path: path));
        visit(f.id, path);
      }
    }

    visit(null, '');
    return result;
  }

  bool _isAncestorOrSelf(String ancestorId, String? id) {
    var current = id;
    while (current != null) {
      if (current == ancestorId) return true;
      current = _nodeById(current)?.parentId;
    }
    return false;
  }

  /// Whether [id] may move into folder [folderId] (null: the root).
  bool canMoveToFolder(String id, String? folderId) {
    final moved = _nodeById(id);
    if (moved == null) return false;
    if (moved.parentId == folderId) return false;
    if (folderId == null) return true;
    if (!_isFolder(folderId)) return false;
    return !_isAncestorOrSelf(id, folderId);
  }

  /// Snapshot of `(parentId, location)` per node, for one-step undo of a
  /// multi-node move.
  Map<String, (String?, List<double>)> _placementOf(Iterable<String> ids) => {
        for (final id in ids)
          if (_nodeById(id) != null)
            id: (_nodeById(id)!.parentId, List<double>.from(_nodeById(id)!.location)),
      };

  void _restorePlacement(Map<String, (String?, List<double>)> placement) {
    placement.forEach((id, p) {
      final n = _nodeById(id);
      if (n == null) return;
      n.parentId = p.$1;
      n.location = List<double>.from(p.$2);
    });
  }

  /// [ids] without any node whose ancestor is also in [ids] (the ancestor
  /// carries it along).
  List<String> _topmostOf(Iterable<String> ids) {
    final set = ids.toSet();
    return set.where((id) {
      var current = _nodeById(id)?.parentId;
      while (current != null) {
        if (set.contains(current)) return false;
        current = _nodeById(current)?.parentId;
      }
      return true;
    }).toList();
  }

  String _uniqueSiblingName(String base, String? parentId) {
    final taken = _actors.where((a) => a.parentId == parentId).map((a) => a.name).toSet();
    if (!taken.contains(base)) return base;
    var n = 1;
    while (taken.contains('${base}_$n')) {
      n++;
    }
    return '${base}_$n';
  }

  /// Moves [ids] into folder [folderId] (null: the root) as one undoable step,
  /// keeping every node's world location. Nodes carried by a moved ancestor,
  /// and moves that would form a cycle, are skipped.
  void moveToFolder(Iterable<String> ids, String? folderId) {
    _moveNodes(_topmostOf(ids).where((id) => canMoveToFolder(id, folderId)).toList(), folderId);
  }

  /// Whether [id] may be attached under actor [parentId] (a drop onto an
  /// actor row).
  bool canAttachToActor(String id, String parentId) =>
      !_isFolder(parentId) && _nodeById(id)?.parentId != parentId && canReparent(id, parentId);

  /// Attaches [ids] as children of actor [parentId] as one undoable step,
  /// keeping world locations.
  void attachToActor(Iterable<String> ids, String parentId) {
    _moveNodes(_topmostOf(ids).where((id) => canAttachToActor(id, parentId)).toList(), parentId);
  }

  void _moveNodes(List<String> movable, String? parentId) {
    if (movable.isEmpty) return;
    final before = _placementOf(movable);
    for (final id in movable) {
      reparentActor(id, parentId);
    }
    final after = _placementOf(movable);
    if (parentId != null) _outlinerExpanded.add(parentId);
    final target = _nodeById(parentId)?.name ?? 'Root';
    transactions.record(
      EditorTransaction(
        label: 'Move ${movable.length} item${movable.length == 1 ? '' : 's'} to $target',
        undo: () {
          _restorePlacement(before);
          _markDirty();
        },
        redo: () {
          _restorePlacement(after);
          _markDirty();
        },
      ),
    );
    _markDirty();
  }

  /// Creates a folder (in [parentFolderId], or the root) and moves [wrapIds]
  /// into it, as one undoable step. The folder is selected, expanded and put
  /// into rename in the outliner. Returns its id.
  String createFolder({
    String? name,
    String? parentFolderId,
    Iterable<String> wrapIds = const [],
  }) {
    final parent = _isFolder(parentFolderId) ? parentFolderId : null;
    final folder = EditorActorNode(
      id: _uniqueActorId(),
      name: _uniqueSiblingName(name ?? 'NewFolder', parent),
      type: 'Folder',
      parentId: parent,
      location: [0.0, 0.0, 0.0],
    );
    _actors.add(folder);
    final wrapped = _topmostOf(wrapIds.where((id) => id != folder.id))
        .where((id) => canMoveToFolder(id, folder.id))
        .toList();
    final before = _placementOf(wrapped);
    for (final id in wrapped) {
      reparentActor(id, folder.id);
    }
    final after = _placementOf(wrapped);

    void select() {
      _outlinerExpanded.add(folder.id);
      if (parent != null) _outlinerExpanded.add(parent);
      _selectedActorIds
        ..clear()
        ..add(folder.id);
      _selectedActor = folder;
    }

    select();
    _outlinerRenamingId = folder.id;
    _logger.log('Created folder "${folder.name}"', level: 'success', source: 'WorldTree');

    transactions.record(
      EditorTransaction(
        label: 'Create Folder ${folder.name}',
        undo: () {
          _restorePlacement(before);
          _actors.removeWhere((a) => a.id == folder.id);
          _selectedActorIds.remove(folder.id);
          if (_selectedActor?.id == folder.id) _selectedActor = null;
          if (_outlinerRenamingId == folder.id) _outlinerRenamingId = null;
          _markDirty();
        },
        redo: () {
          if (!_actors.any((a) => a.id == folder.id)) _actors.add(folder);
          _restorePlacement(after);
          select();
          _markDirty();
        },
      ),
    );
    _markDirty();
    return folder.id;
  }

  /// `New Folder` as the outliner, menus and quick-open run it: a selected
  /// folder receives a subfolder; other selected nodes are wrapped by a folder
  /// created where they live (their shared parent folder, else the root).
  @override
  String createFolderFromSelection() {
    final selected = selectedActors;
    if (selected.length == 1 && selected.single.type == 'Folder') {
      return createFolder(parentFolderId: selected.single.id);
    }
    if (selected.isEmpty) return createFolder();
    final parents = selected.map((a) => a.parentId).toSet();
    final shared = parents.length == 1 && _isFolder(parents.single) ? parents.single : null;
    return createFolder(parentFolderId: shared, wrapIds: selected.map((a) => a.id));
  }

  /// Ids of the outliner nodes currently expanded (deleted ids are pruned).
  Set<String> get outlinerExpandedIds {
    _outlinerExpanded.removeWhere((id) => _nodeById(id) == null);
    return Set.unmodifiable(_outlinerExpanded);
  }

  bool isOutlinerExpanded(String id) => _outlinerExpanded.contains(id) && _nodeById(id) != null;

  void setOutlinerExpanded(String id, bool expanded) {
    final changed = expanded && _nodeById(id) != null ? _outlinerExpanded.add(id) : _outlinerExpanded.remove(id);
    if (changed) notifyListeners();
  }

  void toggleOutlinerExpanded(String id) => setOutlinerExpanded(id, !isOutlinerExpanded(id));

  /// Expands every node that has children — under [under] (inclusive) or in
  /// the whole tree.
  void expandAllInOutliner({String? under}) {
    for (final a in _actors) {
      if (!_actors.any((c) => c.parentId == a.id) && a.type != 'Folder') continue;
      if (under == null || _isAncestorOrSelf(under, a.id)) _outlinerExpanded.add(a.id);
    }
    notifyListeners();
  }

  /// Collapses every node — under [under] (inclusive) or in the whole tree.
  void collapseAllInOutliner({String? under}) {
    if (under == null) {
      _outlinerExpanded.clear();
    } else {
      _outlinerExpanded.removeWhere((id) => _isAncestorOrSelf(under, id));
    }
    notifyListeners();
  }

  /// Expands every ancestor of [id], so a selected node is on screen.
  @override
  void _revealInOutliner(String? id) {
    var current = _nodeById(id)?.parentId;
    while (current != null) {
      _outlinerExpanded.add(current);
      current = _nodeById(current)?.parentId;
    }
  }

  String? get outlinerRenamingId => _outlinerRenamingId;

  @override
  void requestOutlinerRename(String id) {
    if (_nodeById(id) == null) return;
    _outlinerRenamingId = id;
    _revealInOutliner(id);
    notifyListeners();
  }

  void endOutlinerRename() {
    if (_outlinerRenamingId == null) return;
    _outlinerRenamingId = null;
    notifyListeners();
  }

  bool canReparent(String parentId, String? newParentId) {
    if (newParentId == null) return true;
    if (parentId == newParentId) return false;
    // Folders are pure grouping: they live under folders or the root only.
    if (_isFolder(parentId) && !_isFolder(newParentId)) return false;

    // Check for cycles
    String? currentId = newParentId;
    while (currentId != null) {
      if (currentId == parentId) return false;
      final node = _actors.cast<EditorActorNode?>().firstWhere(
        (a) => a?.id == currentId,
        orElse: () => null,
      );
      currentId = node?.parentId;
    }
    return true;
  }

  void reparentActor(String id, String? newParentId) {
    if (!canReparent(id, newParentId)) return;

    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == id,
      orElse: () => null,
    );
    if (actor == null) return;

    // Calculate new local location
    // Currently, location is world space in viewport_widget (which is a bug according to the spec).
    // The spec says: "if the generator/viewport currently treat location as world-space... define here that persisted location is PARENT-RELATIVE"
    // For this simple TDD step: Local = World(child) - World(newParent)
    // We assume `actor.location` is currently in World space, and we'll convert it to new Parent's Local space.
    // Wait, if it's already in World space, we just subtract newParent's world space.

    List<double> getParentWorldLoc(String? pid) {
      if (pid == null) return [0.0, 0.0, 0.0];
      final p = _actors.cast<EditorActorNode?>().firstWhere(
        (a) => a?.id == pid,
        orElse: () => null,
      );
      if (p == null) return [0.0, 0.0, 0.0];
      final pWorld = getParentWorldLoc(p.parentId);
      return [
        pWorld[0] + p.location[0],
        pWorld[1] + p.location[1],
        pWorld[2] + p.location[2],
      ];
    }

    final oldWorld = getParentWorldLoc(actor.parentId);
    final myWorld = [
      oldWorld[0] + actor.location[0],
      oldWorld[1] + actor.location[1],
      oldWorld[2] + actor.location[2],
    ];

    final newWorld = getParentWorldLoc(newParentId);

    actor.parentId = newParentId;
    actor.location = [
      myWorld[0] - newWorld[0],
      myWorld[1] - newWorld[1],
      myWorld[2] - newWorld[2],
    ];

    _markDirty();
    notifyListeners();
  }

  void renameActor(String id, String newName) {
    if (newName.trim().isEmpty) return;
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == id,
      orElse: () => null,
    );
    if (actor == null) return;

    // Check sibling duplicate
    final siblings = actor.parentId == null
        ? rootActors
        : childrenOf(actor.parentId!);
    if (siblings.any((s) => s.id != id && s.name == newName)) return;

    final oldName = actor.name;
    actor.name = newName;
    _renameLevelBlueprintReferences(oldName, newName);
    _markDirty();
    notifyListeners();
  }

  @override
  void duplicateActorSubtree(String id) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == id,
      orElse: () => null,
    );
    if (actor == null) return;

    void duplicateDeep(EditorActorNode node, String? newParentId, bool isRoot) {
      final newId =
          DateTime.now().microsecondsSinceEpoch.toString() + '_' + node.id;
      final newName = isRoot ? '${node.name}_Copy' : '${node.name}_Copy';

      // Every field: a hand-picked list dropped the class, mesh and
      // components, so the copy of a placed Blueprint drew nothing.
      final clone = node.copy(id: newId, name: newName)..parentId = newParentId;
      _actors.add(clone);

      for (final child in childrenOf(node.id)) {
        duplicateDeep(child, newId, false);
      }
    }

    duplicateDeep(actor, actor.parentId, true);
    _markDirty();
    notifyListeners();
  }

  @override
  void deleteActorSubtree(String id, {bool keepChildren = false}) {
    final actor = _actors.where((a) => a.id == id).firstOrNull;
    if (actor == null) return;

    if (keepChildren) {
      final children = childrenOf(id).toList();
      for (final c in children) {
        c.parentId = actor.parentId;
      }
      _actors.removeWhere((a) => a.id == id);
    } else {
      void deleteDeep(String nodeId) {
        final children = childrenOf(nodeId).toList();
        for (final c in children) {
          deleteDeep(c.id);
        }
        _actors.removeWhere((a) => a.id == nodeId);
      }

      deleteDeep(id);
    }

    if (_selectedActor?.id == id) clearSelection();
    _selectedActorIds.remove(id);
    if (!keepChildren) {
      void removeSelectedDeep(String nodeId) {
        _selectedActorIds.remove(nodeId);
        final children = childrenOf(nodeId).toList();
        for (final c in children) {
          removeSelectedDeep(c.id);
        }
      }

      removeSelectedDeep(id);
    }
  }

  void deleteActorSubtreeWithTransaction(
    String id, {
    bool keepChildren = false,
  }) {
    final snapshot = _cloneActors(_actors.cast<EditorActorNode>());
    final selectedBefore = _selectedActor?.id;
    final selectedSetBefore = List<String>.from(_selectedActorIds);

    deleteActorSubtree(id, keepChildren: keepChildren);

    transactions.record(
      EditorTransaction(
        label: keepChildren ? 'Delete Actor (Keep Children)' : 'Delete Subtree',
        undo: () {
          _actors.clear();
          _actors.addAll(_cloneActors(snapshot));

          _selectedActorIds.clear();
          _selectedActorIds.addAll(selectedSetBefore);
          if (selectedBefore != null) {
            _selectedActor = _actors.cast<EditorActorNode?>().firstWhere(
              (a) => a?.id == selectedBefore,
              orElse: () => null,
            );
          }
          _markDirty();
          notifyListeners();
        },
        redo: () {
          deleteActorSubtree(id, keepChildren: keepChildren);
          _markDirty();
          notifyListeners();
        },
      ),
    );

    _markDirty();
    notifyListeners();
  }

  String get outlinerSearchQuery => _outlinerSearchQuery;
  void setOutlinerSearchQuery(String query) {
    _outlinerSearchQuery = query;
    notifyListeners();
  }

  String? get outlinerTypeFilter => _outlinerTypeFilter;
  void setOutlinerTypeFilter(String? type) {
    if (type == 'All') type = null;
    _outlinerTypeFilter = type;
    notifyListeners();
  }

  int get actorCount => _actors.where((a) => a.type != 'Folder').length;
  int get hiddenActorCount => _actors
      .where((a) => a.type != 'Folder' && !isEffectivelyVisible(a.id))
      .length;
  int get selectedCount => _selectedActorIds.length;

  bool isEffectivelyVisible(String id) {
    var current = _actors.where((a) => a.id == id).firstOrNull;
    while (current != null) {
      if (!current.isVisible) return false;
      if (current.parentId == null) break;
      current = _actors.where((a) => a.id == current!.parentId).firstOrNull;
    }
    return true;
  }

  bool isEffectivelyLocked(String id) {
    var current = _actors.where((a) => a.id == id).firstOrNull;
    while (current != null) {
      if (current.isLocked) return true;
      if (current.parentId == null) break;
      current = _actors.where((a) => a.id == current!.parentId).firstOrNull;
    }
    return false;
  }

  void setActorVisibilityWithTransaction(
    String id,
    bool visible, {
    bool recursive = false,
  }) {
    final actor = _actors.where((a) => a.id == id).firstOrNull;
    if (actor == null) return;

    final affected = <String>[];

    void applyRec(String currentId) {
      final a = _actors.where((x) => x.id == currentId).firstOrNull;
      if (a != null) {
        affected.add(currentId);
        a.isVisible = visible;
        for (final c in childrenOf(currentId)) {
          applyRec(c.id);
        }
      }
    }

    if (recursive) {
      applyRec(id);
    } else {
      if (actor.isVisible != visible) {
        affected.add(id);
        actor.isVisible = visible;
      }
    }

    if (affected.isEmpty) return;

    transactions.record(
      EditorTransaction(
        label: visible ? 'Show Actor' : 'Hide Actor',
        undo: () {
          for (final aff in affected) {
            final a = _actors.where((x) => x.id == aff).firstOrNull;
            if (a != null) a.isVisible = !visible;
          }
          _markDirty();
          notifyListeners();
        },
        redo: () {
          for (final aff in affected) {
            final a = _actors.where((x) => x.id == aff).firstOrNull;
            if (a != null) a.isVisible = visible;
          }
          _markDirty();
          notifyListeners();
        },
      ),
    );

    _markDirty();
    notifyListeners();
  }

  void setActorLockedWithTransaction(String id, bool locked) {
    final actor = _actors.where((a) => a.id == id).firstOrNull;
    if (actor == null || actor.isLocked == locked) return;

    actor.isLocked = locked;
    transactions.record(
      EditorTransaction(
        label: locked ? 'Lock Actor' : 'Unlock Actor',
        undo: () {
          final a = _actors.where((x) => x.id == id).firstOrNull;
          if (a != null) a.isLocked = !locked;
          _markDirty();
          notifyListeners();
        },
        redo: () {
          final a = _actors.where((x) => x.id == id).firstOrNull;
          if (a != null) a.isLocked = locked;
          _markDirty();
          notifyListeners();
        },
      ),
    );

    _markDirty();
    notifyListeners();
  }

  /// Whether an Outliner Solo is active (the next Solo click clears it).
  bool get isSoloActive => _soloSnapshot != null;

  /// Outliner → Solo / Clear Solo, each one undo step that restores the
  /// exact per-actor visibility it replaced.
  void toggleSoloWithTransaction(String id) {
    final before = {for (final a in _actors) a.id: a.isVisible};
    final Map<String, bool> after;
    final Map<String, bool>? snapshotAfter;
    final String label;
    if (_soloSnapshot != null) {
      final snapshot = _soloSnapshot!;
      after = {for (final a in _actors) a.id: snapshot[a.id] ?? true};
      snapshotAfter = null;
      label = 'Clear Solo';
    } else {
      after = {
        for (final a in _actors)
          a.id: a.id == id || _isAncestorOf(id, a.id) || _isAncestorOf(a.id, id),
      };
      snapshotAfter = before;
      label = 'Solo Actor';
    }
    final snapshotBefore = _soloSnapshot;

    void applyVisibility(Map<String, bool> visible, Map<String, bool>? snapshot) {
      for (final a in _actors) {
        final v = visible[a.id];
        if (v != null) a.isVisible = v;
      }
      _soloSnapshot = snapshot;
      _markDirty();
      notifyListeners();
    }

    applyVisibility(after, snapshotAfter);
    transactions.record(
      EditorTransaction(
        label: label,
        undo: () => applyVisibility(before, snapshotBefore),
        redo: () => applyVisibility(after, snapshotAfter),
      ),
    );
  }

  bool _isAncestorOf(String ancestorId, String descendantId) {
    var current = _actors.where((a) => a.id == descendantId).firstOrNull;
    while (current != null) {
      if (current.parentId == ancestorId) return true;
      if (current.parentId == null) break;
      current = _actors.where((a) => a.id == current!.parentId).firstOrNull;
    }
    return false;
  }

  // Transaction Wrappers
  void reparentActorWithTransaction(String id, String? newParentId) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == id,
      orElse: () => null,
    );
    if (actor == null) return;
    final oldParentId = actor.parentId;
    final oldLocation = List<double>.from(actor.location);

    if (newParentId == oldParentId) return;

    void apply(String? pid, List<double> loc) {
      actor.parentId = pid;
      actor.location = loc;
      _markDirty();
      notifyListeners();
    }

    // Perform calculation using standard method but we want to capture the NEW location
    reparentActor(id, newParentId);
    final newLocation = List<double>.from(actor.location);

    transactions.record(
      EditorTransaction(
        label: 'Reparent to $newParentId',
        undo: () => apply(oldParentId, oldLocation),
        redo: () => apply(newParentId, newLocation),
      ),
    );
  }

  void renameActorWithTransaction(String id, String newName) {
    final actor = _actors.cast<EditorActorNode?>().firstWhere(
      (a) => a?.id == id,
      orElse: () => null,
    );
    if (actor == null) return;
    final oldName = actor.name;

    renameActor(id, newName);
    if (actor.name != newName) return; // Means it failed duplicate/empty check

    transactions.record(
      EditorTransaction(
        label: 'Rename to $newName',
        undo: () {
          actor.name = oldName;
          _renameLevelBlueprintReferences(newName, oldName);
          _markDirty();
          notifyListeners();
        },
        redo: () {
          actor.name = newName;
          _renameLevelBlueprintReferences(oldName, newName);
          _markDirty();
          notifyListeners();
        },
      ),
    );
  }

  @override
  List<EditorActorNode> _cloneActors(List<EditorActorNode> source) =>
      // Complete copies: undo restoring a partial copy stripped
      // every placed Blueprint's class and every actor's mesh.
      [for (final a in source) a.copy()];
}
