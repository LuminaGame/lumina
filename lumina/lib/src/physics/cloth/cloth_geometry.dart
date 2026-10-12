import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Which vertices of a cloth are pinned in place (they follow the cloth
/// component, and whatever it is attached to, instead of falling).
enum LuminaClothPinning {
  none,
  topEdge,
  bottomEdge,
  leftEdge,
  rightEdge,
  topCorners;

  /// Parses an enum name; null when unknown.
  static LuminaClothPinning? parse(Object? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

/// A cloth's mesh in the component's local frame (cm, runtime axes): the
/// render vertices with normals and UVs, and the welded simulation vertices
/// the soft body uses. A mesh asset splits vertices along UV seams; the
/// simulation joins vertices at the same position so the cloth holds
/// together, and [renderToSim] maps each render vertex back.
class LuminaClothGeometry {
  LuminaClothGeometry({
    required this.renderPositions,
    required this.renderNormals,
    required this.renderUvs,
    required this.renderIndices,
    required this.renderToSim,
    required this.simPositions,
    required this.simTriangles,
  });

  final Float32List renderPositions;
  final Float32List renderNormals;
  final Float32List renderUvs;
  final Uint32List renderIndices;
  final Uint32List renderToSim;
  final Float32List simPositions;
  final Uint32List simTriangles;

  int get renderVertexCount => renderPositions.length ~/ 3;
  int get simVertexCount => simPositions.length ~/ 3;

  Vector3 simVertex(int i) => Vector3(simPositions[3 * i], simPositions[3 * i + 1], simPositions[3 * i + 2]);

  /// Local bounds of the simulation vertices.
  Aabb3 get bounds {
    final lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
    for (var i = 0; i < simVertexCount; i++) {
      final v = simVertex(i);
      Vector3.min(lo, v, lo);
      Vector3.max(hi, v, hi);
    }
    return Aabb3.minMax(lo, hi);
  }

  /// A [width] x [height] cm sheet in the local XY plane, facing +Z, its top
  /// edge centred on the origin (it hangs from where the component is), with
  /// [columns] x [rows] quads.
  factory LuminaClothGeometry.grid({double width = 200, double height = 150, int columns = 24, int rows = 18}) {
    final cx = math.max(1, columns), cy = math.max(1, rows);
    final nx = cx + 1, ny = cy + 1;
    final pos = Float32List(nx * ny * 3);
    final nrm = Float32List(nx * ny * 3);
    final uv = Float32List(nx * ny * 2);
    for (var y = 0; y < ny; y++) {
      for (var x = 0; x < nx; x++) {
        final i = y * nx + x;
        pos[3 * i] = -width / 2 + width * x / cx;
        pos[3 * i + 1] = -height * y / cy;
        pos[3 * i + 2] = 0;
        nrm[3 * i + 2] = 1;
        uv[2 * i] = x / cx;
        uv[2 * i + 1] = y / cy;
      }
    }
    final idx = Uint32List(cx * cy * 6);
    var k = 0;
    for (var y = 0; y < cy; y++) {
      for (var x = 0; x < cx; x++) {
        final i = y * nx + x;
        // Counter-clockwise seen from +Z.
        idx
          ..[k++] = i
          ..[k++] = i + nx
          ..[k++] = i + 1
          ..[k++] = i + 1
          ..[k++] = i + nx
          ..[k++] = i + nx + 1;
      }
    }
    return LuminaClothGeometry(
      renderPositions: pos,
      renderNormals: nrm,
      renderUvs: uv,
      renderIndices: idx,
      renderToSim: Uint32List.fromList([for (var i = 0; i < nx * ny; i++) i]),
      simPositions: Float32List.fromList(pos),
      simTriangles: Uint32List.fromList(idx),
    );
  }

  /// The geometry of a mesh asset ([mesh] from `GlbReader`, glTF metres)
  /// scaled by [unitsPerMetre]: every primitive's triangles, vertices welded
  /// within [weldDistance] cm for the simulation.
  factory LuminaClothGeometry.fromMesh(GlbMeshData mesh, {double unitsPerMetre = 100, double weldDistance = 0.05}) {
    final p = mesh.positions;
    final n = p.length ~/ 3;
    final pos = Float32List(n * 3);
    for (var i = 0; i < n * 3; i++) {
      pos[i] = p[i] * unitsPerMetre;
    }
    final uv = Float32List(n * 2);
    if (mesh.uvs.length >= n * 2) uv.setAll(0, mesh.uvs.take(n * 2));
    final idx = Uint32List.fromList(mesh.indices.isEmpty ? [for (var i = 0; i < n; i++) i] : mesh.indices);
    return LuminaClothGeometry.weld(pos, uv, idx, weldDistance: weldDistance);
  }

  /// Welds [positions] (cm) within [weldDistance] into simulation vertices
  /// and builds face normals for the rest pose.
  factory LuminaClothGeometry.weld(Float32List positions, Float32List uvs, Uint32List indices, {double weldDistance = 0.05}) {
    final n = positions.length ~/ 3;
    final cell = math.max(weldDistance, 1e-4);
    final buckets = <int, List<int>>{};
    final renderToSim = Uint32List(n);
    final sim = <double>[];
    int key(int x, int y, int z) => (x * 73856093) ^ (y * 19349663) ^ (z * 83492791);
    for (var i = 0; i < n; i++) {
      final x = positions[3 * i], y = positions[3 * i + 1], z = positions[3 * i + 2];
      final gx = (x / cell).floor(), gy = (y / cell).floor(), gz = (z / cell).floor();
      var found = -1;
      search:
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (var dz = -1; dz <= 1; dz++) {
            for (final s in buckets[key(gx + dx, gy + dy, gz + dz)] ?? const <int>[]) {
              final ex = sim[3 * s] - x, ey = sim[3 * s + 1] - y, ez = sim[3 * s + 2] - z;
              if (ex * ex + ey * ey + ez * ez <= cell * cell) {
                found = s;
                break search;
              }
            }
          }
        }
      }
      if (found < 0) {
        found = sim.length ~/ 3;
        sim.addAll([x, y, z]);
        (buckets[key(gx, gy, gz)] ??= []).add(found);
      }
      renderToSim[i] = found;
    }
    var tris = <int>[];
    for (var t = 0; t + 2 < indices.length; t += 3) {
      final a = renderToSim[indices[t]], b = renderToSim[indices[t + 1]], c = renderToSim[indices[t + 2]];
      if (a == b || b == c || a == c) continue;
      tris.addAll([a, b, c]);
    }
    // A vertex no simulated triangle uses (only in triangles the weld
    // collapsed, or in none) would fall on its own: draw it with the nearest
    // vertex that is simulated, and leave it out of the simulation.
    final used = List<bool>.filled(sim.length ~/ 3, false);
    for (final i in tris) {
      used[i] = true;
    }
    if (used.contains(false)) {
      final remap = List<int>.filled(used.length, -1);
      final kept = <double>[];
      for (var s = 0; s < used.length; s++) {
        if (!used[s]) continue;
        remap[s] = kept.length ~/ 3;
        kept.addAll([sim[3 * s], sim[3 * s + 1], sim[3 * s + 2]]);
      }
      for (var s = 0; s < used.length; s++) {
        if (used[s] || kept.isEmpty) continue;
        var best = 0, bestD = double.infinity;
        for (var k = 0; k < kept.length ~/ 3; k++) {
          final dx = kept[3 * k] - sim[3 * s], dy = kept[3 * k + 1] - sim[3 * s + 1], dz = kept[3 * k + 2] - sim[3 * s + 2];
          final d = dx * dx + dy * dy + dz * dz;
          if (d < bestD) {
            bestD = d;
            best = k;
          }
        }
        remap[s] = best;
      }
      for (var i = 0; i < n; i++) {
        renderToSim[i] = remap[renderToSim[i]];
      }
      tris = [for (final i in tris) remap[i]];
      sim
        ..clear()
        ..addAll(kept);
    }
    final normals = Float32List(n * 3);
    for (var t = 0; t + 2 < indices.length; t += 3) {
      final i0 = indices[t], i1 = indices[t + 1], i2 = indices[t + 2];
      final a = Vector3(positions[3 * i0], positions[3 * i0 + 1], positions[3 * i0 + 2]);
      final e1 = Vector3(positions[3 * i1], positions[3 * i1 + 1], positions[3 * i1 + 2]) - a;
      final e2 = Vector3(positions[3 * i2], positions[3 * i2 + 1], positions[3 * i2 + 2]) - a;
      final f = e1.cross(e2);
      for (final i in [i0, i1, i2]) {
        normals[3 * i] += f.x;
        normals[3 * i + 1] += f.y;
        normals[3 * i + 2] += f.z;
      }
    }
    for (var i = 0; i < n; i++) {
      final v = Vector3(normals[3 * i], normals[3 * i + 1], normals[3 * i + 2]);
      final l = v.length;
      if (l > 1e-12) v.scale(1 / l);
      normals.setRange(3 * i, 3 * i + 3, l > 1e-12 ? v.storage : [0, 1, 0]);
    }
    return LuminaClothGeometry(
      renderPositions: positions,
      renderNormals: normals,
      renderUvs: uvs,
      renderIndices: indices,
      renderToSim: renderToSim,
      simPositions: Float32List.fromList(sim),
      simTriangles: Uint32List.fromList(tris),
    );
  }

  /// The connected piece of the mesh each simulation vertex belongs to (a
  /// mesh asset may be several unconnected pieces, such as a towel's body
  /// and its folded top).
  late final List<int> islands = _islands();

  List<int> _islands() {
    final parent = List<int>.generate(simVertexCount, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        i = parent[i] = parent[parent[i]];
      }
      return i;
    }

    for (var t = 0; t + 2 < simTriangles.length; t += 3) {
      parent[find(simTriangles[t])] = find(simTriangles[t + 1]);
      parent[find(simTriangles[t + 1])] = find(simTriangles[t + 2]);
    }
    return [for (var i = 0; i < simVertexCount; i++) find(i)];
  }

  /// The simulation vertices [pinning] selects: in every piece of the mesh,
  /// those within [tolerance] cm of the matching extreme of that piece's
  /// bounds (corners: both extremes), so no piece falls away on its own.
  List<int> pinnedBy(LuminaClothPinning pinning, {double tolerance = 0.5}) {
    if (pinning == LuminaClothPinning.none) return const [];
    final boxes = <int, Aabb3>{};
    for (var i = 0; i < simVertexCount; i++) {
      final v = simVertex(i);
      final box = boxes[islands[i]];
      if (box == null) {
        boxes[islands[i]] = Aabb3.minMax(v, v.clone());
      } else {
        box.hullPoint(v);
      }
    }
    final out = <int>[];
    for (var i = 0; i < simVertexCount; i++) {
      final v = simVertex(i);
      final b = boxes[islands[i]]!;
      final top = v.y >= b.max.y - tolerance, bottom = v.y <= b.min.y + tolerance;
      final left = v.x <= b.min.x + tolerance, right = v.x >= b.max.x - tolerance;
      final pinned = switch (pinning) {
        LuminaClothPinning.none => false,
        LuminaClothPinning.topEdge => top,
        LuminaClothPinning.bottomEdge => bottom,
        LuminaClothPinning.leftEdge => left,
        LuminaClothPinning.rightEdge => right,
        LuminaClothPinning.topCorners => top && (left || right),
      };
      if (pinned) out.add(i);
    }
    return out;
  }
}
