part of '../sub_editor_3d_viewport.dart';

/// Orbit camera: brush rays, floor taps, WASD fly moves, reset and the
/// camera test getters.
mixin _SubEditor3DViewportCamera on _SubEditor3DViewportStateBase {
  /// The orbit camera's elevation in degrees (positive: above the target).
  @visibleForTesting
  double get cameraPitchForTest => _cameraPitch;

  /// The orbit camera's distance from its target.
  @visibleForTesting
  double get cameraDistanceForTest => _cameraDistance;

  /// The viewport's width / height.
  @visibleForTesting
  double get viewportAspectForTest => _viewportAspect;

  /// The orbit camera's yaw in degrees.
  @visibleForTesting
  double get cameraYawForTest => _cameraYaw;

  /// The orbit camera's target (runtime frame), pan included.
  @visibleForTesting
  Vector3 get cameraTargetForTest => _yUpTarget();

  /// The Y-up orbit camera's ray through [local] (see [viewportRay]).
  @override
  ViewportRay? _brushRay(Offset local) => viewportRay(
        local: local,
        size: _viewportSize,
        yawDeg: _cameraYaw,
        pitchDeg: _cameraPitch,
        distance: _cameraDistance,
        target: Vector3(
          _cameraPan.dx + _targetCenterX,
          _cameraPan.dy + _targetCenterY,
          _targetCenterZ,
        ),
      );

  /// Unprojects a click through the same orbit camera `_updateNativeCamera`
  /// programs (Y-up branch) onto the floor plane and reports the hit.
  void _handleFloorTap(Offset local) {
    final hit = unprojectViewportToPlaneY(
      local: local,
      size: _viewportSize,
      yawDeg: _cameraYaw,
      pitchDeg: _cameraPitch,
      distance: _cameraDistance,
      target: Vector3(
        _cameraPan.dx + _targetCenterX,
        _cameraPan.dy + _targetCenterY,
        _targetCenterZ,
      ),
      planeY: widget.floorTapPlaneY,
    );
    if (hit != null) widget.onFloorTap!(hit);
  }

  @override
  void _updateNativeCamera() {
    if (_nativeCamera == null) return;
    final yawRad = _cameraYaw * math.pi / 180.0;
    final pitchRad = _cameraPitch.clamp(-89.0, 89.0) * math.pi / 180.0;

    final cx = _cameraPan.dx + _targetCenterX;
    final cy = _cameraPan.dy + _targetCenterY;
    final cz = _targetCenterZ;

    final bool isZUp =
        !widget.yUpCamera &&
        (widget.glbMesh == null ||
            (widget.glbMesh!.maxBounds[2] - widget.glbMesh!.minBounds[2])
                    .abs() >=
                (widget.glbMesh!.maxBounds[1] - widget.glbMesh!.minBounds[1])
                    .abs());

    _nativeCamera!.setProjection(
      fovDegrees: 45.0,
      aspect: _viewportAspect,
      near: 0.1,
      far: 10000.0,
    );

    if (isZUp) {
      // Z-Up (the common FBX convention): Z is Height, Y is Depth, X is Width
      final eyeX = cx + _cameraDistance * math.cos(pitchRad) * math.sin(yawRad);
      final eyeY = cy - _cameraDistance * math.cos(pitchRad) * math.cos(yawRad);
      final eyeZ = cz + _cameraDistance * math.sin(pitchRad);

      _nativeCamera!.lookAt(
        eyeX: eyeX,
        eyeY: eyeY,
        eyeZ: eyeZ,
        centerX: cx,
        centerY: cy,
        centerZ: cz,
        upX: 0,
        upY: 0,
        upZ: 1,
      );
    } else {
      // Y-Up Standard (glTF): Y is Height, Z is Depth, X is Width
      final eyeX = cx + _cameraDistance * math.cos(pitchRad) * math.sin(yawRad);
      final eyeY = cy + _cameraDistance * math.sin(pitchRad);
      final eyeZ = cz + _cameraDistance * math.cos(pitchRad) * math.cos(yawRad);

      _nativeCamera!.lookAt(
        eyeX: eyeX,
        eyeY: eyeY,
        eyeZ: eyeZ,
        centerX: cx,
        centerY: cy,
        centerZ: cz,
        upX: 0,
        upY: 1,
        upZ: 0,
      );
    }

    final world = _previewWorld;
    final bool sceneLights = widget.renderSceneLights;
    final double ev100;
    if (sceneLights && world != null) {
      final lights = LuminaAutoExposure.lightsIn(world);
      ev100 = LuminaAutoExposure.ev100For(lights, skyLight: false);
    } else {
      ev100 = LuminaAutoExposure.daylightEv100;
    }
    _nativeCamera!.setExposure(
      aperture: LuminaAutoExposure.aperture,
      shutterSpeed: LuminaAutoExposure.shutterSpeedFor(ev100),
      sensitivity: LuminaAutoExposure.sensitivity,
    );
  }

  void _moveWASD(String key) {
    setState(() {
      final isNative = _nativeScale;
      final step = isNative
          ? (widget.initialCameraDistance != null
                ? widget.initialCameraDistance! / 16.0
                : 0.5)
          : 15.0;
      final yawRad = _cameraYaw * math.pi / 180.0;

      final fwdX = -math.sin(yawRad);
      final fwdY = math.cos(yawRad);
      final rightX = math.cos(yawRad);
      final rightY = math.sin(yawRad);

      switch (key) {
        case 'w':
        case 'arrow up':
          _cameraPan += Offset(fwdX * step, -fwdY * step);
          break;
        case 's':
        case 'arrow down':
          _cameraPan -= Offset(fwdX * step, -fwdY * step);
          break;
        case 'a':
        case 'arrow left':
          _cameraPan -= Offset(rightX * step, -rightY * step);
          break;
        case 'd':
        case 'arrow right':
          _cameraPan += Offset(rightX * step, -rightY * step);
          break;
        case 'q':
          _cameraDistance = (_cameraDistance + (isNative ? 1.0 : 20.0)).clamp(
            0.5,
            1500.0,
          );
          break;
        case 'e':
          _cameraDistance = (_cameraDistance - (isNative ? 1.0 : 20.0)).clamp(
            0.5,
            1500.0,
          );
          break;
      }
      _updateNativeCamera();
    });
  }

  void _resetCamera() {
    setState(() {
      final isNative = _nativeScale;
      _cameraYaw = widget.initialCameraYaw ?? -35.0;
      _cameraPitch = 25.0;
      _cameraDistance =
          widget.initialCameraDistance ?? (isNative ? 8.0 : 350.0);
      if (_isMaterialPreview && _nativeEngine != null) {
        _cameraDistance = _materialFitDistance();
        _materialFramed = true;
      }
      _cameraPan = Offset.zero;
      _updateNativeCamera();
    });
  }
}
