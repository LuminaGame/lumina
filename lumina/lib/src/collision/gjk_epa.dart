import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/collision/narrow_phase.dart';
import 'package:lumina/src/collision/heightfield.dart';
import 'package:lumina/src/collision/shapes.dart';

/// Support point on the Minkowski difference $A - B$.
class SimplexVertex {
  final Vector3 point = Vector3.zero();
  final Vector3 pointA = Vector3.zero();
  final Vector3 pointB = Vector3.zero();

  void set(Vector3 p, Vector3 a, Vector3 b) {
    point.setFrom(p);
    pointA.setFrom(a);
    pointB.setFrom(b);
  }
}

/// Simplex structure for 3D GJK algorithm.
class GjkSimplex {
  final List<SimplexVertex> vertices = List.generate(4, (_) => SimplexVertex());
  int count = 0;

  void push(Vector3 p, Vector3 a, Vector3 b) {
    if (count < 4) {
      vertices[count].set(p, a, b);
      count++;
    }
  }

  void reset() {
    count = 0;
  }
}

/// Computes the furthest support point on [shape] in [direction] in world space.
///
/// [transform] may carry scale; only [BoxShape] and [ConvexHullShape] honour
/// it (the other primitives read their dimensions from the shape).
Vector3 support(CollisionShape shape, Matrix4 transform, Vector3 direction, Vector3 out) {
  final pos = transform.getTranslation();

  if (shape is SphereShape) {
    final dNorm = direction.length2 > 1e-12 ? direction.normalized() : Vector3(0.0, 1.0, 0.0);
    out.setFrom(pos + (dNorm * shape.radius));
    return out;
  }

  if (shape is BoxShape) {
    final rot = transform.getRotation();
    final localD = rot.transposed() * direction;
    final lx = localD.x >= 0.0 ? shape.halfExtents.x : -shape.halfExtents.x;
    final ly = localD.y >= 0.0 ? shape.halfExtents.y : -shape.halfExtents.y;
    final lz = localD.z >= 0.0 ? shape.halfExtents.z : -shape.halfExtents.z;
    out.setFrom(pos + (rot * Vector3(lx, ly, lz)));
    return out;
  }

  if (shape is CapsuleShape) {
    final u = Vector3(transform.entry(0, 1), transform.entry(1, 1), transform.entry(2, 1)).normalized();
    final segHalf = math.max(0.0, shape.halfHeight - shape.radius);
    final segPt = (direction.dot(u) >= 0.0) ? pos + (u * segHalf) : pos - (u * segHalf);
    final dNorm = direction.length2 > 1e-12 ? direction.normalized() : Vector3(0.0, 1.0, 0.0);
    out.setFrom(segPt + (dNorm * shape.radius));
    return out;
  }

  if (shape is CylinderShape) {
    final u = Vector3(transform.entry(0, 1), transform.entry(1, 1), transform.entry(2, 1)).normalized();
    final capCenter = (direction.dot(u) >= 0.0) ? pos + (u * (shape.height * 0.5)) : pos - (u * (shape.height * 0.5));
    final radial = direction - (u * direction.dot(u));
    final radNorm = radial.length2 > 1e-12 ? radial.normalized() : Vector3.zero();
    out.setFrom(capCenter + (radNorm * shape.radius));
    return out;
  }

  if (shape is ConeShape) {
    final u = Vector3(transform.entry(0, 1), transform.entry(1, 1), transform.entry(2, 1)).normalized();
    final pApex = pos + (u * (shape.height * 0.5));
    final pBase = pos - (u * (shape.height * 0.5));
    final radial = direction - (u * direction.dot(u));
    final radNorm = radial.length2 > 1e-12 ? radial.normalized() : Vector3.zero();
    final baseCandidate = pBase + (radNorm * shape.radius);
    out.setFrom((direction.dot(pApex) >= direction.dot(baseCandidate)) ? pApex : baseCandidate);
    return out;
  }

  if (shape is ConvexHullShape) {
    // argmax over the hull of (M·p)·d = p·(M₃ᵀ·d) + t·d: exact under
    // rotation and non-uniform scale.
    final m = transform.storage;
    final local = Vector3(
      m[0] * direction.x + m[1] * direction.y + m[2] * direction.z,
      m[4] * direction.x + m[5] * direction.y + m[6] * direction.z,
      m[8] * direction.x + m[9] * direction.y + m[10] * direction.z,
    );
    out.setFrom(transform.transform3(shape.localSupport(local).clone()));
    return out;
  }

  out.setFrom(pos);
  return out;
}

Vector3 _minkowskiSupport(
  CollisionShape shapeA,
  Matrix4 tA,
  CollisionShape shapeB,
  Matrix4 tB,
  Vector3 dir,
  Vector3 outA,
  Vector3 outB,
) {
  support(shapeA, tA, dir, outA);
  support(shapeB, tB, -dir, outB);
  return outA - outB;
}

/// Evaluates convex shape overlap using 3D Gilbert-Johnson-Keerthi (GJK).
bool gjkIntersect(
  CollisionShape shapeA,
  Matrix4 tA,
  CollisionShape shapeB,
  Matrix4 tB,
  GjkSimplex simplex,
) {
  simplex.reset();
  final outA = Vector3.zero();
  final outB = Vector3.zero();

  var dir = tB.getTranslation() - tA.getTranslation();
  if (dir.length2 < 1e-12) {
    dir = Vector3(1.0, 0.0, 0.0);
  }

  var p = _minkowskiSupport(shapeA, tA, shapeB, tB, dir, outA, outB);
  simplex.push(p, outA, outB);

  dir = -p;

  for (int iter = 0; iter < 32; iter++) {
    if (dir.length2 < 1e-12) {
      return true; // Origin reached
    }

    p = _minkowskiSupport(shapeA, tA, shapeB, tB, dir, outA, outB);
    if (p.dot(dir) < 0.0) {
      return false; // Separating plane found
    }

    simplex.push(p, outA, outB);

    if (_doSimplex(simplex, dir)) {
      return true;
    }
  }

  return false;
}

bool _doSimplex(GjkSimplex simplex, Vector3 dir) {
  switch (simplex.count) {
    case 2:
      return _simplexLine(simplex, dir);
    case 3:
      return _simplexTriangle(simplex, dir);
    case 4:
      return _simplexTetrahedron(simplex, dir);
    default:
      return false;
  }
}

bool _simplexLine(GjkSimplex simplex, Vector3 dir) {
  final a = simplex.vertices[1].point;
  final b = simplex.vertices[0].point;
  final ab = b - a;
  final ao = -a;

  if (ab.dot(ao) > 0.0) {
    var d = ab.cross(ao).cross(ab);
    if (d.length2 < 1e-12) {
      d = Vector3(-ab.y, ab.x, 0.0).length2 > 1e-12 ? Vector3(-ab.y, ab.x, 0.0) : Vector3(0.0, -ab.z, ab.y);
    }
    dir.setFrom(d);
  } else {
    simplex.vertices[0].set(simplex.vertices[1].point, simplex.vertices[1].pointA, simplex.vertices[1].pointB);
    simplex.count = 1;
    dir.setFrom(ao);
  }
  return false;
}

bool _simplexTriangle(GjkSimplex simplex, Vector3 dir) {
  final a = simplex.vertices[2].point;
  final b = simplex.vertices[1].point;
  final c = simplex.vertices[0].point;

  final ab = b - a;
  final ac = c - a;
  final abc = ab.cross(ac);
  final ao = -a;

  // Check edge AB
  final abPerp = ab.cross(abc);
  if (abPerp.dot(ao) > 0.0) {
    if (ab.dot(ao) > 0.0) {
      // Region AB: [B, A]
      simplex.vertices[0].set(simplex.vertices[1].point, simplex.vertices[1].pointA, simplex.vertices[1].pointB);
      simplex.vertices[1].set(simplex.vertices[2].point, simplex.vertices[2].pointA, simplex.vertices[2].pointB);
      simplex.count = 2;
      dir.setFrom(ab.cross(ao).cross(ab));
    } else {
      // Region A
      simplex.vertices[0].set(simplex.vertices[2].point, simplex.vertices[2].pointA, simplex.vertices[2].pointB);
      simplex.count = 1;
      dir.setFrom(ao);
    }
    return false;
  }

  // Check edge AC
  final acPerp = abc.cross(ac);
  if (acPerp.dot(ao) > 0.0) {
    if (ac.dot(ao) > 0.0) {
      // Region AC: [C, A]
      simplex.vertices[1].set(simplex.vertices[2].point, simplex.vertices[2].pointA, simplex.vertices[2].pointB);
      simplex.count = 2;
      dir.setFrom(ac.cross(ao).cross(ac));
    } else {
      // Region A
      simplex.vertices[0].set(simplex.vertices[2].point, simplex.vertices[2].pointA, simplex.vertices[2].pointB);
      simplex.count = 1;
      dir.setFrom(ao);
    }
    return false;
  }

  // Region ABC (triangle face)
  if (abc.dot(ao) > 0.0) {
    dir.setFrom(abc);
  } else {
    // Swap B and C for outward normal
    final tmpP = simplex.vertices[0].point.clone();
    final tmpA = simplex.vertices[0].pointA.clone();
    final tmpB = simplex.vertices[0].pointB.clone();

    simplex.vertices[0].set(simplex.vertices[1].point, simplex.vertices[1].pointA, simplex.vertices[1].pointB);
    simplex.vertices[1].set(tmpP, tmpA, tmpB);
    dir.setFrom(-abc);
  }
  return false;
}

bool _simplexTetrahedron(GjkSimplex simplex, Vector3 dir) {
  final a = simplex.vertices[3].point;
  final b = simplex.vertices[2].point;
  final c = simplex.vertices[1].point;
  final d = simplex.vertices[0].point;

  final ab = b - a;
  final ac = c - a;
  final ad = d - a;
  final ao = -a;

  var abc = ab.cross(ac);
  if (abc.dot(ad) > 0.0) abc = -abc;

  var acd = ac.cross(ad);
  if (acd.dot(ab) > 0.0) acd = -acd;

  var adb = ad.cross(ab);
  if (adb.dot(ac) > 0.0) adb = -adb;

  if (abc.dot(ao) > 0.0) {
    // Face ABC: [C, B, A]
    simplex.vertices[0].set(simplex.vertices[1].point, simplex.vertices[1].pointA, simplex.vertices[1].pointB);
    simplex.vertices[1].set(simplex.vertices[2].point, simplex.vertices[2].pointA, simplex.vertices[2].pointB);
    simplex.vertices[2].set(simplex.vertices[3].point, simplex.vertices[3].pointA, simplex.vertices[3].pointB);
    simplex.count = 3;
    dir.setFrom(abc);
    return false;
  }

  if (acd.dot(ao) > 0.0) {
    // Face ACD: [D, C, A]
    simplex.vertices[2].set(simplex.vertices[3].point, simplex.vertices[3].pointA, simplex.vertices[3].pointB);
    simplex.count = 3;
    dir.setFrom(acd);
    return false;
  }

  if (adb.dot(ao) > 0.0) {
    // Face ADB: [B, D, A]
    final bPoint = simplex.vertices[2].point.clone();
    final bA = simplex.vertices[2].pointA.clone();
    final bB = simplex.vertices[2].pointB.clone();

    final dPoint = simplex.vertices[0].point.clone();
    final dA = simplex.vertices[0].pointA.clone();
    final dB = simplex.vertices[0].pointB.clone();

    final aPoint = simplex.vertices[3].point.clone();
    final aA = simplex.vertices[3].pointA.clone();
    final aB = simplex.vertices[3].pointB.clone();

    simplex.vertices[0].set(bPoint, bA, bB);
    simplex.vertices[1].set(dPoint, dA, dB);
    simplex.vertices[2].set(aPoint, aA, aB);
    simplex.count = 3;
    dir.setFrom(adb);
    return false;
  }

  return true; // Enclosed origin!
}

class _EpaFace {
  final int a, b, c;
  final Vector3 normal;
  final double distance;

  _EpaFace(this.a, this.b, this.c, this.normal, this.distance);
}

/// Solves penetration depth and contact normal using Expanding Polytope Algorithm (EPA).
///
/// The polytope keeps one winding throughout: the initial
/// tetrahedron's faces are oriented away from its centroid and every new
/// face takes its horizon edge's winding, so a face normal is never flipped
/// and the horizon (edges seen once) is always a closed loop. A GJK simplex
/// with fewer than four points is completed by searching orthogonally to it.
bool epaPenetration(
  GjkSimplex seededSimplex,
  CollisionShape shapeA,
  Matrix4 tA,
  CollisionShape shapeB,
  Matrix4 tB,
  ContactResult out,
) {
  final outA = Vector3.zero();
  final outB = Vector3.zero();
  Vector3 supportOf(Vector3 dir) => _minkowskiSupport(shapeA, tA, shapeB, tB, dir, outA, outB);

  final polytope = <Vector3>[];
  for (int i = 0; i < seededSimplex.count; i++) {
    polytope.add(seededSimplex.vertices[i].point.clone());
  }
  var scale = 1e-9;
  for (final p in polytope) {
    scale = math.max(scale, p.length);
  }
  // A probe along each axis sizes the Minkowski difference for tolerances.
  for (final d in _axisDirections) {
    scale = math.max(scale, supportOf(d).length);
  }
  final eps = scale * 1e-9;

  if (!_completeTetrahedron(polytope, supportOf, eps)) {
    // The shapes only touch (the difference is flat at the origin).
    out.isColliding = true;
    out.penetrationDepth = 0.0;
    final n = tB.getTranslation() - tA.getTranslation();
    out.normal.setFrom(n.length2 > 1e-24 ? -n.normalized() : Vector3(0.0, 1.0, 0.0));
    return true;
  }

  final centroid = (polytope[0] + polytope[1] + polytope[2] + polytope[3])..scale(0.25);
  final faces = <_EpaFace>[];
  for (final (a, b, c) in const [(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)]) {
    final n = (polytope[b] - polytope[a]).cross(polytope[c] - polytope[a]);
    faces.add(n.dot(centroid - polytope[a]) > 0.0 ? _createFace(polytope, a, c, b) : _createFace(polytope, a, b, c));
  }

  final tolerance = math.max(scale * 1e-5, 1e-9);
  _EpaFace closestFace = faces.first;
  for (int iter = 0; iter < 64; iter++) {
    closestFace = faces.first;
    for (final f in faces) {
      if (f.distance < closestFace.distance) closestFace = f;
    }
    if (closestFace.distance == double.infinity) break;

    final p = supportOf(closestFace.normal).clone();
    if (p.dot(closestFace.normal) - closestFace.distance < tolerance) break;
    if (polytope.any((q) => q.distanceToSquared(p) <= eps * eps)) break;

    polytope.add(p);
    final pi = polytope.length - 1;

    // Faces the new point sees go; the edges they share cancel out, the
    // rest is the horizon (each edge once, in its face's winding).
    final horizon = <(int, int)>[];
    for (int i = faces.length - 1; i >= 0; i--) {
      final f = faces[i];
      if (f.normal.dot(p - polytope[f.a]) > eps) {
        _addEdge(horizon, f.a, f.b);
        _addEdge(horizon, f.b, f.c);
        _addEdge(horizon, f.c, f.a);
        faces.removeAt(i);
      }
    }
    if (horizon.isEmpty) break;
    for (final edge in horizon) {
      faces.add(_createFace(polytope, edge.$1, edge.$2, pi));
    }
  }

  out.isColliding = true;
  out.penetrationDepth = closestFace.distance.isFinite ? math.max(0.0, closestFace.distance) : 0.0;
  // Normal B -> A is opposite of outward normal of Minkowski difference A - B
  out.normal.setFrom(-closestFace.normal);
  return true;
}

final List<Vector3> _axisDirections = [
  Vector3(1.0, 0.0, 0.0),
  Vector3(-1.0, 0.0, 0.0),
  Vector3(0.0, 1.0, 0.0),
  Vector3(0.0, -1.0, 0.0),
  Vector3(0.0, 0.0, 1.0),
  Vector3(0.0, 0.0, -1.0),
];

/// Grows [poly] (a GJK simplex, possibly with fewer than four points) into a
/// tetrahedron with volume by searching orthogonally to what it has: off a
/// point along the axes, around a segment, off a triangle along its normal.
/// False when the difference has no volume there (touching shapes).
bool _completeTetrahedron(List<Vector3> poly, Vector3 Function(Vector3) supportOf, double eps) {
  // Drop duplicates a degenerate GJK exit can leave.
  for (int i = poly.length - 1; i > 0; i--) {
    for (int j = 0; j < i; j++) {
      if (poly[i].distanceToSquared(poly[j]) <= eps * eps) {
        poly.removeAt(i);
        break;
      }
    }
  }
  if (poly.length > 4) poly.removeRange(4, poly.length);
  if (poly.isEmpty) poly.add(supportOf(_axisDirections.first).clone());

  if (poly.length == 1) {
    for (final d in _axisDirections) {
      final p = supportOf(d);
      if (p.distanceTo(poly[0]) > eps) {
        poly.add(p.clone());
        break;
      }
    }
    if (poly.length == 1) return false;
  }

  if (poly.length == 2) {
    final axis = (poly[1] - poly[0])..normalize();
    final helper = axis.x.abs() < 0.57735 ? Vector3(1.0, 0.0, 0.0) : (axis.y.abs() < 0.57735 ? Vector3(0.0, 1.0, 0.0) : Vector3(0.0, 0.0, 1.0));
    final u = axis.cross(helper)..normalize();
    final v = axis.cross(u)..normalize();
    Vector3? best;
    var bestDistance = eps;
    for (int k = 0; k < 6; k++) {
      final angle = k * math.pi / 3.0;
      final d = (u * math.cos(angle)) + (v * math.sin(angle));
      final p = supportOf(d);
      final distance = axis.cross(p - poly[0]).length;
      if (distance > bestDistance) {
        bestDistance = distance;
        best = p.clone();
      }
    }
    if (best == null) return false;
    poly.add(best);
  }

  if (poly.length == 3) {
    final n = (poly[1] - poly[0]).cross(poly[2] - poly[0]);
    if (n.length2 <= eps * eps) return false;
    n.normalize();
    final up = supportOf(n).clone();
    final down = supportOf(-n).clone();
    final du = n.dot(up - poly[0]).abs();
    final dd = n.dot(down - poly[0]).abs();
    if (math.max(du, dd) <= eps) return false;
    poly.add(du >= dd ? up : down);
  }

  final volume = (poly[1] - poly[0]).dot((poly[2] - poly[0]).cross(poly[3] - poly[0])).abs();
  return volume > eps * eps * eps;
}

void _addEdge(List<(int, int)> edges, int a, int b) {
  final idx = edges.indexWhere((e) => e.$1 == b && e.$2 == a);
  if (idx != -1) {
    edges.removeAt(idx);
  } else {
    edges.add((a, b));
  }
}

/// A face wound `a → b → c`; its normal follows the winding (never flipped).
/// A face with no area is never the closest one.
_EpaFace _createFace(List<Vector3> poly, int a, int b, int c) {
  final normal = (poly[b] - poly[a]).cross(poly[c] - poly[a]);
  final len = normal.length;
  if (len <= 1e-12) {
    return _EpaFace(a, b, c, Vector3(0.0, 1.0, 0.0), double.infinity);
  }
  normal.scale(1.0 / len);
  return _EpaFace(a, b, c, normal, normal.dot(poly[a]));
}

/// Unified pair collision testing dispatcher routing to analytic or GJK/EPA algorithms.
bool testPair(
  CollisionShape shapeA,
  Matrix4 tA,
  CollisionShape shapeB,
  Matrix4 tB,
  ContactResult out,
) {
  out.reset();

  // 1. Analytic sphere pairs
  if (shapeA is SphereShape && shapeB is SphereShape) {
    return sphereVsSphere(shapeA, tA, shapeB, tB, out);
  }
  if (shapeA is SphereShape && shapeB is CapsuleShape) {
    return sphereVsCapsule(shapeA, tA, shapeB, tB, out);
  }
  if (shapeA is CapsuleShape && shapeB is SphereShape) {
    final hit = sphereVsCapsule(shapeB, tB, shapeA, tA, out);
    if (hit) out.normal.negate();
    return hit;
  }
  if (shapeA is CapsuleShape && shapeB is CapsuleShape) {
    return capsuleVsCapsule(shapeA, tA, shapeB, tB, out);
  }
  if (shapeA is SphereShape && shapeB is BoxShape) {
    return sphereVsBox(shapeA, tA, shapeB, tB, out);
  }
  if (shapeA is BoxShape && shapeB is SphereShape) {
    final hit = sphereVsBox(shapeB, tB, shapeA, tA, out);
    if (hit) out.normal.negate();
    return hit;
  }
  if (shapeA is SphereShape && shapeB is ConeShape) {
    return sphereVsCone(shapeA, tA, shapeB, tB, out);
  }
  if (shapeA is ConeShape && shapeB is SphereShape) {
    final hit = sphereVsCone(shapeB, tB, shapeA, tA, out);
    if (hit) out.normal.negate();
    return hit;
  }

  // 1b. Heightfields: spheres and capsules only; anything else
  //     reports no contact rather than feeding GJK a non-convex shape.
  if (shapeB is HeightfieldShape) {
    if (shapeA is CapsuleShape) return capsuleVsHeightfield(shapeA, tA, shapeB, tB, out);
    if (shapeA is SphereShape) return sphereVsHeightfield(shapeA, tA, shapeB, tB, out);
    return false;
  }
  if (shapeA is HeightfieldShape) {
    final bool hit;
    if (shapeB is CapsuleShape) {
      hit = capsuleVsHeightfield(shapeB, tB, shapeA, tA, out);
    } else if (shapeB is SphereShape) {
      hit = sphereVsHeightfield(shapeB, tB, shapeA, tA, out);
    } else {
      return false;
    }
    if (hit) out.normal.negate();
    return hit;
  }

  // 2. General GJK + EPA for all remaining convex pairs
  final simplex = GjkSimplex();
  if (gjkIntersect(shapeA, tA, shapeB, tB, simplex)) {
    return epaPenetration(simplex, shapeA, tA, shapeB, tB, out);
  }

  out.isColliding = false;
  return false;
}
