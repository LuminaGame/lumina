import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// The FSR3 upscaler and frame generation behind the temporal anti-aliasing
/// options, fed by the structure pass motion vectors.
void main() {
  test('the algorithm and frame generation round-trip through the view (noop backend)', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final view = engine.createView();
    try {
      const options = TemporalAntiAliasingOptions(enabled: true, algorithm: TaaAlgorithm.fsr3, frameGeneration: true, upscaling: 1.5);
      view.temporalAntiAliasingOptions = options;
      final back = view.temporalAntiAliasingOptions;
      expect(back.algorithm, TaaAlgorithm.fsr3);
      expect(back.frameGeneration, isTrue);
      expect(back.upscaling, closeTo(1.5, 1e-6));
      expect(const TemporalAntiAliasingOptions().algorithm, TaaAlgorithm.filament);
      expect(SwapChainConfig.disableVsync.value, 0x100);
    } finally {
      view.dispose();
      engine.dispose();
    }
  });

  for (final backend in [FilamentBackend.vulkan, FilamentBackend.opengl]) {
    group('FSR3 on ${backend.name}', () {
      SmokeRig? rig;
      LoadedGltf? gltf;

      setUp(() {
        FilamentEngine? engine;
        try {
          engine = FilamentEngine.create(backend: backend);
        } catch (_) {
          engine = null;
        }
        if (engine == null) return;
        rig = SmokeRig.adopt(engine, width: 384, height: 256);
        rig!.addSun();
        gltf = loadGltfIntoScene(rig!, 'Props/Barrels/fuel_barrel_red.glb');
      });

      tearDown(() {
        gltf?.dispose(rig!.scene);
        gltf = null;
        rig?.dispose();
        rig = null;
      });

      bool skipWithoutMotionVectors() {
        if (rig == null) {
          markTestSkipped('needs a ${backend.name} device');
          return true;
        }
        if (!rig!.view.motionVectorsSupported) {
          markTestSkipped('FSR3 needs the structure pass motion vectors');
          return true;
        }
        return false;
      }

      test('upscales from two thirds of the viewport and renders a shaded frame', () {
        if (skipWithoutMotionVectors()) return;
        final r = rig!;
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
        Uint8List? taa;
        for (var i = 0; i < 6; i++) {
          taa = r.renderFrame(warmup: 0);
        }
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, algorithm: TaaAlgorithm.fsr3, upscaling: 1.5);
        r.view.dynamicResolutionOptions = const DynamicResolutionOptions(
          enabled: true,
          minScaleX: 1 / 1.5,
          minScaleY: 1 / 1.5,
          maxScaleX: 1 / 1.5,
          maxScaleY: 1 / 1.5,
          homogeneousScaling: true,
        );
        Uint8List? fsr3;
        for (var i = 0; i < 12; i++) {
          fsr3 = r.renderFrame(warmup: 0);
        }
        expect(fsr3!.length, r.width * r.height * 4, reason: 'the output is the full viewport');
        expect(frameStats(fsr3).distinct, greaterThan(100), reason: 'a shaded barrel is visible');
        final (tr, tg, tb) = averageColor(taa!, r.width, r.width ~/ 2 - 16, r.height ~/ 2 - 16, 32, 32);
        final (fr, fg, fb) = averageColor(fsr3, r.width, r.width ~/ 2 - 16, r.height ~/ 2 - 16, 32, 32);
        expect((tr + tg + tb) - (fr + fg + fb), lessThan(60), reason: 'the upscaled frame keeps the exposure of the TAA frame');
        expect((fr + fg + fb) - (tr + tg + tb), lessThan(60));
        var differing = 0;
        for (var i = 0; i < fsr3.length; i += 4) {
          if ((fsr3[i] - taa[i]).abs() > 8 || (fsr3[i + 1] - taa[i + 1]).abs() > 8 || (fsr3[i + 2] - taa[i + 2]).abs() > 8) differing++;
        }
        expect(differing, greaterThan(200), reason: 'the FSR3 reconstruction is not the TAA output');
        print('FSR3 ${backend.name}: ${differing} of ${r.width * r.height} pixels differ from the TAA frame');
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('frame generation presents an interpolated frame before each rendered one without errors', () {
        if (skipWithoutMotionVectors()) return;
        final r = rig!;
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, algorithm: TaaAlgorithm.fsr3, frameGeneration: true);
        final tm = FilamentTransformManager(r.engine);
        final root = gltf!.asset.rootEntity;
        Uint8List? last;
        for (var i = 0; i < 16; i++) {
          final x = 0.02 * i;
          tm.setTransform(root, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, 0, 0, 1]);
          last = r.renderFrame(warmup: 0);
        }
        expect(last!.length, r.width * r.height * 4);
        expect(frameStats(last).distinct, greaterThan(100));
        expect(r.engine.hasUnrecoverableFailure, isFalse);
      }, timeout: const Timeout(Duration(minutes: 3)));
    });
  }
}
