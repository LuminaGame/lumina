import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Authoring ↔ runtime axes.
///
/// Levels are authored and stored **Z-up**: `location`,
/// `rotation` and `scale` in `metadata.actors` are what the Details panel
/// shows. The runtime (Filament, glTF) is **Y-up**. This is the one place the
/// rule is written; the level code generator, Play-In-Editor and the editor
/// viewport all go through it, so the editor and the game agree.
abstract final class LuminaAxes {
  /// Authoring `(x, y, z)` (Z up) → runtime `(x, z, −y)` (Y up).
  static Vector3 location(List<num> authoring) => Vector3(
        _at(authoring, 0),
        _at(authoring, 2),
        -_at(authoring, 1),
      );

  /// Runtime `(x, y, z)` → authoring `(x, −z, y)`.
  static List<double> toAuthoringLocation(Vector3 runtime) => [runtime.x, -runtime.z, runtime.y];

  /// Per-axis scale follows its axis: `(sx, sy, sz)` → `(sx, sz, sy)`.
  static Vector3 scale(List<num> authoring) =>
      Vector3(_at(authoring, 0, 1), _at(authoring, 2, 1), _at(authoring, 1, 1));

  /// Authoring rotation in degrees about the authoring X, Y and Z axes, as
  /// the editor viewport composes it: yaw about Z, then pitch about X, then
  /// roll about Y. In runtime axes that is `Ry(z) · Rx(x) · Rz(−y)`.
  static Quaternion rotation(List<num> authoringDegrees) => luminaAuthoringRotation(
        _at(authoringDegrees, 0),
        _at(authoringDegrees, 1),
        _at(authoringDegrees, 2),
      );

  static double _at(List<num> v, int i, [double fallback = 0.0]) => v.length > i ? v[i].toDouble() : fallback;
}

/// [LuminaAxes.rotation] for three angles: what generated level code calls
/// with the authored values, so the level file still reads like the Details
/// panel.
Quaternion luminaAuthoringRotation(double xDeg, double yDeg, double zDeg) {
  const d2r = math.pi / 180.0;
  final m = Matrix4.rotationY(zDeg * d2r) * Matrix4.rotationX(xDeg * d2r) * Matrix4.rotationZ(-yDeg * d2r);
  return Quaternion.fromRotation(m.getRotation())..normalize();
}
