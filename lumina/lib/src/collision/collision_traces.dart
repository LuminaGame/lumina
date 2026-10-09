part of 'package:lumina/src/collision/collision_subsystem.dart';

/// The trace queries of [LuminaCollisionSubsystem]: line traces, sphere
/// traces and sphere overlaps, with the actor filters the trace nodes use.
///
/// A line trace's [HitResult.location] is its [HitResult.impactPoint]; a
/// sphere trace's is the sphere's centre at contact. Every hit carries the
/// trace's start and end, its [HitResult.time] (fraction of the trace) and its
/// [HitResult.distance] (from the start to the location).
extension LuminaCollisionTraces on LuminaCollisionSubsystem {
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
    out.copyFrom(hits.first);
    return true;
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
      // A ray has no extent: it stops where it hits.
      hit.impactPoint.setFrom(start + dir * t);
      hit.location.setFrom(hit.impactPoint);
      hit.impactNormal.setFrom(normal);
      hit.normal.setFrom(normal);
      hit.traceStart.setFrom(start);
      hit.traceEnd.setFrom(end);
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
    out.copyFrom(hits.first);
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
      hit.normal.setFrom(_sweepNormal(shape, Matrix4.translation(hit.location), hit.impactPoint, hit.impactNormal));
      hit.traceStart.setFrom(start);
      hit.traceEnd.setFrom(end);
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
