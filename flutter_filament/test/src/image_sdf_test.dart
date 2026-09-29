import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('ImageSDF Tests (Task 05)', () {
    test('computeCoordField on single seed pixel', () {
      final mask = LinearImage(16, 16, 1);
      mask.setPixel(5, 5, 0, 1.0);

      final coord = computeCoordField(mask, threshold: 0.5);
      expect(coord.channels, equals(2));

      // Pixel (0, 0) should point to (5, 5)
      expect(coord.getPixel(0, 0, 0), closeTo(5.0, 1e-4));
      expect(coord.getPixel(0, 0, 1), closeTo(5.0, 1e-4));

      // Pixel (10, 10) should also point to (5, 5)
      expect(coord.getPixel(10, 10, 0), closeTo(5.0, 1e-4));
      expect(coord.getPixel(10, 10, 1), closeTo(5.0, 1e-4));

      mask.destroy();
      coord.destroy();
    });

    test('edtFromCoordField yields Euclidean distance', () {
      final mask = LinearImage(16, 16, 1);
      mask.setPixel(5, 5, 0, 1.0);

      final coord = computeCoordField(mask);
      final dist = edtFromCoordField(coord, sqrt: true);

      expect(dist.getPixel(5, 5, 0), closeTo(0.0, 1e-4));
      expect(dist.getPixel(5, 8, 0), closeTo(3.0, 1e-4));
      expect(dist.getPixel(9, 8, 0), closeTo(5.0, 1e-4)); // sqrt((9-5)^2 + (8-5)^2) = sqrt(16+9) = 5

      mask.destroy();
      coord.destroy();
      dist.destroy();
    });

    test('voronoiFromCoordField assigns colors from nearest seeds', () {
      final seeds = LinearImage(8, 8, 3);
      final mask = LinearImage(8, 8, 1);

      // Seed 1: (1, 1) is Pure Red
      seeds.setPixel(1, 1, 0, 1.0);
      mask.setPixel(1, 1, 0, 1.0);

      // Seed 2: (6, 6) is Pure Blue
      seeds.setPixel(6, 6, 2, 1.0);
      mask.setPixel(6, 6, 0, 1.0);

      final coord = computeCoordField(mask);
      final voronoi = voronoiFromCoordField(coord, seeds);

      // (0, 0) is close to (1, 1) -> Red
      expect(voronoi.getPixel(0, 0, 0), equals(1.0));
      expect(voronoi.getPixel(0, 0, 2), equals(0.0));

      // (7, 7) is close to (6, 6) -> Blue
      expect(voronoi.getPixel(7, 7, 0), equals(0.0));
      expect(voronoi.getPixel(7, 7, 2), equals(1.0));

      seeds.destroy();
      mask.destroy();
      coord.destroy();
      voronoi.destroy();
    });

    test('dilateUvIslands propagates island colors to gutters', () {
      final baked = LinearImage(4, 4, 3);
      final coverage = LinearImage(4, 4, 1);

      // Single island pixel at (1, 1)
      baked.setPixel(1, 1, 0, 1.0);
      baked.setPixel(1, 1, 1, 0.5);
      baked.setPixel(1, 1, 2, 0.25);
      coverage.setPixel(1, 1, 0, 1.0);

      final dilated = dilateUvIslands(baked, coverage);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          expect(dilated.getPixel(x, y, 0), equals(1.0));
          expect(dilated.getPixel(x, y, 1), equals(0.5));
          expect(dilated.getPixel(x, y, 2), equals(0.25));
        }
      }

      baked.destroy();
      coverage.destroy();
      dilated.destroy();
    });

    test('signedDistanceField distinguishes inside and outside', () {
      final mask = LinearImage(8, 8, 1);
      // Fill central 4x4 region as inside
      for (var y = 2; y < 6; y++) {
        for (var x = 2; x < 6; x++) {
          mask.setPixel(x, y, 0, 1.0);
        }
      }

      final sdf = signedDistanceField(mask);
      // Center (3, 3) should be negative (inside)
      expect(sdf.getPixel(3, 3, 0), lessThan(0.0));
      // Outer corner (0, 0) should be positive (outside)
      expect(sdf.getPixel(0, 0, 0), greaterThan(0.0));

      mask.destroy();
      sdf.destroy();
    });
  });
}
