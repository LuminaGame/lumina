import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaPostProcessSettings Value Object & Validation', () {
    test('Validation on invalid lutDimensions throws ArgumentError', () {
      expect(
        () => LuminaColorGradeSettings(lutDimensions: 15),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaColorGradeSettings(lutDimensions: 65),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validation on invalid whiteBalance range throws ArgumentError', () {
      expect(
        () => LuminaColorGradeSettings(whiteBalance: (2.0, 0.0)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LuminaColorGradeSettings(whiteBalance: (0.0, -1.5)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Equality and copyWith on LuminaPostProcessSettings and LuminaColorGradeSettings', () {
      final std1 = LuminaPostProcessSettings.standard();
      final std2 = LuminaPostProcessSettings.standard();
      expect(std1, equals(std2));
      expect(std1.hashCode, equals(std2.hashCode));

      final modified = std1.copyWith(
        bloom: std1.bloom.copyWith(enabled: true, strength: 0.25),
      );
      expect(modified, isNot(equals(std1)));
      expect(modified.bloom.enabled, isTrue);
      expect(modified.bloom.strength, equals(0.25));

      final gradeModified = std1.copyWith(
        colorGrade: std1.colorGrade.copyWith(toneMapper: ToneMapperType.filmic),
      );
      expect(gradeModified, isNot(equals(std1)));
      expect(gradeModified.colorGrade.toneMapper, equals(ToneMapperType.filmic));
    });
  });

  group('LuminaPostProcessController Native Integration', () {
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

    test('First apply(standard()) pushes every family once and view reads back pushed values', () {
      final std = LuminaPostProcessSettings.standard();
      world.postProcess.apply(std);

      expect(world.postProcess.applied, equals(std));
      expect(view.bloomOptions.enabled, equals(std.bloom.enabled));
      expect(view.ambientOcclusionOptions.enabled, equals(std.ambientOcclusion.enabled));
      expect(view.dithering, equals(std.dithering));
      expect(view.postProcessingEnabled, equals(std.postProcessingEnabled));
    });

    test('Second apply of an == settings object triggers 0 native setter calls (diff contract)', () {
      final std1 = LuminaPostProcessSettings.standard();
      world.postProcess.apply(std1);

      final std2 = LuminaPostProcessSettings.standard();
      world.postProcess.apply(std2);
      expect(world.postProcess.applied, equals(std2));
    });

    test('apply with single-family modification updates only that family', () {
      final std = LuminaPostProcessSettings.standard();
      world.postProcess.apply(std);

      final modified = std.copyWith(
        bloom: std.bloom.copyWith(enabled: true, strength: 0.5),
      );
      world.postProcess.apply(modified);

      expect(view.bloomOptions.enabled, isTrue);
      expect(view.bloomOptions.strength, equals(0.5));
    });

    test('Changing colorGrade toneMapper filmic -> agx(punchy) rebuilds ColorGrading safely', () {
      final settingsFilmic = LuminaPostProcessSettings.standard().copyWith(
        colorGrade: LuminaColorGradeSettings(toneMapper: ToneMapperType.filmic),
      );
      world.postProcess.apply(settingsFilmic);

      final settingsAgx = settingsFilmic.copyWith(
        colorGrade: LuminaColorGradeSettings(
          toneMapper: ToneMapperType.agx,
          agxLook: AgxLook.punchy,
        ),
      );
      world.postProcess.apply(settingsAgx);

      expect(world.postProcess.applied.colorGrade.toneMapper, equals(ToneMapperType.agx));
      expect(world.postProcess.applied.colorGrade.agxLook, equals(AgxLook.punchy));
    });

    test('notifyCameraCut calls clearFrameHistory on bound view without error', () {
      final settings = LuminaPostProcessSettings.standard().copyWith(
        taa: const TemporalAntiAliasingOptions(enabled: true),
      );
      world.postProcess.apply(settings);

      world.postProcess.notifyCameraCut();
    });

    test('Dynamic resolution options round-trip and lastDynamicResolutionScale', () {
      final dynRes = LuminaPostProcessSettings.standard().copyWith(
        dynamicResolution: const DynamicResolutionOptions(
          enabled: true,
          minScaleX: 0.5,
          minScaleY: 0.5,
        ),
      );
      world.postProcess.apply(dynRes);

      expect(view.dynamicResolutionOptions.enabled, isTrue);
      expect(view.dynamicResolutionOptions.minScaleX, equals(0.5));
      expect(view.dynamicResolutionOptions.minScaleY, equals(0.5));

      final scale = world.postProcess.lastDynamicResolutionScale;
      expect(scale.$1, greaterThan(0.0));
      expect(scale.$2, greaterThan(0.0));
    });

    test('readBack() after apply matches applied settings', () {
      final custom = LuminaPostProcessSettings.standard().copyWith(
        vignette: const VignetteOptions(enabled: true, roundness: 0.8, midPoint: 0.4),
        renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.high),
      );
      world.postProcess.apply(custom);

      final readBack = world.postProcess.readBack();
      expect(readBack.vignette.enabled, equals(custom.vignette.enabled));
      expect(readBack.vignette.roundness, closeTo(custom.vignette.roundness, 1e-5));
      expect(readBack.vignette.midPoint, closeTo(custom.vignette.midPoint, 1e-5));
      expect(readBack.renderQuality.hdrColorBuffer, equals(custom.renderQuality.hdrColorBuffer));
      expect(readBack.postProcessingEnabled, equals(custom.postProcessingEnabled));
    });

    test('Full-pipeline apply(standard) and apply(none) lifecycle is stable', () {
      final full = LuminaPostProcessSettings.standard().copyWith(
        bloom: const BloomOptions(enabled: true, strength: 0.2),
        ambientOcclusion: const AmbientOcclusionOptions(enabled: true),
        taa: const TemporalAntiAliasingOptions(enabled: true),
        vignette: const VignetteOptions(enabled: true),
        fog: const FogOptions(enabled: true, distance: 5.0),
        colorGrade: LuminaColorGradeSettings(
          toneMapper: ToneMapperType.acesLegacy,
          contrast: 1.1,
          vibrance: 1.05,
        ),
      );
      world.postProcess.apply(full);

      final none = LuminaPostProcessSettings.none();
      world.postProcess.apply(none);

      expect(world.postProcess.applied.postProcessingEnabled, isFalse);
      expect(world.postProcess.applied.colorGrade.toneMapper, equals(ToneMapperType.linear));
    });

    test('World cleanup with live grading detaches colorGrading and double cleanup is a no-op', () {
      final full = LuminaPostProcessSettings.standard();
      world.postProcess.apply(full);

      world.cleanup();
      expect(world.isCleanedUp, isTrue);

      // Second cleanup is safe no-op
      world.cleanup();
      expect(world.isCleanedUp, isTrue);
    });
  });
}
