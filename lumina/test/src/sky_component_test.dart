import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaSkyComponent Tests (Task 01)', () {
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

    test('Registering LuminaSkyComponent.color sets skybox and indirect light on scene', () {
      final sky = LuminaSkyComponent.color(
        color: Vector4(1.0, 0.0, 0.0, 1.0),
        skyIntensity: 20000.0,
        iblIntensity: 20000.0,
      );
      final actor = LuminaActor(root: sky);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      expect(scene.skybox, isNotNull);
      expect(scene.skybox!.intensity, closeTo(20000.0, 1e-2));
      expect(scene.indirectLight, isNotNull);
      expect(scene.indirectLight!.intensity, closeTo(20000.0, 1e-2));
    });

    test('rotationDegrees updates IndirectLight rotation matrix during render prep', () {
      final sky = LuminaSkyComponent.color(
        color: Vector4(0.2, 0.4, 0.8, 1.0),
      );
      final actor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      sky.rotationDegrees = 90.0;
      world.tick(1.0 / 60.0);

      final rot = scene.indirectLight!.rotation;
      final expected = Matrix3.rotationY(math.pi / 2.0);
      for (int i = 0; i < 9; i++) {
        expect(rot.storage[i], closeTo(expected.storage[i], 1e-4));
      }
    });

    test('Live iblIntensity setter writes through to IndirectLight', () {
      final sky = LuminaSkyComponent.color(
        color: Vector4(0.1, 0.1, 0.1, 1.0),
        iblIntensity: 30000.0,
      );
      final actor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      sky.iblIntensity = 45000.0;
      expect(scene.indirectLight!.intensity, closeTo(45000.0, 1e-2));
    });

    test('Visibility toggles skybox on scene while indirect light stays active', () {
      final sky = LuminaSkyComponent.color(
        color: Vector4(0.5, 0.5, 0.5, 1.0),
      );
      final actor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      expect(scene.skybox, isNotNull);
      expect(scene.indirectLight, isNotNull);

      sky.visible = false;
      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNotNull);

      sky.visible = true;
      expect(scene.skybox, isNotNull);
      expect(scene.indirectLight, isNotNull);
    });

    test('Registering second LuminaSkyComponent in same world throws StateError', () {
      final sky1 = LuminaSkyComponent.color(color: Vector4(1, 1, 1, 1));
      final actor1 = LuminaActor(root: sky1);
      world.persistentLevel.registerActor(actor1);
      world.beginPlay();

      final sky2 = LuminaSkyComponent.color(color: Vector4(0, 0, 0, 1));
      final actor2 = LuminaActor(root: sky2);
      expect(() => world.persistentLevel.registerActor(actor2), throwsStateError);
    });

    test('deriveSunLight with 3-band SH returns unit-length direction and scaled intensity', () {
      // 3 bands = 9 RGB = 27 floats
      final shCoeffs = List<double>.filled(27, 0.0);
      // L0,0 ambient
      shCoeffs[0] = 1.0;
      shCoeffs[1] = 1.0;
      shCoeffs[2] = 1.0;
      // L1,+1 (dominant Z light)
      shCoeffs[3] = 0.0;
      shCoeffs[4] = 0.0;
      shCoeffs[5] = 2.0;

      final ambientSh = SphericalHarmonics(bands: 3, coefficients: shCoeffs);
      final sky = LuminaSkyComponent.color(
        color: Vector4(0.5, 0.5, 0.5, 1.0),
        ambientSh: ambientSh,
        iblIntensity: 40000.0,
      );
      final actor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      final sunData = sky.deriveSunLight();
      expect(sunData.direction.length, closeTo(1.0, 1e-3));
      expect(sunData.intensity, greaterThan(0.0));
    });

    test('Unregistering sky actor clears skybox and indirect light from scene', () {
      final sky = LuminaSkyComponent.color(color: Vector4(0.3, 0.3, 0.3, 1.0));
      final actor = LuminaActor(root: sky);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      expect(scene.skybox, isNotNull);
      expect(scene.indirectLight, isNotNull);

      world.destroyActor(actor);
      world.tick(1.0 / 60.0);

      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNull);
    });
  });
}
