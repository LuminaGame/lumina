// scene smoke: bulk add/remove of a real multi-entity GLB and hasEntity /
// renderable-count bookkeeping, rendered before and after removal.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Scene Smoke Tests', () {
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

    test('Scene: bulk entity operations on a real GLB change what renders', () {
      final gltf = loadGltfIntoScene(rig, 'fixtures/attackhelicopter.entity.glb');
      try {
        final ents = gltf.asset.renderableEntities;
        expect(ents.length, greaterThan(1), reason: 'helicopter is split into several meshes');
        for (final e in ents) {
          expect(rig.scene.hasEntity(e), isTrue);
        }
        expect(rig.scene.renderableCount, greaterThanOrEqualTo(ents.length));
        final full = rig.screenshot('Scene Smoke Tests Scene: bulk entity operations on a real GLB change what renders');
        final fullFg = countForegroundPixels(full, rig.width);
        expect(fullFg, greaterThan(rig.width * rig.height ~/ 40));

        rig.scene.removeEntities(ents);
        for (final e in ents) {
          expect(rig.scene.hasEntity(e), isFalse);
        }
        final empty = rig.renderFrame();
        final emptyFg = countForegroundPixels(empty, rig.width);

        rig.scene.addEntities(ents);
        expect(rig.scene.hasEntity(ents.first), isTrue);
        final back = rig.renderFrame();
        final backFg = countForegroundPixels(back, rig.width);
        print('scene renderables=${rig.scene.renderableCount} fg full=$fullFg empty=$emptyFg back=$backFg');
        expect(emptyFg, lessThan(fullFg ~/ 10));
        expect(backFg, closeTo(fullFg, fullFg * 0.05));

        rig.scene.removeAllEntities();
        expect(rig.scene.hasEntity(ents.first), isFalse);
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
