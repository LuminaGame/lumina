import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Exponential Height Fog fields mapped onto
/// Filament's per-view `FogOptions`, published through the world's blender.
void main() {
  group('LuminaHeightFogSettings.toFogOptions', () {
    test('defaults: per-metre density and falloff become per-cm, no cutoff → infinity', () {
      const s = LuminaHeightFogSettings(height: 250.0);
      final f = s.toFogOptions(LuminaPostProcessSettings.standard().fog);
      expect(f.enabled, isTrue);
      expect(f.density, closeTo(0.02 / LuminaUnits.unitsPerMetre, 1e-12));
      expect(f.heightFalloff, closeTo(0.2 / LuminaUnits.unitsPerMetre, 1e-12));
      expect(f.cutOffDistance, double.infinity);
      expect(f.distance, 0.0);
      expect(f.maximumOpacity, 1.0);
      expect(f.height, 250.0);
      expect(f.fogColorFromIbl, isFalse);
      expect(f.colorR, closeTo(0.447, 1e-9));
      expect(f.colorB, closeTo(1.0, 1e-9));
    });

    test('cutoff, opacity, start distance, sky colour and enabled pass through', () {
      const s = LuminaHeightFogSettings(
        fogCutoffDistance: 1500.0,
        fogMaxOpacity: 0.7,
        startDistance: 300.0,
        useSkyColor: true,
        enabled: false,
      );
      final f = s.toFogOptions(LuminaPostProcessSettings.standard().fog);
      expect(f.cutOffDistance, 1500.0);
      expect(f.maximumOpacity, closeTo(0.7, 1e-9));
      expect(f.distance, 300.0);
      expect(f.fogColorFromIbl, isTrue);
      expect(f.enabled, isFalse);
    });

    test('fromProperties ↔ toProperties round-trips; missing keys take the defaults', () {
      final s = LuminaHeightFogSettings.fromProperties(const {
        'fogDensity': 0.05,
        'inscatteringColorHex': '#7FA3FF',
        'useSkyColor': true,
      }, height: 10.0);
      expect(s.fogDensity, 0.05);
      expect(s.fogHeightFalloff, LuminaHeightFogSettings.defaults.fogHeightFalloff);
      expect(s.inscatteringColor.x, closeTo(0x7F / 255.0, 1 / 255.0));
      expect(s.inscatteringColor.y, closeTo(0xA3 / 255.0, 1 / 255.0));
      expect(s.inscatteringColor.z, closeTo(1.0, 1 / 255.0));
      expect(s.useSkyColor, isTrue);
      expect(s.height, 10.0);
      final back = LuminaHeightFogSettings.fromProperties(s.toProperties(), height: 10.0);
      expect(back, s);
      expect(s.toProperties()['inscatteringColorHex'], '#7FA3FF');
    });
  });

  group('LuminaExponentialHeightFogComponent on a world', () {
    test('registering publishes the settings; edits republish on tick; unregister clears; a second one wins', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      addTearDown(world.cleanup);
      final fog = LuminaExponentialHeightFogComponent(location: Vector3(0, 250.0, 0), fogDensity: 0.03);
      final actor = LuminaActor(root: fog);
      world.persistentLevel.registerActor(actor);
      final blender = world.postProcessBlender;
      expect(blender.heightFog, isNotNull);
      expect(blender.heightFog!.fogDensity, 0.03);
      expect(blender.heightFog!.height, 250.0);
      expect(identical(blender.heightFogOwner, fog), isTrue);

      world.beginPlay();
      fog.fogDensity = 0.05;
      actor.actorLocation = Vector3(0, 550.0, 0);
      world.tick(1 / 60);
      expect(blender.heightFog!.fogDensity, 0.05);
      expect(blender.heightFog!.height, 550.0);

      final second = LuminaExponentialHeightFogComponent(fogDensity: 0.01);
      world.persistentLevel.registerActor(LuminaActor(root: second));
      expect(blender.heightFog!.fogDensity, 0.01, reason: 'Filament has one fog per view: the latest wins');

      world.persistentLevel.unregisterActor(actor);
      expect(blender.heightFog!.fogDensity, 0.01, reason: 'the first one is not the owner any more');
      world.persistentLevel.unregisterActor(second.owner!);
      expect(blender.heightFog, isNull);
    });

    test('fromProperties builds the component; disabled or hidden publishes enabled: false', () {
      final c = LuminaExponentialHeightFogComponent.fromProperties(const {'fogDensity': 0.09, 'enabled': false});
      expect(c.fogDensity, 0.09);
      expect(c.settings.enabled, isFalse);
      final v = LuminaExponentialHeightFogComponent(visible: false);
      expect(v.settings.enabled, isFalse);
    });

    test('with a bound view the world applies the fog after a tick and follows the actor height', () {
      final engine = FilamentEngine.create();
      if (engine == null) return; // no noop backend in this run
      final scene = engine.createScene();
      final view = engine.createView()..scene = scene;
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
      addTearDown(() {
        world.cleanup();
        view.dispose();
        scene.dispose();
        engine.dispose();
      });
      final actor = LuminaActor(root: LuminaExponentialHeightFogComponent(location: Vector3(0, 120.0, 0)));
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1 / 60);
      expect(world.postProcess.applied.fog.enabled, isTrue);
      expect(world.postProcess.applied.fog.height, 120.0);
      expect(world.postProcess.baseline.fog.enabled, isFalse, reason: 'the fog actor is not the baseline');
      actor.actorLocation = Vector3(0, 420.0, 0);
      world.tick(1 / 60);
      expect(world.postProcess.applied.fog.height, 420.0);
    });
  });
}
