import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/physics/cloth/cloth_simulator.dart';
import 'package:lumina/src/physics/contact_generation.dart';
import 'package:lumina/src/physics/contact_solver.dart';
import 'package:lumina/src/physics/joint_batch.dart';
import 'package:lumina/src/physics/physical_material.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/physics/rigid_body.dart';

class _Entry {
  final Aabb3 box;
  final LuminaRigidBody? body;
  final LuminaCollisionComponent? component;
  final int order;
  _Entry(this.box, this.body, this.component, this.order);
}

/// The pure-Dart solver: runs on every platform (the web's only backend)
/// and is the fallback where Jolt is not built.
///
/// - **Contacts**: a sweep-and-prune broad phase over the bodies and every
///   non-simulating collision component; up to four points per pair from
///   [LuminaContactGenerator], warm started across steps; [solver] runs
///   the subsystem's `velocityIterations` sequential-impulse passes (Coulomb
///   friction, static and dynamic, restitution above
///   [LuminaContactSolver.restitutionThreshold]) and `positionIterations`
///   split-impulse passes. Pairs are processed in body-creation order, so the
///   same input gives the same result.
/// - **Joints**: rows solved with the contacts (`jointIterations` extra
///   passes), then `jointPositionIterations` position passes after
///   integration.
/// - **Sleep**: a group of touching or joined bodies slower than the
///   subsystem's sleep velocities for `timeToSleep` sleeps.
class LuminaDartPhysicsBackend implements LuminaPhysicsBackend {
  late LuminaPhysicsSubsystem _physics;
  final LuminaContactSolver solver = LuminaContactSolver();
  final Map<String, LuminaContactManifold> _manifolds = {};

  @override
  String get name => 'dart';

  @override
  LuminaPhysicsBackendKind get kind => LuminaPhysicsBackendKind.dart;

  @override
  void attach(LuminaPhysicsSubsystem physics) => _physics = physics;

  @override
  List<LuminaContactManifold> get contacts => List.unmodifiable(solver.manifolds);

  /// The Dart solver simulates no cloth.
  @override
  LuminaClothSimulator? get cloth => null;

  @override
  void bodyAdded(LuminaRigidBody body) {}

  @override
  void bodyRemoved(LuminaRigidBody body) {
    _manifolds.removeWhere((_, m) => identical(m.a, body) || identical(m.b, body));
    solver.manifolds.removeWhere((m) => identical(m.a, body) || identical(m.b, body));
  }

  @override
  void jointAdded(LuminaPhysicsJoint joint) {}

  @override
  void jointRemoved(LuminaPhysicsJoint joint) {}

  @override
  void step(double dt) {
    final p = _physics;
    final bodies = p.bodyList;
    _collide();
    final g = p.gravity;
    for (final b in bodies) {
      if (b.isAwake) b.integrateForces(dt, g);
    }
    final joints = LuminaJointBatch.awake(p.jointList);
    solver.prepare(dt);
    joints.prepare(dt);
    for (var i = 0; i < p.velocityIterations; i++) {
      joints.velocityPass(i);
      solver.solveVelocities();
    }
    joints.velocityPasses(p.jointIterations);
    solver.applyRestitution();
    for (var i = 0; i < p.positionIterations; i++) {
      solver.solvePositions(dt);
    }
    for (final b in bodies) {
      if (b.isAwake) b.integrateVelocities(dt);
    }
    joints.positionPasses(p.jointPositionIterations);
    _recordHits(dt, g.length);
    _updateSleep(dt);
  }

  @override
  void dispose() {
    _manifolds.clear();
    solver.manifolds.clear();
  }

  // --- Contacts -------------------------------------------------------------------

  void _collide() {
    final p = _physics;
    final margin = p.contactMargin;
    final entries = <_Entry>[];
    var order = 0;
    for (final b in p.bodyList) {
      final box = Aabb3.copy(b.bounds)
        ..min.sub(Vector3.all(margin))
        ..max.add(Vector3.all(margin));
      entries.add(_Entry(box, b, null, order++));
    }
    for (final c in p.colliders()) {
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
    pairs.sort((x, y) {
      final d = x.$1.id.compareTo(y.$1.id);
      if (d != 0) return d;
      final ix = x.$2?.id ?? (1 << 40) + (x.$3?.componentId ?? 0);
      final iy = y.$2?.id ?? (1 << 40) + (y.$3?.componentId ?? 0);
      return ix.compareTo(iy);
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
      if (b != null && (a.ignoredBodies.contains(b) || b.ignoredBodies.contains(a))) continue;
      if (ownerA != null &&
          identical(ownerA, ownerB) &&
          !(b != null && a.collidesWithOwnBodies && b.collidesWithOwnBodies)) {
        continue;
      }
      for (var i = 0; i < a.shapes.length; i++) {
        final sa = a.shapes[i];
        if (b != null) {
          for (var j = 0; j < b.shapes.length; j++) {
            final sb = b.shapes[j];
            if (!LuminaPhysicsSubsystem.shapesBlock(sa.component, sb.component)) continue;
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
          if (!LuminaPhysicsSubsystem.shapesBlock(sa.component, c)) continue;
          if (!_near(sa.worldBounds, c.getAABB(), margin)) continue;
          if (!LuminaContactGenerator.collide(LuminaCollider(sa.shape, sa.worldTransform), staticCollider(c), set,
              margin: margin)) {
            continue;
          }
          active2.add(_manifold('${a.id}:$i:s${c.componentId}', a, null, sa.component, c, set, c.effectivePhysicalMaterial));
        }
      }
    }
    _manifolds.removeWhere((_, m) => m.lastStep != p.stepCount);
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

  LuminaContactManifold _manifold(String key, LuminaRigidBody a, LuminaRigidBody? b, LuminaCollisionComponent? ca,
      LuminaCollisionComponent? cb, LuminaContactSet set, LuminaPhysicalMaterial materialB) {
    var m = _manifolds[key];
    if (m == null) {
      m = LuminaContactManifold(a, b, ca, cb, key);
      _manifolds[key] = m;
    } else {
      m.age++;
    }
    m.lastStep = _physics.stepCount;
    m.update(set, 2.0);
    m.friction = LuminaPhysicalMaterial.combinedFriction(a.material, materialB);
    m.staticFriction = LuminaPhysicalMaterial.combinedStaticFriction(a.material, materialB);
    m.restitution = LuminaPhysicalMaterial.combinedRestitution(a.material, materialB);
    return m;
  }

  void _recordHits(double dt, double g) {
    for (final m in solver.manifolds) {
      final point = Vector3.zero();
      for (final p in m.points) {
        point.add(p.point);
      }
      if (m.points.isNotEmpty) point.scale(1 / m.points.length);
      _physics.recordHit(m, m.normalImpulse, point, m.normal, dt, g);
    }
  }

  // --- Sleep ----------------------------------------------------------------------

  void _updateSleep(double dt) {
    final p = _physics;
    final bodies = p.bodyList;
    final n = bodies.length;
    final index = <LuminaRigidBody, int>{for (var i = 0; i < n; i++) bodies[i]: i};
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
    for (final j in p.jointList) {
      final xa = index[j.bodyA], xb = index[j.bodyB];
      if (xa == null || xb == null) continue;
      final ia = find(xa), ib = find(xb);
      if (ia != ib) parent[ia] = ib;
    }
    final linTol = p.sleepLinearVelocity * p.sleepLinearVelocity;
    final angTol = p.sleepAngularVelocity * p.sleepAngularVelocity;
    for (final b in bodies) {
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
      final b = bodies[i];
      final root = find(i);
      if (b.isAwake) {
        islandAwake[root] = true;
        islandMin[root] = math.min(islandMin[root] ?? double.infinity, b.sleepTime);
      }
    }
    for (var i = 0; i < n; i++) {
      final b = bodies[i];
      final root = find(i);
      if (islandAwake[root] != true) continue;
      final min = islandMin[root]!;
      if (min >= p.timeToSleep) {
        b.sleep();
      } else if (!b.isAwake) {
        b.wake();
      }
    }
  }
}
