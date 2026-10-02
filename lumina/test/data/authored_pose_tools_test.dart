import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File get _manny => File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');

Vector3 _pos(Matrix4 m) => m.getTranslation();

Quaternion _rot(Matrix4 m) {
  final t = Vector3.zero();
  final r = Quaternion.identity();
  final s = Vector3.zero();
  m.decompose(t, r, s);
  return r..normalize();
}

double _angleBetween(Quaternion a, Quaternion b) {
  final d = (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs().clamp(0.0, 1.0);
  return 2 * math.acos(d) * 180 / math.pi;
}

Map<int, BoneTrs> _rest(GlbSkeleton s) => {for (var i = 0; i < s.count; i++) i: s.rest(i)};

/// Sets [bone]'s local rotation so its world rotation turns by [delta]
/// (a world-space rotation) from what [pose] gives it.
void _turnWorld(GlbSkeleton s, Map<int, BoneTrs> pose, String bone, Quaternion delta) {
  final node = s.indexOf(bone);
  final world = s.worldMatrices(pose);
  final parent = s.parent[node];
  final pr = parent < 0 ? Quaternion.identity() : _rot(world[parent]);
  final local = pr.conjugated() * delta * _rot(world[node]);
  pose[node] = BoneTrs(pose[node]!.t, local..normalize(), pose[node]!.s);
}

/// The local translation that puts [bone] at world position [world].
List<double> _localFor(GlbSkeleton s, Map<int, BoneTrs> pose, String bone, Vector3 world) {
  final node = s.indexOf(bone);
  final parent = s.parent[node];
  final pw = parent < 0 ? Matrix4.identity() : s.worldMatrices(pose)[parent];
  final local = (Matrix4.inverted(pw)).transformed3(world);
  return [local.x, local.y, local.z];
}

/// Posing helpers for authored clips: the left/right mirror table, two-bone
/// IK, root motion extraction, pose blending and the per-skeleton pose library.
void main() {
  late GlbSkeleton manny;
  setUpAll(() {
    if (_manny.existsSync()) manny = GlbSkeleton.fromGlb(_manny.readAsBytesSync());
  });

  group('SkeletonMirror', () {
    test('mirrored names follow the _l/_r, Left/Right, .L/.R and l_/r_ conventions', () {
      expect(SkeletonMirror.mirroredName('upperarm_r'), 'upperarm_l');
      expect(SkeletonMirror.mirroredName('lowerarm_twist_01_L'), 'lowerarm_twist_01_R');
      expect(SkeletonMirror.mirroredName('mixamorig:LeftHand'), 'mixamorig:RightHand');
      expect(SkeletonMirror.mirroredName('Bip01.L'), 'Bip01.R');
      expect(SkeletonMirror.mirroredName('l_foot'), 'r_foot');
      expect(SkeletonMirror.mirroredName('head'), isNull);
      expect(SkeletonMirror.mirroredName('spine_01'), isNull);
    });

    test('pairs come from the skeleton, the axis from its rest pose, and overrides win', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final mirror = SkeletonMirror.of(manny);
      expect(mirror.partnerOf('upperarm_r'), 'upperarm_l');
      expect(mirror.partnerOf('foot_l'), 'foot_r');
      expect(mirror.partnerOf('head'), 'head');
      expect(mirror.pairs.length, greaterThan(20));
      final world = manny.worldMatrices();
      final across = (_pos(world[manny.indexOf('upperarm_l')]) - _pos(world[manny.indexOf('upperarm_r')])).normalized();
      expect(mirror.lateralAxis.dot(across).abs(), greaterThan(0.99), reason: 'detected from the rest pose');
      // The shoulders mirror onto each other across the detected plane.
      final l = _pos(world[manny.indexOf('upperarm_l')]);
      final r = _pos(world[manny.indexOf('upperarm_r')]);
      expect((mirror.mirrorPoint(r) - l).length, lessThan(1e-3));

      final custom = SkeletonMirror.of(manny, overrides: const {'thigh_l': 'calf_r'});
      expect(custom.partnerOf('thigh_l'), 'calf_r');
      expect(custom.partnerOf('calf_r'), 'thigh_l');
    });

    test('a raised right arm mirrors onto the left arm and a head yaw flips its sign', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final mirror = SkeletonMirror.of(manny);
      final pose = _rest(manny);
      final world0 = manny.worldMatrices(pose);
      final up = Vector3(0, 1, 0);
      final forward = up.cross(mirror.lateralAxis).normalized();
      _turnWorld(manny, pose, 'upperarm_r', Quaternion.axisAngle(forward, 50 * math.pi / 180));
      _turnWorld(manny, pose, 'head', Quaternion.axisAngle(up, 30 * math.pi / 180));
      final source = manny.worldMatrices(pose);

      final out = mirror.mirror(source: pose, target: pose, bones: const ['upperarm_r', 'head']);
      expect(out.keys.map((n) => manny.names[n]).toSet(), {'upperarm_l', 'head'});
      final result = {...pose, ...out};
      final world = manny.worldMatrices(result);
      final handR = _pos(source[manny.indexOf('hand_r')]);
      final handL = _pos(world[manny.indexOf('hand_l')]);
      expect((mirror.mirrorPoint(handR) - handL).length, lessThan(1e-3), reason: 'the left hand mirrors the right');
      expect(handL.y, greaterThan(_pos(world0[manny.indexOf('hand_l')]).y + 0.1), reason: 'the left arm is raised too');
      // Head: the world turn is about the up axis by −30°.
      final head = manny.indexOf('head');
      final turned = _rot(world[head]) * _rot(world0[head]).conjugated();
      final expected = Quaternion.axisAngle(up, -30 * math.pi / 180);
      expect(_angleBetween(turned, expected), lessThan(0.05));
    });
  });

  group('TwoBoneIkSolver', () {
    test('the humanoid chains are found on the mannequin', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final chains = {for (final c in TwoBoneIkChain.detect(manny)) c.name: c};
      expect(chains.keys.toSet(), {'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg'});
      final arm = chains['RightArm']!;
      expect([manny.names[arm.upper], manny.names[arm.lower], manny.names[arm.end]], ['upperarm_r', 'lowerarm_r', 'hand_r']);
      final leg = chains['LeftLeg']!;
      expect([manny.names[leg.upper], manny.names[leg.lower], manny.names[leg.end]], ['thigh_l', 'calf_l', 'foot_l']);
    });

    test('a hand target 10 cm forward is reached with the elbow towards the pole, by rotations only', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final chain = TwoBoneIkChain.detect(manny).firstWhere((c) => c.name == 'RightArm');
      final mirror = SkeletonMirror.of(manny);
      final pose = _rest(manny);
      final world = manny.worldMatrices(pose);
      final forward = Vector3(0, 1, 0).cross(mirror.lateralAxis).normalized();
      final hand = _pos(world[chain.end]);
      final shoulder = _pos(world[chain.upper]);
      final target = hand + forward * 0.10;
      final pole = _pos(world[chain.lower]) - forward * 0.5;

      final out = TwoBoneIkSolver.solve(skeleton: manny, pose: pose, chain: chain, target: target, pole: pole);
      expect(out.keys.toSet(), {chain.upper, chain.lower, chain.end});
      for (final e in out.entries) {
        expect((e.value.t - pose[e.key]!.t).length, lessThan(1e-9), reason: 'translations untouched');
        expect((e.value.s - pose[e.key]!.s).length, lessThan(1e-9), reason: 'scales untouched');
      }
      final solved = manny.worldMatrices({...pose, ...out});
      expect((_pos(solved[chain.end]) - target).length, lessThan(0.005), reason: 'within 0.5 cm of the target');
      final elbow = _pos(solved[chain.lower]);
      final toTarget = (target - shoulder).normalized();
      final bend = (pole - shoulder) - toTarget * (pole - shoulder).dot(toTarget);
      final elbowOff = (elbow - shoulder) - toTarget * (elbow - shoulder).dot(toTarget);
      expect(elbowOff.dot(bend), greaterThan(0), reason: 'the elbow points at the pole');
      expect(_angleBetween(_rot(solved[chain.end]), _rot(world[chain.end])), lessThan(0.01),
          reason: 'the hand keeps its world orientation');
    });

    test('an out-of-reach target straightens the chain towards it', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final chain = TwoBoneIkChain.detect(manny).firstWhere((c) => c.name == 'LeftLeg');
      final pose = _rest(manny);
      final world = manny.worldMatrices(pose);
      final hip = _pos(world[chain.upper]);
      final target = hip + Vector3(0, -5, 0);
      final out = TwoBoneIkSolver.solve(skeleton: manny, pose: pose, chain: chain, target: target);
      final solved = manny.worldMatrices({...pose, ...out});
      final dir = (_pos(solved[chain.end]) - hip).normalized();
      expect(dir.dot(Vector3(0, -1, 0)), greaterThan(0.999));
    });
  });

  group('RootMotionAuthoring', () {
    test('Extract from Pelvis moves the horizontal travel to the root and keeps the world pelvis path', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final root = manny.names[manny.root!]!;
      final pelvis = manny.names[manny.rootChild!]!;
      expect(pelvis, 'pelvis');
      final clip = AuthoredAnimationClip(name: 'Walk', lengthFrames: 30);
      final rest = _rest(manny);
      final p0 = _pos(manny.worldMatrices(rest)[manny.rootChild!]);
      clip.setKey(pelvis, AuthoredChannel.translation, 0, rest[manny.rootChild!]!.channel(AuthoredChannel.translation));
      clip.setKey(pelvis, AuthoredChannel.translation, 30, _localFor(manny, rest, pelvis, p0 + Vector3(0.4, -0.05, 1.2)));
      clip.setKey(pelvis, AuthoredChannel.translation, 15, _localFor(manny, rest, pelvis, p0 + Vector3(0.2, 0.03, 0.6)));
      Vector3 pelvisWorld(AuthoredAnimationClip c, int f) =>
          _pos(manny.worldMatrices(c.samplePose(manny, f / c.frameRate))[manny.rootChild!]);
      Vector3 rootWorld(AuthoredAnimationClip c, int f) =>
          _pos(manny.worldMatrices(c.samplePose(manny, f / c.frameRate))[manny.root!]);
      final before = [for (final f in [0, 7, 15, 22, 30]) pelvisWorld(clip, f)];

      expect(RootMotionAuthoring.extractFromPelvis(clip, manny), isTrue);
      expect(clip.keyFrames(root), [0, 15, 30]);
      for (final (i, f) in [0, 7, 15, 22, 30].indexed) {
        expect((pelvisWorld(clip, f) - before[i]).length, lessThan(1e-5), reason: 'pelvis path unchanged at frame $f');
      }
      final travel = rootWorld(clip, 30) - rootWorld(clip, 0);
      expect((travel - Vector3(0.4, 0, 1.2)).length, lessThan(1e-5), reason: 'the root carries the horizontal travel');
      for (final f in [0, 15, 30]) {
        final offset = pelvisWorld(clip, f) - rootWorld(clip, f);
        final offset0 = pelvisWorld(clip, 0) - rootWorld(clip, 0);
        expect(offset.x, closeTo(offset0.x, 1e-5));
        expect(offset.z, closeTo(offset0.z, 1e-5), reason: 'the pelvis keeps only its vertical motion');
      }

      expect(RootMotionAuthoring.zeroRoot(clip, manny), isTrue);
      for (final (i, f) in [0, 7, 15, 22, 30].indexed) {
        expect((pelvisWorld(clip, f) - before[i]).length, lessThan(1e-5));
      }
      expect((rootWorld(clip, 30) - rootWorld(clip, 0)).length, lessThan(1e-9), reason: 'the root stays put');
    });

    test('a clip without pelvis translation keys has nothing to extract', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final clip = AuthoredAnimationClip(name: 'Idle', lengthFrames: 30)
        ..setKey('head', AuthoredChannel.rotation, 0, const [0, 0, 0, 1]);
      expect(RootMotionAuthoring.extractFromPelvis(clip, manny), isFalse);
    });
  });

  group('pose blending and the pose library', () {
    test('BoneTrs.blend goes half way at 0.5 (rotation by slerp)', () {
      final a = BoneTrs(Vector3(0, 0, 0), Quaternion.identity(), Vector3.all(1));
      final b = BoneTrs(Vector3(2, 0, 4), Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2), Vector3.all(3));
      final h = BoneTrs.blend(a, b, 0.5);
      expect((h.t - Vector3(1, 0, 2)).length, lessThan(1e-12));
      expect(_angleBetween(h.r, Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4)), lessThan(1e-6));
      expect((h.s - Vector3.all(2)).length, lessThan(1e-12));
    });

    test('the library round-trips its poses and mirror overrides next to the mesh\'s clips', () {
      final project = Directory.systemTemp.createTempSync('lumina_pose_lib_');
      addTearDown(() => project.deleteSync(recursive: true));
      const mesh = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
      expect(AuthoredPoseLibraryStore.pathFor(mesh), 'contents/animations/SKM_Manny_Simple/PoseLibrary.lmas');
      expect(AuthoredPoseLibraryStore.load(project.path, mesh).poses, isEmpty);
      final library = AuthoredPoseLibrary(meshRelPath: mesh, poses: [
        AuthoredPose('Wave', {
          'upperarm_r': BoneTrs(Vector3(1, 2, 3), Quaternion.axisAngle(Vector3(1, 0, 0), 0.3), Vector3.all(1)),
        }),
      ], mirrorOverrides: const {'thigh_l': 'thigh_r'});
      AuthoredPoseLibraryStore.save(project.path, library);
      final file = File('${project.path}/contents/animations/SKM_Manny_Simple/PoseLibrary.lmas');
      expect(file.existsSync(), isTrue);
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      expect(asset.metadata['pose_library'], 'true');
      expect(asset.metadata['source_mesh'], mesh);
      final back = AuthoredPoseLibraryStore.load(project.path, mesh);
      expect(back.toJson(), library.toJson());
      expect(back.poses.single.bones['upperarm_r']!.toList(), library.poses.single.bones['upperarm_r']!.toList());
    });
  });
}
