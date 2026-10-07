import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart'
    show AssetType, LandscapeData, LandscapeMeshBuilder, LuminaLandscapeComponent, LuminaUnits, RealAssetInfo;
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart' show TransactionManager, TransactionOrigin;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_terrain_sink.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_brush_preferences.dart';

part 'landscape_editor_view_model/state.dart';
part 'landscape_editor_view_model/brush.dart';
part 'landscape_editor_view_model/sculpting.dart';
part 'landscape_editor_view_model/foliage.dart';
part 'landscape_editor_view_model/mesh_and_raycast.dart';

/// Which left/right panel the sub-editor shows.
enum LandscapeEditorTab { manage, sculpt, foliage }

/// Paint or erase, for the foliage brush.
enum FoliagePaintMode { paint, erase }

/// One undoable edit.
///
/// Height strokes snapshot **only the dirty rect** (the mesh is regenerable,
/// so nothing else has to be stored); foliage operations snapshot the edited
/// layer's transform array, which is the layer's entire state and still tiny
/// next to the heightmap.
class LandscapeUndoEntry {
  final String label;
  final HeightRect? rect;
  final Float32List? heightsBefore;
  final Float32List? heightsAfter;
  final int? layerIndex;
  final Float32List? layerBefore;
  final Float32List? layerAfter;

  /// Who made the edit (an agent's stroke is scoped like its Blueprint edits
  /// under the shared undo).
  final TransactionOrigin origin;

  LandscapeUndoEntry({
    required this.label,
    this.rect,
    this.heightsBefore,
    this.heightsAfter,
    this.layerIndex,
    this.layerBefore,
    this.layerAfter,
    TransactionOrigin? origin,
  }) : origin = origin ?? TransactionManager.currentOrigin ?? const TransactionOrigin.user();

  bool get isHeightStroke => rect != null;

  /// Cells stored by this entry's snapshot (a stroke stores its rect, never
  /// the whole map).
  int get snapshotCellCount => heightsBefore?.length ?? 0;
}

/// View model of the Landscape / Foliage sub-editor.
///
/// Owns a real [LandscapeData] (heightmap + foliage layers), applies the
/// sculpt brushes as pure maths over `heights`, maps the dirty rect of every
/// stamp onto the affected mesh tiles' row-contiguous vertex windows, scatters
/// foliage instances with the layer's real placement rules, and persists
/// everything into a `LANDSCAPE` `.lmas`. Everything that must reach the GPU
/// goes through [LandscapeTerrainSink].
///
/// **Units.** Everything the user reads or types is centimetres, like the rest
/// of the editor: labels go through [formatCm] and the panel
/// converts slider values with `LuminaUnits`. The view model itself works in
/// the `LANDSCAPE` payload's terrain-local **metres** (`LandscapeData`, the
/// brush maths, [setBrushRadius], [setNewTerrainWorldSize]): that payload is
/// the engine's heightfield format — shared with the runtime
/// `LuminaLandscapeComponent`, its residency budgets and its uint16 height
/// quantisation — and is deliberately not a stored transform, so no stored
/// data is migrated.
class LandscapeEditorViewModel extends _LandscapeEditorViewModelState
    with
        _LandscapeEditorBrush,
        _LandscapeEditorSculpting,
        _LandscapeEditorFoliage,
        _LandscapeEditorMeshAndRaycast {
  LandscapeEditorViewModel({super.editor, super.assetPath, super.sink, super.randomSeed});
  /// Preview-world units per metre. The landscape preview world is metre
  /// scaled: a 256 m terrain is 256 units wide, which keeps it inside the
  /// shared sub-editor viewport's camera range (near 0.1, far 10 000, orbit
  /// ≤ 1 500 units) — in centimetres the same terrain would be 25 600 units,
  /// beyond its far plane. The preview is not authored data; what the user
  /// reads is converted to cm.
  static const double unitsPerMetre = 1.0;

  /// A terrain-space length (metres) as whole centimetres, for the UI.
  static String formatCm(double metres) => LuminaUnits.metres(metres).toStringAsFixed(0);

  /// The transform a foliage instance is drawn with in the preview: the
  /// engine's own rule ([LuminaLandscapeComponent.foliageMatrix]) — glTF
  /// meshes are metres, so in this metre-scaled preview a barrel painted at
  /// scale 1 is drawn at its real size.
  static Matrix4 foliageMatrixOf(FoliageInstance instance) =>
      LuminaLandscapeComponent.foliageMatrix(instance, unitsPerMetre: unitsPerMetre);

  /// Instance capacity of a foliage batch: `LuminaInstancedStaticMeshComponent`
  /// cannot grow live, so each layer is created with this cap and rebuilt when
  /// it is exceeded.
  static const int foliageCapacityPerLayer = 4096;

  // --- State -----------------------------------------------------------------

  @override
  LandscapeData get data => _data;
  LandscapeSectionMap get sectionMap => _sections;

  /// True when the engine component owns tile mounting (residency-streamed)
  /// rather than the view model pushing every tile.
  bool get engineOwnsTerrain => _engineOwnsTerrain;

  /// What is really resident right now, or null when nothing streams.
  LandscapeResidencyStats? get residencyStats => sink.residencyStats;

  /// Moves the point residency is centred on. Terrain-space metres.
  ///
  /// Does nothing until the engine owns tile mounting — a terrain small enough
  /// to be fully resident has nothing to stream.
  @override
  void setPreviewCamera(double worldX, double worldZ) {
    if (!_engineOwnsTerrain) return;
    if ((worldX - _cameraX).abs() < _data.cellSize && (worldZ - _cameraZ).abs() < _data.cellSize) {
      return;
    }
    _cameraX = worldX;
    _cameraZ = worldZ;
    sink.updateResidency(worldX, worldZ);
    notifyListeners();
  }
  @override
  LandscapeTool get tool => _tool;
  double get brushRadius => _brushRadius;
  double get brushStrength => _brushStrength;
  double get brushFalloff => _brushFalloff;
  @override
  LandscapeFalloffType get falloffType => _falloffType;

  /// Foliage brush radius, terrain metres (shown in cm).
  double get foliageBrushRadius => _foliageBrushRadius;
  double get foliageBrushFalloff => _foliageBrushFalloff;

  /// Fraction of a layer's density one scatter pass lays down (Paint
  /// Density).
  double get paintDensity => _paintDensity;

  /// Density an erase pass thins the core down to, as a fraction of what is
  /// there (Erase Density): 0 clears it.
  @override
  double get eraseDensity => _eraseDensity;

  /// The cells the last sculpt stroke edited, or null.
  HeightRect? get lastStrokeRect => _undo.isEmpty ? null : _undo.last.rect;
  @override
  LandscapeEditorTab get tab => _tab;
  FoliagePaintMode get paintMode => _paintMode;
  int get selectedFoliageLayer => _selectedLayer;
  int get newTerrainResolution => _newResolution;
  double get newTerrainWorldSize => _newWorldSize;
  double get newTerrainMaxHeight => _newMaxHeight;
  bool get isDirty => _dirty;
  bool get isOpened => _opened;
  String? get statusMessage => _statusMessage;
  @override
  double? get flattenTarget => _flattenTarget;
  bool get isStroking => _strokeActive;
  double? get cursorWorldX => _cursorX;
  double? get cursorWorldZ => _cursorZ;

  /// True when a live lumina world renders the terrain; false means the
  /// viewport shows the "engine preview unavailable" badge instead of a fake.
  bool get isPreviewAttached => sink.isAvailable;

  double get heightMin => _data.heightMin;
  double get heightMax => _data.heightMax;
  @override
  int get sectionCount => _sections.sectionCount;
  int get foliageInstanceCount => _data.layers.fold(0, (s, l) => s + l.instanceCount);

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  /// The label (`sculpt stroke`, `foliage <layer>`) and origin of the entry
  /// Undo / Redo would apply, and the undo history newest first
  /// (the landscape stack as a shared undo scope).
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;
  TransactionOrigin? get undoTopOrigin => _undo.isEmpty ? null : _undo.last.origin;
  TransactionOrigin? get redoTopOrigin => _redo.isEmpty ? null : _redo.last.origin;
  List<LandscapeUndoEntry> get undoHistory => List.unmodifiable(_undo.reversed);
  int get lastSnapshotCellCount => _undo.isEmpty ? 0 : _undo.last.snapshotCellCount;

  /// Mesh assets available as foliage types — the project's real FILAMESH
  /// assets, never a hardcoded list.
  List<RealAssetInfo> get meshPalette =>
      editor?.realAssets.where((a) => a.type == AssetType.filamesh).toList() ?? const [];

  String get statsLabel => '${_data.gridResolution} × ${_data.gridResolution} verts · '
      '${formatCm(_data.worldSize)} cm · '
      '${formatCm(heightMin)} cm … ${formatCm(heightMax)} cm';

  String get hudLabel {
    final x = _cursorX, z = _cursorZ;
    final tile = (x == null || z == null) ? '—' : '#${_sectionIndexAtWorld(x, z)}';
    final stats = residencyStats;
    final residency = stats == null
        ? 'Sections: ${_sections.sectionCount}'
        // Measured, not estimated: tiles, triangles and bytes all come back
        // from the engine's own buffers.
        : stats.label;
    return 'Tool: ${_tool.name} · $residency · Tile: $tile · '
        'Height ${formatCm(heightMin)}–${formatCm(heightMax)} cm · '
        'Foliage $foliageInstanceCount';
  }

  // --- Lifecycle ---------------------------------------------------------------

  /// Loads the asset (or starts from a flat terrain) and mounts it.
  void open() {
    if (_opened) return;
    _opened = true;
    _loadBrushPreferences();
    final path = assetPath;
    final loaded = path == null ? null : LandscapeAssetService.load(path);
    _data = loaded ?? LandscapeData.flat(gridResolution: _newResolution, worldSize: _newWorldSize, maxHeight: _newMaxHeight);
    _selectedLayer = _data.layers.isEmpty ? -1 : 0;
    _rebuildAll();
    _dirty = false;
    _statusMessage = loaded == null ? 'New flat terrain (${_data.gridResolution}²)' : 'Loaded ${_data.gridResolution}² terrain';
    _persistBrushes = true;
    notifyListeners();
  }

  /// The project this landscape belongs to, where the brush settings live.
  String? get _projectDir {
    final fromEditor = editor?.projectDirPath;
    if (fromEditor != null && fromEditor.isNotEmpty) return fromEditor;
    return LandscapeBrushPreferences.projectDirOf(assetPath);
  }

  void _loadBrushPreferences() {
    final dir = _projectDir;
    if (dir == null) return;
    final p = LandscapeBrushPreferences.load(dir);
    if (p == null) return;
    _tool = p.tool;
    _brushRadius = p.sculptRadius.clamp(1.0, 200.0);
    _brushStrength = p.sculptStrength.clamp(0.01, 1.0);
    _brushFalloff = p.sculptFalloff.clamp(0.0, 1.0);
    _falloffType = p.falloffType;
    _foliageBrushRadius = p.foliageRadius.clamp(1.0, 200.0);
    _foliageBrushFalloff = p.foliageFalloff.clamp(0.0, 1.0);
    _paintDensity = p.paintDensity.clamp(0.0, 1.0);
    _eraseDensity = p.eraseDensity.clamp(0.0, 1.0);
  }

  /// Writes both brushes to the project's `.lumina/landscape_brush.json`.
  @override
  void _saveBrushPreferences() {
    if (!_persistBrushes) return;
    final dir = _projectDir;
    if (dir == null) return;
    LandscapeBrushPreferences(
      tool: _tool,
      sculptRadius: _brushRadius,
      sculptStrength: _brushStrength,
      sculptFalloff: _brushFalloff,
      falloffType: _falloffType,
      foliageRadius: _foliageBrushRadius,
      foliageFalloff: _foliageBrushFalloff,
      paintDensity: _paintDensity,
      eraseDensity: _eraseDensity,
    ).save(dir);
  }

  /// Replaces the terrain with a fresh flat grid.
  void createTerrain({required int gridResolution, required double worldSize, required double maxHeight}) {
    _data = LandscapeData.flat(gridResolution: gridResolution, worldSize: worldSize, maxHeight: maxHeight);
    _selectedLayer = -1;
    _undo.clear();
    _redo.clear();
    _rebuildAll();
    _dirty = true;
    _statusMessage = 'Created flat terrain $gridResolution² over ${formatCm(worldSize)} cm';
    notifyListeners();
  }

  /// `New Terrain` form → real terrain.
  void createTerrainFromForm() => createTerrain(
        gridResolution: _newResolution,
        worldSize: _newWorldSize,
        maxHeight: _newMaxHeight,
      );

  /// Progress of a running heightmap import, `0..1`, or null when idle.
  double? get importProgress => _importProgress;

  /// Imports a heightmap without freezing the editor.
  ///
  /// The PNG decode runs in a background isolate and [importProgress] ticks as
  /// each stage completes, so a large map shows a progress bar instead of a
  /// frozen window. Returns false and leaves the terrain untouched on any
  /// rejection — including a size that does not tile, which comes back naming
  /// the nearest sizes that would.
  Future<bool> importHeightmapFileAsync(String path) async {
    _importProgress = 0.0;
    _statusMessage = 'Importing ${File(path).uri.pathSegments.last}…';
    notifyListeners();
    try {
      final imported = await LandscapeAssetService.importHeightmapFileAsync(
        path: path,
        worldSize: _newWorldSize,
        maxHeight: _newMaxHeight,
        onProgress: (progress, stage) {
          _importProgress = progress;
          _statusMessage = stage;
          notifyListeners();
        },
      );
      _adoptImported(imported, path);
    } catch (e) {
      _importProgress = null;
      _statusMessage = 'Heightmap import failed: ${e is ArgumentError ? e.message : e}';
      notifyListeners();
      return false;
    }
    _importProgress = null;
    notifyListeners();
    return true;
  }

  void _adoptImported(LandscapeData imported, String path) {
    // Foliage placed on the old terrain no longer matches the new heights.
    _data = imported;
    _selectedLayer = -1;
    _undo.clear();
    _redo.clear();
    _newResolution = imported.gridResolution;
    _rebuildAll();
    _dirty = true;
    _statusMessage = 'Imported ${imported.gridResolution}² heightmap from ${File(path).uri.pathSegments.last}';
  }

  /// Imports a real grayscale heightmap PNG from disk, synchronously.
  bool importHeightmapFile(String path) {
    try {
      final imported = LandscapeAssetService.importHeightmapFile(
        path: path,
        worldSize: _newWorldSize,
        maxHeight: _newMaxHeight,
      );
      _adoptImported(imported, path);
    } catch (e) {
      _statusMessage = 'Heightmap import failed: ${e is ArgumentError ? e.message : e}';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  // --- Persistence ------------------------------------------------------------------

  Future<bool> save() async {
    final path = assetPath;
    if (path == null) {
      _statusMessage = 'This landscape has no asset path — use Save As from the Content Browser';
      notifyListeners();
      return false;
    }
    try {
      final name = File(path).uri.pathSegments.last.replaceAll('.lmas', '');
      await LandscapeAssetService.save(path: path, name: name, data: _data);
      _dirty = false;
      _statusMessage = 'Saved $name.lmas (${_data.gridResolution}², $foliageInstanceCount instances)';
      editor?.refreshAssets();
    } catch (e) {
      _statusMessage = 'Save failed: $e';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }
}
