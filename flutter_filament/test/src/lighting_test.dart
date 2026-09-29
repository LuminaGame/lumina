import 'dart:ffi' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Lighting API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('LightType enum indices', () {
      expect(LightType.sun.index, equals(0));
      expect(LightType.directional.index, equals(1));
      expect(LightType.point.index, equals(2));
      expect(LightType.focusedSpot.index, equals(3));
      expect(LightType.spot.index, equals(4));
    });

    test('FilamentLightManager createLight and destroy', () {
      final lightManager = FilamentLightManager(engine);
      final entity = engine.createEntity();

      expect(
        () => lightManager.createLight(
          entity: entity,
          type: LightType.sun,
          colorR: 1.0,
          colorG: 0.9,
          colorB: 0.8,
          intensity: 100000,
          dirX: 0,
          dirY: -1,
          dirZ: 0,
          castShadows: true,
        ),
        returnsNormally,
      );

      expect(() => lightManager.destroy(entity), returnsNormally);
      engine.destroyEntity(entity);
    });

    test('FilamentSkybox creation and dispose', () {
      final skybox = FilamentSkybox.createColor(
        engine: engine,
        r: 0.2,
        g: 0.3,
        b: 0.4,
        a: 1.0,
      );

      expect(skybox.isDisposed, isFalse);
      expect(skybox.nativePointer, isNotNull);

      skybox.dispose();
      expect(skybox.isDisposed, isTrue);
      expect(() => skybox.nativePointer, throwsStateError);
    });

    test('LightBuilder point light with color, intensity, position, falloff', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.point)
        ..color(1.0, 0.5, 0.25)
        ..intensity(10000.0)
        ..position(1.0, 2.0, 3.0)
        ..falloff(5.0)
        ..build(engine, entity);

      expect(lightManager.hasComponent(entity), isTrue);
      final instance = lightManager.getInstance(entity);
      expect(instance.isValid, isTrue);

      lightManager.destroy(entity);
      expect(lightManager.hasComponent(entity), isFalse);
      engine.destroyEntity(entity);
    });

    test('LightBuilder spot light with spotLightCone and direction', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.spot)
        ..spotLightCone(0.1, 0.5)
        ..direction(0.0, -1.0, 0.0)
        ..build(engine, entity);

      expect(lightManager.hasComponent(entity), isTrue);
      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightBuilder sun light with angular radius, halo, and cast shadows', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.sun)
        ..sunAngularRadius(1.9)
        ..sunHaloSize(10.0)
        ..sunHaloFalloff(80.0)
        ..castShadows(true)
        ..build(engine, entity);

      expect(lightManager.hasComponent(entity), isTrue);
      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightBuilder intensityCandela and intensityWatts forms', () {
      final entity1 = engine.createEntity();
      final entity2 = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.point)
        ..intensityCandela(500.0)
        ..build(engine, entity1);
      expect(lightManager.hasComponent(entity1), isTrue);

      LightBuilder(LightType.point)
        ..intensityWatts(15.0, 0.0092) // 15W halogen
        ..build(engine, entity2);
      expect(lightManager.hasComponent(entity2), isTrue);

      lightManager.destroy(entity1);
      lightManager.destroy(entity2);
      engine.destroyEntity(entity1);
      engine.destroyEntity(entity2);
    });

    test('LightBuilder lightChannel and castLight options', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.directional)
        ..lightChannel(3, enable: true)
        ..castLight(false)
        ..build(engine, entity);

      expect(lightManager.hasComponent(entity), isTrue);
      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('Building twice onto the same entity replaces component safely', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.point)
        ..intensity(100.0)
        ..build(engine, entity);
      expect(lightManager.hasComponent(entity), isTrue);

      // Rebuilding onto same entity
      LightBuilder(LightType.sun)
        ..intensity(50000.0)
        ..build(engine, entity);
      expect(lightManager.hasComponent(entity), isTrue);

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightManager runtime setters and getters (color, position, falloff, direction)', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.point)
        ..position(0, 0, 0)
        ..color(1, 1, 1)
        ..intensity(1000)
        ..falloff(1.0)
        ..build(engine, entity);

      // Color round-trip
      lightManager.setColor(entity, 0.2, 0.4, 0.8);
      final color = lightManager.getColor(entity);
      expect(color[0], closeTo(0.2, 1e-4));
      expect(color[1], closeTo(0.4, 1e-4));
      expect(color[2], closeTo(0.8, 1e-4));

      // Position round-trip
      lightManager.setPosition(entity, 10.0, 20.0, 30.0);
      final pos = lightManager.getPosition(entity);
      expect(pos[0], closeTo(10.0, 1e-4));
      expect(pos[1], closeTo(20.0, 1e-4));
      expect(pos[2], closeTo(30.0, 1e-4));

      // Falloff round-trip
      lightManager.setFalloff(entity, 7.5);
      expect(lightManager.getFalloff(entity), closeTo(7.5, 1e-4));

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightManager runtime direction on directional light', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.directional)
        ..direction(0, -1, 0)
        ..build(engine, entity);

      lightManager.setDirection(entity, 0.0, 0.0, -1.0);
      final dir = lightManager.getDirection(entity);
      expect(dir[0], closeTo(0.0, 1e-4));
      expect(dir[1], closeTo(0.0, 1e-4));
      expect(dir[2], closeTo(-1.0, 1e-4));

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightManager runtime spot cone angles and shadow caster', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.spot)
        ..spotLightCone(0.1, 0.5)
        ..castShadows(false)
        ..build(engine, entity);

      expect(lightManager.isShadowCaster(entity), isFalse);
      lightManager.setShadowCaster(entity, true);
      expect(lightManager.isShadowCaster(entity), isTrue);
      lightManager.setShadowCaster(entity, false);
      expect(lightManager.isShadowCaster(entity), isFalse);

      lightManager.setSpotLightCone(entity, 0.2, 0.6);
      expect(lightManager.getSpotLightInnerCone(entity), closeTo(0.2, 0.02));
      expect(lightManager.getSpotLightOuterCone(entity), closeTo(0.6, 0.02));

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightManager lightChannel toggle and query', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.point).build(engine, entity);

      expect(lightManager.getLightChannel(entity, 0), isTrue);
      expect(lightManager.getLightChannel(entity, 5), isFalse);

      lightManager.setLightChannel(entity, 5, enable: true);
      expect(lightManager.getLightChannel(entity, 5), isTrue);
      expect(lightManager.getLightChannel(entity, 0), isTrue);

      lightManager.setLightChannel(entity, 0, enable: false);
      expect(lightManager.getLightChannel(entity, 0), isFalse);

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightEfficiency constants match Filament spec', () {
      expect(LightEfficiency.incandescent, equals(0.0220));
      expect(LightEfficiency.halogen, equals(0.0707));
      expect(LightEfficiency.fluorescent, equals(0.0878));
      expect(LightEfficiency.led, equals(0.1171));
    });

    test('FilamentShadowOptions struct size and ABI layout fidelity', () {
      final dartSize = ffi.sizeOf<c.FilamentShadowOptions>();
      final cSize = c.filament_sizeof_shadow_options();
      expect(dartSize, equals(cSize));
    });

    test('ShadowCascades split calculation utilities', () {
      // Cascades = 1 returns empty list
      expect(ShadowCascades.computeUniformSplits(1), isEmpty);
      expect(ShadowCascades.computeLogSplits(1, nearPlane: 0.1, farPlane: 100.0), isEmpty);
      expect(ShadowCascades.computePracticalSplits(1, nearPlane: 0.1, farPlane: 100.0), isEmpty);

      // Cascades = 2 returns 1 split at 0.5
      final uniform2 = ShadowCascades.computeUniformSplits(2);
      expect(uniform2.length, equals(1));
      expect(uniform2[0], closeTo(0.5, 1e-4));

      // Practical splits with 4 cascades returns 3 strictly increasing splits
      final practical4 = ShadowCascades.computePracticalSplits(
        4,
        nearPlane: 0.1,
        farPlane: 100.0,
        lambda: 0.5,
      );
      expect(practical4.length, equals(3));
      expect(practical4[0], greaterThan(0.0));
      expect(practical4[1], greaterThan(practical4[0]));
      expect(practical4[2], greaterThan(practical4[1]));
      expect(practical4[2], lessThan(1.0));
    });

    test('ShadowOptions round-trip (mapSize, cascades, biases, vsm, contact shadows)', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      LightBuilder(LightType.sun)
        ..castShadows(true)
        ..build(engine, entity);

      final initialOptions = ShadowOptions(
        mapSize: 2048,
        shadowCascades: 4,
        cascadeSplitPositions: [0.1, 0.3, 0.6],
        constantBias: 0.005,
        normalBias: 2.0,
        stable: true,
        lispsm: false,
        screenSpaceContactShadows: true,
        stepCount: 16,
        maxShadowDistance: 0.5,
        elvsm: true,
        blurWidth: 3.0,
      );

      lightManager.setShadowOptions(entity, initialOptions);

      final readback = lightManager.getShadowOptions(entity);
      expect(readback.mapSize, equals(2048));
      expect(readback.shadowCascades, equals(4));
      expect(readback.cascadeSplitPositions[0], closeTo(0.1, 1e-4));
      expect(readback.cascadeSplitPositions[1], closeTo(0.3, 1e-4));
      expect(readback.cascadeSplitPositions[2], closeTo(0.6, 1e-4));
      expect(readback.constantBias, closeTo(0.005, 1e-4));
      expect(readback.normalBias, closeTo(2.0, 1e-4));
      expect(readback.stable, isTrue);
      expect(readback.lispsm, isFalse);
      expect(readback.screenSpaceContactShadows, isTrue);
      expect(readback.stepCount, equals(16));
      expect(readback.maxShadowDistance, closeTo(0.5, 1e-4));
      expect(readback.elvsm, isTrue);
      expect(readback.blurWidth, closeTo(3.0, 1e-4));

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightBuilder with shadowOptions builds with configured parameters', () {
      final entity = engine.createEntity();
      final lightManager = FilamentLightManager(engine);

      final customOptions = ShadowOptions(
        mapSize: 512,
        shadowCascades: 2,
        constantBias: 0.002,
        normalBias: 1.5,
      );

      LightBuilder(LightType.directional)
        ..castShadows(true)
        ..shadowOptions(customOptions)
        ..build(engine, entity);

      final readback = lightManager.getShadowOptions(entity);
      expect(readback.mapSize, equals(512));
      expect(readback.shadowCascades, equals(2));
      expect(readback.constantBias, closeTo(0.002, 1e-4));
      expect(readback.normalBias, closeTo(1.5, 1e-4));

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('LightManager component queries (hasComponent, getType, classification helpers)', () {
      final lightManager = FilamentLightManager(engine);
      final entity = engine.createEntity();

      // Fresh entity
      expect(lightManager.hasComponent(entity), isFalse);
      expect(lightManager.getType(entity), isNull);
      expect(lightManager.isDirectional(entity), isFalse);
      expect(lightManager.isPoint(entity), isFalse);
      expect(lightManager.isSpot(entity), isFalse);

      // Spot light
      LightBuilder(LightType.spot).build(engine, entity);
      expect(lightManager.hasComponent(entity), isTrue);
      expect(lightManager.getType(entity), equals(LightType.spot));
      expect(lightManager.isSpot(entity), isTrue);
      expect(lightManager.isPoint(entity), isFalse);
      expect(lightManager.isDirectional(entity), isFalse);

      // Focused spot light
      LightBuilder(LightType.focusedSpot).build(engine, entity);
      expect(lightManager.getType(entity), equals(LightType.focusedSpot));
      expect(lightManager.isSpot(entity), isTrue);

      // Sun light (counts as directional in Filament semantics)
      LightBuilder(LightType.sun).build(engine, entity);
      expect(lightManager.getType(entity), equals(LightType.sun));
      expect(lightManager.isDirectional(entity), isTrue);
      expect(lightManager.isSpot(entity), isFalse);

      // Point light
      LightBuilder(LightType.point).build(engine, entity);
      expect(lightManager.getType(entity), equals(LightType.point));
      expect(lightManager.isPoint(entity), isTrue);

      lightManager.destroy(entity);
      expect(lightManager.hasComponent(entity), isFalse);
      engine.destroyEntity(entity);
    });

    test('LightManager componentCount and entities query array', () {
      final lightManager = FilamentLightManager(engine);
      final initialCount = lightManager.componentCount;

      final e1 = engine.createEntity();
      final e2 = engine.createEntity();
      final e3 = engine.createEntity();

      LightBuilder(LightType.point).build(engine, e1);
      LightBuilder(LightType.spot).build(engine, e2);
      LightBuilder(LightType.sun).build(engine, e3);

      expect(lightManager.componentCount, equals(initialCount + 3));
      final allLights = lightManager.entities;
      expect(allLights, contains(e1));
      expect(allLights, contains(e2));
      expect(allLights, contains(e3));

      lightManager.destroy(e2);
      expect(lightManager.componentCount, equals(initialCount + 2));
      expect(lightManager.hasComponent(e2), isFalse);

      lightManager.destroy(e1);
      lightManager.destroy(e3);
      engine.destroyEntity(e1);
      engine.destroyEntity(e2);
      engine.destroyEntity(e3);
    });
  });
}
