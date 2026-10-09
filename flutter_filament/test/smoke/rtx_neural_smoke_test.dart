import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

/// The hooks Lumina's official NVIDIA neural rendering path builds on: the
/// external post pass (the HDR frame, depth and motion with history validity
/// before colour grading), on a real animated character under a moving camera.
void main() {
  group('rtx neural Smoke Tests', () {
    SmokeRig? rig;

    tearDown(() {
      rig?.dispose();
      rig = null;
    });

    test('external post pass visualises motion and history', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped(
          'the external post pass needs the Vulkan backend ($smokeBackendName)',
        );
        return;
      }
      final r = rig = SmokeRig.create(
        width: smokeVideoWidth,
        height: smokeVideoHeight,
      );
      r.addSun();
      r.addIbl();
      const name =
          'rtx neural Smoke Tests external post pass visualises motion and history';
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      DebugPostPass? pass;
      try {
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        final dist = radius * 2.4 + 0.1;
        r.camera.setProjection(
          fovDegrees: 45,
          aspect: r.width / r.height,
          near: dist * 0.01,
          far: dist * 20,
        );
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true,
          motionVectors: true,
        );
        pass = DebugPostPass.create(
          engine: r.engine,
          view: r.view,
          mode: DebugPostPassMode.motion,
        );

        // Three segments: motion, history (with a camera cut in its middle), passthrough.
        final frames = smokeVideoFrames();
        final third = frames ~/ 3;
        var cut = 0.0;
        final shots = <DebugPostPassMode, Uint8List>{};
        DebugPostPassMode modeAt(int frame) => frame < third
            ? DebugPostPassMode.motion
            : frame < 2 * third
            ? DebugPostPassMode.history
            : DebugPostPassMode.passthrough;

        final last = r.video(
          name,
          onFrame: (frame, t) {
            final mode = modeAt(frame);
            if (pass!.mode != mode) pass.mode = mode;
            if (frame == third + third ~/ 2) {
              // a camera cut: the next frame has no usable history
              cut = 1.4;
              r.view.resetExternalPostPassHistory();
            }
            final angle = 0.6 + t * math.pi * 0.6 + cut;
            r.camera.lookAt(
              eyeX: center.x + dist * math.sin(angle),
              eyeY: center.y + dist * 0.35,
              eyeZ: center.z + dist * math.cos(angle),
              centerX: center.x,
              centerY: center.y,
              centerZ: center.z,
            );
            animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
            animator.updateBoneMatrices();
          },
          alsoScreenshot: false,
        );
        shots[DebugPostPassMode.passthrough] = last;

        // One still per mode after the clip, the camera still orbiting and the character
        // walking (motion), then a camera cut (history).
        var step = 0;
        void advance() {
          step++;
          final angle = 0.6 + math.pi * 0.6 + cut + step * 0.02;
          r.camera.lookAt(
            eyeX: center.x + dist * math.sin(angle),
            eyeY: center.y + dist * 0.35,
            eyeZ: center.z + dist * math.cos(angle),
            centerX: center.x,
            centerY: center.y,
            centerZ: center.z,
          );
          animator.applyAnimation(
            0,
            ((frames + step) / smokeVideoFps) % duration,
          );
          animator.updateBoneMatrices();
        }

        pass.mode = DebugPostPassMode.motion;
        advance();
        r.renderFrame(warmup: 0);
        advance();
        shots[DebugPostPassMode.motion] = r.renderFrame(warmup: 0);
        pass.mode = DebugPostPassMode.history;
        cut += 0.5;
        advance();
        shots[DebugPostPassMode.history] = r.renderFrame(warmup: 0);
        for (final entry in shots.entries) {
          SmokeArtifacts.saveScreenshot(
            '$name (${entry.key.name})',
            SmokeArtifacts.encodePng(r.width, r.height, entry.value),
          );
        }
        expect(
          pass.frameCount,
          greaterThanOrEqualTo(frames),
          reason: 'the pass ran on every frame',
        );
        expect(pass.lastSize, (r.width, r.height));
        expect(
          frameStats(last).distinct,
          greaterThan(200),
          reason: 'the character must be visible through the pass',
        );
      } finally {
        pass?.destroy();
        gltf.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
