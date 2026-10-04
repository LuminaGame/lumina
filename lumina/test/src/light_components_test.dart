import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaLightComponent Tests (Task 01)', () {
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

    test('Registering LuminaPointLightComponent creates native point light in FilamentLightManager', () {
      final pointLight = LuminaPointLightComponent(
        intensity: 5000.0,
        falloffRadius: 8.0,
      );
      final actor = LuminaActor(root: pointLight);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      expect(pointLight.lightEntity, isNotNull);
      final entity = pointLight.lightEntity!;

      final lm = FilamentLightManager(engine);
      expect(lm.hasComponent(entity), isTrue);
      expect(lm.isPoint(entity), isTrue);
      // Filament stores lumens as candela = lumens / (4 * pi)
      // Authored lumens reach Filament ×10⁴ in the centimetre world.
      expect(lm.getIntensity(entity), closeTo(5000.0 * 1e4 / (4.0 * math.pi), 1e3));
      expect(lm.getFalloff(entity), closeTo(8.0, 1e-4));
      expect(scene.hasEntity(entity), isTrue);
    });

    test('PointLight at world location (2, 3, 4) updates position after tick', () {
      final pointLight = LuminaPointLightComponent(
        location: Vector3(2.0, 3.0, 4.0),
      );
      final actor = LuminaActor(root: pointLight);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      world.tick(1.0 / 60.0);

      final lm = FilamentLightManager(engine);
      final pos = lm.getPosition(pointLight.lightEntity!);
      expect(pos[0], closeTo(2.0, 1e-4));
      expect(pos[1], closeTo(3.0, 1e-4));
      expect(pos[2], closeTo(4.0, 1e-4));
    });

    test('LuminaDirectionalLightComponent syncs direction from its drawn rotation', () {
      // −90° about X turns the drawn −Z (0,0,-1) down to (0,-1,0). The light
      // follows the drawn rotation, not the mirrored forwardVector.
      final q = Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2.0);
      final dirLight = LuminaDirectionalLightComponent(
        rotation: q,
      );
      final actor = LuminaActor(root: dirLight);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      world.tick(1.0 / 60.0);

      final lm = FilamentLightManager(engine);
      final dir = lm.getDirection(dirLight.lightEntity!);
      expect(dir[0], closeTo(0.0, 1e-4));
      expect(dir[1], closeTo(-1.0, 1e-4));
      expect(dir[2], closeTo(0.0, 1e-4));
    });

    test('LuminaSpotLightComponent converts cone angles to radians and validates angle ranges', () {
      final spotLight = LuminaSpotLightComponent(
        innerConeAngleDegrees: 20.0,
        outerConeAngleDegrees: 40.0,
      );
      final actor = LuminaActor(root: spotLight);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final lm = FilamentLightManager(engine);
      final entity = spotLight.lightEntity!;
      expect(lm.isSpot(entity), isTrue);

      final innerExpected = 20.0 * math.pi / 180.0;
      final outerExpected = 40.0 * math.pi / 180.0;
      expect(lm.getSpotLightInnerCone(entity), closeTo(innerExpected, 1e-2));
      expect(lm.getSpotLightOuterCone(entity), closeTo(outerExpected, 1e-2));

      // Validation test: inner > outer
      expect(() => spotLight.setConeAngles(innerDegrees: 50.0, outerDegrees: 30.0), throwsArgumentError);
      // Validation test: outer > 90
      expect(() => spotLight.setConeAngles(innerDegrees: 30.0, outerDegrees: 95.0), throwsArgumentError);

      // Property accessors
      expect(spotLight.attenuationRadius, 1000.0);
      spotLight.attenuationRadius = 1500.0;
      expect(spotLight.falloffRadius, 1500.0);
      expect(spotLight.attenuationRadius, 1500.0);

      expect(spotLight.innerConeAngle, 20.0);
      expect(spotLight.outerConeAngle, 40.0);
      spotLight.innerConeAngle = 25.0;
      expect(spotLight.innerConeAngleDegrees, 25.0);
      spotLight.outerConeAngle = 55.0;
      expect(spotLight.outerConeAngleDegrees, 55.0);
    });

    test('Live property setters update FilamentLightManager', () {
      final pointLight = LuminaPointLightComponent(
        intensity: 1000.0,
        intensityInCandela: true,
      );
      final actor = LuminaActor(root: pointLight);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final lm = FilamentLightManager(engine);
      final entity = pointLight.lightEntity!;

      pointLight.color = Vector3(1.0, 0.5, 0.25);
      final c = lm.getColor(entity);
      expect(c[0], closeTo(1.0, 1e-4));
      expect(c[1], closeTo(0.5, 1e-4));
      expect(c[2], closeTo(0.25, 1e-4));

      pointLight.intensity = 25000.0;
      expect(lm.getIntensity(entity), closeTo(25000.0 * 1e4, 1e2));

      pointLight.castShadows = true;
      expect(lm.isShadowCaster(entity), isTrue);
    });

    test('Visibility toggles entity presence in FilamentScene without destroying light', () {
      final dirLight = LuminaDirectionalLightComponent();
      final actor = LuminaActor(root: dirLight);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final entity = dirLight.lightEntity!;
      final lm = FilamentLightManager(engine);
      expect(scene.hasEntity(entity), isTrue);
      expect(lm.hasComponent(entity), isTrue);

      dirLight.visible = false;
      expect(scene.hasEntity(entity), isFalse);
      expect(lm.hasComponent(entity), isTrue);

      dirLight.visible = true;
      expect(scene.hasEntity(entity), isTrue);
    });

    test('Unregistering actor destroys native light and frees component', () {
      final initialCount = FilamentLightManager(engine).componentCount;
      final pointLight = LuminaPointLightComponent();
      final actor = LuminaActor(root: pointLight);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final entity = pointLight.lightEntity!;
      final lm = FilamentLightManager(engine);
      expect(lm.hasComponent(entity), isTrue);
      expect(lm.componentCount, equals(initialCount + 1));

      world.destroyActor(actor);
      world.tick(1.0 / 60.0);

      expect(lm.hasComponent(entity), isFalse);
      expect(lm.componentCount, equals(initialCount));
    });

    test('A Blueprint point light takes the editor colour, shadows and radius and follows its actor', () {
      final actor = LuminaActor(root: LuminaSceneComponent(location: Vector3(100, 0, -200)));
      final built = LuminaBlueprintComponents.construct(actor, [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'lamp', name: 'Lamp', type: 'LuminaPointLightComponent', parentId: 'root', properties: {
          'location': [0.0, 0.0, 150.0], // authoring cm, Z up
          'intensity': 20000.0,
          'colorHex': '#FF8000',
          'attenuationRadius': 600.0,
          'castShadows': true,
        }),
      ]);
      final lamp = built['lamp'] as LuminaPointLightComponent;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      world.tick(1.0 / 60.0);

      final lm = FilamentLightManager(engine);
      final entity = lamp.lightEntity!;
      final color = lm.getColor(entity);
      // The picker's sRGB #FF8000, linear, as a level light converts it.
      expect(color[0], closeTo(1.0, 1e-4));
      expect(color[1], closeTo(luminaSrgbToLinear(128 / 255), 1e-4));
      expect(color[2], closeTo(0.0, 1e-4));
      expect(lm.isShadowCaster(entity), isTrue);
      expect(lm.getFalloff(entity), closeTo(600.0, 1e-3));
      var pos = lm.getPosition(entity);
      expect([pos[0], pos[1], pos[2]], [closeTo(100, 1e-3), closeTo(150, 1e-3), closeTo(-200, 1e-3)]);

      // The light moves with the actor.
      actor.actorLocation = Vector3(-300, 0, 50);
      world.tick(1.0 / 60.0);
      pos = lm.getPosition(entity);
      expect([pos[0], pos[1], pos[2]], [closeTo(-300, 1e-3), closeTo(150, 1e-3), closeTo(50, 1e-3)]);
    });

    test('LuminaSpotLightComponent.buildConeWireframe generates valid line segments', () {
      final spot = LuminaSpotLightComponent(
        location: Vector3(100, 200, -300),
        innerConeAngleDegrees: 25.0,
        outerConeAngleDegrees: 45.0,
        falloffRadius: 500.0,
      );

      final wire = spot.buildConeWireframe(segments: 24);
      // Line pairs: length is even
      expect(wire.length % 2, equals(0));
      expect(wire.isNotEmpty, isTrue);

      // Apex should match world location
      final apex = spot.worldLocation;
      expect(wire.any((p) => (p - apex).length < 1e-3), isTrue);

      // Outer cone ring (24 segments * 2 vertices = 48)
      // + 8 outer rays (8 * 2 = 16)
      // + inner cone ring (24 * 2 = 48)
      // + 4 inner rays (4 * 2 = 8)
      // + 1 center axis (2)
      // Total = 48 + 16 + 48 + 8 + 2 = 122 vertices
      expect(wire.length, equals(122));

      // Attenuation distance: outer ray endpoints should be at falloffRadius distance from apex
      // The 8 outer rays start at apex and end at outer cone points
      final outerEndPoints = <Vector3>[];
      for (var i = 48; i < 48 + 16; i += 2) {
        expect((wire[i] - apex).length, closeTo(0.0, 1e-3));
        outerEndPoints.add(wire[i + 1]);
      }
      expect(outerEndPoints.length, equals(8));
      for (final pt in outerEndPoints) {
        expect((pt - apex).length, closeTo(500.0, 1e-2));
      }
    });

    test('LuminaPointLightComponent.buildSphereWireframe generates 3 rings and center cross', () {
      final point = LuminaPointLightComponent(
        location: Vector3(50, 60, 70),
        falloffRadius: 400.0,
      );

      final wire = point.buildSphereWireframe(segments: 24);
      expect(wire.length % 2, equals(0));
      // 3 rings * 24 * 2 = 144
      // + 3 cross lines * 2 = 6
      // Total = 150 vertices
      expect(wire.length, equals(150));

      final center = point.worldLocation;
      // All ring vertices are at falloffRadius from center
      for (var i = 0; i < 144; i++) {
        expect((wire[i] - center).length, closeTo(400.0, 1e-2));
      }
    });

    test('LuminaDirectionalLightComponent.buildArrowWireframe generates arrow along lightDirection', () {
      final dir = LuminaDirectionalLightComponent(
        location: Vector3(10, 20, 30),
      );

      final wire = dir.buildArrowWireframe(length: 100.0);
      expect(wire.length % 2, equals(0));
      expect(wire.isNotEmpty, isTrue);

      final base = dir.worldLocation;
      // First segment is main shaft: base to base + lightDirection * 100
      expect((wire[0] - base).length, closeTo(0.0, 1e-3));
      final tip = base + dir.lightDirection * 100.0;
      expect((wire[1] - tip).length, closeTo(0.0, 1e-3));
    });
  });
}
