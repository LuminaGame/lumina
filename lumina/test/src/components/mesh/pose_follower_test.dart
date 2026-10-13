import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A follower skinned mesh takes its leader's joint transforms by bone name
/// every frame, right after the leader's pose, on a real (headless) engine
/// with the Third Person character and the mannequin.
void main() {
  const bundle = LuminaThirdPersonContent.bundledMeshPath;
  final walkClip = LuminaThirdPersonContent.walkClips[LuminaLocomotionDirection.forward]!;
  final manny = File('${Directory.current.parent.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb');

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

  Future<List<LuminaAnimatedMeshComponent>> spawn(List<String> paths, {List<Vector3>? at}) async {
    final meshes = <LuminaAnimatedMeshComponent>[];
    for (var i = 0; i < paths.length; i++) {
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: paths[i], location: at?[i]);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
      meshes.add(mesh);
    }
    world.beginPlay();
    for (final m in meshes) {
      await m.loaded;
    }
    return meshes;
  }

  /// The angle (degrees) between the rotations of two matrices.
  double degreesBetween(Matrix4 a, Matrix4 b) {
    Quaternion rot(Matrix4 m) {
      final r = m.getRotation();
      for (var c = 0; c < 3; c++) {
        final len = math.sqrt(r.entry(0, c) * r.entry(0, c) + r.entry(1, c) * r.entry(1, c) + r.entry(2, c) * r.entry(2, c));
        for (var row = 0; row < 3; row++) {
          r.setEntry(row, c, r.entry(row, c) / len);
        }
      }
      return Quaternion.fromRotation(r)..normalize();
    }

    final d = (rot(a).clone()..inverse()) * rot(b);
    d.normalize();
    return 2.0 * math.acos(d.w.abs().clamp(0.0, 1.0)) * 180.0 / math.pi;
  }

  test('a follower with no clip of its own matches the playing leader joint for joint', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final [leader, follower] = await spawn([bundle, bundle]);
    follower.poseLeader = leader;
    await follower.poseLinkReady;
    expect(leader.poseFollowers, [follower]);
    leader.play(walkClip);
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    expect(follower.followedBones, isNotEmpty);
    expect(follower.unmatchedBones, isEmpty);
    var checked = 0;
    for (final bone in follower.followedBones) {
      final a = leader.jointWorldTransform(bone), b = follower.jointWorldTransform(bone);
      if (a == null || b == null) continue;
      checked++;
      expect((a.getTranslation() - b.getTranslation()).length, lessThan(1e-4), reason: bone);
      expect(degreesBetween(a, b), lessThan(0.1), reason: bone);
    }
    expect(checked, greaterThan(20));
    // The walk moved the pose away from rest, so this is not a rest-pose match.
    final rest = (await spawn([bundle])).single;
    world.tick(1 / 60);
    final moved = follower.followedBones.where((b) {
      final r = rest.jointLocalTransform(b), f = follower.jointLocalTransform(b);
      return r != null && f != null && degreesBetween(r, f) > 2;
    });
    expect(moved, isNotEmpty);
  });

  test("the leader's pose wins over the follower's own clip; the follower's joint override still applies", () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final [leader, follower] = await spawn([bundle, bundle]);
    leader.play(LuminaThirdPersonContent.idleClip);
    follower.play(walkClip);
    follower.poseLeader = leader;
    await follower.poseLinkReady;
    world.tick(1 / 60);
    for (final bone in ['spine_02', 'thigh_l', 'calf_r']) {
      expect(degreesBetween(leader.jointLocalTransform(bone)!, follower.jointLocalTransform(bone)!), lessThan(0.1), reason: bone);
    }
    follower.setJointOverride('Head', rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 30 * math.pi / 180));
    world.tick(1 / 60);
    expect(degreesBetween(leader.jointLocalTransform('Head')!, follower.jointLocalTransform('Head')!), closeTo(30, 1.0));
    // Handing it back: the follower plays its own walk again.
    follower.clearJointOverride('Head');
    follower.poseLeader = null;
    expect(leader.poseFollowers, isEmpty);
    for (var i = 0; i < 20; i++) {
      world.tick(1 / 60);
    }
    expect(degreesBetween(leader.jointLocalTransform('thigh_l')!, follower.jointLocalTransform('thigh_l')!), greaterThan(2));
  });

  test('bones the leader lacks keep their own pose; a bone under another parent lands on the leader bone', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    if (!manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final [leader, follower] = await spawn([bundle, manny.path]);
    follower.poseLeader = leader;
    await follower.poseLinkReady;
    leader.play(walkClip);
    final spine04Before = follower.jointLocalTransform('spine_04')!;
    for (var i = 0; i < 10; i++) {
      world.tick(1 / 60);
    }
    // The mannequin's extra spine and neck bones are its own.
    expect(follower.unmatchedBones, containsAll(['spine_04', 'spine_05', 'neck_02', 'head']));
    expect(follower.followedBones, containsAll(['pelvis', 'thigh_l', 'neck_01']));
    final spine04After = follower.jointLocalTransform('spine_04')!;
    for (var i = 0; i < 16; i++) {
      expect(spine04After.storage[i], closeTo(spine04Before.storage[i], 1e-5));
    }
    // neck_01 hangs from spine_05 on the mannequin but from spine_03 on the
    // leader: it takes the leader bone's world transform.
    final a = leader.jointWorldTransform('neck_01')!, b = follower.jointWorldTransform('neck_01')!;
    expect((a.getTranslation() - b.getTranslation()).length, lessThan(1e-3));
    // Same-parent bones copy their local transform.
    expect(degreesBetween(leader.jointLocalTransform('calf_l')!, follower.jointLocalTransform('calf_l')!), lessThan(0.1));
  });

  test('a follower placed to the side takes the pose without snapping to the leader', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final [leader, follower] = await spawn([bundle, bundle], at: [Vector3.zero(), Vector3(100, 0, 0)]);
    follower.poseLeader = leader;
    await follower.poseLinkReady;
    leader.play(LuminaThirdPersonContent.idleClip);
    world.tick(1 / 60);
    final a = leader.jointWorldTransform('hand_l')!, b = follower.jointWorldTransform('hand_l')!;
    final offset = b.getTranslation() - a.getTranslation();
    // 100 cm along X, whatever unit the render transform uses.
    expect(offset.x, greaterThan(0.5));
    expect(offset.y.abs() + offset.z.abs(), lessThan(1e-3));
    expect(degreesBetween(a, b), lessThan(0.1));
  });

  test('a pose leader cycle throws', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final [a, b, c] = await spawn([bundle, bundle, bundle]);
    b.poseLeader = a;
    c.poseLeader = b;
    await b.poseLinkReady;
    await c.poseLinkReady;
    expect(() => a.poseLeader = c, throwsStateError);
    expect(() => a.poseLeader = a, throwsStateError);
    expect(a.poseLeader, isNull);
    a.play(walkClip);
    for (var i = 0; i < 5; i++) {
      world.tick(1 / 60);
    }
    // A chain follows through: c matches a.
    expect(degreesBetween(a.jointLocalTransform('thigh_r')!, c.jointLocalTransform('thigh_r')!), lessThan(0.1));
  });

  test('a Blueprint skeletal mesh with poseFrom follows the named component', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final actor = LuminaActor(root: LuminaSceneComponent());
    final diagnostics = <LuminaBlueprintDiagnostic>[];
    final built = LuminaBlueprintComponents.construct(actor, [
      LuminaBlueprintComponent(
        id: 'body',
        name: 'Body',
        type: 'LuminaSkeletalMeshComponent',
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': bundle},
      ),
      LuminaBlueprintComponent(
        id: 'face',
        name: 'Face',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'body',
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': bundle, 'poseFrom': 'body'},
      ),
      LuminaBlueprintComponent(
        id: 'hair',
        name: 'Hair',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'face',
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': bundle, 'poseFrom': 'Body'},
      ),
    ], resolveAsset: (stored) => stored, diagnostics: diagnostics);
    final body = built['body'] as LuminaAnimatedMeshComponent;
    expect((built['face'] as LuminaAnimatedMeshComponent).poseLeader, same(body), reason: 'by id');
    expect((built['hair'] as LuminaAnimatedMeshComponent).poseLeader, same(body), reason: 'by name');
    expect(diagnostics, isEmpty);
  });

  test('twenty followers take their poses in about a millisecond per frame', () async {
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final meshes = await spawn(List.filled(21, bundle));
    final leader = meshes.first;
    for (final f in meshes.skip(1)) {
      f.poseLeader = leader;
      await f.poseLinkReady;
    }
    leader.play(walkClip);
    world.tick(1 / 60);
    final pairs = [for (final f in meshes.skip(1)) f.followedBones.length].fold(0, (a, b) => a + b);
    final probe = meshes[1];
    final sw = Stopwatch()..start();
    const frames = 200;
    for (var i = 0; i < frames; i++) {
      world.tick(1 / 60);
    }
    sw.stop();
    final perFrame = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('pose follow: 20 followers, $pairs bone pairs, ${perFrame.toStringAsFixed(3)} ms per world tick (all 21 meshes, clip included)');
    expect(probe.followedBones, isNotEmpty);
    expect(perFrame, lessThan(2.0));
  });
}
