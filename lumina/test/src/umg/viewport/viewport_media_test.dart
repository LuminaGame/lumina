import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../support/viewport_project.dart';

/// What a Viewport reads beyond meshes: a texture material parameter, a
/// ghost pose sampled from an animation at a time, the motion and animation
/// files a plugin process writes (editor panels), the overlays drawn as
/// Filament lines, and the project's `umg.maxViewports`.
void main() {
  late ViewportTestProject project;
  FilamentEngine? engine;
  final texture = File('${viewportTestAssets.path}/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_MI_Display_1_Emissive.png');

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  setUp(() => engine = FilamentEngine.create(backend: FilamentBackend.noop));
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

  Future<void> settle(LuminaViewportSceneRuntime r, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      r.advance(1 / 60);
    }
  }

  test('a texture material parameter binds the texture to the slot sampler', () async {
    if (skip()) return;
    if (!texture.existsSync()) return markTestSkipped('test-assets texture missing');
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    final hat = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.hatA);
    runtime.apply(scene);
    await runtime.whenReady;
    runtime.apply(scene.copy()..setMaterialParameter(hat, '0', 'baseColorMap', texture.path));
    await settle(runtime, () => runtime.boundTextureCount(hat) == 1);
    expect(runtime.failures, isEmpty);
    expect(runtime.boundTextureCount(hat), 1);
  });

  test('a ghost pose sampled from the idle at a time differs from the live pose and leaves it', () async {
    if (skip()) return;
    final runtime = LuminaViewportSceneRuntime(engine: engine!);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    scene.showGhostPose(hero, animation: ViewportTestProject.idle, time: 1.2, label: 'later');
    runtime.apply(scene);
    await runtime.whenReady;
    final live = runtime.jointsOf(hero).map((j) => j.position.clone()).toList();
    final overlay = scene.skeletonOverlay(hero)!;
    expect(runtime.ghostPoseFor(hero, overlay), isNull, reason: 'sampled in the background');
    var changed = 0;
    runtime.onOverlaysChanged = () => changed++;
    await settle(runtime, () => runtime.ghostPoseFor(hero, overlay) != null);
    final pose = runtime.ghostPoseFor(hero, overlay)!;
    expect(changed, 1);
    expect(pose.keys, contains('hand_r'));
    final ghost = runtime.ghostJointsOf(hero, pose);
    expect(ghost.map((j) => j.name), runtime.jointsOf(hero).map((j) => j.name));
    final after = runtime.jointsOf(hero).map((j) => j.position.clone()).toList();
    for (var i = 0; i < live.length; i++) {
      expect((after[i] - live[i]).length, lessThan(1e-3), reason: 'sampling put the live pose back');
    }
  });

  test('Play Animation File plays a packed motion in an editor panel and is refused in a game', () async {
    if (skip()) return;
    final meshGlb = File('${viewportTestAssets.path}/${ViewportTestProject.sources[ViewportTestProject.mannequin]}').readAsBytesSync();
    final order = LuminaViewportMotion.skeletonOrder(meshGlb);
    expect(order, contains('hand_r'));
    // Two frames: the rest pose, then hand_r moved 0.2 along X.
    final data = Float32List(2 * order.length * 10);
    for (var f = 0; f < 2; f++) {
      for (var j = 0; j < order.length; j++) {
        final o = (f * order.length + j) * 10;
        data[o + 6] = 1; // qw
        data[o + 7] = data[o + 8] = data[o + 9] = 1;
        if (f == 1 && order[j] == 'hand_r') data[o] = 0.2;
      }
    }
    final file = File('${project.dir.path}/motions/m_test.kmo')..parent.createSync(recursive: true);
    file.writeAsBytesSync(LuminaViewportMotion.encode(LuminaViewportMotion(frames: 2, joints: order.length, frameRate: 1, data: data)));

    final events = <String>[];
    final game = LuminaViewportSceneRuntime(engine: engine!, onEvent: (e, a) => events.add('$e ${a['message'] ?? ''}'));
    addTearDown(game.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    scene.playAnimationFile(hero, file.path, loop: false);
    game.apply(scene);
    await game.whenReady;
    await settle(game, () => events.any((e) => e.startsWith('OnAssetLoadFailed')));
    expect(events.where((e) => e.contains('editor panels only')), hasLength(1));

    final panel = LuminaViewportSceneRuntime(engine: engine!, allowFiles: true);
    addTearDown(panel.dispose);
    panel.apply(scene.copy());
    await panel.whenReady;
    await settle(panel, () => panel.playsMotion(hero));
    expect(panel.failures, isEmpty);
    expect(panel.animating, isTrue);
    Vector3 hand() => panel.jointsOf(hero).firstWhere((j) => j.name == 'hand_r').position.clone();
    final rest = hand();
    panel.advance(1.0); // the last frame: hand_r 0.2 m along its parent's X
    expect((hand() - rest).length, greaterThan(1.0), reason: 'the motion moved the hand (cm)');
    final elbow = panel.jointsOf(hero).firstWhere((j) => j.name == 'lowerarm_r').position;
    expect((hand() - elbow).length, greaterThan((rest - elbow).length + 1.0), reason: 'away from the elbow');
  });

  test('Play Animation File retargets an animation file onto the node mesh and plays its clip', () async {
    if (skip()) return;
    final clipGlb = File('${viewportTestAssets.path}/mannequin/MF_Unarmed_Walk_Fwd.glb');
    if (!clipGlb.existsSync()) return markTestSkipped('test-assets clip missing');
    final runtime = LuminaViewportSceneRuntime(engine: engine!, allowFiles: true);
    addTearDown(runtime.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    runtime.apply(scene);
    await runtime.whenReady;
    runtime.apply(scene.copy()..playAnimationFile(hero, clipGlb.path));
    await settle(runtime, () => (runtime.componentOf(hero) as LuminaAnimatedMeshComponent?)?.currentClip == 'MF_Unarmed_Walk_Fwd');
    expect(runtime.failures, isEmpty);
    final mesh = runtime.componentOf(hero)! as LuminaAnimatedMeshComponent;
    expect(mesh.currentClip, 'MF_Unarmed_Walk_Fwd');
    expect(mesh.clipNames, contains(project.idleClip), reason: 'the mesh keeps its own clips');
  });

  test('skeletons, ghosts and markers are Filament lines in an overlay view', () async {
    if (skip()) return;
    final controller = LuminaViewportController(runtime: LuminaViewportSceneRuntime(engine: engine!), fire: (_, _) {});
    addTearDown(controller.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    controller.resize(400, 300);
    controller.sync(scene);
    await controller.runtime.whenReady;
    controller.frame(1 / 60);
    expect(controller.overlayView, isNull, reason: 'no overlay: no extra view');
    scene
      ..showSkeleton(hero, [1, 1, 0, 1])
      ..addMarker('Reach', 'arrow', [0, 0, 100], [40, 0, 100], [1, 0, 0, 1]);
    controller.sync(scene);
    expect(controller.frame(1 / 60), isTrue);
    final joints = controller.runtime.jointsOf(hero).length;
    expect(controller.overlayView, isNotNull);
    final bones = LuminaSkeletonOverlay.bones(controller.runtime.jointsOf(hero)).length;
    expect(controller.overlayLineCount, bones + joints * 2 + 3, reason: 'bones, a cross per joint, an arrow of three lines');
    final lines = LuminaViewportOverlayLines.segmentsOf(controller.runtime, scene);
    expect(lines.first.from, isA<Vector3>());
  });

  test('umg.maxViewports sets the count limit of every scope but the web cap', () {
    addTearDown(() => LuminaViewportBudget.projectMaxViewports = null);
    LuminaViewportBudget.projectMaxViewports = 6;
    expect(LuminaViewportBudget().maxViewports, 6);
    expect(LuminaViewportBudget(scope: LuminaViewportScope.editor).maxViewports, 6);
    expect(LuminaViewportBudget(scope: LuminaViewportScope.web).maxViewports, 2);
    expect(LuminaViewportBudget(maxViewports: 3).maxViewports, 3, reason: 'a budget of its own wins');
    LuminaViewportBudget.projectMaxViewports = null;
    expect(LuminaViewportBudget().maxViewports, 4);
  });
}
