import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// The UI overlay of direct presentation with frame generation: drawn after
/// the frame-generation view, it is drawn again over every generated present,
/// so the presents per rendered frame stay what the generator makes. Also
/// measures what the overlay costs.
void main() {
  group('UI overlay with frame generation (Vulkan, no vsync)', () {
    SmokeRig? rig;
    LoadedGltf? gltf;
    FilamentUiOverlay? overlay;
    const w = 1024, h = 768;

    setUp(() {
      if (DlssFrameGeneration.available) {
        Dlss.requestExtensions();
        DlssFrameGeneration.requestExtensions();
      }
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: w, height: h, swapChainFlags: SwapChainConfig.disableVsync);
      rig!.addSun();
      gltf = loadGltfIntoScene(rig!, 'Props/AC_units/ac_unit_a_300x300.glb');
      rig!.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(motionVectors: true);
      overlay = FilamentUiOverlay.create(engine)!..setViewport(0, 0, w, h);
      final ui = Uint8List(w * h * 4);
      // A HUD bar along the top and a button in the middle.
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final bar = y < 48;
          final button = x > 412 && x < 612 && y > 360 && y < 410;
          if (bar || button) ui.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, const [20, 20, 20, 200]);
        }
      }
      overlay!.upload(ui, w, h);
    });

    tearDown(() {
      overlay?.dispose();
      overlay = null;
      if (gltf != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
      Dlss.clearExtensionRequest();
      DlssFrameGeneration.clearExtensionRequest();
    });

    /// Presents per second, interval CV, presents per rendered frame and the
    /// mean CPU time of a frame (begin to end) over [frames] frames of an
    /// uncapped loop with 8 ms of game work per frame.
    (double, double, double, double) measure(SmokeRig r, int frames, {required bool withOverlay}) {
      final tm = FilamentTransformManager(r.engine);
      final root = gltf!.asset.rootEntity;
      r.engine.flushAndWait();
      final before = r.renderer.getPresentTimes(1024);
      final start = before.isEmpty ? 0 : before.last;
      var rendered = 0;
      var frameUs = 0;
      final clock = Stopwatch()..start();
      for (var i = 0; rendered < frames && i < frames * 20; i++) {
        tm.setTransform(root, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.002 * i, 0, 0, 1]);
        final t0 = clock.elapsedMicroseconds;
        if (r.renderer.beginFrame(r.swapChain)) {
          r.renderer.render(r.view);
          if (withOverlay) overlay!.render(r.renderer);
          r.renderer.endFrame();
          rendered++;
          frameUs += clock.elapsedMicroseconds - t0;
        }
        final until = clock.elapsedMicroseconds + 8000;
        while (clock.elapsedMicroseconds < until) {}
      }
      r.engine.flushAndWait();
      final times = r.renderer.getPresentTimes(1024).where((t) => t > start).toList();
      final intervals = [for (var i = 1; i < times.length; i++) (times[i] - times[i - 1]) / 1e6];
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final sd = math.sqrt(intervals.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / intervals.length);
      return (1000 / mean, sd / mean, times.length / rendered, frameUs / rendered / 1000);
    }

    String fmt((double, double, double, double) m) => '${m.$1.toStringAsFixed(1)} presents/s, cv '
        '${m.$2.toStringAsFixed(2)}, ${m.$3.toStringAsFixed(2)} per rendered frame, ${m.$4.toStringAsFixed(2)} ms CPU/frame';

    test('DLSS frame generation presents every generated frame with the overlay', () {
      if (!DlssFrameGeneration.available || rig == null) {
        markTestSkipped('needs nvngx_dlssg and a Vulkan device');
        return;
      }
      final r = rig!;
      final probe = DlssFrameGeneration.probe(r.engine);
      if (probe == null || !probe.available) {
        markTestSkipped('Frame Generation not available here: $probe');
        return;
      }
      measure(r, 20, withOverlay: true);
      final off = measure(r, 100, withOverlay: false);
      final offUi = measure(r, 100, withOverlay: true);
      smokeLog('overlay, frame generation off: without ${fmt(off)}; with ${fmt(offUi)}');
      expect(offUi.$3, closeTo(1, 0.05));
      for (final generated in [1, 3]) {
        if (generated > probe.multiFrameCountMax) continue;
        final generator = DlssFrameGenerator.create(engine: r.engine, view: r.view, generatedFrames: generated);
        try {
          measure(r, 20, withOverlay: true);
          final on = measure(r, 100, withOverlay: true);
          smokeLog('overlay, DLSS ${generated + 1}x: ${fmt(on)}');
          expect(on.$3, closeTo(generated + 1, 0.05), reason: '${generated + 1} presents per rendered frame');
          expect(on.$1, greaterThan(offUi.$1 * (generated + 1) * 0.7));
        } finally {
          generator.destroy();
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('FSR3 frame generation presents the interpolated frame with the overlay', () {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final r = rig!;
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true, motionVectors: true, algorithm: TaaAlgorithm.fsr3, frameGeneration: true);
      measure(r, 20, withOverlay: true);
      final on = measure(r, 100, withOverlay: true);
      smokeLog('overlay, FSR3 frame generation: ${fmt(on)}');
      expect(on.$3, closeTo(2, 0.05));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('upload cost of a full-window UI picture', () {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      for (final (pw, ph) in [(1920, 1080), (3440, 1440)]) {
        final picture = Uint8List(pw * ph * 4);
        final micros = <int>[];
        for (var i = 0; i < 20; i++) {
          picture[i] = i;
          expect(overlay!.upload(picture, pw, ph), isTrue);
          micros.add(overlay!.lastUploadMicros);
        }
        rig!.engine.flushAndWait();
        micros.sort();
        smokeLog('overlay upload ${pw}x$ph: median ${(micros[10] / 1000).toStringAsFixed(2)} ms '
            '(min ${(micros.first / 1000).toStringAsFixed(2)}, max ${(micros.last / 1000).toStringAsFixed(2)})');
      }
    });
  });
}
