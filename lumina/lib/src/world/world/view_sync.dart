part of '../world.dart';

/// Points the bound view's camera and applies the post-process blend at the
/// end of every rendered frame.
extension _LuminaWorldViewSync on LuminaWorld {
  /// Resolves the blender for the current camera and applies the result when
  /// it changed. Runs for every world type that renders (editor and game).
  void _applyPostProcessBlend() {
    final controller = _postProcessController;
    if (controller == null) return;
    final result = postProcessBlender.resolve(postProcessCameraPosition);
    if (_blendApplied != result.settings) {
      controller.apply(result.settings, asBaseline: false);
      _blendApplied = result.settings;
    }
    final focus = result.focusDistance;
    if (focus != null && focus != _blendFocusDistance) {
      final camera = controller.view.camera;
      if (camera != null) camera.focusDistance = focus;
      _blendFocusDistance = focus;
    } else if (focus == null) {
      _blendFocusDistance = null;
    }
  }

  /// Points the bound view's camera through [activeCamera], once every
  /// transform of the frame is final. Projection and exposure are pushed again
  /// whenever the viewport or the active camera changes, since the view's
  /// owner may reset its camera's projection on a resize.
  void _syncViewCamera() {
    final view = _filamentView;
    if (view == null || !hasNativeContext) return;
    final camera = activeCamera;
    final target = view.camera;
    final (_, _, width, height) = view.viewport;
    if (target == null || width <= 0 || height <= 0) return;
    viewportSize = (width, height);
    final override = viewTargetPov;
    if (override != null) {
      // A view target or blend: look from the manager's POV, and let the
      // camera component re-sync everything once it is in charge again.
      _viewCameraSource = null;
      final eye = override.location;
      final forward = override.rotation.rotateVector(Vector3(0, 0, -1));
      final up = override.rotation.rotateVector(Vector3(0, 1, 0));
      // A camera view target (a placed camera actor) is seen through its
      // own lens: projection, clip planes and exposure; the pose and field of
      // view stay the manager's (shakes, FOV overrides).
      final lens = override.camera;
      final aspect = width / height;
      final near = lens?.nearClipPlane ?? camera?.nearClipPlane ?? override.nearClip;
      final far = lens?.farClipPlane ?? camera?.farClipPlane ?? override.farClip;
      if (lens != null && lens.projectionMode == CameraProjectionMode.orthographic) {
        final halfWidth = lens.orthographicWidth * 0.5;
        final halfHeight = halfWidth / aspect;
        target.setProjectionOrtho(left: -halfWidth, right: halfWidth, bottom: -halfHeight, top: halfHeight, near: near, far: far);
      } else {
        target.setProjection(fovDegrees: override.fovDegrees, aspect: aspect, near: near, far: far);
      }
      if (lens != null) {
        LuminaAutoExposure.applyTo(lens, LuminaAutoExposure.ev100ForWorld(this));
        target.setExposure(aperture: lens.aperture, shutterSpeed: lens.shutterSpeed, sensitivity: lens.sensitivity);
      }
      target.lookAt(
        eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z,
        centerX: eye.x + forward.x, centerY: eye.y + forward.y, centerZ: eye.z + forward.z,
        upX: up.x, upY: up.y, upZ: up.z,
      );
      return;
    }
    if (camera == null) return;
    if (!identical(camera, _viewCameraSource) || _viewCameraViewportSize != (width, height)) {
      camera.invalidateNativeSync();
      _viewCameraSource = camera;
      _viewCameraViewportSize = (width, height);
    }
    camera.aspectRatio = width / height;
    // Auto-exposed for the level's lights:
    // a lamp-lit level is not rendered at sunny 16.
    LuminaAutoExposure.applyTo(camera, LuminaAutoExposure.ev100ForWorld(this));
    camera.syncWithFilamentCamera(target);
  }
}
