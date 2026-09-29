import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'landscape_brush.dart';

/// The engine seam of the Landscape editor.
///
/// The view model owns the heightmap and the foliage transforms; everything
/// that has to reach the GPU goes through this sink. The real implementation
/// is `LandscapePreviewScene` (lumina `LuminaProceduralMeshComponent` tiles +
/// one `LuminaInstancedStaticMeshComponent` per foliage layer); tests use a
/// recording fake, so the upload windows and instance batches are asserted
/// without a renderer.
abstract class LandscapeTerrainSink {
  /// True when a live world is attached and the calls below really render.
  bool get isAvailable;

  /// Hands the whole payload to the engine and lets it decide what to mount.
  ///
  /// Returns true when the sink took ownership — the engine component then
  /// streams tiles against its residency budget, which is the only way an
  /// 8129² terrain is renderable at all. Sinks that cannot do that return
  /// false and the view model pushes every tile itself, as before.
  bool mountPayload(LandscapeData data) => false;

  /// Re-solves residency for a camera at a terrain-space position (metres).
  void updateResidency(double worldX, double worldZ) {}

  /// True when [sectionIndex] is currently mounted. A tile the residency
  /// budget left out must not be uploaded into by a sculpt stroke.
  bool isSectionResident(int sectionIndex) => true;

  /// Asks the sink to rebuild one whole tile itself, at whatever LOD it
  /// currently holds. Returns false when the caller must build it instead.
  bool rebuildSection(int sectionIndex) => false;

  /// Measured residency numbers for the HUD, or null when the sink does not
  /// stream (everything mounted).
  LandscapeResidencyStats? get residencyStats => null;

  /// (Re)builds a whole terrain tile.
  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  });

  /// Uploads one row-contiguous vertex window of a tile (partial update):
  /// positions, the normals the lit terrain shades with, and the window's
  /// slope albedo.
  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  });

  /// False when a tile cannot take windowed uploads — a tile the tangent
  /// generator remeshed (split or reordered its vertices) or a decimated one.
  /// The view model then rebuilds that whole tile instead of writing garbage.
  bool supportsPartialUpdate(int sectionIndex) => true;

  /// Creates (or recreates) the instance batch of a foliage layer.
  void createFoliageBatch(int layerIndex, {required String meshAssetPath, required int capacity});

  /// Adds one instance; returns its index in the batch.
  int addFoliageInstance(int layerIndex, Matrix4 transform);

  /// Swap-removes an instance (the batch's last instance relocates into the
  /// hole, mirroring the view model's own array).
  void removeFoliageInstance(int layerIndex, int instanceIndex);

  /// Drops every section and batch (new terrain / reopen).
  void clearTerrain();

  /// Shows the brush cursor draped on the terrain, or hides it (null).
  void setBrushCursor(LandscapeBrushCursorState? cursor);
}

/// Which brush the cursor shows — it picks the cursor's colour.
enum LandscapeCursorKind { sculpt, scatter, erase }

/// The brush cursor the view model wants on the terrain, in terrain-space
/// metres (the sink converts to its world).
class LandscapeBrushCursorState {
  final double x;
  final double z;
  final double radius;
  final double falloff;
  final LandscapeCursorKind kind;

  const LandscapeBrushCursorState({
    required this.x,
    required this.z,
    required this.radius,
    required this.falloff,
    required this.kind,
  });

  @override
  bool operator ==(Object other) =>
      other is LandscapeBrushCursorState &&
      other.x == x &&
      other.z == z &&
      other.radius == radius &&
      other.falloff == falloff &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(x, z, radius, falloff, kind);

  @override
  String toString() => 'LandscapeBrushCursorState($kind at ($x, $z), r $radius, falloff $falloff)';
}

/// A sink that renders nothing — used when the sub-editor runs without a
/// native viewport (unit tests, headless shells). Every call is a no-op and
/// [isAvailable] is false so the UI can show an honest "preview unavailable"
/// badge instead of faking terrain.
class NullTerrainSink implements LandscapeTerrainSink {
  const NullTerrainSink();

  @override
  bool get isAvailable => false;

  @override
  bool mountPayload(LandscapeData data) => false;

  @override
  void updateResidency(double worldX, double worldZ) {}

  @override
  bool isSectionResident(int sectionIndex) => true;

  @override
  bool rebuildSection(int sectionIndex) => false;

  @override
  LandscapeResidencyStats? get residencyStats => null;

  @override
  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  }) {}

  @override
  bool supportsPartialUpdate(int sectionIndex) => true;

  @override
  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  }) {}

  @override
  void createFoliageBatch(int layerIndex, {required String meshAssetPath, required int capacity}) {}

  @override
  int addFoliageInstance(int layerIndex, Matrix4 transform) => -1;

  @override
  void removeFoliageInstance(int layerIndex, int instanceIndex) {}

  @override
  void clearTerrain() {}

  @override
  void setBrushCursor(LandscapeBrushCursorState? cursor) {}
}


/// What a streaming landscape really has mounted right now.
///
/// Every field is read back from the engine — sections and triangles from the
/// geometry actually uploaded, vertices from the mesh component after any
/// tangent-generator split, bytes from each section's real vertex stride.
/// Nothing here is an estimate.
class LandscapeResidencyStats {
  final int residentSections;
  final int totalSections;
  final int triangles;
  final int vertices;
  final int gpuBytes;
  final int droppedForBudget;
  final int foliageInstances;
  final int foliageRenderables;

  const LandscapeResidencyStats({
    required this.residentSections,
    required this.totalSections,
    required this.triangles,
    required this.vertices,
    required this.gpuBytes,
    required this.droppedForBudget,
    required this.foliageInstances,
    required this.foliageRenderables,
  });

  bool get isStreaming => residentSections < totalSections || droppedForBudget > 0;

  double get gpuMegabytes => gpuBytes / (1024 * 1024);

  /// One line for the viewport HUD.
  String get label => 'Resident $residentSections/$totalSections tiles · '
      '${_thousands(triangles)} tris · ${_thousands(vertices)} verts · '
      '${gpuMegabytes.toStringAsFixed(1)} MB'
      '${droppedForBudget > 0 ? ' · $droppedForBudget over budget' : ''}';

  static String _thousands(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
      out.write(s[i]);
    }
    return out.toString();
  }
}
