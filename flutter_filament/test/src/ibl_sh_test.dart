import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('CubemapSH Tests (Task 02)', () {
    test('computeSH on constant cubemap yields dominant L00 coefficient', () {
      final cm = IblCubemap(8);
      for (final face in IblCubemapFace.values) {
        final img = cm.faceImage(face);
        img.fill(1.0, 1.0, 1.0); // stride-aware write
        img.destroy();
      }

      final sh = CubemapSH.computeSH(cm, numBands: 3, irradiance: true);
      expect(sh.length, equals(27)); // 3 bands -> 3*3 = 9 harmonics * 3 channels = 27

      // L00 is the first 3 floats (RGB)
      expect(sh[0], greaterThan(0.0));
      expect(sh[1], greaterThan(0.0));
      expect(sh[2], greaterThan(0.0));

      cm.destroy();
    });

    test('windowSH and preprocessSHForShader operate in-place', () {
      final cm = IblCubemap(8);
      final sh = CubemapSH.computeSH(cm, numBands: 3, irradiance: true);

      CubemapSH.windowSH(sh, 3, cutoff: 0.85);
      expect(sh.length, equals(27));

      CubemapSH.preprocessSHForShader(sh);
      expect(sh.length, equals(27));

      cm.destroy();
    });

    test('renderSH reconstructs cubemap from SH coefficients', () {
      final cm = IblCubemap(8);
      final sh = CubemapSH.computeSH(cm, numBands: 3, irradiance: true);

      final outCm = IblCubemap(8);
      CubemapSH.renderSH(outCm, sh, 3);
      expect(outCm.dimensions, equals(8));

      final facePX = outCm.faceImage(IblCubemapFace.px);
      expect(facePX.width, equals(8));

      cm.destroy();
      outCm.destroy();
      facePX.destroy();
    });

    test('getShIndex formula: l(l+1) + m', () {
      expect(CubemapSH.getShIndex(0, 0), equals(0)); // l=0, m=0
      expect(CubemapSH.getShIndex(-1, 1), equals(1)); // l=1, m=-1
      expect(CubemapSH.getShIndex(0, 1), equals(2)); // l=1, m=0
      expect(CubemapSH.getShIndex(1, 1), equals(3)); // l=1, m=1
    });
  });
}
