import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../data/models/landscape_data.dart';
import 'landscape_mesh_builder.dart';
import 'landscape_section_map.dart';

/// What a landscape is allowed to keep mounted at once.
///
/// At 8129² the terrain is 127 × 127 = 16 129 tiles and ~68 M vertices; every
/// tile mounted at once is not a thing this (or any) machine renders. The
/// budget is the honest statement of that: tiles are mounted nearest-first
/// until one of these limits is reached, and the rest stay unmounted.
class LandscapeResidencyBudget {
  /// Radius around the camera inside which tiles may be mounted, in terrain
  /// metres. Tiles beyond it are never resident, whatever the budget allows.
  final double loadRadius;

  /// Hard cap on mounted tiles.
  final int maxSections;

  /// Hard cap on mounted triangles.
  final int maxTriangles;

  /// Distance (metres) at which each LOD step takes over, ascending.
  ///
  /// `[200, 500, 1200]` means: full detail inside 200 m, every 2nd sample out
  /// to 500 m, every 4th out to 1200 m, every 8th beyond. The steps are always
  /// powers of two so a tile keeps its seam samples and a coarser neighbour's
  /// vertices are a subset of a finer one's — which is what makes the
  /// crack-free stitching in [LandscapeMeshBuilder] exact.
  final List<double> lodDistances;

  const LandscapeResidencyBudget({
    this.loadRadius = 2000.0,
    this.maxSections = 256,
    this.maxTriangles = 2000000,
    this.lodDistances = const [400.0, 900.0, 2000.0],
  });

  /// The everything-resident budget, for terrains small enough not to need
  /// streaming at all.
  static const LandscapeResidencyBudget unlimited = LandscapeResidencyBudget(
    loadRadius: double.infinity,
    maxSections: 1 << 30,
    maxTriangles: 1 << 30,
    lodDistances: [],
  );

  /// The LOD step a tile at [distance] metres should use.
  int lodStepFor(double distance) {
    var step = 1;
    for (final edge in lodDistances) {
      if (distance <= edge) return step;
      step *= 2;
    }
    return lodDistances.isEmpty ? 1 : step;
  }
}

/// The tiles a landscape should have mounted right now, and at what detail.
class LandscapeResidencyPlan {
  /// Tile index → LOD step (1 = every sample).
  final Map<int, int> tileLod;

  /// Triangles the plan costs, summed from the real per-tile geometry.
  final int triangles;

  /// Tiles that were inside [LandscapeResidencyBudget.loadRadius] but did not
  /// fit the budget — the honest count of what the viewer is not seeing.
  final int droppedForBudget;

  const LandscapeResidencyPlan({
    required this.tileLod,
    required this.triangles,
    required this.droppedForBudget,
  });

  int get sectionCount => tileLod.length;
}

/// Decides which terrain tiles are resident around a camera.
///
/// This is the same model the world-partition subsystem applies to actors — a
/// streaming source with a radius, cells sorted by distance, a residency set
/// that grows and shrinks as the source moves — applied to terrain tiles,
/// which additionally carry a LOD. `LuminaStreamingSourceComponent` is the
/// component form of that source and can drive [solve] directly through its
/// `location` and `loadingRadius`.
class LandscapeResidency {
  const LandscapeResidency._();

  /// Centre of [sectionIndex] in terrain-local metres.
  static (double, double) tileCentre(LandscapeData data, LandscapeSectionMap map, int sectionIndex) {
    final c0 = map.firstColumnOf(sectionIndex);
    final r0 = map.firstRowOf(sectionIndex);
    final c1 = c0 + map.verticesPerRowOf(sectionIndex) - 1;
    final r1 = r0 + map.rowsOf(sectionIndex) - 1;
    return ((data.worldXOf(c0) + data.worldXOf(c1)) / 2, (data.worldZOf(r0) + data.worldZOf(r1)) / 2);
  }

  /// Distance in metres from [cameraLocal] to the nearest point of a tile's
  /// footprint (not its centre — a camera sitting on a tile must read zero).
  static double tileDistance(
    LandscapeData data,
    LandscapeSectionMap map,
    int sectionIndex,
    Vector3 cameraLocal,
  ) {
    final c0 = map.firstColumnOf(sectionIndex);
    final r0 = map.firstRowOf(sectionIndex);
    final c1 = c0 + map.verticesPerRowOf(sectionIndex) - 1;
    final r1 = r0 + map.rowsOf(sectionIndex) - 1;
    final minX = data.worldXOf(c0), maxX = data.worldXOf(c1);
    final minZ = data.worldZOf(r0), maxZ = data.worldZOf(r1);
    final dx = cameraLocal.x < minX ? minX - cameraLocal.x : (cameraLocal.x > maxX ? cameraLocal.x - maxX : 0.0);
    final dz = cameraLocal.z < minZ ? minZ - cameraLocal.z : (cameraLocal.z > maxZ ? cameraLocal.z - maxZ : 0.0);
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Triangles a tile costs at [lodStep].
  static int triangleCountOf(LandscapeSectionMap map, int sectionIndex, int lodStep) {
    final cols = LandscapeMeshBuilder.sampledCount(map.verticesPerRowOf(sectionIndex), lodStep);
    final rows = LandscapeMeshBuilder.sampledCount(map.rowsOf(sectionIndex), lodStep);
    return (cols - 1) * (rows - 1) * 2;
  }

  /// The tiles that should be resident for a camera at [cameraLocal]
  /// (terrain-local metres).
  ///
  /// Tiles are taken nearest-first. When a tile would break the triangle
  /// budget it is first tried at coarser LOD steps; only if even the coarsest
  /// step does not fit is it — and everything behind it — dropped.
  static LandscapeResidencyPlan solve({
    required LandscapeData data,
    required LandscapeSectionMap map,
    required Vector3 cameraLocal,
    LandscapeResidencyBudget budget = const LandscapeResidencyBudget(),
  }) {
    final candidates = <(int, double)>[];
    for (var i = 0; i < map.sectionCount; i++) {
      final d = tileDistance(data, map, i, cameraLocal);
      if (d <= budget.loadRadius) candidates.add((i, d));
    }
    candidates.sort((a, b) => a.$2.compareTo(b.$2));

    final tileLod = <int, int>{};
    var triangles = 0;
    var dropped = 0;
    for (final (index, distance) in candidates) {
      if (tileLod.length >= budget.maxSections) {
        dropped++;
        continue;
      }
      var step = budget.lodStepFor(distance);
      var cost = triangleCountOf(map, index, step);
      while (triangles + cost > budget.maxTriangles && step < map.quadsPerSection) {
        step *= 2;
        cost = triangleCountOf(map, index, step);
      }
      if (triangles + cost > budget.maxTriangles) {
        dropped++;
        continue;
      }
      tileLod[index] = step;
      triangles += cost;
    }
    return LandscapeResidencyPlan(tileLod: tileLod, triangles: triangles, droppedForBudget: dropped);
  }
}
