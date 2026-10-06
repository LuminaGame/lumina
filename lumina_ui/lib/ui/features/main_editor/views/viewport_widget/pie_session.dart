part of '../viewport_widget.dart';

/// Play-In-Editor: starting/stopping the session, its tick, the play
/// camera and the debug-draw projector.
mixin _ViewportPieSession on _ViewportWidgetStateBase {

  /// Play started with Blueprint warnings — a node calling project code that
  /// needs Play Standalone.
  void _showPlayWarnings(List<PlayBlocker> warnings) {
    if (!mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (toastCtx, overlay) => SurfaceCard(
        key: const ValueKey('play_warnings_toast'),
        child: Basic(
          title: Text('Play: ${warnings.length} Blueprint warning${warnings.length == 1 ? '' : 's'}'),
          content: Text(warnings.take(3).map((w) => w.toString()).join('\n'), style: const TextStyle(fontSize: 10)),
        ),
      ),
    );
  }

  /// Play did not start: the Blueprint compile errors.
  void _showPlayBlocked(List<PlayBlocker> blockers) {
    if (!mounted) return;
    showPlayBlockedDialog(context, widget.viewModel, blockers);
  }

  /// Makes the runtime session follow the editor's play state, whichever
  /// control changed it.
  ///
  /// The toolbar calls `onStartSimulationRequest` directly, but the Debug menu,
  /// the `debug.togglePie` command and `Alt+P` go through
  /// `EditorViewModel.togglePlaySimulation`, which only flips the booleans. That
  /// used to leave Play doing nothing at all from those three paths.
  @override
  void _syncPieSession() {
    if (_syncingPie) return;
    final vm = widget.viewModel;
    final pie = vm.pieController;

    // Only the *edges* of the editor's own flags drive this. The toolbar starts
    // a session through `onStartSimulationRequest` without touching them, and
    // reacting to the resulting divergence would stop the session it just
    // started.
    final playingChanged = vm.isPlaying != _lastVmPlaying;
    final pausedChanged = vm.isPaused != _lastVmPaused;
    _lastVmPlaying = vm.isPlaying;
    _lastVmPaused = vm.isPaused;
    if (!playingChanged && !pausedChanged) return;

    _syncingPie = true;
    try {
      if (playingChanged) {
        if (vm.isPlaying && !pie.isPlaying) {
          _startPie();
        } else if (!vm.isPlaying && pie.isPlaying) {
          _stopPie();
        }
      }
      if (pausedChanged && pie.isPlaying) {
        if (vm.isPaused && !pie.isPaused) {
          pie.pause();
        } else if (!vm.isPaused && pie.isPaused) {
          pie.resume();
        }
      }
    } finally {
      _syncingPie = false;
    }
  }

  void _startPie() {
    if (_nativeEngine != null && _nativeScene != null) {
      widget.viewModel.pieController.startPie(
        _nativeEngine!,
        _nativeScene!,
        postProcessView: _nativeView,
        postProcessBaseline: _levelPostProcess.baseline,
      );
      // The running world draws every level actor itself; the editor's copies
      // leave the scene for the session.
      _syncActorAssets();
    }
  }

  void _stopPie() {
    if (_nativeEngine != null && _nativeScene != null) {
      widget.viewModel.pieController.stopPie(_nativeEngine!, _nativeScene!);
      _syncActorAssets();
    }
  }

  /// Whether a Play session owns the scene. The runtime world mounts its own
  /// copy of every level actor, so while it runs the editor's copies stay
  /// loaded but out of the scene — Play shows exactly the game. (They would
  /// also be drawn where the editor puts them, which is not always where
  /// the runtime does.)
  @override
  bool get _pieOwnsTheScene => widget.viewModel.pieController.isPlaying;

  /// Whether the editor draws its own copy of [actorId] right now.
  @override
  bool _editorActorDrawn(String actorId) =>
      !_pieOwnsTheScene && widget.viewModel.isEffectivelyVisible(actorId);

  /// Test seam: how many editor actors the level view draws as solids (in
  /// Wireframe none: their solids stay in the scene on a layer the level
  /// view hides, see [editorActorSolidsInSceneForTest]).
  int get editorActorsInSceneForTest => _wireframeMode ? 0 : _visibleInScene.length;

  /// Test seam: how many editor actors have their solid mesh in the scene.
  int get editorActorSolidsInSceneForTest => _visibleInScene.length;

  /// Test seam: the visibility layers the level view shows.
  int? get viewLayersForTest => _nativeView?.visibleLayers;
  FilamentScene? get nativeSceneForTest => _nativeScene;
  bool get rayTracingSupportedForTest => _rtxController?.rayTracingSupported ?? false;
  bool get fsr3ActiveForTest => _rtxController?.fsr3Active ?? false;

  /// Test seam: whether the editor's preview sun is in the scene.
  bool get editorSunInSceneForTest => editorLightEntitiesForTest.isNotEmpty;

  void _onPieTick(Duration elapsed) {
    if (widget.viewModel.pieController.isPlaying &&
        !widget.viewModel.pieController.isPaused) {
      final now = DateTime.now().microsecondsSinceEpoch;
      if (_lastPieTick > 0) {
        // Clamped so a breakpoint stall does not teleport the pawn.
        final dt = ((now - _lastPieTick) / 1000000.0).clamp(0.0, 0.1);
        widget.viewModel.pieController.tick(dt);
      }
      _lastPieTick = now;
    } else {
      _lastPieTick = 0;
    }
    _applyPieCamera();
  }

  /// Test seam: whether the game's camera owns the Filament view.
  bool get pieCameraDrivesViewForTest => _pieCameraDrivesView;

  /// Whether the running game's camera, rather than the editor flycam, is
  /// driving the Filament view.
  @override
  bool get _pieCameraDrivesView =>
      widget.viewModel.pieController.isPlaying &&
      !widget.viewModel.pieController.isEjected &&
      widget.viewModel.pieController.playerCamera != null;

  /// The projector the debug-draw layer uses this frame: the game camera's
  /// while it drives the view, else the editor camera's overlay maths on
  /// authoring-space points (runtime points converted first).
  PieDebugProjector? _pieDebugProjector() {
    final size = Size(_viewportWidth, _viewportHeight);
    if (_pieCameraDrivesView) {
      final cam = widget.viewModel.pieController.playerCamera!;
      // The manager's view (a camera view target, a blend) when it has one.
      final pov = widget.viewModel.pieController.viewTargetPov;
      return PieCameraProjection(
        eye: pov?.location ?? cam.worldLocation,
        forward: pov?.rotation.rotateVector(Vector3(0, 0, -1)) ?? cam.forwardVector,
        up: pov?.rotation.rotateVector(Vector3(0, 1, 0)) ?? cam.upVector,
        fovDegrees: pov?.fovDegrees ?? cam.fieldOfViewInDegrees,
        size: size,
      );
    }
    final overlay = _overlayCamera(size);
    return PieFunctionProjector(
      (p) {
        final a = LuminaAxes.toAuthoringLocation(p);
        return overlay.project(a[0], a[1], a[2]);
      },
      (p) {
        final a = LuminaAxes.toAuthoringLocation(p);
        final o = overlay.project(a[0], a[1], a[2]);
        final o2 = overlay.project(a[0] + 1, a[1], a[2]);
        return o == null || o2 == null ? 0.0 : (o2 - o).distance;
      },
    );
  }

  /// Points the Filament camera through the player's view: the possessed
  /// pawn's camera component, or the player camera manager's point of view
  /// while it is something else — a placed camera as view target (Auto
  /// Activate for Player, Set View Target), a blend, an FOV override or a
  /// shake. A camera view target also brings its projection, clip planes and
  /// exposure.
  ///
  /// The runtime is Y-up and its transforms are already in Filament's space, so
  /// unlike the editor path this applies them with no axis conversion.
  void _applyPieCamera() {
    if (!_pieCameraDrivesView) return;
    final camera = _nativeCamera;
    final pie = widget.viewModel.pieController;
    // The template character's camera, or a Blueprint pawn's.
    final cameraComponent = pie.playerCamera;
    if (camera == null || cameraComponent == null) return;

    final pov = pie.viewTargetPov;
    final lens = pov?.camera;
    final eye = pov?.location ?? cameraComponent.worldLocation;
    final forward = pov?.rotation.rotateVector(Vector3(0, 0, -1)) ?? cameraComponent.forwardVector;
    final up = pov?.rotation.rotateVector(Vector3(0, 1, 0)) ?? cameraComponent.upVector;
    final fov = pov?.fovDegrees ?? cameraComponent.fieldOfViewInDegrees;

    final aspect = (_viewportWidth > 0 && _viewportHeight > 0)
        ? _viewportWidth / _viewportHeight
        : 16.0 / 9.0;
    if (lens != null && lens.projectionMode == CameraProjectionMode.orthographic) {
      final halfWidth = lens.orthographicWidth * 0.5;
      final halfHeight = halfWidth / aspect;
      camera.setProjectionOrtho(
        left: -halfWidth,
        right: halfWidth,
        bottom: -halfHeight,
        top: halfHeight,
        near: lens.nearClipPlane,
        far: lens.farClipPlane,
      );
    } else {
      camera.setProjection(
        fovDegrees: fov,
        aspect: aspect,
        near: lens?.nearClipPlane ?? 0.1,
        far: lens?.farClipPlane ?? 5000.0,
      );
    }
    camera.lookAt(
      eyeX: eye.x,
      eyeY: eye.y,
      eyeZ: eye.z,
      centerX: eye.x + forward.x,
      centerY: eye.y + forward.y,
      centerZ: eye.z + forward.z,
      upX: up.x,
      upY: up.y,
      upZ: up.z,
    );
    if (lens != null && !lens.autoExposure) {
      // The placed camera's own exposure, set by hand in its Details.
      camera.setExposure(aperture: lens.aperture, shutterSpeed: lens.shutterSpeed, sensitivity: lens.sensitivity);
      _appliedEv100 = null;
    } else {
      // The playing world's lights may change every frame.
      _syncAutoExposure();
    }
    // The editor pose has to be pushed again once the game lets go of the view.
    _pushedCameraPose = null;
  }

  /// Test seam: the eye position the PIE camera is pointing from, or null when
  /// the editor camera owns the view.
  List<double>? get pieCameraEyeForTest {
    if (!_pieCameraDrivesView) return null;
    final pov = widget.viewModel.pieController.viewTargetPov;
    final eye = pov?.location ?? widget.viewModel.pieController.playerCamera!.worldLocation;
    return [eye.x, eye.y, eye.z];
  }
}
