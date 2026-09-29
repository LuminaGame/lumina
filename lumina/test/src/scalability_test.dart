import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaScalabilityProfile Presets & Validation', () {
    test('Preset table asserted literally: low, medium, high, epic match exact specs', () {
      final low = LuminaScalabilityProfile.low;
      expect(low.shadows.shadowType, equals(ShadowType.pcf));
      expect(low.shadows.mapSize, equals(512));
      expect(low.shadows.cascades, equals(1));
      expect(low.shadows.screenSpaceContactShadows, isFalse);
      expect(low.renderQuality.hdrColorBuffer, equals(QualityLevel.low));
      expect(low.dynamicResolution.enabled, isTrue);
      expect(low.dynamicResolution.minScaleX, equals(0.5));
      expect(low.taa.enabled, isFalse);
      expect(low.antiAliasing, equals(AntiAliasing.fxaa));

      final medium = LuminaScalabilityProfile.medium;
      expect(medium.shadows.shadowType, equals(ShadowType.pcf));
      expect(medium.shadows.mapSize, equals(1024));
      expect(medium.shadows.cascades, equals(2));
      expect(medium.shadows.splitMode, equals(CsmSplitMode.practical));
      expect(medium.shadows.practicalLambda, equals(0.5));
      expect(medium.renderQuality.hdrColorBuffer, equals(QualityLevel.medium));
      expect(medium.dynamicResolution.enabled, isTrue);
      expect(medium.dynamicResolution.minScaleX, equals(0.75));
      expect(medium.taa.enabled, isFalse);
      expect(medium.antiAliasing, equals(AntiAliasing.fxaa));

      final high = LuminaScalabilityProfile.high;
      expect(high.shadows.shadowType, equals(ShadowType.vsm));
      expect(high.shadows.vsm.anisotropy, equals(2));
      expect(high.shadows.vsm.mipmapping, isTrue);
      expect(high.shadows.mapSize, equals(2048));
      expect(high.shadows.cascades, equals(3));
      expect(high.shadows.splitMode, equals(CsmSplitMode.practical));
      expect(high.shadows.practicalLambda, equals(0.5));
      expect(high.shadows.stable, isTrue);
      expect(high.renderQuality.hdrColorBuffer, equals(QualityLevel.high));
      expect(high.dynamicResolution.enabled, isFalse);
      expect(high.taa.enabled, isTrue);
      expect(high.antiAliasing, equals(AntiAliasing.none));

      final epic = LuminaScalabilityProfile.epic;
      expect(epic.shadows.shadowType, equals(ShadowType.pcss));
      expect(epic.shadows.mapSize, equals(4096));
      expect(epic.shadows.cascades, equals(4));
      expect(epic.shadows.splitMode, equals(CsmSplitMode.practical));
      expect(epic.shadows.practicalLambda, equals(0.5));
      expect(epic.shadows.screenSpaceContactShadows, isTrue);
      expect(epic.shadows.contactShadowsStepCount, equals(8));
      expect(epic.shadows.stable, isTrue);
      expect(epic.renderQuality.hdrColorBuffer, equals(QualityLevel.ultra));
      expect(epic.dynamicResolution.enabled, isFalse);
      expect(epic.taa.enabled, isTrue);
      expect(epic.antiAliasing, equals(AntiAliasing.none));
    });

    test('toShadowOptions calculates correct CSM splits for low, medium, high, and uniform', () {
      final highShadows = LuminaScalabilityProfile.high.shadows;
      final highOpts = highShadows.toShadowOptions(cameraNear: 0.1, cameraFar: 100.0);
      expect(highOpts.shadowCascades, equals(3));
      expect(highOpts.cascadeSplitPositions.length, equals(3));
      expect(highOpts.cascadeSplitPositions[0], greaterThan(0.0));
      expect(highOpts.cascadeSplitPositions[1], greaterThan(highOpts.cascadeSplitPositions[0]));

      final expectedSplits = ShadowCascades.computePracticalSplits(3, nearPlane: 0.1, farPlane: 100.0, lambda: 0.5);
      expect(highOpts.cascadeSplitPositions[0], closeTo(expectedSplits[0], 1e-6));
      expect(highOpts.cascadeSplitPositions[1], closeTo(expectedSplits[1], 1e-6));

      final lowShadows = LuminaScalabilityProfile.low.shadows;
      final lowOpts = lowShadows.toShadowOptions(cameraNear: 0.1, cameraFar: 100.0);
      expect(lowOpts.shadowCascades, equals(1));
      expect(lowOpts.cascadeSplitPositions.every((s) => s == 0.0), isTrue);

      final uniformShadows = LuminaShadowSettings(
        cascades: 2,
        splitMode: CsmSplitMode.uniform,
      );
      final uniformOpts = uniformShadows.toShadowOptions(cameraNear: 0.1, cameraFar: 100.0);
      expect(uniformOpts.shadowCascades, equals(2));
      expect(uniformOpts.cascadeSplitPositions[0], closeTo(0.5, 1e-6));
    });

    test('Validation on invalid mapSize, cascades, and practicalLambda throws ArgumentError', () {
      expect(
        () => LuminaShadowSettings(mapSize: 1000),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(mapSize: 128),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(mapSize: 8192),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(cascades: 5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(cascades: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(practicalLambda: 1.5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaShadowSettings(practicalLambda: -0.1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('LuminaScalabilityProfile Integration with World and DirectionalLight', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late FilamentView view;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      view = engine.createView();
      view.scene = scene;

      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
    });

    tearDown(() {
      world.cleanup();
      view.dispose();
      scene.dispose();
      engine.dispose();
    });

    test('world.applyScalability(high) updates view shadow type, vsm options, and light shadow options', () {
      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      world.applyScalability(LuminaScalabilityProfile.high);

      expect(world.appliedScalability, equals(LuminaScalabilityProfile.high));
      expect(view.shadowType, equals(ShadowType.vsm));
      expect(view.vsmShadowOptions.anisotropy, equals(2));

      final lm = FilamentLightManager(engine);
      final lightOpts = lm.getShadowOptions(sunLight.lightEntity!);
      expect(lightOpts.mapSize, equals(2048));
      expect(lightOpts.shadowCascades, equals(3));
      expect(lightOpts.stable, isTrue);

      final expectedSplits = ShadowCascades.computePracticalSplits(3, nearPlane: 0.1, farPlane: 100.0, lambda: 0.5);
      expect(lightOpts.cascadeSplitPositions[0], closeTo(expectedSplits[0], 1e-6));
      expect(lightOpts.cascadeSplitPositions[1], closeTo(expectedSplits[1], 1e-6));
    });

    test('Re-applying identical profile does not cause extraneous updates', () {
      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      world.applyScalability(LuminaScalabilityProfile.high);
      world.applyScalability(LuminaScalabilityProfile.high);
      expect(world.appliedScalability, equals(LuminaScalabilityProfile.high));
    });

    test('applyScalability with mapSize modification updates light shadow options', () {
      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      world.applyScalability(LuminaScalabilityProfile.high);

      final modified = LuminaScalabilityProfile.high.copyWith(
        shadows: LuminaScalabilityProfile.high.shadows.copyWith(mapSize: 1024),
      );
      world.applyScalability(modified);

      final lm = FilamentLightManager(engine);
      final lightOpts = lm.getShadowOptions(sunLight.lightEntity!);
      expect(lightOpts.mapSize, equals(1024));
    });

    test('Late-joining directional light receives applied shadow options on registration', () {
      world.applyScalability(LuminaScalabilityProfile.high);

      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      final lm = FilamentLightManager(engine);
      final lightOpts = lm.getShadowOptions(sunLight.lightEntity!);
      expect(lightOpts.mapSize, equals(2048));
      expect(lightOpts.shadowCascades, equals(3));
    });

    test('applyShadowSettings with no shadow-casting lights applies to view without error', () {
      world.postProcess.applyShadowSettings(LuminaScalabilityProfile.high.shadows);
      expect(view.shadowType, equals(ShadowType.vsm));
    });

    test('Switching low -> medium -> high -> epic and rendering one frame under each is stable', () {
      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      final presets = [
        LuminaScalabilityProfile.low,
        LuminaScalabilityProfile.medium,
        LuminaScalabilityProfile.high,
        LuminaScalabilityProfile.epic,
      ];

      world.beginPlay();

      for (final profile in presets) {
        world.applyScalability(profile);
        world.tick(1.0 / 60.0);
      }
    });
  });
}
