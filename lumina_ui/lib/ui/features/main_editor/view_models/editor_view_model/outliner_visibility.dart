part of '../editor_view_model.dart';

/// World Outliner search and filters, actor counts, effective visibility and
/// lock, solo, and the undoable reparent/rename wrappers.
mixin _EditorOutlinerVisibility on _EditorViewModelState, _EditorOutliner {
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
