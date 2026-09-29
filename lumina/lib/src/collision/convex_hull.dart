import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'shapes.dart';

/// One face plane of a [ConvexHullShape]: points `p` of the hull satisfy
/// `normal · p <= offset`, and `normal` points out of the hull.
class ConvexHullPlane {
  final Vector3 normal;
  final double offset;
  const ConvexHullPlane(this.normal, this.offset);
}

/// Convex collision shape: the convex hull of a point set, in the owning
/// component's local frame and world units.
///
/// The hull is built once, when the shape is created: points closer than
/// [weldTolerance] are merged (an imported hull carries each corner once per
/// face normal), points inside the hull are dropped, and what is left are the
/// hull's [vertices], its outward [triangles] and one [planes] entry per
/// flat face. Collision queries only read these.
///
/// A point set with no volume (fewer than four points, or all of them on one
/// line or plane) is [isDegenerate]: it still collides — GJK works on any
/// point set — and ray casts treat it as its local bounding box.
class ConvexHullShape extends CollisionShape {
  /// Points closer than this (world units) are one hull vertex.
  static const double weldTolerance = 1e-4;

  /// The hull's corners (local frame).
  final List<Vector3> vertices;

  /// Outward-facing triangles, three indices into [vertices] each (empty
  /// when [isDegenerate]).
  final List<int> triangles;

  /// One plane per flat face (coplanar triangles share one); the six local
  /// bounding-box planes when [isDegenerate].
  final List<ConvexHullPlane> planes;

  /// Local bounds of [vertices].
  final Vector3 localMin;
  final Vector3 localMax;

  /// Whether the points enclose no volume.
  final bool isDegenerate;

  ConvexHullShape._(this.vertices, this.triangles, this.planes, this.localMin, this.localMax, this.isDegenerate);

  factory ConvexHullShape(List<Vector3> points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'a convex hull needs at least one point');
    }
    final welded = _weld(points);
    final lo = welded.first.clone();
    final hi = welded.first.clone();
    for (final p in welded) {
      Vector3.min(lo, p, lo);
      Vector3.max(hi, p, hi);
    }
    final built = _QuickHull(welded).build();
    if (built == null) {
      return ConvexHullShape._(
        List.unmodifiable(welded),
        const [],
        List.unmodifiable(_boxPlanes(lo, hi)),
        lo,
        hi,
        true,
      );
    }
    return ConvexHullShape._(
      List.unmodifiable(built.vertices),
      List.unmodifiable(built.triangles),
      List.unmodifiable(built.planes),
      lo,
      hi,
      false,
    );
  }

  /// Centre of the local bounds.
  Vector3 get localCenter => (localMin + localMax)..scale(0.5);

  /// The vertex farthest along [localDirection] (local frame).
  Vector3 localSupport(Vector3 localDirection) {
    var best = vertices.first;
    var bestDot = best.dot(localDirection);
    for (var i = 1; i < vertices.length; i++) {
      final d = vertices[i].dot(localDirection);
      if (d > bestDot) {
        bestDot = d;
        best = vertices[i];
      }
    }
    return best;
  }

  /// Merges points closer than [weldTolerance], in linear time (a hash grid
  /// of tolerance-sized cells; a mesh's whole vertex buffer can be hulled).
  static List<Vector3> _weld(List<Vector3> points) {
    const tol2 = weldTolerance * weldTolerance;
    final out = <Vector3>[];
    final grid = <int, List<Vector3>>{};
    int key(int x, int y, int z) => (x * 73856093) ^ (y * 19349663) ^ (z * 83492791);
    for (final p in points) {
      final cx = (p.x / weldTolerance).floor(), cy = (p.y / weldTolerance).floor(), cz = (p.z / weldTolerance).floor();
      var duplicate = false;
      for (var dx = -1; dx <= 1 && !duplicate; dx++) {
        for (var dy = -1; dy <= 1 && !duplicate; dy++) {
          for (var dz = -1; dz <= 1 && !duplicate; dz++) {
            final bucket = grid[key(cx + dx, cy + dy, cz + dz)];
            if (bucket == null) continue;
            for (final q in bucket) {
              if (p.distanceToSquared(q) <= tol2) {
                duplicate = true;
                break;
              }
            }
          }
        }
      }
      if (duplicate) continue;
      final kept = p.clone();
      out.add(kept);
      grid.putIfAbsent(key(cx, cy, cz), () => []).add(kept);
    }
    return out;
  }

  static List<ConvexHullPlane> _boxPlanes(Vector3 lo, Vector3 hi) => [
        ConvexHullPlane(Vector3(1, 0, 0), hi.x),
        ConvexHullPlane(Vector3(-1, 0, 0), -lo.x),
        ConvexHullPlane(Vector3(0, 1, 0), hi.y),
        ConvexHullPlane(Vector3(0, -1, 0), -lo.y),
        ConvexHullPlane(Vector3(0, 0, 1), hi.z),
        ConvexHullPlane(Vector3(0, 0, -1), -lo.z),
      ];
}

class _Face {
  final int a, b, c;
  final Vector3 normal;
  final double offset;
  bool alive = true;
  _Face(this.a, this.b, this.c, this.normal, this.offset);

  double distance(Vector3 p) => normal.dot(p) - offset;
}

/// Incremental 3D convex hull over already-welded points: an initial
/// tetrahedron from the extreme points, then every other point outside the
/// hull replaces the faces it sees (flood-filled from the one it sees most,
/// so the visible region stays connected) with a fan to their horizon.
class _QuickHull {
  final List<Vector3> points;
  final List<_Face> _faces = [];
  late final double _eps;

  _QuickHull(this.points);

  ({List<Vector3> vertices, List<int> triangles, List<ConvexHullPlane> planes})? build() {
    if (points.length < 4) return null;
    var extent = 0.0;
    for (final p in points) {
      extent = math.max(extent, math.max(p.x.abs(), math.max(p.y.abs(), p.z.abs())));
    }
    // Points within this of a face count as on it (a flat face of an
    // imported hull is only flat to its 0.01 cm rounding).
    _eps = math.max(extent, 1.0) * 1e-7;

    final seed = _initialTetrahedron();
    if (seed == null) return null;
    // Farthest points first: the hull grows to its size early and most of
    // a mesh's vertices then fall inside it and cost one face scan each.
    final used = <int>{...seed};
    final centre = (points[seed[0]] + points[seed[1]] + points[seed[2]] + points[seed[3]])..scale(0.25);
    final order = [for (var i = 0; i < points.length; i++) if (!used.contains(i)) i]
      ..sort((a, b) => points[b].distanceToSquared(centre).compareTo(points[a].distanceToSquared(centre)));
    for (final i in order) {
      _add(i);
    }

    final alive = _faces.where((f) => f.alive).toList();
    final remap = <int, int>{};
    final vertices = <Vector3>[];
    final triangles = <int>[];
    int index(int i) => remap.putIfAbsent(i, () {
          vertices.add(points[i].clone());
          return vertices.length - 1;
        });
    for (final f in alive) {
      triangles
        ..add(index(f.a))
        ..add(index(f.b))
        ..add(index(f.c));
    }
    final planes = <ConvexHullPlane>[];
    final planeTol = math.max(extent, 1.0) * 1e-6;
    for (final f in alive) {
      final same = planes.any((p) => p.normal.dot(f.normal) > 1 - 1e-9 && (p.offset - f.offset).abs() <= planeTol);
      if (!same) planes.add(ConvexHullPlane(f.normal.clone(), f.offset));
    }
    return (vertices: vertices, triangles: triangles, planes: planes);
  }

  List<int>? _initialTetrahedron() {
    // The two extreme points (along x, y or z) farthest apart.
    final extremes = <int>[];
    for (var axis = 0; axis < 3; axis++) {
      var lo = 0, hi = 0;
      for (var i = 1; i < points.length; i++) {
        if (points[i][axis] < points[lo][axis]) lo = i;
        if (points[i][axis] > points[hi][axis]) hi = i;
      }
      extremes
        ..add(lo)
        ..add(hi);
    }
    var i0 = 0, i1 = 0;
    var best = -1.0;
    for (final a in extremes) {
      for (final b in extremes) {
        final d = points[a].distanceToSquared(points[b]);
        if (d > best) {
          best = d;
          i0 = a;
          i1 = b;
        }
      }
    }
    if (best <= _eps * _eps) return null;

    // Farthest from the line i0–i1.
    final line = points[i1] - points[i0];
    var i2 = -1;
    best = 0.0;
    for (var i = 0; i < points.length; i++) {
      final d = line.cross(points[i] - points[i0]).length2;
      if (d > best) {
        best = d;
        i2 = i;
      }
    }
    if (i2 < 0 || math.sqrt(best) / line.length <= _eps) return null;

    // Farthest from the plane i0–i1–i2.
    final n = line.cross(points[i2] - points[i0])..normalize();
    var i3 = -1;
    best = 0.0;
    for (var i = 0; i < points.length; i++) {
      final d = n.dot(points[i] - points[i0]).abs();
      if (d > best) {
        best = d;
        i3 = i;
      }
    }
    if (i3 < 0 || best <= _eps) return null;

    // Orient the four faces outwards from the tetrahedron's centroid.
    final centroid = (points[i0] + points[i1] + points[i2] + points[i3])..scale(0.25);
    void face(int a, int b, int c) {
      final f = _makeFace(a, b, c);
      if (f.distance(centroid) > 0) {
        _faces.add(_makeFace(a, c, b));
      } else {
        _faces.add(f);
      }
    }

    face(i0, i1, i2);
    face(i0, i3, i1);
    face(i0, i2, i3);
    face(i1, i3, i2);
    return [i0, i1, i2, i3];
  }

  _Face _makeFace(int a, int b, int c) {
    final n = (points[b] - points[a]).cross(points[c] - points[a]);
    final len = n.length;
    if (len > 0) n.scale(1 / len);
    return _Face(a, b, c, n, n.dot(points[a]));
  }

  /// Directed edge (u, v) → the live face that has it, kept in step with
  /// [_faces] as faces die and are made (was rebuilt from every face for each
  /// point added, which made a large point set quadratic).
  final Map<int, _Face> _edgeFace = {};
  int _dead = 0;

  int _edgeKey(int u, int v) => u * points.length + v;

  void _link(_Face f) {
    _edgeFace[_edgeKey(f.a, f.b)] = f;
    _edgeFace[_edgeKey(f.b, f.c)] = f;
    _edgeFace[_edgeKey(f.c, f.a)] = f;
  }

  void _unlink(_Face f) {
    for (final k in [_edgeKey(f.a, f.b), _edgeKey(f.b, f.c), _edgeKey(f.c, f.a)]) {
      if (identical(_edgeFace[k], f)) _edgeFace.remove(k);
    }
  }

  void _add(int pi) {
    final p = points[pi];
    _Face? seed;
    var seedDistance = _eps;
    for (final f in _faces) {
      if (!f.alive) continue;
      final d = f.distance(p);
      if (d > seedDistance) {
        seedDistance = d;
        seed = f;
      }
    }
    if (seed == null) return; // inside (or within tolerance of) the hull

    if (_edgeFace.isEmpty) {
      for (final f in _faces) {
        if (f.alive) _link(f);
      }
    }

    // Visible region, connected to the seed.
    final visible = <_Face>{seed};
    final stack = <_Face>[seed];
    while (stack.isNotEmpty) {
      final f = stack.removeLast();
      for (final (u, v) in [(f.a, f.b), (f.b, f.c), (f.c, f.a)]) {
        final n = _edgeFace[_edgeKey(v, u)];
        if (n != null && !visible.contains(n) && n.distance(p) > _eps) {
          visible.add(n);
          stack.add(n);
        }
      }
    }

    // Horizon: edges of the visible region whose neighbour stays.
    final horizon = <(int, int)>[];
    for (final f in visible) {
      for (final (u, v) in [(f.a, f.b), (f.b, f.c), (f.c, f.a)]) {
        final n = _edgeFace[_edgeKey(v, u)];
        if (n == null || !visible.contains(n)) horizon.add((u, v));
      }
    }
    for (final f in visible) {
      f.alive = false;
      _unlink(f);
    }
    _dead += visible.length;
    for (final (u, v) in horizon) {
      final f = _makeFace(u, v, pi);
      _faces.add(f);
      _link(f);
    }
    // Drop dead faces once they outnumber the live ones, so every scan stays
    // proportional to the hull's size.
    if (_dead > _faces.length - _dead) {
      _faces.removeWhere((f) => !f.alive);
      _dead = 0;
    }
  }
}
