import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../../data/models/landscape_data.dart';
import 'narrow_phase.dart';
import 'shapes.dart';

/// A landscape's heightmap as a collision shape: the walkable,
/// sweep-able heightfield collider.
///
/// The shape is in the **component's local frame**: runtime Y-up, terrain
/// metres × [unitsPerMetre] (centimetres in a game world), the exact
/// vertices `LandscapeMeshBuilder` draws — so a capsule stands on the
/// triangles it sees. The component's world transform (the placed Landscape
/// actor's location, rotation and scale) is applied by the queries. The shape
/// reads [data] live: a sculpt that edits the heightmap edits the collider.
///
/// Only spheres, capsules and rays test against it (a character's capsule,
/// the floor probe, line traces). Box and convex shapes report no contact.
class HeightfieldShape extends CollisionShape {
  final LandscapeData data;

  /// Local units per terrain metre.
  final double unitsPerMetre;

  const HeightfieldShape(this.data, {this.unitsPerMetre = 1.0});

  /// Surface height (local units) under a local XZ position.
  double heightAt(double localX, double localZ) =>
      data.sampleHeight(localX / unitsPerMetre, localZ / unitsPerMetre) * unitsPerMetre;

  /// Unit surface normal under a local XZ position (local frame).
  Vector3 normalAt(double localX, double localZ) => data.sampleNormal(localX / unitsPerMetre, localZ / unitsPerMetre);

  /// True when a local XZ position is inside the terrain's footprint.
  bool contains(double localX, double localZ) => data.contains(localX / unitsPerMetre, localZ / unitsPerMetre);

  /// The box the terrain can occupy, local units: its footprint × the
  /// payload's whole `0..maxHeight` range (a sculpt cannot leave it).
  Aabb3 get localBounds {
    final half = data.worldSize / 2 * unitsPerMetre;
    return Aabb3.minMax(Vector3(-half, 0.0, -half), Vector3(half, data.maxHeight * unitsPerMetre, half));
  }

  /// One cell's side, local units.
  double get cellSize => data.cellSize * unitsPerMetre;

  /// Local position of grid sample ([col], [row]) on the surface.
  Vector3 vertexAt(int col, int row) => Vector3(
        data.worldXOf(col) * unitsPerMetre,
        data.heightAt(col, row) * unitsPerMetre,
        data.worldZOf(row) * unitsPerMetre,
      );
}

/// Closest point on triangle (a, b, c) to [p] (Ericson, Real-Time Collision
/// Detection 5.1.5).
Vector3 closestPointOnTriangle(Vector3 p, Vector3 a, Vector3 b, Vector3 c) {
  final ab = b - a;
  final ac = c - a;
  final ap = p - a;
  final d1 = ab.dot(ap);
  final d2 = ac.dot(ap);
  if (d1 <= 0 && d2 <= 0) return a.clone();
  final bp = p - b;
  final d3 = ab.dot(bp);
  final d4 = ac.dot(bp);
  if (d3 >= 0 && d4 <= d3) return b.clone();
  final vc = d1 * d4 - d3 * d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0) {
    final v = d1 / (d1 - d3);
    return a + ab * v;
  }
  final cp = p - c;
  final d5 = ab.dot(cp);
  final d6 = ac.dot(cp);
  if (d6 >= 0 && d5 <= d6) return c.clone();
  final vb = d5 * d2 - d1 * d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0) {
    final w = d2 / (d2 - d6);
    return a + ac * w;
  }
  final va = d3 * d6 - d5 * d4;
  if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
    final w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
    return b + (c - b) * w;
  }
  final denom = 1.0 / (va + vb + vc);
  final v = vb * denom;
  final w = vc * denom;
  return a + ab * v + ac * w;
}

/// Closest points between segment [p, q] and triangle (a, b, c): the closest
/// pair is at a segment endpoint, between the segment and a triangle edge, or
/// (when the segment pierces the triangle) on the triangle itself.
/// Writes them to [outSeg] / [outTri] and returns their distance.
double closestPointsSegmentTriangle(
  Vector3 p,
  Vector3 q,
  Vector3 a,
  Vector3 b,
  Vector3 c,
  Vector3 outSeg,
  Vector3 outTri,
) {
  var best = double.infinity;
  void consider(Vector3 s, Vector3 t) {
    final d = (s - t).length;
    if (d < best) {
      best = d;
      outSeg.setFrom(s);
      outTri.setFrom(t);
    }
  }

  consider(p, closestPointOnTriangle(p, a, b, c));
  consider(q, closestPointOnTriangle(q, a, b, c));
  final s1 = Vector3.zero(), s2 = Vector3.zero();
  for (final (e0, e1) in [(a, b), (b, c), (c, a)]) {
    closestPointsBetweenSegments(p, q, e0, e1, s1, s2);
    consider(s1, s2);
  }
  // Piercing: the segment crosses the triangle's plane inside the triangle.
  final n = (b - a).cross(c - a);
  if (n.length2 > 1e-18) {
    final dp = (p - a).dot(n);
    final dq = (q - a).dot(n);
    if ((dp <= 0 && dq >= 0) || (dp >= 0 && dq <= 0)) {
      final denom = dp - dq;
      if (denom.abs() > 1e-18) {
        final x = p + (q - p) * (dp / denom);
        final onTri = closestPointOnTriangle(x, a, b, c);
        if ((onTri - x).length2 < 1e-10) {
          best = 0.0;
          outSeg.setFrom(x);
          outTri.setFrom(x);
        }
      }
    }
  }
  return best;
}

/// The rotation part of [m] as a normalised 3×3 (scale removed), for normals.
Matrix3 _rotationOf(Matrix4 m) {
  final r = m.getRotation();
  for (var c = 0; c < 3; c++) {
    final col = r.getColumn(c);
    if (col.length2 > 1e-18) r.setColumn(c, col.normalized());
  }
  return r;
}

/// Scale of [m] along its X axis: the factor a local length is multiplied by
/// (the heightfield is expected to be scaled uniformly).
double _scaleOf(Matrix4 m) => Vector3(m.entry(0, 0), m.entry(1, 0), m.entry(2, 0)).length;

/// Capsule ([sA] at [tA]) against heightfield ([sB] at [tB]).
///
/// Works in the heightfield's local frame: the capsule's core segment is
/// brought into it, the cells under the segment's footprint (grown by the
/// radius) are visited, and the closest segment–triangle pair decides the
/// contact. A segment end below the surface is a deep penetration and pushes
/// out along the surface normal, so a capsule never falls through.
/// [out.normal] points from the terrain towards the capsule.
bool capsuleVsHeightfield(CapsuleShape sA, Matrix4 tA, HeightfieldShape sB, Matrix4 tB, ContactResult out) {
  final u = Vector3(tA.entry(0, 1), tA.entry(1, 1), tA.entry(2, 1)).normalized();
  final segHalf = math.max(0.0, sA.halfHeight - sA.radius);
  final pos = tA.getTranslation();
  return _segmentVsHeightfield(pos - u * segHalf, pos + u * segHalf, sA.radius, sB, tB, out);
}

/// Sphere ([sA] at [tA]) against heightfield ([sB] at [tB]).
bool sphereVsHeightfield(SphereShape sA, Matrix4 tA, HeightfieldShape sB, Matrix4 tB, ContactResult out) {
  final pos = tA.getTranslation();
  return _segmentVsHeightfield(pos, pos, sA.radius, sB, tB, out);
}

bool _segmentVsHeightfield(Vector3 pW, Vector3 qW, double radiusW, HeightfieldShape hf, Matrix4 tB, ContactResult out) {
  out.reset();
  final inv = Matrix4.copy(tB)..invert();
  final scale = _scaleOf(tB);
  if (scale < 1e-12) return false;
  final radius = radiusW / scale;
  final p = inv.transform3(pW.clone());
  final q = inv.transform3(qW.clone());
  final rot = _rotationOf(tB);

  bool finish(Vector3 normalLocal, Vector3 contactLocal, double depthLocal) {
    out.isColliding = true;
    out.penetrationDepth = depthLocal * scale;
    out.normal.setFrom((rot * normalLocal).normalized());
    out.contactPoint.setFrom(tB.transform3(contactLocal.clone()));
    return true;
  }

  // Deep penetration: a segment end under the surface. Push out along the
  // surface normal from the lowest end.
  final low = p.y <= q.y ? p : q;
  if (hf.contains(low.x, low.z)) {
    final h = hf.heightAt(low.x, low.z);
    if (low.y < h) {
      final n = hf.normalAt(low.x, low.z);
      return finish(n, Vector3(low.x, h, low.z), (h - low.y) + radius);
    }
  }

  // The cells the capsule can touch.
  final res = hf.data.gridResolution;
  final minX = math.min(p.x, q.x) - radius, maxX = math.max(p.x, q.x) + radius;
  final minZ = math.min(p.z, q.z) - radius, maxZ = math.max(p.z, q.z) + radius;
  final u = hf.unitsPerMetre;
  var c0 = (hf.data.columnOf(minX / u)).floor();
  var c1 = (hf.data.columnOf(maxX / u)).ceil();
  var r0 = (hf.data.rowOf(minZ / u)).floor();
  var r1 = (hf.data.rowOf(maxZ / u)).ceil();
  if (c1 < 0 || r1 < 0 || c0 > res - 2 || r0 > res - 2) return false;
  c0 = c0.clamp(0, res - 2);
  c1 = c1.clamp(0, res - 2);
  r0 = r0.clamp(0, res - 2);
  r1 = r1.clamp(0, res - 2);
  // A shape wider than 128 cells is not a character; keep the cost bounded
  // around its centre.
  const maxSpan = 128;
  if (c1 - c0 > maxSpan) {
    final mid = ((c0 + c1) ~/ 2);
    c0 = math.max(0, mid - maxSpan ~/ 2);
    c1 = math.min(res - 2, mid + maxSpan ~/ 2);
  }
  if (r1 - r0 > maxSpan) {
    final mid = ((r0 + r1) ~/ 2);
    r0 = math.max(0, mid - maxSpan ~/ 2);
    r1 = math.min(res - 2, mid + maxSpan ~/ 2);
  }
  // Quick reject: the segment is above every sample it could reach.
  final segMinY = math.min(p.y, q.y) - radius;
  var top = -double.infinity;
  for (var r = r0; r <= r1 + 1; r++) {
    for (var c = c0; c <= c1 + 1; c++) {
      final h = hf.data.heightAt(c, r) * u;
      if (h > top) top = h;
    }
  }
  if (segMinY > top) return false;

  var best = double.infinity;
  final bestSeg = Vector3.zero(), bestTri = Vector3.zero(), bestNormal = Vector3(0, 1, 0);
  final s = Vector3.zero(), t = Vector3.zero();
  for (var r = r0; r <= r1; r++) {
    for (var c = c0; c <= c1; c++) {
      // The two triangles LandscapeMeshBuilder draws for this quad.
      final a = hf.vertexAt(c, r);
      final b = hf.vertexAt(c + 1, r);
      final d = hf.vertexAt(c, r + 1);
      final e = hf.vertexAt(c + 1, r + 1);
      for (final (t0, t1, t2) in [(a, d, b), (b, d, e)]) {
        final dist = closestPointsSegmentTriangle(p, q, t0, t1, t2, s, t);
        if (dist < best) {
          best = dist;
          bestSeg.setFrom(s);
          bestTri.setFrom(t);
          final n = (t1 - t0).cross(t2 - t0);
          bestNormal.setFrom(n.length2 > 1e-18 ? n.normalized() : Vector3(0, 1, 0));
          if (bestNormal.y < 0) bestNormal.negate();
        }
      }
    }
  }
  if (best >= radius - 1e-9) return false;

  final dir = bestSeg - bestTri;
  final normal = dir.length2 > 1e-10 ? dir.normalized() : bestNormal.clone();
  // Never report a normal pointing into the ground.
  if (normal.dot(bestNormal) < 0) normal.negate();
  return finish(normal, bestTri, radius - best);
}

/// Ray ([origin], unit [dir], world) against a heightfield at [transform].
///
/// Marches the ray over the terrain box in half-cell steps and bisects the
/// first crossing of the surface. Returns the world distance to the hit, or
/// null; [normalOut] receives the world surface normal.
double? rayVsHeightfield(Vector3 origin, Vector3 dir, HeightfieldShape hf, Matrix4 transform, Vector3 normalOut) {
  final inv = Matrix4.copy(transform)..invert();
  final o = inv.transform3(origin.clone());
  final d = (inv.getRotation() * dir);
  if (d.length2 < 1e-18) return null;
  d.normalize();
  final bounds = hf.localBounds;
  // Slab clip.
  var tEnter = 0.0, tExit = double.infinity;
  for (var axis = 0; axis < 3; axis++) {
    final oa = o[axis], da = d[axis];
    final lo = bounds.min[axis] - 1e-6, hi = bounds.max[axis] + 1e-6;
    if (da.abs() < 1e-12) {
      if (oa < lo || oa > hi) return null;
      continue;
    }
    var t0 = (lo - oa) / da, t1 = (hi - oa) / da;
    if (t0 > t1) {
      final tmp = t0;
      t0 = t1;
      t1 = tmp;
    }
    if (t0 > tEnter) tEnter = t0;
    if (t1 < tExit) tExit = t1;
    if (tEnter > tExit) return null;
  }
  if (!tExit.isFinite) return null;
  double delta(double t) {
    final x = o.x + d.x * t, z = o.z + d.z * t;
    return (o.y + d.y * t) - hf.heightAt(x, z);
  }

  final step = math.max(hf.cellSize * 0.5, 1e-3);
  var prevT = tEnter;
  var prev = delta(tEnter);
  double? hitT;
  if (prev <= 0) {
    hitT = tEnter;
  } else {
    for (var t = tEnter + step; t <= tExit + step; t += step) {
      final tc = math.min(t, tExit);
      final cur = delta(tc);
      if (cur <= 0) {
        var lo = prevT, hi = tc;
        for (var i = 0; i < 24; i++) {
          final mid = (lo + hi) / 2;
          if (delta(mid) > 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        hitT = (lo + hi) / 2;
        break;
      }
      prevT = tc;
      prev = cur;
      if (tc >= tExit) break;
    }
  }
  if (hitT == null) return null;
  final hx = o.x + d.x * hitT, hz = o.z + d.z * hitT;
  if (!hf.contains(hx, hz)) return null;
  final hitLocal = Vector3(hx, hf.heightAt(hx, hz), hz);
  final hitWorld = transform.transform3(hitLocal);
  normalOut.setFrom((_rotationOf(transform) * hf.normalAt(hx, hz)).normalized());
  return (hitWorld - origin).dot(dir);
}
