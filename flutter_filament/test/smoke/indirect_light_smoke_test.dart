// indirect_light smoke: the bundled lightroom IBL (real KTX) lights a metal
// barrel; rotation / intensity setters and the direction estimate are
// asserted and a full IBL rotation is recorded as a WebM.
import 'dart:math' as math;

import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'smoke_helper.dart';

void main() {
  group('IndirectLight Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
    });

    tearDown(() {
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('IndirectLight: KTX IBL lights a real barrel, rotates and scales (video)', () {
      final ibl = rig.addIbl(intensity: 40000);
      expect(rig.engine.isValidIndirectLight(ibl), isTrue);
      expect(rig.scene.indirectLight?.nativePointer.address, ibl.nativePointer.address);
      expect(ibl.reflectionsTexture, isNotNull);
      final dir = ibl.getDirectionEstimate();
      expect(dir.length, closeTo(1, 1e-3), reason: 'dominant direction is unit length');
      expect(ibl.irradianceTexture, isNull, reason: 'KTX IBL carries SH irradiance, not a texture');

      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_black.glb');
      try {
        final lit = rig.screenshot('IndirectLight Smoke Tests IndirectLight: KTX IBL lights a real barrel, rotates and scales (video)');
        final litBrightness = _brightness(lit);
        expect(countForegroundPixels(lit, rig.width), greaterThan(rig.width * rig.height ~/ 40));

        ibl.setIntensity(2000);
        final dim = rig.renderFrame();
        final dimBrightness = _brightness(dim);
        smokeLog('brightness lit=${litBrightness.toStringAsFixed(1)} dim=${dimBrightness.toStringAsFixed(1)}');
        expect(dimBrightness, lessThan(litBrightness));
        ibl.setIntensity(40000);

        final last = rig.video(
          'IndirectLight Smoke Tests IndirectLight: KTX IBL lights a real barrel, rotates and scales (video)',
          alsoScreenshot: false,
          onFrame: (frame, t) {
            ibl.rotation = Matrix3.rotationY(t * 2 * math.pi);
          },
        );
        final rot = ibl.rotation;
        expect(rot.entry(0, 0), closeTo(1, 1e-4), reason: 'full turn returns to identity');
        ibl.rotation = Matrix3.rotationY(math.pi);
        final half = rig.renderFrame();
        expect(countChangedPixels(lit, half), greaterThan(200), reason: 'rotated environment changes reflections');
        expect(countForegroundPixels(last, rig.width), greaterThan(rig.width * rig.height ~/ 40));
      } finally {
        gltf.dispose(rig.scene);
        rig.scene.setIndirectLight(null);
        ibl.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

double _brightness(List<int> px) {
  var sum = 0;
  for (var i = 0; i < px.length; i += 4) {
    sum += px[i] + px[i + 1] + px[i + 2];
  }
  return sum / (px.length / 4 * 3);
}
