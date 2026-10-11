import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/mesh/pose_authoring/pose_quat.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_rig.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_solve_state.dart';

typedef _Q = LuminaPoseQuat;

const double _deg = math.pi / 180;

/// What one limb is asked for, in the model frame: where its end goes (null
/// keeps it), the end's rotation (null: a hand keeps its local rotation, a
/// foot its model-space one), and a pole the middle joint bends towards.
typedef LuminaLimbGoal = ({Vector3? end, Quaternion? endRotation, Vector3? pole});

/// The pose authoring solvers. Each works on a [LuminaPoseSolveState] in
/// the model frame (the GLB's), changes local rotations only (the pelvis
/// solver also its translation), keeps bone lengths, and leaves the state's
/// frames current.
abstract final class LuminaPoseSolvers {
  /// Moves and turns the pelvis to [position] / [rotation] (either null to
  /// keep it).
  static void pelvis(LuminaPoseSolveState s, {Vector3? position, Quaternion? rotation}) {
    final slot = s.rig.pelvis;
    if (slot < 0 || (position == null && rotation == null)) return;
    if (position != null) s.setWorldPosition(slot, position);
    if (rotation != null) s.setWorldRotation(slot, rotation.normalized());
    s.forwardFrom(slot);
  }

  /// Bends the spine so its top (the chest point) reaches [target]: FABRIK
  /// on the joint positions with the spine's root fixed, each joint's bend
  /// limited to the rig's `spineBend` over its incoming pose, then the bone
  /// rotations re-derived from the new segment directions (lengths kept).
  static void spine(LuminaPoseSolveState s, Vector3 target, {int iterations = 12}) {
    final rig = s.rig;
    final bones = rig.spine;
    if (bones.isEmpty || rig.spineTip < 0) return;
    final n = bones.length;
    final p = [for (final b in bones) s.pos[b].clone(), s.pos[rig.spineTip].clone()];
    final len = [for (var k = 0; k < n; k++) (p[k + 1] - p[k]).length];
    final oldDir = [for (var k = 0; k < n; k++) (p[k + 1] - p[k]).normalized()];
    final total = len.fold(0.0, (a, b) => a + b);
    if (total < 1e-12) return;
    var t = target.clone();
    final reach = t - p[0];
    if (reach.length > total) t = p[0] + reach.normalized() * total;
    final limit = rig.limits.spineBend * _deg;
    final q = [for (final v in p) v.clone()];
    final turns = List<Quaternion>.generate(n, (_) => Quaternion.identity());
    final tolerance = total * 1e-6;
    for (var it = 0; it < iterations; it++) {
      // Tip to root.
      q[n].setFrom(t);
      for (var k = n - 1; k >= 0; k--) {
        final d = q[k] - q[k + 1];
        q[k] = q[k + 1] + (d.length2 < 1e-24 ? -oldDir[k] : d.normalized()) * len[k];
      }
      // Root to tip, limiting each joint's bend.
      q[0].setFrom(p[0]);
      var carried = Quaternion.identity();
      for (var k = 0; k < n; k++) {
        final ref = _Q.qRotate(carried, oldDir[k]);
        var d = q[k + 1] - q[k];
        d = d.length2 < 1e-24 ? ref.clone() : d.normalized();
        final angle = math.acos(ref.dot(d).clamp(-1.0, 1.0));
        if (angle > limit) {
          var axis = ref.cross(d);
          if (axis.length2 < 1e-20) axis = ref.cross(Vector3(1, 0, 0));
          d = _Q.qRotate(_Q.axisAngle(axis.normalized(), limit), ref);
        }
        carried = _Q.qMul(_Q.fromTo(ref, d), carried)..normalize();
        turns[k] = carried.clone();
        q[k + 1] = q[k] + d * len[k];
      }
      if ((q[n] - t).length < tolerance) break;
    }
    final old = [for (final b in bones) s.rot[b].clone()];
    for (var k = 0; k < n; k++) {
      s.setWorldRotation(bones[k], _Q.qMul(turns[k], old[k])..normalize());
      // The next bone's world frame follows its parent before it is set.
      if (k + 1 < n) _refresh(s, bones[k + 1]);
    }
    s.forwardFrom(bones.first);
  }

  /// Turns the neck chain so the head (its handle in front of the face) moves
  /// towards [target] on a sphere around the first neck bone: the turn's
  /// yaw (about the chest's up) and pitch are limited by the rig's neck
  /// limits and shared over the chain by its weights. [rotation] (the head
  /// bone's wanted model-space rotation) adds its roll about the facing
  /// direction.
  static void head(LuminaPoseSolveState s, {Vector3? target, Quaternion? rotation}) {
    final rig = s.rig;
    final chain = rig.neck;
    if (chain.isEmpty || (target == null && rotation == null)) return;
    final limits = rig.limits;
    final parent = rig.parents[chain.first];
    final parentRot = parent < 0 ? Quaternion.identity() : s.rot[parent];
    final up = _Q.qRotate(parentRot, rig.neckUpInParent)..normalize();
    final forward = _Q.qRotate(parentRot, rig.neckForwardInParent)..normalize();
    final pivot = s.pos[chain.first];
    var d0 = headHandle(s) - pivot;
    if (d0.length2 < 1e-20) d0 = up.clone();
    var yaw = 0.0, pitch = 0.0, roll = 0.0;
    if (target != null) {
      final d1 = target - pivot;
      if (d1.length2 > 1e-20) {
        yaw = _Q.signedAngle(d0, d1, up);
        pitch = math.asin(d1.normalized().dot(up).clamp(-1.0, 1.0)) - math.asin(d0.normalized().dot(up).clamp(-1.0, 1.0));
      }
    }
    yaw = yaw.clamp(-limits.neckYaw * _deg, limits.neckYaw * _deg);
    pitch = pitch.clamp(-limits.neckPitch * _deg, limits.neckPitch * _deg);
    final yawTurn = _Q.axisAngle(up, yaw);
    var flat = _Q.across(_Q.qRotate(yawTurn, d0), up);
    if (flat.length2 < 1e-20) flat = _Q.qRotate(yawTurn, forward);
    final pitchAxis = flat.normalized().cross(up)..normalize();
    final facing = _Q.qRotate(yawTurn, forward)..normalize();
    if (rotation != null) {
      final yp = _Q.qMul(_Q.axisAngle(pitchAxis, pitch), yawTurn);
      final residual = _Q.qMul(rotation.normalized(), _Q.qConj(_Q.qMul(yp, s.rot[chain.last])));
      roll = _Q.twistAngle(residual..normalize(), facing).clamp(-limits.neckRoll * _deg, limits.neckRoll * _deg);
    }
    final old = [for (final b in chain) s.rot[b].clone()];
    var share = 0.0;
    for (var i = 0; i < chain.length; i++) {
      share += rig.neckWeights[i];
      final turn = _Q.qMul(_Q.axisAngle(up, yaw * share),
          _Q.qMul(_Q.axisAngle(pitchAxis, pitch * share), _Q.axisAngle(facing, roll * share)));
      if (i > 0) _refresh(s, chain[i]);
      s.setWorldRotation(chain[i], _Q.qMul(turn, old[i])..normalize());
    }
    s.forwardFrom(chain.first);
  }

  /// Where the head handle is in [s] (model frame).
  static Vector3 headHandle(LuminaPoseSolveState s) {
    final h = s.rig.neck.last;
    return s.pos[h] + _Q.qRotate(s.rot[h], s.rig.headHandleOffset * s.scale[h]);
  }

  /// Two-bone IK on [limb]: the middle joint bends about its own hinge to
  /// the angle the law of cosines gives for the end's distance (clamped to
  /// the hinge limits and the shoulder / hip cone), the limb swings to the
  /// target, then turns about the root–end axis so the middle joint lies
  /// towards the pole. Twist bones share the end's and the upper bone's
  /// twist.
  static void limb(LuminaPoseSolveState s, LuminaPoseLimb limb, LuminaLimbGoal goal) {
    if (goal.end == null && goal.endRotation == null && goal.pole == null) return;
    final rig = s.rig;
    final limits = rig.limits;
    final isArm = limb.kind == LuminaPoseLimbKind.arm;
    final u = limb.upper, lo = limb.lower, e = limb.end;
    final a = s.pos[u].clone(), b = s.pos[lo].clone(), c = s.pos[e].clone();
    final upperLen = (b - a).length, lowerLen = (c - b).length;
    if (upperLen < 1e-12 || lowerLen < 1e-12) return;
    final oldUpperLocal = s.localR[u].clone();
    final oldEndLocal = s.localR[e].clone();
    final oldEndWorld = s.rot[e].clone();

    // The wanted direction, kept in the shoulder / hip cone.
    var dir = (goal.end ?? c) - a;
    if (dir.length2 < 1e-24) return;
    final parent = rig.parents[u];
    final coneAxis = parent < 0 ? limb.coneAxisInParent.clone() : _Q.qRotate(s.rot[parent], limb.coneAxisInParent)
      ..normalize();
    final cone = (isArm ? limits.shoulderCone : limits.hipCone) * _deg;
    final off = math.acos(coneAxis.dot(dir.normalized()).clamp(-1.0, 1.0));
    if (off > cone) {
      var axis = coneAxis.cross(dir);
      if (axis.length2 < 1e-20) axis = coneAxis.cross(Vector3(0, 1, 0));
      dir = _Q.qRotate(_Q.axisAngle(axis.normalized(), cone), coneAxis) * dir.length;
    }

    // 1. Bend the middle joint about its hinge.
    final minBend = (isArm ? limits.elbowMin : limits.kneeMin) * _deg;
    final maxBend = (isArm ? limits.elbowMax : limits.kneeMax) * _deg;
    double reachAt(double bend) =>
        math.sqrt(math.max(0.0, upperLen * upperLen + lowerLen * lowerLen + 2 * upperLen * lowerLen * math.cos(bend)));
    final reach = dir.length.clamp(reachAt(maxBend), reachAt(minBend) * (1 - 1e-9));
    final cosWanted = ((reach * reach - upperLen * upperLen - lowerLen * lowerLen) / (2 * upperLen * lowerLen)).clamp(-1.0, 1.0);
    final wantedBend = math.acos(cosWanted);
    final ud = (b - a) / upperLen, ld = (c - b) / lowerLen;
    final bend = math.acos(ud.dot(ld).clamp(-1.0, 1.0));
    var hinge = ud.cross(ld);
    if (hinge.length2 < 1e-10) {
      final hint = goal.pole != null ? _Q.across(goal.pole! - a, ud) : Vector3.zero();
      final h = hint.length2 > 1e-12 ? hint : _hintNow(s, limb);
      hinge = _Q.across(h, ud).cross(ud);
      if (hinge.length2 < 1e-20) hinge = ud.cross(Vector3(0, 0, 1));
    }
    hinge.normalize();
    final bendTurn = _Q.axisAngle(hinge, wantedBend - bend);
    s.turnWorld(lo, bendTurn);
    final c1 = b + _Q.qRotate(bendTurn, c - b);

    // 2. Swing the limb to the target; 3. turn it about the root–end axis
    // towards the pole.
    var swing = _Q.fromTo(c1 - a, dir);
    if (goal.pole != null) {
      final axis = dir.normalized();
      final elbow = _Q.qRotate(swing, b - a);
      final phi = _Q.signedAngle(elbow, goal.pole! - a, axis);
      swing = _Q.qMul(_Q.axisAngle(axis, phi), swing)..normalize();
    }
    s.turnWorld(u, swing);
    s.forwardFrom(u);

    // The end's rotation: the goal's; else a foot keeps its model-space
    // rotation and a hand its local one.
    if (goal.endRotation != null) {
      s.setWorldRotation(e, goal.endRotation!.normalized());
    } else if (!isArm) {
      s.setWorldRotation(e, oldEndWorld);
    }

    // Twist bones: the lower ones share the end's twist about the lower
    // bone, the upper ones hold back the upper bone's own twist.
    final lowerAxis = s.localT[e].normalized();
    if (limb.lowerTwist.isNotEmpty && lowerAxis.length2 > 0) {
      final change = _Q.qMul(s.localR[e], _Q.qConj(oldEndLocal))..normalize();
      final theta = _Q.twistAngle(change, lowerAxis);
      for (final (slot, at) in limb.lowerTwist) {
        s.localR[slot].setFrom(_Q.qMul(_Q.axisAngle(lowerAxis, theta * at), s.localR[slot])..normalize());
      }
    }
    final upperAxis = s.localT[lo].normalized();
    if (limb.upperTwist.isNotEmpty && upperAxis.length2 > 0) {
      final change = _Q.qMul(_Q.qConj(oldUpperLocal), s.localR[u])..normalize();
      final theta = _Q.twistAngle(change, upperAxis);
      for (final (slot, at) in limb.upperTwist) {
        s.localR[slot].setFrom(_Q.qMul(_Q.axisAngle(upperAxis, -theta * (1 - at)), s.localR[slot])..normalize());
      }
    }
    s.forwardFrom(u);
  }

  /// The middle joint's bend direction for a straight limb: the rest hint
  /// turned with the limb's parent bone.
  static Vector3 _hintNow(LuminaPoseSolveState s, LuminaPoseLimb limb) {
    final rig = s.rig;
    final parent = rig.parents[limb.upper];
    if (parent < 0) return limb.restBendHint.clone();
    final restRot = _restRotation(rig, parent);
    return _Q.qRotate(_Q.qMul(s.rot[parent], _Q.qConj(restRot)), limb.restBendHint);
  }

  static Quaternion _restRotation(LuminaPoseRig rig, int slot) {
    var r = Quaternion.identity();
    final chain = <int>[];
    for (var x = slot; x >= 0; x = rig.parents[x]) {
      chain.insert(0, x);
    }
    for (final x in chain) {
      final o = x * 10;
      r = _Q.qMul(r, Quaternion(rig.restPose[o + 3], rig.restPose[o + 4], rig.restPose[o + 5], rig.restPose[o + 6]));
    }
    return r..normalize();
  }

  /// Recomputes slot [slot]'s model-space frame from its parent's.
  static void _refresh(LuminaPoseSolveState s, int slot) {
    final p = s.rig.parents[slot];
    if (p < 0) return;
    s.pos[slot].setFrom(s.pos[p] + _Q.qRotate(s.rot[p], s.localT[slot] * s.scale[p]));
    s.rot[slot].setFrom(_Q.qMul(s.rot[p], s.localR[slot])..normalize());
    s.scale[slot] = s.scale[p] * s.localS[slot].x;
  }
}
