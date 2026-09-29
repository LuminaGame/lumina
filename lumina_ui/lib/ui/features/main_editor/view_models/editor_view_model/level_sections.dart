part of '../editor_view_model.dart';

/// The level's environment, navigation and World Partition sections.
mixin _EditorLevelSections on _EditorViewModelState {
  /// The active level's `environment` payload section as last loaded/edited
  /// (see `EnvironmentLightingViewModel`); empty for levels without one.
  Map<String, dynamic> get levelEnvironment =>
      Map.unmodifiable(_levelEnvironment);

  /// Replaces the level's `environment` section and marks the level dirty so
  /// auto-save / Save Level persist it with the actors.
  void setLevelEnvironment(Map<String, dynamic> section) {
    _levelEnvironment = Map<String, dynamic>.from(section);
    _markDirty();
  }

  @override
  void _loadLevelEnvironment(dynamic metadata) {
    _levelEnvironment = {};
    if (metadata is Map && metadata['environment'] is Map) {
      _levelEnvironment = Map<String, dynamic>.from(
        metadata['environment'] as Map,
      );
    }
  }

  /// The active level's `navigation` payload section as last loaded/edited
  /// (see `NavigationEditorViewModel`); empty for levels without one.
  Map<String, dynamic> get levelNavigation =>
      Map.unmodifiable(_levelNavigation);

  /// Replaces the level's `navigation` section and marks the level dirty so
  /// auto-save / Save Level persist it with the actors.
  void setLevelNavigation(Map<String, dynamic> section) {
    _levelNavigation = Map<String, dynamic>.from(section);
    _markDirty();
  }

  @override
  void _loadLevelNavigation(dynamic metadata) {
    _levelNavigation = {};
    if (metadata is Map && metadata['navigation'] is Map) {
      _levelNavigation = Map<String, dynamic>.from(
        metadata['navigation'] as Map,
      );
    }
  }

  /// The active level's `worldPartition` payload section as last loaded or
  /// edited; empty for levels that do not author one.
  Map<String, dynamic> get levelWorldPartition =>
      Map.unmodifiable(_levelWorldPartition);

  /// Replaces the level's `worldPartition` section and marks the level dirty.
  void setLevelWorldPartition(Map<String, dynamic> section) {
    _levelWorldPartition = Map<String, dynamic>.from(section);
    _markDirty();
    notifyListeners();
  }

  @override
  void _loadLevelWorldPartition(dynamic metadata) {
    _levelWorldPartition = {};
    if (metadata is Map && metadata['worldPartition'] is Map) {
      _levelWorldPartition = Map<String, dynamic>.from(
        metadata['worldPartition'] as Map,
      );
    }
  }

  /// Whether the active level authors an enabled world partition.
  @override
  bool get worldPartitionEnabled => _levelWorldPartition['enabled'] == true;

  /// Grid cell edge length in metres (`LuminaWorldPartitionSubsystem.cellSize`).
  @override
  double get worldPartitionCellSize {
    final v = _levelWorldPartition['cellSize'];
    return v is num ? v.toDouble() : kWorldPartitionDefaultCellSize;
  }

  /// Streaming radius in metres applied to sources that author none
  /// (`LuminaStreamingSourceComponent.loadingRadius`).
  double get worldPartitionLoadingRange {
    final v = _levelWorldPartition['loadingRange'];
    return v is num ? v.toDouble() : kWorldPartitionDefaultLoadingRange;
  }

  /// Cell state transitions the subsystem may run per tick.
  int get worldPartitionMaxCellTransitionsPerTick {
    final v = _levelWorldPartition['maxCellTransitionsPerTick'];
    return v is num
        ? v.toInt()
        : kWorldPartitionDefaultMaxCellTransitionsPerTick;
  }

  /// The authored data layers (`name`, `initialState`, `isRuntime`).
  List<Map<String, dynamic>> get worldPartitionDataLayers {
    final raw = _levelWorldPartition['dataLayers'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Turns the section on (seeding the runtime's own defaults) or off.
  /// Disabling keeps the authored values so toggling back does not lose them.
  /// One undo step; undoing the first Enable removes the
  /// section it seeded.
  void setWorldPartitionEnabled(bool v) {
    _editWorldPartition(v ? 'World Partition Enabled' : 'World Partition Disabled', () {
      if (v && _levelWorldPartition.isEmpty) {
        _levelWorldPartition = defaultWorldPartitionSection();
      } else {
        _levelWorldPartition['enabled'] = v;
      }
    });
  }

  void _setWorldPartitionField(String key, Object value) {
    if (_levelWorldPartition.isEmpty) {
      _levelWorldPartition = defaultWorldPartitionSection();
    }
    _levelWorldPartition[key] = value;
  }

  /// A deep copy of the section (its values are JSON: numbers, bools,
  /// strings and the data-layer maps).
  Map<String, dynamic> _copyWorldPartition(Map<String, dynamic> section) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(section)) as Map);

  /// Runs [apply] on the section as one level undo step labelled [label]
  /// (the setters used to record nothing). With `commit ==
  /// false` (a Details scrub in progress) the change is only previewed; the
  /// commit that follows records one step from the pre-gesture section. An
  /// edit that changes nothing records nothing.
  void _editWorldPartition(String label, void Function() apply, {bool commit = true}) {
    final before = _worldPartitionGestureStart ?? _copyWorldPartition(_levelWorldPartition);
    apply();
    _markDirty();
    notifyListeners();
    if (!commit) {
      _worldPartitionGestureStart = before;
      return;
    }
    _worldPartitionGestureStart = null;
    _recordWorldPartitionEdit(label, before);
  }

  /// Records the change from [before] to the current section as one level
  /// undo step.
  void _recordWorldPartitionEdit(String label, Map<String, dynamic> before) {
    final after = _copyWorldPartition(_levelWorldPartition);
    if (jsonEncode(before) == jsonEncode(after)) return;
    void restore(Map<String, dynamic> section) {
      _levelWorldPartition = _copyWorldPartition(section);
      _markDirty();
      notifyListeners();
    }

    transactions.record(EditorTransaction(
      label: label,
      undo: () => restore(before),
      redo: () => restore(after),
    ));
  }

  /// Cell edge length in cm; clamped to a positive value because the
  /// runtime divides by it.
  void setWorldPartitionCellSize(double v, {bool commit = true}) => _editWorldPartition(
      'World Partition Cell Size', () => _setWorldPartitionField('cellSize', v <= 0 ? 1.0 : v),
      commit: commit);

  void setWorldPartitionLoadingRange(double v, {bool commit = true}) => _editWorldPartition(
      'World Partition Loading Range', () => _setWorldPartitionField('loadingRange', v < 0 ? 0.0 : v),
      commit: commit);

  void setWorldPartitionMaxCellTransitionsPerTick(int v, {bool commit = true}) => _editWorldPartition(
      'World Partition Max Cell Transitions',
      () => _setWorldPartitionField('maxCellTransitionsPerTick', v < 1 ? 1 : v),
      commit: commit);

  /// Appends a data layer the generated code really registers with
  /// `LuminaDataLayerManager.registerLayer`; returns its name, made unique
  /// among the level's layers.
  String addWorldPartitionDataLayer([String name = 'DataLayer']) {
    final layers = worldPartitionDataLayers;
    final taken = layers.map((l) => l['name']).toSet();
    var unique = name;
    var i = 1;
    while (taken.contains(unique)) {
      unique = '$name$i';
      i++;
    }
    layers.add({'name': unique, 'initialState': 'unloaded', 'isRuntime': true});
    _editWorldPartition('Add Data Layer $unique', () => _setWorldPartitionField('dataLayers', layers));
    return unique;
  }

  void removeWorldPartitionDataLayer(int index) {
    final layers = worldPartitionDataLayers;
    if (index < 0 || index >= layers.length) return;
    final removed = layers.removeAt(index);
    _editWorldPartition('Remove Data Layer ${removed['name']}', () => _setWorldPartitionField('dataLayers', layers));
  }

  void setWorldPartitionDataLayerName(int index, String name) {
    final layers = worldPartitionDataLayers;
    if (index < 0 || index >= layers.length) return;
    layers[index]['name'] = name;
    _editWorldPartition('Rename Data Layer', () => _setWorldPartitionField('dataLayers', layers));
  }

  /// [state] is one of `unloaded`, `loaded`, `activated` — the three
  /// `DataLayerState` values the runtime has.
  void setWorldPartitionDataLayerState(int index, String state) {
    final layers = worldPartitionDataLayers;
    if (index < 0 || index >= layers.length) return;
    layers[index]['initialState'] = state;
    _editWorldPartition('Data Layer State', () => _setWorldPartitionField('dataLayers', layers));
  }

  /// The grid cell [actor] falls in, computed exactly the way
  /// `LuminaWorldPartitionSubsystem.cellAt` does it: the X/Z ground plane,
  /// `floor(x / cellSize)` and `floor(z / cellSize)`. Height is not a grid
  /// axis. The runtime once used X and Y, which made cells vertical
  /// slabs; this mirrors the runtime rather than quietly
  /// disagreeing with it.
  (int, int) worldPartitionCellOf(EditorActorNode actor) {
    final size = worldPartitionCellSize;
    // The runtime grid is its X/Z ground plane; stored locations are Z up
    // so go through the shared axis rule.
    final runtime = LuminaAxes.location(actor.location);
    return (
      (runtime.x / size).floor(),
      (runtime.z / size).floor(),
    );
  }

  /// `"x, y"` for the outliner's cell column, or null when the level authors
  /// no enabled partition.
  String? worldPartitionCellLabel(EditorActorNode actor) {
    if (!worldPartitionEnabled) return null;
    final cell = worldPartitionCellOf(actor);
    return '${cell.$1}, ${cell.$2}';
  }

  /// Monotonic counter bumped by `Build → Build Navigation`; the open
  /// Navigation sub-editor runs the real grid bake when it changes.
  int get navigationBuildRequests => _navigationBuildRequests;

  /// `Build → Build Navigation`: opens (or focuses) the Navigation workspace
  /// tab and asks it to run the same bake as its own Build button.
  @override
  void requestNavigationBuild() {
    openSubEditorTab('navmesh', title: 'Navigation');
    _navigationBuildRequests++;
    _logger.log(
      'Build Navigation requested',
      level: 'info',
      source: 'Navigation',
    );
    notifyListeners();
  }
}
