import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/mesh/pose_authoring/pose_quat.dart';
import 'package:lumina/src/input/input_component.dart';
import 'package:lumina/src/interaction/grab/grabber.dart';
import 'package:lumina/src/world/world.dart';

/// A grabber driven by the mouse over a 3D view: it points along the camera
/// ray through the cursor and holds at a depth (cm, along the camera's
/// forward), so dragging moves a held handle in the plane facing the camera
/// at the depth it was grabbed at; [wheel] pushes it away or pulls it in.
/// The left button is the grip.
///
/// Feed it with [cursor], [leftDown], [viewportSize] and the camera
/// ([cameraLocation], [cameraRotation], [fovYDegrees]; the camera looks down
/// its −Z), or with [syncFromWorld] each frame, which reads the world's view
/// and its input subsystem (the mouse position and `MouseLeft` that
/// Play-In-Editor and a game host inject). No OS input is read.
class LuminaMouseGrabber implements LuminaGrabber {
  LuminaMouseGrabber({this.id = 'mouse', this.depth = 150.0, this.wheelStep = 10.0, this.minDepth = 10.0});

  @override
  final String id;

  /// Cursor in viewport pixels (origin top-left).
  final Vector2 cursor = Vector2.zero();

  /// The view's size in pixels.
  final Vector2 viewportSize = Vector2(1280, 720);

  final Vector3 cameraLocation = Vector3.zero();
  final Quaternion cameraRotation = Quaternion.identity();
  double fovYDegrees = 60.0;

  bool leftDown = false;

  /// Where the grabber holds, along the camera's forward (cm).
  double depth;
  double wheelStep;
  double minDepth;

  /// Pulls the grabber [notches] wheel notches closer (negative: further).
  void wheel(double notches) => depth = math.max(minDepth, depth - notches * wheelStep);

  /// Reads the camera, the viewport size, the cursor and the left button
  /// from [world]. False when the world has no view.
  bool syncFromWorld(LuminaWorld world) {
    final pov = world.viewPov;
    if (pov == null) return false;
    cameraLocation.setFrom(pov.location);
    cameraRotation.setFrom(pov.rotation);
    fovYDegrees = pov.fovDegrees;
    viewportSize.setValues(world.viewportSize.$1.toDouble(), world.viewportSize.$2.toDouble());
    final input = world.getSubsystem<LuminaInputSubsystem>();
    if (input != null) {
      cursor.setFrom(input.mousePosition);
      leftDown = input.isKeyDown(LuminaKey.mouseLeft);
    }
    return true;
  }

  Vector3 get _forward => LuminaPoseQuat.qRotate(cameraRotation, Vector3(0, 0, -1));

  /// The camera-space direction through the cursor with forward length 1.
  Vector3 _through() {
    final w = viewportSize.x <= 0 ? 1.0 : viewportSize.x, h = viewportSize.y <= 0 ? 1.0 : viewportSize.y;
    final tanHalf = math.tan(fovYDegrees * math.pi / 360.0);
    final ndcX = cursor.x / w * 2 - 1, ndcY = 1 - cursor.y / h * 2;
    return LuminaPoseQuat.qRotate(cameraRotation, Vector3(ndcX * tanHalf * w / h, ndcY * tanHalf, -1));
  }

  @override
  LuminaGrabRay get ray => LuminaGrabRay(cameraLocation, _through());

  @override
  Matrix4 get worldTransform => Matrix4.compose(cameraLocation + _through() * depth, cameraRotation, Vector3.all(1));

  @override
  double get grip => leftDown ? 1.0 : 0.0;

  @override
  bool get isTracked => true;

  @override
  void pulse(double amplitude, double seconds) {}

  @override
  void grabbedAt(Vector3 point) => depth = math.max(minDepth, (point - cameraLocation).dot(_forward));
}
