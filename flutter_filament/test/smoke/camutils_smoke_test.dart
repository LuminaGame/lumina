// camutils smoke: an ORBIT manipulator built with ManipulatorBuilder drives
// the camera around the Draco helicopter via grab / scroll / update; the
// orbit is recorded as a WebM and lookAt / raycast results asserted.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Camutils Smoke Tests', () {
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

    test('Camutils: orbit manipulator grabs, zooms and orbits the helicopter (video)', () {
      final gltf = loadGltfIntoScene(rig, 'fixtures/attackhelicopter.entity.glb', frameCamera: false);
      try {
        final box = gltf.asset.getBoundingBox();
        final c = box.center;
        final radius = (box.max - box.min).length / 2;
        final builder = ManipulatorBuilder()
          ..viewport(rig.width, rig.height)
          ..targetPosition(c.x, c.y, c.z)
          ..orbitHomePosition(c.x, c.y + radius * 0.5, c.z + radius * 3)
          ..upVector(0, 1, 0)
          ..zoomSpeed(0.05)
          ..fovDegrees(45)
          ..farPlane(radius * 100);
        final manip = builder.build(ManipulatorMode.orbit);
        builder.dispose();
        rig.camera.setProjection(fovDegrees: 45, aspect: rig.width / rig.height, near: 0.05, far: radius * 100);

        final home = manip.getLookAt();
        expect(home.eye[2], closeTo(c.z + radius * 3, 1e-3));
        expect(home.center[0], closeTo(c.x, 1e-3));
        manip.updateCamera(rig.camera);
        expect(rig.camera.position.z, closeTo(c.z + radius * 3, 1e-3));

        // A ray through the viewport centre hits the target plane.
        final hit = manip.raycast(rig.width ~/ 2, rig.height ~/ 2);
        expect(hit, isNotNull);
        expect(hit![2], closeTo(c.z, radius));

        final first = rig.renderFrame();
        expect(countForegroundPixels(first, rig.width), greaterThan(rig.width * rig.height ~/ 60));

        manip.grabBegin(rig.width ~/ 2, rig.height ~/ 2);
        final last = rig.video(
          'Camutils Smoke Tests Camutils: orbit manipulator grabs, zooms and orbits the helicopter (video)',
          onFrame: (frame, t) {
            manip.grabUpdate(rig.width ~/ 2 + (t * 220).round(), rig.height ~/ 2 + (t * 40).round());
            manip.update(1 / 30);
            manip.updateCamera(rig.camera);
          },
        );
        manip.grabEnd();
        final after = manip.getLookAt();
        expect((after.eye[0] - home.eye[0]).abs() + (after.eye[2] - home.eye[2]).abs(), greaterThan(radius * 0.5),
            reason: 'drag orbits the eye around the target');
        expect(countChangedPixels(first, last), greaterThan(500));

        manip.scroll(rig.width ~/ 2, rig.height ~/ 2, -10);
        manip.updateCamera(rig.camera);
        final zoomed = manip.getLookAt();
        double dist(List<double> e) {
          final dx = e[0] - c.x, dy = e[1] - c.y, dz = e[2] - c.z;
          return dx * dx + dy * dy + dz * dz;
        }
        print('orbit home=${home.eye} after=${after.eye} zoomed=${zoomed.eye}');
        expect(dist(zoomed.eye), lessThan(dist(after.eye)), reason: 'scroll zooms in');

        final bookmark = manip.currentBookmark;
        manip.jumpToBookmark(manip.homeBookmark);
        final backHome = manip.getLookAt();
        expect(dist(backHome.eye), closeTo(dist(home.eye), dist(home.eye) * 0.1), reason: 'home bookmark restores the orbit radius');
        expect((backHome.eye[0] - home.eye[0]).abs(), lessThan(1.0));
        bookmark.dispose();
        manip.dispose();
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
