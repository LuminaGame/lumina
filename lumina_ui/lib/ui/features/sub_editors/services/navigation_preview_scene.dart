import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart'
    show CullingMode, FilamentMaterialInstance, FilamentMaterialProvider, MaterialKey;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart' show EditorTransforms;
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart' show EditorPieGame;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;
import 'package:lumina_ui/ui/features/sub_editors/models/navigation_editor_state.dart';

/// Drives the Navigation sub-editor's live viewport through lumina.
///
/// The viewport hands over a [LuminaWorld] bound to its Filament engine; this
/// scene mounts the open level's mesh actors, a sun and a plain sky, plus one
/// [LuminaProceduralMeshComponent] whose sections carry the debug geometry:
/// walkable cells (green quads), blocked cells (red quads), the tested path
/// (blue strip hovering 5 cm above the cell floors) and the start / goal
/// flags. Every section is one batched mesh rebuilt only when its data
/// changes — never per frame. Materials are gltfio ubershader instances
/// (unlit, alpha-blended) obtained through flutter_filament's provider; no
/// raw Filament entity work happens here.
///
/// The preview world is the runtime's: Y up, world units (cm). Level actors'
/// stored (Z-up) transforms are converted with [LuminaAxes] exactly as
/// Play-In-Editor does, and the grid snapshot / path points are already in
/// that space, so the overlay is drawn as-is.
class NavigationPreviewScene {
  LuminaWorld? _world;
  LuminaActor? _overlayActor;
  LuminaProceduralMeshComponent? _overlay;
  FilamentMaterialProvider? _materialProvider;
  final Map<String, FilamentMaterialInstance> _materials = {};
  Timer? _ticker;
  int _meshActorCount = 0;
  NavGridSnapshot? _shownSnapshot;
  bool _overlayVisible = true;
  Object? _shownPathKey;

  static const double _tickSeconds = 1.0 / 30.0;
  static const int walkableSection = 0;
  static const int blockedSection = 1;
  static const int pathSection = 2;
  static const int startFlagSection = 3;
  static const int goalFlagSection = 4;

  /// Overlay quads sit this far above the cell floor (level cm).
  static const double cellHoverCm = 2.0;

  /// Path strip hovers 5 cm above the cell floor heights (task contract).
  static const double pathHoverCm = 5.0;
  static const double pathWidthCm = 12.0;
  static const double flagSizeCm = 30.0;

  bool get isAttached => _world != null && !_world!.isCleanedUp;
  LuminaWorld? get world => _world;
  int get meshActorCount => _meshActorCount;
  LuminaProceduralMeshComponent? get overlay => _overlay;

  /// Number of live overlay sections (walkable / blocked / path / flags).
  int get overlaySectionCount => _overlay?.sectionCount ?? 0;
  bool get hasWalkableSection => _overlay?.hasSection(walkableSection) ?? false;
  bool get hasPathSection => _overlay?.hasSection(pathSection) ?? false;
  int get walkableQuadCount => (_overlay?.sectionVertexCount(walkableSection) ?? 0) ~/ 4;
  int get blockedQuadCount => (_overlay?.sectionVertexCount(blockedSection) ?? 0) ~/ 4;

  /// Binds [world] (already carrying a native context) and mounts the level.
  void attach(
    LuminaWorld world, {
    required List<EditorActorNode> levelActors,
    required String projectDirPath,
  }) {
    detach();
    if (world.isCleanedUp || !world.hasNativeContext) return;
    _world = world;
    _meshActorCount = 0;

    try {
      for (final actor in levelActors) {
        if (!NavigationWorldBuilder.meshActorTypes.contains(actor.type)) continue;
        final path = actor.meshAssetPath;
        if (path == null || !actor.isVisible) continue;
        final mesh = LuminaStaticMeshComponent(
          location: LuminaAxes.location(actor.location),
          rotation: LuminaAxes.rotation(actor.rotation),
          scale: LuminaAxes.scale(actor.scale),
          meshAssetPath: path,
          castShadows: actor.castShadows,
          assetProvider: _readMeshBytes,
          assetUnitScale: EditorTransforms.assetUnitScaleFor(actor),
        );
        mesh.loaded.catchError((Object e) {
          debugPrint('[NavigationPreviewScene] mesh ${actor.name} failed to load: $e');
        });
        _register(LuminaActor(key: LuminaObjectKey('nav_preview_${actor.id}'), root: mesh));
        _meshActorCount++;
      }
      _register(LuminaActor(
        key: const LuminaObjectKey('nav_preview_sun'),
        root: LuminaDirectionalLightComponent(
          rotation: EditorPieGame.eulerDegreesToQuaternion([-55.0, 30.0, 0.0]),
          color: Vector3(1.0, 0.98, 0.94),
          intensity: 100000.0,
          castShadows: true,
          isSun: true,
        ),
      ));
      _register(LuminaActor(
        key: const LuminaObjectKey('nav_preview_sky'),
        root: LuminaSkyComponent.color(color: Vector4(0.36, 0.44, 0.56, 1.0), skyIntensity: 25000.0, iblIntensity: 25000.0),
      ));
      _overlay = LuminaProceduralMeshComponent();
      _overlayActor = LuminaActor(key: const LuminaObjectKey('nav_preview_overlay'), root: _overlay!);
      _register(_overlayActor!);
      world.tick(_tickSeconds);
    } catch (e, st) {
      debugPrint('[NavigationPreviewScene] attach failed: $e\n$st');
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  /// Releases every reference; the viewport owns the world's cleanup. Overlay
  /// sections and material instances are freed here because the sections
  /// keep native buffers alive.
  void detach() {
    _ticker?.cancel();
    _ticker = null;
    try {
      final w = _world;
      if (w != null && !w.isCleanedUp && _overlayActor != null) {
        w.persistentLevel.unregisterActor(_overlayActor!);
      }
      for (final m in _materials.values) {
        m.dispose();
      }
      _materials.clear();
      _materialProvider?.dispose();
    } catch (e) {
      debugPrint('[NavigationPreviewScene] detach cleanup: $e');
    }
    _materialProvider = null;
    _overlayActor = null;
    _overlay = null;
    _world = null;
    _meshActorCount = 0;
    _shownSnapshot = null;
    _shownPathKey = null;
  }

  void _tick() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      w.tick(_tickSeconds);
    } catch (e) {
      debugPrint('[NavigationPreviewScene] tick failed: $e');
    }
  }

  // --- Overlay ---------------------------------------------------------------

  /// Rebuilds the walkable / blocked sections when [snapshot] changed and
  /// toggles their visibility; a null snapshot clears them.
  void setOverlay(NavGridSnapshot? snapshot, {required bool visible}) {
    final overlay = _overlay;
    if (overlay == null || !isAttached) return;
    try {
      if (!identical(snapshot, _shownSnapshot)) {
        overlay.clearMeshSection(walkableSection);
        overlay.clearMeshSection(blockedSection);
        _shownSnapshot = snapshot;
        if (snapshot != null) {
          _buildCellSection(overlay, snapshot, walkable: true);
          _buildCellSection(overlay, snapshot, walkable: false);
        }
      }
      if (_overlayVisible != visible || snapshot != null) {
        _overlayVisible = visible;
        if (overlay.hasSection(walkableSection)) overlay.setSectionVisible(walkableSection, visible);
        if (overlay.hasSection(blockedSection)) overlay.setSectionVisible(blockedSection, visible);
      }
      _world?.tick(_tickSeconds);
    } catch (e, st) {
      debugPrint('[NavigationPreviewScene] overlay rebuild failed: $e\n$st');
    }
  }

  void _buildCellSection(LuminaProceduralMeshComponent overlay, NavGridSnapshot snap, {required bool walkable}) {
    var count = 0;
    for (var r = 0; r < snap.rows; r++) {
      for (var c = 0; c < snap.cols; c++) {
        if (snap.isWalkableCell(c, r) == walkable) count++;
      }
    }
    if (count == 0) return;
    final positions = Float32List(count * 4 * 3);
    final normals = Float32List(count * 4 * 3);
    final uvs = Float32List(count * 4 * 2);
    final colors = Uint8List(count * 4 * 4);
    final indices = Uint32List(count * 6);
    final inset = snap.cellSize * 0.06;
    final half = snap.cellSize / 2 - inset;
    final rgba = walkable ? const [40, 220, 90, 110] : const [230, 60, 50, 120];
    var q = 0;
    for (var r = 0; r < snap.rows; r++) {
      for (var c = 0; c < snap.cols; c++) {
        if (snap.isWalkableCell(c, r) != walkable) continue;
        final cx = snap.cellCenterX(c);
        final cz = snap.cellCenterZ(r);
        final y = snap.floorHeightAt(c, r) + cellHoverCm;
        _writeQuad(positions, normals, uvs, colors, indices, q, cx, y, cz, half, half, rgba);
        q++;
      }
    }
    final material = _material(walkable ? 'walkable' : 'blocked', rgba);
    overlay.createMeshSection(
      walkable ? walkableSection : blockedSection,
      positions: positions,
      normals: normals,
      uv0: uvs,
      colors: colors,
      indices: indices,
      material: material,
    );
    overlay.setSectionVisible(walkable ? walkableSection : blockedSection, _overlayVisible);
  }

  /// Rebuilds the path strip and the two flags. [pathPoints], [start] and
  /// [goal] are runtime-space world units (cm).
  void setPath({List<Vector3>? pathPoints, Vector3? start, Vector3? goal, bool isPartial = false}) {
    final overlay = _overlay;
    if (overlay == null || !isAttached) return;
    final key = Object.hash(
      pathPoints == null ? null : Object.hashAll(pathPoints.map((p) => Object.hash(p.x, p.y, p.z))),
      start == null ? null : Object.hash(start.x, start.y, start.z),
      goal == null ? null : Object.hash(goal.x, goal.y, goal.z),
      isPartial,
    );
    if (key == _shownPathKey) return;
    _shownPathKey = key;
    try {
      overlay.clearMeshSection(pathSection);
      overlay.clearMeshSection(startFlagSection);
      overlay.clearMeshSection(goalFlagSection);
      if (pathPoints != null && pathPoints.length >= 2) {
        _buildPathStrip(overlay, pathPoints, isPartial: isPartial);
      }
      if (start != null) _buildFlag(overlay, startFlagSection, start, const [60, 230, 90, 230], 'start');
      if (goal != null) _buildFlag(overlay, goalFlagSection, goal, const [240, 70, 60, 230], 'goal');
      _world?.tick(_tickSeconds);
    } catch (e, st) {
      debugPrint('[NavigationPreviewScene] path rebuild failed: $e\n$st');
    }
  }

  void _buildPathStrip(LuminaProceduralMeshComponent overlay, List<Vector3> points, {required bool isPartial}) {
    final segs = points.length - 1;
    final positions = Float32List(segs * 4 * 3);
    final normals = Float32List(segs * 4 * 3);
    final uvs = Float32List(segs * 4 * 2);
    final colors = Uint8List(segs * 4 * 4);
    final indices = Uint32List(segs * 6);
    final rgba = isPartial ? const [90, 160, 255, 200] : const [40, 110, 255, 220];
    const hw = pathWidthCm / 2;
    for (var s = 0; s < segs; s++) {
      final a = points[s];
      final b = points[s + 1];
      var dx = b.x - a.x;
      var dz = b.z - a.z;
      final len = math.sqrt(dx * dx + dz * dz);
      if (len < 1e-6) {
        dx = 1.0;
        dz = 0.0;
      } else {
        dx /= len;
        dz /= len;
      }
      // Perpendicular in the XZ plane.
      final px = -dz * hw;
      final pz = dx * hw;
      final ya = a.y + pathHoverCm;
      final yb = b.y + pathHoverCm;
      final base = s * 4;
      final corners = [
        [a.x + px, ya, a.z + pz],
        [a.x - px, ya, a.z - pz],
        [b.x - px, yb, b.z - pz],
        [b.x + px, yb, b.z + pz],
      ];
      for (var i = 0; i < 4; i++) {
        final v = base + i;
        positions[v * 3] = corners[i][0];
        positions[v * 3 + 1] = corners[i][1];
        positions[v * 3 + 2] = corners[i][2];
        normals[v * 3 + 1] = 1.0;
        uvs[v * 2] = (i == 0 || i == 3) ? 0.0 : 1.0;
        uvs[v * 2 + 1] = (i < 2) ? 0.0 : 1.0;
        colors[v * 4] = rgba[0];
        colors[v * 4 + 1] = rgba[1];
        colors[v * 4 + 2] = rgba[2];
        colors[v * 4 + 3] = rgba[3];
      }
      indices[s * 6] = base;
      indices[s * 6 + 1] = base + 2;
      indices[s * 6 + 2] = base + 1;
      indices[s * 6 + 3] = base;
      indices[s * 6 + 4] = base + 3;
      indices[s * 6 + 5] = base + 2;
    }
    overlay.createMeshSection(
      pathSection,
      positions: positions,
      normals: normals,
      uv0: uvs,
      colors: colors,
      indices: indices,
      material: _material(isPartial ? 'path_partial' : 'path', rgba),
    );
  }

  /// A flag is a square marker on the floor plus a small upright pennant.
  void _buildFlag(LuminaProceduralMeshComponent overlay, int section, Vector3 at, List<int> rgba, String key) {
    final positions = Float32List(2 * 4 * 3);
    final normals = Float32List(2 * 4 * 3);
    final uvs = Float32List(2 * 4 * 2);
    final colors = Uint8List(2 * 4 * 4);
    final indices = Uint32List(2 * 6);
    final p = at;
    const half = flagSizeCm / 2;
    _writeQuad(positions, normals, uvs, colors, indices, 0, p.x, p.y + pathHoverCm + 1.0, p.z, half, half, rgba);
    // Upright pennant: a vertical quad rising from the marker.
    final base = 4;
    final verts = [
      [p.x, p.y + pathHoverCm, p.z],
      [p.x, p.y + pathHoverCm + flagSizeCm * 2.5, p.z],
      [p.x + flagSizeCm, p.y + pathHoverCm + flagSizeCm * 2.2, p.z],
      [p.x + flagSizeCm, p.y + pathHoverCm + flagSizeCm * 1.6, p.z],
    ];
    for (var i = 0; i < 4; i++) {
      final v = base + i;
      positions[v * 3] = verts[i][0];
      positions[v * 3 + 1] = verts[i][1];
      positions[v * 3 + 2] = verts[i][2];
      normals[v * 3 + 2] = 1.0;
      uvs[v * 2] = (i >= 2) ? 1.0 : 0.0;
      uvs[v * 2 + 1] = (i == 1 || i == 2) ? 1.0 : 0.0;
      colors[v * 4] = rgba[0];
      colors[v * 4 + 1] = rgba[1];
      colors[v * 4 + 2] = rgba[2];
      colors[v * 4 + 3] = rgba[3];
    }
    indices[6] = base;
    indices[7] = base + 1;
    indices[8] = base + 2;
    indices[9] = base;
    indices[10] = base + 2;
    indices[11] = base + 3;
    overlay.createMeshSection(
      section,
      positions: positions,
      normals: normals,
      uv0: uvs,
      colors: colors,
      indices: indices,
      material: _material('flag_$key', rgba),
    );
  }

  /// Writes one horizontal quad (two triangles, +Y normal) at quad slot [q].
  static void _writeQuad(
    Float32List positions,
    Float32List normals,
    Float32List uvs,
    Uint8List colors,
    Uint32List indices,
    int q,
    double cx,
    double y,
    double cz,
    double halfX,
    double halfZ,
    List<int> rgba,
  ) {
    final base = q * 4;
    final corners = [
      [cx - halfX, y, cz - halfZ],
      [cx + halfX, y, cz - halfZ],
      [cx + halfX, y, cz + halfZ],
      [cx - halfX, y, cz + halfZ],
    ];
    for (var i = 0; i < 4; i++) {
      final v = base + i;
      positions[v * 3] = corners[i][0];
      positions[v * 3 + 1] = corners[i][1];
      positions[v * 3 + 2] = corners[i][2];
      normals[v * 3 + 1] = 1.0;
      uvs[v * 2] = (i == 1 || i == 2) ? 1.0 : 0.0;
      uvs[v * 2 + 1] = (i >= 2) ? 1.0 : 0.0;
      colors[v * 4] = rgba[0];
      colors[v * 4 + 1] = rgba[1];
      colors[v * 4 + 2] = rgba[2];
      colors[v * 4 + 3] = rgba[3];
    }
    // Counter-clockwise seen from +Y (double-sided material anyway).
    indices[q * 6] = base;
    indices[q * 6 + 1] = base + 2;
    indices[q * 6 + 2] = base + 1;
    indices[q * 6 + 3] = base;
    indices[q * 6 + 4] = base + 3;
    indices[q * 6 + 5] = base + 2;
  }

  /// Unlit, alpha-blended, double-sided gltfio ubershader instance tinted by
  /// `baseColorFactor`; depth-tested against nothing so the debug overlay
  /// stays readable through floor slabs.
  FilamentMaterialInstance? _material(String key, List<int> rgba) {
    final cached = _materials[key];
    if (cached != null) return cached;
    final w = _world;
    if (w == null || !w.hasNativeContext) return null;
    try {
      _materialProvider ??= FilamentMaterialProvider.ubershader(w.filamentEngine);
      final result = _materialProvider!.createMaterialInstance(
        MaterialKey(unlit: true, alphaMode: 2, doubleSided: true, hasVertexColors: true),
        label: 'nav_overlay_$key',
      );
      final mi = result.instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', rgba[0] / 255.0, rgba[1] / 255.0, rgba[2] / 255.0, rgba[3] / 255.0);
      mi.setCullingMode(CullingMode.none);
      mi.setDepthCulling(false);
      mi.setDepthWrite(false);
      _materials[key] = mi;
      return mi;
    } catch (e) {
      debugPrint('[NavigationPreviewScene] material $key failed: $e');
      return null;
    }
  }

  /// Registers synchronously through the persistent level (`world.spawnActor`
  /// double-registers via its deferred drain).
  void _register(LuminaActor actor) {
    _world!.persistentLevel.registerActor(actor);
  }

  /// Mesh bytes for a level actor: raw GLB/glTF files are read as-is, `.lmas`
  /// containers yield their embedded payload.
  static Future<Uint8List> _readMeshBytes(String path) async {
    final bytes = await File(path).readAsBytes();
    if (!path.toLowerCase().endsWith('.lmas')) return bytes;
    final asset = LuminaAsset.fromBytes(bytes);
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) {
      throw StateError('$path carries no mesh payload');
    }
    return payload;
  }
}
