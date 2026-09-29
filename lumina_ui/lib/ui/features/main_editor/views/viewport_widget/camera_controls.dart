part of '../viewport_widget.dart';

/// Editor camera: WASD fly tick, speed feedback, cursor and flight hint,
/// pushing the pose to Filament, and the camera HUD buttons.
mixin _ViewportCameraControls on _ViewportWidgetStateBase {

  void _triggerSpeedFeedback() {
    _speedBadgeTimer?.cancel();
    setState(() => _showSpeedBadge = true);
    _speedBadgeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSpeedBadge = false);
    });
  }

  /// The camera exposure the level's lights call for: the lights
  /// the edit-mode scene realised — or, while Play owns the scene, the
  /// playing world's — metered by lumina's [LuminaAutoExposure], the rule
  /// the generated game's world applies to its camera. A sky light or a
  /// sun keeps sunny 16; a lamp-lit level is exposed for its lamps.
  double _meteredEv100() {
    final scene = _nativeScene;
    final skyLight = scene != null && scene.indirectLight != null;
    final pieWorld = _pieOwnsTheScene ? widget.viewModel.pieController.game?.gameInstance.world : null;
    final lights = pieWorld != null ? LuminaAutoExposure.lightsIn(pieWorld) : _levelLights.components;
    return LuminaAutoExposure.ev100For(lights, skyLight: skyLight);
  }

  /// Pushes [_meteredEv100] to the viewport's Filament camera when it moved.
  @override
  void _syncAutoExposure() {
    final camera = _nativeCamera;
    if (camera == null) return;
    final ev100 = _meteredEv100();
    if (_appliedEv100 != null && (_appliedEv100! - ev100).abs() < 1e-6) return;
    _appliedEv100 = ev100;
    camera.setExposure(
      aperture: LuminaAutoExposure.aperture,
      shutterSpeed: LuminaAutoExposure.shutterSpeedFor(ev100),
      sensitivity: LuminaAutoExposure.sensitivity,
    );
  }

  /// Test seam: the EV100 the viewport's Filament camera renders
  /// at, read back from the camera.
  double? get cameraEv100ForTest {
    final camera = _nativeCamera;
    if (camera == null) return null;
    return math.log(camera.aperture * camera.aperture / camera.shutterSpeed * 100 / camera.sensitivity) / math.ln2;
  }

  /// Test seam: the cursor the viewport shows right now.
  MouseCursor get viewportCursorForTest => _viewportCursor();

  /// Whether W/A/S/D/Q/E fly the camera right now: with the
  /// right button held, whenever the viewport has keyboard focus, or never,
  /// as Editor Preferences say.
  bool get _wasdFlies => switch (widget.viewModel.editorPreferences.flightCameraControl) {
        FlightCameraControlType.rmbHeld => _isRmbDown,
        FlightCameraControlType.always => _isRmbDown || _keyboardFocus.hasFocus,
        FlightCameraControlType.never => false,
      };

  /// The flight keys of the current mode, for the camera-speed tooltip.
  String get _flightHint => switch (widget.viewModel.editorPreferences.flightCameraControl) {
        FlightCameraControlType.rmbHeld => 'RMB + WASD/QE to fly · Arrow keys to move',
        FlightCameraControlType.always => 'WASD/QE to fly · Arrow keys to move',
        FlightCameraControlType.never => 'RMB to look · Arrow keys to move',
      };

  /// Test seam: the camera-speed tooltip's flight hint.
  String get flightHintForTest => _flightHint;

  /// Space: select/translate → rotate → scale → translate.
  void _cycleTransformTool() {
    const order = ['translate', 'rotate', 'scale'];
    final next = order[(order.indexOf(widget.viewModel.activeTool) + 1) % order.length];
    widget.viewModel.setActiveTool(next);
  }

  /// The cursor over the viewport: none while a Play session has the mouse,
  /// the arrow once F4 gave it back, else the editor's
  /// navigation / gizmo cursor.
  MouseCursor _viewportCursor() {
    if (widget.viewModel.pieController.mouseCapture.hidesCursor) return SystemMouseCursors.none;
    if (widget.viewModel.pieController.acceptsGameInput) return SystemMouseCursors.basic;
    if (_isRmbDown) return SystemMouseCursors.move;
    if (HardwareKeyboard.instance.isAltPressed) return SystemMouseCursors.grab;
    if (_isMmbDown) return SystemMouseCursors.allScroll;
    if (_isLmbDown && _draggingGizmoAxis != null) return SystemMouseCursors.resizeUpDown;
    if (_hoveredGizmoAxis != null) return SystemMouseCursors.click;
    return SystemMouseCursors.basic;
  }

  void _onFlyTick(Duration elapsed) {
    if (_skipReadPixelsFrames > 0) {
      setState(() {
        _skipReadPixelsFrames--;
      });
    }

    // The procedural sky's day cycle runs whether or not the camera is being
    // flown, so it is advanced before the fly-camera's early return.
    final skyDt = _lastSkyTickTime == Duration.zero
        ? 0.016
        : (elapsed - _lastSkyTickTime).inMicroseconds / 1000000.0;
    _lastSkyTickTime = elapsed;
    _proceduralSky.advance(skyDt.clamp(0.0, 0.1));

    if (!_wasdFlies || _pressedKeys.isEmpty) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = _lastTickTime == Duration.zero
        ? 0.016
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;
    final clampedDt = dt.clamp(0.001, 0.05);

    final moveForward =
        _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp);
    final moveBackward =
        _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown);
    final moveLeft =
        _pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft);
    final moveRight =
        _pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight);
    final moveUp = _pressedKeys.contains(LogicalKeyboardKey.keyE);
    final moveDown = _pressedKeys.contains(LogicalKeyboardKey.keyQ);

    if (moveForward ||
        moveBackward ||
        moveLeft ||
        moveRight ||
        moveUp ||
        moveDown) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;

      widget.viewModel.flyWASD(
        forward: moveForward,
        backward: moveBackward,
        left: moveLeft,
        right: moveRight,
        up: moveUp,
        down: moveDown,
        dt: clampedDt,
        boost: isShift,
        slow: isCtrl,
      );
      _updateNativeCamera();
    }
  }

  @override
  (double, double, double, double, double, double) get _editorCameraPose {
    final vm = widget.viewModel;
    return (vm.cameraYaw, vm.cameraPitch, vm.cameraDistance, vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ);
  }

  @override
  void _updateNativeCamera() {
    if (_nativeCamera == null) return;
    final yawRad = widget.viewModel.cameraYaw * math.pi / 180.0;
    final pitchDeg = widget.viewModel.cameraPitch.clamp(-90.0, 90.0);
    final pitchRad = pitchDeg * math.pi / 180.0;
    // Looking straight down/up makes the world up axis parallel to the view
    // direction; use the camera's forward (yaw) direction as "up" instead so
    // While a possessed PIE session owns the view, the editor flycam must not
    // write over the pawn's camera every frame.
    if (_pieCameraDrivesView) return;

    // Top/Bottom views stay well-defined and axis-aligned.
    final isPolar = pitchDeg.abs() > 89.5;

    final targetX = widget.viewModel.cameraPanX;
    final targetY = widget.viewModel.cameraPanY;
    final targetZ = widget.viewModel.cameraPanZ;

    // The overlay (labels, icons, picking, the gizmo) projects through this
    // same distance, so it is not clamped here: a 60 m level is framed from
    // ~120 m, and a 50 m cap put the render closer than its labels.
    final dist = widget.viewModel.cameraDistance;

    final eyeOffsetX = dist * math.cos(pitchRad) * math.sin(yawRad);
    final eyeOffsetY = -dist * math.cos(pitchRad) * math.cos(yawRad);
    final eyeOffsetZ = dist * math.sin(pitchRad);

    final eyeX = targetX + eyeOffsetX;
    final eyeY = targetY + eyeOffsetY;
    final eyeZ = targetZ + eyeOffsetZ;

    // Convert Lumina (Z-up) coordinates to Filament (Y-up) native camera
    // Aspect follows the widget; it used to be pinned at 16:9, so any other
    // viewport shape stretched the render relative to the overlay.
    final aspect = (_viewportWidth > 0 && _viewportHeight > 0)
        ? _viewportWidth / _viewportHeight
        : 16.0 / 9.0;
    final far = math.max(5000.0, dist * 4.0);
    _nativeCamera!.setProjection(
      fovDegrees: kViewportFovDegrees,
      aspect: aspect,
      near: 0.1,
      // Centimetres: at least 50 m, and past the far side of what the camera
      // orbits at [dist] (a framed level's diagonal is under dist / 1.4).
      far: far,
    );
    _nativeView?.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, math.max(LuminaUnits.dynamicLightingFar, far));

    _nativeCamera!.lookAt(
      eyeX: eyeX,
      eyeY: eyeZ,
      eyeZ: -eyeY,
      centerX: targetX,
      centerY: targetZ,
      centerZ: -targetY,
      upX: isPolar ? math.sin(yawRad) : 0,
      upY: isPolar ? 0 : 1,
      upZ: isPolar ? -math.cos(yawRad) : 0,
    );
    _pushedCameraPose = _editorCameraPose;
    // The blend follows the editor camera.
    _syncLevelPostProcess();
  }

  Widget _buildCameraSpeedHudBtn() {
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(
        'Camera Speed: ${widget.viewModel.cameraSpeedScalar} (${widget.viewModel.cameraSpeedMultiplier}x)\n$_flightHint\nClick to cycle speed 1-8\nRMB + Mouse Wheel to adjust in real-time',
      )),
      child: GestureDetector(
        onTap: () {
          final nextSpeed = widget.viewModel.cameraSpeedScalar >= 8
              ? 1
              : widget.viewModel.cameraSpeedScalar + 1;
          widget.viewModel.setCameraSpeed(nextSpeed);
          _triggerSpeedFeedback();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          height: 24,
          decoration: BoxDecoration(
            color: EditorColors.hudSurface,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: EditorColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.gauge, size: 11, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                'Speed: ${widget.viewModel.cameraSpeedScalar}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: EditorColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudBtn(IconData icon, String tooltipStr, VoidCallback onTap) {
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(tooltipStr)),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: EditorColors.hudSurface,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: EditorColors.border),
          ),
          child: Icon(icon, size: 12, color: EditorColors.foreground),
        ),
      ),
    );
  }
}
