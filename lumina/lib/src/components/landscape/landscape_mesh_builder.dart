import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../data/models/landscape_data.dart';
import 'landscape_section_map.dart';

/// The vertex/index arrays of one terrain tile, in the exact layout
/// `LuminaProceduralMeshComponent.createMeshSection` expects.
class LandscapeSectionGeometry {
  final int sectionIndex;

  /// Vertices per row / number of rows actually emitted (after [lodStep]).
  final int verticesPerRow;
  final int rowCount;

  /// The decimation step this geometry was built with (1 = full detail).
  final int lodStep;

  final Float32List positions;
  final Float32List normals;
  final Float32List uv0;
  final Uint8List colors;
  final Uint32List indices;

  const LandscapeSectionGeometry({
    required this.sectionIndex,
    required this.verticesPerRow,
    required this.rowCount,
    required this.lodStep,
    required this.positions,
    required this.normals,
    required this.uv0,
    required this.colors,
    required this.indices,
  });

  int get vertexCount => verticesPerRow * rowCount;
  int get triangleCount => indices.length ~/ 3;
}

/// The LOD steps of a tile's four neighbours.
///
/// A tile whose neighbour is coarser must place its shared-edge vertices on
/// the straight line the coarse neighbour draws, or a crack opens along the
/// seam. Steps are powers of two, so the coarse tile's edge samples are a
/// subset of the fine tile's and the fix is exact: every fine vertex between
/// two coarse ones takes the linear interpolation of them.
class LandscapeEdgeSteps {
  /// Step of the neighbour at lower row / higher row / lower column / higher
  /// column. 1 means "as fine as this tile", i.e. nothing to stitch.
  final int north;
  final int south;
  final int west;
  final int east;

  const LandscapeEdgeSteps({this.north = 1, this.south = 1, this.west = 1, this.east = 1});

  static const LandscapeEdgeSteps none = LandscapeEdgeSteps();

  bool get isFlat => north <= 1 && south <= 1 && west <= 1 && east <= 1;

  @override
  bool operator ==(Object other) =>
      other is LandscapeEdgeSteps &&
      other.north == north &&
      other.south == south &&
      other.west == west &&
      other.east == east;

  @override
  int get hashCode => Object.hash(north, south, west, east);

  @override
  String toString() => 'LandscapeEdgeSteps(n:$north s:$south w:$west e:$east)';
}

/// The one place terrain geometry is derived from a [LandscapeData].
///
/// Both the runtime `LuminaLandscapeComponent` and the Landscape sub-editor's
/// preview build their tiles here, so a terrain looks identical in the editor,
/// in the level viewport and in a packaged game.
///
/// Tiles duplicate their seam row/column with their neighbours (see
/// [LandscapeSectionMap]), so a height edited on a seam is written into both
/// copies and no crack appears.
class LandscapeMeshBuilder {
  const LandscapeMeshBuilder._();

  /// Linear RGBA albedo of gentle ground: grass (sRGB ≈ 96, 128, 56).
  static const List<int> grassAlbedo = [30, 55, 10, 255];

  /// Linear RGBA albedo of steep ground: bare rock (sRGB ≈ 136, 128, 116).
  static const List<int> rockAlbedo = [63, 55, 45, 255];

  /// Slope (degrees off vertical) where grass starts giving way to rock, and
  /// where the ground is all rock.
  static const double rockSlopeStartDegrees = 30.0;
  static const double rockSlopeEndDegrees = 45.0;

  /// Writes the albedo of a vertex with unit normal [n] into [colors] at [v]:
  /// grass on gentle ground, blending to rock on steep ground.
  ///
  /// It depends on the vertex's own normal only — never on the terrain's
  /// height range — so a tile's colours are fixed by its own samples and a
  /// windowed sculpt upload stays consistent with its neighbours (the
  /// old height ramp went stale per tile as the range grew).
  static void writeAlbedo(Uint8List colors, int v, Vector3 n) {
    final slope = math.acos(n.y.clamp(-1.0, 1.0)) * 180.0 / math.pi;
    final t = ((slope - rockSlopeStartDegrees) / (rockSlopeEndDegrees - rockSlopeStartDegrees)).clamp(0.0, 1.0);
    final s = t * t * (3.0 - 2.0 * t);
    for (var k = 0; k < 4; k++) {
      colors[v * 4 + k] = (grassAlbedo[k] + (rockAlbedo[k] - grassAlbedo[k]) * s).round();
    }
  }

  /// Builds the full geometry of [sectionIndex].
  ///
  /// [lodStep] decimates the vertex grid (1 = every sample, 2 = every second,
  /// …). A step must divide the tile's quad count for the tile to keep its
  /// seam vertices; when it does not, the last sample is still emitted so the
  /// tile keeps its seam vertex.
  static LandscapeSectionGeometry buildSection(
    LandscapeData data,
    LandscapeSectionMap map,
    int sectionIndex, {
    double unitsPerMetre = 1.0,
    int lodStep = 1,
    LandscapeEdgeSteps edgeSteps = LandscapeEdgeSteps.none,
  }) {
    final step = lodStep < 1 ? 1 : lodStep;
    final cols = _sampledCount(map.verticesPerRowOf(sectionIndex), step);
    final rows = _sampledCount(map.rowsOf(sectionIndex), step);
    final count = cols * rows;
    final positions = Float32List(count * 3);
    final normals = Float32List(count * 3);
    final uv0 = Float32List(count * 2);
    final colors = Uint8List(count * 4);
    final indices = Uint32List((cols - 1) * (rows - 1) * 6);

    fillVertices(
      data,
      map,
      sectionIndex,
      firstLocalRow: 0,
      rowCount: rows,
      positions: positions,
      normals: normals,
      uv0: uv0,
      colors: colors,
      unitsPerMetre: unitsPerMetre,
      lodStep: step,
      edgeSteps: edgeSteps,
    );

    var k = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c;
        final b = a + 1;
        final d = a + cols;
        final e = d + 1;
        indices[k++] = a;
        indices[k++] = d;
        indices[k++] = b;
        indices[k++] = b;
        indices[k++] = d;
        indices[k++] = e;
      }
    }

    return LandscapeSectionGeometry(
      sectionIndex: sectionIndex,
      verticesPerRow: cols,
      rowCount: rows,
      lodStep: step,
      positions: positions,
      normals: normals,
      uv0: uv0,
      colors: colors,
      indices: indices,
    );
  }

  /// Number of vertices emitted along an axis of [full] samples at [step].
  ///
  /// The last sample is always emitted so the tile keeps its seam vertex even
  /// when [step] does not divide `full - 1`.
  static int sampledCount(int full, int step) => _sampledCount(full, step);

  static int _sampledCount(int full, int step) {
    if (step <= 1) return full;
    final quads = full - 1;
    return quads ~/ step + (quads % step == 0 ? 1 : 2);
  }

  /// The global grid offset of the [i]-th emitted sample along an axis of
  /// [full] samples at [step].
  static int sampleOffset(int i, int full, int step) {
    if (step <= 1) return i;
    final offset = i * step;
    return offset >= full ? full - 1 : offset;
  }

  /// Fills a row window of [sectionIndex] with real heightmap data.
  ///
  /// [firstLocalRow] and [rowCount] are counted in **emitted** rows, i.e. after
  /// [lodStep] decimation, which is what a windowed
  /// `updateMeshSection(vertexOffset: …)` upload addresses.
  static void fillVertices(
    LandscapeData data,
    LandscapeSectionMap map,
    int sectionIndex, {
    required int firstLocalRow,
    required int rowCount,
    required Float32List positions,
    required Float32List normals,
    Float32List? uv0,
    Uint8List? colors,
    double unitsPerMetre = 1.0,
    int lodStep = 1,
    LandscapeEdgeSteps edgeSteps = LandscapeEdgeSteps.none,
  }) {
    final step = lodStep < 1 ? 1 : lodStep;
    final fullCols = map.verticesPerRowOf(sectionIndex);
    final fullRows = map.rowsOf(sectionIndex);
    final cols = _sampledCount(fullCols, step);
    final baseCol = map.firstColumnOf(sectionIndex);
    final baseRow = map.firstRowOf(sectionIndex);
    final size = data.worldSize;


    final emittedRows = _sampledCount(fullRows, step);
    var v = 0;
    for (var lr = 0; lr < rowCount; lr++) {
      final localRow = firstLocalRow + lr;
      final rowOffset = sampleOffset(localRow, fullRows, step);
      final gr = baseRow + rowOffset;
      final onNorth = localRow == 0;
      final onSouth = localRow == emittedRows - 1;
      for (var lc = 0; lc < cols; lc++) {
        final colOffset = sampleOffset(lc, fullCols, step);
        final gc = baseCol + colOffset;
        final x = data.worldXOf(gc);
        final z = data.worldZOf(gr);
        var y = data.heightAt(gc, gr);
        // Stitch to a coarser neighbour: the shared edge must be the segment
        // the coarse tile draws, not the fine heightmap between its samples.
        if (!edgeSteps.isFlat) {
          if (lc == 0 && edgeSteps.west > step) {
            y = _stitchAlongRow(data, baseRow, fullRows, gc, rowOffset, edgeSteps.west);
          } else if (lc == cols - 1 && edgeSteps.east > step) {
            y = _stitchAlongRow(data, baseRow, fullRows, gc, rowOffset, edgeSteps.east);
          } else if (onNorth && edgeSteps.north > step) {
            y = _stitchAlongColumn(data, baseCol, fullCols, gr, colOffset, edgeSteps.north);
          } else if (onSouth && edgeSteps.south > step) {
            y = _stitchAlongColumn(data, baseCol, fullCols, gr, colOffset, edgeSteps.south);
          }
        }
        positions[v * 3] = x * unitsPerMetre;
        positions[v * 3 + 1] = y * unitsPerMetre;
        positions[v * 3 + 2] = z * unitsPerMetre;
        final n = data.sampleNormal(x, z);
        normals[v * 3] = n.x;
        normals[v * 3 + 1] = n.y;
        normals[v * 3 + 2] = n.z;
        if (uv0 != null) {
          uv0[v * 2] = (x + size / 2) / size;
          uv0[v * 2 + 1] = (z + size / 2) / size;
        }
        if (colors != null) writeAlbedo(colors, v, n);
        v++;
      }
    }
  }

  /// Height on the coarse neighbour's edge polyline, walking down a column of
  /// a tile (used for the west/east seams).
  static double _stitchAlongRow(
    LandscapeData data,
    int baseRow,
    int fullRows,
    int globalCol,
    int rowOffset,
    int neighbourStep,
  ) =>
      _lerpCoarse(
        (int offset) => data.heightAt(globalCol, baseRow + offset),
        rowOffset,
        fullRows - 1,
        neighbourStep,
      );

  /// Height on the coarse neighbour's edge polyline, walking along a row of a
  /// tile (used for the north/south seams).
  static double _stitchAlongColumn(
    LandscapeData data,
    int baseCol,
    int fullCols,
    int globalRow,
    int colOffset,
    int neighbourStep,
  ) =>
      _lerpCoarse(
        (int offset) => data.heightAt(baseCol + offset, globalRow),
        colOffset,
        fullCols - 1,
        neighbourStep,
      );

  static double _lerpCoarse(
    double Function(int offset) sample,
    int offset,
    int lastOffset,
    int neighbourStep,
  ) {
    if (neighbourStep <= 1) return sample(offset);
    var lo = (offset ~/ neighbourStep) * neighbourStep;
    if (lo > lastOffset) lo = lastOffset;
    var hi = lo + neighbourStep;
    if (hi > lastOffset) hi = lastOffset;
    if (hi == lo) return sample(lo);
    final t = (offset - lo) / (hi - lo);
    final a = sample(lo);
    final b = sample(hi);
    return a + (b - a) * t;
  }
}
