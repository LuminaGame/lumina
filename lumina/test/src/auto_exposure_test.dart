import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A level lit only by point and spot lights is exposed
/// for them (auto exposure), not for a 100 000 lux sun; the light
/// colour hex is sRGB.
void main() {
  double log2(double v) => math.log(v) / math.ln2;
  final sunny = log2(16 * 16 * 125);

  group('LuminaAutoExposure.ev100For', () {
    test('no light, a sky light or a template sun keep the sunny-16 exposure', () {
      expect(LuminaAutoExposure.daylightEv100, closeTo(sunny, 1e-9));
      expect(LuminaAutoExposure.ev100For(const []), closeTo(sunny, 1e-9));
      final lamp = LuminaPointLightComponent(intensity: 55695);
      expect(LuminaAutoExposure.ev100For([lamp], skyLight: true), closeTo(sunny, 1e-9),
          reason: 'an image-based sky light is daylight');
      final sun = LuminaDirectionalLightComponent(intensity: 100000);
      expect(LuminaAutoExposure.ev100For([sun, lamp]), closeTo(sunny, 1e-9),
          reason: 'a 100 000 lux sun is exposed exactly as before');
    });

    test('a level lit only by the user\'s point light is metered for it', () {
      final lamp = LuminaPointLightComponent(intensity: 55695);
      // 55 695 lm / 4π = 4 432 cd; 1 108 lux at 2 m; EV100 = log2(E / 2.5).
      final expected = log2(55695 / (4 * math.pi) / 4 / 2.5);
      expect(LuminaAutoExposure.ev100For([lamp]), closeTo(expected, 1e-6));
      expect(expected, lessThan(sunny - 6), reason: 'about 6 stops brighter than sunny 16');
    });

    test('a spot light is metered by Filament\'s lm / π; candela lights directly; the brightest light wins', () {
      final spot = LuminaSpotLightComponent(intensity: 50000);
      expect(LuminaAutoExposure.ev100For([spot]), closeTo(log2(50000 / math.pi / 4 / 2.5), 1e-6));
      final cd = LuminaPointLightComponent(intensity: 1000, intensityInCandela: true);
      expect(LuminaAutoExposure.ev100For([cd]), closeTo(log2(1000 / 4 / 2.5), 1e-6));
      final dim = LuminaPointLightComponent(intensity: 500);
      expect(LuminaAutoExposure.ev100For([dim, spot]), LuminaAutoExposure.ev100For([spot]));
    });

    test('a hidden or zero-intensity light is not metered; the exposure is clamped', () {
      final hidden = LuminaPointLightComponent(intensity: 50000, visible: false);
      final off = LuminaPointLightComponent(intensity: 0);
      expect(LuminaAutoExposure.ev100For([hidden, off]), closeTo(sunny, 1e-9));
      final candle = LuminaPointLightComponent(intensity: 0.01);
      expect(LuminaAutoExposure.ev100For([candle]), LuminaAutoExposure.minEv100);
      final moon = LuminaDirectionalLightComponent(intensity: 0.5);
      final lamp = LuminaPointLightComponent(intensity: 55695);
      expect(LuminaAutoExposure.ev100For([moon, lamp]), LuminaAutoExposure.ev100For([lamp]),
          reason: 'moonlight does not force a daylight exposure onto a lamp-lit level');
    });

    test('shutterSpeedFor gives the EV100 at f/16 ISO 100 (sunny 16 is 1/125 s); applyTo respects a hand-set exposure', () {
      for (final ev in [15.0, 8.8, 3.0]) {
        final t = LuminaAutoExposure.shutterSpeedFor(ev);
        expect(log2(16 * 16 / t), closeTo(ev, 1e-9));
        expect(t, lessThanOrEqualTo(60), reason: 'Filament clamps the shutter at 60 s');
      }
      expect(LuminaAutoExposure.shutterSpeedFor(LuminaAutoExposure.daylightEv100), closeTo(1 / 125, 1e-12));
      final camera = LuminaCameraComponent();
      LuminaAutoExposure.applyTo(camera, 8.0);
      expect(camera.shutterSpeed, closeTo(LuminaAutoExposure.shutterSpeedFor(8.0), 1e-12));
      expect(camera.sensitivity, 100);
      final manual = LuminaCameraComponent()
        ..autoExposure = false
        ..shutterSpeed = 1 / 30;
      LuminaAutoExposure.applyTo(manual, 8.0);
      expect(manual.shutterSpeed, 1 / 30);
    });
  });

  test('luminaLightColorFromHex decodes sRGB to linear', () {
    final c = luminaLightColorFromHex('#D22121');
    expect(c.x, closeTo(0.6445, 1e-3));
    expect(c.y, closeTo(0.0152, 1e-3));
    expect(c.z, closeTo(0.0152, 1e-3));
    expect(luminaLightColorFromHex('#FFFFFF'), Vector3(1, 1, 1));
    expect(luminaLightColorFromHex('nope'), Vector3(1, 1, 1));
    expect(luminaLightColorFromHex(null, fallback: Vector3.all(0.5)), Vector3.all(0.5));
  });

  test('a game world exposes its active camera for its lights every frame', () {
    final engine = FilamentEngine.create()!;
    addTearDown(engine.dispose);
    final scene = engine.createScene();
    final view = engine.createView();
    final native = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = native
      ..setViewport(0, 0, 640, 360);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
    addTearDown(world.cleanup);
    final camera = LuminaCameraComponent()..isActive = true;
    world.persistentLevel.registerActor(LuminaActor(root: camera));
    final lamp = LuminaPointLightComponent(intensity: 55695, location: Vector3(0, 150, 0));
    world.persistentLevel.registerActor(LuminaActor(root: lamp));
    world.beginPlay();
    world.tick(1 / 60);
    double ev() => log2(native.aperture * native.aperture / native.shutterSpeed * 100 / native.sensitivity);
    expect(ev(), closeTo(LuminaAutoExposure.ev100For([lamp]), 1e-3), reason: 'the lamp-lit level is metered');

    final sun = LuminaDirectionalLightComponent(intensity: 100000);
    final sunActor = LuminaActor(root: sun);
    world.persistentLevel.registerActor(sunActor);
    world.tick(1 / 60);
    expect(ev(), closeTo(sunny, 1e-3), reason: 'a sun brings back the daylight exposure');
    world.persistentLevel.unregisterActor(sunActor);
    world.tick(1 / 60);
    expect(ev(), closeTo(LuminaAutoExposure.ev100For([lamp]), 1e-3));
    // The EV100 3 floor reaches the Filament camera (its ISO clamp would
    // stop at ~4).
    lamp.intensity = 100;
    world.tick(1 / 60);
    expect(ev(), closeTo(LuminaAutoExposure.minEv100, 1e-3));
  });
}
