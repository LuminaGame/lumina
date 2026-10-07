import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart' show FilamentCamera;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;
import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_properties.dart';

/// Where a view of the level looks from: runtime axes (Y up), centimetres,
/// and the vertical field of view.
class LevelViewPose {
  const LevelViewPose({required this.eye, required this.forward, required this.up, required this.fovDegrees});

  final Vector3 eye;
  final Vector3 forward;
  final Vector3 up;
  final double fovDegrees;
}

/// Turns a camera actor into a view of the level: the pose it looks from and
/// the lens it looks through (its `LuminaCameraComponent`, read by
/// [LuminaCameraSettings]). The level viewport's camera preview and the
/// Sequencer's camera lock both look through a camera this way.
class CameraActorView {
  const CameraActorView._();

  /// The vertical field of view a camera actor without a camera component
  /// renders with (the runtime camera component's default).
  static const double defaultFovDegrees = LuminaCameraSettings.defaultFieldOfView;

  /// Whether [actor] is a camera a view can look through.
  static bool isCamera(EditorActorNode actor) => actor.type.contains('Camera');

  /// [camera]'s settings; the runtime defaults when it has no camera
  /// component (an unseeded camera from an older level).
  static LuminaCameraSettings settingsOf(EditorActorNode camera) {
    final component = CameraActorProperties.componentOf(camera);
    if (component != null) return LuminaCameraSettings.fromProperties(component.properties);
    for (final c in camera.components) {
      if (c.properties.containsKey('fieldOfView') || c.properties.containsKey('fov')) {
        return LuminaCameraSettings.fromProperties(c.properties);
      }
    }
    return const LuminaCameraSettings();
  }

  /// The pose [camera] looks through: from its location along its forward
  /// (+Y stored, rotated by its rotation), with its vertical field of view.
  static LevelViewPose pose(EditorActorNode camera) {
    // As a matrix: vector_math's Quaternion.rotated turns the other way.
    final r = LuminaAxes.rotation(camera.rotation).asRotationMatrix();
    final forward = r.transformed(LuminaAxes.location(const [0, 1, 0]))..normalize();
    final up = r.transformed(LuminaAxes.location(const [0, 0, 1]))..normalize();
    return LevelViewPose(
      eye: LuminaAxes.location(camera.location),
      forward: forward,
      up: up,
      fovDegrees: settingsOf(camera).fieldOfView,
    );
  }

  /// Points [target] through [camera] for a picture of [aspect] (width /
  /// height): its pose, its projection (perspective field of view or
  /// orthographic width) and clip planes, and its exposure — its own
  /// aperture, shutter speed and ISO, or with Auto Exposure [metered] (the
  /// level viewport's camera, metered from the level's lights) when given.
  /// Returns the far clip plane, for the view's dynamic lighting range.
  static double apply(FilamentCamera target, EditorActorNode camera, {required double aspect, FilamentCamera? metered}) {
    final s = settingsOf(camera);
    final p = pose(camera);
    final a = aspect.isFinite && aspect > 0 ? aspect : 16 / 9;
    if (s.projectionMode == CameraProjectionMode.orthographic) {
      final halfWidth = s.orthoWidth * 0.5;
      final halfHeight = halfWidth / a;
      target.setProjectionOrtho(
        left: -halfWidth,
        right: halfWidth,
        bottom: -halfHeight,
        top: halfHeight,
        near: s.nearClipPlane,
        far: s.farClipPlane,
      );
    } else {
      target.setProjection(fovDegrees: s.fieldOfView, aspect: a, near: s.nearClipPlane, far: s.farClipPlane);
    }
    final e = p.eye, f = p.forward, u = p.up;
    target.lookAt(
      eyeX: e.x,
      eyeY: e.y,
      eyeZ: e.z,
      centerX: e.x + f.x,
      centerY: e.y + f.y,
      centerZ: e.z + f.z,
      upX: u.x,
      upY: u.y,
      upZ: u.z,
    );
    if (!s.autoExposure) {
      target.setExposure(aperture: s.aperture, shutterSpeed: s.shutterSpeed, sensitivity: s.sensitivity);
    } else if (metered != null && !metered.isDisposed) {
      target.setExposure(aperture: metered.aperture, shutterSpeed: metered.shutterSpeed, sensitivity: metered.sensitivity);
    }
    return math.max(s.farClipPlane, s.nearClipPlane);
  }
}
