import 'dart:math' as math;
import 'dart:typed_data';

import '../views/sub_editor_3d_viewport.dart' show PreviewShape;

/// Procedural preview geometry (unit-scale) used by the Material Editor's 3D
/// preview so a compiled material can be shaded on a real Filament renderable
/// even though a material asset carries no mesh payload.
class PreviewMeshData {
  final Float32List positions; // xyz per vertex
  final Float32List normals; // xyz per vertex, unit length
  final Float32List uv0; // uv per vertex
  final Uint32List indices; // triangle list
  final List<double> minBounds;
  final List<double> maxBounds;

  const PreviewMeshData({
    required this.positions,
    required this.normals,
    required this.uv0,
    required this.indices,
    required this.minBounds,
    required this.maxBounds,
  });

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

class PreviewMeshFactory {
  const PreviewMeshFactory._();

  /// Builds the geometry for [shape]. [PreviewShape.mesh] has no procedural
  /// form and falls back to the sphere.
  static PreviewMeshData build(PreviewShape shape) {
    switch (shape) {
      case PreviewShape.cube:
        return cube();
      case PreviewShape.cylinder:
        return cylinder();
      case PreviewShape.plane:
        return plane();
      case PreviewShape.sphere:
      case PreviewShape.mesh:
        return sphere();
    }
  }

  /// UV sphere of radius [radius] centred at the origin.
  static PreviewMeshData sphere({double radius = 1.0, int stacks = 32, int slices = 48}) {
    final vertexCount = (stacks + 1) * (slices + 1);
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    final uv0 = Float32List(vertexCount * 2);
    var v = 0;
    for (var i = 0; i <= stacks; i++) {
      final phi = math.pi * i / stacks; // 0..pi from +Y pole
      final y = math.cos(phi);
      final r = math.sin(phi);
      for (var j = 0; j <= slices; j++) {
        final theta = 2 * math.pi * j / slices;
        final x = r * math.cos(theta);
        final z = r * math.sin(theta);
        positions[v * 3] = x * radius;
        positions[v * 3 + 1] = y * radius;
        positions[v * 3 + 2] = z * radius;
        normals[v * 3] = x;
        normals[v * 3 + 1] = y;
        normals[v * 3 + 2] = z;
        uv0[v * 2] = j / slices;
        uv0[v * 2 + 1] = i / stacks;
        v++;
      }
    }
    final indices = Uint32List(stacks * slices * 6);
    var k = 0;
    for (var i = 0; i < stacks; i++) {
      for (var j = 0; j < slices; j++) {
        final a = i * (slices + 1) + j;
        final b = a + slices + 1;
        indices[k++] = a;
        indices[k++] = b;
        indices[k++] = a + 1;
        indices[k++] = a + 1;
        indices[k++] = b;
        indices[k++] = b + 1;
      }
    }
    return PreviewMeshData(
      positions: positions,
      normals: normals,
      uv0: uv0,
      indices: indices,
      minBounds: [-radius, -radius, -radius],
      maxBounds: [radius, radius, radius],
    );
  }

  /// Axis-aligned cube with per-face normals (24 vertices, 12 triangles).
  static PreviewMeshData cube({double halfExtent = 0.85}) {
    const faceNormals = [
      [1.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0], [0.0, -1.0, 0.0],
      [0.0, 0.0, 1.0], [0.0, 0.0, -1.0],
    ];
    const faceTangents = [
      [0.0, 0.0, -1.0], [0.0, 0.0, 1.0],
      [1.0, 0.0, 0.0], [1.0, 0.0, 0.0],
      [1.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
    ];
    final positions = Float32List(24 * 3);
    final normals = Float32List(24 * 3);
    final uv0 = Float32List(24 * 2);
    final indices = Uint32List(36);
    var v = 0;
    var k = 0;
    for (var f = 0; f < 6; f++) {
      final n = faceNormals[f];
      final t = faceTangents[f];
      // bitangent = n x t
      final b = [
        n[1] * t[2] - n[2] * t[1],
        n[2] * t[0] - n[0] * t[2],
        n[0] * t[1] - n[1] * t[0],
      ];
      const corners = [
        [-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0],
      ];
      final base = v;
      for (final c in corners) {
        for (var a = 0; a < 3; a++) {
          positions[v * 3 + a] = (n[a] + t[a] * c[0] + b[a] * c[1]) * halfExtent;
          normals[v * 3 + a] = n[a];
        }
        uv0[v * 2] = (c[0] + 1) * 0.5;
        uv0[v * 2 + 1] = (c[1] + 1) * 0.5;
        v++;
      }
      indices[k++] = base;
      indices[k++] = base + 1;
      indices[k++] = base + 2;
      indices[k++] = base;
      indices[k++] = base + 2;
      indices[k++] = base + 3;
    }
    return PreviewMeshData(
      positions: positions,
      normals: normals,
      uv0: uv0,
      indices: indices,
      minBounds: [-halfExtent, -halfExtent, -halfExtent],
      maxBounds: [halfExtent, halfExtent, halfExtent],
    );
  }

  /// Capped cylinder along +Y.
  static PreviewMeshData cylinder({double radius = 0.7, double height = 1.7, int slices = 48}) {
    final half = height / 2;
    // side: (slices+1) * 2 vertices; caps: 2 centres + 2*(slices+1) rims
    final sideVerts = (slices + 1) * 2;
    final capVerts = 2 + (slices + 1) * 2;
    final vertexCount = sideVerts + capVerts;
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    final uv0 = Float32List(vertexCount * 2);
    final indices = <int>[];
    var v = 0;
    void put(double x, double y, double z, double nx, double ny, double nz, double u, double w) {
      positions[v * 3] = x;
      positions[v * 3 + 1] = y;
      positions[v * 3 + 2] = z;
      normals[v * 3] = nx;
      normals[v * 3 + 1] = ny;
      normals[v * 3 + 2] = nz;
      uv0[v * 2] = u;
      uv0[v * 2 + 1] = w;
      v++;
    }

    // Side
    for (var j = 0; j <= slices; j++) {
      final theta = 2 * math.pi * j / slices;
      final cx = math.cos(theta);
      final cz = math.sin(theta);
      put(cx * radius, -half, cz * radius, cx, 0, cz, j / slices, 0);
      put(cx * radius, half, cz * radius, cx, 0, cz, j / slices, 1);
    }
    for (var j = 0; j < slices; j++) {
      final a = j * 2;
      indices.addAll([a, a + 1, a + 2, a + 2, a + 1, a + 3]);
    }
    // Top cap
    final topCentre = v;
    put(0, half, 0, 0, 1, 0, 0.5, 0.5);
    for (var j = 0; j <= slices; j++) {
      final theta = 2 * math.pi * j / slices;
      final cx = math.cos(theta);
      final cz = math.sin(theta);
      put(cx * radius, half, cz * radius, 0, 1, 0, 0.5 + cx * 0.5, 0.5 + cz * 0.5);
    }
    for (var j = 0; j < slices; j++) {
      indices.addAll([topCentre, topCentre + 1 + j + 1, topCentre + 1 + j]);
    }
    // Bottom cap
    final bottomCentre = v;
    put(0, -half, 0, 0, -1, 0, 0.5, 0.5);
    for (var j = 0; j <= slices; j++) {
      final theta = 2 * math.pi * j / slices;
      final cx = math.cos(theta);
      final cz = math.sin(theta);
      put(cx * radius, -half, cz * radius, 0, -1, 0, 0.5 + cx * 0.5, 0.5 + cz * 0.5);
    }
    for (var j = 0; j < slices; j++) {
      indices.addAll([bottomCentre, bottomCentre + 1 + j, bottomCentre + 1 + j + 1]);
    }
    return PreviewMeshData(
      positions: positions,
      normals: normals,
      uv0: uv0,
      indices: Uint32List.fromList(indices),
      minBounds: [-radius, -half, -radius],
      maxBounds: [radius, half, radius],
    );
  }

  /// Square plane in the XZ plane facing +Y (double-sided materials render
  /// both faces; single-sided ones show the top).
  static PreviewMeshData plane({double halfExtent = 1.2}) {
    final positions = Float32List.fromList([
      -halfExtent, 0, -halfExtent,
      halfExtent, 0, -halfExtent,
      halfExtent, 0, halfExtent,
      -halfExtent, 0, halfExtent,
    ]);
    final normals = Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]);
    final uv0 = Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]);
    final indices = Uint32List.fromList([0, 2, 1, 0, 3, 2]);
    return PreviewMeshData(
      positions: positions,
      normals: normals,
      uv0: uv0,
      indices: indices,
      minBounds: [-halfExtent, -0.001, -halfExtent],
      maxBounds: [halfExtent, 0.001, halfExtent],
    );
  }
}
