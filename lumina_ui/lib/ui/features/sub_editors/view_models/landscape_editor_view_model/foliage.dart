part of '../landscape_editor_view_model.dart';

/// Foliage layers and foliage paint/erase strokes with their undo entries.
mixin _LandscapeEditorFoliage on _LandscapeEditorViewModelState {

  // --- Foliage ---------------------------------------------------------------------

  int addFoliageLayer({required String meshAssetId, required String meshAssetPath, String? name}) {
    final layer = FoliageLayer(
      meshAssetId: meshAssetId,
      meshAssetPath: meshAssetPath,
      name: name ?? meshAssetId,
    );
    _data.layers.add(layer);
    final index = _data.layers.length - 1;
    sink.createFoliageBatch(index, meshAssetPath: meshAssetPath, capacity: LandscapeEditorViewModel.foliageCapacityPerLayer);
    _selectedLayer = index;
    _dirty = true;
    notifyListeners();
    return index;
  }

  void removeFoliageLayer(int index) {
    if (index < 0 || index >= _data.layers.length) return;
    _data.layers.removeAt(index);
    if (_selectedLayer >= _data.layers.length) _selectedLayer = _data.layers.length - 1;
    _rebuildFoliage();
    _dirty = true;
    notifyListeners();
  }

  void selectFoliageLayer(int index) {
    if (index < -1 || index >= _data.layers.length || index == _selectedLayer) return;
    _selectedLayer = index;
    notifyListeners();
  }

  void setLayerRules(int index, FoliageRules rules) {
    if (index < 0 || index >= _data.layers.length) return;
    _data.layers[index].rules = rules;
    _dirty = true;
    notifyListeners();
  }

  /// Scatters instances of the active layer into the foliage brush circle
  /// (one undo entry); returns how many were placed.
  int paintFoliage(double worldX, double worldZ, {int? layerIndex}) {
    final index = layerIndex ?? _selectedLayer;
    if (index < 0 || index >= _data.layers.length) return 0;
    final layer = _data.layers[index];
    final before = Float32List.fromList(layer.transforms);
    final placed = _scatterAt(index, worldX, worldZ);
    if (placed <= 0) {
      if (placed == 0) _statusMessage = 'No foliage placed — check density, spacing and slope range';
      notifyListeners();
      return 0;
    }
    _pushFoliageUndo(index, before, layer);
    _dirty = true;
    _statusMessage = 'Placed $placed instances of "${layer.name}"';
    notifyListeners();
    return placed;
  }

  /// Erases instances of the active layer inside the foliage brush circle
  /// (one undo entry) — thinned by its falloff and Erase Density; swap-removes
  /// are mirrored into the GPU batch. Returns how many were removed.
  int eraseFoliage(double worldX, double worldZ, {int? layerIndex}) {
    final index = layerIndex ?? _selectedLayer;
    if (index < 0 || index >= _data.layers.length) return 0;
    final layer = _data.layers[index];
    final before = Float32List.fromList(layer.transforms);
    final removed = _eraseAt(index, worldX, worldZ);
    if (removed == 0) return 0;
    _pushFoliageUndo(index, before, layer);
    _dirty = true;
    _statusMessage = 'Erased $removed instances of "${layer.name}"';
    notifyListeners();
    return removed;
  }

  /// Starts a foliage drag on the active layer: scatter, or erase when
  /// [erase]. The drag stamps along its path and becomes one undo entry at
  /// [endFoliageStroke].
  @override
  void beginFoliageStroke(double worldX, double worldZ, {bool erase = false}) {
    final index = _selectedLayer;
    if (index < 0 || index >= _data.layers.length) return;
    _foliageStrokeActive = true;
    _foliageStrokeErase = erase;
    _foliageStrokeLayer = index;
    _foliageStrokeBefore = Float32List.fromList(_data.layers[index].transforms);
    _foliageStamp(worldX, worldZ);
    notifyListeners();
  }

  /// Continues a foliage drag, stamping every ¼ brush radius along the path.
  @override
  void foliageStrokeTo(double worldX, double worldZ) {
    if (!_foliageStrokeActive) return;
    final lx = _foliageLastX, lz = _foliageLastZ;
    if (lx == null || lz == null) {
      _foliageStamp(worldX, worldZ);
      notifyListeners();
      return;
    }
    final dx = worldX - lx;
    final dz = worldZ - lz;
    final dist = math.sqrt(dx * dx + dz * dz);
    final step = math.max(_foliageBrushRadius * 0.25, _data.cellSize);
    if (dist < step) return;
    final steps = (dist / step).floor();
    for (var i = 1; i <= steps; i++) {
      final t = (i * step) / dist;
      _foliageStamp(lx + dx * t, lz + dz * t);
    }
    notifyListeners();
  }

  /// Ends the foliage drag; a drag that changed the layer is one undo entry.
  @override
  void endFoliageStroke() {
    if (!_foliageStrokeActive) return;
    _foliageStrokeActive = false;
    _foliageLastX = null;
    _foliageLastZ = null;
    final index = _foliageStrokeLayer;
    final before = _foliageStrokeBefore;
    _foliageStrokeBefore = null;
    if (before == null || index < 0 || index >= _data.layers.length) return;
    final layer = _data.layers[index];
    final after = layer.transforms;
    var changed = after.length != before.length;
    for (var i = 0; !changed && i < after.length; i++) {
      if (after[i] != before[i]) changed = true;
    }
    if (!changed) {
      notifyListeners();
      return;
    }
    _pushFoliageUndo(index, before, layer);
    _dirty = true;
    final delta = (after.length - before.length) ~/ FoliageLayer.floatsPerInstance;
    _statusMessage = delta >= 0
        ? 'Placed $delta instances of "${layer.name}"'
        : 'Erased ${-delta} instances of "${layer.name}"';
    notifyListeners();
  }

  void _foliageStamp(double worldX, double worldZ) {
    _foliageLastX = worldX;
    _foliageLastZ = worldZ;
    if (_foliageStrokeErase) {
      _eraseAt(_foliageStrokeLayer, worldX, worldZ);
    } else {
      _scatterAt(_foliageStrokeLayer, worldX, worldZ);
    }
  }

  /// One scatter stamp with the foliage brush (no undo, no notify). Returns
  /// the number placed, or −1 when the layer is at its instance cap.
  int _scatterAt(int index, double worldX, double worldZ) {
    final layer = _data.layers[index];
    final placed = LandscapeFoliagePainter.scatter(
      data: _data,
      layer: layer,
      centerX: worldX,
      centerZ: worldZ,
      radius: _foliageBrushRadius,
      falloff: _foliageBrushFalloff,
      densityScale: _paintDensity,
      random: _random,
    );
    if (placed.isEmpty) return 0;
    if (layer.instanceCount + placed.length > LandscapeEditorViewModel.foliageCapacityPerLayer) {
      _statusMessage = 'Layer "${layer.name}" is at its ${LandscapeEditorViewModel.foliageCapacityPerLayer}-instance cap';
      return -1;
    }
    for (final instance in placed) {
      layer.addInstance(instance);
      sink.addFoliageInstance(index, LandscapeEditorViewModel.foliageMatrixOf(instance));
    }
    return placed.length;
  }

  /// One erase stamp with the foliage brush (no undo, no notify).
  int _eraseAt(int index, double worldX, double worldZ) {
    final layer = _data.layers[index];
    final hits = LandscapeFoliagePainter.instancesToErase(
      layer,
      worldX,
      worldZ,
      _foliageBrushRadius,
      falloff: _foliageBrushFalloff,
      eraseDensity: _eraseDensity,
      random: _random,
    );
    for (final hit in hits.reversed) {
      layer.removeAt(hit);
      sink.removeFoliageInstance(index, hit);
    }
    return hits.length;
  }

  void _pushFoliageUndo(int index, Float32List before, FoliageLayer layer) {
    _undo.add(LandscapeUndoEntry(
      label: 'foliage ${layer.name}',
      layerIndex: index,
      layerBefore: before,
      layerAfter: Float32List.fromList(layer.transforms),
    ));
    _redo.clear();
  }
}
