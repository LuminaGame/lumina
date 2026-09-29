// ibl smoke: CPU-side IBL tooling — a procedural equirect becomes an
// IblCubemap (CubemapUtils), its 3-band SH are computed (CubemapSH) and
// used as the irradiance of a Filament IndirectLight lighting a real prop;
// the SH direction estimate points at the bright side.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('IBL Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 320, height: 240);
    });

    tearDown(() {
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('IBL: CPU cubemap + spherical harmonics light a real prop', () {
      const w = 256, h = 128;
      final equirect = IblImage(w, h);
      final data = equirect.data;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final u = x / w, v = y / h;
          // One longitude hemisphere is a bright warm sky, the other is dark:
          // whichever cube face it lands on, exactly one horizontal axis dominates.
          final bright = math.cos((u - 0.25) * 2 * math.pi).clamp(0.0, 1.0);
          final horizon = 1.0 - (v - 0.5).abs() * 1.2;
          final o = (y * w + x) * 3;
          data[o] = 0.03 + bright * horizon * 5.0;
          data[o + 1] = 0.03 + bright * horizon * 3.5;
          data[o + 2] = 0.05 + bright * horizon * 1.5;
        }
      }
      final cube = IblCubemap(64);
      CubemapUtils.equirectangularToCubemap(cube, equirect);
      CubemapUtils.makeSeamless(cube);
      // Round-trip back to an equirect (a tightly packed top-level IblImage) and
      // compare the two longitude hemispheres. Per-face reads are avoided on
      // purpose (a face image is a view into the cubemap cross, with the cross's row stride).
      final back = IblImage(w, h);
      CubemapUtils.cubemapToEquirectangular(back, cube);
      double hemisphere(double u0, double u1) {
        var sum = 0.0;
        var n = 0;
        for (var y = h ~/ 4; y < 3 * h ~/ 4; y++) {
          for (var x = (u0 * w).round(); x < (u1 * w).round(); x++) {
            final o = (y * w + x) * 3;
            sum += back.data[o] + back.data[o + 1] + back.data[o + 2];
            n += 3;
          }
        }
        return sum / n;
      }
      final brightSide = hemisphere(0.0, 0.5);
      final darkSide = hemisphere(0.5, 1.0);
      back.destroy();
      smokeLog('round-trip equirect mean bright=${brightSide.toStringAsFixed(3)} dark=${darkSide.toStringAsFixed(3)}');
      expect(brightSide, greaterThan(darkSide * 5), reason: 'cubemap round-trip preserves the lit hemisphere');

      final shRaw = CubemapSH.computeSH(cube, numBands: 3, irradiance: true);
      expect(shRaw.length, 27);
      CubemapSH.preprocessSHForShader(shRaw);
      final sh = SphericalHarmonics(bands: 3, coefficients: shRaw);
      final dir = FilamentIndirectLight.directionEstimateFromSh(sh);
      smokeLog('sh direction estimate=$dir');
      expect(dir.length, closeTo(1, 1e-3));
      // u = 0.25 is the +X meridian in Filament's equirect convention.
      expect(dir.x, greaterThan(0.9), reason: 'SH direction estimate points at the bright hemisphere (+X)');
      expect(dir.y.abs(), lessThan(0.2));

      final ibl = FilamentIndirectLight.build(rig.engine, irradiance: sh, intensity: 60000);
      rig.scene.setIndirectLight(ibl);
      final gltf = loadGltfIntoScene(rig, 'Props/AC_units/aircon_small_mount.glb');
      try {
        final lit = rig.screenshot('IBL Smoke Tests IBL: CPU cubemap + spherical harmonics light a real prop');
        final fg = countForegroundPixels(lit, rig.width);
        expect(fg, greaterThan(rig.width * rig.height ~/ 40));
        final litStats = frameStats(lit);
        rig.scene.setIndirectLight(null);
        final dark = rig.renderFrame();
        final darkStats = frameStats(dark);
        smokeLog('sh lit distinct=${litStats.distinct} dark distinct=${darkStats.distinct}');
        expect(litStats.distinct, greaterThan(darkStats.distinct), reason: 'SH irradiance adds shading');
      } finally {
        gltf.dispose(rig.scene);
        rig.scene.setIndirectLight(null);
        ibl.dispose();
        cube.destroy();
        equirect.destroy();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
