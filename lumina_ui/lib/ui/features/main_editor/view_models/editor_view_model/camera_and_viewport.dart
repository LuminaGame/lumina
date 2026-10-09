part of '../editor_view_model.dart';

/// Viewport settings (camera/view mode, show flags, snapping, grid), frame
/// stats, the level camera, and the render quality settings.
mixin _EditorCameraAndViewport on _EditorViewModelState {
  // Viewport Settings
  String get cameraMode => project.editorViewport.cameraMode;
  String get viewMode => project.editorViewport.viewMode;
  String get bufferVisualization => project.editorViewport.bufferVisualization;
  Map<String, bool> get showFlags => project.editorViewport.showFlags;

  @override
  void setCameraMode(String mode) {
    if (mode == cameraMode) return;

    // Save perspective pose if we are leaving Perspective
    final previousMode = cameraMode;
    if (previousMode == 'Perspective') {
      _perspYaw = _cameraYaw;
      _perspPitch = _cameraPitch;
      _perspPanX = _cameraPanX;
      _perspPanY = _cameraPanY;
      _perspPanZ = _cameraPanZ;
      _perspDistance = _cameraDistance;
    } else {
      // Leaving an ortho view: remember its zoom (extent) separately.
      _orthoDistance = _cameraDistance;
    }

    _project = project.copyWith(
      editorViewport: project.editorViewport.copyWith(cameraMode: mode),
    );

    // Apply ortho pose or restore perspective pose
    if (mode == 'Perspective') {
      _cameraYaw = _perspYaw;
      _cameraPitch = _perspPitch;
      _cameraPanX = _perspPanX;
      _cameraPanY = _perspPanY;
      _cameraPanZ = _perspPanZ;
      _cameraDistance = _perspDistance;
    } else if (previousMode == 'Perspective') {
      // Entering an ortho view from perspective uses the ortho extent.
      _cameraDistance = _orthoDistance;
    }
    if (mode == 'Top') {
      _cameraYaw = 0.0;
      _cameraPitch =
          -90.0; // look straight down (viewport picks a safe up vector)
    } else if (mode == 'Bottom') {
      _cameraYaw = 0.0;
      _cameraPitch = 90.0; // look straight up
    } else if (mode == 'Front') {
      _cameraYaw = 0.0;
      _cameraPitch = 0.0;
    } else if (mode == 'Back') {
      _cameraYaw = 180.0;
      _cameraPitch = 0.0;
    } else if (mode == 'Right') {
      _cameraYaw = -90.0;
      _cameraPitch = 0.0;
    } else if (mode == 'Left') {
      _cameraYaw = 90.0;
      _cameraPitch = 0.0;
    }

    _markDirty();
    _scheduleCameraSave();
    notifyListeners();
  }

  @override
  void setViewMode(String mode) {
    if (mode == viewMode) return;
    _project = project.copyWith(
      editorViewport: project.editorViewport.copyWith(viewMode: mode),
    );
    _markDirty();
    notifyListeners();
  }

  void setBufferVisualization(String mode) {
    if (mode == bufferVisualization) return;
    _project = project.copyWith(
      editorViewport: project.editorViewport.copyWith(
        bufferVisualization: mode,
      ),
    );
    _markDirty();
    notifyListeners();
  }

  void toggleShowFlag(String flag) {
    final current = Map<String, bool>.from(showFlags);
    current[flag] = !(current[flag] ?? true);
    _project = project.copyWith(
      editorViewport: project.editorViewport.copyWith(showFlags: current),
    );
    _markDirty();
    notifyListeners();
  }

  void reportFrameTime(Duration cpu, Duration frame) {
    final currentFps = frame.inMicroseconds > 0
        ? 1000000.0 / frame.inMicroseconds
        : 60.0;
    final currentCpu = cpu.inMicroseconds / 1000.0;

    _fpsHistory.add(currentFps);
    _cpuHistory.add(currentCpu);

    if (_fpsHistory.length > 30) _fpsHistory.removeAt(0);
    if (_cpuHistory.length > 30) _cpuHistory.removeAt(0);

    _fps = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
    _cpuMs = _cpuHistory.reduce((a, b) => a + b) / _cpuHistory.length;
    _gpuMs = -1.0; // "--" until flutter_filament exposes GPU frame timing

    // Only the telemetry readouts listen to this. Notifying the editor itself
    // rebuilt the whole shell and re-synced every actor on every rendered
    // frame, which is what held the viewport near 15 FPS.
    _frameStatsRevision.value++;
  }

  /// Fires once per reported frame, after [fps], [cpuMs], [gpuMs] and
  /// [viewportStatsLabel] have been updated. Listen to this — not to the
  /// editor — to show frame statistics.
  Listenable get frameStats => _frameStatsRevision;

  int get totalTriangles {
    int total = 0;
    for (final actor in actors) {
      if (actor.meshData != null) {
        total += actor.meshData!.triangleCount;
      }
    }
    return total;
  }

  bool get translateSnapEnabled => project.editorSnap.translateSnapEnabled;
  bool get rotateSnapEnabled => project.editorSnap.rotateSnapEnabled;
  bool get scaleSnapEnabled => project.editorSnap.scaleSnapEnabled;
  bool get surfaceSnapEnabled => project.editorSnap.surfaceSnapEnabled;
  bool get gridVisible => project.editorSnap.gridVisible;
  double get translateSnapStep => project.editorSnap.translateSnapStep;
  double get rotateSnapStep => project.editorSnap.rotateSnapStep;
  double get scaleSnapStep => project.editorSnap.scaleSnapStep;

  /// The editor snap grid step as stored in the project. This is what the
  /// toolbar's grid-step menu picks; it is unrelated to the world partition.
  double get editorGridStep => project.editorSnap.gridStep;

  /// Spacing the viewport draws its editor grid at. When the level authors an
  /// enabled World Partition the viewport draws the partition's `cellSize` so
  /// the authored cell boundaries — not an unrelated snap grid — are what you
  /// see; otherwise it is the project's own grid step. Both are centimetres,
  /// the world unit (`cellSize` 12 800 = 128 m), so no conversion is needed.
  double get gridStep =>
      worldPartitionEnabled ? worldPartitionCellSize : editorGridStep;

  /// Extent the viewport draws its grid over. An enabled partition widens it
  /// to at least 8 cells across so more than one cell boundary is visible.
  double get gridExtent {
    final stored = project.editorSnap.gridExtent;
    if (!worldPartitionEnabled) return stored;
    final eightCells = worldPartitionCellSize * 8;
    return stored > eightCells ? stored : eightCells;
  }

  void updateTranslateSnapEnabled(bool v) {
    if (v == translateSnapEnabled) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(translateSnapEnabled: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateRotateSnapEnabled(bool v) {
    if (v == rotateSnapEnabled) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(rotateSnapEnabled: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateScaleSnapEnabled(bool v) {
    if (v == scaleSnapEnabled) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(scaleSnapEnabled: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateSurfaceSnapEnabled(bool v) {
    if (v == surfaceSnapEnabled) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(surfaceSnapEnabled: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateGridVisible(bool v) {
    if (v == gridVisible) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(gridVisible: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateTranslateSnapStep(double v) {
    if (v == translateSnapStep) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(translateSnapStep: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateRotateSnapStep(double v) {
    if (v == rotateSnapStep) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(rotateSnapStep: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateScaleSnapStep(double v) {
    if (v == scaleSnapStep) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(scaleSnapStep: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateGridStep(double v) {
    if (v == editorGridStep) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(gridStep: v),
    );
    _markDirty();
    notifyListeners();
  }

  void updateGridExtent(double v) {
    if (v == project.editorSnap.gridExtent) return;
    _project = project.copyWith(
      editorSnap: project.editorSnap.copyWith(gridExtent: v),
    );
    _markDirty();
    notifyListeners();
  }

  static const List<double> _cameraSpeedMultipliers = [
    0.1,
    0.25,
    0.5,
    1.0,
    2.0,
    4.0,
    8.0,
    16.0,
  ];

  double get cameraSpeedMultiplier =>
      _cameraSpeedMultipliers[(_cameraSpeedScalar - 1).clamp(0, 7)];
  int get cameraSpeedScalar => _cameraSpeedScalar;
  double get cameraPanZ => _cameraPanZ;

  void setCameraSpeed(int level) {
    _cameraSpeedScalar = level.clamp(1, 8);
    _logger.log(
      'Camera Speed set to Level $_cameraSpeedScalar (${cameraSpeedMultiplier}x)',
      level: 'info',
      source: 'Viewport',
    );
    notifyListeners();
  }

  void adjustCameraSpeed(int delta) {
    setCameraSpeed(_cameraSpeedScalar + delta);
  }

  // 1. Right Mouse Button (RMB) Free-Look / Flycam Look
  void rotateCamera(double dx, double dy) {
    if (cameraMode != "Perspective") return;
    if (cameraMode != "Perspective") return;
    _cameraYaw += dx * 0.25;
    _cameraPitch = (_cameraPitch - dy * 0.25).clamp(-89.0, 89.0);
    _scheduleCameraSave();
    notifyListeners();
  }

  // 2. Left Mouse Button (LMB) Walk & Turn Navigation
  void walkMove(double dx, double dy) {
    if (cameraMode != "Perspective") return;
    if (cameraMode != "Perspective") return;
    _cameraYaw += dx * 0.25;
    final yawRad = _cameraYaw * math.pi / 180.0;
    // Ground forward direction vector
    final fwdX = -math.sin(yawRad);
    final fwdY = math.cos(yawRad);
    final moveStep = -dy * 1.2 * cameraSpeedMultiplier;

    _cameraPanX += fwdX * moveStep;
    _cameraPanY += fwdY * moveStep;
    _scheduleCameraSave();
    notifyListeners();
  }

  // 3. Middle Mouse Button (MMB) / Alt+MMB Screen-Space Pan / Track
  void panCamera(double dx, double dy) {
    if (cameraMode != "Perspective") return;
    if (cameraMode != "Perspective") return;
    final yawRad = _cameraYaw * math.pi / 180.0;
    final pitchRad = _cameraPitch * math.pi / 180.0;

    final rightX = math.cos(yawRad);
    final rightY = math.sin(yawRad);

    final upX = -math.sin(yawRad) * math.sin(pitchRad);
    final upY = math.cos(yawRad) * math.sin(pitchRad);
    final upZ = math.cos(pitchRad);

    final speedFactor =
        (_cameraDistance / 300.0).clamp(0.2, 5.0) * cameraSpeedMultiplier * 0.7;

    _cameraPanX -= (rightX * dx - upX * dy) * speedFactor;
    _cameraPanY -= (rightY * dx - upY * dy) * speedFactor;
    _cameraPanZ += upZ * dy * speedFactor;
    _scheduleCameraSave();
    notifyListeners();
  }

  // 4. LMB + RMB Pan & Pedestal
  void panPedestal(double dx, double dy) {
    final yawRad = _cameraYaw * math.pi / 180.0;
    final rightX = math.cos(yawRad);
    final rightY = math.sin(yawRad);
    final speedFactor = cameraSpeedMultiplier * 0.8;

    _cameraPanX -= rightX * dx * speedFactor;
    _cameraPanY -= rightY * dx * speedFactor;
    _cameraPanZ -= dy * speedFactor;
    _scheduleCameraSave();
    notifyListeners();
  }

  // 5. Alt + LMB Orbit / Tumble Navigation around Pivot
  void orbitCamera(double dx, double dy) {
    if (cameraMode != "Perspective") return;
    if (cameraMode != "Perspective") return;
    _cameraYaw += dx * 0.3;
    _cameraPitch = (_cameraPitch + dy * 0.3).clamp(-89.0, 89.0);
    _scheduleCameraSave();
    notifyListeners();
  }

  // 6. Alt + RMB / Scroll Wheel Dolly / Smooth Zoom
  void dollyCamera(double delta) {
    final step = delta * 0.8 * cameraSpeedMultiplier;
    // The range scales with the level: a fixed 50 m cap made the
    // first scroll in a level framed from further out jump in to 50 m.
    _cameraDistance = (_cameraDistance + step).clamp(5.0, math.max(maxCameraDistance, _cameraDistance));
    _scheduleCameraSave();
    notifyListeners();
  }

  /// The farthest the orbit camera dollies out: 50 m, or twice the distance
  /// that frames the level's bounds ([frameLevelBounds]), whichever is more —
  /// the orbit range follows the world, not a constant.
  double get maxCameraDistance {
    final bounds = _levelBounds();
    if (bounds == null) return 5000.0;
    return math.max(5000.0, _framingDistance(bounds) * 2.0);
  }

  /// The editor-space box around every actor (selection and drop use the
  /// same one); null for an empty level.
  ({List<double> min, List<double> max})? _levelBounds({bool visualOnly = false}) {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;

    for (final actor in _actors) {
      if (actor.type == 'Folder') continue;
      // The same editor-space box selection and drop use (asset axes and
      // unit scale converted).
      final box = ViewportPicker.editorSpaceBounds(actor);
      if (visualOnly && box == null) continue;
      final lo = box == null ? [actor.location[0], actor.location[1], actor.location[2]] : [box.min.x, box.min.y, box.min.z];
      final hi = box == null ? [actor.location[0], actor.location[1], actor.location[2]] : [box.max.x, box.max.y, box.max.z];
      if (lo[0] < minX) minX = lo[0];
      if (lo[1] < minY) minY = lo[1];
      if (lo[2] < minZ) minZ = lo[2];
      if (hi[0] > maxX) maxX = hi[0];
      if (hi[1] > maxY) maxY = hi[1];
      if (hi[2] > maxZ) maxZ = hi[2];
    }
    if (minX == double.infinity) return null;
    return (min: [minX, minY, minZ], max: [maxX, maxY, maxZ]);
  }

  /// 1.4x the diagonal keeps the whole extent inside a 45 degree field of
  /// view with a margin; a degenerate (single point) level gets a sane float.
  static double _framingDistance(({List<double> min, List<double> max}) b) {
    final dx = b.max[0] - b.min[0], dy = b.max[1] - b.min[1], dz = b.max[2] - b.min[2];
    final diagonal = math.sqrt(dx * dx + dy * dy + dz * dz);
    return (diagonal < 1e-6 ? 250.0 : diagonal * 1.4).clamp(1.0, 100000.0);
  }

  void zoomCamera(double delta) {
    dollyCamera(delta * 0.5);
  }

  // 7. Continuous 60 FPS 3D WASD + QE Flycam Flight
  void flyWASD({
    required bool forward,
    required bool backward,
    required bool left,
    required bool right,
    required bool up,
    required bool down,
    required double dt,
    bool boost = false,
    bool slow = false,
  }) {
    if (cameraMode != "Perspective") return;
    if (cameraMode != "Perspective") return;
    final yawRad = _cameraYaw * math.pi / 180.0;
    final pitchRad = _cameraPitch * math.pi / 180.0;

    // True 3D Look Forward vector (into the gaze)
    final fwdX = -math.cos(pitchRad) * math.sin(yawRad);
    final fwdY = math.cos(pitchRad) * math.cos(yawRad);
    final fwdZ = -math.sin(pitchRad);

    // Right vector (horizontal strafe)
    final rightX = math.cos(yawRad);
    final rightY = math.sin(yawRad);
    final rightZ = 0.0;

    // Up vector (World Up for E/Q vertical elevation)
    const upX = 0.0;
    const upY = 0.0;
    const upZ = 1.0;

    final double speedMod = boost ? 2.5 : (slow ? 0.3 : 1.0);
    final double moveDist = 400.0 * cameraSpeedMultiplier * speedMod * dt;

    double moveX = 0.0;
    double moveY = 0.0;
    double moveZ = 0.0;

    if (forward) {
      moveX += fwdX;
      moveY += fwdY;
      moveZ += fwdZ;
    }
    if (backward) {
      moveX -= fwdX;
      moveY -= fwdY;
      moveZ -= fwdZ;
    }
    if (right) {
      moveX += rightX;
      moveY += rightY;
      moveZ += rightZ;
    }
    if (left) {
      moveX -= rightX;
      moveY -= rightY;
      moveZ -= rightZ;
    }
    if (up) {
      moveX += upX;
      moveY += upY;
      moveZ += upZ;
    }
    if (down) {
      moveX -= upX;
      moveY -= upY;
      moveZ -= upZ;
    }

    final len = math.sqrt(moveX * moveX + moveY * moveY + moveZ * moveZ);
    if (len > 0.0001) {
      _cameraPanX += (moveX / len) * moveDist;
      _cameraPanY += (moveY / len) * moveDist;
      _cameraPanZ += (moveZ / len) * moveDist;
      _scheduleCameraSave();
    notifyListeners();
    }
  }

  // Discrete single-step WASD helper
  void moveCameraWASD(String direction, {double step = 25.0}) {
    final dir = direction.toLowerCase();
    final isW = dir == 'w' || dir == 'arrow up' || dir == 'up';
    final isS = dir == 's' || dir == 'arrow down' || dir == 'down';
    final isA = dir == 'a' || dir == 'arrow left' || dir == 'left';
    final isD = dir == 'd' || dir == 'arrow right' || dir == 'right';
    final isE = dir == 'e';
    final isQ = dir == 'q';

    flyWASD(
      forward: isW,
      backward: isS,
      left: isA,
      right: isD,
      up: isE,
      down: isQ,
      dt: step / 400.0,
    );
  }

  @override
  void resetCamera() {
    _cameraYaw = -35.0;
    _cameraPitch = 25.0;
    _cameraPanX = 0.0;
    _cameraPanY = 0.0;
    _cameraPanZ = 0.0;
    _cameraDistance = 250.0;
    _cameraSpeedScalar = 4;
    _logger.log(
      'Reset 3D Viewport Camera to the default view',
      level: 'info',
      source: 'Viewport',
    );
    _scheduleCameraSave();
    notifyListeners();
  }

  /// The View menu's, the MCP tool's and the viewport header's name for
  /// [viewMode]: one persisted field, so the toolbar select, the View menu and
  /// the header never disagree.
  String get viewportMode => viewMode;

  double get cameraYaw => _cameraYaw;
  double get cameraPitch => _cameraPitch;
  double get cameraDistance => _cameraDistance;
  double get cameraPanX => _cameraPanX;
  double get cameraPanY => _cameraPanY;

  double get fps => _fps;
  double get cpuMs => _cpuMs;

  /// Real stats for the viewport HUD: triangles summed from loaded mesh data,
  /// FPS and CPU time measured via [reportFrameTime] (`--` until a frame
  /// has been reported).
  String get viewportStatsLabel {
    final tris = EditorViewModel.formatTriangleCount(totalTriangles);
    final fpsText = _fpsHistory.isEmpty ? '--' : _fps.toStringAsFixed(0);
    final cpuText = _cpuHistory.isEmpty
        ? '--'
        : '${_cpuMs.toStringAsFixed(1)}ms';
    return 'Tris: $tris  FPS: $fpsText  CPU: $cpuText';
  }

  double get gpuMs => _gpuMs;

  /// How the editor viewport renders. Per-user, not part of the project —
  /// the project's shipped quality lives in the manifest and Project Settings.
  EditorQualitySettings get quality => _quality;

  /// Bumped whenever [quality] changes, so the viewport knows to re-apply it
  /// to its live Filament view.
  int get qualityRevision => _qualityRevision;

  String get qualityPreset => _quality.preset;
  double get resolutionScale => _quality.resolutionScale;
  bool get ssaoEnabled => _quality.ssao;
  bool get bloomEnabled => _quality.bloom;
  bool get screenSpaceReflectionsEnabled => _quality.screenSpaceReflections;
  LuminaRayTracingSettings get rayTracingSettings => _quality.rayTracing;
  LuminaDlssSettings get dlssSettings => _quality.dlss;
  LuminaFsr3Settings get fsr3Settings => _quality.fsr3;
  LuminaDlssFrameGenerationSettings get dlssFrameGenerationSettings => _quality.dlssFrameGeneration;
  bool get vsyncEnabled => _project.settings.vsyncEnabled;

  /// Points the viewport camera at the whole level and pulls back far enough
  /// to hold it.
  ///
  /// Levels do not all share a scale: imported props are authored in
  /// centimetres, while the game templates lay out rooms in metres. Framing
  /// what is actually in the level means either opens visible, instead of a
  /// distant speck or a wall of geometry.
  @override
  void frameLevelBounds() {
    if (_actors.isEmpty) return;
    // Only actors with mesh bounds: a light, sky or player start far from the
    // geometry would otherwise push the camera out until the level is a dot.
    final bounds = _levelBounds(visualOnly: true) ?? _levelBounds();
    if (bounds == null) return;

    _cameraPanX = (bounds.min[0] + bounds.max[0]) / 2;
    _cameraPanY = (bounds.min[1] + bounds.max[1]) / 2;
    _cameraPanZ = (bounds.min[2] + bounds.max[2]) / 2;

    _cameraDistance = _framingDistance(bounds);
    _perspDistance = _cameraDistance;
    _scheduleCameraSave();
    notifyListeners();
  }

  @override
  void focusCameraOnActor(EditorActorNode actor) {
    selectActor(actor);

    // Frame and center the actor at target pivot
    _cameraPanX = actor.location[0];
    _cameraPanY = actor.location[1];
    _cameraPanZ = actor.location[2];

    // Compute comfortable framing distance based on actor bounds
    final scale = (actor.scale[0] + actor.scale[1] + actor.scale[2]) / 3.0;
    _cameraDistance = (150.0 * scale).clamp(80.0, 1000.0);

    _logger.log(
      'Focused 3D Viewport camera onto actor "${actor.name}" at [${actor.location[0].toStringAsFixed(1)}, ${actor.location[1].toStringAsFixed(1)}, ${actor.location[2].toStringAsFixed(1)}]',
      level: 'info',
      source: 'Viewport',
    );
    _scheduleCameraSave();
    notifyListeners();
  }

  void updateQualityPreset(String preset) {
    final updatedSettings = EngineScalabilitySettings(
      targetFps: _project.settings.targetFps,
      vsyncEnabled: _project.settings.vsyncEnabled,
      qualityPreset: preset,
      scalability: _project.settings.scalability,
      autoOrganizeFiles: _project.settings.autoOrganizeFiles,
      autoSaveIntervalSeconds: _project.settings.autoSaveIntervalSeconds,
    );
    _project = _project.copyWith(
      settings: updatedSettings,
      isDirty: true,
      lastModifiedTimestamp: DateTime.now().toIso8601String(),
    );
    // The preset is both a project property (what the game ships with, edited
    // in Project Settings) and the editor viewport's own quality — keep them
    // in step rather than letting the toolbar and the settings editor drift.
    _setQuality(_quality.copyWith(preset: preset), 'Quality preset "$preset"');
    notifyListeners();
  }

  void toggleVSync() {
    final updatedSettings = EngineScalabilitySettings(
      targetFps: _project.settings.targetFps,
      vsyncEnabled: !_project.settings.vsyncEnabled,
      qualityPreset: _project.settings.qualityPreset,
      scalability: _project.settings.scalability,
      autoOrganizeFiles: _project.settings.autoOrganizeFiles,
      autoSaveIntervalSeconds: _project.settings.autoSaveIntervalSeconds,
    );
    _project = _project.copyWith(
      settings: updatedSettings,
      isDirty: true,
      lastModifiedTimestamp: DateTime.now().toIso8601String(),
    );
    _logger.log(
      'VSync set to ${updatedSettings.vsyncEnabled}',
      level: 'info',
      source: 'QualityManager',
    );
    notifyListeners();
  }

  /// Applies [next] to the viewport, tells listeners, and persists it for this
  /// project. Persistence is fire-and-forget; [flushQualitySettings] awaits it.
  @override
  void _setQuality(EditorQualitySettings next, String what) {
    if (next == _quality) return;
    _quality = next;
    _qualityRevision++;
    _logger.log(
      '$what — editor viewport now $_quality',
      level: 'info',
      source: 'QualityManager',
    );
    notifyListeners();
    // Chain rather than replace: two quick edits both read-modify-write the
    // same file, and a replaced future would lose the first one.
    final path = projectDirPath;
    final settings = _quality;
    _pendingQualitySave = (_pendingQualitySave ?? Future<void>.value()).then(
      (_) => _qualityStore.save(path, settings),
    );
  }

  /// Awaits the in-flight settings write. Tests and shutdown use this; normal
  /// UI interaction does not have to.
  Future<void> flushQualitySettings() async {
    await _pendingQualitySave;
  }

  /// Restores this project's saved editor quality, if any.
  @override
  Future<void> loadQualitySettings() async {
    final loaded = await _qualityStore.load(projectDirPath);
    if (loaded == _quality) return;
    _quality = loaded;
    _qualityRevision++;
    notifyListeners();
  }

  void toggleSsao() => _setQuality(
    _quality.copyWith(ssao: !_quality.ssao),
    'SSAO ${!_quality.ssao ? 'on' : 'off'}',
  );

  void toggleBloom() => _setQuality(
    _quality.copyWith(bloom: !_quality.bloom),
    'Bloom ${!_quality.bloom ? 'on' : 'off'}',
  );

  void toggleScreenSpaceReflections() => _setQuality(
    _quality.copyWith(screenSpaceReflections: !_quality.screenSpaceReflections),
    'Screen-space reflections ${!_quality.screenSpaceReflections ? 'on' : 'off'}',
  );

  /// The RTX HUD button: ray tracing on or off, keeping the sub-choices.
  void toggleRayTracing() => _setQuality(
    _quality.copyWith(rayTracing: _quality.rayTracing.copyWith(enabled: !_quality.rayTracing.enabled)),
    'Ray tracing ${!_quality.rayTracing.enabled ? 'on' : 'off'}',
  );

  void setRayTracingSettings(LuminaRayTracingSettings settings) =>
      _setQuality(_quality.copyWith(rayTracing: settings), 'Ray tracing $settings');

  /// The DLSS HUD button: DLSS on or off, keeping the quality mode.
  void toggleDlss() => _setQuality(
    _quality.copyWith(dlss: _quality.dlss.copyWith(enabled: !_quality.dlss.enabled)),
    'DLSS ${!_quality.dlss.enabled ? 'on' : 'off'}',
  );

  void setDlssSettings(LuminaDlssSettings settings) => _setQuality(_quality.copyWith(dlss: settings), 'DLSS $settings');

  /// DLSS Frame Generation: 0 (off) to 5 generated frames per rendered frame.
  void setDlssFrameGeneration(int generatedFrames) => _setQuality(
    _quality.copyWith(dlssFrameGeneration: LuminaDlssFrameGenerationSettings(generatedFrames: generatedFrames.clamp(0, 5))),
    'DLSS frame generation ${generatedFrames <= 0 ? 'off' : '${generatedFrames + 1}x'}',
  );

  /// The FSR3 HUD button: FSR3 on or off, keeping the preset and sharpness.
  void toggleFsr3() => _setQuality(
    _quality.copyWith(fsr3: _quality.fsr3.copyWith(enabled: !_quality.fsr3.enabled)),
    'FSR3 ${!_quality.fsr3.enabled ? 'on' : 'off'}',
  );

  void setFsr3Settings(LuminaFsr3Settings settings) => _setQuality(_quality.copyWith(fsr3: settings), 'FSR3 $settings');

  void updateResolutionScale(double scale) => _setQuality(
    _quality.copyWith(resolutionScale: scale),
    'Resolution scale ${scale.toInt()}%',
  );

  void restoreCameraSnapshot(List<double> cam) {
    _cameraYaw = cam[0];
    _cameraPitch = cam[1];
    _cameraDistance = cam[2];
    _cameraPanX = cam[3];
    _cameraPanY = cam[4];
    _cameraPanZ = cam[5];
    _scheduleCameraSave();
    notifyListeners();
  }

  // ---- the remembered camera -----------------------------------------------

  /// The viewport camera as the store keeps it.
  @override
  EditorCameraState get cameraState => EditorCameraState(
        yaw: _cameraYaw,
        pitch: _cameraPitch,
        distance: _cameraDistance,
        panX: _cameraPanX,
        panY: _cameraPanY,
        panZ: _cameraPanZ,
        mode: cameraMode,
      );

  /// Puts the camera where this project was last edited; false (and the
  /// camera untouched) when the project was never opened on this machine.
  /// The project open path calls this before it would frame the level.
  @override
  Future<bool> restoreSavedCamera() async {
    final saved = await _cameraStore.load(projectDirPath);
    if (saved == null) return false;
    _cameraYaw = saved.yaw;
    _cameraPitch = saved.pitch;
    _cameraDistance = saved.distance;
    _perspDistance = saved.distance;
    _cameraPanX = saved.panX;
    _cameraPanY = saved.panY;
    _cameraPanZ = saved.panZ;
    _savedCamera = saved;
    notifyListeners();
    return true;
  }

  /// Saves the camera a moment after it stopped moving (one write per pause,
  /// not one per mouse event). Fire-and-forget; [flushCameraState] awaits it.
  void _scheduleCameraSave() {
    _cameraSaveTimer?.cancel();
    _cameraSaveTimer = Timer(const Duration(milliseconds: 400), _saveCameraNow);
  }

  void _saveCameraNow() {
    _cameraSaveTimer = null;
    final state = cameraState;
    if (state == _savedCamera) return;
    _savedCamera = state;
    _pendingCameraSave = _cameraStore.save(projectDirPath, state);
  }

  /// Writes a camera change that is still pending (a test, a close).
  Future<void> flushCameraState() async {
    if (_cameraSaveTimer != null) {
      _cameraSaveTimer!.cancel();
      _saveCameraNow();
    }
    await _pendingCameraSave;
  }
}
