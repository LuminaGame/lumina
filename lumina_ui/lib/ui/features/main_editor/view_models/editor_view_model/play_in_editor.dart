part of '../editor_view_model.dart';

/// Play In Editor / Simulate and Play Standalone.
mixin _EditorPlayInEditor on _EditorViewModelState {
  void startSimulation() {
    _isPlaying = true;
    _isPaused = false;
    _logger.log(
      'Started PIE Simulation session',
      level: 'info',
      source: 'Viewport',
    );
    notifyListeners();
  }

  @override
  void togglePauseSimulation() {
    if (!_isPlaying) return;
    // Drive the real runtime through the PIE controller when a session is
    // mounted; it calls back into setSimulationPaused.
    if (pieController.isPlaying) {
      if (pieController.isPaused) {
        pieController.resume();
      } else {
        pieController.pause();
      }
      return;
    }
    setSimulationPaused(!_isPaused);
  }

  /// Mirrors the runtime pause state into the editor flags (toolbar, menu).
  void setSimulationPaused(bool paused) {
    if (_isPaused == paused) return;
    _isPaused = paused;
    _logger.log(
      _isPaused ? 'Paused PIE Simulation' : 'Resumed PIE Simulation',
      level: 'info',
      source: 'Viewport',
    );
    notifyListeners();
  }

  /// Frame-steps the paused runtime world by one tick.
  @override
  void stepSimulation() {
    if (!_isPlaying || !_isPaused) return;
    pieController.step();
  }

  @override
  void stopSimulation() {
    _isPlaying = false;
    _isPaused = false;
    _logger.log('Stopped PIE Simulation', level: 'info', source: 'Viewport');
    notifyListeners();
  }

  @override
  void togglePlaySimulation() {
    if (_isPlaying) {
      stopSimulation();
    } else {
      unawaited(requestPlay());
    }
  }

  /// Play Standalone: open Blueprints compile first
  /// (errors stop it, as for Play), open assets are saved, the exposed
  /// functions' registration and the game code are regenerated, then the
  /// project is built and run as its own process. Returns whether it started.
  @override
  Future<bool> playStandalone() async {
    if (standalone.isActive) return false;
    final pending = openBlueprintEditors.where(BlueprintPlayPreflight.needsCompile).toList();
    final blockers = pending.isEmpty ? const <PlayBlocker>[] : await BlueprintPlayPreflight.compileEditors(projectDirPath, pending);
    if (blockers.isNotEmpty) {
      playBlockers = List.unmodifiable(blockers);
      for (final b in blockers) {
        _logger.log('Play Standalone stopped: $b', level: 'error', source: 'Blueprint');
      }
      onPlayBlocked?.call(playBlockers);
      notifyListeners();
      return false;
    }
    for (final session in _tabSessions.values.toList()) {
      if (session.isDirty()) await session.save();
    }
    await blueprintFunctions.scan();
    await saveLevelAndGenerateCode();
    return standalone.start();
  }

  /// Stops Play Standalone's game (or build).
  @override
  Future<void> stopStandalone() => standalone.stop();

  /// Play: open Blueprints whose badge is Dirty or Unknown compile
  /// first, then every class Play uses must load and validate. Errors keep
  /// Play from starting and are listed by Blueprint and node; warnings do
  /// not block. Returns whether Play started.
  Future<bool> requestPlay() async {
    final pending = openBlueprintEditors.where(BlueprintPlayPreflight.needsCompile).toList();
    final warnings = <PlayBlocker>[];
    final blockers = <PlayBlocker>[
      if (pending.isNotEmpty) ...await BlueprintPlayPreflight.compileEditors(projectDirPath, pending, warnings: warnings),
    ];
    if (blockers.isEmpty) blockers.addAll(pieController.preflight(warnings: warnings));
    playBlockers = List.unmodifiable(blockers);
    // Warnings never block; a node calling project code
    // says it needs Play Standalone, and PIE plays the rest of the graph.
    final seen = <String>{};
    playWarnings = List.unmodifiable(warnings.where((w) => seen.add('${w.blueprintPath}|${w.nodeId}|${w.message}')));
    if (blockers.isEmpty) {
      for (final w in playWarnings) {
        _logger.log('Play: $w', level: 'warning', source: 'Blueprint');
      }
      if (playWarnings.isNotEmpty) onPlayWarnings?.call(playWarnings);
    }
    if (blockers.isNotEmpty) {
      for (final b in blockers) {
        _logger.log('Play stopped: $b', level: 'error', source: 'Blueprint');
      }
      onPlayBlocked?.call(playBlockers);
      notifyListeners();
      return false;
    }
    startSimulation();
    return true;
  }
}
