import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Post Process Volume component registers its shape
/// with the world's blender, follows the actor, and blends the bound view by
/// the active camera's position.
void main() {
  test('registering adds one volume with the world transform; moving updates it; unregister removes it', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    final c = LuminaPostProcessVolumeComponent(
      location: Vector3(100.0, 0, 0),
      extent: Vector3.all(50.0),
      priority: 3.0,
      overrides: const LuminaPostProcessOverrides(bloomIntensity: 2.0),
    );
    final actor = LuminaActor(root: c);
    world.persistentLevel.registerActor(actor);
    expect(world.postProcessBlender.volumes, hasLength(1));
    final v = world.postProcessBlender.volumes.single;
    expect(identical(v, c.volume), isTrue);
    expect(v.priority, 3.0);
    expect(v.containsPoint(Vector3(120.0, 0, 0)), isTrue);
    expect(v.containsPoint(Vector3(0, 0, 0)), isFalse);

    world.beginPlay();
    actor.actorLocation = Vector3(-100.0, 0, 0);
    world.tick(1 / 60);
    expect(v.containsPoint(Vector3(-120.0, 0, 0)), isTrue);
    expect(v.containsPoint(Vector3(120.0, 0, 0)), isFalse);

    world.persistentLevel.unregisterActor(actor);
    expect(world.postProcessBlender.volumes, isEmpty);
  });

  test('fromProperties maps the authored Z-up extent to runtime axes and reads the override block', () {
    final c = LuminaPostProcessVolumeComponent.fromProperties(const {
      'extentX': 100.0,
      'extentY': 200.0,
      'extentZ': 300.0,
      'unbound': false,
      'priority': 5.0,
      'blendRadius': 40.0,
      'blendWeight': 0.5,
      'overrideBloomIntensity': true,
      'bloomIntensity': 6.0,
      'overrideExposure': false,
      'exposure': 3.0,
    });
    expect(c.extent, Vector3(100.0, 300.0, 200.0));
    expect(c.priority, 5.0);
    expect(c.blendRadius, 40.0);
    expect(c.blendWeight, 0.5);
    expect(c.overrides.bloomIntensity, 6.0);
    expect(c.overrides.exposure, isNull);
  });

  test('a camera actor inside a bloom volume blends the bound view; leaving it restores the baseline', () {
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
    final baseline = LuminaPostProcessSettings.standard().copyWith(bloom: const BloomOptions(enabled: true, strength: 0.1));
    world.postProcess.apply(baseline);
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaPostProcessVolumeComponent(
        extent: Vector3.all(200.0),
        blendRadius: 0.0,
        overrides: const LuminaPostProcessOverrides(bloomIntensity: 6.0),
      ),
    ));
    final camera = LuminaCameraComponent(location: Vector3(0, 50.0, 0))..isActive = true;
    final cameraActor = LuminaActor(root: camera);
    world.persistentLevel.registerActor(cameraActor);
    world.beginPlay();
    world.tick(1 / 60);
    expect(world.postProcess.applied.bloom.strength, closeTo(0.75, 1e-9));
    expect(world.postProcess.baseline.bloom.strength, closeTo(0.1, 1e-9));
    cameraActor.actorLocation = Vector3(0, 0, 1000.0);
    world.tick(1 / 60);
    expect(world.postProcess.applied.bloom.strength, closeTo(0.1, 1e-9));
  });
}
