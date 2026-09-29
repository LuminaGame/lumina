import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The shader ships inside the package; tests read it straight off disk so
/// they do not depend on an asset bundle.
Future<Uint8List> _diskAssets(String key) async {
  final name = key.split('/').last;
  return File('assets/sky/$name').readAsBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LuminaProceduralSkyComponent parameters', () {
    test('defaults describe a clear midday sky with an animated ocean', () {
      final sky = LuminaProceduralSkyComponent();
      expect(sky.timeOfDay, 12.0);
      expect(sky.isNight, isFalse);
      expect(sky.cloudCoverage, greaterThan(0.0));
      expect(sky.waterStrength, greaterThan(0.0));
      expect(sky.dayCycleSpeed, 0.0, reason: 'the sky is static until a level asks for a cycle');
      expect(sky.visible, isTrue);
    });

    test('sun direction tracks the time of day and is a unit vector', () {
      double len(List<double> v) =>
          (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

      final noon = LuminaProceduralSkyComponent(timeOfDay: 12.0);
      expect(len(noon.sunDirection), closeTo(1.0, 1e-9));
      expect(noon.sunDirection[1], greaterThan(0.9), reason: 'the noon sun is near the zenith');
      expect(noon.isNight, isFalse);

      final dawn = LuminaProceduralSkyComponent(timeOfDay: 6.0);
      expect(dawn.sunDirection[1], closeTo(0.0, 1e-6));

      final midnight = LuminaProceduralSkyComponent(timeOfDay: 0.0);
      expect(midnight.isNight, isTrue);
      expect(midnight.sunDirection[1], lessThan(0.0));
      expect(len(midnight.sunDirection), closeTo(1.0, 1e-9));
    });

    test('onTick advances the day cycle and wraps at 24h', () {
      final sky = LuminaProceduralSkyComponent(timeOfDay: 23.5, dayCycleSpeed: 1.0);
      sky.onTick(1.0);
      expect(sky.timeOfDay, closeTo(0.5, 1e-9));

      final frozen = LuminaProceduralSkyComponent(timeOfDay: 9.0);
      frozen.onTick(10.0);
      expect(frozen.timeOfDay, 9.0, reason: 'dayCycleSpeed 0 freezes the sky');
    });

    test('updateUniforms is a no-op before the material exists', () {
      expect(() => LuminaProceduralSkyComponent().updateUniforms(), returnsNormally);
    });
  });

  group('LuminaProceduralSkyComponent on a real engine', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('registering the actor compiles the shader and puts the sky in the scene', () async {
      final sky = LuminaProceduralSkyComponent(
        timeOfDay: 15.0,
        cloudCoverage: 0.6,
        waterStrength: 45.0,
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      world.persistentLevel.registerActor(LuminaActor(root: sky));
      world.beginPlay();
      await sky.loaded;

      expect(sky.isLoaded, isTrue);
      expect(sky.skyEntity, isNotNull);
      expect(scene.entityCount, greaterThan(0));

      // Hiding and showing the sky is a scene membership change, not a rebuild.
      final entity = sky.skyEntity;
      sky.visible = false;
      expect(sky.skyEntity, entity);
      sky.visible = true;
      expect(sky.skyEntity, entity);

      // Per-frame uniform upload must survive a full tick.
      for (var i = 0; i < 3; i++) {
        world.tick(1 / 60);
      }
      expect(sky.isLoaded, isTrue);
    });

    test('a day cycle drives the sky from day into night', () async {
      final sky = LuminaProceduralSkyComponent(
        timeOfDay: 12.0,
        dayCycleSpeed: 1.0, // one simulated hour of sky per real second
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      world.persistentLevel.registerActor(LuminaActor(root: sky));
      world.beginPlay();
      await sky.loaded;

      expect(sky.isNight, isFalse);
      // 9 simulated hours: past sunset.
      for (var i = 0; i < 9; i++) {
        world.tick(1.0);
      }
      expect(sky.timeOfDay, closeTo(21.0, 1e-6));
      expect(sky.isNight, isTrue);
    });
  });

  group('A procedural sky and a LuminaSkyComponent in one world', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('the procedural sky takes the static skybox off the scene and keeps the ambient light', () async {
      // Filament paints a Skybox into every pixel nothing wrote depth to, and
      // the procedural sky is a depthWrite:false renderable — leaving both on
      // means the static skybox covers the procedural one completely.
      final ambience = LuminaSkyComponent.color(
        color: Vector4(0.2, 0.4, 0.8, 1.0),
        skyIntensity: 30000.0,
        iblIntensity: 30000.0,
      );
      world.persistentLevel.registerActor(LuminaActor(root: ambience));

      final sky = LuminaProceduralSkyComponent(
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      world.persistentLevel.registerActor(LuminaActor(root: sky));
      world.beginPlay();
      await sky.loaded;

      expect(scene.skybox, isNotNull, reason: 'the sky component bound one on register');
      world.tick(1 / 60);
      expect(scene.skybox, isNull, reason: 'the procedural sky is the visible background now');
      expect(scene.indirectLight, isNotNull,
          reason: 'the ambient light the procedural sky cannot provide must be untouched');

      // Hiding the procedural sky gives the static skybox straight back.
      sky.visible = false;
      world.tick(1 / 60);
      expect(scene.skybox, isNotNull);
      sky.visible = true;
      world.tick(1 / 60);
      expect(scene.skybox, isNull);
    });

    test('unregistering the procedural sky restores the skybox it hid', () async {
      final ambience = LuminaSkyComponent.color(color: Vector4(0.2, 0.4, 0.8, 1.0));
      world.persistentLevel.registerActor(LuminaActor(root: ambience));
      final skyActor = LuminaActor(
        root: LuminaProceduralSkyComponent(
          assetProvider: _diskAssets,
          loadNightSkyTextures: false,
        ),
      );
      world.persistentLevel.registerActor(skyActor);
      world.beginPlay();
      await (skyActor.rootComponent as LuminaProceduralSkyComponent).loaded;
      world.tick(1 / 60);
      expect(scene.skybox, isNull);

      world.persistentLevel.unregisterActor(skyActor);
      expect(scene.skybox, isNotNull, reason: 'the level keeps its authored sky');
    });
  });

  group('Procedural sky code generation', () {
    test('a ProceduralSky actor round-trips through metadata.actors into Dart', () {
      final gen = DartCodeGeneratorService();
      final dart = gen.generateLevelDart(
        levelName: 'L_Ocean',
        actors: const [],
        actorMaps: [
          {
            'id': 'act_proc_sky',
            'name': 'ProceduralSky_Ocean',
            'type': 'ProceduralSky',
            'location': [0.0, 0.0, 0.0],
            'isVisible': true,
            'components': [
              {
                'id': 'act_proc_sky_c',
                'type': 'LuminaProceduralSkyComponent',
                'name': 'Procedural Sky',
                'properties': {
                  'timeOfDay': 17.5,
                  'turbidity': 4.0,
                  'cloudCoverage': 0.72,
                  'waterStrength': 55.0,
                  'dayCycleSpeed': 0.25,
                },
              },
            ],
          },
        ],
      );

      expect(dart, contains('LuminaProceduralSkyComponent('));
      expect(dart, contains('timeOfDay: 17.5'));
      expect(dart, contains('turbidity: 4.0'));
      expect(dart, contains('cloudCoverage: 0.72'));
      expect(dart, contains('waterStrength: 55.0'));
      expect(dart, contains('dayCycleSpeed: 0.25'));
      expect(dart, contains('visible: true'));
    });

    test('a ProceduralSky actor with no component falls back to the defaults', () {
      final gen = DartCodeGeneratorService();
      final dart = gen.generateLevelDart(
        levelName: 'L_Ocean',
        actors: const [],
        actorMaps: [
          {
            'id': 'act_proc_sky',
            'name': 'ProceduralSky',
            'type': 'ProceduralSky',
            'location': [0.0, 0.0, 0.0],
            'isVisible': true,
          },
        ],
      );
      expect(dart, contains('timeOfDay: 12.0'));
      expect(dart, contains('cloudCoverage: 0.4'));
    });
  });

  group('LuminaProceduralSkyDescription', () {
    test('fromProperties reads the property map the editor writes', () {
      final d = LuminaProceduralSkyDescription.fromProperties(const {
        'timeOfDay': 18.25,
        'turbidity': 6.0,
        'rayleigh': 2.5,
        'mieCoefficient': 1.5,
        'mieG': 0.7,
        'cloudCoverage': 0.9,
        'cloudDensity': 0.3,
        'waterStrength': 66.0,
        'waterSpeed': 2.0,
        'dayCycleSpeed': 0.5,
        'visible': false,
      });
      expect(d.timeOfDay, 18.25);
      expect(d.turbidity, 6.0);
      expect(d.cloudCoverage, 0.9);
      expect(d.waterStrength, 66.0);
      expect(d.dayCycleSpeed, 0.5);
      expect(d.visible, isFalse);
    });

    test('empty, null and malformed maps fall back to the defaults', () {
      expect(LuminaProceduralSkyDescription.fromProperties(null),
          LuminaProceduralSkyDescription.defaults);
      expect(LuminaProceduralSkyDescription.fromProperties(const {}),
          LuminaProceduralSkyDescription.defaults);
      final partial = LuminaProceduralSkyDescription.fromProperties(const {
        'timeOfDay': 'noon',
        'cloudCoverage': double.nan,
        'waterStrength': 12.0,
      });
      expect(partial.timeOfDay, LuminaProceduralSkyDescription.defaults.timeOfDay);
      expect(partial.cloudCoverage, LuminaProceduralSkyDescription.defaults.cloudCoverage);
      expect(partial.waterStrength, 12.0);
    });

    test('toProperties round-trips through fromProperties', () {
      const d = LuminaProceduralSkyDescription(
        timeOfDay: 7.5,
        cloudCoverage: 0.8,
        dayCycleSpeed: 1.5,
        visible: false,
      );
      expect(LuminaProceduralSkyDescription.fromProperties(d.toProperties()), d);
    });

    test('advancedTimeOfDay wraps and respects a frozen cycle', () {
      const cycling = LuminaProceduralSkyDescription(timeOfDay: 23.5, dayCycleSpeed: 1.0);
      expect(cycling.advancedTimeOfDay(1.0), closeTo(0.5, 1e-9));
      const frozen = LuminaProceduralSkyDescription(timeOfDay: 9.0);
      expect(frozen.advancedTimeOfDay(10.0), 9.0);
      // A cycle speed that is a multiple of 24 returns to the same hour.
      const aliased = LuminaProceduralSkyDescription(timeOfDay: 12.0, dayCycleSpeed: 24.0);
      expect(aliased.advancedTimeOfDay(1.0), 12.0);
    });

    test('equality and copyWith round-trip', () {
      const a = LuminaProceduralSkyDescription.defaults;
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
      expect(a.copyWith(cloudCoverage: 0.99) == a, isFalse);
    });
  });

  group('LuminaProceduralSkyBinding on a real engine', () {
    late FilamentEngine engine;
    late FilamentScene scene;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
    });

    tearDown(() {
      scene.dispose();
      engine.dispose();
    });

    test('loads the sky into a world-free scene and retunes without rebuilding', () async {
      final binding = LuminaProceduralSkyBinding(
        engine: engine,
        scene: scene,
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      addTearDown(binding.dispose);

      expect(scene.entityCount, 0);
      await binding.load(const LuminaProceduralSkyDescription(timeOfDay: 14.0));
      expect(binding.isLoaded, isTrue);
      final entity = binding.skyEntity;
      expect(entity, isNotNull);
      expect(scene.entityCount, 1);

      // Retuning is a uniform upload, never a rebuild.
      binding.apply(binding.description.copyWith(cloudCoverage: 0.95, waterStrength: 80.0));
      expect(binding.skyEntity, entity);
      expect(scene.entityCount, 1);

      // Visibility is a scene-membership change, also not a rebuild.
      binding.apply(binding.description.copyWith(visible: false));
      expect(scene.entityCount, 0);
      expect(binding.skyEntity, entity);
      binding.apply(binding.description.copyWith(visible: true));
      expect(scene.entityCount, 1);
    });

    test('advance() drives the day cycle and reports the new hour', () async {
      final binding = LuminaProceduralSkyBinding(
        engine: engine,
        scene: scene,
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      addTearDown(binding.dispose);
      await binding.load(const LuminaProceduralSkyDescription(timeOfDay: 12.0, dayCycleSpeed: 3.0));

      expect(binding.advance(1.0), closeTo(15.0, 1e-9));
      expect(binding.description.timeOfDay, closeTo(15.0, 1e-9));
      // A frozen cycle never moves, however long the frame was.
      binding.apply(binding.description.copyWith(dayCycleSpeed: 0.0));
      expect(binding.advance(100.0), closeTo(15.0, 1e-9));
    });

    test('dispose removes the sky and frees the scene', () async {
      final binding = LuminaProceduralSkyBinding(
        engine: engine,
        scene: scene,
        assetProvider: _diskAssets,
        loadNightSkyTextures: false,
      );
      await binding.load(LuminaProceduralSkyDescription.defaults);
      expect(scene.entityCount, 1);
      binding.dispose();
      expect(scene.entityCount, 0);
      expect(binding.skyEntity, isNull);
      expect(binding.isLoaded, isFalse);
      // Disposing twice is safe.
      expect(binding.dispose, returnsNormally);
    });
  });
}
