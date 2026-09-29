import '../world.dart';
import 'world_subsystem.dart';

/// Collection manager for [LuminaWorldSubsystem] instances.
/// Provides O(1) dual-indexed generic lookup and deterministic registration-order execution.
class LuminaSubsystemCollection {
  final Map<Type, LuminaWorldSubsystem> _subsystems = {};
  final List<LuminaWorldSubsystem> _orderedSubsystems = [];
  bool _isIterating = false;

  /// Number of registered subsystems.
  int get length => _orderedSubsystems.length;

  /// Whether a subsystem of type [T] is registered.
  bool contains<T extends LuminaWorldSubsystem>() => _subsystems.containsKey(T);

  /// Registers a subsystem with the world, indexed by runtimeType and declared static type [T].
  void registerSubsystem<T extends LuminaWorldSubsystem>(T subsystem, LuminaWorld world) {
    if (_isIterating) {
      throw StateError('Cannot register subsystem during tick or shutdown iteration.');
    }

    final concreteType = subsystem.runtimeType;
    if (_subsystems.containsKey(concreteType) || (T != LuminaWorldSubsystem && _subsystems.containsKey(T))) {
      throw StateError('Subsystem of type $concreteType (or $T) is already registered.');
    }

    _subsystems[concreteType] = subsystem;
    if (T != concreteType && T != LuminaWorldSubsystem) {
      _subsystems[T] = subsystem;
    }

    _orderedSubsystems.add(subsystem);
    subsystem.onWorldInitialize(world);
  }

  /// Retrieves a registered subsystem of type [T] in O(1) time.
  T? getSubsystem<T extends LuminaWorldSubsystem>() {
    return _subsystems[T] as T?;
  }

  /// Notifies all registered subsystems of [beginPlay] in registration order.
  void notifyBeginPlay() {
    for (final sys in _orderedSubsystems) {
      sys.onWorldBeginPlay();
    }
  }

  /// Notifies all registered subsystems of frame tick in registration order.
  void notifyTick(double deltaTime) {
    _isIterating = true;
    try {
      for (final sys in _orderedSubsystems) {
        sys.onWorldTick(deltaTime);
      }
    } finally {
      _isIterating = false;
    }
  }

  /// Notifies all registered subsystems of a world pause/resume in registration order.
  void notifyPauseChanged(bool paused) {
    for (final sys in _orderedSubsystems) {
      sys.onWorldPauseChanged(paused);
    }
  }

  /// Shuts down all registered subsystems in reverse registration order and clears the collection.
  void shutdown() {
    if (_orderedSubsystems.isEmpty) return;

    _isIterating = true;
    try {
      for (final sys in _orderedSubsystems.reversed) {
        sys.onWorldShutdown();
      }
    } finally {
      _isIterating = false;
    }

    _orderedSubsystems.clear();
    _subsystems.clear();
  }
}
