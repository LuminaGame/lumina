part of '../landscape_component.dart';

/// Section residency: the budget, resident statistics, LOD
/// steps and applying a residency plan around the camera.
mixin _LandscapeResidency on _LuminaLandscapeComponentState {

  // --- Residency ---------------------------------------------------------------

  /// The budget actually in force, after the size-based default.
  LandscapeResidencyBudget get effectiveResidencyBudget {
    final explicit = residencyBudget;
    if (explicit != null) return explicit;
    final map = _sectionMap;
    if (map == null || map.sectionCount <= LuminaLandscapeComponent.autoStreamTileThreshold) {
      return LandscapeResidencyBudget.unlimited;
    }
    return const LandscapeResidencyBudget();
  }

  /// Total tiles this terrain has, resident or not.
  int get totalSectionCount => _sectionMap?.sectionCount ?? 0;

  /// Tiles currently mounted.
  int get residentSectionCount => _residentLod.length;

  /// Triangles currently mounted, summed from the geometry really uploaded.
  int get residentTriangleCount => _residentTriangles;

  /// Vertices currently mounted, read back from the mesh component (i.e.
  /// after any MIKKTSPACE split), not from what we asked for.
  int get residentVertexCount {
    final terrain = _terrain;
    if (terrain == null) return 0;
    var total = 0;
    for (final i in _residentLod.keys) {
      total += terrain.sectionVertexCount(i);
    }
    return total;
  }

  /// Bytes the resident tiles occupy in GPU vertex and index buffers,
  /// computed from each section's real stride and vertex count.
  int get residentGpuBytes {
    final terrain = _terrain;
    if (terrain == null) return 0;
    var total = 0;
    for (final i in _residentLod.keys) {
      total += terrain.getSectionStride(i) * terrain.sectionVertexCount(i);
      final indices = _residentIndexCount[i] ?? 0;
      total += indices * (terrain.getSectionIndexType(i) == IndexType.ushort ? 2 : 4);
    }
    return total;
  }

  /// Tiles inside the load radius that the budget could not afford.
  int get tilesOutsideBudget => _tilesOutsideBudget;

  /// Tile index → mounted LOD step.
  Map<int, int> get residentLods => Map.unmodifiable(_residentLod);

  /// True when tile [sectionIndex] is currently mounted.
  bool isSectionResident(int sectionIndex) => _residentLod.containsKey(sectionIndex);

  /// The LOD step tile [sectionIndex] is mounted at, or 0 when it is not.
  int lodStepOf(int sectionIndex) => _residentLod[sectionIndex] ?? 0;

  /// Rebuilds one resident tile from the payload at its current LOD and edge
  /// stitching — what a sculpt stroke needs when the tile cannot take a
  /// windowed upload (it is decimated, or the tangent builder remeshed it).
  ///
  /// Returns false when the tile is not resident, so a caller does not mount
  /// terrain the residency budget deliberately left out.
  bool rebuildResidentSection(int sectionIndex) {
    final d = _data;
    final map = _sectionMap;
    final terrain = _terrain;
    if (d == null || map == null || terrain == null) return false;
    final step = _residentLod[sectionIndex];
    if (step == null) return false;
    final geo = LandscapeMeshBuilder.buildSection(
      d,
      map,
      sectionIndex,
      unitsPerMetre: unitsPerMetre,
      lodStep: step,
      edgeSteps: _residentEdges[sectionIndex] ?? LandscapeEdgeSteps.none,
    );
    terrain.createMeshSection(
      sectionIndex,
      positions: geo.positions,
      normals: geo.normals,
      uv0: geo.uv0,
      colors: geo.colors,
      indices: geo.indices,
      material: buildTerrainMaterial(),
      tangentAlgorithm: LuminaLandscapeComponent.terrainTangentAlgorithm,
      dynamic: true,
      castShadows: true,
      receiveShadows: true,
    );
    _noteRemesh(terrain, sectionIndex);
    _residentIndexCount[sectionIndex] = geo.indices.length;
    return true;
  }

  /// The camera position the current residency was solved for.
  Vector3 get residencyCamera => _residencyCamera.clone();

  /// Re-solves residency for a camera at [cameraWorld] and mounts/unmounts
  /// tiles to match.
  void updateResidency(Vector3 cameraWorld) {
    final d = _data;
    final map = _sectionMap;
    if (d == null || map == null) return;
    _residencyCamera = cameraWorld.clone();
    final origin = worldLocation;
    final local = Vector3(
      (cameraWorld.x - origin.x) / unitsPerMetre,
      0.0,
      (cameraWorld.z - origin.z) / unitsPerMetre,
    );
    final plan = LandscapeResidency.solve(
      data: d,
      map: map,
      cameraLocal: local,
      budget: effectiveResidencyBudget,
    );
    _applyPlan(d, map, plan);
  }

  void _applyPlan(LandscapeData d, LandscapeSectionMap map, LandscapeResidencyPlan plan) {
    final terrain = ensureTerrainMesh();
    if (terrain == null) return;
    _tilesOutsideBudget = plan.droppedForBudget;

    for (final index in _residentLod.keys.toList()) {
      if (plan.tileLod.containsKey(index)) continue;
      terrain.clearMeshSection(index);
      _residentLod.remove(index);
      _residentEdges.remove(index);
      _residentIndexCount.remove(index);
      _remeshedSections.remove(index);
    }

    final edges = <int, LandscapeEdgeSteps>{};
    for (final index in plan.tileLod.keys) {
      edges[index] = _edgesFor(map, plan.tileLod, index);
    }

    final material = buildTerrainMaterial();
    for (final entry in plan.tileLod.entries) {
      final index = entry.key;
      final step = entry.value;
      final edge = edges[index]!;
      if (_residentLod[index] == step && _residentEdges[index] == edge && terrain.hasSection(index)) {
        continue;
      }
      final geo = LandscapeMeshBuilder.buildSection(
        d,
        map,
        index,
        unitsPerMetre: unitsPerMetre,
        lodStep: step,
        edgeSteps: edge,
      );
      terrain.createMeshSection(
        index,
        positions: geo.positions,
        normals: geo.normals,
        uv0: geo.uv0,
        colors: geo.colors,
        indices: geo.indices,
        material: material,
        tangentAlgorithm: LuminaLandscapeComponent.terrainTangentAlgorithm,
        dynamic: true,
        castShadows: true,
        receiveShadows: true,
      );
      _noteRemesh(terrain, index);
      _residentLod[index] = step;
      _residentEdges[index] = edge;
      _residentIndexCount[index] = geo.indices.length;
    }

    _residentTriangles = 0;
    for (final entry in _residentLod.entries) {
      _residentTriangles += LandscapeResidency.triangleCountOf(map, entry.key, entry.value);
    }
  }

  /// The LOD steps of [index]'s four neighbours in [plan].
  ///
  /// A neighbour that is not resident is reported as step 1 — there is no
  /// seam to stitch against a tile that is not drawn.
  LandscapeEdgeSteps _edgesFor(LandscapeSectionMap map, Map<int, int> plan, int index) {
    final sc = map.sectionColOf(index);
    final sr = map.sectionRowOf(index);
    int stepAt(int c, int r) {
      if (c < 0 || r < 0 || c >= map.sectionsPerSide || r >= map.sectionsPerSide) return 1;
      return plan[map.sectionIndexAt(c, r)] ?? 1;
    }

    return LandscapeEdgeSteps(
      north: stepAt(sc, sr - 1),
      south: stepAt(sc, sr + 1),
      west: stepAt(sc - 1, sr),
      east: stepAt(sc + 1, sr),
    );
  }
}
