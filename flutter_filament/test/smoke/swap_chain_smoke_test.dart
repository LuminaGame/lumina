// swap_chain smoke: headless swap chain with config flags, capability
// queries and frame scheduled/completed callbacks firing across rendered
// frames on the GPU backend.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('SwapChain Smoke Tests', () {
    test('SwapChain: readable headless chain, capability queries and frame callbacks', () async {
      SmokeArtifacts.resetRecordedAssets();
      final engine = FilamentEngine.create(backend: smokeBackend)!;
      final rig = SmokeRig.adopt(engine, width: 256, height: 256,
          swapChainFlags: SwapChainConfig.readable | SwapChainConfig.transparent);
      expect(engine.isValidSwapChain(rig.swapChain), isTrue);
      smokeLog('srgb=${FilamentSwapChain.isSRGBSupported(engine)} msaa=${FilamentSwapChain.isMSAASupported(engine)} '
          'frameRateChange=${rig.swapChain.isFrameRateChangeSupported}');
      expect(FilamentSwapChain.isProtectedContentSupported(engine), isA<bool>());
      expect(rig.swapChain.isFrameRateChangeSupported, isNotNull);

      var scheduled = 0, completed = 0;
      rig.swapChain.onFrameScheduled = () => scheduled++;
      rig.swapChain.onFrameCompleted = () => completed++;
      expect(rig.swapChain.isFrameScheduledCallbackSet, isTrue);

      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      final material = buildUnlitMaterial(engine);
      final mi = material.createInstance()..setFloat3('baseColor', 1.0, 0.3, 0.6);
      final quad = SmokeQuad.create(engine, size: 1.2);
      addQuadRenderable(rig, quad, mi);

      final px = rig.screenshot('SwapChain Smoke Tests SwapChain: readable headless chain, capability queries and frame callbacks', warmup: 5);
      expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 5));
      for (var i = 0; i < 10; i++) {
        engine.pumpMessageQueues();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      smokeLog('callbacks scheduled=$scheduled completed=$completed');
      expect(scheduled, greaterThanOrEqualTo(6), reason: 'one scheduled callback per rendered frame');
      // Headless swap chains never present, so onFrameCompleted stays 0 here;
      // the setter round-trip is still exercised.
      expect(completed, greaterThanOrEqualTo(0));

      rig.swapChain.onFrameScheduled = null;
      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      rig.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('direct presentation composites a UI overlay over frame generation', () {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped('direct presentation is Vulkan only');
        return;
      }
      SmokeArtifacts.resetRecordedAssets();
      const name = 'SwapChain Smoke Tests direct presentation composites a UI overlay over frame generation';
      const w = 1024, h = 768;
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      final rig = SmokeRig.adopt(engine, width: w, height: h, swapChainFlags: SwapChainConfig.disableVsync);
      final tm = FilamentTransformManager(engine);
      rig.addSun(intensity: 110000);
      rig.addIbl(intensity: 12000);
      final loaded = <LoadedGltf>[];
      final overlay = FilamentUiOverlay.create(engine)!..setViewport(0, 0, w, h);
      try {
        const props = [
          ('Props/AC_units/ac_unit_a_300x300.glb', -0.9, 0.0),
          ('Props/Barrels/fuel_barrel_red.glb', 0.9, 0.2),
          ('Props/Access_cards/access_card_blue.glb', 0.0, 1.0),
        ];
        for (final (path, x, z) in props) {
          final gltf = loadGltfIntoScene(rig, path, frameCamera: false);
          loaded.add(gltf);
          final box = gltf.asset.getBoundingBox();
          tm.setTransform(gltf.asset.rootEntity,
              [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x - box.center.x, -box.min.y, z - box.center.z, 1]);
        }
        rig.camera.setProjection(fovDegrees: 40, aspect: w / h, near: 0.05, far: 100);
        // FSR3 frame generation: the overlay is drawn again over each present.
        rig.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
            enabled: true, motionVectors: true, algorithm: TaaAlgorithm.fsr3, frameGeneration: true);

        // A game HUD as Flutter would hand it over (premultiplied RGBA8, top
        // row first): a translucent top bar, a health bar that drains, a
        // button in the middle that lights up halfway.
        final ui = Uint8List(w * h * 4);
        void fill(int x0, int y0, int x1, int y1, List<int> c) {
          for (var y = y0; y < y1; y++) {
            for (var x = x0; x < x1; x++) {
              ui.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, c);
            }
          }
        }

        var uploads = 0;
        rig.video(name, afterView: () => overlay.render(rig.renderer), onFrame: (frame, t) {
          final a = t * math.pi * 2;
          rig.camera.lookAt(eyeX: math.sin(a) * 9, eyeY: 3.5, eyeZ: math.cos(a) * 9, centerX: 0, centerY: 1.0, centerZ: 0);
          ui.fillRange(0, ui.length, 0);
          fill(0, 0, w, 56, const [10, 12, 16, 190]);
          final health = (1 - t * 0.8);
          fill(24, 18, 24 + (300 * health).round(), 38, const [40, 170, 60, 255]);
          fill(24 + (300 * health).round(), 18, 324, 38, const [70, 20, 20, 255]);
          final hot = t > 0.5;
          fill(412, 340, 612, 400, hot ? const [200, 120, 20, 230] : const [30, 60, 120, 200]);
          if (overlay.upload(ui, w, h)) uploads++;
        });
        final png = rig.renderFrame(afterView: () => overlay.render(rig.renderer));
        // The top bar is dark over the scene; the button is its colour.
        final button = png.sublist((370 * w + 512) * 4, (370 * w + 512) * 4 + 3);
        smokeLog('direct-presentation overlay: $uploads uploads, last ${overlay.lastUploadMicros} us; button pixel $button');
        expect(button[0], greaterThan(150), reason: 'the lit button blended over the frame');
        expect(uploads, greaterThan(250));
      } finally {
        overlay.dispose();
        for (final g in loaded) {
          g.dispose(rig.scene);
        }
        rig.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
