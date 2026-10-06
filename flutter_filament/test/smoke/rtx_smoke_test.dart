import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

/// Motion vectors on a real animated character: the walking mannequin under a
/// slowly orbiting camera, TAA reprojecting its history with the per-pixel
/// velocity the structure pass renders. Publishes the final frame, the
/// velocity buffer visualised as colour, and a 10 s video of the run.
void main() {
  group('rtx Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      rig.addSun();
      rig.addIbl();
    });

    tearDown(() => rig.dispose());

    test('motion vectors on an animated character', () async {
      if (!rig.view.motionVectorsSupported) {
        markTestSkipped('motion vectors need a GPU backend at feature level 1+ ($smokeBackendName)');
        return;
      }
      const name = 'rtx Smoke Tests motion vectors on an animated character';
      final gltf = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      final motion = MotionVectorBuffer.attach(engine: rig.engine, view: rig.view, width: rig.width, height: rig.height);
      try {
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        final dist = radius * 2.4 + 0.1;
        rig.camera.setProjection(fovDegrees: 45, aspect: rig.width / rig.height, near: dist * 0.01, far: dist * 20);
        rig.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);

        void orbit(double t) {
          final angle = 0.6 + t * math.pi * 0.5;
          rig.camera.lookAt(
            eyeX: center.x + dist * math.sin(angle),
            eyeY: center.y + dist * 0.35,
            eyeZ: center.z + dist * math.cos(angle),
            centerX: center.x,
            centerY: center.y,
            centerZ: center.z,
          );
        }

        final last = rig.video(name, onFrame: (frame, t) {
          orbit(t);
          animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
          animator.updateBoneMatrices();
        }, alsoScreenshot: false);
        SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(rig.width, rig.height, last));

        final velocity = await motion.read(rig.renderer);
        var moving = 0;
        var maxAbs = 0.0;
        final visual = Uint8List(rig.width * rig.height * 4);
        for (var y = 0; y < rig.height; y++) {
          for (var x = 0; x < rig.width; x++) {
            final (vx, vy) = motion.velocityAt(velocity, x, y);
            final m = vx.abs() + vy.abs();
            if (m > 0.5) moving++;
            if (m > maxAbs) maxAbs = m;
            final i = (y * rig.width + x) * 4;
            visual[i] = (128 + vx * 16).round().clamp(0, 255);
            visual[i + 1] = (128 + vy * 16).round().clamp(0, 255);
            visual[i + 2] = (m * 24).round().clamp(0, 255);
            visual[i + 3] = 255;
          }
        }
        SmokeArtifacts.saveScreenshot('$name (velocity)', SmokeArtifacts.encodePng(rig.width, rig.height, visual));
        smokeLog('velocity: moving texels=$moving maxAbs=${maxAbs.toStringAsFixed(2)}');
        // The orbiting camera moves the whole character on screen every frame.
        expect(moving, greaterThan(rig.width * rig.height ~/ 200), reason: 'the character must carry motion');
        expect(maxAbs, lessThan(rig.width.toDouble()), reason: 'no runaway velocities');
        final stats = frameStats(last);
        expect(stats.distinct, greaterThan(200), reason: 'a shaded character must be visible');
      } finally {
        motion.dispose();
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('DLSS Balanced upscaling of an animated character', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped('DLSS needs the Vulkan backend ($smokeBackendName)');
        return;
      }
      if (!Dlss.available) {
        markTestSkipped('DLSS runtime not available (tool/dlss/fetch_sdk.dart on an RTX machine)');
        return;
      }
      // The engine of the shared rig was created without the NGX extensions; this
      // scenario owns an engine created after the request.
      rig.dispose();
      expect(Dlss.requestExtensions(), isTrue);
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      rig = SmokeRig.adopt(engine, width: 1024, height: 768);
      rig.addSun();
      const name = 'rtx Smoke Tests DLSS Balanced upscaling of an animated character';
      final gltf = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      Dlss? dlss;
      try {
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        final dist = radius * 2.4 + 0.1;
        rig.camera.setProjection(fovDegrees: 45, aspect: rig.width / rig.height, near: dist * 0.01, far: dist * 20);
        rig.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);

        void orbit(double t) {
          final angle = 0.6 + t * math.pi * 0.5;
          rig.camera.lookAt(
            eyeX: center.x + dist * math.sin(angle),
            eyeY: center.y + dist * 0.35,
            eyeZ: center.z + dist * math.cos(angle),
            centerX: center.x,
            centerY: center.y,
            centerZ: center.z,
          );
        }

        void pose(int frame) {
          animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
          animator.updateBoneMatrices();
        }

        // The native-resolution reference of the final pose, Filament's own TAA.
        final frames = (10 * smokeVideoFps).round();
        orbit(1.0);
        pose(frames);
        Uint8List? reference;
        for (var i = 0; i < 8; i++) {
          reference = rig.renderFrame(warmup: 0);
        }

        dlss = Dlss.create(
          engine: rig.engine,
          view: rig.view,
          options: DlssOptions(quality: DlssQuality.balanced, outputWidth: rig.width, outputHeight: rig.height),
        );
        final (rw, rh) = dlss.renderResolution;
        smokeLog('dlss balanced render ${rw}x$rh -> ${rig.width}x${rig.height}');
        orbit(0.0);
        pose(0);
        dlss.resetHistory();
        final last = rig.video(name, onFrame: (frame, t) {
          orbit(t);
          pose(frame);
        }, alsoScreenshot: false);
        expect(dlss.lastError, isNull, reason: 'NGX reported no error during the clip');
        expect(last.length, rig.width * rig.height * 4, reason: 'the output is the full 1024x768 frame');

        // Side by side: DLSS output on the left, the native reference on the right.
        final side = Uint8List(rig.width * 2 * rig.height * 4);
        for (var y = 0; y < rig.height; y++) {
          final row = y * rig.width * 4;
          side.setRange(y * rig.width * 8, y * rig.width * 8 + rig.width * 4, last, row);
          side.setRange(y * rig.width * 8 + rig.width * 4, (y + 1) * rig.width * 8, reference!, row);
        }
        SmokeArtifacts.saveScreenshot('$name (DLSS left, native right)', SmokeArtifacts.encodePng(rig.width * 2, rig.height, side));
        final stats = frameStats(last);
        expect(stats.distinct, greaterThan(200), reason: 'a shaded character must be visible in the DLSS output');
        final before = rig.engine.resourceCounts;
        dlss.destroy();
        dlss = null;
        rig.engine.flushAndWait();
        expect(rig.engine.resourceCounts.textures, lessThanOrEqualTo(before.textures), reason: 'no leaked handles');
      } finally {
        dlss?.destroy();
        gltf.dispose(rig.scene);
        Dlss.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('ray-traced sun shadows over props', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped('ray tracing needs the Vulkan backend ($smokeBackendName)');
        return;
      }
      // The engine of the shared rig was created without the ray query extensions;
      // this scenario owns an engine created after the request.
      rig.dispose();
      smokeLog('rt-smoke: shared rig disposed');
      expect(RayTracing.requestExtensions(), isTrue);
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      rig = SmokeRig.adopt(engine, width: 1024, height: 768);
      smokeLog('rt-smoke: engine ready');
      if (!engine.supportsRayQuery) {
        RayTracing.clearExtensionRequest();
        markTestSkipped('this GPU or driver has no Vulkan ray query support');
        return;
      }
      const name = 'rtx Smoke Tests ray-traced sun shadows over props';
      final sun = rig.addSun(intensity: 110000);
      rig.addIbl(intensity: 12000);
      final lm = FilamentLightManager(engine);
      final tm = FilamentTransformManager(engine);

      // A lit floor that receives the shadows: a 14 m quad lying flat.
      final floorMaterial = buildLitMaterial(engine);
      final floorInstance = floorMaterial.createInstance()..setFloat3('baseColor', 0.82, 0.8, 0.76);
      final floorQuad = SmokeQuad.create(engine, size: 14, tangents: true);
      final floor = addQuadRenderable(rig, floorQuad, floorInstance, extent: 7);
      // +Z of the quad becomes +Y: rotate -90 degrees about X.
      tm.setTransform(floor, [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
      smokeLog('rt-smoke: floor ready');

      // Four different props standing on the floor, a walking character among them.
      const props = [
        ('Props/Barrels/fuel_barrel_red.glb', -3.2, 0.6),
        ('Props/AC_units/ac_unit_a_300x300.glb', -1.1, -0.4),
        ('Props/Access_cards/access_card_blue.glb', 1.0, 0.9),
        ('Props/Barrels/dented_barrel.glb', 3.0, -0.2),
      ];
      final loaded = <LoadedGltf>[];
      void place(LoadedGltf gltf, double x, double z) {
        final box = gltf.asset.getBoundingBox();
        tm.setTransform(gltf.asset.rootEntity, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x - box.center.x, -box.min.y, z - box.center.z, 1]);
      }

      try {
        for (final (path, x, z) in props) {
          final gltf = loadGltfIntoScene(rig, path, frameCamera: false);
          loaded.add(gltf);
          place(gltf, x, z);
        }
        smokeLog('rt-smoke: props ready');
        final character = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
        loaded.add(character);
        final animator = character.asset.animator;
        final duration = animator.getAnimationDuration(0);
        animator.applyAnimation(0, 0);
        animator.updateBoneMatrices();
        place(character, 0.0, -2.2);

        rig.camera.setProjection(fovDegrees: 40, aspect: rig.width / rig.height, near: 0.1, far: 200);
        rig.camera.lookAt(eyeX: 0.5, eyeY: 4.2, eyeZ: 9.5, centerX: 0, centerY: 0.9, centerZ: -0.3);
        rig.view.shadowingEnabled = true;
        rig.scene.rayTracingEnabled = true;
        lm.setShadowCaster(sun, true);

        void orbitSun(double t) {
          final a = t * math.pi * 1.2 - 0.4;
          lm.setDirection(sun, math.sin(a) * 0.75, -1.0, math.cos(a) * 0.75);
        }

        void pose(int frame) {
          animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
          animator.updateBoneMatrices();
        }

        lm.setShadowOptions(sun, ShadowOptions(mapSize: 2048, shadowCascades: 1, rayTraced: true));
        orbitSun(0);
        pose(0);
        smokeLog('rt-smoke: character ready');
        rig.renderFrame(warmup: 3);
        smokeLog('rt-smoke: first frame');
        expect(rig.scene.tlasInstanceCount, greaterThanOrEqualTo(6), reason: 'floor, four props and the character');

        final buildTimes = <Duration>[];
        final last = rig.video(name, onFrame: (frame, t) {
          orbitSun(t);
          pose(frame);
          final build = rig.scene.lastTlasBuildTime;
          if (build > Duration.zero) buildTimes.add(build);
        }, alsoScreenshot: false);
        expect(buildTimes, isNotEmpty, reason: 'the TLAS build timer resolved during the clip');
        final averageMicros = buildTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds) / buildTimes.length;
        smokeLog('tlas instances ${rig.scene.tlasInstanceCount}, average build ${averageMicros.toStringAsFixed(0)} us');
        expect(averageMicros, lessThan(4000), reason: 'TLAS build under 4 ms on average');

        // Side by side at the final pose: ray-traced on the left, cascaded shadow maps on the right.
        lm.setShadowOptions(sun, ShadowOptions(mapSize: 2048, shadowCascades: 1, rayTraced: false));
        Uint8List? csm;
        for (var i = 0; i < 4; i++) {
          csm = rig.renderFrame(warmup: 0);
        }
        final side = Uint8List(rig.width * 2 * rig.height * 4);
        for (var y = 0; y < rig.height; y++) {
          final row = y * rig.width * 4;
          side.setRange(y * rig.width * 8, y * rig.width * 8 + rig.width * 4, last, row);
          side.setRange(y * rig.width * 8 + rig.width * 4, (y + 1) * rig.width * 8, csm!, row);
        }
        SmokeArtifacts.saveScreenshot('$name (ray-traced left, shadow maps right)', SmokeArtifacts.encodePng(rig.width * 2, rig.height, side));
        expect(frameStats(last).distinct, greaterThan(200), reason: 'a shaded scene must be visible');
        expect(countChangedPixels(last, csm!, tolerance: 24), greaterThan(0), reason: 'the two shadow techniques differ somewhere');

        final before = engine.resourceCounts;
        for (final gltf in loaded) {
          gltf.dispose(rig.scene);
        }
        loaded.clear();
        engine.flushAndWait();
        rig.renderFrame(warmup: 2);
        expect(engine.resourceCounts.bufferObjects, lessThanOrEqualTo(before.bufferObjects), reason: 'no leaked handles');
      } finally {
        for (final gltf in loaded) {
          gltf.dispose(rig.scene);
        }
        // the floor renderable goes before the material instance and buffers it uses
        engine.destroyEntity(floor);
        rig.entities.remove(floor);
        floorInstance.dispose();
        floorMaterial.dispose();
        floorQuad.dispose();
        RayTracing.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
