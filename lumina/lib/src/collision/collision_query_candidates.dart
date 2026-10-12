part of 'package:lumina/src/collision/collision_subsystem.dart';

/// The components a query or the overlap pass tests: every registered one,
/// or (with a broad phase) only those whose bounds the query may touch, in
/// registration order either way, so both give the same results.
extension _LuminaCollisionCandidates on LuminaCollisionSubsystem {
  /// The broad phase to use now, created when [queryBackend] (or the
  /// default) asks for one and it can run here; null tests every component.
  LuminaCollisionQueryAccelerator? _queryAccelerator() {
    final kind = queryBackend ?? LuminaCollisionSubsystem.defaultQueryBackend;
    if (kind == LuminaCollisionQueryBackendKind.dart) {
      _accelerator?.dispose();
      _accelerator = null;
      return null;
    }
    final existing = _accelerator;
    if (existing != null) return existing;
    if (_acceleratorUnavailable) return null;
    if (kind == LuminaCollisionQueryBackendKind.auto &&
        _components.length < LuminaCollisionSubsystem.autoAcceleratorThreshold) {
      return null;
    }
    final created = createJoltCollisionQueries();
    if (created == null) {
      _acceleratorUnavailable = true;
      return null;
    }
    for (final c in _components) {
      created.add(c);
    }
    return _accelerator = created;
  }

  List<LuminaCollisionComponent> _inOrder(Iterable<LuminaCollisionComponent> candidates) {
    final list = candidates.where(_ordinal.containsKey).toList();
    list.sort((a, b) => _ordinal[a]!.compareTo(_ordinal[b]!));
    return list;
  }

  /// The components registered after [a] whose bounds may overlap its own.
  List<LuminaCollisionComponent> _laterCandidates(
    LuminaCollisionComponent a,
    LuminaCollisionQueryAccelerator broadPhase,
  ) {
    final mine = _ordinal[a]!;
    return _inOrder(broadPhase.inBox(a.getAABB()).where((b) => _ordinal[b]! > mine));
  }

  /// The components a segment from [start] to [end] may enter.
  List<LuminaCollisionComponent> _alongSegment(Vector3 start, Vector3 end) {
    final broadPhase = _queryAccelerator();
    if (broadPhase == null || !_finite(start) || !_finite(end)) return _components;
    return _inOrder(broadPhase.alongSegment(start, end));
  }

  /// The components [shape] at [start] swept by [delta] may touch.
  List<LuminaCollisionComponent> _sweptBy(CollisionShape shape, Matrix4 start, Vector3 delta) {
    final broadPhase = _queryAccelerator();
    final reach = broadPhase == null ? null : _boundingRadius(shape, start);
    if (broadPhase == null || reach == null) return _components;
    final from = start.getTranslation();
    if (!_finite(from) || !_finite(delta)) return _components;
    final box = Aabb3.minMax(from - Vector3.all(reach), from + Vector3.all(reach));
    return _inOrder(delta.length2 > 0 ? broadPhase.alongSweep(box, delta) : broadPhase.inBox(box));
  }

  static bool _finite(Vector3 v) => v.x.isFinite && v.y.isFinite && v.z.isFinite;

  /// A sphere around [shape]'s centre at [at] that holds all of it (cm), or
  /// null for a shape without a simple bound.
  static double? _boundingRadius(CollisionShape shape, Matrix4 at) {
    final scale = math.max(
      Vector3(at.entry(0, 0), at.entry(1, 0), at.entry(2, 0)).length,
      math.max(
        Vector3(at.entry(0, 1), at.entry(1, 1), at.entry(2, 1)).length,
        Vector3(at.entry(0, 2), at.entry(1, 2), at.entry(2, 2)).length,
      ),
    );
    final double? local = switch (shape) {
      SphereShape s => s.radius,
      CapsuleShape s => math.max(s.radius, s.halfHeight),
      BoxShape s => s.halfExtents.length,
      ConeShape s => math.sqrt(s.radius * s.radius + s.height * s.height),
      CylinderShape s => math.sqrt(s.radius * s.radius + s.height * s.height / 4),
      _ => null,
    };
    return local == null ? null : local * math.max(scale, 1.0) + 0.01;
  }
}
