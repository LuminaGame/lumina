// frame_pacing smoke: a FramePacer drives a synthetic 60 Hz vsync tick
// stream while a barrel spins one step per accepted frame; the paced frames
// are recorded as a WebM and the pacer/estimator state asserted.
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('FramePacing Smoke Tests', () {
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

    test('FramePacing: pacer accepts vsync ticks and spins a barrel per frame (video)', () {
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/radbarrel.glb');
      try {
        final pacer = rig.engine.createFramePacer(targetFrameRate: 60.0, latency: const Duration(microseconds: 33333));
        expect(pacer.configuration.targetFrameRate, 60.0);
        pacer.configure(const FramePacerConfiguration(targetFrameRate: 30.0));
        expect(pacer.configuration.targetFrameRate, 30.0);
        pacer.resetPacing();

        const periodNs = 16666666;
        var base = DateTime.now().microsecondsSinceEpoch * 1000;
        var accepted = 0, skipped = 0;
        final tm = FilamentTransformManager(rig.engine);
        final root = gltf.asset.rootEntity;
        final first = rig.renderFrame();

        // The video runs at the pacer's 30 Hz: every recorded frame spans two
        // synthetic 60 Hz ticks, one accepted and one skipped, for the full
        // 10 s, so the barrel turns on every recorded frame.
        final frames = smokeVideoFrames();
        final last = rig.video(
          'FramePacing Smoke Tests FramePacing: pacer accepts vsync ticks and spins a barrel per frame (video)',
          frames: frames,
          onFrame: (frame, t) {
            for (var tick = 0; tick < 2; tick++) {
              base += periodNs;
              final status = pacer.setupFrame(VsyncTick(baseTimeNs: base, vsyncPeriodNs: periodNs));
              if (status.shouldRender) {
                accepted++;
                pacer.applyPresentationTime(rig.renderer);
              } else {
                skipped++;
              }
            }
            final a = accepted * (math.pi / 60);
            tm.setTransform(root, [math.cos(a), 0, -math.sin(a), 0, 0, 1, 0, 0, math.sin(a), 0, math.cos(a), 0, 0, 0, 0, 1]);
          },
        );
        print('pacer accepted=$accepted skipped=$skipped status=${pacer.pacingStatus} '
            'latency=${pacer.effectiveLatency} rate=${pacer.selectedFrameRate}');
        // 30 Hz target on 60 Hz ticks: every other tick is accepted.
        expect(accepted, inInclusiveRange(frames - 2, frames + 2),
            reason: 'half of the ${2 * frames} 60 Hz ticks are accepted at 30 Hz');
        expect(skipped, greaterThan(0));
        expect(pacer.effectiveLatency.inMicroseconds, greaterThanOrEqualTo(0));
        expect(pacer.selectedFrameRate, closeTo(30, 0.1));
        expect(pacer.selectedFrameRate, greaterThan(0));
        expect(pacer.hasGpuFallenBehind(rig.renderer), isA<bool>());
        expect(countChangedPixels(first, last), greaterThan(500), reason: 'barrel rotated');

        final history = rig.renderer.getFrameInfoHistory(8);
        final workload = FramePipelineEstimator.estimateWorkload(history);
        expect(workload, isNotNull);
        expect(pacer.isDisposed, isFalse);
        rig.engine.destroyFramePacer(pacer);
        expect(pacer.isDisposed, isTrue);
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
