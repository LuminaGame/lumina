import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_core/src/physics_asset/physics_asset_data.dart';
import 'package:lumina_core/src/pose_search/glb_animation_sampler.dart';
import 'package:lumina_core/src/pose_search/pose_math.dart';

/// The rest pose of a skeleton in world units: every node's rotation and
/// position (cm) in the model's frame, from a skinned GLB.
class LuminaSkeletonRest {
  final List<String> names;
  final Int32List parents;
  final List<Quaternion> rotations;
  final List<Vector3> positions;

  LuminaSkeletonRest(this.names, this.parents, this.rotations, this.positions);

  /// [unitScale] world units per model unit (100: glTF metres → cm).
  factory LuminaSkeletonRest.fromSampler(LuminaGlbAnimationSampler sampler, {double unitScale = 100.0}) {
    final world = sampler.restWorld();
    final q = Float64List(4);
    final rotations = <Quaternion>[];
    final positions = <Vector3>[];
    for (var i = 0; i < sampler.nodeCount; i++) {
      final o = i * LuminaPoseMath.affineStride;
      LuminaPoseMath.affineRotation(world, o, q, 0);
      rotations.add(Quaternion(q[0], q[1], q[2], q[3]));
      positions.add(Vector3(world[o + 9], world[o + 10], world[o + 11])..scale(unitScale));
    }
    return LuminaSkeletonRest(sampler.nodeNames, sampler.parents, rotations, positions);
  }

  int indexOf(String name) => names.indexOf(name);

  /// The first of [candidates] the skeleton has, or -1.
  int find(List<String> candidates) {
    for (final c in candidates) {
      final i = names.indexOf(c);
      if (i >= 0) return i;
    }
    final lower = [for (final n in names) n.toLowerCase()];
    for (final c in candidates) {
      final i = lower.indexOf(c.toLowerCase());
      if (i >= 0) return i;
    }
    return -1;
  }

  bool isAncestor(int ancestor, int node) {
    for (var n = parents[node]; n >= 0; n = parents[n]) {
      if (n == ancestor) return true;
    }
    return false;
  }
}

/// The body roles a humanoid ragdoll gets, with the bone names they match
/// (UE / MetaHuman names first, then Mixamo).
enum _Role {
  pelvis(['pelvis', 'hips', 'mixamorig:Hips'], 0.145),
  spine(['spine_02', 'spine_01', 'spine1', 'mixamorig:Spine1', 'spine', 'mixamorig:Spine'], 0.12),
  chest(['spine_04', 'spine_03', 'spine2', 'mixamorig:Spine2', 'chest'], 0.17),
  head(['head', 'mixamorig:Head'], 0.07),
  upperArmL(['upperarm_l', 'leftarm', 'mixamorig:LeftArm'], 0.028),
  lowerArmL(['lowerarm_l', 'leftforearm', 'mixamorig:LeftForeArm'], 0.018),
  handL(['hand_l', 'lefthand', 'mixamorig:LeftHand'], 0.007),
  upperArmR(['upperarm_r', 'rightarm', 'mixamorig:RightArm'], 0.028),
  lowerArmR(['lowerarm_r', 'rightforearm', 'mixamorig:RightForeArm'], 0.018),
  handR(['hand_r', 'righthand', 'mixamorig:RightHand'], 0.007),
  thighL(['thigh_l', 'leftupleg', 'mixamorig:LeftUpLeg'], 0.11),
  calfL(['calf_l', 'leftleg', 'mixamorig:LeftLeg'], 0.048),
  footL(['foot_l', 'leftfoot', 'mixamorig:LeftFoot'], 0.014),
  thighR(['thigh_r', 'rightupleg', 'mixamorig:RightUpLeg'], 0.11),
  calfR(['calf_r', 'rightleg', 'mixamorig:RightLeg'], 0.048),
  footR(['foot_r', 'rightfoot', 'mixamorig:RightFoot'], 0.014);

  final List<String> names;
  final double massShare;
  const _Role(this.names, this.massShare);
}

/// Builds a humanoid physics asset from a skeleton's rest pose: bodies on the
/// main bones only (pelvis, two spine bodies, head, upper / lower arms,
/// hands, thighs, calves, feet; never twist, corrective, finger or IK bones),
/// capsules along each limb toward the next body, sized from the
/// character's height; ball joints with anatomical swing / twist limits,
/// hinges for the elbows and knees bending the right way (the character's
/// forward comes from its feet); body pairs that overlap at rest disabled.
abstract final class LuminaPhysicsAssetGenerator {
  static LuminaPhysicsAssetData fromSampler(LuminaGlbAnimationSampler sampler,
          {double totalMassKg = 80.0, double unitScale = 100.0}) =>
      fromSkeleton(LuminaSkeletonRest.fromSampler(sampler, unitScale: unitScale), totalMassKg: totalMassKg);

  static LuminaPhysicsAssetData fromSkeleton(LuminaSkeletonRest skeleton, {double totalMassKg = 80.0}) {
    final bones = <_Role, int>{};
    for (final role in _Role.values) {
      final i = skeleton.find(role.names);
      if (i >= 0) bones[role] = i;
    }
    final pelvis = bones[_Role.pelvis];
    if (pelvis == null) {
      throw StateError('the skeleton has no pelvis / hips bone; cannot generate a physics asset');
    }
    // Two spine bodies need two distinct bones in order pelvis < spine < chest.
    final spine = bones[_Role.spine], chest = bones[_Role.chest];
    if (spine != null && chest != null && (spine == chest || !skeleton.isAncestor(spine, chest))) bones.remove(_Role.spine);
    final p = skeleton.positions;
    Vector3 pos(_Role r) => p[bones[r]!];

    // Frame: up from the pelvis to the head, forward from the feet.
    final headIndex = bones[_Role.head];
    final up = headIndex == null ? Vector3(0, 1, 0) : (p[headIndex] - p[pelvis])
      ..normalize();
    final forward = _forward(skeleton, bones, up);
    final right = forward.cross(up)..normalize();
    var height = 180.0;
    if (headIndex != null) {
      var lowest = p[pelvis].dot(up);
      for (final r in [_Role.footL, _Role.footR]) {
        if (bones[r] != null) lowest = math.min(lowest, pos(r).dot(up));
      }
      // The head bone sits ~ 0.9 of the way up.
      height = math.max(50.0, (p[headIndex].dot(up) - lowest) / 0.9 + 4.0);
    }

    final data = LuminaPhysicsAssetData();
    final shares = <String, double>{};
    final segments = <String, (Vector3, Vector3, double)>{};

    void capsule(_Role role, Vector3 a, Vector3 b, double radius, {Vector3? hint}) {
      final bone = bones[role]!;
      final axis = b - a;
      final length = math.max(axis.length, 1e-3);
      final dir = axis.length > 1e-6 ? axis.normalized() : up.clone();
      final center = (a + b)..scale(0.5);
      final rotation = _rotationWithY(dir, hint ?? forward);
      _addBody(data, skeleton, bone, LuminaPhysicsBodyShape.capsule, center, rotation,
          radius: radius, halfHeight: math.max(length / 2 + radius, radius));
      shares[skeleton.names[bone]] = role.massShare;
      segments[skeleton.names[bone]] = (a, b, radius);
    }

    void sphere(_Role role, Vector3 center, double radius) {
      final bone = bones[role]!;
      _addBody(data, skeleton, bone, LuminaPhysicsBodyShape.sphere, center, Quaternion.identity(), radius: radius);
      shares[skeleton.names[bone]] = role.massShare;
      segments[skeleton.names[bone]] = (center, center, radius);
    }

    final h = height;
    // Torso: capsules across the body.
    final thighL = bones[_Role.thighL], thighR = bones[_Role.thighR];
    final hipHalf = thighL != null && thighR != null ? (p[thighL] - p[thighR]).dot(right).abs() / 2 : 0.06 * h;
    final pelvisCenter = p[pelvis] + up * (0.01 * h);
    final pr = 0.07 * h;
    capsule(_Role.pelvis, pelvisCenter - right * math.max(hipHalf - pr * 0.5, 1.0),
        pelvisCenter + right * math.max(hipHalf - pr * 0.5, 1.0), pr, hint: up);
    if (bones[_Role.spine] != null) {
      final c = pos(_Role.spine) + up * (0.02 * h);
      final r = 0.065 * h;
      capsule(_Role.spine, c - right * (0.05 * h), c + right * (0.05 * h), r, hint: up);
    }
    if (bones[_Role.chest] != null) {
      final c = pos(_Role.chest) + up * (0.035 * h) + forward * (0.01 * h);
      final r = 0.075 * h;
      capsule(_Role.chest, c - right * (0.06 * h), c + right * (0.06 * h), r, hint: up);
    }
    if (headIndex != null) sphere(_Role.head, p[headIndex] + up * (0.045 * h) + forward * (0.01 * h), 0.058 * h);

    for (final side in [
      (_Role.upperArmL, _Role.lowerArmL, _Role.handL),
      (_Role.upperArmR, _Role.lowerArmR, _Role.handR),
    ]) {
      final (upper, lower, hand) = side;
      if (bones[upper] == null || bones[lower] == null) continue;
      capsule(upper, pos(upper), pos(lower), 0.03 * h);
      if (bones[hand] != null) {
        capsule(lower, pos(lower), pos(hand), 0.026 * h);
        // A capsule from the wrist to the knuckles (a sphere would roll).
        final dir = (pos(hand) - pos(lower))..normalize();
        capsule(hand, pos(hand) + dir * (0.015 * h), pos(hand) + dir * (0.07 * h), 0.025 * h);
      }
    }
    for (final side in [
      (_Role.thighL, _Role.calfL, _Role.footL),
      (_Role.thighR, _Role.calfR, _Role.footR),
    ]) {
      final (thigh, calf, foot) = side;
      if (bones[thigh] == null || bones[calf] == null) continue;
      capsule(thigh, pos(thigh), pos(calf), 0.048 * h);
      if (bones[foot] != null) {
        capsule(calf, pos(calf), pos(foot), 0.036 * h);
        // The foot: from the heel to the toes, on the ground.
        // The ankle bone sits about 0.045 h above the sole.
        // A flat box from the heel to the toes (a capsule would roll).
        final half = Vector3(0.03 * h, 0.025 * h, 0.065 * h);
        final center = pos(foot) - up * (0.045 * h - half.y) + forward * (0.035 * h);
        final bone = bones[foot]!;
        _addBody(data, skeleton, bone, LuminaPhysicsBodyShape.box, center, fromAxes(right, up, forward),
            radius: half.y, halfExtents: half);
        shares[skeleton.names[bone]] = foot.massShare;
        segments[skeleton.names[bone]] = (center - forward * (half.z - half.y), center + forward * (half.z - half.y), half.y);
      }
    }

    final shareSum = shares.values.fold(0.0, (a, b) => a + b);
    for (final b in data.bodies) {
      b.massKg = totalMassKg * (shares[b.bone] ?? 0.0) / shareSum;
      b.linearDamping = 0.05;
      b.angularDamping = 0.6;
    }

    // Joints: every body to its nearest body ancestor.
    final bodyBones = {for (final b in data.bodies) skeleton.indexOf(b.bone)};
    _Role? roleOf(int bone) {
      for (final e in bones.entries) {
        if (e.value == bone) return e.key;
      }
      return null;
    }

    for (final body in data.bodies) {
      final child = skeleton.indexOf(body.bone);
      var parent = skeleton.parents[child];
      while (parent >= 0 && !bodyBones.contains(parent)) {
        parent = skeleton.parents[parent];
      }
      if (parent < 0) continue;
      final role = roleOf(child)!;
      // The twist axis: along the limb toward its next body.
      final next = _nextBodyPoint(role, bones, skeleton, up, forward);
      var twist = (next - p[child]);
      twist = twist.length > 1e-6 ? twist.normalized() : up.clone();
      final hinge = role == _Role.lowerArmL || role == _Role.lowerArmR || role == _Role.calfL || role == _Role.calfR;
      Quaternion frame;
      final c = LuminaPhysicsConstraintData(bodyA: skeleton.names[parent], bodyB: body.bone);
      if (hinge) {
        // Flexion: forearms bend forward, shins backward.
        final bendToward = role == _Role.calfL || role == _Role.calfR ? -forward : forward;
        var axis = twist.cross(bendToward);
        if (axis.length < 1e-6) axis = right.clone();
        axis.normalize();
        frame = _rotationWithX(axis, twist);
        c
          ..type = LuminaPhysicsJointType.hinge
          ..swing1Degrees = 0
          ..swing2Degrees = 0
          ..twistMinDegrees = -2
          ..twistMaxDegrees = 140
          ..twistDegrees = 140;
      } else {
        // Y across the body where that is not the twist axis, else forward.
        var y = right - twist * right.dot(twist);
        if (y.length < 0.3) y = forward - twist * forward.dot(twist);
        frame = _rotationWithX(twist, y.normalized());
        final (s1, s2, t) = switch (role) {
          _Role.spine || _Role.chest => (25.0, 25.0, 20.0),
          _Role.head => (40.0, 35.0, 50.0),
          _Role.upperArmL || _Role.upperArmR => (70.0, 80.0, 50.0),
          _Role.handL || _Role.handR => (50.0, 35.0, 25.0),
          _Role.thighL || _Role.thighR => (75.0, 35.0, 25.0),
          _Role.footL || _Role.footR => (30.0, 20.0, 10.0),
          _ => (30.0, 30.0, 20.0),
        };
        c
          ..swing1Degrees = s1
          ..swing2Degrees = s2
          ..twistDegrees = t;
      }
      // The frame in the child bone's frame.
      final local = skeleton.rotations[child].conjugated() * frame;
      c.frameRotationDegrees = LuminaPhysicsAssetData.quaternionToEuler(local).map(_round).toList();
      data.constraints.add(c);
    }

    // Pairs that touch at rest never collide (connected pairs never do).
    final names = segments.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final (a0, a1, ra) = segments[names[i]]!;
        final (b0, b1, rb) = segments[names[j]]!;
        if (_segmentDistance(a0, a1, b0, b1) < ra + rb + 1.0) data.disabledCollisionPairs.add([names[i], names[j]]);
      }
    }
    return data;
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  static Vector3 _forward(LuminaSkeletonRest s, Map<_Role, int> bones, Vector3 up) {
    final f = Vector3.zero();
    for (final (foot, ball) in [('foot_l', 'ball_l'), ('foot_r', 'ball_r'), ('LeftFoot', 'LeftToeBase'), ('RightFoot', 'RightToeBase'),
      ('mixamorig:LeftFoot', 'mixamorig:LeftToeBase'), ('mixamorig:RightFoot', 'mixamorig:RightToeBase')]) {
      final a = s.indexOf(foot), b = s.indexOf(ball);
      if (a >= 0 && b >= 0) f.add(s.positions[b] - s.positions[a]);
    }
    f.sub(up * f.dot(up));
    if (f.length < 1e-6) {
      // No toes: the glTF convention (+Z forward).
      f.setValues(0, 0, 1);
      f.sub(up * f.dot(up));
    }
    return f.normalized();
  }

  static Vector3 _nextBodyPoint(_Role role, Map<_Role, int> bones, LuminaSkeletonRest s, Vector3 up, Vector3 forward) {
    Vector3 at(_Role r) => bones[r] == null ? s.positions[bones[role]!] + up : s.positions[bones[r]!];
    final p = s.positions[bones[role]!];
    return switch (role) {
      _Role.spine => bones[_Role.chest] != null ? at(_Role.chest) : p + up,
      _Role.chest => bones[_Role.head] != null ? at(_Role.head) : p + up,
      _Role.head => p + up,
      _Role.upperArmL => at(_Role.lowerArmL),
      _Role.lowerArmL => at(_Role.handL),
      _Role.upperArmR => at(_Role.lowerArmR),
      _Role.lowerArmR => at(_Role.handR),
      _Role.handL => p + (at(_Role.handL) - at(_Role.lowerArmL)),
      _Role.handR => p + (at(_Role.handR) - at(_Role.lowerArmR)),
      _Role.thighL => at(_Role.calfL),
      _Role.calfL => at(_Role.footL),
      _Role.thighR => at(_Role.calfR),
      _Role.calfR => at(_Role.footR),
      _Role.footL || _Role.footR => p + forward,
      _Role.pelvis => p + up,
    };
  }

  static void _addBody(LuminaPhysicsAssetData data, LuminaSkeletonRest s, int bone, LuminaPhysicsBodyShape shape, Vector3 center,
      Quaternion rotation,
      {double radius = 10, double halfHeight = 20, Vector3? halfExtents}) {
    final boneRotation = s.rotations[bone];
    final inverse = boneRotation.conjugated();
    final offset = (center - s.positions[bone])..applyQuaternion(inverse);
    final local = inverse * rotation;
    data.bodies.add(LuminaPhysicsBodyData(
      bone: s.names[bone],
      shape: shape,
      radius: _round(radius),
      halfHeight: _round(halfHeight),
      halfExtents: (halfExtents == null ? [radius, radius, radius] : [halfExtents.x, halfExtents.y, halfExtents.z]).map(_round).toList(),
      offsetLocation: [offset.x, offset.y, offset.z].map(_round).toList(),
      offsetRotationDegrees: LuminaPhysicsAssetData.quaternionToEuler(local).map(_round).toList(),
    ));
  }

  /// A rotation whose local Y is [y] and whose local X is as close to
  /// [hint] × [y] as possible.
  static Quaternion _rotationWithY(Vector3 y, Vector3 hint) {
    var x = hint.cross(y);
    if (x.length < 1e-6) x = Vector3(1, 0, 0).cross(y);
    if (x.length < 1e-6) x = Vector3(0, 0, 1).cross(y);
    x.normalize();
    final z = x.cross(y)..normalize();
    return fromAxes(x, y, z);
  }

  /// A rotation whose local X is [x] and whose local Y is [y] made
  /// perpendicular to it.
  static Quaternion _rotationWithX(Vector3 x, Vector3 y) {
    final xn = x.normalized();
    var yn = y - xn * y.dot(xn);
    if (yn.length < 1e-6) yn = Vector3(0, 1, 0) - xn * xn.y;
    if (yn.length < 1e-6) yn = Vector3(0, 0, 1) - xn * xn.z;
    yn.normalize();
    final z = xn.cross(yn)..normalize();
    return fromAxes(xn, yn, z);
  }

  /// The rotation whose local axes are [x], [y], [z] (orthonormal).
  static Quaternion fromAxes(Vector3 x, Vector3 y, Vector3 z) {
    final q = Float64List(4);
    LuminaPoseMath.rotationToQuaternion(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, q, 0);
    return Quaternion(q[0], q[1], q[2], q[3]);
  }

  static double _segmentDistance(Vector3 p1, Vector3 q1, Vector3 p2, Vector3 q2) {
    final d1 = q1 - p1, d2 = q2 - p2, r = p1 - p2;
    final a = d1.dot(d1), e = d2.dot(d2), f = d2.dot(r);
    double s, t;
    if (a <= 1e-9 && e <= 1e-9) return r.length;
    if (a <= 1e-9) {
      s = 0;
      t = (f / e).clamp(0.0, 1.0);
    } else {
      final c = d1.dot(r);
      if (e <= 1e-9) {
        t = 0;
        s = (-c / a).clamp(0.0, 1.0);
      } else {
        final b = d1.dot(d2), denom = a * e - b * b;
        s = denom.abs() > 1e-9 ? ((b * f - c * e) / denom).clamp(0.0, 1.0) : 0.0;
        t = (b * s + f) / e;
        if (t < 0) {
          t = 0;
          s = (-c / a).clamp(0.0, 1.0);
        } else if (t > 1) {
          t = 1;
          s = ((b - c) / a).clamp(0.0, 1.0);
        }
      }
    }
    return ((p1 + d1 * s) - (p2 + d2 * t)).length;
  }
}
