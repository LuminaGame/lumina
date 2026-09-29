import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../object/actor.dart';
import 'data_layer.dart';
import 'streaming_source.dart';
import 'subsystem/world_subsystem.dart';
import 'world_partition_cell.dart';

export 'data_layer.dart';
export 'streaming_source.dart';
export 'world_partition_cell.dart';

/// Spatially partitioned world subsystem managing 2D grid cells, data layers, and seamless streaming.
class LuminaWorldPartitionSubsystem extends LuminaWorldSubsystem {
  final double cellSize;
  final int maxCellTransitionsPerTick;

  final Map<int, LuminaWorldPartitionCell> _cells = {};
  final Map<LuminaActor, (int, int)> _actorCellIndex = {};
  final Map<LuminaActor, Set<String>> _actorDataLayers = {};
  final Set<LuminaStreamingSourceComponent> _streamingSources = {};

  /// Logical Data Layer manager for this World Partition subsystem.
  final LuminaDataLayerManager dataLayerManager = LuminaDataLayerManager();

  LuminaWorldPartitionSubsystem({
    this.cellSize = 12800.0, // cm
    this.maxCellTransitionsPerTick = 10,
  });

  /// Backward-compatible alias for dataLayers.
  Map<String, LuminaDataLayer> get dataLayers => dataLayerManager.snapshotStates().map(
        (key, value) => MapEntry(key, LuminaDataLayer(name: key, initialState: value)),
      );

  /// All registered streaming sources.
  List<LuminaStreamingSourceComponent> get streamingSources => _streamingSources.toList();

  /// Total number of instantiated cells in the sparse spatial map.
  int get cellCount => _cells.length;

  /// Registers a streaming source with this World Partition subsystem.
  void registerSource(LuminaStreamingSourceComponent source) {
    _streamingSources.add(source);
  }

  /// Unregisters a streaming source from this World Partition subsystem.
  void unregisterSource(LuminaStreamingSourceComponent source) {
    _streamingSources.remove(source);
  }

  /// Assigns an actor to a logical data layer.
  void assignActorToLayer(LuminaActor actor, String layerName) {
    _actorDataLayers.putIfAbsent(actor, () => {}).add(layerName);

    final layer = dataLayerManager.registerLayer(layerName);
    final coords = _actorCellIndex[actor];
    if (coords != null) {
      final cell = _cells[cellKey(coords.$1, coords.$2)];
      cell?.dataLayers.add(layer);
    }
  }

  /// Removes an actor from a logical data layer.
  void removeActorFromLayer(LuminaActor actor, String layerName) {
    final layers = _actorDataLayers[actor];
    layers?.remove(layerName);
    if (layers != null && layers.isEmpty) {
      _actorDataLayers.remove(actor);
    }

    final coords = _actorCellIndex[actor];
    if (coords != null) {
      final cell = _cells[cellKey(coords.$1, coords.$2)];
      if (cell != null) {
        // Re-evaluate cell.dataLayers
        final hasOtherActorWithLayer = cell.actors.any((a) => _actorDataLayers[a]?.contains(layerName) == true);
        if (!hasOtherActorWithLayer) {
          cell.dataLayers.removeWhere((l) => l.name == layerName);
        }
      }
    }
  }

  /// Returns the set of data layer names assigned to this actor.
  Set<String> getActorLayers(LuminaActor actor) {
    return _actorDataLayers[actor] ?? const {};
  }

  /// Fast 64-bit integer spatial hash combining two 32-bit integers.
  static int cellKey(int x, int y) {
    return (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32);
  }

  /// Retrieves or creates the grid cell at the given 3D world position.
  /// The grid is a partition of the **ground plane**: axis 1 is world X and
  /// axis 2 is world Z, because Y is the up axis everywhere in lumina. Using Y
  /// here made cells vertical slabs.
  LuminaWorldPartitionCell cellAt(Vector3 worldPos) {
    final cellX = (worldPos.x / cellSize).floor();
    final cellY = (worldPos.z / cellSize).floor();
    final key = cellKey(cellX, cellY);

    return _cells.putIfAbsent(
      key,
      () => LuminaWorldPartitionCell(
        cellX: cellX,
        cellY: cellY,
        cellSize: cellSize,
      ),
    );
  }

  /// The grid coordinates an actor currently occupies, or null.
  (int, int)? cellCoordsOfActor(LuminaActor actor) => _actorCellIndex[actor];

  /// Retrieves a cell by discrete grid coordinates if already instantiated.
  LuminaWorldPartitionCell? cellByCoords(int x, int y) {
    return _cells[cellKey(x, y)];
  }

  /// Adds an actor to the appropriate spatial grid cell based on world position.
  void addActor(LuminaActor actor, Vector3 location) {
    final cellX = (location.x / cellSize).floor();
    final cellY = (location.z / cellSize).floor();
    final key = cellKey(cellX, cellY);

    final cell = _cells.putIfAbsent(
      key,
      () => LuminaWorldPartitionCell(
        cellX: cellX,
        cellY: cellY,
        cellSize: cellSize,
      ),
    );

    cell.actors.add(actor);
    _actorCellIndex[actor] = (cellX, cellY);

    final actorLayers = _actorDataLayers[actor];
    if (actorLayers != null) {
      for (final layerName in actorLayers) {
        final layer = dataLayerManager.registerLayer(layerName);
        cell.dataLayers.add(layer);
      }
    }
  }

  /// Updates actor cell assignment when moving across cell boundaries.
  void moveActor(LuminaActor actor, Vector3 newLocation) {
    final newCellX = (newLocation.x / cellSize).floor();
    final newCellY = (newLocation.z / cellSize).floor();

    final oldCoords = _actorCellIndex[actor];
    if (oldCoords != null && oldCoords.$1 == newCellX && oldCoords.$2 == newCellY) {
      // Still inside the same cell
      return;
    }

    if (oldCoords != null) {
      final oldCell = _cells[cellKey(oldCoords.$1, oldCoords.$2)];
      oldCell?.actors.remove(actor);
    }

    final newKey = cellKey(newCellX, newCellY);
    final newCell = _cells.putIfAbsent(
      newKey,
      () => LuminaWorldPartitionCell(
        cellX: newCellX,
        cellY: newCellY,
        cellSize: cellSize,
      ),
    );

    newCell.actors.add(actor);
    _actorCellIndex[actor] = (newCellX, newCellY);

    final actorLayers = _actorDataLayers[actor];
    if (actorLayers != null) {
      for (final layerName in actorLayers) {
        final layer = dataLayerManager.registerLayer(layerName);
        newCell.dataLayers.add(layer);
      }
    }
  }

  /// Removes an actor from its assigned cell in O(1) time.
  void removeActor(LuminaActor actor) {
    final coords = _actorCellIndex.remove(actor);
    if (coords != null) {
      final cell = _cells[cellKey(coords.$1, coords.$2)];
      cell?.actors.remove(actor);
    }
    _actorDataLayers.remove(actor);
  }

  /// Queries all cells whose centers fall within the given radius from center.
  /// Bounded window scan only (never a full-map scan).
  Iterable<LuminaWorldPartitionCell> queryCellsInRadius(Vector3 center, double radius) sync* {
    final minX = ((center.x - radius) / cellSize).floor();
    final maxX = ((center.x + radius) / cellSize).floor();
    final minY = ((center.z - radius) / cellSize).floor();
    final maxY = ((center.z + radius) / cellSize).floor();

    final center2D = Vector2(center.x, center.z);
    final radiusSq = radius * radius;

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final cell = _cells[cellKey(x, y)];
        if (cell != null) {
          final distSq = (cell.center - center2D).length2;
          if (distSq <= radiusSq) {
            yield cell;
          }
        }
      }
    }
  }

  /// Pure helper computing the effective DataLayerState for an actor in a cell.
  ///
  /// Evaluates `min(cellDesiredState, max(actorLayers))` with `unloaded < loaded < activated`.
  DataLayerState computeActorEffectiveState(CellState cellState, LuminaActor actor) {
    if (cellState == CellState.unloaded || cellState == CellState.unloading) {
      return DataLayerState.unloaded;
    }

    final layers = _actorDataLayers[actor];
    if (layers == null || layers.isEmpty) {
      // Layerless actor follows cell state
      return (cellState == CellState.activated)
          ? DataLayerState.activated
          : DataLayerState.loaded;
    }

    // Max over actor layers
    DataLayerState layerMax = DataLayerState.unloaded;
    for (final layerName in layers) {
      final s = dataLayerManager.getDataLayerState(layerName) ?? DataLayerState.unloaded;
      if (s == DataLayerState.activated) {
        layerMax = DataLayerState.activated;
        break;
      } else if (s == DataLayerState.loaded) {
        layerMax = DataLayerState.loaded;
      }
    }

    if (layerMax == DataLayerState.unloaded) {
      return DataLayerState.unloaded;
    }

    // Min with cell state
    if (cellState != CellState.activated && layerMax == DataLayerState.activated) {
      return DataLayerState.loaded;
    }

    return layerMax;
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);

    // 1. Evaluate desired cell states using streaming sources union
    final wantedCellsMap = <LuminaWorldPartitionCell, _CellIntent>{};

    for (final source in _streamingSources) {
      if (!source.bEnabled || !source.bShapesCellLoading) continue;

      final sourceLoc = source.location;
      final sourceRadius = source.loadingRadius;
      final sourceCenter2D = Vector2(sourceLoc.x, sourceLoc.z);
      final cells = queryCellsInRadius(sourceLoc, sourceRadius);

      for (final cell in cells) {
        final dist = (cell.center - sourceCenter2D).length;
        final existing = wantedCellsMap[cell];
        if (existing == null) {
          wantedCellsMap[cell] = _CellIntent(
            maxPriority: source.priority,
            minDistance: dist,
            targetState: source.targetState,
          );
        } else {
          existing.maxPriority = math.max(existing.maxPriority, source.priority);
          existing.minDistance = math.min(existing.minDistance, dist);
          if (source.targetState == LuminaStreamingSourceTargetState.activated) {
            existing.targetState = LuminaStreamingSourceTargetState.activated;
          }
        }
      }
    }

    int transitionsThisTick = 0;

    // Collect cells needing promotion and sort by priority (descending) and distance (ascending)
    final cellsToPromote = <LuminaWorldPartitionCell>[];
    for (final entry in wantedCellsMap.entries) {
      final cell = entry.key;
      final intent = entry.value;

      if (cell.state == CellState.unloaded) {
        cellsToPromote.add(cell);
      } else if (cell.state == CellState.loaded &&
          intent.targetState == LuminaStreamingSourceTargetState.activated) {
        cellsToPromote.add(cell);
      } else if (cell.state == CellState.deactivated) {
        cellsToPromote.add(cell);
      }
    }

    cellsToPromote.sort((a, b) {
      final intentA = wantedCellsMap[a]!;
      final intentB = wantedCellsMap[b]!;
      if (intentA.maxPriority != intentB.maxPriority) {
        return intentB.maxPriority.compareTo(intentA.maxPriority);
      }
      return intentA.minDistance.compareTo(intentB.minDistance);
    });

    for (final cell in cellsToPromote) {
      if (transitionsThisTick >= maxCellTransitionsPerTick) break;
      final intent = wantedCellsMap[cell]!;

      if (cell.state == CellState.unloaded) {
        cell.loadAsync();
        transitionsThisTick++;
      } else if (cell.state == CellState.loaded) {
        if (intent.targetState == LuminaStreamingSourceTargetState.activated) {
          cell.activate();
          transitionsThisTick++;
        }
      } else if (cell.state == CellState.deactivated) {
        if (intent.targetState == LuminaStreamingSourceTargetState.activated) {
          cell.activate();
        } else {
          cell.transitionTo(CellState.loaded);
        }
        transitionsThisTick++;
      }
    }

    // Collect cells needing demotion (not in wantedCellsMap or capping down)
    if (transitionsThisTick < maxCellTransitionsPerTick) {
      for (final cell in _cells.values) {
        if (transitionsThisTick >= maxCellTransitionsPerTick) break;

        final intent = wantedCellsMap[cell];
        if (intent == null) {
          // Completely unwanted
          if (cell.state == CellState.activated) {
            cell.deactivate();
            transitionsThisTick++;
          } else if (cell.state == CellState.deactivated || cell.state == CellState.loaded) {
            cell.unloadAsync();
            transitionsThisTick++;
          }
        } else if (intent.targetState == LuminaStreamingSourceTargetState.loaded &&
            cell.state == CellState.activated) {
          cell.deactivate();
          transitionsThisTick++;
        }
      }
    }

    // 2. Tick actors in activated cells respecting DataLayer gating
    for (final cell in _cells.values) {
      if (cell.isTicking) {
        for (final actor in cell.actors) {
          final actorState = computeActorEffectiveState(cell.state, actor);
          if (actorState == DataLayerState.activated) {
            if (!actor.isInitialized) actor.onInitialize();
            if (!actor.hasBegunPlay) actor.onBeginPlay();
            actor.onTick(deltaTime);
          }
        }
      }
    }
  }

  @override
  void onWorldShutdown() {
    dataLayerManager.dispose();
    super.onWorldShutdown();
  }
}

class _CellIntent {
  int maxPriority;
  double minDistance;
  LuminaStreamingSourceTargetState targetState;

  _CellIntent({
    required this.maxPriority,
    required this.minDistance,
    required this.targetState,
  });
}

/// Alias for backwards compatibility
typedef LuminaWorldPartition = LuminaWorldPartitionSubsystem;
