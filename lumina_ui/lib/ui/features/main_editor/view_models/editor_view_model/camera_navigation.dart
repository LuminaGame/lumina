part of '../editor_view_model.dart';

/// Level viewport camera navigation: fly speed, mouse look, walk, pan,
/// pedestal, orbit, dolly/zoom, WASD flight and reset.
mixin _EditorCameraNavigation on _EditorViewModelState, _EditorCameraAndViewport {
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
}
