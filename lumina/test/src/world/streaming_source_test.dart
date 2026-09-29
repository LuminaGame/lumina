import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('World Partition Streaming Sources Tests (Task 02)', () {
    test('Component defaults -> loadingRadius == 25000.0 (250 m), priority == 1, bShapesCellLoading == true, bEnabled == true', () {
      final source = LuminaStreamingSourceComponent();
      expect(source.loadingRadius, equals(25000.0));
      expect(source.priority, equals(1));
      expect(source.bShapesCellLoading, isTrue);
      expect(source.bEnabled, isTrue);
      expect(source.targetState, equals(LuminaStreamingSourceTargetState.activated));
    });

    test('Source attached to actor at (0,0,0) -> 200m (20000cm) cell activates, 300m cell stays unloaded', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawn = LuminaPawn();
      pawn.actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);

      final source = LuminaStreamingSourceComponent(loadingRadius: 25000.0);
      pawn.addComponent(source);

      // Actor in cell (1, 0) -> center ~ (19200, 6400) -> dist ~ 20200cm (< 25000cm)
      final actorNear = LuminaActor();
      partition.addActor(actorNear, Vector3(19200, 6400, 0));

      // Actor in cell (3, 0) -> center ~ (44800, 6400) -> dist ~ 45200cm (> 25000cm)
      final actorFar = LuminaActor();
      partition.addActor(actorFar, Vector3(44800, 6400, 0));

      world.beginPlay();

      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      final cellNear = partition.cellByCoords(1, 0)!;
      final cellFar = partition.cellByCoords(3, 0)!;

      expect(cellNear.state, equals(CellState.activated));
      expect(cellFar.state, equals(CellState.unloaded));
    });

    test('Two sources 600m (60000cm) apart, radius 250m each -> both neighborhoods loaded, gap unloaded, overlap loaded once', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawnA = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      final pawnB = LuminaPawn()..actorLocation = Vector3(60000, 0, 0);
      world.spawnActor(pawnA);
      world.spawnActor(pawnB);

      final sourceA = LuminaStreamingSourceComponent(loadingRadius: 25000.0);
      final sourceB = LuminaStreamingSourceComponent(loadingRadius: 25000.0);
      pawnA.addComponent(sourceA);
      pawnB.addComponent(sourceB);

      // Near A: cell (0,0)
      final actorA = LuminaActor();
      partition.addActor(actorA, Vector3(1000, 1000, 0));

      // Near B: cell (4,0) (around 51200..64000)
      final actorB = LuminaActor();
      partition.addActor(actorB, Vector3(55000, 1000, 0));

      // Gap: cell (2,0) (around 25600..38400 -> center ~ 32000, distance from 0 is 32000 > 25000, distance from 60000 is 28000 > 25000)
      final actorGap = LuminaActor();
      partition.addActor(actorGap, Vector3(32000, 1000, 0));

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
      expect(partition.cellByCoords(4, 0)!.state, equals(CellState.activated));
      expect(partition.cellByCoords(2, 0)!.state, equals(CellState.unloaded));
    });

    test('Source A leaves cell radius while Source B still covers it -> cell remains activated (union semantics)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawnA = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      final pawnB = LuminaPawn()..actorLocation = Vector3(5000, 0, 0);
      world.spawnActor(pawnA);
      world.spawnActor(pawnB);

      final sourceA = LuminaStreamingSourceComponent(loadingRadius: 20000.0);
      final sourceB = LuminaStreamingSourceComponent(loadingRadius: 20000.0);
      pawnA.addComponent(sourceA);
      pawnB.addComponent(sourceB);

      final actor = LuminaActor();
      partition.addActor(actor, Vector3(6400, 6400, 0)); // Cell (0,0)

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }
      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));

      // Move pawnA far away (100000, 0, 0), pawnB stays at (5000,0,0)
      pawnA.actorLocation = Vector3(100000, 0, 0);
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      // Cell (0,0) is still covered by pawnB -> stays activated
      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
    });

    test('Owner actor movement automatically updates source location and causes cell streaming shifts', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);

      final source = LuminaStreamingSourceComponent(loadingRadius: 20000.0);
      pawn.addComponent(source);

      final actorStart = LuminaActor();
      partition.addActor(actorStart, Vector3(6400, 6400, 0)); // Cell (0, 0)

      final actorEnd = LuminaActor();
      partition.addActor(actorEnd, Vector3(57600, 6400, 0)); // Cell (4, 0)

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
      expect(partition.cellByCoords(4, 0)!.state, equals(CellState.unloaded));

      // Move pawn 550m (55000cm) to the right
      pawn.actorLocation = Vector3(55000, 0, 0);
      for (int i = 0; i < 6; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(4, 0)!.state, equals(CellState.activated));
      expect(partition.cellByCoords(0, 0)!.state, isIn([CellState.deactivated, CellState.unloading, CellState.unloaded]));
    });

    test('Unregistering source on pawn destroy drains all its cells to unloaded without ghost pinning', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);

      final source = LuminaStreamingSourceComponent(loadingRadius: 20000.0);
      pawn.addComponent(source);

      final actor = LuminaActor();
      partition.addActor(actor, Vector3(6400, 6400, 0));

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }
      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));

      // Destroy pawn (unregisters source)
      world.destroyActor(pawn);
      for (int i = 0; i < 6; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.unloaded));
    });

    test('targetState: loaded source -> covered cells reach loaded but never activated', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);

      final source = LuminaStreamingSourceComponent(
        loadingRadius: 20000.0,
        targetState: LuminaStreamingSourceTargetState.loaded,
      );
      pawn.addComponent(source);

      final actor = LuminaActor();
      partition.addActor(actor, Vector3(6400, 6400, 0));

      world.beginPlay();
      for (int i = 0; i < 6; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.loaded));
      expect(partition.cellByCoords(0, 0)!.isTicking, isFalse);
    });

    test('Budget 1 transition/tick, source priority 10 vs 1 -> priority 10 source cell transitions first', () async {
      final partition = LuminaWorldPartitionSubsystem(
        cellSize: 12800.0,
        maxCellTransitionsPerTick: 1,
      );

      final actorHigh = LuminaActor();
      final actorLow = LuminaActor();
      partition.addActor(actorHigh, Vector3(6400, 6400, 0)); // Cell (0, 0)
      partition.addActor(actorLow, Vector3(106400, 6400, 0)); // Cell (8, 0)

      final sourceHigh = LuminaStreamingSourceComponent(
        loadingRadius: 20000.0,
        priority: 10,
      )..overrideLocation = Vector3(6400, 6400, 0);

      final sourceLow = LuminaStreamingSourceComponent(
        loadingRadius: 20000.0,
        priority: 1,
      )..overrideLocation = Vector3(106400, 6400, 0);

      partition.registerSource(sourceHigh);
      partition.registerSource(sourceLow);

      // Tick 1: only 1 cell transitions
      partition.onWorldTick(1.0 / 60.0);

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.loading));
      expect(partition.cellByCoords(8, 0)!.state, equals(CellState.unloaded));
    });

    test('bShapesCellLoading: false source alone -> zero cells load', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 12800.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final pawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);

      final source = LuminaStreamingSourceComponent(
        loadingRadius: 20000.0,
        bShapesCellLoading: false,
      );
      pawn.addComponent(source);

      final actor = LuminaActor();
      partition.addActor(actor, Vector3(6400, 6400, 0));

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.unloaded));
    });
  });
}
