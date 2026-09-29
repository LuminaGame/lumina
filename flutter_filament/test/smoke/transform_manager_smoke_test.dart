// transform_manager smoke: a parent/child hierarchy (barrel + AC unit from
// test-assets) is orbited via TransformManager transactions; world
// transforms are asserted numerically and the orbit is recorded as a WebM.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('TransformManager Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('TransformManager: parent/child hierarchy orbits real props (video)', () {
      final barrel = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_red.glb', frameCamera: false);
      final ac = loadGltfIntoScene(rig, 'Props/AC_units/aircon_small.glb', frameCamera: false);
      try {
        final tm = FilamentTransformManager(rig.engine);
        final pivot = rig.engine.createEntity();
        rig.entities.add(pivot);
        tm.create(pivot);
        expect(tm.hasComponent(pivot), isTrue);

        final barrelRoot = barrel.asset.rootEntity;
        final acRoot = ac.asset.rootEntity;
        tm.transaction(() {
          tm.setParent(barrelRoot, pivot);
          tm.setParent(acRoot, pivot);
          tm.setTransform(barrelRoot, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -1.2, 0, 0, 1]);
          tm.setTransform(acRoot, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1.2, 0, 0, 1]);
        });
        expect(tm.getParent(barrelRoot), pivot);
        expect(tm.childCount(pivot), 2);
        expect(tm.getChildren(pivot, 4), containsAll([barrelRoot, acRoot]));

        // Rotating the pivot 90° about Y sends the barrel from x=-1.2 to z=+1.2.
        final c = math.cos(math.pi / 2), s = math.sin(math.pi / 2);
        tm.setTransform(pivot, [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1]);
        final world = tm.getWorldTransform(barrelRoot);
        expect(world[12], closeTo(0, 1e-5));
        expect(world[14], closeTo(1.2, 1e-5));
        tm.setTransform(pivot, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

        rig.camera.setProjection(fovDegrees: 40, aspect: rig.width / rig.height, near: 0.1, far: 100);
        rig.camera.lookAt(eyeX: 0, eyeY: 2.2, eyeZ: 5, centerX: 0, centerY: 0.5, centerZ: 0);
        final first = rig.renderFrame();
        expect(countForegroundPixels(first, rig.width), greaterThan(rig.width * rig.height ~/ 40));

        final last = rig.video(
          'TransformManager Smoke Tests TransformManager: parent/child hierarchy orbits real props (video)',
          onFrame: (frame, t) {
            final a = t * math.pi; // half turn
            final ca = math.cos(a), sa = math.sin(a);
            tm.setTransform(pivot, [ca, 0, -sa, 0, 0, 1, 0, 0, sa, 0, ca, 0, 0, 0, 0, 1]);
          },
        );
        final changed = countChangedPixels(first, last);
        print('orbit changed pixels=$changed');
        expect(changed, greaterThan(1000), reason: 'half-turn swaps the props left/right');
      } finally {
        ac.dispose(rig.scene);
        barrel.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
