import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/formats/lumina_garment_document.dart';
import 'package:lumina_core/src/garment/rbf.dart';
import 'package:lumina_core/src/garment/skinned_mesh_data.dart';
import 'package:lumina_core/src/garment/triangle_grid.dart';

/// How a fit went: the largest and mean depth of a garment vertex inside
/// the target body (cm, ≈ 0 after the push-out), the landmark error on the
/// target (cm; garment landmark against the body landmark carried to the
/// target), whether the bodies corresponded vertex for vertex, and the time.
class LuminaGarmentFitReport {
  const LuminaGarmentFitReport({
    required this.maxPenetration,
    required this.meanPenetration,
    required this.landmarkError,
    required this.denseCorrespondence,
    required this.milliseconds,
    required this.pushedVertices,
  });

  final double maxPenetration, meanPenetration;
  final Map<String, double> landmarkError;
  final bool denseCorrespondence;
  final int milliseconds;
  final int pushedVertices;

  Map<String, Object?> toJson() => {
    'max_penetration_cm': maxPenetration,
    'mean_penetration_cm': meanPenetration,
    'landmark_error_cm': landmarkError,
    'dense': denseCorrespondence,
    'ms': milliseconds,
    'pushed_vertices': pushedVertices,
  };
}

/// A garment fitted to a body: its vertices (cm, the target body's mesh
/// space), normals, uvs, triangles, four skin influences per vertex (node
/// indices of the target body's GLB) and how the fit went.
class LuminaGarmentFit {
  const LuminaGarmentFit({
    required this.positions,
    required this.normals,
    required this.uvs,
    required this.triangles,
    required this.joints,
    required this.weights,
    required this.report,
  });

  final Float64List positions;
  final Float32List normals;
  final Float32List uvs;
  final Uint32List triangles;
  final Uint16List joints;
  final Float32List weights;
  final LuminaGarmentFitReport report;

  int get vertexCount => positions.length ~/ 3;
}

/// Fits a garment authored on one body to another (pure Dart; run it on a
/// worker isolate):
///
/// 1. the source mesh at the document's placement on the reference body;
/// 2. a smooth deformation from the reference body to the target: with the
///    same topology (vertex for vertex) an RBF field through sampled body
///    vertices and the landmarks, otherwise each garment vertex follows the
///    skeleton (linear blend skinning with the reference body's weights from
///    the reference rest pose to the target's, joints matched by name);
/// 3. near the skin each vertex keeps its distance to the body: the same
///    triangle and barycentre on the target (same topology) or the nearest
///    target point, along the surface normal;
/// 4. push-out: a vertex inside the target body or closer than the
///    thickness moves out along the surface normal; the push is smoothed
///    over the garment and applied again;
/// 5. skin weights from the nearest target-body surface point (its
///    vertices' weights by barycentre, the four strongest, normalised).
abstract final class LuminaGarmentFitter {
  /// Vertices within this offset (cm) of the skin keep their offset.
  static const double tightOffset = 4, looseOffset = 10;

  /// Rounds of skin weight smoothing over the garment.
  static const int weightSmoothing = 3;

  static LuminaGarmentFit fit({
    required LuminaSkinnedMeshData source,
    required LuminaGarmentDocument document,
    required LuminaSkinnedMeshData referenceBody,
    required LuminaSkinnedMeshData targetBody,
  }) {
    final clock = Stopwatch()..start();
    final n = source.vertexCount;
    final thickness = document.thickness;
    // 1. Placed on the reference body.
    final placed = Float64List(n * 3);
    for (var v = 0; v < n; v++) {
      final p = document.place([source.positions[v * 3], source.positions[v * 3 + 1], source.positions[v * 3 + 2]]);
      placed.setRange(v * 3, v * 3 + 3, p);
    }
    final refGrid = LuminaTriangleGrid(referenceBody.positions, referenceBody.triangles);
    final targetGrid = LuminaTriangleGrid(targetBody.positions, targetBody.triangles);
    // Vertex for vertex: the same mesh layout, or the same UV layout (bodies
    // of one family exported with their seams split differently).
    final correspondence = _correspondence(referenceBody, targetBody);
    final dense = correspondence != null;

    // Each placed vertex against the reference body: nearest point and its
    // signed offset along the surface normal.
    final refHits = List<LuminaSurfacePoint?>.filled(n, null);
    final offsets = Float64List(n);
    for (var v = 0; v < n; v++) {
      final hit = refGrid.closest(placed[v * 3], placed[v * 3 + 1], placed[v * 3 + 2]);
      refHits[v] = hit;
      if (hit != null) {
        offsets[v] = (placed[v * 3] - hit.x) * hit.nx + (placed[v * 3 + 1] - hit.y) * hit.ny + (placed[v * 3 + 2] - hit.z) * hit.nz;
      }
    }

    // 2. Coarse deformation.
    final moved = Float64List(n * 3);
    if (dense) {
      final field = _denseField(referenceBody, targetBody, correspondence);
      final d = [0.0, 0.0, 0.0];
      for (var v = 0; v < n; v++) {
        field.displacement(placed[v * 3], placed[v * 3 + 1], placed[v * 3 + 2], d);
        for (var k = 0; k < 3; k++) {
          moved[v * 3 + k] = placed[v * 3 + k] + d[k];
        }
      }
    } else {
      final retarget = _jointRetarget(referenceBody, targetBody);
      for (var v = 0; v < n; v++) {
        final p = _skinRetarget(referenceBody, refHits[v], retarget, placed[v * 3], placed[v * 3 + 1], placed[v * 3 + 2]);
        moved.setRange(v * 3, v * 3 + 3, p);
      }
    }

    // 3. Keep the distance to the skin near it.
    for (var v = 0; v < n; v++) {
      final h = offsets[v];
      final hit = refHits[v];
      if (hit == null || h.abs() >= looseOffset) continue;
      double qx, qy, qz, nx, ny, nz;
      final corners = dense ? _targetCorners(referenceBody, correspondence, hit.triangle) : null;
      if (corners != null) {
        final (a, b, c) = corners;
        final tp = targetBody.positions;
        qx = hit.u * tp[a] + hit.v * tp[b] + hit.w * tp[c];
        qy = hit.u * tp[a + 1] + hit.v * tp[b + 1] + hit.w * tp[c + 1];
        qz = hit.u * tp[a + 2] + hit.v * tp[b + 2] + hit.w * tp[c + 2];
        final fn = _faceNormal(tp, a, b, c);
        (nx, ny, nz) = fn;
      } else {
        final near = targetGrid.closest(moved[v * 3], moved[v * 3 + 1], moved[v * 3 + 2]);
        if (near == null) continue;
        (qx, qy, qz, nx, ny, nz) = (near.x, near.y, near.z, near.nx, near.ny, near.nz);
      }
      final keep = math.max(h, thickness);
      final bound = [qx + nx * keep, qy + ny * keep, qz + nz * keep];
      final alpha = h.abs() <= tightOffset ? 1.0 : 1 - (h.abs() - tightOffset) / (looseOffset - tightOffset);
      for (var k = 0; k < 3; k++) {
        moved[v * 3 + k] = alpha * bound[k] + (1 - alpha) * moved[v * 3 + k];
      }
    }

    // 4. Push-out, smoothed, then again so nothing stays inside.
    final adjacency = _adjacency(n, source.triangles, source.positions);
    var pushed = _pushOut(moved, targetGrid, thickness);
    final push = Float64List(n * 3);
    for (var round = 0; round < 2; round++) {
      final before = Float64List.fromList(moved);
      _pushOut(moved, targetGrid, thickness);
      for (var i = 0; i < push.length; i++) {
        push[i] = moved[i] - before[i];
      }
      _smooth(push, adjacency, 2);
      for (var i = 0; i < push.length; i++) {
        moved[i] = before[i] + push[i];
      }
    }
    // Until nothing moves (a push can land a vertex nearer another face).
    for (var pass = 0; pass < 4; pass++) {
      final moves = _pushOut(moved, targetGrid, thickness);
      pushed += moves;
      if (moves == 0) break;
    }
    if (document.settleSteps > 0) _settle(moved, source.triangles, adjacency, targetGrid, thickness, document.settleSteps);

    // Measure what is left inside.
    var maxPen = 0.0, sumPen = 0.0;
    for (var v = 0; v < n; v++) {
      final hit = targetGrid.closest(moved[v * 3], moved[v * 3 + 1], moved[v * 3 + 2]);
      if (hit == null) continue;
      final s = (moved[v * 3] - hit.x) * hit.nx + (moved[v * 3 + 1] - hit.y) * hit.ny + (moved[v * 3 + 2] - hit.z) * hit.nz;
      if (s < 0) {
        maxPen = math.max(maxPen, -s);
        sumPen += -s;
      }
    }

    // 5. Skin weights from the target body, smoothed over the garment so
    // no lone vertex follows a finger it happens to lie near.
    final joints = Uint16List(n * 4), weights = Float32List(n * 4);
    final tj = targetBody.joints, tw = targetBody.weights;
    var influence = List<Map<int, double>>.generate(n, (_) => <int, double>{});
    for (var v = 0; v < n; v++) {
      final hit = targetGrid.closest(moved[v * 3], moved[v * 3 + 1], moved[v * 3 + 2]);
      if (hit == null || tj == null || tw == null) continue;
      final acc = influence[v];
      final t = hit.triangle * 3;
      for (final (corner, bary) in [(targetBody.triangles[t], hit.u), (targetBody.triangles[t + 1], hit.v), (targetBody.triangles[t + 2], hit.w)]) {
        for (var k = 0; k < 4; k++) {
          final w = tw[corner * 4 + k] * bary;
          if (w > 0) acc.update(tj[corner * 4 + k], (x) => x + w, ifAbsent: () => w);
        }
      }
    }
    for (var it = 0; it < weightSmoothing; it++) {
      final next = List<Map<int, double>>.generate(n, (_) => <int, double>{});
      for (var v = 0; v < n; v++) {
        final nb = adjacency[v];
        final root = nb.length == 1 && nb[0] < 0 ? -1 - nb[0] : v;
        final around = root == v ? nb : adjacency[root];
        final acc = next[v];
        void add(Map<int, double> m, double f) {
          for (final e in m.entries) {
            acc.update(e.key, (x) => x + e.value * f, ifAbsent: () => e.value * f);
          }
        }

        add(influence[root], 1);
        for (final u in around) {
          if (u >= 0) add(influence[u], 1 / math.max(1, around.length));
        }
      }
      influence = next;
    }
    for (var v = 0; v < n; v++) {
      final best = influence[v].entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (best.isEmpty) {
        weights[v * 4] = 1;
        continue;
      }
      final top = best.take(4).toList();
      final total = top.fold(0.0, (s, e) => s + e.value);
      for (var k = 0; k < top.length; k++) {
        joints[v * 4 + k] = top[k].key;
        weights[v * 4 + k] = total > 0 ? top[k].value / total : (k == 0 ? 1 : 0);
      }
    }

    // Landmark error on the target: the garment landmark fitted against
    // the body landmark carried to the target the same way.
    final landmarkError = <String, double>{};
    for (final l in document.landmarks) {
      if (!l.isComplete) continue;
      final g = _nearestVertex(source.positions, l.garment!);
      if (g < 0) continue;
      final bodyHit = refGrid.closest(l.body![0], l.body![1], l.body![2]);
      if (bodyHit == null) continue;
      List<double> target;
      final corners = dense ? _targetCorners(referenceBody, correspondence, bodyHit.triangle) : null;
      if (corners != null) {
        final (a, b, c) = corners;
        final tp = targetBody.positions;
        target = [for (var k = 0; k < 3; k++) bodyHit.u * tp[a + k] + bodyHit.v * tp[b + k] + bodyHit.w * tp[c + k]];
      } else {
        target = _skinRetarget(referenceBody, bodyHit, _jointRetarget(referenceBody, targetBody), l.body![0], l.body![1], l.body![2]);
      }
      // The authored gap between the two points is part of the design.
      final authored = _distance(document.place(l.garment!), l.body!);
      final now = _distance([moved[g * 3], moved[g * 3 + 1], moved[g * 3 + 2]], target);
      landmarkError[l.name] = (now - authored).abs();
    }

    final normals = _vertexNormals(moved, source.triangles);
    return LuminaGarmentFit(
      positions: moved,
      normals: normals,
      uvs: Float32List.fromList(source.uvs),
      triangles: Uint32List.fromList(source.triangles),
      joints: joints,
      weights: weights,
      report: LuminaGarmentFitReport(
        maxPenetration: maxPen,
        meanPenetration: n == 0 ? 0 : sumPen / n,
        landmarkError: landmarkError,
        denseCorrespondence: dense,
        milliseconds: clock.elapsedMilliseconds,
        pushedVertices: pushed,
      ),
    );
  }

  /// The RBF field from the reference body to the target through farthest
  /// point samples of the shared vertices and the landmarks.
  static LuminaRbfField _denseField(LuminaSkinnedMeshData ref, LuminaSkinnedMeshData target, Int32List map) {
    final samples = _farthestPoints(ref.positions, 360);
    final from = <double>[], to = <double>[];
    for (final s in samples) {
      final t = map[s];
      if (t < 0) continue;
      for (var k = 0; k < 3; k++) {
        from.add(ref.positions[s * 3 + k]);
        to.add(target.positions[t * 3 + k]);
      }
    }
    return LuminaRbfField.fit(from, to, smoothing: 1e-3);
  }

  /// Reference vertex → target vertex when the two bodies correspond vertex
  /// for vertex: the same layout (identity), else the same UV layout (each
  /// UV, rounded to 1e-5, names one vertex; at least 95 % of the reference
  /// vertices found). Null when they do not.
  static Int32List? _correspondence(LuminaSkinnedMeshData ref, LuminaSkinnedMeshData target) {
    if (ref.vertexCount == target.vertexCount && ref.triangleCount == target.triangleCount) {
      return Int32List.fromList([for (var v = 0; v < ref.vertexCount; v++) v]);
    }
    if (ref.uvs.isEmpty || target.uvs.isEmpty) return null;
    int key(Float32List uv, int v) => (uv[v * 2] * 1e5).round() * 200003 + (uv[v * 2 + 1] * 1e5).round();
    // Mirrored UVs name two vertices (left and right): among the target
    // vertices with a UV, the nearest in each body's normalised bounds.
    final rn = _normaliser(ref.positions), tn = _normaliser(target.positions);
    final byUv = <int, List<int>>{};
    for (var v = 0; v < target.vertexCount; v++) {
      (byUv[key(target.uvs, v)] ??= <int>[]).add(v);
    }
    final map = Int32List(ref.vertexCount);
    var found = 0;
    for (var v = 0; v < ref.vertexCount; v++) {
      final candidates = byUv[key(ref.uvs, v)];
      var best = -1;
      var bestD = 0.25; // within a quarter of the body's size
      if (candidates != null) {
        for (final t in candidates) {
          var d = 0.0;
          for (var k = 0; k < 3; k++) {
            final a = (ref.positions[v * 3 + k] - rn.$1[k]) / rn.$2, b = (target.positions[t * 3 + k] - tn.$1[k]) / tn.$2;
            d += (a - b) * (a - b);
          }
          d = math.sqrt(d);
          if (d < bestD) {
            bestD = d;
            best = t;
          }
        }
      }
      map[v] = best;
      if (best >= 0) found++;
    }
    return found >= ref.vertexCount * 0.95 ? map : null;
  }

  /// The centre of [p]'s bounds and its largest extent.
  static (List<double>, double) _normaliser(Float64List p) {
    final lo = [double.infinity, double.infinity, double.infinity], hi = [-double.infinity, -double.infinity, -double.infinity];
    for (var i = 0; i + 2 < p.length; i += 3) {
      for (var k = 0; k < 3; k++) {
        lo[k] = math.min(lo[k], p[i + k]);
        hi[k] = math.max(hi[k], p[i + k]);
      }
    }
    final size = math.max(hi[0] - lo[0], math.max(hi[1] - lo[1], hi[2] - lo[2]));
    return ([for (var k = 0; k < 3; k++) (lo[k] + hi[k]) / 2], size <= 0 ? 1.0 : size);
  }

  /// The target vertices (×3 offsets) of reference triangle [t]'s corners,
  /// or null when one has no counterpart.
  static (int, int, int)? _targetCorners(LuminaSkinnedMeshData ref, Int32List map, int t) {
    final a = map[ref.triangles[t * 3]], b = map[ref.triangles[t * 3 + 1]], c = map[ref.triangles[t * 3 + 2]];
    if (a < 0 || b < 0 || c < 0) return null;
    return (a * 3, b * 3, c * 3);
  }

  static List<int> _farthestPoints(Float64List p, int count) {
    final n = p.length ~/ 3;
    if (n <= count) return [for (var i = 0; i < n; i++) i];
    final dist = Float64List(n)..fillRange(0, n, double.infinity);
    final out = <int>[0];
    var current = 0;
    for (var s = 1; s < count; s++) {
      var far = 0, farD = -1.0;
      for (var i = 0; i < n; i++) {
        final dx = p[i * 3] - p[current * 3], dy = p[i * 3 + 1] - p[current * 3 + 1], dz = p[i * 3 + 2] - p[current * 3 + 2];
        final d = dx * dx + dy * dy + dz * dz;
        if (d < dist[i]) dist[i] = d;
        if (dist[i] > farD) {
          farD = dist[i];
          far = i;
        }
      }
      out.add(far);
      current = far;
    }
    return out;
  }

  /// Per reference joint node: the matrix taking its rest frame to the
  /// same-named target joint's (target world · reference inverse bind), cm.
  static Map<int, Float64List> _jointRetarget(LuminaSkinnedMeshData ref, LuminaSkinnedMeshData target) {
    final out = <int, Float64List>{};
    for (final e in ref.inverseBind.entries) {
      final name = ref.nodeNames[e.key];
      final t = target.nodeNamed(name);
      if (t < 0) continue;
      final m = Float64List(16);
      final world = Float64List.sublistView(target.nodeWorld, t * 16, t * 16 + 16);
      for (var c = 0; c < 4; c++) {
        for (var r = 0; r < 4; r++) {
          var s = 0.0;
          for (var k = 0; k < 4; k++) {
            s += world[k * 4 + r] * e.value[c * 4 + k];
          }
          m[c * 4 + r] = s;
        }
      }
      out[e.key] = m;
    }
    return out;
  }

  /// (x, y, z) carried from the reference body to the target by the
  /// skinning of the reference surface point [hit] (identity without one).
  static List<double> _skinRetarget(
    LuminaSkinnedMeshData ref,
    LuminaSurfacePoint? hit,
    Map<int, Float64List> retarget,
    double x,
    double y,
    double z,
  ) {
    final rj = ref.joints, rw = ref.weights;
    if (hit == null || rj == null || rw == null) return [x, y, z];
    final acc = <int, double>{};
    final t = hit.triangle * 3;
    for (final (corner, bary) in [(ref.triangles[t], hit.u), (ref.triangles[t + 1], hit.v), (ref.triangles[t + 2], hit.w)]) {
      for (var k = 0; k < 4; k++) {
        final w = rw[corner * 4 + k] * bary;
        if (w > 0) acc.update(rj[corner * 4 + k], (s) => s + w, ifAbsent: () => w);
      }
    }
    var ox = 0.0, oy = 0.0, oz = 0.0, total = 0.0;
    for (final e in acc.entries) {
      final m = retarget[e.key];
      if (m == null) continue;
      ox += e.value * (m[0] * x + m[4] * y + m[8] * z + m[12]);
      oy += e.value * (m[1] * x + m[5] * y + m[9] * z + m[13]);
      oz += e.value * (m[2] * x + m[6] * y + m[10] * z + m[14]);
      total += e.value;
    }
    if (total <= 1e-9) return [x, y, z];
    return [ox / total, oy / total, oz / total];
  }

  /// Moves every vertex closer than [thickness] outside the surface (or
  /// inside it) out along the surface normal; returns how many moved.
  static int _pushOut(Float64List p, LuminaTriangleGrid grid, double thickness) {
    var moved = 0;
    for (var v = 0; v < p.length ~/ 3; v++) {
      // No distance limit: a vertex deep inside the body is far from it.
      final hit = grid.closest(p[v * 3], p[v * 3 + 1], p[v * 3 + 2]);
      if (hit == null) continue;
      final s = (p[v * 3] - hit.x) * hit.nx + (p[v * 3 + 1] - hit.y) * hit.ny + (p[v * 3 + 2] - hit.z) * hit.nz;
      if (s >= thickness - 1e-6) continue;
      p[v * 3] = hit.x + hit.nx * thickness;
      p[v * 3 + 1] = hit.y + hit.ny * thickness;
      p[v * 3 + 2] = hit.z + hit.nz * thickness;
      moved++;
    }
    return moved;
  }

  /// A cloth settle: [steps] steps of 1/60 s under gravity (−Y, cm) with
  /// position-based edge constraints at their lengths now and the body
  /// pushed out after each step; vertices touching the body (within the
  /// thickness plus 1 cm) are held where they are.
  static void _settle(Float64List p, List<int> triangles, List<List<int>> adjacency, LuminaTriangleGrid body, double thickness, int steps) {
    final n = p.length ~/ 3;
    final held = Uint8List(n);
    for (var v = 0; v < n; v++) {
      final hit = body.closest(p[v * 3], p[v * 3 + 1], p[v * 3 + 2], maxDistance: thickness + 1);
      if (hit != null) held[v] = 1;
    }
    // Welded copies move with their root.
    int root(int v) {
      final nb = adjacency[v];
      return nb.length == 1 && nb[0] < 0 ? -1 - nb[0] : v;
    }

    final edges = <int>[];
    final rest = <double>[];
    final seen = <int>{};
    for (var t = 0; t + 2 < triangles.length; t += 3) {
      for (var k = 0; k < 3; k++) {
        final a = root(triangles[t + k]), b = root(triangles[t + (k + 1) % 3]);
        if (a == b) continue;
        final key = a < b ? a * 0x200000 + b : b * 0x200000 + a;
        if (!seen.add(key)) continue;
        edges
          ..add(a)
          ..add(b);
        final dx = p[a * 3] - p[b * 3], dy = p[a * 3 + 1] - p[b * 3 + 1], dz = p[a * 3 + 2] - p[b * 3 + 2];
        rest.add(math.sqrt(dx * dx + dy * dy + dz * dz));
      }
    }
    const dt = 1 / 60, gravity = 980.0;
    final previous = Float64List.fromList(p);
    for (var s = 0; s < steps; s++) {
      for (var v = 0; v < n; v++) {
        if (held[v] == 1 || root(v) != v) continue;
        // Verlet with damping: velocity from the last step, plus gravity.
        final vx = (p[v * 3] - previous[v * 3]) * 0.9;
        final vy = (p[v * 3 + 1] - previous[v * 3 + 1]) * 0.9;
        final vz = (p[v * 3 + 2] - previous[v * 3 + 2]) * 0.9;
        previous[v * 3] = p[v * 3];
        previous[v * 3 + 1] = p[v * 3 + 1];
        previous[v * 3 + 2] = p[v * 3 + 2];
        p[v * 3] += vx;
        p[v * 3 + 1] += vy - gravity * dt * dt;
        p[v * 3 + 2] += vz;
      }
      for (var it = 0; it < 16; it++) {
        for (var e = 0; e < rest.length; e++) {
          final a = edges[e * 2], b = edges[e * 2 + 1];
          final wa = held[a] == 1 ? 0.0 : 1.0, wb = held[b] == 1 ? 0.0 : 1.0;
          if (wa + wb == 0) continue;
          final dx = p[b * 3] - p[a * 3], dy = p[b * 3 + 1] - p[a * 3 + 1], dz = p[b * 3 + 2] - p[a * 3 + 2];
          final len = math.sqrt(dx * dx + dy * dy + dz * dz);
          if (len < 1e-9) continue;
          final c = (len - rest[e]) / len / (wa + wb);
          p[a * 3] += wa * c * dx;
          p[a * 3 + 1] += wa * c * dy;
          p[a * 3 + 2] += wa * c * dz;
          p[b * 3] -= wb * c * dx;
          p[b * 3 + 1] -= wb * c * dy;
          p[b * 3 + 2] -= wb * c * dz;
        }
      }
      _pushOut(p, body, thickness);
    }
    for (var v = 0; v < n; v++) {
      final r = root(v);
      if (r == v) continue;
      p[v * 3] = p[r * 3];
      p[v * 3 + 1] = p[r * 3 + 1];
      p[v * 3 + 2] = p[r * 3 + 2];
    }
  }

  /// Neighbours of every vertex (vertices at the same position welded).
  static List<List<int>> _adjacency(int n, List<int> triangles, List<double> positions) {
    final weld = <String, int>{};
    final root = Int32List(n);
    for (var v = 0; v < n; v++) {
      final k = '${(positions[v * 3] * 1e3).round()},${(positions[v * 3 + 1] * 1e3).round()},${(positions[v * 3 + 2] * 1e3).round()}';
      root[v] = weld.putIfAbsent(k, () => v);
    }
    final sets = List.generate(n, (_) => <int>{});
    for (var t = 0; t + 2 < triangles.length; t += 3) {
      for (var k = 0; k < 3; k++) {
        final a = root[triangles[t + k]], b = root[triangles[t + (k + 1) % 3]];
        if (a == b) continue;
        sets[a].add(b);
        sets[b].add(a);
      }
    }
    return [for (var v = 0; v < n; v++) root[v] == v ? sets[v].toList() : <int>[-1 - root[v]]];
  }

  /// Laplacian smoothing of a per-vertex vector field over [adjacency]
  /// (welded copies take their root's value).
  static void _smooth(Float64List field, List<List<int>> adjacency, int iterations) {
    final n = adjacency.length;
    for (var it = 0; it < iterations; it++) {
      final next = Float64List.fromList(field);
      for (var v = 0; v < n; v++) {
        final nb = adjacency[v];
        if (nb.isEmpty || (nb.length == 1 && nb[0] < 0)) continue;
        for (var k = 0; k < 3; k++) {
          var s = field[v * 3 + k];
          for (final u in nb) {
            s += field[u * 3 + k];
          }
          next[v * 3 + k] = s / (nb.length + 1);
        }
      }
      for (var v = 0; v < n; v++) {
        final nb = adjacency[v];
        if (nb.length == 1 && nb[0] < 0) {
          final r = -1 - nb[0];
          for (var k = 0; k < 3; k++) {
            next[v * 3 + k] = next[r * 3 + k];
          }
        }
      }
      field.setAll(0, next);
    }
  }

  static (double, double, double) _faceNormal(List<double> p, int a, int b, int c) {
    final ux = p[b] - p[a], uy = p[b + 1] - p[a + 1], uz = p[b + 2] - p[a + 2];
    final vx = p[c] - p[a], vy = p[c + 1] - p[a + 1], vz = p[c + 2] - p[a + 2];
    var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    final l = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (l > 1e-12) {
      nx /= l;
      ny /= l;
      nz /= l;
    }
    return (nx, ny, nz);
  }

  static Float32List _vertexNormals(Float64List p, List<int> triangles) {
    final n = Float32List(p.length);
    for (var t = 0; t + 2 < triangles.length; t += 3) {
      final a = triangles[t] * 3, b = triangles[t + 1] * 3, c = triangles[t + 2] * 3;
      final ux = p[b] - p[a], uy = p[b + 1] - p[a + 1], uz = p[b + 2] - p[a + 2];
      final vx = p[c] - p[a], vy = p[c + 1] - p[a + 1], vz = p[c + 2] - p[a + 2];
      final nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      for (final v in [a, b, c]) {
        n[v] += nx;
        n[v + 1] += ny;
        n[v + 2] += nz;
      }
    }
    for (var i = 0; i + 2 < n.length; i += 3) {
      final l = math.sqrt(n[i] * n[i] + n[i + 1] * n[i + 1] + n[i + 2] * n[i + 2]);
      if (l > 1e-12) {
        n[i] /= l;
        n[i + 1] /= l;
        n[i + 2] /= l;
      } else {
        n[i + 1] = 1;
      }
    }
    return n;
  }

  static int _nearestVertex(List<double> p, List<double> q) {
    var best = -1;
    var bestD = double.infinity;
    for (var v = 0; v < p.length ~/ 3; v++) {
      final dx = p[v * 3] - q[0], dy = p[v * 3 + 1] - q[1], dz = p[v * 3 + 2] - q[2];
      final d = dx * dx + dy * dy + dz * dz;
      if (d < bestD) {
        bestD = d;
        best = v;
      }
    }
    return best;
  }

  static double _distance(List<double> a, List<double> b) {
    final dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
