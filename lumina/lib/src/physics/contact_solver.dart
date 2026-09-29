import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../components/collision/collision_component.dart';
import 'contact_generation.dart';
import 'rigid_body.dart';

/// One persistent contact point of a [LuminaContactManifold].
class LuminaContactPoint {
  /// World position, midway between the surfaces.
  final Vector3 point = Vector3.zero();

  /// [point] in A's frame relative to its centre of mass (for matching the
  /// point next step and warm starting it).
  final Vector3 localA = Vector3.zero();

  /// Penetration (negative: a gap inside the contact margin).
  double depth = 0.0;

  double normalImpulse = 0.0;
  double tangentImpulse1 = 0.0;
  double tangentImpulse2 = 0.0;
  double pseudoImpulse = 0.0;

  double normalMass = 0.0;
  double tangentMass1 = 0.0;
  double tangentMass2 = 0.0;
  double velocityBias = 0.0;

  /// Relative normal velocity before the solve (negative: approaching).
  double relativeVelocity = 0.0;

  /// The largest normal impulse of this step's passes.
  double maxNormalImpulse = 0.0;

  /// Whether the surfaces were not sliding at this point (static friction).
  bool sticking = true;

  final Vector3 rA = Vector3.zero();
  final Vector3 rB = Vector3.zero();

  /// Per direction (normal, tangent 1, tangent 2), 12 values: rA × d,
  /// rB × d, and their angular responses I⁻¹(r × d) for A and B.
  final Float64List jacobian = Float64List(36);
}

/// The contact of body [a] with body [b] or, when [b] is null, with the
/// static collider [componentB]: one normal (A → B) and up to four points,
/// kept between steps so the solver can warm start.
class LuminaContactManifold {
  final LuminaRigidBody a;
  final LuminaRigidBody? b;

  /// The colliding pieces: A's shape component and B's (a body shape or the
  /// static collider), for hit events.
  final LuminaCollisionComponent? componentA;
  final LuminaCollisionComponent? componentB;
  final String key;

  final Vector3 normal = Vector3.zero();
  final Vector3 tangent1 = Vector3.zero();
  final Vector3 tangent2 = Vector3.zero();
  final List<LuminaContactPoint> points = [];

  double friction = 0.7;
  double staticFriction = 0.7;
  double restitution = 0.1;

  /// Relative normal speed before the solve (positive: approaching).
  double approachSpeed = 0.0;

  /// Steps this pair has been touching (0 on the step it began).
  int age = 0;

  /// The step the manifold was last refreshed on.
  int lastStep = -1;

  LuminaContactManifold(this.a, this.b, this.componentA, this.componentB, this.key);

  /// The total normal impulse of the last solve (kg·cm/s).
  double get normalImpulse {
    var sum = 0.0;
    for (final p in points) {
      sum += p.normalImpulse;
    }
    return sum;
  }

  /// Takes [set]'s points, carrying the impulses of the points that match
  /// the previous step's (within [matchDistance] cm in A's frame).
  void update(LuminaContactSet set, double matchDistance) {
    final keep = normal.length2 > 0 && normal.dot(set.normal) > 0.95;
    final old = keep ? List<LuminaContactPoint>.of(points) : const <LuminaContactPoint>[];
    normal.setFrom(set.normal);
    _tangents();
    points.clear();
    final invRot = a.orientation.conjugated();
    for (var i = 0; i < set.points.length; i++) {
      final p = LuminaContactPoint();
      p.point.setFrom(set.points[i]);
      p.depth = set.depths[i];
      p.localA.setFrom(set.points[i] - a.position);
      p.localA.applyQuaternion(invRot);
      LuminaContactPoint? match;
      var best = matchDistance * matchDistance;
      for (final o in old) {
        final d = o.localA.distanceToSquared(p.localA);
        if (d < best) {
          best = d;
          match = o;
        }
      }
      if (match != null) {
        p.normalImpulse = match.normalImpulse;
        p.tangentImpulse1 = match.tangentImpulse1;
        p.tangentImpulse2 = match.tangentImpulse2;
        p.sticking = match.sticking;
        old.remove(match);
      }
      points.add(p);
    }
  }

  void _tangents() {
    final n = normal;
    if (n.x.abs() >= 0.57735) {
      tangent1.setValues(n.y, -n.x, 0.0);
    } else {
      tangent1.setValues(0.0, n.z, -n.y);
    }
    tangent1.normalize();
    tangent2.setFrom(n.cross(tangent1));
  }
}

/// Sequential-impulse contact solver with warm starting, Coulomb friction
/// (static / dynamic), restitution and split-impulse position correction
/// Bodies without a partner ([LuminaContactManifold.b]
/// null) touch an immovable collider; a sleeping body is immovable too.
class LuminaContactSolver {
  double restitutionThreshold = 100.0;
  double linearSlop = 0.25;
  double baumgarte = 0.3;
  double staticFrictionSpeed = 2.0;

  final List<LuminaContactManifold> manifolds = [];

  // Per-manifold linear responses (inverse mass × lock factor), A then B.
  final List<Float64List> _linear = [];

  static final Float64List _none = Float64List(3);
  static final Float64List _scratch = Float64List(12);

  static Float64List _dir(LuminaContactManifold m, int k) =>
      k == 0 ? m.normal.storage : (k == 1 ? m.tangent1.storage : m.tangent2.storage);

  /// Relative velocity of B against A along direction [k] at [p].
  static double _relative(LuminaRigidBody a, LuminaRigidBody? b, Float64List d, Float64List j, int o,
      {bool pseudo = false}) {
    var v = 0.0;
    if (b != null && b.isAwake) {
      final lv = (pseudo ? b.pseudoLinearVelocity : b.linearVelocity).storage;
      final av = (pseudo ? b.pseudoAngularVelocity : b.angularVelocity).storage;
      v += d[0] * lv[0] + d[1] * lv[1] + d[2] * lv[2] + av[0] * j[o + 3] + av[1] * j[o + 4] + av[2] * j[o + 5];
    }
    if (a.isAwake) {
      final lv = (pseudo ? a.pseudoLinearVelocity : a.linearVelocity).storage;
      final av = (pseudo ? a.pseudoAngularVelocity : a.angularVelocity).storage;
      v -= d[0] * lv[0] + d[1] * lv[1] + d[2] * lv[2] + av[0] * j[o] + av[1] * j[o + 1] + av[2] * j[o + 2];
    }
    return v;
  }

  /// Applies [lambda] along direction [d]: −to A, +to B.
  static void _applyImpulse(LuminaRigidBody a, LuminaRigidBody? b, Float64List la, Float64List lb, Float64List d,
      Float64List j, int o, double lambda,
      {bool pseudo = false}) {
    if (a.isAwake) {
      final lv = (pseudo ? a.pseudoLinearVelocity : a.linearVelocity).storage;
      final av = (pseudo ? a.pseudoAngularVelocity : a.angularVelocity).storage;
      lv[0] -= la[0] * d[0] * lambda;
      lv[1] -= la[1] * d[1] * lambda;
      lv[2] -= la[2] * d[2] * lambda;
      av[0] -= j[o + 6] * lambda;
      av[1] -= j[o + 7] * lambda;
      av[2] -= j[o + 8] * lambda;
    }
    if (b != null && b.isAwake) {
      final lv = (pseudo ? b.pseudoLinearVelocity : b.linearVelocity).storage;
      final av = (pseudo ? b.pseudoAngularVelocity : b.angularVelocity).storage;
      lv[0] += lb[0] * d[0] * lambda;
      lv[1] += lb[1] * d[1] * lambda;
      lv[2] += lb[2] * d[2] * lambda;
      av[0] += j[o + 9] * lambda;
      av[1] += j[o + 10] * lambda;
      av[2] += j[o + 11] * lambda;
    }
  }

  static Float64List _linearOf(LuminaRigidBody? b) {
    if (b == null || !b.isAwake) return _none;
    final f = b.linearFactor;
    return Float64List.fromList([b.inverseMass * f.x, b.inverseMass * f.y, b.inverseMass * f.z]);
  }

  static void _angular(LuminaRigidBody? b, double rx, double ry, double rz, Float64List d, Float64List j, int o) {
    // r × d
    final cx = ry * d[2] - rz * d[1], cy = rz * d[0] - rx * d[2], cz = rx * d[1] - ry * d[0];
    j[o] = cx;
    j[o + 1] = cy;
    j[o + 2] = cz;
    if (b == null || !b.isAwake) {
      j[o + 6] = 0.0;
      j[o + 7] = 0.0;
      j[o + 8] = 0.0;
      return;
    }
    final m = b.inverseInertiaWorld.storage;
    final f = b.angularFactor;
    j[o + 6] = (m[0] * cx + m[3] * cy + m[6] * cz) * f.x;
    j[o + 7] = (m[1] * cx + m[4] * cy + m[7] * cz) * f.y;
    j[o + 8] = (m[2] * cx + m[5] * cy + m[8] * cz) * f.z;
  }

  /// Masses, restitution targets and warm starting, once per step.
  void prepare(double dt) {
    _linear.clear();
    for (final m in manifolds) {
      final a = m.a, b = m.b;
      final la = _linearOf(a), lb = _linearOf(b);
      _linear
        ..add(la)
        ..add(lb);
      m.approachSpeed = 0.0;
      for (final p in m.points) {
        p.rA.setFrom(p.point - a.position);
        if (b == null) {
          p.rB.setZero();
        } else {
          p.rB.setFrom(p.point - b.position);
        }
        final j = p.jacobian;
        final ra = p.rA.storage, rb = p.rB.storage;
        for (var k = 0; k < 3; k++) {
          final d = _dir(m, k);
          final o = k * 12;
          _angular(a, ra[0], ra[1], ra[2], d, j, o);
          // B's terms live at o + 3 (r × d) and o + 9 (response).
          final tmp = _scratch;
          _angular(b, rb[0], rb[1], rb[2], d, tmp, 0);
          j[o + 3] = tmp[0];
          j[o + 4] = tmp[1];
          j[o + 5] = tmp[2];
          j[o + 9] = tmp[6];
          j[o + 10] = tmp[7];
          j[o + 11] = tmp[8];
          final kk = d[0] * d[0] * (la[0] + lb[0]) +
              d[1] * d[1] * (la[1] + lb[1]) +
              d[2] * d[2] * (la[2] + lb[2]) +
              j[o] * j[o + 6] +
              j[o + 1] * j[o + 7] +
              j[o + 2] * j[o + 8] +
              j[o + 3] * j[o + 9] +
              j[o + 4] * j[o + 10] +
              j[o + 5] * j[o + 11];
          final mass = kk > 0 ? 1.0 / kk : 0.0;
          if (k == 0) {
            p.normalMass = mass;
          } else if (k == 1) {
            p.tangentMass1 = mass;
          } else {
            p.tangentMass2 = mass;
          }
        }
        final n = m.normal.storage;
        final vn = _relative(a, b, n, j, 0);
        final v1 = _relative(a, b, m.tangent1.storage, j, 12);
        final v2 = _relative(a, b, m.tangent2.storage, j, 24);
        if (-vn > m.approachSpeed) m.approachSpeed = -vn;
        p.sticking = math.sqrt(v1 * v1 + v2 * v2) < staticFrictionSpeed;
        // A gap: the bodies may close it this step, no more (speculative).
        p.velocityBias = p.depth < 0 ? p.depth / dt : 0.0;
        p.relativeVelocity = vn;
        p.maxNormalImpulse = 0.0;
        p.pseudoImpulse = 0.0;
        // Warm start with last step's impulses.
        _applyImpulse(a, b, la, lb, n, j, 0, p.normalImpulse);
        _applyImpulse(a, b, la, lb, m.tangent1.storage, j, 12, p.tangentImpulse1);
        _applyImpulse(a, b, la, lb, m.tangent2.storage, j, 24, p.tangentImpulse2);
      }
    }
  }

  /// One velocity pass over every contact: friction, then the normal.
  void solveVelocities() {
    for (var mi = 0; mi < manifolds.length; mi++) {
      final m = manifolds[mi];
      final a = m.a, b = m.b;
      final la = _linear[mi * 2], lb = _linear[mi * 2 + 1];
      final n = m.normal.storage, t1d = m.tangent1.storage, t2d = m.tangent2.storage;
      for (final p in m.points) {
        final j = p.jacobian;
        // Friction (a circular cone around the normal impulse).
        final mu = p.sticking ? m.staticFriction : m.friction;
        final maxFriction = mu * p.normalImpulse;
        final old1 = p.tangentImpulse1, old2 = p.tangentImpulse2;
        var t1 = old1 - _relative(a, b, t1d, j, 12) * p.tangentMass1;
        var t2 = old2 - _relative(a, b, t2d, j, 24) * p.tangentMass2;
        final len = math.sqrt(t1 * t1 + t2 * t2);
        if (len > maxFriction && len > 0) {
          t1 *= maxFriction / len;
          t2 *= maxFriction / len;
          p.sticking = false;
        }
        p.tangentImpulse1 = t1;
        p.tangentImpulse2 = t2;
        _applyImpulse(a, b, la, lb, t1d, j, 12, t1 - old1);
        _applyImpulse(a, b, la, lb, t2d, j, 24, t2 - old2);

        // Normal.
        final vn = _relative(a, b, n, j, 0);
        final lambda = -(vn - p.velocityBias) * p.normalMass;
        final newImpulse = math.max(p.normalImpulse + lambda, 0.0);
        final dn = newImpulse - p.normalImpulse;
        p.normalImpulse = newImpulse;
        if (newImpulse > p.maxNormalImpulse) p.maxNormalImpulse = newImpulse;
        _applyImpulse(a, b, la, lb, n, j, 0, dn);
      }
    }
  }

  /// After the velocity passes: points that were approaching faster than
  /// [restitutionThreshold] and did push leave at restitution × that speed.
  void applyRestitution() {
    for (var mi = 0; mi < manifolds.length; mi++) {
      final m = manifolds[mi];
      if (m.restitution <= 0) continue;
      final a = m.a, b = m.b;
      final la = _linear[mi * 2], lb = _linear[mi * 2 + 1];
      final n = m.normal.storage;
      for (final p in m.points) {
        if (p.relativeVelocity > -restitutionThreshold || p.maxNormalImpulse <= 0) continue;
        final vn = _relative(a, b, n, p.jacobian, 0);
        final lambda = -(vn + m.restitution * p.relativeVelocity) * p.normalMass;
        final newImpulse = math.max(p.normalImpulse + lambda, 0.0);
        final dn = newImpulse - p.normalImpulse;
        p.normalImpulse = newImpulse;
        _applyImpulse(a, b, la, lb, n, p.jacobian, 0, dn);
      }
    }
  }

  /// One split-impulse pass: pushes penetrating bodies apart through the
  /// pseudo velocities, which never become momentum.
  void solvePositions(double dt) {
    for (var mi = 0; mi < manifolds.length; mi++) {
      final m = manifolds[mi];
      final a = m.a, b = m.b;
      final la = _linear[mi * 2], lb = _linear[mi * 2 + 1];
      final n = m.normal.storage;
      for (final p in m.points) {
        final excess = p.depth - linearSlop;
        if (excess <= 0 && p.pseudoImpulse == 0) continue;
        final target = baumgarte * math.max(excess, 0.0) / dt;
        final vn = _relative(a, b, n, p.jacobian, 0, pseudo: true);
        final lambda = (target - vn) * p.normalMass;
        final newImpulse = math.max(p.pseudoImpulse + lambda, 0.0);
        final d = newImpulse - p.pseudoImpulse;
        p.pseudoImpulse = newImpulse;
        _applyImpulse(a, b, la, lb, n, p.jacobian, 0, d, pseudo: true);
      }
    }
  }
}
