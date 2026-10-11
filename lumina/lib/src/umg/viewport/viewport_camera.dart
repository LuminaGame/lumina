import 'dart:math' as math;

import 'package:lumina/src/umg/viewport/viewport_scene.dart';
import 'package:lumina/src/umg/viewport/viewport_transforms.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// A ray in the runtime frame (Y up, centimetres).
class LuminaViewportRay {
  const LuminaViewportRay(this.origin, this.direction);
  final Vector3 origin;
  final Vector3 direction;

  Vector3 at(double t) => origin + direction * t;

  /// The distance from [p] to the ray (behind the origin: to the origin).
  double distanceTo(Vector3 p) {
    final t = (p - origin).dot(direction);
    return (p - (t < 0 ? origin : at(t))).length;
  }

  /// The ray parameter of the point nearest to [p].
  double closestT(Vector3 p) => math.max(0.0, (p - origin).dot(direction));

  /// Where the ray enters [box] (its parameter), or null when it misses.
  double? hitAabb(Aabb3 box) {
    var tMin = 0.0;
    var tMax = double.infinity;
    for (var i = 0; i < 3; i++) {
      final o = origin[i];
      final d = direction[i];
      final lo = box.min[i];
      final hi = box.max[i];
      if (d.abs() < 1e-12) {
        if (o < lo || o > hi) return null;
        continue;
      }
      var t1 = (lo - o) / d;
      var t2 = (hi - o) / d;
      if (t1 > t2) {
        final s = t1;
        t1 = t2;
        t2 = s;
      }
      tMin = math.max(tMin, t1);
      tMax = math.min(tMax, t2);
      if (tMin > tMax) return null;
    }
    return tMin;
  }
}

/// A Viewport's orbit camera: the player's local orbit (what a drag moves
/// every frame) over the description's camera, and the view and projection
/// it gives at a viewport size. Yaw, pitch and distance are the
/// description's units (degrees, centimetres); the target is authoring
/// space.
class LuminaViewportCamera {
  double yaw = 30.0;
  double pitch = 15.0;
  double distance = 400.0;
  double fov = 45.0;
  bool orthographic = false;
  List<double> target = [0.0, 0.0, 90.0];

  /// The viewport size in pixels.
  double width = 1.0;
  double height = 1.0;

  /// Takes the camera of [scene]'s description.
  void readFrom(LuminaViewportScene scene) {
    final c = scene.camera;
    yaw = scene.yaw;
    pitch = scene.pitch;
    distance = scene.distance;
    fov = c['fov'] is num ? (c['fov'] as num).toDouble() : 45.0;
    orthographic = c['orthographic'] == true;
    target = scene.orbitTarget;
  }

  /// Writes the orbit back into [scene] (on release of a drag).
  void writeTo(LuminaViewportScene scene) {
    scene.setOrbit(yaw, pitch, distance);
    scene.orbitTarget = target;
  }

  void orbit(double dYaw, double dPitch) {
    yaw = (yaw + dYaw) % 360.0;
    if (yaw > 180.0) yaw -= 360.0;
    pitch = (pitch + dPitch).clamp(-89.0, 89.0);
  }

  /// Moves the target across the view by [dx], [dy] pixels.
  void pan(double dx, double dy) {
    final scale = _worldPerPixel();
    final (right, up) = _axesAuthoring();
    for (var i = 0; i < 3; i++) {
      target[i] += (-dx * right[i] + dy * up[i]) * scale;
    }
  }

  /// Multiplies the distance by [factor] (below 1 moves in).
  void zoom(double factor) => distance = (distance * factor).clamp(5.0, 100000.0);

  /// Frames a box (runtime frame, cm): the target at its centre, the
  /// distance fitting its bounding sphere.
  void frame(Aabb3 box) {
    final centre = box.center;
    target = LuminaAxes.toAuthoringLocation(centre);
    final radius = math.max(1.0, (box.max - box.min).length / 2);
    final half = fov * math.pi / 360.0;
    distance = (radius / math.sin(half) * 1.05).clamp(10.0, 100000.0);
  }

  double _worldPerPixel() {
    final half = fov * math.pi / 360.0;
    return 2 * distance * math.tan(half) / math.max(1.0, height);
  }

  /// The view's right and up directions in authoring space.
  (List<double>, List<double>) _axesAuthoring() {
    final y = yaw * math.pi / 180.0;
    final p = pitch * math.pi / 180.0;
    // Forward (eye → target) is the orbit offset reversed; right = forward ×
    // Z, up = right × forward (authoring is right-handed, Z up).
    final forward = Vector3(math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), -math.sin(p));
    final right = forward.cross(Vector3(0, 0, 1))..normalize();
    final up = right.cross(forward)..normalize();
    return ([right.x, right.y, right.z], [up.x, up.y, up.z]);
  }

  /// The eye (runtime frame).
  Vector3 get eye => LuminaViewportTransforms.orbitEye(target, yaw, pitch, distance);

  /// The target (runtime frame).
  Vector3 get centre => LuminaAxes.location(target);

  Matrix4 get viewMatrix => makeViewMatrix(eye, centre, Vector3(0, 1, 0));

  double get near => orthographic ? 1.0 : math.max(1.0, distance / 1000.0);
  double get far => math.max(10000.0, distance * 20.0);

  /// Half the orthographic view's height (cm).
  double get orthoHalfHeight => distance * math.tan(fov * math.pi / 360.0);

  Matrix4 get projectionMatrix {
    final aspect = width / math.max(1.0, height);
    if (orthographic) {
      final h = orthoHalfHeight;
      return makeOrthographicMatrix(-h * aspect, h * aspect, -h, h, -far, far);
    }
    return makePerspectiveMatrix(fov * math.pi / 180.0, aspect, near, far);
  }

  /// The ray under pixel ([x], [y]) (top-left origin).
  LuminaViewportRay rayAt(double x, double y) {
    final inv = Matrix4.inverted(projectionMatrix * viewMatrix);
    final nx = 2 * x / math.max(1.0, width) - 1;
    final ny = 1 - 2 * y / math.max(1.0, height);
    Vector3 unproject(double z) {
      final v = inv.transform(Vector4(nx, ny, z, 1));
      return Vector3(v.x / v.w, v.y / v.w, v.z / v.w);
    }

    final a = unproject(-1);
    final b = unproject(1);
    return LuminaViewportRay(a, (b - a).normalized());
  }

  /// [world] (runtime frame) in pixels (top-left origin), or null behind
  /// the camera.
  (double, double)? project(Vector3 world) {
    final v = (projectionMatrix * viewMatrix).transform(Vector4(world.x, world.y, world.z, 1));
    if (v.w <= 1e-9) return null;
    final x = v.x / v.w;
    final y = v.y / v.w;
    return ((x + 1) / 2 * width, (1 - y) / 2 * height);
  }
}
