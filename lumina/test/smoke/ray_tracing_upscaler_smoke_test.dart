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

import '../blueprint/rendering_features_blueprint.dart';

/// A game's graphics menu Blueprint switches between native rendering, ray
/// tracing (ray-traced sun shadows + ReSTIR), FSR3 Performance with frame
/// generation and DLSS Performance on a real scene of props, through the
/// game user settings and the game's own view.
void main() {
  const testTitle = 'Ray Tracing & Upscaling Smoke: a game Blueprint toggles ray tracing, FSR3 and DLSS';
  test(testTitle, () async {
    const usedAssets = [
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/Barrels/dented_barrel.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
      'Props/Banana Bunch/banana_bunch_long.glb',
    ];
    for (final a in usedAssets) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$a').existsSync()) return markTestSkipped('test-assets missing $a');
    }
    // Before the engine exists: ray query and (with the fetched NGX runtime) DLSS.
    final sdk = Directory('../flutter_filament/build/dlss-sdk');
    LuminaRtxController.requestExtensions(dlssRuntimeDir: sdk.existsSync() ? sdk.absolute.path : null);

    const w = 1024, h = 768;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(w, h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 45, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.55, 0.78, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.55, 0.58, 0.65]), intensity: 22000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });

    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(3000, 20, 3000), color: Vector3(0.62, 0.6, 0.56)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 110000, castShadows: true)));
    // A point light for ReSTIR to shade.
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaPointLightComponent(location: Vector3(-40, 140, 260), intensity: 60000, color: Vector3(1.0, 0.75, 0.5))));
    final props = <LuminaStaticMeshComponent>[];
    for (final (i, a) in usedAssets.indexed) {
      final prop = LuminaStaticMeshComponent(
        meshAssetPath: '${SmokeArtifacts.testAssetsDir.path}/$a',
        // The AC unit stands behind the barrels and the bananas.
        location: a.contains('ac_unit') ? Vector3(0, 0, -320) : Vector3(i * 130.0 - 160.0, 0, 140),
        scale: a.contains('banana') ? Vector3.all(3) : null,
      );
      props.add(prop);
      world.persistentLevel.registerActor(LuminaActor(root: prop));
      SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/$a');
    }

    // The game's graphics menu.
    final menu = LuminaBlueprintClass.fromDocument(graphicsToggleBlueprint(), name: 'bp_graphics_menu').instantiate();
    final printed = <String>[];
    (menu as LuminaBlueprintRuntime).trace = (t) {
      if (t.printed != null) printed.add(t.printed!);
    };
    world.persistentLevel.registerActor(menu);
    world.beginPlay();
    await Future.wait(props.map((p) => p.loaded)).timeout(const Duration(seconds: 60));
    final settings = world.userSettings;
    final support = settings.renderingSupport;
    // ignore: avoid_print
    print('ray tracing / upscaler support: $support');

    var orbit = 0.0;
    void aim(double angle) {
      const r = 1250.0;
      camera.lookAt(
          eyeX: math.sin(angle) * r, eyeY: 520, eyeZ: math.cos(angle) * r + 100, centerX: 0, centerY: 70, centerZ: 0);
    }

    Uint8List frame({bool read = true}) {
      world.tick(1 / 30);
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (read && i == 1) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    double difference(Uint8List a, Uint8List b) {
      var sum = 0;
      for (var i = 0; i < a.length; i += 4) {
        sum += (a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs();
      }
      return sum / (a.length / 4 * 3);
    }

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    final reference = <String, Uint8List>{};
    final phases = <String, Map<String, Object?>>{};

    Future<void> phase(String event, String label) async {
      LuminaBlueprintFunctionLibrary.callCustomEvent(menu, event);
      for (var f = 0; f < 90; f++) {
        orbit += 0.006;
        aim(orbit);
        video.addFrame(frame());
      }
      // The same pose for every mode, so the pictures compare.
      aim(0.35);
      for (var f = 0; f < 6; f++) {
        frame(read: false);
      }
      final shot = frame();
      reference[event] = shot;
      final controller = settings.rtxController;
      final dlss = controller?.dlss;
      final metrics = <String, Object?>{
        'activeUpscaler': settings.activeUpscaler,
        'rayTracingActive': settings.rayTracingActive,
        'sceneRayTracing': scene.rayTracingEnabled,
        'restir': view.restirOptions.enabled,
        'taaAlgorithm': view.temporalAntiAliasingOptions.algorithm.name,
        'frameGeneration': view.temporalAntiAliasingOptions.frameGeneration,
        'renderScale': view.lastDynamicResolutionScale.$1,
        'dlssRenderResolution': dlss == null ? null : '${dlss.renderResolution.$1}x${dlss.renderResolution.$2}',
        'fallbacks': settings.renderingFallbacks.join(' | '),
        'supportedUpscalers': settings.supportedUpscalers.join(', '),
      };
      phases[event] = metrics;
      // ignore: avoid_print
      print('$label: $metrics');
      SmokeArtifacts.saveScreenshot('$testTitle $label', SmokeArtifacts.encodePng(w, h, shot),
          usedAssets: usedAssets, metrics: metrics);
    }

    await phase('UseNative', '01 native');
    await phase('UseRayTracing', '02 ray tracing');
    await phase('UseFsr3', '03 FSR3 performance + frame generation');
    await phase('UseDlss', '04 DLSS performance');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);

    // The Blueprint printed the active upscaler and ray tracing per mode.
    expect(printed.length, 8);
    expect(printed.sublist(0, 2), ['None', 'false']);
    expect(phases['UseNative']!['sceneRayTracing'], isFalse);

    if (support.rayTracing) {
      expect(printed.sublist(2, 4), ['None', 'true']);
      expect(phases['UseRayTracing']!['sceneRayTracing'], isTrue);
      expect(phases['UseRayTracing']!['restir'], isTrue);
      final suns = FilamentLightManager(engine).entities.where((e) => FilamentLightManager(engine).isDirectional(e));
      expect(suns, isNotEmpty);
      final diff = difference(reference['UseNative']!, reference['UseRayTracing']!);
      // ignore: avoid_print
      print('native vs ray traced mean channel difference: $diff');
      expect(diff, greaterThan(0.5), reason: 'ray-traced shadows and ReSTIR change the picture');
    } else {
      // ignore: avoid_print
      print('ray tracing not checked: ${support.rayTracingReason}');
      expect(printed.sublist(2, 4), ['None', 'false']);
    }

    if (support.fsr3) {
      expect(printed.sublist(4, 6), ['FSR3', 'false']);
      expect(phases['UseFsr3']!['taaAlgorithm'], 'fsr3');
      expect(phases['UseFsr3']!['frameGeneration'], isTrue);
      expect(phases['UseFsr3']!['renderScale'] as double, closeTo(0.5, 0.02), reason: 'Performance renders half the output per axis');
      expect(phases['UseNative']!['renderScale'] as double, closeTo(1.0, 0.02));
    }

    if (support.dlss && phases['UseDlss']!['activeUpscaler'] == 'DLSS') {
      expect(printed.sublist(6, 8), ['DLSS', 'false']);
      expect(phases['UseDlss']!['dlssRenderResolution'], isNotNull);
      expect(phases['UseDlss']!['renderScale'] as double, lessThan(0.75));
    } else {
      // ignore: avoid_print
      print('DLSS not checked: ${support.dlss ? phases['UseDlss']!['fallbacks'] : support.dlssReason}');
      expect(printed[6], support.fsr3 ? 'FSR3' : 'None', reason: 'DLSS falls back');
      expect(phases['UseDlss']!['fallbacks'] as String, contains('DLSS'));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
