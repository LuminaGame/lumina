import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/input/input_action.dart';

/// Base class for input modifiers that transform raw action values.
abstract class LuminaInputModifier {
  const LuminaInputModifier();

  /// Modifies [rawValue] and returns the transformed value.
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime);
}

/// Type of dead zone evaluation.
enum DeadZoneType { axial, radial }

/// Modifies an input value by applying a dead zone threshold and rescaling.
class LuminaDeadZoneModifier extends LuminaInputModifier {
  double lowerThreshold;
  double upperThreshold;
  DeadZoneType type;

  LuminaDeadZoneModifier({
    this.lowerThreshold = 0.2,
    this.upperThreshold = 1.0,
    this.type = DeadZoneType.radial,
  });

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final range = upperThreshold - lowerThreshold;
    if (range <= 0.0) {
      return LuminaInputActionValue.raw(rawValue.type, 0.0, 0.0, 0.0);
    }

    final vec = rawValue.asAxis3D;

    if (type == DeadZoneType.radial) {
      final m = rawValue.magnitude;
      if (m <= lowerThreshold || m == 0.0) {
        return LuminaInputActionValue.raw(rawValue.type, 0.0, 0.0, 0.0);
      }
      final remapped = ((m - lowerThreshold) / range).clamp(0.0, 1.0);
      final scale = remapped / m;
      return LuminaInputActionValue.raw(
        rawValue.type,
        vec.x * scale,
        vec.y * scale,
        vec.z * scale,
      );
    } else {
      // Axial dead zone
      double remapAxis(double v) {
        final absV = v.abs();
        if (absV <= lowerThreshold) return 0.0;
        final remapped = ((absV - lowerThreshold) / range).clamp(0.0, 1.0);
        return (v < 0.0 ? -1.0 : 1.0) * remapped;
      }

      return LuminaInputActionValue.raw(
        rawValue.type,
        remapAxis(vec.x),
        remapAxis(vec.y),
        remapAxis(vec.z),
      );
    }
  }
}

/// Inverts selected axes of an input value.
class LuminaNegateModifier extends LuminaInputModifier {
  bool x;
  bool y;
  bool z;

  LuminaNegateModifier({this.x = true, this.y = true, this.z = true});

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final vec = rawValue.asAxis3D;
    return LuminaInputActionValue.raw(
      rawValue.type,
      x ? -vec.x : vec.x,
      y ? -vec.y : vec.y,
      z ? -vec.z : vec.z,
    );
  }
}

/// Multiplies axes of an input value by scalar factors.
class LuminaScalarModifier extends LuminaInputModifier {
  Vector3 scalar;

  LuminaScalarModifier({double x = 1.0, double y = 1.0, double z = 1.0})
      : scalar = Vector3(x, y, z);

  LuminaScalarModifier.uniform(double s) : scalar = Vector3(s, s, s);

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final vec = rawValue.asAxis3D;
    return LuminaInputActionValue.raw(
      rawValue.type,
      vec.x * scalar.x,
      vec.y * scalar.y,
      vec.z * scalar.z,
    );
  }
}

/// Shapes input sensitivity using an exponential response curve.
class LuminaResponseCurveModifier extends LuminaInputModifier {
  double exponent;

  LuminaResponseCurveModifier({this.exponent = 2.0});

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final vec = rawValue.asAxis3D;
    double curve(double v) {
      if (v == 0.0) return 0.0;
      final sign = v < 0.0 ? -1.0 : 1.0;
      return sign * math.pow(v.abs(), exponent).toDouble();
    }

    return LuminaInputActionValue.raw(
      rawValue.type,
      curve(vec.x),
      curve(vec.y),
      curve(vec.z),
    );
  }
}

/// Places a key's raw 1D value onto one axis of a 2D action, scaled — the
/// Enhanced Input "swizzle axis" plus "scalar" pair in a single modifier.
/// What a project's key mappings use (Project Settings > Input), in the
/// editor and in generated games alike.
class LuminaAxisPlacementModifier extends LuminaInputModifier {
  final double toX;
  final double toY;

  const LuminaAxisPlacementModifier({this.toX = 0.0, this.toY = 0.0});

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final raw = rawValue.asAxis1D;
    return LuminaInputActionValue.raw(rawValue.type, raw * toX, raw * toY, 0.0);
  }
}
