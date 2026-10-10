part of '../navigation_editor_view_model.dart';

/// The path tester: the clicked start / goal flags and the `findPathSync`
/// query between them.
mixin _NavigationPathTester on ChangeNotifier {
  // Provided by NavigationEditorViewModel.
  EditorViewModel get editor;
  LuminaNavigationSystem? get _nav;
  void _pushPreviewPath();

  NavPathResult? _pathResult;
  Vector3? _pathStart;
  Vector3? _pathGoal;
  bool _pathTesterMode = false;

  // --- Path tester -----------------------------------------------------------

  void setPathTesterMode(bool on) {
    _pathTesterMode = on;
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
}
