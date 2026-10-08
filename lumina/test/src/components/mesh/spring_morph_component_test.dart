import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../support/morph_glb.dart';

/// Morph targets on the animated (runtime skeletal) mesh and the spring
/// component driving them, on a real headless engine with a generated GLB
/// whose mesh has `Up` and `Down` targets.
void main() {
  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;
  late Directory dir;
  late File glb;

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
    dir = Directory.systemTemp.createTempSync('spring_morph_');
    glb = writeMorphGlb(dir, {
      'Up': [0, 1, 0],
      'Down': [0, -1, 0],
    });
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    engine.dispose();
    dir.deleteSync(recursive: true);
  });

  LuminaMorphSpring spring() => LuminaMorphSpring(
    name: 'mass',
    frequency: 3,
    damping: 0.3,
    range: 2,
    morphs: const {'+y': 'Up', '-y': 'Down'},
  );

  test('the animated mesh discovers its own instance\'s targets; two instances keep their own weights', () async {
    final a = LuminaAnimatedMeshComponent(meshAssetPath: glb.path);
    final b = LuminaAnimatedMeshComponent(meshAssetPath: glb.path);
    world.persistentLevel.registerActor(LuminaActor(root: a));
    world.persistentLevel.registerActor(LuminaActor(root: b));
    world.beginPlay();
    await a.loaded;
    await b.loaded;
    expect(a.morphTargetNames, ['Up', 'Down']);
    expect(b.morphTargetNames, ['Up', 'Down']);
    a.setMorphTarget('Up', 0.8);
    b.setMorphTarget('Down', 0.4);
    world.tick(1 / 60);
    expect(a.getMorphTarget('Up'), closeTo(0.8, 1e-6));
    expect(a.getMorphTarget('Down'), 0);
    expect(b.getMorphTarget('Up'), 0);
    expect(b.getMorphTarget('Down'), closeTo(0.4, 1e-6));
  });

  test('an actor thrown upwards lags its mass down, then it settles; amplitude 0 writes nothing', () async {
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: glb.path);
    final springs = LuminaSpringMorphComponent(springs: [spring()]);
    final actor = LuminaActor(root: mesh);
    actor.addComponent(springs);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await mesh.loaded;
    for (var i = 0; i < 3; i++) {
      world.tick(1 / 60);
    }
    expect(mesh.getMorphTarget('Down'), 0);
    // Accelerate upwards at 6 m/s² for a quarter second.
    var height = 0.0, speed = 0.0, peak = 0.0;
    for (var i = 0; i < 15; i++) {
      speed += 600 / 60;
      height += speed / 60;
      mesh.relativeLocation = Vector3(0, height, 0);
      world.tick(1 / 60);
      peak = peak > mesh.getMorphTarget('Down') ? peak : mesh.getMorphTarget('Down');
    }
    expect(peak, greaterThan(0.2), reason: 'the mass lags below while the body speeds up');
    expect(mesh.getMorphTarget('Up'), 0);
    // Coast at constant speed: the spring settles back.
    for (var i = 0; i < 240; i++) {
      height += speed / 60;
      mesh.relativeLocation = Vector3(0, height, 0);
      world.tick(1 / 60);
    }
    expect(mesh.getMorphTarget('Down'), lessThan(0.02));
    expect(mesh.getMorphTarget('Up'), lessThan(0.02));

    springs.amplitude = 0;
    for (var i = 0; i < 10; i++) {
      speed += 900 / 60;
      height += speed / 60;
      mesh.relativeLocation = Vector3(0, height, 0);
      world.tick(1 / 60);
      expect(mesh.getMorphTarget('Down'), 0);
    }
  });

  test('a teleport does not kick the springs', () async {
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: glb.path);
    final springs = LuminaSpringMorphComponent(springs: [spring()]);
    final actor = LuminaActor(root: mesh)..addComponent(springs);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await mesh.loaded;
    for (var i = 0; i < 3; i++) {
      world.tick(1 / 60);
    }
    mesh.relativeLocation = Vector3(0, 10000, 0);
    for (var i = 0; i < 5; i++) {
      world.tick(1 / 60);
      expect(mesh.getMorphTarget('Down') + mesh.getMorphTarget('Up'), lessThan(0.01));
    }
  });

  test('Blueprints know the component by its document type', () {
    expect(LuminaBlueprintComponents.classNameOf(LuminaSpringMorphComponent()), 'LuminaSpringMorphComponent');
    expect(LuminaBlueprintComponents.isA(LuminaSpringMorphComponent(), 'LuminaActorComponent'), isTrue);
  });

  test('properties round trip; unknown morph targets are skipped', () async {
    final component = LuminaSpringMorphComponent(
      springs: [
        LuminaMorphSpring(name: 'left', bone: 'spine_05', offset: Vector3(9, -4, 12), morphs: const {'+x': 'Out', '-y': 'Down'}),
      ],
      amplitude: 0.7,
      stiffnessScale: 1.4,
      dampingScale: 1.2,
    );
    final back = LuminaSpringMorphComponent.fromProperties(component.toProperties());
    expect(back.toProperties(), component.toProperties());
    expect(back.springs.single.offset, Vector3(9, -4, 12));

    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: glb.path);
    final missing = LuminaSpringMorphComponent(
      springs: [
        LuminaMorphSpring(name: 'm', morphs: const {'+y': 'NoSuchTarget', '-y': 'Down'}),
      ],
    );
    world.persistentLevel.registerActor(LuminaActor(root: mesh)..addComponent(missing));
    world.beginPlay();
    await mesh.loaded;
    for (var i = 0; i < 5; i++) {
      world.tick(1 / 60);
    }
    expect(missing.offsetOf('m'), isNotNull);
  });
}
