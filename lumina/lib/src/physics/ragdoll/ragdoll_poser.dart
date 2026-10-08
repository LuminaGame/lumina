import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';

/// Writes world-space bone frames (a ragdoll's bodies, a snapshot of them)
/// into a skeleton's local pose, blended with the pose already there.
///
/// Bones are visited parents first. A driven bone's world frame becomes
/// `lerp(animated, target, weight)` (positions lerped, rotations slerped,
/// the animated scale kept) and its local transform follows from its
/// parent's new world frame; every driven bone except the topmost keeps its
/// animated local translation, so bone lengths never stretch. Bones that
/// are not driven keep their local transforms and ride along.
class LuminaRagdollPoser {
  final LuminaRagdollSkeleton skeleton;

  /// The skeleton entry of each driven bone name.
  final Map<String, int> slots;

  /// Driven bones with a driven ancestor (they keep their local translation).
  final Set<int> _inner = {};

  final Float64List _animated;
  final Float64List _out;
  final Float64List _tmp = Float64List(12);

  LuminaRagdollPoser(this.skeleton, Iterable<String> bones)
      : slots = {
          for (final b in bones)
            if (skeleton.slotNamed(b) >= 0) b: skeleton.slotNamed(b),
        },
        _animated = Float64List(skeleton.length * 12),
        _out = Float64List(skeleton.length * 12) {
    final driven = slots.values.toSet();
    for (final s in driven) {
      for (var p = skeleton.parents[s]; p >= 0; p = skeleton.parents[p]) {
        if (driven.contains(p)) {
          _inner.add(s);
          break;
        }
      }
    }
  }

  /// The world affines of the pose given to the last [apply] / [frames] call.
  Float64List get animatedWorld => _animated;

  /// The world frames of the driven bones in [pose] under [meshAffine].
  Map<String, LuminaBoneFrame> frames(Float64List pose, Float64List meshAffine) {
    skeleton.world(pose, meshAffine, _animated);
    return {for (final e in slots.entries) e.key: LuminaRagdollSkeleton.frameOf(_animated, e.value)};
  }

  /// Blends [targets] into [pose] (in place) with [weight] in [0, 1].
  void apply(Float64List pose, Float64List meshAffine, Map<String, LuminaBoneFrame> targets, double weight) {
    skeleton.world(pose, meshAffine, _animated);
    if (weight <= 0) return;
    final w = weight.clamp(0.0, 1.0);
    final bySlot = <int, LuminaBoneFrame>{
      for (final e in slots.entries)
        if (targets[e.key] != null) e.value: targets[e.key]!,
    };
    final out = _out;
    final q = Float64List(4), qa = Float64List(4), qb = Float64List(4);
    for (var i = 0; i < skeleton.length; i++) {
      final target = bySlot[i];
      final p = skeleton.parents[i];
      if (target == null) {
        // Rides along: its parent's new world times its own local.
        LuminaPoseMath.composeTrs(pose, i * 10, _tmp, 0);
        if (p < 0) {
          LuminaPoseMath.multiplyAffine(meshAffine, 0, _tmp, 0, out, i * 12);
        } else {
          LuminaPoseMath.multiplyAffine(out, p * 12, _tmp, 0, out, i * 12);
        }
        continue;
      }
      final anim = LuminaRagdollSkeleton.frameOf(_animated, i);
      final scale = LuminaRagdollSkeleton.scaleOf(_animated, i);
      qa
        ..[0] = anim.rotation.x
        ..[1] = anim.rotation.y
        ..[2] = anim.rotation.z
        ..[3] = anim.rotation.w;
      qb
        ..[0] = target.rotation.x
        ..[1] = target.rotation.y
        ..[2] = target.rotation.z
        ..[3] = target.rotation.w;
      LuminaPoseMath.slerp(qa, 0, qb, 0, w, q, 0);
      final frame = (
        position: anim.position + (target.position - anim.position) * w,
        rotation: Quaternion(q[0], q[1], q[2], q[3]),
      );
      LuminaRagdollSkeleton.setFrame(out, i, frame, scale);
      final tx = pose[i * 10], ty = pose[i * 10 + 1], tz = pose[i * 10 + 2];
      skeleton.localFromWorld(out, i, meshAffine, pose);
      if (_inner.contains(i)) {
        pose[i * 10] = tx;
        pose[i * 10 + 1] = ty;
        pose[i * 10 + 2] = tz;
        // Its world frame moves with the kept translation.
        LuminaPoseMath.composeTrs(pose, i * 10, _tmp, 0);
        if (p < 0) {
          LuminaPoseMath.multiplyAffine(meshAffine, 0, _tmp, 0, out, i * 12);
        } else {
          LuminaPoseMath.multiplyAffine(out, p * 12, _tmp, 0, out, i * 12);
        }
      }
    }
  }
}
