import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Distance-based hiding: a mesh with a Min / Max Draw Distance leaves the
/// scene while the view is nearer / farther than that, measured from the
/// active camera (or a view target) once per rendered frame, on a real
/// headless engine with a prop from `test-assets/`.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
  final prop = '$assets/Props/AC_units/ac_unit_a_300x300.glb';
  final skip = File(prop).existsSync() ? false : 'the AC unit prop is missing from test-assets';

  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  ({LuminaActor actor, LuminaCameraComponent camera}) cameraAt(Vector3 location) {
    final camera = LuminaCameraComponent(location: location)..activate();
    final actor = LuminaActor(root: camera);
    world.persistentLevel.registerActor(actor);
    return (actor: actor, camera: camera);
  }

  Future<LuminaStaticMeshComponent> placed({double min = 0, double max = 0}) async {
    final mesh = LuminaStaticMeshComponent(meshAssetPath: prop, minDrawDistance: min, maxDrawDistance: max);
    world.persistentLevel.registerActor(LuminaActor(root: mesh));
    world.beginPlay();
    await mesh.loaded;
    return mesh;
  }

  bool inScene(LuminaStaticMeshComponent mesh) => mesh.entities.every(scene.hasEntity);

  test('a mesh beyond its Max Draw Distance leaves the scene and comes back when the camera nears', () async {
    final view = cameraAt(Vector3(0, 0, 3000));
    final mesh = await placed(max: 2000);
    expect(mesh.entities, isNotEmpty);
    world.tick(1 / 60);
    expect(world.drawDistanceViewLocation, Vector3(0, 0, 3000));
    expect(mesh.isDistanceHidden, isTrue);
    expect(mesh.entities.any(scene.hasEntity), isFalse);
    expect(mesh.visible, isTrue, reason: 'visibility is the user switch, untouched');

    view.camera.relativeLocation = Vector3(0, 0, 1500);
    world.tick(1 / 60);
    expect(mesh.isDistanceHidden, isFalse);
    expect(inScene(mesh), isTrue);

    // Hidden by the user, it stays out whatever the distance.
    mesh.visible = false;
    world.tick(1 / 60);
    expect(mesh.entities.any(scene.hasEntity), isFalse);
    mesh.visible = true;
    expect(inScene(mesh), isTrue);
  }, skip: skip);

  test('a mesh nearer than its Min Draw Distance is hidden; no limits and no camera hide nothing', () async {
    final view = cameraAt(Vector3(0, 0, 200));
    final near = await placed(min: 500);
    final free = await placed();
    world.tick(1 / 60);
    expect(near.isDistanceHidden, isTrue);
    expect(inScene(free), isTrue);
    view.camera.relativeLocation = Vector3(0, 0, 800);
    world.tick(1 / 60);
    expect(inScene(near), isTrue);

    view.camera.deactivate();
    world.tick(1 / 60);
    expect(world.drawDistanceViewLocation, isNull);
    expect(inScene(near), isTrue, reason: 'with nothing to measure from, every mesh is drawn');
  }, skip: skip);

  test("a view target's point of view is what the distance is measured from", () async {
    cameraAt(Vector3(0, 0, 100));
    final mesh = await placed(max: 1000);
    world.viewTargetPov = LuminaMinimalViewInfo()..location = Vector3(0, 0, 5000);
    world.tick(1 / 60);
    expect(mesh.isDistanceHidden, isTrue);
    world.viewTargetPov = null;
    world.tick(1 / 60);
    expect(mesh.isDistanceHidden, isFalse);
  }, skip: skip);

  test('Details distances are metres, the runtime takes cm, and apply sets every mesh of an actor', () {
    expect(LuminaDrawDistance.fromDetails({'minDrawDistance': 0.0, 'maxDrawDistance': 0.0}), isNull);
    expect(LuminaDrawDistance.fromDetails({'maxDrawDistance': 200.0}), (min: 0.0, max: 20000.0));
    expect(LuminaDrawDistance.fromDetails({'minDrawDistance': 5, 'maxDrawDistance': -1}), (min: 500.0, max: 0.0));
    expect(LuminaDrawDistance.within(100, 0, 0), isTrue);
    expect(LuminaDrawDistance.within(100, 150, 0), isFalse);
    expect(LuminaDrawDistance.within(100, 0, 99), isFalse);
    final a = LuminaStaticMeshComponent(meshAssetPath: prop), b = LuminaStaticMeshComponent(meshAssetPath: prop);
    final actor = LuminaActor(root: a)..addComponent(b);
    expect(LuminaDrawDistance.apply(actor, min: 10, max: 20), same(actor));
    expect([a.minDrawDistance, a.maxDrawDistance, b.minDrawDistance, b.maxDrawDistance], [10, 20, 10, 20]);
  });
}
