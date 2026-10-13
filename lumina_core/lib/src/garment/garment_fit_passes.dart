part of 'package:lumina_core/src/garment/garment_fitter.dart';

// The surface passes of the fit: push-out, cloth settle, covering the
// body's bumps and sub-meshes, and the mesh helpers they share.

/// Moves every vertex closer than [thickness] outside the surface (or
/// inside it) out along the surface normal; returns how many moved.
int _pushOut(Float64List p, LuminaTriangleGrid grid, double thickness, {double reach = double.infinity}) {
  var moved = 0;
  for (var v = 0; v < p.length ~/ 3; v++) {
    // No distance limit by default: a vertex deep inside the body is far
    // from its surface.
    final hit = grid.closest(p[v * 3], p[v * 3 + 1], p[v * 3 + 2], maxDistance: reach);
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
void _settle(Float64List p, List<int> triangles, List<List<int>> adjacency, LuminaTriangleGrid body, double thickness, int steps) {
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

/// The largest distance (cm) a vertex of [body] — every sub-mesh — stands
/// in front of the garment surface ([p], [triangles]) along its own
/// normal, counting only body points the garment passes within
/// [LuminaGarmentFitter.coverReach] of.
double _pokeThrough(Float64List p, List<int> triangles, LuminaSkinnedMeshData body) {
  if (triangles.isEmpty) return 0;
  final grid = LuminaTriangleGrid(p, triangles);
  var worst = 0.0;
  final b = body.positions, nb = body.normals;
  for (var v = 0; v < body.vertexCount; v++) {
    final hit = grid.closest(b[v * 3], b[v * 3 + 1], b[v * 3 + 2], maxDistance: LuminaGarmentFitter.coverReach);
    if (hit == null) continue;
    final s = (hit.x - b[v * 3]) * nb[v * 3] + (hit.y - b[v * 3 + 1]) * nb[v * 3 + 1] + (hit.z - b[v * 3 + 2]) * nb[v * 3 + 2];
    // Only where the garment lies over the point, not beside it.
    if (hit.distance > 1e-9 && s.abs() < hit.distance * 0.7) continue;
    if (s < 0) worst = math.max(worst, -s);
  }
  return worst;
}

/// Lifts the garment over every body point (all sub-meshes) that stands
/// in front of it — or closer than [thickness] behind it — where it covers
/// the point: the triangle over the point moves out along the point's
/// normal by what is missing, its corners by their barycentric share, the
/// lift then spread to their neighbours. Returns how many vertices moved.
int _coverBody(Float64List p, List<int> triangles, List<List<int>> adjacency, LuminaSkinnedMeshData body, double thickness) {
  if (triangles.isEmpty) return 0;
  final n = p.length ~/ 3;
  final grid = LuminaTriangleGrid(p, triangles);
  final lift = Float64List(n * 3);
  final amount = Float64List(n);
  final b = body.positions, nb = body.normals;
  // Only the body points within reach of the garment's bounds.
  final lo = [double.infinity, double.infinity, double.infinity], hi = [-double.infinity, -double.infinity, -double.infinity];
  for (var i = 0; i + 2 < p.length; i += 3) {
    for (var k = 0; k < 3; k++) {
      lo[k] = math.min(lo[k], p[i + k] - LuminaGarmentFitter.coverReach);
      hi[k] = math.max(hi[k], p[i + k] + LuminaGarmentFitter.coverReach);
    }
  }
  for (var v = 0; v < body.vertexCount; v++) {
    final x = b[v * 3], y = b[v * 3 + 1], z = b[v * 3 + 2];
    if (x < lo[0] || x > hi[0] || y < lo[1] || y > hi[1] || z < lo[2] || z > hi[2]) continue;
    final hit = grid.closest(x, y, z, maxDistance: LuminaGarmentFitter.coverReach);
    if (hit == null) continue;
    final nx = nb[v * 3], ny = nb[v * 3 + 1], nz = nb[v * 3 + 2];
    final s = (hit.x - b[v * 3]) * nx + (hit.y - b[v * 3 + 1]) * ny + (hit.z - b[v * 3 + 2]) * nz;
    if (hit.distance > 1e-9 && s.abs() < hit.distance * 0.7) continue; // beside, not over
    final need = thickness - s;
    if (need <= 1e-3) continue;
    final t = hit.triangle * 3;
    for (final (corner, share) in [(triangles[t], hit.u), (triangles[t + 1], hit.v), (triangles[t + 2], hit.w)]) {
      // The whole triangle over the point rises, a far corner less.
      final want = share > 0.15 ? need : need * share / 0.15;
      if (want <= amount[corner]) continue;
      amount[corner] = want;
      lift[corner * 3] = nx * want;
      lift[corner * 3 + 1] = ny * want;
      lift[corner * 3 + 2] = nz * want;
    }
  }
  var moved = 0;
  for (var v = 0; v < n; v++) {
    if (amount[v] > 0) moved++;
  }
  if (moved == 0) return 0;
  // Spread a little so the lift makes a smooth bump, keeping each vertex's
  // own lift at least.
  final spread = Float64List.fromList(lift);
  _smooth(spread, adjacency, 1);
  for (var v = 0; v < n; v++) {
    for (var k = 0; k < 3; k++) {
      final own = lift[v * 3 + k], soft = spread[v * 3 + k];
      p[v * 3 + k] += own.abs() >= soft.abs() ? own : soft;
    }
  }
  return moved;
}


/// Neighbours of every vertex (vertices at the same position welded).
List<List<int>> _adjacency(int n, List<int> triangles, List<double> positions) {
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
void _smooth(Float64List field, List<List<int>> adjacency, int iterations) {
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
