import 'dart:ui' show Color;

import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A ghost skeleton drawn over a sub-editor viewport (onion skins): a whole
/// pose, joint name → `[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]` as
/// `SubEditor3DViewport.jointLocalPose`, in [color] at [opacity].
class SubEditorGhostSkeleton {
  final Map<String, List<double>> jointLocalPose;
  final Color color;
  final double opacity;
  final bool volumetric;

  /// A short tag drawn at the skeleton's top joint (`15`, `seam`).
  final String? label;

  const SubEditorGhostSkeleton({
    required this.jointLocalPose,
    required this.color,
    this.opacity = 0.6,
    this.label,
    this.volumetric = true,
  });
}

enum SubEditorMarkerShape { dot, diamond, ring }

/// A point drawn over the viewport (an IK target, a pole), in the GLB frame
/// the skeleton is drawn in.
class SubEditorOverlayMarker {
  final Vector3 position;
  final Color color;
  final SubEditorMarkerShape shape;
  final String? label;

  /// A line from the marker to this point (a pole to its elbow).
  final Vector3? lineTo;

  const SubEditorOverlayMarker({
    required this.position,
    required this.color,
    this.shape = SubEditorMarkerShape.dot,
    this.label,
    this.lineTo,
  });
}

/// A polyline over the viewport (a drawn root path), GLB frame.
class SubEditorOverlayPath {
  final List<Vector3> points;
  final Color color;

  const SubEditorOverlayPath({required this.points, required this.color});
}
