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
  });
}
