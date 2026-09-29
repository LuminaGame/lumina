import 'dart:async';

/// 3-state runtime lifecycle for World Partition Data Layers.
enum DataLayerState {
  unloaded,
  loaded,
  activated,
}

/// Logical Data Layer used to group actors independently of spatial location.
class LuminaDataLayer {
  final String name;
  DataLayerState _state;
  final bool bIsRuntime;

  LuminaDataLayer({
    required this.name,
    DataLayerState initialState = DataLayerState.unloaded,
    this.bIsRuntime = true,
  }) : _state = initialState;

  /// Current runtime state of this data layer.
  DataLayerState get state => _state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaDataLayer && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'LuminaDataLayer($name, state: $_state)';
}

/// Manages logical data layer registrations, runtime state mutations, and change notifications.
class LuminaDataLayerManager {
  final Map<String, LuminaDataLayer> _layers = {};
  final StreamController<({String layer, DataLayerState from, DataLayerState to})>
      _stateChangeController =
      StreamController<({String layer, DataLayerState from, DataLayerState to})>.broadcast();

  /// Stream of state changes across all registered data layers.
  Stream<({String layer, DataLayerState from, DataLayerState to})> get onLayerStateChanged =>
      _stateChangeController.stream;

  /// Registers a logical data layer.
  LuminaDataLayer registerLayer(
    String name, {
    DataLayerState initialState = DataLayerState.unloaded,
    bool bIsRuntime = true,
  }) {
    return _layers.putIfAbsent(
      name,
      () => LuminaDataLayer(
        name: name,
        initialState: initialState,
        bIsRuntime: bIsRuntime,
      ),
    );
  }

  /// Finds a data layer by name if registered.
  LuminaDataLayer? findLayer(String name) {
    return _layers[name];
  }

  /// Gets the current state of a registered data layer.
  DataLayerState? getDataLayerState(String name) {
    return _layers[name]?.state;
  }

  /// Sets the runtime state of a data layer and notifies subscribers if changed.
  void setDataLayerState(String name, DataLayerState newState) {
    final layer = _layers[name];
    if (layer == null) return;
    if (layer._state == newState) return;

    final fromState = layer._state;
    layer._state = newState;
    _stateChangeController.add((layer: name, from: fromState, to: newState));
  }

  /// Snapshots the states of all registered data layers for game saving.
  Map<String, DataLayerState> snapshotStates() {
    return {
      for (final entry in _layers.entries) entry.key: entry.value.state,
    };
  }

  /// Restores data layer states from a saved game snapshot.
  void restoreStates(Map<String, DataLayerState> states) {
    for (final entry in states.entries) {
      setDataLayerState(entry.key, entry.value);
    }
  }

  /// Disposes stream controller.
  void dispose() {
    _stateChangeController.close();
  }
}
