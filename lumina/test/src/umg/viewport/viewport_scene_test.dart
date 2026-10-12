import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Viewport's preview-scene description: JSON-plain, round-trips
/// byte-identically, and diffs into the minimal edit.
void main() {
  LuminaViewportScene sample() {
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh,
        asset: 'contents/meshes/skeletal/SKM_Mannequin.lmas',
        transform: {
          'location': [0.0, 0.0, 0.0],
          'rotation': [0.0, 0.0, 90.0],
          'scale': [1.0, 1.0, 1.0],
        });
    scene.playAnimation(hero, 'contents/animations/M_Neutral_Stand_Idle_Loop/M_Neutral_Stand_Idle_Loop.lmas');
    scene.addLight(LuminaViewportLightType.directional, [1.0, 0.95, 0.9, 1.0], 100000.0, {
      'location': [0.0, 0.0, 300.0],
      'rotation': [-45.0, 0.0, 30.0],
      'scale': [1.0, 1.0, 1.0],
    });
    scene.showSkeleton(hero, [1.0, 0.85, 0.2, 1.0]);
    scene.setGizmo(hero, bone: 'hand_r', mode: 'rotate', space: 'local', snap: 5.0);
    scene.addMarker('Grip', 'point', [10.0, 0.0, 120.0], [10.0, 0.0, 120.0], [1.0, 0.2, 0.2, 1.0]);
    scene.addMarker('Reach', 'arrow', [0.0, 0.0, 100.0], [40.0, 0.0, 100.0], [0.2, 0.6, 1.0, 1.0]);
    return scene;
  }

  test('a skeletal mesh, a light, a skeleton overlay, a gizmo and two markers round-trip byte-identically', () {
    final scene = sample();
    final text = scene.encode();
    final again = LuminaViewportScene.decode(text);
    expect(again.encode(), text);
    expect(again.nodes.map((n) => n['kind']), [LuminaViewportNodeKind.skeletalMesh, LuminaViewportNodeKind.light]);
    expect(again.skeletonOverlays, hasLength(1));
    expect(again.gizmo?['bone'], 'hand_r');
    expect(again.markers.map((m) => m['label']), ['Grip', 'Reach']);
    expect(LuminaViewportSceneDiff.diff(scene, again), isEmpty);
  });

  test('the view mode defaults to lit, round-trips and changes as one viewMode op', () {
    final scene = sample();
    expect(scene.viewMode, LuminaViewportViewMode.lit);
    final next = scene.copy()..viewMode = LuminaViewportViewMode.wireframe;
    expect(LuminaViewportScene(LuminaViewportScene.plain(next.json) as Map<String, Object?>).viewMode, LuminaViewportViewMode.wireframe);
    final ops = LuminaViewportSceneDiff.diff(scene, next);
    expect(ops.map((o) => o.kind), [LuminaViewportSceneOpKind.viewMode]);
    expect(ops.single.value, {'value': 'wireframe'});
    next.viewMode = 'toon';
    expect(next.viewMode, LuminaViewportViewMode.lit);
    expect(LuminaViewportSceneDiff.diff(scene, next), isEmpty);
    // A first description that is not lit applies its mode.
    final unlit = sample()..viewMode = LuminaViewportViewMode.unlit;
    expect(LuminaViewportSceneDiff.diff(null, unlit).map((o) => o.kind), contains(LuminaViewportSceneOpKind.viewMode));
  });

  test('changing one node transform is exactly one updateNode op', () {
    final before = sample();
    final after = before.copy();
    final hero = after.nodes.first['id']! as String;
    after.setNodeTransform(hero, {
      'location': [0.0, 25.0, 0.0],
      'rotation': [0.0, 0.0, 90.0],
      'scale': [1.0, 1.0, 1.0],
    });
    final ops = LuminaViewportSceneDiff.diff(before, after);
    expect(ops, hasLength(1));
    expect(ops.single.kind, LuminaViewportSceneOpKind.updateNode);
    expect(ops.single.id, hero);
    expect(ops.single.fields, {'transform'});
  });

  test('removing a marker is one removeMarker op', () {
    final before = sample();
    final after = before.copy();
    expect(after.removeMarker(after.markers.first['id']! as String), isTrue);
    final ops = LuminaViewportSceneDiff.diff(before, after);
    expect(ops.map((o) => o.kind), [LuminaViewportSceneOpKind.removeMarker]);
  });

  test('a transform of (0, 0, 100) cm Z-up is applied at (0, 1, 0) m Y-up', () {
    final t = LuminaViewportTransforms.toRuntime({
      'location': [0.0, 0.0, 100.0],
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
    });
    expect(t.location, Vector3(0, 100, 0), reason: 'the runtime is centimetres, Y up');
    final m = t.locationMetres;
    expect(m.x, closeTo(0, 1e-9));
    expect(m.y, closeTo(1, 1e-9));
    expect(m.z, closeTo(0, 1e-9));
    // And back: the authoring transform the gizmo writes on commit.
    final back = LuminaViewportTransforms.toAuthoring(Matrix4.compose(t.location, LuminaAxes.rotation([10, 20, 30]), Vector3.all(1)));
    expect((back['location']! as List).cast<double>(), [0.0, 0.0, 100.0]);
    final r = (back['rotation']! as List).cast<double>();
    expect(r[0], closeTo(10, 1e-4));
    expect(r[1], closeTo(20, 1e-4));
    expect(r[2], closeTo(30, 1e-4));
  });

  test('removing a parent removes the nodes attached to it and the overlays and gizmo on them', () {
    final scene = sample();
    final hero = scene.nodes.first['id']! as String;
    final hat = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: 'contents/meshes/SM_Hat.lmas');
    expect(scene.attachToSocket(hat, hero, 'head'), isTrue);
    expect(scene.removeNode(hero), isTrue);
    expect(scene.node(hat), isNull);
    expect(scene.skeletonOverlays, isEmpty);
    expect(scene.gizmo, isNull);
  });

  test('the description is stored on the element and stays JSON-plain', () {
    final element = <String, Object?>{'type': 'viewport', 'name': 'Preview'};
    final scene = LuminaViewportScene.of(element);
    scene.addNode(LuminaViewportNodeKind.staticMesh, asset: 'a.lmas', transform: {
      'location': Vector3(1, 2, 3),
      'rotation': const LuminaRotator(0, 0, 45),
      'scale': [1, 1, 1],
    });
    expect(identical(element['scene'], scene.json), isTrue);
    final node = scene.nodes.single;
    expect((node['transform']! as Map)['location'], [1.0, 2.0, 3.0]);
    expect((node['transform']! as Map)['rotation'], [0.0, 0.0, 45.0]);
    expect(LuminaViewportScene.decode(scene.encode()).encode(), scene.encode());
  });
}
