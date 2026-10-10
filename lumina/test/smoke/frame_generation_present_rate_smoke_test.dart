import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

/// A game's frame generation settings on a vsync-less SwapChain: the walking
/// mannequin rendered uncapped with frame generation off, DLSS 2x / 4x / 6x and
/// FSR3, the presented frame rate and the evenness of the presents measured per
/// mode, then a 10 s clip with DLSS 4x.
void main() {
  const testTitle = 'Frame Generation Smoke: presented frame rate of a walking character without vsync';
  test(testTitle, () async {
    const usedAssets = ['mannequin/MF_Unarmed_Walk_Fwd.glb'];
    for (final a in usedAssets) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$a').existsSync()) {
        return markTestSkipped('test-assets missing $a');
      }
    }
    final sdk = Directory('../flutter_filament/build/dlss-sdk');
    LuminaRtxController.requestExtensions(dlssRuntimeDir: sdk.existsSync() ? sdk.absolute.path : null);

    const w = 1024, h = 768;
    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
    if (engine == null) return markTestSkipped('needs a Vulkan device');
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(w, h, flags: SwapChainConfig.disableVsync);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 40, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    camera.lookAt(eyeX: 160, eyeY: 170, eyeZ: 420, centerX: 0, centerY: 90, centerZ: 0);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.36, 0.48, 0.7, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.55, 0.58, 0.65]), intensity: 20000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
      Dlss.clearExtensionRequest();
      DlssFrameGeneration.clearExtensionRequest();
      RayTracing.clearExtensionRequest();
    });

    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(2000, 20, 2000),
        color: Vector3(0.62, 0.6, 0.56)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-45, 0, 30]), intensity: 110000, castShadows: true)));
    final character = LuminaAnimatedMeshComponent(
        meshAssetPath: '${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}', location: Vector3.zero());
    world.persistentLevel.registerActor(LuminaActor(root: character));
    SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}');
    world.beginPlay();
    await character.loaded.timeout(const Duration(seconds: 60));
    character.play(character.clipNames.first);
    final settings = world.userSettings;
    final support = settings.renderingSupport;
    // ignore: avoid_print
    print('support: $support');
    if (!support.frameGeneration) return markTestSkipped('no frame generation here: $support');

    var clock = 0.0;
    void tick() {
      clock += 1 / 60;
      world.tick(1 / 60);
    }

    /// Uncapped frames of a CPU-bound game (the world tick plus 8 ms of game logic per frame,
    /// no readback): presents per second, interval CV, presents per rendered frame.
    (double, double, double) measure(int frames) {
      engine.flushAndWait();
      final before = renderer.getPresentTimes(1024);
      final start = before.isEmpty ? 0 : before.last;
      var rendered = 0;
      final logic = Stopwatch()..start();
      for (var i = 0; rendered < frames && i < frames * 20; i++) {
        tick();
        final until = logic.elapsedMicroseconds + 8000;
        while (logic.elapsedMicroseconds < until) {}
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.endFrame();
          rendered++;
        }
      }
      engine.flushAndWait();
      final times = renderer.getPresentTimes(1024).where((t) => t > start).toList();
      final intervals = [for (var i = 1; i < times.length; i++) (times[i] - times[i - 1]) / 1e6];
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final sd = math.sqrt(intervals.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / intervals.length);
      return (1000 / mean, sd / mean, times.length / rendered);
    }

    void mode({required bool on, String generator = 'DLSS', int frames = 1}) {
      settings
        ..setUpscaler(on && generator == 'FSR3' ? 'FSR3' : 'None')
        ..setFrameGenerationEnabled(on)
        ..setFrameGenerator(generator)
        ..setDlssGeneratedFrames(frames)
        ..applySettings();
    }

    final results = <String, (double, double, double)>{};
    Future<void> run(String label, {required bool on, String generator = 'DLSS', int frames = 1}) async {
      mode(on: on, generator: generator, frames: frames);
      measure(30);
      final m = measure(100);
      results[label] = m;
      // ignore: avoid_print
      print('$label: ${m.$1.toStringAsFixed(1)} presents/s, cv ${m.$2.toStringAsFixed(2)}, '
          '${m.$3.toStringAsFixed(2)} presents per rendered frame; fallbacks ${settings.renderingFallbacks}');
    }

    await run('off', on: false);
    final dlss = support.dlssFrameGeneration;
    if (dlss) {
      for (final n in [1, 3, 5]) {
        if (n > support.maxDlssGeneratedFrames) continue;
        await run('DLSS ${n + 1}x', on: true, frames: n);
      }
    }
    await run('FSR3 2x', on: true, generator: 'FSR3');

    final off = results['off']!;
    for (final MapEntry(key: label, value: m) in results.entries) {
      if (label == 'off') continue;
      final presents = label.startsWith('FSR3') ? 2 : int.parse(label.split(' ')[1].replaceAll('x', ''));
      expect(m.$3, closeTo(presents, 0.05), reason: '$label: presents per rendered frame');
      expect(m.$1, greaterThan(off.$1 * presents * 0.7), reason: '$label multiplies the presents per second');
      expect(m.$2, lessThan(0.35), reason: '$label: evenly paced');
    }

    // The clip: DLSS 4x (FSR3 where DLSS frame generation is missing), read back at 30 fps.
    mode(on: true, generator: dlss ? 'DLSS' : 'FSR3', frames: math.min(3, math.max(1, support.maxDlssGeneratedFrames)));
    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    Uint8List? shot;
    for (var f = 0; f < 320; f++) {
      tick();
      tick();
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(),
            ffi.nullptr, ffi.nullptr);
        renderer.endFrame();
      }
      engine.flushAndWait();
      shot = Uint8List.fromList(pixels.asTypedList(w * h * 4));
      video.addFrame(shot);
    }
    final metrics = <String, Object?>{
      for (final MapEntry(key: label, value: m) in results.entries) ...{
        '$label presents/s': double.parse(m.$1.toStringAsFixed(1)),
        '$label cv': double.parse(m.$2.toStringAsFixed(3)),
      },
    };
    SmokeArtifacts.saveScreenshot('$testTitle (frame generation on)', SmokeArtifacts.encodePng(w, h, shot!),
        usedAssets: usedAssets, metrics: metrics);
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    expect(clock, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
