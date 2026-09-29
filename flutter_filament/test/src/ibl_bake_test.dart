import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('CubemapIBL Tests (Task 03)', () {
    test('roughnessFilter generates filtered specular cubemap LOD', () {
      final base = IblCubemap(8);
      for (final face in IblCubemapFace.values) {
        final img = base.faceImage(face);
        img.fill(1.0, 1.0, 1.0); // stride-aware write
        img.destroy();
      }

      final filtered = IblCubemap(8);
      var progressCalls = 0;

      CubemapIBL.roughnessFilter(
        filtered,
        [base],
        0.5,
        maxNumSamples: 16,
        onProgress: (index, progress) {
          progressCalls++;
        },
      );

      expect(filtered.dimensions, equals(8));
      final facePX = filtered.faceImage(IblCubemapFace.px);
      expect(facePX.data[0], isNonZero);

      base.destroy();
      filtered.destroy();
      facePX.destroy();
    });

    test('diffuseIrradiance generates irradiance cubemap', () {
      final base = IblCubemap(8);
      for (final face in IblCubemapFace.values) {
        final img = base.faceImage(face);
        img.fill(1.0, 1.0, 1.0); // stride-aware write
        img.destroy();
      }

      final dst = IblCubemap(8);
      CubemapIBL.diffuseIrradiance(
        dst,
        [base],
        maxNumSamples: 16,
      );

      expect(dst.dimensions, equals(8));
      final facePX = dst.faceImage(IblCubemapFace.px);
      expect(facePX.data[0], isNonZero);

      base.destroy();
      dst.destroy();
      facePX.destroy();
    });

    test('dfg generates split-sum integration LUT', () {
      final lut = IblImage(16, 16);
      CubemapIBL.dfg(lut, multiscatter: true, cloth: false);

      expect(lut.width, equals(16));
      expect(lut.height, equals(16));
      expect(lut.data[0], isNonZero);

      lut.destroy();
    });
  });
}
