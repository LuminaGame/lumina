// filameshio smoke: the two-submesh golden .filamesh is loaded through a
// MaterialRegistry binding two differently coloured material instances, and
// both colours are asserted on the rendered frame.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Filameshio Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('Filameshio: registry-bound materials colour each submesh', () {
      final file = File('test/assets/two_materials.filamesh');
      SmokeArtifacts.recordAsset(file.absolute.path);
      final material = buildUnlitMaterial(rig.engine);
      final red = material.createInstance('matA')..setFloat3('baseColor', 1, 0.1, 0.1);
      final blue = material.createInstance('matB')..setFloat3('baseColor', 0.1, 0.2, 1);
      final registry = MaterialRegistry()
        ..register('matA', red)
        ..register('matB', blue);
      expect(registry.numRegistered, 2);

      final mesh = loadMeshFromBuffer(rig.engine, file.readAsBytesSync(), materials: registry);
      expect(mesh, isNotNull);
      final rm = FilamentRenderableManager(rig.engine);
      expect(rm.getPrimitiveCount(mesh!.renderable), 2);
      expect(rm.getMaterialInstanceAt(mesh.renderable, 0)?.nativePointer.address, red.nativePointer.address);
      expect(rm.getMaterialInstanceAt(mesh.renderable, 1)?.nativePointer.address, blue.nativePointer.address);
      rig.scene.addEntity(mesh.renderable);
      rm.setCulling(mesh.renderable, false);
      final box = rm.getAxisAlignedBoundingBox(mesh.renderable);
      final c = box.center;
      final r = box.halfExtent.length;
      rig.camera.setProjection(fovDegrees: 45, aspect: 1, near: 0.05, far: r * 50);
      rig.camera.lookAt(eyeX: c.x + r * 1.2, eyeY: c.y + r * 1.5, eyeZ: c.z + r * 2.6, centerX: c.x, centerY: c.y, centerZ: c.z);

      final px = rig.screenshot('Filameshio Smoke Tests Filameshio: registry-bound materials colour each submesh');
      var reds = 0, blues = 0;
      for (var i = 0; i < px.length; i += 4) {
        if (px[i] > 150 && px[i + 2] < 80) reds++;
        if (px[i + 2] > 150 && px[i] < 80) blues++;
      }
      smokeLog('filamesh reds=$reds blues=$blues aabb=$box');
      expect(reds, greaterThan(300), reason: 'submesh A drawn with matA');
      expect(blues, greaterThan(300), reason: 'submesh B drawn with matB');

      rig.scene.removeEntity(mesh.renderable);
      rig.engine.flushAndWait();
      registry.destroy();
      mesh.destroy();
      rig.engine.flushAndWait();
      blue.dispose();
      red.dispose();
      material.dispose();
      rig.engine.flushAndWait();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
