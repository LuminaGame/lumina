import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Filament is physically based and assumes metres; lumina feeds
/// it a centimetre world, converting only where the two meet.
void main() {
  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  test('point and spot lights: authored lumens reach Filament ×10⁴, falloff defaults to 1000 cm; a sun keeps its lux', () {
    final point = LuminaPointLightComponent(intensity: 10000);
    final spot = LuminaSpotLightComponent(intensity: 10000, location: Vector3(0, 300, 0));
    final sun = LuminaDirectionalLightComponent(intensity: 100000);
    for (final light in [point, spot, sun]) {
      world.persistentLevel.registerActor(LuminaActor(root: light));
    }
    world.beginPlay();
    final lm = FilamentLightManager(engine);
    expect(point.falloffRadius, 1000);
    expect(lm.getFalloff(point.lightEntity!), closeTo(1000, 1e-3));
    expect(lm.getIntensity(point.lightEntity!), closeTo(10000 * 1e4 / (4 * math.pi), 1));
    expect(spot.falloffRadius, 1000);
    expect(lm.getIntensity(sun.lightEntity!), closeTo(100000, 1e-3), reason: 'lux does not depend on distance');

    point.intensity = 5000;
    world.tick(1 / 60);
    expect(lm.getIntensity(point.lightEntity!), closeTo(5000 * 1e4 / (4 * math.pi), 1), reason: 'runtime changes convert too');
  });

  test('a shadow-casting sun without options gets centimetre shadow hints and contact-shadow distance', () {
    final sun = LuminaDirectionalLightComponent(intensity: 100000, castShadows: true);
    world.persistentLevel.registerActor(LuminaActor(root: sun));
    world.beginPlay();
    final options = FilamentLightManager(engine).getShadowOptions(sun.lightEntity!);
    expect(options.shadowNearHint, closeTo(100, 1e-3));
    expect(options.shadowFarHint, closeTo(10000, 1e-3));
    expect(options.maxShadowDistance, closeTo(30, 1e-3));
    expect(options.constantBias, closeTo(0.1, 1e-6));
  });

  test('shadow and post-process defaults are centimetres', () {
    final shadows = LuminaShadowSettings();
    expect(shadows.constantBias, 0.1);
    final options = shadows.toShadowOptions(cameraNear: 10, cameraFar: 100000);
    expect(options.shadowNearHint, 100);
    expect(options.shadowFarHint, 10000);
    expect(options.maxShadowDistance, 30);

    const post = LuminaPostProcessSettings();
    expect(post.ambientOcclusion.radius, 30);
    expect(post.ambientOcclusion.bilateralThreshold, 5);
    expect(post.ambientOcclusion.ssctShadowDistance, 30);
    expect(post.ambientOcclusion.ssctContactDistanceMax, 100);
    expect(post.screenSpaceReflections.thickness, 10);
    expect(post.screenSpaceReflections.bias, 1);
    expect(post.screenSpaceReflections.maxDistance, 300);
    expect(post.fog.density, closeTo(0.001, 1e-12), reason: 'per cm');
    expect(post.fog.heightFalloff, closeTo(0.01, 1e-12), reason: 'per cm');
  });

  // 86b2c12 widened the grid from Filament's 5–100 m to 10 cm – 500 m.
  test('a bound view spreads its froxel lights over 10 cm – 500 m (10–50 000 cm)', () {
    expect((LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar), (10.0, 50000.0));
    final view = engine.createView();
    addTearDown(view.dispose);
    world.bindView(view);
    expect(world.dynamicLightingRange, (10.0, 50000.0));
  });

  test('reflection captures and the staged sun cascades use centimetre near/far', () {
    final capture = LuminaReflectionCaptureComponent(captureOnRegister: false);
    expect(capture.nearClip, 10);
    expect(capture.farClip, 100000);
  });
}
