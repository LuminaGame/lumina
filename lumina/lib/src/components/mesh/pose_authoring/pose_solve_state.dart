import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/mesh/pose_authoring/pose_quat.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_rig.dart';

typedef _Q = LuminaPoseQuat;

/// A pose of a [LuminaPoseRig] being solved: local TRS per slot and the
/// model-space frames they give (position, rotation, uniform scale). The
/// solvers change local rotations (and the pelvis's translation) and
/// call [forward] to refresh the frames.
class LuminaPoseSolveState {
  final LuminaPoseRig rig;
  final List<Vector3> localT;
  final List<Quaternion> localR;
  final List<Vector3> localS;
  final List<Vector3> pos;
  final List<Quaternion> rot;
  final Float64List scale;

  LuminaPoseSolveState(this.rig)
      : _subtreeEnd = _subtreeEnds(rig.parents),
        localT = List.generate(rig.length, (_) => Vector3.zero()),
        localR = List.generate(rig.length, (_) => Quaternion.identity()),
        localS = List.generate(rig.length, (_) => Vector3.all(1)),
        pos = List.generate(rig.length, (_) => Vector3.zero()),
        rot = List.generate(rig.length, (_) => Quaternion.identity()),
        scale = Float64List(rig.length);

  int get length => rig.length;

  /// Per slot, one past the last slot of its subtree (slots are in
  /// depth-first order, so a subtree is a run).
  final Int32List _subtreeEnd;

  static Int32List _subtreeEnds(Int32List parents) {
    final n = parents.length;
    final end = Int32List(n);
    for (var i = n - 1; i >= 0; i--) {
      var e = i + 1;
      while (e < n && _below(parents, e, i)) {
        e = end[e];
      }
      end[i] = e;
    }
    return end;
  }

  static bool _below(Int32List parents, int slot, int ancestor) {
    for (var p = parents[slot]; p >= 0; p = parents[p]) {
      if (p == ancestor) return true;
    }
    return false;
  }

  /// Reads the local TRS of [pose] (10 doubles per slot) and runs [forward].
  void load(Float64List pose) {
    for (var i = 0; i < length; i++) {
      final o = i * 10;
      localT[i].setValues(pose[o], pose[o + 1], pose[o + 2]);
      localR[i].setValues(pose[o + 3], pose[o + 4], pose[o + 5], pose[o + 6]);
      if (localR[i].length2 < 1e-20) {
        localR[i].setValues(0, 0, 0, 1);
      } else {
        localR[i].normalize();
      }
      localS[i].setValues(pose[o + 7], pose[o + 8], pose[o + 9]);
    }
    forward();
  }

  /// Writes the local TRS into [pose].
  void store(Float64List pose) {
    for (var i = 0; i < length; i++) {
      final o = i * 10;
      final t = localT[i], r = localR[i], s = localS[i];
      pose[o] = t.x;
      pose[o + 1] = t.y;
      pose[o + 2] = t.z;
      pose[o + 3] = r.x;
      pose[o + 4] = r.y;
      pose[o + 5] = r.z;
      pose[o + 6] = r.w;
      pose[o + 7] = s.x;
      pose[o + 8] = s.y;
      pose[o + 9] = s.z;
    }
  }

  /// Model-space frames of every slot from the local transforms.
  void forward() => _forward(0, length);

  /// Model-space frames of [slot] and everything below it.
  void forwardFrom(int slot) => _forward(slot, _subtreeEnd[slot]);

  void _forward(int from, int to) {
    final parents = rig.parents;
    for (var i = from; i < to; i++) {
      final p = parents[i];
      final t = localT[i], r = localR[i], out = pos[i], q = rot[i];
      if (p < 0) {
        out.setFrom(t);
        q.setFrom(r);
        scale[i] = localS[i].x;
        continue;
      }
      final pr = rot[p], pp = pos[p], sc = scale[p];
      // pos = parent + parentRotation · (t · parentScale), in place.
      final vx = t.x * sc, vy = t.y * sc, vz = t.z * sc;
      final ux = pr.x, uy = pr.y, uz = pr.z, w = pr.w;
      final cx = uy * vz - uz * vy, cy = uz * vx - ux * vz, cz = ux * vy - uy * vx;
      final dx = uy * cz - uz * cy, dy = uz * cx - ux * cz, dz = ux * cy - uy * cx;
      out.setValues(pp.x + vx + 2 * (w * cx + dx), pp.y + vy + 2 * (w * cy + dy), pp.z + vz + 2 * (w * cz + dz));
      // rot = parentRotation · local, in place.
      final x = w * r.x + ux * r.w + uy * r.z - uz * r.y;
      final y = w * r.y - ux * r.z + uy * r.w + uz * r.x;
      final z = w * r.z + ux * r.y - uy * r.x + uz * r.w;
      final ww = w * r.w - ux * r.x - uy * r.y - uz * r.z;
      q.setValues(x, y, z, ww);
      scale[i] = sc * localS[i].x;
    }
  }

  /// Gives slot [slot] the model-space rotation [world] (its local rotation
  /// relative to its parent's current frame). Frames below it are stale
  /// until [forward].
  void setWorldRotation(int slot, Quaternion world) {
    final p = rig.parents[slot];
    final local = p < 0 ? world.clone() : _Q.qMul(_Q.qConj(rot[p]), world);
    localR[slot].setFrom(local..normalize());
    final w = p < 0 ? localR[slot].clone() : _Q.qMul(rot[p], localR[slot]);
    rot[slot].setFrom(w..normalize());
  }

  /// Turns slot [slot] by [turn] in the model frame (`turn · rotation`).
  void turnWorld(int slot, Quaternion turn) => setWorldRotation(slot, _Q.qMul(turn, rot[slot])..normalize());

  /// Moves slot [slot] to the model-space position [world] (its local
  /// translation).
  void setWorldPosition(int slot, Vector3 world) {
    final p = rig.parents[slot];
    if (p < 0) {
      localT[slot].setFrom(world);
    } else {
      final s = scale[p] == 0 ? 1.0 : scale[p];
      localT[slot].setFrom(_Q.qRotate(_Q.qConj(rot[p]), world - pos[p]) / s);
    }
  }
}
