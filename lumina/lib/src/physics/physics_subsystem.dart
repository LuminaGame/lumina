import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/collision/box_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/physics/cloth/cloth_component.dart';
import 'package:lumina/src/physics/contact_solver.dart';
import 'package:lumina/src/physics/dart_physics_backend.dart';
import 'package:lumina/src/physics/jolt/jolt_backend_factory.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/physics/physics_backend.dart';
import 'package:lumina/src/physics/physics_body_shapes.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/rigid_body.dart';

export 'package:lumina/src/physics/physics_backend.dart' show LuminaPhysicsBackend, LuminaPhysicsBackendKind;

class _BodyRecord {
  final bool drivesRoot;
  final Vector3 lastOrigin = Vector3.zero();
  Quaternion lastRotation = Quaternion.identity();

  /// A box this subsystem made for a static mesh with no collision.
  LuminaBoxComponent? proxy;
  _BodyRecord(this.drivesRoot);
}

class _Hit {
  final LuminaContactManifold manifold;
  double impulse;
  final Vector3 point;
  final Vector3 normal;
  _Hit(this.manifold, this.impulse, this.point, this.normal);
}

/// Rigid-body dynamics for a world (what a primitive component's Simulate
/// Physics runs on). The subsystem owns the bodies, joints, the fixed-step
/// clock, component sync and events; a [LuminaPhysicsBackend] does the
/// stepping: Jolt Physics on native desktop where its library is built, the
/// pure-Dart solver ([LuminaDartPhysicsBackend]) on the web and as the
/// fallback ([backendKind], [defaultBackend]).
///
/// - **Stepping**: fixed [fixedTimeStep] (120 Hz), at most [maxSubsteps] per
///   frame; components are written at the pose interpolated between the last
///   two steps. The same input gives the same result on a backend.
/// - **World**: every collision component that does not simulate (level
///   geometry, the landscape heightfield, a character's capsule) blocks bodies
///   as an immovable collider; gravity is the world's `gravityZ` (authoring
///   −Z, runtime −Y).
/// - **Sleep**: bodies slower than [sleepLinearVelocity] /
///   [sleepAngularVelocity] for [timeToSleep] sleep; a contact with an awake
///   body, an impulse or a force wakes them.
/// - **Driving**: a simulating component that is its actor's root, or a
///   direct child of the root, moves the whole actor; one deeper in the tree
///   is detached and moves by itself.
/// - **Events**: a contact whose normal impulse clearly exceeds resting
///   (twice the effective weight for a step, and [hitImpulseThreshold]) raises
///   `onComponentHit` and the actors' hit hooks (Blueprint Event Hit) once per
///   frame with [HitResult.normalImpulse].
/// - **Joints**: [addJoint] connects two bodies ([LuminaPhysicsJoint]: anchor,
///   swing cone, twist range, hinge, motor). Joined bodies never collide.
///   Bodies of one actor collide with each other only when both have
///   [LuminaRigidBody.collidesWithOwnBodies] and neither lists the other in
///   [LuminaRigidBody.ignoredBodies] (a ragdoll's limbs).
class LuminaPhysicsSubsystem extends LuminaWorldSubsystem {
  /// A subsystem stepped by [backend] (`auto`: [defaultBackend], then the
  /// `LUMINA_PHYSICS_BACKEND` dart-define / environment variable, then Jolt
  /// when available, else Dart).
  LuminaPhysicsSubsystem({LuminaPhysicsBackendKind? backend}) {
    final kind = resolvePhysicsBackendKind(backend ?? defaultBackend);
    final chosen = kind == LuminaPhysicsBackendKind.jolt ? createJoltPhysicsBackend() : null;
    this.backend = chosen ?? LuminaDartPhysicsBackend();
    this.backend.attach(this);
  }

  /// The backend kind new subsystems ask for.
  static LuminaPhysicsBackendKind defaultBackend = LuminaPhysicsBackendKind.auto;

  /// What steps this subsystem's bodies.
  late final LuminaPhysicsBackend backend;

  /// [backend]'s kind (never `auto`).
  LuminaPhysicsBackendKind get backendKind => backend.kind;

  double fixedTimeStep = 1 / 120;
  int maxSubsteps = 8;
  int velocityIterations = 8;
  int positionIterations = 3;
  double contactMargin = 0.5;
  double sleepLinearVelocity = 2.0;
  double sleepAngularVelocity = 0.035;
  double timeToSleep = 0.5;
  double hitImpulseThreshold = 1.0;

  /// Joint-only velocity passes after the shared ones, and position passes
  /// (the Dart backend).
  int jointIterations = 6;
  int jointPositionIterations = 4;

  /// Write interpolated poses (true) or the last step's (false).
  bool interpolate = true;

  /// The Dart backend's contact solver (an idle one on another backend).
  LuminaContactSolver get solver {
    final b = backend;
    return b is LuminaDartPhysicsBackend ? b.solver : _idleSolver;
  }

  static final LuminaContactSolver _idleSolver = LuminaContactSolver();

  final List<LuminaRigidBody> _bodies = [];
  final Map<LuminaRigidBody, _BodyRecord> _records = {};
  final Map<String, _Hit> _pendingHits = {};
  final List<LuminaPhysicsJoint> _joints = [];
  final List<LuminaClothComponent> _cloths = [];
  int _nextBodyId = 0;
  double _accumulator = 0.0;

  /// Fixed steps taken so far, and the simulated time (s).
  int stepCount = 0;
  double simulatedTime = 0.0;

  /// Steps taken in the last frame.
  int lastFrameSteps = 0;

  /// The bodies, in creation order.
  List<LuminaRigidBody> get bodies => List.unmodifiable(_bodies);

  /// The live body list, for backends (do not modify).
  List<LuminaRigidBody> get bodyList => _bodies;

  /// The live joint list, for backends (do not modify).
  List<LuminaPhysicsJoint> get jointList => _joints;

  /// The contacts of the last step.
  List<LuminaContactManifold> get contacts => backend.contacts;

  /// Gravity in the runtime frame (cm/s²): the world's authoring Z.
  Vector3 get gravity => Vector3(0, world?.gravityZ ?? -LuminaUnits.gravity, 0);

  static final Expando<LuminaPhysicsSubsystem> _pending = Expando('luminaPendingPhysics');

  /// [world]'s physics subsystem, registering one when it has none. During
  /// the subsystem tick (when registering is not allowed) the new subsystem
  /// is registered at the start of the next frame.
  static LuminaPhysicsSubsystem? ensure(LuminaWorld world) {
    final existing = world.getSubsystem<LuminaPhysicsSubsystem>() ?? _pending[world];
    if (existing != null) return existing;
    try {
      return world.registerSubsystem(LuminaPhysicsSubsystem());
    } on StateError {
      final physics = LuminaPhysicsSubsystem();
      _pending[world] = physics;
      final previous = world.onPreTick;
      world.onPreTick = (dt) {
        world.onPreTick = previous;
        previous?.call(dt);
        _pending[world] = null;
        if (world.getSubsystem<LuminaPhysicsSubsystem>() == null) world.registerSubsystem(physics);
      };
      return physics;
    }
  }

  /// The joints, in creation order.
  List<LuminaPhysicsJoint> get joints => List.unmodifiable(_joints);

  /// The cloth components of this world, in registration order (simulated
  /// when [backend] has a cloth simulator).
  List<LuminaClothComponent> get cloths => List.unmodifiable(_cloths);

  /// Registers [cloth] (its geometry is built); the cloth starts or stops
  /// its simulation itself.
  void addCloth(LuminaClothComponent cloth) {
    if (!_cloths.contains(cloth)) _cloths.add(cloth);
  }

  void removeCloth(LuminaClothComponent cloth) {
    if (!_cloths.remove(cloth)) return;
    backend.cloth?.remove(cloth);
  }

  /// Connects two bodies of this subsystem; they stop colliding with each
  /// other.
  LuminaPhysicsJoint addJoint(LuminaPhysicsJoint joint) {
    _joints.add(joint);
    joint.bodyA.ignoredBodies.add(joint.bodyB);
    joint.bodyB.ignoredBodies.add(joint.bodyA);
    joint.bodyA.wake();
    joint.bodyB.wake();
    backend.jointAdded(joint);
    return joint;
  }

  void removeJoint(LuminaPhysicsJoint joint) {
    if (!_joints.remove(joint)) return;
    backend.jointRemoved(joint);
    joint.bodyA.wake();
    joint.bodyB.wake();
  }

  // --- Bodies ---------------------------------------------------------------------

  /// Makes [component] a rigid body (see [LuminaPrimitivePhysics]); returns it,
  /// or null when the component has no shape to simulate.
  LuminaRigidBody? addBody(LuminaPrimitivePhysics component) {
    final existing = component.physicsBody;
    if (existing != null && identical(existing.component, component)) return existing;
    final owner = component.owner;
    if (owner == null) return null;
    LuminaBoxComponent? proxy;
    var shapes = LuminaPhysicsBodyShapes.shapesFor(component);
    if (shapes.isEmpty && component is LuminaStaticMeshComponent) {
      proxy = _proxyFor(component);
      shapes = LuminaPhysicsBodyShapes.shapesFor(component);
    }
    if (shapes.isEmpty) return null;

    final root = owner.rootComponent;
    final drivesRoot = identical(component, root) ||
        (identical(component.parentComponent, root) &&
            root.parentComponent == null &&
            !_records.entries.any((e) => e.value.drivesRoot && identical(e.key.component.owner, owner)));
    if (!drivesRoot && component.parentComponent != null) {
      final location = component.worldLocation;
      final rotation = component.worldRotation;
      component.detachFromParent();
      component.relativeLocation = location;
      component.relativeRotation = rotation;
    }

    final body = LuminaRigidBody(
      id: _nextBodyId++,
      component: component,
      shapes: shapes,
      massProperties: resolveMassProperties(component, shapes),
      origin: component.worldLocation,
      rotation: component.worldRotation,
      material: component.effectivePhysicalMaterial,
    )
      ..linearDamping = component.linearDamping
      ..angularDamping = component.angularDamping
      ..enableGravity = component.enableGravity;
    component.applyLocksTo(body);
    body.onSleepChanged = (b, asleep) {
      final c = b.component;
      if (c is! LuminaPrimitivePhysics) return;
      final p = c;
      if (asleep) {
        p.onComponentSleep?.call(c);
      } else {
        p.onComponentWake?.call(c);
      }
    };
    component.physicsBody = body;
    for (final s in shapes) {
      s.component?.physicsBody = body;
    }
    final record = _BodyRecord(drivesRoot)..proxy = proxy;
    record.lastOrigin.setFrom(component.worldLocation);
    record.lastRotation = component.worldRotation.clone();
    _bodies.add(body);
    _records[body] = record;
    backend.bodyAdded(body);
    if (proxy != null && component is LuminaStaticMeshComponent && !component.isLoaded) {
      component.loaded.then((_) {
        if (!identical(component.physicsBody, body)) return;
        _sizeProxy(component, proxy!);
        refreshShapes(body);
      }).catchError((Object _) {});
    }
    return body;
  }

  /// Stops simulating [component]: it stays where it is.
  void removeBody(LuminaPrimitivePhysics component) {
    final body = component.physicsBody;
    if (body == null || !identical(body.component, component)) return;
    for (final j in _joints.where((j) => identical(j.bodyA, body) || identical(j.bodyB, body)).toList()) {
      _joints.remove(j);
      backend.jointRemoved(j);
    }
    backend.bodyRemoved(body);
    _bodies.remove(body);
    for (final other in _bodies) {
      other.ignoredBodies.remove(body);
    }
    final record = _records.remove(body);
    for (final s in body.shapes) {
      if (identical(s.component?.physicsBody, body)) s.component!.physicsBody = null;
    }
    component.physicsBody = null;
    final proxy = record?.proxy;
    if (proxy != null) {
      world?.getSubsystem<LuminaCollisionSubsystem>()?.unregister(proxy);
      proxy.detachFromParent();
      proxy.onUnregister();
    }
    _pendingHits.removeWhere((_, h) => identical(h.manifold.a, body) || identical(h.manifold.b, body));
  }

  /// Recomputes [body]'s mass, centre of mass and inertia from its
  /// component's settings, keeping its pose and velocities.
  void refreshMass(LuminaRigidBody body) {
    final c = body.component;
    if (c is! LuminaPrimitivePhysics) return;
    final origin = body.origin;
    body.setMassProperties(resolveMassProperties(c, body.shapes));
    body.material = c.effectivePhysicalMaterial;
    body.setOriginTransform(origin, body.orientation);
    body.wake();
  }

  /// Rebuilds [body]'s shapes from its component (after a proxy resize or a
  /// collision child change).
  void refreshShapes(LuminaRigidBody body) {
    final c = body.component;
    if (c is! LuminaPrimitivePhysics) return;
    final shapes = LuminaPhysicsBodyShapes.shapesFor(c);
    if (shapes.isEmpty) return;
    body.shapes
      ..clear()
      ..addAll(shapes);
    for (final s in shapes) {
      s.component?.physicsBody = body;
    }
    refreshMass(body);
  }

  /// The mass properties [component] simulates with (see
  /// [LuminaPrimitivePhysics] for the mass rule).
  static LuminaMassProperties resolveMassProperties(LuminaPrimitivePhysics component, [List<LuminaBodyShape>? shapes]) =>
      LuminaPhysicsBodyShapes.resolveMassProperties(component, shapes);

  /// The static mesh physics [component] inherits (see
  /// [LuminaPhysicsBodyShapes.meshPhysicsOf]).
  static LuminaMeshPhysics? meshPhysicsOf(LuminaPrimitivePhysics component) => LuminaPhysicsBodyShapes.meshPhysicsOf(component);

  /// A box collider around a static mesh that has no collision, so the
  /// character, traces and the solver all see it. It is attached under the
  /// mesh and registered with the collision subsystem, owned by the mesh's
  /// actor, but not added to the actor's component list (bodies start while
  /// the actor is iterating it).
  LuminaBoxComponent _proxyFor(LuminaStaticMeshComponent mesh) {
    final proxy = LuminaBoxComponent();
    _sizeProxy(mesh, proxy);
    proxy.attachToComponent(mesh);
    proxy.onRegister(mesh.owner!);
    world?.getSubsystem<LuminaCollisionSubsystem>()?.register(proxy);
    return proxy;
  }

  void _sizeProxy(LuminaStaticMeshComponent mesh, LuminaBoxComponent proxy) {
    final (center, extent) = LuminaPhysicsBodyShapes.meshBox(mesh);
    proxy.relativeLocation = center;
    proxy.setBoxExtent(extent);
  }

  /// The collision components that can block bodies: the collision
  /// subsystem's, else every collision component of the world's actors.
  List<LuminaCollisionComponent> colliders() {
    final collision = world?.getSubsystem<LuminaCollisionSubsystem>();
    if (collision != null) return collision.components;
    final w = world;
    if (w == null) return const [];
    return [
      for (final actor in w.actors)
        for (final c in actor.components)
          if (c is LuminaCollisionComponent) c,
    ];
  }

  /// Whether a body shape from [a] and one from [b] block each other (a null
  /// component blocks whatever blocks `worldDynamic`).
  static bool shapesBlock(LuminaCollisionComponent? a, LuminaCollisionComponent? b) {
    if (a != null && !a.collisionEnabled) return false;
    if (b != null && !b.collisionEnabled) return false;
    if (a != null && b != null) return effectiveResponse(a, b) == CollisionResponse.block;
    final c = a ?? b;
    if (c == null) return true;
    return c.getResponse(CollisionObjectType.worldDynamic) == CollisionResponse.block;
  }

  // --- Tick -------------------------------------------------------------------------

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    advance(deltaTime);
  }

  /// Runs the fixed steps [deltaTime] covers, then writes the components and
  /// raises the frame's hit events.
  void advance(double deltaTime) {
    lastFrameSteps = 0;
    if ((_bodies.isEmpty && _cloths.isEmpty) || deltaTime <= 0) return;
    _syncFromComponents();
    _accumulator += deltaTime;
    var steps = (_accumulator / fixedTimeStep + 1e-9).floor();
    if (steps > maxSubsteps) {
      steps = maxSubsteps;
      _accumulator = steps * fixedTimeStep;
    }
    for (var i = 0; i < steps; i++) {
      step(fixedTimeStep);
      _accumulator -= fixedTimeStep;
    }
    if (_accumulator < 0) _accumulator = 0;
    lastFrameSteps = steps;
    if (steps > 0) {
      for (final b in _bodies) {
        b.clearForces();
      }
    }
    _writeToComponents(interpolate ? _accumulator / fixedTimeStep : 1.0);
    _dispatchHits();
  }

  /// A component moved from outside (a teleport, Set World Location):
  /// the body follows it.
  void _syncFromComponents() {
    for (final body in _bodies) {
      final record = _records[body]!;
      final c = body.component;
      final location = c.worldLocation;
      final rotation = c.worldRotation;
      final moved = location.distanceToSquared(record.lastOrigin) > 1e-4 ||
          (rotation.x - record.lastRotation.x).abs() +
                  (rotation.y - record.lastRotation.y).abs() +
                  (rotation.z - record.lastRotation.z).abs() +
                  (rotation.w - record.lastRotation.w).abs() >
              1e-5;
      if (moved) {
        body.setOriginTransform(location, rotation);
        record.lastOrigin.setFrom(location);
        record.lastRotation = rotation.clone();
        body.wake();
      }
    }
  }

  void _writeToComponents(double alpha) {
    for (final body in _bodies) {
      final record = _records[body]!;
      final (origin, rotation) = body.interpolatedOrigin(alpha);
      final c = body.component;
      if (record.drivesRoot && !identical(c, c.owner?.rootComponent)) {
        final root = c.owner!.rootComponent;
        final rootRotation = (rotation * c.relativeRotation.conjugated())..normalize();
        root.relativeRotation = rootRotation;
        root.relativeLocation = origin - rootRotation.rotateVector(c.relativeLocation);
      } else {
        c.relativeRotation = rotation;
        c.relativeLocation = origin;
      }
      record.lastOrigin.setFrom(c.worldLocation);
      record.lastRotation = c.worldRotation.clone();
    }
  }

  /// One fixed step of [dt] seconds.
  void step(double dt) {
    stepCount++;
    simulatedTime += dt;
    backend.step(dt);
  }

  /// A backend's contact [m] with normal impulse [impulse] (kg·cm/s) at
  /// [point] this step: kept as the frame's hit for its pair when it clearly
  /// exceeds resting ([gravity] cm/s² over [dt]).
  void recordHit(LuminaContactManifold m, double impulse, Vector3 point, Vector3 normal, double dt, double gravity) {
    final a = m.a, b = m.b;
    final invA = a.isAwake ? a.inverseMass : 0.0;
    final invB = b != null && b.isAwake ? b.inverseMass : 0.0;
    final inv = invA + invB;
    if (inv <= 0) return;
    final threshold = math.max(hitImpulseThreshold, 2.0 * gravity * dt / inv);
    if (impulse <= threshold) return;
    final existing = _pendingHits[m.key];
    if (existing == null) {
      _pendingHits[m.key] = _Hit(m, impulse, point.clone(), normal.clone());
    } else if (impulse > existing.impulse) {
      existing.impulse = impulse;
      existing.point.setFrom(point);
      existing.normal.setFrom(normal);
    }
  }

  void _dispatchHits() {
    if (_pendingHits.isEmpty) return;
    final hits = _pendingHits.values.toList();
    _pendingHits.clear();
    for (final h in hits) {
      final m = h.manifold;
      final ca = m.componentA, cb = m.componentB;
      if (ca == null || cb == null) continue;
      HitResult make(LuminaCollisionComponent self, LuminaCollisionComponent other, Vector3 normal) => HitResult()
        ..blockingHit = true
        ..time = 0.0
        ..component = other
        ..normalImpulse = h.impulse
        ..location.setFrom(self.worldLocation)
        ..impactPoint.setFrom(h.point)
        ..impactNormal.setFrom(normal);
      // The normal points from A to B: A is pushed back along −normal.
      final hitA = make(ca, cb, -h.normal);
      final hitB = make(cb, ca, h.normal);
      ca.onComponentHit?.call(ca, cb, hitA);
      cb.onComponentHit?.call(cb, ca, hitB);
      final ownerA = ca.owner, ownerB = cb.owner;
      if (ownerA != null && ownerB != null && !identical(ownerA, ownerB)) {
        ownerA.notifyActorHit(ownerB, ca, cb, hitA);
        ownerB.notifyActorHit(ownerA, cb, ca, hitB);
      }
    }
  }

  @override
  void onWorldShutdown() {
    for (final b in List.of(_bodies)) {
      final c = b.component;
      if (c is LuminaPrimitivePhysics) removeBody(c);
    }
    _joints.clear();
    _pendingHits.clear();
    for (final c in List.of(_cloths)) {
      removeCloth(c);
    }
    backend.dispose();
    super.onWorldShutdown();
  }
}

/// The actor a body drives.
extension LuminaRigidBodyOwner on LuminaRigidBody {
  LuminaActor? get owner => component.owner;
}
