import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/collision/box_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/math/euler.dart';
import 'package:lumina/src/math/units.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/physics/contact_generation.dart';
import 'package:lumina/src/physics/contact_solver.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/physics/physical_material.dart';
import 'package:lumina/src/physics/rigid_body.dart';

class _BodyRecord {
  final bool drivesRoot;
  final Vector3 lastOrigin = Vector3.zero();
  Quaternion lastRotation = Quaternion.identity();

  /// A box this subsystem made for a static mesh with no collision.
  LuminaBoxComponent? proxy;
  _BodyRecord(this.drivesRoot);
}

class _Entry {
  final Aabb3 box;
  final LuminaRigidBody? body;
  final LuminaCollisionComponent? component;
  final int order;
  _Entry(this.box, this.body, this.component, this.order);
}

class _Hit {
  final LuminaContactManifold manifold;
  double impulse;
  final Vector3 point;
  final Vector3 normal;
  _Hit(this.manifold, this.impulse, this.point, this.normal);
}

/// Rigid-body dynamics for a world (what a primitive component's Simulate
/// Physics runs on). A pure-Dart solver on
/// the existing narrow phase, so the web build simulates the same; it sits
/// behind this class so a native engine could replace it.
///
/// - **Stepping**: fixed [fixedTimeStep] (120 Hz), at most [maxSubsteps] per
///   frame; components are written at the pose interpolated between the last
///   two steps. Pairs are processed in body-creation order, so the same input
///   gives the same result.
/// - **Contacts**: up to four points per pair from [LuminaContactGenerator],
///   warm started across steps; [LuminaContactSolver] runs
///   [velocityIterations] sequential-impulse passes (Coulomb friction, static
///   and dynamic, restitution above [LuminaContactSolver.restitutionThreshold])
///   and [positionIterations] split-impulse passes.
/// - **World**: every collision component that does not simulate (level
///   geometry, the landscape heightfield, a character's capsule) blocks bodies
///   as an immovable collider; gravity is the world's `gravityZ` (authoring
///   −Z, runtime −Y).
/// - **Sleep**: a group of touching bodies slower than
///   [sleepLinearVelocity] / [sleepAngularVelocity] for [timeToSleep] sleeps;
///   a contact with an awake body, an impulse or a force wakes it.
/// - **Driving**: a simulating component that is its actor's root, or a
///   direct child of the root, moves the whole actor; one deeper in the tree
///   is detached and moves by itself.
/// - **Events**: a contact whose normal impulse clearly exceeds resting
///   (twice the effective weight for a step, and [hitImpulseThreshold]) raises
///   `onComponentHit` and the actors' hit hooks (Blueprint Event Hit) once per
///   frame with [HitResult.normalImpulse].
class LuminaPhysicsSubsystem extends LuminaWorldSubsystem {
  double fixedTimeStep = 1 / 120;
  int maxSubsteps = 8;
  int velocityIterations = 8;
  int positionIterations = 3;
  double contactMargin = 0.5;
  double sleepLinearVelocity = 2.0;
  double sleepAngularVelocity = 0.035;
  double timeToSleep = 0.5;
  double hitImpulseThreshold = 1.0;

  /// Write interpolated poses (true) or the last step's (false).
  bool interpolate = true;

  final LuminaContactSolver solver = LuminaContactSolver();
  final List<LuminaRigidBody> _bodies = [];
  final Map<LuminaRigidBody, _BodyRecord> _records = {};
  final Map<String, LuminaContactManifold> _manifolds = {};
  final Map<String, _Hit> _pendingHits = {};
  int _nextBodyId = 0;
  double _accumulator = 0.0;

  /// Fixed steps taken so far, and the simulated time (s).
  int stepCount = 0;
  double simulatedTime = 0.0;

  /// Steps taken in the last frame.
  int lastFrameSteps = 0;

  /// The bodies, in creation order.
  List<LuminaRigidBody> get bodies => List.unmodifiable(_bodies);

  /// The contacts of the last step.
  List<LuminaContactManifold> get contacts => List.unmodifiable(solver.manifolds);

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

  // --- Bodies ---------------------------------------------------------------------

  /// Makes [component] a rigid body (see [LuminaPrimitivePhysics]); returns it,
  /// or null when the component has no shape to simulate.
  LuminaRigidBody? addBody(LuminaPrimitivePhysics component) {
    final existing = component.physicsBody;
    if (existing != null && identical(existing.component, component)) return existing;
    final owner = component.owner;
    if (owner == null) return null;
    LuminaBoxComponent? proxy;
    var shapes = _shapesFor(component);
    if (shapes.isEmpty && component is LuminaStaticMeshComponent) {
      proxy = _proxyFor(component);
      shapes = _shapesFor(component);
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
    _bodies.remove(body);
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
    _manifolds.removeWhere((_, m) => identical(m.a, body) || identical(m.b, body));
    solver.manifolds.removeWhere((m) => identical(m.a, body) || identical(m.b, body));
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
    final shapes = _shapesFor(c);
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
  static LuminaMassProperties resolveMassProperties(LuminaPrimitivePhysics component, [List<LuminaBodyShape>? shapes]) {
    final pieces = shapes ?? _shapesFor(component, forMass: true);
    final parts = [for (final s in pieces) (mass: s.massProperties, position: s.position, rotation: s.rotation)];
    var volume = 0.0;
    for (final p in parts) {
      volume += p.mass.volume;
    }
    final mesh = meshPhysicsOf(component);
    final double mass;
    if (component.overrideMass && component.massKg > 0) {
      mass = component.massKg;
    } else if (mesh?.massKg != null) {
      mass = mesh!.massKg!;
    } else {
      // g/cm³ × cm³ → kg.
      mass = math.max(component.effectivePhysicalMaterial.density * volume / 1000.0, 1e-3);
    }
    final offset = component.centerOfMassOffset ?? mesh?.runtimeCenterOfMassOffset;
    return LuminaMassProperties.combine(parts, mass: mass, centerOfMassOffset: offset);
  }

  /// The static mesh physics [component] inherits: its own, else the nearest
  /// static mesh component's in its actor (a parent, then a child, then any).
  static LuminaMeshPhysics? meshPhysicsOf(LuminaPrimitivePhysics component) {
    if (component.meshPhysics != null) return component.meshPhysics;
    for (var p = component.parentComponent; p != null; p = p.parentComponent) {
      if (p is LuminaStaticMeshComponent && p.meshPhysics != null) return p.meshPhysics;
    }
    LuminaMeshPhysics? fromChildren(LuminaSceneComponent c) {
      for (final child in c.childComponents) {
        if (child is LuminaStaticMeshComponent && child.meshPhysics != null) return child.meshPhysics;
        final deeper = fromChildren(child);
        if (deeper != null) return deeper;
      }
      return null;
    }

    final child = fromChildren(component);
    if (child != null) return child;
    final owner = component.owner;
    if (owner == null) return null;
    for (final c in owner.components) {
      if (c is LuminaStaticMeshComponent && c.meshPhysics != null) return c.meshPhysics;
    }
    return null;
  }

  static List<LuminaBodyShape> _shapesFor(LuminaPrimitivePhysics component, {bool forMass = false}) {
    if (component is LuminaCollisionComponent) {
      final s = _shapeOf(component, Vector3.zero(), Quaternion.identity());
      return s == null ? const [] : [s];
    }
    if (component is! LuminaStaticMeshComponent) return const [];
    final mesh = component;
    final out = <LuminaBodyShape>[];
    final invRot = mesh.worldRotation.conjugated();
    final origin = mesh.worldLocation;
    void walk(LuminaSceneComponent c) {
      for (final child in c.childComponents) {
        if (child is LuminaCollisionComponent && !child.simulatePhysics) {
          final p = (child.worldLocation - origin)..applyQuaternion(invRot);
          final q = invRot * child.worldRotation;
          final s = _shapeOf(child, p, q);
          if (s != null) out.add(s);
        }
        if (child is! LuminaStaticMeshComponent) walk(child);
      }
    }

    walk(mesh);
    if (out.isEmpty && forMass) {
      final (center, extent) = _meshBox(mesh);
      out.add(LuminaBodyShape(BoxShape(extent), position: center));
    }
    return out;
  }

  static LuminaBodyShape? _shapeOf(LuminaCollisionComponent c, Vector3 position, Quaternion rotation) {
    final s = c.relativeScale;
    final abs = Vector3(s.x.abs(), s.y.abs(), s.z.abs());
    final CollisionShape shape;
    var scale = Vector3(1, 1, 1);
    switch (c.shapeType) {
      case CollisionShapeType.sphere:
        shape = SphereShape(c.radius);
      case CollisionShapeType.box:
        shape = BoxShape(c.boxExtent.clone()..multiply(abs));
      case CollisionShapeType.capsule:
        shape = CapsuleShape(c.radius, c.halfHeight);
      case CollisionShapeType.cylinder:
        shape = CylinderShape(c.radius, c.height);
      case CollisionShapeType.cone:
        shape = ConeShape(c.radius, c.height);
      case CollisionShapeType.convex:
        shape = c.convexHull!;
        scale = s.clone();
      case CollisionShapeType.heightfield:
        return null;
    }
    return LuminaBodyShape(shape, position: position, rotation: rotation, scale: scale, component: c);
  }

  /// The mesh's bounds box in its own frame (cm, its scale applied); a 50 cm
  /// cube until the mesh has loaded.
  static (Vector3, Vector3) _meshBox(LuminaStaticMeshComponent mesh) {
    final b = mesh.localBounds;
    final s = mesh.relativeScale;
    final abs = Vector3(s.x.abs(), s.y.abs(), s.z.abs());
    if (b == null) return (Vector3.zero(), Vector3.all(25.0));
    final center = ((b.min + b.max)..scale(0.5))..multiply(s);
    final extent = ((b.max - b.min)..scale(0.5))..multiply(abs);
    return (center, Vector3(math.max(extent.x, 0.5), math.max(extent.y, 0.5), math.max(extent.z, 0.5)));
  }

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
    final (center, extent) = _meshBox(mesh);
    proxy.relativeLocation = center;
    proxy.setBoxExtent(extent);
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
    if (_bodies.isEmpty || deltaTime <= 0) return;
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
    _collide();
    final g = gravity;
    for (final b in _bodies) {
      if (b.isAwake) b.integrateForces(dt, g);
    }
    solver.prepare(dt);
    for (var i = 0; i < velocityIterations; i++) {
      solver.solveVelocities();
    }
    solver.applyRestitution();
    for (var i = 0; i < positionIterations; i++) {
      solver.solvePositions(dt);
    }
    for (final b in _bodies) {
      if (b.isAwake) b.integrateVelocities(dt);
    }
    _recordHits(dt, g.length);
    _updateSleep(dt);
  }

  List<LuminaCollisionComponent> _colliders() {
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

  void _collide() {
    final margin = contactMargin;
    final entries = <_Entry>[];
    var order = 0;
    for (final b in _bodies) {
      final box = Aabb3.copy(b.bounds)
        ..min.sub(Vector3.all(margin))
        ..max.add(Vector3.all(margin));
      entries.add(_Entry(box, b, null, order++));
    }
    for (final c in _colliders()) {
      if (!c.collisionEnabled || c.physicsBody != null) continue;
      entries.add(_Entry(c.getAABB(), null, c, order++));
    }
    entries.sort((x, y) {
      final d = x.box.min.x.compareTo(y.box.min.x);
      return d != 0 ? d : x.order.compareTo(y.order);
    });
    final pairs = <(LuminaRigidBody, LuminaRigidBody?, LuminaCollisionComponent?)>[];
    final active = <_Entry>[];
    for (final e in entries) {
      active.removeWhere((a) => a.box.max.x < e.box.min.x);
      for (final a in active) {
        if (a.box.max.y < e.box.min.y || a.box.min.y > e.box.max.y) continue;
        if (a.box.max.z < e.box.min.z || a.box.min.z > e.box.max.z) continue;
        final ba = a.body, be = e.body;
        if (ba == null && be == null) continue;
        if (ba != null && be != null) {
          if (!ba.isAwake && !be.isAwake) continue;
          final first = ba.id < be.id ? ba : be;
          pairs.add((first, identical(first, ba) ? be : ba, null));
        } else {
          final body = ba ?? be!;
          if (!body.isAwake) continue;
          pairs.add((body, null, a.component ?? e.component));
        }
      }
      active.add(e);
    }
    // Deterministic processing order: by body id, then partner.
    pairs.sort((p, q) {
      final d = p.$1.id.compareTo(q.$1.id);
      if (d != 0) return d;
      final ip = p.$2?.id ?? (1 << 40) + (p.$3?.componentId ?? 0);
      final iq = q.$2?.id ?? (1 << 40) + (q.$3?.componentId ?? 0);
      return ip.compareTo(iq);
    });

    final active2 = <LuminaContactManifold>[];
    final set = LuminaContactSet();
    // A static collider's shape and transform, once per step.
    final statics = <LuminaCollisionComponent, LuminaCollider>{};
    LuminaCollider staticCollider(LuminaCollisionComponent c) =>
        statics.putIfAbsent(c, () => LuminaCollider(c.worldShape, c.worldTransform));
    for (final (a, b, staticC) in pairs) {
      final ownerA = a.component.owner;
      final ownerB = b?.component.owner ?? staticC?.owner;
      if (ownerA != null && identical(ownerA, ownerB)) continue;
      for (var i = 0; i < a.shapes.length; i++) {
        final sa = a.shapes[i];
        if (b != null) {
          for (var j = 0; j < b.shapes.length; j++) {
            final sb = b.shapes[j];
            if (!_blocks(sa.component, sb.component)) continue;
            if (!_near(sa.worldBounds, sb.worldBounds, margin)) continue;
            if (!LuminaContactGenerator.collide(
                LuminaCollider(sa.shape, sa.worldTransform), LuminaCollider(sb.shape, sb.worldTransform), set,
                margin: margin)) {
              continue;
            }
            active2.add(_manifold('${a.id}:$i:${b.id}:$j', a, b, sa.component, sb.component, set, b.material));
          }
        } else {
          final c = staticC!;
          if (!_blocks(sa.component, c)) continue;
          if (!_near(sa.worldBounds, c.getAABB(), margin)) continue;
          if (!LuminaContactGenerator.collide(LuminaCollider(sa.shape, sa.worldTransform), staticCollider(c), set,
              margin: margin)) {
            continue;
          }
          active2.add(_manifold('${a.id}:$i:s${c.componentId}', a, null, sa.component, c, set, c.effectivePhysicalMaterial));
        }
      }
    }
    _manifolds.removeWhere((_, m) => m.lastStep != stepCount);
    solver.manifolds
      ..clear()
      ..addAll(active2);
  }

  static bool _near(Aabb3 a, Aabb3 b, double margin) =>
      a.max.x + margin >= b.min.x &&
      a.min.x - margin <= b.max.x &&
      a.max.y + margin >= b.min.y &&
      a.min.y - margin <= b.max.y &&
      a.max.z + margin >= b.min.z &&
      a.min.z - margin <= b.max.z;

  static bool _blocks(LuminaCollisionComponent? a, LuminaCollisionComponent? b) {
    if (a != null && !a.collisionEnabled) return false;
    if (b != null && !b.collisionEnabled) return false;
    if (a != null && b != null) return effectiveResponse(a, b) == CollisionResponse.block;
    final c = a ?? b;
    if (c == null) return true;
    return c.getResponse(CollisionObjectType.worldDynamic) == CollisionResponse.block;
  }

  LuminaContactManifold _manifold(String key, LuminaRigidBody a, LuminaRigidBody? b, LuminaCollisionComponent? ca,
      LuminaCollisionComponent? cb, LuminaContactSet set, LuminaPhysicalMaterial materialB) {
    var m = _manifolds[key];
    if (m == null) {
      m = LuminaContactManifold(a, b, ca, cb, key);
      _manifolds[key] = m;
    } else {
      m.age++;
    }
    m.lastStep = stepCount;
    m.update(set, 2.0);
    m.friction = LuminaPhysicalMaterial.combinedFriction(a.material, materialB);
    m.staticFriction = LuminaPhysicalMaterial.combinedStaticFriction(a.material, materialB);
    m.restitution = LuminaPhysicalMaterial.combinedRestitution(a.material, materialB);
    return m;
  }

  void _recordHits(double dt, double g) {
    for (final m in solver.manifolds) {
      final a = m.a, b = m.b;
      final invA = a.isAwake ? a.inverseMass : 0.0;
      final invB = b != null && b.isAwake ? b.inverseMass : 0.0;
      final inv = invA + invB;
      if (inv <= 0) continue;
      final threshold = math.max(hitImpulseThreshold, 2.0 * g * dt / inv);
      final impulse = m.normalImpulse;
      if (impulse <= threshold) continue;
      final point = Vector3.zero();
      for (final p in m.points) {
        point.add(p.point);
      }
      if (m.points.isNotEmpty) point.scale(1 / m.points.length);
      final existing = _pendingHits[m.key];
      if (existing == null) {
        _pendingHits[m.key] = _Hit(m, impulse, point, m.normal.clone());
      } else if (impulse > existing.impulse) {
        existing.impulse = impulse;
        existing.point.setFrom(point);
        existing.normal.setFrom(m.normal);
      }
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

  void _updateSleep(double dt) {
    final n = _bodies.length;
    final index = <LuminaRigidBody, int>{for (var i = 0; i < n; i++) _bodies[i]: i};
    final parent = List<int>.generate(n, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (final m in solver.manifolds) {
      final b = m.b;
      if (b == null) continue;
      final ia = find(index[m.a]!), ib = find(index[b]!);
      if (ia != ib) parent[ia] = ib;
    }
    final linTol = sleepLinearVelocity * sleepLinearVelocity;
    final angTol = sleepAngularVelocity * sleepAngularVelocity;
    for (final b in _bodies) {
      if (!b.isAwake) continue;
      if (b.linearVelocity.length2 > linTol || b.angularVelocity.length2 > angTol) {
        b.sleepTime = 0.0;
      } else {
        b.sleepTime += dt;
      }
    }
    final islandMin = <int, double>{};
    final islandAwake = <int, bool>{};
    for (var i = 0; i < n; i++) {
      final b = _bodies[i];
      final root = find(i);
      if (b.isAwake) {
        islandAwake[root] = true;
        islandMin[root] = math.min(islandMin[root] ?? double.infinity, b.sleepTime);
      }
    }
    for (var i = 0; i < n; i++) {
      final b = _bodies[i];
      final root = find(i);
      if (islandAwake[root] != true) continue;
      final min = islandMin[root]!;
      if (min >= timeToSleep) {
        b.sleep();
      } else if (!b.isAwake) {
        b.wake();
      }
    }
  }

  @override
  void onWorldShutdown() {
    for (final b in List.of(_bodies)) {
      final c = b.component;
      if (c is LuminaPrimitivePhysics) removeBody(c);
    }
    _manifolds.clear();
    solver.manifolds.clear();
    super.onWorldShutdown();
  }
}

/// The actor a body drives.
extension LuminaRigidBodyOwner on LuminaRigidBody {
  LuminaActor? get owner => component.owner;
}
