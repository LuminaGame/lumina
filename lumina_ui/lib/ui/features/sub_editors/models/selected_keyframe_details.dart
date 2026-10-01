import 'dart:math' as math;

/// Detailed properties of a selected keyframe (Bone Transform, Curve Float, or Notify).
class SelectedKeyframeDetails {
  final String keyId;
  final String type; // 'Bone Keyframe', 'Master Sequence Keyframe', 'Curve Keyframe', 'Animation Notify'
  final String targetName; // e.g. 'pelvis', 'FootstepWeight', 'Idle_Loop'
  final double time;
  final int frame;

  // Transform vectors for Bone Keyframe
  final List<double>? location; // [x, y, z]
  final List<double>? rotationEuler; // [pitch, yaw, roll] in degrees
  final List<double>? rotationQuat; // [x, y, z, w]
  final List<double>? scale; // [x, y, z]
  final String? interpolation; // 'Linear', 'Step', 'Cubic'

  // Values for Curve Keyframe
  final double? curveValue;

  // Values for Notify
  final String? notifyType;

  // Selected sub-track label if sub-track was explicitly selected (e.g. 'Rotation.Pitch (P)')
  final String? subTrackLabel;

  const SelectedKeyframeDetails({
    required this.keyId,
    required this.type,
    required this.targetName,
    required this.time,
    required this.frame,
    this.location,
    this.rotationEuler,
    this.rotationQuat,
    this.scale,
    this.interpolation,
    this.curveValue,
    this.notifyType,
    this.subTrackLabel,
  });

  static List<double> quaternionToEuler(double x, double y, double z, double w) {
    // Roll (x-axis rotation)
    final sinrCosp = 2 * (w * x + y * z);
    final cosrCosp = 1 - 2 * (x * x + y * y);
    final roll = math.atan2(sinrCosp, cosrCosp) * 180.0 / math.pi;

    // Pitch (y-axis rotation)
    final sinp = 2 * (w * y - z * x);
    double pitch;
    if (sinp.abs() >= 1) {
      pitch = (sinp.sign * math.pi / 2) * 180.0 / math.pi;
    } else {
      pitch = math.asin(sinp) * 180.0 / math.pi;
    }

    // Yaw (z-axis rotation)
    final sinyCosp = 2 * (w * z + x * y);
    final cosyCosp = 1 - 2 * (y * y + z * z);
    final yaw = math.atan2(sinyCosp, cosyCosp) * 180.0 / math.pi;

    return [pitch, yaw, roll];
  }

  /// A bone's local rotation as degrees about its own X, Y and Z axes
  /// (applied X, then Y, then Z: `q = qZ · qY · qX`), the order
  /// [eulerXyzToQuaternion] reads back.
  static List<double> quaternionToEulerXyz(double x, double y, double z, double w) {
    final e = quaternionToEuler(x, y, z, w); // [about Y, about Z, about X]
    return [e[2], e[0], e[1]];
  }

  /// `[x, y, z]` degrees → quaternion `[x, y, z, w]`, `q = qZ · qY · qX`.
  static List<double> eulerXyzToQuaternion(double xDeg, double yDeg, double zDeg) {
    const d2r = math.pi / 180.0;
    final cx = math.cos(xDeg * d2r / 2), sx = math.sin(xDeg * d2r / 2);
    final cy = math.cos(yDeg * d2r / 2), sy = math.sin(yDeg * d2r / 2);
    final cz = math.cos(zDeg * d2r / 2), sz = math.sin(zDeg * d2r / 2);
    return [
      sx * cy * cz - cx * sy * sz,
      cx * sy * cz + sx * cy * sz,
      cx * cy * sz - sx * sy * cz,
      cx * cy * cz + sx * sy * sz,
    ];
  }
}
