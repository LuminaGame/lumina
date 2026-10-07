import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';
import 'package:lumina/src/collision/gjk_epa.dart';
import 'package:lumina/src/collision/heightfield.dart';
import 'package:lumina/src/collision/narrow_phase.dart';
import 'package:lumina/src/collision/raycast_math.dart';
import 'package:lumina/src/math/euler.dart';

/// Central world subsystem managing broad-phase filtering, overlap/hit event dispatch, and geometric queries.
class LuminaCollisionSubsystem extends LuminaWorldSubsystem {
  final List<LuminaCollisionComponent> _components = [];
  final Set<int> _activeOverlapPairs = <int>{};
  bool _isUpdating = false;

  /// Test seam counting narrow-phase evaluations in the current frame.
  int narrowPhaseTestCount = 0;

  /// The registered components, in registration order.
  List<LuminaCollisionComponent> get components => List.unmodifiable(_components);

  /// Registers a collision component with this subsystem.
  void register(LuminaCollisionComponent c) {
    if (!_components.contains(c)) {
      _components.add(c);
    }
  }

  /// Unregisters a collision component and terminates any active overlap relationships.
  void unregister(LuminaCollisionComponent c) {
    if (!_components.remove(c)) return;

    final overlapping = List<LuminaCollisionComponent>.from(c.overlappingComponents);
    for (final other in overlapping) {
      c.removeOverlappingComponent(other);
      other.removeOverlappingComponent(c);
      final pairKey = _pairKey(c.componentId, other.componentId);
      _activeOverlapPairs.remove(pairKey);

      c.onComponentEndOverlap?.call(c, other);
      other.onComponentEndOverlap?.call(other, c);
    }
  }

  int _pairKey(int idA, int idB) {
    final minId = math.min(idA, idB);
    final maxId = math.max(idA, idB);
    return (minId << 32) | (maxId & 0xFFFFFFFF);
  }

  @override
  void onWorldTick(double deltaTime) {
    updateCollision(deltaTime);
  }

  /// Executes broad phase, narrow phase, and fires overlap/hit events for all registered components.
  void updateCollision(double deltaTime) {
    if (_isUpdating) return;
    _isUpdating = true;
    narrowPhaseTestCount = 0;

    final beginOverlapEvents = <(LuminaCollisionComponent, LuminaCollisionComponent)>[];
    final endOverlapEvents = <(LuminaCollisionComponent, LuminaCollisionComponent)>[];
    final hitEvents = <(LuminaCollisionComponent, LuminaCollisionComponent, HitResult)>[];

    final currentFrameOverlapPairs = <int>{};
    final currentFrameOverlapsMap = <LuminaCollisionComponent, Set<LuminaCollisionComponent>>{};

    for (final c in _components) {
      currentFrameOverlapsMap[c] = <LuminaCollisionComponent>{};
    }

    final n = _components.length;
    for (int i = 0; i < n; i++) {
      final a = _components[i];
      if (!a.collisionEnabled) continue;

      for (int j = i + 1; j < n; j++) {
        final b = _components[j];
        if (!b.collisionEnabled) continue;

        // Step 1: Layer bitmask & response early exit
        final response = effectiveResponse(a, b);
        if (response == CollisionResponse.ignore) continue;

        // Step 2: AABB overlap early exit
        final aabbA = a.getAABB();
        final aabbB = b.getAABB();
        if (!aabbA.intersectsWithAabb3(aabbB)) continue;

        // Step 3: Narrow phase
        narrowPhaseTestCount++;
        final contact = ContactResult();
        final hit = testPair(a.worldShape, a.worldTransform, b.worldShape, b.worldTransform, contact);
        if (!hit || !contact.isColliding) continue;

        if (response == CollisionResponse.overlap) {
          // Generate Overlap Events: both must ask for them.
          if (!a.generateOverlapEvents || !b.generateOverlapEvents) continue;
          final pairKey = _pairKey(a.componentId, b.componentId);
          currentFrameOverlapPairs.add(pairKey);
          currentFrameOverlapsMap[a]?.add(b);
          currentFrameOverlapsMap[b]?.add(a);

          if (!_activeOverlapPairs.contains(pairKey)) {
            beginOverlapEvents.add((a, b));
          }
        } else if (response == CollisionResponse.block) {
          // A simulating body's contacts raise their hits from the physics
          // solver, by impulse, not every overlapping frame.
          if (a.isSimulatingPhysics || b.isSimulatingPhysics) continue;
          final hitA = HitResult()
            ..blockingHit = true
            ..penetrationDepth = contact.penetrationDepth
            ..impactNormal.setFrom(contact.normal)
            ..impactPoint.setFrom(contact.contactPoint)
            ..location.setFrom(a.worldLocation)
            ..component = b;

          final hitB = HitResult()
            ..blockingHit = true
            ..penetrationDepth = contact.penetrationDepth
            ..impactNormal.setFrom(-contact.normal)
            ..impactPoint.setFrom(contact.contactPoint)
            ..location.setFrom(b.worldLocation)
            ..component = a;

          hitEvents.add((a, b, hitA));
          hitEvents.add((b, a, hitB));
        }
      }
    }

    // Detect ended overlaps
    for (final c in _components) {
      final previousOverlaps = List<LuminaCollisionComponent>.from(c.overlappingComponents);
      final currentOverlaps = currentFrameOverlapsMap[c] ?? <LuminaCollisionComponent>{};

      for (final prev in previousOverlaps) {
        if (!currentOverlaps.contains(prev)) {
          c.removeOverlappingComponent(prev);
          prev.removeOverlappingComponent(c);
          endOverlapEvents.add((c, prev));
        }
      }

      for (final curr in currentOverlaps) {
        c.addOverlappingComponent(curr);
      }
    }

    _activeOverlapPairs.clear();
    _activeOverlapPairs.addAll(currentFrameOverlapPairs);

    _isUpdating = false;

    // Dispatch events: the component delegates, then the actor-level hooks
    // (Blueprint ActorBeginOverlap / ActorEndOverlap / Hit)
    // for the two owners when they differ.
    for (final event in beginOverlapEvents) {
      event.$1.onComponentBeginOverlap?.call(event.$1, event.$2);
      event.$2.onComponentBeginOverlap?.call(event.$2, event.$1);
      _actorOverlap(event.$1, event.$2, begin: true);
      _actorOverlap(event.$2, event.$1, begin: true);
    }

    for (final event in endOverlapEvents) {
      event.$1.onComponentEndOverlap?.call(event.$1, event.$2);
      _actorOverlap(event.$1, event.$2, begin: false);
      _actorOverlap(event.$2, event.$1, begin: false);
    }

    for (final event in hitEvents) {
      event.$1.onComponentHit?.call(event.$1, event.$2, event.$3);
      final self = event.$1.owner, other = event.$2.owner;
      if (self != null && other != null && !identical(self, other)) {
        self.notifyActorHit(other, event.$1, event.$2, event.$3);
      }
    }
  }

  static void _actorOverlap(LuminaCollisionComponent a, LuminaCollisionComponent b, {required bool begin}) {
    final self = a.owner, other = b.owner;
    if (self == null || other == null || identical(self, other)) return;
    if (begin) {
      self.notifyActorBeginOverlap(other, a, b);
      self.broadcastActorEvent(LuminaActor.actorBeginOverlapEvent, {'OverlappedActor': self, 'OtherActor': other});
    } else {
      self.notifyActorEndOverlap(other, a, b);
      self.broadcastActorEvent(LuminaActor.actorEndOverlapEvent, {'OverlappedActor': self, 'OtherActor': other});
    }
  }

  /// Casts a ray through the world and records the first blocking hit in [out].
  bool raycast(
    Vector3 origin,
    Vector3 direction,
    double maxDistance,
    HitResult out, {
    int layerMask = 0xFFFFFFFF,
    LuminaCollisionComponent? ignore,
  }) {
    out.reset();
    final dNorm = direction.normalized();
    double closestT = maxDistance;
    LuminaCollisionComponent? closestComp;
    final closestNormal = Vector3.zero();
    final closestPoint = Vector3.zero();

    for (final c in _components) {
      if (c == ignore || !c.collisionEnabled) continue;
      if ((c.collisionLayer & layerMask) == 0) continue;

      double? t;
      final normal = Vector3.zero();

      switch (c.shapeType) {
        case CollisionShapeType.sphere:
          t = rayVsSphere(origin, dNorm, c.worldLocation, c.radius);
          if (t != null) {
            final hitPt = origin + (dNorm * t);
            normal.setFrom((hitPt - c.worldLocation).normalized());
          }
          break;

        case CollisionShapeType.box:
          t = rayVsBox(origin, dNorm, c.worldTransform, c.boxExtent);
          if (t != null) {
            final hitPt = origin + (dNorm * t);
            final localHit = c.worldRotation.unrotateVector(hitPt - c.worldLocation);
            final ext = c.boxExtent;
            final dx = (localHit.x.abs() - ext.x).abs();
            final dy = (localHit.y.abs() - ext.y).abs();
            final dz = (localHit.z.abs() - ext.z).abs();
            Vector3 localNorm;
            if (dx <= dy && dx <= dz) {
              localNorm = Vector3(localHit.x >= 0 ? 1.0 : -1.0, 0.0, 0.0);
            } else if (dy <= dx && dy <= dz) {
              localNorm = Vector3(0.0, localHit.y >= 0 ? 1.0 : -1.0, 0.0);
            } else {
              localNorm = Vector3(0.0, 0.0, localHit.z >= 0 ? 1.0 : -1.0);
            }
            normal.setFrom(c.worldRotation.rotateVector(localNorm));
          }
          break;

        case CollisionShapeType.capsule:
          final u = c.upVector;
          final segHalf = math.max(0.0, c.halfHeight - c.radius);
          final p1 = c.worldLocation - (u * segHalf);
          final p2 = c.worldLocation + (u * segHalf);
          t = rayVsCapsule(origin, dNorm, p1, p2, c.radius);
          if (t != null) {
            final hitPt = origin + (dNorm * t);
            final seg = p2 - p1;
            final segT = ((hitPt - p1).dot(seg) / seg.length2).clamp(0.0, 1.0);
            final closestSegPt = p1 + (seg * segT);
            normal.setFrom((hitPt - closestSegPt).normalized());
          }
          break;

        case CollisionShapeType.cone:
        case CollisionShapeType.cylinder:
          final aabb = c.getAABB();
          final aabbCenter = (aabb.min + aabb.max) * 0.5;
          final aabbExt = (aabb.max - aabb.min) * 0.5;
          t = rayVsBox(origin, dNorm, Matrix4.translation(aabbCenter), aabbExt);
          if (t != null) {
            normal.setFrom(-dNorm);
          }
          break;

        case CollisionShapeType.convex:
          t = rayVsConvexHull(origin, dNorm, c.convexHull!, c.worldTransform, normal);
          break;

        case CollisionShapeType.heightfield:
          t = rayVsHeightfield(origin, dNorm, c.heightfield!, c.worldTransform, normal);
          break;
      }

      if (t != null && t >= 0.0 && t <= closestT) {
        closestT = t;
        closestComp = c;
        closestNormal.setFrom(normal);
        closestPoint.setFrom(origin + (dNorm * t));
      }
    }

    if (closestComp != null) {
      out.blockingHit = true;
      out.time = closestT;
      out.distance = closestT;
      out.component = closestComp;
      out.location.setFrom(origin);
      out.impactPoint.setFrom(closestPoint);
      out.impactNormal.setFrom(closestNormal);
      return true;
    }

    return false;
  }

  /// Sweeps [shape] along [delta] and returns the earliest blocking collision in [out].
  bool sweep(
    CollisionShape shape,
    Matrix4 start,
    Vector3 delta,
    HitResult out, {
    int layerMask = 0xFFFFFFFF,
    LuminaCollisionComponent? ignore,
  }) {
    out.reset();
    final deltaLen = delta.length;
    if (deltaLen < 1e-9) {
      out.time = 1.0;
      return false;
    }

    double earliestTime = 1.0;
    LuminaCollisionComponent? hitComponent;
    final hitNormal = Vector3.zero();
    final hitPoint = Vector3.zero();

    const int steps = 8;
    final contact = ContactResult();

    for (final c in _components) {
      if (c == ignore || !c.collisionEnabled) continue;
      if ((c.collisionLayer & layerMask) == 0) continue;
      if (ignore != null && effectiveResponse(ignore, c) != CollisionResponse.block) {
        continue;
      }

      final deltaLen = delta.length;
      final deltaDir = deltaLen > 1e-9 ? delta.normalized() : Vector3.zero();
      double tPrev = 0.0;

      for (int step = 0; step <= steps; step++) {
        final t = step / steps;
        final currentPos = start.getTranslation() + (delta * t);
        final currentTransform = start.clone()..setTranslation(currentPos);

        contact.reset();
        final hit = testPair(shape, currentTransform, c.worldShape, c.worldTransform, contact);
        if (hit && contact.isColliding) {
          if (deltaDir.dot(contact.normal) >= -0.01) {
            continue;
          }

          final bestContact = ContactResult()
            ..normal.setFrom(contact.normal)
            ..contactPoint.setFrom(contact.contactPoint);

          // Bisect to refine contact time (low = collision-free, high = colliding)
          double low = tPrev;
          double high = t;
          for (int b = 0; b < 12; b++) {
            final mid = (low + high) * 0.5;
            final midPos = start.getTranslation() + (delta * mid);
            final midTransform = start.clone()..setTranslation(midPos);
            contact.reset();
            if (testPair(shape, midTransform, c.worldShape, c.worldTransform, contact) &&
                contact.isColliding &&
                deltaDir.dot(contact.normal) < -0.01) {
              high = mid;
              bestContact.normal.setFrom(contact.normal);
              bestContact.contactPoint.setFrom(contact.contactPoint);
            } else {
              low = mid;
            }
          }
          final refinedTime = low;
          if (refinedTime < earliestTime) {
            earliestTime = refinedTime;
            hitComponent = c;
            hitNormal.setFrom(bestContact.normal);
            hitPoint.setFrom(bestContact.contactPoint);
          }
          break;
        }
        tPrev = t;
      }
    }

    if (hitComponent != null) {
      out.blockingHit = true;
      out.time = earliestTime;
      out.distance = earliestTime * deltaLen;
      out.component = hitComponent;
      out.location.setFrom(start.getTranslation());
      out.impactNormal.setFrom(hitNormal);
      out.impactPoint.setFrom(hitPoint);
      return true;
    }

    out.time = 1.0;
    return false;
  }

  /// Gathers all registered components overlapping [shape] at [transform].
  int overlapTest(
    CollisionShape shape,
    Matrix4 transform,
    List<LuminaCollisionComponent> outResults, {
    int layerMask = 0xFFFFFFFF,
    LuminaCollisionComponent? ignore,
  }) {
    outResults.clear();
    final contact = ContactResult();
    for (final c in _components) {
      if (c == ignore || !c.collisionEnabled) continue;
      if ((c.collisionLayer & layerMask) == 0) continue;
      contact.reset();
      if (testPair(shape, transform, c.worldShape, c.worldTransform, contact) && contact.isColliding) {
        outResults.add(c);
      }
    }
    return outResults.length;
  }

  /// Whether [c] takes part in a trace with these filters.
  bool _traceable(
    LuminaCollisionComponent c, {
    required List<LuminaActor> ignoreActors,
    required List<LuminaCollisionComponent> ignoreComponents,
    required int layerMask,
    required bool Function(LuminaActor actor)? actorFilter,
    required Set<CollisionObjectType>? objectTypes,
  }) {
    if (!c.collisionEnabled) return false;
    if (objectTypes != null && !objectTypes.contains(c.objectType)) return false;
    if (ignoreComponents.contains(c)) return false;
    final owner = c.owner;
    if (owner != null && ignoreActors.contains(owner)) return false;
    if ((c.collisionLayer & layerMask) == 0) return false;
    if (actorFilter != null && (owner == null || !actorFilter(owner))) return false;
    return true;
  }

  /// The distance along the ray ([start], unit [dir]) at which it enters [c],
  /// and the surface normal there; null when it misses.
  (double, Vector3)? _rayHit(LuminaCollisionComponent c, Vector3 start, Vector3 dir) {
    double? t;
    final normal = Vector3.zero();

    switch (c.shapeType) {
      case CollisionShapeType.sphere:
        t = rayVsSphere(start, dir, c.worldLocation, c.radius);
        if (t != null) {
          final hitPt = start + (dir * t);
          normal.setFrom((hitPt - c.worldLocation).normalized());
        }
        break;

      case CollisionShapeType.box:
        t = rayVsBox(start, dir, c.worldTransform, c.boxExtent);
        if (t != null) {
          final hitPt = start + (dir * t);
          final localHit = c.worldRotation.unrotateVector(hitPt - c.worldLocation);
          final ext = c.boxExtent;
          final dx = (localHit.x.abs() - ext.x).abs();
          final dy = (localHit.y.abs() - ext.y).abs();
          final dz = (localHit.z.abs() - ext.z).abs();
          Vector3 localNorm;
          if (dx <= dy && dx <= dz) {
            localNorm = Vector3(localHit.x >= 0 ? 1.0 : -1.0, 0.0, 0.0);
          } else if (dy <= dx && dy <= dz) {
            localNorm = Vector3(0.0, localHit.y >= 0 ? 1.0 : -1.0, 0.0);
          } else {
            localNorm = Vector3(0.0, 0.0, localHit.z >= 0 ? 1.0 : -1.0);
          }
          normal.setFrom(c.worldRotation.rotateVector(localNorm));
        }
        break;

      case CollisionShapeType.capsule:
        final u = c.upVector;
        final segHalf = math.max(0.0, c.halfHeight - c.radius);
        final p1 = c.worldLocation - (u * segHalf);
        final p2 = c.worldLocation + (u * segHalf);
        t = rayVsCapsule(start, dir, p1, p2, c.radius);
        if (t != null) {
          final hitPt = start + (dir * t);
          final seg = p2 - p1;
          final segT = ((hitPt - p1).dot(seg) / seg.length2).clamp(0.0, 1.0);
          final closestSegPt = p1 + (seg * segT);
          normal.setFrom((hitPt - closestSegPt).normalized());
        }
        break;

      case CollisionShapeType.cone:
      case CollisionShapeType.cylinder:
        final aabb = c.getAABB();
        final aabbCenter = (aabb.min + aabb.max) * 0.5;
        final aabbExt = (aabb.max - aabb.min) * 0.5;
        t = rayVsBox(start, dir, Matrix4.translation(aabbCenter), aabbExt);
        if (t != null) {
          normal.setFrom(-dir);
        }
        break;

      case CollisionShapeType.convex:
        t = rayVsConvexHull(start, dir, c.convexHull!, c.worldTransform, normal);
        break;

      case CollisionShapeType.heightfield:
        t = rayVsHeightfield(start, dir, c.heightfield!, c.worldTransform, normal);
        break;
    }
    return t == null ? null : (t, normal);
  }

  /// Traces a single ray from [start] to [end] and records the nearest
  /// blocking hit in [out], ignoring [ignoreActors] and [ignoreComponents];
  /// [actorFilter] keeps only components whose owner passes (a trace node's
  /// class filter).
  bool lineTraceSingle({
    required Vector3 start,
    required Vector3 end,
    required HitResult out,
    List<LuminaActor> ignoreActors = const [],
    List<LuminaCollisionComponent> ignoreComponents = const [],
    int layerMask = 0xFFFFFFFF,
    bool Function(LuminaActor actor)? actorFilter,
    Set<CollisionObjectType>? objectTypes,
  }) {
    out.reset();
    final hits = lineTraceMulti(
      start: start,
      end: end,
      ignoreActors: ignoreActors,
      ignoreComponents: ignoreComponents,
      layerMask: layerMask,
      actorFilter: actorFilter,
      objectTypes: objectTypes,
      firstOnly: true,
    );
    if (hits.isEmpty) return false;
    _copyHit(hits.first, out);
    return true;
  }

  static void _copyHit(HitResult from, HitResult to) {
    to
      ..blockingHit = from.blockingHit
      ..time = from.time
      ..distance = from.distance
      ..penetrationDepth = from.penetrationDepth
      ..component = from.component;
    to.location.setFrom(from.location);
    to.impactPoint.setFrom(from.impactPoint);
    to.impactNormal.setFrom(from.impactNormal);
  }

  /// Every component the ray from [start] to [end] enters, nearest first
  /// (Multi Line Trace), each hit carrying its actor and distance.
  /// [firstOnly] keeps just the nearest (what [lineTraceSingle] uses).
  List<HitResult> lineTraceMulti({
    required Vector3 start,
    required Vector3 end,
    List<LuminaActor> ignoreActors = const [],
    List<LuminaCollisionComponent> ignoreComponents = const [],
    int layerMask = 0xFFFFFFFF,
    bool Function(LuminaActor actor)? actorFilter,
    Set<CollisionObjectType>? objectTypes,
    bool firstOnly = false,
  }) {
    final delta = end - start;
    final dist = delta.length;
    if (dist < 1e-9) return const [];
    final dir = delta / dist;
    final hits = <HitResult>[];
    for (final c in _components) {
      if (!_traceable(c, ignoreActors: ignoreActors, ignoreComponents: ignoreComponents, layerMask: layerMask,
          actorFilter: actorFilter, objectTypes: objectTypes)) {
        continue;
      }
      final r = _rayHit(c, start, dir);
      if (r == null) continue;
      final (t, normal) = r;
      if (t < 0.0 || t > dist) continue;
      final hit = HitResult()
        ..blockingHit = true
        ..time = t / dist
        ..distance = t
        ..component = c;
      hit.location.setFrom(start);
      hit.impactPoint.setFrom(start + dir * t);
      hit.impactNormal.setFrom(normal);
      if (firstOnly) {
        if (hits.isEmpty) {
          hits.add(hit);
        } else if (t <= hits.first.distance) {
          hits[0] = hit;
        }
      } else {
        hits.add(hit);
      }
    }
    hits.sort((a, b) => a.distance.compareTo(b.distance));
    return hits;
  }

  /// Sweeps a sphere of [radius] from [start] to [end] and records the
  /// nearest blocking hit in [out] (Sphere Trace By Channel).
  bool sphereTraceSingle({
    required Vector3 start,
    required Vector3 end,
    required double radius,
    required HitResult out,
    List<LuminaActor> ignoreActors = const [],
    List<LuminaCollisionComponent> ignoreComponents = const [],
    int layerMask = 0xFFFFFFFF,
    bool Function(LuminaActor actor)? actorFilter,
    Set<CollisionObjectType>? objectTypes,
  }) {
    out.reset();
    final hits = sphereTraceMulti(
      start: start,
      end: end,
      radius: radius,
      ignoreActors: ignoreActors,
      ignoreComponents: ignoreComponents,
      layerMask: layerMask,
      actorFilter: actorFilter,
      objectTypes: objectTypes,
    );
    if (hits.isEmpty) return false;
    _copyHit(hits.first, out);
    return true;
  }

  /// Every component a sphere of [radius] swept from [start] to [end]
  /// touches, nearest first, through the narrow phase (sampled along the
  /// sweep, then bisected to the contact). [HitResult.location] is the sphere
  /// centre at contact, [HitResult.impactPoint] the contact on the surface.
  List<HitResult> sphereTraceMulti({
    required Vector3 start,
    required Vector3 end,
    required double radius,
    List<LuminaActor> ignoreActors = const [],
    List<LuminaCollisionComponent> ignoreComponents = const [],
    int layerMask = 0xFFFFFFFF,
    bool Function(LuminaActor actor)? actorFilter,
    Set<CollisionObjectType>? objectTypes,
  }) {
    final delta = end - start;
    final dist = delta.length;
    final shape = SphereShape(math.max(radius, 1e-6));
    // Sample every half radius so a shape thinner than the sphere is not stepped over.
    final steps = dist < 1e-9 ? 1 : math.min(4096, math.max(8, (dist / math.max(radius * 0.5, 1.0)).ceil()));
    final contact = ContactResult();
    final hits = <HitResult>[];
    Matrix4 at(double t) => Matrix4.translation(start + delta * t);
    for (final c in _components) {
      if (!_traceable(c, ignoreActors: ignoreActors, ignoreComponents: ignoreComponents, layerMask: layerMask,
          actorFilter: actorFilter, objectTypes: objectTypes)) {
        continue;
      }
      // Broad phase: the sweep's AABB against the component's.
      final aabb = c.getAABB();
      final sweepMin = Vector3(math.min(start.x, end.x) - radius, math.min(start.y, end.y) - radius, math.min(start.z, end.z) - radius);
      final sweepMax = Vector3(math.max(start.x, end.x) + radius, math.max(start.y, end.y) + radius, math.max(start.z, end.z) + radius);
      if (!Aabb3.minMax(sweepMin, sweepMax).intersectsWithAabb3(aabb)) continue;
      double? low;
      double? high;
      for (var step = 0; step <= steps; step++) {
        final t = step / steps;
        contact.reset();
        if (testPair(shape, at(t), c.worldShape, c.worldTransform, contact) && contact.isColliding) {
          high = t;
          low = step == 0 ? null : (step - 1) / steps;
          break;
        }
      }
      if (high == null) continue;
      var contactT = high;
      if (low != null) {
        var lo = low, hi = high;
        for (var i = 0; i < 12; i++) {
          final mid = (lo + hi) * 0.5;
          contact.reset();
          if (testPair(shape, at(mid), c.worldShape, c.worldTransform, contact) && contact.isColliding) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        contactT = hi;
      }
      contact.reset();
      testPair(shape, at(contactT), c.worldShape, c.worldTransform, contact);
      final hit = HitResult()
        ..blockingHit = true
        ..time = contactT
        ..distance = contactT * dist
        ..penetrationDepth = contact.penetrationDepth
        ..component = c;
      hit.location.setFrom(start + delta * contactT);
      hit.impactPoint.setFrom(contact.contactPoint);
      hit.impactNormal.setFrom(contact.normal.length2 > 1e-12 ? contact.normal : -delta.normalized());
      hits.add(hit);
    }
    hits.sort((a, b) => a.distance.compareTo(b.distance));
    return hits;
  }

  /// The actors (deduplicated, nearest first) with a component overlapping a
  /// sphere of [radius] at [location] (Sphere Overlap Actors).
  List<LuminaActor> sphereOverlapActors(
    Vector3 location,
    double radius, {
    List<LuminaActor> ignoreActors = const [],
    int layerMask = 0xFFFFFFFF,
    bool Function(LuminaActor actor)? actorFilter,
  }) {
    final results = <LuminaCollisionComponent>[];
    overlapTest(SphereShape(radius), Matrix4.translation(location), results, layerMask: layerMask);
    final actors = <LuminaActor>[];
    for (final c in results) {
      final owner = c.owner;
      if (owner == null || actors.contains(owner) || ignoreActors.contains(owner)) continue;
      if (actorFilter != null && !actorFilter(owner)) continue;
      actors.add(owner);
    }
    actors.sort((a, b) => (a.actorLocation - location).length2.compareTo((b.actorLocation - location).length2));
    return actors;
  }
}
