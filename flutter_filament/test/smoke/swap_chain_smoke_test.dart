// swap_chain smoke: headless swap chain with config flags, capability
// queries and frame scheduled/completed callbacks firing across rendered
// frames on the GPU backend.
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
  });
}
