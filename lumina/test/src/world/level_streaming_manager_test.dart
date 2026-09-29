import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaLevelStreamingManager Tests (Task 03)', () {
    test('Manager registered on a world via subsystem collection -> non-null world and receives onWorldTick', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager();
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      expect(manager.world, same(world));
      expect(manager.isInitialized, isTrue);

      world.beginPlay();
      world.tick(1.0 / 60.0);
    });

    test('Distance policy: level at (1000,0,0) stays unloaded at dist 1000, loads when viewer moves to (600,0,0)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager(streamingDistance: 500.0);
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/Sub_Dist.lmas',
        levelInstance: level,
        bShouldBeLoaded: false,
        bShouldBeVisible: false,
      );

      manager.registerStreamingLevel(streaming, levelOrigin: Vector3(1000, 0, 0));
      world.beginPlay();

      // Viewer at (0,0,0) -> distance = 1000 > 500 -> unloaded
      manager.setViewerPosition(Vector3(0, 0, 0));
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);
      expect(streaming.state, equals(LevelState.unloaded));

      // Viewer moves to (600,0,0) -> distance = 400 <= 500 -> triggers load and show
      manager.setViewerPosition(Vector3(600, 0, 0));
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);

      // Wait a microtask for async transition to settle
      await Future.delayed(const Duration(milliseconds: 10));
      expect(streaming.state, equals(LevelState.visible));
    });

    test('Level with bDisableDistanceStreaming: true and bShouldBeLoaded: true -> loads even with viewer 10 km away', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager(streamingDistance: 100.0);
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/Sub_NoDist.lmas',
        levelInstance: level,
        bShouldBeLoaded: true,
        bShouldBeVisible: true,
        bDisableDistanceStreaming: true,
      );

      manager.registerStreamingLevel(streaming, levelOrigin: Vector3(10000, 0, 0));
      world.beginPlay();

      manager.setViewerPosition(Vector3(0, 0, 0));
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(streaming.state, equals(LevelState.visible));
    });

    test('Volume requests Cave and viewer is also within streamingDistance of Cave -> exactly one load issued (dedupe)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager(streamingDistance: 500.0);
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'Cave',
        levelInstance: level,
        bShouldBeLoaded: false,
      );
      manager.registerStreamingLevel(streaming, levelOrigin: Vector3(100, 0, 0));

      final volume = LuminaLevelStreamingVolume(
        volumeName: 'CaveVol',
        targetLevelNames: ['Cave'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(200, 200, 200)),
      );
      manager.addVolume(volume);

      final pawn = LuminaPawn();
      pawn.actorLocation = Vector3(50, 50, 50);
      world.spawnActor(pawn);

      world.beginPlay();
      manager.setViewerPosition(Vector3(50, 50, 50));

      int loadCount = 0;
      streaming.onLevelLoaded = (_) => loadCount++;

      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(streaming.state, isIn([LevelState.loaded, LevelState.visible]));
      expect(loadCount, equals(1));
    });

    test('Volume exit committed while distance policy still wants level -> level stays loaded (union semantics)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager(streamingDistance: 500.0);
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);

      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'Forest',
        levelInstance: level,
        bShouldBeLoaded: false,
      );
      manager.registerStreamingLevel(streaming, levelOrigin: Vector3(100, 0, 0));

      final volume = LuminaLevelStreamingVolume(
        volumeName: 'ForestVol',
        targetLevelNames: ['Forest'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(20, 20, 20)),
        bufferMargin: 1.0,
        exitDelay: const Duration(milliseconds: 50),
      );
      manager.addVolume(volume);

      final pawn = LuminaPawn();
      pawn.actorLocation = Vector3(10, 10, 10);
      world.spawnActor(pawn);
      world.beginPlay();

      manager.setViewerPosition(Vector3(50, 0, 0)); // viewer is close (< 500)
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(streaming.state, isIn([LevelState.loaded, LevelState.visible]));

      // Pawn exits volume to (100, 100, 100), but viewer remains close
      pawn.actorLocation = Vector3(100, 100, 100);
      world.tick(0.1);
      world.tick(0.1);
      await Future.delayed(const Duration(milliseconds: 10));

      // Level stays loaded because distance policy still wants it
      expect(streaming.state, isIn([LevelState.loaded, LevelState.visible]));
    });

    test('Double-buffered request dispatch avoids ConcurrentModificationError and schedules follow-up for next tick', () {
      final manager = LuminaLevelStreamingManager();
      final order = <String>[];

      manager.enqueueRequest(() {
        order.add('req1');
        // Enqueue another request from within dispatch
        manager.enqueueRequest(() {
          order.add('req2');
        });
      });

      // Tick 1: should execute req1 and enqueue req2 into the other buffer
      manager.processPendingRequests();
      expect(order, equals(['req1']));

      // Tick 2: should execute req2
      manager.processPendingRequests();
      expect(order, equals(['req1', 'req2']));
    });

    test('LuminaTimeSlicedWorkQueue with 100 steps and 4ms budget pumps steps within budget across pumps', () {
      final queue = LuminaTimeSlicedWorkQueue();
      int executedSteps = 0;

      queue.enqueue(List.generate(100, (i) => () {
        executedSteps++;
        // Small busy loop
        final sw = Stopwatch()..start();
        while (sw.elapsedMicroseconds < 200) {}
      }));

      expect(queue.pendingCount, equals(100));

      // Pump 1
      queue.pump(const Duration(milliseconds: 2));
      expect(queue.pendingCount, lessThan(100));
      expect(executedSteps, greaterThan(0));

      // Pump repeatedly until 0
      while (queue.pendingCount > 0) {
        final prev = queue.pendingCount;
        queue.pump(const Duration(milliseconds: 4));
        expect(queue.pendingCount, lessThanOrEqualTo(prev));
      }

      expect(executedSteps, equals(100));
      expect(queue.pendingCount, equals(0));
    });

    test('parseLevelInIsolate round-trips level descriptor payload', () async {
      final payload = await LuminaLevelStreamingManager.parseLevelInIsolate('contents/levels/Test_Isolate.lmas');
      expect(payload.levelPath, equals('contents/levels/Test_Isolate.lmas'));
      expect(payload.actorDescriptors, isA<List<Map<String, dynamic>>>());
    });

    test('loadLevelInstanceAsync dynamic creation registers, loads and returns handle', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final manager = LuminaLevelStreamingManager();
      world.subsystems.registerSubsystem<LuminaLevelStreamingManager>(manager, world);
      world.beginPlay();

      final level = await manager.loadLevelInstanceAsync('Dynamic_Level_X', visible: true);
      expect(level, isNotNull);

      final handle = manager.findByName('Dynamic_Level_X');
      expect(handle, isNotNull);
      expect(handle!.state, equals(LevelState.visible));
    });
  });
}
