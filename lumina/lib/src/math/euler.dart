import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Rotating vectors the way Lumina means a rotation.
///
/// A rotation quaternion `q` on a component, an actor or a control rotation
/// means what `Matrix4.compose` draws: the standard `R(q)·v = q·v·q*`.
/// vector_math's `Quaternion.rotate` / `rotated` compute the *inverse*
/// (`q*·v·q`, and `rotate` also overwrites its argument), so engine
/// code never uses them for directions. Instead:
/// - [rotateVector] takes a vector from the rotated (local) frame to the
///   parent/world frame;
/// - [unrotateVector] takes it back (world → local).
/// Both return a new vector and leave the argument alone.
extension LuminaQuaternionRotation on Quaternion {
  /// `R(q)·v`: [v] expressed in this rotation's frame, turned into the outer
  /// frame — what the renderer does to a mesh's local axes.
  Vector3 rotateVector(Vector3 v) => v.clone()..applyQuaternion(this);

  /// `R(q)ᵀ·v`: the inverse of [rotateVector] (world → local).
  Vector3 unrotateVector(Vector3 v) => v.clone()..applyQuaternion(conjugated());
}

/// Converts editor Euler angles in degrees (pitch X, yaw Y, roll Z) into a
/// unit quaternion using the `Rz · Ry · Rx` composition the editor viewport,
/// Play-In-Editor and generated level code all share.
///
/// Built through a rotation matrix rather than quaternion multiplication so it
/// matches `Matrix4.rotationZ * rotationY * rotationX` exactly (vector_math's
/// `Quaternion.rotate` uses the opposite handedness from its matrices).
Quaternion luminaEulerDegreesToQuaternion(double xDeg, double yDeg, double zDeg) {
  final m = Matrix4.rotationZ(zDeg * math.pi / 180.0) *
      Matrix4.rotationY(yDeg * math.pi / 180.0) *
      Matrix4.rotationX(xDeg * math.pi / 180.0);
  return Quaternion.fromRotation(m.getRotation())..normalize();
}

/// Same as [luminaEulerDegreesToQuaternion] for a `[x, y, z]` list; missing
/// components default to 0.
Quaternion luminaEulerListToQuaternion(List<num>? euler) {
  double at(int i) => (euler != null && euler.length > i) ? euler[i].toDouble() : 0.0;
  return luminaEulerDegreesToQuaternion(at(0), at(1), at(2));
}

/// The pawn's actor-rotation convention: runtime Euler degrees (pitch X,
/// yaw Y, roll Z) to the quaternion `LuminaPawn.faceRotation` gives the actor.
///
/// Positive yaw turns right: the rotation's `forwardVector` (the drawn −Z) is
/// `(sin yaw, 0, −cos yaw)`, the direction `LuminaTemplateCharacter.onMove`
/// walks. It is the conjugate of `Quaternion.euler(yaw, pitch, roll)`: earlier
/// the engine read directions through `Quaternion.rotate` (the
/// inverse rotation) and built this quaternion without the conjugate; keeping
/// the conjugate here keeps every direction a control rotation produced —
/// pitch and roll included — exactly what it was, now drawn that way too.
/// The Blueprint function library uses the same pair, so a Blueprint's Get
/// Forward Vector is the pawn's own forward. (The spring arm's camera uses
/// `luminaControlRotationToQuaternion`, which tilts pitch about the camera's
/// own right axis.)
Quaternion luminaPawnEulerToQuaternion(double pitchDeg, double yawDeg, double rollDeg) {
  const d2r = math.pi / 180.0;
  return Quaternion.euler(yawDeg * d2r, pitchDeg * d2r, rollDeg * d2r)..conjugate();
}

/// The inverse of [luminaPawnEulerToQuaternion]: runtime Euler degrees
/// (pitch X, yaw Y, roll Z).
Vector3 luminaPawnQuaternionToEuler(Quaternion q) {
  const r2d = 180.0 / math.pi;
  // Undo the conjugate, then decompose Ry(yaw)·Rx(pitch)·Rz(roll).
  final m = q.conjugated().asRotationMatrix();
  final pitchRad = math.asin((-m.entry(1, 2)).clamp(-1.0, 1.0));
  double yawRad;
  double rollRad;
  if (math.cos(pitchRad).abs() > 1e-6) {
    rollRad = math.atan2(m.entry(1, 0), m.entry(1, 1));
    yawRad = math.atan2(m.entry(0, 2), m.entry(2, 2));
  } else {
    rollRad = 0.0;
    yawRad = math.atan2(-m.entry(2, 0), m.entry(0, 0));
  }
  return Vector3(pitchRad * r2d, yawRad * r2d, rollRad * r2d);
}
