import 'dart:math' as math;

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/rigid_body.dart';

/// Torques: kg·cm²/s² → N·m.
const double _torqueScale = kJoltScale * kJoltScale;

/// A [LuminaPhysicsJoint] as a Jolt constraint. The joint's Dart fields stay
/// the source of truth: [sync] sends changed limits and friction and the
/// motor's target before every step.
///
/// A ball joint is a swing-twist constraint (twist about the joint frame's
/// X, `swing1` about Y as the plane cone, `swing2` about Z as the normal
/// cone); a hinge (or a ball whose cones are closed) is a hinge about X with
/// the twist range as its limits, clamped to contain 0.
class LuminaJoltJoint {
  LuminaJoltJoint._(this.joint, this.constraint, this.isHinge);

  final LuminaPhysicsJoint joint;
  final JoltConstraint constraint;
  final bool isHinge;
  double _swing1 = double.nan, _swing2 = double.nan, _twistMin = double.nan, _twistMax = double.nan;
  bool? _limits;
  double _friction = double.nan;
  bool _motorOn = false;

  /// Solver iterations of an island with joints.
  static int jointVelocitySteps = 20;
  static int jointPositionSteps = 10;

  /// Whether [joint] becomes a Jolt hinge.
  static bool hingeFor(LuminaPhysicsJoint j) =>
      j.kind == LuminaJointKind.hinge || (j.swing1 <= 1e-4 && j.swing2 <= 1e-4);

  /// Creates the constraint between Jolt bodies [a] and [b].
  static LuminaJoltJoint create(JoltWorld world, LuminaPhysicsJoint j, int a, int b) {
    Vector3 anchor(LuminaRigidBody body, Vector3 local) => (local - body.localCenterOfMass) * kJoltScale;
    Vector3 axis(Quaternion frame, Vector3 v) => v.clone()..applyQuaternion(frame);
    final x = Vector3(1, 0, 0), y = Vector3(0, 1, 0);
    final hinge = hingeFor(j);
    final JoltConstraint c;
    if (hinge) {
      c = world.addHinge(
        a,
        b,
        JoltHingeSettings(
          positionA: anchor(j.bodyA, j.localAnchorA),
          hingeAxisA: axis(j.localFrameA, x),
          normalAxisA: axis(j.localFrameA, y),
          positionB: anchor(j.bodyB, j.localAnchorB),
          hingeAxisB: axis(j.localFrameB, x),
          normalAxisB: axis(j.localFrameB, y),
        ),
      );
    } else {
      c = world.addSwingTwist(
        a,
        b,
        JoltSwingTwistSettings(
          positionA: anchor(j.bodyA, j.localAnchorA),
          twistAxisA: axis(j.localFrameA, x),
          planeAxisA: axis(j.localFrameA, y),
          positionB: anchor(j.bodyB, j.localAnchorB),
          twistAxisB: axis(j.localFrameB, x),
          planeAxisB: axis(j.localFrameB, y),
          normalHalfCone: math.pi,
          planeHalfCone: math.pi,
          twistMin: -math.pi,
          twistMax: math.pi,
        ),
      );
    }
    // Joint chains (ragdolls) need more iterations than resting contacts.
    c.setSolverSteps(velocity: jointVelocitySteps, position: jointPositionSteps);
    return LuminaJoltJoint._(j, c, hinge)..sync();
  }

  /// Sends what changed on [joint] since the last call.
  void sync() {
    final j = joint;
    if (j.limitsEnabled != _limits ||
        j.swing1 != _swing1 ||
        j.swing2 != _swing2 ||
        j.twistMin != _twistMin ||
        j.twistMax != _twistMax) {
      _limits = j.limitsEnabled;
      _swing1 = j.swing1;
      _swing2 = j.swing2;
      _twistMin = j.twistMin;
      _twistMax = j.twistMax;
      if (!j.limitsEnabled) {
        // A hinge reads min > max as "no limits"; a swing-twist opens fully.
        constraint.setLimits(
          normalHalfCone: math.pi,
          planeHalfCone: math.pi,
          twistMin: isHinge ? 1 : -math.pi,
          twistMax: isHinge ? -1 : math.pi,
        );
      } else {
        constraint.setLimits(
          normalHalfCone: j.swing2.clamp(0.0, math.pi),
          planeHalfCone: j.swing1.clamp(0.0, math.pi),
          twistMin: j.twistMin.clamp(-math.pi, math.pi),
          twistMax: j.twistMax.clamp(-math.pi, math.pi),
        );
      }
    }
    if (j.frictionTorque != _friction) {
      _friction = j.frictionTorque;
      constraint.maxFrictionTorque = j.frictionTorque * _torqueScale;
    }
    final on = j.motorEnabled && j.motorMaxTorque > 0;
    if (on) {
      // A critically damped spring toward the target, solved implicitly by
      // Jolt. Its frequency (Hz) is half the motor's rate (1/s): about as
      // stiff as the Dart solver's velocity drive (a light hand holds its
      // pose against gravity), still far below the 120 Hz step.
      constraint.setPositionMotor(
        j.motorTarget,
        frequency: j.motorRate / 2,
        damping: 1.0,
        maxTorque: j.motorMaxTorque * _torqueScale,
      );
    } else if (_motorOn) {
      constraint.setPositionMotor(Quaternion.identity(), frequency: 0, maxTorque: 0);
    }
    _motorOn = on;
  }
}
