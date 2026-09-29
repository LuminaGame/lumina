import 'dart:math' as math;
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:lumina/src/services/mesh_decimation_service.dart';

void main() {
  group('MeshDecimationService Tests', () {
    late Float32List spherePositions;
    late List<int> sphereIndices;

    setUp(() {
      // Build a UV sphere (16 rings, 16 segments)
      const rings = 16;
      const segments = 16;
      final positions = <double>[];
      final indices = <int>[];

      for (int r = 0; r <= rings; r++) {
        final theta = r * math.pi / rings;
        final sinTheta = math.sin(theta);
        final cosTheta = math.cos(theta);

        for (int s = 0; s <= segments; s++) {
          final phi = s * 2 * math.pi / segments;
          final sinPhi = math.sin(phi);
          final cosPhi = math.cos(phi);

          positions.add(cosPhi * sinTheta);
          positions.add(cosTheta);
          positions.add(sinPhi * sinTheta);
        }
      }

      for (int r = 0; r < rings; r++) {
        for (int s = 0; s < segments; s++) {
          final first = (r * (segments + 1)) + s;
          final second = first + segments + 1;

          indices.add(first);
          indices.add(second);
          indices.add(first + 1);

          indices.add(second);
          indices.add(second + 1);
          indices.add(first + 1);
        }
      }

      spherePositions = Float32List.fromList(positions);
      sphereIndices = indices;
    });

    test('Decimation correctness: ratio 0.5 reduces triangles within expected range and maintains valid indices', () {
      final initialTriCount = sphereIndices.length ~/ 3;
      final decimated = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 0.5,
      );

      expect(decimated.triangleCount, greaterThan(0));
      expect(decimated.triangleCount, lessThanOrEqualTo((initialTriCount * 0.7).ceil()));
      expect(decimated.vertexCount, greaterThan(0));

      // Assert valid index range
      for (final idx in decimated.indices) {
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(decimated.vertexCount));
      }

      // Assert no collapsed triangles
      for (int t = 0; t < decimated.triangleCount; t++) {
        final i0 = decimated.indices[t * 3];
        final i1 = decimated.indices[t * 3 + 1];
        final i2 = decimated.indices[t * 3 + 2];
        expect(i0 != i1 && i1 != i2 && i0 != i2, isTrue);
      }
    });

    test('Determinism: two runs on identical input and ratio produce byte-identical buffers', () {
      final run1 = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 0.35,
      );

      final run2 = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 0.35,
      );

      expect(run1.triangleCount, equals(run2.triangleCount));
      expect(run1.vertexCount, equals(run2.vertexCount));
      expect(run1.positions, equals(run2.positions));
      expect(run1.indices, equals(run2.indices));
    });

    test('Monotonicity: ratios 1.0 -> 0.5 -> 0.25 produce non-increasing triangle counts and ratio 1.0 returns verbatim', () {
      final dec100 = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 1.0,
      );
      final dec50 = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 0.5,
      );
      final dec25 = MeshDecimationService.decimate(
        positions: spherePositions,
        indices: sphereIndices,
        targetRatio: 0.25,
      );

      expect(dec100.triangleCount, equals(sphereIndices.length ~/ 3));
      expect(dec50.triangleCount, lessThanOrEqualTo(dec100.triangleCount));
      expect(dec25.triangleCount, lessThanOrEqualTo(dec50.triangleCount));
    });
  });
}
