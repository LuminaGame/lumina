part of '../landscape_editor_view_model.dart';

/// Sculpt strokes (begin, stamp, end) and height/layer undo/redo.
mixin _LandscapeEditorSculpting on _LandscapeEditorViewModelState {

  // --- Sculpting -------------------------------------------------------------------

  LandscapeBrushSettings get brushSettings => LandscapeBrushSettings(
        tool: _tool,
        radius: _brushRadius,
        strength: _brushStrength,
        falloff: _brushFalloff,
        falloffType: _falloffType,
        invert: _strokeInvert,
      );

  /// Starts a stroke at a world position; `Flatten` samples its target here
  /// and `Noise` seeds itself per stroke.
  @override
  void beginStroke(double worldX, double worldZ, {bool invert = false}) {
    _strokeActive = true;
    _strokeInvert = invert;
    _strokeRect = null;
    _preStrokeValues.clear();
    _strokeSeed = _random.nextInt(1 << 30);
    _flattenTarget = _tool == LandscapeTool.flatten ? _data.sampleHeight(worldX, worldZ) : null;
    _lastStampX = null;
    _lastStampZ = null;
    _stamp(worldX, worldZ);
    notifyListeners();
  }

  /// Continues the stroke, stamping every ~¼ radius along the drag.
  @override
  void strokeTo(double worldX, double worldZ) {
    if (!_strokeActive) return;
    final lx = _lastStampX, lz = _lastStampZ;
    if (lx == null || lz == null) {
      _stamp(worldX, worldZ);
      notifyListeners();
      return;
    }
    final dx = worldX - lx;
    final dz = worldZ - lz;
    final dist = math.sqrt(dx * dx + dz * dz);
    final step = math.max(_brushRadius * 0.25, _data.cellSize);
    if (dist < step) return;
    final steps = (dist / step).floor();
    for (var i = 1; i <= steps; i++) {
      final t = (i * step) / dist;
      _stamp(lx + dx * t, lz + dz * t);
    }
    notifyListeners();
  }

  /// Ends the stroke and records it as a single undo transaction.
  @override
  void endStroke() {
    if (!_strokeActive) return;
    _strokeActive = false;
    final rect = _strokeRect;
    _strokeRect = null;
    _strokeInvert = false;
    if (rect == null) {
      _preStrokeValues.clear();
      notifyListeners();
      return;
    }
    final before = Float32List(rect.cellCount);
    final after = Float32List(rect.cellCount);
    var i = 0;
    for (var r = rect.minRow; r <= rect.maxRow; r++) {
      for (var c = rect.minCol; c <= rect.maxCol; c++) {
        final key = r * _data.gridResolution + c;
        after[i] = _data.heightAtIndex(key);
        before[i] = _preStrokeValues[key] ?? _data.heightAtIndex(key);
        i++;
      }
    }
    _preStrokeValues.clear();
    _undo.add(LandscapeUndoEntry(
      label: '${_tool.name} stroke',
      rect: rect,
      heightsBefore: before,
      heightsAfter: after,
    ));
    _redo.clear();
    _dirty = true;
    notifyListeners();
  }

  void _stamp(double worldX, double worldZ) {
    _captureBefore(worldX, worldZ);
    final rect = LandscapeBrush.stamp(
      _data,
      brushSettings,
      worldX,
      worldZ,
      flattenTarget: _flattenTarget,
      noiseSeed: _strokeSeed,
    );
    _lastStampX = worldX;
    _lastStampZ = worldZ;
    if (rect == null) return;
    _strokeRect = _strokeRect == null ? rect : _strokeRect!.union(rect);
    _uploadRect(rect);
  }

  /// Remembers the pre-stroke heights of every cell the next stamp can reach
  /// (once per cell — the first touch wins).
  void _captureBefore(double worldX, double worldZ) {
    final res = _data.gridResolution;
    final span = _brushRadius / _data.cellSize;
    final minCol = math.max(0, (_data.columnOf(worldX) - span).floor());
    final maxCol = math.min(res - 1, (_data.columnOf(worldX) + span).ceil());
    final minRow = math.max(0, (_data.rowOf(worldZ) - span).floor());
    final maxRow = math.min(res - 1, (_data.rowOf(worldZ) + span).ceil());
    for (var r = minRow; r <= maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        final key = r * res + c;
        _preStrokeValues.putIfAbsent(key, () => _data.heightAtIndex(key));
      }
    }
  }

  // --- Undo / redo --------------------------------------------------------------

  @override
  void undo() {
    if (_undo.isEmpty) return;
    final entry = _undo.removeLast();
    if (entry.isHeightStroke) {
      _applyRect(entry.rect!, entry.heightsBefore!);
    } else {
      _applyLayer(entry.layerIndex!, entry.layerBefore!);
    }
    _redo.add(entry);
    _dirty = true;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final entry = _redo.removeLast();
    if (entry.isHeightStroke) {
      _applyRect(entry.rect!, entry.heightsAfter!);
    } else {
      _applyLayer(entry.layerIndex!, entry.layerAfter!);
    }
    _undo.add(entry);
    _dirty = true;
    notifyListeners();
  }

  void _applyRect(HeightRect rect, Float32List values) {
    var i = 0;
    for (var r = rect.minRow; r <= rect.maxRow; r++) {
      for (var c = rect.minCol; c <= rect.maxCol; c++) {
        _data.setHeightAtIndex(r * _data.gridResolution + c, values[i++]);
      }
    }
    _uploadRect(rect);
  }

  void _applyLayer(int layerIndex, Float32List transforms) {
    if (layerIndex < 0 || layerIndex >= _data.layers.length) return;
    final layer = _data.layers[layerIndex];
    layer.clearInstances();
    final count = transforms.length ~/ FoliageLayer.floatsPerInstance;
    for (var i = 0; i < count; i++) {
      final o = i * FoliageLayer.floatsPerInstance;
      layer.addInstance(FoliageInstance(
        x: transforms[o],
        y: transforms[o + 1],
        z: transforms[o + 2],
        scaleX: transforms[o + 3],
        scaleY: transforms[o + 4],
        scaleZ: transforms[o + 5],
        yaw: transforms[o + 6],
        nx: transforms[o + 7],
        ny: transforms[o + 8],
        nz: transforms[o + 9],
      ));
    }
    _rebuildFoliageBatch(layerIndex);
  }
}
