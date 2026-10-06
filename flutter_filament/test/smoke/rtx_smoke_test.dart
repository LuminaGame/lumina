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
        // Disposing an engine right after TAA frames crashes (a Filament issue
        // independent of motion vectors); a plain frame first avoids it.
        rig.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions();
        rig.renderFrame(warmup: 1);
        motion.dispose();
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
