import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaNavigationSystem Tests', () {
    test('buildFromWorld on 10x10m (1000x1000cm) empty bounds with cellSize 50cm creates 400 walkable cells', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds, config: const NavGridConfig(cellSize: 50.0));

      expect(nav.isBuilt, isTrue);
      expect(nav.walkableCellCount, equals(400));
      expect(nav.isWalkable(Vector3(0.0, 0.0, 0.0)), isTrue);
    });

    test('1x1m blocking box at center with agentRadius 35cm marks inflated footprint un-walkable', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final boxActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 200.0, 100.0); // half-extents in cm
      CollisionProfile.applyBlockAll(col);
      boxActor.addComponent(col);
      world.persistentLevel.registerActor(boxActor);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(
        bounds: bounds,
        config: const NavGridConfig(cellSize: 50.0, agentRadius: 35.0),
      );

      // Center (0, 0) should be blocked
      expect(nav.isWalkable(Vector3(0.0, 0.0, 0.0)), isFalse);
      // 2m (200cm) away should be walkable
      expect(nav.isWalkable(Vector3(200.0, 0.0, 200.0)), isTrue);
    });

    test('findPathSync across open ground collapses to 2 points with smoothing', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds);

      final path = nav.findPathSync(Vector3(-400.0, 0.0, -400.0), Vector3(400.0, 0.0, 400.0), smooth: true);
      expect(path, isNotNull);
      expect(path!.points.length, equals(2));
      expect(path.isPartial, isFalse);
      expect(path.length, closeTo(Vector3(800.0, 0.0, 800.0).length, 50.0));
    });

    test('Path around a wall detours around obstacles and respects direct walkable line', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final wallActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(400.0, 200.0, 50.0); // Wall half-extents in cm
      CollisionProfile.applyBlockAll(col);
      wallActor.addComponent(col);
      world.persistentLevel.registerActor(wallActor);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds, config: const NavGridConfig(cellSize: 50.0, agentRadius: 25.0));

      final start = Vector3(0.0, 0.0, -200.0);
      final end = Vector3(0.0, 0.0, 200.0);
      final path = nav.findPathSync(start, end, smooth: true);

      expect(path, isNotNull);
      expect(path!.isPartial, isFalse);
      for (int i = 0; i < path.points.length - 1; i++) {
        expect(nav.hasDirectWalkableLine(path.points[i], path.points[i + 1]), isTrue);
      }
    });

    test('Goal inside an obstacle with allowPartialPath returns nearest partial path', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final obstacleActor = LuminaActor(location: Vector3(300.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(200.0, 200.0, 200.0);
      CollisionProfile.applyBlockAll(col);
      obstacleActor.addComponent(col);
      world.persistentLevel.registerActor(obstacleActor);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds);

      final start = Vector3(0.0, 0.0, 0.0);
      final insideGoal = Vector3(300.0, 0.0, 0.0);

      final partialPath = nav.findPathSync(start, insideGoal, allowPartialPath: true);
      expect(partialPath, isNotNull);
      expect(partialPath!.isPartial, isTrue);

      final noPath = nav.findPathSync(start, insideGoal, allowPartialPath: false);
      expect(noPath, isNull);
    });

    test('Two regions separated by complete wall returns null without infinite loop', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final wallActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1000.0, 200.0, 100.0); // Spans entire X
      CollisionProfile.applyBlockAll(col);
      wallActor.addComponent(col);
      world.persistentLevel.registerActor(wallActor);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds);

      final path = nav.findPathSync(Vector3(0.0, 0.0, -300.0), Vector3(0.0, 0.0, 300.0), allowPartialPath: false);
      expect(path, isNull);
    });

    test('projectPointToNavigation projects blocked point to nearest walkable cell', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final box = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(100.0, 200.0, 100.0);
      CollisionProfile.applyBlockAll(col);
      box.addComponent(col);
      world.persistentLevel.registerActor(box);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds);

      final proj = nav.projectPointToNavigation(Vector3(0.0, 0.0, 0.0), searchRadius: 200.0);
      expect(proj, isNotNull);
      expect(nav.isWalkable(proj!), isTrue);

      final farProj = nav.projectPointToNavigation(Vector3(10000.0, 0.0, 10000.0), searchRadius: 100.0);
      expect(farProj, isNull);
    });

    test('Overlap collision components are not rasterized as obstacles', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final triggerActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(200.0, 200.0, 200.0);
      CollisionProfile.applyOverlapAll(col); // Trigger
      triggerActor.addComponent(col);
      world.persistentLevel.registerActor(triggerActor);

      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-500.0, 0.0, -500.0), Vector3(500.0, 0.0, 500.0));
      nav.buildFromWorld(bounds: bounds);

      expect(nav.isWalkable(Vector3(0.0, 0.0, 0.0)), isTrue);
    });

    test('100x100 grid path query completes in under 50ms', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final nav = LuminaNavigationSystem();
      world.registerSubsystem<LuminaNavigationSystem>(nav);

      final bounds = Aabb3.minMax(Vector3(-2500.0, 0.0, -2500.0), Vector3(2500.0, 0.0, 2500.0));
      nav.buildFromWorld(bounds: bounds, config: const NavGridConfig(cellSize: 50.0)); // 100x100 = 10,000 cells

      final stopwatch = Stopwatch()..start();
      final path = nav.findPathSync(Vector3(-2400.0, 0.0, -2400.0), Vector3(2400.0, 0.0, 2400.0), smooth: true);
      stopwatch.stop();

      expect(path, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
