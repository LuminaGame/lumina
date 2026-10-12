import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/contact_solver.dart';
import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';
import 'package:lumina/src/physics/jolt/jolt_collision_profiles.dart';
import 'package:lumina/src/physics/jolt/jolt_joints.dart';
import 'package:lumina/src/physics/jolt/jolt_static_colliders.dart';
import 'package:lumina/src/physics/physical_material.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/physics/rigid_body.dart';

/// What the backend last sent to or read from Jolt for one body, so a step
/// pushes only what gameplay changed in between.
class _Mirror {
  _Mirror(this.id, this.body);

  final int id;
  final LuminaRigidBody body;
  final Vector3 position = Vector3.zero();
  Quaternion orientation = Quaternion.identity();
  final Vector3 linear = Vector3.zero();
  final Vector3 angular = Vector3.zero();
  bool awake = true;
  List<Object> shapes = const [];
  double mass = 0;
  final Vector3 centerOfMass = Vector3.zero();
  final Matrix3 inertia = Matrix3.zero();
  LuminaPhysicalMaterial? material;
  int dofs = -1;
  double linearDamping = double.nan, angularDamping = double.nan;
  bool? gravity;
  bool? collidesWithOwn;
  List<int> profiles = const [];
  final Set<LuminaRigidBody> ignored = {};

  void remember() {
    final b = body;
    position.setFrom(b.position);
    orientation = b.orientation.clone();
    linear.setFrom(b.linearVelocity);
    angular.setFrom(b.angularVelocity);
    awake = b.isAwake;
  }
}

/// Jolt Physics behind [LuminaPhysicsSubsystem] (native desktop).
///
/// Every [LuminaRigidBody] is mirrored as a dynamic Jolt body whose shape
/// is its pieces in the body frame, centre of mass, mass and inertia taken
/// from the Dart body (so the mass rules stay Lumina's); every non-simulating
/// collision component is a static Jolt body ([LuminaJoltStaticColliders]).
/// Lengths are converted at this boundary only (cm ↔ m); the runtime frame is
/// Y-up on both sides.
///
/// A step pushes what gameplay changed since the last one (teleports,
/// velocities, sleep and wake, damping, gravity, locks, materials, shapes,
/// mass, ignored pairs, joint parameters) and the frame's forces, steps Jolt,
/// then writes poses, velocities and sleep back into the Dart bodies. Jolt's
/// contacts become the step's [contacts] and hit candidates (Jolt's estimated
/// normal impulse).
class LuminaJoltPhysicsBackend implements LuminaPhysicsBackend {
  LuminaJoltPhysicsBackend({this.workerThreads = 2});

  /// Jolt's worker threads for this world's steps.
  final int workerThreads;

  /// Made on first use: a world without bodies (an editor preview) never
  /// starts Jolt's threads.
  JoltWorld? _joltWorld;
  JoltWorld get _world => _joltWorld ??= _createWorld();
  late LuminaPhysicsSubsystem _physics;
  late final LuminaJoltCollisionProfiles _profiles = LuminaJoltCollisionProfiles(_world);
  late final LuminaJoltStaticColliders _statics = LuminaJoltStaticColliders(_world, _profiles, _ownerOfComponent);
  final Map<LuminaRigidBody, _Mirror> _mirrors = {};
  final Map<int, _Mirror> _byId = {};
  final Map<LuminaPhysicsJoint, LuminaJoltJoint> _joints = {};
  final Expando<int> _ownerIds = Expando('luminaJoltOwner');
  int _nextOwner = 1;
  List<LuminaContactManifold> _contacts = const [];
  bool _disposed = false;

  /// The Jolt world (tests and diagnostics).
  JoltWorld get joltWorld => _world;

  /// The Jolt body id of [body] (null when it is not in this backend).
  int? joltBodyId(LuminaRigidBody body) => _mirrors[body]?.id;

  /// Static Jolt bodies for the world's colliders right now.
  int get staticBodyCount => _statics.length;

  @override
  String get name => 'jolt';

  @override
  LuminaPhysicsBackendKind get kind => LuminaPhysicsBackendKind.jolt;

  @override
  void attach(LuminaPhysicsSubsystem physics) => _physics = physics;

  JoltWorld _createWorld() {
    if (_disposed) throw StateError('The Jolt physics backend was disposed');
    final physics = _physics;
    final world = JoltWorld(workerThreads: workerThreads);
    world.solverSettings = world.solverSettings
      // Centimetre-scale expectations: bodies rest within a few millimetres.
      ..velocitySteps = physics.velocityIterations + physics.jointIterations
      ..positionSteps = physics.positionIterations + 1
      ..penetrationSlop = 0.002
      ..speculativeContactDistance = 0.01
      ..timeBeforeSleep = physics.timeToSleep
      ..pointVelocitySleepThreshold = physics.sleepLinearVelocity * kJoltScale;
    return world;
  }

  @override
  List<LuminaContactManifold> get contacts => List.unmodifiable(_contacts);

  int _ownerOf(LuminaActor? actor) {
    if (actor == null) return 0;
    return _ownerIds[actor] ??= _nextOwner++;
  }

  int _ownerOfComponent(LuminaCollisionComponent c) => _ownerOf(c.owner);

  // --- Bodies ---------------------------------------------------------------------

  @override
  void bodyAdded(LuminaRigidBody body) {
    final shape = LuminaJoltShapes.forBody(body);
    final dofs = _dofsOf(body);
    final id = _world.createBody(
      shape,
      JoltBodySettings(
        motionType: dofs == 0 ? JoltMotionType.kinematic : JoltMotionType.dynamic_,
        position: toJolt(body.origin),
        rotation: body.orientation.normalized(),
        linearVelocity: toJolt(body.linearVelocity),
        angularVelocity: body.angularVelocity.clone(),
        userData: body.id,
        linearDamping: body.linearDamping,
        angularDamping: body.angularDamping,
        gravityFactor: body.enableGravity ? 1 : 0,
        mass: body.mass,
        inertia: LuminaJoltShapes.inertiaOf(body),
        allowedDofs: dofs == 0 ? JoltDofs.all : dofs,
        startActive: body.isAwake,
      ),
    );
    shape.release();
    final m = _Mirror(id, body)
      ..shapes = List<Object>.of(body.shapes)
      ..mass = body.mass
      ..dofs = dofs
      ..linearDamping = body.linearDamping
      ..angularDamping = body.angularDamping
      ..gravity = body.enableGravity;
    m.centerOfMass.setFrom(body.localCenterOfMass);
    m.inertia.setFrom(body.localInertia);
    m.remember();
    _mirrors[body] = m;
    _byId[id] = m;
    _syncFilters(m);
  }

  @override
  void bodyRemoved(LuminaRigidBody body) {
    final m = _mirrors.remove(body);
    if (m == null) return;
    for (final entry in _joints.entries.where((e) => identical(e.key.bodyA, body) || identical(e.key.bodyB, body)).toList()) {
      _joints.remove(entry.key);
    }
    _byId.remove(m.id);
    _world.destroyBody(m.id);
    for (final other in _mirrors.values) {
      other.ignored.remove(body);
    }
    _contacts = [
      for (final c in _contacts)
        if (!identical(c.a, body) && !identical(c.b, body)) c,
    ];
  }

  static int _dofsOf(LuminaRigidBody b) {
    var d = 0;
    if (b.linearFactor.x != 0) d |= JoltDofs.translationX;
    if (b.linearFactor.y != 0) d |= JoltDofs.translationY;
    if (b.linearFactor.z != 0) d |= JoltDofs.translationZ;
    if (b.angularFactor.x != 0) d |= JoltDofs.rotationX;
    if (b.angularFactor.y != 0) d |= JoltDofs.rotationY;
    if (b.angularFactor.z != 0) d |= JoltDofs.rotationZ;
    // 0: every axis locked; Jolt needs a free axis on a dynamic body, so
    // such a body is kinematic (it never moves, it pushes what it touches).
    return d;
  }

  /// Owner group, profiles, material and ignored pairs of [m]'s body.
  void _syncFilters(_Mirror m) {
    final b = m.body;
    if (b.collidesWithOwnBodies != m.collidesWithOwn) {
      _world.setBodyOwner(m.id, _ownerOf(b.component.owner), collidesWithOwner: b.collidesWithOwnBodies);
      m.collidesWithOwn = b.collidesWithOwnBodies;
    }
    final profiles = [for (final s in b.shapes) _profiles.profileOf(s.component)];
    if (!_sameInts(profiles, m.profiles)) {
      _world.setBodyProfiles(m.id, profiles);
      m.profiles = profiles;
    }
    final mat = b.material;
    if (!identical(mat, m.material) && mat != m.material) {
      _world.setBodyMaterial(
        m.id,
        friction: mat.friction,
        staticFriction: mat.effectiveStaticFriction,
        restitution: mat.restitution,
        frictionMode: JoltCombineMode.values[mat.frictionCombineMode.index],
        restitutionMode: JoltCombineMode.values[mat.restitutionCombineMode.index],
      );
      m.material = mat;
    }
    if (b.ignoredBodies.length != m.ignored.length || !m.ignored.containsAll(b.ignoredBodies)) {
      for (final gone in m.ignored.difference(b.ignoredBodies)) {
        final other = _mirrors[gone];
        if (other != null && !gone.ignoredBodies.contains(b)) _world.ignorePair(m.id, other.id, ignore: false);
      }
      for (final added in b.ignoredBodies.difference(m.ignored)) {
        final other = _mirrors[added];
        if (other != null) _world.ignorePair(m.id, other.id);
      }
      m.ignored
        ..clear()
        ..addAll(b.ignoredBodies.where(_mirrors.containsKey));
    }
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameObjects(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Sends what gameplay changed on [m]'s body since the last step.
  void _push(_Mirror m) {
    final b = m.body;
    final id = m.id;
    final reshaped = !_sameObjects(m.shapes, b.shapes) || (b.localCenterOfMass - m.centerOfMass).length2 > 1e-12;
    if (reshaped) {
      final shape = LuminaJoltShapes.forBody(b);
      _world.setBodyShape(id, shape, updateMass: false);
      shape.release();
      m.shapes = List<Object>.of(b.shapes);
      m.centerOfMass.setFrom(b.localCenterOfMass);
      // The body frame's origin moved relative to the centre of mass.
      m.position.setValues(double.nan, 0, 0);
    }
    final dofs = _dofsOf(b);
    if ((dofs == 0) != (m.dofs == 0)) {
      _world.setBodyMotionType(id, dofs == 0 ? JoltMotionType.kinematic : JoltMotionType.dynamic_, activate: b.isAwake);
      if (dofs == 0) _world.setBodyVelocity(id, Vector3.zero(), Vector3.zero());
      m.mass = double.nan;
    }
    if (reshaped || b.mass != m.mass || dofs != m.dofs || !_sameMatrix(b.localInertia, m.inertia)) {
      if (dofs != 0) _world.setBodyMassProperties(id, b.mass, LuminaJoltShapes.inertiaOf(b), allowedDofs: dofs);
      m.mass = b.mass;
      m.dofs = dofs;
      m.inertia.setFrom(b.localInertia);
    }
    if (b.linearDamping != m.linearDamping || b.angularDamping != m.angularDamping) {
      _world.setBodyDamping(id, b.linearDamping, b.angularDamping);
      m.linearDamping = b.linearDamping;
      m.angularDamping = b.angularDamping;
    }
    if (b.enableGravity != m.gravity) {
      _world.setBodyGravityFactor(id, b.enableGravity ? 1 : 0);
      m.gravity = b.enableGravity;
    }
    _syncFilters(m);
    final moved = !(b.position.distanceToSquared(m.position) <= 1e-10) || !_sameRotation(b.orientation, m.orientation);
    if (moved) _world.setBodyTransform(id, toJolt(b.origin), b.orientation.normalized(), activate: b.isAwake);
    if (b.linearVelocity.distanceToSquared(m.linear) > 1e-12 || b.angularVelocity.distanceToSquared(m.angular) > 1e-14) {
      _world.setBodyVelocity(id, toJolt(b.linearVelocity), b.angularVelocity);
    }
    if (b.isAwake != m.awake) {
      if (b.isAwake) {
        _world.activateBody(id);
      } else {
        _world.deactivateBody(id);
      }
    }
    if (b.isAwake) {
      final f = b.pendingForce;
      if (f.length2 > 0) _world.addForce(id, f * kJoltScale);
      final t = b.pendingTorque;
      if (t.length2 > 0) _world.addTorque(id, t * (kJoltScale * kJoltScale));
    }
  }

  static bool _sameMatrix(Matrix3 a, Matrix3 b) {
    for (var i = 0; i < 9; i++) {
      if (a.storage[i] != b.storage[i]) return false;
    }
    return true;
  }

  static bool _sameRotation(Quaternion a, Quaternion b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs() + (a.w - b.w).abs() <= 1e-9;

  // --- Joints ---------------------------------------------------------------------

  @override
  void jointAdded(LuminaPhysicsJoint joint) {
    final a = _mirrors[joint.bodyA], b = _mirrors[joint.bodyB];
    if (a == null || b == null) return;
    _syncFilters(a);
    _syncFilters(b);
    _joints[joint] = LuminaJoltJoint.create(_world, joint, a.id, b.id);
  }

  @override
  void jointRemoved(LuminaPhysicsJoint joint) {
    final j = _joints.remove(joint);
    if (j != null) _world.removeConstraint(j.constraint);
  }

  // --- Step -----------------------------------------------------------------------

  @override
  void step(double dt) {
    final physics = _physics;
    _world.gravity = toJolt(physics.gravity);
    _statics.sync(physics.colliders());
    final bodies = physics.bodyList;
    for (final b in bodies) {
      final m = _mirrors[b];
      if (m != null) _push(m);
    }
    for (final j in _joints.values) {
      j.sync();
    }
    _profiles.flush();
    _world.step(dt);
    _read(bodies);
    _collectContacts(dt, physics.gravity.length);
  }

  void _read(List<LuminaRigidBody> bodies) {
    final ids = <int>[];
    final mirrors = <_Mirror>[];
    for (final b in bodies) {
      final m = _mirrors[b];
      if (m == null) continue;
      ids.add(m.id);
      mirrors.add(m);
    }
    _world.readBodyStates(ids);
    final s = _world.stateBuffer;
    const stride = JoltWorld.stateStride;
    for (var i = 0; i < mirrors.length; i++) {
      final m = mirrors[i];
      final b = m.body;
      final o = i * stride;
      final active = s[o + 13] != 0;
      b.previousPosition.setFrom(b.position);
      b.previousOrientation = b.orientation.clone();
      b.position.setValues(s[o] * kLuminaScale, s[o + 1] * kLuminaScale, s[o + 2] * kLuminaScale);
      b.orientation = Quaternion(s[o + 3], s[o + 4], s[o + 5], s[o + 6])..normalize();
      b.linearVelocity.setValues(s[o + 7] * kLuminaScale, s[o + 8] * kLuminaScale, s[o + 9] * kLuminaScale);
      b.angularVelocity.setValues(s[o + 10], s[o + 11], s[o + 12]);
      b.updateInertia();
      b.updateWorld();
      if (active && !b.isAwake) {
        b.wake();
      } else if (!active && b.isAwake) {
        b.sleep();
      }
      m.remember();
    }
  }

  void _collectContacts(double dt, double gravity) {
    final out = <LuminaContactManifold>[];
    for (final c in _world.contacts()) {
      var ma = _byId[c.bodyA], mb = _byId[c.bodyB];
      var shapeA = c.shapeA, shapeB = c.shapeB;
      final normal = c.normal.clone();
      LuminaCollisionComponent? staticComponent;
      if (ma == null && mb == null) continue;
      if (ma == null || (mb != null && mb.body.id < ma.body.id)) {
        // The body (the lower id of two) is A; the normal points from A to B.
        final m = ma;
        ma = mb;
        mb = m;
        final s = shapeA;
        shapeA = shapeB;
        shapeB = s;
        normal.negate();
        if (mb == null) staticComponent = _statics.byBody[c.bodyA];
      } else if (mb == null) {
        staticComponent = _statics.byBody[c.bodyB];
      }
      final a = ma!.body;
      final b = mb?.body;
      if (b == null && staticComponent == null) continue;
      final ca = shapeA < a.shapes.length ? a.shapes[shapeA].component : null;
      final cb = b != null ? (shapeB < b.shapes.length ? b.shapes[shapeB].component : null) : staticComponent;
      final key = b != null ? '${a.id}:$shapeA:${b.id}:$shapeB' : '${a.id}:$shapeA:s${staticComponent!.componentId}';
      final materialB = b?.material ?? staticComponent!.effectivePhysicalMaterial;
      final impulse = c.impulse * kLuminaScale;
      final point = c.point * kLuminaScale;
      final m = LuminaContactManifold(a, b, ca, cb, key)
        ..friction = LuminaPhysicalMaterial.combinedFriction(a.material, materialB)
        ..staticFriction = LuminaPhysicalMaterial.combinedStaticFriction(a.material, materialB)
        ..restitution = LuminaPhysicalMaterial.combinedRestitution(a.material, materialB)
        ..lastStep = _physics.stepCount;
      m.normal.setFrom(normal);
      m.points.add(LuminaContactPoint()
        ..point.setFrom(point)
        ..depth = c.penetration * kLuminaScale
        ..normalImpulse = impulse);
      out.add(m);
      _physics.recordHit(m, impulse, point, normal, dt, gravity);
    }
    _contacts = out;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _joints.clear();
    _mirrors.clear();
    _byId.clear();
    _contacts = const [];
    _joltWorld?.dispose();
    _joltWorld = null;
  }
}
