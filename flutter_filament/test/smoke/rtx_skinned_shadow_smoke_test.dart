import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

/// Ray-traced sun shadows of an animated character follow its pose: the
/// walking mannequin on a lit floor under a low sun, its skinned geometry
/// re-posed for the acceleration structures every frame. Publishes a 10 s
/// video and, at three moments of the walk, the ray-traced shadow beside the
/// shadow-map one.
void main() {
  test('rtx Smoke Tests ray-traced shadow of a walking character follows its pose', () async {
    if (smokeBackend != FilamentBackend.vulkan) {
      markTestSkipped('ray tracing needs the Vulkan backend ($smokeBackendName)');
      return;
    }
    expect(RayTracing.requestExtensions(), isTrue);
    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
    final rig = SmokeRig.adopt(engine, width: smokeVideoWidth, height: smokeVideoHeight);
    if (!engine.supportsRayQuery) {
      rig.dispose();
      RayTracing.clearExtensionRequest();
      markTestSkipped('this GPU or driver has no Vulkan ray query support');
      return;
    }
    const name = 'rtx Smoke Tests ray-traced shadow of a walking character follows its pose';
    final sun = rig.addSun(intensity: 110000);
    // An irradiance-only ambient (a reflections cubemap from a KTX IBL turns the ray-traced
    // sun shadow direction wrong, a separate bug).
    final ambient = FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.55, 0.58, 0.65]), intensity: 22000);
    rig.scene.setIndirectLight(ambient);
    final lm = FilamentLightManager(engine);
    final tm = FilamentTransformManager(engine);

    final floorMaterial = buildLitMaterial(engine);
    final floorInstance = floorMaterial.createInstance()..setFloat3('baseColor', 0.85, 0.83, 0.8);
    final floorQuad = SmokeQuad.create(engine, size: 12, tangents: true);
    final floor = addQuadRenderable(rig, floorQuad, floorInstance, extent: 6);
    // +Z of the quad becomes +Y: rotate -90 degrees about X.
    tm.setTransform(floor, [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);

    final character = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
    SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/mannequin/MF_Unarmed_Walk_Fwd.glb');
    try {
      final box = character.asset.getBoundingBox();
      tm.setTransform(character.asset.rootEntity,
          [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -box.center.x, -box.min.y, -box.center.z, 1]);
      final animator = character.asset.animator;
      final duration = animator.getAnimationDuration(0);
      void pose(double time) {
        animator.applyAnimation(0, time % duration);
        animator.updateBoneMatrices();
      }

      // A low sun from the side throws a long shadow of the limbs onto the floor.
      lm.setDirection(sun, -0.85, -0.55, -0.25);
      lm.setShadowCaster(sun, true);
      rig.camera.setProjection(fovDegrees: 40, aspect: rig.width / rig.height, near: 0.1, far: 200);
      rig.camera.lookAt(eyeX: 1.2, eyeY: 3.4, eyeZ: 5.2, centerX: 0.9, centerY: 0.4, centerZ: 0);
      rig.view.shadowingEnabled = true;
      rig.scene.rayTracingEnabled = true;

      Uint8List render({required bool shadows, bool rayTraced = true}) {
        lm.setShadowCaster(sun, shadows);
        lm.setShadowOptions(sun, ShadowOptions(mapSize: 4096, shadowCascades: 1, rayTraced: rayTraced));
        return rig.renderFrame(warmup: 2);
      }

      // texels a shadow darkens, against the same frame without shadows
      Set<int> shadowed(Uint8List lit, Uint8List img) {
        final out = <int>{};
        for (var i = 0; i < rig.width * rig.height; i++) {
          if (lit[i * 4 + 1] - img[i * 4 + 1] > 25) out.add(i);
        }
        return out;
      }

      // At three moments of the walk: the ray-traced shadow covers the shadow-map
      // one (same pose, same sun), and it moves between the moments.
      final rtShadows = <Set<int>>[];
      for (final (i, fraction) in [0.0, 0.33, 0.66].indexed) {
        pose(duration * fraction);
        final lit = render(shadows: false);
        final rt = render(shadows: true);
        final csm = render(shadows: true, rayTraced: false);
        final a = shadowed(lit, rt);
        final b = shadowed(lit, csm);
        final union = a.union(b).length;
        final iou = union == 0 ? 0.0 : a.intersection(b).length / union;
        smokeLog('pose $i: ray-traced ${a.length} shadowed texels, shadow maps ${b.length}, IoU ${iou.toStringAsFixed(2)}');
        final side = Uint8List(rig.width * 2 * rig.height * 4);
        for (var y = 0; y < rig.height; y++) {
          final row = y * rig.width * 4;
          side.setRange(y * rig.width * 8, y * rig.width * 8 + rig.width * 4, rt, row);
          side.setRange(y * rig.width * 8 + rig.width * 4, (y + 1) * rig.width * 8, csm, row);
        }
        SmokeArtifacts.saveScreenshot('$name pose ${i + 1} (ray-traced left, shadow maps right)',
            SmokeArtifacts.encodePng(rig.width * 2, rig.height, side));
        expect(b.length, greaterThan(2000), reason: 'pose $i: the shadow maps draw a shadow');
        expect(iou, greaterThan(0.6), reason: 'pose $i: the ray-traced shadow has the shape of the posed character');
        rtShadows.add(a);
      }
      final moved = rtShadows[0].difference(rtShadows[1]).length + rtShadows[1].difference(rtShadows[0]).length;
      expect(moved, greaterThan(1000), reason: 'the ray-traced shadow changes with the pose');

      // The clip: the walk with ray-traced shadows, timing the posing passes.
      lm.setShadowCaster(sun, true);
      lm.setShadowOptions(sun, ShadowOptions(mapSize: 4096, shadowCascades: 1, rayTraced: true));
      final deformTimes = <Duration>[];
      var posedFrames = 0;
      rig.video(name, onFrame: (frame, t) {
        if (rig.scene.deformedBlasCount > 0) posedFrames++;
        final d = rig.scene.lastBlasDeformTime;
        if (d > Duration.zero) deformTimes.add(d);
        pose(frame / smokeVideoFps);
      }, alsoScreenshot: true);
      expect(posedFrames, greaterThan(smokeVideoFrames() - 3), reason: 'every frame of the walk re-poses it');
      expect(deformTimes, isNotEmpty);
      final average = deformTimes.fold<int>(0, (s, d) => s + d.inMicroseconds) / deformTimes.length;
      smokeLog('posing + refit ${average.toStringAsFixed(0)} us per frame, TLAS build ${rig.scene.lastTlasBuildTime.inMicroseconds} us');
      expect(average, lessThan(2000), reason: 'posing one character costs well under 2 ms');
    } finally {
      character.dispose(rig.scene);
      engine.destroyEntity(floor);
      rig.entities.remove(floor);
      floorInstance.dispose();
      floorMaterial.dispose();
      floorQuad.dispose();
      rig.dispose();
      RayTracing.clearExtensionRequest();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
