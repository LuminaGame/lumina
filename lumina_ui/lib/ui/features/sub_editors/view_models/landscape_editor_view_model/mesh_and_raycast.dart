part of '../landscape_editor_view_model.dart';

/// Terrain/foliage mesh generation and upload to the preview scene, and
/// the heightmap raycast behind the brush ring.
mixin _LandscapeEditorMeshAndRaycast on _LandscapeEditorViewModelState {

  // --- Mesh generation --------------------------------------------------------------

  /// Rebuilds every terrain section and foliage batch on the sink. Call this
  /// once the preview world is up: [attach] gives the scene a fresh mesh
  /// component, so whatever was uploaded before it is gone.
  void rebuildPreview() => _rebuildAll();

  void _rebuildAll() {
    _sections = LandscapeSectionMap(gridResolution: _data.gridResolution);
    sink.clearTerrain();
    // Prefer handing the whole payload to the engine: it streams tiles against
    // a residency budget, which is the only way a terrain of more than a few
    // thousand tiles renders at all. Sinks that cannot (the headless fake, the
    // null sink) fall back to pushing every tile.
    if (sink.mountPayload(_data)) {
      _engineOwnsTerrain = true;
      _syncCursor(force: true);
      return;
    }
    _engineOwnsTerrain = false;
    for (var i = 0; i < _sections.sectionCount; i++) {
      _createSection(i);
    }
    _rebuildFoliage();
    _syncCursor(force: true);
  }

  @override
  void _rebuildFoliage() {
    for (var i = 0; i < _data.layers.length; i++) {
      _rebuildFoliageBatch(i);
    }
  }

  @override
  void _rebuildFoliageBatch(int index) {
    final layer = _data.layers[index];
    sink.createFoliageBatch(index, meshAssetPath: layer.meshAssetPath, capacity: LandscapeEditorViewModel.foliageCapacityPerLayer);
    for (var i = 0; i < layer.instanceCount; i++) {
      sink.addFoliageInstance(index, LandscapeEditorViewModel.foliageMatrixOf(layer.instanceAt(i)));
    }
  }

  void _createSection(int sectionIndex) {
    // Geometry comes from the engine's own builder — the same code the runtime
    // LuminaLandscapeComponent uses, so the preview and the packaged game draw
    // the identical terrain.
    final geo = LandscapeMeshBuilder.buildSection(
      _data,
      _sections,
      sectionIndex,
      unitsPerMetre: LandscapeEditorViewModel.unitsPerMetre,
    );
    sink.createTerrainSection(
      sectionIndex,
      positions: geo.positions,
      normals: geo.normals,
      uv0: geo.uv0,
      colors: geo.colors,
      indices: geo.indices,
    );
  }

  /// Uploads only the row windows of the sections [edited] touched, grown by
  /// one ring: a vertex just outside the edited cells has a normal (and so a
  /// shading and a slope albedo) that depends on them. Each window carries its
  /// positions, normals and colours — the lit terrain needs all three.
  @override
  void _uploadRect(HeightRect edited) {
    final rect = edited.inflate(1, _data.gridResolution);
    for (final window in _sections.windowsFor(rect)) {
      if (!sink.isSectionResident(window.sectionIndex)) {
        // The residency budget deliberately left this tile unmounted; writing
        // into it would mount terrain the budget said no to.
        continue;
      }
      if (!sink.supportsPartialUpdate(window.sectionIndex)) {
        // Decimated or vertex-split: the engine rebuilds the whole tile at its
        // own LOD where it can, otherwise we rebuild it at full detail.
        if (sink.rebuildSection(window.sectionIndex)) continue;
        _createSection(window.sectionIndex);
        continue;
      }
      final cols = window.verticesPerRow;
      final count = cols * window.rowCount;
      final positions = Float32List(count * 3);
      final normals = Float32List(count * 3);
      final colors = Uint8List(count * 4);
      LandscapeMeshBuilder.fillVertices(
        _data,
        _sections,
        window.sectionIndex,
        firstLocalRow: window.firstLocalRow,
        rowCount: window.rowCount,
        positions: positions,
        normals: normals,
        colors: colors,
        unitsPerMetre: LandscapeEditorViewModel.unitsPerMetre,
      );
      sink.updateTerrainSection(window, positions: positions, normals: normals, colors: colors);
    }
    // The ground under the cursor moved: drape it again.
    _syncCursor(force: true);
  }

  int _sectionIndexAtWorld(double worldX, double worldZ) {
    final c = _data.columnOf(worldX).clamp(0.0, (_data.gridResolution - 1).toDouble()).floor();
    final r = _data.rowOf(worldZ).clamp(0.0, (_data.gridResolution - 1).toDouble()).floor();
    final sc = math.min(c ~/ _sections.quadsPerSection, _sections.sectionsPerSide - 1);
    final sr = math.min(r ~/ _sections.quadsPerSection, _sections.sectionsPerSide - 1);
    return _sections.sectionIndexAt(sc, sr);
  }

  // --- Heightmap raycast (brush ring) ------------------------------------------------

  /// Marches [direction] from [origin] (world units) against the bilinear
  /// heightmap and returns the hit position in **metres**, or null on a miss.
  /// Fixed-step march then bisection — identical in tests and in the editor,
  /// never a GPU readback.
  ///
  /// The ray is first clipped to the terrain's box (its footprint × the
  /// payload's `0..maxHeight` range), so a ray that misses the terrain costs
  /// nothing and a hit only marches the part of the ray over it.
  @override
  Vector3? raycast(Vector3 origin, Vector3 direction, {double maxDistance = 100000.0}) {
    if (direction.length2 < 1e-18) return null;
    final dir = direction.normalized();
    final step = math.max(_data.cellSize, 0.25) * LandscapeEditorViewModel.unitsPerMetre * 0.5;
    double heightDelta(double t) {
      final p = origin + dir * t;
      return p.y / LandscapeEditorViewModel.unitsPerMetre - _data.sampleHeight(p.x / LandscapeEditorViewModel.unitsPerMetre, p.z / LandscapeEditorViewModel.unitsPerMetre);
    }

    // Slab test against the terrain's box, in preview units.
    final half = _data.worldSize / 2 * LandscapeEditorViewModel.unitsPerMetre;
    final lo = [-half, -LandscapeEditorViewModel.unitsPerMetre, -half];
    final hi = [half, (_data.maxHeight + 1.0) * LandscapeEditorViewModel.unitsPerMetre, half];
    final o = [origin.x, origin.y, origin.z];
    final d = [dir.x, dir.y, dir.z];
    var tEnter = 0.0, tExit = maxDistance;
    for (var axis = 0; axis < 3; axis++) {
      if (d[axis].abs() < 1e-12) {
        if (o[axis] < lo[axis] || o[axis] > hi[axis]) return null;
        continue;
      }
      var t0 = (lo[axis] - o[axis]) / d[axis];
      var t1 = (hi[axis] - o[axis]) / d[axis];
      if (t0 > t1) {
        final tmp = t0;
        t0 = t1;
        t1 = tmp;
      }
      if (t0 > tEnter) tEnter = t0;
      if (t1 < tExit) tExit = t1;
      if (tEnter > tExit) return null;
    }

    var prevT = tEnter;
    var prev = heightDelta(tEnter);
    if (prev <= 0) {
      // The ray starts inside the ground (or enters the box below the
      // surface): the entry point is the hit.
      final p = origin + dir * tEnter;
      final mx = p.x / LandscapeEditorViewModel.unitsPerMetre, mz = p.z / LandscapeEditorViewModel.unitsPerMetre;
      if (!_data.contains(mx, mz)) return null;
      return Vector3(mx, _data.sampleHeight(mx, mz), mz);
    }
    for (var t = tEnter + step; t <= tExit + step; t += step) {
      final current = heightDelta(t);
      if (prev > 0 && current <= 0) {
        var lo = prevT, hi = t;
        for (var i = 0; i < 24; i++) {
          final mid = (lo + hi) / 2;
          if (heightDelta(mid) > 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        final hit = origin + dir * ((lo + hi) / 2);
        final mx = hit.x / LandscapeEditorViewModel.unitsPerMetre;
        final mz = hit.z / LandscapeEditorViewModel.unitsPerMetre;
        if (!_data.contains(mx, mz)) return null;
        return Vector3(mx, _data.sampleHeight(mx, mz), mz);
      }
      prevT = t;
      prev = current;
    }
    return null;
  }
}
