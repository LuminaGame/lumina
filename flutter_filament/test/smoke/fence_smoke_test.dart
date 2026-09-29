// fence smoke: a Fence created after GPU work signals via wait / poll /
// whenSignaled on a real backend; the frame it fences is published.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Fence Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
    });

    tearDown(() => rig.dispose());

    test('Fence: wait, poll and whenSignaled after rendered frames', () async {
      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.9, 0.2, 0.9);
      final quad = SmokeQuad.create(rig.engine, size: 1.0);
      addQuadRenderable(rig, quad, mi);

      final px = rig.screenshot('Fence Smoke Tests Fence: wait, poll and whenSignaled after rendered frames');
      expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 6));

      final fence = rig.engine.createFence();
      expect(fence.isDisposed, isFalse);
      expect(FilamentFence.fenceWaitForEver, isNot(0));
      final status = fence.wait(timeout: const Duration(seconds: 5));
      expect(status, FenceStatus.conditionSatisfied);
      expect(fence.poll(), FenceStatus.conditionSatisfied);
      fence.dispose();

      final fence2 = FilamentFence.create(rig.engine);
      final async = await fence2.whenSignaled().timeout(const Duration(seconds: 5));
      expect(async, FenceStatus.conditionSatisfied);
      expect(fence2.waitAndDestroy(), FenceStatus.conditionSatisfied);
      expect(fence2.isDisposed, isTrue);

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
