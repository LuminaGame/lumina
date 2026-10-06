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
  });
}
