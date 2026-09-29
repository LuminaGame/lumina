import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math_64.dart';

/// A camera ray through a viewport pixel: [origin] is the eye, [direction]
/// is unit length.
class ViewportRay {
  final Vector3 origin;
  final Vector3 direction;

  const ViewportRay(this.origin, this.direction);

  /// The point [t] units along the ray.
  Vector3 at(double t) => origin + direction * t;
}

/// A sub-editor tool that paints with the mouse in the 3D viewport — the
/// Landscape editor's sculpt and foliage brushes.
///
/// With one, `SubEditor3DViewport` reports the camera ray under the mouse on
/// every hover, and a plain primary-button press / drag / release (no Alt)
/// becomes a brush stroke instead of an orbit. Alt+LMB orbit, RMB look,
/// Alt+RMB dolly, MMB pan and the wheel keep driving the camera.
class ViewportBrushInput {
  /// The mouse moved over the viewport with no button held.
  final void Function(ViewportRay ray) onHover;

  /// A plain LMB press; [invert] is Shift. Return true to take the press (no
  /// orbit until release), false to leave it to the camera.
  final bool Function(ViewportRay ray, {required bool invert}) onStrokeStart;

  /// The pressed mouse moved.
  final void Function(ViewportRay ray) onStrokeUpdate;

  /// The button came up (or the pointer was cancelled).
  final void Function() onStrokeEnd;

  const ViewportBrushInput({
    required this.onHover,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });
}

/// The ray of the sub-editor's Y-up orbit camera through a viewport pixel.
///
/// Mirrors `SubEditor3DViewport._updateNativeCamera` (Y-up branch): the eye
/// orbits [target] at [distance] with [yawDeg] / [pitchDeg], looks at the
/// target with `(0, 1, 0)` up and a vertical field of view of [fovDeg] —
/// exactly what Filament is given, so the ray passes through what the pixel
/// shows. Returns null for an empty viewport or a degenerate camera.
ViewportRay? viewportRay({
  required Offset local,
  required Size size,
  required double yawDeg,
  required double pitchDeg,
  required double distance,
  required Vector3 target,
  double fovDeg = 45.0,
}) {
  if (size.width <= 0 || size.height <= 0) return null;
  final yaw = yawDeg * math.pi / 180.0;
  final pitch = pitchDeg.clamp(-89.0, 89.0) * math.pi / 180.0;
  final eye = Vector3(
    target.x + distance * math.cos(pitch) * math.sin(yaw),
    target.y + distance * math.sin(pitch),
    target.z + distance * math.cos(pitch) * math.cos(yaw),
  );
  final forward = (target - eye);
  if (forward.length2 == 0) return null;
  forward.normalize();
  final up = Vector3(0.0, 1.0, 0.0);
  final right = forward.cross(up);
  if (right.length2 < 1e-12) return null;
  right.normalize();
  final camUp = right.cross(forward)..normalize();

  final ndcX = (2.0 * local.dx / size.width) - 1.0;
  final ndcY = 1.0 - (2.0 * local.dy / size.height);
  final tanHalf = math.tan(fovDeg * 0.5 * math.pi / 180.0);
  final aspect = size.width / size.height;
  final dir = forward + right * (ndcX * tanHalf * aspect) + camUp * (ndcY * tanHalf);
  dir.normalize();
  return ViewportRay(eye, dir);
}

/// Unprojects a viewport pixel of the sub-editor's Y-up orbit camera onto
/// the horizontal plane `y == planeY` (see [viewportRay]). Returns `null` when
/// the ray never reaches the plane (parallel or behind the camera).
Vector3? unprojectViewportToPlaneY({
  required Offset local,
  required Size size,
  required double yawDeg,
  required double pitchDeg,
  required double distance,
  required Vector3 target,
  required double planeY,
  double fovDeg = 45.0,
}) {
  final ray = viewportRay(
    local: local,
    size: size,
    yawDeg: yawDeg,
    pitchDeg: pitchDeg,
    distance: distance,
    target: target,
    fovDeg: fovDeg,
  );
  if (ray == null) return null;
  final dir = ray.direction;
  if (dir.y.abs() < 1e-9) return null;
  final t = (planeY - ray.origin.y) / dir.y;
  if (t <= 0) return null;
  final hit = ray.at(t);
  return Vector3(hit.x, planeY, hit.z);
}

/// Projects a 3D world coordinate onto viewport screen coordinates (in pixels)
/// matching `SubEditor3DViewport._updateNativeCamera`.
///
/// Returns `null` if the point is behind or on the camera plane, if [size] is
/// non-positive, or if the point (or the camera) is not finite — a NaN or
/// infinite world position never becomes a NaN `Offset`, which `Canvas`
/// throws on.
Offset? projectWorldToViewport({
  required Vector3 worldPos,
  required Size size,
  required double yawDeg,
  required double pitchDeg,
  required double distance,
  required Vector3 target,
  bool isZUp = false,
  double fovDeg = 45.0,
}) {
  if (size.width <= 0 || size.height <= 0) return null;
  if (!worldPos.x.isFinite || !worldPos.y.isFinite || !worldPos.z.isFinite) return null;
  if (!distance.isFinite || !target.x.isFinite || !target.y.isFinite || !target.z.isFinite) return null;
  final yaw = yawDeg * math.pi / 180.0;
  final pitch = pitchDeg.clamp(-89.0, 89.0) * math.pi / 180.0;

  final Vector3 eye;
  final Vector3 up;
  if (isZUp) {
    // Z-Up: Z is height, Y is depth, X is width
    eye = Vector3(
      target.x + distance * math.cos(pitch) * math.sin(yaw),
      target.y - distance * math.cos(pitch) * math.cos(yaw),
      target.z + distance * math.sin(pitch),
    );
    up = Vector3(0.0, 0.0, 1.0);
  } else {
    // Y-Up: Y is height, Z is depth, X is width
    eye = Vector3(
      target.x + distance * math.cos(pitch) * math.sin(yaw),
      target.y + distance * math.sin(pitch),
      target.z + distance * math.cos(pitch) * math.cos(yaw),
    );
    up = Vector3(0.0, 1.0, 0.0);
  }

  final forward = (target - eye);
  if (forward.length2 == 0) return null;
  forward.normalize();

  final right = forward.cross(up);
  if (right.length2 < 1e-12) return null;
  right.normalize();
  final camUp = right.cross(forward)..normalize();

  final toPoint = worldPos - eye;
  final depth = toPoint.dot(forward);
  // `NaN <= 0.001` is false: the finite check is explicit.
  if (!depth.isFinite || depth <= 0.001) return null;

  final xCam = toPoint.dot(right);
  final yCam = toPoint.dot(camUp);

  final tanHalf = math.tan(fovDeg * 0.5 * math.pi / 180.0);
  final aspect = size.width / size.height;

  final ndcX = xCam / (depth * tanHalf * aspect);
  final ndcY = yCam / (depth * tanHalf);

  final screenX = (ndcX + 1.0) * 0.5 * size.width;
  final screenY = (1.0 - ndcY) * 0.5 * size.height;
  if (!screenX.isFinite || !screenY.isFinite) return null;

  return Offset(screenX, screenY);
}

