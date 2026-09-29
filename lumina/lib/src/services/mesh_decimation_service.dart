import 'dart:typed_data';
import 'dart:math' as math;

class DecimatedMeshData {
  final Float32List positions;
  final Uint32List indices;
  final int triangleCount;
  final int vertexCount;

  const DecimatedMeshData({
    required this.positions,
    required this.indices,
    required this.triangleCount,
    required this.vertexCount,
  });
}

class MeshDecimationService {
  /// Deterministic vertex-clustering mesh decimation.
  /// [positions] is 3 floats per vertex (x, y, z).
  /// [indices] is 3 integers per triangle.
  /// [targetRatio] is the fraction of triangles desired (e.g. 0.5 for ~50%, 1.0 for no reduction).
  static DecimatedMeshData decimate({
    required Float32List positions,
    required List<int> indices,
    required double targetRatio,
    String algorithmVersion = 'vc1',
  }) {
    final clampedRatio = targetRatio.clamp(0.01, 1.0);
    final totalVertices = positions.length ~/ 3;
    final totalTriangles = indices.length ~/ 3;

    // Fast path: 1.0 ratio -> return unchanged copy
    if (clampedRatio >= 0.999 || totalTriangles <= 4 || totalVertices <= 4) {
      final outIndices = Uint32List.fromList(indices);
      final outPositions = Float32List.fromList(positions);
      return DecimatedMeshData(
        positions: outPositions,
        indices: outIndices,
        triangleCount: totalTriangles,
        vertexCount: totalVertices,
      );
    }

    // 1. Calculate AABB
    double minX = positions[0], maxX = positions[0];
    double minY = positions[1], maxY = positions[1];
    double minZ = positions[2], maxZ = positions[2];

    for (int i = 0; i < totalVertices; i++) {
      final x = positions[i * 3];
      final y = positions[i * 3 + 1];
      final z = positions[i * 3 + 2];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }

    final extentX = (maxX - minX).abs().clamp(1e-6, double.infinity);
    final extentY = (maxY - minY).abs().clamp(1e-6, double.infinity);
    final extentZ = (maxZ - minZ).abs().clamp(1e-6, double.infinity);
    final maxExtent = math.max(extentX, math.max(extentY, extentZ));

    // 2. Determine grid resolution based on target ratio
    // Use target cluster count proportional to targetRatio * totalVertices
    final targetClusters = math.max(4, (totalVertices * clampedRatio).round());
    final gridDivisions = math.max(2, (math.pow(targetClusters.toDouble(), 1.0 / 3.0) * 1.5).round()).clamp(2, 256);
    final cellSize = maxExtent / gridDivisions;

    // 3. Cluster vertices
    final Map<int, List<int>> clusterToOriginalVertices = {};
    final List<int> vertexToClusterId = List<int>.filled(totalVertices, 0);

    for (int i = 0; i < totalVertices; i++) {
      final x = positions[i * 3];
      final y = positions[i * 3 + 1];
      final z = positions[i * 3 + 2];

      final gx = ((x - minX) / cellSize).floor().clamp(0, gridDivisions - 1);
      final gy = ((y - minY) / cellSize).floor().clamp(0, gridDivisions - 1);
      final gz = ((z - minZ) / cellSize).floor().clamp(0, gridDivisions - 1);

      // Deterministic 1D hash
      final clusterHash = gx + gy * gridDivisions + gz * gridDivisions * gridDivisions;
      vertexToClusterId[i] = clusterHash;
      (clusterToOriginalVertices[clusterHash] ??= []).add(i);
    }

    // 4. Create new representative vertices per cluster
    // Sort cluster keys for strictly deterministic ordering
    final sortedClusterKeys = clusterToOriginalVertices.keys.toList()..sort();
    final Map<int, int> clusterKeyToNewVertexIndex = {};
    final List<double> newPositionsList = [];

    for (int newIndex = 0; newIndex < sortedClusterKeys.length; newIndex++) {
      final clusterKey = sortedClusterKeys[newIndex];
      clusterKeyToNewVertexIndex[clusterKey] = newIndex;

      final vertIndices = clusterToOriginalVertices[clusterKey]!;
      double sumX = 0, sumY = 0, sumZ = 0;
      for (final vIdx in vertIndices) {
        sumX += positions[vIdx * 3];
        sumY += positions[vIdx * 3 + 1];
        sumZ += positions[vIdx * 3 + 2];
      }
      final count = vertIndices.length;
      newPositionsList.add(sumX / count);
      newPositionsList.add(sumY / count);
      newPositionsList.add(sumZ / count);
    }

    // 5. Re-index triangles and discard degenerate (zero-area or collapsed) triangles
    final List<int> newIndicesList = [];
    final Set<String> seenTriangles = {}; // Prevent duplicate triangles

    for (int t = 0; t < totalTriangles; t++) {
      final i0 = indices[t * 3];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      final c0 = vertexToClusterId[i0];
      final c1 = vertexToClusterId[i1];
      final c2 = vertexToClusterId[i2];

      final n0 = clusterKeyToNewVertexIndex[c0]!;
      final n1 = clusterKeyToNewVertexIndex[c1]!;
      final n2 = clusterKeyToNewVertexIndex[c2]!;

      // Skip collapsed triangles
      if (n0 == n1 || n1 == n2 || n0 == n2) continue;

      // Ensure triangle is not a duplicate
      final minIdx = math.min(n0, math.min(n1, n2));
      String triKey;
      if (minIdx == n0) {
        triKey = '$n0,$n1,$n2';
      } else if (minIdx == n1) {
        triKey = '$n1,$n2,$n0';
      } else {
        triKey = '$n2,$n0,$n1';
      }

      if (!seenTriangles.contains(triKey)) {
        seenTriangles.add(triKey);
        newIndicesList.add(n0);
        newIndicesList.add(n1);
        newIndicesList.add(n2);
      }
    }

    // Fallback: If decimation eliminated all triangles, return input
    if (newIndicesList.isEmpty) {
      return DecimatedMeshData(
        positions: Float32List.fromList(positions),
        indices: Uint32List.fromList(indices),
        triangleCount: totalTriangles,
        vertexCount: totalVertices,
      );
    }

    return DecimatedMeshData(
      positions: Float32List.fromList(newPositionsList),
      indices: Uint32List.fromList(newIndicesList),
      triangleCount: newIndicesList.length ~/ 3,
      vertexCount: newPositionsList.length ~/ 3,
    );
  }
}
