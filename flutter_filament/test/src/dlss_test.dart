import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// DLSS Super Resolution: NVIDIA NGX behind Filament's dynamic resolution.
/// The NGX runtime is optional (fetched by `tool/dlss/fetch_sdk.dart`, never
/// committed); without it every entry point reports "not available" and the
/// engine renders as before.
void main() {
  group('DLSS without a GPU (noop backend)', () {
    late FilamentEngine engine;
    late FilamentView view;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      view = engine.createView();
    });
    tearDown(() {
      view.dispose();
      engine.dispose();
    });

    test('the upscaler option defaults to builtin and the mirror keeps the native size', () {
      expect(const DynamicResolutionOptions().upscaler, Upscaler.builtin);
      const opts = DynamicResolutionOptions(enabled: true, upscaler: Upscaler.external);
      view.dynamicResolutionOptions = opts;
      expect(view.dynamicResolutionOptions.upscaler, Upscaler.external);
      expect(c.filament_options_sizeof(0), ffi.sizeOf<c.filament_dynamic_resolution_options>());
    });

    test('no Vulkan device: not available, extension request is a harmless no-op, create throws', () {
      // With the noop engine there is no Vulkan device, whether or not the
      // NGX runtime is on this machine.
      expect(Dlss.requestExtensions(), anyOf(isTrue, isFalse));
      expect(
        () => Dlss.create(engine: engine, view: view, options: const DlssOptions(outputWidth: 640, outputHeight: 360)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('DLSS'))),
      );
      // The engine still renders: a frame on the noop backend completes.
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(64, 64);
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }
      swapChain.dispose();
      renderer.dispose();
    });
  });

  group('DLSS on an RTX GPU (Vulkan)', () {
    const outputWidth = 1920;
    const outputHeight = 1080;
    SmokeRig? rig;
    LoadedGltf? gltf;
    Dlss? dlss;
    var extensionsRequested = false;

    setUp(() {
      if (!Dlss.available) return;
      extensionsRequested = Dlss.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: outputWidth, height: outputHeight);
      rig!.addSun();
    });

    tearDown(() {
      dlss?.destroy();
      dlss = null;
      if (gltf != null && rig != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
    });

    bool skipWithoutDlss() {
      if (!Dlss.available) {
        markTestSkipped('DLSS runtime not available (run tool/dlss/fetch_sdk.dart on an RTX machine)');
        return true;
      }
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      return false;
    }

    /// Pixels of the model: those that differ from the clear colour in [reference].
    List<int> modelPixels(Uint8List reference) {
      final clear = (reference[0], reference[1], reference[2]);
      final out = <int>[];
      for (var i = 0; i < reference.length; i += 4) {
        final d = (reference[i] - clear.$1).abs() + (reference[i + 1] - clear.$2).abs() + (reference[i + 2] - clear.$3).abs();
        if (d > 24) out.add(i);
      }
      return out;
    }

    double psnr(Uint8List a, Uint8List b, List<int> pixels) {
      var sum = 0.0;
      for (final i in pixels) {
        for (var k = 0; k < 3; k++) {
          final d = (a[i + k] - b[i + k]).toDouble();
          sum += d * d;
        }
      }
      final mse = sum / (pixels.length * 3);
      if (mse == 0) return double.infinity;
      return 10 * math.log(255 * 255 / mse) / math.ln10;
    }

    test('create at Balanced reports the NGX optimal render resolution and drives dynamic resolution', () {
      if (skipWithoutDlss()) return;
      expect(extensionsRequested, isTrue, reason: 'NGX must have reported its extensions');
      final r = rig!;
      dlss = Dlss.create(
        engine: r.engine,
        view: r.view,
        options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: outputWidth, outputHeight: outputHeight),
      );
      expect(dlss!.lastError, isNull);
      final (rw, rh) = dlss!.renderResolution;
      // Balanced is a 58% scale: 1114x626 for 1080p on the current SDK, read
      // from NGX_DLSS_GET_OPTIMAL_SETTINGS rather than hardcoded.
      expect(rw, inInclusiveRange(1100, 1130));
      expect(rh, inInclusiveRange(615, 640));
      final dsr = r.view.dynamicResolutionOptions;
      expect(dsr.enabled, isTrue);
      expect(dsr.upscaler, Upscaler.external);
      expect(dsr.minScaleX, closeTo(rw / outputWidth, 1e-4));
      expect(dsr.maxScaleX, closeTo(rw / outputWidth, 1e-4));
      expect(dsr.minScaleY, closeTo(rh / outputHeight, 1e-4));
      expect(dsr.maxScaleY, closeTo(rh / outputHeight, 1e-4));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('30 frames of DLSS Balanced reconstruct a prop within 30 dB of the native render, reset changes the next frame', () {
      if (skipWithoutDlss()) return;
      final r = rig!;
      gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb');
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);

      // Native reference: full resolution, Filament's own TAA, no upscaling.
      r.view.dynamicResolutionOptions = const DynamicResolutionOptions(enabled: false);
      Uint8List? reference;
      for (var i = 0; i < 30; i++) {
        reference = r.renderFrame(warmup: 0);
      }

      dlss = Dlss.create(
        engine: r.engine,
        view: r.view,
        options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: outputWidth, outputHeight: outputHeight),
      );
      Uint8List? output;
      for (var i = 0; i < 30; i++) {
        output = r.renderFrame(warmup: 0);
      }
      expect(dlss!.lastError, isNull);
      expect(output!.length, outputWidth * outputHeight * 4, reason: 'the output is the full 1920x1080 frame');
      final pixels = modelPixels(reference!);
      expect(pixels.length, greaterThan(10000), reason: 'the barrel must cover a meaningful area');
      final quality = psnr(output, reference, pixels);
      smokeLog('dlss balanced psnr=${quality.toStringAsFixed(2)} dB over ${pixels.length} pixels');
      expect(quality, greaterThanOrEqualTo(30.0));

      dlss!.resetHistory();
      final afterReset = r.renderFrame(warmup: 0);
      var changed = 0;
      for (final i in pixels) {
        if ((afterReset[i] - output[i]).abs() > 1 || (afterReset[i + 1] - output[i + 1]).abs() > 1) changed++;
      }
      expect(changed, greaterThan(0), reason: 'a history reset must change the reconstruction');
      expect(dlss!.lastError, isNull);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('changing the quality recreates the feature with a smaller render resolution', () {
      if (skipWithoutDlss()) return;
      final r = rig!;
      gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb');
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
      dlss = Dlss.create(
        engine: r.engine,
        view: r.view,
        options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: outputWidth, outputHeight: outputHeight),
      );
      final (bw, bh) = dlss!.renderResolution;
      r.renderFrame(warmup: 2);
      dlss!.quality = DlssQuality.maxPerformance;
      final (pw, ph) = dlss!.renderResolution;
      expect(pw, lessThan(bw));
      expect(ph, lessThan(bh));
      r.renderFrame(warmup: 3);
      expect(dlss!.lastError, isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('two views with their own DLSS on one engine render at their own sizes', () {
      if (skipWithoutDlss()) return;
      final r = rig!;
      gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb');
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
      dlss = Dlss.create(
        engine: r.engine,
        view: r.view,
        options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: outputWidth, outputHeight: outputHeight),
      );
      final second = SmokeRig.adopt(r.engine, width: 1280, height: 720);
      second.view.scene = r.scene;
      final other = Dlss.create(
        engine: r.engine,
        view: second.view,
        options: const DlssOptions(quality: DlssQuality.maxQuality, outputWidth: 1280, outputHeight: 720),
      );
      try {
        second.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
        Uint8List? a;
        Uint8List? b;
        for (var i = 0; i < 8; i++) {
          a = r.renderFrame(warmup: 0);
          b = second.renderFrame(warmup: 0);
        }
        expect(a!.length, outputWidth * outputHeight * 4);
        expect(b!.length, 1280 * 720 * 4);
        expect(frameStats(a).distinct, greaterThan(50), reason: 'first view shows the barrel');
        expect(frameStats(b).distinct, greaterThan(50), reason: 'second view shows the barrel');
        expect(dlss!.lastError, isNull);
        expect(other.lastError, isNull);
        expect(dlss!.renderResolution, isNot(other.renderResolution));
      } finally {
        other.destroy();
        second.view.scene = second.scene;
        second.disposeViewport();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('destroy restores the builtin upscaler, is idempotent and leaks nothing', () {
      if (skipWithoutDlss()) return;
      final r = rig!;
      gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb');
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
      r.engine.flushAndWait();
      final before = r.engine.resourceCounts;
      final d = Dlss.create(
        engine: r.engine,
        view: r.view,
        options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: outputWidth, outputHeight: outputHeight),
      );
      r.renderFrame(warmup: 5);
      d.destroy();
      expect(r.view.dynamicResolutionOptions.upscaler, Upscaler.builtin);
      expect(r.view.dynamicResolutionOptions.enabled, isFalse);
      // FSR1 still renders when asked for.
      r.view.dynamicResolutionOptions = const DynamicResolutionOptions(
          enabled: true, minScaleX: 0.5, minScaleY: 0.5, maxScaleX: 0.5, maxScaleY: 0.5, quality: QualityLevel.ultra);
      final frame = r.renderFrame(warmup: 2);
      expect(frameStats(frame).distinct, greaterThan(50));
      d.destroy();
      r.engine.flushAndWait();
      final after = r.engine.resourceCounts;
      expect(after.textures, before.textures, reason: 'no leaked textures');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('DLSS on an engine created without the NGX extensions', () {
    test('create fails naming the missing extension and the engine keeps rendering with FSR1', () {
      if (!Dlss.available) {
        markTestSkipped('DLSS runtime not available');
        return;
      }
      // Dlss.requestExtensions() is deliberately not called here, so the engine's
      // Vulkan device lacks what NGX needs.
      Dlss.clearExtensionRequest();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final rig = SmokeRig.adopt(engine, width: 640, height: 360);
      rig.addSun();
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/empty_barrel.glb');
      try {
        expect(
          () => Dlss.create(
            engine: rig.engine,
            view: rig.view,
            options: const DlssOptions(outputWidth: 640, outputHeight: 360),
          ),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('VK_'))),
        );
        expect(Dlss.lastErrorMessage, contains('extension'));
        rig.view.dynamicResolutionOptions = const DynamicResolutionOptions(
            enabled: true, minScaleX: 0.5, minScaleY: 0.5, maxScaleX: 0.5, maxScaleY: 0.5, quality: QualityLevel.ultra);
        final frame = rig.renderFrame(warmup: 2);
        expect(frameStats(frame).distinct, greaterThan(50));
      } finally {
        gltf.dispose(rig.scene);
        rig.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
