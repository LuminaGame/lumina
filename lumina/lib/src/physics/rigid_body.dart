import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/physics/physical_material.dart';

/// One convex piece of a rigid body: [shape] posed in the body's frame by
/// [position] / [rotation], in world units. A box's half extents already
/// include the component scale; a convex hull is drawn ×[scale].
class LuminaBodyShape {
  final CollisionShape shape;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;

  /// The collision component this piece came from, if any.
  final LuminaCollisionComponent? component;

  /// This piece's world transform (with [scale]) at the current step.
  final Matrix4 worldTransform = Matrix4.identity();

  /// This piece's world bounds at the current step.
  final Aabb3 worldBounds = Aabb3();

  LuminaBodyShape(this.shape, {Vector3? position, Quaternion? rotation, Vector3? scale, this.component})
      : position = position?.clone() ?? Vector3.zero(),
        rotation = rotation?.clone() ?? Quaternion.identity(),
        scale = scale?.clone() ?? Vector3(1, 1, 1);

  /// Volume, centroid and unit inertia of this piece in its own frame.
  LuminaShapeMass get massProperties {
    final s = shape;
    if (s is BoxShape) return LuminaShapeMass.box(s.halfExtents);
    if (s is SphereShape) return LuminaShapeMass.sphere(s.radius);
    if (s is CapsuleShape) return LuminaShapeMass.capsule(s.radius, s.halfHeight);
    if (s is CylinderShape) return LuminaShapeMass.cylinder(s.radius, s.height);
    if (s is ConeShape) return LuminaShapeMass.cone(s.radius, s.height);
    if (s is ConvexHullShape) return LuminaShapeMass.convex(s, scale);
    return LuminaShapeMass.box(Vector3.all(10));
  }

  /// Updates [worldTransform] and [worldBounds] for a body frame at
  /// [origin] / [orientation].
  void updateWorld(Vector3 origin, Quaternion orientation) {
    final q = orientation * rotation;
    final p = origin + _rotate(orientation, position);
    worldTransform.setFromTranslationRotationScale(p, q, scale);
    _bounds(p, q);
  }

  void _bounds(Vector3 p, Quaternion q) {
    final s = shape;
    final m = q.asRotationMatrix();
    final st = m.storage;
    Vector3 ext;
    var center = p;
    if (s is SphereShape) {
      ext = Vector3.all(s.radius);
    } else if (s is BoxShape) {
      final h = s.halfExtents;
      ext = Vector3(
        st[0].abs() * h.x + st[3].abs() * h.y + st[6].abs() * h.z,
        st[1].abs() * h.x + st[4].abs() * h.y + st[7].abs() * h.z,
        st[2].abs() * h.x + st[5].abs() * h.y + st[8].abs() * h.z,
      );
    } else if (s is CapsuleShape) {
      final seg = math.max(0.0, s.halfHeight - s.radius);
      ext = Vector3(st[3].abs() * seg + s.radius, st[4].abs() * seg + s.radius, st[5].abs() * seg + s.radius);
    } else if (s is CylinderShape || s is ConeShape) {
      final r = s is CylinderShape ? s.radius : (s as ConeShape).radius;
      final hh = (s is CylinderShape ? s.height : (s as ConeShape).height) * 0.5;
      final u = Vector3(st[3], st[4], st[5]);
      ext = Vector3(
        u.x.abs() * hh + r * math.sqrt(math.max(0.0, 1 - u.x * u.x)),
        u.y.abs() * hh + r * math.sqrt(math.max(0.0, 1 - u.y * u.y)),
        u.z.abs() * hh + r * math.sqrt(math.max(0.0, 1 - u.z * u.z)),
      );
    } else if (s is ConvexHullShape) {
      final lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
      for (final v in s.vertices) {
        final w = worldTransform.transform3(v.clone());
        Vector3.min(lo, w, lo);
        Vector3.max(hi, w, hi);
      }
      worldBounds.min.setFrom(lo);
      worldBounds.max.setFrom(hi);
      return;
    } else {
      ext = Vector3.all(10);
    }
    center = p;
    worldBounds.min.setFrom(center - ext);
    worldBounds.max.setFrom(center + ext);
  }
}

Vector3 _rotate(Quaternion q, Vector3 v) => v.clone()..applyQuaternion(q);

/// A simulated rigid body (a primitive component while Simulate Physics is
/// on). Runtime frame: cm, kg, seconds, Y up.
///
/// The body's frame is its component's world frame; [position] is the centre
/// of mass in the world, [orientation] the frame's rotation. [LuminaPhysicsSubsystem]
/// integrates it; gameplay pushes it through [addImpulse] / [addForce] and friends.
class LuminaRigidBody {
  LuminaRigidBody({
    required this.id,
    required this.component,
    required this.shapes,
    required LuminaMassProperties massProperties,
    required Vector3 origin,
    required Quaternion rotation,
    this.material = LuminaPhysicalMaterial.standard,
  }) {
    setMassProperties(massProperties);
    orientation = rotation.normalized();
    position.setFrom(origin + _rotate(orientation, localCenterOfMass));
    previousPosition.setFrom(position);
    previousOrientation = orientation.clone();
    updateWorld();
  }

  /// Creation order in its subsystem: pairs are processed by it.
  final int id;

  /// The component this body drives (a collision or static mesh component).
  final LuminaSceneComponent component;
  final List<LuminaBodyShape> shapes;
  LuminaPhysicalMaterial material;

  double mass = 1.0;
  double inverseMass = 1.0;
  final Vector3 localCenterOfMass = Vector3.zero();
  final Matrix3 localInertia = Matrix3.identity();
  final Matrix3 _inverseLocalInertia = Matrix3.identity();

  /// World-frame inverse inertia at [orientation].
  final Matrix3 inverseInertiaWorld = Matrix3.identity();

  /// Centre of mass, world.
  final Vector3 position = Vector3.zero();
  Quaternion orientation = Quaternion.identity();
  final Vector3 linearVelocity = Vector3.zero();

  /// rad/s, world axes.
  final Vector3 angularVelocity = Vector3.zero();

  // Split-impulse position correction velocities (never kept between steps).
  final Vector3 pseudoLinearVelocity = Vector3.zero();
  final Vector3 pseudoAngularVelocity = Vector3.zero();

  final Vector3 previousPosition = Vector3.zero();
  Quaternion previousOrientation = Quaternion.identity();

  final Vector3 _force = Vector3.zero();
  final Vector3 _torque = Vector3.zero();

  double linearDamping = 0.01;
  double angularDamping = 0.0;
  bool enableGravity = true;

  /// 1 on a free axis, 0 on a locked one (runtime axes).
  final Vector3 linearFactor = Vector3(1, 1, 1);
  final Vector3 angularFactor = Vector3(1, 1, 1);

  bool _awake = true;
  double sleepTime = 0.0;

  /// Whether the solver moves it (a body not asleep).
  bool get isAwake => _awake;

  /// The world bounds of every shape at the current step.
  final Aabb3 bounds = Aabb3();

  /// Called when the body falls asleep (true) or wakes (false).
  void Function(LuminaRigidBody body, bool asleep)? onSleepChanged;

  void setMassProperties(LuminaMassProperties p) {
    mass = math.max(p.mass, 1e-4);
    inverseMass = 1.0 / mass;
    localCenterOfMass.setFrom(p.centerOfMass);
    localInertia.setFrom(p.inertia);
    // Keep the tensor invertible even for a degenerate shape.
    final st = localInertia.storage;
    final floor = mass * 1e-2;
    if (st[0] < floor) st[0] = floor;
    if (st[4] < floor) st[4] = floor;
    if (st[8] < floor) st[8] = floor;
    _inverseLocalInertia.setFrom(localInertia);
    if (_inverseLocalInertia.invert() == 0.0) {
      _inverseLocalInertia.setValues(1 / st[0], 0, 0, 0, 1 / st[4], 0, 0, 0, 1 / st[8]);
    }
    updateInertia();
  }

  /// The body frame's origin in the world (the component's world location).
  Vector3 get origin => position - _rotate(orientation, localCenterOfMass);

  /// Places the body frame at [origin] / [rotation], keeping the velocities.
  void setOriginTransform(Vector3 origin, Quaternion rotation) {
    orientation = rotation.normalized();
    position.setFrom(origin + _rotate(orientation, localCenterOfMass));
    previousPosition.setFrom(position);
    previousOrientation = orientation.clone();
    updateInertia();
    updateWorld();
  }

  void updateInertia() {
    final r = orientation.asRotationMatrix();
    inverseInertiaWorld
      ..setFrom(r)
      ..multiply(_inverseLocalInertia)
      ..multiply(r.transposed());
  }

  /// Refreshes every shape's world transform and [bounds].
  void updateWorld() {
    final o = origin;
    var first = true;
    for (final s in shapes) {
      s.updateWorld(o, orientation);
      if (first) {
        bounds.copyFrom(s.worldBounds);
        first = false;
      } else {
        bounds.hull(s.worldBounds);
      }
    }
  }

  /// The world velocity of the body's material point at [worldPoint].
  Vector3 velocityAt(Vector3 worldPoint) => linearVelocity + angularVelocity.cross(worldPoint - position);

  // --- Gameplay pushes --------------------------------------------------------

  /// Changes the momentum by [impulse] (kg·cm/s) through the centre of mass;
  /// [velocityChange] treats it as cm/s regardless of mass.
  void addImpulse(Vector3 impulse, {bool velocityChange = false}) {
    final dv = impulse * (velocityChange ? 1.0 : inverseMass);
    linearVelocity.add(dv..multiply(linearFactor));
    wake();
  }

  /// [impulse] (kg·cm/s) at [worldPoint]: it also spins the body.
  void addImpulseAtLocation(Vector3 impulse, Vector3 worldPoint) {
    applyImpulse(impulse, worldPoint - position);
    wake();
  }

  /// [impulse] at offset [r] from the centre of mass, without waking.
  void applyImpulse(Vector3 impulse, Vector3 r) {
    linearVelocity.add((impulse * inverseMass)..multiply(linearFactor));
    angularVelocity.add(inverseInertiaWorld.transformed(r.cross(impulse))..multiply(angularFactor));
  }

  /// A force (kg·cm/s²) applied over the next frame's steps; [accelChange]
  /// as cm/s².
  void addForce(Vector3 force, {bool accelChange = false}) {
    _force.add(accelChange ? force * mass : force);
    wake();
  }

  void addForceAtLocation(Vector3 force, Vector3 worldPoint) {
    _force.add(force);
    _torque.add((worldPoint - position).cross(force));
    wake();
  }

  /// A torque (kg·cm²/s²); [accelChange] as rad/s².
  void addTorque(Vector3 torque, {bool accelChange = false}) {
    _torque.add(accelChange ? localInertiaWorld().transformed(torque) : torque);
    wake();
  }

  /// An angular impulse (kg·cm²/s); [velocityChange] as rad/s.
  void addAngularImpulse(Vector3 impulse, {bool velocityChange = false}) {
    angularVelocity.add((velocityChange ? impulse.clone() : inverseInertiaWorld.transformed(impulse))..multiply(angularFactor));
    wake();
  }

  /// The world inertia (not inverted) at [orientation].
  Matrix3 localInertiaWorld() {
    final r = orientation.asRotationMatrix();
    return r.multiplied(localInertia)..multiply(r.transposed());
  }

  /// Integrates the accumulated forces and gravity into the velocities.
  void integrateForces(double dt, Vector3 gravity) {
    if (enableGravity) linearVelocity.add((gravity * dt)..multiply(linearFactor));
    linearVelocity.add((_force * (inverseMass * dt))..multiply(linearFactor));
    angularVelocity.add((inverseInertiaWorld.transformed(_torque) * dt)..multiply(angularFactor));
    // Damping: v /= 1 + c·dt.
    if (linearDamping > 0) linearVelocity.scale(1.0 / (1.0 + dt * linearDamping));
    if (angularDamping > 0) angularVelocity.scale(1.0 / (1.0 + dt * angularDamping));
  }

  /// Drops the forces added for this frame (after its last step).
  void clearForces() {
    _force.setZero();
    _torque.setZero();
  }

  /// Integrates the velocities (plus the split-impulse correction) into the
  /// pose and clears the correction.
  void integrateVelocities(double dt) {
    previousPosition.setFrom(position);
    previousOrientation = orientation.clone();
    position.add((linearVelocity + pseudoLinearVelocity) * dt);
    final w = angularVelocity + pseudoAngularVelocity;
    final angle = w.length * dt;
    if (angle > 1e-12) {
      final dq = Quaternion.axisAngle(w.normalized(), angle);
      orientation = (dq * orientation)..normalize();
    }
    pseudoLinearVelocity.setZero();
    pseudoAngularVelocity.setZero();
    updateInertia();
    updateWorld();
  }

  /// Puts the body in or out of the solver; waking resets its rest timer.
  void wake() {
    sleepTime = 0.0;
    if (_awake) return;
    _awake = true;
    onSleepChanged?.call(this, false);
  }

  void sleep() {
    if (!_awake) return;
    _awake = false;
    linearVelocity.setZero();
    angularVelocity.setZero();
    previousPosition.setFrom(position);
    previousOrientation = orientation.clone();
    onSleepChanged?.call(this, true);
  }

  /// The body frame's origin and rotation between the previous step and this
  /// one, [alpha] ∈ [0, 1] (render interpolation).
  (Vector3, Quaternion) interpolatedOrigin(double alpha) {
    final a = alpha.clamp(0.0, 1.0);
    final p = previousPosition + (position - previousPosition) * a;
    final q = _slerp(previousOrientation, orientation, a);
    return (p - _rotate(q, localCenterOfMass), q);
  }

  static Quaternion _slerp(Quaternion a, Quaternion b, double t) {
    var bx = b.x, by = b.y, bz = b.z, bw = b.w;
    var dot = a.x * bx + a.y * by + a.z * bz + a.w * bw;
    if (dot < 0) {
      dot = -dot;
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    // Close enough for a render step: normalised lerp.
    final q = Quaternion(a.x + (bx - a.x) * t, a.y + (by - a.y) * t, a.z + (bz - a.z) * t, a.w + (bw - a.w) * t);
    return q..normalize();
  }
}
