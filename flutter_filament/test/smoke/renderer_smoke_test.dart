// renderer smoke: ClearOptions, frame-info history and readPixels via the
// standard swap chain path on a real GPU engine.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'smoke_helper.dart';

void main() {
  group('Renderer Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('Renderer: clear colour round-trips, frame history fills, readPixels matches', () {
      rig.renderer.clearOptions = ClearOptions(clearColor: Vector4(0.0, 0.5, 1.0, 1.0), clear: true, discard: true);
      final co = rig.renderer.clearOptions;
      expect(co.clearColor.y, closeTo(0.5, 1e-6));
      expect(co.clear, isTrue);

      rig.renderer.frameRateOptions = const FrameRateOptions(headRoomRatio: 0.0, scaleRate: 0.125, history: 15, interval: 1);
      rig.renderer.displayInfo = const DisplayInfo(refreshRate: 60.0);

      final px = rig.screenshot('Renderer Smoke Tests Renderer: clear colour round-trips, frame history fills, readPixels matches', warmup: 5);
      final (r, g, b) = averageColor(px, rig.width, 0, 0, rig.width, rig.height);
      print('clear readback avg=($r,$g,$b)');
      expect(r, lessThan(10));
      expect(g, inInclusiveRange(110, 145));
      expect(b, greaterThan(240));

      // Frame info arrives once the GPU has completed frames; keep rendering
      // until the history is populated (bounded).
      var history = rig.renderer.getFrameInfoHistory(4);
      for (var attempt = 0; attempt < 20 && history.isEmpty; attempt++) {
        rig.renderFrame(warmup: 2);
        history = rig.renderer.getFrameInfoHistory(4);
      }
      expect(history, isNotEmpty);
      expect(history.first.frameId, greaterThan(0));
      print('frame history=${history.length} lastId=${history.first.frameId}');

      // Convenience readPixels path (copies after flushAndWait) agrees with the screenshot.
      final out = Uint8ListExt.zeros(rig.width * rig.height * 4);
      if (rig.renderer.beginFrame(rig.swapChain)) {
        rig.renderer.render(rig.view);
        rig.renderer.readPixels(x: 0, y: 0, width: rig.width, height: rig.height, outPixels: out);
        rig.renderer.endFrame();
      }
      rig.engine.flushAndWait();
      final (_, g2, b2) = averageColor(out, rig.width, 0, 0, rig.width, rig.height);
      expect(g2, closeTo(g, 6));
      expect(b2, closeTo(b, 6));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
