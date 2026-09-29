import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../main_editor/commands/editor_transaction.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../models/navigation_editor_state.dart';
import '../services/navigation_preview_scene.dart';

/// View model of the Navigation sub-editor.
///
/// Owns the `NavGridConfig` draft, the selected bounds volume, the path
/// tester endpoints and overlay visibility. [build] unions the level's
/// `NavMeshBoundsVolume` actors into the bounds handed to the real
/// `LuminaNavigationSystem.buildFromWorld` over a collision world derived
/// from the level's mesh geometry, then snapshots per-cell occupancy for the
/// overlay; [testPath] issues real `findPathSync` queries under a stopwatch.
/// Config persists in the level's `navigation` section; volumes are ordinary
/// level actors (undo / outliner / save reuse the editor plumbing).
///
/// Units and axes: everything here is world units (cm). The grid, obstacle
/// boxes, path points and click positions are in runtime axes (Y up); stored
/// actor transforms are authoring axes (Z up) and cross over only through
/// [LuminaAxes] (see [NavMeshBoundsVolume] / [NavigationWorldBuilder]).
class NavigationEditorViewModel extends ChangeNotifier {
  final EditorViewModel editor;
  final NavigationPreviewScene preview;

  /// Debounce applied to auto-rebuilds after scene / config changes.
  final Duration autoRebuildDebounce;

  NavigationEditorConfig _config = NavigationEditorConfig.defaults();
  NavigationEditorConfig? _gestureStart;
  LuminaNavigationSystem? _nav;
  LuminaWorld? _navWorld;
  NavGridSnapshot? _snapshot;
  NavBuildResult? _lastBuild;
  bool _isBuilding = false;
  bool _isStale = false;
  int _buildCount = 0;
  String? _buildError;

  NavPathResult? _pathResult;
  Vector3? _pathStart;
  Vector3? _pathGoal;
  bool _pathTesterMode = false;
  bool _overlayVisible = true;

  String? _selectedVolumeId;
  String _volumeFilter = '';

  bool _dirty = false;
  bool _opened = false;
  bool _disposed = false;
  String _sceneSignature = '';
  int _seenBuildRequests = 0;
  Timer? _debounce;

  NavigationEditorViewModel({
    required this.editor,
    NavigationPreviewScene? preview,
    this.autoRebuildDebounce = const Duration(milliseconds: 500),
  }) : preview = preview ?? NavigationPreviewScene();

  // --- State -----------------------------------------------------------------

  NavigationEditorConfig get config => _config;
  bool get isDirty => _dirty;
  bool get isOpened => _opened;
  bool get isBuilding => _isBuilding;

  /// The scene or config changed since the last build.
  bool get isStale => _isStale;
  int get buildCount => _buildCount;
  String? get buildError => _buildError;
  NavBuildResult? get lastBuild => _lastBuild;
  NavGridSnapshot? get snapshot => _snapshot;

  /// The live engine backend of the last build (null before any build).
  LuminaNavigationSystem? get navigation => _nav;
  NavPathResult? get pathResult => _pathResult;
  Vector3? get pathStart => _pathStart;
  Vector3? get pathGoal => _pathGoal;
  bool get pathTesterMode => _pathTesterMode;
  bool get overlayVisible => _overlayVisible;
  bool get isPreviewAttached => preview.isAttached;
  String get volumeFilter => _volumeFilter;

  /// The engine backend this editor drives — a walkable grid, not Recast.
  static const String backendLabel = 'Walkable grid + A* (LuminaNavigationSystem)';

  List<EditorActorNode> get volumes => editor.actors.where(NavMeshBoundsVolume.isVolume).toList();

  List<EditorActorNode> get filteredVolumes {
    final q = _volumeFilter.trim().toLowerCase();
    if (q.isEmpty) return volumes;
    return volumes.where((v) => v.name.toLowerCase().contains(q)).toList();
  }

  EditorActorNode? get selectedVolume {
    final id = _selectedVolumeId;
    if (id == null) return null;
    for (final v in volumes) {
      if (v.id == id) return v;
    }
    return null;
  }

  bool get canBuild => volumes.isNotEmpty && !_isBuilding;

  String get buildDisabledReason {
    if (_isBuilding) return 'A build is running.';
    if (volumes.isEmpty) return 'Add a NavMeshBoundsVolume first — the grid is baked inside the volumes\' bounds.';
    return '';
  }

  // --- HUD (computed values only) ----------------------------------------------

  String get hudWalkableLabel {
    final b = _lastBuild;
    return b == null ? '' : 'Walkable Cells: ${b.walkableCells}';
  }

  String get hudGridLabel {
    final b = _lastBuild;
    return b == null ? '' : 'Grid: ${b.cols}×${b.rows} @ ${formatCm(b.cellSize)} cm';
  }

  /// A length in world units for display: whole centimetres print without
  /// decimals, anything finer keeps one.
  static String formatCm(double cm) => cm == cm.roundToDouble() ? cm.toStringAsFixed(0) : cm.toStringAsFixed(1);

  String get hudPathLabel {
    final r = _pathResult;
    if (r == null) return '';
    switch (r.state) {
      case NavPathState.found:
      case NavPathState.partial:
        return 'Path: ${r.pointCount} points, ${r.length.toStringAsFixed(0)} cm, ${r.queryTimeMs.toStringAsFixed(3)} ms';
      case NavPathState.noPath:
        return 'No path (${r.queryTimeMs.toStringAsFixed(3)} ms)';
      case NavPathState.none:
        return '';
    }
  }

  /// `Partial path` / `No path` badge text, null when a full path exists.
  String? get hudPathBadge {
    switch (_pathResult?.state) {
      case NavPathState.partial:
        return 'Partial path';
      case NavPathState.noPath:
        return 'No path';
      default:
        return null;
    }
  }

  /// Bottom-bar debug line for the last query. Endpoints print as the
  /// Details panel shows locations: authoring X / Y (the Z-up ground plane),
  /// in cm.
  String get pathDebugLine {
    final r = _pathResult;
    if (r == null) return '';
    // Whole cm; the axis flip must not print "-0".
    String c(double v) {
      final r = v.roundToDouble();
      return (r == 0 ? 0.0 : r).toStringAsFixed(0);
    }

    String v(Vector3 p) {
      final a = LuminaAxes.toAuthoringLocation(p);
      return '(${c(a[0])}, ${c(a[1])})';
    }

    final head = '${v(r.start)} → ${v(r.goal)} cm';
    if (r.path == null) return '$head: no path — ${r.queryTimeMs.toStringAsFixed(3)} ms';
    return '$head: ${r.pointCount} smoothed points, ${r.length.toStringAsFixed(0)} cm, ${r.queryTimeMs.toStringAsFixed(3)} ms${r.path!.isPartial ? ' (partial)' : ''}';
  }

  String get lastBuildLabel {
    final b = _lastBuild;
    if (b == null) return _buildError ?? 'Not built yet';
    final t = b.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Built in ${b.durationMs.toStringAsFixed(1)} ms at ${two(t.hour)}:${two(t.minute)}:${two(t.second)} — '
        '${b.walkableCells}/${b.cellCount} cells walkable, ${b.obstacleCount} obstacles, ${b.volumeCount} volumes';
  }

  // --- Lifecycle ---------------------------------------------------------------

  /// Loads the level's `navigation` section, subscribes to the editor and
  /// runs an initial build when volumes exist (baked data is derived state
  /// and never persisted).
  void open() {
    if (_opened) return;
    _opened = true;
    _level = editor.project.activeLevel;
    final section = editor.levelNavigation;
    if (section.isNotEmpty) {
      _config = NavigationEditorConfig.fromSection(section);
    }
    _sceneSignature = NavigationWorldBuilder.signature(editor.actors);
    _seenBuildRequests = editor.navigationBuildRequests;
    _selectedVolumeId ??= volumes.isEmpty ? null : volumes.first.id;
    editor.addListener(_onEditorChanged);
    if (volumes.isNotEmpty) {
      build();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    if (_opened) editor.removeListener(_onEditorChanged);
    preview.detach();
    super.dispose();
  }

  /// The level the tab shows (it follows a level switch).
  String? _level;

  /// Another level was opened: its own navigation settings and volumes.
  void _reloadLevel() {
    _level = editor.project.activeLevel;
    final section = editor.levelNavigation;
    _config = section.isNotEmpty ? NavigationEditorConfig.fromSection(section) : NavigationEditorConfig.defaults();
    _dropBuild();
    _sceneSignature = NavigationWorldBuilder.signature(editor.actors);
    _seenBuildRequests = editor.navigationBuildRequests;
    _selectedVolumeId = volumes.isEmpty ? null : volumes.first.id;
    if (volumes.isNotEmpty) {
      build();
    } else {
      notifyListeners();
    }
  }

  void _onEditorChanged() {
    if (_disposed) return;
    if (editor.project.activeLevel != _level) {
      _reloadLevel();
      return;
    }
    var changed = false;
    if (editor.navigationBuildRequests != _seenBuildRequests) {
      _seenBuildRequests = editor.navigationBuildRequests;
      if (canBuild) {
        build();
      }
      changed = true;
    }
    final sig = NavigationWorldBuilder.signature(editor.actors);
    if (sig != _sceneSignature) {
      _sceneSignature = sig;
      _isStale = _lastBuild != null;
      if (volumes.isEmpty) {
        _dropBuild();
      } else if (_config.autoRebuild) {
        _scheduleAutoRebuild();
      }
      changed = true;
    }
    if (_selectedVolumeId != null && selectedVolume == null) {
      _selectedVolumeId = volumes.isEmpty ? null : volumes.first.id;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _scheduleAutoRebuild() {
    _debounce?.cancel();
    _debounce = Timer(autoRebuildDebounce, () {
      _debounce = null;
      if (_disposed || !canBuild) return;
      build();
    });
  }

  void _dropBuild() {
    _nav = null;
    _navWorld = null;
    _snapshot = null;
    _lastBuild = null;
    _pathResult = null;
    _isStale = false;
    _pushPreviewOverlay();
    _pushPreviewPath();
  }

  // --- Volumes -----------------------------------------------------------------

  void setVolumeFilter(String value) {
    _volumeFilter = value;
    notifyListeners();
  }

  void selectVolume(String? id) {
    _selectedVolumeId = id;
    if (id != null) editor.selectActorById(id);
    notifyListeners();
  }

  /// Spawns a `NavMeshBoundsVolume` centred on the viewport pivot (bottom
  /// face resting on the pivot height) with the default 20×20 m, 5 m tall
  /// extent, as one undoable level edit. The pivot is an authoring (Z-up)
  /// point; the volume is lifted along the runtime up axis and written back
  /// through [LuminaAxes.toAuthoringLocation].
  EditorActorNode addBoundsVolume() {
    final extent = NavMeshBoundsVolume.defaultExtentMetres;
    final pivot = LuminaAxes.location([editor.cameraPanX, editor.cameraPanY, editor.cameraPanZ]);
    final halfHeight = LuminaAxes.scale(extent).y * LuminaUnits.unitsPerMetre / 2;
    final centre = pivot + Vector3(0.0, halfHeight, 0.0);
    final node = EditorActorNode(
      id: _uniqueId('act_nav'),
      name: _uniqueName(NavMeshBoundsVolume.defaultName),
      type: NavMeshBoundsVolume.actorType,
      location: LuminaAxes.toAuthoringLocation(centre),
      scale: List<double>.from(extent),
      mobility: 'Static',
    );
    editor.addActorNode(node, label: 'Add ${NavMeshBoundsVolume.actorType}');
    _selectedVolumeId = node.id;
    _dirty = true;
    notifyListeners();
    return node;
  }

  void deleteVolume(String id) {
    if (!editor.actors.any((a) => a.id == id)) return;
    editor.deleteActorSubtreeWithTransaction(id);
    if (_selectedVolumeId == id) _selectedVolumeId = volumes.isEmpty ? null : volumes.first.id;
    _dirty = true;
    notifyListeners();
  }

  void renameVolume(String id, String name) {
    if (name.trim().isEmpty) return;
    editor.renameActorWithTransaction(id, name.trim());
    _dirty = true;
    notifyListeners();
  }

  void focusVolume(String id) {
    final actor = editor.actors.cast<EditorActorNode?>().firstWhere((a) => a!.id == id, orElse: () => null);
    if (actor == null) return;
    _selectedVolumeId = id;
    editor.focusCameraOnActor(actor);
    notifyListeners();
  }

  /// Writes the centre along authoring [axis] (0..2 = X / Y / Z, Z up — the
  /// Details panel's Location) in cm through to the actor location.
  void setVolumeCenter(String id, int axis, double cm, {bool commit = true}) {
    final actor = _volumeById(id);
    if (actor == null) return;
    if (editor.selectedActorId != id || editor.selectedActorIds.length != 1) editor.selectActorById(id);
    final loc = List<double>.from(actor.location);
    loc[axis] = cm;
    editor.updateActorLocation(loc, isCommit: commit);
    _dirty = true;
    notifyListeners();
  }

  /// Writes the size along authoring [axis] (0..2 = X / Y / Z, Z up) in cm
  /// through to the actor scale, which is that size in metres.
  void setVolumeExtent(String id, int axis, double cm, {bool commit = true}) {
    final actor = _volumeById(id);
    if (actor == null) return;
    if (editor.selectedActorId != id || editor.selectedActorIds.length != 1) editor.selectActorById(id);
    final scale = List<double>.from(actor.scale);
    final size = cm.abs() < NavMeshBoundsVolume.minExtentCm ? NavMeshBoundsVolume.minExtentCm : cm.abs();
    scale[axis] = LuminaUnits.toMetres(size);
    editor.updateActorScale(scale, isCommit: commit);
    _dirty = true;
    notifyListeners();
  }

  EditorActorNode? _volumeById(String id) {
    for (final v in volumes) {
      if (v.id == id) return v;
    }
    return null;
  }

  String _uniqueId(String base) {
    final ids = editor.actors.map((a) => a.id).toSet();
    var i = 1;
    while (ids.contains('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  String _uniqueName(String base) {
    final names = editor.actors.map((a) => a.name).toSet();
    if (!names.contains(base)) return base;
    var i = 2;
    while (names.contains('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  // --- Config ----------------------------------------------------------------

  void _updateConfig(NavigationEditorConfig next, {required bool commit, required String label}) {
    if (!commit) {
      _gestureStart ??= _config;
      _config = next;
      notifyListeners();
      return;
    }
    final before = _gestureStart ?? _config;
    _gestureStart = null;
    _config = next;
    if (before != next) {
      _dirty = true;
      _syncToEditor();
      editor.transactions.record(
        EditorTransaction(
          label: label,
          undo: () => _restoreConfig(before),
          redo: () => _restoreConfig(next),
        ),
      );
      _afterConfigCommit();
    }
    notifyListeners();
  }

  void _restoreConfig(NavigationEditorConfig c) {
    _config = c;
    _dirty = true;
    _syncToEditor();
    _afterConfigCommit();
    notifyListeners();
  }

  void _afterConfigCommit() {
    if (_lastBuild != null) _isStale = true;
    if (_config.autoRebuild && canBuild) _scheduleAutoRebuild();
  }

  /// Cell size in cm.
  void setCellSize(double v, {bool commit = true}) => _updateConfig(
        _config.copyWith(cellSize: v.clamp(NavigationEditorConfig.minCellSize, NavigationEditorConfig.maxCellSize)),
        commit: commit,
        label: 'Nav Cell Size',
      );

  /// Agent radius in cm.
  void setAgentRadius(double v, {bool commit = true}) => _updateConfig(
        _config.copyWith(agentRadius: v.clamp(0.0, NavigationEditorConfig.maxAgentRadius)),
        commit: commit,
        label: 'Nav Agent Radius',
      );

  /// Agent height in cm.
  void setAgentHeight(double v, {bool commit = true}) => _updateConfig(
        _config.copyWith(
          agentHeight: v.clamp(NavigationEditorConfig.minAgentHeight, NavigationEditorConfig.maxAgentHeight),
        ),
        commit: commit,
        label: 'Nav Agent Height',
      );

  /// Max step height in cm.
  void setMaxStepHeight(double v, {bool commit = true}) => _updateConfig(
        _config.copyWith(maxStepHeight: v.clamp(0.0, NavigationEditorConfig.maxStepHeightLimit)),
        commit: commit,
        label: 'Nav Max Step Height',
      );

  void setWalkableLayerMask(int mask) =>
      _updateConfig(_config.copyWith(walkableLayerMask: mask & 0xFFFFFFFF), commit: true, label: 'Nav Walkable Layer Mask');

  /// Parses `0xFF`, `FF` or decimal input; returns false when unparsable.
  bool setWalkableLayerMaskText(String text) {
    var t = text.trim().toLowerCase();
    int? mask;
    if (t.startsWith('0x')) {
      mask = int.tryParse(t.substring(2), radix: 16);
    } else {
      mask = int.tryParse(t) ?? int.tryParse(t, radix: 16);
    }
    if (mask == null) return false;
    setWalkableLayerMask(mask);
    return true;
  }

  String get walkableLayerMaskHex => '0x${_config.walkableLayerMask.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  void setAutoRebuild(bool on) {
    _updateConfig(_config.copyWith(autoRebuild: on), commit: true, label: on ? 'Nav Auto-rebuild On' : 'Nav Auto-rebuild Off');
    if (on && _isStale && canBuild) _scheduleAutoRebuild();
  }

  void _syncToEditor() {
    editor.setLevelNavigation(_config.toSection(volumes: volumes));
  }

  // --- Build ----------------------------------------------------------------

  /// Runs the real grid bake. Returns null (and logs) when there is nothing
  /// to bake; never throws into the UI.
  NavBuildResult? build() {
    if (!canBuild) {
      editor.logger.log('Navigation build skipped: $buildDisabledReason', level: 'warning', source: 'Navigation');
      return null;
    }
    _debounce?.cancel();
    _debounce = null;
    _isBuilding = true;
    _buildError = null;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      final vols = volumes;
      final bounds = NavMeshBoundsVolume.unionBounds(vols)!;
      final gridConfig = _config.toNavGridConfig();
      final boxes = NavigationWorldBuilder.obstaclesFrom(editor.actors)
          .where((b) => NavigationWorldBuilder.intersectsXZ(b, bounds))
          .where((b) => NavigationWorldBuilder.blocksAgent(b, groundY: bounds.min.y, config: gridConfig))
          .toList();
      final world = NavigationWorldBuilder.buildWorld(boxes);
      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);
      nav.buildFromWorld(bounds: bounds, config: gridConfig);
      final snap = NavGridSnapshot.capture(nav, bounds);
      sw.stop();
      _navWorld = world;
      _nav = nav;
      _snapshot = snap;
      _lastBuild = NavBuildResult(
        finishedAt: DateTime.now(),
        duration: sw.elapsed,
        walkableCells: nav.walkableCellCount,
        cols: snap.cols,
        rows: snap.rows,
        cellSize: gridConfig.cellSize,
        bounds: bounds,
        obstacleCount: boxes.length,
        volumeCount: vols.length,
      );
      _buildCount++;
      _isStale = false;
      _sceneSignature = NavigationWorldBuilder.signature(editor.actors);
      editor.logger.log(
        'Navigation build: ${snap.cols}×${snap.rows} cells @ ${formatCm(gridConfig.cellSize)} cm, ${nav.walkableCellCount} walkable, ${boxes.length} obstacles, ${vols.length} volumes in ${_lastBuild!.durationMs.toStringAsFixed(1)} ms',
        level: 'success',
        source: 'Navigation',
      );
      // Re-run the path test on the fresh grid so the HUD never shows stale data.
      if (_pathStart != null && _pathGoal != null) {
        _pathResult = _query(_pathStart!, _pathGoal!);
      }
    } catch (e, st) {
      sw.stop();
      _buildError = 'Build failed: $e';
      editor.logger.log('Navigation build failed: $e\n$st', level: 'error', source: 'Navigation');
    } finally {
      _isBuilding = false;
    }
    _pushPreviewOverlay();
    _pushPreviewPath();
    notifyListeners();
    return _lastBuild;
  }

  // --- Path tester -----------------------------------------------------------

  void setPathTesterMode(bool on) {
    _pathTesterMode = on;
    notifyListeners();
  }

  void setOverlayVisible(bool visible) {
    _overlayVisible = visible;
    _pushPreviewOverlay();
    notifyListeners();
  }

  /// Runs `findPathSync` between [start] and [goal] (runtime axes, cm) under
  /// a stopwatch.
  NavPathResult testPath(Vector3 start, Vector3 goal) {
    _pathStart = Vector3.copy(start);
    _pathGoal = Vector3.copy(goal);
    _pathResult = _query(start, goal);
    _pushPreviewPath();
    notifyListeners();
    return _pathResult!;
  }

  NavPathResult _query(Vector3 start, Vector3 goal) {
    final nav = _nav;
    if (nav == null || !nav.isBuilt) {
      return NavPathResult(start: start, goal: goal, path: null, queryTimeMs: 0.0, state: NavPathState.noPath);
    }
    final sw = Stopwatch()..start();
    NavPath? path;
    try {
      path = nav.findPathSync(start, goal, allowPartialPath: true, smooth: true);
    } catch (e) {
      editor.logger.log('Navigation path query failed: $e', level: 'error', source: 'Navigation');
      path = null;
    }
    sw.stop();
    final ms = sw.elapsedTicks / sw.frequency * 1000.0;
    final state = path == null
        ? NavPathState.noPath
        : path.isPartial
            ? NavPathState.partial
            : NavPathState.found;
    editor.logger.log(
      'Navigation path ${state.name}: ${path?.points.length ?? 0} points, ${(path?.length ?? 0).toStringAsFixed(0)} cm, ${ms.toStringAsFixed(3)} ms',
      level: state == NavPathState.noPath ? 'warning' : 'info',
      source: 'Navigation',
    );
    return NavPathResult(start: start, goal: goal, path: path, queryTimeMs: ms, state: state);
  }

  /// Click-driven placement: [world] is the viewport's floor hit in runtime
  /// axes (Y up), cm — the grid's own space. The first click drops the start
  /// flag, the second the goal; later clicks move whichever flag is nearer.
  /// Endpoints are projected onto the grid by the engine itself.
  void placePathPoint(Vector3 world) {
    final p = Vector3.copy(world);
    if (_pathStart == null) {
      _pathStart = p;
      _pathResult = null;
      _pushPreviewPath();
      notifyListeners();
      return;
    }
    if (_pathGoal == null) {
      testPath(_pathStart!, p);
      return;
    }
    final ds = (_pathStart! - p).length2;
    final dg = (_pathGoal! - p).length2;
    if (ds < dg) {
      testPath(p, _pathGoal!);
    } else {
      testPath(_pathStart!, p);
    }
  }

  void clearPath() {
    _pathStart = null;
    _pathGoal = null;
    _pathResult = null;
    _pushPreviewPath();
    notifyListeners();
  }

  // --- Persistence -----------------------------------------------------------

  /// Saves the level (`.lmas` + generated Dart) through the editor.
  Future<bool> save() async {
    _gestureStart = null;
    _syncToEditor();
    try {
      await editor.saveLevelAndGenerateCode();
    } catch (e) {
      editor.logger.log('Navigation save failed: $e', level: 'error', source: 'Navigation');
      return false;
    }
    _dirty = false;
    notifyListeners();
    return true;
  }

  // --- Live preview ------------------------------------------------------------

  /// Called by the viewport once its lumina world exists on the live engine.
  void attachPreview(LuminaWorld world) {
    preview.attach(world, levelActors: editor.actors, projectDirPath: editor.projectDirPath);
    _pushPreviewOverlay();
    _pushPreviewPath();
    notifyListeners();
  }

  /// Called by the viewport right before it cleans the world up.
  void detachPreview(LuminaWorld world) {
    preview.detach();
    if (!_disposed) notifyListeners();
  }

  void _pushPreviewOverlay() {
    if (!preview.isAttached) return;
    preview.setOverlay(_snapshot, visible: _overlayVisible);
  }

  void _pushPreviewPath() {
    if (!preview.isAttached) return;
    preview.setPath(
      pathPoints: _pathResult?.path?.points,
      start: _pathStart,
      goal: _pathGoal,
      isPartial: _pathResult?.path?.isPartial ?? false,
    );
  }

  /// Floor height (runtime Y, cm) the path-tester clicks are unprojected
  /// onto: the baked grid's ground, or the volumes' bottom before a build.
  double get floorTapPlaneCm {
    final snap = _snapshot;
    if (snap != null) return snap.floorY;
    final bounds = NavMeshBoundsVolume.unionBounds(volumes);
    return bounds == null ? 0.0 : bounds.min.y;
  }

  /// The collision world of the last build (tests / diagnostics).
  @visibleForTesting
  LuminaWorld? get navWorldForTest => _navWorld;
}
