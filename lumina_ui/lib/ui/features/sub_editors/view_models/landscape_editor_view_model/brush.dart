part of '../landscape_editor_view_model.dart';

/// Brush and form settings (tool, size, strength, falloff, densities, tab,
/// new-terrain form) and brush input from the 3D viewport.
mixin _LandscapeEditorBrush on _LandscapeEditorViewModelState {

  // --- Brush settings ------------------------------------------------------------

  void setTool(LandscapeTool tool) {
    if (_tool == tool) return;
    _tool = tool;
    _brushChanged();
  }

  /// Sculpt brush radius in terrain metres (the panel shows cm).
  void setBrushRadius(double metres) {
    final v = metres.clamp(1.0, 200.0);
    if (v == _brushRadius) return;
    _brushRadius = v;
    _brushChanged();
  }

  void setBrushStrength(double v) {
    final c = v.clamp(0.01, 1.0);
    if (c == _brushStrength) return;
    _brushStrength = c;
    _brushChanged();
  }

  void setBrushFalloff(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _brushFalloff) return;
    _brushFalloff = c;
    _brushChanged();
  }

  void setFalloffType(LandscapeFalloffType t) {
    if (_falloffType == t) return;
    _falloffType = t;
    _brushChanged();
  }

  /// Foliage brush radius in terrain metres (the panel shows cm).
  void setFoliageBrushRadius(double metres) {
    final v = metres.clamp(1.0, 200.0);
    if (v == _foliageBrushRadius) return;
    _foliageBrushRadius = v;
    _brushChanged();
  }

  void setFoliageBrushFalloff(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _foliageBrushFalloff) return;
    _foliageBrushFalloff = c;
    _brushChanged();
  }

  void setPaintDensity(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _paintDensity) return;
    _paintDensity = c;
    _brushChanged();
  }

  void setEraseDensity(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _eraseDensity) return;
    _eraseDensity = c;
    _brushChanged();
  }

  /// Runs [body] with brush changes kept out of `.lumina/landscape_brush.json`
  /// (a stroke's one-off overrides are not the user's brush).
  T withoutPersistingBrush<T>(T Function() body) {
    final persisted = _persistBrushes;
    _persistBrushes = false;
    try {
      return body();
    } finally {
      _persistBrushes = persisted;
    }
  }

  void _brushChanged() {
    _saveBrushPreferences();
    _syncCursor();
    notifyListeners();
  }

  void setTab(LandscapeEditorTab t) {
    if (_tab == t) return;
    _tab = t;
    _syncCursor();
    notifyListeners();
  }

  void setPaintMode(FoliagePaintMode mode) {
    if (_paintMode == mode) return;
    _paintMode = mode;
    _syncCursor();
    notifyListeners();
  }

  void setNewTerrainResolution(int r) {
    if (_newResolution == r) return;
    _newResolution = r;
    notifyListeners();
  }

  void setNewTerrainWorldSize(double m) {
    if (_newWorldSize == m) return;
    _newWorldSize = m;
    notifyListeners();
  }

  void setNewTerrainMaxHeight(double m) {
    if (_newMaxHeight == m) return;
    _newMaxHeight = m;
    notifyListeners();
  }

  /// Brush ring position under the cursor (metres), null when off-terrain.
  void setCursor(double? worldX, double? worldZ) {
    _cursorX = worldX;
    _cursorZ = worldZ;
    // On a streamed terrain the point the user is working at is the point that
    // must stay resident. `SubEditor3DViewport` does not report its orbit
    // target yet, so the sculpt cursor is the streaming focus; the smoke run
    // drives [setPreviewCamera] directly to fly across the terrain.
    if (_engineOwnsTerrain && worldX != null && worldZ != null) {
      setPreviewCamera(worldX, worldZ);
    }
    _syncCursor();
    notifyListeners();
  }

  /// Hides the brush cursor (the mouse left the viewport).
  void clearCursor() => setCursor(null, null);

  /// The cursor the terrain should show now: the active tab's brush under the
  /// mouse, or nothing (Manage tab, or the mouse is off the terrain).
  LandscapeBrushCursorState? get brushCursorState {
    final x = _cursorX, z = _cursorZ;
    if (x == null || z == null || _tab == LandscapeEditorTab.manage) return null;
    if (_tab == LandscapeEditorTab.foliage) {
      final erase = (_paintMode == FoliagePaintMode.erase) != (_viewportBrushDown && _viewportBrushInvert);
      return LandscapeBrushCursorState(
        x: x,
        z: z,
        radius: _foliageBrushRadius,
        falloff: _foliageBrushFalloff,
        kind: erase ? LandscapeCursorKind.erase : LandscapeCursorKind.scatter,
      );
    }
    return LandscapeBrushCursorState(
      x: x,
      z: z,
      radius: _brushRadius,
      falloff: _brushFalloff,
      kind: LandscapeCursorKind.sculpt,
    );
  }

  /// Pushes [brushCursorState] to the sink when it changed.
  @override
  void _syncCursor({bool force = false}) {
    final next = brushCursorState;
    if (!force && next == _pushedCursor) return;
    _pushedCursor = next;
    sink.setBrushCursor(next);
  }

  // --- Brush input from the 3D viewport ----------------------------------------------

  /// The mouse moved over the viewport: the cursor follows the terrain under
  /// the camera ray ([origin], [direction] in preview-world units).
  void hoverRay(Vector3 origin, Vector3 direction) {
    final hit = raycast(origin, direction);
    setCursor(hit?.x, hit?.z);
  }

  /// A plain LMB press in the viewport (Shift: [invert]). Sculpt tab: starts
  /// a stroke (Shift lowers); Foliage tab: starts a scatter drag, or an erase
  /// drag in Erase mode (Shift swaps the two). Returns false in the Manage
  /// tab, where the press belongs to the camera.
  bool brushDown(Vector3 origin, Vector3 direction, {bool invert = false}) {
    if (_tab == LandscapeEditorTab.manage) return false;
    _viewportBrushDown = true;
    _viewportBrushInvert = invert;
    final hit = raycast(origin, direction);
    setCursor(hit?.x, hit?.z);
    if (hit != null) _brushBegin(hit.x, hit.z);
    return true;
  }

  /// The pressed mouse moved: the stroke or drag continues to the terrain
  /// under the ray (and begins there if the press started off the terrain).
  void brushDrag(Vector3 origin, Vector3 direction) {
    if (!_viewportBrushDown) return;
    final hit = raycast(origin, direction);
    setCursor(hit?.x, hit?.z);
    if (hit == null) return;
    if (!_strokeActive && !_foliageStrokeActive) {
      _brushBegin(hit.x, hit.z);
    } else if (_strokeActive) {
      strokeTo(hit.x, hit.z);
    } else {
      foliageStrokeTo(hit.x, hit.z);
    }
  }

  /// The mouse button came up: the stroke or drag becomes one undo entry.
  void brushUp() {
    if (!_viewportBrushDown) return;
    _viewportBrushDown = false;
    _viewportBrushInvert = false;
    if (_strokeActive) endStroke();
    if (_foliageStrokeActive) endFoliageStroke();
    _syncCursor();
  }

  void _brushBegin(double x, double z) {
    if (_tab == LandscapeEditorTab.sculpt) {
      beginStroke(x, z, invert: _viewportBrushInvert);
    } else if (_tab == LandscapeEditorTab.foliage) {
      final erase = (_paintMode == FoliagePaintMode.erase) != _viewportBrushInvert;
      beginFoliageStroke(x, z, erase: erase);
    }
  }
}
