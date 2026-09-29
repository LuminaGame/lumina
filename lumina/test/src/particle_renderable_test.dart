import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The particle component used to add bare entities to the scene, so
/// a running game drew nothing. These tests assert real geometry reaches the
/// scene and that per-particle age drives colour and size.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  LuminaParticleEmitterConfig fountain({int maxParticles = 64}) => LuminaParticleEmitterConfig(
        spawnRate: 30.0,
        lifetimeMin: 1.0,
        lifetimeMax: 1.0,
        speedMin: 1.0,
        speedMax: 2.0,
        coneAngleDegrees: 30.0,
        maxParticles: maxParticles,
        gravity: Vector3(0.0, -2.0, 0.0),
        colorOverLife: [
          LuminaGradientStop(0.0, Vector4(1.0, 0.0, 0.0, 1.0)),
          LuminaGradientStop(1.0, Vector4(0.0, 0.0, 1.0, 0.0)),
        ],
        sizeOverLife: [
          LuminaCurvePoint(0.0, 1.0),
          LuminaCurvePoint(1.0, 0.1),
        ],
        looping: true,
        duration: 4.0,
      );

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
  });

  tearDown(() {
    world.cleanup();
    engine.destroyScene(scene);
    engine.dispose();
  });

  LuminaParticleSystemComponent mount() {
    final comp = LuminaParticleSystemComponent(config: fountain(), randomSeed: 7);
    final actor = LuminaActor(location: Vector3(0.0, 1.0, 0.0));
    actor.addComponent(comp);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    return comp;
  }

  test('live particles reach the scene as real geometry, not bare entities', () {
    final comp = mount();
    expect(comp.renderedParticleCount, 0, reason: 'nothing drawn before the first tick');

    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    expect(comp.liveParticleCount, greaterThan(0));
    expect(comp.renderedParticleCount, comp.liveParticleCount,
        reason: 'every live particle is drawn');
    expect(comp.hasSpriteGeometry, isTrue);
    expect(comp.spriteVertexCount, comp.liveParticleCount * 8,
        reason: 'a pair of crossed quads per particle');
  });

  test('geometry is released when the system empties and after unregister', () {
    final comp = mount();
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    expect(comp.renderedParticleCount, greaterThan(0));

    comp.deactivate();
    comp.resetSimulation();
    world.tick(1 / 60);
    expect(comp.liveParticleCount, 0);
    expect(comp.renderedParticleCount, 0);

    comp.onUnregister();
    expect(comp.hasSpriteGeometry, isFalse);
  });

  test('each particle ages on its own clock and drives its own colour and size', () {
    final comp = mount();
    for (var i = 0; i < 40; i++) {
      world.tick(1 / 60);
    }
    final live = comp.liveParticleCount;
    expect(live, greaterThan(2));

    final ages = [for (var i = 0; i < live; i++) comp.particleAgeAt(i)];
    for (final a in ages) {
      expect(a, inInclusiveRange(0.0, 1.0));
    }
    final spread = (ages.reduce((a, b) => a > b ? a : b)) - (ages.reduce((a, b) => a < b ? a : b));
    expect(spread, greaterThan(0.05), reason: 'particles spawned at different times: $ages');

    // Oldest vs youngest must not share a colour or a size, since the emitter
    // ramps red -> blue and 1.0 -> 0.1 over life.
    var oldest = 0, youngest = 0;
    for (var i = 0; i < live; i++) {
      if (ages[i] > ages[oldest]) oldest = i;
      if (ages[i] < ages[youngest]) youngest = i;
    }
    final cOld = comp.particleColorAt(oldest);
    final cYoung = comp.particleColorAt(youngest);
    expect(cOld.z, greaterThan(cYoung.z), reason: 'older particles are bluer');
    expect(comp.particleSizeAt(oldest), lessThan(comp.particleSizeAt(youngest)));
  });
}
