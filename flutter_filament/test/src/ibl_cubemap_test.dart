import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('face image stride', () {
    test('per-face reads of a hemisphere-split environment respect the cross row stride', () {
      // Left longitude half bright, right half dark.
      final img = IblImage(64, 32);
      final d = img.data;
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 64; x++) {
          final v = x < 32 ? 4.0 : 0.05;
          final i = (y * 64 + x) * 3;
          d[i] = v;
          d[i + 1] = v;
          d[i + 2] = v;
        }
      }
      final cube = IblCubemap(16);
      CubemapUtils.equirectangularToCubemap(cube, img);

      double meanOf(Float32List f) {
        var sum = 0.0;
        for (var i = 0; i < f.length; i++) {
          sum += f[i];
        }
        return sum / f.length;
      }
      final means = <IblCubemapFace, double>{};
      final linearMeans = <IblCubemapFace, double>{};
      for (final face in IblCubemapFace.values) {
        final fi = cube.faceImage(face);
        expect(fi.width, 16);
        expect(fi.height, 16);
        expect(fi.data.length, 16 * 16 * 3);
        means[face] = meanOf(fi.data);
        final lin = fi.toLinearImage();
        expect(lin.width, 16);
        linearMeans[face] = meanOf(lin.data);
        lin.destroy();
      }
      final bright = [means[IblCubemapFace.px]!, means[IblCubemapFace.nx]!]..sort();
      expect(bright[1], greaterThan(bright[0] * 5), reason: 'one of ±X faces looks at the bright hemisphere: $means');
      final brightLin = [linearMeans[IblCubemapFace.px]!, linearMeans[IblCubemapFace.nx]!]..sort();
      expect(brightLin[1], greaterThan(brightLin[0] * 5), reason: 'toLinearImage must copy rows with the stride: $linearMeans');
      // ±Z faces straddle the split: roughly half bright.
      expect(means[IblCubemapFace.pz]!, closeTo(means[IblCubemapFace.nz]!, 0.6));
      cube.destroy();
      img.destroy();
    });
  });

  group('repeated face reads', () {
    test('256x128 equirect -> 64px cubemap, faces read over many iterations', () {
      // Each `faceImage()` hands back a short-lived wrapper carrying a
      // NativeFinalizer. Enough iterations force the collector to run those
      // finalizers off the mutator thread, which aborted the VM while the
      // finalizer was a `Pointer.fromFunction` trampoline into Dart.
      for (var rep = 0; rep < 20; rep++) {
        final img = IblImage(256, 128);
        for (var y = 0; y < 128; y++) {
          for (var x = 0; x < 256; x++) {
            img.setPixel(x, y, x / 256.0, y / 128.0, 0.5);
          }
        }
        final cube = IblCubemap(64);
        CubemapUtils.equirectangularToCubemap(cube, img);
        for (final face in IblCubemapFace.values) {
          final data = cube.faceImage(face).data;
          expect(data.length, 64 * 64 * 3);
          // `reduce` over an FFI-backed list is the original crash shape.
          final mean = data.reduce((a, b) => a + b) / data.length;
          expect(mean.isFinite, isTrue);
          expect(mean, greaterThan(0.0));
        }
        cube.destroy();
        img.destroy();
      }
    });
  });

  group('IblCubemap Tests (Task 01)', () {
    test('IblImage creation and LinearImage conversion', () {
      final linear = LinearImage(4, 4, 3);
      clearToValue(linear, 0.75);

      final iblImg = IblImage.fromLinearImage(linear);
      expect(iblImg.width, equals(4));
      expect(iblImg.height, equals(4));
      expect(iblImg.data.length, equals(4 * 4 * 3));
      expect(iblImg.data[0], closeTo(0.75, 1e-5));

      final convertedBack = iblImg.toLinearImage();
      expect(convertedBack.width, equals(4));
      expect(convertedBack.height, equals(4));
      expect(convertedBack.channels, equals(3));
      expect(convertedBack.getPixel(0, 0, 0), closeTo(0.75, 1e-5));

      linear.destroy();
      iblImg.destroy();
      convertedBack.destroy();
    });

    test('IblCubemap face images retrieval', () {
      final cm = IblCubemap(8);
      expect(cm.dimensions, equals(8));

      for (final face in IblCubemapFace.values) {
        final faceImg = cm.faceImage(face);
        expect(faceImg.width, equals(8));
        expect(faceImg.height, equals(8));
        faceImg.destroy();
      }

      cm.destroy();
    });

    test('CubemapUtils equirectangularToCubemap and cubemapToEquirectangular', () {
      final equirect = IblImage(32, 16);
      for (var i = 0; i < 32 * 16 * 3; i++) {
        equirect.data[i] = 1.0;
      }

      final cm = IblCubemap(8);
      CubemapUtils.equirectangularToCubemap(cm, equirect);

      final facePX = cm.faceImage(IblCubemapFace.px);
      expect(facePX.data[0], isNonZero);
      facePX.destroy();

      final outEquirect = IblImage(32, 16);
      CubemapUtils.cubemapToEquirectangular(outEquirect, cm);
      expect(outEquirect.data[0], isNonZero);

      equirect.destroy();
      cm.destroy();
      outEquirect.destroy();
    });

    test('CubemapUtils crossToCubemap', () {
      // 4:3 horizontal cross: width=32, height=24 (dim=8)
      final cross = IblImage(32, 24);
      for (var i = 0; i < 32 * 24 * 3; i++) {
        cross.data[i] = 0.5;
      }

      final cm = CubemapUtils.crossToCubemap(cross);
      expect(cm.dimensions, equals(8));

      cross.destroy();
      cm.destroy();
    });

    test('CubemapUtils cubemapToOctahedron', () {
      final cm = IblCubemap(8);
      final oct = IblImage(16, 16);

      CubemapUtils.cubemapToOctahedron(oct, cm);
      expect(oct.width, equals(16));
      expect(oct.height, equals(16));

      cm.destroy();
      oct.destroy();
    });

    test('CubemapUtils mirrorCubemap and downsampleCubemapLevelBoxFilter', () {
      final src = IblCubemap(8);
      final mirrored = IblCubemap(8);
      CubemapUtils.mirrorCubemap(mirrored, src);

      final downsampled = IblCubemap(4);
      CubemapUtils.downsampleCubemapLevelBoxFilter(downsampled, src);
      expect(downsampled.dimensions, equals(4));

      CubemapUtils.makeSeamless(src);

      src.destroy();
      mirrored.destroy();
      downsampled.destroy();
    });
  });
}
