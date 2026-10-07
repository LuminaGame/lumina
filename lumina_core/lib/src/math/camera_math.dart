import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Smoothly interpolates a double from [current] to [target] at [interpSpeed].
double fInterpTo(double current, double target, double deltaTime, double interpSpeed) {
  if (interpSpeed <= 0.0) {
    return target;
  }
  final delta = target - current;
  if (delta.abs() < 1e-6) {
    return target;
  }
  final step = delta * (deltaTime * interpSpeed).clamp(0.0, 1.0);
  return current + step;
}

/// Smoothly interpolates a [Vector3] from [current] to [target] at [interpSpeed].
Vector3 vInterpTo(Vector3 current, Vector3 target, double deltaTime, double interpSpeed, {Vector3? out}) {
  if (interpSpeed <= 0.0) {
    if (out != null) {
      out.setFrom(target);
      return out;
    }
    return target.clone();
  }
  final delta = target - current;
  if (delta.length2 < 1e-12) {
    if (out != null) {
      out.setFrom(target);
      return out;
    }
    return target.clone();
  }
  final step = delta * (deltaTime * interpSpeed).clamp(0.0, 1.0);
  if (out != null) {
    out.setFrom(current);
    out.add(step);
    return out;
  }
  return current + step;
}

/// Smoothly interpolates a [Quaternion] from [current] to [target] at [interpSpeed].
Quaternion rInterpTo(Quaternion current, Quaternion target, double deltaTime, double interpSpeed, {Quaternion? out}) {
  if (interpSpeed <= 0.0) {
    if (out != null) {
      out.setFrom(target);
      return out;
    }
    return target.clone();
  }
  final alpha = (deltaTime * interpSpeed).clamp(0.0, 1.0);
  if (alpha >= 1.0) {
    if (out != null) {
      out.setFrom(target);
      return out;
    }
    return target.clone();
  }
  if (alpha <= 0.0) {
    if (out != null) {
      out.setFrom(current);
      return out;
    }
    return current.clone();
  }

  double cosTheta = current.x * target.x + current.y * target.y + current.z * target.z + current.w * target.w;
  double endX = target.x;
  double endY = target.y;
  double endZ = target.z;
  double endW = target.w;

  if (cosTheta < 0.0) {
    endX = -endX;
    endY = -endY;
    endZ = -endZ;
    endW = -endW;
    cosTheta = -cosTheta;
  }

  final result = out ?? Quaternion(0, 0, 0, 1);

  if (cosTheta > 0.9995) {
    result.x = current.x + alpha * (endX - current.x);
    result.y = current.y + alpha * (endY - current.y);
    result.z = current.z + alpha * (endZ - current.z);
    result.w = current.w + alpha * (endW - current.w);
    result.normalize();
    return result;
  }

  final theta = math.acos(cosTheta.clamp(-1.0, 1.0));
  final sinTheta = math.sin(theta);
  final w1 = math.sin((1.0 - alpha) * theta) / sinTheta;
  final w2 = math.sin(alpha * theta) / sinTheta;

  result.x = current.x * w1 + endX * w2;
  result.y = current.y * w1 + endY * w2;
  result.z = current.z * w1 + endZ * w2;
  result.w = current.w * w1 + endW * w2;
  result.normalize();
  return result;
}

extension QuaternionEuler on Quaternion {
  /// This rotation as (pitch X, yaw Y, roll Z) in **radians**, in the
  /// control-rotation convention ([luminaQuaternionToControlRotation]).
  /// [setFromEulerAngles] is its exact inverse (the former
  /// pair read Z-up aerospace angles and rebuilt Y-up ones, so a yaw came
  /// back as a pitch).
  Vector3 get eulerAngles => luminaQuaternionToControlRotation(this)..scale(_deg2rad);

  /// Sets this quaternion from (pitch X, yaw Y, roll Z) in **radians**, as
  /// [luminaControlRotationToQuaternion] builds them.
  void setFromEulerAngles(Vector3 euler) =>
      luminaControlRotationToQuaternion(euler.x / _deg2rad, euler.y / _deg2rad, euler.z / _deg2rad, out: this);
}

const double _deg2rad = math.pi / 180.0;
final Vector3 _axisX = Vector3(1.0, 0.0, 0.0);
final Vector3 _axisY = Vector3(0.0, 1.0, 0.0);
final Vector3 _axisZ = Vector3(0.0, 0.0, 1.0);

/// Builds the rotation a control rotation (pitch / yaw / roll) describes.
///
/// [pitchDeg], [yawDeg] and [rollDeg] are **degrees**, the unit
/// `LuminaController.controlRotation` is kept in (`LuminaPlayerController`
/// clamps pitch to ±89.9). Positive yaw turns right, positive pitch looks up:
/// the result's forward (drawn −Z, `R(q)·(0, 0, −1)`) is
/// `(cos p·sin y, sin p, −cos p·cos y)`.
///
/// A rotation means what `Matrix4.compose` draws, so this is
/// `Ry(−yaw)·Rx(pitch)·Rz(−roll)`: yaw is the outermost factor, so pitch tilts
/// about the camera's own right axis — built the other way round (as
/// `setEuler` does), pitch would turn about world X and have no effect at all
/// while facing ±X.
Quaternion luminaControlRotationToQuaternion(
  double pitchDeg,
  double yawDeg,
  double rollDeg, {
  Quaternion? out,
}) {
  final yaw = Quaternion.axisAngle(_axisY, -yawDeg * _deg2rad);
  final pitch = Quaternion.axisAngle(_axisX, pitchDeg * _deg2rad);
  final roll = Quaternion.axisAngle(_axisZ, -rollDeg * _deg2rad);
  final result = out ?? Quaternion.identity();
  result.setFrom(yaw * pitch * roll);
  return result;
}

/// The control rotation (pitch X, yaw Y, roll Z, **degrees**) that
/// [luminaControlRotationToQuaternion] turns into [q]: its exact inverse
/// `q` is decomposed as `Ry(−yaw)·Rx(pitch)·Rz(−roll)`;
/// pitch stays within ±90°.
Vector3 luminaQuaternionToControlRotation(Quaternion q) {
  final m = q.asRotationMatrix();
  final pitch = math.asin((-m.entry(1, 2)).clamp(-1.0, 1.0));
  final double a;
  final double c;
  if (math.cos(pitch).abs() > 1e-9) {
    a = math.atan2(m.entry(0, 2), m.entry(2, 2));
    c = math.atan2(m.entry(1, 0), m.entry(1, 1));
  } else {
    // Looking straight up or down: fold roll into yaw.
    a = math.atan2(-m.entry(2, 0), m.entry(0, 0));
    c = 0.0;
  }
  const rad2deg = 180.0 / math.pi;
  return Vector3(pitch * rad2deg, -a * rad2deg, -c * rad2deg);
}
