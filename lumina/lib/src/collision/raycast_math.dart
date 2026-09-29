import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

import 'convex_hull.dart';

/// Tests whether [point] is inside or on the boundary of a capsule.
bool pointInCapsule(
  Vector3 point,
  Vector3 segStart,
  Vector3 segEnd,
  double radius,
) {
  final d = segEnd - segStart;
  final len2 = d.length2;
  final t = len2 > 1e-12 ? ((point - segStart).dot(d) / len2).clamp(0.0, 1.0) : 0.0;
  final closest = segStart + (d * t);
  return (point - closest).length2 <= radius * radius;
}

/// Ray vs Sphere intersection test returning distance `t` or `null`.
double? rayVsSphere(
  Vector3 origin,
  Vector3 dir,
  Vector3 center,
  double radius,
) {
  final m = origin - center;
  final b = m.dot(dir);
  final c = m.dot(m) - (radius * radius);

  if (c > 0.0 && b > 0.0) return null;

  final discr = b * b - c;
  if (discr < 0.0) return null;

  var t = -b - math.sqrt(discr);
  if (t < 0.0) {
    t = -b + math.sqrt(discr);
  }
  return t >= 0.0 ? t : null;
}

/// Ray vs Oriented Box intersection test returning distance `t` or `null`.
double? rayVsBox(
  Vector3 origin,
  Vector3 dir,
  Matrix4 boxTransform,
  Vector3 halfExtents,
) {
  final invTransform = Matrix4.inverted(boxTransform);
  final localOrigin = (invTransform * Vector4(origin.x, origin.y, origin.z, 1.0)).xyz;
  final localDir = (invTransform.getRotation() * dir).normalized();

  double tMin = -double.infinity;
  double tMax = double.infinity;

  for (int i = 0; i < 3; i++) {
    final oi = localOrigin[i];
    final di = localDir[i];
    final hi = halfExtents[i];

    if (di.abs() < 1e-12) {
      if (oi < -hi || oi > hi) return null;
    } else {
      var t1 = (-hi - oi) / di;
      var t2 = (hi - oi) / di;
      if (t1 > t2) {
        final tmp = t1;
        t1 = t2;
        t2 = tmp;
      }
      tMin = math.max(tMin, t1);
      tMax = math.min(tMax, t2);
      if (tMin > tMax || tMax < 0.0) return null;
    }
  }

  return tMin >= 0.0 ? tMin : (tMax >= 0.0 ? tMax : null);
}

/// Ray vs Capsule intersection test (cylinder body + two hemispherical caps).
double? rayVsCapsule(
  Vector3 origin,
  Vector3 dir,
  Vector3 segStart,
  Vector3 segEnd,
  double radius,
) {
  final ba = segEnd - segStart;
  final oa = origin - segStart;

  final bada = ba.dot(ba);
  final badir = ba.dot(dir);
  final baoa = ba.dot(oa);
  final diroa = dir.dot(oa);

  final a = bada - badir * badir;
  final b = bada * diroa - baoa * badir;
  final c = bada * oa.dot(oa) - baoa * baoa - radius * radius * bada;

  double? minT;

  if (a.abs() > 1e-12) {
    final h = b * b - a * c;
    if (h >= 0.0) {
      final tCyl = (-b - math.sqrt(h)) / a;
      if (tCyl >= 0.0) {
        final y = baoa + tCyl * badir;
        if (y >= 0.0 && y <= bada) {
          minT = tCyl;
        }
      }
    }
  }

  // Cap at segStart
  final tCap1 = rayVsSphere(origin, dir, segStart, radius);
  if (tCap1 != null && (minT == null || tCap1 < minT)) {
    minT = tCap1;
  }

  // Cap at segEnd
  final tCap2 = rayVsSphere(origin, dir, segEnd, radius);
  if (tCap2 != null && (minT == null || tCap2 < minT)) {
    minT = tCap2;
  }

  return minT;
}

/// Ray vs [ConvexHullShape] drawn with [transform] (which may carry scale),
/// returning the distance `t` along [dir] (normalized) or `null`.
///
/// The ray is taken into the hull's local frame and clipped against its face
/// planes; the plane it enters through gives [outNormal] (world space, unit
/// length). A ray starting inside the hull hits at `t = 0` with
/// `outNormal = -dir`.
double? rayVsConvexHull(
  Vector3 origin,
  Vector3 dir,
  ConvexHullShape hull,
  Matrix4 transform,
  Vector3 outNormal,
) {
  final inverse = Matrix4.copy(transform);
  if (inverse.invert() == 0.0) return null;
  final o = inverse.transform3(origin.clone());
  final d = inverse.rotate3(dir.clone());

  var tEnter = -double.infinity;
  var tExit = double.infinity;
  ConvexHullPlane? entering;
  for (final plane in hull.planes) {
    final denom = plane.normal.dot(d);
    final dist = plane.normal.dot(o) - plane.offset;
    if (denom.abs() < 1e-15) {
      if (dist > 1e-9) return null; // parallel and outside this face
      continue;
    }
    final t = -dist / denom;
    if (denom < 0) {
      if (t > tEnter) {
        tEnter = t;
        entering = plane;
      }
    } else if (t < tExit) {
      tExit = t;
    }
    if (tEnter > tExit + 1e-9) return null;
  }
  if (tExit < 0) return null;
  if (tEnter <= 0 || entering == null) {
    outNormal.setFrom(-dir);
    return 0.0;
  }
  // Normals take the inverse transpose of the hull's linear part.
  final m = inverse.storage;
  final n = entering.normal;
  outNormal.setValues(
    m[0] * n.x + m[1] * n.y + m[2] * n.z,
    m[4] * n.x + m[5] * n.y + m[6] * n.z,
    m[8] * n.x + m[9] * n.y + m[10] * n.z,
  );
  outNormal.normalize();
  return tEnter;
}
