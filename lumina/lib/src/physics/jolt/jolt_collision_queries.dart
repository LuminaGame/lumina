import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_query_accelerator.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';

/// The collision subsystem's queries on Jolt's broad phase: every collision
/// component is a box proxy (its bounds, in metres, a little grown so float
/// rounding never loses one) in a Jolt world of its own that is never
/// stepped; a query asks the broad phase which proxies it crosses. Moved
/// components are updated before the next query, and the tree is rebuilt
/// once many moved (until then it may report a moved component where it
/// was too, which the narrow phase rejects).
class LuminaJoltCollisionQueries implements LuminaCollisionQueryAccelerator {
  LuminaJoltCollisionQueries({int maxComponents = 65536})
    : _world = JoltWorld(maxBodies: maxComponents, workerThreads: 0);

  final JoltWorld _world;
  final Map<LuminaCollisionComponent, (int, int)> _proxies = {};
  final List<LuminaCollisionComponent?> _bySlot = [];
  final List<int> _freeSlots = [];
  final Set<LuminaCollisionComponent> _dirty = {};
  int _movedSinceRebuild = 0;
  bool _disposed = false;

  /// Grows every proxy and query box by this much (cm).
  static const double margin = 0.5;

  @override
  String get name => 'jolt';

  /// How many components have a proxy (tests and diagnostics).
  int get proxyCount => _proxies.length;

  (Vector3, Vector3) _bounds(LuminaCollisionComponent c) {
    final box = c.getAABB();
    return ((box.min - Vector3.all(margin)) * kJoltScale, (box.max + Vector3.all(margin)) * kJoltScale);
  }

  @override
  void add(LuminaCollisionComponent component) {
    if (_disposed || _proxies.containsKey(component)) return;
    final slot = _freeSlots.isNotEmpty ? _freeSlots.removeLast() : _bySlot.length;
    if (slot == _bySlot.length) {
      _bySlot.add(component);
    } else {
      _bySlot[slot] = component;
    }
    final (min, max) = _bounds(component);
    _proxies[component] = (_world.addBoxProxy(min, max, slot), slot);
  }

  @override
  void remove(LuminaCollisionComponent component) {
    final proxy = _proxies.remove(component);
    _dirty.remove(component);
    if (proxy == null || _disposed) return;
    _world.destroyBody(proxy.$1);
    _bySlot[proxy.$2] = null;
    _freeSlots.add(proxy.$2);
  }

  @override
  void dirty(LuminaCollisionComponent component) {
    if (_proxies.containsKey(component)) _dirty.add(component);
  }

  void _sync() {
    if (_dirty.isEmpty) return;
    for (final c in _dirty) {
      final proxy = _proxies[c];
      if (proxy == null) continue;
      final (min, max) = _bounds(c);
      _world.setBoxProxy(proxy.$1, min, max);
    }
    _movedSinceRebuild += _dirty.length;
    _dirty.clear();
    if (_movedSinceRebuild > 64 && _movedSinceRebuild * 8 > _proxies.length) {
      _world.optimizeBroadPhase();
      _movedSinceRebuild = 0;
    }
  }

  Iterable<LuminaCollisionComponent> _components(List<int> slots) sync* {
    for (final s in slots) {
      final c = s < _bySlot.length ? _bySlot[s] : null;
      if (c != null) yield c;
    }
  }

  @override
  Iterable<LuminaCollisionComponent> alongSegment(Vector3 start, Vector3 end) {
    if (_disposed) return const [];
    _sync();
    return _components(_world.broadPhaseRay(start * kJoltScale, (end - start) * kJoltScale));
  }

  @override
  Iterable<LuminaCollisionComponent> alongSweep(Aabb3 box, Vector3 delta) {
    if (_disposed) return const [];
    _sync();
    return _components(
      _world.broadPhaseBoxCast(
        (box.min - Vector3.all(margin)) * kJoltScale,
        (box.max + Vector3.all(margin)) * kJoltScale,
        delta * kJoltScale,
      ),
    );
  }

  @override
  Iterable<LuminaCollisionComponent> inBox(Aabb3 box) {
    if (_disposed) return const [];
    _sync();
    return _components(
      _world.broadPhaseBox((box.min - Vector3.all(margin)) * kJoltScale, (box.max + Vector3.all(margin)) * kJoltScale),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _proxies.clear();
    _bySlot.clear();
    _dirty.clear();
    _world.dispose();
  }
}
