import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math_64.dart';

/// What the debug-draw layer projects through: the game camera during
/// Play, the editor camera once ejected.
abstract interface class PieDebugProjector {
  /// The screen position of runtime point [p], or null when off camera.
  Offset? project(Vector3 p);

  /// Pixels one runtime unit spans at [p]'s depth.
  double scaleAt(Vector3 p);
}

/// A projector over two callbacks (the editor camera's overlay maths).
class PieFunctionProjector implements PieDebugProjector {
  final Offset? Function(Vector3 p) _project;
  final double Function(Vector3 p) _scaleAt;
  const PieFunctionProjector(this._project, this._scaleAt);

  @override
  Offset? project(Vector3 p) => _project(p);

  @override
  double scaleAt(Vector3 p) => _scaleAt(p);
}

/// Projects **runtime** (Y-up, cm) points through the camera Play looks
/// through: the possessed pawn's camera component —
/// its eye, forward and up vectors and vertical field of view — onto the
/// viewport, with the same pinhole model the Filament camera uses, so the
/// debug shapes `LuminaWorld.debugShapes` records land where the renderer
/// draws the world. Pure Dart; the level viewport builds one per frame.
class PieCameraProjection implements PieDebugProjector {
  final Vector3 eye;
  final Vector3 forward;
  final Vector3 right;
  final Vector3 up;
  final double fovDegrees;
  final Size size;
  late final double _focal;

  PieCameraProjection({
    required this.eye,
    required Vector3 forward,
    required Vector3 up,
    required this.fovDegrees,
    required this.size,
  })  : forward = forward.normalized(),
        right = forward.cross(up).normalized(),
        up = forward.cross(up).normalized().cross(forward).normalized() {
    _focal = size.height <= 0 ? 500.0 : (size.height / 2) / math.tan(fovDegrees * math.pi / 360.0);
  }

  /// The screen position of runtime point [p], or null behind the camera.
  @override
  Offset? project(Vector3 p) {
    final v = p - eye;
    final z = v.dot(forward);
    if (z <= 1.0) return null;
    final x = v.dot(right);
    final y = v.dot(up);
    return Offset(size.width / 2 + x / z * _focal, size.height / 2 - y / z * _focal);
  }

  /// Pixels one runtime unit spans at [p]'s depth (for radii and sizes).
  @override
  double scaleAt(Vector3 p) {
    final z = (p - eye).dot(forward);
    return z <= 1.0 ? 0.0 : _focal / z;
  }
}
