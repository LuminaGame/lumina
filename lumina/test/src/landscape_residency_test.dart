import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// The engine half. Large heightmaps are
/// only renderable if residency is bounded and LOD transitions do not crack.
LandscapeData _terrain({required int resolution, required double worldSize}) {
  final data = LandscapeData.flat(gridResolution: resolution, worldSize: worldSize, maxHeight: 400.0);
  final half = (resolution - 1) / 2.0;
  for (var r = 0; r < resolution; r++) {
    for (var c = 0; c < resolution; c++) {
      final u = (c - half) / half;
      final v = (r - half) / half;
      // Deliberately high-frequency: a decimated tile that ignored its coarse
      // neighbour would visibly miss these ridges at the seam.
      data.setHeight(
        c,
        r,
        120.0 + math.sin(u * 17.0) * 60.0 + math.cos(v * 13.0) * 50.0 + math.sin((u + v) * 31.0) * 20.0,
      );
    }
  }
  data.recomputeHeightRange();
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LandscapeResidency', () {
    test('a camera in one corner of an 8129² terrain keeps residency inside the budget', () {
      final data = LandscapeData.flat(
        gridResolution: LandscapeData.maxGridResolution,
        worldSize: 16256.0,
        maxHeight: 1000.0,
      );
      final map = LandscapeSectionMap(gridResolution: data.gridResolution);
      expect(map.sectionCount, 127 * 127, reason: '8129² is a 127×127 tile grid');

      const budget = LandscapeResidencyBudget(
        loadRadius: 2000.0,
        maxSections: 256,
        maxTriangles: 1500000,
        lodDistances: [400.0, 900.0, 2000.0],
      );

      final corner = Vector3(-data.worldSize / 2, 0.0, -data.worldSize / 2);
      final near = LandscapeResidency.solve(data: data, map: map, cameraLocal: corner, budget: budget);

      expect(near.sectionCount, greaterThan(0));
      expect(near.sectionCount, lessThanOrEqualTo(budget.maxSections));
      expect(near.triangles, lessThanOrEqualTo(budget.maxTriangles));
      expect(near.sectionCount, lessThan(map.sectionCount / 10),
          reason: 'a corner camera must not mount a meaningful fraction of 16 129 tiles');

      // Everything resident really is inside the load radius…
      for (final index in near.tileLod.keys) {
        expect(LandscapeResidency.tileDistance(data, map, index, corner),
            lessThanOrEqualTo(budget.loadRadius));
      }
      // …and the tile the camera stands on is at full detail.
      final under = near.tileLod.entries
          .firstWhere((e) => LandscapeResidency.tileDistance(data, map, e.key, corner) == 0.0);
      expect(under.value, 1);

      // Moving the camera mounts and unmounts.
      final middle = Vector3(0.0, 0.0, 0.0);
      final far = LandscapeResidency.solve(data: data, map: map, cameraLocal: middle, budget: budget);
      final mounted = far.tileLod.keys.toSet().difference(near.tileLod.keys.toSet());
      final unmounted = near.tileLod.keys.toSet().difference(far.tileLod.keys.toSet());
      expect(mounted, isNotEmpty, reason: 'the centre brings its own tiles in');
      expect(unmounted, isNotEmpty, reason: 'the corner tiles must leave residency');
      expect(far.sectionCount, lessThanOrEqualTo(budget.maxSections));
      expect(far.triangles, lessThanOrEqualTo(budget.maxTriangles));
    });

    test('distance decides LOD, and the budget coarsens rather than silently dropping', () {
      const budget = LandscapeResidencyBudget(lodDistances: [100.0, 200.0, 400.0]);
      expect(budget.lodStepFor(0.0), 1);
      expect(budget.lodStepFor(100.0), 1);
      expect(budget.lodStepFor(150.0), 2);
      expect(budget.lodStepFor(300.0), 4);
      expect(budget.lodStepFor(5000.0), 8);

      final data = _terrain(resolution: 1025, worldSize: 2048.0);
      final map = LandscapeSectionMap(gridResolution: 1025);
      const tight = LandscapeResidencyBudget(
        loadRadius: 100000.0,
        maxSections: 1000,
        maxTriangles: 200000,
        lodDistances: [50.0],
      );
      final plan = LandscapeResidency.solve(
        data: data,
        map: map,
        cameraLocal: Vector3.zero(),
        budget: tight,
      );
      expect(plan.triangles, lessThanOrEqualTo(tight.maxTriangles));
      expect(plan.tileLod.values.any((s) => s > 1), isTrue,
          reason: 'the triangle budget must coarsen tiles before dropping them');
    });
  });

  group('LOD seams', () {
    test('a fine tile stitched to a coarser neighbour leaves no gap along the shared edge', () {
      final data = _terrain(resolution: 257, worldSize: 512.0);
      final map = LandscapeSectionMap(gridResolution: 257);
      // Tiles (0,0) and (1,0) share a vertical seam.
      final fineIndex = map.sectionIndexAt(0, 0);
      final coarseIndex = map.sectionIndexAt(1, 0);

      final fine = LandscapeMeshBuilder.buildSection(
        data,
        map,
        fineIndex,
        lodStep: 1,
        edgeSteps: const LandscapeEdgeSteps(east: 4),
      );
      final coarse = LandscapeMeshBuilder.buildSection(data, map, coarseIndex, lodStep: 4);

      expect(fine.verticesPerRow, 65);
      expect(coarse.verticesPerRow, 17, reason: 'every 4th sample of a 65-wide tile');
      expect(coarse.triangleCount, 16 * 16 * 2);

      // The coarse tile's west column is the seam polyline.
      double coarseYAt(double z) {
        for (var r = 0; r < coarse.rowCount - 1; r++) {
          final z0 = coarse.positions[(r * coarse.verticesPerRow) * 3 + 2];
          final z1 = coarse.positions[((r + 1) * coarse.verticesPerRow) * 3 + 2];
          if (z >= z0 - 1e-6 && z <= z1 + 1e-6) {
            final y0 = coarse.positions[(r * coarse.verticesPerRow) * 3 + 1];
            final y1 = coarse.positions[((r + 1) * coarse.verticesPerRow) * 3 + 1];
            final t = (z1 - z0).abs() < 1e-9 ? 0.0 : (z - z0) / (z1 - z0);
            return y0 + (y1 - y0) * t;
          }
        }
        return double.nan;
      }

      var maxGap = 0.0;
      for (var r = 0; r < fine.rowCount; r++) {
        final base = (r * fine.verticesPerRow + fine.verticesPerRow - 1) * 3;
        final x = fine.positions[base];
        final y = fine.positions[base + 1];
        final z = fine.positions[base + 2];
        // Same seam line in X.
        expect(x, closeTo(coarse.positions[0], 1e-4));
        final expectedY = coarseYAt(z);
        expect(expectedY.isNaN, isFalse, reason: 'row $r must land on the coarse polyline');
        maxGap = math.max(maxGap, (y - expectedY).abs());
      }
      expect(maxGap, lessThan(1e-3), reason: 'no crack: the seam is one shared polyline (max gap $maxGap m)');

      // Without stitching the same seam really does crack — the test would be
      // vacuous otherwise.
      final unstitched = LandscapeMeshBuilder.buildSection(data, map, fineIndex, lodStep: 1);
      var naiveGap = 0.0;
      for (var r = 0; r < unstitched.rowCount; r++) {
        final base = (r * unstitched.verticesPerRow + unstitched.verticesPerRow - 1) * 3;
        naiveGap = math.max(
          naiveGap,
          (unstitched.positions[base + 1] - coarseYAt(unstitched.positions[base + 2])).abs(),
        );
      }
      expect(naiveGap, greaterThan(1.0), reason: 'the unstitched seam gaps by $naiveGap m');
    });
  });

  group('LuminaLandscapeComponent residency', () {
    test('a large terrain mounts only what the budget allows and reports measured numbers', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);
      final scene = engine!.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final data = _terrain(resolution: 1025, worldSize: 2048.0);
      const budget = LandscapeResidencyBudget(
        loadRadius: 400.0,
        maxSections: 24,
        maxTriangles: 300000,
        lodDistances: [150.0, 300.0],
      );
      final landscape = LuminaLandscapeComponent(data: data, residencyBudget: budget);
      final actor = LuminaActor(root: landscape);
      world.persistentLevel.registerActor(actor);
      await landscape.ensureBuilt();

      expect(landscape.totalSectionCount, 16 * 16);
      expect(landscape.residentSectionCount, lessThanOrEqualTo(budget.maxSections));
      expect(landscape.residentSectionCount, greaterThan(0));
      expect(landscape.residentTriangleCount, lessThanOrEqualTo(budget.maxTriangles));
      expect(landscape.residentSectionCount, lessThan(landscape.totalSectionCount));

      // Every HUD number is measured, not estimated.
      expect(landscape.residentVertexCount, greaterThan(0));
      expect(landscape.residentGpuBytes, greaterThan(landscape.residentVertexCount * 12),
          reason: 'bytes come from each section real stride, so at least position size');

      final before = landscape.residentLods.keys.toSet();
      // The camera is in world units (cm); the budget stays in terrain-local
      // metres, so (800 m, 800 m) in the terrain is (80000, 80000) in the world.
      landscape.updateResidency(Vector3(800.0, 0.0, 800.0) * LuminaUnits.unitsPerMetre);
      final after = landscape.residentLods.keys.toSet();
      expect(after.difference(before), isNotEmpty, reason: 'tiles stream in');
      expect(before.difference(after), isNotEmpty, reason: 'tiles stream out');
      expect(landscape.residentSectionCount, lessThanOrEqualTo(budget.maxSections));
      expect(landscape.terrainMesh!.sectionCount, landscape.residentSectionCount,
          reason: 'the mesh component holds exactly the resident tiles, no leaks');

      // ignore: avoid_print
      print('[landscape residency] total=${landscape.totalSectionCount} '
          'resident=${landscape.residentSectionCount} tris=${landscape.residentTriangleCount} '
          'verts=${landscape.residentVertexCount} gpuKB=${landscape.residentGpuBytes ~/ 1024} '
          'droppedForBudget=${landscape.tilesOutsideBudget}');

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('a small terrain still mounts whole — streaming only kicks in where it is needed', () async {
      final data = _terrain(resolution: 513, worldSize: 1024.0);
      final landscape = LuminaLandscapeComponent(data: data);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.persistentLevel.registerActor(LuminaActor(root: landscape));
      await landscape.ensureBuilt();
      expect(landscape.totalSectionCount, 64);
      expect(landscape.residentSectionCount, 64);
      expect(landscape.effectiveResidencyBudget.loadRadius, double.infinity);
      world.cleanup();
    });
  });
}
