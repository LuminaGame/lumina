import 'dart:typed_data';

import 'package:lumina_core/src/garment/skinned_mesh_data.dart';
import 'package:lumina_core/src/garment/triangle_grid.dart';
import 'package:lumina_core/src/services/glb_animation_merger.dart' show GlbDocument;

/// The body triangles a set of garments covers, so the body under a
/// garment can be left out of the draw (it would poke through the garment
/// as the character moves).
///
/// A body vertex is covered when a garment surface lies within
/// [coverDistance] of it on its outside (the garment point is not behind
/// the skin by more than [insideTolerance]) and that garment point is at
/// least [edgeMargin] from the garment's open edges (so the skin near a
/// collar, cuff or hem stays drawn and no gap shows). A triangle is covered
/// when its three vertices are. Units are centimetres.
abstract final class LuminaBodyMask {
  /// Covered body triangles (indices into [body]'s triangles), for the
  /// garments in [garments] posed on [body] at rest.
  static Uint8List compute(
    LuminaSkinnedMeshData body,
    List<LuminaSkinnedMeshData> garments, {
    double coverDistance = 4,
    double insideTolerance = 2,
    double edgeMargin = 3,
  }) {
    final covered = Uint8List(body.vertexCount);
    for (final garment in garments) {
      if (garment.triangleCount == 0) continue;
      final grid = LuminaTriangleGrid(garment.positions, garment.triangles);
      final nearEdge = _nearOpenEdges(garment, edgeMargin);
      final p = body.positions, n = body.normals;
      for (var v = 0; v < body.vertexCount; v++) {
        if (covered[v] == 1) continue;
        final x = p[v * 3], y = p[v * 3 + 1], z = p[v * 3 + 2];
        final hit = grid.closest(x, y, z, maxDistance: coverDistance);
        if (hit == null) continue;
        final outside = (hit.x - x) * n[v * 3] + (hit.y - y) * n[v * 3 + 1] + (hit.z - z) * n[v * 3 + 2];
        if (outside < -insideTolerance) continue;
        final t = hit.triangle * 3;
        // The garment point's nearest corner decides the edge margin.
        final corner = hit.u >= hit.v && hit.u >= hit.w
            ? garment.triangles[t]
            : (hit.v >= hit.w ? garment.triangles[t + 1] : garment.triangles[t + 2]);
        if (nearEdge[corner] == 1) continue;
        covered[v] = 1;
      }
    }
    final out = Uint8List(body.triangleCount);
    final tri = body.triangles;
    for (var t = 0; t < out.length; t++) {
      if (covered[tri[t * 3]] == 1 && covered[tri[t * 3 + 1]] == 1 && covered[tri[t * 3 + 2]] == 1) out[t] = 1;
    }
    return out;
  }

  /// 1 for every garment vertex within [margin] of an open edge (an edge
  /// used by one triangle, welding vertices at the same position).
  static Uint8List _nearOpenEdges(LuminaSkinnedMeshData g, double margin) {
    final weld = _weld(g.positions);
    final edges = <int, int>{};
    final tri = g.triangles;
    int key(int a, int b) => a < b ? a * 0x100000 + b : b * 0x100000 + a;
    for (var t = 0; t < g.triangleCount; t++) {
      for (var k = 0; k < 3; k++) {
        final a = weld[tri[t * 3 + k]], b = weld[tri[t * 3 + (k + 1) % 3]];
        if (a == b) continue;
        edges.update(key(a, b), (c) => c + 1, ifAbsent: () => 1);
      }
    }
    final boundary = <double>[];
    for (final e in edges.entries) {
      if (e.value != 1) continue;
      for (final v in [e.key ~/ 0x100000, e.key % 0x100000]) {
        boundary.addAll([g.positions[v * 3], g.positions[v * 3 + 1], g.positions[v * 3 + 2]]);
      }
    }
    final out = Uint8List(g.vertexCount);
    if (boundary.isEmpty) return out;
    // Boundary points as degenerate triangles: a closest-point grid.
    final points = Float64List.fromList(boundary);
    final idx = Uint32List(points.length ~/ 3 * 3);
    for (var i = 0; i < points.length ~/ 3; i++) {
      idx[i * 3] = idx[i * 3 + 1] = idx[i * 3 + 2] = i;
    }
    final grid = LuminaTriangleGrid(points, idx, cellSize: margin);
    for (var v = 0; v < g.vertexCount; v++) {
      if (grid.closest(g.positions[v * 3], g.positions[v * 3 + 1], g.positions[v * 3 + 2], maxDistance: margin) != null) {
        out[v] = 1;
      }
    }
    return out;
  }

  /// The first vertex at each position (within 1e-4 cm).
  static Int32List _weld(Float64List p) {
    final n = p.length ~/ 3;
    final out = Int32List(n);
    final seen = <String, int>{};
    for (var v = 0; v < n; v++) {
      final k = '${(p[v * 3] * 1e4).round()},${(p[v * 3 + 1] * 1e4).round()},${(p[v * 3 + 2] * 1e4).round()}';
      out[v] = seen.putIfAbsent(k, () => v);
    }
    return out;
  }

  /// [body]'s GLB with every [covered] triangle made degenerate (its three
  /// indices set to its first, so it is not drawn). The GLB keeps its
  /// layout; a primitive without an index accessor (Draco) stays whole.
  static Uint8List applyDegenerate(LuminaSkinnedMeshData body, Uint8List covered) {
    final doc = body.document;
    final bin = Uint8List.fromList(doc.bin);
    final data = ByteData.sublistView(bin);
    final accessors = (doc.json['accessors'] as List).cast<Map<String, dynamic>>();
    final views = (doc.json['bufferViews'] as List).cast<Map<String, dynamic>>();
    for (final prim in body.primitives) {
      final ai = prim.indexAccessor;
      if (ai == null) continue;
      final a = accessors[ai];
      final view = views[(a['bufferView'] as num).toInt()];
      final type = (a['componentType'] as num).toInt();
      final size = switch (type) { 5125 => 4, 5123 => 2, _ => 1 };
      final base = (view['byteOffset'] as num? ?? 0).toInt() + (a['byteOffset'] as num? ?? 0).toInt();
      for (var t = 0; t < prim.triangleCount; t++) {
        if (covered[prim.firstTriangle + t] != 1) continue;
        final o = base + t * 3 * size;
        switch (size) {
          case 4:
            final first = data.getUint32(o, Endian.little);
            data
              ..setUint32(o + 4, first, Endian.little)
              ..setUint32(o + 8, first, Endian.little);
          case 2:
            final first = data.getUint16(o, Endian.little);
            data
              ..setUint16(o + 2, first, Endian.little)
              ..setUint16(o + 4, first, Endian.little);
          default:
            bin[o + 1] = bin[o];
            bin[o + 2] = bin[o];
        }
      }
    }
    return GlbDocument(doc.json, bin).encode();
  }
}
