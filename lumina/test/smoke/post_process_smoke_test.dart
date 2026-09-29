import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  group('Post Process Module Smoke Tests', () {
    test('Scenario 01: LuminaPostProcessSettings per-view diffing, tone mapper presets, and full post-pipeline state updates', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      view.scene = scene;

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);

      world.beginPlay();

      // 1. Apply customized post-process settings
      final customSettings = LuminaPostProcessSettings.standard().copyWith(
        bloom: const BloomOptions(enabled: true, strength: 0.25),
        vignette: const VignetteOptions(enabled: true, roundness: 0.8, midPoint: 0.5),
        ambientOcclusion: const AmbientOcclusionOptions(enabled: true, intensity: 1.2),
        colorGrade: LuminaColorGradeSettings(
          toneMapper: ToneMapperType.aces,
          contrast: 1.15,
          vibrance: 1.1,
          saturation: 1.05,
        ),
      );

      world.postProcess.apply(customSettings);

      expect(world.postProcess.applied.bloom.enabled, isTrue);
      expect(world.postProcess.applied.vignette.enabled, isTrue);
      expect(world.postProcess.applied.ambientOcclusion.enabled, isTrue);
      expect(world.postProcess.applied.colorGrade.toneMapper, equals(ToneMapperType.aces));

      // Tick 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // 2. Diff and mutate only color grading (AgX look)
      final agxSettings = customSettings.copyWith(
        colorGrade: LuminaColorGradeSettings(
          toneMapper: ToneMapperType.agx,
          agxLook: AgxLook.golden,
        ),
      );
      world.postProcess.apply(agxSettings);
      expect(world.postProcess.applied.colorGrade.toneMapper, equals(ToneMapperType.agx));
      expect(world.postProcess.applied.colorGrade.agxLook, equals(AgxLook.golden));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // 3. Clear TAA/SSR history
      world.postProcess.notifyCameraCut();

      world.cleanup();
      view.dispose();
      scene.dispose();
      engine.dispose();

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'Post Process Module Smoke Tests Scenario 01: LuminaPostProcessSettings per-view diffing, tone mapper presets, and full post-pipeline state updates';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );
    });

    test('Scenario 02: LuminaScalabilityProfile quality tiers, CSM shadow cascading, and sun shadow tuning with 3D assets', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      view.scene = scene;

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);

      final sunActor = LuminaActor();
      final sunLight = LuminaDirectionalLightComponent(castShadows: true);
      sunActor.addComponent(sunLight);
      world.persistentLevel.registerActor(sunActor);

      world.beginPlay();

      // 1. Apply high scalability profile
      world.applyScalability(LuminaScalabilityProfile.high);
      expect(world.appliedScalability, equals(LuminaScalabilityProfile.high));
      expect(view.shadowType, equals(ShadowType.vsm));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // 2. Switch to epic scalability profile
      world.applyScalability(LuminaScalabilityProfile.epic);
      expect(world.appliedScalability, equals(LuminaScalabilityProfile.epic));
      expect(view.shadowType, equals(ShadowType.pcss));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      world.cleanup();
      view.dispose();
      scene.dispose();
      engine.dispose();

      final usedAssets = [
        'Props/AC_units/roof_aircon_unit_300x150_a.glb',
        'Props/Barrels/fuel_barrel_yellow.glb',
      ];

      const testTitle = 'Post Process Module Smoke Tests Scenario 02: LuminaScalabilityProfile quality tiers, CSM shadow cascading, and sun shadow tuning with 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );
    });

    // A Post Process Volume around part of the orbit: the
    // camera flies in and out twice; bloom is high inside, the baseline
    // outside, and the view returns to the baseline every time.
    test('Scenario 03: LuminaPostProcessVolumeComponent blends bloom by camera position and restores the baseline', () async {
      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];
      LuminaWorld? world;
      final strengths = <double>[];
      final insideFlags = <bool>[];
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: 'Post Process Module Smoke Tests Scenario 03: LuminaPostProcessVolumeComponent bloom volume fly-through',
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        onFrame: (engine, scene, view, camera, assets, frame, total, t) {
          if (world == null) {
            world = LuminaWorld(worldType: LuminaWorldType.game)
              ..initializeNativeContext(engine, scene)
              ..attachPostProcessView(view);
            world!.postProcess.apply(LuminaPostProcessSettings.standard().copyWith(
              bloom: const BloomOptions(enabled: true, strength: 0.05),
            ));
            // A box on the +X side of the orbit (the media camera circles at
            // 3.5 m); the camera crosses it twice per revolution's half.
            world!.persistentLevel.registerActor(LuminaActor(
              root: LuminaPostProcessVolumeComponent(
                location: Vector3(LuminaUnits.metres(3.5), LuminaUnits.metres(1.8), 0),
                extent: Vector3(LuminaUnits.metres(1.0), LuminaUnits.metres(1.5), LuminaUnits.metres(2.0)),
                blendRadius: LuminaUnits.metres(0.5),
                overrides: const LuminaPostProcessOverrides(bloomIntensity: 8.0, exposure: 1.0),
              ),
            ));
            world!.beginPlay();
          }
          final eye = camera.position;
          world!.postProcessBlender.cameraPositionOverride = eye;
          world!.tick(1 / 30);
          strengths.add(world!.postProcess.applied.bloom.strength);
          insideFlags.add(world!.postProcessBlender.volumes.single.containsPoint(eye));
        },
      );
      expect(insideFlags.contains(true), isTrue, reason: 'the orbit passes through the volume');
      expect(insideFlags.contains(false), isTrue);
      for (var i = 0; i < strengths.length; i++) {
        if (insideFlags[i]) expect(strengths[i], closeTo(1.0, 1e-6), reason: 'frame $i inside: bloom 8/8');
      }
      final farOutside = [for (var i = 0; i < strengths.length; i++) if (!insideFlags[i]) strengths[i]];
      expect(farOutside.reduce((a, b) => a < b ? a : b), closeTo(0.05, 1e-6), reason: 'the baseline returns outside');
      world!.cleanup();
    });
  });
}
