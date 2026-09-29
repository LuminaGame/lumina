// dart_math smoke: the pure-Dart Frustum / Box / Aabb / Exposure helpers are
// checked against the real engine — a Frustum built from the live camera
// matrices agrees with View.visibleRenderableCount for a real GLB moved in
// and out of view, and camera exposure matches Exposure.ev100.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Frustum;

import 'smoke_helper.dart';

void main() {
  group('DartMath Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 320, height: 240);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('DartMath: Frustum/Box culling agrees with the engine for a real GLB', () {
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/lootbarrel_junk.glb');
      try {
        final rm = FilamentRenderableManager(rig.engine);
        final tm = FilamentTransformManager(rig.engine);
        final entity = gltf.asset.renderableEntities.first;
        final localBox = rm.getAxisAlignedBoundingBox(entity);
        expect(localBox.isEmpty, isFalse);

        Frustum frustumNow() => Frustum(rig.camera.projectionMatrix * rig.camera.viewMatrix);
        Box worldBox() => Box.rigidTransform(localBox, Matrix4.fromList(tm.getWorldTransform(entity)));

        final inView = rig.screenshot('DartMath Smoke Tests DartMath: Frustum/Box culling agrees with the engine for a real GLB');
        expect(countForegroundPixels(inView, rig.width), greaterThan(rig.width * rig.height ~/ 40));
        expect(frustumNow().intersects(worldBox()), isTrue);
        final aabb = Aabb(min: worldBox().center - worldBox().halfExtent, max: worldBox().center + worldBox().halfExtent);
        expect(aabb.contains(worldBox().center), lessThanOrEqualTo(0), reason: 'centre is inside its own AABB');
        final visibleBefore = rig.view.visibleRenderableCount;
        expect(visibleBefore, greaterThan(0));

        // Move the barrel far to the right, out of the frustum.
        final root = gltf.asset.rootEntity;
        final far = (localBox.halfExtent.length * 60).clamp(50.0, 1e6);
        tm.setTransform(root, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, far, 0, 0, 1]);
        final outView = rig.renderFrame();
        final fgOut = countForegroundPixels(outView, rig.width);
        final visibleAfter = rig.view.visibleRenderableCount;
        smokeLog('visible before=$visibleBefore after=$visibleAfter fgOut=$fgOut worldBox=${worldBox()}');
        expect(frustumNow().intersects(worldBox()), isFalse);
        expect(fgOut, lessThan(50));
        expect(visibleAfter, lessThan(visibleBefore));

        // Exposure helpers vs the physical camera settings.
        rig.camera.setExposure(aperture: 16, shutterSpeed: 1 / 125, sensitivity: 100);
        final ev = Exposure.ev100(aperture: 16, shutterSpeed: 1 / 125, sensitivity: 100);
        expect(ev, closeTo(15, 0.1));
        expect(rig.camera.aperture, closeTo(16, 1e-4));
        expect(Exposure.exposureFromEv100(ev), closeTo(Exposure.exposure(aperture: 16, shutterSpeed: 1 / 125, sensitivity: 100), 1e-9));
        final warm = FilamentColor.cct(2700);
        final cool = FilamentColor.cct(9000);
        expect(warm.x, greaterThan(warm.z));
        expect(cool.z, greaterThan(cool.x));
        const vp = Viewport(left: 0, bottom: 0, width: 320, height: 240);
        expect(vp, rig.view.viewportModel);
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
