import 'dart:math' as math;

/// Inclusive rectangle of heightmap cells touched by a stroke.
class HeightRect {
  final int minCol;
  final int minRow;
  final int maxCol;
  final int maxRow;

  const HeightRect(this.minCol, this.minRow, this.maxCol, this.maxRow);

  int get colCount => maxCol - minCol + 1;
  int get rowCount => maxRow - minRow + 1;
  int get cellCount => colCount * rowCount;

  HeightRect union(HeightRect other) => HeightRect(
        math.min(minCol, other.minCol),
        math.min(minRow, other.minRow),
        math.max(maxCol, other.maxCol),
        math.max(maxRow, other.maxRow),
      );

  /// Grows the rect by [ring] cells, clamped to a [resolution]² grid — used
  /// to recompute normals one ring outside the edited cells.
  HeightRect inflate(int ring, int resolution) => HeightRect(
        math.max(0, minCol - ring),
        math.max(0, minRow - ring),
        math.min(resolution - 1, maxCol + ring),
        math.min(resolution - 1, maxRow + ring),
      );

  @override
  String toString() => 'HeightRect($minCol,$minRow → $maxCol,$maxRow)';

  @override
  bool operator ==(Object other) =>
      other is HeightRect &&
      other.minCol == minCol &&
      other.minRow == minRow &&
      other.maxCol == maxCol &&
      other.maxRow == maxRow;

  @override
  int get hashCode => Object.hash(minCol, minRow, maxCol, maxRow);
}


/// One contiguous vertex window of a terrain mesh section.
///
/// Windows are always **row-contiguous**: a circular brush touches a span of
/// rows, and each section uploads that row span in a single
/// `updateMeshSection(vertexOffset: …)` call — some untouched columns ride
/// along, which is cheaper than one call per row at 64-quad tile width and
/// matches the single-window contract of the procedural-mesh spec.
class SectionUpdateWindow {
  final int sectionIndex;
  final int sectionCol;
  final int sectionRow;
  final int firstLocalRow;
  final int rowCount;
  final int verticesPerRow;

  const SectionUpdateWindow({
    required this.sectionIndex,
    required this.sectionCol,
    required this.sectionRow,
    required this.firstLocalRow,
    required this.rowCount,
    required this.verticesPerRow,
  });

  int get vertexOffset => firstLocalRow * verticesPerRow;
  int get vertexCount => rowCount * verticesPerRow;

  @override
  String toString() => 'SectionUpdateWindow(#$sectionIndex, offset $vertexOffset, count $vertexCount)';
}

/// Maps the heightmap grid onto tiled mesh sections.
///
/// Sections share their seam rows/columns (each section's vertex grid
/// duplicates its neighbour's edge), so a brush on a seam writes both copies
/// and no crack appears.
class LandscapeSectionMap {
  final int gridResolution;
  final int quadsPerSection;

  LandscapeSectionMap({required this.gridResolution, int quadsPerSection = 64})
      : quadsPerSection = math.min(quadsPerSection, gridResolution - 1);

  int get sectionsPerSide => ((gridResolution - 1) / quadsPerSection).ceil();
  int get sectionCount => sectionsPerSide * sectionsPerSide;

  /// Vertices per row of a full-size section (seam row included).
  int get verticesPerRow => quadsPerSection + 1;
  int get verticesPerSection => verticesPerRow * verticesPerRow;

  int sectionIndexAt(int sectionCol, int sectionRow) => sectionRow * sectionsPerSide + sectionCol;
  int sectionColOf(int sectionIndex) => sectionIndex % sectionsPerSide;
  int sectionRowOf(int sectionIndex) => sectionIndex ~/ sectionsPerSide;

  /// First global heightmap column of a section.
  int firstColumnOf(int sectionIndex) => sectionColOf(sectionIndex) * quadsPerSection;
  int firstRowOf(int sectionIndex) => sectionRowOf(sectionIndex) * quadsPerSection;

  /// Global column of a section-local column.
  int globalColumnOf({required int sectionIndex, required int localCol}) => firstColumnOf(sectionIndex) + localCol;
  int globalRowOf({required int sectionIndex, required int localRow}) => firstRowOf(sectionIndex) + localRow;

  /// Vertices per row of [sectionIndex] (the last section is clipped when the
  /// resolution is not a multiple of [quadsPerSection]).
  int verticesPerRowOf(int sectionIndex) =>
      math.min(verticesPerRow, gridResolution - firstColumnOf(sectionIndex));
  int rowsOf(int sectionIndex) => math.min(verticesPerRow, gridResolution - firstRowOf(sectionIndex));

  /// The upload windows covering [rect], one per affected section.
  List<SectionUpdateWindow> windowsFor(HeightRect rect) {
    final windows = <SectionUpdateWindow>[];
    for (var sr = 0; sr < sectionsPerSide; sr++) {
      final rowStart = sr * quadsPerSection;
      final rowEnd = math.min(rowStart + quadsPerSection, gridResolution - 1);
      if (rect.maxRow < rowStart || rect.minRow > rowEnd) continue;
      for (var sc = 0; sc < sectionsPerSide; sc++) {
        final colStart = sc * quadsPerSection;
        final colEnd = math.min(colStart + quadsPerSection, gridResolution - 1);
        if (rect.maxCol < colStart || rect.minCol > colEnd) continue;
        final index = sectionIndexAt(sc, sr);
        final firstLocalRow = math.max(rect.minRow, rowStart) - rowStart;
        final lastLocalRow = math.min(rect.maxRow, rowEnd) - rowStart;
        windows.add(SectionUpdateWindow(
          sectionIndex: index,
          sectionCol: sc,
          sectionRow: sr,
          firstLocalRow: firstLocalRow,
          rowCount: lastLocalRow - firstLocalRow + 1,
          verticesPerRow: verticesPerRowOf(index),
        ));
      }
    }
    return windows;
  }
}

