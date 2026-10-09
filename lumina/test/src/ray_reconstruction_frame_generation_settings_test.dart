import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// DLSS Ray Reconstruction and DLSS Frame Generation in the game user
/// settings: values, persistence, fallback, the Blueprint nodes and, on an
/// RTX GPU, what the controller puts on the view.
void main() {
  const everything = LuminaRenderingFeatureSupport(
    rayTracing: true,
    dlss: true,
    fsr3: true,
    frameGeneration: true,
    rayReconstruction: true,
    dlssFrameGeneration: true,
    maxDlssGeneratedFrames: 5,
  );

  group('values and persistence', () {
    test('DLSS RR and the frame generator parse and round trip; generated frames clamp to 1-5', () {
      expect(LuminaUpscaler.parse('DLSS RR'), LuminaUpscaler.dlssRayReconstruction);
      expect(LuminaUpscaler.parse('ray reconstruction'), LuminaUpscaler.dlssRayReconstruction);
      expect(LuminaUpscaler.parse('dlss_rr'), LuminaUpscaler.dlssRayReconstruction);
      expect(LuminaUpscaler.parse('DLSS'), LuminaUpscaler.dlss);
      expect(LuminaFrameGenerator.parse('dlss'), LuminaFrameGenerator.dlss);
      expect(LuminaFrameGenerator.parse('FSR3'), LuminaFrameGenerator.fsr3);
      expect(LuminaFrameGenerator.parse('whatever'), LuminaFrameGenerator.fsr3);

      const d = LuminaRenderingFeatureSettings();
      expect(d.frameGenerator, LuminaFrameGenerator.fsr3);
      expect(d.dlssGeneratedFrames, 1);
      expect(d.copyWith(dlssGeneratedFrames: 9).dlssGeneratedFrames, 5);
      expect(d.copyWith(dlssGeneratedFrames: 0).dlssGeneratedFrames, 1);

      final s = d.copyWith(
        upscaler: LuminaUpscaler.dlssRayReconstruction,
        frameGeneration: true,
        frameGenerator: LuminaFrameGenerator.dlss,
        dlssGeneratedFrames: 3,
      );
      final back = LuminaRenderingFeatureSettings.fromMap(s.toMap());
      expect(back, s);
      expect(s.toMap()['upscaler'], 'DLSS RR');
      expect(s.toMap()['frame_generator'], 'DLSS');
      // a file written before these keys existed keeps the defaults
      final old = LuminaRenderingFeatureSettings.fromMap({'upscaler': 'DLSS', 'frame_generation': true});
      expect(old.frameGenerator, LuminaFrameGenerator.fsr3);
      expect(old.dlssGeneratedFrames, 1);
    });

    test('the choice is merged into GameUserSettings.json next to keys other writers own', () async {
      final dir = await Directory.systemTemp.createTemp('lumina_rr_fg_settings');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/${LuminaGameUserSettingsFile.fileName}';
      // keys of other writers (the game window, the game's own) are already there
      await File(path).writeAsString('{"window_mode": "borderless", "audio_master_volume": 0.7}');
      final a = LuminaWorld(worldType: LuminaWorldType.game).userSettings
        ..setRayTracingEnabled(true)
        ..setUpscaler('DLSS RR')
        ..setFrameGenerationEnabled(true)
        ..setFrameGenerator('DLSS')
        ..setDlssGeneratedFrames(3);
      expect(await a.saveSettings(path: path), isTrue);

      final saved = await File(path).readAsString();
      expect(saved, contains('"window_mode"'), reason: 'keys of other writers are kept');
      expect(saved, contains('"audio_master_volume"'));
      final b = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await b.loadSettings(path: path), isTrue);
      expect(b.upscaler, 'DLSS RR');
      expect(b.frameGenerator, 'DLSS');
      expect(b.dlssGeneratedFrames, 3);
      expect(b.frameGenerationEnabled, isTrue);
    });

    test('the view settings they describe', () {
      final rr = const LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.dlssRayReconstruction);
      expect(rr.dlssSettings.enabled, isTrue);
      expect(rr.dlssSettings.rayReconstruction, isTrue);
      expect(rr.fsr3Settings.enabled, isFalse);
      final fg = const LuminaRenderingFeatureSettings(
          frameGeneration: true, frameGenerator: LuminaFrameGenerator.dlss, dlssGeneratedFrames: 2);
      expect(fg.dlssFrameGenerationSettings.generatedFrames, 2);
      expect(fg.fsr3Settings.frameGeneration, isFalse);
      final fsr3Fg = const LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.fsr3, frameGeneration: true);
      expect(fsr3Fg.dlssFrameGenerationSettings.enabled, isFalse);
      expect(fsr3Fg.fsr3Settings.frameGeneration, isTrue);
      expect(LuminaDlssSettings.fromMap(const LuminaDlssSettings(rayReconstruction: true).toMap()).rayReconstruction,
          isTrue);
      expect(LuminaDlssFrameGenerationSettings.fromMap({'generated_frames': 9}).generatedFrames, 5);
    });
  });

  group('fallback', () {
    test('everything supported keeps DLSS RR and DLSS frame generation', () {
      final s = const LuminaRenderingFeatureSettings(
        rayTracing: true,
        upscaler: LuminaUpscaler.dlssRayReconstruction,
        frameGeneration: true,
        frameGenerator: LuminaFrameGenerator.dlss,
        dlssGeneratedFrames: 3,
      );
      final r = s.resolve(everything);
      expect(r.settings, s);
      expect(r.fallbacks, isEmpty);
    });

    test('DLSS RR needs ray tracing, then the runtime; it falls back to DLSS, FSR3, None', () {
      const rr = LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.dlssRayReconstruction);
      final noRt = rr.resolve(everything);
      expect(noRt.settings.upscaler, LuminaUpscaler.dlss);
      expect(noRt.fallbacks.single, contains('needs ray tracing'));

      final withRt = rr.copyWith(rayTracing: true);
      const noRr = LuminaRenderingFeatureSupport(
          rayTracing: true, dlss: true, fsr3: true, frameGeneration: true, rayReconstructionReason: 'no nvngx_dlssd');
      final r1 = withRt.resolve(noRr);
      expect(r1.settings.upscaler, LuminaUpscaler.dlss);
      expect(r1.fallbacks.single, contains('no nvngx_dlssd'));

      const onlyFsr3 = LuminaRenderingFeatureSupport(rayTracing: true, dlss: false, fsr3: true, frameGeneration: true);
      expect(withRt.resolve(onlyFsr3).settings.upscaler, LuminaUpscaler.fsr3);
      const nothing = LuminaRenderingFeatureSupport(rayTracing: true, dlss: false, fsr3: false, frameGeneration: false);
      expect(withRt.resolve(nothing).settings.upscaler, LuminaUpscaler.none);
    });

    test('DLSS frame generation falls back to FSR3 frame generation, and to the GPU maximum of frames', () {
      const fg = LuminaRenderingFeatureSettings(
        upscaler: LuminaUpscaler.fsr3,
        frameGeneration: true,
        frameGenerator: LuminaFrameGenerator.dlss,
        dlssGeneratedFrames: 5,
      );
      const noDlssFg = LuminaRenderingFeatureSupport(
          rayTracing: false, dlss: true, fsr3: true, frameGeneration: true, dlssFrameGenerationReason: 'RTX 40 needed');
      final r1 = fg.resolve(noDlssFg);
      expect(r1.settings.frameGeneration, isTrue);
      expect(r1.settings.frameGenerator, LuminaFrameGenerator.fsr3);
      expect(r1.fallbacks.single, contains('RTX 40 needed'));

      const twoX = LuminaRenderingFeatureSupport(
          rayTracing: false, dlss: true, fsr3: true, frameGeneration: true, dlssFrameGeneration: true, maxDlssGeneratedFrames: 1);
      final r2 = fg.resolve(twoX);
      expect(r2.settings.frameGenerator, LuminaFrameGenerator.dlss);
      expect(r2.settings.dlssGeneratedFrames, 1);
      expect(r2.fallbacks.single, contains('at most 1'));

      // DLSS frame generation works with any upscaler, FSR3's needs the FSR3 upscaler
      final withDlss = fg.copyWith(upscaler: LuminaUpscaler.dlss).resolve(everything);
      expect(withDlss.settings.frameGeneration, isTrue);
      expect(withDlss.fallbacks, isEmpty);
      final r3 = fg.copyWith(upscaler: LuminaUpscaler.dlss).resolve(noDlssFg);
      expect(r3.settings.frameGeneration, isFalse, reason: 'FSR3 frame generation needs the FSR3 upscaler');
    });

    test('a headless (noop) engine supports neither, with reasons', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final view = engine.createView();
      try {
        final support = LuminaRenderingFeatureSupport.probe(engine: engine, view: view, isWeb: false);
        expect(support.rayReconstruction, isFalse);
        expect(support.dlssFrameGeneration, isFalse);
        expect(support.maxDlssGeneratedFrames, 0);
        expect(support.rayReconstructionReason, isNotEmpty);
        expect(support.dlssFrameGenerationReason, isNotEmpty);
        expect(support.supportedUpscalers, isNot(contains(LuminaUpscaler.dlssRayReconstruction)));
      } finally {
        view.dispose();
        engine.dispose();
      }
    });
  });

  group('Blueprint nodes', () {
    const ids = [
      'set_frame_generator',
      'get_frame_generator',
      'set_dlss_generated_frames',
      'get_dlss_generated_frames',
      'is_ray_reconstruction_supported',
      'is_dlss_frame_generation_supported',
      'get_max_dlss_generated_frames',
    ];

    test('every new node has a spec, a VM function and a call shape, and is findable', () {
      for (final id in ids) {
        final spec = LuminaBlueprintNodeLibrary.spec(id);
        expect(spec, isNotNull, reason: id);
        expect(spec!.category, 'Settings|Ray Tracing & Upscaling', reason: id);
        expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
        expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
      }
      Set<String> found(String word) =>
          {for (final s in LuminaBlueprintNodeLibrary.builtIns) if (s.keywords.contains(word)) s.id};
      expect(found('ray reconstruction'), contains('is_ray_reconstruction_supported'));
      expect(found('mfg'), containsAll(['set_dlss_generated_frames', 'get_max_dlss_generated_frames']));
    });

    test('the VM functions stage and read back; without a renderer nothing is supported', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor();
      world.persistentLevel.registerActor(actor);
      final fns = LuminaBlueprintFunctionLibrary.functions;
      final ctx = LuminaBlueprintCallContext(actor);
      fns['set_upscaler']!(ctx, {'upscaler': 'DLSS RR'});
      fns['set_frame_generator']!(ctx, {'generator': 'DLSS'});
      fns['set_dlss_generated_frames']!(ctx, {'frames': 3});
      expect(fns['get_upscaler']!(ctx, {})['return_value'], 'DLSS RR');
      expect(fns['get_frame_generator']!(ctx, {})['return_value'], 'DLSS');
      expect(fns['get_dlss_generated_frames']!(ctx, {})['return_value'], 3);
      expect(fns['is_ray_reconstruction_supported']!(ctx, {})['return_value'], isFalse);
      expect(fns['is_dlss_frame_generation_supported']!(ctx, {})['return_value'], isFalse);
      expect(fns['get_max_dlss_generated_frames']!(ctx, {})['return_value'], 0);
      world.userSettings.applySettings();
      expect(world.userSettings.activeUpscaler, 'None');
      expect(world.userSettings.renderingFallbacks, isNotEmpty);
    });
  });

  group('on an RTX GPU (Vulkan)', () {
    FilamentEngine? engine;

    setUp(() {
      // the NGX runtimes fetched for flutter_filament (tool/dlss/fetch_sdk.dart), when present
      final sdk = Directory('../flutter_filament/build/dlss-sdk');
      LuminaRtxController.requestExtensions(dlssRuntimeDir: sdk.existsSync() ? sdk.absolute.path : null);
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
    });

    tearDown(() {
      engine?.dispose();
      engine = null;
      Dlss.clearExtensionRequest();
      DlssFrameGeneration.clearExtensionRequest();
      RayTracing.clearExtensionRequest();
    });

    test('the controller puts Ray Reconstruction and the frame generator on the view and takes them off', () {
      final e = engine;
      if (e == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      if (!LuminaRtxController.rayReconstructionSupported(e) || LuminaRtxController.maxDlssGeneratedFrames(e) == 0) {
        markTestSkipped('needs the NGX Ray Reconstruction and Frame Generation runtimes on an RTX GPU');
        return;
      }
      final scene = e.createScene();
      final view = e.createView()
        ..scene = scene
        ..setViewport(0, 0, 1280, 720);
      final controller = LuminaRtxController(engine: e, view: view, scene: scene);
      try {
        const rt = LuminaRayTracingSettings(enabled: true, restir: true);
        controller.apply(
          rt,
          const LuminaDlssSettings(enabled: true, rayReconstruction: true),
          dlssFrameGeneration: const LuminaDlssFrameGenerationSettings(generatedFrames: 3),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        expect(controller.rayReconstruction, isNotNull);
        expect(controller.dlss, isNull);
        expect(view.guideBufferOptions.enabled, isTrue);
        expect(controller.frameGenerator, isNotNull);
        expect(controller.frameGenerator!.generatedFrames, 3);
        final (rw, rh) = controller.rayReconstruction!.renderResolution;
        expect(rw, lessThan(1280));
        expect(rh, lessThan(720));

        // A chosen screen resolution in borderless fullscreen resizes the
        // view's render target: Ray Reconstruction follows it on the next
        // apply (the per-frame tick), rendering at its quality scale of it.
        view.setViewport(0, 0, 1920, 1080);
        controller.apply(
          rt,
          const LuminaDlssSettings(enabled: true, rayReconstruction: true),
          dlssFrameGeneration: const LuminaDlssFrameGenerationSettings(generatedFrames: 3),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        expect(controller.rayReconstruction, isNotNull);
        final (fw, fh) = controller.rayReconstruction!.renderResolution;
        expect(fw, greaterThan(rw));
        expect(fw, lessThan(1920));
        expect(fw / fh, closeTo(1920 / 1080, 0.02));
        expect(controller.frameGenerator, isNotNull);

        // RR off -> Super Resolution; frame generation off
        controller.apply(
          rt,
          const LuminaDlssSettings(enabled: true),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        expect(controller.rayReconstruction, isNull);
        expect(controller.dlss, isNotNull);
        expect(view.guideBufferOptions.enabled, isFalse);
        expect(controller.frameGenerator, isNull);

        controller.apply(
          const LuminaRayTracingSettings(),
          const LuminaDlssSettings(),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        expect(controller.dlss, isNull);
        expect(view.dynamicResolutionOptions.upscaler, Upscaler.builtin);
      } finally {
        controller.dispose();
        view.dispose();
        scene.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
