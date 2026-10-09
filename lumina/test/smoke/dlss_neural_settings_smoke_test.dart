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

/// A graphics menu Blueprint with two custom events: `UseRayReconstruction`
/// (ray tracing + ReSTIR, the `DLSS RR` upscaler at Quality) and
/// `UseFrameGeneration` (the same plus DLSS frame generation with 3 generated
/// frames). Each applies the settings and prints the active upscaler, the
/// frame generator and whether Ray Reconstruction is supported.
LuminaBlueprintDocument dlssNeuralMenuBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_dlss_neural_menu');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  void mode(String event, String key, {required bool frameGeneration}) {
    final steps = <LuminaBlueprintNode>[
      place('custom_event', '${key}_event', {'name': event}),
      place('set_ray_tracing_enabled', '${key}_rt', {'enabled': true}),
      place('set_restir_enabled', '${key}_restir', {'enabled': true}),
      place('set_upscaler', '${key}_upscaler', {'upscaler': 'DLSS RR'}),
      place('set_upscaler_quality', '${key}_quality', {'quality': 'Quality'}),
      place('set_frame_generator', '${key}_generator', {'generator': 'DLSS'}),
      place('set_dlss_generated_frames', '${key}_frames', {'frames': 3}),
      place('set_frame_generation_enabled', '${key}_framegen', {'enabled': frameGeneration}),
      place('apply_scalability_settings', '${key}_apply'),
      place('print_string', '${key}_say_upscaler'),
      place('print_string', '${key}_say_rr'),
    ];
    doc.eventGraph.nodes.addAll([
      ...steps,
      place('get_active_upscaler', '${key}_active'),
      place('is_ray_reconstruction_supported', '${key}_rr_supported'),
      place('bool_to_string', '${key}_rr_text'),
    ]);
    for (var k = 0; k + 1 < steps.length; k++) {
      doc.eventGraph.wires.add(wire(steps[k].id, 'exec_out', steps[k + 1].id, 'exec_in'));
    }
    doc.eventGraph.wires.addAll([
      wire('${key}_active', 'return_value', '${key}_say_upscaler', 'in_string'),
      wire('${key}_rr_supported', 'return_value', '${key}_rr_text', 'in_bool'),
      wire('${key}_rr_text', 'return_value', '${key}_say_rr', 'in_string'),
    ]);
  }

  mode('UseRayReconstruction', 'rr', frameGeneration: false);
  mode('UseFrameGeneration', 'fg', frameGeneration: true);
  return doc;
}

void main() {
  const testTitle = 'DLSS Smoke: a game Blueprint switches to DLSS Ray Reconstruction and DLSS frame generation';
  test(testTitle, () async {
    const usedAssets = [
      'Props/AC_units/ac_unit_a_300x300.glb',
      'Props/Banana Bunch/banana_bunch_long.glb',
      'Props/Access_cards/access_card_green.glb',
    ];
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
    final swapChain = engine.createHeadlessSwapChain(w, h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 45, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.05, 0.06, 0.09, 1), intensity: 30000));
    scene.setIndirectLight(
      FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.5, 0.52, 0.6]),
        intensity: 6000,
      ),
    );
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

    world.persistentLevel.registerActor(
      LuminaPrimitiveActor(
        location: Vector3(0, -10, 0),
        shape: LuminaPrimitiveShape.box,
        size: Vector3(3000, 20, 3000),
        color: Vector3(0.62, 0.6, 0.56),
      ),
    );
    // coloured point lights for ReSTIR (one visibility ray per pixel: the noise RR removes)
    final rnd = math.Random(3);
    final lights = <LuminaPointLightComponent>[];
    for (var i = 0; i < 24; i++) {
      final light = LuminaPointLightComponent(
        location: Vector3(rnd.nextDouble() * 900 - 450, 40 + rnd.nextDouble() * 160, rnd.nextDouble() * 900 - 450),
        intensity: 900000,
        color: Vector3(0.4 + 0.6 * rnd.nextDouble(), 0.4 + 0.6 * rnd.nextDouble(), 0.4 + 0.6 * rnd.nextDouble()),
      );
      lights.add(light);
      world.persistentLevel.registerActor(LuminaActor(root: light));
    }
    final props = <LuminaStaticMeshComponent>[];
    for (final (i, a) in usedAssets.indexed) {
      final prop = LuminaStaticMeshComponent(
        meshAssetPath: '${SmokeArtifacts.testAssetsDir.path}/$a',
        location: Vector3(i * 220.0 - 220.0, 0, 0),
        scale: a.contains('banana') || a.contains('card') ? Vector3.all(3) : null,
      );
      props.add(prop);
      world.persistentLevel.registerActor(LuminaActor(root: prop));
      SmokeArtifacts.recordAsset('${SmokeArtifacts.testAssetsDir.path}/$a');
    }

    final menu = LuminaBlueprintClass.fromDocument(
      dlssNeuralMenuBlueprint(),
      name: 'bp_dlss_neural_menu',
    ).instantiate();
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
    print('support: $support');
    if (!support.rayReconstruction || !support.dlssFrameGeneration) {
      return markTestSkipped(
        'needs DLSS Ray Reconstruction and Frame Generation: '
        '${support.rayReconstructionReason} / ${support.dlssFrameGenerationReason}',
      );
    }

    var t = 0.0;
    void animate() {
      t += 1 / 30;
      const r = 800.0;
      final angle = 0.3 + t * 0.15;
      camera.lookAt(
        eyeX: math.sin(angle) * r,
        eyeY: 360,
        eyeZ: math.cos(angle) * r,
        centerX: 0,
        centerY: 60,
        centerZ: 0,
      );
      for (final (i, light) in lights.indexed) {
        final a = t * (i.isEven ? 0.8 : -0.6) + i;
        light.relativeLocation = Vector3(math.cos(a) * (200 + i * 12), 60 + (i % 3) * 50, math.sin(a) * (200 + i * 12));
      }
    }

    Uint8List frame() {
      world.tick(1 / 30);
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 1) {
            c.filament_renderer_read_pixels(
              renderer.nativePointer,
              engine.nativePointer,
              0,
              0,
              w,
              h,
              pixels.cast(),
              ffi.nullptr,
              ffi.nullptr,
            );
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    final phases = <String, Map<String, Object?>>{};
    Future<void> phase(String event, String label) async {
      LuminaBlueprintFunctionLibrary.callCustomEvent(menu, event);
      Uint8List? shot;
      for (var f = 0; f < 160; f++) {
        animate();
        shot = frame();
        video.addFrame(shot);
      }
      final controller = settings.rtxController;
      final metrics = <String, Object?>{
        'activeUpscaler': settings.activeUpscaler,
        'rayReconstruction': controller?.rayReconstruction != null,
        'guideBuffers': view.guideBufferOptions.enabled,
        'frameGenerator': controller?.frameGenerator?.generatedFrames,
        'rrGpuMs': (controller?.rayReconstruction?.lastGpuTimeNanos ?? 0) / 1e6,
        'fgGpuMs': (controller?.frameGenerator?.lastGpuTimeNanos ?? 0) / 1e6,
        'fgFrameCount': controller?.frameGenerator?.frameCount ?? 0,
        'fallbacks': settings.renderingFallbacks.join(' | '),
      };
      phases[event] = metrics;
      // ignore: avoid_print
      print('$label: $metrics');
      SmokeArtifacts.saveScreenshot(
        '$testTitle $label',
        SmokeArtifacts.encodePng(w, h, shot!),
        usedAssets: usedAssets,
        metrics: metrics,
      );
    }

    await phase('UseRayReconstruction', '01 DLSS Ray Reconstruction');
    await phase('UseFrameGeneration', '02 DLSS RR + DLSS frame generation 4x');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);

    expect(printed, ['DLSS RR', 'true', 'DLSS RR', 'true']);
    expect(phases['UseRayReconstruction']!['rayReconstruction'], isTrue);
    expect(phases['UseRayReconstruction']!['guideBuffers'], isTrue);
    expect(phases['UseRayReconstruction']!['frameGenerator'], isNull);
    final expectedFrames = math.min(3, support.maxDlssGeneratedFrames);
    expect(phases['UseFrameGeneration']!['frameGenerator'], expectedFrames);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
