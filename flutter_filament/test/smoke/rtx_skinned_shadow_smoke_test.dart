import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

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
    // The bundled KTX IBL: reflections, SH and a rotation of its own, which also turns the
    // world the colour pass shades in.
    rig.addIbl();
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
          if (lit[i * 4 + 1] - img[i * 4 + 1] > 10) out.add(i);
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

  test('rtx Smoke Tests ray-traced sun shadow follows the sun under a rotated IBL', () async {
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
    const name = 'rtx Smoke Tests ray-traced sun shadow follows the sun under a rotated IBL';
    final sun = rig.addSun(intensity: 110000);
    final ibl = rig.addIbl();
    final lm = FilamentLightManager(engine);
    final tm = FilamentTransformManager(engine);
    final floorMaterial = buildLitMaterial(engine);
    final floorInstance = floorMaterial.createInstance()..setFloat3('baseColor', 0.85, 0.83, 0.8);
    final floorQuad = SmokeQuad.create(engine, size: 12, tangents: true);
    final floor = addQuadRenderable(rig, floorQuad, floorInstance, extent: 6);
    tm.setTransform(floor, [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
    final character = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
    SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/mannequin/MF_Unarmed_Walk_Fwd.glb');
    try {
      final box = character.asset.getBoundingBox();
      tm.setTransform(character.asset.rootEntity,
          [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -box.center.x, -box.min.y, -box.center.z, 1]);
      character.asset.animator
        ..applyAnimation(0, 0)
        ..updateBoneMatrices();
      rig.camera.setProjection(fovDegrees: 40, aspect: rig.width / rig.height, near: 0.1, far: 200);
      rig.camera.lookAt(eyeX: 1.2, eyeY: 3.4, eyeZ: 5.2, centerX: 0.9, centerY: 0.4, centerZ: 0);
      rig.view.shadowingEnabled = true;
      rig.scene.rayTracingEnabled = true;

      Uint8List render({required bool shadows, bool rayTraced = true}) {
        lm.setShadowCaster(sun, shadows);
        lm.setShadowOptions(sun, ShadowOptions(mapSize: 4096, shadowCascades: 1, rayTraced: rayTraced));
        return rig.renderFrame(warmup: 2);
      }

      Set<int> shadowed(Uint8List lit, Uint8List img) {
        final out = <int>{};
        for (var i = 0; i < rig.width * rig.height; i++) {
          if (lit[i * 4 + 1] - img[i * 4 + 1] > 10) out.add(i);
        }
        return out;
      }

      // The KTX IBL as loaded (it carries its own rotation), then turned further about Y and
      // about X, under two low suns: the ray-traced shadow lies where the shadow maps put it.
      final rotations = <String, Matrix3?>{
        'as loaded': null,
        'turned 90 degrees about Y': Matrix3.rotationY(1.5708),
        'tilted 30 degrees about X': Matrix3.rotationX(0.5236),
      };
      const suns = [(-0.85, -0.55, -0.25), (0.6, -0.5, 0.6)];
      for (final MapEntry(key: label, value: rotation) in rotations.entries) {
        if (rotation != null) ibl.rotation = rotation;
        for (final (s, (x, y, z)) in suns.indexed) {
          lm.setDirection(sun, x, y, z);
          final lit = render(shadows: false);
          final rt = render(shadows: true);
          final csm = render(shadows: true, rayTraced: false);
          final a = shadowed(lit, rt);
          final b = shadowed(lit, csm);
          final union = a.union(b).length;
          final iou = union == 0 ? 0.0 : a.intersection(b).length / union;
          smokeLog('IBL $label, sun $s: ray-traced ${a.length} shadowed texels, shadow maps ${b.length}, '
              'IoU ${iou.toStringAsFixed(2)}');
          final side = Uint8List(rig.width * 2 * rig.height * 4);
          for (var y = 0; y < rig.height; y++) {
            final row = y * rig.width * 4;
            side.setRange(y * rig.width * 8, y * rig.width * 8 + rig.width * 4, rt, row);
            side.setRange(y * rig.width * 8 + rig.width * 4, (y + 1) * rig.width * 8, csm, row);
          }
          SmokeArtifacts.saveScreenshot('$name IBL $label sun ${s + 1} (ray-traced left, shadow maps right)',
              SmokeArtifacts.encodePng(rig.width * 2, rig.height, side));
          expect(b.length, greaterThan(2000), reason: 'IBL $label, sun $s: the shadow maps draw a shadow');
          expect(iou, greaterThan(0.8), reason: 'IBL $label, sun $s: the ray-traced shadow lies where the shadow maps put it');
        }
      }

      // ReSTIR's visibility rays under the same rotations: one point light beside the
      // character, its shadow (visibility rays on against off) the same for every rotation.
      rig.scene.removeEntity(sun);
      ibl.setIntensity(3000);
      final point = engine.createEntity();
      LightBuilder(LightType.point)
        ..color(1, 0.95, 0.9)
        ..intensity(400000)
        ..position(1.2, 1.4, 0.6)
        ..falloff(10)
        ..build(engine, point);
      rig.scene.addEntity(point);
      rig.entities.add(point);
      Set<int>? reference;
      for (final MapEntry(key: label, value: rotation) in {'identity': Matrix3.identity(), ...rotations}.entries) {
        ibl.rotation = rotation ?? Matrix3.rotationY(0.5);
        Uint8List restir({required bool visibility}) {
          rig.view.restirOptions = RestirOptions(enabled: true, temporal: false, visibilityRays: visibility);
          return rig.renderFrame(warmup: 2);
        }

        final lit = restir(visibility: false);
        final img = restir(visibility: true);
        final shadow = shadowed(lit, img);
        SmokeArtifacts.saveScreenshot('$name ReSTIR point light shadow, IBL $label',
            SmokeArtifacts.encodePng(rig.width, rig.height, img));
        if (reference == null) {
          reference = shadow;
          smokeLog('ReSTIR, IBL $label: ${shadow.length} shadowed texels');
          expect(shadow.length, greaterThan(2000), reason: 'the visibility rays draw the point light shadow');
          continue;
        }
        final union = shadow.union(reference).length;
        final iou = union == 0 ? 0.0 : shadow.intersection(reference).length / union;
        smokeLog('ReSTIR, IBL $label: ${shadow.length} shadowed texels, IoU ${iou.toStringAsFixed(2)} against identity');
        expect(iou, greaterThan(0.8), reason: 'IBL $label: the ReSTIR shadow does not move with the IBL rotation');
      }
      rig.view.restirOptions = const RestirOptions();
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
