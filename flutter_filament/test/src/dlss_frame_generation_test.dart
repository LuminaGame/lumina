import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// DLSS Frame Generation through NGX directly (no Streamline): availability,
/// the requirements NGX reports, and the interpolator that runs the network
/// inside Filament's frame.
void main() {
  test('without a Vulkan device there is no frame generation', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final view = engine.createView();
    try {
      expect(DlssFrameGeneration.probe(engine), isNull);
      expect(
        () => DlssFrameInterpolator.create(engine: engine, view: view),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Frame Generation'),
          ),
        ),
      );
    } finally {
      view.dispose();
      engine.dispose();
    }
  });

  group('DLSS Frame Generation on an RTX GPU (Vulkan)', () {
    SmokeRig? rig;
    LoadedGltf? gltf;
    DlssFrameInterpolator? interpolator;

    setUp(() {
      if (!DlssFrameGeneration.available) return;
      Dlss.requestExtensions();
      DlssFrameGeneration.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: 1024, height: 768);
      rig!.addSun();
    });

    tearDown(() {
      interpolator?.destroy();
      interpolator = null;
      if (gltf != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
      Dlss.clearExtensionRequest();
      DlssFrameGeneration.clearExtensionRequest();
    });

    bool skip() {
      if (!DlssFrameGeneration.available) {
        markTestSkipped(
          'nvngx_dlssg not available (tool/dlss/fetch_sdk.dart on an RTX machine)',
        );
        return true;
      }
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      return false;
    }

    test(
      'the probe reports availability, the multi-frame limit and the extensions NGX wants',
      () {
        if (skip()) return;
        final probe = DlssFrameGeneration.probe(rig!.engine);
        smokeLog('frame generation probe on ${rig!.engine.gpuName}: $probe');
        expect(probe, isNotNull, reason: DlssFrameGeneration.lastErrorMessage);
        for (final ext in probe!.deviceExtensions) {
          smokeLog(
            '  $ext enabled: ${VulkanFeatures.isExtensionEnabled(rig!.engine, ext)}',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'the interpolator generates a frame between two rendered frames of a moving prop',
      () async {
        if (skip()) return;
        final r = rig!;
        final probe = DlssFrameGeneration.probe(r.engine);
        if (probe == null || !probe.available) {
          markTestSkipped(
            'Frame Generation not available here: $probe ${DlssFrameGeneration.lastErrorMessage}',
          );
          return;
        }
        gltf = loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb');
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          motionVectors: true,
        );
        final tm = FilamentTransformManager(r.engine);
        final root = gltf!.asset.rootEntity;
        void place(double x) => tm.setTransform(root, [
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          x,
          0,
          0,
          1,
        ]);
        const step = 0.15;
        // the true midpoint, rendered
        place(step * 0.5);
        final midpoint = r.renderFrame(warmup: 2);
        place(0);
        final a = r.renderFrame(warmup: 2);
        place(step);
        final b = r.renderFrame(warmup: 0);

        interpolator = DlssFrameInterpolator.create(
          engine: r.engine,
          view: r.view,
        );
        place(0);
        r.renderFrame(warmup: 2);
        place(step);
        final generated = r.renderFrame(warmup: 0);
        smokeLog(
          'interpolator: frames ${interpolator!.frameCount}, last result 0x${interpolator!.lastResult.toRadixString(16)}, '
          'GPU ${(interpolator!.lastGpuTimeNanos / 1e6).toStringAsFixed(3)} ms, error ${DlssFrameGeneration.lastErrorMessage}',
        );
        expect(
          interpolator!.frameCount,
          greaterThan(0),
          reason: DlssFrameGeneration.lastErrorMessage,
        );

        double psnr(Uint8List x, Uint8List y) {
          var se = 0.0;
          for (var i = 0; i < x.length; i += 4) {
            for (var k = 0; k < 3; k++) {
              final d = (x[i + k] - y[i + k]).toDouble();
              se += d * d;
            }
          }
          final mse = se / (x.length / 4 * 3);
          return mse == 0
              ? double.infinity
              : 10 * math.log(255 * 255 / mse) / math.ln10;
        }

        smokeLog(
          'PSNR generated vs midpoint ${psnr(generated, midpoint).toStringAsFixed(2)} dB, '
          'vs previous ${psnr(generated, a).toStringAsFixed(2)} dB, vs current ${psnr(generated, b).toStringAsFixed(2)} dB, '
          'previous vs current ${psnr(a, b).toStringAsFixed(2)} dB',
        );
        expect(countChangedPixels(generated, a, tolerance: 4), greaterThan(0));
        expect(countChangedPixels(generated, b, tolerance: 4), greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    /// Renders [frames] frames of a prop sliding across the view and returns the present
    /// times that belong to them.
    List<int> presentsOf(SmokeRig r, int frames) {
      final tm = FilamentTransformManager(r.engine);
      final root = gltf!.asset.rootEntity;
      final before = r.renderer.getPresentTimes();
      final start = before.isEmpty ? 0 : before.last;
      for (var i = 0; i < frames; i++) {
        tm.setTransform(root, [
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0.01 * i,
          0,
          0,
          1,
        ]);
        r.renderFrame(warmup: 0);
      }
      return r.renderer.getPresentTimes().where((t) => t > start).toList();
    }

    (double, double) intervalStats(List<int> times) {
      final intervals = [
        for (var i = 1; i < times.length; i++) (times[i] - times[i - 1]) / 1e6,
      ];
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance =
          intervals
              .map((x) => (x - mean) * (x - mean))
              .reduce((a, b) => a + b) /
          intervals.length;
      return (mean, math.sqrt(variance));
    }

    for (final generatedFrames in [1, 3, 5]) {
      test(
        'generating $generatedFrames frame(s) presents ${generatedFrames + 1} frames per rendered frame',
        () {
          if (skip()) return;
          final r = rig!;
          final probe = DlssFrameGeneration.probe(r.engine);
          if (probe == null || !probe.available) {
            markTestSkipped('Frame Generation not available here: $probe');
            return;
          }
          if (generatedFrames > probe.multiFrameCountMax) {
            expect(
              () => DlssFrameGenerator.create(
                engine: r.engine,
                view: r.view,
                generatedFrames: generatedFrames,
              ),
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('RTX 50'),
                ),
              ),
            );
            markTestSkipped(
              'this GPU generates at most ${probe.multiFrameCountMax} frames',
            );
            return;
          }
          gltf = loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb');
          r.view.temporalAntiAliasingOptions =
              const TemporalAntiAliasingOptions(motionVectors: true);
          presentsOf(r, 3);
          final generator = DlssFrameGenerator.create(
            engine: r.engine,
            view: r.view,
            generatedFrames: generatedFrames,
          );
          try {
            presentsOf(r, 3); // first frames: no history yet
            final presents = presentsOf(r, 20);
            smokeLog(
              '${generatedFrames + 1}x: ${presents.length} presents for 20 rendered frames, '
              'NGX result 0x${generator.lastResult.toRadixString(16)}, '
              'GPU ${(generator.lastGpuTimeNanos / 1e6).toStringAsFixed(3)} ms per rendered frame',
            );
            expect(
              generator.lastResult,
              1,
              reason: DlssFrameGeneration.lastErrorMessage,
            );
            expect(presents.length, 20 * (generatedFrames + 1));
            expect(generator.frameCount, greaterThanOrEqualTo(20));
          } finally {
            generator.destroy();
          }
          final after = presentsOf(r, 5);
          expect(
            after.length,
            5,
            reason: 'one present per frame once the generator is gone',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }

    test(
      'without vsync the generated and rendered frames are presented evenly spaced',
      () {
        if (skip()) return;
        final probe = DlssFrameGeneration.probe(rig!.engine);
        if (probe == null || !probe.available) {
          markTestSkipped('Frame Generation not available here: $probe');
          return;
        }
        // a second rig on the same engine whose SwapChain presents without vsync
        final r = SmokeRig.adopt(
          rig!.engine,
          width: 1024,
          height: 768,
          swapChainFlags: SwapChainConfig.disableVsync,
        );
        r.addSun();
        gltf = loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb');
        final ownGltf = gltf!;
        DlssFrameGenerator? generator;
        try {
          r.view.temporalAntiAliasingOptions =
              const TemporalAntiAliasingOptions(motionVectors: true);
          final plain = presentsOf(r, 40);
          final (plainMean, plainSd) = intervalStats(plain);
          final count = math.min(3, math.max(1, probe.multiFrameCountMax));
          generator = DlssFrameGenerator.create(
            engine: r.engine,
            view: r.view,
            generatedFrames: count,
          );
          presentsOf(r, 10);
          // at most 128 present times are kept: 30 rendered frames of up to 4 presents
          final generated = presentsOf(r, 30);
          final (mean, sd) = intervalStats(generated);
          smokeLog(
            'pacing without vsync: plain ${plain.length} presents, interval ${plainMean.toStringAsFixed(2)} '
            '± ${plainSd.toStringAsFixed(2)} ms (cv ${(plainSd / plainMean).toStringAsFixed(2)}, '
            '${(1000 / plainMean).toStringAsFixed(1)} presents/s); ${count + 1}x ${generated.length} presents, interval '
            '${mean.toStringAsFixed(2)} ± ${sd.toStringAsFixed(2)} ms (cv ${(sd / mean).toStringAsFixed(2)}, '
            '${(1000 / mean).toStringAsFixed(1)} presents/s)',
          );
          expect(generated.length, 30 * (count + 1));
          // The render thread itself waits between the presents of one frame, so the frame
          // interval stretches with the presents and the rate of presents stays close to the
          // rendering rate (see the DLSS documentation page); what must hold is that the presents
          // of one rendered frame are spaced out, not submitted back to back.
          final bunched = [
            for (var i = 1; i < generated.length; i++) generated[i] - generated[i - 1],
          ].where((ns) => ns < 1000000).length;
          smokeLog('intervals under 1 ms: $bunched of ${generated.length - 1}');
          expect(
            bunched,
            lessThanOrEqualTo((generated.length - 1) ~/ 10),
            reason: 'paced presents, not bunched',
          );
        } finally {
          generator?.destroy();
          ownGltf.dispose(r.scene);
          gltf = null;
          r.disposeViewport();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
