import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('ImageSampler Tests (Task 02)', () {
    test('BOX downsample of checkerboard produces 0.5 average', () {
      final src = LinearImage(4, 4, 1);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          src.setPixel(x, y, 0, (x + y) % 2 == 0 ? 1.0 : 0.0);
        }
      }

      final dst = resampleImage(src, 2, 2, filter: ImageFilter.box);
      expect(dst.width, equals(2));
      expect(dst.height, equals(2));
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 2; x++) {
          expect(dst.getPixel(x, y, 0), closeTo(0.5, 1e-5));
        }
      }

      src.destroy();
      dst.destroy();
    });

    test('NEAREST upsample preserves discrete quadrants without blending', () {
      final src = LinearImage(2, 2, 1);
      src.setPixel(0, 0, 0, 1.0);
      src.setPixel(1, 0, 0, 2.0);
      src.setPixel(0, 1, 0, 3.0);
      src.setPixel(1, 1, 0, 4.0);

      final dst = resampleImage(src, 4, 4, filter: ImageFilter.nearest);
      expect(dst.width, equals(4));
      expect(dst.height, equals(4));

      expect(dst.getPixel(0, 0, 0), equals(1.0));
      expect(dst.getPixel(1, 0, 0), equals(1.0));
      expect(dst.getPixel(0, 1, 0), equals(1.0));
      expect(dst.getPixel(1, 1, 0), equals(1.0));

      expect(dst.getPixel(2, 0, 0), equals(2.0));
      expect(dst.getPixel(3, 0, 0), equals(2.0));

      src.destroy();
      dst.destroy();
    });

    test('getMipmapCount contracts', () {
      final img256 = LinearImage(256, 256, 3);
      expect(getMipmapCount(img256), equals(8));
      img256.destroy();

      final img5x3 = LinearImage(5, 3, 3);
      expect(getMipmapCount(img5x3), equals(2));
      img5x3.destroy();
    });

    test('generateMipmaps creates full mip chain down to 1x1', () {
      final src = LinearImage(8, 8, 3);
      for (var i = 0; i < 8 * 8 * 3; i++) {
        src.data[i] = 0.75;
      }

      final mips = generateMipmaps(src, filter: ImageFilter.box);
      expect(mips.length, equals(3)); // 4x4, 2x2, 1x1

      expect(mips[0].width, equals(4));
      expect(mips[0].height, equals(4));

      expect(mips[1].width, equals(2));
      expect(mips[1].height, equals(2));

      expect(mips[2].width, equals(1));
      expect(mips[2].height, equals(1));

      expect(mips[2].getPixel(0, 0, 0), closeTo(0.75, 1e-4));
      expect(mips[2].getPixel(0, 0, 1), closeTo(0.75, 1e-4));
      expect(mips[2].getPixel(0, 0, 2), closeTo(0.75, 1e-4));

      src.destroy();
      for (final m in mips) {
        m.destroy();
      }
    });

    test('GAUSSIAN_NORMALS produces unit-length vectors in mips', () {
      final src = LinearImage(4, 4, 3);
      final n1 = [0.0, 0.0, 1.0];
      final n2 = [1.0 / math.sqrt(2), 0.0, 1.0 / math.sqrt(2)];

      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final n = (x + y) % 2 == 0 ? n1 : n2;
          src.setPixel(x, y, 0, n[0]);
          src.setPixel(x, y, 1, n[1]);
          src.setPixel(x, y, 2, n[2]);
        }
      }

      final normalMip = resampleImage(src, 2, 2, filter: ImageFilter.gaussianNormals);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 2; x++) {
          final vx = normalMip.getPixel(x, y, 0);
          final vy = normalMip.getPixel(x, y, 1);
          final vz = normalMip.getPixel(x, y, 2);
          final len = math.sqrt(vx * vx + vy * vy + vz * vz);
          expect(len, closeTo(1.0, 1e-3));
        }
      }

      src.destroy();
      normalMip.destroy();
    });

    test('MINIMUM filter downsamples to quad minimums', () {
      final src = LinearImage(4, 4, 1);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          src.setPixel(x, y, 0, (y * 4 + x + 1).toDouble());
        }
      }

      final minMip = resampleImage(src, 2, 2, filter: ImageFilter.minimum);
      expect(minMip.getPixel(0, 0, 0), closeTo(1.0, 1e-4));
      expect(minMip.getPixel(1, 0, 0), closeTo(3.0, 1e-4));
      expect(minMip.getPixel(0, 1, 0), closeTo(9.0, 1e-4));
      expect(minMip.getPixel(1, 1, 0), closeTo(11.0, 1e-4));

      src.destroy();
      minMip.destroy();
    });

    test('LANCZOS/MITCHELL filters resample cleanly', () {
      final src = LinearImage(8, 8, 1);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          src.setPixel(x, y, 0, (x / 7.0));
        }
      }

      final dstL = resampleImage(src, 4, 4, filter: ImageFilter.lanczos);
      final dstM = resampleImage(src, 4, 4, filter: ImageFilter.mitchell);

      expect(dstL.width, equals(4));
      expect(dstM.width, equals(4));

      src.destroy();
      dstL.destroy();
      dstM.destroy();
    });
  });
}
