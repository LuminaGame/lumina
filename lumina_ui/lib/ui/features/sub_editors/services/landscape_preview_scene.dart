import 'dart:async';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueKey, debugPrint;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3, Vector4;

import '../models/landscape_terrain_sink.dart';
import '../view_models/landscape_editor_view_model.dart' show LandscapeEditorViewModel;

/// Mounts the engine's terrain component in the Landscape sub-editor's preview
/// world.
///
/// There is exactly one implementation of terrain drawing in the stack and it
/// lives in `package:lumina`: [LuminaLandscapeComponent] owns the procedural
/// mesh tiles, the foliage instance batches, their chunking against
/// `maxAutomaticInstances` and the MIKKTSPACE-split detection that decides
/// whether a tile can take a windowed upload. This class is the adapter
/// between the sub-editor's [LandscapeTerrainSink] seam and that component —
/// it holds no geometry, no materials and no batching logic of its own.
///
/// Nothing here fabricates terrain: without an attached world [isAvailable]
/// is false and the editor shows an honest "preview unavailable" badge; when a
/// foliage batch cannot be created, [foliageError] says why.
class LandscapePreviewScene implements LandscapeTerrainSink {
  static const double _tickSeconds = 1.0 / 30.0;

  LuminaWorld? _world;
  LuminaActor? _terrainActor;
  LuminaLandscapeComponent? _landscape;
  LuminaDirectionalLightComponent? _sun;

  /// Where the preview sun shines: 35° above the horizon, from the right of
  /// and slightly behind the viewport's default camera, so the shadows hills
  /// and foliage throw fall across the view instead of hiding behind them.
  static final Vector3 sunDirection = Vector3(-0.799, -0.574, -0.181)..normalize();

  /// Cursor colours (linear RGB): sculpt amber, scatter green, erase red.
  static final Map<LandscapeCursorKind, Vector3> cursorColors = {
    LandscapeCursorKind.sculpt: Vector3(1.0, 0.62, 0.1),
    LandscapeCursorKind.scatter: Vector3(0.3, 1.0, 0.35),
    LandscapeCursorKind.erase: Vector3(1.0, 0.2, 0.18),
  };

  Timer? _ticker;

  /// Fired whenever a batch finishes building (so the UI can repaint counts).
  void Function()? onChanged;

  /// The engine component drawing the terrain, once attached.
  LuminaLandscapeComponent? get landscape => _landscape;

  /// The preview's shadow-casting sun, once attached.
  LuminaDirectionalLightComponent? get sun => _sun;

  String? get foliageError => _landscape?.foliageError;
  LuminaProceduralMeshComponent? get terrain => _landscape?.terrainMesh;
  LuminaWorld? get world => _world;
  int get terrainSectionCount => _landscape?.sectionCount ?? 0;

  /// Foliage layers with a mounted (or mounting) instance batch.
  int get batchCount => _layersSeen.length;

  final Set<int> _layersSeen = {};

  int foliageInstanceCount(int layerIndex) => _landscape?.foliageInstanceCount(layerIndex) ?? 0;

  int get totalFoliageInstances =>
      _layersSeen.fold(0, (s, i) => s + (_landscape?.foliageInstanceCount(i) ?? 0));

  /// Renderables currently drawing foliage (one per chunk).
  int get foliageChunkCount => _landscape?.foliageChunkCount ?? 0;

  @override
  bool get isAvailable => _world != null && !_world!.isCleanedUp && _landscape != null;

  @override
  bool mountPayload(LandscapeData data) {
    final landscape = _landscape;
    if (landscape == null) return false;
    _layersSeen
      ..clear()
      ..addAll(List.generate(data.layers.length, (i) => i));
    _fitSunShadows(data);
    unawaited(landscape.mountPayload(data).then((_) {
      try {
        _world?.tick(_tickSeconds);
      } catch (_) {}
      onChanged?.call();
    }));
    return true;
  }

  @override
  void updateResidency(double worldX, double worldZ) {
    final landscape = _landscape;
    if (landscape == null) return;
    try {
      landscape.updateResidency(Vector3(
        worldX * LandscapeEditorViewModel.unitsPerMetre,
        0.0,
        worldZ * LandscapeEditorViewModel.unitsPerMetre,
      ));
    } catch (e) {
      debugPrint('[LandscapePreviewScene] updateResidency failed: $e');
    }
  }

  @override
  bool isSectionResident(int sectionIndex) => _landscape?.isSectionResident(sectionIndex) ?? false;

  @override
  bool rebuildSection(int sectionIndex) => _landscape?.rebuildResidentSection(sectionIndex) ?? false;

  @override
  LandscapeResidencyStats? get residencyStats {
    final landscape = _landscape;
    if (landscape == null) return null;
    return LandscapeResidencyStats(
      residentSections: landscape.residentSectionCount,
      totalSections: landscape.totalSectionCount,
      triangles: landscape.residentTriangleCount,
      vertices: landscape.residentVertexCount,
      gpuBytes: landscape.residentGpuBytes,
      droppedForBudget: landscape.tilesOutsideBudget,
      foliageInstances: totalFoliageInstances,
      foliageRenderables: landscape.foliageChunkCount,
    );
  }

  // --- Lifecycle ---------------------------------------------------------------

  /// Binds a world handed over by the viewport and mounts lighting + terrain.
  void attach(LuminaWorld world) {
    detach();
    if (world.isCleanedUp || !world.hasNativeContext) return;
    _world = world;
    try {
      _sun = LuminaDirectionalLightComponent(
        rotation: Quaternion.fromTwoVectors(Vector3(0.0, 0.0, -1.0), sunDirection),
        color: Vector3(1.0, 0.97, 0.92),
        intensity: 110000.0,
        castShadows: true,
        isSun: true,
      );
      _register(LuminaActor(key: const ValueKey('landscape_preview_sun'), root: _sun!));
      _register(LuminaActor(
        key: const ValueKey('landscape_preview_sky'),
        root: LuminaSkyComponent.color(
          color: Vector4(0.42, 0.55, 0.72, 1.0),
          skyIntensity: 30000.0,
          // Enough sky light that shadowed ground reads as ground, not black.
          iblIntensity: 22000.0,
        ),
      ));
      // glTF foliage is drawn at the asset unit scale by the engine itself,
      // so the preview passes no mesh-scale correction.
      _landscape = LuminaLandscapeComponent.editable(unitsPerMetre: LandscapeEditorViewModel.unitsPerMetre);
      _terrainActor = LuminaActor(key: const ValueKey('landscape_preview_terrain'), root: _landscape!);
      _register(_terrainActor!);
      _landscape!.ensureTerrainMesh();
      world.tick(_tickSeconds);
    } catch (e, st) {
      debugPrint('[LandscapePreviewScene] attach failed: $e\n$st');
      _landscape = null;
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void detach() {
    _ticker?.cancel();
    _ticker = null;
    final w = _world;
    try {
      if (w != null && !w.isCleanedUp && _terrainActor != null) {
        w.persistentLevel.unregisterActor(_terrainActor!);
      }
    } catch (e) {
      debugPrint('[LandscapePreviewScene] detach cleanup: $e');
    }
    _layersSeen.clear();
    _terrainActor = null;
    _landscape = null;
    _sun = null;
    _world = null;
  }

  /// Sizes the sun's shadow maps for [data] in this metre-scaled preview.
  ///
  /// lumina's default shadow options are tuned for centimetre worlds. Here a 256 m terrain is 256 units: the shadow distance must
  /// cover its diagonal, with three cascades on a 2048 map so a barrel's
  /// shadow near the camera stays sharp while the far hills still cast.
  void _fitSunShadows(LandscapeData data) {
    final sun = _sun;
    if (sun == null) return;
    final diagonal = data.worldSize * math.sqrt2 * LandscapeEditorViewModel.unitsPerMetre;
    final far = (diagonal * 1.1).clamp(60.0, 4000.0);
    try {
      sun.shadowOptions = LuminaShadowSettings(mapSize: 2048, cascades: 3, shadowFar: far)
          .toShadowOptions(cameraNear: 0.1, cameraFar: far);
    } catch (e) {
      debugPrint('[LandscapePreviewScene] sun shadow options: $e');
    }
  }

  void _tick() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      w.tick(_tickSeconds);
    } catch (e) {
      debugPrint('[LandscapePreviewScene] tick failed: $e');
    }
  }

  // --- Terrain -----------------------------------------------------------------

  @override
  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  }) {
    try {
      _landscape?.createTerrainSection(
        sectionIndex,
        positions: positions,
        normals: normals,
        uv0: uv0,
        colors: colors,
        indices: indices,
      );
    } catch (e, st) {
      debugPrint('[LandscapePreviewScene] createTerrainSection($sectionIndex) failed: $e\n$st');
    }
  }

  @override
  bool supportsPartialUpdate(int sectionIndex) => _landscape?.supportsPartialUpdate(sectionIndex) ?? false;

  @override
  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  }) {
    try {
      _landscape?.updateTerrainSection(window, positions: positions, normals: normals, colors: colors);
    } catch (e) {
      debugPrint('[LandscapePreviewScene] updateTerrainSection(${window.sectionIndex}) failed: $e');
    }
  }

  @override
  void clearTerrain() {
    try {
      _landscape?.clearTerrain();
      _landscape?.clearFoliage();
    } catch (e) {
      debugPrint('[LandscapePreviewScene] clearTerrain: $e');
    }
    _layersSeen.clear();
  }

  // --- Foliage -----------------------------------------------------------------

  @override
  void createFoliageBatch(int layerIndex, {required String meshAssetPath, required int capacity}) {
    final landscape = _landscape;
    if (landscape == null) return;
    _layersSeen.add(layerIndex);
    // Mesh parsing is asynchronous; the component queues instances painted in
    // the meantime and flushes them when the batch is ready.
    unawaited(landscape.mountFoliageLayer(layerIndex, meshAssetPath: meshAssetPath).then((_) {
      try {
        _world?.tick(_tickSeconds);
      } catch (_) {}
      onChanged?.call();
    }));
  }

  @override
  int addFoliageInstance(int layerIndex, Matrix4 transform) =>
      _landscape?.addFoliageInstance(layerIndex, transform) ?? -1;

  @override
  void removeFoliageInstance(int layerIndex, int instanceIndex) =>
      _landscape?.removeFoliageInstance(layerIndex, instanceIndex);

  // --- Brush cursor ------------------------------------------------------------

  @override
  void setBrushCursor(LandscapeBrushCursorState? cursor) {
    final landscape = _landscape;
    if (landscape == null) return;
    try {
      if (cursor == null) {
        landscape.hideBrushCursor();
        return;
      }
      const u = LandscapeEditorViewModel.unitsPerMetre;
      landscape.showBrushCursor(LandscapeBrushCursor(
        centerX: cursor.x * u,
        centerZ: cursor.z * u,
        radius: cursor.radius * u,
        falloff: cursor.falloff,
        color: cursorColors[cursor.kind],
      ));
    } catch (e) {
      debugPrint('[LandscapePreviewScene] brush cursor: $e');
    }
  }

  // --- Helpers -----------------------------------------------------------------

  void _register(LuminaActor actor) => _world!.persistentLevel.registerActor(actor);
}
