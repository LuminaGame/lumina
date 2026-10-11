import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get testAssets =>
    Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File get mannequinFile => File('${testAssets.path}/mannequin/SKM_Manny_Simple.glb');

/// Why a mannequin test skips, or false.
Object get mannequinSkip => mannequinFile.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing';

GlbSkeleton? _manny;

/// The test-assets mannequin's skeleton, parsed once.
GlbSkeleton get mannequinSkeleton => _manny ??= GlbSkeleton.fromGlb(mannequinFile.readAsBytesSync());

/// A humanoid skeleton with MetaHuman bone names (glTF metres, +Y up,
/// facing +Z, its left on +X), twist and corrective joints included; no
/// Epic data, only names and lengths. [upperArm] / [lowerArm] are the arm
/// bone lengths; the elbows bend 10° and the knees 5° at rest.
Map<String, dynamic> metahumanSkeletonJson({double upperArm = 0.30, double lowerArm = 0.28, bool legs = true}) {
  final nodes = <Map<String, dynamic>>[];
  final children = <int, List<int>>{};
  int add(String name, int parent, List<double> t, [List<double>? r]) {
    final i = nodes.length;
    nodes.add({'name': name, 'translation': t, 'rotation': ?r});
    if (parent >= 0) (children[parent] ??= []).add(i);
    return i;
  }

  List<double> about(List<double> axis, double degrees) {
    final h = degrees * math.pi / 360;
    return [axis[0] * math.sin(h), axis[1] * math.sin(h), axis[2] * math.sin(h), math.cos(h)];
  }

  final root = add('root', -1, [0, 0, 0]);
  final pelvis = add('pelvis', root, [0, 0.95, 0]);
  var parent = pelvis;
  for (final (name, length) in const [
    ('spine_01', 0.05),
    ('spine_02', 0.08),
    ('spine_03', 0.08),
    ('spine_04', 0.09),
    ('spine_05', 0.10),
  ]) {
    parent = add(name, parent, [0, length, 0]);
  }
  final spine5 = parent;
  final neck1 = add('neck_01', spine5, [0, 0.15, 0]);
  final neck2 = add('neck_02', neck1, [0, 0.05, 0]);
  add('head', neck2, [0, 0.05, 0]);
  add('FACIAL_C_FacialRoot', nodes.length - 1, [0, 0.05, 0.05]);
  for (final side in const ['l', 'r']) {
    final x = side == 'l' ? 1.0 : -1.0;
    final clavicle = add('clavicle_$side', spine5, [0.03 * x, 0.10, 0]);
    final upper = add('upperarm_$side', clavicle, [0.15 * x, 0, 0]);
    add('upperarm_correctiveRoot_$side', upper, [0, 0, 0]);
    add('upperarm_twist_01_$side', upper, [upperArm / 3 * x, 0, 0]);
    add('upperarm_twist_02_$side', upper, [upperArm * 2 / 3 * x, 0, 0]);
    // The forearm turns 10° forward about the vertical (the elbow behind).
    final lower = add('lowerarm_$side', upper, [upperArm * x, 0, 0], about([0, 1, 0], -10 * x));
    add('lowerarm_correctiveRoot_$side', lower, [0, 0, 0]);
    add('lowerarm_twist_02_$side', lower, [lowerArm / 3 * x, 0, 0]);
    add('lowerarm_twist_01_$side', lower, [lowerArm * 2 / 3 * x, 0, 0]);
    final hand = add('hand_$side', lower, [lowerArm * x, 0, 0]);
    add('index_metacarpal_$side', hand, [0.03 * x, 0, 0.01]);
    if (!legs) continue;
    final thigh = add('thigh_$side', pelvis, [0.10 * x, -0.05, 0]);
    add('thigh_twist_01_$side', thigh, [0, -0.15, 0]);
    add('thigh_correctiveRoot_$side', thigh, [0, 0, 0]);
    // The shin turns 5° back (the knee in front).
    final calf = add('calf_$side', thigh, [0, -0.45, 0], about([1, 0, 0], 5));
    add('calf_twist_01_$side', calf, [0, -0.2, 0]);
    final foot = add('foot_$side', calf, [0, -0.43, 0]);
    add('ball_$side', foot, [0, -0.05, 0.12]);
  }
  children.forEach((p, c) => nodes[p]['children'] = c);
  return {
    'nodes': nodes,
    'skins': [
      {'joints': List<int>.generate(nodes.length, (i) => i)},
    ],
  };
}

/// [metahumanSkeletonJson] as a skeleton.
GlbSkeleton metahumanSkeleton({double upperArm = 0.30, double lowerArm = 0.28, bool legs = true}) =>
    GlbSkeleton.fromJson(metahumanSkeletonJson(upperArm: upperArm, lowerArm: lowerArm, legs: legs));

/// A mesh render transform: the mesh at [at] (cm), glTF metres → cm, turned
/// by [rotation].
Matrix4 meshAt(Vector3 at, {Quaternion? rotation}) =>
    Matrix4.compose(at, rotation ?? Quaternion.identity(), Vector3.all(LuminaUnits.unitsPerMetre));

/// A pose authoring component on [rig], solving a pose array that starts at
/// the rest pose and keeps what the component writes (as a mesh that plays
/// nothing does).
class PoseRun {
  PoseRun(this.rig, {Matrix4? mesh}) : pose = rig.restPoseCopy() {
    component.setUp(rig);
    if (mesh != null) this.mesh.setFrom(mesh);
    // The mesh's first frame, before anything is set.
    tick();
  }

  final LuminaPoseRig rig;
  final LuminaPoseAuthoringComponent component = LuminaPoseAuthoringComponent();
  final Float64List pose;
  final Matrix4 mesh = meshAt(Vector3.zero());

  /// One frame.
  void tick([int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      component.modifyPose(pose, mesh, 1 / 60);
    }
  }

  /// World position of [bone] now (cm).
  Vector3 at(String bone) => rig.worldPositionOf(pose, mesh, bone);

  /// World rotation of [bone] now.
  Quaternion rotationOf(String bone) {
    final m = rig.worldTransformOf(pose, mesh, rig.slotNamed(bone));
    final r = Quaternion.identity();
    m.decompose(Vector3.zero(), r, Vector3.zero());
    return r..normalize();
  }

  /// Local rotation of [bone] in [pose].
  Quaternion localRotation(String bone) {
    final o = rig.slotNamed(bone) * 10;
    return Quaternion(pose[o + 3], pose[o + 4], pose[o + 5], pose[o + 6]);
  }
}

/// The angle between two rotations, in degrees.
double angleBetween(Quaternion a, Quaternion b) =>
    LuminaPoseQuat.angleOf(LuminaPoseQuat.qMul(LuminaPoseQuat.qConj(a), b)..normalize()) * 180 / math.pi;
