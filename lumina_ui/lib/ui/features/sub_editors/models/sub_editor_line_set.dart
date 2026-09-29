/// Line segments a sub-editor viewport draws over its scene: a Blueprint's
/// capsule, spring arm and camera. In the viewport's own frame (the
/// runtime's Y up, world units).
class SubEditorLineSet {
  /// Which set this is (a component id); one native line entity per id.
  final String id;

  /// Vertex positions, `x, y, z` per vertex.
  final List<double> positions;

  /// Vertex index pairs, one pair per segment.
  final List<int> indices;

  /// Line colour, 0–1.
  final double r;
  final double g;
  final double b;

  /// The highlighted set (the selected component).
  final bool selected;

  /// Drawn over the scene with no depth test (a selected component shows
  /// through the mesh around it).
  final bool xray;

  /// Changes whenever the geometry or the style does; the viewport rebuilds a
  /// set's native lines only then.
  final String signature;

  const SubEditorLineSet({
    required this.id,
    required this.positions,
    required this.indices,
    required this.r,
    required this.g,
    required this.b,
    required this.signature,
    this.selected = false,
    this.xray = false,
  });

  int get segmentCount => indices.length ~/ 2;
}
