import 'dart:ffi' show sizeOf;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as ffi_gen;
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// ReSTIR direct lighting: per-pixel reservoirs resample the scene's punctual
/// lights (initial candidates, temporal and spatial reuse) and one visibility
/// ray shades the surviving light, replacing the froxel light loop.
void main() {
  group('ReSTIR options', () {
    test('defaults, round trip and the mirrored struct size', () {
      const options = RestirOptions();
      expect(options.enabled, isFalse);
      expect(options.initialCandidates, 8);
      expect(options.spatialSamples, 2);
      expect(options.spatialRadiusPx, 32.0);
      expect(options.temporal, isTrue);
      expect(options.maxHistory, 20);
      expect(options.visibilityRays, isTrue);
      expect(options.shadeEmissive, isFalse);
      expect(sizeOf<ffi_gen.filament_restir_options>(), ffi_gen.filament_options_sizeof(14));

      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final view = engine.createView();
      try {
        const set = RestirOptions(enabled: true, initialCandidates: 16, spatialSamples: 3, spatialRadiusPx: 12.5, temporal: false, maxHistory: 7, visibilityRays: false);
        view.restirOptions = set;
        expect(view.restirOptions, set);
        expect(view.restirSupported, isFalse, reason: 'the noop backend traces no rays');
        expect(view.restirStats.lightCount, 0);
        view.resetRestirHistory();
      } finally {
        view.dispose();
        engine.dispose();
      }
    });
  });

  group('ReSTIR on the RTX GPU (Vulkan)', () {
    const size = 256;
    SmokeRig? rig;
    final materials = <FilamentMaterial>[];
    final instances = <FilamentMaterialInstance>[];
    final quads = <SmokeQuad>[];
    final lights = <int>[];

    setUp(() {
      if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') return;
      RayTracing.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: size, height: size);
      // Orthographic 2.56 world units across (1 unit = 100 texels), looking down -Z.
      rig!.camera.setProjectionOrtho(left: -1.28, right: 1.28, bottom: -1.28, top: 1.28, near: 0.1, far: 100);
      rig!.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 10, centerX: 0, centerY: 0, centerZ: 0);
      rig!.camera.setExposure(aperture: 16, shutterSpeed: 1 / 125, sensitivity: 100);
    });

    tearDown(() {
      final r = rig;
      if (r != null) {
        for (final e in r.entities) {
          r.engine.destroyEntity(e);
        }
        r.entities.clear();
      }
      lights.clear();
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
      RayTracing.clearExtensionRequest();
    });

    bool skipWithoutRayQuery() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      if (!rig!.engine.supportsRayQuery) {
        markTestSkipped('this GPU or driver has no Vulkan ray query support');
        return true;
      }
      return false;
    }

    /// A lit quad facing +Z at depth [z], shifted by ([x], [y]).
    int addLitQuad(SmokeRig r, {double z = 0, double x = 0, double y = 0, double sizeUnits = 2.56, (double, double, double) color = (0.8, 0.8, 0.8)}) {
      final quad = SmokeQuad.create(r.engine, size: sizeUnits, tangents: true);
      quads.add(quad);
      final material = buildLitMaterial(r.engine);
      materials.add(material);
      final mi = material.createInstance()..setFloat3('baseColor', color.$1, color.$2, color.$3);
      instances.add(mi);
      final entity = addQuadRenderable(r, quad, mi, extent: sizeUnits);
      FilamentTransformManager(r.engine).setTransform(entity, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1]);
      return entity;
    }

    int addPointLight(SmokeRig r, double x, double y, double z, {(double, double, double) color = (1, 1, 1), double intensity = 20000, double falloff = 8}) {
      final e = r.engine.createEntity();
      LightBuilder(LightType.point)
        ..color(color.$1, color.$2, color.$3)
        ..intensity(intensity)
        ..position(x, y, z)
        ..falloff(falloff)
        ..build(r.engine, e);
      r.scene.addEntity(e);
      r.entities.add(e);
      lights.add(e);
      return e;
    }

    /// [count] lights of varied colour and radius on a grid above the floor.
    void addLightGrid(SmokeRig r, int count, {double z = 1.5}) {
      final side = math.sqrt(count).ceil();
      final rnd = math.Random(7);
      for (var i = 0; i < count; i++) {
        final gx = (i % side) / math.max(1, side - 1) * 2.0 - 1.0;
        final gy = (i ~/ side) / math.max(1, side - 1) * 2.0 - 1.0;
        addPointLight(r, gx, gy, z + rnd.nextDouble() * 0.5,
            color: (0.3 + 0.7 * rnd.nextDouble(), 0.3 + 0.7 * rnd.nextDouble(), 0.3 + 0.7 * rnd.nextDouble()),
            intensity: 400000 / count,
            falloff: 3 + rnd.nextDouble() * 4);
      }
    }

    Uint8List renderFrames(SmokeRig r, int frames) {
      Uint8List? last;
      for (var i = 0; i < frames; i++) {
        last = r.renderFrame(warmup: 0);
      }
      return last!;
    }

    (double, double, double) patchMean(Uint8List px, int cx, int cy, [int half = 16]) =>
        averageColor(px, size, cx - half, cy - half, half * 2, half * 2);

    double relDiff(double a, double b) => (a - b).abs() / math.max(1e-3, math.max(a, b));

    test('64 lights: supported, counted, one ray per pixel at most twice, GPU time recorded', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      addLightGrid(r, 64);
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true);
      expect(r.view.restirSupported, isTrue);
      renderFrames(r, 60);
      final stats = r.view.restirStats;
      expect(stats.lightCount, 64);
      expect(stats.raysPerFrame, greaterThan(0));
      expect(stats.raysPerFrame, lessThanOrEqualTo(2 * size * size));
      expect(stats.gpuTime, greaterThan(Duration.zero));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('converges to the froxel reference and resampling lowers the noise', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      addLightGrid(r, 64);
      r.scene.rayTracingEnabled = true;
      // Filament's own light loop evaluates every light analytically: the reference.
      r.view.restirOptions = const RestirOptions(enabled: false);
      final reference = renderFrames(r, 3);
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: false);
      final restir = renderFrames(r, 60);
      for (final (cx, cy) in [(size ~/ 2, size ~/ 2), (64, 64), (192, 192), (64, 192)]) {
        final a = patchMean(reference, cx, cy);
        final b = patchMean(restir, cx, cy);
        expect(relDiff(a.$1, b.$1), lessThan(0.1), reason: 'red at $cx,$cy ref ${a.$1} restir ${b.$1}');
        expect(relDiff(a.$2, b.$2), lessThan(0.1), reason: 'green at $cx,$cy');
        expect(relDiff(a.$3, b.$3), lessThan(0.1), reason: 'blue at $cx,$cy');
      }

      double variance(RestirOptions options) {
        r.view.restirOptions = options;
        r.view.resetRestirHistory();
        renderFrames(r, 10);
        final means = <double>[];
        for (var i = 0; i < 30; i++) {
          final px = r.renderFrame(warmup: 0);
          final (red, green, blue) = patchMean(px, 100, 150, 4);
          means.add((red + green + blue) / 3);
        }
        final mean = means.reduce((a, b) => a + b) / means.length;
        return means.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) / means.length;
      }

      final noisy = variance(const RestirOptions(enabled: true, temporal: false, spatialSamples: 0, initialCandidates: 1, visibilityRays: false));
      final resampled = variance(const RestirOptions(enabled: true, visibilityRays: false));
      expect(resampled, lessThan(noisy), reason: 'temporal and spatial reuse reduce the per-frame variance');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('visibility rays shadow the floor behind an occluder', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      addLitQuad(r, z: 1.5, sizeUnits: 0.6, color: (0.2, 0.2, 0.2));
      // One strong light above and left of the occluder: its shadow lands at x ~ +0.8.
      addPointLight(r, -0.4, 0, 3, intensity: 300000, falloff: 20);
      r.scene.rayTracingEnabled = true;
      const shadowX = 128 + 80;
      const openX = 128 - 80;
      const cy = 128;
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: false);
      final unshadowed = renderFrames(r, 40);
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: true);
      r.view.resetRestirHistory();
      final shadowed = renderFrames(r, 40);
      final litOpenA = patchMean(unshadowed, openX, cy, 8);
      final litOpenB = patchMean(shadowed, openX, cy, 8);
      final shadowA = patchMean(unshadowed, shadowX, cy, 8);
      final shadowB = patchMean(shadowed, shadowX, cy, 8);
      expect(relDiff(litOpenA.$2, litOpenB.$2), lessThan(0.05), reason: 'the open floor does not change with rays');
      expect(shadowB.$2, lessThan(shadowA.$2 * 0.5), reason: 'the floor behind the occluder darkens by at least half');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('1024 lights cost less than twice 64 lights', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true);

      Duration measure(int lightCount) {
        for (final e in lights) {
          r.scene.removeEntity(e);
          r.engine.destroyEntity(e);
          r.entities.remove(e);
        }
        lights.clear();
        addLightGrid(r, lightCount);
        renderFrames(r, 20);
        var total = Duration.zero;
        var samples = 0;
        for (var i = 0; i < 30; i++) {
          r.renderFrame(warmup: 0);
          final t = r.view.restirStats.gpuTime;
          if (t > Duration.zero) {
            total += t;
            samples++;
          }
        }
        expect(r.view.restirStats.lightCount, lightCount);
        expect(samples, greaterThan(0));
        return total ~/ samples;
      }

      final small = measure(64);
      final large = measure(1024);
      smokeLog('restir gpu time: 64 lights ${small.inMicroseconds} us, 1024 lights ${large.inMicroseconds} us');
      expect(large.inMicroseconds, lessThan(small.inMicroseconds * 2 + 200), reason: 'ReSTIR cost is nearly independent of the light count');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a sampling weight of zero removes a light', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      final left = addPointLight(r, -0.7, 0, 1.2, intensity: 60000, falloff: 6);
      addPointLight(r, 0.7, 0, 1.2, intensity: 60000, falloff: 6);
      r.scene.rayTracingEnabled = true;
      final lm = FilamentLightManager(r.engine);
      // reference: the froxel path with the left light switched off
      lm.setIntensity(left, 0);
      r.view.restirOptions = const RestirOptions(enabled: false);
      final reference = renderFrames(r, 3);
      lm.setIntensity(left, 60000);
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: false);
      final both = renderFrames(r, 40);
      lm.setRestirSamplingWeight(left, 0);
      r.view.resetRestirHistory();
      final muted = renderFrames(r, 40);
      for (final (cx, label) in [(128 - 70, 'under the muted light'), (128 + 70, 'under the other light'), (128, 'between them')]) {
        final ref = patchMean(reference, cx, 128, 8);
        final got = patchMean(muted, cx, 128, 8);
        expect(relDiff(ref.$2 + 1, got.$2 + 1), lessThan(0.1), reason: '$label: ReSTIR without the muted light matches the froxel render without it');
      }
      final before = patchMean(both, 128 - 70, 128, 8);
      final after = patchMean(muted, 128 - 70, 128, 8);
      expect(after.$2, lessThan(before.$2 * 0.5), reason: 'the floor under the muted light loses its contribution');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('resetting the history drops it and the image converges again', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      addLightGrid(r, 64);
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: false);
      final converged = renderFrames(r, 60);
      r.view.resetRestirHistory();
      final fresh = r.renderFrame(warmup: 0);
      expect(countChangedPixels(fresh, converged, tolerance: 6), greaterThan(0), reason: 'the first frame after the reset starts over');
      final again = renderFrames(r, 20);
      final a = patchMean(converged, 128, 128);
      final b = patchMean(again, 128, 128);
      expect(relDiff(a.$2, b.$2), lessThan(0.1));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a moving light leaves no trail behind it', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      final light = addPointLight(r, -0.8, 0, 1.0, intensity: 80000, falloff: 4);
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true, visibilityRays: false);
      final lm = FilamentLightManager(r.engine);
      // reference: the light already at its final position, no history of the old one
      lm.setPosition(light, 0.8, 0, 1.0);
      final reference = renderFrames(r, 40);
      // start over on the left and move across in 20 frames
      lm.setPosition(light, -0.8, 0, 1.0);
      r.view.resetRestirHistory();
      renderFrames(r, 40);
      for (var i = 1; i <= 20; i++) {
        lm.setPosition(light, -0.8 + 1.6 * i / 20, 0, 1.0);
        r.renderFrame(warmup: 0);
      }
      final after = renderFrames(r, 10);
      final oldSpotRef = patchMean(reference, 128 - 80, 128, 8);
      final oldSpot = patchMean(after, 128 - 80, 128, 8);
      expect(relDiff(oldSpotRef.$2 + 1, oldSpot.$2 + 1), lessThan(0.1), reason: 'where the light was 10 frames ago matches the reference');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('destroying view, scene and engine with reservoirs alive leaks nothing', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      addLitQuad(r);
      addLightGrid(r, 16);
      r.scene.rayTracingEnabled = true;
      r.view.restirOptions = const RestirOptions(enabled: true);
      renderFrames(r, 5);
      expect(r.view.restirStats.lightCount, 16);
      r.engine.flushAndWait();
      for (final e in r.entities) {
        r.engine.destroyEntity(e);
      }
      r.entities.clear();
      lights.clear();
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
      r.dispose();
      rig = null;
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('ReSTIR on an engine created without the ray query extensions', () {
    test('is unsupported and enabling it keeps the froxel render', () {
      if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') {
        markTestSkipped('Vulkan only');
        return;
      }
      RayTracing.clearExtensionRequest();
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
      final rig = SmokeRig.adopt(engine, width: 256, height: 256);
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/empty_barrel.glb');
      final light = engine.createEntity();
      LightBuilder(LightType.point)
        ..color(1, 0.9, 0.8)
        ..intensity(50000)
        ..position(0.5, 1.5, 0.5)
        ..falloff(10)
        ..build(engine, light);
      rig.scene.addEntity(light);
      rig.entities.add(light);
      try {
        expect(rig.view.restirSupported, isFalse);
        rig.scene.rayTracingEnabled = true;
        rig.view.restirOptions = const RestirOptions(enabled: false);
        final a = rig.renderFrame(warmup: 3);
        final b = rig.renderFrame(warmup: 3);
        final noise = countChangedPixels(a, b, tolerance: 3);
        rig.view.restirOptions = const RestirOptions(enabled: true);
        final fallback = rig.renderFrame(warmup: 3);
        expect(countChangedPixels(fallback, b, tolerance: 3), lessThanOrEqualTo(noise + 16),
            reason: 'without ray query the froxel render is used unchanged');
        expect(rig.view.restirStats.lightCount, 0);
      } finally {
        gltf.dispose(rig.scene);
        rig.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
