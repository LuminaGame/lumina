import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';

Vector3 _rot(Quaternion q, Vector3 v) => v.clone()..applyQuaternion(q);

/// How a get-up starts: the clip, and where the mesh goes (its world origin
/// on the ground and its yaw) so the clip's first frame lies where the
/// ragdoll lies.
class LuminaGetUpPlan {
  final String clip;
  final int clipIndex;
  final bool faceDown;

  /// The mesh's world yaw (radians about +Y) and origin (world units).
  final double yaw;
  final Vector3 origin;
  final double cost;

  const LuminaGetUpPlan(this.clip, this.clipIndex, this.faceDown, this.yaw, this.origin, this.cost);
}

class _ClipStart {
  final bool faceDown;
  final double axisYaw;
  final Vector3 pelvis;

  /// Key bone positions relative to the pelvis in the body-axis frame.
  final List<Vector3> keys;
  const _ClipStart(this.faceDown, this.axisYaw, this.pelvis, this.keys);
}

/// Gets a settled ragdoll back up: picks the get-up clip whose first frame
/// lies like the ragdoll (face down or face up by the pelvis's forward axis,
/// then the closest key-bone layout), places the mesh so that frame lies
/// where the ragdoll lies, and samples the clip on the CPU with its root
/// motion taken out (the mesh, and the character with it, follows the root
/// motion instead).
class LuminaRagdollGetUp {
  final LuminaGlbAnimationSampler sampler;
  final LuminaPoseSearchPoser poser;

  /// Every node of the mesh, parents first.
  final LuminaRagdollSkeleton skeleton;
  final double unitScale;
  final double _restYaw;
  final int pelvis;
  final int head;
  final List<int> _keyBones;

  /// The character's forward in the pelvis bone's frame.
  final Vector3 pelvisForward;

  final Float64List _samplerPose;
  final Float64List _world;
  final Map<int, _ClipStart> _starts = {};

  LuminaRagdollGetUp._(this.sampler, this.poser, this.skeleton, this.unitScale, this._restYaw, this.pelvis, this.head,
      this._keyBones, this.pelvisForward)
      : _samplerPose = Float64List(sampler.nodeCount * LuminaPoseMath.trsStride),
        _world = Float64List(skeleton.length * 12);

  /// [meshYawOffsetDegrees]: the mesh's authored forward turned to glTF +Z
  /// (as its pose search schema says); [pelvisBone] / [headBone] name the
  /// body axis.
  factory LuminaRagdollGetUp(LuminaGlbAnimationSampler sampler,
      {double meshYawOffsetDegrees = 0.0,
      double unitScale = LuminaUnits.unitsPerMetre,
      String pelvisBone = 'pelvis',
      String headBone = 'head'}) {
    final rig = LuminaPoseSearchRig(sampler, LuminaPoseSearchSchema(meshYawOffsetDegrees: meshYawOffsetDegrees));
    final skeleton = LuminaRagdollSkeleton(sampler, allNodes: true);
    final pelvis = skeleton.slotNamed(pelvisBone), head = skeleton.slotNamed(headBone);
    if (pelvis < 0 || head < 0) throw StateError('the mesh has no $pelvisBone / $headBone bone to get up with');
    // The authored forward (glTF +Z turned back by the yaw offset) in the
    // pelvis's rest frame.
    final rest = skeleton.restWorld(LuminaRagdollSkeleton.affineOf(Matrix4.identity()));
    final o = meshYawOffsetDegrees * math.pi / 180.0;
    final forward = Vector3(-math.sin(o), 0, math.cos(o));
    final pelvisRest = LuminaRagdollSkeleton.frameOf(rest, pelvis);
    final keys = [
      for (final n in const ['head', 'hand_l', 'hand_r', 'foot_l', 'foot_r', 'calf_l', 'calf_r', 'lowerarm_l', 'lowerarm_r'])
        if (skeleton.slotNamed(n) >= 0) skeleton.slotNamed(n),
    ];
    return LuminaRagdollGetUp._(sampler, LuminaPoseSearchPoser(rig), skeleton, unitScale, -o, pelvis, head, keys,
        _rot(pelvisRest.rotation.conjugated(), forward)..normalize());
  }

  /// Whether a pelvis at [pelvisFrame] faces the ground.
  bool isFaceDown(LuminaBoneFrame pelvisFrame) => _rot(pelvisFrame.rotation, pelvisForward).y < 0;

  /// Samples [clip] at [time] (root motion removed) into [pose], in
  /// [skeleton] order; returns the clip's ground frame then (model units).
  LuminaGroundFrame sample(int clip, double time, Float64List pose) {
    final g = poser.pose(clip, time, false, _samplerPose);
    for (var i = 0; i < skeleton.length; i++) {
      pose.setRange(i * 10, i * 10 + 10, _samplerPose, skeleton.nodes[i] * 10);
    }
    return g;
  }

  double duration(int clip) => sampler.clips[clip].duration;

  /// The heading of the body axis (pelvis → head) on the ground.
  static double axisYaw(Vector3 pelvis, Vector3 head) => math.atan2(head.x - pelvis.x, head.z - pelvis.z);

  _ClipStart _start(int clip) => _starts.putIfAbsent(clip, () {
        final pose = Float64List(skeleton.length * 10);
        sample(clip, 0.0, pose);
        skeleton.world(pose, LuminaRagdollSkeleton.affineOf(Matrix4.identity()), _world);
        final p = LuminaRagdollSkeleton.frameOf(_world, pelvis);
        final h = LuminaRagdollSkeleton.frameOf(_world, head);
        final yaw = axisYaw(p.position, h.position);
        return _ClipStart(isFaceDown(p), yaw, p.position..scale(unitScale), _keys(_world, p.position, yaw, unitScale));
      });

  List<Vector3> _keys(Float64List world, Vector3 pelvisScaled, double yaw, double scale) {
    final q = Quaternion.axisAngle(Vector3(0, 1, 0), -yaw);
    return [
      for (final k in _keyBones) _rot(q, LuminaRagdollSkeleton.frameOf(world, k).position..scale(scale)..sub(pelvisScaled)),
    ];
  }

  /// The plan for [candidates] (clip names; ones the mesh lacks are
  /// skipped) given the ragdoll's bone frames [bones] (needs the pelvis and
  /// head, by the names given at construction) on ground at [groundY].
  LuminaGetUpPlan? plan(Map<String, LuminaBoneFrame> bones, List<String> candidates, double groundY) {
    final pf = bones[skeleton.nodeNames[pelvis]], hf = bones[skeleton.nodeNames[head]];
    if (pf == null || hf == null) return null;
    final faceDown = isFaceDown(pf);
    final ragYaw = axisYaw(pf.position, hf.position);
    // The ragdoll's key bones in its body-axis frame, where known.
    final q = Quaternion.axisAngle(Vector3(0, 1, 0), -ragYaw);
    final ragKeys = <int, Vector3>{};
    for (var i = 0; i < _keyBones.length; i++) {
      final f = bones[skeleton.nodeNames[_keyBones[i]]];
      if (f != null) ragKeys[i] = _rot(q, f.position - pf.position);
    }
    LuminaGetUpPlan? best;
    for (final name in candidates) {
      final index = sampler.clipIndex(name);
      if (index == null) continue;
      final s = _start(index);
      var cost = s.faceDown == faceDown ? 0.0 : 1e6;
      for (final e in ragKeys.entries) {
        cost += (s.keys[e.key] - e.value).length;
      }
      if (best != null && cost >= best.cost) continue;
      final yaw = ragYaw - s.axisYaw;
      final offset = _rot(Quaternion.axisAngle(Vector3(0, 1, 0), yaw), s.pelvis);
      final origin = Vector3(pf.position.x - offset.x, groundY, pf.position.z - offset.z);
      best = LuminaGetUpPlan(name, index, faceDown, yaw, origin, cost);
    }
    return best;
  }

  /// The mesh's render transform [time] seconds into [plan]'s clip: its
  /// start placement moved by the clip's root motion since its first frame.
  Matrix4 meshTransformAt(LuminaGetUpPlan plan, LuminaGroundFrame start, LuminaGroundFrame now) {
    Matrix4 ground(LuminaGroundFrame g) => Matrix4.translationValues(g.x, 0, g.z)..rotateY(g.yaw - _restYaw);
    final w0 = Matrix4.translation(plan.origin)
      ..rotateY(plan.yaw)
      ..scaleByDouble(unitScale, unitScale, unitScale, 1.0);
    return w0..multiply(Matrix4.inverted(ground(start)))..multiply(ground(now));
  }
}
