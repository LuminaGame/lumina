import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Ray tracing and DLSS settings for a view, and the controller that applies
/// them without touching Filament where the engine cannot support them.
void main() {
  group('LuminaRayTracingSettings', () {
    test('defaults, copy, map round trip and the ReSTIR options they describe', () {
      const defaults = LuminaRayTracingSettings();
      expect(defaults.enabled, isFalse);
      expect(defaults.sunShadows, isTrue);
      expect(defaults.restir, isFalse);
      expect(defaults.restirOptions.enabled, isFalse);

      final on = defaults.copyWith(enabled: true, restir: true, restirCandidates: 100, restirSpatialSamples: -1);
      expect(on.restirCandidates, 64, reason: 'clamped');
      expect(on.restirSpatialSamples, 0, reason: 'clamped');
      expect(on.restirOptions.enabled, isTrue);
      expect(on.restirOptions.initialCandidates, 64);
      expect(LuminaRayTracingSettings.fromMap(on.toMap()), on);
      expect(LuminaRayTracingSettings.fromMap(const {}), defaults);
    });
  });

  group('LuminaDlssSettings', () {
    test('defaults and map round trip', () {
      const defaults = LuminaDlssSettings();
      expect(defaults.enabled, isFalse);
      expect(defaults.quality, DlssQuality.balanced);
      const set = LuminaDlssSettings(enabled: true, quality: DlssQuality.maxQuality);
      expect(LuminaDlssSettings.fromMap(set.toMap()), set);
      expect(LuminaDlssSettings.fromMap(const {'quality': 'nonsense'}).quality, DlssQuality.balanced);
    });
  });

  group('LuminaFsr3Settings', () {
    test('defaults, map round trip and the Filament options they describe', () {
      const d = LuminaFsr3Settings();
      expect(d.enabled, isFalse);
      expect(d.quality, LuminaFsr3Quality.quality);
      expect(d.sharpness, 0.5);
      expect(d.frameGeneration, isFalse);
      const s = LuminaFsr3Settings(enabled: true, quality: LuminaFsr3Quality.performance, sharpness: 0.8, frameGeneration: true);
      expect(LuminaFsr3Settings.fromMap(s.toMap()), s);
      expect(LuminaFsr3Settings.fromMap(const {'quality': 'bogus', 'sharpness': 7}).quality, LuminaFsr3Quality.quality);
      expect(LuminaFsr3Settings.fromMap(const {'sharpness': 7}).sharpness, 1.0);
      final taa = s.taaOptions(const TemporalAntiAliasingOptions(feedback: 0.2));
      expect(taa.enabled, isTrue);
      expect(taa.algorithm, TaaAlgorithm.fsr3);
      expect(taa.upscaling, 2.0);
      expect(taa.sharpness, closeTo(0.8, 1e-9));
      expect(taa.frameGeneration, isTrue);
      expect(taa.feedback, closeTo(0.2, 1e-9), reason: 'the profile\'s other TAA values stay');
      final dyn = s.dynamicResolutionOptions;
      expect(dyn.enabled, isTrue);
      expect(dyn.minScaleX, closeTo(0.5, 1e-9));
      expect(dyn.maxScaleY, closeTo(0.5, 1e-9));
      expect(const LuminaFsr3Settings(quality: LuminaFsr3Quality.nativeAA).dynamicResolutionOptions.enabled, isFalse);
      expect(s.copyWith(sharpness: 3).sharpness, 1.0);
    });
  });

  group('LuminaShadowSettings', () {
    test('rayTraced reaches the Filament shadow options', () {
      final settings = LuminaShadowSettings(rayTraced: true);
      expect(settings.toShadowOptions(cameraNear: 10, cameraFar: 10000).rayTraced, isTrue);
      expect(settings.copyWith(rayTraced: false).toShadowOptions(cameraNear: 10, cameraFar: 10000).rayTraced, isFalse);
      expect(const LuminaShadowSettings.defaults().rayTraced, isFalse);
    });
  });

  group('LuminaRtxController', () {
    test('on an engine without ray query it keeps the settings and leaves the froxel path on', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      final view = engine.createView();
      view.scene = scene;
      view.setViewport(0, 0, 320, 240);
      final sun = engine.createEntity();
      LightBuilder(LightType.directional)
        ..castShadows(true)
        ..build(engine, sun);
      scene.addEntity(sun);
      final controller = LuminaRtxController(engine: engine, view: view, scene: scene);
      try {
        expect(controller.rayTracingSupported, isFalse);
        controller.apply(
          const LuminaRayTracingSettings(enabled: true, restir: true),
          const LuminaDlssSettings(enabled: true),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        expect(scene.rayTracingEnabled, isFalse, reason: 'nothing to build without ray query');
        expect(view.restirOptions.enabled, isFalse);
        expect(FilamentLightManager(engine).getShadowOptions(sun).rayTraced, isFalse);
        expect(controller.dlss, isNull, reason: 'no NGX on the noop backend');
        expect(controller.appliedRayTracing, const LuminaRayTracingSettings(enabled: true, restir: true));
        controller.apply(
          const LuminaRayTracingSettings(),
          const LuminaDlssSettings(),
          baseTaa: const TemporalAntiAliasingOptions(),
          baseDynamicResolution: const DynamicResolutionOptions(),
        );
        controller.dispose();
      } finally {
        engine.destroyEntity(sun);
        view.dispose();
        scene.dispose();
        engine.dispose();
      }
    });

    test('FSR3 puts its TAA and dynamic resolution on the view and off again restores the profile', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final scene = engine.createScene();
      final view = engine.createView();
      view.scene = scene;
      view.setViewport(0, 0, 320, 240);
      final controller = LuminaRtxController(engine: engine, view: view, scene: scene);
      const base = TemporalAntiAliasingOptions(enabled: true, feedback: 0.3);
      const baseDyn = DynamicResolutionOptions(enabled: true, minScaleX: 0.7, minScaleY: 0.7);
      try {
        final supported = controller.fsr3Supported;
        controller.apply(
          const LuminaRayTracingSettings(),
          const LuminaDlssSettings(),
          fsr3: const LuminaFsr3Settings(enabled: true, quality: LuminaFsr3Quality.performance, frameGeneration: true),
          baseTaa: base,
          baseDynamicResolution: baseDyn,
        );
        expect(controller.appliedFsr3?.enabled, isTrue);
        expect(controller.fsr3Active, supported);
        if (supported) {
          expect(view.temporalAntiAliasingOptions.algorithm, TaaAlgorithm.fsr3);
          expect(view.temporalAntiAliasingOptions.upscaling, closeTo(2.0, 1e-6));
          expect(view.temporalAntiAliasingOptions.frameGeneration, isTrue);
          expect(view.temporalAntiAliasingOptions.feedback, closeTo(0.3, 1e-6));
          expect(view.dynamicResolutionOptions.maxScaleX, closeTo(0.5, 1e-6));
        }
        // the preset changes without toggling
        controller.apply(
          const LuminaRayTracingSettings(),
          const LuminaDlssSettings(),
          fsr3: const LuminaFsr3Settings(enabled: true, quality: LuminaFsr3Quality.nativeAA),
          baseTaa: base,
          baseDynamicResolution: baseDyn,
        );
        if (supported) {
          expect(view.temporalAntiAliasingOptions.upscaling, closeTo(1.0, 1e-6));
          expect(view.dynamicResolutionOptions.enabled, isFalse);
        }
        controller.apply(
          const LuminaRayTracingSettings(),
          const LuminaDlssSettings(),
          baseTaa: base,
          baseDynamicResolution: baseDyn,
        );
        expect(controller.fsr3Active, isFalse);
        expect(view.temporalAntiAliasingOptions.algorithm, TaaAlgorithm.filament);
        if (supported) {
          // the profile's own options come back only where FSR3 had replaced them
          expect(view.temporalAntiAliasingOptions.feedback, closeTo(0.3, 1e-6));
          expect(view.dynamicResolutionOptions.minScaleX, closeTo(0.7, 1e-6));
        }
        controller.dispose();
      } finally {
        view.dispose();
        scene.dispose();
        engine.dispose();
      }
    });
  });
}
