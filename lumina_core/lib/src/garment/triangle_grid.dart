import 'dart:math' as math;
import 'dart:typed_data';

/// The nearest surface point a [LuminaTriangleGrid] found: the triangle,
/// the point, its barycentric weights (of the triangle's three vertices),
/// the distance and the triangle's unit normal.
class LuminaSurfacePoint {
  LuminaSurfacePoint(this.triangle, this.x, this.y, this.z, this.u, this.v, this.w, this.distance, this.nx, this.ny, this.nz);

  final int triangle;
  final double x, y, z;
  final double u, v, w;
  final double distance;
  final double nx, ny, nz;
}

/// Closest-point queries against a triangle mesh: triangles bucketed into a
/// uniform grid of [cellSize] (same units as the positions), searched in
/// growing shells of cells around the query point.
class LuminaTriangleGrid {
  LuminaTriangleGrid(this.positions, this.triangles, {double? cellSize}) {
    final n = triangles.length ~/ 3;
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    var edge = 0.0;
    for (var t = 0; t < n; t++) {
      for (var k = 0; k < 3; k++) {
        final i = triangles[t * 3 + k] * 3;
        minX = math.min(minX, positions[i]);
        minY = math.min(minY, positions[i + 1]);
        minZ = math.min(minZ, positions[i + 2]);
        maxX = math.max(maxX, positions[i]);
        maxY = math.max(maxY, positions[i + 1]);
        maxZ = math.max(maxZ, positions[i + 2]);
      }
      final a = triangles[t * 3] * 3, b = triangles[t * 3 + 1] * 3;
      edge += _dist(positions[a], positions[a + 1], positions[a + 2], positions[b], positions[b + 1], positions[b + 2]);
    }
    if (n == 0) {
      minX = minY = minZ = 0;
      maxX = maxY = maxZ = 1;
    }
    cell = cellSize ?? math.max(edge / math.max(n, 1) * 2, 1e-3);
    ox = minX;
    oy = minY;
    oz = minZ;
    nx = math.max(1, ((maxX - minX) / cell).ceil() + 1);
    ny = math.max(1, ((maxY - minY) / cell).ceil() + 1);
    nz = math.max(1, ((maxZ - minZ) / cell).ceil() + 1);
    final buckets = <int, List<int>>{};
    for (var t = 0; t < n; t++) {
      var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
      var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
      for (var k = 0; k < 3; k++) {
        final i = triangles[t * 3 + k] * 3;
        x0 = math.min(x0, positions[i]);
        y0 = math.min(y0, positions[i + 1]);
        z0 = math.min(z0, positions[i + 2]);
        x1 = math.max(x1, positions[i]);
        y1 = math.max(y1, positions[i + 1]);
        z1 = math.max(z1, positions[i + 2]);
      }
      for (var cx = _c(x0, ox); cx <= _c(x1, ox); cx++) {
        for (var cy = _c(y0, oy); cy <= _c(y1, oy); cy++) {
          for (var cz = _c(z0, oz); cz <= _c(z1, oz); cz++) {
            (buckets[_key(cx, cy, cz)] ??= <int>[]).add(t);
          }
        }
      }
    }
    _cells = {for (final e in buckets.entries) e.key: Int32List.fromList(e.value)};
    _stamp = Int32List(n);
  }

  final List<double> positions;
  final List<int> triangles;
  late final double cell, ox, oy, oz;
  late final int nx, ny, nz;
  late final Map<int, Int32List> _cells;
  late final Int32List _stamp;
  int _query = 0;

  int _c(double v, double o) => ((v - o) / cell).floor();
  int _key(int x, int y, int z) => (x * ny + y) * nz + z;

  /// The nearest point of the mesh to (x, y, z) within [maxDistance], or
  /// null when none is that close.
  LuminaSurfacePoint? closest(double x, double y, double z, {double maxDistance = double.infinity}) {
    _query++;
    final cx = _c(x, ox), cy = _c(y, oy), cz = _c(z, oz);
    final maxShell = maxDistance.isFinite ? (maxDistance / cell).ceil() + 1 : math.max(nx, math.max(ny, nz));
    LuminaSurfacePoint? best;
    var bestD = maxDistance;
    for (var r = 0; r <= maxShell; r++) {
      // Every point within the shells searched so far is (r - 1) cells away.
      if (best != null && (r - 1) * cell > bestD) break;
      for (var ix = cx - r; ix <= cx + r; ix++) {
        if (ix < 0 || ix >= nx) continue;
        for (var iy = cy - r; iy <= cy + r; iy++) {
          if (iy < 0 || iy >= ny) continue;
          for (var iz = cz - r; iz <= cz + r; iz++) {
            if (iz < 0 || iz >= nz) continue;
            if ((ix - cx).abs() != r && (iy - cy).abs() != r && (iz - cz).abs() != r) continue;
            final list = _cells[_key(ix, iy, iz)];
            if (list == null) continue;
            for (final t in list) {
              if (_stamp[t] == _query) continue;
              _stamp[t] = _query;
              final p = _closestOnTriangle(t, x, y, z);
              if (p.distance < bestD) {
                bestD = p.distance;
                best = p;
              }
            }
          }
        }
      }
    }
    return best;
  }

  LuminaSurfacePoint _closestOnTriangle(int t, double px, double py, double pz) {
    final a = triangles[t * 3] * 3, b = triangles[t * 3 + 1] * 3, c = triangles[t * 3 + 2] * 3;
    final ax = positions[a], ay = positions[a + 1], az = positions[a + 2];
    final bx = positions[b], by = positions[b + 1], bz = positions[b + 2];
    final cx = positions[c], cy = positions[c + 1], cz = positions[c + 2];
    final abx = bx - ax, aby = by - ay, abz = bz - az;
    final acx = cx - ax, acy = cy - ay, acz = cz - az;
    var nnx = aby * acz - abz * acy, nny = abz * acx - abx * acz, nnz = abx * acy - aby * acx;
    final nl = math.sqrt(nnx * nnx + nny * nny + nnz * nnz);
    if (nl > 1e-12) {
      nnx /= nl;
      nny /= nl;
      nnz /= nl;
    }
    final apx = px - ax, apy = py - ay, apz = pz - az;
    final d1 = abx * apx + aby * apy + abz * apz, d2 = acx * apx + acy * apy + acz * apz;
    double u, v, w;
    if (d1 <= 0 && d2 <= 0) {
      (u, v, w) = (1, 0, 0);
    } else {
      final bpx = px - bx, bpy = py - by, bpz = pz - bz;
      final d3 = abx * bpx + aby * bpy + abz * bpz, d4 = acx * bpx + acy * bpy + acz * bpz;
      final cpx = px - cx, cpy = py - cy, cpz = pz - cz;
      final d5 = abx * cpx + aby * cpy + abz * cpz, d6 = acx * cpx + acy * cpy + acz * cpz;
      final vc = d1 * d4 - d3 * d2, vb = d5 * d2 - d1 * d6, va = d3 * d6 - d5 * d4;
      if (d3 >= 0 && d4 <= d3) {
        (u, v, w) = (0, 1, 0);
      } else if (d6 >= 0 && d5 <= d6) {
        (u, v, w) = (0, 0, 1);
      } else if (vc <= 0 && d1 >= 0 && d3 <= 0) {
        final s = d1 / (d1 - d3);
        (u, v, w) = (1 - s, s, 0);
      } else if (vb <= 0 && d2 >= 0 && d6 <= 0) {
        final s = d2 / (d2 - d6);
        (u, v, w) = (1 - s, 0, s);
      } else if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
        final s = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        (u, v, w) = (0, 1 - s, s);
      } else {
        final denom = 1 / (va + vb + vc);
        final vv = vb * denom, ww = vc * denom;
        (u, v, w) = (1 - vv - ww, vv, ww);
      }
    }
    final qx = u * ax + v * bx + w * cx, qy = u * ay + v * by + w * cy, qz = u * az + v * bz + w * cz;
    return LuminaSurfacePoint(t, qx, qy, qz, u, v, w, _dist(px, py, pz, qx, qy, qz), nnx, nny, nnz);
  }

  static double _dist(double ax, double ay, double az, double bx, double by, double bz) {
    final dx = ax - bx, dy = ay - by, dz = az - bz;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
