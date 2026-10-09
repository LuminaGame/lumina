import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The game's ray tracing / upscaler settings: values, the presets each
/// upscaler gets, the fallback when the GPU cannot do what was chosen, and
/// their persistence with the other user settings.
void main() {
  const all = LuminaRenderingFeatureSupport(rayTracing: true, dlss: true, fsr3: true, frameGeneration: true);

  group('LuminaUpscaler and LuminaUpscalerQuality', () {
    test('display names parse back, leniently, and unknown text is the default', () {
      for (final u in LuminaUpscaler.values) {
        expect(LuminaUpscaler.parse(u.displayName), u);
      }
      expect(LuminaUpscaler.parse('fsr'), LuminaUpscaler.fsr3);
      expect(LuminaUpscaler.parse(' dlss '), LuminaUpscaler.dlss);
      expect(LuminaUpscaler.parse('off'), LuminaUpscaler.none);
      expect(LuminaUpscaler.parse('xyz'), LuminaUpscaler.none);
      for (final q in LuminaUpscalerQuality.values) {
        expect(LuminaUpscalerQuality.parse(q.displayName), q);
      }
      expect(LuminaUpscalerQuality.parse('ultra_performance'), LuminaUpscalerQuality.ultraPerformance);
      expect(LuminaUpscalerQuality.parse('DLAA'), LuminaUpscalerQuality.nativeAA);
      expect(LuminaUpscalerQuality.parse('bogus'), LuminaUpscalerQuality.quality);
    });

    test('each quality maps to the matching FSR3 and DLSS preset', () {
      expect([for (final q in LuminaUpscalerQuality.values) q.fsr3], [
        LuminaFsr3Quality.nativeAA,
        LuminaFsr3Quality.quality,
        LuminaFsr3Quality.balanced,
        LuminaFsr3Quality.performance,
        LuminaFsr3Quality.ultraPerformance,
      ]);
      expect([for (final q in LuminaUpscalerQuality.values) q.dlss], [
        DlssQuality.dlaa,
        DlssQuality.maxQuality,
        DlssQuality.balanced,
        DlssQuality.maxPerformance,
        DlssQuality.ultraPerformance,
      ]);
    });
  });

  group('LuminaRenderingFeatureSettings', () {
    test('defaults are off, values clamp and the map round trips', () {
      const d = LuminaRenderingFeatureSettings();
      expect(d.rayTracing, isFalse);
      expect(d.rayTracedShadows, isTrue);
      expect(d.restir, isFalse);
      expect(d.restirCandidates, 8);
      expect(d.restirSpatialSamples, 2);
      expect(d.upscaler, LuminaUpscaler.none);
      expect(d.upscalerQuality, LuminaUpscalerQuality.quality);
      expect(d.sharpness, 0.5);
      expect(d.frameGeneration, isFalse);

      final s = d.copyWith(
        rayTracing: true,
        restir: true,
        restirCandidates: 500,
        restirSpatialSamples: -3,
        upscaler: LuminaUpscaler.dlss,
        upscalerQuality: LuminaUpscalerQuality.performance,
        sharpness: 4,
        frameGeneration: true,
      );
      expect(s.restirCandidates, 64);
      expect(s.restirSpatialSamples, 0);
      expect(s.sharpness, 1.0);
      expect(LuminaRenderingFeatureSettings.fromMap(s.toMap()), s);
      expect(s.toMap()['upscaler'], 'DLSS');
      expect(s.toMap()['upscaler_quality'], 'Performance');
      expect(LuminaRenderingFeatureSettings.fromMap(const {}), d);
      expect(LuminaRenderingFeatureSettings.fromMap(const {'upscaler': 'nope', 'restir_candidates': 'x'}), d);
    });

    test('the engine settings they describe', () {
      const s = LuminaRenderingFeatureSettings(
        rayTracing: true,
        rayTracedShadows: false,
        restir: true,
        restirCandidates: 16,
        restirSpatialSamples: 4,
        upscaler: LuminaUpscaler.fsr3,
        upscalerQuality: LuminaUpscalerQuality.balanced,
        sharpness: 0.25,
        frameGeneration: true,
      );
      expect(s.rayTracingSettings,
          const LuminaRayTracingSettings(enabled: true, sunShadows: false, restir: true, restirCandidates: 16, restirSpatialSamples: 4));
      expect(s.fsr3Settings,
          const LuminaFsr3Settings(enabled: true, quality: LuminaFsr3Quality.balanced, sharpness: 0.25, frameGeneration: true));
      expect(s.dlssSettings, const LuminaDlssSettings(quality: DlssQuality.balanced));
      final dlss = s.copyWith(upscaler: LuminaUpscaler.dlss);
      expect(dlss.dlssSettings, const LuminaDlssSettings(enabled: true, quality: DlssQuality.balanced));
      expect(dlss.fsr3Settings.enabled, isFalse);
    });
  });

  group('fallback', () {
    test('everything supported keeps the choice and reports nothing', () {
      const s = LuminaRenderingFeatureSettings(rayTracing: true, upscaler: LuminaUpscaler.fsr3, frameGeneration: true);
      final r = s.resolve(all);
      expect(r.settings, s);
      expect(r.fallbacks, isEmpty);
    });

    test('DLSS without DLSS support falls back to FSR3, then to none', () {
      const s = LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.dlss);
      final noDlss = LuminaRenderingFeatureSupport(rayTracing: true, dlss: false, fsr3: true, frameGeneration: true, dlssReason: 'no NGX');
      final r = s.resolve(noDlss);
      expect(r.settings.upscaler, LuminaUpscaler.fsr3);
      expect(r.fallbacks.single, contains('DLSS'));
      expect(r.fallbacks.single, contains('no NGX'));
      expect(noDlss.supportedUpscalers, [LuminaUpscaler.none, LuminaUpscaler.fsr3]);
      // DLSS RR is listed only when Ray Reconstruction is supported too
      expect(all.supportedUpscalers, [LuminaUpscaler.none, LuminaUpscaler.fsr3, LuminaUpscaler.dlss]);
    });

    test('nothing supported turns ray tracing, the upscaler and frame generation off with a reason each', () {
      const s = LuminaRenderingFeatureSettings(rayTracing: true, restir: true, upscaler: LuminaUpscaler.dlss, frameGeneration: true);
      final none = LuminaRenderingFeatureSupport.none('not available on the web');
      final r = s.resolve(none);
      expect(r.settings.rayTracing, isFalse);
      expect(r.settings.upscaler, LuminaUpscaler.none);
      expect(r.settings.frameGeneration, isFalse);
      expect(r.settings.restir, isTrue, reason: 'the sub-choice is kept; ray tracing being off disables it');
      expect(r.settings.rayTracingSettings.restirOptions.enabled, isFalse);
      expect(r.fallbacks, hasLength(3));
      expect(r.fallbacks.every((m) => m.contains('not available on the web')), isTrue);
      expect(none.supportedUpscalers, [LuminaUpscaler.none]);
    });

    test('frame generation needs the FSR3 upscaler', () {
      const s = LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.dlss, frameGeneration: true);
      final r = s.resolve(all);
      expect(r.settings.upscaler, LuminaUpscaler.dlss);
      expect(r.settings.frameGeneration, isFalse);
      expect(r.fallbacks.single, contains('FSR3'));
      // Not asked for: nothing to report.
      expect(const LuminaRenderingFeatureSettings(upscaler: LuminaUpscaler.dlss).resolve(all).fallbacks, isEmpty);
    });

    test('a headless (noop) engine supports none of it, with reasons', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final view = engine.createView();
      addTearDown(() {
        view.dispose();
        engine.dispose();
      });
      final support = LuminaRenderingFeatureSupport.probe(engine: engine, view: view);
      expect(support.rayTracing, isFalse);
      expect(support.dlss, isFalse);
      expect(support.fsr3, isFalse);
      expect(support.frameGeneration, isFalse);
      expect(support.rayTracingReason, isNotEmpty);
      expect(support.dlssReason, isNotEmpty);
      expect(support.fsr3Reason, isNotEmpty);
      expect(LuminaRenderingFeatureSupport.probe(engine: null, view: null).rayTracingReason, contains('renderer'));
    });
  });

  group('LuminaUserSettingsSubsystem', () {
    test('setters stage until applySettings; the result and the fallbacks are readable', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final settings = world.userSettings;
      settings
        ..setRayTracingEnabled(true)
        ..setRayTracedShadowsEnabled(false)
        ..setRestirEnabled(true)
        ..setRestirCandidates(12)
        ..setRestirSpatialSamples(3)
        ..setUpscaler('FSR3')
        ..setUpscalerQuality('Performance')
        ..setUpscalerSharpness(0.8)
        ..setFrameGenerationEnabled(true);
      expect(settings.rayTracingEnabled, isTrue);
      expect(settings.rayTracedShadowsEnabled, isFalse);
      expect(settings.restirEnabled, isTrue);
      expect(settings.restirCandidates, 12);
      expect(settings.restirSpatialSamples, 3);
      expect(settings.upscaler, 'FSR3');
      expect(settings.upscalerQuality, 'Performance');
      expect(settings.upscalerSharpness, closeTo(0.8, 1e-9));
      expect(settings.frameGenerationEnabled, isTrue);
      expect(settings.renderingFallbacks, isEmpty, reason: 'nothing applied yet');

      settings.applySettings();
      // No renderer is bound: every feature falls back, and says why.
      expect(settings.activeUpscaler, 'None');
      expect(settings.rayTracingActive, isFalse);
      expect(settings.renderingFallbacks, hasLength(3));
      expect(settings.isRayTracingSupported, isFalse);
      expect(settings.isDlssSupported, isFalse);
      expect(settings.isFsr3Supported, isFalse);
      expect(settings.isFrameGenerationSupported, isFalse);
      expect(settings.supportedUpscalers, ['None']);
      // The choice itself is kept for a GPU that can do it.
      expect(settings.upscaler, 'FSR3');
      expect(settings.rayTracingEnabled, isTrue);
    });

    test('scalability presets keep the ray tracing and upscaler choices', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final settings = world.userSettings
        ..setRayTracingEnabled(true)
        ..setUpscaler('DLSS')
        ..setFrameGenerationEnabled(true);
      for (final preset in ['Low', 'Medium', 'High', 'Epic', 'Cinematic']) {
        settings.setOverallScalabilityLevel(preset);
        expect(settings.rayTracingEnabled, isTrue, reason: preset);
        expect(settings.upscaler, 'DLSS', reason: preset);
        expect(settings.frameGenerationEnabled, isTrue, reason: preset);
      }
      expect(LuminaWorld(worldType: LuminaWorldType.game).userSettings.rayTracingEnabled, isFalse,
          reason: 'a fresh game never starts with ray tracing on');
    });

    test('the settings save to disk and load back, applied', () async {
      final dir = await Directory.systemTemp.createTemp('lumina_user_settings_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/GameUserSettings.json';
      final a = LuminaWorld(worldType: LuminaWorldType.game).userSettings
        ..setOverallScalabilityLevel('High')
        ..setShadowQuality('Cinematic')
        ..setResolutionScale(80)
        ..setTargetFps(144)
        ..setVsyncEnabled(true)
        ..setViewDistance(123456)
        ..setRayTracingEnabled(true)
        ..setRestirEnabled(true)
        ..setRestirCandidates(20)
        ..setUpscaler('DLSS')
        ..setUpscalerQuality('Ultra Performance')
        ..setUpscalerSharpness(0.1)
        ..setFrameGenerationEnabled(true);
      expect(await a.saveSettings(path: path), isTrue);

      final b = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await b.loadSettings(path: path), isTrue);
      expect(b.toMap(), a.toMap());
      expect(b.overallScalabilityLevel, 'Custom');
      expect(b.shadowQuality, 'Cinematic');
      expect(b.resolutionScale, 80);
      expect(b.targetFps, 144);
      expect(b.vsyncEnabled, isTrue);
      expect(b.viewDistance, 123456);
      expect(b.restirCandidates, 20);
      expect(b.upscaler, 'DLSS');
      expect(b.upscalerQuality, 'Ultra Performance');
      expect(b.renderingFallbacks, isNotEmpty, reason: 'loading applies, and this world has no renderer');

      // Missing and corrupt files leave the settings alone.
      final c = LuminaWorld(worldType: LuminaWorldType.game).userSettings;
      expect(await c.loadSettings(path: '${dir.path}/missing.json'), isFalse);
      await File('${dir.path}/corrupt.json').writeAsString('{not json');
      expect(await c.loadSettings(path: '${dir.path}/corrupt.json'), isFalse);
      expect(c.toMap(), LuminaWorld(worldType: LuminaWorldType.game).userSettings.toMap());
    });
  });
}
