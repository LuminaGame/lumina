import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// A description transform (authoring: Z up, centimetres, rotator degrees)
/// in the runtime frame (Y up, centimetres) the preview scene draws in.
class LuminaViewportRuntimeTransform {
  const LuminaViewportRuntimeTransform(this.location, this.rotation, this.scale);

  final Vector3 location;
  final Quaternion rotation;
  final Vector3 scale;

  /// The location in metres (the glTF unit).
  Vector3 get locationMetres => location / LuminaUnits.unitsPerMetre;

  Matrix4 get matrix => Matrix4.compose(location, rotation, scale);
}

/// The one place a Viewport converts its description into the runtime
/// frame, through [LuminaAxes] and [LuminaUnits].
abstract final class LuminaViewportTransforms {
  static List<num> _nums(Object? v, List<num> fallback) =>
      v is List && v.length >= 3 ? [for (final e in v.take(3)) e is num ? e : 0] : fallback;

  /// [transform] (`{location, rotation, scale}`, authoring) → runtime.
  static LuminaViewportRuntimeTransform toRuntime(Object? transform) {
    final t = transform is Map ? transform : const {};
    return LuminaViewportRuntimeTransform(
      LuminaAxes.location(_nums(t['location'], const [0, 0, 0])),
      LuminaAxes.rotation(_nums(t['rotation'], const [0, 0, 0])),
      LuminaAxes.scale(_nums(t['scale'], const [1, 1, 1])),
    );
  }

  /// A runtime matrix back into a description transform (authoring).
  static Map<String, Object?> toAuthoring(Matrix4 runtime) {
    final location = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();
    runtime.decompose(location, rotation, scale);
    return <String, Object?>{
      'location': LuminaAxes.toAuthoringLocation(location),
      'rotation': authoringDegrees(rotation),
      'scale': [scale.x, scale.z, scale.y],
    };
  }

  /// The authoring rotator (degrees about X, Y, Z) of runtime rotation [q]:
  /// the inverse of [LuminaAxes.rotation] (`Ry(−z) · Rx(x) · Rz(y)`).
  static List<double> authoringDegrees(Quaternion q) {
    final m = q.asRotationMatrix();
    // R = Ry(a) Rx(b) Rz(c) with a = −z, b = x, c = y:
    // m[1][2] (row 1, col 2) = −sin b.
    final sb = (-m.entry(1, 2)).clamp(-1.0, 1.0);
    final b = math.asin(sb);
    final double a;
    final double c;
    if (sb.abs() < 0.999999) {
      a = math.atan2(m.entry(0, 2), m.entry(2, 2));
      c = math.atan2(m.entry(1, 0), m.entry(1, 1));
    } else {
      a = math.atan2(-m.entry(2, 0), m.entry(0, 0));
      c = 0.0;
    }
    const r2d = 180.0 / math.pi;
    double clean(double v) => (v * 1e6).roundToDouble() / 1e6;
    return [clean(b * r2d), clean(c * r2d), clean(-a * r2d)];
  }

  /// The eye of an orbit camera around [target] (authoring, cm): [yaw]
  /// degrees about authoring Z (0 looks along +Y, from a character's front),
  /// [pitch] degrees down, [distance] cm away. Returned in runtime axes.
  static Vector3 orbitEye(List<double> target, double yaw, double pitch, double distance) {
    const d2r = math.pi / 180.0;
    final y = yaw * d2r;
    final p = pitch * d2r;
    // Authoring: the eye sits in front (−Y forward of the target … +Y), above.
    final offset = [
      -math.sin(y) * math.cos(p) * distance,
      math.cos(y) * math.cos(p) * distance,
      math.sin(p) * distance,
    ];
    return LuminaAxes.location([target[0] + offset[0], target[1] + offset[1], target[2] + offset[2]]);
  }
}
