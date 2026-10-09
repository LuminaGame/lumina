import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// The external post-pass hook: a pass recorded after TAA / FSR3 and before
/// bloom and colour grading, with the HDR colour, the depth and the motion
/// (plus history validity) at the colour's resolution.
void main() {
  test('the noop backend has no external post pass', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final view = engine.createView();
    try {
      expect(
        () => DebugPostPass.create(engine: engine, view: view),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Vulkan'),
          ),
        ),
      );
      // harmless without a pass
      view.resetExternalPostPassHistory();
    } finally {
      view.dispose();
      engine.dispose();
    }
  });

  group('external post pass on Vulkan', () {
    SmokeRig? rig;
    LoadedGltf? gltf;
    DebugPostPass? pass;

    void boot({int width = 512, int height = 384}) {
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: width, height: height);
      rig!.addSun();
      gltf = loadGltfIntoScene(rig!, 'Props/AC_units/ac_unit_a_300x300.glb');
    }

    tearDown(() {
      pass?.destroy();
      pass = null;
      if (gltf != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
    });

    bool skipWithoutVulkan() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      return false;
    }

    /// Fraction of pixels whose red exceeds green by a margin (history invalid
    /// tint) in the columns [x0, x1).
    double redShare(Uint8List rgba, int width, int height, int x0, int x1) {
      var red = 0;
      var total = 0;
      for (var y = 0; y < height; y += 2) {
        for (var x = x0; x < x1; x++) {
          final i = (y * width + x) * 4;
          total++;
          if (rgba[i] > rgba[i + 1] + 20) red++;
        }
      }
      return red / total;
    }

    /// Turns the camera right by [radians] about its own position.
    void yaw(SmokeRig r, double radians) {
      final eye = r.camera.position;
      final f = r.camera.forwardVector;
      final c = math.cos(radians);
      final s = math.sin(radians);
      final fx = f.x * c - f.z * s;
      final fz = f.x * s + f.z * c;
      r.camera.lookAt(
        eyeX: eye.x,
        eyeY: eye.y,
        eyeZ: eye.z,
        centerX: eye.x + fx,
        centerY: eye.y + f.y,
        centerZ: eye.z + fz,
      );
    }

    double meanChannel(Uint8List rgba, int channel) {
      var sum = 0;
      for (var i = channel; i < rgba.length; i += 4) {
        sum += rgba[i];
      }
      return sum / (rgba.length / 4);
    }

    test('passthrough renders the frame unchanged and runs once per frame', () {
      boot();
      if (skipWithoutVulkan()) return;
      final r = rig!;
      final reference = r.renderFrame(warmup: 6);
      final again = r.renderFrame(warmup: 3);
      pass = DebugPostPass.create(engine: r.engine, view: r.view);
      final before = pass!.frameCount;
      final through = r.renderFrame(warmup: 3);
      expect(
        pass!.frameCount - before,
        4,
        reason: 'four rendered frames, four evaluations',
      );
      expect(pass!.lastSize, (512, 384));
      // Consecutive frames of this scene already differ on shadow-edge pixels (the shadow
      // filter's per-frame noise); the copy must not change more than that noise does.
      (int, double) difference(Uint8List a, Uint8List b) {
        var differing = 0;
        var sum = 0;
        for (var i = 0; i < a.length; i += 4) {
          final d =
              (a[i] - b[i]).abs() +
              (a[i + 1] - b[i + 1]).abs() +
              (a[i + 2] - b[i + 2]).abs();
          sum += d;
          if (d > 3) differing++;
        }
        return (differing, sum / (a.length / 4));
      }

      final (noisePixels, noiseMean) = difference(reference, again);
      final (passPixels, passMean) = difference(again, through);
      smokeLog(
        'frame-to-frame noise: $noisePixels px, mean ${noiseMean.toStringAsFixed(3)}; '
        'with the passthrough: $passPixels px, mean ${passMean.toStringAsFixed(3)}',
      );
      expect(
        passPixels,
        lessThanOrEqualTo(noisePixels * 1.5 + 200),
        reason: 'the HDR copy must not change the graded frame',
      );
      expect(passMean, lessThanOrEqualTo(noiseMean * 1.5 + 0.1));
      expect(frameStats(through).distinct, greaterThan(50));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('invert rewrites the HDR frame before colour grading', () {
      boot();
      if (skipWithoutVulkan()) return;
      final r = rig!;
      final reference = r.renderFrame(warmup: 2);
      pass = DebugPostPass.create(
        engine: r.engine,
        view: r.view,
        mode: DebugPostPassMode.invert,
      );
      final inverted = r.renderFrame(warmup: 2);
      final a = meanChannel(reference, 2);
      final b = meanChannel(inverted, 2);
      smokeLog(
        'mean blue: reference ${a.toStringAsFixed(1)}, inverted ${b.toStringAsFixed(1)}',
      );
      expect((a - b).abs(), greaterThan(20));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'history is invalid on the first frame and after a reset, valid on a still camera, invalid where a pan reveals',
      () {
        boot();
        if (skipWithoutVulkan()) return;
        final r = rig!;
        pass = DebugPostPass.create(
          engine: r.engine,
          view: r.view,
          mode: DebugPostPassMode.history,
        );
        final first = r.renderFrame(warmup: 0);
        expect(
          redShare(first, 512, 384, 0, 512),
          greaterThan(0.95),
          reason: 'no previous frame',
        );
        final still = r.renderFrame(warmup: 3);
        expect(
          redShare(still, 512, 384, 0, 512),
          lessThan(0.02),
          reason: 'a still camera keeps every pixel',
        );

        // turn the camera right: the right edge shows what the previous frame never saw
        yaw(r, 0.2);
        final panned = r.renderFrame(warmup: 0);
        final rightEdge = redShare(panned, 512, 384, 500, 512);
        final middle = redShare(panned, 512, 384, 200, 300);
        smokeLog(
          'pan: right edge invalid ${rightEdge.toStringAsFixed(2)}, middle ${middle.toStringAsFixed(2)}',
        );
        expect(rightEdge, greaterThan(0.9));
        expect(middle, lessThan(0.05));

        r.view.resetExternalPostPassHistory();
        final reset = r.renderFrame(warmup: 0);
        expect(
          redShare(reset, 512, 384, 0, 512),
          greaterThan(0.95),
          reason: 'a reset forgets the history',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'motion shows the camera turning over the sky and nothing on a still frame',
      () {
        boot();
        if (skipWithoutVulkan()) return;
        final r = rig!;
        pass = DebugPostPass.create(
          engine: r.engine,
          view: r.view,
          mode: DebugPostPassMode.motion,
        );
        final still = r.renderFrame(warmup: 3);
        Uint8List? turning;
        for (var i = 0; i < 4; i++) {
          yaw(r, 0.03);
          turning = r.renderFrame(warmup: 0);
        }
        // the top rows are sky: their red channel carries |x motion|
        double topRed(Uint8List rgba) {
          var sum = 0;
          for (var i = 0; i < 512 * 40 * 4; i += 4) {
            sum += rgba[i];
          }
          return sum / (512 * 40);
        }

        final a = topRed(still);
        final b = topRed(turning!);
        smokeLog(
          'sky red: still ${a.toStringAsFixed(1)}, turning ${b.toStringAsFixed(1)}',
        );
        expect(b, greaterThan(a + 40));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('after FSR3 upscaling the pass gets output-resolution images', () {
      boot(width: 1024, height: 768);
      if (skipWithoutVulkan()) return;
      final r = rig!;
      if (!r.view.motionVectorsSupported) {
        markTestSkipped('FSR3 needs the structure pass motion vectors');
        return;
      }
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
        enabled: true,
        algorithm: TaaAlgorithm.fsr3,
        upscaling: 1.5,
      );
      r.view.dynamicResolutionOptions = const DynamicResolutionOptions(
        enabled: true,
        minScaleX: 1 / 1.5,
        minScaleY: 1 / 1.5,
        maxScaleX: 1 / 1.5,
        maxScaleY: 1 / 1.5,
      );
      pass = DebugPostPass.create(engine: r.engine, view: r.view);
      final frame = r.renderFrame(warmup: 4);
      // FSR3's output texture is the upscaled size rounded up to its alignment; the
      // viewport is its lower-left 1024x768.
      final (w, h) = pass!.lastSize;
      expect(w, inInclusiveRange(1024, 1040));
      expect(h, inInclusiveRange(768, 776));
      expect(frameStats(frame).distinct, greaterThan(50));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
