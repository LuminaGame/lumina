import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class DataLayerTickActor extends LuminaActor {
  int ticks = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    ticks++;
  }
}

void main() {
  group('World Partition Data Layer Tests (Task 03)', () {
    test('registerLayer -> getDataLayerState == unloaded; findLayer on unknown -> null', () {
      final manager = LuminaDataLayerManager();
      final layer = manager.registerLayer('DataLayer_Quests');

      expect(layer.name, equals('DataLayer_Quests'));
      expect(manager.getDataLayerState('DataLayer_Quests'), equals(DataLayerState.unloaded));
      expect(manager.findLayer('Unknown_Layer'), isNull);
    });

    test('setDataLayerState emits exactly one event on transition; duplicate state emits nothing', () async {
      final manager = LuminaDataLayerManager();
      manager.registerLayer('DataLayer_Quests');

      final events = <({String layer, DataLayerState from, DataLayerState to})>[];
      final sub = manager.onLayerStateChanged.listen(events.add);

      manager.setDataLayerState('DataLayer_Quests', DataLayerState.activated);
      await Future.microtask(() {});

      expect(events.length, equals(1));
      expect(events.first.layer, equals('DataLayer_Quests'));
      expect(events.first.from, equals(DataLayerState.unloaded));
      expect(events.first.to, equals(DataLayerState.activated));

      // Setting same state again
      manager.setDataLayerState('DataLayer_Quests', DataLayerState.activated);
      await Future.microtask(() {});
      expect(events.length, equals(1));

      await sub.cancel();
    });

    test('Layerless actor in a spatially activated cell -> live and ticking', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      final actor = DataLayerTickActor();
      partition.addActor(actor, Vector3(50, 0, 50));

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final pawn = LuminaPawn()..actorLocation = Vector3(50, 50, 0);
      world.spawnActor(pawn);
      pawn.addComponent(source);

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(actor.ticks, greaterThan(0));
    });

    test('Actor in DataLayer_Seasonal (unloaded) inside activated cell -> frozen/not ticking; flip layer to activated -> ticks', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      partition.dataLayerManager.registerLayer('DataLayer_Seasonal', initialState: DataLayerState.unloaded);

      final actor = DataLayerTickActor();
      partition.addActor(actor, Vector3(50, 50, 0));
      partition.assignActorToLayer(actor, 'DataLayer_Seasonal');

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final pawn = LuminaPawn()..actorLocation = Vector3(50, 50, 0);
      world.spawnActor(pawn);
      pawn.addComponent(source);

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      // Actor in unloaded layer -> does not tick
      expect(actor.ticks, equals(0));

      // Flip layer to activated without source moving
      partition.dataLayerManager.setDataLayerState('DataLayer_Seasonal', DataLayerState.activated);
      for (int i = 0; i < 2; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(actor.ticks, greaterThan(0));
    });

    test('Layer loaded + cell activated -> actor resident but tick counter frozen (min rule)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      partition.dataLayerManager.registerLayer('DataLayer_Quests', initialState: DataLayerState.loaded);

      final actor = DataLayerTickActor();
      partition.addActor(actor, Vector3(50, 50, 0));
      partition.assignActorToLayer(actor, 'DataLayer_Quests');

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final pawn = LuminaPawn()..actorLocation = Vector3(50, 50, 0);
      world.spawnActor(pawn);
      pawn.addComponent(source);

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(partition.cellByCoords(0, 0)!.state, equals(CellState.activated));
      expect(actor.ticks, equals(0));
    });

    test('Actor in two layers (unloaded and activated) -> actor live (max over layers)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      partition.dataLayerManager.registerLayer('LayerA', initialState: DataLayerState.unloaded);
      partition.dataLayerManager.registerLayer('LayerB', initialState: DataLayerState.activated);

      final actor = DataLayerTickActor();
      partition.addActor(actor, Vector3(50, 50, 0));
      partition.assignActorToLayer(actor, 'LayerA');
      partition.assignActorToLayer(actor, 'LayerB');

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final pawn = LuminaPawn()..actorLocation = Vector3(50, 50, 0);
      world.spawnActor(pawn);
      pawn.addComponent(source);

      world.beginPlay();
      for (int i = 0; i < 4; i++) {
        world.tick(1.0 / 60.0);
        await Future.microtask(() {});
      }

      expect(actor.ticks, greaterThan(0));
    });

    test('Layer activated but actor cell outside all source radii -> actor stays unloaded', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      world.subsystems.registerSubsystem<LuminaWorldPartitionSubsystem>(partition, world);

      partition.dataLayerManager.registerLayer('DataLayer_Weather', initialState: DataLayerState.activated);

      final actor = DataLayerTickActor();
      partition.addActor(actor, Vector3(1000, 0, 1000));
      partition.assignActorToLayer(actor, 'DataLayer_Weather');

      final source = LuminaStreamingSourceComponent(loadingRadius: 200.0);
      final pawn = LuminaPawn()..actorLocation = Vector3(0, 0, 0);
      world.spawnActor(pawn);
      pawn.addComponent(source);

      world.beginPlay();
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);

      expect(actor.ticks, equals(0));
      expect(partition.cellByCoords(7, 7)!.state, equals(CellState.unloaded));
    });

    test('assignActorToLayer updates cell.dataLayers and removeActorFromLayer cleans up set', () {
      final partition = LuminaWorldPartitionSubsystem(cellSize: 128.0);
      partition.dataLayerManager.registerLayer('DataLayer_Destruction');

      final actor = LuminaActor();
      partition.addActor(actor, Vector3(50, 50, 0));

      final cell = partition.cellByCoords(0, 0)!;
      expect(cell.dataLayers, isEmpty);

      partition.assignActorToLayer(actor, 'DataLayer_Destruction');
      expect(cell.dataLayers.map((l) => l.name), contains('DataLayer_Destruction'));

      partition.removeActorFromLayer(actor, 'DataLayer_Destruction');
      expect(cell.dataLayers, isEmpty);
    });

    test('Snapshot and restore data layer states preserves runtime state map', () {
      final manager = LuminaDataLayerManager();
      manager.registerLayer('DataLayer_Quests', initialState: DataLayerState.activated);
      manager.registerLayer('DataLayer_Weather', initialState: DataLayerState.loaded);
      manager.registerLayer('DataLayer_Destruction', initialState: DataLayerState.unloaded);

      final snapshot = manager.snapshotStates();
      expect(snapshot['DataLayer_Quests'], equals(DataLayerState.activated));
      expect(snapshot['DataLayer_Weather'], equals(DataLayerState.loaded));
      expect(snapshot['DataLayer_Destruction'], equals(DataLayerState.unloaded));

      final newManager = LuminaDataLayerManager();
      newManager.registerLayer('DataLayer_Quests');
      newManager.registerLayer('DataLayer_Weather');
      newManager.registerLayer('DataLayer_Destruction');
      newManager.restoreStates(snapshot);

      expect(newManager.getDataLayerState('DataLayer_Quests'), equals(DataLayerState.activated));
      expect(newManager.getDataLayerState('DataLayer_Weather'), equals(DataLayerState.loaded));
      expect(newManager.getDataLayerState('DataLayer_Destruction'), equals(DataLayerState.unloaded));
    });
  });
}
