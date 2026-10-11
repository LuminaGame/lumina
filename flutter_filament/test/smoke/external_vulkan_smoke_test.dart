// external Vulkan smoke: an engine on a device it did not create renders both
// eyes of a multiview frame into a two-layer image it does not own (the
// OpenXR path), with a turning barrel and AC unit from test-assets. The two
// layers are published side by side.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'smoke_helper.dart';

void main() {
  const eyeWidth = 512;
  const eyeHeight = 768;
  const name = 'External Vulkan Smoke Tests multiview eyes of a barrel and an AC unit side by side';

  test(name, () {
    SmokeArtifacts.resetRecordedAssets();
    final offscreen = ExternalVulkanOffscreen.create(
        width: eyeWidth, height: eyeHeight, layers: 2, multiview: true, srgb: true);
    if (offscreen == null) return markTestSkipped('no Vulkan device');
    final engine = FilamentEngine.createOnExternalVulkan(offscreen.context,
        config: const EngineConfig(stereoscopicType: StereoscopicType.multiview, stereoscopicEyeCount: 2));
    if (engine == null || !engine.isStereoSupported(StereoscopicType.multiview)) {
      engine?.dispose();
      offscreen.dispose();
      return markTestSkipped('no multiview engine on this device');
    }
    final rig = SmokeRig.adopt(engine, width: eyeWidth, height: eyeHeight);
    final swapChain = FilamentSwapChain.external(engine, offscreen.provider)!;
    rig.addSun();
    final ibl = rig.addIbl();
    final barrel = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_red.glb', frameCamera: false);
    final unit = loadGltfIntoScene(rig, 'Props/AC_units/roof_aircon_unit_150x150_a.glb', frameCamera: false);
    try {
      rig.view.stereoscopicOptions = const StereoscopicOptions(enabled: true);
      expect(rig.view.isStereoActive(engine), isTrue);
      final transforms = FilamentTransformManager(engine);
      final barrelBox = barrel.asset.getBoundingBox();
      final unitBox = unit.asset.getBoundingBox();
      final barrelScale = 0.55 / (barrelBox.max - barrelBox.min).length;
      final unitScale = 0.55 / (unitBox.max - unitBox.min).length;
      void place(LoadedGltf model, Aabb box, double scale, double x, double angle) {
        final center = box.center;
        final m = Matrix4.translationValues(x, 0, 0)
          ..multiply(Matrix4.rotationY(angle))
          ..multiply(Matrix4.diagonal3Values(scale, scale, scale))
          ..multiply(Matrix4.translationValues(-center.x, -center.y, -center.z));
        transforms.setTransform(model.asset.rootEntity, m.storage);
      }

      // Head 1.6 m back from the pair, eyes 6.4 cm apart.
      rig.camera.setProjection(fovDegrees: 60, aspect: eyeWidth / eyeHeight, near: 0.05, far: 50);
      rig.camera.lookAt(eyeX: 0, eyeY: 0.3, eyeZ: 1.6, centerX: 0, centerY: 0, centerZ: 0);
      rig.camera.setEyeModelMatrix(0, Matrix4.translationValues(-0.032, 0, 0));
      rig.camera.setEyeModelMatrix(1, Matrix4.translationValues(0.032, 0, 0));

      final frames = smokeVideoFrames();
      final pngs = <Uint8List>[];
      var lastImage = 0;
      for (var f = 0; f < frames; f++) {
        final angle = f / smokeVideoFps * math.pi / 3;
        place(barrel, barrelBox, barrelScale, -0.25, angle);
        place(unit, unitBox, unitScale, 0.25, -angle);
        var began = false;
        for (var attempt = 0; attempt < 500 && !began; attempt++) {
          began = rig.renderer.beginFrame(swapChain);
        }
        expect(began, isTrue, reason: 'frame $f');
        rig.renderer.render(rig.view);
        rig.renderer.endFrame();
        engine.flushAndWait();
        lastImage = offscreen.events.lastWhere((e) => e.present).index;
        final left = offscreen.readPixels(lastImage, layer: 0)!;
        final right = offscreen.readPixels(lastImage, layer: 1)!;
        pngs.add(SmokeArtifacts.encodePng(eyeWidth * 2, eyeHeight, sideBySide(left, right, eyeWidth, eyeHeight)));
        if (f == frames ~/ 2) {
          expect(countForegroundPixels(left, eyeWidth), greaterThan(eyeWidth * eyeHeight ~/ 50));
          expect(countChangedPixels(left, right), greaterThan(500), reason: 'the eyes differ by their offset');
        }
      }
      SmokeArtifacts.saveVideoFromPngFrames(name, pngs, fps: smokeVideoFps);
      SmokeArtifacts.saveScreenshot(name, pngs[pngs.length ~/ 2]);
      smokeLog('external multiview: $frames frames, ${offscreen.events.length} provider calls, '
          'GPU ${engine.gpuName}');
    } finally {
      engine.flushAndWait();
      unit.dispose(rig.scene);
      barrel.dispose(rig.scene);
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      swapChain.dispose();
      rig.dispose();
      offscreen.dispose();
      SmokeArtifacts.resetRecordedAssets();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Two RGBA8 images of [w] x [h] next to each other.
Uint8List sideBySide(Uint8List left, Uint8List right, int w, int h) {
  final out = Uint8List(w * 2 * h * 4);
  for (var y = 0; y < h; y++) {
    out.setRange(y * w * 8, y * w * 8 + w * 4, left, y * w * 4);
    out.setRange(y * w * 8 + w * 4, (y + 1) * w * 8, right, y * w * 4);
  }
  return out;
}
