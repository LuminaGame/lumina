import 'dart:math' as math;

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode, EditorViewModel;

/// Where a view of the level looks from (the level's shared pose type).
typedef SequencerViewPose = LevelViewPose;

/// The Sequencer viewport's editor camera: the level viewport's orbit
/// camera (yaw, pitch and distance around a target, stored Z up) with its
/// own pose, so navigating the Sequencer's view leaves the level viewport's
/// camera where it was. Also turns a camera actor into the pose a camera
/// lock looks through.
class SequencerViewportCamera {
  SequencerViewportCamera({this.yaw = 0.0, this.pitch = 20.0, this.distance = 800.0, List<double>? target})
      : target = target ?? [0.0, 0.0, 0.0];

  /// Starts where the level viewport's camera is.
  factory SequencerViewportCamera.fromEditor(EditorViewModel vm) => SequencerViewportCamera(
        yaw: vm.cameraYaw,
        pitch: vm.cameraPitch,
        distance: vm.cameraDistance,
        target: [vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ],
      );

  /// Degrees; yaw 0 looks along +Y, positive pitch puts the eye above the target.
  double yaw;
  double pitch;

  /// Centimetres from the eye to [target].
  double distance;

  /// The orbit pivot, stored axes (Z up), centimetres.
  List<double> target;

  /// The vertical field of view a camera actor without a camera component
  /// renders with (the runtime camera component's default).
  static const double defaultCameraFovDegrees = CameraActorView.defaultFovDegrees;

  /// The eye in stored axes (Z up).
  List<double> get eyeAuthoring {
    final y = yaw * math.pi / 180.0;
    final p = pitch.clamp(-90.0, 90.0) * math.pi / 180.0;
    return [
      target[0] + distance * math.cos(p) * math.sin(y),
      target[1] - distance * math.cos(p) * math.cos(y),
      target[2] + distance * math.sin(p),
    ];
  }

  /// The pose the editor camera looks through.
  SequencerViewPose editorPose({double fovDegrees = 45.0}) {
    final eye = LuminaAxes.location(eyeAuthoring);
    final forward = LuminaAxes.location(target) - eye;
    if (forward.length2 < 1e-12) forward.setValues(0, 0, -1);
    forward.normalize();
    // Straight down or up the world up is parallel to the gaze: use the
    // yaw direction instead, as the level viewport does.
    final y = yaw * math.pi / 180.0;
    final up = pitch.abs() > 89.5 ? Vector3(math.sin(y), 0, -math.cos(y)) : Vector3(0, 1, 0);
    return SequencerViewPose(eye: eye, forward: forward, up: up, fovDegrees: fovDegrees);
  }

  /// Tumbles around [target] (pointer pixels).
  void orbit(double dx, double dy) {
    yaw += dx * 0.3;
    pitch = (pitch + dy * 0.3).clamp(-89.0, 89.0);
  }

  /// Slides the view in its own plane (pointer pixels), faster when further out.
  void pan(double dx, double dy) {
    final y = yaw * math.pi / 180.0;
    final p = pitch * math.pi / 180.0;
    final rightX = math.cos(y), rightY = math.sin(y);
    final upX = -math.sin(y) * math.sin(p), upY = math.cos(y) * math.sin(p), upZ = math.cos(p);
    final speed = (distance / 300.0).clamp(0.2, 5.0) * 0.7;
    target = [
      target[0] - (rightX * dx - upX * dy) * speed,
      target[1] - (rightY * dx - upY * dy) * speed,
      target[2] + upZ * dy * speed,
    ];
  }

  /// Moves toward (negative) or away from (positive) [target].
  void dolly(double delta) {
    distance = (distance + delta * 0.8 * math.max(1.0, distance / 500.0)).clamp(5.0, 200000.0);
  }

  /// Flies the eye (and the pivot with it) along the gaze, the horizontal
  /// right and the world up; each of [forward], [right], [up] is −1, 0 or 1.
  void fly({required int forward, required int right, required int up, required double dt, double speed = 400.0}) {
    final y = yaw * math.pi / 180.0;
    final p = pitch * math.pi / 180.0;
    final step = speed * dt;
    final fx = -math.cos(p) * math.sin(y), fy = math.cos(p) * math.cos(y), fz = -math.sin(p);
    final rx = math.cos(y), ry = math.sin(y);
    target = [
      target[0] + (fx * forward + rx * right) * step,
      target[1] + (fy * forward + ry * right) * step,
      target[2] + (fz * forward + up) * step,
    ];
  }

  /// Frames a sphere (stored axes, centimetres) the way the level viewport
  /// frames a selection.
  void focus({required List<double> center, required double radius}) {
    target = List<double>.of(center);
    distance = math.max(radius * 2.8, 100.0);
  }

  /// The pose a camera lock looks through [camera]: from its location along
  /// its forward (+Y stored, rotated by its rotation), with the field of
  /// view of its camera component.
  static SequencerViewPose lockedPose(EditorActorNode camera) => CameraActorView.pose(camera);

  /// [camera]'s vertical field of view in degrees.
  static double cameraFovDegrees(EditorActorNode camera) => CameraActorView.settingsOf(camera).fieldOfView;

  /// Whether [actor] is a camera the view can look through.
  static bool isCamera(EditorActorNode actor) => CameraActorView.isCamera(actor);
}
