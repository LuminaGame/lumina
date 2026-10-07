import 'package:lumina/src/declarative/build_context.dart';
import 'package:lumina/src/declarative/lumina_object.dart';

/// Heavy runtime tier object that holds persistent native handles (Filament entities, physics bodies).
/// Survives declarative rebuilds and is updated in place to prevent frame drops.
abstract class LuminaRuntimeObject {
  /// Whether this runtime object is currently attached to an active element.
  bool get isAttached;

  /// Acquires native resources and binds to the active build context.
  void attach(LuminaBuildContext context);

  /// Updates internal native state and parameters with a new declarative configuration.
  void update(covariant LuminaObject newConfig);

  /// Detaches from the active context and releases (or resets) native resources.
  void detach();
}

/// Declarative configuration node that instantiates and updates a corresponding [LuminaRuntimeObject].
abstract class LuminaRuntimeObjectNode extends LuminaObject {
  const LuminaRuntimeObjectNode({super.key});

  /// Instantiates a new runtime object for this declarative node.
  LuminaRuntimeObject createRuntimeObject(LuminaBuildContext context);

  /// Mutates an existing runtime object with this node's updated parameters.
  void updateRuntimeObject(covariant LuminaRuntimeObject runtimeObject);
}

/// Lightweight, allocation-free object pool for reusing frequently allocated engine objects.
class LuminaObjectPool<T> {
  final T Function() create;
  final void Function(T) reset;
  final int maxSize;
  final List<T> _pool = [];
  int _createCount = 0;

  LuminaObjectPool({
    required this.create,
    required this.reset,
    this.maxSize = 64,
  });

  /// Retrieves an instance from the pool or creates a new one if the pool is empty.
  T acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }
    _createCount++;
    return create();
  }

  /// Resets an instance and returns it to the pool if below [maxSize].
  void release(T obj) {
    reset(obj);
    if (_pool.length < maxSize) {
      _pool.add(obj);
    }
  }

  /// Number of idle objects currently in the pool.
  int get pooledCount => _pool.length;

  /// Total number of allocations created by this pool.
  int get createCount => _createCount;
}
