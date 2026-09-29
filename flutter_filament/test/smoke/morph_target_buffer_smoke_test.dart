// morph_target_buffer smoke: a quad with one morph target that pushes its
// right edge outward; weights are animated 0→1→0 and recorded as a WebM.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('MorphTargetBuffer Smoke Tests', () {
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

    test('MorphTargetBuffer: animated weights stretch a quad (video)', () {
      final quad = SmokeQuad.create(rig.engine, size: 0.8);
      final mtb = MorphTargetBuffer.create(rig.engine, vertexCount: 4, count: 2);
      expect(mtb.count, 2);
      expect(mtb.vertexCount, 4);
      // Target 0: push right vertices (1, 2) further right by 0.8.
      mtb.setPositionsAt(0, Float32List.fromList([0, 0, 0, 0.8, 0, 0, 0.8, 0, 0, 0, 0, 0]));
      // Target 1: push top vertices (2, 3) up by 0.5.
      mtb.setPositionsAt(1, Float32List.fromList([0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0, 0.5, 0]));

      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.2, 0.8, 0.3);
      final entity = rig.engine.createEntity();
      rig.entities.add(entity);
      RenderableBuilder(1)
        ..boundingBox(-2, -2, -2, 2, 2, 2)
        ..culling(false)
        ..material(0, mi)
        ..morphing(2)
        ..morphingBuffer(mtb)
        ..geometry(0, PrimitiveType.triangles, quad.vb, ib: quad.ib)
        ..build(rig.engine, entity);
      rig.scene.addEntity(entity);
      final rm = FilamentRenderableManager(rig.engine);
      expect(rm.getMorphTargetCount(entity), 2);

      rm.setMorphWeights(entity, Float32List.fromList([0, 0]));
      final rest = rig.renderFrame();
      final restFg = countForegroundPixels(rest, rig.width);

      rig.video(
        'MorphTargetBuffer Smoke Tests MorphTargetBuffer: animated weights stretch a quad (video)',
        onFrame: (frame, t) {
          final w = math.sin(t * math.pi);
          rm.setMorphWeights(entity, Float32List.fromList([w, w * 0.5]));
        },
      );

      rm.setMorphWeights(entity, Float32List.fromList([1, 0]));
      final morphed = rig.renderFrame();
      final morphedFg = countForegroundPixels(morphed, rig.width);
      print('rest fg=$restFg morphed fg=$morphedFg');
      // Quad 0.8 wide → 1.6 wide: foreground roughly doubles.
      expect(morphedFg, greaterThan((restFg * 1.7).round()));
      // Pixel far right of the original quad is covered only when morphed.
      final probeX = rig.width * 230 ~/ 256, probeY = rig.height ~/ 2;
      final (_, gRest, _) = pixelAt(rest, rig.width, probeX, probeY);
      final (_, gMorph, _) = pixelAt(morphed, rig.width, probeX, probeY);
      expect(gRest, lessThan(60));
      expect(gMorph, greaterThan(150));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      mtb.dispose();
      quad.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
