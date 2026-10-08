import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/pose_search/glb_animation_sampler.dart';
import 'package:lumina_core/src/pose_search/pose_math.dart';
import 'package:lumina_core/src/pose_search/pose_search_builder.dart';

/// Samples a database clip frame as the pose a character shows: every
/// node's local TRS with the root's ground motion removed (the root stays at
/// the mesh origin facing the mesh's forward, so the capsule — not the clip —
/// moves the character), optionally mirrored across the character's
/// sagittal plane (left and right bones swapped).
class LuminaPoseSearchPoser {
  final LuminaPoseSearchRig rig;
  LuminaGlbAnimationSampler get sampler => rig.sampler;

  late final Float64List _restWorld = sampler.restWorld();
  late final Float64List _world = Float64List(sampler.nodeCount * LuminaPoseMath.affineStride);
  late final Float64List _mirroredWorld = Float64List(sampler.nodeCount * LuminaPoseMath.affineStride);
  late final Float64List _restRotations = _rotations(_restWorld);

  /// Nodes from the root down (the ones a mirror changes), in parent-first
  /// order, and a flag per node.
  late final List<int> _subtree = [for (final n in sampler.order) if (_inSubtree(n)) n];
  late final List<bool> _subtreeFlag = List<bool>.generate(sampler.nodeCount, _inSubtree);

  /// The yaw of the mesh's authored forward (0 = +Z).
  late final double _restYaw = -rig.schema.meshYawOffsetDegrees * math.pi / 180.0;

  LuminaPoseSearchPoser(this.rig);

  bool _inSubtree(int node) {
    var n = node;
    while (n >= 0) {
      if (n == rig.root) return true;
      n = sampler.parents[n];
    }
    return false;
  }

  Float64List _rotations(Float64List world) {
    final out = Float64List(sampler.nodeCount * 4);
    for (var i = 0; i < sampler.nodeCount; i++) {
      LuminaPoseMath.affineRotation(world, i * LuminaPoseMath.affineStride, out, i * 4);
    }
    return out;
  }

  final Float64List _a = Float64List(LuminaPoseMath.affineStride);
  final Float64List _b = Float64List(LuminaPoseMath.affineStride);
  final Float64List _c = Float64List(LuminaPoseMath.affineStride);

  /// The local pose of [clip] at [time] into [out] (`nodeCount * 10`), root
  /// motion removed, mirrored when [mirrored]. Returns the clip's ground
  /// frame at [time] (the root motion that was removed).
  LuminaGroundFrame pose(int clip, double time, bool mirrored, Float64List out) {
    sampler.sampleLocal(clip, time, out);
    sampler.world(out, _world);
    final root = rig.root;
    final ro = root * LuminaPoseMath.affineStride;
    final g = rig.groundOf(_world, ro);

    // New root world = Ry(rest − yaw) · T(−ground) · W.
    final dy = _restYaw - g.yaw;
    final c = math.cos(dy), s = math.sin(dy);
    // Ry as an affine (column-major): +Z goes toward +X for positive angles.
    _a.setAll(0, [c, 0, -s, 0, 1, 0, s, 0, c, 0, 0, 0]);
    _a[9] = -(c * g.x + s * g.z);
    _a[11] = -(-s * g.x + c * g.z);
    LuminaPoseMath.multiplyAffine(_a, 0, _world, ro, _b, 0);
    final parent = sampler.parents[root];
    if (parent >= 0) {
      LuminaPoseMath.invertAffine(_world, parent * LuminaPoseMath.affineStride, _a, 0);
      LuminaPoseMath.multiplyAffine(_a, 0, _b, 0, _c, 0);
      LuminaPoseMath.decomposeAffine(_c, 0, out, root * LuminaPoseMath.trsStride);
    } else {
      LuminaPoseMath.decomposeAffine(_b, 0, out, root * LuminaPoseMath.trsStride);
    }
    if (mirrored) {
      sampler.world(out, _world);
      _mirror(out);
    }
    return g;
  }

  final Float64List _q = Float64List(4);
  final Float64List _qr = Float64List(4);
  final Float64List _p = Float64List(3);
  final Float64List _trs = Float64List(LuminaPoseMath.trsStride);

  /// Reflects the quaternion at [q]/[o] across the sagittal plane into
  /// [out]: conjugated into the frame whose lateral axis is X, (x, −y, −z, w),
  /// conjugated back.
  void _reflectQuaternion(Float64List q, int o, Float64List out) {
    final half = -_restYaw / 2; // canonical = Ry(−restYaw)
    final yq = Float64List.fromList([0, math.sin(half), 0, math.cos(half)]);
    final yqi = Float64List.fromList([0, -math.sin(half), 0, math.cos(half)]);
    final t = Float64List(4);
    LuminaPoseMath.multiplyQuaternion(yq, 0, q, o, t, 0);
    LuminaPoseMath.multiplyQuaternion(t, 0, yqi, 0, t, 0);
    t[1] = -t[1];
    t[2] = -t[2];
    LuminaPoseMath.multiplyQuaternion(yqi, 0, t, 0, t, 0);
    LuminaPoseMath.multiplyQuaternion(t, 0, yq, 0, out, 0);
  }

  void _reflectPoint(double x, double y, double z, Float64List out) {
    final (cx, cz) = LuminaPoseMath.rotateYaw(x, z, -_restYaw);
    final (mx, mz) = LuminaPoseMath.rotateYaw(-cx, cz, _restYaw);
    out[0] = mx;
    out[1] = y;
    out[2] = mz;
  }

  void _mirror(Float64List out) {
    const as = LuminaPoseMath.affineStride;
    for (final i in _subtree) {
      final m = sampler.mirror[i];
      // R'_i = refl(R_m) · refl(Rrest_m)⁻¹ · Rrest_i
      LuminaPoseMath.affineRotation(_world, m * as, _q, 0);
      _reflectQuaternion(_q, 0, _qr);
      final restM = Float64List(4);
      _reflectQuaternion(_restRotations, m * 4, restM);
      restM[0] = -restM[0];
      restM[1] = -restM[1];
      restM[2] = -restM[2];
      LuminaPoseMath.multiplyQuaternion(_qr, 0, restM, 0, _q, 0);
      LuminaPoseMath.multiplyQuaternion(_q, 0, _restRotations, i * 4, _q, 0);
      _reflectPoint(_world[m * as + 9], _world[m * as + 10], _world[m * as + 11], _p);
      double len(int o) => math.sqrt(
          _world[m * as + o] * _world[m * as + o] + _world[m * as + o + 1] * _world[m * as + o + 1] + _world[m * as + o + 2] * _world[m * as + o + 2]);
      _trs.setAll(0, [_p[0], _p[1], _p[2], _q[0], _q[1], _q[2], _q[3], len(0), len(3), len(6)]);
      LuminaPoseMath.composeTrs(_trs, 0, _mirroredWorld, i * as);
    }
    for (final i in _subtree) {
      final parent = sampler.parents[i];
      if (parent < 0) {
        LuminaPoseMath.decomposeAffine(_mirroredWorld, i * as, out, i * LuminaPoseMath.trsStride);
        continue;
      }
      final parentWorld = _subtreeFlag[parent] ? _mirroredWorld : _world;
      LuminaPoseMath.invertAffine(parentWorld, parent * as, _a, 0);
      LuminaPoseMath.multiplyAffine(_a, 0, _mirroredWorld, i * as, _c, 0);
      LuminaPoseMath.decomposeAffine(_c, 0, out, i * LuminaPoseMath.trsStride);
    }
  }
}
