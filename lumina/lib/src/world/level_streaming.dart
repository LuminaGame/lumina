import 'dart:async';
import 'level.dart';

/// Handles asynchronous level streaming, 7-state lifecycle management, and visibility transitions per sub-level.
class LuminaLevelStreaming {
  final String levelPath;
  final LuminaLevel levelInstance;

  bool bShouldBeLoaded;
  bool bShouldBeVisible;
  bool bDisableDistanceStreaming;

  final StreamController<LevelState> _stateController = StreamController<LevelState>.broadcast(sync: true);

  void Function(LuminaLevelStreaming)? onLevelLoaded;
  void Function(LuminaLevelStreaming)? onLevelShown;
  void Function(LuminaLevelStreaming)? onLevelHidden;
  void Function(LuminaLevelStreaming)? onLevelUnloaded;

  Future<LuminaLevel>? _inFlightLoad;
  Future<void>? _inFlightVisibility;
  Future<void>? _inFlightUnload;
  bool? _desiredVisible;

  LuminaLevelStreaming({
    required this.levelPath,
    required this.levelInstance,
    this.bShouldBeLoaded = true,
    this.bShouldBeVisible = false,
    this.bDisableDistanceStreaming = false,
  });

  /// The current lifecycle state of this streaming level.
  LevelState get state => levelInstance.state;

  /// Broadcast stream of state changes.
  Stream<LevelState> get onStateChanged => _stateController.stream;

  /// Whether the level is currently in an asynchronous transitional state.
  bool get isTransitioning =>
      state == LevelState.loading ||
      state == LevelState.makingVisible ||
      state == LevelState.makingInvisible ||
      state == LevelState.unloading;

  void _setState(LevelState newState) {
    levelInstance.state = newState;
    _stateController.add(newState);
  }

  /// Asynchronously loads the level, transitioning through `unloaded -> loading -> loaded` (and `visible` if [bShouldBeVisible] is true).
  Future<LuminaLevel> loadLevelAsync() {
    if (state == LevelState.loading && _inFlightLoad != null) {
      return _inFlightLoad!;
    }
    if (state != LevelState.unloaded) {
      if (bShouldBeVisible && state == LevelState.loaded) {
        return setVisibleAsync(true).then((_) => levelInstance);
      }
      return Future.value(levelInstance);
    }

    _inFlightLoad = _doLoad();
    return _inFlightLoad!;
  }

  Future<LuminaLevel> _doLoad() async {
    try {
      _setState(LevelState.loading);
      await Future.microtask(() {});
      _setState(LevelState.loaded);
      onLevelLoaded?.call(this);

      if (bShouldBeVisible) {
        await setVisibleAsync(true);
      }
      return levelInstance;
    } finally {
      _inFlightLoad = null;
    }
  }

  /// Asynchronously transitions visibility between `loaded <-> makingVisible <-> visible` and `visible <-> makingInvisible <-> loaded`.
  Future<void> setVisibleAsync(bool visible) async {
    bShouldBeVisible = visible;
    if (state == LevelState.unloaded || state == LevelState.unloading) {
      throw StateError('Cannot transition from $state to ${visible ? 'visible' : 'loaded'}');
    }

    _desiredVisible = visible;

    if (_inFlightVisibility != null) {
      await _inFlightVisibility;
      if (_desiredVisible != null && _isDesiredVisibleDifferentFromCurrent(_desiredVisible!)) {
        return setVisibleAsync(_desiredVisible!);
      }
      return;
    }

    if (!_isDesiredVisibleDifferentFromCurrent(visible)) {
      return;
    }

    _inFlightVisibility = _doSetVisible(visible);
    try {
      await _inFlightVisibility;
    } finally {
      _inFlightVisibility = null;
    }

    if (_desiredVisible != null && _isDesiredVisibleDifferentFromCurrent(_desiredVisible!)) {
      await setVisibleAsync(_desiredVisible!);
    }
  }

  bool _isDesiredVisibleDifferentFromCurrent(bool desired) {
    if (desired) {
      return state != LevelState.visible;
    } else {
      return state != LevelState.loaded;
    }
  }

  Future<void> _doSetVisible(bool visible) async {
    if (visible) {
      if (state == LevelState.loaded) {
        _setState(LevelState.makingVisible);
        await Future.microtask(() {});
        _setState(LevelState.visible);
        onLevelShown?.call(this);
      }
    } else {
      if (state == LevelState.visible) {
        _setState(LevelState.makingInvisible);
        await Future.microtask(() {});
        _setState(LevelState.loaded);
        onLevelHidden?.call(this);
      }
    }
  }

  /// Asynchronously unloads the level, hiding it first if visible, unregistering all actors, and transitioning to `unloaded`.
  Future<void> unloadLevelAsync() async {
    if (state == LevelState.unloaded) return;
    if (state == LevelState.unloading && _inFlightUnload != null) {
      return _inFlightUnload!;
    }

    _inFlightUnload = _doUnload();
    try {
      await _inFlightUnload;
    } finally {
      _inFlightUnload = null;
    }
  }

  Future<void> _doUnload() async {
    if (_inFlightVisibility != null) {
      await _inFlightVisibility;
    }

    if (state == LevelState.visible || state == LevelState.makingVisible) {
      await setVisibleAsync(false);
    }

    if (state == LevelState.loaded) {
      _setState(LevelState.unloading);
      await Future.microtask(() {});
      levelInstance.unloadActors();
      _setState(LevelState.unloaded);
      onLevelUnloaded?.call(this);
    }
  }

  /// Closes the state broadcast stream controller and releases resources.
  void dispose() {
    _stateController.close();
  }
}
