// instance_buffer smoke: one quad drawn as a 4x4 grid of GPU instances via
// InstanceBuffer local transforms; the grid is counted on the rendered frame
// and the transforms are animated into a WebM.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'smoke_helper.dart';

void main() {
  group('InstanceBuffer Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      // Square ortho scene (framed as the former 256×256 rig) at video size.
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoWidth);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('InstanceBuffer: 16 instanced quads form a grid and animate (video)', () {
      const n = 16;
      List<Matrix4> grid(double scale, double spin) => [
            for (var i = 0; i < n; i++)
              Matrix4.identity()
                ..translateByDouble(-0.75 + (i % 4) * 0.5, -0.75 + (i ~/ 4) * 0.5, 0.0, 1.0)
                ..rotateZ(spin)
                ..scaleByDouble(scale, scale, 1.0, 1.0),
          ];
      final ibuf = InstanceBuffer.create(rig.engine, instanceCount: n, localTransforms: packMatrices(grid(1, 0)));
      expect(ibuf.instanceCount, n);
      final t5 = ibuf.getLocalTransform(5).getTranslation();
      expect(t5.x, closeTo(-0.25, 1e-5));
      expect(t5.y, closeTo(-0.25, 1e-5));

      final quad = SmokeQuad.create(rig.engine, size: 0.3);
      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.95, 0.85, 0.2);
      final entity = rig.engine.createEntity();
      rig.entities.add(entity);
      RenderableBuilder(1)
        ..boundingBox(-2, -2, -2, 2, 2, 2)
        ..culling(false)
        ..material(0, mi)
        ..instances(n, ibuf)
        ..geometry(0, PrimitiveType.triangles, quad.vb, ib: quad.ib)
        ..build(rig.engine, entity);
      rig.scene.addEntity(entity);
      expect(FilamentRenderableManager(rig.engine).getInstanceCount(entity), n);

      final px = rig.screenshot('InstanceBuffer Smoke Tests InstanceBuffer: 16 instanced quads form a grid and animate (video)');
      // Count yellow blobs along the middle row of the first grid row (y for row 0 = -0.75 → 7/8 of the height).
      var runs = 0;
      var inside = false;
      for (var x = 0; x < rig.width; x++) {
        final (r, _, b) = pixelAt(px, rig.width, x, rig.height * 7 ~/ 8);
        final on = r > 150 && b < 100;
        if (on && !inside) runs++;
        inside = on;
      }
      final fg = countForegroundPixels(px, rig.width);
      smokeLog('instance grid runs=$runs fg=$fg');
      expect(runs, 4, reason: 'four instances across one grid row');
      // 16 quads of 0.3 on a 2-unit frame → each 15% of the side → ~36% of the pixels.
      expect(fg / (rig.width * rig.height), inInclusiveRange(0.24, 0.46));

      rig.video(
        'InstanceBuffer Smoke Tests InstanceBuffer: 16 instanced quads form a grid and animate (video)',
        alsoScreenshot: false,
        onFrame: (frame, t) {
          ibuf.setLocalTransforms(packMatrices(grid(0.6 + 0.4 * math.sin(t * math.pi), t * math.pi)), count: n);
        },
      );

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      ibuf.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
