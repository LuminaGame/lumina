import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/src/animation/motion_matching/spring_math.dart';

/// Inertialization of pose switches: at a switch the difference between the
/// pose shown so far and the new pose (per node: translation and rotation,
/// and their velocities) becomes an offset that decays to zero with a
/// critically damped spring, so the new animation takes over smoothly
/// without blending two poses.
///
/// Poses are flat TRS arrays (10 doubles per node: translation, rotation
/// quaternion x y z w, scale); velocities 6 doubles per node (linear then
/// angular, the angular one as a scaled angle-axis rate).
class LuminaInertializer {
  final int nodeCount;

  /// Seconds for an offset to halve.
  double halflife;

  final Float64List _offsetT;
  final Float64List _offsetV;
  final Float64List _offsetQ;
  final Float64List _offsetW;

  LuminaInertializer(this.nodeCount, {this.halflife = 0.05})
      : _offsetT = Float64List(nodeCount * 3),
        _offsetV = Float64List(nodeCount * 3),
        _offsetQ = _identityQuaternions(nodeCount),
        _offsetW = Float64List(nodeCount * 3);

  static Float64List _identityQuaternions(int n) {
    final q = Float64List(n * 4);
    for (var i = 0; i < n; i++) {
      q[i * 4 + 3] = 1.0;
    }
    return q;
  }

  /// The largest rotation offset now, in radians (0 when settled).
  double get maxRotationOffset {
    var m = 0.0;
    for (var i = 0; i < nodeCount; i++) {
      final w = _offsetQ[i * 4 + 3].abs().clamp(0.0, 1.0);
      m = math.max(m, 2 * math.acos(w));
    }
    return m;
  }

  /// The largest translation offset now.
  double get maxTranslationOffset {
    var m = 0.0;
    for (var i = 0; i < nodeCount; i++) {
      final x = _offsetT[i * 3], y = _offsetT[i * 3 + 1], z = _offsetT[i * 3 + 2];
      m = math.max(m, math.sqrt(x * x + y * y + z * z));
    }
    return m;
  }

  /// Drops every offset.
  void reset() {
    _offsetT.fillRange(0, _offsetT.length, 0.0);
    _offsetV.fillRange(0, _offsetV.length, 0.0);
    _offsetW.fillRange(0, _offsetW.length, 0.0);
    _offsetQ.setAll(0, _identityQuaternions(nodeCount));
  }

  /// A switch: the pose shown now is [shown] moving at [shownVelocity]; the
  /// new animation starts at [target] moving at [targetVelocity]. The
  /// offsets become their difference.
  void transition(Float64List shown, Float64List shownVelocity, Float64List target, Float64List targetVelocity) {
    for (var i = 0; i < nodeCount; i++) {
      final o = i * 10, v = i * 6;
      for (var k = 0; k < 3; k++) {
        _offsetT[i * 3 + k] = shown[o + k] - target[o + k];
        _offsetV[i * 3 + k] = shownVelocity[v + k] - targetVelocity[v + k];
        _offsetW[i * 3 + k] = shownVelocity[v + 3 + k] - targetVelocity[v + 3 + k];
      }
      // offsetQ = shown · target⁻¹ (shortest arc).
      final q = _mul(shown[o + 3], shown[o + 4], shown[o + 5], shown[o + 6], -target[o + 3], -target[o + 4],
          -target[o + 5], target[o + 6]);
      final s = q.$4 < 0 ? -1.0 : 1.0;
      _offsetQ[i * 4] = q.$1 * s;
      _offsetQ[i * 4 + 1] = q.$2 * s;
      _offsetQ[i * 4 + 2] = q.$3 * s;
      _offsetQ[i * 4 + 3] = q.$4 * s;
    }
  }

  /// Decays the offsets by [dt] and writes [target] with them applied into
  /// [out] (translation added, rotation pre-multiplied; scale from target).
  void update(double dt, Float64List target, Float64List out) {
    for (var i = 0; i < nodeCount; i++) {
      final o = i * 10;
      for (var k = 0; k < 3; k++) {
        final (x, v) = LuminaSpringMath.decaySpringDamper(_offsetT[i * 3 + k], _offsetV[i * 3 + k], halflife, dt);
        _offsetT[i * 3 + k] = x;
        _offsetV[i * 3 + k] = v;
        out[o + k] = target[o + k] + x;
      }
      // Rotation offset as a scaled angle-axis vector.
      final (ax, ay, az) = _toScaledAngleAxis(_offsetQ[i * 4], _offsetQ[i * 4 + 1], _offsetQ[i * 4 + 2], _offsetQ[i * 4 + 3]);
      final sa = [ax, ay, az];
      for (var k = 0; k < 3; k++) {
        final (x, v) = LuminaSpringMath.decaySpringDamper(sa[k], _offsetW[i * 3 + k], halflife, dt);
        sa[k] = x;
        _offsetW[i * 3 + k] = v;
      }
      final q = _fromScaledAngleAxis(sa[0], sa[1], sa[2]);
      _offsetQ[i * 4] = q.$1;
      _offsetQ[i * 4 + 1] = q.$2;
      _offsetQ[i * 4 + 2] = q.$3;
      _offsetQ[i * 4 + 3] = q.$4;
      final r = _mul(q.$1, q.$2, q.$3, q.$4, target[o + 3], target[o + 4], target[o + 5], target[o + 6]);
      out[o + 3] = r.$1;
      out[o + 4] = r.$2;
      out[o + 5] = r.$3;
      out[o + 6] = r.$4;
      out[o + 7] = target[o + 7];
      out[o + 8] = target[o + 8];
      out[o + 9] = target[o + 9];
    }
  }

  /// Per-node velocities (6 per node) of a pose going from [from] to [to]
  /// in [dt] seconds into [out].
  static void velocities(Float64List from, Float64List to, double dt, int nodeCount, Float64List out) {
    final inv = dt > 1e-9 ? 1.0 / dt : 0.0;
    for (var i = 0; i < nodeCount; i++) {
      final o = i * 10, v = i * 6;
      for (var k = 0; k < 3; k++) {
        out[v + k] = (to[o + k] - from[o + k]) * inv;
      }
      var q = _mul(to[o + 3], to[o + 4], to[o + 5], to[o + 6], -from[o + 3], -from[o + 4], -from[o + 5], from[o + 6]);
      if (q.$4 < 0) q = (-q.$1, -q.$2, -q.$3, -q.$4);
      final (ax, ay, az) = _toScaledAngleAxis(q.$1, q.$2, q.$3, q.$4);
      out[v + 3] = ax * inv;
      out[v + 4] = ay * inv;
      out[v + 5] = az * inv;
    }
  }

  static (double, double, double, double) _mul(
      double ax, double ay, double az, double aw, double bx, double by, double bz, double bw) {
    return (
      aw * bx + ax * bw + ay * bz - az * by,
      aw * by - ax * bz + ay * bw + az * bx,
      aw * bz + ax * by - ay * bx + az * bw,
      aw * bw - ax * bx - ay * by - az * bz,
    );
  }

  /// 2 · log(q): the rotation's axis times its angle.
  static (double, double, double) _toScaledAngleAxis(double x, double y, double z, double w) {
    final len = math.sqrt(x * x + y * y + z * z);
    if (len < 1e-9) return (2 * x, 2 * y, 2 * z);
    final angle = 2 * math.atan2(len, w);
    final k = angle / len;
    return (x * k, y * k, z * k);
  }

  static (double, double, double, double) _fromScaledAngleAxis(double x, double y, double z) {
    final angle = math.sqrt(x * x + y * y + z * z);
    if (angle < 1e-9) {
      final q = (x / 2, y / 2, z / 2, 1.0);
      final n = math.sqrt(q.$1 * q.$1 + q.$2 * q.$2 + q.$3 * q.$3 + 1.0);
      return (q.$1 / n, q.$2 / n, q.$3 / n, 1.0 / n);
    }
    final s = math.sin(angle / 2) / angle;
    return (x * s, y * s, z * s, math.cos(angle / 2));
  }
}
