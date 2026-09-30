import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../components/camera/camera_math.dart';

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
/// It is the control-rotation convention ([luminaControlRotationToQuaternion],
/// what the spring arm and the player camera manager build the view from), so
/// the camera, the pawn and a Blueprint's Get Forward Vector of the control
/// rotation always agree: positive yaw turns right, positive pitch looks up
/// (about the view's own right axis, whatever the yaw); the forward (drawn −Z)
/// is `(cos p·sin y, sin p, −cos p·cos y)`, the direction
/// `LuminaTemplateCharacter.onMove` walks at pitch 0.
Quaternion luminaPawnEulerToQuaternion(double pitchDeg, double yawDeg, double rollDeg) =>
    luminaControlRotationToQuaternion(pitchDeg, yawDeg, rollDeg);

/// The inverse of [luminaPawnEulerToQuaternion]: runtime Euler degrees
/// (pitch X, yaw Y, roll Z).
Vector3 luminaPawnQuaternionToEuler(Quaternion q) => luminaQuaternionToControlRotation(q);
