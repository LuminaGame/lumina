import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../support/viewport_project.dart';

/// The Viewport's preview scene on a real (headless) engine, with real
/// `.lmas` meshes of a temp project built from `test-assets/`.
void main() {
  late ViewportTestProject project;
  FilamentEngine? engine;

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop);
  });

  tearDown(() {
    engine?.dispose();
    engine = null;
  });

  bool skip() {
    if (!ViewportTestProject.available) {
      markTestSkipped('test-assets models missing');
      return true;
    }
    if (engine == null) {
      markTestSkipped('no native assets');
      return true;
    }
    return false;
  }

  Map<String, Object?> at(double x, double y, double z) => {
        'location': [x, y, z],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      };

  test('a static and a skeletal mesh are two renderable meshes', () async {
    if (skip()) return;
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene()..gridVisible = false;
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin, transform: at(0, 0, 0));
    final prop = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.barrel, transform: at(80, 0, 0));
    runtime.apply(scene);
    await runtime.whenReady;
    expect(runtime.failures, isEmpty);
    expect((runtime.componentOf(hero)! as LuminaStaticMeshComponent).isLoaded, isTrue);
    expect((runtime.componentOf(prop)! as LuminaStaticMeshComponent).isLoaded, isTrue);
    expect(runtime.componentOf(hero), isA<LuminaAnimatedMeshComponent>());
    expect(runtime.scene.renderableCount, greaterThanOrEqualTo(2));
    final meshes = runtime.nodeIds.map(runtime.componentOf).whereType<LuminaStaticMeshComponent>().where((m) => m.isLoaded);
    expect(meshes, hasLength(2));
    // A Set Text-sized edit elsewhere: nothing to apply.
    expect(runtime.apply(scene.copy()), isEmpty);
  });

  test('swapping the mesh of a node keeps its transform', () async {
    if (skip()) return;
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    final hat = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.hatA, transform: at(10, 20, 30));
    runtime.apply(scene);
    await runtime.whenReady;
    final before = runtime.componentOf(hat)!;
    final where = before.relativeLocation.clone();
    final next = scene.copy()..setNodeAsset(hat, ViewportTestProject.hatB);
    final ops = runtime.apply(next);
    expect(ops.map((o) => o.kind), [LuminaViewportSceneOpKind.updateNode]);
    await runtime.whenReady;
    final after = runtime.componentOf(hat)! as LuminaStaticMeshComponent;
    expect(identical(after, before), isFalse);
    expect(after.meshAssetPath, ViewportTestProject.hatB);
    expect(after.isLoaded, isTrue);
    expect(after.relativeLocation, where);
    expect(where, LuminaAxes.location([10, 20, 30]));
  });

  test('a node attached to the hand_r socket follows it while the animation plays', () async {
    if (skip()) return;
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin, transform: at(0, 0, 0));
    final card = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.hatA, transform: at(0, 0, 0));
    scene
      ..playAnimation(hero, ViewportTestProject.idle)
      ..attachToSocket(card, hero, 'hand_r');
    runtime.apply(scene);
    await runtime.whenReady;
    final mesh = runtime.componentOf(hero)! as LuminaAnimatedMeshComponent;
    expect(mesh.currentClip, project.idleClip);
    expect(runtime.animating, isTrue);
    final positions = <Vector3>[];
    for (var i = 0; i < 3; i++) {
      runtime.advance(0.4);
      final hand = mesh.jointWorldTransform('hand_r')!.getTranslation();
      final attached = runtime.componentOf(card)!.worldTransform.getTranslation();
      expect((attached - hand).length, lessThan(0.01), reason: 'frame $i: the card sits on hand_r');
      positions.add(attached);
    }
    expect((positions[0] - positions[2]).length, greaterThan(0.001), reason: 'the idle moves the hand');
  });

  test('a missing asset reports On Asset Load Failed naming it', () async {
    if (skip()) return;
    final events = <String>[];
    final runtime = LuminaViewportSceneRuntime(engine: engine!, onEvent: (e, args) => events.add('$e ${args['asset'] ?? ''}'));
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    scene.addNode(LuminaViewportNodeKind.staticMesh, asset: 'contents/meshes/static/SM_Missing.lmas');
    runtime.apply(scene);
    await runtime.whenReady;
    expect(events, ['OnAssetLoadFailed contents/meshes/static/SM_Missing.lmas', 'OnSceneReady ']);
    expect(runtime.failures.keys, ['contents/meshes/static/SM_Missing.lmas']);
  });

  test('disposing destroys the view, scene and nodes it created', () async {
    if (skip()) return;
    final start = engine!.resourceCounts;
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    final scene = LuminaViewportScene();
    scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    scene.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.acUnit);
    scene.addLight(LuminaViewportLightType.directional, [1, 1, 1, 1], 100000, null);
    runtime.apply(scene);
    await runtime.whenReady;
    final during = engine!.resourceCounts;
    expect(during.views, start.views + 1);
    expect(during.scenes, start.scenes + 1);
    runtime.dispose();
    final end = engine!.resourceCounts;
    expect(end.views, start.views);
    expect(end.scenes, start.scenes);
    expect(end.lights, start.lights);
    expect(end.renderables, start.renderables);
    expect(end.entities, start.entities);
  });
}
