import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/rigid_body.dart';

/// What a [LuminaPhysicsJoint] allows between its bodies besides staying
/// pinned at the anchor: a ball-and-socket swings inside a cone and twists
/// in a range; a hinge only turns about its frame's X axis.
enum LuminaJointKind { ball, hinge }

Vector3 _rot(Quaternion q, Vector3 v) => v.clone()..applyQuaternion(q);

/// A joint between two rigid bodies (a ragdoll's bone connection): the
/// anchors stay together, and the rotation of [bodyB]'s joint frame relative
/// to [bodyA]'s is limited.
///
/// Frames: [localAnchorA] / [localFrameA] place the joint in [bodyA]'s frame
/// (its component's world frame, not the centre of mass), the same for B.
/// When the bodies are posed so that both joint frames coincide, the joint
/// is at rest. The relative rotation splits into swing (the X axis leaving
/// its rest direction, limited by an elliptical cone of [swing1] about Y and
/// [swing2] about Z) and twist (about X, between [twistMin] and [twistMax]).
/// Angles are radians.
///
/// A motor ([motorEnabled]) pulls the relative rotation toward
/// [motorTarget] (B's joint frame in A's joint frame) at [motorRate] 1/s,
/// with at most [motorMaxTorque] kg·cm²/s² — a powered ragdoll following an
/// animation.
class LuminaPhysicsJoint {
  final LuminaRigidBody bodyA;
  final LuminaRigidBody bodyB;
  final Vector3 localAnchorA;
  final Vector3 localAnchorB;
  final Quaternion localFrameA;
  final Quaternion localFrameB;

  LuminaJointKind kind;
  bool limitsEnabled;
  double swing1;
  double swing2;
  double twistMin;
  double twistMax;

  /// Whether the position passes also turn the bodies back inside the
  /// limits (the velocity rows correct a share of the error every step).
  bool angularPositionCorrection = false;

  /// A torque (kg·cm²/s²) that resists the bodies turning relative to each
  /// other (muscle tone: a ragdoll settles instead of rocking); 0 is free.
  double frictionTorque = 0.0;

  bool motorEnabled = false;
  Quaternion motorTarget = Quaternion.identity();
  double motorRate = 20.0;
  double motorMaxTorque = 0.0;

  /// A name for debugging (the child bone).
  final String name;

  LuminaPhysicsJoint({
    required this.bodyA,
    required this.bodyB,
    required Vector3 localAnchorA,
    required Vector3 localAnchorB,
    Quaternion? localFrameA,
    Quaternion? localFrameB,
    this.kind = LuminaJointKind.ball,
    this.limitsEnabled = true,
    this.swing1 = math.pi / 4,
    this.swing2 = math.pi / 4,
    this.twistMin = -math.pi / 6,
    this.twistMax = math.pi / 6,
    this.name = '',
  })  : localAnchorA = localAnchorA.clone(),
        localAnchorB = localAnchorB.clone(),
        localFrameA = (localFrameA ?? Quaternion.identity()).normalized(),
        localFrameB = (localFrameB ?? Quaternion.identity()).normalized();

  /// A joint at world [anchor] with world joint frame [frame], for the bodies
  /// as they are posed now.
  factory LuminaPhysicsJoint.atWorld(
    LuminaRigidBody a,
    LuminaRigidBody b,
    Vector3 anchor,
    Quaternion frame, {
    LuminaJointKind kind = LuminaJointKind.ball,
    double swing1 = math.pi / 4,
    double swing2 = math.pi / 4,
    double twistMin = -math.pi / 6,
    double twistMax = math.pi / 6,
    bool limitsEnabled = true,
    String name = '',
  }) {
    final ia = a.orientation.conjugated(), ib = b.orientation.conjugated();
    return LuminaPhysicsJoint(
      bodyA: a,
      bodyB: b,
      localAnchorA: _rot(ia, anchor - a.origin),
      localAnchorB: _rot(ib, anchor - b.origin),
      localFrameA: ia * frame,
      localFrameB: ib * frame,
      kind: kind,
      swing1: swing1,
      swing2: swing2,
      twistMin: twistMin,
      twistMax: twistMax,
      limitsEnabled: limitsEnabled,
      name: name,
    );
  }

  // --- Geometry -----------------------------------------------------------------

  Vector3 worldAnchorA() => a.origin + _rot(a.orientation, localAnchorA);
  Vector3 worldAnchorB() => b.origin + _rot(b.orientation, localAnchorB);
  LuminaRigidBody get a => bodyA;
  LuminaRigidBody get b => bodyB;

  /// The distance between the two anchors now (cm).
  double get anchorError => (worldAnchorB() - worldAnchorA()).length;

  Quaternion worldFrameA() => (bodyA.orientation * localFrameA)..normalize();
  Quaternion worldFrameB() => (bodyB.orientation * localFrameB)..normalize();

  /// B's joint frame in A's joint frame.
  Quaternion relativeRotation() {
    final q = worldFrameA().conjugated() * worldFrameB();
    if (q.w < 0) q.setValues(-q.x, -q.y, -q.z, -q.w);
    return q..normalize();
  }

  /// The twist angle and the swing rotation vector (in A's joint frame; its X
  /// is ~0) of [relative].
  static (double, Vector3) swingTwist(Quaternion relative) {
    var q = relative;
    if (q.w < 0) q = Quaternion(-q.x, -q.y, -q.z, -q.w);
    final tl = math.sqrt(q.x * q.x + q.w * q.w);
    final twist = tl < 1e-9 ? Quaternion.identity() : Quaternion(q.x / tl, 0, 0, q.w / tl);
    var angle = 2 * math.atan2(twist.x, twist.w);
    if (angle > math.pi) angle -= 2 * math.pi;
    if (angle < -math.pi) angle += 2 * math.pi;
    final swing = q * twist.conjugated();
    if (swing.w < 0) swing.setValues(-swing.x, -swing.y, -swing.z, -swing.w);
    final s = math.sqrt(swing.x * swing.x + swing.y * swing.y + swing.z * swing.z);
    if (s < 1e-9) return (angle, Vector3.zero());
    final swingAngle = 2 * math.atan2(s, swing.w);
    return (angle, Vector3(swing.x, swing.y, swing.z)..scale(swingAngle / s));
  }

  /// The swing angle (rad) and twist angle (rad) now.
  (double, double) get angles {
    final (twist, swing) = swingTwist(relativeRotation());
    return (swing.length, twist);
  }

  // --- Solver state ----------------------------------------------------------------

  final Vector3 _rA = Vector3.zero(), _rB = Vector3.zero();
  final Matrix3 _pointMass = Matrix3.zero();
  final Vector3 _pointImpulse = Vector3.zero();
  double _beta = 0.0;
  final Vector3 _error = Vector3.zero();

  final List<_AngularRow> _rows = [];
  final Map<int, double> _warm = {};
  final Matrix3 _motorMass = Matrix3.zero();
  final Vector3 _motorImpulse = Vector3.zero();
  final Vector3 _motorVelocity = Vector3.zero();
  double _motorMaxImpulse = 0.0;
  bool _motorActive = false;
  final Vector3 _frictionImpulse = Vector3.zero();
  double _frictionMaxImpulse = 0.0;

  double _invMassA = 0.0, _invMassB = 0.0;
  Matrix3 _invIA = Matrix3.zero(), _invIB = Matrix3.zero();

  void _bodies() {
    final a = bodyA, b = bodyB;
    _invMassA = a.inverseMass;
    _invMassB = b.inverseMass;
    _invIA = a.inverseInertiaWorld;
    _invIB = b.inverseInertiaWorld;
    _rA.setFrom(worldAnchorA() - a.position);
    _rB.setFrom(worldAnchorB() - b.position);
  }

  static Matrix3 _skew(Vector3 r) => Matrix3(0, r.z, -r.y, -r.z, 0, r.x, r.y, -r.x, 0);

  /// The point constraint's mass matrix K (inverted into [out]).
  void _pointMatrix(Matrix3 out) {
    final sa = _skew(_rA), sb = _skew(_rB);
    final k = Matrix3.identity()..scale(_invMassA + _invMassB);
    k.sub(sa.multiplied(_invIA)..multiply(sa));
    k.sub(sb.multiplied(_invIB)..multiply(sb));
    out.setFrom(k);
    if (out.invert() == 0.0) out.setZero();
  }

  void _applyAngular(Vector3 impulse) {
    bodyA.angularVelocity.sub(_invIA.transformed(impulse)..multiply(bodyA.angularFactor));
    bodyB.angularVelocity.add(_invIB.transformed(impulse)..multiply(bodyB.angularFactor));
  }

  void _applyLinear(Vector3 p) {
    bodyA.linearVelocity.sub((p * _invMassA)..multiply(bodyA.linearFactor));
    bodyA.angularVelocity.sub(_invIA.transformed(_rA.cross(p))..multiply(bodyA.angularFactor));
    bodyB.linearVelocity.add((p * _invMassB)..multiply(bodyB.linearFactor));
    bodyB.angularVelocity.add(_invIB.transformed(_rB.cross(p))..multiply(bodyB.angularFactor));
  }

  double _angularMass(Vector3 n) {
    final k = n.dot(_invIA.transformed(n)) + n.dot(_invIB.transformed(n));
    return k > 1e-12 ? 1.0 / k : 0.0;
  }

  /// Builds this step's rows and applies last step's impulses (warm start).
  void prepare(double dt, {double baumgarte = 0.1, double warmStart = 0.8}) {
    _bodies();
    _pointMatrix(_pointMass);
    _error.setFrom((bodyB.position + _rB) - (bodyA.position + _rA));
    _beta = baumgarte / dt;
    _pointImpulse.scale(warmStart);
    _applyLinear(_pointImpulse);

    _rows.clear();
    if (limitsEnabled) _limitRows(dt);
    for (final r in _rows) {
      r.impulse = (_warm[r.key] ?? 0.0) * warmStart;
      if (r.impulse != 0.0) _applyAngular(r.axis * r.impulse);
    }
    _warm.clear();

    _motorActive = motorEnabled && motorMaxTorque > 0;
    _frictionMaxImpulse = frictionTorque * dt;
    _frictionImpulse.setZero();
    if (_motorActive || _frictionMaxImpulse > 0) {
      final k = _invIA.clone()..add(_invIB);
      _motorMass.setFrom(k);
      if (_motorMass.invert() == 0.0) _motorMass.setZero();
    }
    if (_motorActive) {
      final rel = relativeRotation();
      final delta = (motorTarget * rel.conjugated())..normalize();
      if (delta.w < 0) delta.setValues(-delta.x, -delta.y, -delta.z, -delta.w);
      final s = math.sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z);
      final angle = 2 * math.atan2(s, delta.w);
      final local = s < 1e-9 ? Vector3.zero() : (Vector3(delta.x, delta.y, delta.z)..scale(angle / s));
      _motorVelocity.setFrom(_rot(worldFrameA(), local)..scale(motorRate));
      _motorMaxImpulse = motorMaxTorque * dt;
      _motorImpulse.setZero();
    } else {
      _motorImpulse.setZero();
    }
  }

  void _limitRows(double dt) {
    final fa = worldFrameA();
    final (twist, swing) = swingTwist(relativeRotation());
    const margin = 0.1; // rad: rows engage a little before the limit.
    if (kind == LuminaJointKind.hinge || (swing1 <= 1e-4 && swing2 <= 1e-4)) {
      // Swing locked: two bilateral rows about A's Y and Z.
      final y = _rot(fa, Vector3(0, 1, 0)), z = _rot(fa, Vector3(0, 0, 1));
      _rows.add(_AngularRow(1, y, _angularMass(y), swing.y, dt, bilateral: true));
      _rows.add(_AngularRow(2, z, _angularMass(z), swing.z, dt, bilateral: true));
    } else {
      final angle = swing.length;
      if (angle > 1e-6) {
        final u = Vector3(0, swing.y, swing.z)..normalize();
        final l1 = math.max(swing1, 1e-4), l2 = math.max(swing2, 1e-4);
        final limit = 1.0 / math.sqrt((u.y / l1) * (u.y / l1) + (u.z / l2) * (u.z / l2));
        final e = angle - limit;
        if (e > -margin) {
          final n = _rot(fa, u);
          _rows.add(_AngularRow(3, n, _angularMass(n), e, dt));
        }
      }
    }
    final tAxis = _rot(worldFrameB(), Vector3(1, 0, 0));
    if (twist > twistMax - margin) {
      _rows.add(_AngularRow(4, tAxis, _angularMass(tAxis), twist - twistMax, dt));
    } else if (twist < twistMin + margin) {
      final n = -tAxis;
      _rows.add(_AngularRow(5, n, _angularMass(n), twistMin - twist, dt));
    }
  }

  /// One velocity pass: the motor, the angular limits, then the anchor.
  void solveVelocities() {
    final a = bodyA, b = bodyB;
    if (_motorActive) {
      final rel = b.angularVelocity - a.angularVelocity;
      final lambda = _motorMass.transformed(_motorVelocity - rel);
      final old = _motorImpulse.clone();
      _motorImpulse.add(lambda);
      final len = _motorImpulse.length;
      if (len > _motorMaxImpulse) _motorImpulse.scale(_motorMaxImpulse / len);
      _applyAngular(_motorImpulse - old);
    } else if (_frictionMaxImpulse > 0) {
      final rel = b.angularVelocity - a.angularVelocity;
      final old = _frictionImpulse.clone();
      _frictionImpulse.add(_motorMass.transformed(-rel));
      final len = _frictionImpulse.length;
      if (len > _frictionMaxImpulse) _frictionImpulse.scale(_frictionMaxImpulse / len);
      _applyAngular(_frictionImpulse - old);
    }
    for (final r in _rows) {
      final cdot = r.axis.dot(b.angularVelocity - a.angularVelocity);
      var lambda = -r.mass * (cdot - r.allowed);
      final old = r.impulse;
      if (r.bilateral) {
        r.impulse = old + lambda;
      } else {
        r.impulse = math.min(old + lambda, 0.0);
      }
      lambda = r.impulse - old;
      if (lambda != 0.0) _applyAngular(r.axis * lambda);
    }
    final vA = a.linearVelocity + a.angularVelocity.cross(_rA);
    final vB = b.linearVelocity + b.angularVelocity.cross(_rB);
    final cdot = (vB - vA)..add(_error * _beta);
    final p = _pointMass.transformed(-cdot);
    _pointImpulse.add(p);
    _applyLinear(p);
  }

  /// Keeps this step's impulses for the next step's warm start.
  void storeImpulses() {
    for (final r in _rows) {
      _warm[r.key] = r.impulse;
    }
  }

  /// One position pass after integration: pulls the anchors together and
  /// the angles back inside their limits by moving the bodies directly.
  /// Returns the anchor error before the pass (cm).
  double solvePosition({double maxCorrection = 20.0, double angularSlop = 0.005}) {
    _bodies();
    if (limitsEnabled && angularPositionCorrection) _solveAngularPosition(angularSlop);
    _bodies();
    final error = (bodyB.position + _rB) - (bodyA.position + _rA);
    final length = error.length;
    if (length > 1e-5) {
      final c = length > maxCorrection ? error * (maxCorrection / length) : error;
      final k = Matrix3.zero();
      _pointMatrix(k);
      final p = k.transformed(-c);
      _move(bodyA, -p * _invMassA, _invIA.transformed(_rA.cross(-p)));
      _move(bodyB, p * _invMassB, _invIB.transformed(_rB.cross(p)));
    }
    return length;
  }

  void _solveAngularPosition(double angularSlop) {
    final fa = worldFrameA();
    final (twist, swing) = swingTwist(relativeRotation());
    void rotate(Vector3 n, double e) {
      final m = _angularMass(n);
      if (m == 0.0) return;
      final j = -e * m;
      _move(bodyA, null, _invIA.transformed(n * -j));
      _move(bodyB, null, _invIB.transformed(n * j));
    }

    if (kind == LuminaJointKind.hinge || (swing1 <= 1e-4 && swing2 <= 1e-4)) {
      final sy = swing.y, sz = swing.z;
      if (sy.abs() > angularSlop) rotate(_rot(fa, Vector3(0, 1, 0)), sy - sy.sign * angularSlop);
      if (sz.abs() > angularSlop) rotate(_rot(fa, Vector3(0, 0, 1)), sz - sz.sign * angularSlop);
    } else {
      final angle = swing.length;
      if (angle > 1e-6) {
        final u = Vector3(0, swing.y, swing.z)..normalize();
        final l1 = math.max(swing1, 1e-4), l2 = math.max(swing2, 1e-4);
        final limit = 1.0 / math.sqrt((u.y / l1) * (u.y / l1) + (u.z / l2) * (u.z / l2));
        final e = angle - limit;
        if (e > angularSlop) rotate(_rot(fa, u), math.min(e - angularSlop, 0.2));
      }
    }
    final tAxis = _rot(worldFrameB(), Vector3(1, 0, 0));
    if (twist > twistMax + angularSlop) {
      rotate(tAxis, math.min(twist - twistMax - angularSlop, 0.2));
    } else if (twist < twistMin - angularSlop) {
      rotate(-tAxis, math.min(twistMin - twist - angularSlop, 0.2));
    }
  }

  static void _move(LuminaRigidBody body, Vector3? dp, Vector3 dTheta) {
    if (body.inverseMass == 0.0) return;
    if (dp != null) body.position.add(dp..multiply(body.linearFactor));
    dTheta.multiply(body.angularFactor);
    final angle = dTheta.length;
    if (angle > 1e-12) {
      body.orientation = (Quaternion.axisAngle(dTheta / angle, angle) * body.orientation)..normalize();
      body.updateInertia();
    }
  }
}

class _AngularRow {
  final int key;
  final Vector3 axis;
  final double mass;
  final bool bilateral;

  /// The relative angular velocity along [axis] the row allows: up to
  /// closing the gap to the limit this step while inside it, none past it.
  final double allowed;
  double impulse = 0.0;

  _AngularRow(this.key, this.axis, this.mass, double error, double dt, {this.bilateral = false})
      : allowed = bilateral
            ? -_angularBaumgarte * (error.abs() > _slop ? error - error.sign * _slop : 0.0) / dt
            : (error > 0 ? -_angularBaumgarte * math.max(0.0, error - _slop) / dt : -error / dt);

  /// The share of an angular error past [_slop] corrected per step by the
  /// velocity rows; within the slop nothing pushes (a joint resting on its
  /// limit does not creep).
  static const double _angularBaumgarte = 0.2;
  static const double _slop = 0.02;
}
