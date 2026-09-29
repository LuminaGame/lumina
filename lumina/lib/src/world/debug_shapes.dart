import 'package:vector_math/vector_math_64.dart';

/// What kind of debug shape a Blueprint drew.
enum LuminaDebugShapeKind { line, sphere, box, point, arrow, string, capsule }

/// One debug shape recorded in `LuminaWorld.debugShapes` for the editor's
/// Play-In-Editor viewport to draw. Points
/// are **runtime** coordinates (Y up, cm); [color] is linear RGBA 0–1;
/// [expiresAt] is the world's real time the shape disappears at.
class LuminaDebugShape {
  final LuminaDebugShapeKind kind;

  /// Line / arrow: start and end. Sphere / point / string / capsule: the
  /// centre. Box: the centre.
  final List<Vector3> points;
  final List<double> color;
  final double thickness;
  final double duration;
  final double expiresAt;

  /// Sphere / point / capsule radius; arrow head size.
  final double radius;

  /// Box half extents; capsule: `(0, halfHeight, 0)`.
  final Vector3? extent;

  /// Box / capsule orientation.
  final Quaternion? rotation;

  /// The text of a string shape.
  final String? text;

  /// The Blueprint node that drew it (for the editor's debug-draw hover).
  final String? nodeId;

  const LuminaDebugShape({
    required this.kind,
    required this.points,
    required this.color,
    required this.expiresAt,
    this.thickness = 1.0,
    this.duration = 0.0,
    this.radius = 0.0,
    this.extent,
    this.rotation,
    this.text,
    this.nodeId,
  });

  @override
  String toString() =>
      'LuminaDebugShape(${kind.name}, ${points.map((p) => '(${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)}, ${p.z.toStringAsFixed(1)})').join(' → ')}'
      '${text == null ? '' : ' "$text"'}, until $expiresAt)';
}

/// One line of `Print String` with Print to Screen, keyed so a
/// node with the same key replaces its previous line.
class LuminaScreenMessage {
  final String key;
  final String text;
  final List<double> color;
  final double expiresAt;
  const LuminaScreenMessage(this.key, this.text, this.color, this.expiresAt);

  @override
  String toString() => 'LuminaScreenMessage($key: "$text", until $expiresAt)';
}
