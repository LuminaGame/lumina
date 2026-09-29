// material_instance smoke: duplicate(), per-instance parameters and render
// state (culling, depth, scissor) rendered on the GPU.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('MaterialInstance Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('MaterialInstance: duplicate keeps params, scissor and culling change the frame', () {
      final material = buildUnlitMaterial(rig.engine);
      final a = material.createInstance('a')..setFloat3('baseColor', 1, 0, 0);
      final b = a.duplicate(name: 'b');
      expect(b.name, 'b');
      expect(b.material.nativePointer.address, material.nativePointer.address);
      b.setFloat3('baseColor', 0, 0, 1);

      final left = SmokeQuad.create(rig.engine, size: 0.9);
      final right = SmokeQuad.create(rig.engine, size: 0.9);
      // Offset the second quad to the right via its transform.
      final eA = addQuadRenderable(rig, left, a);
      final eB = addQuadRenderable(rig, right, b);
      final tm = FilamentTransformManager(rig.engine);
      tm.setTransform(eA, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -0.5, 0, 0, 1]);
      tm.setTransform(eB, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.5, 0, 0, 1]);

      final px = rig.screenshot('MaterialInstance Smoke Tests MaterialInstance: duplicate keeps params, scissor and culling change the frame');
      final (lr, _, lb) = pixelAt(px, rig.width, 64, 128);
      final (rr, _, rb) = pixelAt(px, rig.width, 192, 128);
      expect(lr, greaterThan(180));
      expect(lb, lessThan(60));
      expect(rb, greaterThan(180));
      expect(rr, lessThan(60));

      // Render state: scissor the blue instance to its top half.
      expect(a.isDepthCullingEnabled, isTrue);
      expect(a.cullingMode, CullingMode.none);
      b.setScissor(left: 0, bottom: 128, width: 256, height: 128);
      final scissored = rig.renderFrame();
      final (_, _, topB) = pixelAt(scissored, rig.width, 192, 100);
      final (_, _, botB) = pixelAt(scissored, rig.width, 192, 170);
      print('scissor top=$topB bottom=$botB');
      expect(topB, greaterThan(180));
      expect(botB, lessThan(60), reason: 'scissor clips the bottom half');
      b.unsetScissor();

      // Back-face culling: look at the quads from behind. The red instance is
      // made single-sided + back-culled (instance overrides on a double-sided
      // material) and must vanish; the blue instance stays double-sided.
      a.setDoubleSided(false);
      a.setCullingMode(CullingMode.back);
      expect(a.isDoubleSided, isFalse);
      expect(a.cullingMode, CullingMode.back);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: -2, centerX: 0, centerY: 0, centerZ: 0);
      final culled = rig.renderFrame();
      var redPixels = 0, bluePixels = 0;
      for (var i = 0; i < culled.length; i += 4) {
        if (culled[i] > 180 && culled[i + 2] < 60) redPixels++;
        if (culled[i + 2] > 180 && culled[i] < 60) bluePixels++;
      }
      print('from behind: red=$redPixels blue=$bluePixels');
      expect(redPixels, 0, reason: 'back-culled single-sided quad is invisible from behind');
      expect(bluePixels, greaterThan(5000), reason: 'double-sided quad still renders');

      b.dispose();
      a.dispose();
      material.dispose();
      left.dispose();
      right.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
