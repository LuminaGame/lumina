// camera smoke: projection / lookAt / exposure on a real AC-unit GLB — a
// dolly-in is recorded as a WebM, matrices and FOV getters are asserted and
// exposure visibly brightens the frame.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Camera Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('Camera: dolly-in on a real prop with FOV, matrices and exposure (video)', () {
      final gltf = loadGltfIntoScene(rig, 'Props/AC_units/ac_unit_b_600x600.glb', frameCamera: false);
      try {
        final box = gltf.asset.getBoundingBox();
        final c = box.center;
        final radius = (box.max - box.min).length / 2;
        final cam = rig.camera;
        cam.setProjection(fovDegrees: 50, aspect: rig.width / rig.height, near: 0.05, far: radius * 50);
        expect(cam.getFieldOfViewInDegrees(FovDirection.vertical), closeTo(50, 0.01));
        cam.lookAt(eyeX: c.x, eyeY: c.y + radius, eyeZ: c.z + radius * 4, centerX: c.x, centerY: c.y, centerZ: c.z);
        expect(cam.position.z, closeTo(c.z + radius * 4, 1e-4));
        expect(cam.forwardVector.z, lessThan(0));
        final view = cam.viewMatrix;
        final model = cam.modelMatrix;
        final product = view * model;
        for (var i = 0; i < 16; i++) {
          expect(product.storage[i], closeTo(i % 5 == 0 ? 1 : 0, 1e-4), reason: 'view * model = identity');
        }
        expect(cam.frustumPlanes.length, 6);

        final far = rig.renderFrame();
        final farFg = countForegroundPixels(far, rig.width);
        final last = rig.video(
          'Camera Smoke Tests Camera: dolly-in on a real prop with FOV, matrices and exposure (video)',
          onFrame: (frame, t) {
            final d = radius * (4 - 2.6 * t);
            cam.lookAt(eyeX: c.x + radius * 0.8 * t, eyeY: c.y + radius * 0.6, eyeZ: c.z + d,
                centerX: c.x, centerY: c.y, centerZ: c.z);
          },
        );
        final nearFg = countForegroundPixels(last, rig.width);
        smokeLog('dolly foreground far=$farFg near=$nearFg');
        expect(nearFg, greaterThan(farFg * 2), reason: 'dolly-in grows the prop on screen');

        // Exposure: +3 EV brighter.
        cam.setExposure(aperture: 16, shutterSpeed: 1 / 125, sensitivity: 100); // EV100 ~ 15
        final ev = cam.renderFrameBrightness(rig);
        cam.setExposureEv100(12);
        final bright = cam.renderFrameBrightness(rig);
        smokeLog('brightness ev15=${ev.toStringAsFixed(1)} ev12=${bright.toStringAsFixed(1)}');
        // 3 stops brighter; the frame mean is damped by the unlit background.
        expect(bright, greaterThan(ev * 1.15));
        // The same EV set both ways renders the same frame (the old
        // wrapper took the EV as an exposure factor: ~15× over-exposed).
        cam.setExposureEv100(math.log(16 * 16 * 125) / math.ln2);
        final same = cam.renderFrameBrightness(rig);
        smokeLog('brightness sunny16=${ev.toStringAsFixed(1)} setExposureEv100(14.97)=${same.toStringAsFixed(1)}');
        expect(same, closeTo(ev, 1.5));
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

extension on FilamentCamera {
  double renderFrameBrightness(SmokeRig rig) {
    final px = rig.renderFrame();
    var sum = 0;
    for (var i = 0; i < px.length; i += 4) {
      sum += px[i] + px[i + 1] + px[i + 2];
    }
    return sum / (px.length / 4 * 3);
  }
}
