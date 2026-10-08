import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/box_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/collision/sphere_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/physical_material.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';
import 'package:lumina/src/physics/rigid_body.dart';

Vector3 _rot(Quaternion q, Vector3 v) => v.clone()..applyQuaternion(q);

/// One simulated body of a [LuminaRagdoll]: the bone it drives (an entry of
/// the ragdoll's skeleton), its shape's offset from the bone, the collision
/// component that carries it and its rigid body.
class LuminaRagdollBody {
  final String bone;
  final int slot;
  final LuminaPhysicsBodyData data;
  final Vector3 offsetPosition;
  final Quaternion offsetRotation;
  final LuminaCollisionComponent component;
  final LuminaRigidBody body;

  /// The joint to the parent body (null for the root body).
  LuminaPhysicsJoint? joint;
  LuminaRagdollBody? parent;

  LuminaRagdollBody(this.bone, this.slot, this.data, this.offsetPosition, this.offsetRotation, this.component, this.body);

  /// The body's world frame for a bone at [bone].
  LuminaBoneFrame bodyFrameFor(LuminaBoneFrame bone) => (
        position: bone.position + _rot(bone.rotation, offsetPosition),
        rotation: (bone.rotation * offsetRotation)..normalize(),
      );

  /// The bone's world frame the body's current pose implies (between the
  /// last two physics steps when [alpha] < 1).
  LuminaBoneFrame boneFrame([double alpha = 1.0]) {
    final (origin, rotation) = body.interpolatedOrigin(alpha);
    final r = (rotation * offsetRotation.conjugated())..normalize();
    return (position: origin - _rot(r, offsetPosition), rotation: r);
  }
}

/// A ragdoll in a world's physics: a rigid body per physics asset body,
/// posed on its bone, and a joint per constraint, built at the skeleton's
/// rest pose (the limits are measured from it) and then moved to the pose
/// it starts from.
///
/// Bodies belong to [owner] but are not registered with the collision
/// subsystem, so the owner's capsule and traces never see them; they collide
/// with the level, other actors and each other, except joined pairs and the
/// asset's disabled pairs.
class LuminaRagdoll {
  final LuminaPhysicsSubsystem physics;
  final LuminaActor owner;
  final LuminaPhysicsAssetData asset;
  final List<LuminaRagdollBody> bodies;
  final List<LuminaPhysicsJoint> joints;
  final Map<String, LuminaRagdollBody> _byBone;

  /// Friction 0.9, no bounce: limbs slide little and settle.
  static const LuminaPhysicalMaterial material = LuminaPhysicalMaterial(friction: 0.9, restitution: 0.0);

  LuminaRagdoll._(this.physics, this.owner, this.asset, this.bodies, this.joints)
      : _byBone = {for (final b in bodies) b.bone: b};

  LuminaRagdollBody? bodyOf(String bone) => _byBone[bone];

  /// The root body (the one without a parent: the pelvis).
  LuminaRagdollBody get root => bodies.firstWhere((b) => b.parent == null, orElse: () => bodies.first);

  /// Builds the ragdoll in [physics]. [rest] gives each body bone's rest
  /// frame, [start] the frame to start from (missing: rest), [velocities]
  /// each bone's linear (world units/s) and angular (rad/s) velocity.
  /// Joint friction per kg of the child body (kg·cm²/s² per kg; 3000 is
  /// 0.3 N·m per kg): enough to stop a limb rocking, far too little to hold
  /// it up.
  static double jointFrictionPerKg = 3000.0;

  static LuminaRagdoll create({
    required LuminaPhysicsSubsystem physics,
    required LuminaActor owner,
    required LuminaPhysicsAssetData asset,
    required LuminaRagdollSkeleton skeleton,
    required Map<String, LuminaBoneFrame> rest,
    Map<String, LuminaBoneFrame> start = const {},
    Map<String, (Vector3, Vector3)> velocities = const {},
  }) {
    final bodies = <LuminaRagdollBody>[];
    for (final data in asset.bodies) {
      final slot = skeleton.slotNamed(data.bone);
      final restFrame = rest[data.bone];
      if (slot < 0 || restFrame == null) continue;
      final offsetPosition = data.offsetVector;
      final offsetRotation = data.offsetQuaternion;
      final frame = (
        position: restFrame.position + _rot(restFrame.rotation, offsetPosition),
        rotation: (restFrame.rotation * offsetRotation)..normalize(),
      );
      final component = _componentFor(data, frame.position, frame.rotation)
        ..overrideMass = true
        ..massKg = math.max(data.massKg, 0.05)
        ..linearDamping = data.linearDamping
        ..angularDamping = data.angularDamping
        ..physicalMaterial = material;
      component.onRegister(owner);
      final body = physics.addBody(component);
      if (body == null) continue;
      body.collidesWithOwnBodies = true;
      bodies.add(LuminaRagdollBody(data.bone, slot, data, offsetPosition, offsetRotation, component, body));
    }
    final byBone = {for (final b in bodies) b.bone: b};
    for (final a in bodies) {
      for (final b in bodies) {
        if (identical(a, b) || !asset.isPairDisabled(a.bone, b.bone)) continue;
        a.body.ignoredBodies.add(b.body);
      }
    }

    final joints = <LuminaPhysicsJoint>[];
    for (final c in asset.constraints) {
      final a = byBone[c.bodyA], b = byBone[c.bodyB];
      final childRest = rest[c.bodyB];
      if (a == null || b == null || childRest == null) continue;
      final frame = (childRest.rotation * c.frameQuaternion)..normalize();
      const k = math.pi / 180.0;
      final joint = LuminaPhysicsJoint.atWorld(
        a.body,
        b.body,
        childRest.position,
        frame,
        kind: c.type == LuminaPhysicsJointType.hinge ? LuminaJointKind.hinge : LuminaJointKind.ball,
        swing1: c.swing1Degrees * k,
        swing2: c.swing2Degrees * k,
        twistMin: c.effectiveTwistMin * k,
        twistMax: c.effectiveTwistMax * k,
        limitsEnabled: c.angularMode != LuminaPhysicsAngularMode.free,
        name: c.bodyB,
      );
      if (c.angularMode == LuminaPhysicsAngularMode.locked) {
        joint
          ..swing1 = 0
          ..swing2 = 0
          ..twistMin = 0
          ..twistMax = 0;
      }
      joint.frictionTorque = jointFrictionPerKg * b.body.mass;
      physics.addJoint(joint);
      joints.add(joint);
      b.joint = joint;
      b.parent = a;
    }

    final ragdoll = LuminaRagdoll._(physics, owner, asset, bodies, joints);
    ragdoll.setPose(start.isEmpty ? rest : {...rest, ...start}, velocities: velocities);
    return ragdoll;
  }

  static LuminaCollisionComponent _componentFor(LuminaPhysicsBodyData data, Vector3 at, Quaternion rotation) {
    switch (data.shape) {
      case LuminaPhysicsBodyShape.capsule:
        return LuminaCapsuleComponent(location: at, rotation: rotation, radius: data.radius, halfHeight: data.effectiveHalfHeight);
      case LuminaPhysicsBodyShape.sphere:
        return LuminaSphereComponent(location: at, rotation: rotation, radius: data.radius);
      case LuminaPhysicsBodyShape.box:
        return LuminaBoxComponent(
            location: at, rotation: rotation, boxExtent: Vector3(data.halfExtents[0], data.halfExtents[1], data.halfExtents[2]));
    }
  }

  /// Moves every body onto its bone in [bones] (bodies of missing bones stay)
  /// with the bones' [velocities] (linear, angular) and wakes them.
  void setPose(Map<String, LuminaBoneFrame> bones, {Map<String, (Vector3, Vector3)> velocities = const {}}) {
    for (final b in bodies) {
      final bone = bones[b.bone];
      if (bone == null) continue;
      final f = b.bodyFrameFor(bone);
      b.body.setOriginTransform(f.position, f.rotation);
      final v = velocities[b.bone];
      if (v != null) {
        // A point's velocity on a turning bone: v + ω × r.
        b.body.linearVelocity.setFrom(v.$1 + v.$2.cross(b.body.position - bone.position));
        b.body.angularVelocity.setFrom(v.$2);
      } else {
        b.body.linearVelocity.setZero();
        b.body.angularVelocity.setZero();
      }
      b.body.wake();
    }
  }

  /// The bone frames the bodies give now ([alpha] as
  /// [LuminaRagdollBody.boneFrame]).
  Map<String, LuminaBoneFrame> boneFrames([double alpha = 1.0]) => {for (final b in bodies) b.bone: b.boneFrame(alpha)};

  /// Pushes [bone]'s body (the root body for an unknown bone) by [impulse]
  /// (kg·cm/s), at [location] when given; [velocityChange] treats it as cm/s.
  void addImpulse(Vector3 impulse, {String? bone, Vector3? location, bool velocityChange = false}) {
    final b = (bone == null ? null : _byBone[bone]) ?? root;
    if (location != null && !velocityChange) {
      b.body.addImpulseAtLocation(impulse, location);
    } else {
      b.body.addImpulse(impulse, velocityChange: velocityChange);
    }
    for (final other in bodies) {
      other.body.wake();
    }
  }

  /// Gives every body [velocity] (a thrown ragdoll).
  void addVelocity(Vector3 velocity) {
    for (final b in bodies) {
      b.body.linearVelocity.add(velocity);
      b.body.wake();
    }
  }

  /// Powers the joints toward the relative rotations of [targets] (bone
  /// frames, e.g. the animated pose) with [maxTorque] kg·cm²/s² per kg of
  /// the child body and [rate] 1/s; [maxTorque] 0 switches the motors off.
  void driveToward(Map<String, LuminaBoneFrame> targets, {required double maxTorque, double rate = 20.0}) {
    for (final b in bodies) {
      final j = b.joint, p = b.parent;
      if (j == null || p == null) continue;
      final tb = targets[b.bone], ta = targets[p.bone];
      if (maxTorque <= 0 || tb == null || ta == null) {
        j.motorEnabled = false;
        continue;
      }
      final fa = (ta.rotation * p.offsetRotation) * j.localFrameA;
      final fb = (tb.rotation * b.offsetRotation) * j.localFrameB;
      final target = (fa.conjugated() * fb)..normalize();
      j
        ..motorEnabled = true
        ..motorTarget = target
        ..motorRate = rate
        ..motorMaxTorque = maxTorque * b.body.mass;
    }
  }

  /// The bodies' kinetic energy (kg·cm²/s²).
  double get kineticEnergy {
    var e = 0.0;
    for (final b in bodies) {
      final r = b.body;
      e += 0.5 * r.mass * r.linearVelocity.length2 + 0.5 * r.angularVelocity.dot(r.localInertiaWorld().transformed(r.angularVelocity));
    }
    return e;
  }

  /// The fastest body's speed (world units/s).
  double get maxSpeed => bodies.fold(0.0, (m, b) => math.max(m, b.body.linearVelocity.length));

  /// Whether every body sleeps or moves slower than [speed].
  bool isSettled(double speed) =>
      bodies.every((b) => !b.body.isAwake || (b.body.linearVelocity.length < speed && b.body.angularVelocity.length < 0.5));

  /// The speed of the centre of mass (world units/s).
  double get centerOfMassSpeed {
    final p = Vector3.zero();
    for (final b in bodies) {
      p.add(b.body.linearVelocity * b.body.mass);
    }
    return p.length / math.max(totalMass, 1e-6);
  }

  /// Sets every body's damping; null restores the physics asset's.
  void setDamping({double? linear, double? angular}) {
    for (final b in bodies) {
      b.body
        ..linearDamping = linear ?? b.data.linearDamping
        ..angularDamping = angular ?? b.data.angularDamping;
    }
  }

  /// The largest distance between joined anchors (world units).
  double get maxJointError => joints.fold(0.0, (m, j) => math.max(m, j.anchorError));

  double get totalMass => bodies.fold(0.0, (m, b) => m + b.body.mass);

  /// The centre of mass of all bodies.
  Vector3 get centerOfMass {
    final c = Vector3.zero();
    for (final b in bodies) {
      c.add(b.body.position * b.body.mass);
    }
    return c..scale(1 / math.max(totalMass, 1e-6));
  }

  /// Removes the bodies and joints from the world.
  void destroy() {
    for (final j in joints) {
      physics.removeJoint(j);
    }
    for (final b in bodies) {
      physics.removeBody(b.component);
      b.component.onUnregister();
    }
  }
}
