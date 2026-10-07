import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/gjk_epa.dart';
import 'package:lumina/src/collision/narrow_phase.dart';
import 'package:lumina/src/collision/shapes.dart';

/// One side of a contact test: a convex [shape] at world [transform] (with
/// scale, which a box and a convex hull honour, as in the collision queries).
class LuminaCollider {
  CollisionShape shape;
  Matrix4 transform;
  LuminaCollider(this.shape, this.transform);
}

/// The contact of two colliders: one [normal] pointing from A to B and up to
/// four [points] (world, midway between the surfaces) with their
/// penetration [depths] (negative: a gap inside the contact margin).
class LuminaContactSet {
  final Vector3 normal = Vector3.zero();
  final List<Vector3> points = [];
  final List<double> depths = [];

  bool get isEmpty => points.isEmpty;

  void clear() {
    normal.setZero();
    points.clear();
    depths.clear();
  }

  void add(Vector3 point, double depth) {
    points.add(point);
    depths.add(depth);
  }
}

/// Contact manifolds for the rigid-body solver: the
/// existing narrow phase (analytic pairs, GJK/EPA) finds the normal and
/// depth, and the touching features of the two shapes are clipped against
/// each other for up to four points, so boxes rest on faces, capsules and
/// cylinders on their sides, and tipping bodies on edges. Box pairs use the
/// separating-axis test directly (faster and exact for the common case).
abstract final class LuminaContactGenerator {
  /// Points closer than this (cm) to touching still make a contact.
  static const double defaultMargin = 0.2;

  /// Fills [out] with the contact of [a] and [b]; false when they do not
  /// touch. [b] may be a heightfield (the landscape); [a] never is.
  static bool collide(LuminaCollider a, LuminaCollider b, LuminaContactSet out, {double margin = defaultMargin}) {
    out.clear();
    final sa = a.shape, sb = b.shape;
    if (sb is HeightfieldShape) return _heightfield(a, b, sb, out, margin);
    if (sa is BoxShape && sb is BoxShape) return _boxBox(_Box.of(sa, a.transform), _Box.of(sb, b.transform), out, margin);
    if (sa is SphereShape || sb is SphereShape) return _withSphere(a, b, out);
    final contact = ContactResult();
    if (!testPair(sa, a.transform, sb, b.transform, contact) || !contact.isColliding) return false;
    final nAB = -contact.normal;
    if (nAB.length2 < 1e-12) return false;
    nAB.normalize();
    out.normal.setFrom(nAB);
    final fa = feature(sa, a.transform, nAB);
    final fb = feature(sb, b.transform, -nAB);
    _clip(fa, fb, nAB, contact.penetrationDepth, out, margin);
    if (out.isEmpty) {
      // No overlap of the features (edge on edge): the midpoint of the two
      // deepest points.
      final pa = support(sa, a.transform, nAB, Vector3.zero());
      final pb = support(sb, b.transform, -nAB, Vector3.zero());
      out.add((pa + pb)..scale(0.5), contact.penetrationDepth);
    }
    return true;
  }

  /// Where [a] and [b] touch along [nAB] (from A to B) when they are within
  /// [margin] of each other: the clipped touching features' points (the
  /// midpoint of the two nearest points when the features do not overlap).
  /// For a pusher and what it pushes (a character's capsule and a body).
  static List<Vector3> touchPoints(CollisionShape a, Matrix4 ta, CollisionShape b, Matrix4 tb, Vector3 nAB,
      {double margin = 2.0}) {
    final n = nAB.normalized();
    final set = LuminaContactSet();
    _clip(feature(a, ta, n), feature(b, tb, -n), n, 0.0, set, margin);
    if (set.isEmpty) {
      final pa = support(a, ta, n, Vector3.zero());
      final pb = support(b, tb, -n, Vector3.zero());
      return [(pa + pb)..scale(0.5)];
    }
    return set.points;
  }

  // --- Spheres ----------------------------------------------------------------

  static bool _withSphere(LuminaCollider a, LuminaCollider b, LuminaContactSet out) {
    final contact = ContactResult();
    if (!testPair(a.shape, a.transform, b.shape, b.transform, contact) || !contact.isColliding) return false;
    final nAB = -contact.normal;
    if (nAB.length2 < 1e-12) nAB.setValues(0, -1, 0);
    nAB.normalize();
    out.normal.setFrom(nAB);
    final depth = contact.penetrationDepth;
    // The sphere's deepest point, moved half the depth back to the midway surface.
    final Vector3 point;
    if (a.shape is SphereShape) {
      point = a.transform.getTranslation() + nAB * ((a.shape as SphereShape).radius - depth * 0.5);
    } else {
      point = b.transform.getTranslation() - nAB * ((b.shape as SphereShape).radius - depth * 0.5);
    }
    out.add(point, depth);
    return true;
  }

  // --- Box / box (SAT) --------------------------------------------------------

  static bool _boxBox(_Box a, _Box b, LuminaContactSet out, double margin) {
    final t = b.c - a.c;
    final r = List<double>.filled(9, 0), ar = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final v = a.u[i].dot(b.u[j]);
        r[i * 3 + j] = v;
        ar[i * 3 + j] = v.abs() + 1e-9;
      }
    }
    var faceA = -double.infinity, faceB = -double.infinity, edge = -double.infinity;
    var faceAIndex = 0, faceBIndex = 0;
    Vector3? edgeAxis;
    var edgeI = 0, edgeJ = 0;
    for (var i = 0; i < 3; i++) {
      final rb = b.e[0] * ar[i * 3] + b.e[1] * ar[i * 3 + 1] + b.e[2] * ar[i * 3 + 2];
      final sep = t.dot(a.u[i]).abs() - (a.e[i] + rb);
      if (sep > margin) return false;
      if (sep > faceA) {
        faceA = sep;
        faceAIndex = i;
      }
    }
    for (var j = 0; j < 3; j++) {
      final ra = a.e[0] * ar[j] + a.e[1] * ar[3 + j] + a.e[2] * ar[6 + j];
      final sep = t.dot(b.u[j]).abs() - (ra + b.e[j]);
      if (sep > margin) return false;
      if (sep > faceB) {
        faceB = sep;
        faceBIndex = j;
      }
    }
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final l = a.u[i].cross(b.u[j]);
        final len = l.length;
        if (len < 1e-5) continue;
        l.scale(1 / len);
        final ra = a.e[0] * a.u[0].dot(l).abs() + a.e[1] * a.u[1].dot(l).abs() + a.e[2] * a.u[2].dot(l).abs();
        final rb = b.e[0] * b.u[0].dot(l).abs() + b.e[1] * b.u[1].dot(l).abs() + b.e[2] * b.u[2].dot(l).abs();
        final sep = t.dot(l).abs() - (ra + rb);
        if (sep > margin) return false;
        if (sep > edge) {
          edge = sep;
          edgeAxis = l;
          edgeI = i;
          edgeJ = j;
        }
      }
    }
    // Prefer faces: stable manifolds for resting and stacked boxes.
    const relTol = 0.95, absTol = 0.05;
    final bestFace = math.max(faceA, faceB);
    if (edgeAxis != null && edge > relTol * bestFace + absTol) {
      final l = edgeAxis;
      if (t.dot(l) < 0) l.negate();
      // A's edge farthest along +l, B's farthest along −l.
      final pa = a.c.clone();
      for (var k = 0; k < 3; k++) {
        if (k == edgeI) continue;
        pa.add(a.u[k] * (a.e[k] * (a.u[k].dot(l) >= 0 ? 1.0 : -1.0)));
      }
      final pb = b.c.clone();
      for (var k = 0; k < 3; k++) {
        if (k == edgeJ) continue;
        pb.add(b.u[k] * (b.e[k] * (b.u[k].dot(l) >= 0 ? -1.0 : 1.0)));
      }
      final ca = Vector3.zero(), cb = Vector3.zero();
      closestPointsBetweenSegments(pa - a.u[edgeI] * a.e[edgeI], pa + a.u[edgeI] * a.e[edgeI], pb - b.u[edgeJ] * b.e[edgeJ],
          pb + b.u[edgeJ] * b.e[edgeJ], ca, cb);
      out.normal.setFrom(l);
      out.add((ca + cb)..scale(0.5), -edge);
      return true;
    }
    final useB = faceB > relTol * faceA + absTol;
    final ref = useB ? b : a;
    final inc = useB ? a : b;
    final refIndex = useB ? faceBIndex : faceAIndex;
    final toInc = inc.c - ref.c;
    final refN = ref.u[refIndex] * (toInc.dot(ref.u[refIndex]) >= 0 ? 1.0 : -1.0);
    // The incident face: the one most anti-parallel to the reference normal.
    var k = 0;
    var best = -1.0;
    for (var i = 0; i < 3; i++) {
      final d = inc.u[i].dot(refN).abs();
      if (d > best) {
        best = d;
        k = i;
      }
    }
    final incN = inc.u[k] * (inc.u[k].dot(refN) > 0 ? -1.0 : 1.0);
    final k1 = (k + 1) % 3, k2 = (k + 2) % 3;
    final fc = inc.c + incN * inc.e[k];
    final a1 = inc.u[k1] * inc.e[k1], a2 = inc.u[k2] * inc.e[k2];
    var poly = <Vector3>[fc + a1 + a2, fc - a1 + a2, fc - a1 - a2, fc + a1 - a2];
    final i1 = (refIndex + 1) % 3, i2 = (refIndex + 2) % 3;
    for (final (axis, extent) in [(ref.u[i1], ref.e[i1]), (ref.u[i2], ref.e[i2])]) {
      poly = _clipPlane(poly, axis, axis.dot(ref.c) + extent);
      poly = _clipPlane(poly, -axis, -axis.dot(ref.c) + extent);
      if (poly.isEmpty) break;
    }
    final faceCenter = ref.c + refN * ref.e[refIndex];
    final pts = <Vector3>[];
    final depths = <double>[];
    for (final p in poly) {
      final s = (p - faceCenter).dot(refN);
      if (s <= margin) {
        pts.add(p - refN * (s * 0.5));
        depths.add(-s);
      }
    }
    if (pts.isEmpty) return false;
    out.normal.setFrom(useB ? -refN : refN);
    _reduce(pts, depths, out);
    return true;
  }

  /// Keeps the part of [poly] with `n · p <= d` (Sutherland–Hodgman).
  static List<Vector3> _clipPlane(List<Vector3> poly, Vector3 n, double d) {
    if (poly.isEmpty) return poly;
    final out = <Vector3>[];
    if (poly.length == 1) {
      if (n.dot(poly[0]) <= d) out.add(poly[0]);
      return out;
    }
    final count = poly.length == 2 ? 1 : poly.length;
    for (var i = 0; i < count; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final dp = n.dot(p) - d, dq = n.dot(q) - d;
      if (dp <= 0) out.add(p);
      if ((dp < 0 && dq > 0) || (dp > 0 && dq < 0)) {
        out.add(p + (q - p) * (dp / (dp - dq)));
      }
      if (poly.length == 2 && dq <= 0) out.add(q);
    }
    return out;
  }

  /// Up to four of [pts]: the deepest, the farthest from it, then the two
  /// spanning the largest area.
  static void _reduce(List<Vector3> pts, List<double> depths, LuminaContactSet out) {
    if (pts.length <= 4) {
      for (var i = 0; i < pts.length; i++) {
        out.add(pts[i], depths[i]);
      }
      return;
    }
    var i0 = 0;
    for (var i = 1; i < pts.length; i++) {
      if (depths[i] > depths[i0] + 1e-6) i0 = i;
    }
    var i1 = -1;
    var best = -1.0;
    for (var i = 0; i < pts.length; i++) {
      final d = pts[i].distanceToSquared(pts[i0]);
      if (d > best) {
        best = d;
        i1 = i;
      }
    }
    var i2 = -1;
    best = -1.0;
    for (var i = 0; i < pts.length; i++) {
      if (i == i0 || i == i1) continue;
      final area = (pts[i1] - pts[i0]).cross(pts[i] - pts[i0]).length2;
      if (area > best) {
        best = area;
        i2 = i;
      }
    }
    var i3 = -1;
    best = -1.0;
    for (var i = 0; i < pts.length; i++) {
      if (i == i0 || i == i1 || i == i2) continue;
      final d = pts[i].distanceToSquared(pts[i0]) + pts[i].distanceToSquared(pts[i1]) + pts[i].distanceToSquared(pts[i2]);
      if (d > best) {
        best = d;
        i3 = i;
      }
    }
    for (final i in [i0, i1, i2, i3]) {
      if (i >= 0) out.add(pts[i], depths[i]);
    }
  }

  // --- Features and clipping ----------------------------------------------------

  static const int _discSegments = 8;
  static final Expando<List<List<int>>> _hullFaces = Expando('luminaHullFaces');

  /// The feature of [shape] (at [t]) that is farthest along [dir]: a face
  /// (ordered polygon), an edge (two points) or a vertex, world space.
  static List<Vector3> feature(CollisionShape shape, Matrix4 t, Vector3 dir) {
    final d = dir.normalized();
    final pos = t.getTranslation();
    if (shape is SphereShape) return [pos + d * shape.radius];
    if (shape is BoxShape) {
      final box = _Box.of(shape, t);
      var k = 0;
      var best = -1.0;
      for (var i = 0; i < 3; i++) {
        final v = box.u[i].dot(d).abs();
        if (v > best) {
          best = v;
          k = i;
        }
      }
      final n = box.u[k] * (box.u[k].dot(d) >= 0 ? 1.0 : -1.0);
      final k1 = (k + 1) % 3, k2 = (k + 2) % 3;
      final fc = box.c + n * box.e[k];
      final a1 = box.u[k1] * box.e[k1], a2 = box.u[k2] * box.e[k2];
      return [fc + a1 + a2, fc - a1 + a2, fc - a1 - a2, fc + a1 - a2];
    }
    final u = Vector3(t.entry(0, 1), t.entry(1, 1), t.entry(2, 1))..normalize();
    final a = u.dot(d);
    final radial = d - u * a;
    final hasRadial = radial.length2 > 1e-10;
    if (hasRadial) radial.normalize();
    if (shape is CapsuleShape) {
      final seg = math.max(0.0, shape.halfHeight - shape.radius);
      if (a.abs() < 0.35 && seg > 0) {
        return [pos - u * seg + d * shape.radius, pos + u * seg + d * shape.radius];
      }
      return [pos + u * (a >= 0 ? seg : -seg) + d * shape.radius];
    }
    if (shape is CylinderShape) {
      final hh = shape.height * 0.5;
      if (a.abs() > 0.7 || !hasRadial) return _disc(pos + u * (a >= 0 ? hh : -hh), u, shape.radius, a >= 0);
      return [pos - u * hh + radial * shape.radius, pos + u * hh + radial * shape.radius];
    }
    if (shape is ConeShape) {
      final hh = shape.height * 0.5;
      final apex = pos + u * hh;
      if (a < -0.7 || !hasRadial) {
        if (!hasRadial && a > 0) return [apex];
        return _disc(pos - u * hh, u, shape.radius, false);
      }
      final rim = pos - u * hh + radial * shape.radius;
      // The side's outward normal along this generatrix.
      final side = (radial * shape.height + u * shape.radius)..normalize();
      if (side.dot(d) > 0.95) return [rim, apex];
      return [apex.dot(d) >= rim.dot(d) ? apex : rim];
    }
    if (shape is ConvexHullShape) return _hullFeature(shape, t, d);
    return [support(shape, t, d, Vector3.zero())];
  }

  static List<Vector3> _disc(Vector3 center, Vector3 axis, double radius, bool facingAxis) {
    final helper = axis.x.abs() < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 0, 1);
    final e1 = axis.cross(helper)..normalize();
    final e2 = axis.cross(e1)..normalize();
    final pts = <Vector3>[];
    for (var i = 0; i < _discSegments; i++) {
      final ang = (facingAxis ? 1 : -1) * i * 2 * math.pi / _discSegments;
      pts.add(center + e1 * (math.cos(ang) * radius) + e2 * (math.sin(ang) * radius));
    }
    return pts;
  }

  static List<List<int>> _facesOf(ConvexHullShape hull) {
    final cached = _hullFaces[hull];
    if (cached != null) return cached;
    final size = (hull.localMax - hull.localMin).length;
    final tol = math.max(size, 1.0) * 1e-4;
    final faces = <List<int>>[];
    for (final plane in hull.planes) {
      final idx = <int>[];
      for (var i = 0; i < hull.vertices.length; i++) {
        if ((plane.normal.dot(hull.vertices[i]) - plane.offset).abs() <= tol) idx.add(i);
      }
      if (idx.length >= 3) {
        final c = Vector3.zero();
        for (final i in idx) {
          c.add(hull.vertices[i]);
        }
        c.scale(1 / idx.length);
        final n = plane.normal;
        final e1 = (hull.vertices[idx[0]] - c)..normalize();
        final e2 = n.cross(e1);
        double angle(int i) {
          final v = hull.vertices[i] - c;
          return math.atan2(v.dot(e2), v.dot(e1));
        }

        idx.sort((x, y) => angle(x).compareTo(angle(y)));
      }
      faces.add(idx);
    }
    return _hullFaces[hull] = faces;
  }

  static List<Vector3> _hullFeature(ConvexHullShape hull, Matrix4 t, Vector3 d) {
    if (hull.isDegenerate || hull.planes.isEmpty) return [support(hull, t, d, Vector3.zero())];
    final faces = _facesOf(hull);
    // Normals go through the inverse transpose (non-uniform scale).
    final m = t.storage;
    final inv3 = Matrix3(m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10]);
    if (inv3.invert() == 0.0) return [support(hull, t, d, Vector3.zero())];
    final normalMatrix = inv3.transposed();
    var bestFace = -1;
    var bestDot = -double.infinity;
    for (var i = 0; i < hull.planes.length; i++) {
      if (faces[i].length < 3) continue;
      final n = normalMatrix.transformed(hull.planes[i].normal)..normalize();
      final v = n.dot(d);
      if (v > bestDot) {
        bestDot = v;
        bestFace = i;
      }
    }
    final sup = support(hull, t, d, Vector3.zero());
    if (bestFace < 0 || bestDot < 0.7) return [sup];
    return [for (final i in faces[bestFace]) t.transform3(hull.vertices[i].clone())];
  }

  /// Clips A's feature [fa] and B's feature [fb] (normal [nAB] from A to B).
  static void _clip(List<Vector3> fa, List<Vector3> fb, Vector3 nAB, double depth, LuminaContactSet out, double margin) {
    if (fa.length >= 3 || fb.length >= 3) {
      bool refIsA;
      if (fa.length >= 3 && fb.length >= 3) {
        refIsA = _faceNormal(fa).dot(nAB).abs() >= _faceNormal(fb).dot(nAB).abs();
      } else {
        refIsA = fa.length >= 3;
      }
      final ref = refIsA ? fa : fb;
      final inc = refIsA ? fb : fa;
      final toOther = refIsA ? nAB : -nAB;
      final refN = _faceNormal(ref);
      if (refN.dot(toOther) < 0) refN.negate();
      final centroid = Vector3.zero();
      for (final p in ref) {
        centroid.add(p);
      }
      centroid.scale(1 / ref.length);
      var poly = List<Vector3>.of(inc);
      for (var i = 0; i < ref.length && poly.isNotEmpty; i++) {
        final p = ref[i], q = ref[(i + 1) % ref.length];
        final sideN = (q - p).cross(refN);
        if (sideN.length2 < 1e-12) continue;
        sideN.normalize();
        if (sideN.dot(centroid - p) > 0) sideN.negate();
        poly = _clipPlane(poly, sideN, sideN.dot(p));
      }
      final pts = <Vector3>[];
      final depths = <double>[];
      for (final p in poly) {
        final s = (p - ref[0]).dot(refN);
        if (s <= margin) {
          pts.add(p - refN * (s * 0.5));
          depths.add(-s);
        }
      }
      _reduce(pts, depths, out);
      return;
    }
    if (fa.length == 2 && fb.length == 2) {
      final da = fa[1] - fa[0], db = fb[1] - fb[0];
      final cross = da.normalized().cross(db.normalized());
      if (cross.length < 0.05) {
        // Parallel segments: B's segment clipped to A's extent.
        final dir = da.normalized();
        final lo = dir.dot(fa[0]), hi = dir.dot(fa[1]);
        var seg = List<Vector3>.of(fb);
        seg = _clipPlane(seg, dir, math.max(lo, hi));
        seg = _clipPlane(seg, -dir, -math.min(lo, hi));
        for (final p in seg) {
          out.add(p - nAB * (depth * 0.5), depth);
        }
        if (!out.isEmpty) return;
      }
    }
    final pa = fa.length == 1 ? fa[0] : null;
    final pb = fb.length == 1 ? fb[0] : null;
    final ca = Vector3.zero(), cb = Vector3.zero();
    closestPointsBetweenSegments(pa ?? fa[0], pa ?? fa[1], pb ?? fb[0], pb ?? fb[1], ca, cb);
    out.add((ca + cb)..scale(0.5), depth);
  }

  static Vector3 _faceNormal(List<Vector3> face) {
    final n = Vector3.zero();
    for (var i = 0; i < face.length; i++) {
      final p = face[i], q = face[(i + 1) % face.length];
      n.x += (p.y - q.y) * (p.z + q.z);
      n.y += (p.z - q.z) * (p.x + q.x);
      n.z += (p.x - q.x) * (p.y + q.y);
    }
    if (n.length2 < 1e-18) return Vector3(0, 1, 0);
    return n..normalize();
  }

  // --- Heightfield ----------------------------------------------------------------

  static bool _heightfield(LuminaCollider a, LuminaCollider b, HeightfieldShape hf, LuminaContactSet out, double margin) {
    final sa = a.shape;
    if (sa is SphereShape || sa is CapsuleShape) {
      final contact = ContactResult();
      if (!testPair(sa, a.transform, hf, b.transform, contact) || !contact.isColliding) return false;
      final nAB = -contact.normal..normalize();
      out.normal.setFrom(nAB);
      final r = sa is SphereShape ? sa.radius : (sa as CapsuleShape).radius;
      final center = contact.contactPoint.length2 > 0 ? contact.contactPoint : a.transform.getTranslation() + nAB * r;
      out.add(center, contact.penetrationDepth);
      return true;
    }
    final samples = _samplePoints(sa, a.transform);
    final inv = Matrix4.copy(b.transform);
    if (inv.invert() == 0.0) return false;
    final m = b.transform.storage;
    final scaleY = math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6]);
    final rot = Matrix3(m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10]);
    final pts = <Vector3>[];
    final depths = <double>[];
    final normal = Vector3.zero();
    for (final p in samples) {
      final l = inv.transform3(p.clone());
      if (!hf.contains(l.x, l.z)) continue;
      final h = hf.heightAt(l.x, l.z);
      final gap = (l.y - h) * scaleY;
      if (gap > margin) continue;
      final nl = hf.normalAt(l.x, l.z);
      final nw = rot.transformed(nl)..normalize();
      final depth = -gap * nw.y.abs().clamp(0.2, 1.0);
      pts.add(p + nw * (depth * 0.5));
      depths.add(depth);
      normal.add(nw);
    }
    if (pts.isEmpty || normal.length2 < 1e-12) return false;
    out.normal.setFrom(-normal.normalized());
    _reduce(pts, depths, out);
    return true;
  }

  static List<Vector3> _samplePoints(CollisionShape s, Matrix4 t) {
    if (s is BoxShape) {
      final h = s.halfExtents;
      return [
        for (var i = 0; i < 8; i++)
          t.transform3(Vector3(i & 1 == 0 ? -h.x : h.x, i & 2 == 0 ? -h.y : h.y, i & 4 == 0 ? -h.z : h.z)),
      ];
    }
    if (s is ConvexHullShape) return [for (final v in s.vertices) t.transform3(v.clone())];
    final pos = t.getTranslation();
    final u = Vector3(t.entry(0, 1), t.entry(1, 1), t.entry(2, 1))..normalize();
    if (s is CylinderShape) {
      final hh = s.height * 0.5;
      return [..._disc(pos + u * hh, u, s.radius, true), ..._disc(pos - u * hh, u, s.radius, false)];
    }
    if (s is ConeShape) {
      final hh = s.height * 0.5;
      return [pos + u * hh, ..._disc(pos - u * hh, u, s.radius, false)];
    }
    return [pos];
  }
}

/// An oriented box: centre, unit axes and half extents (scale folded in).
class _Box {
  final Vector3 c;
  final List<Vector3> u;
  final List<double> e;
  _Box(this.c, this.u, this.e);

  factory _Box.of(BoxShape s, Matrix4 t) {
    final m = t.storage;
    final axes = <Vector3>[];
    final ext = <double>[];
    final h = s.halfExtents;
    for (var i = 0; i < 3; i++) {
      final col = Vector3(m[i * 4], m[i * 4 + 1], m[i * 4 + 2]);
      final len = col.length;
      axes.add(len > 1e-12 ? col / len : Vector3(i == 0 ? 1 : 0, i == 1 ? 1 : 0, i == 2 ? 1 : 0));
      ext.add(h[i].abs() * (len > 1e-12 ? len : 1.0));
    }
    return _Box(t.getTranslation(), axes, ext);
  }
}
