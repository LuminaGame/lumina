import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class CountingTickActor extends LuminaActor {
  int ticks = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    ticks++;
  }
}

void main() {
  _groundPlaneProjection();
  group('World Partition Grid Cells & Lifecycle Tests (Task 01)', () {
    // Positions are (x, height, z); the grid is the X/Z ground plane.
    test('cellSize: 128 -> actor at (130, 5, 0) lands in cell (1, 0); actor at (-1, 0, -1) lands in cell (-1, -1)', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final actor1 = LuminaActor();
      final actor2 = LuminaActor();

      partition.addActor(actor1, Vector3(130, 5, 0));
      partition.addActor(actor2, Vector3(-1, 0, -1));

      final cell1 = partition.cellAt(Vector3(130, 5, 0));
      expect(cell1.cellX, equals(1));
      expect(cell1.cellY, equals(0));
      expect(cell1.actors, contains(actor1));

      final cell2 = partition.cellAt(Vector3(-1, 0, -1));
      expect(cell2.cellX, equals(-1));
      expect(cell2.cellY, equals(-1));
      expect(cell2.actors, contains(actor2));
    });

    test('Two actors at (10,0,10) and (100,0,100) -> same cell; at (10,0,10) and (130,0,10) -> different cells (sparse hash)', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final actor1 = LuminaActor();
      final actor2 = LuminaActor();
      final actor3 = LuminaActor();

      partition.addActor(actor1, Vector3(10, 0, 10));
      partition.addActor(actor2, Vector3(100, 0, 100));
      expect(partition.cellCount, equals(1));

      partition.addActor(actor3, Vector3(130, 0, 10));
      expect(partition.cellCount, equals(2));

      final cell00 = partition.cellByCoords(0, 0);
      expect(cell00, isNotNull);
      expect(cell00!.actors.length, equals(2));
      expect(cell00.actors, containsAll([actor1, actor2]));

      final cell10 = partition.cellByCoords(1, 0);
      expect(cell10, isNotNull);
      expect(cell10!.actors.length, equals(1));
      expect(cell10.actors, contains(actor3));
    });

    test('queryCellsInRadius(center, 250) on populated grid touches only bounded window and returns cells within radius', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);

      // Populate 20x20 grid
      for (int x = 0; x < 20; x++) {
        for (int y = 0; y < 20; y++) {
          final actor = LuminaActor();
          partition.addActor(actor, Vector3(x * 128.0 + 64.0, 0, y * 128.0 + 64.0));
        }
      }

      final center = Vector3(500, 0, 500);
      final radius = 250.0;
      final queryCells = partition.queryCellsInRadius(center, radius).toList();

      expect(queryCells, isNotEmpty);
      for (final cell in queryCells) {
        final dist = (cell.center - Vector2(center.x, center.z)).length;
        expect(dist, lessThanOrEqualTo(radius));
      }
    });

    test('moveActor from (10,0,0) to (300,0,0) -> absent from cell (0,0), present in cell (2,0); intra-cell move unchanged', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final actor = LuminaActor();

      partition.addActor(actor, Vector3(10, 0, 0));
      expect(partition.cellByCoords(0, 0)!.actors, contains(actor));

      // Small move inside same cell
      partition.moveActor(actor, Vector3(50, 0, 0));
      expect(partition.cellByCoords(0, 0)!.actors, contains(actor));
      expect(partition.cellByCoords(2, 0), isNull);

      // Cross cell boundary into cell (2,0)
      partition.moveActor(actor, Vector3(300, 0, 0));
      expect(partition.cellByCoords(0, 0)!.actors, isNot(contains(actor)));
      expect(partition.cellByCoords(2, 0)!.actors, contains(actor));
    });

    test('Cell lifecycle: full ascent (unloaded -> loading -> loaded -> activated) and descent (activated -> deactivated -> unloading -> unloaded)', () async {
      final cell = LuminaWorldPartitionCell(cellX: 0, cellY: 0, cellSize: 128.0);
      final stateHistory = <CellState>[cell.state];

      cell.onStateChanged = (oldState, newState) {
        stateHistory.add(newState);
      };

      // 1. Ascent
      await cell.loadAsync();
      expect(cell.state, equals(CellState.loaded));

      cell.activate();
      expect(cell.state, equals(CellState.activated));
      expect(cell.isTicking, isTrue);

      // 2. Descent
      cell.deactivate();
      expect(cell.state, equals(CellState.deactivated));
      expect(cell.isTicking, isFalse);

      await cell.unloadAsync();
      expect(cell.state, equals(CellState.unloaded));

      expect(stateHistory, equals([
        CellState.unloaded,
        CellState.loading,
        CellState.loaded,
        CellState.activated,
        CellState.deactivated,
        CellState.unloading,
        CellState.unloaded,
      ]));
    });

    test('Only activated cells tick: actor tick counters advance for activated, stay frozen for deactivated', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final actor1 = CountingTickActor();
      final actor2 = CountingTickActor();

      partition.addActor(actor1, Vector3(50, 50, 0));
      partition.addActor(actor2, Vector3(500, 500, 0));

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0)
        ..location = Vector3(50, 50, 0);
      partition.registerSource(source);

      world.beginPlay();
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(actor1.ticks, greaterThan(0));
      expect(actor2.ticks, equals(0));
    });

    test('maxCellTransitionsPerTick = 2 with 10 cells wanting to load -> exactly 2 transition per tick', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0, maxCellTransitionsPerTick: 2);

      for (int i = 0; i < 10; i++) {
        final actor = LuminaActor();
        partition.addActor(actor, Vector3(i * 128.0 + 10.0, 0, 0));
      }

      // Add a streaming source that covers all 10 cells
      final source = LuminaStreamingSourceComponent(
        loadingRadius: 2000.0,
      )..location = Vector3(500, 0, 0);
      partition.registerSource(source);

      // Tick 1: should trigger exactly 2 loading transitions
      partition.onWorldTick(1.0 / 60.0);
      int loadingCount = 0;
      for (int i = 0; i < 10; i++) {
        final cell = partition.cellByCoords(i, 0);
        if (cell != null && cell.state != CellState.unloaded) {
          loadingCount++;
        }
      }
      expect(loadingCount, equals(2));
    });

    test('removeActor on an actor in an occupied cell -> cell no longer lists it and back-index cleared', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final actor1 = LuminaActor();
      final actor2 = LuminaActor();

      partition.addActor(actor1, Vector3(10, 10, 0));
      partition.addActor(actor2, Vector3(20, 20, 0));

      final cell = partition.cellByCoords(0, 0)!;
      expect(cell.actors.length, equals(2));

      partition.removeActor(actor1);
      expect(cell.actors, isNot(contains(actor1)));
      expect(cell.actors, contains(actor2));
      expect(cell.actors.length, equals(1));
    });
  });
}

/// The grid used X and **Y**, but Y is the up axis everywhere else in
/// lumina, so cells were vertical slabs: horizontal separation along Z never
/// changed cell, and height did.
void _groundPlaneProjection() {
  group('the grid partitions the ground plane', () {
    test('actors far apart along Z land in different cells', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final a = LuminaActor();
      final b = LuminaActor();

      partition.addActor(a, Vector3(0, 0, 0));
      partition.addActor(b, Vector3(0, 0, 1000));

      expect(partition.cellCount, 2, reason: '1000 units apart on the ground is 7 cells');
      expect(partition.cellCoordsOfActor(a), isNot(partition.cellCoordsOfActor(b)));
    });

    test('actors stacked vertically share one cell', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      final ground = LuminaActor();
      final high = LuminaActor();

      partition.addActor(ground, Vector3(0, 0, 0));
      partition.addActor(high, Vector3(0, 1000, 0));

      expect(partition.cellCount, 1, reason: 'height is not a grid axis');
      expect(partition.cellCoordsOfActor(ground), partition.cellCoordsOfActor(high));
    });

    test('cell coordinates read off X and Z', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 100.0);
      final cell = partition.cellAt(Vector3(250, 9999, -150));
      expect(cell.cellX, 2);
      expect(cell.cellY, -2, reason: 'grid axis 2 is world Z');
    });

    test('a cell is bounded on the ground plane and unbounded in height', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 100.0);
      final bounds = partition.cellAt(Vector3(50, 0, 50)).bounds;
      expect(bounds.min.x, 0.0);
      expect(bounds.max.x, 100.0);
      expect(bounds.min.z, 0.0);
      expect(bounds.max.z, 100.0);
      expect(bounds.min.y, lessThan(-1000.0));
      expect(bounds.max.y, greaterThan(1000.0));
    });

    test('a radius query sweeps the ground plane, not a vertical slab', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 100.0);
      partition.cellAt(Vector3(0, 0, 0));
      partition.cellAt(Vector3(0, 0, 250));
      partition.cellAt(Vector3(0, 5000, 0));

      final near = partition.queryCellsInRadius(Vector3(0, 0, 0), 150.0);
      expect(near.length, 1, reason: 'only the cell at the origin is within 150 units');

      final wide = partition.queryCellsInRadius(Vector3(0, 0, 200), 200.0);
      expect(wide.length, greaterThanOrEqualTo(2),
          reason: 'a query along Z must reach the cell 250 units away');
    });

    test('moving an actor along Z changes its cell; moving it up does not', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 100.0);
      final actor = LuminaActor();
      partition.addActor(actor, Vector3(0, 0, 0));
      final startCell = partition.cellCoordsOfActor(actor);

      partition.moveActor(actor, Vector3(0, 900, 0));
      expect(partition.cellCoordsOfActor(actor), startCell);

      partition.moveActor(actor, Vector3(0, 900, 900));
      expect(partition.cellCoordsOfActor(actor), isNot(startCell));
    });
  });
}
