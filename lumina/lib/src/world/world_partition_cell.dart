import 'package:vector_math/vector_math_64.dart';
import '../object/actor.dart';
import 'data_layer.dart';

/// 6-state lifecycle for World Partition cells.
enum CellState {
  unloaded,
  loading,
  loaded,
  activated,
  deactivated,
  unloading,
}

/// A spatial grid cell within World Partition holding regional actors.
class LuminaWorldPartitionCell {
  final int cellX;
  final int cellY;
  final double cellSize;
  final List<LuminaActor> actors = [];
  final Set<LuminaDataLayer> dataLayers = {};

  CellState _state = CellState.unloaded;
  CellState get state => _state;

  /// Whether actors in this cell should be actively ticked.
  bool get isTicking => _state == CellState.activated;

  /// Hook for observing cell state transitions.
  void Function(CellState oldState, CellState newState)? onStateChanged;

  LuminaWorldPartitionCell({
    required this.cellX,
    required this.cellY,
    required this.cellSize,
  });

  /// 2D ground plane centre of this cell: `(world X, world Z)`.
  Vector2 get center => Vector2(
        (cellX + 0.5) * cellSize,
        (cellY + 0.5) * cellSize,
      );

  /// 3D Axis-Aligned Bounding Box enclosing this cell: bounded on the X/Z
  /// ground plane and effectively unbounded in height, because Y is up.
  Aabb3 get bounds => Aabb3.minMax(
        Vector3(cellX * cellSize, -1000000.0, cellY * cellSize),
        Vector3((cellX + 1) * cellSize, 1000000.0, (cellY + 1) * cellSize),
      );

  /// Transitions cell from unloaded -> loading -> loaded.
  Future<void> loadAsync() async {
    if (_state != CellState.unloaded) return;
    transitionTo(CellState.loading);
    // Simulate async data retrieval / actor preparation
    await Future.microtask(() {});
    transitionTo(CellState.loaded);
  }

  /// Transitions cell from (loaded | deactivated) -> activated.
  void activate() {
    if (_state == CellState.loaded || _state == CellState.deactivated) {
      transitionTo(CellState.activated);
    }
  }

  /// Transitions cell from activated -> deactivated.
  void deactivate() {
    if (_state == CellState.activated) {
      transitionTo(CellState.deactivated);
    }
  }

  /// Transitions cell from (loaded | deactivated) -> unloading -> unloaded.
  Future<void> unloadAsync() async {
    if (_state != CellState.loaded && _state != CellState.deactivated) return;
    transitionTo(CellState.unloading);
    await Future.microtask(() {});
    transitionTo(CellState.unloaded);
  }

  /// Direct guarded state transition.
  void transitionTo(CellState newState) {
    if (_state == newState) return;
    final oldState = _state;
    _state = newState;
    onStateChanged?.call(oldState, newState);
  }
}
