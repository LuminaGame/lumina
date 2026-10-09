import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// DLSS Ray Reconstruction: NGX `dlssd` as an HDR-stage external upscaler fed
/// by the guide buffers, denoising ReSTIR lighting. The runtime is optional
/// (fetched by `tool/dlss/fetch_sdk.dart`, never committed).
void main() {
  test(
    'without a Vulkan device: not supported and create throws naming the feature',
    () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final view = engine.createView();
      try {
        expect(DlssRayReconstruction.available, anyOf(isTrue, isFalse));
        expect(DlssRayReconstruction.supported(engine), isFalse);
        expect(
          () => DlssRayReconstruction.create(
            engine: engine,
            view: view,
            options: const DlssRayReconstructionOptions(
              outputWidth: 640,
              outputHeight: 360,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Ray Reconstruction'),
            ),
          ),
        );
        expect(
          const DlssRayReconstructionOptions(
            outputWidth: 1,
            outputHeight: 1,
          ).preset,
          DlssRayReconstructionPreset.f,
        );
      } finally {
        view.dispose();
        engine.dispose();
      }
    },
  );

  group('DLSS Ray Reconstruction on an RTX GPU (Vulkan)', () {
    SmokeRig? rig;
    final materials = <FilamentMaterial>[];
    final instances = <FilamentMaterialInstance>[];
    final quads = <SmokeQuad>[];
    final props = <LoadedGltf>[];
    DlssRayReconstruction? rr;

    void boot(int width, int height) {
      if (!DlssRayReconstruction.available) return;
      Dlss.requestExtensions();
      RayTracing.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: width, height: height);
    }

    tearDown(() {
      rr?.destroy();
      rr = null;
      final r = rig;
      if (r != null) {
        for (final p in props) {
          p.dispose(r.scene);
        }
        for (final e in r.entities) {
          r.engine.destroyEntity(e);
        }
        r.entities.clear();
      }
      props.clear();
      for (final mi in instances) {
        mi.dispose();
      }
      instances.clear();
      for (final m in materials) {
        m.dispose();
      }
      materials.clear();
      for (final q in quads) {
        q.dispose();
      }
      quads.clear();
      rig?.dispose();
      rig = null;
      Dlss.clearExtensionRequest();
      RayTracing.clearExtensionRequest();
    });

    bool skipWithoutRr() {
      if (!DlssRayReconstruction.available) {
        markTestSkipped(
          'nvngx_dlssd not available (run tool/dlss/fetch_sdk.dart on an RTX machine)',
        );
        return true;
      }
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      if (!rig!.engine.supportsRayQuery ||
          !DlssRayReconstruction.supported(rig!.engine)) {
        markTestSkipped(
          'this GPU or driver has no ray query or Ray Reconstruction: ${DlssRayReconstruction.lastErrorMessage}',
        );
        return true;
      }
      return false;
    }

    /// A lit floor, two props and [lightCount] point lights shaded by ReSTIR with one
    /// visibility ray per pixel: the noisy signal Ray Reconstruction is for.
    void restirScene(SmokeRig r, {int lightCount = 64}) {
      final floor = buildLitMaterial(r.engine);
      materials.add(floor);
      final mi = floor.createInstance()
        ..setFloat3('baseColor', 0.75, 0.75, 0.75);
      instances.add(mi);
      final quad = SmokeQuad.create(r.engine, size: 12, tangents: true);
      quads.add(quad);
      final e = addQuadRenderable(r, quad, mi, extent: 12);
      FilamentTransformManager(
        r.engine,
      ).setTransform(e, [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
      final ac = loadGltfIntoScene(
        r,
        'Props/AC_units/ac_unit_a_300x300.glb',
        frameCamera: false,
      );
      final card = loadGltfIntoScene(
        r,
        'Props/Access_cards/access_card_red.glb',
        frameCamera: false,
      );
      props
        ..add(ac)
        ..add(card);
      final tm = FilamentTransformManager(r.engine);
      final box = ac.asset.getBoundingBox();
      final s = 1.5 / math.max(box.max.y - box.min.y, box.max.x - box.min.x);
      tm.setTransform(ac.asset.rootEntity, [
        s,
        0,
        0,
        0,
        0,
        s,
        0,
        0,
        0,
        0,
        s,
        0,
        -box.center.x * s,
        -box.min.y * s,
        -box.center.z * s,
        1,
      ]);
      final cbox = card.asset.getBoundingBox();
      final cs =
          0.8 / math.max(cbox.max.x - cbox.min.x, cbox.max.z - cbox.min.z);
      tm.setTransform(card.asset.rootEntity, [
        cs,
        0,
        0,
        0,
        0,
        cs,
        0,
        0,
        0,
        0,
        cs,
        0,
        1.4,
        -cbox.min.y * cs,
        0.8,
        1,
      ]);
      final rnd = math.Random(11);
      for (var i = 0; i < lightCount; i++) {
        final le = r.engine.createEntity();
        LightBuilder(LightType.point)
          ..color(
            0.4 + 0.6 * rnd.nextDouble(),
            0.4 + 0.6 * rnd.nextDouble(),
            0.4 + 0.6 * rnd.nextDouble(),
          )
          ..intensity(600000 / lightCount)
          ..position(
            rnd.nextDouble() * 6 - 3,
            0.3 + rnd.nextDouble() * 1.5,
            rnd.nextDouble() * 6 - 3,
          )
          ..falloff(3 + rnd.nextDouble() * 3)
          ..build(r.engine, le);
        r.scene.addEntity(le);
        r.entities.add(le);
      }
      r.camera.setProjection(
        fovDegrees: 50,
        aspect: r.width / r.height,
        near: 0.05,
        far: 100,
      );
      r.camera.lookAt(
        eyeX: 0.5,
        eyeY: 2.0,
        eyeZ: 4.5,
        centerX: 0,
        centerY: 0.5,
        centerZ: 0,
      );
      r.camera.setExposure(
        aperture: 16,
        shutterSpeed: 1 / 125,
        sensitivity: 100,
      );
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true);
    }

    /// Mean over pixels of the per-pixel standard deviation of luma across [frames]
    /// still frames.
    double temporalNoise(SmokeRig r, int frames) {
      final n = r.width * r.height;
      final sum = Float64List(n);
      final sumSq = Float64List(n);
      for (var f = 0; f < frames; f++) {
        final px = r.renderFrame(warmup: 0);
        for (var i = 0; i < n; i++) {
          final y =
              0.2126 * px[i * 4] +
              0.7152 * px[i * 4 + 1] +
              0.0722 * px[i * 4 + 2];
          sum[i] += y;
          sumSq[i] += y * y;
        }
      }
      var total = 0.0;
      for (var i = 0; i < n; i++) {
        final mean = sum[i] / frames;
        total += math.sqrt(math.max(0, sumSq[i] / frames - mean * mean));
      }
      return total / n;
    }

    double psnr(Uint8List a, Float64List reference) {
      var se = 0.0;
      var count = 0;
      for (var i = 0; i < a.length; i += 4) {
        for (var k = 0; k < 3; k++) {
          final d = a[i + k] - reference[i + k];
          se += d * d;
          count++;
        }
      }
      final mse = se / count;
      return mse == 0
          ? double.infinity
          : 10 * math.log(255 * 255 / mse) / math.ln10;
    }

    test(
      'create at Balanced: NGX render resolution, guides and TAA on, no error after 30 frames',
      () {
        boot(1920, 1080);
        if (skipWithoutRr()) return;
        final r = rig!;
        restirScene(r);
        rr = DlssRayReconstruction.create(
          engine: r.engine,
          view: r.view,
          options: const DlssRayReconstructionOptions(
            quality: DlssQuality.balanced,
            outputWidth: 1920,
            outputHeight: 1080,
          ),
        );
        final (rw, rh) = rr!.renderResolution;
        smokeLog('ray reconstruction balanced render ${rw}x$rh -> 1920x1080');
        expect(rw, inInclusiveRange(1000, 1200));
        expect(rh, inInclusiveRange(560, 680));
        expect(r.view.guideBufferOptions.enabled, isTrue);
        expect(r.view.temporalAntiAliasingOptions.enabled, isTrue);
        expect(r.view.temporalAntiAliasingOptions.motionVectors, isTrue);
        expect(r.view.dynamicResolutionOptions.upscaler, Upscaler.external);
        final frame = r.renderFrame(warmup: 29);
        expect(rr!.lastError, isNull);
        expect(rr!.frameCount, greaterThanOrEqualTo(30));
        expect(frame.length, 1920 * 1080 * 4);
        expect(frameStats(frame).distinct, greaterThan(200));
        final gpu = rr!.lastGpuTimeNanos;
        smokeLog(
          'ray reconstruction GPU time at 1920x1080 (balanced, ${rw}x$rh): ${(gpu / 1e6).toStringAsFixed(3)} ms',
        );
        expect(gpu, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Ray Reconstruction lowers the temporal noise of one-ray ReSTIR versus TAA, PSNR against an accumulated reference',
      () {
        const w = 1280;
        const h = 720;
        boot(w, h);
        if (skipWithoutRr()) return;
        final r = rig!;
        restirScene(r);
        final results = <String>[];
        // Two signals: Lumina's default ReSTIR (temporal and spatial reuse already smooth it)
        // and a raw one (two candidates, no reuse), the kind of noise RR is trained for.
        final configs = {
          'default ReSTIR': const RestirOptions(enabled: true),
          'raw ReSTIR (2 candidates, no reuse)': const RestirOptions(
            enabled: true,
            initialCandidates: 2,
            spatialSamples: 0,
            temporal: false,
          ),
        };
        final ratios = <String, double>{};
        for (final entry in configs.entries) {
          r.view.restirOptions = entry.value;
          rr?.destroy();
          rr = null;
          r.view.temporalAntiAliasingOptions =
              const TemporalAntiAliasingOptions(
                enabled: true,
                motionVectors: true,
              );
          r.view.resetRestirHistory();
          // reference: 128 accumulated native frames with Filament's TAA
          r.renderFrame(warmup: 30);
          final reference = Float64List(w * h * 4);
          const accumulate = 128;
          for (var f = 0; f < accumulate; f++) {
            final px = r.renderFrame(warmup: 0);
            for (var i = 0; i < px.length; i++) {
              reference[i] += px[i] / accumulate;
            }
          }
          final taaNoise = temporalNoise(r, 16);
          final taaFrame = r.renderFrame(warmup: 0);

          rr = DlssRayReconstruction.create(
            engine: r.engine,
            view: r.view,
            options: const DlssRayReconstructionOptions(
              quality: DlssQuality.maxQuality,
              outputWidth: w,
              outputHeight: h,
            ),
          );
          r.renderFrame(warmup: 40);
          final rrNoise = temporalNoise(r, 16);
          final rrFrame = r.renderFrame(warmup: 0);
          expect(rr!.lastError, isNull);
          final taaPsnr = psnr(taaFrame, reference);
          final rrPsnr = psnr(rrFrame, reference);
          ratios[entry.key] = rrNoise / taaNoise;
          results.add(
            '${entry.key}: temporal noise (mean per-pixel luma stddev over 16 frames, 0..255) '
            'TAA ${taaNoise.toStringAsFixed(3)}, Ray Reconstruction ${rrNoise.toStringAsFixed(3)} '
            '(${(100 * rrNoise / taaNoise).toStringAsFixed(1)} %); PSNR against the 128-frame TAA reference: '
            'TAA ${taaPsnr.toStringAsFixed(2)} dB, Ray Reconstruction ${rrPsnr.toStringAsFixed(2)} dB',
          );
        }
        results.forEach(smokeLog);
        for (final entry in ratios.entries) {
          expect(
            entry.value,
            lessThan(1.0),
            reason: 'Ray Reconstruction is less noisy than TAA on ${entry.key}',
          );
        }
        expect(
          ratios['raw ReSTIR (2 candidates, no reuse)'],
          lessThanOrEqualTo(0.5),
          reason:
              'on raw one-ray lighting Ray Reconstruction halves the noise at least',
        );
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    test(
      'reset changes the next frame; destroy restores the view options and leaks nothing',
      () {
        boot(960, 540);
        if (skipWithoutRr()) return;
        final r = rig!;
        restirScene(r, lightCount: 16);
        r.engine.flushAndWait();
        final before = r.engine.resourceCounts;
        expect(r.view.guideBufferOptions.enabled, isFalse);
        rr = DlssRayReconstruction.create(
          engine: r.engine,
          view: r.view,
          options: const DlssRayReconstructionOptions(
            quality: DlssQuality.balanced,
            outputWidth: 960,
            outputHeight: 540,
          ),
        );
        final converged = r.renderFrame(warmup: 30);
        rr!.resetHistory();
        final afterReset = r.renderFrame(warmup: 0);
        expect(
          countChangedPixels(converged, afterReset, tolerance: 2),
          greaterThan(0),
        );
        rr!.quality = DlssQuality.maxPerformance;
        r.renderFrame(warmup: 3);
        expect(rr!.lastError, isNull);
        rr!.destroy();
        rr = null;
        expect(r.view.guideBufferOptions.enabled, isFalse);
        expect(r.view.temporalAntiAliasingOptions.enabled, isFalse);
        expect(r.view.dynamicResolutionOptions.upscaler, Upscaler.builtin);
        final frame = r.renderFrame(warmup: 2);
        expect(frameStats(frame).distinct, greaterThan(50));
        r.engine.flushAndWait();
        expect(
          r.engine.resourceCounts.textures,
          before.textures,
          reason: 'no leaked textures',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
