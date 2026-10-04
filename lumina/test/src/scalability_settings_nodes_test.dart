import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaUserSettingsSubsystem & Scalability Presets', () {
    test('Default scalability values match Epic specifications', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final settings = world.userSettings;

      expect(settings.overallScalabilityLevel, equals('Epic'));
      expect(settings.viewDistanceQuality, equals('Epic'));
      expect(settings.viewDistance, equals(LuminaUserSettingsSubsystem.viewDistanceEpic));
      expect(settings.viewDistance, equals(200000.0)); // 2 km
      expect(settings.shadowQuality, equals('High'));
      expect(settings.antiAliasingQuality, equals('FXAA'));
      expect(settings.postProcessingQuality, equals('Epic'));
      expect(settings.textureQuality, equals('High'));
      expect(settings.shadingQuality, equals('Epic'));
      expect(settings.resolutionScale, equals(100.0));
      expect(settings.targetFps, equals(0));
      expect(settings.vsyncEnabled, isFalse);
    });

    test('Overall scalability level Low configures all constituent tiers and camera view distance', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final cameraActor = LuminaActor();
      final camera = LuminaCameraComponent()..isActive = true;
      cameraActor.addComponent(camera);
      world.persistentLevel.registerActor(cameraActor);

      final settings = world.userSettings;
      settings.setOverallScalabilityLevel('Low');

      expect(settings.overallScalabilityLevel, equals('Low'));
      expect(settings.viewDistanceQuality, equals('Low'));
      expect(settings.viewDistance, equals(25000.0)); // 250 m
      expect(camera.farClipPlane, equals(25000.0));
      expect(settings.shadowQuality, equals('Low'));
      expect(settings.antiAliasingQuality, equals('None'));
      expect(settings.postProcessingQuality, equals('Low'));
      expect(settings.textureQuality, equals('Low'));
      expect(settings.shadingQuality, equals('Low'));

      expect(world.appliedScalability?.shadows.mapSize, equals(512));
      expect(world.appliedScalability?.shadows.cascades, equals(1));
      expect(world.appliedScalability?.renderQuality.hdrColorBuffer, equals(QualityLevel.low));
      expect(world.appliedScalability?.dynamicResolution.enabled, isTrue);
      expect(world.appliedScalability?.dynamicResolution.minScaleX, equals(0.5));
    });

    test('Overall scalability level Cinematic configures 4km view distance, PCSS shadows, and MSAA/TAA', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final cameraActor = LuminaActor();
      final camera = LuminaCameraComponent()..isActive = true;
      cameraActor.addComponent(camera);
      world.persistentLevel.registerActor(cameraActor);

      final settings = world.userSettings;
      settings.setOverallScalabilityLevel('Cinematic');

      expect(settings.overallScalabilityLevel, equals('Cinematic'));
      expect(settings.viewDistanceQuality, equals('Cinematic'));
      expect(settings.viewDistance, equals(400000.0)); // 4 km
      expect(camera.farClipPlane, equals(400000.0));
      expect(settings.shadowQuality, equals('Cinematic'));
      expect(settings.antiAliasingQuality, equals('TAA'));
      expect(settings.postProcessingQuality, equals('Cinematic'));
      expect(settings.textureQuality, equals('Cinematic'));
      expect(settings.shadingQuality, equals('Cinematic'));

      expect(world.appliedScalability?.shadows.mapSize, equals(4096));
      expect(world.appliedScalability?.shadows.cascades, equals(4));
      expect(world.appliedScalability?.shadows.screenSpaceContactShadows, isTrue);
      expect(world.appliedScalability?.shadows.contactShadowsStepCount, equals(16));
      expect(world.appliedScalability?.renderQuality.hdrColorBuffer, equals(QualityLevel.ultra));
      expect(world.appliedScalability?.taa.enabled, isTrue);
    });

    test('Custom view distance and resolution scale mutate camera and dynamic resolution factor', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final cameraActor = LuminaActor();
      final camera = LuminaCameraComponent()..isActive = true;
      cameraActor.addComponent(camera);
      world.persistentLevel.registerActor(cameraActor);

      final settings = world.userSettings;
      settings.setViewDistance(75000.0); // 750 m
      expect(settings.viewDistance, equals(75000.0));
      expect(camera.farClipPlane, equals(75000.0));

      settings.setResolutionScale(66.0);
      expect(settings.resolutionScale, equals(66.0));
      settings.applySettings();

      expect(world.appliedScalability?.dynamicResolution.enabled, isTrue);
      expect(world.appliedScalability?.dynamicResolution.minScaleX, closeTo(0.66, 1e-4));
      expect(world.appliedScalability?.dynamicResolution.maxScaleX, closeTo(0.66, 1e-4));
    });
  });

  group('Blueprint Function Library Scalability & View Distance Nodes', () {
    test('VM functions execute setters and getters end to end', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor();
      world.persistentLevel.registerActor(actor);
      final ctx = LuminaBlueprintCallContext(actor);
      final fns = LuminaBlueprintFunctionLibrary.functions;

      // 1. Overall Scalability Level
      fns['set_overall_scalability_level']!(ctx, {'preset': 'Medium'});
      expect(fns['get_overall_scalability_level']!(ctx, const {})['return_value'], equals('Medium'));
      expect(fns['get_view_distance_quality']!(ctx, const {})['return_value'], equals('Medium'));
      expect(fns['get_view_distance']!(ctx, const {})['return_value'], equals(50000.0));

      // 2. View Distance Quality & Direct Distance
      fns['set_view_distance_quality']!(ctx, {'quality': 'High'});
      expect(fns['get_view_distance_quality']!(ctx, const {})['return_value'], equals('High'));
      expect(fns['get_view_distance']!(ctx, const {})['return_value'], equals(100000.0));

      fns['set_view_distance']!(ctx, {'distance': 350000.0});
      expect(fns['get_view_distance']!(ctx, const {})['return_value'], equals(350000.0));

      // 3. Shadow Quality
      fns['set_shadow_quality']!(ctx, {'quality': 'Cinematic'});
      expect(fns['get_shadow_quality']!(ctx, const {})['return_value'], equals('Cinematic'));

      // 4. Anti-Aliasing Quality
      fns['set_anti_aliasing_quality']!(ctx, {'quality': 'MSAA'});
      expect(fns['get_anti_aliasing_quality']!(ctx, const {})['return_value'], equals('MSAA'));

      // 5. Post Processing Quality
      fns['set_post_processing_quality']!(ctx, {'quality': 'Low'});
      expect(fns['get_post_processing_quality']!(ctx, const {})['return_value'], equals('Low'));

      // 6. Texture Quality
      fns['set_texture_quality']!(ctx, {'quality': 'High'});
      expect(fns['get_texture_quality']!(ctx, const {})['return_value'], equals('High'));

      // 7. Shading Quality
      fns['set_shading_quality']!(ctx, {'quality': 'Medium'});
      expect(fns['get_shading_quality']!(ctx, const {})['return_value'], equals('Medium'));

      // 8. Resolution Scale
      fns['set_resolution_scale']!(ctx, {'percent': 85.0});
      expect(fns['get_resolution_scale']!(ctx, const {})['return_value'], equals(85.0));

      // 9. Frame Rate & VSync
      fns['set_target_fps']!(ctx, {'fps': 120});
      expect(fns['get_target_fps']!(ctx, const {})['return_value'], equals(120));

      fns['set_vsync_enabled']!(ctx, {'enabled': true});
      expect(fns['get_vsync_enabled']!(ctx, const {})['return_value'], isTrue);

      // 10. Apply Scalability Settings
      fns['apply_scalability_settings']!(ctx, const {});
      expect(world.appliedScalability, isNotNull);
      expect(world.appliedScalability?.dynamicResolution.minScaleX, closeTo(0.85, 1e-4));
    });

    test('Node specs and call shapes are strictly declared for all 23 settings nodes', () {
      final ids = [
        'set_overall_scalability_level',
        'get_overall_scalability_level',
        'set_view_distance_quality',
        'get_view_distance_quality',
        'set_view_distance',
        'get_view_distance',
        'set_shadow_quality',
        'get_shadow_quality',
        'set_anti_aliasing_quality',
        'get_anti_aliasing_quality',
        'set_post_processing_quality',
        'get_post_processing_quality',
        'set_texture_quality',
        'get_texture_quality',
        'set_shading_quality',
        'get_shading_quality',
        'set_resolution_scale',
        'get_resolution_scale',
        'set_target_fps',
        'get_target_fps',
        'set_vsync_enabled',
        'get_vsync_enabled',
        'apply_scalability_settings',
      ];

      for (final id in ids) {
        final spec = LuminaBlueprintNodeLibrary.spec(id);
        expect(spec, isNotNull, reason: 'Spec missing for $id');
        expect(spec!.category, equals('Settings|Scalability'));
        expect(LuminaBlueprintFunctionLibrary.functions.containsKey(id), isTrue, reason: 'VM function missing for $id');
        expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: 'Call shape missing for $id');
      }
    });
  });
}
