import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Flutter presentation path of a game, offscreen: the game widget's
/// frame driver ticks the world and the FilamentWidget renders the view into
/// its headless swap chain and reads it back each frame (what Flutter then
/// shows). With frame generation on (FSR3, DLSS 2x) the frames keep coming
/// with no readback stall; with it off, the presented rate of the view
/// rendered once per frame is compared with the former wiring, whose frame
/// driver rendered the view a second time into a 1x1 swap chain.
void main() {
  const testTitle = 'Flutter Presentation Smoke: frame generation on the texture path keeps presenting';
  test(testTitle, () async {
    const usedAssets = [
      'Props/AC_units/ac_unit_a_300x300.glb',
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/Access_cards/access_card_blue.glb',
      'Props/Banana Bunch/banana_bunch_medium.glb',
      'Props/Chair/chair.glb',
    ];
    for (final a in usedAssets) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$a').existsSync()) {
        return markTestSkipped('test-assets missing $a');
      }
    }
    final sdk = Directory('../flutter_filament/build/dlss-sdk');
    LuminaRtxController.requestExtensions(dlssRuntimeDir: sdk.existsSync() ? sdk.absolute.path : null);

    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
    if (engine == null) return markTestSkipped('needs a Vulkan device');
    final scene = engine.createScene();
    final view = engine.createView();
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera;
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.36, 0.48, 0.7, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.55, 0.58, 0.65]), intensity: 20000));
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
    final texturePath = _TexturePath(engine, view);
    final drivers = <LuminaFrameDriver>[];
    addTearDown(() {
      for (final d in drivers) {
        d.dispose();
      }
      texturePath.dispose();
      world.cleanup();
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
    final props = <LuminaStaticMeshComponent>[];
    for (final (i, a) in usedAssets.indexed) {
      final prop = LuminaStaticMeshComponent(
        meshAssetPath: '${SmokeArtifacts.testAssetsDir.path}/$a',
        location: Vector3(i * 160.0 - 320.0, 0, 0),
        scale: a.contains('Banana') || a.contains('card') ? Vector3.all(3) : null,
      );
      props.add(prop);
      world.persistentLevel.registerActor(LuminaActor(root: prop));
      SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/$a');
    }
    world.beginPlay();
    await Future.wait(props.map((p) => p.loaded)).timeout(const Duration(seconds: 60));

    var t = 0.0;
    void animate() {
      t += 1 / 30;
      final angle = 0.4 + t * 0.25;
      camera.lookAt(
          eyeX: math.sin(angle) * 700, eyeY: 300, eyeZ: math.cos(angle) * 700, centerX: 0, centerY: 40, centerZ: 0);
    }

    void resize(int w, int h) {
      texturePath.resize(w, h);
      camera.setProjection(fovDegrees: 40, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    }

    // The game widget's frame driver: it ticks the world on the refreshes
    // the view renders on; the FilamentWidget renders the view.
    LuminaFrameDriver gameWidgetDriver() {
      final d = LuminaFrameDriver(world, renderer: engine.createRenderer(), view: view);
      drivers.add(d);
      return d;
    }

    // What the game widget used to build: a driver that rendered the view a
    // second time into a 1x1 headless swap chain (frame generation off only).
    LuminaFrameDriver formerDoubleRenderDriver() {
      final d = LuminaFrameDriver(world,
          renderer: engine.createRenderer(), swapChain: engine.createHeadlessSwapChain(1, 1), view: view);
      drivers.add(d);
      return d;
    }

    /// [frames] host frames (tick, then the FilamentWidget's frame): the
    /// presented frames per second and the slowest frame in ms.
    (double, double) run(LuminaFrameDriver driver, int frames, {void Function(Uint8List)? onPixels}) {
      var slowest = 0.0;
      final clock = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        final frame = Stopwatch()..start();
        animate();
        driver.onVsync(engine.steadyClockTimeNano);
        final pixels = texturePath.frame();
        final ms = frame.elapsedMicroseconds / 1000;
        if (ms > slowest) slowest = ms;
        if (pixels != null) onPixels?.call(pixels);
        // A readback stall (a fence timeout) shows as frames of seconds.
        if (ms > 2000) break;
      }
      return (frames / (clock.elapsedMicroseconds / 1e6), slowest);
    }

    final settings = world.userSettings;
    final support = settings.renderingSupport;
    // ignore: avoid_print
    print('support: $support');
    if (!support.frameGeneration) return markTestSkipped('no frame generation here: $support');

    void mode({required bool on, String generator = 'FSR3'}) {
      settings
        ..setUpscaler(on && generator == 'FSR3' ? 'FSR3' : 'None')
        ..setFrameGenerationEnabled(on)
        ..setFrameGenerator(generator)
        ..setDlssGeneratedFrames(1)
        ..applySettings();
    }

    final metrics = <String, Object?>{};
    resize(1024, 768);
    final driver = gameWidgetDriver();

    // Frame generation on the Flutter path: every frame comes back.
    final generators = ['FSR3', if (support.dlssFrameGeneration) 'DLSS'];
    for (final g in generators) {
      mode(on: true, generator: g);
      expect(settings.activeRenderingFeatures.frameGeneration, isTrue, reason: '$g frame generation is in force');
      expect(LuminaRtxController.frameGenerationActive.value, isTrue);
      run(driver, 20);
      final (fps, slowest) = run(driver, 120);
      // ignore: avoid_print
      print('$g frame generation, Flutter path 1024x768: ${fps.toStringAsFixed(1)} frames/s, '
          'slowest ${slowest.toStringAsFixed(1)} ms');
      metrics['$g FG Flutter path frames/s'] = double.parse(fps.toStringAsFixed(1));
      expect(slowest, lessThan(1000), reason: '$g: no readback stall');
      expect(driver.renderedFrames, 0, reason: 'the game widget driver never renders the view');
    }

    // Frame generation off: the view rendered once vs twice per frame.
    mode(on: false);
    final former = formerDoubleRenderDriver();
    for (final (w, h) in const [(1024, 768), (1920, 1080), (3440, 1440)]) {
      resize(w, h);
      run(former, 20);
      final (twice, _) = run(former, 120);
      run(driver, 20);
      final (once, _) = run(driver, 120);
      // ignore: avoid_print
      print('${w}x$h Flutter path: ${twice.toStringAsFixed(1)} frames/s rendering the view twice, '
          '${once.toStringAsFixed(1)} once (${((once / twice - 1) * 100).toStringAsFixed(1)}%)');
      metrics['${w}x$h twice frames/s'] = double.parse(twice.toStringAsFixed(1));
      metrics['${w}x$h once frames/s'] = double.parse(once.toStringAsFixed(1));
      expect(former.renderedFrames, greaterThan(0));
    }
    for (final size in const ['1024x768', '1920x1080', '3440x1440']) {
      expect(metrics['$size once frames/s']! as double, greaterThan(metrics['$size twice frames/s']! as double),
          reason: '$size: rendering the view once per frame is faster');
    }

    // The clip: the Flutter path with frame generation on, read back at 30 fps.
    resize(1024, 768);
    mode(on: true, generator: support.dlssFrameGeneration ? 'DLSS' : 'FSR3');
    final video = SmokeVideoRecorder(width: 1024, height: 768, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    Uint8List? shot;
    run(driver, 320, onPixels: (p) {
      shot = p;
      video.addFrame(p);
    });
    SmokeArtifacts.saveScreenshot('$testTitle (frame generation on)', SmokeArtifacts.encodePng(1024, 768, shot!),
        usedAssets: usedAssets, metrics: metrics);
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// The FilamentWidget's texture path: its own renderer and headless swap
/// chain at the view's size, the frame read back and waited for.
class _TexturePath {
  _TexturePath(this.engine, this.view) : renderer = engine.createRenderer();

  final FilamentEngine engine;
  final FilamentView view;
  final FilamentRenderer renderer;
  FilamentSwapChain? _swapChain;
  ffi.Pointer<ffi.Uint8>? _pixels;
  int _w = 0, _h = 0;

  void resize(int w, int h) {
    engine.flushAndWait();
    _swapChain?.dispose();
    if (_pixels != null) calloc.free(_pixels!);
    _w = w;
    _h = h;
    _swapChain = engine.createHeadlessSwapChain(w, h);
    _pixels = calloc<ffi.Uint8>(w * h * 4);
    view.setViewport(0, 0, w, h);
  }

  Uint8List? frame() {
    if (!renderer.beginFrame(_swapChain!)) return null;
    renderer.render(view);
    c.filament_renderer_read_pixels(
        renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, _pixels!.cast(), ffi.nullptr, ffi.nullptr);
    engine.flushAndWait();
    renderer.endFrame();
    engine.flushAndWait();
    return Uint8List.fromList(_pixels!.asTypedList(_w * _h * 4));
  }

  void dispose() {
    engine.flushAndWait();
    _swapChain?.dispose();
    renderer.dispose();
    if (_pixels != null) calloc.free(_pixels!);
  }
}
