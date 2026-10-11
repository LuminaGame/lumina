import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Quaternion helpers for the pose solvers, written out so their conventions
/// are explicit: [qMul] is the Hamilton product (`a · b` turns by `b` first),
/// [qRotate] turns a vector by a unit quaternion the way its rotation matrix
/// does.
abstract final class LuminaPoseQuat {
  /// `a · b`.
  static Quaternion qMul(Quaternion a, Quaternion b) => Quaternion(
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
      );

  /// The inverse of a unit quaternion.
  static Quaternion qConj(Quaternion q) => Quaternion(-q.x, -q.y, -q.z, q.w);

  /// [v] turned by the unit quaternion [q].
  static Vector3 qRotate(Quaternion q, Vector3 v) {
    // v + 2w(u × v) + 2 u × (u × v), u = (x, y, z).
    final ux = q.x, uy = q.y, uz = q.z, w = q.w;
    final cx = uy * v.z - uz * v.y, cy = uz * v.x - ux * v.z, cz = ux * v.y - uy * v.x;
    final dx = uy * cz - uz * cy, dy = uz * cx - ux * cz, dz = ux * cy - uy * cx;
    return Vector3(v.x + 2 * (w * cx + dx), v.y + 2 * (w * cy + dy), v.z + 2 * (w * cz + dz));
  }

  /// A turn of [radians] about the unit [axis].
  static Quaternion axisAngle(Vector3 axis, double radians) {
    final h = radians * 0.5;
    final s = math.sin(h);
    return Quaternion(axis.x * s, axis.y * s, axis.z * s, math.cos(h));
  }

  /// The shortest turn taking direction [from] to direction [to].
  static Quaternion fromTo(Vector3 from, Vector3 to) {
    final a = from.normalized(), b = to.normalized();
    final d = a.dot(b);
    if (d > 1 - 1e-12) return Quaternion.identity();
    if (d < -1 + 1e-12) {
      var axis = a.cross(Vector3(1, 0, 0));
      if (axis.length2 < 1e-12) axis = a.cross(Vector3(0, 1, 0));
      return axisAngle(axis.normalized(), math.pi);
    }
    final c = a.cross(b);
    final q = Quaternion(c.x, c.y, c.z, 1 + d);
    return q..normalize();
  }

  /// The rotation angle of a unit quaternion, in [0, π].
  static double angleOf(Quaternion q) {
    final w = q.w.abs().clamp(0.0, 1.0);
    return 2 * math.acos(w);
  }

  /// The signed angle [q] turns about the unit [axis] (its twist part).
  static double twistAngle(Quaternion q, Vector3 axis) {
    final p = q.x * axis.x + q.y * axis.y + q.z * axis.z;
    if (p.abs() < 1e-15 && q.w.abs() < 1e-15) return 0.0;
    var a = 2 * math.atan2(p, q.w);
    if (a > math.pi) a -= 2 * math.pi;
    if (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  /// Shortest-path slerp from [a] to [b] by [t].
  static Quaternion slerp(Quaternion a, Quaternion b, double t) {
    var bx = b.x, by = b.y, bz = b.z, bw = b.w;
    var d = a.x * bx + a.y * by + a.z * bz + a.w * bw;
    if (d < 0) {
      d = -d;
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    double k0, k1;
    if (d > 0.9995) {
      k0 = 1 - t;
      k1 = t;
    } else {
      final th = math.acos(d.clamp(-1.0, 1.0));
      final s = math.sin(th);
      k0 = math.sin((1 - t) * th) / s;
      k1 = math.sin(t * th) / s;
    }
    return Quaternion(a.x * k0 + bx * k1, a.y * k0 + by * k1, a.z * k0 + bz * k1, a.w * k0 + bw * k1)..normalize();
  }

  /// [v] with its component along the unit [axis] removed.
  static Vector3 across(Vector3 v, Vector3 axis) => v - axis * v.dot(axis);

  /// The signed angle from [a] to [b] about the unit [axis] (both projected
  /// onto the plane across it).
  static double signedAngle(Vector3 a, Vector3 b, Vector3 axis) {
    final pa = across(a, axis), pb = across(b, axis);
    if (pa.length2 < 1e-20 || pb.length2 < 1e-20) return 0.0;
    return math.atan2(axis.dot(pa.cross(pb)), pa.dot(pb));
  }
}
