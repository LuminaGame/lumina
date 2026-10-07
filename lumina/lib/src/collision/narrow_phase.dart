import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/collision/shapes.dart';

/// Mutable container for contact geometry and penetration information.
class ContactResult {
  bool isColliding = false;
  double penetrationDepth = 0.0;

  /// Normal pointing from Shape B towards Shape A.
  final Vector3 normal = Vector3.zero();

  /// Contact point in world space.
  final Vector3 contactPoint = Vector3.zero();

  void reset() {
    isColliding = false;
    penetrationDepth = 0.0;
    normal.setZero();
    contactPoint.setZero();
  }
}

/// Finds the closest points between two 3D line segments [p1, q1] and [p2, q2].
///
/// Writes closest points into [outA] and [outB] and returns the Euclidean distance between them.
double closestPointsBetweenSegments(
  Vector3 p1,
  Vector3 q1,
  Vector3 p2,
  Vector3 q2,
  Vector3 outA,
  Vector3 outB,
) {
  final d1 = q1 - p1;
  final d2 = q2 - p2;
  final r = p1 - p2;

  final a = d1.dot(d1);
  final e = d2.dot(d2);
  final f = d2.dot(r);

  double s = 0.0;
  double t = 0.0;

  // Check if either or both segments degenerate into points
  if (a <= 1e-9 && e <= 1e-9) {
    outA.setFrom(p1);
    outB.setFrom(p2);
    return (outA - outB).length;
  }

  if (a <= 1e-9) {
    s = 0.0;
    t = (f / e).clamp(0.0, 1.0);
  } else {
    final c = d1.dot(r);
    if (e <= 1e-9) {
      t = 0.0;
      s = (-c / a).clamp(0.0, 1.0);
    } else {
      final b = d1.dot(d2);
      final denom = a * e - b * b;

      if (denom.abs() > 1e-9) {
        s = ((b * f - c * e) / denom).clamp(0.0, 1.0);
      } else {
        s = 0.0;
      }

      t = (b * s + f) / e;
      if (t < 0.0) {
        t = 0.0;
        s = (-c / a).clamp(0.0, 1.0);
      } else if (t > 1.0) {
        t = 1.0;
        s = ((b - c) / a).clamp(0.0, 1.0);
      }
    }
  }

  outA.setFrom(p1 + (d1 * s));
  outB.setFrom(p2 + (d2 * t));
  return (outA - outB).length;
}

/// Analytic Sphere vs Sphere narrow-phase test.
bool sphereVsSphere(
  SphereShape sA,
  Matrix4 tA,
  SphereShape sB,
  Matrix4 tB,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final posB = tB.getTranslation();

  final delta = posA - posB;
  final dist = delta.length;
  final sumR = sA.radius + sB.radius;

  if (dist < sumR) {
    out.isColliding = true;
    out.penetrationDepth = sumR - dist;
    if (dist > 1e-9) {
      out.normal.setFrom(delta / dist);
    } else {
      out.normal.setValues(0.0, 1.0, 0.0);
    }
    out.contactPoint.setFrom(posB + (out.normal * sB.radius));
    return true;
  }

  out.isColliding = false;
  return false;
}

/// Analytic Capsule vs Capsule narrow-phase test.
bool capsuleVsCapsule(
  CapsuleShape sA,
  Matrix4 tA,
  CapsuleShape sB,
  Matrix4 tB,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final posB = tB.getTranslation();

  final uA = Vector3(tA.entry(0, 1), tA.entry(1, 1), tA.entry(2, 1)).normalized();
  final uB = Vector3(tB.entry(0, 1), tB.entry(1, 1), tB.entry(2, 1)).normalized();

  final segHalfA = math.max(0.0, sA.halfHeight - sA.radius);
  final segHalfB = math.max(0.0, sB.halfHeight - sB.radius);

  final p1 = posA - (uA * segHalfA);
  final q1 = posA + (uA * segHalfA);
  final p2 = posB - (uB * segHalfB);
  final q2 = posB + (uB * segHalfB);

  final ptA = Vector3.zero();
  final ptB = Vector3.zero();
  final dist = closestPointsBetweenSegments(p1, q1, p2, q2, ptA, ptB);

  final sumR = sA.radius + sB.radius;
  if (dist < sumR) {
    out.isColliding = true;
    out.penetrationDepth = sumR - dist;
    final delta = ptA - ptB;
    if (delta.length > 1e-9) {
      out.normal.setFrom(delta.normalized());
    } else {
      out.normal.setValues(0.0, 1.0, 0.0);
    }
    out.contactPoint.setFrom(ptB + (out.normal * sB.radius));
    return true;
  }

  out.isColliding = false;
  return false;
}

/// Analytic Sphere vs Capsule narrow-phase test.
bool sphereVsCapsule(
  SphereShape sA,
  Matrix4 tA,
  CapsuleShape sB,
  Matrix4 tB,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final posB = tB.getTranslation();
  final uB = Vector3(tB.entry(0, 1), tB.entry(1, 1), tB.entry(2, 1)).normalized();

  final segHalfB = math.max(0.0, sB.halfHeight - sB.radius);
  final p1 = posB - (uB * segHalfB);
  final p2 = posB + (uB * segHalfB);

  final ab = p2 - p1;
  final len2 = ab.length2;
  final t = len2 > 1e-9 ? ((posA - p1).dot(ab) / len2).clamp(0.0, 1.0) : 0.0;
  final closestB = p1 + (ab * t);

  final delta = posA - closestB;
  final dist = delta.length;
  final sumR = sA.radius + sB.radius;

  if (dist < sumR) {
    out.isColliding = true;
    out.penetrationDepth = sumR - dist;
    if (dist > 1e-9) {
      out.normal.setFrom(delta / dist);
    } else {
      out.normal.setValues(0.0, 1.0, 0.0);
    }
    out.contactPoint.setFrom(closestB + (out.normal * sB.radius));
    return true;
  }

  out.isColliding = false;
  return false;
}

/// Analytic Sphere vs Box narrow-phase test.
bool sphereVsBox(
  SphereShape sA,
  Matrix4 tA,
  BoxShape sB,
  Matrix4 tB,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final invB = Matrix4.inverted(tB);
  final localSphereCenter = (invB * Vector4(posA.x, posA.y, posA.z, 1.0)).xyz;

  final half = sB.halfExtents;
  final clamped = Vector3(
    localSphereCenter.x.clamp(-half.x, half.x),
    localSphereCenter.y.clamp(-half.y, half.y),
    localSphereCenter.z.clamp(-half.z, half.z),
  );

  final localDelta = localSphereCenter - clamped;
  final localDist2 = localDelta.length2;

  if (localDist2 <= sA.radius * sA.radius) {
    final worldClosest = (tB * Vector4(clamped.x, clamped.y, clamped.z, 1.0)).xyz;
    final worldDelta = posA - worldClosest;
    final worldDist = worldDelta.length;

    out.isColliding = true;
    out.penetrationDepth = sA.radius - worldDist;
    if (worldDist > 1e-9) {
      out.normal.setFrom(worldDelta / worldDist);
    } else {
      out.normal.setValues(0.0, 1.0, 0.0);
    }
    out.contactPoint.setFrom(worldClosest);
    return true;
  }

  out.isColliding = false;
  return false;
}

/// Analytic Sphere vs Cone narrow-phase test.
bool sphereVsCone(
  SphereShape sA,
  Matrix4 tA,
  ConeShape sB,
  Matrix4 tB,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final posB = tB.getTranslation();
  final uB = Vector3(tB.entry(0, 1), tB.entry(1, 1), tB.entry(2, 1)).normalized();

  final h = sB.height;
  final r = sB.radius;
  final pApex = posB + (uB * (h * 0.5));
  final pBase = posB - (uB * (h * 0.5));

  // Distance from sphere to apex
  final toApex = posA - pApex;
  final apexDist = toApex.length;
  if (apexDist < sA.radius) {
    out.isColliding = true;
    out.penetrationDepth = sA.radius - apexDist;
    out.normal.setFrom(apexDist > 1e-9 ? toApex / apexDist : uB);
    out.contactPoint.setFrom(pApex);
    return true;
  }

  // Distance along cone axis
  final proj = (posA - pBase).dot(uB);
  if (proj >= 0.0 && proj <= h) {
    final coneRadiusAtHeight = r * (1.0 - (proj / h));
    final axisPt = pBase + (uB * proj);
    final radialVec = posA - axisPt;
    final radialDist = radialVec.length;

    if (radialDist < coneRadiusAtHeight + sA.radius) {
      out.isColliding = true;
      final effectiveR = coneRadiusAtHeight;
      final delta = radialDist - effectiveR;
      out.penetrationDepth = sA.radius - delta;
      final radNorm = radialDist > 1e-9 ? radialVec / radialDist : Vector3(1.0, 0.0, 0.0);
      out.normal.setFrom(radNorm);
      out.contactPoint.setFrom(axisPt + (radNorm * effectiveR));
      return true;
    }
  }

  out.isColliding = false;
  return false;
}

/// Analytic Capsule vs Plane narrow-phase test.
bool capsuleVsPlane(
  CapsuleShape sA,
  Matrix4 tA,
  Plane plane,
  ContactResult out,
) {
  final posA = tA.getTranslation();
  final uA = Vector3(tA.entry(0, 1), tA.entry(1, 1), tA.entry(2, 1)).normalized();
  final segHalf = math.max(0.0, sA.halfHeight - sA.radius);

  final p1 = posA - (uA * segHalf);
  final p2 = posA + (uA * segHalf);

  final d1 = plane.distanceToVector3(p1);
  final d2 = plane.distanceToVector3(p2);

  final minDist = math.min(d1, d2);
  if (minDist < sA.radius) {
    out.isColliding = true;
    out.penetrationDepth = sA.radius - minDist;
    out.normal.setFrom(plane.normal);
    final closestPt = (d1 < d2) ? p1 : p2;
    out.contactPoint.setFrom(closestPt - (plane.normal * minDist));
    return true;
  }

  out.isColliding = false;
  return false;
}
